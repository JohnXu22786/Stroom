import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/browser_cookie_service.dart';

/// Management page for browser cookies and persisted browsing data.
///
/// Allows users to:
/// - Toggle cookie retention mode
/// - View all stored cookies grouped by domain
/// - Clear all cookies
/// - Clear individual cookies by domain
class BrowserCookiesPage extends StatefulWidget {
  const BrowserCookiesPage({super.key});

  @override
  State<BrowserCookiesPage> createState() => _BrowserCookiesPageState();
}

class _BrowserCookiesPageState extends State<BrowserCookiesPage> {
  bool _retentionEnabled = false;
  Map<String, List<Cookie>> _cookiesByDomain = {};
  bool _isLoadingCookies = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingCookies = true);
    final retention = await BrowserCookieService.getRetentionMode();
    final cookies = await BrowserCookieService.getAllCookiesGrouped();
    if (mounted) {
      setState(() {
        _retentionEnabled = retention;
        _cookiesByDomain = cookies;
        _isLoadingCookies = false;
      });
    }
  }

  Future<void> _toggleRetention() async {
    final newValue = await BrowserCookieService.toggleRetentionMode();
    if (mounted) {
      setState(() => _retentionEnabled = newValue);
    }
  }

  Future<void> _clearAllCookies() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有Cookies吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await BrowserCookieService.clearAllCookies();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除所有Cookies')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _clearDomainCookies(String domain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: Text('确定要清除 $domain 的所有Cookies吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await BrowserCookieService.clearCookiesForDomain(domain);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览器数据管理'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRetentionCard(colorScheme),
            const SizedBox(height: 16),
            _buildActionCards(colorScheme),
            const SizedBox(height: 16),
            _buildCookieList(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: Icon(
            Icons.cookie,
            color: _retentionEnabled ? Colors.orange : colorScheme.onSurfaceVariant,
          ),
          title: const Text('退出保留Cookies数据'),
          subtitle: Text(
            _retentionEnabled ? '已启用 - 退出时保留Cookies' : '已禁用 - 退出时清除Cookies',
          ),
          trailing: Switch(
            value: _retentionEnabled,
            onChanged: (_) => _toggleRetention(),
            activeThumbColor: Colors.orange,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildActionCards(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildActionTile(
          leading: const Icon(Icons.delete_sweep, color: Colors.red),
          title: '清除所有Cookies',
          subtitle: '删除所有已保存的网站Cookies',
          onTap: _isClearing ? null : _clearAllCookies,
          trailing: _isClearing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Widget trailing,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCookieList(ColorScheme colorScheme) {
    if (_isLoadingCookies) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_cookiesByDomain.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无持久化数据',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '使用内置浏览器并开启Cookies持久化后，\n已保存的数据将在此处显示。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            '已存储的Cookies (${_cookiesByDomain.values.fold<int>(0, (sum, list) => sum + list.length)})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
        ..._cookiesByDomain.entries.map(
          (entry) => _buildDomainCard(entry.key, entry.value, colorScheme),
        ),
      ],
    );
  }

  Widget _buildDomainCard(
      String domain, List<Cookie> cookies, ColorScheme colorScheme) {
    final totalCookies = cookies.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              leading: Icon(Icons.language, color: colorScheme.primary),
              title: Text(
                domain,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('$totalCookies 个Cookie'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: '清除此域名下的所有Cookies',
                onPressed: () => _clearDomainCookies(domain),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            // List individual cookies
            ...cookies.map(
              (cookie) => Padding(
                padding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cookie.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _maskValue('${cookie.value}'),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (cookie.path != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          cookie.path!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        padding: EdgeInsets.zero,
                        color: Colors.red.shade300,
                        tooltip: '删除此Cookie',
                        onPressed: () => _deleteSingleCookie(domain, cookie),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSingleCookie(String domain, Cookie cookie) async {
    await BrowserCookieService.deleteCookie(domain, cookie.name);
    await _loadData();
  }

  /// Masks a cookie value for display, showing only first few chars.
  String _maskValue(String value) {
    if (value.isEmpty) return '(空值)';
    if (value.length <= 6) return value;
    return '${value.substring(0, 3)}...${value.substring(value.length - 3)}';
  }
}
