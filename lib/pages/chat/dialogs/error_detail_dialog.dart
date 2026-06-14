import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stroom/utils/data_sanitizer.dart';

/// Represents a selectable section within the error detail dialog.
class _ErrorSection {
  final String id;
  final String label;
  final IconData icon;
  final dynamic value;

  const _ErrorSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.value,
  });
}

/// Shows a dialog with detailed API error information.
///
/// Displays a list of available sections (Request URL, Request Headers,
/// Request Body, Status Code, Response Headers, Response Body, Error).
/// Tap any section to view its detail. Use the back button to return
/// to the section list.
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

class _ErrorDetailDialogContent extends StatefulWidget {
  final Map<String, dynamic>? rawRequest;
  final Map<String, dynamic>? rawResponse;

  const _ErrorDetailDialogContent({
    required this.rawRequest,
    required this.rawResponse,
  });

  @override
  State<_ErrorDetailDialogContent> createState() =>
      _ErrorDetailDialogContentState();
}

class _ErrorDetailDialogContentState
    extends State<_ErrorDetailDialogContent> {
  /// Currently selected section id, or null to show the section list.
  String? _selectedSectionId;

  /// Cached sections list, rebuilt when widget data changes.
  List<_ErrorSection>? _cachedSections;

  List<_ErrorSection> get _sections =>
      _cachedSections ??= _buildSections();

  @override
  void didUpdateWidget(covariant _ErrorDetailDialogContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawRequest != widget.rawRequest ||
        oldWidget.rawResponse != widget.rawResponse) {
      _cachedSections = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = _sections;

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
            // Header with back button when in detail view
            _buildHeader(context, isDark),
            // Body
            Flexible(
              child: sections.isEmpty
                  ? _buildEmptyState(isDark)
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
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the dialog header, optionally with a back button.
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
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
              tooltip: 'Back',
            ),
          if (_selectedSectionId != null) const SizedBox(width: 8),
          Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
          const SizedBox(width: 8),
          Text(
            _selectedSectionId != null
                ? _findSectionLabel(_selectedSectionId!)
                : 'Error Details',
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
    );
  }

  /// Returns the label for a given section id.
  String _findSectionLabel(String id) {
    for (final section in _sections) {
      if (section.id == id) return section.label;
    }
    return id;
  }

  /// Builds the list of available sections based on available data.
  List<_ErrorSection> _buildSections() {
    final sections = <_ErrorSection>[];
    final req = widget.rawRequest ?? {};
    final resp = widget.rawResponse ?? {};

    // Check if this is a network error (no HTTP response)
    final isNetworkError = resp.containsKey('error');

    // Request sections
    if (req.containsKey('url') && req['url'] != null) {
      sections.add(_ErrorSection(
        id: 'request_url',
        label: 'Request URL',
        icon: Icons.link,
        value: req['url'],
      ));
    }
    if (req.containsKey('headers') && req['headers'] != null) {
      sections.add(_ErrorSection(
        id: 'request_headers',
        label: 'Request Headers',
        icon: Icons.code,
        value: req['headers'],
      ));
    }
    if (req.containsKey('body') && req['body'] != null) {
      sections.add(_ErrorSection(
        id: 'request_body',
        label: 'Request Body',
        icon: Icons.code,
        value: req['body'],
      ));
    }

    if (isNetworkError) {
      // Network error — show a single Error section
      if (resp['error'] != null) {
        sections.add(_ErrorSection(
          id: 'error',
          label: 'Error',
          icon: Icons.error_outline,
          value: resp['error'],
        ));
      }
    } else {
      // Normal HTTP response sections
      if (resp.containsKey('statusCode') && resp['statusCode'] != null) {
        sections.add(_ErrorSection(
          id: 'status_code',
          label: 'Status Code',
          icon: Icons.info_outline,
          value: resp['statusCode'],
        ));
      }
      if (resp.containsKey('headers') && resp['headers'] != null) {
        sections.add(_ErrorSection(
          id: 'response_headers',
          label: 'Response Headers',
          icon: Icons.code,
          value: resp['headers'],
        ));
      }
      if (resp.containsKey('data') && resp['data'] != null) {
        sections.add(_ErrorSection(
          id: 'response_body',
          label: 'Response Body',
          icon: Icons.code,
          value: resp['data'],
        ));
      }
    }

    return sections;
  }

  /// Builds the empty state shown when no data is available.
  Widget _buildEmptyState(bool isDark) {
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
  Widget _buildListView(List<_ErrorSection> sections, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      itemCount: sections.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final section = sections[index];
        return ListTile(
          leading: Icon(section.icon, size: 20, color: Colors.red[700]),
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
        );
      },
    );
  }

  /// Builds the detail view for the selected section.
  Widget _buildDetailView(List<_ErrorSection> sections, bool isDark) {
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
              color: isDark ? Colors.black : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
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
