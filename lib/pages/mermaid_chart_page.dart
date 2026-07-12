import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/mermaid_templates.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

/// Builds a complete HTML document with mermaid.js that renders the
/// given [mermaidCode] as a diagram.
///
/// Delegates to [MermaidRenderWidget.buildMermaidHtml] which is the
/// single source of truth for the HTML/JS template.
String _buildMermaidHtml(String mermaidCode) {
  return MermaidRenderWidget.buildMermaidHtml(mermaidCode);
}

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
const double _splitEditorHeightRatio = 0.45;

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

  // Deferred WebView creation guards (see _schedulePreviewWebViewCreation)
  bool _previewWebViewScheduled = false;
  bool _previewWebViewReady = false;

  // Timer for delayed WebView creation to ensure page transition completes
  Timer? _webViewCreationTimer;

  // Mermaid render error state (set via JavaScript error handler)
  String? _previewErrorMessage;

  // Previously rendered code (to avoid unnecessary re-renders)
  String _lastRenderedCode = '';

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
    _codeController.addListener(_onCodeChanged);

    // Defer WebView creation to after the first frame so that the
    // page transition animation is not blocked by platform view creation.
    if (widget.initialShowPreview) {
      _schedulePreviewWebViewCreation();
    }
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
    _webViewCreationTimer?.cancel();
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
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

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
          // Schedule WebView creation when entering split or preview mode
          if ((selected == EditorMode.split ||
                  selected == EditorMode.preview) &&
              !_previewWebViewScheduled) {
            _schedulePreviewWebViewCreation();
          }
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Mermaid rendering via WebView
  // ---------------------------------------------------------------------------

  /// Schedules the WebView to be created after the page transition animation
  /// completes, to avoid blocking the UI with platform view creation.
  ///
  /// Uses a two-phase approach:
  /// 1. After the first frame (postFrameCallback), the loading placeholder is shown
  /// 2. After a 300ms delay, the WebView is actually created
  ///
  /// This ensures the page transition animation completes smoothly before the
  /// heavyweight platform view (WebView2 on Windows, WKWebView on iOS, etc.)
  /// is created on the main thread.
  void _schedulePreviewWebViewCreation() {
    if (_previewWebViewScheduled) return;
    _previewWebViewScheduled = true;

    // Phase 1: After the first frame, show the loading placeholder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Phase 2: After 300ms (page transition completes), create the WebView
      _webViewCreationTimer = Timer(
        const Duration(milliseconds: 300),
        () {
          _webViewCreationTimer = null;
          if (mounted) {
            setState(() => _previewWebViewReady = true);
          }
        },
      );
    });
  }

  void _updatePreview() {
    final code = _codeController.text.trim();
    if (code.isEmpty || code == _lastRenderedCode) return;
    _lastRenderedCode = code;

    // Clear any previous error so the loading overlay reappears
    if (_previewErrorMessage != null) {
      _previewErrorMessage = null;
      _isPreviewReady = false;
      if (mounted) setState(() {});
    }

    if (_webViewController != null && _webViewLoaded) {
      final html = _buildMermaidHtml(code);
      _webViewController!.loadData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf8',
      );
    }
  }

  void _retryPreview() {
    setState(() {
      _previewErrorMessage = null;
      _isPreviewReady = false;
    });
    // Reload the current code into the WebView
    final code = _codeController.text.trim();
    if (code.isNotEmpty && _webViewController != null) {
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

    // Show folder picker dialog first (same style as catcatch/get-web-resource)
    final folders = await TextManifest.getAllFolders();
    if (!mounted) return;

    final selectedFolder = await FolderPickerDialog.show(
      context,
      availableFolders: folders,
      title: '选择保存文件夹',
      hintText: '选择或创建文件夹保存 .mmd 图表文件',
      onCreateFolder: (name) async {
        await TextManifest.addFolder(name);
        return null;
      },
      onRefreshFolders: () async => TextManifest.getAllFolders(),
    );

    if (selectedFolder == null || !mounted) return;

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
        folder: selectedFolder,
        textLength: content.length,
      ));

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '已保存到文本储存区: ${selectedFolder.isEmpty ? "根目录" : selectedFolder}/$name.mmd'),
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

    return Stack(
      children: [
        // Preview — once the WebView is ready, keep it alive in the widget
        // tree (even across mode switches) to avoid recreation freezes.
        if (_previewWebViewReady)
          Positioned.fill(
            // In split mode, leave bottom space for the code editor
            bottom: _editorMode == EditorMode.split
                ? MediaQuery.of(context).size.height * _splitEditorHeightRatio
                : 0,
            child: _buildPreviewPanel(cs),
          ),
        // Loading placeholder — shown when the user enters split or preview
        // mode but the WebView has not yet been created (deferred creation).
        if (!_previewWebViewReady && showPreview)
          Positioned.fill(
            bottom: _editorMode == EditorMode.split
                ? MediaQuery.of(context).size.height * _splitEditorHeightRatio
                : 0,
            child: _buildPreviewPlaceholder(cs),
          ),
        // Editor overlay for edit mode (full area)
        if (_editorMode == EditorMode.edit)
          Positioned.fill(
            child: _buildCodeEditor(cs),
          ),
        // Editor overlay for split mode (bottom portion, no overlap)
        if (_editorMode == EditorMode.split)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height:
                MediaQuery.of(context).size.height * _splitEditorHeightRatio,
            child: _buildSplitEditorPart(cs),
          ),
      ],
    );
  }

  /// Preview panel that wraps [InAppWebView] in a consistent widget tree.
  /// In preview mode, [InteractiveViewer] pan/scale is enabled for zoom/pan.
  /// In split mode, the InteractiveViewer is still present but interaction
  /// is disabled, keeping the widget tree depth constant so the platform
  /// view is never recreated on mode switch.
  Widget _buildPreviewPanel(ColorScheme cs) {
    final isPreviewMode = _editorMode == EditorMode.preview;

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
            // Disable pan/scale in split mode so the WebView receives
            // touch events normally; enable only in full preview mode.
            panEnabled: isPreviewMode,
            scaleEnabled: isPreviewMode,
            child: _buildPreviewContent(cs),
          ),
        ),
      ),
    );
  }

  /// Editor-only part of the split view (no InAppWebView preview).
  Widget _buildSplitEditorPart(ColorScheme cs) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * _splitEditorHeightRatio,
      child: Column(
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
      ),
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
  // Preview content (shared between split and preview-only modes)
  // ---------------------------------------------------------------------------

  Widget _buildPreviewContent(ColorScheme cs) {
    // The WebView is always kept alive in the widget tree once created.
    // Errors and loading states are overlaid on top so the platform view
    // (WebView2) is never destroyed by removing it from the tree.
    final showLoading = !_isPreviewReady && _previewErrorMessage == null;

    return Stack(
      children: [
        // RepaintBoundary isolates the WebView's rendering layer so that
        // the platform view (WebView2 on Windows, WKWebView on iOS, etc.)
        // does not force relayouts or repaints in the rest of the widget tree.
        RepaintBoundary(
          child: InAppWebView(
            key: const Key('mermaid_webview'),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              verticalScrollBarEnabled: false,
            ),
            onWebViewCreated: (ctrl) {
              _webViewController = ctrl;
              // Set up JavaScript handler to receive mermaid errors
              ctrl.addJavaScriptHandler(
                handlerName: 'onMermaidError',
                callback: (args) {
                  if (mounted) {
                    final msg = args.isNotEmpty ? args[0].toString() : '未知错误';
                    setState(() => _previewErrorMessage = msg);
                  }
                },
              );
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
              // Only set state once to prevent infinite build → recreate → load loop
              if (!_isPreviewReady) {
                _webViewLoaded = true;
                if (mounted) setState(() => _isPreviewReady = true);
              }
            },
            onLoadError: (ctrl, url, code, message) {
              if (mounted && !_isPreviewReady) {
                setState(() {
                  _isPreviewReady = true;
                  _previewErrorMessage = '页面加载失败: $message';
                });
              }
            },
          ),
        ),
        // Loading overlay — shown until the WebView first finishes loading
        if (showLoading)
          Positioned.fill(
            child: Container(
              color: cs.surface,
              child: Center(
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
            ),
          ),
        // Error overlay — shown on top of the WebView when mermaid fails.
        // The WebView remains in the tree so the controller stays valid
        // for retry.
        if (_previewErrorMessage != null)
          Positioned.fill(
            child: Container(
              color: cs.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 32, color: cs.error),
                      const SizedBox(height: 8),
                      Text(
                        '渲染图表时出错',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _previewErrorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _retryPreview,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Placeholder shown while the WebView is being created (deferred).
  Widget _buildPreviewPlaceholder(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '正在准备渲染引擎...',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
