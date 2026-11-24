// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/utils/sort_config.dart';

void main() {
  test('loads persisted sort config when no user change occurs', () async {
    SharedPreferences.setMockInitialValues({
      'sort_config': jsonEncode({
        'field': SortField.size.name,
        'order': SortOrder.ascending.name,
      }),
    });

    try {
      final notifier = SortConfigNotifier('sort_config');
      await notifier.load();

      expect(notifier.state.field, SortField.size);
      expect(notifier.state.order, SortOrder.ascending);
    } finally {
      SharedPreferences.setMockInitialValues({});
    }
  });

  test(
    'a user sort change wins over an in-flight persisted config load',
    () async {
      SharedPreferences.setMockInitialValues({});
      final readStarted = Completer<void>();
      final storedValue = Completer<String?>();

      try {
        final notifier = SortConfigNotifier(
          'sort_config',
          readStoredValue: (_) {
            readStarted.complete();
            return storedValue.future;
          },
        );
        final load = notifier.load();
        await readStarted.future;

        await notifier.toggle(SortField.name);
        expect(notifier.state.field, SortField.name);
        expect(notifier.state.order, SortOrder.descending);

        storedValue.complete(
          jsonEncode({
            'field': SortField.size.name,
            'order': SortOrder.ascending.name,
          }),
        );
        await load;

        expect(notifier.state.field, SortField.name);
        expect(notifier.state.order, SortOrder.descending);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('sort_config'),
          jsonEncode({
            'field': SortField.name.name,
            'order': SortOrder.descending.name,
          }),
        );
      } finally {
        SharedPreferences.setMockInitialValues({});
      }
    },
  );
}
