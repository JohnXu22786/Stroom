import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_version.dart';

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(),
);

class UpdateState {
  final bool isChecking;
  final String? latestVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? error;
  final bool updateAvailable;

  // Download fields
  final bool isDownloading;
  final double downloadProgress;
  final bool downloadComplete;
  final String? downloadError;
  final String? downloadedFilePath;

  // Auto-install field: true while the app is auto-installing
  // the downloaded update immediately after download completes.
  final bool isInstalling;

  const UpdateState({
    this.isChecking = false,
    this.latestVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.error,
    this.updateAvailable = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.downloadComplete = false,
    this.downloadError,
    this.downloadedFilePath,
    this.isInstalling = false,
  });

  UpdateState copyWith({
    bool? isChecking,
    String? latestVersion,
    String? releaseNotes,
    String? downloadUrl,
    String? error,
    bool? updateAvailable,
    bool? isDownloading,
    double? downloadProgress,
    bool? downloadComplete,
    String? downloadError,
    String? downloadedFilePath,
    bool? isInstalling,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: error ?? this.error,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadComplete: downloadComplete ?? this.downloadComplete,
      downloadError: downloadError ?? this.downloadError,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      isInstalling: isInstalling ?? this.isInstalling,
    );
  }
}








class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  Version._({required this.major, required this.minor, required this.patch});

  factory Version.parse(String versionString) {
    final cleaned = versionString.replaceAll(RegExp(r'^v'), '');
    final base = cleaned.split('+').first.split('-').first;
    final parts = base.split('.');
    return Version._(
      major: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minor: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      patch: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
}

const String _kUpdateCheckUrl = 'https://api.github.com/repos/JohnXu22786/Stroom/releases/latest';
const String _kSkippedVersionKey = 'update_skipped_version';
const String _kUpdateAvailableKey = 'update_available_data';

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
  static String? findAssetDownloadUrl(List<dynamic> assets, String platformKey) {
    final key = platformKey.toLowerCase();
    String? installerUrl;
    String? fallbackUrl;

    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      if (!name.contains(key)) continue;

      final url = asset['browser_download_url'] as String?;
      if (url == null) continue;

      // 优先选择安装包 (.exe/.msi/.dmg)，其次才是压缩包
      if (name.endsWith('.exe') || name.endsWith('.msi') || name.endsWith('.dmg')) {
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

  Future<void> checkForUpdate({bool silent = false}) async {
    if (state.isChecking) return;

    // Web platform does not support direct download updates
    if (kIsWeb) {
      state = const UpdateState();
      return;
    }

    state = state.copyWith(isChecking: true, error: null);

    try {
      final response = await _dio.get(_kUpdateCheckUrl);
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
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
            state = const UpdateState();
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
          state = const UpdateState();
        }
      } else {
        if (!silent) {
          state = state.copyWith(
            isChecking: false,
            updateAvailable: false,
            error: '检查更新失败: HTTP ${response.statusCode}',
          );
        } else {
          state = const UpdateState();
        }
      }
    } catch (e) {
      if (!silent) {
        state = state.copyWith(
          isChecking: false,
          updateAvailable: false,
          error: '网络错误: $e',
        );
      } else {
        state = const UpdateState();
      }
    }
  }

  Future<Map<String, dynamic>?> getPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUpdateAvailableKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>?;
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSkippedVersionKey, version);
    await prefs.remove(_kUpdateAvailableKey);
    state = const UpdateState();
  }

  Future<void> clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUpdateAvailableKey);
    state = const UpdateState();
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
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'update';
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

  /// 桌面端更新：
  /// - .exe/.msi/.dmg：直接启动安装程序
  /// - .zip：解压后替换当前安装文件并重启
  Future<void> _installOnDesktop(String filePath) async {
    final fileName = filePath.split(Platform.pathSeparator).last.toLowerCase();
    final isInstaller = fileName.endsWith('.exe') ||
        fileName.endsWith('.msi') ||
        fileName.endsWith('.dmg');

    if (isInstaller) {
      // 安装包：直接启动
      final uri = Uri.file(filePath);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!fileName.endsWith('.zip')) {
      // 其他类型，用系统默认打开
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // .zip：自更新流程
    await _selfUpdateFromZip(filePath);
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
        ? await _createWindowsUpdateScript(installDir.path, updateDir.path, extractedExe)
        : await _createUnixUpdateScript(installDir.path, updateDir.path, extractedExe);

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

  String _fileName(String path) =>
      path.split(Platform.pathSeparator).last;

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

  /// Android 专用：通过 FileProvider 生成 content:// URI 并触发安装
  Future<void> _installOnAndroid(String filePath) async {
    const channel = MethodChannel('com.johntsui.stroom/install');
    final result = await channel.invokeMethod<bool>('installApk', {
      'filePath': filePath,
    });
    if (result != true) {
      state = state.copyWith(
        downloadError: '安装失败，请手动打开 APK 安装',
      );
    }
  }}
