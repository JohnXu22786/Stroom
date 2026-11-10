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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
