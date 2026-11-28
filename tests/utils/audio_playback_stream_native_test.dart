import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/utils/audio_playback_stub.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeAudioSource extends Fake implements AudioSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioSource());
  });

  test(
    'stop during native source setup prevents playback from starting',
    () async {
      final player = _MockAudioPlayer();
      final setupStarted = Completer<void>();
      final setup = Completer<Duration?>();
      final disposeStarted = Completer<void>();
      when(() => player.positionStream).thenAnswer((_) => const Stream.empty());
      when(() => player.durationStream).thenAnswer((_) => const Stream.empty());
      when(() => player.playerStateStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => player.setAudioSource(any<AudioSource>())).thenAnswer((_) {
        setupStarted.complete();
        return setup.future;
      });
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) {
        if (!disposeStarted.isCompleted) disposeStarted.complete();
        return Future<void>.value();
      });

      final adapter = AudioPlayerAdapter(createPlayer: () => player);
      final playback = adapter.playStream(
        Stream<Uint8List>.empty(),
        contentType: 'audio/wav',
      );
      await setupStarted.future;

      adapter.stop();
      await playback;
      await disposeStarted.future;
      verify(() => player.dispose()).called(1);
      setup.complete(null);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => player.play());
      await adapter.dispose();
    },
  );

  test(
    'dispose during native player replacement prevents creating another player',
    () async {
      final player = _MockAudioPlayer();
      final disposeStarted = Completer<void>();
      final releaseDispose = Completer<void>();
      var createdPlayers = 0;
      when(() => player.positionStream).thenAnswer((_) => const Stream.empty());
      when(() => player.durationStream).thenAnswer((_) => const Stream.empty());
      when(() => player.playerStateStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => player.setAudioSource(any<AudioSource>()))
          .thenAnswer((_) async => null);
      when(() => player.dispose()).thenAnswer((_) {
        if (!disposeStarted.isCompleted) disposeStarted.complete();
        return releaseDispose.future;
      });

      final adapter = AudioPlayerAdapter(
        createPlayer: () {
          createdPlayers++;
          return player;
        },
      );
      await adapter.load('first');

      final replacementLoad = adapter.load('replacement');
      await disposeStarted.future;
      final disposal = adapter.dispose();
      releaseDispose.complete();
      await Future.wait([replacementLoad, disposal]);

      expect(createdPlayers, 1);
      verify(() => player.setAudioSource(any<AudioSource>())).called(1);
    },
  );
}
