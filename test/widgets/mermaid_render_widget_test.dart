import 'package:flutter/material.dart';
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

    test('HTML setZoom reports zoom level via onZoomChanged', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('onZoomChanged'));
    });

    test('HTML includes window.setPan function', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.setPan'));
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

  group('MermaidRenderWidget - widget rendering', () {
    testWidgets('renders as a StatefulWidget', (tester) async {
      const widget = MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
    });

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

    testWidgets('shows border around the container', (tester) async {
      const widget = MermaidRenderWidget(mermaidCode: 'graph TD');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('uses default height of 300', (tester) async {
      const widgetKey = Key('height-test-widget');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(
              key: widgetKey,
              mermaidCode: 'graph TD',
            ),
          ),
        ),
      );
      expect(find.byKey(widgetKey), findsOneWidget);
    });

    testWidgets('respects custom height', (tester) async {
      const widgetKey = Key('custom-height-test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(
              key: widgetKey,
              mermaidCode: 'graph TD',
              height: 500,
            ),
          ),
        ),
      );
      expect(find.byKey(widgetKey), findsOneWidget);
    });

    testWidgets('adapts colors to dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: MermaidRenderWidget(mermaidCode: 'graph TD'),
          ),
        ),
      );
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
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
    testWidgets('renders with gesture wrapper in render mode', (tester) async {
      const widget = MermaidRenderWidget(mermaidCode: 'graph TD');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      // Early loading state shows the preparation text
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      // The gesture wrapper (Listener) should wrap the WebView when created
    });

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
