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
import 'package:stroom/pages/chat/widgets/message_action_row.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/conversation_record_adapter.dart';
import 'package:stroom/services/conversation_repository.dart';
import 'package:stroom/services/conversation_repository_memory.dart';
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

  testWidgets(
    'deleting an attachment keeps bytes referenced by older history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'shared-attachment-history',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      final attachment = Attachment(
        id: 'shared-attachment',
        fileName: 'file.txt',
        mimeType: 'text/plain',
        fileType: 'file',
        hash: 'file-hash',
        storagePath: 'attachments/shared-file.txt',
        fileSize: 4,
      );
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'shared-attachment-history',
          'title': 'Shared attachment history',
          'messages': [
            ChatMessage(
              id: 'older-reference',
              role: 'user',
              content: 'Older reference',
              attachments: [attachment],
            ).toMap(),
            for (var index = 1; index < 20; index++)
              ChatMessage(
                id: 'm$index',
                role: 'user',
                content: 'Message $index',
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
              ).toMap(),
            ChatMessage(
              id: 'latest-reference',
              role: 'user',
              content: 'Latest reference',
              attachments: [attachment],
              createdAt: DateTime(2025, 1, 1).add(const Duration(hours: 20)),
            ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          activeConversationIdProvider.overrideWith(
            (ref) => 'shared-attachment-history',
          ),
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
      expect(
        container
            .read(conversationsProvider)
            .single
            .messages
            .map((message) => message.id),
        isNot(contains('older-reference')),
        reason: 'the older attachment reference should remain outside the page',
      );

      var deleteCalls = 0;
      AttachmentStorage.readFileOverrideForTesting =
          (path) async => Uint8List.fromList([1, 2, 3, 4]);
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deleteCalls++;
        return true;
      };
      final latestRow = find.byWidgetPredicate(
        (widget) =>
            widget is MessageActionRow &&
            widget.messageText == 'Latest reference',
      );
      expect(latestRow, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: latestRow,
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(deleteCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
