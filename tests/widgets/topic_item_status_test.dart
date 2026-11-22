import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/topic_item.dart';

Widget _app({
  bool isRunning = false,
  bool isUnread = false,
  bool isFailed = false,
  bool isTemporary = false,
  VoidCallback? onTemporaryToggle,
  Brightness brightness = Brightness.light,
  VoidCallback? onReadStateToggle,
  Locale? locale,
  TextScaler? textScaler,
  double? topicWidth,
  bool scrollableTopic = false,
}) {
  return MaterialApp(
    locale: locale,
    theme: ThemeData(
      colorSchemeSeed: Colors.deepPurple,
      brightness: brightness,
    ),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: scrollableTopic
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: topicWidth,
                child: _topicItem(
                  isTemporary: isTemporary,
                  isRunning: isRunning,
                  isUnread: isUnread,
                  isFailed: isFailed,
                  onReadStateToggle: onReadStateToggle,
                  onTemporaryToggle: onTemporaryToggle,
                ),
              ),
            )
          : SizedBox(
              width: topicWidth,
              child: _topicItem(
                isTemporary: isTemporary,
                isRunning: isRunning,
                isUnread: isUnread,
                isFailed: isFailed,
                onReadStateToggle: onReadStateToggle,
                onTemporaryToggle: onTemporaryToggle,
              ),
            ),
    ),
  );
}

Widget _topicItem({
  bool isTemporary = false,
  bool isRunning = false,
  bool isUnread = true,
  bool isFailed = false,
  VoidCallback? onReadStateToggle,
  VoidCallback? onTemporaryToggle,
}) {
  return TopicItem(
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
    onReadStateToggle: onReadStateToggle ?? () {},
    onSelectionToggle: () {},
    onTemporaryToggle: onTemporaryToggle ?? () {},
  );
}

void main() {
  testWidgets(
    'narrow scaled localized read-state label keeps its row geometry',
    (tester) async {
      tester.view.physicalSize = const Size(240, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.5),
          topicWidth: 500,
          scrollableTopic: true,
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump(const Duration(milliseconds: 300));

      const label = 'Als ungelesen markieren';
      final labelFinder = find.text(label);
      final constrainedLabel = find.ancestor(
        of: labelFinder,
        matching: find.byType(ConstrainedText),
      );
      expect(constrainedLabel, findsOneWidget);
      expect(labelFinder, findsOneWidget);

      final menuItem = find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<String> && widget.value == 'read_state',
      );
      final row = find.descendant(of: menuItem, matching: find.byType(Row));
      expect(row, findsOneWidget);
      final iconFinder = find.byIcon(Icons.mark_email_unread_outlined);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.size, 20);
      final gap = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 12,
        ),
      );
      expect(gap, findsOneWidget);
      expect(
        tester.getRect(find.text(label)).left -
            tester.getRect(iconFinder).right,
        12,
      );
      const autoName = 'Automatisch benennen';
      final autoNameFinder = find.text(autoName);
      final constrainedAutoName = find.ancestor(
        of: autoNameFinder,
        matching: find.byType(ConstrainedText),
      );
      expect(constrainedAutoName, findsOneWidget);
      expect(
        find.descendant(
          of: constrainedAutoName,
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.descendant(
          of: constrainedAutoName,
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordinary read-state label remains stationary when it fits', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final label = find.text('Mark as unread');
    final constrainedLabel = find.ancestor(
      of: label,
      matching: find.byType(ConstrainedText),
    );
    expect(constrainedLabel, findsOneWidget);
    expect(
      find.descendant(
        of: constrainedLabel,
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 3));
    expect(
      find.descendant(
        of: constrainedLabel,
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('narrow scaled topic date stays within metadata slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(topicWidth: 320, textScaler: const TextScaler.linear(2)),
    );

    final date = find.textContaining('-');
    expect(date, findsOneWidget);
    expect(
      find.ancestor(of: date, matching: find.byType(ConstrainedText)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topic menu toggles temporary status in either direction', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(_app(onTemporaryToggle: () => toggles++));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Set as temporary conversation'), findsOneWidget);
    await tester.tap(find.text('Set as temporary conversation'));
    await tester.pumpAndSettle();
    expect(toggles, 0);
    await tester.tap(find.text('Enable temporary mode').last);
    await tester.pumpAndSettle();
    expect(toggles, 1);

    await tester.pumpWidget(
      _app(isTemporary: true, onTemporaryToggle: () => toggles++),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Keep conversation'), findsOneWidget);
    await tester.tap(find.text('Keep conversation'));
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

  testWidgets(
    'menu read toggle follows unread state and preserves error icon',
    (tester) async {
      await tester.pumpWidget(_app(isUnread: true, isFailed: true));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Mark as read'), findsOneWidget);
      expect(find.text('Mark as unread'), findsNothing);
      final actionIcon = tester.widget<Icon>(
        find.byIcon(Icons.mark_email_read_outlined),
      );
      final cs = Theme.of(tester.element(find.byType(TopicItem))).colorScheme;
      expect(actionIcon.color, Color.lerp(cs.primary, Colors.green, 0.55));

      final leadingIcon = tester.widget<Icon>(
        find.byIcon(Icons.chat_bubble_outline_rounded),
      );
      expect(leadingIcon.color, Color.lerp(cs.error, cs.onSurfaceVariant, 0.4));
    },
  );

  testWidgets('first topic menu action invokes the read-state toggle', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(_app(onReadStateToggle: () => toggled = true));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Mark as unread')).dy,
      lessThan(tester.getTopLeft(find.text('Rename')).dy),
    );
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    expect(toggled, isTrue);
  });

  testWidgets('read toggle uses the selected locale', (tester) async {
    await tester.pumpWidget(_app(locale: const Locale('zh', 'CN')));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('标记为未读'), findsOneWidget);
  });
}
