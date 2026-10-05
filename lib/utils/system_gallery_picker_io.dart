import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Future<List<XFile>> pickNativeGalleryMedia(
  BuildContext context, {
  required bool isVideo,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) async {
  final List<AssetEntity>? selectedAssets;
  try {
    selectedAssets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 999,
        requestType: isVideo ? RequestType.video : RequestType.image,
        pickerTheme: AssetPicker.themeData(
          Theme.of(context).colorScheme.primary,
          light: Theme.of(context).brightness == Brightness.light,
        ),
        dragToSelect: true,
      ),
    );
  } on StateError {
    if (context.mounted) {
      await _showGalleryPermissionDialog(context);
    }
    return [];
  }

  if (selectedAssets == null || selectedAssets.isEmpty) return [];

  final files = <XFile>[];
  for (final asset in selectedAssets) {
    final shouldResizeImage =
        !isVideo &&
        (maxWidth != null || maxHeight != null || imageQuality != null);
    if (shouldResizeImage) {
      if (asset.width <= 0 || asset.height <= 0) {
        throw FileSystemException('无法读取所选图片的尺寸', asset.id);
      }
      final targetWidth = (maxWidth?.round() ?? asset.width)
          .clamp(1, asset.width)
          .toInt();
      final targetHeight = (maxHeight?.round() ?? asset.height)
          .clamp(1, asset.height)
          .toInt();
      final scale = math.min(
        targetWidth / asset.width,
        targetHeight / asset.height,
      );
      final width = (asset.width * scale).round().clamp(1, targetWidth).toInt();
      final height = (asset.height * scale)
          .round()
          .clamp(1, targetHeight)
          .toInt();
      final bytes = await asset.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        format: ThumbnailFormat.jpeg,
        quality: (imageQuality ?? 100).clamp(1, 100).toInt(),
      );
      if (bytes == null || bytes.isEmpty) {
        throw FileSystemException('无法生成受尺寸限制的图片副本', asset.id);
      }
      final title = await asset.titleAsync;
      final basename = p.basenameWithoutExtension(title);
      final name = '${basename.isEmpty ? 'image' : basename}.jpg';
      files.add(
        XFile.fromData(bytes, mimeType: 'image/jpeg', name: name, path: name),
      );
      continue;
    }

    final file = await asset.originFile;
    if (file == null) {
      throw FileSystemException('无法读取所选媒体文件', asset.id);
    }
    files.add(XFile(file.path, name: await asset.titleAsync));
  }
  return files;
}

Future<void> _showGalleryPermissionDialog(BuildContext context) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('需要访问相册'),
      content: const Text('允许 Stroom 访问照片和视频后，才能浏览并导入设备媒体。返回应用后请再次打开设备相册。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('打开设置'),
        ),
      ],
    ),
  );
  if (openSettings == true) {
    await PhotoManager.openSetting();
  }
}
