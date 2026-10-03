import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart'
    show kTemporaryConversationDuration;

void main() {
  group('temporary countdown fallback persistence', () {
    test('an explicit opt-out clears stale temporary metadata', () {
      final conversationMap = <String, dynamic>{
        'id': 'c1',
        'isTemporary': true,
        'temporaryExpiresAt': '2026-10-03T12:00:00.000',
        'temporaryExpiryVersion': 1,
      };

      final wasTemporary = applyTemporaryCountdownFallback(
        conversationMap,
        wasTemporary: false,
        persistedStateIsAuthoritative: true,
        startedAt: DateTime.parse('2026-10-03T11:30:00.000'),
      );

      expect(wasTemporary, isFalse);
      expect(conversationMap, isNot(contains('isTemporary')));
      expect(conversationMap, isNot(contains('temporaryExpiresAt')));
      expect(conversationMap, isNot(contains('temporaryExpiryVersion')));
    });

    test('a persisted opt-out takes precedence over send-time temporary state',
        () {
      final conversationMap = <String, dynamic>{'id': 'c1'};

      final wasTemporary = applyTemporaryCountdownFallback(
        conversationMap,
        wasTemporary: true,
        persistedStateIsAuthoritative: true,
        startedAt: DateTime.parse('2026-10-03T11:30:00.000'),
      );

      expect(wasTemporary, isFalse);
      expect(conversationMap, isNot(contains('isTemporary')));
      expect(conversationMap, isNot(contains('temporaryExpiresAt')));
      expect(conversationMap, isNot(contains('temporaryExpiryVersion')));
    });

    test('an unknown temporary state still uses persisted state', () {
      final conversationMap = <String, dynamic>{
        'id': 'c1',
        'isTemporary': true,
        'temporaryExpiresAt': '2026-10-03T12:00:00.000',
        'temporaryExpiryVersion': 1,
      };
      final startedAt = DateTime.parse('2026-10-03T11:30:00.000');

      final wasTemporary = applyTemporaryCountdownFallback(
        conversationMap,
        wasTemporary: null,
        persistedStateIsAuthoritative: true,
        startedAt: startedAt,
      );

      final expiresAt = DateTime.parse(
        conversationMap['temporaryExpiresAt'] as String,
      );
      expect(conversationMap['isTemporary'], isTrue);
      expect(wasTemporary, isTrue);
      expect(expiresAt, startedAt.add(kTemporaryConversationDuration));
    });

    test('a current temporary state takes precedence over a stale opt-out', () {
      final conversationMap = <String, dynamic>{'id': 'c1'};
      final startedAt = DateTime.parse('2026-10-03T11:30:00.000');

      final wasTemporary = applyTemporaryCountdownFallback(
        conversationMap,
        wasTemporary: true,
        persistedStateIsAuthoritative: false,
        startedAt: startedAt,
      );

      final expiresAt = DateTime.parse(
        conversationMap['temporaryExpiresAt'] as String,
      );
      expect(conversationMap['isTemporary'], isTrue);
      expect(wasTemporary, isTrue);
      expect(expiresAt, startedAt.add(kTemporaryConversationDuration));
    });

    test('a new temporary conversation uses its captured state', () {
      final conversationMap = <String, dynamic>{'id': 'c1'};
      final startedAt = DateTime.parse('2026-10-03T11:30:00.000');

      final wasTemporary = applyTemporaryCountdownFallback(
        conversationMap,
        wasTemporary: true,
        persistedStateIsAuthoritative: false,
        startedAt: startedAt,
      );

      final expiresAt = DateTime.parse(
        conversationMap['temporaryExpiresAt'] as String,
      );
      expect(conversationMap['isTemporary'], isTrue);
      expect(wasTemporary, isTrue);
      expect(expiresAt, startedAt.add(kTemporaryConversationDuration));
    });
  });
}
