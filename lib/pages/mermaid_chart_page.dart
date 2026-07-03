import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/mermaid_templates.dart';

// ============================================================================
// Editor Mode
// ============================================================================

/// Three-state editor mode for the chart page.
enum EditorMode {
  /// 纯编辑 — only code editor visible
  edit,

  /// 一边编辑一边预览 — preview on top, code on bottom
  split,

  /// 纯预览 — only preview visible (with gesture zoom)
  preview;

  String get label {
    switch (this) {
      case EditorMode.edit:
        return '编辑模式';
      case EditorMode.split:
        return '编辑+预览';
      case EditorMode.preview:
        return '预览模式';
    }
  }

  IconData get icon {
    switch (this) {
      case EditorMode.edit:
        return Icons.code;
      case EditorMode.split:
        return Icons.view_column;
      case EditorMode.preview:
        return Icons.visibility;
    }
  }
}

// ============================================================================
// MermaidChartPage
// ============================================================================

/// 图表制作页面 — 使用 Mermaid.js 制作和预览各种图表
///
/// 功能特点：
/// - 支持 13 种 Mermaid 图表类型
/// - 三态编辑模式：纯编辑、编辑+预览（预览在上）、纯预览（支持手势缩放）
/// - 上下文章节快捷片段按钮
/// - 保存为 .mmd 格式到文本储存区
class MermaidChartPage extends StatefulWidget {
  /// 可选的初始代码，用于从文本储存区打开已有 .mmd 文件
  final String? initialCode;

  /// 初始是否显示预览（WebView）。测试环境中设为 false 以避免
  /// InAppWebView 平台未初始化导致的崩溃。
  final bool initialShowPreview;

  const MermaidChartPage({
    super.key,
    this.initialCode,
    this.initialShowPreview = true,
  });

  @override
  State<MermaidChartPage> createState() => _MermaidChartPageState();
}

class _MermaidChartPageState extends State<MermaidChartPage> {
  // Editor state
  final _codeController = TextEditingController();
  String _selectedTypeId = 'flowchart';
  bool _isPreviewReady = false;
  bool _isSaving = false;
  late EditorMode _editorMode;

  // WebView controller
  InAppWebViewController? _webViewController;
  bool _webViewLoaded = false;

  // Previously rendered code (to avoid unnecessary re-renders)
  String _lastRenderedCode = '';

  @override
  void initState() {
    super.initState();
    _editorMode = widget.initialShowPreview
        ? EditorMode.split
        : EditorMode.edit;
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      _selectedTypeId = _detectTypeFromCode(widget.initialCode!);
    } else {
      _codeController.text = MermaidTemplates.getTemplate(_selectedTypeId);
    }
    _codeController.addListener(_onCodeChanged);
  }

  /// 从 Mermaid 代码中检测图表类型
  String _detectTypeFromCode(String code) {
    final firstLine = code.trimLeft().split('\n').first.trim();
    for (final type in MermaidTemplates.getAllTypes()) {
      if (firstLine.startsWith(type.keyword)) {
        return type.id;
      }
    }
    return 'flowchart';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _webViewController = null;
    super.dispose();
  }

  void _onCodeChanged() {
    _schedulePreviewUpdate();
  }

  // ---------------------------------------------------------------------------
  // Diagram type selection
  // ---------------------------------------------------------------------------

  void _selectDiagramType(String typeId) {
    final template = MermaidTemplates.getTemplate(typeId);
    setState(() {
      _selectedTypeId = typeId;
      _codeController.text = template;
    });
  }

  // ---------------------------------------------------------------------------
  // Snippet insertion
  // ---------------------------------------------------------------------------

  void _insertSnippet(String snippet) {
    final currentCode = _codeController.text;
    final insertionPoint = currentCode.lastIndexOf('\n');
    if (insertionPoint >= 0) {
      _codeController.text =
          '${currentCode.substring(0, insertionPoint)}\n$snippet\n';
    } else {
      _codeController.text = MermaidTemplates.insertSnippet(
        currentCode,
        snippet,
      );
    }
    _codeController.selection = TextSelection.fromPosition(
      TextPosition(offset: _codeController.text.length),
    );
  }

  // ---------------------------------------------------------------------------
  // Editor mode popup
  // ---------------------------------------------------------------------------

  void _showEditorModeMenu() {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<EditorMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        kToolbarHeight + MediaQuery.of(context).padding.top,
        MediaQuery.of(context).size.width - 4,
        kToolbarHeight + MediaQuery.of(context).padding.top + 140,
      ),
      items: EditorMode.values.map((mode) {
        return PopupMenuItem<EditorMode>(
          value: mode,
          child: Row(
            children: [
              Icon(mode.icon, size: 20),
              const SizedBox(width: 12),
              Text(mode.label),
              if (mode == _editorMode) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null && selected != _editorMode) {
        setState(() => _editorMode = selected);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Mermaid rendering via WebView
  // ---------------------------------------------------------------------------

  static const _mermaidHtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js">
  </script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: sans-serif;
      padding: 16px;
      background: transparent;
      display: flex;
      justify-content: center;
    }
    #container {
      max-width: 100%;
      overflow-x: auto;
    }
    .mermaid {
      text-align: center;
    }
    .error-message {
      color: #e74c3c;
      padding: 16px;
      border: 1px solid #e74c3c;
      border-radius: 8px;
      margin: 16px;
      background: #fdf0ef;
      font-family: monospace;
      white-space: pre-wrap;
    }
  </style>
</head>
<body>
  <div id="container">
    <pre class="mermaid" id="mermaid-code">
MERMAID_CODE_PLACEHOLDER
    </pre>
  </div>
  <script>
    try {
      mermaid.initialize({
        startOnLoad: true,
        theme: 'default',
        securityLevel: 'loose',
        fontFamily: 'sans-serif',
      });
    } catch(e) {
      document.getElementById('container').innerHTML =
        '<div class="error-message">Mermaid initialize error: ' + e.message + '</div>';
    }
  </script>
</body>
</html>
''';

  String _buildMermaidHtml(String mermaidCode) {
    final escaped = mermaidCode
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return _mermaidHtmlTemplate.replaceFirst(
      'MERMAID_CODE_PLACEHOLDER',
      escaped,
    );
  }

  void _updatePreview() {
    final code = _codeController.text.trim();
    if (code.isEmpty || code == _lastRenderedCode) return;
    _lastRenderedCode = code;

    if (_webViewController != null && _webViewLoaded) {
      final html = _buildMermaidHtml(code);
      _webViewController!.loadData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf8',
      );
    }
  }

  Timer? _debounceTimer;

  void _schedulePreviewUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _updatePreview();
    });
  }

  // ---------------------------------------------------------------------------
  // Save to text storage
  // ---------------------------------------------------------------------------

  Future<void> _saveChart() async {
    final content = _codeController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图表内容为空，无法保存')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final typeLabel = MermaidTemplates.getAllTypes()
          .firstWhere((t) => t.id == _selectedTypeId)
          .label;

      final bytes = Uint8List.fromList(utf8.encode(content));
      final hash = computeTextHash(bytes);
      final storageFileName = '$hash.txt';

      const baseName = '我的图表';
      final records = await TextManifest.loadRecords();
      String name = '$baseName-$typeLabel';
      int counter = 2;
      while (records.any((r) => r.name == name)) {
        name = '$baseName-$typeLabel ($counter)';
        counter++;
      }

      await TextManifest.writeText(storageFileName, content);
      await TextManifest.addRecord(TextRecord(
        name: name,
        hash: hash,
        format: 'mmd',
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: '',
        textLength: content.length,
      ));

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到文本储存区: $name.mmd'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final types = MermaidTemplates.getAllTypes();
    final snippets = MermaidTemplates.getSnippets(_selectedTypeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('图表制作'),
        actions: [
          // Three-state editor mode selector (popup menu)
          IconButton(
            icon: Icon(
              _editorMode.icon,
              size: 20,
            ),
            tooltip: '切换视图模式',
            onPressed: _showEditorModeMenu,
          ),
          // Save
          if (_isSaving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, size: 20),
              tooltip: '保存到文本储存区',
              onPressed: _saveChart,
            ),
        ],
      ),
      body: Column(
        children: [
          // ----- Diagram type selector chips -----
          Container(
            color: cs.surfaceContainerLow,
            child: SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final type = types[index];
                  final isSelected = type.id == _selectedTypeId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      avatar: Icon(type.icon, size: 16),
                      onSelected: (_) => _selectDiagramType(type.id),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ),
          ),

          // ----- Snippet buttons -----
          if (snippets.isNotEmpty)
            Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: snippets.length,
                  itemBuilder: (context, index) {
                    final (label, snippet) = snippets[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      child: ActionChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _insertSnippet(snippet),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ----- Main content -----
          Expanded(
            child: _buildMainContent(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ColorScheme cs) {
    switch (_editorMode) {
      case EditorMode.edit:
        return _buildCodeEditor(cs);
      case EditorMode.split:
        return _buildSplitView(cs);
      case EditorMode.preview:
        return _buildPreviewOnly(cs);
    }
  }

  // ---------------------------------------------------------------------------
  // Code editor only
  // ---------------------------------------------------------------------------

  Widget _buildCodeEditor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _codeController,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.all(12),
          hintText: '输入 Mermaid 代码...',
          labelText: 'Mermaid 代码',
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Split view: preview on TOP, code on BOTTOM
  // ---------------------------------------------------------------------------

  Widget _buildSplitView(ColorScheme cs) {
    return Column(
      children: [
        // Preview on TOP
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildPreviewContent(cs),
              ),
            ),
          ),
        ),

        // Divider + label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.code, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '代码',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Expanded(child: Divider(thickness: 0.5)),
            ],
          ),
        ),

        // Code editor on BOTTOM
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: TextField(
              controller: _codeController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(10),
                labelText: 'Mermaid 代码',
                isDense: true,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preview only (with gesture zoom)
  // ---------------------------------------------------------------------------

  Widget _buildPreviewOnly(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            constrained: false,
            child: _buildPreviewContent(cs),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Preview content (shared between split and preview-only modes)
  // ---------------------------------------------------------------------------

  Widget _buildPreviewContent(ColorScheme cs) {
    return _webViewLoaded
        ? InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              verticalScrollBarEnabled: false,
            ),
            onWebViewCreated: (ctrl) {
              _webViewController = ctrl;
              final html = _buildMermaidHtml(
                _codeController.text.trim(),
              );
              ctrl.loadData(
                data: html,
                mimeType: 'text/html',
                encoding: 'utf8',
              );
            },
            onLoadStop: (ctrl, url) {
              _webViewLoaded = true;
              if (mounted) setState(() => _isPreviewReady = true);
            },
          )
        : Stack(
            children: [
              // Dummy WebView that will load when visible
              if (!_webViewLoaded)
                Opacity(
                  opacity: 0,
                  child: InAppWebView(
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      transparentBackground: true,
                    ),
                    onWebViewCreated: (ctrl) {
                      _webViewController = ctrl;
                      final html = _buildMermaidHtml(
                        _codeController.text.trim(),
                      );
                      ctrl.loadData(
                        data: html,
                        mimeType: 'text/html',
                        encoding: 'utf8',
                      );
                    },
                    onLoadStop: (ctrl, url) {
                      _webViewLoaded = true;
                      if (mounted) {
                        setState(() => _isPreviewReady = true);
                      }
                    },
                  ),
                ),
              // Loading indicator
              if (!_isPreviewReady)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '加载渲染引擎...',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
  }
}
