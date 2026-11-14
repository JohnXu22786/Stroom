import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assistant.dart';
import '../../models/remote_assistant_catalog.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/chat_manager_provider.dart';
import '../../providers/provider_config.dart';
import '../../services/assistant_catalog_service.dart';
import '../../services/assistant_prompt_safety_review.dart';
import '../../services/chat_adapter.dart' show resolveModelRef;
import '../../services/assistant_tool_policy.dart';
import 'assistant_schema_info_dialog.dart';

import '../../widgets/constrained_text.dart';

void showAssistantRemoteSourceDialog(
  BuildContext context,
  WidgetRef ref, {
  String initialUrl = '',
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _AssistantRemoteSourceDialog(ref: ref, initialUrl: initialUrl),
  );
}

class _AssistantRemoteSourceDialog extends StatefulWidget {
  final WidgetRef ref;
  final String initialUrl;

  const _AssistantRemoteSourceDialog({
    required this.ref,
    required this.initialUrl,
  });

  @override
  State<_AssistantRemoteSourceDialog> createState() =>
      _AssistantRemoteSourceDialogState();
}

class _AssistantRemoteSourceDialogState
    extends State<_AssistantRemoteSourceDialog> {
  late final TextEditingController _urlController;
  RemoteAssistantCatalog? _catalog;
  bool _busy = false;
  bool _autoUpdate = false;
  bool _reviewSafety = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    if (widget.initialUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCatalog();
      });
    }
  }

  bool get _isZh => Localizations.localeOf(context).languageCode == 'zh';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _busy = true;
      _error = null;
      _catalog = null;
    });
    final service = AssistantCatalogService();
    try {
      final catalog = await service.fetchCatalog(_urlController.text);
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      service.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importDirectFile() async {
    await _performImport(() async {
      final service = AssistantCatalogService();
      try {
        return await service.fetchDirectAssistant(_urlController.text);
      } finally {
        service.close();
      }
    }, catalogUrl: null);
  }

  Future<void> _importEntry(RemoteAssistantCatalogEntry entry) async {
    final catalogUrl = _urlController.text.trim();
    await _performImport(() async {
      final service = AssistantCatalogService();
      try {
        return await service.fetchCatalogEntry(
          catalogUrl: catalogUrl,
          entry: entry,
        );
      } finally {
        service.close();
      }
    }, catalogUrl: catalogUrl);
  }

  Future<void> _performImport(
    Future<DownloadedRemoteAssistant> Function() download, {
    required String? catalogUrl,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var imported = false;
    try {
      final remote = await download();
      final definition = remote.definition;

      final refs = widget.ref.read(providerEntriesProvider);
      final adapter = widget.ref.read(chatStreamManagerProvider).adapter;
      final models = adapter.availableModels(refs);
      final defaultModel = resolveModelRef(
        models: models,
        modelId: definition.defaultModelId,
        providerName: definition.defaultProviderName,
        displayName: definition.defaultModelName,
      );
      final defaultTools = supportedAssistantToolNames(refs);
      final requestedTools = definition.defaultToolNames;
      if (requestedTools != null && !defaultTools.containsAll(requestedTools)) {
        final unknown = requestedTools.difference(defaultTools).join(', ');
        throw FormatException('Unsupported Stroom tool name(s): $unknown');
      }
      final validRequestedTools = requestedTools;

      if (_reviewSafety) {
        final review = await AssistantPromptSafetyReview.review(
          adapter: adapter,
          entriesState: refs,
          assistantId: definition.id,
          prompt: definition.prompt,
          settings: definition.settings.toMap(),
        );
        if (!review.approved) {
          throw FormatException(
            '${_isZh ? '安全审查未通过' : 'Safety review rejected this assistant'}: ${review.reason}',
          );
        }
      }

      final replacement = Assistant(
        name: definition.name,
        description: definition.description,
        emoji: definition.emoji,
        prompt: definition.prompt,
        settings: definition.settings,
        defaultModelName: defaultModel?.displayName,
        defaultModelId: defaultModel?.modelId,
        defaultProviderName: defaultModel?.providerName,
        defaultToolNames: validRequestedTools,
      );
      final existing = widget.ref.read(assistantProvider).where((assistant) {
        return assistant.remoteAssistantId == definition.id &&
            assistant.remoteCatalogUrl == catalogUrl;
      }).firstOrNull;
      if (existing == null) {
        widget.ref.read(assistantProvider.notifier).createAssistant(
              name: replacement.name,
              description: replacement.description,
              emoji: replacement.emoji,
              prompt: replacement.prompt,
              settings: replacement.settings,
              remoteCatalogUrl: catalogUrl,
              remoteFileUrl: remote.fileUrl,
              remoteAssistantId: definition.id,
              remoteVersion: definition.version,
              remoteFormat: remote.format,
              remoteSha256: remote.sha256,
              remoteUpdatePolicy: _autoUpdate ? 'automatic' : 'manual',
              remoteSecurityReview: _reviewSafety,
              remoteExtensions: definition.extensions,
            );
      } else {
        widget.ref.read(assistantProvider.notifier).updateRemoteAssistant(
              localId: existing.id,
              replacement: replacement,
              remoteVersion: definition.version,
              remoteFileUrl: remote.fileUrl,
              remoteFormat: remote.format,
              remoteSha256: remote.sha256,
              remoteExtensions: definition.extensions,
            );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _busy = false);
      Navigator.of(context).pop();
      imported = true;
      messenger.showSnackBar(
        SnackBar(content: Text(_isZh ? '助手已接入' : 'Assistant added')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted && !imported) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: ConstrainedText(
        _isZh ? '接入远程助手' : 'Connect remote assistants',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText:
                      _isZh ? '目录清单或助手文件 URL' : 'Catalog or assistant file URL',
                  hintText: 'https://…/catalog.json',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _isZh ? '参数格式说明' : 'Parameter reference',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showAssistantSchemaInfoDialog(
                      context,
                      supportedToolNames: supportedAssistantToolNames(
                        widget.ref.read(providerEntriesProvider),
                      ),
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {
                  _catalog = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_isZh ? '自动更新' : 'Automatic updates'),
                subtitle: Text(
                  _isZh
                      ? '关闭时进入该助手的对话选择页再提醒更新。'
                      : 'When off, check and notify on the assistant topic page.',
                ),
                value: _autoUpdate,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _autoUpdate = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _isZh
                      ? '使用内置安全审查 agent'
                      : 'Review with the built-in safety agent',
                ),
                subtitle: Text(
                  _isZh
                      ? '首次接入及每次更新前审查提示词；会发送给当前配置的首个 LLM，可能产生 API 用量。'
                      : 'Reviews imports and updates using the first configured LLM; this may incur API usage.',
                ),
                value: _reviewSafety,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _reviewSafety = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colorScheme.error)),
              ],
              if (_catalog != null) ...[
                const Divider(height: 24),
                Text(
                  '${_isZh ? '目录' : 'Catalog'}: ${_catalog!.catalogId}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final entry in _catalog!.assistants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      entry.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(entry.name),
                    subtitle: Text('${entry.description}\n${entry.version}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: _isZh ? '接入' : 'Add',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _busy ? null : () => _importEntry(entry),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: ConstrainedText(
            _isZh ? '关闭' : 'Close',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: _busy || _urlController.text.trim().isEmpty
              ? null
              : _importDirectFile,
          child: ConstrainedText(
            _isZh ? '直接导入文件' : 'Import file',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton.icon(
          onPressed:
              _busy || _urlController.text.trim().isEmpty ? null : _loadCatalog,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: ConstrainedText(
            _isZh ? '读取目录' : 'Load catalog',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
