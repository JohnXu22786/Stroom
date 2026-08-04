package com.johntsui.stroom

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import id.flutter.flutter_background_service.BackgroundService

/**
 * AlarmManager-based keep-alive watchdog for the foreground service.
 *
 * Android (especially Chinese ROMs) may kill the app process even when a
 * foreground service is active. This receiver schedules a periodic alarm
 * that, when fired, tries to restart the foreground service. If the process
 * is already running with the service active, the alarm is a no-op.
 *
 * Scheduling strategy:
 * - Prefer an **exact** alarm ([AlarmManager.setExactAndAllowWhileIdle])
 *   when the app is allowed to schedule exact alarms. On Android 12+
 *   (API 31+) an exact alarm is one of the documented exemptions that allow
 *   an app to start a foreground service from the background, so the
 *   watchdog actually works after the process has been killed.
 * - Fall back to [AlarmManager.setAndAllowWhileIdle] when exact alarms are
 *   not permitted (Android 14+ denies SCHEDULE_EXACT_ALARM by default).
 *   The alarm may be deferred a bit by the system, but still fires in
 *   Doze mode. NOTE: inexact alarms are NOT exempt from the Android 12+
 *   background-start restriction — the restart then depends on the user
 *   having granted the battery-optimization exemption (requested via
 *   requestIgnoreBatteryOptimizations).
 * - Pre-M (API < 23): repeating alarm.
 * - The alarm is a one-shot that re-schedules itself on every fire, so a
 *   single failed firing (e.g. ForegroundServiceStartNotAllowedException
 *   on a device without battery-optimization exemption) never kills the
 *   watchdog permanently.
 *
 * Failure backoff: Android 15+ caps dataSync foreground services at 6h per
 * 24h; once exhausted every start throws. After 3 consecutive failures the
 * watchdog backs off to a 30-minute interval instead of waking the device
 * every 5 minutes forever. Any successful start, or an explicit
 * startKeepAlive from Dart (user start / cold-start restore / app resume),
 * resets the counter.
 *
 * Lifecycle:
 * 1. [scheduleAlarm] — called from Dart via MethodChannel when the
 *    background service is started. Schedules the next alarm and persists
 *    that the watchdog is active.
 * 2. [cancelAlarm] — called when the background service is stopped.
 * 3. On [Intent.ACTION_BOOT_COMPLETED] / [Intent.ACTION_MY_PACKAGE_REPLACED]
 *    / QUICKBOOT_POWERON / SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED the
 *    alarm is re-scheduled if it was previously active (persisted via
 *    SharedPreferences). Only the alarm is re-scheduled, never a direct
 *    foreground-service start — Android 15+ forbids starting a dataSync
 *    foreground service from BOOT_COMPLETED, while starting from an exact
 *    alarm is an allowed exemption.
 */
class KeepAliveReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KeepAliveReceiver"
        private const val ALARM_REQUEST_CODE = 2001
        private const val KEEP_ALIVE_INTERVAL_MS = 5 * 60 * 1000L // 5 minutes

        // 连续启动失败后的退避间隔（见类注释）。
        private const val MAX_CONSECUTIVE_FAILURES = 3
        private const val FAILURE_BACKOFF_INTERVAL_MS = 30 * 60 * 1000L

        const val ACTION_KEEP_ALIVE = "com.johntsui.stroom.KEEP_ALIVE"

        // SharedPreferences keys — mirror the Dart side's keys.
        // shared_preferences persists them with a "flutter." prefix.
        private const val PREF_NAME = "FlutterSharedPreferences"
        private const val KEY_SERVICE_ENABLED = "flutter.background_service_enabled"
        private const val KEY_KEEP_ALIVE_ACTIVE = "flutter.keep_alive_active"
        private const val KEY_KEEP_ALIVE_FAILURES = "flutter.keep_alive_failures"

        /**
         * Schedule the next keep-alive alarm (one-shot, self-rescheduling).
         * Safe to call multiple times; the existing alarm is replaced.
         */
        fun scheduleAlarm(context: Context, intervalMs: Long = KEEP_ALIVE_INTERVAL_MS) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = createPendingIntent(context, PendingIntent.FLAG_UPDATE_CURRENT)
            val triggerAt = SystemClock.elapsedRealtime() + intervalMs

            // 在调度之前先持久化「闹钟已激活」标记：无论走主路径还是
            // 降级路径，设备重启后 BOOT_COMPLETED 都能恢复调度。
            markActive(context, true)

            // Prefer exact alarms: on Android 12+ an exact alarm is an
            // exemption that permits starting a foreground service from the
            // background, and it is not deferred by Doze.
            // Note: in Doze, setExactAndAllowWhileIdle is throttled to about
            // once per 9 minutes, so the effective interval may stretch.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
                    Log.i(TAG, "Keep-alive exact alarm scheduled (interval=${intervalMs / 60000}min)")
                    return
                } catch (e: SecurityException) {
                    // canScheduleExactAlarms raced or permission revoked — fall through.
                    Log.w(TAG, "Exact alarm denied, falling back to inexact", e)
                }
            }
            // setAndAllowWhileIdle requires no permission; the system may
            // defer the delivery a little to batch wake-ups.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
                Log.i(TAG, "Keep-alive inexact alarm scheduled (interval=${intervalMs / 60000}min)")
            } else {
                alarmManager.setInexactRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    KEEP_ALIVE_INTERVAL_MS,
                    pendingIntent
                )
                Log.i(TAG, "Keep-alive repeating alarm scheduled (interval=${KEEP_ALIVE_INTERVAL_MS / 60000}min)")
            }
        }

        /**
         * Cancel the keep-alive alarm and persist that it is inactive.
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            val pendingIntent = createPendingIntent(context, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.i(TAG, "Keep-alive alarm cancelled")
            }
            markActive(context, false)
        }

        /**
         * Reset the consecutive-failure counter. Called when the Dart side
         * explicitly (re)arms the watchdog (user start / cold-start restore),
         * giving the watchdog a fresh chance at the normal interval.
         */
        fun resetFailureCount(context: Context) {
            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_KEEP_ALIVE_FAILURES, 0)
                .apply()
        }

        private fun markActive(context: Context, active: Boolean) {
            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_KEEP_ALIVE_ACTIVE, active)
                .apply()
        }

        private fun createPendingIntent(context: Context, extraFlags: Int): PendingIntent {
            val intent = Intent(context, KeepAliveReceiver::class.java).apply {
                action = ACTION_KEEP_ALIVE
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or extraFlags
            } else {
                extraFlags
            }
            return PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, flags)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            // 用户授予「精确闹钟」权限后系统会发送此广播（撤销时不会发送，
            // 且撤销会静默删除所有精确闹钟）。授予后立即恢复精确调度；
            // 撤销场景由 Dart 侧在应用回到前台时补武装（见
            // BackgroundService.rearmKeepAliveOnResume）。
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" -> {
                // 开机 / 应用更新 / 快速开机 / 闹钟权限变化后系统可能清除闹钟：
                // 如果之前看门狗处于激活状态，重新调度。注意：这里只重新调度
                // 闹钟，不直接启动前台服务 —— Android 15+ 禁止从 BOOT_COMPLETED
                // 直接启动 dataSync 前台服务，而闹钟触发后启动则属于精确闹钟
                // 豁免场景。
                Log.i(TAG, "${intent.action} — checking if keep-alive should be re-scheduled")
                val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                if (prefs.getBoolean(KEY_KEEP_ALIVE_ACTIVE, false)) {
                    scheduleAlarm(context)
                }
            }

            ACTION_KEEP_ALIVE -> {
                val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                val serviceEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
                if (!serviceEnabled) {
                    // 用户已明确停止后台服务：取消闹钟，绝不复活服务。
                    Log.i(TAG, "Keep-alive alarm fired but service disabled — cancelling watchdog")
                    cancelAlarm(context)
                    return
                }

                var startSucceeded = true
                if (!isServiceRunning(context)) {
                    try {
                        // 进程被系统杀掉后，这里会冷启动进程并重建前台服务；
                        // 插件会重新初始化 Flutter engine 并恢复后台任务。
                        val serviceIntent = Intent(context, BackgroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                        Log.d(TAG, "Foreground service start requested")
                    } catch (e: Exception) {
                        // Android 12+ 后台启动前台服务限制
                        // （ForegroundServiceStartNotAllowedException），
                        // 或 Android 15+ dataSync 6 小时/24 小时上限耗尽：
                        // 属于瞬时/上限失败 —— 用户授予电池优化豁免、冷启动
                        // 恢复或下一个周期会重新尝试。记录失败次数。
                        startSucceeded = false
                        Log.e(TAG, "Failed to start foreground service via keep-alive", e)
                    }
                }

                if (startSucceeded) {
                    // 成功（服务已在运行或已启动）：重置连续失败计数。
                    prefs.edit().putInt(KEY_KEEP_ALIVE_FAILURES, 0).apply()
                    scheduleAlarm(context)
                } else {
                    // 连续失败达到阈值后进入退避周期，避免看门狗持续
                    // 唤醒设备做无效尝试。计数封顶，避免无限增长。
                    val failures = (prefs.getInt(KEY_KEEP_ALIVE_FAILURES, 0) + 1)
                        .coerceAtMost(MAX_CONSECUTIVE_FAILURES + 1)
                    prefs.edit().putInt(KEY_KEEP_ALIVE_FAILURES, failures).apply()
                    if (failures >= MAX_CONSECUTIVE_FAILURES) {
                        Log.w(
                            TAG,
                            "Keep-alive start failed $failures times consecutively — " +
                                "backing off to ${FAILURE_BACKOFF_INTERVAL_MS / 60000}min interval"
                        )
                        scheduleAlarm(context, FAILURE_BACKOFF_INTERVAL_MS)
                    } else {
                        scheduleAlarm(context)
                    }
                }
            }
        }
    }

    /// 检查插件的前台服务当前是否在运行。
    private fun isServiceRunning(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val serviceClass = BackgroundService::class.java.name
        for (info in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass == info.service.className) {
                return true
            }
        }
        return false
    }
}
