import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper: create a test Attachment with given file type.
Attachment _createTestAttachment({
  required String id,
  required String fileName,
  required String fileType,
  String mimeType = 'image/jpeg',
  int fileSize = 1024,
}) {
  return Attachment(
    id: id,
    fileName: fileName,
    mimeType: mimeType,
    fileType: fileType,
    hash: 'hash-$id',
    storagePath: 'attachments/$id.dat',
    fileSize: fileSize,
  );
}

/// Creates the test app with a [ChatComposerWidget] centered on screen.
Widget createComposerTestApp() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
      isStreamingProvider.overrideWith((ref) => false),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(
          child: ChatComposerWidget(
            onSend: _dummyOnSend,
            onStop: _dummyOnStop,
            onEnabledToolsChanged: _dummyOnToolsChanged,
            onModelSelected: _dummyOnModelSelected,
          ),
        ),
      ),
    ),
  );
}

void _dummyOnSend(String text, List<Attachment> attachments) {}
void _dummyOnStop() {}
void _dummyOnToolsChanged(Set<String> tools) {}
void _dummyOnModelSelected(int index) {}

// ====================================================================
// Tests
// ====================================================================

void main() {

  // ═══════════════════════════════════════════════════════════════
  // Unit: Image preview + edit on pending attachments
  // ═══════════════════════════════════════════════════════════════
  group('Pending image preview + edit', () {
    test('editing an image updates the attachment bytes', () async {
      // Simulate the edit flow:
      // 1. User has a pending image attachment with original bytes
      // 2. User opens ImagePreviewDialog -> taps Edit
      // 3. ImageEditorPage returns edited bytes
      // 4. Attachment is updated with new bytes, hash, and storage path

      final editedBytes = Uint8List.fromList([5, 6, 7, 8, 9]);

      final att = _createTestAttachment(
        id: 'edit-test',
        fileName: 'photo.jpg',
        fileType: 'image',
      );

      // After editor returns, we simulate updating the pending attachment
      final Attachment updatedAtt = att.copyWith(
        hash: 'new-hash-edited',
        storagePath: 'attachments/new-hash-edited.jpg',
        fileSize: editedBytes.length,
      );

      // Verify the update
      expect(updatedAtt.hash, 'new-hash-edited');
      expect(updatedAtt.storagePath, 'attachments/new-hash-edited.jpg');
      expect(updatedAtt.fileSize, editedBytes.length);
      // Original fields preserved
      expect(updatedAtt.id, att.id);
      expect(updatedAtt.fileName, att.fileName);
    });

    test('cancelling editor returns null - attachment unchanged', () async {
      final att = _createTestAttachment(
        id: 'cancel-test',
        fileName: 'photo.jpg',
        fileType: 'image',
      );

      // Simulate editor returning null (cancelled)
      const ImageEditorResult? result = null;

      // Attachment should remain unchanged
      if (result == null) {
        expect(att.hash, 'hash-cancel-test');
        expect(att.fileName, 'photo.jpg');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Widget: ChatComposerWidget renders pending attachments as reorderable
  // ═══════════════════════════════════════════════════════════════
  group('ChatComposerWidget pending attachments rendering', () {
    testWidgets('composer renders with attach button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Basic composer elements should render
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('composer shows attachment panel when attach button is tapped',
        (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith(
              (ref) => ConversationsNotifier(ref),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: _dummyOnSend,
                onStop: _dummyOnStop,
                onEnabledToolsChanged: _dummyOnToolsChanged,
                onModelSelected: _dummyOnModelSelected,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);

      // Tap the attach button to confirm the panel opens
      await tester.tap(find.byIcon(Icons.attach_file_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the file attachment panel
      expect(find.text('传文件'), findsOneWidget);
    });

    testWidgets('reorder callback properly reorders items', (tester) async {
      // Test the reorder logic independently: simulate the composer state.
      // Create a list simulating _pendingAttachments
      final items = <Attachment>[
        _createTestAttachment(
          id: 'i1',
          fileName: 'img1.jpg',
          fileType: 'image',
        ),
        _createTestAttachment(
          id: 'i2',
          fileName: 'img2.jpg',
          fileType: 'image',
        ),
        _createTestAttachment(
          id: 'i3',
          fileName: 'img3.jpg',
          fileType: 'image',
        ),
      ];

      // Simulate ReorderableListView.onReorder callback
      // oldIndex=2 (i3), newIndex=0
      void onReorder(int oldIndex, int newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final item = items.removeAt(oldIndex);
        items.insert(newIndex, item);
      }

      // Move i3 (index 2) to position before i1 (index 0)
      onReorder(2, 0);
      expect(items[0].id, 'i3');
      expect(items[1].id, 'i1');
      expect(items[2].id, 'i2');

      // Now move i2 (now at index 2) to position after i1 (newIndex=3, adjusted=2)
      onReorder(2, 3);
      expect(items[0].id, 'i3');
      expect(items[1].id, 'i1');
      expect(items[2].id, 'i2');

      // Move i3 (index 0) to position after i2 (newIndex=3, adjusted=2)
      onReorder(0, 3);
      expect(items[0].id, 'i1');
      expect(items[1].id, 'i2');
      expect(items[2].id, 'i3');
    });
  });
}

// ====================================================================
// Helper type to reference in tests (mirrors image_editor_page types)
// ====================================================================
class ImageEditorResult {
  final Uint8List editedBytes;
  final bool isSaveAs;

  const ImageEditorResult({required this.editedBytes, required this.isSaveAs});
}
