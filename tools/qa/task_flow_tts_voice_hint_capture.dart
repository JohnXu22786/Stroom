import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_editor_dialog.dart';

class _FixtureProviderEntries extends ProviderEntriesNotifier {
  _FixtureProviderEntries() {
    state = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'local-tts-fixture',
          type: 'tts',
          name: 'Local TTS fixture',
          configs: [
            ProviderConfigItem(
              providerName: 'CustomTTS',
              host: 'https://example.invalid',
              key: 'fixture-only',
              models: [ModelConfig(name: 'custom', modelId: 'custom')],
            ),
          ],
        ),
      ],
    );
  }
}

class _FixtureAssistants extends AssistantsNotifier {
  _FixtureAssistants() {
    state = const <Assistant>[];
  }
}

void main() {
  runApp(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => _FixtureProviderEntries(),
        ),
        assistantProvider.overrideWith((ref) => _FixtureAssistants()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
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
          cardTheme: const CardThemeData(elevation: 0),
        ),
        home: const _CapturePage(),
      ),
    ),
  );
}

class _CapturePage extends StatefulWidget {
  const _CapturePage();

  @override
  State<_CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<_CapturePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showBlockEditorDialog(
        context,
        block: TaskFlowBlock(typeKey: BlockType.tts),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
