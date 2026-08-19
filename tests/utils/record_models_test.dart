import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/manifest_database_shared.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  group('record model roundtrips', () {
    test('AudioRecord toMap/fromMap preserves all fields', () {
      final now = DateTime.parse('2024-05-01T10:20:30.123');
      final modified = DateTime.parse('2024-05-01T11:00:00.000');
      final record = AudioRecord(
        id: 'audio_rt',
        name: '我的录音',
        hash: 'h_audio',
        format: 'wav',
        createdAt: now,
        modifiedAt: modified,
        size: 12345,
        folder: 'folder/sub',
        sourceText: '你好世界',
        duration: 42,
      );

      final restored = AudioRecord.fromMap(record.toMap());

      expect(restored.id, equals('audio_rt'));
      expect(restored.name, equals('我的录音'));
      expect(restored.hash, equals('h_audio'));
      expect(restored.format, equals('wav'));
      expect(restored.createdAt, equals(now));
      expect(restored.modifiedAt, equals(modified));
      expect(restored.size, equals(12345));
      expect(restored.folder, equals('folder/sub'));
      expect(restored.sourceText, equals('你好世界'));
      expect(restored.duration, equals(42));
    });

    test('ImageRecord toMap/fromMap preserves all fields', () {
      final now = DateTime.parse('2024-05-02T08:00:00.000');
      final modified = DateTime.parse('2024-05-02T09:30:00.000');
      final record = ImageRecord(
        id: 'img_rt',
        name: '照片',
        hash: 'h_img',
        format: 'png',
        createdAt: now,
        modifiedAt: modified,
        size: 999,
        folder: 'a/b',
      );

      final restored = ImageRecord.fromMap(record.toMap());

      expect(restored.id, equals('img_rt'));
      expect(restored.name, equals('照片'));
      expect(restored.hash, equals('h_img'));
      expect(restored.format, equals('png'));
      expect(restored.createdAt, equals(now));
      expect(restored.modifiedAt, equals(modified));
      expect(restored.size, equals(999));
      expect(restored.folder, equals('a/b'));
    });

    test('VideoRecord toMap/fromMap preserves all fields', () {
      final now = DateTime.parse('2024-05-03T12:00:00.000');
      final modified = DateTime.parse('2024-05-03T13:00:00.000');
      final record = VideoRecord(
        id: 'vid_rt',
        name: 'video',
        hash: 'h_vid',
        format: 'mp4',
        createdAt: now,
        modifiedAt: modified,
        size: 5555,
        folder: 'x',
        duration: 60000,
      );

      final restored = VideoRecord.fromMap(record.toMap());

      expect(restored.id, equals('vid_rt'));
      expect(restored.name, equals('video'));
      expect(restored.hash, equals('h_vid'));
      expect(restored.format, equals('mp4'));
      expect(restored.createdAt, equals(now));
      expect(restored.modifiedAt, equals(modified));
      expect(restored.size, equals(5555));
      expect(restored.folder, equals('x'));
      expect(restored.duration, equals(60000));
    });

    test('TextRecord toMap/fromMap preserves all fields', () {
      final now = DateTime.parse('2024-05-04T15:45:00.000');
      final modified = DateTime.parse('2024-05-04T16:00:00.000');
      final record = TextRecord(
        id: 'txt_rt',
        name: '笔记',
        hash: 'h_txt',
        format: 'txt',
        createdAt: now,
        modifiedAt: modified,
        size: 77,
        folder: 'notes',
        textLength: 88,
      );

      final restored = TextRecord.fromMap(record.toMap());

      expect(restored.id, equals('txt_rt'));
      expect(restored.name, equals('笔记'));
      expect(restored.hash, equals('h_txt'));
      expect(restored.format, equals('txt'));
      expect(restored.createdAt, equals(now));
      expect(restored.modifiedAt, equals(modified));
      expect(restored.size, equals(77));
      expect(restored.folder, equals('notes'));
      expect(restored.textLength, equals(88));
    });

    test('旧数据缺失 modifiedAt 时回退为 createdAt（向后兼容）', () {
      // 模拟升级前持久化的记录：只有 createdAt 没有 modifiedAt
      final legacyAudio = AudioRecord.fromMap({
        'id': 'a1',
        'name': '旧录音',
        'hash': 'h1',
        'format': 'wav',
        'createdAt': '2024-01-01T08:00:00.000',
        'size': 100,
        'folder': '',
      });
      expect(
        legacyAudio.modifiedAt,
        equals(DateTime.parse('2024-01-01T08:00:00.000')),
      );

      final legacyImage = ImageRecord.fromMap({
        'id': 'i1',
        'name': '旧照片',
        'hash': 'h2',
        'format': 'jpg',
        'createdAt': '2024-02-02T08:00:00.000',
        'size': 200,
        'folder': '',
      });
      expect(
        legacyImage.modifiedAt,
        equals(DateTime.parse('2024-02-02T08:00:00.000')),
      );

      final legacyVideo = VideoRecord.fromMap({
        'id': 'v1',
        'name': '旧视频',
        'hash': 'h3',
        'format': 'mp4',
        'createdAt': '2024-03-03T08:00:00.000',
        'size': 300,
        'folder': '',
      });
      expect(
        legacyVideo.modifiedAt,
        equals(DateTime.parse('2024-03-03T08:00:00.000')),
      );

      final legacyText = TextRecord.fromMap({
        'id': 't1',
        'name': '旧文本',
        'hash': 'h4',
        'format': 'txt',
        'createdAt': '2024-04-04T08:00:00.000',
        'size': 400,
        'folder': '',
      });
      expect(
        legacyText.modifiedAt,
        equals(DateTime.parse('2024-04-04T08:00:00.000')),
      );
    });

    test('fromMap tolerates missing fields with defaults', () {
      final audio = AudioRecord.fromMap(const {});
      expect(audio.name, equals(''));
      expect(audio.hash, equals(''));
      expect(audio.format, equals('wav'));
      expect(audio.size, equals(0));
      expect(audio.folder, equals(''));
      expect(audio.sourceText, equals(''));
      expect(audio.duration, equals(0));
      expect(audio.createdAt, isNotNull);
      expect(audio.id, isNotEmpty, reason: 'id must be generated when absent');

      final text = TextRecord.fromMap(const {});
      expect(text.format, equals('txt'));
      expect(text.textLength, equals(0));

      final image = ImageRecord.fromMap(const {});
      expect(image.format, equals('jpg'));

      final video = VideoRecord.fromMap(const {});
      expect(video.format, equals('mp4'));
      expect(video.duration, equals(0));
    });
  });

  group('manifest database shared conversions', () {
    test('recordToDbRow maps camelCase keys to snake_case', () {
      final row = recordToDbRow({
        'id': 'r1',
        'createdAt': '2024-05-01T10:20:30.000',
        'sourceText': 'hello',
        'textLength': 5,
        'folder': '',
      });

      expect(row['id'], equals('r1'));
      expect(
          row['created_at'],
          equals(DateTime.parse('2024-05-01T10:20:30.000')
              .millisecondsSinceEpoch));
      expect(row['source_text'], equals('hello'));
      expect(row['text_length'], equals(5));
      expect(row['folder'], equals(''));
    });

    test('dbRowToRecord maps snake_case keys to camelCase', () {
      final epoch =
          DateTime.parse('2024-05-01T10:20:30.000').millisecondsSinceEpoch;
      final record = dbRowToRecord({
        'id': 'r1',
        'created_at': epoch,
        'source_text': 'hello',
        'text_length': 5,
      });

      expect(record['id'], equals('r1'));
      expect(record['createdAt'], equals('2024-05-01T10:20:30.000'));
      expect(record['sourceText'], equals('hello'));
      expect(record['textLength'], equals(5));
    });

    test('recordToDbRow/dbRowToRecord roundtrip preserves values', () {
      final original = {
        'id': 'r2',
        'name': 'n',
        'hash': 'h',
        'format': 'wav',
        'createdAt': '2024-06-01T01:02:03.000',
        'modifiedAt': '2024-06-02T01:02:03.000',
        'size': 4,
        'folder': 'f',
        'duration': 9,
      };

      final restored = dbRowToRecord(recordToDbRow(original));

      expect(restored, equals(original));
    });

    test('folderTableFor maps every record table to its folder table', () {
      expect(ManifestTables.folderTableFor(ManifestTables.textRecords),
          equals(ManifestTables.textFolders));
      expect(ManifestTables.folderTableFor(ManifestTables.audioRecords),
          equals(ManifestTables.audioFolders));
      expect(ManifestTables.folderTableFor(ManifestTables.imageRecords),
          equals(ManifestTables.imageFolders));
      expect(ManifestTables.folderTableFor(ManifestTables.videoRecords),
          equals(ManifestTables.videoFolders));
    });

    test('folderTableFor throws on unknown record table', () {
      expect(() => ManifestTables.folderTableFor('unknown_table'),
          throwsArgumentError);
    });
  });
}
