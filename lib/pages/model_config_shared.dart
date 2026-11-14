import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tts_models.dart';
import '../providers/tts_config.dart';

import '../widgets/constrained_text.dart';

/// Localized presentation for custom-parameter types; persisted values stay
/// in [ParamType.value].
String localizedParamTypeLabel(AppLocalizations l10n, ParamType type) {
  return switch (type) {
    ParamType.string => l10n.paramTypeStringLabel,
    ParamType.number => l10n.paramTypeNumberLabel,
    ParamType.boolean => l10n.paramTypeBooleanLabel,
    ParamType.json => l10n.paramTypeJsonLabel,
    _ => l10n.paramTypeStringLabel,
  };
}

/// Localized examples for the custom-parameter value field.
String localizedParamTypeDefaultValueHint(
  AppLocalizations l10n,
  ParamType type,
) {
  return switch (type) {
    ParamType.string => l10n.paramTypeStringHint,
    ParamType.number => l10n.paramTypeNumberHint,
    ParamType.boolean => l10n.paramTypeBooleanHint,
    ParamType.json => '${l10n.paramTypeJsonHint}{"key": "value"}',
    _ => '',
  };
}

// ============================================================================
// ToggleButton — reusable toggle button with selected/unselected styling
// ============================================================================

/// A simple toggle button used for boolean selections (yes/no).
class ToggleButton extends StatelessWidget {
  final String label;
  final bool value;
  final bool currentValue;
  final ValueChanged<bool> onChanged;

  const ToggleButton({
    super.key,
    required this.label,
    required this.value,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Trim Section — build + dialogs for audio trim presets
// ============================================================================

/// Displays the trim preset selection and management UI.
class TrimSection extends ConsumerWidget {
  final String? selectedPresetId;
  final ValueChanged<String?> onPresetChanged;
  final bool isTestingAudio;
  final String? testAudioError;
  final VoidCallback onPlayTestAudio;
  final VoidCallback onAddPreset;
  final void Function(TrimPreset) onEditPreset;
  final Future<bool> Function(TrimPreset) onDeletePreset;

  const TrimSection({
    super.key,
    required this.selectedPresetId,
    required this.onPresetChanged,
    required this.isTestingAudio,
    required this.testAudioError,
    required this.onPlayTestAudio,
    required this.onAddPreset,
    required this.onEditPreset,
    required this.onDeletePreset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPresets = ref.watch(customTrimPresetsProvider);

    Widget buildTrimPresetLabel(String? presetId) {
      if (presetId == null) {
        final nonePreset = getBuiltinTrimPresets().firstWhere(
          (p) => p['id'] == BuiltinTrimPresetIds.none,
        );
        return Text(nonePreset['name'] as String);
      }
      final all = getAllTrimPresets(customPresets);
      for (final p in all) {
        if (p['id'] == presetId) {
          final direction = p['direction'] as String;
          final dirLabel = direction == 'head'
              ? AppLocalizations.of(context)!.batchRuleBeginning
              : AppLocalizations.of(context)!.batchRuleEnd;
          final name = p['name'] as String;
          final duration = p['durationSeconds'] as double;
          return Text('$name（$dirLabel，${duration.toStringAsFixed(3)}s）');
        }
      }
      return Text(AppLocalizations.of(context)!.modelNoTrim);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.content_cut, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.modelAudioTrimTitle,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const Spacer(),
                if (selectedPresetId != null &&
                    selectedPresetId != BuiltinTrimPresetIds.none)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DefaultTextStyle(
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                      child: buildTrimPresetLabel(selectedPresetId),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.modelAudioTrimHelp,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // 内置预设
            ...getBuiltinTrimPresets().map((preset) {
              final presetId = preset['id'] as String;
              return RadioListTile<String?>(
                title: Text(preset['name'] as String),
                subtitle: Text(
                  presetId == BuiltinTrimPresetIds.none
                      ? AppLocalizations.of(context)!.audioTrimNone
                      : AppLocalizations.of(context)!.audioTrimBeginning(
                          preset['durationSeconds'].toString(),
                        ),
                  style: const TextStyle(fontSize: 12),
                ),
                value: preset['id'] as String,
                // ignore: deprecated_member_use
                groupValue: selectedPresetId ?? BuiltinTrimPresetIds.none,
                // ignore: deprecated_member_use
                onChanged: (v) => onPresetChanged(v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),

            // 分割线
            if (customPresets.isNotEmpty) const Divider(),

            // 自定义预设
            if (customPresets.isNotEmpty)
              ...customPresets.asMap().entries.map((entry) {
                final preset = entry.value;
                final dirLabel = preset.direction == 'head'
                    ? AppLocalizations.of(context)!.batchRuleBeginning
                    : AppLocalizations.of(context)!.batchRuleEnd;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String?>(
                    value: preset.id,
                    // ignore: deprecated_member_use
                    groupValue: selectedPresetId ?? BuiltinTrimPresetIds.none,
                    // ignore: deprecated_member_use
                    onChanged: (v) => onPresetChanged(v),
                  ),
                  title: Text(
                    preset.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.audioTrimDirection(
                      dirLabel,
                      preset.durationSeconds.toStringAsFixed(3),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => onEditPreset(preset),
                        tooltip: AppLocalizations.of(context)!.imagePreviewEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: ConstrainedText(
                                AppLocalizations.of(context)!
                                    .modelDeleteTrimPreset,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              content: Text(
                                AppLocalizations.of(context)!
                                    .modelDeleteTrimConfirmation(preset.name),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: ConstrainedText(
                                    AppLocalizations.of(context)!
                                        .batchDlgCancel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: ConstrainedText(
                                    AppLocalizations.of(context)!
                                        .fileManagerDelete,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await onDeletePreset(preset);
                          }
                        },
                        tooltip:
                            AppLocalizations.of(context)!.fileManagerDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // 添加按钮
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: ConstrainedText(
                  AppLocalizations.of(context)!.modelAddTrimPreset,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: onAddPreset,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isTestingAudio
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: ConstrainedText(
                  isTestingAudio
                      ? AppLocalizations.of(context)!.modelPlayingTestAudio
                      : AppLocalizations.of(context)!.modelPlayTestAudio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: isTestingAudio ? null : onPlayTestAudio,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (testAudioError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  testAudioError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
