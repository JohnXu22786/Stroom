import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/connectivity_test_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
  });

  tearDown(() async {
    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
  });

  test(
    'built-in read connectivity test honors the configured record id',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('first document'));
      final record = TextRecord(
        id: 'existing-record',
        name: 'Existing',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
      );
      await TextManifest.writeFile(record.storageFileName, bytes);
      await TextManifest.addRecord(record);

      final result = await ConnectivityTestService.runBuiltinTest(
        toolName: 'stroom_space_read',
        testContent: jsonEncode({'record_id': 'missing-record'}),
      );

      expect(result.succeeded, isFalse);
      expect(result.details, contains('missing-record'));
    },
  );
}
