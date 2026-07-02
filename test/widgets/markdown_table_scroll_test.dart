import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/markdown_extensions.dart';

import 'package:markdown_widget/markdown_widget.dart';

void main() {
  group('TableConfig - horizontal drag scroll wrapper', () {
    test('buildMarkdownConfig includes TableConfig with a wrapper', () {
      final config = buildMarkdownConfig(isDark: false);
      final tableConfig = config.table;
      expect(tableConfig, isA<TableConfig>());
      expect(tableConfig.wrapper, isNotNull,
          reason:
              'TableConfig.wrapper should be set to enable horizontal scrolling');
    });

    test('buildMarkdownConfig wrapper is a WidgetWrapper (function)', () {
      final config = buildMarkdownConfig(isDark: false);
      final wrapper = config.table.wrapper;
      expect(wrapper, isA<Widget Function(Widget child)>());
    });

    test('buildMarkdownConfig dark mode also includes table wrapper', () {
      final config = buildMarkdownConfig(isDark: true);
      expect(config.table.wrapper, isNotNull,
          reason:
              'Dark mode config should also have table wrapper for consistency');
    });

    test('wrapper wraps child in a SingleChildScrollView with horizontal scroll',
        () {
      final config = buildMarkdownConfig(isDark: false);
      final wrapper = config.table.wrapper!;

      const testChild = SizedBox(width: 800, height: 100);
      final wrapped = wrapper(testChild);

      expect(
          wrapped, isA<SingleChildScrollView>(), reason: 'outermost widget');

      final scrollView = wrapped as SingleChildScrollView;
      expect(scrollView.scrollDirection, Axis.horizontal,
          reason: 'scroll direction should be horizontal');
    });

    test('wrapper clips child with Clip.hardEdge to prevent overflow', () {
      final config = buildMarkdownConfig(isDark: false);
      final wrapper = config.table.wrapper!;

      const testChild = SizedBox(width: 800, height: 100);
      final wrapped = wrapper(testChild);

      final scrollView = wrapped as SingleChildScrollView;
      expect(scrollView.clipBehavior, Clip.hardEdge,
          reason: 'should clip to prevent overflow beyond bubble');
    });
  });
}
