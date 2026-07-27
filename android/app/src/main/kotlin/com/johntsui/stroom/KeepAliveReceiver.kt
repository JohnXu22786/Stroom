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
 * foreground service is active. This receiver schedules a periodic alarm
 * that, when fired, tries to restart the foreground service. If the process
 * is already running with the service active, the alarm is a no-op.
 *
 * Lifecycle:
 * 1. [scheduleAlarm] — called from Dart via MethodChannel when the
 *    background service is started. Schedules a repeating alarm.
 * 2. [cancelAlarm] — called when the background service is stopped.
 * 3. On [Intent.ACTION_BOOT_COMPLETED], the alarm is re-scheduled if
 *    it was previously active (persisted via SharedPreferences).
 */
class KeepAliveReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KeepAliveReceiver"
        private const val ALARM_REQUEST_CODE = 2001
        private const val KEEP_ALIVE_INTERVAL_MS = 15 * 60 * 1000L // 15 minutes

        // SharedPreferences key — mirrors the Dart side's
        // _backgroundServiceEnabledKey. Written from Kotlin so that the
        // BOOT_COMPLETED handler can decide whether to re-schedule.
        private const val PREF_NAME = "FlutterSharedPreferences"
        private const val KEY_SERVICE_ENABLED = "flutter.background_service_enabled"
        private const val KEY_KEEP_ALIVE_ACTIVE = "flutter.keep_alive_active"

        /**
         * Schedule the repeating keep-alive alarm.
         * Safe to call multiple times; the existing alarm is replaced.
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

            // Use setInexactRepeating to let the system batch alarms for
            // battery efficiency. The interval is 15 minutes but the actual
            // timing may vary by up to 5 minutes.
            try {
                alarmManager.setInexactRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + KEEP_ALIVE_INTERVAL_MS,
                    KEEP_ALIVE_INTERVAL_MS,
                    pendingIntent
                )
                Log.i(TAG, "Keep-alive alarm scheduled (interval=${KEEP_ALIVE_INTERVAL_MS / 60000}min)")

                // Persist that the alarm is active so BOOT_COMPLETED can re-schedule
                context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(KEY_KEEP_ALIVE_ACTIVE, true)
                    .apply()
            } catch (e: SecurityException) {
                Log.e(TAG, "Failed to schedule keep-alive alarm: exact alarms permission may be denied", e)
            }
        }

        /**
         * Cancel the repeating keep-alive alarm.
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
                    // Don't give up — the alarm will fire again in 15 minutes.
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
