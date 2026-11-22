import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/flow_block_card.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('narrow localized header preserves title and card actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var settings = 0;
    var replacements = 0;
    bool? temporaryOutput;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: FlowBlockCard(
            block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
            index: 1,
            isFirst: true,
            isLast: false,
            onSettings: () => settings++,
            onReplace: () => replacements++,
            onTemporaryOutputChanged: (value) => temporaryOutput = value,
          ),
        ),
      ),
    ));

    expect(find.text('1. Separação de áudio'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byTooltip('Definir parâmetros'), findsOneWidget);
    expect(find.byTooltip('Substituir bloco'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Definir parâmetros'));
    await tester.tap(find.byTooltip('Substituir bloco'));
    await tester.tap(find.byType(Checkbox));
    expect(settings, 1);
    expect(replacements, 1);
    expect(temporaryOutput, isTrue);
  });

  testWidgets('wide header keeps actions beside the title at larger text scale',
      (tester) async {
    tester.view.physicalSize = const Size(700, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: FlowBlockCard(
              block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
              index: 1,
              isFirst: true,
              isLast: false,
              onTemporaryOutputChanged: (_) {},
            ),
          ),
        ),
      ),
    ));

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('Audiotrennung'), findsOneWidget);
    final title = tester.widget<ConstrainedText>(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data.startsWith('1. '),
      ),
    );
    expect(title.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu exposes duplicate and movement with disabled boundary',
      (tester) async {
    var duplicates = 0;
    var moves = 0;
    await tester.pumpWidget(ProviderScope(
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
    ));
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PopupMenuItem<int>>(
                find.widgetWithText(PopupMenuItem<int>, '上移（已在最前）'))
            .enabled,
        isFalse);
    await tester.tap(find.text('复制功能块'));
    await tester.pumpAndSettle();
    expect(duplicates, 1);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下移'));
    await tester.pumpAndSettle();
    expect(moves, 1);
  });

  testWidgets('unsupported blocks still offer replacement and deletion',
      (tester) async {
    var removed = false;
    await tester.pumpWidget(ProviderScope(
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
    ));
    expect(find.textContaining('未知功能块'), findsOneWidget);
    await tester.tap(find.byTooltip('步骤 1 操作'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PopupMenuItem<int>>(
                find.widgetWithText(PopupMenuItem<int>, '替换功能块'))
            .enabled,
        isTrue);
    await tester.tap(find.text('删除功能块'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });
}
