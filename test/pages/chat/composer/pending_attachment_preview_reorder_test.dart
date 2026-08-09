import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void _dummyOnSend(String text, List<Attachment> attachments) {}
void _dummyOnStop() {}
void _dummyOnToolsChanged(Set<String> tools) {}
void _dummyOnModelSelected(int index) {}

void main() {
  group('ChatComposerWidget pending attachments rendering', () {
    testWidgets('composer shows attachment panel when attach button is tapped',
        (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith(
              (ref) => ConversationsNotifier(ref),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: _dummyOnSend,
                onStop: _dummyOnStop,
                onEnabledToolsChanged: _dummyOnToolsChanged,
                onModelSelected: _dummyOnModelSelected,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);

      // Tap the attach button to confirm the panel opens
      await tester.tap(find.byIcon(Icons.attach_file_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the file attachment panel
      expect(find.text('传文件'), findsOneWidget);
    });
  });
}
