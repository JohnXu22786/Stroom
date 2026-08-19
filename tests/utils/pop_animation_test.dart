import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/pop_animation.dart';

void main() {
  group('waitForPopAnimation', () {
    test('null route completes via fallback delay without error', () async {
      // A missing route must not hang the caller — the 400ms fallback
      // delay lets the pipeline proceed.
      await waitForPopAnimation(null);
    });

    test('route without animation completes immediately', () async {
      // An unattached route has no animation (and is not null), so no
      // wait should occur.
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      await waitForPopAnimation(route);
    });

    testWidgets('returns only after the popped route exits', (tester) async {
      // The core contract: the returned future completes when the pop
      // transition ends — not before, and not never.
      DateTime? completedAt;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => Builder(
                    builder: (innerCtx) => ElevatedButton(
                      onPressed: () async {
                        final route = ModalRoute.of(innerCtx);
                        Navigator.pop(innerCtx);
                        await waitForPopAnimation(route);
                        completedAt = DateTime.now();
                      },
                      child: const Text('pop'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('pop'), findsOneWidget);

      // Pop and pump only part-way through the exit transition —
      // the wait must NOT have completed yet.
      await tester.tap(find.text('pop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(completedAt, isNull, reason: 'must not complete mid-transition');

      // Finish the transition — the wait completes.
      await tester.pumpAndSettle();
      expect(completedAt, isNotNull,
          reason: 'must complete once the exit transition ends');
    });
  });
}
