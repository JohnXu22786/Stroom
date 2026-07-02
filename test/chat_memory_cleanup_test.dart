import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Memory map cleanup patterns', () {
    test('clearing message-specific maps on stream completion', () {
      final msgId = 'a123';
      final chatSegments = <String, List<Object>>{};
      final reasoningContents = <String, List<String>>{};
      final streamingRenderedLengths = <String, int>{};

      // Simulate adding streaming data for a message
      chatSegments[msgId] = ['test'];
      reasoningContents[msgId] = ['reasoning text'];
      streamingRenderedLengths[msgId] = 4;

      // Verify data exists
      expect(chatSegments.containsKey(msgId), true);
      expect(reasoningContents.containsKey(msgId), true);
      expect(streamingRenderedLengths.containsKey(msgId), true);

      // Clean up after stream completes
      // Remove the map entries that are no longer needed
      chatSegments.remove(msgId);
      reasoningContents.remove(msgId);
      streamingRenderedLengths.remove(msgId);

      // Verify cleanup
      expect(chatSegments.containsKey(msgId), false);
      expect(reasoningContents.containsKey(msgId), false);
      expect(streamingRenderedLengths.containsKey(msgId), false);
    });

    test('message keys are cleaned up on message deletion', () {
      final messageKeys = <String, GlobalKey>{
        'msg_1': GlobalKey(),
        'msg_2': GlobalKey(),
        'msg_3': GlobalKey(),
      };

      // Simulate deleting msg_2
      messageKeys.remove('msg_2');

      expect(messageKeys.containsKey('msg_1'), true);
      expect(messageKeys.containsKey('msg_2'), false);
      expect(messageKeys.containsKey('msg_3'), true);
    });

    test('multiple map entries cleaned up consistently on deletion', () {
      final msgId = 'msg_to_delete';
      final chatSegments = <String, List<String>>{
        msgId: ['hello'],
        'other_msg': ['world'],
      };
      final reasoningContents = <String, List<String>>{
        msgId: ['thinking'],
        'other_msg': ['thoughts'],
      };
      final streamingRenderedLengths = <String, int>{
        msgId: 5,
        'other_msg': 5,
      };
      final messageKeys = <String, GlobalKey>{
        msgId: GlobalKey(),
        'other_msg': GlobalKey(),
      };

      // Clean up all 4 maps for the deleted message
      chatSegments.remove(msgId);
      reasoningContents.remove(msgId);
      streamingRenderedLengths.remove(msgId);
      messageKeys.remove(msgId);

      // Verify all 4 maps are cleaned up
      expect(chatSegments.containsKey(msgId), false);
      expect(reasoningContents.containsKey(msgId), false);
      expect(streamingRenderedLengths.containsKey(msgId), false);
      expect(messageKeys.containsKey(msgId), false);

      // Verify other messages are preserved
      expect(chatSegments.containsKey('other_msg'), true);
      expect(reasoningContents.containsKey('other_msg'), true);
      expect(streamingRenderedLengths.containsKey('other_msg'), true);
      expect(messageKeys.containsKey('other_msg'), true);
    });
  });
}
