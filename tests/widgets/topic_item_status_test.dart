import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/topic_item.dart';

Widget _app({
  bool isRunning = false,
  bool isUnread = false,
  bool isFailed = false,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: Colors.deepPurple,
      brightness: brightness,
    ),
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
    'running conversation pulses the inactive icon style each second',
    (tester) async {
      await tester.pumpWidget(_app(isRunning: true));

      final cs = Theme.of(tester.element(find.byType(TopicItem))).colorScheme;
      final iconFinder = find.byIcon(Icons.chat_bubble_outline_rounded);
      final bubble = tester.widget<Icon>(iconFinder);
      expect(bubble.color, cs.onSurfaceVariant);

      final tile = tester.widget<Container>(
        find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
      );
      final decoration = tile.decoration! as BoxDecoration;
      expect(decoration.color, cs.primaryContainer.withValues(alpha: 0.3));
      expect(decoration.border, isNull);

      final firstColor = bubble.color;

      await tester.pump(const Duration(milliseconds: 500));
      final middleColor = tester
          .widget<Icon>(iconFinder)
          .color;
      expect(middleColor, isNot(firstColor));
      expect(middleColor!.a, lessThan(firstColor!.a));
      expect(middleColor.r, firstColor.r);

      await tester.pump(const Duration(milliseconds: 500));
      final cycleColor = tester.widget<Icon>(iconFinder).color;
      expect(cycleColor, firstColor);
    },
  );

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

  testWidgets('completed unread conversation uses a muted theme green', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isUnread: true));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    final cs = Theme.of(tester.element(find.byType(TopicItem))).colorScheme;
    expect(bubble.color, Color.lerp(cs.primary, Colors.green, 0.55));
  });

  testWidgets('unread green adapts to the dark theme blue', (tester) async {
    await tester.pumpWidget(_app(isUnread: true, brightness: Brightness.dark));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    final cs = Theme.of(tester.element(find.byType(TopicItem))).colorScheme;
    expect(bubble.color, Color.lerp(cs.primary, Colors.green, 0.55));
  });
}
