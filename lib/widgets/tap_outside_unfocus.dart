import 'package:flutter/widgets.dart';

/// Makes tapping outside a focused text field blur it, on every platform
/// and pointer kind.
///
/// Flutter's default [EditableTextTapOutsideIntent] action only unfocuses
/// on desktop platforms (and for mouse/stylus events on mobile); a mobile
/// touch outside a focused field deliberately leaves the field focused —
/// the cursor stays and the soft keyboard stays up, which reads as
/// "I can't leave this input". Overriding the intent at the app root makes
/// the tap-outside blur behavior uniform across all platforms.
///
/// The SDK explicitly documents this as the extension point ("To change
/// this behavior, a callback may be set here or [EditableTextTapOutsideIntent]
/// may be overridden"). Fields that set their own `onTapOutside` keep their
/// custom behavior; only fields with the default (null) handler are
/// affected. Pages that want to keep the keyboard while interacting with a
/// sibling area can group that area with the field via [TextFieldTapRegion]
/// and a shared `groupId` (see the chat message list).
class TapOutsideUnfocus extends StatelessWidget {
  const TapOutsideUnfocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) => intent.focusNode.unfocus(),
        ),
      },
      child: child,
    );
  }
}
