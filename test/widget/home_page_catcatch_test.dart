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

    // 桌面端 NavigationRail 中有加号图标
    expect(find.byIcon(Icons.add), findsAtLeast(1));
    await tester.tap(find.byIcon(Icons.add).first);
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
  testWidgets('Home page has task list icon in top right with pending_actions icon',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    // 找任务列表图标 (改用 Icons.pending_actions)
    expect(find.byIcon(Icons.pending_actions), findsOneWidget);
  });

  // ──────────────────────────────────────────────
  // Plus icon in navigation
  // ──────────────────────────────────────────────
  testWidgets('Home page has add icon in navigation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    // 桌面端 NavigationRail 中有加号图标
    expect(find.byIcon(Icons.add), findsAtLeast(1));
  });
}
