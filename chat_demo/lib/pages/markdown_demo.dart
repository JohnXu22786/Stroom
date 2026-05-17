import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/dracula.dart';

class MarkdownDemoPage extends StatefulWidget {
  const MarkdownDemoPage({super.key});

  @override
  State<MarkdownDemoPage> createState() => _MarkdownDemoPageState();
}

class _MarkdownDemoPageState extends State<MarkdownDemoPage> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final isDark = _dark || Theme.of(context).brightness == Brightness.dark;
    final config = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

    return Column(
      children: [
        SwitchListTile(
          title: const Text('暗黑模式'),
          value: _dark,
          onChanged: (v) => setState(() => _dark = v),
        ),
        Expanded(
          child: MarkdownWidget(
            data: _markdownContent,
            selectable: true,
            padding: const EdgeInsets.all(16),
            config: config.copy(configs: [
              PreConfig(theme: isDark ? draculaTheme : a11yLightTheme),
            ]),
          ),
        ),
      ],
    );
  }
}

const _markdownContent = '''
# 标题 H1

## 标题 H2

### 标题 H3

这是一段**加粗**文字，一段*斜体*文字，一段 ~~删除线~~ 文字，一段 `行内代码`。

> 这是一段引用文本
> 多行引用

---

### 列表

1. 有序列表项一
2. 有序列表项二
   - 嵌套无序列表
   - 嵌套无序列表
3. 有序列表项三

### 代码块

```dart
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text('Hello, markdown_widget!'),
    );
  }
}
```

```python
def fibonacci(n: int) -> list[int]:
    fib = [0, 1]
    for i in range(2, n):
        fib.append(fib[i-1] + fib[i-2])
    return fib

print(fibonacci(10))
```

### 表格

| 特性 | markdown_widget | flutter_chat_ui |
|------|----------------|-----------------|
| 代码高亮 | 支持 | 需自定义 |
| 流式文本 | 不支持 | 原生支持 |
| 暗黑模式 | 内置 | 可配置 |

### 链接

[访问 Flutter 官网](https://flutter.dev)

> **提示：** markdown_widget 支持 `selectable: true`，用户可以长按选择文本。
''';
