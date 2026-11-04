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
}
