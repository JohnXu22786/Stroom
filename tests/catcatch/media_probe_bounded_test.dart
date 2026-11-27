import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/executor_media.dart';
import 'package:stroom/catcatch/engine/media_probe.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  final resources = [
    const MediaResource(
      url: 'https://example.test/first.mp4',
      name: 'first',
      ext: 'mp4',
      isPlayable: true,
    ),
    const MediaResource(
      url: 'https://example.test/second.mp4',
      name: 'second',
      ext: 'mp4',
      isPlayable: true,
    ),
  ];

  test(
    'timed out probe does not block metadata probes for later resources',
    () async {
      var probeCount = 0;

      final result = await probeMediaResources(
        resources,
        probeTimeout: const Duration(milliseconds: 10),
        probe: (url, {cancelToken, required timeout}) {
          probeCount++;
          if (url == resources.first.url) {
            return Completer<MediaProbeResult>().future;
          }
          return Future.value(
            const MediaProbeResult(duration: Duration(seconds: 4), width: 640),
          );
        },
      );

      expect(probeCount, 2);
      expect(result, hasLength(2));
      expect(result.first.duration, isNull);
      expect(result.last.duration, '00:00:04.000');
      expect(result.last.width, 640);
    },
  );

  test(
    'cancellation interrupts an in-flight probe and keeps discovered items',
    () async {
      final token = CancelToken();
      final entered = Completer<void>();
      final neverCompletes = Completer<MediaProbeResult>();
      var probeCount = 0;

      final pending = probeMediaResources(
        resources,
        cancelToken: token,
        probeTimeout: const Duration(seconds: 1),
        probe: (url, {cancelToken, required timeout}) {
          probeCount++;
          entered.complete();
          return neverCompletes.future;
        },
      );

      await entered.future;
      token.cancel('cancel probe');
      final result = await pending.timeout(const Duration(milliseconds: 100));

      expect(probeCount, 1);
      expect(result.map((resource) => resource.url), [
        resources.first.url,
        resources.last.url,
      ]);
      expect(result.first.duration, isNull);
    },
  );
}
