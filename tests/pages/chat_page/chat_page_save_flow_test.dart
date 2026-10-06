import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  testWidgets(
    'save opens destination choices and app files opens a folder/name panel',
    (tester) async {
      final conversation = Conversation(
        id: 'save-flow-conversation',
        title: 'Save flow',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        messages: [
          ChatMessage(
            id: 'assistant-reply',
            role: 'assistant',
            content: '这是一条可保存的回复。',
            createdAt: DateTime(2025, 1, 1),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(ref);
              notifier.state = [conversation];
              return notifier;
            }),
            activeConversationIdProvider
                .overrideWith((ref) => 'save-flow-conversation'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final appFiles = find.text('保存到应用文件');
      final device = find.text('保存到设备');
      expect(appFiles, findsOneWidget);
      expect(device, findsOneWidget);
      expect(
        tester.getTopLeft(appFiles).dy,
        lessThan(tester.getTopLeft(device).dy),
      );

      await tester.tap(appFiles);
      await tester.pumpAndSettle();

      expect(find.text('选择或创建文件夹保存 .md 文件'), findsOneWidget);
      final defaultName = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text.startsWith('chat_message_') == true,
      );
      expect(defaultName, findsOneWidget);
      expect(
        tester.widget<TextField>(defaultName).controller!.text,
        matches(RegExp(r'^chat_message_\d{8}_\d{6}$')),
      );
      expect(find.text('输入文件名（自动添加 .md 后缀）'), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      final records = await TextManifest.loadRecords();
      expect(records, hasLength(1));
      final saved = records.single;
      expect(saved.name, matches(RegExp(r'^chat_message_\d{8}_\d{6}$')));
      expect(saved.format, 'md');
      expect(saved.folder, '');
      expect(
        await TextManifest.readText('${saved.hash}.txt'),
        '这是一条可保存的回复。',
      );
    },
  );
}
