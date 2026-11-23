// Widget tests for temporary-conversation UI on the conversations page:
//   - countdown capsule + checked-bubble leading icon for temporary conversations
//   - three-dot menu toggle enabling temporary mode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/temporary_countdown_capsule.dart';

Conversation _conv(String id, {bool isTemporary = false}) {
  return Conversation(
    id: id,
    title: '对话$id',
    isTemporary: isTemporary,
    temporaryExpiresAt:
        isTemporary ? DateTime.now().add(kTemporaryConversationDuration) : null,
  );
}

Widget _testApp(List<Conversation> conversations) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = conversations;
        return notifier;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh', 'CN'),
      home: ConversationsPage(),
    ),
  );
}

void _expectCountdownAtExpiration(
  WidgetTester tester,
  DateTime expiresAt,
  DateTime startedAt,
) {
  final capsule = find.byType(TemporaryCountdownCapsule);
  final countdownText = tester.widget<Text>(
    find.descendant(of: capsule, matching: find.byType(Text)),
  );
  final parts = countdownText.data!.split(':');
  final displayedSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
  final secondsRemaining = expiresAt.difference(DateTime.now()).inSeconds;
  final secondsAtStart = formatTemporaryCountdown(
    expiresAt.difference(startedAt),
  );
  final startParts = secondsAtStart.split(':');
  final maximumDisplayedSeconds =
      int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

  // Bound the display to the measured test interval. Exact rounding is
  // covered by the formatter test below.
  expect(
    displayedSeconds,
    inInclusiveRange(secondsRemaining, maximumDisplayedSeconds),
  );
}

void main() {
  testWidgets(
      'temporary conversation shows countdown capsule and '
      'checked-bubble leading icon', (tester) async {
    final countdownStartedAt = DateTime.now();
    final temporaryConversation = _conv('temp-1', isTemporary: true);
    await tester.pumpWidget(
      _testApp([temporaryConversation, _conv('normal-1')]),
    );
    await tester.pump();

    // 倒计时胶囊（MM:SS）出现在临时对话条目前。
    _expectCountdownAtExpiration(
      tester,
      temporaryConversation.temporaryExpiresAt!,
      countdownStartedAt,
    );
    expect(find.text('临时'), findsNothing);
    // 临时对话左侧图标变为"气泡 + 打勾"（非 drag handle）。
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsOneWidget);
    // 普通对话仍保留拖拽把手。
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);

    // 菜单开启项文案随状态变化。
    expect(find.text('对话temp-1'), findsOneWidget);
    expect(find.text('对话normal-1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('保留对话'), findsOneWidget);
  });

  testWidgets('conversation list freezes the capsule while a reply is active',
      (tester) async {
    final paused = Conversation(
      id: 'paused-1',
      title: 'Paused conversation',
      isTemporary: true,
      temporaryExpiresAt: DateTime.now().add(const Duration(minutes: 50)),
      temporaryPausedRemainingMilliseconds: 30 * 1000,
    );
    await tester.pumpWidget(_testApp([paused]));
    await tester.pump();

    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('50:00'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('three-dot menu can enable temporary mode on a conversation', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp([_conv('target-1'), _conv('other-1')]));
    await tester.pump();

    // 初始无临时对话：无胶囊、无勾选气泡图标。
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsNothing);

    // 打开 target-1 的更多菜单（取第一个 more_vert）。
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('设为临时对话'), findsOneWidget);

    await tester.tap(find.text('设为临时对话'));
    await tester.pumpAndSettle();
    expect(find.textContaining('一小时后删除'), findsOneWidget);
    final countdownStartedAt = DateTime.now();
    await tester.tap(find.text('开启临时模式').last);
    // 菜单关闭动画 + 状态变更重建。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 胶囊与气泡+打勾图标出现。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConversationsPage)),
    );
    final enabledConversation = container
        .read(conversationsProvider)
        .firstWhere((conversation) => conversation.id == 'target-1');
    _expectCountdownAtExpiration(
      tester,
      enabledConversation.temporaryExpiresAt!,
      countdownStartedAt,
    );
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);

    // 卸载页面以释放 notifier 的周期性临时对话计时器。
    await tester.pumpWidget(const SizedBox());
  });

  test('countdown formatting displays rounded minutes and seconds', () {
    expect(formatTemporaryCountdown(const Duration(hours: 1)), '60:00');
    expect(formatTemporaryCountdown(const Duration(seconds: 59)), '00:59');
    expect(formatTemporaryCountdown(const Duration(seconds: 58)), '00:58');
    expect(formatTemporaryCountdown(const Duration(microseconds: 1)), '00:01');
    expect(formatTemporaryCountdown(const Duration(microseconds: -1)), '00:00');
  });
}
