import 'package:video_player/video_player.dart';

/// Releases a controller after its initialization attempt has failed.
Future<void> disposeVideoPlayerAfterInitializationFailure(
  VideoPlayerController controller,
) async {
  // A failed create can leave video_player's creation completer unresolved,
  // and dispose waits for that completer. An event error means creation has
  // settled even if the platform did not assign a usable player ID.
  // ignore: invalid_use_of_visible_for_testing_member
  final playerId = controller.playerId;
  // ignore: invalid_use_of_visible_for_testing_member
  final wasCreated = playerId != VideoPlayerController.kUninitializedPlayerId;
  if (wasCreated || controller.value.errorDescription != null) {
    await controller.dispose();
  }
}
