import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

import '../models/tool_call.dart';
import '../providers/provider_config.dart';
import '../services/http_tool_service.dart';

class HttpToolConfigDialog extends StatefulWidget {
  final ProviderConfigItem config;
  final ToolDefinition? definition;

  const HttpToolConfigDialog({required this.config, required this.definition});

  @override
  State<HttpToolConfigDialog> createState() => _HttpToolConfigDialogState();
}

class _HttpToolConfigDialogState extends State<HttpToolConfigDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _urlController;
  bool _obscureApiKey = true;
  String? _urlError;

  Map<String, dynamic> get _typeConfig => widget.config.models.isNotEmpty
      ? widget.config.models[0].typeConfig
      : const <String, dynamic>{};

  bool get _allowsCustomUrl => widget.config.providerName == 'Searxng';

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: HttpToolService.extractHttpToolApiKey(
        widget.config.providerName,
        _typeConfig,
      ),
    );
    _urlController = TextEditingController(
      text: _typeConfig['url'] as String? ?? widget.config.host,
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  ProviderConfigItem _updatedConfig() {
    final updated = widget.config.copy();
    if (updated.models.isEmpty) return updated;

    final typeConfig = Map<String, dynamic>.from(updated.models[0].typeConfig);
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      typeConfig.remove('apiKey');
    } else {
      typeConfig['apiKey'] = apiKey;
    }
    _updateCredentialHeaders(typeConfig, apiKey);
    if (_allowsCustomUrl) {
      final url = _urlController.text.trim();
      typeConfig['url'] = url;
      updated.host = url;
    }
    updated.models[0].typeConfig = typeConfig;
    return updated;
  }

  void _updateCredentialHeaders(
    Map<String, dynamic> typeConfig,
    String apiKey,
  ) {
    final credentialHeaderNames =
        HttpToolService.credentialHeaderNamesForProvider(
      widget.config.providerName,
    );
    final rawHeaders = typeConfig['headers'];
    if (rawHeaders is! Map) return;

    final headers = Map<String, dynamic>.from(rawHeaders);
    for (final key in headers.keys.toList()) {
      if (!credentialHeaderNames.contains(key.toString().toLowerCase())) {
        continue;
      }

      headers[key] = key.toString().toLowerCase() == 'authorization'
          ? (apiKey.isEmpty ? 'Bearer ' : 'Bearer $apiKey')
          : apiKey;
    }
    typeConfig['headers'] = headers;
  }

  void _save() {
    if (_allowsCustomUrl) {
      final url = Uri.tryParse(_urlController.text.trim());
      if (url == null ||
          (url.scheme != 'http' && url.scheme != 'https') ||
          !url.hasAuthority ||
          url.host.isEmpty) {
        setState(
          () => _urlError = AppLocalizations.of(context)!.toolInvalidHttpUrl,
        );
        return;
      }
    }
    Navigator.pop(context, _updatedConfig());
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    return AlertDialog(
      title: Text(widget.config.providerName),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.toolHttpSearchType),
              if (definition != null) ...[
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.toolInterface(definition.name),
                ),
                const SizedBox(height: 4),
                Text(definition.description),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.toolParameterDefinitions,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  const JsonEncoder.withIndent('  ')
                      .convert(definition.parameters),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                readOnly: !_allowsCustomUrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.toolHttpAddress,
                  border: const OutlineInputBorder(),
                  errorText: _urlError,
                ),
                onChanged: (_) {
                  if (_urlError != null) setState(() => _urlError = null);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.mcpApiKey,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscureApiKey
                        ? AppLocalizations.of(context)!.mcpShowKey
                        : AppLocalizations.of(context)!.mcpHideKey,
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.batchDlgCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(AppLocalizations.of(context)!.mermaidSaveButton),
        ),
      ],
    );
  }
}

class BuiltinToolDetailsDialog extends StatelessWidget {
  final ToolDefinition definition;

  const BuiltinToolDetailsDialog({required this.definition});

  static const _englishDescriptions = <String, Map<String, String>>{
    'todowrite': {
      'description': 'Create, read, and manage a to-do list. Passing todos replaces the full list; omitting it reads the current list. Each item has content, status (pending, in_progress, completed, or cancelled), and priority (high, medium, or low). Use it to manage complex tasks with three or more steps.',
      'properties.todos.description': 'Complete replacement of the to-do list. Omit this parameter to read the current list.',
      'properties.todos.items.properties.content.description':
          'Task description.',
      'properties.todos.items.properties.status.description':
          'Task status: pending, in_progress, completed, or cancelled.',
      'properties.todos.items.properties.priority.description':
          'Priority: high, medium, or low.',
    },
    'web_search': {
      'description': 'Search the web for current information. Choose Google, Bing, or Baidu with the source parameter (Google is the default). If the preferred engine is unavailable or returns no usable results, the tool tries other engines automatically. No API key is required. Each result includes a title, link, and summary.',
      'properties.query.description': 'Search terms.',
      'properties.source.description': 'Preferred search engine: google, bing, or baidu. The tool switches automatically if it is unavailable.',
      'properties.count.description':
          'Number of results to return (maximum 10).',
    },
  };

  static const _chineseDescriptions = <String, Map<String, String>>{
    'todowrite': {
      'description': '创建、读取并管理待办事项列表。传入 todos（完整的待办事项列表）时覆盖写入，系统将替换所有现有事项；省略 todos 参数时读取当前待办事项列表。各事项包含：content（任务描述）、status（状态：pending/in_progress/completed/cancelled）、priority（优先级：high/medium/low）。适用于 3 个以上步骤的复杂任务管理。',
      'properties.todos.description': '待办事项列表（全量替换）。省略该参数时读取当前待办列表。',
      'properties.todos.items.properties.content.description': '任务描述',
      'properties.todos.items.properties.status.description':
          '任务状态：pending（待处理）、in_progress（进行中）、completed（已完成）、cancelled（已取消）',
      'properties.todos.items.properties.priority.description':
          '优先级：high（高）、medium（中）、low（低）',
    },
    'web_search': {
      'description': '通过网络搜索获取实时信息。支持 Google、Bing、百度三个搜索引擎，通过 source 参数选择首选引擎（默认 google）；首选引擎不可用或未返回可解析结果时会自动尝试其他引擎。无需 API Key，免费使用。每个结果包含标题、链接和内容摘要。',
      'properties.query.description': '搜索关键词',
      'properties.source.description':
          '首选搜索引擎：google（谷歌）、bing（必应）、baidu（百度）；不可用时会自动切换',
      'properties.count.description': '返回结果数量（最大 10）',
    },
  };

  Map<String, dynamic> _localizedParameters(Locale locale) {
    final translations = locale.languageCode == 'en'
        ? _englishDescriptions[definition.name]
        : locale.languageCode == 'zh'
        ? _chineseDescriptions[definition.name]
        : null;
    if (translations == null) return definition.parameters;

    dynamic localize(dynamic value, String path) {
      if (value is Map) {
        return <String, dynamic>{
          for (final entry in value.entries)
            entry.key as String: entry.key == 'description'
                ? translations[path.isEmpty
                          ? 'description'
                          : '$path.description'] ??
                      entry.value
                : localize(
                    entry.value,
                    path.isEmpty ? entry.key as String : '$path.${entry.key}',
                  ),
        };
      }
      if (value is List) {
        return value.map((item) => localize(item, path)).toList();
      }
      return value;
    }

    return localize(definition.parameters, '') as Map<String, dynamic>;
  }

  String _localizedDescription(Locale locale) {
    final translations = locale.languageCode == 'en'
        ? _englishDescriptions[definition.name]
        : locale.languageCode == 'zh'
        ? _chineseDescriptions[definition.name]
        : null;
    return translations?['description'] ?? definition.description;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AlertDialog(
      title: Text(definition.name),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.toolBuiltinType),
              const SizedBox(height: 8),
              Text(_localizedDescription(locale)),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.toolParameterDefinitions,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SelectableText(
                const JsonEncoder.withIndent('  ')
                    .convert(_localizedParameters(locale)),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.toolBuiltinEnableHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.mathClose),
        ),
      ],
    );
  }
}
