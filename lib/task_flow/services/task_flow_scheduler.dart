import 'dart:io';

import '../models/block_type_definition.dart';

/// Resource-aware scheduler for concurrent task-flow executions.
///
/// Blocks are sequential within a flow, but multiple flows may run
/// concurrently. This scheduler caps the total weighted resource budget
/// across all running blocks so concurrent flows cannot saturate the
/// device (CPU-heavy download/convert blocks cost more than network-only
/// calls). Flows whose next block exceeds the remaining budget queue FIFO
/// and are resumed automatically when resources free up.
///
/// The budget adapts to the device's current load: when the process's
/// resident memory grows quickly between samples (via
/// [ProcessInfo.currentRss]), the budget shrinks; it recovers once memory
/// stabilizes (hysteresis prevents flapping).
class TaskFlowScheduler {
  TaskFlowScheduler({
    int? coreCount,
    int Function()? rssBytes,
    DateTime Function()? now,
    this.rssWindow = const Duration(seconds: 30),
    this.rssGrowthThresholdBytes = 300 * 1024 * 1024,
    this.minBudget = 1,
  })  : _coreCount = coreCount ?? Platform.numberOfProcessors,
        _rssBytes = rssBytes ?? (() => ProcessInfo.currentRss),
        _now = now ?? DateTime.now;

  final int _coreCount;
  final int Function() _rssBytes;
  final DateTime Function() _now;
  final Duration rssWindow;
  final int rssGrowthThresholdBytes;
  final int minBudget;

  /// Resource weight per block type: CPU/IO-heavy work (downloads,
  /// conversions) costs 2, network-only work costs 1.
  static int weightFor(BlockType type) {
    switch (type) {
      case BlockType.catcatch:
      case BlockType.audioSeparation:
        return 2;
      case BlockType.asr:
      case BlockType.ocr:
      case BlockType.tts:
      case BlockType.chat:
      case BlockType.custom:
        return 1;
    }
  }

  /// Base budget from the device class: half the cores, clamped 2..4.
  /// A 4-core device allows e.g. 2 converts, or 1 convert + 2 calls.
  int get baseBudget => (_coreCount ~/ 2).clamp(2, 4);

  /// Budget after the dynamic RSS-based contraction (hysteresis).
  int get currentBudget {
    final base = baseBudget;
    if (_contracted && base > minBudget) return base - 1;
    return base;
  }

  /// Sum of weights of currently running blocks.
  int get activeWeight => _active.values.fold(0, (sum, w) => sum + w);

  /// Number of flows waiting for resources.
  int get queuedCount => _queue.length;

  bool _contracted = false;

  /// execId -> weight of currently running blocks.
  final Map<String, int> _active = {};

  /// FIFO wait queue.
  final List<_WaitEntry> _queue = [];

  /// RSS samples within [rssWindow]: (timestamp, rss).
  final List<(DateTime, int)> _rssSamples = [];

  /// Last sampled RSS — kept as a cross-block baseline even after the
  /// window prunes older samples, so memory growth during a long block
  /// is attributed to the next acquire.
  int? _lastSampleRss;
  DateTime? _lastSampleAt;

  /// Requests resources for [execId]'s next block. Returns immediately
  /// when the budget allows; otherwise waits FIFO until resources free up
  /// or the entry is cancelled via [cancel].
  Future<void> acquire(String execId, int weight) async {
    _sampleRss();
    if (_canRun(weight)) {
      _active[execId] = weight;
      return;
    }

    final entry = _WaitEntry(execId, weight);
    _queue.add(entry);
    while (!entry.done) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _sampleRss();
      if (entry.cancelled) {
        throw const FlowSchedulerCancelledException();
      }
      // FIFO: only the head of the queue may acquire. When nothing is
      // running, the head always proceeds — even a weight-2 block under a
      // contracted budget — so a heavy head can never starve the queue.
      if (_queue.first == entry &&
          (activeWeight == 0 || activeWeight + entry.weight <= currentBudget)) {
        _queue.remove(entry);
        _active[execId] = weight;
        entry.done = true;
        return;
      }
    }
  }

  /// Releases [execId]'s resources (idempotent).
  void release(String execId, {int? weight}) {
    if (_active.remove(execId) != null) {
      _sampleRss();
    }
  }

  /// Cancels a queued (not yet running) [execId]; its [acquire] throws
  /// [FlowSchedulerCancelledException].
  void cancel(String execId) {
    final idx = _queue.indexWhere((e) => e.execId == execId);
    if (idx == -1) return;
    final entry = _queue.removeAt(idx);
    entry.cancelled = true;
    entry.done = true;
  }

  bool _canRun(int weight) =>
      activeWeight == 0 || activeWeight + weight <= currentBudget;

  /// Samples the process RSS and re-evaluates the contraction state.
  /// Hysteresis: contract when growth exceeds the threshold; recover only
  /// when growth drops below half the threshold.
  ///
  /// Growth is measured against the earliest sample inside the window; if
  /// the window holds a single sample (long block between acquisitions),
  /// the last sampled RSS serves as the baseline instead, so memory
  /// growth during a block still counts. After a long idle gap (> 2x the
  /// window) the baseline re-anchors to the current RSS.
  void _sampleRss() {
    final now = _now();
    final rss = _rssBytes();
    final prevSampleRss = _lastSampleRss;
    final prevSampleAt = _lastSampleAt;
    _lastSampleRss = rss;
    _lastSampleAt = now;
    _rssSamples.add((now, rss));
    // Drop samples outside the window.
    final cutoff = now.subtract(rssWindow);
    while (_rssSamples.isNotEmpty && _rssSamples.first.$1.isBefore(cutoff)) {
      _rssSamples.removeAt(0);
    }
    // Skip the very first sample (no baseline yet).
    if (prevSampleRss == null) return;

    // Re-anchor after a long idle gap — a stale baseline would
    // misattribute unrelated memory to the current run.
    if (prevSampleAt != null && now.difference(prevSampleAt) > rssWindow * 2) {
      return;
    }

    final baseline =
        _rssSamples.length >= 2 ? _rssSamples.first.$2 : prevSampleRss;
    final growth = rss - baseline;
    if (growth > rssGrowthThresholdBytes) {
      _contracted = true;
    } else if (growth < rssGrowthThresholdBytes ~/ 2) {
      _contracted = false;
    }
  }
}

/// Thrown by [TaskFlowScheduler.acquire] when the waiting flow was
/// cancelled (deleted) while queued.
class FlowSchedulerCancelledException implements Exception {
  const FlowSchedulerCancelledException();
}

class _WaitEntry {
  _WaitEntry(this.execId, this.weight);

  final String execId;
  final int weight;
  bool done = false;
  bool cancelled = false;
}
