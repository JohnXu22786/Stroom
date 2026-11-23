import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/widgets/block_chain_editor.dart';

void main() {
  final localeCode = Uri.base.queryParameters['locale'] ?? 'pt-BR';
  final localeParts = localeCode.split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        body: BlockChainEditor(
          blocks: [
            TaskFlowBlock(typeKey: BlockType.audioSeparation),
            TaskFlowBlock(typeKey: BlockType.asr),
          ],
          inputType: IOType.video,
          onInputTypeChanged: (_) {},
          onAddBlock: (_) {},
          onEditBlock: (_) {},
          onDeleteBlock: (_) {},
          onReplaceBlock: (_, __) {},
          onTemporaryOutputsChanged: (_) {},
        ),
      ),
    ),
  );
}
