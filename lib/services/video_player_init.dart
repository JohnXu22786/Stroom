/// Dispatches to the correct video player initialization
/// based on the available Dart libraries:
///
/// - **Native** (`dart.library.io`): uses [video_player_init_io.dart]
///   which imports `package:fvp/fvp.dart` and calls `fvp.registerWith()`.
/// - **Web** (`dart.library.html`): uses [video_player_init_stub.dart]
///   which is a no-op, since `dart:ffi` is not available on web.
///
/// This avoids compile-time errors from `package:fvp`'s `dart:ffi` import
/// when building for web.
library;
export 'video_player_init_stub.dart'
    if (dart.library.io) 'video_player_init_io.dart';
