import 'package:flutter/material.dart';

/// Floating overlay buttons over the chat list's bottom-right corner:
///
///  - the **scroll-to-bottom button**, shown whenever the list is NOT at
///    the bottom (plays a scale + fade in/out via [AnimatedSwitcher]), and
///  - the **keyboard-dismiss button**, shown while the soft keyboard is
///    open (plays the same scale + fade in/out AND slides between the
///    left-of-scroll slot and the corner via [AnimatedPositioned]).
///
/// Both buttons' visibility state is owned HERE, not by the chat page:
///  - the keyboard state comes from this widget's own
///    [WidgetsBindingObserver], reading the view insets directly (the
///    page's enclosing Scaffold strips viewInsets from MediaQuery, so the
///    insets must come from the View — same as the page's own keyboard
///    session logic); and
///  - the scroll button's visibility is recomputed from the CURRENT
///    scroll metrics on every scroll event, every keyboard metrics change
///    and every [metricsTick] (a notifier the page bumps from its
///    ScrollMetricsNotification handler — it fires for viewport-only
///    changes like composer growth that produce no scroll event).
///
/// Owning the state here means a keyboard transition or an at-bottom flip
/// rebuilds ONLY this small subtree. If the page owned these flags, every
/// flip would rebuild the whole chat page — including every visible
/// markdown message (MarkdownWidget re-parses the markdown on any
/// rebuild), which is exactly what dropped frames during the keyboard
/// open/close animation.
class ChatOverlayButtons extends StatefulWidget {
  const ChatOverlayButtons({
    super.key,
    required this.scrollController,
    required this.metricsTick,
    required this.isDark,
    required this.onScrollToBottomTap,
    required this.onKeyboardDismissTap,
  });

  /// The chat list's scroll controller. The button visibility is judged
  /// from its CURRENT position on every scroll/metrics change, never from
  /// the last action — an idle scroll position does not notify its
  /// controller listeners on viewport-only changes, so those come in via
  /// [metricsTick] instead.
  final ScrollController scrollController;

  /// Bumped by the page whenever a [ScrollMetricsNotification] fires
  /// (every frame any scroll metric moves, including viewport-only
  /// changes). Listened to as a cheap "metrics changed, recompute"
  /// signal; the recompute itself runs post-frame.
  final Listenable metricsTick;

  /// Whether the surrounding theme is dark (button colors follow it).
  final bool isDark;

  /// Called when the scroll-to-bottom button is tapped: the page scrolls
  /// to the bottom and re-engages auto-scroll.
  final VoidCallback onScrollToBottomTap;

  /// Called when the keyboard-dismiss button is tapped: the page
  /// unfocuses the composer so the soft keyboard collapses.
  final VoidCallback onKeyboardDismissTap;

  /// Insets (logical px) above which the soft keyboard is considered
  /// visible. Non-keyboard system bars live in [MediaQueryData.padding],
  /// not viewInsets, so a small threshold cannot misfire.
  static const double keyboardVisibleThreshold = 20;

  /// Distance from the bottom within which the list counts as "at the
  /// bottom": the scroll-to-bottom button stays hidden.
  static const double atBottomWindowPx = 80;

  /// Edge margin (logical px) of the overlay buttons from the chat area's
  /// bottom-right corner.
  static const double overlayButtonMargin = 16;

  /// Diameter of the circular overlay buttons.
  static const double overlayButtonSize = 36;

  /// Horizontal gap between the keyboard-dismiss button and the
  /// scroll-to-bottom button when both are visible.
  static const double overlayButtonGap = 8;

  /// Duration of the overlay switch animations: the scroll-to-bottom
  /// button's scale+fade in/out, the keyboard-dismiss button's non-linear
  /// slide between its left-of-scroll slot and the corner, and its
  /// scale+fade in/out.
  static const Duration overlaySwitchDuration = Duration(milliseconds: 250);

  /// Non-linear curve for the overlay switch animations.
  static const Curve overlaySwitchCurve = Curves.easeOutCubic;

  @override
  State<ChatOverlayButtons> createState() => _ChatOverlayButtonsState();
}

class _ChatOverlayButtonsState extends State<ChatOverlayButtons>
    with WidgetsBindingObserver {
  /// Whether the soft keyboard is currently visible. Tracked by this
  /// widget's own observer (the view's viewInsets change on every frame
  /// of the keyboard animation; only the show/hide transitions matter).
  bool _wasKeyboardVisible = false;

  /// Whether the initial keyboard state was seeded from the view in
  /// [didChangeDependencies] (the only place an inherited lookup like
  /// [View.of] is legal before the first build).
  bool _keyboardStateSeeded = false;

  /// Whether the scroll-to-bottom button should be visible. Recomputed
  /// from the CURRENT list metrics (never from the last action), so it is
  /// truthful even for metric-only changes that fire no scroll event.
  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController.addListener(_onScroll);
    widget.metricsTick.addListener(_onMetricsTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed the keyboard state from the view so a keyboard that is ALREADY
    // open when this widget mounts (e.g. the chat tab was kept alive while
    // the keyboard opened elsewhere) shows the dismiss button immediately.
    if (!_keyboardStateSeeded) {
      _keyboardStateSeeded = true;
      _wasKeyboardVisible =
          _currentKeyboardInset() > ChatOverlayButtons.keyboardVisibleThreshold;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.scrollController.removeListener(_onScroll);
    widget.metricsTick.removeListener(_onMetricsTick);
    super.dispose();
  }

  /// Current soft-keyboard inset in logical pixels, read from the VIEW
  /// (fresh) instead of the inherited [MediaQuery] (which is stripped by
  /// the enclosing Scaffold's resizeToAvoidBottomInset and would always
  /// read 0 here).
  double _currentKeyboardInset() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final isNowVisible =
        _currentKeyboardInset() > ChatOverlayButtons.keyboardVisibleThreshold;
    if (isNowVisible != _wasKeyboardVisible) {
      setState(() => _wasKeyboardVisible = isNowVisible);
    }
    // The keyboard resizes the viewport, which moves the at-bottom
    // relationship WITHOUT firing a scroll event — recompute the scroll
    // button from the new metrics, post-frame so the layout has settled.
    _schedulePostFrameRecompute();
  }

  /// Scroll events: the pixels moved (or a programmatic jump landed), so
  /// the at-bottom relationship may have changed.
  void _onScroll() {
    _recomputeScrollButtonState();
  }

  /// The page's ScrollMetricsNotification handler bumped [metricsTick] —
  /// some metric changed (scroll, keyboard viewport, composer growth,
  /// sliver extent correction). Recompute post-frame, coalescing all
  /// notifications of the frame into one recompute.
  void _onMetricsTick() {
    _schedulePostFrameRecompute();
  }

  /// Registers the post-frame recompute AND schedules the frame it needs.
  /// [SchedulerBinding.addPostFrameCallback] alone does NOT schedule a
  /// frame — if the trigger fires while no frame is pending (e.g. a
  /// composer-growth metrics notification dispatched in the microtask
  /// after the frame that grew the composer, or a handleMetricsChanged
  /// with no animation running), the recompute would never run and the
  /// button would go stale until the next scroll or animation.
  /// [SchedulerBinding.scheduleFrame] is a no-op when a frame is already
  /// scheduled, so this is free during scrolls/keyboard animations.
  void _schedulePostFrameRecompute() {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recomputeScrollButtonState();
    });
  }

  /// Recomputes the scroll-to-bottom button visibility from the CURRENT
  /// list metrics ("is the user at the bottom?"). Idempotent: no setState
  /// when nothing changed. Deliberately touches ONLY the button flag —
  /// the auto-scroll flag stays with the page's scroll bookkeeping, which
  /// owns the content-growth follow.
  void _recomputeScrollButtonState() {
    if (!widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final isAtBottom = (pos.maxScrollExtent - pos.pixels) <=
        ChatOverlayButtons.atBottomWindowPx;
    final showButton = !isAtBottom;
    if (showButton == _showScrollToBottomButton) return;
    setState(() => _showScrollToBottomButton = showButton);
  }

  @override
  Widget build(BuildContext context) {
    final size = ChatOverlayButtons.overlayButtonSize;
    final margin = ChatOverlayButtons.overlayButtonMargin;
    return Stack(
      children: [
        // ── Scroll-to-bottom overlay button ──
        // Shown whenever the list is NOT at the bottom. The AnimatedSwitcher
        // plays the non-linear scale-up + fade-in (appear) and scale-down +
        // fade-out (disappear) transition.
        Positioned(
          right: margin,
          bottom: margin,
          child: AnimatedSwitcher(
            duration: ChatOverlayButtons.overlaySwitchDuration,
            switchInCurve: ChatOverlayButtons.overlaySwitchCurve,
            switchOutCurve: ChatOverlayButtons.overlaySwitchCurve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _showScrollToBottomButton
                ? KeyedSubtree(
                    key: const ValueKey('scroll-to-bottom-button'),
                    child: _buildScrollToBottomButton(),
                  )
                : const SizedBox(
                    key: ValueKey('scroll-to-bottom-placeholder'),
                    width: ChatOverlayButtons.overlayButtonSize,
                    height: ChatOverlayButtons.overlayButtonSize,
                  ),
          ),
        ),
        // ── Keyboard-dismiss overlay button ──
        // Shown while the soft keyboard is open (the list itself never
        // dismisses it — manual behavior), so the user can close the
        // keyboard without hunting for its close key. It fades/scales in
        // and out with the same AnimatedSwitcher transition as the scroll
        // button (never a sudden pop), and slides (non-linear,
        // overlaySwitchCurve) into the scroll button's corner slot when
        // the scroll button hides.
        AnimatedPositioned(
          duration: ChatOverlayButtons.overlaySwitchDuration,
          curve: ChatOverlayButtons.overlaySwitchCurve,
          right: _showScrollToBottomButton
              ? margin + size + ChatOverlayButtons.overlayButtonGap
              : margin,
          bottom: margin,
          child: AnimatedSwitcher(
            duration: ChatOverlayButtons.overlaySwitchDuration,
            switchInCurve: ChatOverlayButtons.overlaySwitchCurve,
            switchOutCurve: ChatOverlayButtons.overlaySwitchCurve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _wasKeyboardVisible
                ? KeyedSubtree(
                    key: const ValueKey('keyboard-dismiss-button'),
                    child: _buildKeyboardDismissButton(),
                  )
                : const SizedBox(
                    key: ValueKey('keyboard-dismiss-placeholder'),
                    width: ChatOverlayButtons.overlayButtonSize,
                    height: ChatOverlayButtons.overlayButtonSize,
                  ),
          ),
        ),
      ],
    );
  }

  /// Scroll-to-bottom button: taps scroll the list to the bottom and
  /// re-engage auto-scroll (handled by the page's callback).
  Widget _buildScrollToBottomButton() {
    final isDark = widget.isDark;
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onScrollToBottomTap,
        child: Container(
          width: ChatOverlayButtons.overlayButtonSize,
          height: ChatOverlayButtons.overlayButtonSize,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_downward,
            size: 20,
            color: isDark ? Colors.grey[200] : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  /// Dismisses the soft keyboard. Bottom-right, LEFT of the scroll-to-
  /// bottom button while that button is visible; it takes over the corner
  /// slot when the scroll button is hidden. The keyboard otherwise stays
  /// up while the user reads/scrolls (the list's
  /// [ScrollViewKeyboardDismissBehavior.manual]): it is closed either via
  /// the keyboard's own close key or this button.
  Widget _buildKeyboardDismissButton() {
    final isDark = widget.isDark;
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onKeyboardDismissTap,
        child: Container(
          width: ChatOverlayButtons.overlayButtonSize,
          height: ChatOverlayButtons.overlayButtonSize,
          alignment: Alignment.center,
          child: Icon(
            Icons.keyboard_hide,
            size: 20,
            color: isDark ? Colors.grey[200] : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
