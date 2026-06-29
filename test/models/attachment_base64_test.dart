import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';

void main() {
  group('Attachment base64Data caching', () {
    test('base64Data is NOT included in toMap (not serialized)', () {
      final att = Attachment(
        fileName: 'test.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'abc123',
        storagePath: 'attachments/abc123_12345.png',
        fileSize: 1024,
      )..base64Data =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk';

      final map = att.toMap();

      expect(map.containsKey('base64Data'), false);
      expect(map['fileName'], 'test.png');
      expect(map['hash'], 'abc123');
    });

    test('fromMap does not set base64Data (remains null)', () {
      final map = <String, dynamic>{
        'id': 'att1',
        'fileName': 'test.png',
        'mimeType': 'image/png',
        'fileType': 'image',
        'hash': 'abc123',
        'storagePath': 'attachments/abc123_12345.png',
        'fileSize': 1024,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final att = Attachment.fromMap(map);

      expect(att.base64Data, isNull);
    });

    test('serialization round-trip preserves all fields except base64Data', () {
      final att = Attachment(
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'def456',
        storagePath: 'attachments/def456_67890.jpg',
        fileSize: 2048,
      )..base64Data =
          '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcU';

      final map = att.toMap();
      final restored = Attachment.fromMap(map);

      expect(restored.id, att.id);
      expect(restored.fileName, 'photo.jpg');
      expect(restored.mimeType, 'image/jpeg');
      expect(restored.fileType, 'image');
      expect(restored.hash, 'def456');
      expect(restored.storagePath, 'attachments/def456_67890.jpg');
      expect(restored.fileSize, 2048);
      // base64Data should be lost after round-trip (not persisted)
      expect(restored.base64Data, isNull);
    });

    test('copyWith preserves base64Data', () {
      final att = Attachment(
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        fileType: 'document',
        hash: 'ghi789',
        storagePath: 'attachments/ghi789_11111.pdf',
        fileSize: 4096,
      )..base64Data =
          'JVBERi0xLjQKJcOkw7zDtsOfCjIgMCBvYmoKPDwvTGVuZ3RoIDMgMCBSL0Zp';

      final copied = att.copyWith(fileName: 'renamed.pdf');

      expect(copied.base64Data,
          'JVBERi0xLjQKJcOkw7zDtsOfCjIgMCBvYmoKPDwvTGVuZ3RoIDMgMCBSL0Zp');
      expect(copied.fileName, 'renamed.pdf');
      expect(copied.hash, 'ghi789');
    });

    test('multiple attachments can each have their own base64Data', () {
      final att1 = Attachment(
        fileName: 'img1.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'hash1',
        storagePath: 'attachments/hash1.png',
        fileSize: 100,
      )..base64Data = 'base64_data_1';

      final att2 = Attachment(
        fileName: 'img2.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'hash2',
        storagePath: 'attachments/hash2.jpg',
        fileSize: 200,
      )..base64Data = 'base64_data_2';

      expect(att1.base64Data, 'base64_data_1');
      expect(att2.base64Data, 'base64_data_2');
      expect(att1.base64Data, isNot(att2.base64Data));
    });

    test('base64Data defaults to null when not set', () {
      final att = Attachment(
        fileName: 'file.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'hash3',
        storagePath: 'attachments/hash3.txt',
        fileSize: 50,
      );

      expect(att.base64Data, isNull);
    });
  });
}
