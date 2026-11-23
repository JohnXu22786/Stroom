import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '') ?? 2.5;
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;

  runApp(
    ProviderScope(
      overrides: [
        videoRecordsProvider
            .overrideWith((ref) => _EmptyVideoRecordsNotifier()),
        videoFolderListProvider.overrideWith(
          (ref) => _EmptyVideoFoldersNotifier(),
        ),
        videoViewModeProvider.overrideWith((ref) => VideoViewModeNotifier()),
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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: const VideoGalleryPage(),
      ),
    ),
  );
}
