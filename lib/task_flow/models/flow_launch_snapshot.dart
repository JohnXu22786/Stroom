import 'dart:convert';

import '../../models/assistant.dart';
import '../../providers/provider_config.dart';
import '../../utils/provider_models.dart';
import 'task_flow_definition.dart';
import 'block_type_definition.dart';

/// Detached launch configuration. Connection secrets remain in the provider
/// store and are resolved by stable identity whenever an execution runs.
class FlowLaunchSnapshot {
  final String _encoded;
  FlowLaunchSnapshot._(Map<String, dynamic> map)
      : _encoded = jsonEncode(_publicValue(map));

  static const _unreadableJson = '[stroom:redacted-invalid-json]';

  static bool _credentialName(String name) => const {
        'key',
        'apikey',
        'xapikey',
        'authorization',
        'password',
        'secret',
        'accesstoken',
        'token',
        'credentials',
        'credential',
        'clientsecret',
        'authtoken',
        'xauthtoken',
        'xauthkey',
        'xaccesstoken',
      }.contains(name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

  static bool _parameterList(String? field) => const {
        'customParams',
        'customParameters',
        'reasoningParams'
      }.contains(field);

  static String _parameterName(Map item) =>
      (item['paramName'] ?? item['name'] ?? '').toString();

  static const _jsonParameterFields = <String>{
    'defaultValue',
    'value',
    'options',
    'optionOrder',
    'onValue',
    'offValue'
  };

  static bool _jsonParameter(Map item) =>
      item['type']?.toString().toLowerCase() == 'json';

  static bool _looksLikeJsonObject(String value) {
    final trimmed = value.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  static String _publicJsonString(String value, {bool strictJson = false}) {
    if (!strictJson && !_looksLikeJsonObject(value)) return value;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map && decoded is! List) return value;
      final safe = _publicValue(decoded, jsonStrings: true);
      return jsonEncode(safe) == jsonEncode(decoded) ? value : jsonEncode(safe);
    } catch (_) {
      // A malformed JSON-typed parameter may still contain a credential.
      // Fail closed; hydration uses the current same-identity value.
      return _unreadableJson;
    }
  }

  static String _withCurrentJsonString(String frozen, String current) {
    if (frozen == _unreadableJson) return current;
    if (!_looksLikeJsonObject(frozen) || !_looksLikeJsonObject(current)) {
      return frozen;
    }
    try {
      final frozenJson = jsonDecode(frozen);
      final currentJson = jsonDecode(current);
      if ((frozenJson is! Map && frozenJson is! List) ||
          (currentJson is! Map && currentJson is! List)) {
        return frozen;
      }
      return jsonEncode(
          _withCurrentCredentials(frozenJson, currentJson, jsonStrings: true));
    } catch (_) {
      return frozen;
    }
  }

  static Map<String, dynamic> _publicParameter(Map item,
          {bool jsonStrings = false}) =>
      {
        for (final entry in item.entries)
          if (!_credentialName(entry.key.toString()))
            entry.key.toString(): _publicValue(entry.value,
                field: entry.key.toString(),
                jsonStrings: jsonStrings ||
                    (_jsonParameter(item) &&
                        _jsonParameterFields.contains(entry.key.toString())),
                strictJson: _jsonParameter(item) &&
                    _jsonParameterFields.contains(entry.key.toString()) &&
                    (entry.value is String ||
                        entry.key == 'options' ||
                        entry.key == 'optionOrder'))
      };

  static dynamic _publicValue(dynamic value,
      {String? field, bool jsonStrings = false, bool strictJson = false}) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (!_credentialName(entry.key.toString()))
            entry.key.toString(): _publicValue(entry.value,
                field: entry.key.toString(),
                jsonStrings:
                    jsonStrings || entry.key.toString() == 'typeConfig')
      };
    }
    if (value is List) {
      return value
          .where((item) =>
              !_parameterList(field) ||
              item is! Map ||
              !_credentialName(_parameterName(item)))
          .map((item) => _parameterList(field) && item is Map
              ? _publicParameter(item, jsonStrings: jsonStrings)
              : _publicValue(item,
                  jsonStrings: jsonStrings, strictJson: strictJson))
          .toList();
    }
    if (value is String && jsonStrings) {
      return _publicJsonString(value, strictJson: strictJson);
    }
    return value;
  }

  /// Secret fields intentionally absent from the snapshot are hydrated only
  /// from the same current model/config identity, including custom auth params.
  static dynamic _withCurrentCredentials(dynamic frozen, dynamic current,
      {String? field, bool jsonStrings = false}) {
    if (frozen is Map && current is Map) {
      final result = Map<String, dynamic>.from(frozen);
      for (final entry in current.entries) {
        final key = entry.key.toString();
        if (_credentialName(key)) {
          result[key] = entry.value;
        } else if (result.containsKey(key)) {
          result[key] = _withCurrentCredentials(result[key], entry.value,
              field: key, jsonStrings: jsonStrings || key == 'typeConfig');
        }
      }
      return result;
    }
    if (frozen is List && current is List) {
      if (_parameterList(field)) {
        final result = [
          for (final item in frozen)
            if (item is Map && _jsonParameter(item))
              _withCurrentJsonParameter(
                  item,
                  current
                      .where((candidate) =>
                          candidate is Map &&
                          _parameterName(candidate) == _parameterName(item))
                      .firstOrNull)
            else
              item
        ];
        result.addAll(current.where(
            (item) => item is Map && _credentialName(_parameterName(item))));
        return result;
      }
      if (jsonStrings) {
        return [
          for (var i = 0; i < frozen.length; i++)
            i < current.length
                ? _withCurrentCredentials(frozen[i], current[i],
                    jsonStrings: true)
                : frozen[i]
        ];
      }
      return frozen;
    }
    if (jsonStrings && frozen is String && current is String) {
      return _withCurrentJsonString(frozen, current);
    }
    return frozen;
  }

  static Map<String, dynamic> _withCurrentJsonParameter(
      Map frozen, dynamic current) {
    if (current is! Map) return Map<String, dynamic>.from(frozen);
    final result = Map<String, dynamic>.from(frozen);
    for (final field in _jsonParameterFields) {
      if (result.containsKey(field) && current.containsKey(field)) {
        result[field] = _withCurrentCredentials(result[field], current[field],
            field: field, jsonStrings: true);
      }
    }
    return result;
  }

  factory FlowLaunchSnapshot.capture(TaskFlowDefinition flow,
      ProviderEntriesState providers, List<Assistant> assistants,
      {Map<String, dynamic> synthesisDefaults = const {},
      Map<String, String>? selectedChatModel}) {
    final models = <Map<String, dynamic>>[];
    final selectedAssistants = <Map<String, dynamic>>[];
    final configs = <Map<String, dynamic>>[];
    final chatModels = <Map<String, dynamic>>[];
    void capture(ProviderModel selected) {
      models.add(
          {'configId': selected.config.id, 'model': selected.model.toMap()});
      // Connection host/key remain exclusively in the credential store.
      final settings = selected.config.toMap()
        ..remove('host')
        ..remove('key')
        ..remove('models');
      configs.add(settings);
    }

    for (final block in flow.blocks) {
      final ref = block.params['modelRef'];
      for (final type in ['tts', 'asr', 'ocr']) {
        final selected = resolveProviderModel(providers, type, ref);
        if (selected == null) {
          continue;
        }
        // Snapshot model tuning without copying the provider's credentials.
        capture(selected);
      }
      final id = block.params['assistantId'];
      final assistant = assistants.where((a) => a.id == id).firstOrNull;
      if (assistant != null) {
        final available = flattenProviderModels(providers, 'llm');
        final boundId = assistant.modelId?.trim();
        final requestedId = boundId != null && boundId.isNotEmpty
            ? boundId
            : assistant.defaultModelId;
        final byId =
            available.where((s) => s.model.modelId == requestedId).toList();
        final byProvider = byId
            .where(
                (s) => s.config.providerName == assistant.defaultProviderName)
            .toList();
        final byName = available
            .where((s) =>
                '${s.model.name.isEmpty ? s.model.modelId : s.model.name} | ${s.config.providerName}' ==
                assistant.defaultModelName)
            .toList();
        final bySelectedIdentity = selectedChatModel == null
            ? null
            : available
                .where((s) =>
                    s.config.id == selectedChatModel['configId'] &&
                    s.model.id == selectedChatModel['modelId'])
                .firstOrNull;
        final selected = boundId != null && boundId.isNotEmpty
            ? byId.firstOrNull
            : requestedId != null && requestedId.isNotEmpty
                ? byProvider.firstOrNull ??
                    byId.firstOrNull ??
                    byName.firstOrNull
                : byName.firstOrNull ?? bySelectedIdentity;
        if (selected == null &&
            selectedChatModel != null &&
            bySelectedIdentity == null &&
            (boundId == null || boundId.isEmpty) &&
            (requestedId == null || requestedId.isEmpty)) {
          throw StateError('当前选择的对话模型已删除或供应商配置不可用，请重新选择模型');
        }
        final map = assistant.toMap();
        if (selected != null) {
          capture(selected);
          chatModels
              .add({'blockId': block.id, ...providerModelReference(selected)});
          map.remove('modelId');
          map['defaultModelId'] = selected.model.modelId;
          map['defaultProviderName'] = selected.config.providerName;
          map['defaultModelName'] =
              '${selected.model.name} | ${selected.config.providerName}';
        }
        selectedAssistants.add(map);
      }
    }
    return FlowLaunchSnapshot._({
      'flow': flow
          .copyWith(
              blocks: flow.blocks
                  .map((b) =>
                      b.typeKey == BlockType.tts && synthesisDefaults.isNotEmpty
                          ? b.copyWithParam(
                              '_launchSynthesisConfig', synthesisDefaults)
                          : b)
                  .toList())
          .toMap(),
      'models': models,
      'configs': configs,
      'assistants': selectedAssistants,
      'chatModels': chatModels
    });
  }

  TaskFlowDefinition get flow => TaskFlowDefinition.fromMap(
      Map<String, dynamic>.from(toMap()['flow'] as Map));
  List<Assistant> get assistants => (toMap()['assistants'] as List? ?? [])
      .map((a) => Assistant.fromMap(Map<String, dynamic>.from(a as Map)))
      .toList();

  /// Public assistant settings stay frozen; authentication comes only from
  /// the current assistant with the same local identity.
  List<Assistant> resolveAssistants(List<Assistant> current) =>
      assistants.map((assistant) {
        final live = current.where((a) => a.id == assistant.id).firstOrNull;
        return live == null
            ? assistant
            : Assistant.fromMap(Map<String, dynamic>.from(
                _withCurrentCredentials(assistant.toMap(), live.toMap())
                    as Map));
      }).toList();

  /// Scope resolution to the blocks that will run. Dispatch resolves one block
  /// at a time so chat's API-ID lookup cannot choose a competing live model.
  ProviderEntriesState resolveProviders(ProviderEntriesState current,
      {Iterable<TaskFlowBlock>? blocks}) {
    final map = toMap();
    final frozen = (map['models'] as List? ?? []).cast<Map>();
    final configs = (map['configs'] as List? ?? []).cast<Map>();
    final chatModels = (map['chatModels'] as List? ?? []).cast<Map>();
    final references = <(String, String)>{};
    for (final block in blocks ?? flow.blocks) {
      final reference = block.typeKey == BlockType.chat
          ? chatModels.where((m) => m['blockId'] == block.id).firstOrNull
          : block.params['modelRef'];
      if (reference is Map &&
          reference['configId'] is String &&
          reference['modelId'] is String) {
        references.add(
            (reference['configId'] as String, reference['modelId'] as String));
      }
    }
    final selectedModels = <Map>[];
    for (final reference in references) {
      final captured = frozen
          .where((m) =>
              m['configId'] == reference.$1 &&
              (m['model'] as Map)['id'] == reference.$2)
          .firstOrNull;
      final matches = current.entries
          .expand((e) => e.configs)
          .where((config) =>
              config.id == reference.$1 &&
              config.host.trim().isNotEmpty &&
              config.key.trim().isNotEmpty &&
              config.models.any((model) => model.id == reference.$2))
          .toList();
      if (captured == null || matches.length != 1) {
        throw StateError('运行快照引用的模型或供应商配置已删除或不可用，请使用最新配置重试');
      }
      selectedModels.add(captured);
    }
    return ProviderEntriesState(entries: [
      for (final entry in current.entries)
        if (entry.configs.any(
            (config) => selectedModels.any((m) => m['configId'] == config.id)))
          ProviderEntry.fromMap({
            ...entry.toMap(),
            'configs': [
              for (final config in entry.configs)
                if (selectedModels.any((m) => m['configId'] == config.id))
                  {
                    ...config.toMap(),
                    ...Map<String, dynamic>.from(_withCurrentCredentials(
                        configs.firstWhere((s) => s['id'] == config.id),
                        config.toMap()) as Map),
                    'models': [
                      for (final model in config.models)
                        if (references.contains((config.id, model.id)))
                          _withCurrentCredentials(
                              selectedModels.firstWhere((m) =>
                                  m['configId'] == config.id &&
                                  (m['model'] as Map)['id'] ==
                                      model.id)['model'],
                              model.toMap())
                    ]
                  }
            ]
          })
    ]);
  }

  Map<String, dynamic> toMap() => jsonDecode(_encoded) as Map<String, dynamic>;
  factory FlowLaunchSnapshot.fromMap(Map<String, dynamic> map) =>
      FlowLaunchSnapshot._(map);
}
