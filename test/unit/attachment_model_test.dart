import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/services/attachment_storage.dart';

void main() {
  group('Attachment', () {
    test('creates with auto-generated id', () {
      final att = Attachment(
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'abc123',
        storagePath: 'attachments/abc123.jpg',
        fileSize: 1024,
      );
      expect(att.id, isNotEmpty);
      expect(att.fileName, 'photo.jpg');
      expect(att.mimeType, 'image/jpeg');
      expect(att.fileType, 'image');
      expect(att.hash, 'abc123');
      expect(att.storagePath, 'attachments/abc123.jpg');
      expect(att.fileSize, 1024);
      expect(att.createdAt, isNotNull);
      expect(att.thumbnailPath, isNull);
    });

    test('toMap / fromMap round-trip', () {
      final original = Attachment(
        id: 'test-id-1',
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        fileType: 'document',
        hash: 'def456',
        storagePath: 'attachments/def456.pdf',
        fileSize: 2048,
        thumbnailPath: 'attachments/def456_thumb.png',
      );

      final map = original.toMap();
      final restored = Attachment.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.fileName, original.fileName);
      expect(restored.mimeType, original.mimeType);
      expect(restored.fileType, original.fileType);
      expect(restored.hash, original.hash);
      expect(restored.storagePath, original.storagePath);
      expect(restored.fileSize, original.fileSize);
      expect(restored.createdAt.toIso8601String(),
          original.createdAt.toIso8601String());
      expect(restored.thumbnailPath, original.thumbnailPath);
    });

    test('toMap excludes null thumbnailPath', () {
      final att = Attachment(
        fileName: 'a.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'abc',
        storagePath: 'attachments/abc.txt',
        fileSize: 100,
      );
      final map = att.toMap();
      expect(map.containsKey('thumbnailPath'), false);
    });

    test('fromMap handles missing thumbnailPath', () {
      final map = <String, dynamic>{
        'id': 't1',
        'fileName': 'a.txt',
        'mimeType': 'text/plain',
        'fileType': 'document',
        'hash': 'abc',
        'storagePath': 'attachments/abc.txt',
        'fileSize': 100,
        'createdAt': DateTime.now().toIso8601String(),
      };
      final att = Attachment.fromMap(map);
      expect(att.thumbnailPath, isNull);
    });

    test('copyWith overrides specified fields', () {
      final base = Attachment(
        fileName: 'a.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'abc',
        storagePath: 'attachments/abc.txt',
        fileSize: 100,
      );
      final copy = base.copyWith(fileName: 'b.txt', fileSize: 200);
      expect(copy.fileName, 'b.txt');
      expect(copy.fileSize, 200);
      expect(copy.mimeType, 'text/plain');
      expect(copy.hash, 'abc');
    });

    test('copyWith returns same fields when no arguments', () {
      final base = Attachment(
        id: 'fixed-id',
        fileName: 'a.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'abc',
        storagePath: 'attachments/abc.txt',
        fileSize: 100,
      );
      final copy = base.copyWith();
      expect(copy.id, 'fixed-id');
      expect(copy.fileName, 'a.txt');
      expect(copy.fileSize, 100);
    });
  });

  group('ChatMessage with attachments', () {
    test('defaults to empty attachments list', () {
      final msg = ChatMessage(role: 'user', content: 'hello');
      expect(msg.attachments, isEmpty);
    });

    test('toMap / fromMap round-trip with attachments', () {
      final att = Attachment(
        fileName: 'img.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'hash123',
        storagePath: 'attachments/hash123.png',
        fileSize: 5000,
      );

      final original = ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'see attached',
        attachments: [att],
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.createdAt.toIso8601String(),
          original.createdAt.toIso8601String());
      expect(restored.attachments, hasLength(1));
      expect(restored.attachments[0].fileName, 'img.png');
      expect(restored.attachments[0].hash, 'hash123');
    });

    test('backward compatibility - missing attachments key defaults to empty',
        () {
      final map = <String, dynamic>{
        'id': 'msg-old',
        'role': 'user',
        'content': 'legacy message',
        'createdAt': DateTime.now().toIso8601String(),
      };
      final msg = ChatMessage.fromMap(map);
      expect(msg.attachments, isEmpty);
      expect(msg.content, 'legacy message');
    });

    test('multiple attachments round-trip', () {
      final atts = [
        Attachment(
          fileName: 'a.pdf',
          mimeType: 'application/pdf',
          fileType: 'document',
          hash: 'h1',
          storagePath: 'attachments/h1.pdf',
          fileSize: 100,
        ),
        Attachment(
          fileName: 'b.jpg',
          mimeType: 'image/jpeg',
          fileType: 'image',
          hash: 'h2',
          storagePath: 'attachments/h2.jpg',
          fileSize: 200,
        ),
      ];

      final original = ChatMessage(
        role: 'assistant',
        content: 'two files',
        attachments: atts,
      );

      final restored =
          ChatMessage.fromMap(original.toMap());

      expect(restored.attachments, hasLength(2));
      expect(restored.attachments[0].fileName, 'a.pdf');
      expect(restored.attachments[1].fileName, 'b.jpg');
    });
  });

  group('AttachmentStorage computeHash', () {
    test('computeHash returns MD5 hex string', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final hash = AttachmentStorage.computeHash(data);
      // known MD5 of "hello world"
      expect(hash, '5eb63bbbe01eeed093cb22bb8f5acdc3');
    });

    test('computeHash is deterministic', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash1 = AttachmentStorage.computeHash(data);
      final hash2 = AttachmentStorage.computeHash(data);
      expect(hash1, hash2);
    });

    test('computeHash matches crypto.md5 directly', () {
      final data = Uint8List.fromList(utf8.encode('test data'));
      final storageHash = AttachmentStorage.computeHash(data);
      final directHash = md5.convert(data).toString();
      expect(storageHash, directHash);
    });

    test('different inputs produce different hashes', () {
      final h1 = AttachmentStorage.computeHash(
          Uint8List.fromList(utf8.encode('abc')));
      final h2 = AttachmentStorage.computeHash(
          Uint8List.fromList(utf8.encode('xyz')));
      expect(h1, isNot(h2));
    });
  });

  group('AttachmentStorage file I/O', () {
    test(
        'saveFile / readFile / deleteFile require platform test',
        () {
      // File I/O tests require platform bindings (dart:io or WebFileStore).
      // These are covered by integration/widget tests running on device/web.
    });
  });
}
