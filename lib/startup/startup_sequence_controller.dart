import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, immutable, visibleForTesting;

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
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

  StartupSequenceController({AppLocalizations Function()? localizations})
      : _localizations =
            localizations ?? (() => appLocalizationsForLocale(null));

  final AppLocalizations Function() _localizations;
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
      _events.add(
        StartupCheckProgress(
          message: message,
          detail: detail,
          isWorking: isWorking,
          blockedMessage: blockedMessage,
        ),
      );
    }
  }

  Future<StartupCheckOutcome> run() async {
    if (_hasRun) {
      throw StateError('StartupSequenceController can only run once.');
    }
    _hasRun = true;
    final l10n = _localizations();
    final stopwatch = Stopwatch()..start();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // This noncritical update hint must not block data-safety checks.
      try {
        if (await hasPendingUpdateRestart()) {
          debugPrint(
            '[StartupSequenceController] Clearing update restart flag',
          );
          await clearPendingUpdateRestart();
        }
      } catch (error) {
        debugPrint(
          '[StartupSequenceController] Update flag read failed: $error',
        );
      }

      _publish(l10n.startupProgressDataSafety, '0/5');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final versionAhead = await StartupCheckService.checkVersionAhead();
      if (versionAhead != null) {
        debugPrint(
          '[StartupSequenceController] Data version is ahead: $versionAhead',
        );
        final blocked = l10n.startupSafetyNewerDataVersion(versionAhead);
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }

      final repairResult = await DataSafetyManager.checkAndRepair();
      if (repairResult.skippedDueToFreeze || repairResult.frozen) {
        final status = await DataSafetyManager.loadStatus();
        final blocked = repairResult.statusUnreadable || status.isUnreadable
            ? l10n.startupSafetyStatusUnreadable
            : (status.failedMigration != null)
                ? l10n.startupSafetyMigrationFailedNoChanges(
                    status.failedMigration!,
                  )
                : l10n.startupSafetyDataCorrupted;
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }
      if (repairResult.repaired) {
        debugPrint('[StartupSequenceController] Data restored from snapshot');
      }
      unawaited(DataSafetyManager.cleanupOrphans().catchError((_) {}));

      _publish(l10n.startupProgressFormatVersion, '1/5');
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
          '[StartupSequenceController] checkFormatVersion failed: $error',
        );
        if (error is StartupPreferencesUnavailable ||
            error is StartupDataValidationUnavailable) {
          rethrow;
        }
        await AppLogService.error(
          'StartupSequenceController',
          '检查数据格式版本失败',
          error,
        );
        rethrow;
      }

      final postMigrationStatus = await DataSafetyManager.loadStatus();
      if (postMigrationStatus.isFrozen || postMigrationStatus.isUnreadable) {
        final blocked = postMigrationStatus.isUnreadable
            ? l10n.startupSafetyStatusUnreadableAfterChecks
            : (postMigrationStatus.failedMigration != null)
                ? l10n.startupSafetyMigrationFailedRestored(
                    postMigrationStatus.failedMigration!,
                  )
                : l10n.startupSafetyDataCorrupted;
        debugPrint('[StartupSequenceController] Migration left data frozen');
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }
      await Future<void>.delayed(
        const Duration(milliseconds: _statusVisibilityDelayMs),
      );

      _publish(l10n.startupProgressDataFormat, '2/5');
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
          '[StartupSequenceController] validateDataFormats failed: $error',
        );
        if (error is StartupDataValidationUnavailable ||
            error is StartupPreferencesUnavailable) {
          rethrow;
        }
        await AppLogService.error(
          'StartupSequenceController',
          '验证数据格式失败',
          error,
        );
        rethrow;
      }
      await Future<void>.delayed(
        const Duration(milliseconds: _statusVisibilityDelayMs),
      );

      _publish(l10n.startupProgressDataIntegrity, '3/5');
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
          '[StartupSequenceController] checkDataIntegrity failed: $error',
        );
        if (error is StartupDataValidationUnavailable ||
            error is StartupPreferencesUnavailable) {
          rethrow;
        }
        await AppLogService.error(
          'StartupSequenceController',
          '检查数据完整性失败',
          error,
        );
        rethrow;
      }
      await Future<void>.delayed(
        const Duration(milliseconds: _statusVisibilityDelayMs),
      );

      _publish(l10n.startupProgressResults, '4/5');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final allIssues = <StartupIssue>[...formatIssues, ...integrityIssues];
      String? warning;
      if (allIssues.isNotEmpty) {
        for (final issue in allIssues) {
          debugPrint(
            '[StartupSequenceController] ${issue.severity.name}: ${issue.message}',
          );
        }
        final errors = allIssues
            .where((issue) => issue.severity == StartupIssueSeverity.error)
            .map((issue) => startupIssueDisplayMessage(issue.message, l10n))
            .toList();
        final warnings = allIssues
            .where((issue) => issue.severity == StartupIssueSeverity.warning)
            .map((issue) => startupIssueDisplayMessage(issue.message, l10n))
            .toList();
        if (errors.isNotEmpty || warnings.isNotEmpty) {
          final summary = StringBuffer();
          if (errors.isNotEmpty) {
            summary.writeln(l10n.startupWarningErrorCount(errors.length));
            for (final message in errors) {
              summary.writeln('  • $message');
            }
          }
          if (warnings.isNotEmpty) {
            if (summary.isNotEmpty) summary.writeln();
            summary.writeln(l10n.startupWarningWarningCount(warnings.length));
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
            ? l10n.startupProgressCompleteWithWarnings(warning)
            : migrationResult.needsMigration
                ? l10n.startupProgressCompleteAfterMigration
                : l10n.startupProgressReady,
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
            ? l10n.startupSafetyPreferencesUnavailable
            : l10n.startupSafetyValidationUnavailable;
        _publish('', '', isWorking: false, blockedMessage: blocked);
        return StartupCheckOutcome(blockedMessage: blocked);
      }
      final message = l10n.startupSafetyCheckFailed(error.toString());
      _publish(message, '', isWorking: false, blockedMessage: message);
      return StartupCheckOutcome(
        failure: error.toString(),
        blockedMessage: message,
      );
    }
  }
}

/// Localizes a raw startup validation diagnostic for the progress summary.
@visibleForTesting
String startupIssueDisplayMessage(String message, AppLocalizations l10n) {
  if (message == 'provider_entries 数据格式错误：不是合法的 JSON 数组') {
    return l10n.startupIssueProviderEntriesInvalid;
  }
  if (message == 'conversations 数据格式错误：不是合法的 JSON 数组') {
    return l10n.startupIssueConversationsInvalid;
  }

  final providerEntry = RegExp(r'^provider_entries\[(\d+)\]: 条目为 null 或类型无效$')
      .firstMatch(message);
  if (providerEntry != null) {
    return l10n.startupIssueProviderEntryInvalid(providerEntry[1]!);
  }
  final providerField = RegExp(
    r'^provider_entries\[(\d+)\]: (id|type|name) 字段缺失或为空$',
  ).firstMatch(message);
  if (providerField != null) {
    final index = providerField[1]!;
    return switch (providerField[2]) {
      'id' => l10n.startupIssueProviderIdMissing(index),
      'type' => l10n.startupIssueProviderTypeMissing(index),
      _ => l10n.startupIssueProviderNameMissing(index),
    };
  }
  final providerList = RegExp(
    r'^provider_entries\[(\d+)\]\.([^:]+): 字段不是合法列表$',
  ).firstMatch(message);
  if (providerList != null) {
    return l10n.startupIssueProviderListInvalid(
      providerList[1]!,
      providerList[2]!,
    );
  }
  final nestedProviderItem = RegExp(
    r'^provider_entries\[(\d+)\]\.([A-Za-z]+)\[(\d+)\]: 条目不是合法对象，可能会导致解析闪退$',
  ).firstMatch(message);
  if (nestedProviderItem != null) {
    return l10n.startupIssueProviderNestedItemInvalid(
      nestedProviderItem[1]!,
      '${nestedProviderItem[2]}[${nestedProviderItem[3]}]',
    );
  }
  final conversationEntry =
      RegExp(r'^conversations\[(\d+)\]: 会话为 null 或类型无效$').firstMatch(message);
  if (conversationEntry != null) {
    return l10n.startupIssueConversationInvalid(conversationEntry[1]!);
  }
  final conversationField = RegExp(
    r'^conversations\[(\d+)\]: (id|messages) 字段(缺失|不是合法列表)$',
  ).firstMatch(message);
  if (conversationField != null) {
    final index = conversationField[1]!;
    if (conversationField[2] == 'id') {
      return l10n.startupIssueConversationIdMissing(index);
    }
    return conversationField[3] == '缺失'
        ? l10n.startupIssueConversationMessagesMissing(index)
        : l10n.startupIssueConversationMessagesInvalid(index);
  }
  final unknownProvider = RegExp(
    r'^provider_entries\[(\d+)\]: 未知的供应商类型 "([\s\S]*)"，应用可能无法正常使用该供应商$',
  ).firstMatch(message);
  if (unknownProvider != null) {
    return l10n.startupIssueUnknownProviderType(
      unknownProvider[1]!,
      unknownProvider[2]!,
    );
  }
  return message;
}
