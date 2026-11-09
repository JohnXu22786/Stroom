import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'assistant.dart';

const int kRemoteAssistantSchemaVersion = 1;
const String kRemoteAssistantMarkdownFormat = 'stroom-markdown-yaml-v1';

/// The canonical Stroom assistant definition, independent of its file syntax.
/// JSON, YAML, and Markdown front matter are only encodings of this model.
class RemoteAssistantDefinition {
  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String version;
  final String prompt;
  final AssistantSettings settings;
  final String? defaultModelName;
  final String? defaultModelId;
  final String? defaultProviderName;
  final Set<String>? defaultToolNames;
  final Map<String, dynamic> extensions;

  const RemoteAssistantDefinition({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.version,
    required this.prompt,
    required this.settings,
    required this.defaultModelName,
    required this.defaultModelId,
    required this.defaultProviderName,
    required this.defaultToolNames,
    required this.extensions,
  });

  factory RemoteAssistantDefinition.parse(String source, {String? format}) {
    final parsed = _parseAssistantSource(source, format: format);
    final allowed = <String>{
      'schemaVersion',
      'id',
      'name',
      'description',
      'emoji',
      'version',
      'prompt',
      'settings',
      'defaultModelName',
      'defaultModelId',
      'defaultProviderName',
      'defaultToolNames',
      'extensions',
    };
    _rejectUnknownKeys(parsed, allowed, 'assistant');

    final schemaVersion = _requiredInt(parsed, 'schemaVersion');
    if (schemaVersion != kRemoteAssistantSchemaVersion) {
      throw FormatException('Unsupported schemaVersion: $schemaVersion');
    }
    final id = _requiredString(parsed, 'id');
    final name = _requiredString(parsed, 'name');
    final prompt = _requiredString(parsed, 'prompt');
    final version = _requiredString(parsed, 'version');
    if (id.length > 160 || name.length > 120 || prompt.trim().isEmpty) {
      throw const FormatException('Assistant id, name, or prompt is invalid.');
    }

    final settingsMap = _optionalMap(parsed, 'settings') ?? const {};
    _validateSettings(settingsMap);
    final defaultToolNames = _optionalStringSet(parsed, 'defaultToolNames');
    final extensions = _optionalMap(parsed, 'extensions') ?? const {};

    return RemoteAssistantDefinition(
      schemaVersion: schemaVersion,
      id: id,
      name: name,
      description: _optionalString(parsed, 'description') ?? '',
      emoji: _optionalString(parsed, 'emoji') ?? '🤖',
      version: version,
      prompt: prompt,
      settings: AssistantSettings.fromMap(settingsMap),
      defaultModelName: _optionalString(parsed, 'defaultModelName'),
      defaultModelId: _optionalString(parsed, 'defaultModelId'),
      defaultProviderName: _optionalString(parsed, 'defaultProviderName'),
      defaultToolNames: defaultToolNames,
      extensions: Map<String, dynamic>.from(extensions),
    );
  }

  Assistant toAssistant({
    required String? defaultModelName,
    required String? defaultModelId,
    required String? defaultProviderName,
    required Set<String>? defaultToolNames,
  }) =>
      Assistant(
        name: name,
        description: description,
        emoji: emoji,
        prompt: prompt,
        settings: settings,
        defaultModelName: defaultModelName,
        defaultModelId: defaultModelId,
        defaultProviderName: defaultProviderName,
        defaultToolNames: defaultToolNames,
      );
}

class RemoteAssistantCatalogEntry {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String version;
  final String file;
  final String format;
  final String sha256;
  final Set<String> requiresCapabilities;
  final Map<String, dynamic> extensions;

  const RemoteAssistantCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.version,
    required this.file,
    required this.format,
    required this.sha256,
    required this.requiresCapabilities,
    required this.extensions,
  });

  factory RemoteAssistantCatalogEntry.fromMap(Map<String, dynamic> map) {
    _rejectUnknownKeys(
      map,
      {
        'id',
        'name',
        'description',
        'emoji',
        'version',
        'file',
        'format',
        'sha256',
        'requiresCapabilities',
        'extensions',
      },
      'catalog entry',
    );
    final format = _requiredString(map, 'format');
    if (!const {
      'stroom-json-v1',
      'stroom-yaml-v1',
      kRemoteAssistantMarkdownFormat,
    }.contains(format)) {
      throw FormatException('Unsupported assistant format: $format');
    }
    final digest = _requiredString(map, 'sha256').toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Catalog sha256 must contain 64 hex digits.');
    }
    final capabilities =
        _optionalStringSet(map, 'requiresCapabilities') ?? const <String>{};
    const supportedCapabilities = {
      'stroom.assistant.v1',
      'stroom.settings.v1',
      'stroom.defaultTools.v1',
    };
    final unknownCapabilities = capabilities.difference(supportedCapabilities);
    if (unknownCapabilities.isNotEmpty) {
      throw FormatException(
        'Unsupported required capability(s): ${unknownCapabilities.join(', ')}',
      );
    }
    return RemoteAssistantCatalogEntry(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _optionalString(map, 'description') ?? '',
      emoji: _optionalString(map, 'emoji') ?? '🤖',
      version: _requiredString(map, 'version'),
      file: _requiredString(map, 'file'),
      format: format,
      sha256: digest,
      requiresCapabilities: capabilities,
      extensions: _optionalMap(map, 'extensions') ?? const {},
    );
  }
}

class RemoteAssistantCatalog {
  final int schemaVersion;
  final String catalogId;
  final String? updatedAt;
  final List<RemoteAssistantCatalogEntry> assistants;
  final Map<String, dynamic> extensions;

  const RemoteAssistantCatalog({
    required this.schemaVersion,
    required this.catalogId,
    required this.updatedAt,
    required this.assistants,
    required this.extensions,
  });

  factory RemoteAssistantCatalog.parse(String source) {
    final map = _decodeStructured(source);
    _rejectUnknownKeys(
      map,
      {'schemaVersion', 'catalogId', 'updatedAt', 'assistants', 'extensions'},
      'catalog',
    );
    final version = _requiredInt(map, 'schemaVersion');
    if (version != 1)
      throw FormatException('Unsupported catalog schemaVersion: $version');
    final rawEntries = map['assistants'];
    if (rawEntries is! List) {
      throw const FormatException('Catalog assistants must be a list.');
    }
    final entries = rawEntries.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Catalog entries must be objects.');
      }
      return RemoteAssistantCatalogEntry.fromMap(
        Map<String, dynamic>.from(entry),
      );
    }).toList();
    final ids = entries.map((entry) => entry.id).toSet();
    if (ids.length != entries.length) {
      throw const FormatException('Catalog assistant ids must be unique.');
    }
    return RemoteAssistantCatalog(
      schemaVersion: version,
      catalogId: _requiredString(map, 'catalogId'),
      updatedAt: _optionalString(map, 'updatedAt'),
      assistants: entries,
      extensions: _optionalMap(map, 'extensions') ?? const {},
    );
  }
}

Map<String, dynamic> _parseAssistantSource(String source, {String? format}) {
  var effectiveFormat = format;
  var bodyPrompt = <String, dynamic>{};
  var frontMatter = source;
  if (effectiveFormat == kRemoteAssistantMarkdownFormat ||
      (effectiveFormat == null && source.startsWith('---\n'))) {
    final match = RegExp(
      r'^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$',
    ).firstMatch(source);
    if (match == null) {
      throw const FormatException(
          'Markdown assistant needs YAML front matter delimited by --- lines.');
    }
    frontMatter = match.group(1)!;
    bodyPrompt = {'prompt': match.group(2)!.trimRight()};
    effectiveFormat = kRemoteAssistantMarkdownFormat;
  }

  final data = _decodeStructured(frontMatter);
  if (bodyPrompt.isNotEmpty) {
    if (data.containsKey('prompt')) {
      throw const FormatException(
          'Markdown prompt belongs after the front matter.');
    }
    data.addAll(bodyPrompt);
  }
  if (effectiveFormat == 'stroom-json-v1' &&
      !frontMatter.trimLeft().startsWith('{')) {
    throw const FormatException('stroom-json-v1 must be JSON.');
  }
  if (effectiveFormat == 'stroom-yaml-v1' &&
      frontMatter.trimLeft().startsWith('{')) {
    throw const FormatException('stroom-yaml-v1 must be YAML.');
  }
  return data;
}

Map<String, dynamic> _decodeStructured(String source) {
  dynamic value;
  try {
    value = jsonDecode(source);
  } on FormatException {
    try {
      value = loadYaml(source);
    } catch (error) {
      throw FormatException('Invalid Stroom JSON/YAML: $error');
    }
  }
  if (value is! Map)
    throw const FormatException('Expected a JSON/YAML object.');
  return Map<String, dynamic>.from(_normalizeYaml(value) as Map);
}

dynamic _normalizeYaml(dynamic value) {
  if (value is YamlMap || value is Map) {
    return Map<String, dynamic>.fromEntries(
      (value as Map).entries.map(
            (entry) => MapEntry('${entry.key}', _normalizeYaml(entry.value)),
          ),
    );
  }
  if (value is YamlList || value is List) {
    return (value as List).map(_normalizeYaml).toList();
  }
  return value;
}

void _validateSettings(Map<String, dynamic> settings) {
  const allowed = {
    'temperature',
    'enableTemperature',
    'topP',
    'enableTopP',
    'maxTokens',
    'enableMaxTokens',
    'maxToolCalls',
    'enableMaxToolCalls',
    'maxToolOutputChars',
    'enableMaxToolOutputChars',
    'streamOutput',
    'enableWebSearch',
    'frequencyPenalty',
    'enableFrequencyPenalty',
    'presencePenalty',
    'enablePresencePenalty',
    'seed',
    'enableSeed',
    'customParameters',
  };
  _rejectUnknownKeys(settings, allowed, 'settings');
  _rangeNumber(settings, 'temperature', 0, 2);
  _rangeNumber(settings, 'topP', 0, 1);
  _rangeInt(settings, 'maxTokens', 256, 32768);
  _positiveInt(settings, 'maxToolCalls');
  _rangeInt(settings, 'maxToolOutputChars', 100, 100000);
  _rangeNumber(settings, 'frequencyPenalty', -2, 2);
  _rangeNumber(settings, 'presencePenalty', -2, 2);
  if (settings['seed'] != null && settings['seed'] is! int) {
    throw const FormatException('settings.seed must be an integer.');
  }
  for (final key in const [
    'enableTemperature',
    'enableTopP',
    'enableMaxTokens',
    'enableMaxToolCalls',
    'enableMaxToolOutputChars',
    'streamOutput',
    'enableWebSearch',
    'enableFrequencyPenalty',
    'enablePresencePenalty',
    'enableSeed',
  ]) {
    if (settings[key] != null && settings[key] is! bool) {
      throw FormatException('settings.$key must be a boolean.');
    }
  }
  final custom = settings['customParameters'];
  if (custom != null) {
    if (custom is! List) {
      throw const FormatException('settings.customParameters must be a list.');
    }
    for (final item in custom) {
      if (item is! Map) {
        throw const FormatException('Custom parameters must be objects.');
      }
      final map = Map<String, dynamic>.from(item);
      _rejectUnknownKeys(map, {'name', 'type', 'value'}, 'custom parameter');
      _requiredString(map, 'name');
      final type = _requiredString(map, 'type');
      if (!const {'string', 'number', 'boolean', 'json'}.contains(type)) {
        throw FormatException('Unsupported custom parameter type: $type');
      }
      if (!map.containsKey('value')) {
        throw const FormatException('Custom parameter value is required.');
      }
      final value = map['value'];
      final validValue = switch (type) {
        'string' => value is String,
        'number' => value is num,
        'boolean' => value is bool,
        'json' => true,
        _ => false,
      };
      if (!validValue || !isValidRemoteParameterName(map['name'] as String)) {
        throw const FormatException(
            'Invalid custom parameter name or value type.');
      }
    }
  }
}

/// Matches the current assistant editor's dotted custom parameter path rules.
bool isValidRemoteParameterName(String name) {
  if (name.trim().isEmpty) return false;
  return name
      .split('.')
      .every((part) => part.isNotEmpty && part == part.trim());
}

void _rangeNumber(Map<String, dynamic> map, String key, num min, num max) {
  final value = map[key];
  if (value == null) return;
  if (value is! num || value < min || value > max) {
    throw FormatException('$key must be between $min and $max.');
  }
}

void _rangeInt(Map<String, dynamic> map, String key, int min, int max) {
  final value = map[key];
  if (value == null) return;
  if (value is! int || value < min || value > max) {
    throw FormatException('$key must be an integer between $min and $max.');
  }
}

void _positiveInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value != null && (value is! int || value <= 0)) {
    throw FormatException('$key must be a positive integer.');
  }
}

void _rejectUnknownKeys(
  Map<String, dynamic> map,
  Set<String> allowed,
  String context,
) {
  final unknown = map.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw FormatException('Unknown $context field(s): ${unknown.join(', ')}');
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('$key must be an object.');
  return Map<String, dynamic>.from(value);
}

Set<String>? _optionalStringSet(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be a list of strings.');
  }
  return value.cast<String>().toSet();
}
