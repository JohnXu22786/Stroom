import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/confirm_dialog.dart';

void main() {
  group('ConfirmDialogs', () {
    group('showRetryEditConfirmDialog', () {
      testWidgets('shows edit message dialog for user message', (tester) async {
        bool confirmed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRetryEditConfirmDialog(
                  context: context,
                  isUser: true,
                  newerMessagesExist: true,
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

        expect(find.text('编辑消息'), findsOneWidget);
        expect(find.text('确定'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
      });

      testWidgets('shows retry dialog for assistant message', (tester) async {
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

        expect(find.text('重试'), findsOneWidget);
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
      testWidgets('shows delete confirmation', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteConfirmDialog(
                  context: context,
                  onDelete: () {},
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('删除消息'), findsOneWidget);
        expect(find.text('删除'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
      });

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
