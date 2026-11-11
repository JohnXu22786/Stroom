import '../l10n/app_localizations.dart';

/// Parses app-authored per-page OCR failure summaries across supported locales.
///
/// Matching the complete localized templates keeps arbitrary provider text out
/// of the set of summaries that may be persisted or re-localized.
class OcrPageFailureSummary {
  OcrPageFailureSummary._();

  static const _detailMarker = '__OCR_PAGE_FAILURE_DETAILS__';
  static const _indexMarker = '7391846250';

  static bool isKnownLocalizedSummary(String value) => _parse(value) != null;

  static String? localize(String value, AppLocalizations strings) {
    final pages = _parse(value);
    if (pages == null) return null;

    final details = pages
        .map((page) {
          return page.incomplete
              ? strings.bgTaskOcrPageIncomplete(page.index)
              : strings.bgTaskOcrPageFailed(page.index);
        })
        .join(strings.bgTaskOcrPageFailureSeparator);
    return strings.bgTaskOcrPagesIncomplete(details);
  }

  static List<_OcrPageFailure>? _parse(String value) {
    for (final locale in AppLocalizations.supportedLocales) {
      final source = lookupAppLocalizations(locale);
      final outer = source.bgTaskOcrPagesIncomplete(_detailMarker);
      final markerOffset = outer.indexOf(_detailMarker);
      if (markerOffset < 0) continue;
      final prefix = outer.substring(0, markerOffset);
      final suffix = outer.substring(markerOffset + _detailMarker.length);
      if (!value.startsWith(prefix) || !value.endsWith(suffix)) continue;
      if (value.length < prefix.length + suffix.length) continue;

      final details = value.substring(
        prefix.length,
        value.length - suffix.length,
      );
      final separator = source.bgTaskOcrPageFailureSeparator;
      if (separator.isEmpty) continue;
      final parts = details.split(separator);
      if (parts.isEmpty || parts.any((part) => part.isEmpty)) continue;

      final pages = <_OcrPageFailure>[];
      for (final part in parts) {
        final page = _parsePage(part, source);
        if (page == null) {
          pages.clear();
          break;
        }
        pages.add(page);
      }
      if (pages.isNotEmpty) return pages;
    }
    return null;
  }

  static _OcrPageFailure? _parsePage(String value, AppLocalizations strings) {
    for (final (template, incomplete) in <(String, bool)>[
      (strings.bgTaskOcrPageIncomplete(_indexMarker), true),
      (strings.bgTaskOcrPageFailed(_indexMarker), false),
    ]) {
      final markerOffset = template.indexOf(_indexMarker);
      if (markerOffset < 0) continue;
      final prefix = template.substring(0, markerOffset);
      final suffix = template.substring(markerOffset + _indexMarker.length);
      if (!value.startsWith(prefix) || !value.endsWith(suffix)) continue;
      if (value.length < prefix.length + suffix.length) continue;

      final index = value.substring(
        prefix.length,
        value.length - suffix.length,
      );
      if (index.isEmpty || !RegExp(r'^\d+$').hasMatch(index)) continue;
      return _OcrPageFailure(index: index, incomplete: incomplete);
    }
    return null;
  }
}

class _OcrPageFailure {
  const _OcrPageFailure({required this.index, required this.incomplete});

  final String index;
  final bool incomplete;
}
