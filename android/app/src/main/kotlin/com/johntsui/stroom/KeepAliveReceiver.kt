package com.johntsui.stroom

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * AlarmManager-based keep-alive watchdog for the foreground service.
 *
 * Android (especially Chinese ROMs) may kill the app process even when a
 * foreground service is active. This receiver schedules a periodic
 * keep-alive alarm that, when fired, tries to restart the foreground
 * service. If the process is already running with the service active,
 * the alarm is a no-op.
 *
 * Lifecycle:
 * 1. [scheduleAlarm] — called from Dart via MethodChannel when the
 *    background service is started. Schedules the keep-alive alarm.
 * 2. [cancelAlarm] — called when the background service is stopped.
 * 3. On [Intent.ACTION_BOOT_COMPLETED], the alarm is re-scheduled if
 *    it was previously active (persisted via SharedPreferences).
 * 4. After every alarm fire, [onReceive] re-schedules the next one
 *    (the modern alarm types used here are one-shot).
 */
class KeepAliveReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KeepAliveReceiver"
        private const val ALARM_REQUEST_CODE = 2001
        private const val KEEP_ALIVE_INTERVAL_MS = 5 * 60 * 1000L // 5 minutes

        // SharedPreferences key — mirrors the Dart side's
        // _backgroundServiceEnabledKey. Written from Kotlin so that the
        // BOOT_COMPLETED handler can decide whether to re-schedule.
        private const val PREF_NAME = "FlutterSharedPreferences"
        private const val KEY_SERVICE_ENABLED = "flutter.background_service_enabled"
        private const val KEY_KEEP_ALIVE_ACTIVE = "flutter.keep_alive_active"

        /**
         * Schedule the keep-alive alarm.
         * Safe to call multiple times; the existing alarm is replaced.
         *
         * Alarm strategy (strongest → fallback):
         * 1. Android 12+ (S) with exact-alarm permission:
         *    [AlarmManager.setExactAndAllowWhileIdle] — fires precisely
         *    even in Doze; one-shot, re-scheduled by [onReceive] after
         *    every fire. Exact alarms are exempt from the S+
         *    background-start restriction, so the foreground service
         *    can be restarted from the alarm even when the app process
         *    is not running.
         * 2. Android 6+ (M): [AlarmManager.setAndAllowWhileIdle] — fires
         *    within ~10 minutes of the target even in Doze. NOTE: inexact
         *    alarms are NOT exempt from the S+ background-start
         *    restriction; on Android 12+ the service restart from this
         *    alarm only works while the user has granted the battery
         *    optimization exemption (the app requests it via
         *    requestIgnoreBatteryOptimizations).
         * 3. Older versions: [AlarmManager.setInexactRepeating].
         */
        fun scheduleAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, KeepAliveReceiver::class.java).apply {
                action = "com.johntsui.stroom.KEEP_ALIVE"
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, ALARM_REQUEST_CODE, intent, flags
            )

            val triggerAt = SystemClock.elapsedRealtime() + KEEP_ALIVE_INTERVAL_MS

            // 在调度之前先持久化"闹钟已激活"标记：无论走主路径还是
            // 降级路径，设备重启后 BOOT_COMPLETED 都能恢复调度。
            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_KEEP_ALIVE_ACTIVE, true)
                .apply()

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    alarmManager.canScheduleExactAlarms()
                ) {
                    // Exact alarm: fires on time even in deep Doze.
                    // One-shot — re-scheduled by onReceive after each fire.
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    // Inexact but Doze-tolerant (fires within ~10 min of target).
                    // One-shot — re-scheduled by onReceive.
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
                } else {
                    // Pre-M: repeating alarm; onReceive also re-schedules.
                    alarmManager.setInexactRepeating(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAt,
                        KEEP_ALIVE_INTERVAL_MS,
                        pendingIntent
                    )
                }
                Log.i(TAG, "Keep-alive alarm scheduled (interval=${KEEP_ALIVE_INTERVAL_MS / 60000}min)")
            } catch (e: SecurityException) {
                // Exact-alarm permission revoked or denied (Android 12+).
                // Fall back to an alarm that still tolerates Doze:
                // on Android 6+ use setAndAllowWhileIdle (one-shot), on
                // older versions use the repeating alarm.
                Log.w(TAG, "Exact alarm not permitted — falling back", e)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setInexactRepeating(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            KEEP_ALIVE_INTERVAL_MS,
                            pendingIntent
                        )
                    }
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to schedule keep-alive alarm", e2)
                }
            }
        }

        /**
         * Cancel the keep-alive alarm.
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, KeepAliveReceiver::class.java).apply {
                action = "com.johntsui.stroom.KEEP_ALIVE"
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, ALARM_REQUEST_CODE, intent, flags
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.i(TAG, "Keep-alive alarm cancelled")
            }

            context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_KEEP_ALIVE_ACTIVE, false)
                .apply()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "BOOT_COMPLETED — checking if keep-alive should be re-scheduled")
                val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                val keepAliveActive = prefs.getBoolean(KEY_KEEP_ALIVE_ACTIVE, false)
                if (keepAliveActive) {
                    scheduleAlarm(context)
                }
            }

            "com.johntsui.stroom.KEEP_ALIVE" -> {
                Log.d(TAG, "Keep-alive alarm fired — checking foreground service status")
                try {
                    // Try to start the foreground service.
                    // If it's already running, this is a no-op (the service
                    // handles duplicate start requests).
                    // If the process was killed, this recreates the service
                    // and the Flutter engine's restoreBackgroundServiceOnColdStart
                    // will handle reinitialization.
                    val serviceIntent = Intent(context, Class.forName("com.foregroundservice.ForegroundService"))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    Log.d(TAG, "Foreground service start requested")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start foreground service via keep-alive", e)
                    // Don't give up — the alarm will fire again in 5 minutes.
                    // If the service class is not found, cancel the alarm to
                    // stop repeated failures.
                    if (e is ClassNotFoundException) {
                        Log.w(TAG, "ForegroundService class not found — cancelling keep-alive")
                        cancelAlarm(context)
                    }
                }

                // Re-schedule the next alarm (inexact repeating does this
                // automatically, but we ensure it by calling scheduleAlarm
                // which replaces the existing alarm)
                val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                val serviceEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
                if (serviceEnabled) {
                    scheduleAlarm(context)
                }
            }
        }
    }
}
