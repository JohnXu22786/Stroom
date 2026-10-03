import 'dart:io';

import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

class _InMemoryFlows extends TaskFlowNotifier {
  @override
  Future<bool> persist() async => true;
}

class _InMemoryExecutions extends TaskFlowExecutionNotifier {
  @override
  Future<bool> persist() async => true;
}

class _InputPicker extends FilePickerPlatform {
  _InputPicker(this.path, {this.reportedSize = 6});
  final String path;
  final int reportedSize;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    expect(type, FileType.any);
    expect(allowMultiple, isFalse);
    expect(withReadStream, isTrue);
    return FilePickerResult([
      PlatformFile(name: 'notes.pdf', size: reportedSize, path: path),
    ]);
  }
}

class _CaptureControl implements TaskFlowExecutionService {
  _CaptureControl({this.failLaunch = false, this.executions});
  final bool failLaunch;
  final TaskFlowExecutionNotifier? executions;
  List<FlowRunInput>? submitted;
  @override
  Future<void> launchFlowMany(String flowId, List<FlowRunInput> inputs) async {
    submitted = inputs;
    if (failLaunch) throw StateError('launch failed');
    for (final input in inputs) {
      if (input.ownedStoragePath == null || executions == null) continue;
      executions!.addExecution(
        flowId: flowId,
        flowName: 'Test flow',
        inputText: input.text,
        inputStoragePath: input.ownedStoragePath,
        persistImmediately: false,
      );
      await executions!.persist();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the builder page in run mode with a preloaded single-block flow.
Future<String> _pumpRunMode(
  WidgetTester tester,
  TaskFlowBlock block, {
  IOType? inputType,
  _CaptureControl? control,
  FlowRunInput? initialInput,
  TaskFlowNotifier? flows,
  TaskFlowExecutionNotifier? executions,
}) async {
  final flowNotifier = flows ?? TaskFlowNotifier();
  final flowId = flowNotifier.addFlow(
    name: '测试流程',
    inputType: inputType,
    blocks: [block],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskFlowListProvider.overrideWith((ref) => flowNotifier),
        if (executions != null)
          taskFlowExecutionsProvider.overrideWith((ref) => executions),
        if (control != null)
          taskFlowExecutionServiceProvider.overrideWithValue(control),
      ],
      child: MaterialApp(
        home: TaskFlowBuilderPage(
          flowId: flowId,
          startInRunMode: true,
          initialInput: initialInput,
        ),
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

    testWidgets('AudioSeparation first: multi-select video picker button',
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

    testWidgets('restored generic file input uses the file picker',
        (tester) async {
      final control = _CaptureControl();
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.chat),
          inputType: IOType.file,
          control: control,
          initialInput: const FlowRunInput(
              text: '/stored/previous.pdf', mimeType: 'application/pdf'));
      expect(find.text('选择文件'), findsOneWidget);
      expect(find.text('previous.pdf'), findsOneWidget);
      expect(find.text('输入文本或链接'), findsNothing);
      expect(_startButtonEnabled(tester), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, '开始任务流'));
      await tester.pump();
      expect(control.submitted!.single.mimeType, 'application/pdf');
    });

    testWidgets('generic file pick persists a copy and removal deletes it',
        (tester) async {
      final directory = Directory.systemTemp.createTempSync('flow_file_ui_');
      final source = File('${directory.path}/notes.pdf')
        ..writeAsStringSync('report');
      final originalPicker = FilePickerPlatform.instance;
      final originalDocuments = PathProviderPlatform.instance;
      FilePickerPlatform.instance = _InputPicker(source.path);
      PathProviderPlatform.instance = _Documents(directory.path);
      addTearDown(() {
        FilePickerPlatform.instance = originalPicker;
        PathProviderPlatform.instance = originalDocuments;
        directory.deleteSync(recursive: true);
      });
      final executions = _InMemoryExecutions();
      final control = _CaptureControl(executions: executions);
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.chat),
          inputType: IOType.file, control: control, executions: executions);
      expect(_startButtonEnabled(tester), isFalse);
      final storage = Directory('${directory.path}/attachments');
      Future<void> pickFile() async {
        await tester.runAsync(() async {
          await tester.tap(find.text('选择文件'));
          for (var attempt = 0; attempt < 100; attempt++) {
            if (storage.existsSync() &&
                storage.listSync().whereType<File>().isNotEmpty) {
              // The storage write finishes before the picker resolves the
              // copied path and updates the builder's selected-input row.
              await Future<void>.delayed(const Duration(milliseconds: 100));
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          fail('The selected document was not copied into app storage');
        });
        for (var attempt = 0;
            attempt < 100 && find.text('notes.pdf').evaluate().isEmpty;
            attempt++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pumpAndSettle();
      }

      await pickFile();
      expect(find.text('notes.pdf'), findsOneWidget);
      expect(_startButtonEnabled(tester), isTrue);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '选择文件'))
            .onPressed,
        isNull,
        reason: 'a second picker copy cannot leave without a durable record',
      );
      final firstCopy = storage.listSync().whereType<File>().single;
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('移除'));
        for (var attempt = 0;
            attempt < 100 && firstCopy.existsSync();
            attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(firstCopy.existsSync(), isFalse);
      expect(_startButtonEnabled(tester), isFalse);

      await pickFile();
      await tester.tap(find.widgetWithText(FilledButton, '开始任务流'));
      await tester.pump();
      final submitted = control.submitted;
      expect(submitted, hasLength(1));
      expect(submitted!.single.text, isNot(source.path));
      expect(File(submitted.single.text).readAsStringSync(), 'report');
      expect(submitted.single.fileName, 'notes.pdf');
      expect(submitted.single.ownedStoragePath, startsWith('attachments/'));
      expect(
        executions
            .referencesInputStoragePath(submitted.single.ownedStoragePath!),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(File(submitted.single.text).existsSync(), isTrue,
          reason: 'the durable execution owns the submitted copy');
    });

    testWidgets('failed launch keeps a picked file until leaving the builder',
        (tester) async {
      final directory = Directory.systemTemp.createTempSync('flow_file_fail_');
      final source = File('${directory.path}/notes.pdf')
        ..writeAsStringSync('report');
      final originalPicker = FilePickerPlatform.instance;
      final originalDocuments = PathProviderPlatform.instance;
      FilePickerPlatform.instance = _InputPicker(source.path);
      PathProviderPlatform.instance = _Documents(directory.path);
      addTearDown(() {
        FilePickerPlatform.instance = originalPicker;
        PathProviderPlatform.instance = originalDocuments;
        directory.deleteSync(recursive: true);
      });
      final control = _CaptureControl(failLaunch: true);
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.chat),
          inputType: IOType.file, control: control);
      final storage = Directory('${directory.path}/attachments');
      await tester.runAsync(() async {
        await tester.tap(find.text('选择文件'));
        for (var attempt = 0; attempt < 100; attempt++) {
          if (storage.existsSync() &&
              storage.listSync().whereType<File>().isNotEmpty) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('The selected document was not copied into app storage');
      });
      await tester.pumpAndSettle();
      final copy = storage.listSync().whereType<File>().single;
      await tester.tap(find.widgetWithText(FilledButton, '开始任务流'));
      await tester.pumpAndSettle();
      expect(control.submitted, hasLength(1));
      expect(copy.existsSync(), isTrue,
          reason: 'a failed launch can still be retried in the builder');
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        for (var attempt = 0; attempt < 100 && copy.existsSync(); attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(copy.existsSync(), isFalse);
    });

    testWidgets('file copy is discarded after editing to text and launching',
        (tester) async {
      final directory = Directory.systemTemp.createTempSync('flow_edit_input_');
      final source = File('${directory.path}/notes.pdf')
        ..writeAsStringSync('report');
      final originalPicker = FilePickerPlatform.instance;
      final originalDocuments = PathProviderPlatform.instance;
      FilePickerPlatform.instance = _InputPicker(source.path);
      PathProviderPlatform.instance = _Documents(directory.path);
      addTearDown(() {
        FilePickerPlatform.instance = originalPicker;
        PathProviderPlatform.instance = originalDocuments;
        directory.deleteSync(recursive: true);
      });
      final control = _CaptureControl();
      final flows = _InMemoryFlows();
      await _pumpRunMode(
        tester,
        TaskFlowBlock(
          typeKey: BlockType.chat,
          params: {'assistantId': 'selected-assistant'},
        ),
        inputType: IOType.file,
        control: control,
        flows: flows,
      );
      final storage = Directory('${directory.path}/attachments');
      await tester.runAsync(() async {
        await tester.tap(find.text('选择文件'));
        for (var attempt = 0; attempt < 100; attempt++) {
          if (storage.existsSync() &&
              storage.listSync().whereType<File>().isNotEmpty) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('The selected document was not copied into app storage');
      });
      await tester.pumpAndSettle();
      final copy = storage.listSync().whereType<File>().single;
      expect(copy.existsSync(), isTrue);

      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<IOType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('文本').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<IOType>>(find.byType(DropdownButton<IOType>))
            .value,
        IOType.text,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('输入文本或链接'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Summarize this');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, '开始任务流'));
        for (var attempt = 0; attempt < 100 && copy.existsSync(); attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      expect(control.submitted, hasLength(1));
      expect(control.submitted!.single.text, 'Summarize this');
      expect(control.submitted!.single.ownedStoragePath, isNull);
      expect(copy.existsSync(), isFalse,
          reason: 'the edited-out picker copy was not submitted');
      expect(source.existsSync(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(copy.existsSync(), isFalse);
    });

    testWidgets('generic file picker checks metadata before copying',
        (tester) async {
      final directory = Directory.systemTemp.createTempSync('flow_file_size_');
      final source = File('${directory.path}/notes.pdf')
        ..writeAsStringSync('report');
      final originalPicker = FilePickerPlatform.instance;
      final originalDocuments = PathProviderPlatform.instance;
      FilePickerPlatform.instance =
          _InputPicker(source.path, reportedSize: 10 * 1024 * 1024 + 1);
      PathProviderPlatform.instance = _Documents(directory.path);
      addTearDown(() {
        FilePickerPlatform.instance = originalPicker;
        PathProviderPlatform.instance = originalDocuments;
        directory.deleteSync(recursive: true);
      });
      await _pumpRunMode(tester, TaskFlowBlock(typeKey: BlockType.chat),
          inputType: IOType.file);
      await tester.runAsync(() async {
        await tester.tap(find.text('选择文件'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('超过 10 MB'), findsOneWidget);
      expect(_startButtonEnabled(tester), isFalse);
      expect(Directory('${directory.path}/attachments').existsSync(), isFalse);
    });
  });
}
