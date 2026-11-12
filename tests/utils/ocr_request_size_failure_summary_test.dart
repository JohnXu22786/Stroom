import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/ocr_diagnostics.dart';
import 'package:stroom/utils/ocr_request_size_failure_summary.dart';

void main() {
  test(
    'request-size summaries persist safely and re-localize exact byte counts',
    () {
      final target = lookupAppLocalizations(const Locale('en', 'US'));

      for (final locale in AppLocalizations.supportedLocales) {
        final source = lookupAppLocalizations(locale);
        final summary = source.bgTaskOcrRequestSizeExceeded(123456, 200000);

        expect(
          OcrRequestSizeFailureSummary.isKnownLocalizedSummary(summary),
          isTrue,
        );
        expect(
          OcrRequestSizeFailureSummary.localize(summary, target),
          target.bgTaskOcrRequestSizeExceeded(123456, 200000),
        );
        expect(OcrDiagnosticSnapshot.sanitizeStoredTaskError(summary), summary);
        final wrappedSummary = source.bgTaskOcrError(summary);
        expect(
          OcrDiagnosticSnapshot.sanitizeStoredTaskError(wrappedSummary),
          wrappedSummary,
        );
      }

      const arbitrary = 'OCR request JSON size is 123456 bytes; token=secret';
      expect(
        OcrRequestSizeFailureSummary.isKnownLocalizedSummary(arbitrary),
        isFalse,
      );
      expect(OcrRequestSizeFailureSummary.localize(arbitrary, target), isNull);
      expect(
        OcrDiagnosticSnapshot.sanitizeStoredTaskError(arbitrary),
        isNot(arbitrary),
      );
    },
  );
}
