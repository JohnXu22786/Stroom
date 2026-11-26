import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/video_gallery_page.dart';
import 'package:stroom/providers/video_provider.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

class _VideoRecordsNotifier extends VideoRecordsNotifier {
  _VideoRecordsNotifier(List<VideoRecord> records) {
    state = records;
  }

  @override
  Future<void> loadRecords() async {}
}

class _VideoFolderListNotifier extends VideoFolderListNotifier {
  @override
  Future<void> loadFolders() async {}
}

class _GridViewModeNotifier extends VideoViewModeNotifier {
  _GridViewModeNotifier() {
    state = true;
  }

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets(
    'duration badges fit the thumbnail and reveal clipped durations accessibly',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final record = VideoRecord(
        id: 'duration-badge-video',
        name: 'sample',
        hash: 'missing-thumbnail',
        format: 'mp4',
        createdAt: DateTime(2026),
        size: 1,
        duration: 100 * 60 * 60 * 1000,
      );

      Future<void> pumpGallery(double textScale) async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('video-gallery-scale-$textScale'),
            overrides: [
              videoRecordsProvider.overrideWith(
                (ref) => _VideoRecordsNotifier([record]),
              ),
              videoFolderListProvider.overrideWith(
                (ref) => _VideoFolderListNotifier(),
              ),
              videoViewModeProvider.overrideWith(
                (ref) => _GridViewModeNotifier(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en', 'US'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: const MediaQueryData(size: Size(320, 640))
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: const VideoGalleryPage(),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpGallery(1);
      final durationText = find.text('6000:00');
      var badge = find.ancestor(
        of: durationText,
        matching: find.byType(ConstrainedText),
      );
      expect(badge, findsOneWidget);
      expect(tester.getSemantics(badge).label, startsWith('6000:00'));
      final fittingBadgeRect = tester.getRect(badge);
      final fittingThumbnailRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('fm_grid_file_duration-badge-video')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(
        fittingBadgeRect.left,
        greaterThanOrEqualTo(fittingThumbnailRect.left),
      );
      expect(
        fittingBadgeRect.right,
        lessThanOrEqualTo(fittingThumbnailRect.right),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpGallery(3);
      badge = find.ancestor(
        of: durationText,
        matching: find.byType(ConstrainedText),
      );
      expect(badge, findsOneWidget);
      expect(tester.getSemantics(badge).label, contains('6000:00'));
      final clippedThumbnailRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('fm_grid_file_duration-badge-video')),
          matching: find.byType(ClipRRect),
        ),
      );
      final initialBadgeRect = tester.getRect(badge);
      final marqueeText = find.descendant(
        of: badge,
        matching: find.byType(RichText),
      );
      final initialTextRect = tester.getRect(marqueeText);
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '6000:00',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(3),
      )..layout();
      final travel = Duration(
        milliseconds:
            ((textPainter.width - tester.getSize(badge).width) / 24 * 1000)
                .round(),
      );
      expect(
        initialBadgeRect.left,
        greaterThanOrEqualTo(clippedThumbnailRect.left),
      );
      expect(
        initialBadgeRect.right,
        lessThanOrEqualTo(clippedThumbnailRect.right),
      );

      await tester.pump(const Duration(milliseconds: 900));
      final stillTextRect = tester.getRect(marqueeText);
      expect(stillTextRect.left, closeTo(initialTextRect.left, 0.1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(travel + const Duration(milliseconds: 20));
      final endTextRect = tester.getRect(marqueeText);
      expect(endTextRect.left, lessThan(stillTextRect.left));
      expect(endTextRect.right, closeTo(initialBadgeRect.right, 2));
    },
  );
}
