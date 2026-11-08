import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/assistant/assistant_schema_info_dialog.dart';

void main() {
  testWidgets('documents exact schema names, ranges, and available tools',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAssistantSchemaInfoDialog(
              context,
              supportedToolNames: {'web_search', 'todowrite'},
            ),
            child: const Text('show schema'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('show schema'));
    await tester.pumpAndSettle();

    expect(find.text('Remote assistant schema'), findsOneWidget);
    expect(find.text('Catalog manifest fields'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('temperature / enableTemperature'),
      260,
    );
    expect(find.textContaining('0–2 / bool'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('maxTokens / enableMaxTokens'),
      260,
    );
    expect(find.text('maxTokens / enableMaxTokens'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('defaultToolNames'), 260);
    expect(find.textContaining('todowrite, web_search'), findsOneWidget);
  });
}
