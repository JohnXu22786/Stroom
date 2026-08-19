import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/transform_stretch_overscroll.dart';

/// Regression tests for [TransformStretchOverscroll].
///
/// Flutter's default Material 3 stretch overscroll on Android uses an
/// ImageFilter fragment shader, which does NOT affect platform views
/// (e.g. the InAppWebView that renders mermaid diagrams) — the WebView
/// stays rigid while the rest of the content stretches. This wrapper
/// applies the stretch with a plain Transform matrix, which platform
/// views honor, so everything stretches uniformly.
void main() {
  ScrollMetrics buildMetrics({AxisDirection direction = AxisDirection.down}) {
    return FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      pixels: 1000,
      viewportDimension: 500,
      axisDirection: direction,
      devicePixelRatio: 1.0,
    );
  }

  Transform transformUnderTest(WidgetTester tester) {
    return tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(TransformStretchOverscroll),
            matching: find.byType(Transform),
          )
          .first,
    );
  }

  Widget buildWrapper({AxisDirection direction = AxisDirection.down}) {
    return MaterialApp(
      home: Scaffold(
        body: TransformStretchOverscroll(
          axisDirection: direction,
          child: const SizedBox(
            width: 200,
            height: 200,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
  }

  BuildContext contextOf(WidgetTester tester) =>
      // Dispatch from the CHILD's context: scroll notifications bubble UP
      // the tree, so the origin must be below the NotificationListener.
      tester.element(
        find
            .descendant(
              of: find.byType(TransformStretchOverscroll),
              matching: find.byType(ColoredBox),
            )
            .first,
      );

  void dispatchOverscroll(
    WidgetTester tester, {
    required double overscroll,
    required Offset dragDelta,
  }) {
    final ctx = contextOf(tester);
    OverscrollNotification(
      metrics: buildMetrics(),
      context: ctx,
      overscroll: overscroll,
      velocity: 0,
      dragDetails: DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: dragDelta,
      ),
    ).dispatch(ctx);
  }

  testWidgets('no stretch at rest (identity transform)', (tester) async {
    await tester.pumpWidget(buildWrapper());
    final transform = transformUnderTest(tester);
    expect(transform.transform.getMaxScaleOnAxis(), 1.0);
  });

  testWidgets('overscroll at the end stretches the content (scaleY > 1)',
      (tester) async {
    await tester.pumpWidget(buildWrapper());

    dispatchOverscroll(tester,
        overscroll: 100, dragDelta: const Offset(0, -10));
    await tester.pump();

    final transform = transformUnderTest(tester);
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.0),
        reason: 'a transform-based stretch must scale the content, '
            'including platform views (the shader-based default does not)');
  });

  testWidgets('overscroll at the start stretches with the opposite anchor',
      (tester) async {
    await tester.pumpWidget(buildWrapper());

    dispatchOverscroll(tester,
        overscroll: -100, dragDelta: const Offset(0, 10));
    await tester.pump();

    final transform = transformUnderTest(tester);
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.0));
    expect(transform.alignment, Alignment.topCenter,
        reason: 'overscroll at the start must anchor at the top edge');
  });

  testWidgets('stretch releases back to identity after scroll end',
      (tester) async {
    await tester.pumpWidget(buildWrapper());

    dispatchOverscroll(tester,
        overscroll: 100, dragDelta: const Offset(0, -10));
    await tester.pump();
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));

    final ctx = contextOf(tester);
    ScrollEndNotification(
      metrics: buildMetrics(),
      context: ctx,
      dragDetails: DragEndDetails(primaryVelocity: 0),
    ).dispatch(ctx);
    await tester.pumpAndSettle();

    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('ignores notifications from a different axis', (tester) async {
    await tester.pumpWidget(buildWrapper(direction: AxisDirection.down));

    final ctx = contextOf(tester);
    OverscrollNotification(
      metrics: buildMetrics(direction: AxisDirection.right),
      context: ctx,
      overscroll: 100,
      velocity: 0,
      dragDetails: DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: const Offset(0, -10),
      ),
    ).dispatch(ctx);
    await tester.pump();

    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(), 1.0);
  });

  testWidgets('accepts reversed (same-axis) scrollables with sign flips',
      (tester) async {
    // The framework filters on axis (not axisDirection) so reversed lists
    // stretch too, with the direction-dependent sign handled in build().
    await tester.pumpWidget(buildWrapper(direction: AxisDirection.up));

    final ctx = contextOf(tester);
    OverscrollNotification(
      metrics: buildMetrics(direction: AxisDirection.up),
      context: ctx,
      overscroll: -100,
      velocity: 0,
      dragDetails: DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: const Offset(0, 10),
      ),
    ).dispatch(ctx);
    await tester.pump();

    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));
  });

  testWidgets('negative (start-side) stretch springs back, not snaps',
      (tester) async {
    // Regression: the stretch strength is signed; the animation must run
    // through negative values (unbounded controller), otherwise the
    // top-edge stretch snaps to identity in a single frame on release.
    await tester.pumpWidget(buildWrapper());

    dispatchOverscroll(tester,
        overscroll: -100, dragDelta: const Offset(0, 10));
    await tester.pump();
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));

    final ctx = contextOf(tester);
    ScrollEndNotification(
      metrics: buildMetrics(),
      context: ctx,
      dragDetails: DragEndDetails(primaryVelocity: 0),
    ).dispatch(ctx);
    // Mid-flight: the spring must still be stretched, not snapped to 1.
    await tester.pump(const Duration(milliseconds: 30));
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('fling overscroll pulses the stretch and settles back',
      (tester) async {
    await tester.pumpWidget(buildWrapper());

    final ctx = contextOf(tester);
    OverscrollNotification(
      metrics: buildMetrics(),
      context: ctx,
      overscroll: 1,
      velocity: 3000,
    ).dispatch(ctx);
    // Timed pumps so the spring simulation ticks past t=0 (the first
    // tick only initializes the ticker's start time).
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        moreOrLessEquals(1.0, epsilon: 0.001));

    // A second spring on the SAME state must work too (the state uses
    // TickerProviderStateMixin, not SingleTickerProviderStateMixin —
    // a second ticker would throw in debug builds).
    OverscrollNotification(
      metrics: buildMetrics(),
      context: ctx,
      overscroll: 1,
      velocity: 3000,
    ).dispatch(ctx);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('a new drag continues smoothly from the interrupted spring',
      (tester) async {
    // The interrupted-spring value must be preserved so a re-pull does
    // not jump the stretch back to the raw pull distance.
    await tester.pumpWidget(buildWrapper());

    dispatchOverscroll(tester,
        overscroll: 100, dragDelta: const Offset(0, -10));
    await tester.pump();
    final released = transformUnderTest(tester).transform.getMaxScaleOnAxis();
    expect(released, greaterThan(1.0));

    final ctx = contextOf(tester);
    ScrollEndNotification(
      metrics: buildMetrics(),
      context: ctx,
      dragDetails: DragEndDetails(primaryVelocity: 0),
    ).dispatch(ctx);
    await tester.pump(const Duration(milliseconds: 30));

    dispatchOverscroll(tester,
        overscroll: 100, dragDelta: const Offset(0, -10));
    await tester.pump();
    // The stretch must not drop below the interrupted value's scale
    // (raw-pull from zero would be ~1.0032 for 100px/500px; the
    // interrupted value is still in flight).
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThanOrEqualTo(released));
    await tester.pumpAndSettle();
  });

  testWidgets('normal scroll updates reset the stretch without animating',
      (tester) async {
    await tester.pumpWidget(buildWrapper());

    dispatchOverscroll(tester, overscroll: 50, dragDelta: const Offset(0, -5));
    await tester.pump();
    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        greaterThan(1.0));

    final ctx = contextOf(tester);
    ScrollUpdateNotification(
      metrics: buildMetrics(),
      context: ctx,
      scrollDelta: 10,
    ).dispatch(ctx);
    await tester.pumpAndSettle();

    expect(transformUnderTest(tester).transform.getMaxScaleOnAxis(),
        moreOrLessEquals(1.0, epsilon: 0.001));
  });
}
