import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/voice_editor_page.dart';

void main() {
  runApp(
    MaterialApp(
      locale: const Locale('es', 'ES'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      debugShowCheckedModeBanner: false,
      home: VoiceEditorPage(
        initialVoices: [VoiceEntry(name: '', id: '')],
      ),
    ),
  );
}
