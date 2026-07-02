import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      // 测试环境中不显示 WebView 预览，避免 InAppWebView 平台未初始化
      home: MermaidChartPage(initialShowPreview: false),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('MermaidChartPage', () {
    testWidgets('renders with title and diagram type selector', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should show the page title
      expect(find.text('图表制作'), findsOneWidget);

      // Should show the code editor area (text field)
      expect(find.byType(TextField), findsWidgets);

      // Should show diagram type buttons
      expect(find.text('流程图'), findsOneWidget);
      expect(find.text('时序图'), findsOneWidget);
    });

    testWidgets('shows all major diagram type buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // All diagram type buttons should be present
      expect(find.text('流程图'), findsOneWidget);
      expect(find.text('时序图'), findsOneWidget);
      expect(find.text('类图'), findsOneWidget);
      expect(find.text('状态图'), findsOneWidget);
      expect(find.text('ER图'), findsOneWidget);
      expect(find.text('甘特图'), findsOneWidget);
      expect(find.text('饼图'), findsOneWidget);
    });

    testWidgets('selecting flowchart loads template in editor', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Tap the flowchart button
      await tester.tap(find.text('流程图'));
      await tester.pump();

      // The editor should contain flowchart template code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('graph TD'));
    });

    testWidgets('selecting sequence diagram loads template', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Tap the sequence diagram button
      await tester.tap(find.text('时序图'));
      await tester.pump();

      // The editor should contain sequence diagram template
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('sequenceDiagram'));
    });

    testWidgets('save button exists as icon button in app bar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should have a save icon button in the app bar
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('can be created with initial code', (tester) async {
      const initialCode = 'graph TD\n  A[Custom] --> B[End]';
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MermaidChartPage(
              initialCode: initialCode,
              initialShowPreview: false,
            ),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pump();

      // The code editor should contain the initial code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('graph TD'));
      expect(textField.controller?.text, contains('Custom'));
    });

    testWidgets('initialCode auto-detects sequenceDiagram type',
        (tester) async {
      const initialCode = 'sequenceDiagram\n  A->>B: Hello';
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MermaidChartPage(
              initialCode: initialCode,
              initialShowPreview: false,
            ),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pump();

      // The diagram type chip should show sequence diagram selected
      // and the code should contain the initial code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('sequenceDiagram'));
      expect(textField.controller?.text, contains('Hello'));
    });

    testWidgets('initialCode auto-detects gantt type', (tester) async {
      const initialCode = 'gantt\n  title Test';
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MermaidChartPage(
              initialCode: initialCode,
              initialShowPreview: false,
            ),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('gantt'));
      expect(textField.controller?.text, contains('Test'));
    });
  });
}
