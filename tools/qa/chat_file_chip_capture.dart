import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/composer/chat_file_picker_dialog.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Future<void> main() async {
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '') ?? 3;
  final dark = query['theme'] == 'dark';
  if (query['route'] == 'picker') {
    final fileName = query['file'] ?? 'annual.pdf';
    final dot = fileName.lastIndexOf('.');
    final name = dot < 0 ? fileName : fileName.substring(0, dot);
    final format = dot < 0 ? 'txt' : fileName.substring(dot + 1);
    ManifestDatabase.enableTestMode();
    // ignore: invalid_use_of_visible_for_testing_member
    TextManifest.readFileOverrideForTesting =
        (_) async => Uint8List.fromList([1, 2, 3]);
    await TextManifest.addRecord(
      TextRecord(
        name: name,
        format: format,
        hash: 'chat-file-chip-capture',
        size: 3,
        createdAt: DateTime.now(),
      ),
    );
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: query['motion'] == 'off',
        );
        return MediaQuery(
          data: mediaQuery,
          child: TickerMode(
            enabled: query['offscreen'] != 'true',
            child: child!,
          ),
        );
      },
      home: query['route'] == 'picker'
          ? const _DialogRouteFixture()
          : Scaffold(
              body: const SafeArea(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: _FileChipFixture(),
                  ),
                ),
              ),
            ),
    ),
  );
}

class _DialogRouteFixture extends StatefulWidget {
  const _DialogRouteFixture();

  @override
  State<_DialogRouteFixture> createState() => _DialogRouteFixtureState();
}

class _DialogRouteFixtureState extends State<_DialogRouteFixture> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) showAppFilePickerDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _FileChipFixture extends StatelessWidget {
  const _FileChipFixture();

  @override
  Widget build(BuildContext context) {
    final query = Uri.base.queryParameters;
    final fileName = query['file'] ??
        switch (query['name']) {
          'fit' => 'notes.txt',
          'two-line' => 'annual.pdf',
          _ => 'quarterly-report-2024-final-archive-version.pdf',
        };
    final textStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    final textLayout = TextPainter(
      text: TextSpan(text: fileName, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 100);
    final twoLineLayout = TextPainter(
      text: TextSpan(text: fileName, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 100);
    debugPrint(
      'CHAT_FILE_CHIP_METRIC:${query['name'] ?? 'long'} '
      'lines=${textLayout.computeLineMetrics().length} '
      'height=${textLayout.height.toStringAsFixed(1)} '
      'twoLineHeight=${twoLineLayout.height.toStringAsFixed(1)} '
      'exceedsTwo=${twoLineLayout.didExceedMaxLines}',
    );
    return PreviewChip(
      fileName: fileName,
      bytes: Uint8List(0),
      isImage: false,
      onRemove: () {},
    );
  }
}
