import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/tts_create_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  final textScale =
      double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1.0;
  ManifestDatabase.enableTestMode();
  final entry = ProviderEntry(
    id: 'qa_tts',
    type: 'tts',
    name: 'TTS供应商',
    configs: [
      ProviderConfigItem(
        providerName: 'OpenAI',
        host: 'https://api.openai.com/v1',
        key: 'local-only',
        models: [ModelConfig(name: 'TTS-1', modelId: 'tts-1')],
      ),
    ],
  );
  final entries = ProviderEntriesNotifier()
    ..state = ProviderEntriesState(entries: [entry]);

  runApp(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
        providerEntriesProvider.overrideWith((ref) => entries),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TTSCreatePage(),
                  ),
                ),
                child: const Text('Open TTS editor'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
