import 'dart:async';

import 'package:flutter/widgets.dart';

/// Waits for a route's exit transition to finish after [Navigator.pop].
///
/// Pages that "pop immediately and continue in the background" must not
/// start heavy background work (Riverpod rebuilds, image rasterization,
/// isolate processing) while the pop transition is still animating —
/// the background work competes with the transition frames and freezes
/// the animation mid-flight.
///
/// [route] must be captured from `ModalRoute.of(context)` BEFORE the
/// pop is scheduled (after the pop the route is no longer the current
/// route, so `ModalRoute.of(context)` returns the route below).
///
/// The route's secondary [Animation] status reaching [AnimationStatus.dismissed]
/// is the exact moment the exit transition completes. (`route.popped`
/// cannot be used — it completes synchronously in `ModalRoute.didPop`,
/// BEFORE the animation even starts.)
Future<void> waitForPopAnimation(ModalRoute<dynamic>? route) async {
  final animation = route?.animation;
  if (animation != null && animation.status != AnimationStatus.dismissed) {
    final done = Completer<void>();
    void listener(AnimationStatus s) {
      if (s == AnimationStatus.dismissed) {
        if (!done.isCompleted) done.complete();
        animation.removeStatusListener(listener);
      }
    }

    animation.addStatusListener(listener);
    await done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        animation.removeStatusListener(listener);
        // Timeout waiting for the transition — proceed anyway rather
        // than silently dropping the background work.
      },
    );
  } else if (route == null) {
    // No route — unexpected, but guard with a fallback delay.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  // Implicit else: animation already dismissed — no wait needed;
  // fall through immediately.
}
