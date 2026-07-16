import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The app_log_service_test tests file-based logging, so ensure file I/O is enabled
    AppLogService.enableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
  });

  // ==================================================================
  // Log file creation and path
  // ==================================================================

  group('AppLogService — log file creation', () {
    test('log file is created at correct path', () async {
      await AppLogService.info('TestSource', 'Test message');

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

      final content = await AppLogService.readTodayLog();
      expect(content, contains('[WARN]'));
      expect(content, contains('Warning message'));

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('debug log has correct format', () async {
      await AppLogService.debug('TestSource', 'Debug message');

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

      final files = await AppLogService.listLogFiles();
      expect(files, isNotEmpty);
      expect(files.any((f) => f.endsWith('.log')), isTrue);

      // Cleanup
      final logDir = await AppLogService.getLogDir();
      await logDir.delete(recursive: true);
    });

    test('readLogFile returns correct content for specific file', () async {
      await AppLogService.info('TestSource', 'Specific file test');

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
  });

  // ==================================================================
  // Log retention — cleanup old logs
  // ==================================================================

  group('AppLogService — log retention', () {
    test('cleanup removes logs older than 3 days', () async {
      await AppLogService.info('TestSource', 'Today log');

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
}

String _pad(int n) => n.toString().padLeft(2, '0');
