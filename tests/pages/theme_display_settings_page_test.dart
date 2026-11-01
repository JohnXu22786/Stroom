import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/pages/theme_display_settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

void main() {
  testWidgets('theme mode options update and language displays Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeProvider.overrideWith((ref) => ThemeNotifier())],
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
    expect(find.text('简体中文（简体中文）'), findsOneWidget);
    expect(find.text('zh-cn'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('主题与显示'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('system'), findsOneWidget);

    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);

    final searchField = find.byKey(const Key('language-search-field'));
    await tester.enterText(searchField, '简体');
    await tester.pumpAndSettle();
    expect(find.text('简体中文（简体中文）'), findsOneWidget);

    await tester.enterText(searchField, 'ZH-CN');
    await tester.pumpAndSettle();
    expect(find.text('简体中文（简体中文）'), findsOneWidget);

    await tester.enterText(searchField, 'english');
    await tester.pumpAndSettle();
    expect(find.text('简体中文（简体中文）'), findsNothing);
    expect(find.text('没有匹配的语言'), findsOneWidget);
  });

  testWidgets('settings entry opens the titled theme and display page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith((ref) => ThemeNotifier()),
          providerEntriesProvider.overrideWith((ref) {
            final notifier = ProviderEntriesNotifier();
            notifier.load();
            return notifier;
          }),
          updateProvider.overrideWith((ref) => UpdateNotifier()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深色模式、显示语言'), findsOneWidget);
    await tester.tap(find.text('主题与显示'));
    await tester.pumpAndSettle();

    expect(find.text('主题与显示'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('简体中文（简体中文）'), findsOneWidget);
    expect(find.text('zh-cn'), findsOneWidget);
  });
}
