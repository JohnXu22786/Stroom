import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../providers/provider_config.dart';

import '../widgets/constrained_text.dart';

class DuplicateResolveDialog extends StatefulWidget {
  final List<VoiceEntry> working;
  final Map<String, int> idToFirstIdx;
  final List<int> pending;
  final ValueChanged<List<VoiceEntry>?> onComplete;

  const DuplicateResolveDialog({
    super.key,
    required this.working,
    required this.idToFirstIdx,
    required this.pending,
    required this.onComplete,
  });

  @override
  State<DuplicateResolveDialog> createState() => DuplicateResolveDialogState();
}

class DuplicateResolveDialogState extends State<DuplicateResolveDialog> {
  late List<VoiceEntry> _working;
  late Map<String, int> _idToFirstIdx;
  late List<int> _pending;

  @override
  void initState() {
    super.initState();
    _working = widget.working.map((v) => v.copy()).toList();
    _idToFirstIdx = Map.from(widget.idToFirstIdx);
    _pending = List.from(widget.pending);
  }

  void _handleUpdate(int pendingIdx) {
    final dupIdx = _pending[pendingIdx];
    final dup = _working[dupIdx];
    final firstIdx = _idToFirstIdx[dup.id.trim()]!;

    _working[firstIdx].name = dup.name;
    _working[firstIdx].id = dup.id;

    _working.removeAt(dupIdx);

    final newIdToFirst = <String, int>{};
    for (int i = 0; i < _working.length; i++) {
      newIdToFirst.putIfAbsent(_working[i].id.trim(), () => i);
    }
    _idToFirstIdx = newIdToFirst;

    final newPending = <int>[];
    final seen = <String>{};
    for (int i = 0; i < _working.length; i++) {
      if (!seen.add(_working[i].id.trim())) {
        newPending.add(i);
      }
    }
    _pending = newPending;

    if (_pending.isEmpty) {
      widget.onComplete(_working);
    } else {
      setState(() {});
    }
  }

  void _handleSkip(int pendingIdx) {
    final dupIdx = _pending[pendingIdx];
    _working.removeAt(dupIdx);

    final newIdToFirst = <String, int>{};
    for (int i = 0; i < _working.length; i++) {
      newIdToFirst.putIfAbsent(_working[i].id.trim(), () => i);
    }
    _idToFirstIdx = newIdToFirst;

    final newPending = <int>[];
    final seen = <String>{};
    for (int i = 0; i < _working.length; i++) {
      if (!seen.add(_working[i].id.trim())) {
        newPending.add(i);
      }
    }
    _pending = newPending;

    if (_pending.isEmpty) {
      widget.onComplete(_working);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: ConstrainedText(
        l10n.voiceDuplicateResolution,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _pending.length,
                itemBuilder: (context, i) {
                  final dupIdx = _pending[i];
                  final entry = _working[dupIdx];
                  final indexText = '${i + 1}.';
                  final theme = Theme.of(context);
                  final buttonStyle = TextButtonTheme.of(context).style;
                  final buttonStates = const <WidgetState>{};
                  final buttonTextStyle =
                      buttonStyle?.textStyle?.resolve(buttonStates) ??
                      theme.textTheme.labelLarge ??
                      const TextStyle(fontSize: 14);
                  final buttonPadding =
                      buttonStyle?.padding?.resolve(buttonStates) ??
                      const EdgeInsets.symmetric(horizontal: 16);
                  final buttonMinWidth =
                      buttonStyle?.minimumSize?.resolve(buttonStates)?.width ??
                      64;
                  final textScaler = MediaQuery.textScalerOf(context);
                  double buttonWidth(String label) {
                    final painter = TextPainter(
                      text: TextSpan(text: label, style: buttonTextStyle),
                      textDirection: Directionality.of(context),
                      textScaler: textScaler,
                    )..layout();
                    return math.max(
                      buttonMinWidth,
                      painter.width + buttonPadding.horizontal,
                    );
                  }

                  final indexPainter = TextPainter(
                    text: TextSpan(
                      text: indexText,
                      style: const TextStyle(fontSize: 14),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: textScaler,
                  )..layout();
                  final minInlineWidth =
                      math.max(28, indexPainter.width) +
                      buttonWidth(l10n.update) +
                      buttonWidth(l10n.skip) +
                      8 +
                      48;

                  Widget indexLabel() => ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 28),
                    child: Text(
                      indexText,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );

                  Widget voiceIdLabel() => Text(
                    entry.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  );

                  Widget updateButton({double? width}) => SizedBox(
                    width: width ?? buttonWidth(l10n.update),
                    child: TextButton(
                      style: width == null
                          ? null
                          : TextButton.styleFrom(
                              alignment: AlignmentDirectional.centerEnd,
                            ),
                      onPressed: () => _handleUpdate(i),
                      child: Text(l10n.update),
                    ),
                  );

                  Widget skipButton({double? width}) => SizedBox(
                    width: width ?? buttonWidth(l10n.skip),
                    child: TextButton(
                      style: width == null
                          ? null
                          : TextButton.styleFrom(
                              alignment: AlignmentDirectional.centerEnd,
                            ),
                      onPressed: () => _handleSkip(i),
                      child: Text(l10n.skip),
                    ),
                  );

                  Widget actionButtons() => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      updateButton(),
                      const SizedBox(width: 4),
                      skipButton(),
                    ],
                  );

                  Widget stackedActionButtons(double availableWidth) => Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        updateButton(width: availableWidth),
                        skipButton(width: availableWidth),
                      ],
                    ),
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < minInlineWidth) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  indexLabel(),
                                  const SizedBox(width: 4),
                                  Expanded(child: voiceIdLabel()),
                                ],
                              ),
                              stackedActionButtons(constraints.maxWidth),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            indexLabel(),
                            Expanded(child: voiceIdLabel()),
                            actionButtons(),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.voiceDuplicatesRemaining(_pending.length),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => widget.onComplete(null),
                child: ConstrainedText(
                  l10n.continueEditing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
