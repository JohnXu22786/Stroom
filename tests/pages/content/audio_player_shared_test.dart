import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/audio_player_shared.dart';

void main() {
  testWidgets('audio player helper views use the selected locale',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Column(
            children: [
              Expanded(
                child: AudioPlayerErrorView(
                  errorMessage: 'Decoder failure',
                  diagnosticInfo: '',
                  onRetry: () {},
                ),
              ),
              Expanded(child: buildAudioLoadingView(context)),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Playback failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Loading audio...'), findsOneWidget);
    expect(find.text('Decoder failure'), findsOneWidget);
  });
}
