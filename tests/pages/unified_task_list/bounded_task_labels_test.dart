import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/background_task_card.dart';
import 'package:stroom/pages/unified_task_list/synthesis_task_card.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/widgets/constrained_text.dart';

Future<void> _pumpAtNarrowSize(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('ar'),
  double textScale = 1.8,
}) async {
  const size = Size(320, 640);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(useMaterial3: true),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'localized background error heading and details action stay in their row',
    (tester) async {
      final task = BackgroundTask(
        id: 'failed-ocr',
        type: BackgroundTaskType.ocr,
        title: 'failed task',
        status: TaskStatus.failed,
        error: 'Request failed',
        rawRequest: {'request': true},
        createdAt: DateTime(2025),
      );
      await _pumpAtNarrowSize(
        tester,
        ListView(children: [BackgroundTaskCard(task: task)]),
      );
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      final strings = AppLocalizations.of(
        tester.element(find.byType(BackgroundTaskCard)),
      )!;
      expect(find.text(strings.unifiedTaskErrorDetails), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(strings.unifiedTaskErrorDetails),
          matching: find.byType(ConstrainedText),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text(strings.unifiedTaskViewErrorDetails),
          matching: find.byType(ConstrainedText),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'synthesis error dialog bounds localized title and close action while body remains selectable',
    (tester) async {
      final task = SynthesisTask(
        id: 'failed-synthesis',
        title: 'voice synthesis',
        status: TaskStatus.failed,
        error: 'A complete diagnostic response that remains selectable.',
        text: 'Request text',
        providerConfig: ProviderConfigItem(providerName: 'Example'),
        modelConfig: ModelConfig(name: 'Voice', modelId: 'voice'),
        originalRequest: '{"request":true}',
      );
      await _pumpAtNarrowSize(
        tester,
        ListView(
          children: [SynthesisTaskCard(task: task, isFlowManaged: true)],
        ),
        locale: const Locale('ar'),
        textScale: 1.8,
      );
      await tester.tap(find.text(task.error!));
      await tester.pumpAndSettle();

      final strings = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      )!;
      expect(find.text(strings.unifiedTaskSynthesisError), findsOneWidget);
      expect(find.text(strings.unifiedTaskClose), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(strings.unifiedTaskSynthesisError),
          matching: find.byType(ConstrainedText),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text(strings.unifiedTaskClose),
          matching: find.byType(ConstrainedText),
        ),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsOneWidget);
    },
  );
}
