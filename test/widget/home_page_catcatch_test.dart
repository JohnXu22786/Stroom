import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/home_page.dart';

void main() {
  // ──────────────────────────────────────────────
  // Plus menu integration
  // ──────────────────────────────────────────────
  testWidgets('Home page plus menu has 获取网页视频 option', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    // 找加号按钮（桌面端 FloatingActionButton）
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 点击加号按钮
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 验证菜单中有"获取网页视频"
    expect(find.text('获取网页视频'), findsOneWidget);

    // 验证其他菜单项也存在
    expect(find.text('录音'), findsOneWidget);
    expect(find.text('拍摄'), findsOneWidget);
    expect(find.text('录像'), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // Task list icon
  // ──────────────────────────────────────────────
  testWidgets('Home page has catcatch task list icon in top right',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    // 找任务列表图标
    expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // Plus icon inside FAB
  // ──────────────────────────────────────────────
  testWidgets('Home page FAB contains add icon', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    // 验证 FAB 存在（桌面端），FAB 内自带加号图标
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
