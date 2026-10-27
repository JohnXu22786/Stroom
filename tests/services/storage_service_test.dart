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
    'uses the test storage path without waiting for Path Provider',
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
        const Duration(milliseconds: 100),
      );

      expect(path, Directory.systemTemp.path);
      expect(pathProviderCalls, 0);
      pendingPath.complete(Directory.systemTemp.path);
    },
  );
}
