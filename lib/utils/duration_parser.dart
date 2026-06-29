class DurationResult {
  final int hours;
  final int minutes;
  final int seconds;
  const DurationResult(
      {required this.hours, required this.minutes, required this.seconds});
}

int totalSeconds({int hours = 0, int minutes = 0, int seconds = 0}) {
  return hours * 3600 + minutes * 60 + seconds;
}

String formatHms(DurationResult d) {
  final h = d.hours.toString().padLeft(2, '0');
  final m = d.minutes.toString().padLeft(2, '0');
  final s = d.seconds.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

DurationResult? parseSmartDuration(String text) {
  final numbers = text
      .split(RegExp(r'[^\d]+'))
      .where((s) => s.isNotEmpty)
      .map(int.parse)
      .toList();
  if (numbers.isEmpty) return null;

  var h = 0, m = 0, s = 0;
  if (numbers.length == 1) {
    s = numbers[0];
    m = s ~/ 60;
    s = s % 60;
    h = m ~/ 60;
    m = m % 60;
    return DurationResult(hours: h, minutes: m, seconds: s);
  }
  if (numbers.length == 2) {
    m = numbers[0];
    s = numbers[1];
    if (m > 59 || s > 59) return null;
    return DurationResult(hours: 0, minutes: m, seconds: s);
  }
  h = numbers[0];
  m = numbers[1];
  s = numbers[2];
  if (m > 59 || s > 59) return null;
  return DurationResult(hours: h, minutes: m, seconds: s);
}

String formatDurationDisplay(DurationResult d) {
  final parts = <String>[];
  if (d.hours > 0) parts.add('${d.hours}时');
  if (d.minutes > 0 || d.hours > 0) parts.add('${d.minutes}分');
  parts.add('${d.seconds}秒');
  return parts.join('');
}
