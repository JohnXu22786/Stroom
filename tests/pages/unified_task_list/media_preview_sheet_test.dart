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

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await tester.pump();
  }
}

Future<void> _waitForFileDeletion(WidgetTester tester, File file) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 100 && file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pump();
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
      await _waitForFileDeletion(tester, previewFile);
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
      addTearDown(() async {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
        await videoPlatform.close();
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
      await _pumpUntil(
        tester,
        () => videoPlatform.videoEventsRequested.isCompleted,
      );
      expect(videoPlatform.videoEventsRequested.isCompleted, isTrue);
      videoPlatform.emitInitialized();
      await tester.pump();

      expect(previewFile, isNotNull);
      expect(previewFile!.existsSync(), isTrue);
      expect(videoPlatform.playerInitialized.isCompleted, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntil(tester, () => videoPlatform.disposeStarted.isCompleted);
      expect(videoPlatform.disposeStarted.isCompleted, isTrue);
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      await _waitForFileDeletion(tester, previewFile!);
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
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform();
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() async {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
        await videoPlatform.close();
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
      await _pumpUntil(
        tester,
        () => videoPlatform.videoEventsRequested.isCompleted,
      );
      expect(videoPlatform.videoEventsRequested.isCompleted, isTrue);
      videoPlatform.emitInitializationFailure();
      await _pumpUntil(tester, () => videoPlatform.disposeStarted.isCompleted);
      expect(videoPlatform.disposeStarted.isCompleted, isTrue);
      expect(previewFile!.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      await _waitForFileDeletion(tester, previewFile!);
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
      addTearDown(() async {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
        await videoPlatform.close();
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

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(previewFile, isNotNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(videoPlatform.pauseCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _waitForFileDeletion(tester, previewFile!);
      expect(previewFile!.existsSync(), isFalse);
    },
  );

  testWidgets('disposes a created player when initialization never completes', (
    tester,
  ) async {
    final temporaryDirectory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('media_preview_video_pending_'),
    );
    final tempDir = temporaryDirectory!;
    final previousPathProvider = PathProviderPlatform.instance;
    final previousVideoPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _BlockingDisposalVideoPlayerPlatform();
    PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
      tempDir.path,
    );
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() async {
      if (!videoPlatform.finishDispose.isCompleted) {
        videoPlatform.finishDispose.complete();
      }
      PathProviderPlatform.instance = previousPathProvider;
      VideoPlayerPlatform.instance = previousVideoPlatform;
      tempDir.deleteSync(recursive: true);
      await videoPlatform.close();
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
    await _pumpUntil(tester, () => videoPlatform.playerCreated.isCompleted);
    expect(videoPlatform.playerCreated.isCompleted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(tester, () => videoPlatform.disposeStarted.isCompleted);

    expect(videoPlatform.disposeStarted.isCompleted, isTrue);
    expect(previewFile!.existsSync(), isTrue);

    videoPlatform.finishDispose.complete();
    await _waitForFileDeletion(tester, previewFile!);
    expect(previewFile!.existsSync(), isFalse);
  });

  testWidgets(
    'cleans up when player creation returns no player and initialization fails',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_no_id_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        returnNullCreation: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      addTearDown(() async {
        if (!videoPlatform.finishDispose.isCompleted) {
          videoPlatform.finishDispose.complete();
        }
        PathProviderPlatform.instance = previousPathProvider;
        VideoPlayerPlatform.instance = previousVideoPlatform;
        tempDir.deleteSync(recursive: true);
        await videoPlatform.close();
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
      await _pumpUntil(tester, () => videoPlatform.playerCreated.isCompleted);
      expect(videoPlatform.playerCreated.isCompleted, isTrue);
      await _pumpUntil(
        tester,
        () => videoPlatform.videoEventsRequested.isCompleted,
      );
      expect(videoPlatform.videoEventsRequested.isCompleted, isTrue);
      videoPlatform.emitInitializationFailure();
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await _waitForFileDeletion(tester, previewFile!);
      expect(previewFile!.existsSync(), isFalse);
      expect(videoPlatform.disposeStarted.isCompleted, isTrue);
      expect(videoPlatform.finishDispose.isCompleted, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      videoPlatform.finishDispose.complete();
    },
  );
}

class _BlockingDisposalVideoPlayerPlatform extends VideoPlayerPlatform {
  _BlockingDisposalVideoPlayerPlatform({
    this.failCreation = false,
    this.returnNullCreation = false,
  });

  final bool failCreation;
  final bool returnNullCreation;
  final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast(sync: true);
  final Completer<void> disposeStarted = Completer<void>();
  final Completer<void> finishDispose = Completer<void>();
  final Completer<void> playerCreated = Completer<void>();
  final Completer<void> videoEventsRequested = Completer<void>();
  final Completer<void> playerInitialized = Completer<void>();
  int pauseCalls = 0;

  Future<void> close() => _events.close();

  void emitInitialized() {
    _events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 1),
        size: const Size(640, 360),
      ),
    );
    playerInitialized.complete();
  }

  void emitInitializationFailure() {
    _events.addError(
      PlatformException(code: 'init_failed', message: 'Initialization failed'),
    );
  }

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
    videoEventsRequested.complete();
    return _events.stream;
  }

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {
    pauseCalls++;
  }

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
