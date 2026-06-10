import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stroom/utils/data_sanitizer.dart';

/// Shows a dialog with error details including raw request/response data.
void showErrorDetailDialog({
  required BuildContext context,
  required Map<String, dynamic>? rawRequest,
  required Map<String, dynamic>? rawResponse,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _ErrorDetailDialogContent(
      rawRequest: rawRequest,
      rawResponse: rawResponse,
    ),
  );
}

class _ErrorDetailDialogContent extends StatelessWidget {
  final Map<String, dynamic>? rawRequest;
  final Map<String, dynamic>? rawResponse;

  const _ErrorDetailDialogContent({
    required this.rawRequest,
    required this.rawResponse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Text(
                    '错误详情',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: rawRequest != null || rawResponse != null
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      children: [
                        if (rawRequest != null) ...[
                          _buildJsonBlock(
                            context,
                            '请求 (Request)',
                            rawRequest,
                            isDark,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (rawResponse != null)
                          _buildJsonBlock(
                            context,
                            '响应 (Response)',
                            rawResponse,
                            isDark,
                          ),
                      ],
                    )
                  : const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '无详细数据',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
            ),
            // Close button
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonBlock(
    BuildContext context,
    String label,
    dynamic data,
    bool isDark,
  ) {
    final encoder = const JsonEncoder.withIndent('  ');
    final sanitized = DataSanitizer.sanitizeForDisplay(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            encoder.convert(sanitized),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }
}
