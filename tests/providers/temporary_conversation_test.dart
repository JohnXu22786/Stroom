// Tests for the temporary conversation feature:
//   - toggleTemporary enable/disable semantics
//   - countdown reset on new messages (updateMessages with the reset flag)
//   - serialization round-trip
//   - automatic deletion when the 1h window elapses
//   - the per-second UI ticker lifecycle
import 'dart:convert';
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/services/conversation_repository.dart';
import 'package:stroom/services/conversation_record_adapter.dart';
import 'package:stroom/services/conversation_repository_memory.dart';
import 'package:stroom/utils/web_file_store.dart';

/// Helper: create a ProviderContainer with a ConversationsNotifier that has
/// state pre-set (bypassing async _load from SharedPreferences).
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

Future<ProviderContainer> _createLoadedContainer(
  List<Conversation> initialState, {
  String? activeConversationId,
  ConversationRepository? repository,
}) async {
  WebFileStore.enableTestMode();
  addTearDown(WebFileStore.disableTestMode);
  SharedPreferences.setMockInitialValues({
    'conversations': jsonEncode(initialState.map((c) => c.toMap()).toList()),
    if (activeConversationId != null)
      'active_conversation_id': activeConversationId,
  });
  final container = ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(
        repository ?? MemoryConversationRepository(),
      ),
    ],
  );
  await container.read(conversationsProvider.notifier).ready;
  return container;
}

class _GatedMemoryConversationRepository extends MemoryConversationRepository {
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();
  bool gateNextRead = false;

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final messages = await super.getMessages(
      conversationId,
      offset: offset,
      limit: limit,
    );
    if (gateNextRead) {
      gateNextRead = false;
      readStarted.complete();
      await releaseRead.future;
    }
    return messages;
  }
}

Conversation _conv(String id, {bool isTemporary = false, DateTime? expiresAt}) {
  return Conversation(
    id: id,
    title: 'conv-$id',
    isTemporary: isTemporary,
    temporaryExpiresAt: expiresAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('toggleTemporary', () {
    test('enabling sets isTemporary and a ~1h expiry', () async {
      final container = _createContainer(initialState: [_conv('c1')]);
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      await notifier.toggleTemporary('c1');

      final conv = container.read(conversationsProvider).single;
      expect(conv.isTemporary, isTrue);
      expect(conv.temporaryExpiresAt, isNotNull);
      final remaining = conv.temporaryExpiresAt!.difference(DateTime.now());
      expect(
        remaining.inMinutes,
        greaterThanOrEqualTo(kTemporaryConversationDuration.inMinutes - 1),
      );
      expect(remaining.inHours, lessThanOrEqualTo(1));
    });

    test('disabling clears isTemporary and the expiry', () async {
      final container = _createContainer(
        initialState: [
          _conv('c1', isTemporary: true, expiresAt: DateTime.now()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      await notifier.toggleTemporary('c1');

      final conv = container.read(conversationsProvider).single;
      expect(conv.isTemporary, isFalse);
      expect(conv.temporaryExpiresAt, isNull);
    });

    test('re-enabling after disabling starts a fresh 1h window', () async {
      final container = _createContainer(initialState: [_conv('c1')]);
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      await notifier.toggleTemporary('c1');
      await notifier.toggleTemporary('c1');
      await notifier.toggleTemporary('c1');

      final conv = container.read(conversationsProvider).single;
      expect(conv.isTemporary, isTrue);
      final remaining = conv.temporaryExpiresAt!.difference(DateTime.now());
      expect(
        remaining.inMinutes,
        greaterThanOrEqualTo(kTemporaryConversationDuration.inMinutes - 1),
      );
    });
  });

  group('countdown reset on new messages', () {
    test(
      'updateMessages with the reset flag re-arms a temporary conversation',
      () async {
        // Start with a window almost fully elapsed.
        final container = _createContainer(
          initialState: [
            _conv('c1', isTemporary: true, expiresAt: DateTime.now()),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(conversationsProvider.notifier);

        await notifier.updateMessages(
            'c1',
            [
              ChatMessage(id: 'm1', role: 'user', content: 'hi'),
            ],
            resetTemporaryCountdown: true);

        final conv = container.read(conversationsProvider).single;
        expect(conv.isTemporary, isTrue);
        final remaining = conv.temporaryExpiresAt!.difference(DateTime.now());
        expect(
          remaining.inMinutes,
          greaterThanOrEqualTo(kTemporaryConversationDuration.inMinutes - 1),
        );
        expect(remaining.inHours, lessThanOrEqualTo(1));
      },
    );

    test(
      'updateMessages without the flag does NOT reset the countdown',
      () async {
        // 非产生事件（切换对话前的存档保存、编辑截断、删除消息等）
        // 不得重置倒计时。
        final expiresAt = DateTime.now().add(const Duration(hours: 3));
        final container = _createContainer(
          initialState: [_conv('c1', isTemporary: true, expiresAt: expiresAt)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(conversationsProvider.notifier);

        await notifier.updateMessages('c1', [
          ChatMessage(id: 'm1', role: 'user', content: 'hi'),
        ]);

        final conv = container.read(conversationsProvider).single;
        expect(conv.isTemporary, isTrue);
        expect(conv.temporaryExpiresAt, expiresAt);
      },
    );

    test('updateMessages does not touch non-temporary conversations', () async {
      final container = _createContainer(initialState: [_conv('c1')]);
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      await notifier.updateMessages(
          'c1',
          [
            ChatMessage(id: 'm1', role: 'user', content: 'hi'),
          ],
          resetTemporaryCountdown: true);

      final conv = container.read(conversationsProvider).single;
      expect(conv.isTemporary, isFalse);
      expect(conv.temporaryExpiresAt, isNull);
    });
  });

  group('serialization', () {
    test('toMap/fromMap round-trips temporary state', () {
      final expiresAt = DateTime.now().add(kTemporaryConversationDuration);
      final conv = _conv('c1', isTemporary: true, expiresAt: expiresAt);

      final restored = Conversation.fromMap(conv.toMap());

      expect(restored.isTemporary, isTrue);
      expect(restored.temporaryExpiresAt, expiresAt);
      expect(restored.id, 'c1');
    });

    test('non-temporary conversations serialize without temp fields', () {
      final restored = Conversation.fromMap(_conv('c1').toMap());
      expect(restored.isTemporary, isFalse);
      expect(restored.temporaryExpiresAt, isNull);
    });

    test('isTemporary without a valid expiry normalizes to non-temporary', () {
      // 数据损坏场景：isTemporary=true 但缺少/损坏 temporaryExpiresAt，
      // 恢复成普通对话（否则会成为永不过期且让 1s tick 永不停止的记录）。
      final restored = Conversation.fromMap({
        'id': 'c1',
        'title': 't',
        'messages': <Map<String, dynamic>>[],
        'isTemporary': true,
      });
      expect(restored.isTemporary, isFalse);
      expect(restored.temporaryExpiresAt, isNull);
    });
  });

  group('expiry auto-deletion', () {
    test('an expired temporary conversation is deleted', () async {
      final container = await _createLoadedContainer([
        _conv(
          'expired',
          isTemporary: true,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        _conv('alive'),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);
      notifier.state = [
        _conv(
          'expired',
          isTemporary: true,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        _conv('alive'),
      ];

      await notifier.checkTemporaryExpiryNow();

      final ids = container.read(conversationsProvider).map((c) => c.id);
      expect(ids, isNot(contains('expired')));
      expect(ids, contains('alive'));
    });

    test('multiple expired conversations are swept in one pass', () async {
      final container = await _createLoadedContainer([
        _conv('e1',
            isTemporary: true,
            expiresAt: DateTime.now().add(const Duration(hours: 1))),
        _conv('e2',
            isTemporary: true,
            expiresAt: DateTime.now().add(const Duration(hours: 1))),
        _conv('alive'),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);
      notifier.state = [
        _conv('e1',
            isTemporary: true,
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1))),
        _conv('e2',
            isTemporary: true,
            expiresAt: DateTime.now().subtract(const Duration(seconds: 5))),
        _conv('alive'),
      ];

      await notifier.checkTemporaryExpiryNow();

      final ids = container.read(conversationsProvider).map((c) => c.id);
      expect(ids, isNot(contains('e1')));
      expect(ids, isNot(contains('e2')));
      expect(ids, contains('alive'));
    });

    test('expired active conversation clears the active selection', () async {
      final container = await _createLoadedContainer(
        [
          _conv('active-expired',
              isTemporary: true,
              expiresAt: DateTime.now().add(const Duration(hours: 1))),
        ],
        activeConversationId: 'active-expired',
      );
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);
      notifier.state = [
        _conv('active-expired',
            isTemporary: true,
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1))),
      ];

      await notifier.checkTemporaryExpiryNow();

      expect(container.read(activeConversationIdProvider), isNull);
      expect(container.read(conversationsProvider), isEmpty);
    });

    test(
      'expiry read does not replace messages after a new send resets expiry',
      () async {
        final repository = _GatedMemoryConversationRepository();
        final container = await _createLoadedContainer(
          [
            Conversation(
              id: 'expiring-with-new-messages',
              title: 'Expiring with new messages',
              isTemporary: true,
              temporaryExpiresAt: DateTime.now().add(const Duration(hours: 1)),
              messages: [
                ChatMessage(
                  id: 'old-message',
                  role: 'user',
                  content: 'old history',
                ),
              ],
            ),
          ],
          repository: repository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(conversationsProvider.notifier);
        final conversation = container.read(conversationsProvider).single
          ..temporaryExpiresAt = DateTime.now().subtract(
            const Duration(minutes: 1),
          );
        notifier.state = [conversation];
        repository.gateNextRead = true;

        final expiryCheck = notifier.checkTemporaryExpiryNow();
        await repository.readStarted.future;
        await notifier.updateMessages(
          conversation.id,
          [
            ChatMessage(
              id: 'new-message',
              role: 'user',
              content: 'new history',
            ),
          ],
          resetTemporaryCountdown: true,
        );
        repository.releaseRead.complete();
        await expiryCheck;

        final current = container.read(conversationsProvider).single;
        expect(current.messages.map((message) => message.id), ['new-message']);
        expect(current.temporaryExpiresAt!.isAfter(DateTime.now()), isTrue);
      },
    );

    test(
      'unexpired temporary conversations survive the expiry check',
      () async {
        final container = _createContainer(
          initialState: [
            _conv(
              'soon',
              isTemporary: true,
              expiresAt: DateTime.now().add(const Duration(minutes: 5)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(conversationsProvider.notifier);

        await notifier.checkTemporaryExpiryNow();

        expect(container.read(conversationsProvider), hasLength(1));
      },
    );

    test(
        'an expired temporary conversation is removed right after async '
        'load', () async {
      // 生产路径：provider 真实的 _load 从 SharedPreferences 读入后，
      // 立即清理已到期临时对话（不等首轮 tick）。
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          _conv(
            'exp-old',
            isTemporary: true,
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ).toMap(),
          _conv('alive-load').toMap(),
        ]),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // 必须持有一个强引用的 ProviderSubscription（Riverpod 3 的
      // unlinked container 会回收订阅被丢弃的 provider）。
      final sub = container.listen<List<Conversation>?>(
        conversationsProvider,
        (_, __) {},
      );
      // 触发真实 factory（notifier._load()）。
      container.read(conversationsProvider.notifier);

      // 固定等待 _load + finally 中的到期清理完成（600ms，远大于该
      // 流程的微秒级耗时；不能用"按条件轮询"——首次检查若发生在
      // _load 完成前会立刻退出循环）。
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final ids = container.read(conversationsProvider).map((c) => c.id);
      expect(ids, isNot(contains('exp-old')));
      expect(ids, contains('alive-load'));
      sub.close();
    });

    test(
        'the per-second ticker bumps the UI tick while temp conversations '
        'exist and stops after they are all disabled', () {
      fakeAsync((async) {
        final container = _createContainer(initialState: [_conv('c1')]);
        addTearDown(container.dispose);
        final notifier = container.read(conversationsProvider.notifier);

        notifier.toggleTemporary('c1');
        async.elapse(const Duration(seconds: 3));
        expect(container.read(temporaryCountdownTickProvider), 3);

        // 移除最后一个临时对话：下一轮 tick 之前计时器即停止，
        // tick 值不再增长。
        notifier.toggleTemporary('c1');
        async.elapse(const Duration(seconds: 2));
        expect(container.read(temporaryCountdownTickProvider), 3);
      });
    });

    testWidgets(
        'the ticker stops when the last temporary conversation is deleted '
        'via deleteConversation', (tester) async {
      final container = await _createLoadedContainer([
        _conv('only-temp',
            isTemporary: true,
            expiresAt: DateTime.now().add(const Duration(hours: 24))),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      await tester.pump(const Duration(seconds: 2));
      expect(container.read(temporaryCountdownTickProvider), 2);

      final deletion = notifier.deleteConversation('only-temp');
      for (var i = 0; i < 10 && notifier.state.isNotEmpty; i++) {
        await tester.pump();
      }
      expect(notifier.state, isEmpty);
      await deletion;
      await tester.pump(const Duration(seconds: 1));
      final tickAfterDelete = container.read(temporaryCountdownTickProvider);

      await tester.pump(const Duration(seconds: 2));
      expect(container.read(temporaryCountdownTickProvider), tickAfterDelete);
    });
  });

  group('one-hour migration', () {
    test('repository records with 24h expiries are shortened on load',
        () async {
      WebFileStore.enableTestMode();
      addTearDown(WebFileStore.disableTestMode);
      SharedPreferences.setMockInitialValues({});
      final originalExpiry = DateTime.now().add(const Duration(hours: 24));
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.upsertConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'repository-temp-v0',
          'title': 'Temporary',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'isTemporary': true,
          'temporaryExpiresAt': originalExpiry.toIso8601String(),
          'temporaryExpiryVersion': 0,
          'messages': const [],
        }),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(conversationsProvider.notifier).ready;

      final migrated = container.read(conversationsProvider).single;
      expect(migrated.temporaryExpiryVersion,
          kTemporaryConversationDurationVersion);
      expect(
        migrated.temporaryExpiresAt,
        originalExpiry.subtract(const Duration(hours: 23)),
      );
      final stored = await repository.getConversation('repository-temp-v0');
      expect(stored, isNotNull);
      final storedLegacy =
          ConversationRecordAdapter.toLegacyMap(stored!, const []);
      expect(storedLegacy['temporaryExpiryVersion'],
          kTemporaryConversationDurationVersion);
      expect(storedLegacy['temporaryExpiresAt'],
          originalExpiry.subtract(const Duration(hours: 23)).toIso8601String());
    });

    test('persisted 24h expiries are shortened once when loaded', () async {
      final originalExpiry = DateTime.now().add(const Duration(hours: 24));
      final legacyTemporaryConversation = _conv(
        'legacy-temp',
        isTemporary: true,
        expiresAt: originalExpiry,
      ).toMap()
        ..remove('temporaryExpiryVersion');
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          legacyTemporaryConversation,
          'malformed-entry',
        ]),
      });

      Future<(ProviderContainer, ProviderSubscription<List<Conversation>?>)>
          loadContainer() async {
        final container = ProviderContainer();
        final subscription = container.listen<List<Conversation>?>(
          conversationsProvider,
          (_, __) {},
        );
        container.read(conversationsProvider.notifier);
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return (container, subscription);
      }

      final (firstContainer, firstSubscription) = await loadContainer();
      final migratedExpiry =
          firstContainer.read(conversationsProvider).single.temporaryExpiresAt!;
      final remaining = migratedExpiry.difference(DateTime.now());
      expect(remaining.inMinutes, greaterThanOrEqualTo(59));
      expect(remaining.inMinutes, lessThanOrEqualTo(60));
      expect(
        firstContainer
            .read(conversationsProvider)
            .single
            .temporaryExpiryVersion,
        kTemporaryConversationDurationVersion,
      );
      final migratedJson = (await SharedPreferences.getInstance()).getString(
        'conversations',
      )!;
      expect(jsonDecode(migratedJson), contains('malformed-entry'));
      firstSubscription.close();
      firstContainer.dispose();

      final (secondContainer, secondSubscription) = await loadContainer();
      expect(
        secondContainer.read(conversationsProvider).single.temporaryExpiresAt,
        migratedExpiry,
      );
      secondSubscription.close();
      secondContainer.dispose();
    });

    test(
      'expiry cleanup preserves malformed entries after migration',
      () async {
        final legacyTemporaryConversation = _conv(
          'expired-legacy-temp',
          isTemporary: true,
          expiresAt: DateTime.now().add(const Duration(hours: 22)),
        ).toMap()
          ..remove('temporaryExpiryVersion');
        SharedPreferences.setMockInitialValues({
          'conversations': jsonEncode([
            legacyTemporaryConversation,
            'malformed-entry',
          ]),
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final subscription = container.listen<List<Conversation>?>(
          conversationsProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);
        container.read(conversationsProvider.notifier);
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        expect(container.read(conversationsProvider), isEmpty);
        final storedJson = (await SharedPreferences.getInstance()).getString(
          'conversations',
        )!;
        expect(jsonDecode(storedJson), ['malformed-entry']);
      },
    );
  });
}
