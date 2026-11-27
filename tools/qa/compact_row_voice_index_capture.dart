import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/voice_editor_shared.dart';

void main() => runApp(const _CaptureApp());

class _CaptureApp extends StatelessWidget {
  const _CaptureApp();

  @override
  Widget build(BuildContext context) {
    final query = Uri.base.queryParameters;
    final locale = Locale(query['locale'] ?? 'fr');
    final count = int.tryParse(query['count'] ?? '') ?? 1;
    final scale = double.tryParse(query['scale'] ?? '') ?? 1;
    final brightness = query['theme'] == 'dark'
        ? Brightness.dark
        : Brightness.light;
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: brightness,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: DuplicateResolveDialog(
          working: [
            for (var i = 0; i < count; i++)
              VoiceEntry(name: 'Voice $i', id: 'duplicate'),
          ],
          idToFirstIdx: const {'duplicate': 0},
          pending: List.generate(count, (i) => i),
          onComplete: (_) {},
        ),
      ),
    );
  }
}
