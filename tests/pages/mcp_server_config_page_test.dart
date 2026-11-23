import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/mcp_server_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

// Unit owner: vertical_mcp_arguments_hint.
// Functional suite mapping: feature-ui.
void main() {
  Future<void> openStdioConfig(WidgetTester tester,
      {double textScale = 1}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showMcpServerConfigDialog(
                    context: context,
                    entryId: 'missing-entry',
                    configIndex: -1,
                  ),
                  child: const Text('Open MCP settings'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open MCP settings'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).last);
    await tester.tap(find.text(AppLocalizations.of(context)!.mcpLocalStdio));
    await tester.pumpAndSettle();
  }

  Finder argumentsField() => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.helper != null,
      );

  testWidgets(
    'arguments instruction wraps completely at 320x640',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await openStdioConfig(tester);
      final context = tester.element(argumentsField());
      final instruction = AppLocalizations.of(context)!.mcpArgumentsHint;
      final helper = find.text(instruction);
      await tester.ensureVisible(helper);
      await tester.pumpAndSettle();

      expect(helper, findsOneWidget);
      expect(tester.getSize(helper).height, greaterThan(20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'arguments helper stays reachable at 2x scale with focused native input',
    (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await openStdioConfig(tester, textScale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      final field = argumentsField();
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(MediaQuery.textScalerOf(tester.element(field)).scale(1), 2);
      await tester.tap(field);
      await tester.enterText(field, '--directory, /tmp');
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(field);
      expect(textField.controller!.text, '--directory, /tmp');
      expect(
          tester
              .getSize(find.text(
                  AppLocalizations.of(tester.element(field))!.mcpArgumentsHint))
              .height,
          greaterThan(40));
      expect(
          find.text(
              AppLocalizations.of(tester.element(field))!.mcpArgumentsHint),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
