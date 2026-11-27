import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('uses active field hint style and preserves the full semantics', (
    tester,
  ) async {
    final states = MaterialStatesController();
    addTearDown(states.dispose);
    const hint = 'Enter a long localized value that needs to be revealed';
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
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
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: TextField(
                key: const Key('input-hint-field'),
                statesController: states,
                decoration: InputDecoration(
                  hint: ConstrainedInputHint(
                    hint,
                    statesController: states,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == hint,
    );
    expect(hintFinder, findsOneWidget);
    final initialStyle = tester.widget<ConstrainedText>(hintFinder).style!;
    expect(initialStyle.color, Colors.blue);
    final editableText = find.descendant(
      of: find.byKey(const Key('input-hint-field')),
      matching: find.byType(EditableText),
    );
    expect(tester.getSemantics(editableText).getSemanticsData().label, hint);

    await tester.tap(find.byKey(const Key('input-hint-field')));
    await tester.pump();
    expect(tester.widget<ConstrainedText>(hintFinder).style!.color, Colors.red);
    expect(tester.getSemantics(hintFinder), isNotNull);

    await tester.enterText(find.byKey(const Key('input-hint-field')), 'typed');
    await tester.pump();
    expect(tester.widget<EditableText>(editableText).controller.text, 'typed');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('matches InputDecorator hint styling across states and themes', (
    tester,
  ) async {
    const hint = 'A production hint';

    Future<TextStyle> sample({
      required bool useMaterial3,
      required bool custom,
      bool disabled = false,
      bool error = false,
      bool focused = false,
      bool hovered = false,
      bool localStyle = false,
      bool themedStyle = true,
    }) async {
      final states = MaterialStatesController();
      final focusNode = FocusNode();
      const baseStyle = TextStyle(fontSize: 17, letterSpacing: 0.2);
      final decorationStyle = WidgetStateTextStyle.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.error)
              ? Colors.red
              : states.contains(WidgetState.disabled)
                  ? Colors.grey
                  : states.contains(WidgetState.focused)
                      ? Colors.green
                      : Colors.blue,
          fontSize: 23,
        );
      });
      final localDecorationStyle = WidgetStateTextStyle.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.error)
              ? Colors.deepOrange
              : states.contains(WidgetState.focused)
                  ? Colors.purple
                  : Colors.teal,
          fontSize: 27,
        );
      });
      final theme = ThemeData(
        useMaterial3: useMaterial3,
        textTheme: ThemeData(useMaterial3: useMaterial3).textTheme.copyWith(
              bodyLarge: const TextStyle(fontSize: 21),
              titleMedium: const TextStyle(fontSize: 19),
            ),
        inputDecorationTheme: themedStyle
            ? InputDecorationTheme(hintStyle: decorationStyle)
            : const InputDecorationTheme(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: TextField(
                  key: const Key('style-reference-field'),
                  enabled: !disabled,
                  focusNode: focusNode,
                  statesController: states,
                  style: baseStyle,
                  decoration: InputDecoration(
                    hintText: custom ? null : hint,
                    hint: custom
                        ? ConstrainedInputHint(
                            hint,
                            statesController: states,
                            baseStyle: baseStyle,
                            hintStyle: localStyle ? localDecorationStyle : null,
                            hasError: error,
                          )
                        : null,
                    hintStyle: localStyle ? localDecorationStyle : null,
                    errorText: error ? 'Invalid value' : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      if (focused) {
        focusNode.requestFocus();
        await tester.pump();
      }
      if (hovered) {
        await tester.sendEventToBinding(
          PointerHoverEvent(
            position: tester
                .getCenter(find.byKey(const Key('style-reference-field'))),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pump();
      }
      final style = custom
          ? tester.widget<ConstrainedText>(find.byType(ConstrainedText)).style!
          : tester.widget<Text>(find.text(hint)).style!;
      await tester.pumpWidget(const SizedBox.shrink());
      focusNode.dispose();
      states.dispose();
      return style;
    }

    for (final useMaterial3 in [false, true]) {
      for (final state in [
        (disabled: false, error: false, focused: false, hovered: false),
        (disabled: false, error: false, focused: false, hovered: true),
        (disabled: true, error: false, focused: false, hovered: false),
        (disabled: false, error: true, focused: false, hovered: false),
        (disabled: false, error: false, focused: true, hovered: false),
      ]) {
        final native = await sample(
          useMaterial3: useMaterial3,
          custom: false,
          disabled: state.disabled,
          error: state.error,
          focused: state.focused,
          hovered: state.hovered ?? false,
          localStyle: true,
        );
        final constrained = await sample(
          useMaterial3: useMaterial3,
          custom: true,
          disabled: state.disabled,
          error: state.error,
          focused: state.focused,
          hovered: state.hovered ?? false,
          localStyle: true,
        );
        expect(constrained, native,
            reason: 'M3=$useMaterial3 state=$state local decoration style');
      }

      final nativeDefault = await sample(
        useMaterial3: useMaterial3,
        custom: false,
        disabled: true,
        themedStyle: false,
        localStyle: false,
      );
      final constrainedDefault = await sample(
        useMaterial3: useMaterial3,
        custom: true,
        disabled: true,
        themedStyle: false,
        localStyle: false,
      );
      expect(constrainedDefault, nativeDefault,
          reason: 'M3=$useMaterial3 default disabled style');
    }
  });

  testWidgets('dialog fields keep hint semantics on their native node', (
    tester,
  ) async {
    final states = MaterialStatesController();
    addTearDown(states.dispose);
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const hint = 'https://example.com/audio.mp3';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Enter URL'),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('dialog-input'),
                        statesController: states,
                        autofocus: true,
                        decoration: InputDecoration(
                          hint: ConstrainedInputHint(
                            hint,
                            statesController: states,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('dialog-input'));
    await tester.tap(field);
    await tester.pump();
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    expect(tester.getSemantics(editable).getSemanticsData().label, hint);
    await tester.enterText(field, 'https://example.test/audio.mp3');
    await tester.pump();
    expect(tester.getSemantics(editable).getSemanticsData().label, hint);
    semantics.dispose();
  });

  testWidgets('field-level hint semantics merge into the editable node', (
    tester,
  ) async {
    final states = MaterialStatesController();
    addTearDown(states.dispose);
    final semantics = tester.ensureSemantics();
    const hint = 'A complete hint that is visually constrained';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: Semantics(
                hint: hint,
                child: TextField(
                  key: const Key('wrapped-field'),
                  statesController: states,
                  decoration: InputDecoration(
                    hint: ExcludeSemantics(
                      child: ConstrainedInputHint(
                        hint,
                        statesController: states,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const Key('wrapped-field'));
    await tester.tap(field);
    await tester.pump();
    final fieldData = tester.getSemantics(field).getSemanticsData();
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    final editableData = tester.getSemantics(editable).getSemanticsData();
    expect(fieldData.hint, hint);
    expect(fieldData.hasFlag(SemanticsFlag.isTextField), isTrue);
    expect(fieldData.hasAction(SemanticsAction.focus), isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reveals only hints measured wider than their decoration slot', (
    tester,
  ) async {
    final states = MaterialStatesController();
    addTearDown(states.dispose);
    const hint = 'https://very-long.example.test/catalog.json';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: TextField(
                statesController: states,
                decoration: InputDecoration(
                  hint: ConstrainedInputHint(hint, statesController: states),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final textFinder = find.text(hint);
    final start = tester.getTopLeft(textFinder);
    final hintFinder = find.byType(ConstrainedInputHint);
    final measuredHint = tester.widget<ConstrainedText>(
      find.byType(ConstrainedText),
    );
    final hintContext = tester.element(find.byType(ConstrainedText));
    final naturalHint = TextPainter(
      text: TextSpan(text: hint, style: measuredHint.style),
      textDirection: Directionality.of(hintContext),
      textScaler: MediaQuery.textScalerOf(hintContext),
    )..layout();
    expect(naturalHint.width, greaterThan(tester.getSize(hintFinder).width));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(textFinder).dx, lessThan(start.dx));

    expect(tester.takeException(), isNull);
  });
}
