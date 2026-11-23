import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';

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

  final flows = TaskFlowNotifier();
  final flowId = flows.addFlow(
    name: 'Flow details',
    blocks: [
      TaskFlowBlock(
        typeKey: BlockType.chat,
        params: {
          'experimental_provider_configuration_override_for_desktop':
              'Readable local value',
        },
      ),
    ],
  );

  runApp(
    ProviderScope(
      overrides: [taskFlowListProvider.overrideWith((_) => flows)],
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
        home: TaskFlowBuilderPage(flowId: flowId, startInRunMode: true),
      ),
    ),
  );
}
