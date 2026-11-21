// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'long run labels stay bounded and duration inputs still update the preview',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const flowName =
          'Quarterly review flow for the international research team';
      final flows = TaskFlowNotifier();
      final flowId = flows.addFlow(
        name: flowName,
        blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskFlowListProvider.overrideWith((_) => flows)],
          child: MaterialApp(
            locale: const Locale('es', 'ES'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: TaskFlowBuilderPage(
              flowId: flowId,
              startInRunMode: true,
              initialInput: const FlowRunInput(
                text: 'https://example.com/resource',
                durationSec: 61,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(flowName), findsNWidgets(2));

      final durationHint = find.text('hh:mm:ss');
      await tester.ensureVisible(durationHint);
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (final label in ['hora', 'mín.', 'segundo']) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.label is ConstrainedText &&
                (widget.decoration!.label as ConstrainedText).data == label,
          ),
          findsOneWidget,
        );
      }

      final secondsField = find.byWidgetPredicate((widget) {
        if (widget is! TextField) return false;
        final label = widget.decoration?.label;
        return label is ConstrainedText && label.data == 'segundo';
      });
      expect(secondsField, findsOneWidget);
      expect(
        tester.widget<TextField>(secondsField).decoration?.labelText,
        isNull,
      );
      await tester.enterText(secondsField, '42');
      await tester.pump();

      expect(find.text('00:00:42'), findsOneWidget);
      final secondsEditableText = tester.widget<EditableText>(
        find.descendant(of: secondsField, matching: find.byType(EditableText)),
      );
      expect(secondsEditableText.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == flowName,
        ),
        findsOneWidget,
      );

      final fittingFlowId = flows.addFlow(
        name: 'Team',
        blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskFlowListProvider.overrideWith((_) => flows)],
          child: MaterialApp(
            locale: const Locale('de', 'DE'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: TaskFlowBuilderPage(
              key: const Key('fitting-flow'),
              flowId: fittingFlowId,
              startInRunMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final fittingText = find.descendant(
        of: find
            .byWidgetPredicate(
              (widget) => widget is ConstrainedText && widget.data == 'Team',
            )
            .first,
        matching: find.text('Team'),
      );
      final fittingPosition = tester.getTopLeft(fittingText);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.getTopLeft(fittingText), fittingPosition);
      expect(tester.takeException(), isNull);
    },
  );
}
