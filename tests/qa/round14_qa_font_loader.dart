import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadRound14QaFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
  for (final (family, fileName) in [
    ('Roboto', 'Roboto-Regular.ttf'),
    ('MaterialIcons', 'MaterialIcons-Regular.otf'),
  ]) {
    final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }
}
