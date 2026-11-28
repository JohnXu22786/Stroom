import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/utils/audio_playback_stub.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _MockPlayerState extends Mock implements PlayerState {}

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

  test(
    'overlapping native loads create a player only for the latest request',
    () async {
      final players = [_MockAudioPlayer(), _MockAudioPlayer()];
      var createdPlayers = 0;
      for (final player in players) {
        when(() => player.positionStream)
            .thenAnswer((_) => const Stream.empty());
        when(() => player.durationStream)
            .thenAnswer((_) => const Stream.empty());
        when(() => player.playerStateStream)
            .thenAnswer((_) => const Stream.empty());
        when(() => player.setAudioSource(any<AudioSource>()))
            .thenAnswer((_) async => null);
        when(() => player.dispose()).thenAnswer((_) async {});
      }

      final adapter = AudioPlayerAdapter(
        createPlayer: () => players[createdPlayers++],
      );
      addTearDown(adapter.dispose);

      final staleLoad = adapter.load('stale');
      final latestLoad = adapter.load('latest');
      await Future.wait([staleLoad, latestLoad]);

      expect(createdPlayers, 1);
      final source =
          verify(() => players.first.setAudioSource(captureAny<AudioSource>()))
              .captured
              .single as UriAudioSource;
      expect(source.uri, Uri.parse('latest'));
      verifyNever(() => players.last.setAudioSource(any<AudioSource>()));
    },
  );

  test(
    'a stale native source completion does not emit active-load state',
    () async {
      final firstPlayer = _MockAudioPlayer();
      final latestPlayer = _MockAudioPlayer();
      final firstSetupStarted = Completer<void>();
      final firstSetup = Completer<Duration?>();
      final players = [firstPlayer, latestPlayer];
      var createdPlayers = 0;
      for (final player in players) {
        when(() => player.positionStream)
            .thenAnswer((_) => const Stream.empty());
        when(() => player.durationStream)
            .thenAnswer((_) => const Stream.empty());
        when(() => player.playerStateStream)
            .thenAnswer((_) => const Stream.empty());
        when(() => player.dispose()).thenAnswer((_) async {});
      }
      when(() => firstPlayer.setAudioSource(any<AudioSource>()))
          .thenAnswer((_) {
        firstSetupStarted.complete();
        return firstSetup.future;
      });
      when(() => latestPlayer.setAudioSource(any<AudioSource>()))
          .thenAnswer((_) async => null);

      final adapter = AudioPlayerAdapter(
        createPlayer: () => players[createdPlayers++],
      );
      addTearDown(adapter.dispose);
      final stateEvents = <void>[];
      final stateSubscription = adapter.stateStream.listen(stateEvents.add);
      addTearDown(stateSubscription.cancel);

      final staleLoad = adapter.load('stale');
      await firstSetupStarted.future;
      final latestLoad = adapter.load('latest');
      await latestLoad;
      await Future<void>.delayed(Duration.zero);
      expect(stateEvents, hasLength(1));

      firstSetup.complete(null);
      await staleLoad;
      await Future<void>.delayed(Duration.zero);

      expect(stateEvents, hasLength(1));
      verify(() => firstPlayer.dispose()).called(1);
    },
  );

  test(
    'stopping keeps listeners active for the current native player',
    () async {
      final player = _MockAudioPlayer();
      final playerStates = StreamController<PlayerState>();
      when(() => player.positionStream).thenAnswer((_) => const Stream.empty());
      when(() => player.durationStream).thenAnswer((_) => const Stream.empty());
      when(() => player.playerStateStream)
          .thenAnswer((_) => playerStates.stream);
      when(() => player.setAudioSource(any<AudioSource>()))
          .thenAnswer((_) async => null);
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});

      final adapter = AudioPlayerAdapter(createPlayer: () => player);
      addTearDown(adapter.dispose);
      addTearDown(playerStates.close);
      var stateEvents = 0;
      final stateSubscription = adapter.stateStream.listen(
        (_) => stateEvents++,
      );
      addTearDown(stateSubscription.cancel);

      await adapter.load('current');
      await Future<void>.delayed(Duration.zero);
      adapter.stop();
      playerStates.add(_MockPlayerState());
      await Future<void>.delayed(Duration.zero);

      expect(stateEvents, 3);
    },
  );
}
