import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/utils/block_param_display.dart';

class _Entries extends ProviderEntriesNotifier {
  _Entries() {
    state = const ProviderEntriesState();
  }
}

class _Assistants extends AssistantsNotifier {
  _Assistants() {
    state = const [];
  }
}

void main() {
  testWidgets(
      'friendly parameter values use localized states and preserve raw values',
      (tester) async {
    late List<String> values;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith((_) => _Entries()),
        assistantProvider.overrideWith((_) => _Assistants()),
      ],
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Consumer(builder: (context, ref, _) {
          final strings = AppLocalizations.of(context)!;
          final assistant =
              BlockTypeDefinition.findBlockType(BlockType.chat)!.params.single;
          final tts = BlockTypeDefinition.findBlockType(BlockType.tts)!;
          values = [
            friendlyParamValue(assistant, '', ref,
                strings: strings, params: const {}),
            friendlyParamValue(assistant, 'deleted-assistant', ref,
                strings: strings, params: const {}),
            friendlyParamValue(tts.params[1], 'deleted-voice', ref,
                strings: strings, params: const {'modelRef': 'deleted-model'}),
            friendlyParamValue(tts.params[0], 'deleted-model', ref,
                strings: strings, params: const {}),
            friendlyParamValue(tts.params[3], '', ref,
                strings: strings, params: const {}),
            friendlyParamValue(null, 'unchanged', ref,
                strings: strings, params: const {}),
          ];
          return const SizedBox();
        }),
      ),
    ));
    await tester.pumpAndSettle();

    expect(values, [
      '(Not set)',
      'Assistant unavailable',
      'Voice is unavailable. Select another voice.',
      'No model is selected or the model is unavailable. Select another model.',
      'Root folder',
      'unchanged',
    ]);
  });
}
