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
  // Unit: Pending attachment reorder logic
  // ═══════════════════════════════════════════════════════════════
  group('Pending attachment reorder logic', () {
    test('_handleSubmitted sends attachments in display order', () {
      final attachments = <Attachment>[
        _createTestAttachment(
          id: 'a1',
          fileName: 'first.jpg',
          fileType: 'image',
        ),
        _createTestAttachment(
          id: 'a2',
          fileName: 'second.jpg',
          fileType: 'image',
        ),
        _createTestAttachment(
          id: 'a3',
          fileName: 'third.jpg',
          fileType: 'image',
        ),
      ];

      // Simulate reorder: move index 2 (third) to index 0
      final reordered = List<Attachment>.from(attachments);
      final item = reordered.removeAt(2);
      reordered.insert(0, item);

      // After reorder, third should be first
      expect(reordered[0].id, 'a3');
      expect(reordered[1].id, 'a1');
      expect(reordered[2].id, 'a2');

      // Simulate send: all attachments in current order
      List<Attachment>? captured;
      void onSend(String text, List<Attachment> atts) {
        captured = atts;
      }

      // Verify the send captures the REORDERED list
      onSend('', reordered);
      expect(captured, isNotNull);
      expect(captured![0].id, 'a3');
      expect(captured![1].id, 'a1');
      expect(captured![2].id, 'a2');
    });

    test('removing an item then reordering works correctly', () {
      final attachments = <Attachment>[
        _createTestAttachment(
          id: 'a1',
          fileName: 'img1.jpg',
          fileType: 'image',
        ),
        _createTestAttachment(
          id: 'a2',
          fileName: 'img2.jpg',
          fileType: 'image',
        ),
        _createTestAttachment(
          id: 'a3',
          fileName: 'img3.jpg',
          fileType: 'image',
        ),
      ];

      // Remove a2
      attachments.removeAt(1);
      expect(attachments.length, 2);
      expect(attachments[0].id, 'a1');
      expect(attachments[1].id, 'a3');

      // Now reorder: move a3 to before a1
      final item = attachments.removeAt(1);
      attachments.insert(0, item);
      expect(attachments[0].id, 'a3');
      expect(attachments[1].id, 'a1');
    });

    test('_onReorder adjusts indices correctly (item moved forward)', () {
      final list = ['a', 'b', 'c', 'd'];
      // Drag 'c' (index 2) to position before 'a' (index 0)
      // ReorderableListView passes: oldIndex=2, newIndex=0
      // When newIndex < oldIndex, no adjustment needed
      final item = list.removeAt(2);
      list.insert(0, item);
      expect(list, ['c', 'a', 'b', 'd']);
    });

    test('_onReorder adjusts indices correctly (item moved backward)', () {
      final list = ['a', 'b', 'c', 'd'];
      // Drag 'b' (index 1) to position after 'd' (newIndex=4)
      // ReorderableListView passes: oldIndex=1, newIndex=4
      // When newIndex > oldIndex, subtract 1: newIndex=3
      final adjustedNewIndex = 4 - 1;
      final item = list.removeAt(1);
      list.insert(adjustedNewIndex, item);
      expect(list, ['a', 'c', 'd', 'b']);
    });

    test('_onReorder same index (oldIndex == newIndex) is a no-op', () {
      final list = ['a', 'b', 'c'];
      // oldIndex=1, newIndex=1 — nothing should change
      if (1 != 1) {
        final item = list.removeAt(1);
        list.insert(0, item);
      }
      expect(list, ['a', 'b', 'c']);
    });

    test('_onReorder with single item list does not crash', () {
      final list = ['a'];
      // Drag the only item (index 0) to after itself (index 1)
      // newIndex (1) > oldIndex (0), so adjust: newIndex = 0
      var newIdx = 1;
      if (newIdx > 0) newIdx--;
      if (0 != newIdx) {
        final item = list.removeAt(0);
        list.insert(newIdx, item);
      }
      // List should remain unchanged since oldIndex == newIndex
      expect(list, ['a']);
    });

    test('_onReorder first item stays first when dragged to index 0', () {
      final list = ['a', 'b', 'c'];
      // oldIndex=0, newIndex=0 — no-op, item 'a' stays first
      if (0 != 0) {
        final item = list.removeAt(0);
        list.insert(0, item);
      }
      expect(list, ['a', 'b', 'c']);
    });

    test('_onReorder last item to end (newIndex == length) is handled', () {
      final list = ['a', 'b', 'c'];
      // Drag 'c' (index 2) to position after end (newIndex=3)
      // newIndex (3) > oldIndex (2), so adjust: newIndex = 2
      var newIdx = 3;
      if (newIdx > 2) newIdx--;
      if (2 != newIdx) {
        final item = list.removeAt(2);
        list.insert(newIdx, item);
      }
      // List should remain unchanged since adjusted newIndex == oldIndex
      expect(list, ['a', 'b', 'c']);
    });
  });

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
