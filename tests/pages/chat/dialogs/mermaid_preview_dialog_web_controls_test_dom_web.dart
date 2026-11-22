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

void constrainControlsViewportForTest(double width) {
  final root = html.document.querySelector('[data-mermaid-preview-controls]');
  if (root == null) return;
  root.style
    ..width = '${width}px'
    ..right = 'auto';
  html.window.dispatchEvent(html.Event('resize'));
}

bool titleStaysBetweenControls() {
  final root = html.document.querySelector('[data-mermaid-preview-controls]');
  final title = root?.querySelector('[data-mermaid-preview-controls-title]');
  final zoom = root?.querySelector('[data-action="zoom-in"]');
  final close = root?.querySelector('[data-action="close"]');
  if (title == null || zoom == null || close == null) return false;
  final titleRect = title.getBoundingClientRect();
  final zoomRect = zoom.getBoundingClientRect();
  final closeRect = close.getBoundingClientRect();
  return titleRect.left >= zoomRect.right && titleRect.right <= closeRect.left;
}

String? titleMotionState() => html.document
    .querySelector('[data-mermaid-preview-controls-title]')
    ?.getAttribute('data-motion-state');

String? titleTransform() {
  return html.document
      .querySelector('[data-mermaid-preview-controls-title-text]')
      ?.style
      .transform;
}

bool titleLeadingCharacterIsVisible() {
  final title = html.document.querySelector(
    '[data-mermaid-preview-controls-title]',
  );
  final span = html.document.querySelector(
    '[data-mermaid-preview-controls-title-text]',
  );
  final text = span?.firstChild;
  if (title == null || text is! html.Text) return false;
  final range = html.document.createRange()
    ..setStart(text, 0)
    ..setEnd(text, 1);
  final characterRect = range.getBoundingClientRect();
  final titleRect = title.getBoundingClientRect();
  return characterRect.left >= titleRect.left + 12 &&
      characterRect.right <= titleRect.right - 12;
}

double? titleLeadingCharacterCenterX() {
  final span = html.document.querySelector(
    '[data-mermaid-preview-controls-title-text]',
  );
  final text = span?.firstChild;
  if (text is! html.Text) return null;
  final range = html.document.createRange()
    ..setStart(text, 0)
    ..setEnd(text, 1);
  final rect = range.getBoundingClientRect();
  return (rect.left + rect.right) / 2;
}

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
