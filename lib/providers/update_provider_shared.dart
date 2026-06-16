class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  Version._({required this.major, required this.minor, required this.patch});

  factory Version.parse(String versionString) {
    final cleaned = versionString.replaceAll(RegExp(r'^v'), '');
    final base = cleaned.split('+').first.split('-').first;
    final parts = base.split('.');
    return Version._(
      major: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minor: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      patch: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
}
