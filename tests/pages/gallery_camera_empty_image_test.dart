import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/gallery_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
  });

  testWidgets('empty camera image is not saved or reported as success', (
    tester,
  ) async {
    final tempDirectory = await Directory.systemTemp.createTemp();
    addTearDown(() => tempDirectory.delete(recursive: true));
    final emptyImage = File('${tempDirectory.path}/empty.jpg');
    await emptyImage.writeAsBytes(const <int>[]);

    const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pickerChannel,
      (call) async => emptyImage.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pickerChannel,
        null,
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: GalleryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(await ImageManifest.loadRecords(), isEmpty);
    expect(
      await ImageManifest.readFile('d41d8cd98f00b204e9800998ecf8427e.jpg'),
      isNull,
    );
    expect(
      await ImageManifest.readFile(
        'd41d8cd98f00b204e9800998ecf8427e_thumb_v2.png',
      ),
      isNull,
    );
    expect(find.text('Photo saved'), findsNothing);
    expect(find.textContaining('Could not take a photo'), findsOneWidget);
  });
}
