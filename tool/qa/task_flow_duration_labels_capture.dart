import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';

void main() {
  final query = Uri.base.queryParameters;
  final localeCode = query['locale'] ?? 'es-ES';
  final parts = localeCode.split('-');
  final locale = Locale(parts.first, parts.length > 1 ? parts[1] : null);
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final motion = query['motion'] == 'true';
  final brightness = query['theme'] == 'dark'
      ? Brightness.dark
      : Brightness.light;

  final flows = TaskFlowNotifier();
  final flowId = flows.addFlow(
    name: 'Production task flow duration editor',
    blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)],
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: false,
          ),
          child: TickerMode(enabled: motion, child: child!),
        ),
        home: TaskFlowBuilderPage(
          flowId: flowId,
          startInRunMode: true,
          initialInput: const FlowRunInput(
            text: 'https://example.com/resource',
            durationSec: 42,
          ),
        ),
      ),
    ),
  );
}
