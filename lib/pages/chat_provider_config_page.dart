import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import 'chat_provider_config_detail_page.dart';

class ChatProviderConfigPage extends ConsumerStatefulWidget {
  const ChatProviderConfigPage({super.key});

  @override
  ConsumerState<ChatProviderConfigPage> createState() =>
      _ChatProviderConfigPageState();
}

class _ChatProviderConfigPageState
    extends ConsumerState<ChatProviderConfigPage> {
  Future<void> _addConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatProviderConfigDetailPage(
          configIndex: -1,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editConfig(int configIndex) async {
    final configs = ref.read(chatConfigsProvider);
    if (configIndex < 0 || configIndex >= configs.length) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatProviderConfigDetailPage(
          configIndex: configIndex,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _reorderConfigs(int oldIndex, int newIndex) async {
    await ref.read(chatConfigsProvider.notifier).reorder(oldIndex, newIndex);
  }

  Future<void> _deleteConfig(int configIndex) async {
    final configs = ref.read(chatConfigsProvider);
    if (configIndex < 0 || configIndex >= configs.length) return;

    final config = configs[configIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配置'),
        content: const Text('确定要删除此聊天供应商配置及其所有模型吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(chatConfigsProvider.notifier).remove(config.id);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(chatConfigsProvider);
    final selectedId = ref.watch(selectedChatConfigIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天供应商'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 供应商配置列表
                Row(
                  children: [
                    Text(
                      '供应商配置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加'),
                      onPressed: _addConfig,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          if (configs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('暂无聊天供应商配置，请点击"添加"创建',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: configs.length,
                onReorder: _reorderConfigs,
                proxyDecorator: (child, index, animation) => Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final config = configs[i];
                  final providerName = config.providerName.isNotEmpty
                      ? config.providerName
                      : '（未命名）';
                  final hostPreview =
                      config.host.isNotEmpty ? config.host : '(未设置 Host)';
                  final isSelected = selectedId == config.id;

                  return Card(
                    key: ValueKey('chat_config_$i'),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: isSelected
                        ? RoundedRectangleBorder(
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle,
                                color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected ? Icons.check_circle : Icons.chat,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.teal,
                          ),
                        ],
                      ),
                      title: Text(providerName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(hostPreview,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteConfig(i),
                            tooltip: '删除配置',
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.check,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      contentPadding: const EdgeInsets.only(left: 8, right: 4),
                      onTap: () {
                        // Set this config as the selected one and persist
                        ref.read(selectedChatConfigIdProvider.notifier).state =
                            config.id;
                        persistSelectedChatConfigId(config.id);
                        _editConfig(i);
                      },
                    ),
                  );
                },
              ),
            ),
          const SliverPadding(
            padding: EdgeInsets.all(16),
          ),
        ],
      ),
    );
  }
}
