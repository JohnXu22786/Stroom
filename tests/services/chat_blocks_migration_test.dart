import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'chat v2 migrates plain replies and repairs empty reasoning rounds once',
    () async {
      final messages = [
        {
          'id': 'plain',
          'role': 'assistant',
          'content': '回答',
          'reasoningContent': '想法',
          'reasoningSections': [],
        },
        {
          'id': 'rounds',
          'role': 'assistant',
          'content': '最终回复',
          'reasoningSections': ['第一步', '', '第三步'],
          'textSections': ['开始', '', '最终回复'],
          'toolCallRoundStarts': [0, 1],
          'toolCalls': [
            {
              'id': 't1',
              'name': 'read',
              'arguments': {},
              'status': 'completed',
              'result': '已压缩',
              'compactedAt': '2026-10-01T00:00:00.000Z',
            },
            {
              'id': 't2',
              'name': 'search',
              'arguments': {},
              'status': 'completed',
              'result': '找到',
            },
          ],
          'blocks': [
            {'type': 'reasoning', 'text': '第一步', 'isComplete': true},
            {'type': 'reasoning', 'text': '第三步', 'isComplete': true},
          ],
          'rawResponse': '保留',
        },
        {
          'id': 'canonical',
          'role': 'assistant',
          'content': '内容',
          'blocks': [
            {'type': 'error', 'message': '错误'},
          ],
        },
        {'id': 'user', 'role': 'user', 'content': '问题'},
        {
          'id': 'failed',
          'role': 'assistant',
          'isError': true,
          'content': '错误: 连接中断\n\n---\n部分回复',
          'blocks': [
            {'type': 'text', 'text': '部分回复'},
          ],
        },
      ];
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          ...DataParts.currentVersions,
          DataParts.chat: 1,
        }),
        'conversations': jsonEncode([
          {'id': 'c1', 'messages': messages},
        ]),
      });
      await DataMigrationService.migrateDataFormatIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('conversations')!;
      final migrated = (jsonDecode(saved) as List).single['messages'] as List;
      expect(migrated[0]['blocks'], [
        {'type': 'reasoning', 'text': '想法', 'isComplete': true},
        {'type': 'text', 'text': '回答'},
      ]);
      final blocks = migrated[1]['blocks'] as List;
      expect(blocks.map((b) => b['type']), [
        'reasoning',
        'text',
        'tool_call',
        'reasoning',
        'tool_call',
        'reasoning',
        'text',
      ]);
      expect(blocks[3]['text'], '');
      expect(blocks[2]['compactedAt'], '2026-10-01T00:00:00.000Z');
      expect(migrated[1]['rawResponse'], '保留');
      expect(migrated[2]['blocks'], [
        {'type': 'error', 'message': '错误'},
        {'type': 'text', 'text': '内容'},
      ]);
      expect(migrated[3], messages[3]);
      expect(migrated[4]['blocks'], [
        {'type': 'text', 'text': '错误: 连接中断'},
        {'type': 'text', 'text': '部分回复'},
      ]);
      expect(
        (await DataMigrationService.getStoredPartVersions())[DataParts.chat],
        2,
      );
      await DataMigrationService.migrateDataFormatIfNeeded();
      expect(prefs.getString('conversations'), saved);
    },
  );

  test(
    'chat v2 restores a later text round missing from partial blocks',
    () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          ...DataParts.currentVersions,
          DataParts.chat: 1,
        }),
        'conversations': jsonEncode([
          {
            'id': 'partial',
            'messages': [
              {
                'role': 'assistant',
                'content': '第一轮第二轮',
                'textSections': ['第一轮', '第二轮'],
                'toolCallRoundStarts': [0, 1],
                'toolCalls': [
                  {
                    'id': 't1',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': 'first',
                  },
                  {
                    'id': 't2',
                    'name': 'search',
                    'arguments': {},
                    'status': 'completed',
                    'result': 'second',
                  },
                ],
                'blocks': [
                  {'type': 'text', 'text': '第一轮'},
                  {'type': 'tool_call', 'id': 't1'},
                  {'type': 'tool_call', 'id': 't2'},
                ],
              },
            ],
          },
        ]),
      });

      await DataMigrationService.migrateDataFormatIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('conversations')!) as List;
      final blocks =
          (saved.single['messages'] as List).single['blocks'] as List;
      expect(blocks.map((block) => block['type']), [
        'text',
        'tool_call',
        'text',
        'tool_call',
      ]);
      expect(
        blocks
            .where((block) => block['type'] == 'text')
            .map((block) => block['text']),
        ['第一轮', '第二轮'],
      );
    },
  );

  test('chat v2 quarantines and resets valid non-list conversations', () async {
    const corrupt = '{"unexpected":"object"}';
    SharedPreferences.setMockInitialValues({
      'data_format_versions': jsonEncode({
        ...DataParts.currentVersions,
        DataParts.chat: 1,
      }),
      'conversations': corrupt,
    });

    await DataMigrationService.migrateDataFormatIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('conversations'), '[]');
    final quarantined = prefs.getKeys().where(
          (key) => key.startsWith('conversations_corrupt_'),
        );
    expect(quarantined, isNotEmpty);
    expect(quarantined.any((key) => prefs.getString(key) == corrupt), isTrue);
    expect(
      (await DataMigrationService.getStoredPartVersions())[DataParts.chat],
      DataParts.currentVersions[DataParts.chat],
    );
  });

  test(
    'chat v2 preserves legacy content after tools without text sections',
    () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          ...DataParts.currentVersions,
          DataParts.chat: 0,
        }),
        'conversations': jsonEncode([
          {
            'id': 'legacy',
            'messages': [
              {
                'role': 'assistant',
                'content': '旧记录里的完整回复',
                'toolCallRoundStarts': [0],
                'toolCalls': [
                  {
                    'id': 't1',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': '完成',
                  },
                ],
              },
              {
                'role': 'assistant',
                'content': '第一轮第二轮',
                'textSections': ['第一轮', '第二轮'],
                'toolCallRoundStarts': [0, 1],
                'toolCalls': [
                  {
                    'id': 't2',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': '第一轮完成',
                  },
                  {
                    'id': 't3',
                    'name': 'search',
                    'arguments': {},
                    'status': 'completed',
                    'result': '第二轮完成',
                  },
                ],
                'blocks': [
                  {
                    'type': 'tool_call',
                    'id': 't2',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': '第一轮完成',
                  },
                  {
                    'type': 'tool_call',
                    'id': 't3',
                    'name': 'search',
                    'arguments': {},
                    'status': 'completed',
                    'result': '第二轮完成',
                  },
                ],
              },
              {
                'role': 'assistant',
                'content': '旧块记录里的完整回复',
                'toolCalls': [
                  {
                    'id': 't4',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': '完成',
                  },
                ],
                'blocks': [
                  {
                    'type': 'tool_call',
                    'id': 't4',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': '完成',
                  },
                ],
              },
            ],
          },
        ]),
      });

      await DataMigrationService.migrateDataFormatIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      final migrated = (jsonDecode(prefs.getString('conversations')!) as List)
          .single['messages'] as List;
      expect((migrated[0]['blocks'] as List).map((block) => block['type']), [
        'tool_call',
        'text',
      ]);
      expect(migrated[0]['blocks'][1]['text'], '旧记录里的完整回复');
      final second = migrated[1]['blocks'] as List;
      expect(second.map((block) => block['type']), [
        'text',
        'tool_call',
        'text',
        'tool_call',
      ]);
      expect(second[0]['text'], '第一轮');
      expect(second[2]['text'], '第二轮');
      expect((migrated[2]['blocks'] as List).map((block) => block['type']), [
        'tool_call',
        'text',
      ]);
      expect(migrated[2]['blocks'][1]['text'], '旧块记录里的完整回复');
    },
  );

  test(
    'chat v2 fallback places content after tools when blocks are absent',
    () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          ...DataParts.currentVersions,
          DataParts.chat: 1,
        }),
        'conversations': jsonEncode([
          {
            'id': 'v1',
            'messages': [
              {
                'role': 'assistant',
                'content': '旧记录里的完整回复',
                'toolCallRoundStarts': [0],
                'toolCalls': [
                  {
                    'id': 't1',
                    'name': 'read',
                    'arguments': {},
                    'status': 'completed',
                    'result': '完成',
                  },
                ],
              },
            ],
          },
        ]),
      });

      await DataMigrationService.migrateDataFormatIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      final migrated = (jsonDecode(prefs.getString('conversations')!) as List)
          .single['messages'] as List;
      expect(
        (migrated.single['blocks'] as List).map((block) => block['type']),
        ['tool_call', 'text'],
      );
      expect(migrated.single['blocks'][1]['text'], '旧记录里的完整回复');
    },
  );

  test(
    'chat v2 ignores malformed optional fields without blocking valid siblings',
    () async {
      final messages = [
        {
          'role': 'assistant',
          'content': 'canonical',
          'reasoningSections': 'bad',
          'blocks': [
            {'type': 'text', 'text': 'canonical'},
          ],
        },
        {
          'role': 'assistant',
          'content': 'fallback',
          'reasoningSections': ['idea', 7],
          'textSections': false,
          'toolCalls': 'bad',
          'toolCallRoundStarts': [0, 'bad'],
        },
        {'role': 'assistant', 'content': 'sibling'},
      ];
      SharedPreferences.setMockInitialValues({
        'data_format_versions': jsonEncode({
          ...DataParts.currentVersions,
          DataParts.chat: 1,
        }),
        'conversations': jsonEncode([
          {'id': 'c', 'messages': messages},
        ]),
      });
      await DataMigrationService.migrateDataFormatIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('conversations')!) as List;
      final migrated = saved.single['messages'] as List;
      expect(migrated[0], messages[0]);
      expect(migrated[1]['blocks'], [
        {'type': 'reasoning', 'text': 'idea', 'isComplete': true},
        {'type': 'text', 'text': 'fallback'},
      ]);
      expect(migrated[2]['blocks'], [
        {'type': 'text', 'text': 'sibling'},
      ]);
      expect(
        (await DataMigrationService.getStoredPartVersions())[DataParts.chat],
        2,
      );
    },
  );
}
