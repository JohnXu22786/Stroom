import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _blockAfter(String source, String marker) {
  final markerStart = source.indexOf(marker);
  expect(markerStart, isNonNegative, reason: 'Missing source marker: $marker');
  final openBrace = source.indexOf('{', markerStart);
  expect(openBrace, isNonNegative, reason: 'Missing block for: $marker');

  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}' && --depth == 0) {
      return source.substring(openBrace + 1, index);
    }
  }

  fail('Unclosed block for: $marker');
}

void main() {
  test('idle Android background service does not acquire a CPU wake lock', () {
    final source = File(
      'packages/flutter_background_service_android/android/src/main/java/'
      'id/flutter/flutter_background_service/BackgroundService.java',
    ).readAsStringSync();
    final runServiceStart = source.indexOf('protected void runService()');
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

  test('manual stop releases and resets the boot wake lock', () {
    final source = File(
      'packages/flutter_background_service_android/android/src/main/java/'
      'id/flutter/flutter_background_service/BackgroundService.java',
    ).readAsStringSync();
    final onDestroy = _blockAfter(source, 'public void onDestroy()');
    final manualStop = _blockAfter(onDestroy, 'else');
    final releaseLock = _blockAfter(source, 'static synchronized void releaseLock()');

    expect(manualStop, contains('config.setManuallyStopped(true)'));
    expect(manualStop, contains('releaseLock()'));
    expect(releaseLock, contains('if (lockStatic != null)'));
    expect(releaseLock, contains('if (lockStatic.isHeld())'));
    expect(releaseLock, contains('lockStatic.release()'));
    expect(releaseLock, contains('lockStatic = null'));
  });

  test('watchdog restart retains the wake lock until service recovery', () {
    final source = File(
      'packages/flutter_background_service_android/android/src/main/java/'
      'id/flutter/flutter_background_service/BackgroundService.java',
    ).readAsStringSync();
    final onDestroy = _blockAfter(source, 'public void onDestroy()');
    final automaticRestart = _blockAfter(onDestroy, 'if (!isManuallyStopped)');

    expect(automaticRestart, contains('WatchdogReceiver.enqueue(this)'));
    expect(automaticRestart, isNot(contains('lockStatic.release()')));
    expect(automaticRestart, isNot(contains('lockStatic = null')));
  });
}
