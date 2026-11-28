import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/video_gallery_shared.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maps 3GPP file extensions to browser MIME types', () {
    expect(videoMimeTypeForPath('videos/sample.3gp'), 'video/3gpp');
    expect(videoMimeTypeForPath('videos/sample.3gpp'), 'video/3gpp');
  });

  test('maps ambiguous web video containers to browser MIME types', () {
    expect(videoMimeTypeForPath('videos/sample.mov'), 'video/quicktime');
    expect(videoMimeTypeForPath('videos/sample.flv'), 'video/x-flv');
    expect(videoMimeTypeForPath('videos/sample.avi'), 'video/x-msvideo');
    expect(videoMimeTypeForPath('videos/sample.mpeg'), 'video/mpeg');
    expect(videoMimeTypeForPath('videos/sample.mpg'), 'video/mpeg');
  });

  testWidgets(
    'disposal during initialization does not create a late Chewie controller',
    (tester) async {
      final controller = _PendingVideoPlayerController();
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  PageRouteBuilder<void>(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) => VideoPlayerPage(
                      filePath: '/videos/sample.mp4',
                      displayName: 'sample-video.mp4',
                      controllerFactory: (_) => controller,
                    ),
                  ),
                ),
                child: const Text('open video'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open video'));
      await tester.pump();
      expect(controller.initializeCalls, 1);

      navigatorKey.currentState!.pop();
      await tester.pump();
      expect(controller.disposeCalls, 1);

      controller.finishInitialization.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(VideoPlayerPage), findsNothing);
      expect(controller.playCalls, 0);
      expect(controller.disposeCalls, 1);
      expect(tester.takeException(), isNull);
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

class _PendingVideoPlayerController extends VideoPlayerController {
  _PendingVideoPlayerController() : super.file(File('/videos/sample.mp4'));

  final Completer<void> finishInitialization = Completer<void>();
  int initializeCalls = 0;
  int disposeCalls = 0;
  int playCalls = 0;

  @override
  Future<void> initialize() {
    initializeCalls++;
    return finishInitialization.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await super.dispose();
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> play() async {
    playCalls++;
  }
}
