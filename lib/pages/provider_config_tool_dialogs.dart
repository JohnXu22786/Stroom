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
                  style: Theme.of(context).textTheme.bodySmall
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

  @override
  Widget build(BuildContext context) {
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
              Text(definition.description),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.toolParameterDefinitions,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SelectableText(
                const JsonEncoder.withIndent('  ')
                    .convert(definition.parameters),
                style: Theme.of(context).textTheme.bodySmall
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
