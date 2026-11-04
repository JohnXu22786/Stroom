import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/models/built_in_assistants.dart';
import 'package:stroom/models/built_in_prompts.dart';
import 'package:stroom/models/ocr_output_template.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/pages/assistant/built_in_prompt_selector.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';
import 'package:stroom/providers/system_assistant_provider.dart';
import 'package:stroom/task_flow/models/task_flow_templates.dart';

void main() {
  group('built-in content localization', () {
    test('ARB resources have matching keys and valid JSON', () {
      final files = [
        'lib/l10n/app_en.arb',
        'lib/l10n/app_en_US.arb',
        'lib/l10n/app_zh.arb',
        'lib/l10n/app_zh_CN.arb',
      ];
      final resources = files
          .map((path) => jsonDecode(File(path).readAsStringSync()) as Map)
          .toList();
      final templateKeys = resources.first.keys.toSet();

      for (final resource in resources.skip(1)) {
        expect(resource.keys.toSet(), unorderedEquals(templateKeys));
      }
      for (final resource in resources) {
        for (final value in resource.values.whereType<String>()) {
          expect(value, isNotEmpty);
        }
      }
      final placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');
      for (final key in templateKeys.where((key) => !key.startsWith('@'))) {
        final english = placeholder
            .allMatches(resources[1][key] as String)
            .map((match) => match.group(1))
            .toSet();
        final chinese = placeholder
            .allMatches(resources[3][key] as String)
            .map((match) => match.group(1))
            .toSet();
        expect(chinese, english, reason: 'Placeholder mismatch for $key');
      }
    });

    test('English count labels use singular forms for a count of one', () {
      final strings = AppLocalizationsEnUs();

      expect(strings.taskFlowTemplateCount(1), '1 template');
      expect(strings.taskFlowTemplateCount(2), '2 templates');
      expect(strings.taskFlowBlockCount(1), '1 block');
      expect(strings.taskFlowBlockCount(2), '2 blocks');
      expect(strings.ocrConcurrencyOption(1), '1 concurrent request');
      expect(strings.ocrConcurrencyOption(2), '2 concurrent requests');
      expect(strings.ocrConcurrencyStatus(1), '1 concurrent request');
      expect(strings.ocrConcurrencyStatus(2), '2 concurrent requests');
      expect(strings.ocrSelectedImagesCount(1), '1 image selected');
      expect(strings.ocrSelectedImagesCount(2), '2 images selected');
      expect(
        strings.ocrRechooseRequiredImages(1),
        'Select all 1 image again before retrying.',
      );
      expect(
        strings.ocrRechooseRequiredImages(2),
        'Select all 2 images again before retrying.',
      );
      expect(strings.ocrImagesLoaded(1), 'Loaded 1 image');
      expect(strings.ocrImagesLoaded(2), 'Loaded 2 images');
      expect(strings.contextModelOverrideCount(1), '1 model-specific override');
      expect(
        strings.contextModelOverrideCount(2),
        '2 model-specific overrides',
      );
    });

    test(
      'built-in prompts are available in English and Simplified Chinese',
      () {
        final english = localizedBuiltInPrompts(AppLocalizationsEnUs());
        final chinese = localizedBuiltInPrompts(AppLocalizationsZhCn());

        expect(english, hasLength(builtInPrompts.length));
        expect(chinese, hasLength(builtInPrompts.length));
        expect(english.first.name, 'General Assistant');
        expect(
          english.first.prompt,
          contains('Answer the user in the language they use'),
        );
        expect(chinese.first.name, '通用助手');
        expect(chinese.first.prompt, contains('请使用用户所用的语言回答问题'));
        expect(
          english.map((prompt) => prompt.name).toSet(),
          hasLength(english.length),
        );
      },
    );

    test('system assistant prompts follow the selected app locale', () {
      final english = localizedBuiltInSystemAssistantById(
        kBuiltInTitleAssistantId,
        AppLocalizationsEnUs(),
      )!;
      final chinese = localizedBuiltInSystemAssistantById(
        kBuiltInTitleAssistantId,
        AppLocalizationsZhCn(),
      )!;

      expect(english.name, 'Title Assistant');
      expect(english.prompt, contains('You are a title generator'));
      expect(chinese.name, '标题助手');
      expect(chinese.prompt, contains('你是一个标题生成器'));

      final englishCompaction = localizedBuiltInSystemAssistantById(
        kBuiltInCompactionAssistantId,
        AppLocalizationsEnUs(),
      )!;
      final chineseCompaction = localizedBuiltInSystemAssistantById(
        kBuiltInCompactionAssistantId,
        AppLocalizationsZhCn(),
      )!;
      for (final prompt in [
        english.prompt,
        chinese.prompt,
        englishCompaction.prompt,
        chineseCompaction.prompt,
      ]) {
        expect(prompt, isNot(startsWith('\n')));
        expect(prompt, isNot(endsWith('\n')));
      }

      const customPrompt = 'User-edited prompt: keep this text';
      expect(
        resolveSystemAssistantPrompt(
          const SystemAssistantTaskConfig(prompt: customPrompt),
          defaultAssistantId: kBuiltInTitleAssistantId,
          strings: AppLocalizationsEnUs(),
        ),
        customPrompt,
      );
    });

    test('task flow templates localize labels and created drafts', () {
      final english = localizedTaskFlowTemplates(AppLocalizationsEnUs()).first;
      final chinese = localizedTaskFlowTemplates(AppLocalizationsZhCn()).first;

      expect(english.name, 'Transcribe and Summarize a Recording');
      expect(english.description, contains('speech recognition'));
      expect(english.createDraft().name, english.name);
      expect(chinese.name, '录音转写与总结');
      expect(chinese.createDraft().description, chinese.description);
    });

    test('OCR output templates localize labels and model instructions', () {
      final english = localizedOcrOutputTemplates(AppLocalizationsEnUs()).first;
      final chinese = localizedOcrOutputTemplates(AppLocalizationsZhCn()).first;

      expect(english.label, 'Plain Text');
      expect(english.content, contains('Transcribe all visible text'));
      expect(chinese.label, '纯文本模板');
      expect(chinese.content, contains('请按页面的自然阅读顺序转录'));
      expect(english.selectionValue, chinese.selectionValue);
    });

    test(
      'OCR request localizes built-in instructions but preserves user text',
      () {
        const userInstruction = OcrInstruction(content: 'Keep my OCR wording');

        expect(
          selectedOcrInstructionContent(
            [userInstruction],
            0,
            strings: AppLocalizationsEnUs(),
          ),
          userInstruction.content,
        );
        expect(
          selectedOcrInstructionContent(
            [userInstruction],
            -3,
            strings: AppLocalizationsEnUs(),
          ),
          AppLocalizationsEnUs().ocrTemplatePlainTextContent,
        );
      },
    );

    testWidgets('built-in prompt market renders English and Chinese', (
      tester,
    ) async {
      Future<void> pumpMarket(Locale locale) async {
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
              home: const _PromptMarketLauncher(),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-market')));
        await tester.pumpAndSettle();
      }

      await pumpMarket(const Locale('en', 'US'));
      expect(find.text('Assistant Market'), findsOneWidget);
      expect(find.text('General Assistant'), findsOneWidget);
      expect(
        find.text(
          'Imported prompts become regular assistants that you can edit freely.',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpMarket(const Locale('zh', 'CN'));
      expect(find.text('助手市场'), findsOneWidget);
      expect(find.text('通用助手'), findsOneWidget);
      expect(find.text('选择后将添加为普通助手，之后可自由编辑'), findsOneWidget);
    });
  });
}

class _PromptMarketLauncher extends ConsumerWidget {
  const _PromptMarketLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: TextButton(
          key: const Key('open-market'),
          onPressed: () => showBuiltInPromptSelector(context, ref),
          child: const Text('Open'),
        ),
      );
}
