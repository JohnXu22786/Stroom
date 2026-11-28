import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp.dart';
import '../providers/provider_config.dart';
import 'mcp_server_config_shared.dart';

import '../widgets/constrained_text.dart';

Future<bool?> showMcpServerConfigDialog({
  required BuildContext context,
  required String entryId,
  required int configIndex,
  String? groupId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _McpServerConfigDialog(
      entryId: entryId,
      configIndex: configIndex,
      groupId: groupId,
    ),
  );
}

/// MCP 服务器配置对话框，用于添加或编辑服务器连接信息。
class _McpServerConfigDialog extends ConsumerStatefulWidget {
  final String entryId;
  final int configIndex; // -1 for new config
  final String? groupId;

  const _McpServerConfigDialog({
    super.key,
    required this.entryId,
    required this.configIndex,
    this.groupId,
  });

  @override
  ConsumerState<_McpServerConfigDialog> createState() =>
      _McpServerConfigDialogState();
}

class _McpServerConfigDialogState
    extends ConsumerState<_McpServerConfigDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _commandController = TextEditingController();
  final _argsController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _nameHintStates = MaterialStatesController();
  final _commandHintStates = MaterialStatesController();
  final _urlHintStates = MaterialStatesController();
  final _apiKeyHintStates = MaterialStatesController();
  final _descriptionHintStates = MaterialStatesController();

  McpTransportType _transportType = McpTransportType.sse;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _hasUnsavedChanges = false;
  bool _obscureApiKey = true;

  String _originalName = '';
  String _originalDescription = '';
  McpTransportType _originalTransport = McpTransportType.sse;
  String _originalCommand = '';
  String _originalArgs = '';
  String _originalUrl = '';
  String _originalApiKey = '';
  bool _isVendor = false;

  bool get _isExistingConfig => widget.configIndex >= 0;

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
    if (_isExistingConfig) {
      _loadExistingConfig();
      _isEditMode = false;
    } else {
      _isEditMode = true;
    }
  }

  void _loadExistingConfig() {
    final entry = _entry;
    if (entry == null) return;
    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length) {
      return;
    }
    final config = entry.configs[widget.configIndex];
    final mcpConfig =
        config.models.isNotEmpty ? config.models[0].typeConfig : null;
    final serverConfig = McpServerConfig.fromProviderConfig(
      providerName: config.providerName,
      typeConfig: mcpConfig,
    );

    if (serverConfig != null) {
      _nameController.text = serverConfig.name;
      _transportType = serverConfig.transportType;
      _commandController.text = serverConfig.command ?? '';
      _argsController.text = (serverConfig.args ?? []).join(', ');
      _urlController.text = serverConfig.url ?? '';
      _isVendor = serverConfig.isVendor;

      // Load description from typeConfig
      final desc = mcpConfig?['description'] as String? ?? '';
      _descriptionController.text = desc;

      // Extract API key from apiKey field, env, or headers
      // （'Bearer ' 占位符视为未设置，不自动填入假 Key）
      _apiKeyController.text = _extractApiKeyFromEnvOrHeaders(serverConfig);

      _originalName = serverConfig.name;
      _originalDescription = _descriptionController.text;
      _originalTransport = serverConfig.transportType;
      _originalCommand = _commandController.text;
      _originalArgs = _argsController.text;
      _originalUrl = _urlController.text;
      _originalApiKey = _apiKeyController.text;
    } else {
      // Legacy: use providerName and host
      _nameController.text = config.providerName;
      _urlController.text = config.host;
      _originalName = config.providerName;
      _originalUrl = config.host;
    }
  }

  /// Extract API key from apiKey field, env, or headers.
  /// This handles legacy configs and provides a better editing experience.
  /// Placeholders ('Bearer ' 前缀等) are treated as unset so the field is
  /// never auto-filled with a fake key.
  String _extractApiKeyFromEnvOrHeaders(McpServerConfig config) {
    final explicitApiKey = McpServerConfig.extractApiKeyFromTypeConfig({
      if (config.apiKey != null) 'apiKey': config.apiKey,
    });
    if (explicitApiKey.isNotEmpty) return explicitApiKey;

    for (final entry in config.headers.entries) {
      if (!_isApiKeySourceFieldName(entry.key)) continue;
      final apiKey = _extractApiKeyFromFieldValue(entry.value);
      if (apiKey.isNotEmpty) return apiKey;
    }

    for (final entry in config.env.entries) {
      if (!_isApiKeySourceFieldName(entry.key)) continue;
      final apiKey = _extractApiKeyFromFieldValue(entry.value);
      if (apiKey.isNotEmpty) return apiKey;
    }
    return '';
  }

  String _extractApiKeyFromFieldValue(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty || trimmedValue.toLowerCase() == 'bearer') {
      return '';
    }
    final bearerMatch = RegExp(
      r'^bearer\s+',
      caseSensitive: false,
    ).firstMatch(trimmedValue);
    if (bearerMatch == null) return trimmedValue;

    final key = trimmedValue.substring(bearerMatch.end).trim();
    return key.toLowerCase() == 'bearer' ? '' : key;
  }

  bool _isApiKeySourceFieldName(String name) {
    final separatedName = name.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );
    final nameParts = separatedName
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.isNotEmpty);
    final hasToken = nameParts.contains('token');
    const unrelatedTokenNameParts = {
      'refresh',
      'session',
      'csrf',
      'xsrf',
      'id',
    };
    // Custom MCPs often use provider-specific names such as OPENAI_TOKEN.
    final isApiToken =
        hasToken && !nameParts.any(unrelatedTokenNameParts.contains);

    return nameParts.contains('authorization') ||
        nameParts.contains('apikey') ||
        (nameParts.contains('api') &&
            (nameParts.contains('key') || nameParts.contains('secret'))) ||
        isApiToken;
  }

  String _apiKeyValueForSource(
    String fieldName,
    String originalValue,
    String newApiKey,
  ) {
    final trimmedValue = originalValue.trim();
    final bearerMatch = RegExp(
      r'^bearer\s+',
      caseSensitive: false,
    ).firstMatch(trimmedValue);
    if (bearerMatch != null) {
      return '${trimmedValue.substring(0, bearerMatch.end)}$newApiKey';
    }

    if (fieldName.toLowerCase() == 'authorization') {
      return 'Bearer $newApiKey';
    }
    return newApiKey;
  }

  bool _isApiKeyPlaceholder(String fieldName, String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ||
        trimmedValue.toLowerCase() == 'bearer' ||
        trimmedValue.toLowerCase() == fieldName.trim().toLowerCase();
  }

  void _syncExistingApiKey(Map<String, String> values, String? newApiKey) {
    if (_originalApiKey.isEmpty || newApiKey == _originalApiKey) return;

    for (final entry in values.entries.toList()) {
      if (!_isApiKeySourceFieldName(entry.key)) continue;

      if (newApiKey == null) {
        values.remove(entry.key);
      } else {
        values[entry.key] = _apiKeyValueForSource(
          entry.key,
          entry.value,
          newApiKey,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _nameHintStates.dispose();
    _commandHintStates.dispose();
    _urlHintStates.dispose();
    _apiKeyHintStates.dispose();
    _descriptionHintStates.dispose();
    super.dispose();
  }

  void _checkUnsavedChanges() {
    // Vendor configs: only track API key changes
    if (_isVendor) {
      final changed = _apiKeyController.text != _originalApiKey;
      setState(() => _hasUnsavedChanges = changed);
      return;
    }

    final changed = _nameController.text != _originalName ||
        _descriptionController.text != _originalDescription ||
        _transportType != _originalTransport ||
        _commandController.text != _originalCommand ||
        _argsController.text != _originalArgs ||
        _urlController.text != _originalUrl ||
        _apiKeyController.text != _originalApiKey;
    setState(() => _hasUnsavedChanges = changed);
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _hasUnsavedChanges = false;
      _obscureApiKey = true;
    });
  }

  void _discardChanges() {
    _nameController.text = _originalName;
    _descriptionController.text = _originalDescription;
    _transportType = _originalTransport;
    _commandController.text = _originalCommand;
    _argsController.text = _originalArgs;
    _urlController.text = _originalUrl;
    _apiKeyController.text = _originalApiKey;
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
      _obscureApiKey = true;
    });
    if (!_isExistingConfig) {
      Navigator.pop(context);
    }
  }

  void _exitEditMode() {
    _originalName = _nameController.text;
    _originalDescription = _descriptionController.text;
    _originalTransport = _transportType;
    _originalCommand = _commandController.text;
    _originalArgs = _argsController.text;
    _originalUrl = _urlController.text;
    _originalApiKey = _apiKeyController.text;
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
      _obscureApiKey = true;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.mcpServerNameRequired),
        ),
      );
      return;
    }

    // Validate transport-specific fields
    if (_transportType == McpTransportType.stdio &&
        _commandController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.mcpStdioCommandRequired),
        ),
      );
      return;
    }
    if (_transportType == McpTransportType.sse &&
        _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.mcpSseUrlRequired),
        ),
      );
      return;
    }

    final entry = _entry;
    if (entry == null) return;

    setState(() => _isSaving = true);

    // Build MCP server config
    final argsStr = _argsController.text.trim();
    final args = argsStr.isNotEmpty
        ? argsStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final apiKey = _apiKeyController.text.trim();
    final effectiveApiKey = apiKey.isNotEmpty ? apiKey : null;

    McpServerConfig serverConfig;
    if (_transportType == McpTransportType.stdio) {
      // For stdio: merge apiKey into env vars
      // Load existing env from the original config if editing
      var effectiveEnv = <String, String>{
        'PATH': '/usr/local/bin:/usr/bin:/bin',
      };
      if (_isExistingConfig) {
        final entry = _entry;
        if (entry != null && widget.configIndex < entry.configs.length) {
          final existingConfig = entry.configs[widget.configIndex];
          if (existingConfig.models.isNotEmpty) {
            final tc = existingConfig.models[0].typeConfig;
            final envRaw = tc['env'];
            if (envRaw is Map) {
              effectiveEnv = envRaw.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
            }
          }
        }
      }
      _syncExistingApiKey(effectiveEnv, effectiveApiKey);
      // Merge apiKey: replace empty placeholder values in env
      if (effectiveApiKey != null) {
        for (final entry in effectiveEnv.entries.toList()) {
          if (_isApiKeySourceFieldName(entry.key) &&
              _isApiKeyPlaceholder(entry.key, entry.value)) {
            effectiveEnv[entry.key] = effectiveApiKey;
          }
        }
      }
      serverConfig = McpServerConfig.stdio(
        name: name,
        command: _commandController.text.trim(),
        args: args,
        env: effectiveEnv,
        apiKey: effectiveApiKey,
        isVendor: _isVendor,
      );
    } else {
      // For sse: merge apiKey into headers
      var effectiveHeaders = <String, String>{};
      var effectiveEnv = <String, String>{};
      // Load existing headers/env from original config if editing
      if (_isExistingConfig) {
        final entry = _entry;
        if (entry != null && widget.configIndex < entry.configs.length) {
          final existingConfig = entry.configs[widget.configIndex];
          if (existingConfig.models.isNotEmpty) {
            final tc = existingConfig.models[0].typeConfig;
            final headersRaw = tc['headers'];
            if (headersRaw is Map) {
              effectiveHeaders = headersRaw.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
            }
            final envRaw = tc['env'];
            if (envRaw is Map) {
              effectiveEnv = envRaw.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
            }
          }
        }
      }
      _syncExistingApiKey(effectiveHeaders, effectiveApiKey);
      _syncExistingApiKey(effectiveEnv, effectiveApiKey);
      // Merge apiKey into headers: replace placeholder values
      if (effectiveApiKey != null) {
        for (final entry in effectiveHeaders.entries.toList()) {
          if (_isApiKeySourceFieldName(entry.key) &&
              _isApiKeyPlaceholder(entry.key, entry.value)) {
            effectiveHeaders[entry.key] = _apiKeyValueForSource(
              entry.key,
              entry.value,
              effectiveApiKey,
            );
          }
        }
      }
      serverConfig = McpServerConfig.sse(
        name: name,
        url: _urlController.text.trim(),
        env: effectiveEnv,
        headers: effectiveHeaders,
        apiKey: effectiveApiKey,
        isVendor: _isVendor,
      );
    }

    // Add description to typeConfig
    final typeConfigMap = serverConfig.toMap();
    final description = _descriptionController.text.trim();
    if (description.isNotEmpty) {
      typeConfigMap['description'] = description;
    }
    final savedApiKey = _extractApiKeyFromEnvOrHeaders(serverConfig);

    // Store in ProviderConfigItem with typeConfig in models[0]
    final modelConfig = ModelConfig(
      name: name,
      modelId: _transportType.value,
      typeConfig: typeConfigMap,
    );

    var configs = entry.configs.map((c) => c.copy()).toList();
    final existingConfig = _isExistingConfig &&
            widget.configIndex >= 0 &&
            widget.configIndex < configs.length
        ? configs[widget.configIndex]
        : null;
    final targetGroupId = existingConfig?.groupId ??
        widget.groupId ??
        defaultMcpGroupIdForProvider(name);
    final parentGroupEnabled = ref
            .read(providerEntriesProvider)
            .mcpGroups
            .where((group) => group.id == targetGroupId)
            .firstOrNull
            ?.enabled ??
        true;
    final newConfig = ProviderConfigItem(
      id: existingConfig?.id,
      providerName: name,
      groupId: targetGroupId,
      host: _transportType == McpTransportType.sse
          ? _urlController.text.trim()
          : '',
      key: '',
      models: [modelConfig],
      enabled: existingConfig?.enabled ?? (entry.enabled && parentGroupEnabled),
    );

    if (existingConfig != null) {
      final existingTypeConfig = existingConfig.models.isNotEmpty
          ? existingConfig.models[0].typeConfig
          : existingConfig.typeConfig;
      final connectivityTest = existingTypeConfig['connectivityTest'];
      if (connectivityTest is Map) {
        newConfig.models[0].typeConfig['connectivityTest'] =
            Map<String, dynamic>.from(connectivityTest);
      }
      configs[widget.configIndex] = newConfig;
    } else {
      configs.insert(0, newConfig);
    }

    final updated = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: configs,
      // 保留 MCP 总开关状态：编辑服务器配置不应悄悄重置总开关。
      enabled: entry.enabled,
    );

    try {
      await ref
          .read(providerEntriesProvider.notifier)
          .update(entry.id, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatSaveFailed('$error')),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (_isExistingConfig) {
      _nameController.text = name;
      _descriptionController.text = description;
      _commandController.text = _transportType == McpTransportType.stdio
          ? _commandController.text.trim()
          : '';
      _argsController.text =
          _transportType == McpTransportType.stdio ? args.join(', ') : '';
      _urlController.text = _transportType == McpTransportType.sse
          ? _urlController.text.trim()
          : '';
      _apiKeyController.text = savedApiKey;
      _exitEditMode();
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionWidths = _measureAppBarActionWidths();
    final appBarActionSpace = _appBarActionSpace;
    final hasActions = actionWidths.normalWidth > 0;
    final compactAppBar = hasActions &&
        actionWidths.normalWidth > appBarActionSpace &&
        actionWidths.condensedWidth > appBarActionSpace &&
        actionWidths.minimalWidth > appBarActionSpace;
    final condensedAppBarActions = hasActions &&
        actionWidths.normalWidth > appBarActionSpace &&
        actionWidths.condensedWidth <= appBarActionSpace;
    final minimalPaddingAppBarActions = hasActions &&
        actionWidths.normalWidth > appBarActionSpace &&
        actionWidths.condensedWidth > appBarActionSpace &&
        actionWidths.minimalWidth <= appBarActionSpace;
    final title = _isExistingConfig
        ? (_nameController.text.isNotEmpty
            ? _nameController.text
            : AppLocalizations.of(context)!.mcpEditServerTitle)
        : AppLocalizations.of(context)!.mcpCreateServerTitle;
    final screenSize = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final desiredDialogHeight = screenSize.height * 0.85;
    final keyboardVisible = viewInsets.vertical > 0;
    final dialogVerticalInsets = keyboardVisible ? 24.0 : 48.0;
    final availableDialogHeight =
        (screenSize.height - viewInsets.vertical - dialogVerticalInsets)
            .clamp(0.0, double.infinity)
            .toDouble();
    final dialogHeight = desiredDialogHeight < availableDialogHeight
        ? desiredDialogHeight
        : availableDialogHeight;
    final compactAppBarHeight = kToolbarHeight + _compactAppBarActionsHeight;
    final tallCompactAppBar = compactAppBarHeight > kToolbarHeight + 120;
    final scrollWholeDialog = compactAppBar &&
        ((screenSize.height <= 480 && tallCompactAppBar) ||
            compactAppBarHeight + 120 > desiredDialogHeight);
    var compactActionsViewportHeight = _compactAppBarActionsHeight;
    if (keyboardVisible && !scrollWholeDialog) {
      final availableActionHeight =
          (dialogHeight - kToolbarHeight - 140).clamp(0.0, double.infinity);
      if (availableActionHeight < compactActionsViewportHeight) {
        compactActionsViewportHeight = availableActionHeight;
      }
    }
    final scrollCompactActions =
        compactActionsViewportHeight < _compactAppBarActionsHeight;
    return PopScope(
      canPop: !_isEditMode || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: ConstrainedText(
              AppLocalizations.of(context)!.mcpUnsavedChangesTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            content: Text(
              AppLocalizations.of(context)!.mcpUnsavedChangesConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: ConstrainedText(
                  AppLocalizations.of(context)!.batchDlgCancel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: ConstrainedText(
                  AppLocalizations.of(context)!.taskFlowUiDiscard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        if (shouldDiscard == true) {
          if (!context.mounted) return;
          setState(() {
            _isEditMode = false;
            _hasUnsavedChanges = false;
          });
          Navigator.pop(context);
        }
      },
      child: Dialog(
        insetPadding: EdgeInsets.only(
          left: 24,
          top: 24,
          right: 24,
          bottom: keyboardVisible ? 0 : 24,
        ),
        child: _McpDialogContentScroller(
          width: 560,
          viewportHeight: dialogHeight,
          scroll: scrollWholeDialog,
          child: Scaffold(
            appBar: AppBar(
              primary: !scrollWholeDialog,
              title: ConstrainedText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: compactAppBar
                  ? const []
                  : _buildAppBarActions(
                      horizontalPadding: condensedAppBarActions
                          ? 8
                          : minimalPaddingAppBarActions
                              ? 0
                              : null,
                    ),
              bottom: compactAppBar
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(
                        compactActionsViewportHeight,
                      ),
                      child: SizedBox(
                        height: compactActionsViewportHeight,
                        child: scrollCompactActions
                            ? SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _buildCompactAppBarActions(),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildCompactAppBarActions(),
                              ),
                      ),
                    )
                  : null,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Transport type
                SectionHeader(
                  title: AppLocalizations.of(context)!.mcpTransportType,
                ),
                const SizedBox(height: 8),
                if (_isEditMode && !_isVendor)
                  _buildTransportSelector()
                else
                  _buildReadOnlyTransport(),

                const SizedBox(height: 16),

                // Server name
                SectionHeader(
                  title: AppLocalizations.of(context)!.mcpServerName,
                ),
                const SizedBox(height: 8),
                if (_isEditMode && !_isVendor)
                  Semantics(
                    hint: AppLocalizations.of(context)!.mcpServerNameHint,
                    child: TextField(
                      controller: _nameController,
                      statesController: _nameHintStates,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hint: ExcludeSemantics(
                          child: ConstrainedInputHint(
                            AppLocalizations.of(context)!.mcpServerNameHint,
                            statesController: _nameHintStates,
                          ),
                        ),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label, color: Colors.teal),
                      ),
                      onChanged: (_) => _checkUnsavedChanges(),
                    ),
                  )
                else
                  ReadOnlyField(
                    icon: Icons.label,
                    iconColor: Colors.teal,
                    label: AppLocalizations.of(context)!.batchDlgSortName,
                    value: _nameController.text,
                  ),

                const SizedBox(height: 16),

                // Transport-specific fields
                if (_transportType == McpTransportType.stdio) ...[
                  SectionHeader(
                    title: AppLocalizations.of(context)!.mcpCommand,
                  ),
                  const SizedBox(height: 8),
                  if (_isEditMode && !_isVendor)
                    Semantics(
                      hint: AppLocalizations.of(context)!.mcpCommandExample,
                      child: TextField(
                        controller: _commandController,
                        statesController: _commandHintStates,
                        enabled: !_isSaving,
                        decoration: InputDecoration(
                          hint: ExcludeSemantics(
                            child: ConstrainedInputHint(
                              AppLocalizations.of(context)!.mcpCommandExample,
                              statesController: _commandHintStates,
                            ),
                          ),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.terminal,
                            color: Colors.orange,
                          ),
                        ),
                        onChanged: (_) => _checkUnsavedChanges(),
                      ),
                    )
                  else
                    ReadOnlyField(
                      icon: Icons.terminal,
                      iconColor: Colors.orange,
                      label: AppLocalizations.of(context)!.mcpCommand,
                      value: _commandController.text,
                    ),
                  const SizedBox(height: 12),
                  SectionHeader(
                    title: AppLocalizations.of(context)!.mcpArguments,
                  ),
                  const SizedBox(height: 8),
                  if (_isEditMode && !_isVendor)
                    TextField(
                      controller: _argsController,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        helper: Text(
                          AppLocalizations.of(context)!.mcpArgumentsHint,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.list, color: Colors.purple),
                      ),
                      onChanged: (_) => _checkUnsavedChanges(),
                    )
                  else
                    ReadOnlyField(
                      icon: Icons.list,
                      iconColor: Colors.purple,
                      label: AppLocalizations.of(context)!.mcpArguments,
                      value: _argsController.text,
                    ),
                ] else ...[
                  SectionHeader(
                    title: AppLocalizations.of(context)!.mcpSseUrlLabel,
                  ),
                  const SizedBox(height: 8),
                  if (_isEditMode && !_isVendor)
                    Semantics(
                      hint: AppLocalizations.of(context)!.mcpSseUrlExample,
                      child: TextField(
                        controller: _urlController,
                        statesController: _urlHintStates,
                        enabled: !_isSaving,
                        decoration: InputDecoration(
                          hint: ExcludeSemantics(
                            child: ConstrainedInputHint(
                              AppLocalizations.of(context)!.mcpSseUrlExample,
                              statesController: _urlHintStates,
                            ),
                          ),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link, color: Colors.blue),
                        ),
                        onChanged: (_) => _checkUnsavedChanges(),
                      ),
                    )
                  else
                    ReadOnlyField(
                      icon: Icons.link,
                      iconColor: Colors.blue,
                      label: AppLocalizations.of(context)!.mcpUrlLabel,
                      value: _urlController.text,
                    ),
                ],

                const SizedBox(height: 16),

                // API Key (for built-in and regular configs)
                SectionHeader(title: AppLocalizations.of(context)!.mcpApiKey),
                const SizedBox(height: 8),
                if (_isEditMode)
                  Semantics(
                    hint: AppLocalizations.of(context)!.mcpApiKeyHint,
                    child: TextField(
                      controller: _apiKeyController,
                      statesController: _apiKeyHintStates,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hint: ExcludeSemantics(
                          child: ConstrainedInputHint(
                            AppLocalizations.of(context)!.mcpApiKeyHint,
                            statesController: _apiKeyHintStates,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(
                          Icons.vpn_key,
                          color: Colors.amber,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          tooltip: _obscureApiKey
                              ? AppLocalizations.of(context)!.mcpShowKey
                              : AppLocalizations.of(context)!.mcpHideKey,
                          onPressed: _isSaving
                              ? null
                              : () => setState(
                                    () => _obscureApiKey = !_obscureApiKey,
                                  ),
                        ),
                      ),
                      obscureText: _obscureApiKey,
                      onChanged: (_) => _checkUnsavedChanges(),
                    ),
                  )
                else
                  ReadOnlyField(
                    icon: Icons.vpn_key,
                    iconColor: Colors.amber,
                    label: AppLocalizations.of(context)!.mcpApiKey,
                    value: _apiKeyController.text.isNotEmpty ? '••••••••' : '',
                  ),

                const SizedBox(height: 16),

                // Description
                SectionHeader(
                  title: AppLocalizations.of(context)!
                      .builtInPromptDescriptionHeading,
                ),
                const SizedBox(height: 8),
                if (_isEditMode && !_isVendor)
                  Semantics(
                    hint: AppLocalizations.of(context)!.mcpDescriptionHint,
                    child: TextField(
                      controller: _descriptionController,
                      statesController: _descriptionHintStates,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hint: ExcludeSemantics(
                          child: ConstrainedInputHint(
                            AppLocalizations.of(context)!.mcpDescriptionHint,
                            statesController: _descriptionHintStates,
                            maxLines: 2,
                          ),
                        ),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description, color: Colors.teal),
                      ),
                      maxLines: 2,
                      minLines: 1,
                      onChanged: (_) => _checkUnsavedChanges(),
                    ),
                  )
                else
                  ReadOnlyField(
                    icon: Icons.description,
                    iconColor: Colors.teal,
                    label: AppLocalizations.of(context)!
                        .builtInPromptDescriptionHeading,
                    value: _descriptionController.text,
                  ),

                const SizedBox(height: 16),

                // Description
                Card(
                  color: cs.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _transportType == McpTransportType.stdio
                                ? AppLocalizations.of(context)!
                                    .mcpStdioDescription
                                : AppLocalizations.of(context)!
                                    .mcpSseDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTransportOption(
            McpTransportType.stdio,
            Icons.desktop_windows,
            AppLocalizations.of(context)!.mcpLocalStdio,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTransportOption(
            McpTransportType.sse,
            Icons.cloud,
            AppLocalizations.of(context)!.mcpRemoteSse,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportOption(
    McpTransportType type,
    IconData icon,
    String label,
  ) {
    final selected = _transportType == type;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                _transportType = type;
                _checkUnsavedChanges();
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyTransport() {
    final cs = Theme.of(context).colorScheme;
    final icon = _transportType == McpTransportType.stdio
        ? Icons.desktop_windows
        : Icons.cloud;
    final label = _transportType == McpTransportType.stdio
        ? AppLocalizations.of(context)!.mcpLocalStdio
        : AppLocalizations.of(context)!.mcpRemoteSse;
    return ReadOnlyField(
      icon: icon,
      iconColor: cs.primary,
      label: AppLocalizations.of(context)!.mcpTransportType,
      value: label,
    );
  }

  double get _compactAppBarActionsHeight {
    if (_isEditMode) {
      final saveLabel = _isSaving
          ? AppLocalizations.of(context)!.mcpSaving
          : AppLocalizations.of(context)!.mermaidSaveButton;
      return _compactActionHeight(saveLabel, iconHeight: _isSaving ? 16 : 20) +
          _compactActionHeight(
            AppLocalizations.of(context)!.taskFlowUiDiscard,
            iconHeight: 20,
          );
    }
    if (_isExistingConfig) {
      return _compactActionHeight(
        AppLocalizations.of(context)!.imagePreviewEdit,
        iconHeight: 20,
      );
    }
    return 0;
  }

  double _compactActionHeight(String label, {required double iconHeight}) {
    final button = TextButton(
      onPressed: null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
      ),
      child: const SizedBox.shrink(),
    );
    final labelStyle = button.style?.textStyle?.resolve(const {}) ??
        button.themeStyleOf(context)?.textStyle?.resolve(const {}) ??
        button.defaultStyleOf(context).textStyle?.resolve(const {}) ??
        Theme.of(context).textTheme.labelLarge;
    final actionWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(0.0, 560.0).toDouble();
    final labelWidth = (actionWidth - 16 - iconHeight - 8)
        .clamp(0.0, double.infinity)
        .toDouble();
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    )..layout(maxWidth: labelWidth);
    final contentHeight =
        painter.height > iconHeight ? painter.height : iconHeight;
    return contentHeight > 48 ? contentHeight : 48;
  }

  double get _appBarActionSpace {
    final dialogWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(0.0, 560.0).toDouble();
    return dialogWidth - kToolbarHeight;
  }

  ({double normalWidth, double condensedWidth, double minimalWidth})
      _measureAppBarActionWidths() {
    final labels = _isEditMode
        ? [
            _isSaving
                ? AppLocalizations.of(context)!.mcpSaving
                : AppLocalizations.of(context)!.mermaidSaveButton,
            AppLocalizations.of(context)!.taskFlowUiDiscard,
          ]
        : _isExistingConfig
            ? [AppLocalizations.of(context)!.imagePreviewEdit]
            : const <String>[];
    if (labels.isEmpty) {
      return (normalWidth: 0, condensedWidth: 0, minimalWidth: 0);
    }

    final textScaler = MediaQuery.textScalerOf(context);
    return labels.fold<
            ({double normalWidth, double condensedWidth, double minimalWidth})>(
        (normalWidth: 0, condensedWidth: 0, minimalWidth: 0), (widths, label) {
      final button = TextButton.icon(
        onPressed: null,
        icon: const Icon(Icons.save, size: 20),
        label: Text(label),
      );
      final themeStyle = button.themeStyleOf(context);
      final defaultStyle = button.defaultStyleOf(context);
      final buttonPadding = (button.style?.padding?.resolve(const {}) ??
              themeStyle?.padding?.resolve(const {}) ??
              defaultStyle.padding?.resolve(const {}) ??
              EdgeInsets.zero)
          .resolve(Directionality.of(context));
      final labelStyle = button.style?.textStyle?.resolve(const {}) ??
          themeStyle?.textStyle?.resolve(const {}) ??
          defaultStyle.textStyle?.resolve(const {}) ??
          Theme.of(context).textTheme.labelLarge;
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      final fontSize = labelStyle?.fontSize ?? 14.0;
      final scale = (textScaler.scale(fontSize) / 14).clamp(1.0, 2.0) - 1.0;
      final iconGap = 8 - 4 * scale;
      final iconWidth =
          _isSaving && label == AppLocalizations.of(context)!.mcpSaving
              ? 16.0
              : 20.0;
      final contentWidth = painter.width + iconWidth + iconGap;
      final minimumWidth =
          (button.style?.minimumSize?.resolve(const {})?.width ??
                  themeStyle?.minimumSize?.resolve(const {})?.width ??
                  defaultStyle.minimumSize?.resolve(const {})?.width ??
                  64.0)
              .toDouble();
      return (
        normalWidth: widths.normalWidth +
            (contentWidth + buttonPadding.horizontal)
                .clamp(minimumWidth, double.infinity)
                .toDouble(),
        condensedWidth: widths.condensedWidth +
            (contentWidth + 16).clamp(minimumWidth, double.infinity).toDouble(),
        minimalWidth: widths.minimalWidth +
            contentWidth.clamp(minimumWidth, double.infinity).toDouble(),
      );
    });
  }

  List<Widget> _buildCompactAppBarActions() {
    if (_isEditMode) {
      final saveLabel = _isSaving
          ? AppLocalizations.of(context)!.mcpSaving
          : AppLocalizations.of(context)!.mermaidSaveButton;
      return [
        _buildCompactAppBarAction(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 20),
          label: saveLabel,
          iconHeight: _isSaving ? 16 : 20,
        ),
        _buildCompactAppBarAction(
          onPressed: _isSaving ? null : _discardChanges,
          icon: const Icon(Icons.close, size: 20),
          label: AppLocalizations.of(context)!.taskFlowUiDiscard,
          iconHeight: 20,
        ),
      ];
    }
    if (_isExistingConfig) {
      return [
        _buildCompactAppBarAction(
          onPressed: _enterEditMode,
          icon: const Icon(Icons.edit, size: 20),
          label: AppLocalizations.of(context)!.imagePreviewEdit,
          iconHeight: 20,
        ),
      ];
    }
    return const [];
  }

  List<Widget> _buildAppBarActions({required double? horizontalPadding}) {
    final actionStyle = horizontalPadding != null
        ? TextButton.styleFrom(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              8,
              horizontalPadding,
              8,
            ),
          )
        : null;
    if (_isEditMode) {
      final saveLabel = _isSaving
          ? AppLocalizations.of(context)!.mcpSaving
          : AppLocalizations.of(context)!.mermaidSaveButton;
      final discardLabel = AppLocalizations.of(context)!.taskFlowUiDiscard;
      return [
        TextButton.icon(
          onPressed: _isSaving ? null : _save,
          style: actionStyle,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 20),
          label: ConstrainedText(
            saveLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: _isSaving ? null : _discardChanges,
          style: actionStyle,
          icon: const Icon(Icons.close, size: 20),
          label: ConstrainedText(
            discardLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    }
    return [
      if (_isExistingConfig)
        TextButton.icon(
          style: actionStyle,
          icon: const Icon(Icons.edit, size: 20),
          label: ConstrainedText(
            AppLocalizations.of(context)!.imagePreviewEdit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: _enterEditMode,
        ),
    ];
  }

  Widget _buildCompactAppBarAction({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required double iconHeight,
  }) {
    return SizedBox(
      height: _compactActionHeight(label, iconHeight: iconHeight),
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class _McpDialogContentScroller extends StatelessWidget {
  const _McpDialogContentScroller({
    required this.width,
    required this.viewportHeight,
    required this.scroll,
    required this.child,
  });

  final double width;
  final double viewportHeight;
  final bool scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scaffold = child as Scaffold;
    if (!scroll) {
      return SizedBox(
        width: width,
        height: viewportHeight,
        child: child,
      );
    }

    final body = scaffold.body! as ListView;
    final scrollableBody = ListView.custom(
      childrenDelegate: body.childrenDelegate,
      padding: body.padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      primary: false,
    );
    return SizedBox(
      width: width,
      height: viewportHeight,
      child: SingleChildScrollView(
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: scaffold.appBar!.preferredSize.height,
                child: scaffold.appBar,
              ),
              scrollableBody,
            ],
          ),
        ),
      ),
    );
  }
}
