import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  CameraNotifier() : super(const CameraState());

  /// 添加新图像路径
  void addImage(String imagePath) {
    state = state.copyWith(imagePaths: [...state.imagePaths, imagePath]);
  }

  /// 移除指定索引的图像路径
  void removeImage(int index) {
    if (index >= 0 && index < state.imagePaths.length) {
      final newImagePaths = List<String>.from(state.imagePaths);
      newImagePaths.removeAt(index);
      state = state.copyWith(imagePaths: newImagePaths);
    }
  }

  /// 清空所有图像路径
  void clearImages() {
    state = const CameraState();
  }

  /// 获取图像路径数量
  int get imageCount => state.imagePaths.length;

  /// 获取所有图像路径
  List<String> get allImages => state.imagePaths;
}

/// 相机状态提供器
final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>(
  (ref) => CameraNotifier(),
);
