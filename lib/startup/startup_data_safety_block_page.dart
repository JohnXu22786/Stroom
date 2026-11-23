import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../l10n/app_localizations.dart';
import '../providers/update_provider.dart';
import '../services/backup_service.dart';
import '../widgets/constrained_text.dart';
import '../widgets/update_dialog.dart';
import 'startup_sequence_controller.dart';
import 'startup_update_recovery.dart';

/// 数据安全阻断页：版本哨兵（数据由更新版本创建）或冻结
/// （迁移失败 / 无法自动修复）时全屏展示，拒绝进入主应用。
///
/// 只读页面：提供「导出数据」（全量导出到用户选择的位置，只读操作）
/// 与「退出应用」，绝不提供任何写入入口，防止破坏被保护的数据。
class StartupDataSafetyBlockPage extends ConsumerStatefulWidget {
  final StartupBlock block;
  final VoidCallback? onExit;

  const StartupDataSafetyBlockPage({
    super.key,
    required this.block,
    this.onExit,
  });

  @override
  ConsumerState<StartupDataSafetyBlockPage> createState() =>
      _StartupDataSafetyBlockPageState();
}

class _StartupDataSafetyBlockPageState
    extends ConsumerState<StartupDataSafetyBlockPage> {
  bool _exporting = false;
  bool _loadingRollback = false;
  bool _rollbackLookupComplete = false;
  StartupRollbackCandidate? _rollbackCandidate;

  @override
  void initState() {
    super.initState();
    if (widget.block.canOfferVersionRecovery) {
      unawaited(_loadRollbackCandidate());
    }
  }

  Future<void> _loadRollbackCandidate() async {
    final sourceVersion = widget.block.recoverySourceVersion;
    if (sourceVersion == null) return;
    final candidate = await ref
        .read(updateProvider.notifier)
        .findStartupRollbackCandidate(sourceVersion);
    if (mounted) {
      setState(() {
        _rollbackCandidate = candidate;
        _rollbackLookupComplete = true;
      });
    }
  }

  Future<void> _chooseRollbackCandidate() async {
    final candidate = _rollbackCandidate;
    if (candidate == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmedCandidate =
        await showModalBottomSheet<StartupRollbackCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.sizeOf(context);
        final wide = media.width >= 600;
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? (media.width - 48).clamp(0, 640) : media.width,
                maxHeight: (media.height * 0.8).clamp(0, 640),
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.startupSafetyRollbackButton,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: ListTile(
                          leading: const Icon(Icons.recommend_outlined),
                          title: Text(candidate.version),
                          subtitle: Text(
                            l10n.startupSafetyRollbackRecommended,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.startupSafetyRollbackReleaseNotes,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            candidate.releaseNotes.isEmpty
                                ? l10n.startupSafetyRollbackNoReleaseNotes
                                : candidate.releaseNotes,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, candidate),
                        child: Text(l10n.startupSafetyRollbackContinue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || confirmedCandidate == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.startupSafetyRollbackConfirmTitle),
        content: Text(
          l10n.startupSafetyRollbackConfirmMessage(candidate.version),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.startupSafetyRollbackContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loadingRollback = true);
    await ref.read(updateProvider.notifier).downloadUpdate(
          downloadUrlOverride: confirmedCandidate.downloadUrl,
          targetVersion: confirmedCandidate.version,
          recordStartupAttempt: false,
        );
    if (!mounted) return;
    setState(() => _loadingRollback = false);
    final error = ref.read(updateProvider).downloadError;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _checkForUpdate() async {
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ConstrainedText(
                l10n.startupSafetyCheckingUpdates,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: Duration(days: 1),
      ),
    );

    await ref.read(updateProvider.notifier).checkForUpdate();
    if (!mounted) return;
    final state = ref.read(updateProvider);
    snackBar.close();

    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (state.updateAvailable) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => const UpdateDialog(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.startupSafetyUpToDate),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      // 双平台统一路径：原生走 FilePicker 保存；Web 走内存构建 +
      // 浏览器下载（exportBackup 内部处理）。
      final exported = await BackupService.exportBackup(
        context,
        selection: BackupSelection.all,
      );
      if (!mounted || !exported) return;
      // BackupService already shows a localized success message with the saved path.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupServiceExportFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      // 阻断页不允许返回键关闭（数据保护）
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.startupSafetyTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.block.message,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.6,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (widget.block.canOfferVersionRecovery)
                              _buildRollbackButton(),
                            if (!kIsWeb) ...[_buildUpdateButton()],
                            OutlinedButton.icon(
                              onPressed: _exporting ? null : _exportData,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_alt),
                              label: ConstrainedText(
                                l10n.startupSafetyExportButton,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  widget.onExit ?? () => SystemNavigator.pop(),
                              icon: const Icon(Icons.exit_to_app),
                              label: ConstrainedText(
                                l10n.startupSafetyExitButton,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRollbackButton() {
    final l10n = AppLocalizations.of(context)!;
    final loading = _loadingRollback || !_rollbackLookupComplete;
    final candidate = _rollbackCandidate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed:
              candidate == null || loading ? null : _chooseRollbackCandidate,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history),
          label: ConstrainedText(
            l10n.startupSafetyRollbackButton,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (candidate == null && _rollbackLookupComplete) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              l10n.startupSafetyRollbackNoCandidate,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUpdateButton() {
    final isChecking = ref.watch(updateProvider).isChecking;
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: isChecking ? null : _checkForUpdate,
      icon: isChecking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.update),
      label: ConstrainedText(
        l10n.startupSafetyUpdateButton,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
