import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/video_gallery_shared.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.error(
        PlatformException(
            code: 'video_init_failed', message: 'fixture failure'),
      );

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool value,
  ) async {}

  @override
  Future<void> dispose(int playerId) async {}
}
