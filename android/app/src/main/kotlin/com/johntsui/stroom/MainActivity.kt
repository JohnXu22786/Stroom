package com.johntsui.stroom

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Process
import android.provider.Settings
import android.provider.DocumentsContract
import android.util.Log
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL_INSTALL = "com.johntsui.stroom/install"
    private val CHANNEL_SAF = "com.johntsui.stroom/saf"
    private val CHANNEL_KEEPALIVE = "com.johntsui.stroom/keepalive"
    private val TAG = "MainActivity"

    companion object {
        private const val RESTART_REQUEST_CODE = 1001
        private const val SAF_REQUEST_CODE = 1002

        // 保存 pickDirectory 的结果回调
        private var pendingSafResult: MethodChannel.Result? = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SAF_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                // 立即固化权限 — 必须成功才能持久化 URI
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    Log.i(TAG, "SAF: 权限已固化: $uri")
                    pendingSafResult?.success(uri.toString())
                } catch (e: SecurityException) {
                    Log.w(TAG, "SAF: 无法固化权限: $uri", e)
                    // 固化失败时返回 null，避免 Dart 侧保存一个无效 URI
                    // 否则下次启动时权限丢失，导致授权弹窗反复出现
                    pendingSafResult?.success(null)
                }
            } else {
                Log.i(TAG, "SAF: 用户取消了目录选择")
                pendingSafResult?.success(null)
            }
            pendingSafResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // === 安装 APK 通道 ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_INSTALL).setMethodCallHandler { call, result ->
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

        // === SAF 存储访问框架通道 ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SAF).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> {
                    // 打开 SAF 目录选择器，优先导航到 Documents 目录
                    openSafDirectoryPicker(result)
                }
                "checkAccess" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        checkSafAccess(uriStr, result)
                    } else {
                        result.success(false)
                    }
                }
                "writeFile" -> {
                    val uriStr = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (uriStr != null && fileName != null && bytes != null) {
                        writeFileToSaf(uriStr, fileName, bytes, result)
                    } else {
                        result.error("INVALID_ARGS", "参数不完整", null)
                    }
                }
                "readFile" -> {
                    val uriStr = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    if (uriStr != null && fileName != null) {
                        readFileFromSaf(uriStr, fileName, result)
                    } else {
                        result.error("INVALID_ARGS", "参数不完整", null)
                    }
                }
                "deleteFile" -> {
                    val uriStr = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    if (uriStr != null && fileName != null) {
                        deleteFileInSaf(uriStr, fileName, result)
                    } else {
                        result.error("INVALID_ARGS", "参数不完整", null)
                    }
                }
                "renameFile" -> {
                    val uriStr = call.argument<String>("uri")
                    val oldName = call.argument<String>("oldName")
                    val newName = call.argument<String>("newName")
                    if (uriStr != null && oldName != null && newName != null) {
                        renameFileInSaf(uriStr, oldName, newName, result)
                    } else {
                        result.error("INVALID_ARGS", "参数不完整", null)
                    }
                }
                "listFiles" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        listFilesInSaf(uriStr, result)
                    } else {
                        result.error("INVALID_ARGS", "URI 为空", null)
                    }
                }
                "getFreeSpace" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        getFreeSpaceInSaf(uriStr, result)
                    } else {
                        result.success(null)
                    }
                }
                // === 日志文件操作（写入 Stroom/Logs 目录） ===
                "writeLog" -> {
                    val uriStr = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (uriStr != null && fileName != null && content != null) {
                        writeLogToSaf(uriStr, fileName, content, result)
                    } else {
                        result.error("INVALID_ARGS", "日志参数不完整", null)
                    }
                }
                "readLog" -> {
                    val uriStr = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    if (uriStr != null && fileName != null) {
                        readLogFromSaf(uriStr, fileName, result)
                    } else {
                        result.error("INVALID_ARGS", "日志参数不完整", null)
                    }
                }
                "listLogs" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        listLogsInSaf(uriStr, result)
                    } else {
                        result.error("INVALID_ARGS", "URI 为空", null)
                    }
                }
                "deleteLog" -> {
                    val uriStr = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    if (uriStr != null && fileName != null) {
                        deleteLogInSaf(uriStr, fileName, result)
                    } else {
                        result.error("INVALID_ARGS", "日志参数不完整", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // === 保活通道：AlarmManager 看门狗 + 忽略电池优化 ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_KEEPALIVE).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKeepAlive" -> {
                    Log.i(TAG, "Keep-alive: start requested from Dart")
                    KeepAliveReceiver.scheduleAlarm(this)
                    // 用户显式启动看门狗：清零连续失败计数，
                    // 恢复正常的 5 分钟调度间隔。
                    KeepAliveReceiver.resetFailureCount(this)
                    result.success(true)
                }
                "stopKeepAlive" -> {
                    Log.i(TAG, "Keep-alive: stop requested from Dart")
                    KeepAliveReceiver.cancelAlarm(this)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "requestScheduleExactAlarm" -> {
                    requestScheduleExactAlarm()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
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

    // shared_preferences 插件会把所有 key 加上 "flutter." 前缀写入
    // FlutterSharedPreferences；Dart 侧写入的是 'pending_update_restart'
    // （update_provider.dart），这里必须读前缀后的完整 key，
    // 否则 onNewIntent 永远读不到标记，原生重启路径永不触发。
    private val PENDING_UPDATE_RESTART_KEY = "flutter.pending_update_restart"

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

    // ==================================================================
    // SAF（Storage Access Framework）方法
    // ==================================================================

    /// 打开 SAF 目录选择器，引导用户选择 Documents 目录。
    ///
    /// Android 8.0+ (API 26+) 使用 [EXTRA_INITIAL_URI] 自动定位到
    /// Documents 文档目录，用户无需手动查找，直接点击「允许」即可。
    /// 低版本 Android 回退到系统默认位置（通常也是最近使用的目录）。
    private fun openSafDirectoryPicker(result: MethodChannel.Result) {
        pendingSafResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)

            // Android 8.0+ 支持初始目录定位到 Documents 文件夹
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    val documentsUri = DocumentsContract.buildDocumentUri(
                        "com.android.externalstorage.documents",
                        "primary:Documents"
                    )
                    intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, documentsUri)
                    Log.i(TAG, "SAF: 设置初始目录为 Documents: $documentsUri")
                } catch (e: Exception) {
                    Log.w(TAG, "SAF: 设置初始目录失败，使用默认位置", e)
                }
            }

            startActivityForResult(intent, SAF_REQUEST_CODE)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 打开目录选择器失败", e)
            pendingSafResult = null
            result.error("PICKER_FAILED", "无法打开目录选择器", null)
        }
    }

    /// 检查 SAF URI 是否仍然可访问。
    ///
    /// 优先尝试在 Stroom/AutoBackups 子目录中创建测试文件并删除来验证权限。
    /// 如果创建文件测试失败，回退到更简单的测试：先尝试列出 Stroom 目录内容
    /// （仅需读权限），再尝试查找或创建 Stroom/AutoBackups 目录（需要写权限）。
    /// 在某些 Android 版本上，目录创建可能比文件创建更可靠。
    private fun checkSafAccess(uriStr: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(uriStr)
            val documentFile = DocumentFile.fromTreeUri(this, uri)

            if (documentFile == null) {
                result.success(false)
                return
            }

            // 首先找到或创建 Stroom/AutoBackups 子目录
            val backupDir = getOrCreateBackupDir(documentFile)
            if (backupDir == null) {
                // 目录创建失败，尝试回退：仅检查 tree document 是否可列出内容
                try {
                    val children = documentFile.listFiles()
                    // 能列出内容说明仍有读取权限
                    // 但无法创建子目录意味着写入可能受限
                    Log.w(TAG, "SAF: 目录可读但无法创建 Stroom/AutoBackups")
                    result.success(false)
                } catch (e2: Exception) {
                    Log.e(TAG, "SAF: 访问检查完全失败", e2)
                    result.success(false)
                }
                return
            }

            // 在 Stroom/AutoBackups 子目录中创建临时测试文件
            val testFileName = ".saf_access_test_${System.currentTimeMillis()}.tmp"
            try {
                val testFile = backupDir.createFile("application/octet-stream", testFileName)
                if (testFile != null) {
                    // 写入一些测试数据
                    val outStream = contentResolver.openOutputStream(testFile.uri)
                    if (outStream != null) {
                        outStream.use { it.write(1) }
                        // 删除测试文件
                        testFile.delete()
                        result.success(true)
                    } else {
                        // 输出流打开失败，清理测试文件
                        testFile.delete()
                        Log.w(TAG, "SAF: 可创建文件但无法打开输出流")
                        result.success(false)
                    }
                } else {
                    // 文件创建失败，尝试回退：列出备份目录内容
                    // 如果能列出文件，说明有读取权限但可能写入受限
                    try {
                        backupDir.listFiles()
                        Log.w(TAG, "SAF: 可列出文件但无法创建测试文件，" +
                            "权限可能部分恢复")
                        // 部分权限也认为是可访问的（允许只读操作）
                        result.success(true)
                    } catch (e2: Exception) {
                        Log.e(TAG, "SAF: 文件创建和列出均失败", e2)
                        result.success(false)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "SAF: 测试文件创建异常", e)
                // 发生异常时仍尝试回退检查
                try {
                    backupDir.listFiles()
                    Log.w(TAG, "SAF: 异常后目录列表成功，认为可访问")
                    result.success(true)
                } catch (e2: Exception) {
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 访问检查失败", e)
            result.success(false)
        }
    }

    /// 在 treeDocument 下找到或创建 Stroom/AutoBackups 嵌套目录。
    ///
    /// SAF 的 findFile/createDirectory 只支持一级子目录，因此需要
    /// 先处理 Stroom 目录，再在其下处理 AutoBackups 目录。
    /// 返回 AutoBackups 的 DocumentFile，如果任何一级创建失败返回 null。
    private fun getOrCreateBackupDir(treeDocument: DocumentFile): DocumentFile? {
        val stroomDir = treeDocument.findFile("Stroom")
            ?: treeDocument.createDirectory("Stroom")
        if (stroomDir == null) return null

        val autoBackupsDir = stroomDir.findFile("AutoBackups")
            ?: stroomDir.createDirectory("AutoBackups")
        return autoBackupsDir
    }

    /// 在 treeDocument 下找到或创建 Stroom/Logs 嵌套目录。
    ///
    /// 日志文件与备份文件共享 Stroom 父目录，位于 Logs 子目录。
    /// 返回 Logs 的 DocumentFile，如果任何一级创建失败返回 null。
    private fun getOrCreateLogsDir(treeDocument: DocumentFile): DocumentFile? {
        val stroomDir = treeDocument.findFile("Stroom")
            ?: treeDocument.createDirectory("Stroom")
        if (stroomDir == null) return null

        val logsDir = stroomDir.findFile("Logs")
            ?: stroomDir.createDirectory("Logs")
        return logsDir
    }

    // ==================================================================
    // 日志文件 SAF 操作方法（写入 Stroom/Logs 目录，追加模式）
    // ==================================================================

    /// 通过 SAF 将日志文本追加写入文件。
    ///
    /// 与备份文件的"覆盖写入"不同，日志采用追加模式：
    /// 先读取已有内容，再拼接新内容后写回。
    /// 如果文件不存在则直接创建。
    ///
    /// 安全策略：先写入临时文件，成功后再替换原文件，避免写入失败导致数据丢失。
    private fun writeLogToSaf(
        uriStr: String,
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)

            if (treeDocument == null) {
                result.error("TREE_DOC_FAILED", "无法访问目录", null)
                return
            }

            // 获取或创建 Stroom/Logs 目录
            val logsDir = getOrCreateLogsDir(treeDocument)
            if (logsDir == null) {
                result.error("CREATE_DIR_FAILED", "无法创建日志目录", null)
                return
            }

            // 查找已有日志文件，读取已有内容用于追加
            val existingFile = logsDir.findFile(fileName)
            val existingContent = if (existingFile != null) {
                val inputStream = contentResolver.openInputStream(existingFile.uri)
                inputStream?.bufferedReader()?.use { it.readText() } ?: ""
            } else {
                ""
            }

            // 拼接完整内容
            val combinedContent = existingContent + content

            // 安全写入：先写临时文件，成功后删除旧文件并重命名
            val tempFileName = "$fileName.tmp_${System.currentTimeMillis()}"
            val tempFile = logsDir.createFile("text/plain", tempFileName)
            if (tempFile == null) {
                result.error("CREATE_FILE_FAILED", "无法创建临时日志文件", null)
                return
            }

            val outputStream = contentResolver.openOutputStream(tempFile.uri)
            if (outputStream == null) {
                // 清理临时文件
                tempFile.delete()
                result.error("WRITE_FAILED", "无法打开输出流写入日志", null)
                return
            }

            outputStream.bufferedWriter().use { writer ->
                writer.write(combinedContent)
                writer.flush()
            }

            // 写入成功：删除旧文件
            if (existingFile != null) {
                existingFile.delete()
            }

            // 将临时文件重命名为目标文件名
            val renamed = tempFile.renameTo(fileName)
            if (!renamed) {
                // 重命名失败，尝试重新创建。内容已写入临时文件，
                // 至少数据没丢（临时文件会留在目录里）
                Log.w(TAG, "SAF: 日志文件重命名失败，临时文件保留: $tempFileName")
            }

            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 写入日志文件失败", e)
            result.error("WRITE_LOG_FAILED", "写入日志文件失败: ${e.message}", null)
        }
    }

    /// 通过 SAF 读取日志文件内容。
    private fun readLogFromSaf(
        uriStr: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.success(null)
                return
            }
            val logsDir = getOrCreateLogsDir(treeDocument)
                ?: run {
                    result.success(null)
                    return
                }

            val file = logsDir.findFile(fileName)
            if (file != null) {
                val inputStream = contentResolver.openInputStream(file.uri)
                val content = inputStream?.bufferedReader()?.use { it.readText() }
                result.success(content)
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 读取日志文件失败", e)
            result.success(null)
        }
    }

    /// 列出 SAF 日志目录中的所有 .log 文件。
    private fun listLogsInSaf(
        uriStr: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.success(emptyList<String>())
                return
            }
            val logsDir = getOrCreateLogsDir(treeDocument)
                ?: run {
                    result.success(emptyList<String>())
                    return
                }

            val children = logsDir.listFiles()
            val fileNames = children
                .filter { it.isFile && (it.name?.endsWith(".log") == true) }
                .map { it.name }
                .filterNotNull()
            result.success(fileNames)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 列出日志文件失败", e)
            result.success(emptyList<String>())
        }
    }

    /// 通过 SAF 删除日志文件。
    private fun deleteLogInSaf(
        uriStr: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.success(null)
                return
            }
            val logsDir = getOrCreateLogsDir(treeDocument)
                ?: run {
                    result.success(null)
                    return
                }

            val file = logsDir.findFile(fileName)
            if (file != null) {
                val deleted = file.delete()
                Log.i(TAG, "SAF: 删除日志文件 $fileName: $deleted")
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 删除日志文件失败", e)
            result.success(null)
        }
    }

    /// 通过 SAF 将字节写入文件。
    private fun writeFileToSaf(
        uriStr: String,
        fileName: String,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)

            if (treeDocument == null) {
                result.error("TREE_DOC_FAILED", "无法访问目录", null)
                return
            }

            // 获取或创建 Stroom/AutoBackups 嵌套子目录
            val backupDir = getOrCreateBackupDir(treeDocument)
            if (backupDir == null) {
                result.error("CREATE_DIR_FAILED", "无法创建备份目录", null)
                return
            }

            // 删除已存在的同名文件，然后创建新文件
            val existingFile = backupDir.findFile(fileName)
            if (existingFile != null) {
                existingFile.delete()
            }

            val newFile = backupDir.createFile("application/zip", fileName)
            if (newFile != null) {
                val outputStream = contentResolver.openOutputStream(newFile.uri)
                outputStream?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                }
                result.success(null)
            } else {
                result.error("CREATE_FILE_FAILED", "无法创建备份文件", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 写入文件失败", e)
            result.error("WRITE_FAILED", "写入备份文件失败: ${e.message}", null)
        }
    }

    /// 通过 SAF 从文件中读取字节。
    private fun readFileFromSaf(
        uriStr: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.success(null)
                return
            }
            val backupDir = getOrCreateBackupDir(treeDocument)
                ?: run {
                    result.success(null)
                    return
                }

            val file = backupDir.findFile(fileName)
            if (file != null) {
                val inputStream = contentResolver.openInputStream(file.uri)
                val bytes = inputStream?.use { stream -> stream.readBytes() }
                result.success(bytes)
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 读取文件失败", e)
            result.success(null)
        }
    }

    /// 通过 SAF 删除文件。
    private fun deleteFileInSaf(
        uriStr: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.success(null)
                return
            }
            val backupDir = getOrCreateBackupDir(treeDocument)
                ?: run {
                    result.success(null)
                    return
                }

            val file = backupDir.findFile(fileName)
            if (file != null) {
                val deleted = file.delete()
                Log.i(TAG, "SAF: 删除文件 $fileName: $deleted")
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 删除文件失败", e)
            result.success(null)
        }
    }

    /// 通过 SAF 重命名文件（.tmp → .zip）。
    private fun renameFileInSaf(
        uriStr: String,
        oldName: String,
        newName: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.error("TREE_DOC_FAILED", "无法访问目录", null)
                return
            }
            val backupDir = getOrCreateBackupDir(treeDocument)
                ?: run {
                    result.error("DIR_NOT_FOUND", "备份目录不存在", null)
                    return
                }

            val file = backupDir.findFile(oldName)
            if (file != null) {
                val renamed = file.renameTo(newName)
                if (renamed) {
                    result.success(null)
                } else {
                    // 重命名失败（SAF 不支持直接重命名），使用先读后写再删的方式
                    val inputStream = contentResolver.openInputStream(file.uri)
                    val bytes = inputStream?.use { stream -> stream.readBytes() }
                    if (bytes != null) {
                        // 删除旧文件
                        file.delete()
                        // 创建新文件
                        val newFile = backupDir.createFile("application/zip", newName)
                        if (newFile != null) {
                            val outputStream = contentResolver.openOutputStream(newFile.uri)
                            outputStream?.use { stream ->
                                stream.write(bytes)
                                stream.flush()
                            }
                            result.success(null)
                        } else {
                            result.error("RENAME_FAILED", "无法创建新文件", null)
                        }
                    } else {
                        result.error("RENAME_FAILED", "无法读取原文件", null)
                    }
                }
            } else {
                // 原文件不存在，尝试直接创建
                val newFile = backupDir.createFile("application/zip", newName)
                if (newFile != null) {
                    result.success(null)
                } else {
                    result.error("RENAME_FAILED", "原文件不存在且无法创建新文件", null)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 重命名文件失败", e)
            result.error("RENAME_FAILED", "重命名失败: ${e.message}", null)
        }
    }

    /// 列出 SAF 备份目录中的所有文件。
    private fun listFilesInSaf(
        uriStr: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri = Uri.parse(uriStr)
            val treeDocument = DocumentFile.fromTreeUri(this, uri)
            if (treeDocument == null) {
                result.success(emptyList<String>())
                return
            }
            val backupDir = getOrCreateBackupDir(treeDocument)
                ?: run {
                    result.success(emptyList<String>())
                    return
                }

            val children = backupDir.listFiles()
            val fileNames = children
                .filter { it.isFile }
                .map { it.name }
                .filterNotNull()
            result.success(fileNames)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 列出文件失败", e)
            result.success(emptyList<String>())
        }
    }

    /// 获取 SAF 目录所在存储的可用空间。
    private fun getFreeSpaceInSaf(
        uriStr: String,
        result: MethodChannel.Result
    ) {
        try {
            // 使用 Environment 获取外部存储的可用空间
            val stat = Environment.getExternalStorageDirectory()
            val freeBytes = stat?.freeSpace ?: -1L
            result.success(freeBytes)
        } catch (e: Exception) {
            Log.e(TAG, "SAF: 获取可用空间失败", e)
            result.success(-1L)
        }
    }

    /// 检查是否已忽略电池优化。
    ///
    /// 如果返回 true，说明应用已被添加到省电白名单，
    /// Doze 模式不会影响后台运行。
    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // 低版本不需要
        }
    }

    /// 是否允许调度精确闹钟（Android 12+，即 API 31+）。
    ///
    /// 精确闹钟是保活看门狗「准点触发 + 后台启动前台服务豁免」的前提。
    /// Android 14+ 默认拒绝，用户可在系统设置中授予。
    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true // 低版本始终允许
        }
    }

    /// 打开系统「闹钟和提醒」特殊权限页面，引导用户授予精确闹钟权限。
    ///
    /// 授予后系统会发送 SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED 广播，
    /// KeepAliveReceiver 会立即重新调度看门狗。
    private fun requestScheduleExactAlarm() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                Log.i(TAG, "Schedule exact alarm permission requested")
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "ACTION_REQUEST_SCHEDULE_EXACT_ALARM not supported", e)
                // 回退：打开应用详情页（部分国产 ROM 不支持特殊权限跳转）
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to open app settings", e2)
                }
            }
        }
    }

    /// 打开系统设置页面，引导用户将本应用添加到省电白名单。
    ///
    /// Android 6+ 需要 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 权限，
    /// 系统会自动弹出确认弹窗让用户选择"是/否"。
    /// 对于某些国产 ROM，这个 API 可能无效（它们有自己的省电策略），
    /// 此时会回退到打开应用详情页。
    private fun requestIgnoreBatteryOptimizations() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                Log.i(TAG, "Battery optimization exemption requested")
            }
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS not supported — opening app settings", e)
            // 回退：打开应用详情页
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to open app settings", e2)
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
