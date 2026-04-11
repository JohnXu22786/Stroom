import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/camera_provider.dart';

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraProvider);
    final imagePaths = cameraState.imagePaths;

    return Scaffold(
      appBar: AppBar(
        title: const Text('相册'),
        actions: [
          if (imagePaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _showClearConfirmationDialog(context, ref);
              },
              tooltip: '清空所有图片',
            ),
        ],
      ),
      body: imagePaths.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '暂无图片',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '使用相机拍摄或从相册导入图片',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: imagePaths.length,
              itemBuilder: (context, index) {
                final imagePath = imagePaths[index];
                return GestureDetector(
                  onTap: () {
                    _showImageDialog(context, imagePath, index, ref);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              _deleteImage(context, index, ref);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showImageDialog(
    BuildContext context,
    String imagePath,
    int index,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteImage(BuildContext context, int index, WidgetRef ref) {
    ref.read(cameraProvider.notifier).removeImage(index);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('图片已删除'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showClearConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空相册'),
          content: const Text('确定要删除所有图片吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                ref.read(cameraProvider.notifier).clearImages();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('所有图片已清空'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
  }
}
