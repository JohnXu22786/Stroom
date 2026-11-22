import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/voice_batch_add_page.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        fontFamily: 'Noto Sans CJK SC',
        useMaterial3: true,
      ),
      home: const VoiceBatchAddPage(existingVoices: []),
    ),
  );
}
