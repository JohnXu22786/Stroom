import 'package:flutter/material.dart';

import '../../widgets/constrained_text.dart';

/// Reference panel for the exact Stroom-owned remote assistant schema.
void showAssistantSchemaInfoDialog(
  BuildContext context, {
  Set<String> supportedToolNames = const {},
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _AssistantSchemaInfoDialog(supportedToolNames: supportedToolNames),
  );
}

class _AssistantSchemaInfoDialog extends StatelessWidget {
  final Set<String> supportedToolNames;

  const _AssistantSchemaInfoDialog({required this.supportedToolNames});

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final colorScheme = Theme.of(context).colorScheme;
    final groups = <_InfoGroup>[
      _InfoGroup(isZh ? '目录清单字段' : 'Catalog manifest fields', [
        _InfoRow(
          'schemaVersion',
          '1',
          isZh ? '目录 schema 版本。' : 'Catalog schema version.',
        ),
        _InfoRow(
          'catalogId',
          '非空字符串',
          isZh ? '目录来源的稳定 ID。' : 'Stable identifier for this catalog.',
        ),
        _InfoRow(
          'updatedAt',
          'ISO 8601 字符串，可省略',
          isZh ? '目录生成时间。' : 'Catalog generation timestamp.',
        ),
        _InfoRow(
          'extensions',
          '对象，可省略',
          isZh
              ? '供未来 Stroom 扩展保留；当前不会执行。'
              : 'Reserved for future Stroom extensions; not executed today.',
        ),
        _InfoRow(
          'assistants',
          '对象列表',
          isZh ? '每项包含助手摘要、版本、文件路径、格式和 SHA-256。' : 'Entries include summary, version, file path, format, and SHA-256.',
        ),
        _InfoRow(
          'file',
          '同源相对路径',
          isZh ? '目录中的助手文件位置。' : 'Assistant file path relative to the catalog.',
        ),
        _InfoRow(
          'format',
          'stroom-json-v1 / stroom-yaml-v1 / stroom-markdown-yaml-v1',
          isZh
              ? '声明助手文件的 Stroom 格式。'
              : 'Declares the Stroom assistant file format.',
        ),
        _InfoRow(
          'sha256',
          '64 位十六进制字符串',
          isZh
              ? '校验下载文件是否与目录清单一致。'
              : 'Verifies the downloaded file matches the manifest.',
        ),
        _InfoRow(
          'requiresCapabilities',
          '字符串列表，可省略',
          isZh
              ? '仅支持 stroom.assistant.v1、stroom.settings.v1、stroom.defaultTools.v1；未知能力会拒绝导入。'
              : 'Supported values: stroom.assistant.v1, stroom.settings.v1, stroom.defaultTools.v1; unknown capabilities are rejected.',
        ),
      ]),
      _InfoGroup(isZh ? '助手信息' : 'Assistant fields', [
        _InfoRow(
          'schemaVersion',
          '1',
          isZh ? '当前支持的 schema 版本。' : 'Supported schema version.',
        ),
        _InfoRow(
          'id',
          '非空字符串',
          isZh
              ? '目录内稳定唯一，用于识别后续更新。'
              : 'Stable unique catalog ID used to match updates.',
        ),
        _InfoRow(
          'name',
          '非空字符串',
          isZh ? '助手显示名称，最多 120 个字符。' : 'Display name, up to 120 characters.',
        ),
        _InfoRow(
          'description',
          '字符串，可省略',
          isZh ? '列表中的说明文字。' : 'Short description shown in the market.',
        ),
        _InfoRow(
          'emoji',
          '字符串，可省略',
          isZh ? '助手图标，默认 🤖。' : 'Assistant icon; defaults to 🤖.',
        ),
        _InfoRow(
          'version',
          '非空字符串',
          isZh ? '目录和文件中的版本必须一致。' : 'Must match the version in the catalog.',
        ),
        _InfoRow(
          'prompt',
          '非空字符串',
          isZh
              ? '助手系统提示词；Markdown 格式中使用前置区后的正文。'
              : 'System prompt; in Markdown, use the body after front matter.',
        ),
        _InfoRow(
          'settings',
          '对象，可省略',
          isZh
              ? '下面列出的参数必须使用这些固定名称。'
              : 'Optional object containing the exact parameter names below.',
        ),
      ]),
      _InfoGroup(isZh ? 'settings 参数' : 'settings parameters', [
        _InfoRow(
          'temperature / enableTemperature',
          '0–2 / bool',
          isZh ? '温度值和启用开关。' : 'Temperature and its enable toggle.',
        ),
        _InfoRow(
          'topP / enableTopP',
          '0–1 / bool',
          isZh ? 'Top P 值和启用开关。' : 'Top P and its enable toggle.',
        ),
        _InfoRow(
          'maxTokens / enableMaxTokens',
          '256–32768 / bool',
          isZh
              ? '最大输出 Token 数和启用开关。'
              : 'Maximum output tokens and its enable toggle.',
        ),
        _InfoRow(
          'maxToolCalls / enableMaxToolCalls',
          '正整数 / bool',
          isZh ? '最大工具调用轮数；UI 接受任意正整数，运行时最多按 100 轮执行；关闭开关表示不限。' : 'Tool-call rounds; the UI accepts any positive integer and runtime execution is capped at 100 rounds; disabled means unlimited.',
        ),
        _InfoRow(
          'streamOutput',
          'bool',
          isZh ? '是否流式输出。' : 'Whether to stream output.',
        ),
        _InfoRow(
          'frequencyPenalty / enableFrequencyPenalty',
          '-2–2 / bool',
          isZh ? '频率惩罚值和启用开关。' : 'Frequency penalty and its enable toggle.',
        ),
        _InfoRow(
          'presencePenalty / enablePresencePenalty',
          '-2–2 / bool',
          isZh ? '存在惩罚值和启用开关。' : 'Presence penalty and its enable toggle.',
        ),
        _InfoRow(
          'seed / enableSeed',
          '整数 / bool',
          isZh ? '随机种子和启用开关。' : 'Integer seed and its enable toggle.',
        ),
        _InfoRow(
          'enableWebSearch',
          'bool',
          isZh ? '网页搜索开关。' : 'Web search toggle.',
        ),
        _InfoRow(
          'maxToolOutputChars / enableMaxToolOutputChars',
          '100–100000 字符 / bool',
          isZh
              ? '工具结果截断长度和启用开关。'
              : 'Tool-result truncation length and its enable toggle.',
        ),
        _InfoRow(
          'customParameters',
          'name / type / value',
          isZh
              ? '类型可选 string、number、boolean、json；name 可用点号分层，不能有空段或分段首尾空格；value 须符合 type。'
              : 'Types: string, number, boolean, json; names may use dotted paths without empty segments or surrounding segment whitespace; value must match type.',
        ),
      ]),
      _InfoGroup(isZh ? '默认设置' : 'Defaults', [
        _InfoRow(
          'defaultModelName',
          '当前设备已配置的模型',
          isZh ? '值必须匹配本机模型；不匹配时接入后不设默认模型。' : 'Must match a model configured on this device; otherwise no default model is applied.',
        ),
        _InfoRow(
          'defaultModelId / defaultProviderName',
          '字符串',
          isZh ? '模型 ID 与供应商名应对应本机配置，用于稳定识别。' : 'Should identify a model and provider configured on this device.',
        ),
        _InfoRow(
          'defaultToolNames',
          supportedToolNames.isEmpty
              ? '字符串列表（当前未发现可用工具）'
              : (supportedToolNames.toList()..sort()).join(', '),
          isZh ? '每项必须是当前设备可用的 Stroom 工具名；空列表表示全部关闭；省略表示保留应用默认行为。' : 'Each value must be a Stroom tool available on this device; an empty list disables all tools, while omission keeps app defaults.',
        ),
        _InfoRow(
          'extensions',
          '对象，可省略',
          isZh
              ? '保留可选扩展数据；未支持的扩展不会启用。'
              : 'Optional extension data is preserved but not activated.',
        ),
      ]),
    ];

    return AlertDialog(
      title: ConstrainedText(
        isZh ? '远程助手参数说明' : 'Remote assistant schema',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 620,
        height: 560,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                isZh
                    ? '助手文件支持 JSON、YAML 和 Markdown；目录清单支持 JSON 或 YAML。所有格式使用同一组 Stroom 字段名和参数类型，不接受其他字段别名。'
                    : 'Assistant files support JSON, YAML, and Markdown; catalogs support JSON or YAML. Every encoding uses the same Stroom field names and types, with no aliases.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final row in group.rows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row.name,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  subtitle: Text('${row.value} · ${row.description}'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: ConstrainedText(
            isZh ? '关闭' : 'Close',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoGroup {
  final String title;
  final List<_InfoRow> rows;

  const _InfoGroup(this.title, this.rows);
}

class _InfoRow {
  final String name;
  final String value;
  final String description;

  const _InfoRow(this.name, this.value, this.description);
}
