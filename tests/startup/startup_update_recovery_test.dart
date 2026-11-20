import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/startup_update_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'update attempt is usable only when target and source are exact',
    () async {
      await StartupUpdateAttempt.record(
        sourceVersion: '0.5.3-hotfix.1',
        targetVersion: '0.5.4-rc.2',
      );

      final attempt = await StartupUpdateAttempt.load();

      expect(attempt?.sourceVersion, '0.5.3-hotfix.1');
      expect(attempt?.targetVersion, '0.5.4-rc.2');
      expect(
        attempt?.matchesFrozenTarget(
          frozenByVersion: '0.5.4-rc.2',
          runningVersion: '0.5.4-rc.2',
        ),
        isTrue,
      );
      expect(
        attempt?.matchesFrozenTarget(
          frozenByVersion: '0.5.4',
          runningVersion: '0.5.4-rc.2',
        ),
        isFalse,
        reason: 'suffixes distinguish an update attempt from another build',
      );
    },
  );

  test('missing or incomplete update attempt is ignored', () async {
    expect(await StartupUpdateAttempt.load(), isNull);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StartupUpdateAttempt.storageKey,
      '{"sourceVersion":"0.5.3"}',
    );
    expect(await StartupUpdateAttempt.load(), isNull);
  });

  test(
    'rollback candidate needs exact source release and direct platform asset',
    () {
      final candidate = StartupRollbackCandidate.fromReleases(
        sourceVersion: '0.5.3-hotfix.1',
        platformKey: 'windows',
        releases: [
          _release(
            '0.5.3',
            url:
                'https://github.com/a/b/releases/download/v0.5.3/a-windows.exe',
          ),
          _release(
            '0.5.3-hotfix.1',
            url: 'https://github.com/a/b/releases/tag/v0.5.3-hotfix.1',
          ),
          _release(
            '0.5.3-hotfix.1',
            url:
                'https://github.com/a/b/releases/download/v0.5.3-hotfix.1/a-windows.exe',
          ),
        ],
      );

      expect(candidate?.version, '0.5.3-hotfix.1');
      expect(candidate?.downloadUrl, contains('/releases/download/'));
    },
  );

  test('rollback candidate rejects malformed source and nonmatching assets',
      () {
    expect(
      StartupRollbackCandidate.fromReleases(
        sourceVersion: 'dev',
        platformKey: 'windows',
        releases: [
          _release(
            '0.1.0',
            url:
                'https://github.com/a/b/releases/download/v0.1.0/a-windows.exe',
          ),
        ],
      ),
      isNull,
    );
    expect(
      StartupRollbackCandidate.fromReleases(
        sourceVersion: '0.5.3',
        platformKey: 'windows',
        releases: [
          _release('0.5.3', url: 'https://github.com/a/b/releases/tag/v0.5.3'),
        ],
      ),
      isNull,
    );
  });
}

Map<String, Object?> _release(String version, {required String url}) => {
      'tag_name': 'v$version',
      'body': 'Notes for $version',
      'assets': [
        {'name': 'stroom-windows.exe', 'browser_download_url': url},
      ],
    };
