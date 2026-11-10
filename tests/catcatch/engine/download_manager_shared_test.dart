import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/download_manager.dart';

void main() {
  test('applies headers per segment URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cookiesByPath = <String, String?>{};
    final serverDone = server.listen((request) async {
      cookiesByPath[request.uri.path] = request.headers.value('cookie');
      request.response.write(request.uri.path);
      await request.response.close();
    });
    final directory =
        await Directory.systemTemp.createTemp('hls-segment-headers-test');
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
}
