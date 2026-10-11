import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Future<List<XFile>> pickNativeGalleryMedia(
  BuildContext context, {
  required bool isVideo,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) async {
  final permission = await PhotoManager.requestPermissionExtend();
  if (!permission.hasAccess) {
    await _showPermissionDialog(context);
    return [];
  }
  if (!context.mounted) return [];

  final requestType = isVideo ? RequestType.video : RequestType.image;
  final availableCount = await PhotoManager.getAssetCount(type: requestType);
  if (!context.mounted) return [];

  final theme = Theme.of(context);
  final gridCount = (MediaQuery.sizeOf(context).width / 96)
      .floor()
      .clamp(4, 10)
      .toInt();
  const preferredPageSize = 80;
  final pageSize =
      ((preferredPageSize + gridCount - 1) ~/ gridCount) * gridCount;
  final assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: AssetPickerConfig(
      // This picker requires a positive limit. Using the accessible library
      // size permits selecting every available asset without a fixed cap.
      maxAssets: math.max(1, availableCount).toInt(),
      // Keep thumbnails close to 96 logical pixels wide as the screen grows.
      // The picker requires pageSize to be a multiple of gridCount.
      gridCount: gridCount,
      pageSize: pageSize,
      requestType: requestType,
      pickerTheme: AssetPicker.themeData(
        null,
        light: theme.brightness == Brightness.light,
      ),
      dragToSelect: true,
    ),
  );
  if (assets == null || assets.isEmpty) return [];

  final files = <XFile>[];
  for (final asset in assets) {
    if (!isVideo &&
        (maxWidth != null || maxHeight != null || imageQuality != null)) {
      final width = asset.width;
      final height = asset.height;
      if (width > 0 && height > 0) {
        final scale = math.min(
          1.0,
          math.min(
            maxWidth == null ? 1.0 : maxWidth / width,
            maxHeight == null ? 1.0 : maxHeight / height,
          ),
        );
        final thumbnail = await asset.thumbnailDataWithSize(
          ThumbnailSize(
            math.max(1, (width * scale).round()).toInt(),
            math.max(1, (height * scale).round()).toInt(),
          ),
          format: ThumbnailFormat.jpeg,
          quality: imageQuality ?? 100,
        );
        if (thumbnail != null) {
          final title = await asset.titleAsync;
          files.add(
            XFile.fromData(
              thumbnail,
              name: '${p.basenameWithoutExtension(title)}.jpg',
              mimeType: 'image/jpeg',
            ),
          );
          continue;
        }
      }
    }

    final file = await asset.originFile;
    if (file == null) continue;
    files.add(XFile(file.path, name: await asset.titleAsync));
  }
  return files;
}

Future<void> _showPermissionDialog(BuildContext context) async {
  if (!context.mounted) return;
  final shouldOpenSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('需要访问相册'),
      content: const Text('请在系统设置中允许 Stroom 访问照片和视频。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('打开设置'),
        ),
      ],
    ),
  );
  if (shouldOpenSettings == true) await PhotoManager.openSetting();
}
