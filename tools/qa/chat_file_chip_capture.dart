import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';

void main() {
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '') ?? 3;
  final dark = query['theme'] == 'dark';
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
      home: Scaffold(
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

class _FileChipFixture extends StatelessWidget {
  const _FileChipFixture();

  @override
  Widget build(BuildContext context) {
    final query = Uri.base.queryParameters;
    final fileName =
        query['file'] ??
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
