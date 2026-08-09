// Tests for the 上下文长度 suggestion popup on the LLM model config page:
// tapping the context-length input shows suggested values (1024, 2048, ...),
// the user can select one or type freely, and the popup never blocks input.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

const kExpectedSuggestions = kContextLengthSuggestions;

Future<void> pumpPage(WidgetTester tester, {ModelConfig? model}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: LlmModelConfigPage(model: model)));
  await tester.pump();
}

/// Context length field: index 2 of TextField (name=0, modelId=1, context=2).
Finder get contextField => find.byType(TextField).at(2);

/// The suggestion popup's ListView (inside the overlay).
Finder get popupList =>
    find.byKey(const ValueKey('labeledTextFieldSuggestions'));

/// All values currently offered by the popup, in order.
List<String> popupValues(WidgetTester tester) {
  final listView = tester.widget<ListView>(popupList);
  final delegate = listView.childrenDelegate as SliverChildListDelegate;
  return delegate.children
      .whereType<ListTile>()
      .map((t) => (t.title! as Text).data!)
      .toList();
}

void main() {
  testWidgets('tapping the 上下文长度 field shows all suggestion values',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();

    expect(popupValues(tester), kExpectedSuggestions);
    // First items are visible without scrolling the popup.
    expect(find.text('1024'), findsOneWidget);
    expect(find.text('8192'), findsOneWidget);
  });

  testWidgets('selecting a suggestion fills the field and closes the popup',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();

    await tester.tap(find.text('65536'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(contextField);
    expect(field.controller?.text, '65536');
    // Popup is closed after selection.
    expect(find.text('131072'), findsNothing);
    expect(find.text('262144'), findsNothing);
  });

  testWidgets('typing filters the suggestions', (tester) async {
    await pumpPage(tester);

    await tester.enterText(contextField, '65');
    await tester.pump();

    expect(find.text('65536'), findsOneWidget);
    expect(find.text('1024'), findsNothing);
    expect(find.text('4096'), findsNothing);
    expect(find.text('262144'), findsNothing);
  });

  testWidgets('typing a value with no match closes the popup', (tester) async {
    await pumpPage(tester);

    await tester.enterText(contextField, '99999');
    await tester.pump();

    for (final value in kExpectedSuggestions) {
      expect(find.text(value), findsNothing, reason: 'suggestion $value');
    }

    // Backspacing back to empty restores the full suggestion list.
    await tester.enterText(contextField, '');
    await tester.pump();
    expect(popupValues(tester), kExpectedSuggestions);
  });

  testWidgets(
      'after a no-match filter, re-tapping the field reopens the '
      'full list', (tester) async {
    await pumpPage(tester);

    await tester.enterText(contextField, '99999');
    await tester.pump();
    expect(find.text('1024'), findsNothing);

    // The popup was left in an invisible empty state; re-tapping must
    // bring the full list back instead of being swallowed.
    await tester.tap(contextField);
    await tester.pump();
    expect(popupValues(tester), kExpectedSuggestions);
    // The non-matching input must survive.
    expect(
      tester.widget<TextField>(contextField).controller?.text,
      '99999',
    );
  });

  testWidgets('direct typing still works while the popup is open',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();
    // Popup is open; typing directly must work normally.
    await tester.enterText(contextField, '8192');
    await tester.pump();

    final field = tester.widget<TextField>(contextField);
    expect(field.controller?.text, '8192');
    // Popup narrows to the typed value instead of blocking input.
    expect(find.text('1024'), findsNothing);
  });

  testWidgets('tapping outside the popup closes it', (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();
    expect(find.text('65536'), findsOneWidget);

    // Tap on the page below the field, outside the popup's x-range.
    await tester.tapAt(const Offset(400, 600));
    await tester.pump();

    expect(find.text('65536'), findsNothing);
  });

  testWidgets('focus loss closes the popup; other fields have no suggestions',
      (tester) async {
    await pumpPage(tester);

    // Open the popup on the context field.
    await tester.tap(contextField);
    await tester.pump();
    expect(find.text('65536'), findsOneWidget);

    // Tapping another field (model name) moves focus away and closes popup.
    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    expect(find.text('65536'), findsNothing);

    // Other fields never show suggestions.
    for (final value in kExpectedSuggestions) {
      expect(find.text(value), findsNothing, reason: 'suggestion $value');
    }
  });

  testWidgets(
      'editing an existing model: tapping the filled field shows all values',
      (tester) async {
    final model = ModelConfig(
      name: 'test-model',
      modelId: 'test-model',
      typeConfig: {'context': 4096},
    );
    await pumpPage(tester, model: model);

    await tester.tap(contextField);
    await tester.pump();

    // All suggestions offered; '4096' also present in the field text.
    expect(popupValues(tester), kExpectedSuggestions);
    expect(find.text('4096'), findsNWidgets(2));
    expect(find.text('8192'), findsOneWidget);
  });

  testWidgets('re-tapping the field reopens a dismissed popup', (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();
    expect(find.text('65536'), findsOneWidget);

    // Dismiss by tapping outside (focus is retained on the field).
    await tester.tapAt(const Offset(400, 600));
    await tester.pump();
    expect(find.text('65536'), findsNothing);

    // Re-tapping the field must bring the popup back.
    await tester.tap(contextField);
    await tester.pump();
    expect(popupValues(tester), kExpectedSuggestions);
    expect(find.text('65536'), findsOneWidget);
  });

  testWidgets(
      'field keeps focus after selecting a suggestion, so typing '
      'continues to work', (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();
    await tester.tap(find.text('65536'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(contextField);
    expect(field.focusNode?.hasFocus, isTrue);
    expect(field.controller?.text, '65536');

    // The user can keep typing after selecting.
    await tester.enterText(contextField, '6553600');
    await tester.pump();
    expect(field.controller?.text, '6553600');
  });

  testWidgets('popup flips above the field when there is no room below',
      (tester) async {
    // Default 800x600 test surface — the field sits low enough that 280px
    // of popup would not fit below it.
    await tester.pumpWidget(const MaterialApp(home: LlmModelConfigPage()));
    await tester.pump();

    await tester.tap(contextField);
    await tester.pump();

    expect(popupValues(tester), kExpectedSuggestions);
    expect(
      tester.getRect(popupList).bottom,
      lessThanOrEqualTo(tester.getRect(contextField).top),
    );
  });

  testWidgets('popup re-flips above when the keyboard rises', (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();
    // Plenty of room on the tall surface: popup opens below the field.
    expect(
      tester.getRect(popupList).top,
      greaterThanOrEqualTo(tester.getRect(contextField).bottom),
    );

    // Simulate the IME appearing: the view inset shrinks the usable
    // height (1400 - 800 = 600, less than field bottom 401 + 280), so the
    // open popup must flip above the field. The field stays visible.
    tester.view.viewInsets = const FakeViewPadding(bottom: 800);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(
      tester.getRect(popupList).bottom,
      lessThanOrEqualTo(tester.getRect(contextField).top),
    );
  });

  testWidgets('flip measurement converts physical viewInsets (DPR != 1)',
      (tester) async {
    // Logical 800x1400 at DPR 2 (physical 1600x2800).
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LlmModelConfigPage()));
    await tester.pump();

    await tester.tap(contextField);
    await tester.pump();
    // Plenty of room: popup below the field.
    expect(
      tester.getRect(popupList).top,
      greaterThanOrEqualTo(tester.getRect(contextField).bottom),
    );

    // Keyboard 1000 physical px = 500 logical: usable height 900, still
    // enough room -> must stay below. (Missing the DPR division would give
    // usable height 400 and wrongly flip above.)
    tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(
      tester.getRect(popupList).top,
      greaterThanOrEqualTo(tester.getRect(contextField).bottom),
    );

    // Keyboard 1800 physical px = 900 logical: usable height 500 ->
    // not enough room below, popup flips above.
    tester.view.viewInsets = const FakeViewPadding(bottom: 1800);
    await tester.pump();
    expect(
      tester.getRect(popupList).bottom,
      lessThanOrEqualTo(tester.getRect(contextField).top),
    );
  });

  testWidgets('disposing the page while the popup is open does not throw',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(contextField);
    await tester.pump();
    expect(find.text('65536'), findsOneWidget);

    // Tear the page down with the overlay still inserted.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(find.byType(Overlay), findsNothing);
  });
}
