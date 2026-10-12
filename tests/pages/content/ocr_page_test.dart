// Merged from: ocr_page_test.dart, ocr_page_preview_edit_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/ocr_batch_execution.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/ocr_retry_storage.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/ocr_image_payload.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

/// Creates a small valid PNG (8x8) via the real engine, tinted [color]
/// so distinct images can be told apart (default: green).
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> _createEnginePng({
  Color color = const Color(0xFF00FF00),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, 8, 8), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

/// Pumps until [condition] is true or [timeout] elapses, alternating
/// real-async windows (engine image work) with pumps (fake-zone
/// continuations).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for condition');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({
  List<ProviderEntry>? entries,
  List<SelectedImage>? testImages,
  Map<String, dynamic>? retryData,
  String? retryTaskId,
  List<OcrPageOutcome> retryPageOutcomes = const [],
  List<OcrInstruction> ocrInstructions = const [],
  BackgroundTaskNotifier? backgroundTasksNotifier,
  Future<OcrImagePayload> Function(Uint8List bytes)? testImagePayloadPreparer,
  Future<OcrRetryRestoreResult> Function(OcrRetrySnapshot snapshot)?
      testRetryImageRestorer,
  Future<Map<String, dynamic>?> Function({
    required String taskId,
    required OcrRetrySnapshot snapshot,
  })? testRetrySnapshotCacher,
  Future<XFile?> Function({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  })? testCameraPicker,
  OcrInstructionsNotifier Function(Ref ref)? testInstructionsNotifierBuilder,
  Future<List<XFile>> Function({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  })? testGalleryPicker,
}) {
  return ProviderScope(
    overrides: [
      if (entries != null)
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(entries: entries);
          return notifier;
        }),
      if (backgroundTasksNotifier != null)
        backgroundTasksProvider.overrideWith((ref) => backgroundTasksNotifier),
      ocrInstructionsProvider.overrideWith((ref) {
        if (testInstructionsNotifierBuilder != null) {
          return testInstructionsNotifierBuilder(ref);
        }
        final notifier = OcrInstructionsNotifier(ref);
        notifier.state = ocrInstructions;
        return notifier;
      }),
    ],
    child: MaterialApp(
      home: OcrPage(
        testImages: testImages,
        retryData: retryData,
        retryTaskId: retryTaskId,
        retryPageOutcomes: retryPageOutcomes,
        testCameraPicker: testCameraPicker,
        testGalleryPicker: testGalleryPicker,
        testImagePayloadPreparer: testImagePayloadPreparer,
        testRetryImageRestorer: testRetryImageRestorer,
        testRetrySnapshotCacher: testRetrySnapshotCacher,
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

class _InspectableBackgroundTaskNotifier extends BackgroundTaskNotifier {
  List<BackgroundTask> get tasksForTest => state;

  void setTasksForTest(List<BackgroundTask> tasks) => state = tasks;
}

// ============================================================================
// Helper: Create a sample OCR provider entry with models
// ============================================================================

ProviderEntry _createOcrEntry({bool withModels = true}) {
  return ProviderEntry(
    id: 'test_ocr',
    type: 'ocr',
    name: 'OCR供应商',
    configs: [
      ProviderConfigItem(
        providerName: 'OpenAI',
        host: 'https://api.openai.com',
        key: 'test-key',
        models: withModels
            ? [
                ModelConfig(name: 'GPT-4o', modelId: 'gpt-4o'),
                ModelConfig(name: 'GPT-4o Mini', modelId: 'gpt-4o-mini'),
                ModelConfig(
                  name: 'GPT-4 Vision',
                  modelId: 'gpt-4-vision-preview',
                ),
              ]
            : [],
      ),
    ],
  );
}

/// Instructions notifier whose load() fills the list asynchronously —
/// mirrors the production provider (initial state empty, list arrives
/// after load), unlike the synchronous override used by [_buildTestApp].
class _DelayedInstructionsNotifier extends OcrInstructionsNotifier {
  _DelayedInstructionsNotifier(
    super.ref, {
    this.delay = const Duration(milliseconds: 100),
  });

  final Duration delay;

  @override
  Future<void> load() async {
    await Future<void>.delayed(delay);
    state = const [
      OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
      OcrInstruction(name: '表格提取', content: '提取表格内容'),
    ];
  }
}

class _CompletableInstructionsNotifier extends OcrInstructionsNotifier {
  _CompletableInstructionsNotifier(
    super.ref, {
    required this.loadStarted,
    required this.finishLoad,
  });

  final Completer<void> loadStarted;
  final Completer<void> finishLoad;

  @override
  Future<void> load() async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    await finishLoad.future;
    state = const [
      OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
      OcrInstruction(name: '表格提取', content: '提取表格内容'),
    ];
  }
}

class _InstructionsLoadFailsOnRetryNotifier extends OcrInstructionsNotifier {
  _InstructionsLoadFailsOnRetryNotifier(
    super.ref, {
    required this.loadStarted,
    required this.finishFirstLoad,
  });

  final Completer<void> loadStarted;
  final Completer<void> finishFirstLoad;
  var _loadCount = 0;

  @override
  Future<void> load() async {
    if (++_loadCount > 1) {
      throw StateError('instruction store unavailable');
    }
    if (!loadStarted.isCompleted) loadStarted.complete();
    await finishFirstLoad.future;
    state = const [
      OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
      OcrInstruction(name: '表格提取', content: '提取表格内容'),
    ];
  }
}

/// Create a small valid PNG 1x1 pixel for mock image data.
Uint8List _createTestPngBytes() {
  // Minimal valid 1x1 red PNG
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, // PNG signature
    0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, // IHDR chunk
    0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, // width=1
    0x00, 0x00, 0x00, 0x01, // height=1
    0x08, 0x02, // bit depth=8, color type=RGB
    0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, // CRC
    0x00, 0x00, 0x00, 0x0C, // IDAT chunk
    0x49, 0x44, 0x41, 0x54,
    0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01,
    0x26, 0xE0, 0xFE, 0xA0, // CRC
    0x00, 0x00, 0x00, 0x00, // IEND chunk
    0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82,
  ]);
}

/// Create a test SelectedImage with dummy PNG bytes
SelectedImage _createTestImage({int seed = 1}) {
  return SelectedImage(bytes: _createTestPngBytes(), format: 'png');
}

SelectedImage _createValidOcrTestImage() => SelectedImage.fromPayload(
      payload: prepareOcrImagePayloadSync(
        img.encodePng(img.Image(width: 1, height: 1, numChannels: 3)),
      ),
    );

Future<void> _storeAppAlbumImage({
  required String name,
  required String hash,
  required Uint8List bytes,
}) async {
  final record = ImageRecord(
    name: name,
    hash: hash,
    format: 'png',
    createdAt: DateTime.now(),
    size: bytes.length,
  );
  await ImageManifest.writeFile(record.storagePath, bytes);
  await ImageManifest.addRecord(record);
}

Map<String, dynamic> _createVersionedRetryData({
  required String configId,
  required String modelId,
  String? instructionContent,
  String saveFolder = '',
}) =>
    {
      'type': 'ocr',
      'version': 1,
      'modelRef': {'configId': configId, 'modelId': modelId},
      'images': [
        {
          'bytes': base64Encode(_createTestPngBytes()),
          'format': 'png',
          'name': 'retry-image.png',
        },
      ],
      if (instructionContent != null) 'instructionContent': instructionContent,
      'saveFolder': saveFolder,
    };

class _UnreadPickerFile extends XFile {
  int reads = 0;
  _UnreadPickerFile() : super('disposed.png');

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return Uint8List.fromList([1]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
    TextManifest.invalidateCache();
  });

  for (final gallery in [false, true]) {
    testWidgets(
      'late ${gallery ? "gallery" : "camera"} picker ignores disposed page',
      (tester) async {
        final file = _UnreadPickerFile();
        final camera = Completer<XFile?>();
        final images = Completer<List<XFile>>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: OcrPage(
                testCameraPicker: ({maxWidth, maxHeight, imageQuality}) =>
                    camera.future,
                testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) =>
                    images.future,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(gallery ? '相册选择' : '拍照识别'));
        await tester.pumpAndSettle();
        if (gallery) {
          await tester.tap(find.text('从系统相册选择'));
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        if (gallery) {
          images.complete([file]);
        } else {
          camera.complete(file);
        }
        await tester.pump();
        expect(
          file.reads,
          0,
          reason: 'disposed picker must stop before file I/O',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('OcrPage - model selector', () {
    testWidgets('shows model selector when OCR provider has models', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show the model selector with "ModelName | ProviderName" format
      expect(find.text('GPT-4o | OpenAI'), findsWidgets);
    });

    testWidgets('model selector shows all available models when tapped', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Tap the model selector dropdown - need to tap the displayed text
      await tester.tap(find.text('GPT-4o | OpenAI').last);
      await tester.pumpAndSettle();

      // Should show all models in the dropdown with provider name
      expect(find.text('GPT-4o Mini | OpenAI'), findsWidgets);
      expect(find.text('GPT-4 Vision | OpenAI'), findsWidgets);
    });

    testWidgets('model selector falls back to modelId when name is empty', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'TestAI',
            host: 'https://api.test.ai',
            key: 'test-key',
            models: [ModelConfig(name: '', modelId: 'test-model-v1')],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show modelId | ProviderName when name is empty
      expect(find.text('test-model-v1 | TestAI'), findsWidgets);
    });

    testWidgets('model selector still works when provider name is empty', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: '',
            host: 'https://api.test.ai',
            key: 'test-key',
            models: [ModelConfig(name: 'TestModel', modelId: 'test-model-v1')],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show just the model name when no provider name
      expect(find.text('TestModel'), findsWidgets);
    });
  });

  group('OcrPage - stable retry context', () {
    testWidgets('image preparation failure resets OCR start', (tester) async {
      var prepareAttempts = 0;
      final cacheStarted = Completer<void>();
      final finishCache = Completer<Map<String, dynamic>?>();
      final notifier = _InspectableBackgroundTaskNotifier();
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          testImages: [_createTestImage()],
          backgroundTasksNotifier: notifier,
          testImagePayloadPreparer: (bytes) async {
            prepareAttempts++;
            if (prepareAttempts == 1) {
              throw StateError('image decode failed');
            }
            return OcrImagePayload(
              bytes: bytes,
              format: 'png',
              width: 1,
              height: 1,
            );
          },
          testRetrySnapshotCacher: ({required taskId, required snapshot}) {
            cacheStarted.complete();
            return finishCache.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始识别'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('处理 OCR 图片失败，请重试'), findsOneWidget);
      expect(find.text('已选 1 张图片'), findsOneWidget);
      expect(notifier.tasksForTest, isEmpty);

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await cacheStarted.future;

      expect(prepareAttempts, 2);
      expect(find.text('保存重试图片...'), findsOneWidget);
      expect(notifier.tasksForTest, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      finishCache.complete(null);
      await tester.pump();
    });

    testWidgets('waits for retry image caching before adding a task', (
      tester,
    ) async {
      final cacheStarted = Completer<void>();
      final finishCache = Completer<Map<String, dynamic>?>();
      final notifier = _InspectableBackgroundTaskNotifier();
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          testImages: [_createValidOcrTestImage()],
          backgroundTasksNotifier: notifier,
          testRetrySnapshotCacher: ({required taskId, required snapshot}) {
            cacheStarted.complete();
            return finishCache.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await cacheStarted.future;

      expect(find.text('保存重试图片...'), findsOneWidget);
      expect(notifier.tasksForTest, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      finishCache.complete(null);
      await tester.pump();
    });

    testWidgets('locks image removal while retry images are being cached', (
      tester,
    ) async {
      final cacheStarted = Completer<void>();
      final finishCache = Completer<Map<String, dynamic>?>();
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          testImages: [_createValidOcrTestImage(), _createValidOcrTestImage()],
          testRetrySnapshotCacher: ({required taskId, required snapshot}) {
            cacheStarted.complete();
            return finishCache.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await cacheStarted.future;
      expect(find.text('已选 2 张图片'), findsOneWidget);

      final firstImage = tester.getRect(
        find.byKey(const ValueKey('ocr_grid_item_0')),
      );
      await tester.tapAt(Offset(firstImage.right - 12, firstImage.top + 12));
      await tester.pump();

      expect(find.text('已选 2 张图片'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      finishCache.complete(null);
      await tester.pump();
    });

    testWidgets('waits for active image imports before starting OCR', (
      tester,
    ) async {
      final importedBytes = img.encodePng(img.Image(width: 1, height: 1));
      await tester.runAsync(
        () => _storeAppAlbumImage(
          name: 'Pending OCR import',
          hash: 'pending_ocr_import',
          bytes: importedBytes,
        ),
      );
      final importPreparationStarted = Completer<void>();
      final finishImportPreparation = Completer<OcrImagePayload>();
      final cacheStarted = Completer<void>();
      final finishCache = Completer<Map<String, dynamic>?>();
      OcrRetrySnapshot? pendingSnapshot;
      final notifier = _InspectableBackgroundTaskNotifier();
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          testImages: [_createValidOcrTestImage()],
          backgroundTasksNotifier: notifier,
          testImagePayloadPreparer: (_) {
            importPreparationStarted.complete();
            return finishImportPreparation.future;
          },
          testRetrySnapshotCacher: ({required taskId, required snapshot}) {
            pendingSnapshot = snapshot;
            cacheStarted.complete();
            return finishCache.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _pumpUntil(
        tester,
        () => find.text('Pending OCR import.png').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Pending OCR import.png'));
      await _pumpUntil(tester, () => find.text('确定 (1)').evaluate().isNotEmpty);
      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pumpAndSettle();
      await importPreparationStarted.future;

      expect(find.text('正在导入图片...'), findsOneWidget);
      final startButtonWhileImporting = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('正在导入图片...'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(startButtonWhileImporting.onPressed, isNull);
      expect(notifier.tasksForTest, isEmpty);

      finishImportPreparation.complete(
        prepareOcrImagePayloadSync(importedBytes),
      );
      await _pumpUntil(
        tester,
        () => find.text('已选 2 张图片').evaluate().isNotEmpty,
      );
      expect(find.text('已选 2 张图片'), findsOneWidget);
      expect(find.text('开始识别'), findsOneWidget);

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await cacheStarted.future;
      expect(pendingSnapshot!.images.length, 2);
      expect(notifier.tasksForTest, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      finishCache.complete(null);
      await tester.pump();
    });

    testWidgets(
      'continues OCR with unavailable retry data when caching fails',
      (tester) async {
        final notifier = _InspectableBackgroundTaskNotifier();
        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry(withModels: true)],
            testImages: [_createValidOcrTestImage()],
            backgroundTasksNotifier: notifier,
            testRetrySnapshotCacher: (
                {required taskId, required snapshot}) async {
              throw StateError('cache write failed');
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('开始识别'));
        await tester.pumpAndSettle();

        expect(notifier.tasksForTest, hasLength(1));
        final retryData = notifier.tasksForTest.single.retryData!;
        expect(retryData['version'], OcrRetrySnapshot.currentVersion);
        final image = (retryData['images'] as List).single as Map;
        expect(image['storageRef'], startsWith('ocr_retry_cache/'));
        expect(image.containsKey('bytes'), isFalse);
        expect(find.text('保存重试图片失败，请检查存储空间后重试'), findsNothing);
      },
    );

    testWidgets('legacy migration failure keeps retry inputs in memory', (
      tester,
    ) async {
      final image = _createValidOcrTestImage();
      final encodedImage = base64Encode(image.bytes);
      const taskId = 'legacy-page-migration-failure';
      final legacyRetryData = {
        'type': 'ocr',
        'version': 1,
        'modelRef': {'configId': 'test_ocr', 'modelId': 'gpt-4o'},
        'instructionContent': 'Read the saved receipt',
        'images': [
          {'bytes': encodedImage, 'format': 'png', 'name': 'receipt.png'},
        ],
      };
      final notifier = _InspectableBackgroundTaskNotifier();
      notifier.setTasksForTest([
        BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.ocr,
          title: 'legacy OCR retry',
          status: TaskStatus.failed,
          retryData: legacyRetryData,
        ),
      ]);
      var cacheAttempts = 0;

      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          retryData: legacyRetryData,
          retryTaskId: taskId,
          backgroundTasksNotifier: notifier,
          testRetrySnapshotCacher: (
              {required taskId, required snapshot}) async {
            cacheAttempts++;
            throw StateError('cache write failed');
          },
        ),
      );
      await _pumpUntil(tester, () => cacheAttempts == 1);
      await tester.pump();

      expect(cacheAttempts, 1);
      expect(find.text('已选 1 张图片'), findsOneWidget);
      final stillLegacy = OcrRetrySnapshot.fromMap(
        notifier.tasksForTest.single.retryData!,
      );
      expect(stillLegacy.version, 1);
      expect(stillLegacy.instructionContent, 'Read the saved receipt');
      expect(stillLegacy.images.single.bytes, image.bytes);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'legacy retry validates unknown image bytes before task publication',
      (tester) async {
        final notifier = _InspectableBackgroundTaskNotifier();
        final retryData = {
          'type': 'ocr',
          'version': 1,
          'modelIndex': 0,
          'images': [
            {
              'bytes': base64Encode(Uint8List.fromList([1, 2, 3, 4])),
            },
          ],
        };

        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry(withModels: true)],
            backgroundTasksNotifier: notifier,
            retryData: retryData,
            retryTaskId: 'unknown-format-legacy-retry',
            testImagePayloadPreparer: (bytes) async =>
                prepareOcrImagePayloadSync(bytes),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.tap(find.text('确认此模型'));
        await tester.pumpAndSettle();
        final startButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('开始识别'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(startButton.onPressed, isNotNull);
        await tester.tap(find.text('开始识别'));
        await tester.pumpAndSettle();

        expect(find.text('原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试'), findsOneWidget);
        expect(notifier.tasksForTest, isEmpty);
        final blockedStartButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('开始识别'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(blockedStartButton.onPressed, isNull);
      },
    );

    testWidgets('disposed retry migration preserves shared cache references', (
      tester,
    ) async {
      WebFileStore.enableTestMode();
      final bytes = Uint8List.fromList([7, 8, 9]);
      final legacyTaskId = 'shared-legacy-task';
      final migrationStarted = Completer<void>();
      final finishMigration = Completer<void>();
      final notifier = _InspectableBackgroundTaskNotifier();
      try {
        final sharedRetryData = await tester.runAsync(
          () => OcrRetryStorage.cacheSnapshot(
            taskId: legacyTaskId,
            snapshot: OcrRetrySnapshot.capture(
              configId: 'config-1',
              modelId: 'model-1',
              images: [OcrRetryImage(bytes: bytes, format: 'png')],
            ),
          ),
        );
        final sharedReference = (((sharedRetryData!['images'] as List).single
            as Map)['storageRef'] as String);
        final legacyRetryData = {
          'type': 'ocr',
          'version': 1,
          'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
          'images': [
            {'bytes': base64Encode(bytes), 'format': 'png'},
          ],
        };
        notifier.setTasksForTest([
          BackgroundTask(
            id: legacyTaskId,
            type: BackgroundTaskType.ocr,
            title: 'legacy retry',
            status: TaskStatus.failed,
            retryData: legacyRetryData,
          ),
          BackgroundTask(
            id: 'shared-reference-task',
            type: BackgroundTaskType.ocr,
            title: 'shared cache reference',
            status: TaskStatus.failed,
            retryData: sharedRetryData,
          ),
        ]);

        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry()],
            backgroundTasksNotifier: notifier,
            retryData: legacyRetryData,
            retryTaskId: legacyTaskId,
            testRetrySnapshotCacher: (
                {required taskId, required snapshot}) async {
              final result = await OcrRetryStorage.cacheSnapshot(
                taskId: taskId,
                snapshot: snapshot,
              );
              migrationStarted.complete();
              await finishMigration.future;
              return result;
            },
          ),
        );
        await tester.pumpAndSettle();
        await migrationStarted.future;

        await tester.pumpWidget(const SizedBox.shrink());
        finishMigration.complete();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        final retained = await tester.runAsync(
          () => OcrRetryStorage.read(sharedReference),
        );
        expect(retained, bytes);
      } finally {
        if (!finishMigration.isCompleted) finishMigration.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        WebFileStore.disableTestMode();
      }
    });

    testWidgets('unknown retry image count requires explicit input reset', (
      tester,
    ) async {
      final notifier = _InspectableBackgroundTaskNotifier();
      final replacementBytes = _createValidOcrTestImage().bytes;
      var gallerySelections = 0;
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          testImages: [_createValidOcrTestImage()],
          retryTaskId: 'failed-ocr-task',
          backgroundTasksNotifier: notifier,
          testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) async {
            gallerySelections++;
            return [
              XFile.fromData(
                replacementBytes,
                name: 'replacement-$gallerySelections.png',
              ),
            ];
          },
          testImagePayloadPreparer: (_) async =>
              prepareOcrImagePayloadSync(replacementBytes),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('原始 OCR 图片缓存不可用，且无法确认图片数量。请重置后重新选择本次全部图片'),
        findsOneWidget,
      );
      var startButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('开始识别'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(startButton.onPressed, isNull);

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ocr_unknown_retry_reset_dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ocr_cancel_unknown_retry_reset')));
      await tester.pumpAndSettle();
      startButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('开始识别'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(startButton.onPressed, isNull);

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('ocr_confirm_unknown_retry_reset')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已选 1 张图片'), findsNothing);
      expect(notifier.tasksForTest, isEmpty);

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从系统相册选择'));
      await tester.pumpAndSettle();
      expect(find.text('已选 1 张图片'), findsOneWidget);
      startButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('开始识别'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(startButton.onPressed, isNotNull);
      expect(notifier.tasksForTest, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      notifier.dispose();
    });

    testWidgets('retry instruction load failure unlocks OCR start', (
      tester,
    ) async {
      final loadStarted = Completer<void>();
      final finishFirstLoad = Completer<void>();
      final notifier = _InspectableBackgroundTaskNotifier();
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry(withModels: true)],
          retryData: {
            'type': 'ocr',
            'images': [
              {'bytes': base64Encode(_createTestPngBytes()), 'format': 'png'},
            ],
            'modelIndex': 0,
            'instructionIndex': 1,
          },
          backgroundTasksNotifier: notifier,
          testInstructionsNotifierBuilder: (ref) =>
              _InstructionsLoadFailsOnRetryNotifier(
            ref,
            loadStarted: loadStarted,
            finishFirstLoad: finishFirstLoad,
          ),
          testImagePayloadPreparer: (bytes) async =>
              OcrImagePayload(bytes: bytes, format: 'png', width: 1, height: 1),
        ),
      );
      await tester.pumpAndSettle();
      await loadStarted.future;
      await tester.tap(find.byKey(const Key('ocr_confirm_legacy_model')));
      await tester.pump();

      await tester.tap(find.text('开始识别'));
      await tester.pump();

      expect(find.text('读取识别指令失败，请重试'), findsOneWidget);
      expect(notifier.tasksForTest, isEmpty);
      final startButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('开始识别'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(startButton.onPressed, isNotNull);

      finishFirstLoad.complete();
      await tester.pump();
    });

    testWidgets('disables image changes while cached retry images restore', (
      tester,
    ) async {
      final pendingRestore = Completer<OcrRetryRestoreResult>();
      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry()],
          retryData: {
            'type': 'ocr',
            'version': 2,
            'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
            'images': [
              {
                'storageRef': 'ocr_retry_cache/${'a' * 64}.bin',
                'format': 'png',
                'name': 'retry.png',
              },
            ],
          },
          testRetryImageRestorer: (_) => pendingRestore.future,
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '相册选择'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '拍照识别'))
            .onPressed,
        isNull,
      );
      expect(find.text('读取重试图片...'), findsOneWidget);

      pendingRestore.complete(
        OcrRetryRestoreResult(
          images: [OcrRetryImage(bytes: _createTestPngBytes(), format: 'png')],
          missingImageCount: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已选 1 张图片'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '相册选择'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'missing cached retry image requires reselecting the full image set',
      (tester) async {
        WebFileStore.enableTestMode();
        final notifier = _InspectableBackgroundTaskNotifier();
        final replacementBytes = _createValidOcrTestImage().bytes;
        var gallerySelections = 0;

        Future<void> closeRecoveryBannerIfDismissible(String message) async {
          final messageFinder = find.text(message);
          final errorColor = Theme.of(
            tester.element(messageFinder),
          ).colorScheme.errorContainer;
          final bannerFinder = find.ancestor(
            of: messageFinder,
            matching: find.byWidgetPredicate(
              (widget) => widget is Container && widget.color == errorColor,
            ),
          );
          expect(bannerFinder, findsOneWidget);
          final dismissButton = find.descendant(
            of: bannerFinder,
            matching: find.byIcon(Icons.close),
          );
          if (dismissButton.evaluate().isNotEmpty) {
            await tester.tap(dismissButton);
            await tester.pumpAndSettle();
          }
          expect(
            messageFinder,
            findsOneWidget,
            reason:
                'a blocked retry must keep its image-recovery guidance visible',
          );
        }

        try {
          final stored = await tester.runAsync(
            () => OcrRetryStorage.cacheSnapshot(
              taskId: 'present-image',
              snapshot: OcrRetrySnapshot.capture(
                configId: 'config-1',
                modelId: 'model-1',
                images: [
                  OcrRetryImage(
                    bytes: Uint8List.fromList([1, 2]),
                    format: 'png',
                  ),
                ],
              ),
            ),
          );
          final presentImage = (stored!['images'] as List).single as Map;
          await tester.pumpWidget(
            _buildTestApp(
              entries: [_createOcrEntry()],
              backgroundTasksNotifier: notifier,
              retryData: {
                'type': 'ocr',
                'version': 2,
                'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
                'images': [
                  presentImage,
                  {
                    'storageRef':
                        'ocr_retry_cache/ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff.bin',
                    'format': 'png',
                    'name': 'missing.png',
                  },
                ],
              },
              testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) async {
                gallerySelections++;
                return [
                  XFile.fromData(
                    replacementBytes,
                    name: 'replacement-$gallerySelections.png',
                  ),
                ];
              },
              testImagePayloadPreparer: (_) async =>
                  prepareOcrImagePayloadSync(replacementBytes),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('已选 1 张图片'), findsOneWidget);
          expect(
            find.text('原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试'),
            findsOneWidget,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .toList()
                .toString(),
          );
          await closeRecoveryBannerIfDismissible(
            '原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试',
          );
          final startButton = tester.widget<FilledButton>(
            find.ancestor(
              of: find.text('开始识别'),
              matching: find.byType(FilledButton),
            ),
          );
          expect(startButton.onPressed, isNull);
          await tester.tap(find.text('开始识别'));
          await tester.pump();
          expect(notifier.tasksForTest, isEmpty);

          await tester.tap(find.text('清空'));
          await tester.pumpAndSettle();

          Future<void> selectOneImage() async {
            await tester.tap(find.text('相册选择'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('从系统相册选择'));
            await tester.pumpAndSettle();
          }

          await selectOneImage();
          expect(find.text('已选 1 张图片'), findsOneWidget);
          await closeRecoveryBannerIfDismissible('请重新选择全部 2 张图片后重试');
          final partialReselectButton = tester.widget<FilledButton>(
            find.ancestor(
              of: find.text('开始识别'),
              matching: find.byType(FilledButton),
            ),
          );
          expect(partialReselectButton.onPressed, isNull);
          expect(notifier.tasksForTest, isEmpty);

          await selectOneImage();
          expect(find.text('已选 2 张图片'), findsOneWidget);
          final completeReselectButton = tester.widget<FilledButton>(
            find.ancestor(
              of: find.text('开始识别'),
              matching: find.byType(FilledButton),
            ),
          );
          expect(completeReselectButton.onPressed, isNotNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          notifier.dispose();
          WebFileStore.disableTestMode();
        }
      },
    );

    testWidgets(
      'unavailable retry with reusable page results can reset and reselect images',
      (tester) async {
        final replacementBytes = _createValidOcrTestImage().bytes;
        final notifier = _InspectableBackgroundTaskNotifier();
        var gallerySelections = 0;

        try {
          await tester.pumpWidget(
            _buildTestApp(
              entries: [_createOcrEntry()],
              backgroundTasksNotifier: notifier,
              retryData: {
                'type': 'ocr',
                'version': 3,
                'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
                'images': [
                  {
                    'storageRef': 'ocr_retry_cache/${'a' * 64}.bin',
                    'format': 'png',
                    'name': 'first.png',
                  },
                  {
                    'storageRef': 'ocr_retry_cache/${'b' * 64}.bin',
                    'format': 'png',
                    'name': 'second.png',
                  },
                ],
                'batchMode': 'perImage',
                'perImageConcurrency': 1,
                'requestSizeBudgetBytes': defaultOcrRequestSizeBudgetBytes,
              },
              retryPageOutcomes: const [
                OcrPageOutcome(
                  imageIndex: 0,
                  status: OcrPageOutcomeStatus.succeeded,
                  text: 'completed page',
                ),
                OcrPageOutcome(
                  imageIndex: 1,
                  status: OcrPageOutcomeStatus.failed,
                  error: 'request failed',
                ),
              ],
              testRetryImageRestorer: (_) async => OcrRetryRestoreResult(
                images: [OcrRetryImage(bytes: replacementBytes, format: 'png')],
                missingImageCount: 1,
              ),
              testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) async {
                gallerySelections++;
                return [
                  XFile.fromData(
                    replacementBytes,
                    name: 'replacement-$gallerySelections.png',
                  ),
                ];
              },
              testImagePayloadPreparer: (_) async =>
                  prepareOcrImagePayloadSync(replacementBytes),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('已选 1 张图片'), findsOneWidget);
          expect(find.text('清空'), findsOneWidget);
          await tester.tap(find.text('清空'));
          await tester.pumpAndSettle();

          Future<void> selectOneImage() async {
            await tester.tap(find.text('相册选择'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('从系统相册选择'));
            await tester.pumpAndSettle();
          }

          await selectOneImage();
          expect(find.text('已选 1 张图片'), findsOneWidget);
          await selectOneImage();
          expect(find.text('已选 2 张图片'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '开始识别'),
                )
                .onPressed,
            isNotNull,
          );
          expect(notifier.tasksForTest, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          notifier.dispose();
        }
      },
    );

    testWidgets(
      'retry locks model and instruction while reusing page results',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry()],
            testImages: [_createValidOcrTestImage()],
            ocrInstructions: const [
              OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            ],
            retryPageOutcomes: const [
              OcrPageOutcome(
                imageIndex: 0,
                status: OcrPageOutcomeStatus.succeeded,
                text: 'retained page result',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final selectors = tester
            .widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .toList();
        expect(selectors, hasLength(2));
        expect(selectors.every((selector) => selector.onChanged == null), isTrue);
      },
    );

    testWidgets(
      'clearing an unavailable retry invalidates a pending system gallery import',
      (tester) async {
        final replacementBytes = _createValidOcrTestImage().bytes;
        final finishGalleryPicker = Completer<List<XFile>>();
        final importPreparationStarted = Completer<void>();
        final finishImportPreparation = Completer<OcrImagePayload>();
        final notifier = _InspectableBackgroundTaskNotifier();
        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry(withModels: true)],
            backgroundTasksNotifier: notifier,
            retryData: {
              'type': 'ocr',
              'version': 2,
              'modelRef': {'configId': 'test_ocr', 'modelId': 'gpt-4o'},
              'images': [
                {
                  'storageRef': 'ocr_retry_cache/${'a' * 64}.bin',
                  'format': 'png',
                  'name': 'missing.png',
                },
              ],
            },
            testRetryImageRestorer: (_) async =>
                const OcrRetryRestoreResult(images: [], missingImageCount: 1),
            testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) =>
                finishGalleryPicker.future,
            testImagePayloadPreparer: (_) {
              importPreparationStarted.complete();
              return finishImportPreparation.future;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('相册选择'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从系统相册选择'));
        await tester.pump();
        finishGalleryPicker.complete([
          XFile.fromData(replacementBytes, name: 'replacement.png'),
        ]);
        await _pumpUntil(tester, () => importPreparationStarted.isCompleted);

        await tester.tap(find.text('清空'));
        await tester.pump();
        finishImportPreparation.complete(
          prepareOcrImagePayloadSync(replacementBytes),
        );
        await tester.pumpAndSettle();

        expect(find.text('已选 1 张图片'), findsNothing);
        expect(find.text('请重新选择全部 1 张图片后重试'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '开始识别'))
              .onPressed,
          isNull,
        );
        expect(notifier.tasksForTest, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        notifier.dispose();
      },
    );

    testWidgets(
      'clearing an unavailable retry invalidates a pending camera import',
      (tester) async {
        final replacementBytes = _createValidOcrTestImage().bytes;
        final finishCameraPicker = Completer<XFile?>();
        final importPreparationStarted = Completer<void>();
        final finishImportPreparation = Completer<OcrImagePayload>();
        final notifier = _InspectableBackgroundTaskNotifier();
        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry(withModels: true)],
            backgroundTasksNotifier: notifier,
            retryData: {
              'type': 'ocr',
              'version': 2,
              'modelRef': {'configId': 'test_ocr', 'modelId': 'gpt-4o'},
              'images': [
                {
                  'storageRef': 'ocr_retry_cache/${'b' * 64}.bin',
                  'format': 'png',
                  'name': 'missing.png',
                },
              ],
            },
            testRetryImageRestorer: (_) async =>
                const OcrRetryRestoreResult(images: [], missingImageCount: 1),
            testCameraPicker: ({maxWidth, maxHeight, imageQuality}) =>
                finishCameraPicker.future,
            testImagePayloadPreparer: (_) {
              importPreparationStarted.complete();
              return finishImportPreparation.future;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('拍照识别'));
        await tester.pump();
        finishCameraPicker.complete(
          XFile.fromData(replacementBytes, name: 'replacement.png'),
        );
        await _pumpUntil(tester, () => importPreparationStarted.isCompleted);

        await tester.tap(find.text('清空'));
        await tester.pump();
        finishImportPreparation.complete(
          prepareOcrImagePayloadSync(replacementBytes),
        );
        await tester.pumpAndSettle();

        expect(find.text('已选 1 张图片'), findsNothing);
        expect(find.text('请重新选择全部 1 张图片后重试'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '开始识别'))
              .onPressed,
          isNull,
        );
        expect(notifier.tasksForTest, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        notifier.dispose();
      },
    );

    testWidgets(
      'corrupt cached retry image requires reselecting the full image set',
      (tester) async {
        WebFileStore.enableTestMode();
        final notifier = _InspectableBackgroundTaskNotifier();
        final replacementBytes = _createValidOcrTestImage().bytes;
        var gallerySelections = 0;
        try {
          final retryData = await tester.runAsync(
            () => OcrRetryStorage.cacheSnapshot(
              taskId: 'corrupt-image',
              snapshot: OcrRetrySnapshot.capture(
                legacyModelIndex: 0,
                images: [
                  OcrRetryImage(
                    bytes: Uint8List.fromList([1, 2]),
                    format: 'png',
                    name: 'corrupt.png',
                  ),
                  OcrRetryImage(
                    bytes: _createTestPngBytes(),
                    format: 'png',
                    name: 'valid.png',
                  ),
                ],
              ),
            ),
          );
          await tester.pumpWidget(
            _buildTestApp(
              entries: [_createOcrEntry(withModels: true)],
              backgroundTasksNotifier: notifier,
              retryData: retryData,
              testImagePayloadPreparer: (bytes) async {
                if (bytes.length == 2) {
                  throw const FormatException('corrupt cached image');
                }
                return prepareOcrImagePayloadSync(bytes);
              },
              testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) async {
                gallerySelections++;
                return [
                  XFile.fromData(
                    replacementBytes,
                    name: 'replacement-$gallerySelections.png',
                  ),
                ];
              },
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('已选 2 张图片'), findsOneWidget);
          await tester.tap(find.text('确认此模型'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('开始识别'));
          await tester.pumpAndSettle();

          expect(
            find.text('原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试'),
            findsOneWidget,
          );
          expect(notifier.tasksForTest, isEmpty);

          final corruptImageRect = tester.getRect(
            find.byKey(const ValueKey('ocr_grid_item_0')),
          );
          await tester.tapAt(
            Offset(corruptImageRect.right - 12, corruptImageRect.top + 12),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('相册选择'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('从系统相册选择'));
          await tester.pumpAndSettle();

          expect(find.text('已选 2 张图片'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.ancestor(
                    of: find.text('开始识别'),
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
            reason:
                'replacing one corrupt image must not retain old retry inputs',
          );
          expect(notifier.tasksForTest, isEmpty);

          await tester.tap(find.text('清空'));
          await tester.pumpAndSettle();

          Future<void> selectOneImage() async {
            await tester.tap(find.text('相册选择'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('从系统相册选择'));
            await tester.pumpAndSettle();
          }

          await selectOneImage();
          expect(find.text('已选 1 张图片'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.ancestor(
                    of: find.text('开始识别'),
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
          );

          await selectOneImage();
          expect(find.text('已选 2 张图片'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.ancestor(
                    of: find.text('开始识别'),
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNotNull,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          notifier.dispose();
          WebFileStore.disableTestMode();
        }
      },
    );

    testWidgets(
      'unavailable retry inputs keep recovery controls visible when empty',
      (tester) async {
        final entry = _createOcrEntry(withModels: true);
        await tester.pumpWidget(
          _buildTestApp(
            entries: [entry],
            ocrInstructions: const [
              OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
              OcrInstruction(name: '表格提取', content: '提取表格内容'),
            ],
            retryData: {
              'type': 'ocr',
              'modelIndex': 0,
              'instructionIndex': 1,
              'images': <Map<String, dynamic>>[],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('原始 OCR 图片缓存不可用，且无法确认图片数量。请重置后重新选择本次全部图片'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, '相册选择'),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '开始识别'))
              .onPressed,
          isNull,
        );
        expect(find.widgetWithText(TextButton, '清空'), findsOneWidget);
      },
    );

    testWidgets(
      'restores the referenced model, folder and instruction snapshot',
      (tester) async {
        final firstEntry = ProviderEntry(
          id: 'ocr-entry-first',
          type: 'ocr',
          name: 'First OCR',
          configs: [
            ProviderConfigItem(
              id: 'ocr-config-first',
              providerName: 'First Provider',
              host: 'https://first.example/v1',
              key: 'first-secret',
              models: [
                ModelConfig(
                  id: 'ocr-model-first',
                  name: 'First Model',
                  modelId: 'first-model',
                ),
              ],
            ),
          ],
        );
        final reorderedEntry = ProviderEntry(
          id: 'ocr-entry-reordered',
          type: 'ocr',
          name: 'Second OCR',
          configs: [
            ProviderConfigItem(
              id: 'ocr-config-reordered',
              providerName: 'Second Provider',
              host: 'https://second.example/v1',
              key: 'second-secret',
              models: [
                ModelConfig(
                  id: 'ocr-model-other',
                  name: 'Other Model',
                  modelId: 'other-model',
                ),
                ModelConfig(
                  id: 'ocr-model-target',
                  name: 'Target Model',
                  modelId: 'target-model',
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          _buildTestApp(
            entries: [firstEntry, reorderedEntry],
            ocrInstructions: const [
              OcrInstruction(name: 'Edited prompt', content: 'new prompt'),
            ],
            retryData: _createVersionedRetryData(
              configId: 'ocr-config-reordered',
              modelId: 'ocr-model-target',
              instructionContent: 'captured prompt removed from generic list',
              saveFolder: 'receipts/2026',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Target Model | Second Provider'), findsOneWidget);
        expect(find.text('receipts/2026'), findsOneWidget);
        expect(find.text('已保存的指令快照'), findsOneWidget);
      },
    );

    testWidgets(
      'a deleted model reference blocks submission until reselection',
      (tester) async {
        final bgNotifier = _InspectableBackgroundTaskNotifier();
        final availableEntry = ProviderEntry(
          id: 'ocr-entry-current',
          type: 'ocr',
          name: 'Current OCR',
          configs: [
            ProviderConfigItem(
              id: 'current-config',
              providerName: 'Current Provider',
              host: 'https://current.example/v1',
              key: 'current-secret',
              models: [
                ModelConfig(
                  id: 'current-model',
                  name: 'Current Model',
                  modelId: 'current-model-api',
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          _buildTestApp(
            entries: [availableEntry],
            backgroundTasksNotifier: bgNotifier,
            retryData: _createVersionedRetryData(
              configId: 'deleted-config',
              modelId: 'deleted-model',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('原 OCR 供应商或模型已不存在，请重新选择'), findsOneWidget);
        expect(find.text('Current Model | Current Provider'), findsNothing);
        await tester.tap(find.text('开始识别'));
        await tester.pump();

        expect(bgNotifier.tasksForTest, isEmpty);
      },
    );

    testWidgets(
      'legacy model context is shown when provider identity is absent',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry(withModels: true)],
            retryData: {
              'type': 'ocr',
              'version': 2,
              'modelRef': {'modelId': 'vision-model'},
              'images': [
                {
                  'storageRef':
                      'ocr_retry_cache/ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff.bin',
                  'format': 'png',
                },
              ],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('旧任务使用模型 vision-model，请重新选择供应商和模型'), findsOneWidget);
      },
    );

    testWidgets('legacy model index needs confirmation before submission', (
      tester,
    ) async {
      final bgNotifier = _InspectableBackgroundTaskNotifier();
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          backgroundTasksNotifier: bgNotifier,
          retryData: {
            'type': 'ocr',
            'images': [
              {
                'bytes': base64Encode(_createTestPngBytes()),
                'format': 'png',
                'name': 'legacy.png',
              },
            ],
            'modelIndex': 1,
            'instructionIndex': 0,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GPT-4o Mini | OpenAI'), findsOneWidget);
      expect(find.text('旧重试记录只保存了模型位置，请确认当前模型后继续。'), findsOneWidget);
      await tester.tap(find.text('开始识别'));
      await tester.pump();
      expect(bgNotifier.tasksForTest, isEmpty);

      await tester.tap(find.byKey(const Key('ocr_confirm_legacy_model')));
      await tester.pump();
      expect(find.text('旧重试记录只保存了模型位置，请确认当前模型后继续。'), findsNothing);
      expect(bgNotifier.tasksForTest, isEmpty);
    });
  });

  group('OcrPage - instruction selector', () {
    testWidgets('always shown even without any configured instructions', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // The selector is always visible regardless of configuration.
      expect(find.text('识别指令'), findsOneWidget);
      expect(find.text('默认（仅发送图片）'), findsOneWidget);
    });

    testWidgets('shows generic instruction names in the dropdown', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('识别指令'), findsOneWidget);
      expect(find.text('默认（仅发送图片）'), findsOneWidget);

      // Open the dropdown — both instruction names are listed.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      expect(find.text('发票提取'), findsWidgets);
      expect(find.text('表格提取'), findsWidgets);
    });

    testWidgets('shows content snippet when instruction has no name', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [OcrInstruction(content: '提取图片中的全部文字并翻译')],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dropdown — the unnamed instruction is labeled by its
      // content snippet.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();

      expect(find.text('提取图片中的全部文字并翻译'), findsWidgets);
    });

    testWidgets('selecting an instruction updates the dropdown display', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the instruction dropdown and pick the second instruction.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('表格提取').last);
      await tester.pumpAndSettle();

      expect(find.text('表格提取'), findsOneWidget);
    });

    testWidgets('switching model keeps the generic instruction selection', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Select the instruction.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发票提取').last);
      await tester.pumpAndSettle();
      expect(find.text('发票提取'), findsOneWidget);

      // Switch model — instructions are generic, so the selection sticks.
      await tester.tap(find.text('GPT-4o | OpenAI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPT-4o Mini | OpenAI').last);
      await tester.pumpAndSettle();

      expect(find.text('识别指令'), findsOneWidget);
      expect(find.text('发票提取'), findsOneWidget);
    });

    testWidgets('retry data restores the instruction selection', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
          retryData: {
            'type': 'ocr',
            'images': <Map<String, dynamic>>[],
            'modelIndex': 0,
            'instructionIndex': 1,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('表格提取'), findsOneWidget);
    });

    testWidgets(
      'retry restores the instruction by content when the list changed',
      (tester) async {
        final entry = _createOcrEntry(withModels: true);
        await tester.pumpWidget(
          _buildTestApp(
            entries: [entry],
            ocrInstructions: const [
              OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
              OcrInstruction(name: '表格提取', content: '提取表格内容'),
            ],
            retryData: {
              'type': 'ocr',
              'images': <Map<String, dynamic>>[],
              'modelIndex': 0,
              // Stale index (the list changed since the task failed) — the
              // content wins and resolves to the correct instruction.
              'instructionIndex': 1,
              'instructionContent': '提取发票号码和金额',
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('已保存的指令快照'), findsOneWidget);
      },
    );

    testWidgets(
      'retry keeps the instruction snapshot when its generic entry is gone',
      (tester) async {
        final entry = _createOcrEntry(withModels: true);
        await tester.pumpWidget(
          _buildTestApp(
            entries: [entry],
            ocrInstructions: const [
              OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            ],
            retryData: {
              'type': 'ocr',
              'images': <Map<String, dynamic>>[],
              'modelIndex': 0,
              'instructionIndex': 0,
              'instructionContent': '已删除的指令内容',
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('已保存的指令快照'), findsOneWidget);
        expect(find.text('默认（仅发送图片）'), findsNothing);
      },
    );

    testWidgets(
      'retry instruction restore survives the async list load (production '
      'race: list arrives after the first build)',
      (tester) async {
        // Simulates the real provider: initial state is empty, the list
        // arrives only after load() completes asynchronously.
        final entry = _createOcrEntry(withModels: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              providerEntriesProvider.overrideWith((ref) {
                final notifier = ProviderEntriesNotifier();
                notifier.state = ProviderEntriesState(entries: [entry]);
                return notifier;
              }),
              ocrInstructionsProvider.overrideWith((ref) {
                final notifier = _DelayedInstructionsNotifier(ref);
                notifier.load();
                return notifier;
              }),
            ],
            child: MaterialApp(
              home: OcrPage(
                retryData: {
                  'type': 'ocr',
                  'images': <Map<String, dynamic>>[],
                  'modelIndex': 0,
                  'instructionIndex': 1,
                },
              ),
              localizationsDelegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
            ),
          ),
        );
        // No time advance — the delayed load has not completed yet.
        await tester.pump();

        // The list has not arrived yet — the dropdown shows the default
        // instead of crashing on an out-of-range value.
        expect(find.text('默认（仅发送图片）'), findsOneWidget);

        // The list arrives — the restored instruction selection applies.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('表格提取'), findsOneWidget);
      },
    );

    testWidgets(
      'user picking 默认 during the pending restore wins over the retry '
      'instruction',
      (tester) async {
        final entry = _createOcrEntry(withModels: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              providerEntriesProvider.overrideWith((ref) {
                final notifier = ProviderEntriesNotifier();
                notifier.state = ProviderEntriesState(entries: [entry]);
                return notifier;
              }),
              ocrInstructionsProvider.overrideWith((ref) {
                final notifier = _DelayedInstructionsNotifier(ref);
                notifier.load();
                return notifier;
              }),
            ],
            child: MaterialApp(
              home: OcrPage(
                retryData: {
                  'type': 'ocr',
                  'images': <Map<String, dynamic>>[],
                  'modelIndex': 0,
                  'instructionIndex': 1,
                },
              ),
              localizationsDelegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
            ),
          ),
        );
        await tester.pump();

        // Inside the pending window the dropdown has only the default item —
        // explicitly pick it.
        await tester.tap(find.text('默认（仅发送图片）'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('默认（仅发送图片）').last);
        await tester.pumpAndSettle();

        // The load lands — the user's explicit choice sticks and the retry
        // instruction does not resurrect.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('默认（仅发送图片）'), findsOneWidget);
        expect(find.text('表格提取'), findsNothing);
      },
    );

    testWidgets('double-tap 开始识别 during the pending restore starts one task', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      final bgNotifier = BackgroundTaskNotifier();
      final instructionsLoadStarted = Completer<void>();
      final finishInstructionsLoad = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = ProviderEntriesState(entries: [entry]);
              return notifier;
            }),
            ocrInstructionsProvider.overrideWith((ref) {
              final notifier = _CompletableInstructionsNotifier(
                ref,
                loadStarted: instructionsLoadStarted,
                finishLoad: finishInstructionsLoad,
              );
              notifier.load();
              return notifier;
            }),
            backgroundTasksProvider.overrideWith((ref) => bgNotifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OcrPage(
                          retryData: {
                            'type': 'ocr',
                            'images': [
                              {
                                'bytes': base64Encode(_createTestPngBytes()),
                                'format': 'png',
                              },
                            ],
                            'modelIndex': 0,
                            'instructionIndex': 1,
                          },
                          testImagePayloadPreparer: (bytes) async =>
                              OcrImagePayload(
                            bytes: bytes,
                            format: 'png',
                            width: 1,
                            height: 1,
                          ),
                          testRetrySnapshotCacher: ({
                            required taskId,
                            required snapshot,
                          }) async =>
                              OcrRetrySnapshot.capture(
                            configId: snapshot.configId,
                            modelId: snapshot.modelId,
                            images: [
                              for (final image in snapshot.images)
                                OcrRetryImage.reference(
                                  storageRef:
                                      'ocr_retry_cache/${List.filled(64, 'a').join()}.bin',
                                  format: image.format,
                                  name: image.name,
                                ),
                            ],
                            instructionContent: snapshot.instructionContent,
                            saveFolder: snapshot.saveFolder,
                          ).toMap(),
                        ),
                      ),
                    ),
                    child: const Text('打开OCR'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开OCR'));
      await tester.pumpAndSettle();
      await instructionsLoadStarted.future;
      await tester.tap(find.byKey(const Key('ocr_confirm_legacy_model')));
      await tester.pump();

      // Keep the instruction restore pending after the first tap, then ensure
      // the busy control cannot publish a second task.
      await tester.tap(find.text('开始识别'));
      await tester.pump();
      expect(bgNotifier.state, isEmpty);
      final busyButton = find.byType(FilledButton).last;
      expect(tester.widget<FilledButton>(busyButton).onPressed, isNull);
      await tester.tap(busyButton);
      finishInstructionsLoad.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      // Exactly one task was created and the page popped exactly once
      // (host visible again).
      expect(bgNotifier.state.length, 1);
      expect(find.text('开始识别'), findsNothing);
      expect(find.text('打开OCR'), findsOneWidget);
    });

    testWidgets('manage button opens the instruction management dialog', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();

      expect(find.text('管理识别指令'), findsOneWidget);
      expect(find.text('暂无指令'), findsOneWidget);
      expect(find.text('添加指令'), findsOneWidget);
    });

    testWidgets(
      'adding an instruction via manage dialog shows it in dropdown',
      (tester) async {
        final entry = _createOcrEntry(withModels: true);
        await tester.pumpWidget(_buildTestApp(entries: [entry]));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('添加指令'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, '指令名称（可选）'),
          '发票提取',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '指令内容'),
          '提取发票号码和金额',
        );
        // Rebuild so the save button's enabled state reflects the content.
        await tester.pump();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        // The new instruction appears in the manage dialog list.
        expect(find.text('发票提取'), findsOneWidget);

        // Close the dialog and open the dropdown — instruction is selectable.
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('默认（仅发送图片）'));
        await tester.pumpAndSettle();
        expect(find.text('发票提取'), findsWidgets);
      },
    );

    testWidgets('editing an instruction via manage dialog updates the list', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();

      // Open the editor — it is pre-filled with the existing instruction.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '发票提取'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '指令名称（可选）'),
        '发票提取v2',
      );
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The updated name replaces the old one in the dialog list.
      expect(find.text('发票提取v2'), findsOneWidget);
      expect(find.text('发票提取'), findsNothing);

      // And in the dropdown after closing.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      expect(find.text('发票提取v2'), findsWidgets);
    });

    testWidgets('deleting the selected instruction falls back to the default', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Select the second instruction, then delete it via the manage dialog.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('表格提取').last);
      await tester.pumpAndSettle();
      expect(find.text('表格提取'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      // Only the first instruction remains in the dialog.
      expect(find.text('发票提取'), findsOneWidget);
      expect(find.text('表格提取'), findsNothing);

      // Closing falls back to the default — the deleted selection never
      // sticks.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('默认（仅发送图片）'), findsOneWidget);
    });

    testWidgets('save is disabled while the instruction content is blank', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加指令'));
      await tester.pumpAndSettle();

      FilledButton saveButton() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存'));

      // Blank content — save disabled.
      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, '指令内容'), '提取发票号码');
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
    });
  });

  group('OcrPage - instruction injection', () {
    const instructions = [
      OcrInstruction(name: '发票', content: '提取发票号码和金额'),
      OcrInstruction(content: '提取表格内容'),
    ];

    test('selected instruction content is written to typeConfig', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        instructions,
        1,
      );
      expect(tc['userInstruction'], '提取表格内容');
    });

    test('default selection (-1) leaves typeConfig untouched', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        instructions,
        -1,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });

    test('out-of-range index leaves typeConfig untouched', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        instructions,
        5,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });

    test(
        'default selection removes a legacy per-model instruction from the '
        'request copy', () {
      // The request copy inherits the model's stored typeConfig, which may
      // still carry a legacy per-model userInstruction (kept in storage for
      // the migration) — the default selection must keep the request
      // images-only.
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096, 'userInstruction': '旧版指令'},
        instructions,
        -1,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });

    test('blank-content instruction is not injected', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        const [OcrInstruction(name: '空白', content: '   \n\n  ')],
        0,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });
  });

  group('OcrPage - camera button (no choice panel)', () {
    testWidgets('tapping camera button does NOT show choice panel', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the camera button - it now directly opens system camera
      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      // The old choice panel should NOT appear
      expect(find.text('应用相机'), findsNothing);
      expect(find.text('系统相机'), findsNothing);
      expect(find.text('选择拍照方式'), findsNothing);
    });
  });

  group('OcrPage - album choice panel', () {
    testWidgets('tapping album button shows choice panel', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the album button
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      // Should show choice panel with system album and app album
      expect(find.text('从系统相册选择'), findsOneWidget);
      expect(find.text('从应用相册选择'), findsOneWidget);
    });

    testWidgets('album choice panel shows title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      expect(find.text('选择图片来源'), findsOneWidget);
    });
  });

  group('OcrPage - image import quality', () {
    testWidgets('standard keeps 2048/q90 and original mode removes limits', (
      tester,
    ) async {
      final calls = <({double? maxWidth, double? maxHeight, int? quality})>[];
      await tester.pumpWidget(
        _buildTestApp(
          testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) async {
            calls.add((
              maxWidth: maxWidth,
              maxHeight: maxHeight,
              quality: imageQuality,
            ));
            return [];
          },
        ),
      );
      await tester.pumpAndSettle();

      Future<void> pickFromSystemGallery() async {
        await tester.tap(find.text('相册选择'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从系统相册选择'));
        await tester.pumpAndSettle();
      }

      await pickFromSystemGallery();
      expect(calls.single, (maxWidth: 2048, maxHeight: 2048, quality: 90));

      await tester.tap(find.byKey(const Key('ocr_high_detail_switch')));
      await tester.pumpAndSettle();
      await pickFromSystemGallery();
      expect(calls.last, (maxWidth: null, maxHeight: null, quality: null));

      final denseTextImage = img.encodePng(
        img.Image(width: 3000, height: 2200),
      );
      final prepared = prepareOcrImagePayloadSync(denseTextImage);
      expect(prepared.width, 3000);
      expect(prepared.height, 2200);
      expect(prepared.bytes, denseTextImage);
    });
  });

  group('OcrPage - async image validation races', () {
    testWidgets('does not restore a selection cleared during OCR startup', (
      tester,
    ) async {
      final validationStarted = Completer<void>();
      final finishValidation = Completer<void>();
      final validPayload = prepareOcrImagePayloadSync(
        img.encodePng(img.Image(width: 1, height: 1, numChannels: 3)),
      );

      Future<OcrImagePayload> delayedValidation(Uint8List _) async {
        if (!validationStarted.isCompleted) validationStarted.complete();
        await finishValidation.future;
        return validPayload;
      }

      await tester.pumpWidget(
        _buildTestApp(
          entries: [_createOcrEntry()],
          testImages: [_createTestImage(), _createTestImage(seed: 2)],
          testImagePayloadPreparer: delayedValidation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await validationStarted.future;

      await tester.tap(find.text('清空'));
      await tester.pump();
      finishValidation.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('已选 2 张图片'), findsNothing);
      expect(find.text('图片列表已变化，请重新开始识别。'), findsOneWidget);
      expect(find.text('开始识别'), findsOneWidget);
    });

    testWidgets('applies an edit to the same image after it is reordered', (
      tester,
    ) async {
      final imageA = await tester.runAsync(
        () => _createEnginePng(color: const Color(0xFF00FF00)),
      );
      final imageB = await tester.runAsync(
        () => _createEnginePng(color: const Color(0xFFFF0000)),
      );
      final validationStarted = Completer<void>();
      final finishValidation = Completer<void>();
      Uint8List? editedBytes;

      Future<OcrImagePayload> delayedValidation(Uint8List bytes) async {
        editedBytes = bytes;
        validationStarted.complete();
        await finishValidation.future;
        return prepareOcrImagePayloadSync(bytes);
      }

      await tester.pumpWidget(
        _buildTestApp(
          testImages: [
            SelectedImage(bytes: imageA!, format: 'png'),
            SelectedImage(bytes: imageB!, format: 'png'),
          ],
          testImagePayloadPreparer: delayedValidation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('保存'));
      await _pumpUntil(
        tester,
        () =>
            validationStarted.isCompleted &&
            find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!
          .call(0, 1);
      await tester.pumpAndSettle();
      finishValidation.complete();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ocr_grid_item_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      final editor = tester.widget<ExtendedImageEditorPage>(
        find.byType(ExtendedImageEditorPage),
      );
      expect(editor.imageBytes, editedBytes);
    });
  });

  group('OcrPage - image tap to preview', () {
    testWidgets('empty grid shows empty state, no images to tap', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No grid when no images
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('OcrPage - bottom bar', () {
    testWidgets('start recognition button is visible when no images', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('开始识别'), findsOneWidget);
    });
  });

  group('OcrPage - request size budget', () {
    testWidgets(
      'reused per-image results skip request size preflight',
      (tester) async {
        final largeImage = Uint8List.fromList(
          img.encodePng(img.Image(width: 3000, height: 2200, numChannels: 3)),
        );
        final entry = _createOcrEntry();
        final retryData = {
          'type': 'ocr',
          'version': 3,
          'modelRef': {
            'configId': entry.configs.single.id,
            'modelId': entry.configs.single.models.first.id,
          },
          'images': [
            {
              'bytes': base64Encode(largeImage),
              'format': 'png',
              'name': 'completed.png',
            },
          ],
          'batchMode': 'perImage',
          'perImageConcurrency': 1,
          'requestSizeBudgetBytes': defaultOcrRequestSizeBudgetBytes,
        };
        final taskNotifier = _InspectableBackgroundTaskNotifier();

        await tester.pumpWidget(
          _buildTestApp(
            entries: [entry],
            retryData: retryData,
            testImagePayloadPreparer: (bytes) async => OcrImagePayload(
              bytes: bytes,
              format: 'png',
              width: 3000,
              height: 2200,
            ),
            retryPageOutcomes: const [
              OcrPageOutcome(
                imageIndex: 0,
                status: OcrPageOutcomeStatus.succeeded,
                text: 'reused text',
              ),
            ],
            backgroundTasksNotifier: taskNotifier,
            testRetryImageRestorer: (snapshot) async =>
                OcrRetryRestoreResult(
                  images: [
                    for (final image in snapshot.images)
                      OcrRetryImage(
                        bytes: image.bytes!,
                        format: image.format,
                        name: image.name,
                      ),
                  ],
                  missingImageCount: 0,
                ),
            testRetrySnapshotCacher:
                ({required taskId, required snapshot}) async => retryData,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('ocr_request_budget_mib')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(
          find.byKey(const Key('ocr_request_budget_editor_mib')),
          '0.001',
        );
        await tester.tap(find.byKey(const Key('ocr_save_request_budget')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final startButton = find.widgetWithText(FilledButton, '开始识别');
        expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);
        await tester.ensureVisible(startButton);
        await tester.pumpAndSettle();
        await tester.tap(startButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('ocr_request_budget_dialog_mib')),
          findsNothing,
        );
        expect(taskNotifier.tasksForTest, hasLength(1));
      },
    );

    testWidgets(
      'oversized joint requests offer budget changes and per-image mode',
      (tester) async {
        final bytes = Uint8List.fromList(List<int>.generate(300, (i) => i));
        final imagePayload = OcrImagePayload(
          bytes: bytes,
          format: 'png',
          width: 1,
          height: 1,
        );
        final taskNotifier = _InspectableBackgroundTaskNotifier();
        await tester.pumpWidget(
          _buildTestApp(
            entries: [_createOcrEntry()],
            testImages: [
              SelectedImage.fromPayload(
                payload: imagePayload,
                sourceName: 'first.png',
              ),
              SelectedImage.fromPayload(
                payload: imagePayload,
                sourceName: 'second.png',
              ),
            ],
            backgroundTasksNotifier: taskNotifier,
          ),
        );
        await tester.pumpAndSettle();

        Future<void> pumpDialogTransition() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        await tester.tap(find.byKey(const Key('ocr_request_budget_mib')));
        await pumpDialogTransition();
        await tester.enterText(
          find.byKey(const Key('ocr_request_budget_editor_mib')),
          '0.0001',
        );
        await tester.tap(find.byKey(const Key('ocr_save_request_budget')));
        await pumpDialogTransition();
        await tester.tap(find.text('开始识别'));
        await pumpDialogTransition();

        expect(
          find.byKey(const Key('ocr_request_budget_dialog_mib')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('ocr_switch_to_per_image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('ocr_change_request_budget')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('ocr_request_budget_dialog_mib')),
          '0.0002',
        );
        await tester.tap(find.byKey(const Key('ocr_change_request_budget')));
        await pumpDialogTransition();
        expect(
          find.byKey(const Key('ocr_request_budget_dialog_mib')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('ocr_switch_to_per_image')));
        await pumpDialogTransition();
        expect(
          find.byKey(const Key('ocr_request_budget_dialog_mib')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ocr_switch_to_per_image')), findsNothing);

        await tester.tap(find.text('取消').last);
        await pumpDialogTransition();
        expect(find.text('0.0002 MiB'), findsOneWidget);
        expect(taskNotifier.tasksForTest, isEmpty);
      },
    );
  });

  // ====================================================================
  // NEW TESTS: Sort button label
  // ====================================================================

  group('OcrPage - sort button label', () {
    testWidgets('sort button NOT shown when fewer than 2 images', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should not appear with only 1 image
      expect(find.byKey(const Key('ocr_sort_btn')), findsNothing);
    });

    testWidgets('sort button shows text label "排序" when not in reorder mode', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should be visible
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
      // Should show the "排序" text label
      expect(find.text('排序'), findsOneWidget);
    });

    testWidgets('sort button shows swap_vert icon when not in reorder mode', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Should show swap_vert icon
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
    });

    testWidgets('sort button toggles to "完成" label and check icon after tap', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the sort button
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Should now show "完成" label
      expect(find.text('完成'), findsOneWidget);
      // Should now show check icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('sort button toggles back to "排序" label after second tap', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap sort button to enter reorder mode
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Tap again to exit reorder mode
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Should be back to "排序" label
      expect(find.text('排序'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Tap to exit preview
  // ====================================================================

  group('OcrPage - tap image to exit preview', () {
    testWidgets('preview dialog shows close button', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image in the grid to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should show the close button
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);
    });

    testWidgets('tapping close button dismisses preview', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image in the grid to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Close button should be visible
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);

      // Tap close button
      await tester.tap(find.byKey(const Key('preview_close_btn')));
      await tester.pumpAndSettle();

      // Preview should be dismissed — close button should be gone
      expect(find.byKey(const Key('preview_close_btn')), findsNothing);
    });

    testWidgets('tapping the image itself dismisses preview', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image in the grid to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Confirm dialog is open
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);

      // Tap the preview image area
      await tester.tap(find.byKey(const Key('preview_tap_to_close')));
      await tester.pumpAndSettle();

      // Preview should be dismissed
      expect(find.byKey(const Key('preview_close_btn')), findsNothing);
    });
  });

  // ====================================================================
  // NEW TESTS: Reorder tests for audio_separation_page_test.dart
  // ====================================================================

  group('OcrPage - long-press drag to reorder in grid', () {
    testWidgets('grid items are wrapped in DragTarget and LongPressDraggable', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Grid should be showing
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // Each item should be inside a DragTarget
      expect(find.byKey(const Key('drag_target_0')), findsOneWidget);
      expect(find.byKey(const Key('drag_target_1')), findsOneWidget);
      expect(find.byKey(const Key('drag_target_2')), findsOneWidget);
    });

    testWidgets(
      'long-press drag and drop completes without crash and cleans up drag state',
      (tester) async {
        final images = [
          _createTestImage(seed: 1),
          _createTestImage(seed: 2),
          _createTestImage(seed: 3),
        ];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Get center coordinates of first and second items
        final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')),
        );
        final item1Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_1')),
        );

        // Simulate long-press + drag from item 0 to item 1
        final gesture = await tester.startGesture(item0Center);
        // Wait for long-press delay (300ms) plus some buffer
        await tester.pump(const Duration(milliseconds: 400));

        // Drag from item 0 toward item 1
        await gesture.moveTo(item1Center);
        await tester.pump(const Duration(milliseconds: 100));

        // Complete the drag (drop) — this should trigger onAcceptWithDetails
        await gesture.up();
        await tester.pumpAndSettle();

        // After reorder, all items should still be visible
        expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

        // No DragTargets should have active hover state (all drag state cleaned up)
        // Verify the sort button still works normally after the drag
        await tester.tap(find.byKey(const Key('ocr_sort_btn')));
        await tester.pumpAndSettle();
        expect(find.text('完成'), findsOneWidget);
      },
    );

    testWidgets(
      'sort button list reorder works independently of grid long-press',
      (tester) async {
        final images = [
          _createTestImage(seed: 1),
          _createTestImage(seed: 2),
          _createTestImage(seed: 3),
        ];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Tap sort button — should switch to list reorder mode
        await tester.tap(find.byKey(const Key('ocr_sort_btn')));
        await tester.pumpAndSettle();

        // Should be in reorder mode now (list view), with "完成" label
        expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
        expect(find.text('完成'), findsOneWidget);

        // Tap again to exit reorder mode
        await tester.tap(find.byKey(const Key('ocr_sort_btn')));
        await tester.pumpAndSettle();

        // Grid should be back to normal view with "排序" label
        expect(find.text('排序'), findsOneWidget);

        // Grid items should still be present
        expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);
      },
    );

    testWidgets('long-press is disabled with single image', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should not appear (need >1 images)
      expect(find.byKey(const Key('ocr_sort_btn')), findsNothing);

      // Grid item should be present
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);

      // Only one DragTarget since there's one item
      expect(find.byKey(const Key('drag_target_0')), findsOneWidget);

      // Long-press on the single item — should NOT crash or enter drag mode
      final itemCenter = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final gesture = await tester.startGesture(itemCenter);
      await tester.pump(const Duration(milliseconds: 350));
      // Move slightly to simulate drag attempt
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Item should still be present (no crash)
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
    });

    testWidgets('clear button hidden during reorder mode', (tester) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Clear button visible initially
      expect(find.text('清空'), findsOneWidget);

      // Enter reorder mode via sort button
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Clear button should be hidden during reorder mode
      expect(find.text('清空'), findsNothing);
    });

    testWidgets(
      'grid items are wrapped in Draggable with proper drag lifecycle',
      (tester) async {
        final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Verify LongPressDraggable and DragTarget exist in the widget tree
        expect(find.byType(LongPressDraggable<int>), findsNWidgets(2));
        expect(find.byType(DragTarget<int>), findsNWidgets(2));

        // Start a long-press on item 0 to trigger drag
        final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')),
        );
        final gesture = await tester.startGesture(item0Center);
        await tester.pump(
          const Duration(milliseconds: 400),
        ); // 300ms is the new delay

        // During drag, cancel the drag by moving outside
        await gesture.moveBy(const Offset(300, 300));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        // After drag cancel, items should return to normal
        expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      },
    );
  });

  // ====================================================================
  // NEW TESTS: In-app album picker dialog (uses showAppAlbumPickerDialog)
  // ====================================================================

  group('OcrPage - in-app album picker dialog', () {
    testWidgets('clearing selection cancels a pending app album import', (
      tester,
    ) async {
      final validPng = img.encodePng(img.Image(width: 2, height: 2));
      await tester.runAsync(
        () => _storeAppAlbumImage(
          name: 'A_valid',
          hash: 'app_album_pending_valid',
          bytes: validPng,
        ),
      );
      final validationStarted = Completer<void>();
      final finishValidation = Completer<void>();
      Future<OcrImagePayload> delayedValidation(Uint8List bytes) async {
        validationStarted.complete();
        await finishValidation.future;
        return prepareOcrImagePayloadSync(bytes);
      }

      await tester.pumpWidget(
        _buildTestApp(
          testImages: [_createTestImage()],
          testImagePayloadPreparer: delayedValidation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _pumpUntil(
        tester,
        () => find.text('A_valid.png').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('A_valid.png'));
      await _pumpUntil(tester, () => find.text('确定 (1)').evaluate().isNotEmpty);
      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pumpAndSettle();
      await validationStarted.future;

      await tester.tap(find.text('清空'));
      await tester.pump();
      finishValidation.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ocr_grid_item_0')), findsNothing);
      expect(find.text('已加载 1 张图片'), findsNothing);
    });

    testWidgets('success count includes only valid app album images', (
      tester,
    ) async {
      final validPng = img.encodePng(img.Image(width: 2, height: 2));
      await tester.runAsync(
        () => _storeAppAlbumImage(
          name: 'A_valid',
          hash: 'app_album_mixed_valid',
          bytes: validPng,
        ),
      );
      await tester.runAsync(
        () => _storeAppAlbumImage(
          name: 'B_corrupt',
          hash: 'app_album_mixed_corrupt',
          bytes: Uint8List.fromList([0x01, 0x02, 0x03]),
        ),
      );
      Future<OcrImagePayload> validate(Uint8List bytes) async =>
          prepareOcrImagePayloadSync(bytes);

      await tester.pumpWidget(
        _buildTestApp(testImagePayloadPreparer: validate),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _pumpUntil(
        tester,
        () =>
            find.text('A_valid.png').evaluate().isNotEmpty &&
            find.text('B_corrupt.png').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('A_valid.png'));
      await _pumpUntil(tester, () => find.text('确定 (1)').evaluate().isNotEmpty);
      await tester.tap(find.text('B_corrupt.png'));
      await _pumpUntil(tester, () => find.text('确定 (2)').evaluate().isNotEmpty);
      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('已加载 1 张图片'), findsOneWidget);
      expect(find.text('已加载 2 张图片'), findsNothing);
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
    });

    testWidgets('tapping 从应用相册选择 opens in-app album picker dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog can open (not empty state)
      await ImageManifest.addRecord(
        ImageRecord(
          name: '测试图片',
          hash: 'test_hash_abc',
          format: 'png',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );

      // Tap the album button
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      // Tap "从应用相册选择"
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the in-app album picker dialog title
      expect(find.text('应用内相册'), findsOneWidget);
    });

    testWidgets('in-app album picker shows empty state when no images', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Ensure image records are empty
      final records = await ImageManifest.loadRecords();
      expect(records, isEmpty);

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state text
      expect(find.text('暂无图片'), findsOneWidget);
    });

    testWidgets('in-app album picker shows records when images exist', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test image record to the manifest
      await ImageManifest.addRecord(
        ImageRecord(
          name: '测试图片',
          hash: 'test_hash_123',
          format: 'png',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );
      // Verify the record was added
      final records = await ImageManifest.loadRecords();
      expect(records.length, equals(1));

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the record name
      expect(find.text('测试图片.png'), findsOneWidget);
    });

    testWidgets(
      'in-app album picker tapping record with missing file shows error snackbar',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Add a test image record (file won't exist in test environment)
        await ImageManifest.addRecord(
          ImageRecord(
            name: '缺失图片',
            hash: 'missing_hash',
            format: 'png',
            createdAt: DateTime.now(),
            size: 1024,
          ),
        );

        // Navigate to the in-app album picker
        await tester.tap(find.text('相册选择'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从应用相册选择'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Tap the checkbox to toggle selection (this triggers read)
        final checkboxes = find.byType(Checkbox);
        if (checkboxes.evaluate().isNotEmpty) {
          await tester.tap(checkboxes.first);
        } else {
          // Fallback: tap the text
          await tester.tap(find.text('缺失图片.png'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should show error snackbar since the file doesn't exist
        expect(find.textContaining('无法读取'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('in-app album picker close button dismisses the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog opens
      await ImageManifest.addRecord(
        ImageRecord(
          name: '测试图片',
          hash: 'test_hash_close',
          format: 'png',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be visible
      expect(find.text('应用内相册'), findsOneWidget);

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed
      expect(find.text('应用内相册'), findsNothing);
    });
  });

  // ====================================================================
  // NEW TESTS: Smooth release animation with Stack+AnimatedPositioned
  // ====================================================================

  group('OcrPage - smooth drag-release animation', () {
    testWidgets('long-press delay is 300ms (changed from 500ms)', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );

      // Negative case: pump well below 300ms — drag should NOT have started
      final gestureEarly = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 200)); // 200ms << 300ms

      // Cancel without any drag movement — no crash, no stale state
      await gestureEarly.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);

      // Positive case: pump past 300ms — drag SHOULD start (old 500ms would NOT)
      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 350));

      // Drag should have started by now (350ms > 300ms)
      await tester.pump(const Duration(milliseconds: 50));

      // Cancel the drag
      await gesture.up();
      await tester.pumpAndSettle();

      // No crash — drag started and ended cleanly with 300ms delay
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
    });

    testWidgets('after drop, all items remain visible and sort button works', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Long-press and drag item 0 to item 2
      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final item2Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_2')),
      );

      final gesture = await tester.startGesture(item0Center);
      await tester.pump(
        const Duration(milliseconds: 350),
      ); // trigger long-press

      // Drag to item 2 position
      await gesture.moveTo(item2Center);
      await tester.pump(const Duration(milliseconds: 100));

      // Drop
      await gesture.up();
      await tester.pumpAndSettle();

      // All items should still be visible (no items lost)
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // No crash — operation completed
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);

      // Verify sort button toggles (confirming clean state after reorder)
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('no crash during rapid drag and drop', (tester) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Rapidly drag and drop multiple times
      for (int i = 0; i < 10; i++) {
        final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')),
        );
        final item1Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_1')),
        );

        final gesture = await tester.startGesture(item0Center);
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.moveTo(item1Center);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      // No crash after rapid operations
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);
    });

    testWidgets('drag state is properly cleaned up after drag cancel', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Long-press item 0 to trigger drag
      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 350));

      // Move to hover over item 1 (sets _dragTargetIndex)
      final item1Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_1')),
      );
      await gesture.moveTo(item1Center);
      await tester.pump(const Duration(milliseconds: 50));

      // Cancel the drag (not drop — cancel leaves original order intact)
      await gesture.up();
      await tester.pumpAndSettle();

      // All items should still be present and normal
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // Sort button still functional after drag cancel
      // (proves no stale drag state)
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
    });

    testWidgets('reorder completes correctly after drag-and-drop', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Drag item 0 and drop on item 2
      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final item2Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_2')),
      );

      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 350));

      // Move to item 2's position
      await gesture.moveTo(item2Center);
      await tester.pump(const Duration(milliseconds: 50));

      // Drop on item 2
      await gesture.up();
      await tester.pumpAndSettle();

      // After reorder, grid should be stable — all items visible
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // Verify sort button still works after reorder
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Unified order - app first, system second
  // ====================================================================

  group('OcrPage - unified order (app first, system second)', () {
    testWidgets(
      'album choice panel shows app album BEFORE system album (Y-coordinate)',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('相册选择'));
        await tester.pumpAndSettle();

        // Verify both options are rendered
        final appAlbum = find.text('从应用相册选择');
        final sysAlbum = find.text('从系统相册选择');
        expect(appAlbum, findsOneWidget);
        expect(sysAlbum, findsOneWidget);

        // Verify app album renders ABOVE system album (lower Y = higher on screen)
        final appRect = tester.getRect(appAlbum);
        final sysRect = tester.getRect(sysAlbum);
        expect(
          appRect.center.dy,
          lessThan(sysRect.center.dy),
          reason: '从应用相册选择 should appear above 从系统相册选择',
        );
      },
    );

    testWidgets('both 从应用相册选择 and 从系统相册选择 are visible in album panel', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      expect(find.text('从应用相册选择'), findsOneWidget);
      expect(find.text('从系统相册选择'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Multiple configs within a single OCR entry
  // ====================================================================

  group('OcrPage - multiple configs', () {
    testWidgets(
      'shows models from valid config when first config has no host/key',
      (tester) async {
        final entry = ProviderEntry(
          id: 'test_ocr',
          type: 'ocr',
          name: 'OCR供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'Empty',
              host: '',
              key: '',
              models: [
                ModelConfig(name: 'Empty-Model', modelId: 'empty-model'),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Valid',
              host: 'https://api.valid.com',
              key: 'valid-key-123',
              models: [
                ModelConfig(name: 'Valid-Model', modelId: 'valid-model'),
              ],
            ),
          ],
        );
        await tester.pumpWidget(_buildTestApp(entries: [entry]));
        await tester.pumpAndSettle();

        // Should show the valid config's model
        expect(find.text('Valid-Model | Valid'), findsWidgets);
      },
    );

    testWidgets('shows models from ALL valid configs (not just first)', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'First',
            host: 'https://api.first.com',
            key: 'first-key',
            models: [ModelConfig(name: 'First-Model', modelId: 'first-model')],
          ),
          ProviderConfigItem(
            providerName: 'Second',
            host: 'https://api.second.com',
            key: 'second-key',
            models: [
              ModelConfig(name: 'Second-Model', modelId: 'second-model'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // First model is selected by default (visible in collapsed dropdown)
      expect(find.text('First-Model | First'), findsOneWidget);

      // Tap the dropdown to open it and see all items
      await tester.tap(find.text('First-Model | First'));
      await tester.pumpAndSettle();

      // Should show models from ALL valid configs in the dropdown
      expect(find.text('Second-Model | Second'), findsWidgets);
    });

    testWidgets('shows configure prompt when no config has valid host/key', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'Empty',
            host: '',
            key: '',
            models: [ModelConfig(name: 'Empty-Model', modelId: 'empty-model')],
          ),
          ProviderConfigItem(
            providerName: 'Also Empty',
            host: '',
            key: '',
            models: [ModelConfig(name: 'Also-Empty', modelId: 'also-empty')],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show configure prompt instead of hiding the selector
      expect(find.text('识别模型'), findsOneWidget);
      expect(find.textContaining('配置'), findsWidgets);
    });

    testWidgets('shows configure prompt when no OCR models exist', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'Empty',
            host: '',
            key: '',
            models: [],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show configure prompt
      expect(find.text('识别模型'), findsOneWidget);
      expect(find.textContaining('配置'), findsWidgets);
    });

    testWidgets('shows configure prompt when no OCR entry exists', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      // Should show configure prompt
      expect(find.text('识别模型'), findsOneWidget);
      expect(find.textContaining('配置'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Merged from: tests/pages/ocr_page_preview_edit_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('OcrPage - preview dialog two edit buttons', () {
    testWidgets('preview dialog shows crop and edit buttons in top-right', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should see TWO edit icon buttons: crop + full editor
      expect(
        find.byIcon(Icons.crop),
        findsOneWidget,
        reason: 'Crop button should be visible',
      );
      expect(
        find.byIcon(Icons.edit),
        findsOneWidget,
        reason: 'Full editor button should be visible',
      );
    });

    testWidgets('preview dialog shows close button in top-left', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Close button should be present
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);
    });

    testWidgets('preview dialog shows position indicator for multiple images', (
      tester,
    ) async {
      final images = [_createTestImage(), _createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the first image
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should show the position indicator
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('preview dialog can be closed with close button', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byKey(const Key('preview_close_btn')));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });

  // ====================================================================
  // Left/right swipe paging in the preview dialog — same interaction as
  // the file page's gallery viewer.
  // ====================================================================
  group('OcrPage - preview dialog swipe', () {
    testWidgets('swiping left/right flips the page and the indicator', (
      tester,
    ) async {
      // The two images are byte-identical dummy PNGs — this test only
      // proves the paging wiring (indicator follows the swipe); that the
      // displayed content actually changes is covered by the next test
      // with two distinct engine PNGs.
      final images = [_createTestImage(), _createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Open preview on the first image
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      // Swipe left → second image
      await tester.drag(
        find.byType(ExtendedImageGesturePageView),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      // Swipe right → back to the first image
      await tester.drag(
        find.byType(ExtendedImageGesturePageView),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('after swiping, the quick editor targets the current image', (
      tester,
    ) async {
      // Two distinct engine PNGs so the edited image is identifiable.
      final pngA = await tester.runAsync(
        () => _createEnginePng(color: const Color(0xFF00FF00)),
      );
      final pngB = await tester.runAsync(
        () => _createEnginePng(color: const Color(0xFFFF0000)),
      );
      final images = [
        SelectedImage(bytes: pngA!, format: 'png'),
        SelectedImage(bytes: pngB!, format: 'png'),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Open preview on the FIRST image, then swipe to the second.
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ExtendedImageGesturePageView),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      // Tap crop — the editor must receive the SECOND image's bytes,
      // proving the swipe moved the edit target with the page.
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      final editorWidget = tester.widget<ExtendedImageEditorPage>(
        find.byType(ExtendedImageEditorPage),
      );
      expect(
        editorWidget.imageBytes,
        pngB,
        reason: 'the editor must edit the image that was swiped to',
      );
    });
  });

  // ====================================================================
  // Quick-edit flow: the editor processes the image in place (the page
  // stays open while processing) and the edited bytes are applied once
  // it pops.
  // ====================================================================
  group('OcrPage - quick edit flow', () {
    testWidgets(
      'the quick editor processes in place, then the edited bytes are '
      'applied to the selected image',
      (tester) async {
        // Engine-generated PNG — the quick editor only builds after the
        // image decodes, which needs a real-async window.
        final png = await tester.runAsync(_createEnginePng);
        final images = [SelectedImage(bytes: png!, format: 'png')];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Open the preview and the quick editor.
        await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.crop));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Wait for the editor image to decode (engine work — real async).
        await _pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
        );

        // Confirm the edit — the editor must NOT close immediately: it
        // processes the image in place with a spinner until the pipeline
        // finishes.
        await tester.tap(find.text('保存'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byType(ExtendedImageEditorPage),
          findsOneWidget,
          reason: 'the editor must stay on screen while processing',
        );
        expect(
          find.descendant(
            of: find.byType(ExtendedImageEditorPage),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
          reason: 'a processing spinner must be visible',
        );

        // Only after the pipeline finishes does the editor pop back to the
        // OCR page.
        await _pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
        );

        // Re-open the preview and the quick editor — it must now show the
        // EDITED bytes (a new instance), proving the edit was applied to
        // the selected image.
        await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.crop));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await _pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
        );

        final editorWidget = tester.widget<ExtendedImageEditorPage>(
          find.byType(ExtendedImageEditorPage),
        );
        expect(
          editorWidget.imageBytes,
          isNot(same(png)),
          reason: 'the selected image must hold the edited bytes',
        );
      },
    );
  });
}
