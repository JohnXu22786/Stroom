import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../anki/sync/anki_sync_engine.dart';
import '../anki/sync/anki_sync_provider.dart';

/// 自定义同步服务器设置 —— 与 AnkiDroid 相同的交互模式。
class AnkiSyncSettingsPage extends ConsumerWidget {
  const AnkiSyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(ankiSyncProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anki 同步'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 说明区 ──
          Card(
            color: cs.secondaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: cs.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '自建 Anki 同步服务器后在此配置连接信息。\n'
                      'docker run -p 8080:8080 -e SYNC_USER1=user:pass '
                      'zweizs/anki-sync-server',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 服务器地址（含开关）──
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  title: const Text('启用自定义同步'),
                  subtitle: const Text('使用自建服务器替代 AnkiWeb'),
                  value: config.enabled,
                  onChanged: (v) =>
                      ref.read(ankiSyncProvider.notifier).setEnabled(v),
                  secondary: Icon(Icons.dns_outlined,
                      color: config.enabled ? cs.primary : cs.onSurfaceVariant),
                ),
                if (config.enabled) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: TextFormField(
                      initialValue: config.url,
                      decoration: InputDecoration(
                        labelText: '服务器地址',
                        hintText: 'http://192.168.1.100:8080/sync/',
                        prefixIcon: const Icon(Icons.link),
                        border: const OutlineInputBorder(),
                        helperText: '末尾需带 /sync/',
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.url,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请输入服务器地址';
                        final uri = Uri.tryParse(v);
                        if (uri == null ||
                            !uri.hasScheme ||
                            !uri.hasAuthority) {
                          return '无效的 URL';
                        }
                        return null;
                      },
                      onChanged: (v) =>
                          ref.read(ankiSyncProvider.notifier).setSyncUrl(v),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── SSL 证书（可选）──
          if (config.enabled) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('自定义 SSL 证书（可选）',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('如果自建服务器使用了自签名证书，粘贴 PEM 格式的 CA 证书。',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: config.certificate,
                      decoration: const InputDecoration(
                        hintText: '-----BEGIN CERTIFICATE-----\n...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      onChanged: (v) =>
                          ref.read(ankiSyncProvider.notifier).setCertificate(v),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── 同步区域 ──
          if (config.isConfigured) ...[
            const SizedBox(height: 20),
            _SyncSection(),
          ],
        ],
      ),
    );
  }
}

/// 登录 / 同步操作区域。
class _SyncSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<_SyncSection> {
  String _status = '';
  bool _syncing = false;
  String? _sessionKey;

  /// 弹出登录对话框。
  Future<void> _showLoginDialog() async {
    final config = ref.read(ankiSyncProvider);
    final userCtl = TextEditingController();
    final passCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登录同步服务器'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('服务器: ${config.url}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextFormField(
                controller: userCtl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? '请输入用户名' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'u': userCtl.text.trim(),
                    'p': passCtl.text,
                  });
                }
              },
              child: const Text('登录')),
        ],
      ),
    );

    if (result != null) {
      await _connect(result['u']!, result['p']!);
    }
  }

  /// 向自定义服务器 hostKey 认证。
  Future<void> _connect(String username, String password) async {
    final config = ref.read(ankiSyncProvider);
    setState(() {
      _status = '认证中...';
      _sessionKey = null;
    });
    try {
      final uri = Uri.parse('${config.url}hostKey');
      final body = jsonEncode({'u': username, 'p': password});
      final client = config.certificate.isNotEmpty
          ? HttpClient(
              context: SecurityContext()
                ..setTrustedCertificatesBytes(utf8.encode(config.certificate)))
          : HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final key = json['key'] as String?;
        if (key != null && key.isNotEmpty) {
          _sessionKey = key;
          setState(() => _status = '认证成功 ✓');
          return;
        }
      }
      throw Exception('服务器返回 (${response.statusCode}): $responseBody');
    } catch (e) {
      setState(() => _status = '认证失败: $e');
    }
  }

  Future<void> _doSync() async {
    if (_syncing || _sessionKey == null) return;
    final config = ref.read(ankiSyncProvider);
    setState(() {
      _syncing = true;
      _status = '同步中...';
    });
    try {
      final engine = AnkiSyncEngine(endpoint: config.url);
      engine.syncKey = _sessionKey!;

      setState(() => _status = '交换元数据...');
      final meta = await engine.meta(SyncMeta());

      setState(() => _status = '开始同步...');
      await engine.start(meta.usn, 9999);

      setState(() => _status = '获取/发送变更...');
      var chunk = await engine.chunk();
      while (!chunk.done) {
        if (chunk.cards.isNotEmpty || chunk.notes.isNotEmpty) {
          await engine.applyChunk(chunk);
        }
        chunk = await engine.chunk();
      }

      setState(() => _status = '一致性检查...');
      await engine.sanityCheck(0, 0);

      setState(() => _status = '完成同步...');
      await engine.finish();

      setState(() => _status = '同步完成 ✓');
    } catch (e) {
      setState(() => _status = '同步失败: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _sessionKey = null;
      _status = '已登出';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoggedIn = _sessionKey != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(isLoggedIn ? Icons.cloud_done : Icons.cloud_outlined,
                    color: isLoggedIn ? Colors.green : cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(isLoggedIn ? '已连接服务器' : '未连接',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(isLoggedIn ? Icons.logout : Icons.wifi_find),
                    label: Text(isLoggedIn ? '登出' : '登录服务器'),
                    onPressed: _syncing
                        ? null
                        : () => isLoggedIn ? _logout() : _showLoginDialog(),
                  ),
                ),
                if (isLoggedIn) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync),
                      label: Text(_syncing ? '同步中...' : '立即同步'),
                      onPressed: _syncing ? null : _doSync,
                    ),
                  ),
                ],
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_status,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
