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
  await tester.pump();
  for (var i = 0; i < 100 && file.existsSync(); i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

Future<bool> _waitForSignal(
  WidgetTester tester,
  Completer<void> signal,
) async {
  for (var i = 0; i < 100 && !signal.isCompleted; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (!signal.isCompleted) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }
  return signal.isCompleted;
}

Future<void> _tearDownVideoTest({
  required WidgetTester tester,
  required _BlockingDisposalVideoPlayerPlatform videoPlatform,
  required PathProviderPlatform previousPathProvider,
  required VideoPlayerPlatform previousVideoPlatform,
  required Directory tempDir,
  File? previewFile,
}) async {
  try {
    await tester.pumpWidget(const SizedBox.shrink());
    if (!videoPlatform.finishDispose.isCompleted) {
      videoPlatform.finishDispose.complete();
    }
    if (videoPlatform.createStarted.isCompleted &&
        !videoPlatform.finishCreate.isCompleted) {
      videoPlatform.finishCreate.complete();
    }
    await tester.pump();

    final disposed = await tester.runAsync(() async {
      try {
        if (videoPlatform.createStarted.isCompleted) {
          await videoPlatform.createFinished.future.timeout(
            const Duration(seconds: 2),
          );
        }
        if (videoPlatform.playerCreated.isCompleted) {
          await videoPlatform.disposeStarted.future.timeout(
            const Duration(seconds: 2),
          );
          await videoPlatform.disposeFinished.future.timeout(
            const Duration(seconds: 2),
          );
        }
        if (previewFile != null) {
          for (var i = 0; i < 100 && previewFile.existsSync(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }
        return previewFile == null || !previewFile.existsSync();
      } on TimeoutException {
        return false;
      }
    });
    await tester.pump();
    expect(disposed, isTrue, reason: 'video preview cleanup did not finish');
  } finally {
    if (!videoPlatform.finishDispose.isCompleted) {
      videoPlatform.finishDispose.complete();
    }
    if (videoPlatform.createStarted.isCompleted &&
        !videoPlatform.finishCreate.isCompleted) {
      videoPlatform.finishCreate.complete();
    }
    try {
      await videoPlatform.close().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Keep shared plugin state isolated even if a broken subscription hangs.
    } finally {
      PathProviderPlatform.instance = previousPathProvider;
      VideoPlayerPlatform.instance = previousVideoPlatform;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  }
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
      File? previewFile;
      addTearDown(
        () => _tearDownVideoTest(
          tester: tester,
          videoPlatform: videoPlatform,
          previousPathProvider: previousPathProvider,
          previousVideoPlatform: previousVideoPlatform,
          tempDir: tempDir,
          previewFile: previewFile,
        ),
      );
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
      expect(
          await _waitForSignal(tester, videoPlatform.disposeStarted), isTrue);
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
      File? previewFile;
      addTearDown(
        () => _tearDownVideoTest(
          tester: tester,
          videoPlatform: videoPlatform,
          previousPathProvider: previousPathProvider,
          previousVideoPlatform: previousVideoPlatform,
          tempDir: tempDir,
          previewFile: previewFile,
        ),
      );
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
      await tester.pump();
      expect(
          await _waitForSignal(tester, videoPlatform.disposeStarted), isTrue);
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
      File? previewFile;
      addTearDown(
        () => _tearDownVideoTest(
          tester: tester,
          videoPlatform: videoPlatform,
          previousPathProvider: previousPathProvider,
          previousVideoPlatform: previousVideoPlatform,
          tempDir: tempDir,
          previewFile: previewFile,
        ),
      );
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

      expect(previewFile, isNotNull);
      await _waitForFileDeletion(tester, previewFile!);
      expect(previewFile!.existsSync(), isFalse);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(videoPlatform.pauseCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'cleans up when player creation fails after the sheet is closed',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp(
          'media_preview_video_create_pending_',
        ),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        failCreation: true,
        blockCreation: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      File? previewFile;
      addTearDown(
        () => _tearDownVideoTest(
          tester: tester,
          videoPlatform: videoPlatform,
          previousPathProvider: previousPathProvider,
          previousVideoPlatform: previousVideoPlatform,
          tempDir: tempDir,
          previewFile: previewFile,
        ),
      );

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
      expect(await _waitForSignal(tester, videoPlatform.createStarted), isTrue);
      expect(previewFile!.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(previewFile!.existsSync(), isTrue);
      videoPlatform.finishCreate.complete();
      expect(
          await _waitForSignal(tester, videoPlatform.createFinished), isTrue);
      await _waitForFileDeletion(tester, previewFile!);

      expect(previewFile!.existsSync(), isFalse);
      expect(videoPlatform.disposeStarted.isCompleted, isFalse);
    },
  );

  testWidgets(
    'waits for player setup before disposing an assigned player ID',
    (tester) async {
      final temporaryDirectory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_preview_video_setup_'),
      );
      final tempDir = temporaryDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
        blockDisplaySleepSetup: true,
      );
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDir.path,
      );
      VideoPlayerPlatform.instance = videoPlatform;
      File? previewFile;
      addTearDown(
        () => _tearDownVideoTest(
          tester: tester,
          videoPlatform: videoPlatform,
          previousPathProvider: previousPathProvider,
          previousVideoPlatform: previousVideoPlatform,
          tempDir: tempDir,
          previewFile: previewFile,
        ),
      );
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

      expect(
        await _waitForSignal(tester, videoPlatform.displaySleepSetupStarted),
        isTrue,
      );
      expect(videoPlatform.videoEventsRequested.isCompleted, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(previewFile!.existsSync(), isTrue);
      expect(videoPlatform.disposeStarted.isCompleted, isFalse);

      videoPlatform.finishDisplaySleepSetup.complete();
      expect(
        await _waitForSignal(
            tester, videoPlatform.videoEventSubscriptionStarted),
        isTrue,
      );
      expect(
          await _waitForSignal(tester, videoPlatform.disposeStarted), isTrue);
      expect(videoPlatform.disposedBeforeEventSubscription, isFalse);
      expect(previewFile!.existsSync(), isTrue);

      videoPlatform.finishDispose.complete();
      await _waitForFileDeletion(tester, previewFile!);
      expect(previewFile!.existsSync(), isFalse);
    },
  );

  testWidgets(
      'disposes a created negative-ID player when initialization never completes',
      (tester) async {
    final temporaryDirectory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('media_preview_video_pending_'),
    );
    final tempDir = temporaryDirectory!;
    final previousPathProvider = PathProviderPlatform.instance;
    final previousVideoPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _BlockingDisposalVideoPlayerPlatform(
      blockCreation: true,
      blockDisplaySleepSetup: true,
      creationPlayerId: -7,
    );
    PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
      tempDir.path,
    );
    VideoPlayerPlatform.instance = videoPlatform;
    File? previewFile;
    addTearDown(
      () => _tearDownVideoTest(
        tester: tester,
        videoPlatform: videoPlatform,
        previousPathProvider: previousPathProvider,
        previousVideoPlatform: previousVideoPlatform,
        tempDir: tempDir,
        previewFile: previewFile,
      ),
    );
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
    await _pumpUntil(tester, () => videoPlatform.createStarted.isCompleted);
    expect(videoPlatform.createStarted.isCompleted, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(previewFile!.existsSync(), isTrue);
    expect(videoPlatform.disposeStarted.isCompleted, isFalse);

    videoPlatform.finishCreate.complete();
    expect(await _waitForSignal(tester, videoPlatform.createFinished), isTrue);
    expect(
      await _waitForSignal(tester, videoPlatform.displaySleepSetupStarted),
      isTrue,
    );
    expect(videoPlatform.disposeStarted.isCompleted, isFalse);
    videoPlatform.finishDisplaySleepSetup.complete();
    expect(
      await _waitForSignal(tester, videoPlatform.videoEventSubscriptionStarted),
      isTrue,
    );
    expect(videoPlatform.displaySleepSetupCalls, 2);
    expect(await _waitForSignal(tester, videoPlatform.disposeStarted), isTrue);

    expect(videoPlatform.disposeStarted.isCompleted, isTrue);
    expect(videoPlatform.disposedBeforeEventSubscription, isFalse);
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
      File? previewFile;
      addTearDown(
        () => _tearDownVideoTest(
          tester: tester,
          videoPlatform: videoPlatform,
          previousPathProvider: previousPathProvider,
          previousVideoPlatform: previousVideoPlatform,
          tempDir: tempDir,
          previewFile: previewFile,
        ),
      );
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
      expect(
          await _waitForSignal(tester, videoPlatform.disposeStarted), isTrue);
      expect(previewFile!.existsSync(), isTrue);
      expect(videoPlatform.finishDispose.isCompleted, isFalse);

      videoPlatform.finishDispose.complete();
      await _waitForFileDeletion(tester, previewFile!);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(previewFile!.existsSync(), isFalse);
    },
  );
}

class _BlockingDisposalVideoPlayerPlatform extends VideoPlayerPlatform {
  _BlockingDisposalVideoPlayerPlatform({
    this.failCreation = false,
    this.returnNullCreation = false,
    this.blockCreation = false,
    this.blockDisplaySleepSetup = false,
    this.creationPlayerId = 1,
  });

  final bool failCreation;
  final bool returnNullCreation;
  final bool blockCreation;
  final bool blockDisplaySleepSetup;
  final int creationPlayerId;
  final Completer<void> disposeStarted = Completer<void>();
  final Completer<void> finishDispose = Completer<void>();
  final Completer<void> disposeFinished = Completer<void>();
  final Completer<void> playerCreated = Completer<void>();
  final Completer<void> createStarted = Completer<void>();
  final Completer<void> finishCreate = Completer<void>();
  final Completer<void> createFinished = Completer<void>();
  final Completer<void> videoEventsRequested = Completer<void>();
  final Completer<void> videoEventSubscriptionStarted = Completer<void>();
  final Completer<void> displaySleepSetupStarted = Completer<void>();
  final Completer<void> finishDisplaySleepSetup = Completer<void>();
  final Completer<void> playerInitialized = Completer<void>();
  late final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast(
    sync: true,
    onListen: () {
      if (!videoEventSubscriptionStarted.isCompleted) {
        videoEventSubscriptionStarted.complete();
      }
    },
  );
  int pauseCalls = 0;
  int _displaySleepSetupCalls = 0;
  bool disposedBeforeEventSubscription = false;

  int get displaySleepSetupCalls => _displaySleepSetupCalls;

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
    if (blockCreation) {
      createStarted.complete();
      await finishCreate.future;
    }
    try {
      if (failCreation) {
        throw PlatformException(
          code: 'create_failed',
          message: 'Player creation failed',
        );
      }
      playerCreated.complete();
      if (returnNullCreation) return null;
      return creationPlayerId;
    } finally {
      createFinished.complete();
    }
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
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {
    _displaySleepSetupCalls++;
    if (blockDisplaySleepSetup) {
      if (!displaySleepSetupStarted.isCompleted) {
        displaySleepSetupStarted.complete();
      }
      await finishDisplaySleepSetup.future;
    }
  }

  @override
  Future<void> dispose(int playerId) async {
    disposedBeforeEventSubscription =
        !videoEventSubscriptionStarted.isCompleted;
    disposeStarted.complete();
    try {
      await finishDispose.future;
    } finally {
      disposeFinished.complete();
    }
  }
}
