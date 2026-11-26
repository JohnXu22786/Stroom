// Widget tests for the temporary-conversation toggle on the chat page top bar:
//   - icon pair swap (outline bubble ↔ bubble + check) and countdown capsule
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/temporary_countdown_capsule.dart';

/// Pumps a ChatPage with a single seeded conversation, mirroring
/// createChatTestApp (tests/pages/chat_page/chat_page_test.dart) but with a resolvable
/// conversation so the top bar shows an enabled temp toggle.
Widget _appFor({
  required String activeId,
  required String convTitle,
  String? convId,
  bool temporary = false,
  bool configuredProvider = false,
  double textScale = 1,
  Locale locale = const Locale('zh', 'CN'),
  List<ChatMessage> messages = const [],
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [
          Conversation(
            id: convId ?? activeId,
            title: convTitle,
            messages: messages,
            isTemporary: temporary,
            temporaryExpiresAt: temporary
                ? DateTime.now().add(const Duration(minutes: 20))
                : null,
            temporaryPausedRemainingMilliseconds:
                temporary ? 20 * 60 * 1000 : null,
          ),
        ];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => activeId),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        if (configuredProvider) {
          // This fixture seeds StateNotifier state directly for the fake provider.
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          notifier.state = ProviderEntriesState(
            entries: [
              ProviderEntry(
                id: 'fixture_llm',
                type: 'llm',
                name: 'Fixture provider',
                configs: [
                  ProviderConfigItem(
                    providerName: 'Fixture',
                    host: 'https://example.invalid/v1',
                    key: 'fixture-key',
                    models: [
                      ModelConfig(
                        name: 'Fixture model',
                        modelId: 'fixture-model',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }
        return notifier;
      }),
      chatStreamManagerProvider.overrideWith((ref) => ChatStreamManager(null)),
    ],
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Roboto'),
        child: ChatPage(),
      ),
    ),
  );
}

List<ChatMessage> _fixtureHistory() => [
      ChatMessage(
        id: 'temporary-chat-fixture-message',
        role: 'user',
        content: 'Fixture history message',
        createdAt: DateTime(2026, 11, 26, 12),
      ),
    ];

List<String> _chatPageOverflowMessages(WidgetTester tester) {
  final signatures = <String>{};
  Object? error;
  while ((error = tester.takeException()) != null) {
    final message = error is FlutterError
        ? '${error.toStringDeep()} ${error.diagnostics.map((d) => d.toString()).join(' | ')}'
        : error.toString();
    if (message.isNotEmpty) signatures.add(message);
  }
  return signatures.toList()..sort();
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

  testWidgets('ChatPage stacks its temporary timer under the real title row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appFor(
        activeId: 'narrow-temporary-chat',
        convTitle: 'French chat title',
        temporary: true,
        configuredProvider: true,
        textScale: 4,
        locale: const Locale('fr'),
        messages: _fixtureHistory(),
      ),
    );
    final temporaryErrors = <String>[
      ..._chatPageOverflowMessages(tester),
    ];
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    temporaryErrors.addAll(_chatPageOverflowMessages(tester));
    expect(find.text('Fixture history message'), findsOneWidget);

    final timerFinder = find.byType(TemporaryCountdownCapsule);
    final timer = tester.widget<Text>(
      find.descendant(of: timerFinder, matching: find.byType(Text)),
    );
    expect(timer.data, matches(RegExp(r'^\d{2}:\d{2}$')));
    final headerFinder = find.byKey(const ValueKey('chat-page-topbar'));
    final headerRect = tester.getRect(headerFinder);
    final titleRect = tester.getRect(find.text('French chat title'));
    final titleSlotRect = tester.getRect(
      find.ancestor(
        of: find.text('French chat title'),
        matching: find.byType(ConstrainedText),
      ),
    );
    final timerRect = tester.getRect(timerFinder);
    final fullPageFinder = find.byKey(const ValueKey('chat-page-layout'));
    expect(tester.getSize(fullPageFinder), const Size(320, 640));
    await expectLater(
      fullPageFinder,
      matchesGoldenFile(
        '../../../docs/ui-constrained-text-qa/temporary-countdown/chat-page-fr-320x640-scale4-light.png',
      ),
    );
    expect(titleSlotRect.left, greaterThanOrEqualTo(headerRect.left));
    expect(titleSlotRect.right, lessThanOrEqualTo(headerRect.right));
    expect(titleSlotRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(titleRect.top, greaterThanOrEqualTo(headerRect.top));
    expect(titleRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(timerRect.top, greaterThanOrEqualTo(titleRect.bottom));
    expect(timerRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(timerRect.overlaps(titleRect), isFalse);
    final headerScrollFinder = find.byKey(
      const ValueKey('chat-page-header-scroll'),
    );
    final headerScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: headerScrollFinder,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(headerScroll.position.maxScrollExtent, 0);
    final composerScrollFinder = find.byKey(
      const ValueKey('chat-page-composer-scroll'),
    );
    final composerScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: composerScrollFinder,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(composerScroll.position.maxScrollExtent, greaterThan(0));
    await expectLater(
      headerFinder,
      matchesGoldenFile(
        '../../../docs/ui-constrained-text-qa/temporary-countdown/chat-header-fr-320x640-scale4-light.png',
      ),
    );
    final titleFinder = find.text('French chat title');
    final initialTitleX = tester.getTopLeft(titleFinder).dx;
    await tester.pump(const Duration(milliseconds: 499));
    temporaryErrors.addAll(_chatPageOverflowMessages(tester));
    expect(tester.getTopLeft(titleFinder).dx, initialTitleX);
    await tester.pump(const Duration(milliseconds: 1));
    temporaryErrors.addAll(_chatPageOverflowMessages(tester));
    expect(tester.getTopLeft(titleFinder).dx, initialTitleX);
    for (var second = 2; second <= 20; second += 2) {
      await tester.pump(Duration(seconds: second == 2 ? 1 : 2));
      temporaryErrors.addAll(_chatPageOverflowMessages(tester));
      await expectLater(
        headerFinder,
        matchesGoldenFile(
          '../../../docs/ui-constrained-text-qa/temporary-countdown/chat-header-reveal-${second}s.png',
        ),
      );
    }
    expect(tester.getTopLeft(titleFinder).dx, lessThan(initialTitleX));
    await tester.drag(composerScrollFinder, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(composerScroll.position.pixels, greaterThan(0));
    expect(
        composerScroll.position.pixels,
        lessThanOrEqualTo(
          composerScroll.position.maxScrollExtent,
        ));
    await expectLater(
      fullPageFinder,
      matchesGoldenFile(
        '../../../docs/ui-constrained-text-qa/temporary-countdown/chat-page-fr-320x640-scale4-scrolled-light.png',
      ),
    );
    temporaryErrors.addAll(_chatPageOverflowMessages(tester));
    // On unmodified main the same fixture had a 114px capsule-row overflow
    // plus the page body overflow. The responsive page keeps the scaled
    // content reachable without a RenderFlex exception.
    expect(temporaryErrors, isEmpty);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ChatPage keeps its fitting 1x layout and full page capture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appFor(
        activeId: 'normal-temporary-chat',
        convTitle: 'French chat title',
        temporary: true,
        configuredProvider: true,
        locale: const Locale('fr'),
        messages: _fixtureHistory(),
      ),
    );
    final errors = _chatPageOverflowMessages(tester);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    errors.addAll(_chatPageOverflowMessages(tester));

    final pageContext = tester.element(find.byType(ChatPage));
    expect(MediaQuery.textScalerOf(pageContext).scale(16), 16);
    expect(find.text('Fixture history message'), findsOneWidget);
    final headerFinder = find.byKey(const ValueKey('chat-page-topbar'));
    final timerFinder = find.byType(TemporaryCountdownCapsule);
    final titleFinder = find.text('French chat title');
    expect(tester.getRect(headerFinder).height, 48);
    expect(tester.getRect(timerFinder).overlaps(tester.getRect(titleFinder)),
        isFalse);
    expect(errors, isEmpty);
    await expectLater(
      find.byKey(const ValueKey('chat-page-layout')),
      matchesGoldenFile(
        '../../../docs/ui-constrained-text-qa/temporary-countdown/chat-page-fr-320x640-scale1-light.png',
      ),
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'switching to an existing temporary conversation does not replay its glow',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final first = Conversation(
        id: 'c-first',
        title: 'First',
        isTemporary: true,
        temporaryExpiresAt: DateTime.now().add(const Duration(minutes: 40)),
      )..temporaryExpiryRevision = 1;
      final second = Conversation(
        id: 'c-second',
        title: 'Second',
        isTemporary: true,
        temporaryExpiresAt: DateTime.now().add(const Duration(minutes: 20)),
      );
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(ref);
            notifier.state = [first, second];
            return notifier;
          }),
          activeConversationIdProvider.overrideWith((ref) => first.id),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
          chatStreamManagerProvider.overrideWith(
            (ref) => ChatStreamManager(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh', 'CN'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ChatPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.read(activeConversationIdProvider.notifier).state = second.id;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final capsule = tester.widget<Container>(
        find.descendant(
          of: find.byType(TemporaryCountdownCapsule),
          matching: find.byType(Container),
        ),
      );
      expect((capsule.decoration as BoxDecoration).boxShadow, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets(
      'top bar toggles temporary mode on the current conversation '
      'and shows the countdown capsule', (tester) async {
    await tester.pumpWidget(_appFor(activeId: 'c-main', convTitle: '主对话'));
    await tester.pumpAndSettle();
    expect(find.text('发送消息以开始对话。'), findsOneWidget);

    // 关闭态：空心气泡图标、无打勾、无倒计时胶囊。
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer), findsNothing);
    expect(find.byType(TemporaryCountdownCapsule), findsNothing);

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('一小时后删除'), findsNothing);

    // 开启态：气泡 + 打勾图标、标题前出现倒计时胶囊。
    expect(find.widgetWithIcon(IconButton, Icons.timer), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.timer_outlined), findsNothing);
    expect(find.byType(TemporaryCountdownCapsule), findsOneWidget);
    expect(find.text('临时'), findsNothing);
    expect(find.text('60:00'), findsOneWidget);

    // 再点一次关闭。
    expect(find.byTooltip('保留对话'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer), findsNothing);
    expect(find.byType(TemporaryCountdownCapsule), findsNothing);

    // 卸载页面释放 notifier 的周期性临时对话计时器。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'top-bar temp toggle is disabled without an active conversation',
    (tester) async {
      // activeId 指向列表中不存在的对话 → currentConversation 为 null。
      await tester.pumpWidget(
        _appFor(activeId: 'missing', convTitle: '主对话', convId: 'other'),
      );
      await tester.pumpAndSettle();
      expect(find.text('请选择或新建对话以开始聊天。'), findsOneWidget);

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.timer_outlined),
      );
      expect(button.onPressed, isNull);
      expect(find.byIcon(Icons.timer), findsNothing);
      expect(find.byType(TemporaryCountdownCapsule), findsNothing);
    },
  );
}
