import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Widget tests for the reasoning panel completion animation in the
/// dialog's top-right corner:
///
/// When reasoning completes while the panel is open:
///   1. the spinner fades out over 0.5s,
///   2. a checkmark pops in with a jelly (elastic) overshoot over 0.5s,
///   3. it holds at full scale for 1s,
///   4. it pops out with a jelly shrink over 0.5s and the corner empties.
///
/// The dialog itself is private, so the tests drive it through the public
/// [ReasoningSection] button: tap the "思考中" line, then flip the shared
/// streaming providers to simulate completion.
const _convId = 'conv-test-1';
const _spinnerKey = ValueKey('reasoning-corner-spinner');
const _checkKey = ValueKey('reasoning-corner-check');

/// The x-scale of the checkmark's Transform.scale matrix. Read directly
/// from the matrix instead of [Matrix4.getMaxScaleOnAxis], which can never
/// report a value below 1.0 (the z-axis stays 1.0) and would therefore
/// mask a shrunken checkmark.
double _checkScale(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(_checkKey)).transform.storage[0];

/// Pumps the app, seeds the streaming providers, opens the reasoning panel
/// dialog and returns the provider container used to flip stream state.
Future<ProviderContainer> _openPanel(
  WidgetTester tester, {
  required String buttonLabel,
  required bool streaming,
  required bool hasFirstToken,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReasoningSection(
              messageId: 'msg-test-1',
              sections: ReasoningSectionData(
                texts: const ['思考内容'],
                streaming: streaming,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final container =
      ProviderScope.containerOf(tester.element(find.byType(ReasoningSection)));
  container.read(activeConversationIdProvider.notifier).state = _convId;
  container.read(streamingReasoningSectionsProvider(_convId).notifier).state =
      const ['思考内容'];
  container.read(streamingHasFirstTokenProvider(_convId).notifier).state =
      hasFirstToken;
  container.read(isStreamingProvider(_convId).notifier).state = streaming;
  await tester.pump();

  await tester.tap(find.text(buttonLabel));
  await tester.pump();
  // Let the dialog route transition settle before asserting.
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  testWidgets(
      'corner spinner fades out, checkmark pops in with jelly overshoot, '
      'holds, then pops out and disappears', (tester) async {
    final container = await _openPanel(
      tester,
      buttonLabel: '思考中',
      streaming: true,
      hasFirstToken: false,
    );

    // Panel opens with a spinning corner indicator (no checkmark yet).
    expect(find.byKey(_spinnerKey), findsOneWidget);
    expect(find.byKey(_checkKey), findsNothing);

    // Reasoning completes.
    container.read(isStreamingProvider(_convId).notifier).state = false;
    await tester.pump(); // rebuild + post-frame starts the animation
    await tester.pump(); // first ticker tick establishes t=0

    // 250ms in: the spinner is still present but partially faded out,
    // and the checkmark has NOT appeared yet (it only starts after the
    // fade completes at 500ms).
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(_spinnerKey), findsOneWidget);
    final fadingOpacity =
        tester.widget<Opacity>(find.byKey(_spinnerKey)).opacity;
    expect(fadingOpacity, greaterThan(0.0));
    expect(fadingOpacity, lessThan(1.0));
    expect(find.byKey(_checkKey), findsNothing);

    // 600ms in: fade finished (spinner gone within 0.5s) and the
    // checkmark is popping in with an elastic overshoot (scale > 1).
    // Sampled at 600ms where elasticOut peaks at ~1.25 — the 500ms-550ms
    // window is useless because elasticOut(0.1) == 1.0 analytically.
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(_spinnerKey), findsNothing);
    expect(find.byKey(_checkKey), findsOneWidget);
    expect(_checkScale(tester), greaterThan(1.0));

    // 1600ms in: hold phase — checkmark rests at full scale.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(_checkKey), findsOneWidget);
    expect(_checkScale(tester), closeTo(1.0, 0.001));

    // 2300ms in: pop-out is underway — the checkmark is shrinking
    // (jelly exit) but still present.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(_checkKey), findsOneWidget);
    expect(_checkScale(tester), lessThan(1.0));

    // 2550ms in: pop-out finished — corner is empty again.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(_checkKey), findsNothing);
    expect(find.byKey(_spinnerKey), findsNothing);

    // A new stream restarts (next message begins streaming, hasFirstToken
    // resets): spinner comes back.
    container.read(streamingHasFirstTokenProvider(_convId).notifier).state =
        false;
    container.read(isStreamingProvider(_convId).notifier).state = true;
    await tester.pump();
    expect(find.byKey(_spinnerKey), findsOneWidget);
    expect(find.byKey(_checkKey), findsNothing);

    // Completion again replays the pop-in animation.
    container.read(isStreamingProvider(_convId).notifier).state = false;
    await tester.pump();
    await tester.pump(); // first ticker tick establishes t=0
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(_spinnerKey), findsNothing);
    expect(find.byKey(_checkKey), findsOneWidget);

    // Unmount so the button's periodic chevron timer is disposed, then
    // flush the visibility_detector timer that MarkdownWidget (dialog
    // content) schedules when it detaches during unmount.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
      'panel opened after completion shows a static checkmark without '
      'replaying the animation', (tester) async {
    await _openPanel(
      tester,
      buttonLabel: '思考完成',
      streaming: false,
      hasFirstToken: true,
    );

    expect(find.byKey(_spinnerKey), findsNothing);
    expect(find.byKey(_checkKey), findsOneWidget);
    expect(_checkScale(tester), closeTo(1.0, 0.001));

    // No animation is scheduled: the checkmark stays put.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(_checkKey), findsOneWidget);
    expect(_checkScale(tester), closeTo(1.0, 0.001));

    // Unmount and flush the visibility_detector post-detach timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });
}
