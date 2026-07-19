import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../anki/sync/anki_sync_provider.dart';

/// AnkiWeb 账号管理页面。
///
/// 登录 / 注册 / 登出 三种状态切换。
class AnkiSyncSettingsPage extends ConsumerWidget {
  const AnkiSyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ankiSyncProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnkiWeb 同步'),
        centerTitle: true,
      ),
      body: _buildBody(context, state, cs, ref),
    );
  }

  Widget _buildBody(BuildContext context, AnkiSyncState state, ColorScheme cs,
      WidgetRef ref) {
    if (state.isLoading) return _buildLoading();
    if (state.isLoggedIn) return _buildLoggedIn(context, cs, state, ref);
    return _buildLoggedOut(context, cs, state, ref);
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildLoggedOut(BuildContext context, ColorScheme cs,
      AnkiSyncState state, WidgetRef ref) {
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_sync,
              size: 64, color: cs.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text('AnkiWeb 登录',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('登录后可同步卡片数据到 AnkiWeb',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          const SizedBox(height: 32),

          // Show error message
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(state.error!,
                          style: TextStyle(color: cs.error, fontSize: 13))),
                ]),
              ),
            ),

          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? '请输入有效邮箱' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passCtl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 4) ? '密码长度至少 4 位' : null,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('登录'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      ref.read(ankiSyncProvider.notifier).login(
                            emailCtl.text.trim(),
                            passCtl.text,
                          );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('注册 AnkiWeb 账号'),
            onPressed: () => _openRegisterPage(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedIn(BuildContext context, ColorScheme cs,
      AnkiSyncState state, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done, size: 72, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text('已登录',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(state.email ?? '',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('AnkiWeb 账号已连接',
                            style: TextStyle(color: cs.onSurface))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.info_outline, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('同步功能将自动在后台进行。导出 .apkg 文件时也会附带同步状态信息。',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: cs.error),
            icon: const Icon(Icons.logout),
            label: const Text('登出'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('登出'),
                  content: const Text('确定要登出 AnkiWeb 吗？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: cs.error),
                      onPressed: () {
                        ref.read(ankiSyncProvider.notifier).logout();
                        Navigator.pop(ctx);
                      },
                      child: const Text('登出'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openRegisterPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AnkiWebRegisterPage(),
      ),
    );
  }
}

/// WebView that opens AnkiWeb's register page.
class _AnkiWebRegisterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册 AnkiWeb')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://ankiweb.net/account/register'),
        ),
      ),
    );
  }
}
