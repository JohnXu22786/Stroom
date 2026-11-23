import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/widgets/batch_rename_dialog.dart';
import 'package:stroom/widgets/batch_rename_rule_editor.dart';
import 'package:stroom/widgets/constrained_text.dart';

import '../utils/batch_rename_test.dart' show bridge, file;

Widget _localizedApp(Widget body, Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: body),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'localized rule field labels reveal only when clipped without changing editing',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        _localizedApp(
          SingleChildScrollView(
            child: BatchRenameRuleEditor(
              rule: const BatchReplaceOp(enabled: true),
              primary: true,
              slotId: 0,
              onChanged: (_) {},
              onValidityChanged: (_) {},
              onDuplicate: () {},
              onRemove: () {},
            ),
          ),
          const Locale('de', 'DE'),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('batch_replace_to_field'));
      final textField = tester.widget<TextField>(field);
      final label = textField.decoration!.label! as ConstrainedText;
      expect(
        label.data,
        AppLocalizations.of(tester.element(field))!.batchRuleReplace,
      );
      expect(
        find.descendant(
          of: find.byWidget(label),
          matching: find.byType(Transform),
        ),
        findsWidgets,
      );

      await tester.tap(field);
      await tester.enterText(field, 'draft value');
      await tester.pump();
      textField.controller!.selection = const TextSelection.collapsed(
        offset: 5,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<TextField>(field).controller!.text, 'draft value');
      expect(
        tester.widget<TextField>(field).controller!.selection,
        const TextSelection.collapsed(offset: 5),
      );
      final editableText = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(editableText).focusNode.hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(800, 640);
      await tester.pumpWidget(
        _localizedApp(
          SingleChildScrollView(
            child: BatchRenameRuleEditor(
              rule: const BatchNumberOp(enabled: true),
              primary: true,
              slotId: 0,
              onChanged: (_) {},
              onValidityChanged: (_) {},
              onDuplicate: () {},
              onRemove: () {},
            ),
          ),
          const Locale('en', 'US'),
        ),
      );
      await tester.pumpAndSettle();
      final fittingField = find.byKey(const Key('batch_num_start_field'));
      final fittingLabel =
          tester.widget<TextField>(fittingField).decoration!.label!;
      expect(fittingLabel, isA<ConstrainedText>());
      expect((fittingLabel as ConstrainedText).data, 'Start');
      expect(
        find.descendant(
          of: find.byWidget(fittingLabel),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preset and manual rename labels are constrained while input remains native',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 900);
      final items = [file('a', 'alpha')];
      await tester.pumpWidget(
        _localizedApp(
          BatchRenameDialog(
            items: items,
            allFiles: items,
            allFolders: const {},
            bridge: bridge,
            initialConfig: const BatchRenameConfig(),
          ),
          const Locale('en', 'US'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Save preset'));
      await tester.pumpAndSettle();
      final presetField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      final preset = tester.widget<TextField>(presetField);
      expect(preset.decoration!.label, isA<ConstrainedText>());
      expect(preset.decoration!.labelText, isNull);
      await tester.enterText(presetField, 'My preset');
      expect(preset.controller!.text, 'My preset');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      final previewList = find.byKey(const Key('batch_rename_preview_list'));
      await tester.drag(previewList, const Offset(0, -500));
      await tester.pumpAndSettle();
      final editButton = find.byKey(const Key('batch_edit_file:a'));
      await tester.ensureVisible(editButton);
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      final manualField = find.byKey(const Key('batch_manual_name'));
      final manual = tester.widget<TextField>(manualField);
      expect(manual.decoration!.label, isA<ConstrainedText>());
      expect(manual.decoration!.labelText, isNull);
      await tester.enterText(manualField, 'edited name');
      expect(manual.controller!.text, 'edited name');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rename preview keeps complete before and after names available while excluding items',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      const oldName =
          'A very long original filename that must be completely readable.txt';
      const newName =
          'A very long replacement filename that must be completely readable.txt';
      final item = file('long', oldName.substring(0, oldName.length - 4));
      await tester.pumpWidget(
        _localizedApp(
          BatchRenameDialog(
            items: [item],
            allFiles: [item],
            allFolders: const {},
            bridge: bridge,
            initialConfig: const BatchRenameConfig(
              rules: [
                BatchReplaceOp(
                  enabled: true,
                  find: 'original',
                  replace: 'replacement',
                ),
              ],
            ),
          ),
          const Locale('en', 'US'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_preview_tab')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('batch_rename_preview_list')),
        const Offset(0, -700),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final previewItem = find.byKey(const Key('batch_rename_preview_0'));
      expect(previewItem, findsOneWidget);
      final oldText = find.descendant(
        of: previewItem,
        matching: find.byKey(const Key('batch_rename_old_name_file:long')),
      );
      final newText = find.descendant(
        of: previewItem,
        matching: find.byKey(const Key('batch_rename_new_name_file:long')),
      );
      expect(tester.widget<Text>(oldText).data, oldName);
      expect(tester.widget<Text>(newText).data, newName);
      expect(tester.widget<Text>(oldText).maxLines, isNull);
      expect(tester.widget<Text>(newText).maxLines, isNull);
      expect(tester.widget(oldText), isA<Text>());
      expect(tester.widget(newText), isA<Text>());

      final checkbox = find.byKey(const Key('batch_include_file:long'));
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      await tester.ensureVisible(checkbox);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(checkbox);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      expect(item.name,
          'A very long original filename that must be completely readable');
    },
  );
}
