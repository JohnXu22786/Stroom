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
    testWidgets('renders Android tutorial correctly', (tester) async {
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

      // AppBar title
      expect(find.text('Android 后台运行教程'), findsOneWidget);
      // Header card subtitle
      expect(find.text('Android 后台运行优化指南'), findsOneWidget);
      // Tutorial section
      expect(find.text('优化步骤'), findsOneWidget);
      // Tips card
      expect(find.text('小提示'), findsOneWidget);
    });

    testWidgets('renders iOS tutorial correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
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

      // AppBar title
      expect(find.text('iOS 后台运行教程'), findsOneWidget);
      // Header card subtitle
      expect(find.text('iOS 后台运行优化指南'), findsOneWidget);
    });

    testWidgets('renders Windows tutorial correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'Windows',
        icon: Icons.desktop_windows,
        color: Colors.blue,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      // AppBar title
      expect(find.text('Windows 后台运行教程'), findsOneWidget);
      // Header card subtitle
      expect(find.text('Windows 后台运行优化指南'), findsOneWidget);
    });

    testWidgets('renders macOS tutorial correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'macOS',
        icon: Icons.desktop_mac,
        color: Colors.blueGrey,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      // AppBar title
      expect(find.text('macOS 后台运行教程'), findsOneWidget);
      // Header card subtitle
      expect(find.text('macOS 后台运行优化指南'), findsOneWidget);
    });

    testWidgets('renders Linux tutorial correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const config = PlatformTutorialConfig(
        platformName: 'Linux',
        icon: Icons.terminal,
        color: Colors.orange,
      );

      await tester.pumpWidget(_buildTestApp(config));
      await tester.pump();

      // AppBar title
      expect(find.text('Linux 后台运行教程'), findsOneWidget);
      // Header card subtitle
      expect(find.text('Linux 后台运行优化指南'), findsOneWidget);
    });

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
  });
}
