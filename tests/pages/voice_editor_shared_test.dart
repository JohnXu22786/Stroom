import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/voice_editor_shared.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  testWidgets('updating a duplicate keeps the replacement voice', (
    tester,
  ) async {
    List<VoiceEntry>? resolved;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<List<VoiceEntry>>(
                  context: context,
                  builder: (dialogContext) => DuplicateResolveDialog(
                    working: [
                      VoiceEntry(name: 'Original', id: 'shared-id'),
                      VoiceEntry(name: 'Replacement', id: 'shared-id'),
                    ],
                    idToFirstIdx: const {'shared-id': 0},
                    pending: [1],
                    onComplete: (result) {
                      resolved = result;
                      Navigator.pop(dialogContext, result);
                    },
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Update'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(resolved, hasLength(1));
    expect(resolved!.single.name, 'Replacement');
    expect(resolved!.single.id, 'shared-id');
  });
}
