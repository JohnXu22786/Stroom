import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/catcatch_page.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';

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

    // 验证 URL 输入框（有三个 TextFormField：URL + 分 + 秒）
    expect(find.byType(TextFormField), findsNWidgets(3));

    // 验证"开始分析"按钮
    expect(find.text('开始分析'), findsOneWidget);

    // 验证新标签
    expect(find.text('视频时长'), findsOneWidget);
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

    // 输入合法 URL + 分 + 秒
    await tester.enterText(
        find.byType(TextFormField).at(0), 'https://example.com/video.mp4');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.enterText(find.byType(TextFormField).at(2), '30');
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
    expect(find.text('分'), findsOneWidget);
    expect(find.text('秒'), findsOneWidget);
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

    // 输入合法 URL 和时长（分+秒）
    await tester.enterText(
        find.byType(TextFormField).at(0), 'https://example.com/video.mp4');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.enterText(find.byType(TextFormField).at(2), '30');
    await tester.tap(find.text('开始分析'));
    await tester.pump();

    // 验证 SnackBar 提示
    expect(find.text('任务已开始，执行过程中请勿退出应用'), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // Bilibili URL input tests
  // ──────────────────────────────────────────────
  testWidgets('CatCatchPage accepts full Bilibili URL with 70s duration',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 输入完整 B 站 URL（含长 query 参数）
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'https://www.bilibili.com/video/BV1DA5M6VE39/'
      '?buvid=XU38B3D3A445F9880897DA7B22AB0C497D0D8'
      '&from_spmid=main.later-watch.0.0'
      '&is_story_h5=false'
      '&mid=sbsPunnk%2FuOScwI%2BEkBRrg%3D%3D'
      '&p=1&plat_id=116&share_from=ugc'
      '&share_medium=android_hd&share_plat=android'
      '&share_session_id=cc88269c-2902-4a0c-809c-397752ad0dc2'
      '&share_source=COPY&share_tag=s_i'
      '&spmid=united.player-video-detail.0.0'
      '&timestamp=1778651200&unique_k=MzLhbCL&up_id=456664753',
    );

    // 输入 70 秒 (1分10秒)
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.enterText(find.byType(TextFormField).at(2), '10');
    await tester.tap(find.text('开始分析'));
    await tester.pump();

    // 不应有验证错误
    expect(find.text('请输入URL'), findsNothing);
    expect(find.text('请输入有效的URL'), findsNothing);
    expect(find.text('请输入视频时长（分和秒）'), findsNothing);

    // 应有任务开始提示
    expect(find.text('任务已开始，执行过程中请勿退出应用'), findsOneWidget);

    // 验证 Provider 状态中已创建任务
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CatCatchPage)),
    );
    final tasks = container.read(catcatchTasksProvider);
    expect(tasks.length, 1);
    expect(tasks[0].url,
        startsWith('https://www.bilibili.com/video/BV1DA5M6VE39/'));
    expect(tasks[0].expectedDurationSec, 70);
    expect(tasks[0].status, TaskStatus.running);
  });

  testWidgets(
      'CatCatchPage accepts short b23.tv Bilibili URL with 70s duration',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkSplash.splashFactory),
          home: const CatCatchPage(),
        ),
      ),
    );

    // 输入 B 站短链接
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'https://b23.tv/MzLhbCL',
    );

    // 输入 70 秒
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.enterText(find.byType(TextFormField).at(2), '10');
    await tester.tap(find.text('开始分析'));
    await tester.pump();

    // 不应有验证错误
    expect(find.text('请输入URL'), findsNothing);
    expect(find.text('请输入有效的URL'), findsNothing);
    expect(find.text('请输入视频时长（分和秒）'), findsNothing);

    // 应有任务开始提示
    expect(find.text('任务已开始，执行过程中请勿退出应用'), findsOneWidget);

    // 验证 Provider 状态中已创建任务
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CatCatchPage)),
    );
    final tasks = container.read(catcatchTasksProvider);
    expect(tasks.length, 1);
    expect(tasks[0].url, 'https://b23.tv/MzLhbCL');
    expect(tasks[0].expectedDurationSec, 70);
    expect(tasks[0].status, TaskStatus.running);
  });
}
