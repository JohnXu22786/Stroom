import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/startup_page.dart';
import 'package:stroom/startup/startup_visual_style.dart';

/// Helper to create a standalone StartupPage for focused widget testing.
Widget wrapStartupPage({
  bool isWorking = true,
  String statusMessage = '',
  String? progressDetail,
  StartupVisualStyle? visualStyle,
}) {
  return MaterialApp(
    home: StartupPage(
      isWorking: isWorking,
      statusMessage: statusMessage,
      progressDetail: progressDetail,
      visualStyle: visualStyle,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'data_format_version': 1,
    });
  });

  group('StartupPage - splash UI', () {
    testWidgets('shows loading indicator when working', (tester) async {
      await tester.pumpWidget(wrapStartupPage(isWorking: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows check icon when done', (tester) async {
      await tester.pumpWidget(wrapStartupPage(isWorking: false));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows status message when provided', (tester) async {
      await tester.pumpWidget(wrapStartupPage(
        statusMessage: '正在检查数据格式...',
      ));
      await tester.pump();

      expect(find.text('正在检查数据格式...'), findsOneWidget);
    });

    testWidgets('shows progress detail when provided', (tester) async {
      await tester.pumpWidget(wrapStartupPage(
        statusMessage: '正在检查',
        progressDetail: '1/3',
      ));
      await tester.pump();

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('uses Mint Glass as the default launch style', (tester) async {
      await tester.pumpWidget(wrapStartupPage());
      await tester.pump();

      expect(find.byIcon(StartupVisualStyle.mintGlass.icon), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        StartupVisualStyle.mintGlass.palette.first,
      );
    });

    testWidgets('long status message does not overflow the layout',
        (tester) async {
      // 启动检查发现多个问题时状态文案会非常长（所有问题拼接），
      // 必须在受限高度内滚动而不是触发 RenderFlex overflow。
      final longMessage = '启动完成（注意: 发现 3 个数据问题:\n'
          '  • provider_entries[0]: id 字段缺失或为空\n'
          '  • provider_entries[1]: type 字段缺失或为空\n'
          '  • conversations[2]: messages 字段缺失\n'
          '  • conversations[3]: id 字段缺失）';
      await tester.pumpWidget(wrapStartupPage(statusMessage: longMessage));
      await tester.pump();

      expect(find.text(longMessage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '长状态文案必须可滚动而非溢出报错');
    });

    testWidgets('all concepts fit a compact landscape viewport',
        (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final style in StartupVisualStyle.values) {
        await tester.pumpWidget(wrapStartupPage(
          statusMessage: '正在准备你的学习空间',
          progressDetail: '1/4',
          visualStyle: style,
        ));
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: '${style.title} should fit a short landscape screen',
        );
      }
    });
  });
}
