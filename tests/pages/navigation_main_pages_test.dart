import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

/// A GlobalKey for the outer [Navigator] so tests can trigger [Navigator.maybePop]
/// to simulate the Android system back button, which is intercepted by [PopScope]
/// in [HomePage].
final _navigatorKey = GlobalKey<NavigatorState>();

/// Build a test app that wraps [HomePage] inside a [Navigator] route, so that
/// the system back button (simulated via [_navigatorKey]) triggers [PopScope].
/// When [assistants] is given, [assistantProvider] is overridden with those
/// assistants so the chat tab's assistant selection page has entries to tap.
Widget _buildTestApp({Size? screenSize, List<Assistant>? assistants}) {
  final app = ProviderScope(
    overrides: [
      if (assistants != null)
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          for (final a in assistants) {
            notifier.createAssistant(
              name: a.name,
              prompt: a.prompt,
              emoji: a.emoji,
              description: a.description,
            );
          }
          return notifier;
        }),
    ],
    child: MaterialApp(
      home: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => const HomePage(),
            settings: settings,
          );
        },
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
  if (screenSize != null) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: app,
    );
  }
  return app;
}

/// Helper: simulate the system back button by calling [Navigator.maybePop].
Future<void> _simulateBackButton(WidgetTester tester) async {
  await _navigatorKey.currentState?.maybePop();
  await tester.pumpAndSettle();
}

/// Find a bottom NavigationBar destination by its label. Scoped to the
/// NavigationBar so page content carrying the same text (e.g. the chat
/// page's "设置" API-config button) cannot make taps ambiguous.
Finder _navTab(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('Main page navigation (4 buttons, state preservation)', () {
    testWidgets(
        'renders four nav destinations on portrait screens, no plus button',
        (tester) async {
      // Use a portrait size (height > width) so the bottom nav bar is shown
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Bottom nav bar should contain exactly the 4 main destinations
      expect(find.text('主页'), findsOneWidget);
      expect(find.text('对话'), findsOneWidget);
      expect(find.text('文件'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      // No plus button should exist
      expect(find.byIcon(Icons.add), findsNothing);

      // Home page content should be visible by default
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('tapping nav bar items switches pages', (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Default: home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Tap "文件" in nav bar to go to Files page
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();

      // Should see Files page content
      expect(find.text('文件'), findsWidgets);

      // Tap "设置" in nav bar to go to Settings page
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Should see Settings page content
      expect(find.text('设置'), findsWidgets);

      // Tap "主页" in nav bar to go back to Home
      await tester.tap(find.text('主页'));
      await tester.pumpAndSettle();

      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('horizontal swipe does NOT change main page', (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Verify we start on home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Attempt to swipe left (which would normally go to Chat page with PageView)
      await tester.drag(
        find.byType(HomePage),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Should still be on home page — swipe had no effect
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Try a fast fling left
      await tester.fling(
        find.byType(HomePage),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // Should still be on home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Try swiping right too
      await tester.fling(
        find.byType(HomePage),
        const Offset(500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // Should still be on home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('back from Files page returns to Home', (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Navigate to Files via nav bar
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();

      // Verify on Files page
      expect(find.text('文件'), findsWidgets);

      // Simulate system back
      await _simulateBackButton(tester);

      // Should return to Home
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('back from Settings page returns to Home', (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Navigate to Settings via nav bar
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Simulate system back
      await _simulateBackButton(tester);

      // Should return to Home
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('back from Home page does not pop the app (stays on Home)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // We're on home page with empty history
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Simulate system back — should NOT pop the route
      await _simulateBackButton(tester);

      // Should still be on home page (not popped)
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // HomePage should still be displayed (the outer navigator did not pop it)
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('hierarchical back: Home→Chat→Files→Back→Home, not Chat',
        (tester) async {
      // The back button should navigate to the parent page (Home),
      // not the previously visited tab (Chat).
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Start on Home
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Go to Chat
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // Go to Files
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.text('文件'), findsWidgets);

      // Press back — should go to Home (parent), NOT Chat (previous step)
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('hierarchical back: Home→Chat→Files→Settings→Back→Home',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Go through multiple tabs
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsWidgets);

      // Press back — should go to Home (parent), not Files (previous step)
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets(
        'double-tap Chat tab stays on assistant selection (already at home)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // First tap: go to Chat
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // Second tap on same Chat tab: stay at assistant selection (already at home)
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets(
        'back from assistant selection root returns to Home (no phantom '
        'pop, no duplicate assistant-selection route)', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        screenSize: const Size(390, 844),
        assistants: [
          Assistant(
            name: '助手根',
            prompt: 'P1',
            emoji: '🤖',
            description: '根路由助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Enter chat tab: assistant selection page (root of the nested
      // navigator)
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // System back at the chat tab root must leave the chat tab and
      // return to Home — not replay a pop animation on the assistant
      // selection page.
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
      expect(find.text('选择助手'), findsNothing);
    });

    testWidgets(
        'back at assistant selection after returning from the chat page '
        'goes Home, not a second assistant-selection pop', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        screenSize: const Size(390, 844),
        assistants: [
          Assistant(
            name: '助手深',
            prompt: 'P1',
            emoji: '🤖',
            description: '深流程助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Drill down: assistant selection → topic selection → chat page
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('助手深'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);

      final newTopicButtons = find.widgetWithText(FilledButton, '新话题');
      await tester.tap(newTopicButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('新对话'), findsWidgets);

      // Back from chat page → topic selection
      await _simulateBackButton(tester);
      expect(find.text('选择对话'), findsOneWidget);

      // Back from topic selection → assistant selection (nested root)
      await _simulateBackButton(tester);
      expect(find.text('选择助手'), findsOneWidget);

      // Back from assistant selection root → Home page
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
      expect(find.text('选择助手'), findsNothing);
    });

    testWidgets(
        'double-tap chat tab at assistant selection root does not leave '
        'a duplicate route behind', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        screenSize: const Size(390, 844),
        assistants: [
          Assistant(
            name: '助手双',
            prompt: 'P1',
            emoji: '🤖',
            description: '双击助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Enter chat tab. The nested navigator must have exactly ONE
      // assistant-selection route: the framework's default initial-route
      // generation would also push a '/' ancestor route that renders as a
      // phantom duplicate assistant-selection page (visible offstage).
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手', skipOffstage: false), findsOneWidget,
          reason: 'chat tab must have a single root route — a phantom '
              'duplicate assistant-selection page would make back '
              'navigation replay a pop animation and stay on the page');

      // Double-tap the chat tab while already at the root: this must be a
      // no-op (reset to root that is already the root), not a pop that
      // reveals a phantom duplicate.
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);
      expect(find.text('选择助手', skipOffstage: false), findsOneWidget,
          reason: 'double-tap at the root must not pop to a phantom '
              'duplicate route');

      // The stack is at the single root: system back leaves for Home.
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
      expect(find.text('选择助手'), findsNothing);
    });

    testWidgets('chat state preserved when switching away and back',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Enter chat page
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // Switch to files
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.text('文件'), findsWidgets);

      // Switch back to chat - should still show assistant selection (state preserved)
      // Since we never navigated deeper into chat, it should still show assistant selection
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets(
        'chat tab keeps topic selection page after switching away and back',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        screenSize: const Size(390, 844),
        assistants: [
          Assistant(
            name: '助手甲',
            prompt: 'P1',
            emoji: '🤖',
            description: '第一个助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Enter chat tab and drill down to topic selection
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      await tester.tap(find.text('助手甲'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);

      // Switch to files — the chat navigator stack must stay alive (hidden)
      await tester.tap(_navTab('文件'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('files_page')), findsOneWidget);
      // The chat navigator stack must stay alive (hidden) — IndexedStack
      // keeps non-selected pages in the tree, so search includes offstage.
      expect(find.text('选择对话', skipOffstage: false), findsOneWidget,
          reason: 'chat navigator stack must not be torn down when '
              'switching to another main page');

      // Switch back — should return to topic selection, not assistant selection
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);
      expect(find.text('选择助手'), findsNothing);
    });

    testWidgets(
        'double-tap chat tab from topic selection resets to assistant selection',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        screenSize: const Size(390, 844),
        assistants: [
          Assistant(
            name: '助手丙',
            prompt: 'P1',
            emoji: '🤖',
            description: '第三个助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Drill down to topic selection
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('助手丙'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);

      // Re-tap the chat tab while already on it → reset to assistant selection
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);
      // The topic selection route must be gone entirely (popped, not hidden)
      expect(find.text('选择对话', skipOffstage: false), findsNothing);
    });

    testWidgets(
        'chat tab keeps the open chat page after switching away and back',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        screenSize: const Size(390, 844),
        assistants: [
          Assistant(
            name: '助手乙',
            prompt: 'P1',
            emoji: '🤖',
            description: '第二个助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Enter chat tab and drill down to the chat page
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      await tester.tap(find.text('助手乙'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);

      final newTopicButtons = find.widgetWithText(FilledButton, '新话题');
      await tester.tap(newTopicButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // Chat page entry must not throw (bare takeException would mask it).
      expect(tester.takeException(), isNull,
          reason: 'entering the chat page must not throw');
      expect(find.text('新对话'), findsWidgets);

      // Switch to settings — the chat page must stay alive (hidden)
      await tester.tap(_navTab('设置'));
      await tester.pumpAndSettle();
      expect(find.text('新对话', skipOffstage: false), findsWidgets,
          reason: 'open chat page must not be torn down when switching '
              'to another main page');

      // Switch back — should still be on the chat page, not assistant selection
      await tester.tap(_navTab('对话'));
      await tester.pumpAndSettle();
      expect(find.text('新对话'), findsWidgets);
      expect(find.text('选择助手'), findsNothing);
    });

    testWidgets('home page module cards still work after navigation changes',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Verify OCR module card is tappable
      expect(find.text('OCR'), findsOneWidget);
      await tester.tap(find.text('OCR'));
      await tester.pumpAndSettle();

      // Should navigate to OCR page
      expect(find.text('文字识别'), findsOneWidget);
    });
  });

  group('Navigation placement by screen aspect ratio', () {
    testWidgets(
        'wide screen (width > height) shows the side NavigationRail, '
        'no bottom NavigationBar', (tester) async {
      // e.g. a phone rotated to landscape or a wide desktop window.
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(844, 390)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // All four destinations are reachable from the rail
      expect(find.text('主页'), findsOneWidget);
      expect(find.text('对话'), findsOneWidget);
      expect(find.text('文件'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets(
        'tall screen (height > width) shows the bottom NavigationBar, '
        'no side NavigationRail', (tester) async {
      // A wide-but-tall window (e.g. a tablet in portrait) must NOT show
      // the side rail even though its width is well above 600 px.
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(800, 1200)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets(
        'short wide window (narrow width but wider than tall) shows the '
        'side NavigationRail', (tester) async {
      // Regression: a small landscape window (width < 600) previously got
      // the bottom bar; by aspect ratio it is wider than tall → side rail.
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(500, 300)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('square screen shows the side NavigationRail (not taller)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(600, 600)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('side rail taps switch pages on wide screens', (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(844, 390)));
      await tester.pumpAndSettle();

      // Tap "文件" in the rail to go to the Files page. Its root key proves
      // the Files page actually opened (the "文件" label itself would match
      // the rail even if navigation never happened).
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('files_page')), findsOneWidget);

      // Tap "设置" in the rail to go to the Settings page. Its "主题" section
      // header proves the Settings page actually opened (the "设置" label
      // itself would match the rail even if navigation never happened).
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('主题'), findsOneWidget);
    });

    testWidgets(
        'resizing from landscape to portrait moves the nav to the bottom',
        (tester) async {
      // Simulate a screen rotation: the same widget tree is re-pumped with a
      // new size and updated in place, so placement must update live (not be
      // decided once at startup) and page state must survive the resize.
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(844, 390)));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);

      // Navigate to the Files page before rotating, so state survival is
      // verified across the resize
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('files_page')), findsOneWidget);

      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      // Still on the Files page after the resize
      expect(find.byKey(const Key('files_page')), findsOneWidget);

      // And back to landscape again
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(844, 390)));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('files_page')), findsOneWidget);
    });
  });
}
