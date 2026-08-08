import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/startup/startup_check_service.dart';

/// Constants matching the production values in startup_app.dart.
const _preCheckDelayMs = 50;
const _postCheckDelayMs = 150;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('StartupApp - progress visibility timing', () {
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
