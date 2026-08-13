import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../providers/task_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../services/storage_service.dart';

final taskListLastReadProvider =
    StateProvider<DateTime>((ref) => DateTime(2000));

Future<void> persistTaskListLastRead(DateTime dt) async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'task_list_last_read.json'));
    await file.writeAsString(jsonEncode({'lastRead': dt.toIso8601String()}));
  } catch (e) {
    debugPrint('Failed to persist lastRead: $e');
  }
}

Future<DateTime> loadTaskListLastRead() async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'task_list_last_read.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final data = jsonDecode(content) as Map;
        if (data['lastRead'] != null) {
          return DateTime.parse(data['lastRead'] as String);
        }
      }
    }
  } catch (e) {
    debugPrint('Failed to load lastRead: $e');
  }
  return DateTime(2000);
}

/// Provider that holds the list of recorded app launch timestamps.
final appLaunchTimestampsProvider = StateProvider<List<DateTime>>((ref) => []);

/// Record a new cold-start launch timestamp and persist.
/// Keeps the last 4 timestamps (to have 3 intervals).
/// Returns the updated list of launch timestamps (after trimming).
Future<List<DateTime>> recordAppLaunch() async {
  try {
    final launches = await loadAppLaunches();
    final now = DateTime.now();
    launches.add(now);
    if (launches.length > 4) {
      launches.removeRange(0, launches.length - 4);
    }
    await _persistAppLaunches(launches);
    return launches;
  } catch (e) {
    debugPrint('[recordAppLaunch] Failed: $e');
    return [];
  }
}

/// Load app launch timestamps from disk.
Future<List<DateTime>> loadAppLaunches() async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'app_launches.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final data = jsonDecode(content) as Map;
        final list = data['launches'] as List? ?? [];
        return list.map((s) => DateTime.parse(s as String)).toList();
      }
    }
  } catch (e) {
    debugPrint('[loadAppLaunches] Failed: $e');
  }
  return [];
}

Future<void> _persistAppLaunches(List<DateTime> launches) async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'app_launches.json'));
    final data = launches.map((dt) => dt.toIso8601String()).toList();
    await file.writeAsString(jsonEncode({'launches': data}));
  } catch (e) {
    debugPrint('[persistAppLaunches] Failed: $e');
  }
}

/// Count of tasks created during each of the last N launch sessions.
///
/// Returns a list of (taskCount, unreadCount) pairs, one per launch session,
/// ordered from most recent to oldest. Each pair represents tasks whose
/// [createdAt] falls within the time window of that launch session.
///
/// The "current" session (most recent launch) counts tasks created after
/// the previous launch up to [DateTime.now] (open-ended). Past sessions
/// count tasks created between consecutive launch timestamps.
/// Start is exclusive (tasks at a launch boundary belong to the interval
/// after that launch), end is inclusive.
///
/// [unreadThreshold] is the last time the user viewed the task list
/// (from [taskListLastReadProvider]). A task is considered unread if its
/// [createdAt] or [statusChangedAt] is after this threshold.
List<Map<String, int>> computeRecentTaskCounts({
  required List<DateTime> launches,
  required List<catcatch.CatCatchTask> catcatchTasks,
  required List<SynthesisTask> synthesisTasks,
  required List<BackgroundTask> backgroundTasks,
  required DateTime unreadThreshold,
}) {
  if (launches.length < 2) return [];

  final sessions = <Map<String, int>>[];

  final sorted = List<DateTime>.from(launches)..sort();

  final numSessions = sorted.length - 1;
  final numToShow = numSessions > 3 ? 3 : numSessions;
  final startIndex = sorted.length - numToShow;

  for (int i = startIndex; i < sorted.length; i++) {
    final intervalStart = sorted[i - 1];
    final intervalEnd = (i == sorted.length - 1) ? DateTime.now() : sorted[i];

    int totalCount = 0;
    int unreadCount = 0;

    bool isAfterStart(DateTime t) => t.isAfter(intervalStart);
    bool isBeforeOrAtEnd(DateTime t) => !t.isAfter(intervalEnd);

    void countTask(DateTime createdAt, DateTime? statusChangedAt) {
      if (isAfterStart(createdAt) && isBeforeOrAtEnd(createdAt)) {
        totalCount++;
        final effective = statusChangedAt ?? createdAt;
        if (effective.isAfter(unreadThreshold)) {
          unreadCount++;
        }
      }
    }

    for (final t in catcatchTasks) {
      countTask(t.createdAt, t.statusChangedAt);
    }
    for (final t in synthesisTasks) {
      countTask(t.createdAt, t.statusChangedAt);
    }
    for (final t in backgroundTasks) {
      countTask(t.createdAt, t.statusChangedAt);
    }

    sessions.add({
      'total': totalCount,
      'unread': unreadCount,
    });
  }

  return sessions.reversed.toList();
}
