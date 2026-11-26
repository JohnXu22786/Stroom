import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_recording_page.dart';

void main() {
  testWidgets('fitting labels retain 48 px buttons with centered icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingActionButton(
            onPressed: () {},
            icon: Icons.pause_circle_filled,
            label: 'Pause',
            color: Colors.orange,
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byType(ElevatedButton));
    final labelRect = tester.getRect(find.text('Pause'));
    final iconRect = tester.getRect(find.byIcon(Icons.pause_circle_filled));
    expect(buttonRect.height, 48);
    expect(iconRect.center.dy, closeTo(labelRect.center.dy, 0.1));
    expect(buttonRect.contains(labelRect.topLeft), isTrue);
    expect(buttonRect.contains(labelRect.bottomRight), isTrue);
  });

  testWidgets('scaled French labels expand the button slot around its icon', (
    tester,
  ) async {
    const labels = ['Mettre en pause', 'Arrêter'];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: Scaffold(
            body: RecordingActionGroup(
              buttons: [
                for (var i = 0; i < labels.length; i++)
                  RecordingActionButton(
                    onPressed: () {},
                    icon: i == 0 ? Icons.pause_circle_filled : Icons.stop,
                    label: labels[i],
                    color: Colors.orange,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final label in labels) {
      final buttonRect = tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(ElevatedButton),
        ),
      );
      final labelRect = tester.getRect(find.text(label));
      final icon =
          label == labels.first ? Icons.pause_circle_filled : Icons.stop;
      final iconRect = tester.getRect(find.byIcon(icon));
      expect(buttonRect.height, greaterThan(48));
      expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
      expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
      expect(iconRect.top, greaterThanOrEqualTo(buttonRect.top));
      expect(iconRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
      expect(iconRect.center.dy, closeTo(labelRect.center.dy, 0.1));
    }
  });

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
