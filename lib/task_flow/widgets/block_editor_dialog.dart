import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../models/tts_models.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/provider_config.dart';
import '../../utils/file_manifest.dart';
import '../../utils/provider_models.dart';
import '../../utils/video_manifest.dart';
import '../../widgets/folder_picker_dialog.dart';
import '../models/task_flow_definition.dart';
import '../models/block_type_definition.dart';
import '../services/block_executors/shared_helpers.dart' show asIntParam;

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

    // Clamp persisted modelSelector values into the CURRENT model range
    // (configs/models may have been deleted since the block was saved) — a
    // stale out-of-range index would otherwise survive untouched through a
    // confirm and fail at execution time.
    if (_definition != null) {
      final def = _definition!;
      for (final p in def.params) {
        if (p.type != BlockParamType.modelSelector) continue;
        final models = _modelsOf(p.configType);
        if (models.isEmpty) continue;
        final raw = _params[p.key];
        final idx = raw is num ? raw.toInt() : (int.tryParse('$raw') ?? 0);
        _params[p.key] = idx.clamp(0, models.length - 1).toInt();
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

  /// Models of a provider type, flattened with their config — the same
  /// shared list the executors and standalone pages use (configs without
  /// host/key excluded), so a selected index resolves identically
  /// everywhere.
  List<({dynamic config, dynamic model})> _modelsOf(String configType) {
    return [
      for (final e in flattenProviderModels(
        ref.read(providerEntriesProvider),
        configType,
      ))
        (config: e.config, model: e.model),
    ];
  }

  /// The TTS model selected by the block's modelIndex param (shared list).
  dynamic _selectedTtsModel() {
    final models = _modelsOf('tts');
    final idx = asIntParam(_params, 'modelIndex', 0);
    if (models.isEmpty || idx >= models.length) return null;
    return models[idx].model;
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
    // the (keyboard-reduced) available height, and the fixed chrome
    // (handle + header ≈ 90px — the actions row lives inside the
    // scrollable list) must never exceed the sheet's minimum.
    final availableHeight =
        screenHeight - MediaQuery.viewInsetsOf(context).bottom;
    final initialChildSize = math.min(0.75, 520 / availableHeight);
    final minFraction =
        math.min(math.max(0.4, 90 / availableHeight), initialChildSize);

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minFraction,
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
                // Actions live INSIDE the scrollable list so the sheet can
                // shrink below the fixed chrome (handle + header) when the
                // keyboard is open on short screens without overflowing.
                Row(
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
                const SizedBox(height: 12),
              ],
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
          // Multi-line for text prompts (e.g. the chat block's 开头提示语)
          // — single-line scrolling hides long instructions.
          maxLines: param.key == 'promptPrefix' ? 3 : 1,
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => _params[param.key] = v,
        );

      case BlockParamType.modelSelector:
        // Persisted JSON round-trips numbers as `num` — `int.tryParse('2.0')`
        // would fail and silently reset the selection to 0.
        final currentIndex =
            value is num ? value.toInt() : (int.tryParse('$value') ?? 0);
        // Model-level selection, same granularity as the standalone page:
        // each entry is a model of a configured provider, displayed as
        // 'modelName | providerName'.
        final models = _modelsOf(param.configType);
        if (models.isEmpty) {
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
            currentIndex.clamp(0, math.max(0, models.length - 1)).toInt();
        final selectedModel = models[clampedIndex].model;
        final customParams =
            (selectedModel.customParams as List<dynamic>? ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              value: clampedIndex,
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
              items: List.generate(models.length, (i) {
                final dynamic m = models[i].model;
                final dynamic c = models[i].config;
                final modelName = (m.name as String?)?.isNotEmpty == true
                    ? m.name as String
                    : (m.modelId as String? ?? '模型 $i');
                final providerName =
                    (c.providerName as String?)?.isNotEmpty == true
                        ? c.providerName as String
                        : '未命名供应商';
                return DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    '$modelName | $providerName',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _params[param.key] = v);
                }
              },
            ),
            // Custom params of the selected model — shown so the user sees
            // what extra fields the request carries (edited in the model
            // settings page).
            if (customParams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '模型自定义参数',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      for (final dynamic cp in customParams)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${cp.paramName}: ${cp.defaultValue}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );

      case BlockParamType.voiceSelector:
        // Voices of the SELECTED TTS model (the same model the executor
        // uses via modelIndex) — offering voices of every model would
        // confuse ("my voice isn't there") and the executor would reject
        // them. Deduped by id.
        final selectedTtsModel = _selectedTtsModel();
        final voices = <VoiceEntry>[];
        {
          final byId = <String, VoiceEntry>{};
          final model = selectedTtsModel;
          if (model != null) {
            final mVoices = model.voices as List<dynamic>? ?? const [];
            for (final v in mVoices) {
              final entry = v is VoiceEntry
                  ? v
                  : VoiceEntry.fromMap(Map<String, dynamic>.from(v as Map));
              if (entry.name.isNotEmpty && entry.id.isNotEmpty) {
                byId[entry.id] = entry;
              }
            }
          }
          voices.addAll(byId.values);
        }
        final current = value?.toString() ?? '';
        // A stale voice (not in the selected model's voices) must not
        // survive confirm — reset it to '' (use the model default). Only
        // applies when the model HAS voices: in the manual fallback (no
        // voices configured) the user's typed id is the source of truth
        // and must never be wiped by unrelated rebuilds.
        final stale = voices.isNotEmpty &&
            current.isNotEmpty &&
            !voices.any((v) => v.id == current);
        if (stale) {
          _params[param.key] = '';
          _controllers[param.key]?.text = '';
        }
        // Track the controller in both branches (dropdown + manual
        // fallback) so it is disposed with the panel. The fallback field
        // must show the POST-reset value — a stale id would display while
        // confirm silently drops it.
        _controllers[param.key] ??=
            TextEditingController(text: stale ? '' : current);
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
            // A persisted voice id that no longer exists must not show the
            // raw id string — guide re-selection instead.
            stale ? '音色已失效，请重新选择' : '选择音色',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          items: voices.map((v) {
            return DropdownMenuItem<String>(
              value: v.id,
              // Name only — the id (e.g. zh-CN-XiaoxiaoNeural) is a long
              // opaque string that would confuse users; the TTS page shows
              // the same.
              child: Text(v.name),
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
        final display = _assistantDisplay(currentId, assistants);
        final missing = currentId.isNotEmpty && display == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Picker field: shows the selected assistant's name; tapping
            // opens the assistant picker panel (built-in + user-defined).
            InkWell(
              onTap: () => _showAssistantPicker(param.key, currentId),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        display == null
                            ? (currentId.isEmpty ? '未指定（使用当前选中的助手）' : '助手不存在')
                            : '${display.$1} ${display.$2}',
                        style: TextStyle(
                          fontSize: 13,
                          color: display == null
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (missing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '配置的助手已删除，请重新选择',
                  style: TextStyle(fontSize: 11, color: cs.error),
                ),
              ),
          ],
        );

      case BlockParamType.speedSlider:
        // Slider like the TTS page — range from the selected TTS model's
        // speedMin/speedMax (defaults 0.5–2.0).
        final model = _selectedTtsModel();
        // Raw model bounds (like the TTS page and the executor) — no
        // pre-clamp into a hard window, so display always matches run.
        final speedMin = (model?.speedMin as num?)?.toDouble() ?? 0.5;
        final speedMax = (model?.speedMax as num?)?.toDouble() ?? 2.0;
        final lo = math.min(speedMin, speedMax);
        final hi = math.max(speedMin, speedMax);
        final speedRaw = value is num ? value.toDouble() : 1.0;
        // Display (and slider value) clamped to the model's range — the
        // executed speed is clamped identically in the executor, so what
        // the user sees always matches what runs.
        final display = speedRaw.clamp(lo, hi).toDouble();
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: display,
                min: lo,
                max: hi,
                divisions: ((hi - lo) * 10).round().clamp(1, 100),
                label: '${display.toStringAsFixed(1)}x',
                onChanged: (v) => setState(() => _params[param.key] = v),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${display.toStringAsFixed(1)}x',
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );

      case BlockParamType.durationSeconds:
        // 时/分/秒 three fields, like the CatCatch page's duration input.
        final totalSec = value is num ? value.toInt() : 0;
        final h = totalSec ~/ 3600;
        final m = (totalSec % 3600) ~/ 60;
        final s = totalSec % 60;
        final hCtrl = _controllers['${param.key}_h'] ??
            TextEditingController(text: h == 0 ? '' : '$h');
        final mCtrl = _controllers['${param.key}_m'] ??
            TextEditingController(text: m == 0 ? '' : '$m');
        final sCtrl = _controllers['${param.key}_s'] ??
            TextEditingController(text: s == 0 ? '' : '$s');
        _controllers['${param.key}_h'] = hCtrl;
        _controllers['${param.key}_m'] = mCtrl;
        _controllers['${param.key}_s'] = sCtrl;
        void rebuild() {
          final hh = int.tryParse(hCtrl.text) ?? 0;
          final mm = int.tryParse(mCtrl.text) ?? 0;
          final ss = int.tryParse(sCtrl.text) ?? 0;
          setState(() {
            _params[param.key] = hh * 3600 + mm * 60 + ss;
          });
        }

        InputDecoration dec() => InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            );
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: hCtrl,
                decoration: dec().copyWith(hintText: '时'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => rebuild(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: mCtrl,
                decoration: dec().copyWith(hintText: '分'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => rebuild(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: sCtrl,
                decoration: dec().copyWith(hintText: '秒'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => rebuild(),
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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

  /// Resolves the display (emoji, name) for an assistant id — only
  /// user-defined assistants are allowed on blocks (built-in prompt ids
  /// are legacy configs and resolve to null → 助手不存在).
  /// Returns null when the id is empty or no longer resolvable.
  (String, String)? _assistantDisplay(
    String id,
    List<Assistant> assistants,
  ) {
    if (id.isEmpty) return null;
    if (id.startsWith(kBuiltInPromptIdPrefix)) return null;
    final a = assistants.where((a) => a.id == id).firstOrNull;
    return a == null ? null : (a.emoji, a.name);
  }

  /// Opens the assistant picker panel: only the user's custom assistants
  /// ("我的助手") are selectable — built-in prompts are not offered on
  /// flow blocks. Selecting one stores its id in the param.
  Future<void> _showAssistantPicker(String key, String currentId) async {
    final cs = Theme.of(context).colorScheme;
    final assistants = ref.read(assistantProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      // Without isScrollControlled the sheet is capped at 9/16 of the
      // screen height — the fractions below would resolve to ~37%.
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (scrollCtx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            Center(
              child: Text(
                '选择助手',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '只能选择"我的助手"（在"聊天 → 助手"中添加）',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            // User-defined assistants
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '我的助手',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (assistants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '还没有自定义助手，可在"聊天 → 助手"中创建',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final a in assistants)
                _assistantTile(
                  emoji: a.emoji,
                  name: a.name,
                  subtitle: a.description,
                  selected: currentId == a.id,
                  onTap: () => Navigator.pop(ctx, a.id),
                ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _params[key] = selected);
    }
  }

  Widget _assistantTile({
    required String emoji,
    required String name,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 18, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
