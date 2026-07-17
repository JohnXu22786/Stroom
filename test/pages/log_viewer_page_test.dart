import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/log_viewer_page.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
    AppLogService.enableFileLogging();
  });

  // ==================================================================
  // Widget structure tests (no file I/O needed)
  // ==================================================================
  //
  // LogViewerPage calls AppLogService._loadLogFiles() in initState,
  // which uses real file I/O. In testWidgets' fake async zone, file
  // I/O futures never complete, so _loadLogFiles hangs. These tests
  // verify widget structure without depending on async completion.

  group('LogViewerPage — widget structure', () {
    testWidgets('shows AppBar with title 应用日志', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      expect(find.text('应用日志'), findsOneWidget);
    });

    testWidgets('contains refresh button in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('contains cleanup old logs button in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('shows loading indicator while fetching logs', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      // _loadLogFiles starts with synchronous setState to show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
