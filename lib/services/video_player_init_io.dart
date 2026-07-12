import 'package:fvp/fvp.dart' as fvp;

/// Registers the native [fvp] video player plugin.
///
/// This must be called before using any [fvp] video player instances.
/// On Android/iOS/desktop, this registers the FFI-based native bindings.
void registerVideoPlayer() {
  fvp.registerWith();
}
