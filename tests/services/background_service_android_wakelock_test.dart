import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle Android background service does not acquire a CPU wake lock', () {
    final source = File(
      'packages/flutter_background_service_android/android/src/main/java/'
      'id/flutter/flutter_background_service/BackgroundService.java',
    ).readAsStringSync();
    final runServiceStart = source.indexOf('private void runService()');
    final runServiceEnd = source.indexOf(
      'public void receiveData(',
      runServiceStart,
    );

    expect(runServiceStart, isNonNegative);
    expect(runServiceEnd, greaterThan(runServiceStart));
    final runService = source.substring(runServiceStart, runServiceEnd);
    expect(runService, isNot(contains('WakeLock')));
    expect(runService, isNot(contains('.acquire(')));
  });
}
