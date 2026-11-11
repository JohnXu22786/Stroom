// Widget tests for the temporary-conversation toggle on the chat page top bar:
//   - icon pair swap (outline bubble ↔ bubble + check) and countdown capsule
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/temporary_countdown_capsule.dart';

/// Pumps a ChatPage with a single seeded conversation, mirroring
/// createChatTestApp (tests/pages/chat_page/chat_page_test.dart) but with a resolvable
/// conversation so the top bar shows an enabled temp toggle.
Widget _appFor({
  required String activeId,
  required String convTitle,
  String? convId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [
          Conversation(id: convId ?? activeId, title: convTitle),
        ];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => activeId),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
    child: const MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ChatPage(),
    ),
  );
}

void main() {
  testWidgets('top bar toggles temporary mode on the current conversation '
      'and shows the countdown capsule', (tester) async {
    await tester.pumpWidget(_appFor(activeId: 'c-main', convTitle: '主对话'));
    await tester.pumpAndSettle();
    expect(find.text('发送消息以开始对话。'), findsOneWidget);

    // 关闭态：空心气泡图标、无打勾、无倒计时胶囊。
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer), findsNothing);
    expect(find.byType(TemporaryCountdownCapsule), findsNothing);

    // Cancelling the explanation must leave temporary mode disabled.
    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('一小时后删除'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byType(TemporaryCountdownCapsule), findsNothing);

    // Confirm the lifecycle explanation before enabling.
    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启临时模式').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 开启态：气泡 + 打勾图标、标题前出现倒计时胶囊。
    expect(find.byIcon(Icons.timer), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(find.byType(TemporaryCountdownCapsule), findsOneWidget);
    expect(find.text('临时'), findsOneWidget);
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
