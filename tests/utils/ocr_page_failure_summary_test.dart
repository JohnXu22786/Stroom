import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/ocr_page_failure_summary.dart';

void main() {
  test('page failure summaries re-localize their ordered statuses', () {
    final target = lookupAppLocalizations(const Locale('en', 'US'));

    for (final locale in AppLocalizations.supportedLocales) {
      final source = lookupAppLocalizations(locale);
      final details = [
        source.bgTaskOcrPageFailed('2'),
        source.bgTaskOcrPageIncomplete('4'),
      ].join(source.bgTaskOcrPageFailureSeparator);
      final summary = source.bgTaskOcrPagesIncomplete(details);
      final expectedDetails = [
        target.bgTaskOcrPageFailed('2'),
        target.bgTaskOcrPageIncomplete('4'),
      ].join(target.bgTaskOcrPageFailureSeparator);

      expect(
        OcrPageFailureSummary.localize(summary, target),
        target.bgTaskOcrPagesIncomplete(expectedDetails),
      );
    }

    expect(
      OcrPageFailureSummary.localize(
        'Some images were not fully recognized: vendor secret=abc',
        target,
      ),
      isNull,
    );
  });
}
