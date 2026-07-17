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
    /// 在 Stroom/AutoBackups 子目录中尝试创建临时文件并删除来验证权限是否仍有效，
    /// 因为文件实际会写入该子目录。在某些 Android 版本上，在 Documents 根目录
    /// 直接创建文件可能失败，但在其子目录中创建文件却能正常工作。
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
                result.success(false)
                return
            }

            // 在 Stroom/AutoBackups 子目录中创建临时测试文件
            val testFileName = ".saf_access_test_${System.currentTimeMillis()}.tmp"
            val testFile = backupDir.createFile("application/octet-stream", testFileName)
            if (testFile != null) {
                // 写入一些测试数据
                val outStream = contentResolver.openOutputStream(testFile.uri)
                outStream?.use { it.write(1) }
                // 删除测试文件
                testFile.delete()
                result.success(true)
            } else {
                result.success(false)
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
