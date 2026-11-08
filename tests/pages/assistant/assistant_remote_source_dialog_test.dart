import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/assistant/assistant_remote_source_dialog.dart';

void main() {
  testWidgets('shows URL entry, update policy, safety option, and schema info',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                ),
                child: const Text('open remote source'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open remote source'));
    await tester.pumpAndSettle();

    expect(find.text('Connect remote assistants'), findsOneWidget);
    expect(find.text('Automatic updates'), findsOneWidget);
    expect(find.text('Review with the built-in safety agent'), findsOneWidget);
    expect(find.byTooltip('Parameter reference'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));

    await tester.tap(find.byTooltip('Parameter reference'));
    await tester.pumpAndSettle();
    expect(find.text('Remote assistant schema'), findsOneWidget);
    expect(find.text('Catalog manifest fields'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining(
        'stroom-json-v1 / stroom-yaml-v1 / stroom-markdown-yaml-v1',
      ),
      260,
    );
    expect(
      find.textContaining(
        'stroom-json-v1 / stroom-yaml-v1 / stroom-markdown-yaml-v1',
      ),
      findsOneWidget,
    );
  });
}
