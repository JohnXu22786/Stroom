import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/task_utils.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
      'long localized info labels stay within the row in both themes at large scale',
      (tester) async {
    const viewport = Size(280, 180);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(
              size: viewport,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) {
                    final strings = AppLocalizations.of(context)!;
                    return buildInfoRow(
                      Theme.of(context).colorScheme,
                      Icons.warning_amber_outlined,
                      strings.unifiedTaskResultStatus,
                      strings.unifiedTaskPartialResult,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final strings =
          AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(ConstrainedText), findsOneWidget);
      expect(
        tester.getSize(find.text(strings.unifiedTaskPartialResult)).width,
        greaterThan(100),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
