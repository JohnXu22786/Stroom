import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('web asset URL keeps ?v= and &code= in one query string', () {
      // Regression: the URL previously became "...?v=4?code=..." (two '?'),
      // so URLSearchParams could not find the code and the template showed
      // the empty-code placeholder instead of the diagram.
      final url = MermaidRenderWidget.buildWebAssetUrl('graph TD\nA-->B');
      expect(url, contains('mermaid_render.html?v=4&code='));
      expect(url, isNot(contains('?code')));
      expect(url, isNot(contains('v=4?')));
      // The code must be percent-encoded inside the query string.
      expect(url, contains('graph+TD'));
      // Empty code -> version parameter only, no dangling '&'.
      final empty = MermaidRenderWidget.buildWebAssetUrl('   ');
      expect(empty, '${MermaidRenderWidget.webAssetTemplateUrl}?v=4');
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

    test('HTML includes window.setPanZoom for Flutter-driven pan/zoom', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.setPanZoom = function(x, y, level)'),
          reason:
              'the inline widget drives pan/zoom from Flutter via setPanZoom');
    });

    test('HTML includes fitToViewport for auto-fit after render', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.fitToViewport'));
    });

    test('fitToViewport is called after mermaid.run completes', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // The fit must be wired into the mermaid.run success path.
      final runIdx = html.indexOf('mermaid.run');
      final fitCallIdx = html.indexOf('fitToViewport()');
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
      // mouse-drag pan, touch pan. This pins the notify calls to the
      // pan handlers (not just to the zoom/fit paths).
      expect('notifyTransform();'.allMatches(html).length, 4);
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
      expect(html, contains('wheel'));
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
      expect(html, contains('wheel'),
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
      expect(html, isNot(contains('wheel')),
          reason: 'should omit wheel zoom handler');
      expect(html, isNot(contains('touchstart')),
          reason: 'should omit touch handlers');
      // Core mermaid rendering should still be present
      expect(html, contains('mermaid.initialize'));
      expect(html, contains('mermaid.run'));
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
  });
}
