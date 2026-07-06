package com.johntsui.stroom

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.johntsui.stroom/install"
    private val TAG = "MainActivity"

    companion object {
        private const val RESTART_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        installApk(filePath)
                        result.success("ok")
                    } catch (e: ActivityNotFoundException) {
                        Log.e(TAG, "No activity found to handle APK installation", e)
                        result.error("ACTIVITY_NOT_FOUND", "未找到 APK 安装程序，请手动安装", null)
                    } catch (e: SecurityException) {
                        Log.e(TAG, "Missing permission to install APK", e)
                        result.error("SECURITY_EXCEPTION", "缺少安装权限，请在设置中允许安装未知来源应用", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to install APK", e)
                        result.error("INSTALL_FAILED", "APK 安装失败: ${e.message}", null)
                    }
                } else {
                    Log.e(TAG, "installApk called with null filePath")
                    result.error("NULL_FILEPATH", "安装文件路径为空", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // ======================================================================
    // onNewIntent — 检测"安装后重新打开"场景
    // ======================================================================
    //
    // Android 的 launchMode="singleTop" 意味着如果 Activity 已在栈顶，
    // 系统会调用 onNewIntent() 而不是重新创建 Activity。
    //
    // 流程：
    // 1. 用户在 app 内点击"立即更新"，APK 被下载并启动安装器
    // 2. 安装完成后用户点击安装器的"打开"按钮
    // 3. 系统向现有 Activity 发送 ACTION_MAIN + CATEGORY_LAUNCHER Intent
    // 4. onNewIntent() 被调用
    //
    // 注意：我们在调用 super.onNewIntent() 之前检查标记并处理重启，
    // 以避免 Flutter engine 先分发生命周期事件到 Dart 侧，
    // 导致 Dart 的 didChangeAppLifecycleState 处理程序与原生
    // 重启逻辑竞争。
    // ======================================================================

    private val PENDING_UPDATE_RESTART_KEY = "pending_update_restart"

    override fun onNewIntent(intent: Intent) {
        var handled = false

        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (prefs.getBoolean(PENDING_UPDATE_RESTART_KEY, false)) {
                Log.i(TAG, "onNewIntent: detected pending_update_restart flag — forcing clean restart")

                // Clear the flag to prevent repeated restarts
                prefs.edit().remove(PENDING_UPDATE_RESTART_KEY).apply()

                // Schedule a delayed launch using an exact alarm.
                // On Android 12+ Doze mode, setExactAndAllowWhileIdle ensures
                // the alarm fires even if the device is in deep sleep.
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT
                    } else {
                        PendingIntent.FLAG_ONE_SHOT
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        this, RESTART_REQUEST_CODE, launchIntent, flags
                    )
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC,
                            System.currentTimeMillis() + 200,
                            pendingIntent
                        )
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        alarmManager.setExact(
                            AlarmManager.RTC,
                            System.currentTimeMillis() + 200,
                            pendingIntent
                        )
                    } else {
                        alarmManager.set(
                            AlarmManager.RTC,
                            System.currentTimeMillis() + 200,
                            pendingIntent
                        )
                    }

                    handled = true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "onNewIntent: exception checking restart flag", e)
        }

        if (handled) {
            // Process was scheduled to restart — finish current activity
            // and kill the process so the AlarmManager launch starts fresh.
            finishAffinity()
            Process.killProcess(Process.myPid())
            // Note: super.onNewIntent is NOT called here because the
            // process is about to be killed. The Flutter engine will be
            // recreated on the next cold start.
        } else {
            // No restart needed — let the Flutter engine handle the intent
            super.onNewIntent(intent)
        }
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)
        val apkUri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
