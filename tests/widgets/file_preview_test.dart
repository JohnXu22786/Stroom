import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/file_preview.dart';
import 'package:stroom/widgets/message_attachment_preview.dart';

void main() {
  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  testWidgets('FilePreviewChip keeps fitting names unchanged', (tester) async {
    final attachment = _attachment('notes.txt');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FilePreviewChip(attachment: attachment)),
      ),
    );

    final label = tester.widget<ConstrainedText>(find.byType(ConstrainedText));
    expect(label.data, 'notes.txt');
    expect(
      tester.getSize(find.byType(ConstrainedText)).width,
      lessThanOrEqualTo(48),
    );
  });

  testWidgets(
    'FilePreviewChip bounds the full name for shared overflow display',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longName = 'a-very-long-attachment-name.txt';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreviewChip(attachment: _attachment(longName)),
          ),
        ),
      );

      final label = tester.widget<ConstrainedText>(
        find.byType(ConstrainedText),
      );
      expect(label.data, longName);
      expect(tester.getSize(find.byType(ConstrainedText)).width, 48);
      final labelFinder = find.text(longName);
      final initialPosition = tester.getTopLeft(labelFinder);
      await tester.pump(const Duration(milliseconds: 999));
      expect(
        tester.getTopLeft(labelFinder).dx,
        closeTo(initialPosition.dx, 0.01),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(labelFinder).dx, lessThan(initialPosition.dx));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders the attachment previews at 320x640 in light theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fileName = 'a-very-long-attachment-name-that-clips.txt';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilePreviewChip(attachment: _attachment(fileName)),
              MessageAttachmentPreview(
                attachment: _attachment(fileName),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/bounded_attachment_previews_320x640.png'),
    );
  });

  testWidgets(
    'keeps the full name bounded with German locale and larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const name = 'sehr-langer-deutscher-anlagen-dateiname.txt';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          locale: const Locale('de', 'DE'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('de', 'DE')],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: MessageAttachmentPreview(
              attachment: _attachment(name),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        tester.widget<ConstrainedText>(find.byType(ConstrainedText).first).data,
        name,
      );
      expect(tester.getSize(find.byType(ConstrainedText).first).width, 80);
      expect(tester.takeException(), isNull);
    },
  );
}

Attachment _attachment(String name) => Attachment(
  fileName: name,
  mimeType: 'text/plain',
  fileType: 'document',
  hash: 'hash',
  storagePath: '/tmp/$name',
  fileSize: 1024,
);
