import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('French editor tools fit a narrow phone and keep full labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr', 'FR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ExtendedImageEditorPage(
          imageBytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC',
          ),
          fileName: 'fixture.png',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final toolLabels = tester
        .widgetList<ConstrainedText>(find.byType(ConstrainedText))
        .skip(2)
        .toList();
    expect(toolLabels.map((label) => label.data), [
      'Pivoter vers la gauche',
      'Pivoter vers la droite',
      'Retourner',
      'Recadrer',
    ]);

    final toolLabelFinder = find.byType(ConstrainedText).evaluate().skip(2);
    for (final label in toolLabelFinder) {
      final rect = tester.getRect(find.byWidget(label.widget));
      expect(rect.width, lessThanOrEqualTo(80));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    expect(find.byIcon(Icons.rotate_left), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    expect(find.byIcon(Icons.flip), findsOneWidget);
    expect(find.byIcon(Icons.crop), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
