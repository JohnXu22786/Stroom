import '../l10n/app_localizations.dart';

/// Parses app-authored OCR request-size summaries so they can be safely
/// persisted and re-localized without accepting arbitrary provider text.
class OcrRequestSizeFailureSummary {
  OcrRequestSizeFailureSummary._();

  static const _encodedBytesMarker = 913735284;
  static const _budgetBytesMarker = 827164953;

  static bool isKnownLocalizedSummary(String value) => _parse(value) != null;

  static String? localize(String value, AppLocalizations strings) {
    final bytes = _parse(value);
    if (bytes == null) return null;
    return strings.bgTaskOcrRequestSizeExceeded(bytes.$1, bytes.$2);
  }

  static (int, int)? _parse(String value) {
    for (final locale in AppLocalizations.supportedLocales) {
      final strings = lookupAppLocalizations(locale);
      final template = strings.bgTaskOcrRequestSizeExceeded(
        _encodedBytesMarker,
        _budgetBytesMarker,
      );
      final encodedMarker = _encodedBytesMarker.toString();
      final budgetMarker = _budgetBytesMarker.toString();
      final encodedOffset = template.indexOf(encodedMarker);
      final budgetOffset = template.indexOf(budgetMarker);
      if (encodedOffset < 0 || budgetOffset < encodedOffset) continue;

      final prefix = template.substring(0, encodedOffset);
      final separator = template.substring(
        encodedOffset + encodedMarker.length,
        budgetOffset,
      );
      final suffix = template.substring(
        budgetOffset + budgetMarker.length,
      );
      if (!value.startsWith(prefix) || !value.endsWith(suffix)) continue;
      if (value.length < prefix.length + suffix.length) continue;

      final details = value.substring(
        prefix.length,
        value.length - suffix.length,
      );
      final separatorOffset = details.indexOf(separator);
      if (separatorOffset < 0 || separator.isEmpty) continue;
      final encodedText = details.substring(0, separatorOffset);
      final budgetText = details.substring(separatorOffset + separator.length);
      if (!RegExp(r'^\d+$').hasMatch(encodedText) ||
          !RegExp(r'^\d+$').hasMatch(budgetText)) {
        continue;
      }

      final encodedBytes = int.tryParse(encodedText);
      final budgetBytes = int.tryParse(budgetText);
      if (encodedBytes != null && budgetBytes != null) {
        return (encodedBytes, budgetBytes);
      }
    }
    return null;
  }
}
