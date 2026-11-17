import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/flow_block_card.dart';

void main() {
  testWidgets('regular phone keeps the compact inline block header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cardAtWidth(358));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('1. Audio Separation'));
    final temporaryOutput = tester.getRect(find.byType(Checkbox));

    expect(find.text('Temporary'), findsOneWidget);
    expect((title.center.dy - temporaryOutput.center.dy).abs(), lessThan(20));
  });

  testWidgets('very narrow phone stacks the title above action controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cardAtWidth(288));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('1. Audio Separation'));
    final temporaryOutput = tester.getRect(find.byType(Checkbox));

    expect(title.bottom, lessThan(temporaryOutput.top));
  });

  testWidgets('tablet block title and action controls stay in one row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cardAtWidth(768));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('1. Audio Separation'));
    final temporaryOutput = tester.getRect(find.byType(Checkbox));

    expect((title.center.dy - temporaryOutput.center.dy).abs(), lessThan(20));
  });

  testWidgets('phone block card tolerates dark theme and larger text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_cardAtWidth(358, theme: ThemeData.dark()));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('1. Audio Separation'));
    final temporaryOutput = tester.getRect(find.byType(Checkbox));
    expect(title.bottom, lessThan(temporaryOutput.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu exposes duplicate and movement with disabled boundary', (
    tester,
  ) async {
    var duplicates = 0;
    var moves = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: FlowBlockCard(
              block: TaskFlowBlock(typeKey: BlockType.chat),
              index: 1,
              isFirst: true,
              onDuplicate: () => duplicates++,
              onMoveDown: () => moves++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<int>>(
            find.widgetWithText(PopupMenuItem<int>, '上移（已在最前）'),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('复制功能块'));
    await tester.pumpAndSettle();
    expect(duplicates, 1);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下移'));
    await tester.pumpAndSettle();
    expect(moves, 1);
  });

  testWidgets('unsupported blocks still offer replacement and deletion', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: FlowBlockCard(
              block: TaskFlowBlock(typeKey: BlockType.custom),
              index: 1,
              isFirst: true,
              onDelete: () => removed = true,
              onReplace: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('未知功能块'), findsOneWidget);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<int>>(
            find.widgetWithText(PopupMenuItem<int>, '替换功能块'),
          )
          .enabled,
      isTrue,
    );
    await tester.tap(find.text('删除功能块'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });
}

Widget _cardAtWidth(double width, {ThemeData? theme}) => ProviderScope(
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: FlowBlockCard(
                block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
                index: 1,
                isFirst: true,
                isLast: false,
                onTemporaryOutputChanged: (_) {},
                onSettings: () {},
                onReplace: () {},
                onDelete: () {},
                onDuplicate: () {},
                onMoveUp: () {},
                onMoveDown: () {},
                onInsertBefore: () {},
                onInsertAfter: () {},
              ),
            ),
          ),
        ),
      ),
    );
