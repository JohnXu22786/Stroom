// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';
import 'package:stroom/l10n/app_localizations.dart';

Widget buildMermaidPreviewWebControls({
  Key? key,
  required VoidCallback onZoomOut,
  required VoidCallback onZoomIn,
  required VoidCallback onClose,
  required Color backgroundColor,
  required Color foregroundColor,
  required double topInset,
}) =>
    _MermaidPreviewWebControls(
      key: key,
      onZoomOut: onZoomOut,
      onZoomIn: onZoomIn,
      onClose: onClose,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      topInset: topInset,
    );

class _MermaidPreviewWebControls extends StatefulWidget {
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onClose;
  final Color backgroundColor;
  final Color foregroundColor;
  final double topInset;

  const _MermaidPreviewWebControls({
    super.key,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onClose,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.topInset,
  });

  @override
  State<_MermaidPreviewWebControls> createState() =>
      _MermaidPreviewWebControlsState();
}

class _MermaidPreviewWebControlsState
    extends State<_MermaidPreviewWebControls> {
  html.DivElement? _element;
  final List<StreamSubscription<html.MouseEvent>> _clickSubscriptions = [];
  final List<StreamSubscription<html.Event>> _motionSubscriptions = [];
  html.DivElement? _title;
  html.SpanElement? _titleText;
  html.MediaQueryList? _reducedMotion;
  int? _animationFrame;
  int _phase = 0;
  double _phaseStartedAt = 0;
  double _travel = 0;
  bool _motionPaused = false;
  bool _isRtl = false;
  double? _pausedAt;

  @override
  void initState() {
    super.initState();
    final element = html.DivElement()
      ..setAttribute('data-mermaid-preview-controls', 'true');
    _element = element;
    html.document.body!.append(element);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final element = _element;
    if (element != null) _renderControls(element);
  }

  void _renderControls(html.DivElement root) {
    _stopTitleMotion();
    for (final subscription in _clickSubscriptions) {
      unawaited(subscription.cancel());
    }
    _clickSubscriptions.clear();
    root.children.clear();
    root.style
      ..display = 'block'
      ..position = 'fixed'
      ..top = '${widget.topInset}px'
      ..left = '0'
      ..right = '0'
      ..height = '44px'
      ..zIndex = '2147483647'
      ..setProperty('pointer-events', 'none');

    final bar = html.DivElement();
    bar.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..right = '0'
      ..height = '44px'
      ..boxSizing = 'border-box'
      ..display = 'flex'
      ..alignItems = 'center'
      ..justifyContent = 'space-between'
      ..padding = '0 8px'
      ..fontFamily = 'sans-serif'
      ..setProperty('pointer-events', 'none');

    final zoomGroup = html.DivElement();
    zoomGroup.style
      ..display = 'flex'
      ..borderRadius = '20px'
      ..backgroundColor = _rgba(widget.backgroundColor, 0.85)
      ..setProperty('pointer-events', 'none');
    zoomGroup.append(_button(
      label: AppLocalizations.of(context)!.chatZoomOut,
      action: 'zoom-out',
      glyph: '−',
      onClick: widget.onZoomOut,
      circular: false,
    ));
    zoomGroup.append(_button(
      label: AppLocalizations.of(context)!.chatZoomIn,
      action: 'zoom-in',
      glyph: '+',
      onClick: widget.onZoomIn,
      circular: false,
    ));

    final titleSlot = html.DivElement()
      ..setAttribute('data-mermaid-preview-controls-title-slot', 'true');
    titleSlot.style
      ..flex = '1 1 0'
      ..minWidth = '0'
      ..height = '100%'
      ..display = 'flex'
      ..alignItems = 'center'
      ..justifyContent = 'center'
      ..margin = '0 4px'
      ..setProperty('pointer-events', 'none');

    final title = html.DivElement()
      ..setAttribute('data-mermaid-preview-controls-title', 'true')
      ..setAttribute('role', 'heading')
      ..setAttribute('aria-level', '2')
      ..setAttribute('data-motion-state', 'stationary');
    final titleText = html.SpanElement()
      ..setAttribute('data-mermaid-preview-controls-title-text', 'true')
      ..text = AppLocalizations.of(context)!.chatMermaidPreview;
    title.style
      ..display = 'inline-block'
      ..boxSizing = 'border-box'
      ..maxWidth = '100%'
      ..overflow = 'hidden'
      ..padding = '6px 12px'
      ..borderRadius = '16px'
      ..backgroundColor = _rgba(widget.backgroundColor, 0.85)
      ..color = _rgba(widget.foregroundColor, 1)
      ..fontSize = '13px'
      ..whiteSpace = 'nowrap'
      ..setProperty('pointer-events', 'none');
    titleText.style
      ..display = 'block'
      ..width = 'max-content'
      ..maxWidth = 'none'
      ..whiteSpace = 'nowrap'
      ..fontWeight = '500'
      ..textAlign = 'start'
      ..setProperty('will-change', 'transform');
    title.append(titleText);
    titleSlot.append(title);
    _title = title;
    _titleText = titleText;

    final close = _button(
      label: AppLocalizations.of(context)!.chatPreviewClose,
      action: 'close',
      glyph: '×',
      onClick: widget.onClose,
      circular: true,
    );
    final closeSlot = html.DivElement();
    closeSlot.style
      ..width = '40px'
      ..height = '40px'
      ..setProperty('pointer-events', 'none');
    closeSlot.append(close);

    bar.append(zoomGroup);
    bar.append(titleSlot);
    bar.append(closeSlot);
    root.append(bar);
    _startTitleMotion();
  }

  void _startTitleMotion() {
    final title = _title;
    final titleText = _titleText;
    if (title == null || titleText == null) return;

    _isRtl = Directionality.of(context) == TextDirection.rtl;
    titleText.style.direction = _isRtl ? 'rtl' : 'ltr';
    _reducedMotion = html.window.matchMedia('(prefers-reduced-motion: reduce)');
    _motionPaused = html.document.visibilityState == 'hidden';
    _motionSubscriptions
      ..add(_reducedMotion!.onChange.listen((_) => _measureTitle()))
      ..add(
        html.document.onVisibilityChange.listen((_) {
          final now = html.window.performance.now();
          if (html.document.visibilityState == 'hidden') {
            _motionPaused = true;
            _pausedAt = now;
            _cancelAnimationFrame();
          } else {
            final pausedAt = _pausedAt;
            if (pausedAt != null) _phaseStartedAt += now - pausedAt;
            _pausedAt = null;
            _motionPaused = false;
            _scheduleMotionFrame();
          }
        }),
      )
      ..add(html.window.onResize.listen((_) => _measureTitle()));
    _measureTitle();
  }

  void _measureTitle() {
    final title = _title;
    final titleText = _titleText;
    if (title == null || titleText == null) return;
    _cancelAnimationFrame();
    _travel = (titleText.scrollWidth - title.clientWidth + 24).toDouble();
    final startOffset = _isRtl ? -_travel : 0.0;
    titleText.style.transform = 'translateX(${startOffset}px)';
    if (_travel <= 0 || (_reducedMotion?.matches ?? false)) {
      title.setAttribute('data-motion-state', 'stationary');
      if (_travel <= 0) titleText.style.transform = 'translateX(0px)';
      return;
    }
    _phase = -1;
    _phaseStartedAt = 0;
    title.setAttribute('data-motion-state', 'waiting');
    if (!_motionPaused) _scheduleMotionFrame();
  }

  void _scheduleMotionFrame() {
    if (_animationFrame != null || _motionPaused) return;
    _animationFrame = html.window.requestAnimationFrame(_tickTitleMotion);
  }

  void _tickTitleMotion(num timestamp) {
    _animationFrame = null;
    final title = _title;
    final titleText = _titleText;
    if (title == null || titleText == null || _motionPaused) return;
    if (_phaseStartedAt == 0) _phaseStartedAt = timestamp.toDouble();

    final moveDuration = _travel / 24 * 1000;
    final phaseDuration = switch (_phase) {
      -1 => 1000.0,
      0 || 2 => moveDuration,
      _ => 2000.0,
    };
    final elapsed = timestamp - _phaseStartedAt;
    final progress = (elapsed / phaseDuration).clamp(0.0, 1.0).toDouble();
    final startOffset = _isRtl ? -_travel : 0.0;
    final endOffset = _isRtl ? 0.0 : -_travel;
    final offset = switch (_phase) {
      0 => startOffset + (endOffset - startOffset) * progress,
      1 => endOffset,
      2 => endOffset + (startOffset - endOffset) * progress,
      _ => startOffset,
    };
    titleText.style.transform = 'translateX(${offset}px)';
    title.setAttribute(
      'data-motion-state',
      _phase == -1
          ? 'waiting'
          : (_phase == 0 || _phase == 2)
              ? 'moving'
              : 'paused',
    );
    if (progress >= 1) {
      _phase = _phase == -1 ? 0 : (_phase + 1) % 4;
      _phaseStartedAt = timestamp.toDouble();
    }
    _scheduleMotionFrame();
  }

  void _cancelAnimationFrame() {
    final frame = _animationFrame;
    if (frame != null) html.window.cancelAnimationFrame(frame);
    _animationFrame = null;
  }

  void _stopTitleMotion() {
    _cancelAnimationFrame();
    for (final subscription in _motionSubscriptions) {
      unawaited(subscription.cancel());
    }
    _motionSubscriptions.clear();
    _reducedMotion = null;
    _title = null;
    _titleText = null;
    _pausedAt = null;
    _phaseStartedAt = 0;
  }

  html.ButtonElement _button({
    required String label,
    required String action,
    required String glyph,
    required VoidCallback onClick,
    required bool circular,
  }) {
    final button = html.ButtonElement()
      ..type = 'button'
      ..text = glyph
      ..setAttribute('aria-label', label)
      ..setAttribute('data-action', action)
      ..title = label;
    button.style
      ..display = 'inline-flex'
      ..alignItems = 'center'
      ..justifyContent = 'center'
      ..width = '40px'
      ..height = '40px'
      ..border = '0'
      ..borderRadius = circular ? '50%' : '20px'
      ..backgroundColor =
          circular ? _rgba(widget.backgroundColor, 0.85) : 'transparent'
      ..color = _rgba(widget.foregroundColor, 1)
      ..fontSize = circular ? '24px' : '21px'
      ..lineHeight = '1'
      ..cursor = 'pointer'
      ..setProperty('pointer-events', 'auto');
    _clickSubscriptions.add(button.onClick.listen((_) => onClick()));
    return button;
  }

  String _rgba(Color color, double opacity) {
    final value = color.toARGB32();
    final alpha = ((value >> 24) & 0xff) / 255 * opacity;
    return 'rgba(${(value >> 16) & 0xff}, ${(value >> 8) & 0xff}, '
        '${value & 0xff}, $alpha)';
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  void didUpdateWidget(covariant _MermaidPreviewWebControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final element = _element;
    if (element != null) _renderControls(element);
  }

  @override
  void dispose() {
    _stopTitleMotion();
    for (final subscription in _clickSubscriptions) {
      unawaited(subscription.cancel());
    }
    _element?.remove();
    _element = null;
    super.dispose();
  }
}
