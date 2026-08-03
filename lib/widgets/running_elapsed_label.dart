import 'dart:async';

import 'package:flutter/material.dart';

/// Shows "已运行 mm:ss" for an in-progress task, ticking every second so
/// the user can see a slow-but-working task is still alive and decide
/// whether to keep waiting. Renders nothing while [startedAt] is null.
class RunningElapsedLabel extends StatefulWidget {
  final DateTime? startedAt;
  final TextStyle? style;

  const RunningElapsedLabel({super.key, this.startedAt, this.style});

  @override
  State<RunningElapsedLabel> createState() => _RunningElapsedLabelState();
}

class _RunningElapsedLabelState extends State<RunningElapsedLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant RunningElapsedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.startedAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String format(DateTime start) {
    final d = DateTime.now().difference(start);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startedAt;
    if (start == null) return const SizedBox.shrink();
    return Text('已运行 ${format(start)}', style: widget.style);
  }
}
