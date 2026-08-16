import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';

/// Pumps the builder page in run mode with a preloaded single-block flow.
Future<String> _pumpRunMode(
  WidgetTester tester,
  TaskFlowBlock block,
) async {
  final flowNotifier = TaskFlowNotifier();
  final flowId = flowNotifier.addFlow(
    name: '测试流程',
    blocks: [block],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskFlowListProvider.overrideWith((ref) => flowNotifier),
      ],
      child: MaterialApp(
        home: TaskFlowBuilderPage(flowId: flowId, startInRunMode: true),
      ),
    ),
  );
  await tester.pump();
  return flowId;
}

bool _startButtonEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, '开始任务流'),
  );
  return button.onPressed != null;
}

void main() {
  group('Task flow run-mode input adapts to the FIRST block', () {
    testWidgets(
        'CatCatch first: URL + 时/分/秒 box, start disabled until a valid '
        'URL is entered', (tester) async {
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.catcatch));

      // Header names the first block, not the generic input type.
      expect(find.text('输入（下载网页资源）'), findsOneWidget);

      // Empty state: no URL field yet, add button present, start disabled.
      expect(find.text('添加网页资源'), findsOneWidget);
      expect(_startButtonEnabled(tester), isFalse);

      // Add an entry → the CatCatch main box appears (URL + 时/分/秒).
      await tester.tap(find.text('添加网页资源'));
      await tester.pump();
      expect(find.text('请输入视频/音频网页URL'), findsOneWidget);
      expect(find.text('时'), findsOneWidget);
      expect(find.text('分'), findsOneWidget);
      expect(find.text('秒'), findsOneWidget);
      expect(find.textContaining('预览'), findsOneWidget);
      expect(_startButtonEnabled(tester), isFalse);

      // Invalid URL keeps the start button disabled.
      await tester.enterText(
        find.widgetWithText(TextField, '请输入视频/音频网页URL'),
        'not-a-url',
      );
      await tester.pump();
      expect(_startButtonEnabled(tester), isFalse);

      // Valid URL enables start.
      await tester.enterText(
        find.widgetWithText(TextField, '请输入视频/音频网页URL'),
        'https://example.com/video',
      );
      await tester.pump();
      expect(_startButtonEnabled(tester), isTrue);
    });

    testWidgets(
        'OCR first: multi-select image picker button, no manual '
        'path/identifier text field', (tester) async {
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.ocr));

      expect(find.text('选择图片（可多选）'), findsOneWidget);
      // The old "输入 图片 路径或标识" manual field must be gone — the
      // user must pick real files ("必须确切的选择").
      expect(find.textContaining('路径或标识'), findsNothing);
      expect(_startButtonEnabled(tester), isFalse);
    });

    testWidgets('ASR first: multi-select audio picker button', (tester) async {
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.asr));

      expect(find.text('选择音频（可多选）'), findsOneWidget);
      expect(find.textContaining('路径或标识'), findsNothing);
    });

    testWidgets(
        'AudioSeparation first: multi-select video picker button',
        (tester) async {
      await _pumpRunMode(
        tester,
        TaskFlowBlock(typeKey: BlockType.audioSeparation),
      );

      expect(find.text('选择视频（可多选）'), findsOneWidget);
      expect(find.textContaining('路径或标识'), findsNothing);
    });

    testWidgets('TTS first: plain text input box', (tester) async {
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.tts));

      expect(find.text('输入（语音合成）'), findsOneWidget);
      expect(find.text('输入文本或链接'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
