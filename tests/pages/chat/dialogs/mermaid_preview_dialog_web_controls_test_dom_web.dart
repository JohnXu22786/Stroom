// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/widgets.dart';

List<String> controlLabels() {
  final controls =
      html.document.querySelector('[data-mermaid-preview-controls]');
  return controls
          ?.querySelectorAll('button')
          .map((button) => button.getAttribute('aria-label') ?? '')
          .toList() ??
      const [];
}

String? controlTitle() =>
    html.document.querySelector('[data-mermaid-preview-controls-title]')?.text;

String controlsSnapshot() {
  return html.document
          .querySelector('[data-mermaid-preview-controls]')
          ?.outerHtml ??
      '<controls layer not mounted>';
}

bool previewIframeReceivesPointer() {
  final iframe = html.document.querySelector(
    '[data-mermaid-preview-test-iframe]',
  );
  if (iframe is! html.IFrameElement) return false;
  final rect = iframe.getBoundingClientRect();
  return html.document.elementFromPoint(
        (rect.left + rect.width / 2).round(),
        (rect.top + rect.height / 2).round(),
      ) ==
      iframe;
}

String pointerHitTargetDescription(String action) {
  final button = html.document.querySelector(
    '[data-mermaid-preview-controls] button[data-action="$action"]',
  );
  if (button is! html.ButtonElement) {
    return 'No "$action" button; ${controlsSnapshot()}';
  }
  final rect = button.getBoundingClientRect();
  final hitTarget = html.document.elementFromPoint(
    (rect.left + rect.width / 2).round(),
    (rect.top + rect.height / 2).round(),
  );
  return 'button=$button rect=$rect; hitTarget=${hitTarget?.outerHtml}';
}

bool controlReceivesPointer(String action) {
  final button = html.document.querySelector(
    '[data-mermaid-preview-controls] button[data-action="$action"]',
  );
  if (button is! html.ButtonElement) return false;
  final rect = button.getBoundingClientRect();
  final hitTarget = html.document.elementFromPoint(
    (rect.left + rect.width / 2).round(),
    (rect.top + rect.height / 2).round(),
  );
  return hitTarget == button || button.contains(hitTarget);
}

void clickControl(String action) {
  final button = html.document.querySelector(
    '[data-mermaid-preview-controls] button[data-action="$action"]',
  );
  if (button == null) {
    throw StateError('Mermaid preview control "$action" was not rendered');
  }
  (button as html.ButtonElement).click();
}

Widget fakeWebViewLayer() {
  return const _FakeWebViewLayer();
}

class _FakeWebViewLayer extends StatefulWidget {
  const _FakeWebViewLayer();

  @override
  State<_FakeWebViewLayer> createState() => _FakeWebViewLayerState();
}

class _FakeWebViewLayerState extends State<_FakeWebViewLayer> {
  late final html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _iframe = html.IFrameElement()
      ..setAttribute('data-mermaid-preview-test-iframe', 'true')
      ..srcdoc = '<!doctype html><html><body></body></html>';
    _iframe.style
      ..position = 'fixed'
      ..top = '0'
      ..left = '0'
      ..width = '100vw'
      ..height = '100vh'
      ..border = '0'
      ..zIndex = '0';
    html.document.body!.append(_iframe);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  void dispose() {
    _iframe.remove();
    super.dispose();
  }
}
