import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/confirm_dialog.dart';

void main() {
  group('ConfirmDialogs', () {
    group('showRetryEditConfirmDialog', () {
      testWidgets('calls onRetry when 重试 tapped for assistant message',
          (tester) async {
        bool retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRetryEditConfirmDialog(
                  context: context,
                  isUser: false,
                  newerMessagesExist: false,
                  onEdit: () {},
                  onRetry: () => retried = true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // 「重试」是对话框标题；确认按钮是「确定」。
        expect(find.text('重试'), findsOneWidget);
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(retried, isTrue);
      });

      testWidgets('calls onEdit when确认 tapped for user message',
          (tester) async {
        bool confirmed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRetryEditConfirmDialog(
                  context: context,
                  isUser: true,
                  newerMessagesExist: false,
                  onEdit: () => confirmed = true,
                  onRetry: () {},
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(confirmed, isTrue);
      });
    });

    group('showDeleteConfirmDialog', () {
      testWidgets('calls onDelete when confirm tapped', (tester) async {
        bool deleted = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteConfirmDialog(
                  context: context,
                  onDelete: () => deleted = true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        expect(deleted, isTrue);
      });
    });
  });
}
