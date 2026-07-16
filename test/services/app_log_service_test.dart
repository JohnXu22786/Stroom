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
    AppLogService.enableFileLogging();
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
      final dateStr = '${today.year}-${_pad(today.month)}-${_pad(today.day)}';
      final logFile = File('${logDir.path}/app_$dateStr.log');
      expect(await logFile.exists(), isTrue,
          reason: 'Log file should exist at expected path');

      // Cleanup
      await logDir.delete(recursive: true);
    });

    test('creates one file per day', () async {
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
          reason: 'Messages on same day should go to one file');

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
          '${oldDate.year}-${_pad(oldDate.month)}-${_pad(oldDate.day)}';
      final oldFile = File('${logDir.path}/app_$oldDateStr.log');
      await oldFile.writeAsString('old log content');
      expect(await oldFile.exists(), isTrue);

      // Create a log file from 2 days ago (should be kept)
      const twoDaysAgo = Duration(days: 2);
      final recentDate = DateTime.now().subtract(twoDaysAgo);
      final recentDateStr =
          '${recentDate.year}-${_pad(recentDate.month)}-${_pad(recentDate.day)}';
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
      final todayStr = '${today.year}-${_pad(today.month)}-${_pad(today.day)}';
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
          '${yesterday.year}-${_pad(yesterday.month)}-${_pad(yesterday.day)}';
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
          '${yesterday.year}-${_pad(yesterday.month)}-${_pad(yesterday.day)}';
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
          '${longAgo.year}-${_pad(longAgo.month)}-${_pad(longAgo.day)}';
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
}

String _pad(int n) => n.toString().padLeft(2, '0');
