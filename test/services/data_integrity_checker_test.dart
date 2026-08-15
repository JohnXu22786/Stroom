import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_integrity_checker.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String appDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppStorage.resetCache();
    appDir = await AppStorage.directory;
  });

  tearDown(() async {
    // 清理本测试创建的脏数据文件
    for (final rel in [
      'synthesis/tasks.json',
      'catcatch/tasks.json',
      'background/tasks.json',
      'task_flows/flows.json',
      'task_flows/executions.json',
      'browser_cookies.json',
    ]) {
      final f = File(p.join(appDir, rel));
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  });

  group('DataIntegrityChecker', () {
    test('clean data reports no corruption', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '[]',
        'provider_entries': '[{"id":"a","type":"x","name":"n"}]',
        'data_format_versions': '{"chat":1}',
      });
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.hasCorruption, isFalse, reason: '${report.issues}');
    });

    test('corrupt conversations JSON is reported', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': '{not-valid-json',
      });
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.hasCorruption, isTrue);
      final hit = report.corruptions
          .where((i) => i.message.contains('conversations'))
          .toList();
      expect(hit, isNotEmpty);
    });

    test(
        'corrupt provider_entries structure is reported (as Map crash '
        'guard)', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': '[{"id":123,"type":"x"}]', // id 非字符串
      });
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.hasCorruption, isTrue);
    });

    test('corrupt data_format_versions is reported', () async {
      SharedPreferences.setMockInitialValues({
        'data_format_versions': 'not-json{{{',
      });
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(
          report.corruptions
              .any((i) => i.message.contains('data_format_versions')),
          isTrue);
    });

    test('corrupt synthesis/tasks.json is reported', () async {
      final f = File(p.join(appDir, 'synthesis', 'tasks.json'));
      await f.create(recursive: true);
      await f.writeAsString('[{broken');
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.corruptions.any((i) => i.message.contains('synthesis')),
          isTrue);
    });

    test('corrupt task_flows/executions.json is reported', () async {
      final f = File(p.join(appDir, 'task_flows', 'executions.json'));
      await f.create(recursive: true);
      await f.writeAsString('not json at all');
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.corruptions.any((i) => i.message.contains('executions')),
          isTrue);
    });

    test('corrupt browser_cookies.json is reported', () async {
      final f = File(p.join(appDir, 'browser_cookies.json'));
      await f.writeAsString('{oops');
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(
          report.corruptions.any((i) => i.message.contains('browser_cookies')),
          isTrue);
    });

    test('missing files are not corruption (fresh install)', () async {
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.hasCorruption, isFalse);
    });

    test('valid JSON in files is not corruption', () async {
      final f = File(p.join(appDir, 'catcatch', 'tasks.json'));
      await f.create(recursive: true);
      await f.writeAsString('[]');
      final report = await DataIntegrityChecker.checkCurrentData();
      expect(report.hasCorruption, isFalse);
    });
  });
}
