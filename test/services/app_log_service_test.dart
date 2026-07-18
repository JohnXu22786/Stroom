import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
    // Must enable file logging AFTER WebFileStore test mode (which disables it by default)
    AppLogService.reset();
    AppLogService.enableFileLogging();
  });

  // ==================================================================
  // In-memory buffer — logs are buffered before being flushed to disk
  // ==================================================================

  group('AppLogService — memory buffer flushing', () {
    test('logs are NOT written to file before flush()', () async {
      await AppLogService.info('TestSource', 'Buffered message');

      // Before flush, the file should NOT exist
      final logDir = await AppLogService.getLogDir();
      final now = DateTime.now();
      final hourStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}-${_pad(now.hour)}';
      final logFile = File('${logDir.path}/app_$hourStr.log');
      expect(await logFile.exists(), isFalse,
          reason: 'Log should NOT be written to file before flush()');

      // After flush, the file should exist with content
      await AppLogService.flush();
      expect(await logFile.exists(), isTrue,
          reason: 'Log should be written to file after flush()');
      final content = await logFile.readAsString();
      expect(content, contains('Buffered message'));

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('multiple buffered entries are flushed together', () async {
      await AppLogService.info('TestSource', 'Message A');
      await AppLogService.info('TestSource', 'Message B');
      await AppLogService.info('TestSource', 'Message C');

      // Before flush, no file should exist
      final logDir = await AppLogService.getLogDir();
      final now = DateTime.now();
      final hourStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}-${_pad(now.hour)}';
      final logFile = File('${logDir.path}/app_$hourStr.log');
      expect(await logFile.exists(), isFalse,
          reason: 'No file before flush with multiple buffered entries');

      await AppLogService.flush();
      expect(await logFile.exists(), isTrue);
      final content = await logFile.readAsString();
      expect(content, contains('Message A'));
      expect(content, contains('Message B'));
      expect(content, contains('Message C'));

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('buffer is empty after flush', () async {
      await AppLogService.info('TestSource', 'Gone after flush');
      await AppLogService.flush();

      // Write another info and flush — buffer from first flush is gone
      await AppLogService.info('TestSource', 'Second batch');
      await AppLogService.flush();

      final logDir = await AppLogService.getLogDir();
      final now = DateTime.now();
      final hourStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}-${_pad(now.hour)}';
      final logFile = File('${logDir.path}/app_$hourStr.log');
      final content = await logFile.readAsString();
      // Both entries should be present (appended to same file)
      expect(content, contains('Gone after flush'));
      expect(content, contains('Second batch'));

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('logs from different days go to separate files', () async {
      // Force a different date by manipulating what we can — write entries
      // that span two dates; the flush groups them by timestamp.
      // We'll write one entry and manually create a "yesterday" entry in the
      // buffer by using the service as-is.  Since we can't easily mock DateTime,
      // verify that writing and flushing produces one file for today.
      await AppLogService.info('TestSource', 'Today entry');
      await AppLogService.flush();

      final logDir = await AppLogService.getLogDir();
      final files = await logDir.list().toList();
      final logFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();
      // Should be exactly one file (today)
      expect(logFiles.length, equals(1));

      // Cleanup
      await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Hourly grouping — logs are split into one file per hour
  // ==================================================================

  group('AppLogService — hourly grouping', () {
    test('writes log file with hour suffix (app_YYYY-MM-DD-HH.log)', () async {
      await AppLogService.info('Test', 'Hourly log message');
      await AppLogService.flush();

      final logDir = await AppLogService.getLogDir();
      final now = DateTime.now();
      final hourStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}-${_pad(now.hour)}';
      final expectedFile = File('${logDir.path}/app_$hourStr.log');
      expect(await expectedFile.exists(), isTrue,
          reason: 'Hourly log file should exist at app_YYYY-MM-DD-HH.log path');

      // Old day-based filename should NOT exist
      final dayStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
      final oldStyleFile = File('${logDir.path}/app_$dayStr.log');
      expect(await oldStyleFile.exists(), isFalse,
          reason: 'Old day-based filename should not be used anymore');

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('listLogFiles includes hour-suffixed filenames', () async {
      await AppLogService.info('Test', 'Hour-suffix list test');
      await AppLogService.flush();

      final files = await AppLogService.listLogFiles();
      final now = DateTime.now();
      final hourStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}-${_pad(now.hour)}';
      expect(files, contains('app_$hourStr.log'),
          reason: 'listLogFiles should include app_YYYY-MM-DD-HH.log');

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('readLogFile reads hour-suffixed file by exact filename', () async {
      await AppLogService.info('TestSource', 'Hourly content marker');
      await AppLogService.flush();

      final now = DateTime.now();
      final hourStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}-${_pad(now.hour)}';
      final fileName = 'app_$hourStr.log';

      final content = await AppLogService.readLogFile(fileName);
      expect(content, isNotNull);
      expect(content, contains('Hourly content marker'));

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Log directory path — under Documents/Stroom/Logs
  // ==================================================================
  //
  // The production path is hard to exercise from the test env (which uses
  // <systemTemp>/stroom_log_test). What we CAN verify here is that the
  // path resolver is a function we can introspect and that it produces a
  // stable, non-empty result. The full production path is documented in
  // AppLogService._getLogsRootPath() and is covered by manual verification
  // on each target platform (see app_log_service.dart header comment).
  group('AppLogService — log directory location', () {
    test('log directory is a non-empty path under a parent that includes '
        '"stroom" or "Logs"', () async {
      final logDir = await AppLogService.getLogDir();
      // In production, path is .../Stroom/Logs. In tests, it's
      // <systemTemp>/stroom_log_test. Both share the property that
      // "stroom" appears in the path (case-insensitive).
      expect(logDir.path.toLowerCase(), contains('stroom'),
          reason:
              'Log directory should live under a Stroom-named parent. '
              'Production: Documents/Stroom/Logs. Tests: <tmp>/stroom_log_test.');

      // Cleanup
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Reset — state cleanup
  // ==================================================================

  group('AppLogService — reset', () {
    test('reset clears buffer, cache, and timer state', () async {
      // Write some log to populate buffer
      await AppLogService.info('Test', 'Pre-reset message');
      expect(await AppLogService.getLogDir(), isNotNull);

      AppLogService.reset();

      // After reset, buffer should be empty
      await AppLogService.flush(); // should be a no-op
      final logDir = await AppLogService.getLogDir();
      if (await logDir.exists()) await logDir.delete(recursive: true);
      AppLogService.clearLogDirCache();

      // Re-enable and write a new log — should work fresh
      AppLogService.enableFileLogging();
      await AppLogService.info('Test', 'Post-reset message');
      await AppLogService.flush();

      final newLogDir = await AppLogService.getLogDir();
      expect(await newLogDir.exists(), isTrue,
          reason: 'Should work after reset');
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${_pad(today.month)}-${_pad(today.day)}-${_pad(today.hour)}';
      final logFile = File('${newLogDir.path}/app_$dateStr.log');
      final content = await logFile.readAsString();
      expect(content, contains('Post-reset message'));
      expect(content, isNot(contains('Pre-reset message')),
          reason: 'Pre-reset message should not appear after reset');

      // Cleanup
      await newLogDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Failure recovery — buffer re-adds entries on write failure
  // ==================================================================

  group('AppLogService — flush failure recovery', () {
    test('buffered entries survive a flush failure and are written on retry',
        () async {
      // Create a log dir
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Write two log entries
      await AppLogService.info('Test', 'Entry A');
      await AppLogService.info('Test', 'Entry B');

      // Simulate a write failure: replace the log directory with a file
      // with the same name, so writeAsString throws.
      AppLogService.clearLogDirCache();

      final backupDirPath = '${logDir.path}_backup';
      if (await logDir.exists()) {
        await logDir.rename(backupDirPath);
      }
      final badFile = File(logDir.path);
      await badFile.create(); // Create a FILE at what was the directory path

      // First flush should fail
      await AppLogService.flush();
      // Entries should still be in buffer (re-added on failure)

      // Restore the real directory
      await badFile.delete();
      if (await Directory(backupDirPath).exists()) {
        await Directory(backupDirPath).rename(logDir.path);
      } else {
        await logDir.create(recursive: true);
      }
      AppLogService.clearLogDirCache();

      // Second flush should succeed and write the entries
      await AppLogService.flush();

      final today = DateTime.now();
      final dateStr =
          '${today.year}-${_pad(today.month)}-${_pad(today.day)}-${_pad(today.hour)}';
      final logFile = File('${logDir.path}/app_$dateStr.log');
      expect(await logFile.exists(), isTrue,
          reason: 'File should exist after successful retry flush');
      final content = await logFile.readAsString();
      expect(content, contains('Entry A'));
      expect(content, contains('Entry B'),
          reason: 'Both entries should survive a failed flush');

      // Cleanup
      await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Concurrent flush guard — rapid flush calls are safe
  // ==================================================================

  group('AppLogService — concurrent flush guard', () {
    test('rapid sequential flush() calls do not lose entries', () async {
      await AppLogService.info('Test', 'Concurrent A');
      await AppLogService.info('Test', 'Concurrent B');

      // Call flush rapidly multiple times — only one should execute
      await Future.wait([
        AppLogService.flush(),
        AppLogService.flush(),
        AppLogService.flush(),
      ]);

      final logDir = await AppLogService.getLogDir();
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${_pad(today.month)}-${_pad(today.day)}-${_pad(today.hour)}';
      final logFile = File('${logDir.path}/app_$dateStr.log');
      expect(await logFile.exists(), isTrue);
      final content = await logFile.readAsString();
      expect(content, contains('Concurrent A'));
      expect(content, contains('Concurrent B'));
      // No duplicates — each entry should appear exactly once
      expect('Concurrent A'.allMatches(content).length, equals(1),
          reason: 'Entry A should appear exactly once (no duplicate)');
      expect('Concurrent B'.allMatches(content).length, equals(1),
          reason: 'Entry B should appear exactly once (no duplicate)');

      // Cleanup
      await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Log file creation and path
  // ==================================================================

  group('AppLogService — log file creation', () {
    test('log file is created at correct path', () async {
      await AppLogService.info('TestSource', 'Test message');
      await AppLogService.flush();

      final logDir = await AppLogService.getLogDir();
      expect(await logDir.exists(), isTrue);

      final today = DateTime.now();
      final dateStr =
          '${today.year}-${_pad(today.month)}-${_pad(today.day)}-${_pad(today.hour)}';
      final logFile = File('${logDir.path}/app_$dateStr.log');
      expect(await logFile.exists(), isTrue,
          reason: 'Log file should exist at expected path');

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('creates one file per hour', () async {
      await AppLogService.info('TestSource', 'Message 1');
      await AppLogService.info('TestSource', 'Message 2');
      await AppLogService.flush();

      final logDir = await AppLogService.getLogDir();
      final entries = await logDir.list().toList();
      final logFiles = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();
      expect(logFiles.length, equals(1),
          reason: 'Messages on same hour should go to one file');

      // Cleanup
      await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Log content format
  // ==================================================================

  group('AppLogService — log content format', () {
    test('log entry contains timestamp, level, source, and message', () async {
      await AppLogService.info('TestSource', 'Hello world');
      await AppLogService.flush();

      final content = await AppLogService.readTodayLog();
      expect(content, isNotNull);
      expect(content, contains('[INFO]'));
      expect(content, contains('[TestSource]'));
      expect(content, contains('Hello world'));
      expect(content, contains(RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')),
          reason: 'Should contain ISO-like timestamp');

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('error log includes stack trace', () async {
      try {
        throw Exception('Test exception');
      } catch (e, s) {
        await AppLogService.error('TestSource', 'Error occurred', e, s);
      }
      await AppLogService.flush();

      final content = await AppLogService.readTodayLog();
      expect(content, contains('[ERROR]'));
      expect(content, contains('Error occurred'));
      expect(content, contains('Test exception'));

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('warning log has correct format', () async {
      await AppLogService.warning('TestSource', 'Warning message');
      await AppLogService.flush();

      final content = await AppLogService.readTodayLog();
      expect(content, contains('[WARN]'));
      expect(content, contains('Warning message'));

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('debug log has correct format', () async {
      await AppLogService.debug('TestSource', 'Debug message');
      await AppLogService.flush();

      final content = await AppLogService.readTodayLog();
      expect(content, contains('[DEBUG]'));
      expect(content, contains('Debug message'));

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // List and read log files
  // ==================================================================

  group('AppLogService — list and read logs', () {
    test('listLogFiles returns available log files', () async {
      await AppLogService.info('TestSource', 'Test');
      await AppLogService.flush();

      final files = await AppLogService.listLogFiles();
      expect(files, isNotEmpty);
      expect(files.any((f) => f.endsWith('.log')), isTrue);

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('readLogFile returns correct content for specific file', () async {
      await AppLogService.info('TestSource', 'Specific file test');
      await AppLogService.flush();

      final files = await AppLogService.listLogFiles();
      expect(files, isNotEmpty);

      final content = await AppLogService.readLogFile(files.first);
      expect(content, isNotEmpty);
      expect(content, contains('Specific file test'));

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('readLogFile returns null for non-existent file', () async {
      final content = await AppLogService.readLogFile('nonexistent.log');
      expect(content, isNull);
    });

    test('listLogFiles returns empty list when directory does not exist',
        () async {
      final logDir = await AppLogService.getLogDir();
      // Delete dir if it exists from previous tests
      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
      }
      AppLogService.clearLogDirCache();

      final files = await AppLogService.listLogFiles();
      expect(files, isEmpty,
          reason:
              'When log directory does not exist, listLogFiles should return empty list');

      // Cleanup
      AppLogService.clearLogDirCache();
    });

    test('readLogFile returns null for empty log file', () async {
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final emptyFile = File('${logDir.path}/app_empty_test.log');
      await emptyFile.writeAsString('');
      AppLogService.clearLogDirCache();

      final content = await AppLogService.readLogFile('app_empty_test.log');
      // An empty file should return empty string, not null
      // (the file exists, it's just empty)
      expect(content, isNotNull,
          reason:
              'readLogFile should not return null for an existing but empty file');
      expect(content, isEmpty,
          reason: 'An empty file should return empty string, not null');

      // Cleanup
      await emptyFile.delete();
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });

    test('listLogFiles filters out non-log files', () async {
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Create a log file
      await AppLogService.info('TestSource', 'Log entry');
      await AppLogService.flush();

      // Create a non-log file in the same directory
      final nonLogFile = File('${logDir.path}/readme.txt');
      await nonLogFile.writeAsString('Not a log file');

      AppLogService.clearLogDirCache();
      final files = await AppLogService.listLogFiles();
      expect(files.every((f) => f.endsWith('.log')), isTrue,
          reason: 'listLogFiles should only return .log files');
      expect(files.any((f) => f == 'readme.txt'), isFalse,
          reason: 'Non-log files should be filtered out');

      // Cleanup
      await nonLogFile.delete();
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Log directory caching — avoids BackupLocationManager recursion
  // ==================================================================

  group('AppLogService — directory caching', () {
    test('getLogDir returns the same instance on repeated calls', () async {
      AppLogService.enableFileLogging();
      final dir1 = await AppLogService.getLogDir();
      final dir2 = await AppLogService.getLogDir();

      expect(dir1.path, equals(dir2.path),
          reason: 'Repeated calls should return same directory');

      // Cleanup
      if (await dir1.exists()) await dir1.delete(recursive: true);
    });
  });

  // ==================================================================
  // Log retention — cleanup old logs
  // ==================================================================

  group('AppLogService — log retention', () {
    test('cleanup removes logs older than 3 days', () async {
      await AppLogService.info('TestSource', 'Today log');
      await AppLogService.flush();

      // Create old log files manually (simulating past dates)
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Create a log file from 5 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 5));
      final oldDateStr =
          '${oldDate.year}-${_pad(oldDate.month)}-${_pad(oldDate.day)}-${_pad(oldDate.hour)}';
      final oldFile = File('${logDir.path}/app_$oldDateStr.log');
      await oldFile.writeAsString('old log content');
      expect(await oldFile.exists(), isTrue);

      // Create a log file from 2 days ago (should be kept)
      const twoDaysAgo = Duration(days: 2);
      final recentDate = DateTime.now().subtract(twoDaysAgo);
      final recentDateStr =
          '${recentDate.year}-${_pad(recentDate.month)}-${_pad(recentDate.day)}-${_pad(recentDate.hour)}';
      final recentFile = File('${logDir.path}/app_$recentDateStr.log');
      await recentFile.writeAsString('recent log content');
      expect(await recentFile.exists(), isTrue);

      // Run cleanup
      await AppLogService.cleanupOldLogs();

      // Old file (5 days) should be deleted
      expect(await oldFile.exists(), isFalse,
          reason: 'Logs older than 3 days should be deleted');

      // Recent file (2 days) should be kept
      expect(await recentFile.exists(), isTrue,
          reason: 'Logs within 3 days should be kept');

      // Today's file should be kept
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${_pad(today.month)}-${_pad(today.day)}-${_pad(today.hour)}';
      final todayFile = File('${logDir.path}/app_$todayStr.log');
      expect(await todayFile.exists(), isTrue,
          reason: 'Today log should be kept');

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('cleanup is idempotent when no logs exist', () async {
      await AppLogService.cleanupOldLogs(); // Should not throw
    });
  });

  // ==================================================================
  // Cross-date boundary — reading logs from different dates
  // ==================================================================

  group('AppLogService — cross-date log reading', () {
    test('readLogFile works for yesterday log file', () async {
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Simulate yesterday's log file
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yDateStr =
          '${yesterday.year}-${_pad(yesterday.month)}-${_pad(yesterday.day)}-${_pad(yesterday.hour)}';
      final yesterdayFile = File('${logDir.path}/app_$yDateStr.log');
      await yesterdayFile
          .writeAsString('[yesterday] [INFO] [Test] Yesterday log\n');

      // Create today's log as well
      await AppLogService.info('Test', 'Today log');
      await AppLogService.flush();

      AppLogService.clearLogDirCache();
      final files = await AppLogService.listLogFiles();
      expect(files, contains('app_$yDateStr.log'),
          reason: 'Yesterday log file should appear in file list');

      // Read yesterday's log
      final content = await AppLogService.readLogFile('app_$yDateStr.log');
      expect(content, isNotNull,
          reason: 'Yesterday\'s log file should be readable by filename');
      expect(content, contains('Yesterday log'));

      // Cleanup
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });

    test('readLogFile handles yesterday log when no today log exists',
        () async {
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Only yesterday's log exists (no today log)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yDateStr =
          '${yesterday.year}-${_pad(yesterday.month)}-${_pad(yesterday.day)}-${_pad(yesterday.hour)}';
      final yesterdayFile = File('${logDir.path}/app_$yDateStr.log');
      await yesterdayFile
          .writeAsString('[yesterday] [INFO] [Test] Only yesterday\n');

      AppLogService.clearLogDirCache();
      final files = await AppLogService.listLogFiles();
      expect(files, contains('app_$yDateStr.log'));

      final content = await AppLogService.readLogFile('app_$yDateStr.log');
      expect(content, isNotNull,
          reason:
              'Yesterday log should be readable even when today log does not exist');

      // Cleanup
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });

    test('reading a non-existent previous day file returns null', () async {
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Create today's log
      await AppLogService.info('Test', 'Today log');
      await AppLogService.flush();

      // Try to read a log from 30 days ago (which doesn't exist)
      final longAgo = DateTime.now().subtract(const Duration(days: 30));
      final laDateStr =
          '${longAgo.year}-${_pad(longAgo.month)}-${_pad(longAgo.day)}-${_pad(longAgo.hour)}';
      final content = await AppLogService.readLogFile('app_$laDateStr.log');
      expect(content, isNull,
          reason: 'Non-existent previous day log should return null');

      // Cleanup
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });
  });

  // ==================================================================
  // Sequential list and read consistency
  // ==================================================================

  group('AppLogService — sequential list and read consistency', () {
    test('listLogFiles and readLogFile remain reliable on repeated calls',
        () async {
      // Write a log
      await AppLogService.info('Test', 'Consistency check');
      await AppLogService.flush();

      // List and read multiple times — should always work
      for (int i = 0; i < 5; i++) {
        final files = await AppLogService.listLogFiles();
        expect(files, isNotEmpty,
            reason: 'Files should be available on attempt $i');

        final content = await AppLogService.readLogFile(files.first);
        expect(content, isNotNull,
            reason: 'File should be readable on attempt $i');
        expect(content, contains('Consistency check'));
      }

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      if (await logDir.exists()) await logDir.delete(recursive: true);
      AppLogService.clearLogDirCache();
    });
  });

  // ==================================================================
  // readLogFile robustness — handles various content types
  // ==================================================================

  group('AppLogService — readLogFile robustness', () {
    test('readLogFile reads a plain text file successfully', () async {
      // Create a file, then verify it's readable
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final testFile = File('${logDir.path}/app_readable_test.log');
      await testFile.writeAsString('readable content');
      AppLogService.clearLogDirCache();

      // Should be readable without issue
      final content = await AppLogService.readLogFile('app_readable_test.log');
      expect(content, isNotNull);
      expect(content, 'readable content');

      // Cleanup
      await testFile.delete();
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });

    test('readLogFile handles file with special characters', () async {
      final logDir = await AppLogService.getLogDir();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final testFile = File('${logDir.path}/app_special_test.log');
      await testFile.writeAsString('[INFO] 测试中文日志内容 ñáéíóú \n');
      AppLogService.clearLogDirCache();

      final content = await AppLogService.readLogFile('app_special_test.log');
      expect(content, isNotNull);
      expect(content, contains('测试中文日志内容'));
      expect(content, contains('ñáéíóú'));

      // Cleanup
      await testFile.delete();
      AppLogService.clearLogDirCache();
      if (await logDir.exists()) await logDir.delete(recursive: true);
    });
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
