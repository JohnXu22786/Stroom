import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';

void main() {
  testWidgets('shared menu themes use the rounded themed surface', (
    tester,
  ) async {
    const scheme = ColorScheme.light();
    late MenuStyle dropdownStyle;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Builder(
          builder: (context) {
            dropdownStyle = StroomMenuStyle.dropdownMenu(scheme);
            expect(
                StroomMenuStyle.surface(context), scheme.surfaceContainerHigh);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final popupTheme = StroomMenuStyle.popupMenu(scheme);
    final popupShape = popupTheme.shape! as RoundedRectangleBorder;
    final dropdownShape =
        dropdownStyle.shape!.resolve({})! as RoundedRectangleBorder;

    expect(popupTheme.color, scheme.surfaceContainerHigh);
    expect(popupShape.borderRadius, StroomMenuStyle.borderRadius);
    expect(dropdownShape.borderRadius, StroomMenuStyle.borderRadius);
  });
}
