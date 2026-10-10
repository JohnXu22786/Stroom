import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/message_view/dsh_message_view.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/attachment_storage.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);

  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

Future<Uint8List> _tinyPng({Color color = Colors.red}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2, 2),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(2, 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switching conversations evicts cached message thumbnails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('chat_thumbnails_');
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);

    try {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      final attachmentPath = await AttachmentStorage.saveFile(
        'image.png',
        await _tinyPng(),
      );
      ChatMessage message(String id) => ChatMessage(
            id: id,
            role: 'user',
            content: '',
            attachments: [
              Attachment(
                id: 'same-attachment-id',
                fileName: 'image.png',
                mimeType: 'image/png',
                fileType: 'image',
                hash: 'same-hash',
                storagePath: attachmentPath,
                fileSize: 100,
              ),
            ],
            createdAt: DateTime(2025, 1, 1),
          );
      final now = DateTime(2025, 1, 1);
      final conversations = [
        Conversation(
          id: 'conversation-a',
          title: 'A',
          createdAt: now,
          updatedAt: now,
          messages: [message('message-a')],
        ),
        Conversation(
          id: 'conversation-b',
          title: 'B',
          createdAt: now,
          updatedAt: now,
          messages: [message('message-b')],
        ),
      ];
      ValueNotifier<Map<String, dynamic>?>? commands;
      void Function(Map<String, dynamic>)? sendEvent;
      Widget hostBuilder(
        String _,
        ValueNotifier<Map<String, dynamic>?> nextCommands,
        void Function(Map<String, dynamic>) nextSendEvent,
      ) {
        commands = nextCommands;
        sendEvent = nextSendEvent;
        return const SizedBox.shrink();
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(ref);
              notifier.state = conversations;
              return notifier;
            }),
            activeConversationIdProvider
                .overrideWith((ref) => 'conversation-a'),
            providerEntriesProvider
                .overrideWith((ref) => ProviderEntriesNotifier()),
          ],
          child: MaterialApp(
            home: ChatPage(messageHostBuilder: hostBuilder),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      sendEvent!({'type': 'ready'});
      await tester.pump();
      final session = commands!.value!['session'] as String;
      sendEvent!({
        'type': 'action',
        'action': 'thumbnail',
        'session': session,
        'messageId': 'message-a',
        'attachmentId': 'same-attachment-id',
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      List<Map<String, dynamic>> attachments() {
        final values = tester
            .widget<DshMessageView>(find.byType(DshMessageView))
            .messages
            .single['attachments'] as List;
        return values.cast<Map<String, dynamic>>();
      }

      expect(
        attachments().single['thumbnail'],
        startsWith('data:image/png;base64,'),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      container.read(activeConversationIdProvider.notifier).state =
          'conversation-b';
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final secondMessage = tester
          .widget<DshMessageView>(find.byType(DshMessageView))
          .messages
          .singleWhere((entry) => entry['id'] == 'message-b');
      final secondAttachment =
          (secondMessage['attachments'] as List).single as Map<String, dynamic>;
      expect(secondAttachment.containsKey('thumbnail'), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      PathProviderPlatform.instance = previousPathProvider;
      await directory.delete(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
    'a pending thumbnail does not block the same id in a new conversation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final directory =
          await Directory.systemTemp.createTemp('chat_thumbnail_race_');
      final previousPathProvider = PathProviderPlatform.instance;
      final staleLoad = Completer<Uint8List?>();
      PathProviderPlatform.instance = _Documents(directory.path);

      try {
        await tester.binding.setSurfaceSize(const Size(1200, 2000));
        final currentThumbnail = await _tinyPng(color: Colors.blue);
        var staleReads = 0;
        var currentReads = 0;
        ChatMessage message(String id, String path) => ChatMessage(
              id: id,
              role: 'user',
              content: '',
              attachments: [
                Attachment(
                  id: 'reused-attachment-id',
                  fileName: 'image.png',
                  mimeType: 'image/png',
                  fileType: 'image',
                  hash: 'same-hash',
                  storagePath: path,
                  fileSize: 100,
                ),
              ],
              createdAt: DateTime(2025, 1, 1),
            );
        final now = DateTime(2025, 1, 1);
        final conversations = [
          Conversation(
            id: 'conversation-a',
            title: 'A',
            createdAt: now,
            updatedAt: now,
            messages: [message('message-a', 'conversation-a.png')],
          ),
          Conversation(
            id: 'conversation-b',
            title: 'B',
            createdAt: now,
            updatedAt: now,
            messages: [message('message-b', 'conversation-b.png')],
          ),
        ];
        ValueNotifier<Map<String, dynamic>?>? commands;
        void Function(Map<String, dynamic>)? sendEvent;
        Widget hostBuilder(
          String _,
          ValueNotifier<Map<String, dynamic>?> nextCommands,
          void Function(Map<String, dynamic>) nextSendEvent,
        ) {
          commands = nextCommands;
          sendEvent = nextSendEvent;
          return const SizedBox.shrink();
        }
        Future<Uint8List?> readThumbnail(String path) {
          if (path == 'conversation-a.png') {
            staleReads++;
            return staleLoad.future;
          }
          if (path == 'conversation-b.png') {
            currentReads++;
            return Future.value(currentThumbnail);
          }
          throw StateError('Unexpected thumbnail path: $path');
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              conversationsProvider.overrideWith((ref) {
                final notifier = ConversationsNotifier(ref);
                notifier.state = conversations;
                return notifier;
              }),
              activeConversationIdProvider
                  .overrideWith((ref) => 'conversation-a'),
              providerEntriesProvider
                  .overrideWith((ref) => ProviderEntriesNotifier()),
            ],
            child: MaterialApp(
              home: ChatPage(
                messageHostBuilder: hostBuilder,
                thumbnailBytesReader: readThumbnail,
              ),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        sendEvent!({'type': 'ready'});
        await tester.pump();
        var session = commands!.value!['session'] as String;
        sendEvent!({
          'type': 'action',
          'action': 'thumbnail',
          'session': session,
          'messageId': 'message-a',
          'attachmentId': 'reused-attachment-id',
        });
        await tester.pump();
        expect(staleReads, 1);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ChatPage)),
        );
        container.read(activeConversationIdProvider.notifier).state =
            'conversation-b';
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        session = commands!.value!['session'] as String;
        sendEvent!({
          'type': 'action',
          'action': 'thumbnail',
          'session': session,
          'messageId': 'message-b',
          'attachmentId': 'reused-attachment-id',
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(currentReads, 1);

        Map<String, dynamic> secondAttachment() {
          final message = tester
              .widget<DshMessageView>(find.byType(DshMessageView))
              .messages
              .singleWhere((entry) => entry['id'] == 'message-b');
          return (message['attachments'] as List).single
              as Map<String, dynamic>;
        }

        final latestThumbnail = secondAttachment()['thumbnail'] as String;
        expect(latestThumbnail, startsWith('data:image/png;base64,'));

        staleLoad.complete(await _tinyPng());
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(secondAttachment()['thumbnail'], latestThumbnail);
      } finally {
        if (!staleLoad.isCompleted) staleLoad.complete(null);
        await tester.pumpWidget(const SizedBox.shrink());
        PathProviderPlatform.instance = previousPathProvider;
        await directory.delete(recursive: true);
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
