import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/platform_tutorial_page.dart';

Widget _buildTestApp(PlatformTutorialConfig config) {
  return ProviderScope(
    child: MaterialApp(
      home: PlatformTutorialPage(config: config),
    ),
  );
}

void main() {
  group('PlatformTutorialPage - rendering', () {
    testWidgets('tutorial page contains tutorial steps and tips',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'Android',
        icon: Icons.android,
        color: Colors.green,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      // Should show the section header
      expect(find.text('优化步骤'), findsOneWidget);
      // Should show the tips card header
      expect(find.text('小提示'), findsOneWidget);
      // Should show at least one step title (e.g. first Android step)
      expect(find.text('关闭电池优化'), findsOneWidget);
    });

    testWidgets('Android tutorial covers ROM-specific keep-alive settings',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'Android',
        icon: Icons.android,
        color: Colors.green,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      // Android 13+ notification permission step
      expect(find.text('允许通知权限（Android 13+）'), findsOneWidget);
      // Chinese ROM (MIUI/EMUI/ColorOS/OriginOS) autostart step
      expect(find.text('国产系统自启动与后台管理'), findsOneWidget);
      // Lock-screen cleanup step
      expect(find.text('关闭锁屏清理与省电模式'), findsOneWidget);
    });

    testWidgets('iOS tutorial explains platform background limits',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'iOS',
        icon: Icons.phone_iphone,
        color: Colors.grey,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      // Honest limitation step
      expect(find.text('理解 iOS 的后台运行限制'), findsOneWidget);
      // Resident-background + old-iOS return-period tips step
      expect(find.text('任务运行时的后台注意事项'), findsOneWidget);
      expect(find.textContaining('请勿在 App 切换器中划掉'), findsOneWidget);
    });

    testWidgets('desktop tutorials cover the minimize-on-close keep-alive',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final platform in ['Windows', 'macOS', 'Linux']) {
        final config = PlatformTutorialConfig(
          platformName: platform,
          icon: Icons.desktop_windows,
          color: Colors.blue,
        );
        await tester.pumpWidget(_buildTestApp(config));
        await tester.pump();
        expect(find.text('关闭窗口时最小化'), findsOneWidget,
            reason: '$platform 教程应包含关闭窗口=最小化保活说明');
        expect(find.textContaining('完全退出应用'), findsOneWidget,
            reason: '$platform 教程应说明完全退出按钮');
      }
    });

    testWidgets(
        'Web tutorial covers keeping the tab open and browser throttling',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'Web',
        icon: Icons.language,
        color: Colors.purple,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      expect(find.text('保持标签页打开'), findsOneWidget);
      expect(find.text('避免浏览器挂起标签页'), findsOneWidget);
    });
  });
}
