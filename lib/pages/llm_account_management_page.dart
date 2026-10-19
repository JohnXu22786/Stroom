import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/llm_account.dart';
import '../services/llm_chat_runtime.dart';
import '../services/llm_connector_service.dart';
import '../services/llm_model_group_provider.dart';
import '../services/llm_routing_service.dart';

class LlmAccountManagementPage extends StatefulWidget {
  final LlmAccountConnectorService? accountService;
  final Future<void> Function()? onConfigurationChanged;
  final Future<void> Function(LlmAccount account)? onAccountSaved;
  final Future<void> Function(LlmAccount account)? beforeAccountDelete;

  const LlmAccountManagementPage({
    super.key,
    this.accountService,
    this.onConfigurationChanged,
    this.onAccountSaved,
    this.beforeAccountDelete,
  });

  @override
  State<LlmAccountManagementPage> createState() =>
      _LlmAccountManagementPageState();
}

class _LlmAccountManagementPageState extends State<LlmAccountManagementPage> {
  late final Future<LlmAccountConnectorService> _serviceFuture;
  Future<_ManagementData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _serviceFuture = widget.accountService == null
        ? LlmChatRoutingRuntime.createPlatform().then(
            (runtime) => runtime.accountService,
          )
        : Future.value(widget.accountService!);
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
    final service = await _serviceFuture;
    final results = await Future.wait([
      service.listAccounts(),
      service.listModelGroups(),
    ]);
    LlmRoutingRuntimeState? usageState;
    try {
      usageState = await LlmRoutingStateStore(
        preferences: service.preferences,
      ).load();
    } catch (_) {
      // Keep account and group management available if only local usage data
      // is malformed or temporarily unreadable.
    }
    final usageByAccount = <String, Map<String, num>>{};
    final usageByGroup = <String, Map<String, num>>{};
    for (final event in usageState?.events ?? const <LlmUsageEvent>[]) {
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
      accounts: results[0] as List<LlmAccount>,
      groups: results[1] as List<LlmModelGroup>,
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
    final result = await showDialog<_AccountEditResult>(
      context: context,
      builder: (_) => const _AccountEditorDialog(),
    );
    if (result == null || !mounted) return;
    try {
      final service = await _serviceFuture;
      final saved = await service.saveAccount(
        result.account,
        secret: result.secret.isEmpty ? null : result.secret,
      );
      await widget.onAccountSaved?.call(saved);
      await _reload();
    } catch (_) {
      _showError('账号保存失败。请检查账号信息和安全存储状态。');
    }
  }

  Future<void> _editAccount(LlmAccount account) async {
    final result = await showDialog<_AccountEditResult>(
      context: context,
      builder: (_) => _AccountEditorDialog(account: account),
    );
    if (result == null || !mounted) return;
    try {
      final service = await _serviceFuture;
      final saved = await service.saveAccount(
        result.account,
        secret: result.secret.isEmpty ? null : result.secret,
      );
      await widget.onAccountSaved?.call(saved);
      await _reload();
    } catch (_) {
      _showError('账号保存失败。请检查账号信息和安全存储状态。');
    }
  }

  Future<void> _deleteAccount(LlmAccount account) async {
    final confirmed = await _confirm(
      title: '删除账号',
      message: '删除“${account.displayName}”并从模型组中移除该账号？',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.beforeAccountDelete?.call(account);
      final service = await _serviceFuture;
      await service.deleteAccount(account.id);
      await _reload();
    } catch (_) {
      _showError('账号删除失败。');
    }
  }

  Future<void> _addGroup(List<LlmAccount> accounts) async {
    final choices = [
      for (final account in accounts)
        for (final model in account.models) (account, model),
    ];
    if (choices.isEmpty) {
      _showError('请先在账号中添加模型，再创建模型组。');
      return;
    }
    final (account, model) = choices.first;
    final initial = LlmModelGroup(
      id: const Uuid().v4(),
      displayName: model.displayName,
      members: [
        LlmModelGroupMember(
          accountId: account.id,
          upstreamModelId: model.upstreamModelId,
          localModelId: model.id,
        ),
      ],
    );
    await _editGroup(initial, accounts);
  }

  Future<void> _editGroup(
    LlmModelGroup group,
    List<LlmAccount> accounts,
  ) async {
    final updated = await showDialog<LlmModelGroup>(
      context: context,
      builder: (_) => _ModelGroupEditorDialog(group: group, accounts: accounts),
    );
    if (updated == null || !mounted) return;
    try {
      final service = await _serviceFuture;
      await service.saveModelGroup(updated);
      await _reload();
    } catch (_) {
      _showError('模型组保存失败。请确认成员账号中存在对应的上游模型。');
    }
  }

  Future<void> _deleteGroup(LlmModelGroup group) async {
    final confirmed = await _confirm(
      title: '删除模型组',
      message: '删除“${group.displayName}”的路由配置？已有会话中的模型引用不会改写。',
    );
    if (!confirmed || !mounted) return;
    try {
      final service = await _serviceFuture;
      await service.deleteModelGroup(group.id);
      await _reload();
    } catch (_) {
      _showError('模型组删除失败。');
    }
  }

  Future<void> _editPolicy({
    required LlmRoutingPolicy policy,
    required String title,
    required bool showGroupOnlyControls,
    required Future<void> Function(LlmRoutingPolicy) save,
  }) async {
    final updated = await showDialog<LlmRoutingPolicy>(
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
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              title: const Text('LLM 账号与模型组'),
              centerTitle: true,
              bottom: const TabBar(
                tabs: [
                  Tab(text: '账号'),
                  Tab(text: '模型组'),
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
                const Expanded(
                  child: Text('每个账号独立保存凭据、模型能力、额度和并发策略。未知额度保持未知。'),
                ),
                IconButton.filledTonal(
                  tooltip: '添加账号',
                  onPressed: _addAccount,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        if (data.accounts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('还没有 LLM 账号。')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: data.accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _AccountCard(
                account: data.accounts[index],
                localUsage:
                    data.runtimeUsageByAccount[data.accounts[index].id] ??
                    const <String, num>{},
                runtimeUsageAvailable: data.runtimeUsageAvailable,
                onEdit: () => _editAccount(data.accounts[index]),
                onDelete: () => _deleteAccount(data.accounts[index]),
                onPolicy: () => _editPolicy(
                  policy: data.accounts[index].policy,
                  title: '${data.accounts[index].displayName} 路由策略',
                  showGroupOnlyControls: false,
                  save: (policy) async {
                    final account = data.accounts[index];
                    try {
                      final service = await _serviceFuture;
                      await service.saveAccount(
                        LlmAccount(
                          id: account.id,
                          connectorType: account.connectorType,
                          authType: account.authType,
                          displayName: account.displayName,
                          status: account.status,
                          credentialRef: account.credentialRef,
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
                      _showError('路由策略保存失败。');
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
                const Expanded(
                  child: Text('稳定模型组把旧会话模型 ID 映射到可选账号和上游模型。成员只能在此组内回退。'),
                ),
                IconButton.filledTonal(
                  tooltip: '添加模型组',
                  onPressed: () => _addGroup(data.accounts),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        if (data.groups.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('还没有模型组。')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: data.groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ModelGroupCard(
                group: data.groups[index],
                accounts: data.accounts,
                localUsage:
                    data.runtimeUsageByGroup[data.groups[index].id] ??
                    const <String, num>{},
                runtimeUsageAvailable: data.runtimeUsageAvailable,
                onEdit: () => _editGroup(data.groups[index], data.accounts),
                onDelete: () => _deleteGroup(data.groups[index]),
                onPolicy: () => _editPolicy(
                  policy: data.groups[index].policy,
                  title: '${data.groups[index].displayName} 路由策略',
                  showGroupOnlyControls: true,
                  save: (policy) async {
                    final group = data.groups[index];
                    try {
                      final service = await _serviceFuture;
                      await service.saveModelGroup(
                        LlmModelGroup(
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
                      _showError('路由策略保存失败。');
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

class _ManagementData {
  final List<LlmAccount> accounts;
  final List<LlmModelGroup> groups;
  final Map<String, Map<String, num>> runtimeUsageByAccount;
  final Map<String, Map<String, num>> runtimeUsageByGroup;
  final bool runtimeUsageAvailable;

  const _ManagementData({
    required this.accounts,
    required this.groups,
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
        const Text('账号或模型组无法读取。'),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class _AccountCard extends StatelessWidget {
  final LlmAccount account;
  final Map<String, num> localUsage;
  final bool runtimeUsageAvailable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPolicy;

  const _AccountCard({
    required this.account,
    required this.localUsage,
    required this.runtimeUsageAvailable,
    required this.onEdit,
    required this.onDelete,
    required this.onPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    final quotaRows = [
      ..._quotaRows(account.usageByWindow),
      ..._accountQuotaRows(account),
    ];
    final policyRows = _policyWindowLimitRows(account.policy);
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
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑账号')),
                    PopupMenuItem(value: 'policy', child: Text('额度与并发策略')),
                    PopupMenuItem(value: 'delete', child: Text('删除账号')),
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
                  label: Text(_statusLabel(account.status)),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    '账号并发 ${account.policy.concurrencyLimit?.toString() ?? '不限'}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(_connectionExplanation(account.status)),
            if (llmChatEndpointTypeForConnector(account.connectorType) == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ChatAdapter 暂不支持此连接器。'),
                    Text('该账号的模型组不会出现在聊天与 Task Flow 模型选择器中。'),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('模型与能力', style: Theme.of(context).textTheme.labelLarge),
            if (account.models.isEmpty)
              const Text('未配置模型')
            else
              for (final model in account.models)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${model.displayName} (${model.upstreamModelId}) · ${_capabilitiesLabel(model.capabilities)}',
                  ),
                ),
            const SizedBox(height: 8),
            Text('用量与额度', style: Theme.of(context).textTheme.labelLarge),
            if (quotaRows.isEmpty)
              const Text('额度未知')
            else
              for (final row in quotaRows) Text(row),
            if (policyRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('额度限制', style: Theme.of(context).textTheme.labelLarge),
              for (final row in policyRows) Text(row),
            ],
            const SizedBox(height: 8),
            Text('本地观测用量', style: Theme.of(context).textTheme.labelLarge),
            if (localUsage.isEmpty)
              Text(
                runtimeUsageAvailable
                    ? '暂无本地记录（最近 62 天）'
                    : '本地观测用量未知（路由记录无法读取）',
              )
            else ...[
              const Text('最近 62 天的本地统计，不代表账号余额。'),
              for (final entry in localUsage.entries)
                Text(
                  '${_usageUnitLabel(entry.key)}：${_formatUsageValue(entry.value)}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelGroupCard extends StatelessWidget {
  final LlmModelGroup group;
  final List<LlmAccount> accounts;
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
    final preservesLegacyIdentity = group.members.any(
      (member) => _preservesStableGroupIdentity(group, member),
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
                    PopupMenuItem(value: 'edit', child: Text('编辑模型组')),
                    PopupMenuItem(value: 'policy', child: Text('额度与回退策略')),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !preservesLegacyIdentity,
                      child: Text(
                        preservesLegacyIdentity ? '保留旧会话模型组' : '删除模型组',
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
              '回退范围：${_fallbackLabel(group.policy.fallbackScope)} · '
              '组并发：${group.policy.concurrencyLimit?.toString() ?? '不限'}',
            ),
            Text('同优先级策略：${_strategyLabel(group.policy.strategy)}'),
            Text(
              localUsage.isEmpty
                  ? runtimeUsageAvailable
                        ? '模型组本地累计用量：未知'
                        : '模型组本地累计用量：未知（路由记录无法读取）'
                  : '模型组本地累计用量：${localUsage.entries.map((entry) => '${_usageUnitLabel(entry.key)} ${_formatUsageValue(entry.value)}').join(' · ')}',
            ),
            for (final row in _policyWindowLimitRows(group.policy)) Text(row),
            if (preservesLegacyIdentity) const Text('需保留旧会话模型引用对应的成员及本地引用 ID。'),
            const SizedBox(height: 8),
            Text('成员', style: Theme.of(context).textTheme.labelLarge),
            if (group.members.isEmpty)
              const Text('没有可路由的账号成员')
            else
              for (final member in group.members)
                Text(
                  '${accountNames[member.accountId] ?? '账号已删除'} · '
                  '${member.upstreamModelId} · 优先级 ${member.priorityTier} · '
                  '本地引用 ${member.localModelId ?? group.id}',
                ),
            const SizedBox(height: 8),
            if (diagnostic != null) ...[
              Text('最近一次路由', style: Theme.of(context).textTheme.labelLarge),
              Text(
                diagnostic.selectedAccountId == null
                    ? '没有账号可处理 ${diagnostic.localModelId}'
                    : '尝试账号：${accountNames[diagnostic.selectedAccountId] ?? diagnostic.selectedAccountId}',
              ),
              for (final decision in diagnostic.decisions)
                Text(
                  '${accountNames[decision.subjectId] ?? decision.subjectId}：'
                  '${llmRouteDecisionLabel(decision.reason)}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _quotaRows(Map<LlmUsageWindow, LlmUsageWindowState> usage) {
  const labels = {
    LlmUsageWindow.fiveHour: '5 小时',
    LlmUsageWindow.day: '每日',
    LlmUsageWindow.week: '每周',
    LlmUsageWindow.month: '每月',
  };
  final rows = <String>[];
  for (final window in LlmUsageWindow.values) {
    final state = usage[window] ?? const LlmUsageWindowState();
    final quota = state.quota;
    final used = state.used;
    final remaining = state.remaining;
    if (!quota.isKnown && !used.isKnown && !remaining.isKnown) continue;
    final parts = <String>[];
    parts.add('已用 ${used.isKnown ? _metricLabel(used) : '未知'}');
    parts.add('剩余 ${remaining.isKnown ? _metricLabel(remaining) : '未知'}');
    parts.add('总额 ${quota.isKnown ? _metricLabel(quota) : '未知'}');
    rows.add('${labels[window]}：${parts.join(' · ')}');
  }
  return rows;
}

List<String> _accountQuotaRows(LlmAccount account) {
  final rows = <String>[];
  if (_isDisplayableQuotaMetric(account.remainingQuota)) {
    rows.add('剩余额度：${_metricLabel(account.remainingQuota)}');
  }
  for (final entry in account.quotaSignals.entries) {
    if (!_isDisplayableQuotaMetric(entry.value)) continue;
    rows.add('${_quotaSignalLabel(entry.key)}：${_metricLabel(entry.value)}');
  }
  return rows;
}

bool _isDisplayableQuotaMetric(LlmMetricObservation metric) =>
    metric.isKnown &&
    metric.value != null &&
    metric.value!.isFinite &&
    metric.value! >= 0;

String _quotaSignalLabel(String signal) => switch (signal) {
  'primaryRemainingPercent' => '主窗口额度剩余',
  'secondaryRemainingPercent' => '次窗口额度剩余',
  'dailyRemainingPercent' => '每日额度剩余',
  'weeklyRemainingPercent' => '每周额度剩余',
  'monthlyRemainingPercent' => '每月额度剩余',
  'codeReviewRemainingPercent' => '代码审查额度剩余',
  _ => signal,
};

String _metricLabel(LlmMetricObservation metric) =>
    '${metric.value ?? '未知'} ${metric.unit ?? '单位未知'}';

String _usageUnitLabel(String unit) => switch (unit) {
  'requests' => '请求',
  'tokens' => 'tokens',
  'usd' => 'USD',
  _ => unit,
};

String _formatUsageValue(num value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String _capabilitiesLabel(Map<String, dynamic> capabilities) {
  if (capabilities.isEmpty) return '能力未知';
  return capabilities.entries
      .map(
        (entry) =>
            '${entry.key} ${entry.value == true
                ? '支持'
                : entry.value == false
                ? '不支持'
                : '未知'}',
      )
      .join('、');
}

String _statusLabel(LlmAccountStatus status) => switch (status) {
  LlmAccountStatus.unknown => '连接状态未知',
  LlmAccountStatus.ready => '就绪',
  LlmAccountStatus.paused => '已暂停',
  LlmAccountStatus.needsAttention => '需要重新认证',
};

String _connectionExplanation(LlmAccountStatus status) => switch (status) {
  LlmAccountStatus.unknown => '连接状态未知；路由仍可尝试请求，请根据请求结果更新状态。',
  LlmAccountStatus.ready => '账号可参与其模型组路由。',
  LlmAccountStatus.paused => '账号已暂停，不会参与路由。',
  LlmAccountStatus.needsAttention => '账号需要重新认证后才会参与路由。',
};

IconData _statusIcon(LlmAccountStatus status) => switch (status) {
  LlmAccountStatus.unknown => Icons.help_outline,
  LlmAccountStatus.ready => Icons.check_circle_outline,
  LlmAccountStatus.paused => Icons.pause_circle_outline,
  LlmAccountStatus.needsAttention => Icons.warning_amber_outlined,
};

String _fallbackLabel(LlmFallbackScope scope) => switch (scope) {
  LlmFallbackScope.account => '同一连接器账号',
  LlmFallbackScope.modelGroup => '当前模型组',
};

String _strategyLabel(LlmSelectionStrategy strategy) => switch (strategy) {
  LlmSelectionStrategy.leastUsed => '最少使用',
  LlmSelectionStrategy.roundRobin => '轮询',
  LlmSelectionStrategy.balanceHigher => '优先较高余额',
  LlmSelectionStrategy.balanceLower => '优先消耗较低余额',
};

class _AccountEditResult {
  final LlmAccount account;
  final String secret;

  const _AccountEditResult(this.account, this.secret);
}

class _AccountEditorDialog extends StatefulWidget {
  final LlmAccount? account;

  const _AccountEditorDialog({this.account});

  @override
  State<_AccountEditorDialog> createState() => _AccountEditorDialogState();
}

class _AccountEditorDialogState extends State<_AccountEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _credential;
  late final TextEditingController _models;
  late String _connectorType;
  late String _authType;
  late LlmAccountStatus _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _connectorType = account?.connectorType ?? 'openai-compatibility';
    _authType = account?.authType ?? 'api_key';
    _status = account?.status ?? LlmAccountStatus.unknown;
    _name = TextEditingController(text: account?.displayName ?? '');
    final endpoint =
        account?.endpointConfig['baseUrl'] ??
        account?.endpointConfig['host'] ??
        account?.endpointConfig['apiBase'];
    _endpoint = TextEditingController(text: endpoint is String ? endpoint : '');
    _credential = TextEditingController();
    _models = TextEditingController(
      text:
          account?.models
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
                ].join(','),
              )
              .join('\n') ??
          '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _credential.dispose();
    _models.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectors = LlmConnectorRegistry.all;
    final connector = LlmConnectorRegistry.find(_connectorType)!;
    final authTypes = connector.authTypes.toList()..sort();
    if (!authTypes.contains(_authType)) _authType = authTypes.first;
    return AlertDialog(
      title: Text(widget.account == null ? '添加 LLM 账号' : '编辑 LLM 账号'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '账号名称'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _connectorType,
                decoration: const InputDecoration(labelText: '连接器'),
                items: [
                  for (final item in connectors)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.displayName),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _connectorType = value;
                    final available = LlmConnectorRegistry.find(
                      value,
                    )!.authTypes.toList()..sort();
                    if (!available.contains(_authType)) {
                      _authType = available.first;
                    }
                    if (_authType == 'none' || _authType == 'relay') {
                      _credential.clear();
                    }
                  });
                },
              ),
              if (llmChatEndpointTypeForConnector(_connectorType) == null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'ChatAdapter 暂不支持此连接器；保存后，该账号的模型组不会出现在聊天与 Task Flow 模型选择器中。',
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _authType,
                decoration: const InputDecoration(labelText: '认证方式'),
                items: [
                  for (final type in authTypes)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_authLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _authType = value;
                    if (value == 'none' || value == 'relay') {
                      _credential.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _endpoint,
                decoration: const InputDecoration(
                  labelText: '端点地址（连接器需要时填写）',
                  hintText: 'https://api.example.com/v1',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _credential,
                enabled: _authType != 'none' && _authType != 'relay',
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _authType == 'none' || _authType == 'relay'
                      ? '该认证方式无需凭据'
                      : '凭据',
                  hintText: widget.account?.credentialRef == null
                      ? '保存在平台安全存储中'
                      : '留空以保留当前安全凭据',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<LlmAccountStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '连接状态'),
                items: [
                  for (final status in LlmAccountStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _models,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: '上游模型与能力',
                  hintText: '每行一个：模型 ID,streaming,vision,tools',
                  helperText: '能力为显式声明；用 vision=false 显式禁用，未填写保持未知。',
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
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final accountName = _name.text.trim();
    if (accountName.isEmpty) {
      setState(() => _error = '请输入账号名称。');
      return;
    }
    final id = widget.account?.id ?? const Uuid().v4();
    final previousModels = widget.account?.models ?? const <LlmUpstreamModel>[];
    final existingModelsByUpstream = <String, List<LlmUpstreamModel>>{};
    for (final model in previousModels) {
      existingModelsByUpstream
          .putIfAbsent(model.upstreamModelId, () => <LlmUpstreamModel>[])
          .add(model);
    }
    final modelLines = <List<String>>[];
    for (final line in _models.text.split('\n')) {
      final parts = line.split(',').map((part) => part.trim()).toList();
      if (parts.isNotEmpty && parts.first.isNotEmpty) modelLines.add(parts);
    }
    final existingByLine = <int, LlmUpstreamModel>{};
    final usedModelIds = <String>{};
    for (var index = 0; index < modelLines.length; index++) {
      final exact = existingModelsByUpstream[modelLines[index].first]
          ?.where((model) => !usedModelIds.contains(model.id))
          .firstOrNull;
      if (exact == null) continue;
      existingByLine[index] = exact;
      usedModelIds.add(exact.id);
    }
    final parsedModels = <LlmUpstreamModel>[];
    for (var index = 0; index < modelLines.length; index++) {
      final parts = modelLines[index];
      final upstreamId = parts.first;
      var existing = existingByLine[index];
      if (existing == null &&
          index < previousModels.length &&
          !usedModelIds.contains(previousModels[index].id)) {
        existing = previousModels[index];
        usedModelIds.add(existing.id);
      }
      final capabilities = <String, dynamic>{
        if (existing != null)
          for (final entry in existing.capabilities.entries)
            if (entry.value is! bool) entry.key: entry.value,
      };
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
        if (value != 'true' && value != 'false') {
          setState(() => _error = '能力值只能是 true 或 false。');
          return;
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
      parsedModels.add(
        LlmUpstreamModel(
          id: existing?.id ?? newModelId,
          upstreamModelId: upstreamId,
          displayName: existing?.displayName ?? upstreamId,
          capabilities: capabilities,
          config: existing?.config ?? const {},
        ),
      );
    }
    final endpoint = _endpoint.text.trim();
    final endpointConfig = Map<String, dynamic>.from(
      widget.account?.endpointConfig ?? const <String, dynamic>{},
    );
    final previousEndpoint =
        widget.account?.endpointConfig['baseUrl'] ??
        widget.account?.endpointConfig['host'] ??
        widget.account?.endpointConfig['apiBase'];
    if (endpointConfig['legacyOcrFullEndpoint'] == true &&
        endpoint !=
            (previousEndpoint is String ? previousEndpoint.trim() : '')) {
      endpointConfig.remove('legacyOcrFullEndpoint');
    }
    if (endpoint.isEmpty) {
      endpointConfig.remove('baseUrl');
      endpointConfig.remove('host');
      endpointConfig.remove('apiBase');
    } else {
      endpointConfig['baseUrl'] = endpoint;
    }
    final account = LlmAccount(
      id: id,
      connectorType: _connectorType,
      authType: _authType,
      displayName: accountName,
      status: _status,
      credentialRef: widget.account?.credentialRef,
      endpointConfig: endpointConfig,
      models: parsedModels,
      policy: widget.account?.policy,
      usageByWindow: widget.account?.usageByWindow,
      remainingQuota:
          widget.account?.remainingQuota ??
          const LlmMetricObservation.unknown(),
      quotaSignals: widget.account?.quotaSignals ?? const {},
    );
    final secret = _authType == 'none' || _authType == 'relay'
        ? ''
        : _credential.text.trim();
    final credentialIdentityChanged =
        widget.account != null &&
        (widget.account!.connectorType != _connectorType ||
            widget.account!.authType != _authType);
    if (_authType != 'none' &&
        _authType != 'relay' &&
        secret.isEmpty &&
        (widget.account?.credentialRef == null || credentialIdentityChanged)) {
      setState(() => _error = '请输入凭据。');
      return;
    }
    Navigator.pop(context, _AccountEditResult(account, secret));
  }
}

String _authLabel(String type) => switch (type) {
  'api_key' => 'API Key',
  'oauth' => 'OAuth 凭据',
  'service_account' => '服务账号',
  'session_token' => '会话令牌',
  'relay' => '应用内中继',
  'none' => '无认证',
  _ => type,
};

class _ModelGroupEditorDialog extends StatefulWidget {
  final LlmModelGroup group;
  final List<LlmAccount> accounts;

  const _ModelGroupEditorDialog({required this.group, required this.accounts});

  @override
  State<_ModelGroupEditorDialog> createState() =>
      _ModelGroupEditorDialogState();
}

class _ModelGroupEditorDialogState extends State<_ModelGroupEditorDialog> {
  late final TextEditingController _name;
  late List<LlmModelGroupMember> _members;

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
      title: const Text('模型组设置'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '模型组名称'),
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
                      '账号与上游模型',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addMember,
                    icon: const Icon(Icons.add),
                    label: const Text('添加成员'),
                  ),
                ],
              ),
              if (_members.isEmpty) const Text('模型组当前没有成员。'),
              for (var index = 0; index < _members.length; index++)
                _memberEditor(index),
              const SizedBox(height: 8),
              const Text('本地引用用于兼容已有会话模型 ID；账号成员只会在这个稳定组内参与选择。'),
              if (hasMixedProtocols) ...[
                const SizedBox(height: 8),
                const Text('同一模型引用下的组成员必须使用相同聊天协议。'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: hasMixedProtocols
              ? null
              : () {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(
                    context,
                    LlmModelGroup(
                      id: widget.group.id,
                      displayName: name,
                      members: _members,
                      policy: widget.group.policy,
                      legacyModelId: widget.group.legacyModelId,
                      legacyProviderName: widget.group.legacyProviderName,
                    ),
                  );
                },
          child: const Text('保存'),
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
      final endpoint = llmChatEndpointTypeForConnector(account.connectorType);
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
      member,
    );
    final account = widget.accounts
        .where((item) => item.id == member.accountId)
        .firstOrNull;
    final accountName = account?.displayName ?? '账号已删除';
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
                  tooltip: preservesLegacyIdentity ? '旧会话引用所需成员' : '移除成员',
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
              decoration: const InputDecoration(labelText: '本地模型引用 ID'),
              enabled: !preservesLegacyIdentity,
              onChanged: (value) {
                setState(() {
                  final current = _members[index];
                  _members[index] = LlmModelGroupMember(
                    accountId: current.accountId,
                    upstreamModelId: current.upstreamModelId,
                    localModelId: value.trim(),
                    priorityTier: current.priorityTier,
                  );
                });
              },
            ),
            DropdownButtonFormField<int>(
              initialValue: member.priorityTier,
              decoration: const InputDecoration(labelText: '优先级层级'),
              items: [
                for (var tier = 0; tier < 5; tier++)
                  DropdownMenuItem(value: tier, child: Text('层级 $tier')),
              ],
              onChanged: (tier) {
                if (tier == null) return;
                setState(() {
                  final current = _members[index];
                  _members[index] = LlmModelGroupMember(
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
    final member = await showDialog<LlmModelGroupMember>(
      context: context,
      builder: (_) => _AddModelGroupMemberDialog(
        accounts: widget.accounts,
        defaultLocalModelId:
            _members.firstOrNull?.localModelId ??
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
  LlmModelGroup group,
  LlmModelGroupMember member,
) {
  final localModelId = member.localModelId;
  if (localModelId == null) return false;
  if (group.id == stableLlmModelGroupId(member.accountId, localModelId)) {
    return true;
  }
  return group.legacyModelId != null &&
      stableLlmModelGroupLocalModelId(group.id) == localModelId;
}

class _AddModelGroupMemberDialog extends StatefulWidget {
  final List<LlmAccount> accounts;
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

  List<LlmAccount> get _accountsWithModels =>
      widget.accounts.where((account) => account.models.isNotEmpty).toList();

  LlmAccount? get _selectedAccount => _accountsWithModels
      .where((account) => account.id == _accountId)
      .firstOrNull;
  List<LlmUpstreamModel> get _selectableModels {
    final seenUpstreamModelIds = <String>{};
    return [
      for (final model in _selectedAccount?.models ?? const [])
        if (seenUpstreamModelIds.add(model.upstreamModelId)) model,
    ];
  }

  LlmUpstreamModel? get _selectedModel => _selectedAccount?.models
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
    title: const Text('添加模型组成员'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: '账号'),
            items: [
              for (final account in _accountsWithModels)
                DropdownMenuItem(
                  value: account.id,
                  child: Text(account.displayName),
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
            key: ValueKey('upstream_model_$_accountId'),
            initialValue: _modelRecordId,
            decoration: const InputDecoration(labelText: '上游模型'),
            items: [
              for (final model in _selectableModels)
                DropdownMenuItem(
                  value: model.id,
                  child: Text(model.displayName),
                ),
            ],
            onChanged: (value) => setState(() => _modelRecordId = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _localModelId,
            decoration: const InputDecoration(labelText: '本地模型引用 ID'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _priorityTier,
            decoration: const InputDecoration(labelText: '优先级层级'),
            items: [
              for (var tier = 0; tier < 5; tier++)
                DropdownMenuItem(value: tier, child: Text('层级 $tier')),
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
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('添加')),
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
      LlmModelGroupMember(
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
  final LlmRoutingPolicy policy;
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
  late LlmSelectionStrategy _strategy;
  late LlmFallbackScope _fallbackScope;
  final Map<LlmUsageWindow, _WindowDraft> _windows = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _concurrency = TextEditingController(
      text: widget.policy.concurrencyLimit?.toString() ?? '',
    );
    _strategy = widget.policy.strategy;
    _fallbackScope = widget.policy.fallbackScope;
    for (final window in LlmUsageWindow.values) {
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
      width: 640,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showGroupOnlyControls) ...[
              DropdownButtonFormField<LlmSelectionStrategy>(
                initialValue: _strategy,
                decoration: const InputDecoration(labelText: '同优先级选择'),
                items: [
                  for (final strategy in LlmSelectionStrategy.values)
                    DropdownMenuItem(
                      value: strategy,
                      child: Text(_strategyLabel(strategy)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _strategy = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<LlmFallbackScope>(
                initialValue: _fallbackScope,
                decoration: const InputDecoration(labelText: '跨账号回退范围'),
                items: [
                  for (final scope in LlmFallbackScope.values)
                    DropdownMenuItem(
                      value: scope,
                      child: Text(_fallbackLabel(scope)),
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
              decoration: const InputDecoration(
                labelText: '并发上限',
                helperText: '留空表示不限制；账号和模型组分别配置。',
              ),
            ),
            const SizedBox(height: 12),
            for (final window in LlmUsageWindow.values)
              _windowEditor(window, _windows[window]!),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('保存策略')),
    ],
  );

  Widget _windowEditor(LlmUsageWindow window, _WindowDraft draft) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _windowLabel(window),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            DropdownButtonFormField<LlmWindowMode>(
              initialValue: draft.mode,
              decoration: const InputDecoration(labelText: '窗口模式'),
              items: const [
                DropdownMenuItem(
                  value: LlmWindowMode.rolling,
                  child: Text('滚动窗口'),
                ),
                DropdownMenuItem(
                  value: LlmWindowMode.calendar,
                  child: Text('日历窗口'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => draft.mode = value);
              },
            ),
            if (draft.mode == LlmWindowMode.calendar)
              TextField(
                controller: draft.timeZone,
                decoration: const InputDecoration(
                  labelText: '日历时区',
                  hintText: '例如 Asia/Taipei 或 UTC',
                ),
              ),
            _thresholdEditor('剩余额度保留线', draft.reserve),
            _thresholdEditor('窗口使用量上限', draft.ceiling),
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
                  decoration: const InputDecoration(labelText: '数值'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<LlmLimitKind>(
                  initialValue: draft.kind,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(
                      value: LlmLimitKind.fixed,
                      child: Text('固定值'),
                    ),
                    DropdownMenuItem(
                      value: LlmLimitKind.percentage,
                      child: Text('百分比'),
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
                  enabled: draft.kind == LlmLimitKind.fixed,
                  decoration: InputDecoration(
                    labelText: draft.kind == LlmLimitKind.fixed ? '单位' : '%',
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
    final concurrency = concurrencyText.isEmpty
        ? null
        : int.tryParse(concurrencyText);
    if (concurrencyText.isNotEmpty &&
        (concurrency == null || concurrency <= 0)) {
      setState(() => _error = '并发上限必须是正整数，或留空表示不限。');
      return;
    }
    final windows = <LlmUsageWindow, LlmWindowPolicy>{};
    for (final entry in _windows.entries) {
      final draft = entry.value;
      final zone = draft.timeZone.text.trim();
      if (draft.mode == LlmWindowMode.calendar && zone.isEmpty) {
        setState(() => _error = '日历窗口需要填写时区。');
        return;
      }
      final reserve = _buildThreshold(draft.reserve);
      final ceiling = _buildThreshold(draft.ceiling);
      if (reserve == _invalidThreshold || ceiling == _invalidThreshold) {
        setState(() => _error = '额度和使用上限必须是非负数；百分比不能超过 100。');
        return;
      }
      windows[entry.key] = LlmWindowPolicy(
        mode: draft.mode,
        timeZone: zone.isEmpty ? null : zone,
        reserveFloor: reserve as LlmLimitThreshold?,
        usageCeiling: ceiling as LlmLimitThreshold?,
      );
    }
    Navigator.pop(
      context,
      LlmRoutingPolicy(
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
    if (draft.kind == LlmLimitKind.percentage) {
      if (value > 100) return _invalidThreshold;
      return LlmLimitThreshold.percentage(value);
    }
    final unit = draft.unit.text.trim();
    if (unit.isEmpty) return _invalidThreshold;
    return LlmLimitThreshold.fixed(value, unit: unit);
  }
}

class _WindowDraft {
  LlmWindowMode mode;
  final TextEditingController timeZone;
  final _ThresholdDraft reserve;
  final _ThresholdDraft ceiling;

  _WindowDraft(LlmWindowPolicy policy)
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
  LlmLimitKind kind;
  final TextEditingController value;
  final TextEditingController unit;

  _ThresholdDraft(LlmLimitThreshold? threshold)
    : kind = threshold?.kind ?? LlmLimitKind.fixed,
      value = TextEditingController(text: threshold?.value.toString() ?? ''),
      unit = TextEditingController(text: threshold?.unit ?? '');

  void dispose() {
    value.dispose();
    unit.dispose();
  }
}

String _windowLabel(LlmUsageWindow window) => switch (window) {
  LlmUsageWindow.fiveHour => '5 小时窗口',
  LlmUsageWindow.day => '日窗口',
  LlmUsageWindow.week => '周窗口',
  LlmUsageWindow.month => '月窗口',
};

String _limitThresholdLabel(LlmLimitThreshold threshold) =>
    threshold.kind == LlmLimitKind.percentage
    ? '${_formatUsageValue(threshold.value)}%'
    : '${_formatUsageValue(threshold.value)} ${threshold.unit ?? '单位未知'}';

List<String> _policyWindowLimitRows(LlmRoutingPolicy policy) {
  final rows = <String>[];
  for (final window in LlmUsageWindow.values) {
    final windowPolicy = policy.windows[window];
    if (windowPolicy == null) continue;
    final label = _windowLabel(window);
    final reserveFloor = windowPolicy.reserveFloor;
    if (reserveFloor != null) {
      rows.add('$label剩余额度保留线：${_limitThresholdLabel(reserveFloor)}');
    }
    final usageCeiling = windowPolicy.usageCeiling;
    if (usageCeiling != null) {
      rows.add('$label使用上限：${_limitThresholdLabel(usageCeiling)}');
    }
  }
  return rows;
}
