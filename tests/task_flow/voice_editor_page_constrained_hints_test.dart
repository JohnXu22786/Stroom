import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/voice_editor_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpVoiceEditor(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
    ThemeData? theme,
    InputDecorationThemeData? decorationTheme,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    Widget home = VoiceEditorPage(
      initialVoices: [VoiceEntry(name: '', id: '')],
    );
    if (decorationTheme != null) {
      home = InputDecorationTheme(data: decorationTheme, child: home);
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: theme ?? ThemeData(useMaterial3: true),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Spanish input hints reveal within the narrow voice row', (
    tester,
  ) async {
    await pumpVoiceEditor(
      tester,
      locale: const Locale('es', 'ES'),
      size: const Size(320, 640),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('es', 'ES'));
    for (final hint in [l10n.voiceName, l10n.voiceId]) {
      final constrainedHint = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == hint,
      );
      expect(constrainedHint, findsOneWidget);
      final theme = Theme.of(tester.element(constrainedHint));
      final hintStyle = tester.widget<ConstrainedText>(constrainedHint).style!;
      expect(hintStyle.fontSize, theme.textTheme.bodyLarge!.fontSize);
      expect(hintStyle.fontWeight, theme.textTheme.bodyLarge!.fontWeight);
      expect(hintStyle.color, theme.colorScheme.onSurfaceVariant);
      final field = find
          .ancestor(
            of: constrainedHint,
            matching: find.byType(TextField),
          )
          .first;
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      final naturalText = TextPainter(
        text: TextSpan(text: hint, style: hintStyle),
        textDirection: Directionality.of(tester.element(constrainedHint)),
        textScaler: MediaQuery.textScalerOf(tester.element(constrainedHint)),
      )..layout();
      expect(
        naturalText.width,
        greaterThan(tester.getSize(constrainedHint).width),
        reason: 'the complete localized hint is wider than its finite slot',
      );
      expect(tester.getSemantics(constrainedHint).label, hint);
    }

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    final row = tester.getRect(find.byKey(const ValueKey('voice_row_0')));
    final dragHandle = tester.getRect(find.byIcon(Icons.drag_indicator));
    final deleteIcon = tester.getRect(find.byIcon(Icons.delete));
    expect(dragHandle.size, const Size(24, 24));
    expect(deleteIcon.size, const Size(24, 24));
    expect(dragHandle.left, closeTo(row.left + 20, 0.5));
    expect(deleteIcon.right, closeTo(row.right - 24, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fitting localized hints stay stationary and fields stay native',
      (
    tester,
  ) async {
    final statefulHintTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    final localHintTheme = InputDecorationThemeData(
      hintStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.focused)
              ? Colors.purple
              : Colors.green,
        ),
      ),
    );
    await pumpVoiceEditor(
      tester,
      locale: const Locale('es', 'ES'),
      // The widget test font uses fixed-width Ahem glyphs; 1000 dp gives the
      // complete Spanish hints room to fit in this fixture.
      size: const Size(1000, 640),
      theme: statefulHintTheme,
      decorationTheme: localHintTheme,
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('es', 'ES'));
    for (final hint in [l10n.voiceName, l10n.voiceId]) {
      final constrainedHint = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == hint,
      );
      expect(constrainedHint, findsOneWidget);
      final theme = Theme.of(tester.element(constrainedHint));
      final hintStyle = tester.widget<ConstrainedText>(constrainedHint).style!;
      expect(hintStyle.fontSize, theme.textTheme.bodyLarge!.fontSize);
      expect(hintStyle.fontWeight, theme.textTheme.bodyLarge!.fontWeight);
      expect(hintStyle.color, Colors.green);
      final naturalText = TextPainter(
        text: TextSpan(text: hint, style: hintStyle),
        textDirection: Directionality.of(tester.element(constrainedHint)),
        textScaler: MediaQuery.textScalerOf(tester.element(constrainedHint)),
      )..layout();
      expect(
        naturalText.width,
        lessThanOrEqualTo(tester.getSize(constrainedHint).width),
        reason: 'the complete localized hint fits in its slot and stays still',
      );
    }

    final nameField = find.byType(TextField).first;
    await tester.tap(nameField);
    await tester.pumpAndSettle();
    final focusedNameHint = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == l10n.voiceName,
    );
    expect(
      tester.widget<ConstrainedText>(focusedNameHint).style!.color,
      Colors.purple,
    );
    await tester.enterText(nameField, 'Mi voz');
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text, 'Mi voz');
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
