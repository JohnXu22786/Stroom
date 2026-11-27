import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/playlist_merged_extensions.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

class _PlaylistAdapter implements HttpClientAdapter {
  _PlaylistAdapter(this.playlists);

  final Map<String, String> playlists;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final content = playlists[options.uri.toString()];
    if (content == null) {
      return ResponseBody.fromString(
        'Playlist not found',
        404,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    return ResponseBody.fromString(
      content,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/vnd.apple.mpegurl'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _HeldPlaylistAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (!started.isCompleted) started.complete();
    cancelFuture?.then((_) {
      if (!response.isCompleted) {
        response.completeError(
          DioException(requestOptions: options, type: DioExceptionType.cancel),
        );
      }
    });
    return response.future;
  }

  void release() {
    if (!response.isCompleted) {
      response.complete(
        ResponseBody.fromString(
          '#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n#EXT-X-ENDLIST',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/vnd.apple.mpegurl'],
          },
        ),
      );
    }
  }

  @override
  void close({bool force = false}) {}
}

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fails encrypted HLS before treating downloaded ciphertext as media',
    () async {
      const playlistUrl = 'https://example.com/encrypted.m3u8';
      const playlist = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
encrypted-segment.ts
#EXT-X-ENDLIST
''';
      final task = CatCatchTask(
        id: 'encrypted-hls',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'encrypted',
            ext: 'm3u8',
            isPlaylist: true,
          ),
        ],
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.parsingPlaylist)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      final cancelToken = CancelToken();
      CatCatchTask? finalTask;

      try {
        await TaskExecutor.retryFromStep(
          task: task,
          fromStep: StepType.parsingPlaylist,
          cancelToken: cancelToken,
          playlistDioFactory: () => Dio()
            ..httpClientAdapter = _PlaylistAdapter({playlistUrl: playlist}),
          onUpdate: (updated) {
            finalTask = updated;
            final parsing = updated.steps.firstWhere(
              (step) => step.type == StepType.parsingPlaylist,
            );
            if (parsing.completed) cancelToken.cancel();
          },
        );
      } finally {
        cancelToken.cancel();
      }

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('encrypted'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.parsingPlaylist)
            .failed,
        isTrue,
      );
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .completed,
        isFalse,
      );
    },
  );

  test(
    'keeps direct media selectable when an initial HLS option is encrypted',
    () async {
      const playlistUrl = 'https://example.com/encrypted.m3u8';
      const directUrl = 'https://example.com/direct.mp4';
      final task = CatCatchTask(
        id: 'encrypted-hls-with-direct-media',
        url: 'https://example.com/page',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'encrypted',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          const MediaResource(
            url: directUrl,
            name: 'direct',
            ext: 'mp4',
          ),
        ],
        metadata: const {'deferSingleResourceSelection': 'true'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.parsingPlaylist)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.parsingPlaylist,
        playlistDioFactory: () => Dio()
          ..httpClientAdapter = _PlaylistAdapter({
            playlistUrl: '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
encrypted-segment.ts
#EXT-X-ENDLIST
''',
          }),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.running);
      expect(finalTask!.error, isNull);
      expect(finalTask!.selectedMedia, isNull);
      expect(finalTask!.detectedMedia.map((media) => media.url), [directUrl]);
    },
  );

  test(
    'rejects saved encrypted HLS segments when retry starts at download',
    () async {
      const playlistUrl = 'https://example.com/encrypted.m3u8';
      const segmentUrl = 'https://example.com/segment.ts';
      const playlist = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
encrypted-segment.ts
#EXT-X-ENDLIST
''';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'encrypted-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'encrypted-hls-download-retry',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'encrypted',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.downloading,
        playlistDioFactory: () => Dio()
          ..httpClientAdapter = _PlaylistAdapter({playlistUrl: playlist}),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('encrypted'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .failed,
        isTrue,
      );
    },
  );

  test(
    'cancels a retry while HLS playlist revalidation is pending',
    () async {
      const playlistUrl = 'https://example.com/retry-cancel.m3u8';
      const segmentUrl = 'https://example.com/segment.ts';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'hls-retry-cancel',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'playlist',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      final cancelToken = CancelToken();
      final adapter = _HeldPlaylistAdapter();
      final updates = <CatCatchTask>[];
      final retry = TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.downloading,
        cancelToken: cancelToken,
        playlistDioFactory: () => Dio()..httpClientAdapter = adapter,
        onUpdate: updates.add,
      );

      await adapter.started.future.timeout(const Duration(seconds: 1));
      cancelToken.cancel('retry cancelled');

      try {
        expect(await retry.timeout(const Duration(milliseconds: 250)), isNull);
      } finally {
        adapter.release();
      }

      expect(updates, hasLength(1));
      expect(updates.single.status, TaskStatus.running);
      expect(updates.single.steps.any((step) => step.failed), isFalse);
    },
  );

  test(
    'skips playlist parsing when cancellation arrives with the response',
    () async {
      const originalReferer = 'https://source.example/video';
      final variantServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final variantUrl =
          'http://${variantServer.address.address}:${variantServer.port}/variant.m3u8';
      const playlistUrl = 'https://example.com/cancel-after-response.m3u8';
      const segmentUrl = 'https://example.com/saved-segment.ts';
      var variantRequests = 0;
      final serverRequests = variantServer.listen((request) async {
        variantRequests++;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n#EXT-X-ENDLIST');
        await request.response.close();
      });
      final master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
$variantUrl
''';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'saved-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'hls-retry-cancel-after-master-response',
        url: originalReferer,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'master',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      final cancelToken = CancelToken();
      final dio = Dio()
        ..httpClientAdapter = _PlaylistAdapter({playlistUrl: master});
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            cancelToken.cancel('retry cancelled after master response');
            handler.next(response);
          },
        ),
      );
      final updates = <CatCatchTask>[];

      try {
        await HttpOverrides.runWithHttpOverrides(
          () => TaskExecutor.retryFromStep(
            task: task,
            fromStep: StepType.downloading,
            cancelToken: cancelToken,
            playlistDioFactory: () => dio,
            onUpdate: updates.add,
          ),
          _RealHttpOverrides(),
        );
      } finally {
        await serverRequests.cancel();
        await variantServer.close(force: true);
      }

      expect(variantRequests, 0);
      expect(updates, hasLength(1));
      expect(updates.single.status, TaskStatus.running);
      expect(updates.single.steps.any((step) => step.failed), isFalse);
    },
  );

  test(
    'cancels retry while a variant playlist response is held',
    () async {
      final variantServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestReceived = Completer<void>();
      final releaseResponse = Completer<void>();
      final variantUrl =
          'http://${variantServer.address.address}:${variantServer.port}/variant.m3u8';
      const playlistUrl = 'https://example.com/held-child-master.m3u8';
      const segmentUrl = 'https://example.com/saved-segment.ts';
      final serverRequests = variantServer.listen((request) async {
        if (!requestReceived.isCompleted) requestReceived.complete();
        await releaseResponse.future;
        try {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write('#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n#EXT-X-ENDLIST');
          await request.response.close();
        } on SocketException {
          // The retry cancels the held child request before the response is released.
        }
      });
      final master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
$variantUrl
''';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'saved-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'hls-retry-cancel-held-child',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'master',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      final cancelToken = CancelToken();
      final updates = <CatCatchTask>[];
      final retry = HttpOverrides.runWithHttpOverrides(
        () => TaskExecutor.retryFromStep(
          task: task,
          fromStep: StepType.downloading,
          cancelToken: cancelToken,
          playlistDioFactory: () => Dio()
            ..httpClientAdapter = _PlaylistAdapter({playlistUrl: master}),
          onUpdate: updates.add,
        ),
        _RealHttpOverrides(),
      );

      try {
        await requestReceived.future.timeout(const Duration(seconds: 1));
        cancelToken.cancel('retry cancelled during child playlist fetch');
        expect(await retry.timeout(const Duration(milliseconds: 250)), isNull);
      } finally {
        if (!releaseResponse.isCompleted) releaseResponse.complete();
        await serverRequests.cancel();
        await variantServer.close(force: true);
      }

      expect(updates, hasLength(1));
      expect(updates.single.status, TaskStatus.running);
      expect(updates.single.steps.any((step) => step.failed), isFalse);
    },
  );

  test(
    'does not block selection while encrypted HLS remains unselected',
    () async {
      const playlistUrl = 'https://example.com/encrypted.m3u8';
      final task = CatCatchTask(
        id: 'encrypted-hls-selection-pending',
        url: 'https://example.com/page',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'encrypted',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          const MediaResource(
            url: 'https://example.com/encrypted-segment.ts',
            name: 'encrypted-segment',
            ext: 'ts',
            initiator: playlistUrl,
            isPlayable: false,
          ),
          const MediaResource(
            url: 'https://example.com/direct.mp4',
            name: 'direct',
            ext: 'mp4',
          ),
        ],
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.userSelecting)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.userSelecting,
        playlistDioFactory: () => Dio()
          ..httpClientAdapter = _PlaylistAdapter({
            playlistUrl: '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
encrypted-segment.ts
#EXT-X-ENDLIST
''',
          }),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.running);
      expect(finalTask!.selectedMedia, isNull);
      expect(finalTask!.error, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.userSelecting)
            .failed,
        isFalse,
      );
    },
  );

  test(
    'rejects a login page when verifying a saved HLS playlist',
    () async {
      const playlistUrl = 'https://example.com/encrypted.m3u8';
      const segmentUrl = 'https://example.com/segment.ts';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'encrypted-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'encrypted-hls-retry-login-page',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'encrypted',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.downloading,
        playlistDioFactory: () => Dio()
          ..httpClientAdapter = _PlaylistAdapter({
            playlistUrl: '<html>Sign in to continue</html>',
          }),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('invalid response'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .failed,
        isTrue,
      );
    },
  );

  test(
    'rejects an empty saved HLS playlist when verifying a retry',
    () async {
      const playlistUrl = 'https://example.com/encrypted.m3u8';
      const segmentUrl = 'https://example.com/segment.ts';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'encrypted-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'encrypted-hls-retry-empty-playlist',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'encrypted',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.downloading,
        playlistDioFactory: () => Dio()
          ..httpClientAdapter = _PlaylistAdapter({playlistUrl: '#EXTM3U'}),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('no media resources'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .failed,
        isTrue,
      );
    },
  );

  test(
    'rejects an HLS map without media segments when retrying saved segments',
    () async {
      const playlistUrl = 'https://example.com/playlist.m3u8';
      const segmentUrl = 'https://example.com/stale-segment.ts';
      final staleSegment = MediaResource(
        url: segmentUrl,
        name: 'stale-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'hls-map-only-retry-with-stale-segment',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'playlist',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          staleSegment,
        ],
        selectedMedia: staleSegment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.downloading,
        playlistDioFactory: () => Dio()
          ..httpClientAdapter = _PlaylistAdapter({
            playlistUrl: '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXT-X-ENDLIST
''',
          }),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('no media resources'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .failed,
        isTrue,
      );
    },
  );

  test(
    'rejects a non-playlist response from a variant during retry validation',
    () async {
      const originalReferer = 'https://source.example/video';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final variantUrl =
          'http://${server.address.address}:${server.port}/variant.m3u8';
      final playlistUrl = 'https://example.com/master.m3u8';
      final segmentUrl = 'https://example.com/segment.ts';
      final serverDone = server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('<html>Sign in to continue</html>');
        await request.response.close();
      });
      final master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
$variantUrl
''';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'saved-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'encrypted-hls-retry-invalid-variant',
        url: originalReferer,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'master',
            ext: 'm3u8',
            initiator: originalReferer,
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      try {
        await HttpOverrides.runWithHttpOverrides(
          () => TaskExecutor.retryFromStep(
            task: task,
            fromStep: StepType.downloading,
            playlistDioFactory: () => Dio()
              ..httpClientAdapter = _PlaylistAdapter({playlistUrl: master}),
            onUpdate: (updated) => finalTask = updated,
          ),
          _RealHttpOverrides(),
        );
      } finally {
        await serverDone.cancel();
        await server.close(force: true);
      }

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('invalid hls playlist'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .failed,
        isTrue,
      );
    },
  );

  test(
    'rejects a cyclic HLS variant when validating a retry',
    () async {
      const playlistUrl = 'https://example.com/self-referencing.m3u8';
      const segmentUrl = 'https://example.com/saved-segment.ts';
      final master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
$playlistUrl
''';
      final savedSegment = MediaResource(
        url: segmentUrl,
        name: 'saved-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'hls-retry-cyclic-variant',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'master',
            ext: 'm3u8',
            isPlaylist: true,
          ),
          savedSegment,
        ],
        selectedMedia: savedSegment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.downloading,
        playlistDioFactory: () =>
            Dio()..httpClientAdapter = _PlaylistAdapter({playlistUrl: master}),
        onUpdate: (updated) => finalTask = updated,
      );

      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('cyclic variant url'));
      expect(finalTask!.downloadedFilePath, isNull);
      expect(
        finalTask!.steps
            .firstWhere((step) => step.type == StepType.downloading)
            .failed,
        isTrue,
      );
    },
  );

  test(
    'uses the original initiator as variant referer during HLS retry check',
    () async {
      const originalReferer = 'https://source.example/video';
      const variant = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
encrypted-segment.ts
#EXT-X-ENDLIST
''';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final playlistUrl =
          'http://${server.address.address}:${server.port}/master.m3u8';
      final variantUrl =
          'http://${server.address.address}:${server.port}/variant.m3u8';
      final segmentUrl =
          'http://${server.address.address}:${server.port}/segment.ts';
      String? observedVariantReferer;
      final serverDone = server.listen((request) async {
        observedVariantReferer = request.headers.value(
          HttpHeaders.refererHeader,
        );
        request.response
          ..statusCode = observedVariantReferer == originalReferer
              ? HttpStatus.ok
              : HttpStatus.forbidden
          ..headers.contentType = ContentType.text
          ..write(observedVariantReferer == originalReferer
              ? variant
              : 'Forbidden');
        await request.response.close();
      });
      final master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
$variantUrl
''';
      final segment = MediaResource(
        url: segmentUrl,
        name: 'encrypted-segment',
        ext: 'ts',
        initiator: playlistUrl,
        isPlayable: false,
      );
      final task = CatCatchTask(
        id: 'encrypted-hls-retry-variant-referer',
        url: originalReferer,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          MediaResource(
            url: playlistUrl,
            name: 'master',
            ext: 'm3u8',
            initiator: originalReferer,
            isPlaylist: true,
          ),
          segment,
        ],
        selectedMedia: segment,
        metadata: const {'resumeSupported': 'false'},
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.downloading)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? finalTask;

      try {
        await HttpOverrides.runWithHttpOverrides(
          () => TaskExecutor.retryFromStep(
            task: task,
            fromStep: StepType.downloading,
            playlistDioFactory: () => Dio()
              ..httpClientAdapter = _PlaylistAdapter({playlistUrl: master}),
            onUpdate: (updated) => finalTask = updated,
          ),
          _RealHttpOverrides(),
        );
      } finally {
        await serverDone.cancel();
        await server.close(force: true);
      }

      expect(observedVariantReferer, originalReferer);
      expect(finalTask, isNotNull);
      expect(finalTask!.status, TaskStatus.failed);
      expect(finalTask!.error!.toLowerCase(), contains('encrypted'));
      expect(finalTask!.downloadedFilePath, isNull);
    },
  );

  test('keeps the merged container extension for each playlist', () async {
    const transportUrl = 'https://example.com/transport.m3u8';
    const fragmentedUrl = 'https://example.com/fragmented.m3u8';
    final playlists = {
      transportUrl: '''
#EXTM3U
#EXTINF:4.0,
transport.ts
#EXT-X-ENDLIST
''',
      fragmentedUrl: '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXTINF:4.0,
fragment.m4s
#EXT-X-ENDLIST
''',
    };
    final task = CatCatchTask(
      id: 'mixed-playlists',
      url: 'https://example.com',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      detectedMedia: [
        MediaResource(
          url: transportUrl,
          name: 'transport',
          ext: 'm3u8',
          isPlaylist: true,
        ),
        MediaResource(
          url: fragmentedUrl,
          name: 'fragmented',
          ext: 'm3u8',
          isPlaylist: true,
        ),
      ],
      steps: [
        for (final type in StepType.values)
          type.index < StepType.values.indexOf(StepType.parsingPlaylist)
              ? StepStatus.done(type)
              : StepStatus.pending(type),
      ],
    );
    final cancelToken = CancelToken();
    CatCatchTask? parsedTask;

    try {
      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.parsingPlaylist,
        cancelToken: cancelToken,
        playlistDioFactory: () =>
            Dio()..httpClientAdapter = _PlaylistAdapter(playlists),
        onUpdate: (updated) {
          final parsing = updated.steps.firstWhere(
            (step) => step.type == StepType.parsingPlaylist,
          );
          if (parsing.completed) {
            parsedTask = updated;
            cancelToken.cancel();
          }
        },
      );
    } finally {
      cancelToken.cancel();
    }

    final playlistExtensions =
        parsedTask!.metadata['playlistMergedExtensions']!;
    expect(
      PlaylistMergedExtensions.decode(playlistExtensions),
      {transportUrl: 'ts', fragmentedUrl: 'mp4'},
    );
    expect(
      PlaylistMergedExtensions.forPlaylist(parsedTask!.metadata, transportUrl),
      'ts',
    );
    expect(
      PlaylistMergedExtensions.forPlaylist(
        parsedTask!.metadata,
        fragmentedUrl,
      ),
      'mp4',
    );
    expect(
      parsedTask!.detectedMedia
          .where((resource) => resource.isPlaylistSegment)
          .map((resource) => resource.url),
      containsAll([
        'https://example.com/transport.ts',
        'https://example.com/fragment.m4s',
      ]),
    );

    final restoredTask = CatCatchTask.fromMap(parsedTask!.toMap());
    expect(
      PlaylistMergedExtensions.forPlaylist(restoredTask.metadata, transportUrl),
      'ts',
    );
    expect(
      PlaylistMergedExtensions.forPlaylist(
        restoredTask.metadata,
        fragmentedUrl,
      ),
      'mp4',
    );
  });

  test(
    'keeps DASH alternatives selectable and filters their segment groups',
    () async {
      const manifestUrl = 'https://example.com/manifest.mpd';
      const manifest = r'''
<MPD mediaPresentationDuration="PT2S">
  <Period>
    <AdaptationSet mimeType="video/mp4" codecs="avc1.4d401f">
      <SegmentTemplate media="$RepresentationID$/segment-$Number$.m4s" duration="1"/>
      <Representation id="low" bandwidth="400000" width="640" height="360"/>
      <Representation id="high" bandwidth="1200000" width="1280" height="720"/>
    </AdaptationSet>
  </Period>
</MPD>
''';
      final task = CatCatchTask(
        id: 'dash-representation-selection',
        url: manifestUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: manifestUrl,
            name: 'manifest',
            ext: 'mpd',
            mimeType: 'application/dash+xml',
            isPlaylist: true,
          ),
        ],
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.parsingPlaylist)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      final cancelToken = CancelToken();
      CatCatchTask? parsedTask;

      try {
        await TaskExecutor.retryFromStep(
          task: task,
          fromStep: StepType.parsingPlaylist,
          cancelToken: cancelToken,
          playlistDioFactory: () => Dio()
            ..httpClientAdapter = _PlaylistAdapter({manifestUrl: manifest}),
          onUpdate: (updated) {
            final parsing = updated.steps.firstWhere(
              (step) => step.type == StepType.parsingPlaylist,
            );
            if (parsing.completed) {
              parsedTask = updated;
              cancelToken.cancel();
            }
          },
        );
      } finally {
        cancelToken.cancel();
      }

      final resources = parsedTask!.detectedMedia;
      final representations = resources.where(
        (resource) => resource.isPlaylist,
      );
      expect(representations, hasLength(2));
      final byName = {
        for (final resource in representations) resource.name: resource,
      };
      final low = byName['manifest_640x360']!;
      final high = byName['manifest_1280x720']!;
      expect(low.url, manifestUrl);
      expect(high.url, manifestUrl);
      expect(low.groupId, isNot(high.groupId));
      expect(low.selectionIdentity, isNot(high.selectionIdentity));
      expect(low.mimeType, 'video/mp4');
      expect(low.width, 640);
      expect(low.height, 360);
      expect(high.width, 1280);
      expect(high.height, 720);

      final lowSegments = playlistSegmentsForSelection(low, resources);
      final highSegments = playlistSegmentsForSelection(high, resources);
      expect(
        playlistMergedFileExtensionForSelection(low, lowSegments, const {}),
        'mp4',
      );
      expect(lowSegments.map((resource) => resource.url), [
        'https://example.com/low/segment-1.m4s',
        'https://example.com/low/segment-2.m4s',
      ]);
      expect(highSegments.map((resource) => resource.url), [
        'https://example.com/high/segment-1.m4s',
        'https://example.com/high/segment-2.m4s',
      ]);
    },
  );

  test('preserves dynamic playlist HTTP errors for both locales', () async {
    for (final locale in [
      const Locale('en', 'US'),
      const Locale('zh', 'CN'),
    ]) {
      const playlistUrl = 'https://example.com/unavailable.m3u8';
      final task = CatCatchTask(
        id: 'playlist-error',
        url: playlistUrl,
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
            url: playlistUrl,
            name: 'unavailable',
            ext: 'm3u8',
            isPlaylist: true,
          ),
        ],
        steps: [
          for (final type in StepType.values)
            type.index < StepType.values.indexOf(StepType.parsingPlaylist)
                ? StepStatus.done(type)
                : StepStatus.pending(type),
        ],
      );
      CatCatchTask? lastUpdate;

      await TaskExecutor.retryFromStep(
        task: task,
        fromStep: StepType.parsingPlaylist,
        locale: locale,
        playlistDioFactory: () =>
            Dio()..httpClientAdapter = _PlaylistAdapter(const {}),
        onUpdate: (updated) => lastUpdate = updated,
      );

      expect(lastUpdate?.status, TaskStatus.failed);
      expect(lastUpdate?.error, contains('404'));
      expect(lastUpdate?.error, contains('Playlist not found'));
    }
  });
}
