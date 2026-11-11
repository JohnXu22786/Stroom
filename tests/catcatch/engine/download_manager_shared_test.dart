import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/config/default_rules.dart';
import 'package:stroom/catcatch/engine/download_manager.dart';

void main() {
  test('restarts a resumed download when the server ignores Range', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? requestedRange;
    final serverDone = server.listen((request) async {
      requestedRange = request.headers.value(HttpHeaders.rangeHeader);
      request.response.write('complete file');
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('ignored-range-');
    const fileName = 'download.bin';
    final partial = File(
      '${directory.path}/$fileName${DefaultRules.tempFileSuffix}',
    )..writeAsStringSync('complete ');
    final expectedRange = 'bytes=${await partial.length()}-';
    final url = 'http://${server.address.address}:${server.port}/file';
    try {
      final outputPath = await DownloadManager.downloadFile(
        url: url,
        saveDir: directory.path,
        fileName: fileName,
      );

      expect(requestedRange, expectedRange);
      expect(await File(outputPath).readAsString(), 'complete file');
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
  test('isolates concurrent downloads with the same output filename', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.listen((request) async {
      final contents = request.uri.pathSegments.last;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final startByte = int.parse(
          RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!,
        );
        request.response.statusCode = HttpStatus.partialContent;
        request.response.write(contents.substring(startByte));
      } else {
        request.response.write(contents);
      }
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('same-name-');
    final origin = 'http://${server.address.address}:${server.port}';
    try {
      Future<void> verifyPair({
        required String fileName,
        required String firstContent,
        required String secondContent,
        String? firstTaskId,
        String? secondTaskId,
        String? existingPath,
      }) async {
        Future<String> download(String content, String? taskId) {
          if (existingPath != null) {
            return DownloadManager.downloadFile(
              url: '$origin/$content',
              saveDir: directory.path,
              fileName: fileName,
              taskId: taskId ?? '',
              existingPath: existingPath,
            );
          }
          return taskId == null
              ? DownloadManager.downloadFile(
                  url: '$origin/$content',
                  saveDir: directory.path,
                  fileName: fileName,
                )
              : DownloadManager.downloadFile(
                  url: '$origin/$content',
                  saveDir: directory.path,
                  fileName: fileName,
                  taskId: taskId,
                );
        }

        final results = await Future.wait([
          download(firstContent, firstTaskId),
          download(secondContent, secondTaskId),
        ]);

        expect(results.toSet(), hasLength(2));
        expect(
          results.where((path) => path.endsWith(DefaultRules.tempFileSuffix)),
          isEmpty,
        );
        final contents = await Future.wait(
          results.map((path) => File(path).readAsString()),
        );
        expect(contents.toSet(), {firstContent, secondContent});
      }

      Directory('${directory.path}/shared (1).bin').createSync();
      await verifyPair(
        fileName: 'shared.bin',
        firstContent: 'first-content',
        secondContent: 'second-content',
        firstTaskId: 'first-task',
        secondTaskId: 'second-task',
      );
      await verifyPair(
        fileName: 'shared-default.bin',
        firstContent: 'first-default-content',
        secondContent: 'second-default-content',
      );
      final legacyPartialPath = '${directory.path}/shared-legacy.bin.tmp';
      await File(legacyPartialPath).writeAsString('first-resume-');
      await verifyPair(
        fileName: 'shared-legacy.bin',
        firstContent: 'first-resume-content',
        secondContent: 'second-resume-content',
        firstTaskId: 'first-resume-task',
        secondTaskId: 'second-resume-task',
        existingPath: legacyPartialPath,
      );
      final legacyDefaultPartialPath =
          '${directory.path}/shared-legacy-default.bin.tmp';
      await File(legacyDefaultPartialPath)
          .writeAsString('first-default-resume-');
      await verifyPair(
        fileName: 'shared-legacy-default.bin',
        firstContent: 'first-default-resume-content',
        secondContent: 'second-default-resume-content',
        existingPath: legacyDefaultPartialPath,
      );
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
  test('applies headers per segment URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cookiesByPath = <String, String?>{};
    final serverDone = server.listen((request) async {
      cookiesByPath[request.uri.path] = request.headers.value('cookie');
      request.response.write(request.uri.path);
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp(
      'hls-segment-headers-test',
    );
    final origin = 'http://${server.address.address}:${server.port}';
    try {
      await DownloadManager.downloadSegmentsAndMerge(
        segmentUrls: ['$origin/playlist-host.ts', '$origin/cdn-host.ts'],
        outputPath: '${directory.path}/merged.ts',
        headers: const {'Referer': 'https://watch.example.net/'},
        headersForUrl: (url) => {
          'Referer': 'https://watch.example.net/',
          if (url.endsWith('playlist-host.ts')) 'Cookie': 'host_a=session_a',
          if (url.endsWith('cdn-host.ts')) 'Cookie': 'host_b=session_b',
        },
      );

      expect(cookiesByPath['/playlist-host.ts'], 'host_a=session_a');
      expect(cookiesByPath['/cdn-host.ts'], 'host_b=session_b');
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  test(
    'downloads and merges repeated URL byte ranges in playlist order',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestedRanges = <String?>[];
      final serverDone = server.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        requestedRanges.add(range);
        final bytes = switch (range) {
          'bytes=2-4' => 'cde',
          'bytes=5-6' => 'fg',
          _ => 'abcdefg',
        };
        request.response.statusCode = range == null ? HttpStatus.ok : 206;
        request.response.write(bytes);
        await request.response.close();
      });
      final directory = await Directory.systemTemp.createTemp('hls-range-test');
      final url = 'http://${server.address.address}:${server.port}/shared.ts';
      try {
        final outputPath = '${directory.path}/merged.ts';
        await DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: [url, url, url],
          segmentRanges: [(start: 2, length: 3), (start: 5, length: 2), null],
          outputPath: outputPath,
        );

        expect(requestedRanges.toSet(), {null, 'bytes=2-4', 'bytes=5-6'});
        expect(await File(outputPath).readAsString(), 'cdefgabcdefg');
      } finally {
        await serverDone.cancel();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test('isolates concurrent playlists with the same output filename', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.listen((request) async {
      final payload = request.uri.pathSegments.last;
      await Future<void>.delayed(
        Duration(milliseconds: payload.startsWith('first') ? 25 : 5),
      );
      request.response.write(payload);
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('same-playlist-');
    final origin = 'http://${server.address.address}:${server.port}';
    try {
      final results = await Future.wait([
        DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/first-a.ts', '$origin/first-b.ts'],
          outputPath: '${directory.path}/same_merged.ts',
          taskId: 'first-playlist-task',
        ),
        DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/second-a.ts', '$origin/second-b.ts'],
          outputPath: '${directory.path}/same_merged.ts',
          taskId: 'second-playlist-task',
        ),
      ]);

      expect(results.toSet(), hasLength(2));
      final contents = await Future.wait(
        results.map((path) => File(path).readAsString()),
      );
      expect(contents.toSet(), {
        'first-a.tsfirst-b.ts',
        'second-a.tssecond-b.ts',
      });
      expect(
        Directory(directory.path)
            .listSync()
            .whereType<Directory>()
            .where((entry) => entry.path.endsWith('_parts')),
        isEmpty,
      );
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  test('releases a playlist output reservation when cancelled', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.listen((request) async {
      request.response.write('replacement segment');
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('cancel-playlist-');
    final outputPath = '${directory.path}/same_merged.ts';
    final origin = 'http://${server.address.address}:${server.port}';
    try {
      final cancelToken = CancelToken()..cancel('cancel playlist');
      await expectLater(
        DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/cancelled.ts'],
          outputPath: outputPath,
          cancelToken: cancelToken,
          taskId: 'cancelled-playlist-task',
        ),
        throwsA(anything),
      );

      final replacementPath = await DownloadManager.downloadSegmentsAndMerge(
        segmentUrls: ['$origin/replacement.ts'],
        outputPath: outputPath,
        taskId: 'replacement-playlist-task',
      );

      expect(replacementPath, outputPath);
      expect(await File(replacementPath).readAsString(), 'replacement segment');
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
