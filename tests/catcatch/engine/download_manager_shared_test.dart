import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/download_manager.dart';

void main() {
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
