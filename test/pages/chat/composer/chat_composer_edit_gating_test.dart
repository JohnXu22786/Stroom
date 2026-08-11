import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/pages/image_editor_page.dart';
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

/// Opens an editor from the pending attachment chip: taps the preview
/// dialog's [icon] — crop opens the quick editor, edit opens the full
/// editor (matching the OCR page).
///
/// The preview bytes load asynchronously via real file IO, so the chip
/// tap is retried (harmlessly) until the preview dialog actually opens.
Future<void> _openEditor(WidgetTester tester, IconData icon) async {
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

  // The composer in edit mode also has an Icons.edit in its capsule —
  // scope the tap to the preview dialog.
  await tester.tap(find.descendant(
    of: find.byType(ImagePreviewDialog),
    matching: find.byIcon(icon),
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
    tempRoot = await Directory.systemTemp.createTemp('composer_gating_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempRoot.path);
    // The composer writes edited images to the temp cache directory.
    await Directory('${tempRoot.path}/tmp').create(recursive: true);
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

  group('ChatComposerWidget quick-edit send gating', () {
    testWidgets(
        'send is blocked (button disabled + banner) while an image edit '
        'processes, then re-enabled', (tester) async {
      // Desktop platform so the Enter-key send path is active too.
      // Restore in try/finally (repo convention) — flutter_test asserts
      // debug variables are unchanged at test end.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final att = await saveTestAttachment(tester);
        List<Attachment>? sent;
        await tester.pumpWidget(buildComposer(
          editingAttachments: [att],
          onSend: (text, attachments) => sent = attachments,
          onEditSend: (id, text, attachments) => sent = attachments,
        ));
        await tester.pump();

        await _openEditor(tester, Icons.crop);

        // Wait for the editor image to decode (engine work — real async).
        await _pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
        );

        // Confirm the edit — the editor hides its UI immediately and the
        // image processing continues in the background (deferred destroy:
        // the page stays alive until the result is delivered). The
        // composer's in-flight guard is armed synchronously via
        // onSubmitted.
        await tester.tap(find.text('完成'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Gating: while processing, the send button is disabled, a
        // processing banner is shown, and Enter does not send.
        expect(find.text('图片处理中，完成后可发送'), findsOneWidget);
        final sendBtn = tester.widget<IconButton>(find.ancestor(
            of: find.byTooltip('发送'), matching: find.byType(IconButton)));
        expect(sendBtn.onPressed, isNull);

        // Focus the text field and press Enter — must not send. The
        // editor's hidden modal barrier blocks hit-testing while it sits
        // on top, so focus is acquired programmatically via enterText
        // (which bypasses hit-testing); the in-flight guard in
        // _handleSubmitted is what must stop the send.
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(sent, isNull, reason: 'send must be blocked while editing');

        // Once the background pipeline finishes, the banner disappears
        // and the send button re-enables.
        await _pumpUntil(
          tester,
          () => find.text('图片处理中，完成后可发送').evaluate().isEmpty,
        );
        final sendBtn2 = tester.widget<IconButton>(find.ancestor(
            of: find.byTooltip('发送'), matching: find.byType(IconButton)));
        expect(sendBtn2.onPressed, isNotNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('closing the editor without confirming does not block send',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final att = await saveTestAttachment(tester);
        await tester.pumpWidget(buildComposer(
          editingAttachments: [att],
          onSend: (text, attachments) {},
          onEditSend: (id, text, attachments) {},
        ));
        await tester.pump();

        await _openEditor(tester, Icons.crop);
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

        // No pipeline ran — no banner, send stays enabled.
        expect(find.text('图片处理中，完成后可发送'), findsNothing);
        final sendBtn = tester.widget<IconButton>(find.ancestor(
            of: find.byTooltip('发送'), matching: find.byType(IconButton)));
        expect(sendBtn.onPressed, isNotNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'edit button opens the full editor (ImageEditorPage), not the '
        'quick editor', (tester) async {
      final att = await saveTestAttachment(tester);
      await tester.pumpWidget(buildComposer(
        editingAttachments: [att],
        onSend: (text, attachments) {},
        onEditSend: (id, text, attachments) {},
      ));
      await tester.pump();

      await _openEditor(tester, Icons.edit);

      // The full editor page must be pushed (ProImageEditor).
      await _pumpUntil(
        tester,
        () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
      );
      // The quick editor must NOT be open underneath the full editor.
      expect(find.byType(ExtendedImageEditorPage), findsNothing);
    });
  });
}
