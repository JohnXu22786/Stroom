import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Full-screen dark dialog with pinch-to-zoom image preview.
///
/// Uses [ExtendedImage.memory] with gesture mode for built-in
/// pinch-to-zoom, pan, and double-tap zoom — no separate cache needed.
///
/// 加载策略：传 [data] 时立即显示；传 [dataLoader] 时对话框先出现并显示
/// 加载指示，字节就绪后再渲染图片 —— 避免大图在弹窗前阻塞磁盘读取
/// （聊天附件预览的卡顿来源）。
void showImagePreviewDialog({
  required BuildContext context,
  required String fileName,
  Uint8List? data,
  Future<Uint8List?> Function()? dataLoader,
}) {
  assert(data != null || dataLoader != null,
      'showImagePreviewDialog requires either data or dataLoader');
  showDialog(
    context: context,
    builder: (ctx) => _ChatImagePreviewDialog(
      fileName: fileName,
      data: data,
      dataLoader: dataLoader,
    ),
  );
}

class _ChatImagePreviewDialog extends StatefulWidget {
  final String fileName;
  final Uint8List? data;
  final Future<Uint8List?> Function()? dataLoader;

  const _ChatImagePreviewDialog({
    required this.fileName,
    this.data,
    this.dataLoader,
  });

  @override
  State<_ChatImagePreviewDialog> createState() =>
      _ChatImagePreviewDialogState();
}

class _ChatImagePreviewDialogState extends State<_ChatImagePreviewDialog> {
  late final Future<Uint8List?>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = widget.data != null ? null : _loadData();
  }

  /// 包装 loader：同步抛异常 / Future 拒绝都落到 null → 错误占位，
  /// 不能让 dialog 构建在 initState 阶段崩溃
  Future<Uint8List?> _loadData() async {
    try {
      return await widget.dataLoader?.call();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.fileName;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(child: _buildContent(context)),
          // Close button (top right) — with semi-transparent circular
          // background so it's visible regardless of image color.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // 直接传入的字节（或已加载完成的 loader 结果）
    final immediate = widget.data;
    if (immediate != null) {
      return immediate.isEmpty ? const _BrokenImage() : _buildImage(immediate);
    }
    return FutureBuilder<Uint8List?>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final data = snapshot.data;
        if (data == null || data.isEmpty) {
          return const _BrokenImage();
        }
        return _buildImage(data);
      },
    );
  }

  Widget _buildImage(Uint8List data) {
    if (widget.fileName.toLowerCase().endsWith('.svg')) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: SvgPicture.memory(
          data,
          fit: BoxFit.contain,
        ),
      );
    }
    return ExtendedImage.memory(
      data,
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.5,
        maxScale: 4.0,
        animationMinScale: 0.5,
        animationMaxScale: 4.0,
        initialScale: 1.0,
        cacheGesture: false,
      ),
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return const _BrokenImage();
        }
        return null;
      },
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.white54),
          SizedBox(height: 8),
          Text('无法加载图片', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
