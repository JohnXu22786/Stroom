import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/utils/image_manifest.dart';

/// Shows a dialog for selecting images from the app's internal album.
///
/// Returns a list of (fileName, data) entries for the selected images,
/// or null if the user cancels.
Future<List<MapEntry<String, Uint8List>>?> showAppAlbumPickerDialog(
  BuildContext context,
) {
  return showDialog<List<MapEntry<String, Uint8List>>?>(
    context: context,
    builder: (ctx) => const _AppAlbumPickerDialog(),
  );
}

class _AppAlbumPickerDialog extends ConsumerStatefulWidget {
  const _AppAlbumPickerDialog();

  @override
  ConsumerState<_AppAlbumPickerDialog> createState() =>
      _AppAlbumPickerDialogState();
}

class _AppAlbumPickerDialogState
    extends ConsumerState<_AppAlbumPickerDialog> {
  List<ImageRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      await ref.read(imageRecordsProvider.notifier).loadRecords();
      final records = ref.read(imageRecordsProvider);
      if (mounted) {
        setState(() {
          _records = List<ImageRecord>.from(records);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectImage(ImageRecord record) async {
    final data = await ImageManifest.readFile(record.storagePath);
    if (data == null || data.isEmpty || !context.mounted) return;

    Navigator.of(context).pop([
      MapEntry('${record.name}.${record.format}', data),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '应用内相册',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(null),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Content ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_library_outlined,
                                    size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  '暂无图片',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            return _ImageTile(
                              record: record,
                              onTap: () => _selectImage(record),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatefulWidget {
  final ImageRecord record;
  final VoidCallback onTap;

  const _ImageTile({
    required this.record,
    required this.onTap,
  });

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  Future<Uint8List?>? _imageDataFuture;

  @override
  void initState() {
    super.initState();
    _imageDataFuture = _loadImageData();
  }

  @override
  void didUpdateWidget(covariant _ImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.hash != oldWidget.record.hash) {
      _imageDataFuture = _loadImageData();
    }
  }

  Future<Uint8List?> _loadImageData() async {
    // Try thumbnail first for faster loading
    final thumb = await ImageManifest.readFile('${widget.record.hash}_thumb.png');
    if (thumb != null) return thumb;
    return ImageManifest.readFile(widget.record.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _imageDataFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 32),
                ),
              );
            }
            return Image.memory(
              data,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
