import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/mcp_server_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

// Unit owner: vertical_mcp_arguments_hint.
// Functional suite mapping: feature-ui.
void main() {
  Future<void> openStdioConfig(
    WidgetTester tester, {
    double textScale = 1,
    Locale locale = const Locale('en', 'US'),
    bool stdio = true,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
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
    if (stdio) {
      final context = tester.element(find.byType(Scaffold).last);
      await tester.tap(find.text(AppLocalizations.of(context)!.mcpLocalStdio));
      await tester.pumpAndSettle();
    }
  }

  Finder argumentsField() => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.helper != null,
      );

  testWidgets('arguments instruction wraps completely at 320x640', (
    tester,
  ) async {
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
  });

  testWidgets('French compact AppBar actions grow to fit at 4x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openStdioConfig(
      tester,
      textScale: 4,
      locale: const Locale('fr', 'FR'),
      stdio: false,
    );

    final discardLabel = find.text('Abandonner');
    expect(discardLabel, findsOneWidget);
    final labelContext = tester.element(discardLabel);
    final painter = TextPainter(
      text: TextSpan(
        text: 'Abandonner',
        style: DefaultTextStyle.of(labelContext).style,
      ),
      textDirection: Directionality.of(labelContext),
      textScaler: MediaQuery.textScalerOf(labelContext),
      locale: Localizations.localeOf(labelContext),
    )..layout(maxWidth: tester.getSize(discardLabel).width);
    expect(painter.computeLineMetrics().length, greaterThan(1));

    final actionButton = find
        .ancestor(of: discardLabel, matching: find.byType(TextButton))
        .first;
    final actionSlot = find
        .ancestor(
          of: actionButton,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height != null &&
                widget.height! > 72,
          ),
        )
        .first;
    final labelRect = tester.getRect(discardLabel);
    final slotRect = tester.getRect(actionSlot);
    final appBarRect = tester.getRect(find.byType(AppBar).last);
    final dialogRect = tester.getRect(find.byType(Dialog));
    expect(slotRect.height, greaterThan(72));
    expect(slotRect.inflate(0.5).contains(labelRect.topLeft), isTrue);
    expect(slotRect.inflate(0.5).contains(labelRect.bottomRight), isTrue);
    expect(appBarRect.inflate(0.5).contains(labelRect.topLeft), isTrue);
    expect(appBarRect.inflate(0.5).contains(labelRect.bottomRight), isTrue);
    expect(appBarRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
    for (final label in [find.text('Enregistrer'), discardLabel]) {
      final button =
          find.ancestor(of: label, matching: find.byType(TextButton)).first;
      expect(dialogRect.contains(tester.getRect(button).topLeft), isTrue);
      expect(dialogRect.contains(tester.getRect(button).bottomRight), isTrue);
    }
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.byIcon(Icons.save), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.save));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Abandonner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('French compact AppBar actions scroll within a short dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openStdioConfig(
      tester,
      textScale: 4,
      locale: const Locale('fr', 'FR'),
      stdio: false,
    );

    final viewport = const Rect.fromLTWH(0, 0, 320, 320);
    final dialogTitle = find.text('Nouveau serveur MCP');
    expect(dialogTitle, findsOneWidget);
    final titleRect = tester.getRect(dialogTitle);
    expect(titleRect.top, greaterThanOrEqualTo(0));
    expect(titleRect.bottom, lessThanOrEqualTo(320));
    for (final (label, buttonLabel) in [
      (find.text('Enregistrer'), 'Enregistrer'),
      (find.text('Abandonner'), 'Abandonner'),
    ]) {
      final button =
          find.ancestor(of: label, matching: find.byType(TextButton)).first;
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final buttonRect = tester.getRect(button);
      final labelRect = tester.getRect(label);
      expect(viewport.contains(buttonRect.topLeft), isTrue);
      expect(viewport.contains(buttonRect.bottomRight), isTrue);
      expect(buttonRect.contains(labelRect.topLeft), isTrue);
      expect(buttonRect.inflate(0.5).contains(labelRect.bottomRight), isTrue);
      expect(find.text(buttonLabel), findsOneWidget);
    }

    final outerScroll = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(outerScroll.position.pixels, greaterThan(0));

    final nameField = find.byType(TextField).first;
    await tester.ensureVisible(nameField);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewport.contains(tester.getRect(nameField).topLeft), isTrue);

    final beforeFormScroll = outerScroll.position.pixels;
    await tester.dragFrom(const Offset(160, 160), const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 300));
    final afterFormScroll = outerScroll.position.pixels;
    expect(afterFormScroll, greaterThan(beforeFormScroll));

    await tester.dragFrom(const Offset(160, 160), const Offset(0, 480));
    await tester.pump(const Duration(milliseconds: 300));
    expect(outerScroll.position.pixels, lessThan(afterFormScroll));
    await tester.ensureVisible(find.text('Abandonner'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('French compact AppBar actions remain reachable with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await openStdioConfig(
      tester,
      textScale: 4,
      locale: const Locale('fr', 'FR'),
      stdio: false,
    );

    final nameField = find.byType(TextField).first;
    expect(nameField, findsOneWidget);
    await tester.ensureVisible(nameField);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(nameField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final visibleArea = const Rect.fromLTWH(0, 0, 320, 380);
    await tester.ensureVisible(nameField);
    await tester.pump(const Duration(milliseconds: 300));
    expect(visibleArea.contains(tester.getRect(nameField).topLeft), isTrue);
    expect(visibleArea.contains(tester.getRect(nameField).bottomRight), isTrue);
    for (final label in [find.text('Enregistrer'), find.text('Abandonner')]) {
      final button =
          find.ancestor(of: label, matching: find.byType(TextButton)).first;
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 300));
      final buttonRect = tester.getRect(button);
      final labelRect = tester.getRect(label);
      expect(visibleArea.contains(buttonRect.topLeft), isTrue);
      expect(visibleArea.contains(buttonRect.bottomRight), isTrue);
      expect(buttonRect.inflate(0.5).contains(labelRect.topLeft), isTrue);
      expect(buttonRect.inflate(0.5).contains(labelRect.bottomRight), isTrue);
    }

    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English compact AppBar action retains 48 dp at 1x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openStdioConfig(tester, stdio: false);

    final saveLabel = find.text('Save');
    expect(saveLabel, findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar).last);
    expect(appBar.bottom!.preferredSize.height, 96);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.byIcon(Icons.save), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
            .getSize(
              find.text(
                AppLocalizations.of(tester.element(field))!.mcpArgumentsHint,
              ),
            )
            .height,
        greaterThan(40),
      );
      expect(
        find.text(AppLocalizations.of(tester.element(field))!.mcpArgumentsHint),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MCP empty-field hints reveal clips and retain native semantics',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openStdioConfig(
        tester,
        theme: ThemeData(
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            hintStyle: WidgetStateTextStyle.resolveWith((states) {
              return TextStyle(
                color: states.contains(WidgetState.focused)
                    ? Colors.red
                    : Colors.blue,
              );
            }),
          ),
        ),
      );
      expect(argumentsField(), findsOneWidget);
      final semantics = tester.ensureSemantics();
      final context = tester.element(argumentsField());
      final l10n = AppLocalizations.of(context)!;
      final clippedHintMeasurements = <String, double>{};
      for (final hint in [
        l10n.mcpServerNameHint,
        l10n.mcpCommandExample,
        l10n.mcpApiKeyHint,
        l10n.mcpDescriptionHint,
      ]) {
        final hintFinder = find.text(hint);
        await tester.ensureVisible(hintFinder);
        await tester.pumpAndSettle();
        final fieldFinder = find
            .ancestor(of: hintFinder, matching: find.byType(TextField))
            .first;
        final field = tester.widget<TextField>(fieldFinder);
        expect(field.decoration!.hintText, isNull);
        expect(field.statesController, isNotNull);
        final constrainedHint = (field.decoration!.hint! as ExcludeSemantics)
            .child as ConstrainedInputHint;
        expect(constrainedHint.data, hint);
        expect(constrainedHint.maxLines, field.maxLines ?? 1);
        final editableText = find.descendant(
          of: fieldFinder,
          matching: find.byType(EditableText),
        );
        expect(
          tester.getSemantics(editableText).getSemanticsData().hint,
          hint,
        );
        final textFinder = find.descendant(
          of: find.byWidget(constrainedHint),
          matching: find.byType(ConstrainedText),
        );
        final measuredText = tester.widget<ConstrainedText>(textFinder);
        final textContext = tester.element(textFinder);
        final slotWidth = tester.getSize(textFinder).width;
        final painter = TextPainter(
          text: TextSpan(text: hint, style: measuredText.style),
          textDirection: Directionality.of(textContext),
          textScaler: MediaQuery.textScalerOf(textContext),
          locale: Localizations.localeOf(textContext),
          maxLines: measuredText.maxLines,
          ellipsis: '…',
        )..layout(maxWidth: slotWidth);
        final fullPainter = TextPainter(
          text: TextSpan(text: hint, style: measuredText.style),
          textDirection: Directionality.of(textContext),
          textScaler: MediaQuery.textScalerOf(textContext),
          locale: Localizations.localeOf(textContext),
        )..layout(maxWidth: slotWidth);
        final overflow = measuredText.maxLines == 1
            ? (TextPainter(
                text: TextSpan(text: hint, style: measuredText.style),
                textDirection: Directionality.of(textContext),
                textScaler: MediaQuery.textScalerOf(textContext),
                locale: Localizations.localeOf(textContext),
              )..layout())
            : null;
        final measuredOverflow = measuredText.maxLines == 1
            ? overflow!.width - slotWidth
            : fullPainter.height - painter.height;
        expect(measuredOverflow, greaterThan(0), reason: hint);
        debugPrint(
          'MCP hint=$hint slot=${tester.getSize(textFinder)} '
          'intrinsicWidth=${overflow?.width ?? fullPainter.width} '
          'naturalHeight=${fullPainter.height} '
          'maxLines=${measuredText.maxLines} clippedBy=$measuredOverflow',
        );
        clippedHintMeasurements[hint] = measuredOverflow;

        final visualLabel = find.descendant(
          of: find.byWidget(constrainedHint),
          matching: find.byType(ConstrainedText),
        );
        expect(
          tester.widget<ConstrainedText>(visualLabel).style!.color,
          Colors.blue,
        );
        await tester.tap(fieldFinder);
        await tester.pump();
        expect(
          tester.widget<ConstrainedText>(visualLabel).style!.color,
          Colors.red,
        );
        final enteredValue = 'Native value ${clippedHintMeasurements.length}';
        await tester.enterText(fieldFinder, enteredValue);
        await tester.pump();
        expect(
          tester.widget<EditableText>(editableText).controller.text,
          enteredValue,
        );
        expect(tester.getSemantics(editableText).getSemanticsData().hint, hint);
      }
      expect(clippedHintMeasurements, hasLength(4));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('MCP SSE URL example reveals inside the production field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await openStdioConfig(
      tester,
      stdio: false,
      theme: ThemeData(
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: WidgetStateTextStyle.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.focused)
                  ? Colors.red
                  : Colors.blue,
            );
          }),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold).last);
    final hint = AppLocalizations.of(context)!.mcpSseUrlExample;
    final fieldFinder = find
        .ancestor(of: find.text(hint), matching: find.byType(TextField))
        .first;
    final field = tester.widget<TextField>(fieldFinder);
    final visualHint = (field.decoration!.hint! as ExcludeSemantics).child
        as ConstrainedInputHint;
    expect(visualHint.data, hint);
    final visualText = find.descendant(
      of: find.byWidget(visualHint),
      matching: find.byType(ConstrainedText),
    );
    expect(
        tester.widget<ConstrainedText>(visualText).style!.color, Colors.blue);
    final editableText = find.descendant(
      of: fieldFinder,
      matching: find.byType(EditableText),
    );
    expect(tester.getSemantics(editableText).getSemanticsData().hint, hint);
    final textFinder = find.descendant(
      of: find.byWidget(visualHint),
      matching: find.byType(ConstrainedText),
    );
    final text = tester.widget<ConstrainedText>(textFinder);
    final textContext = tester.element(textFinder);
    final slotWidth = tester.getSize(textFinder).width;
    final natural = TextPainter(
      text: TextSpan(text: hint, style: text.style),
      textDirection: Directionality.of(textContext),
      textScaler: MediaQuery.textScalerOf(textContext),
      locale: Localizations.localeOf(textContext),
    )..layout();
    expect(natural.width, greaterThan(slotWidth));
    debugPrint(
      'MCP SSE hint=$hint slotWidth=$slotWidth intrinsicWidth=${natural.width}',
    );
    await tester.tap(fieldFinder);
    await tester.pump();
    expect(tester.widget<ConstrainedText>(visualText).style!.color, Colors.red);
    await tester.enterText(fieldFinder, 'https://example.org/events');
    await tester.pump();
    expect(tester.getSemantics(editableText).getSemanticsData().hint, hint);
    expect(
      tester.widget<EditableText>(editableText).controller.text,
      'https://example.org/events',
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
