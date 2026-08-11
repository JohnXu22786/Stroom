import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';

// ============================================================================
// LabeledTextField — label + description + text field.
// When [suggestions] is provided, focusing / tapping the field pops up an
// overlay list of suggested values below it. The user can tap a suggestion
// or keep typing freely — the popup never takes focus or blocks input.
// ============================================================================

class LabeledTextField extends StatefulWidget {
  final String label;
  final String? description;
  final TextEditingController controller;
  final String? hintText;
  final bool required;
  final TextInputType keyboardType;
  final int? maxLines;
  final List<String>? suggestions;

  const LabeledTextField({
    super.key,
    required this.label,
    this.description,
    required this.controller,
    this.hintText,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLines,
    this.suggestions,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField>
    with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _popupKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  /// 弹出时显示全部备选值；用户开始输入后按文本过滤。
  bool _filterByText = false;

  /// 输入框下方空间不足时改为在上方弹出。
  bool _showAbove = false;

  /// 上次监听到的文本，用于区分"输入内容变化"与"光标移动"。
  String _lastText = '';

  bool get _hasSuggestions =>
      widget.suggestions != null && widget.suggestions!.isNotEmpty;

  /// Suggestions filtered by the current input; empty input shows all.
  List<String> get _filteredSuggestions {
    final all = widget.suggestions ?? const <String>[];
    if (!_filterByText) return all;
    final query = widget.controller.text.trim();
    if (query.isEmpty) return all;
    return all.where((s) => s.contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(LabeledTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
      _lastText = widget.controller.text;
      _filterByText = false;
      _overlayEntry?.markNeedsBuild();
    }
    // 备选值被清空时不再保留弹层。
    if (oldWidget.suggestions?.isNotEmpty == true && !_hasSuggestions) {
      _removeOverlay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    widget.controller.removeListener(_handleTextChange);
    _removeOverlay();
    super.dispose();
  }

  /// 软键盘弹出/收起或窗口尺寸变化时，重新评估弹出方向（重建弹层）。
  @override
  void didChangeMetrics() {
    if (_overlayEntry != null && mounted) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _handleTextChange() {
    // 纯光标移动（选中位置变化）不算输入，不触发过滤。
    final newText = widget.controller.text;
    if (newText == _lastText) return;
    _lastText = newText;
    // Rebuild the overlay so the suggestions filter as the user types.
    _filterByText = true;
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    if (!_hasSuggestions || !mounted) return;
    if (_overlayEntry != null) {
      // 过滤无结果时弹层处于不可见空态，视为未打开，允许重新弹出完整列表。
      if (_filteredSuggestions.isNotEmpty) return;
      _removeOverlay();
    }
    // Opening the popup always offers the full list; typing narrows it.
    _filterByText = false;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  /// 下方空间不足 280 时改为在输入框上方弹出，避免被屏幕边缘或软键盘裁剪。
  /// 输入框在弹层打开期间一般不会移动（在输入框外的滚动会先触发
  /// onTapOutside 关闭弹层），但软键盘会在聚焦后弹出，故每次构建弹层时
  /// 都按当前 viewInsets 重测。直接读 View：数据总是最新，且不受
  /// 继承式 MediaQuery 的刷新时机影响。注意 viewInsets 是物理像素，
  /// 需要除以 devicePixelRatio。
  void _updateShowAbove() {
    _showAbove = false;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final view = View.of(context);
      final height = (view.physicalSize.height - view.viewInsets.bottom) /
          view.devicePixelRatio;
      _showAbove = bottom + 280 > height;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Tapping a suggestion fills the field and keeps focus for further typing.
  void _selectSuggestion(String value) {
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(offset: value.length);
    _focusNode.requestFocus();
    _removeOverlay();
  }

  void _handleTapOutside(PointerDownEvent event) {
    // Taps on the popup itself are handled by the suggestion items.
    final popupBox = _popupKey.currentContext?.findRenderObject();
    if (popupBox is RenderBox) {
      final local = popupBox.globalToLocal(event.position);
      if (local.dx >= 0 &&
          local.dy >= 0 &&
          local.dx <= popupBox.size.width &&
          local.dy <= popupBox.size.height) {
        return;
      }
    }
    _removeOverlay();
  }

  Widget _buildOverlay(BuildContext context) {
    _updateShowAbove();
    final suggestions = _filteredSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: _showAbove ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: _showAbove ? Alignment.bottomLeft : Alignment.topLeft,
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            key: _popupKey,
            elevation: 4,
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 180,
                maxWidth: 220,
                maxHeight: 260,
              ),
              child: ListView(
                key: const ValueKey('labeledTextFieldSuggestions'),
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final s in suggestions)
                    ListTile(
                      dense: true,
                      title: Text(s),
                      onTap: () => _selectSuggestion(s),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.label}${widget.required ? ' *' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (widget.description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              widget.description!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 4),
        CompositedTransformTarget(
          link: _layerLink,
          child: Listener(
            // 用 pointer-down 而非 onTap：TextField 的 onTap 只对"非连续点击"
            // 触发（双击窗口内的第二次点击不会回调），会漏掉弹层关闭后
            // 的快速重新点击。Listener 观察原始指针事件，不参与手势竞技场；
            // 仅响应主键（左键/触摸），右键与笔刷不弹出。
            onPointerDown: _hasSuggestions
                ? (e) {
                    if (e.buttons & kPrimaryButton != 0) _showOverlay();
                  }
                : null,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              // 无备选值的字段不接管 onTapOutside，保持默认失焦行为。
              onTapOutside: _hasSuggestions ? _handleTapOutside : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
              ),
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SyncedValueField — 外部值驱动的文本输入框。
// TextFormField 的 initialValue 只在首次构建生效：拖拽排序后行内容被
// 重新分配索引时，旧元素的内部 controller 仍显示旧文本。本组件在外部
// 值变化（且与输入框当前文本不一致）时同步 controller，用户输入则
// 原样保留（不打断编辑）。
// ============================================================================

class SyncedValueField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final bool readOnly;

  const SyncedValueField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.readOnly = false,
  });

  @override
  State<SyncedValueField> createState() => _SyncedValueFieldState();
}

class _SyncedValueFieldState extends State<SyncedValueField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SyncedValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化（拖拽排序、重置等）且不是用户正在输入的内容时同步。
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: widget.readOnly,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
    );
  }
}

// ============================================================================
// LlmToggleSlider — slider with toggle switch
// ============================================================================

class LlmToggleSlider extends StatelessWidget {
  final String label;
  final String? description;
  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onToggle;
  final double min;
  final double max;
  final int divisions;

  const LlmToggleSlider({
    super.key,
    required this.label,
    this.description,
    required this.enabled,
    required this.value,
    required this.onChanged,
    required this.onToggle,
    this.min = 0,
    this.max = 2,
    this.divisions = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  description!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (enabled)
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: divisions,
                      onChanged: onChanged,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      value.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LlmToggleTextField — text field with toggle switch
// ============================================================================

class LlmToggleTextField extends StatelessWidget {
  final String label;
  final String? description;
  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;
  final String? hintText;
  final bool required;
  final TextInputType keyboardType;

  const LlmToggleTextField({
    super.key,
    required this.label,
    this.description,
    required this.enabled,
    required this.controller,
    required this.onToggle,
    this.hintText,
    this.required = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$label${required ? ' *' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  description!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (enabled)
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: keyboardType,
              ),
          ],
        ),
      ),
    );
  }
}
