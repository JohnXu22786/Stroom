import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/widgets/file_preview.dart';
import 'package:stroom/widgets/image_preview_dialog.dart';

/// Fake [PathProviderPlatform] so [AttachmentStorage] file IO works in
/// widget tests (path_provider has no default test implementation).
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String root;

  _FakePathProviderPlatform(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

/// Pumps until [condition] is true or [timeout] elapses, alternating
/// real-async windows (engine image work / file IO) with pumps
/// (fake-zone continuations).
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
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [condition] (an async disk check) is true or [timeout]
/// elapses. The condition runs inside `tester.runAsync` — real disk IO
/// never completes in the widget-test FakeAsync zone.
Future<void> _pumpUntilDisk(
  WidgetTester tester,
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    final done = await tester.runAsync(condition) ?? false;
    if (done) return;
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for disk condition');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the quick editor from the pending attachment chip: taps the
/// preview dialog's crop icon — both preview buttons open the same quick
/// editor.
///
/// The preview bytes load asynchronously via real file IO, so the chip
/// tap is retried (harmlessly) until the preview dialog actually opens.
Future<void> _openEditor(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (find.byType(ImagePreviewDialog).evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('preview dialog never opened');
    }
    if (find.byType(FilePreviewChip).evaluate().isNotEmpty) {
      await tester.tap(find.byType(FilePreviewChip), warnIfMissed: false);
      await tester.pump();
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }

  await tester.tap(find.descendant(
    of: find.byType(ImagePreviewDialog),
    matching: find.byIcon(Icons.crop),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory tempRoot;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalPathProvider = PathProviderPlatform.instance;
    tempRoot = await Directory.systemTemp.createTemp('composer_edit_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempRoot.path);
    await Directory('${tempRoot.path}/tmp').create(recursive: true);
    await Directory('${tempRoot.path}/attachments').create(recursive: true);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup
    }
  });

  Widget buildComposer({
    required List<Attachment> editingAttachments,
    required void Function(String, List<Attachment>) onSend,
    void Function(String, String, List<Attachment>)? onEditSend,
  }) {
    return ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
        activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
        providerEntriesProvider
            .overrideWith((ref) => ProviderEntriesNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatComposerWidget(
              editingMessageId: 'msg-1',
              editingMessageText: 'hello',
              editingMessageAttachments: editingAttachments,
              onSend: onSend,
              onEditSend: onEditSend,
              onStop: () {},
              onEnabledToolsChanged: (_) {},
              onModelSelected: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  Future<Attachment> saveTestAttachment(WidgetTester tester) async {
    final pngBytes = (await tester.runAsync(_createEnginePng))!;
    final storagePath = await tester
        .runAsync(() => AttachmentStorage.saveFile('photo.png', pngBytes));
    return Attachment(
      fileName: 'photo.png',
      mimeType: 'image/png',
      fileType: 'image',
      hash: 'orig-hash',
      storagePath: storagePath!,
      fileSize: pngBytes.length,
      base64Data: base64Encode(pngBytes),
    );
  }

  group('ChatComposerWidget quick-edit flow', () {
    testWidgets(
        'the quick editor processes the image in place (page stays open '
        'while processing) and then the pending attachment is updated '
        'with the edited bytes', (tester) async {
      final att = await saveTestAttachment(tester);
      List<Attachment>? sent;
      await tester.pumpWidget(buildComposer(
        editingAttachments: [att],
        onSend: (text, attachments) => sent = attachments,
        onEditSend: (id, text, attachments) => sent = attachments,
      ));
      await tester.pump();

      await _openEditor(tester);

      // Wait for the editor image to decode (engine work — real async).
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      // Confirm the edit — the editor must NOT close immediately: it
      // processes the image in place, keeping the page on screen with a
      // spinner until the pipeline finishes.
      await tester.tap(find.text('完成'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ExtendedImageEditorPage), findsOneWidget,
          reason: 'the editor must stay on screen while processing');
      expect(
        find.descendant(
          of: find.byType(ExtendedImageEditorPage),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a processing spinner must be visible',
      );

      // Only after the pipeline finishes does the editor pop back to the
      // composer.
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
      );

      // The pop resumes the attachment apply (async file IO) — wait for
      // the edited file to appear in the attachments storage (edit mode
      // keeps the original file, so a second file means the edit landed).
      await _pumpUntilDisk(tester, () async {
        final dir = Directory('${tempRoot.path}/attachments');
        if (!await dir.exists()) return false;
        final files = await dir.list().toList();
        return files.length >= 2;
      });

      // Sending now carries the EDITED attachment, not the original.
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      expect(sent, isNotNull);
      expect(sent!.single.storagePath, startsWith('temp_edited/'),
          reason: 'the sent attachment must be the edited one');
      expect(sent!.single.hash, isNot('orig-hash'));
    });

    testWidgets('closing the editor without confirming does not modify the '
        'attachment', (tester) async {
      final att = await saveTestAttachment(tester);
      List<Attachment>? sent;
      await tester.pumpWidget(buildComposer(
        editingAttachments: [att],
        onSend: (text, attachments) => sent = attachments,
        onEditSend: (id, text, attachments) => sent = attachments,
      ));
      await tester.pump();

      await _openEditor(tester);
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      // Close the editor with X (no confirmation) — the capsule below
      // also has a close icon, so scope the tap to the editor page.
      await tester.tap(find.descendant(
        of: find.byType(ExtendedImageEditorPage),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      // No pipeline ran — the pending attachment is unchanged.
      expect(find.byType(ExtendedImageEditorPage), findsNothing);
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      expect(sent, isNotNull);
      expect(sent!.single.storagePath, att.storagePath,
          reason: 'the attachment must be the original one');
      expect(sent!.single.hash, 'orig-hash');
    });
  });
}
