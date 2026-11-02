import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/playlist_merged_extensions.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps the merged container extension for each playlist', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    final serving = server.forEach((request) async {
      request.response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
      );
      request.response.write(switch (request.uri.path) {
        '/transport.m3u8' =>
          '''
#EXTM3U
#EXTINF:4.0,
transport.ts
#EXT-X-ENDLIST
''',
        '/fragmented.m3u8' =>
          '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXTINF:4.0,
fragment.m4s
#EXT-X-ENDLIST
''',
        _ => throw StateError('Unexpected request: ${request.uri.path}'),
      });
      await request.response.close();
    });

    final task = CatCatchTask(
      id: 'mixed-playlists',
      url: baseUrl,
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      detectedMedia: [
        MediaResource(
          url: '$baseUrl/transport.m3u8',
          name: 'transport',
          ext: 'm3u8',
          isPlaylist: true,
        ),
        MediaResource(
          url: '$baseUrl/fragmented.m3u8',
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
      await server.close(force: true);
      await serving;
    }

    final playlistExtensions = jsonDecode(
      parsedTask!.metadata['playlistMergedExtensions']!,
    ) as Map<String, dynamic>;
    expect(playlistExtensions, {
      '$baseUrl/transport.m3u8': 'ts',
      '$baseUrl/fragmented.m3u8': 'mp4',
    });
    expect(
      PlaylistMergedExtensions.forPlaylist(
        parsedTask!.metadata,
        '$baseUrl/transport.m3u8',
      ),
      'ts',
    );
    expect(
      PlaylistMergedExtensions.forPlaylist(
        parsedTask!.metadata,
        '$baseUrl/fragmented.m3u8',
      ),
      'mp4',
    );
    expect(
      parsedTask!.detectedMedia
          .where((resource) => resource.isPlaylistSegment)
          .map((resource) => resource.url),
      containsAll(['$baseUrl/transport.ts', '$baseUrl/fragment.m4s']),
    );

    final restoredTask = CatCatchTask.fromMap(parsedTask!.toMap());
    expect(
      jsonDecode(restoredTask.metadata['playlistMergedExtensions']!),
      playlistExtensions,
    );
  });
}
