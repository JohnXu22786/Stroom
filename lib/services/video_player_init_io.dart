import 'package:fvp/fvp.dart' as fvp;

/// Registers the native [fvp] video player plugin.
///
/// This must be called before using any [fvp] video player instances.
/// On Android/iOS/desktop, this registers the FFI-based native bindings.
/// The `fvp` package and its libmdk-based runtime have separate license terms;
/// see `docs/third-party-notices.md` for the reviewed versions and condition.
void registerVideoPlayer() {
  fvp.registerWith();
}
