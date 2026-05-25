import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/app_version.dart';

void main() {
  group('appVersion', () {
    test('defaults to 1.0.0+1 when not set via --dart-define', () {
      expect(appVersion, '1.0.0+1');
    });
  });
}
