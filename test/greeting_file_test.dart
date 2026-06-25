import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GreetingFile', () {
    test('greeting.txt file exists at project root', () {
      final file = File('greeting.txt');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'greeting.txt should exist at project root',
      );
    });

    test('greeting.txt contains exactly "你好"', () {
      final file = File('greeting.txt');
      final content = file.readAsStringSync();
      expect(content, '你好', reason: 'File content should be exactly "你好"');
    });
  });
}
