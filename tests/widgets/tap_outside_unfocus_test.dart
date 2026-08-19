// Widget tests for the app-wide tap-outside blur behavior.
//
// Flutter's default `EditableTextTapOutsideIntent` action only unfocuses a
// focused text field on desktop platforms (and for mouse/stylus events on
// mobile); a mobile touch outside the field deliberately leaves it focused,
// which surfaces as "the input cursor stays there and tapping beside it
// does nothing". The app overrides that intent at the root
// ([TapOutsideUnfocus]) so every text field blurs on tap-outside on every
// platform and pointer kind.
//
// Behaviors protected:
//  1. With the override, a mobile tap outside a focused field blurs it.
//  2. Control: without the override, the mobile tap-outside does NOT blur
//     (the SDK default this fix targets — keeps the control meaningful).
//  3. Tapping another text field still transfers focus (no interference).
//  4. A button outside the field still receives its tap (the override does
//     not swallow taps).
//  5. Desktop behavior is unchanged: tap-outside still blurs.
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/widgets/tap_outside_unfocus.dart';

/// Runs [body] with [debugDefaultTargetPlatformOverride] forced to
/// [platform], guaranteeing the override is reset even on failure — the
/// test binding asserts all foundation debug variables are unset at the
/// end of the test body (before addTearDown runs).
Future<void> withPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Pumps the harness. [withOverride] controls whether the app-level
/// [TapOutsideUnfocus] override (as wired in application.dart) is present.
/// [focusNodes] are attached to the two text fields so tests can observe
/// focus directly.
Widget buildApp({
  required bool withOverride,
  VoidCallback? onButtonPressed,
  List<FocusNode>? focusNodes,
}) {
  final nodes = focusNodes ?? [FocusNode(), FocusNode()];
  return MaterialApp(
    builder: withOverride
        ? (context, child) =>
            TapOutsideUnfocus(child: child ?? const SizedBox.shrink())
        : null,
    home: Scaffold(
      body: Column(
        children: [
          TextField(key: const Key('field-a'), focusNode: nodes[0]),
          TextField(key: const Key('field-b'), focusNode: nodes[1]),
          const Expanded(
            child: Center(child: Text('outside', key: Key('outside'))),
          ),
          ElevatedButton(
            key: const Key('button'),
            onPressed: onButtonPressed,
            child: const Text('Go'),
          ),
        ],
      ),
    ),
  );
}

bool fieldFocused(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).focusNode!.hasFocus;
}

void main() {
  group('TapOutsideUnfocus', () {
    testWidgets(
        'mobile: with the override, tapping outside a focused text field '
        'blurs it', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await tester.pumpWidget(buildApp(withOverride: true));
        await tester.tap(find.byKey(const Key('field-a')));
        await tester.pump();
        expect(fieldFocused(tester, 'field-a'), isTrue,
            reason: 'precondition: the field is focused');

        await tester.tap(find.byKey(const Key('outside')));
        await tester.pump();
        expect(fieldFocused(tester, 'field-a'), isFalse,
            reason: 'a mobile tap outside the field must blur it '
                '(the reported bug: the cursor stays and tapping beside '
                'does nothing)');
      });
    });

    testWidgets(
        'mobile control: WITHOUT the override the tap-outside does not '
        'blur (the SDK default this fix targets)', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await tester.pumpWidget(buildApp(withOverride: false));
        await tester.tap(find.byKey(const Key('field-a')));
        await tester.pump();
        expect(fieldFocused(tester, 'field-a'), isTrue);

        await tester.tap(find.byKey(const Key('outside')));
        await tester.pump();
        expect(fieldFocused(tester, 'field-a'), isTrue,
            reason: 'Flutter mobile default keeps the field focused on a '
                'touch outside — this is exactly why the app-level override '
                'exists');
      });
    });

    testWidgets(
        'tapping another text field still transfers focus (fields are not '
        'blocked by the override)', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await tester.pumpWidget(buildApp(withOverride: true));
        await tester.tap(find.byKey(const Key('field-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('field-b')));
        await tester.pump();
        expect(fieldFocused(tester, 'field-b'), isTrue,
            reason: 'the second field gains focus');
        expect(fieldFocused(tester, 'field-a'), isFalse,
            reason: 'the first field loses focus');
      });
    });

    testWidgets(
        'a button outside the field still receives its tap (the override '
        'does not swallow taps)', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        var pressed = false;
        await tester.pumpWidget(buildApp(
          withOverride: true,
          onButtonPressed: () => pressed = true,
        ));
        await tester.tap(find.byKey(const Key('field-a')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('button')));
        await tester.pump();
        expect(pressed, isTrue,
            reason: 'the button still fires while the field is blurred');
        expect(fieldFocused(tester, 'field-a'), isFalse,
            reason: 'the outside tap blurred the field as well');
      });
    });

    testWidgets(
        'desktop: with the override, tap-outside still blurs (behavior is '
        'unchanged from the SDK default)', (tester) async {
      await withPlatform(tester, TargetPlatform.windows, () async {
        await tester.pumpWidget(buildApp(withOverride: true));
        await tester.tap(find.byKey(const Key('field-a')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('outside')));
        await tester.pump();
        expect(fieldFocused(tester, 'field-a'), isFalse);
      });
    });
  });
}
