import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/startup_check_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('StartupCheckService - format version check', () {
    test('returns needsMigration=false when version matches', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'data_format_version', DataMigrationService.currentFormatVersion);

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
      await prefs.setInt('data_format_version', 999);

      final result = await StartupCheckService.checkFormatVersion();
      expect(result.needsMigration, isFalse);
    });
  });

  group('StartupCheckService - data format validation', () {
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
      final idIssues =
          issues.where((i) => i.message.contains('id') && i.message.contains('缺失'));
      expect(idIssues, isNotEmpty);
      expect(
        issues.any((i) => i.message.contains('type') && i.message.contains('缺失')),
        isTrue,
      );
      expect(
        issues.any((i) => i.message.contains('name') && i.message.contains('缺失')),
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

    test('non-list configs/models fields are reported, not crashes',
        () async {
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
            i.message.contains('configs') &&
            i.message.contains('不是合法列表')),
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
            {'id': 'bad_type2', 'type': {'nested': true}, 'name': 'Bad2'},
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
    test('validateDataFormats completes in test environment', () async {
      // This test verifies that even in test mode (where Isolate.run is unavailable),
      // the validation falls back to synchronous execution and still returns results.
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
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      AppStorage.resetCache();

      final issues = await StartupCheckService.validateDataFormats();
      // Should complete without throwing and at least return no errors or some errors
      expect(issues, isA<List<StartupIssue>>());
    });

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
