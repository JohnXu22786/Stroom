import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  test('serializes overlapping restores that reuse a credential ref', () async {
    const selection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: true,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    const reference = 'shared-restore-credential-reference';
    const firstSecret = 'sk_first_overlapping_restore_secret';
    const secondSecret = 'sk_second_overlapping_restore_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: selection,
    );

    Uint8List backupFor(String providerName, String secret) {
      final archive = ZipDecoder().decodeBytes(baseBackup);
      final settingsFile = archive.findFile('settings.json')!;
      final settings =
          jsonDecode(utf8.decode(settingsFile.content as List<int>))
              as Map<String, dynamic>;
      settings['provider_entries'] = jsonEncode([
        {
          'id': 'restore-llm-entry',
          'type': 'llm',
          'configs': [
            {
              'id': 'shared-restore-account',
              'providerName': providerName,
              'host': 'https://shared-restore.example.test',
              'credentialRef': reference,
              'key': secret,
              'models': [
                {'modelId': 'shared-restore-model'},
              ],
            },
          ],
        },
      ]);
      archive.removeFile(settingsFile);
      final encodedSettings = utf8.encode(jsonEncode(settings));
      archive.addFile(
        ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
      );
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    final firstStaged = Completer<void>();
    final releaseFirst = Completer<void>();
    final credentialStore = _BackupCredentialStore();
    var secondCompletedBeforeFirstCommit = false;

    final firstRestore = BackupService.restoreFromBytesForTest(
      backupFor('First provider', firstSecret),
      selection: selection,
      skipPostRestoreMigration: true,
      credentialStore: credentialStore,
      afterCredentialStagingForTest: () async {
        firstStaged.complete();
        await releaseFirst.future;
      },
    );
    await firstStaged.future.timeout(const Duration(seconds: 2));

    final secondRestore = BackupService.restoreFromBytesForTest(
      backupFor('Second provider', secondSecret),
      selection: selection,
      skipPostRestoreMigration: true,
      credentialStore: credentialStore,
    );
    try {
      await secondRestore.timeout(const Duration(milliseconds: 500));
      secondCompletedBeforeFirstCommit = true;
    } on TimeoutException {
      // A queued restore must wait until the first preferences commit.
    }

    releaseFirst.complete();
    await Future.wait([firstRestore, secondRestore]);

    expect(secondCompletedBeforeFirstCommit, isFalse);
    final restoredEntries =
        jsonDecode(prefs.getString('provider_entries')!) as List;
    final restoredConfig =
        ((restoredEntries.single as Map)['configs'] as List).single as Map;
    expect(restoredConfig['providerName'], 'Second provider');
    expect(restoredConfig['credentialRef'], reference);
    expect(restoredConfig.containsKey('key'), isFalse);
    expect(await credentialStore.read(reference), secondSecret);
  });

  test(
      'rechecks secure credential refs after waiting for the transaction lease',
      () async {
    const selection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: true,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    const reference = 'shared-restore-migration-race-reference';
    const backupSecret = 'sk_preflighted_restore_secret';
    const concurrentSecret = 'sk_concurrent_migration_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: selection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'referenced-provider-entry',
        'type': 'llm',
        'configs': [
          {
            'id': 'referenced-provider-config',
            'providerName': 'Shared migration provider',
            'host': 'https://migration-race.example.test',
            'credentialRef': reference,
            'models': [
              {'modelId': 'migration-race-model'},
            ],
          },
        ],
      },
    ]);
    settings['chat_configs'] = jsonEncode([
      {
        'providerName': 'Shared migration provider',
        'host': 'https://migration-race.example.test',
        'key': backupSecret,
        'models': [
          {'modelId': 'migration-race-model'},
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );

    final credentials = _RacingCredentialStore(reference, backupSecret);
    final restore = BackupService.restoreFromBytesForTest(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      selection: selection,
      skipPostRestoreMigration: true,
      credentialStore: credentials,
    );
    await credentials.preflightReadStarted.future
        .timeout(const Duration(seconds: 2));

    await LlmAccountMigrationService(
      preferences: _SharedPreferencesLlmPreferences(prefs),
      credentialStore: credentials,
    ).migrate(
      sourceProviderEntriesJson: jsonEncode([
        {
          'id': 'concurrent-migration-entry',
          'type': 'llm',
          'configs': [
            {
              'id': 'concurrent-migration-config',
              'providerName': 'Concurrent migration provider',
              'host': 'https://concurrent-migration.example.test',
              'credentialRef': reference,
              'key': concurrentSecret,
              'models': [
                {'modelId': 'concurrent-model'},
              ],
            },
          ],
        },
      ]),
    );
    credentials.releasePreflightRead.complete();

    await expectLater(restore, throwsA(isA<BackupValidationException>()));
    expect(await credentials.read(reference), concurrentSecret);
  });

  test('rolls back secure credentials when a preference write returns false',
      () async {
    const selection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: true,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    const reference = 'failed-preference-restore-reference';
    const secret = 'sk_failed_preference_restore_secret';
    SharedPreferences.setMockInitialValues({'provider_entries': '[]'});
    final prefs = await SharedPreferences.getInstance();
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: selection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'failed-preference-entry',
        'type': 'llm',
        'configs': [
          {
            'id': 'failed-preference-config',
            'providerName': 'Failed preference provider',
            'host': 'https://failed-preference.example.test',
            'credentialRef': reference,
            'key': secret,
            'models': [
              {'modelId': 'failed-preference-model'},
            ],
          },
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );

    final originalStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance =
        _RejectProviderEntriesWriteStore({'flutter.provider_entries': '[]'});
    await prefs.reload();
    final credentials = _BackupCredentialStore();
    try {
      await expectLater(
        BackupService.restoreFromBytesForTest(
          Uint8List.fromList(ZipEncoder().encode(archive)),
          selection: selection,
          skipPostRestoreMigration: true,
          credentialStore: credentials,
        ),
        throwsA(isA<StateError>()),
      );
      await prefs.reload();
      expect(prefs.getString('provider_entries'), '[]');
      expect(await credentials.read(reference), isNull);
    } finally {
      SharedPreferencesStorePlatform.instance = originalStore;
      await prefs.reload();
    }
  });

  test('retains staged credentials when preference rollback also fails',
      () async {
    const selection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: true,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
    );
    const reference = 'incomplete-preference-rollback-reference';
    const secret = 'sk_incomplete_preference_rollback_secret';
    SharedPreferences.setMockInitialValues({'provider_entries': '[]'});
    final prefs = await SharedPreferences.getInstance();
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: selection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'incomplete-rollback-entry',
        'type': 'llm',
        'configs': [
          {
            'id': 'incomplete-rollback-config',
            'providerName': 'Incomplete rollback provider',
            'host': 'https://incomplete-rollback.example.test',
            'credentialRef': reference,
            'key': secret,
            'models': [
              {'modelId': 'incomplete-rollback-model'},
            ],
          },
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );

    final originalStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _RejectProviderEntriesWriteStore(
      {'flutter.provider_entries': '[]'},
      rejectedProviderEntriesWrites: 2,
    );
    await prefs.reload();
    final credentials = _BackupCredentialStore();
    try {
      await expectLater(
        BackupService.restoreFromBytesForTest(
          Uint8List.fromList(ZipEncoder().encode(archive)),
          selection: selection,
          skipPostRestoreMigration: true,
          credentialStore: credentials,
        ),
        throwsA(isA<StateError>()),
      );
      await prefs.reload();
      expect(prefs.containsKey('provider_entries'), isFalse);
      expect(await credentials.read(reference) == secret, isTrue);
    } finally {
      SharedPreferencesStorePlatform.instance = originalStore;
      await prefs.reload();
    }
  });
}

class _BackupCredentialStore implements LlmCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}

class _RacingCredentialStore implements LlmCredentialStore {
  _RacingCredentialStore(this.pausedReference, this.initialSecret);

  final String pausedReference;
  final String initialSecret;
  final preflightReadStarted = Completer<void>();
  final releasePreflightRead = Completer<void>();
  final Map<String, String> values = {};
  var _pauseFirstRead = true;

  @override
  Future<String?> read(String reference) async {
    if (_pauseFirstRead && reference == pausedReference) {
      _pauseFirstRead = false;
      final observedBeforePause = values[reference] ?? initialSecret;
      preflightReadStarted.complete();
      await releasePreflightRead.future;
      return observedBeforePause;
    }
    return values[reference] ?? initialSecret;
  }

  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}

class _SharedPreferencesLlmPreferences implements LlmAccountPreferences {
  _SharedPreferencesLlmPreferences(this.preferences);

  final SharedPreferences preferences;

  @override
  Future<String?> getString(String key) async => preferences.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      preferences.setString(key, value);

  @override
  Future<bool> remove(String key) => preferences.remove(key);
}

class _RejectProviderEntriesWriteStore extends InMemorySharedPreferencesStore {
  _RejectProviderEntriesWriteStore(
    Map<String, Object> values, {
    this.rejectedProviderEntriesWrites = 1,
  }) : super.withData(values);

  int rejectedProviderEntriesWrites;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (valueType == 'String' &&
        key == 'flutter.provider_entries' &&
        rejectedProviderEntriesWrites > 0) {
      rejectedProviderEntriesWrites--;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
