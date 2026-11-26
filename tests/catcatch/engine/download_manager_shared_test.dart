import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/config/default_rules.dart';
import 'package:stroom/catcatch/engine/download_manager_shared.dart';
import 'package:stroom/catcatch/engine/download_manager.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  Future<void> verifyRangeRetry({
    required String rejectedContentRange,
    required String rejectedBody,
    bool rejectByStreamError = false,
    bool expectByteCorrection = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    String? requestedRange;
    final serverDone = server.listen((request) async {
      requests++;
      requestedRange = request.headers.value(HttpHeaders.rangeHeader);
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        requests == 1 ? rejectedContentRange : 'bytes 2-4/10',
      );
      if (requests == 1 && rejectByStreamError) {
        request.response.contentLength = 3;
      }
      request.response.write(requests == 1 ? rejectedBody : 'cde');
      try {
        await request.response.close();
      } catch (_) {
        // A deliberately truncated Content-Length closes the first stream
        // with an error so the downloader exercises its retry path.
      }
    });
    final directory = await Directory.systemTemp.createTemp('range-retry-');
    final partFiles = <String?>[null];
    final errors = <int, String>{};
    final byteDeltas = <int>[];
    var completedSegments = 0;
    try {
      await downloadSingleSegment(
        index: 0,
        url: 'http://${server.address.address}:${server.port}/segment',
        rangeStart: 2,
        rangeLength: 3,
        tempDir: directory.path,
        partFiles: partFiles,
        semaphore: Semaphore(1),
        errors: errors,
        onSegmentComplete: (_) async => completedSegments++,
        onBytesDelta: byteDeltas.add,
      );

      expect(requestedRange, 'bytes=2-4');
      expect(requests, 2);
      expect(errors, isEmpty);
      expect(completedSegments, 1);
      expect(await File(partFiles.single!).readAsString(), 'cde');
      expect(byteDeltas.where((delta) => delta > 0), isNotEmpty);
      expect(byteDeltas.any((delta) => delta < 0), expectByteCorrection);
      expect(byteDeltas.fold<int>(0, (total, delta) => total + delta), 3);
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  }

  test('retries ranged responses with a mismatched Content-Range', () async {
    await verifyRangeRetry(
      rejectedContentRange: 'bytes 1-3/10',
      rejectedBody: 'bcd',
    );
  });

  test('retries ranged responses with a short body', () async {
    await verifyRangeRetry(
      rejectedContentRange: 'bytes 2-4/10',
      rejectedBody: 'cd',
      expectByteCorrection: true,
    );
  });

  test(
    'retries a ranged stream failure without correcting unreported bytes',
    () async {
      await verifyRangeRetry(
        rejectedContentRange: 'bytes 2-4/10',
        rejectedBody: 'cd',
        rejectByStreamError: true,
      );
    },
  );

  test('confines progress files for traversal task IDs', () async {
    const taskId = '../../catcatch_progress_escape_test';
    final appDir = await AppStorage.directory;
    final expectedOutsideFile = File(
      p.join(appDir, 'catcatch_progress_escape_test_dl_progress.json'),
    )..writeAsStringSync('keep');
    try {
      await saveSegmentProgress(taskId, {'completed': 3});

      final savedPath = await progressPath(taskId);
      final progressDir = p.join(appDir, 'catcatch', '.progress');
      expect(p.isWithin(progressDir, savedPath), isTrue);
      expect(
        p.basename(await progressPath('legacy.task')),
        'legacy.task_dl_progress.json',
      );
      expect(p.basename(await progressPath('旧任务')), '旧任务_dl_progress.json');
      expect(
        p.basename(await progressPath('a/b')),
        isNot(p.basename(await progressPath('a%2Fb'))),
      );
      final firstWindowsUnsafe =
          p.basename(await progressPath('\u0000/')).toLowerCase();
      final secondWindowsUnsafe =
          p.basename(await progressPath('h/')).toLowerCase();
      expect(firstWindowsUnsafe, isNot(secondWindowsUnsafe));
      expect(await expectedOutsideFile.readAsString(), 'keep');
      expect(jsonDecode(await File(savedPath).readAsString()), {
        'completed': 3,
      });
    } finally {
      if (await expectedOutsideFile.exists()) {
        await expectedOutsideFile.delete();
      }
    }
  });

  test(
    'propagates a failed response stream instead of returning a temp path',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final serverDone = server.listen((socket) async {
        socket.write(
          'HTTP/1.1 200 OK\r\n'
          'Content-Length: 100\r\n'
          'Connection: close\r\n\r\n'
          'partial',
        );
        await socket.flush();
        await socket.close();
      });
      final directory = await Directory.systemTemp.createTemp('failed-stream-');
      final url = 'http://${server.address.address}:${server.port}/file';
      try {
        await expectLater(
          DownloadManager.downloadFile(
            url: url,
            saveDir: directory.path,
            fileName: 'download.bin',
          ),
          throwsA(anything),
        );
      } finally {
        await serverDone.cancel();
        await server.close();
        await directory.delete(recursive: true);
      }
    },
  );

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

  test(
    'does not append a resumed response with invalid Content-Range',
    () async {
      for (final contentRange in [
        'bytes 0-7/8',
        'bytes 8-7/8',
        'bytes\t8-14/15',
      ]) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? requestedRange;
        final serverDone = server.listen((request) async {
          requestedRange = request.headers.value(HttpHeaders.rangeHeader);
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            contentRange,
          );
          request.response.write('corrupt');
          await request.response.close();
        });
        final directory = await Directory.systemTemp.createTemp(
          'wrong-resume-range-',
        );
        const fileName = 'download.bin';
        final partial = File(
          '${directory.path}/$fileName${DefaultRules.tempFileSuffix}',
        )..writeAsStringSync('trusted-');
        final url = 'http://${server.address.address}:${server.port}/file';
        try {
          await expectLater(
            DownloadManager.downloadFile(
              url: url,
              saveDir: directory.path,
              fileName: fileName,
            ),
            throwsA(anything),
          );

          expect(requestedRange, 'bytes=${'trusted-'.length}-');
          expect(await partial.readAsString(), 'trusted-');
          expect(await File('${directory.path}/$fileName').exists(), isFalse);
        } finally {
          await serverDone.cancel();
          await server.close(force: true);
          await directory.delete(recursive: true);
        }
      }
    },
  );

  test(
    'does not publish a resumed response that stops before the file end',
    () async {
      for (final response in [
        (contentRange: 'bytes 7-10/20', body: 'part'),
        (contentRange: 'bytes 7-19/20', body: 'part'),
      ]) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serverDone = server.listen((request) async {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            response.contentRange,
          );
          request.response.write(response.body);
          await request.response.close();
        });
        final directory = await Directory.systemTemp.createTemp(
          'truncated-resume-range-',
        );
        const fileName = 'download.bin';
        final partial = File(
          '${directory.path}/$fileName${DefaultRules.tempFileSuffix}',
        )..writeAsStringSync('trusted');
        final url = 'http://${server.address.address}:${server.port}/file';
        try {
          await expectLater(
            DownloadManager.downloadFile(
              url: url,
              saveDir: directory.path,
              fileName: fileName,
            ),
            throwsA(anything),
          );

          expect(await partial.readAsString(), 'trusted');
          expect(await File('${directory.path}/$fileName').exists(), isFalse);
        } finally {
          await serverDone.cancel();
          await server.close(force: true);
          await directory.delete(recursive: true);
        }
      }
    },
  );

  test(
    'keeps a resumable partial when publication fails and paths change',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestedRanges = <String?>[];
      var requests = 0;
      final serverDone = server.listen((request) async {
        requests++;
        requestedRanges.add(request.headers.value(HttpHeaders.rangeHeader));
        if (requests == 1) {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 8-17/18',
          );
          request.response.contentLength = 'continued-'.length;
          request.response.write('continued-');
        } else {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 8-14/15',
          );
          request.response.write('content');
        }
        await request.response.close();
      });
      final directory = await Directory.systemTemp.createTemp('task-resume-');
      const taskId = 'resume-task';
      const fileName = 'download.bin';
      final occupiedOutput = File(p.join(directory.path, fileName))
        ..writeAsStringSync('keep existing');
      final taskSuffix =
          base64Url.encode(utf8.encode(taskId)).replaceAll('=', '');
      final partial = File(
        '${directory.path}/$fileName.$taskSuffix${DefaultRules.tempFileSuffix}',
      )..writeAsStringSync('partial-');
      final url = 'http://${server.address.address}:${server.port}/file';
      try {
        var createdBlocker = false;
        await expectLater(
          DownloadManager.downloadFile(
            url: url,
            saveDir: directory.path,
            fileName: fileName,
            taskId: taskId,
            onProgress: (received, total) {
              if (received > 0 && !createdBlocker) {
                createdBlocker = true;
                Directory(p.join(directory.path, 'download (1).bin'))
                    .createSync();
              }
            },
          ),
          throwsA(anything),
        );

        final outputPath = await DownloadManager.downloadFile(
          url: url,
          saveDir: directory.path,
          fileName: fileName,
          taskId: taskId,
        );

        expect(outputPath, p.join(directory.path, 'download (2).bin'));
        expect(requestedRanges.first, 'bytes=${'partial-'.length}-');
        expect(requestedRanges.last, 'bytes=${'partial-'.length}-');
        expect(await File(outputPath).readAsString(), 'partial-content');
        expect(await occupiedOutput.readAsString(), 'keep existing');
        expect(await partial.exists(), isFalse);
      } finally {
        await serverDone.cancel();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test('preserves an existing single-download output path', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.listen((request) async {
      request.response.write('new download');
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('existing-file-');
    final existing = File(p.join(directory.path, 'download.bin'))
      ..writeAsStringSync('keep existing');
    final occupiedAlternate = File(p.join(directory.path, 'download (1).bin'))
      ..writeAsStringSync('also keep');
    final url = 'http://${server.address.address}:${server.port}/file';
    try {
      final outputPath = await DownloadManager.downloadFile(
        url: url,
        saveDir: directory.path,
        fileName: 'download.bin',
      );

      expect(outputPath, p.join(directory.path, 'download (2).bin'));
      expect(await existing.readAsString(), 'keep existing');
      expect(await occupiedAlternate.readAsString(), 'also keep');
      expect(await File(outputPath).readAsString(), 'new download');
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
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $startByte-${contents.length - 1}/${contents.length}',
        );
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
        firstTaskId: 'same-task',
        secondTaskId: 'same-task',
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

  test('preserves an existing segmented-download output path', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.listen((request) async {
      request.response.write(request.uri.pathSegments.last);
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp('existing-merge-');
    final outputPath = p.join(directory.path, 'merged.ts');
    final existing = File(outputPath)..writeAsStringSync('keep merged output');
    final occupiedAlternate = Directory(p.join(directory.path, 'merged (1).ts'))
      ..createSync();
    final origin = 'http://${server.address.address}:${server.port}';
    try {
      final resolvedPath = await DownloadManager.downloadSegmentsAndMerge(
        segmentUrls: ['$origin/first.ts', '$origin/second.ts'],
        outputPath: outputPath,
      );

      expect(resolvedPath, p.join(directory.path, 'merged (2).ts'));
      expect(await existing.readAsString(), 'keep merged output');
      expect(await occupiedAlternate.exists(), isTrue);
      expect(await File(resolvedPath).readAsString(), 'first.tssecond.ts');
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  test('does not publish a partial file when segment merging fails', () async {
    final directory = await Directory.systemTemp.createTemp('failed-merge-');
    final firstPart = File(p.join(directory.path, 'first.part'))
      ..writeAsStringSync('partial output');
    final secondPart = File(p.join(directory.path, 'second.part'))
      ..writeAsStringSync('remaining output');
    final output = File(p.join(directory.path, 'merged.ts'));
    try {
      await expectLater(
        DownloadManager.mergeFiles([
          firstPart.path,
          secondPart.path,
        ], output.path, onBytes: (_) => throw StateError('merge failed')),
        throwsA(isA<StateError>()),
      );

      expect(await output.exists(), isFalse);
      expect(
        Directory(directory.path)
            .listSync()
            .map((entry) => p.basename(entry.path))
            .toSet(),
        {'first.part', 'second.part'},
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'fails and discards staged output when a segment part is missing',
    () async {
      final directory = await Directory.systemTemp.createTemp('missing-part-');
      final firstPart = File(p.join(directory.path, 'first.part'))
        ..writeAsStringSync('first segment');
      final missingPartPath = p.join(directory.path, 'missing.part');
      final output = File(p.join(directory.path, 'merged.ts'));
      try {
        await expectLater(
          DownloadManager.mergeFiles([
            firstPart.path,
            missingPartPath,
          ], output.path),
          throwsA(isA<FileSystemException>()),
        );

        expect(await output.exists(), isFalse);
        expect(await firstPart.readAsString(), 'first segment');
        expect(
          Directory(directory.path)
              .listSync()
              .map((entry) => p.basename(entry.path))
              .toSet(),
          {'first.part'},
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

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
        if (range != null) {
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes ${range == 'bytes=2-4' ? '2-4' : '5-6'}/7',
          );
        }
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

  test(
    'resumes only segments completed before an interrupted playlist',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = 'http://${server.address.address}:${server.port}';
      final firstSegmentStarted = Completer<void>();
      final releaseFirstSegment = Completer<void>();
      var firstSegmentRequests = 0;
      var secondSegmentRequests = 0;
      final serverDone = server.listen((request) async {
        if (request.uri.path == '/first.ts' && firstSegmentRequests++ == 0) {
          request.response.write('partial-');
          await request.response.flush();
          if (!firstSegmentStarted.isCompleted) firstSegmentStarted.complete();
          await releaseFirstSegment.future;
          return;
        }
        if (request.uri.path == '/second.ts') secondSegmentRequests++;

        request.response.write(
          request.uri.path == '/first.ts'
              ? 'first-complete'
              : 'second-complete',
        );
        await request.response.close();
      });
      final directory = await Directory.systemTemp.createTemp(
        'playlist-resume-',
      );
      const taskId = 'out-of-order-playlist-resume-test';
      final outputPath = '${directory.path}/merged.ts';
      final cancelToken = CancelToken();
      final completedOutOfOrder = Completer<void>();
      try {
        final initialDownload = DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/first.ts', '$origin/second.ts'],
          outputPath: outputPath,
          concurrency: 2,
          taskId: taskId,
          cancelToken: cancelToken,
          onProgress: (completed, total, progress) {
            if (completed == 1 && !completedOutOfOrder.isCompleted) {
              completedOutOfOrder.complete();
            }
          },
        );

        await firstSegmentStarted.future;
        await completedOutOfOrder.future;
        cancelToken.cancel('simulate app interruption');
        await expectLater(initialDownload, throwsA(anything));

        final savedProgress = await DownloadManager.loadProgress(taskId);
        expect(savedProgress?['completedSegments'], [1]);
        final firstRequestsBeforeResume = firstSegmentRequests;

        final resumedPath = await DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/first.ts', '$origin/second.ts'],
          outputPath: outputPath,
          concurrency: 2,
          taskId: taskId,
        );

        expect(
          await File(resumedPath).readAsString(),
          'first-completesecond-complete',
        );
        expect(firstSegmentRequests, greaterThan(firstRequestsBeforeResume));
        expect(secondSegmentRequests, 1);
      } finally {
        if (!releaseFirstSegment.isCompleted) releaseFirstSegment.complete();
        await serverDone.cancel();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'does not resume saved parts from a different playlist with the same output name',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = 'http://${server.address.address}:${server.port}';
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var replacementFirstRequests = 0;
      var replacementSecondRequests = 0;
      final serverDone = server.listen((request) async {
        if (request.uri.path == '/old-first.ts') {
          if (!firstStarted.isCompleted) firstStarted.complete();
          await releaseFirst.future;
          return;
        }
        if (request.uri.path == '/old-second.ts') {
          request.response.write('old-second');
        } else if (request.uri.path == '/new-first.ts') {
          replacementFirstRequests++;
          request.response.write('new-first');
        } else {
          replacementSecondRequests++;
          request.response.write('new-second');
        }
        await request.response.close();
      });
      final directory = await Directory.systemTemp.createTemp(
        'playlist-identity-resume-',
      );
      const taskId = 'playlist-identity-resume-test';
      final outputPath = '${directory.path}/same_merged.ts';
      final cancelToken = CancelToken();
      final completedOutOfOrder = Completer<void>();
      try {
        final initialDownload = DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/old-first.ts', '$origin/old-second.ts'],
          outputPath: outputPath,
          concurrency: 2,
          taskId: taskId,
          cancelToken: cancelToken,
          onProgress: (completed, total, progress) {
            if (completed == 1 && !completedOutOfOrder.isCompleted) {
              completedOutOfOrder.complete();
            }
          },
        );
        await firstStarted.future;
        await completedOutOfOrder.future;
        cancelToken.cancel('simulate retry after playlist reselection');
        await expectLater(initialDownload, throwsA(anything));

        final resumedPath = await DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/new-first.ts', '$origin/new-second.ts'],
          outputPath: outputPath,
          taskId: taskId,
        );

        expect(await File(resumedPath).readAsString(), 'new-firstnew-second');
        expect(replacementFirstRequests, 1);
        expect(replacementSecondRequests, 1);
      } finally {
        if (!releaseFirst.isCompleted) releaseFirst.complete();
        await serverDone.cancel();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

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

  test('cancels a large playlist merge without publishing output', () async {
    const payloadLength = 2 * 1024 * 1024;
    final payload = List<int>.filled(payloadLength, 0x61);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final serverDone = server.listen((request) async {
      requests++;
      request.response.add(payload);
      await request.response.close();
    });
    final directory = await Directory.systemTemp.createTemp(
      'cancelled-playlist-merge-',
    );
    final outputPath = p.join(directory.path, 'merged.ts');
    final origin = 'http://${server.address.address}:${server.port}';
    final cancelToken = CancelToken();
    var merging = false;
    var copiedMergeChunks = 0;
    try {
      await expectLater(
        DownloadManager.downloadSegmentsAndMerge(
          segmentUrls: ['$origin/segment.ts'],
          outputPath: outputPath,
          cancelToken: cancelToken,
          onProgress: (_, _, progress) {
            if (progress == 95) merging = true;
          },
          onBytes: (_) {
            if (merging && !cancelToken.isCancelled) {
              copiedMergeChunks++;
              cancelToken.cancel('cancel during playlist merge');
            }
          },
        ),
        throwsA(anything),
      );

      expect(copiedMergeChunks, 1);
      expect(await File(outputPath).exists(), isFalse);
      expect(
        Directory(directory.path)
            .listSync()
            .where((entry) => p.basename(entry.path).contains('.merge-')),
        isEmpty,
      );

      final retryPath = await DownloadManager.downloadSegmentsAndMerge(
        segmentUrls: ['$origin/segment.ts'],
        outputPath: outputPath,
      );

      expect(retryPath, outputPath);
      expect(await File(retryPath).length(), payloadLength);
      expect(requests, 2);
    } finally {
      await serverDone.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
