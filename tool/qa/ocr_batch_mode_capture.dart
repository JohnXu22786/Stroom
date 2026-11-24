import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:image/image.dart' as img;

void main() {
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final imageBytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8, numChannels: 3)),
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: OcrPage(
          testImages: [
            SelectedImage(bytes: imageBytes, format: 'png'),
            SelectedImage(bytes: imageBytes, format: 'png'),
          ],
        ),
      ),
    ),
  );
}
