import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Handles actions sent from the native macOS application menu.
class MacOSMenuService {
  MacOSMenuService(this._navigatorKey);

  static const channelName = 'com.johntsui.stroom/menu';
  static const _channel = MethodChannel(channelName);
  static GlobalKey<NavigatorState>? _activeNavigatorKey;
  static bool _handlerInstalled = false;
  static bool _pendingSettingsRequest = false;

  final GlobalKey<NavigatorState> _navigatorKey;

  /// Register before startup awaits so a menu selection cannot be lost.
  static void installPlatformHandler() {
    if (!_handlerInstalled) {
      _channel.setMethodCallHandler(_handleMethodCall);
      _handlerInstalled = true;
    }
    unawaited(_signalHandlerReady());
  }

  static Future<void> _signalHandlerReady() async {
    try {
      await _channel.invokeMethod<void>('menuHandlerReady');
    } on MissingPluginException {
      // The native macOS channel is unavailable in unit tests and on other
      // platforms; macOS Application.attach retries after startup.
    }
  }

  void attach() {
    installPlatformHandler();
    _activeNavigatorKey = _navigatorKey;
    _schedulePendingSettingsRequest();
  }

  static void _schedulePendingSettingsRequest() {
    if (!_pendingSettingsRequest || _activeNavigatorKey == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _activeNavigatorKey?.currentState;
      if (!_pendingSettingsRequest || navigator == null) return;

      _pendingSettingsRequest = false;
      navigator.pushNamed('/settings');
    });
  }

  void dispose() {
    if (identical(_activeNavigatorKey, _navigatorKey)) {
      _activeNavigatorKey = null;
    }
  }

  static void resetForTesting() {
    _channel.setMethodCallHandler(null);
    _handlerInstalled = false;
    _activeNavigatorKey = null;
    _pendingSettingsRequest = false;
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'openSettings':
        final navigator = _activeNavigatorKey?.currentState;
        if (navigator == null) {
          _pendingSettingsRequest = true;
          _schedulePendingSettingsRequest();
        } else {
          navigator.pushNamed('/settings');
        }
      default:
        throw MissingPluginException(
          'Unknown macOS menu action: ${call.method}',
        );
    }
  }
}
