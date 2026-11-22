import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_pt.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

const _longModeLabel =
    'Editar e visualizar diagramas Mermaid com uma descrição muito longa';
const _longCodeFieldLabel =
    'Código-fonte Mermaid para editar e visualizar diagramas detalhados';
const _longCodeLabel =
    'Código-fonte Mermaid e edição do diagrama em modo dividido';
const _captureKey = ValueKey('bounded-mermaid-page');

class _TestPortugueseLocalizations extends AppLocalizationsPt {
  _TestPortugueseLocalizations({required this.longFieldLabel}) : super('pt');

  final bool longFieldLabel;

  @override
  String get mermaidEditorModeSplit => _longModeLabel;

  @override
  String get mermaidEditorCodeLabel =>
      longFieldLabel ? _longCodeFieldLabel : 'Código Mermaid';

  @override
  String get mermaidEditorSplitCodeLabel => _longCodeLabel;
}

class _TestPortugueseDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TestPortugueseDelegate({
    required this.longLabels,
    this.longFieldLabel = false,
  });

  final bool longLabels;
  final bool longFieldLabel;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'pt';

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
        longLabels || longFieldLabel
            ? _TestPortugueseLocalizations(longFieldLabel: longFieldLabel)
            : AppLocalizationsPt(locale.toString()),
      );

  @override
  bool shouldReload(covariant _TestPortugueseDelegate old) =>
      old.longLabels != longLabels || old.longFieldLabel != longFieldLabel;
}

Widget _buildApp({required bool longLabels, bool longFieldLabel = false}) =>
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            _TestPortugueseDelegate(
              longLabels: longLabels,
              longFieldLabel: longFieldLabel,
            ),
            ...AppLocalizations.localizationsDelegates,
          ],
          home: const MermaidChartPage(
            initialCode: 'graph TD\n  A-->B',
            initialShowPreview: false,
          ),
        ),
      ),
    );

void _setNarrowViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  testWidgets(
    'narrow editor mode menu bounds a long translation and keeps selection usable',
    (tester) async {
      _setNarrowViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildApp(longLabels: true));
      await tester.pump();

      await tester.tap(find.byTooltip('Alternar modo de visualização'));
      await tester.pumpAndSettle();

      final longLabel = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == _longModeLabel,
      );
      expect(longLabel, findsOneWidget);
      final label = tester.widget<ConstrainedText>(longLabel);
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(longLabel).width, lessThan(250));
      expect(tester.getSemantics(longLabel).label, _longModeLabel);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(longLabel);
      await tester.pump();
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'graph TD\n  A-->C');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'graph TD\n  A-->C',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fitting mode labels keep their natural width', (tester) async {
    _setNarrowViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_buildApp(longLabels: false));
    await tester.pump();

    await tester.tap(find.byTooltip('Alternar modo de visualização'));
    await tester.pumpAndSettle();

    final editLabel = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Editar',
    );
    expect(editLabel, findsOneWidget);
    final text = tester.widget<ConstrainedText>(editLabel);
    final painter = TextPainter(
      text: TextSpan(
        text: text.data,
        style: DefaultTextStyle.of(tester.element(editLabel))
            .style
            .merge(text.style),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(tester.getSize(editLabel).width, closeTo(painter.width, 1));
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/mermaid_editor_mode_320x640.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('split editor bounds a long code header and remains editable', (
    tester,
  ) async {
    _setNarrowViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_buildApp(longLabels: true));
    await tester.pump();

    await tester.tap(find.byTooltip('Alternar modo de visualização'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == _longModeLabel,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(10, 500));
    await tester.pump(const Duration(milliseconds: 500));

    final codeLabel = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == _longCodeLabel,
    );
    expect(codeLabel, findsOneWidget);
    expect(tester.getSize(codeLabel).width, lessThan(280));
    expect(find.byType(TextField), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/mermaid_split_code_header_320x640.png'),
    );

    await tester.enterText(find.byType(TextField), 'graph TD\n  A-->C');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'graph TD\n  A-->C',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('code editor field bounds its long label and remains editable', (
    tester,
  ) async {
    _setNarrowViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _buildApp(longLabels: false, longFieldLabel: true),
    );
    await tester.pump();

    final field = find.byType(TextField);
    final textField = tester.widget<TextField>(field);
    expect(textField.decoration!.label, isA<ConstrainedText>());
    final label = textField.decoration!.label! as ConstrainedText;
    expect(label.data, _longCodeFieldLabel);
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    final renderedLabel = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText && widget.data == _longCodeFieldLabel,
    );
    expect(renderedLabel, findsOneWidget);
    expect(tester.getSemantics(renderedLabel).label, _longCodeFieldLabel);

    await tester.enterText(field, 'graph TD\n  A-->C');
    await tester.pump();
    expect(textField.controller!.text, 'graph TD\n  A-->C');
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
