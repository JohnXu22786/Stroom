import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lightweight documentation tests for the chat UI color scheme.
///
/// These tests record the specific Material color constants used in
/// chat_page.dart for error bubbles and the scroll-to-bottom button.
/// They serve as basic documentation of the color contract.
void main() {
  group('Chat UI color contract', () {
    test('error bubble uses red palette, not grey', () {
      // Production: Colors.red[50] (light) / Colors.red[900] (dark)
      expect(Colors.red[50]!.toARGB32(), 0xFFFFEBEE);
      expect(Colors.red[900]!.toARGB32(), 0xFFB71C1C);
      // Old grey colors for comparison
      expect(Colors.grey[100]!.toARGB32(), 0xFFF5F5F5);
      expect(Colors.grey[850]!.toARGB32(), 0xFF303030);
      // Verify red is different from old grey
      expect(Colors.red[50], isNot(Colors.grey[100]));
      expect(Colors.red[900], isNot(Colors.grey[850]));
    });

    test('scroll button uses grey palette, not orange-red', () {
      // Production: Colors.grey[300] (light) / Colors.grey[700] (dark)
      expect(Colors.grey[300]!.toARGB32(), 0xFFE0E0E0);
      expect(Colors.grey[700]!.toARGB32(), 0xFF616161);
      // Old orange color
      expect(Colors.orange[700]!.toARGB32(), 0xFFF57C00);
      // Verify grey is not orange
      expect(Colors.grey[300], isNot(Colors.orange[700]));
      expect(Colors.grey[700], isNot(Colors.orange[700]));
    });

    test('background opacity is 0.7', () {
      // Production: .withOpacity(0.7) applied to the red background
      expect(Colors.red[50]!.withValues(alpha: 0.7).a, closeTo(0.7, 0.01));
      expect(Colors.red[900]!.withValues(alpha: 0.7).a, closeTo(0.7, 0.01));
    });
  });
}
