import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/chat/chat_initial_scroll.dart';

void main() {
  group('resolveInitialChatScrollTarget', () {
    test('long tail: returns the last user message top (top of viewport)',
        () {
      // Last user message top at 1500, tail ends at 5000, viewport 500:
      // the tail (3500) does not fit one screen -> show the user message top.
      final target = resolveInitialChatScrollTarget(
        lastUserMessageTop: 1500,
        tailBottom: 5000,
        maxScrollExtent: 4500,
        viewportDimension: 500,
      );
      expect(target, 1500);
    });

    test('short tail: prefers the bottom when everything fits one screen',
        () {
      // Tail = 5000 - 4700 = 300 <= viewport 500 -> bottom.
      final target = resolveInitialChatScrollTarget(
        lastUserMessageTop: 4700,
        tailBottom: 5000,
        maxScrollExtent: 5000,
        viewportDimension: 500,
      );
      expect(target, 5000);
    });

    test('tail exactly one viewport still goes to the bottom', () {
      final target = resolveInitialChatScrollTarget(
        lastUserMessageTop: 4500,
        tailBottom: 5000,
        maxScrollExtent: 5000,
        viewportDimension: 500,
      );
      expect(target, 5000);
    });

    test('last message near the end (tail below one pixel) goes to bottom',
        () {
      final target = resolveInitialChatScrollTarget(
        lastUserMessageTop: 4999,
        tailBottom: 5000,
        maxScrollExtent: 5000,
        viewportDimension: 500,
      );
      expect(target, 5000);
    });

    test('result is clamped to [0, maxScrollExtent]', () {
      // lastUserMessageTop above the content start cannot happen in practice,
      // but the resolver must never return an out-of-range offset.
      final negative = resolveInitialChatScrollTarget(
        lastUserMessageTop: -100,
        tailBottom: 5000,
        maxScrollExtent: 5000,
        viewportDimension: 500,
      );
      expect(negative, 0);

      final oversized = resolveInitialChatScrollTarget(
        lastUserMessageTop: 9000,
        tailBottom: 9500,
        maxScrollExtent: 5000,
        viewportDimension: 500,
      );
      expect(oversized, 5000);
    });

    test('non-scrollable content resolves to 0', () {
      final target = resolveInitialChatScrollTarget(
        lastUserMessageTop: 0,
        tailBottom: 0,
        maxScrollExtent: 0,
        viewportDimension: 500,
      );
      expect(target, 0);
    });
  });
}
