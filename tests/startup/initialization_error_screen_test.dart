import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/startup_initialization_error_screen.dart';

void main() {
  testWidgets('long initialization diagnostics can scroll to the tail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final details = List.generate(
      80,
      (index) => 'Local synthetic exception diagnostic line $index',
    ).join('\n');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        theme: ThemeData.light(),
        home: StartupInitializationErrorScreen(
          title: 'App startup error',
          details: details,
        ),
      ),
    );

    final detailsFinder = find.text(details);
    expect(detailsFinder, findsOneWidget);
    expect(tester.getRect(detailsFinder).height, greaterThan(640));
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();

    final detailsRect = tester.getRect(detailsFinder);
    expect(detailsRect.top, lessThan(0));
    expect(detailsRect.bottom, lessThanOrEqualTo(640));
    expect(detailsRect.bottom, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short initialization errors remain vertically centered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('en', 'US'),
        theme: ThemeData.light(),
        home: StartupInitializationErrorScreen(
          title: 'App startup error',
          details: 'Error: Local synthetic exception',
        ),
      ),
    );

    final title = tester.getRect(find.text('App startup error'));
    final details = tester.getRect(
      find.text('Error: Local synthetic exception'),
    );
    expect((title.top + details.bottom) / 2, closeTo(320, 1));
    expect(tester.takeException(), isNull);
  });
}
