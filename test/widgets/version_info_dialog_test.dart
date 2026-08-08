import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/version_info_dialog.dart';

/// Helper: pumps a host app with a button that opens [VersionInfoDialog].
Future<void> _openDialog(
  WidgetTester tester, {
  String? version,
  String? releaseTime,
  String? releaseNotes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => VersionInfoDialog(
                  version: version,
                  releaseTime: releaseTime,
                  releaseNotes: releaseNotes,
                ),
              ),
              child: const Text('打开版本信息'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开版本信息'));
  await tester.pumpAndSettle();
}

void main() {
  group('VersionInfoDialog', () {
    testWidgets('shows version, release time and release notes', (tester) async {
      await _openDialog(
        tester,
        version: '1.2.3',
        releaseTime: '2026-08-08 17:30',
        releaseNotes: '第一行更新内容\n第二行更新内容',
      );

      expect(find.text('版本信息'), findsOneWidget);
      expect(find.text('版本号'), findsOneWidget);
      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.text('发布时间'), findsOneWidget);
      expect(find.text('2026-08-08 17:30'), findsOneWidget);
      expect(find.text('更新内容'), findsOneWidget);
      expect(find.text('第一行更新内容\n第二行更新内容'), findsOneWidget);
    });

    testWidgets('hides release notes section when notes are empty',
        (tester) async {
      await _openDialog(tester, version: '1.2.3');

      expect(find.text('版本信息'), findsOneWidget);
      expect(find.text('版本号'), findsOneWidget);
      expect(find.text('发布时间'), findsOneWidget);
      expect(find.text('更新内容'), findsNothing);
    });

    testWidgets('shows 本地构建 fallback when no release time was baked in',
        (tester) async {
      await _openDialog(tester, version: '1.2.3');

      expect(find.text('本地构建'), findsOneWidget);
    });

    testWidgets('closes via the 关闭 button', (tester) async {
      await _openDialog(tester, version: '1.2.3');

      expect(find.text('版本信息'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      expect(find.text('版本信息'), findsNothing);
    });
  });
}
