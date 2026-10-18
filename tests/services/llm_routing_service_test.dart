import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_routing_service.dart';

void main() {
  group('LlmRoutingService quota eligibility', () {
    test(
      'unknown and stale balances do not satisfy reserves or balance policy',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final account = _account(
          'unknown',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(1, unit: 'credits'),
              ),
            },
          ),
        );
        final rig = _Rig(now: now, accounts: [account]);
        await expectLater(
          rig.route((candidate, progress) async {
            await progress.markRequestSent();
            return candidate.account.id;
          }),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final stale = _account(
          'stale',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(1, unit: 'credits'),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(
                100,
                'credits',
                now.subtract(const Duration(days: 2)),
              ),
              remaining: _metric(
                80,
                'credits',
                now.subtract(const Duration(days: 2)),
              ),
              resetAt: now.subtract(const Duration(minutes: 1)),
            ),
          },
        );
        final staleRig = _Rig(now: now, accounts: [stale]);
        await expectLater(
          staleRig.route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        await expectLater(
          _Rig(
            now: now,
            accounts: [_account('unknown-balance', 'codex')],
            strategy: LlmSelectionStrategy.balanceHigher,
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        await expectLater(
          _Rig(
            now: now,
            accounts: [
              _account(
                'calendar-without-zone',
                'codex',
                policy: LlmRoutingPolicy(
                  windows: {
                    LlmUsageWindow.day: const LlmWindowPolicy(
                      mode: LlmWindowMode.calendar,
                      reserveFloor: LlmLimitThreshold.fixed(1, unit: 'credits'),
                    ),
                  },
                ),
              ),
            ],
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'uses newer comparable provider usage over stale remaining balance',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final account = _account(
          'newer-usage',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(60, unit: 'credits'),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(
                100,
                'credits',
                now.subtract(const Duration(minutes: 5)),
              ),
              remaining: _metric(
                80,
                'credits',
                now.subtract(const Duration(hours: 2)),
              ),
              used: _metric(
                50,
                'credits',
                now.subtract(const Duration(minutes: 5)),
              ),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );

        await expectLater(
          _Rig(now: now, accounts: [account]).route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'rejects unsafe persisted routing identifiers before sending',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final invalidGroupRig = _Rig(
          now: now,
          accounts: [_account('safe-account', 'codex')],
        );
        final invalidGroup = LlmModelGroup(
          id: 'group id with spaces',
          displayName: 'Invalid group ID',
          members: invalidGroupRig.group.members,
          policy: invalidGroupRig.group.policy,
        );
        var requestInvoked = false;
        await expectLater(
          invalidGroupRig.service.execute(
            group: invalidGroup,
            requestedModelId: 'chat-model',
            estimatedUsage: const {'requests': 1},
            request: (candidate, progress) async {
              requestInvoked = true;
              return candidate.account.id;
            },
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        expect(requestInvoked, isFalse);
        expect((await invalidGroupRig.stateStore.load()).pendingUsage, isEmpty);

        final invalidAccountRig = _Rig(
          now: now,
          accounts: [_account('account id with spaces', 'codex')],
        );
        requestInvoked = false;
        await expectLater(
          invalidAccountRig.route((candidate, progress) async {
            requestInvoked = true;
            return candidate.account.id;
          }),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        expect(requestInvoked, isFalse);
        expect(
          (await invalidAccountRig.stateStore.load()).pendingUsage,
          isEmpty,
        );
      },
    );

    test(
      'does not derive remaining balance from different-time quota snapshots',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final account = _account(
          'snapshot-time-mismatch',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(10, unit: 'credits'),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(
                100,
                'credits',
                now.subtract(const Duration(hours: 1)),
              ),
              used: _metric(80, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        final rig = _Rig(now: now, accounts: [account]);
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        await expectLater(
          rig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'provider quota snapshots require local tracking coverage after observation',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final observedAt = now.subtract(const Duration(hours: 1));
        final trackingStartedAt = now.subtract(const Duration(minutes: 30));
        final reserveRig = _Rig(
          now: now,
          accounts: [
            _account(
              'partially-tracked-reserve',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    reserveFloor: LlmLimitThreshold.fixed(5, unit: 'credits'),
                  ),
                },
              ),
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  remaining: _metric(10, 'credits', observedAt),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
        );
        _seedUsageTracking(reserveRig, trackingStartedAt);
        await expectLater(
          reserveRig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final ceilingRig = _Rig(
          now: now,
          accounts: [
            _account(
              'partially-tracked-ceiling',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    usageCeiling: LlmLimitThreshold.fixed(100, unit: 'credits'),
                  ),
                },
              ),
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  used: _metric(10, 'credits', observedAt),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
        );
        _seedUsageTracking(ceilingRig, trackingStartedAt);
        await expectLater(
          ceilingRig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'account and group fixed and percentage limits are independent',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final account = _account(
          'limited',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.percentage(25),
                usageCeiling: LlmLimitThreshold.fixed(1, unit: 'requests'),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now),
              used: _metric(0, 'credits', now),
              remaining: _metric(26, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        final rig = _Rig(now: now, accounts: [account]);
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        final first = await rig.route((candidate, progress) async {
          await progress.markRequestSent();
          return candidate.account.id;
        }, estimatedUsage: const {'requests': 1, 'credits': 1});
        expect(first.candidate.account.id, 'limited');

        await expectLater(
          rig.route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final belowReserve = _account(
          'below-floor',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.percentage(25),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now),
              remaining: _metric(24, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        await expectLater(
          _Rig(
            now: now,
            accounts: [belowReserve],
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final atReserve = _account(
          'at-floor',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.percentage(25),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now),
              remaining: _metric(25, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        await expectLater(
          _Rig(
            now: now,
            accounts: [atReserve],
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final groupLimitedRig = _Rig(
          now: now,
          accounts: [_account('group-limited', 'codex')],
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.fixed(0, unit: 'requests'),
              ),
            },
          ),
        );
        await expectLater(
          groupLimitedRig.route(
            (candidate, progress) async => candidate.account.id,
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final incompleteUsageAccount = _account(
          'incomplete-usage',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.fixed(1, unit: 'requests'),
              ),
            },
          ),
        );
        await expectLater(
          _Rig(
            now: now,
            accounts: [incompleteUsageAccount],
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final remainingOnlyAccount = _account(
          'remaining-only',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.fixed(50, unit: 'credits'),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now),
              remaining: _metric(20, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        await expectLater(
          _Rig(now: now, accounts: [remainingOnlyAccount]).route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        await expectLater(
          _Rig(
            now: now,
            accounts: [remainingOnlyAccount],
            groupPolicy: LlmRoutingPolicy(
              windows: {
                LlmUsageWindow.day: const LlmWindowPolicy(
                  usageCeiling: LlmLimitThreshold.fixed(50, unit: 'credits'),
                ),
              },
            ),
          ).route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final incomparableSourcesAccount = _account(
          'incomparable-sources',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.percentage(50),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now, source: 'quota-source'),
              used: _metric(49, 'credits', now, source: 'usage-source'),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        await expectLater(
          _Rig(now: now, accounts: [incomparableSourcesAccount]).route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final percentageAccount = _account(
          'percentage-ceiling',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.percentage(50),
                usageCeiling: LlmLimitThreshold.percentage(50),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now),
              used: _metric(49, 'credits', now),
              remaining: _metric(51, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        final percentageAccountRig = _Rig(
          now: now,
          accounts: [percentageAccount],
        );
        final exactAccountLimit = await percentageAccountRig.route((
          candidate,
          progress,
        ) async {
          await progress.markRequestSent();
          await progress.recordUsage(
            unit: 'credits',
            value: 1,
            source: 'codex.response',
          );
          return candidate.account.id;
        }, estimatedUsage: const {'credits': 1});
        expect(exactAccountLimit.candidate.account.id, 'percentage-ceiling');
        await expectLater(
          percentageAccountRig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final groupCeilingRig = _Rig(
          now: now,
          accounts: [
            _account(
              'group-used-a',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(100, 'credits', now, source: 'codex.response'),
                  used: _metric(30, 'credits', now),
                  remaining: _metric(70, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
            _account(
              'group-used-b',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(100, 'credits', now, source: 'codex.response'),
                  used: _metric(30, 'credits', now),
                  remaining: _metric(70, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.percentage(50),
              ),
            },
          ),
        );
        _seedUsageTracking(
          groupCeilingRig,
          now.subtract(const Duration(days: 2)),
          events: [
            for (final accountId in ['group-used-a', 'group-used-b'])
              LlmUsageEvent(
                accountId: accountId,
                groupId: groupCeilingRig.group.id,
                occurredAt: now.subtract(const Duration(minutes: 1)),
                measurements: const [
                  LlmUsageMeasurement(
                    unit: 'credits',
                    value: 30,
                    source: 'codex.response',
                  ),
                ],
              ),
          ],
        );
        final exactGroupLimit = await groupCeilingRig.route((
          candidate,
          progress,
        ) async {
          await progress.markRequestSent();
          await progress.recordUsage(
            unit: 'credits',
            value: 40,
            source: 'codex.response',
          );
          return candidate.account.id;
        }, estimatedUsage: const {'credits': 40});
        expect(exactGroupLimit.value, 'group-used-a');
        await expectLater(
          groupCeilingRig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final sharedAccount = _account(
          'shared',
          'codex',
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(100, 'credits', now),
              used: _metric(80, 'credits', now),
              remaining: _metric(20, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        final isolatedGroupUsageRig = _Rig(
          now: now,
          accounts: [sharedAccount],
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.fixed(50, unit: 'credits'),
              ),
            },
          ),
        );
        _seedUsageTracking(
          isolatedGroupUsageRig,
          now.subtract(const Duration(days: 2)),
        );
        await isolatedGroupUsageRig.stateStore.recordUsage(
          LlmUsageEvent(
            accountId: sharedAccount.id,
            groupId: 'another-group',
            occurredAt: now,
            measurements: const [
              LlmUsageMeasurement(unit: 'credits', value: 10, source: 'local'),
            ],
          ),
        );
        final isolatedGroupRequest = await isolatedGroupUsageRig.route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'credits': 1},
        );
        expect(isolatedGroupRequest.candidate.account.id, sharedAccount.id);
      },
    );

    test('group usage ceiling follows its calendar window', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final rig = _Rig(
        now: now,
        accounts: [_account('calendar-member', 'codex')],
        groupPolicy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: LlmWindowPolicy(
              mode: LlmWindowMode.calendar,
              timeZone: 'America/Los_Angeles',
              usageCeiling: LlmLimitThreshold.fixed(10, unit: 'tokens'),
            ),
          },
        ),
      );
      _seedUsageTracking(
        rig,
        now.subtract(const Duration(days: 40)),
        events: [
          LlmUsageEvent(
            accountId: 'calendar-member',
            groupId: rig.group.id,
            occurredAt: now.subtract(const Duration(minutes: 1)),
            measurements: const [
              LlmUsageMeasurement(unit: 'tokens', value: 4, source: 'local'),
            ],
          ),
        ],
      );

      final routed = await rig.route(
        (candidate, progress) async => candidate.account.id,
        estimatedUsage: const {'requests': 1, 'tokens': 5},
      );
      expect(routed.candidate.account.id, 'calendar-member');
    });

    test('group usage ceiling includes usage from former members', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final rig = _Rig(
        now: now,
        accounts: [_account('current-member', 'codex')],
        groupPolicy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              usageCeiling: LlmLimitThreshold.fixed(10, unit: 'tokens'),
            ),
          },
        ),
      );
      _seedUsageTracking(
        rig,
        now.subtract(const Duration(days: 2)),
        events: [
          LlmUsageEvent(
            accountId: 'former-member',
            groupId: rig.group.id,
            occurredAt: now.subtract(const Duration(minutes: 1)),
            measurements: const [
              LlmUsageMeasurement(unit: 'tokens', value: 6, source: 'local'),
            ],
          ),
        ],
      );

      await expectLater(
        rig.route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'tokens': 5},
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );
    });

    test(
      'group reserve refuses missing or incomparable member totals',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final groupPolicy = LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.fixed(1, unit: 'credits'),
            ),
          },
        );
        final accounts = [
          _account(
            'first',
            'codex',
            usage: {
              LlmUsageWindow.day: LlmUsageWindowState(
                quota: _metric(10, 'credits', now, source: 'provider-a'),
                remaining: _metric(5, 'credits', now, source: 'provider-a'),
                resetAt: now.add(const Duration(hours: 12)),
              ),
            },
          ),
          _account(
            'second',
            'claude',
            usage: {
              LlmUsageWindow.day: LlmUsageWindowState(
                quota: _metric(10, 'requests', now, source: 'provider-b'),
                remaining: _metric(5, 'requests', now, source: 'provider-b'),
                resetAt: now.add(const Duration(hours: 12)),
              ),
            },
          ),
        ];

        await expectLater(
          _Rig(
            now: now,
            accounts: accounts,
            groupPolicy: groupPolicy,
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final equalToGroupFloor = _Rig(
          now: now,
          accounts: [
            _account(
              'group-floor-a',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(10, 'credits', now),
                  remaining: _metric(5, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
            _account(
              'group-floor-b',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(10, 'credits', now),
                  remaining: _metric(5, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(10, unit: 'credits'),
              ),
            },
          ),
        );
        await expectLater(
          equalToGroupFloor.route(
            (candidate, progress) async => candidate.account.id,
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        await expectLater(
          _Rig(
            now: now,
            accounts: accounts,
            groupMembers: [
              ('first', 'codex-model', 0),
              ('second', 'claude-model', 0),
              ('missing', 'missing-model', 0),
            ],
            groupPolicy: groupPolicy,
          ).route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'group percentage totals require same-time member snapshots',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final accounts = [
          _account(
            'group-time-a',
            'codex',
            usage: {
              LlmUsageWindow.day: LlmUsageWindowState(
                quota: _metric(
                  100,
                  'credits',
                  now.subtract(const Duration(minutes: 30)),
                ),
                remaining: _metric(
                  80,
                  'credits',
                  now.subtract(const Duration(minutes: 30)),
                ),
                resetAt: now.add(const Duration(hours: 12)),
              ),
            },
          ),
          _account(
            'group-time-b',
            'codex',
            usage: {
              LlmUsageWindow.day: LlmUsageWindowState(
                quota: _metric(
                  100,
                  'credits',
                  now.subtract(const Duration(minutes: 5)),
                ),
                remaining: _metric(
                  80,
                  'credits',
                  now.subtract(const Duration(minutes: 5)),
                ),
                resetAt: now.add(const Duration(hours: 12)),
              ),
            },
          ),
        ];
        final rig = _Rig(
          now: now,
          accounts: accounts,
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.percentage(50),
              ),
            },
          ),
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        await expectLater(
          rig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'group percentage ceilings reject member totals observed at different times',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'group-ceiling-time-a',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(
                    100,
                    'credits',
                    now.subtract(const Duration(minutes: 30)),
                  ),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
            _account(
              'group-ceiling-time-b',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(
                    100,
                    'credits',
                    now.subtract(const Duration(minutes: 5)),
                  ),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.percentage(100),
              ),
            },
          ),
        );
        _seedUsageTracking(
          rig,
          now.subtract(const Duration(days: 2)),
          events: [
            LlmUsageEvent(
              accountId: 'group-ceiling-time-a',
              groupId: rig.group.id,
              occurredAt: now.subtract(const Duration(minutes: 1)),
              measurements: const [
                LlmUsageMeasurement(
                  unit: 'credits',
                  value: 0,
                  source: 'provider',
                ),
              ],
            ),
          ],
        );

        await expectLater(
          rig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test('percentage reserve floors require matching usage sources', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final accountWindow = {
        LlmUsageWindow.day: LlmUsageWindowState(
          quota: _metric(20, 'credits', now, source: 'quota-source'),
          remaining: _metric(100, 'credits', now, source: 'balance-source'),
          resetAt: now.add(const Duration(hours: 12)),
        ),
      };
      final accountPolicy = LlmRoutingPolicy(
        windows: {
          LlmUsageWindow.day: const LlmWindowPolicy(
            reserveFloor: LlmLimitThreshold.percentage(50),
          ),
        },
      );
      await expectLater(
        _Rig(
          now: now,
          accounts: [
            _account(
              'account-source-mismatch',
              'codex',
              policy: accountPolicy,
              usage: accountWindow,
            ),
          ],
        ).route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'credits': 1},
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );

      await expectLater(
        _Rig(
          now: now,
          accounts: [
            _account('group-source-mismatch', 'codex', usage: accountWindow),
          ],
          groupPolicy: accountPolicy,
        ).route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'credits': 1},
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );
    });

    test(
      'percentage reserve totals require a same-time remaining and used snapshot',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final usage = {
          LlmUsageWindow.day: LlmUsageWindowState(
            remaining: _metric(40, 'credits', now),
            used: _metric(
              10,
              'credits',
              now.subtract(const Duration(hours: 1)),
            ),
            resetAt: now.add(const Duration(hours: 12)),
          ),
        };
        final reservePolicy = LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.percentage(50),
            ),
          },
        );

        for (final scope in ['account', 'group']) {
          final rig = _Rig(
            now: now,
            accounts: [
              _account(
                'time-mismatch-$scope',
                'codex',
                policy: scope == 'account' ? reservePolicy : null,
                usage: usage,
              ),
            ],
            groupPolicy: scope == 'group' ? reservePolicy : null,
          );
          _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

          await expectLater(
            rig.route(
              (candidate, progress) async => candidate.account.id,
              estimatedUsage: const {'requests': 1, 'credits': 10},
            ),
            throwsA(isA<LlmRoutingUnavailableException>()),
            reason: scope,
          );
        }
      },
    );

    test(
      'percentage limits reject quota snapshots older than paired metrics',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final earlier = now.subtract(const Duration(minutes: 30));
        final resetAt = now.add(const Duration(hours: 12));
        final reservePolicy = LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.percentage(50),
            ),
          },
        );
        final ceilingPolicy = LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              usageCeiling: LlmLimitThreshold.percentage(50),
            ),
          },
        );

        for (final scope in ['account', 'group']) {
          final rig = _Rig(
            now: now,
            accounts: [
              _account(
                'reserve-time-$scope',
                'codex',
                policy: scope == 'account' ? reservePolicy : null,
                usage: {
                  LlmUsageWindow.day: LlmUsageWindowState(
                    quota: _metric(100, 'credits', earlier),
                    remaining: _metric(90, 'credits', now),
                    resetAt: resetAt,
                  ),
                },
              ),
            ],
            groupPolicy: scope == 'group' ? reservePolicy : null,
          );
          _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

          await expectLater(
            rig.route(
              (candidate, progress) async => candidate.account.id,
              estimatedUsage: const {'requests': 1, 'credits': 1},
            ),
            throwsA(isA<LlmRoutingUnavailableException>()),
            reason: '$scope reserve',
          );

          final ceilingRig = _Rig(
            now: now,
            accounts: [
              _account(
                'ceiling-time-$scope',
                'codex',
                policy: scope == 'account' ? ceilingPolicy : null,
                usage: {
                  LlmUsageWindow.day: LlmUsageWindowState(
                    quota: _metric(100, 'credits', earlier),
                    used: scope == 'account'
                        ? _metric(40, 'credits', now)
                        : const LlmMetricObservation.unknown(),
                    resetAt: resetAt,
                  ),
                },
              ),
            ],
            groupPolicy: scope == 'group' ? ceilingPolicy : null,
          );
          _seedUsageTracking(
            ceilingRig,
            now.subtract(const Duration(days: 2)),
            events: scope == 'group'
                ? [
                    LlmUsageEvent(
                      accountId: 'ceiling-time-group',
                      groupId: ceilingRig.group.id,
                      occurredAt: now.subtract(const Duration(minutes: 1)),
                      measurements: const [
                        LlmUsageMeasurement(
                          unit: 'credits',
                          value: 40,
                          source: 'provider',
                        ),
                      ],
                    ),
                  ]
                : const [],
          );

          await expectLater(
            ceilingRig.route(
              (candidate, progress) async => candidate.account.id,
              estimatedUsage: const {'requests': 1, 'credits': 1},
            ),
            throwsA(isA<LlmRoutingUnavailableException>()),
            reason: '$scope ceiling',
          );
        }
      },
    );

    test('balance derivations require a same-time quota snapshot', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final reserveAccount = _account(
        'mismatched-reserve',
        'codex',
        policy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.fixed(50, unit: 'credits'),
            ),
          },
        ),
        usage: {
          LlmUsageWindow.day: LlmUsageWindowState(
            quota: _metric(
              100,
              'credits',
              now.subtract(const Duration(hours: 2)),
            ),
            remaining: _metric(
              80,
              'credits',
              now.subtract(const Duration(hours: 2)),
            ),
            used: _metric(
              10,
              'credits',
              now.subtract(const Duration(minutes: 5)),
            ),
            resetAt: now.add(const Duration(hours: 12)),
          ),
        },
      );
      await expectLater(
        _Rig(now: now, accounts: [reserveAccount]).route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'credits': 1},
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );

      final ceilingAccount = _account(
        'mismatched-ceiling',
        'codex',
        policy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              usageCeiling: LlmLimitThreshold.fixed(50, unit: 'credits'),
            ),
          },
        ),
        usage: {
          LlmUsageWindow.day: LlmUsageWindowState(
            quota: _metric(
              100,
              'credits',
              now.subtract(const Duration(hours: 2)),
            ),
            remaining: _metric(90, 'credits', now),
            resetAt: now.add(const Duration(hours: 12)),
          ),
        },
      );
      final ceilingRig = _Rig(now: now, accounts: [ceilingAccount]);
      _seedUsageTracking(ceilingRig, now.subtract(const Duration(hours: 1)));
      await expectLater(
        ceilingRig.route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'credits': 5},
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );
    });

    test('percentage thresholds stay finite for large known totals', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final account = _account(
        'large-quota',
        'codex',
        policy: LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              usageCeiling: LlmLimitThreshold.percentage(100),
            ),
          },
        ),
        usage: {
          LlmUsageWindow.day: LlmUsageWindowState(
            quota: _metric(1e308, 'credits', now),
            used: _metric(1e308, 'credits', now),
            resetAt: now.add(const Duration(hours: 12)),
          ),
        },
      );
      final rig = _Rig(now: now, accounts: [account]);
      _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

      await expectLater(
        rig.route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'credits': 1e308},
        ),
        throwsA(isA<LlmRoutingUnavailableException>()),
      );
    });

    test(
      'percentage reserve floors stay finite under balance ranking',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final policy = LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.percentage(50),
            ),
          },
        );
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'large-reserve',
              'codex',
              policy: policy,
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(1e308, 'credits', now),
                  remaining: _metric(9e307, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
            _account(
              'small-reserve',
              'codex',
              policy: policy,
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(100, 'credits', now),
                  remaining: _metric(80, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
          strategy: LlmSelectionStrategy.balanceHigher,
        );

        final selected = await rig.route(
          (candidate, progress) async => candidate.account.id,
          estimatedUsage: const {'requests': 1, 'credits': 1e307},
        );

        expect(selected.candidate.account.id, 'large-reserve');
      },
    );

    test(
      'reserve floors reject a request without a positive unit estimate',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final account = _account(
          'unknown-estimate',
          'codex',
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(5, unit: 'credits'),
              ),
            },
          ),
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(20, 'credits', now),
              remaining: _metric(10, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        await expectLater(
          _Rig(now: now, accounts: [account]).route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final groupAccount = _account(
          'group-unknown-estimate',
          'codex',
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(20, 'credits', now),
              remaining: _metric(10, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        await expectLater(
          _Rig(
            now: now,
            accounts: [groupAccount],
            groupPolicy: LlmRoutingPolicy(
              windows: {
                LlmUsageWindow.day: const LlmWindowPolicy(
                  reserveFloor: LlmLimitThreshold.fixed(5, unit: 'credits'),
                ),
              },
            ),
          ).route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );
  });

  group('LlmRoutingService selection and fallback', () {
    test(
      'keeps the best eligible tier and applies each same-tier strategy',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final leastUsed = _Rig(
          now: now,
          accounts: [
            _account('a', 'codex'),
            _account('b', 'codex'),
            _account('lower', 'codex'),
          ],
          groupMembers: [
            ('a', 'codex-model', 0),
            ('b', 'codex-model', 0),
            ('lower', 'codex-model', 1),
          ],
        );
        await leastUsed.stateStore.recordUsage(
          LlmUsageEvent(
            accountId: 'a',
            groupId: leastUsed.group.id,
            occurredAt: now.subtract(const Duration(minutes: 1)),
            measurements: const [
              LlmUsageMeasurement(unit: 'requests', value: 1, source: 'local'),
            ],
          ),
        );
        final selectedLeastUsed = await leastUsed.route(
          (candidate, progress) async => candidate.account.id,
        );
        expect(selectedLeastUsed.candidate.account.id, 'b');

        final roundRobin = _Rig(
          now: now,
          accounts: [_account('rr-a', 'codex'), _account('rr-b', 'codex')],
          strategy: LlmSelectionStrategy.roundRobin,
        );
        final rrFirst = await roundRobin.route(
          (candidate, progress) async => candidate.account.id,
        );
        final rrSecond = await roundRobin.route(
          (candidate, progress) async => candidate.account.id,
        );
        expect(
          [rrFirst.candidate.account.id, rrSecond.candidate.account.id],
          ['rr-a', 'rr-b'],
        );

        final balanceAccounts = [
          _account(
            'low',
            'codex',
            usage: {
              LlmUsageWindow.day: LlmUsageWindowState(
                quota: _metric(100, 'credits', now),
                remaining: _metric(20, 'credits', now),
                resetAt: now.add(const Duration(hours: 12)),
              ),
            },
          ),
          _account(
            'high',
            'codex',
            usage: {
              LlmUsageWindow.day: LlmUsageWindowState(
                quota: _metric(100, 'credits', now),
                remaining: _metric(80, 'credits', now),
                resetAt: now.add(const Duration(hours: 12)),
              ),
            },
          ),
        ];
        final preferHigh = await _Rig(
          now: now,
          accounts: balanceAccounts,
          strategy: LlmSelectionStrategy.balanceHigher,
        ).route((candidate, progress) async => candidate.account.id);
        expect(preferHigh.candidate.account.id, 'high');

        final consumeLow = await _Rig(
          now: now,
          accounts: balanceAccounts,
          strategy: LlmSelectionStrategy.balanceLower,
        ).route((candidate, progress) async => candidate.account.id);
        expect(consumeLow.candidate.account.id, 'low');

        final balanceLowerAtFloor =
            await _Rig(
              now: now,
              accounts: [
                _account(
                  'balance-lower-at-floor',
                  'codex',
                  policy: LlmRoutingPolicy(
                    windows: {
                      LlmUsageWindow.day: const LlmWindowPolicy(
                        reserveFloor: LlmLimitThreshold.fixed(
                          25,
                          unit: 'credits',
                        ),
                      ),
                    },
                  ),
                  usage: {
                    LlmUsageWindow.day: LlmUsageWindowState(
                      quota: _metric(100, 'credits', now),
                      remaining: _metric(26, 'credits', now),
                      resetAt: now.add(const Duration(hours: 12)),
                    ),
                  },
                ),
              ],
              strategy: LlmSelectionStrategy.balanceLower,
            ).route(
              (candidate, progress) async => candidate.account.id,
              estimatedUsage: const {'credits': 1},
            );
        expect(
          balanceLowerAtFloor.candidate.account.id,
          'balance-lower-at-floor',
        );

        for (final strategy in [
          LlmSelectionStrategy.balanceHigher,
          LlmSelectionStrategy.balanceLower,
        ]) {
          final nonnegativeBalance = await _Rig(
            now: now,
            accounts: [
              _account(
                'depleted',
                'codex',
                usage: {
                  LlmUsageWindow.day: LlmUsageWindowState(
                    quota: _metric(100, 'credits', now),
                    used: _metric(101, 'credits', now),
                    resetAt: now.add(const Duration(hours: 12)),
                  ),
                },
              ),
              _account(
                'healthy',
                'codex',
                usage: {
                  LlmUsageWindow.day: LlmUsageWindowState(
                    quota: _metric(100, 'credits', now),
                    remaining: _metric(80, 'credits', now),
                    resetAt: now.add(const Duration(hours: 12)),
                  ),
                },
              ),
            ],
            strategy: strategy,
          ).route((candidate, progress) async => candidate.account.id);
          expect(nonnegativeBalance.candidate.account.id, 'healthy');
        }

        final unknownPriorityRig = _Rig(
          now: now,
          accounts: [
            _account('unknown-priority', 'codex'),
            _account(
              'known-lower-priority',
              'codex',
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(100, 'credits', now),
                  remaining: _metric(50, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
          groupMembers: [
            ('unknown-priority', 'codex-model', 0),
            ('known-lower-priority', 'codex-model', 1),
          ],
          strategy: LlmSelectionStrategy.balanceHigher,
        );
        await expectLater(
          unknownPriorityRig.route(
            (candidate, progress) async => candidate.account.id,
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        final incompatibleWindowAccounts = [
          for (final entry in [
            ('rolling', LlmWindowMode.rolling),
            ('calendar', LlmWindowMode.calendar),
          ])
            _account(
              entry.$1,
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: LlmWindowPolicy(
                    mode: entry.$2,
                    timeZone: entry.$2 == LlmWindowMode.calendar
                        ? 'America/Los_Angeles'
                        : null,
                  ),
                },
              ),
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(100, 'credits', now),
                  remaining: _metric(
                    entry.$1 == 'rolling' ? 20 : 80,
                    'credits',
                    now,
                  ),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
        ];
        final incompatibleRig = _Rig(
          now: now,
          accounts: incompatibleWindowAccounts,
          strategy: LlmSelectionStrategy.balanceHigher,
        );
        await expectLater(
          incompatibleRig.route(
            (candidate, progress) async => candidate.account.id,
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'fallback respects provider scope, group membership, and model mapping',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'primary',
              'openai-compatibility',
              upstreamModel: 'gpt-4o',
            ),
            _account(
              'other-provider',
              'claude',
              upstreamModel: 'claude-sonnet',
            ),
            _account(
              'same-provider',
              'openai-compatibility',
              upstreamModel: 'gpt-4.1',
            ),
            _account(
              'outside-group',
              'openai-compatibility',
              upstreamModel: 'gpt-4o',
            ),
          ],
          groupMembers: [
            ('primary', 'gpt-4o', 0),
            ('other-provider', 'claude-sonnet', 0),
            ('same-provider', 'gpt-4.1', 0),
          ],
          fallbackScope: LlmFallbackScope.account,
        );
        final attempted = <String>[];
        final result = await rig.route((candidate, progress) async {
          attempted.add(candidate.account.id);
          expect(candidate.localModelId, 'chat-model');
          if (candidate.account.id == 'primary') {
            throw const LlmRouteRequestException(statusCode: 503);
          }
          await progress.markRequestSent();
          return candidate.account.id;
        });

        expect(attempted, ['primary', 'same-provider']);
        expect(result.candidate.upstreamModelId, 'gpt-4.1');
        expect(attempted, isNot(contains('other-provider')));
        expect(attempted, isNot(contains('outside-group')));

        final groupScope = _Rig(
          now: now,
          accounts: [
            _account(
              'primary-2',
              'openai-compatibility',
              upstreamModel: 'gpt-4o',
            ),
            _account(
              'claude-fallback',
              'claude',
              upstreamModel: 'claude-sonnet',
            ),
          ],
          groupMembers: [
            ('primary-2', 'gpt-4o', 0),
            ('claude-fallback', 'claude-sonnet', 0),
          ],
          fallbackScope: LlmFallbackScope.modelGroup,
        );
        final groupAttempts = <String>[];
        await groupScope.route((candidate, progress) async {
          groupAttempts.add(candidate.account.id);
          if (candidate.account.id == 'primary-2') {
            throw const LlmRouteRequestException(statusCode: 503);
          }
          return candidate.account.id;
        });
        expect(groupAttempts, ['primary-2', 'claude-fallback']);
      },
    );

    test(
      'does not replay ambiguous server or connection failures after sending',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final serverRig = _Rig(
          now: now,
          accounts: [
            _account('server-first', 'codex'),
            _account('server-next', 'codex'),
          ],
        );
        final serverAttempts = <String>[];
        await expectLater(
          serverRig.route((candidate, progress) async {
            serverAttempts.add(candidate.account.id);
            await progress.markRequestSent();
            throw const LlmRouteRequestException(statusCode: 503);
          }),
          throwsA(isA<LlmRouteRequestException>()),
        );
        expect(serverAttempts, ['server-first']);

        final connectionRig = _Rig(
          now: now,
          accounts: [
            _account('connection-first', 'codex'),
            _account('connection-next', 'codex'),
          ],
        );
        final connectionAttempts = <String>[];
        await expectLater(
          connectionRig.route((candidate, progress) async {
            connectionAttempts.add(candidate.account.id);
            await progress.markRequestSent();
            throw DioException(
              requestOptions: RequestOptions(path: '/'),
              type: DioExceptionType.receiveTimeout,
            );
          }),
          throwsA(isA<DioException>()),
        );
        expect(connectionAttempts, ['connection-first']);
      },
    );

    test(
      'classifies retry failures and honors Retry-After and reset hints',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final resetAt = now.add(const Duration(minutes: 3));
        final failure = const LlmRouteRequestException(
          statusCode: 429,
          headers: {'Retry-After': '60'},
        );
        final classification = LlmRequestErrorClassifier.classify(
          failure,
          now: now,
          resetAt: resetAt,
        );
        expect(classification.kind, LlmRequestFailureKind.rateLimited);
        expect(classification.retryable, isTrue);
        expect(classification.cooldownUntil, resetAt);

        final latestReset = LlmRequestErrorClassifier.classify(
          LlmRouteRequestException(
            statusCode: 429,
            headers: {
              'x-rate-limit-reset':
                  '${now.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000}',
              'x-quota-reset':
                  '${now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000}',
            },
          ),
          now: now,
        );
        expect(latestReset.cooldownUntil, now.add(const Duration(minutes: 5)));

        final malformedReset = LlmRequestErrorClassifier.classify(
          const LlmRouteRequestException(
            statusCode: 429,
            headers: {'x-ratelimit-reset': '1e300'},
          ),
          now: now,
        );
        expect(
          malformedReset.cooldownUntil,
          now.add(const Duration(minutes: 1)),
        );

        final malformedRetryAfter = LlmRequestErrorClassifier.classify(
          const LlmRouteRequestException(
            statusCode: 429,
            headers: {'retry-after': '9000000000000'},
          ),
          now: now,
        );
        expect(
          malformedRetryAfter.cooldownUntil,
          now.add(const Duration(minutes: 1)),
        );

        final immediateRetry = LlmRequestErrorClassifier.classify(
          const LlmRouteRequestException(
            statusCode: 429,
            headers: {'Retry-After': '0'},
          ),
          now: now,
        );
        expect(immediateRetry.cooldownUntil, now);

        final pastRetryDate = LlmRequestErrorClassifier.classify(
          const LlmRouteRequestException(
            statusCode: 429,
            headers: {'Retry-After': 'Sun, 18 Oct 2026 11:59:00 GMT'},
          ),
          now: now,
        );
        expect(pastRetryDate.cooldownUntil, now);

        expect(
          LlmRequestErrorClassifier.classify(
            const LlmRouteRequestException(
              statusCode: 429,
              code: 'insufficient_quota',
            ),
            now: now,
          ).kind,
          LlmRequestFailureKind.quotaExhausted,
        );

        expect(
          LlmRequestErrorClassifier.classify(
            const LlmRouteRequestException(statusCode: 401),
            now: now,
          ).kind,
          LlmRequestFailureKind.authentication,
        );
        expect(
          LlmRequestErrorClassifier.classify(
            const LlmRouteRequestException(
              statusCode: 403,
              code: 'insufficient_quota',
            ),
            now: now,
          ).kind,
          LlmRequestFailureKind.quotaExhausted,
        );
        expect(
          LlmRequestErrorClassifier.classify(
            const LlmRouteRequestException(statusCode: 400),
            now: now,
          ).retryable,
          isFalse,
        );
        expect(
          LlmRequestErrorClassifier.classify(
            DioException(
              requestOptions: RequestOptions(path: '/'),
              type: DioExceptionType.connectionTimeout,
            ),
            now: now,
          ).kind,
          LlmRequestFailureKind.connection,
        );

        final rig = _Rig(
          now: now,
          accounts: [_account('limited', 'codex'), _account('next', 'codex')],
        );
        await rig.route((candidate, progress) async {
          if (candidate.account.id == 'limited') {
            await progress.markRequestSent();
            throw const LlmRouteRequestException(
              statusCode: 429,
              headers: {'retry-after': '60'},
            );
          }
          return candidate.account.id;
        });
        final state = await rig.stateStore.load();
        expect(
          state.cooldowns['limited']!.until,
          now.add(const Duration(seconds: 60)),
        );

        final authFallback = _Rig(
          now: now,
          accounts: [
            _account('rejected', 'codex'),
            _account('auth-next', 'codex'),
          ],
        );
        final authAttempts = <String>[];
        await authFallback.route((candidate, progress) async {
          authAttempts.add(candidate.account.id);
          if (candidate.account.id == 'rejected') {
            await progress.markRequestSent();
            throw const LlmRouteRequestException(statusCode: 401);
          }
          return candidate.account.id;
        });
        expect(authAttempts, ['rejected', 'auth-next']);

        final invalidRequestRig = _Rig(
          now: now,
          accounts: [
            _account('invalid-first', 'codex'),
            _account('invalid-next', 'codex'),
          ],
        );
        final invalidAttempts = <String>[];
        await expectLater(
          invalidRequestRig.route((candidate, progress) async {
            invalidAttempts.add(candidate.account.id);
            throw const LlmRouteRequestException(statusCode: 400);
          }),
          throwsA(isA<LlmRouteRequestException>()),
        );
        expect(invalidAttempts, ['invalid-first']);
      },
    );

    test(
      'keeps an account cooled down when cooldown persistence fails',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(now: now, accounts: [_account('limited', 'codex')]);
        final attempted = <String>[];

        await expectLater(
          rig.route((candidate, progress) async {
            attempted.add(candidate.account.id);
            await progress.markRequestSent();
            // Cooldown is written before request usage and marker cleanup.
            rig.preferences.failRoutingStateWriteAfter(0);
            throw const LlmRouteRequestException(
              statusCode: 429,
              headers: {'retry-after': '60'},
            );
          }),
          throwsA(isA<LlmRoutingStateException>()),
        );
        expect(attempted, ['limited']);

        await expectLater(
          rig.route((candidate, progress) async {
            attempted.add(candidate.account.id);
            return candidate.account.id;
          }),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        expect(attempted, ['limited']);

        final nextService = LlmRoutingService(
          accountService: rig.accounts,
          stateStore: LlmRoutingStateStore(
            preferences: rig.preferences,
            clock: () => rig.now,
          ),
          clock: () => rig.now,
          concurrency: rig.service.concurrency,
        );
        await expectLater(
          nextService.execute(
            group: rig.group,
            requestedModelId: 'chat-model',
            request: (candidate, progress) async {
              attempted.add(candidate.account.id);
              return candidate.account.id;
            },
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        expect(attempted, ['limited']);
      },
    );

    test(
      'records cooldown when usage or pending-marker cleanup fails',
      () async {
        for (final writesBeforeFailure in [1, 2]) {
          final rig = _Rig(
            now: DateTime.utc(2026, 10, 18, 12),
            accounts: [
              _account('cleanup-limited-$writesBeforeFailure', 'codex'),
            ],
          );
          final attempted = <String>[];

          await expectLater(
            rig.route((candidate, progress) async {
              attempted.add(candidate.account.id);
              await progress.markRequestSent();
              rig.preferences.failRoutingStateWriteAfter(writesBeforeFailure);
              throw const LlmRouteRequestException(
                statusCode: 429,
                headers: {'retry-after': '60'},
              );
            }),
            throwsA(isA<LlmRoutingStateException>()),
          );
          expect(attempted, ['cleanup-limited-$writesBeforeFailure']);

          await expectLater(
            rig.route((candidate, progress) async {
              attempted.add(candidate.account.id);
              return candidate.account.id;
            }),
            throwsA(isA<LlmRoutingUnavailableException>()),
          );
          expect(attempted, ['cleanup-limited-$writesBeforeFailure']);
        }
      },
    );

    test(
      'does not retry after visible stream output or a tool side effect',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        for (final mark in <Future<void> Function(LlmRouteProgress)>[
          (progress) => progress.markOutputVisible(),
          (progress) => progress.markToolSideEffect(),
        ]) {
          final rig = _Rig(
            now: now,
            accounts: [_account('first', 'codex'), _account('second', 'codex')],
          );
          final attempts = <String>[];
          await expectLater(
            rig.route((candidate, progress) async {
              attempts.add(candidate.account.id);
              await progress.markRequestSent();
              await mark(progress);
              throw const LlmRouteRequestException(statusCode: 503);
            }),
            throwsA(isA<LlmRouteRequestException>()),
          );
          expect(attempts, hasLength(1));
        }
      },
    );
  });

  group('LlmRoutingService reservations and local usage', () {
    test(
      'rejects usage estimate keys that normalize to the same unit',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(now: now, accounts: [_account('account', 'codex')]);
        var requestInvoked = false;

        await expectLater(
          rig.route((candidate, progress) async {
            requestInvoked = true;
            return candidate.account.id;
          }, estimatedUsage: const {'credits': 10, ' credits ': 0}),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        expect(requestInvoked, isFalse);
      },
    );

    test(
      'atomically reserves group/account capacity under concurrent calls',
      () async {
        final rig = _Rig(
          now: DateTime.utc(2026, 10, 18, 12),
          accounts: [
            _account(
              'one-slot',
              'codex',
              policy: LlmRoutingPolicy(concurrencyLimit: 1),
            ),
          ],
          groupPolicy: LlmRoutingPolicy(concurrencyLimit: 1),
        );
        final entered = Completer<void>();
        final finish = Completer<void>();
        final first = rig.route((candidate, progress) async {
          await progress.markRequestSent();
          entered.complete();
          await finish.future;
          return candidate.account.id;
        });
        await entered.future;

        await expectLater(
          rig.route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        finish.complete();
        await first;

        final afterRelease = await rig.route(
          (candidate, progress) async => candidate.account.id,
        );
        expect(afterRelease.candidate.account.id, 'one-slot');
      },
    );

    test(
      'write-ahead usage markers allow concurrent reservations within a ceiling',
      () async {
        final rig = _Rig(
          now: DateTime.utc(2026, 10, 18, 12),
          accounts: [_account('two-slots', 'codex')],
          groupPolicy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.fixed(2, unit: 'requests'),
              ),
            },
          ),
        );
        _seedUsageTracking(rig, rig.now.subtract(const Duration(days: 2)));
        final entered = Completer<void>();
        final finish = Completer<void>();
        final first = rig.route((candidate, progress) async {
          await progress.markRequestSent();
          entered.complete();
          await finish.future;
          return candidate.account.id;
        });
        await entered.future;

        final second = await rig.route((candidate, progress) async {
          await progress.markRequestSent();
          return candidate.account.id;
        });
        expect(second.candidate.account.id, 'two-slots');

        finish.complete();
        await first;
        final state = await rig.stateStore.load();
        expect(state.events, hasLength(2));
        expect(state.pendingUsage, isEmpty);
      },
    );

    test(
      'unknown active usage cannot be ignored by account or group ceilings',
      () async {
        for (final scope in ['account', 'group']) {
          final now = DateTime.utc(2026, 10, 18, 12);
          final ceiling = LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                usageCeiling: LlmLimitThreshold.fixed(10, unit: 'tokens'),
              ),
            },
          );
          final rig = _Rig(
            now: now,
            accounts: [
              _account(
                'unknown-active-$scope',
                'codex',
                policy: scope == 'account' ? ceiling : null,
              ),
            ],
            groupPolicy: scope == 'group' ? ceiling : null,
          );
          _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));
          final entered = Completer<void>();
          final finish = Completer<void>();
          final first = rig.route((candidate, progress) async {
            await progress.markRequestSent();
            entered.complete();
            await finish.future;
            return candidate.account.id;
          }, estimatedUsage: const {'requests': 1, 'tokens': 0});
          await entered.future;

          await expectLater(
            rig.route(
              (candidate, progress) async => candidate.account.id,
              estimatedUsage: const {'requests': 1, 'tokens': 10},
            ),
            throwsA(isA<LlmRoutingUnavailableException>()),
          );

          finish.complete();
          await first;
        }
      },
    );

    test(
      'does not admit against a usage snapshot read before another route completes',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'usage-limited',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    usageCeiling: LlmLimitThreshold.fixed(1, unit: 'requests'),
                  ),
                },
              ),
            ),
          ],
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        final firstEntered = Completer<void>();
        final finishFirst = Completer<void>();
        final first = rig.route((candidate, progress) async {
          await progress.markRequestSent();
          firstEntered.complete();
          await finishFirst.future;
          return candidate.account.id;
        });
        await firstEntered.future;

        rig.preferences.pauseNextRoutingStateRead();
        final staleReadEntered = rig.preferences.routingStateReadPaused;
        final second = rig.route(
          (candidate, progress) async => candidate.account.id,
        );
        final secondDenied = expectLater(
          second,
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        await staleReadEntered;

        // The second route has captured the pre-request usage snapshot while
        // holding the shared preference transaction. Finish the first request
        // before allowing that stale snapshot to continue to selection.
        finishFirst.complete();
        await Future<void>.delayed(Duration.zero);
        rig.preferences.resumeRoutingStateRead();

        await first;
        await secondDenied;
      },
    );

    test(
      'counts estimated usage reservations against an account floor',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'reserved-balance',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    reserveFloor: LlmLimitThreshold.fixed(1, unit: 'credits'),
                  ),
                },
              ),
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(20, 'credits', now),
                  remaining: _metric(10, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
        );
        final entered = Completer<void>();
        final finish = Completer<void>();
        final first = rig.route((candidate, progress) async {
          await progress.markRequestSent();
          entered.complete();
          await finish.future;
          return candidate.account.id;
        }, estimatedUsage: const {'requests': 1, 'credits': 6});
        await entered.future;
        await expectLater(
          rig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 4},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
        finish.complete();
        await first;
      },
    );

    test(
      'a group reserve sees unknown usage on an overlapping active account',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final sharedAccount = _account(
          'active-unknown',
          'codex',
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(20, 'credits', now),
              remaining: _metric(10, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        final rig = _Rig(now: now, accounts: [sharedAccount]);
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));
        final entered = Completer<void>();
        final finish = Completer<void>();
        final first = rig.route((candidate, progress) async {
          await progress.markRequestSent();
          entered.complete();
          await finish.future;
          return candidate.account.id;
        });
        await entered.future;

        final reserveGroup = LlmModelGroup(
          id: 'reserve-group',
          displayName: 'Reserve group',
          members: [
            LlmModelGroupMember(
              accountId: sharedAccount.id,
              upstreamModelId: sharedAccount.models.single.upstreamModelId,
              localModelId: 'chat-model',
            ),
          ],
          policy: LlmRoutingPolicy(
            windows: {
              LlmUsageWindow.day: const LlmWindowPolicy(
                reserveFloor: LlmLimitThreshold.fixed(5, unit: 'credits'),
              ),
            },
          ),
        );
        final reserveService = LlmRoutingService(
          accountService: rig.accounts,
          stateStore: rig.stateStore,
          clock: () => rig.now,
          concurrency: rig.service.concurrency,
          roundRobin: LlmRoundRobinCursor(),
        );
        await expectLater(
          reserveService.execute(
            group: reserveGroup,
            requestedModelId: 'chat-model',
            estimatedUsage: const {'requests': 1, 'credits': 1},
            request: (candidate, progress) async => candidate.account.id,
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        finish.complete();
        await first;
      },
    );

    test(
      'unknown per-request token usage cannot be treated as zero under a ceiling',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'token-limited',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    usageCeiling: LlmLimitThreshold.fixed(10, unit: 'tokens'),
                  ),
                },
              ),
            ),
          ],
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        await rig.route((candidate, progress) async {
          await progress.markRequestSent();
          return candidate.account.id;
        }, estimatedUsage: const {'requests': 1, 'tokens': 4});

        await expectLater(
          rig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'tokens': 5},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'unknown per-request credit usage cannot be treated as zero under a reserve',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'credit-reserved',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    reserveFloor: LlmLimitThreshold.fixed(10, unit: 'credits'),
                  ),
                },
              ),
              usage: {
                LlmUsageWindow.day: LlmUsageWindowState(
                  quota: _metric(100, 'credits', now),
                  remaining: _metric(20, 'credits', now),
                  resetAt: now.add(const Duration(hours: 12)),
                ),
              },
            ),
          ],
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        await rig.route((candidate, progress) async {
          await progress.markRequestSent();
          return candidate.account.id;
        }, estimatedUsage: const {'requests': 1, 'credits': 5});

        await expectLater(
          rig.route(
            (candidate, progress) async => candidate.account.id,
            estimatedUsage: const {'requests': 1, 'credits': 6},
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'shared-account reservations count toward every group reserve',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final groupPolicy = LlmRoutingPolicy(
          windows: {
            LlmUsageWindow.day: const LlmWindowPolicy(
              reserveFloor: LlmLimitThreshold.fixed(5, unit: 'credits'),
            ),
          },
        );
        final sharedAccount = _account(
          'shared',
          'codex',
          usage: {
            LlmUsageWindow.day: LlmUsageWindowState(
              quota: _metric(20, 'credits', now),
              remaining: _metric(10, 'credits', now),
              resetAt: now.add(const Duration(hours: 12)),
            ),
          },
        );
        final rig = _Rig(
          now: now,
          accounts: [sharedAccount],
          groupPolicy: groupPolicy,
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        final overlappingGroup = LlmModelGroup(
          id: 'group-2',
          displayName: 'Overlapping group',
          members: [
            LlmModelGroupMember(
              accountId: sharedAccount.id,
              upstreamModelId: sharedAccount.models.single.upstreamModelId,
              localModelId: 'chat-model',
            ),
          ],
          policy: groupPolicy,
        );
        final overlappingService = LlmRoutingService(
          accountService: rig.accounts,
          stateStore: rig.stateStore,
          clock: () => rig.now,
          concurrency: rig.service.concurrency,
          roundRobin: LlmRoundRobinCursor(),
        );
        final entered = Completer<void>();
        final finish = Completer<void>();
        final first = rig.route((candidate, progress) async {
          await progress.markRequestSent();
          entered.complete();
          await finish.future;
          return candidate.account.id;
        }, estimatedUsage: const {'requests': 1, 'credits': 5});
        await entered.future;

        await expectLater(
          overlappingService.execute(
            group: overlappingGroup,
            requestedModelId: 'chat-model',
            estimatedUsage: const {'requests': 1, 'credits': 5},
            request: (candidate, progress) async => candidate.account.id,
          ),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        finish.complete();
        await first;
      },
    );

    test(
      'releases reservations on success, error, cancellation, and timeout',
      () async {
        for (final terminal in ['success', 'error', 'cancel', 'timeout']) {
          final rig = _Rig(
            now: DateTime.utc(2026, 10, 18, 12),
            accounts: [
              _account(
                'slot',
                'codex',
                policy: LlmRoutingPolicy(concurrencyLimit: 1),
              ),
            ],
            groupPolicy: LlmRoutingPolicy(concurrencyLimit: 1),
          );
          if (terminal != 'success') {
            await expectLater(
              rig.route((candidate, progress) async {
                await progress.markRequestSent();
                switch (terminal) {
                  case 'error':
                    throw StateError('request failed');
                  case 'cancel':
                    throw DioException(
                      requestOptions: RequestOptions(path: '/'),
                      type: DioExceptionType.cancel,
                    );
                  case 'timeout':
                    throw TimeoutException('request timed out');
                }
                return candidate.account.id;
              }),
              throwsA(anything),
            );
            rig.advance(const Duration(seconds: 16));
          } else {
            await rig.route((candidate, progress) async {
              await progress.markRequestSent();
              return candidate.account.id;
            });
          }

          expect((await rig.stateStore.load()).pendingUsage, isEmpty);
          final result = await rig.route(
            (candidate, progress) async => candidate.account.id,
          );
          expect(result.candidate.account.id, 'slot', reason: terminal);
        }
      },
    );

    test(
      'releases a reservation when a provider reset hint is out of range',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'slot',
              'codex',
              policy: LlmRoutingPolicy(concurrencyLimit: 1),
            ),
          ],
          groupPolicy: LlmRoutingPolicy(concurrencyLimit: 1),
        );

        await expectLater(
          rig.route((candidate, progress) async {
            throw const LlmRouteRequestException(
              statusCode: 429,
              headers: {'x-ratelimit-reset': '1e300'},
            );
          }),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        rig.advance(const Duration(minutes: 1));
        final retried = await rig.route(
          (candidate, progress) async => candidate.account.id,
        );
        expect(retried.candidate.account.id, 'slot');
      },
    );

    test(
      'releases a reservation when Retry-After exceeds the DateTime range',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'slot',
              'codex',
              policy: LlmRoutingPolicy(concurrencyLimit: 1),
            ),
          ],
          groupPolicy: LlmRoutingPolicy(concurrencyLimit: 1),
        );

        await expectLater(
          rig.route((candidate, progress) async {
            throw const LlmRouteRequestException(
              statusCode: 429,
              headers: {'retry-after': '9000000000000'},
            );
          }),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );

        rig.advance(const Duration(minutes: 1));
        final retried = await rig.route(
          (candidate, progress) async => candidate.account.id,
        );
        expect(retried.candidate.account.id, 'slot');
      },
    );

    test(
      'persists observed usage and cooldowns without response or secrets',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(now: now, accounts: [_account('account', 'codex')]);
        await rig.route((candidate, progress) async {
          await progress.markRequestSent();
          await progress.recordUsage(
            unit: 'tokens',
            value: 18,
            source: 'codex.response',
          );
          return 'ok';
        });
        await rig.stateStore.recordCooldown(
          'account',
          LlmCooldown(
            until: now.add(const Duration(minutes: 1)),
            reason: LlmRequestFailureKind.rateLimited,
          ),
        );

        final restored = LlmRoutingStateStore(
          preferences: rig.preferences,
          clock: () => rig.now,
        );
        final state = await restored.load();
        expect(state.events, hasLength(1));
        expect(state.pendingUsage, isEmpty);
        expect(
          state.events.single.measurements.map((item) => item.unit),
          containsAll(['requests', 'tokens']),
        );
        expect(
          state.cooldowns['account']!.reason,
          LlmRequestFailureKind.rateLimited,
        );
        final encoded =
            rig.preferences.values[LlmRoutingStateStore.preferenceKey]!;
        expect(encoded, isNot(contains('credential')));
        expect(encoded, isNot(contains('response body')));
      },
    );

    test('explicit cooldown clearing removes its in-memory fallback', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final rig = _Rig(now: now, accounts: [_account('account', 'codex')]);
      await rig.stateStore.recordCooldown(
        'account',
        LlmCooldown(
          until: now.add(const Duration(minutes: 1)),
          reason: LlmRequestFailureKind.rateLimited,
        ),
      );

      await rig.stateStore.clearCooldown('account');

      expect(
        (await rig.stateStore.load()).cooldowns,
        isNot(contains('account')),
      );
    });

    test('malformed persisted usage cannot be silently dropped', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final rig = _Rig(now: now, accounts: [_account('account', 'codex')]);
      rig.preferences.values[LlmRoutingStateStore.preferenceKey] = jsonEncode({
        'version': 1,
        'trackingStartedAt': now.toIso8601String(),
        'events': [
          {'invalid': true},
        ],
        'cooldowns': {},
      });

      await expectLater(
        rig.route((candidate, progress) async => candidate.account.id),
        throwsA(isA<LlmRoutingStateException>()),
      );
    });

    test('rejects malformed usage before persisting routing state', () async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final rig = _Rig(now: now, accounts: [_account('account', 'codex')]);

      await expectLater(
        rig.stateStore.recordUsage(
          LlmUsageEvent(
            accountId: 'account',
            groupId: 'group-1',
            occurredAt: now,
            measurements: const [
              LlmUsageMeasurement(unit: '', value: 1, source: 'local'),
            ],
          ),
        ),
        throwsA(isA<LlmRoutingStateException>()),
      );
      expect(
        rig.preferences.values.containsKey(LlmRoutingStateStore.preferenceKey),
        isFalse,
      );
      expect((await rig.stateStore.load()).events, isEmpty);
    });

    test(
      'expired pending usage does not block an unrelated quota window',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final expiredAt = now.subtract(const Duration(days: 31));
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'expired-pending',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.month: const LlmWindowPolicy(
                    usageCeiling: LlmLimitThreshold.fixed(1, unit: 'requests'),
                  ),
                },
              ),
            ),
          ],
        );
        _seedUsageTracking(
          rig,
          expiredAt,
          pendingUsage: [
            LlmPendingUsage(
              id: 'pending-old-marker',
              accountId: 'expired-pending',
              groupId: rig.group.id,
              startedAt: expiredAt,
            ),
          ],
        );

        final result = await rig.route(
          (candidate, progress) async => candidate.account.id,
        );
        expect(result.candidate.account.id, 'expired-pending');
      },
    );

    test(
      'a sent request crossing the rolling window boundary keeps its marker in-window',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'boundary-pending',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.fiveHour: const LlmWindowPolicy(
                    usageCeiling: LlmLimitThreshold.fixed(1, unit: 'requests'),
                  ),
                },
              ),
            ),
          ],
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 1)));

        await expectLater(
          rig.route((candidate, progress) async {
            rig.advance(const Duration(hours: 5, seconds: 1));
            await progress.markRequestSent();
            rig.preferences.failNextRoutingStateWrite();
            return candidate.account.id;
          }),
          throwsA(isA<LlmRoutingStateException>()),
        );

        await expectLater(
          rig.route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );

    test(
      'does not send before a usage uncertainty marker is persisted',
      () async {
        final rig = _Rig(
          now: DateTime.utc(2026, 10, 18, 12),
          accounts: [_account('write-ahead', 'codex')],
        );
        rig.preferences.failNextRoutingStateWrite();
        var requestStarted = false;

        await expectLater(
          rig.route((candidate, progress) async {
            requestStarted = true;
            return candidate.account.id;
          }),
          throwsA(isA<LlmRoutingStateException>()),
        );

        expect(requestStarted, isFalse);
        expect(rig.service.concurrency.activeForAccount('write-ahead'), 0);
        expect((await rig.stateStore.load()).pendingUsage, isEmpty);
      },
    );

    test(
      'failed usage persistence leaves later quota admissions uncertain',
      () async {
        final now = DateTime.utc(2026, 10, 18, 12);
        final rig = _Rig(
          now: now,
          accounts: [
            _account(
              'write-failed',
              'codex',
              policy: LlmRoutingPolicy(
                windows: {
                  LlmUsageWindow.day: const LlmWindowPolicy(
                    usageCeiling: LlmLimitThreshold.fixed(1, unit: 'requests'),
                  ),
                },
              ),
            ),
          ],
        );
        _seedUsageTracking(rig, now.subtract(const Duration(days: 2)));

        await expectLater(
          rig.route((candidate, progress) async {
            await progress.markRequestSent();
            rig.preferences.failNextRoutingStateWrite();
            return candidate.account.id;
          }),
          throwsA(isA<LlmRoutingStateException>()),
        );
        expect((await rig.stateStore.load()).pendingUsage, hasLength(1));

        await expectLater(
          rig.route((candidate, progress) async => candidate.account.id),
          throwsA(isA<LlmRoutingUnavailableException>()),
        );
      },
    );
  });
}

class _Rig {
  DateTime now;
  final _MemoryPreferences preferences = _MemoryPreferences();
  final _MemoryCredentials credentials = _MemoryCredentials();
  late final LlmAccountConnectorService accounts = LlmAccountConnectorService(
    preferences: preferences,
    credentialStore: credentials,
  );
  late final LlmModelGroup group;
  late final LlmRoutingStateStore stateStore = LlmRoutingStateStore(
    preferences: preferences,
    clock: () => now,
  );
  late final LlmRoutingService service = LlmRoutingService(
    accountService: accounts,
    stateStore: stateStore,
    clock: () => now,
    concurrency: LlmConcurrencyReservations(),
    roundRobin: LlmRoundRobinCursor(),
  );

  _Rig({
    required this.now,
    required List<LlmAccount> accounts,
    List<(String, String, int)>? groupMembers,
    LlmRoutingPolicy? groupPolicy,
    LlmSelectionStrategy strategy = LlmSelectionStrategy.leastUsed,
    LlmFallbackScope fallbackScope = LlmFallbackScope.modelGroup,
  }) {
    final accountById = {for (final account in accounts) account.id: account};
    final members =
        groupMembers ??
        [
          for (final account in accounts)
            (account.id, account.models.first.upstreamModelId, 0),
        ];
    group = LlmModelGroup(
      id: 'group-1',
      displayName: 'Test group',
      members: [
        for (final member in members)
          LlmModelGroupMember(
            accountId: member.$1,
            upstreamModelId: member.$2,
            priorityTier: member.$3,
            localModelId: 'chat-model',
          ),
      ],
      policy:
          groupPolicy ??
          LlmRoutingPolicy(fallbackScope: fallbackScope, strategy: strategy),
    );
    preferences.values[LlmAccountMigrationService.accountsPreferenceKey] =
        jsonEncode({
          'version': 1,
          'items': accountById.values.map((item) => item.toMap()).toList(),
        });
  }

  Future<LlmRoutingExecution<T>> route<T>(
    Future<T> Function(LlmRouteCandidate candidate, LlmRouteProgress progress)
    request, {
    Map<String, num> estimatedUsage = const {'requests': 1},
  }) => service.execute(
    group: group,
    requestedModelId: 'chat-model',
    estimatedUsage: estimatedUsage,
    request: request,
  );

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

void _seedUsageTracking(
  _Rig rig,
  DateTime startedAt, {
  List<LlmUsageEvent> events = const [],
  List<LlmPendingUsage> pendingUsage = const [],
}) {
  rig.preferences.values[LlmRoutingStateStore.preferenceKey] = jsonEncode({
    'version': 1,
    'trackingStartedAt': startedAt.toUtc().toIso8601String(),
    'events': events.map((event) => event.toMap()).toList(),
    'pendingUsage': pendingUsage.map((pending) => pending.toMap()).toList(),
    'cooldowns': <String, Object?>{},
  });
}

LlmAccount _account(
  String id,
  String connector, {
  LlmRoutingPolicy? policy,
  Map<LlmUsageWindow, LlmUsageWindowState> usage = const {},
  String? upstreamModel,
}) => LlmAccount(
  id: id,
  connectorType: connector,
  authType: 'api_key',
  displayName: id,
  status: LlmAccountStatus.ready,
  models: [
    LlmUpstreamModel(
      id: '$id-model',
      upstreamModelId: upstreamModel ?? '$connector-model',
      displayName: upstreamModel ?? '$connector-model',
      capabilities: const {'tools': true, 'vision': true},
    ),
  ],
  policy: policy,
  usageByWindow: usage,
);

LlmMetricObservation _metric(
  num value,
  String unit,
  DateTime observedAt, {
  String source = 'provider',
}) => LlmMetricObservation.reported(
  value,
  unit: unit,
  source: source,
  observedAt: observedAt,
);

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};
  var _failNextRoutingStateWrite = false;
  int? _routingStateWritesBeforeFailure;
  Completer<void>? _routingStateReadPaused;
  Completer<void>? _resumeRoutingStateRead;
  var _pauseNextRoutingStateRead = false;

  Future<void> get routingStateReadPaused => _routingStateReadPaused!.future;

  void pauseNextRoutingStateRead() {
    _routingStateReadPaused = Completer<void>();
    _resumeRoutingStateRead = Completer<void>();
    _pauseNextRoutingStateRead = true;
  }

  void resumeRoutingStateRead() {
    if (!_resumeRoutingStateRead!.isCompleted) {
      _resumeRoutingStateRead!.complete();
    }
  }

  void failNextRoutingStateWrite() => _failNextRoutingStateWrite = true;

  void failRoutingStateWriteAfter(int successfulWrites) {
    _routingStateWritesBeforeFailure = successfulWrites;
  }

  @override
  Future<String?> getString(String key) async {
    final snapshot = values[key];
    if (key == LlmRoutingStateStore.preferenceKey &&
        _pauseNextRoutingStateRead) {
      _pauseNextRoutingStateRead = false;
      _routingStateReadPaused!.complete();
      await _resumeRoutingStateRead!.future;
    }
    return snapshot;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (key == LlmRoutingStateStore.preferenceKey &&
        _routingStateWritesBeforeFailure != null) {
      if (_routingStateWritesBeforeFailure == 0) {
        _routingStateWritesBeforeFailure = null;
        return false;
      }
      _routingStateWritesBeforeFailure = _routingStateWritesBeforeFailure! - 1;
    }
    if (key == LlmRoutingStateStore.preferenceKey &&
        _failNextRoutingStateWrite) {
      _failNextRoutingStateWrite = false;
      return false;
    }
    values[key] = value;
    return true;
  }
}

class _MemoryCredentials implements LlmCredentialStore {
  @override
  Future<void> delete(String reference) async {}

  @override
  Future<String?> read(String reference) async => null;

  @override
  Future<void> write(String reference, String secret) async {}
}
