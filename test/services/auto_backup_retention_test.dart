import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/auto_backup_service.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
    // Clean up any leftover backup files from previous tests
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  // ==================================================================
  // 1-hour skip rule — performAutoBackup
  // ==================================================================

  group('performAutoBackup — 1-hour rule', () {
    test('skips backup when there is a backup within the last hour', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      await dir.create(recursive: true);

      // Create a recent backup (within last hour)
      final now = DateTime.now();
      final timeStr = '${now.year}-${_pad(now.month)}-${_pad(now.day)}T'
          '${_pad(now.hour)}-${_pad(now.minute)}-${_pad(now.second)}';
      final recentFile = File('${dir.path}/backup_$timeStr.zip');
      await recentFile.writeAsString('recent_backup');

      // performAutoBackup should skip because of recent backup
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue,
          reason: 'Should return true (skip is not a failure)');

      // Verify no new zip file was created (still only 1)
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(1),
          reason:
              'Should not create a new backup when one exists within 1 hour');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('performs backup when last backup is older than 1 hour', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      await dir.create(recursive: true);

      // Create an old backup (>1 hour ago)
      final oldTime = DateTime.now().subtract(const Duration(hours: 2));
      final timeStr =
          '${oldTime.year}-${_pad(oldTime.month)}-${_pad(oldTime.day)}T'
          '${_pad(oldTime.hour)}-${_pad(oldTime.minute)}-${_pad(oldTime.second)}';
      final oldFile = File('${dir.path}/backup_$timeStr.zip');
      await oldFile.writeAsString('old_backup');

      // performAutoBackup should proceed since last backup > 1 hour ago
      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Verify a new zip file was created (2 zips now)
      final entries = await dir.list().toList();
      final zips = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      expect(zips.length, equals(2),
          reason: 'Should create a new backup when last backup > 1 hour old');

      // Cleanup
      await dir.delete(recursive: true);
    });

    test('performs backup when no previous backups exist', () async {
      final root = await DataMigrationService.getExternalBackupRootPath();
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      final result = await AutoBackupService.performAutoBackup();
      expect(result, isTrue);

      // Cleanup
      await dir.delete(recursive: true);
    });
  });

// ==================================================================
// cleanupOldBackups — new retention policy (max 5 total, max 3 within 24h,
// keep last backup from last 2 usage days, prefer day diversity)
// ==================================================================

group('cleanupOldBackups — retention policy', () {
  test('keeps max 3 within 24h and max 5 total', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Create 7 backup zip files:
    // - 4 recent (within 24h)
    // - 3 old (beyond 24h, on 3 different "usage days")
    final now = DateTime.now();
    // 4 recent files: 2h, 4h, 6h, 8h ago (all within 24h)
    for (int i = 0; i < 4; i++) {
      final t = now.subtract(Duration(hours: 2 * (i + 1)));
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final file = File('${dir.path}/backup_$timeStr.zip');
      await file.writeAsString('recent_$i');
    }
    // 3 old files on 3 different days (48h, 72h, 96h ago)
    for (int i = 0; i < 3; i++) {
      final t = now.subtract(Duration(hours: 24 * (i + 2)));
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final file = File('${dir.path}/backup_$timeStr.zip');
      await file.writeAsString('old_$i');
    }

    await AutoBackupService.cleanupOldBackups();

    // Should keep max 5 total
    final entries = await dir.list().toList();
    final zips = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    expect(zips.length, equals(5), reason: 'Should keep max 5 backups total');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('keeps all when fewer than 3 backups exist', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Create only 2 backups (less than min 3)
    final now = DateTime.now();
    for (int i = 0; i < 2; i++) {
      final t = now.subtract(Duration(hours: 2 * (i + 1)));
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final file = File('${dir.path}/backup_$timeStr.zip');
      await file.writeAsString('backup_$i');
    }

    await AutoBackupService.cleanupOldBackups();

    final entries = await dir.list().toList();
    final zips = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    expect(zips.length, equals(2),
        reason: 'Should keep all 2 when below min threshold');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('keeps all when exactly 3 backups exist', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Create exactly 3 backups (at the min threshold)
    final now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final t = now.subtract(Duration(hours: 2 * (i + 1)));
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final file = File('${dir.path}/backup_$timeStr.zip');
      await file.writeAsString('backup_$i');
    }

    await AutoBackupService.cleanupOldBackups();

    final entries = await dir.list().toList();
    final zips = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    expect(zips.length, equals(3),
        reason: 'Should keep all 3 at min threshold');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('keeps at most 3 within 24h when many recent backups exist', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    await dir.create(recursive: true);

    // Create 6 backups all within the last 24 hours
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final t = now.subtract(Duration(hours: i)); // 0,1,2,3,4,5 hours ago
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final file = File('${dir.path}/backup_$timeStr.zip');
      await file.writeAsString('recent_$i');
    }

    await AutoBackupService.cleanupOldBackups();

    // All within 24h → limited to max 3 within 24h (no beyond-24h files to add)
    final entries = await dir.list().toList();
    final zips = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    expect(zips.length, equals(3),
        reason: 'Should keep max 3 when all are within 24h');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test(
      'prefers day diversity: keeps 1 per day from old days, not multiple from same day',
      () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // === Key scenario demonstrating the new behavior ===
    // within 24h: 2 backups (not filling the 3 slots)
    // beyond 24h: 3 from yesterday, 1 from 2-days-ago, 1 from 3-days-ago
    // Total: 7
    //
    // Old behavior: keeps 2 today + 2 yesterday + 1 from 2-days-ago = 5
    // New behavior: keeps 2 today + 1 yesterday (last) + 1 2-days-ago + 1 3-days-ago = 5
    // New prefers DAY DIVERSITY — 1 per day from more distant days.

    final now = DateTime.now();

    // 2 from today (2h and 4h ago — within 24h)
    final today1 = now.subtract(const Duration(hours: 2));
    final fToday1 = '${dir.path}/backup_${_ts(today1)}.zip';
    await File(fToday1).writeAsString('today_1');
    final today2 = now.subtract(const Duration(hours: 4));
    final fToday2 = '${dir.path}/backup_${_ts(today2)}.zip';
    await File(fToday2).writeAsString('today_2');

    // 3 from yesterday (same day, different times)
    final yesterdayBase = now.subtract(const Duration(hours: 30));
    final yesterdayMorning = yesterdayBase.subtract(const Duration(hours: 6));
    final fYesterdayMorning = '${dir.path}/backup_${_ts(yesterdayMorning)}.zip';
    await File(fYesterdayMorning).writeAsString('yesterday_morning');
    final yesterdayAfternoon = yesterdayBase.subtract(const Duration(hours: 3));
    final fYesterdayAfternoon =
        '${dir.path}/backup_${_ts(yesterdayAfternoon)}.zip';
    await File(fYesterdayAfternoon).writeAsString('yesterday_afternoon');
    final yesterdayEvening = yesterdayBase;
    final fYesterdayEvening =
        '${dir.path}/backup_${_ts(yesterdayEvening)}.zip';
    await File(fYesterdayEvening).writeAsString('yesterday_evening');

    // 1 from 2 days ago
    final twoDaysAgo = now.subtract(const Duration(hours: 54));
    final fTwoDaysAgo = '${dir.path}/backup_${_ts(twoDaysAgo)}.zip';
    await File(fTwoDaysAgo).writeAsString('two_days_ago');

    // 1 from 3 days ago
    final threeDaysAgo = now.subtract(const Duration(hours: 78));
    final fThreeDaysAgo = '${dir.path}/backup_${_ts(threeDaysAgo)}.zip';
    await File(fThreeDaysAgo).writeAsString('three_days_ago');

    await AutoBackupService.cleanupOldBackups();

    // Check which files survived
    final fToday1Survived = await File(fToday1).exists();
    final fToday2Survived = await File(fToday2).exists();
    final fYesterdayMorningSurvived =
        await File(fYesterdayMorning).exists();
    final fYesterdayAfternoonSurvived =
        await File(fYesterdayAfternoon).exists();
    final fYesterdayEveningSurvived =
        await File(fYesterdayEvening).exists();
    final fTwoDaysAgoSurvived = await File(fTwoDaysAgo).exists();
    final fThreeDaysAgoSurvived = await File(fThreeDaysAgo).exists();

    final kept = [
      if (fToday1Survived) 'today_1',
      if (fToday2Survived) 'today_2',
      if (fYesterdayMorningSurvived) 'yesterday_morning',
      if (fYesterdayAfternoonSurvived) 'yesterday_afternoon',
      if (fYesterdayEveningSurvived) 'yesterday_evening',
      if (fTwoDaysAgoSurvived) 'two_days_ago',
      if (fThreeDaysAgoSurvived) 'three_days_ago',
    ];

    expect(kept.length, equals(5),
        reason:
            'Should keep max 5. Kept: $kept');

    // Day diversity: keep 1 from yesterday (latest), not multiple
    expect(fToday1Survived, isTrue, reason: 'Should keep today_1');
    expect(fToday2Survived, isTrue, reason: 'Should keep today_2');
    expect(fYesterdayEveningSurvived, isTrue,
        reason: 'Should keep the latest yesterday backup');
    expect(fYesterdayMorningSurvived, isFalse,
        reason: 'Should delete older yesterday backup (morning) for day diversity');
    expect(fYesterdayAfternoonSurvived, isFalse,
        reason: 'Should delete older yesterday backup (afternoon) for day diversity');
    expect(fTwoDaysAgoSurvived, isTrue,
        reason: 'Should keep backup from 2 days ago');
    expect(fThreeDaysAgoSurvived, isTrue,
        reason:
            'Should prefer keeping 1 from 3-days-ago over a 2nd from yesterday (day diversity)');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('fills up to 5 from more days when within-24h count < 3', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // within 24h: 1 backup
    // beyond 24h: 5 different days (yesterday, ..., 5-days-ago)
    // Total: 6 → should keep 5 using 1 per day

    final now = DateTime.now();
    // Track filenames for verification
    final filePaths = <String>[];

    // 1 from today (within 24h)
    final today = now.subtract(const Duration(hours: 2));
    final fToday = '${dir.path}/backup_${_ts(today)}.zip';
    await File(fToday).writeAsString('today');
    filePaths.add(fToday);

    // 5 from different old days
    for (int i = 1; i <= 5; i++) {
      final t = now.subtract(Duration(days: i, hours: 2));
      final f = '${dir.path}/backup_${_ts(t)}.zip';
      await File(f).writeAsString('old_day_$i');
      filePaths.add(f);
    }

    await AutoBackupService.cleanupOldBackups();

    // Check which survived
    final kept = <String>[];
    for (final f in filePaths) {
      if (await File(f).exists()) {
        kept.add(f);
      }
    }

    expect(kept.length, equals(5),
        reason: 'Should keep 5 total (1 today + 4 old days)');

    // Should keep: 1 today + yesterday + 2-days-ago + 3-days-ago + 4-days-ago
    // Should delete: 5-days-ago
    final keptStr = kept.join(', ');

    // today should be kept
    expect(kept.any((p) => p == fToday), isTrue,
        reason: 'Should keep today backup');

    // old_day_1 through old_day_4 should be kept
    expect(kept.any((p) => p == filePaths[1]), isTrue,
        reason: 'Should keep old_day_1 (yesterday). Kept: $keptStr');
    expect(kept.any((p) => p == filePaths[2]), isTrue,
        reason: 'Should keep old_day_2 (2-days-ago). Kept: $keptStr');
    expect(kept.any((p) => p == filePaths[3]), isTrue,
        reason: 'Should keep old_day_3 (3-days-ago). Kept: $keptStr');
    expect(kept.any((p) => p == filePaths[4]), isTrue,
        reason: 'Should keep old_day_4 (4-days-ago). Kept: $keptStr');

    // old_day_5 should be deleted
    expect(kept.any((p) => p == filePaths[5]), isFalse,
        reason: 'Should delete the oldest day (old_day_5) when filling to 5');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('keeps 4 when within 24h is full (3) and only 1 old day exists',
      () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 3 within 24h, 1 from yesterday = 4 total → keep all (between min 3 and max 5)
    final now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final t = now.subtract(Duration(hours: 2 * (i + 1)));
      await File('${dir.path}/backup_${_ts(t)}.zip').writeAsString('today_$i');
    }
    final yesterday = now.subtract(const Duration(hours: 30));
    await File('${dir.path}/backup_${_ts(yesterday)}.zip')
        .writeAsString('yesterday');

    await AutoBackupService.cleanupOldBackups();

    final entries = await dir.list().toList();
    final remaining = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    expect(remaining.length, equals(4),
        reason: 'Should keep 4 when within-24h is 3 and only 1 old day');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('handles mixed zip and dir backups without error', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    await dir.create(recursive: true);

    // 3 zips + 5 old-style dirs = 8 total → cleanup should reduce count
    final now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final t = now.subtract(Duration(hours: 2 * (i + 1)));
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final file = File('${dir.path}/backup_$timeStr.zip');
      await file.writeAsString('zip_$i');
    }
    for (int i = 0; i < 5; i++) {
      final t = now.subtract(Duration(days: 2 * (i + 1)));
      final timeStr = '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
          '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
      final d = Directory('${dir.path}/backup_$timeStr');
      await d.create(recursive: true);
      await File('${d.path}/manifest.json').writeAsString('{}');
    }

    await AutoBackupService.cleanupOldBackups();

    // Verify count was reduced
    final entries = await dir.list().toList();
    int count = 0;
    for (final e in entries) {
      if (e is File && e.path.endsWith('.zip')) count++;
      if (e is Directory && e.path.contains('backup_')) count++;
    }
    expect(count, lessThan(8), reason: 'Should reduce total count from 8');

    // Cleanup
    await dir.delete(recursive: true);
  });

  test('is idempotent when no backups exist', () async {
    // Should not throw
    await AutoBackupService.cleanupOldBackups();
  });

  test('all beyond 24h with no within-24h backups fills toward 5', () async {
    final root = await DataMigrationService.getExternalBackupRootPath();
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 4 old days, no within-24h backups
    // Total: 4 > 3, but algorithm fills toward 5 → keeps all 4
    // (4 is between min 3 and max 5)
    final now = DateTime.now();
    final filePaths = <String>[];
    for (int i = 1; i <= 4; i++) {
      final t = now.subtract(Duration(days: i, hours: 2));
      final f = '${dir.path}/backup_${_ts(t)}.zip';
      await File(f).writeAsString('old_day_$i');
      filePaths.add(f);
    }

    await AutoBackupService.cleanupOldBackups();

    final kept = <String>[];
    for (final f in filePaths) {
      if (await File(f).exists()) {
        kept.add(f);
      }
    }

    final keptStr = kept.join(', ');
    // With 0 within-24h and 4 old days, algorithm fills toward 5 → keeps all 4
    expect(kept.length, equals(4),
        reason:
            'Should keep all 4 (fills toward 5 from 0 within-24h). Kept: $keptStr');

    // All 4 days should be kept (between min 3 and max 5)
    for (int i = 0; i < 4; i++) {
      expect(kept.any((p) => p == filePaths[i]), isTrue,
          reason:
              'Should keep old_day_${i + 1}. Kept: $keptStr');
    }

    // Cleanup
    await dir.delete(recursive: true);
  });
});

  // ==================================================================
  // DataMigrationService delegation (uses new retention)
  // ==================================================================

  group('DataMigrationService delegation — new retention', () {
    test('cleanOldBackups delegates to AutoBackupService with new policy',
        () async {
      await DataMigrationService.cleanOldBackups();
    });
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// Format a [DateTime] into the backup filename timestamp format:
/// YYYY-MM-DDTHH-MM-SS
String _ts(DateTime t) =>
    '${t.year}-${_pad(t.month)}-${_pad(t.day)}T'
    '${_pad(t.hour)}-${_pad(t.minute)}-${_pad(t.second)}';
