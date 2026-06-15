import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cameraSettingsProvider =
    StateNotifierProvider<CameraSettingsNotifier, CameraSettings>(
  (ref) => CameraSettingsNotifier(),
);

class CameraSettings {
  final double compressionQuality;

  const CameraSettings({
    this.compressionQuality = 0.8,
  });

  Map<String, dynamic> toJson() {
    return {
      'compressionQuality': compressionQuality,
    };
  }

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      compressionQuality: (json['compressionQuality'] as num?)?.toDouble() ?? 0.8,
    );
  }

  CameraSettings copyWith({
    double? compressionQuality,
  }) {
    return CameraSettings(
      compressionQuality: compressionQuality ?? this.compressionQuality,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraSettings &&
          runtimeType == other.runtimeType &&
          compressionQuality == other.compressionQuality;

  @override
  int get hashCode => compressionQuality.hashCode;
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

  Future<void> setCompressionQuality(double value) async {
    state = state.copyWith(compressionQuality: value);
    await _persist();
  }
}
