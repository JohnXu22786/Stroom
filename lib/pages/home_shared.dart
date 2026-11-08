import '../l10n/app_localizations.dart';

String formatDurationShort(String durationStr, AppLocalizations l10n) {
  final parts = durationStr.split(':');
  if (parts.length != 3) return durationStr;
  final secondsParts = parts[2].split('.');
  final isDigits = RegExp(r'^\d+$').hasMatch;
  if (!isDigits(parts[0]) ||
      !isDigits(parts[1]) ||
      !isDigits(secondsParts[0]) ||
      secondsParts.length > 2 ||
      (secondsParts.length == 2 && !isDigits(secondsParts[1]))) {
    return durationStr;
  }
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final s = int.tryParse(secondsParts[0]);
  if (h == null || m == null || s == null) return durationStr;
  if (h > 0) return l10n.homeMediaDurationHoursMinutesSeconds(h, m, s);
  if (m > 0) return l10n.unifiedDurationMinutesSeconds(m, s);
  return l10n.unifiedDurationSeconds(s);
}
