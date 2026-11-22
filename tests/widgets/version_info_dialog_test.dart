import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/version_info_dialog.dart';

Future<void> _showVersionDialog(
  WidgetTester tester, {
  required ThemeData theme,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de', 'DE'),
      theme: theme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const VersionInfoDialog(
                  version: '0.5.4 (build 20261120, commit 123456789abcdef)',
                  releaseTime: '2026-11-20T14:35:22',
                  releaseNotes:
                      'This release includes a long flowing release note that must wrap naturally instead of being clipped or moved like a label.',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('long localized dialog labels stay within the narrow dialog', (
    tester,
  ) async {
    await _showVersionDialog(tester, theme: ThemeData.light(), textScale: 1.8);

    final label = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == 'Veröffentlichungsdatum',
    );
    expect(label, findsOneWidget);
    final labelWidget = tester.widget<ConstrainedText>(label);
    final labelContext = tester.element(label);
    final naturalLabel = TextPainter(
      text: TextSpan(
        text: labelWidget.data,
        style: DefaultTextStyle.of(labelContext).style.merge(labelWidget.style),
      ),
      textDirection: Directionality.of(labelContext),
      textScaler: MediaQuery.textScalerOf(labelContext),
      locale: Localizations.localeOf(labelContext),
      maxLines: labelWidget.maxLines,
    )..layout();
    expect(naturalLabel.width, greaterThan(tester.getSize(label).width));
    expect(find.text('Versionsinformationen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release notes remain flowing content in dark theme', (
    tester,
  ) async {
    await _showVersionDialog(tester, theme: ThemeData.dark(), textScale: 1.8);

    final notes = find.textContaining('This release includes a long flowing');
    expect(notes, findsOneWidget);
    expect(tester.getSize(notes).height, greaterThan(40));
    expect(tester.takeException(), isNull);
  });
}
