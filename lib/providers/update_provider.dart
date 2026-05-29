import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_version.dart';

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(),
);

class UpdateState {
  final bool isChecking;
  final String? latestVersion;
  final bool mandatory;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? error;
  final bool updateAvailable;

  const UpdateState({
    this.isChecking = false,
    this.latestVersion,
    this.mandatory = false,
    this.releaseNotes,
    this.downloadUrl,
    this.error,
    this.updateAvailable = false,
  });

  UpdateState copyWith({
    bool? isChecking,
    String? latestVersion,
    bool? mandatory,
    String? releaseNotes,
    String? downloadUrl,
    String? error,
    bool? updateAvailable,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      latestVersion: latestVersion ?? this.latestVersion,
      mandatory: mandatory ?? this.mandatory,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: error ?? this.error,
      updateAvailable: updateAvailable ?? this.updateAvailable,
    );
  }
}

class _Version implements Comparable<_Version> {
  final int major;
  final int minor;
  final int patch;

  _Version._({required this.major, required this.minor, required this.patch});

  factory _Version.parse(String versionString) {
    final cleaned = versionString.replaceAll(RegExp(r'^v'), '');
    final parts = cleaned.split('+').first.split('.');
    return _Version._(
      major: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minor: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      patch: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  @override
  int compareTo(_Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(_Version other) => compareTo(other) < 0;
  bool operator >(_Version other) => compareTo(other) > 0;
  bool operator <=(_Version other) => compareTo(other) <= 0;
  bool operator >=(_Version other) => compareTo(other) >= 0;
}

const String _kUpdateCheckUrl = 'https://raw.githubusercontent.com/JohnXu22786/Stroom/main/version.json';
const String _kSkippedVersionKey = 'update_skipped_version';
const String _kUpdateAvailableKey = 'update_available_data';

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  Future<void> checkForUpdate({bool silent = false}) async {
    if (state.isChecking) return;

    state = state.copyWith(isChecking: true, error: null);

    try {
      final response = await Dio().get(_kUpdateCheckUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.data.toString()) as Map<String, dynamic>;
        final latestVersion = data['latest_version'] as String? ?? '';
        final minimumVersion = data['minimum_version'] as String? ?? '';
        final mandatory = data['mandatory'] as bool? ?? false;
        final releaseNotes = data['release_notes'] as String? ?? '';
        final downloadUrl = data['download_url'] as String? ?? '';

        final current = _Version.parse(appVersion);
        final latest = _Version.parse(latestVersion);
        final minVersion = _Version.parse(minimumVersion);

        final updateAvailable = latest > current;
        final isMandatory = mandatory || (minVersion > current);

        if (updateAvailable) {
          final prefs = await SharedPreferences.getInstance();
          final skippedVersion = prefs.getString(_kSkippedVersionKey);

          if (skippedVersion == latestVersion && !isMandatory) {
            state = const UpdateState();
            return;
          }

          final updateData = jsonEncode({
            'latest_version': latestVersion,
            'mandatory': isMandatory,
            'release_notes': releaseNotes,
            'download_url': downloadUrl,
          });
          await prefs.setString(_kUpdateAvailableKey, updateData);

          state = UpdateState(
            updateAvailable: true,
            latestVersion: latestVersion,
            mandatory: isMandatory,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl,
          );
        } else {
          state = const UpdateState();
        }
      } else {
        if (!silent) {
          state = state.copyWith(
            isChecking: false,
            error: '检查更新失败: HTTP ${response.statusCode}',
          );
        } else {
          state = const UpdateState();
        }
      }
    } catch (e) {
      if (!silent) {
        state = state.copyWith(
          isChecking: false,
          error: '网络错误: $e',
        );
      } else {
        state = const UpdateState();
      }
    }
  }

  Future<Map<String, dynamic>?> getPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUpdateAvailableKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>?;
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSkippedVersionKey, version);
    await prefs.remove(_kUpdateAvailableKey);
    state = const UpdateState();
  }

  Future<void> clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUpdateAvailableKey);
    state = const UpdateState();
  }
}
