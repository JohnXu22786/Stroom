import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show
        defaultTargetPlatform,
        debugDefaultTargetPlatformOverride,
        kIsWeb,
        TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, LogicalKeyboardKey, rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/mermaid_web_url.dart';
import 'package:stroom/utils/mermaid_web_url_stub.dart'
    if (dart.library.html) 'package:stroom/utils/mermaid_web_url_web.dart'
    as platform;
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MermaidRenderWidget - web overlay pointer routing', () {
    testWidgets(
      'inline toolbar intercepts the iframe without blocking diagram gestures',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(
                mermaidCode: 'graph TD\nA-->B',
                showToolbar: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller =
            webView.controllerFromPlatform<InAppWebViewController>(
          webView.controller,
        );
        webView.params.onWebViewCreated!(controller);
        await tester.pump();
        webView.params.onLoadStop?.call(
          controller,
          webView.controller.loadedUrls.last,
        );
        await tester.pump();

        final zoomCenter = tester.getCenter(find.byIcon(Icons.zoom_in));
        final interceptor = find.byType(PointerInterceptor);
        expect(interceptor, findsOneWidget);
        final interceptorRect = tester.getRect(interceptor);
        expect(interceptorRect.contains(zoomCenter), isTrue);

        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
        expect(
          webView.controller.evaluatedScripts,
          contains('window.applyZoomDeltasAfterFit([0.1])'),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(
                mermaidCode: 'graph TD\nA-->B',
                showToolbar: false,
                showZoomControls: true,
              ),
            ),
          ),
        );
        await tester.pump();

        final standaloneZoom = find.byType(PointerInterceptor);
        expect(standaloneZoom, findsOneWidget);
        final standaloneZoomRect = tester.getRect(standaloneZoom);
        final standaloneZoomCenter =
            tester.getCenter(find.byIcon(Icons.zoom_in));
        expect(standaloneZoomRect.contains(standaloneZoomCenter), isTrue);

        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
        expect(
          webView.controller.evaluatedScripts.where(
            (script) => script == 'window.applyZoomDeltasAfterFit([0.1])',
          ),
          hasLength(2),
        );

        final diagramCenter =
            tester.getCenter(find.byType(MermaidRenderWidget));
        expect(standaloneZoomRect.contains(diagramCenter), isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets('error retry overlay intercepts the iframe and retries',
        (tester) async {
      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _MermaidWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() => InAppWebViewPlatform.instance =
          previousPlatform ?? _MermaidWebViewPlatform());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final webView = platform.webView!;
      final controller = webView.controllerFromPlatform<InAppWebViewController>(
        webView.controller,
      );
      webView.params.onWebViewCreated!(controller);
      await tester.pump();
      webView.params.onReceivedError!(
        controller,
        WebResourceRequest(
          url: WebUri(
            MermaidRenderWidget.buildWebAssetUrl('graph TD\nA-->B'),
          ),
          isForMainFrame: true,
        ),
        WebResourceError(
          type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
          description: 'Could not connect to host',
        ),
      );
      await tester.pump();

      final retry = find.text('重试');
      expect(retry, findsOneWidget);
      final retryCenter = tester.getCenter(retry);
      final interceptor = find.byType(PointerInterceptor);
      expect(interceptor, findsOneWidget);
      final interceptorRect = tester.getRect(interceptor);
      expect(interceptorRect.contains(retryCenter), isTrue);
      expect(
        interceptorRect.contains(
          tester.getCenter(find.byType(MermaidRenderWidget)),
        ),
        isTrue,
      );

      final loadCount = webView.controller.loadedUrls.length;
      await tester.tap(retry);
      await tester.pump();
      expect(webView.controller.loadedUrls.length, greaterThan(loadCount));
      await tester.pumpWidget(const SizedBox.shrink());
    }, skip: !kIsWeb);
  });

  group('MermaidRenderWidget - bundled JavaScript loading', () {
    test(
      'failed asset reads retry while concurrent callers share the load',
      () async {
        final assetBytes = await rootBundle.load(
          MermaidRenderWidget.bundledMermaidJsAsset,
        );
        final successfulAssetLoad = Completer<ByteData>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var assetLoadCount = 0;
        messenger.setMockMessageHandler('flutter/assets', (message) async {
          final assetKey = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          if (assetKey != MermaidRenderWidget.bundledMermaidJsAsset) {
            return null;
          }
          assetLoadCount++;
          if (assetLoadCount == 1) {
            return null;
          }
          return successfulAssetLoad.future;
        });
        addTearDown(() {
          messenger.setMockMessageHandler('flutter/assets', null);
        });

        expect(await MermaidRenderWidget.loadBundledMermaidJs(), isNull);
        expect(assetLoadCount, 1);

        final firstLoad = MermaidRenderWidget.loadBundledMermaidJs();
        final secondLoad = MermaidRenderWidget.loadBundledMermaidJs();
        await Future<void>.delayed(Duration.zero);
        successfulAssetLoad.complete(assetBytes);

        final loadedSources = await Future.wait([firstLoad, secondLoad]);
        expect(loadedSources, hasLength(2));
        expect(loadedSources.first, isNotNull);
        expect(
          identical(loadedSources.last, loadedSources.first),
          isTrue,
          reason: 'concurrent callers should receive the shared loaded source',
        );
        expect(assetLoadCount, 2);

        expect(
          await MermaidRenderWidget.loadBundledMermaidJs(),
          loadedSources.first,
        );
        expect(
          assetLoadCount,
          2,
          reason: 'successful results should stay cached',
        );
      },
    );
  });

  group('MermaidRenderWidget - buildMermaidHtml', () {
    test('replaces MERMAID_CODE_PLACEHOLDER with escaped code', () {
      final code = 'graph TD\nA-->B';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('graph TD'));
      // '-->' gets HTML-escaped to '--&gt;'
      expect(html, contains('A--&gt;B'));
      expect(html, isNot(contains('MERMAID_CODE_PLACEHOLDER')));
    });

    test('escapes HTML special characters in code', () {
      final code = '<test> & "quote"';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('&lt;test&gt;'));
      expect(html, contains('&amp;'));
    });

    test('includes mermaid.js script reference', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid@11'));
      expect(html, contains('mermaid.min.js'));
    });

    test('loads mermaid.js dynamically so the CDN cannot block the load event',
        () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Regression: a static <script src="https://cdn.jsdelivr.net/..."> in
      // <head> delays the document load event until the CDN responds. On a
      // slow or unreachable network the WebView's onLoadStop never fires,
      // so the Flutter-side loading overlay spun forever. The script must
      // be injected dynamically so the page finishes loading immediately.
      expect(html, isNot(contains('<script src="https://cdn.jsdelivr.net')));
      expect(html, contains("document.createElement('script')"));
      expect(
          html,
          contains(
              "script.src = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js'"));
    });

    test('shows a visible error when the mermaid CDN fails or times out', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // A dead or hanging CDN must not leave the diagram area spinning:
      // script.onerror and a load timeout both surface a visible error.
      expect(html, contains('script.onerror'));
      expect(html, contains('无法访问 cdn.jsdelivr.net'));
      expect(html, contains('Mermaid 加载超时'));
    });

    test('inlines the bundled mermaid.js when inlineMermaidJs is provided', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: 'var bundled = 1;');
      // The library must be embedded in the page itself — no CDN request.
      expect(html, contains('var bundled = 1;'));
      expect(html, isNot(contains("script.src = 'https://cdn.jsdelivr.net")));
    });
    test('escapes < in the inlined library so the script tag stays intact', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: 'var s = "</script><!--";');
      // Every '<' is emitted as \u003C inside the JS string literal, so the
      // HTML parser never sees a raw '</script' or '<!--' from the library
      // code that could terminate the script tag early.
      expect(html, contains(r'\u003C/script>'));
      expect(html, contains(r'\u003C!--'));
    });

    test('web asset URL uses the Flutter base href and keeps one query string',
        () {
      // Regression: the URL previously became "...?v=4?code=..." (two '?'),
      // so URLSearchParams could not find the code and the template showed
      // the empty-code placeholder instead of the diagram.
      final url = MermaidRenderWidget.buildWebAssetUrl('graph TD\nA-->B');
      expect(url, contains('mermaid_render.html?v=9&code='));
      expect(url, isNot(contains('?code')));
      expect(url, isNot(contains('v=9?')));
      // The code must be percent-encoded inside the query string.
      expect(url, contains('graph+TD'));
      expect(Uri.parse(url).queryParameters, {
        'v': '9',
        'code': 'graph TD\nA-->B',
      });

      final rootUrl = Uri.parse(
        resolveMermaidWebUrl(
          url,
          baseUri: Uri.parse('https://example.test/'),
        ),
      );
      expect(rootUrl.path, '/assets/assets/vendor/mermaid_render.html');

      final subpathUrl = Uri.parse(
        resolveMermaidWebUrl(
          url,
          baseUri: Uri.parse('https://example.test/stroom/'),
        ),
      );
      expect(
        subpathUrl.path,
        '/stroom/assets/assets/vendor/mermaid_render.html',
      );
      // Empty code -> version parameter only, no dangling '&'.
      final empty = MermaidRenderWidget.buildWebAssetUrl('   ');
      expect(empty, '${MermaidRenderWidget.webAssetTemplateUrl}?v=9');
    });

    test('uses the platform base URI when resolving without an override', () {
      const url = 'assets/assets/vendor/mermaid_render.html?v=9';
      final platformBaseUri = platform.mermaidWebBaseUri;

      expect(
        resolveMermaidWebUrl(url),
        platformBaseUri.resolve(url).toString(),
      );
    });

    // ---- Inline loader caching (perf: the ~3.5MB bundled library must be
    // JSON-encoded exactly once, not once per render / per widget rebuild) ----

    test(
        'reuses the encoded inline loader for repeated renders of the same '
        'library', () {
      const lib = 'var cachedLibAAA = 1;';
      final before = MermaidRenderWidget.inlineLoaderBuildCount;
      final html1 = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: lib);
      final html2 = MermaidRenderWidget.buildMermaidHtml('graph TD\nA-->B',
          inlineMermaidJs: lib);
      // Both diagrams embed the library, and the expensive encode step ran
      // exactly once across the two renders (not once per diagram).
      expect(html1, contains('var cachedLibAAA = 1;'));
      expect(html2, contains('var cachedLibAAA = 1;'));
      expect(MermaidRenderWidget.inlineLoaderBuildCount, before + 1);
    });

    test('does not reuse the cached inline loader across different libraries',
        () {
      const libA = 'var libAAA = 1;';
      const libB = 'var libBBB = 1;';
      final before = MermaidRenderWidget.inlineLoaderBuildCount;
      final htmlA = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: libA);
      final htmlB = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: libB);
      final htmlA2 = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: libA);
      expect(htmlA, contains('var libAAA = 1;'));
      expect(htmlA, isNot(contains('var libBBB = 1;')));
      expect(htmlB, contains('var libBBB = 1;'));
      expect(htmlB, isNot(contains('var libAAA = 1;')));
      expect(htmlA2, contains('var libAAA = 1;'));
      expect(htmlA2, isNot(contains('var libBBB = 1;')));
      // The cache holds one library; every DIFFERENT library in a sequence
      // re-encodes (production only ever sees the single bundled library).
      // The point is zero cross-contamination between libraries.
      expect(MermaidRenderWidget.inlineLoaderBuildCount, before + 3);
    });

    test('falls back to the CDN loader after an inline render', () {
      const lib = 'var libAAA = 1;';
      MermaidRenderWidget.buildMermaidHtml('graph TD', inlineMermaidJs: lib);
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(
          html,
          contains(
              "script.src = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js'"));
      expect(html, isNot(contains('var libAAA = 1;')));
    });

    test('skeleton cache keeps withJsGestures independent of the loader cache',
        () {
      const lib = 'var libAAA = 1;';
      final withGestures = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: lib);
      final withoutGestures = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: lib, withJsGestures: false);
      final withGesturesAgain = MermaidRenderWidget.buildMermaidHtml('graph TD',
          inlineMermaidJs: lib);
      expect(withGestures, contains('mousedown'));
      expect(withoutGestures, isNot(contains('mousedown')));
      expect(withGesturesAgain, contains('mousedown'));
      expect(withoutGestures, contains('var libAAA = 1;'));
    });

    test('includes mermaid.initialize call', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.initialize'));
    });

    test('uses mermaid.run() for v11 API compatibility', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.run'));
    });

    test('handles empty code', () {
      final html = MermaidRenderWidget.buildMermaidHtml('');
      expect(html, isNot(contains('MERMAID_CODE_PLACEHOLDER')));
    });

    test('handles code with newlines and special chars', () {
      final code = 'sequenceDiagram\nAlice->>Bob: Hello\nBob-->>Alice: Hi';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('sequenceDiagram'));
      expect(html, contains('Alice-&gt;&gt;Bob'));
      expect(html, contains('Bob--&gt;&gt;Alice'));
    });

    test('HTML uses loose securityLevel for mermaid', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains("securityLevel: 'loose'"));
    });

    test('HTML includes error container for rendering failures', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('error-message'));
    });

    test('HTML includes Flutter error handler call for mermaid errors', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('flutter_inappwebview'));
      expect(html, contains('callHandler'));
      expect(html, contains('onMermaidError'));
    });

    test('HTML reports initialize and render errors to Flutter', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('onMermaidError'));
      // Verify both error paths exist: mermaid.initialize() and mermaid.run().catch
      expect(html, contains('mermaid.initialize'));
      expect(html, contains('mermaid.run'));
      expect(html, contains('.catch'));
    });

    // ---- Pan/zoom support ----

    test('HTML sets overflow: hidden on body for viewport behavior', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('overflow: hidden'));
    });

    test('HTML has viewport container div', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('id="viewport"'));
    });

    test('HTML has diagram-container div with transform-origin 0 0', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('id="diagram-container"'));
      expect(html, contains('transform-origin: 0 0'));
    });

    test('HTML includes window.setZoom function', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.setZoom'));
    });

    test('HTML setZoom reports transform changes via onTransformChanged', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('onTransformChanged'));
    });

    test('HTML queues native gesture transforms until after the first fit', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(
        html,
        contains(
          'window.applyGestureTransformAfterFit = function(gestureId, scale, panDeltaX, panDeltaY, centerX, centerY)',
        ),
      );
    });

    test('HTML includes fitToViewport for auto-fit after render', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.fitToViewport'));
    });

    test('fitToViewport is called after mermaid.run completes', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // The fit must be wired into the mermaid.run success path.
      final runIdx = html.indexOf('mermaid.run');
      final fitCallIdx = html.indexOf('window.fitToViewport();', runIdx);
      expect(runIdx, greaterThanOrEqualTo(0));
      expect(fitCallIdx, greaterThan(runIdx),
          reason: 'fitToViewport() must be invoked after mermaid.run finishes');
    });

    test('fitToViewport notifies Flutter of the fitted viewport', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // The fit reports zoom AND pan so the Flutter side can keep its
      // gesture/button state in sync (no post-fit position jumps).
      expect(html, contains('onTransformChanged'));
      expect(html, contains('callHandler'));
    });

    test('JS gesture pan handlers report transform changes to Flutter', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Regression: when the JS gesture handlers (mobile fallback, where
      // the platform view receives events directly) pan the diagram, they
      // must notify Flutter so the Flutter-side pan state does not go
      // stale and snap back on the next gesture/button interaction.
      // Mouse drag pan and touch pan must both report.
      expect(html, contains('panX = panStartX + (e.clientX - dragStartX)'));
      expect(html, contains('panX = touchPanStartX'));
      // Exactly one notify per mutation path: setZoom, fitToViewport,
      // native pan/pinch, mouse-drag pan, touch pan. This pins the notify
      // calls to the transform handlers (not just to zoom and fit paths).
      expect('notifyTransform();'.allMatches(html).length, 5);
    });

    test('fitToViewport uses contain-fit (min ratio) and centers the diagram',
        () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Contain fit: zoom = min(vw/sw, vh/sh) — full diagram visible at the
      // maximum zoom (not cover-fill).
      expect(html, contains('Math.min(vw / sw, vh / sh)'));
      // Centered: pan places the diagram in the middle of the viewport.
      expect(html, contains('panX = (vw - sw * zoomLevel) / 2'));
      expect(html, contains('panY = (vh - sh * zoomLevel) / 2'));
    });

    test('fitToViewport reads the diagram size from the rendered SVG', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains("container.querySelector('svg')"));
      // 'svg.getBBox()' (with the svg. prefix) anchors the CODE call only —
      // the fit comment in the template also mentions getBBox(), so the bare
      // word would match the comment instead of the code.
      expect(html, contains('svg.getBBox()'));
    });

    test('fitToViewport pins the SVG to its natural size before fitting', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Regression: mermaid v11 renders <svg width="100%"> with only a
      // max-width style and NO width/height attributes, so without explicit
      // pixel size the SVG stretches to the container width while getBBox()
      // still reports the natural content size. The fit math would then
      // double-scale the diagram (shrunk AND misplaced). fitToViewport must
      // pin the SVG to its measured content size before computing the fit.
      expect(html, contains("svg.setAttribute('width', sw)"));
      expect(html, contains("svg.setAttribute('height', sh)"));
      // Order must be: measure (getBBox) -> pin -> fit math. The pin must
      // use the MEASURED size (pinning before measuring would pin 0), and
      // must happen before the zoom/pan math that consumes sw/sh.
      // 'svg.getBBox()' anchors the code call only (the template comment
      // also mentions getBBox without the svg. prefix).
      final measureIdx = html.indexOf('svg.getBBox()');
      final pinIdx = html.indexOf("svg.setAttribute('height', sh)");
      final zoomIdx = html.indexOf('Math.min(vw / sw, vh / sh)');
      expect(measureIdx, greaterThanOrEqualTo(0));
      expect(pinIdx, greaterThan(measureIdx),
          reason: 'SVG size must be measured before it is pinned');
      expect(zoomIdx, greaterThan(pinIdx),
          reason: 'SVG size must be pinned before the fit math reads sw/sh');
    });

    test('HTML includes updateTransform function', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('updateTransform'));
    });

    test('HTML has mouse drag-to-pan handlers (mousedown/mousemove/mouseup)',
        () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mousedown'));
      expect(html, contains('mousemove'));
      expect(html, contains('mouseup'));
    });

    test('HTML has wheel zoom handler with Ctrl/Cmd key modifier', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains("document.addEventListener('wheel'"));
      expect(html, contains('ctrlKey'));
      expect(html, contains('metaKey'),
          reason:
              'metaKey (Cmd on macOS) must be supported for cross-platform zoom');
    });

    test('HTML constrains zoom between 0.1 and 10', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('Math.max(0.1'));
      expect(html, contains('Math.min(10'));
    });

    test('HTML SVG uses max-width:none for full-size rendering', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('.mermaid svg'));
      expect(html, contains('max-width: none'));
      expect(html, contains('max-height: none'));
    });

    // ---- Zoom center fix tests ----

    test('setZoom accepts optional centerX and centerY parameters', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Should declare setZoom with centerX and centerY parameters
      expect(
          html, contains('window.setZoom = function(level, centerX, centerY)'),
          reason: 'setZoom must accept centerX and centerY parameters');
    });

    test('setZoom adjusts pan when centerX/centerY provided', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Should calculate new pan to keep center point fixed
      expect(html, contains('panX'),
          reason: 'setZoom should adjust panX when center is provided');
      expect(html, contains('panY'),
          reason: 'setZoom should adjust panY when center is provided');
    });

    test('wheel handler passes cursor position relative to viewport', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // The wheel handler should get the viewport rect and compute
      // cursor position relative to it for zoom centering
      expect(html, contains('getBoundingClientRect'),
          reason: 'wheel handler should get viewport bounding rect');
      expect(html, contains('centerX'),
          reason: 'wheel handler should compute centerX');
      expect(html, contains('centerY'),
          reason: 'wheel handler should compute centerY');
    });

    test('touch pinch handler passes midpoint to setZoom', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // The pinch handler should compute the midpoint of two touches
      expect(html, contains('clientX'),
          reason: 'touch handler should access touch clientX');
      // Should compute midpoint and pass it to setZoom
      expect(
          html, contains('(e.touches[0].clientX + e.touches[1].clientX) / 2'),
          reason: 'touch handler should compute midpoint X');
      expect(
          html, contains('(e.touches[0].clientY + e.touches[1].clientY) / 2'),
          reason: 'touch handler should compute midpoint Y');
      // Should pass centerX/centerY to setZoom
      expect(html, contains('setZoom(zoomLevel * scale, centerX, centerY)'),
          reason: 'touch handler should pass center to setZoom');
    });

    // ---- Zoom position jumping fix ----

    test('touchend checks e.touches.length for pinch-to-pan transition', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // After a multi-touch gesture, if one finger remains, the handler
      // should update pan start state to prevent position jumping.
      expect(html, contains('e.touches.length === 1'),
          reason: 'touchend should check if a finger remains for pinch-to-pan');
      expect(html, contains('touchPanStartX'),
          reason: 'touchend should update pan start X for remaining finger');
      expect(html, contains('touchPanStartY'),
          reason: 'touchend should update pan start Y for remaining finger');
    });

    // ---- withJsGestures parameter ----

    test('buildMermaidHtml default includes JS gesture handlers', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mousedown'),
          reason: 'default should include mouse drag handlers');
      expect(html, contains("document.addEventListener('wheel'"),
          reason: 'default should include wheel zoom handler');
      expect(html, contains('touchstart'),
          reason: 'default should include touch handlers');
    });

    test(
        'buildMermaidHtml with withJsGestures: false omits JS gesture handlers',
        () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: false);
      expect(html, isNot(contains('mousedown')),
          reason: 'should omit mouse drag handlers');
      expect(html, isNot(contains("document.addEventListener('wheel'")),
          reason: 'should omit wheel zoom handler');
      expect(html, isNot(contains('touchstart')),
          reason: 'should omit touch handlers');
      // Core mermaid rendering should still be present
      expect(html, contains('mermaid.initialize'));
      expect(html, contains('mermaid.run'));
      expect(
        html,
        contains(
          'window.applyWheelZoomAfterFit = function(delta, centerX, centerY)',
        ),
        reason:
            'native programmatic wheel zoom support should remain available',
      );
      expect(html, contains('window.applyZoomOperationsAfterFit = function'),
          reason: 'native buffered zoom operations should remain available');
      expect(html, isNot(contains('MERMAID_CODE_PLACEHOLDER')),
          reason: 'code placeholder should be replaced');
    });
  });

  group('MermaidRenderWidget - web asset template', () {
    // The web platform loads the bundled asset template via loadUrl (a
    // data: URL cannot carry the bundled mermaid.js — Chromium truncates
    // data: URLs at ~1MB). These tests pin the template's contract so it
    // does not silently drift from the Dart template.
    Future<String> loadAssetTemplate() =>
        rootBundle.loadString('assets/vendor/mermaid_render.html');

    test('loads mermaid.min.js from the same asset directory (no CDN)',
        () async {
      final html = await loadAssetTemplate();
      // The library ships gzip-compressed (dev-server transfer stays
      // fast); it is fetched from the same asset directory, decompressed
      // in the browser, and falls back to the raw file if needed.
      expect(html, contains("fetch('mermaid.min.js.gz')"));
      expect(html, contains("DecompressionStream('gzip')"));
      expect(html, contains("runScriptUrl('mermaid.min.js')"));
      expect(html, isNot(contains('cdn.jsdelivr.net')));
    });

    test('reads the diagram code from the ?code= query parameter', () async {
      final html = await loadAssetTemplate();
      expect(html, contains('URLSearchParams'));
      expect(html, contains("params.get('code')"));
    });

    test('caches the decompressed library in CacheStorage for repeat renders',
        () async {
      final html = await loadAssetTemplate();
      // Every diagram opens a fresh iframe document; without a persistent
      // cache each one would re-download the gz and re-decompress the
      // library, so the renderer caches the decompressed blob per version.
      expect(html, contains('caches.open'));
      expect(html, contains('cache.match'));
      // The cache key must be versioned: a stale key would keep serving
      // the previous library after an update. TEMPLATE_VERSION must stay
      // in sync with the ?v= in buildWebAssetUrl.
      final templateVersion =
          RegExp(r"TEMPLATE_VERSION = '(v\d+)'").firstMatch(html)?.group(1);
      expect(templateVersion, 'v9');
      final urlVersion = templateVersion!.substring(1);
      final populatedUrl = MermaidRenderWidget.buildWebAssetUrl('graph TD');
      final emptyUrl = MermaidRenderWidget.buildWebAssetUrl('  ');
      expect(populatedUrl, contains('mermaid_render.html?v=$urlVersion&code='));
      expect(
        emptyUrl,
        '${MermaidRenderWidget.webAssetTemplateUrl}?v=$urlVersion',
      );
    });

    test(
        'keeps the shared fit/gesture behavior in sync with the Dart '
        'template', () async {
      final html = await loadAssetTemplate();
      // fitToViewport with the SVG natural-size pinning (auto center+fit).
      expect(html, contains('window.fitToViewport'));
      expect(html, contains("svg.setAttribute('width', sw)"));
      expect(html, contains("svg.setAttribute('height', sh)"));
      // Mouse + touch pan/zoom gesture handlers.
      expect(html, contains("document.addEventListener('mousedown'"));
      expect(html, contains("document.addEventListener('touchstart'"));
      // Error reporting surface.
      expect(html, contains('reportError'));
    });
  });

  group('MermaidRenderWidget - widget rendering', () {
    testWidgets('zoom tapped while loading is applied after WebView readiness',
        (tester) async {
      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _MermaidWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() => InAppWebViewPlatform.instance =
          previousPlatform ?? _MermaidWebViewPlatform());

      await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(
              mermaidCode: 'graph TD\nA-->B',
              showZoomControls: true,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final webView = platform.webView!;
      final controller = webView.controllerFromPlatform<InAppWebViewController>(
        webView.controller,
      );
      final fakeController = webView.controller;

      // The control is visible while loading, but its WebView controller has
      // not reported creation yet.
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(
        fakeController.evaluatedScripts,
        isEmpty,
        reason: 'horizontal-only Ctrl+wheel should not send a zoom command',
      );

      webView.params.onWebViewCreated!(controller);
      await tester.pump();
      expect(fakeController.evaluatedScripts, isEmpty);

      // Web sets its overlay-ready state on controller creation, before the
      // page has necessarily loaded the zoom helper.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(fakeController.evaluatedScripts, isEmpty);

      // Until onLoadStop, the page has not reported that its JavaScript zoom
      // helper is available.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(fakeController.evaluatedScripts, isEmpty);

      webView.params.onLoadStop?.call(
        controller,
        webView.params.initialData?.baseUrl,
      );
      await tester.pump();

      expect(fakeController.zoomLevel, 1.0);
      expect(
        fakeController.evaluatedScripts,
        contains(predicate<String>((script) =>
            script.contains('window.applyZoomDeltasAfterFit([0.1,0.1,0.1])'))),
      );

      // Load completion can precede Mermaid's asynchronous render and fit.
      // A tap in that interval must be retained too.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(
        fakeController.evaluatedScripts,
        contains(predicate<String>((script) =>
            script.contains('window.applyZoomDeltasAfterFit([0.1])'))),
      );

      // Mermaid's auto-fit runs after the WebView load callback, so the
      // queued taps must apply on top of that fitted zoom rather than precede it.
      fakeController.simulateJsFitToViewport(0.8);
      expect(fakeController.zoomLevel, closeTo(1.2, 0.0001));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'queued toolbar zoom is applied by native readiness fallback without onLoadStop',
        (tester) async {
      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _MermaidWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() => InAppWebViewPlatform.instance =
          previousPlatform ?? _MermaidWebViewPlatform());

      await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(
              mermaidCode: 'graph TD\nA-->B',
              showZoomControls: true,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final webView = platform.webView!;
      final controller = webView.controllerFromPlatform<InAppWebViewController>(
        webView.controller,
      );
      final fakeController = webView.controller;

      // The toolbar is visible while loading, before its native controller is
      // created, so this tap is queued in Flutter.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(fakeController.evaluatedScripts, isEmpty);

      webView.params.onWebViewCreated!(controller);
      await tester.pump();

      // Let the native fallback expose the preview without delivering the
      // WebView's onLoadStop callback.
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('加载渲染引擎...'), findsNothing);
      expect(
        fakeController.evaluatedScripts,
        contains(predicate<String>((script) =>
            script.contains('window.applyZoomDeltasAfterFit([0.1])'))),
      );

      // Once the fallback exposes the preview, later taps must also reach
      // the page even though onLoadStop never arrives.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(
        fakeController.evaluatedScripts
            .where((script) =>
                script.contains('window.applyZoomDeltasAfterFit([0.1])'))
            .length,
        2,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'toolbar zoom continues from the JS-fitted zoom without a transform handler',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _MermaidWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() => InAppWebViewPlatform.instance =
          previousPlatform ?? _MermaidWebViewPlatform());

      await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final webView = platform.webView!;
      final controller = webView.controllerFromPlatform<InAppWebViewController>(
        webView.controller,
      );
      webView.params.onWebViewCreated!(controller);
      webView.params.onLoadStop?.call(
        controller,
        webView.params.initialData?.baseUrl,
      );
      await tester.pump();

      // The web template's fitToViewport changes zoom in JavaScript. The
      // unavailable addJavaScriptHandler leaves Flutter's zoom at 1.0.
      webView.controller.simulateJsFitToViewport(0.45);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      expect(webView.controller.zoomLevel, closeTo(0.55, 0.0001));
      expect(html, contains('var zoomLevel = 1;'));
      expect(
        webView.controller.evaluatedScripts,
        contains(predicate<String>((script) =>
            script.contains('window.applyZoomDeltasAfterFit([0.1])'))),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'Ctrl+wheel zoom before fit survives auto-fit and does not scroll parent',
        (tester) async {
      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _MermaidWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() => InAppWebViewPlatform.instance =
          previousPlatform ?? _MermaidWebViewPlatform());

      await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  const MermaidRenderWidget(
                    mermaidCode: 'graph TD\nA-->B',
                    height: 200,
                    showToolbar: false,
                    showZoomControls: true,
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );

      // Let the widget's asset-load continuation run outside fake test time.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      final webView = platform.webView!;
      final fakeController = webView.controller;
      final controller = webView.controllerFromPlatform<InAppWebViewController>(
        fakeController,
      );
      webView.params.onWebViewCreated!(controller);
      await tester.pump();

      final widgetRect = tester.getRect(find.byType(MermaidRenderWidget));
      fakeController.viewportSize = widgetRect.size;
      final localWheelCenters = [
        Offset(widgetRect.width * 0.25, widgetRect.height * 0.25),
        Offset(widgetRect.width * 0.75, widgetRect.height * 0.75),
      ];

      Future<void> sendWheel(Offset position, Offset scrollDelta) async {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            kind: PointerDeviceKind.mouse,
            scrollDelta: scrollDelta,
          ),
        );
        await tester.pump();
      }

      // Load completion removes Flutter's loading overlay, while Mermaid's
      // asynchronous render and first fit are still pending.
      webView.params.onLoadStop?.call(
        controller,
        webView.params.initialData?.baseUrl,
      );
      await tester.pump();

      // The toolbar and wheel inputs reach the page before its first fit.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      expect(
        HardwareKeyboard.instance.logicalKeysPressed,
        contains(LogicalKeyboardKey.controlLeft),
      );
      await sendWheel(widgetRect.center, const Offset(20, 0));

      expect(
        fakeController.evaluatedScripts,
        ['window.applyZoomDeltasAfterFit([0.1])'],
        reason: 'horizontal-only Ctrl+wheel should not issue another zoom',
      );

      for (final localCenter in localWheelCenters) {
        await sendWheel(widgetRect.topLeft + localCenter, const Offset(0, -20));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(
        fakeController.evaluatedScripts,
        hasLength(3),
        reason: 'the toolbar and both vertical wheel inputs should be captured',
      );
      expect(
        fakeController.zoomLevel,
        1.0,
        reason: 'pre-fit wheel input must not mutate the unfit zoom state',
      );

      final expectedCommands = <String>[
        'window.applyZoomDeltasAfterFit([0.1])',
        for (final center in localWheelCenters)
          'window.applyWheelZoomAfterFit(0.1, ${center.dx}, ${center.dy});',
      ];
      expect(
        fakeController.evaluatedScripts,
        expectedCommands,
        reason:
            'both vertical wheel events should queue in order with their anchors',
      );

      fakeController.simulateJsFitToViewport(0.8);
      expect(
        fakeController.zoomLevel,
        closeTo(1.1, 0.0001),
        reason:
            'toolbar and wheel steps should apply on top of the fitted zoom',
      );
      expect(
        fakeController.wheelZoomAnchors,
        localWheelCenters,
        reason:
            'queued wheel zooms must preserve their individual cursor anchors',
      );
      double anchor(
        double pan,
        double center,
        double oldZoom,
        double newZoom,
      ) =>
          center - (center - pan) * (newZoom / oldZoom);
      var expectedPanX = anchor(0, widgetRect.width / 2, 0.8, 0.9);
      var expectedPanY = anchor(0, widgetRect.height / 2, 0.8, 0.9);
      expectedPanX = anchor(expectedPanX, localWheelCenters[0].dx, 0.9, 1.0);
      expectedPanY = anchor(expectedPanY, localWheelCenters[0].dy, 0.9, 1.0);
      expectedPanX = anchor(expectedPanX, localWheelCenters[1].dx, 1.0, 1.1);
      expectedPanY = anchor(expectedPanY, localWheelCenters[1].dy, 1.0, 1.1);
      expect(fakeController.panX, closeTo(expectedPanX, 0.0001));
      expect(fakeController.panY, closeTo(expectedPanY, 0.0001));
      expect(
        scrollController.offset,
        closeTo(0, 0.1),
        reason: 'the same Ctrl+wheel event must not scroll the parent',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      scrollController.dispose();
    });

    testWidgets(
      'native pan and pinch before first fit survive auto-fit',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(
            mermaidCode: 'graph TD\nA-->B',
            height: 200,
            showToolbar: false,
          ),
        );
        final fakeController = webView.controller;
        final widgetRect = tester.getRect(find.byType(MermaidRenderWidget));
        fakeController.viewportSize = widgetRect.size;

        // onLoadStop has completed, but Mermaid's asynchronous render and
        // first fit have not. Exercise both native scale-gesture updates in
        // that interval, when their pan/pinch state can be overwritten.
        await tester.drag(
          find.byType(MermaidRenderWidget),
          const Offset(35, -12),
        );
        await tester.pump();

        final center = widgetRect.center;
        final firstFinger = await tester.startGesture(
          center - const Offset(30, 0),
          pointer: 5,
        );
        final secondFinger = await tester.startGesture(
          center + const Offset(30, 0),
          pointer: 6,
        );
        await tester.pump();
        await firstFinger.moveTo(center - const Offset(60, 0));
        await secondFinger.moveTo(center + const Offset(60, 0));
        await tester.pump();
        await firstFinger.up();
        await secondFinger.up();
        await tester.pump();

        expect(
          fakeController.gestureTransformCalls,
          isNotEmpty,
          reason: 'native gestures must reach the page before its first fit',
        );
        expect(
          fakeController.gestureTransformCalls.any(
            (operation) =>
                operation.scale == 1 &&
                (operation.panDeltaX != 0 || operation.panDeltaY != 0),
          ),
          isTrue,
          reason: 'the pre-fit drag should be sent as a relative pan',
        );
        expect(
          fakeController.gestureTransformCalls.any(
            (operation) => operation.scale > 1,
          ),
          isTrue,
          reason: 'the pre-fit pinch should be sent as a relative scale',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb,
    );

    testWidgets(
      'pinch continuing across first fit uses the latest transform baseline',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(
            mermaidCode: 'graph TD\nA-->B',
            height: 200,
            showToolbar: false,
          ),
          supportsJavaScriptHandlers: true,
        );
        final fakeController = webView.controller;
        final widgetRect = tester.getRect(find.byType(MermaidRenderWidget));
        fakeController.viewportSize = widgetRect.size;
        final center = widgetRect.center;
        final firstFinger = await tester.startGesture(
          center - const Offset(30, 0),
          pointer: 7,
        );
        final secondFinger = await tester.startGesture(
          center + const Offset(30, 0),
          pointer: 8,
        );
        await tester.pump();

        await firstFinger.moveTo(center - const Offset(60, 0));
        await secondFinger.moveTo(center + const Offset(60, 0));
        await tester.pump();

        // The gesture remains active while the asynchronous first fit resets
        // JS state and replays its queued transforms into the fitted view.
        fakeController.simulateJsFitToViewport(0.8);
        final fittedGestureScale = fakeController.zoomLevel / 0.8;
        expect(fittedGestureScale, greaterThan(1.5));
        final callsBeforeContinuation =
            fakeController.gestureTransformCalls.length;

        await firstFinger.moveTo(center - const Offset(90, 0));
        await secondFinger.moveTo(center + const Offset(90, 0));
        await tester.pump();

        final continuingScales = fakeController.gestureTransformCalls
            .skip(callsBeforeContinuation)
            .map((operation) => operation.scale);
        final combinedScale = continuingScales.fold<double>(
          1,
          (scale, updateScale) => scale * updateScale,
        );
        expect(
          combinedScale,
          closeTo(3 / fittedGestureScale, 0.0001),
          reason:
              'continued pinch deltas must be based on the latest cumulative gesture scale after fit',
        );

        await firstFinger.up();
        await secondFinger.up();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb,
    );

    testWidgets(
      'pre-fit pinch scale is not clamped against the default Flutter zoom',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(
            mermaidCode: 'graph TD\nA-->B',
            height: 200,
            showToolbar: false,
          ),
        );
        final fakeController = webView.controller;
        final widgetRect = tester.getRect(find.byType(MermaidRenderWidget));
        fakeController.viewportSize = widgetRect.size;
        final center = widgetRect.center;
        final firstFinger = await tester.startGesture(
          center - const Offset(30, 0),
          pointer: 9,
        );
        final secondFinger = await tester.startGesture(
          center + const Offset(30, 0),
          pointer: 10,
        );
        await tester.pump();

        await firstFinger.moveTo(center - const Offset(330, 0));
        await secondFinger.moveTo(center + const Offset(330, 0));
        await tester.pump();

        fakeController.simulateJsFitToViewport(0.5);
        expect(
          fakeController.zoomLevel,
          closeTo(5.5, 0.001),
          reason:
              'the raw 11x pinch must be replayed against the fitted 0.5x zoom',
        );

        await firstFinger.up();
        await secondFinger.up();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb,
    );

    testWidgets(
      'a stationary native diagram tap forwards one WebView click',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(
            mermaidCode: 'graph TD\nA-->B',
            height: 200,
            showToolbar: false,
          ),
        );
        final hitPoint = tester.getCenter(find.byType(InAppWebView));

        await tester.tapAt(hitPoint);
        await tester.pump();

        final clickScripts = webView.controller.evaluatedScripts.where(
          (script) =>
              script.contains('document.elementFromPoint') &&
              script.contains("target.dispatchEvent(new MouseEvent('click', {"),
        );
        expect(
          clickScripts,
          hasLength(1),
          reason: 'a tap on the native gesture overlay must invoke the page '
              'click target exactly once',
        );
        expect(clickScripts.single, contains('bubbles: true'));
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb,
    );

    testWidgets(
      'sub-slop native diagram tap jitter forwards one WebView click',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(
            mermaidCode: 'graph TD\nA-->B',
            height: 200,
            showToolbar: false,
          ),
        );
        final hitPoint = tester.getCenter(find.byType(InAppWebView));
        int forwardedClickCount() => webView.controller.evaluatedScripts
            .where(
              (script) =>
                  script.contains('document.elementFromPoint') &&
                  script.contains(
                    "target.dispatchEvent(new MouseEvent('click', {",
                  ),
            )
            .length;

        for (final (pointer, kind, jitter)
            in <(int, PointerDeviceKind, Offset)>[
          (1, PointerDeviceKind.touch, const Offset(5, 3)),
          (2, PointerDeviceKind.mouse, const Offset(0.5, 0.5)),
        ]) {
          final clicksBeforeGesture = forwardedClickCount();
          final gesture = await tester.startGesture(
            hitPoint,
            pointer: pointer,
            kind: kind,
          );
          await gesture.moveBy(jitter);
          await gesture.up();
          await tester.pump();

          expect(
            forwardedClickCount() - clicksBeforeGesture,
            1,
            reason: 'sub-slop $kind pointer jitter must still invoke the '
                'page click target exactly once',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb,
    );

    testWidgets(
      'diagram drags pan without forwarding clicks or scrolling parent',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final scrollController = ScrollController();
        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 100),
                const MermaidRenderWidget(
                  mermaidCode: 'graph TD\nA-->B',
                  height: 200,
                  showToolbar: false,
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        );

        await tester.drag(
          find.byType(MermaidRenderWidget),
          const Offset(0, -40),
        );
        await tester.pump();
        expect(scrollController.offset, closeTo(0, 0.1));

        await tester.drag(
          find.byType(MermaidRenderWidget),
          const Offset(60, 0),
        );
        await tester.pump();

        expect(scrollController.offset, closeTo(0, 0.1));
        expect(
          webView.controller.evaluatedScripts,
          contains(predicate<String>((script) =>
              script.contains('window.applyGestureTransformAfterFit('))),
        );
        expect(
          webView.controller.evaluatedScripts.where(
            (script) =>
                script.contains('document.elementFromPoint') &&
                script
                    .contains("target.dispatchEvent(new MouseEvent('click', {"),
          ),
          isEmpty,
          reason: 'dragging the diagram must never fire a Mermaid click target',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        scrollController.dispose();
      },
      skip: kIsWeb,
    );

    testWidgets(
      'native source updates ignore stale subresource errors but show active document errors',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          InAppWebViewPlatform.instance =
              previousPlatform ?? _MermaidWebViewPlatform();
        });

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
          supportsJavaScriptHandlers: true,
        );
        final initialDocumentUrl = webView.params.initialData!.baseUrl;
        expect(
          initialDocumentUrl,
          isNotNull,
          reason: 'native initialData needs a document identity for callbacks',
        );
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->C'),
            ),
          ),
        );
        await tester.pump();
        final staleDocumentUrl = webView.controller.loadedDataBaseUrls.last!;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->D'),
            ),
          ),
        );
        await tester.pump();
        final activeDocumentUrl = webView.controller.loadedDataBaseUrls.last!;

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('${staleDocumentUrl}old-image.svg'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Stale subresource failed'),
          findsNothing,
        );
        expect(find.text('重试'), findsNothing);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri(
              Uri.parse(staleDocumentUrl.toString())
                  .resolve('../old-parent-relative-image.svg')
                  .toString(),
            ),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale parent-relative subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Stale parent-relative subresource failed'),
          findsNothing,
        );

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri(
              Uri.parse(staleDocumentUrl.toString())
                  .resolve('/old-absolute-image.svg')
                  .toString(),
            ),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale absolute subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Stale absolute subresource failed'),
          findsNothing,
        );

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('${initialDocumentUrl!}old-initial-image.svg'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale initial subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Stale initial subresource failed'),
          findsNothing,
        );

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('https://cdn.example/old-image.svg'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale external subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Stale external subresource failed'),
          findsNothing,
        );
        expect(find.text('重试'), findsNothing);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('https://cdn.example/current-image.svg'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Current absolute subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Current absolute subresource failed'),
          findsNothing,
        );
        expect(find.text('重试'), findsNothing);

        webView.controller.simulateMermaidError(
          'Current absolute subresource failed',
          2,
        );
        await tester.pump();
        expect(
          find.text('Current absolute subresource failed'),
          findsOneWidget,
          reason: 'the current document reports external failures by bridge',
        );
        expect(find.text('重试'), findsOneWidget);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('${activeDocumentUrl}current-image.svg'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Current subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Current subresource failed'),
          findsOneWidget,
        );

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri(
              Uri.parse(activeDocumentUrl.toString())
                  .resolve('../current-parent-relative-image.svg')
                  .toString(),
            ),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Current parent-relative subresource failed',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Current parent-relative subresource failed'),
          findsOneWidget,
        );

        expect(find.text('重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb || defaultTargetPlatform == TargetPlatform.windows,
    );

    testWidgets(
      'native source updates ignore stale Mermaid bridge errors but show active document errors',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          InAppWebViewPlatform.instance =
              previousPlatform ?? _MermaidWebViewPlatform();
        });

        final webView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
          supportsJavaScriptHandlers: true,
        );
        final controller = webView.controller;
        final initialData = webView.params.initialData!;
        final initialHtml = initialData.data;
        expect(
          initialHtml,
          contains("callHandler('onMermaidError', msg, 0);"),
        );
        expect(
          initialHtml,
          contains("window.addEventListener('error', function(event) {"),
        );
        expect(
          initialHtml,
          contains("reportError('Mermaid resource failed to load');"),
        );
        expect(
          initialHtml,
          isNot(
            contains('MERMAID_GENERATION_SCOPED_RESOURCE_ERROR_LISTENER'),
          ),
        );

        controller.simulateMermaidError(
          'Current initial Mermaid render failed',
          0,
        );
        await tester.pump();
        expect(
          find.text('Current initial Mermaid render failed'),
          findsOneWidget,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->C'),
            ),
          ),
        );
        await tester.pump();
        const staleGeneration = 1;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->D'),
            ),
          ),
        );
        await tester.pump();
        const activeGeneration = 2;
        expect(activeGeneration, isNot(staleGeneration));

        controller.simulateMermaidError(
          'Stale initial Mermaid render failed',
          0,
        );
        await tester.pump();

        expect(find.text('Stale initial Mermaid render failed'), findsNothing);
        expect(find.text('重试'), findsNothing);

        controller.simulateMermaidError(
          'Stale Mermaid render failed',
          staleGeneration,
        );
        await tester.pump();

        expect(find.text('Stale Mermaid render failed'), findsNothing);
        expect(find.text('重试'), findsNothing);

        controller.simulateMermaidError(
          'Current Mermaid render failed',
          activeGeneration,
        );
        await tester.pump();

        expect(find.text('Current Mermaid render failed'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(
          controller.loadedDataDocuments[0],
          contains("callHandler('onMermaidError', msg, 1);"),
        );
        expect(
          controller.loadedDataDocuments[1],
          contains("callHandler('onMermaidError', msg, 2);"),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb || defaultTargetPlatform == TargetPlatform.windows,
    );

    testWidgets(
      'native source updates ignore stale errors and completion before current load errors',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final previousTargetPlatform = debugDefaultTargetPlatformOverride;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());
        late final Map<String, bool> androidState;
        late final Map<String, bool> windowsState;

        try {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final platform = _MermaidWebViewPlatform();
          InAppWebViewPlatform.instance = platform;
          final webView = await _mountReadyMermaidWidget(
            tester,
            platform,
            const MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
          );
          final controller =
              webView.controllerFromPlatform<InAppWebViewController>(
                  webView.controller);

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->C'),
              ),
            ),
          );
          await tester.pump();
          final previousLoadUrl =
              webView.controller.loadedDataBaseUrls.single ??
                  WebUri('about:blank');

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->D'),
              ),
            ),
          );
          await tester.pump();
          final currentLoadUrl = webView.controller.loadedDataBaseUrls.last ??
              WebUri('about:blank');

          final loadingVisibleBeforeStaleCompletion =
              find.text('加载渲染引擎...').evaluate().isNotEmpty;
          webView.params.onLoadStop?.call(controller, previousLoadUrl);
          await tester.pump();
          final loadingVisibleAfterStaleCompletion =
              find.text('加载渲染引擎...').evaluate().isNotEmpty;

          webView.params.onReceivedError!(
            controller,
            WebResourceRequest(url: previousLoadUrl, isForMainFrame: true),
            WebResourceError(
              type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
              description: 'Stale load failed',
            ),
          );
          await tester.pump();
          expect(
            find.text('页面加载失败: Stale load failed'),
            findsNothing,
            reason: 'an earlier source must not replace the current preview',
          );
          expect(find.text('重试'), findsNothing);

          const errorMessage = '页面加载失败: Could not connect to host';
          webView.params.onReceivedError!(
            controller,
            WebResourceRequest(url: currentLoadUrl, isForMainFrame: true),
            WebResourceError(
              type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
              description: 'Could not connect to host',
            ),
          );
          await tester.pump();

          androidState = {
            'loading overlay before stale completion':
                loadingVisibleBeforeStaleCompletion,
            'loading overlay after stale completion':
                loadingVisibleAfterStaleCompletion,
            'current load error': find.text(errorMessage).evaluate().isNotEmpty,
            'retry action': find.text('重试').evaluate().isNotEmpty,
          };

          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          final windowsPlatform = _MermaidWebViewPlatform();
          InAppWebViewPlatform.instance = windowsPlatform;
          await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
              ),
            ),
          );
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          });
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();

          final previousWebView = windowsPlatform.webView!;
          final previousController =
              previousWebView.controllerFromPlatform<InAppWebViewController>(
                  previousWebView.controller);
          // Keep the initial document pending so its readiness fallback is
          // still active when the source update remounts the Windows view.
          previousWebView.params.onWebViewCreated!(previousController);
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->C'),
              ),
            ),
          );
          await tester.pump();
          final firstPendingWebView = windowsPlatform.webView!;
          final firstPendingController = firstPendingWebView
              .controllerFromPlatform<InAppWebViewController>(
                  firstPendingWebView.controller);
          final firstPendingViewKey =
              tester.widget<InAppWebView>(find.byType(InAppWebView)).key;
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->D'),
              ),
            ),
          );
          await tester.pump();
          final currentWebView = windowsPlatform.webView!;
          final currentController =
              currentWebView.controllerFromPlatform<InAppWebViewController>(
                  currentWebView.controller);
          final currentViewKey =
              tester.widget<InAppWebView>(find.byType(InAppWebView)).key;
          final viewRekeyedForPendingSourceUpdate =
              firstPendingViewKey != currentViewKey;

          // The replacement view has not delivered onWebViewCreated. The old
          // readiness deadline must not resolve the new view's loading state.
          await tester.pump(const Duration(seconds: 3));
          final windowsLoadingVisibleAfterPreviousFallback =
              find.text('加载渲染引擎...').evaluate().isNotEmpty;

          currentWebView.params.onWebViewCreated!(currentController);
          await tester.pump();

          // A pending view superseded by the second source update may still
          // finish creating. Its late controller and document must stay stale.
          firstPendingWebView.params.onWebViewCreated!(firstPendingController);
          await tester.pump();
          firstPendingWebView.params.onLoadStop?.call(
            firstPendingController,
            null,
          );
          await tester.pump();
          final windowsLoadingVisibleAfterStalePendingViewCompletion =
              find.text('加载渲染引擎...').evaluate().isNotEmpty;

          previousWebView.params.onLoadStop?.call(previousController, null);
          await tester.pump();
          final windowsLoadingVisibleAfterStaleCompletion =
              find.text('加载渲染引擎...').evaluate().isNotEmpty;

          currentWebView.params.onReceivedError!(
            currentController,
            WebResourceRequest(
              url: WebUri('about:blank'),
              isForMainFrame: true,
            ),
            WebResourceError(
              type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
              description: 'Could not connect to host',
            ),
          );
          await tester.pump();
          windowsState = {
            'view remounted for source update':
                !identical(previousWebView, currentWebView),
            'view rekeyed for update while creation was pending':
                viewRekeyedForPendingSourceUpdate,
            'loading overlay after previous readiness fallback':
                windowsLoadingVisibleAfterPreviousFallback,
            'loading overlay after stale pending-view completion':
                windowsLoadingVisibleAfterStalePendingViewCompletion,
            'loading overlay after stale completion':
                windowsLoadingVisibleAfterStaleCompletion,
            'current load error': find.text(errorMessage).evaluate().isNotEmpty,
            'retry action': find.text('重试').evaluate().isNotEmpty,
          };
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = previousTargetPlatform;
        }

        expect(
          {
            'loadData generation guard': androidState,
            'Windows view guard': windowsState
          },
          {
            'loadData generation guard': {
              'loading overlay before stale completion': true,
              'loading overlay after stale completion': true,
              'current load error': true,
              'retry action': true,
            },
            'Windows view guard': {
              'view remounted for source update': true,
              'view rekeyed for update while creation was pending': true,
              'loading overlay after previous readiness fallback': true,
              'loading overlay after stale pending-view completion': true,
              'loading overlay after stale completion': true,
              'current load error': true,
              'retry action': true,
            },
          },
        );
        expect(tester.takeException(), isNull);
      },
      skip: kIsWeb,
    );

    testWidgets(
      'native initial-page failures after readiness fallback show retry',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        final webView = platform.webView!;
        final initialDocumentUrl = webView.params.initialData!.baseUrl!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();

        // Native readiness fallback only hides Flutter's loading overlay; it
        // does not prove that the initial page loaded successfully.
        expect(find.text('加载渲染引擎...'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('加载渲染引擎...'), findsNothing);

        const errorMessage = '页面加载失败: Could not connect to host';
        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: initialDocumentUrl,
            isForMainFrame: true,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Could not connect to host',
          ),
        );
        await tester.pump();

        expect(find.text(errorMessage), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb || defaultTargetPlatform == TargetPlatform.windows,
    );

    testWidgets(
      'web main-frame navigation errors show retry after creation hides loading',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        expect(find.text('正在准备渲染引擎...'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();

        // The iframe manages its own render progress, so the Flutter overlay
        // must be removed as soon as the WebView is created. This deliberately
        // does not send onLoadStop.
        expect(find.text('加载渲染引擎...'), findsNothing);

        const errorMessage = '页面加载失败: Could not connect to host';
        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('https://cdn.example/mermaid.min.js'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Could not connect to host',
          ),
        );
        await tester.pump();

        // Subresource failures stay inside the web renderer so the iframe's
        // loading hint and error handling remain visible.
        expect(find.text(errorMessage), findsNothing);
        expect(find.text('加载渲染引擎...'), findsNothing);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri(
              MermaidRenderWidget.buildWebAssetUrl('graph TD\nA-->B'),
            ),
            isForMainFrame: true,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Could not connect to host',
          ),
        );
        await tester.pump();

        expect(find.text(errorMessage), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'web source updates keep queued zoom until current load completes',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(
                mermaidCode: 'graph TD\nA-->B',
                showZoomControls: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();
        final previousUrl = webView.controller.loadedUrls.last;
        webView.params.onLoadStop?.call(controller, previousUrl);
        await tester.pump();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(
                mermaidCode: 'graph TD\nA-->C',
                showZoomControls: true,
              ),
            ),
          ),
        );
        await tester.pump();
        final currentUrl = webView.controller.loadedUrls.last;
        expect(currentUrl, isNot(previousUrl));

        final scriptCountBeforeQueuedZoom =
            webView.controller.evaluatedScripts.length;
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
        expect(
          webView.controller.evaluatedScripts,
          hasLength(scriptCountBeforeQueuedZoom),
          reason: 'zoom waits for the active source document to load',
        );

        webView.params.onLoadStop?.call(controller, null);
        await tester.pump();
        expect(
          webView.controller.evaluatedScripts,
          hasLength(scriptCountBeforeQueuedZoom),
          reason: 'a completion without a URL must not flush queued zoom',
        );

        webView.params.onLoadStop?.call(controller, previousUrl);
        await tester.pump();
        expect(
          webView.controller.evaluatedScripts,
          hasLength(scriptCountBeforeQueuedZoom),
          reason: 'a superseded source completion must not flush queued zoom',
        );

        webView.params.onLoadStop?.call(controller, currentUrl);
        await tester.pump();
        expect(
          webView.controller.evaluatedScripts,
          contains(predicate<String>((script) =>
              script.contains('window.applyZoomDeltasAfterFit([0.1])'))),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'web source updates ignore stale errors and surface current errors',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();
        final previousUrl = webView.controller.loadedUrls.last;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: ' graph TD\nA-->B '),
            ),
          ),
        );
        await tester.pump();
        final currentUrl = webView.controller.loadedUrls.last;
        expect(
          MermaidRenderWidget.buildWebAssetUrl('graph TD\nA-->B'),
          MermaidRenderWidget.buildWebAssetUrl(' graph TD\nA-->B '),
          reason: 'whitespace-only source changes share the same rendered URL',
        );
        expect(currentUrl, isNot(previousUrl));

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(url: previousUrl, isForMainFrame: true),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale load failed',
          ),
        );
        await tester.pump();

        expect(find.text('页面加载失败: Stale load failed'), findsNothing);
        expect(find.text('重试'), findsNothing);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(url: currentUrl, isForMainFrame: true),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Current load failed',
          ),
        );
        await tester.pump();

        expect(find.text('页面加载失败: Current load failed'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'web retry falls back without load completion or main-frame error',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri(
              MermaidRenderWidget.buildWebAssetUrl('graph TD\nA-->B'),
            ),
            isForMainFrame: true,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Could not connect to host',
          ),
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Could not connect to host'),
          findsOneWidget,
        );
        await tester.tap(find.text('重试'));
        await tester.pump();

        expect(find.text('加载渲染引擎...'), findsOneWidget);
        expect(find.text('页面加载失败: Could not connect to host'), findsNothing);

        // A subresource failure does not resolve the retry navigation or
        // disable its fallback. No onLoadStop or main-frame error follows.
        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: WebUri('https://cdn.example/mermaid.min.js'),
            isForMainFrame: false,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Could not connect to host',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(find.text('页面加载超时，请重试'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);

        // A navigation that completes after the fallback should replace its
        // timeout message with the successfully loaded preview.
        webView.params.onLoadStop?.call(
          controller,
          webView.controller.loadedUrls.last,
        );
        await tester.pump();

        expect(find.text('页面加载超时，请重试'), findsNothing);
        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'web retry source update gets a fresh fallback window',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();
        final initialUrl = webView.controller.loadedUrls.last;

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: initialUrl,
            isForMainFrame: true,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Initial navigation failed',
          ),
        );
        await tester.pump();

        await tester.tap(find.text('重试'));
        await tester.pump();
        final oldRetryUrl = webView.controller.loadedUrls.last;
        await tester.pump(const Duration(seconds: 2));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nC-->D'),
            ),
          ),
        );
        await tester.pump();
        final updatedUrl = webView.controller.loadedUrls.last;
        webView.params.onLoadStop?.call(controller, oldRetryUrl);
        await tester.pump();
        expect(find.text('加载渲染引擎...'), findsOneWidget);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(url: oldRetryUrl, isForMainFrame: true),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale navigation failed',
          ),
        );
        await tester.pump();
        expect(find.text('加载渲染引擎...'), findsOneWidget);
        expect(find.text('页面加载失败: Stale navigation failed'), findsNothing);

        await tester.pump(const Duration(seconds: 2));

        expect(find.text('加载渲染引擎...'), findsOneWidget);
        expect(find.text('页面加载超时，请重试'), findsNothing);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(find.text('页面加载超时，请重试'), findsOneWidget);
        webView.params.onLoadStop?.call(controller, updatedUrl);
        await tester.pump();
        expect(find.text('页面加载超时，请重试'), findsNothing);
        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(find.text('重试'), findsNothing);

        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(url: oldRetryUrl, isForMainFrame: true),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Stale navigation failed after success',
          ),
        );
        await tester.pump();
        expect(
          find.text('页面加载失败: Stale navigation failed after success'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'web retry source update restarts recovery after timeout',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();
        webView.params.onReceivedError!(
          controller,
          WebResourceRequest(
            url: webView.controller.loadedUrls.last,
            isForMainFrame: true,
          ),
          WebResourceError(
            type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
            description: 'Initial navigation failed',
          ),
        );
        await tester.pump();

        await tester.tap(find.text('重试'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('页面加载超时，请重试'), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nC-->D'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('加载渲染引擎...'), findsOneWidget);
        expect(find.text('页面加载超时，请重试'), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('加载渲染引擎...'), findsOneWidget);
        expect(find.text('页面加载超时，请重试'), findsNothing);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(find.text('页面加载超时，请重试'), findsOneWidget);
        webView.params.onLoadStop?.call(
          controller,
          webView.controller.loadedUrls.last,
        );
        await tester.pump();
        expect(find.text('页面加载超时，请重试'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'same-source web retry ignores callbacks from the prior attempt',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);
        webView.params.onWebViewCreated!(controller);
        await tester.pump();

        void sendMainFrameError(WebUri url, String description) {
          webView.params.onReceivedError!(
            controller,
            WebResourceRequest(url: url, isForMainFrame: true),
            WebResourceError(
              type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
              description: description,
            ),
          );
        }

        sendMainFrameError(
          webView.controller.loadedUrls.last,
          'Initial navigation failed',
        );
        await tester.pump();

        await tester.tap(find.text('重试'));
        await tester.pump();
        final previousRetryUrl = webView.controller.loadedUrls.last;
        sendMainFrameError(previousRetryUrl, 'First retry failed');
        await tester.pump();

        expect(find.text('页面加载失败: First retry failed'), findsOneWidget);
        await tester.tap(find.text('重试'));
        await tester.pump();
        final currentRetryUrl = webView.controller.loadedUrls.last;

        webView.params.onLoadStop?.call(controller, previousRetryUrl);
        await tester.pump();
        expect(find.text('加载渲染引擎...'), findsOneWidget);

        sendMainFrameError(previousRetryUrl, 'Stale retry failure');
        await tester.pump();
        expect(find.text('加载渲染引擎...'), findsOneWidget);
        expect(find.text('页面加载失败: Stale retry failure'), findsNothing);

        await tester.pump(const Duration(seconds: 3));
        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(find.text('页面加载超时，请重试'), findsOneWidget);

        webView.params.onLoadStop?.call(controller, currentRetryUrl);
        await tester.pump();
        expect(find.text('页面加载超时，请重试'), findsNothing);
        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'web retry completion and navigation error resolve fallback state',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final webView = platform.webView!;
        final controller = webView
            .controllerFromPlatform<InAppWebViewController>(webView.controller);

        void sendMainFrameError(String description) {
          webView.params.onReceivedError!(
            controller,
            WebResourceRequest(
              url: webView.controller.loadedUrls.last,
              isForMainFrame: true,
            ),
            WebResourceError(
              type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
              description: description,
            ),
          );
        }

        webView.params.onWebViewCreated!(controller);
        await tester.pump();
        sendMainFrameError('Initial navigation failed');
        await tester.pump();

        await tester.tap(find.text('重试'));
        await tester.pump();
        webView.params.onLoadStop?.call(
          controller,
          webView.controller.loadedUrls.last,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('加载渲染引擎...'), findsNothing);
        expect(find.text('页面加载超时，请重试'), findsNothing);
        expect(find.text('页面加载失败: Initial navigation failed'), findsNothing);

        sendMainFrameError('Retry navigation failed');
        await tester.pump();
        expect(find.text('页面加载失败: Retry navigation failed'), findsOneWidget);

        await tester.tap(find.text('重试'));
        await tester.pump();
        sendMainFrameError('Final navigation failure');
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('页面加载失败: Final navigation failure'), findsOneWidget);
        expect(find.text('页面加载超时，请重试'), findsNothing);

        await tester.tap(find.text('重试'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('页面加载超时，请重试'), findsOneWidget);

        sendMainFrameError('Late main-frame failure');
        await tester.pump();
        webView.params.onLoadStop?.call(
          controller,
          webView.controller.loadedUrls.last,
        );
        await tester.pump();

        expect(
          find.text('页面加载失败: Late main-frame failure'),
          findsOneWidget,
        );
        expect(find.text('页面加载超时，请重试'), findsNothing);
        expect(find.text('重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb,
    );

    testWidgets(
      'retry after WebView creation timeout mounts a fresh platform view',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        const creationError = '图表渲染引擎初始化失败，请重试';
        await tester.pump(const Duration(seconds: 12));
        expect(find.text(creationError), findsOneWidget);
        final failedWebViewElement = tester.element(find.byType(InAppWebView));
        final failedWebView = platform.webView!;
        final failedInitialData = failedWebView.params.initialData!;

        await tester.tap(find.text('重试'));
        await tester.pump();

        expect(
          tester.element(find.byType(InAppWebView)),
          isNot(same(failedWebViewElement)),
          reason: 'Retry must create a new platform view when the controller '
              'was never created',
        );
        final retriedInitialData = platform.webView!.params.initialData!;
        expect(
          retriedInitialData.data,
          contains("callHandler('onMermaidError', msg, 1);"),
          reason: 'the remounted page must use the retry document generation',
        );
        expect(
          retriedInitialData.baseUrl,
          isNot(failedInitialData.baseUrl),
          reason: 'the remounted page must use a new native document identity',
        );
        expect(find.text(creationError), findsNothing);

        await tester.pump(const Duration(seconds: 12));
        expect(
          find.text(creationError),
          findsOneWidget,
          reason: 'the creation fallback must report a repeated mount failure',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb || defaultTargetPlatform == TargetPlatform.windows,
    );

    testWidgets(
      'empty-code remount reports a failed WebView creation',
      (tester) async {
        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        final firstWebView = await _mountReadyMermaidWidget(
          tester,
          platform,
          const MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: ''),
            ),
          ),
        );
        expect(find.text('No Mermaid code to render'), findsOneWidget);
        expect(find.byType(InAppWebView), findsNothing);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
            ),
          ),
        );
        final remountedWebView = platform.webView!;
        expect(remountedWebView, isNot(same(firstWebView)));
        expect(find.text('加载渲染引擎...'), findsOneWidget);

        // Simulate a platform view that mounts but never calls
        // onWebViewCreated after the previous controller was retained.
        await tester.pump(const Duration(seconds: 12));

        expect(find.text('图表渲染引擎初始化失败，请重试'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: kIsWeb,
    );

    testWidgets('shows loading state initially before WebView creation',
        (tester) async {
      const widget = MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      // Should show the loading indicator text
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      // Loading state shows before WebView creation, so action buttons
      // (zoom, fullscreen, source code toggle) should NOT be shown yet
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
      expect(find.byIcon(Icons.code), findsNothing);
    });

    testWidgets('shows empty placeholder for empty code', (tester) async {
      const widget = MermaidRenderWidget(mermaidCode: '');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      expect(find.text('No Mermaid code to render'), findsOneWidget);
    });

    testWidgets('handles empty code gracefully', (tester) async {
      const widget = MermaidRenderWidget(mermaidCode: '');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      expect(find.text('No Mermaid code to render'), findsOneWidget);
      expect(find.text('正在准备渲染引擎...'), findsNothing);
    });
  });

  group('MermaidRenderWidget - gesture wrapper', () {
    testWidgets('gesture wrapper not present when showing source code',
        (tester) async {
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD',
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      // Source code mode shows code text, no gesture wrapper needed
      expect(find.text('graph TD'), findsOneWidget);
    });
  });

  group('MermaidRenderWidget - showZoomControls', () {
    testWidgets(
        'showZoomControls:false does not show zoom buttons in loading state',
        (tester) async {
      // Regression: default showZoomControls should be false, so zoom
      // buttons should NOT appear when the widget is in loading state.
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showZoomControls: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Should show loading indicator but no zoom buttons
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
    });

    testWidgets('showZoomControls:true shows zoom buttons in loading state',
        (tester) async {
      // Regression: when showZoomControls is true, zoom in/out buttons
      // should appear even in the loading state (before WebView is ready).
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showZoomControls: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Should show zoom buttons alongside loading indicator
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    });

    testWidgets('showZoomControls:true does not show fullscreen or code-toggle',
        (tester) async {
      // Regression: showZoomControls should ONLY show zoom buttons, not
      // the full toolbar (fullscreen, code toggle, save).
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showZoomControls: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Only zoom buttons should appear
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      // These should NOT appear
      expect(find.byIcon(Icons.fullscreen), findsNothing);
      expect(find.byIcon(Icons.code), findsNothing);
      expect(find.byIcon(Icons.save), findsNothing);
    });

    testWidgets('showZoomControls:true and showToolbar:true show both',
        (tester) async {
      // Regression: showZoomControls should combine with showToolbar.
      // The full toolbar shows when showToolbar is true, and the zoom
      // controls shown via showZoomControls should not duplicate.
      // In practice, when showToolbar is true the toolbar already
      // contains zoom controls, so showZoomControls is redundant but
      // should not cause errors or layout issues.
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showZoomControls: true,
        showToolbar: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Loading state — zoom buttons shown by showZoomControls
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    });

    testWidgets('showZoomControls works with testOnlyShowSourceCode',
        (tester) async {
      // Regression: showZoomControls should not affect source code mode
      // (source code mode shows its own action buttons).
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showZoomControls: true,
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // In source code mode, show zoom controls via separate path
      // Source code view shows code, not zoom buttons
      expect(find.text('graph TD\nA-->B'), findsOneWidget);
      // Source code view uses its own action buttons
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('showZoomControls buttons have proper accessibility labels',
        (tester) async {
      // Regression: zoom buttons must have semanticLabel for accessibility.
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showZoomControls: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      final zoomInIcon = tester.widget<Icon>(find.byIcon(Icons.zoom_in));
      final zoomOutIcon = tester.widget<Icon>(find.byIcon(Icons.zoom_out));
      expect(zoomInIcon.semanticLabel, isNotNull);
      expect(zoomOutIcon.semanticLabel, isNotNull);
    });

    testWidgets(
        'showZoomControls:false hidden when showToolbar:false (default)',
        (tester) async {
      // Regression: default showZoomControls should be false, matching
      // the existing behavior of showToolbar:false.
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // No zoom buttons by default
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
    });
  });

  group('MermaidRenderWidget - source code mode (test-only)', () {
    testWidgets('shows source code view with code text', (tester) async {
      const mermaidCode = 'graph TD\nA-->B';
      const widget = MermaidRenderWidget(
        mermaidCode: mermaidCode,
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Should show mermaid code as selectable text
      expect(find.text(mermaidCode), findsOneWidget);
    });

    testWidgets('shows toggle button with image icon in source code mode',
        (tester) async {
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD',
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // In source code mode: image icon (查看图表)
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.byIcon(Icons.code), findsNothing);
      // Zoom controls should NOT be visible in source code mode
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
    });

    testWidgets('toggle to render mode transitions state without error',
        (tester) async {
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD',
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Start in source code mode with image icon
      expect(find.byIcon(Icons.image), findsOneWidget);

      // Tap the "查看图表" button to toggle to render mode
      await tester.tap(find.byIcon(Icons.image));
      await tester.pump();

      // After toggle, the widget leaves source code mode. Since
      // testOnlyShowSourceCode means no WebView was ever created,
      // the widget will show a loading indicator (trying to set up
      // the deferred WebView). The important thing is the toggle
      // doesn't crash and the source code text is no longer shown.
      expect(find.byIcon(Icons.image), findsNothing);
    });

    testWidgets('handles empty code in source code mode', (tester) async {
      const widget = MermaidRenderWidget(
        mermaidCode: '',
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Empty code should show the placeholder, not the code view
      expect(find.text('No Mermaid code to render'), findsOneWidget);
    });

    testWidgets('source code mode keeps the render layer mounted underneath',
        (tester) async {
      // Regression: toggling to the source code view must NOT unmount the
      // render layer (the loading placeholder here — the WebView platform
      // view in production). Previously the source view REPLACED the
      // render tree, destroying the platform view; toggling back to
      // preview then re-created it from scratch, producing a blank flash
      // followed by a loading animation. The chart page (home page entry)
      // avoids this by keeping the preview mounted while the code editor
      // is visible — the inline widget must do the same.
      //
      // The render layer must keep the SAME element across the toggle:
      // if its root widget type changed between modes, Flutter would tear
      // down and re-inflate the whole subtree (disposing the platform
      // view) even though both modes render the loading placeholder.
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Source code view is shown...
      expect(find.text('graph TD\nA-->B'), findsOneWidget);
      // ...and the render layer is still mounted underneath it (covered
      // by the source view's opaque background, but alive in the tree).
      final renderLayerText = find.text('正在准备渲染引擎...');
      expect(renderLayerText, findsOneWidget);
      final renderLayerElement = tester.element(renderLayerText);

      // Toggle back to preview: the render layer stays mounted — the very
      // SAME element (identity, not just presence) survives the toggle.
      await tester.tap(find.byIcon(Icons.image));
      await tester.pump();
      expect(find.byIcon(Icons.image), findsNothing);
      expect(renderLayerText, findsOneWidget);
      expect(tester.element(renderLayerText), same(renderLayerElement));
      expect(tester.takeException(), isNull);
    });
  });

  group('MermaidRenderWidget - Save as MMD', () {
    testWidgets(
      'shows folder lookup failure and unlocks a successful retry',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        ManifestDatabase.enableTestMode();
        TextManifest.invalidateCache();

        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() => InAppWebViewPlatform.instance =
            previousPlatform ?? _MermaidWebViewPlatform());

        var folderLookups = 0;
        Future<Set<String>> getFolders() async {
          folderLookups++;
          if (folderLookups == 1) {
            throw StateError('folder lookup unavailable');
          }
          return TextManifest.getAllFolders();
        }

        await _mountReadyMermaidWidget(
          tester,
          platform,
          MermaidRenderWidget(
            mermaidCode: 'graph TD\n  A-->B',
            testOnlyGetAllFolders: getFolders,
          ),
        );

        await tester.tap(find.byIcon(Icons.save));
        await tester.pump();
        final firstLookupException = tester.takeException();
        final folderLookupErrorShown =
            find.textContaining('获取文件夹失败').evaluate().isNotEmpty;

        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        expect(firstLookupException, isNull);
        expect(folderLookupErrorShown, isTrue);
        expect(folderLookups, 2);
        expect(find.byType(FolderPickerDialog), findsOneWidget);

        await tester.tap(find.text('根目录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        final savedRecord = (await TextManifest.loadRecords())
            .singleWhere((r) => r.format == 'mmd');
        expect(savedRecord.folder, '');
        expect(await TextManifest.readText(savedRecord.storagePath),
            'graph TD\n  A-->B');
      },
      skip: kIsWeb,
    );

    testWidgets(
      'concurrent saves with the same name get unique names in one folder',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        ManifestDatabase.enableTestMode();
        TextManifest.invalidateCache();

        final previousPlatform = InAppWebViewPlatform.instance;
        final platform = _MermaidWebViewPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          InAppWebViewPlatform.instance =
              previousPlatform ?? _MermaidWebViewPlatform();
        });

        final firstFolderLookupStarted = Completer<void>();
        final firstFolderLookup = Completer<Set<String>>();
        final firstNameSelected = Completer<String>();
        final secondNameLockAttempted = Completer<void>();
        final bothNamesSelected = Completer<void>();
        final releaseFirstNameSelection = Completer<void>();
        final bothSavesCompleted = Completer<void>();
        final selectedNames = <String>[];
        var completedSaveCount = 0;
        addTearDown(() {
          if (!releaseFirstNameSelection.isCompleted) {
            releaseFirstNameSelection.complete();
          }
        });

        Future<void> holdFirstNameSelection(String name) async {
          selectedNames.add(name);
          firstNameSelected.complete(name);
          await releaseFirstNameSelection.future;
        }

        Future<void> recordSecondNameSelection(String name) async {
          selectedNames.add(name);
          if (selectedNames.length == 2) bothNamesSelected.complete();
        }

        void onMmdSaveComplete() {
          completedSaveCount++;
          if (completedSaveCount == 2) bothSavesCompleted.complete();
        }

        Future<Set<String>> getFirstFolders() {
          firstFolderLookupStarted.complete();
          return firstFolderLookup.future;
        }

        await _mountReadyMermaidWidgets(
          tester,
          platform,
          [
            SizedBox(
              height: 240,
              child: MermaidRenderWidget(
                mermaidCode: 'graph TD\n  A-->B',
                testOnlyGetAllFolders: getFirstFolders,
                testOnlyAfterMmdNameAllocation: holdFirstNameSelection,
                testOnlyOnMmdSaveComplete: onMmdSaveComplete,
              ),
            ),
            SizedBox(
              height: 240,
              child: MermaidRenderWidget(
                mermaidCode: 'graph TD\n  A-->C',
                testOnlyBeforeMmdFolderNameLock: () {
                  secondNameLockAttempted.complete();
                },
                testOnlyAfterMmdNameAllocation: recordSecondNameSelection,
                testOnlyOnMmdSaveComplete: onMmdSaveComplete,
              ),
            ),
          ],
        );

        await tester.tap(find.byIcon(Icons.save).first);
        await tester.runAsync(
          () async => firstFolderLookupStarted.future,
        );
        // Keep the first dialog from covering the second widget until both
        // saves have started their folder selection.
        await tester.tap(find.byIcon(Icons.save).last);
        await tester.pumpAndSettle();
        expect(find.byType(FolderPickerDialog), findsOneWidget);

        firstFolderLookup.complete({});
        await tester.pumpAndSettle();
        expect(find.byType(FolderPickerDialog), findsNWidgets(2));

        // Both diagrams default to "graph TD". Pause the first save after it
        // chooses that name, before it inserts the record.
        await tester.tap(find.text('确定').last);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () async => firstNameSelected.future,
        );

        expect(selectedNames, ['graph TD']);

        // Let the second save reach the lock while the first name is still
        // unregistered. It must not choose a name from the stale snapshot.
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await secondNameLockAttempted.future;
          await Future<void>.delayed(Duration.zero);
        });
        final secondNameSelectedBeforeFirstWasSaved = selectedNames.length > 1;

        releaseFirstNameSelection.complete();
        await tester.runAsync(() async {
          await bothNamesSelected.future.timeout(const Duration(seconds: 5));
          await bothSavesCompleted.future.timeout(const Duration(seconds: 5));
        });

        expect(secondNameSelectedBeforeFirstWasSaved, isFalse);
        final savedRecords = (await TextManifest.loadRecordsUncached())
            .where((record) => record.format == 'mmd')
            .toList();
        expect(savedRecords, hasLength(2));
        expect(
          savedRecords.map((record) => record.name),
          unorderedEquals(['graph TD', 'graph TD (2)']),
        );
        expect(
          await Future.wait(
            savedRecords
                .map((record) => TextManifest.readText(record.storagePath)),
          ),
          unorderedEquals(['graph TD\n  A-->B', 'graph TD\n  A-->C']),
        );
      },
      skip: kIsWeb,
    );
  });
}

Future<_MermaidWebView> _mountReadyMermaidWidget(
  WidgetTester tester,
  _MermaidWebViewPlatform platform,
  Widget body, {
  bool supportsJavaScriptHandlers = false,
}) async {
  await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();

  final webView = platform.webView!;
  webView.controller.supportsJavaScriptHandlers = supportsJavaScriptHandlers;
  final controller = webView.controllerFromPlatform<InAppWebViewController>(
    webView.controller,
  );
  webView.params.onWebViewCreated!(controller);
  final initialUrl = webView.params.initialData?.baseUrl;
  webView.params.onLoadStop?.call(controller, initialUrl);
  await tester.pump();
  return webView;
}

Future<List<_MermaidWebView>> _mountReadyMermaidWidgets(
  WidgetTester tester,
  _MermaidWebViewPlatform platform,
  List<Widget> bodies, {
  bool supportsJavaScriptHandlers = false,
}) async {
  await tester.runAsync(MermaidRenderWidget.loadBundledMermaidJs);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: bodies.length == 1 ? bodies.single : Column(children: bodies),
      ),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();

  for (final webView in platform.webViews) {
    webView.controller.supportsJavaScriptHandlers = supportsJavaScriptHandlers;
    final controller = webView.controllerFromPlatform<InAppWebViewController>(
      webView.controller,
    );
    webView.params.onWebViewCreated!(controller);
    final initialUrl = webView.params.initialData?.baseUrl;
    webView.params.onLoadStop?.call(controller, initialUrl);
  }
  await tester.pump();
  return platform.webViews;
}

class _MermaidWebViewPlatform extends InAppWebViewPlatform {
  _MermaidWebView? webView;
  final webViews = <_MermaidWebView>[];

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
      PlatformInAppWebViewWidgetCreationParams params) {
    final created = _MermaidWebView(params);
    webView = created;
    webViews.add(created);
    return created;
  }
}

class _MermaidWebView extends PlatformInAppWebViewWidget {
  final controller = _MermaidWebViewController();
  InAppWebViewController? _controllerWrapper;

  _MermaidWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    // The real plugin reuses one wrapper for callbacks from each platform view.
    final wrapper = _controllerWrapper ??=
        params.controllerFromPlatform!(controller) as InAppWebViewController;
    return wrapper as T;
  }

  @override
  void dispose() {}
}

class _MermaidWebViewController extends PlatformInAppWebViewController {
  final evaluatedScripts = <String>[];
  final List<({double delta, double? centerX, double? centerY})>
      _pendingZoomOperations = [];
  final gestureTransformCalls = <({
    int gestureId,
    double scale,
    double panDeltaX,
    double panDeltaY,
    double? centerX,
    double? centerY,
  })>[];
  final wheelZoomAnchors = <Offset>[];
  final loadedUrls = <WebUri>[];
  final loadedDataBaseUrls = <WebUri?>[];
  final loadedDataDocuments = <String>[];
  final _javascriptHandlers = <String, JavaScriptHandlerCallback>{};
  Size viewportSize = const Size(200, 100);
  double zoomLevel = 1.0;
  double panX = 0;
  double panY = 0;
  int? _activeNativeGestureId;
  double _nativeGestureZoomLevel = 1.0;
  bool supportsJavaScriptHandlers = false;
  bool _fitComplete = false;

  void simulateMermaidError(String message, int documentGeneration) {
    _javascriptHandlers['onMermaidError']?.call([message, documentGeneration]);
  }

  void simulateJsFitToViewport(double fittedZoom) {
    zoomLevel = fittedZoom;
    panX = 0;
    panY = 0;
    _fitComplete = true;
    _activeNativeGestureId = null;
    _nativeGestureZoomLevel = fittedZoom;
    _applyPendingZoomOperations();
    for (final operation in gestureTransformCalls) {
      _applyGestureTransform(operation);
    }
    _javascriptHandlers['onTransformChanged']?.call([
      zoomLevel,
      panX,
      panY,
    ]);
  }

  void _applyGestureTransform(
    ({
      int gestureId,
      double scale,
      double panDeltaX,
      double panDeltaY,
      double? centerX,
      double? centerY,
    }) operation,
  ) {
    if (_activeNativeGestureId != operation.gestureId) {
      _activeNativeGestureId = operation.gestureId;
      _nativeGestureZoomLevel = zoomLevel;
    }
    panX += operation.panDeltaX;
    panY += operation.panDeltaY;
    final oldZoom = zoomLevel;
    _nativeGestureZoomLevel *= operation.scale;
    zoomLevel = _nativeGestureZoomLevel.clamp(0.1, 10.0).toDouble();
    final appliedScale = oldZoom > 0 ? zoomLevel / oldZoom : 1.0;
    if (operation.centerX != null && operation.centerY != null) {
      panX = operation.centerX! - (operation.centerX! - panX) * appliedScale;
      panY = operation.centerY! - (operation.centerY! - panY) * appliedScale;
    }
  }

  void _applyPendingZoomOperations() {
    if (!_fitComplete) return;
    for (final operation in _pendingZoomOperations) {
      final centerX = operation.centerX ?? viewportSize.width / 2;
      final centerY = operation.centerY ?? viewportSize.height / 2;
      final newZoom = (zoomLevel + operation.delta).clamp(0.1, 10.0).toDouble();
      if (newZoom == zoomLevel) {
        _activeNativeGestureId = null;
        _nativeGestureZoomLevel = zoomLevel;
        continue;
      }
      panX = centerX - (centerX - panX) * (newZoom / zoomLevel);
      panY = centerY - (centerY - panY) * (newZoom / zoomLevel);
      zoomLevel = newZoom;
      _activeNativeGestureId = null;
      _nativeGestureZoomLevel = zoomLevel;
      if (operation.centerX != null && operation.centerY != null) {
        wheelZoomAnchors.add(Offset(centerX, centerY));
      }
    }
    _pendingZoomOperations.clear();
  }

  void _queueZoomOperation({
    required double delta,
    double? centerX,
    double? centerY,
  }) {
    _pendingZoomOperations.add((
      delta: delta,
      centerX: centerX,
      centerY: centerY,
    ));
    _applyPendingZoomOperations();
  }

  _MermaidWebViewController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 0));

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    final url = urlRequest.url;
    if (url != null) {
      loadedUrls.add(
        kIsWeb ? WebUri(Uri.base.resolve(url.toString()).toString()) : url,
      );
    }
  }

  @override
  Future<void> loadData({
    required String data,
    String mimeType = 'text/html',
    String encoding = 'utf8',
    WebUri? baseUrl,
    Uri? androidHistoryUrl,
    WebUri? historyUrl,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    loadedDataBaseUrls.add(baseUrl);
    loadedDataDocuments.add(data);
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    if (!supportsJavaScriptHandlers) {
      throw UnimplementedError('JavaScript handlers are unavailable on web');
    }
    _javascriptHandlers[handlerName] = callback;
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluatedScripts.add(source);
    final zoomOperations = RegExp(
      r'window\.applyZoomOperationsAfterFit\((\[[\s\S]*\])\)',
    ).firstMatch(source);
    if (zoomOperations != null) {
      final operations = jsonDecode(zoomOperations.group(1)!) as List<dynamic>;
      for (final operation in operations.cast<Map<String, dynamic>>()) {
        final delta = (operation['delta'] as num).toDouble();
        if (operation['kind'] == 'wheel') {
          _queueZoomOperation(
            delta: delta,
            centerX: (operation['centerX'] as num).toDouble(),
            centerY: (operation['centerY'] as num).toDouble(),
          );
        } else if (operation['kind'] == 'toolbar') {
          _queueZoomOperation(delta: delta);
        }
      }
      return;
    }

    final queuedWheelZoom = RegExp(
      r'window\.applyWheelZoomAfterFit\((-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\)',
    ).firstMatch(source);
    if (queuedWheelZoom != null) {
      final delta = double.parse(queuedWheelZoom.group(1)!);
      final centerX = double.parse(queuedWheelZoom.group(2)!);
      final centerY = double.parse(queuedWheelZoom.group(3)!);
      _queueZoomOperation(
        delta: delta,
        centerX: centerX,
        centerY: centerY,
      );
      return;
    }

    final gestureTransform = RegExp(
      r'window\.applyGestureTransformAfterFit\((\d+),\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*(null|-?\d+(?:\.\d+)?),\s*(null|-?\d+(?:\.\d+)?)\)',
    ).firstMatch(source);
    if (gestureTransform != null) {
      double? optionalDouble(String value) =>
          value == 'null' ? null : double.parse(value);
      gestureTransformCalls.add((
        gestureId: int.parse(gestureTransform.group(1)!),
        scale: double.parse(gestureTransform.group(2)!),
        panDeltaX: double.parse(gestureTransform.group(3)!),
        panDeltaY: double.parse(gestureTransform.group(4)!),
        centerX: optionalDouble(gestureTransform.group(5)!),
        centerY: optionalDouble(gestureTransform.group(6)!),
      ));
      if (_fitComplete) _applyGestureTransform(gestureTransformCalls.last);
      return;
    }

    final deferredZoom = RegExp(
      r'window\.applyZoomDeltasAfterFit\(\[([^\]]*)\]\)',
    ).firstMatch(source);
    if (deferredZoom != null) {
      final deltas = RegExp(r'-?\d+(?:\.\d+)?')
          .allMatches(deferredZoom.group(1)!)
          .map((match) => double.parse(match.group(0)!));
      for (final delta in deltas) {
        _queueZoomOperation(delta: delta);
      }
      return;
    }

    final relativeZoom = RegExp(
      r'window\.setZoom\(window\.zoomLevel \+ (-?\d+(?:\.\d+)?),',
    ).firstMatch(source);
    if (relativeZoom != null) {
      zoomLevel = (zoomLevel + double.parse(relativeZoom.group(1)!))
          .clamp(0.1, 10.0)
          .toDouble();
      return;
    }

    final absoluteZoom =
        RegExp(r'window\.setZoom\((-?\d+(?:\.\d+)?),').firstMatch(source);
    if (absoluteZoom != null) {
      zoomLevel =
          double.parse(absoluteZoom.group(1)!).clamp(0.1, 10.0).toDouble();
    }
  }

  @override
  void dispose({bool isKeepAlive = false}) {}
}
