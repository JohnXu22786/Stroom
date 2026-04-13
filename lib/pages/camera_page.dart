import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../providers/camera_provider.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = false;
  double _zoomLevel = 1.0;
  FlashMode _flashMode = FlashMode.off;
  List<CameraDescription>? _cameras;
  bool _isPageVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 延迟初始化，确保页面已构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  @override
  void didUpdateWidget(CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当widget更新时，如果相机未初始化则重新初始化
    if (!_isCameraInitialized) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 应用恢复时重新初始化相机
      _reinitializeCameraIfNeeded();
    } else if (state == AppLifecycleState.paused) {
      // 应用暂停时释放相机
      _disposeCamera();
    }
  }

  void _disposeCamera() {
    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    setState(() {
      _isCameraInitialized = false;
    });
  }

  Future<void> _reinitializeCameraIfNeeded() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

      // 选择前置或后置摄像头
      final camera = _isFrontCamera
          ? _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras!.first,
            )
          : _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras!.first,
            );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
      _showErrorSnackBar('无法初始化相机: $e');
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller == null) return;

    try {
      // 拍照
      final image = await _controller!.takePicture();

      // 保存图片到应用支持目录（系统默认的应用数据存储路径）
      final appDir = await getApplicationSupportDirectory();
      final picturesDir = Directory(path.join(appDir.path, 'pictures'));
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final fileName = path.join(
        picturesDir.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final savedImage = await File(image.path).copy(fileName);

      // 更新状态提供器
      ref.read(cameraProvider.notifier).addImage(savedImage.path);

      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片已保存'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('拍照失败: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // 保存图片到应用支持目录（系统默认的应用数据存储路径）
        final appDir = await getApplicationSupportDirectory();
        final picturesDir = Directory(path.join(appDir.path, 'pictures'));
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }

        final fileName = path.join(
          picturesDir.path,
          'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final savedImage = await File(pickedFile.path).copy(fileName);

        // 更新状态提供器
        ref.read(cameraProvider.notifier).addImage(savedImage.path);

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片已导入'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('从相册选择图片失败: $e');
    }
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) {
      _showErrorSnackBar('没有可用的前置摄像头');
      return;
    }

    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });

    // 重新初始化相机
    _controller?.dispose();
    _initializeCamera();
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      if (_flashMode == FlashMode.off) {
        _flashMode = FlashMode.auto;
      } else if (_flashMode == FlashMode.auto) {
        _flashMode = FlashMode.always;
      } else if (_flashMode == FlashMode.always) {
        _flashMode = FlashMode.torch;
      } else {
        _flashMode = FlashMode.off;
      }
    });

    _controller!.setFlashMode(_flashMode);
  }

  void _zoomIn() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _zoomLevel = (_zoomLevel + 0.5).clamp(1.0, 5.0);
    });
    _controller!.setZoomLevel(_zoomLevel);
  }

  void _zoomOut() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _zoomLevel = (_zoomLevel - 0.5).clamp(1.0, 5.0);
    });
    _controller!.setZoomLevel(_zoomLevel);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                '正在初始化相机...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return CameraPreview(_controller!);
  }

  Widget _buildFlashIcon() {
    IconData icon;
    Color color;

    switch (_flashMode) {
      case FlashMode.off:
        icon = Icons.flash_off;
        color = Colors.white;
        break;
      case FlashMode.auto:
        icon = Icons.flash_auto;
        color = Colors.amber;
        break;
      case FlashMode.always:
        icon = Icons.flash_on;
        color = Colors.yellow;
        break;
      case FlashMode.torch:
        icon = Icons.highlight;
        color = Colors.yellow;
        break;
      default:
        icon = Icons.flash_off;
        color = Colors.white;
    }

    return Icon(icon, color: color, size: 28);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用父类的build方法
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 相机预览
            Positioned.fill(
              child: _buildCameraPreview(),
            ),

            // 顶部控制栏
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 闪光灯控制
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: _buildFlashIcon(),
                    color: Colors.white,
                  ),

                  // 缩放指示器
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 摄像头切换
                  IconButton(
                    onPressed: _toggleCamera,
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  ),
                ],
              ),
            ),

            // 底部控制栏
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // 缩放控制
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _zoomOut,
                        icon: const Icon(Icons.zoom_out, color: Colors.white),
                      ),
                      const SizedBox(width: 40),
                      IconButton(
                        onPressed: _zoomIn,
                        icon: const Icon(Icons.zoom_in, color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 拍照和相册按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 相册按钮
                      FloatingActionButton(
                        onPressed: _pickImageFromGallery,
                        backgroundColor: Colors.white24,
                        child: const Icon(Icons.photo_library, color: Colors.white),
                      ),

                      // 拍照按钮
                      FloatingActionButton(
                        onPressed: _takePicture,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.camera_alt, color: Colors.black),
                      ),

                      // 占位按钮，保持对称
                      const FloatingActionButton(
                        onPressed: null,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: Icon(Icons.circle, color: Colors.transparent),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 相机不可用时显示的消息
            if (!_isCameraInitialized && _controller == null)
              const Positioned.fill(
                child: Center(
                  child: Text(
                    '无法访问相机\n请检查权限设置',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
