import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_version.dart';
import 'update_provider_shared.dart';
import 'update_state.dart';
export 'update_provider_shared.dart';
export 'update_state.dart';

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(),
);

const String _kUpdateCheckUrl =
    'https://api.github.com/repos/JohnXu22786/Stroom/releases/latest';
const String _kAllReleasesUrl =
    'https://api.github.com/repos/JohnXu22786/Stroom/releases?per_page=100';
const String _kSkippedVersionKey = 'update_skipped_version';
const String _kUpdateAvailableKey = 'update_available_data';
const String _kAcceptPreReleaseKey = 'update_accept_pre_release';

class UpdateNotifier extends StateNotifier<UpdateState> {
  final Dio _dio;

  UpdateNotifier({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ),
        super(const UpdateState());

  /// Finds the download URL for the given [platformKey] from the release [assets].
  ///
  /// Matches by checking if the asset name contains the platform key (e.g., 'android',
  /// 'windows', 'macos', 'linux'). Returns the [browser_download_url] of the first match,
  /// or `null` if no asset matches.
  static String? findAssetDownloadUrl(
      List<dynamic> assets, String platformKey) {
    final key = platformKey.toLowerCase();
    String? installerUrl;
    String? fallbackUrl;

    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      if (!name.contains(key)) continue;

      final url = asset['browser_download_url'] as String?;
      if (url == null) continue;

      // 优先选择安装包 (.exe/.msi/.dmg)，其次才是压缩包
      if (name.endsWith('.exe') ||
          name.endsWith('.msi') ||
          name.endsWith('.dmg')) {
        installerUrl = url;
      } else {
        fallbackUrl ??= url;
      }
    }

    return installerUrl ?? fallbackUrl;
  }

  /// Determines the current platform and returns the matching download URL from [assets].
  ///
  /// On Web, returns `null` since updates are not supported.
  /// Falls back to `null` if no matching asset is found for the current platform.
  static String? getPlatformDownloadUrl(List<dynamic> assets) {
    if (kIsWeb) return null;

    String platformKey;
    if (defaultTargetPlatform == TargetPlatform.android) {
      platformKey = 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformKey = 'ios';
    } else if (Platform.isWindows) {
      platformKey = 'windows';
    } else if (Platform.isMacOS) {
      platformKey = 'macos';
    } else if (Platform.isLinux) {
      platformKey = 'linux';
    } else {
      return null;
    }

    return findAssetDownloadUrl(assets, platformKey);
  }

  /// Attempts to load the persisted [acceptPreRelease] preference
  /// from SharedPreferences and applies it to the current state.
  Future<void> loadAcceptPreRelease() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_kAcceptPreReleaseKey) ?? false;
      state = state.copyWith(acceptPreRelease: value);
    } catch (_) {
      // Default to false on error
      state = state.copyWith(acceptPreRelease: false);
    }
  }

  /// Sets whether the user accepts pre-release versions in update checks.
  /// Persists the value to SharedPreferences.
  Future<void> setAcceptPreRelease(bool value) async {
    state = state.copyWith(acceptPreRelease: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAcceptPreReleaseKey, value);
    } catch (e) {
      debugPrint('setAcceptPreRelease failed: $e');
    }
  }

  /// Resets transient update state while preserving user preferences
  /// (e.g., [acceptPreRelease]).
  UpdateState _resetState() {
    return UpdateState(acceptPreRelease: state.acceptPreRelease);
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    if (state.isChecking) return;

    // Web platform does not support direct download updates
    if (kIsWeb) {
      state = _resetState();
      return;
    }

    state = state.copyWith(isChecking: true, error: null);

    try {
      if (state.acceptPreRelease) {
        await _checkForUpdateWithPreRelease(silent: silent);
      } else {
        await _checkForUpdateStable(silent: silent);
      }
    } catch (e) {
      if (!silent) {
        state = state.copyWith(
          isChecking: false,
          updateAvailable: false,
          error: '网络错误: $e',
        );
      } else {
        state = _resetState();
      }
    }
  }

  /// Checks for updates using the stable releases API (/releases/latest).
  /// This is the original behavior — only non-prerelease releases are considered.
  Future<void> _checkForUpdateStable({required bool silent}) async {
    final response = await _dio.get(_kUpdateCheckUrl);
    if (response.statusCode == 200) {
      await _processSingleRelease(response.data as Map<String, dynamic>);
    } else {
      if (!silent) {
        state = state.copyWith(
          isChecking: false,
          updateAvailable: false,
          error: '检查更新失败: HTTP ${response.statusCode}',
        );
      } else {
        state = _resetState();
      }
    }
  }

  /// Checks for updates using the full releases API (/releases).
  /// Iterates through all returned releases (including pre-releases) to find
  /// the latest version newer than the current installed version.
  Future<void> _checkForUpdateWithPreRelease({required bool silent}) async {
    final response = await _dio.get(_kAllReleasesUrl);
    if (response.statusCode == 200) {
      final releases = response.data as List<dynamic>;
      final current = Version.parse(appVersion);

      Version? bestVersion;
      String? bestTagName;
      String? bestBody;
      String? bestHtmlUrl;
      List<dynamic> bestAssets = [];

      for (final release in releases) {
        final tagName = release['tag_name'] as String? ?? '';
        final versionStr = tagName.replaceAll(RegExp(r'^v'), '');
        final parsed = Version.parse(versionStr);

        if (parsed > current) {
          if (bestVersion == null || parsed > bestVersion) {
            bestVersion = parsed;
            bestTagName = versionStr;
            bestBody = release['body'] as String? ?? '';
            bestHtmlUrl = release['html_url'] as String? ?? '';
            bestAssets = release['assets'] as List<dynamic>? ?? [];
          }
        }
      }

      if (bestVersion != null) {
        final prefs = await SharedPreferences.getInstance();
        final skippedVersion = prefs.getString(_kSkippedVersionKey);

        if (skippedVersion == bestTagName) {
          state = _resetState();
          return;
        }

        // Find direct download URL for current platform, fall back to html_url
        final directDownloadUrl = getPlatformDownloadUrl(bestAssets);
        final downloadUrl = directDownloadUrl ?? bestHtmlUrl;

        final updateData = jsonEncode({
          'latest_version': bestTagName,
          'release_notes': bestBody,
          'download_url': downloadUrl,
        });
        await prefs.setString(_kUpdateAvailableKey, updateData);

        state = UpdateState(
          acceptPreRelease: state.acceptPreRelease,
          updateAvailable: true,
          latestVersion: bestTagName,
          releaseNotes: bestBody,
          downloadUrl: downloadUrl,
        );
      } else {
        state = _resetState();
      }
    } else {
      if (!silent) {
        state = state.copyWith(
          isChecking: false,
          updateAvailable: false,
          error: '检查更新失败: HTTP ${response.statusCode}',
        );
      } else {
        state = _resetState();
      }
    }
  }

  /// Processes a single release from the GitHub API (/releases/latest) response.
  Future<void> _processSingleRelease(Map<String, dynamic> data) async {
    final tagName = data['tag_name'] as String? ?? '';
    final latestVersion = tagName.replaceAll(RegExp(r'^v'), '');
    final releaseNotes = data['body'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? '';
    final assets = data['assets'] as List<dynamic>? ?? [];

    // Find direct download URL for current platform, fall back to html_url
    final directDownloadUrl = getPlatformDownloadUrl(assets);
    final downloadUrl = directDownloadUrl ?? htmlUrl;

    final current = Version.parse(appVersion);
    final latest = Version.parse(latestVersion);

    final updateAvailable = latest > current;

    if (updateAvailable) {
      final prefs = await SharedPreferences.getInstance();
      final skippedVersion = prefs.getString(_kSkippedVersionKey);

      if (skippedVersion == latestVersion) {
        state = _resetState();
        return;
      }

      final updateData = jsonEncode({
        'latest_version': latestVersion,
        'release_notes': releaseNotes,
        'download_url': downloadUrl,
      });
      await prefs.setString(_kUpdateAvailableKey, updateData);

      state = UpdateState(
        updateAvailable: true,
        latestVersion: latestVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      );
    } else {
      state = _resetState();
    }
  }

  Future<Map<String, dynamic>?> getPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUpdateAvailableKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>?;
  }

  Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSkippedVersionKey, version);
      await prefs.remove(_kUpdateAvailableKey);
    } catch (e) {
      debugPrint('skipVersion failed: $e');
    }
    state = _resetState();
  }

  Future<void> clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUpdateAvailableKey);
    state = _resetState();
  }

  /// Downloads the update file to a local temp directory, then
  /// automatically installs it.
  ///
  /// Uses [dio.get] with [ResponseType.bytes] to download the file,
  /// then writes the bytes to a local file. Tracks download progress
  /// through [UpdateState.downloadProgress].
  ///
  /// After the file is saved, [installDownloadedFile] is called
  /// automatically so the user does not need to click a separate
  /// install button.
  ///
  /// On success, saves the file path to [UpdateState.downloadedFilePath]
  /// and sets [UpdateState.downloadComplete] to true.
  /// On failure, sets [UpdateState.downloadError] with an error message.
  ///
  /// The [downloadDir] parameter is optional and used primarily for testing
  /// to avoid dependency on platform path providers.
  Future<void> downloadUpdate({String? downloadDir}) async {
    final url = state.downloadUrl;
    if (url == null || url.isEmpty) {
      state = state.copyWith(
        isDownloading: false,
        downloadError: '下载地址不可用',
      );
      return;
    }

    // 防止重复下载
    if (state.isDownloading) return;

    state = state.copyWith(
      isDownloading: true,
      downloadProgress: 0.0,
      downloadError: null,
      downloadComplete: false,
      downloadedFilePath: null,
      isInstalling: false,
    );

    // Check if the URL is a GitHub release page (html_url fallback) rather than a direct download
    // /releases/tag/ indicates a release page, /releases/download/ is a direct asset download
    if (url.contains('/releases/tag/')) {
      state = state.copyWith(
        isDownloading: false,
        downloadError: '当前平台暂无直接下载链接，请前往浏览器手动下载',
      );
      return;
    }

    try {
      final tempDir = downloadDir ?? await _getDownloadDirectory();
      final uri = Uri.parse(url);
      final fileName =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'update';
      final filePath = '$tempDir/$fileName';

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            state = state.copyWith(downloadProgress: progress);
          }
        },
      );

      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        state = state.copyWith(
          isDownloading: false,
          downloadProgress: 1.0,
          downloadComplete: true,
          downloadedFilePath: filePath,
          isInstalling: true,
        );

        // 自动安装：下载完成后立即安装，无需用户点击安装按钮
        try {
          await installDownloadedFile();
        } catch (e) {
          // 捕获 installDownloadedFile 未处理到的异常
          state = state.copyWith(
            downloadError: '自动安装失败: $e',
          );
        } finally {
          state = state.copyWith(isInstalling: false);
        }
      } else {
        state = state.copyWith(
          isDownloading: false,
          downloadError: '下载失败: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        downloadError: '下载失败: $e',
      );
    }
  }

  Future<String> _getDownloadDirectory() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final dir = await getApplicationCacheDirectory();
      return dir.path;
    }
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// Opens/installs the previously downloaded file using the system default handler.
  ///
  /// For Android APKs, uses FileProvider + install intent via MethodChannel.
  /// For desktop:
  ///   - Installers (.exe/.msi/.dmg): launch directly
  ///   - Zip archives: extract, replace running app files, restart
  /// Does nothing if [downloadedFilePath] is null or on Web.
  Future<void> installDownloadedFile() async {
    final filePath = state.downloadedFilePath;
    if (filePath == null || filePath.isEmpty) return;
    if (kIsWeb) return;

    // Clear previous error before attempting installation
    state = state.copyWith(downloadError: null);

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _installOnAndroid(filePath);
      } catch (e) {
        state = state.copyWith(
          downloadError: '安装失败: $e',
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      try {
        await _installOnDesktop(filePath);
      } catch (e) {
        state = state.copyWith(
          downloadError: '更新失败: $e',
        );
      }
    } else {
      // Fallback: use system default handler
      try {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          state = state.copyWith(
            downloadError: '无法打开文件，请手动安装: $filePath',
          );
        }
      } catch (e) {
        state = state.copyWith(
          downloadError: '安装失败: $e',
        );
      }
    }
  }

  /// 桌面端更新（所有非 Web 平台都会自动触发安装）：
  ///
  /// ### Windows
  /// - .exe / .msi → [Process.start] 直接启动安装程序
  ///
  /// ### macOS
  /// - .dmg → [launchUrl] 挂载磁盘映像
  /// - .pkg → [launchUrl] 启动安装器
  ///
  /// ### Linux
  /// - .AppImage → `chmod +x` 后直接运行
  /// - .deb / .rpm → [launchUrl] 通过系统包管理器打开
  ///
  /// ### 全部桌面端
  /// - .zip → 解压后走自更新流程（替换文件并重启）
  /// - 其他类型 → [launchUrl] 以系统默认方式打开
  Future<void> _installOnDesktop(String filePath) async {
    final fileName = filePath.split(Platform.pathSeparator).last.toLowerCase();

    if (Platform.isWindows) {
      if (fileName.endsWith('.exe') || fileName.endsWith('.msi')) {
        // Windows: 直接启动安装程序
        await Process.start(filePath, [], runInShell: true);
        return;
      }
    } else if (Platform.isMacOS) {
      if (fileName.endsWith('.dmg') || fileName.endsWith('.pkg')) {
        // macOS: 挂载 dmg 或启动 pkg 安装器
        final uri = Uri.file(filePath);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } else if (Platform.isLinux) {
      if (fileName.endsWith('.AppImage')) {
        // Linux AppImage: 加执行权限后直接运行
        await Process.run('chmod', ['+x', filePath]);
        await Process.run(filePath, []);
        return;
      }
      if (fileName.endsWith('.deb') || fileName.endsWith('.rpm')) {
        // Linux 包: 通过系统默认打开（会调起包管理器）
        final uri = Uri.file(filePath);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // .zip：自更新流程（解压 → 替换 → 重启）
    if (fileName.endsWith('.zip')) {
      await _selfUpdateFromZip(filePath);
      return;
    }

    // 其他类型，用系统默认打开
    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 从 zip 自更新：解压 → 创建替换脚本 → 启动脚本 → 退出应用
  Future<void> _selfUpdateFromZip(String zipPath) async {
    // 1. 确定当前安装目录
    final executablePath = Platform.resolvedExecutable;
    final installDir = File(executablePath).parent;

    // 2. 解压到临时更新目录
    final updateDir = Directory.systemTemp.createTempSync('stroom_update_');
    await _extractZip(zipPath, updateDir.path);
    final extractedExe = _findExecutable(updateDir.path);

    // 3. 创建更新脚本
    final scriptPath = Platform.isWindows
        ? await _createWindowsUpdateScript(
            installDir.path, updateDir.path, extractedExe)
        : await _createUnixUpdateScript(
            installDir.path, updateDir.path, extractedExe);

    // 4. 启动脚本
    if (Platform.isWindows) {
      await Process.start(scriptPath, [], runInShell: true);
    } else {
      await Process.start('/bin/bash', [scriptPath], runInShell: false);
    }

    // 5. 弹出更新脚本后退出应用
    // 脚本会：等待 → 杀掉当前进程 → 替换文件 → 启动新版本
  }

  /// 解压 zip 文件到目标目录
  Future<void> _extractZip(String zipPath, String outputDir) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final entry in archive) {
      final entryPath = '$outputDir/${entry.name}';
      if (entry.isFile) {
        final file = File(entryPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(entryPath).create(recursive: true);
      }
    }
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  /// 在提取目录中查找主可执行文件
  String _findExecutable(String dirPath) {
    final dir = Directory(dirPath);
    final exts = Platform.isWindows ? ['.exe'] : [''];
    final files = dir.listSync(recursive: true);

    // 查找第一个可执行文件（优先与当前 exe 同名的）
    final currentExeName = _fileName(Platform.resolvedExecutable);
    for (final file in files) {
      final name = _fileName(file.path);
      if (exts.any((e) => name.toLowerCase().endsWith(e)) &&
          !name.contains('msvcp') &&
          !name.contains('vcruntime')) {
        if (name == currentExeName) return file.path;
      }
    }
    // 没找到同名，返回第一个 exe
    for (final file in files) {
      final name = _fileName(file.path);
      if (exts.any((e) => name.toLowerCase().endsWith(e))) {
        return file.path;
      }
    }
    // 还找不到，返回解压目录本身
    return dirPath;
  }

  /// Windows 更新脚本 (.bat)
  Future<String> _createWindowsUpdateScript(
      String installDir, String updateDir, String extractedExe) async {
    final exeName = _fileName(extractedExe);
    final scriptContent = '''@echo off
timeout /t 3 /nobreak > nul
taskkill /f /im $exeName 2>nul
xcopy /E /Y "$updateDir\\*" "$installDir\\"
start "" "$installDir\\$exeName"
del "%~f0"
''';
    final scriptFile = File('${updateDir}_update.bat');
    await scriptFile.writeAsString(scriptContent);
    return scriptFile.path;
  }

  /// macOS/Linux 更新脚本 (.sh)
  Future<String> _createUnixUpdateScript(
      String installDir, String updateDir, String extractedExe) async {
    final exeName = _fileName(extractedExe);
    final exePath = '$installDir/$exeName';
    final scriptContent = '''#!/bin/bash
sleep 3
pkill -9 "$exeName" 2>/dev/null
cp -R "$updateDir/"* "$installDir/"
chmod +x "$exePath"
"$exePath" &
rm -- "\$0"
''';
    final scriptFile = File('${updateDir}_update.sh');
    await scriptFile.writeAsString(scriptContent);
    // 设置执行权限
    await Process.run('chmod', ['+x', scriptFile.path]);
    return scriptFile.path;
  }

  /// Retries installation of the already-downloaded file.
  ///
  /// Sets [UpdateState.isInstalling] to provide visual feedback in the UI,
  /// then calls [installDownloadedFile]. Resets [UpdateState.isInstalling] to
  /// `false` after the install attempt completes (success or failure).
  ///
  /// This is used by the update dialog's "手动安装" button when auto-install
  /// fails — the APK is already on disk and only needs to be re-triggered.
  Future<void> retryInstall() async {
    state = state.copyWith(isInstalling: true, downloadError: null);
    try {
      await installDownloadedFile();
    } finally {
      state = state.copyWith(isInstalling: false);
    }
  }

  /// Android 专用：通过 FileProvider 生成 content:// URI 并触发安装
  ///
  /// Native side ([MainActivity.kt]) returns `"ok"` on success or throws a
  /// [PlatformException] on failure with a Chinese error message in the
  /// exception details. The error message is displayed directly in the dialog.
  Future<void> _installOnAndroid(String filePath) async {
    try {
      const channel = MethodChannel('com.johntsui.stroom/install');
      await channel.invokeMethod<String>('installApk', {
        'filePath': filePath,
      });
      // Success — native side successfully launched the package installer.
      // No error to report.
    } on PlatformException catch (e) {
      state = state.copyWith(
        downloadError: e.message ?? '安装失败，请手动打开 APK 安装',
      );
    } catch (e) {
      state = state.copyWith(
        downloadError: '安装失败: $e',
      );
    }
  }
}
