import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, immutable;

import '../services/app_log_service.dart';
import '../services/data_migration_service.dart';
import '../services/data_safety_manager.dart';
import '../services/startup_data_validation_unavailable.dart';
import '../services/startup_preferences.dart';
import '../providers/update_provider.dart';
import 'startup_check_service.dart';

/// UI-facing progress emitted by the independent startup check controller.
@immutable
class StartupCheckProgress {
  final String message;
  final String? detail;
  final bool isWorking;
  final String? blockedMessage;

  const StartupCheckProgress({
    required this.message,
    this.detail,
    this.isWorking = true,
    this.blockedMessage,
  });
}

/// Result of the backend startup checks. UI-specific actions such as dialogs
/// and route transitions remain owned by StartupApp.
@immutable
class StartupCheckOutcome {
  final bool didMigrate;
  final String? warning;
  final String? failure;
  final String? blockedMessage;

  const StartupCheckOutcome({
    this.didMigrate = false,
    this.warning,
    this.failure,
    this.blockedMessage,
  });
}

/// Runs startup data checks independently from the widget tree and publishes
/// progress as events. The UI can render or animate without owning check flow.
class StartupSequenceController {
  static const int _minimumDisplayMs = 1500;
  static const int _statusVisibilityDelayMs = 150;

  final StreamController<StartupCheckProgress> _events =
      StreamController<StartupCheckProgress>.broadcast(sync: true);
  bool _hasRun = false;

  Stream<StartupCheckProgress> get progress => _events.stream;

  void dispose() {
    _events.close();
  }

  void _publish(
    String message,
    String detail, {
    bool isWorking = true,
    String? blockedMessage,
  }) {
    if (!_events.isClosed) {
      _events.add(StartupCheckProgress(
        message: message,
        detail: detail,
        isWorking: isWorking,
        blockedMessage: blockedMessage,
      ));
    }
  }

  Future<StartupCheckOutcome> run() async {
    if (_hasRun) {
      throw StateError('StartupSequenceController can only run once.');
    }
    _hasRun = true;
    final stopwatch = Stopwatch()..start();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // This noncritical update hint must not block data-safety checks.
      try {
        if (await hasPendingUpdateRestart()) {
          debugPrint(
              '[StartupSequenceController] Clearing update restart flag');
          await clearPendingUpdateRestart();
        }
      } catch (error) {
        debugPrint(
            '[StartupSequenceController] Update flag read failed: $error');
      }

      _publish('正在检查数据安全...', '0/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final versionAhead = await StartupCheckService.checkVersionAhead();
      if (versionAhead != null) {
        debugPrint(
            '[StartupSequenceController] Data version is ahead: $versionAhead');
        final blocked = '数据由更新版本的应用创建（$versionAhead）。\n\n'
            '当前版本无法安全读取这些数据。请安装最新版本的应用，'
            '数据未做任何改动。';
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }

      final repairResult = await DataSafetyManager.checkAndRepair();
      if (repairResult.skippedDueToFreeze || repairResult.frozen) {
        final status = await DataSafetyManager.loadStatus();
        final blocked = repairResult.statusUnreadable || status.isUnreadable
            ? '无法确认数据安全状态（状态标记无法读取或格式无效）。\n\n'
                '为避免覆盖可能存在的冻结状态，应用已阻止启动，未执行数据修复或格式迁移。'
                '请先使用「导出数据」保存数据文件，然后退出应用并修复状态标记后重试。'
            : (status.failedMigration != null)
                ? '数据格式迁移失败（${status.failedMigration}）。\n\n'
                    '为保护数据未做任何改动。请回退到旧版本应用，'
                    '或等待修复版本发布后再升级。'
                : '数据损坏且无法自动修复。\n\n'
                    '应用已冻结以防止进一步破坏。请使用「导出数据」'
                    '保存数据文件，然后手动导入或重新安装。';
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }
      if (repairResult.repaired) {
        debugPrint('[StartupSequenceController] Data restored from snapshot');
      }
      unawaited(DataSafetyManager.cleanupOrphans().catchError((_) {}));

      _publish('正在检查数据格式版本...', '1/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await AppLogService.info('StartupSequenceController', '开始检查数据格式版本');

      MigrationResult migrationResult;
      try {
        migrationResult = await StartupCheckService.checkFormatVersion();
        await AppLogService.info(
          'StartupSequenceController',
          '数据格式版本检查完成: needsMigration=${migrationResult.needsMigration}',
        );
      } catch (error) {
        debugPrint(
            '[StartupSequenceController] checkFormatVersion failed: $error');
        if (error is StartupPreferencesUnavailable ||
            error is StartupDataValidationUnavailable) {
          rethrow;
        }
        await AppLogService.error(
          'StartupSequenceController',
          '检查数据格式版本失败',
          error,
        );
        migrationResult = const MigrationResult(needsMigration: false);
      }

      final postMigrationStatus = await DataSafetyManager.loadStatus();
      if (postMigrationStatus.isFrozen || postMigrationStatus.isUnreadable) {
        final blocked = postMigrationStatus.isUnreadable
            ? '无法确认数据安全状态（状态标记无法读取或格式无效）。\n\n'
                '应用已停止继续启动。请先使用「导出数据」保存数据文件，'
                '然后退出应用并修复状态标记后重试。'
            : (postMigrationStatus.failedMigration != null)
                ? '数据格式迁移失败（${postMigrationStatus.failedMigration}）。\n\n'
                    '已自动恢复到迁移前的数据。为保护数据，请回退到旧版本应用，'
                    '或等待修复版本发布后再升级。'
                : '数据损坏且无法自动修复。\n\n'
                    '应用已冻结以防止进一步破坏。请使用「导出数据」'
                    '保存数据文件，然后手动导入或重新安装。';
        debugPrint('[StartupSequenceController] Migration left data frozen');
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }
      await Future<void>.delayed(
        const Duration(milliseconds: _statusVisibilityDelayMs),
      );

      _publish('正在验证数据格式...', '2/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await AppLogService.info('StartupSequenceController', '开始验证数据格式');
      List<StartupIssue> formatIssues;
      try {
        formatIssues = await StartupCheckService.validateDataFormats();
        await AppLogService.info(
          'StartupSequenceController',
          '数据格式验证完成: 发现 ${formatIssues.length} 个问题',
        );
      } catch (error) {
        debugPrint(
            '[StartupSequenceController] validateDataFormats failed: $error');
        if (error is StartupDataValidationUnavailable ||
            error is StartupPreferencesUnavailable) {
          rethrow;
        }
        await AppLogService.error(
          'StartupSequenceController',
          '验证数据格式失败',
          error,
        );
        formatIssues = <StartupIssue>[];
      }
      await Future<void>.delayed(
        const Duration(milliseconds: _statusVisibilityDelayMs),
      );

      _publish('正在检查数据完整性...', '3/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await AppLogService.info('StartupSequenceController', '开始检查数据完整性');
      List<StartupIssue> integrityIssues;
      try {
        integrityIssues = await StartupCheckService.checkDataIntegrity();
        await AppLogService.info(
          'StartupSequenceController',
          '数据完整性检查完成: 发现 ${integrityIssues.length} 个问题',
        );
      } catch (error) {
        debugPrint(
            '[StartupSequenceController] checkDataIntegrity failed: $error');
        if (error is StartupDataValidationUnavailable ||
            error is StartupPreferencesUnavailable) {
          rethrow;
        }
        await AppLogService.error(
          'StartupSequenceController',
          '检查数据完整性失败',
          error,
        );
        integrityIssues = <StartupIssue>[];
      }
      await Future<void>.delayed(
        const Duration(milliseconds: _statusVisibilityDelayMs),
      );

      _publish('正在处理检查结果...', '4/5');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final allIssues = <StartupIssue>[...formatIssues, ...integrityIssues];
      String? warning;
      if (allIssues.isNotEmpty) {
        for (final issue in allIssues) {
          debugPrint(
              '[StartupSequenceController] ${issue.severity.name}: ${issue.message}');
        }
        final errors = allIssues
            .where((issue) => issue.severity == StartupIssueSeverity.error)
            .map((issue) => issue.message)
            .toList();
        final warnings = allIssues
            .where((issue) => issue.severity == StartupIssueSeverity.warning)
            .map((issue) => issue.message)
            .toList();
        if (errors.isNotEmpty || warnings.isNotEmpty) {
          final summary = StringBuffer();
          if (errors.isNotEmpty) {
            summary.writeln('发现 ${errors.length} 个数据问题:');
            for (final message in errors) {
              summary.writeln('  • $message');
            }
          }
          if (warnings.isNotEmpty) {
            if (summary.isNotEmpty) summary.writeln();
            summary.writeln('${warnings.length} 个警告:');
            for (final message in warnings) {
              summary.writeln('  • $message');
            }
          }
          warning = summary.toString().trim();
        }
      }

      final remaining = _minimumDisplayMs - stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }
      _publish(
        warning != null
            ? '启动完成（注意: $warning）'
            : migrationResult.needsMigration
                ? '数据检查完成，准备启动应用'
                : '准备启动应用',
        '5/5',
        isWorking: false,
      );
      return StartupCheckOutcome(
        didMigrate: migrationResult.needsMigration,
        warning: warning,
      );
    } catch (error, stack) {
      debugPrint('[StartupSequenceController] Startup checks failed: $error');
      debugPrint('[StartupSequenceController] Stack: $stack');
      if (error is StartupDataValidationUnavailable ||
          error is StartupPreferencesUnavailable) {
        final blocked = error is StartupPreferencesUnavailable
            ? '无法读取启动检查所需的偏好设置，应用已阻止继续启动以保护数据。'
                '\n\n请检查存储空间或权限后重新打开应用。'
            : '无法完成启动数据安全检查，应用已阻止继续启动以保护数据。'
                '\n\n请检查浏览器设置并重新打开应用。';
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }
      final message = '启动检查失败: ${error.toString()}';
      _publish(message, '', isWorking: false);
      return StartupCheckOutcome(failure: error.toString());
    }
  }
}
