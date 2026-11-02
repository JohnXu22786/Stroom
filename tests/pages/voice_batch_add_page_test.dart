import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/voice_batch_add_page.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';

void main() {
  testWidgets('separator dropdown uses the shared rounded surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VoiceBatchAddPage(existingVoices: [])),
    );

    final dropdownFinder = find.byType(DropdownButton<String>);
    final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
    final colors = Theme.of(tester.element(dropdownFinder)).colorScheme;

    expect(dropdown.dropdownColor, colors.surfaceContainerHigh);
    expect(dropdown.borderRadius, StroomMenuStyle.borderRadius);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    expect(find.text('逗号 (,)'), findsOneWidget);

    await tester.tap(find.text('逗号 (,)'));
    await tester.pumpAndSettle();
    expect(find.text('逗号 (,)'), findsOneWidget);
  });
}
