import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stroom/utils/data_sanitizer.dart';

/// Shows a dialog with JSON request/response data inspection.
void showJsonInspectionDialog({
  required BuildContext context,
  required Map<String, dynamic>? rawRequest,
  required Map<String, dynamic>? rawResponse,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: DefaultTabController(
        length: 2,
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Text(
                      'JSON 审查',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Request'),
                  Tab(text: 'Response'),
                ],
              ),
              Flexible(
                child: TabBarView(
                  children: [
                    _JsonContent(
                      data: rawRequest,
                      label: '无请求数据',
                    ),
                    _JsonContent(
                      data: rawResponse,
                      label: '无响应数据',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _JsonContent extends StatelessWidget {
  final Map<String, dynamic>? data;
  final String label;

  const _JsonContent({required this.data, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final encoder = const JsonEncoder.withIndent('  ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        data != null
            ? encoder.convert(DataSanitizer.sanitizeForDisplay(data))
            : label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    );
  }
}
