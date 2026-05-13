import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/catcatch_page.dart';

void main() {
  // ──────────────────────────────────────────────
  // Basic UI structure
  // ──────────────────────────────────────────────
  testWidgets('CatCatchPage has input fields and analyze button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // Explicit InkSplash avoids the InkSparkle shader asset error in test mode
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 验证页面标题
    expect(find.text('获取网页视频'), findsOneWidget);

    // 验证 URL 输入框（有两个 TextFormField：URL + 时长）
    expect(find.byType(TextFormField), findsNWidgets(2));

    // 验证"开始分析"按钮
    expect(find.text('开始分析'), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // Input validation
  // ──────────────────────────────────────────────
  testWidgets('CatCatchPage input validation - empty URL', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 点击"开始分析"（输入为空，应显示验证错误）
    await tester.tap(find.text('开始分析'));
    await tester.pump();

    // 验证错误提示
    expect(find.text('请输入URL'), findsOneWidget);
  });

  testWidgets('CatCatchPage input validation - invalid URL', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 输入无效 URL
    await tester.enterText(find.byType(TextFormField).first, 'not-a-url');
    await tester.tap(find.text('开始分析'));
    await tester.pump();

    // 验证无效 URL 错误提示
    expect(find.text('请输入有效的URL'), findsOneWidget);
  });

  testWidgets('CatCatchPage form validates duration field type',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 输入合法 URL + 时长
    await tester.enterText(
        find.byType(TextFormField).first, 'https://example.com/video.mp4');
    await tester.enterText(find.byType(TextFormField).last, '30');
    await tester.tap(find.text('开始分析'));

    // 不出现验证错误（表单应通过校验）
    await tester.pump();
    expect(find.text('请输入URL'), findsNothing);
    expect(find.text('请输入有效的URL'), findsNothing);
  });

  // ──────────────────────────────────────────────
  // Empty state
  // ──────────────────────────────────────────────
  testWidgets('CatCatchPage shows empty state initially', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 验证空状态提示
    expect(find.text('暂无任务'), findsOneWidget);
    expect(find.text('在上方输入URL开始分析网页中的媒体资源'), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // Input field hints
  // ──────────────────────────────────────────────
  testWidgets('CatCatchPage input fields have correct hints', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 验证输入框 hint
    expect(find.text('请输入视频/音频网页URL'), findsOneWidget);
    expect(find.text('期望时长（秒）'), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // SnackBar appeared after starting task
  // ──────────────────────────────────────────────
  testWidgets('CatCatchPage shows snackbar after starting a task',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 输入合法 URL 和时长
    await tester.enterText(
        find.byType(TextFormField).first, 'https://example.com/video.mp4');
    await tester.enterText(find.byType(TextFormField).last, '30');
    await tester.tap(find.text('开始分析'));
    await tester.pump();

    // 验证 SnackBar 提示
    expect(find.text('任务已开始，执行过程中请勿退出应用'), findsOneWidget);
  });
}
