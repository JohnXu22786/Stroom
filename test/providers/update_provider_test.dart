import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/update_provider.dart';

/// Creates a mock [Dio] that intercepts all requests and returns [jsonResponse].
Dio _createMockDio(String jsonResponse) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: jsonResponse,
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
String _githubRelease(String tagName, {String body = '', String? htmlUrl}) {
  htmlUrl ??= 'https://github.com/JohnXu22786/Stroom/releases/tag/$tagName';
  return '''
{
  "tag_name": "$tagName",
  "body": "$body",
  "html_url": "$htmlUrl"
}
''';
}

void main() {
  group('Version', () {
    test('parse standard semver "0.2.12"', () {
      final v = Version.parse('0.2.12');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
    });

    test('parse with v prefix "v0.2.12"', () {
      final v = Version.parse('v0.2.12');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
    });

    test('parse with build metadata "0.2.12+1"', () {
      final v = Version.parse('0.2.12+1');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
    });

    test('parse with pre-release "0.2.12-alpha"', () {
      final v = Version.parse('0.2.12-alpha');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 12);
    });

    test('parse empty string defaults to 0.0.0', () {
      final v = Version.parse('');
      expect(v.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('parse non-numeric parts defaults to 0', () {
      final v = Version.parse('x.y.z');
      expect(v.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('0.2.14 > 0.2.13', () {
      final a = Version.parse('0.2.14');
      final b = Version.parse('0.2.13');
      expect(a > b, true);
    });

    test('0.2.13 == 0.2.13', () {
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
        'update_available_data': '{"latest_version":"0.2.14","release_notes":"","download_url":"https://github.com/JohnXu22786/Stroom/releases"}',
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
  });
}
