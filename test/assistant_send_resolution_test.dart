// 发送时助手解析的回归测试：对话绑定的助手必须生效，绝不静默退化为
// "无提示词"请求。
//
// 背景：聊天发送路径此前只读会话级选择（selectedAssistantProvider），
// 而全局搜索/直达入口可能打开一个绑定到其它助手的对话——此时发送仍用
// 会话选择的提示词；会话选择为空（如助手被删除）时更是直接不发任何
// 系统提示词。修复后按 对话绑定 → 会话选择 → 默认助手 解析。

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/assistant_provider.dart';

void main() {
  Assistant makeAssistant(String id, {String? prompt}) => Assistant(
        id: id,
        name: '助手$id',
        prompt: prompt ?? '提示词-$id',
        emoji: '🤖',
      );

  group('resolveAssistantForSend', () {
    test('对话绑定的助手优先于会话选择（核心回归）', () {
      final bound = makeAssistant('a-bound', prompt: '翻译助手提示词');
      final session = makeAssistant('a-session', prompt: '会话提示词');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: bound.id,
        sessionAssistant: session,
        assistants: [bound, session],
      );

      expect(resolved, same(bound),
          reason: '通过全局搜索打开其它助手的对话后，发送必须用对话绑定的'
              '助手提示词，而不是会话里另一个助手');
    });

    test('对话绑定存在且会话选择为空时仍使用绑定助手（不再无提示词）', () {
      final bound = makeAssistant('a-bound');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: bound.id,
        sessionAssistant: null,
        assistants: [bound],
      );

      expect(resolved, same(bound));
    });

    test('绑定助手已删除且会话选择为空 → 兜底默认助手，而非 null', () {
      final first = makeAssistant('a-first', prompt: '默认提示词');
      final other = makeAssistant('a-other');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: 'deleted-assistant-id',
        sessionAssistant: null,
        assistants: [first, other],
      );

      expect(resolved, same(first),
          reason: '绑定失效且无会话选择时兜底列表第一个助手，'
              '避免静默发出无系统提示词的请求');
    });

    test('绑定助手已删除但会话选择有效 → 回退到会话选择', () {
      final session = makeAssistant('a-session');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: 'deleted-assistant-id',
        sessionAssistant: session,
        assistants: [session],
      );

      expect(resolved, same(session));
    });

    test('对话未绑定助手（旧数据）→ 跟随会话选择（保留原有语义）', () {
      final session = makeAssistant('a-session');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: null,
        sessionAssistant: session,
        assistants: [session],
      );

      expect(resolved, same(session));
    });

    test('对话未绑定且会话选择为空 → 默认（列表第一个）助手', () {
      final first = makeAssistant('a-first');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: null,
        sessionAssistant: null,
        assistants: [first],
      );

      expect(resolved, same(first));
    });

    test('空 assistantId 视为未绑定', () {
      final session = makeAssistant('a-session');

      final resolved = resolveAssistantForSend(
        conversationAssistantId: '',
        sessionAssistant: session,
        assistants: [session],
      );

      expect(resolved, same(session));
    });

    test('助手列表为空（防御性）→ null，保持调用方原行为', () {
      final resolved = resolveAssistantForSend(
        conversationAssistantId: 'whatever',
        sessionAssistant: null,
        assistants: const [],
      );

      expect(resolved, isNull);
    });
  });
}
