import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

const _settingsAndTextRestoreSelection = BackupSelection(
  chatRecordsAndAttachments: false,
  settings: true,
  pictures: false,
  audio: false,
  videos: false,
  texts: true,
  tasks: false,
  ankiData: false,
  browserCookies: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Disable file logging for testWidgets (FakeAsync zone doesn't support file I/O)
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  testWidgets('LLM credentials migrate out of ordinary backup exports',
      (WidgetTester t) async {
    const secret = 'sk_export_boundary_secret_8632';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'llm-entry',
          'type': 'llm',
          'name': 'LLM providers',
          'configs': [
            {
              'id': 'provider-config-export',
              'providerName': 'Test provider',
              'host': 'https://api.example.test',
              'key': secret,
              'endpointType': 'openai',
              'models': [
                {
                  'name': 'Example model',
                  'modelId': 'example-model',
                  'supportStream': true,
                  'typeConfig': <String, dynamic>{},
                  'customParams': <Map<String, dynamic>>[],
                  'reasoningParams': <Map<String, dynamic>>[],
                },
              ],
              'customParams': <Map<String, dynamic>>[],
              'reasoningParams': <Map<String, dynamic>>[],
            },
          ],
        },
      ]),
    );
    await prefs.setString(
      'provider_entries_corrupt_123',
      jsonEncode([
        {
          'type': 'llm',
          'configs': [
            {'id': 'quarantined-config', 'key': secret},
          ],
        },
      ]),
    );
    await LlmAccountMigrationService(
      preferences: _BackupLlmPreferences(prefs),
      credentialStore: _BackupCredentialStore(),
    ).migrate();

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(secret), isFalse);
    expect(exportedText, contains('provider-config-export'));
    expect(exportedText, contains('credentialRef'));
  });

  testWidgets('legacy LLM credentials are redacted from backup exports',
      (WidgetTester t) async {
    const secret = 'sk_unmigrated_export_secret_2718';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'legacy-llm-entry',
          'type': 'llm',
          'name': 'Legacy LLM providers',
          'key': secret,
          'configs': [
            {
              'id': 'legacy-provider-config',
              'providerName': 'Legacy provider',
              'host': 'https://api.example.test',
              'key': secret,
              'models': [
                {
                  'id': 'legacy-model',
                  'modelId': 'legacy-model-id',
                },
              ],
            },
          ],
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(secret), isFalse);
    expect(exportedText, contains('legacy-provider-config'));
    expect(exportedText, contains('legacy-model-id'));
    expect(prefs.getString('provider_entries'), contains(secret));
  });

  testWidgets(
      'redacts nested model credentials while preserving safe model data',
      (WidgetTester t) async {
    const secret = 'sk_nested_model_subscription_secret';
    const secretKeyValue = 'sk_nested_model_secret_key_value';
    const authKeyValue = 'sk_nested_model_auth_key_value';
    const functionsKeyValue = 'sk_nested_model_functions_key_value';
    const proxyAuthorizationValue = 'sk_nested_model_proxy_authorization_value';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'model-provider-entry',
          'type': 'llm',
          'name': 'Preserved provider',
          'configs': [
            {
              'id': 'model-provider-config',
              'providerName': 'Safe provider',
              'models': [
                {
                  'id': 'safe-model',
                  'modelId': 'safe-model-id',
                  'name': 'Preserved model name',
                  'headers': {
                    'Ocp-Apim-Subscription-Key': secret,
                    'x-functions-key': functionsKeyValue,
                    'proxy-authorization': proxyAuthorizationValue,
                  },
                  'options': {
                    'authorizationHeader': secret,
                    'temperature': 0.25,
                  },
                  'secretKey': secretKeyValue,
                  'authKey': authKeyValue,
                  'publicKey': 'public-key-metadata',
                },
              ],
            },
          ],
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(secret), isFalse);
    expect(exportedText.contains(secretKeyValue), isFalse);
    expect(exportedText.contains(authKeyValue), isFalse);
    expect(exportedText.contains(functionsKeyValue), isFalse);
    expect(exportedText.contains(proxyAuthorizationValue), isFalse);
    expect(exportedText, contains('safe-model-id'));
    expect(exportedText, contains('Preserved model name'));
    expect(exportedText, contains('temperature'));
    expect(exportedText, contains('public-key-metadata'));
  });

  testWidgets(
      'sanitizes missing and unknown provider types and legacy chat configs',
      (WidgetTester t) async {
    const missingTypeSecret = 'sk_missing_provider_type_secret';
    const unknownTypeSecret = 'sk_unknown_provider_type_secret';
    const legacyConfigSecret = 'sk_legacy_chat_config_secret';
    const nestedLegacySecret = 'sk_legacy_chat_nested_secret';
    const quarantinedLegacySecret = 'sk_quarantined_chat_config_secret';
    const credentialKeySecret = 'sk_credential_key_field_secret';
    const apiSecretKeySecret = 'sk_api_secret_key_field_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'provider-without-type',
          'name': 'Keep missing-type data',
          'apiKey': missingTypeSecret,
        },
        {
          'id': 'provider-with-unknown-type',
          'type': 'custom-provider',
          'name': 'Keep custom provider data',
          'headers': {
            'authorizationHeader': unknownTypeSecret,
            'credentialKey': credentialKeySecret,
            'apiSecretKey': apiSecretKeySecret,
          },
        },
      ]),
    );
    await prefs.setString(
      'chat_configs',
      jsonEncode([
        {
          'providerName': 'Legacy provider',
          'host': 'https://legacy.example.test',
          'key': legacyConfigSecret,
          'credentialRef': 'safe-legacy-credential-reference',
          'publicKey': 'safe-legacy-public-key',
          'models': [
            {
              'modelId': 'safe-legacy-model-id',
              'headers': {'Ocp-Apim-Subscription-Key': nestedLegacySecret},
            },
          ],
        },
      ]),
    );
    await prefs.setString(
      'chat_configs_corrupt_123',
      jsonEncode([
        {
          'providerName': 'Quarantined legacy config',
          'key': quarantinedLegacySecret
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(missingTypeSecret), isFalse);
    expect(exportedText.contains(unknownTypeSecret), isFalse);
    expect(exportedText.contains(legacyConfigSecret), isFalse);
    expect(exportedText.contains(nestedLegacySecret), isFalse);
    expect(exportedText.contains(quarantinedLegacySecret), isFalse);
    expect(exportedText.contains(credentialKeySecret), isFalse);
    expect(exportedText.contains(apiSecretKeySecret), isFalse);
    expect(exportedText, contains('provider-without-type'));
    expect(exportedText, contains('provider-with-unknown-type'));
    expect(exportedText, contains('safe-legacy-model-id'));
    expect(exportedText, contains('safe-legacy-credential-reference'));
    expect(exportedText, contains('safe-legacy-public-key'));
  });

  testWidgets('redacts authentication cookies from custom provider backups',
      (WidgetTester t) async {
    const cookie = 'session=sk_cookie_export_secret';
    const setCookie = 'auth=sk_set_cookie_export_secret; HttpOnly';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'custom-cookie-provider',
          'type': 'custom-provider',
          'headers': {
            'Cookie': cookie,
            'Set-Cookie': setCookie,
          },
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(cookie), isFalse);
    expect(exportedText.contains(setCookie), isFalse);
    expect(exportedText, contains('custom-cookie-provider'));
  });

  testWidgets('redacts credentials from LLM account and group backups',
      (WidgetTester t) async {
    const accountSecret = 'sk_account_envelope_export_secret';
    const groupSecret = 'sk_group_envelope_export_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      LlmAccountMigrationService.accountsPreferenceKey,
      jsonEncode({
        'version': 1,
        'items': [
          {
            'id': 'safe-account-id',
            'credentialRef': 'safe-account-reference',
            'apiKey': accountSecret,
          },
        ],
        'authorizationHeader': accountSecret,
      }),
    );
    await prefs.setString(
      LlmAccountMigrationService.modelGroupsPreferenceKey,
      jsonEncode({
        'version': 1,
        'items': [
          {
            'id': 'safe-group-id',
            'members': [
              {'accountId': 'safe-account-id', 'token': groupSecret},
            ],
          },
        ],
      }),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(accountSecret), isFalse);
    expect(exportedText.contains(groupSecret), isFalse);
    expect(exportedText, contains('safe-account-id'));
    expect(exportedText, contains('safe-account-reference'));
    expect(exportedText, contains('safe-group-id'));

    const malformedEnvelopeSecret = 'sk_malformed_llm_envelope_export_secret';
    await prefs.setString(
      LlmAccountMigrationService.accountsPreferenceKey,
      jsonEncode(malformedEnvelopeSecret),
    );
    final malformedBackup = await BackupService.buildBackupBytesForTest();
    final malformedArchive = ZipDecoder().decodeBytes(malformedBackup);
    final malformedExportedText = malformedArchive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');
    expect(malformedExportedText.contains(malformedEnvelopeSecret), isFalse);
  });

  testWidgets('redacts credentials from MCP provider backups',
      (WidgetTester t) async {
    const apiKey = 'sk_mcp_backup_api_key_secret';
    const headerSecret = 'sk_mcp_backup_authorization_secret';
    const environmentSecret = 'sk_mcp_backup_environment_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'mcp-provider-entry',
          'type': 'mcp',
          'name': 'MCP provider',
          'typeConfig': {
            'apiKey': apiKey,
            'headers': {'Authorization': headerSecret},
            'environment': {'MCP_API_TOKEN': environmentSecret},
            'command': 'safe-command',
          },
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText.contains(apiKey), isFalse);
    expect(exportedText.contains(headerSecret), isFalse);
    expect(exportedText.contains(environmentSecret), isFalse);
    expect(exportedText, contains('mcp-provider-entry'));
    expect(exportedText, contains('safe-command'));
  });

  testWidgets(
      'preflights ambiguous legacy chat configs before files or database change',
      (WidgetTester t) async {
    final prefs = await SharedPreferences.getInstance();
    const importedText = 'this-text-must-not-be-restored';
    await TextManifest.writeText('imported-text-hash.txt', importedText);
    await ManifestDatabase.insertTextRecord({
      'id': 'imported-text-record',
      'name': 'Imported text',
      'hash': 'imported-text-hash',
      'format': 'txt',
      'createdAt': DateTime.now().toIso8601String(),
      'size': importedText.length,
      'folder': '',
      'textLength': importedText.length,
    });
    await prefs.setString('provider_entries', '[]');

    final validBackup = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(validBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['chat_configs'] = jsonEncode([
      {
        'providerName': 'Ambiguous provider',
        'host': 'https://api.example.test',
        'key': 'sk_first_ambiguous_legacy_key',
        'models': [
          {'modelId': 'same-model'},
        ],
      },
      {
        'providerName': 'Ambiguous provider',
        'host': 'https://api.example.test',
        'key': 'sk_second_ambiguous_legacy_key',
        'models': [
          {'modelId': 'same-model'},
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final invalidSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
        ArchiveFile('settings.json', invalidSettings.length, invalidSettings));
    final backup = Uint8List.fromList(ZipEncoder().encode(archive));

    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
    await TextManifest.deleteFile('imported-text-hash.txt');
    const existingText = 'keep-this-existing-text';
    await TextManifest.writeText('existing-text-hash.txt', existingText);
    await ManifestDatabase.insertTextRecord({
      'id': 'existing-text-record',
      'name': 'Existing text',
      'hash': 'existing-text-hash',
      'format': 'txt',
      'createdAt': DateTime.now().toIso8601String(),
      'size': existingText.length,
      'folder': '',
      'textLength': existingText.length,
    });

    await expectLater(
      BackupService.restoreFromBytesForTest(
        backup,
        selection: _settingsAndTextRestoreSelection,
      ),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.message,
          'message',
          '备份中的 LLM 设置无效或存在歧义。未更改本机数据。',
        ),
      ),
    );

    final textRecords = await ManifestDatabase.getAllTextRecords();
    expect(textRecords.map((record) => record['id']),
        contains('existing-text-record'));
    expect(textRecords.map((record) => record['id']),
        isNot(contains('imported-text-record')));
    expect(await TextManifest.readText('existing-text-hash.txt'), existingText);
    expect(await TextManifest.readText('imported-text-hash.txt'), isNull);
  });

  testWidgets(
      'preflights malformed selected LLM settings before files or database change',
      (WidgetTester t) async {
    final prefs = await SharedPreferences.getInstance();
    await TextManifest.writeText('imported-text-hash.txt', 'unrestored');
    await ManifestDatabase.insertTextRecord({
      'id': 'imported-text-record',
      'name': 'Imported text',
      'hash': 'imported-text-hash',
      'format': 'txt',
      'createdAt': DateTime.now().toIso8601String(),
      'size': 'unrestored'.length,
      'folder': '',
      'textLength': 'unrestored'.length,
    });
    await prefs.setString(
      'provider_entries',
      '[]',
    );

    final validBackup = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(validBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'malformed-llm-entry',
        'type': 'llm',
        'configs': 'not-a-config-list',
      },
    ]);
    archive.removeFile(settingsFile);
    final invalidSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
        ArchiveFile('settings.json', invalidSettings.length, invalidSettings));
    final backup = Uint8List.fromList(ZipEncoder().encode(archive));

    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
    await TextManifest.deleteFile('imported-text-hash.txt');
    const existingText = 'preserve-on-invalid-import';
    await TextManifest.writeText('existing-text-hash.txt', existingText);
    await ManifestDatabase.insertTextRecord({
      'id': 'existing-text-record',
      'name': 'Existing text',
      'hash': 'existing-text-hash',
      'format': 'txt',
      'createdAt': DateTime.now().toIso8601String(),
      'size': existingText.length,
      'folder': '',
      'textLength': existingText.length,
    });

    await expectLater(
      BackupService.restoreFromBytesForTest(backup),
      throwsA(isA<BackupValidationException>()),
    );

    final textRecords = await ManifestDatabase.getAllTextRecords();
    expect(textRecords.map((record) => record['id']),
        contains('existing-text-record'));
    expect(textRecords.map((record) => record['id']),
        isNot(contains('imported-text-record')));
    expect(await TextManifest.readText('existing-text-hash.txt'), existingText);
    expect(await TextManifest.readText('imported-text-hash.txt'), isNull);
  });

  testWidgets(
      'preflights LLM account IDs, references, and envelopes before restore mutations',
      (WidgetTester t) async {
    final prefs = await SharedPreferences.getInstance();
    const importedText = 'this-text-must-not-be-restored';
    await TextManifest.writeText('imported-text-hash.txt', importedText);
    await ManifestDatabase.insertTextRecord({
      'id': 'imported-text-record',
      'name': 'Imported text',
      'hash': 'imported-text-hash',
      'format': 'txt',
      'createdAt': DateTime.now().toIso8601String(),
      'size': importedText.length,
      'folder': '',
      'textLength': importedText.length,
    });
    await prefs.setString('provider_entries', '[]');

    final validBackup = await BackupService.buildBackupBytesForTest();
    final invalidSettingsCases = <Map<String, dynamic>>[
      {
        'provider_entries': jsonEncode([
          {
            'id': 'entry-with-extra-credential',
            'type': 'llm',
            'authorizationHeader': 'sk_restore_entry_header_secret',
            'configs': [
              {'id': 'valid-account-id', 'models': []},
            ],
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'missing-type-entry-with-credential',
            'apiKey': 'sk_restore_missing_type_secret',
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'invalid-entry-level-llm-key',
            'type': 'llm',
            'key': 42,
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'unknown-type-entry-with-credential',
            'type': 'custom-provider',
            'headers': {
              'authorizationHeader': 'sk_restore_unknown_type_secret'
            },
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'unknown-type-set-cookie-entry',
            'type': 'custom-provider',
            'headers': {'Set-Cookie': 'auth=sk_restore_set_cookie_secret'},
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'credential-bearing-mcp-entry',
            'type': 'mcp',
            'typeConfig': {
              'apiKey': 'sk_restore_mcp_secret',
              'headers': {'Authorization': 'sk_restore_mcp_header_secret'},
            },
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'missing-type-cookie-entry',
            'headers': {'Cookie': 'auth=sk_restore_cookie_secret'},
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'cross-source-llm-entry',
            'type': 'llm',
            'configs': [
              {
                'id': 'cross-source-account',
                'providerName': 'Cross-source provider',
                'host': 'https://cross-source.example.test',
                'key': 'sk_provider_entries_cross_source_key',
                'models': [
                  {'modelId': 'cross-source-model'},
                ],
              },
            ],
          },
        ]),
        'chat_configs': jsonEncode([
          {
            'providerName': 'Cross-source provider',
            'host': 'https://cross-source.example.test',
            'key': 'sk_legacy_chat_configs_cross_source_key',
            'models': [
              {'modelId': 'cross-source-model'},
            ],
          },
        ]),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'account-ref-fallback-entry',
            'type': 'llm',
            'configs': [
              {'id': 'account-ref-fallback-id', 'models': []},
            ],
          },
        ]),
        LlmAccountMigrationService.accountsPreferenceKey: jsonEncode({
          'version': 1,
          'items': [
            {
              'id': 'account-ref-fallback-id',
              'credentialRef': 'missing-account-level-secure-reference',
              'models': [],
            },
          ],
        }),
      },
      {
        'provider_entries': jsonEncode([
          {
            'id': 'mismatched-reference-entry',
            'type': 'llm',
            'configs': [
              {
                'id': 'mismatched-reference-id',
                'credentialRef': 'provider-config-reference',
                'models': [],
              },
            ],
          },
        ]),
        LlmAccountMigrationService.accountsPreferenceKey: jsonEncode({
          'version': 1,
          'items': [
            {
              'id': 'mismatched-reference-id',
              'credentialRef': 'account-envelope-reference',
              'models': [],
            },
          ],
        }),
      },
      {
        LlmAccountMigrationService.accountsPreferenceKey:
            '{"version":1,"items":"not-a-record-list"}',
      },
      {
        LlmAccountMigrationService.accountsPreferenceKey: jsonEncode({
          'version': 1,
          'items': [
            {'id': ''},
          ],
        }),
      },
      {
        LlmAccountMigrationService.accountsPreferenceKey: jsonEncode({
          'version': 1,
          'items': [
            {
              'id': 'unlinked-account-with-reference',
              'credentialRef': 'missing-unlinked-account-reference',
              'models': [],
            },
          ],
        }),
      },
      {
        LlmAccountMigrationService.modelGroupsPreferenceKey:
            '{"version":1,"items":"not-a-record-list"}',
      },
    ];

    Uint8List backupWithSettings(Map<String, dynamic> replacement) {
      final archive = ZipDecoder().decodeBytes(validBackup);
      final settingsFile = archive.findFile('settings.json')!;
      final settings =
          jsonDecode(utf8.decode(settingsFile.content as List<int>))
              as Map<String, dynamic>;
      settings.addAll(replacement);
      archive.removeFile(settingsFile);
      final encoded = utf8.encode(jsonEncode(settings));
      archive.addFile(ArchiveFile('settings.json', encoded.length, encoded));
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
    await TextManifest.deleteFile('imported-text-hash.txt');
    const existingText = 'preserve-on-invalid-import';
    await TextManifest.writeText('existing-text-hash.txt', existingText);
    await ManifestDatabase.insertTextRecord({
      'id': 'existing-text-record',
      'name': 'Existing text',
      'hash': 'existing-text-hash',
      'format': 'txt',
      'createdAt': DateTime.now().toIso8601String(),
      'size': existingText.length,
      'folder': '',
      'textLength': existingText.length,
    });

    for (final invalidSettings in invalidSettingsCases) {
      await expectLater(
        BackupService.restoreFromBytesForTest(
          backupWithSettings(invalidSettings),
          selection: _settingsAndTextRestoreSelection,
          credentialStore: _BackupCredentialStore(),
        ),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.message,
            'message',
            '备份中的 LLM 设置无效或存在歧义。未更改本机数据。',
          ),
        ),
      );

      final textRecords = await ManifestDatabase.getAllTextRecords();
      expect(textRecords.map((record) => record['id']),
          contains('existing-text-record'));
      expect(textRecords.map((record) => record['id']),
          isNot(contains('imported-text-record')));
      expect(
          await TextManifest.readText('existing-text-hash.txt'), existingText);
      expect(await TextManifest.readText('imported-text-hash.txt'), isNull);
      expect(prefs.getString('provider_entries'), '[]');
    }
  });

  testWidgets(
      'rejects an unlinked LLM account credential reference without secure data',
      (WidgetTester t) async {
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings[LlmAccountMigrationService.accountsPreferenceKey] = jsonEncode({
      'version': 1,
      'items': [
        {
          'id': 'unlinked-account',
          'credentialRef': 'missing-unlinked-account-reference',
          'models': [],
        },
      ],
    });
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );

    await expectLater(
      BackupService.restoreFromBytesForTest(
        Uint8List.fromList(ZipEncoder().encode(archive)),
        selection: settingsOnlySelection,
        skipPostRestoreMigration: true,
        credentialStore: _BackupCredentialStore(),
      ),
      throwsA(isA<BackupValidationException>()),
    );
    expect(prefs.getString('provider_entries'), '[]');
    expect(
      prefs.getString(LlmAccountMigrationService.accountsPreferenceKey),
      isNull,
    );
  });

  testWidgets('rejects credential-bearing MCP settings before restore commits',
      (WidgetTester t) async {
    const settingsOnlySelection = BackupSelection(
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
    const secret = 'sk_credential_bearing_mcp_restore_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'credential-bearing-mcp-entry',
        'type': 'mcp',
        'typeConfig': {
          'apiKey': secret,
          'headers': {'Authorization': secret},
        },
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );

    await expectLater(
      BackupService.restoreFromBytesForTest(
        Uint8List.fromList(ZipEncoder().encode(archive)),
        selection: settingsOnlySelection,
        skipPostRestoreMigration: true,
        credentialStore: _BackupCredentialStore(),
      ),
      throwsA(isA<BackupValidationException>()),
    );
    expect(prefs.getString('provider_entries'), '[]');
  });

  testWidgets(
      'rejects cross-source inline credentials that conflict with a referenced secret',
      (WidgetTester t) async {
    const reference = 'stroom.llm.credential.cross-source-preflight';
    const existingSecret = 'sk_existing_cross_source_secret';
    const legacySecret = 'sk_conflicting_legacy_restore_secret';
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'keyless-provider-entry',
        'type': 'llm',
        'configs': [
          {
            'id': 'keyless-provider-config',
            'providerName': 'Shared provider',
            'host': 'https://shared.example.test',
            'credentialRef': reference,
            'models': [
              {'modelId': 'shared-model'},
            ],
          },
        ],
      },
    ]);
    settings['chat_configs'] = jsonEncode([
      {
        'providerName': 'Shared provider',
        'host': 'https://shared.example.test',
        'key': legacySecret,
        'models': [
          {'modelId': 'shared-model'},
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );
    final credentialStore = _BackupCredentialStore()
      ..values[reference] = existingSecret;

    await expectLater(
      BackupService.restoreFromBytesForTest(
        Uint8List.fromList(ZipEncoder().encode(archive)),
        selection: settingsOnlySelection,
        skipPostRestoreMigration: true,
        credentialStore: credentialStore,
      ),
      throwsA(isA<BackupValidationException>()),
    );

    expect(credentialStore.values[reference] == existingSecret, isTrue);
    expect(prefs.getString('provider_entries') == '[]', isTrue);
  });

  testWidgets(
      'restores distinct accounts that share endpoint and model identity',
      (WidgetTester t) async {
    const firstReference = 'stroom.llm.credential.same-endpoint-first';
    const secondReference = 'stroom.llm.credential.same-endpoint-second';
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'shared-endpoint-llm-entry',
        'type': 'llm',
        'configs': [
          {
            'id': 'same-endpoint-account-one',
            'providerName': 'Shared endpoint',
            'host': 'https://same-endpoint.example.test',
            'credentialRef': firstReference,
            'models': [
              {'modelId': 'shared-model'},
            ],
          },
          {
            'id': 'same-endpoint-account-two',
            'providerName': 'Shared endpoint',
            'host': 'https://same-endpoint.example.test',
            'credentialRef': secondReference,
            'models': [
              {'modelId': 'shared-model'},
            ],
          },
        ],
      },
    ]);
    settings[LlmAccountMigrationService.accountsPreferenceKey] = jsonEncode({
      'version': 1,
      'items': [
        {
          'id': 'same-endpoint-account-one',
          'credentialRef': firstReference,
          'models': [],
        },
        {
          'id': 'same-endpoint-account-two',
          'credentialRef': secondReference,
          'models': [],
        },
      ],
    });
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );
    final credentialStore = _BackupCredentialStore()
      ..values[firstReference] = 'stored-value-one'
      ..values[secondReference] = 'stored-value-two';

    await BackupService.restoreFromBytesForTest(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      selection: settingsOnlySelection,
      skipPostRestoreMigration: true,
      credentialStore: credentialStore,
    );

    final restoredEntries =
        jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
    final configs =
        ((restoredEntries.single as Map)['configs'] as List).cast<Map>();
    expect(
      configs.map((config) => config['credentialRef']).toSet(),
      {firstReference, secondReference},
    );
    expect(credentialStore.values[firstReference], 'stored-value-one');
    expect(credentialStore.values[secondReference], 'stored-value-two');
  });

  testWidgets(
      'rejects null selected provider settings before clearing local settings',
      (WidgetTester t) async {
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    const previousProviderEntries = '[]';
    await prefs.setString('provider_entries', previousProviderEntries);
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = null;
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );

    await expectLater(
      BackupService.restoreFromBytesForTest(
        Uint8List.fromList(ZipEncoder().encode(archive)),
        selection: settingsOnlySelection,
        skipPostRestoreMigration: true,
        credentialStore: _BackupCredentialStore(),
      ),
      throwsA(isA<BackupValidationException>()),
    );

    expect(prefs.getString('provider_entries'), previousProviderEntries);
  });

  testWidgets(
      'restores legacy single-config LLM entries without persisting inline keys',
      (WidgetTester t) async {
    const legacySecret = 'sk_legacy_single_config_restore_secret';
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'legacy-single-config-entry',
        'type': 'llm',
        'name': 'Legacy single config',
        'providerName': 'Legacy provider',
        'host': 'https://legacy-single-config.example.test',
        'key': legacySecret,
        'models': [
          {'modelId': 'legacy-model', 'name': 'Legacy model'},
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );
    final credentialStore = _BackupCredentialStore();

    await BackupService.restoreFromBytesForTest(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      selection: settingsOnlySelection,
      skipPostRestoreMigration: true,
      credentialStore: credentialStore,
    );

    final restoredEntries =
        jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
    final restoredEntry = restoredEntries.single as Map;
    final restoredConfigs = (restoredEntry['configs'] as List).cast<Map>();
    final restoredConfig = restoredConfigs.single;
    expect(restoredEntry['providerName'], isNull);
    expect(restoredEntry.containsKey('key'), isFalse);
    expect(restoredConfig['id'], isA<String>());
    expect(restoredConfig['id'], isNotEmpty);
    expect(restoredConfig['key'], isNull);
    expect(restoredConfig['providerName'], 'Legacy provider');
    expect(restoredConfig['host'], 'https://legacy-single-config.example.test');
    expect(
        (restoredConfig['models'] as List).single['modelId'], 'legacy-model');
    final reference = restoredConfig['credentialRef'] as String;
    expect(credentialStore.values[reference], legacySecret);
    expect(
        prefs.getString('provider_entries')!.contains(legacySecret), isFalse);
  });

  testWidgets(
      'restores LLM configs without IDs using staged secure credentials',
      (WidgetTester t) async {
    const legacySecret = 'sk_missing_config_id_restore_secret';
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final baseBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(baseBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'llm-configs-without-ids-entry',
        'type': 'llm',
        'configs': [
          {
            'providerName': 'Config without ID',
            'host': 'https://missing-config-id.example.test',
            'key': legacySecret,
            'models': [],
          },
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );
    final credentialStore = _BackupCredentialStore();

    await BackupService.restoreFromBytesForTest(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      selection: settingsOnlySelection,
      skipPostRestoreMigration: true,
      credentialStore: credentialStore,
    );

    final restoredEntries =
        jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
    final restoredEntry = restoredEntries.single as Map;
    final restoredConfig = restoredEntry['configs'] as List;
    final config = restoredConfig.single as Map;
    expect(config['id'], isA<String>());
    expect(config['id'], isNotEmpty);
    expect(config['key'], isNull);
    final reference = config['credentialRef'] as String;
    expect(credentialStore.values[reference], legacySecret);
    expect(
        prefs.getString('provider_entries')!.contains(legacySecret), isFalse);
  });

  testWidgets(
      'moves inline restore credentials to secure storage before prefs commit',
      (WidgetTester t) async {
    const providerSecret = 'sk_restore_provider_entry_secret';
    const entrySecret = 'sk_restore_provider_entry_level_secret';
    const legacySecret = 'sk_restore_legacy_chat_secret';
    const settingsOnlySelection = BackupSelection(
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', '[]');
    final validBackup = await BackupService.buildBackupBytesForTest(
      selection: settingsOnlySelection,
    );
    final archive = ZipDecoder().decodeBytes(validBackup);
    final settingsFile = archive.findFile('settings.json')!;
    final settings = jsonDecode(utf8.decode(settingsFile.content as List<int>))
        as Map<String, dynamic>;
    settings['provider_entries'] = jsonEncode([
      {
        'id': 'restore-llm-entry',
        'type': 'llm',
        'name': 'Restored LLM',
        'configs': [
          {
            'id': 'restore-provider-config',
            'providerName': 'Restored provider',
            'host': 'https://restore-provider.example.test',
            'key': providerSecret,
            'models': [],
          },
        ],
      },
      {
        'id': 'restore-llm-entry-key',
        'type': 'llm',
        'name': 'Restored legacy entry key',
        'key': entrySecret,
        'configs': [
          {
            'id': 'restore-entry-key-config',
            'providerName': 'Restored entry-key provider',
            'host': 'https://restore-entry-key.example.test',
            'models': [],
          },
        ],
      },
    ]);
    settings['chat_configs'] = jsonEncode([
      {
        'providerName': 'Restored legacy provider',
        'host': 'https://restore-legacy.example.test',
        'key': legacySecret,
        'models': [
          {'modelId': 'legacy-model'},
        ],
      },
    ]);
    archive.removeFile(settingsFile);
    final encodedSettings = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
    );
    final credentialStore = _BackupCredentialStore();

    await BackupService.restoreFromBytesForTest(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      selection: settingsOnlySelection,
      skipPostRestoreMigration: true,
      credentialStore: credentialStore,
    );

    final restoredEntries =
        jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
    final restoredConfig = ((restoredEntries.singleWhere(
      (entry) => (entry as Map)['id'] == 'restore-llm-entry',
    ) as Map)['configs'] as List)
        .single as Map;
    expect(restoredConfig.containsKey('key'), isFalse);
    final providerReference = restoredConfig['credentialRef'] as String;
    expect(credentialStore.values[providerReference], providerSecret);
    final restoredEntryKeyConfig = ((restoredEntries.singleWhere(
      (entry) => (entry as Map)['id'] == 'restore-llm-entry-key',
    ) as Map)['configs'] as List)
        .single as Map;
    expect(restoredEntryKeyConfig.containsKey('key'), isFalse);
    final entryReference = restoredEntryKeyConfig['credentialRef'] as String;
    expect(credentialStore.values[entryReference], entrySecret);

    final restoredLegacy =
        jsonDecode(prefs.getString('chat_configs')!) as List<dynamic>;
    final restoredLegacyConfig = restoredLegacy.single as Map;
    expect(restoredLegacyConfig.containsKey('key'), isFalse);
    final legacyReference = restoredLegacyConfig['credentialRef'] as String;
    expect(credentialStore.values[legacyReference], legacySecret);
    expect(
        prefs.getString('provider_entries'), isNot(contains(providerSecret)));
    expect(prefs.getString('provider_entries'), isNot(contains(entrySecret)));
    expect(prefs.getString('chat_configs'), isNot(contains(legacySecret)));

    await prefs.setString('provider_entries', '[]');
    await prefs.remove('chat_configs');
    final unavailableStore = _BackupCredentialStore()..failOnWriteNumber = 2;
    await expectLater(
      BackupService.restoreFromBytesForTest(
        Uint8List.fromList(ZipEncoder().encode(archive)),
        selection: settingsOnlySelection,
        skipPostRestoreMigration: true,
        credentialStore: unavailableStore,
      ),
      throwsA(isA<BackupValidationException>()),
    );
    expect(prefs.getString('provider_entries'), '[]');
    expect(prefs.getString('chat_configs'), isNull);
    expect(unavailableStore.values, isEmpty);
  });

  test('serializes backup restore until migration rollback completes',
      () async {
    const settingsOnlySelection = BackupSelection(
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
    const reference = 'stroom.llm.credential.concurrent-restore-rollback';
    const firstSecret = 'sk_initial_migration_credential';
    const migrationSecret = 'sk_rollback_migration_credential';
    const restoredSecret = 'sk_committed_backup_restore_credential';

    String sourceWithKey(String secret) => jsonEncode([
          {
            'id': 'rollback-race-provider',
            'type': 'llm',
            'configs': [
              {
                'id': 'rollback-race-account',
                'providerName': 'Rollback race provider',
                'host': 'https://rollback-race.example.test',
                'credentialRef': reference,
                'key': secret,
                'models': [],
              },
            ],
          },
        ]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', sourceWithKey(firstSecret));
    final credentials = _BackupCredentialStore();
    final migrationPreferences = _BackupLlmPreferences(prefs);
    final migration = LlmAccountMigrationService(
      preferences: migrationPreferences,
      credentialStore: credentials,
    );
    await migration.migrate();
    expect(credentials.values[reference] == firstSecret, isTrue);
    await prefs.remove(LlmAccountMigrationService.migrationStateKey);

    late Future<void> pendingRestore;
    var restoreCompletedBeforeMigrationFailure = false;
    migrationPreferences.onSet = (key, value) async {
      if (key != LlmAccountMigrationService.migrationStateKey) {
        return prefs.setString(key, value);
      }
      expect(credentials.values[reference] == migrationSecret, isTrue);
      final backupBytes = await BackupService.buildBackupBytesForTest(
        selection: settingsOnlySelection,
      );
      final archive = ZipDecoder().decodeBytes(backupBytes);
      final settingsFile = archive.findFile('settings.json')!;
      final settings =
          jsonDecode(utf8.decode(settingsFile.content as List<int>))
              as Map<String, dynamic>;
      final entries =
          jsonDecode(settings['provider_entries'] as String) as List<dynamic>;
      final entry = entries.single as Map<String, dynamic>;
      final config = (entry['configs'] as List).single as Map<String, dynamic>;
      config['key'] = restoredSecret;
      settings['provider_entries'] = jsonEncode(entries);
      archive.removeFile(settingsFile);
      final encodedSettings = utf8.encode(jsonEncode(settings));
      archive.addFile(
        ArchiveFile('settings.json', encodedSettings.length, encodedSettings),
      );
      pendingRestore = BackupService.restoreFromBytesForTest(
        Uint8List.fromList(ZipEncoder().encode(archive)),
        selection: settingsOnlySelection,
        skipPostRestoreMigration: true,
        credentialStore: credentials,
      ).then((_) {
        restoreCompletedBeforeMigrationFailure = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(restoreCompletedBeforeMigrationFailure, isFalse);
      return false;
    };

    await expectLater(
      migration.migrate(
        sourceProviderEntriesJson: sourceWithKey(migrationSecret),
      ),
      throwsA(isA<LlmAccountMigrationException>()),
    );
    await pendingRestore;
    expect(credentials.values[reference] == restoredSecret, isTrue);
  });

  testWidgets('redacts keys when a provider entry has no type',
      (WidgetTester t) async {
    const secret = 'sk_missing_provider_type_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'unknown-provider-entry',
          'name': 'Preserved provider name',
          'key': secret,
          'configs': [
            {
              'id': 'unknown-provider-config',
              'host': 'https://api.example.test',
              'key': secret,
              'options': {
                'label': 'Preserved option',
                'credentials': {'key': secret},
              },
            },
          ],
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText, isNot(contains(secret)));
    expect(exportedText, contains('Preserved provider name'));
    expect(exportedText, contains('Preserved option'));
    expect(exportedText, contains('https://api.example.test'));
  });

  testWidgets('redacts keys when a provider entry has an unsupported type',
      (WidgetTester t) async {
    const secret = 'sk_unsupported_provider_type_secret';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'unsupported-provider-entry',
          'type': 'unsupported-provider',
          'name': 'Preserved unsupported provider',
          'key': secret,
          'configs': [
            {
              'id': 'unsupported-provider-config',
              'host': 'https://unsupported.example.test',
              'key': secret,
              'options': {
                'label': 'Preserved unsupported option',
                'credentials': {'key': secret},
              },
            },
          ],
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText, isNot(contains(secret)));
    expect(exportedText, contains('Preserved unsupported provider'));
    expect(exportedText, contains('Preserved unsupported option'));
    expect(exportedText, contains('https://unsupported.example.test'));
  });

  testWidgets('preserves data for a recognized builtin provider type',
      (WidgetTester t) async {
    const builtinValue = 'supported-builtin-key-value';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_entries',
      jsonEncode([
        {
          'id': 'builtin-provider-entry',
          'type': 'builtin',
          'name': 'Preserved builtin provider',
          'key': builtinValue,
          'configs': [
            {
              'id': 'builtin-provider-config',
              'options': {'key': builtinValue},
            },
          ],
        },
      ]),
    );

    final bytes = await BackupService.buildBackupBytesForTest();
    final archive = ZipDecoder().decodeBytes(bytes);
    final exportedText = archive.files
        .where((file) => file.isFile)
        .map((file) =>
            utf8.decode(file.content as List<int>, allowMalformed: true))
        .join('\n');

    expect(exportedText, contains(builtinValue));
    expect(exportedText, contains('Preserved builtin provider'));
  });

  // ==================================================================
  // Backup creation: onProgress callback
  // ==================================================================

  group('Backup creation with onProgress callback', () {
    testWidgets('buildBackupBytesForTest calls onProgress with 0.0 and 1.0',
        (WidgetTester t) async {
      final progressValues = <double>[];
      await BackupService.buildBackupBytesForTest(
        onProgress: (p) => progressValues.add(p),
      );

      // First call should be 0.0
      expect(progressValues.first, equals(0.0));
      // Last call should be 1.0
      expect(progressValues.last, equals(1.0));
      // Should have multiple progress updates
      expect(progressValues.length, greaterThanOrEqualTo(2));
    });

    testWidgets('buildBackupBytesForTest reports intermediate progress values',
        (WidgetTester t) async {
      final progressValues = <double>[];
      await BackupService.buildBackupBytesForTest(
        onProgress: (p) => progressValues.add(p),
      );

      // Should have reported progress at multiple stages
      expect(progressValues, contains(0.0));
      expect(progressValues, contains(1.0));
      // Check for intermediate values
      expect(progressValues.any((p) => p > 0.0 && p < 1.0), isTrue,
          reason: 'Should report intermediate progress values between 0 and 1');
    });
  });

  // ==================================================================
  // Backup creation: verify text records and text files are included
  // ==================================================================

  group('Backup creation includes text records', () {
    testWidgets('stroom_manifest.json contains text_records key',
        (WidgetTester t) async {
      // Insert a text record into the database
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_backup_1',
        'name': 'backup_test',
        'hash': 'hash123',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });

      // Build backup bytes
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find stroom_manifest.json in the archive
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull,
          reason: 'stroom_manifest.json must exist in the backup archive');

      final manifestJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;

      // Verify text_records key exists
      expect(manifestJson.containsKey('text_records'), isTrue,
          reason:
              'stroom_manifest.json must contain text_records key (bug: was missing)');

      // Verify our inserted record is in the list
      final textRecords =
          (manifestJson['text_records'] as List<dynamic>?) ?? [];
      expect(textRecords.length, equals(1),
          reason: 'text_records must contain 1 record');
      expect((textRecords[0] as Map)['id'], equals('txt_backup_1'));
    });

    testWidgets('text files are included in the backup archive',
        (WidgetTester t) async {
      const testContent = 'Hello, this is text file content for backup test!';
      // Create a text file and its database record
      final storageFileName = 'my_test_hash.txt';
      await TextManifest.writeText(storageFileName, testContent);
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_backup_2',
        'name': 'file_backup_test',
        'hash': 'my_test_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': testContent.length,
        'folder': '',
        'textLength': testContent.length,
      });

      // Build backup bytes
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Look for the text file in the texts/ directory
      String? foundFileKey;
      for (final f in archive) {
        if (f.isFile && f.name == 'texts/$storageFileName') {
          foundFileKey = f.name;
          break;
        }
      }
      expect(foundFileKey, isNotNull,
          reason:
              'Backup archive must contain texts/$storageFileName (bug: text files were excluded)');
    });
  });

  // ==================================================================
  // Backup restore: verify text records and files are restored
  // ==================================================================

  group('Backup restore includes text records', () {
    testWidgets('_restoreDatabaseFromJson inserts text records',
        (WidgetTester t) async {
      // Build a JSON string as it would appear in a backup
      final testJson = jsonEncode({
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': [
          {
            'id': 'txt_restore_1',
            'name': 'restored_text',
            'hash': 'restored_hash',
            'format': 'txt',
            'createdAt': DateTime.now().toIso8601String(),
            'size': 200,
            'folder': 'subfolder',
            'textLength': 200,
          },
          {
            'id': 'txt_restore_2',
            'name': 'restored_text_2',
            'hash': 'restored_hash_2',
            'format': 'txt',
            'createdAt': DateTime.now().toIso8601String(),
            'size': 300,
            'folder': '',
            'textLength': 300,
          },
        ],
        'folders': <String>['subfolder'],
      });

      // First clear the database (simulates restore starting fresh)
      await ManifestDatabase.clearAllData();

      // Restore from JSON
      await BackupService.restoreDatabaseFromJsonForTest(testJson);

      // Verify text records were inserted
      final textRecords = await ManifestDatabase.getAllTextRecords();
      expect(textRecords.length, equals(2),
          reason:
              'After restore from JSON, there should be 2 text records (bug: text records were not inserted)');
      expect(textRecords[0]['id'], equals('txt_restore_1'));
      expect(textRecords[0]['folder'], equals('subfolder'));
    });

    testWidgets('text files are restored from texts/ directory',
        (WidgetTester t) async {
      // Build a minimal backup archive that includes a text file
      const testContent = 'Restored text content! 你好世界';
      final archive = Archive();

      // Add manifest.json
      final manifest = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': 'test',
      };
      archive.addFile(ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode(manifest)).length,
          utf8.encode(jsonEncode(manifest))));

      // Add stroom_manifest.json with a text record
      final dbData = {
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': [
          {
            'id': 'txt_restore_file',
            'name': 'restored_file',
            'hash': 'restored_hash_file',
            'format': 'txt',
            'createdAt': DateTime.now().toIso8601String(),
            'size': utf8.encode(testContent).length,
            'folder': '',
            'textLength': testContent.length,
          },
        ],
        'folders': <String>[],
      };
      archive.addFile(ArchiveFile(
          'stroom_manifest.json',
          utf8.encode(jsonEncode(dbData)).length,
          utf8.encode(jsonEncode(dbData))));

      // Add the text file in texts/ directory
      final textFileContent = utf8.encode(testContent);
      archive.addFile(ArchiveFile('texts/restored_hash_file.txt',
          textFileContent.length, textFileContent));

      // Encode to bytes
      final encoded = ZipEncoder().encode(archive);
      final backupBytes = Uint8List.fromList(encoded);

      // Clear database and file store
      await ManifestDatabase.clearAllData();
      TextManifest.invalidateCache();

      // Restore from bytes
      await BackupService.restoreFromBytesForTest(backupBytes,
          skipMissingCategories: true);
      TextManifest.invalidateCache();

      // Verify text record exists in DB
      final textRecords = await ManifestDatabase.getAllTextRecords();
      expect(textRecords.length, equals(1),
          reason:
              'After full restore, there should be 1 text record in the database');

      // Verify the text file content can be read
      final restoredContent =
          await TextManifest.readText('restored_hash_file.txt');
      expect(restoredContent, isNotNull,
          reason:
              'Text file should be readable after restore (bug: texts/ was missing from knownDirs)');
      expect(restoredContent, equals(testContent));
    });
  });

  // ==================================================================
  // Full roundtrip: backup → clear → restore → verify
  // ==================================================================

  group('Full backup/restore roundtrip preserves text records', () {
    testWidgets('text records survive backup and restore cycle',
        (WidgetTester t) async {
      // 1. Create test data: insert a text record and write a text file
      const testContent = 'Full roundtrip test content with 中文 Unicode!';
      final storageFileName = 'roundtrip_hash.txt';
      await TextManifest.writeText(storageFileName, testContent);
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_roundtrip_1',
        'name': 'roundtrip_test',
        'hash': 'roundtrip_hash',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': utf8.encode(testContent).length,
        'folder': '',
        'textLength': testContent.length,
      });

      // 2. Create backup
      final backupBytes = await BackupService.buildBackupBytesForTest();

      // 3. Clear everything
      await ManifestDatabase.clearAllData();
      TextManifest.invalidateCache();
      expect(await ManifestDatabase.getAllTextRecords(), isEmpty,
          reason: 'After clearAllData, text records must be empty');

      // 4. Restore from backup
      await BackupService.restoreFromBytesForTest(backupBytes,
          skipMissingCategories: true);
      TextManifest.invalidateCache();

      // 5. Verify text records are restored
      final restoredRecords = await ManifestDatabase.getAllTextRecords();
      expect(restoredRecords.length, equals(1),
          reason:
              'After full restore cycle, there must be 1 text record (bug: text records were lost during restore)');
      expect(restoredRecords[0]['name'], equals('roundtrip_test'));
      expect(restoredRecords[0]['hash'], equals('roundtrip_hash'));

      // 6. Verify text file content is restored
      final restoredContent = await TextManifest.readText(storageFileName);
      expect(restoredContent, isNotNull,
          reason:
              'Text file content must be restorable after full backup/restore cycle');
      expect(restoredContent, equals(testContent),
          reason:
              'Text file content must be identical after backup/restore roundtrip');
    });

    testWidgets('multiple text records with Chinese content survive roundtrip',
        (WidgetTester t) async {
      // Create several text records with Chinese content
      const contents = [
        '第一篇中文文档内容',
        '第二篇文档 - 含有English混合',
        '第三篇: 数字12345和符号!@#\$%',
      ];

      for (var i = 0; i < contents.length; i++) {
        final hash = 'chinese_hash_$i';
        final fileName = '$hash.txt';
        await TextManifest.writeText(fileName, contents[i]);
        await ManifestDatabase.insertTextRecord({
          'id': 'txt_chinese_$i',
          'name': 'chinese_doc_$i',
          'hash': hash,
          'format': 'txt',
          'createdAt': DateTime.now().toIso8601String(),
          'size': utf8.encode(contents[i]).length,
          'folder': '',
          'textLength': contents[i].length,
        });
      }

      // Create backup
      final backupBytes = await BackupService.buildBackupBytesForTest();

      // Clear everything
      await ManifestDatabase.clearAllData();
      TextManifest.invalidateCache();

      // Restore
      await BackupService.restoreFromBytesForTest(backupBytes,
          skipMissingCategories: true);
      TextManifest.invalidateCache();

      // Verify all 3 records exist
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records.length, equals(3),
          reason: 'All 3 Chinese text records must survive backup/restore');

      // Verify content for each
      for (var i = 0; i < contents.length; i++) {
        final hash = 'chinese_hash_$i';
        final fileName = '$hash.txt';
        final content = await TextManifest.readText(fileName);
        expect(content, isNotNull,
            reason: 'Text file $fileName must be restorable');
        expect(content, equals(contents[i]),
            reason: 'Content of $fileName must match original');
      }
    });
  });

  // ==================================================================
  // Error handling: backup/restore with no data
  // ==================================================================

  group('Backup/restore handles empty data gracefully', () {
    testWidgets('backup with no records does not crash',
        (WidgetTester t) async {
      // No records inserted - just empty data
      final bytes = await BackupService.buildBackupBytesForTest();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify stroom_manifest.json has all keys (even if empty)
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'stroom_manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull);

      final manifestJson =
          jsonDecode(utf8.decode(manifestData!)) as Map<String, dynamic>;
      expect(manifestJson.containsKey('text_records'), isTrue);
      expect((manifestJson['text_records'] as List<dynamic>?)?.length ?? 0,
          equals(0));
    });

    testWidgets('restore with no text records in backup does not crash',
        (WidgetTester t) async {
      // Build a minimal backup with empty text_records
      final testJson = jsonEncode({
        'image_records': <Map<String, dynamic>>[],
        'audio_records': <Map<String, dynamic>>[],
        'video_records': <Map<String, dynamic>>[],
        'text_records': <Map<String, dynamic>>[],
        'folders': <String>[],
      });

      await ManifestDatabase.clearAllData();
      await BackupService.restoreDatabaseFromJsonForTest(testJson);

      final records = await ManifestDatabase.getAllTextRecords();
      expect(records, isEmpty,
          reason: 'Restoring empty text_records must not crash');
    });
  });

  // ==================================================================
  // Background archive encoding (anti-freeze fix)
  // ==================================================================

  group('Backup service progress reporting and ZIP validity', () {
    testWidgets(
        'buildBackupBytesForTest calls onProgress with proper progression',
        (WidgetTester t) async {
      // Insert a few records so there are items to process
      await ManifestDatabase.insertImageRecord({
        'id': 'img_1',
        'name': 'test_img',
        'hash': 'img_hash_1',
        'format': 'jpg',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'width': 100,
        'height': 100,
      });
      await ManifestDatabase.insertAudioRecord({
        'id': 'aud_1',
        'name': 'test_aud',
        'hash': 'aud_hash_1',
        'format': 'wav',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'duration': 1.0,
      });

      final progressValues = <double>[];
      await BackupService.buildBackupBytesForTest(
        onProgress: (p) => progressValues.add(p),
      );

      // Verify progress is reported in order
      expect(progressValues.first, equals(0.0));
      expect(progressValues.last, equals(1.0));
      // Should have at least the expected milestone progress calls
      expect(progressValues.length, greaterThanOrEqualTo(2));

      // Verify values are monotonically non-decreasing
      for (var i = 1; i < progressValues.length; i++) {
        expect(progressValues[i], greaterThanOrEqualTo(progressValues[i - 1]),
            reason: 'Progress values must be monotonically non-decreasing');
      }
    });

    testWidgets('background encoding produces valid zip archive',
        (WidgetTester t) async {
      final bytes = await BackupService.buildBackupBytesForTest();
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));

      // Decode and verify it's a valid zip
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive, isNotNull);

      // Should contain at least manifest.json and stroom_manifest.json
      final fileNames =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();
      expect(fileNames, contains('manifest.json'));
      expect(fileNames, contains('stroom_manifest.json'));

      // Verify manifest.json content
      Uint8List? manifestData;
      for (final f in archive) {
        if (f.isFile && f.name == 'manifest.json') {
          manifestData = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
      expect(manifestData, isNotNull);

      final manifest = jsonDecode(utf8.decode(manifestData!));
      expect(manifest, isA<Map<String, dynamic>>());
      expect((manifest as Map<String, dynamic>)['version'], equals(2));
    });
  });
}

class _BackupLlmPreferences implements LlmAccountPreferences {
  final SharedPreferences _preferences;
  Future<bool> Function(String key, String value)? onSet;

  _BackupLlmPreferences(this._preferences);

  @override
  Future<String?> getString(String key) async => _preferences.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    final hook = onSet;
    if (hook != null) return hook(key, value);
    return _preferences.setString(key, value);
  }

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}

class _BackupCredentialStore implements LlmCredentialStore {
  final Map<String, String> values = {};
  int? failOnWriteNumber;
  var _writeCount = 0;

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    _writeCount++;
    if (_writeCount == failOnWriteNumber) {
      throw const LlmCredentialStoreException();
    }
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}
