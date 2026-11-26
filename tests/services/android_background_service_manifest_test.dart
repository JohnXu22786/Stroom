import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'internal Android components are private and boot receiver stays enabled',
      () {
    final manifest = File(
      'packages/flutter_background_service_android/android/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    String component(String tag, String name) {
      final match = RegExp(
        '<$tag\\b(?=[^>]*android:name="\\.$name")[^>]*>',
      ).firstMatch(manifest);
      expect(match, isNotNull, reason: 'Missing $name declaration');
      return match!.group(0)!;
    }

    String componentBlock(String tag, String name) {
      final startTag = component(tag, name);
      final start = manifest.indexOf(startTag);
      if (startTag.endsWith('/>')) return startTag;

      final endTag = '</$tag>';
      final end = manifest.indexOf(endTag, start + startTag.length);
      expect(end, isNonNegative, reason: 'Missing $name closing tag');
      return manifest.substring(start, end + endTag.length);
    }

    expect(component('service', 'BackgroundService'),
        contains('android:exported="false"'));
    expect(component('receiver', 'WatchdogReceiver'),
        contains('android:exported="false"'));

    final bootReceiver = componentBlock('receiver', 'BootReceiver');
    expect(bootReceiver, contains('android:exported="true"'));
    expect(
        bootReceiver,
        contains(
            '<action android:name="android.intent.action.BOOT_COMPLETED"'));
    expect(
        bootReceiver,
        contains(
            '<action android:name="android.intent.action.MY_PACKAGE_REPLACED"'));
    expect(
        bootReceiver,
        contains(
            '<action android:name="android.intent.action.QUICKBOOT_POWERON"'));
  });
}
