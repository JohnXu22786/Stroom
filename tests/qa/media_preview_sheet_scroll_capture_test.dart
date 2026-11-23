import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';
import 'package:stroom/widgets/modal_bottom_sheet_constraints.dart';

// Functional suite mapping: media-processing; widget tests run in feature-ui.
class _MockAudioPlayer extends Mock implements AudioPlayer {}

const _captureKey = ValueKey('media-preview-scroll-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(
      AudioSource.uri(Uri.parse('https://example.invalid/fallback.mp3')),
    );
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  testWidgets('captures production audio sheet at narrow and scaled sizes', (
    tester,
  ) async {
    final cases = [
      (
        const Size(320, 640),
        1.0,
        1.0,
        '../../docs/ui-constrained-text-qa/vertical-media-preview-scroll/audio-preview-en-320x640-scale1-light.png',
      ),
      (
        const Size(320, 640),
        1.0,
        2.0,
        '../../docs/ui-constrained-text-qa/vertical-media-preview-scroll/audio-preview-en-320x640-scale2-light.png',
      ),
      (
        const Size(240, 400),
        1.0,
        1.0,
        '../../docs/ui-constrained-text-qa/vertical-media-preview-scroll/audio-preview-en-240x400-scale1-light.png',
      ),
    ];

    for (final (physicalSize, deviceScale, textScale, screenshot) in cases) {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = deviceScale;
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
          .thenAnswer((_) async => const Duration(minutes: 2, seconds: 34));
      when(() => player.dispose()).thenAnswer((_) async {});

      final resource = const MediaResource(
        url: 'https://example.invalid/field-recording.mp3',
        name: 'Field recording from the northern garden',
        ext: 'mp3',
        size: 2345678,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en', 'US'),
              theme: ThemeData.light(useMaterial3: true),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        constraints: modalBottomSheetWidthConstraints(context),
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (context) => MediaPreviewSheet(
                          resource: resource,
                          taskTitle: 'Field recording',
                          audioPlayerFactory: () => player,
                        ),
                      ),
                      child: const Text('Open preview'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Play audio'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final playButton = find.byTooltip('Play audio');
      final previewScroll = find.byType(SingleChildScrollView).first;
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: previewScroll,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      if (textScale == 1) {
        await scrollable.position.ensureVisible(
          tester.renderObject(playButton),
          alignment: 1,
        );
        await tester.pumpAndSettle();
        final playButtonRect = tester.getRect(playButton);
        final scrollRect = tester.getRect(previewScroll);
        expect(playButtonRect.top, greaterThanOrEqualTo(scrollRect.top));
        expect(playButtonRect.bottom, lessThanOrEqualTo(scrollRect.bottom + 1));
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(screenshot),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await position.close();
      await duration.close();
      await playerState.close();
      await processingState.close();
      await errors.close();
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
