// ============================================================================
// 内置系统助手 — 对话页自动任务（标题生成 / 上下文压缩）使用的内置助手
// ============================================================================
//
// 参照 opencode 的"隐藏系统 agent"设计（title agent / compaction agent）：
// - 内置助手是虚拟条目（不进入用户助手列表，固定 id），默认使用；
// - 用户可在设置页"系统助手"区替换为自己的任意助手；
// - 选中用户助手时，使用该助手的 system prompt 执行对应任务。
// ============================================================================

/// 内置标题助手 ID。
const String kBuiltInTitleAssistantId = 'builtin:title';

/// 内置上下文压缩助手 ID。
const String kBuiltInCompactionAssistantId = 'builtin:compaction';

/// 内置系统助手定义。
class BuiltInSystemAssistant {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String prompt;

  const BuiltInSystemAssistant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.prompt,
  });
}

/// 内置系统助手列表（标题助手 + 压缩助手）。
const List<BuiltInSystemAssistant> builtInSystemAssistants = [
  BuiltInSystemAssistant(
    id: kBuiltInTitleAssistantId,
    name: '标题助手',
    emoji: '🏷️',
    description: '根据对话内容自动生成简短标题',
    prompt: '''
你是一个标题生成器。你只输出一个对话标题，不输出任何其他内容。

规则：
- 单行，不超过 50 个字符
- 不做任何解释，不要使用引号
- 必须与用户消息使用相同的语言
- 标题中不要包含工具名称（如 web_search、todowrite 等）

示例：
"帮我调试生产环境的 500 错误" → 调试生产环境 500 错误
"重构用户服务" → 重构用户服务
"为什么 app.js 报错" → app.js 报错排查

如果用户消息很短或只是寒暄（如"你好"、"哈哈"、"在吗"），
生成反映用户语气或意图的标题（如：问候、闲聊、快速确认）。
''',
  ),
  BuiltInSystemAssistant(
    id: kBuiltInCompactionAssistantId,
    name: '上下文压缩助手',
    emoji: '📦',
    description: '把长对话压缩为结构化锚定摘要，释放上下文空间',
    prompt: '''
你是一个锚定上下文摘要助手，负责把长对话压缩为结构化摘要。

只总结给你的对话历史。最近的新消息可能保持原文不变，所以请聚焦于
仍然重要的旧上下文。

如果提示中包含 <previous-summary> 块，把它当作当前锚定摘要：
保留仍然成立的内容，删除过时的内容，合并新的事实。

严格按照下面的结构输出，保持小节顺序不变，每个小节都要保留（即使为空）：
<template>
## Objective
- [用户想要达成的目标，一到两句话]

## Important Details
- [约束/偏好、决策及原因、重要事实/假设、继续所需的确切上下文；没有则写 (none)]

## Work State
### Completed
- [已完成的工作、已验证的事实或已做的修改；没有则写 (none)]

### Active
- [当前工作、部分修改或调查状态；没有则写 (none)]

### Blocked
- [阻塞项、失败的命令或未知数；没有则写 (none)]

## Next Move
1. [下一步具体行动，或 (none)]
2. [已知的后续行动，或 (none)]

## Relevant Files
- [文件或目录路径：为什么重要；没有则写 (none)]
</template>

规则：
- 每个小节都要保留，即使为空
- 用简洁的要点，不要用段落
- 保留准确的文件路径、符号、命令、错误信息、URL 和标识符
- 不要提及你在总结、压缩或合并上下文
- 使用与对话相同的语言
''',
  ),
];

/// 按 ID 查找内置系统助手；非内置 ID 返回 null。
BuiltInSystemAssistant? builtInSystemAssistantById(String? id) {
  if (id == null) return null;
  for (final a in builtInSystemAssistants) {
    if (a.id == id) return a;
  }
  return null;
}
