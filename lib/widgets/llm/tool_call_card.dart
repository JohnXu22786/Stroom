import 'package:flutter/material.dart';
import '../../models/tool_call.dart';

class ToolCallCard extends StatelessWidget {
  final ToolCallData data;

  const ToolCallCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    final statusColor = switch (data.status) {
      ToolCallStatus.running => Colors.orange,
      ToolCallStatus.completed => Colors.green,
      ToolCallStatus.error => Colors.red,
      ToolCallStatus.pending => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.troubleshoot, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                data.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (data.status == ToolCallStatus.running)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          if (data.arguments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _formatArgs(data.arguments),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          if (data.result != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor.withOpacity(0.5)),
              ),
              child: Text(
                data.result!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: data.status == ToolCallStatus.error
                      ? Colors.red
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatArgs(Map<String, dynamic> args) {
    return args.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
}
