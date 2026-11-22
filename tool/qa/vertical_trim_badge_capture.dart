import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/model_config_shared.dart';
import 'package:stroom/providers/tts_config.dart';

class _PresetNotifier extends CustomTrimPresetsNotifier {
  _PresetNotifier() {
    state = [
      TrimPreset(
        id: 'local-screenshot-fixture',
        name: 'A deliberately long user defined trim preset name',
        durationSeconds: 0.25,
      ),
    ];
  }
}

void main() {
  final query = Uri.base.queryParameters;
  final localeCode = query['locale'] ?? 'en-US';
  final localeParts = localeCode.split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;

  runApp(
    ProviderScope(
      overrides: [
        customTrimPresetsProvider.overrideWith((_) => _PresetNotifier()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: TrimSection(
                selectedPresetId: 'local-screenshot-fixture',
                onPresetChanged: (_) {},
                isTestingAudio: false,
                testAudioError: null,
                onPlayTestAudio: () {},
                onAddPreset: () {},
                onEditPreset: (_) {},
                onDeletePreset: (_) async => true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
