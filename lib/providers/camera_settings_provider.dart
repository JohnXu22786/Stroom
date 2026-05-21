import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>(
  (ref) => CameraSettingsNotifier(),
);

class CameraSettings {
  final bool saveToGallery;
  final bool highQuality;
  final double compressionQuality;

  const CameraSettings({
    this.saveToGallery = true,
    this.highQuality = false,
    this.compressionQuality = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'saveToGallery': saveToGallery,
      'highQuality': highQuality,
      'compressionQuality': compressionQuality,
    };
  }

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      saveToGallery: json['saveToGallery'] as bool? ?? true,
      highQuality: json['highQuality'] as bool? ?? false,
      compressionQuality: (json['compressionQuality'] as num?)?.toDouble() ?? 1.0,
    );
  }

  CameraSettings copyWith({
    bool? saveToGallery,
    bool? highQuality,
    double? compressionQuality,
  }) {
    return CameraSettings(
      saveToGallery: saveToGallery ?? this.saveToGallery,
      highQuality: highQuality ?? this.highQuality,
      compressionQuality: compressionQuality ?? this.compressionQuality,
    );
  }
}

class CameraSettingsNotifier extends StateNotifier<CameraSettings> {
  CameraSettingsNotifier() : super(const CameraSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('camera_settings');
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = CameraSettings.fromJson(json);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camera_settings', jsonEncode(state.toJson()));
  }

  Future<void> setSaveToGallery(bool value) async {
    state = state.copyWith(saveToGallery: value);
    await _persist();
  }

  Future<void> setHighQuality(bool value) async {
    state = state.copyWith(highQuality: value);
    await _persist();
  }

  Future<void> setCompressionQuality(double value) async {
    state = state.copyWith(compressionQuality: value);
    await _persist();
  }
}
