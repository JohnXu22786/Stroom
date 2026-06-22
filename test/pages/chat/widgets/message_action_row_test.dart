import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/action_button.dart';
import 'package:stroom/pages/chat/widgets/message_action_row.dart';

/// Helper to find the button [Row] inside a [MessageActionRow].
Row? findButtonRow(WidgetTester tester) {
  // Find all Rows, then look for one that contains ActionButtons.
  final rows = tester.widgetList<Row>(find.byType(Row));
  for (final row in rows) {
    if (row.children.any((c) => c is ActionButton)) {
      return row;
    }
  }
  return null;
}

/// Counts [SizedBox] widgets with exact [width] in [row].
int countSpacers(Row row, {double width = 2}) {
  return row.children
      .whereType<SizedBox>()
      .where((s) => s.width == width)
      .length;
}

/// Counts [ActionButton] widgets in [row].
int countButtons(Row row) {
  return row.children.whereType<ActionButton>().length;
}

void main() {
  group('MessageActionRow button spacing', () {
    Widget buildApp({
      required String messageText,
      required bool isAi,
      required bool showRawData,
      required bool showJsonInspection,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            messageText: messageText,
            isAi: isAi,
            showRawData: showRawData,
            showJsonInspection: showJsonInspection,
            onCopy: () {},
            onRetryOrEdit: () {},
            onViewRawData: showRawData ? () {} : null,
            onJsonInspection: showJsonInspection ? () {} : null,
            onDelete: () {},
          ),
        ),
      );
    }

    Future<void> pumpRow(WidgetTester tester, Widget app) async {
      await tester.pumpWidget(app);
    }

    // ------------------------------------------------------------------------
    // 3-button scenarios: Copy + Edit/Retry + Delete
    // ------------------------------------------------------------------------

    testWidgets(
      'user message, no raw data, not dev mode: '
      '3 buttons, 2 spacers',
      (tester) async {
        await pumpRow(
          tester,
          buildApp(
            messageText: 'Hello',
            isAi: false,
            showRawData: false,
            showJsonInspection: false,
          ),
        );

        final row = findButtonRow(tester);
        expect(row, isNotNull);
        expect(countButtons(row!), 3);
        expect(countSpacers(row), 2);

        // Verify correct icons
        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // No conditional buttons
        expect(find.byIcon(Icons.info_outline), findsNothing);
        expect(find.byIcon(Icons.code), findsNothing);
      },
    );

    testWidgets(
      'AI message, no raw data, not dev mode: '
      '3 buttons, 2 spacers, shows retry',
      (tester) async {
        await pumpRow(
          tester,
          buildApp(
            messageText: 'AI response',
            isAi: true,
            showRawData: false,
            showJsonInspection: false,
          ),
        );

        final row = findButtonRow(tester);
        expect(row, isNotNull);
        expect(countButtons(row!), 3);
        expect(countSpacers(row), 2);

        // AI message uses refresh (retry), not edit_outlined
        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
      },
    );

    // ------------------------------------------------------------------------
    // 4-button scenarios: Copy + Edit/Retry + Info + Delete
    // ------------------------------------------------------------------------

    testWidgets(
      'user message with raw data, not dev mode: '
      '4 buttons, 3 spacers',
      (tester) async {
        await pumpRow(
          tester,
          buildApp(
            messageText: 'Hello',
            isAi: false,
            showRawData: true,
            showJsonInspection: false,
          ),
        );

        final row = findButtonRow(tester);
        expect(row, isNotNull);
        expect(countButtons(row!), 4);
        expect(countSpacers(row), 3);

        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets(
      'AI message with raw data, not dev mode: '
      '4 buttons, 3 spacers, tooltip shows 查看响应数据',
      (tester) async {
        await pumpRow(
          tester,
          buildApp(
            messageText: 'AI response',
            isAi: true,
            showRawData: true,
            showJsonInspection: false,
          ),
        );

        final row = findButtonRow(tester);
        expect(row, isNotNull);
        expect(countButtons(row!), 4);
        expect(countSpacers(row), 3);

        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // 4-button scenarios: Copy + Edit + JSON + Delete (dev mode, AI, no raw)
    // ------------------------------------------------------------------------

    testWidgets(
      'AI message, dev mode, no raw data: '
      '4 buttons (with JSON), 3 spacers',
      (tester) async {
        await pumpRow(
          tester,
          buildApp(
            messageText: 'AI response',
            isAi: true,
            showRawData: false,
            showJsonInspection: true,
          ),
        );

        final row = findButtonRow(tester);
        expect(row, isNotNull);
        expect(countButtons(row!), 4);
        expect(countSpacers(row), 3);

        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.code), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // 5-button scenarios: Copy + Edit/Retry + Info + JSON + Delete
    // ------------------------------------------------------------------------

    testWidgets(
      'AI message, dev mode, with raw data: '
      '5 buttons, 4 spacers',
      (tester) async {
        await pumpRow(
          tester,
          buildApp(
            messageText: 'AI response',
            isAi: true,
            showRawData: true,
            showJsonInspection: true,
          ),
        );

        final row = findButtonRow(tester);
        expect(row, isNotNull);
        expect(countButtons(row!), 5);
        expect(countSpacers(row), 4);

        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.code), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // User message shows edit_outlined, AI shows refresh
    // ------------------------------------------------------------------------

    testWidgets(
      'user message shows edit icon, AI shows retry icon',
      (tester) async {
        // User message
        await pumpRow(
          tester,
          buildApp(
            messageText: 'Hello',
            isAi: false,
            showRawData: false,
            showJsonInspection: false,
          ),
        );
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsNothing);
      },
    );

    // ------------------------------------------------------------------------
    // Verify no orphaned SizedBox(2) widgets
    // ------------------------------------------------------------------------

    testWidgets(
      'no orphaned spacers: SizedBox count matches (buttons - 1)',
      (tester) async {
        // Test all six combinations
        final combinations = [
          (
            isAi: false,
            showRawData: false,
            showJsonInspection: false,
            expectedButtons: 3
          ),
          (
            isAi: true,
            showRawData: false,
            showJsonInspection: false,
            expectedButtons: 3
          ),
          (
            isAi: false,
            showRawData: true,
            showJsonInspection: false,
            expectedButtons: 4
          ),
          (
            isAi: true,
            showRawData: true,
            showJsonInspection: false,
            expectedButtons: 4
          ),
          (
            isAi: true,
            showRawData: false,
            showJsonInspection: true,
            expectedButtons: 4
          ),
          (
            isAi: true,
            showRawData: true,
            showJsonInspection: true,
            expectedButtons: 5
          ),
        ];

        for (final combo in combinations) {
          await pumpRow(
            tester,
            buildApp(
              messageText: 'test',
              isAi: combo.isAi,
              showRawData: combo.showRawData,
              showJsonInspection: combo.showJsonInspection,
            ),
          );

          final row = findButtonRow(tester);
          expect(row, isNotNull,
              reason: 'Expected Row for isAi=${combo.isAi}, '
                  'showRawData=${combo.showRawData}, '
                  'showJsonInspection=${combo.showJsonInspection}');
          final buttons = countButtons(row!);
          final spacers = countSpacers(row);
          expect(buttons, combo.expectedButtons,
              reason: 'Button count mismatch for isAi=${combo.isAi}, '
                  'showRawData=${combo.showRawData}, '
                  'showJsonInspection=${combo.showJsonInspection}');
          expect(spacers, buttons - 1,
              reason: 'Spacer count should be (buttons - 1) for '
                  'isAi=${combo.isAi}, '
                  'showRawData=${combo.showRawData}, '
                  'showJsonInspection=${combo.showJsonInspection}. '
                  'Got $spacers spacers for $buttons buttons. '
                  'This means orphaned spacers exist when conditional '
                  'buttons are hidden.');

          // Clear the widget tree for next combination
          await tester.pumpWidget(Container());
        }
      },
    );
  });
}
