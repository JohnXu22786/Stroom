import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

// ============================================================================
// Tests for ChatMessage / Conversation data resilience:
// Prevents "no message yet" bugs caused by corrupt rawRequest/rawResponse data.
// ============================================================================

void main() {
  group('ChatMessage rawRequest/rawResponse - defensive deserialization', () {
    test('handles non-Map rawRequest (String value) without throwing', () {
      // Simulate corrupt data: rawRequest stored as a String instead of Map
      final map = <String, dynamic>{
        'id': 'test-1',
        'role': 'assistant',
        'content': 'Hello',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawRequest': 'this is a string, not a map',
      };

      // Should NOT throw — individual bad field doesn't break the message
      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test-1');
      expect(msg.content, 'Hello');
      // rawRequest should be null (gracefully ignored) instead of crashing
      expect(msg.rawRequest, isNull);
    });

    test('handles non-Map rawResponse (List value) without throwing', () {
      final map = <String, dynamic>{
        'id': 'test-2',
        'role': 'assistant',
        'content': 'Response',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawResponse': <dynamic>[1, 2, 3], // List instead of Map
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test-2');
      expect(msg.content, 'Response');
      // Should gracefully ignore and set to null
      expect(msg.rawResponse, isNull);
    });

    test('handles non-Map rawResponse (int value) without throwing', () {
      final map = <String, dynamic>{
        'id': 'test-3',
        'role': 'user',
        'content': 'Hello',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawResponse': 500, // int instead of Map
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test-3');
      expect(msg.content, 'Hello');
      expect(msg.rawResponse, isNull);
    });

    test('handles both rawRequest and rawResponse non-Map simultaneously', () {
      final map = <String, dynamic>{
        'id': 'test-4',
        'role': 'assistant',
        'content': 'Error',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawRequest': 'bad_request',
        'rawResponse': 404,
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.id, 'test-4');
      expect(msg.content, 'Error');
      expect(msg.rawRequest, isNull);
      expect(msg.rawResponse, isNull);
    });

    test('preserves valid rawRequest Map after deserialization', () {
      final map = <String, dynamic>{
        'id': 'test-5',
        'role': 'assistant',
        'content': 'Normal response',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawRequest': {
          'url': 'https://api.example.com/chat',
          'headers': {'Authorization': 'Bearer sk-****'},
        },
        'rawResponse': {
          'statusCode': 200,
          'data': {
            'choices': [
              {
                'message': {'content': 'Hi'}
              }
            ]
          },
        },
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.rawRequest, isNotNull);
      expect(msg.rawRequest!['url'], 'https://api.example.com/chat');
      expect(msg.rawResponse, isNotNull);
      expect(msg.rawResponse!['statusCode'], 200);
    });

    test('handles empty Map rawRequest/rawResponse gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-6',
        'role': 'user',
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawRequest': <String, dynamic>{},
        'rawResponse': <String, dynamic>{},
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.rawRequest, isA<Map<String, dynamic>>());
      expect(msg.rawResponse, isA<Map<String, dynamic>>());
      expect(msg.rawRequest, isEmpty);
      expect(msg.rawResponse, isEmpty);
    });

    test('handles null rawRequest/rawResponse - no key present', () {
      final map = <String, dynamic>{
        'id': 'test-7',
        'role': 'user',
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        // rawRequest/rawResponse keys not present
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.rawRequest, isNull);
      expect(msg.rawResponse, isNull);
    });

    test('handles rawRequest being explicit null value', () {
      final map = <String, dynamic>{
        'id': 'test-8',
        'role': 'user',
        'content': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'attachments': <dynamic>[],
        'rawRequest': null,
        'rawResponse': null,
      };

      final msg = ChatMessage.fromMap(map);
      expect(msg.rawRequest, isNull);
      expect(msg.rawResponse, isNull);
    });

    test(
        'corrupt rawRequest in one message does NOT skip other messages in conversation',
        () {
      final convMap = <String, dynamic>{
        'id': 'conv-resilient',
        'title': 'Resilient Conversation',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[
          <String, dynamic>{
            'id': 'good-msg-1',
            'role': 'user',
            'content': 'First message',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
          <String, dynamic>{
            'id': 'bad-raw-msg',
            'role': 'assistant',
            'content': 'This has bad rawRequest',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
            'rawRequest': 'corrupted_string_instead_of_map',
          },
          <String, dynamic>{
            'id': 'good-msg-2',
            'role': 'assistant',
            'content': 'Second valid message',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
          },
        ],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };

      // Conversation should load all 3 messages (bad rawRequest doesn't skip)
      final conv = Conversation.fromMap(convMap);
      expect(conv.id, 'conv-resilient');
      expect(conv.messages.length, 3,
          reason:
              'All 3 messages should survive — the middle one has corrupt rawRequest '
              'but that should be handled per-field without skipping the whole message');
      expect(conv.messages[0].content, 'First message');
      expect(conv.messages[1].content, 'This has bad rawRequest');
      expect(conv.messages[1].rawRequest, isNull,
          reason:
              'rawRequest should be null (gracefully ignored), not throwing');
      expect(conv.messages[2].content, 'Second valid message');
    });

    test('deeply nested valid rawResponse survives round-trip serialization',
        () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Complex response',
        rawRequest: {
          'url': 'https://api.example.com/v1/chat/completions',
          'headers': {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer sk-test',
          },
          'body': {
            'model': 'gpt-4',
            'messages': [
              {'role': 'user', 'content': 'Hi'},
            ],
            'max_tokens': 4096,
            'stream': true,
          },
        },
        rawResponse: {
          'statusCode': 200,
          'headers': {
            'content-type': ['application/json'],
            'x-request-id': ['req-12345'],
          },
          'data': {
            'id': 'chatcmpl-123',
            'object': 'chat.completion.chunk',
            'choices': [
              {
                'index': 0,
                'delta': {'content': 'Hello!'},
                'finish_reason': null,
              },
            ],
          },
        },
      );

      final map = msg.toMap();
      // Should serialize without throwing
      expect(map.containsKey('rawRequest'), true);
      expect(map.containsKey('rawResponse'), true);

      // Should deserialize without throwing
      final restored = ChatMessage.fromMap(map);
      expect(restored.rawRequest, isNotNull);
      expect(restored.rawResponse, isNotNull);
      expect(restored.rawRequest!['url'],
          'https://api.example.com/v1/chat/completions');
      expect(restored.rawResponse!['statusCode'], 200);

      // The round-trip should be JSON-serializable
      expect(() => jsonEncode(map), returnsNormally,
          reason: 'toMap output must be JSON-serializable');
    });
  });

  group('ChatMessage.toMap JSON safety', () {
    test(
        'toMap output is always JSON-serializable even with rawRequest/rawResponse',
        () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Test',
        rawRequest: {
          'url': 'https://api.example.com',
          'headers': {'Authorization': 'Bearer test-key'},
        },
        rawResponse: {
          'statusCode': 200,
          'data': {'result': 'ok'},
        },
      );

      final map = msg.toMap();
      // JSON encoding should never throw
      expect(() => jsonEncode(map), returnsNormally);
    });

    test('toMap with empty rawRequest/rawResponse is JSON-serializable', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Test',
        rawRequest: <String, dynamic>{},
        rawResponse: <String, dynamic>{},
      );

      final map = msg.toMap();
      expect(() => jsonEncode(map), returnsNormally);
    });

    test('toMap with deeply nested data is JSON-serializable', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Deep nesting test',
        rawRequest: {
          'url': 'https://api.example.com',
          'body': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': 'Hello'},
                ],
              },
            ],
            'tools': [
              {
                'type': 'function',
                'function': {
                  'name': 'search',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'query': {'type': 'string'},
                    },
                  },
                },
              },
            ],
          },
        },
        rawResponse: {
          'statusCode': 200,
          'data': {
            'choices': [
              {
                'index': 0,
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'search',
                        'arguments': '{"query": "test"}',
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      );

      final map = msg.toMap();
      expect(() => jsonEncode(map), returnsNormally);
    });
  });

  group('Conversation - full data resilience', () {
    test('conversation survives when ALL messages have corrupt rawRequest', () {
      final convMap = <String, dynamic>{
        'id': 'conv-all-bad',
        'title': 'All Bad',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[
          <String, dynamic>{
            'id': 'msg-1',
            'role': 'user',
            'content': 'Hello',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
            'rawRequest': 'bad_string',
          },
          <String, dynamic>{
            'id': 'msg-2',
            'role': 'assistant',
            'content': 'World',
            'createdAt': DateTime.now().toIso8601String(),
            'attachments': <dynamic>[],
            'rawResponse': <dynamic>[1, 2],
          },
        ],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };

      // Should still load all messages
      final conv = Conversation.fromMap(convMap);
      expect(conv.messages.length, 2,
          reason:
              'Both messages should survive even with corrupt rawRequest/rawResponse');
      expect(conv.messages[0].content, 'Hello');
      expect(conv.messages[1].content, 'World');
    });

    test('Conversation.toMap is always JSON-serializable', () {
      final conv = Conversation(
        title: 'Test',
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Hi',
            rawRequest: {
              'url': 'https://api.example.com',
              'body': {
                'messages': [
                  {'role': 'user', 'content': 'Hi'}
                ]
              },
            },
            rawResponse: {
              'statusCode': 200,
              'data': {
                'choices': [
                  {
                    'message': {'content': 'Hello'}
                  }
                ]
              },
            },
          ),
        ],
      );

      final map = conv.toMap();
      expect(() => jsonEncode(map), returnsNormally,
          reason: 'Conversation.toMap must produce JSON-serializable output');
    });

    test('Conversation with empty messages toMap is JSON-serializable', () {
      final conv = Conversation(title: 'Empty');
      final map = conv.toMap();
      expect(() => jsonEncode(map), returnsNormally);
    });
  });

  group('Conversation.fromMap - resilience against corrupt raw data', () {
    /// Helper: builds a conversation from a messages list JSON
    Conversation _convFromMessages(dynamic messagesJson) {
      return Conversation.fromMap({
        'id': 'test-conv',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': messagesJson,
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      });
    }

    test('handles null messages field gracefully', () {
      final conv = _convFromMessages(null);
      expect(conv.messages, isEmpty);
    });

    test(
        'handles messages with corrupt rawResponse without losing any messages',
        () {
      final conv = _convFromMessages([
        {
          'id': 'msg-1',
          'role': 'user',
          'content': 'Valid',
          'createdAt': DateTime.now().toIso8601String(),
          'attachments': [],
        },
        {
          'id': 'msg-2',
          'role': 'assistant',
          'content': 'Corrupt rawResponse',
          'createdAt': DateTime.now().toIso8601String(),
          'attachments': [],
          'rawResponse': 'bad_string',
        },
      ]);

      // Critical: message count should be 2, not 1 or 0
      // This is the exact bug being fixed: corrupt rawResponse should NOT skip the message
      expect(conv.messages.length, 2,
          reason:
              'Corrupt rawResponse should NOT cause the message to be skipped. '
              'The message must survive with rawResponse=null.');
      expect(conv.messages[1].content, 'Corrupt rawResponse');
      expect(conv.messages[1].rawResponse, isNull);
    });

    test('handles messages with ALL having corrupt rawRequest/rawResponse', () {
      final conv = _convFromMessages([
        {
          'id': 'msg-1',
          'role': 'user',
          'content': 'Hello',
          'createdAt': DateTime.now().toIso8601String(),
          'attachments': [],
          'rawRequest': 'bad_string',
        },
        {
          'id': 'msg-2',
          'role': 'assistant',
          'content': 'World',
          'createdAt': DateTime.now().toIso8601String(),
          'attachments': [],
          'rawResponse': <dynamic>[1, 2],
        },
      ]);

      // Should still load all messages
      expect(conv.messages.length, 2,
          reason:
              'Both messages should survive even with corrupt rawRequest/rawResponse');
      expect(conv.messages[0].content, 'Hello');
      expect(conv.messages[1].content, 'World');
    });

    test('handles partially corrupted conversation entries gracefully', () {
      // Simulate raw JSON array with some non-Map entries interspersed
      // This exercises the Conversation.fromMap loop defense
      final convList = <dynamic>[
        // Good conversation
        {
          'id': 'good-conv',
          'title': 'Good',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'messages': [],
          'isPinned': false,
          'sortOrder': 0,
          'draftText': '',
        },
        // Corrupt entry (not a Map)
        'this is not a conversation',
        // Another good conversation
        {
          'id': 'another-good',
          'title': 'Another',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'messages': [],
          'isPinned': false,
          'sortOrder': 0,
          'draftText': '',
        },
      ];

      final conversations = <Conversation>[];
      for (final item in convList) {
        if (item is Map) {
          try {
            conversations
                .add(Conversation.fromMap(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Skip corrupt entries (same logic as ConversationsNotifier._load)
          }
        }
      }

      expect(conversations.length, 2,
          reason:
              'Corrupt non-Map entries should be skipped, good entries preserved');
      expect(conversations[0].id, 'good-conv');
      expect(conversations[1].id, 'another-good');
    });
  });
}
