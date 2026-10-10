import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chat v2 migrates plain replies and repairs empty reasoning rounds once',
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
            'compactedAt': '2026-10-01T00:00:00.000Z'
          },
          {
            'id': 't2',
            'name': 'search',
            'arguments': {},
            'status': 'completed',
            'result': '找到'
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
          {'type': 'error', 'message': '错误'}
        ]
      },
      {'id': 'user', 'role': 'user', 'content': '问题'},
      {
        'id': 'failed',
        'role': 'assistant',
        'isError': true,
        'content': '错误: 连接中断\n\n---\n部分回复',
        'blocks': [
          {'type': 'text', 'text': '部分回复'}
        ]
      },
    ];
    SharedPreferences.setMockInitialValues({
      'data_format_versions':
          jsonEncode({...DataParts.currentVersions, DataParts.chat: 1}),
      'conversations': jsonEncode([
        {'id': 'c1', 'messages': messages}
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
      'text'
    ]);
    expect(blocks[3]['text'], '');
    expect(blocks[2]['compactedAt'], '2026-10-01T00:00:00.000Z');
    expect(migrated[1]['rawResponse'], '保留');
    expect(migrated[2]['blocks'], messages[2]['blocks']);
    expect(migrated[3], messages[3]);
    expect(migrated[4]['blocks'], [
      {'type': 'text', 'text': '错误: 连接中断'},
      {'type': 'text', 'text': '部分回复'},
    ]);
    expect((await DataMigrationService.getStoredPartVersions())[DataParts.chat],
        2);
    await DataMigrationService.migrateDataFormatIfNeeded();
    expect(prefs.getString('conversations'), saved);
  });
  test(
      'chat v2 ignores malformed optional fields without blocking valid siblings',
      () async {
    final messages = [
      {
        'role': 'assistant',
        'content': 'canonical',
        'reasoningSections': 'bad',
        'blocks': [
          {'type': 'text', 'text': 'canonical'}
        ]
      },
      {
        'role': 'assistant',
        'content': 'fallback',
        'reasoningSections': ['idea', 7],
        'textSections': false,
        'toolCalls': 'bad',
        'toolCallRoundStarts': [0, 'bad']
      },
      {'role': 'assistant', 'content': 'sibling'},
    ];
    SharedPreferences.setMockInitialValues({
      'data_format_versions':
          jsonEncode({...DataParts.currentVersions, DataParts.chat: 1}),
      'conversations': jsonEncode([
        {'id': 'c', 'messages': messages}
      ]),
    });
    await DataMigrationService.migrateDataFormatIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('conversations')!) as List;
    final migrated = saved.single['messages'] as List;
    expect(migrated[0], messages[0]);
    expect(migrated[1]['blocks'], [
      {'type': 'reasoning', 'text': 'idea', 'isComplete': true},
      {'type': 'text', 'text': 'fallback'}
    ]);
    expect(migrated[2]['blocks'], [
      {'type': 'text', 'text': 'sibling'}
    ]);
    expect((await DataMigrationService.getStoredPartVersions())[DataParts.chat],
        2);
  });
}
