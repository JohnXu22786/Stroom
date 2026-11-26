import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/video_player_cleanup.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FailedCreationPlatform extends VideoPlayerPlatform {
  int disposeCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    throw PlatformException(code: 'create_failed');
  }

  @override
  Future<void> dispose(int playerId) async {
    disposeCalls++;
  }
}

void main() {
  testWidgets('failed creation cleanup does not await an uncreated player', (
    tester,
  ) async {
    final originalPlatform = VideoPlayerPlatform.instance;
    final platform = _FailedCreationPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);

    final controller = VideoPlayerController.file(
      File('unreadable-video.mp4'),
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    await expectLater(
      controller.initialize(),
      throwsA(isA<PlatformException>()),
    );

    final cleanupCompleted = await tester.runAsync(() async {
      try {
        await disposeVideoPlayerAfterInitializationFailure(controller)
            .timeout(const Duration(milliseconds: 100));
        return true;
      } on TimeoutException {
        return false;
      }
    });
    expect(cleanupCompleted, isTrue);
    expect(platform.disposeCalls, 0);
  });
}
