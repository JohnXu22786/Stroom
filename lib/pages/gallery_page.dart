import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:extended_image/extended_image.dart';

import '../providers/image_provider.dart';
import '../utils/image_manifest.dart';
import '../utils/image_thumbnail_loader.dart';
import '../utils/file_picker_utils.dart';
import '../utils/manifest_bridge.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../utils/system_pick_utils.dart';
import '../utils/storage_file_publication.dart';
import '../utils/partial_import_refresh.dart';
import '../widgets/file_manager_view.dart';
import '../widgets/file_manager_utils.dart';
import 'files_page_shared.dart';
import 'gallery_shared.dart';
import 'gallery_viewer_page.dart';

import '../widgets/constrained_text.dart';

Future<bool> _mutateGalleryFolderPath({
  required String sourcePath,
  required String destinationPath,
  required bool copy,
  required Future<void> Function() mutate,
}) async {
  final records = await ImageManifest.loadRecordsStrict();
  final folders = await ImageManifest.getAllFolders();
  final sourcePrefix = '$sourcePath/';
  final sourceRecords = records
      .where(
        (record) =>
            record.folder == sourcePath ||
            record.folder.startsWith(sourcePrefix),
      )
      .toList();
  final sourceRecordLocations = {
    for (final record in sourceRecords) record.id: record.folder,
  };
  final sourceFolders = folders
      .where(
        (folder) => folder == sourcePath || folder.startsWith(sourcePrefix),
      )
      .toSet()
    ..add(sourcePath);
  final mappedFolders = sourceFolders
      .map(
        (folder) => folder == sourcePath
            ? destinationPath
            : '$destinationPath${folder.substring(sourcePath.length)}',
      )
      .toSet();
  final mappedRecords = sourceRecords.map((record) {
    final folder = record.folder == sourcePath
        ? destinationPath
        : '$destinationPath${record.folder.substring(sourcePath.length)}';
    return record.copyWith(folder: folder);
  }).toList();
  final destinationParents = <String>{
    ImageManifest.getParentFolderPath(sourcePath),
    ImageManifest.getParentFolderPath(destinationPath),
    ...mappedFolders,
    for (final record in mappedRecords) record.folder,
  };

  return withGalleryVisibleNameLocks(
    {
      sourcePath,
      ...sourceFolders,
      ...destinationParents,
    },
    () async {
      // Recheck all manifest paths while the source and destination namespaces
      // are reserved. Retry is unnecessary: callers can invoke again after the
      // competing mutation has completed.
      final currentRecords = await ImageManifest.loadRecordsStrict();
      final currentFolders = await ImageManifest.getAllFolders();
      final currentSourceRecords = currentRecords
          .where(
            (record) =>
                record.folder == sourcePath ||
                record.folder.startsWith(sourcePrefix),
          )
          .toList();
      final currentSourceFolders = currentFolders
          .where(
            (folder) => folder == sourcePath || folder.startsWith(sourcePrefix),
          )
          .toSet()
        ..add(sourcePath);
      final currentRecordLocations = {
        for (final record in currentSourceRecords) record.id: record.folder,
      };
      bool sameSet<T>(Set<T> left, Set<T> right) =>
          left.length == right.length && left.containsAll(right);
      if (currentRecordLocations.length != sourceRecordLocations.length ||
          currentRecordLocations.entries.any(
            (entry) => sourceRecordLocations[entry.key] != entry.value,
          ) ||
          !sameSet(currentSourceFolders, sourceFolders)) {
        return false;
      }

      final liveExcludedIds = copy
          ? const <String>{}
          : currentSourceRecords.map((record) => record.id).toSet();
      final liveExcludedFolders =
          copy ? const <String>{} : currentSourceFolders;
      final liveUnrelatedRecords = currentRecords
          .where((record) => !liveExcludedIds.contains(record.id))
          .toList();
      final liveUnrelatedFolders = currentFolders
          .where((folder) => !liveExcludedFolders.contains(folder))
          .toList();
      final liveMappedFolders = currentSourceFolders
          .map(
            (folder) => folder == sourcePath
                ? destinationPath
                : '$destinationPath${folder.substring(sourcePath.length)}',
          )
          .toSet();
      final liveMappedRecords = currentSourceRecords.map((record) {
        final folder = record.folder == sourcePath
            ? destinationPath
            : '$destinationPath${record.folder.substring(sourcePath.length)}';
        return record.copyWith(folder: folder);
      }).toList();

      for (final folder in liveMappedFolders) {
        if (galleryVisiblePathHasConflict(
          path: folder,
          isFolder: true,
          records: liveUnrelatedRecords,
          folders: liveUnrelatedFolders,
        )) {
          return false;
        }
      }
      final outputFileKeys = <String>{};
      for (final record in liveMappedRecords) {
        final path = galleryRecordVisiblePath(record);
        final pathKey = userVisibleExportPathComparisonKey(path);
        if (!outputFileKeys.add(pathKey) ||
            galleryVisiblePathHasConflict(
              path: path,
              isFolder: false,
              records: liveUnrelatedRecords,
              folders: liveUnrelatedFolders,
            )) {
          return false;
        }
        if (liveMappedFolders.any((folder) {
          final folderKey = userVisibleExportPathComparisonKey(folder);
          return pathKey == folderKey || folderKey.startsWith('$pathKey/');
        })) {
          return false;
        }
      }

      await mutate();
      return true;
    },
  );
}

class GalleryPage extends ConsumerStatefulWidget {
  final int tabIndex;
  final bool isActiveTab;
  @visibleForTesting
  final Future<XFile?> Function()? testCameraPicker;

  const GalleryPage({
    super.key,
    this.tabIndex = 0,
    this.isActiveTab = true,
    this.testCameraPicker,
  });

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageRecordsProvider.notifier).loadRecords();
      ref.read(imageFolderListProvider.notifier).loadFolders();
    });
    // 重新进入文件页（切换底部导航）时 filesRefreshSignalProvider 递增：
    // 只重载数据，不重建页面，保留已打开的文件夹层级。
    ref.listenManual(filesRefreshSignalProvider, (prev, next) {
      ref.read(imageRecordsProvider.notifier).loadRecords();
      ref.read(imageFolderListProvider.notifier).loadFolders();
    });
  }

  /// Formats whose thumbnails / preview are rendered via `ExtendedImage`.
  static const _supportedFormats = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'wbmp',
    'svg',
  };

  /// Tracks the currently-active folder (synced from FileManagerView).
  String _currentFolder = '';

  /// Guards against re-entrant imports.
  bool _isImporting = false;

  /// Guards against re-entrant image preview (double-tap while loading).
  bool _isPreviewing = false;

  /// 缩略图解码目标尺寸（与生成尺寸一致：≤256px，宽高比保持）
  static const int _thumbDecodeSize = 256;

  /// Finds an available import name based on current visible folder paths.
  String _uniqueImageName(
    String baseName,
    String format,
    String folder,
    List<ImageRecord> records,
    Set<String> usedInBatch,
    Iterable<String> existingFolders,
  ) =>
      uniqueGalleryVisibleName(
        records: records,
        folder: folder,
        baseName: baseName,
        format: format,
        existingFolders: existingFolders,
        reservedFileNames: usedInBatch,
      );

  // ====================================================================
  // Image preview (full-screen gallery viewer)
  // ====================================================================

  /// 记录被删除后丢弃其缩略图内存缓存（hash 键控，防陈旧字节驻留）。
  void _invalidateThumbnails(Iterable<ImageRecord> recs) {
    for (final r in recs) {
      ImageThumbnailLoader.invalidate(r.hash);
    }
  }

  Future<void> _showImagePreview(ImageRecord file) async {
    if (_isPreviewing) return;
    _isPreviewing = true;
    try {
      if (!_supportedFormats.contains(file.format)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!
                    .galleryUnsupportedPreview(file.format),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Get all images in the current folder for gallery browsing
      final records = ref.read(imageRecordsProvider);
      final folderImages = records
          .where(
            (r) =>
                r.folder == file.folder && _supportedFormats.contains(r.format),
          )
          .toList();
      final initialIndex = folderImages.indexWhere((r) => r.id == file.id);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryViewerPage(
            images: folderImages,
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          ),
        ),
      );

      // Refresh records after returning from viewer — edits (overwrite / save-as)
      // create new records with new hashes, and the gallery grid needs to reflect
      // these changes immediately.
      ref.read(imageRecordsProvider.notifier).loadRecords();
    } finally {
      _isPreviewing = false;
    }
  }
  // ====================================================================
  // Import / export
  // ====================================================================

  Future<void> _takePhoto() async {
    // 直接保存到当前正在浏览的文件夹（_currentFolder），不再弹文件夹选择
    var success = false;
    try {
      final picker = ImagePicker();
      final file = await (widget.testCameraPicker?.call() ??
          picker.pickImage(source: ImageSource.camera));
      if (file == null) return;
      if (!mounted) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('Camera returned an empty image');
      }
      final hash = computeImageHash(bytes);
      const format = 'jpg';
      final fileName = '$hash.$format';
      final destinationFolder = _currentFolder;
      await withGalleryVisibleNameLock(destinationFolder, () async {
        final records = await ImageManifest.loadRecordsStrict();
        final existingFolders = await ImageManifest.getAllFolders();
        final now = DateTime.now();
        final timestamp =
            '${now.year}${padInt(now.month)}${padInt(now.day)}_${padInt(now.hour)}${padInt(now.minute)}${padInt(now.second)}';
        final visibleName = uniqueGalleryVisibleName(
          records: records,
          folder: destinationFolder,
          baseName: '照片_$timestamp',
          format: format,
          existingFolders: existingFolders,
        );
        await ImageManifest.withFilePublicationLock(
          hash,
          destinationFolder,
          () async => publishStorageFiles<void, ImageRecord>(
            publish: (writeFile) async {
              await writeFile(fileName, bytes);
              final thumbnailBytes =
                  await ImageThumbnailLoader.generateThumbnail(
                bytes,
              );
              if (thumbnailBytes != null) {
                await writeFile(imageThumbFileName(hash), thumbnailBytes);
              }
              await ImageManifest.addRecord(
                ImageRecord(
                  name: visibleName,
                  hash: hash,
                  format: format,
                  createdAt: DateTime.now(),
                  size: bytes.length,
                  folder: destinationFolder,
                ),
              );
            },
            loadRecords: ImageManifest.loadRecordsStrict,
            isReferenced: (record, name) =>
                record.hash == hash &&
                (name == record.storageFileName ||
                    name == imageThumbFileName(record.hash)),
            writeFile: ImageManifest.writeFile,
            readFile: ImageManifest.readFile,
            fileExists: ImageManifest.fileExists,
            deleteFile: ImageManifest.deleteFile,
          ),
        );
      });
      success = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.galleryCameraFailed(e.toString()),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    await ref.read(imageRecordsProvider.notifier).loadRecords();
    await ref.read(imageFolderListProvider.notifier).loadFolders();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.galleryPhotoSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _importFromGallery() async {
    if (_isImporting) return;
    _isImporting = true;
    var count = 0;
    // 记录加载对话框是否弹出：异常发生在弹窗之前（如文件选择器/系统
    // 相册选择器抛错）或成功弹出之后（如 loadRecords 抛错）时，catch 中的
    // pop 会误弹下层路由（应用根路由），因此必须带条件执行
    var dialogShown = false;
    try {
      // 移动端打开应用内相册选择器，
      // 桌面端打开文件选择器并定位到系统"图片"目录
      final pickedFiles = await pickGalleryMedia(
        GalleryMediaKind.image,
        context: context,
      );
      if (pickedFiles.isEmpty) {
        _isImporting = false;
        return;
      }

      if (!mounted) return;
      // Loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        // PopScope(canPop: false)：barrierDismissible 只能拦截点击遮罩，
        // 系统返回键仍会关掉对话框 —— 若不拦截，加载完成后
        // Navigator.pop() 可能误弹下层路由（应用根路由）
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
      dialogShown = true;

      final usedInBatch = <String>{};
      count = await importBatchWithPartialRefresh(
        items: pickedFiles,
        importItem: (pickedFile) async {
          final bytes = await pickedFile.readAsBytes();
          if (bytes.isEmpty) return false;
          final hash = computeImageHash(bytes);
          final rawName = sanitizeFileName(pickedFile.name);
          final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
          final format = ext.isNotEmpty ? ext : 'jpg';
          if (!_supportedFormats.contains(format)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!
                        .galleryUnsupportedImportFormat(format),
                  ),
                ),
              );
            }
            return false;
          }
          final storageFileName = '$hash.$format';
          final destinationFolder = _currentFolder;
          await withGalleryVisibleNameLock(destinationFolder, () async {
            final records = await ImageManifest.loadRecordsStrict();
            final existingFolders = await ImageManifest.getAllFolders();
            final displayName = _uniqueImageName(
              p.basenameWithoutExtension(rawName),
              format,
              destinationFolder,
              records,
              usedInBatch,
              existingFolders,
            );
            usedInBatch.add('$displayName.$format');
            await ImageManifest.withFilePublicationLock(
              hash,
              destinationFolder,
              () async {
                await publishStorageFiles<void, ImageRecord>(
                  publish: (writeFile) async {
                    await writeFile(storageFileName, bytes);
                    final thumbnailBytes =
                        await ImageThumbnailLoader.generateThumbnail(bytes);
                    if (thumbnailBytes != null) {
                      await writeFile(imageThumbFileName(hash), thumbnailBytes);
                    }
                    await ImageManifest.addRecord(
                      ImageRecord(
                        name: displayName,
                        hash: hash,
                        format: format,
                        createdAt: DateTime.now(),
                        size: bytes.length,
                        folder: destinationFolder,
                      ),
                    );
                  },
                  loadRecords: ImageManifest.loadRecordsStrict,
                  isReferenced: (record, fileName) =>
                      record.hash == hash &&
                      (fileName == record.storageFileName ||
                          fileName == imageThumbFileName(record.hash)),
                  writeFile: ImageManifest.writeFile,
                  readFile: ImageManifest.readFile,
                  fileExists: ImageManifest.fileExists,
                  deleteFile: ImageManifest.deleteFile,
                );
              },
            );
          });
          return true;
        },
        refresh: () async {
          await ref.read(imageRecordsProvider.notifier).loadRecords();
          await ref.read(imageFolderListProvider.notifier).loadFolders();
        },
      );

      // Close loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      await ref.read(imageRecordsProvider.notifier).loadRecords();
      await ref.read(imageFolderListProvider.notifier).loadFolders();
      // 没有任何文件被导入（如全部跳过）时不显示成功提示
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.galleryImportImagesCount(count),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _isImporting = false;
    } catch (e) {
      _isImporting = false;
      if (mounted) {
        await refreshAfterPartialImport(count, () async {
          await ref.read(imageRecordsProvider.notifier).loadRecords();
          await ref.read(imageFolderListProvider.notifier).loadFolders();
        });
      }
      if (mounted && dialogShown) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.galleryImportFailed(e.toString()),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _exportFile(String id) async {
    final strings = AppLocalizations.of(context)!;
    try {
      final records = ref.read(imageRecordsProvider);
      final file = records.firstWhere((r) => r.id == id);

      final data = await ImageManifest.readFile(file.storagePath);
      if (data == null || data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.galleryFileReadFailed)),
          );
        }
        return;
      }

      final exportName = '${file.name}.${file.format}';
      final outputUri = await saveFileWithType(
        dialogTitle: strings.galleryExportImageTitle,
        fileName: exportName,
        extensions: [file.format],
        bytes: data,
        initialDirectory: SystemPickDirectories.pictures(),
      );
      if (outputUri != null && mounted) {
        final outputPath = filePickerLocationLabel(outputUri);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.galleryExportedTo(outputPath)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.galleryExportFailed(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 批量导出文件。返回用户最终使用的导出目录
  /// （用户取消目录选择或导出失败时返回 null；归档导出返回 ''）。
  Future<String?> _exportFiles(List<String> ids, String targetDirectory) async {
    final strings = AppLocalizations.of(context)!;
    try {
      // Native mobile uses the system save dialog for one visible-path ZIP.
      final useArchive = kIsWeb || SystemPickDirectories.isNativeMobile;
      String? outputDir;
      if (useArchive) {
        // Archive exports do not need an output directory.
        outputDir = '';
      } else {
        outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
        if (outputDir == null) {
          outputDir = await FilePicker.getDirectoryPath(
            dialogTitle: strings.galleryChooseExportDirectory,
            initialDirectory: SystemPickDirectories.pictures(),
          );
          if (outputDir == null) return null;
        }
      }

      if (!mounted) return null;

      final records = ref.read(imageRecordsProvider);
      var exportedCount = 0;
      final archiveFiles = <String, Uint8List>{};
      final exportPaths = <String>{};
      final selectedFiles = ids
          .map((id) => records.firstWhere((record) => record.id == id))
          .toList();
      final selectedPaths = selectedFiles
          .map(
            (file) => p.posix.join(file.folder, '${file.name}.${file.format}'),
          )
          .toList();
      validateUserVisibleExportPaths(files: selectedPaths);
      final resolvedOutputPaths = useArchive
          ? const <String>[]
          : await resolveNonClobberingExportPaths(
              files: selectedPaths,
              directory: outputDir,
              pathExists: (path) async =>
                  await FileSystemEntity.type(path, followLinks: false) !=
                  FileSystemEntityType.notFound,
            );

      for (var index = 0; index < selectedFiles.length; index++) {
        final file = selectedFiles[index];
        final data = await ImageManifest.readFile(file.storagePath);
        if (data == null) continue;

        final exportName = '${file.name}.${file.format}';
        final relativePath = p.posix.join(file.folder, exportName);
        if (!exportPaths.add(relativePath)) {
          throw StateError('导出路径重复: $relativePath');
        }

        if (useArchive) {
          archiveFiles[relativePath] = data;
        } else {
          final outputPath = resolvedOutputPaths[index];
          final fileDir = p.dirname(outputPath);
          await Directory(fileDir).create(recursive: true);
          await writeUserVisibleExportFile(outputPath, data);
        }
        exportedCount++;
      }

      if (useArchive && exportedCount > 0) {
        final saved = await saveFileWithType(
          dialogTitle: strings.galleryExportImageTitle,
          fileName: strings.galleryExportImageArchiveFileName,
          extensions: const ['zip'],
          bytes: encodeUserVisibleExportArchive(files: archiveFiles),
          initialDirectory: SystemPickDirectories.pictures(),
          mimeType: 'application/zip',
        );
        if (saved == null) return null;
      }

      // Web 端全部保存被取消时返回 null（与原生端取消目录选择一致，
      // 保持选择模式不退出）
      if (useArchive && exportedCount == 0) return null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.galleryExportedFilesCount(exportedCount)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return outputDir;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.galleryExportFailed(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// 批量导出文件夹（保留完整文件夹层级，含子文件夹内容）。
  /// 返回用户最终使用的导出目录（用户取消或失败时返回 null；归档导出返回 ''）。
  Future<String?> _exportFolders(
    List<String> names,
    String targetDirectory,
  ) async {
    final strings = AppLocalizations.of(context)!;
    // For each folder, export all files within preserving folder structure
    try {
      if (kIsWeb || SystemPickDirectories.isNativeMobile) {
        if (kIsWeb) {
          if (!mounted) return null;
          final action = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: ConstrainedText(
                strings.galleryFolderExportTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              content: Text(strings.galleryWebFolderExportInfo),
              actions: [
                TextButton(
                  key: const Key('fm_web_export_cancel_btn'),
                  onPressed: () => Navigator.pop(ctx),
                  child: ConstrainedText(
                    strings.actionCancel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton(
                  key: const Key('fm_web_export_individual_btn'),
                  onPressed: () => Navigator.pop(ctx, 'exportFiles'),
                  child: ConstrainedText(
                    strings.galleryDownloadZip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

          if (action != 'exportFiles' || !mounted) return null;
        }

        final records = ref.read(imageRecordsProvider);
        var exportedCount = 0;
        final archiveFiles = <String, Uint8List>{};
        final exportPaths = <String>{};
        for (final folderName in names) {
          final folderFiles = records
              .where(
                (r) =>
                    r.folder == folderName ||
                    r.folder.startsWith('$folderName/'),
              )
              .toList();
          for (final file in folderFiles) {
            final data = await ImageManifest.readFile(file.storagePath);
            if (data == null) continue;
            final exportName = '${file.name}.${file.format}';
            final relativePath = p.posix.join(file.folder, exportName);
            if (!exportPaths.add(relativePath)) {
              throw StateError('导出路径重复: $relativePath');
            }
            archiveFiles[relativePath] = data;
            exportedCount++;
          }
        }
        exportedCount = archiveFiles.length;
        // 全部保存被取消时返回 null（保持选择模式不退出），
        // 且不显示「已导出 0 个文件」提示
        final saved = await saveFileWithType(
          dialogTitle: strings.galleryExportImageFolderTitle,
          fileName: strings.galleryExportImageFolderArchiveFileName,
          extensions: const ['zip'],
          bytes: encodeUserVisibleExportArchive(
            files: archiveFiles,
            folders: {
              ...names,
              ...ref.read(imageFolderListProvider).where(
                    (folder) => names.any(
                      (name) => folder == name || folder.startsWith('$name/'),
                    ),
                  ),
            },
          ),
          initialDirectory: SystemPickDirectories.pictures(),
          mimeType: 'application/zip',
        );
        if (saved == null) return null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.galleryExportedFilesCount(exportedCount)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return '';
      }

      String? outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
      if (outputDir == null) {
        outputDir = await FilePicker.getDirectoryPath(
          dialogTitle: strings.galleryChooseExportDirectory,
          initialDirectory: SystemPickDirectories.pictures(),
        );
        if (outputDir == null) return null;
      }

      if (!mounted) return null;

      final records = ref.read(imageRecordsProvider);
      var exportedCount = 0;

      final selectedFolders = <String>{
        ...names,
        ...ref.read(imageFolderListProvider).where(
              (folder) => names.any(
                (name) => folder == name || folder.startsWith('$name/'),
              ),
            ),
      };
      final folderFiles = records
          .where(
            (record) => names.any(
              (name) =>
                  record.folder == name || record.folder.startsWith('$name/'),
            ),
          )
          .toList();
      final outputPaths = await resolveNonClobberingExportPaths(
        files: folderFiles.map(
          (file) => p.posix.join(file.folder, '${file.name}.${file.format}'),
        ),
        directory: outputDir,
        folders: selectedFolders,
        pathExists: (path) async =>
            await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.notFound,
      );
      validateUserVisibleExportPaths(
        files: folderFiles.map(
          (file) => p.posix.join(file.folder, '${file.name}.${file.format}'),
        ),
        folders: selectedFolders,
      );
      for (final folderName in selectedFolders) {
        await createUserVisibleExportDirectory(outputDir, folderName);
      }

      for (var i = 0; i < folderFiles.length; i++) {
        final file = folderFiles[i];
        final data = await ImageManifest.readFile(file.storagePath);
        if (data == null) continue;
        final outputPath = outputPaths[i];
        final fileDir = p.dirname(outputPath);
        await createUserVisibleExportDirectory(
          outputDir,
          p.relative(fileDir, from: outputDir),
        );
        await writeUserVisibleExportFile(outputPath, data);
        exportedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.galleryExportedFilesCount(exportedCount)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return outputDir;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.galleryExportFailed(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  Future<String?> _exportFolder(String folderName) async {
    // Same behavior as _exportFolders but for a single folder
    return _exportFolders([folderName], '');
  }

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(imageRecordsProvider);
    final folders = ref.watch(imageFolderListProvider);
    final sortConfig = ref.watch(imageSortConfigProvider);
    final viewMode = ref.watch(imageViewModeProvider);

    // Sort records
    final sortedRecords = List<ImageRecord>.from(records);
    sortedRecords.sort((a, b) {
      final cmp = compareFileRecords(a, b, sortConfig.field);
      return sortConfig.order == SortOrder.descending ? -cmp : cmp;
    });

    // Top action bar — available only in the root folder
    final topActionBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: ConstrainedText(
                AppLocalizations.of(context)!.galleryTakePhoto,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _importFromGallery,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: ConstrainedText(
                AppLocalizations.of(context)!.galleryImport,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    // Build file-thumbnail builder
    Widget fileThumbnailBuilder(ImageRecord file) {
      final canPreview = _supportedFormats.contains(file.format);
      if (canPreview) {
        final isSvg = file.format.toLowerCase() == 'svg';
        if (isSvg) {
          return FutureBuilder<Uint8List?>(
            future: ImageManifest.readFile(file.storagePath),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.isEmpty) {
                return buildFormatIcon(file.format);
              }
              return SvgPicture.memory(
                data,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholderBuilder: (_) => const SizedBox(),
              );
            },
          );
        }
        return FutureBuilder<Uint8List?>(
          // 统一走 ImageThumbnailLoader：内存 LRU 缓存避免网格反复读盘，
          // 缩略图缺失时按需生成并持久化，不再回退整张原图
          future: ImageThumbnailLoader.loadThumbnail(file),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null || data.isEmpty) {
              return buildFormatIcon(file.format);
            }
            return ExtendedImage.memory(
              data,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              // 缩略图按 ≤256px 解码（仅限宽：同时限宽又限高会把
              // 非正方形图片强行压成正方形再裁剪，导致缩略图变形）。
              // 生成端已保证缩略图尺寸受控，显示解码不会超预算。
              cacheWidth: _thumbDecodeSize,
              loadStateChanged: (state) {
                if (state.extendedImageLoadState == LoadState.failed) {
                  return buildFormatIcon(file.format);
                }
                return null;
              },
            );
          },
        );
      }
      return buildFormatIcon(file.format);
    }

    // FileManagerConfig
    final config = FileManagerConfig<ImageRecord>(
      title: AppLocalizations.of(context)!.galleryImagePageTitle,
      topActionBar: topActionBar,
      showThumbnailToggle: true,
      fileIconBuilder: (_) => const Icon(Icons.image, color: Colors.blueGrey),
      fileThumbnailBuilder: fileThumbnailBuilder,
      onFileTap: _showImagePreview,
      initialGridView: viewMode,
      onGridViewChanged: (v) =>
          ref.read(imageViewModeProvider.notifier).setViewMode(v),
      onCurrentFolderChanged: (f) {
        _currentFolder = f;
        ref.read(filesPageCurrentFolderProvider.notifier).state = f;
      },
      extraPopupMenuItems: (file) => [
        PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: Icon(Icons.file_download, size: 20),
            title: Text(AppLocalizations.of(context)!.galleryExportToLocal),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );

    final navigateToParentSignal = ref.watch(
      filesPageNavigateToParentSignalProvider,
    );
    final tabResetSignal = ref.watch(
      fileTabFolderResetSignalProvider(widget.tabIndex),
    );

    return FileManagerView<ImageRecord>(
      tabResetSignal: tabResetSignal,
      navigateToParentSignal: navigateToParentSignal,
      isActiveTab: widget.isActiveTab,
      sortedRecords: sortedRecords,
      folders: folders,
      sortConfig: sortConfig,
      config: config,
      invalidateRenameCache: ImageManifest.invalidateCache,
      onRefresh: () async {
        await ref.read(imageRecordsProvider.notifier).loadRecords();
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onRenameFile: (id, newName) async {
        final source = records.firstWhere((record) => record.id == id);
        final conflictMessage = AppLocalizations.of(context)!
            .fileManagerFileExists(source.format, newName);
        final renamed =
            await withGalleryVisibleNameLock(source.folder, () async {
          final currentRecords = await ImageManifest.loadRecordsStrict();
          final currentFolders = await ImageManifest.getAllFolders();
          final current = currentRecords.firstWhere(
            (record) => record.id == id,
          );
          if (current.folder != source.folder) return false;
          final candidatePath = current.folder.isEmpty
              ? '$newName.${current.format}'
              : '${current.folder}/$newName.${current.format}';
          if (galleryVisiblePathHasConflict(
            path: candidatePath,
            isFolder: false,
            records: currentRecords,
            folders: currentFolders,
            excludedRecordIds: {id},
          )) {
            return false;
          }
          await ref
              .read(imageRecordsProvider.notifier)
              .renameRecord(id, newName);
          return true;
        });
        if (!renamed) throw StateError(conflictMessage);
      },
      onMoveFile: (id, targetFolder) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerMoveNameConflict;
        final source = records.firstWhere((record) => record.id == id);
        final moved = await withGalleryVisibleNameLocks(
          [source.folder, targetFolder],
          () async {
            final currentRecords = await ImageManifest.loadRecordsStrict();
            final currentFolders = await ImageManifest.getAllFolders();
            final current = currentRecords.firstWhere(
              (record) => record.id == id,
            );
            if (current.folder != source.folder) return false;
            final candidatePath = targetFolder.isEmpty
                ? '${current.name}.${current.format}'
                : '$targetFolder/${current.name}.${current.format}';
            if (galleryVisiblePathHasConflict(
              path: candidatePath,
              isFolder: false,
              records: currentRecords,
              folders: currentFolders,
              excludedRecordIds: {id},
            )) {
              return false;
            }
            await ref
                .read(imageRecordsProvider.notifier)
                .moveRecord(id, targetFolder);
            return true;
          },
        );
        if (!moved) throw StateError(conflictMessage);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onCopyFile: (id, selectedFolder) async {
        await withGalleryVisibleNameLock(selectedFolder, () async {
          final currentRecords = await ImageManifest.loadRecordsStrict();
          final currentFolders = await ImageManifest.getAllFolders();
          final source = currentRecords.firstWhere((record) => record.id == id);
          final copyName = uniqueGalleryVisibleName(
            records: currentRecords,
            folder: selectedFolder,
            baseName: '${source.name}_副本',
            format: source.format,
            existingFolders: currentFolders,
          );
          await ImageManifest.addRecord(
            ImageRecord(
              name: copyName,
              hash: source.hash,
              format: source.format,
              createdAt: DateTime.now(),
              size: source.size,
              folder: selectedFolder,
            ),
          );
        });
        await ref.read(imageRecordsProvider.notifier).loadRecords();
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFile: (id) async {
        _invalidateThumbnails(records.where((r) => r.id == id));
        await ref.read(imageRecordsProvider.notifier).deleteRecord(id);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFiles: (ids) async {
        final idSet = ids.toSet();
        _invalidateThumbnails(records.where((r) => idSet.contains(r.id)));
        await ref.read(imageRecordsProvider.notifier).deleteRecords(ids);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolders: (names) async {
        for (final name in names) {
          _invalidateThumbnails(
            records.where(
              (r) => r.folder == name || r.folder.startsWith('$name/'),
            ),
          );
          await ref.read(imageRecordsProvider.notifier).deleteFolder(name);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onMoveFiles: (ids, targetFolder) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerMoveNameConflict;
        for (final id in ids) {
          final source = records.firstWhere((record) => record.id == id);
          final moved = await withGalleryVisibleNameLocks(
            [source.folder, targetFolder],
            () async {
              final currentRecords = await ImageManifest.loadRecordsStrict();
              final currentFolders = await ImageManifest.getAllFolders();
              final current = currentRecords.firstWhere(
                (record) => record.id == id,
              );
              if (current.folder != source.folder) return false;
              final candidatePath = targetFolder.isEmpty
                  ? '${current.name}.${current.format}'
                  : '$targetFolder/${current.name}.${current.format}';
              if (galleryVisiblePathHasConflict(
                path: candidatePath,
                isFolder: false,
                records: currentRecords,
                folders: currentFolders,
                excludedRecordIds: {id},
              )) {
                return false;
              }
              await ref
                  .read(imageRecordsProvider.notifier)
                  .moveRecord(id, targetFolder);
              return true;
            },
          );
          if (!moved) throw StateError(conflictMessage);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onMoveFolders: (names, targetFolder) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerFolderSelfConflict;
        for (final name in names) {
          final baseName = ImageManifest.getFolderBaseName(name);
          final targetParent = targetFolder.trim().replaceAll(
                RegExp(r'/+$'),
                '',
              );
          final destinationPath =
              targetParent.isEmpty ? baseName : '$targetParent/$baseName';
          final moved = await _mutateGalleryFolderPath(
            sourcePath: name,
            destinationPath: destinationPath,
            copy: false,
            mutate: () => ref
                .read(imageRecordsProvider.notifier)
                .moveFolder(name, targetFolder),
          );
          if (!moved) throw StateError(conflictMessage);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onExportFile: _exportFile,
      onExportFiles: _exportFiles,
      onExportFolders: _exportFolders,
      onExportFolder: (name) async {
        return _exportFolder(name);
      },
      onRenameFolder: (oldName, newName) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerTargetFolderConflict;
        final parent = ImageManifest.getParentFolderPath(oldName);
        final trimmedName = newName.trim();
        final destinationPath =
            parent.isEmpty ? trimmedName : '$parent/$trimmedName';
        final renamed = await _mutateGalleryFolderPath(
          sourcePath: oldName,
          destinationPath: destinationPath,
          copy: false,
          mutate: () => ref
              .read(imageRecordsProvider.notifier)
              .renameFolder(oldName, newName),
        );
        if (!renamed) throw StateError(conflictMessage);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onMoveFolder: (sourceName, targetParent) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerFolderSelfConflict;
        final baseName = ImageManifest.getFolderBaseName(sourceName);
        final targetParentClean = targetParent.trim().replaceAll(
              RegExp(r'/+$'),
              '',
            );
        final destinationPath = targetParentClean.isEmpty
            ? baseName
            : '$targetParentClean/$baseName';
        final moved = await _mutateGalleryFolderPath(
          sourcePath: sourceName,
          destinationPath: destinationPath,
          copy: false,
          mutate: () => ref
              .read(imageRecordsProvider.notifier)
              .moveFolder(sourceName, targetParent),
        );
        if (!moved) throw StateError(conflictMessage);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onCopyFolder: (sourceName, targetParent) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerFolderConflict;
        final baseName = ImageManifest.getFolderBaseName(sourceName);
        final targetParentClean = targetParent.trim().replaceAll(
              RegExp(r'/+$'),
              '',
            );
        final destinationPath = targetParentClean.isEmpty
            ? baseName
            : '$targetParentClean/$baseName';
        final copied = await _mutateGalleryFolderPath(
          sourcePath: sourceName,
          destinationPath: destinationPath,
          copy: true,
          mutate: () => ref
              .read(imageRecordsProvider.notifier)
              .copyFolder(sourceName, targetParent),
        );
        if (!copied) throw StateError(conflictMessage);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolder: (name) async {
        _invalidateThumbnails(
          records.where(
            (r) => r.folder == name || r.folder.startsWith('$name/'),
          ),
        );
        await ref.read(imageRecordsProvider.notifier).deleteFolder(name);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onCreateFolder: (name) async {
        final conflictMessage =
            AppLocalizations.of(context)!.fileManagerFolderConflict;
        final created = await createGalleryFolderIfNameAvailable(
          name,
          () => ref.read(imageRecordsProvider.notifier).createFolder(name),
        );
        if (!created) {
          throw StateError(conflictMessage);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onToggleSort: (field) {
        ref.read(imageSortConfigProvider.notifier).toggle(field);
      },
      manifestBridge: ManifestBridge(
        getFolderBaseName: ImageManifest.getFolderBaseName,
        getParentFolderPath: ImageManifest.getParentFolderPath,
        getChildFolderPaths: (parent, allPaths) =>
            ImageManifest.getChildFolderPaths(parent, allPaths.toList()),
        validateFolderName: ImageManifest.validateFolderName,
        getAllDescendantFolderPaths:
            FolderPathUtils.getAllDescendantFolderPaths,
      ),
    );
  }
}
