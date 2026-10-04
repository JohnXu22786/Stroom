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
      : _encoded = jsonEncode(_publicValue(map, snapshotRoot: true));

  static const _unreadableJson = '[stroom:redacted-invalid-json]';
  static const _unreadableEndpoint = '[stroom:redacted-invalid-endpoint]';
  static const _redactedUrlCredential = 'stroom-redacted-url-credential';

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
        'apisecret',
        'authtoken',
        'refreshtoken',
        'sessiontoken',
        'idtoken',
        'clienttoken',
        'privatekey',
        'signingkey',
        'signature',
        'xamzsignature',
        'xamzcredential',
        'xamzsecuritytoken',
        'xgoogsignature',
        'xgoogcredential',
        'sig',
        'auth',
        'xauthtoken',
        'xauthkey',
        'xaccesstoken',
        'cookie',
        'setcookie',
        'proxyauthorization',
      }.contains(name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

  static bool _endpointField(String? name) => const {
        'host',
        'url',
        'baseurl',
        'endpointurl',
        'endpoint',
      }.contains(name?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

  static bool _urlContainsCredentials(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.userInfo.isNotEmpty ||
            uri.queryParametersAll.keys.any(_credentialName) ||
            (uri.hasAuthority && uri.hasFragment));
  }

  static bool _redactedEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.userInfo == _redactedUrlCredential ||
            uri.fragment == _redactedUrlCredential ||
            uri.queryParametersAll.values
                .any((values) => values.contains(_redactedUrlCredential)));
  }

  /// Keep the destination and nonsecret query settings, while retaining only
  /// markers for credentials embedded in a URL. Private user info and fragment
  /// values must never be written into execution records.
  static String _publicEndpoint(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return _unreadableEndpoint;
    if (uri.userInfo.isEmpty &&
        !uri.queryParametersAll.keys.any(_credentialName) &&
        !uri.hasFragment) {
      return value;
    }
    final query = uri.queryParametersAll.map((key, values) => MapEntry(
          key,
          _credentialName(key)
              ? List.filled(values.length, _redactedUrlCredential)
              : values,
        ));
    return (uri.hasAuthority
            ? uri.replace(
                userInfo: uri.userInfo.isEmpty ? '' : _redactedUrlCredential,
                queryParameters: query.isEmpty ? null : query,
                fragment: uri.fragment.isEmpty ? null : _redactedUrlCredential,
              )
            : uri.replace(
                queryParameters: query.isEmpty ? null : query,
                fragment: uri.fragment.isEmpty ? null : _redactedUrlCredential))
        .toString();
  }

  static bool _hasSignedQuery(Uri uri) => uri.queryParametersAll.keys.any(
        (key) => const {'xamzsignature', 'xgoogsignature'}.contains(
          key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        ),
      );

  static bool _signedEndpointInputsMatch(Uri launch, Uri live) {
    if (launch.scheme != live.scheme ||
        launch.host != live.host ||
        launch.port != live.port ||
        launch.path != live.path) {
      return false;
    }
    final launchQuery = launch.queryParametersAll;
    final liveQuery = live.queryParametersAll;
    final publicKeys = launchQuery.keys.where((key) => !_credentialName(key));
    final livePublicKeys =
        liveQuery.keys.where((key) => !_credentialName(key)).toSet();
    if (publicKeys.length != livePublicKeys.length ||
        !livePublicKeys.containsAll(publicKeys)) {
      return false;
    }
    for (final key in publicKeys) {
      final launchValues = launchQuery[key]!.toList()..sort();
      final liveValues = liveQuery[key]!.toList()..sort();
      if (jsonEncode(launchValues) != jsonEncode(liveValues)) return false;
    }
    return true;
  }

  static String _withCurrentEndpoint(String frozen, String current) {
    if (frozen == _unreadableEndpoint) {
      throw StateError('运行快照中的服务端点无法安全恢复，请使用最新配置重试');
    }
    final launch = Uri.tryParse(frozen);
    final live = Uri.tryParse(current);
    if (launch == null || (live == null && _redactedEndpoint(frozen))) {
      throw StateError('运行快照中的服务端点凭据无法安全恢复，请使用最新配置重试');
    }
    if (live == null) return frozen;
    // AWS/GCP signatures cover the destination and public query inputs. A
    // refreshed signature cannot be combined with changed frozen inputs.
    if ((_hasSignedQuery(launch) || _hasSignedQuery(live)) &&
        !_signedEndpointInputsMatch(launch, live)) {
      throw StateError('运行快照中的签名 URL 服务端点或公开签名参数已改变，请使用最新配置重新运行');
    }
    final fragment =
        launch.fragment == _redactedUrlCredential ? live.fragment : null;
    if (fragment != null && fragment.isEmpty) {
      throw StateError('运行快照中的 URL 片段凭据已移除，请使用最新配置重试');
    }
    final userInfo = live.userInfo.isNotEmpty ? live.userInfo : launch.userInfo;
    if (launch.hasAuthority && userInfo == _redactedUrlCredential) {
      throw StateError('运行快照中的服务端点凭据已移除，请使用最新配置重试');
    }
    final query = launch.queryParametersAll.map((key, values) {
      if (!_credentialName(key)) return MapEntry(key, values);
      final liveValues = live.queryParametersAll[key];
      if (liveValues == null ||
          liveValues.length != values.length ||
          liveValues.any((value) => value.isEmpty)) {
        throw StateError('运行快照中的服务端点凭据已移除，请使用最新配置重试');
      }
      return MapEntry(key, liveValues);
    });
    // A provider may add a new authentication query parameter while retaining
    // its local identity. New noncredential settings must not change the run.
    for (final entry in live.queryParametersAll.entries) {
      if (_credentialName(entry.key) && !query.containsKey(entry.key)) {
        query[entry.key] = entry.value;
      }
    }
    return (launch.hasAuthority
            ? launch.replace(
                userInfo: userInfo,
                queryParameters: query.isEmpty ? null : query,
                fragment: fragment)
            : launch.replace(
                queryParameters: query.isEmpty ? null : query,
                fragment: fragment))
        .toString();
  }

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

  static bool _looksLikeJsonValue(String value) =>
      _looksLikeJsonObject(value) || value.trimLeft().startsWith('"');

  static String _publicJsonString(String value, {bool strictJson = false}) {
    if (!strictJson && !_looksLikeJsonValue(value)) return value;
    try {
      final decoded = jsonDecode(value);
      dynamic safe;
      if (decoded is String) {
        if (!_looksLikeJsonValue(decoded) && _urlContainsCredentials(decoded)) {
          safe = _publicEndpoint(decoded);
        } else {
          // A quoted string may itself contain encoded JSON. Only parse a
          // valid nested value; ordinary strings remain launch settings.
          try {
            jsonDecode(decoded);
          } on FormatException {
            return value;
          }
          safe = _publicJsonString(decoded);
        }
      } else if (decoded is Map || decoded is List) {
        safe = _publicValue(decoded, jsonStrings: true);
      } else {
        return value;
      }
      return jsonEncode(safe) == jsonEncode(decoded) ? value : jsonEncode(safe);
    } catch (_) {
      // A malformed JSON-typed parameter may still contain a credential.
      // Fail closed; hydration uses the current same-identity value.
      return strictJson || _looksLikeJsonObject(value)
          ? _unreadableJson
          : value;
    }
  }

  static String _withCurrentJsonString(String frozen, String current) {
    if (frozen == _unreadableJson) return current;
    if (!_looksLikeJsonValue(frozen) || !_looksLikeJsonValue(current)) {
      return frozen;
    }
    dynamic frozenJson;
    dynamic currentJson;
    try {
      frozenJson = jsonDecode(frozen);
      currentJson = jsonDecode(current);
    } catch (_) {
      return frozen;
    }
    if ((frozenJson is! Map && frozenJson is! List && frozenJson is! String) ||
        (currentJson is! Map &&
            currentJson is! List &&
            currentJson is! String)) {
      return frozen;
    }
    // Matching failures must reach the caller; silently returning redacted
    // snapshot JSON could make a retry run with the wrong credentials.
    final hydrated =
        _withCurrentCredentials(frozenJson, currentJson, jsonStrings: true);
    return frozenJson is String && hydrated == frozenJson
        ? frozen
        : jsonEncode(hydrated);
  }

  static bool _containsCredential(dynamic value) {
    if (value is Map) {
      return value.entries.any((entry) =>
          _credentialName(entry.key.toString()) ||
          _containsCredential(entry.value));
    }
    if (value is List) return value.any(_containsCredential);
    if (value is String) {
      if (_looksLikeJsonValue(value)) {
        try {
          return _containsCredential(jsonDecode(value));
        } catch (_) {
          return false;
        }
      }
      return _urlContainsCredentials(value);
    }
    return false;
  }

  static bool _containsUnreadableJson(dynamic value) {
    if (value == _unreadableJson) return true;
    if (value is Map) return value.values.any(_containsUnreadableJson);
    if (value is List) return value.any(_containsUnreadableJson);
    if (value is String && _looksLikeJsonValue(value)) {
      try {
        return _containsUnreadableJson(jsonDecode(value));
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static bool _containsEndpointMarker(dynamic value) {
    if (value is String) {
      return value.contains(_redactedUrlCredential) ||
          value.contains(_unreadableEndpoint);
    }
    if (value is Map) return value.values.any(_containsEndpointMarker);
    if (value is List) return value.any(_containsEndpointMarker);
    return false;
  }

  static dynamic _canonicalPublicValue(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {
        for (final key in keys) key: _canonicalPublicValue(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalPublicValue).toList();
    if (value is String && _looksLikeJsonValue(value)) {
      try {
        return jsonEncode(_canonicalPublicValue(jsonDecode(value)));
      } on FormatException {
        return value;
      }
    }
    if (value is String) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.hasAuthority && uri.hasQuery) {
        final query = uri.queryParametersAll;
        final keys = query.keys.toList()..sort();
        // Compare public query inputs without changing frozen request URLs.
        // Sorting values retains duplicate counts and ignores query order.
        return uri.replace(queryParameters: {
          for (final key in keys) key: query[key]!.toList()..sort(),
        }).toString();
      }
    }
    return value;
  }

  static String _publicFingerprint(dynamic value) =>
      jsonEncode(_canonicalPublicValue(_publicValue(value, jsonStrings: true)));

  static List<int> _jsonArrayCredentialMatches(List frozen, List current) {
    Never mismatch() => throw StateError('运行快照中的 JSON 数组项无法唯一匹配当前凭据，请使用最新配置重试');
    bool hasIdentity(dynamic item, String field) {
      if (item is! Map || !item.containsKey(field)) return false;
      final value = item[field];
      return value is String && value.isNotEmpty ||
          value is num ||
          value is bool;
    }

    for (final field in ['id', 'name', 'route', 'path']) {
      if (!frozen.every((item) => hasIdentity(item, field))) {
        continue;
      }
      if (!current.every((item) => hasIdentity(item, field))) {
        mismatch();
      }
      final frozenKeys =
          frozen.map((item) => jsonEncode((item as Map)[field])).toList();
      final currentKeys =
          current.map((item) => jsonEncode((item as Map)[field])).toList();
      if (frozenKeys.toSet().length != frozenKeys.length ||
          currentKeys.toSet().length != currentKeys.length) {
        mismatch();
      }
      final matches = [
        for (final key in frozenKeys) currentKeys.indexOf(key),
      ];
      if (matches.contains(-1)) {
        mismatch();
      }
      return matches;
    }

    // Without a stable field, only an exact and unique public projection
    // identifies an entry. Changed or ambiguous settings require a new run.
    final frozenKeys = frozen.map(_publicFingerprint).toList();
    final currentKeys = current.map(_publicFingerprint).toList();
    if (frozenKeys.toSet().length != frozenKeys.length ||
        currentKeys.toSet().length != currentKeys.length) {
      mismatch();
    }
    final matches = [
      for (final key in frozenKeys) currentKeys.indexOf(key),
    ];
    if (matches.contains(-1)) {
      mismatch();
    }
    return matches;
  }

  static Map _matchingJsonParameter(List frozen, List current, Map item) {
    final name = _parameterName(item);
    final frozenMatches = frozen
        .where((candidate) =>
            candidate is Map &&
            _jsonParameter(candidate) &&
            _parameterName(candidate) == name)
        .length;
    final liveMatches = current
        .whereType<Map>()
        .where((candidate) => _parameterName(candidate) == name)
        .toList();
    if (name.isEmpty || frozenMatches != 1 || liveMatches.length != 1) {
      throw StateError('运行快照中的 JSON 参数无法唯一匹配当前凭据，请使用最新配置重试');
    }
    return liveMatches.single;
  }

  static Map _matchingUrlParameter(List frozen, List current, Map item) {
    final name = _parameterName(item);
    final frozenMatches = frozen
        .where((candidate) =>
            candidate is Map && _parameterName(candidate) == name)
        .length;
    final liveMatches = current
        .whereType<Map>()
        .where((candidate) => _parameterName(candidate) == name)
        .toList();
    if (name.isEmpty ||
        frozenMatches != 1 ||
        liveMatches.length != 1 ||
        liveMatches.single['type'] != item['type']) {
      throw StateError('运行快照中的 URL 参数无法唯一匹配当前凭据，请使用最新配置重试');
    }
    return liveMatches.single;
  }

  static Map<String, dynamic> _publicParameter(Map item,
          {bool jsonStrings = false}) =>
      {
        for (final entry in item.entries)
          if (!_credentialName(entry.key.toString()))
            entry.key.toString(): _publicValue(entry.value,
                field: entry.key.toString(),
                urlStrings: _jsonParameterFields.contains(entry.key.toString()),
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
      {String? field,
      bool jsonStrings = false,
      bool strictJson = false,
      bool providerSettings = false,
      bool snapshotRoot = false,
      bool urlStrings = false}) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          if (!_credentialName(entry.key.toString()))
            entry.key.toString(): _publicValue(entry.value,
                field: entry.key.toString(),
                providerSettings: providerSettings ||
                    (snapshotRoot &&
                        (entry.key == 'models' || entry.key == 'configs')),
                urlStrings: urlStrings,
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
                  jsonStrings: jsonStrings,
                  strictJson: strictJson,
                  providerSettings: providerSettings,
                  urlStrings: urlStrings))
          .toList();
    }
    if (value is String && jsonStrings && value.trimLeft().startsWith('"')) {
      return _publicJsonString(value, strictJson: strictJson);
    }
    if (value is String && urlStrings && _urlContainsCredentials(value)) {
      return _publicEndpoint(value);
    }
    if (value is String && jsonStrings) {
      if (_endpointField(field) || _urlContainsCredentials(value)) {
        return _publicEndpoint(value);
      }
      return _publicJsonString(value, strictJson: strictJson);
    }
    if (value is String && providerSettings && _endpointField(field)) {
      return _publicEndpoint(value);
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
              _withCurrentParameter(
                  item, _matchingJsonParameter(frozen, current, item),
                  jsonStrings: true)
            else if (item is Map && _containsEndpointMarker(item))
              _withCurrentParameter(
                  item, _matchingUrlParameter(frozen, current, item))
            else
              item
        ];
        result.addAll(current.where(
            (item) => item is Map && _credentialName(_parameterName(item))));
        return result;
      }
      if (jsonStrings || _containsEndpointMarker(frozen)) {
        if (!_containsCredential(current) &&
            !_containsUnreadableJson(frozen) &&
            !_containsEndpointMarker(frozen)) {
          return frozen;
        }
        // A sole entry cannot be mistaken for another entry. In longer
        // arrays, only a unique match of public settings may receive secrets.
        if (frozen.length == 1 && current.length == 1) {
          if (frozen.single is Map &&
              ['id', 'name', 'route', 'path']
                  .any((field) => (frozen.single as Map).containsKey(field))) {
            _jsonArrayCredentialMatches(frozen, current);
          }
          return [
            _withCurrentCredentials(frozen.single, current.single,
                jsonStrings: true),
          ];
        }
        final matches = _jsonArrayCredentialMatches(frozen, current);
        return [
          for (var i = 0; i < frozen.length; i++)
            _withCurrentCredentials(
              frozen[i],
              current[matches[i]],
              jsonStrings: true,
            ),
        ];
      }
      return frozen;
    }
    if (frozen is String &&
        current is String &&
        (frozen == _unreadableEndpoint ||
            (!_looksLikeJsonValue(frozen) && _redactedEndpoint(frozen)))) {
      return _withCurrentEndpoint(frozen, current);
    }
    if (jsonStrings && frozen is String && current is String) {
      if (_looksLikeJsonValue(frozen)) {
        return _withCurrentJsonString(frozen, current);
      }
      if (_endpointField(field) || _redactedEndpoint(frozen)) {
        return _withCurrentEndpoint(frozen, current);
      }
      return _withCurrentJsonString(frozen, current);
    }
    if (_endpointField(field) && frozen is String && current is String) {
      return _withCurrentEndpoint(frozen, current);
    }
    return frozen;
  }

  static Map<String, dynamic> _withCurrentParameter(Map frozen, dynamic current,
      {bool jsonStrings = false}) {
    if (current is! Map) return Map<String, dynamic>.from(frozen);
    final result = Map<String, dynamic>.from(frozen);
    for (final field in _jsonParameterFields) {
      if (result.containsKey(field) && current.containsKey(field)) {
        result[field] = _withCurrentCredentials(result[field], current[field],
            field: field, jsonStrings: jsonStrings);
      }
    }
    return result;
  }

  static dynamic _resolvedCredentials(dynamic frozen, dynamic current) {
    final hydrated = _withCurrentCredentials(frozen, current);
    if (_containsEndpointMarker(hydrated)) {
      throw StateError('运行快照中的 URL 凭据已移除或无法匹配，请使用最新配置重试');
    }
    if (_containsUnreadableJson(hydrated)) {
      throw StateError('运行快照中的 JSON 配置已移除或无法安全恢复，请使用最新配置重试');
    }
    return hydrated;
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
      // Freeze the public endpoint; hydrate credentials from its stable identity.
      final settings = selected.config.toMap()
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
      } else if (block.typeKey == BlockType.chat && selectedChatModel != null) {
        final selected =
            resolveProviderModel(providers, 'llm', selectedChatModel);
        if (selected == null) {
          throw StateError('当前选择的对话模型已删除或供应商配置不可用，请重新选择模型');
        }
        capture(selected);
        chatModels
            .add({'blockId': block.id, ...providerModelReference(selected)});
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

  /// Exact, credential-free LLM identity captured for this Chat block.
  Map<String, String>? chatModelReference(String blockId) {
    final matches = (toMap()['chatModels'] as List? ?? [])
        .whereType<Map>()
        .where((entry) => entry['blockId'] == blockId)
        .toList();
    if (matches.length != 1) return null;
    final entry = matches.single;
    final configId = entry['configId'];
    final modelId = entry['modelId'];
    if (configId is! String ||
        modelId is! String ||
        configId.isEmpty ||
        modelId.isEmpty) {
      return null;
    }
    return {'configId': configId, 'modelId': modelId};
  }

  /// Public assistant settings stay frozen; authentication comes only from
  /// the current assistant with the same local identity. A saved suffix only
  /// needs assistants used by its unfinished Chat blocks.
  List<Assistant> resolveAssistants(
    List<Assistant> current, {
    Iterable<TaskFlowBlock>? blocks,
  }) {
    final requiredIds = blocks
        ?.where((block) => block.typeKey == BlockType.chat)
        .map((block) => block.params['assistantId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    return assistants
        .where((assistant) =>
            requiredIds == null || requiredIds.contains(assistant.id))
        .map((assistant) {
      final matches = current.where((a) => a.id == assistant.id).toList();
      if (matches.length != 1) {
        throw StateError('运行快照引用的助手已删除或身份不唯一，请使用最新配置重试');
      }
      return Assistant.fromMap(Map<String, dynamic>.from(
          _resolvedCredentials(assistant.toMap(), matches.single.toMap())
              as Map));
    }).toList();
  }

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
                    ...Map<String, dynamic>.from(_resolvedCredentials(
                        configs.firstWhere((s) => s['id'] == config.id),
                        config.toMap()) as Map),
                    'models': [
                      for (final model in config.models)
                        if (references.contains((config.id, model.id)))
                          _resolvedCredentials(
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
