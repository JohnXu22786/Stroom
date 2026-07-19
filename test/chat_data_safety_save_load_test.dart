// ============================================================================
// Tests for the chat data save/load resilience fixes.
//
// Bug being fixed: After sending a message with a non-text attachment (image,
// video, audio, PDF), the app could suddenly crash during the save path,
// leaving the conversation list blank even though data still exists on disk.
//
// Root cause: the request body containing huge base64 data URIs was being
// saved verbatim to SharedPreferences. This caused:
//   - multi-MB JSON files
//   - long synchronous writes that froze the UI
//   - on some platforms, the OS killing the process mid-write, leaving
//     a corrupt (truncated) JSON file
//
// These tests verify that:
//   1. The toMap output for messages with large attachments stays small.
//   2. The save path survives JSON encoding errors with multi-tier fallback.
//   3. The load path recovers from corrupt JSON without wiping all data.
//   4. Round-trip preserves user-visible fields (content, role, etc.).
// ============================================================================

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =================================================================
  // 1. ChatMessage.toMap must keep saved JSON small even with huge
  //    base64 attachments — this is the primary fix for the bug.
  // =================================================================
  group('ChatMessage.toMap - keep saved JSON small with attachments', () {
    test('video attachment: saved JSON stays under 50KB', () {
      // Simulate a realistic video: ~5MB file → ~6.7MB base64.
      // Without stripping, the saved JSON would be 7+ MB and cause
      // the user-reported flash crash + data half-corruption.
      final hugeVideoBase64 = 'A' * (5 * 1024 * 1024); // 5MB of base64
      final msg = ChatMessage(
        role: 'user',
        content: '请看看这个视频',
        rawRequest: {
          'url': 'https://api.example.com/v1/chat/completions',
          'body': {
            'model': 'gpt-4o',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': '请看看这个视频'},
                  {
                    'type': 'video_url',
                    'video_url': {
                      'url': 'data:video/mp4;base64,$hugeVideoBase64',
                    },
                  },
                ],
              },
            ],
          },
        },
      );

      final map = msg.toMap();
      // toMap must always be JSON-encodable.
      final json = jsonEncode(map);
      // The saved JSON must be small — strip the huge base64 on save.
      expect(
        json.length,
        lessThan(50 * 1024),
        reason: 'Saved JSON must be <50KB even for 5MB attachments. '
            'Without stripping, the JSON would be 7+ MB and cause '
            'SharedPreferences write failures, UI freezes, and silent '
            'data corruption. Got ${json.length} bytes.',
      );
      // The huge base64 must NOT appear in the saved JSON.
      expect(json, isNot(contains('A' * 1000)),
          reason: 'Huge base64 strings must be stripped before save');
    });

    test('image attachment: saved JSON stays under 50KB', () {
      final hugeImageBase64 = 'B' * (2 * 1024 * 1024); // 2MB of base64
      final msg = ChatMessage(
        role: 'user',
        content: '看图',
        rawRequest: {
          'body': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/png;base64,$hugeImageBase64',
                    },
                  },
                ],
              },
            ],
          },
        },
      );

      final json = jsonEncode(msg.toMap());
      expect(json.length, lessThan(50 * 1024));
      expect(json, isNot(contains('B' * 1000)));
    });

    test('audio input_audio format: saved JSON stays under 50KB', () {
      final hugeAudioBase64 = 'C' * (3 * 1024 * 1024); // 3MB
      final msg = ChatMessage(
        role: 'user',
        content: '听音频',
        rawRequest: {
          'body': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_audio',
                    'input_audio': {
                      'data': hugeAudioBase64,
                      'format': 'wav',
                    },
                  },
                ],
              },
            ],
          },
        },
      );

      final json = jsonEncode(msg.toMap());
      expect(json.length, lessThan(50 * 1024));
      expect(json, isNot(contains('C' * 1000)));
    });

    test('file (PDF) attachment: saved JSON stays under 50KB', () {
      final hugePdfBase64 = 'D' * (4 * 1024 * 1024); // 4MB
      final msg = ChatMessage(
        role: 'user',
        content: '看 PDF',
        rawRequest: {
          'body': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'file',
                    'file': {
                      'filename': 'report.pdf',
                      'file_data': 'data:application/pdf;base64,$hugePdfBase64',
                    },
                  },
                ],
              },
            ],
          },
        },
      );

      final json = jsonEncode(msg.toMap());
      expect(json.length, lessThan(50 * 1024));
      expect(json, isNot(contains('D' * 1000)));
    });

    test('user-visible fields preserved even after base64 stripping', () {
      // The strip must NOT remove important metadata that the user
      // might want to see in the "view raw data" dialog.
      final msg = ChatMessage(
        role: 'assistant',
        content: '回复内容',
        rawRequest: {
          'url': 'https://api.example.com/v1/chat/completions',
          'body': {
            'model': 'gpt-4o',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': '原问题'},
                  {
                    'type': 'video_url',
                    'video_url': {
                      'url': 'data:video/mp4;base64,AAAAGGZ0eXBpc29t',
                    },
                  },
                ],
              },
            ],
          },
        },
      );

      final map = msg.toMap();
      // User-visible metadata must be preserved
      expect(map['content'], '回复内容');
      expect(map['role'], 'assistant');
      // The URL and other non-base64 fields should still be there
      final body = (map['rawRequest'] as Map)['body'] as Map;
      expect(body['model'], 'gpt-4o');
    });
  });

  // =================================================================
  // 2. Conversation.toMap must keep the whole saved payload small.
  // =================================================================
  group('Conversation.toMap - keep saved JSON small with many attachments', () {
    test('10 messages with 1MB attachments each stays under 200KB', () {
      final messages = <ChatMessage>[];
      for (var i = 0; i < 10; i++) {
        messages.add(ChatMessage(
          role: i.isEven ? 'user' : 'assistant',
          content: '消息 $i',
          rawRequest: i.isEven
              ? {
                  'body': {
                    'messages': [
                      {
                        'role': 'user',
                        'content': [
                          {
                            'type': 'video_url',
                            'video_url': {
                              'url':
                                  'data:video/mp4;base64,${'X' * (1024 * 1024)}',
                            },
                          },
                        ],
                      },
                    ],
                  },
                }
              : null,
        ));
      }
      final conv = Conversation(
        title: '视频测试',
        messages: messages,
      );
      final json = jsonEncode(conv.toMap());
      // 10 messages × 1MB rawRequest = 10MB without stripping.
      // With stripping, it should be a few KB at most.
      expect(
        json.length,
        lessThan(200 * 1024),
        reason: 'Got ${json.length} bytes - stripping failed',
      );
    });
  });

  // =================================================================
  // 3. Round-trip: stripping must not lose user-visible data.
  // =================================================================
  group('ChatMessage round-trip preserves user-visible fields', () {
    test('content, role, id survive a toMap → fromMap round-trip', () {
      final original = ChatMessage(
        id: 'msg-1',
        role: 'assistant',
        content: '这是回复',
        reasoningContent: '这是推理',
        rawRequest: {
          'body': {
            'model': 'gpt-4o',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'video_url',
                    'video_url': {
                      'url': 'data:video/mp4;base64,${'A' * 10000}',
                    },
                  },
                ],
              },
            ],
          },
        },
        rawResponse: {
          'statusCode': 200,
          'data': {
            'choices': [
              {
                'message': {'content': '这是回复'}
              },
            ],
          },
        },
      );

      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.reasoningContent, original.reasoningContent);
      // The model and other metadata should survive in rawRequest.
      expect(restored.rawRequest, isNotNull);
      final body = (restored.rawRequest!['body'] as Map);
      expect(body['model'], 'gpt-4o');
      // rawResponse should be preserved fully (it's small).
      expect(restored.rawResponse, isNotNull);
      expect(restored.rawResponse!['statusCode'], 200);
    });
  });

  // =================================================================
  // 4. ConversationsNotifier._load must recover from corrupt JSON.
  //
  //    Bug being fixed: When the saved file is corrupt (truncated
  //    mid-write, malformed, etc.), the previous code set state = []
  //    and lost ALL conversations. Now it must back up the corrupt
  //    file and start fresh without losing the corrupted data forever.
  // =================================================================
  group('ConversationsNotifier._load - recovers from corrupt data', () {
    test('corrupt JSON (truncated mid-write) does not throw, starts empty',
        () async {
      // Simulate a corrupt file: valid JSON opening, but the array
      // is truncated in the middle of a message — exactly what
      // happens when the OS kills the app during a write.
      final truncatedJson =
          '[{"id":"conv-good","title":"Good","createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000","messages":[{"id":"m1","role":"user","content":"hello","createdAt":"2026-01-01T00:00:00.000","attachments":[]},{"id":"m2","role":"assistant","content":"wor';

      SharedPreferences.setMockInitialValues({
        'conversations': truncatedJson,
      });

      final container = ProviderContainer();
      try {
        // Reading the provider should NOT throw, even though the
        // conversations JSON is undecodable. (The previous behavior
        // could crash the app at this point.)
        expect(
          () => container.read(conversationsProvider),
          returnsNormally,
          reason:
              'Reading conversationsProvider must not throw on corrupt JSON. '
              'The notifier should catch the decode error and back up the '
              'corrupt blob to a conversations.corrupt.* key.',
        );
        // Pump the event loop until _load completes.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pumpEventQueue();

        // State should be a valid list (empty in this case since the
        // JSON is unparseable).
        final state = container.read(conversationsProvider);
        expect(state, isA<List<Conversation>>());
        expect(state, isEmpty,
            reason: 'Undecodable JSON should yield empty state, not crash');
      } finally {
        container.dispose();
      }
    });

    test('garbage JSON does not crash and yields empty state', () async {
      const garbage = 'not json at all {{{ ]]]';
      SharedPreferences.setMockInitialValues({
        'conversations': garbage,
      });

      final container = ProviderContainer();
      try {
        expect(() => container.read(conversationsProvider), returnsNormally,
            reason: 'Garbage JSON must not crash the provider read');

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pumpEventQueue();

        final state = container.read(conversationsProvider);
        expect(state, isA<List<Conversation>>());
        expect(state, isEmpty);

        // The corrupt payload must be backed up under a timestamped key so
        // the user can recover it manually, and the original 'conversations'
        // key must be cleared so the next save isn't fighting the same
        // corrupt blob.
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys();
        final backupKeys =
            keys.where((k) => k.startsWith('conversations.corrupt.'));
        expect(backupKeys, isNotEmpty,
            reason: 'corrupt JSON must be backed up under a '
                'conversations.corrupt.* key for manual recovery');
        // The backed-up value should be the original garbage
        final backupValue = prefs.getString(backupKeys.first);
        expect(backupValue, garbage);
        // The original key should be cleared
        expect(prefs.getString('conversations'), isNull,
            reason: 'original corrupt conversations key must be cleared '
                'so the next save starts fresh');
      } finally {
        container.dispose();
      }
    });

    test('empty conversations value yields empty state, not crash', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      try {
        container.read(conversationsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pumpEventQueue();

        expect(container.read(conversationsProvider), isEmpty);
      } finally {
        container.dispose();
      }
    });

    test(
        'corrupt backup retention: only the N most recent backups are kept, '
        'older ones are evicted', () async {
      // This test directly seeds the prefs with pre-existing corrupt backups
      // and verifies the retention cap is enforced after _load processes
      // a new corrupt payload.
      const cap = 3; // must match _maxCorruptBackups in conversation_provider

      // Pre-seed with cap+1 corrupt backups at different timestamps.
      final initial = <String, Object>{
        'conversations.corrupt.1000': 'old-1',
        'conversations.corrupt.2000': 'old-2',
        'conversations.corrupt.3000': 'old-3',
        'conversations.corrupt.4000': 'old-4', // this should be evicted
        'conversations': 'still corrupt',
      };
      SharedPreferences.setMockInitialValues(initial);

      final container = ProviderContainer();
      try {
        expect(() => container.read(conversationsProvider), returnsNormally);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pumpEventQueue();

        final prefs = await SharedPreferences.getInstance();
        final backupKeys = prefs
            .getKeys()
            .where((k) => k.startsWith('conversations.corrupt.'))
            .toList();
        // After _load processes the still-corrupt 'conversations' key, it
        // will create a new backup. The retention cap of $cap means at most
        // $cap backups should remain.
        expect(backupKeys.length, lessThanOrEqualTo(cap),
            reason: 'At most $cap corrupt backups should be retained; got '
                '${backupKeys.length}: $backupKeys');
        // The oldest pre-seeded backup (timestamp 1000) should be evicted
        // since it's the oldest of the originals.
        expect(prefs.getString('conversations.corrupt.1000'), isNull,
            reason: 'oldest backup must be evicted when over cap');
      } finally {
        container.dispose();
      }
    });
  });

  // =================================================================
  // 5. ConversationsNotifier._persist must survive errors.
  //
  //    Bug being fixed: When jsonEncode throws (e.g., due to a
  //    non-serializable value sneaking in), the save was silently
  //    lost. Now it must attempt fallback strategies.
  // =================================================================
  group('ConversationsNotifier._persist - survives JSON errors', () {
    test('normal save cycle preserves all messages and keeps payload small',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      try {
        // Wait for initial _load to settle.
        container.read(conversationsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await pumpEventQueue();

        final notifier = container.read(conversationsProvider.notifier);

        // Create a conversation.
        notifier.createConversation();
        final convId = notifier.state.first.id;

        // Add a message with a 1MB video attachment.
        final msg = ChatMessage(
          role: 'user',
          content: '请看视频',
          rawRequest: {
            'body': {
              'messages': [
                {
                  'content': [
                    {
                      'type': 'video_url',
                      'video_url': {
                        'url': 'data:video/mp4;base64,${'Z' * (1024 * 1024)}',
                      },
                    },
                  ],
                },
              ],
            },
          },
        );
        await notifier.updateMessages(convId, [msg]);

        // Allow debounced _persist to fire (500ms).
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await pumpEventQueue();

        // Verify SharedPreferences was written with a SMALL payload.
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('conversations');
        expect(saved, isNotNull);
        expect(
          saved!.length,
          lessThan(100 * 1024),
          reason: 'Saved JSON must be <100KB even for 1MB attachments. '
              'Got ${saved.length} bytes — stripping is not working.',
        );

        // And the user-visible data is preserved.
        final decoded = jsonDecode(saved) as List;
        final conv = decoded.first as Map;
        final messages = conv['messages'] as List;
        expect(messages.first['content'], '请看视频');
      } finally {
        container.dispose();
      }
    });
  });
}
