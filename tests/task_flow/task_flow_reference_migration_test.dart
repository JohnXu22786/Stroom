import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flow_migration_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
    ManifestDatabase.enableTestMode();
    // These migration fixtures deliberately exercise the native flow file,
    // unlike backup widget tests which use the in-memory storage backend.
    WebFileStore.disableTestMode();
    SharedPreferences.setMockInitialValues({
      'data_format_versions': jsonEncode({
        ...DataParts.currentVersions,
        DataParts.settings: 1,
        DataParts.tasks: 0
      }),
      'provider_entries': jsonEncode([
        {
          'id': 'entry',
          'type': 'tts',
          'name': 'TTS',
          'configs': [
            {
              'host': 'https://example.com',
              'key': 'secret-key',
              'models': [
                {'name': 'Model', 'modelId': 'remote-model'},
                {'name': 'Same API model', 'modelId': 'remote-model'},
              ]
            },
          ]
        },
      ]),
    });
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  testWidgets(
      'memory-backed restore never migrates unrelated native flow files',
      (tester) async {
    final file = File('${directory.path}/task_flows/flows.json');
    await tester.runAsync(() async {
      await file.parent.create(recursive: true);
      await file.writeAsString('unrelated-native-data');
    });
    WebFileStore.enableTestMode();
    final result = await DataMigrationService.migrateDataFormatIfNeeded();
    expect(result.needsMigration, isTrue);
    expect(await tester.runAsync(file.readAsString), 'unrelated-native-data');
  });

  test('startup migration persists unique identities once and is idempotent',
      () async {
    final result = await DataMigrationService.migrateDataFormatIfNeeded();
    expect(result.needsMigration, isTrue);
    expect(result.restartRequired, isTrue);
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('provider_entries')!;
    final config = (jsonDecode(encoded) as List).single['configs'].single;
    expect(config['id'], isA<String>());
    final models = config['models'] as List;
    expect(models[0]['id'], isA<String>());
    expect(models[0]['id'], isNot(models[1]['id']));
    expect(config['key'], 'secret-key');
    await prefs.setString(
        'data_format_versions',
        jsonEncode({
          ...DataParts.currentVersions,
          DataParts.settings: 1,
          DataParts.tasks: 0
        }));
    await DataMigrationService.migrateDataFormatIfNeeded();
    expect(prefs.getString('provider_entries'), encoded);
  });

  test('flat legacy provider configs receive durable IDs before loading',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'provider_entries',
        jsonEncode([
          {
            'id': 'old-entry',
            'name': 'Old',
            'type': 'tts',
            'providerName': 'Provider',
            'host': 'https://example.com',
            'key': 'secret',
            'models': [
              {'name': 'Model', 'modelId': 'remote-model'}
            ]
          },
        ]));
    await DataMigrationService.migrateDataFormatIfNeeded();
    final entry =
        (jsonDecode(prefs.getString('provider_entries')!) as List).single;
    expect(entry['id'], 'old-entry');
    expect(entry.containsKey('key'), isFalse);
    expect(entry['configs'].single['key'], 'secret');
    expect(entry['configs'].single['id'], isA<String>());
    expect(entry['configs'].single['models'].single['id'], isA<String>());
  });

  test('a failed flow migration retries without changing persisted identities',
      () async {
    final dir = await Directory('${directory.path}/task_flows').create();
    final file =
        await File('${dir.path}/flows.json').writeAsString('broken-json');
    await expectLater(DataMigrationService.migrateDataFormatIfNeeded(),
        throwsFormatException);
    final prefs = await SharedPreferences.getInstance();
    final identities = prefs.getString('provider_entries');
    final versions = await DataMigrationService.getStoredPartVersions();
    expect(versions[DataParts.settings], 1);
    expect(versions[DataParts.tasks], 0);
    expect(await file.readAsString(), 'broken-json');
    await file.writeAsString('[]');
    await DataMigrationService.migrateDataFormatIfNeeded();
    expect(prefs.getString('provider_entries'), identities);
    expect(
        (await DataMigrationService.getStoredPartVersions())[DataParts.tasks],
        DataParts.currentVersions[DataParts.tasks]);
  });

  test(
      'legacy indices require reselection without losing other params or copying secrets',
      () async {
    final dir = await Directory('${directory.path}/task_flows').create();
    final file = File('${dir.path}/flows.json');
    await file.writeAsString(jsonEncode([
      {
        'id': 'flow',
        'name': 'Old',
        'blocks': [
          for (final index in [0, -1, 99, 'bad'])
            {
              'id': 'block-$index',
              'typeKey': 'tts',
              'params': {'modelIndex': index, 'voice': 'v', 'speed': 1.2}
            },
          {
            'id': 'modern',
            'typeKey': 'tts',
            'params': {
              'modelRef': {'configId': 'c', 'modelId': 'm'}
            }
          },
        ]
      },
    ]));
    await DataMigrationService.migrateDataFormatIfNeeded();
    final encoded = await file.readAsString();
    final blocks = (jsonDecode(encoded) as List).single['blocks'] as List;
    for (final block in blocks.take(4)) {
      final params = block['params'];
      expect(params.containsKey('modelIndex'), isFalse);
      expect(params['modelRef'], isNull);
      expect(params['modelSelectionRequired'], isTrue);
      expect(params['voice'], 'v');
      expect(params['speed'], 1.2);
    }
    expect(
        blocks.last['params']['modelRef'], {'configId': 'c', 'modelId': 'm'});
    expect(encoded, isNot(contains('secret-key')));
    await DataMigrationService.migrateDataFormatIfNeeded();
    expect(await file.readAsString(), encoded);
  });
}
