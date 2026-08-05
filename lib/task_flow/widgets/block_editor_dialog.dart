import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tts_models.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/provider_config.dart';
import '../../utils/file_manifest.dart';
import '../../utils/video_manifest.dart';
import '../../widgets/folder_picker_dialog.dart';
import '../models/task_flow_definition.dart';
import '../models/block_type_definition.dart';

/// Opens the block settings panel for editing a [TaskFlowBlock] instance.
///
/// A bottom-sheet panel that renders every parameter defined in the
/// block's [BlockTypeDefinition] using the same native-style controls as
/// the standalone pages (model dropdowns, voice dropdowns, assistant
/// selection, folder pickers, toggles, number fields).
/// Returns the updated [TaskFlowBlock] if confirmed, or null if cancelled.
Future<TaskFlowBlock?> showBlockEditorDialog(
  BuildContext context, {
  required TaskFlowBlock block,
}) {
  return showModalBottomSheet<TaskFlowBlock>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => AnimatedPadding(
      // Lift the sheet above the keyboard so the confirm/cancel row stays
      // reachable while typing (showModalBottomSheet does not inset by
      // viewInsets for isScrollControlled sheets).
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: _BlockEditorDialog(block: block),
    ),
  );
}

class _BlockEditorDialog extends ConsumerStatefulWidget {
  final TaskFlowBlock block;

  const _BlockEditorDialog({required this.block});

  @override
  ConsumerState<_BlockEditorDialog> createState() => _BlockEditorDialogState();
}

class _BlockEditorDialogState extends ConsumerState<_BlockEditorDialog> {
  late Map<String, dynamic> _params;
  late final BlockTypeDefinition? _definition;
  late final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _params = Map<String, dynamic>.from(widget.block.params);
    _definition = widget.block.getDefinition();

    // Clamp persisted modelSelector values into the CURRENT config range
    // (configs may have been deleted since the block was saved) — a stale
    // out-of-range index would otherwise survive untouched through a
    // confirm and fail at execution time.
    if (_definition != null) {
      final def = _definition!;
      for (final p in def.params) {
        if (p.type != BlockParamType.modelSelector) continue;
        final configs = _configsOf(p.configType);
        if (configs.isEmpty) continue;
        final raw = _params[p.key];
        final idx = raw is num ? raw.toInt() : (int.tryParse('$raw') ?? 0);
        _params[p.key] = idx.clamp(0, configs.length - 1).toInt();
      }
    }

    // Initialize TextEditingControllers for string-type params
    if (_definition != null) {
      for (final p in _definition!.params) {
        if (p.type == BlockParamType.string ||
            p.type == BlockParamType.secret ||
            p.type == BlockParamType.number) {
          _controllers[p.key] = TextEditingController(
            text: _params[p.key]?.toString() ?? '',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Configs of a provider type (flattened, in the same order the
  /// executors index them).
  List<dynamic> _configsOf(String configType) {
    return ref
        .read(providerEntriesProvider)
        .entries
        .where((e) => e.type == configType)
        .expand((e) => e.configs)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = _definition;
    final screenHeight = MediaQuery.of(context).size.height;

    if (def == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('功能块类型 "${widget.block.typeKey.name}" 未注册'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    }

    // Floor the min drag size in pixels: minChildSize is a fraction of
    // the (keyboard-reduced) available height, and the fixed header +
    // actions must never exceed the sheet's minimum.
    final availableHeight =
        screenHeight - MediaQuery.viewInsetsOf(context).bottom;
    final minFraction = math.max(0.4, 170 / availableHeight);

    return DraggableScrollableSheet(
      initialChildSize: math.min(0.75, 520 / availableHeight),
      minChildSize: math.min(minFraction, 0.75),
      maxChildSize: 0.9,
      expand: false,
      builder: (scrollCtx, scrollController) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: def.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(def.icon, size: 18, color: def.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${def.label} 设置',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '输入: ${def.inputType.label}  →  输出: ${def.outputType.label}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Params
          Flexible(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              children: [
                // Chat blocks: note about the user message being the
                // previous step's output.
                if (def.typeKey == BlockType.chat)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 14, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '发送给助手的用户消息 = 上一步的输出',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (def.params.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '该功能块无额外参数',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...def.params.map((param) => _buildParamField(param, cs)),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Actions
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final updated = widget.block.copyWithParams(_params);
                      Navigator.pop(context, updated);
                    },
                    child: const Text('确认'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamField(BlockParamDefinition param, ColorScheme cs) {
    final value = _params[param.key];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${param.label}${param.required ? ' *' : ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          _buildInputField(param, value, cs),
          if (param.hintText != null && param.hintText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                param.hintText!,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BlockParamDefinition param,
    dynamic value,
    ColorScheme cs,
  ) {
    switch (param.type) {
      case BlockParamType.string:
      case BlockParamType.secret:
        final controller = _controllers[param.key] ??
            TextEditingController(text: value?.toString() ?? '');
        if (_controllers[param.key] == null) {
          _controllers[param.key] = controller;
        }
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          obscureText: param.type == BlockParamType.secret,
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => _params[param.key] = v,
        );

      case BlockParamType.modelSelector:
        // Persisted JSON round-trips numbers as `num` — `int.tryParse('2.0')`
        // would fail and silently reset the selection to 0.
        final currentIndex =
            value is num ? value.toInt() : (int.tryParse('$value') ?? 0);
        final configs = _configsOf(param.configType);
        if (configs.isEmpty) {
          return const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '未配置模型',
              style: TextStyle(fontSize: 13),
            ),
          );
        }
        final clampedIndex =
            currentIndex.clamp(0, math.max(0, configs.length - 1)).toInt();
        return DropdownButtonFormField<int>(
          value: clampedIndex,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          style: TextStyle(fontSize: 13, color: cs.onSurface),
          items: List.generate(configs.length, (i) {
            final dynamic c = configs[i];
            final providerName = (c.providerName as String?)?.isNotEmpty == true
                ? c.providerName as String
                : '模型 $i';
            return DropdownMenuItem<int>(value: i, child: Text(providerName));
          }),
          onChanged: (v) {
            if (v != null) {
              setState(() => _params[param.key] = v);
            }
          },
        );

      case BlockParamType.voiceSelector:
        // Voices of the SAME TTS model the executor uses
        // (tts_executor: configs.first.models.first) — listing voices of
        // every config would offer voices the executed model can't use.
        // Deduped by id (a model can list the same voice id twice, which
        // would otherwise break the dropdown's exactly-one-item assert).
        final voices = <VoiceEntry>[];
        {
          final byId = <String, VoiceEntry>{};
          final ttsConfigs = _configsOf('tts');
          if (ttsConfigs.isNotEmpty) {
            final dynamic config = ttsConfigs.first;
            final models = config.models as List<dynamic>? ?? const [];
            if (models.isNotEmpty) {
              final mVoices = models.first.voices as List<dynamic>? ?? const [];
              for (final v in mVoices) {
                final entry = v is VoiceEntry
                    ? v
                    : VoiceEntry.fromMap(Map<String, dynamic>.from(v as Map));
                if (entry.name.isNotEmpty && entry.id.isNotEmpty) {
                  byId[entry.id] = entry;
                }
              }
            }
          }
          voices.addAll(byId.values);
        }
        final current = value?.toString() ?? '';
        // Track the controller in both branches (dropdown + manual
        // fallback) so it is disposed with the panel.
        _controllers[param.key] ??= TextEditingController(text: current);
        if (voices.isEmpty) {
          return TextField(
            controller: _controllers[param.key],
            onChanged: (v) => _params[param.key] = v,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              hintText: '未配置TTS音色，可手动输入ID',
            ),
            style: const TextStyle(fontSize: 13),
          );
        }
        return DropdownButtonFormField<String>(
          value: voices.any((v) => v.id == current) ? current : null,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          style: TextStyle(fontSize: 13, color: cs.onSurface),
          hint: Text(
            current.isNotEmpty && !voices.any((v) => v.id == current)
                ? current
                : '选择音色',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          items: voices.map((v) {
            return DropdownMenuItem<String>(
              value: v.id,
              child: Text('${v.name} (${v.id})'),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _params[param.key] = v;
                _controllers[param.key]?.text = v;
              });
            }
          },
        );

      case BlockParamType.assistantSelector:
        final assistants = ref.watch(assistantProvider);
        final currentId = value?.toString() ?? '';
        final currentAssistant =
            assistants.where((a) => a.id == currentId).firstOrNull;
        // The dropdown has an enabled null-valued item, so the hint
        // mechanism never shows (the framework selects the null item) —
        // a deleted-assistant warning is rendered as a line below instead.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              // A persisted id whose assistant was deleted must not be
              // passed as value (no matching item → debug assert crash).
              value: currentId.isNotEmpty && currentAssistant != null
                  ? currentId
                  : null,
              isDense: true,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('（使用当前选中的助手）'),
                ),
                ...assistants.map((a) {
                  return DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(
                      '${a.emoji} ${a.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (v) {
                setState(() => _params[param.key] = v ?? '');
              },
            ),
            if (currentId.isNotEmpty && currentAssistant == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '配置的助手已删除，请重新选择',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.error,
                  ),
                ),
              ),
          ],
        );

      case BlockParamType.number:
        final controller = _controllers[param.key] ??
            TextEditingController(text: value?.toString() ?? '');
        if (_controllers[param.key] == null) {
          _controllers[param.key] = controller;
        }
        return TextField(
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          controller: controller,
          onChanged: (v) {
            final parsed = num.tryParse(v);
            _params[param.key] = parsed ?? 0;
          },
        );

      case BlockParamType.boolean:
        return SwitchListTile(
          value: value == true,
          onChanged: (v) => setState(() => _params[param.key] = v),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            value == true ? '是' : '否',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        );

      case BlockParamType.filePath:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value?.toString().isNotEmpty == true
                      ? value.toString()
                      : '默认 (根目录)',
                  style: TextStyle(
                    fontSize: 13,
                    color: value?.toString().isNotEmpty == true
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pickFolder(param.key),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('选择', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _pickFolder(String key) async {
    final currentValue = _params[key]?.toString() ?? '';
    final folders = key == 'videoFolder'
        ? await VideoManifest.getAllFolders()
        : await FileManifest.getAllFolders();
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: currentValue,
      availableFolders: folders,
      title: '选择保存文件夹',
    );
    if (result != null && mounted) {
      setState(() => _params[key] = result);
    }
  }
}
