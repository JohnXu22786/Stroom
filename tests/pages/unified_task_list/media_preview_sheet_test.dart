import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _TemporaryDirectoryPathProvider extends PathProviderPlatform {
  _TemporaryDirectoryPathProvider(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'removes downloaded preview file when sheet is disposed mid-download',
    (tester) async {
      Directory? tempDirectory;
      await tester.runAsync(() async {
        tempDirectory = await Directory.systemTemp.createTemp('media_preview_');
      });
      final temporaryDirectory = tempDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        temporaryDirectory.path,
      );
      final downloadStarted = Completer<File>();
      final finishDownload = Completer<void>();
      addTearDown(() {
        if (!finishDownload.isCompleted) finishDownload.complete();
        PathProviderPlatform.instance = previousPathProvider;
        temporaryDirectory.deleteSync(recursive: true);
      });

      Widget previewWidget() => ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MediaPreviewSheet(
                  resource: MediaResource(
                    url: 'https://example.com/preview.mp4',
                    name: 'sample',
                    ext: 'mp4',
                  ),
                  taskTitle: 'Preview',
                  downloadToFile: (_, file) {
                    downloadStarted.complete(file);
                    return finishDownload.future;
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(previewWidget());
      await tester.pump();
      expect(downloadStarted.isCompleted, isTrue);
      final previewFile = await downloadStarted.future;

      await tester.pumpWidget(const SizedBox.shrink());
      expect(previewFile.existsSync(), isFalse);
      previewFile.writeAsBytesSync([1, 2, 3, 4]);
      expect(previewFile.existsSync(), isTrue);

      finishDownload.complete();
      await tester.pump();
      for (var i = 0; i < 100 && previewFile.existsSync(); i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pump();
      expect(previewFile.existsSync(), isFalse);
    },
  );

  testWidgets(
    'waits for video player disposal before deleting downloaded preview file',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform();
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
      });

      File? previewFile;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaPreviewSheet(
                resource: MediaResource(
                  url: 'https://example.com/preview.mp4',
                  name: 'sample',
                  ext: 'mp4',
                ),
                taskTitle: 'Preview',
                downloadToFile: (_, file) async {
                  previewFile = file;
                  file.writeAsBytesSync([1, 2, 3, 4]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await videoPlatform.playerInitialized.future;

      expect(previewFile, isNotNull);
      expect(previewFile!.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await videoPlatform.disposeStarted.future;
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      for (var i = 0; i < 100 && previewFile!.existsSync(); i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(previewFile!.existsSync(), isFalse);
    },
  );

  testWidgets(
    'waits for failed video initialization cleanup before deleting preview',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_error_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        failInitialization: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
      });

      File? previewFile;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaPreviewSheet(
                resource: MediaResource(
                  url: 'https://example.com/preview.mp4',
                  name: 'sample',
                  ext: 'mp4',
                ),
                taskTitle: 'Preview',
                downloadToFile: (_, file) async {
                  previewFile = file;
                  file.writeAsBytesSync([1, 2, 3, 4]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await videoPlatform.disposeStarted.future;
      expect(previewFile!.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      for (var i = 0; i < 100 && previewFile!.existsSync(); i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(previewFile!.existsSync(), isFalse);
    },
  );

  testWidgets(
    'reports create failure and deletes the downloaded preview file',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_create_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        failCreation: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
      });

      File? previewFile;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaPreviewSheet(
                resource: MediaResource(
                  url: 'https://example.com/preview.mp4',
                  name: 'sample',
                  ext: 'mp4',
                ),
                taskTitle: 'Preview',
                downloadToFile: (_, file) async {
                  previewFile = file;
                  file.writeAsBytesSync([1, 2, 3, 4]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(previewFile, isNotNull);
      expect(previewFile!.existsSync(), isFalse);
    },
  );

  testWidgets(
    'disposes a created player when initialization never completes',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_pending_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        neverInitialize: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
      });

      File? previewFile;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaPreviewSheet(
                resource: MediaResource(
                  url: 'https://example.com/preview.mp4',
                  name: 'sample',
                  ext: 'mp4',
                ),
                taskTitle: 'Preview',
                downloadToFile: (_, file) async {
                  previewFile = file;
                  file.writeAsBytesSync([1, 2, 3, 4]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await videoPlatform.playerCreated.future;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 && !videoPlatform.disposeStarted.isCompleted;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      expect(videoPlatform.disposeStarted.isCompleted, isTrue);
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && previewFile!.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(previewFile!.existsSync(), isFalse);
    },
  );

  testWidgets(
    'cleans up when player creation returns no player and initialization hangs',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_no_id_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        neverInitialize: true,
        returnNullCreation: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
      });

      File? previewFile;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaPreviewSheet(
                resource: MediaResource(
                  url: 'https://example.com/preview.mp4',
                  name: 'sample',
                  ext: 'mp4',
                ),
                taskTitle: 'Preview',
                downloadToFile: (_, file) async {
                  previewFile = file;
                  file.writeAsBytesSync([1, 2, 3, 4]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await videoPlatform.playerCreated.future;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 && !videoPlatform.disposeStarted.isCompleted;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      expect(videoPlatform.disposeStarted.isCompleted, isTrue);
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && previewFile!.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(previewFile!.existsSync(), isFalse);
    },
  );
}

class _BlockingDisposalVideoPlayerPlatform extends VideoPlayerPlatform {
  _BlockingDisposalVideoPlayerPlatform({
    this.failCreation = false,
    this.failInitialization = false,
    this.neverInitialize = false,
    this.returnNullCreation = false,
  });

  final bool failCreation;
  final bool failInitialization;
  final bool neverInitialize;
  final bool returnNullCreation;
  final Completer<void> disposeStarted = Completer<void>();
  final Completer<void> finishDispose = Completer<void>();
  final Completer<void> playerCreated = Completer<void>();
  final Completer<void> playerInitialized = Completer<void>();

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (failCreation) {
      throw PlatformException(
        code: 'create_failed',
        message: 'Player creation failed',
      );
    }
    playerCreated.complete();
    if (returnNullCreation) return null;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (failInitialization) {
      return Stream.error(
        PlatformException(
          code: 'init_failed',
          message: 'Initialization failed',
        ),
      );
    }
    if (neverInitialize) return const Stream.empty();
    return Stream.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 1),
        size: const Size(640, 360),
      ),
    ).map((event) {
      playerInitialized.complete();
      return event;
    });
  }

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> dispose(int playerId) async {
    disposeStarted.complete();
    await finishDispose.future;
  }
}
