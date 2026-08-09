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

    test('toMap(includeBase64Data: true) 显式携带 base64Data（草稿快照用）', () {
      final att = Attachment(
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'snap-hash',
        storagePath: 'attachments/snap-hash_1.jpg',
        fileSize: 2048,
      )..base64Data = '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAYEBQYFBAYGBQYH';

      final map = att.toMap(includeBase64Data: true);
      final restored = Attachment.fromMap(map);

      expect(map['base64Data'], att.base64Data);
      expect(restored.base64Data, att.base64Data,
          reason: '草稿快照的压缩 base64 必须随 toMap/fromMap 往返保留');
      expect(restored.hash, 'snap-hash');
      expect(restored.fileName, 'photo.jpg');
    });

    test('toMap(includeBase64Data: true) 在 base64Data 为 null 时仍不携带该键', () {
      final att = Attachment(
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'no-b64',
        storagePath: 'attachments/no-b64_1.png',
        fileSize: 1024,
      );

      final map = att.toMap(includeBase64Data: true);

      expect(map.containsKey('base64Data'), false);
    });
  });
}
