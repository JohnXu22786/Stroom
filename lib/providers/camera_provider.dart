import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// 相机状态，管理捕获或选择的图像路径列表
class CameraState {
  final List<String> imagePaths;

  const CameraState({this.imagePaths = const []});

  CameraState copyWith({List<String>? imagePaths}) {
    return CameraState(
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraState &&
          runtimeType == other.runtimeType &&
          imagePaths == other.imagePaths;

  @override
  int get hashCode => imagePaths.hashCode;
}

/// 相机状态通知器，管理图像路径
class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState()) {
    _init();
  }

  Future<void> _init() async {
    await loadSavedImages();
  }

  /// 添加新图像路径
  void addImage(String imagePath) {
    state = state.copyWith(imagePaths: [...state.imagePaths, imagePath]);
  }

  /// 移除指定索引的图像路径
  void removeImage(int index) {
    if (index >= 0 && index < state.imagePaths.length) {
      // 删除文件
      final filePath = state.imagePaths[index];
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        // 忽略文件删除错误，继续移除列表项
        print('删除文件失败: $e');
      }

      final newImagePaths = List<String>.from(state.imagePaths);
      newImagePaths.removeAt(index);
      state = state.copyWith(imagePaths: newImagePaths);
    }
  }

  /// 清空所有图像路径
  void clearImages() {
    // 删除所有文件
    for (final filePath in state.imagePaths) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        // 忽略文件删除错误，继续删除其他文件
        print('删除文件失败: $e');
      }
    }
    state = const CameraState();
  }

  /// 获取图像路径数量
  int get imageCount => state.imagePaths.length;

  /// 获取所有图像路径
  List<String> get allImages => state.imagePaths;

  /// 扫描已保存的图片并添加到列表
  Future<void> loadSavedImages() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final picturesDir = Directory(path.join(appDir.path, 'pictures'));
      if (await picturesDir.exists()) {
        final files = await picturesDir.list().toList();
        final fileList = <File>[];
        for (var file in files) {
          if (file is File && file.path.toLowerCase().endsWith('.jpg')) {
            fileList.add(file);
          }
        }
        // 按修改时间排序（最新的在前）
        fileList.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        final imagePaths = fileList.map((file) => file.path).toList();
        state = state.copyWith(imagePaths: imagePaths);
      }
    } catch (e) {
      // 忽略扫描错误，保持空列表
      print('扫描图片目录失败: $e');
    }
  }
}

/// 相机状态提供器
final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>(
  (ref) => CameraNotifier(),
);
