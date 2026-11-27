import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../l10n/app_localizations.dart';

import '../widgets/constrained_text.dart';

Future<XFile?> createConstrainedGalleryImageFile({
  required String title,
  required int width,
  required int height,
  required double? maxWidth,
  required double? maxHeight,
  required int? imageQuality,
  required Future<Uint8List?> Function(
    ThumbnailSize size, {
    required ThumbnailFormat format,
    required int quality,
  }) thumbnailDataWithSize,
}) async {
  if (width <= 0 || height <= 0) return null;

  final scale = math.min(
    1.0,
    math.min(
      maxWidth == null ? 1.0 : maxWidth / width,
      maxHeight == null ? 1.0 : maxHeight / height,
    ),
  );
  final thumbnail = await thumbnailDataWithSize(
    ThumbnailSize(
      math.max(1, (width * scale).round()).toInt(),
      math.max(1, (height * scale).round()).toInt(),
    ),
    format: ThumbnailFormat.jpeg,
    quality: imageQuality ?? 100,
  );
  if (thumbnail == null) return null;

  return XFile.fromData(
    thumbnail,
    name: '${p.basenameWithoutExtension(title)}.jpg',
    mimeType: 'image/jpeg',
  );
}

Future<List<XFile>> collectConstrainedGalleryImageFiles(
  Iterable<Future<XFile?> Function()> createFiles,
) async {
  final files = <XFile>[];
  for (final createFile in createFiles) {
    try {
      final file = await createFile();
      if (file != null) files.add(file);
    } on Exception {
      // A failed asset must not discard other successfully constrained files.
    }
  }
  return files;
}

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
  final gridCount =
      (MediaQuery.sizeOf(context).width / 96).floor().clamp(4, 10).toInt();
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

  if (!isVideo &&
      (maxWidth != null || maxHeight != null || imageQuality != null)) {
    return collectConstrainedGalleryImageFiles(
      assets.map(
        (asset) => () async {
          final title = await asset.titleAsync;
          return createConstrainedGalleryImageFile(
            title: title,
            width: asset.width,
            height: asset.height,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            imageQuality: imageQuality,
            thumbnailDataWithSize: asset.thumbnailDataWithSize,
          );
        },
      ),
    );
  }

  final files = <XFile>[];
  for (final asset in assets) {
    final file = await asset.originFile;
    if (file == null) continue;
    files.add(XFile(file.path, name: await asset.titleAsync));
  }
  return files;
}

Future<void> _showPermissionDialog(BuildContext context) async {
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final shouldOpenSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: ConstrainedText(
        l10n.galleryPermissionTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: Text(l10n.galleryPermissionMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: ConstrainedText(
            l10n.galleryPermissionCancel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: ConstrainedText(
            l10n.galleryPermissionOpenSettings,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
  if (shouldOpenSettings == true) await PhotoManager.openSetting();
}
