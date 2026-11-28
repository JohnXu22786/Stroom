import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/utils/audio_playback.dart';

// Functional suite mapping: feature-ui.
void main() {
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ignores a delayed JSON response after route disposal', (
    tester,
  ) async {
    final harness = await _startTestAudio(tester);

    await harness.disposeRoute();
    expect(find.byType(ModelConfigPage), findsNothing);
    harness.complete(
      body: '{"error":"bad request"}',
      contentType: 'application/json',
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(harness.responseHandled, isFalse);
    expect(harness.playerCreations, 0);
  });

  testWidgets('ignores a delayed empty response after route disposal', (
    tester,
  ) async {
    final harness = await _startTestAudio(tester);

    await harness.disposeRoute();
    expect(find.byType(ModelConfigPage), findsNothing);
    harness.complete(body: '', contentType: 'audio/wav');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(harness.responseHandled, isFalse);
    expect(harness.playerCreations, 0);
  });

  testWidgets('does not create a player for delayed audio after disposal', (
    tester,
  ) async {
    final harness = await _startTestAudio(tester);

    await harness.disposeRoute();
    expect(find.byType(ModelConfigPage), findsNothing);
    harness.complete(body: 'audio bytes', contentType: 'audio/wav');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(harness.responseHandled, isFalse);
    expect(harness.playerCreations, 0);
  });
}

Future<_Harness> _startTestAudio(WidgetTester tester) async {
  final response = Completer<Response<dynamic>>();
  var playerCreations = 0;
  var responseHandled = false;
  final configState = ProviderEntriesState(
    entries: [
      ProviderEntry(
        id: 'entry',
        name: 'Test provider',
        configs: [
          ProviderConfigItem(
            host: 'https://example.test/audio',
            key: 'test-key',
            models: [ModelConfig(name: 'Test model', modelId: 'test-model')],
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith((ref) {
          final notifier = _TestProviderEntriesNotifier();
          notifier.setState(configState);
          return notifier;
        }),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ModelConfigPage(
                      entryId: 'entry',
                      configIndex: 0,
                      modelIndex: 0,
                      testAudioRequest: (host, body) => response.future,
                      testAudioPlayerFactory: () {
                        playerCreations++;
                        return _FakeAudioPlayerAdapter();
                      },
                      testOnAudioResponseHandled: () => responseHandled = true,
                    ),
                  ),
                ),
                child: const Text('Open model config'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open model config'));
  await tester.pumpAndSettle();
  final playButton = find.text(
    AppLocalizations.of(tester.element(find.byType(ModelConfigPage)))!
        .modelPlayTestAudio,
  );
  for (var i = 0; i < 12 && playButton.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
  }
  expect(playButton, findsOneWidget);
  await tester.ensureVisible(playButton);
  await tester.pump();
  tester
      .widget<ElevatedButton>(
        find.ancestor(of: playButton, matching: find.byType(ElevatedButton)),
      )
      .onPressed!
      .call();
  await tester.pump();

  return _Harness(
    response: response,
    getPlayerCreations: () => playerCreations,
    getResponseHandled: () => responseHandled,
    disposeRoute: () => tester.pumpWidget(const SizedBox.shrink()),
  );
}

class _Harness {
  final Completer<Response<dynamic>> response;
  final int Function() getPlayerCreations;
  final bool Function() getResponseHandled;
  final Future<void> Function() disposeRoute;

  int get playerCreations => getPlayerCreations();
  bool get responseHandled => getResponseHandled();

  _Harness({
    required this.response,
    required this.getPlayerCreations,
    required this.getResponseHandled,
    required this.disposeRoute,
  });

  void complete({required String body, required String contentType}) {
    response.complete(
      Response<dynamic>(
        requestOptions: RequestOptions(path: 'https://example.test/audio'),
        data: body.codeUnits,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: [contentType],
        }),
      ),
    );
  }
}

class _TestProviderEntriesNotifier extends ProviderEntriesNotifier {
  void setState(ProviderEntriesState state) => this.state = state;
}

class _FakeAudioPlayerAdapter extends AudioPlayerAdapter {
  @override
  Future<void> load(String url) async {}

  @override
  Future<void> play() async {}
}
