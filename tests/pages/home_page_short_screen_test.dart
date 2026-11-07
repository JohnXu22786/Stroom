import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/home_shared.dart';
import 'package:stroom/pages/home_page.dart';

void main() {
  test('short media durations use the selected locale unit labels', () async {
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final chinese =
        await AppLocalizations.delegate.load(const Locale('zh', 'CN'));

    expect(formatDurationShort('00:00:09.999', english), '9 sec');
    expect(formatDurationShort('00:03:05.000', english), '3 min 5 sec');
    expect(formatDurationShort('01:02:03.000', english), '1 hr 2 min 3 sec');
    expect(formatDurationShort('not-a-duration', english), 'not-a-duration');
    expect(formatDurationShort('00:xx:03', english), '00:xx:03');
    expect(formatDurationShort('00:00:03.xyz', english), '00:00:03.xyz');
    expect(formatDurationShort('00:-1:03', english), '00:-1:03');
    expect(formatDurationShort('00:00:-3', english), '00:00:-3');

    expect(formatDurationShort('00:00:09.999', chinese), '9秒');
    expect(formatDurationShort('00:03:05.000', chinese), '3分5秒');
    expect(formatDurationShort('01:02:03.000', chinese), '1时2分3秒');
    expect(formatDurationShort('not-a-duration', chinese), 'not-a-duration');
    expect(formatDurationShort('00:xx:03', chinese), '00:xx:03');
    expect(formatDurationShort('00:00:03.xyz', chinese), '00:00:03.xyz');
    expect(formatDurationShort('00:-1:03', chinese), '00:-1:03');
    expect(formatDurationShort('00:00:-3', chinese), '00:00:-3');
  });

  testWidgets(
      'dragging on the module grid scrolls the page '
      '(no scroll dead-zone)', (tester) async {
    // 375x667: the body viewport (below the 80px NavigationBar) shows the
    // grid's first rows, so a drag starting on a card must scroll the page.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drag upward from a point inside the module grid (starts ≈312px;
    // the body viewport bottom is ≈587px on this size).
    await tester.dragFrom(const Offset(50, 500), const Offset(0, -120));
    await tester.pumpAndSettle();

    // The page (SingleChildScrollView) must have scrolled.
    final scrollable = find.byType(SingleChildScrollView).first;
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: scrollable,
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.pixels, greaterThan(0),
        reason: 'drag on the grid must scroll the page, not dead-zone');
  });
}
