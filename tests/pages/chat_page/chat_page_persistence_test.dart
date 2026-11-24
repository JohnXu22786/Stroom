import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart'
    show
        ConversationsNotifier,
        conversationsProvider,
        kTemporaryConversationDuration;

void main() {
  group('chat fallback conversation preservation', () {
    test('Tier B replaces corrupt data only after a backup exists', () async {
      const corruptJson = '{"broken":';
      SharedPreferences.setMockInitialValues({'conversations': corruptJson});
      final prefs = await SharedPreferences.getInstance();

      final savedWithoutBackup = await persistConversationFallbackIfRecovered(
        prefs,
        '[]',
      );

      expect(savedWithoutBackup, isFalse);
      expect(prefs.getString('conversations'), corruptJson);

      await prefs.setString('conversations.corrupt.1', corruptJson);
      final savedWithBackup = await persistConversationFallbackIfRecovered(
        prefs,
        '[]',
      );

      expect(savedWithBackup, isTrue);
      expect(prefs.getString('conversations'), '[]');
    });

    test('backup cleanup keeps a concurrent Tier B canonical save', () async {
      const corruptJson = '{"broken":';
      const recoveredJson = '[{"id":"recovered"}]';
      SharedPreferences.setMockInitialValues({'conversations': corruptJson});
      final backupStored = Completer<void>();
      final completeBackup = Completer<bool>();
      var backupAttempts = 0;
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(
              ref,
              corruptConversationBackupWriter: (prefs, key, value) async {
                backupAttempts++;
                if (backupAttempts == 1) return false;
                await prefs.setString(key, value);
                backupStored.complete();
                return completeBackup.future;
              },
            );
            notifier.loadForTesting();
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final retry = notifier.persistNowForTesting();
      await backupStored.future;

      final prefs = await SharedPreferences.getInstance();
      final fallbackSaved = await persistConversationFallbackIfRecovered(
        prefs,
        recoveredJson,
      );
      expect(fallbackSaved, isTrue);

      completeBackup.complete(true);
      expect(await retry, isFalse);

      expect(prefs.getString('conversations'), recoveredJson);
      expect(backupAttempts, 2);
    });

    test(
      'preserves legacy records and fields when replacing target messages',
      () {
        final legacyRecord = <String, dynamic>{
          'id': 'legacy',
          'title': 42,
          'createdAt': null,
          'updatedAt': 'not-a-date',
          'lastInputTokens': 3.5,
          'temporaryPausedRemainingMilliseconds': 45,
          'futureField': {'value': 7},
          'messages': [
            'malformed message',
            {
              'id': 'future-message',
              'role': 'assistant',
              'createdAt': null,
              'content': null,
              'attachments': ['malformed attachment'],
              'blocks': [
                {'type': 'future-block', 'payload': 1},
              ],
              'textSections': ['section-only content'],
              'toolCalls': [
                {'status': 'future-status'},
              ],
              'futureMessageField': true,
            },
          ],
        };
        final existingTarget = <String, dynamic>{
          'id': 'target',
          'title': 'Keep me',
          'sortOrder': 1.5,
          'enabledMcpToolNames': ['future-tool'],
          'hasExplicitEnabledMcpTools': false,
          'futureConversationField': 'retained',
          'messages': [
            {
              'id': 'old-message',
              'role': 'assistant',
              'content': 'old',
              'toolCalls': [
                {'status': 'future-status'},
              ],
            },
          ],
        };
        final malformedTopLevel = 'legacy list entry';

        final result = prepareConversationFallbackList(
          [legacyRecord, malformedTopLevel, existingTarget],
          conversationId: 'target',
          targetMap: {
            'id': 'target',
            'updatedAt': 'new-date',
            'messages': [ChatMessage(role: 'user', content: 'new').toMap()],
          },
        );

        expect(result[0], legacyRecord);
        expect(result[1], malformedTopLevel);
        final savedTarget = result[2] as Map;
        expect(savedTarget['title'], 'Keep me');
        expect(savedTarget['sortOrder'], 1.5);
        expect(savedTarget['enabledMcpToolNames'], ['future-tool']);
        expect(savedTarget['futureConversationField'], 'retained');
        expect(savedTarget['messages'].single['content'], 'new');
      },
    );

    test('sanitizes raw diagnostics without normalizing sibling messages', () {
      final rawRequest = <String, dynamic>{
        'url': 'https://example.test/chat',
        'body': {
          'model': 'future-model',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,${'X' * 10000}'},
                },
              ],
            },
          ],
        },
      };
      final sibling = <String, dynamic>{
        'id': 'sibling',
        'title': 42,
        'futureField': {'keep': true},
        'messages': [
          {
            'id': 'message',
            'role': 'assistant',
            'content': null,
            'futureMessageField': 'keep',
            'rawRequest': rawRequest,
            'rawResponse': {'payload': 'data:image/png;base64,${'Y' * 10000}'},
          },
        ],
      };

      final result = prepareConversationFallbackList(
        [sibling],
        conversationId: 'target',
        targetMap: {'id': 'target', 'messages': []},
      );
      final savedSibling = result.firstWhere(
        (item) => item is Map && item['id'] == 'sibling',
      ) as Map;
      final savedMessage = (savedSibling['messages'] as List).first as Map;
      final savedRequest = savedMessage['rawRequest'] as Map;
      final savedResponse = savedMessage['rawResponse'] as Map;

      expect(savedSibling['title'], 42);
      expect(savedSibling['futureField'], {'keep': true});
      expect(savedMessage['futureMessageField'], 'keep');
      expect(savedMessage['content'], isNull);
      expect(savedRequest['body']['model'], 'future-model');
      expect(jsonEncode(savedRequest).length, lessThan(10000));
      expect(jsonEncode(savedResponse).length, lessThan(10000));
    });

    test('retained non-finite legacy values make Tier A encoding fail', () {
      final decoded =
          jsonDecode('[{"id":"legacy","futureNumber":1e999}]') as List<dynamic>;
      expect((decoded.single as Map)['futureNumber'], double.infinity);
      final result = prepareConversationFallbackList(
        decoded,
        conversationId: 'target',
        targetMap: {'id': 'target', 'messages': []},
      );

      expect(
        () => jsonEncode(result),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
  });

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

    test(
      'a persisted opt-out takes precedence over send-time temporary state',
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
      },
    );

    test('an unknown temporary state still uses persisted state', () {
      final conversationMap = <String, dynamic>{
        'id': 'c1',
        'isTemporary': true,
        'temporaryExpiresAt': '2026-10-03T12:00:00.000',
        'temporaryExpiryVersion': 1,
      };
      final startedAt = DateTime.parse('2026-10-03T11:30:00.000');
      final persistedExpiry = DateTime.parse(
        conversationMap['temporaryExpiresAt'] as String,
      );

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
      expect(expiresAt, persistedExpiry);
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
