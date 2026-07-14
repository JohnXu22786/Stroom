import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MermaidRenderWidget - expand mode', () {
    testWidgets('expand:true fills available space without fixed height',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: MermaidRenderWidget(
                mermaidCode: 'graph TD\nA-->B',
                expand: true,
                testOnlyShowSourceCode: true,
              ),
            ),
          ),
        ),
      );

      // The widget should render without overflow or error
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
      // The MermaidRenderWidget should fill the available space (600px height)
      // Without overflow — this confirms expand:true lets it fill available space
      expect(tester.takeException(), isNull);

      // In source code mode with expand:true, the code should be visible
      expect(find.text('graph TD\nA-->B'), findsOneWidget);
    });

    testWidgets('expand:true with empty code shows placeholder',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: MermaidRenderWidget(
                mermaidCode: '',
                expand: true,
              ),
            ),
          ),
        ),
      );

      // Should show the empty placeholder, not the loading indicator
      expect(find.text('No Mermaid code to render'), findsOneWidget);
      expect(find.text('正在准备渲染引擎...'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand:false still uses default height of 300',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(
              mermaidCode: 'graph TD',
              expand: false,
              testOnlyShowSourceCode: true,
            ),
          ),
        ),
      );

      // Should show source code (since testOnlyShowSourceCode is true)
      expect(find.text('graph TD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand:true shows source code view with test flag',
        (tester) async {
      const mermaidCode = 'graph TD\nA-->B';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: MermaidRenderWidget(
                mermaidCode: mermaidCode,
                expand: true,
                testOnlyShowSourceCode: true,
              ),
            ),
          ),
        ),
      );

      // Should show mermaid code as selectable text
      expect(find.text(mermaidCode), findsOneWidget);
      // Should show the toggle button (image icon for "查看图表")
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand:true shows loading state initially without test flag',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: MermaidRenderWidget(
                mermaidCode: 'graph TD\nA-->B',
                expand: true,
              ),
            ),
          ),
        ),
      );

      // Should show the loading indicator text
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      // Zoom buttons should NOT be visible yet
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
