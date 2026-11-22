import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/pages/task_flow_list_page.dart';

void main() {
  testWidgets('template picker wraps short content below its height cap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TaskFlowListPage(),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined).first);
    await tester.pumpAndSettle();

    final sheetHeight = tester.getSize(find.byType(BottomSheet)).height;
    expect(sheetHeight, lessThan(1000 * 0.86));
    expect(find.text('选择一个接近需求的流程，后续还可以继续调整。'), findsOneWidget);
    expect(find.text('使用'), findsNWidgets(3));
  });

  testWidgets('template cards adapt to phone and tablet widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> openTemplatePicker(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('en', 'US'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: TaskFlowListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start from a template'));
      await tester.pumpAndSettle();
    }

    const templateName = 'Transcribe and Summarize a Recording';
    const description =
        'Choose a recording → speech recognition → assistant summary';
    const requirements =
        'Configure an ASR model and choose an assistant for the summary.';

    await openTemplatePicker(const Size(390, 844));

    final phoneTitle = find.text(templateName);
    final phoneDescription = find.text(description);
    final phoneRequirements = find.text(requirements);
    final phoneUse = find.widgetWithText(FilledButton, 'Use').first;
    expect(phoneTitle, findsOneWidget);
    expect(phoneDescription, findsOneWidget);
    expect(phoneRequirements, findsOneWidget);
    expect(
      tester.widget<Text>(phoneDescription).maxLines,
      isNull,
      reason: 'Phone descriptions must wrap instead of being truncated.',
    );
    expect(
      tester.getTopLeft(phoneUse).dy,
      greaterThan(tester.getBottomLeft(phoneRequirements).dy),
      reason: 'The phone Use action belongs below all template copy.',
    );

    await tester.tap(phoneUse);
    // The builder has a separate phone-width layout outside this regression's
    // scope; keep its route at tablet width while checking that Use navigates.
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpAndSettle();
    expect(find.byType(TaskFlowBuilderPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await openTemplatePicker(const Size(768, 1024));

    final tabletTitle = find.text(templateName);
    final tabletListTile =
        find.ancestor(of: tabletTitle, matching: find.byType(ListTile));
    expect(tabletListTile, findsOneWidget);
    final tabletTile = tester.widget<ListTile>(tabletListTile);
    expect(tabletTile.trailing, isA<FilledButton>());
    expect(
      tester.getCenter(find.widgetWithText(FilledButton, 'Use').first).dx,
      greaterThan(tester.getCenter(tabletTitle).dx),
      reason: 'The tablet Use action remains trailing to the copy.',
    );
  });
}
