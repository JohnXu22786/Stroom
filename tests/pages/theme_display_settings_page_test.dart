import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/theme_display_settings_page.dart';
import 'package:stroom/providers/theme_provider.dart';

void main() {
  testWidgets('theme mode options update and language displays Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith((ref) => ThemeNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: ThemeDisplaySettingsPage()),
                Consumer(
                  builder: (context, ref, _) => Text(
                    ref.watch(themeProvider).name,
                    key: const Key('selected-theme-mode'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('system'), findsOneWidget);

    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);
  });
}
