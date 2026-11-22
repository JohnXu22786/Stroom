import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';

void main() {
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final canvas = img.Image(width: 640, height: 480);
  img.fill(canvas, color: img.ColorRgb8(229, 239, 246));
  img.fillRect(
    canvas,
    x1: 75,
    y1: 55,
    x2: 565,
    y2: 425,
    color: img.ColorRgb8(53, 120, 145),
  );
  img.fillCircle(
    canvas,
    x: 320,
    y: 240,
    radius: 112,
    color: img.ColorRgb8(245, 190, 99),
  );
  final imageBytes = Uint8List.fromList(img.encodePng(canvas));

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ExtendedImageEditorPage(
        imageBytes: imageBytes,
        fileName: 'fixture-image.png',
      ),
    ),
  );
}
