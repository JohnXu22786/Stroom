import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';

ChatMessage _message({
  required String id,
  required String role,
  required String content,
}) {
  return ChatMessage(id: id, role: role, content: content);
}

void main() {
  group('ChatPage streaming re-entry history merge', () {
    test('keeps a newly sent user message missing from persisted history', () {
      final persisted = [
        _message(id: 'u1', role: 'user', content: 'first'),
        _message(id: 'a1', role: 'assistant', content: 'partial answer'),
      ];
      final live = [
        ...persisted,
        _message(id: 'u2', role: 'user', content: 'second'),
      ];

      final merged = mergeStreamingHistory(persisted, live);

      expect(merged.map((message) => message.id), ['u1', 'a1', 'u2']);
      expect(merged.last.content, 'second');
    });

    test('prefers the live assistant snapshot over an older persisted copy',
        () {
      final persisted = [
        _message(id: 'u1', role: 'user', content: 'first'),
        _message(id: 'a1', role: 'assistant', content: 'old partial'),
      ];
      final live = [
        _message(id: 'u1', role: 'user', content: 'first'),
        _message(id: 'a1', role: 'assistant', content: 'latest answer'),
      ];

      final merged = mergeStreamingHistory(persisted, live);

      expect(merged.map((message) => message.id), ['u1', 'a1']);
      expect(merged.last.content, 'latest answer');
    });

    test('handles empty persisted or live history without duplicates', () {
      final live = [
        _message(id: 'u1', role: 'user', content: 'first'),
      ];
      final duplicateLive = [
        ...live,
        _message(id: 'u2', role: 'user', content: 'second'),
        _message(id: 'u2', role: 'user', content: 'second (latest)'),
      ];

      expect(
        mergeStreamingHistory(const [], duplicateLive)
            .map((message) => message.id),
        ['u1', 'u2'],
      );
      expect(
        mergeStreamingHistory(const [], duplicateLive).last.content,
        'second (latest)',
      );
      expect(mergeStreamingHistory(const [], live), equals(live));
      expect(mergeStreamingHistory(live, const []), equals(live));
    });
  });
}
