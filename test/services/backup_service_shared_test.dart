import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/backup_service_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('collectAttachmentPaths', () {
    test('collects storage and thumbnail paths from valid conversations',
        () async {
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'c1',
            'messages': [
              {
                'attachments': [
                  {
                    'storagePath': '/data/a.png',
                    'thumbnailPath': '/data/a_thumb.png',
                  },
                  {'storagePath': '/data/b.pdf'},
                ],
              },
              {'attachments': []},
            ],
          },
        ]),
      });

      final paths = await collectAttachmentPaths();

      expect(paths, contains('/data/a.png'));
      expect(paths, contains('/data/a_thumb.png'));
      expect(paths, contains('/data/b.pdf'));
    });

    test('skips corrupt entries instead of dropping every attachment path',
        () async {
      // 回归：单条损坏数据（非 Map 会话/消息/附件、非 List 字段）
      // 只跳过对应条目 —— 旧代码 TypeError 被外层 catch 吞掉，
      // 一条坏数据会让备份丢失所有附件路径。
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          'garbage-string',
          {
            'id': 'c_bad_messages',
            'messages': 'not-a-list',
          },
          {
            'id': 'c_bad_attachments',
            'messages': [
              {'attachments': 'not-a-list'},
            ],
          },
          {
            'id': 'c_valid',
            'messages': [
              {
                'attachments': [
                  {'storagePath': '/data/valid.png'},
                ],
              },
            ],
          },
        ]),
      });

      final paths = await collectAttachmentPaths();

      expect(paths, contains('/data/valid.png'), reason: '合法条目必须仍然被收集');
      expect(paths, isNot(contains('/data/nonexistent')));
    });

    test('non-array conversations returns an empty set', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '{"not": "an array"}',
      });

      final paths = await collectAttachmentPaths();

      expect(paths, isEmpty);
    });
  });
}
