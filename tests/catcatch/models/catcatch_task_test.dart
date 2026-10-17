import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';

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
}
