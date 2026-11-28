import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/gallery_page.dart';
import 'package:stroom/pages/platform_tutorial_page.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/widgets/block_chain_editor.dart';

const _captureKey = ValueKey('round13-fixed-label-controls-capture');

class _EmptyImageRecordsNotifier extends ImageRecordsNotifier {
  @override
  Future<void> loadRecords() async {}
}

class _EmptyImageFoldersNotifier extends ImageFolderListNotifier {
  @override
  Future<void> loadFolders() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadRobotoTestFont();
  });

  Future<void> pumpLocalized(
    WidgetTester tester, {
    required double textScale,
    required Widget home,
    Locale locale = const Locale('de', 'DE'),
    Brightness brightness = Brightness.light,
  }) async {
    final theme = ThemeData(
      brightness: brightness,
      fontFamily: 'Roboto',
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Theme(data: theme, child: home),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('gallery action buttons grow with expanded text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    Future<void> pumpGallery(double scale) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageRecordsProvider.overrideWith(
              (ref) => _EmptyImageRecordsNotifier(),
            ),
            imageFolderListProvider.overrideWith(
              (ref) => _EmptyImageFoldersNotifier(),
            ),
            imageViewModeProvider.overrideWith(
              (ref) => ImageViewModeNotifier(),
            ),
          ],
          child: RepaintBoundary(
            key: _captureKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('de', 'DE'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData(
                fontFamily: 'Roboto',
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const GalleryPage(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final scale in [1.0, 2.5]) {
      await pumpGallery(scale);
      expect(find.bySemanticsLabel('Foto aufnehmen'), findsOneWidget);
      expect(find.bySemanticsLabel('Importieren'), findsOneWidget);
      for (final icon in [
        Icons.camera_alt_outlined,
        Icons.photo_library_outlined,
      ]) {
        final button = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(ElevatedButton),
        );
        expect(button, findsOneWidget);
        final height = tester.getSize(button).height;
        expect(height, greaterThanOrEqualTo(48));
        if (scale == 1) {
          expect(height, 48);
        } else {
          expect(height, greaterThan(48));
        }
      }
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/r13_fixed_label_controls/gallery-de-320x640-scale${scale == 1 ? '1' : '2_5'}-light.png',
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('Task Flow Add Block grows with expanded text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    IOType? selectedInputType;
    for (final scale in [1.0, 2.5]) {
      await pumpLocalized(
        tester,
        textScale: scale,
        home: Scaffold(
          body: BlockChainEditor(
            blocks: const [],
            inputType: IOType.text,
            onInputTypeChanged: (type) => selectedInputType = type,
            onAddBlock: (_) {},
            onEditBlock: (_) {},
            onDeleteBlock: (_) {},
            onReplaceBlock: (_, _) {},
          ),
        ),
      );
      final button = find.ancestor(
        of: find.text('Block hinzufügen'),
        matching: find.byType(OutlinedButton),
      );
      expect(button, findsOneWidget);
      expect(find.bySemanticsLabel('Block hinzufügen'), findsOneWidget);
      final height = tester.getSize(button).height;
      expect(height, greaterThanOrEqualTo(44));
      if (scale == 1) {
        expect(height, 44);
      } else {
        expect(height, greaterThan(44));
        final initialInputLabel = find.text('0. Anfangseingabe');
        expect(initialInputLabel, findsOneWidget);
        expect(tester.getSize(initialInputLabel).width, greaterThan(120));
      }
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/r13_fixed_label_controls/task-flow-de-320x640-scale${scale == 1 ? '1' : '2_5'}-light.png',
        ),
      );
      if (scale > 1) {
        final inputDropdown = find.byType(DropdownButton<IOType>);
        expect(inputDropdown, findsOneWidget);
        await tester.tap(inputDropdown);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Audio'), findsOneWidget);
        await tester.tap(find.text('Audio'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(selectedInputType, IOType.audio);

        await pumpLocalized(
          tester,
          textScale: scale,
          brightness: Brightness.dark,
          home: Scaffold(
            body: BlockChainEditor(
              blocks: const [],
              inputType: IOType.text,
              onInputTypeChanged: (_) {},
              onAddBlock: (_) {},
              onEditBlock: (_) {},
              onDeleteBlock: (_) {},
              onReplaceBlock: (_, _) {},
            ),
          ),
        );
        expect(
          Theme.of(tester.element(find.byType(BlockChainEditor))).brightness,
          Brightness.dark,
        );
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile(
            '../../docs/ui-constrained-text-qa/r13_fixed_label_controls/task-flow-de-320x640-scale2_5-dark.png',
          ),
        );
      }
    }
    semantics.dispose();
  });

  testWidgets('tutorial step number badge grows with expanded text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scale in [1.0, 2.5]) {
      await pumpLocalized(
        tester,
        textScale: scale,
        home: const PlatformTutorialPage(
          config: PlatformTutorialConfig(
            platformName: 'Android',
            icon: Icons.android,
            color: Colors.green,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('1'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      final firstBadge = find
          .ancestor(of: find.text('1').first, matching: find.byType(Container))
          .first;
      final size = tester.getSize(firstBadge);
      expect(size.width, greaterThanOrEqualTo(32));
      expect(size.height, greaterThanOrEqualTo(32));
      if (scale == 1) {
        expect(size, const Size(32, 32));
      } else {
        expect(size.height, greaterThan(32));
      }
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/r13_fixed_label_controls/tutorial-de-320x640-scale${scale == 1 ? '1' : '2_5'}-light.png',
        ),
      );
    }
  });
}

Future<void> _loadRobotoTestFont() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is required to load capture fonts.');
  }
  final materialFontDirectory =
      '$flutterRoot/bin/cache/artifacts/material_fonts';
  for (final font in [
    (
      'Roboto',
      '$materialFontDirectory/Roboto-Regular.ttf',
      '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto/Roboto-Regular.ttf',
    ),
    (
      'MaterialIcons',
      '$materialFontDirectory/MaterialIcons-Regular.otf',
      '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    ),
  ]) {
    final path = File(font.$2).existsSync() ? font.$2 : font.$3;
    final bytes = await File(path).readAsBytes();
    await (FontLoader(
      font.$1,
    )..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }
}
