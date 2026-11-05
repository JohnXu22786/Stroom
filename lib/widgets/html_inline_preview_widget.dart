import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';
import 'package:stroom/widgets/html_code_block_widget.dart';

/// Renders the explicit `html-preview` Markdown fence as inline visual content.
///
/// The nested frame runs the author-provided script and can load network
/// resources, but it has no Stroom JavaScript bridge, file access,
/// same-origin access, or top-level navigation. A finished preview taller
/// than the chat viewport is handed to Stroom's existing full-screen Flutter
/// preview.
class HtmlInlinePreviewWidget extends StatefulWidget {
  final String htmlCode;
  final bool isStreaming;

  const HtmlInlinePreviewWidget({
    super.key,
    required this.htmlCode,
    this.isStreaming = false,
  });

  static InAppWebViewSettings get inlineWebViewSettings => InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptBridgeEnabled: false,
        javaScriptCanOpenWindowsAutomatically: false,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        iframeSandbox: {Sandbox.ALLOW_SCRIPTS},
        transparentBackground: true,
        supportMultipleWindows: false,
        useShouldOverrideUrlLoading: true,
      );

  static String buildPreviewDocument(String rawHtml, {required String token}) {
    final base = HtmlCodeBlockWidget.buildHtmlDocument(rawHtml);
    final previewDocument = html_parser.parse(base);
    final monitor = html.Element.tag('script')
      ..attributes['data-stroom-preview-monitor'] = ''
      ..text = _measurementScript(token);
    previewDocument.head?.nodes.insert(0, monitor);

    final wrapper = html_parser.parse('''
<!doctype html>
<html><head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>html,body{height:100%;margin:0;padding:0;width:100%;background:transparent}iframe{display:block;width:100%;height:100vh;border:0}</style>
</head><body><iframe id="stroom-html-preview" sandbox="allow-scripts" title="HTML preview"></iframe><script>${_wrapperMessageScript(token)}</script></body></html>
''');
    wrapper.querySelector('#stroom-html-preview')?.attributes['srcdoc'] =
        previewDocument.outerHtml;
    return wrapper.outerHtml;
  }

  static bool exceedsViewport(double contentHeight, double viewportHeight) =>
      contentHeight > viewportHeight;

  static String _measurementScript(String token) {
    final encodedToken = jsonEncode(token).replaceAll('<', r'\u003c');
    return '''
(() => {
  const token = $encodedToken;
  const report = (height) => parent.postMessage({type: 'stroom-html-preview-height', token, height: Math.ceil(height)}, '*');
  const fail = () => parent.postMessage({type: 'stroom-html-preview-error', token}, '*');
  let queued = false;
  const measure = () => {
    queued = false;
    const root = document.documentElement;
    const body = document.body;
    report(Math.max(root?.scrollHeight || 0, body?.scrollHeight || 0, body?.offsetHeight || 0));
  };
  const schedule = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(measure);
  };
  addEventListener('error', (event) => {
    // External scripts can fail to load without providing `event.error` and
    // their ErrorEvent does not target `window`. Image and stylesheet load
    // failures are ordinary content failures, so only promote script errors.
    if (event.error || event.target === window || event.target instanceof HTMLScriptElement) fail();
  }, true);
  addEventListener('unhandledrejection', fail);
  addEventListener('load', schedule);
  addEventListener('resize', schedule);
  document.addEventListener('load', schedule, true);
  let resizeObserver;
  let resizeObserverBody;
  const observeBody = () => {
    const body = document.body;
    if (!resizeObserver || !body || resizeObserverBody === body) return;
    resizeObserverBody = body;
    resizeObserver.observe(body);
  };
  if (window.ResizeObserver) {
    resizeObserver = new ResizeObserver(schedule);
    resizeObserver.observe(document.documentElement);
    observeBody();
  }
  if (window.MutationObserver) {
    new MutationObserver(schedule).observe(document.documentElement, {
      attributes: true, childList: true, characterData: true, subtree: true
    });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      observeBody();
      schedule();
    }, { once: true });
  } else {
    observeBody();
    schedule();
  }
})();
''';
  }

  static String _wrapperMessageScript(String token) {
    final encodedToken = jsonEncode(token).replaceAll('<', r'\u003c');
    return '''
(() => {
  const token = $encodedToken;
  const frame = document.getElementById('stroom-html-preview');
  addEventListener('message', (event) => {
    if (event.source !== frame.contentWindow || !event.data || event.data.token !== token) return;
    if (event.data.type === 'stroom-html-preview-height' && Number.isFinite(event.data.height)) {
      frame.style.height = Math.max(1, Math.ceil(event.data.height)) + 'px';
      console.info('stroom-html-preview-height:' + token + ':' + Math.ceil(event.data.height));
    } else if (event.data.type === 'stroom-html-preview-error') {
      console.error('stroom-html-preview-error:' + token);
    }
  });
})();
''';
  }

  @override
  State<HtmlInlinePreviewWidget> createState() =>
      _HtmlInlinePreviewWidgetState();
}

class _HtmlInlinePreviewWidgetState extends State<HtmlInlinePreviewWidget> {
  static final RegExp _heightMessage = RegExp(
    r'^stroom-html-preview-height:([^:]+):(\d+)$',
  );
  static final RegExp _errorMessage = RegExp(
    r'^stroom-html-preview-error:([^:]+)$',
  );

  late String _token = _createToken();
  double _contentHeight = 1;
  bool _hasError = false;
  bool _tooTall = false;

  static String _createToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';

  @override
  void didUpdateWidget(covariant HtmlInlinePreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlCode == widget.htmlCode) return;
    _token = _createToken();
    _contentHeight = 1;
    _hasError = false;
    _tooTall = false;
  }

  void _handleConsoleMessage(ConsoleMessage message) {
    final text = message.message.trim();
    if (_errorMessage.firstMatch(text)?.group(1) == _token) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    final match = _heightMessage.firstMatch(text);
    if (match?.group(1) != _token) return;
    final contentHeight = double.tryParse(match!.group(2)!);
    if (contentHeight == null ||
        contentHeight.isNaN ||
        contentHeight.isInfinite) {
      return;
    }
    final scrollable = Scrollable.maybeOf(context);
    final viewportHeight = scrollable?.position.viewportDimension ??
        MediaQuery.sizeOf(context).height;
    final tooTall = HtmlInlinePreviewWidget.exceedsViewport(
      contentHeight,
      viewportHeight,
    );
    if (mounted) {
      setState(() {
        _contentHeight = math.max(1, contentHeight);
        _tooTall = tooTall;
      });
    }
  }

  void _openFullScreen() {
    showHtmlPreviewDialog(context: context, htmlCode: widget.htmlCode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isStreaming) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_hasError) {
      return CodeBlockSourceView(
        code: widget.htmlCode,
        language: 'html',
      );
    }
    if (_tooTall) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _openFullScreen,
          icon: const Icon(Icons.open_in_full),
          label: const Text('在全屏预览'),
        ),
      );
    }
    final scrollable = Scrollable.maybeOf(context);
    final viewportHeight = scrollable?.position.viewportDimension ??
        MediaQuery.sizeOf(context).height;
    return SizedBox(
      width: double.infinity,
      height: math.min(_contentHeight, viewportHeight),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: viewportHeight,
          maxHeight: viewportHeight,
          child: SizedBox(
            width: double.infinity,
            height: viewportHeight,
            child: InAppWebView(
              key: ValueKey(_token),
              initialSettings: HtmlInlinePreviewWidget.inlineWebViewSettings,
              initialData: InAppWebViewInitialData(
                data: HtmlInlinePreviewWidget.buildPreviewDocument(
                  widget.htmlCode,
                  token: _token,
                ),
                mimeType: 'text/html',
                encoding: 'utf8',
              ),
              onConsoleMessage: (controller, message) =>
                  _handleConsoleMessage(message),
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true && mounted) {
                  setState(() => _hasError = true);
                }
              },
              shouldOverrideUrlLoading: (controller, action) async =>
                  NavigationActionPolicy.CANCEL,
            ),
          ),
        ),
      ),
    );
  }
}
