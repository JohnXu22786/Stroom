import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

Widget _previewApp({
  required MediaResource resource,
  AudioPlayer? player,
  double textScale = 1,
}) =>
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: MediaPreviewSheet(
            resource: resource,
            taskTitle: 'Media preview',
            audioPlayerFactory: player == null ? null : () => player,
          ),
        ),
      ),
    );

void _setViewport(WidgetTester tester, Size physicalSize, double scale) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = scale;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(
      AudioSource.uri(Uri.parse('https://example.invalid/fallback.mp3')),
    );
  });

  testWidgets(
    'long audio metadata and playback controls scroll in narrow and scaled viewports',
    (tester) async {
      final player = _MockAudioPlayer();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration?>.broadcast();
      final playerState = StreamController<PlayerState>.broadcast();
      final processingState = StreamController<ProcessingState>.broadcast();
      final errors = StreamController<PlayerException>.broadcast();
      when(() => player.positionStream).thenAnswer((_) => position.stream);
      when(() => player.durationStream).thenAnswer((_) => duration.stream);
      when(() => player.playerStateStream)
          .thenAnswer((_) => playerState.stream);
      when(() => player.processingStateStream)
          .thenAnswer((_) => processingState.stream);
      when(() => player.errorStream).thenAnswer((_) => errors.stream);
      when(() => player.setAudioSource(any<AudioSource>()))
          .thenAnswer((_) async => const Duration(minutes: 3));
      when(() => player.dispose()).thenAnswer((_) async {});

      final longName = List.filled(12, 'very-long-recording-name').join('_');
      final resource = MediaResource(
        url: 'https://example.invalid/audio.mp3',
        name: longName,
        ext: 'mp3',
        size: 5 * 1024 * 1024 * 1024,
      );

      for (final (physicalSize, deviceScale, textScale) in [
        (const Size(320, 640), 1.0, 1.0),
        (const Size(240, 400), 1.0, 1.0),
        (const Size(320, 640), 1.0, 2.0),
      ]) {
        _setViewport(tester, physicalSize, deviceScale);
        await tester.pumpWidget(
          _previewApp(
            resource: resource,
            player: player,
            textScale: textScale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(find.textContaining(longName), findsOneWidget);
        final playButton = find.byTooltip('Play audio');
        expect(playButton, findsOneWidget);
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, greaterThan(0));
        expect(
          tester.getRect(playButton).overlaps(
                tester.getRect(find.byType(SingleChildScrollView).first),
              ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await position.close();
      await duration.close();
      await playerState.close();
      await processingState.close();
      await errors.close();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets(
    'long audio initialization diagnostics remain reachable in a short viewport',
    (tester) async {
      _setViewport(tester, const Size(320, 480), 1);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final player = _MockAudioPlayer();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration?>.broadcast();
      final playerState = StreamController<PlayerState>.broadcast();
      final processingState = StreamController<ProcessingState>.broadcast();
      final errors = StreamController<PlayerException>.broadcast();
      when(() => player.positionStream).thenAnswer((_) => position.stream);
      when(() => player.durationStream).thenAnswer((_) => duration.stream);
      when(() => player.playerStateStream)
          .thenAnswer((_) => playerState.stream);
      when(() => player.processingStateStream)
          .thenAnswer((_) => processingState.stream);
      when(() => player.errorStream).thenAnswer((_) => errors.stream);
      final diagnostic =
          'Decoder initialization failed: ${'detail-' * 90} end-of-diagnostic';
      when(() => player.setAudioSource(any<AudioSource>()))
          .thenThrow(StateError(diagnostic));
      when(() => player.dispose()).thenAnswer((_) async {});

      await tester.pumpWidget(
        _previewApp(
          resource: const MediaResource(
            url: 'https://example.invalid/audio.mp3',
            name: 'sample',
            ext: 'mp3',
          ),
          player: player,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Decoder initialization failed'),
        findsOneWidget,
      );
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsWidgets);
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: scrollView.first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(find.textContaining('end-of-diagnostic'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await position.close();
      await duration.close();
      await playerState.close();
      await processingState.close();
      await errors.close();
    },
  );
}
