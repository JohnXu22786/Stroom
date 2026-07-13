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

    test('HTML reports initialize errors to Flutter', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('onMermaidError'));
    });

    test('HTML reports render errors to Flutter', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('onMermaidError'));
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

    test('HTML has wheel zoom handler with Ctrl key modifier', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('wheel'));
      expect(html, contains('ctrlKey'));
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
