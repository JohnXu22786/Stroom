import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>(
  (ref) => CameraSettingsNotifier(),
);

class CameraSettings {
  final bool saveToGallery;
  final double compressionQuality;

  const CameraSettings({
    this.saveToGallery = true,
    this.compressionQuality = 0.8,
  });

  Map<String, dynamic> toJson() {
    return {
      'saveToGallery': saveToGallery,
      'compressionQuality': compressionQuality,
    };
  }

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      saveToGallery: json['saveToGallery'] as bool? ?? true,
      compressionQuality: (json['compressionQuality'] as num?)?.toDouble() ?? 0.8,
    );
  }

  CameraSettings copyWith({
    bool? saveToGallery,
    double? compressionQuality,
  }) {
    return CameraSettings(
      saveToGallery: saveToGallery ?? this.saveToGallery,
      compressionQuality: compressionQuality ?? this.compressionQuality,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraSettings &&
          runtimeType == other.runtimeType &&
          saveToGallery == other.saveToGallery &&
          compressionQuality == other.compressionQuality;

  @override
  int get hashCode => Object.hash(saveToGallery, compressionQuality);
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

  Future<void> setCompressionQuality(double value) async {
    state = state.copyWith(compressionQuality: value);
    await _persist();
  }
}
