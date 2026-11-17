import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/widgets/io_type_indicator.dart';

void main() {
  testWidgets(
    'shows concise labels and keeps explicit input/output semantics',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IOTypeIndicator(type: IOType.video, isInput: true),
                Icon(Icons.arrow_forward),
                IOTypeIndicator(type: IOType.audio, isInput: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Input: Video'), findsNothing);
      expect(find.text('Output: Audio'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Input: Video',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Output: Audio',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('media chips and arrow fit phone and wide layouts', (
    tester,
  ) async {
    for (final width in [280.0, 390.0, 700.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width - 32,
                child: const Row(
                  children: [
                    Flexible(
                      child: IOTypeIndicator(type: IOType.video, isInput: true),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 12),
                    SizedBox(width: 6),
                    Flexible(
                      child: IOTypeIndicator(
                        type: IOType.audio,
                        isInput: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Video'), findsOneWidget, reason: 'width $width');
      expect(find.text('Audio'), findsOneWidget, reason: 'width $width');
      expect(tester.takeException(), isNull, reason: 'width $width');
      final input = tester.getRect(find.text('Video'));
      final arrow = tester.getRect(find.byIcon(Icons.arrow_forward));
      final output = tester.getRect(find.text('Audio'));
      expect(
        input.center.dy,
        closeTo(arrow.center.dy, 2),
        reason: 'width $width',
      );
      expect(
        output.center.dy,
        closeTo(arrow.center.dy, 2),
        reason: 'width $width',
      );
      expect(input.right, lessThan(arrow.left), reason: 'width $width');
      expect(arrow.right, lessThan(output.left), reason: 'width $width');
    }
    await tester.binding.setSurfaceSize(null);
  });
}
