import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('keeps fitting text in its normal Text widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedText(
                'Short label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Short label'), findsOneWidget);
    expect(tester.getSize(find.byType(ConstrainedText)).width, lessThan(240));
    final start = tester.getTopLeft(find.text('Short label'));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.text('Short label')), start);
  });

  testWidgets('moves clipped labels after the initial delay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: child!,
        ),
        home: const Scaffold(
          body: SizedBox(
            width: 80,
            child: ConstrainedText(
              'A deliberately long value that will scroll',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    final text = find.text('A deliberately long value that will scroll');
    final start = tester.getTopLeft(text);
    await tester.pump(const Duration(milliseconds: 999));
    expect(tester.getTopLeft(text).dx, closeTo(start.dx, 0.01));
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.getTopLeft(text).dx, closeTo(start.dx, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(start.dx - tester.getTopLeft(text).dx, closeTo(6, 1));
  });

  testWidgets('shows the trailing text at the horizontal endpoint', (
    tester,
  ) async {
    const label = 'A deliberately long value that will scroll';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: ConstrainedText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    final constrainedText = find.byType(ConstrainedText);
    final text = find.text(label);
    final context = tester.element(constrainedText);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final slot = tester.getSize(constrainedText).width;
    final travel = Duration(
      milliseconds: ((painter.width - slot) / 24 * 1000).round(),
    );
    final clip = find.ancestor(of: text, matching: find.byType(ClipRect)).first;
    final clipRect = tester.getRect(clip);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(travel);
    await tester.pump(const Duration(milliseconds: 20));
    final endpoint = tester.getRect(text);
    expect(endpoint.width, greaterThan(clipRect.width));
    expect(endpoint.right, closeTo(clipRect.right, 2));
    expect(endpoint.overlaps(clipRect), isTrue);

    await tester.pump(const Duration(milliseconds: 1999));
    expect(tester.getRect(text).left, closeTo(endpoint.left, 0.01));
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(text).left, greaterThan(endpoint.left));
  });

  testWidgets('keeps the final lines visible at the vertical endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: ConstrainedText(
              'Line one has enough text to wrap. Line two has enough text to wrap. Line three has enough text to wrap.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    final constrainedText = find.byType(ConstrainedText);
    final text = find.text(
      'Line one has enough text to wrap. Line two has enough text to wrap. Line three has enough text to wrap.',
    );
    final context = tester.element(constrainedText);
    final fullText = TextPainter(
      text: TextSpan(
        text: (tester.widget<ConstrainedText>(constrainedText)).data,
        style: DefaultTextStyle.of(context).style,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 120);
    final clip = find.ancestor(of: text, matching: find.byType(ClipRect)).first;
    final clipRect = tester.getRect(clip);
    final start = tester.getTopLeft(text);
    expect(fullText.height, greaterThan(clipRect.height));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(text).dy, lessThan(start.dy));
    final travel = Duration(
      milliseconds: ((fullText.height - clipRect.height) / 24 * 1000).round(),
    );
    await tester.pump(travel - const Duration(seconds: 2));

    final endRect = tester.getRect(text);
    expect(endRect.height, greaterThan(clipRect.height));
    expect(endRect.bottom, closeTo(clipRect.bottom, 2));
    expect(endRect.overlaps(clipRect), isTrue);
  });

  testWidgets('keeps clipped text discoverable while it scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: ConstrainedText(
              'A deliberately long value that will scroll',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('A deliberately long value that will scroll'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('A deliberately long value that will scroll'),
      findsOneWidget,
    );
  });

  testWidgets('lays out safely inside dropdown items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: DropdownButton<String>(
              isExpanded: true,
              value: 'format',
              items: [
                DropdownMenuItem(
                  value: 'format',
                  child: ConstrainedText(
                    'A short dropdown label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out safely inside dropdown form fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: 'format',
              items: [
                DropdownMenuItem(
                  value: 'format',
                  child: ConstrainedText(
                    'A short dropdown label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
