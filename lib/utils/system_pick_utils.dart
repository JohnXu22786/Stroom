import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'system_gallery_picker.dart';

/// 系统默认目录类型。
enum SystemFolder { documents, music, pictures, videos }

/// 相册媒体类型（用于 [pickGalleryMedia]）。
enum GalleryMediaKind { image, video }

/// 系统默认目录（桌面端）：为系统文件选择器指定初始目录，让导入/导出
/// 对话框默认打开到对应的系统文件夹（文档 / 音乐 / 图片 / 视频）。
///
/// 平台差异：
/// - **Android / iOS**：系统选择器（SAF / UIDocumentPicker）不支持指定
///   初始目录，相关方法一律返回 `null`；图片/视频由 [pickGalleryMedia]
///   打开 WeChat 风格的应用内相册。
/// - **Web**：浏览器文件选择器无法指定初始目录，返回 `null`。
/// - **Windows / macOS / Linux**：返回对应的系统目录；目录不存在时回退
///   到用户主目录，比让选择器落在任意历史位置更可预期。
class SystemPickDirectories {
  SystemPickDirectories._();

  /// 当前是否为移动端（Android / iOS）。
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 当前是否为桌面端（Windows / macOS / Linux）。
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// 文档目录（Windows / macOS / Linux：Documents）。
  static String? documents() => _resolveCurrent(SystemFolder.documents);

  /// 音乐/音频目录（Windows / macOS / Linux：Music）。
  static String? music() => _resolveCurrent(SystemFolder.music);

  /// 图片目录（Windows / macOS / Linux：Pictures）。
  static String? pictures() => _resolveCurrent(SystemFolder.pictures);

  /// 视频目录（Windows / Linux：Videos；macOS：Movies —— macOS 没有
  /// Videos 目录，视频默认在 Movies）。
  static String? videos() => _resolveCurrent(SystemFolder.videos);

  /// 用户主目录（Windows：USERPROFILE；macOS / Linux：HOME）。
  static String? get _home {
    if (kIsWeb) return null;
    if (Platform.isWindows) return Platform.environment['USERPROFILE'];
    return Platform.environment['HOME'];
  }

  static String? _resolveCurrent(SystemFolder folder) {
    final name = folderName(defaultTargetPlatform, folder);
    if (name == null) return null;
    final home = _home;
    if (home == null || home.isEmpty) return null;
    return resolvePath(home, name);
  }

  /// 纯逻辑：平台差异映射 —— 返回对应系统目录的一级文件夹名；
  /// 移动端不支持指定初始目录，返回 `null`。
  @visibleForTesting
  static String? folderName(TargetPlatform platform, SystemFolder folder) {
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return null;
    }
    switch (folder) {
      case SystemFolder.documents:
        return 'Documents';
      case SystemFolder.music:
        return 'Music';
      case SystemFolder.pictures:
        return 'Pictures';
      case SystemFolder.videos:
        // macOS 视频目录是 Movies（其余平台是 Videos）
        return platform == TargetPlatform.macOS ? 'Movies' : 'Videos';
    }
  }

  /// 纯逻辑：目录名 + 主目录 → 实际路径。
  /// 目标目录存在时返回它，否则回退到主目录；主目录无效时返回 `null`。
  @visibleForTesting
  static String? resolvePath(String home, String folderName) {
    if (home.isEmpty || folderName.isEmpty) return null;
    for (final candidate in [p.join(home, folderName), home]) {
      try {
        if (Directory(candidate).existsSync()) return candidate;
      } catch (_) {
        // 非法路径（如含 NUL 字符）按不存在处理
      }
    }
    return null;
  }
}

/// 从相册选择图片/视频（多选）。
///
/// - **Android / iOS**：使用 WeChat 风格的应用内相册，允许拖动连续选择；
///   拒绝权限时提供前往系统设置的入口，受限照片授权由选择器自身呈现。
/// - **桌面端 / Web**：保持原有文件选择器行为；Web（包括手机浏览器）由
///   浏览器打开文件输入界面，因为 WeChat 组件没有 Web 实现。
///
/// 用户取消时返回空列表。[maxWidth] / [maxHeight] / [imageQuality] 在
/// 原生移动端图片路径中用于生成 OCR 尺寸的 JPEG；其他平台保持原有行为。
Future<List<XFile>> pickGalleryMedia(
  BuildContext context,
  GalleryMediaKind kind, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) async {
  if (SystemPickDirectories.isMobile) {
    return pickNativeGalleryMedia(
      context,
      isVideo: kind == GalleryMediaKind.video,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
  final result = await FilePicker.pickFiles(
    type: kind == GalleryMediaKind.image ? FileType.image : FileType.video,
    allowMultiple: true,
    withData: true,
    initialDirectory: kind == GalleryMediaKind.image
        ? SystemPickDirectories.pictures()
        : SystemPickDirectories.videos(),
  );
  return [
    for (final file in result?.files ?? [])
      // 保留原始路径：部分调用方（如 OCR）依赖 file.path 识别格式
      XFile.fromData(
        file.bytes ?? Uint8List(0),
        name: file.name,
        path: file.path,
      ),
  ];
}
