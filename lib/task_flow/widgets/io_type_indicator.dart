import 'package:flutter/material.dart';
import '../models/io_type.dart';

/// Displays an [IOType] with an icon and label in a chip-like container.
///
/// Used in the flow builder to show the input/output types of each block.
/// The [type] parameter determines the icon and color shown.
class IOTypeIndicator extends StatelessWidget {
  final IOType type;
  final bool isInput;

  const IOTypeIndicator({
    super.key,
    required this.type,
    this.isInput = true,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _typeData(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isInput ? '输入: ${type.label}' : '输出: ${type.label}',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _typeData(IOType type) {
    switch (type) {
      case IOType.text:
        return (Icons.text_fields, const Color(0xFF2196F3));
      case IOType.audio:
        return (Icons.audiotrack, const Color(0xFF9C27B0));
      case IOType.video:
        return (Icons.videocam, const Color(0xFF4CAF50));
      case IOType.image:
        return (Icons.image, const Color(0xFFFF9800));
      case IOType.url:
        return (Icons.link, const Color(0xFF00BCD4));
      case IOType.file:
        return (Icons.insert_drive_file, const Color(0xFF607D8B));
      case IOType.any:
        return (Icons.extension, Colors.grey);
    }
  }
}
