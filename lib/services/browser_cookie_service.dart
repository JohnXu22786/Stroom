import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing browser cookie retention mode.
///
/// When retention mode is enabled, cookies and other browsing data
/// are persisted when the browser is closed, instead of being deleted.
/// The preference is stored in [SharedPreferences].
class BrowserCookieService {
  BrowserCookieService._();

  static const String _retentionKey = 'browser_cookie_retention';

  // ===========================================================================
  // Retention mode
  // ===========================================================================

  /// Returns whether cookie retention mode is currently enabled.
  static Future<bool> getRetentionMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_retentionKey) ?? false;
    } catch (e) {
      debugPrint('BrowserCookieService.getRetentionMode error: $e');
      return false;
    }
  }

  /// Enables or disables cookie retention mode.
  static Future<void> setRetentionMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_retentionKey, enabled);
    } catch (e) {
      debugPrint('BrowserCookieService.setRetentionMode error: $e');
    }
  }

  /// Toggles the current retention mode and returns the new value.
  static Future<bool> toggleRetentionMode() async {
    final current = await getRetentionMode();
    final newValue = !current;
    await setRetentionMode(newValue);
    return newValue;
  }

  // ===========================================================================
  // Cookie management via CookieManager
  // ===========================================================================

  /// Clears all cookies stored by the WebView.
  ///
  /// Returns `true` if the operation was successful, `false` otherwise.
  static Future<bool> clearAllCookies() async {
    try {
      return await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      debugPrint('BrowserCookieService.clearAllCookies error: $e');
      return false;
    }
  }

  /// Clears all cookies for the specified [domain].
  ///
  /// [domain] should be a domain name like "example.com".
  /// Leading dots (e.g. ".example.com") are automatically stripped.
  /// Returns `true` if the operation was successful, `false` otherwise.
  static Future<bool> clearCookiesForDomain(String domain) async {
    try {
      // Strip leading dot used in cookie domain attributes
      final cleanDomain = domain.startsWith('.') ? domain.substring(1) : domain;
      if (cleanDomain.isEmpty) return false;

      final httpsUrl = WebUri('https://$cleanDomain');
      final httpUrl = WebUri('http://$cleanDomain');

      final results = await Future.wait([
        CookieManager.instance().deleteCookies(url: httpsUrl),
        if (httpsUrl.toString() != httpUrl.toString())
          CookieManager.instance().deleteCookies(url: httpUrl),
      ]);

      return results.every((r) => r);
    } catch (e) {
      debugPrint('BrowserCookieService.clearCookiesForDomain error: $e');
      return false;
    }
  }

  /// Retrieves all stored cookies grouped by domain.
  ///
  /// Returns a map of domain → list of cookies. On platforms where
  /// [getAllCookies] is not supported, an empty map is returned.
  static Future<Map<String, List<Cookie>>> getAllCookiesGrouped() async {
    try {
      final allCookies = await CookieManager.instance().getAllCookies();
      final map = <String, List<Cookie>>{};
      for (final cookie in allCookies) {
        final domain = cookie.domain ?? 'unknown';
        map.putIfAbsent(domain, () => []).add(cookie);
      }
      // Sort domains alphabetically
      final sortedKeys = map.keys.toList()..sort();
      final sortedMap = <String, List<Cookie>>{};
      for (final key in sortedKeys) {
        sortedMap[key] = map[key]!;
      }
      return sortedMap;
    } catch (e) {
      debugPrint('BrowserCookieService.getAllCookiesGrouped error: $e');
      return {};
    }
  }

  /// Deletes a specific cookie by domain and name.
  ///
  /// [domain] should be a domain name like "example.com".
  /// Leading dots (e.g. ".example.com") are automatically stripped.
  /// Returns `true` if the operation was successful, `false` otherwise.
  static Future<bool> deleteCookie(String domain, String name) async {
    try {
      final cleanDomain = domain.startsWith('.') ? domain.substring(1) : domain;
      if (cleanDomain.isEmpty) return false;

      final httpsUrl = WebUri('https://$cleanDomain');
      final httpUrl = WebUri('http://$cleanDomain');

      final results = await Future.wait([
        CookieManager.instance().deleteCookie(url: httpsUrl, name: name),
        if (httpsUrl.toString() != httpUrl.toString())
          CookieManager.instance().deleteCookie(url: httpUrl, name: name),
      ]);

      return results.every((r) => r);
    } catch (e) {
      debugPrint('BrowserCookieService.deleteCookie error: $e');
      return false;
    }
  }
}
