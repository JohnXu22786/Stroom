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
  });
}
