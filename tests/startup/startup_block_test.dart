import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/data_safety_manager.dart';
import 'package:stroom/startup/startup_sequence_controller.dart';
import 'package:stroom/startup/startup_update_recovery.dart';

void main() {
  test('recovery source requires readable complete frozen migration evidence',
      () {
    const attempt = StartupUpdateAttempt(
      sourceVersion: '0.5.3-hotfix.1',
      targetVersion: '0.5.4-rc.2',
    );
    const confirmed = DataSafetyStatus(
      state: DataSafetyState.frozen,
      frozenByVersion: '0.5.4-rc.2',
      failedMigration: 'chat v1→v2',
      targetFormatVersion: 2,
      preMigrationDataSafe: true,
    );

    expect(
      StartupBlock.eligibleRecoverySourceVersion(
        status: confirmed,
        attempt: attempt,
        runningVersion: '0.5.4-rc.2',
      ),
      '0.5.3-hotfix.1',
    );
    expect(
      StartupBlock.eligibleRecoverySourceVersion(
        status: DataSafetyStatus.unreadable,
        attempt: attempt,
        runningVersion: '0.5.4-rc.2',
      ),
      isNull,
    );
    expect(
      StartupBlock.eligibleRecoverySourceVersion(
        status: const DataSafetyStatus(
          state: DataSafetyState.frozen,
          frozenByVersion: '0.5.4-rc.2',
          failedMigration: 'chat v1→v2',
          targetFormatVersion: 2,
          preMigrationDataSafe: false,
        ),
        attempt: attempt,
        runningVersion: '0.5.4-rc.2',
      ),
      isNull,
      reason: 'failed snapshot restoration cannot establish rollback safety',
    );
    expect(
      StartupBlock.eligibleRecoverySourceVersion(
        status: const DataSafetyStatus(
          state: DataSafetyState.frozen,
          frozenByVersion: '0.5.4-rc.2',
        ),
        attempt: attempt,
        runningVersion: '0.5.4-rc.2',
      ),
      isNull,
      reason: 'generic corruption has no failed migration evidence',
    );
    expect(
      StartupBlock.eligibleRecoverySourceVersion(
        status: confirmed,
        attempt: null,
        runningVersion: '0.5.4-rc.2',
      ),
      isNull,
    );
    expect(
      StartupBlock.eligibleRecoverySourceVersion(
        status: confirmed,
        attempt: const StartupUpdateAttempt(
          sourceVersion: '0.5.3',
          targetVersion: '0.5.4',
        ),
        runningVersion: '0.5.4-rc.2',
      ),
      isNull,
      reason: 'a stale or mismatched update record cannot enable recovery',
    );
  });
}
