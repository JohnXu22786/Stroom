import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/home_shared.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

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
        child: TickerMode(
          enabled: false,
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
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

  testWidgets('home status dots stay centered and labels wrap when narrow', (
    tester,
  ) async {
    // Keep the existing Recent tasks header within its minimum width while
    // still allowing the German status label to wrap.
    tester.view.physicalSize = const Size(350, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<void> pumpHome(Locale locale) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TickerMode(
            enabled: false,
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const HomePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpHome(const Locale('en'));
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final labels = [
      english.statusInProgress,
      english.statusCompleted,
      english.statusFailed,
    ];
    for (final label in labels) {
      final labelFinder = find.text(label);
      expect(labelFinder, findsOneWidget);
      final itemColumn = find
          .ancestor(
            of: labelFinder,
            matching: find.byType(Column),
          )
          .first;
      final countRect = tester.getRect(
        find.descendant(of: itemColumn, matching: find.text('0')),
      );
      final statusRow = find
          .ancestor(
            of: labelFinder,
            matching: find.byType(Row),
          )
          .first;
      final dot = find.descendant(
        of: statusRow,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(dot, findsOneWidget);
      final groupCenter = tester.getRect(statusRow).center.dx;
      expect(
        groupCenter,
        closeTo(countRect.center.dx, 1),
        reason: 'the dot and $label should be centered together',
      );
    }

    final german = await AppLocalizations.delegate.load(const Locale('de'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 80,
            child: HomeStatusLabel(
              label: german.statusInProgress,
              dotColor: Colors.orange,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final wrappedLabel = find.text(german.statusInProgress);
    expect(wrappedLabel, findsOneWidget);
    final germanRow =
        find.ancestor(of: wrappedLabel, matching: find.byType(Row)).first;
    expect(
      find.descendant(
        of: germanRow,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .renderObject<RenderParagraph>(wrappedLabel)
          .getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: german.statusInProgress.length,
            ),
          )
          .length,
      greaterThan(1),
      reason: 'the German in-progress label should wrap at this width',
    );
  });

  testWidgets('home constrained labels fit at large text scale', (
    tester,
  ) async {
    // Widget tests render the bundled Ahem test font, which assigns every
    // character the same width. At 390px the English pair fits even with that
    // conservative font, proving the action gets its natural width and leaves
    // the remainder available to the heading.
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    Widget home(Locale locale) => ProviderScope(
      child: TickerMode(
        enabled: false,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );

    const englishLocale = Locale('en');
    await tester.pumpWidget(home(englishLocale));
    await tester.pumpAndSettle();
    final english = await AppLocalizations.delegate.load(englishLocale);
    final headerRow = find
        .ancestor(
          of: find.text(english.homeRecentTasks),
          matching: find.byType(Row),
        )
        .first;
    for (final value in [english.homeRecentTasks, english.homeViewAll]) {
      final label = find.text(value);
      expect(label, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      final actionLabel = find.text(english.homeViewAll);
      final action = find
          .ancestor(of: actionLabel, matching: find.byType(InkWell))
          .first;
      final actionParagraph = tester.renderObject<RenderParagraph>(actionLabel);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason:
            'the complete English label "$value" fits at 390px and normal scale; '
            'row=${tester.getSize(headerRow).width}, heading/action slot=${paragraph.size.width}, '
            'heading natural=${paragraph.getMaxIntrinsicWidth(double.infinity)}, '
            'action slot=${tester.getSize(action).width}, '
            'action text natural=${actionParagraph.getMaxIntrinsicWidth(double.infinity)}, '
            'heading scale=${paragraph.textScaler.scale(12)}',
      );
    }

    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpWidget(home(englishLocale));
    await tester.pumpAndSettle();
    final normalCardSize = tester.getSize(find.byType(Card).first);
    expect(
      normalCardSize.height,
      closeTo(normalCardSize.width / 1.2, 1),
      reason: 'normal text scale keeps the original module card proportion',
    );

    const portugueseLocale = Locale('pt', 'BR');
    tester.view.physicalSize = const Size(390, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 1.7;
    await tester.pumpWidget(home(portugueseLocale));
    await tester.pumpAndSettle();
    final portuguese = await AppLocalizations.delegate.load(portugueseLocale);
    for (final value in [portuguese.homeRecentTasks, portuguese.homeViewAll]) {
      final label = find.text(value);
      expect(label, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == value,
        ),
        findsOneWidget,
        reason: 'the Portuguese label remains inside a bounded reveal slot',
      );
    }

    const locale = Locale('de', 'DE');
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pumpWidget(home(locale));
    await tester.pumpAndSettle();
    final largeCardSize = tester.getSize(find.byType(Card).first);
    expect(
      largeCardSize.height,
      greaterThan(normalCardSize.height),
      reason: 'the constrained module card grows when scaled labels need room',
    );

    final labels = await AppLocalizations.delegate.load(locale);
    final heading = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == labels.homeRecentTasks,
    );
    final constrainedViewAll = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == labels.homeViewAll,
    );
    final viewAll = find.text(labels.homeViewAll);
    expect(heading, findsOneWidget);
    expect(constrainedViewAll, findsOneWidget);
    expect(viewAll, findsOneWidget);

    final headingRow = find
        .ancestor(of: heading, matching: find.byType(Row))
        .first;
    final action = find
        .ancestor(of: viewAll, matching: find.byType(InkWell))
        .first;
    final headingRect = tester.getRect(heading);
    final actionRect = tester.getRect(action);
    expect(
      headingRect.right,
      lessThanOrEqualTo(actionRect.left),
      reason: 'the clipped heading must stay inside the action row slot',
    );
    expect(
      headingRect.center.dy,
      closeTo(actionRect.center.dy, 1),
      reason: 'the view-all action remains aligned with the one-line heading',
    );
    expect(tester.getRect(headingRow).right, lessThanOrEqualTo(320));

    for (final label in [
      labels.statusInProgress,
      labels.statusCompleted,
      labels.statusFailed,
    ]) {
      final statusLabel = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == label,
      );
      expect(statusLabel, findsOneWidget);
      final statusRow = find
          .ancestor(of: statusLabel, matching: find.byType(Row))
          .first;
      final statusColumn = find
          .ancestor(of: statusLabel, matching: find.byType(Column))
          .first;
      final count = tester.getRect(
        find.descendant(of: statusColumn, matching: find.text('0')),
      );
      final dot = find.descendant(
        of: statusRow,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(dot, findsOneWidget);
      expect(
        tester.getRect(statusRow).center.dx,
        closeTo(count.center.dx, 1),
        reason: 'the dot and $label stay centered below the count at 2× scale',
      );
      expect(tester.getSize(dot), const Size(8, 8));
    }

    const arabicLocale = Locale('ar');
    await tester.pumpWidget(home(arabicLocale));
    await tester.pumpAndSettle();
    final arabic = await AppLocalizations.delegate.load(arabicLocale);
    final arabicHeading = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == arabic.homeRecentTasks,
    );
    final arabicActionLabel = find.text(arabic.homeViewAll);
    final arabicHeaderRow = find
        .ancestor(of: arabicHeading, matching: find.byType(Row))
        .first;
    final arabicAction = find
        .ancestor(of: arabicActionLabel, matching: find.byType(InkWell))
        .first;
    expect(
      tester.getRect(arabicAction).left,
      closeTo(tester.getRect(arabicHeaderRow).left, 1),
      reason: 'the action stays on the trailing edge in right-to-left layout',
    );
    expect(
      tester
          .widget<ConstrainedText>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ConstrainedText &&
                  widget.data == arabic.homeViewAll,
            ),
          )
          .marqueeTextAlign,
      TextAlign.end,
    );

    final layoutException = tester.takeException();
    expect(
      layoutException,
      isNull,
      reason:
          'scaled home labels must fit their cards without RenderFlex overflow',
    );
  });
}
