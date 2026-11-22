import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/widgets/catcatch_policy_menu.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('selected CatCatch policy stays on one line in a narrow slot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: CatCatchPolicyMenu(
                outputPolicy: false,
                value: 'automaticWithPrompt',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final selectedValue = find.descendant(
      of: find.byKey(const ValueKey('catcatch-resource-selection-policy')),
      matching: find.byType(ConstrainedText),
    );
    expect(selectedValue, findsOneWidget);
    expect(tester.widget<ConstrainedText>(selectedValue).maxLines, 1);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('catcatch-resource-selection-policy')),
          )
          .height,
      lessThan(60),
    );
  });
}
