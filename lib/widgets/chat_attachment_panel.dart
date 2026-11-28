import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:stroom/widgets/modal_bottom_sheet_constraints.dart';

import '../l10n/app_localizations.dart';
import 'constrained_text.dart';

/// Shows the File Attachment Panel — a modal bottom sheet with file transfer
/// options only. No model selection, tools, or reasoning settings.
///
/// [onPickFromCamera] — called when the camera option is tapped.
/// [onPickFromGallery] — called when the gallery option is tapped.
/// [onPickFromFilePicker] — called when the file picker option is tapped.
/// [onPickFromAppFiles] — called when the app internal file option is tapped.
void showChatAttachmentPanel({
  required BuildContext context,
  required VoidCallback onPickFromCamera,
  required VoidCallback onPickFromGallery,
  required VoidCallback onPickFromFilePicker,
  required VoidCallback onPickFromAppFiles,
}) {
  showModalBottomSheet(
    context: context,
    constraints: modalBottomSheetWidthConstraints(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.min(640.0, MediaQuery.sizeOf(ctx).height * 0.8),
          ),
          child: _DismissibleAttachmentScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Drag handle ──
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[350],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // ── Title ──
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.attach_file_outlined,
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ConstrainedText(
                          AppLocalizations.of(context)!.chatAttachmentFile,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ══════════════════════════════════════════════════
                  // File action buttons
                  // ══════════════════════════════════════════════════
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actions = [
                        _FileActionButton(
                          icon: Icons.camera_alt_outlined,
                          label: AppLocalizations.of(context)!
                              .chatAttachmentCamera,
                          color: Colors.orange,
                          onTap: () {
                            Navigator.pop(context);
                            onPickFromCamera();
                          },
                        ),
                        _FileActionButton(
                          icon: Icons.photo_library_outlined,
                          label: AppLocalizations.of(context)!
                              .chatAttachmentDeviceGallery,
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pop(context);
                            onPickFromGallery();
                          },
                        ),
                        _FileActionButton(
                          icon: Icons.insert_drive_file_outlined,
                          label: AppLocalizations.of(context)!
                              .chatAttachmentDeviceFiles,
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(context);
                            onPickFromFilePicker();
                          },
                        ),
                        _FileActionButton(
                          icon: Icons.folder_outlined,
                          label: AppLocalizations.of(context)!
                              .chatAttachmentAppFiles,
                          color: Colors.purple,
                          onTap: () {
                            Navigator.pop(context);
                            onPickFromAppFiles();
                          },
                        ),
                      ];

                      if (constraints.maxWidth < 320) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                for (final action in actions.take(2))
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: action.withWidth(double.infinity),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final action in actions.skip(2))
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: action.withWidth(double.infinity),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: actions,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DismissibleAttachmentScrollView extends StatefulWidget {
  const _DismissibleAttachmentScrollView({required this.child});

  final Widget child;

  @override
  State<_DismissibleAttachmentScrollView> createState() =>
      _DismissibleAttachmentScrollViewState();
}

class _DismissibleAttachmentScrollViewState
    extends State<_DismissibleAttachmentScrollView> {
  final ScrollController _scrollController = ScrollController();
  Offset? _dragStart;
  VelocityTracker? _velocityTracker;
  bool _dismissRequested = false;

  bool get _isAtScrollStart =>
      _scrollController.hasClients &&
      _scrollController.position.pixels <=
          _scrollController.position.minScrollExtent + 1;

  void _trackPointer(PointerEvent event) {
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final start = _dragStart;
    if (start == null || _dismissRequested || !_isAtScrollStart) return;

    final renderObject = context.findRenderObject();
    final viewportHeight = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.size.height
        : 0.0;
    final dragDistance = event.position.dy - start.dy;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    if (dragDistance >= viewportHeight / 2 || velocity >= 700) {
      _dismissRequested = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (_isAtScrollStart) {
          _dragStart = event.position;
          _velocityTracker = VelocityTracker.withKind(event.kind)
            ..addPosition(event.timeStamp, event.position);
        } else {
          _dragStart = null;
          _velocityTracker = null;
        }
        _dismissRequested = false;
      },
      onPointerMove: _trackPointer,
      onPointerUp: (event) {
        _trackPointer(event);
        _dragStart = null;
        _velocityTracker = null;
      },
      onPointerCancel: (_) {
        _dragStart = null;
        _velocityTracker = null;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: widget.child,
      ),
    );
  }
}

/// A large icon button for file actions (camera, gallery, file, app files).
class _FileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const _FileActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.width = 80,
  });

  Widget withWidth(double width) => _FileActionButton(
        icon: icon,
        label: label,
        color: color,
        onTap: onTap,
        width: width,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedText(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
