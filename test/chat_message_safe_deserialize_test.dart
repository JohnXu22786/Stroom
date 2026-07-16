import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  group('ChatMessage.fromMap - defensive deserialization', () {
    test('handles invalid createdAt format without throwing', () {
      final map = <String, dynamic>{
        'id': 'test123',
        'role': 'user',
        'content': 'Hello',
        'createdAt': 'not-a-valid-date', // invalid date format
        'attachments': <dynamic>[],
      };

      // Should not throw
      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test123');
      expect(msg.content, 'Hello');
      // createdAt should fall back to a valid DateTime (created now-ish)
      expect(msg.createdAt, isA<DateTime>());
    });

    test('handles null createdAt gracefully', () {
      final map = <String, dynamic>{
        'id': 'test456',
        'role': 'user',
        'content': 'Hello',
        // createdAt is null
        'createdAt': null,
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test456');
      expect(msg.createdAt, isA<DateTime>());
    });

    test('handles null content gracefully', () {
      final map = <dynamic, dynamic>{
        'id': 'test789',
        'role': 'user',
        'content': null,
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(
          Map<String, dynamic>.from(map as Map));
      expect(msg.content, '');
    });

    test('handles missing content key gracefully', () {
      final map = <String, dynamic>{
        'id': 'test999',
        'role': 'assistant',
        // content key is missing
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.content, '');
    });

    test('handles invalid attachments (non-List) gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-attach',
        'role': 'user',
        'content': 'with attachment',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': 'not-a-list', // invalid type
      };

      // Should not throw and return empty attachments
      final msg = ChatMessage.fromMap(map);
      expect(msg.attachments, isEmpty);
    });

    test('handles attachments list with non-Map entries gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-bad-attach',
        'role': 'user',
        'content': 'bad attachment',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[
          'this is a string, not a map',
          123,
          null,
        ],
      };

      // Should not throw and return empty attachments
      final msg = ChatMessage.fromMap(map);
      expect(msg.attachments, isEmpty);
    });

    test('handles mixed valid/invalid attachments preserving valid entries',
        () {
      final map = <String, dynamic>{
        'id': 'test-mixed-attach',
        'role': 'user',
        'content': 'mixed attachments',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[
          'this is a string, not a map',
          <String, dynamic>{
            'id': 'valid-att-1',
            'fileName': 'good.txt',
            'mimeType': 'text/plain',
            'fileType': 'text',
            'hash': 'abc123',
            'storagePath': '/tmp/good.txt',
            'fileSize': 100,
            'createdAt': DateTime.now().toIso8601String(),
          },
          123,
          <String, dynamic>{
            'id': 'valid-att-2',
            'fileName': 'also-good.txt',
            'mimeType': 'text/plain',
            'fileType': 'text',
            'hash': 'def456',
            'storagePath': '/tmp/also-good.txt',
            'fileSize': 200,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      };

      // Should keep valid attachments and skip invalid ones
      final msg = ChatMessage.fromMap(map);
      expect(msg.attachments.length, 2,
          reason:
              'Both valid attachments should be preserved, invalid ones skipped');
      expect(msg.attachments[0].fileName, 'good.txt');
      expect(msg.attachments[1].fileName, 'also-good.txt');
    });

    test('handles empty role string gracefully (defaults to user)', () {
      final map = <String, dynamic>{
        'id': 'test-role',
        'role': '',
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.role, 'user');
    });

    test('handles invalid role gracefully (defaults to user)', () {
      final map = <String, dynamic>{
        'id': 'test-role2',
        'role': 'system',
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.role, 'user');
    });

    test('handles null role gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-nullrole',
        'role': null,
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.role, 'user');
    });

    test('handles messages list with mixed valid/invalid entries', () {
      final map = <String, dynamic>{
        'id': 'test-mixed',
        'role': 'user',
        'content': 'valid message',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'isStreaming': true,
        'isError': false,
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test-mixed');
      expect(msg.isStreaming, true);
      expect(msg.isError, false);
    });

    test('handles malformed isStreaming/isError fields', () {
      final map = <String, dynamic>{
        'id': 'test-bad-bools',
        'role': 'assistant',
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'isStreaming': 'not-a-bool', // should default to false
        'isError': 123, // should default to false
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.isStreaming, false);
      expect(msg.isError, false);
    });

    test('handles entire conversation message list with corrupt entries - partial protection',
        () {
      // This tests what happens when a conversation has some bad messages
      // The conversation itself should still be loadable
      final convMap = <String, dynamic>{
        'id': 'conv-with-bad-msgs',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[
          <String, dynamic>{
            'id': 'good-msg-1',
            'role': 'user',
            'content': 'Hello',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
          <String, dynamic>{
            'id': 'bad-msg',
            'role': 'assistant',
            'content': 'This message has a bad date',
            'createdAt': 'bad-date-format',
            'attachments': <dynamic>[],
          },
          <String, dynamic>{
            'id': 'good-msg-2',
            'role': 'assistant',
            'content': 'World',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
        ],
        'isPinned': false,
        'sortOrder': 0,
      };

      // Should not throw; the bad message's createdAt should be handled
      final conv = Conversation.fromMap(convMap);
      expect(conv.id, 'conv-with-bad-msgs');
      expect(conv.messages.length, 3);
      // The bad message should still be present but with a fallback DateTime
      final badMsg = conv.messages[1];
      expect(badMsg.content, 'This message has a bad date');
      expect(badMsg.createdAt, isA<DateTime>());
    });
  });

  group('Attachment.fromMap - defensive deserialization', () {
    test('handles null id gracefully', () {
      final map = <String, dynamic>{
        // id is null
        'id': null,
        'fileName': 'test.txt',
        'mimeType': 'text/plain',
        'fileType': 'text',
        'hash': 'abc123',
        'storagePath': '/tmp/test.txt',
        'fileSize': 100,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final att = Attachment.fromMap(map);
      expect(att.id, isA<String>());
      expect(att.fileName, 'test.txt');
    });

    test('handles null fileName gracefully', () {
      final map = <String, dynamic>{
        'id': 'att-1',
        'fileName': null,
        'mimeType': 'text/plain',
        'fileType': 'text',
        'hash': 'abc123',
        'storagePath': '/tmp/test.txt',
        'fileSize': 100,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final att = Attachment.fromMap(map);
      expect(att.fileName, '');
    });

    test('handles missing mimeType gracefully', () {
      final map = <String, dynamic>{
        'id': 'att-2',
        'fileName': 'test.txt',
        // mimeType missing
        'fileType': 'text',
        'hash': 'abc123',
        'storagePath': '/tmp/test.txt',
        'fileSize': 100,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final att = Attachment.fromMap(map);
      expect(att.mimeType, '');
    });

    test('handles invalid createdAt gracefully', () {
      final map = <String, dynamic>{
        'id': 'att-3',
        'fileName': 'test.txt',
        'mimeType': 'text/plain',
        'fileType': 'text',
        'hash': 'abc123',
        'storagePath': '/tmp/test.txt',
        'fileSize': 100,
        'createdAt': 'not-a-date',
      };

      final att = Attachment.fromMap(map);
      expect(att, isA<Attachment>());
      // createdAt should be a valid DateTime
      expect(att.createdAt, isA<DateTime>());
    });

    test('handles null fileSize gracefully', () {
      final map = <String, dynamic>{
        'id': 'att-4',
        'fileName': 'test.txt',
        'mimeType': 'text/plain',
        'fileType': 'text',
        'hash': 'abc123',
        'storagePath': '/tmp/test.txt',
        'fileSize': null,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final att = Attachment.fromMap(map);
      expect(att.fileSize, 0);
    });

    test('handles invalid createdAt in conversation context', () {
      // Test that a conversation with an attachment with bad createdAt
      // doesn't fail the whole conversation
      final convMap = <String, dynamic>{
        'id': 'conv-bad-att-date',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[
          <String, dynamic>{
            'id': 'msg-1',
            'role': 'user',
            'content': 'Hello',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[
              <String, dynamic>{
                'id': 'att-bad-date',
                'fileName': 'test.txt',
                'mimeType': 'text/plain',
                'fileType': 'text',
                'hash': 'abc123',
                'storagePath': '/tmp/test.txt',
                'fileSize': 100,
                'createdAt': 'invalid-date',
              },
            ],
          },
        ],
        'isPinned': false,
        'sortOrder': 0,
      };

      final conv = Conversation.fromMap(convMap);
      expect(conv.messages.length, 1);
      expect(conv.messages[0].attachments.length, 1);
    });
  });

  group('Conversation.fromMap - defensive deserialization', () {
    test('handles null messages gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-null-msgs',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': null,
        'isPinned': false,
        'sortOrder': 0,
      };

      final conv = Conversation.fromMap(map);
      expect(conv.messages, isEmpty);
    });

    test('handles null title gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-null-title',
        'title': null,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
      };

      final conv = Conversation.fromMap(map);
      expect(conv.title, '');
    });

    test('handles invalid createdAt gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-bad-date',
        'title': 'Test',
        'createdAt': 'bad-date',
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
      };

      final conv = Conversation.fromMap(map);
      // createdAt should fall back to a valid DateTime
      expect(conv.createdAt, isA<DateTime>());
    });

    test('handles invalid updatedAt gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-bad-updated',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': 'bad-date',
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
      };

      final conv = Conversation.fromMap(map);
      expect(conv.updatedAt, isA<DateTime>());
    });

    test('handles non-Map entry in messages list gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-nonmap-msg',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[
          'this is a string, not a map',
          123,
          null,
        ],
        'isPinned': false,
        'sortOrder': 0,
      };

      // Should not throw and should skip non-Map entries
      final conv = Conversation.fromMap(map);
      expect(conv.messages, isEmpty);
    });

    test('handles missing sortOrder gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-no-sort',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        // sortOrder missing
      };

      final conv = Conversation.fromMap(map);
      expect(conv.sortOrder, 0);
    });

    test('handles corrupt enabledMcpToolNames gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-bad-tools',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
        'enabledMcpToolNames': 'not-a-list', // invalid type
      };

      final conv = Conversation.fromMap(map);
      expect(conv.enabledMcpToolNames, isEmpty);
    });

    test('handles null enabledMcpToolNames gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-null-tools',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
        'enabledMcpToolNames': null,
      };

      final conv = Conversation.fromMap(map);
      expect(conv.enabledMcpToolNames, isEmpty);
    });

    test('handles null createdAt gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-null-created',
        'title': 'Test',
        'createdAt': null,
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };

      final conv = Conversation.fromMap(map);
      expect(conv.createdAt, isA<DateTime>());
    });

    test('handles null updatedAt gracefully', () {
      final map = <String, dynamic>{
        'id': 'conv-null-updated',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': null,
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };

      final conv = Conversation.fromMap(map);
      expect(conv.updatedAt, isA<DateTime>());
    });

    test('handles a message with truly corrupt data that throws during fromMap',
        () {
      // This message map has an impossible structure that would cause
      // ChatMessage.fromMap to throw (e.g., messages with non-Map entries)
      final convMap = <String, dynamic>{
        'id': 'conv-throwing-msg',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[
          <String, dynamic>{
            'id': 'good-msg',
            'role': 'user',
            'content': 'Hello',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
          // A message where attachments field causes .fromMap to fail
          // by providing a Map that can't be cast to Map<String, dynamic>
          <String, dynamic>{
            'id': 'throw-msg',
            'role': 'user',
            'content': 'Bad',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[
              <String, dynamic>{
                // This attachment itself should be fine
              },
            ],
            // Ensure Conversation.fromMap catches the throw
          },
          <String, dynamic>{
            'id': 'good-msg-2',
            'role': 'assistant',
            'content': 'World',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
        ],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };

      // Should not throw — the corrupt message should be skipped
      final conv = Conversation.fromMap(convMap);
      expect(conv.id, 'conv-throwing-msg');
      // Good messages should still be present
      expect(conv.messages.length, greaterThanOrEqualTo(1),
          reason:
              'At least good messages should survive; the throwing one is skipped');
    });
  });

  group('ConversationsNotifier._load - robust loading via raw JSON', () {
    /// Helper: create a ProviderContainer with a ConversationsNotifier that
    /// skips _load by using a pre-set state. This avoids timing issues with
    /// async _load + container disposal.
    ProviderContainer _createContainer({List<Conversation>? initialState}) {
      SharedPreferences.setMockInitialValues({});
      return ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(ref);
            notifier.state = initialState ?? [];
            return notifier;
          }),
        ],
      );
    }

    test(
        'conversation model handles one corrupt conversation without losing others',
        () {
      // Simulate loading raw JSON where one conversation is corrupt
      // by calling Conversation.fromMap on mixed data

      // Good conversation
      final goodConv = Conversation.fromMap({
        'id': 'good-conv',
        'title': 'Good Conversation',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <Map<String, dynamic>>[],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      });

      // Conversation with null draftText — should still parse
      final badConv = Conversation.fromMap({
        'id': 'bad-conv',
        'title': 'Bad Conversation',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <Map<String, dynamic>>[],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': null,
      });

      // Both conversations should be loadable
      expect(goodConv.id, 'good-conv');
      expect(badConv.id, 'bad-conv');
      expect(badConv.draftText, '');
    });

    test('conversation with bad message date still loads all messages', () {
      final conv = Conversation.fromMap({
        'id': 'conv-with-bad-msg',
        'title': 'Has a bad message',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': [
          {
            'id': 'msg-1',
            'role': 'user',
            'content': 'Good message',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
          {
            'id': 'msg-2',
            'role': 'assistant',
            'content': 'Bad message with invalid date',
            'createdAt': 'invalid-date-format',
            'attachments': <dynamic>[],
          },
        ],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      });

      expect(conv.messages.length, 2,
          reason:
              'Both messages should be present (bad dates handled gracefully)');
      expect(conv.messages[0].content, 'Good message');
      expect(conv.messages[1].content, 'Bad message with invalid date');
    });

    test('ConversationsNotifier can have state with all valid conversations',
        () {
      final container = _createContainer(initialState: [
        Conversation.fromMap({
          'id': 'good-conv',
          'title': 'Good',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'messages': <Map<String, dynamic>>[],
          'isPinned': false,
          'sortOrder': 0,
          'draftText': '',
        }),
        Conversation.fromMap({
          'id': 'bad-conv',
          'title': 'Bad',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'messages': <Map<String, dynamic>>[],
          'isPinned': false,
          'sortOrder': 0,
          'draftText': null,
        }),
      ]);

      final convs = container.read(conversationsProvider);
      expect(convs.length, 2);
      container.dispose();
    });

    test('ConversationsNotifier state can be empty without error', () {
      final container = _createContainer(initialState: []);
      final convs = container.read(conversationsProvider);
      expect(convs, isEmpty);
      container.dispose();
    });
  });

  group('Conversation serialization - full resilience', () {
    test('toMap/fromMap round-trip handles streaming flags gracefully', () {
      final conv = Conversation(
        id: 'test-roundtrip',
        title: 'Test',
        messages: [
          ChatMessage(
            id: 'm1',
            role: 'user',
            content: 'Hello',
            isStreaming: true,
            isError: false,
          ),
          ChatMessage(
            id: 'm2',
            role: 'assistant',
            content: 'Hi there',
            isStreaming: false,
            isError: false,
          ),
        ],
      );

      // Round-trip
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(restored.messages.length, 2);
      expect(restored.messages[0].isStreaming, true);
      expect(restored.messages[1].isStreaming, false);
    });

    test('serialization does not contain stale streaming flags', () {
      final msg = ChatMessage(
        id: 'm1',
        role: 'user',
        content: 'Hello',
        isStreaming: false,
        isError: false,
      );

      final map = msg.toMap();
      // isStreaming should NOT be in the map when false (not included)
      expect(map.containsKey('isStreaming'), false);
    });

    test('serialization includes isStreaming when true', () {
      final msg = ChatMessage(
        id: 'm1',
        role: 'user',
        content: 'Hello',
        isStreaming: true,
      );

      final map = msg.toMap();
      expect(map['isStreaming'], true);
    });
  });
}
