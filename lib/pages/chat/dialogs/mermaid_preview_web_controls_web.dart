// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

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

  @override
  void initState() {
    super.initState();
    final element = html.DivElement()
      ..setAttribute('data-mermaid-preview-controls', 'true');
    _element = element;
    _renderControls(element);
    html.document.body!.append(element);
  }

  void _renderControls(html.DivElement root) {
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
      label: '缩小',
      action: 'zoom-out',
      glyph: '−',
      onClick: widget.onZoomOut,
      circular: false,
    ));
    zoomGroup.append(_button(
      label: '放大',
      action: 'zoom-in',
      glyph: '+',
      onClick: widget.onZoomIn,
      circular: false,
    ));

    final title = html.DivElement()
      ..setAttribute('data-mermaid-preview-controls-title', 'true')
      ..setAttribute('role', 'heading')
      ..setAttribute('aria-level', '2')
      ..text = 'Mermaid 预览';
    title.style
      ..position = 'absolute'
      ..left = '50%'
      ..transform = 'translateX(-50%)'
      ..padding = '6px 12px'
      ..borderRadius = '16px'
      ..backgroundColor = _rgba(widget.backgroundColor, 0.85)
      ..color = _rgba(widget.foregroundColor, 1)
      ..fontSize = '13px'
      ..whiteSpace = 'nowrap'
      ..setProperty('pointer-events', 'none');

    final close = _button(
      label: '关闭预览',
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
    bar.append(title);
    bar.append(closeSlot);
    root.append(bar);
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
    for (final subscription in _clickSubscriptions) {
      unawaited(subscription.cancel());
    }
    _element?.remove();
    _element = null;
    super.dispose();
  }
}
