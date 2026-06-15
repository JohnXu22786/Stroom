import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';

Widget _buildTestApp(Widget body) {
  return MaterialApp(
    home: Scaffold(body: body),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

void main() {
  group('FolderPickerDialog', () {
    testWidgets('shows root directory option always', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(context),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Root directory should always be shown
      expect(find.text('根目录'), findsOneWidget);
    });

    testWidgets('shows existing folders when availableFolders provided',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {'photos', 'documents', 'music'},
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show "现有文件夹" section header
      expect(find.text('现有文件夹'), findsOneWidget);

      // Should show all folders
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('documents'), findsOneWidget);
      expect(find.text('music'), findsOneWidget);
    });

    testWidgets('does not show empty string folder in existing folders list',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {''}, // Only empty string (root)
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should NOT show "现有文件夹" section when only empty string
      expect(find.text('现有文件夹'), findsNothing);

      // Root directory is still shown
      expect(find.text('根目录'), findsOneWidget);
    });

    testWidgets('allows selecting a folder and returns it', (tester) async {
      String? result;
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await FolderPickerDialog.show(
                context,
                availableFolders: {'work'},
              );
            },
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap on "work" folder
      await tester.tap(find.text('work'));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(result, 'work');
    });

    testWidgets('allows creating a new folder', (tester) async {
      String? created;
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {'photos'},
              onCreateFolder: (name) async {
                created = name;
                return null;
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter folder name
      await tester.enterText(find.byType(TextField), 'new_folder');
      await tester.pumpAndSettle();

      // Tap add/create button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(created, 'new_folder');
    });
  });
}
