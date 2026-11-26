import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/voice_editor_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpVoiceEditor(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VoiceEditorPage(
          initialVoices: [VoiceEntry(name: '', id: '')],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Spanish input hints reveal within the narrow voice row', (
    tester,
  ) async {
    await pumpVoiceEditor(
      tester,
      locale: const Locale('es', 'ES'),
      size: const Size(320, 640),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('es', 'ES'));
    for (final hint in [l10n.voiceName, l10n.voiceId]) {
      final constrainedHint = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == hint,
      );
      expect(constrainedHint, findsOneWidget);
      final field = find
          .ancestor(
            of: constrainedHint,
            matching: find.byType(TextField),
          )
          .first;
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: constrainedHint, matching: find.byType(RichText)),
      );
      expect(
        paragraph.size.width,
        greaterThan(tester.getSize(constrainedHint).width),
        reason: 'the complete localized hint is wider than its finite slot',
      );
      expect(tester.getSemantics(constrainedHint).label, hint);
    }

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    final row = tester.getRect(find.byKey(const ValueKey('voice_row_0')));
    final dragHandle = tester.getRect(find.byIcon(Icons.drag_indicator));
    final deleteIcon = tester.getRect(find.byIcon(Icons.delete));
    expect(dragHandle.size, const Size(24, 24));
    expect(deleteIcon.size, const Size(24, 24));
    expect(dragHandle.left, closeTo(row.left + 20, 0.5));
    expect(deleteIcon.right, closeTo(row.right - 24, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fitting localized hints stay stationary and fields stay native',
      (
    tester,
  ) async {
    await pumpVoiceEditor(
      tester,
      locale: const Locale('es', 'ES'),
      size: const Size(800, 640),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('es', 'ES'));
    for (final hint in [l10n.voiceName, l10n.voiceId]) {
      final constrainedHint = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == hint,
      );
      expect(constrainedHint, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: constrainedHint, matching: find.byType(RichText)),
      );
      expect(
        paragraph.size.width,
        closeTo(tester.getSize(constrainedHint).width, 0.01),
        reason: 'a fitting hint keeps its natural stationary width',
      );
    }

    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Mi voz');
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text, 'Mi voz');
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
