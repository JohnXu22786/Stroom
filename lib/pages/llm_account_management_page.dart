import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../ai_gateway/ai_gateway.dart';
import '../widgets/constrained_text.dart';
import '../widgets/stroom_menu_style.dart';
import '../services/llm_connector_service.dart';
import '../services/llm_connector_model_catalog.dart';
import '../services/cloudflare_workers_ai_connector.dart';
import '../services/llm_provider_preset_catalog.dart';
import '../services/amazon_q_connector.dart';
import '../services/azure_openai_endpoint.dart';
import '../services/devin_cli_acp.dart';
import '../services/api_protocol_config.dart';
import '../services/auggie_cli_service.dart';
import '../services/zcode_cli_service.dart';
import '../services/llm_oauth_flow.dart';
import '../services/llm_oauth_loopback.dart';
import '../services/zed_keychain_import.dart';
import '../services/trae_solo_connector.dart';
import 'browser_page.dart';
import 'trae_solo_authorization_page.dart';

Widget _accountDropdownLabel(String value) => ConstrainedText(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      useNaturalWidthLayout: true,
    );

Widget _accountFieldLabel(String value) => ConstrainedText(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      useNaturalWidthLayout: true,
    );

List<AiGatewayUpstreamModel> _pinnedAuggieModels(String accountId) => [
      for (var index = 0; index < AuggieCliService.pinnedModels.length; index++)
        AiGatewayUpstreamModel(
          id: '$accountId:auggie:$index',
          upstreamModelId: AuggieCliService.pinnedModels[index].id,
          displayName: AuggieCliService.pinnedModels[index].displayName,
          capabilities: {
            'chat': true,
            'streaming': true,
            'textOnly': true,
            'vision': false,
            'audio': false,
            'tools': false,
            'contextLength': AuggieCliService.pinnedModels[index].contextLength,
            'supportedApiProtocols': ['auggie.cli'],
          },
          config: const {
            'catalogSource': 'pinned_auggie_registry',
            'availability': 'unknown',
          },
        ),
    ];

List<AiGatewayUpstreamModel> _pinnedCodexAppServerModels(String accountId) => [
      for (var index = 0; index < kPinnedCodexModels.length; index++)
        AiGatewayUpstreamModel(
          id: '$accountId:codex-app-server:$index',
          upstreamModelId: kPinnedCodexModels[index],
          displayName: kPinnedCodexModels[index],
          capabilities: {
            if (!kPinnedCodexModels[index].startsWith('gpt-image-')) ...{
              'chat': true,
              'streaming': true,
              'reasoning': true,
              'tools': true,
              'textOnly': true,
            },
            'vision': false,
            'audio': false,
            'contextLength': 400000,
            'supportedApiProtocols': ['openai.responses'],
          },
          config: const {
            'catalogSource': 'pinned_codex_app_server_registry',
            'availability': 'unknown',
          },
        ),
    ];

List<AiGatewayUpstreamModel> _pinnedZcodeModels(String accountId) => [
      for (var index = 0; index < zcodePinnedModels.length; index++)
        AiGatewayUpstreamModel(
          id: '$accountId:zcode:$index',
          upstreamModelId: zcodePinnedModels[index].id,
          displayName: zcodePinnedModels[index].displayName,
          capabilities: {
            'chat': true,
            'streaming': true,
            'reasoning': true,
            'tools': true,
            'vision': zcodePinnedModels[index].supportsVision,
            'audio': false,
            'contextLength': zcodePinnedModels[index].contextLength,
            'supportedApiProtocols': ['openai.chat_completions'],
          },
          config: const {
            'catalogSource': 'pinned_zcode_registry',
            'availability': 'unknown',
          },
        ),
    ];

class LlmAccountManagementPage extends StatefulWidget {
  final AiGatewayFacade? gateway;
  final Future<void> Function()? onConfigurationChanged;
  final Future<void> Function(AiGatewayAccount account)? onAccountSaved;
  final Future<void> Function(AiGatewayAccount account)? onAccountDeleted;

  const LlmAccountManagementPage({
    super.key,
    this.gateway,
    this.onConfigurationChanged,
    this.onAccountSaved,
    this.onAccountDeleted,
  });

  @override
  State<LlmAccountManagementPage> createState() =>
      _LlmAccountManagementPageState();
}

class _LlmAccountManagementPageState extends State<LlmAccountManagementPage> {
  late final Future<AiGatewayFacade> _gatewayFuture;
  Future<_ManagementData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _gatewayFuture = widget.gateway == null
        ? AiGateway.sharedPlatform()
        : Future.value(widget.gateway!);
    _dataFuture = _load();
    LlmChatRouteDiagnostics.revision.addListener(_refreshDiagnostics);
  }

  @override
  void dispose() {
    LlmChatRouteDiagnostics.revision.removeListener(_refreshDiagnostics);
    super.dispose();
  }

  void _refreshDiagnostics() {
    if (!mounted) return;
    setState(() {
      _dataFuture = _load();
    });
  }

  Future<_ManagementData> _load() async {
    final gateway = await _gatewayFuture;
    final accountManagement = gateway.accountManagement;
    final results = await Future.wait([
      accountManagement.listAccounts(),
      accountManagement.listModelGroups(),
    ]);
    final gatewayAccounts = results[0] as List<AiGatewayAccount>;
    AiGatewayRoutingSnapshot? usageState;
    try {
      usageState = await gateway.loadRoutingState();
    } catch (_) {
      // Keep account and group management available if only local usage data
      // is malformed or temporarily unreadable.
    }
    final usageByAccount = <String, Map<String, num>>{};
    final usageByGroup = <String, Map<String, num>>{};
    for (final event in usageState?.events ?? const <AiGatewayUsageEvent>[]) {
      final measurements = usageByAccount.putIfAbsent(
        event.accountId,
        () => <String, num>{},
      );
      for (final measurement in event.measurements) {
        measurements.update(
          measurement.unit,
          (current) => current + measurement.value,
          ifAbsent: () => measurement.value,
        );
      }
      final groupId = event.groupId;
      final groupMeasurements = usageByGroup.putIfAbsent(
        groupId,
        () => <String, num>{},
      );
      for (final measurement in event.measurements) {
        groupMeasurements.update(
          measurement.unit,
          (current) => current + measurement.value,
          ifAbsent: () => measurement.value,
        );
      }
    }
    return _ManagementData(
      accounts: gatewayAccounts,
      groups: results[1] as List<AiGatewayModelGroup>,
      providerCatalog: gateway.providerCatalog,
      runtimeUsageByAccount: usageByAccount,
      runtimeUsageByGroup: usageByGroup,
      runtimeUsageAvailable: usageState != null,
    );
  }

  Future<void> _reload() async {
    if (!mounted) return;
    await widget.onConfigurationChanged?.call();
    if (!mounted) return;
    setState(() {
      _dataFuture = _load();
    });
    await _dataFuture;
  }

  Future<void> _addAccount() async {
    final gateway = await _gatewayFuture;
    if (!mounted) return;
    final result = await showDialog<_AccountEditResult>(
      context: context,
      builder: (_) => _AccountEditorDialog(
        providerCatalog: gateway.providerCatalog,
        modelDiscovery: gateway.modelDiscovery,
      ),
    );
    if (result == null || !mounted) return;
    try {
      final gateway = await _gatewayFuture;
      final saved = await _saveAccountResult(gateway, result);
      if (saved == null) return;
      await widget.onAccountSaved?.call(saved);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      _showError(
        AppLocalizations.of(context)?.llmAccountUiAccountSaving ??
            '账号保存失败。请检查账号信息和安全存储状态。',
      );
    }
  }

  Future<void> _editAccount(AiGatewayAccount account) async {
    final gateway = await _gatewayFuture;
    if (!mounted) return;
    final result = await showDialog<_AccountEditResult>(
      context: context,
      builder: (_) => _AccountEditorDialog(
        account: account,
        hasCredential: account.hasCredential,
        providerCatalog: gateway.providerCatalog,
        modelDiscovery: gateway.modelDiscovery,
      ),
    );
    if (result == null || !mounted) return;
    try {
      final gateway = await _gatewayFuture;
      final changingAwayFromCli =
          account.connectorType == 'devin-cli-agentic' &&
              result.account.connectorType != 'devin-cli-agentic';
      final groupsToRestore = changingAwayFromCli
          ? (await gateway.accountManagement.listModelGroups())
              .where(
                (group) => group.members.any(
                  (member) => member.accountId == account.id,
                ),
              )
              .toList()
          : const <AiGatewayModelGroup>[];
      final saved = await _saveAccountResult(
        gateway,
        result,
        cleanupCliLoginOnSaveFailure:
            account.connectorType != 'devin-cli-agentic',
      );
      if (saved == null) return;
      if (changingAwayFromCli && saved.connectorType != 'devin-cli-agentic') {
        try {
          await gateway.localCliAuthentication.logout(account);
        } catch (_) {
          var restored = false;
          try {
            await gateway.accountManagement.saveAccount(account);
            restored = true;
          } catch (_) {}
          if (restored) {
            for (final group in groupsToRestore) {
              try {
                await gateway.accountManagement.saveModelGroup(group);
              } catch (_) {}
            }
          }
          rethrow;
        }
      }
      await widget.onAccountSaved?.call(saved);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      _showError(
        AppLocalizations.of(context)?.llmAccountUiAccountSaving ??
            '账号保存失败。请检查账号信息和安全存储状态。',
      );
    }
  }

  Future<AiGatewayAccount?> _saveAccountResult(
    AiGatewayFacade gateway,
    _AccountEditResult result, {
    bool cleanupCliLoginOnSaveFailure = true,
  }) async {
    if (result.requiresCliLogin &&
        result.account.connectorType == 'devin-cli-agentic') {
      await gateway.localCliAuthentication.login(result.account);
      final account = result.account;
      try {
        return await gateway.accountManagement.saveAccount(
          AiGatewayAccount(
            id: account.id,
            connectorType: account.connectorType,
            authType: account.authType,
            displayName: account.displayName,
            status: account.status,
            endpointConfig: account.endpointConfig,
            models: account.models,
            policy: account.policy,
            usageByWindow: account.usageByWindow,
            remainingQuota: account.remainingQuota,
            quotaSignals: account.quotaSignals,
          ),
        );
      } catch (_) {
        if (cleanupCliLoginOnSaveFailure) {
          try {
            await gateway.localCliAuthentication.logout(account);
          } catch (_) {}
        }
        rethrow;
      }
    }
    if (!result.requiresOAuthAuthorization) {
      return gateway.accountManagement.saveAccount(
        result.account,
        secret: result.secret.isEmpty ? null : result.secret,
        traeCallbackIssued: result.traeCallbackIssued,
      );
    }
    if (result.account.connectorType == 'cursor') {
      final authorization = await gateway.oauthAuthorization
          .beginCursorAuthorization(result.account);
      if (!mounted) {
        authorization.cancel();
        return null;
      }
      return showDialog<AiGatewayAccount>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _CursorOAuthAuthorizationDialog(authorization: authorization),
      );
    }
    if (result.account.connectorType == 'kilocode') {
      final authorization = await gateway.oauthAuthorization
          .beginKiloDeviceAuthorization(result.account);
      if (!mounted) {
        authorization.cancel();
        return null;
      }
      return showDialog<AiGatewayAccount>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _KiloDeviceAuthorizationDialog(authorization: authorization),
      );
    }
    if (result.account.connectorType != 'kimi-coding') {
      if ({
        'codebuddy-cn',
        'codebuddy-intl',
        'workbuddy',
      }.contains(result.account.connectorType)) {
        final authorization = await gateway.oauthAuthorization
            .beginTencentDeviceAuthorization(result.account);
        if (!mounted) {
          authorization.cancel();
          return null;
        }
        return showDialog<AiGatewayAccount>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _TencentDeviceAuthorizationDialog(
            authorization: authorization,
            connectorType: result.account.connectorType,
          ),
        );
      }
      if (result.account.connectorType == 'grok-cli' ||
          result.account.connectorType == 'xai-oauth') {
        final authorization = await gateway.oauthAuthorization
            .beginXaiDeviceAuthorization(result.account);
        if (!mounted) {
          authorization.cancel();
          return null;
        }
        return showDialog<AiGatewayAccount>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _XaiDeviceAuthorizationDialog(
            authorization: authorization,
            connectorType: result.account.connectorType,
          ),
        );
      }
      if (result.account.connectorType == 'github' ||
          result.account.connectorType == 'ghe-copilot') {
        final authorization = await gateway.oauthAuthorization
            .beginGithubDeviceAuthorization(result.account);
        if (!mounted) {
          authorization.cancel();
          return null;
        }
        return showDialog<AiGatewayAccount>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _XaiDeviceAuthorizationDialog(
            authorization: authorization,
            connectorType: result.account.connectorType,
          ),
        );
      }
      if (result.account.connectorType == 'muse-code') {
        final authorization = await gateway.oauthAuthorization
            .beginMetaMuseDeviceAuthorization(result.account);
        if (!mounted) {
          authorization.cancel();
          return null;
        }
        return showDialog<AiGatewayAccount>(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              _MetaMuseDeviceAuthorizationDialog(authorization: authorization),
        );
      }
      return gateway.oauthAuthorization.authorize(
        result.account,
        configuration: result.oauthConfiguration,
        openInAppAuthorization: result.account.connectorType == 'zed-hosted'
            ? (authorizationUri, callbackUri, cancelSignal) async {
                if (!mounted) return false;
                final navigator = Navigator.of(context);
                final route = MaterialPageRoute<bool>(
                  builder: (_) => BrowserPage(
                    initialUrl: authorizationUri.toString(),
                    oauthCallbackUri: callbackUri,
                  ),
                );
                final browserResult = navigator.push<bool>(route);
                unawaited(
                  cancelSignal.then((_) {
                    if (route.isCurrent) navigator.pop(false);
                  }),
                );
                return await browserResult == true;
              }
            : null,
      );
    }

    final authorization = await gateway.oauthAuthorization
        .beginKimiCodeDeviceAuthorization(result.account);
    if (!mounted) {
      authorization.cancel();
      return null;
    }
    return showDialog<AiGatewayAccount>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _KimiCodeDeviceAuthorizationDialog(authorization: authorization),
    );
  }

  Future<void> _deleteAccount(AiGatewayAccount account) async {
    final deletionMessage =
        switch (account.authType == 'oauth' ? account.connectorType : '') {
      'codex' || 'gemini' || 'aistudio' => AppLocalizations.of(context)
              ?.llmConfirmDeleteAccountWithOAuth(account.displayName) ??
          '删除“${account.displayName}”、撤销 OAuth 授权并从模型组中移除该账号？',
      _ => AppLocalizations.of(context)
              ?.llmConfirmDeleteAccount(account.displayName) ??
          '删除“${account.displayName}”并从模型组中移除该账号？',
    };
    final confirmed = await _confirm(
      title: AppLocalizations.of(context)?.llmDelete ?? '删除账号',
      message: deletionMessage,
    );
    if (!confirmed || !mounted) return;
    var revocationFailed = false;
    try {
      final gateway = await _gatewayFuture;
      if (!mounted) return;
      final groupsToRestore = account.connectorType == 'devin-cli-agentic'
          ? (await gateway.accountManagement.listModelGroups())
              .where(
                (group) => group.members.any(
                  (member) => member.accountId == account.id,
                ),
              )
              .toList()
          : const <AiGatewayModelGroup>[];
      if (account.authType == 'oauth' && account.hasCredential) {
        revocationFailed =
            !await gateway.oauthAuthorization.deleteAccountAndRevoke(account);
      } else {
        await gateway.accountManagement.deleteAccount(account.id);
      }
      if (account.connectorType == 'devin-cli-agentic') {
        try {
          await gateway.localCliAuthentication.logout(account);
        } catch (_) {
          var restored = false;
          try {
            await gateway.accountManagement.saveAccount(account);
            restored = true;
          } catch (_) {}
          if (restored) {
            for (final group in groupsToRestore) {
              try {
                await gateway.accountManagement.saveModelGroup(group);
              } catch (_) {}
            }
          }
          rethrow;
        }
      }
    } catch (_) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)?.llmAccountUiAccountDeletion ??
              '账号删除失败。',
        );
      }
      return;
    }
    try {
      await widget.onAccountDeleted?.call(account);
    } catch (_) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)?.llmAccountUiTheAccount ??
              '账号已删除，但旧配置清理失败。',
        );
      }
    }
    if (mounted && revocationFailed) {
      _showError(
        AppLocalizations.of(context)?.llmAccountUiTheAccountWas ??
            '账号已删除，但 OAuth 撤销失败。请到提供商账户设置中撤销授权。',
      );
    }
    if (mounted) await _reload();
  }

  Future<void> _importZedKeychainAccounts() async {
    final gateway = await _gatewayFuture;
    if (!mounted) return;
    if (Platform.isMacOS) {
      final continueDiscovery = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                AppLocalizations.of(context)?.llmCheckZedKeychain ??
                    AppLocalizations.of(context)?.llmAccountUiCheckZed ??
                    '检查 Zed 钥匙串？',
              ),
              content: const Text(
                'macOS 可能在生成可导入清单时，逐项询问是否允许 Stroom 检查匹配的钥匙串条目。'
                '这一步不会保存账号；之后你仍需逐个确认要导入的账号。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    AppLocalizations.of(context)?.llmContinueKeychainScan ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiKeepChecking ??
                        '继续检查',
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted || !continueDiscovery) return;
    }
    final importer = ZedKeychainImportService(
      reader: const MethodChannelZedKeychainReader(),
      saveAccount: (account, {required secret}) async {
        final existing = (await gateway.accountManagement.listAccounts())
            .where((item) => item.id == account.id)
            .firstOrNull;
        final target = existing == null
            ? account
            : AiGatewayAccount(
                id: existing.id,
                connectorType: existing.connectorType,
                authType: existing.authType,
                displayName: existing.displayName,
                status: existing.status,
                hasCredential: existing.hasCredential,
                endpointConfig: existing.endpointConfig,
                models: existing.models,
                policy: existing.policy,
                usageByWindow: existing.usageByWindow,
                remainingQuota: existing.remainingQuota,
                quotaSignals: existing.quotaSignals,
              );
        return gateway.accountManagement.saveAccount(target, secret: secret);
      },
    );

    late final List<ZedKeychainCredentialCandidate> candidates;
    try {
      candidates = await importer.discover();
    } on ZedKeychainImportException {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)?.llmAccountUiUnableTo ??
              '无法读取系统钥匙串。请检查系统钥匙串访问权限后重试。',
        );
      }
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      _showError(
        '没有找到可读取的 Zed OpenAI、Anthropic、Google、Mistral 或 xAI 凭据。'
        '${Platform.isMacOS ? '如果 macOS 拒绝了某个钥匙串请求，该条目会被跳过。' : ''}',
      );
      return;
    }

    var imported = 0;
    var stopped = false;
    var legacyCleanupFailed = false;
    for (final candidate in candidates) {
      if (!mounted) return;
      late final bool alreadyExists;
      try {
        alreadyExists = (await gateway.accountManagement.listAccounts()).any(
          (account) => account.id == _zedAccountId(candidate),
        );
      } catch (_) {
        stopped = true;
        break;
      }
      if (!mounted) return;
      final providerName = switch (candidate.provider) {
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'google' => 'Google',
        'mistral' => 'Mistral',
        'xai' => 'xAI',
        _ => AppLocalizations.of(context)?.llmAccountUiProviderText ?? '提供商',
      };
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                AppLocalizations.of(context)
                        ?.llmImportCredentialsConfirmTitle(providerName) ??
                    '导入 $providerName 凭据？',
              ),
              content: Text(
                [
                  AppLocalizations.of(context)?.llmKeychainImportAccountSource(
                        candidate.account,
                        providerName,
                      ) ??
                      '将从本机钥匙串导入“${candidate.account}”到 Stroom 的 $providerName API 账号。',
                  if (alreadyExists)
                    AppLocalizations.of(context)
                            ?.llmKeychainImportExistingAccountNotice ??
                        '这会更新该 Stroom 账号的密钥，并保留现有名称、模型和路由设置。',
                  AppLocalizations.of(context)?.llmKeychainImportSecurityNote ??
                      'Stroom 会在确认后重新读取并核对该凭据。密钥不会显示在界面中。',
                ].join('\n\n'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppLocalizations.of(context)?.actionCancel ?? '跳过',
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    AppLocalizations.of(context)?.llmImportThisAccount ??
                        AppLocalizations.of(context)?.llmAccountUiImportThis ??
                        '导入此账号',
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
      if (!confirmed) continue;
      try {
        final saved = await importer.importConfirmed(candidate);
        imported++;
        try {
          await widget.onAccountSaved?.call(saved);
        } catch (_) {
          legacyCleanupFailed = true;
          stopped = true;
          break;
        }
      } on ZedKeychainImportException {
        stopped = true;
        break;
      }
    }
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    if (stopped) {
      final message = legacyCleanupFailed
          ? AppLocalizations.of(context)
                  ?.llmImportStoppedAfterLegacySyncFailure(imported) ??
              '已导入 $imported 个账号，但旧配置同步失败。'
          : imported == 0
              ? AppLocalizations.of(context)?.llmAccountUiCredentialsNot ??
                  '凭据未导入。钥匙串项目可能已更改、访问被拒绝，或安全存储不可用。'
              : AppLocalizations.of(context)
                      ?.llmImportStoppedAfterCredentialFailure(imported) ??
                  '已导入 $imported 个账号；后续凭据未导入，因为钥匙串项目已更改、访问被拒绝或安全存储不可用。';
      _showError(message);
    } else if (imported > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.llmImportedAccounts(imported) ??
                '已安全导入 $imported 个提供商账号。',
          ),
        ),
      );
    }
  }

  String _zedAccountId(ZedKeychainCredentialCandidate candidate) =>
      'zed-${candidate.provider}-${ZedKeychainImportService.fingerprint(candidate.service, candidate.account, '')}';

  Future<void> _addGroup(List<AiGatewayAccount> accounts) async {
    final choices = [
      for (final account in accounts)
        for (final model in account.models) (account, model),
    ];
    if (choices.isEmpty) {
      _showError(
        AppLocalizations.of(context)?.llmAccountUiPleaseAdd ??
            '请先在账号中添加模型，再创建模型组。',
      );
      return;
    }
    final (account, model) = choices.first;
    final initial = AiGatewayModelGroup(
      id: const Uuid().v4(),
      displayName: model.displayName,
      members: [
        AiGatewayModelGroupMember(
          accountId: account.id,
          upstreamModelId: model.upstreamModelId,
          localModelId: model.id,
        ),
      ],
    );
    await _editGroup(initial, accounts);
  }

  Future<void> _editGroup(
    AiGatewayModelGroup group,
    List<AiGatewayAccount> accounts,
  ) async {
    final gateway = await _gatewayFuture;
    if (!mounted) return;
    final updated = await showDialog<AiGatewayModelGroup>(
      context: context,
      builder: (_) => _ModelGroupEditorDialog(
        group: group,
        accounts: accounts,
        providerCatalog: gateway.providerCatalog,
      ),
    );
    if (updated == null || !mounted) return;
    try {
      final gateway = await _gatewayFuture;
      await gateway.accountManagement.saveModelGroup(updated);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      _showError(
        AppLocalizations.of(context)?.llmAccountUiTheModel ??
            '模型组保存失败。请确认成员账号中存在对应的上游模型。',
      );
    }
  }

  Future<void> _deleteGroup(AiGatewayModelGroup group) async {
    final confirmed = await _confirm(
      title: AppLocalizations.of(context)?.llmDelete ?? '删除模型组',
      message: AppLocalizations.of(context)
              ?.llmConfirmDeleteModelGroup(group.displayName) ??
          '删除“${group.displayName}”的路由配置？已有会话中的模型引用不会改写。',
    );
    if (!confirmed || !mounted) return;
    try {
      final gateway = await _gatewayFuture;
      await gateway.accountManagement.deleteModelGroup(group.id);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      _showError(
        AppLocalizations.of(context)?.llmAccountUiModelGroup ?? '模型组删除失败。',
      );
    }
  }

  Future<void> _editPolicy({
    required AiGatewayRoutingPolicy policy,
    required String title,
    required bool showGroupOnlyControls,
    required Future<void> Function(AiGatewayRoutingPolicy) save,
  }) async {
    final updated = await showDialog<AiGatewayRoutingPolicy>(
      context: context,
      builder: (_) => _RoutingPolicyEditorDialog(
        title: title,
        policy: policy,
        showGroupOnlyControls: showGroupOnlyControls,
      ),
    );
    if (updated == null || !mounted) return;
    await save(updated);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)?.llmDelete ?? '删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ManagementData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                AppLocalizations.of(context)?.llmAccountManagementTitle ??
                    AppLocalizations.of(context)?.llmAccountUiLLMAccount ??
                    'LLM 账号与模型组',
              ),
              centerTitle: true,
              bottom: TabBar(
                tabs: [
                  Tab(
                    text: AppLocalizations.of(context)?.llmAccountsTab ?? '账号',
                  ),
                  Tab(
                    text: AppLocalizations.of(context)?.llmModelGroupsTab ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiModelGroupText ??
                        '模型组',
                  ),
                ],
              ),
            ),
            body: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : snapshot.hasError
                    ? _LoadFailure(onRetry: _reload)
                    : TabBarView(
                        children: [
                          _buildAccounts(snapshot.data!),
                          _buildGroups(snapshot.data!),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildAccounts(_ManagementData data) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountsSummary ??
                        AppLocalizations.of(context)?.llmAccountUiEachAccount ??
                        '每个账号独立保存凭据、模型能力、额度和并发策略。未知额度保持未知。',
                  ),
                ),
                if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
                  IconButton.filledTonal(
                    tooltip: AppLocalizations.of(context)
                            ?.llmImportZedCredentials ??
                        AppLocalizations.of(context)?.llmAccountUiImportAPI ??
                        '从 Zed 导入 API 凭据',
                    onPressed: _importZedKeychainAccounts,
                    icon: const Icon(Icons.key_outlined),
                  ),
                IconButton.filledTonal(
                  tooltip:
                      AppLocalizations.of(context)?.llmAccountAdd ?? '添加账号',
                  onPressed: _addAccount,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        if (data.accounts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                AppLocalizations.of(context)?.llmAccountEmpty ?? '还没有 LLM 账号。',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: data.accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _AccountCard(
                account: data.accounts[index],
                providerCatalog: data.providerCatalog,
                recentError: _recentRequestErrorForAccount(
                  data.accounts[index].id,
                  data.groups,
                  AppLocalizations.of(context),
                ),
                localUsage:
                    data.runtimeUsageByAccount[data.accounts[index].id] ??
                        const <String, num>{},
                runtimeUsageAvailable: data.runtimeUsageAvailable,
                onEdit: () => _editAccount(data.accounts[index]),
                onDelete: () => _deleteAccount(data.accounts[index]),
                onPolicy: () => _editPolicy(
                  policy: data.accounts[index].policy,
                  title: AppLocalizations.of(context)?.llmRoutingPolicyTitle(
                        data.accounts[index].displayName,
                      ) ??
                      '${data.accounts[index].displayName} 路由策略',
                  showGroupOnlyControls: false,
                  save: (policy) async {
                    final account = data.accounts[index];
                    try {
                      final gateway = await _gatewayFuture;
                      await gateway.accountManagement.saveAccount(
                        AiGatewayAccount(
                          id: account.id,
                          connectorType: account.connectorType,
                          authType: account.authType,
                          displayName: account.displayName,
                          status: account.status,
                          hasCredential: account.hasCredential,
                          endpointConfig: account.endpointConfig,
                          models: account.models,
                          policy: policy,
                          usageByWindow: account.usageByWindow,
                          remainingQuota: account.remainingQuota,
                          quotaSignals: account.quotaSignals,
                        ),
                      );
                      await _reload();
                    } catch (_) {
                      if (!context.mounted) return;
                      _showError(
                        AppLocalizations.of(context)?.llmAccountUiTheRouting ??
                            '路由策略保存失败。',
                      );
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroups(_ManagementData data) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.llmModelGroupsSummary ??
                        AppLocalizations.of(context)?.llmAccountUiStableModel ??
                        '稳定模型组把旧会话模型 ID 映射到可选账号和上游模型。成员只能在此组内回退。',
                  ),
                ),
                IconButton.filledTonal(
                  tooltip:
                      AppLocalizations.of(context)?.llmAddModelGroupTooltip ??
                          AppLocalizations.of(context)?.llmAccountUiAddModel ??
                          '添加模型组',
                  onPressed: () => _addGroup(data.accounts),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        if (data.groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                AppLocalizations.of(context)?.llmNoModelGroups ?? '还没有模型组。',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: data.groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ModelGroupCard(
                group: data.groups[index],
                accounts: data.accounts,
                localUsage: data.runtimeUsageByGroup[data.groups[index].id] ??
                    const <String, num>{},
                runtimeUsageAvailable: data.runtimeUsageAvailable,
                onEdit: () => _editGroup(data.groups[index], data.accounts),
                onDelete: () => _deleteGroup(data.groups[index]),
                onPolicy: () => _editPolicy(
                  policy: data.groups[index].policy,
                  title: AppLocalizations.of(context)?.llmRoutingPolicyTitle(
                        data.groups[index].displayName,
                      ) ??
                      '${data.groups[index].displayName} 路由策略',
                  showGroupOnlyControls: true,
                  save: (policy) async {
                    final group = data.groups[index];
                    try {
                      final gateway = await _gatewayFuture;
                      await gateway.accountManagement.saveModelGroup(
                        AiGatewayModelGroup(
                          id: group.id,
                          displayName: group.displayName,
                          members: group.members,
                          policy: policy,
                          legacyModelId: group.legacyModelId,
                          legacyProviderName: group.legacyProviderName,
                        ),
                      );
                      await _reload();
                    } catch (_) {
                      if (!context.mounted) return;
                      _showError(
                        AppLocalizations.of(context)?.llmAccountUiTheRouting ??
                            '路由策略保存失败。',
                      );
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CursorOAuthAuthorizationDialog extends StatelessWidget {
  final AiGatewayOAuthCursorAuthorization authorization;

  const _CursorOAuthAuthorizationDialog({required this.authorization});

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Connect Cursor'),
          content: FutureBuilder<AiGatewayAccount>(
            future: authorization.completed,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Cursor sign-in could not be completed. Cancel and start again.',
                );
              }
              if (snapshot.hasData) {
                return const Text('Cursor is connected.');
              }
              return const Text(
                'Complete sign-in in Stroom’s in-app browser, then return here. '
                'Stroom checks authorization directly with Cursor and does not '
                'read or import another browser session.',
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                authorization.cancel();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FutureBuilder<AiGatewayAccount>(
              future: authorization.completed,
              builder: (context, snapshot) => TextButton(
                onPressed: snapshot.hasData
                    ? () => Navigator.of(context).pop(snapshot.data)
                    : snapshot.hasError
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => BrowserPage(
                                  initialUrl:
                                      authorization.authorizationUri.toString(),
                                ),
                              ),
                            );
                          },
                child: Text(snapshot.hasData ? 'Finish' : 'Open sign-in'),
              ),
            ),
          ],
        ),
      );
}

class _KimiCodeDeviceAuthorizationDialog extends StatefulWidget {
  final AiGatewayOAuthDeviceAuthorization authorization;

  const _KimiCodeDeviceAuthorizationDialog({required this.authorization});

  @override
  State<_KimiCodeDeviceAuthorizationDialog> createState() =>
      _KimiCodeDeviceAuthorizationDialogState();
}

class _KimiCodeDeviceAuthorizationDialogState
    extends State<_KimiCodeDeviceAuthorizationDialog> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authorization.completed.then(
      (account) {
        if (mounted) Navigator.of(context).pop(account);
      },
      onError: (Object _) {
        if (mounted) {
          setState(
            () => _error = AppLocalizations.of(context)
                    ?.llmProviderAuthorizationFailed('Kimi Code') ??
                'Kimi Code 授权失败，请重新开始登录。',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<AiGatewayAccount>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) widget.authorization.cancel();
        },
        child: AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.llmSignInProvider('Kimi Code CLI') ??
                AppLocalizations.of(context)?.llmAccountUiLoginTo ??
                '登录 Kimi Code CLI',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.llmOAuthInstructions('Kimi') ??
                    AppLocalizations.of(context)?.llmAccountUiOpenThe ??
                    '打开 Kimi 验证页面，输入下面的代码。授权完成后 Stroom 会自动保存账号。',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.authorization.userCode),
              const SizedBox(height: 8),
              SelectableText(
                widget.authorization.verificationUriComplete.toString(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!)
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchUrl(
                  widget.authorization.verificationUriComplete,
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(
                AppLocalizations.of(context)
                        ?.llmOpenProviderAuthorization('Kimi') ??
                    AppLocalizations.of(context)?.llmAccountUiOpenKimi ??
                    '打开 Kimi',
              ),
            ),
            TextButton(
              onPressed: () {
                widget.authorization.cancel();
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
            ),
          ],
        ),
      );
}

class _KiloDeviceAuthorizationDialog extends StatefulWidget {
  final AiGatewayOAuthDeviceAuthorization authorization;

  const _KiloDeviceAuthorizationDialog({required this.authorization});

  @override
  State<_KiloDeviceAuthorizationDialog> createState() =>
      _KiloDeviceAuthorizationDialogState();
}

class _KiloDeviceAuthorizationDialogState
    extends State<_KiloDeviceAuthorizationDialog> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authorization.completed.then(
      (account) {
        if (mounted) Navigator.of(context).pop(account);
      },
      onError: (Object _) {
        if (mounted) {
          setState(
            () => _error = AppLocalizations.of(context)
                    ?.llmProviderAuthorizationFailed('Kilo Code') ??
                'Kilo Code 授权失败，请重新开始登录。',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<AiGatewayAccount>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) widget.authorization.cancel();
        },
        child: AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.llmSignInProvider('Kilo Code') ??
                AppLocalizations.of(context)?.llmAccountUiLoginToKilo ??
                '登录 Kilo Code',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)
                        ?.llmOAuthInstructions('Kilo Code') ??
                    AppLocalizations.of(context)?.llmAccountUiOpenTheKilo ??
                    '打开 Kilo Code 验证页面并输入代码。授权完成后 Stroom 会自动保存账号。',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.authorization.userCode),
              const SizedBox(height: 8),
              SelectableText(
                widget.authorization.verificationUriComplete.toString(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!)
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchUrl(
                  widget.authorization.verificationUriComplete,
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(
                AppLocalizations.of(context)
                        ?.llmOpenProviderAuthorization('Kilo Code') ??
                    AppLocalizations.of(context)?.llmAccountUiOpenKilo ??
                    '打开 Kilo Code',
              ),
            ),
            TextButton(
              onPressed: () {
                widget.authorization.cancel();
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
            ),
          ],
        ),
      );
}

class _MetaMuseDeviceAuthorizationDialog extends StatefulWidget {
  final AiGatewayOAuthDeviceAuthorization authorization;

  const _MetaMuseDeviceAuthorizationDialog({required this.authorization});

  @override
  State<_MetaMuseDeviceAuthorizationDialog> createState() =>
      _MetaMuseDeviceAuthorizationDialogState();
}

class _MetaMuseDeviceAuthorizationDialogState
    extends State<_MetaMuseDeviceAuthorizationDialog> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authorization.completed.then(
      (account) {
        if (mounted) Navigator.of(context).pop(account);
      },
      onError: (Object _) {
        if (mounted) {
          setState(
            () => _error = AppLocalizations.of(context)
                    ?.llmProviderAuthorizationFailed('Meta Muse') ??
                'Meta Muse 授权失败，请重新开始登录。',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<AiGatewayAccount>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) widget.authorization.cancel();
        },
        child: AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.llmSignInProvider('Meta Muse Code') ??
                AppLocalizations.of(context)?.llmAccountUiLoginMeta ??
                '登录 Meta Muse Code',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.llmOAuthInstructions('Meta') ??
                    AppLocalizations.of(context)?.llmAccountUiOpenTheMeta ??
                    '打开 Meta 验证页面并输入下面的代码。授权完成后 Stroom 会自动保存账号。',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.authorization.userCode),
              const SizedBox(height: 8),
              SelectableText(
                widget.authorization.verificationUriComplete.toString(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!)
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchUrl(
                  widget.authorization.verificationUriComplete,
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(
                AppLocalizations.of(context)
                        ?.llmOpenProviderAuthorization('Meta') ??
                    AppLocalizations.of(context)?.llmAccountUiOpenMeta ??
                    '打开 Meta',
              ),
            ),
            TextButton(
              onPressed: () {
                widget.authorization.cancel();
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
            ),
          ],
        ),
      );
}

class _XaiDeviceAuthorizationDialog extends StatefulWidget {
  final AiGatewayOAuthDeviceAuthorization authorization;
  final String connectorType;

  const _XaiDeviceAuthorizationDialog({
    required this.authorization,
    required this.connectorType,
  });

  @override
  State<_XaiDeviceAuthorizationDialog> createState() =>
      _XaiDeviceAuthorizationDialogState();
}

class _XaiDeviceAuthorizationDialogState
    extends State<_XaiDeviceAuthorizationDialog> {
  String? _error;

  String get _providerName => switch (widget.connectorType) {
        'github' => 'GitHub Copilot',
        'ghe-copilot' => 'GitHub Enterprise Copilot',
        'grok-cli' => 'Grok Build',
        _ => 'xAI API',
      };

  @override
  void initState() {
    super.initState();
    widget.authorization.completed.then(
      (account) {
        if (mounted) Navigator.of(context).pop(account);
      },
      onError: (Object _) {
        if (mounted) {
          setState(
            () => _error = AppLocalizations.of(context)
                    ?.llmProviderAuthorizationFailed(_providerName) ??
                '$_providerName 授权失败，请重新开始登录。',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<AiGatewayAccount>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) widget.authorization.cancel();
        },
        child: AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.llmSignInProvider(_providerName) ??
                '登录 $_providerName',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)
                        ?.llmOAuthInstructions(_providerName) ??
                    '打开 $_providerName 验证页面，输入下面的代码。授权完成后 Stroom 会自动保存账号。',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.authorization.userCode),
              const SizedBox(height: 8),
              SelectableText(
                widget.authorization.verificationUriComplete.toString(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!)
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchUrl(
                  widget.authorization.verificationUriComplete,
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(
                AppLocalizations.of(context)
                        ?.llmOpenProviderAuthorization(_providerName) ??
                    '打开 $_providerName',
              ),
            ),
            TextButton(
              onPressed: () {
                widget.authorization.cancel();
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
            ),
          ],
        ),
      );
}

class _ManagementData {
  final List<AiGatewayAccount> accounts;
  final List<AiGatewayModelGroup> groups;
  final AiGatewayProviderCatalog providerCatalog;
  final Map<String, Map<String, num>> runtimeUsageByAccount;
  final Map<String, Map<String, num>> runtimeUsageByGroup;
  final bool runtimeUsageAvailable;

  const _ManagementData({
    required this.accounts,
    required this.groups,
    required this.providerCatalog,
    required this.runtimeUsageByAccount,
    required this.runtimeUsageByGroup,
    required this.runtimeUsageAvailable,
  });
}

class _LoadFailure extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadFailure({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)?.llmAccountGroupLoadError ??
                  AppLocalizations.of(context)?.llmAccountUiTheAccountOr ??
                  '账号或模型组无法读取。',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)?.llmRetryLoad ?? '重试'),
            ),
          ],
        ),
      );
}

class _AccountCard extends StatelessWidget {
  final AiGatewayAccount account;
  final AiGatewayProviderCatalog providerCatalog;
  final String? recentError;
  final Map<String, num> localUsage;
  final bool runtimeUsageAvailable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPolicy;

  const _AccountCard({
    required this.account,
    required this.providerCatalog,
    required this.recentError,
    required this.localUsage,
    required this.runtimeUsageAvailable,
    required this.onEdit,
    required this.onDelete,
    required this.onPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final connector = providerCatalog.findProvider(account.connectorType);
    final authLimitation = connector?.authTypeLimitations[account.authType];
    final quotaRows = [
      ..._quotaRows(account.usageByWindow, AppLocalizations.of(context)),
      ..._accountQuotaRows(account, AppLocalizations.of(context)),
    ];
    final policyRows = _policyWindowLimitRows(
      account.policy,
      AppLocalizations.of(context),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(connector?.displayName ?? account.connectorType),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'policy') onPolicy();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        AppLocalizations.of(context)?.llmEdit ?? '编辑账号',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'policy',
                      child: Text(
                        AppLocalizations.of(context)
                                ?.llmQuotaConcurrencyPolicy ??
                            AppLocalizations.of(context)
                                ?.llmAccountUiQuotaAnd ??
                            '额度与并发策略',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        AppLocalizations.of(context)?.llmDelete ?? '删除账号',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: Icon(_statusIcon(account.status), size: 18),
                  label: Text(
                    _statusLabel(account.status, AppLocalizations.of(context)),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    AppLocalizations.of(context)?.llmAccountConcurrencySummary(
                          account.policy.concurrencyLimit?.toString() ??
                              AppLocalizations.of(context)
                                  ?.assistantUnlimited ??
                              '不限',
                        ) ??
                        '账号并发 ${account.policy.concurrencyLimit?.toString() ?? '不限'}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              _connectionExplanation(
                account.status,
                AppLocalizations.of(context),
              ),
            ),
            Text(
              '${AppLocalizations.of(context)?.llmAuthenticationMethodLabel ?? '认证方式'}：${_authLabel(account.authType, connectorType: account.connectorType, l10n: AppLocalizations.of(context))}',
            ),
            if (account.connectorType == 'openference' ||
                account.connectorType == 'openference-api')
              Text(
                AppLocalizations.of(context)?.llmOpenferenceCatalogNote ??
                    AppLocalizations.of(context)?.llmAccountUiAvailableModels ??
                    '可用模型取决于 Openference 账号计划；离线模型目录不代表已获授权。',
              ),
            Text(
              AppLocalizations.of(context)?.llmAccountAuthSource(
                    _authSourceLabel(
                      account,
                      connector,
                      AppLocalizations.of(context),
                    ),
                  ) ??
                  '授权来源：${_authSourceLabel(account, connector, AppLocalizations.of(context))}',
            ),
            if (authLimitation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  authLimitation,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Text(
              AppLocalizations.of(context)?.llmAccountRecentError(
                    recentError ??
                        AppLocalizations.of(context)?.llmNoRecord ??
                        AppLocalizations.of(context)?.llmAccountUiNoRecord ??
                        '无记录',
                  ) ??
                  '最近错误：${recentError ?? '无记录'}',
            ),
            if (connector?.supportsChatAdapter != true ||
                !LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
                  account.connectorType,
                  account.authType,
                ))
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)
                              ?.llmConnectorUnavailableForChat ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiChatAdapterDoes ??
                          'ChatAdapter 暂不支持此连接器。',
                    ),
                    Text(
                      AppLocalizations.of(context)
                              ?.llmAccountUnavailableInSelectors ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiThisAccount ??
                          '该账号的模型组不会出现在聊天与 Task Flow 模型选择器中。',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.llmModelsCapabilitiesHeading ??
                  AppLocalizations.of(context)?.llmAccountUiModelsAnd ??
                  '模型与能力',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (account.models.isEmpty)
              Text(
                AppLocalizations.of(context)?.llmNoModelsConfigured ?? '未配置模型',
              )
            else
              for (final model in account.models)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${model.displayName} (${model.upstreamModelId}) · ${_capabilitiesLabel(model.capabilities, AppLocalizations.of(context))}',
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.llmUsageQuotaHeading ?? '用量与额度',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (quotaRows.isEmpty)
              Text(AppLocalizations.of(context)?.llmQuotaUnknown ?? '额度未知')
            else
              for (final row in quotaRows) Text(row),
            if (policyRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.llmQuotaLimitsHeading ?? '额度限制',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final row in policyRows) Text(row),
            ],
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.llmLocalObservedUsageHeading ??
                  AppLocalizations.of(context)?.llmAccountUiLocalObservation ??
                  '本地观测用量',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (localUsage.isEmpty)
              Text(
                runtimeUsageAvailable
                    ? AppLocalizations.of(context)?.llmAccountUiNoLocal ??
                        '暂无本地记录（最近 62 天）'
                    : AppLocalizations.of(context)
                            ?.llmAccountUiLocalObservationUsage ??
                        '本地观测用量未知（路由记录无法读取）',
              )
            else ...[
              Text(
                AppLocalizations.of(context)?.llmUsageHistoryDisclaimer ??
                    AppLocalizations.of(context)?.llmAccountUiLocalStatistics ??
                    '最近 62 天的本地统计，不代表账号余额。',
              ),
              for (final entry in localUsage.entries)
                Text(
                  '${_usageUnitLabel(entry.key, AppLocalizations.of(context))}：${_formatUsageValue(entry.value)}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelGroupCard extends StatelessWidget {
  final AiGatewayModelGroup group;
  final List<AiGatewayAccount> accounts;
  final Map<String, num> localUsage;
  final bool runtimeUsageAvailable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPolicy;

  const _ModelGroupCard({
    required this.group,
    required this.accounts,
    required this.localUsage,
    required this.runtimeUsageAvailable,
    required this.onEdit,
    required this.onDelete,
    required this.onPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final accountNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    final diagnostic = LlmChatRouteDiagnostics.latestForGroup(group.id);
    final preservesLegacyIdentity = group.members.asMap().entries.any(
          (entry) => _preservesStableGroupIdentity(
            group,
            members: group.members,
            index: entry.key,
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'policy') onPolicy();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        AppLocalizations.of(context)?.llmEdit ?? '编辑模型组',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'policy',
                      child: Text(
                        AppLocalizations.of(context)
                                ?.llmQuotaConcurrencyPolicy ??
                            AppLocalizations.of(context)
                                ?.llmAccountUiQuotaAndFallback ??
                            '额度与回退策略',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !preservesLegacyIdentity,
                      child: Text(
                        preservesLegacyIdentity
                            ? AppLocalizations.of(context)
                                    ?.llmKeepLegacyGroup ??
                                AppLocalizations.of(context)
                                    ?.llmAccountUiKeepOld ??
                                '保留旧会话模型组'
                            : AppLocalizations.of(context)?.llmDelete ??
                                AppLocalizations.of(context)
                                    ?.llmAccountUiDeleteModel ??
                                '删除模型组',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SelectableText(
              group.id,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${AppLocalizations.of(context)?.llmFallbackScopeLabel ?? '回退范围'}：'
              '${_fallbackLabel(group.policy.fallbackScope, AppLocalizations.of(context))} · '
              '${AppLocalizations.of(context)?.llmConcurrencyLimitLabel ?? '组并发'}：'
              '${group.policy.concurrencyLimit?.toString() ?? '不限'}',
            ),
            Text(
              AppLocalizations.of(context)?.llmSamePriorityStrategySummary(
                    _strategyLabel(
                      group.policy.strategy,
                      AppLocalizations.of(context),
                    ),
                  ) ??
                  '同优先级策略：${_strategyLabel(group.policy.strategy, AppLocalizations.of(context))}',
            ),
            Text(
              localUsage.isEmpty
                  ? runtimeUsageAvailable
                      ? AppLocalizations.of(context)
                              ?.llmAccountUiModelGroupLocal ??
                          '模型组本地累计用量：未知'
                      : AppLocalizations.of(context)
                              ?.llmAccountUiModelGroupLocalCumulative ??
                          '模型组本地累计用量：未知（路由记录无法读取）'
                  : AppLocalizations.of(context)?.llmAccountGroupUsageSummary(
                        localUsage.entries
                            .map(
                              (entry) =>
                                  '${_usageUnitLabel(entry.key, AppLocalizations.of(context))} ${_formatUsageValue(entry.value)}',
                            )
                            .join(' · '),
                      ) ??
                      '模型组本地累计用量：${localUsage.entries.map((entry) => '${_usageUnitLabel(entry.key, AppLocalizations.of(context))} ${_formatUsageValue(entry.value)}').join(' · ')}',
            ),
            for (final row in _policyWindowLimitRows(
              group.policy,
              AppLocalizations.of(context),
            ))
              Text(row),
            if (preservesLegacyIdentity)
              Text(
                AppLocalizations.of(context)?.llmLegacyMemberRequired ??
                    AppLocalizations.of(context)
                        ?.llmAccountUiTheCorresponding ??
                    '需保留旧会话模型引用对应的成员及本地引用 ID。',
              ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.llmMembersHeading ?? '成员',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (group.members.isEmpty)
              Text(
                AppLocalizations.of(context)?.llmNoRoutableMembers ??
                    AppLocalizations.of(context)?.llmAccountUiThereAre ??
                    '没有可路由的账号成员',
              )
            else
              for (final member in group.members)
                Text(
                  '${accountNames[member.accountId] ?? '账号已删除'} · '
                  '${AppLocalizations.of(context)?.llmGroupMemberSummary(member.upstreamModelId, member.priorityTier, member.localModelId ?? group.id) ?? '${member.upstreamModelId} · 优先级 ${member.priorityTier} · 本地引用 ${member.localModelId ?? group.id}'}',
                ),
            const SizedBox(height: 8),
            if (diagnostic != null) ...[
              Text(
                AppLocalizations.of(context)?.llmLastRouteHeading ?? '最近一次路由',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                diagnostic.selectedAccountId == null
                    ? AppLocalizations.of(context)?.llmNoAccountCanProcessModel(
                          diagnostic.localModelId,
                        ) ??
                        '没有账号可处理 ${diagnostic.localModelId}'
                    : '${diagnostic.requestSucceeded ? AppLocalizations.of(context)?.llmRequestUsedAccount ?? '本轮使用账号' : AppLocalizations.of(context)?.llmLastAttemptedAccount ?? '最后尝试账号'}：${accountNames[diagnostic.selectedAccountId] ?? diagnostic.selectedAccountId}',
              ),
              for (final decision in diagnostic.decisions)
                Text(
                  '${accountNames[decision.subjectId] ?? decision.subjectId}：'
                  '${_localizedRouteDecisionLabel(decision.reason, AppLocalizations.of(context))}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _quotaRows(
  Map<AiGatewayUsageWindow, AiGatewayUsageWindowState> usage,
  AppLocalizations? l10n,
) {
  final labels = {
    AiGatewayUsageWindow.fiveHour: l10n?.llmAccountUiHoursText ?? '5 小时',
    AiGatewayUsageWindow.day: l10n?.llmAccountUiDailyText ?? '每日',
    AiGatewayUsageWindow.week: l10n?.llmAccountUiWeeklyText ?? '每周',
    AiGatewayUsageWindow.month: l10n?.llmAccountUiMonthlyText ?? '每月',
  };
  final rows = <String>[];
  for (final window in AiGatewayUsageWindow.values) {
    final state = usage[window] ?? const AiGatewayUsageWindowState();
    final quota = state.quota;
    final used = state.used;
    final remaining = state.remaining;
    if (!quota.isKnown && !used.isKnown && !remaining.isKnown) continue;
    final parts = <String>[];
    parts.add(
      '${l10n?.llmAccountUsageUsedLabel ?? '已用'} ${used.isKnown ? _metricLabel(used, l10n) : l10n?.llmQuotaUnknown ?? '未知'}',
    );
    parts.add(
      '${l10n?.llmAccountUsageRemainingLabel ?? '剩余'} ${remaining.isKnown ? _metricLabel(remaining, l10n) : l10n?.llmQuotaUnknown ?? '未知'}',
    );
    parts.add(
      '${l10n?.llmAccountUsageTotalLabel ?? '总额'} ${quota.isKnown ? _metricLabel(quota, l10n) : l10n?.llmQuotaUnknown ?? '未知'}',
    );
    rows.add('${labels[window]}：${parts.join(' · ')}');
  }
  return rows;
}

List<String> _accountQuotaRows(
  AiGatewayAccount account,
  AppLocalizations? l10n,
) {
  final rows = <String>[];
  if (_isDisplayableQuotaMetric(account.remainingQuota)) {
    rows.add(
      '${l10n?.llmAccountRemainingQuotaLabel ?? '剩余额度：'}${_metricLabel(account.remainingQuota, l10n)}',
    );
  }
  for (final entry in account.quotaSignals.entries) {
    if (!_isDisplayableQuotaMetric(entry.value)) continue;
    rows.add(
      '${_quotaSignalLabel(entry.key, l10n)}：${_metricLabel(entry.value, l10n)}',
    );
  }
  return rows;
}

bool _isDisplayableQuotaMetric(AiGatewayMetricObservation metric) =>
    metric.isKnown &&
    metric.value != null &&
    metric.value!.isFinite &&
    metric.value! >= 0;

String _quotaSignalLabel(
  String signal,
  AppLocalizations? l10n,
) =>
    switch (signal) {
      'primaryRemainingPercent' => l10n?.llmAccountUiMainWindow ?? '主窗口额度剩余',
      'secondaryRemainingPercent' =>
        l10n?.llmAccountUiTheRemaining ?? '次窗口额度剩余',
      'dailyRemainingPercent' => l10n?.llmAccountUiDailyQuota ?? '每日额度剩余',
      'weeklyRemainingPercent' => l10n?.llmAccountUiWeeklyQuota ?? '每周额度剩余',
      'monthlyRemainingPercent' => l10n?.llmAccountUiMonthlyQuota ?? '每月额度剩余',
      'codeReviewRemainingPercent' =>
        l10n?.llmAccountUiCodeReview ?? '代码审查额度剩余',
      _ => signal,
    };

String _metricLabel(
  AiGatewayMetricObservation metric,
  AppLocalizations? l10n,
) =>
    '${metric.value ?? l10n?.llmQuotaUnknown ?? '未知'} ${metric.unit ?? l10n?.llmAccountMetricUnitUnknown ?? '单位未知'}';

String _usageUnitLabel(String unit, AppLocalizations? l10n) => switch (unit) {
      'requests' => l10n?.llmAccountUiRequestText ?? '请求',
      'tokens' => 'tokens',
      'usd' => 'USD',
      _ => unit,
    };

String _formatUsageValue(num value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String _capabilitiesLabel(
  Map<String, dynamic> capabilities,
  AppLocalizations? l10n,
) {
  if (capabilities.isEmpty) return l10n?.llmAccountUiAbilityUnknown ?? '能力未知';
  return capabilities.entries.map((entry) {
    final support = entry.value == true
        ? l10n?.llmAccountCapabilitySupported ?? '支持'
        : entry.value == false
            ? l10n?.llmAccountCapabilityUnsupported ?? '不支持'
            : l10n?.llmAccountCapabilityUnknown ?? '未知';
    return '${entry.key} $support';
  }).join('、');
}

String _statusLabel(AiGatewayAccountStatus status, AppLocalizations? l10n) =>
    switch (status) {
      AiGatewayAccountStatus.unknown =>
        l10n?.llmAccountUiConnectionStatus ?? '连接状态未知',
      AiGatewayAccountStatus.ready => l10n?.llmAccountUiReadyText ?? '就绪',
      AiGatewayAccountStatus.paused => l10n?.llmAccountUiSuspendedText ?? '已暂停',
      AiGatewayAccountStatus.needsAttention =>
        l10n?.llmAccountUiReAuthentication ?? '需要重新认证',
    };

String _connectionExplanation(
  AiGatewayAccountStatus status,
  AppLocalizations? l10n,
) =>
    switch (status) {
      AiGatewayAccountStatus.unknown =>
        l10n?.llmAccountUiTheConnection ?? '连接状态未知；路由仍可尝试请求，请根据请求结果更新状态。',
      AiGatewayAccountStatus.ready =>
        l10n?.llmAccountUiAccountsCan ?? '账号可参与其模型组路由。',
      AiGatewayAccountStatus.paused =>
        l10n?.llmAccountUiTheAccountHas ?? '账号已暂停，不会参与路由。',
      AiGatewayAccountStatus.needsAttention =>
        l10n?.llmAccountUiTheAccountNeeds ?? '账号需要重新认证后才会参与路由。',
    };

String _authLabel(
  String type, {
  String? connectorType,
  AppLocalizations? l10n,
}) {
  if (connectorType == 'cursor' && type == 'api_key') {
    return 'Cursor User API Key';
  }
  if (connectorType == 'trae' && type == 'session_token') {
    return l10n?.llmAccountUiPasteCloud ?? '粘贴 Cloud-IDE-JWT';
  }
  if (connectorType == 'cline' && type == 'oauth') {
    return 'Cline WorkOS OAuth';
  }
  if (connectorType == 'clinepass' && type == 'oauth') {
    return 'ClinePass via Cline OAuth';
  }
  if (connectorType == 'cline' && type == 'api_key') {
    return 'Cline API Key';
  }
  if (connectorType == 'clinepass' && type == 'api_key') {
    return 'ClinePass API Key';
  }
  if (connectorType == 'openference' && type == 'oauth') {
    return 'Openference OAuth';
  }
  if (connectorType == 'openference-api' && type == 'api_key') {
    return 'Openference API Key';
  }
  if (connectorType == 'kilocode' && type == 'oauth') {
    return l10n?.llmAccountUiKiloCodeDevice ?? 'Kilo Code 设备 OAuth';
  }
  if (connectorType == 'kilocode' && type == 'api_key') {
    return 'Kilo Code API Key';
  }
  if (connectorType == 'kilocode' && type == 'none') {
    return l10n?.llmAccountUiAnonymousFree ?? '匿名（仅免费模型）';
  }
  if (connectorType == 'qoder' && type == 'oauth') {
    return l10n?.llmAccountUiQoderAdministrator ?? 'Qoder 管理员配置 OAuth';
  }
  if (connectorType == 'qoder' && type == 'pat') {
    return 'Qoder Personal Access Token';
  }
  if (type == 'oauth' && connectorType == 'codebuddy-cn') {
    return l10n?.llmAccountUiCodeBuddyDomestic ?? 'CodeBuddy 国内设备 OAuth';
  }
  if (type == 'oauth' && connectorType == 'codebuddy-intl') {
    return l10n?.llmAccountUiCodeBuddyInternational ??
        'CodeBuddy International 设备 OAuth';
  }
  if (type == 'oauth' && connectorType == 'workbuddy') {
    return l10n?.llmAccountUiWorkBuddyCLI ?? 'WorkBuddy CLI 设备 OAuth';
  }
  if (type == 'oauth' && connectorType == 'vertex') {
    return l10n?.llmAccountUiLegacyOAuth ?? '旧版 OAuth（不支持）';
  }
  if (type == 'oauth' && connectorType == 'claude') {
    return 'Claude Code OAuth';
  }
  return switch (type) {
    'api_key' => switch (connectorType) {
        'bedrock' => 'Amazon Bedrock API Key',
        'aihorde' => 'AI Horde API Key (higher queue priority)',
        'qoder' => 'DashScope API Key',
        _ => 'API Key',
      },
    'pat' => 'Personal Access Token',
    'oauth' => l10n?.llmAccountUiSubscribeTo ?? '订阅 OAuth',
    'setup_token' => 'Setup Token',
    'service_account' => l10n?.llmAccountUiGoogleService ?? 'Google 服务账号',
    'aws_credentials' => l10n?.llmAccountUiAWSAccess ??
        'AWS Access + Secret Key（Session Token 可选）',
    'aws_credential_chain' => l10n?.llmAccountUiAWSDefault ?? 'AWS 默认凭据链',
    'session_token' => l10n?.llmAccountUiSessionToken ?? '会话令牌',
    'cli_session' => l10n?.llmAccountUiOfficialDevin ?? '官方 Devin CLI 独立登录',
    'relay' => l10n?.llmAccountUiLegacyAI ?? '旧版 AI Studio relay（已停用）',
    'none' => l10n?.llmAccountUiNoCertification ?? '无认证',
    _ => type,
  };
}

class _TencentDeviceAuthorizationDialog extends StatefulWidget {
  final AiGatewayOAuthDeviceAuthorization authorization;
  final String connectorType;

  const _TencentDeviceAuthorizationDialog({
    required this.authorization,
    required this.connectorType,
  });

  @override
  State<_TencentDeviceAuthorizationDialog> createState() =>
      _TencentDeviceAuthorizationDialogState();
}

class _TencentDeviceAuthorizationDialogState
    extends State<_TencentDeviceAuthorizationDialog> {
  String? _error;

  String get _name => switch (widget.connectorType) {
        'codebuddy-cn' => 'CodeBuddy',
        'codebuddy-intl' => 'CodeBuddy International',
        _ => 'WorkBuddy',
      };

  @override
  void initState() {
    super.initState();
    widget.authorization.completed.then(
      (account) {
        if (mounted) Navigator.of(context).pop(account);
      },
      onError: (Object _) {
        if (mounted) {
          setState(
            () => _error = AppLocalizations.of(context)
                    ?.llmProviderAuthorizationFailed(_name) ??
                '$_name 授权失败，请重新开始登录。',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<AiGatewayAccount>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) widget.authorization.cancel();
        },
        child: AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.llmSignInProvider(_name) ??
                '登录 $_name',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.llmOAuthInstructions(_name) ??
                    '打开 $_name 验证页面并输入下方代码。授权完成后 Stroom 会自动保存账号。',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.authorization.userCode),
              const SizedBox(height: 8),
              SelectableText(
                widget.authorization.verificationUriComplete.toString(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!)
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => launchUrl(
                widget.authorization.verificationUriComplete,
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                AppLocalizations.of(context)
                        ?.llmOpenProviderAuthorization(_name) ??
                    AppLocalizations.of(context)
                        ?.llmAccountUiOpenVerification ??
                    '打开验证页面',
              ),
            ),
            TextButton(
              onPressed: () {
                widget.authorization.cancel();
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
            ),
          ],
        ),
      );
}

String _authSourceLabel(
  AiGatewayAccount account,
  AiGatewayProviderDefinition? connector,
  AppLocalizations? l10n,
) {
  final provider = connector?.displayName ?? account.connectorType;
  return switch (account.authType) {
    'oauth' => account.connectorType == 'vertex'
        ? 'Unsupported Vertex OAuth; reconnect with a supported credential type'
        : '$provider OAuth',
    'setup_token' => '$provider Setup Token',
    'api_key' => account.connectorType == 'bedrock'
        ? 'Amazon Bedrock API Key'
        : account.connectorType == 'openai-compatibility'
            ? l10n?.llmAccountUiUserProvided ?? '用户提供的上游 API Key'
            : '$provider API Key',
    'service_account' =>
      l10n?.llmProviderEnterpriseCredentials(provider) ?? '$provider 企业服务凭据',
    'aws_credentials' =>
      l10n?.llmAccountUiAWSBedrock ?? 'AWS Bedrock 用户提供的静态凭据',
    'aws_credential_chain' => l10n?.llmAccountUiAWSDefault ?? 'AWS 默认凭据链',
    'session_token' =>
      l10n?.llmProviderSessionToken(provider) ?? '$provider 用户提供的会话令牌',
    'cli_session' =>
      l10n?.llmAccountUiStroomDevin ?? 'Stroom 为此账号单独创建的 Devin CLI 登录配置',
    'relay' => l10n?.llmAccountUiTheLegacy ??
        '旧版 AI Studio relay 已停用；请改用 API Key 或受支持的 OAuth。',
    'none' => l10n?.llmAccountUiNativeCompatible ?? '本地兼容端点，无凭据',
    _ => l10n?.llmProviderCredential(provider) ?? '$provider 提供的凭据',
  };
}

String? _recentRequestErrorForAccount(
  String accountId,
  Iterable<AiGatewayModelGroup> groups,
  AppLocalizations? l10n,
) {
  LlmChatRouteDiagnostic? latest;
  String? latestReason;
  for (final group in groups) {
    if (!group.members.any((member) => member.accountId == accountId)) {
      continue;
    }
    final diagnostic = LlmChatRouteDiagnostics.latestForGroup(group.id);
    if (diagnostic == null ||
        (latest != null && !diagnostic.recordedAt.isAfter(latest.recordedAt))) {
      continue;
    }
    final accountFailure = diagnostic.decisions
        .where(
          (decision) =>
              decision.subjectId == accountId &&
              decision.reason.startsWith('request_'),
        )
        .lastOrNull;
    if (accountFailure == null) continue;
    latest = diagnostic;
    latestReason = accountFailure.reason;
  }
  return latestReason == null
      ? null
      : _safeRequestErrorLabel(latestReason, l10n);
}

String _safeRequestErrorLabel(String reason, AppLocalizations? l10n) =>
    switch (reason) {
      'request_authentication' =>
        l10n?.llmAccountUiUpstreamAuthentication ?? '上游认证失败',
      'request_quotaExhausted' =>
        l10n?.llmAccountUiInsufficientUpstream ?? '上游额度不足',
      'request_rateLimited' => l10n?.llmAccountUiUpstreamRequests ?? '上游请求受限',
      'request_connection' => l10n?.llmAccountUiUpstreamConnection ?? '上游连接失败',
      'request_server' => l10n?.llmAccountUiUpstreamService ?? '上游服务错误',
      'request_invalidRequest' => l10n?.llmAccountUiUpstreamRejects ?? '上游拒绝请求',
      'request_cancelled' => l10n?.llmAccountUiRequestCanceled ?? '请求已取消',
      _ => l10n?.llmAccountUiUpstreamRequest ?? '上游请求失败',
    };

String _localizedRouteDecisionLabel(
  String reason,
  AppLocalizations? l10n,
) =>
    switch (reason) {
      'session_affinity' =>
        l10n?.llmRouteDecisionSessionAffinity ?? llmRouteDecisionLabel(reason),
      'session_affinity_persistence_failed' =>
        l10n?.llmRouteDecisionSessionAffinityPersistenceFailed ??
            llmRouteDecisionLabel(reason),
      'explicit_account_selection' =>
        l10n?.llmRouteDecisionExplicitAccountSelection ??
            llmRouteDecisionLabel(reason),
      'selected_account_outside_group' =>
        l10n?.llmRouteDecisionSelectedAccountOutsideGroup ??
            llmRouteDecisionLabel(reason),
      'conversation_id_invalid' =>
        l10n?.llmRouteDecisionConversationIdInvalid ??
            llmRouteDecisionLabel(reason),
      'model_group_missing' => l10n?.llmRouteDecisionModelGroupMissing ??
          llmRouteDecisionLabel(reason),
      'model_group_ambiguous' => l10n?.llmRouteDecisionModelGroupAmbiguous ??
          llmRouteDecisionLabel(reason),
      'connector_protocol_incompatible' =>
        l10n?.llmRouteDecisionConnectorProtocolIncompatible ??
            llmRouteDecisionLabel(reason),
      'connection_unknown' => l10n?.llmRouteDecisionConnectionUnknown ??
          llmRouteDecisionLabel(reason),
      'account_missing' =>
        l10n?.llmRouteDecisionAccountMissing ?? llmRouteDecisionLabel(reason),
      'account_id_invalid' =>
        l10n?.llmRouteDecisionAccountIdInvalid ?? llmRouteDecisionLabel(reason),
      'account_unavailable' => l10n?.llmRouteDecisionAccountUnavailable ??
          llmRouteDecisionLabel(reason),
      'model_mapping_mismatch' => l10n?.llmRouteDecisionModelMappingMismatch ??
          llmRouteDecisionLabel(reason),
      'model_not_mapped' =>
        l10n?.llmRouteDecisionModelNotMapped ?? llmRouteDecisionLabel(reason),
      'capability_mismatch' => l10n?.llmRouteDecisionCapabilityMismatch ??
          llmRouteDecisionLabel(reason),
      'fallback_scope' =>
        l10n?.llmRouteDecisionFallbackScope ?? llmRouteDecisionLabel(reason),
      'cooldown' =>
        l10n?.llmRouteDecisionCooldown ?? llmRouteDecisionLabel(reason),
      'concurrency_limit' =>
        l10n?.llmRouteDecisionConcurrencyLimit ?? llmRouteDecisionLabel(reason),
      'balance_unknown_or_incomparable' =>
        l10n?.llmRouteDecisionBalanceUnknownOrIncomparable ??
            llmRouteDecisionLabel(reason),
      'balance_at_or_below_reserve' =>
        l10n?.llmRouteDecisionBalanceAtOrBelowReserve ??
            llmRouteDecisionLabel(reason),
      'usage_unknown' =>
        l10n?.llmRouteDecisionUsageUnknown ?? llmRouteDecisionLabel(reason),
      'reserve_balance_unknown' =>
        l10n?.llmRouteDecisionReserveBalanceUnknown ??
            llmRouteDecisionLabel(reason),
      'reserve_unit_unknown_or_incomparable' =>
        l10n?.llmRouteDecisionReserveUnitUnknownOrIncomparable ??
            llmRouteDecisionLabel(reason),
      'reserve_total_unknown_or_incomparable' =>
        l10n?.llmRouteDecisionReserveTotalUnknownOrIncomparable ??
            llmRouteDecisionLabel(reason),
      'reserve_total_unknown' => l10n?.llmRouteDecisionReserveTotalUnknown ??
          llmRouteDecisionLabel(reason),
      'reserve_usage_estimate_unknown' =>
        l10n?.llmRouteDecisionReserveUsageEstimateUnknown ??
            llmRouteDecisionLabel(reason),
      'reserve_in_flight_usage_unknown' =>
        l10n?.llmRouteDecisionReserveInFlightUsageUnknown ??
            llmRouteDecisionLabel(reason),
      'reserve_floor_reached' => l10n?.llmRouteDecisionReserveFloorReached ??
          llmRouteDecisionLabel(reason),
      'usage_ceiling_reached' => l10n?.llmRouteDecisionUsageCeilingReached ??
          llmRouteDecisionLabel(reason),
      'usage_ceiling_total_unknown' =>
        l10n?.llmRouteDecisionUsageCeilingTotalUnknown ??
            llmRouteDecisionLabel(reason),
      'usage_unit_mismatch' => l10n?.llmRouteDecisionUsageUnitMismatch ??
          llmRouteDecisionLabel(reason),
      'usage_source_mismatch' => l10n?.llmRouteDecisionUsageSourceMismatch ??
          llmRouteDecisionLabel(reason),
      'usage_in_flight_unknown' => l10n?.llmRouteDecisionUsageInFlightUnknown ??
          llmRouteDecisionLabel(reason),
      'usage_estimate_unknown' => l10n?.llmRouteDecisionUsageEstimateUnknown ??
          llmRouteDecisionLabel(reason),
      'invalid_window_timezone' =>
        l10n?.llmRouteDecisionInvalidWindowTimezone ??
            llmRouteDecisionLabel(reason),
      'reserve_floor' =>
        l10n?.llmRouteDecisionReserveFloor ?? llmRouteDecisionLabel(reason),
      'usage_ceiling' =>
        l10n?.llmRouteDecisionUsageCeiling ?? llmRouteDecisionLabel(reason),
      'request_authentication' => l10n?.llmRouteDecisionRequestAuthentication ??
          llmRouteDecisionLabel(reason),
      'request_quotaExhausted' => l10n?.llmRouteDecisionRequestQuotaExhausted ??
          llmRouteDecisionLabel(reason),
      'request_rateLimited' => l10n?.llmRouteDecisionRequestRateLimited ??
          llmRouteDecisionLabel(reason),
      'request_connection' => l10n?.llmRouteDecisionRequestConnection ??
          llmRouteDecisionLabel(reason),
      'request_server' =>
        l10n?.llmRouteDecisionRequestServer ?? llmRouteDecisionLabel(reason),
      'request_invalidRequest' => l10n?.llmRouteDecisionRequestInvalidRequest ??
          llmRouteDecisionLabel(reason),
      'request_cancelled' =>
        l10n?.llmRouteDecisionRequestCancelled ?? llmRouteDecisionLabel(reason),
      'request_other' =>
        l10n?.llmRouteDecisionRequestOther ?? llmRouteDecisionLabel(reason),
      _ => llmRouteDecisionLabel(reason),
    };

IconData _statusIcon(AiGatewayAccountStatus status) => switch (status) {
      AiGatewayAccountStatus.unknown => Icons.help_outline,
      AiGatewayAccountStatus.ready => Icons.check_circle_outline,
      AiGatewayAccountStatus.paused => Icons.pause_circle_outline,
      AiGatewayAccountStatus.needsAttention => Icons.warning_amber_outlined,
    };

String _fallbackLabel(AiGatewayFallbackScope scope, AppLocalizations? l10n) =>
    switch (scope) {
      AiGatewayFallbackScope.account =>
        l10n?.llmAccountUiSameConnector ?? '同一连接器账号',
      AiGatewayFallbackScope.modelGroup =>
        l10n?.llmAccountUiCurrentModel ?? '当前模型组',
    };

String _strategyLabel(
  AiGatewaySelectionStrategy strategy,
  AppLocalizations? l10n,
) =>
    switch (strategy) {
      AiGatewaySelectionStrategy.leastUsed =>
        l10n?.llmAccountUiLeastUsed ?? '最少使用',
      AiGatewaySelectionStrategy.roundRobin =>
        l10n?.llmAccountUiPollingText ?? '轮询',
      AiGatewaySelectionStrategy.balanceHigher =>
        l10n?.llmAccountUiPrioritizeHigher ?? '优先较高余额',
      AiGatewaySelectionStrategy.balanceLower =>
        l10n?.llmAccountUiPrioritizeConsumption ?? '优先消耗较低余额',
    };

class _AccountEditResult {
  final AiGatewayAccount account;
  final String secret;
  final Map<String, String> oauthConfiguration;
  final bool requiresOAuthAuthorization;
  final bool requiresCliLogin;
  final bool traeCallbackIssued;

  const _AccountEditResult(
    this.account,
    this.secret, {
    this.oauthConfiguration = const {},
    this.requiresOAuthAuthorization = false,
    this.requiresCliLogin = false,
    this.traeCallbackIssued = false,
  });
}

class _AccountEditorDialog extends StatefulWidget {
  final AiGatewayAccount? account;
  final bool hasCredential;
  final AiGatewayProviderCatalog providerCatalog;
  final AiGatewayModelDiscovery modelDiscovery;

  const _AccountEditorDialog({
    this.account,
    this.hasCredential = false,
    required this.providerCatalog,
    required this.modelDiscovery,
  });

  @override
  State<_AccountEditorDialog> createState() => _AccountEditorDialogState();
}

class _AccountEditorDialogState extends State<_AccountEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _azureDeployment;
  late final TextEditingController _azureApiVersion;
  late final TextEditingController _region;
  late final TextEditingController _projectId;
  late final TextEditingController _cloudflareAccountId;
  late final TextEditingController _credential;
  late final TextEditingController _models;
  late final TextEditingController _oauthClientId;
  late final TextEditingController _oauthClientSecret;
  late final TextEditingController _qoderAuthorizeUrl;
  late final TextEditingController _qoderTokenUrl;
  late final TextEditingController _qoderUserInfoUrl;
  late final TextEditingController _googleCloudProjectId;
  late final TextEditingController _devinCliExecutable;
  String? _initialDevinCliExecutable;
  late String _connectorType;
  late String _authType;
  late String _apiProtocol;
  String? _providerPresetId;
  String? _selectedCommandCodeModelId;
  String _commandCodeModelProtocol = '';
  late AiGatewayAccountStatus _status;
  var _draftChanged = false;
  String? _validatedTraeCallbackCredential;
  var _reconnectCli = false;
  var _trustDevinCliExecutable = false;
  String? _error;
  List<AiGatewayUpstreamModel> _discoveredModels = const [];

  bool get _isAzureConnector =>
      _connectorType == 'azure-ai' || _connectorType == 'azure-openai';

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _connectorType = account?.connectorType ?? 'openai-compatibility';
    final savedAuggieModels = account?.connectorType == 'auggie'
        ? account!.models
        : const <AiGatewayUpstreamModel>[];
    final auggieModelIds = savedAuggieModels.isEmpty
        ? AuggieCliService.pinnedModels.map((model) => model.id).join('\n')
        : savedAuggieModels.map((model) => model.upstreamModelId).join('\n');
    _authType = account?.authType ?? 'api_key';
    final savedProviderPresetId = account?.endpointConfig['providerPresetId'];
    _providerPresetId = _connectorType == 'openai-compatibility'
        ? findLlmOpenAiProviderPreset(
            savedProviderPresetId is String ? savedProviderPresetId : null,
          )?.id
        : null;
    final configuredProtocol = account?.endpointConfig['apiProtocol'];
    _apiProtocol = configuredProtocol is String &&
            kCustomHttpApiProtocols.contains(configuredProtocol)
        ? configuredProtocol
        : builtinDefaultApiProtocolForConnector(_connectorType);
    if ({'command-code', 'openai-compatibility'}.contains(_connectorType) &&
        account?.models.isNotEmpty == true) {
      final model = account!.models.first;
      _selectedCommandCodeModelId = model.upstreamModelId;
      final override = model.config['apiProtocolOverride'];
      if (override is String) _commandCodeModelProtocol = override;
    }
    _status = account?.status ?? AiGatewayAccountStatus.unknown;
    _name = TextEditingController(text: account?.displayName ?? '');
    final endpoint = account?.endpointConfig[
            _connectorType == 'ghe-copilot' ? 'gheUrl' : 'baseUrl'] ??
        account?.endpointConfig['host'] ??
        account?.endpointConfig['apiBase'];
    _endpoint = TextEditingController(text: endpoint is String ? endpoint : '');
    final deploymentId = account?.endpointConfig['azureDeploymentId'];
    _azureDeployment = TextEditingController(
      text: deploymentId is String ? deploymentId : '',
    );
    final apiVersion = account?.endpointConfig['apiVersion'];
    _azureApiVersion = TextEditingController(
      text: apiVersion is String && apiVersion.trim().isNotEmpty
          ? apiVersion
          : AzureOpenAiEndpoint.defaultApiVersion,
    );
    if (_connectorType == 'uncloseai') {
      _endpoint.text = 'https://hermes.ai.unturf.com/v1';
    }
    final configuredLocation = account?.endpointConfig['location'];
    final configuredRegion = account?.endpointConfig['region'];
    final region = account?.connectorType == 'vertex'
        ? configuredLocation is String
            ? configuredLocation
            : configuredRegion is String
                ? configuredRegion
                : null
        : configuredRegion is String
            ? configuredRegion
            : null;
    _region = TextEditingController(
      text: region ??
          (account?.connectorType == 'bedrock' ||
                  account?.connectorType == 'amazon-q'
              ? 'us-east-1'
              : account?.connectorType == 'vertex'
                  ? 'us-central1'
                  : account?.connectorType == 'qwen-cloud'
                      ? 'ap-southeast-1'
                      : ''),
    );
    final projectId = account?.endpointConfig['projectId'];
    _projectId = TextEditingController(
      text: projectId is String ? projectId : '',
    );
    final cloudflareAccountId = account?.endpointConfig['cloudflareAccountId'];
    _cloudflareAccountId = TextEditingController(
      text: cloudflareAccountId is String ? cloudflareAccountId : '',
    );
    _credential = TextEditingController();
    final copilotClientId = account?.endpointConfig['copilotClientId'] ??
        account?.endpointConfig['clientId'] ??
        account?.endpointConfig['qoderClientId'];
    _oauthClientId = TextEditingController(
      text: copilotClientId is String ? copilotClientId : '',
    );
    _oauthClientSecret = TextEditingController();
    _qoderAuthorizeUrl = TextEditingController(
      text: account?.endpointConfig['qoderLoginUrl'] as String? ?? '',
    );
    _qoderTokenUrl = TextEditingController(
      text: account?.endpointConfig['qoderExchangeUrl'] as String? ?? '',
    );
    _qoderUserInfoUrl = TextEditingController(
      text: account?.endpointConfig['qoderUserInfoUrl'] as String? ?? '',
    );
    final googleCloudProjectId =
        account?.endpointConfig['googleCloudProjectId'];
    _googleCloudProjectId = TextEditingController(
      text: googleCloudProjectId is String ? googleCloudProjectId : '',
    );
    final devinCliExecutable =
        account?.endpointConfig[DevinCliAcpLaunch.executablePathKey];
    _initialDevinCliExecutable =
        devinCliExecutable is String ? devinCliExecutable : null;
    _devinCliExecutable = TextEditingController(
      text: _initialDevinCliExecutable ?? '',
    );
    _models = TextEditingController(
      text: account?.connectorType == 'devin-cli-agentic'
          ? kPinnedDevinCliModels.join('\n')
          : account?.connectorType == 'auggie'
              ? auggieModelIds
              : account?.connectorType == 'kimi-coding'
                  ? kPinnedKimiCodeModels.join('\n')
                  : account?.models
                          .map(
                            (model) => [
                              model.upstreamModelId,
                              ...model.capabilities.entries
                                  .where((entry) => entry.value is bool)
                                  .map(
                                    (entry) => entry.value == true
                                        ? entry.key
                                        : '${entry.key}=false',
                                  ),
                              if ({
                                    'command-code',
                                    'openai-compatibility',
                                  }.contains(_connectorType) &&
                                  model.config['apiProtocolOverride'] is String)
                                'apiProtocolOverride=${model.config['apiProtocolOverride']}',
                            ].join(','),
                          )
                          .join('\n') ??
                      '',
    );
    if (_connectorType == 'cloudflare-ai') {
      _models.text = kCloudflareWorkersAiModelIds.join('\n');
      _discoveredModels = [
        for (final model in cloudflareWorkersAiModelCatalog(
          account?.id ?? 'new',
        ))
          AiGatewayUpstreamModel(
            id: model.id,
            upstreamModelId: model.upstreamModelId,
            displayName: model.displayName,
            capabilities: model.capabilities,
            config: model.config,
          ),
      ];
    }
    if (_connectorType == 'auggie') {
      _models.text = auggieModelIds;
      _discoveredModels = savedAuggieModels.isEmpty
          ? _pinnedAuggieModels(account?.id ?? 'new')
          : List<AiGatewayUpstreamModel>.of(savedAuggieModels);
      _endpoint.clear();
    }
    if (_connectorType == 'codex-app-server') {
      _authType = 'none';
      _apiProtocol = 'openai.responses';
      _models.text = account?.models.isNotEmpty == true
          ? account!.models.map((model) => model.upstreamModelId).join('\n')
          : kPinnedCodexModels.join('\n');
      _discoveredModels = account?.models.isNotEmpty == true
          ? List<AiGatewayUpstreamModel>.of(account!.models)
          : _pinnedCodexAppServerModels(account?.id ?? 'new');
      _endpoint.clear();
    }
    if (_connectorType == 'zcode-cli') {
      _authType = 'none';
      _apiProtocol = 'openai.chat_completions';
      _models.text = account?.models.isNotEmpty == true
          ? account!.models.map((model) => model.upstreamModelId).join('\n')
          : zcodePinnedModelIds.join('\n');
      _discoveredModels = account?.models.isNotEmpty == true
          ? List<AiGatewayUpstreamModel>.of(account!.models)
          : _pinnedZcodeModels(account?.id ?? 'new');
      _endpoint.clear();
    }
    if (_isAzureConnector && _azureDeployment.text.trim().isNotEmpty) {
      _models.text = _azureDeployment.text.trim();
    }
    final preset = findLlmOpenAiProviderPreset(_providerPresetId);
    if (_models.text.trim().isEmpty &&
        preset?.fallbackModels.isNotEmpty == true) {
      _models.text = preset!.fallbackModels
          .map(
            (model) =>
                model.accountEditorLine(modelIdPrefix: preset.modelIdPrefix),
          )
          .join('\n');
      _discoveredModels = [
        for (final model in preset.fallbackModels)
          AiGatewayUpstreamModel(
            id: '${account?.id ?? 'new'}:preset:${preset.modelIdPrefix}${model.id}',
            upstreamModelId: '${preset.modelIdPrefix}${model.id}',
            displayName: model.displayName,
            capabilities: {
              ...model.capabilities,
              if (preset.id == 'agentrouter')
                'supportedApiProtocols': _apiProtocolOptionsForPreset(preset),
            },
            config: {
              'catalogSource': 'pinned-provider-preset',
              if (model.apiProtocolOverride != null) ...{
                'apiProtocolOverride': model.apiProtocolOverride,
                'apiProtocolOverrideSource': 'provider-preset-default',
              },
            },
          ),
      ];
    }
  }

  void _selectProviderPreset(String value) {
    final preset = findLlmOpenAiProviderPreset(value.isEmpty ? null : value);
    final previousPreset = findLlmOpenAiProviderPreset(_providerPresetId);
    setState(() {
      _providerPresetId = preset?.id;
      _draftChanged = true;
      final inheritedOverrideModelIds = {
        for (final model
            in widget.account?.models ?? const <AiGatewayUpstreamModel>[])
          if (model.config['apiProtocolOverrideSource'] ==
              'provider-preset-default')
            model.upstreamModelId,
      };
      final normalizedLines = _models.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) {
        final parts = line.split(',');
        if (inheritedOverrideModelIds.contains(parts.first.trim())) {
          parts.removeWhere(
            (part) => part.trim().startsWith('apiProtocolOverride='),
          );
        }
        return parts.join(',');
      }).toList();
      if (preset == null) {
        _models.text = normalizedLines.join('\n');
        _discoveredModels = const [];
        return;
      }
      _authType = preset.authType;
      _apiProtocol = preset.defaultApiProtocol;
      _endpoint.text = preset.baseUrl;
      if (_name.text.trim().isEmpty) _name.text = preset.displayName;
      if (preset.fallbackModels.isNotEmpty) {
        _selectedCommandCodeModelId =
            '${preset.modelIdPrefix}${preset.fallbackModels.first.id}';
      }
      final previousFallbackModelIds = {
        for (final model in previousPreset?.fallbackModels ?? const [])
          '${previousPreset!.modelIdPrefix}${model.id}',
      };
      final currentLines = normalizedLines
          .where(
            (line) => !previousFallbackModelIds.contains(
              line.split(',').first.trim(),
            ),
          )
          .toList();
      final currentModelIds = {
        for (final line in currentLines) line.split(',').first.trim(),
      };
      final newFallbackLines = preset.fallbackModels
          .where(
            (model) =>
                !currentModelIds.contains('${preset.modelIdPrefix}${model.id}'),
          )
          .map(
            (model) =>
                model.accountEditorLine(modelIdPrefix: preset.modelIdPrefix),
          )
          .toList();
      if (_models.text.trim().isEmpty || previousPreset != null) {
        _models.text = [...currentLines, ...newFallbackLines].join('\n');
      }
      _discoveredModels = [
        for (final model in preset.fallbackModels)
          AiGatewayUpstreamModel(
            id: '${widget.account?.id ?? 'new'}:preset:${preset.modelIdPrefix}${model.id}',
            upstreamModelId: '${preset.modelIdPrefix}${model.id}',
            displayName: model.displayName,
            capabilities: {
              ...model.capabilities,
              if (preset.id == 'agentrouter')
                'supportedApiProtocols': _apiProtocolOptionsForPreset(preset),
            },
            config: {
              'catalogSource': 'pinned-provider-preset',
              if (model.apiProtocolOverride != null) ...{
                'apiProtocolOverride': model.apiProtocolOverride,
                'apiProtocolOverrideSource': 'provider-preset-default',
              },
            },
          ),
      ];
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _azureDeployment.dispose();
    _azureApiVersion.dispose();
    _region.dispose();
    _projectId.dispose();
    _cloudflareAccountId.dispose();
    _credential.dispose();
    _oauthClientId.dispose();
    _oauthClientSecret.dispose();
    _qoderAuthorizeUrl.dispose();
    _qoderTokenUrl.dispose();
    _qoderUserInfoUrl.dispose();
    _googleCloudProjectId.dispose();
    _devinCliExecutable.dispose();
    _models.dispose();
    super.dispose();
  }

  List<AiGatewayUpstreamModel> get _commandCodeModels {
    final models = <String, AiGatewayUpstreamModel>{};
    if ({'command-code', 'openai-compatibility'}.contains(_connectorType) &&
        widget.account?.connectorType == _connectorType) {
      for (final model in widget.account!.models) {
        models[model.upstreamModelId] = model;
      }
    }
    for (final model in _discoveredModels) {
      models[model.upstreamModelId] = model;
    }
    return models.values.toList(growable: false);
  }

  List<String> get _accountApiProtocolOptions {
    if (_connectorType == 'command-code') {
      return kCustomHttpApiProtocols.toList(growable: false);
    }
    if (_connectorType == 'openai-compatibility' &&
        _providerPresetId == 'agentrouter') {
      return _apiProtocolOptionsForPreset(
        findLlmOpenAiProviderPreset(_providerPresetId),
      );
    }
    return const [];
  }

  bool get _hasApiProtocolSelection => _accountApiProtocolOptions.length > 1;

  static List<String> _apiProtocolOptionsForPreset(LlmProviderPreset? preset) =>
      preset == null
          ? kCustomHttpApiProtocols.toList(growable: false)
          : preset.protocolRoutes.isNotEmpty
              ? preset.protocolRoutes.keys.toList(growable: false)
              : [preset.defaultApiProtocol];

  List<String> _commandCodeProtocolsForSelectedModel() {
    final selectedModel = _commandCodeModels
        .where((model) => model.upstreamModelId == _selectedCommandCodeModelId)
        .firstOrNull;
    final protocols = selectedModel?.capabilities['supportedApiProtocols'];
    if (_connectorType == 'openai-compatibility' &&
        _providerPresetId != 'agentrouter') {
      return kCustomHttpApiProtocols.toList(growable: false);
    }
    if (protocols is! Iterable) {
      return const [];
    }
    return protocols
        .whereType<String>()
        .where(kCustomHttpApiProtocols.contains)
        .toList(growable: false);
  }

  void _selectCommandCodeModel(String modelId) {
    final model = _commandCodeModels
        .where((item) => item.upstreamModelId == modelId)
        .firstOrNull;
    final override = model?.config['apiProtocolOverride'];
    setState(() {
      _selectedCommandCodeModelId = modelId;
      _commandCodeModelProtocol = override is String ? override : '';
    });
  }

  void _setCommandCodeModelProtocol(String protocol) {
    final modelId = _selectedCommandCodeModelId;
    if (modelId == null) return;
    final lines = _models.text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final parts = lines[index].split(',').map((part) => part.trim()).toList();
      if (parts.isEmpty || parts.first != modelId) continue;
      parts.removeWhere((part) => part.startsWith('apiProtocolOverride='));
      if (protocol.isNotEmpty) {
        parts.add('apiProtocolOverride=$protocol');
      }
      lines[index] = parts.join(',');
      break;
    }
    _models.text = lines.join('\n');
    setState(() {
      _commandCodeModelProtocol = protocol;
      _draftChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectors = widget.providerCatalog.providers.toList();
    final connector = widget.providerCatalog.findProvider(_connectorType)!;
    final authTypes = connector.supportedAuthTypes.toList();
    if (widget.account?.connectorType == _connectorType &&
        widget.account?.authType == 'oauth' &&
        !authTypes.contains('oauth')) {
      // Keep a legacy unsupported value visible so the editor cannot silently
      // rewrite it to another credential type before the user chooses one.
      authTypes.add('oauth');
    }
    if (widget.account?.connectorType == 'aistudio' &&
        widget.account?.authType == 'relay' &&
        !authTypes.contains('relay')) {
      // Keep the retired auth mode visible until the account is explicitly
      // reconfigured; never reinterpret its page-session record as an API key.
      authTypes.add('relay');
    }
    authTypes.sort();
    final oauthLimitation = connector.authTypeLimitations['oauth'];
    if (!authTypes.contains(_authType)) {
      _authType = _connectorType == 'gitlab-duo' && authTypes.contains('pat')
          ? 'pat'
          : authTypes.first;
    }
    final commandCodeModels = _commandCodeModels;
    final commandCodeProtocols = _commandCodeProtocolsForSelectedModel();
    final selectedCommandCodeProtocol =
        commandCodeProtocols.contains(_commandCodeModelProtocol)
            ? _commandCodeModelProtocol
            : '';
    return AlertDialog(
      title: Text(
        widget.account == null
            ? AppLocalizations.of(context)?.llmAccountEditTitleAdd ??
                AppLocalizations.of(context)?.llmAccountUiAddLLM ??
                '添加 LLM 账号'
            : AppLocalizations.of(context)?.llmAccountEditTitleEdit ??
                AppLocalizations.of(context)?.llmAccountUiEditLLM ??
                '编辑 LLM 账号',
      ),
      content: SizedBox(
        width: math.min(520.0, MediaQuery.sizeOf(context).width - 48),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmAccountName ?? '账号名称',
                  ),
                ),
                onChanged: (_) => setState(() => _draftChanged = true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                initialValue: _connectorType,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmConnectorLabel ?? '连接器',
                  ),
                ),
                items: [
                  for (final item in connectors)
                    DropdownMenuItem(
                      value: item.id,
                      child: _accountDropdownLabel(item.displayName),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _draftChanged = true;
                    final previousConnectorType = _connectorType;
                    _connectorType = value;
                    if (value != 'openai-compatibility') {
                      _providerPresetId = null;
                    }
                    if ((value == 'azure-ai' || value == 'azure-openai') &&
                        previousConnectorType != value) {
                      _azureDeployment.clear();
                      _azureApiVersion.text =
                          AzureOpenAiEndpoint.defaultApiVersion;
                      _models.clear();
                    }
                    _apiProtocol = builtinDefaultApiProtocolForConnector(value);
                    if (value == 'uncloseai') {
                      _authType = 'none';
                      _endpoint.text = 'https://hermes.ai.unturf.com/v1';
                    }
                    if (value == 'trae') {
                      _models.clear();
                      _endpoint.clear();
                      _discoveredModels = const [];
                    }
                    if (value == 'command-code' &&
                        widget.account?.connectorType != 'command-code') {
                      _models.clear();
                      _selectedCommandCodeModelId = null;
                      _commandCodeModelProtocol = '';
                      _discoveredModels = const [];
                    }
                    if (value == 'auggie') {
                      _authType = 'none';
                      _endpoint.clear();
                      _models.text = AuggieCliService.pinnedModels
                          .map((model) => model.id)
                          .join('\n');
                      _discoveredModels = _pinnedAuggieModels(
                        widget.account?.id ?? 'new',
                      );
                    } else if (value == 'codex-app-server') {
                      _authType = 'none';
                      _endpoint.clear();
                      _apiProtocol = 'openai.responses';
                      _models.text = kPinnedCodexModels.join('\n');
                      _discoveredModels = _pinnedCodexAppServerModels(
                        widget.account?.id ?? 'new',
                      );
                    } else if (value == 'zcode-cli') {
                      _authType = 'none';
                      _endpoint.clear();
                      _apiProtocol = 'openai.chat_completions';
                      _models.text = zcodePinnedModelIds.join('\n');
                      _discoveredModels = _pinnedZcodeModels(
                        widget.account?.id ?? 'new',
                      );
                    } else if (value == 'devin-cli-agentic') {
                      _models.text = kPinnedDevinCliModels.join('\n');
                    } else if (value == 'cloudflare-ai') {
                      _models.text = kCloudflareWorkersAiModelIds.join('\n');
                      _discoveredModels = [
                        for (final model in cloudflareWorkersAiModelCatalog(
                          widget.account?.id ?? 'new',
                        ))
                          AiGatewayUpstreamModel(
                            id: model.id,
                            upstreamModelId: model.upstreamModelId,
                            displayName: model.displayName,
                            capabilities: model.capabilities,
                            config: model.config,
                          ),
                      ];
                    } else if (value == 'qoder') {
                      _models.text = kPinnedQoderModels.join('\n');
                    } else if (value == 'kimi-coding') {
                      _models.text = kPinnedKimiCodeModels.join('\n');
                    } else if (value == 'kilocode') {
                      _models.text = _authType == 'none'
                          ? kKiloCodeAnonymousFreeModelIds.join('\n')
                          : kPinnedKiloCodeModels.join('\n');
                    } else if (value == 'cline') {
                      _models.text = kPinnedClineModels.join('\n');
                    } else if (value == 'clinepass') {
                      _models.text = kPinnedClinePassModels.join('\n');
                    } else if (previousConnectorType == 'kimi-coding' ||
                        previousConnectorType == 'cline' ||
                        previousConnectorType == 'clinepass') {
                      _models.clear();
                    } else if (previousConnectorType == 'kilocode') {
                      _models.clear();
                    }
                    if (value == 'bedrock' &&
                        previousConnectorType != 'bedrock') {
                      _region.text = 'us-east-1';
                      _authType = 'aws_credentials';
                    } else if (value == 'vertex' &&
                        previousConnectorType != 'vertex') {
                      _region.text = 'us-central1';
                    } else if (value == 'qwen-cloud' &&
                        previousConnectorType != 'qwen-cloud') {
                      _region.text = 'ap-southeast-1';
                    } else if (value != 'qwen-cloud' &&
                        previousConnectorType == 'qwen-cloud') {
                      _region.clear();
                    }
                    final available = widget.providerCatalog
                        .findProvider(value)!
                        .supportedAuthTypes
                        .toList()
                      ..sort();
                    if (value == 'gitlab-duo' &&
                        previousConnectorType != value) {
                      _authType = 'pat';
                    } else if (!available.contains(_authType)) {
                      _authType = available.first;
                    }
                    if (_connectorType == 'bedrock' &&
                        _region.text.trim().isEmpty) {
                      _region.text = 'us-east-1';
                    } else if ({
                          'vertex',
                          'vertex-partner',
                        }.contains(_connectorType) &&
                        _region.text.trim().isEmpty) {
                      _region.text = 'us-central1';
                    }
                    if (_authType == 'none' ||
                        _authType == 'cli_session' ||
                        _authType == 'relay' ||
                        _authType == 'aws_credential_chain') {
                      _credential.clear();
                    }
                    if (_connectorType == 'kilocode') {
                      _models.text = _authType == 'none'
                          ? kKiloCodeAnonymousFreeModelIds.join('\n')
                          : kPinnedKiloCodeModels.join('\n');
                    } else if (_connectorType == 'cline') {
                      _models.text = kPinnedClineModels.join('\n');
                    } else if (_connectorType == 'clinepass') {
                      _models.text = kPinnedClinePassModels.join('\n');
                    }
                  });
                },
              ),
              if (_connectorType == 'openai-compatibility') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor: StroomMenuStyle.surface(context),
                  borderRadius: StroomMenuStyle.borderRadius,
                  isExpanded: true,
                  initialValue: _providerPresetId ?? '',
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmProviderPresetLabel ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiServiceProvider ??
                          '服务商预设',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: _accountDropdownLabel(
                        AppLocalizations.of(context)
                                ?.llmAccountUiCustomOpenAI ??
                            '自定义 OpenAI 兼容端点',
                      ),
                    ),
                    for (final preset in llmOpenAiProviderPresets)
                      DropdownMenuItem(
                        value: preset.id,
                        child: _accountDropdownLabel(preset.displayName),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _selectProviderPreset(value);
                  },
                ),
              ],
              if (_connectorType == 'trae') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _connectTraeSolo,
                  icon: const Icon(Icons.login),
                  label: Text(
                    AppLocalizations.of(context)
                            ?.llmSignInProvider('Trae SOLO') ??
                        AppLocalizations.of(context)?.llmAccountUiLogIn ??
                        '在 Stroom 内登录 Trae SOLO',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)?.llmTraeCallbackPrivacy ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiLoginCallbacks ??
                        '登录回调只在本机接收并写入安全凭据存储；不会保存回调地址或浏览记录。',
                  ),
                ),
              ],
              if (connector.supportsChatAdapter != true ||
                  !LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
                    _connectorType,
                    _authType,
                  ))
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)
                            ?.llmAccountUiChatAdapterDoesNot ??
                        'ChatAdapter 暂不支持此连接器；保存后，该账号的模型组不会出现在聊天与 Task Flow 模型选择器中。',
                  ),
                ),
              if (_connectorType == 'openference' ||
                  _connectorType == 'openference-api')
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.of(context)?.llmOpenferenceCatalogNote ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiAvailableModels ??
                        '可用模型取决于 Openference 账号计划；离线模型目录不代表已获授权。',
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                initialValue: _authType,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)
                            ?.llmAuthenticationMethodLabel ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiAuthenticationMethod ??
                        '认证方式',
                  ),
                ),
                items: [
                  for (final type in authTypes)
                    DropdownMenuItem(
                      value: type,
                      enabled: type != 'relay' &&
                          (type != 'oauth' ||
                              connector.authTypeLimitations[type] == null),
                      child: _accountDropdownLabel(
                        _authLabel(
                          type,
                          connectorType: _connectorType,
                          l10n: AppLocalizations.of(context),
                        ),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _draftChanged = true;
                    if (_connectorType == 'bedrock' && value != _authType) {
                      _credential.clear();
                    }
                    _authType = value;
                    if (value == 'none' ||
                        value == 'relay' ||
                        value == 'aws_credential_chain') {
                      _credential.clear();
                    }
                    if (_connectorType == 'kilocode') {
                      _models.text = value == 'none'
                          ? kKiloCodeAnonymousFreeModelIds.join('\n')
                          : kPinnedKiloCodeModels.join('\n');
                    }
                  });
                },
              ),
              if (_connectorType == 'cloudflare-ai') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _cloudflareAccountId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)
                              ?.llmCloudflareAccountIdLabel ??
                          'Cloudflare Account ID',
                    ),
                    helperText: AppLocalizations.of(context)
                            ?.llmCloudflareAccountIdHint ??
                        AppLocalizations.of(context)?.llmAccountUiFindThe ??
                        '在 Cloudflare Dashboard 右侧找到 Account ID。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (_connectorType == 'kilocode')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiAPIKeys ??
                        'API Key 可添加为多个独立连接并通过模型组轮询。匿名模式只显示并调用已确认的免费模型；不会使用账号目录。',
                  ),
                ),
              if (_connectorType == 'cline' || _connectorType == 'clinepass')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiEachCline ??
                        '每个 Cline API Key 需保存为独立账号。模型目录按 Cline 或 ClinePass 分开刷新；目录本身不代表账号拥有订阅授权。',
                  ),
                ),
              if (_connectorType == 'devin-cli-agentic')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiOnlyLaunch ??
                        '仅启动官方 devin CLI。登录配置保存在此账号独立的 Stroom 应用目录；不会读取主机 Devin 登录或 API key。',
                  ),
                ),
              if (_connectorType == 'codex-app-server')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiUseThe ??
                        '使用本机 Codex CLI。请先在终端运行 codex login；Stroom 不读取或保存 CLI 登录数据。',
                  ),
                ),
              if (_connectorType == 'zcode-cli')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiUseTheNative ??
                        '使用本机 ZCode app-server 和 GLM Coding Plan。需要时请先在官方 ZCode 应用中登录；Stroom 不读取或保存 ZCode 登录数据。',
                  ),
                ),
              if (_connectorType == 'devin-cli-agentic') ...[
                TextField(
                  controller: _devinCliExecutable,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)
                              ?.llmDevinExecutablePathLabel ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiOfficialDevinCLI ??
                          '官方 Devin CLI 可执行文件绝对路径',
                    ),
                    helperText: AppLocalizations.of(context)
                            ?.llmDevinExecutablePathHelp ??
                        AppLocalizations.of(context)?.llmAccountUiCopyThe ??
                        '从 Devin 官方安装位置复制 devin 可执行文件的完整路径。',
                  ),
                  onChanged: (_) => setState(() {
                    _trustDevinCliExecutable = false;
                    _draftChanged = true;
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _trustDevinCliExecutable,
                  title: Text(
                    widget.account != null &&
                            _devinCliExecutable.text.trim() ==
                                _initialDevinCliExecutable
                        ? AppLocalizations.of(context)
                                ?.llmAccountUiRetrustCurrent ??
                            '重新信任当前 CLI 可执行文件并更新 SHA-256'
                        : AppLocalizations.of(context)?.llmAccountUiIHave ??
                            '我已从 Devin 官方渠道安装并信任此可执行文件',
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)?.llmExecutableIntegrityHint ??
                        AppLocalizations.of(context)?.llmAccountUiStroomFixes ??
                        'Stroom 固定当前文件的 SHA-256；文件改变后会拒绝启动。',
                  ),
                  onChanged: (value) => setState(() {
                    _trustDevinCliExecutable = value ?? false;
                    _draftChanged = true;
                  }),
                ),
              ],
              if (_connectorType == 'devin-cli-agentic' &&
                  widget.account != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reconnectCli,
                  title: Text(
                    AppLocalizations.of(context)?.llmDevinReauthTitle ??
                        AppLocalizations.of(context)?.llmAccountUiLogBack ??
                        '重新登录官方 Devin CLI',
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)?.llmDevinReauthSubtitle ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiReauthenticateThe ??
                        '重新认证此账号的独立 CLI 登录配置。',
                  ),
                  onChanged: (value) => setState(() {
                    _reconnectCli = value ?? false;
                    _draftChanged = true;
                  }),
                ),
              if (_authType == 'oauth' && oauthLimitation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    oauthLimitation,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_authType == 'oauth' && oauthLimitation != null)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmSupportedAuthRequired ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiPleaseSelect ??
                        '请选择受支持的认证方式后再保存此账号。',
                  ),
                ),
              if (_connectorType == 'aistudio' && _authType == 'relay')
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiTheLegacyAI ??
                        '旧版 AI Studio 网页会话连接已停用。请选择 API Key 或受支持的 OAuth 并重新授权。',
                  ),
                ),
              if (_connectorType == 'qoder' && _authType == 'oauth') ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.llmAccountUiQoderOAuth ??
                      'Qoder OAuth 需要服务管理员提供完整的 OAuth authorize、token、user-info URL 和 client credentials。授权后只将 DashScope API key 与敏感 OAuth 凭据保存在平台安全存储中；不会使用浏览器 Cookie。上游未定义 refresh grant；凭据失效时请重新授权。',
                ),
                TextField(
                  controller: _qoderAuthorizeUrl,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('QODER_OAUTH_AUTHORIZE_URL'),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _qoderTokenUrl,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('QODER_OAUTH_TOKEN_URL'),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _qoderUserInfoUrl,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('QODER_OAUTH_USER_INFO_URL'),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _oauthClientId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('QODER_OAUTH_CLIENT_ID'),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _oauthClientSecret,
                  obscureText: true,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('QODER_OAUTH_CLIENT_SECRET'),
                    helperText: AppLocalizations.of(context)
                            ?.llmKeepOAuthClientSecretHelp ??
                        AppLocalizations.of(context)?.llmAccountUiSubmitTo ??
                        '只提交到平台安全存储；留空以保留现有 OAuth client secret。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (_connectorType == 'qoder' && _authType == 'pat')
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    AppLocalizations.of(context)?.llmAccountUiEnterThe ??
                        '输入以 pt- 开头的 Qoder Personal Access Token。通过本机 qodercli 调用；仅支持文本聊天，不支持调用方 tools，响应会缓冲后返回，单次请求最多 45 秒。',
                  ),
                ),
              if (_connectorType == 'gitlab-duo' && _authType == 'oauth') ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.llmGitlabOAuthPrerequisites ??
                      'GitLab Duo OAuth 需要先在 GitLab 注册应用，并设置回调 http://localhost:20128/callback、权限 ai_features read_user。OAuth client ID 必填，client secret 按注册应用的类型填写；访问令牌会安全保存并在支持时自动刷新。PAT 可直接选择 Personal Access Token。',
                ),
                TextField(
                  controller: _oauthClientId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('GitLab Duo OAuth client ID'),
                    helperText: AppLocalizations.of(context)
                            ?.llmGitlabApplicationsHint ??
                        AppLocalizations.of(context)?.llmAccountUiGitLabUser ??
                        'GitLab 用户设置 → Applications',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _oauthClientSecret,
                  obscureText: true,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('GitLab Duo OAuth client secret'),
                    helperText: AppLocalizations.of(context)
                            ?.llmPublicOauthClientSecretHelp ??
                        AppLocalizations.of(context)?.llmAccountUiOnlySaved ??
                        '仅保存在平台安全存储；公开客户端可留空。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if ((_connectorType == 'gemini' ||
                      _connectorType == 'aistudio') &&
                  _authType == 'oauth') ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.llmGoogleOAuthPrerequisites ??
                      '此连接使用 Google Generative Language API OAuth；需要你管理的 Google Cloud 项目、已启用 Generative Language API 和配置好的 OAuth Desktop 客户端。请求会按此项目计量，不使用 Code Assist 或 AI Studio 网页登录。',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _googleCloudProjectId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('Google Cloud project ID'),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _oauthClientId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('Google OAuth Desktop client ID'),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                TextField(
                  controller: _oauthClientSecret,
                  obscureText: true,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('Google OAuth client secret'),
                    helperText: AppLocalizations.of(context)
                            ?.llmKeepOAuthClientSecretHelp ??
                        AppLocalizations.of(context)?.llmAccountUiOnlyStored ??
                        '只保存在平台安全存储中。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              const SizedBox(height: 8),
              if (_connectorType == 'ghe-copilot' && _authType == 'oauth') ...[
                Text(
                  AppLocalizations.of(context)?.llmAccountUiGitHubEnterprise ??
                      'GitHub Enterprise Cloud 或 Server 必须启用 Copilot，并允许 device OAuth。使用 HTTPS 实例地址；OAuth 应用客户端 ID 可由管理员提供，留空时使用公开客户端 ID。',
                ),
                TextField(
                  controller: _oauthClientId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      'Enterprise OAuth application client ID (optional)',
                    ),
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
                const SizedBox(height: 8),
              ],
              if (_connectorType != 'cloudflare-ai' &&
                  _connectorType != 'codex-app-server' &&
                  _connectorType != 'zcode-cli')
                TextField(
                  controller: _endpoint,
                  enabled: _connectorType != 'devin-cli-agentic' &&
                      _connectorType != 'command-code' &&
                      _connectorType != 'aihorde' &&
                      _connectorType != 'uncloseai' &&
                      _connectorType != 'qoder' &&
                      _connectorType != 'kilocode' &&
                      _connectorType != 'cline' &&
                      _connectorType != 'clinepass' &&
                      _connectorType != 'trae',
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      _isAzureConnector
                          ? 'Azure resource / Foundry host'
                          : _connectorType == 'ghe-copilot'
                              ? 'GitHub Enterprise instance HTTPS URL'
                              : _connectorType == 'cline' ||
                                      _connectorType == 'clinepass'
                                  ? AppLocalizations.of(context)
                                          ?.llmAccountUiClineUses ??
                                      'Cline 使用固定服务端点'
                                  : _connectorType == 'aihorde'
                                      ? AppLocalizations.of(context)
                                              ?.llmAccountUiAIHorde ??
                                          'AI Horde 使用固定 HTTPS Chat 端点'
                                      : _connectorType == 'uncloseai'
                                          ? AppLocalizations.of(context)
                                                  ?.llmAccountUiUncloseAIUses ??
                                              'UncloseAI 使用固定 OpenAI Chat Completions 端点'
                                          : _connectorType == 'kilocode'
                                              ? AppLocalizations.of(context)
                                                      ?.llmAccountUiKiloCodeUses ??
                                                  'Kilo Code 使用固定服务端点'
                                              : _connectorType == 'qoder' ||
                                                      _connectorType == 'trae'
                                                  ? AppLocalizations.of(context)
                                                          ?.llmAccountUiFixedService ??
                                                      '固定服务端点'
                                                  : AppLocalizations.of(context)
                                                          ?.llmAccountUiEndpointAddress ??
                                                      '端点地址（连接器需要时填写）',
                    ),
                    hintText: _isAzureConnector
                        ? 'https://resource.openai.azure.com'
                        : switch (_connectorType) {
                            'aihorde' => 'https://oai.aihorde.net/v1',
                            'uncloseai' => 'https://hermes.ai.unturf.com/v1',
                            'opencode-go' => 'https://opencode.ai/zen/go/v1',
                            'opencode-zen' => 'https://opencode.ai/zen/v1',
                            'command-code' => kCommandCodeBaseUrl,
                            'ghe-copilot' => 'https://github.example.com',
                            _ => 'https://api.example.com/v1',
                          },
                    helperText: _isAzureConnector
                        ? AppLocalizations.of(context)
                                ?.llmAccountUiEnterAzure ??
                            '输入 Azure OpenAI resource 或 Azure AI Foundry host；部署和版本分别配置。'
                        : switch (_connectorType) {
                            'opencode-go' ||
                            'opencode-zen' =>
                              AppLocalizations.of(context)
                                      ?.llmAccountUiLeaveBlank ??
                                  '留空以使用此账号类型的官方模型目录和 API 端点。',
                            'command-code' => AppLocalizations.of(context)
                                    ?.llmAccountUiFixedHTTPS ??
                                '使用 Command Code 的固定 HTTPS API 端点。',
                            'kilocode' => AppLocalizations.of(context)
                                    ?.llmAccountUiFixedHTTPSEndpoint ??
                                '使用 Kilo Code 模型网关的固定 HTTPS 端点。',
                            'cline' ||
                            'clinepass' =>
                              AppLocalizations.of(context)
                                      ?.llmAccountUiFixedHTTPSChat ??
                                  '使用 Cline 的固定 HTTPS Chat Completions 端点。',
                            'uncloseai' =>
                              AppLocalizations.of(context)?.llmAccountUiNoAPI ??
                                  '无需 API key；可选 key 仅用于身份标识。',
                            'aihorde' => AppLocalizations.of(context)
                                    ?.llmAccountUiAIHordeS ??
                                'AI Horde 的匿名键或优先级 API Key 仅发送到其固定聊天服务端点。',
                            'trae' => AppLocalizations.of(context)
                                    ?.llmTraeTokenSecurity ??
                                AppLocalizations.of(context)
                                    ?.llmAccountUiSOLOUses ??
                                'SOLO 使用固定的 Trae 服务端点；仅将 Cloud-IDE-JWT 发送到该端点。粘贴令牌约 14 天后需重新输入。',
                            _ => null,
                          },
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              if (_isAzureConnector) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _azureDeployment,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('Azure deployment ID'),
                    helperText: AppLocalizations.of(context)
                            ?.llmAzureDeploymentIdHelp ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiTheDeployment ??
                        '部署 ID 会作为该账号唯一的上游模型 ID。',
                  ),
                  onChanged: (value) {
                    _models.text = value.trim();
                    setState(() => _draftChanged = true);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _azureApiVersion,
                  decoration: InputDecoration(
                    label: _accountFieldLabel('Azure API version'),
                    helperText: AppLocalizations.of(context)
                            ?.llmAzureApiVersionHelp ??
                        AppLocalizations.of(context)?.llmAccountUiTheDefault ??
                        '默认值根据 Azure 模型目录配置。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (_connectorType == 'amazon-q' && _authType == 'oauth') ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.llmAmazonQOAuthPrerequisites ??
                      '导入 AWS Builder ID OAuth 凭据 JSON，必须包含 refresh_token；也可提供 access_token、clientId 和 clientSecret。缺少客户端凭据时，Stroom 会通过 AWS OIDC 注册客户端后刷新令牌。令牌直接写入安全存储；Stroom 不读取浏览器 Cookie。仅支持 us-east-1 与 eu-central-1。',
                ),
                TextField(
                  controller: _region,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmAmazonQRegionLabel ??
                          AppLocalizations.of(context)?.llmAccountUiAmazonQ ??
                          'Amazon Q Developer 区域',
                    ),
                    hintText: 'us-east-1',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (_connectorType == 'bedrock' ||
                  {'vertex', 'vertex-partner'}.contains(_connectorType)) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _region,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      _connectorType == 'bedrock'
                          ? AppLocalizations.of(context)
                                  ?.llmAccountUiAWSRegion ??
                              'AWS 区域'
                          : AppLocalizations.of(context)
                                  ?.llmAccountUiVertexArea ??
                              'Vertex 区域',
                    ),
                    hintText: _connectorType == 'bedrock'
                        ? 'us-east-1'
                        : 'us-central1',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (_connectorType == 'qwen-cloud') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _region,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmQwenCloudRegionLabel ??
                          AppLocalizations.of(context)?.llmAccountUiQwenCloud ??
                          'Qwen Cloud 区域 ID',
                    ),
                    hintText: 'ap-southeast-1',
                    helperText: AppLocalizations.of(context)
                            ?.llmQwenCloudRegionHelp ??
                        'API Key 与区域绑定；支持 ap-southeast-1、cn-beijing、eu-central-1、cn-hongkong、ap-northeast-1、us-east-1。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if ({'vertex', 'vertex-partner'}.contains(_connectorType)) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _projectId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)
                              ?.llmGoogleCloudProjectLabel ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiGoogleCloud ??
                          'Google Cloud 项目 ID',
                    ),
                    helperText: _connectorType == 'vertex-partner'
                        ? AppLocalizations.of(context)
                                ?.llmAccountUiThePartner ??
                            '伙伴模型需要项目 ID；服务账号可从 JSON 的 project_id 自动读取。'
                        : AppLocalizations.of(context)?.llmAccountUiCanBe ??
                            '可留空以使用服务账号 JSON 中的 project_id。',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (!(_authType == 'oauth' &&
                  (oauthLimitation != null || _connectorType == 'qoder'))) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _credential,
                  enabled: _authType != 'none' &&
                      _authType != 'relay' &&
                      _authType != 'cli_session' &&
                      _authType != 'aws_credential_chain',
                  obscureText: true,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      _connectorType == 'amazon-q' && _authType == 'oauth'
                          ? AppLocalizations.of(context)
                                  ?.llmAccountUiAWSBuilder ??
                              'AWS Builder ID OAuth 凭据 JSON'
                          : _authType == 'none' ||
                                  _authType == 'relay' ||
                                  _authType == 'cli_session' ||
                                  _authType == 'aws_credential_chain'
                              ? AppLocalizations.of(context)
                                      ?.llmAccountUiThisAuthentication ??
                                  '该认证方式无需输入凭据'
                              : _connectorType == 'bedrock' &&
                                      _authType == 'aws_credentials'
                                  ? AppLocalizations.of(context)
                                          ?.llmAccountUiAWSCredentials ??
                                      'AWS 凭据 JSON'
                                  : _connectorType == 'bedrock' &&
                                          _authType == 'api_key'
                                      ? 'Amazon Bedrock API Key'
                                      : _connectorType == 'vertex' &&
                                              _authType == 'service_account'
                                          ? AppLocalizations.of(context)
                                                  ?.llmAccountUiServiceAccount ??
                                              '服务账号 JSON'
                                          : _authType == 'setup_token'
                                              ? 'Claude Setup Token'
                                              : _authType == 'api_key'
                                                  ? switch (_connectorType) {
                                                      'cursor' =>
                                                        'Cursor User API Key',
                                                      'cloudflare-ai' =>
                                                        'Cloudflare API Token',
                                                      'azure-ai' ||
                                                      'azure-openai' =>
                                                        'Azure API Key',
                                                      'aihorde' => AppLocalizations
                                                                  .of(context)
                                                              ?.llmAccountUiAIHordeAPI ??
                                                          'AI Horde API Key（可选优先级）',
                                                      'glm-cn' =>
                                                        'GLM Coding (China) API Key',
                                                      'minimax-cn' =>
                                                        'MiniMax (China) API Key',
                                                      'opencode-go' =>
                                                        'OpenCode Go API Key',
                                                      'opencode-zen' =>
                                                        'OpenCode Zen API Key',
                                                      'qwen-cloud' =>
                                                        'Qwen Cloud API Key',
                                                      'qwen-cloud-token-plan' =>
                                                        'Qwen Cloud Token Plan API Key',
                                                      _ => AppLocalizations.of(
                                                                  context)
                                                              ?.llmAccountUiCredentialsText ??
                                                          '凭据',
                                                    }
                                                  : _connectorType == 'qoder' &&
                                                          _authType == 'pat'
                                                      ? 'Qoder PAT（pt-…）'
                                                      : _connectorType == 'trae'
                                                          ? 'Trae Cloud-IDE-JWT'
                                                          : AppLocalizations.of(
                                                                      context)
                                                                  ?.llmAccountUiCredentialsText ??
                                                              '凭据',
                    ),
                    helperText: _connectorType == 'trae'
                        ? AppLocalizations.of(context)?.llmAccountUiPasteThe ??
                            '粘贴 JWT 本身或完整的 “Cloud-IDE-JWT <token>” 请求头值。导入令牌不会自动刷新；应用内 Trae 登录的凭据会在到期时自动刷新。'
                        : _connectorType == 'cursor' && _authType == 'api_key'
                            ? AppLocalizations.of(context)
                                    ?.llmAccountUiGetThe ??
                                '从 cursor.com/dashboard/api 获取 User API Key（crsr_… 或 grok_…）。不会读取 Cursor IDE 登录。'
                            : _connectorType == 'aihorde' &&
                                    _authType == 'api_key'
                                ? AppLocalizations.of(context)
                                        ?.llmAccountUiTheOptional ??
                                    '可选的 AI Horde API Key 只提高排队优先级（kudos），不会增加模型权限。选择“无认证”即可使用匿名模式。'
                                : null,
                    hintText: _connectorType == 'trae'
                        ? 'Cloud-IDE-JWT eyJ…'
                        : _authType == 'aws_credential_chain'
                            ? AppLocalizations.of(context)
                                    ?.llmAccountUiUsingThe ??
                                '使用运行环境的 AWS 默认凭据链'
                            : !widget.hasCredential
                                ? AppLocalizations.of(context)
                                        ?.llmAccountUiSavedIn ??
                                    '保存在平台安全存储中'
                                : AppLocalizations.of(context)
                                        ?.llmAccountUiLeaveBlankTo ??
                                    '留空以保留当前安全凭据',
                  ),
                  onChanged: (_) => setState(() => _draftChanged = true),
                ),
              ],
              if (_hasApiProtocolSelection) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor: StroomMenuStyle.surface(context),
                  borderRadius: StroomMenuStyle.borderRadius,
                  isExpanded: true,
                  initialValue: _apiProtocol,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)
                              ?.llmDefaultApiProtocolLabel ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiDefaultAPI ??
                          '默认 API 协议',
                    ),
                  ),
                  items: [
                    for (final protocol in _accountApiProtocolOptions)
                      DropdownMenuItem(
                        value: protocol,
                        child: _accountDropdownLabel(
                          apiProtocolLabels[protocol] ?? protocol,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _apiProtocol = value;
                      _draftChanged = true;
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<AiGatewayAccountStatus>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                initialValue: _status,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmConnectionStatusLabel ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiConnectionStatusText ??
                        '连接状态',
                  ),
                ),
                items: [
                  for (final status in AiGatewayAccountStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: _accountDropdownLabel(
                        _statusLabel(status, AppLocalizations.of(context)),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _draftChanged = true;
                      _status = value;
                    });
                  }
                },
              ),
              if (_hasApiProtocolSelection && commandCodeModels.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor: StroomMenuStyle.surface(context),
                  borderRadius: StroomMenuStyle.borderRadius,
                  isExpanded: true,
                  initialValue: _selectedCommandCodeModelId,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmConfigureModelLabel ??
                          AppLocalizations.of(context)?.llmAccountUiModelTo ??
                          '要配置的模型',
                    ),
                  ),
                  items: [
                    for (final model in commandCodeModels)
                      DropdownMenuItem(
                        value: model.upstreamModelId,
                        child: _accountDropdownLabel(model.displayName),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _selectCommandCodeModel(value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor: StroomMenuStyle.surface(context),
                  borderRadius: StroomMenuStyle.borderRadius,
                  isExpanded: true,
                  initialValue: selectedCommandCodeProtocol,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmModelApiProtocolLabel ??
                          AppLocalizations.of(context)?.llmAccountUiModelAPI ??
                          '模型 API 协议',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: _accountDropdownLabel(
                        AppLocalizations.of(context)
                                ?.llmAccountUiInheritAccount ??
                            '继承账号默认协议',
                      ),
                    ),
                    for (final protocol in commandCodeProtocols)
                      DropdownMenuItem(
                        value: protocol,
                        child: _accountDropdownLabel(
                          apiProtocolLabels[protocol] ?? protocol,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _setCommandCodeModelProtocol(value);
                  },
                ),
              ],
              const SizedBox(height: 8),
              if (!_isAzureConnector)
                TextField(
                  controller: _models,
                  minLines: 3,
                  maxLines: 7,
                  readOnly: _connectorType == 'cloudflare-ai' ||
                      _connectorType == 'codex-app-server' ||
                      _connectorType == 'devin-cli-agentic' ||
                      _connectorType == 'kimi-coding' ||
                      _connectorType == 'kilocode' ||
                      _connectorType == 'grok-cli' ||
                      _connectorType == 'xai-oauth' ||
                      _connectorType == 'muse-code' ||
                      _connectorType == 'command-code' ||
                      _connectorType == 'cline' ||
                      _connectorType == 'clinepass' ||
                      _connectorType == 'trae',
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)
                              ?.llmUpstreamModelsCapabilitiesLabel ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiUpstreamModels ??
                          '上游模型与能力',
                    ),
                    hintText: AppLocalizations.of(context)
                            ?.llmModelCapabilitiesInputHint ??
                        AppLocalizations.of(context)?.llmAccountUiOnePer ??
                        '每行一个：模型 ID,streaming,vision,tools',
                    helperText: _connectorType == 'cloudflare-ai'
                        ? AppLocalizations.of(context)?.llmAccountUiModelID ??
                            '模型 ID 和上下文长度来自固定目录；其他能力保持未知。'
                        : _connectorType == 'kilocode'
                            ? _authType == 'none'
                                ? AppLocalizations.of(context)?.llmAccountUiAnonymousMode ??
                                    '匿名模式只允许 openrouter/free。连接账号后可使用该账号目录中的模型。'
                                : AppLocalizations.of(context)?.llmAccountUiModelsCome ??
                                    '模型来自 Kilo Code 目录；API Key 和设备 OAuth 使用各自保存的凭据。'
                            : _connectorType == 'command-code'
                                ? AppLocalizations.of(context)
                                        ?.llmAccountUiModelsAndCapabilities ??
                                    '模型和能力来自上游目录；在上方为每个模型选择其声明支持的 API 协议。'
                                : _connectorType == 'devin-cli-agentic'
                                    ? AppLocalizations.of(context)?.llmAccountUiACPDoes ??
                                        'ACP 未提供稳定的模型目录；使用官方 CLI 当前默认模型。'
                                    : _connectorType == 'kimi-coding'
                                        ? AppLocalizations.of(context)
                                                ?.llmAccountUiKimiCodeCLI ??
                                            'Kimi Code CLI 仅开放已验证的 Coding Plan 模型目录。'
                                        : _connectorType == 'grok-cli'
                                            ? AppLocalizations.of(context)
                                                    ?.llmAccountUiGrokBuild ??
                                                'Grok Build 仅开放已验证的订阅模型目录。'
                                            : _connectorType == 'xai-oauth'
                                                ? AppLocalizations.of(context)
                                                        ?.llmAccountUiXAIOAuth ??
                                                    'xAI OAuth 仅开放该账号从 API 获取的模型目录。'
                                                : _connectorType == 'muse-code'
                                                    ? AppLocalizations.of(context)
                                                            ?.llmAccountUiMetaMuseOAuth ??
                                                        'Meta Muse OAuth 仅开放该订阅账号从 API 获取的模型目录。'
                                                    : _connectorType == 'cline' ||
                                                            _connectorType ==
                                                                'clinepass'
                                                        ? AppLocalizations.of(context)?.llmAccountUiModelsComeFrom ??
                                                            '模型来自 Cline 的 Chat Completions 目录；可用性由对应账号和订阅决定。'
                                                        : AppLocalizations.of(context)
                                                                ?.llmAccountUiTheAbility ??
                                                            '能力为显式声明；用 vision=false 显式禁用，未填写保持未知。',
                  ),
                  onChanged: _connectorType == 'devin-cli-agentic' ||
                          _connectorType == 'kimi-coding' ||
                          _connectorType == 'kilocode' ||
                          _connectorType == 'grok-cli' ||
                          _connectorType == 'xai-oauth' ||
                          _connectorType == 'muse-code' ||
                          _connectorType == 'cline' ||
                          _connectorType == 'clinepass' ||
                          _connectorType == 'trae'
                      ? null
                      : (_) => setState(() => _draftChanged = true),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.account != null &&
                          !_draftChanged &&
                          !{
                            'kimi-coding',
                            'devin-cli-agentic',
                          }.contains(_connectorType)
                      ? _discoverModels
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    AppLocalizations.of(context)?.llmRefreshModelCatalog ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiRefreshModel ??
                        '刷新模型目录',
                  ),
                ),
              ),
              if (_connectorType == 'auggie')
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: widget.account != null && !_draftChanged
                        ? _testAuggieCli
                        : null,
                    icon: const Icon(Icons.terminal),
                    label: Text(
                      AppLocalizations.of(context)?.llmTestLocalCli('Auggie') ??
                          AppLocalizations.of(context)?.llmAccountUiTestThe ??
                          '测试本地 Auggie CLI',
                    ),
                  ),
                ),
              if (_connectorType == 'codex-app-server')
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: widget.account != null && !_draftChanged
                        ? _testCodexAppServer
                        : null,
                    icon: const Icon(Icons.terminal),
                    label: Text(
                      AppLocalizations.of(context)?.llmCheckLocalCodexCli ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiCheckLocal ??
                          '检查本地 Codex CLI 登录状态',
                    ),
                  ),
                ),
              if (widget.account == null || _draftChanged)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppLocalizations.of(context)?.llmSaveBeforeModelRefresh ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiTheModelDirectory ??
                        '保存账号和修改后可刷新模型目录。',
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
        ),
        if (widget.account != null &&
            _authType == 'oauth' &&
            oauthLimitation == null)
          OutlinedButton(
            onPressed: () => _saveSafely(reconnectOAuth: true),
            child: Text(AppLocalizations.of(context)?.llmReauthorize ?? '重新授权'),
          ),
        FilledButton(
          onPressed: _saveSafely,
          child: Text(AppLocalizations.of(context)?.llmSave ?? '保存'),
        ),
      ],
    );
  }

  Future<void> _discoverModels() async {
    if (widget.account == null || _draftChanged) return;
    try {
      final models = await widget.modelDiscovery.discoverModels(
        widget.account!,
        refreshRemote: true,
      );
      if (!mounted) return;
      setState(() {
        _discoveredModels = models;
        if (!models.any(
          (model) => model.upstreamModelId == _selectedCommandCodeModelId,
        )) {
          final firstModel = models.firstOrNull;
          _selectedCommandCodeModelId = firstModel?.upstreamModelId;
          final override = firstModel?.config['apiProtocolOverride'];
          _commandCodeModelProtocol = override is String ? override : '';
        }
        _models.text = models
            .map(
              (model) => [
                model.upstreamModelId,
                ...model.capabilities.entries
                    .where((entry) => entry.value is bool)
                    .map(
                      (entry) => entry.value == true
                          ? entry.key
                          : '${entry.key}=false',
                    ),
                if ({
                      'command-code',
                      'openai-compatibility',
                    }.contains(_connectorType) &&
                    model.config['apiProtocolOverride'] is String)
                  'apiProtocolOverride=${model.config['apiProtocolOverride']}',
              ].join(','),
            )
            .join('\n');
        _draftChanged = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _connectorType == 'auggie'
            ? AppLocalizations.of(context)?.llmAccountUiAuggieCLI ??
                'Auggie CLI model list 未返回目录；已保留固定模型目录。'
            : _connectorType == 'vertex-partner'
                ? AppLocalizations.of(context)?.llmAccountUiVertexAI ??
                    'Vertex AI Partners 需要有效的 Google Cloud 项目和有权限的服务账号；Express API Key 仅支持 Gemini。'
                : AppLocalizations.of(context)?.llmAccountUiFailedTo ??
                    '模型目录读取失败，请检查账号认证和连接设置。',
      );
    }
  }

  Future<void> _testAuggieCli() async {
    final account = widget.account;
    if (account == null || _draftChanged) return;
    try {
      await widget.modelDiscovery.testConnection(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.llmCliReady('Auggie') ??
                AppLocalizations.of(context)?.llmAccountUiAuggieCLIIs ??
                'Auggie CLI 已安装并可运行。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _testCodexAppServer() async {
    final account = widget.account;
    if (account == null || _draftChanged) return;
    try {
      await widget.modelDiscovery.testConnection(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.llmCodexCliReady ??
                AppLocalizations.of(context)?.llmAccountUiCodexCLI ??
                'Codex CLI 已登录并可运行。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _saveSafely({bool reconnectOAuth = false}) {
    _save(reconnectOAuth: reconnectOAuth).catchError((_) {
      if (!mounted) return;
      setState(
        () => _error = _connectorType == 'vertex-partner'
            ? AppLocalizations.of(context)?.llmAccountUiVertexAIPartners ??
                'Vertex AI Partners 需要有效项目 ID；服务账号可从 JSON 读取，API Key 必须绑定项目。'
            : AppLocalizations.of(context)?.llmAccountUiFailedToSave ??
                '保存账号失败，请检查连接设置后重试。',
      );
    });
  }

  Future<void> _connectTraeSolo() async {
    LlmOAuthLoopback? loopback;
    try {
      loopback = await LlmOAuthLoopback.bind('/authorize');
      final state = List<int>.generate(
        32,
        (_) => math.Random.secure().nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final callback = loopback.nextCallback().timeout(
            const Duration(minutes: 5),
          );
      final authorizationUri = TraeSoloConnector.authorizationUri(
        loopback.redirectUri,
        state,
      );
      if (!mounted) return;
      final callbackUri = await Navigator.of(context).push<Uri>(
        MaterialPageRoute<Uri>(
          builder: (_) => TraeSoloAuthorizationPage(
            authorizationUri: authorizationUri,
            callback: callback,
          ),
        ),
      );
      if (callbackUri == null) return;
      final credential = TraeSoloCredential.fromCallbackUri(
        callbackUri,
        expectedState: state,
      );
      await loopback.respond(accepted: true);
      if (!mounted) return;
      final storedCredential = credential.toStoredValue();
      setState(() {
        _authType = 'session_token';
        _validatedTraeCallbackCredential = storedCredential;
        _credential.text = storedCredential;
        _draftChanged = true;
        _error = null;
      });
    } catch (_) {
      await loopback?.respond(accepted: false);
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context)?.llmAccountUiTraeThe ??
            'Trae 登录未完成，请重试或使用 Cloud-IDE-JWT 手动导入。',
      );
    } finally {
      await loopback?.close();
    }
  }

  Future<void> _save({bool reconnectOAuth = false}) async {
    final accountName = _name.text.trim();
    if (accountName.isEmpty) {
      setState(
        () => _error =
            AppLocalizations.of(context)?.llmAccountUiPleaseEnter ?? '请输入账号名称。',
      );
      return;
    }
    final connector = widget.providerCatalog.findProvider(_connectorType)!;
    if (_connectorType == 'cursor' && _authType == 'api_key') {
      final candidate = _credential.text.trim();
      final retainingExistingKey = candidate.isEmpty &&
          widget.hasCredential &&
          widget.account?.connectorType == 'cursor' &&
          widget.account?.authType == 'api_key';
      if (!retainingExistingKey &&
          !(candidate.startsWith('crsr_') || candidate.startsWith('grok_'))) {
        setState(
          () => _error =
              AppLocalizations.of(context)?.llmAccountUiPleaseEnterThe ??
                  '请输入以 crsr_ 开头的 Cursor User API Key。',
        );
        return;
      }
    }
    final oauthLimitation = connector.authTypeLimitations['oauth'];
    final previousGoogleClientId = widget.account?.endpointConfig['clientId'];
    final isGoogleGenerativeLanguageAccount =
        _connectorType == 'gemini' || _connectorType == 'aistudio';
    final wasGoogleGenerativeLanguageAccount =
        widget.account?.connectorType == 'gemini' ||
            widget.account?.connectorType == 'aistudio';
    final geminiOAuthClientChanged = wasGoogleGenerativeLanguageAccount &&
        widget.account?.authType == 'oauth' &&
        isGoogleGenerativeLanguageAccount &&
        _authType == 'oauth' &&
        previousGoogleClientId != _oauthClientId.text.trim();
    final geminiOAuthClientSecretChanged = wasGoogleGenerativeLanguageAccount &&
        widget.account?.authType == 'oauth' &&
        isGoogleGenerativeLanguageAccount &&
        _authType == 'oauth' &&
        _oauthClientSecret.text.trim().isNotEmpty;
    final qoderOAuthConfigurationChanged =
        widget.account?.connectorType == 'qoder' &&
            widget.account?.authType == 'oauth' &&
            _connectorType == 'qoder' &&
            _authType == 'oauth' &&
            (widget.account!.endpointConfig['qoderLoginUrl'] !=
                    _qoderAuthorizeUrl.text.trim() ||
                widget.account!.endpointConfig['qoderExchangeUrl'] !=
                    _qoderTokenUrl.text.trim() ||
                widget.account!.endpointConfig['qoderUserInfoUrl'] !=
                    _qoderUserInfoUrl.text.trim() ||
                widget.account!.endpointConfig['qoderClientId'] !=
                    _oauthClientId.text.trim() ||
                _oauthClientSecret.text.trim().isNotEmpty);
    final qoderOAuthClientChanged = widget.account?.connectorType == 'qoder' &&
        widget.account?.authType == 'oauth' &&
        widget.account!.endpointConfig['qoderClientId'] !=
            _oauthClientId.text.trim();
    final gitLabOAuthConfigurationChanged = widget.account?.connectorType ==
            'gitlab-duo' &&
        widget.account?.authType == 'oauth' &&
        _connectorType == 'gitlab-duo' &&
        _authType == 'oauth' &&
        (widget.account!.endpointConfig['baseUrl'] != _endpoint.text.trim() ||
            widget.account!.endpointConfig['clientId'] !=
                _oauthClientId.text.trim() ||
            _oauthClientSecret.text.trim().isNotEmpty);
    final gheOAuthConfigurationChanged = widget.account?.connectorType ==
            'ghe-copilot' &&
        widget.account?.authType == 'oauth' &&
        _connectorType == 'ghe-copilot' &&
        _authType == 'oauth' &&
        (widget.account!.endpointConfig['gheUrl'] != _endpoint.text.trim() ||
            widget.account!.endpointConfig['copilotClientId'] !=
                _oauthClientId.text.trim());
    final providerPresetIdentityChanged = widget.account != null &&
        _connectorType == 'openai-compatibility' &&
        widget.account!.endpointConfig['providerPresetId'] != _providerPresetId;
    final credentialIdentityChanged = widget.account != null &&
        (widget.account!.connectorType != _connectorType ||
            widget.account!.authType != _authType ||
            providerPresetIdentityChanged ||
            geminiOAuthClientChanged ||
            geminiOAuthClientSecretChanged ||
            qoderOAuthConfigurationChanged ||
            gitLabOAuthConfigurationChanged ||
            gheOAuthConfigurationChanged);
    if (_connectorType == 'gitlab-duo' &&
        _authType == 'oauth' &&
        _oauthClientId.text.trim().isEmpty) {
      setState(
        () => _error =
            AppLocalizations.of(context)?.llmAccountUiPleaseEnterYour ??
                '请输入 GitLab Duo OAuth client ID。',
      );
      return;
    }
    if (_connectorType == 'qoder' && _authType == 'oauth') {
      try {
        for (final value in [
          _qoderAuthorizeUrl.text,
          _qoderTokenUrl.text,
          _qoderUserInfoUrl.text,
        ]) {
          LlmOAuthAuthorizationAttempt.validateQoderOAuthEndpoint(value);
        }
      } catch (_) {
        setState(
          () => _error =
              AppLocalizations.of(context)?.llmAccountUiPleaseEnterA ??
                  '请输入有效的 HTTPS Qoder OAuth 管理员端点。',
        );
        return;
      }
      final needsSecret = widget.account == null ||
          widget.account?.authType != 'oauth' ||
          !widget.hasCredential ||
          qoderOAuthClientChanged ||
          _oauthClientSecret.text.trim().isNotEmpty;
      if (_oauthClientId.text.trim().isEmpty ||
          (needsSecret && _oauthClientSecret.text.trim().isEmpty)) {
        setState(
          () => _error =
              AppLocalizations.of(context)?.llmAccountUiPleaseEnterQODER ??
                  '请输入 QODER_OAUTH_CLIENT_ID 和 client secret。',
        );
        return;
      }
    }
    if (_authType == 'oauth' && oauthLimitation != null) {
      setState(
        () => _error = AppLocalizations.of(context)
                ?.llmOAuthLimitationSaveMessage(oauthLimitation) ??
            '$oauthLimitation\n请选择受支持的认证方式后再保存此账号。',
      );
      return;
    }
    final id = widget.account?.id ?? const Uuid().v4();
    final previousModels =
        widget.account?.models ?? const <AiGatewayUpstreamModel>[];
    final azureDeploymentId = _azureDeployment.text.trim();
    final azureApiVersion = _azureApiVersion.text.trim();
    if (_isAzureConnector) {
      try {
        AzureOpenAiEndpoint.chatCompletionsUri(
          resourceUrl: _endpoint.text.trim(),
          deploymentId: azureDeploymentId,
          apiVersion: azureApiVersion,
        );
      } on FormatException {
        setState(
          () => _error = AppLocalizations.of(context)
                  ?.llmAccountUiPleaseEnterAValid ??
              '请输入有效的 Azure HTTPS resource host、deployment ID 和 API version。',
        );
        return;
      }
      // Azure deployments are the source model IDs; there is no public model
      // catalog to infer or substitute here.
      _models.text = azureDeploymentId;
    }
    final selectedModelPreset = findLlmOpenAiProviderPreset(_providerPresetId);
    final existingModelsByUpstream = <String, List<AiGatewayUpstreamModel>>{};
    for (final model in previousModels) {
      existingModelsByUpstream
          .putIfAbsent(model.upstreamModelId, () => <AiGatewayUpstreamModel>[])
          .add(model);
    }
    final modelLines = <List<String>>[];
    for (final line in _models.text.split('\n')) {
      final parts = line.split(',').map((part) => part.trim()).toList();
      if (parts.isNotEmpty && parts.first.isNotEmpty) modelLines.add(parts);
    }
    if (_connectorType == 'cloudflare-ai') {
      try {
        CloudflareWorkersAiConnector.buildChatCompletionsUri(
          _cloudflareAccountId.text,
        );
      } on ArgumentError {
        setState(
          () => _error = AppLocalizations.of(context)
                  ?.llmAccountUiPleaseEnterAValidCloudflare ??
              '请输入有效的 Cloudflare Account ID。',
        );
        return;
      }
      if (modelLines.any(
        (parts) => !kCloudflareWorkersAiModelIds.contains(parts.first),
      )) {
        setState(
          () => _error =
              AppLocalizations.of(context)?.llmAccountUiCloudflareWorkers ??
                  'Cloudflare Workers AI 仅提供已验证的固定模型目录。',
        );
        return;
      }
    }
    if (_connectorType == 'kimi-coding' &&
        modelLines.any(
          (parts) => !kPinnedKimiCodeModels.contains(parts.first),
        )) {
      setState(
        () => _error =
            AppLocalizations.of(context)?.llmAccountUiKimiCodeAccounts ??
                'Kimi Code 账号只能使用已验证的 Coding Plan 模型。',
      );
      return;
    }
    final existingByLine = <int, AiGatewayUpstreamModel>{};
    final usedModelIds = <String>{};
    for (var index = 0; index < modelLines.length; index++) {
      final exact = existingModelsByUpstream[modelLines[index].first]
          ?.where((model) => !usedModelIds.contains(model.id))
          .firstOrNull;
      if (exact == null) continue;
      existingByLine[index] = exact;
      usedModelIds.add(exact.id);
    }
    final parsedModels = <AiGatewayUpstreamModel>[];
    for (var index = 0; index < modelLines.length; index++) {
      final parts = modelLines[index];
      final upstreamId = parts.first;
      var existing = existingByLine[index];
      final refreshPresetModel = selectedModelPreset != null &&
          providerPresetIdentityChanged &&
          selectedModelPreset.fallbackModels.any(
            (model) =>
                '${selectedModelPreset.modelIdPrefix}${model.id}' == upstreamId,
          );
      if (existing == null &&
          !providerPresetIdentityChanged &&
          index < previousModels.length &&
          !usedModelIds.contains(previousModels[index].id)) {
        existing = previousModels[index];
        usedModelIds.add(existing.id);
      }
      if (existing == null) {
        existing = _discoveredModels
            .where((model) => model.upstreamModelId == upstreamId)
            .firstOrNull;
        if (existing != null) usedModelIds.add(existing.id);
      }
      final refreshedPresetModel = refreshPresetModel
          ? _discoveredModels
              .where((model) => model.upstreamModelId == upstreamId)
              .firstOrNull
          : null;
      final capabilities = <String, dynamic>{
        if (refreshedPresetModel != null)
          ...refreshedPresetModel.capabilities
        else if (existing != null)
          for (final entry in existing.capabilities.entries)
            if (entry.value is! bool) entry.key: entry.value,
      };
      if (_connectorType == 'openai-compatibility' &&
          _providerPresetId == 'agentrouter') {
        capabilities['supportedApiProtocols'] = _accountApiProtocolOptions;
      }
      if (_connectorType == 'vertex-partner') {
        final isClaude = upstreamId.toLowerCase().startsWith('claude-');
        capabilities
          ..['chat'] = true
          ..['streaming'] = true
          ..['supportedApiProtocols'] = [
            isClaude ? 'anthropic.messages' : 'openai.chat_completions',
          ];
      }
      if (_isAzureConnector) {
        capabilities
          ..['chat'] = true
          ..['streaming'] = true
          ..['supportedApiProtocols'] = ['openai.chat_completions'];
      }
      String? apiProtocolOverride;
      for (final declaration
          in parts.skip(1).where((part) => part.isNotEmpty)) {
        final separator = declaration.indexOf('=');
        final capability = separator < 0
            ? declaration
            : declaration.substring(0, separator).trim();
        if (capability.isEmpty) continue;
        final value = separator < 0
            ? 'true'
            : declaration.substring(separator + 1).trim().toLowerCase();
        if (capability == 'apiProtocolOverride') {
          if (!{
            'command-code',
            'openai-compatibility',
            'vertex-partner',
          }.contains(_connectorType)) {
            continue;
          }
          final declaredProtocols = capabilities['supportedApiProtocols'];
          final supportedProtocols = _connectorType == 'openai-compatibility' &&
                  _providerPresetId == 'agentrouter'
              ? _accountApiProtocolOptions
              : declaredProtocols;
          if (!kCustomHttpApiProtocols.contains(value) ||
              (supportedProtocols is Iterable &&
                  !supportedProtocols.whereType<String>().contains(value))) {
            setState(
              () => _error =
                  AppLocalizations.of(context)?.llmAccountUiPleaseRefresh ??
                      '请先刷新该模型目录，并选择其 supportedApiProtocols 中的协议。',
            );
            return;
          }
          apiProtocolOverride = value;
          continue;
        }
        if (value != 'true' && value != 'false') {
          setState(
            () => _error =
                AppLocalizations.of(context)?.llmAccountUiAbilityValues ??
                    '能力值只能是 true 或 false。',
          );
          return;
        }
        if (_connectorType == 'command-code') {
          final declared = existing?.capabilities[capability];
          if (declared is! bool || declared != (value == 'true')) {
            setState(
              () => _error =
                  AppLocalizations.of(context)?.llmAccountUiCommandCode ??
                      'Command Code 模型能力只能由上游目录声明。',
            );
            return;
          }
          capabilities[capability] = declared;
          continue;
        }
        capabilities[capability] = value == 'true';
      }
      var newModelId = '$id:model:$index';
      var suffix = index;
      while (existing == null &&
          (usedModelIds.contains(newModelId) ||
              previousModels.any((model) => model.id == newModelId))) {
        newModelId = '$id:model:${++suffix}';
      }
      if (existing == null) usedModelIds.add(newModelId);
      final modelConfig = Map<String, dynamic>.from(
        existing?.config ?? const {},
      );
      if (refreshedPresetModel != null) {
        final retainedApiProtocolOverride = modelConfig['apiProtocolOverride'];
        final retainedOverrideSource = modelConfig['apiProtocolOverrideSource'];
        modelConfig.remove('catalogSource');
        modelConfig
          ..remove('apiProtocolOverride')
          ..remove('apiProtocolOverrideSource');
        modelConfig.addAll(refreshedPresetModel.config);
        if (retainedApiProtocolOverride != null &&
            retainedOverrideSource != 'provider-preset-default') {
          modelConfig
            ..['apiProtocolOverride'] = retainedApiProtocolOverride
            ..remove('apiProtocolOverrideSource');
        }
      } else if (providerPresetIdentityChanged &&
          modelConfig['apiProtocolOverrideSource'] ==
              'provider-preset-default') {
        modelConfig
          ..remove('apiProtocolOverride')
          ..remove('apiProtocolOverrideSource');
      }
      if (_isAzureConnector) {
        modelConfig['catalogSource'] = 'configured-azure-deployment';
      }
      if (_connectorType == 'vertex-partner' &&
          upstreamId.toLowerCase().startsWith('claude-')) {
        modelConfig
          ..['apiProtocolOverride'] = 'anthropic.messages'
          ..['apiProtocolOverrideSource'] = 'provider-preset-default';
      }
      if ({'command-code', 'openai-compatibility'}.contains(_connectorType)) {
        modelConfig.remove('apiProtocolOverride');
        final selectedPresetDefaultOverride =
            refreshedPresetModel?.config['apiProtocolOverride'];
        final existingOverride = existing?.config['apiProtocolOverride'];
        final existingOverrideSource =
            existing?.config['apiProtocolOverrideSource'];
        final retainedExplicitOverride = existingOverride is String &&
            existingOverrideSource != 'provider-preset-default';
        final effectiveOverride = apiProtocolOverride ??
            (retainedExplicitOverride
                ? existingOverride
                : selectedPresetDefaultOverride is String
                    ? selectedPresetDefaultOverride
                    : null);
        if (effectiveOverride != null) {
          modelConfig['apiProtocolOverride'] = effectiveOverride;
          if (apiProtocolOverride == null &&
              !retainedExplicitOverride &&
              selectedPresetDefaultOverride is String) {
            modelConfig['apiProtocolOverrideSource'] =
                'provider-preset-default';
          } else {
            modelConfig.remove('apiProtocolOverrideSource');
          }
        }
      } else if ({
        'command-code',
        'openai-compatibility',
      }.contains(widget.account?.connectorType)) {
        modelConfig.remove('apiProtocolOverride');
      }
      parsedModels.add(
        AiGatewayUpstreamModel(
          id: existing?.id ?? newModelId,
          upstreamModelId: upstreamId,
          displayName: existing?.displayName ?? upstreamId,
          capabilities: capabilities,
          config: modelConfig,
        ),
      );
    }
    final endpoint = _endpoint.text.trim();
    final endpointConfig = Map<String, dynamic>.from(
      widget.account?.endpointConfig ?? const <String, dynamic>{},
    );
    if (_connectorType == 'cloudflare-ai') {
      endpointConfig
        ..['cloudflareAccountId'] = _cloudflareAccountId.text.trim()
        ..remove('baseUrl')
        ..remove('host')
        ..remove('apiBase');
    } else {
      endpointConfig.remove('cloudflareAccountId');
    }
    if (_isAzureConnector) {
      endpointConfig
        ..['azureDeploymentId'] = azureDeploymentId
        ..['apiVersion'] = azureApiVersion
        ..['apiProtocol'] = 'openai.chat_completions';
    } else if (_connectorType == 'auggie') {
      endpointConfig
        ..remove('baseUrl')
        ..remove('host')
        ..remove('apiBase')
        ..remove('apiProtocol');
    } else if (_connectorType == 'zcode-cli') {
      endpointConfig.clear();
    } else if (widget.account?.connectorType == 'azure-ai' ||
        widget.account?.connectorType == 'azure-openai') {
      endpointConfig
        ..remove('azureDeploymentId')
        ..remove('apiVersion')
        ..remove('apiProtocol');
    }
    if (_connectorType == 'ghe-copilot') {
      final gheUri = Uri.tryParse(endpoint);
      if (_authType == 'oauth' &&
          (gheUri == null ||
              gheUri.scheme != 'https' ||
              gheUri.host.isEmpty ||
              gheUri.userInfo.isNotEmpty ||
              gheUri.hasQuery ||
              gheUri.hasFragment)) {
        setState(
          () => _error = AppLocalizations.of(context)
                  ?.llmAccountUiPleaseEnterAValidGitHub ??
              '请输入有效的 GitHub Enterprise HTTPS 实例地址。',
        );
        return;
      }
      endpointConfig['gheUrl'] = endpoint;
      endpointConfig.remove('baseUrl');
      if (_oauthClientId.text.trim().isEmpty) {
        endpointConfig.remove('copilotClientId');
      } else {
        endpointConfig['copilotClientId'] = _oauthClientId.text.trim();
      }
    } else if (widget.account?.connectorType == 'ghe-copilot') {
      endpointConfig.remove('gheUrl');
      endpointConfig.remove('copilotClientId');
    }
    if (_connectorType == 'devin-cli-agentic') {
      final executablePath = _devinCliExecutable.text.trim();
      final previousExecutablePath =
          widget.account?.endpointConfig[DevinCliAcpLaunch.executablePathKey];
      final previousExecutableSha256 =
          widget.account?.endpointConfig[DevinCliAcpLaunch.executableSha256Key];
      if (executablePath.isEmpty) {
        setState(
          () => _error = AppLocalizations.of(context)?.llmAccountUiPleaseFill ??
              '请填写官方 Devin CLI 可执行文件的完整路径。',
        );
        return;
      }
      if (widget.account == null ||
          executablePath != previousExecutablePath ||
          previousExecutableSha256 is! String ||
          previousExecutableSha256.isEmpty ||
          _trustDevinCliExecutable) {
        if (!_trustDevinCliExecutable) {
          setState(
            () => _error =
                AppLocalizations.of(context)?.llmAccountUiPleaseConfirm ??
                    '请确认此可执行文件来自 Devin 官方安装渠道。',
          );
          return;
        }
        try {
          final approval = await DevinCliAcpLaunch.approveExecutablePath(
            executablePath,
          );
          endpointConfig[DevinCliAcpLaunch.executablePathKey] = approval.path;
          endpointConfig[DevinCliAcpLaunch.executableSha256Key] =
              approval.sha256;
        } on FileSystemException {
          setState(
            () => _error =
                AppLocalizations.of(context)?.llmAccountUiTheSelected ??
                    '所选 CLI 路径无效或不可执行。',
          );
          return;
        }
      } else {
        endpointConfig[DevinCliAcpLaunch.executablePathKey] =
            previousExecutablePath;
        endpointConfig[DevinCliAcpLaunch.executableSha256Key] =
            previousExecutableSha256;
      }
    } else {
      endpointConfig.remove(DevinCliAcpLaunch.executablePathKey);
      endpointConfig.remove(DevinCliAcpLaunch.executableSha256Key);
    }
    if (isGoogleGenerativeLanguageAccount &&
        _authType == 'oauth' &&
        _oauthClientId.text.trim().isNotEmpty) {
      endpointConfig['clientId'] = _oauthClientId.text.trim();
    }
    if (_connectorType == 'gitlab-duo' &&
        _authType == 'oauth' &&
        _oauthClientId.text.trim().isNotEmpty) {
      endpointConfig['clientId'] = _oauthClientId.text.trim();
    }
    if (isGoogleGenerativeLanguageAccount &&
        _authType == 'oauth' &&
        _googleCloudProjectId.text.trim().isNotEmpty) {
      endpointConfig['googleCloudProjectId'] =
          _googleCloudProjectId.text.trim();
    }
    if (_connectorType == 'qoder' && _authType == 'oauth') {
      endpointConfig['qoderLoginUrl'] = _qoderAuthorizeUrl.text.trim();
      endpointConfig['qoderExchangeUrl'] = _qoderTokenUrl.text.trim();
      endpointConfig['qoderUserInfoUrl'] = _qoderUserInfoUrl.text.trim();
      endpointConfig['qoderClientId'] = _oauthClientId.text.trim();
      endpointConfig.remove('baseUrl');
      endpointConfig.remove('host');
      endpointConfig.remove('apiBase');
    } else if (widget.account?.connectorType == 'qoder') {
      endpointConfig.remove('qoderLoginUrl');
      endpointConfig.remove('qoderExchangeUrl');
      endpointConfig.remove('qoderUserInfoUrl');
      endpointConfig.remove('qoderClientId');
    }
    final previousEndpoint = widget.account?.endpointConfig[
            _connectorType == 'ghe-copilot' ? 'gheUrl' : 'baseUrl'] ??
        widget.account?.endpointConfig['host'] ??
        widget.account?.endpointConfig['apiBase'];
    if (endpointConfig['legacyOcrFullEndpoint'] == true &&
        endpoint !=
            (previousEndpoint is String ? previousEndpoint.trim() : '')) {
      endpointConfig.remove('legacyOcrFullEndpoint');
    }
    if (_connectorType == 'ghe-copilot') {
      endpointConfig['gheUrl'] = endpoint;
      endpointConfig.remove('baseUrl');
      endpointConfig.remove('host');
      endpointConfig.remove('apiBase');
    } else if (_connectorType == 'trae' ||
        _connectorType == 'uncloseai' ||
        _connectorType == 'cloudflare-ai' ||
        _connectorType == 'codex-app-server') {
      endpointConfig.remove('baseUrl');
      endpointConfig.remove('host');
      endpointConfig.remove('apiBase');
      if (_connectorType == 'codex-app-server') {
        endpointConfig.remove('websocketUrl');
      }
    } else if (endpoint.isEmpty) {
      endpointConfig.remove('baseUrl');
      endpointConfig.remove('host');
      endpointConfig.remove('apiBase');
    } else {
      endpointConfig['baseUrl'] = endpoint;
    }
    if (_connectorType == 'command-code' ||
        _connectorType == 'cline' ||
        _connectorType == 'clinepass') {
      endpointConfig.remove('baseUrl');
      endpointConfig.remove('host');
      endpointConfig.remove('apiBase');
      if (_connectorType == 'command-code') {
        endpointConfig['apiProtocol'] = _apiProtocol;
      }
    } else if (_connectorType == 'openai-compatibility') {
      endpointConfig['apiProtocol'] = _apiProtocol;
    } else if (_connectorType == 'codex-app-server') {
      endpointConfig['apiProtocol'] = 'openai.responses';
    } else if (widget.account?.connectorType == 'command-code') {
      endpointConfig.remove('apiProtocol');
    }
    final selectedPreset = _connectorType == 'openai-compatibility'
        ? findLlmOpenAiProviderPreset(_providerPresetId)
        : null;
    final previousPresetId = widget.account?.endpointConfig['providerPresetId'];
    final previousPreset = findLlmOpenAiProviderPreset(
      previousPresetId is String ? previousPresetId : null,
    );
    if (selectedPreset != null) {
      final appliedPresetConfig = selectedPreset.applyToEndpointConfig(
        endpointConfig,
      );
      endpointConfig
        ..clear()
        ..addAll(appliedPresetConfig);
    } else {
      final customEndpointConfig = LlmProviderPreset.clearFromEndpointConfig(
        endpointConfig,
      );
      endpointConfig
        ..clear()
        ..addAll(customEndpointConfig);
      if (endpointConfig['modelsUrl'] == previousPreset?.modelsUrl &&
          previousPreset?.modelsUrl != null) {
        endpointConfig.remove('modelsUrl');
      }
    }
    if (_connectorType == 'bedrock') {
      endpointConfig['region'] = _region.text.trim();
      endpointConfig.remove('location');
    } else if ({'vertex', 'vertex-partner'}.contains(_connectorType)) {
      endpointConfig['location'] = _region.text.trim();
      endpointConfig.remove('region');
    } else if (_connectorType == 'qwen-cloud') {
      endpointConfig['region'] = _region.text.trim();
      endpointConfig.remove('location');
    } else {
      endpointConfig.remove('region');
      endpointConfig.remove('location');
    }
    if ({'vertex', 'vertex-partner'}.contains(_connectorType) &&
        _projectId.text.trim().isNotEmpty) {
      endpointConfig['projectId'] = _projectId.text.trim();
    } else {
      endpointConfig.remove('projectId');
    }
    final account = AiGatewayAccount(
      id: id,
      connectorType: _connectorType,
      authType: _authType,
      displayName: accountName,
      status: _status,
      hasCredential: widget.hasCredential,
      endpointConfig: endpointConfig,
      models: parsedModels,
      policy: widget.account?.policy,
      usageByWindow: widget.account?.usageByWindow,
      remainingQuota: widget.account?.remainingQuota ??
          const AiGatewayMetricObservation.unknown(),
      quotaSignals: widget.account?.quotaSignals ?? const {},
    );
    var secret = _authType == 'none' ||
            _authType == 'relay' ||
            _authType == 'aws_credential_chain'
        ? ''
        : _credential.text.trim();
    if (_connectorType == 'amazon-q' && _authType == 'oauth') {
      final region = _region.text.trim().toLowerCase();
      final retainingExistingCredential = secret.isEmpty &&
          widget.hasCredential &&
          !credentialIdentityChanged &&
          widget.account?.connectorType == 'amazon-q' &&
          widget.account?.authType == 'oauth';
      if (!retainingExistingCredential) {
        try {
          secret = jsonEncode(AmazonQConnector.parseCredentialImport(secret));
        } catch (_) {
          setState(
            () => _error = AppLocalizations.of(context)
                    ?.llmAccountUiPleaseEnterTheAmazon ??
                '请输入包含 AWS Builder ID refresh token 的 Amazon Q 凭据 JSON。',
          );
          return;
        }
      }
      if (!const {'us-east-1', 'eu-central-1'}.contains(region) ||
          (!retainingExistingCredential && secret.isEmpty)) {
        setState(
          () => _error = AppLocalizations.of(context)
                  ?.llmAccountUiPleaseEnterAValidAmazon ??
              '请输入有效的 Amazon Q OAuth 凭据 JSON 和受支持区域。',
        );
        return;
      }
      endpointConfig['region'] = region;
    }
    final requiresOAuthAuthorization = _authType == 'oauth' &&
        _connectorType != 'amazon-q' &&
        (widget.account == null || reconnectOAuth || credentialIdentityChanged);
    final oauthConfiguration = <String, String>{
      if (_oauthClientId.text.trim().isNotEmpty)
        'clientId': _oauthClientId.text.trim(),
      if (_oauthClientSecret.text.trim().isNotEmpty)
        'clientSecret': _oauthClientSecret.text.trim(),
      if (_connectorType == 'qoder') ...{
        'authorizeUrl': _qoderAuthorizeUrl.text.trim(),
        'tokenUrl': _qoderTokenUrl.text.trim(),
        'userInfoUrl': _qoderUserInfoUrl.text.trim(),
      },
      if (_connectorType == 'gitlab-duo' && _authType == 'oauth') ...{
        'clientId': _oauthClientId.text.trim(),
        if (_oauthClientSecret.text.trim().isNotEmpty)
          'clientSecret': _oauthClientSecret.text.trim(),
      },
    };
    if (_connectorType == 'aistudio' && _authType == 'relay') {
      setState(
        () => _error =
            AppLocalizations.of(context)?.llmAccountUiLegacyAIStudio ??
                '旧版 AI Studio 网页会话连接已停用，请改用 API Key 或受支持的 OAuth。',
      );
      return;
    }
    if (requiresOAuthAuthorization &&
        isGoogleGenerativeLanguageAccount &&
        (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$')
                .hasMatch(_googleCloudProjectId.text.trim()) ||
            oauthConfiguration['clientId'] == null ||
            ((widget.account == null ||
                    !wasGoogleGenerativeLanguageAccount ||
                    widget.account!.authType != 'oauth' ||
                    !widget.hasCredential ||
                    geminiOAuthClientChanged) &&
                oauthConfiguration['clientSecret'] == null))) {
      setState(
        () => _error =
            AppLocalizations.of(context)?.llmAccountUiPleaseProvide ??
                '请提供 Google OAuth Desktop client ID 和对应的 client secret。',
      );
      return;
    }
    if (_authType != 'none' &&
        _authType != 'relay' &&
        _authType != 'cli_session' &&
        _authType != 'aws_credential_chain' &&
        _authType != 'oauth' &&
        secret.isEmpty &&
        (!widget.hasCredential || credentialIdentityChanged)) {
      setState(
        () => _error = AppLocalizations.of(context)
                ?.llmAccountUiPleaseEnterYourCredentials ??
            '请输入凭据。',
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      _AccountEditResult(
        account,
        secret,
        oauthConfiguration: oauthConfiguration,
        requiresOAuthAuthorization: requiresOAuthAuthorization,
        requiresCliLogin: account.connectorType == 'devin-cli-agentic' &&
            (widget.account?.connectorType != 'devin-cli-agentic' ||
                _reconnectCli),
        traeCallbackIssued: _connectorType == 'trae' &&
            _authType == 'session_token' &&
            _validatedTraeCallbackCredential != null &&
            secret == _validatedTraeCallbackCredential,
      ),
    );
  }
}

class _ModelGroupEditorDialog extends StatefulWidget {
  final AiGatewayModelGroup group;
  final List<AiGatewayAccount> accounts;
  final AiGatewayProviderCatalog providerCatalog;

  const _ModelGroupEditorDialog({
    required this.group,
    required this.accounts,
    required this.providerCatalog,
  });

  @override
  State<_ModelGroupEditorDialog> createState() =>
      _ModelGroupEditorDialogState();
}

class _ModelGroupEditorDialogState extends State<_ModelGroupEditorDialog> {
  late final TextEditingController _name;
  late List<AiGatewayModelGroupMember> _members;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.displayName);
    _members = List.of(widget.group.members);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMixedProtocols = _hasMixedProtocols;
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context)?.llmModelGroupSettings ?? '模型组设置',
      ),
      content: SizedBox(
        width: math.min(560.0, MediaQuery.sizeOf(context).width - 48),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmModelGroupNameLabel ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiModelGroupName ??
                        '模型组名称',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.group.id,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.llmAccountUiAccountAnd ??
                          '账号与上游模型',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addMember,
                    icon: const Icon(Icons.add),
                    label: Text(
                      AppLocalizations.of(context)?.llmAddMember ?? '添加成员',
                    ),
                  ),
                ],
              ),
              if (_members.isEmpty)
                Text(
                  AppLocalizations.of(context)?.llmNoGroupMembers ??
                      AppLocalizations.of(context)?.llmAccountUiTheModelGroup ??
                      '模型组当前没有成员。',
                ),
              for (var index = 0; index < _members.length; index++)
                _memberEditor(index),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.llmStableModelGroupHelp ??
                    AppLocalizations.of(context)?.llmAccountUiLocalReferences ??
                    '本地引用用于兼容已有会话模型 ID；账号成员只会在这个稳定组内参与选择。',
              ),
              if (hasMixedProtocols) ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.llmMixedGroupProtocolError ??
                      AppLocalizations.of(context)?.llmAccountUiGroupMembers ??
                      '同一模型引用下的组成员必须使用相同聊天协议。',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
        ),
        FilledButton(
          onPressed: hasMixedProtocols
              ? null
              : () {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(
                    context,
                    AiGatewayModelGroup(
                      id: widget.group.id,
                      displayName: name,
                      members: _members,
                      policy: widget.group.policy,
                      legacyModelId: widget.group.legacyModelId,
                      legacyProviderName: widget.group.legacyProviderName,
                    ),
                  );
                },
          child: Text(AppLocalizations.of(context)?.llmSave ?? '保存'),
        ),
      ],
    );
  }

  bool get _hasMixedProtocols {
    final endpointByLocalModel = <String, String>{};
    for (final member in _members) {
      final account = widget.accounts
          .where((item) => item.id == member.accountId)
          .firstOrNull;
      if (account == null) continue;
      final endpoint = widget.providerCatalog
          .findProvider(account.connectorType)
          ?.chatProtocolId;
      if (endpoint == null) continue;
      final localModelId = member.localModelId ?? widget.group.id;
      final existing = endpointByLocalModel[localModelId];
      if (existing != null && existing != endpoint) return true;
      endpointByLocalModel[localModelId] = endpoint;
    }
    return false;
  }

  Widget _memberEditor(int index) {
    final member = _members[index];
    final preservesLegacyIdentity = _preservesStableGroupIdentity(
      widget.group,
      members: _members,
      index: index,
    );
    final account = widget.accounts
        .where((item) => item.id == member.accountId)
        .firstOrNull;
    final accountName = account?.displayName ??
        AppLocalizations.of(context)?.llmAccountUiAccountHas ??
        '账号已删除';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$accountName · ${member.upstreamModelId}'),
                ),
                IconButton(
                  tooltip: preservesLegacyIdentity
                      ? AppLocalizations.of(context)?.llmAccountUiOldSession ??
                          '旧会话引用所需成员'
                      : AppLocalizations.of(context)
                              ?.llmAccountUiRemoveMember ??
                          '移除成员',
                  onPressed: preservesLegacyIdentity
                      ? null
                      : () => setState(() => _members.removeAt(index)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('local_alias_${member.accountId}_$index'),
              initialValue: member.localModelId ?? widget.group.id,
              decoration: InputDecoration(
                label: _accountFieldLabel(
                  AppLocalizations.of(context)?.llmStableModelIdLabel ??
                      AppLocalizations.of(context)?.llmAccountUiLocalModel ??
                      '本地模型引用 ID',
                ),
              ),
              enabled: !preservesLegacyIdentity,
              onChanged: (value) {
                setState(() {
                  final current = _members[index];
                  _members[index] = AiGatewayModelGroupMember(
                    accountId: current.accountId,
                    upstreamModelId: current.upstreamModelId,
                    localModelId: value.trim(),
                    priorityTier: current.priorityTier,
                  );
                });
              },
            ),
            DropdownButtonFormField<int>(
              dropdownColor: StroomMenuStyle.surface(context),
              borderRadius: StroomMenuStyle.borderRadius,
              isExpanded: true,
              initialValue: member.priorityTier,
              decoration: InputDecoration(
                label: _accountFieldLabel(
                  AppLocalizations.of(context)?.llmPriorityTierLabel ?? '优先级层级',
                ),
              ),
              items: [
                for (var tier = 0; tier < 5; tier++)
                  DropdownMenuItem(
                    value: tier,
                    child: _accountDropdownLabel(
                      AppLocalizations.of(context)
                              ?.llmPriorityTierValue(tier) ??
                          '层级 $tier',
                    ),
                  ),
              ],
              onChanged: (tier) {
                if (tier == null) return;
                setState(() {
                  final current = _members[index];
                  _members[index] = AiGatewayModelGroupMember(
                    accountId: current.accountId,
                    upstreamModelId: current.upstreamModelId,
                    localModelId: current.localModelId,
                    priorityTier: tier,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember() async {
    final member = await showDialog<AiGatewayModelGroupMember>(
      context: context,
      builder: (_) => _AddModelGroupMemberDialog(
        accounts: widget.accounts,
        defaultLocalModelId: _members.firstOrNull?.localModelId ??
            widget.group.members.firstOrNull?.localModelId ??
            stableLlmModelGroupLocalModelId(widget.group.id) ??
            widget.group.id,
      ),
    );
    if (member == null || !mounted) return;
    setState(() => _members.add(member));
  }
}

bool _preservesStableGroupIdentity(
  AiGatewayModelGroup group, {
  required List<AiGatewayModelGroupMember> members,
  required int index,
}) {
  final exactAnchor = members.indexWhere((member) {
    final localModelId = member.localModelId;
    return localModelId != null &&
        group.id == stableLlmModelGroupId(member.accountId, localModelId);
  });
  if (exactAnchor >= 0) return index == exactAnchor;

  final legacyLocalModelId = stableLlmModelGroupLocalModelId(group.id);
  if (group.legacyModelId == null || legacyLocalModelId == null) return false;
  final legacyAnchor = members.indexWhere(
    (member) => member.localModelId == legacyLocalModelId,
  );
  return index == legacyAnchor;
}

class _AddModelGroupMemberDialog extends StatefulWidget {
  final List<AiGatewayAccount> accounts;
  final String defaultLocalModelId;

  const _AddModelGroupMemberDialog({
    required this.accounts,
    required this.defaultLocalModelId,
  });

  @override
  State<_AddModelGroupMemberDialog> createState() =>
      _AddModelGroupMemberDialogState();
}

class _AddModelGroupMemberDialogState
    extends State<_AddModelGroupMemberDialog> {
  late String? _accountId;
  String? _modelRecordId;
  late final TextEditingController _localModelId;
  int _priorityTier = 0;

  List<AiGatewayAccount> get _accountsWithModels =>
      widget.accounts.where((account) => account.models.isNotEmpty).toList();

  AiGatewayAccount? get _selectedAccount => _accountsWithModels
      .where((account) => account.id == _accountId)
      .firstOrNull;
  List<AiGatewayUpstreamModel> get _selectableModels {
    final seenUpstreamModelIds = <String>{};
    return [
      for (final model in _selectedAccount?.models ?? const [])
        if (seenUpstreamModelIds.add(model.upstreamModelId)) model,
    ];
  }

  AiGatewayUpstreamModel? get _selectedModel => _selectedAccount?.models
      .where((model) => model.id == _modelRecordId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _accountId = _accountsWithModels.firstOrNull?.id;
    _modelRecordId = _selectedAccount?.models.firstOrNull?.id;
    _localModelId = TextEditingController(text: widget.defaultLocalModelId);
  }

  @override
  void dispose() {
    _localModelId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.llmAddModelGroupMemberTitle ??
              '添加模型组成员',
        ),
        content: SizedBox(
          width: math.min(460.0, MediaQuery.sizeOf(context).width - 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                initialValue: _accountId,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmAccountLabel ?? '账号',
                  ),
                ),
                items: [
                  for (final account in _accountsWithModels)
                    DropdownMenuItem(
                      value: account.id,
                      child: _accountDropdownLabel(account.displayName),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _accountId = value;
                    _modelRecordId = widget.accounts
                        .firstWhere((account) => account.id == value)
                        .models
                        .firstOrNull
                        ?.id;
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                key: ValueKey('upstream_model_$_accountId'),
                initialValue: _modelRecordId,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmUpstreamModelLabel ??
                        '上游模型',
                  ),
                ),
                items: [
                  for (final model in _selectableModels)
                    DropdownMenuItem(
                      value: model.id,
                      child: _accountDropdownLabel(model.displayName),
                    ),
                ],
                onChanged: (value) => setState(() => _modelRecordId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _localModelId,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmStableModelIdLabel ??
                        AppLocalizations.of(context)?.llmAccountUiLocalModel ??
                        '本地模型引用 ID',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                dropdownColor: StroomMenuStyle.surface(context),
                borderRadius: StroomMenuStyle.borderRadius,
                isExpanded: true,
                initialValue: _priorityTier,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmPriorityTierLabel ??
                        '优先级层级',
                  ),
                ),
                items: [
                  for (var tier = 0; tier < 5; tier++)
                    DropdownMenuItem(
                      value: tier,
                      child: _accountDropdownLabel(
                        AppLocalizations.of(context)
                                ?.llmPriorityTierValue(tier) ??
                            '层级 $tier',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priorityTier = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
          ),
          FilledButton(
            onPressed: _save,
            child: Text(AppLocalizations.of(context)?.builtInPromptAdd ?? '添加'),
          ),
        ],
      );

  void _save() {
    final accountId = _accountId;
    final upstreamModelId = _selectedModel?.upstreamModelId;
    final localModelId = _localModelId.text.trim();
    if (accountId == null || upstreamModelId == null || localModelId.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      AiGatewayModelGroupMember(
        accountId: accountId,
        upstreamModelId: upstreamModelId,
        localModelId: localModelId,
        priorityTier: _priorityTier,
      ),
    );
  }
}

class _RoutingPolicyEditorDialog extends StatefulWidget {
  final String title;
  final AiGatewayRoutingPolicy policy;
  final bool showGroupOnlyControls;

  const _RoutingPolicyEditorDialog({
    required this.title,
    required this.policy,
    required this.showGroupOnlyControls,
  });

  @override
  State<_RoutingPolicyEditorDialog> createState() =>
      _RoutingPolicyEditorDialogState();
}

class _RoutingPolicyEditorDialogState
    extends State<_RoutingPolicyEditorDialog> {
  late final TextEditingController _concurrency;
  late AiGatewaySelectionStrategy _strategy;
  late AiGatewayFallbackScope _fallbackScope;
  final Map<AiGatewayUsageWindow, _WindowDraft> _windows = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _concurrency = TextEditingController(
      text: widget.policy.concurrencyLimit?.toString() ?? '',
    );
    _strategy = widget.policy.strategy;
    _fallbackScope = widget.policy.fallbackScope;
    for (final window in AiGatewayUsageWindow.values) {
      _windows[window] = _WindowDraft(widget.policy.windows[window]!);
    }
  }

  @override
  void dispose() {
    _concurrency.dispose();
    for (final draft in _windows.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: math.min(640.0, MediaQuery.sizeOf(context).width - 48),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showGroupOnlyControls) ...[
                  DropdownButtonFormField<AiGatewaySelectionStrategy>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
                    isExpanded: true,
                    initialValue: _strategy,
                    decoration: InputDecoration(
                      label: _accountFieldLabel(
                        AppLocalizations.of(context)
                                ?.llmSamePrioritySelectionLabel ??
                            AppLocalizations.of(context)
                                ?.llmAccountUiSamePriority ??
                            '同优先级选择',
                      ),
                    ),
                    items: [
                      for (final strategy in AiGatewaySelectionStrategy.values)
                        DropdownMenuItem(
                          value: strategy,
                          child: _accountDropdownLabel(
                            _strategyLabel(
                                strategy, AppLocalizations.of(context)),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _strategy = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AiGatewayFallbackScope>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
                    isExpanded: true,
                    initialValue: _fallbackScope,
                    decoration: InputDecoration(
                      label: _accountFieldLabel(
                        AppLocalizations.of(context)?.llmFallbackScopeLabel ??
                            AppLocalizations.of(context)
                                ?.llmAccountUiCrossAccount ??
                            '跨账号回退范围',
                      ),
                    ),
                    items: [
                      for (final scope in AiGatewayFallbackScope.values)
                        DropdownMenuItem(
                          value: scope,
                          child: _accountDropdownLabel(
                            _fallbackLabel(scope, AppLocalizations.of(context)),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _fallbackScope = value);
                    },
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 8),
                TextField(
                  controller: _concurrency,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmConcurrencyLimitLabel ??
                          AppLocalizations.of(context)
                              ?.llmAccountUiConcurrencyLimit ??
                          '并发上限',
                    ),
                    helperText: AppLocalizations.of(context)
                            ?.llmAccountUiLeaveBlankToIndicate ??
                        '留空表示不限制；账号和模型组分别配置。',
                  ),
                ),
                const SizedBox(height: 12),
                for (final window in AiGatewayUsageWindow.values)
                  _windowEditor(window, _windows[window]!),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.llmCancel ?? '取消'),
          ),
          FilledButton(
            onPressed: _save,
            child: Text(AppLocalizations.of(context)?.llmSavePolicy ?? '保存策略'),
          ),
        ],
      );

  Widget _windowEditor(AiGatewayUsageWindow window, _WindowDraft draft) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _windowLabel(window, AppLocalizations.of(context)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            DropdownButtonFormField<AiGatewayWindowMode>(
              dropdownColor: StroomMenuStyle.surface(context),
              borderRadius: StroomMenuStyle.borderRadius,
              isExpanded: true,
              initialValue: draft.mode,
              decoration: InputDecoration(
                label: _accountFieldLabel(
                  AppLocalizations.of(context)?.llmWindowModeLabel ?? '窗口模式',
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: AiGatewayWindowMode.rolling,
                  child: _accountDropdownLabel(
                    AppLocalizations.of(context)?.llmAccountUiRollingWindow ??
                        '滚动窗口',
                  ),
                ),
                DropdownMenuItem(
                  value: AiGatewayWindowMode.calendar,
                  child: _accountDropdownLabel(
                    AppLocalizations.of(context)?.llmAccountUiCalendarWindow ??
                        '日历窗口',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => draft.mode = value);
              },
            ),
            if (draft.mode == AiGatewayWindowMode.calendar)
              TextField(
                controller: draft.timeZone,
                decoration: InputDecoration(
                  label: _accountFieldLabel(
                    AppLocalizations.of(context)?.llmCalendarTimezoneLabel ??
                        AppLocalizations.of(context)
                            ?.llmAccountUiCalendarTime ??
                        '日历时区',
                  ),
                  hintText:
                      AppLocalizations.of(context)?.llmAccountUiForExample ??
                          '例如 Asia/Taipei 或 UTC',
                ),
              ),
            _thresholdEditor(
              AppLocalizations.of(context)?.llmAccountUiRemainingCredit ??
                  '剩余额度保留线',
              draft.reserve,
            ),
            _thresholdEditor(
              AppLocalizations.of(context)?.llmAccountUiWindowUsage ??
                  '窗口使用量上限',
              draft.ceiling,
            ),
          ],
        ),
      ),
    );
  }

  Widget _thresholdEditor(String label, _ThresholdDraft draft) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: draft.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmValueLabel ?? '数值',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<AiGatewayLimitKind>(
                  dropdownColor: StroomMenuStyle.surface(context),
                  borderRadius: StroomMenuStyle.borderRadius,
                  isExpanded: true,
                  initialValue: draft.kind,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      AppLocalizations.of(context)?.llmTypeLabel ?? '类型',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AiGatewayLimitKind.fixed,
                      child: _accountDropdownLabel(
                        AppLocalizations.of(context)?.llmAccountUiFixedValue ??
                            '固定值',
                      ),
                    ),
                    DropdownMenuItem(
                      value: AiGatewayLimitKind.percentage,
                      child: _accountDropdownLabel(
                        AppLocalizations.of(context)
                                ?.llmAccountUiPercentageText ??
                            '百分比',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => draft.kind = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: draft.unit,
                  enabled: draft.kind == AiGatewayLimitKind.fixed,
                  decoration: InputDecoration(
                    label: _accountFieldLabel(
                      draft.kind == AiGatewayLimitKind.fixed
                          ? AppLocalizations.of(context)
                                  ?.llmAccountUiUnitText ??
                              '单位'
                          : '%',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final concurrencyText = _concurrency.text.trim();
    final concurrency =
        concurrencyText.isEmpty ? null : int.tryParse(concurrencyText);
    if (concurrencyText.isNotEmpty &&
        (concurrency == null || concurrency <= 0)) {
      setState(
        () => _error =
            AppLocalizations.of(context)?.llmAccountUiTheConcurrency ??
                '并发上限必须是正整数，或留空表示不限。',
      );
      return;
    }
    final windows = <AiGatewayUsageWindow, AiGatewayWindowPolicy>{};
    for (final entry in _windows.entries) {
      final draft = entry.value;
      final zone = draft.timeZone.text.trim();
      if (draft.mode == AiGatewayWindowMode.calendar && zone.isEmpty) {
        setState(
          () => _error =
              AppLocalizations.of(context)?.llmAccountUiTheCalendar ??
                  '日历窗口需要填写时区。',
        );
        return;
      }
      final reserve = _buildThreshold(draft.reserve);
      final ceiling = _buildThreshold(draft.ceiling);
      if (reserve == _invalidThreshold || ceiling == _invalidThreshold) {
        setState(
          () => _error =
              AppLocalizations.of(context)?.llmAccountUiQuotaAndUsage ??
                  '额度和使用上限必须是非负数；百分比不能超过 100。',
        );
        return;
      }
      windows[entry.key] = AiGatewayWindowPolicy(
        mode: draft.mode,
        timeZone: zone.isEmpty ? null : zone,
        reserveFloor: reserve as AiGatewayLimitThreshold?,
        usageCeiling: ceiling as AiGatewayLimitThreshold?,
      );
    }
    Navigator.pop(
      context,
      AiGatewayRoutingPolicy(
        fallbackScope: _fallbackScope,
        strategy: _strategy,
        windows: windows,
        concurrencyLimit: concurrency,
      ),
    );
  }

  static const Object _invalidThreshold = Object();

  Object? _buildThreshold(_ThresholdDraft draft) {
    final text = draft.value.text.trim();
    if (text.isEmpty) return null;
    final value = num.tryParse(text);
    if (value == null || !value.isFinite || value < 0) {
      return _invalidThreshold;
    }
    if (draft.kind == AiGatewayLimitKind.percentage) {
      if (value > 100) return _invalidThreshold;
      return AiGatewayLimitThreshold.percentage(value);
    }
    final unit = draft.unit.text.trim();
    if (unit.isEmpty) return _invalidThreshold;
    return AiGatewayLimitThreshold.fixed(value, unit: unit);
  }
}

class _WindowDraft {
  AiGatewayWindowMode mode;
  final TextEditingController timeZone;
  final _ThresholdDraft reserve;
  final _ThresholdDraft ceiling;

  _WindowDraft(AiGatewayWindowPolicy policy)
      : mode = policy.mode,
        timeZone = TextEditingController(text: policy.timeZone ?? ''),
        reserve = _ThresholdDraft(policy.reserveFloor),
        ceiling = _ThresholdDraft(policy.usageCeiling);

  void dispose() {
    timeZone.dispose();
    reserve.dispose();
    ceiling.dispose();
  }
}

class _ThresholdDraft {
  AiGatewayLimitKind kind;
  final TextEditingController value;
  final TextEditingController unit;

  _ThresholdDraft(AiGatewayLimitThreshold? threshold)
      : kind = threshold?.kind ?? AiGatewayLimitKind.fixed,
        value = TextEditingController(text: threshold?.value.toString() ?? ''),
        unit = TextEditingController(text: threshold?.unit ?? '');

  void dispose() {
    value.dispose();
    unit.dispose();
  }
}

String _windowLabel(AiGatewayUsageWindow window, AppLocalizations? l10n) =>
    switch (window) {
      AiGatewayUsageWindow.fiveHour => l10n?.llmAccountUiHourWindow ?? '5 小时窗口',
      AiGatewayUsageWindow.day => l10n?.llmAccountUiDayWindow ?? '日窗口',
      AiGatewayUsageWindow.week => l10n?.llmAccountUiWeeklyWindow ?? '周窗口',
      AiGatewayUsageWindow.month => l10n?.llmAccountUiMonthWindow ?? '月窗口',
    };

String _limitThresholdLabel(
  AiGatewayLimitThreshold threshold,
  AppLocalizations? l10n,
) =>
    threshold.kind == AiGatewayLimitKind.percentage
        ? '${_formatUsageValue(threshold.value)}%'
        : '${_formatUsageValue(threshold.value)} ${threshold.unit ?? l10n?.llmAccountMetricUnitUnknown ?? '单位未知'}';

List<String> _policyWindowLimitRows(
  AiGatewayRoutingPolicy policy,
  AppLocalizations? l10n,
) {
  final rows = <String>[];
  for (final window in AiGatewayUsageWindow.values) {
    final windowPolicy = policy.windows[window];
    if (windowPolicy == null) continue;
    final label = _windowLabel(window, l10n);
    final reserveFloor = windowPolicy.reserveFloor;
    if (reserveFloor != null) {
      rows.add(
        l10n?.llmAccountQuotaReserveThreshold(
              label,
              _limitThresholdLabel(reserveFloor, l10n),
            ) ??
            '$label剩余额度保留线：${_limitThresholdLabel(reserveFloor, l10n)}',
      );
    }
    final usageCeiling = windowPolicy.usageCeiling;
    if (usageCeiling != null) {
      rows.add(
        l10n?.llmAccountUsageCeilingThreshold(
              label,
              _limitThresholdLabel(usageCeiling, l10n),
            ) ??
            '$label使用上限：${_limitThresholdLabel(usageCeiling, l10n)}',
      );
    }
  }
  return rows;
}
