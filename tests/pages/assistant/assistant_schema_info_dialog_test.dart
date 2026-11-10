import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/assistant/assistant_schema_info_dialog.dart';

void main() {
  testWidgets('documents exact schema names, ranges, and available tools', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );

    await tester.tap(find.text('show schema'));
    await tester.pumpAndSettle();

    expect(find.text('Remote assistant schema'), findsOneWidget);
    expect(find.text('Catalog manifest fields'), findsOneWidget);
    final list = find.byType(ListView);
    await _scrollUntilBuilt(
      tester,
      list,
      find.text('temperature / enableTemperature'),
    );
    expect(find.textContaining('0–2 / bool'), findsOneWidget);
    await _scrollUntilBuilt(
      tester,
      list,
      find.text('maxTokens / enableMaxTokens'),
    );
    expect(find.text('maxTokens / enableMaxTokens'), findsOneWidget);
    await _scrollUntilBuilt(tester, list, find.text('defaultToolNames'));
    expect(find.textContaining('todowrite, web_search'), findsOneWidget);
  });
}

Future<void> _scrollUntilBuilt(
  WidgetTester tester,
  Finder list,
  Finder target,
) async {
  for (var i = 0; i < 24; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(list, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}
