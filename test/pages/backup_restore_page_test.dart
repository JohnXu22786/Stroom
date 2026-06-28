import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/backup_restore_page.dart';

Widget createTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: BackupRestorePage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackupRestorePage - general rendering', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Title bar
      expect(find.text('数据备份与恢复'), findsOneWidget);
    });

    testWidgets('shows backup and restore sections', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Should find section headers
      expect(find.text('导出备份'), findsAtLeast(1));
      expect(find.text('导入恢复'), findsOneWidget);
    });
  });
}
