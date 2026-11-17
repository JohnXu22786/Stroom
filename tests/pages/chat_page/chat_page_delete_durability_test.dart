// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/attachment_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AttachmentStorage.resetOverridesForTesting();
  });

  tearDown(AttachmentStorage.resetOverridesForTesting);

  testWidgets('persists message removal before deleting its attachment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final conversation = Conversation(
      id: 'delete-durability-conversation',
      title: 'Delete durability',
      messages: [
        ChatMessage(
          id: 'attached-message',
          role: 'user',
          content: 'Attached message',
          attachments: [
            Attachment(
              id: 'attachment',
              fileName: 'file.txt',
              mimeType: 'text/plain',
              fileType: 'file',
              hash: 'file-hash',
              storagePath: 'attachments/file.txt',
              fileSize: 4,
            ),
          ],
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'conversations': jsonEncode([conversation.toMap()]),
      'active_conversation_id': conversation.id,
    });
    final container = ProviderContainer(
      overrides: [
        activeConversationIdProvider.overrideWith((ref) => conversation.id),
        providerEntriesProvider.overrideWith(
          (ref) => ProviderEntriesNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ChatPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Map<String, dynamic>? persistedAtDelete;
    AttachmentStorage.readFileOverrideForTesting =
        (path) async => Uint8List.fromList([1, 2, 3, 4]);
    AttachmentStorage.deleteFileOverrideForTesting = (path) async {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('conversations');
      if (json != null) {
        final conversations = jsonDecode(json) as List<dynamic>;
        persistedAtDelete = (conversations.single as Map<String, dynamic>);
      }
      return true;
    };

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(persistedAtDelete, isNotNull);
    expect(persistedAtDelete!['messages'], isEmpty);
  });
}
