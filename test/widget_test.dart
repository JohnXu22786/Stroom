import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stroom/application.dart';
import 'package:stroom/pages/home_page.dart';

void main() {
  testWidgets('Application widget builds successfully', (WidgetTester tester) async {
    // Build our app with ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: Application(),
      ),
    );

    // Verify that the MaterialApp is created
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify that the HomePage is loaded
    expect(find.byType(HomePage), findsOneWidget);

    // Give some time for the widget tree to settle
    await tester.pumpAndSettle();
  });

  testWidgets('Application has correct title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Application(),
      ),
    );

    // Check if the app title is set correctly
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Stroom');
  });

  testWidgets('Application uses Material 3', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Application(),
      ),
    );

    await tester.pumpAndSettle();

    // Check that MaterialApp is using Material 3
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, true);
    expect(materialApp.darkTheme?.useMaterial3, true);
  });
}
