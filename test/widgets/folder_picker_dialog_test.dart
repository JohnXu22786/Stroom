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
    testWidgets('shows root directory option always at top level',
        (tester) async {
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

      // Root directory should always be shown at top level
      expect(find.text('根目录'), findsOneWidget);
    });

    testWidgets('shows hint text below the title', (tester) async {
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

      // Hint text should be visible with small gray text style
      final hintFinder = find.text('单击选中，双击进入查看子文件夹');
      expect(hintFinder, findsOneWidget);
    });

    testWidgets('shows only root-level folders at top level', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {
                'photos',
                'documents',
                'photos/vacation',
                'photos/work',
                'documents/reports',
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show root-level folders only
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('documents'), findsOneWidget);
      // Sub-folders should NOT be visible at top level
      expect(find.text('vacation'), findsNothing);
      expect(find.text('work'), findsNothing);
      expect(find.text('reports'), findsNothing);
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

      // Root directory is still shown as a separate row
      expect(find.text('根目录'), findsOneWidget);
      // Should NOT show "现有文件夹" section when only empty string
      expect(find.text('现有文件夹'), findsNothing);
    });

    testWidgets('single tap selects a folder', (tester) async {
      String? result;
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await FolderPickerDialog.show(
                context,
                availableFolders: {'work', 'photos'},
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
      // GestureDetector with both onTap and onDoubleTap delays onTap by the
      // double-tap timeout. Pump past it so the callback fires.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(result, 'work');
    });

    testWidgets('double tap navigates into sub-folder', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {
                'photos',
                'photos/vacation',
                'photos/vacation/beach',
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Initially should only see root-level folder 'photos'
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('vacation'), findsNothing);
      expect(find.text('beach'), findsNothing);

      // Double tap on 'photos' to navigate into it.
      // Use two taps with a brief pause (shorter than double-tap timeout).
      await tester.tap(find.text('photos'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('photos'));
      await tester.pumpAndSettle();

      // Now should see 'vacation' (direct child of 'photos')
      expect(find.text('photos'), findsNothing);
      expect(find.text('vacation'), findsOneWidget);
      expect(find.text('beach'), findsNothing);

      // Double tap on 'vacation' to navigate into it
      await tester.tap(find.text('vacation'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('vacation'));
      await tester.pumpAndSettle();

      // Now should see 'beach' (direct child of 'photos/vacation')
      expect(find.text('vacation'), findsNothing);
      expect(find.text('beach'), findsOneWidget);
    });

    testWidgets('back navigation from sub-folder works', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {
                'photos',
                'photos/vacation',
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Double tap on 'photos' to navigate into it
      await tester.tap(find.text('photos'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('photos'));
      await tester.pumpAndSettle();

      // Should see 'vacation'
      expect(find.text('vacation'), findsOneWidget);
      // Should see a back button (Icons.arrow_back)
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should be back at root level, seeing 'photos' again
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('vacation'), findsNothing);
    });

    testWidgets('creating new folder refreshes the folder list',
        (tester) async {
      final initialFolders = <String>{'photos'};

      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: initialFolders,
              onCreateFolder: (name) async {
                initialFolders.add(name);
                return null;
              },
              onRefreshFolders: () async {
                return Set.from(initialFolders);
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should initially show 'photos' only
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('new_folder'), findsNothing);

      // Enter new folder name
      await tester.enterText(find.byType(TextField), 'new_folder');
      await tester.pumpAndSettle();

      // Tap create button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Now 'new_folder' should also be visible in the list
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('new_folder'), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      String? result = 'not_null';
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await FolderPickerDialog.show(
                context,
                availableFolders: {'photos'},
              );
            },
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap cancel button
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('selecting sub-folder after navigation works', (tester) async {
      String? result;
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await FolderPickerDialog.show(
                context,
                availableFolders: {
                  'photos',
                  'photos/vacation',
                  'photos/work',
                },
              );
            },
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Double tap on 'photos' to navigate into it
      await tester.tap(find.text('photos'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('photos'));
      await tester.pumpAndSettle();

      // Select 'work' (single tap) - pump past double-tap timeout
      await tester.tap(find.text('work'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(result, 'photos/work');
    });

    testWidgets(
        'hint text is small gray text below title with no border/background',
        (tester) async {
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

      final hintFinder = find.text('单击选中，双击进入查看子文件夹');
      expect(hintFinder, findsOneWidget);

      // Verify it's a plain Text widget (no border/background container)
      final textWidget = tester.widget<Text>(hintFinder);
      expect(textWidget.style, isNotNull);
      // Font size is exactly 12 (small gray hint)
      expect(textWidget.style!.fontSize, equals(12.0));
      // Color is a gray variant (onSurfaceVariant with reduced alpha)
      expect(textWidget.style!.color, isNotNull);
    });
  });
}
