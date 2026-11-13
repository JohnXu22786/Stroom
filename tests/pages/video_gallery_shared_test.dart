import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/video_gallery_shared.dart';
import 'package:stroom/utils/web_file_store.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'plays a WebFileStore video through a blob URL on web',
    skip: !kIsWeb,
    (tester) async {
      final previousPlatform = VideoPlayerPlatform.instance;
      final platform = _FailingVideoPlayerPlatform();
      VideoPlayerPlatform.instance = platform;
      WebFileStore.enableTestMode();
      addTearDown(() {
        VideoPlayerPlatform.instance = previousPlatform;
        WebFileStore.disableTestMode();
      });
      await WebFileStore.write(
        'videos/sample.3gp',
        Uint8List.fromList([0, 1, 2, 3]),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerPage(
            filePath: 'videos/sample.3gp',
            displayName: 'sample.3gp',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(videoMimeTypeForPath('videos/sample.3gp'), 'video/3gpp');
      expect(videoMimeTypeForPath('videos/sample.3gpp'), 'video/3gpp');
      expect(platform.dataSource?.sourceType, DataSourceType.network);
      expect(platform.dataSource?.uri, startsWith('blob:'));
    },
  );

  for (final testCase in [
    (locale: const Locale('en'), error: 'Could not load video'),
    (locale: const Locale('zh', 'CN'), error: '无法加载视频'),
  ]) {
    testWidgets(
      'video initialization failure uses ${testCase.locale.languageCode} copy and keeps display name',
      (tester) async {
        final previousPlatform = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = _FailingVideoPlayerPlatform();
        addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);

        await tester.pumpWidget(
          MaterialApp(
            locale: testCase.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const VideoPlayerPage(
              filePath: '/missing/video.mp4',
              displayName: 'sample-video.mp4',
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(testCase.error), findsOneWidget);
        expect(find.text('sample-video.mp4'), findsOneWidget);
      },
    );
  }
}

class _FailingVideoPlayerPlatform extends VideoPlayerPlatform {
  DataSource? dataSource;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    dataSource = options.dataSource;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.error(
    PlatformException(code: 'video_init_failed', message: 'fixture failure'),
  );

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool value,
  ) async {}

  @override
  Future<void> dispose(int playerId) async {}
}
