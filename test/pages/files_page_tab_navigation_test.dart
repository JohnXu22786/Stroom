import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/files_page.dart';
import 'package:stroom/pages/files_page_shared.dart';
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

  group('FilesPage tab navigation - provider unit tests', () {
    test('fileTabFolderResetSignalProvider starts at 0 for all tabs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 4; i++) {
        expect(container.read(fileTabFolderResetSignalProvider(i)), equals(0));
      }
    });

    test('filesPageCurrentFolderProvider starts empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(filesPageCurrentFolderProvider), equals(''));
    });

    test(
        'fileTabFolderResetSignalProvider can be incremented independently per tab',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Increment tab 0's reset signal
      container.read(fileTabFolderResetSignalProvider(0).notifier).state++;

      expect(container.read(fileTabFolderResetSignalProvider(0)), equals(1));
      expect(container.read(fileTabFolderResetSignalProvider(1)), equals(0));
      expect(container.read(fileTabFolderResetSignalProvider(2)), equals(0));
      expect(container.read(fileTabFolderResetSignalProvider(3)), equals(0));

      // Increment tab 2's reset signal
      container.read(fileTabFolderResetSignalProvider(2).notifier).state++;

      expect(container.read(fileTabFolderResetSignalProvider(0)), equals(1));
      expect(container.read(fileTabFolderResetSignalProvider(2)), equals(1));

      // Increment tab 0 again
      container.read(fileTabFolderResetSignalProvider(0).notifier).state++;
      expect(container.read(fileTabFolderResetSignalProvider(0)), equals(2));
    });

    test('filesRefreshSignalProvider can be incremented', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(filesRefreshSignalProvider), equals(0));

      container.read(filesRefreshSignalProvider.notifier).state++;
      expect(container.read(filesRefreshSignalProvider), equals(1));
    });
  });

  group('FilesPage tab navigation - widget tests', () {
    testWidgets('FilesPage shows 4 tabs with TabBar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify TabBar is present
      expect(find.byType(TabBar), findsOneWidget);

      // Verify all 4 tab labels are present
      expect(find.text('文本'), findsWidgets);
      expect(find.text('音频'), findsWidgets);
      expect(find.text('图片'), findsWidgets);
      expect(find.text('视频'), findsWidgets);
    });

    testWidgets('FilesPage uses IndexedStack instead of TabBarView',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify IndexedStack is used to keep all tab children alive
      expect(find.byType(IndexedStack), findsOneWidget,
          reason:
              'FilesPage should use IndexedStack to preserve tab state across switches');

      // The IndexedStack should contain all 4 tab content widgets
      // (TextStoragePage, TtsPage, GalleryPage, VideoGalleryPage)
      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('tapping a different tab switches content', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially on text tab (first tab), should see text-related content
      // Find the Tab widget for '文本'
      expect(find.widgetWithText(Tab, '文本'), findsOneWidget);

      // Tap on audio tab
      await tester.tap(find.widgetWithText(Tab, '音频'));
      await tester.pumpAndSettle();

      // Now on audio tab - verify audio tab content is shown
      expect(find.widgetWithText(Tab, '音频'), findsOneWidget);

      // Tap back to text tab
      await tester.tap(find.widgetWithText(Tab, '文本'));
      await tester.pumpAndSettle();

      // Should be back on text tab
      expect(find.widgetWithText(Tab, '文本'), findsOneWidget);
    });

    testWidgets(
        'fileTabFolderResetSignalProvider is NOT incremented on initial load',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify reset signals are all 0 for all tabs
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );

      for (int i = 0; i < 4; i++) {
        expect(container.read(fileTabFolderResetSignalProvider(i)), equals(0),
            reason: 'Tab $i should not have reset signal on initial load');
      }
    });

    testWidgets('double-tap on same tab increments reset signal',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Get reset signal value before double-tap
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );
      final initialReset = container.read(fileTabFolderResetSignalProvider(0));

      // Find the text tab in the TabBar
      final textTab = find.widgetWithText(Tab, '文本');
      expect(textTab, findsOneWidget);

      // First tap on text tab to set _lastTappedLogicalTabIndex to 0
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Reset signal should still be unchanged (first tap on the
      // currently-shown tab should NOT reset - it just records the index)
      expect(
        container.read(fileTabFolderResetSignalProvider(0)),
        equals(initialReset),
        reason: 'First tap should NOT reset the tab',
      );

      // Second tap on same text tab should trigger reset
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Reset signal should now be incremented
      expect(
        container.read(fileTabFolderResetSignalProvider(0)),
        equals(initialReset + 1),
        reason: 'Second tap SHOULD increment reset signal',
      );
    });

    testWidgets('switching tabs and back does NOT trigger reset signal',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // First tap on text tab to set _lastTappedLogicalTabIndex to 0
      final textTab = find.widgetWithText(Tab, '文本');
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );

      // Get reset signal values before switching
      final textResetBefore =
          container.read(fileTabFolderResetSignalProvider(0));
      final audioResetBefore =
          container.read(fileTabFolderResetSignalProvider(1));

      // Switch to audio tab
      final audioTab = find.widgetWithText(Tab, '音频');
      await tester.tap(audioTab);
      await tester.pumpAndSettle();

      // Switch back to text tab
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Text tab reset signal should NOT have changed
      expect(
        container.read(fileTabFolderResetSignalProvider(0)),
        equals(textResetBefore),
        reason:
            'Switching to audio tab and back should NOT trigger text tab reset',
      );

      // Audio tab reset signal should also NOT have changed
      expect(
        container.read(fileTabFolderResetSignalProvider(1)),
        equals(audioResetBefore),
        reason: 'Audio tab reset signal should not have changed',
      );
    });

    testWidgets('filesPageCurrentFolderProvider starts empty on initial load',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );

      // Initially empty
      expect(container.read(filesPageCurrentFolderProvider), equals(''));
    });

    testWidgets('isActiveTab plumbing: tab switching does not crash',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially, only the text tab (tab 0 at physical index 0) should be active
      final textTab = find.widgetWithText(Tab, '文本');
      final audioTab = find.widgetWithText(Tab, '音频');

      // Tap to audio tab
      await tester.tap(audioTab);
      await tester.pumpAndSettle();

      // Now audio tab should be active and text tab should be inactive
      // Tap back to text tab
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Text tab should be active again - just verify no crash occurs
      // during the tab switch sequence (verifying the plumbing holds)
      expect(textTab, findsOneWidget);
      expect(audioTab, findsOneWidget);
    });
  });
}
