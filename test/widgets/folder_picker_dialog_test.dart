import 'dart:async';

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

      // Tap on "work" folder (selection is immediate with manual timer-based detection)
      await tester.tap(find.text('work'));
      // Use a short pump to flush any pending microtasks
      await tester.pump(const Duration(milliseconds: 50));
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

    testWidgets('input row is hidden by default, create button shown instead',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {'photos'},
              onCreateFolder: (name) async => null,
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // No input row by default — only the trigger button
      expect(
        find.byKey(const Key('folder_picker_start_create_btn')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Tapping the button reveals the input row (TextField + plus + X)
      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(
        find.byKey(const Key('folder_picker_cancel_create_btn')),
        findsOneWidget,
      );
      // Trigger button is replaced while editing
      expect(
        find.byKey(const Key('folder_picker_start_create_btn')),
        findsNothing,
      );
    });

    testWidgets('X button abandons creation and clears the input',
        (tester) async {
      final createdNames = <String>[];
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: {'photos'},
              onCreateFolder: (name) async {
                createdNames.add(name);
                return null;
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Start creating, type a name, then abandon with X
      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'cancel_me');
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('folder_picker_cancel_create_btn')));
      await tester.pumpAndSettle();

      // Back to the trigger button, input hidden, nothing was created
      expect(
        find.byKey(const Key('folder_picker_start_create_btn')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(createdNames, isEmpty);

      // Reopening the input starts from a clean empty field
      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('buttons are disabled while a folder creation is in flight',
        (tester) async {
      final completer = Completer<String?>();
      final folders = <String>{'photos'};
      await tester.pumpWidget(_buildTestApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => FolderPickerDialog.show(
              context,
              availableFolders: folders,
              onCreateFolder: (name) => completer.future,
              onRefreshFolders: () async {
                folders.addAll({'photos', 'new_folder'});
                return Set.from(folders);
              },
            ),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Reveal the input row and submit a name
      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'new_folder');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // In-flight: plus, X and 确定 must all be disabled
      final plusButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('folder_picker_create_confirm_btn')),
      );
      expect(plusButton.onPressed, isNull);
      final cancelCreateButton = tester.widget<IconButton>(find.byKey(
        const Key('folder_picker_cancel_create_btn'),
      ));
      expect(cancelCreateButton.onPressed, isNull);
      final confirmButton = tester.widget<FilledButton>(find.ancestor(
        of: find.text('确定'),
        matching: find.byType(FilledButton),
      ));
      expect(confirmButton.onPressed, isNull);
      final cancelButton = tester.widget<TextButton>(find.ancestor(
        of: find.text('取消'),
        matching: find.byType(TextButton),
      ));
      expect(cancelButton.onPressed, isNull);

      // Complete the creation: everything re-enables and input clears
      completer.complete(null);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(
              const Key('folder_picker_create_confirm_btn'),
            ))
            .onPressed,
        isNotNull,
      );
      expect(find.text('new_folder'), findsOneWidget); // 创建成功并出现在列表中
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

      // Reveal the input row via the create button
      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pumpAndSettle();

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

    testWidgets(
        'creating a folder inside a subfolder uses the full path and returns it',
        (tester) async {
      final createdPaths = <String>[];
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
                },
                onCreateFolder: (name) async {
                  createdPaths.add(name);
                  return null;
                },
                onRefreshFolders: () async {
                  return {'photos', 'photos/vacation', 'photos/new_folder'};
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

      // Create a new folder while inside 'photos'
      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'new_folder');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // The folder must be created at the full path, not at the root level
      expect(createdPaths, ['photos/new_folder']);

      // Confirm — the dialog must return the full path as the selection
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(result, 'photos/new_folder');
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

      // Without onCreateFolder the dialog must not advertise creation
      expect(
        find.byKey(const Key('folder_picker_start_create_btn')),
        findsNothing,
      );

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

      // Select 'work' (single tap) - selection is immediate
      await tester.tap(find.text('work'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(result, 'photos/work');
    });

    testWidgets(
        'double-tap navigating into folder also selects it (no prior selection)',
        (tester) async {
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
                  'photos/vacation/beach',
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

      // Now double tap on 'vacation' to navigate into it
      await tester.tap(find.text('vacation'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('vacation'));
      await tester.pumpAndSettle();

      // Confirm without any single-tap selection
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // The result should be 'photos/vacation' (navigated into, thus selected)
      expect(result, 'photos/vacation');
    });
  });
}
