import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// Service for managing browser cookie retention mode and persistence.
///
/// When retention mode is enabled, cookies and other browsing data
/// are persisted when the browser is closed, instead of being deleted.
/// The preference is stored in [SharedPreferences].
///
/// Actual cookie data is persisted to a JSON file (`browser_cookies.json`)
/// in the app documents directory, allowing cookies to survive browser
/// restarts when retention mode is enabled.
class BrowserCookieService {
  BrowserCookieService._();

  static const String _retentionKey = 'browser_cookie_retention';

  // ===========================================================================
  // Test mode support (in-memory store, no file I/O)
  // ===========================================================================

  static bool _testMode = false;
  static List<Map<String, dynamic>>? _testCookies;

  /// Enable in-memory test mode — all file operations use a [List] instead of
  /// actual file I/O. Call before any persistence operations in tests.
  static void enableTestMode() {
    _testMode = true;
    _testCookies = null;
  }

  /// Disable test mode and clear stored data.
  static void disableTestMode() {
    _testMode = false;
    _testCookies = null;
  }

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
  // File path for cookie persistence
  // ===========================================================================

  /// Returns the path to the cookie persistence file.
  static Future<String> get _cookiesFilePath async {
    if (_testMode) {
      // In test mode, we don't actually use file paths
      return '';
    }
    try {
      final dir = await AppStorage.directory;
      return p.join(dir, 'browser_cookies.json');
    } catch (e) {
      debugPrint('BrowserCookieService._cookiesFilePath error: $e');
      return 'browser_cookies.json';
    }
  }

  // ===========================================================================
  // Cookie persistence — save/load/clear
  // ===========================================================================

  /// Persists all currently stored cookies (from the platform CookieManager)
  /// to a local JSON file. Does nothing if retention mode is disabled.
  ///
  /// Should be called periodically while browsing (e.g. after page loads)
  /// and when the browser is closing.
  static Future<void> persistCookiesToFile() async {
    if (!await getRetentionMode()) return;
    try {
      final allCookies = await CookieManager.instance().getAllCookies();
      final list = allCookies.map(_cookieToMap).toList();
      await _writeCookiesFile(list);
    } catch (e) {
      debugPrint('BrowserCookieService.persistCookiesToFile error: $e');
    }
  }

  /// Restores cookies from the local JSON file to the platform CookieManager.
  /// Does nothing if retention mode is disabled.
  ///
  /// Should be called when the WebView is created and a new page is about
  /// to load, so that previously persisted cookies are available.
  static Future<void> restoreCookiesFromFile() async {
    if (!await getRetentionMode()) return;
    try {
      final list = await _readCookiesFile();
      for (final cookieMap in list) {
        final cookie = Cookie.fromMap(cookieMap);
        if (cookie == null) continue;
        final domain = cookie.domain;
        if (domain == null || domain.isEmpty) continue;
        final cleanDomain =
            domain.startsWith('.') ? domain.substring(1) : domain;
        await CookieManager.instance().setCookie(
          url: WebUri('https://$cleanDomain'),
          name: cookie.name,
          value: '${cookie.value}',
          domain: domain,
          path: cookie.path ?? '/',
          expiresDate: cookie.expiresDate,
          isSecure: cookie.isSecure,
          isHttpOnly: cookie.isHttpOnly,
          sameSite: cookie.sameSite,
        );
      }
    } catch (e) {
      debugPrint('BrowserCookieService.restoreCookiesFromFile error: $e');
    }
  }

  /// Returns persisted cookies grouped by domain.
  ///
  /// Reads from the local JSON file (or test in-memory store).
  /// Returns empty map if the file doesn't exist or is empty.
  /// Note: [getCookiesGrouped] should be used as the primary entry point
  /// as it tries the platform CookieManager first, then falls back here.
  static Future<Map<String, List<Map<String, dynamic>>>>
      getCookiesFromFile() async {
    try {
      final list = await _readCookiesFile();
      if (list.isEmpty) return {};
      final map = <String, List<Map<String, dynamic>>>{};
      for (final cookie in list) {
        final domain = cookie['domain'] as String? ?? 'unknown';
        map.putIfAbsent(domain, () => []).add(cookie);
      }
      // Sort domains alphabetically
      final sortedKeys = map.keys.toList()..sort();
      final sortedMap = <String, List<Map<String, dynamic>>>{};
      for (final key in sortedKeys) {
        sortedMap[key] = map[key]!;
      }
      return sortedMap;
    } catch (e) {
      debugPrint('BrowserCookieService.getCookiesFromFile error: $e');
      return {};
    }
  }

  /// Returns cookies grouped by domain, combining data from the persisted
  /// file store and the platform CookieManager.
  ///
  /// This is the main method to use for the cookies management page.
  static Future<Map<String, List<Map<String, dynamic>>>>
      getCookiesGrouped() async {
    // First try to get from the platform CookieManager
    try {
      final allCookies = await CookieManager.instance().getAllCookies();
      if (allCookies.isNotEmpty) {
        final map = <String, List<Map<String, dynamic>>>{};
        for (final cookie in allCookies) {
          final domain = cookie.domain ?? 'unknown';
          map.putIfAbsent(domain, () => []).add(_cookieToMap(cookie));
        }
        // Sort domains alphabetically
        final sortedKeys = map.keys.toList()..sort();
        final sortedMap = <String, List<Map<String, dynamic>>>{};
        for (final key in sortedKeys) {
          sortedMap[key] = map[key]!;
        }
        return sortedMap;
      }
    } catch (e) {
      debugPrint('BrowserCookieService.getCookiesGrouped error (CookieManager): $e');
    }

    // Fall back to file-based store
    return getCookiesFromFile();
  }

  /// Clears all persisted cookies from the local JSON file.
  static Future<void> clearPersistedCookies() async {
    try {
      await _writeCookiesFile([]);
    } catch (e) {
      debugPrint('BrowserCookieService.clearPersistedCookies error: $e');
    }
  }

  // ===========================================================================
  // Cookie management via CookieManager
  // ===========================================================================

  /// Clears all cookies from both the platform CookieManager and the
  /// persisted local file.
  static Future<bool> clearAllCookies() async {
    try {
      await clearPersistedCookies();
      return await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      debugPrint('BrowserCookieService.clearAllCookies error: $e');
      return false;
    }
  }

  /// Clears all cookies for the specified [domain] from the platform
  /// CookieManager and the persisted file.
  ///
  /// [domain] should be a domain name like "example.com".
  /// Leading dots (e.g. ".example.com") are automatically stripped.
  static Future<bool> clearCookiesForDomain(String domain) async {
    try {
      // Also remove from persisted store
      await _removeDomainFromFile(domain);

      final cleanDomain =
          domain.startsWith('.') ? domain.substring(1) : domain;
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

  /// Retrieves all stored cookies grouped by domain from the platform
  /// CookieManager.
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

  /// Deletes a specific cookie by domain and name from both the platform
  /// CookieManager and the persisted file.
  ///
  /// [domain] should be a domain name like "example.com".
  /// Leading dots (e.g. ".example.com") are automatically stripped.
  static Future<bool> deleteCookie(String domain, String name) async {
    try {
      // Also remove from persisted store
      await _removeCookieFromFile(domain, name);

      final cleanDomain =
          domain.startsWith('.') ? domain.substring(1) : domain;
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

  // ===========================================================================
  // Internal helpers
  // ===========================================================================

  /// Converts a [Cookie] object to a serializable map.
  static Map<String, dynamic> _cookieToMap(Cookie cookie) {
    return cookie.toJson();
  }

  /// Writes cookies list to the persistence file (or in-memory store in
  /// test mode).
  static Future<void> _writeCookiesFile(List<Map<String, dynamic>> cookies) async {
    if (_testMode) {
      _testCookies = cookies;
      return;
    }
    final path = await _cookiesFilePath;
    final content = jsonEncode(cookies);
    await File(path).writeAsString(content);
  }

  /// Reads cookies list from the persistence file (or in-memory store in
  /// test mode).
  static Future<List<Map<String, dynamic>>> _readCookiesFile() async {
    if (_testMode) {
      return _testCookies ?? [];
    }
    final path = await _cookiesFilePath;
    final file = File(path);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final decoded = jsonDecode(content);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Removes all cookies for a given domain from the persisted file.
  static Future<void> _removeDomainFromFile(String domain) async {
    try {
      final list = await _readCookiesFile();
      final cleanDomain =
          domain.startsWith('.') ? domain.substring(1) : domain;
      list.removeWhere((c) {
        final d = (c['domain'] as String?) ?? '';
        final cleanD = d.startsWith('.') ? d.substring(1) : d;
        return cleanD == cleanDomain;
      });
      await _writeCookiesFile(list);
    } catch (e) {
      debugPrint('BrowserCookieService._removeDomainFromFile error: $e');
    }
  }

  /// Removes a specific cookie by domain and name from the persisted file.
  static Future<void> _removeCookieFromFile(String domain, String name) async {
    try {
      final list = await _readCookiesFile();
      final cleanDomain =
          domain.startsWith('.') ? domain.substring(1) : domain;
      list.removeWhere((c) {
        final d = (c['domain'] as String?) ?? '';
        final cleanD = d.startsWith('.') ? d.substring(1) : d;
        return cleanD == cleanDomain && (c['name'] as String?) == name;
      });
      await _writeCookiesFile(list);
    } catch (e) {
      debugPrint('BrowserCookieService._removeCookieFromFile error: $e');
    }
  }

  // ===========================================================================
  // Test helper
  // ===========================================================================

  /// Directly persists a raw cookie list for testing purposes.
  /// Only available when test mode is enabled.
  @visibleForTesting
  static Future<void> persistCookiesRawForTest(
      List<Map<String, dynamic>> cookies) async {
    assert(_testMode, 'persistCookiesRawForTest should only be called in test mode');
    _testCookies = List.from(cookies);
  }
}
