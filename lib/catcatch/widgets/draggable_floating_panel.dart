import 'dart:math';
import 'package:flutter/material.dart';

// =============================================================================
// Draggable Floating Panel
// =============================================================================

/// A draggable floating overlay panel that displays detected media URLs
/// from the WebView sniffing layer.
///
/// Features:
/// - Drag anywhere on screen via GestureDetector
/// - ListView of detected URLs with media type icons
/// - Selection and "Confirm Capture" action
/// - Minimize/expand toggle
/// - Close button
///
/// This widget is designed to be placed inside a [Stack] above a [WebView].
class DraggableFloatingPanel extends StatefulWidget {
  /// The list of detected media URLs to display.
  final List<String> detectedUrls;

  /// Callback when user confirms capturing a URL.
  /// Returns the selected URL.
  final ValueChanged<String> onConfirmCapture;

  /// Optional callback when the panel is closed.
  final VoidCallback? onClose;

  /// Optional initial position offset.
  final Offset? initialPosition;

  const DraggableFloatingPanel({
    super.key,
    required this.detectedUrls,
    required this.onConfirmCapture,
    this.onClose,
    this.initialPosition,
  });

  @override
  State<DraggableFloatingPanel> createState() => _DraggableFloatingPanelState();
}

class _DraggableFloatingPanelState extends State<DraggableFloatingPanel> {
  double _panelWidth = 280;
  double _panelMaxHeight = 320;
  double _left = 0;
  double _top = 0;
  bool _minimized = false;
  bool _visible = true;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _left = widget.initialPosition!.dx;
      _top = widget.initialPosition!.dy;
    }
  }

  @override
  void didUpdateWidget(DraggableFloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection if URLs changed
    if (widget.detectedUrls != oldWidget.detectedUrls) {
      if (_selectedIndex != null &&
          _selectedIndex! >= widget.detectedUrls.length) {
        _selectedIndex = null;
      }
    }
  }

  void _close() {
    setState(() => _visible = false);
    widget.onClose?.call();
  }

  void _toggleMinimize() {
    setState(() => _minimized = !_minimized);
  }

  String _extractExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final dot = path.lastIndexOf('.');
      if (dot < 0) return '';
      return path.substring(dot + 1).toLowerCase();
    } catch (_) {
      return '';
    }
  }

  IconData _iconForUrl(String url) {
    final ext = _extractExtension(url);
    switch (ext) {
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'wma':
      case 'opus':
      case 'weba':
        return Icons.audio_file;
      case 'm3u8':
      case 'm3u':
      case 'mpd':
        return Icons.playlist_play;
      default:
        return Icons.videocam;
    }
  }

  Color _colorForUrl(String url) {
    final ext = _extractExtension(url);
    switch (ext) {
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Colors.orange;
      case 'm3u8':
      case 'm3u':
      case 'mpd':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _shortUrl(String url, {int maxLen = 45}) {
    if (url.length <= maxLen) return url;
    return '${url.substring(0, maxLen ~/ 2)}...${url.substring(url.length - maxLen ~/ 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // Note: This widget returns the panel content directly (without Positioned).
    // The parent should wrap it in a Positioned or Stack as needed.
    // Tests can place it directly in the widget tree without a Stack.
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _left = max(0, _left + details.delta.dx);
          _top = max(0, _top + details.delta.dy);
        });
      },
      child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHigh,
          surfaceTintColor: colorScheme.primaryContainer,
          child: Container(
            width: _panelWidth,
            constraints: BoxConstraints(maxHeight: _panelMaxHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Drag handle / Header ---
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pets,
                        size: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '猫抓嗅探',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const Spacer(),
                      // Count badge
                      if (widget.detectedUrls.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.detectedUrls.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      // Minimize
                      InkWell(
                        onTap: _toggleMinimize,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _minimized
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      // Close
                      InkWell(
                        onTap: _close,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Content ---
                if (!_minimized)
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // URL list
                        Flexible(
                          child: widget.detectedUrls.isEmpty
                              ? _buildEmptyState(colorScheme)
                              : _buildUrlList(colorScheme),
                        ),
                        // Action bar
                        if (widget.detectedUrls.isNotEmpty)
                          _buildActionBar(colorScheme),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radar,
            size: 32,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无检测到媒体资源',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '等待网络请求...',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlList(ColorScheme colorScheme) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.detectedUrls.length,
      itemBuilder: (context, index) {
        final url = widget.detectedUrls[index];
        final isSelected = _selectedIndex == index;

        return InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _iconForUrl(url),
                  size: 16,
                  color: _colorForUrl(url),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shortUrl(url),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _extractExtension(url).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          color: _colorForUrl(url),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedIndex != null
                  ? '已选: ${_extractExtension(widget.detectedUrls[_selectedIndex!]).toUpperCase()}'
                  : '选择资源后确认',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: FilledButton.icon(
              onPressed: _selectedIndex != null
                  ? () {
                      widget.onConfirmCapture(
                        widget.detectedUrls[_selectedIndex!],
                      );
                    }
                  : null,
              icon: const Icon(Icons.check, size: 14),
              label: const Text(
                '确认捕获',
                style: TextStyle(fontSize: 11),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
