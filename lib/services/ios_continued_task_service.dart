import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

/// iOS 26+ 常驻后台任务桥接（BGContinuedProcessingTask）。
///
/// 机制：后台任务在前台启动时（用户操作）提交一个「继续处理任务」
/// 请求；用户切到后台或锁屏后，系统保持进程运行，任务继续执行，
/// 并在系统 UI（灵动岛 / 锁屏）显示进度。全部任务结束后调用
/// [complete] 通知系统。
///
/// 原生侧实现位于 ios/Runner/AppDelegate.swift；
/// 低版本 iOS（< 26）上所有调用均为安全空操作（Dart 侧门控 +
/// 原生 #available 双重保护）。
class IosContinuedTaskService {
  IosContinuedTaskService._();

  static final IosContinuedTaskService instance = IosContinuedTaskService._();

  /// Method channel name — must match ios/Runner/AppDelegate.swift.
  static const _channel =
      MethodChannel('com.johntsui.stroom/ios_continued_task');

  /// 测试专用：强制视为 iOS 26+（测试机为 Windows/macOS 主机，
  /// 无法真实判断 iOS 版本）。
  @visibleForTesting
  static bool debugForceSupported = false;

  /// 当前平台是否支持常驻后台任务（iOS 26+）。
  bool get isSupported {
    if (debugForceSupported) return true;
    if (!Platform.isIOS) return false;
    try {
      final parts = Platform.operatingSystemVersion.split('.');
      final major = parts.isEmpty ? 0 : int.tryParse(parts.first) ?? 0;
      return major >= 26;
    } catch (_) {
      return false;
    }
  }

  /// 提交常驻后台任务请求。
  ///
  /// 幂等：原生侧在已有激活任务时跳过提交；任务被系统终止后
  /// 下一次同步会自动重新建立保护（App 回到前台时）。
  Future<void> submit({String? title}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('submit', {
        'title': title ?? 'Stroom 后台任务',
      });
    } catch (e) {
      debugPrint('[IosContinuedTask] submit failed: $e');
    }
  }

  /// 更新系统进度 UI（0–100，整数百分比）。
  Future<void> updateProgress(int percent) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('updateProgress', {'percent': percent});
    } catch (e) {
      debugPrint('[IosContinuedTask] updateProgress failed: $e');
    }
  }

  /// 全部任务结束：通知系统完成常驻任务。
  Future<void> complete() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('complete');
    } catch (e) {
      debugPrint('[IosContinuedTask] complete failed: $e');
    }
  }
}
