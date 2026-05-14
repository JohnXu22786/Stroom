import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../providers/provider_config.dart';
import '../providers/tts_config.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_trim.dart';
import '../utils/audio_utils.dart';
import 'voice_editor_page.dart';

class ModelConfigPage extends ConsumerStatefulWidget {
  final String entryId;
  final int configIndex;
  final int modelIndex; // -1 for new model
  const ModelConfigPage({
    super.key,
    required this.entryId,
    required this.configIndex,
    required this.modelIndex,
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
      if (_customParams[i].paramName != _initialCustomParams[i].paramName)
        return true;
      if (_customParams[i].defaultValue != _initialCustomParams[i].defaultValue)
        return true;
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
      _voices = [];
      _customParams = [];
      return;
    }
    final configModels = entry.configs[widget.configIndex].models;
    if (_isEditing &&
        widget.modelIndex >= 0 &&
        widget.modelIndex < configModels.length) {
      final model = configModels[widget.modelIndex];
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
          title: const Text('添加自定义裁切'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '切割方式名称 *',
                  hintText: '例如: 静音裁切',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: '切割时长（秒） *',
                  hintText: '例如: 0.123',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('开头'),
                    selected: direction == 'head',
                    onSelected: (_) => setDlgState(() => direction = 'head'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('结尾'),
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
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final durationText = durationCtrl.text.trim();
                if (name.isEmpty || durationText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('名称和时长为必填项'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final duration = double.tryParse(durationText);
                if (duration == null || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请输入有效的时长（正数）'),
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
              child: const Text('添加'),
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
          title: const Text('编辑自定义裁切'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '切割方式名称 *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: '切割时长（秒） *',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('开头'),
                    selected: direction == 'head',
                    onSelected: (_) => setDlgState(() => direction = 'head'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('结尾'),
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
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final durationText = durationCtrl.text.trim();
                if (name.isEmpty || durationText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('名称和时长为必填项'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final duration = double.tryParse(durationText);
                if (duration == null || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请输入有效的时长（正数）'),
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
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取当前选中的裁切预设名称（用于显示）
  String _getTrimPresetLabel(String? presetId, List<TrimPreset> customPresets) {
    if (presetId == null) {
      // 默认显示内置的 "不裁切"
      final nonePreset = getBuiltinTrimPresets().firstWhere(
        (p) => p['id'] == BuiltinTrimPresetIds.none,
      );
      return nonePreset['name'] as String;
    }
    final all = getAllTrimPresets(customPresets);
    for (final p in all) {
      if (p['id'] == presetId) {
        final direction = p['direction'] as String;
        final dirLabel = direction == 'head' ? '开头' : '结尾';
        final name = p['name'] as String;
        final duration = p['durationSeconds'] as double;
        return '$name（$dirLabel，${duration.toStringAsFixed(3)}s）';
      }
    }
    return '不裁切';
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
    final entry = _entry;
    if (entry == null) return;
    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length)
      return;

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
          _testAudioError = 'Host 未配置';
          _isTestingAudio = false;
        });
        return;
      }
      if (key.isEmpty) {
        setState(() {
          _testAudioError = 'Key 未配置';
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

      final dio = Dio(BaseOptions(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ));

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
          errorBody = '响应 Content-Type 为 $contentType，非音频数据';
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
          _testAudioError = '服务器返回了空的音频数据';
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
      String errorMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg = '连接超时，请检查网络';
          break;
        case DioExceptionType.receiveTimeout:
          errorMsg = '接收超时，服务器响应过慢';
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
            bodyStr = body?.toString() ?? '无响应体';
          }
          errorMsg = 'HTTP $statusCode: $bodyStr';
          break;
        case DioExceptionType.cancel:
          errorMsg = '请求已取消';
          break;
        default:
          if (e.type == DioExceptionType.connectionError && kIsWeb) {
            errorMsg =
                '无法连接到服务器。Web端常见原因：CORS跨域限制或API地址不正确。请检查：1) 供应商配置中的API地址是否正确 2) 服务器是否允许跨域请求';
          } else {
            errorMsg = '网络错误: ${e.message}';
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
            child: const Text('知道了'),
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
        const SnackBar(
          content: Text('模型ID为必填项'),
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
        const SnackBar(
          content: Text('单次最长音频字数为必填项，请输入大于0的整数'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证自定义参数：每个参数都必须有参数名和默认值，且参数名不能重复
    final seenNames = <String>{};
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      final name = param.paramName.trim();
      if (name.isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和默认值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已存在该参数: $name'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // 验证音量范围：必须成对填写或同时留空
    final volMinText = _volumeMinController.text.trim();
    final volMaxText = _volumeMaxController.text.trim();
    if (volMinText.isNotEmpty != volMaxText.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('音量范围必须成对填写（最小音量和最大音量），或者同时留空'),
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
        const SnackBar(
          content: Text('语速范围必须成对填写（最小语速和最大语速），或者同时留空'),
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

    var configs = entry.configs.map((c) => c.copy()).toList();
    var models = List<ModelConfig>.from(configs[widget.configIndex].models);

    if (_isEditing &&
        widget.modelIndex >= 0 &&
        widget.modelIndex < models.length) {
      models[widget.modelIndex] = modelConfig;
    } else {
      models.insert(0, modelConfig);
    }

    configs[widget.configIndex] = ProviderConfigItem(
      providerName: configs[widget.configIndex].providerName,
      host: configs[widget.configIndex].host,
      key: configs[widget.configIndex].key,
      models: models,
    );

    final updated = ProviderEntry(
      id: entry.id,
      name: entry.name,
      configs: configs,
    );

    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('模型已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? (_nameController.text.isNotEmpty ? _nameController.text : '编辑模型')
        : '新建模型';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃修改？'),
            content: const Text('当前有未保存的修改，确定要放弃吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续编辑'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('放弃'),
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
              label: Text(_isSaving ? '保存中...' : '保存'),
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
                const Text('模型名称',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showInfoDialog(
                    '模型名称',
                    '模型名称是用于显示和识别的友好名称，例如"GPT-4o Mini TTS"。\n\n同一个供应商下多个模型时，通过名称可以快速区分它们。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '输入模型名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================================
            // 模型ID
            // ==========================================================
            Row(
              children: [
                const Text('模型ID *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showInfoDialog(
                    '模型ID',
                    '模型ID是调用API时使用的唯一标识符，例如"gpt-4o-mini-tts"。\n\nAPI请求时以此ID指定要使用的模型，必须与供应商提供的模型ID一致。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelIdController,
              decoration: const InputDecoration(
                hintText: '输入模型ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================================
            // 音量范围
            // ==========================================================
            const Text('音量范围', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _volumeMinController,
                    decoration: const InputDecoration(
                      labelText: '最小音量',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('~'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _volumeMaxController,
                    decoration: const InputDecoration(
                      labelText: '最大音量',
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
            const Text('语速范围', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speedMinController,
                    decoration: const InputDecoration(
                      labelText: '最小语速',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('~'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _speedMaxController,
                    decoration: const InputDecoration(
                      labelText: '最大语速',
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
              decoration: const InputDecoration(
                labelText: '单次最长音频字数 *',
                hintText: '例如: 1000',
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
                title: Text('音色 (${_voices.length})'),
                subtitle: Text(
                  _voices.isEmpty
                      ? '暂无音色，点击进入编辑'
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
                const Text('自定义参数',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加参数'),
                  onPressed: _addCustomParam,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_customParams.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('暂无自定义参数', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...List.generate(_customParams.length, (i) {
                final param = _customParams[i];
                // 检查当前参数名是否与其他参数重复
                final name = param.paramName.trim();
                final isDuplicate = name.isNotEmpty &&
                    _customParams
                            .indexWhere((p) => p.paramName.trim() == name) !=
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
                                  labelText: '参数名',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText: isDuplicate ? '已存在该参数' : null,
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: param.type,
                                  isDense: true,
                                  items: ParamType.values
                                      .map((t) => DropdownMenuItem(
                                            value: t.value,
                                            child: Text(t.label,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          ))
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
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () => _removeCustomParam(i),
                              tooltip: '删除参数',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: param.defaultValue,
                          decoration: InputDecoration(
                            labelText: '默认参数值',
                            hintText: param.paramType.defaultValueHint,
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
                                ? '在请求格式中生成: "{{${param.paramName}}}"'
                                : '在请求格式中生成: {{${param.paramName}}}',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          const Text('模型是否支持 instruction 参数'),
                          Text(
                            '开启后可在TTS请求中附加指令描述语气、情绪、语速等',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildToggleButton('是', true, _supportInstruction,
                        (v) => setState(() => _supportInstruction = v)),
                    const SizedBox(width: 8),
                    _buildToggleButton('否', false, _supportInstruction,
                        (v) => setState(() => _supportInstruction = v)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          const Text('模型是否支持流式输出'),
                          Text(
                            '开启后部分需要流式输出的场景将可以使用该模型，请确认模型支持流式输出再开启',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildToggleButton('是', true, _supportStream,
                        (v) => setState(() => _supportStream = v)),
                    const SizedBox(width: 8),
                    _buildToggleButton('否', false, _supportStream,
                        (v) => setState(() => _supportStream = v)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ==========================================================
            // 裁切设置
            // ==========================================================
            _buildTrimSection(),
            const SizedBox(height: 8),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimSection() {
    final customPresets = ref.watch(customTrimPresetsProvider);

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
                const Text('裁切设置',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                if (_selectedTrimPresetId != null &&
                    _selectedTrimPresetId != BuiltinTrimPresetIds.none)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTrimPresetLabel(_selectedTrimPresetId, customPresets),
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('选择对音频进行裁切的方式',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),

            // 内置预设
            ...getBuiltinTrimPresets().map((preset) {
              final presetId = preset['id'] as String;
              return RadioListTile<String?>(
                title: Text(preset['name'] as String),
                subtitle: Text(
                  presetId == BuiltinTrimPresetIds.none
                      ? '不对音频做任何裁切'
                      : '裁切开头 ${preset['durationSeconds']}s',
                  style: const TextStyle(fontSize: 12),
                ),
                value: preset['id'] as String,
                // ignore: deprecated_member_use
                groupValue: _selectedTrimPresetId ?? BuiltinTrimPresetIds.none,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _selectedTrimPresetId = v),
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
                final dirLabel = preset.direction == 'head' ? '开头' : '结尾';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String?>(
                    value: preset.id,
                    // ignore: deprecated_member_use
                    groupValue:
                        _selectedTrimPresetId ?? BuiltinTrimPresetIds.none,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => _selectedTrimPresetId = v),
                  ),
                  title:
                      Text(preset.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '裁切$dirLabel ${preset.durationSeconds.toStringAsFixed(3)}s',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditTrimPresetDialog(preset),
                        tooltip: '编辑',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除裁切预设'),
                              content: Text('确定要删除裁切预设"${preset.name}"吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(customTrimPresetsProvider.notifier)
                                .remove(preset.id);
                            // 如果当前选中的是这个预设，重置为不裁切
                            if (_selectedTrimPresetId == preset.id) {
                              setState(() => _selectedTrimPresetId = null);
                            }
                          }
                        },
                        tooltip: '删除',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
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
                label: const Text('添加自定义裁切'),
                onPressed: _showAddTrimPresetDialog,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isTestingAudio
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_isTestingAudio ? '播放中...' : '播放测试音频'),
                onPressed: _isTestingAudio ? null : _playTestAudio,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_testAudioError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _testAudioError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool value, bool currentValue,
      ValueChanged<bool> onChanged) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
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
