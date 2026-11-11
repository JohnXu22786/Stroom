import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/topic_item.dart';

Widget _app({
  bool isRunning = false,
  bool isUnread = false,
  bool isFailed = false,
  bool isTemporary = false,
  VoidCallback? onTemporaryToggle,
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
        topic: Conversation(id: 'topic', title: 'Topic', isTemporary: isTemporary),
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
        onTemporaryToggle: onTemporaryToggle ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('topic menu toggles temporary status in either direction', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(_app(onTemporaryToggle: () => toggles++));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Temporary conversation'), findsOneWidget);
    await tester.tap(find.text('Temporary conversation'));
    expect(toggles, 1);

    await tester.pumpWidget(_app(
      isTemporary: true,
      onTemporaryToggle: () => toggles++,
    ));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Close temporary conversation'), findsOneWidget);
    await tester.tap(find.text('Close temporary conversation'));
    expect(toggles, 2);
  });

  testWidgets('inactive conversation icon tile is borderless', (tester) async {
    await tester.pumpWidget(_app());

    final iconFinder = find.byIcon(Icons.chat_bubble_outline_rounded);
    final bubble = tester.widget<Icon>(iconFinder);
    final cs = Theme.of(tester.element(find.byType(TopicItem))).colorScheme;
    expect(bubble.color, cs.onSurfaceVariant);

    final tile = tester.widget<Container>(
      find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.color, cs.primaryContainer.withValues(alpha: 0.3));
    expect(decoration.border, isNull);
  });

  testWidgets(
    'running conversation pulses the inactive icon style every 1.5 seconds',
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

      await tester.pump(const Duration(milliseconds: 750));
      final middleColor = tester.widget<Icon>(iconFinder).color;
      expect(middleColor, isNot(firstColor));
      expect(middleColor!.a, lessThan(firstColor!.a));
      expect(middleColor.r, firstColor.r);

      await tester.pump(const Duration(milliseconds: 750));
      final cycleColor = tester.widget<Icon>(iconFinder).color;
      expect(cycleColor, firstColor);
    },
  );

  testWidgets('failed conversation uses a softened red status color', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isFailed: true));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    expect(
      bubble.color,
      Color.lerp(
        Theme.of(tester.element(find.byType(TopicItem))).colorScheme.error,
        Theme.of(tester.element(find.byType(TopicItem)))
            .colorScheme
            .onSurfaceVariant,
        0.4,
      ),
    );
    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.chat_bubble_outline_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(
      decoration.color,
      Color.lerp(
        Theme.of(tester.element(find.byType(TopicItem))).colorScheme.error,
        Theme.of(tester.element(find.byType(TopicItem)))
            .colorScheme
            .onSurfaceVariant,
        0.4,
      )!
          .withValues(alpha: 0.12),
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
    final statusColor = Color.lerp(cs.primary, Colors.green, 0.55)!;
    final softenedColor = Color.lerp(statusColor, cs.onSurfaceVariant, 0.4);
    expect(bubble.color, softenedColor);
    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.chat_bubble_outline_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.color, softenedColor!.withValues(alpha: 0.12));
  });

  testWidgets('unread green adapts to the dark theme blue', (tester) async {
    await tester.pumpWidget(_app(isUnread: true, brightness: Brightness.dark));

    final bubble = tester.widget<Icon>(
      find.byIcon(Icons.chat_bubble_outline_rounded),
    );
    final cs = Theme.of(tester.element(find.byType(TopicItem))).colorScheme;
    expect(
      bubble.color,
      Color.lerp(
        Color.lerp(cs.primary, Colors.green, 0.55)!,
        cs.onSurfaceVariant,
        0.4,
      ),
    );
  });
}
