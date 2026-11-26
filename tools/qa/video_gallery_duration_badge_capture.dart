import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/video_gallery_page.dart';
import 'package:stroom/providers/video_provider.dart';
import 'package:stroom/utils/video_manifest.dart';

class _CaptureVideoRecordsNotifier extends VideoRecordsNotifier {
  _CaptureVideoRecordsNotifier(int durationMs) {
    state = [
      VideoRecord(
        id: 'duration-badge-capture',
        name: 'sample-video',
        hash: 'duration-badge-capture-missing-thumbnail',
        format: 'mp4',
        createdAt: DateTime(2026),
        size: 1,
        duration: durationMs,
      ),
    ];
  }

  @override
  Future<void> loadRecords() async {}
}

class _CaptureVideoFoldersNotifier extends VideoFolderListNotifier {
  @override
  Future<void> loadFolders() async {}
}

class _CaptureGridViewModeNotifier extends VideoViewModeNotifier {
  _CaptureGridViewModeNotifier() {
    state = true;
  }

  @override
  Future<void> load() async {}
}

void main() {
  final query = Uri.base.queryParameters;
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final isDark = query['theme'] == 'dark';
  final durationMs =
      query['hours'] == '100' ? 100 * 60 * 60 * 1000 : 6 * 60 * 60 * 1000;
  final brightness = isDark ? Brightness.dark : Brightness.light;

  runApp(
    ProviderScope(
      overrides: [
        videoRecordsProvider.overrideWith(
          (ref) => _CaptureVideoRecordsNotifier(durationMs),
        ),
        videoFolderListProvider.overrideWith(
          (ref) => _CaptureVideoFoldersNotifier(),
        ),
        videoViewModeProvider.overrideWith(
          (ref) => _CaptureGridViewModeNotifier(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const VideoGalleryPage(),
      ),
    ),
  );
}
