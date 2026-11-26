import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/sse_data_line.dart';

void main() {
  group('sseDataLineValue', () {
    test('accepts data fields with no space after the colon', () {
      expect(sseDataLineValue('data:payload'), 'payload');
    });

    test('accepts data fields with one optional space after the colon', () {
      expect(sseDataLineValue('data: payload'), 'payload');
    });

    test('returns null for lines without a data field', () {
      expect(sseDataLineValue('event: message'), isNull);
    });
  });
}
