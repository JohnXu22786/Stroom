import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Full-screen image preview dialog with close and edit buttons.
///
/// 加载策略说明 (Loading strategy):
/// ── 旧逻辑 (old): 调用方先 await 完整图加载完成，然后将完整图数据传入 dialog 显示。
///    即：需等待完整图（可能数 MB）从磁盘读取完毕后，对话框才出现。
/// ── 新逻辑 (new): 对话框立即打开，显示缩略图（从缓存或磁盘快速获取）作为占位，
///    同时在后台异步加载完整图；完整图加载完成后无缝替换。
///    如果缩略图不可用，则显示加载指示器；如果完整图加载失败，保留缩略图或显示错误。
///
/// Parameters:
///   [thumbnailData]   — 缩略图字节（可能为 null，表示无可用的缩略图）
///   [fullImageFuture] — 完整图加载 Future（在后台执行，不阻塞对话框打开）
///   [fileName]        — 文件显示名
class ImagePreviewDialog extends StatefulWidget {
  final Uint8List? thumbnailData;
  final Future<Uint8List?> fullImageFuture;
  final String fileName;

  const ImagePreviewDialog({
    super.key,
    required this.thumbnailData,
    required this.fullImageFuture,
    required this.fileName,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  /// 当前显示的数据：初始为缩略图，完整图加载完成后替换为完整图
  Uint8List? _displayData;

  /// 完整图是否已加载完成
  bool _isFullImageLoaded = false;

  /// 完整图加载是否失败（无有效数据可显示时的最终错误态）
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 初始显示缩略图（可能为 null，此时会显示加载指示器）
    _displayData = widget.thumbnailData;
    // 在后台启动完整图加载
    _loadFullImage();
  }

  Future<void> _loadFullImage() async {
    try {
      final fullData = await widget.fullImageFuture;
      if (!mounted) return;

      if (fullData != null && fullData.isNotEmpty) {
        // 完整图加载成功 → 替换显示
        setState(() {
          _displayData = fullData;
          _isFullImageLoaded = true;
        });
      } else if (_displayData == null) {
        // 没有缩略图且完整图返回空/null → 显示错误
        setState(() {
          _hasError = true;
        });
      }
      // 有缩略图且完整图返回空/null → 保留缩略图，不显示错误
    } catch (_) {
      if (!mounted) return;
      if (_displayData == null) {
        // 没有缩略图且完整图加载异常 → 显示错误
        setState(() {
          _hasError = true;
        });
      }
      // 有缩略图且完整图加载异常 → 保留缩略图
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: _buildContent(),
          ),
          // Close button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          // Edit button (top right) — 仅在完整图加载完成后可编辑
          // 旧逻辑：编辑按钮始终可用（完整图在打开对话框前已加载完成）
          // 新逻辑：完整图在后台加载中，加载完成前编辑按钮不可用
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.edit,
                color: _isFullImageLoaded
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                size: 28,
              ),
              tooltip: _isFullImageLoaded ? '编辑图片' : '图片加载中，请稍后...',
              onPressed: _isFullImageLoaded
                  ? () => Navigator.pop(context, true)
                  : null,
            ),
          ),
          // Bottom file-name
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              widget.fileName,
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

  Widget _buildContent() {
    // 错误态（无缩略图且完整图加载失败）
    if (_hasError && _displayData == null) {
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

    // 加载中（无缩略图，完整图还在加载）
    if (_displayData == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // 有数据可显示（缩略图或完整图）
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      // 旧逻辑：直接显示完整图
      // 新逻辑：先显示缩略图，完整图加载完成后无缝替换
      child: Image.memory(
        _displayData!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.white54),
              SizedBox(height: 8),
              Text('无法加载图片', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
