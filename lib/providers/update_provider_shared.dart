/// A semantic version that preserves pre-release information.
///
/// Examples:
///   - "1.0.0"          → major=1, minor=0, patch=0, preRelease=null
///   - "1.0.0-alpha"    → major=1, minor=0, patch=0, preRelease="alpha"
///   - "1.0.0-beta.1"   → major=1, minor=0, patch=0, preRelease="beta.1"
///   - "v1.0.0-alpha"   → same as above (leading 'v' stripped)
///   - "1.0.0-alpha+001" → preRelease="alpha" (build metadata stripped)
///
/// Comparison rules follow semver:
///   - Base version (major.minor.patch) is compared first.
///   - If base versions differ, the higher base wins regardless of pre-release.
///   - If base versions are equal, release (no pre-release) > any pre-release.
///   - If both have pre-release, compare the identifiers lexicographically.
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  /// The pre-release identifier (e.g., "alpha", "beta.1", "rc.2").
  /// Null means this is a release version.
  final String? preRelease;

  bool get isPreRelease => preRelease != null;

  const Version._({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
  });

  factory Version.parse(String versionString) {
    final cleaned = versionString.replaceAll(RegExp(r'^v'), '');
    // Remove build metadata (+...)
    final withoutBuild = cleaned.split('+').first;
    // Split on '-' to get base and pre-release
    final parts = withoutBuild.split('-');
    final baseParts = parts.first.split('.');
    final preRelease = parts.length > 1 ? parts.sublist(1).join('-') : null;
    return Version._(
      major: baseParts.isNotEmpty ? int.tryParse(baseParts[0]) ?? 0 : 0,
      minor: baseParts.length > 1 ? int.tryParse(baseParts[1]) ?? 0 : 0,
      patch: baseParts.length > 2 ? int.tryParse(baseParts[2]) ?? 0 : 0,
      preRelease: preRelease,
    );
  }

  @override
  int compareTo(Version other) {
    // Compare base version first
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // Same base version: compare pre-release
    if (preRelease == other.preRelease) return 0;
    // Release (no pre-release) > pre-release
    if (preRelease == null) return 1;
    if (other.preRelease == null) return -1;
    // Both have pre-release: compare lexicographically
    return preRelease!.compareTo(other.preRelease!);
  }

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >=(Version other) => compareTo(other) >= 0;

  @override
  String toString() {
    if (preRelease != null) {
      return '$major.$minor.$patch-$preRelease';
    }
    return '$major.$minor.$patch';
  }
}
