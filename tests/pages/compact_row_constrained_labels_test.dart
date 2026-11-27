import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/pages/voice_editor_shared.dart';
import 'package:stroom/providers/assistant_provider.dart';

void _setViewport(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _localizedApp({
  required Locale locale,
  required Widget home,
  bool disableAnimations = false,
  bool useMaterial3 = false,
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: useMaterial3),
      builder: disableAnimations
          ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
          : null,
      home: home,
    );

Widget _voiceDialog({
  required int count,
  Locale locale = const Locale('fr'),
  bool disableAnimations = false,
  bool useMaterial3 = true,
}) =>
    _localizedApp(
      locale: locale,
      disableAnimations: disableAnimations,
      useMaterial3: useMaterial3,
      home: Scaffold(
        body: DuplicateResolveDialog(
          working: [
            for (var i = 0; i < count; i++)
              VoiceEntry(name: 'Voice $i', id: 'duplicate'),
          ],
          idToFirstIdx: const {'duplicate': 0},
          pending: List.generate(count, (i) => i),
          onComplete: (_) {},
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom parameter values remain complete when opened for edit', (
    tester,
  ) async {
    _setViewport(tester, const Size(800, 640), scale: 1.8);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    const name = 'extremely_long_parameter_name_for_layout';
    const value = 'a long custom value to reproduce constrained row text';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantProvider.overrideWith((ref) {
            final notifier = AssistantsNotifier();
            notifier.createAssistant(
              name: 'Layout assistant',
              prompt: 'P1',
              settings: AssistantSettings(
                enableTemperature: true,
                customParameters: [
                  CustomParameter(name: name, type: 'string', value: value),
                ],
              ),
            );
            return notifier;
          }),
        ],
        child: _localizedApp(
          locale: const Locale('de'),
          home: const AssistantSelectionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parameter'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(name));
    await tester.tap(find.text(name));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == name,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == value,
      ),
      findsOneWidget,
    );
  });

  testWidgets('duplicate index keeps its 28dp prefix at normal scale', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 640));
    await tester.pumpWidget(_voiceDialog(count: 1));
    await tester.pumpAndSettle();

    final index = find.text('1.');
    expect(index, findsOneWidget);
    final prefix =
        find.ancestor(of: index, matching: find.byType(ConstrainedBox)).first;
    expect(tester.getSize(prefix).width, closeTo(28, 1));
    expect(find.byType(OverflowBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large duplicate index stays on one line and grows past 28dp', (
    tester,
  ) async {
    _setViewport(tester, const Size(440, 932), scale: 2);
    await tester.pumpWidget(_voiceDialog(count: 1234));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1234.'),
      5000,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 2000,
    );

    final index = find.text('1234.');
    expect(index, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(index);
    final prefix =
        find.ancestor(of: index, matching: find.byType(ConstrainedBox)).first;
    expect(paragraph.maxLines, 1);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.getSize(prefix).width, greaterThan(28));
    expect(tester.getSize(index).height, lessThan(60));
    expect(find.text('Mettre à jour'), findsWidgets);
    expect(find.text('Ignorer'), findsWidgets);
    expect(find.byType(OverflowBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion duplicate title keeps its full semantic value', (
    tester,
  ) async {
    _setViewport(tester, const Size(440, 932), scale: 2);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_voiceDialog(count: 1, disableAnimations: true));
    await tester.pumpAndSettle();

    final title = AppLocalizations.of(tester.element(find.byType(Scaffold)))!
        .voiceDuplicateResolution;
    final titleFinder = find.text(title);
    expect(titleFinder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
    expect(paragraph.maxLines, 1);
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(tester.getSemantics(titleFinder).label, title);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('narrow Arabic duplicate actions stay on the RTL trailing edge', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 932), scale: 2);
    await tester.pumpWidget(
      _voiceDialog(
        count: 1,
        locale: const Locale('ar'),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OverflowBar), findsNothing);
    expect(find.byType(TextButton), findsNWidgets(2));
    final actionButtons = find.byType(TextButton);
    expect(
      tester.getRect(actionButtons.first).top,
      greaterThanOrEqualTo(tester.getRect(find.text('duplicate')).bottom),
    );
    final dialogCenter =
        tester.getCenter(find.byType(DuplicateResolveDialog)).dx;
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    for (final label in [l10n.update, l10n.skip]) {
      final labelFinder = find.text(label);
      expect(labelFinder, findsOneWidget);
      expect(tester.getCenter(labelFinder).dx, lessThan(dialogCenter));
      final paragraph = tester.renderObject<RenderParagraph>(labelFinder);
      final textContext = tester.element(labelFinder);
      final natural = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.rtl,
        textScaler: MediaQuery.textScalerOf(textContext),
        locale: Localizations.localeOf(textContext),
      )..layout(maxWidth: double.infinity);
      expect(paragraph.size.width, greaterThanOrEqualTo(natural.width - 0.01));
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}
