import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MermaidRenderWidget - gesture wrapper overlay', () {
    testWidgets('buildMermaidHtml with withJsGestures=true includes gesture JS',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: true);
      // Full gesture JS includes mouse handlers
      expect(html, contains('mousedown'));
      expect(html, contains('mousemove'));
      expect(html, contains('mouseup'));
      expect(html, contains('touchstart'));
      expect(html, contains('touchmove'));
      expect(html, contains('touchend'));
      // Should have zoom and pan JS functions
      expect(html, contains('window.setZoom'));
      expect(html, contains('window.setPanZoom'));
      // Auto-fit on render completion
      expect(html, contains('window.fitToViewport'));
    });

    testWidgets(
        'buildMermaidHtml with withJsGestures=false omits all gesture JS',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: false);
      // Should NOT contain mouse handlers
      expect(html, isNot(contains('mousedown')));
      expect(html, isNot(contains('mousemove')));
      expect(html, isNot(contains('mouseup')));
      // Should NOT contain touch handlers either (gesture JS omitted entirely)
      expect(html, isNot(contains('touchstart')));
      expect(html, isNot(contains('touchmove')));
      expect(html, isNot(contains('touchend')));
      // Should NOT have drag-related variables
      expect(html, isNot(contains('isDragging')));
      expect(html, isNot(contains('lastTouchDist')));
      // Should still have zoom and pan JS functions
      expect(html, contains('window.setZoom'));
      expect(html, contains('window.setPanZoom'));
    });

    testWidgets('HTML has gesture-absorbing viewport container',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('id="viewport"'));
      expect(html, contains('id="diagram-container"'));
      expect(html, contains('cursor: grab'));
      expect(html, contains('cursor: grabbing'));
      // Viewport should have overflow: hidden
      expect(html, contains('overflow: hidden'));
    });

    testWidgets(
        'HTML has window.setZoom and window.setPanZoom for external gesture control',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.setZoom'));
      expect(html, contains('window.setPanZoom'));
      // Should clamp zoom between 0.1 and 10
      expect(html, contains('Math.max(0.1, Math.min(10, level))'));
    });

    testWidgets('HTML contains mermaid initialization code', (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.initialize'));
      expect(html, contains('mermaid.run'));
      expect(html, contains('securityLevel'));
      expect(html, contains("'loose'"));
    });

    testWidgets('HTML contains viewport meta tag for mobile', (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('viewport'));
      expect(html, contains('user-scalable=no'));
    });

    testWidgets('HTML sets svg to no max dimensions', (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('max-width: none'));
      expect(html, contains('max-height: none'));
    });

    testWidgets('error handler reports to Flutter via callHandler',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('flutter_inappwebview.callHandler'));
      expect(html, contains('onMermaidError'));
      expect(html, contains('onTransformChanged'));
    });

    testWidgets('zoom is clamped between 0.1 and 10', (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('Math.max(0.1, Math.min(10, level))'));
    });

    testWidgets('full gesture JS handles pinch-to-zoom and pan',
        (tester) async {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: true);
      // Full gesture JS should handle:
      // - Mouse drag pan
      expect(html, contains('isDragging'));
      expect(html, contains('dragStartX'));
      expect(html, contains('panStartX'));
      // - Ctrl+wheel zoom
      expect(html, contains('e.ctrlKey'));
      expect(html, contains('e.metaKey'));
      expect(html, contains('e.deltaY'));
      // - Touch pan
      expect(html, contains('touchStartX'));
      expect(html, contains('touchPanStartX'));
      // - Touch pinch zoom
      expect(html, contains('lastTouchDist'));
      expect(html, contains('e.touches.length === 2'));
    });

    testWidgets('inline rendering shares the fullscreen HTML template',
        (tester) async {
      // Regression: the chat inline mermaid preview must use the SAME HTML
      // template as the fullscreen dialog (buildMermaidHtml with full
      // gesture JS), so zoom anchoring and auto-fit behavior stay unified
      // and there is only one template to maintain.
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: true);
      expect(html, contains('mousedown'));
      expect(html, contains('touchstart'));
      expect(html, contains('window.setZoom'));
      expect(html, contains('window.setPanZoom'));
      expect(html, contains('window.fitToViewport'));
    });

    testWidgets('source code mode does not use gesture wrapper',
        (tester) async {
      // In test-only source code mode (testOnlyShowSourceCode=true),
      // no WebView is created, so _buildGestureWrapper is not used.
      // The widget shows the code source view instead.
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

      // In source code mode, we should see the code view
      expect(find.text('graph TD'), findsOneWidget);
    });
  });
}
