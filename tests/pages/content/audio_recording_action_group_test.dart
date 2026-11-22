import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/audio_recording_page.dart';

void main() {
  for (final state in ['recording', 'paused', 'completed']) {
    testWidgets('$state actions reflow at 320 px and share a row when wide', (
      tester,
    ) async {
      final labels = switch (state) {
        'recording' => ['Pause', 'Stop'],
        'paused' => ['Resume', 'Stop'],
        _ => ['Save', 'Record again'],
      };

      Future<void> pumpAt(double width) async {
        await tester.binding.setSurfaceSize(Size(width, 640));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordingActionGroup(
                children: [
                  for (final label in labels)
                    SizedBox(
                      width: 160,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: Text(label),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpAt(320);
      expect(tester.takeException(), isNull);
      final narrowButtons = labels.map(find.text).toList();
      expect(
        tester.getCenter(narrowButtons[0]).dy,
        lessThan(tester.getCenter(narrowButtons[1]).dy),
      );

      await pumpAt(400);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(narrowButtons[0]).dy,
        closeTo(tester.getCenter(narrowButtons[1]).dy, 0.1),
      );
      await tester.binding.setSurfaceSize(null);
    });
  }
}
