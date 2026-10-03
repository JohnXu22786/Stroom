import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' hide Cookie;

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
///
/// Platform note: [CookieManager.getAllCookies] is only implemented on
/// iOS/macOS by `flutter_inappwebview`. On Android/Windows the platform
/// throws [UnimplementedError], so this service falls back to enumerating
/// cookies per-domain for every host seen via [noteVisitedUrl] using
/// [CookieManager.getCookies].
class BrowserCookieService {
  BrowserCookieService._();

  static const String _retentionKey = 'browser_cookie_retention';
  // Keep pending callbacks rather than a completed Future tail, which can
  // retain the caller's async zone across independent operations.
  static final Queue<_QueuedRetentionOperation<dynamic>> _retentionOperations =
      Queue();
  static bool _isRunningRetentionOperation = false;

  /// The platform cookie facade used for all platform cookie operations.
  ///
  /// Overridable in tests (via [enableTestMode]) to exercise the platform
  /// branches — the per-domain fallback, the merged grouping, restore
  /// validation — without a device.
  @visibleForTesting
  static CookiePlatform cookiePlatform = _RealCookiePlatform();

  // ===========================================================================
  // Test mode support (in-memory store, no file I/O)
  // ===========================================================================

  static bool _testMode = false;
  static List<Map<String, dynamic>>? _testCookies;

  /// Enable in-memory test mode — all file operations use a [List] instead of
  /// actual file I/O. Call before any persistence operations in tests.
  ///
  /// The platform facade is replaced with a fake that behaves like Android
  /// (no [CookieManager.getAllCookies]) but accepts every mutation, so the
  /// platform branches stay exercisable. Override [cookiePlatform] per test
  /// for specific scenarios.
  static void enableTestMode() {
    _testMode = true;
    _testCookies = null;
    _visitedDomains.clear();
    _visitedUrls.clear();
    cookiePlatform = _AndroidLikeCookiePlatform();
  }

  /// Disable test mode and clear stored data.
  static void disableTestMode() {
    _testMode = false;
    _testCookies = null;
    _visitedDomains.clear();
    _visitedUrls.clear();
    cookiePlatform = _RealCookiePlatform();
  }

  // ===========================================================================
  // Visited-domain tracking
  // ===========================================================================

  /// Hosts visited in the current app session. Used to enumerate cookies
  /// per-domain on platforms where [CookieManager.getAllCookies] is not
  /// implemented (Android/Windows).
  ///
  /// Bounded to the most recent [maxVisitedDomains] hosts so it cannot grow
  /// without limit over a long session.
  static final Set<String> _visitedDomains = <String>{};

  /// Maximum number of hosts kept for per-domain cookie enumeration.
  static const int maxVisitedDomains = 64;

  /// Page URLs kept for the current browser session to discover path-scoped
  /// cookies on platforms that cannot enumerate the complete cookie store.
  static final Set<String> _visitedUrls = <String>{};

  /// Records the host and path of a visited page URL so its cookies can be
  /// persisted, displayed, and cleared on platforms without
  /// [CookieManager.getAllCookies].
  static void noteVisitedUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    if (host == null || host.isEmpty) return;
    if (_visitedDomains.contains(host)) {
      // Re-visit: refresh recency (LinkedHashSet.add of an existing element
      // does NOT move it to the end — remove first).
      _visitedDomains.remove(host);
    } else if (_visitedDomains.length >= maxVisitedDomains) {
      // Evict the oldest host when inserting a NEW one at capacity.
      _visitedDomains.remove(_visitedDomains.first);
    }
    _visitedDomains.add(host);

    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      // Cookie paths do not include URL queries or fragments. Keep the origin
      // and path only; the set collapses repeated visits to the same path.
      final visitedUrl = '${uri.origin}${uri.path.isEmpty ? '/' : uri.path}';
      _visitedUrls.add(visitedUrl);
    }
  }

  /// The currently tracked visited hosts (test helper).
  @visibleForTesting
  static Set<String> get visitedDomainsForTest =>
      Set.unmodifiable(_visitedDomains);

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
    await _serializeRetentionOperation(() => _writeRetentionMode(enabled));
  }

  static Future<void> _writeRetentionMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_retentionKey, enabled);
    } catch (e) {
      debugPrint('BrowserCookieService.setRetentionMode error: $e');
    }
  }

  /// Toggles the current retention mode and returns the new value.
  static Future<bool> toggleRetentionMode() async {
    return _serializeRetentionOperation(() async {
      final current = await getRetentionMode();
      final newValue = !current;
      await _writeRetentionMode(newValue);
      return newValue;
    });
  }

  /// Applies the final retention preference when the browser closes.
  ///
  /// Queuing this with preference writes ensures the final selected mode is
  /// applied before cookies are persisted or cleared.
  static Future<void> handleBrowserClose() {
    return _serializeRetentionOperation(() async {
      if (await getRetentionMode()) {
        await persistCookiesToFile();
      } else {
        await clearAllCookies();
      }
    });
  }

  static Future<T> _serializeRetentionOperation<T>(
      Future<T> Function() operation) {
    final completer = Completer<T>();
    _retentionOperations.add(_QueuedRetentionOperation(operation, completer));
    if (!_isRunningRetentionOperation) {
      _isRunningRetentionOperation = true;
      _runNextRetentionOperation();
    }
    return completer.future;
  }

  static void _runNextRetentionOperation() {
    if (_retentionOperations.isEmpty) {
      _isRunningRetentionOperation = false;
      return;
    }

    final queuedOperation = _retentionOperations.removeFirst();
    Future<dynamic>.sync(queuedOperation.run).then<void>(
      (value) {
        if (_retentionOperations.isEmpty) {
          _isRunningRetentionOperation = false;
        } else {
          _runNextRetentionOperation();
        }
        queuedOperation.completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_retentionOperations.isEmpty) {
          _isRunningRetentionOperation = false;
        } else {
          _runNextRetentionOperation();
        }
        queuedOperation.completer.completeError(error, stackTrace);
      },
    );
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
      // Never fall back to a relative path: file operations resolve relative
      // paths against the process CWD (e.g. "/" on Android) and would throw.
      return p.join(Directory.systemTemp.path, 'browser_cookies.json');
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
  ///
  /// On platforms with an authoritative [CookieManager.getAllCookies]
  /// (iOS/macOS) the file mirrors the exact snapshot — cookies deleted by
  /// sites stay deleted. The per-domain fallback replaces known root-path
  /// cookies for successfully queried hosts while preserving path-scoped
  /// cookies and cookies for failed or unvisited hosts.
  static Future<void> persistCookiesToFile() async {
    if (!await getRetentionMode()) return;
    try {
      final result = await _collectPlatformCookies();
      // If enumeration was impossible (e.g. no visited domains recorded on
      // a platform without getAllCookies), don't overwrite the existing file.
      if (result.cookies == null) return;
      final collected = result.cookies!.map(_cookieToMap).toList();
      if (result.complete) {
        await _writeCookiesFile(collected);
      } else {
        final fileCookies = await _readCookiesFile();
        fileCookies.removeWhere((cookie) =>
            _rootPathCookieAppliesToAnyHost(cookie, result.queriedHosts));
        await _writeCookiesFile(_mergeCookies(fileCookies, collected));
      }
    } catch (e) {
      debugPrint('BrowserCookieService.persistCookiesToFile error: $e');
    }
  }

  /// Restores cookies from the local JSON file to the platform CookieManager.
  /// Does nothing if retention mode is disabled.
  ///
  /// Should be called when the WebView is created and a new page is about
  /// to load, so that previously persisted cookies are available.
  ///
  /// A malformed or invalid entry only skips that cookie — it never aborts
  /// the restoration of the remaining cookies.
  static Future<void> restoreCookiesFromFile() async {
    if (!await getRetentionMode()) return;
    try {
      final list = await _readCookiesFile();
      for (final cookieMap in list) {
        try {
          final name = cookieMap['name'];
          final domain = cookieMap['domain'];
          if (name is! String || name.isEmpty) continue;
          if (domain is! String || domain.isEmpty) continue;
          final value = cookieMap['value'];
          if (value == null) continue;
          final valueStr = value.toString();
          // Semicolons in the value would corrupt the native cookie string
          // ("name=value; Path=..."); skip such cookies instead.
          if (valueStr.contains(';')) continue;
          final cleanDomain =
              domain.startsWith('.') ? domain.substring(1) : domain;
          await cookiePlatform.setCookie(
            url: WebUri('https://$cleanDomain'),
            name: name,
            value: valueStr,
            // Only genuine domain cookies (leading dot) keep the Domain
            // attribute; host-only cookies (including those stamped with the
            // visited host by the Android fallback) are restored as host-only.
            domain: domain.startsWith('.') ? domain : null,
            path: (cookieMap['path'] as String?) ?? '/',
            expiresDate: cookieMap['expiresDate'] as int?,
            isSecure: cookieMap['isSecure'] as bool?,
            isHttpOnly: cookieMap['isHttpOnly'] as bool?,
            sameSite:
                HTTPCookieSameSitePolicy.fromNativeValue(cookieMap['sameSite']),
          );
        } catch (e) {
          debugPrint(
              'BrowserCookieService.restoreCookiesFromFile: skipping cookie: $e');
        }
      }
    } catch (e) {
      debugPrint('BrowserCookieService.restoreCookiesFromFile error: $e');
    }
  }

  /// Returns persisted cookies grouped by domain.
  ///
  /// Reads from the local JSON file (or test in-memory store).
  /// Returns empty map if the file doesn't exist or is empty.
  static Future<Map<String, List<Map<String, dynamic>>>>
      getCookiesFromFile() async {
    try {
      final list = await _readCookiesFile();
      return _groupAndSort(list);
    } catch (e) {
      debugPrint('BrowserCookieService.getCookiesFromFile error: $e');
      return {};
    }
  }

  /// Returns cookies grouped by domain, combining data from the persisted
  /// file store and the platform CookieManager.
  ///
  /// This is the main method to use for the cookies management page.
  /// When the platform snapshot is authoritative (iOS/macOS) it is shown
  /// as-is; on platforms without [CookieManager.getAllCookies] the partial
  /// per-domain snapshot is merged with the file (platform wins per
  /// domain/name/path; file entries for domains not visited this session
  /// are still shown).
  static Future<Map<String, List<Map<String, dynamic>>>>
      getCookiesGrouped() async {
    final platformCookies = <Map<String, dynamic>>[];
    var platformComplete = false;
    try {
      final all = await cookiePlatform.getAllCookies();
      platformCookies.addAll(all.map(_cookieToMap));
      platformComplete = true;
    } on UnimplementedError {
      // Android/Windows: no getAllCookies — enumerate per visited domain.
      await _collectPerDomainCookies(platformCookies);
    } catch (e) {
      debugPrint(
          'BrowserCookieService.getCookiesGrouped error (CookieManager): $e');
    }

    List<Map<String, dynamic>> fileCookies;
    try {
      fileCookies = await _readCookiesFile();
    } catch (e) {
      debugPrint('BrowserCookieService.getCookiesGrouped read error: $e');
      fileCookies = [];
    }

    if (platformComplete) {
      // Authoritative snapshot — show it as-is (even when empty, so cookies
      // deleted on the platform do not resurface from the file).
      return _groupAndSort(platformCookies);
    }
    // Partial or failed platform data: merge file + platform (platform wins
    // on conflicts).
    return _groupAndSort(_mergeCookies(fileCookies, platformCookies));
  }

  /// Enumerates cookies for every visited host (in parallel) and appends
  /// them to [out]. Host-only cookies (whose platform `domain` is null) are
  /// stamped with the visited host so they group, match and restore correctly.
  /// Returns the hosts whose queries completed, including those with no cookies.
  static Future<Set<String>> _collectPerDomainCookies(
      List<Map<String, dynamic>> out) async {
    final successfulHosts = <String>{};
    await Future.wait(_visitedDomains.map((host) async {
      try {
        final cookies =
            await cookiePlatform.getCookies(url: WebUri('https://$host'));
        final hostCookies = <Map<String, dynamic>>[];
        for (final cookie in cookies) {
          final map = _cookieToMap(cookie);
          if (map['domain'] == null) map['domain'] = host;
          hostCookies.add(map);
        }
        out.addAll(hostCookies);
        successfulHosts.add(host);
      } catch (e) {
        debugPrint(
            'BrowserCookieService._collectPerDomainCookies: domain $host error: $e');
      }
    }));
    return successfulHosts;
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
      return await cookiePlatform.deleteAllCookies();
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
  /// Cookies at known paths are expired separately because the native API
  /// only expires cookies at the given path.
  /// Returns false when the platform cannot provide a complete cookie
  /// snapshot, since URL-filtered queries cannot prove every path was cleared.
  static Future<bool> clearCookiesForDomain(String domain) async {
    try {
      final cleanDomain = domain.startsWith('.') ? domain.substring(1) : domain;
      if (cleanDomain.isEmpty) return false;

      // The native delete API operates on one path at a time. Preserve the
      // paths from the saved snapshot before removing that domain, and add
      // paths from a complete platform snapshot where the platform supports
      // getAllCookies (iOS/macOS).
      final paths = <String>{'/'};
      var completePlatformSnapshot = false;

      try {
        _addCookiePathsForDomain(await _readCookiesFile(), cleanDomain, paths);
      } catch (e) {
        debugPrint(
            'BrowserCookieService.clearCookiesForDomain path read error: $e');
      }
      try {
        final allCookies = await cookiePlatform.getAllCookies();
        completePlatformSnapshot = true;
        _addCookiePathsForDomain(
            allCookies.map(_cookieToMap), cleanDomain, paths);
      } on UnimplementedError {
        // Android/Windows do not expose a complete cookie snapshot.
        await _addPathsFromVisitedUrls(cleanDomain, paths);
      } catch (e) {
        debugPrint(
            'BrowserCookieService.clearCookiesForDomain platform read error: $e');
        await _addPathsFromVisitedUrls(cleanDomain, paths);
      }

      // Also remove from persisted store after collecting the paths it knows.
      await _removeDomainFromFile(domain);

      // Expire both host-only and domain cookies (leading-dot domain) at
      // every known path, over both schemes.
      final deleteCalls = <Future<bool>>[];
      for (final path in paths) {
        // The native implementation enumerates cookies applicable to the URL
        // before expiring them, so the URL itself must match the cookie path.
        final urlPath =
            path == '/' ? '' : (path.startsWith('/') ? path : '/$path');
        final httpsUrl = WebUri('https://$cleanDomain$urlPath');
        final httpUrl = WebUri('http://$cleanDomain$urlPath');
        deleteCalls.addAll([
          cookiePlatform.deleteCookies(url: httpsUrl, path: path),
          cookiePlatform.deleteCookies(
              url: httpsUrl, path: path, domain: '.$cleanDomain'),
          cookiePlatform.deleteCookies(url: httpUrl, path: path),
          cookiePlatform.deleteCookies(
              url: httpUrl, path: path, domain: '.$cleanDomain'),
        ]);
      }
      final results = await Future.wait(deleteCalls);

      return completePlatformSnapshot && results.every((r) => r);
    } catch (e) {
      debugPrint('BrowserCookieService.clearCookiesForDomain error: $e');
      return false;
    }
  }

  /// Deletes a specific cookie by domain and name from both the platform
  /// CookieManager and the persisted file.
  ///
  /// [domain] should be a domain name like "example.com" (leading dots are
  /// stripped for the URL; the raw [domain] is forwarded to the platform so
  /// the exact stored cookie is expired — genuine domain cookies keep their
  /// leading dot, host-only cookies are expired without a Domain attribute).
  static Future<bool> deleteCookie(String domain, String name,
      {String? path}) async {
    if (name.isEmpty) return false;
    try {
      // Also remove from persisted store
      await _removeCookieFromFile(domain, name, path: path);

      final cleanDomain = domain.startsWith('.') ? domain.substring(1) : domain;
      if (cleanDomain.isEmpty) return false;

      final httpsUrl = WebUri('https://$cleanDomain');
      final httpUrl = WebUri('http://$cleanDomain');

      final results = await Future.wait([
        cookiePlatform.deleteCookie(
            url: httpsUrl,
            name: name,
            path: path ?? '/',
            domain: domain.startsWith('.') ? domain : null),
        cookiePlatform.deleteCookie(
            url: httpUrl,
            name: name,
            path: path ?? '/',
            domain: domain.startsWith('.') ? domain : null),
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

  /// Collects the platform cookie store, using per-domain enumeration as a
  /// fallback on platforms without [CookieManager.getAllCookies].
  ///
  /// Returns `(cookies: null, complete: false)` when enumeration was
  /// impossible (nothing known to query or every query failed), so callers can
  /// avoid clobbering the persisted store. Successful queries are recorded in
  /// `queriedHosts`, including hosts that returned no cookies.
  ///
  /// `complete` is true when [CookiePlatform.getAllCookies] succeeded — the
  /// snapshot then covers the whole platform store and must be used WITHOUT
  /// merging with the file (a cookie the site deleted would resurrect).
  /// When `complete` is false the snapshot is partial and callers merge it
  /// with the persisted file. Successful per-domain queries are listed so
  /// root-path entries can be replaced only for those hosts.
  static Future<
          ({List<Cookie>? cookies, bool complete, Set<String> queriedHosts})>
      _collectPlatformCookies() async {
    try {
      final all = await cookiePlatform.getAllCookies();
      return (cookies: all, complete: true, queriedHosts: <String>{});
    } on UnimplementedError {
      final collected = <Map<String, dynamic>>[];
      final queriedHosts = await _collectPerDomainCookies(collected);
      if (queriedHosts.isEmpty) {
        // No visited domains or every per-domain query failed — do not
        // clobber the persisted store with an unavailable snapshot.
        return (
          cookies: null,
          complete: false,
          queriedHosts: queriedHosts,
        );
      }
      final cookies = collected
          .map((m) => Cookie(
                name: m['name'] as String? ?? '',
                value: m['value'] as String? ?? '',
                domain: m['domain'] as String?,
                path: m['path'] as String?,
                expiresDate: m['expiresDate'] as int?,
                isSecure: m['isSecure'] as bool?,
                isHttpOnly: m['isHttpOnly'] as bool?,
                sameSite:
                    HTTPCookieSameSitePolicy.fromNativeValue(m['sameSite']),
              ))
          .toList();
      return (
        cookies: cookies,
        complete: false,
        queriedHosts: queriedHosts,
      );
    }
  }

  /// Whether a persisted root-path cookie applies to any successfully queried
  /// host. Per-domain enumeration queries each host at `/`, so path-scoped
  /// cookies cannot be proven stale by an empty result.
  static bool _rootPathCookieAppliesToAnyHost(
      Map<String, dynamic> cookie, Set<String> hosts) {
    final path = cookie['path'];
    if (path != null && path != '/') return false;
    final cookieDomain = cookie['domain'];
    if (cookieDomain is! String || cookieDomain.isEmpty) return false;
    final isDomainCookie = cookieDomain.startsWith('.');
    final domain = (isDomainCookie ? cookieDomain.substring(1) : cookieDomain)
        .toLowerCase();
    if (domain.isEmpty) return false;
    return hosts.any((host) {
      final normalizedHost = host.toLowerCase();
      return normalizedHost == domain ||
          (isDomainCookie && normalizedHost.endsWith('.$domain'));
    });
  }

  /// Adds the paths belonging to [domain] from a set of cookie records.
  /// [hostForNullDomain] is used for host-only cookies returned by a URL query.
  static void _addCookiePathsForDomain(
      Iterable<Map<String, dynamic>> cookies, String domain, Set<String> paths,
      {String? hostForNullDomain}) {
    for (final cookie in cookies) {
      final cookieDomain = cookie['domain'] ?? hostForNullDomain;
      if (cookieDomain is! String) continue;
      final cleanCookieDomain = cookieDomain.startsWith('.')
          ? cookieDomain.substring(1)
          : cookieDomain;
      if (cleanCookieDomain.toLowerCase() != domain.toLowerCase()) continue;
      final path = cookie['path'];
      if (path is String && path.isNotEmpty) paths.add(path);
    }
  }

  /// Queries each recent visited URL in [domain]'s host tree and adds the
  /// paths of matching live cookies. This provides path discovery on
  /// Android/Windows, where [CookiePlatform.getAllCookies] is unavailable and
  /// retention may be disabled so the file has no path records.
  static Future<void> _addPathsFromVisitedUrls(
      String domain, Set<String> paths) async {
    final normalizedDomain = domain.toLowerCase();
    final urls = _visitedUrls.where((url) {
      final host = Uri.tryParse(url)?.host.toLowerCase();
      return host != null &&
          (host == normalizedDomain || host.endsWith('.$normalizedDomain'));
    });

    await Future.wait(urls.map((url) async {
      final uri = Uri.parse(url);
      try {
        // HTTPS exposes both secure and non-secure cookies for this URL path.
        final cookies = await cookiePlatform.getCookies(
            url: WebUri(uri.replace(scheme: 'https').toString()));
        _addCookiePathsForDomain(
          cookies.map(_cookieToMap),
          domain,
          paths,
          hostForNullDomain: uri.host,
        );
      } catch (e) {
        debugPrint(
            'BrowserCookieService._addPathsFromVisitedUrls: $url error: $e');
      }
    }));
  }

  /// Converts a [Cookie] object to a serializable map.
  static Map<String, dynamic> _cookieToMap(Cookie cookie) {
    return cookie.toJson();
  }

  /// Groups a flat cookie list by domain (alphabetically sorted).
  static Map<String, List<Map<String, dynamic>>> _groupAndSort(
      List<Map<String, dynamic>> cookies) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final cookie in cookies) {
      final domain = cookie['domain'] as String? ?? 'unknown';
      map.putIfAbsent(domain, () => []).add(cookie);
    }
    final sortedKeys = map.keys.toList()..sort();
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  /// Merges [override] entries on top of [base] entries. Two cookies are
  /// considered the same when their domain, name and path are equal.
  /// Platform (override) data wins so freshly-read cookies replace
  /// stale file entries.
  static List<Map<String, dynamic>> _mergeCookies(
      List<Map<String, dynamic>> base, List<Map<String, dynamic>> override) {
    String keyOf(Map<String, dynamic> cookie) {
      final domain = cookie['domain'];
      final name = cookie['name'];
      final path = cookie['path'];
      return '$domain\u0000$name\u0000$path';
    }

    final byKey = <String, Map<String, dynamic>>{};
    for (final cookie in base) {
      byKey[keyOf(cookie)] = cookie;
    }
    for (final cookie in override) {
      byKey[keyOf(cookie)] = cookie;
    }
    return byKey.values.toList();
  }

  /// Writes cookies atomically (temp file + rename) so a crash mid-write
  /// cannot corrupt the persisted store. The temp file gets a unique suffix
  /// so concurrent writers (page-load persist + dispose persist) cannot
  /// interleave inside the same tmp file.
  static Future<void> _writeCookiesFile(
      List<Map<String, dynamic>> cookies) async {
    if (_testMode) {
      _testCookies = cookies;
      return;
    }
    final path = await _cookiesFilePath;
    final tmpPath = '$path.tmp-${DateTime.now().microsecondsSinceEpoch}';
    await File(tmpPath).writeAsString(jsonEncode(cookies));
    await File(tmpPath).rename(path);
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
    // Validate entries eagerly: a single non-map element must not abort
    // processing of the rest (see restoreCookiesFromFile).
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  /// Removes all cookies for a given domain from the persisted file.
  static Future<void> _removeDomainFromFile(String domain) async {
    try {
      final list = await _readCookiesFile();
      final cleanDomain = domain.startsWith('.') ? domain.substring(1) : domain;
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
  /// When [path] is provided, only entries with that exact path are removed,
  /// keeping the file in sync with the platform deletion.
  static Future<void> _removeCookieFromFile(String domain, String name,
      {String? path}) async {
    try {
      final list = await _readCookiesFile();
      final cleanDomain = domain.startsWith('.') ? domain.substring(1) : domain;
      list.removeWhere((c) {
        final d = (c['domain'] as String?) ?? '';
        final cleanD = d.startsWith('.') ? d.substring(1) : d;
        final nameMatch = (c['name'] as String?) == name;
        final pathMatch = path == null || (c['path'] as String?) == path;
        return cleanD == cleanDomain && nameMatch && pathMatch;
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
    assert(_testMode,
        'persistCookiesRawForTest should only be called in test mode');
    _testCookies = List.from(cookies);
  }
}

class _QueuedRetentionOperation<T> {
  const _QueuedRetentionOperation(this.run, this.completer);

  final Future<T> Function() run;
  final Completer<T> completer;
}

// ===========================================================================
// Platform cookie facade
// ===========================================================================

/// Thin facade over the platform cookie operations used by
/// [BrowserCookieService]. The production implementation delegates to
/// [CookieManager]; tests install fakes to exercise the platform branches
/// (per-domain fallback, merged grouping, restore validation) without a
/// device.
@visibleForTesting
abstract class CookiePlatform {
  /// All cookies from the platform store. Throws [UnimplementedError] on
  /// platforms that cannot enumerate cookies (Android/Windows).
  Future<List<Cookie>> getAllCookies();

  /// Cookies applicable to [url].
  Future<List<Cookie>> getCookies({required WebUri url});

  /// Sets a cookie.
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
  });

  /// Deletes one cookie by name (optionally constrained by path/domain).
  Future<bool> deleteCookie({
    required WebUri url,
    required String name,
    String path = '/',
    String? domain,
  });

  /// Deletes all cookies for the URL (optionally constrained by domain).
  Future<bool> deleteCookies(
      {required WebUri url, String path, String? domain});

  /// Deletes every cookie in the platform store.
  Future<bool> deleteAllCookies();
}

/// Production facade backed by the real [CookieManager].
/// The manager is resolved lazily so constructing this facade never touches
/// the platform (important in unit tests, where the platform is absent).
class _RealCookiePlatform implements CookiePlatform {
  CookieManager get _manager => CookieManager.instance();

  @override
  Future<List<Cookie>> getAllCookies() => _manager.getAllCookies();

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) =>
      _manager.getCookies(url: url);

  @override
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
  }) =>
      _manager.setCookie(
        url: url,
        name: name,
        value: value,
        path: path,
        domain: domain,
        expiresDate: expiresDate,
        isSecure: isSecure,
        isHttpOnly: isHttpOnly,
        sameSite: sameSite,
      );

  @override
  Future<bool> deleteCookie({
    required WebUri url,
    required String name,
    String path = '/',
    String? domain,
  }) =>
      _manager.deleteCookie(url: url, name: name, path: path, domain: domain);

  @override
  Future<bool> deleteCookies(
          {required WebUri url, String path = '/', String? domain}) =>
      _manager.deleteCookies(url: url, path: path, domain: domain);

  @override
  Future<bool> deleteAllCookies() => _manager.deleteAllCookies();
}

/// Default test-mode facade: behaves like Android (no [getAllCookies],
/// per-domain enumeration returns nothing) while accepting every mutation.
/// Mirrors the real platform's [UnimplementedError] so the fallback paths
/// are exercised, but never touches the platform channel.
class _AndroidLikeCookiePlatform implements CookiePlatform {
  @override
  Future<List<Cookie>> getAllCookies() => throw UnimplementedError(
      'getAllCookies is not implemented on the current platform');

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) async => [];

  @override
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
  }) async =>
      true;

  @override
  Future<bool> deleteCookie({
    required WebUri url,
    required String name,
    String path = '/',
    String? domain,
  }) async =>
      true;

  @override
  Future<bool> deleteCookies(
          {required WebUri url, String path = '/', String? domain}) async =>
      true;

  @override
  Future<bool> deleteAllCookies() async => true;
}
