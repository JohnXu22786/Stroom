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

  testWidgets('RunningElapsedLabel ticks with an injected clock',
      (tester) async {
    final start = DateTime(2026, 1, 1, 12, 0, 0);
    var now = DateTime(2026, 1, 1, 12, 2, 5); // 2:05 elapsed
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunningElapsedLabel(startedAt: start, now: () => now),
        ),
      ),
    );
    expect(find.text('已运行 02:05'), findsOneWidget);

    // Advance the injected clock by 10 seconds and let the 1s tick timer
    // fire — the label must re-render with the new elapsed time.
    now = DateTime(2026, 1, 1, 12, 2, 15);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('已运行 02:15'), findsOneWidget);
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
