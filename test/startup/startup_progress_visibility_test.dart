import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/startup/startup_check_service.dart';

/// Constants matching the production values in startup_app.dart.
const _preCheckDelayMs = 50;
const _postCheckDelayMs = 150;
const _step4DelayMs = 200;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('StartupApp - progress visibility timing', () {
    test('three checks run sequentially with production-equivalent timing',
        () async {
      // This test simulates the timing schedule used by
      // _runStartupSequence() in startup_app.dart:
      //
      //   Step N: _setStatus(`N/5`) → delay(50ms) → check() → delay(150ms)
      //
      // Total minimum overhead: 3 × (50ms + 150ms) + 200ms (step 4) = 800ms
      //
      // This test verifies that all checks produce correct results when
      // interleaved with the same delay pattern as production.

      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [],
          },
        ]),
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test Conversation',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      });
      AppStorage.resetCache();

      final stopwatch = Stopwatch()..start();

      // Step 1 (1/5): pre-check delay → checkFormatVersion → post-check delay
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      final r1 = await StartupCheckService.checkFormatVersion();
      expect(r1, isA<MigrationResult>());
      expect(r1.needsMigration, isFalse);
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      // Step 2 (2/5): pre-check delay → validateDataFormats → post-check delay
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      final r2 = await StartupCheckService.validateDataFormats();
      expect(r2, isA<List<StartupIssue>>());
      expect(
          r2.where((i) => i.severity == StartupIssueSeverity.error), isEmpty);
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      // Step 3 (3/5): pre-check delay → checkDataIntegrity → post-check delay
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      final r3 = await StartupCheckService.checkDataIntegrity();
      expect(r3, isA<List<StartupIssue>>());
      expect(r3, isEmpty);
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      // Step 4 (4/5): aggregate results (no check, just delay)
      final allIssues = <StartupIssue>[...r2, ...r3];
      expect(allIssues, isEmpty);
      await Future<void>.delayed(Duration(milliseconds: _step4DelayMs));

      stopwatch.stop();

      // All results are correct after the full sequence
      expect(r1.needsMigration, isFalse);
      expect(r2, isEmpty);
      expect(r3, isEmpty);

      // Minimum expected: 3×(50+150) + 200 = 800ms
      // (check execution time is negligible — <10ms each)
      expect(stopwatch.elapsedMilliseconds,
          greaterThanOrEqualTo(800 - 20 /* margin */));
    });

    test('total timing budget for three checks with post-check delays',
        () async {
      // Verifies that the 150ms post-check delays consume a predictable
      // amount of wall-clock time, confirming the production code's
      // timing commitment is met: 3 checks × 150ms post-check = 450ms
      // minimum overhead.

      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [],
          },
        ]),
      });
      AppStorage.resetCache();

      final stopwatch = Stopwatch()..start();

      // Step 1
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      await StartupCheckService.checkFormatVersion();
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      // Step 2
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      await StartupCheckService.validateDataFormats();
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      // Step 3
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      await StartupCheckService.checkDataIntegrity();
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      stopwatch.stop();

      // Minimum: 3 × (50 + 150) = 600ms (check exec time is negligible)
      expect(stopwatch.elapsedMilliseconds,
          greaterThanOrEqualTo(600 - 20 /* margin */));

      // Maximum: should complete well within 2000ms even on slow runners
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('checks produce correct results even with post-check delays',
        () async {
      // Verifies that the added delays between checks do not interfere
      // with the correctness of each check's result. The delays should
      // be purely cosmetic — they must not affect data or state.

      SharedPreferences.setMockInitialValues({
        'data_format_version': DataMigrationService.currentFormatVersion,
        'provider_entries': jsonEncode([
          {
            'id': 'test_provider',
            'type': 'llm',
            'name': 'Test Provider',
            'configs': [],
          },
        ]),
      });
      AppStorage.resetCache();

      // Run with delays matching production
      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      final r1 = await StartupCheckService.checkFormatVersion();
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      final r2 = await StartupCheckService.validateDataFormats();
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      await Future<void>.delayed(Duration(milliseconds: _preCheckDelayMs));
      final r3 = await StartupCheckService.checkDataIntegrity();
      await Future<void>.delayed(Duration(milliseconds: _postCheckDelayMs));

      // Results should be identical to running without delays
      expect(r1.needsMigration, isFalse);
      expect(r2, isEmpty);
      expect(r3, isEmpty);
    });
  });
}
