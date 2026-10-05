import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_integrity_json_parser.dart' as json_parser;
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/startup_data_validation_unavailable.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/startup/startup_check_service.dart';

Future<String> Function()? loadStartupValidationWorkerSourceForTesting;

void _mockStartupValidationWorkerAsset() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final assetKey = utf8.decode(
      message!.buffer.asUint8List(
        message.offsetInBytes,
        message.lengthInBytes,
      ),
    );
    if (assetKey != 'web/data_integrity_json_worker.js') return null;
    final loadWorkerSource = loadStartupValidationWorkerSourceForTesting;
    if (loadWorkerSource == null) {
      throw StateError('Web validation worker asset source is missing');
    }
    final source = await loadWorkerSource();
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  });
  addTearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
    // 迁移前备份需要可用的存储（JSON 测试模式）：
    // checkAndMigrate 在备份失败时会取消迁移（生产安全策略）。
    ManifestDatabase.enableTestMode();
  });

  group('StartupCheckService - format version check', () {
    test('returns needsMigration=false when version matches', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'data_format_versions', jsonEncode(DataParts.currentVersions));

      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isFalse);
    });

    test('returns needsMigration=true when version is stale', () async {
      // No version set (defaults to 0)
      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isTrue);
    });

    test('returns needsMigration=false when version is newer', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'data_format_versions',
          jsonEncode({
            for (final part in DataParts.all)
              part: DataParts.currentVersions[part]! + 1
          }));

      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isFalse);
    });
  });

  group('StartupCheckService - version sentinel', () {
    test('returns null when no part is ahead of current version', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          for (final part in DataParts.all)
            part: DataParts.currentVersions[part],
        }),
      });
      final ahead = await StartupCheckService.checkVersionAhead();
      expect(ahead, isNull);
    });

    test('describes parts whose stored version is ahead', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          'chat': 99, // 超前（当前 chat v1）
          'settings': 1, // 正常
          for (final part in DataParts.all)
            if (part != 'chat' && part != 'settings')
              part: DataParts.currentVersions[part],
        }),
      });
      final ahead = await StartupCheckService.checkVersionAhead();
      expect(ahead, isNotNull);
      expect(ahead, contains('chat'));
      expect(ahead, contains('v99'));
    });

    test('returns null when version record is unreadable (fail-open)',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': 'not-json{{{',
      });
      final ahead = await StartupCheckService.checkVersionAhead();
      expect(ahead, isNull, reason: '版本记录损坏时按未存储处理（0），不应误判为超前');
    });
  });

  group('Startup JSON batch parsing on Web', () {
    test(
      'parses a batch once and preserves semantic findings in the worker',
      () async {
        _mockStartupValidationWorkerAsset();

        final result =
            await StartupCheckService.validateJsonBatchAndDataFormats(
          [
            '[{"id":"","type":"llm","name":"provider"}]',
            '[{"id":1,"messages":"not-a-list"}]',
            '{not-valid-json',
          ],
          providerEntriesIndex: 0,
          conversationsIndex: 1,
        );

        expect(result.parseErrors[0], isNull);
        expect(result.parseErrors[1], isNull);
        expect(result.parseErrors[2], isNotNull);
        expect(
          result.formatIssues.map((issue) => issue.message),
          containsAll([
            'provider_entries[0]: id 字段缺失或为空',
            'conversations[0]: id 字段缺失',
            'conversations[0]: messages 字段不是合法列表',
          ]),
        );
      },
      skip: !kIsWeb,
    );

    test('retries bundled worker and preserves parse findings', () async {
      final previousPrimaryWorker =
          json_parser.debugPrimaryValidationWorkerForTesting;
      final previousBundledWorker =
          json_parser.debugBundledValidationWorkerForTesting;
      var bundledWorkerCalled = false;
      json_parser.debugPrimaryValidationWorkerForTesting = (_) async {
        throw StateError('simulated primary parse worker failure');
      };
      json_parser.debugBundledValidationWorkerForTesting = (message) async {
        bundledWorkerCalled = true;
        expect(message.first, 'parseJsonBatch');
        return jsonEncode([null, 'simulated JSON parse error']);
      };

      try {
        final parseErrors = await json_parser.parseJsonBatch([
          '[]',
          '{broken',
        ]);

        expect(bundledWorkerCalled, isTrue);
        expect(parseErrors, [null, 'simulated JSON parse error']);
      } finally {
        json_parser.debugPrimaryValidationWorkerForTesting =
            previousPrimaryWorker;
        json_parser.debugBundledValidationWorkerForTesting =
            previousBundledWorker;
      }
    }, skip: !kIsWeb);

    test('large payload stays responsive during bundled worker retry',
        () async {
      _mockStartupValidationWorkerAsset();
      final largeJson =
          '[${List<String>.filled(1000000, '"payload"').join(',')}]';
      final previousPrimaryWorker =
          json_parser.debugPrimaryValidationWorkerForTesting;
      final previousBundledWorker =
          json_parser.debugBundledValidationWorkerForTesting;
      final previousWorkerSourceLoader =
          loadStartupValidationWorkerSourceForTesting;
      var bundledWorkerSourceLoaded = false;
      var uiPulses = 0;
      var uiPulsesWhenWorkerSourceLoaded = 0;
      json_parser.debugPrimaryValidationWorkerForTesting = (_) async {
        throw StateError('simulated primary parse worker failure');
      };
      json_parser.debugBundledValidationWorkerForTesting = null;
      loadStartupValidationWorkerSourceForTesting = () async {
        final loadSource = previousWorkerSourceLoader;
        if (loadSource == null) {
          throw StateError('Web validation worker asset source is missing');
        }
        final source = await loadSource();
        bundledWorkerSourceLoaded = true;
        uiPulsesWhenWorkerSourceLoaded = uiPulses;
        return source;
      };
      final uiHeartbeat = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => uiPulses++,
      );

      try {
        final parseErrors = await json_parser.parseJsonBatch([largeJson]);

        expect(parseErrors, [null]);
        expect(bundledWorkerSourceLoaded, isTrue);
        expect(
          uiPulses,
          greaterThan(uiPulsesWhenWorkerSourceLoaded),
          reason:
              'the UI event loop should keep running while the Worker parses',
        );
      } finally {
        uiHeartbeat.cancel();
        json_parser.debugPrimaryValidationWorkerForTesting =
            previousPrimaryWorker;
        json_parser.debugBundledValidationWorkerForTesting =
            previousBundledWorker;
        loadStartupValidationWorkerSourceForTesting =
            previousWorkerSourceLoader;
      }
    }, skip: !kIsWeb);

    test('blocks validation when both parse workers fail', () async {
      final previousPrimaryWorker =
          json_parser.debugPrimaryValidationWorkerForTesting;
      final previousBundledWorker =
          json_parser.debugBundledValidationWorkerForTesting;
      json_parser.debugPrimaryValidationWorkerForTesting = (_) async {
        throw StateError('simulated primary parse worker failure');
      };
      json_parser.debugBundledValidationWorkerForTesting = (_) async {
        throw StateError('simulated bundled parse worker failure');
      };

      try {
        await expectLater(
          json_parser.parseJsonBatch(['[]']),
          throwsA(isA<StartupDataValidationUnavailable>()),
        );
      } finally {
        json_parser.debugPrimaryValidationWorkerForTesting =
            previousPrimaryWorker;
        json_parser.debugBundledValidationWorkerForTesting =
            previousBundledWorker;
      }
    }, skip: !kIsWeb);
  });

  group('StartupCheckService - data format validation', () {
    test(
      'preserves all format findings when the primary Web worker fails',
      () async {
        _mockStartupValidationWorkerAsset();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'provider_entries',
          '[{"id":"","type":7,"name":null,"configs":[null]}]',
        );
        await prefs.setString(
          'conversations',
          '[{"id":1,"messages":"not-a-list"}]',
        );

        final previousWorker =
            json_parser.debugPrimaryValidationWorkerForTesting;
        final previousBundledWorker =
            json_parser.debugBundledValidationWorkerForTesting;
        json_parser.debugPrimaryValidationWorkerForTesting = (_) async {
          throw StateError('simulated primary worker failure');
        };
        try {
          final issues = await StartupCheckService.validateDataFormats();
          final messages = issues.map((issue) => issue.message).toSet();

          expect(
            messages,
            containsAll([
              'provider_entries[0]: id 字段缺失或为空',
              'provider_entries[0]: type 字段缺失或为空',
              'provider_entries[0]: name 字段缺失或为空',
              'provider_entries[0].configs[0]: 条目不是合法对象，可能会导致解析闪退',
              'conversations[0]: id 字段缺失',
              'conversations[0]: messages 字段不是合法列表',
            ]),
          );

          json_parser.debugBundledValidationWorkerForTesting = (_) async {
            throw StateError('simulated bundled worker failure');
          };
          await expectLater(
            StartupCheckService.validateDataFormats(),
            throwsA(isA<StartupDataValidationUnavailable>()),
          );

          json_parser.debugBundledValidationWorkerForTesting =
              (_) async => '[{}]';
          await expectLater(
            StartupCheckService.validateDataFormats(),
            throwsA(isA<StartupDataValidationUnavailable>()),
          );
        } finally {
          json_parser.debugPrimaryValidationWorkerForTesting = previousWorker;
          json_parser.debugBundledValidationWorkerForTesting =
              previousBundledWorker;
        }
      },
      skip: !kIsWeb,
    );

    test('validates provider_entries JSON structure', () async {
      final prefs = await SharedPreferences.getInstance();
      // Valid provider_entries
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'test_id',
              'type': 'llm',
              'name': 'Test Provider',
              'configs': [],
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      // No issues expected with valid data
      expect(issues.where((i) => i.severity == StartupIssueSeverity.error),
          isEmpty);
    });

    test('detects malformed provider_entries JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('provider_entries', 'not valid json');
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      // Should have at least one error about malformed provider_entries
      expect(
        issues.any((i) =>
            i.severity == StartupIssueSeverity.error &&
            i.message.contains('provider_entries')),
        isTrue,
      );
    });

    test('detects provider_entries with null IDs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': null,
              'type': 'tts',
              'name': 'Broken Provider',
              'configs': [],
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      expect(
        issues.any((i) => i.message.contains('id') && i.message.contains('缺失')),
        isTrue,
      );
    });

    test('non-string id/type/name values are reported as issues, not crashes',
        () async {
      // 损坏数据：id 为 int、type 为 Map、name 为 List。
      // 旧代码 `(entry['id'] as String?)` 强转抛 TypeError 中断整个验证。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 123,
              'type': {'nested': true},
              'name': ['a', 'b'],
              'configs': [],
            },
            {
              'id': 'valid',
              'type': 'llm',
              'name': 'Valid',
              'configs': [],
            },
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();

      // 不崩溃：损坏条目被报告，且后续合法条目没有被漏检。
      expect(issues, isA<List<StartupIssue>>());
      final idIssues = issues
          .where((i) => i.message.contains('id') && i.message.contains('缺失'));
      expect(idIssues, isNotEmpty);
      expect(
        issues
            .any((i) => i.message.contains('type') && i.message.contains('缺失')),
        isTrue,
      );
      expect(
        issues
            .any((i) => i.message.contains('name') && i.message.contains('缺失')),
        isTrue,
      );
    });

    test('conversations with non-string id are reported, not crashes',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'conversations',
          jsonEncode([
            {'id': 42, 'messages': []},
            {'id': 'conv_valid', 'messages': []},
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();

      expect(issues, isA<List<StartupIssue>>());
      expect(
        issues.any((i) =>
            i.dataKey == 'conversations' &&
            i.message.contains('id') &&
            i.message.contains('缺失')),
        isTrue,
      );
    });

    test('non-list configs/models fields are reported, not crashes', () async {
      // 损坏数据：configs 为 Map、models 为 String。
      // 旧代码 `entry['configs'] as List?` 强转抛 TypeError 中断整个验证。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'p1',
              'type': 'llm',
              'name': 'P1',
              'configs': {'not': 'a list'},
            },
            {
              'id': 'p2',
              'type': 'llm',
              'name': 'P2',
              'configs': [
                {
                  'providerName': 'C1',
                  'host': '',
                  'key': '',
                  'models': 'not-a-list',
                },
              ],
            },
            {
              'id': 'p3',
              'type': 'llm',
              'name': 'P3',
              'configs': [],
            },
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();

      // 不崩溃：两个损坏字段都被上报，且合法条目没有被漏检。
      expect(issues, isA<List<StartupIssue>>());
      expect(
        issues.any((i) =>
            i.message.contains('configs') && i.message.contains('不是合法列表')),
        isTrue,
        reason: 'configs 非 List 应被上报为问题',
      );
      expect(
        issues.any((i) =>
            i.message.contains('models') && i.message.contains('不是合法列表')),
        isTrue,
        reason: 'models 非 List 应被上报为问题',
      );
      // 合法条目 p3 不应产生错误
      expect(
        issues.where((i) => i.severity == StartupIssueSeverity.error),
        isNotEmpty,
      );
    });

    test('validates conversation data structure', () async {
      final prefs = await SharedPreferences.getInstance();
      // Valid conversations
      await prefs.setString(
          'conversations',
          jsonEncode([
            {
              'id': 'conv1',
              'title': 'Test',
              'messages': [],
              'createdAt': DateTime.now().toIso8601String(),
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      expect(issues.where((i) => i.severity == StartupIssueSeverity.error),
          isEmpty);
    });

    test('detects corrupted conversation data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('conversations', '{broken');
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.validateDataFormats();
      expect(
        issues.any((i) =>
            i.severity == StartupIssueSeverity.error &&
            i.message.contains('conversations')),
        isTrue,
      );
    });
  });

  group('StartupCheckService - data integrity checks', () {
    test(
      'keeps the Web event loop responsive while checking large provider entries',
      () async {
        _mockStartupValidationWorkerAsset();
        final providerEntries = List.generate(
          75000,
          (_) => {'type': 'llm'},
        )..add({'type': 'unknown_provider'});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'provider_entries',
          jsonEncode(providerEntries),
        );

        var integrityCheckCompleted = false;
        var integrityFallbackUsed = false;
        final eventLoopTick = Completer<bool>();
        final previousDebugPrint = debugPrint;
        final previousWorker =
            json_parser.debugPrimaryValidationWorkerForTesting;
        final previousBundledWorker =
            json_parser.debugBundledValidationWorkerForTesting;
        var primaryWorkerFailed = false;
        json_parser.debugPrimaryValidationWorkerForTesting = (_) async {
          primaryWorkerFailed = true;
          throw StateError('simulated primary worker failure');
        };
        debugPrint = (message, {wrapWidth}) {
          if (message?.contains('Web worker integrity check failed') == true ||
              message?.contains('Isolate check failed') == true) {
            integrityFallbackUsed = true;
          }
          previousDebugPrint(message, wrapWidth: wrapWidth);
        };
        late List<StartupIssue> issues;
        try {
          final integrityCheck = StartupCheckService.checkDataIntegrity();
          Timer(const Duration(milliseconds: 1), () {
            eventLoopTick.complete(!integrityCheckCompleted);
          });
          issues = await integrityCheck;
        } finally {
          integrityCheckCompleted = true;
          debugPrint = previousDebugPrint;
          json_parser.debugPrimaryValidationWorkerForTesting = previousWorker;
          json_parser.debugBundledValidationWorkerForTesting =
              previousBundledWorker;
        }

        expect(primaryWorkerFailed, isTrue);
        expect(
          await eventLoopTick.future,
          isTrue,
          reason:
              'large Web integrity checks should yield to the browser event loop',
        );
        expect(
          integrityFallbackUsed,
          isFalse,
          reason:
              'Web integrity checks should not fall back to main-thread parsing',
        );
        expect(issues, hasLength(1));
        expect(issues.single.dataKey, 'provider_entries');
        expect(
          issues.single.message,
          'provider_entries[75000]: 未知的供应商类型 "unknown_provider"，'
          '应用可能无法正常使用该供应商',
        );
      },
      skip: !kIsWeb,
    );

    test('detects orphaned provider entries with missing type registration',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'unknown_provider',
              'type': 'nonexistent_type',
              'name': 'Unknown',
              'configs': [],
            }
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.checkDataIntegrity();
      expect(
        issues.any((i) => i.message.contains('nonexistent_type')),
        isTrue,
      );
    });

    test('non-string type values do not crash or abort the whole check',
        () async {
      // 损坏数据：type 为 int/Map 等非字符串。旧代码 `as String?` 强转
      // 抛 TypeError 导致整个完整性检查中断（其余条目全部漏检）。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {'id': 'bad_type', 'type': 123, 'name': 'Bad'},
            {
              'id': 'bad_type2',
              'type': {'nested': true},
              'name': 'Bad2'
            },
            {
              'id': 'valid_unknown',
              'type': 'unknown_type',
              'name': 'Unknown',
            },
          ]));
      await prefs.setInt('data_format_version', 1);

      final issues = await StartupCheckService.checkDataIntegrity();

      // 不崩溃，且合法的未知类型条目仍然被检查到。
      expect(issues, isA<List<StartupIssue>>());
      expect(
        issues.any((i) => i.message.contains('unknown_type')),
        isTrue,
        reason: '非字符串 type 条目应被跳过而非中断整个检查',
      );
    });
  });

  group('StartupCheckService - native Isolate failures', () {
    test(
      'fails closed when format validation cannot start its Isolate',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('provider_entries', '{broken');
        final previousRunner = debugStartupIsolateRunnerForTesting;
        debugStartupIsolateRunnerForTesting =
            (_) async => throw StateError('simulated Isolate failure');

        try {
          await expectLater(
            StartupCheckService.validateDataFormats(),
            throwsA(isA<StartupDataValidationUnavailable>()),
          );
        } finally {
          debugStartupIsolateRunnerForTesting = previousRunner;
        }
      },
      skip: kIsWeb,
    );

    test(
      'fails closed when integrity checking cannot start its Isolate',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'provider_entries',
          '[{"id":"p1","type":"unregistered","name":"P1"}]',
        );
        final previousRunner = debugStartupIsolateRunnerForTesting;
        debugStartupIsolateRunnerForTesting =
            (_) async => throw StateError('simulated Isolate failure');

        try {
          await expectLater(
            StartupCheckService.checkDataIntegrity(),
            throwsA(isA<StartupDataValidationUnavailable>()),
          );
        } finally {
          debugStartupIsolateRunnerForTesting = previousRunner;
        }
      },
      skip: kIsWeb,
    );
  });

  group('StartupCheckService - checkFormatVersion tests', () {
    test('runs format version check and returns result', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'provider_entries',
          jsonEncode([
            {
              'id': 'test_llm',
              'type': 'llm',
              'name': 'Test',
              'configs': [],
            }
          ]));
      await prefs.setString('conversations', '[]');

      final result = await StartupCheckService.checkFormatVersion();
      expect(result, isNotNull);
      // On fresh test setup without version, migration will be needed
      expect(result.needsMigration, isTrue);
    });

    test('handles empty data gracefully (no errors)', () async {
      final formatIssues = await StartupCheckService.validateDataFormats();
      final integrityIssues = await StartupCheckService.checkDataIntegrity();
      expect(formatIssues, isEmpty);
      expect(integrityIssues, isEmpty);
    });
  });

  group('StartupCheckService - runs in test mode (sync fallback)', () {
    test('validateDataFormats detects nested non-Map entries in test mode',
        () async {
      // provider_entries has voices list containing non-Map entry 'not_a_map'
      SharedPreferences.setMockInitialValues({
        'data_format_version': 1,
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [
              {
                'models': [
                  {
                    'customParams': [],
                    'voices': ['not_a_map'],
                  },
                ],
              },
            ],
          },
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();

      // Should detect that voices[0] is not a valid Map object
      final voicesIssues = issues.where(
        (i) => i.message.contains('voices'),
      );
      expect(voicesIssues, isNotEmpty,
          reason: 'Should detect non-Map entry in voices list');
    });
  });
}
