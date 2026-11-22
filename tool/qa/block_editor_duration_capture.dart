import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_editor_dialog.dart';

class _EmptyEntriesNotifier extends ProviderEntriesNotifier {
  _EmptyEntriesNotifier() {
    state = const ProviderEntriesState();
  }
}

class _EmptyAssistantsNotifier extends AssistantsNotifier {
  _EmptyAssistantsNotifier() {
    state = const [];
  }
}

void main() {
  final query = Uri.base.queryParameters;
  final localeCode = query['locale'] ?? 'es-ES';
  final parts = localeCode.split('-');
  final locale = Locale(parts.first, parts.length > 1 ? parts[1] : null);
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final brightness = query['theme'] == 'dark'
      ? Brightness.dark
      : Brightness.light;

  runApp(
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith((_) => _EmptyEntriesNotifier()),
        assistantProvider.overrideWith((_) => _EmptyAssistantsNotifier()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showBlockEditorDialog(
                  context,
                  block: TaskFlowBlock(typeKey: BlockType.catcatch),
                );
              });
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
}
