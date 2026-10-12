// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _nextTestViewId = 0;

List<String> controlLabels() {
  final controls =
      html.document.querySelector('[data-mermaid-preview-controls]');
  return controls
          ?.querySelectorAll('button')
          .map((button) => button.getAttribute('aria-label') ?? '')
          .toList() ??
      const [];
}

String? controlTitle() => html.document
    .querySelector('[data-mermaid-preview-controls-title]')
    ?.text;

String controlsSnapshot() =>
    html.document.querySelector('[data-mermaid-preview-controls]')?.outerHtml ??
    '<controls layer not mounted>';

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
  final viewType = 'stroom-test-mermaid-webview-${_nextTestViewId++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
    return html.IFrameElement()
      ..setAttribute('data-mermaid-preview-test-iframe', 'true')
      ..srcdoc = '<!doctype html><html><body></body></html>'
      ..style.width = '100%'
      ..style.height = '100%';
  });
  return HtmlElementView(viewType: viewType);
}
