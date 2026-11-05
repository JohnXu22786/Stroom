import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import '../providers/tts_config.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_trim.dart';
import '../utils/audio_utils.dart';
import 'model_config_shared.dart';
import 'voice_editor_page.dart';

class ModelConfigPage extends ConsumerStatefulWidget {
  final String entryId;
  final int configIndex;
  final int modelIndex; // -1 for new model
  final ModelConfig?
      initialModel; // for editing pending models (configIndex == -1)

  const ModelConfigPage({
    super.key,
    required this.entryId,
    required this.configIndex,
    required this.modelIndex,
    this.initialModel,
  });

  @override
  ConsumerState<ModelConfigPage> createState() => _ModelConfigPageState();
}

class _ModelConfigPageState extends ConsumerState<ModelConfigPage> {
  final _nameController = TextEditingController();
  final _modelIdController = TextEditingController();
  final _volumeMinController = TextEditingController();
  final _volumeMaxController = TextEditingController();
  final _speedMinController = TextEditingController();
  final _speedMaxController = TextEditingController();
  final _maxWordsController = TextEditingController();

  List<VoiceEntry> _voices = [];
  List<CustomParam> _customParams = [];
  List<VoiceEntry> _initialVoices = [];
  List<CustomParam> _initialCustomParams = [];
  String _initialName = '';
  String _initialModelId = '';
  String? _stableModelId;
  String _initialVolumeMin = '';
  String _initialVolumeMax = '';
  String _initialSpeedMin = '';
  String _initialSpeedMax = '';
  String _initialMaxWords = '';
  bool _initialSupportStream = false;
  bool _initialSupportInstruction = false;
  String? _initialTrimPresetId;

  bool _isSaving = false;
  bool _supportStream = false;
  bool _supportInstruction = false;
  String? _selectedTrimPresetId;
  bool get _isEditing => widget.modelIndex >= 0;

  bool _isTestingAudio = false;
  String? _testAudioError;
  AudioPlayerAdapter? _audioPlayer;

  bool get _hasUnsavedChanges {
    if (_nameController.text.trim() != _initialName) return true;
    if (_modelIdController.text.trim() != _initialModelId) return true;
    if (_volumeMinController.text.trim() != _initialVolumeMin) return true;
    if (_volumeMaxController.text.trim() != _initialVolumeMax) return true;
    if (_speedMinController.text.trim() != _initialSpeedMin) return true;
    if (_speedMaxController.text.trim() != _initialSpeedMax) return true;
    if (_maxWordsController.text.trim() != _initialMaxWords) return true;
    if (_supportStream != _initialSupportStream) return true;
    if (_supportInstruction != _initialSupportInstruction) return true;
    if (_selectedTrimPresetId != _initialTrimPresetId) return true;
    if (_voices.length != _initialVoices.length) return true;
    for (int i = 0; i < _voices.length; i++) {
      if (i >= _initialVoices.length) return true;
      if (_voices[i].name != _initialVoices[i].name) return true;
      if (_voices[i].id != _initialVoices[i].id) return true;
    }
    if (_customParams.length != _initialCustomParams.length) return true;
    for (int i = 0; i < _customParams.length; i++) {
      if (i >= _initialCustomParams.length) return true;
      if (_customParams[i].paramName != _initialCustomParams[i].paramName) {
        return true;
      }
      if (_customParams[i].defaultValue !=
          _initialCustomParams[i].defaultValue) {
        return true;
      }
      if (_customParams[i].type != _initialCustomParams[i].type) return true;
    }
    return false;
  }

  ProviderEntry? get _entry {
    final state = ref.read(providerEntriesProvider);
    try {
      return state.entries.firstWhere((e) => e.id == widget.entryId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  void _loadModel() {
    final entry = _entry;
    if (entry == null) return;

    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length) {
      if (widget.initialModel != null) {
        final model = widget.initialModel!;
        _stableModelId = model.id;
        _nameController.text = model.name;
        _modelIdController.text = model.modelId;
        _voices = model.voices.map((v) => v.copy()).toList();
        _volumeMinController.text =
            model.hasVolume ? model.volumeMin.toString() : '';
        _volumeMaxController.text =
            model.hasVolume ? model.volumeMax.toString() : '';
        _speedMinController.text =
            model.hasSpeed ? model.speedMin.toString() : '';
        _speedMaxController.text =
            model.hasSpeed ? model.speedMax.toString() : '';
        _maxWordsController.text = model.maxWordsPerRequest > 0
            ? model.maxWordsPerRequest.toString()
            : '';
        _customParams = model.customParams.map((p) => p.copy()).toList();
        _supportStream = model.supportStream;
        _supportInstruction = model.supportInstruction;
        _selectedTrimPresetId = model.selectedTrimPresetId;
      } else {
        _voices = [];
        _customParams = [];
        _supportStream = false;
        _supportInstruction = false;
        _selectedTrimPresetId = null;
      }
      _initialVoices = _voices.map((v) => v.copy()).toList();
      _initialCustomParams = _customParams.map((p) => p.copy()).toList();
      _initialName = _nameController.text.trim();
      _initialModelId = _modelIdController.text.trim();
      _initialVolumeMin = _volumeMinController.text.trim();
      _initialVolumeMax = _volumeMaxController.text.trim();
      _initialSpeedMin = _speedMinController.text.trim();
      _initialSpeedMax = _speedMaxController.text.trim();
      _initialMaxWords = _maxWordsController.text.trim();
      _initialSupportStream = _supportStream;
      _initialSupportInstruction = _supportInstruction;
      _initialTrimPresetId = _selectedTrimPresetId;
      return;
    }
    final configModels = entry.configs[widget.configIndex].models;
    if (_isEditing &&
        widget.modelIndex >= 0 &&
        widget.modelIndex < configModels.length) {
      final model = configModels[widget.modelIndex];
      _stableModelId = model.id;
      _nameController.text = model.name;
      _modelIdController.text = model.modelId;
      _voices = model.voices.map((v) => v.copy()).toList();
      _volumeMinController.text =
          model.hasVolume ? model.volumeMin.toString() : '';
      _volumeMaxController.text =
          model.hasVolume ? model.volumeMax.toString() : '';
      _speedMinController.text =
          model.hasSpeed ? model.speedMin.toString() : '';
      _speedMaxController.text =
          model.hasSpeed ? model.speedMax.toString() : '';
      _maxWordsController.text = model.maxWordsPerRequest > 0
          ? model.maxWordsPerRequest.toString()
          : '';
      _customParams = model.customParams.map((p) => p.copy()).toList();
      _supportStream = model.supportStream;
      _supportInstruction = model.supportInstruction;
      _selectedTrimPresetId = model.selectedTrimPresetId;
    } else {
      _voices = [];
      _customParams = [];
      _supportStream = false;
      _supportInstruction = false;
      _selectedTrimPresetId = null;
    }
    _initialVoices = _voices.map((v) => v.copy()).toList();
    _initialCustomParams = _customParams.map((p) => p.copy()).toList();
    _initialName = _nameController.text.trim();
    _initialModelId = _modelIdController.text.trim();
    _initialVolumeMin = _volumeMinController.text.trim();
    _initialVolumeMax = _volumeMaxController.text.trim();
    _initialSpeedMin = _speedMinController.text.trim();
    _initialSpeedMax = _speedMaxController.text.trim();
    _initialMaxWords = _maxWordsController.text.trim();
    _initialSupportStream = _supportStream;
    _initialSupportInstruction = _supportInstruction;
    _initialTrimPresetId = _selectedTrimPresetId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    _volumeMinController.dispose();
    _volumeMaxController.dispose();
    _speedMinController.dispose();
    _speedMaxController.dispose();
    _maxWordsController.dispose();
    _audioPlayer?.dispose();

    super.dispose();
  }

  // ----------------------------------------------------------------
  // 音色管理（已迁移到 VoiceEditorPage）
  // ----------------------------------------------------------------

  // ----------------------------------------------------------------
  // 裁切预设管理
  // ----------------------------------------------------------------

  void _showAddTrimPresetDialog() {
    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String direction = 'head';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.modelAddTrimPreset),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.trimNameLabel,
                  hintText: AppLocalizations.of(context)!.trimNameHint,
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.trimDurationLabel,
                  hintText: AppLocalizations.of(context)!.trimDurationHint,
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      AppLocalizations.of(context)!.batchRuleBeginning,
                    ),
                    selected: direction == 'head',
                    onSelected: (_) => setDlgState(() => direction = 'head'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(AppLocalizations.of(context)!.batchRuleEnd),
                    selected: direction == 'tail',
                    onSelected: (_) => setDlgState(() => direction = 'tail'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.batchDlgCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final durationText = durationCtrl.text.trim();
                if (name.isEmpty || durationText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!
                            .trimNameAndDurationRequired,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final duration = double.tryParse(durationText);
                if (duration == null || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.trimDurationInvalid,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final preset = TrimPreset(
                  name: name,
                  durationSeconds: duration,
                  direction: direction,
                );
                await ref.read(customTrimPresetsProvider.notifier).add(preset);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context)!.builtInPromptAdd),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTrimPresetDialog(TrimPreset preset) {
    final nameCtrl = TextEditingController(text: preset.name);
    final durationCtrl = TextEditingController(
      text: preset.durationSeconds.toString(),
    );
    String direction = preset.direction;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.ttsEditTrimTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.trimNameLabel,
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.trimDurationLabel,
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      AppLocalizations.of(context)!.batchRuleBeginning,
                    ),
                    selected: direction == 'head',
                    onSelected: (_) => setDlgState(() => direction = 'head'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(AppLocalizations.of(context)!.batchRuleEnd),
                    selected: direction == 'tail',
                    onSelected: (_) => setDlgState(() => direction = 'tail'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.batchDlgCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final durationText = durationCtrl.text.trim();
                if (name.isEmpty || durationText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!
                            .trimNameAndDurationRequired,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final duration = double.tryParse(durationText);
                if (duration == null || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.trimDurationInvalid,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final updated = TrimPreset(
                  id: preset.id,
                  name: name,
                  durationSeconds: duration,
                  direction: direction,
                );
                await ref
                    .read(customTrimPresetsProvider.notifier)
                    .update(preset.id, updated);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context)!.mermaidSaveButton),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // 自定义参数管理
  // ----------------------------------------------------------------

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
    });
  }

  // ----------------------------------------------------------------

  Future<void> _playTestAudio() async {
    final strings = AppLocalizations.of(context)!;
    final entry = _entry;
    if (entry == null) return;
    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length) {
      return;
    }

    setState(() {
      _isTestingAudio = true;
      _testAudioError = null;
    });

    try {
      final config = entry.configs[widget.configIndex];
      final host = config.host.trim();
      final key = config.key.trim();

      if (host.isEmpty) {
        setState(() {
          _testAudioError = strings.testAudioHostMissing;
          _isTestingAudio = false;
        });
        return;
      }
      if (key.isEmpty) {
        setState(() {
          _testAudioError = strings.testAudioKeyMissing;
          _isTestingAudio = false;
        });
        return;
      }

      // 只传输文本（input）、model（必填）、key（放 Header）、host（作 URL）、音色的第一个（如果用户填写）
      final body = <String, dynamic>{
        'input': '这是一段测试音频',
        'model': _modelIdController.text.trim(),
      };
      if (_voices.isNotEmpty) {
        body['voice'] = _voices.first.id;
      }

      final dio = Dio(
        BaseOptions(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
            ...openRouterAppHeaders,
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final response = await dio.post(
        host,
        data: body,
        options: Options(responseType: ResponseType.bytes),
      );

      // 检查响应 Content-Type，若不是音频则按错误处理
      // 同时检查响应体是否以 { 或 [ 开头（JSON 错误响应）
      final contentType = response.headers.value('content-type') ?? '';
      final isJsonBody = response.data.isNotEmpty &&
          (response.data[0] == 0x7b || response.data[0] == 0x5b);

      if (isJsonBody ||
          (contentType.isNotEmpty && !contentType.startsWith('audio/'))) {
        String errorBody;
        try {
          errorBody = utf8.decode(response.data);
        } catch (_) {
          errorBody = strings.testAudioContentTypeError(contentType);
        }
        setState(() {
          _testAudioError = errorBody;
          _isTestingAudio = false;
        });
        return;
      }

      final audioData = Uint8List.fromList(response.data);
      if (audioData.isEmpty) {
        setState(() {
          _testAudioError = strings.testAudioEmpty;
          _isTestingAudio = false;
        });
        return;
      }

      // 先裁切（对原始数据操作），再转换格式
      var trimmedData = audioData;
      if (_selectedTrimPresetId != null &&
          _selectedTrimPresetId != BuiltinTrimPresetIds.none) {
        final customPresets = ref.read(customTrimPresetsProvider);
        final preset = getTrimPresetById(_selectedTrimPresetId!, customPresets);
        if (preset != null) {
          try {
            trimmedData = trimAudio(trimmedData, preset: preset);
          } catch (e) {
            debugPrint('裁切失败: $e');
          }
        }
      }

      // 检测格式并转换（PCM→WAV 等），确保浏览器可播放
      final (playbackData, actualFormat) = ensureValidAudioFormat(
        trimmedData,
        requestedFormat: 'wav',
      );
      final mimeType = getMimeType(actualFormat);

      // 播放音频
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayerAdapter();
      final audioUrl = createAudioUrl(playbackData, mimeType);
      await _audioPlayer!.load(audioUrl);
      await _audioPlayer!.play();

      if (mounted) {
        setState(() => _isTestingAudio = false);
      }
    } on DioException catch (e) {
      final String origMsg = e.message ?? '';
      final String extra =
          origMsg.isNotEmpty ? '\n${strings.modelOriginalError(origMsg)}' : '';
      String errorMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg = strings.testAudioTimeoutConnection(extra);
          break;
        case DioExceptionType.receiveTimeout:
          errorMsg = strings.testAudioTimeoutReceive(extra);
          break;
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final body = e.response?.data;
          String bodyStr;
          if (body is List<int>) {
            try {
              bodyStr = utf8.decode(body);
            } catch (_) {
              bodyStr = body.toString();
            }
          } else {
            bodyStr = body?.toString() ?? strings.testAudioNoBody;
          }
          errorMsg = 'HTTP $statusCode: $bodyStr$extra';
          break;
        case DioExceptionType.cancel:
          errorMsg = strings.testAudioRequestCancelled(extra);
          break;
        default:
          if (e.type == DioExceptionType.connectionError && kIsWeb) {
            errorMsg = strings.testAudioCorsHelp(extra);
          } else {
            errorMsg = strings.testAudioNetworkError(e.message ?? '');
          }
      }
      if (mounted) {
        setState(() {
          _testAudioError = errorMsg;
          _isTestingAudio = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testAudioError = e.toString();
          _isTestingAudio = false;
        });
      }
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.batchDlgHelpDismiss),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 保存
  // ----------------------------------------------------------------

  Future<void> _save() async {
    final entry = _entry;
    if (entry == null) return;

    // 验证模型ID必填
    final modelId = _modelIdController.text.trim();
    if (modelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.modelIdRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证单次最长音频字数必填
    final maxWordsText = _maxWordsController.text.trim();
    final maxWords = int.tryParse(maxWordsText);
    if (maxWordsText.isEmpty || maxWords == null || maxWords <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.ttsMaxAudioLengthRequired,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证自定义参数：每个参数都必须有参数名和默认值，且参数名不能重复，
    // JSON 类型的默认值必须是合法 JSON
    final seenNames = <String>{};
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      final name = param.paramName.trim();
      if (name.isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.modelCustomParamRequired,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.modelParamDuplicate(name),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // JSON 类型的默认值必须是合法 JSON
      if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
        try {
          jsonDecode(param.defaultValue.trim());
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!
                    .modelParamJsonInvalid(name, param.defaultValue),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    // 验证音量范围：必须成对填写或同时留空
    final volMinText = _volumeMinController.text.trim();
    final volMaxText = _volumeMaxController.text.trim();
    if (volMinText.isNotEmpty != volMaxText.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .ttsRangePair(AppLocalizations.of(context)!.ttsVoiceRangeTitle),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    // 验证语速范围：必须成对填写或同时留空
    final spdMinText = _speedMinController.text.trim();
    final spdMaxText = _speedMaxController.text.trim();
    if (spdMinText.isNotEmpty != spdMaxText.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .ttsRangePair(AppLocalizations.of(context)!.ttsSpeedRangeTitle),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    setState(() => _isSaving = true);

    // 自动填充：如果模型名称为空，使用模型ID
    var name = _nameController.text.trim();
    if (name.isEmpty && modelId.isNotEmpty) {
      name = modelId;
    }

    final hasVolume = _volumeMinController.text.trim().isNotEmpty ||
        _volumeMaxController.text.trim().isNotEmpty;
    final hasSpeed = _speedMinController.text.trim().isNotEmpty ||
        _speedMaxController.text.trim().isNotEmpty;

    final modelConfig = ModelConfig(
      id: _stableModelId,
      name: name,
      modelId: modelId,
      voices: _voices.map((v) => v.copy()).toList(),
      volumeMin: double.tryParse(_volumeMinController.text) ?? 0.1,
      volumeMax: double.tryParse(_volumeMaxController.text) ?? 2.0,
      speedMin: double.tryParse(_speedMinController.text) ?? 0.5,
      speedMax: double.tryParse(_speedMaxController.text) ?? 2.0,
      hasVolume: hasVolume,
      hasSpeed: hasSpeed,
      maxWordsPerRequest: maxWords,
      customParams: _customParams.map((p) => p.copy()).toList(),
      supportStream: _supportStream,
      supportInstruction: _supportInstruction,
      selectedTrimPresetId: _selectedTrimPresetId,
    );

    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context, modelConfig);
      return;
    }

    var configs = entry.configs.map((c) => c.copy()).toList();
    var models = List<ModelConfig>.from(configs[widget.configIndex].models);

    if (_isEditing &&
        widget.modelIndex >= 0 &&
        widget.modelIndex < models.length) {
      models[widget.modelIndex] = modelConfig;
    } else {
      models.insert(0, modelConfig);
    }

    // 在完整副本上更新模型：保留供应商的 typeConfig / customParams /
    // reasoningParams / endpointType（重建会丢配置，推理参数继承视图与
    // 请求构建都依赖供应商级参数——与 provider_config_detail_page 的
    // _insertModelResult / _updateModelInConfig 保持一致）。
    final base = configs[widget.configIndex];
    configs[widget.configIndex] = ProviderConfigItem(
      id: base.id,
      providerName: base.providerName,
      host: base.host,
      key: base.key,
      models: models,
      typeConfig: base.typeConfig,
      customParams: base.customParams,
      reasoningParams: base.reasoningParams,
      endpointType: base.endpointType,
    );

    final updated = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: configs,
    );

    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.modelSaveSuccess),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? (_nameController.text.isNotEmpty
            ? _nameController.text
            : AppLocalizations.of(context)!.modelEditTitle)
        : AppLocalizations.of(context)!.modelCreateTitle;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.modelDiscardTitle),
            content: Text(AppLocalizations.of(context)!.modelDiscardBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.batchDlgCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(AppLocalizations.of(context)!.taskFlowUiDiscard),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(
                _isSaving
                    ? AppLocalizations.of(context)!.modelSaving
                    : AppLocalizations.of(context)!.mermaidSaveButton,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ==========================================================
            // 模型名称
            // ==========================================================
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.modelNameLabel,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showInfoDialog(
                    AppLocalizations.of(context)!.modelNameLabel,
                    AppLocalizations.of(context)!.trimModelNameHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.modelNameHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================================
            // 模型ID
            // ==========================================================
            Row(
              children: [
                Text(
                  '${AppLocalizations.of(context)!.modelIdLabel} *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showInfoDialog(
                    AppLocalizations.of(context)!.modelIdLabel,
                    AppLocalizations.of(context)!.trimModelIdHelp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelIdController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.modelIdLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================================
            // 音量范围
            // ==========================================================
            Text(
              AppLocalizations.of(context)!.ttsVoiceRangeTitle,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _volumeMinController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.ttsMinVolume,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Text('~'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _volumeMaxController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.ttsMaxVolume,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ==========================================================
            // 语速范围
            // ==========================================================
            Text(
              AppLocalizations.of(context)!.ttsSpeedRangeTitle,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speedMinController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.ttsMinSpeed,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Text('~'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _speedMaxController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.ttsMaxSpeed,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // 单次最长音频字数
            // ==========================================================
            TextField(
              controller: _maxWordsController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.ttsMaxAudioLength,
                hintText: AppLocalizations.of(context)!.ttsAudioLengthHint,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // 音色列表 → 入口卡片，跳转到独立编辑大面板
            // ==========================================================
            Card(
              child: ListTile(
                leading: const Icon(Icons.record_voice_over, size: 24),
                title: Text(
                  AppLocalizations.of(context)!
                      .ttsVoicesCount(_voices.length.toString()),
                ),
                subtitle: Text(
                  _voices.isEmpty
                      ? AppLocalizations.of(context)!.ttsNoVoices
                      : _voices.take(3).map((v) => v.name).join('、') +
                          (_voices.length > 3 ? '…' : ''),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await Navigator.push<List<VoiceEntry>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VoiceEditorPage(
                        initialVoices: _voices.map((v) => v.copy()).toList(),
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() => _voices = result);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // ==========================================================
            // 自定义参数
            // ==========================================================
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.chatCustomParameters,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.assistantAddParameter,
                  ),
                  onPressed: _addCustomParam,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_customParams.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.assistantNoCustomParameters,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...List.generate(_customParams.length, (i) {
                final param = _customParams[i];
                // 检查当前参数名是否与其他参数重复
                final name = param.paramName.trim();
                final isDuplicate = name.isNotEmpty &&
                    _customParams.indexWhere(
                          (p) => p.paramName.trim() == name,
                        ) !=
                        i;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: param.paramName,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!
                                      .assistantParameterName,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText: isDuplicate
                                      ? AppLocalizations.of(context)!
                                          .modelParamDuplicate(
                                          param.paramName.trim(),
                                        )
                                      : null,
                                  errorStyle: const TextStyle(fontSize: 11),
                                ),
                                onChanged: (v) {
                                  param.paramName = v;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 类型选择
                            Container(
                              width: 110,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: StroomMenuStyle.surface(
                                    context,
                                  ),
                                  borderRadius: StroomMenuStyle.borderRadius,
                                  value: param.type,
                                  isDense: true,
                                  items: ParamType.values
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t.value,
                                          child: Text(
                                            localizedParamTypeLabel(
                                                AppLocalizations.of(context)!,
                                                t),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => param.type = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _removeCustomParam(i),
                              tooltip: AppLocalizations.of(context)!
                                  .modelParamDelete,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: param.defaultValue,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!
                                .modelParamDefaultValue,
                            hintText: localizedParamTypeDefaultValueHint(
                                AppLocalizations.of(context)!, param.paramType),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => param.defaultValue = v,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            param.paramType.needsQuotes
                                ? AppLocalizations.of(context)!
                                    .ttsRequestFormatExample(
                                    '"{{${param.paramName}}}"',
                                  )
                                : AppLocalizations.of(context)!
                                    .ttsRequestFormatExample(
                                    '{{${param.paramName}}}',
                                  ),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),

            // ==========================================================
            // instruction 参数开关
            // ==========================================================
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.description, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!
                                .ttsInstructionSupported,
                          ),
                          Text(
                            AppLocalizations.of(context)!.ttsInstructionHelp,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ToggleButton(
                      label: AppLocalizations.of(context)!.taskFlowUiYes,
                      value: true,
                      currentValue: _supportInstruction,
                      onChanged: (v) => setState(() => _supportInstruction = v),
                    ),
                    const SizedBox(width: 8),
                    ToggleButton(
                      label: AppLocalizations.of(context)!.taskFlowUiNo,
                      value: false,
                      currentValue: _supportInstruction,
                      onChanged: (v) => setState(() => _supportInstruction = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ==========================================================
            // 流式输出开关
            // ==========================================================
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.stream, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.ttsStreamSupported,
                          ),
                          Text(
                            AppLocalizations.of(context)!.ttsStreamHelp,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ToggleButton(
                      label: AppLocalizations.of(context)!.taskFlowUiYes,
                      value: true,
                      currentValue: _supportStream,
                      onChanged: (v) => setState(() => _supportStream = v),
                    ),
                    const SizedBox(width: 8),
                    ToggleButton(
                      label: AppLocalizations.of(context)!.taskFlowUiNo,
                      value: false,
                      currentValue: _supportStream,
                      onChanged: (v) => setState(() => _supportStream = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ==========================================================
            // 裁切设置
            // ==========================================================
            TrimSection(
              selectedPresetId: _selectedTrimPresetId,
              onPresetChanged: (v) => setState(() => _selectedTrimPresetId = v),
              isTestingAudio: _isTestingAudio,
              testAudioError: _testAudioError,
              onPlayTestAudio: _playTestAudio,
              onAddPreset: _showAddTrimPresetDialog,
              onEditPreset: _showEditTrimPresetDialog,
              onDeletePreset: (preset) async {
                await ref
                    .read(customTrimPresetsProvider.notifier)
                    .remove(preset.id);
                if (_selectedTrimPresetId == preset.id) {
                  setState(() => _selectedTrimPresetId = null);
                }
                return true;
              },
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
