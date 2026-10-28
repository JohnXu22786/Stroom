import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/services/conversation_repository.dart';
import 'package:stroom/services/conversation_repository_memory.dart';

class _FailingSearchRepository extends MemoryConversationRepository {
  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async =>
      throw StateError('message search unavailable');
}

void main() {
  testWidgets('shows search failure alongside title matches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FailingSearchRepository();
    await repository.initialize();
    await repository.upsertConversation(
      StroomConversation(
        id: 'title-match',
        title: 'Needle title',
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2025),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository)
        ],
        child: const MaterialApp(home: ConversationsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Needle title'), findsOneWidget);
    expect(find.text('搜索失败，部分消息结果可能未显示'), findsOneWidget);
  });
}
