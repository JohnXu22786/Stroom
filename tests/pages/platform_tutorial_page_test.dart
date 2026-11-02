import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/platform_tutorial_page.dart';

void main() {
  testWidgets('lists the supported platform tutorial choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlatformTutorialSelectionPage()),
    );
    await tester.pumpAndSettle();

    for (final platform in [
      'Android',
      'iOS',
      'Windows',
      'macOS',
      'Linux',
      'Web'
    ]) {
      expect(find.text('$platform 后台运行优化教程'), findsOneWidget);
    }
  });

  testWidgets('opens the selected platform detail guide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlatformTutorialSelectionPage()),
    );
    await tester.pumpAndSettle();

    final webTutorial = find.text('Web 后台运行优化教程');
    await tester.ensureVisible(webTutorial);
    await tester.pumpAndSettle();
    await tester.tap(webTutorial);
    await tester.pumpAndSettle();

    expect(find.text('Web 后台运行教程'), findsOneWidget);
    expect(find.text('Web 后台运行优化指南'), findsOneWidget);
    expect(find.text('保持标签页打开'), findsOneWidget);
  });
}
