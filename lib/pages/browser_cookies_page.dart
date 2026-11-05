import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/browser_cookie_service.dart';

/// Management page for browser cookies and persisted browsing data.
///
/// Allows users to:
/// - Toggle cookie retention mode
/// - View all stored cookies grouped by domain (from both the platform
///   CookieManager and the persisted file store)
/// - Clear all cookies
/// - Clear individual cookies by domain
class BrowserCookiesPage extends StatefulWidget {
  const BrowserCookiesPage({super.key});

  @override
  State<BrowserCookiesPage> createState() => _BrowserCookiesPageState();
}

class _BrowserCookiesPageState extends State<BrowserCookiesPage> {
  bool _retentionEnabled = false;
  Map<String, List<Map<String, dynamic>>> _cookiesByDomain = {};
  bool _isLoadingCookies = true;
  bool _isClearing = false;
  int _cookieLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final generation = ++_cookieLoadGeneration;
    if (mounted) {
      setState(() => _isLoadingCookies = true);
    }
    final retention = await BrowserCookieService.getRetentionMode();
    if (generation != _cookieLoadGeneration) return;
    final cookies = await BrowserCookieService.getCookiesGrouped();
    if (mounted && generation == _cookieLoadGeneration) {
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.browserCookiesConfirmClear),
        content: Text(l10n.browserCookiesConfirmClearAll),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.browserCookiesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.browserCookiesClear),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _cookieLoadGeneration++;
    setState(() => _isClearing = true);
    try {
      final ok = await BrowserCookieService.clearAllCookies();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? l10n.browserCookiesClearedAll
                  : l10n.browserCookiesClearFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _clearDomainCookies(String domain) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.browserCookiesConfirmClear),
        content: Text(l10n.browserCookiesClearDomainConfirm(domain)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.browserCookiesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.browserCookiesClear),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _cookieLoadGeneration++;
    final ok = await BrowserCookieService.clearCookiesForDomain(domain);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.browserCookiesClearedDomain(domain)
                : l10n.browserCookiesClearFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browserCookiesPageTitle),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          // Always scrollable so pull-to-refresh works even when the
          // content fits the screen.
          physics: const AlwaysScrollableScrollPhysics(),
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: Icon(
            Icons.cookie,
            color: _retentionEnabled
                ? Colors.orange
                : colorScheme.onSurfaceVariant,
          ),
          title: Text(l10n.browserCookiesRetentionTitle),
          subtitle: Text(
            _retentionEnabled
                ? l10n.browserCookiesRetentionOn
                : l10n.browserCookiesRetentionOff,
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
          title: AppLocalizations.of(context)!.browserCookiesClearAllTitle,
          subtitle:
              AppLocalizations.of(context)!.browserCookiesClearAllDescription,
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
                  AppLocalizations.of(context)!.browserCookiesEmptyTitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.browserCookiesEmptyDescription,
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
            AppLocalizations.of(context)!.browserCookiesStoredCount(
              _cookiesByDomain.values
                  .fold<int>(0, (sum, list) => sum + list.length),
            ),
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

  Widget _buildDomainCard(String domain, List<Map<String, dynamic>> cookies,
      ColorScheme colorScheme) {
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
              subtitle: Text(
                AppLocalizations.of(context)!
                    .browserCookiesDomainCount(totalCookies),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: AppLocalizations.of(context)!
                    .browserCookiesClearDomainTooltip,
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
                            cookie['name'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _maskValue(
                              cookie['value'] as String? ?? '',
                              AppLocalizations.of(context)!
                                  .browserCookiesEmptyValue,
                            ),
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
                    if (cookie['path'] != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          cookie['path'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    // Cookies without a name cannot be deleted by the
                    // platform API — don't offer a dead delete button.
                    if ((cookie['name'] as String? ?? '').isNotEmpty)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          padding: EdgeInsets.zero,
                          color: Colors.red.shade300,
                          tooltip: AppLocalizations.of(context)!
                              .browserCookiesDeleteOneTooltip,
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

  Future<void> _deleteSingleCookie(
      String domain, Map<String, dynamic> cookie) async {
    final l10n = AppLocalizations.of(context)!;
    final name = cookie['name'] as String? ?? '';
    _cookieLoadGeneration++;
    final ok = await BrowserCookieService.deleteCookie(
      domain,
      name,
      path: cookie['path'] as String?,
    );
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.browserCookiesDeletedOne
                : l10n.browserCookiesDeleteFailed,
          ),
        ),
      );
    }
  }

  /// Masks a cookie value for display, showing only first few chars.
  String _maskValue(String value, String emptyValue) {
    if (value.isEmpty) return emptyValue;
    if (value.length <= 6) return value;
    return '${value.substring(0, 3)}...${value.substring(value.length - 3)}';
  }
}
