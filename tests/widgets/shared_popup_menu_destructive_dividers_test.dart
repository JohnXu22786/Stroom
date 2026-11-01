import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/pages/anki_page.dart';
import 'package:stroom/pages/unified_task_list/synthesis_task_card.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/widgets/batch_rename_rule_editor.dart';
import 'package:stroom/widgets/topic_item.dart';

void expectDividerImmediatelyBeforeValue(
  List<PopupMenuEntry<String>> items,
  String value,
) {
  final itemIndex = items.indexWhere(
    (item) => item is PopupMenuItem<String> && item.value == value,
  );

  expect(itemIndex, greaterThan(0));
  expect(items[itemIndex - 1], isA<PopupMenuDivider>());
}

List<PopupMenuEntry<String>> menuItemsFor(WidgetTester tester, Finder finder) {
  final button = tester.widget<PopupMenuButton<String>>(finder);
  return button.itemBuilder(tester.element(finder));
}

void main() {
  testWidgets('Anki deck menu separates delete from routine actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDeckListProvider.overrideWith(
            (ref) async => [Deck(id: 1, name: 'Study deck')],
          ),
          ankiDeckStatsProvider.overrideWith(
            (ref, deckId) async => DeckStats(deckName: 'Study deck'),
          ),
        ],
        child: const MaterialApp(home: AnkiDroidPage()),
      ),
    );
    await tester.pumpAndSettle();

    final menu = find.byType(PopupMenuButton<String>);
    expect(menu, findsOneWidget);
    final items = menuItemsFor(tester, menu);
    expectDividerImmediatelyBeforeValue(items, 'delete');
  });

  testWidgets('running synthesis task menu separates removal from pause', (
    tester,
  ) async {
    final task = SynthesisTask(
      id: 'running-task',
      title: 'Running task',
      text: 'text',
      providerConfig: ProviderConfigItem(
        providerName: 'Test',
        host: 'https://example.com',
        key: 'key',
      ),
      modelConfig: ModelConfig(name: 'Test model', modelId: 'test-model'),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SynthesisTaskCard(task: task)),
        ),
      ),
    );

    final menu = find.byType(PopupMenuButton<String>);
    expect(menu, findsOneWidget);
    final items = menuItemsFor(tester, menu);
    expectDividerImmediatelyBeforeValue(items, 'remove');
  });

  testWidgets('batch rename rule menu separates deletion from duplication', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchRenameRuleEditor(
            rule: const BatchNumberOp(),
            primary: true,
            slotId: 0,
            onChanged: (_) {},
            onValidityChanged: (_) {},
            onDuplicate: () {},
            onRemove: () {},
          ),
        ),
      ),
    );

    final menu = find.byType(PopupMenuButton<String>);
    expect(menu, findsOneWidget);
    final items = menuItemsFor(tester, menu);
    expectDividerImmediatelyBeforeValue(items, 'remove');
  });

  testWidgets('topic menu separates delete from topic actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopicItem(
            topic: Conversation(title: 'Topic', assistantId: 'assistant'),
            selectionMode: false,
            isSelected: false,
            isActive: false,
            onTap: () {},
            onDelete: () {},
            onPinToggle: () {},
            onRename: () {},
            onAutoRename: () {},
            onSelectionToggle: () {},
          ),
        ),
      ),
    );

    final menu = find.byType(PopupMenuButton<String>);
    expect(menu, findsOneWidget);
    final items = menuItemsFor(tester, menu);
    expectDividerImmediatelyBeforeValue(items, 'delete');
  });
}
