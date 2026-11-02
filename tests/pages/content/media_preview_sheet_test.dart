import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(
      AudioSource.uri(Uri.parse('https://example.invalid/fallback.mp3')),
    );
  });

  group('MediaPreviewSheet', () {
    testWidgets('plays supported audio candidates in the sheet', (
      tester,
    ) async {
      final originalOverrides = HttpOverrides.global;
      final httpOverrides = _BlockingHttpOverrides();
      HttpOverrides.global = httpOverrides;
      addTearDown(() => HttpOverrides.global = originalOverrides);

      final player = _MockAudioPlayer();
      final positionController = StreamController<Duration>.broadcast();
      final durationController = StreamController<Duration?>.broadcast();
      final playerStateController = StreamController<PlayerState>.broadcast();
      final processingStateController =
          StreamController<ProcessingState>.broadcast();
      final errorController = StreamController<PlayerException>.broadcast();
      when(() => player.positionStream)
          .thenAnswer((_) => positionController.stream);
      when(() => player.durationStream)
          .thenAnswer((_) => durationController.stream);
      when(() => player.playerStateStream)
          .thenAnswer((_) => playerStateController.stream);
      when(() => player.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);
      when(() => player.errorStream).thenAnswer((_) => errorController.stream);
      when(() => player.setAudioSource(any<AudioSource>()))
          .thenAnswer((_) async => const Duration(hours: 1, minutes: 2));
      when(() => player.play()).thenAnswer((_) async {});
      when(() => player.pause()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaPreviewSheet(
              resource: const MediaResource(
                url: 'https://example.invalid/audio.mp3',
                name: 'audio',
                ext: 'mp3',
                isPlayable: true,
              ),
              taskTitle: 'Audio preview',
              audioPlayerFactory: () => player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(httpOverrides.requested, isFalse);
      expect(find.byTooltip('Play audio'), findsOneWidget);
      expect(find.text('62:00'), findsOneWidget);
      verify(() => player.setAudioSource(any<AudioSource>())).called(1);

      await tester.tap(find.byTooltip('Play audio'));
      await tester.pump();
      verify(() => player.play()).called(1);

      errorController.add(PlayerException(1, 'connection lost', 0));
      await tester.pump();
      expect(find.textContaining('connection lost'), findsOneWidget);
      expect(find.byTooltip('Play audio'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      verify(() => player.dispose()).called(1);
      await positionController.close();
      await durationController.close();
      await playerStateController.close();
      await processingStateController.close();
      await errorController.close();
    });

    testWidgets('shows unsupported format error for unknown extensions', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaPreviewSheet(
              resource: MediaResource(
                url: 'https://example.com/file.xyz',
                name: 'file',
                ext: 'xyz',
              ),
              taskTitle: 'Test',
            ),
          ),
        ),
      );

      // Wait for async init
      await tester.pump(const Duration(seconds: 1));

      // Should show error about unsupported format
      expect(find.text('不支持此格式预览'), findsOneWidget);
    });
  });
}

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _BlockingHttpOverrides extends HttpOverrides {
  bool requested = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    requested = true;
    throw StateError('Audio preview should not download the media file.');
  }
}
