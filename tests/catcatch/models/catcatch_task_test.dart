import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  test('immutable updates keep ownership while restored rows get new ownership',
      () {
    final original = CatCatchTask(
      id: 'same-id',
      url: 'https://example.com/video.mp4',
      expectedDurationSec: 30,
      createdAt: DateTime(2025, 1, 1),
    );
    final updated = original.copyWith(progress: 42).copyWith(
          status: TaskStatus.paused,
        );
    final serialized = jsonEncode(updated.toMap());
    final restored = CatCatchTask.fromMap(
      jsonDecode(serialized) as Map<String, dynamic>,
    );

    expect(
        identical(updated.runtimeIdentity, original.runtimeIdentity), isTrue);
    expect(
        identical(restored.runtimeIdentity, updated.runtimeIdentity), isFalse);
    expect(restored.toMap(), updated.toMap());
  });

      test('browser recovery resumes after fetch and retains prior task state', () {
    final originalMedia = MediaResource(
      url: 'https://example.com/original.mp4',
      name: 'original',
      ext: 'mp4',
    );
    final recoveredMedia = MediaResource(
      url: 'https://example.com/recovered.mp4',
      name: 'recovered',
      ext: 'mp4',
    );
    final task = CatCatchTask(
      id: 'recovery',
      url: 'https://example.com/page',
      expectedDurationSec: 30,
      createdAt: DateTime(2025, 1, 1),
      status: TaskStatus.paused,
      error: 'WebView scan needs manual browser recovery',
      steps: [
        StepStatus.running(StepType.fetching),
        StepStatus.pending(StepType.analyzing),
        StepStatus.pending(StepType.parsingPlaylist),
      ],
      detectedMedia: [originalMedia],
      metadata: {CatCatchTask.webViewRecoveryRequiredKey: 'true'},
    );

    final resumed = task.resumeAfterBrowserRecovery(
      recoveredMedia: [recoveredMedia, originalMedia],
      pageTitle: 'Recovered page',
      cookieHeadersByHost: {
        'example.com': 'session=example',
        'cdn.example.net': 'cdn_session=example',
      },
    );

    expect(resumed, isNotNull);
    expect(resumed!.status, TaskStatus.running);
    expect(resumed.steps[0].completed, isTrue);
    expect(resumed.steps[1].completed, isTrue);
    expect(resumed.steps[2].completed, isFalse);
    expect(resumed.detectedMedia, [originalMedia, recoveredMedia]);
    expect(resumed.metadata, isEmpty);
    expect(resumed.error, isNull);
    expect(resumed.title, 'Recovered page');
    expect(
      resumed.browserCookieHeaderForUrl('https://example.com/video.mp4'),
      'session=example',
    );
    expect(
      resumed.browserCookieHeaderForUrl('https://cdn.example.net/video.mp4'),
      'cdn_session=example',
    );
    expect(resumed.toMap().containsKey('runtimeBrowserCookieHeader'), isFalse);
  });
}
