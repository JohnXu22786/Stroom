import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/mermaid_templates.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

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

/// The height ratio of the split editor relative to the available space.
/// Set to 0.5 for a 50/50 split between preview and editor.
const double _splitEditorHeightRatio = 0.5;

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
  bool _isSaving = false;
  late EditorMode _editorMode;

  /// Whether the left/right panels in landscape split mode are swapped.
  bool _isLandscapeSwapped = false;

  // Debounced preview code — passed to MermaidRenderWidget so the WebView
  // is only updated after the user stops typing (debounce in _onCodeChanged).
  String _previewCode = '';

  @override
  void initState() {
    super.initState();
    _editorMode =
        widget.initialShowPreview ? EditorMode.split : EditorMode.edit;
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      _selectedTypeId = _detectTypeFromCode(widget.initialCode!);
    } else {
      _codeController.text = MermaidTemplates.getTemplate(_selectedTypeId);
    }
    _previewCode = _codeController.text.trim();
    _codeController.addListener(_onCodeChanged);
  }

  /// 从 Mermaid 代码中检测图表类型
  ///
  /// 跳过 %% 注释行和 %%{init} 配置指令以找到真正的图表类型声明。
  String _detectTypeFromCode(String code) {
    final lines = code.trimLeft().split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      // Skip %% comment lines and %%{init} directive lines
      if (line.isEmpty || line.startsWith('%%')) continue;
      for (final type in MermaidTemplates.getAllTypes()) {
        if (line.startsWith(type.keyword)) {
          return type.id;
        }
      }
      // Found a non-comment line that doesn't match any known type → stop
      break;
    }
    return 'flowchart';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    _schedulePreviewUpdate();
  }

  Timer? _debounceTimer;

  /// Debounces preview updates so that the [MermaidRenderWidget] is not
  /// rebuilt on every keystroke. After 800ms of inactivity, [setState] is
  /// called with the latest code so [MermaidRenderWidget.didUpdateWidget]
  /// triggers a reload inside the WebView.
  void _schedulePreviewUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _previewCode = _codeController.text.trim();
        });
      }
    });
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
        setState(() {
          _editorMode = selected;
        });
      }
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

    // Show save dialog with filename input and folder picker
    final folders = await TextManifest.getAllFolders();
    if (!mounted) return;

    // Local controller - will be garbage collected after _saveChart completes.
    // Not explicitly disposed because the dialog's dismiss animation still
    // references it after showDialog returns.
    final fileNameController = TextEditingController(text: '我的图表');
    final selectedFolder = await FolderPickerDialog.show(
      context,
      availableFolders: folders,
      title: '保存图表',
      hintText: '选择或创建文件夹保存 .mmd 图表文件',
      fileNameController: fileNameController,
      fileNameHintText: '输入文件名（自动添加 .mmd 后缀）',
      onCreateFolder: (name) async {
        await TextManifest.addFolder(name);
        return null;
      },
      onRefreshFolders: () async => TextManifest.getAllFolders(),
    );

    final userFileName = fileNameController.text.trim();

    if (selectedFolder == null || !mounted) return;

    if (userFileName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件名不能为空')),
        );
      }
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

      // Use user-provided filename (without extension for storage consistency)
      final baseName = userFileName;
      final saveName = '$baseName-$typeLabel';
      final records = await TextManifest.loadRecords();
      String finalName = saveName;
      int counter = 2;
      while (records.any((r) => r.name == finalName)) {
        finalName = '$saveName ($counter)';
        counter++;
      }

      await TextManifest.writeText(storageFileName, content);
      await TextManifest.addRecord(TextRecord(
        name: finalName,
        hash: hash,
        format: 'mmd',
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: selectedFolder,
        textLength: content.length,
      ));

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '已保存到文本储存区: ${selectedFolder.isEmpty ? "根目录" : selectedFolder}/$finalName.mmd'),
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
          // ----- Diagram type selector chips (hidden when opening .mmd file) -----
          if (widget.initialCode == null)
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
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
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

  // ---------------------------------------------------------------------------
  // Main content — no overlap between preview and editor
  // ---------------------------------------------------------------------------

  Widget _buildMainContent(ColorScheme cs) {
    final bool showPreview = _editorMode != EditorMode.edit;
    final bool isSplitMode = _editorMode == EditorMode.split;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final isLandscape = availableWidth > availableHeight;

        // Horizontal split layout for landscape split mode
        if (isSplitMode && isLandscape) {
          final leftPanel = _isLandscapeSwapped
              ? _buildSplitEditorPart(cs)
              : _buildPreviewPanel(cs);
          final rightPanel = _isLandscapeSwapped
              ? _buildPreviewPanel(cs)
              : _buildSplitEditorPart(cs);

          return Row(
            children: [
              Expanded(child: leftPanel),
              // Swap button in the middle — centered vertically
              SizedBox(
                width: 28,
                child: Center(
                  child: _buildSwapButton(cs),
                ),
              ),
              Expanded(child: rightPanel),
            ],
          );
        }

        // Vertical layout for portrait split mode, edit mode, or preview mode
        final editorHeight = isSplitMode
            ? availableHeight * _splitEditorHeightRatio
            : 0.0;

        return Stack(
          children: [
            // Preview — uses MermaidRenderWidget which defers WebView creation
            // via postFrameCallback to avoid freezing the UI (same pattern as
            // the chat page's inline Mermaid rendering).
            if (showPreview)
              Positioned.fill(
                // In split mode, leave bottom space for the code editor
                bottom: editorHeight,
                child: _buildPreviewPanel(cs),
              ),
            // Editor overlay for edit mode (full area)
            if (_editorMode == EditorMode.edit)
              Positioned.fill(
                child: _buildCodeEditor(cs),
              ),
            // Editor overlay for split mode (bottom portion, no overlap)
            if (isSplitMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: editorHeight,
                child: _buildSplitEditorPart(cs),
              ),
          ],
        );
      },
    );
  }

  /// Preview panel that uses [MermaidRenderWidget] — the same widget used
  /// by the chat page for inline Mermaid rendering. This avoids creating
  /// an [InAppWebView] directly in the chart page's widget tree, which was
  /// causing the entire application to freeze when the platform view
  /// (WebView2 on Windows) was created synchronously.
  ///
  /// [MermaidRenderWidget] handles deferred WebView creation, loading
  /// states, error reporting, zoom controls, source code toggle, and
  /// fullscreen — all without blocking the UI thread.
  Widget _buildPreviewPanel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: MermaidRenderWidget(
        mermaidCode: _previewCode,
        expand: true,
        showToolbar: false,
        showZoomControls: true,
      ),
    );
  }

  /// Builds the swap button that appears between the two panels in
  /// landscape split mode. Tapping it exchanges the left/right positions
  /// of the preview and code editor panels.
  Widget _buildSwapButton(ColorScheme cs) {
    return Tooltip(
      message: '交换预览和编辑面板',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _isLandscapeSwapped = !_isLandscapeSwapped;
            });
          },
          child: Container(
            width: 28,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.swap_horiz,
              size: 18,
              color: cs.onSurfaceVariant,
              semanticLabel: '交换预览和编辑面板',
            ),
          ),
        ),
      ),
    );
  }

  /// Editor-only part of the split view (no InAppWebView preview).
  /// The height is constrained by the parent [Positioned] widget so this
  /// widget does not set its own fixed height.
  Widget _buildSplitEditorPart(ColorScheme cs) {
    return Column(
      children: [
        // Divider + label
        Container(
          color: cs.surfaceContainerLow,
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
        // Code editor
        Expanded(
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
  // Preview — delegated to MermaidRenderWidget (see _buildPreviewPanel above)
  // ---------------------------------------------------------------------------
}
