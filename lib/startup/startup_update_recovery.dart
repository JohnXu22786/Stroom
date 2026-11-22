import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The exact app versions involved in one update installation attempt.
///
/// This record is deliberately independent of the ordinary update selection
/// cache: a rollback is justified only by the source version that was running
/// immediately before the failed target build was installed.
class StartupUpdateAttempt {
  static const String storageKey = 'startup_update_attempt';
  static final RegExp _exactVersion = RegExp(
    r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final String sourceVersion;
  final String targetVersion;

  const StartupUpdateAttempt({
    required this.sourceVersion,
    required this.targetVersion,
  });

  static bool isExactVersion(String value) => _exactVersion.hasMatch(value);

  /// Returns false when the preferences store cannot persist the evidence.
  static Future<bool> record({
    required String sourceVersion,
    required String targetVersion,
  }) async {
    if (!isExactVersion(sourceVersion) || !isExactVersion(targetVersion)) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        storageKey,
        jsonEncode({
          'sourceVersion': sourceVersion,
          'targetVersion': targetVersion,
        }),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // Startup can proceed safely without being able to clear stale evidence.
    }
  }

  static Future<StartupUpdateAttempt?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final source = decoded['sourceVersion'];
      final target = decoded['targetVersion'];
      if (source is! String ||
          target is! String ||
          !isExactVersion(source) ||
          !isExactVersion(target)) {
        return null;
      }
      return StartupUpdateAttempt(sourceVersion: source, targetVersion: target);
    } catch (_) {
      return null;
    }
  }

  bool matchesFrozenTarget({
    required String? frozenByVersion,
    required String runningVersion,
  }) =>
      frozenByVersion != null &&
      targetVersion == frozenByVersion &&
      targetVersion == runningVersion;
}

/// The single evidence-backed release Stroom may offer as startup recovery.
class StartupRollbackCandidate {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const StartupRollbackCandidate({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  static StartupRollbackCandidate? fromReleases({
    required String sourceVersion,
    required String platformKey,
    required List<dynamic> releases,
  }) {
    if (!StartupUpdateAttempt.isExactVersion(sourceVersion)) return null;
    final normalizedSource = sourceVersion.replaceFirst(RegExp(r'^v'), '');

    for (final release in releases) {
      if (release is! Map) continue;
      final rawTag = release['tag_name'];
      if (rawTag is! String ||
          rawTag.replaceFirst(RegExp(r'^v'), '') != normalizedSource) {
        continue;
      }
      final assets = release['assets'];
      if (assets is! List) continue;
      final url = _directPlatformAsset(assets, platformKey);
      if (url == null) continue;
      final notes = release['body'];
      return StartupRollbackCandidate(
        version: normalizedSource,
        releaseNotes: notes is String ? notes : '',
        downloadUrl: url,
      );
    }
    return null;
  }

  static String? _directPlatformAsset(
    List<dynamic> assets,
    String platformKey,
  ) {
    final key = platformKey.toLowerCase();
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final rawUrl = asset['browser_download_url'];
      if (name is! String ||
          rawUrl is! String ||
          !name.toLowerCase().contains(key)) {
        continue;
      }
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'github.com' ||
          !uri.path.contains('/releases/download/')) {
        continue;
      }
      return rawUrl;
    }
    return null;
  }
}
