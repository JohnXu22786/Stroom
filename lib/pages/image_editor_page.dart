import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/image_editor_utils.dart';

/// Editor tool selection
enum _EditorTool { none, crop, rotate, adjust, filter, draw }

/// Result returned by the image editor.
///
/// [editedBytes] contains the edited image bytes.
/// [isSaveAs] is `true` when the user chose "另存为" (save as new copy),
/// and `false` when the user chose "覆盖" (overwrite original).
class ImageEditorResult {
  final Uint8List editedBytes;
  final bool isSaveAs;

  const ImageEditorResult({
    required this.editedBytes,
    required this.isSaveAs,
  });
}

/// Image editor page.
///
/// Takes [imageBytes] as input, applies edits, and pops with an
/// [ImageEditorResult] (or pops with `null` if cancelled).
class ImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageEditorPage({super.key, required this.imageBytes});

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  // Original image dimensions (filled after first decode)
  double _origWidth = 0;
  double _origHeight = 0;

  // ======== Crop state ========
  CropRect _cropRect = CropRect();
  CropRect? _savedCropRect; // non-null once user confirms crop
  Offset? _cropStart; // drag start position for crop

  // ======== Rotate/flip state ========
  int _rotation = 0; // 0, 90, 180, 270
  bool _flipH = false;
  bool _flipV = false;

  // ======== Adjust state ========
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;

  // ======== Filter state ========
  ImageFilterType _filter = ImageFilterType.none;

  // ======== Drawing state ========
  List<EditorPath> _drawings = [];
  List<EditorPath> _undoStack = [];
  Color _drawColor = Colors.red;
  double _drawStrokeWidth = 3.0;
  List<Offset> _currentPoints = [];

  // ======== UI state ========
  _EditorTool _currentTool = _EditorTool.none;
  bool _isSaving = false;

  // ======== Zoom state ========
  final TransformationController _transformController =
      TransformationController();

  // ======== Lifecycle ========

  @override
  void initState() {
    super.initState();
    _initImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _initImage() async {
    try {
      final image = await ImageEditorPipeline.decodeImage(widget.imageBytes);
      if (mounted) {
        setState(() {
          _origWidth = image.width.toDouble();
          _origHeight = image.height.toDouble();
        });
      }
    } catch (_) {
      // Image decode failed — error state is shown in build()
    }
  }

  // ======== Computed properties ========

  bool get _imageLoaded => _origWidth > 0 && _origHeight > 0;

  bool get _hasEdits =>
      _savedCropRect != null ||
      _rotation != 0 ||
      _flipH ||
      _flipV ||
      _brightness != 0.0 ||
      _contrast != 1.0 ||
      _saturation != 1.0 ||
      _filter != ImageFilterType.none ||
      _drawings.isNotEmpty;

  ColorFilter? get _colorFilter {
    if (_filter != ImageFilterType.none) {
      return ImageEditorPipeline.buildFilterColorFilter(_filter);
    }
    if (_brightness != 0.0 || _contrast != 1.0 || _saturation != 1.0) {
      return ImageEditorPipeline.buildAdjustColorFilter(
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
      );
    }
    return null;
  }

  // ======== Zoom helpers ========

  void _zoomIn() {
    final current = _transformController.value;
    final scale = current.getMaxScaleOnAxis();
    final newScale = (scale * 1.25).clamp(0.5, 4.0);
    // Preserve the current translation so zoom doesn't reset pan position
    final translationX = current[12];
    final translationY = current[13];
    final matrix = Matrix4.diagonal3Values(newScale, newScale, 1);
    matrix.setTranslationRaw(translationX, translationY, 0);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final current = _transformController.value;
    final scale = current.getMaxScaleOnAxis();
    final newScale = (scale / 1.25).clamp(0.5, 4.0);
    // Preserve the current translation so zoom doesn't reset pan position
    final translationX = current[12];
    final translationY = current[13];
    final matrix = Matrix4.diagonal3Values(newScale, newScale, 1);
    matrix.setTranslationRaw(translationX, translationY, 0);
    _transformController.value = matrix;
  }

  void _fitToScreen() {
    _transformController.value = Matrix4.identity();
  }

  // ======== Actions ========

  Future<void> _showSaveDialog() async {
    final result = await showDialog<_SaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          '保存图片',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '请选择保存方式：',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveAction.cancel),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveAction.overwrite),
            child: const Text(
              '覆盖',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _SaveAction.saveAs),
            child: const Text('另存为'),
          ),
        ],
      ),
    );

    if (result == null || result == _SaveAction.cancel) return;

    await _save(result == _SaveAction.saveAs);
  }

  Future<void> _save(bool isSaveAs) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final edited = await ImageEditorPipeline.applyAll(
        widget.imageBytes,
        editorState: {
          'cropRect': _savedCropRect,
          'rotation': _rotation,
          'flipH': _flipH,
          'flipV': _flipV,
          'brightness': _brightness,
          'contrast': _contrast,
          'saturation': _saturation,
          'filter': _filter,
          'drawings': _drawings,
        },
      );
      if (mounted) {
        Navigator.pop(
          context,
          ImageEditorResult(editedBytes: edited, isSaveAs: isSaveAs),
        );
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

  void _cancel() {
    Navigator.pop(context, null);
  }

  void _resetAll() {
    setState(() {
      _savedCropRect = null;
      _cropRect = CropRect();
      _rotation = 0;
      _flipH = false;
      _flipV = false;
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _filter = ImageFilterType.none;
      _drawings = [];
      _undoStack = [];
      _currentPoints = [];
    });
    _fitToScreen();
  }

  // ======== Rotate helpers ========

  void _rotateCW() => setState(() => _rotation = (_rotation + 90) % 360);
  void _rotateCCW() => setState(() => _rotation = (_rotation - 90 + 360) % 360);
  void _toggleFlipH() => setState(() => _flipH = !_flipH);
  void _toggleFlipV() => setState(() => _flipV = !_flipV);

  // ======== Adjust helpers ========

  void _resetAdjust() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
    });
  }

  // ======== Crop helpers ========

  void _confirmCrop() {
    setState(() {
      _savedCropRect = _cropRect;
      _currentTool = _EditorTool.none;
    });
  }

  void _resetCrop() {
    setState(() {
      _cropRect = CropRect();
      _savedCropRect = null;
    });
  }

  // ======== Drawing helpers ========

  void _undoLastStroke() {
    if (_drawings.isEmpty) return;
    setState(() {
      _undoStack.add(_drawings.removeLast());
    });
  }

  void _clearDrawings() {
    setState(() {
      _undoStack.addAll(_drawings);
      _drawings.clear();
    });
  }

  void _redoStroke() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _drawings.add(_undoStack.removeLast());
    });
  }

  // ======== Build ========

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(cs),
      body: _imageLoaded ? _buildBody(cs) : _buildLoading(),
      bottomNavigationBar: _buildBottomBar(cs),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _cancel,
        tooltip: '取消',
      ),
      title: const Text(
        '图片编辑',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        // Zoom controls
        IconButton(
          icon: const Icon(Icons.zoom_out, color: Colors.white),
          onPressed: _zoomOut,
          tooltip: '缩小',
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in, color: Colors.white),
          onPressed: _zoomIn,
          tooltip: '放大',
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen, color: Colors.white),
          onPressed: _fitToScreen,
          tooltip: '适应屏幕',
        ),
        TextButton(
          onPressed: _hasEdits ? _resetAll : null,
          child: Text(
            '重置',
            style: TextStyle(
              color: _hasEdits ? Colors.white : Colors.white38,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: _isSaving ? null : _showSaveDialog,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            '加载图片中...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    return Column(
      children: [
        // Image preview area
        Expanded(
          child: _buildPreviewArea(cs),
        ),
        // Tool-specific controls
        if (_currentTool != _EditorTool.none)
          _buildToolControls(cs),
      ],
    );
  }

  Widget _buildPreviewArea(ColorScheme cs) {
    // Determine the pixel dimensions for display
    final double displayW, displayH;
    if (_rotation % 180 == 0) {
      displayW = _origWidth;
      displayH = _origHeight;
    } else {
      displayW = _origHeight;
      displayH = _origWidth;
    }

    Widget imageWidget = Image.memory(
      widget.imageBytes,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Text(
          '无法加载图片',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );

    // Apply rotation and flip transforms
    imageWidget = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(_rotation * 3.1415927 / 180)
        ..setEntry(0, 0, _flipH ? -1.0 : 1.0)
        ..setEntry(1, 1, _flipV ? -1.0 : 1.0),
      child: imageWidget,
    );

    // Apply color filter
    if (_colorFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: _colorFilter!,
        child: imageWidget,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;

        // Calculate fitting dimensions so the image fits within the viewport
        final aspectRatio = displayW / displayH;
        double fitW, fitH;
        if (viewW / viewH > aspectRatio) {
          // Viewport is wider than image aspect — height constrained
          fitH = viewH;
          fitW = fitH * aspectRatio;
        } else {
          // Viewport is taller than image aspect — width constrained
          fitW = viewW;
          fitH = fitW / aspectRatio;
        }

        final zoomedImage = InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 4.0,
          constrained: false,
          child: SizedBox(
            width: fitW,
            height: fitH,
            child: imageWidget,
          ),
        );

        return Stack(
          children: [
            zoomedImage,
            // Crop overlay
            if (_currentTool == _EditorTool.crop)
              _buildCropOverlay(cs, Size(viewW, viewH)),
            // Drawing overlay
            if (_currentTool == _EditorTool.draw)
              GestureDetector(
                onPanStart: _onDrawStart,
                onPanUpdate: _onDrawUpdate,
                onPanEnd: _onDrawEnd,
                child: CustomPaint(
                  painter: _DrawingOverlayPainter(
                    drawings: _drawings,
                    currentPoints: _currentPoints,
                    currentColor: _drawColor,
                    currentStrokeWidth: _drawStrokeWidth,
                  ),
                  size: Size(displayW, displayH),
                ),
              ),
          ],
        );
      },
    );
  }

  // ======== Crop overlay ========

  Widget _buildCropOverlay(ColorScheme cs, Size overlaySize) {
    // Calculate image position within the viewport (inverse of painter logic)
    final displayAspect = overlaySize.width / overlaySize.height;
    final aspectRatio = _rotation % 180 == 0
        ? _origWidth / _origHeight
        : _origHeight / _origWidth;
    double imgW, imgH, imgX, imgY;
    if (displayAspect > aspectRatio) {
      imgH = overlaySize.height;
      imgW = imgH * aspectRatio;
      imgX = (overlaySize.width - imgW) / 2;
      imgY = 0;
    } else {
      imgW = overlaySize.width;
      imgH = imgW / aspectRatio;
      imgX = 0;
      imgY = (overlaySize.height - imgH) / 2;
    }

    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _cropStart = details.localPosition;
          _cropRect = CropRect(x: 0, y: 0, width: 1, height: 1);
        });
      },
      onPanUpdate: (details) {
        if (_cropStart == null ||
            overlaySize.width <= 0 ||
            overlaySize.height <= 0 ||
            imgW <= 0 ||
            imgH <= 0) {
          return;
        }
        // Convert viewport coordinates to image-relative normalized (0..1)
        final relDx = (details.localPosition.dx - imgX) / imgW;
        final relDy = (details.localPosition.dy - imgY) / imgH;
        setState(() {
          final startRelX =
              ((_cropStart!.dx - imgX) / imgW).clamp(0.0, 1.0);
          final startRelY =
              ((_cropStart!.dy - imgY) / imgH).clamp(0.0, 1.0);
          final endX = relDx.clamp(0.0, 1.0);
          final endY = relDy.clamp(0.0, 1.0);
          _cropRect = CropRect(
            x: startRelX < endX ? startRelX : endX,
            y: startRelY < endY ? startRelY : endY,
            width: (endX - startRelX).abs().clamp(0.05, 1.0),
            height: (endY - startRelY).abs().clamp(0.05, 1.0),
          );
        });
      },
      onPanEnd: (_) {
        setState(() => _cropStart = null);
      },
      child: CustomPaint(
        painter: _CropOverlayPainter(
          cropRect: _cropRect,
          aspectRatio: aspectRatio,
          overlaySize: overlaySize,
        ),
        size: overlaySize,
      ),
    );
  }

  // ======== Drawing handlers ========

  void _onDrawStart(DragStartDetails details) {
    // Convert local position to image-relative coordinates
    // For simplicity, we use the local position directly
    setState(() {
      _currentPoints = [details.localPosition];
    });
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoints.add(details.localPosition);
    });
  }

  void _onDrawEnd(DragEndDetails details) {
    if (_currentPoints.length >= 2) {
      setState(() {
        _drawings.add(EditorPath(
          points: List.from(_currentPoints),
          color: _drawColor,
          strokeWidth: _drawStrokeWidth,
        ));
        _currentPoints = [];
      });
    } else {
      setState(() => _currentPoints = []);
    }
  }

  // ======== Tool controls ========

  Widget _buildToolControls(ColorScheme cs) {
    switch (_currentTool) {
      case _EditorTool.crop:
        return _buildCropControls(cs);
      case _EditorTool.rotate:
        return _buildRotateControls(cs);
      case _EditorTool.adjust:
        return _buildAdjustControls(cs);
      case _EditorTool.filter:
        return _buildFilterControls(cs);
      case _EditorTool.draw:
        return _buildDrawControls(cs);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCropControls(ColorScheme cs) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _resetCrop,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            label: const Text('重置',
                style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: _confirmCrop,
            child: const Text('确认裁剪'),
          ),
        ],
      ),
    );
  }

  Widget _buildRotateControls(ColorScheme cs) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolIconButton(Icons.rotate_left, '左旋90°', _rotateCCW),
          _toolIconButton(Icons.rotate_right, '右旋90°', _rotateCW),
          _toolIconButton(
            _flipH ? Icons.flip_to_front : Icons.flip_to_back,
            '水平翻转',
            _toggleFlipH,
          ),
          _toolIconButton(
            Icons.flip,
            '垂直翻转',
            _toggleFlipV,
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustControls(ColorScheme cs) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSlider('亮度', _brightness, -1.0, 1.0, (v) {
            setState(() => _brightness = v);
          }),
          _buildSlider('对比度', _contrast, 0.0, 3.0, (v) {
            setState(() => _contrast = v);
          }),
          _buildSlider('饱和度', _saturation, 0.0, 3.0, (v) {
            setState(() => _saturation = v);
          }),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _resetAdjust,
            child: const Text('重置参数', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.blue.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: 100,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls(ColorScheme cs) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ImageFilterType.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = ImageFilterType.values[index];
            final isSelected = _filter == filter;
            return FilterChip(
              label: Text(
                filter.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: cs.primary,
              backgroundColor: Colors.white12,
              checkmarkColor: Colors.white,
              onSelected: (_) => setState(() => _filter = filter),
              side: BorderSide.none,
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawControls(ColorScheme cs) {
    const colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.white,
      Colors.black,
    ];

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color picker
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: colors.map((c) {
              final isSelected = _drawColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _drawColor = c),
                child: Container(
                  width: isSelected ? 32 : 24,
                  height: isSelected ? 32 : 24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Stroke width + Undo/Clear
          Row(
            children: [
              const Text('粗细', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.blue.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _drawStrokeWidth,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    onChanged: (v) => setState(() => _drawStrokeWidth = v),
                  ),
                ),
              ),
              Text(
                _drawStrokeWidth.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _undoStack.isNotEmpty ? _redoStroke : null,
                child: Text(
                  '重做',
                  style: TextStyle(
                    color: _undoStack.isNotEmpty ? Colors.white70 : Colors.white24,
                  ),
                ),
              ),
              TextButton(
                onPressed: _drawings.isNotEmpty ? _undoLastStroke : null,
                child: Text(
                  '撤销',
                  style: TextStyle(
                    color: _drawings.isNotEmpty ? Colors.white70 : Colors.white24,
                  ),
                ),
              ),
              TextButton(
                onPressed: _drawings.isNotEmpty ? _clearDrawings : null,
                child: Text(
                  '清除',
                  style: TextStyle(
                    color: _drawings.isNotEmpty ? Colors.white70 : Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  // ======== Bottom toolbar ========

  Widget _buildBottomBar(ColorScheme cs) {
    return Container(
      color: Colors.black87,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton(Icons.crop, '裁剪', _EditorTool.crop),
          _buildToolButton(Icons.rotate_right, '旋转', _EditorTool.rotate),
          _buildToolButton(Icons.tune, '调整', _EditorTool.adjust),
          _buildToolButton(Icons.filter, '滤镜', _EditorTool.filter),
          _buildToolButton(Icons.brush, '画笔', _EditorTool.draw),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, _EditorTool tool) {
    final isSelected = _currentTool == tool;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTool = isSelected ? _EditorTool.none : tool;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Drawing overlay painter
// ====================================================================

class _DrawingOverlayPainter extends CustomPainter {
  final List<EditorPath> drawings;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;

  _DrawingOverlayPainter({
    required this.drawings,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed paths
    for (final path in drawings) {
      if (path.points.length < 2) continue;
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final uiPath = Path();
      uiPath.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        uiPath.lineTo(path.points[i].dx, path.points[i].dy);
      }
      canvas.drawPath(uiPath, paint);
    }

    // Draw current (in-progress) stroke
    if (currentPoints.length >= 2) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final uiPath = Path();
      uiPath.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 1; i < currentPoints.length; i++) {
        uiPath.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(uiPath, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingOverlayPainter oldDelegate) => true;
}

// ====================================================================
// Enum for save dialog action
// ====================================================================

enum _SaveAction { overwrite, saveAs, cancel }

// ====================================================================
// Crop overlay painter
// ====================================================================

class _CropOverlayPainter extends CustomPainter {
  final CropRect cropRect;
  final double aspectRatio;
  final Size overlaySize;

  _CropOverlayPainter({
    required this.cropRect,
    required this.aspectRatio,
    required this.overlaySize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the crop area in pixels based on the display size
    final displayAspect = overlaySize.width / overlaySize.height;
    double imgW, imgH, imgX, imgY;
    if (displayAspect > aspectRatio) {
      // Display is wider than image — image is height-constrained
      imgH = overlaySize.height;
      imgW = imgH * aspectRatio;
      imgX = (overlaySize.width - imgW) / 2;
      imgY = 0;
    } else {
      // Display is taller than image — image is width-constrained
      imgW = overlaySize.width;
      imgH = imgW / aspectRatio;
      imgX = 0;
      imgY = (overlaySize.height - imgH) / 2;
    }

    final cropX = imgX + cropRect.x * imgW;
    final cropY = imgY + cropRect.y * imgH;
    final cropW = cropRect.width * imgW;
    final cropH = cropRect.height * imgH;

    // Darken outside crop area
    final fillPaint = Paint()..color = Colors.black54;

    // Top
    if (cropY > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, overlaySize.width, cropY), fillPaint);
    }
    // Bottom
    final bottom = cropY + cropH;
    if (bottom < overlaySize.height) {
      canvas.drawRect(
        Rect.fromLTWH(0, bottom, overlaySize.width, overlaySize.height - bottom),
        fillPaint,
      );
    }
    // Left
    if (cropX > imgX) {
      canvas.drawRect(
        Rect.fromLTWH(imgX, cropY, cropX - imgX, cropH),
        fillPaint,
      );
    }
    // Right
    final right = cropX + cropW;
    final imgRight = imgX + imgW;
    if (right < imgRight) {
      canvas.drawRect(
        Rect.fromLTWH(right, cropY, imgRight - right, cropH),
        fillPaint,
      );
    }

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(cropX, cropY, cropW, cropH),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect ||
      oldDelegate.aspectRatio != aspectRatio ||
      oldDelegate.overlaySize != overlaySize;
}
