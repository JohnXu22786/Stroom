// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/tts_create_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  final query = Uri.base.queryParameters;
  final locale =
      query['locale'] == 'ar' ? const Locale('ar') : const Locale('pt', 'BR');
  final scale = double.tryParse(query['scale'] ?? '3') ?? 3;
  final entry = ProviderEntry(
    id: 'local-tts-fixture',
    type: 'tts',
    name: 'TTS供应商',
    configs: [
      ProviderConfigItem(
        providerName: 'Local fixture',
        host: 'https://example.invalid',
        key: 'fixture-only',
        models: [
          ModelConfig(name: 'Local voice', modelId: 'local-voice'),
        ],
      ),
    ],
  );
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  runApp(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(entries: [entry]);
          return notifier;
        }),
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
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: TTSCreatePage(),
      ),
    ),
  );
}
