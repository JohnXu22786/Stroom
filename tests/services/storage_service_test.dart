import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    AppStorage.resetCache();
  });

  test(
    'uses the test storage fallback when Path Provider never responds',
    () async {
      AppStorage.resetCache();
      final pendingPath = Completer<Object?>();
      addTearDown(() {
        if (!pendingPath.isCompleted) {
          pendingPath.complete(Directory.systemTemp.path);
        }
      });
      var pathProviderCalls = 0;
      messenger.setMockMethodCallHandler(pathProviderChannel, (call) {
        pathProviderCalls++;
        return pendingPath.future;
      });

      final path = await AppStorage.directory.timeout(
        const Duration(seconds: 2),
      );

      expect(path, Directory.systemTemp.path);
      expect(pathProviderCalls, 1);
      pendingPath.complete(Directory.systemTemp.path);
    },
  );

  test('uses an available Path Provider directory in Flutter tests', () async {
    final documents = await Directory.systemTemp.createTemp('app_storage_');
    addTearDown(() => documents.delete(recursive: true));
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => documents.path,
    );

    final path = await AppStorage.directory;

    expect(path, documents.path);
  });
}
