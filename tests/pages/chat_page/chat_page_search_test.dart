// Widget tests for chat search: markdown must survive search (only the
// matching text is highlighted), and the up/down navigation must jump
// between matches — including jumping to matches in older messages that
// lazy pagination has not loaded yet.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/assistant_selection_page.dart'
    show ChatTabVisibility;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _buildApp({
  String? initialSearchQuery,
  Locale locale = const Locale('zh', 'CN'),
  double textScale = 1,
  ThemeData? theme,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: theme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ChatPage(initialSearchQuery: initialSearchQuery),
      ),
    ),
  );
}

Future<void> _pumpChat(
  WidgetTester tester, {
  required List<ChatMessage> messages,
  String? initialSearchQuery,
  Locale locale = const Locale('zh', 'CN'),
  double textScale = 1,
  ThemeData? theme,
  ValueListenable<bool>? chatTabVisibility,
}) async {
  Widget app = _buildApp(
    initialSearchQuery: initialSearchQuery,
    locale: locale,
    textScale: textScale,
    theme: theme,
  );
  if (chatTabVisibility != null) {
    app = ValueListenableBuilder<bool>(
      valueListenable: chatTabVisibility,
      builder: (context, isVisible, child) => ChatTabVisibility(
        isVisible: isVisible,
        child: child!,
      ),
      child: app,
    );
  }
  await tester.pumpWidget(app);
  await tester.pump();

  final ctx = tester.element(find.byType(ChatPage));
  final container = ProviderScope.containerOf(ctx);
  container.read(conversationsProvider.notifier).state = [
    Conversation.fromMap({
      'id': 'test-conv-id',
      'title': 'Test Conversation',
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
      'messages': messages.map((m) => m.toMap()).toList(),
      'isPinned': false,
      'sortOrder': 0,
    }),
  ];
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

List<ChatMessage> _messages() {
  return [
    ChatMessage(
      id: 'u1',
      role: 'user',
      content: 'Hello there',
      createdAt: DateTime(2025, 1, 1, 1),
    ),
    ChatMessage(
      id: 'a1',
      role: 'assistant',
      content: '**bold** term here and *em* term too',
      createdAt: DateTime(2025, 1, 1, 2),
    ),
    // A code fence containing the query: that occurrence can never be
    // highlighted (the fence renders as a dedicated code widget), so search
    // must not count it — the counter below would otherwise be 1/4.
    ChatMessage(
      id: 'a2',
      role: 'assistant',
      content: '```\nterm\n```\nterm in prose',
      createdAt: DateTime(2025, 1, 1, 3),
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  setUp(() {
    // Markdown rendering wraps blocks in VisibilityDetector; its default
    // 500ms debounce timer would remain pending at test teardown.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('ChatPage search keeps markdown and highlights matches', () {
    testWidgets('current-search hint stays editable and exposes the full label',
        (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpChat(
        tester,
        messages: _messages(),
        locale: const Locale('fr', 'FR'),
        textScale: 2,
      );
      await tester.tap(find.byTooltip('Rechercher dans les messages'));
      await tester.pump();

      final fieldFinder = find.byType(TextField).first;
      final field = tester.widget<TextField>(fieldFinder);
      final hint = field.decoration!.hint as ConstrainedText;
      expect(hint.data, 'Rechercher dans cette conversation…');
      expect(field.controller, isNotNull);
      expect(tester.getSize(fieldFinder).height, greaterThan(32));
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.getSemantics(find.byWidget(hint)).label,
          'Rechercher dans cette conversation…');

      await tester.enterText(fieldFinder, 'requête');
      await tester.pump();
      expect(field.controller!.text, 'requête');
    });

    testWidgets('search field preserves 32 dp at 1x and grows at 2x',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(800, 640);
      tester.view.devicePixelRatio = 1;

      await _pumpChat(
        tester,
        messages: _messages(),
        locale: const Locale('en', 'US'),
        theme: ThemeData.light(useMaterial3: true),
      );
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();

      final searchField = find.byType(TextField).first;
      expect(tester.getSize(searchField).height, 32);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../../docs/ui-constrained-text-qa/round13-chat-search-height/chat-search-en-800x640-scale1-light.png',
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      await _pumpChat(
        tester,
        messages: _messages(),
        locale: const Locale('fr', 'FR'),
        textScale: 2,
        theme: ThemeData.light(useMaterial3: true),
      );
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();

      final scaledField = find.byType(TextField).first;
      expect(tester.getSize(scaledField).height, greaterThan(32));
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(
        tester.getRect(find.byIcon(Icons.close)).right,
        lessThanOrEqualTo(320),
      );
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          '../../../docs/ui-constrained-text-qa/round13-chat-search-height/chat-search-fr-320x640-scale2-light.png',
        ),
      );

      await tester.enterText(scaledField, 'requête');
      await tester.pump();
      expect(tester.widget<TextField>(scaledField).controller!.text, 'requête');
      expect(tester.takeException(), isNull);
    });

    testWidgets('current-search hint resolves focused theme text style',
        (tester) async {
      final theme = ThemeData(
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: WidgetStateTextStyle.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.focused)
                  ? Colors.purple
                  : Colors.green,
            ),
          ),
        ),
      );
      await _pumpChat(tester, messages: _messages(), theme: theme);
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      final hint = field.decoration!.hint as ConstrainedText;
      expect(field.focusNode!.hasFocus, isTrue);
      expect(hint.style!.color, Colors.purple);
    });

    testWidgets('search focus and hover do not rebuild the chat message list',
        (tester) async {
      await _pumpChat(tester, messages: _messages());
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      await tester.pump();

      final chatFinder = find.byType(Chat);
      final initialChat = tester.widget<Chat>(chatFinder);
      final fieldFinder = find.byType(TextField).first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(fieldFinder));
      await tester.pump();
      expect(identical(tester.widget<Chat>(chatFinder), initialChat), isTrue);
      await mouse.moveTo(const Offset(0, 0));
      await tester.pump();
      expect(identical(tester.widget<Chat>(chatFinder), initialChat), isTrue);

      FocusScope.of(tester.element(fieldFinder)).unfocus();
      await tester.pump();
      expect(identical(tester.widget<Chat>(chatFinder), initialChat), isTrue);
      await tester.tap(fieldFinder);
      await tester.pump();
      expect(identical(tester.widget<Chat>(chatFinder), initialChat), isTrue);
      await mouse.removePointer();
    });

    testWidgets('search hint stops ticking while the chat tab is hidden',
        (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chatTabVisibility = ValueNotifier(true);
      addTearDown(chatTabVisibility.dispose);
      await _pumpChat(
        tester,
        messages: _messages(),
        locale: const Locale('fr', 'FR'),
        textScale: 2,
        chatTabVisibility: chatTabVisibility,
      );
      await tester.tap(find.byTooltip('Rechercher dans les messages'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      final hintText = find.text('Rechercher dans cette conversation…');
      final visiblePosition = tester.getTopLeft(hintText);
      chatTabVisibility.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getTopLeft(hintText), visiblePosition);
    });

    testWidgets('German current-search hint keeps its full semantic label',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpChat(
        tester,
        messages: _messages(),
        locale: const Locale('de', 'DE'),
      );
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();

      final hint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == 'Dieses Gespräch durchsuchen …',
      );
      expect(tester.widget<ConstrainedText>(hint).data,
          'Dieses Gespräch durchsuchen …');
      expect(tester.getSemantics(hint).label, 'Dieses Gespräch durchsuchen …');
    });

    testWidgets('global-search mode also constrains its localized hint',
        (tester) async {
      await _pumpChat(
        tester,
        messages: _messages(),
        locale: const Locale('fr', 'FR'),
      );
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      await tester.tap(find.text('Toutes les conversations'));
      await tester.pump();

      final chatPage = find.byType(ChatPage, skipOffstage: false).first;
      final fieldFinder = find
          .descendant(
            of: chatPage,
            matching: find.byType(TextField),
          )
          .first;
      final hint = tester.widget<TextField>(fieldFinder).decoration!.hint;
      expect(hint, isA<ConstrainedText>());
      expect((hint! as ConstrainedText).data,
          'Rechercher dans toutes les conversations…');
    });

    testWidgets('fitting search hint stays stationary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
                child: const ConstrainedText(
                  'Search this conversation...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );

      final hint = find.byType(ConstrainedText);
      expect(find.descendant(of: hint, matching: find.byType(Transform)),
          findsNothing);
    });

    testWidgets('search does not flatten markdown into plain text',
        (tester) async {
      await _pumpChat(tester,
          messages: _messages(), initialSearchQuery: 'term');

      // Search bar is active.
      expect(find.text('搜索当前对话...'), findsOneWidget);

      // The markdown is still parsed: no literal asterisks anywhere.
      expect(find.textContaining('**', findRichText: true), findsNothing,
          reason: 'markdown must not be flattened to raw text during search');

      // The rendered text is the parsed markdown (bold/emphasis applied).
      expect(
        find.textContaining('bold term here and em term too',
            findRichText: true),
        findsOneWidget,
        reason: 'the parsed markdown text must still be rendered',
      );

      // Match counter shows 1 of 3 matches: two prose occurrences in a1 plus
      // one in a2 — the "term" inside a2's code fence is NOT counted.
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('up/down buttons move the current match counter',
        (tester) async {
      await _pumpChat(tester,
          messages: _messages(), initialSearchQuery: 'term');

      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget,
          reason: 'down button must advance to the second match');

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      await tester.pump();
      expect(find.text('3/3'), findsOneWidget,
          reason: 'down button must advance to the third match');

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget,
          reason: 'up button must go back to the previous match');
    });

    testWidgets('navigation loads older (unloaded) messages to reach a match',
        (tester) async {
      // 35 messages: only the last 20 are inserted into the chat controller
      // initially. The first match lives in message m0, which is unloaded.
      final messages = <ChatMessage>[
        for (var i = 0; i < 35; i++)
          ChatMessage(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            content: 'Message $i content',
            createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
          ),
      ];
      await _pumpChat(
        tester,
        messages: messages,
        initialSearchQuery: 'Message 0 content',
      );

      // Only one match (message 0), so the counter is 1/1 — and reaching it
      // must have pulled the older page into the controller.
      final chat = tester.widget<Chat>(find.byType(Chat));
      expect(chat.chatController.messages.length, 35,
          reason: 'scrolling to the first match must load the older '
              'messages that contain it');
      expect(find.text('1/1'), findsOneWidget);

      // The observer-based scroll-to-message runs asynchronously (it scrolls
      // towards the target iteratively until the lazy item is built). Pump
      // until message 0's bubble actually appears — scoped to the chat list
      // so the search bar's TextField (which also contains the query text)
      // cannot satisfy the finder — proving the navigation really jumped.
      final matchInChat = find.descendant(
        of: find.byType(Chat),
        matching: find.text('Message 0 content'),
      );
      var scrolledToMatch = false;
      for (var i = 0; i < 80 && !scrolledToMatch; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        scrolledToMatch = tester.any(matchInChat);
      }
      expect(scrolledToMatch, isTrue,
          reason: 'navigation must scroll until the matched message is built');

      // Let the observer finish its final alignment (it scrolls iteratively
      // and then animates to the target position) before measuring.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final bubbleRect = tester.getRect(matchInChat);
      final pageSize = tester.getSize(find.byType(ChatPage));
      expect(bubbleRect.top, lessThan(pageSize.height),
          reason: 'the matched message must be inside the viewport');
      expect(bubbleRect.bottom, greaterThan(0),
          reason: 'the matched message must be inside the viewport');
    });
  });
}
