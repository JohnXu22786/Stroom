import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/files_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: FilesPage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('FilesPage with text storage tab', () {
    testWidgets('shows 4 tabs including text storage as first tab',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find the TabBar and verify it has 4 tabs
      final tabBar = find.byType(TabBar);
      expect(tabBar, findsOneWidget);

      // The text tab label '文本' appears (also in TextStoragePage's AppBar title)
      // so it's found at least once
      expect(find.text('文本'), findsWidgets);
    });

    testWidgets('text tab is placed before audio tab (new order)', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The tabs should be ordered: 文本, 音频, 图片, 视频
      // Check by finding the TabBar and inspecting its children
      final tabBar = find.byType(TabBar);
      final tabBarWidget = tester.widget<TabBar>(tabBar);

      expect(tabBarWidget.tabs.length, equals(4));

      // The first tab should be '文本'
      final firstTab = tabBarWidget.tabs[0] as Tab;
      expect(firstTab.text, equals('文本'));

      // The second tab should be '音频'
      final secondTab = tabBarWidget.tabs[1] as Tab;
      expect(secondTab.text, equals('音频'));

      // The third tab should be '图片'
      final thirdTab = tabBarWidget.tabs[2] as Tab;
      expect(thirdTab.text, equals('图片'));

      // The fourth tab should be '视频'
      final fourthTab = tabBarWidget.tabs[3] as Tab;
      expect(fourthTab.text, equals('视频'));
    });

    testWidgets('files page has fileTabOrderProvider with 4 items',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify the files_page key exists
      expect(find.byKey(const Key('files_page')), findsOneWidget);

      // Verify fileTabOrderProvider has 4 items
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('files_page'))),
      );
      final order = container.read(fileTabOrderProvider);
      expect(order.length, equals(4));
    });
  });
}
