import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart'
    show htmlPreviewWebViewSettings;
import 'package:stroom/widgets/html_inline_preview_widget.dart';

void main() {
  group('HtmlInlinePreviewWidget document and sandbox', () {
    test('remeasures after body creation and late external resource loads', () {
      final document = HtmlInlinePreviewWidget.buildPreviewDocument(
        '<img src="https://example.test/late.png">',
        token: 'late-resource',
      );
      final frame = html_parser.parse(document).querySelector('iframe')!;
      final preview = html_parser.parse(frame.attributes['srcdoc']!);
      final script = preview.querySelector('[data-stroom-preview-monitor]')!;

      expect(script.text, contains('const observeBody = () =>'));
      expect(script.text, contains('resizeObserver.observe(body)'));
      expect(
        script.text,
        contains("document.addEventListener('load', schedule, true)"),
      );
      expect(script.text, contains('DOMContentLoaded'));
    });

    test('measures natural content instead of the frame viewport', () {
      final document = HtmlInlinePreviewWidget.buildPreviewDocument(
        '<p>Short answer</p>',
        token: 'short-content',
      );
      final frame = html_parser.parse(document).querySelector('iframe')!;
      final preview = html_parser.parse(frame.attributes['srcdoc']!);
      final script = preview.querySelector('[data-stroom-preview-monitor]')!;

      expect(
        script.text,
        contains('const viewportHeight = window.innerHeight'),
      );
      expect(
        script.text,
        contains('rootHeight > viewportHeight ? rootHeight : 0'),
      );
      expect(script.text, contains('Math.max(bodyHeight, rootHeight'));
    });

    testWidgets('open visual fence stays inert while content streams', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HtmlInlinePreviewWidget(
              htmlCode: '<script>window.ran = true</script>',
              isStreaming: true,
            ),
          ),
        ),
      );

      expect(find.byType(InAppWebView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('rechecks the cutoff when the conversation viewport changes', (
      tester,
    ) async {
      final originalPlatform = InAppWebViewPlatform.instance;
      final platform = _PreviewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(
        () => InAppWebViewPlatform.instance =
            originalPlatform ?? _PreviewPlatform(),
      );
      final viewportHeight = ValueNotifier<double?>(600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: SingleChildScrollView(
                child: HtmlInlinePreviewWidget(
                  htmlCode: '<p>tall visual</p>',
                  conversationViewportHeight: viewportHeight,
                ),
              ),
            ),
          ),
        ),
      );

      final webViewParams = platform.webViews.single.params;
      final document = webViewParams.initialData!.data;
      final token =
          RegExp(r'const token = "([^"]+)"').firstMatch(document)!.group(1)!;
      final controller = InAppWebViewController.fromPlatform(
        platform: _PreviewController(),
      );
      webViewParams.onConsoleMessage?.call(
        controller,
        ConsoleMessage(message: 'stroom-html-preview-height:$token:500'),
      );
      await tester.pump();
      expect(find.text('在全屏预览'), findsNothing);

      viewportHeight.value = 400;
      await tester.pump();
      expect(find.text('在全屏预览'), findsOneWidget);

      viewportHeight.value = 600;
      await tester.pump();
      expect(find.text('在全屏预览'), findsNothing);
      viewportHeight.dispose();
    });

    testWidgets('closed preview reloads when its HTML changes in place', (
      tester,
    ) async {
      final originalPlatform = InAppWebViewPlatform.instance;
      final platform = _PreviewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(
        () => InAppWebViewPlatform.instance =
            originalPlatform ?? _PreviewPlatform(),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HtmlInlinePreviewWidget(htmlCode: '<p>first version</p>'),
          ),
        ),
      );
      expect(
        platform.webViews.last.params.initialData?.data,
        contains('first version'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HtmlInlinePreviewWidget(htmlCode: '<p>second version</p>'),
          ),
        ),
      );
      expect(platform.webViews, hasLength(2));
      final updated = platform.webViews.last.params.initialData?.data;
      expect(updated, contains('second version'));
      expect(updated, isNot(contains('first version')));
    });

    test(
      'HTML fragments get a single document and keep inline scripts and URLs',
      () {
        const html = '<main><h1>Visual answer</h1></main>'
            '<script>window.answerRendered = true;</script>'
            '<script src="https://cdn.example.test/view.js"></script>'
            '<img src="https://images.example.test/chart.png">';

        final document = HtmlInlinePreviewWidget.buildPreviewDocument(
          html,
          token: 'test-token',
        );

        final wrapper = html_parser.parse(document);
        final frame = wrapper.querySelector('#stroom-html-preview')!;
        final preview = html_parser.parse(frame.attributes['srcdoc']!);

        expect(frame.attributes['sandbox'], 'allow-scripts');
        expect(
          frame.attributes['srcdoc'],
          contains('window.answerRendered = true'),
        );
        expect(
          frame.attributes['srcdoc'],
          contains('https://cdn.example.test/view.js'),
        );
        expect(
          frame.attributes['srcdoc'],
          contains('https://images.example.test/chart.png'),
        );
        expect(preview.querySelectorAll('body'), hasLength(1));
        expect(preview.body?.text, contains('Visual answer'));
        expect(
          preview.querySelector('[data-stroom-preview-monitor]')?.text,
          contains('parent.postMessage'),
        );
        expect(
          preview.querySelector('[data-stroom-preview-monitor]')?.text,
          contains('event.target instanceof HTMLScriptElement'),
        );
        expect(
          preview.querySelector('[data-stroom-preview-monitor]')?.text,
          contains('const token = "test-token";'),
        );
        expect(
          wrapper.querySelector('body script')?.text,
          contains('event.source !== frame.contentWindow'),
        );
        expect(
          wrapper.querySelector('body script')?.text,
          contains("'stroom-html-preview-height:' + token"),
        );
      },
    );

    test('complete documents keep their existing head and body', () {
      const html = '<!doctype html><html lang="en"><head><title>Example</title>'
          '</head><body><main>Body</main></body></html>';

      final document = HtmlInlinePreviewWidget.buildPreviewDocument(
        html,
        token: 'full-document',
      );

      final wrapper = html_parser.parse(document);
      final preview = html_parser.parse(
        wrapper.querySelector('#stroom-html-preview')!.attributes['srcdoc']!,
      );

      expect(preview.querySelectorAll('head'), hasLength(1));
      expect(preview.querySelectorAll('body'), hasLength(1));
      expect(preview.querySelector('title')?.text, 'Example');
      expect(
        preview.querySelector('[data-stroom-preview-monitor]')?.text,
        contains("'stroom-html-preview-height'"),
      );
      expect(
        preview.querySelector('[data-stroom-preview-monitor]')?.text,
        contains('const token = "full-document";'),
      );
    });

    test('native wrapper validates child window and preview token', () {
      final wrapper = html_parser.parse(
        HtmlInlinePreviewWidget.buildPreviewDocument(
          '<p>safe boundary</p>',
          token: 'boundary-token',
        ),
      );
      final script = wrapper.querySelector('body script')!.text;

      expect(
        wrapper.querySelector('#stroom-html-preview')?.attributes['sandbox'],
        'allow-scripts',
      );
      final bodyNodes = wrapper.querySelector('body')!.nodes;
      expect(
        bodyNodes.indexOf(wrapper.querySelector('#stroom-html-preview')!),
        lessThan(bodyNodes.indexOf(wrapper.querySelector('body script')!)),
      );
      expect(script, contains('event.source !== frame.contentWindow'));
      expect(script, contains('event.data.token !== token'));
      expect(script, contains('const token = "boundary-token";'));
      expect(script, contains('Number.isFinite(event.data.height)'));
      expect(wrapper.querySelector('style')?.text, contains('height:100vh'));
      expect(script, contains('frame.style.height ='));
    });

    test('web iframe allows scripts without same-origin or host bridge', () {
      final settings = HtmlInlinePreviewWidget.inlineWebViewSettings;

      expect(settings.javaScriptEnabled, isTrue);
      expect(settings.javaScriptBridgeEnabled, isFalse);
      expect(settings.allowFileAccess, isFalse);
      expect(settings.allowContentAccess, isFalse);
      expect(settings.allowFileAccessFromFileURLs, isFalse);
      expect(settings.allowUniversalAccessFromFileURLs, isFalse);
      expect(settings.iframeSandbox, contains(Sandbox.ALLOW_SCRIPTS));
      expect(
        settings.iframeSandbox,
        isNot(contains(Sandbox.ALLOW_SAME_ORIGIN)),
      );
    });

    test('fullscreen threshold is the conversation viewport height', () {
      expect(HtmlInlinePreviewWidget.exceedsViewport(400, 400), isFalse);
      expect(HtmlInlinePreviewWidget.exceedsViewport(401, 400), isTrue);
    });

    test(
      'full-screen AI preview keeps scripts/network but denies host access',
      () {
        final settings = htmlPreviewWebViewSettings(sandboxed: true);

        expect(settings.javaScriptEnabled, isTrue);
        expect(settings.javaScriptBridgeEnabled, isFalse);
        expect(settings.allowContentAccess, isFalse);
        expect(settings.allowFileAccess, isFalse);
        expect(settings.allowFileAccessFromFileURLs, isFalse);
        expect(settings.allowUniversalAccessFromFileURLs, isFalse);
        expect(settings.javaScriptCanOpenWindowsAutomatically, isFalse);
        expect(settings.supportMultipleWindows, isFalse);
        expect(settings.useShouldOverrideUrlLoading, isTrue);
      },
    );

    test(
      'ordinary full-screen HTML preview keeps its existing permissions',
      () {
        final settings = htmlPreviewWebViewSettings(sandboxed: false);

        expect(settings.allowContentAccess, isTrue);
        expect(settings.allowFileAccessFromFileURLs, isTrue);
        expect(settings.allowUniversalAccessFromFileURLs, isTrue);
      },
    );
  });
}

class _PreviewPlatform extends InAppWebViewPlatform {
  final List<_PreviewWebView> webViews = [];

  @override
  PlatformInAppWebViewController createPlatformInAppWebViewController(
    PlatformInAppWebViewControllerCreationParams params,
  ) =>
      _PreviewController();

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final webView = _PreviewWebView(params);
    webViews.add(webView);
    return webView;
  }
}

class _PreviewController extends PlatformInAppWebViewController {
  _PreviewController()
      : super.implementation(
          const PlatformInAppWebViewControllerCreationParams(id: 1),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewWebView extends PlatformInAppWebViewWidget {
  _PreviewWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}
