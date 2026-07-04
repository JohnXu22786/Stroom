import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stroom/utils/data_sanitizer.dart';

/// Represents a selectable data section within the detail dialog.
class _DataSection {
  final String id;
  final String label;
  final IconData icon;
  final dynamic value;

  const _DataSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.value,
  });
}

/// Shows a unified dialog with 6 common data sections:
/// Request URL, Request Headers, Request Body,
/// Status Code, Response Headers, Response Body.
///
/// Tap any section to view its detail. Use the back button to return
/// to the section list. The panel is visually uniform regardless of
/// whether the data is from an error or normal request.
void showDataDetailDialog({
  required BuildContext context,
  required Map<String, dynamic>? rawRequest,
  required Map<String, dynamic>? rawResponse,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _DataDetailDialogContent(
      rawRequest: rawRequest,
      rawResponse: rawResponse,
    ),
  );
}

class _DataDetailDialogContent extends StatefulWidget {
  final Map<String, dynamic>? rawRequest;
  final Map<String, dynamic>? rawResponse;

  const _DataDetailDialogContent({
    required this.rawRequest,
    required this.rawResponse,
  });

  @override
  State<_DataDetailDialogContent> createState() =>
      _DataDetailDialogContentState();
}

class _DataDetailDialogContentState extends State<_DataDetailDialogContent> {
  /// Currently selected section id, or null to show the section list.
  String? _selectedSectionId;

  List<_DataSection> get _sections => _buildSections();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = _sections;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          color: isDark ? Colors.grey[850] : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(context, isDark),
              // Body
              Flexible(
                child: sections.isEmpty
                    ? _buildEmptyState()
                    : _selectedSectionId != null
                        ? _buildDetailView(sections, isDark)
                        : _buildListView(sections, isDark),
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
      ),
    );
  }

  /// Builds the dialog header.
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (_selectedSectionId != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () {
                setState(() {
                  _selectedSectionId = null;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '返回',
            ),
          if (_selectedSectionId != null) const SizedBox(width: 8),
          const Icon(
            Icons.info_outline,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _selectedSectionId != null
                ? _findSectionLabel(_selectedSectionId!)
                : '数据详情',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
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
    );
  }

  /// Returns the label for a given section id.
  String _findSectionLabel(String id) {
    for (final section in _sections) {
      if (section.id == id) return section.label;
    }
    return id;
  }

  /// Builds the list of 6 common sections based on available data.
  List<_DataSection> _buildSections() {
    final sections = <_DataSection>[];
    final req = widget.rawRequest ?? {};
    final resp = widget.rawResponse ?? {};

    // 1. Request URL
    if (req.containsKey('url') && req['url'] != null) {
      sections.add(_DataSection(
        id: 'request_url',
        label: 'Request URL',
        icon: Icons.link,
        value: req['url'],
      ));
    }

    // 2. Request Headers
    if (req.containsKey('headers') && req['headers'] != null) {
      sections.add(_DataSection(
        id: 'request_headers',
        label: 'Request Headers',
        icon: Icons.code,
        value: req['headers'],
      ));
    }

    // 3. Request Body
    if (req.containsKey('body') && req['body'] != null) {
      sections.add(_DataSection(
        id: 'request_body',
        label: 'Request Body',
        icon: Icons.code,
        value: req['body'],
      ));
    }

    // 4. Status Code
    if (resp.containsKey('statusCode') && resp['statusCode'] != null) {
      sections.add(_DataSection(
        id: 'status_code',
        label: 'Status Code',
        icon: Icons.info_outline,
        value: resp['statusCode'],
      ));
    }

    // 5. Response Headers
    if (resp.containsKey('headers') && resp['headers'] != null) {
      sections.add(_DataSection(
        id: 'response_headers',
        label: 'Response Headers',
        icon: Icons.code,
        value: resp['headers'],
      ));
    }

    // 6. Response Body — check both 'data' (HTTP success) and 'error' (network error)
    if (resp.containsKey('data') && resp['data'] != null) {
      sections.add(_DataSection(
        id: 'response_body',
        label: 'Response Body',
        icon: Icons.code,
        value: resp['data'],
      ));
    } else if (resp.containsKey('error') && resp['error'] != null) {
      sections.add(_DataSection(
        id: 'response_body',
        label: 'Response Body',
        icon: Icons.code,
        value: resp['error'],
      ));
    }

    return sections;
  }

  /// Builds the empty state shown when no data is available.
  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'No detail data available',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  /// Builds the list view showing all available sections.
  Widget _buildListView(List<_DataSection> sections, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      itemCount: sections.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final section = sections[index];
        return Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Icon(section.icon, size: 20),
            title: Text(
              section.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            onTap: () {
              setState(() {
                _selectedSectionId = section.id;
              });
            },
          ),
        );
      },
    );
  }

  /// Builds the detail view for the selected section.
  Widget _buildDetailView(List<_DataSection> sections, bool isDark) {
    final section = sections.firstWhere(
      (s) => s.id == _selectedSectionId,
      orElse: () => sections.first,
    );

    final encoder = const JsonEncoder.withIndent('  ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section label
          Text(
            section.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          // Value display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildValueDisplay(section.value, encoder, isDark),
          ),
        ],
      ),
    );
  }

  /// Builds the display widget for a section value.
  Widget _buildValueDisplay(
    dynamic value,
    JsonEncoder encoder,
    bool isDark,
  ) {
    if (value is String) {
      return SelectableText(
        value,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      );
    }

    // For Map or List values, format as JSON
    final sanitized = DataSanitizer.sanitizeForDisplay(value);
    return SelectableText(
      encoder.convert(sanitized),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? Colors.grey[300] : Colors.grey[800],
      ),
    );
  }
}
