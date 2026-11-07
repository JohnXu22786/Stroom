import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/topic_item.dart';

Widget _app({
  bool isRunning = false,
  bool isUnread = false,
  bool isFailed = false,
}) {
  return MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.blue),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: TopicItem(
        topic: Conversation(id: 'topic', title: 'Topic'),
        selectionMode: false,
        isSelected: false,
        isActive: false,
        isRunning: isRunning,
        isUnread: isUnread,
        isFailed: isFailed,
        onTap: () {},
        onDelete: () {},
        onPinToggle: () {},
        onRename: () {},
        onAutoRename: () {},
        onSelectionToggle: () {},
      ),
    ),
  );
}

void main() {
  testWidgets(
      'running conversation keeps its bubble and pulses blue each second',
      (tester) async {
    await tester.pumpWidget(_app(isRunning: true));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    expect(
      bubble.color,
      ColorScheme.fromSeed(seedColor: Colors.blue).primary,
    );
    final firstColor = bubble.color;

    await tester.pump(const Duration(milliseconds: 500));
    final middleColor = tester
        .widget<Icon>(find.byIcon(Icons.chat_bubble_outline_rounded))
        .color;
    expect(middleColor, isNot(firstColor));

    await tester.pump(const Duration(milliseconds: 500));
    final cycleColor = tester
        .widget<Icon>(find.byIcon(Icons.chat_bubble_outline_rounded))
        .color;
    expect(cycleColor, firstColor);
  });

  testWidgets('failed conversation is marked red', (tester) async {
    await tester.pumpWidget(_app(isFailed: true));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    expect(
      bubble.color,
      Theme.of(tester.element(find.byType(TopicItem))).colorScheme.error,
    );
  });

  testWidgets('completed unread conversation is marked green', (tester) async {
    await tester.pumpWidget(_app(isUnread: true));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    expect(
      bubble.color,
      ColorScheme.fromSeed(seedColor: Colors.green).primary,
    );
  });
}
