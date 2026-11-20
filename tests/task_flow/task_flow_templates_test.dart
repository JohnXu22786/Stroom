import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_templates.dart';
import 'package:stroom/task_flow/pages/task_flow_list_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';

class _TaskFlowNotifierWithState extends TaskFlowNotifier {
  _TaskFlowNotifierWithState(TaskFlowDefinition flow) {
    state = [flow];
  }
}

void main() {
  test(
      'template drafts keep independent identities and require real configuration',
      () {
    for (final template in taskFlowTemplates) {
      final first = template.createDraft();
      final second = template.createDraft();
      expect(first.id, isNot(second.id));
      expect(
          first.blocks
              .map((block) => block.id)
              .toSet()
              .intersection(second.blocks.map((block) => block.id).toSet()),
          isEmpty);
      for (final block in first.blocks) {
        if ([BlockType.asr, BlockType.ocr, BlockType.tts]
            .contains(block.typeKey)) {
          expect(block.params['modelRef'], anyOf(isNull, isEmpty));
        }
        if (block.typeKey == BlockType.chat) {
          expect(block.params['assistantId'], isEmpty);
        }
        block.params['configuredLater'] = {
          'model': ['changed']
        };
      }
      expect(
          second.blocks
              .any((block) => block.params.containsKey('configuredLater')),
          isFalse);
      expect(
          template
              .createDraft()
              .blocks
              .any((block) => block.params.containsKey('configuredLater')),
          isFalse);
    }
  });

  testWidgets('template chooser displays localized built-in templates',
      (tester) async {
    Future<void> openTemplates(Locale locale) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const TaskFlowListPage(),
          ),
        ),
      );
      final openButton =
          locale.languageCode == 'en' ? 'Start from a template' : '从示例模板开始';
      await tester.tap(find.text(openButton));
      await tester.pumpAndSettle();
    }

    await openTemplates(const Locale('en', 'US'));
    expect(find.text('Choose an Example Template'), findsOneWidget);
    expect(find.text('Transcribe and Summarize a Recording'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await openTemplates(const Locale('zh', 'CN'));
    expect(find.text('选择示例模板'), findsOneWidget);
    expect(find.text('录音转写与总结'), findsOneWidget);
  });

  testWidgets('saved flow previews localize built-in block labels',
      (tester) async {
    final flow = TaskFlowDefinition(
      name: 'Example Flow',
      inputType: IOType.image,
      blocks: [
        TaskFlowBlock(typeKey: BlockType.ocr),
        TaskFlowBlock(typeKey: BlockType.chat),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskFlowListProvider.overrideWith(
            (ref) => _TaskFlowNotifierWithState(flow),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const TaskFlowListPage(),
        ),
      ),
    );

    expect(find.text('OCR → Assistant Chat'), findsOneWidget);
  });

  testWidgets(
      'block-count metadata preserves fit and reveals clipped Portuguese text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final flow = TaskFlowDefinition(
      name: 'Flow',
      blocks: List.generate(99, (_) => TaskFlowBlock(typeKey: BlockType.ocr)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    );

    Widget buildPage(TextScaler textScaler) => ProviderScope(
          overrides: [
            taskFlowListProvider.overrideWith(
              (ref) => _TaskFlowNotifierWithState(flow),
            ),
          ],
          child: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: MaterialApp(
              locale: const Locale('pt', 'BR'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const TaskFlowListPage(),
            ),
          ),
        );

    await tester.pumpWidget(
      buildPage(const TextScaler.linear(4)),
    );

    final strings = AppLocalizations.of(tester.element(
      find.byType(TaskFlowListPage),
    ))!;
    final countFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText &&
          widget.data == strings.taskFlowBlockCount(99),
    );
    final updatedFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText &&
          widget.data == strings.commonHoursAgo(5),
    );
    final count = tester.widget<ConstrainedText>(countFinder);
    final updated = tester.widget<ConstrainedText>(updatedFinder);
    double naturalWidth(ConstrainedText label, TextScaler scaler) =>
        (TextPainter(
          text: TextSpan(text: label.data, style: label.style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          locale: const Locale('pt', 'BR'),
        )..layout())
            .width;

    expect(count.data, strings.taskFlowBlockCount(99));
    expect(updated.data, strings.commonHoursAgo(5));
    expect(
      tester.getSize(countFinder).width,
      lessThan(naturalWidth(count, const TextScaler.linear(4))),
      reason: 'The localized block count clips in the narrow, scaled row.',
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(buildPage(const TextScaler.linear(1)));
    final fitCount = tester.widget<ConstrainedText>(countFinder);
    final fitUpdated = tester.widget<ConstrainedText>(updatedFinder);
    final fitRow =
        find.ancestor(of: countFinder, matching: find.byType(Row)).first;
    final naturalCountWidth = naturalWidth(
      fitCount,
      const TextScaler.linear(1),
    );
    final naturalUpdatedWidth = naturalWidth(
      fitUpdated,
      const TextScaler.linear(1),
    );
    expect(
      tester.getSize(countFinder).width,
      closeTo(naturalCountWidth, 0.5),
    );
    expect(
      tester.getSize(updatedFinder).width,
      closeTo(naturalUpdatedWidth, 0.5),
    );
    expect(
      tester.getRect(countFinder).left,
      closeTo(tester.getRect(fitRow).left, 0.5),
    );
    expect(
      tester.getRect(updatedFinder).right,
      closeTo(tester.getRect(fitRow).right, 0.5),
    );
    expect(tester.takeException(), isNull);
  });
}
