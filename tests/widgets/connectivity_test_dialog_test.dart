import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/connectivity_test_dialog.dart';
import 'package:stroom/services/connectivity_test_service.dart';

void main() {
  testWidgets('disables test content editing while saving or running',
      (tester) async {
    final saveCompleter = Completer<void>();
    final runCompleter = Completer<ConnectivityTestResult>();
    var saveAttempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => ConnectivityTestDialog(
                    title: 'Test',
                    initialContent: '{}',
                    note: 'Test connectivity content.',
                    onSave: (_) {
                      saveAttempts++;
                      if (saveAttempts == 1) return saveCompleter.future;
                      return Future<void>.error(StateError('storage error'));
                    },
                    onRun: (_) => runCompleter.future,
                  ),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final contentField = find.byType(TextField);
    expect(tester.widget<TextField>(contentField).enabled, isTrue);

    await tester.tap(find.text('保存内容'));
    await tester.pump();
    expect(tester.widget<TextField>(contentField).enabled, isFalse);

    saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(contentField).enabled, isTrue);
    expect(find.text('测试内容已保存'), findsOneWidget);

    await tester.tap(find.text('保存内容'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('测试内容已保存'), findsNothing);

    await tester.tap(find.text('运行测试'));
    await tester.pump();
    expect(tester.widget<TextField>(contentField).enabled, isFalse);

    runCompleter.complete(
      const ConnectivityTestResult(
        succeeded: true,
        summary: 'Test succeeded',
        details: 'Test details',
        elapsed: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(contentField).enabled, isTrue);
  });
}
