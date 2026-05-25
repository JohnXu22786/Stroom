import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:stroom/pages/browser_page.dart';

void main() {
  group('UserScript serialization', () {
    test('toMap and fromMap round-trip', () {
      final script = UserScript(
        name: 'Test Script',
        code: 'console.log("hello");',
        matches: ['*://*.example.com/*'],
      );
      final map = script.toMap();
      final restored = UserScript.fromMap(map);
      expect(restored.name, 'Test Script');
      expect(restored.code, 'console.log("hello");');
      expect(restored.matches, ['*://*.example.com/*']);
    });

    test('empty fields are handled', () {
      final script = UserScript(name: '', code: '', matches: []);
      final map = script.toMap();
      final restored = UserScript.fromMap(map);
      expect(restored.name, '');
      expect(restored.code, '');
      expect(restored.matches, []);
    });

    test('list serialization to JSON', () {
      final scripts = [
        UserScript(name: 'A', code: '// a', matches: ['*://a.com/*']),
        UserScript(name: 'B', code: '// b', matches: []),
      ];
      final json = jsonEncode(scripts.map((s) => s.toMap()).toList());
      final decoded = jsonDecode(json) as List;
      final restored = decoded.map((e) => UserScript.fromMap(e as Map<String, dynamic>)).toList();
      expect(restored.length, 2);
      expect(restored[0].name, 'A');
      expect(restored[1].name, 'B');
    });
  });
}
