import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/providers/conversation_provider.dart';

class _RejectRawDiagnosticWrites extends InMemorySharedPreferencesStore {
  _RejectRawDiagnosticWrites(Map<String, Object> data) : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.conversations' &&
        value is String &&
        value.contains('rawRequest')) {
      throw StateError('simulate a full-save rejection');
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tier 2 save keeps schema versions and unknown conversation fields',
      () async {
    final originalStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.withData({
      'flutter.conversations': jsonEncode([
        {
          'id': 'future-conversation',
          'title': 'Old title',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'updatedAt': '2025-01-01T00:00:00.000Z',
          'schemaVersion': 7,
          'futureConversationField': {'keep': true},
          'messages': [
            {
              'id': 'future-message',
              'role': 'tool',
              'content': 'answer',
              'createdAt': '2025-01-01T00:01:00.000Z',
              'schemaVersion': 8,
              'futureMessageField': 'keep',
              'attachments': [
                {
                  'id': 'image',
                  'fileName': 'image.png',
                  'mimeType': 'image/png',
                  'fileType': 'image',
                  'hash': 'image-hash',
                  'storagePath': 'attachments/image.png',
                  'fileSize': 3,
                },
              ],
              'contentParts': [
                {'type': 'text', 'text': 'before'},
                {'type': 'attachment', 'attachmentId': 'image'},
                {'type': 'text', 'text': 'after'},
              ],
              'rawRequest': {'body': 'drop this only in tier two'},
            },
          ],
        },
      ]),
    });
    final container = ProviderContainer();
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      SharedPreferencesStorePlatform.instance = _RejectRawDiagnosticWrites({});
      await prefs.reload();

      await notifier.renameConversation('future-conversation', 'New title');
      await Future<void>.delayed(const Duration(milliseconds: 650));

      final saved = jsonDecode(prefs.getString('conversations')!) as List;
      final savedConversation = Map<String, dynamic>.from(saved.single as Map);
      final savedMessage = Map<String, dynamic>.from(
        (savedConversation['messages'] as List).single as Map,
      );
      expect(savedConversation['schemaVersion'], 7);
      expect(savedConversation['futureConversationField'], {'keep': true});
      expect(savedMessage['schemaVersion'], 8);
      expect(savedMessage['futureMessageField'], 'keep');
      expect(savedMessage['role'], 'tool');
      expect(savedMessage['contentParts'], [
        {'type': 'text', 'text': 'before'},
        {'type': 'attachment', 'attachmentId': 'image'},
        {'type': 'text', 'text': 'after'},
      ]);
      expect(savedMessage.containsKey('rawRequest'), isFalse);
    } finally {
      container.dispose();
      SharedPreferencesStorePlatform.instance = originalStore;
    }
  });
}
