import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/storage_service.dart';

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPathProvider;

  setUp(() {
    originalPathProvider = PathProviderPlatform.instance;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
  });

  testWidgets(
    'uses the test storage fallback without a platform override',
    (WidgetTester _) async {
      AppStorage.resetCache();
      final path = await AppStorage.directory;

      expect(path, Directory.systemTemp.path);
    },
  );

  test('uses an available Path Provider directory in Flutter tests', () async {
    final documents = await Directory.systemTemp.createTemp('app_storage_');
    addTearDown(() => documents.delete(recursive: true));
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);

    final path = await AppStorage.directory;

    expect(path, documents.path);
  });
}
