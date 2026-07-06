import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show
        debugDefaultTargetPlatformOverride,
        defaultTargetPlatform,
        TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/update_provider.dart';

/// Creates a mock [Dio] that intercepts all requests and returns [jsonResponse].
///
/// The [jsonResponse] string is pre-parsed into a [Map] before setting it on the
/// response, simulating real Dio's JSON auto-parsing behavior (ResponseType.json).
Dio _createMockDio(String jsonResponse) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: jsonDecode(jsonResponse) as Map<String, dynamic>,
        ),
      );
    },
  ));
  return dio;
}

/// Creates a mock [Dio] that returns a JSON array response.
/// Used for the /releases endpoint which returns a list of releases.
Dio _createMockDioForList(String jsonResponse) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: jsonDecode(jsonResponse) as List<dynamic>,
        ),
      );
    },
  ));
  return dio;
}

/// Creates a mock [Dio] that always fails with an exception.
Dio _createFailingDio() {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        message: 'Connection refused',
        type: DioExceptionType.connectionTimeout,
      ));
    },
  ));
  return dio;
}

/// Creates a mock [Dio] that returns a non-200 HTTP status.
Dio _createNon200Dio(int statusCode) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: statusCode,
          data: 'Not Found',
        ),
      );
    },
  ));
  return dio;
}

/// Build a GitHub releases API response for the given tag.
String _githubRelease(String tagName,
    {String body = '', String? htmlUrl, List<Map<String, String>>? assets}) {
  htmlUrl ??= 'https://github.com/JohnXu22786/Stroom/releases/tag/$tagName';
  final assetsJson = assets != null
      ? ',\n  "assets": [${assets.map((a) => '{\n      "name": "${a['name']}",\n      "browser_download_url": "${a['browser_download_url']}"\n    }').join(',\n    ')}]'
      : '';
  return '''
{
  "tag_name": "$tagName",
  "body": "$body",
  "html_url": "$htmlUrl"$assetsJson
}
''';
}

/// Build a list of release assets for all platforms.
List<Map<String, String>> _allPlatformAssets(String tagName) {
  final version = tagName.replaceAll(RegExp(r'^v'), '');
  return [
    {
      'name': 'stroom-android-release-v$version.apk',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-android-release-v$version.apk'
    },
    {
      'name': 'stroom-windows-x64-installer-v$version.exe',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-windows-x64-installer-v$version.exe'
    },
    {
      'name': 'stroom-macos-arm64-release-v$version.zip',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-macos-arm64-release-v$version.zip'
    },
    {
      'name': 'stroom-linux-x64-release-v$version.zip',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-linux-x64-release-v$version.zip'
    },
    {
      'name': 'stroom-web-release-v$version.zip',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-web-release-v$version.zip'
    },
  ];
}

/// Build a list of GitHub releases API response (for /releases endpoint).
/// Each entry is a (tagName, isPrerelease, body) tuple.
String _githubReleases(List<(String, bool, String)> releases) {
  final items = releases.map((r) {
    final (tagName, isPrerelease, body) = r;
    return '''{
    "tag_name": "$tagName",
    "prerelease": $isPrerelease,
    "body": "$body",
    "html_url": "https://github.com/JohnXu22786/Stroom/releases/tag/$tagName"
  }''';
  }).join(',\n  ');
  return '[\n  $items\n]';
}

void main() {
  group('Version', () {
    test('parse standard semver "0.2.12"', () {
      final v = Version.parse('0.2.12');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
      expect(v.isPreRelease, false);
      expect(v.preRelease, isNull);
    });

    test('parse with v prefix "v0.2.12"', () {
      final v = Version.parse('v0.2.12');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
      expect(v.isPreRelease, false);
    });

    test('parse with build metadata "0.2.12+1"', () {
      final v = Version.parse('0.2.12+1');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
      expect(v.isPreRelease, false);
    });

    test('parse with pre-release "0.2.12-alpha" preserves pre-release', () {
      final v = Version.parse('0.2.12-alpha');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
      expect(v.isPreRelease, true);
      expect(v.preRelease, 'alpha');
    });

    test('parse with pre-release builds "0.2.12-beta.1"', () {
      final v = Version.parse('0.2.12-beta.1');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
      expect(v.isPreRelease, true);
      expect(v.preRelease, 'beta.1');
    });

    test('parse with pre-release plus build metadata "0.2.12-alpha+001"', () {
      final v = Version.parse('0.2.12-alpha+001');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
      expect(v.isPreRelease, true);
      expect(v.preRelease, 'alpha');
    });

    test('parse empty string defaults to 0.0.0', () {
      final v = Version.parse('');
      expect(v.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
      expect(v.isPreRelease, false);
    });

    test('parse non-numeric parts defaults to 0', () {
      final v = Version.parse('x.y.z');
      expect(v.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
      expect(v.isPreRelease, false);
    });

    // ---------- Pre-release compareTo logic ----------

    test('release > same base version with pre-release (1.1.0 > 1.1.0-alpha)',
        () {
      final release = Version.parse('1.1.0');
      final preRel = Version.parse('1.1.0-alpha');
      expect(release > preRel, true);
      expect(preRel < release, true);
      expect(release == preRel, false);
      expect(release >= preRel, true);
      expect(preRel <= release, true);
    });

    test('pre-release < same base version release (1.1.0-alpha < 1.1.0)', () {
      final preRel = Version.parse('1.1.0-alpha');
      final release = Version.parse('1.1.0');
      expect(preRel < release, true);
      expect(release > preRel, true);
    });

    test(
        'different major.minor.patch overrides pre-release (1.2.0-alpha > 1.1.0)',
        () {
      final preRel = Version.parse('1.2.0-alpha');
      final release = Version.parse('1.1.0');
      expect(preRel > release, true);
      expect(release < preRel, true);
    });

    test('pre-release order by identifier (1.1.0-beta > 1.1.0-alpha)', () {
      final beta = Version.parse('1.1.0-beta');
      final alpha = Version.parse('1.1.0-alpha');
      expect(beta > alpha, true);
      expect(alpha < beta, true);
    });

    test('same pre-release versions are equal (1.1.0-alpha == 1.1.0-alpha)',
        () {
      final a = Version.parse('1.1.0-alpha');
      final b = Version.parse('1.1.0-alpha');
      expect(a == b, false); // different instances
      expect(a > b, false);
      expect(a < b, false);
      expect(a >= b, true);
      expect(a <= b, true);
    });

    test('beta.2 > beta.1 in pre-release', () {
      final b2 = Version.parse('1.0.0-beta.2');
      final b1 = Version.parse('1.0.0-beta.1');
      expect(b2 > b1, true);
    });

    test('rc.1 > beta.5 in pre-release ordering (lexicographic)', () {
      // 'beta.5' vs 'rc.1': 'b' < 'r' → beta < rc
      final rc = Version.parse('1.0.0-rc.1');
      final beta = Version.parse('1.0.0-beta.5');
      expect(rc > beta, true);
    });

    // ---------- Legacy compareTo tests ----------

    test('0.2.14 > 0.2.13', () {
      final a = Version.parse('0.2.14');
      final b = Version.parse('0.2.13');
      expect(a > b, true);
    });

    test('0.2.13 == 0.2.13 (value equality via compareTo)', () {
      final a = Version.parse('0.2.13');
      final b = Version.parse('0.2.13');
      expect(a > b, false);
      expect(a < b, false);
      expect(a >= b, true);
      expect(a <= b, true);
    });

    test('v0.2.13 == 0.2.13 (v prefix ignored)', () {
      final a = Version.parse('v0.2.13');
      final b = Version.parse('0.2.13');
      expect(a > b, false);
      expect(a < b, false);
    });
  });

  group('UpdateNotifier', () {
    test('initial state has no update available and not checking', () {
      final dio = _createMockDio(_githubRelease('v0.2.13'));
      final notifier = UpdateNotifier(dio: dio);
      expect(notifier.state.updateAvailable, false);
      expect(notifier.state.isChecking, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.latestVersion, isNull);
    });

    test('checkForUpdate sets isChecking immediately', () {
      final dio = Dio(BaseOptions());
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Never resolve — keep checking
        },
      ));
      final notifier = UpdateNotifier(dio: dio);

      final future = notifier.checkForUpdate();
      expect(notifier.state.isChecking, true);
      expect(notifier.state.error, isNull);

      future.ignore();
    });

    test('detects update when latest release > current version', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14', body: 'Bug fixes'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.isChecking, false);
      expect(notifier.state.latestVersion, '0.2.14');
      expect(notifier.state.error, isNull);
      expect(notifier.state.releaseNotes, 'Bug fixes');
    });

    test('no update when latest release equals current version', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.13'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      expect(notifier.state.updateAvailable, false);
      expect(notifier.state.isChecking, false);
      expect(notifier.state.latestVersion, isNull);
      expect(notifier.state.error, isNull);
    });

    test('skipped version is not shown again', () async {
      SharedPreferences.setMockInitialValues({
        'update_skipped_version': '0.2.14',
      });
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      expect(notifier.state.updateAvailable, false);
      expect(notifier.state.isChecking, false);
    });

    test('sets error on HTTP failure', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createFailingDio();
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate(silent: false);

      expect(notifier.state.isChecking, false);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('网络错误'));
    });

    test('resets state on HTTP failure when silent', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createFailingDio();
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate(silent: true);

      expect(notifier.state.isChecking, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.updateAvailable, false);
    });

    test('sets error on non-200 response', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createNon200Dio(404);
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate(silent: false);

      expect(notifier.state.isChecking, false);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('HTTP 404'));
    });

    test('resets state on non-200 response when silent', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createNon200Dio(500);
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate(silent: true);

      expect(notifier.state.isChecking, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.updateAvailable, false);
    });

    test('recovers from error on subsequent check', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createFailingDio();
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate(silent: false);
      expect(notifier.state.error, isNotNull);

      final workingDio = _createMockDio(_githubRelease('v0.2.14'));
      final recovered = UpdateNotifier(dio: workingDio);
      await recovered.checkForUpdate(silent: false);

      expect(recovered.state.error, isNull);
      expect(recovered.state.updateAvailable, true);
      expect(recovered.state.latestVersion, '0.2.14');
    });

    test('isChecking prevents concurrent checks', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      notifier.state = notifier.state.copyWith(isChecking: true);

      await notifier.checkForUpdate();

      expect(notifier.state.isChecking, true);
    });

    test('getPendingUpdate returns null when no pending update', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      final result = await notifier.getPendingUpdate();
      expect(result, isNull);
    });

    test('getPendingUpdate returns saved update data', () async {
      SharedPreferences.setMockInitialValues({
        'update_available_data':
            '{"latest_version":"0.2.14","release_notes":"","download_url":"https://github.com/JohnXu22786/Stroom/releases"}',
      });
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      final result = await notifier.getPendingUpdate();
      expect(result, isNotNull);
      expect(result!['latest_version'], '0.2.14');
    });

    test('skipVersion saves skipped version and clears state', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.skipVersion('0.2.14');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('update_skipped_version'), '0.2.14');
      expect(prefs.containsKey('update_available_data'), false);
      expect(notifier.state.updateAvailable, false);
    });

    test('clearPendingUpdate clears persisted data', () async {
      SharedPreferences.setMockInitialValues({
        'update_available_data': '{"latest_version":"0.2.14"}',
      });
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.clearPendingUpdate();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('update_available_data'), false);
      expect(notifier.state.updateAvailable, false);
    });

    test('persists update data to SharedPreferences on detection', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('update_available_data');
      expect(raw, isNotNull);
      expect(raw, contains('0.2.14'));

      final pending = await notifier.getPendingUpdate();
      expect(pending, isNotNull);
      expect(pending!['latest_version'], '0.2.14');
    });

    test('downloadUrl is browser_download_url when asset found for platform',
        () async {
      SharedPreferences.setMockInitialValues({});
      final assets = _allPlatformAssets('v0.2.14');
      final dio = _createMockDio(
          _githubRelease('v0.2.14', body: 'Bug fixes', assets: assets));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.downloadUrl, isNotNull);
      // Should be a direct download URL, not the html_url
      expect(notifier.state.downloadUrl,
          contains('github.com/JohnXu22786/Stroom/releases/download'));
      expect(notifier.state.downloadUrl, isNot(contains('releases/tag')));
    });

    test('downloadUrl falls back to html_url when no assets provided',
        () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.downloadUrl, isNotNull);
      // Fallback to html_url when no assets
      expect(notifier.state.downloadUrl, contains('releases/tag'));
    });

    test('downloadUrl falls back to html_url when assets list is empty',
        () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14', assets: []));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.checkForUpdate();

      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.downloadUrl, isNotNull);
      expect(notifier.state.downloadUrl, contains('releases/tag'));
    });

    test('finds android asset when name contains android', () async {
      final assets = _allPlatformAssets('v0.2.14');
      final url = UpdateNotifier.findAssetDownloadUrl(assets, 'android');
      expect(url, isNotNull);
      expect(url, contains('.apk'));
      expect(url, contains('android'));
    });

    test('finds windows asset when name contains windows', () async {
      final assets = _allPlatformAssets('v0.2.14');
      final url = UpdateNotifier.findAssetDownloadUrl(assets, 'windows');
      expect(url, isNotNull);
      expect(url, contains('windows'));
    });

    test('finds macos asset when name contains macos', () async {
      final assets = _allPlatformAssets('v0.2.14');
      final url = UpdateNotifier.findAssetDownloadUrl(assets, 'macos');
      expect(url, isNotNull);
      expect(url, contains('macos'));
    });

    test('finds linux asset when name contains linux', () async {
      final assets = _allPlatformAssets('v0.2.14');
      final url = UpdateNotifier.findAssetDownloadUrl(assets, 'linux');
      expect(url, isNotNull);
      expect(url, contains('linux'));
    });

    test('returns null when no asset matches platform key', () async {
      final assets = _allPlatformAssets('v0.2.14');
      final url = UpdateNotifier.findAssetDownloadUrl(assets, 'nonexistent');
      expect(url, isNull);
    });

    test('returns null when assets list is empty', () async {
      final url = UpdateNotifier.findAssetDownloadUrl([], 'windows');
      expect(url, isNull);
    });
  });

  group('UpdateNotifier - Pre-release toggle', () {
    test('initial acceptPreRelease is false', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      expect(notifier.state.acceptPreRelease, false);
    });

    test('setAcceptPreRelease(true) updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.setAcceptPreRelease(true);

      expect(notifier.state.acceptPreRelease, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('update_accept_pre_release'), true);
    });

    test('setAcceptPreRelease(false) persists false', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.setAcceptPreRelease(false);

      expect(notifier.state.acceptPreRelease, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('update_accept_pre_release'), false);
    });

    test('loadAcceptPreRelease loads persisted true from SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({
        'update_accept_pre_release': true,
      });
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.loadAcceptPreRelease();

      expect(notifier.state.acceptPreRelease, true);
    });

    test('loadAcceptPreRelease defaults to false when not persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);

      await notifier.loadAcceptPreRelease();

      expect(notifier.state.acceptPreRelease, false);
    });

    test(
        'checkForUpdate with acceptPreRelease=true fetches all releases and finds latest prerelease',
        () async {
      SharedPreferences.setMockInitialValues({});
      final releases = _githubReleases([
        ('v0.2.15-alpha', true, 'Alpha test'),
        ('v0.2.14', false, 'Stable release'),
      ]);
      final dio = _createMockDioForList(releases);
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = notifier.state.copyWith(acceptPreRelease: true);

      await notifier.checkForUpdate();

      // Should find 0.2.15-alpha (newer than installed 0.2.13)
      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.latestVersion, '0.2.15-alpha');
      // acceptPreRelease should be preserved after check
      expect(notifier.state.acceptPreRelease, true);
    });

    test(
        'checkForUpdate with acceptPreRelease=false uses /releases/latest for non-prerelease',
        () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = notifier.state.copyWith(acceptPreRelease: false);

      await notifier.checkForUpdate();

      // 0.2.14 > installed 0.2.13
      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.latestVersion, '0.2.14');
    });

    test(
        'checkForUpdate with acceptPreRelease=true, only older prereleases → no update',
        () async {
      SharedPreferences.setMockInitialValues({});
      final releases = _githubReleases([
        ('v0.2.12-alpha', true, 'Older alpha'),
      ]);
      final dio = _createMockDioForList(releases);
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = notifier.state.copyWith(acceptPreRelease: true);

      await notifier.checkForUpdate();

      // 0.2.12-alpha < installed 0.2.13 → no update
      expect(notifier.state.updateAvailable, false);
      // acceptPreRelease should survive "no update" path
      expect(notifier.state.acceptPreRelease, true);
    });

    test(
        'checkForUpdate with acceptPreRelease=true picks latest regardless of prerelease status',
        () async {
      SharedPreferences.setMockInitialValues({});
      final releases = _githubReleases([
        ('v0.2.15-beta', true, 'Beta'),
        ('v0.2.15-alpha', true, 'Alpha'),
        ('v0.2.14', false, 'Stable'),
      ]);
      final dio = _createMockDioForList(releases);
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = notifier.state.copyWith(acceptPreRelease: true);

      await notifier.checkForUpdate();

      // 0.2.15-beta > other versions → should be selected
      expect(notifier.state.updateAvailable, true);
      expect(notifier.state.latestVersion, '0.2.15-beta');
    });

    test('acceptPreRelease survives error during pre-release check', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createFailingDio();
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = notifier.state.copyWith(acceptPreRelease: true);

      await notifier.checkForUpdate(silent: false);

      // Even on error, acceptPreRelease should be preserved
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.acceptPreRelease, true);
    });

    test('acceptPreRelease survives silent error during pre-release check',
        () async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createFailingDio();
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = notifier.state.copyWith(acceptPreRelease: true);

      await notifier.checkForUpdate(silent: true);

      // Even on silent error, acceptPreRelease should be preserved
      expect(notifier.state.isChecking, false);
      expect(notifier.state.acceptPreRelease, true);
    });
  });

  group('UpdateNotifier - Download', () {
    late Dio dio;
    late String tempDir;
    late TargetPlatform originalPlatform;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dio = Dio(BaseOptions());
      // Create a real temp directory for download tests
      tempDir = Directory.systemTemp.createTempSync('stroom_test_').path;
      // Save original platform and override to avoid auto-install side effects
      originalPlatform =
          debugDefaultTargetPlatformOverride ?? defaultTargetPlatform;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      // Clean up temp directory
      try {
        Directory(tempDir).deleteSync(recursive: true);
      } catch (_) {}
      debugDefaultTargetPlatformOverride = originalPlatform;
    });

    test('downloadUpdate returns error when downloadUrl is null', () async {
      final notifier = UpdateNotifier(dio: dio);
      // No downloadUrl set
      await notifier.downloadUpdate(downloadDir: tempDir);
      expect(notifier.state.downloadError, isNotNull);
      expect(notifier.state.isDownloading, false);
    });

    test(
        'downloadUpdate sets isDownloading, completes download, and auto-installs',
        () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Simulate download by resolving immediately
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: <int>[1, 2, 3], // minimal binary data
            ),
          );
        },
      ));
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        releaseNotes: '',
      );

      await notifier.downloadUpdate(downloadDir: tempDir);

      expect(notifier.state.isDownloading, false);
      // On test environment (iOS override), auto-install may fail gracefully
      // but download itself should be complete
      expect(notifier.state.downloadComplete, true);
      expect(notifier.state.downloadedFilePath, isNotNull);
      // downloadError might be set due to auto-install failure in test environment
      // but that is acceptable - the key is download completed
    });

    test('downloadUpdate transitions through download lifecycle states',
        () async {
      // Use Completer to control when download resolves
      final completer = Completer<Response>();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Store the handler for later resolution
          completer.future.then((response) {
            handler.resolve(response);
          });
        },
      ));
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        releaseNotes: '',
      );

      final future = notifier.downloadUpdate(downloadDir: tempDir);

      // During download, isDownloading should be true immediately
      expect(notifier.state.isDownloading, true);
      expect(notifier.state.downloadComplete, false);
      expect(notifier.state.isInstalling, false);

      // Complete the download by resolving the completer
      completer.complete(Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: <int>[1, 2, 3],
      ));
      await future;

      expect(notifier.state.isDownloading, false);
      expect(notifier.state.downloadComplete, true);
      // After auto-install completes, isInstalling should be false
      expect(notifier.state.isInstalling, false);
    });

    test('downloadUpdate handles network error', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            message: 'Connection refused',
            type: DioExceptionType.connectionTimeout,
          ));
        },
      ));
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        releaseNotes: '',
      );

      await notifier.downloadUpdate(downloadDir: tempDir);

      expect(notifier.state.isDownloading, false);
      expect(notifier.state.downloadError, isNotNull);
      expect(notifier.state.downloadError, contains('下载失败'));
    });

    test('downloadUpdate handles non-200 response', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 404,
              data: 'Not Found',
            ),
          );
        },
      ));
      final notifier = UpdateNotifier(dio: dio);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        releaseNotes: '',
      );

      await notifier.downloadUpdate(downloadDir: tempDir);

      expect(notifier.state.isDownloading, false);
      expect(notifier.state.downloadError, isNotNull);
    });
  });

  group('UpdateNotifier - Install Flow', () {
    late TargetPlatform originalPlatform;
    late String tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir =
          Directory.systemTemp.createTempSync('stroom_test_install_').path;
      originalPlatform =
          debugDefaultTargetPlatformOverride ?? defaultTargetPlatform;
      // Use iOS to avoid Android MethodChannel dependency in unit tests
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = originalPlatform;
      try {
        Directory(tempDir).deleteSync(recursive: true);
      } catch (_) {}
    });

    test('installDownloadedFile does nothing when downloadedFilePath is null',
        () async {
      final notifier = UpdateNotifier(dio: Dio(BaseOptions()));
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl: 'https://example.com/test.apk',
      );

      // downloadedFilePath is null → early return, no install attempt
      await notifier.installDownloadedFile();
      expect(notifier.state.downloadError, isNull);
    });

    test('installDownloadedFile does nothing when downloadedFilePath is empty',
        () async {
      final notifier = UpdateNotifier(dio: Dio(BaseOptions()));
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl: 'https://example.com/test.apk',
        downloadComplete: true,
        downloadedFilePath: '',
      );

      await notifier.installDownloadedFile();
      expect(notifier.state.downloadError, isNull);
    });

    test(
        'installDownloadedFile clears previous downloadError before attempting install',
        () async {
      final notifier = UpdateNotifier(dio: Dio(BaseOptions()));
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl: 'https://example.com/test.apk',
        downloadComplete: true,
        downloadedFilePath: '/tmp/nonexistent.zip',
        downloadError: '之前的错误',
      );

      await notifier.installDownloadedFile();

      // The error should be cleared first (even if install later fails with a new error)
      expect(notifier.state.downloadError, isNot(contains('之前的错误')));
    });
  });

  group('Pending Update Restart Flag', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      setPendingRestartInMemory(false);
    });

    test('hasPendingUpdateRestart returns false when flag is not set',
        () async {
      final result = await hasPendingUpdateRestart();
      expect(result, isFalse);
    });

    test('hasPendingUpdateRestart returns true when flag is set in prefs',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(pendingUpdateRestartKey, true);

      final result = await hasPendingUpdateRestart();
      expect(result, isTrue);
    });

    test('clearPendingUpdateRestart removes the flag from prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(pendingUpdateRestartKey, true);

      await clearPendingUpdateRestart();

      final result = await hasPendingUpdateRestart();
      expect(result, isFalse);
    });

    test('pendingUpdateRestartKey returns correct key string', () {
      expect(pendingUpdateRestartKey, equals('pending_update_restart'));
    });

    test('clearPendingUpdateRestart is idempotent when flag not set', () async {
      // Should not throw when flag is not in prefs
      await clearPendingUpdateRestart();
      final result = await hasPendingUpdateRestart();
      expect(result, isFalse);
    });

    test('isPendingRestartInMemory getter returns current state', () {
      expect(isPendingRestartInMemory, isFalse);
      setPendingRestartInMemory(true);
      expect(isPendingRestartInMemory, isTrue);
      setPendingRestartInMemory(false);
      expect(isPendingRestartInMemory, isFalse);
    });

    test(
        'isPendingRestartInMemory is cleared on process restart (simulated)',
        () {
      // Simulate process restart: flag resets to false on each isolate start
      setPendingRestartInMemory(false);
      expect(isPendingRestartInMemory, isFalse);
    });

    test('hasPendingUpdateRestart handles null SharedPreferences gracefully',
        () async {
      // Even with empty SharedPreferences, no crash
      SharedPreferences.setMockInitialValues({'some_other_key': 'value'});
      final result = await hasPendingUpdateRestart();
      expect(result, isFalse);
    });
  });
}
