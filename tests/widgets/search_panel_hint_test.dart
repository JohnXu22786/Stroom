import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/search_panel.dart';

Widget _searchPanelHost({
  required Locale locale,
  required double textScale,
  bool disableAnimations = false,
  bool tickerEnabled = true,
  InputDecorationThemeData? decorationTheme,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme ?? ThemeData(useMaterial3: true),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => InputDecorationTheme(
                data: decorationTheme,
                child: TickerMode(
                  enabled: tickerEnabled,
                  child: SearchPanel(
                    conversations: const [],
                    onConversationSelected: (_) {},
                  ),
                ),
              ),
            ),
            child: const Text('Open search'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'search hint reveals only when clipped while keeping native input semantics',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _searchPanelHost(locale: const Locale('de', 'DE'), textScale: 2),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SearchPanel)),
      )!;
      final field = find.byType(TextField);
      final hint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText && widget.data == l10n.searchPanelHint,
      );
      expect(hint, findsOneWidget);
      final hintWidget = tester.widget<ConstrainedText>(hint);
      expect(hintWidget.maxLines, 1);
      expect(tester.getSize(hint).width, lessThan(_naturalWidth(tester, hint)));
      expect(tester.takeException(), isNull);

      final hintText = find.descendant(
        of: hint,
        matching: find.text(l10n.searchPanelHint),
      );
      final clippedStartLeft = tester.getTopLeft(hintText).dx;
      await tester.pump(const Duration(milliseconds: 999));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getTopLeft(hintText).dx, lessThan(clippedStartLeft));

      final fieldWidget = tester.widget<TextField>(field);
      expect(fieldWidget.decoration!.hintText, isNull);
      expect(fieldWidget.controller!.text, isEmpty);
      await tester.tap(field);
      await tester.pump();
      expect(
        tester.getSemantics(field).getSemanticsData().hint,
        l10n.searchPanelHint,
      );
      await tester.enterText(field, 'Wortsuche');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'Wortsuche');
      expect(tester.testTextInput.hasAnyClients, isTrue);
      final hiddenHintLeft = tester.getTopLeft(hintText).dx;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getTopLeft(hintText).dx, hiddenHintLeft);
      await tester.enterText(field, '');
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(hintText).dx, clippedStartLeft);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      // The widget-test font has fixed-width glyphs, so give the fitting
      // comparison the same wide slot used by other hint regression tests.
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpWidget(
        _searchPanelHost(locale: const Locale('en', 'US'), textScale: 1),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      final fittingHint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data ==
                AppLocalizations.of(tester.element(find.byType(SearchPanel)))!
                    .searchPanelHint,
      );
      expect(fittingHint, findsOneWidget);
      expect(
        _naturalWidth(tester, fittingHint),
        lessThanOrEqualTo(tester.getSize(fittingHint).width),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _searchPanelHost(
          locale: const Locale('de', 'DE'),
          textScale: 2,
          theme: ThemeData(
            useMaterial3: true,
            textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 15)),
          ),
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      final partialThemeHint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data ==
                AppLocalizations.of(tester.element(find.byType(SearchPanel)))!
                    .searchPanelHint,
      );
      expect(partialThemeHint, findsOneWidget);
      expect(tester.widget<ConstrainedText>(partialThemeHint).style, isNotNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(320, 640);
      final focusedHintColor = Colors.purple;
      final unfocusedHintColor = Colors.green;
      await tester.pumpWidget(
        _searchPanelHost(
          locale: const Locale('de', 'DE'),
          textScale: 2,
          decorationTheme: InputDecorationThemeData(
            hintStyle: WidgetStateTextStyle.resolveWith((states) {
              final focused = states.contains(WidgetState.focused);
              return TextStyle(
                color: focused ? focusedHintColor : unfocusedHintColor,
                fontSize: focused ? 20 : 14,
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      final themedHint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data ==
                AppLocalizations.of(tester.element(find.byType(SearchPanel)))!
                    .searchPanelHint,
      );
      final effectiveHintStyle = tester
          .widget<ConstrainedText>(themedHint)
          .style!;
      expect(effectiveHintStyle.color, focusedHintColor);
      expect(effectiveHintStyle.fontSize, 20);

      await tester.pumpWidget(const SizedBox.shrink());
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpWidget(
        _searchPanelHost(
          locale: const Locale('de', 'DE'),
          textScale: 2,
          disableAnimations: true,
          theme: ThemeData.dark(useMaterial3: true),
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      final reducedMotionHint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data ==
                AppLocalizations.of(tester.element(find.byType(SearchPanel)))!
                    .searchPanelHint,
      );
      expect(reducedMotionHint, findsOneWidget);
      final reducedText = find.descendant(
        of: reducedMotionHint,
        matching: find.text(l10n.searchPanelHint),
      );
      final initialTextLeft = tester.getTopLeft(reducedText).dx;
      await tester.pump(const Duration(seconds: 10));
      expect(tester.getTopLeft(reducedText).dx, initialTextLeft);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _searchPanelHost(
          locale: const Locale('de', 'DE'),
          textScale: 2,
          tickerEnabled: false,
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      final hiddenHint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data ==
                AppLocalizations.of(tester.element(find.byType(SearchPanel)))!
                    .searchPanelHint,
      );
      final hiddenText = find.descendant(
        of: hiddenHint,
        matching: find.text(l10n.searchPanelHint),
      );
      final hiddenTextLeft = tester.getTopLeft(hiddenText).dx;
      await tester.pump(const Duration(seconds: 10));
      expect(tester.getTopLeft(hiddenText).dx, hiddenTextLeft);
      expect(tester.takeException(), isNull);
    },
  );
}

double _naturalWidth(WidgetTester tester, Finder finder) {
  final label = tester.widget<ConstrainedText>(finder);
  final context = tester.element(finder);
  final painter = TextPainter(
    text: TextSpan(
      text: label.data,
      style: label.style ?? DefaultTextStyle.of(context).style,
    ),
    textDirection: label.textDirection ?? Directionality.of(context),
    textScaler: label.textScaler ?? MediaQuery.textScalerOf(context),
    locale: label.locale ?? Localizations.maybeLocaleOf(context),
    maxLines: label.maxLines,
  )..layout();
  return painter.width;
}
