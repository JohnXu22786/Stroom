import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/sort_config.dart';

void main() {
  group('SortField enum', () {
    test('has three values', () {
      expect(SortField.values, hasLength(3));
    });

    test('values are createdAt, name, size in that order', () {
      expect(SortField.values[0], SortField.createdAt);
      expect(SortField.values[1], SortField.name);
      expect(SortField.values[2], SortField.size);
    });
  });

  group('SortOrder enum', () {
    test('has two values', () {
      expect(SortOrder.values, hasLength(2));
    });

    test('values are ascending, descending in that order', () {
      expect(SortOrder.values[0], SortOrder.ascending);
      expect(SortOrder.values[1], SortOrder.descending);
    });
  });

  group('SortConfig — default constructor', () {
    test('uses createdAt and descending by default', () {
      const config = SortConfig();
      expect(config.field, SortField.createdAt);
      expect(config.order, SortOrder.descending);
    });

    test('default values are const-canonicalized', () {
      const a = SortConfig();
      const b = SortConfig();
      const c =
          SortConfig(field: SortField.createdAt, order: SortOrder.descending);
      // Dart canonicalises identical const expressions, so all three share
      // the same instance and pass `==`.
      expect(a, same(b));
      expect(a, same(c));
    });
  });

  group('SortConfig — copyWith', () {
    late SortConfig base;

    setUp(() {
      base =
          const SortConfig(field: SortField.size, order: SortOrder.ascending);
    });

    test('returns same config when no arguments provided', () {
      final copied = base.copyWith();
      expect(copied.field, SortField.size);
      expect(copied.order, SortOrder.ascending);
    });

    test('overrides only field', () {
      final copied = base.copyWith(field: SortField.name);
      expect(copied.field, SortField.name);
      expect(copied.order, SortOrder.ascending);
    });

    test('overrides only order', () {
      final copied = base.copyWith(order: SortOrder.descending);
      expect(copied.field, SortField.size);
      expect(copied.order, SortOrder.descending);
    });

    test('overrides both field and order', () {
      final copied = base.copyWith(
        field: SortField.createdAt,
        order: SortOrder.descending,
      );
      expect(copied.field, SortField.createdAt);
      expect(copied.order, SortOrder.descending);
    });

    test('does not mutate the original config', () {
      base.copyWith(field: SortField.name, order: SortOrder.descending);
      expect(base.field, SortField.size);
      expect(base.order, SortOrder.ascending);
    });
  });

  group('SortConfig — toggle', () {
    test('toggling to a different field uses descending order', () {
      const config =
          SortConfig(field: SortField.createdAt, order: SortOrder.ascending);
      final toggled = config.toggle(SortField.size);
      expect(toggled.field, SortField.size);
      expect(toggled.order, SortOrder.descending);
    });

    test('toggling to same field reverses order (ascending → descending)', () {
      const config =
          SortConfig(field: SortField.name, order: SortOrder.ascending);
      final toggled = config.toggle(SortField.name);
      expect(toggled.field, SortField.name);
      expect(toggled.order, SortOrder.descending);
    });

    test('toggling to same field reverses order (descending → ascending)', () {
      const config =
          SortConfig(field: SortField.size, order: SortOrder.descending);
      final toggled = config.toggle(SortField.size);
      expect(toggled.field, SortField.size);
      expect(toggled.order, SortOrder.ascending);
    });

    test(
        'toggling from default (createdAt, descending) to createdAt reverses to ascending',
        () {
      const config = SortConfig();
      expect(config.field, SortField.createdAt);
      expect(config.order, SortOrder.descending);

      final toggled = config.toggle(SortField.createdAt);
      expect(toggled.field, SortField.createdAt);
      expect(toggled.order, SortOrder.ascending);
    });

    test(
        'toggling from default (createdAt, descending) to name uses descending',
        () {
      const config = SortConfig();
      final toggled = config.toggle(SortField.name);
      expect(toggled.field, SortField.name);
      expect(toggled.order, SortOrder.descending);
    });

    test('does not mutate the original config', () {
      const config =
          SortConfig(field: SortField.name, order: SortOrder.ascending);
      config.toggle(SortField.name);
      expect(config.field, SortField.name);
      expect(config.order, SortOrder.ascending);
    });
  });

  group('SortConfig — toJson / fromJson round-trip', () {
    test('serialises and deserialises correctly for createdAt descending', () {
      const config = SortConfig();
      final json = config.toJson();
      expect(json, {'field': 'createdAt', 'order': 'descending'});

      final restored = SortConfig.fromJson(json);
      expect(restored.field, SortField.createdAt);
      expect(restored.order, SortOrder.descending);
    });

    test('serialises and deserialises correctly for name ascending', () {
      const config =
          SortConfig(field: SortField.name, order: SortOrder.ascending);
      final json = config.toJson();
      expect(json, {'field': 'name', 'order': 'ascending'});

      final restored = SortConfig.fromJson(json);
      expect(restored.field, SortField.name);
      expect(restored.order, SortOrder.ascending);
    });

    test('serialises and deserialises correctly for size descending', () {
      const config =
          SortConfig(field: SortField.size, order: SortOrder.descending);
      final json = config.toJson();
      expect(json, {'field': 'size', 'order': 'descending'});

      final restored = SortConfig.fromJson(json);
      expect(restored.field, SortField.size);
      expect(restored.order, SortOrder.descending);
    });

    test('round-trip is lossless for all 6 combinations', () {
      for (final field in SortField.values) {
        for (final order in SortOrder.values) {
          final original = SortConfig(field: field, order: order);
          final json = original.toJson();
          final restored = SortConfig.fromJson(json);
          expect(restored.field, field);
          expect(restored.order, order);
        }
      }
    });

    test('fromJson falls back to defaults for unknown field name', () {
      final restored = SortConfig.fromJson({
        'field': 'nonexistent',
        'order': 'ascending',
      });
      expect(restored.field, SortField.createdAt);
      expect(restored.order, SortOrder.ascending);
    });

    test('fromJson falls back to defaults for unknown order name', () {
      final restored = SortConfig.fromJson({
        'field': 'size',
        'order': 'invalid_order',
      });
      expect(restored.field, SortField.size);
      expect(restored.order, SortOrder.descending);
    });

    test('fromJson falls back to defaults for both unknown values', () {
      final restored = SortConfig.fromJson({
        'field': 'bogus',
        'order': 'bogus',
      });
      expect(restored.field, SortField.createdAt);
      expect(restored.order, SortOrder.descending);
    });

    test('fromJson handles missing keys gracefully', () {
      final restored = SortConfig.fromJson({});
      expect(restored.field, SortField.createdAt);
      expect(restored.order, SortOrder.descending);
    });
  });

  group('SortConfig — label', () {
    test('"最新在前" for createdAt + descending', () {
      const config = SortConfig();
      expect(config.label, '最新在前');
    });

    test('"最旧在前" for createdAt + ascending', () {
      const config =
          SortConfig(field: SortField.createdAt, order: SortOrder.ascending);
      expect(config.label, '最旧在前');
    });

    test('"文件名（大到小）" for name + descending', () {
      const config =
          SortConfig(field: SortField.name, order: SortOrder.descending);
      expect(config.label, '文件名（大到小）');
    });

    test('"文件名（小到大）" for name + ascending', () {
      const config =
          SortConfig(field: SortField.name, order: SortOrder.ascending);
      expect(config.label, '文件名（小到大）');
    });

    test('"大小（大到小）" for size + descending', () {
      const config =
          SortConfig(field: SortField.size, order: SortOrder.descending);
      expect(config.label, '大小（大到小）');
    });

    test('"大小（小到大）" for size + ascending', () {
      const config =
          SortConfig(field: SortField.size, order: SortOrder.ascending);
      expect(config.label, '大小（小到大）');
    });
  });

  group('SortConfig — equality and hashCode', () {
    test('const instances with same values are identical (canonicalised)', () {
      const a = SortConfig();
      const b = SortConfig();
      expect(a, same(b));
    });

    test('const instances with different values are different objects', () {
      const a = SortConfig();
      const b = SortConfig(field: SortField.name);
      expect(a == b, false);
    });

    test(
        'non-const identical instances are not equal by default (no == override)',
        () {
      // SortConfig does not override operator== or hashCode, so two
      // non-canonicalised instances with the same values are *not* equal.
      final a = SortConfig();
      final b = SortConfig();
      expect(identical(a, b), false);
      expect(a == b, false);
    });

    test(
        'hashCode differs for non-const instances with same values (no override)',
        () {
      final a = SortConfig();
      final b = SortConfig();
      // Identity-based hashCode means different objects get different codes.
      // We can only assert they are *not guaranteed to be* the same.
      // This test documents the current behaviour.
      expect(a.hashCode == b.hashCode, false);
    });
  });
}
