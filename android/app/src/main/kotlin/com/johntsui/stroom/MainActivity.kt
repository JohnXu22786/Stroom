package com.johntsui.stroom

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.johntsui.stroom/install"
    private val TAG = "MainActivity"

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
