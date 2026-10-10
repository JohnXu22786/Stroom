import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/message_view/dsh_message_view.dart';
import 'package:stroom/pages/chat/message_view/message_code_fence.dart';

void main() {
  testWidgets('bridge diffs messages and rejects actions from an old session',
      (tester) async {
    final commands = <Map<String, dynamic>>[];
    final events = <Map<String, dynamic>>[];
    late void Function(Map<String, dynamic>) receive;
    ValueNotifier<Map<String, dynamic>?>? bound;
    Widget host(String html, ValueNotifier<Map<String, dynamic>?> notifier,
        void Function(Map<String, dynamic>) callback) {
      receive = callback;
      if (!identical(bound, notifier)) {
        bound = notifier;
        notifier.addListener(() => commands.add(notifier.value!));
      }
      return const SizedBox();
    }

    Future<void> render(String conversation, String text,
            {bool historyLoaded = true, bool hasOlder = false}) =>
        tester.pumpWidget(MaterialApp(
            home: DshMessageView(
                conversationId: conversation,
                messages: [
                  {'id': 'm', 'content': text}
                ],
                theme: const {'dark': false},
                hasOlder: hasOlder,
                historyLoaded: historyLoaded,
                onEvent: events.add,
                hostBuilder: host)));
    await render('a', 'old', historyLoaded: false);
    receive({'type': 'ready'});
    final first = commands.last['session'];
    expect(commands.last['type'], 'snapshot');
    expect(commands.last['historyLoaded'], false);
    await render('a', 'old', hasOlder: true);
    expect(commands.last['type'], 'patch');
    expect(commands.last['messages'], isEmpty);
    expect(commands.last['historyLoaded'], true);
    expect(commands.last['hasOlder'], true);
    await render('a', 'new');
    expect(commands.last['type'], 'patch');
    expect((commands.last['messages'] as List).single['content'], 'new');
    await render('b', 'other');
    final second = commands.last['session'];
    expect(second, isNot(first));
    receive({
      'type': 'action',
      'session': first,
      'messageId': 'm',
      'action': 'delete'
    });
    expect(events.where((e) => e['type'] == 'action'), isEmpty);
    receive({
      'type': 'action',
      'session': second,
      'messageId': 'm',
      'action': 'copy'
    });
    expect(events.last['action'], 'copy');
  });

  test(
      'code actions resolve only valid source ranges and closed matching fences',
      () {
    const text = '前言\n```html\n<h1>标题</h1>\n```\n尾声';
    final end = text.indexOf('\n尾声');
    final fence = messageCodeFence(text, 3, end)!;
    expect(fence.code, '<h1>标题</h1>');
    expect(fence.language, 'html');
    expect(fence.complete, isTrue);
    expect(
        messageCodeFence(text, 3, end, streaming: true)!.generating, isFalse);
    const tabClose = '```html\nx\n```\t';
    expect(
        messageCodeFence(tabClose, 0, tabClose.length, streaming: true)!
            .generating,
        isFalse);
    const open = '```HTML\n<h1>tail</h1>';
    expect(messageCodeFence(open, 0, open.length, streaming: true)!.generating,
        isTrue);
    expect(messageCodeFence(open, 0, open.length)!.generating, isFalse);
    expect(messageCodeFence(open, 0, open.length)!.language, 'html');
    expect(messageCodeFence(text, -1, end), isNull);
    expect(messageCodeFence(text, 3, text.length + 1), isNull);
    expect(messageCodeFence(text, 0, end), isNull);
    const quoted = '> ```html\n> <h1>A</h1>\n> ```';
    expect(messageCodeFence(quoted, 2, quoted.length)!.code, '<h1>A</h1>');
    const listed = '- ```js\n  let x=1;\n  ```';
    expect(messageCodeFence(listed, 2, listed.length)!.code, 'let x=1;');
    expect(messageCodeFence('    one\n    two', 0, 15)!.code, 'one\ntwo');
    expect(
        messageCodeFence('~~~mermaid\ngraph TD\n```', 0,
                '~~~mermaid\ngraph TD\n```'.length)!
            .complete,
        isFalse);
  });
}
