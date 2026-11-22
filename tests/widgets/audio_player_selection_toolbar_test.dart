import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/audio_player_shared.dart';

void main() {
  testWidgets('long German actions reflow and remain operable at 320 dp', (
    tester,
  ) async {
    var playCount = 0;
    var generateCount = 0;
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: AudioPlayerSelectionToolbar(
                playLabel: 'Auswahl abspielen',
                generateLabel: 'Auswahl erstellen',
                onPlay: () => playCount++,
                onGenerate: () => generateCount++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final playRect = tester.getRect(find.text('Auswahl abspielen'));
    final generateRect = tester.getRect(find.text('Auswahl erstellen'));
    expect(generateRect.top, greaterThan(playRect.top));

    await tester.tap(find.text('Auswahl abspielen'));
    await tester.tap(find.text('Auswahl erstellen'));
    expect(playCount, 1);
    expect(generateCount, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: AudioPlayerSelectionToolbar(
                playLabel: 'Auswahl abspielen',
                generateLabel: 'Auswahl erstellen',
                onPlay: () {},
                onGenerate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Auswahl abspielen'), findsOneWidget);
    expect(find.text('Auswahl erstellen'), findsOneWidget);
  });

  testWidgets('short actions keep the existing single-row appearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: AudioPlayerSelectionToolbar(
                playLabel: 'Play selection',
                generateLabel: 'Generate selection',
                onPlay: () {},
                onGenerate: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final playRect = tester.getRect(find.text('Play selection'));
    final generateRect = tester.getRect(find.text('Generate selection'));
    expect(generateRect.top, playRect.top);
  });
}
