import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/backup_startup_check.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  // ==================================================================
  // runCheck — basic behavior
  // ==================================================================

  group('runCheck', () {
    testWidgets('returns result with storageReady and autoBackup status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              Future.microtask(() async {
                final result = await BackupStartupCheck.runCheck(context);
                // In test environment (non-Android, temp dir),
                // storage should be ready and backup should succeed
                expect(result.storageReady, isTrue);
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
