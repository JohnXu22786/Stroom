import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/notification_service.dart';

// ============================================================================
// Notification Payload Provider
// ============================================================================

/// Provider that holds the current active in-app notification payload.
/// Set to null to dismiss.
final inAppNotificationProvider = StateProvider<NotificationPayload?>(
  (ref) => null,
);

// ============================================================================
// Notification Settings Provider
// ============================================================================

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, bool>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettingsNotifier extends StateNotifier<bool> {
  NotificationSettingsNotifier() : super(false);

  Future<void> load() async {
    final enabled = await NotificationService().isEnabled;
    state = enabled;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await NotificationService().setEnabled(value);
  }
}
