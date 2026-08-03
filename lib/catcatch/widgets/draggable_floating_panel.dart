import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/audio_utils.dart';

// =============================================================================
// Draggable Floating Panel
// =============================================================================

/// Content widget for the draggable floating overlay panel.
///
/// Renders the panel UI (header with drag handle, URL list, action bar)
/// WITHOUT managing its own position or creating a full-screen compositing
/// layer. The parent widget must:
/// 1. Place this widget inside a [Stack] using [Positioned] for screen
///    positioning.
/// 2. Pass the [onDragUpdate] callback to handle drag-to-reposition.
///
/// The panel does NOT use [IgnorePointer] + [SizedBox.expand()] internally
/// because that creates a full-screen compositing layer that can interfere
/// with platform view (InAppWebView) event routing. Instead, the panel
/// renders only within its natural content bounds.
///
/// Features:
/// - Drag-to-reposition via [onDragUpdate] callback
/// - ListView of detected URLs with media type icons
/// - Selection and "Confirm Capture" action
/// - Minimize/expand toggle
/// - Close button
///
/// Visibility is controlled externally via [visible]. The panel shows when
/// [visible] is true and hides when false.
class DraggableFloatingPanel extends StatefulWidget {
  /// Fixed panel width, used by the parent to clamp the drag offset.
  static const double panelWidth = 280;

  /// The list of detected media URLs to display.
  final List<String> detectedUrls;

  /// Callback when user confirms capturing a URL.
  final ValueChanged<String> onConfirmCapture;

  /// Callback when the panel is closed.
  final VoidCallback? onClose;

  /// Callback for drag-to-reposition. Receives the drag [Delta] from
  /// [GestureDetector.onPanUpdate]. The parent should update its position
  /// state and call [setState].
  final ValueChanged<Offset>? onDragUpdate;

  /// Whether the panel is visible. Shows when true, hides when false.
  final bool visible;

  /// Bumped by the parent whenever the detected-URL list is reset for a new
  /// page. The panel drops its current selection when this changes, so a
  /// selection from the previous page can never capture a URL from the new
  /// one — even when both pages detect the same number of URLs.
  final int detectionEpoch;

  const DraggableFloatingPanel({
    super.key,
    required this.detectedUrls,
    required this.onConfirmCapture,
    this.onClose,
    this.onDragUpdate,
    this.visible = true,
    this.detectionEpoch = 0,
  });

  @override
  State<DraggableFloatingPanel> createState() => _DraggableFloatingPanelState();
}

class _DraggableFloatingPanelState extends State<DraggableFloatingPanel> {
  // Single source of truth: the public [DraggableFloatingPanel.panelWidth]
  // that the parent uses to clamp the drag offset.
  static const double _panelMaxHeight = 320;
  bool _minimized = false;
  int? _selectedIndex;

  @override
  void didUpdateWidget(DraggableFloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent mutates one list instance in place (clear + add on
    // navigation), so identity AND length comparisons between builds can
    // never detect the change — always keep the selection within bounds.
    // The action bar additionally guards its own index access.
    if (_selectedIndex != null &&
        _selectedIndex! >= widget.detectedUrls.length) {
      _selectedIndex = null;
    }
    // Drop the selection when the parent starts a new detection epoch
    // (new page), so a stale selection can never capture the wrong URL.
    if (widget.detectionEpoch != oldWidget.detectionEpoch) {
      _selectedIndex = null;
    }
    // Reset state when panel transitions from hidden to visible
    if (widget.visible && !oldWidget.visible) {
      setState(() {
        _selectedIndex = null;
        _minimized = false;
      });
    }
  }

  void _toggleMinimize() {
    setState(() => _minimized = !_minimized);
  }

  String _extractExtension(String url) {
    try {
      final uri = Uri.parse(url);
      // blob:/data: URLs have an opaque remainder, not a real path with a
      // file extension — don't parse a garbage "extension" out of them.
      if (!uri.hasScheme || uri.scheme != 'http' && uri.scheme != 'https') {
        return '';
      }
      final path = uri.path;
      final dot = path.lastIndexOf('.');
      if (dot < 0) return '';
      return path.substring(dot + 1).toLowerCase();
    } catch (_) {
      return '';
    }
  }

  /// Display label for a media type extension; blob:/unknown URLs get a
  /// generic label instead of a nonsense "extension".
  String _typeLabel(String ext) {
    if (ext.isEmpty) return '媒体资源';
    return formatDisplayName(ext);
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
      case 'wma':
      case 'opus':
      case 'weba':
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
    if (!widget.visible) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // Only the header acts as the drag handle (the spec's "拖动手柄").
    // A pan detector over the whole panel would compete with the URL
    // ListView in the gesture arena: vertical drags over the list would be
    // ambiguous and horizontal drags would move the panel while scrolling.
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: colorScheme.primaryContainer,
      child: Container(
        width: DraggableFloatingPanel.panelWidth,
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
            GestureDetector(
              onPanUpdate: widget.onDragUpdate != null
                  ? (details) => widget.onDragUpdate!(details.delta)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/cat_head.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onPrimaryContainer,
                        BlendMode.srcIn,
                      ),
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
                          _minimized ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    // Close
                    InkWell(
                      onTap: widget.onClose,
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
                        _typeLabel(_extractExtension(url)),
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
    // The list may have shrunk since the selection was made (page
    // navigated, detection reset) — never index out of bounds.
    final selectedIndex = _selectedIndex;
    final hasSelection =
        selectedIndex != null && selectedIndex < widget.detectedUrls.length;

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
              hasSelection
                  ? '已选: ${_typeLabel(_extractExtension(widget.detectedUrls[selectedIndex]))}'
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
              onPressed: hasSelection
                  ? () {
                      widget.onConfirmCapture(
                        widget.detectedUrls[selectedIndex],
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
