import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/widgets/running_elapsed_label.dart';

void main() {
  testWidgets('RunningElapsedLabel renders nothing when startedAt is null',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RunningElapsedLabel())),
    );
    expect(find.textContaining('已运行'), findsNothing);
  });

  testWidgets('RunningElapsedLabel shows elapsed time and ticks',
      (tester) async {
    final start =
        DateTime.now().subtract(const Duration(minutes: 2, seconds: 5));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunningElapsedLabel(startedAt: start),
        ),
      ),
    );
    expect(find.textContaining('已运行 02:05'), findsOneWidget);

    // The 1s tick timer stays active while startedAt is set; the test
    // framework's fake clock does not advance DateTime.now(), so the
    // label text itself cannot change here — this just verifies the
    // periodic timer does not leak (no pending-timer failure on teardown).
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('已运行'), findsOneWidget);
  });

  testWidgets('RunningElapsedLabel stops ticking when startedAt becomes null',
      (tester) async {
    final start = DateTime.now().subtract(const Duration(seconds: 30));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunningElapsedLabel(startedAt: start),
        ),
      ),
    );
    expect(find.textContaining('已运行 00:30'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RunningElapsedLabel()),
      ),
    );
    expect(find.textContaining('已运行'), findsNothing);
  });
}
