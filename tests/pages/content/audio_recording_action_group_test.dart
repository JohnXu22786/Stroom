import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_recording_page.dart';

void main() {
  for (final state in ['recording', 'paused', 'completed']) {
    testWidgets('$state actions reflow at 320 px and share a row when wide', (
      tester,
    ) async {
      final strings = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );
      final theme = ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true);
      final actions = switch (state) {
        'recording' => [
            (
              Icons.pause_circle_filled,
              strings.audioRecordingPause,
              Colors.orange
            ),
            (Icons.stop, strings.audioRecordingStop, Colors.red),
          ],
        'paused' => [
            (
              Icons.play_circle_filled,
              strings.audioRecordingResume,
              Colors.green
            ),
            (Icons.stop, strings.audioRecordingStop, Colors.red),
          ],
        _ => [
            (Icons.save, strings.audioRecordingSave, theme.colorScheme.primary),
            (Icons.refresh, strings.audioRecordingRecordAgain, Colors.grey),
          ],
      };
      final labels = actions.map((action) => action.$2).toList();

      Future<void> pumpAt(double width) async {
        await tester.binding.setSurfaceSize(Size(width, 640));
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: RecordingActionGroup(
                buttons: [
                  for (final action in actions)
                    RecordingActionButton(
                      onPressed: () {},
                      icon: action.$1,
                      label: action.$2,
                      color: action.$3,
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
      final actionButtonFinder = find.byType(RecordingActionButton);
      expect(tester.getSize(actionButtonFinder.first).width, 272);
      expect(tester.getSize(actionButtonFinder.last).width, 272);
      expect(
        tester.getCenter(narrowButtons[0]).dy,
        lessThan(tester.getCenter(narrowButtons[1]).dy),
      );

      await pumpAt(400);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(actionButtonFinder.first).width, 160);
      expect(tester.getSize(actionButtonFinder.last).width, 160);
      expect(
        tester.getCenter(narrowButtons[0]).dy,
        closeTo(tester.getCenter(narrowButtons[1]).dy, 0.1),
      );
      await tester.binding.setSurfaceSize(null);
    });
  }
}
