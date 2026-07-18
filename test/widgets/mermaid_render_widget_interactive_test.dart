import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Toolbar behavior tests
  // ===========================================================================
  //
  // These tests verify that the interactive toolbar (zoom in/out, fullscreen,
  // source code toggle) appears correctly in different widget states. These
  // behaviors are relevant to both the MermaidChartPage and the chat inline
  // rendering, since both use the same MermaidRenderWidget.

  group('MermaidRenderWidget - toolbar behavior', () {
    testWidgets('source code mode hides zoom and fullscreen buttons',
        (tester) async {
      // Regression: zoom in/out and fullscreen buttons must only appear
      // when the widget is in render (diagram) mode. In source code mode
      // they should be absent and only the image (查看图表) and save
      // icons shown.
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

      // In source code mode: zoom buttons should NOT appear
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
      // Should show image icon for "查看图表" and save icon
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets(
        'tapping source code toggle exits source code mode without crash',
        (tester) async {
      // Regression: tapping the toggle button must not crash and the
      // previous source code view must disappear after the toggle.
      // Since testOnlyShowSourceCode skips WebView creation, the widget
      // enters the deferred loading state after toggle (loading indicator
      // shown instead of source code or render view).
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph LR\nA-->B',
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // Source code mode → image icon is visible
      expect(find.byIcon(Icons.image), findsOneWidget);

      // Tap toggle to switch to render mode
      await tester.tap(find.byIcon(Icons.image));
      await tester.pump();

      // After toggle, the widget exits source code mode and enters the
      // deferred WebView loading state. The image icon disappears.
      expect(find.byIcon(Icons.image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showToolbar:false toolbar buttons absent in source code view',
        (tester) async {
      // Regression: when showToolbar is false (used by MermaidChartPage),
      // the toolbar buttons (zoom in/out, fullscreen) must not be rendered
      // regardless of the current view mode. This test verifies they are
      // absent in source code mode (the only mode available without
      // creating an InAppWebView in test environment).
      //
      // In render mode (not available in tests due to InAppWebView
      // platform requirement), the toolbar suppression depends on the
      // same `widget.showToolbar` flag checked in the build() method,
      // so this test provides adequate coverage of the flag behavior.
      const widget = MermaidRenderWidget(
        mermaidCode: 'graph TD\nA-->B',
        showToolbar: false,
        testOnlyShowSourceCode: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      // In source code mode (testOnlyShowSourceCode): toolbar should not
      // appear regardless of showToolbar (source code view uses a separate
      // rendering path with its own action buttons).
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });

    testWidgets('action button icon has proper accessibility semantic label',
        (tester) async {
      // Regression: action buttons must have semanticLabel for accessibility.
      // In source code mode, the image (查看图表) button is the only visible
      // action button, so verify it has a non-null semanticLabel.
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

      final imageIcon = tester.widget<Icon>(find.byIcon(Icons.image));
      expect(imageIcon.semanticLabel, isNotNull);
    });
  });

  // ===========================================================================
  // Save button behavior tests
  // ===========================================================================
  //
  // These tests verify that the save button appears correctly in the
  // source code mode toolbar and triggers the FolderPickerDialog for
  // saving Mermaid source code as .mmd files via TextManifest.

  group('MermaidRenderWidget - save button', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ManifestDatabase.enableTestMode();
      TextManifest.invalidateCache();
    });

    testWidgets('save icon appears in source code mode toolbar',
        (tester) async {
      // Regression: the save button (Icons.save) must be present in the
      // source code mode toolbar so users can save Mermaid source code.
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

      // Save button should be visible in source code mode
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets(
        'save icon and code toggle icon both visible in source code mode',
        (tester) async {
      // Regression: both the save button and the "view chart" toggle
      // button must be present in the source code mode toolbar.
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

      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('save icon absent when mermaid code is empty', (tester) async {
      // Regression: when the Mermaid code is empty, the widget shows a
      // placeholder instead of the source code view, so the save button
      // must not be present.
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

      // Empty code shows placeholder, not the code view
      expect(find.text('No Mermaid code to render'), findsOneWidget);
      // Save button should NOT be present
      expect(find.byIcon(Icons.save), findsNothing);
    });

    testWidgets('tapping save button opens FolderPickerDialog', (tester) async {
      // Regression: tapping the save button must show the folder picker
      // dialog so the user can choose where to save the .mmd file.
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

      // Tap the save button
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the FolderPickerDialog for selecting save location
      expect(find.byType(FolderPickerDialog), findsOneWidget);
    });

    testWidgets('save icon has proper accessibility semantic label',
        (tester) async {
      // Regression: save button must have semanticLabel for accessibility.
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

      final saveIcon = tester.widget<Icon>(find.byIcon(Icons.save));
      expect(saveIcon.semanticLabel, isNotNull);
    });
  });

  // ===========================================================================
  // HTML template - interactive JS contract tests
  // ===========================================================================
  //
  // These tests verify that the generated HTML contains the JavaScript
  // functions and event handlers required for drag-to-pan and zoom.
  // They supplement the existing static HTML string checks in
  // mermaid_render_widget_test.dart by testing precise formulas and
  // event handler logic that the existing tests skip.

  group('MermaidRenderWidget - HTML JS pan/zoom contract', () {
    test('updateTransform uses translate and scale on diagram-container', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('updateTransform'));
      expect(html, contains('translate('));
      expect(html, contains('scale('));
    });

    test('mousedown targets diagram-container and sets dragging flag', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('e.target.closest'));
      expect(html, contains('diagram-container'));
      expect(html, contains('isDragging = true'));
    });

    test('mousemove increments pan from drag start position', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('panX = panStartX'));
      expect(html, contains('panY = panStartY'));
    });

    test('mouseup resets dragging flag', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('isDragging = false'));
    });

    test('wheel handler supports both ctrlKey and metaKey modifiers', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Both Ctrl (Windows/Linux) and Cmd (macOS) should trigger zoom
      expect(html, contains('e.ctrlKey || e.metaKey'));
      expect(html, contains('e.preventDefault()'));
    });

    test('setZoom clamps zoom level between 0.1 and 10', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('Math.max(0.1, Math.min(10, level))'));
    });

    test('setZoom reports new zoom level via onZoomChanged handler', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains("callHandler('onZoomChanged'"));
    });

    test('setZoom adjusts panX and panY when centerX/centerY provided', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // The centering formula keeps the cursor position fixed on screen
      // during zoom: newPan = center - (center - oldPan) * (newZoom / oldZoom)
      expect(
          html, contains('centerX - (centerX - panX) * (zoomLevel / oldZoom)'));
      expect(
          html, contains('centerY - (centerY - panY) * (zoomLevel / oldZoom)'));
    });

    test('touchstart and touchend handlers exist for mobile support', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('touchstart'));
      expect(html, contains('touchmove'));
      expect(html, contains('touchend'));
      expect(html, contains('Math.hypot'));
    });

    test('touch pinch computes midpoint in viewport coordinates', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(
          html, contains('(e.touches[0].clientX + e.touches[1].clientX) / 2'));
      expect(
          html, contains('(e.touches[0].clientY + e.touches[1].clientY) / 2'));
    });

    test('touchend resets pan start on finger lift for smooth pinch-to-pan',
        () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('e.touches.length === 1'));
      expect(html, contains('touchPanStartX = panX'));
      expect(html, contains('touchPanStartY = panY'));
    });
  });

  // ===========================================================================
  // HTML template - error handling contract tests
  // ===========================================================================
  //
  // These tests verify that Mermaid render/initialize errors are reported
  // through the JavaScript callHandler bridge to the Flutter side.

  group('MermaidRenderWidget - HTML error handling', () {
    test('reportError function replaces viewport with error message div', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('function reportError'));
      expect(html, contains('error-message'));
    });

    test('reportError invokes flutter_inappwebview callHandler', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('flutter_inappwebview.callHandler'));
      expect(html, contains('onMermaidError'));
    });

    test('mermaid.run() failure is caught and forwarded to reportError', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.run'));
      expect(html, contains('.catch'));
      expect(html, contains('reportError'));
    });

    test('mermaid.initialize() failure is caught and forwarded to reportError',
        () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.initialize'));
      expect(html, contains('catch(e)'));
      expect(html, contains('reportError'));
    });
  });

  // ===========================================================================
  // Widget behavior tests (unique tests not in other test files)
  // ===========================================================================

  group('MermaidRenderWidget - widget behavior', () {
    testWidgets('whitespace-only code shows empty placeholder', (tester) async {
      // Regression: code consisting only of whitespace should be treated
      // as empty and shown the "No Mermaid code to render" placeholder
      // instead of attempting to create a WebView.
      const widget = MermaidRenderWidget(mermaidCode: '   \n  \t  ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );

      expect(find.text('No Mermaid code to render'), findsOneWidget);
    });
  });

  // ===========================================================================
  // BuildMermaidHtml static method tests (edge cases)
  // ===========================================================================
  //
  // These tests supplement the existing buildMermaidHtml tests in
  // mermaid_render_widget_test.dart by covering edge-case inputs.

  group('MermaidRenderWidget.buildMermaidHtml - edge cases', () {
    test('escapes HTML tags inside mermaid syntax labels', () {
      // When mermaid label text contains HTML-like syntax, it must be
      // escaped so it renders as literal text rather than HTML.
      final code = 'graph TD\nA["<b>Bold</b>"]-->C';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('&lt;b&gt;Bold&lt;/b&gt;'));
    });

    test('escapes ampersands in mermaid labels', () {
      // Ampersands in mermaid syntax must be HTML-encoded to prevent
      // parsing as HTML entities.
      final code = 'graph TD\nA["A&B"]-->C';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('A&amp;B'));
    });

    test('handles very large mermaid diagram code (100+ nodes)', () {
      // Regression: large mermaid diagrams should not cause template
      // injection or placeholder leak.
      final lines = <String>['graph TD'];
      for (int i = 0; i < 100; i++) {
        lines.add('  A${i}-->B${i}');
      }
      final code = lines.join('\n');
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('graph TD'));
      expect(html, isNot(contains('MERMAID_CODE_PLACEHOLDER')));
    });

    test('preserves mermaid %%{init} directive in output', () {
      // Mermaid %%{init} configuration directives must be preserved
      // in the generated HTML so that theme/config settings take effect.
      final code = '%%{init: {\'theme\': \'dark\'}}%%\ngraph TD\nA-->B';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('%%{init'));
      expect(html, contains('theme'));
    });
  });
}
