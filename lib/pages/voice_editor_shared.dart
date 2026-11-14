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
      newIdToFirst[_working[i].id.trim()] = i;
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
      newIdToFirst[_working[i].id.trim()] = i;
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _handleUpdate(i),
                          child: ConstrainedText(
                            l10n.update,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => _handleSkip(i),
                          child: ConstrainedText(
                            l10n.skip,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
