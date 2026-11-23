import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/video_gallery_page.dart';
import 'package:stroom/providers/video_provider.dart';

class _EmptyVideoRecordsNotifier extends VideoRecordsNotifier {
  @override
  Future<void> loadRecords() async {}
}

class _EmptyVideoFoldersNotifier extends VideoFolderListNotifier {
  @override
  Future<void> loadFolders() async {}
}

void main() {
  testWidgets('video gallery actions grow with text scale at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in [1.0, 2.5]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordsProvider.overrideWith(
              (ref) => _EmptyVideoRecordsNotifier(),
            ),
            videoFolderListProvider.overrideWith(
              (ref) => _EmptyVideoFoldersNotifier(),
            ),
            videoViewModeProvider.overrideWith(
              (ref) => VideoViewModeNotifier(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1),
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const VideoGalleryPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final icon in [Icons.videocam, Icons.photo_library_outlined]) {
        final button = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(ElevatedButton),
        );
        expect(button, findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        if (textScale > 1) {
          expect(tester.getSize(button).height, greaterThan(48));
        }
      }
    }
  });
}
