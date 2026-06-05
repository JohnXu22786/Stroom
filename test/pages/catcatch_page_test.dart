import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/catcatch_page.dart';

void main() {
  group('CatCatchPage - Duration Filter Three Inputs', () {
    testWidgets('Three input fields render for hours, minutes, seconds',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CatCatchPage(),
          ),
        ),
      );

      // Wait for frame
      await tester.pump();

      // Find the three text fields by their decoration labels
      // The hour field's InputDecoration has labelText: '时'
      // The minute field's InputDecoration has labelText: '分'
      // The second field's InputDecoration has labelText: '秒'
      expect(find.byType(TextFormField), findsNWidgets(4)); // URL + 3 duration fields
    });

    testWidgets('Entering values shows hh:mm:ss preview below inputs',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CatCatchPage(),
          ),
        ),
      );

      // Wait for frame
      await tester.pump();

      // Find text fields - URL field is first, then 時/分/秒 fields
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4));

      // The second TextFormField should be the hour field (index 1)
      // Third is minute (index 2), fourth is second (index 3)
      await tester.enterText(textFields.at(1), '1'); // hours
      await tester.enterText(textFields.at(2), '30'); // minutes
      await tester.enterText(textFields.at(3), '15'); // seconds

      // Pump to rebuild with the entered text
      await tester.pump();

      // Check that the preview text shows hh:mm:ss format
      // The preview should be something like 01:30:15
      expect(find.text('01:30:15'), findsOneWidget);
    });

    testWidgets('Hint text is visible below the duration inputs',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CatCatchPage(),
          ),
        ),
      );

      await tester.pump();

      // The hint text about duration filtering should be visible
      expect(
        find.text('按时长筛选视频资源，不匹配的将不会出现在结果列表中'),
        findsOneWidget,
      );
    });

    testWidgets('Empty fields show 00:00:00 preview', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CatCatchPage(),
          ),
        ),
      );

      await tester.pump();

      // With empty fields, preview should show 00:00:00
      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Non-numeric input in hour field handled gracefully',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CatCatchPage(),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextFormField);

      await tester.enterText(textFields.at(1), 'abc');
      await tester.pump();

      expect(find.text('00:00:00'), findsOneWidget);
    });
  });
}
