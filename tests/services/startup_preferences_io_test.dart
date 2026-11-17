import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/services/startup_preferences_io.dart' as preferences_io;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory applicationSupportDirectory;

  setUp(() async {
    applicationSupportDirectory = await Directory.systemTemp.createTemp(
      'startup_preferences_io_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => applicationSupportDirectory.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await applicationSupportDirectory.delete(recursive: true);
  });

  test(
    'concurrent mutations preserve independent preference updates',
    () async {
      final file = File(
        p.join(applicationSupportDirectory.path, 'shared_preferences.json'),
      );
      await file.writeAsString(jsonEncode({'flutter.remove': true}));

      await Future.wait([
        preferences_io.writeValue('flutter.first', 'one'),
        preferences_io.writeValue('flutter.second', 'two'),
        preferences_io.removeValue('flutter.remove'),
      ]);

      expect(jsonDecode(await file.readAsString()), {
        'flutter.first': 'one',
        'flutter.second': 'two',
      });
    },
  );

  test('a failed mutation leaves the existing preferences readable', () async {
    final file = File(
      p.join(applicationSupportDirectory.path, 'shared_preferences.json'),
    );
    const original = '{"flutter.existing":"preserved"}';
    await file.writeAsString(original);

    await expectLater(
      preferences_io.writeValue('flutter.invalid', Object()),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    expect(await file.readAsString(), original);
    expect(await preferences_io.readValues({'flutter.existing'}), {
      'flutter.existing': 'preserved',
    });
  });
}
