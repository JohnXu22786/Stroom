import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/system_gallery_picker_io.dart';

const _photoManagerChannel = MethodChannel('com.fluttercandies/photo_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final localeCase in [
    (
      locale: const Locale('en', 'US'),
      title: 'Photo library access required',
      message: 'Allow Stroom to access photos and videos in system settings.',
      cancel: 'Cancel',
      openSettings: 'Open settings',
    ),
    (
      locale: const Locale('en'),
      title: 'Photo library access required',
      message: 'Allow Stroom to access photos and videos in system settings.',
      cancel: 'Cancel',
      openSettings: 'Open settings',
    ),
    (
      locale: const Locale('zh', 'CN'),
      title: '需要访问相册',
      message: '请在系统设置中允许 Stroom 访问照片和视频。',
      cancel: '取消',
      openSettings: '打开设置',
    ),
    (
      locale: const Locale('zh'),
      title: '需要访问相册',
      message: '请在系统设置中允许 Stroom 访问照片和视频。',
      cancel: '取消',
      openSettings: '打开设置',
    ),
  ]) {
    testWidgets('gallery permission dialog uses ${localeCase.locale} strings', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_photoManagerChannel, (call) async {
        expect(call.method, 'requestPermissionExtend');
        return 2; // PermissionState.denied
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_photoManagerChannel, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: localeCase.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    unawaited(pickNativeGalleryMedia(context, isVideo: false)),
                child: const Text('Pick media'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick media'));
      await tester.pumpAndSettle();

      expect(find.text(localeCase.title), findsOneWidget);
      expect(find.text(localeCase.message), findsOneWidget);
      expect(find.text(localeCase.cancel), findsOneWidget);
      expect(find.text(localeCase.openSettings), findsOneWidget);

      await tester.tap(find.text(localeCase.cancel));
      await tester.pumpAndSettle();
      expect(find.text(localeCase.title), findsNothing);
    });
  }
}
