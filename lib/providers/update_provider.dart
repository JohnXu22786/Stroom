import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_version.dart';
import 'update_provider_shared.dart';
export 'update_provider_shared.dart';

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

  /// Whether the user accepts pre-release versions in update checks.
  /// When true, checks include pre-releases; when false, only stable releases.
  final bool acceptPreRelease;

  /// All available versions newer than the current installed version.
  /// Sorted descending (newest first). Null when no check has been performed
  /// or no updates are available.
  final List<AvailableUpdate>? availableVersions;

  /// Index of the currently selected version in [availableVersions].
  /// Defaults to 0 (newest version).
  final int selectedVersionIndex;

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
    this.acceptPreRelease = false,
    this.availableVersions,
    this.selectedVersionIndex = 0,
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
    bool? acceptPreRelease,
    List<AvailableUpdate>? availableVersions,
    int? selectedVersionIndex,
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
      acceptPreRelease: acceptPreRelease ?? this.acceptPreRelease,
      availableVersions: availableVersions ?? this.availableVersions,
      selectedVersionIndex: selectedVersionIndex ?? this.selectedVersionIndex,
    );
  }
}

const String _kAllReleasesUrl =
    'https://api.github.com/repos/JohnXu22786/Stroom/releases?per_page=100';
const String _kSkippedVersionKey = 'update_skipped_version';
const String _kUpdateAvailableKey = 'update_available_data';
const String _kAcceptPreReleaseKey = 'update_accept_pre_release';
const String _kPendingUpdateRestartKey = 'pending_update_restart';
const String _kDownloadedFilePathKey = 'update_downloaded_file_path';

/// In-memory flag that survives as long as the Dart isolate is alive.
/// Set to `true` right before the APK installer is launched on Android.
/// Checked by [Application]'s lifecycle listener to detect warm resume
/// after an APK update install.
///
/// Unlike the SharedPreferences flag ([_kPendingUpdateRestartKey]), this
/// flag IS cleared when the process is killed.  By comparing the two:
/// - In-memory set + SharedPref set = process survived install → warm resume
/// - In-memory clear + SharedPref set = process was killed → cold restart
bool _pendingRestartInMemory = false;

/// The SharedPreferences key used to persist the pending-update-restart flag.
///
/// Exported so that [main.dart] and [startup_app.dart] can check and clear
/// it during cold-start without importing the notifier.
String get pendingUpdateRestartKey => _kPendingUpdateRestartKey;

/// The SharedPreferences key used to persist the downloaded installer file
/// path for cleanup on next app startup.
String get downloadFilePathKey => _kDownloadedFilePathKey;

/// Returns `true` if a pending-update-restart flag was found in
/// SharedPreferences.  The caller should clear the flag after handling it.
///
/// This is used in two places:
/// 1. [StartupApp._runStartupSequence] — on cold start, checks and clears it.
/// 2. [Application] lifecycle listener — on warm resume from installer.
Future<bool> hasPendingUpdateRestart() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPendingUpdateRestartKey) ?? false;
  } catch (_) {
    return false;
  }
}

/// Clears the pending-update-restart flag from SharedPreferences.
///
/// Called after the flag has been handled on either cold start or warm resume.
Future<void> clearPendingUpdateRestart() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingUpdateRestartKey);
  } catch (_) {}
}

/// Returns the current value of the in-memory pending-restart flag.
///
/// This flag is set to `true` right before the APK installer is launched
/// on Android, and cleared when the warm-resume handler fires or when the
/// process is killed.  The flag is exposed primarily for testing.
bool get isPendingRestartInMemory => _pendingRestartInMemory;

/// Sets the in-memory pending-restart flag.
///
/// Only intended for use in testing and by [_installOnAndroid].
void setPendingRestartInMemory(bool value) {
  _pendingRestartInMemory = value;
}

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

  /// Selects a version from [availableVersions] by index and updates
  /// the state to reflect the selected version's details.
  ///
  /// The [latestVersion], [releaseNotes], and [downloadUrl] fields are
  /// updated to match the selected [AvailableUpdate]. Does nothing if
  /// the index is out of range.
  void selectVersion(int index) {
    final versions = state.availableVersions;
    if (versions == null || index < 0 || index >= versions.length) return;
    final selected = versions[index];
    state = state.copyWith(
      selectedVersionIndex: index,
      latestVersion: selected.version,
      releaseNotes: selected.releaseNotes,
      downloadUrl: selected.downloadUrl,
    );
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
      await _checkForUpdates(silent: silent);
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

  /// Fetches ALL releases from GitHub (up to 100), filters those newer
  /// than the current installed version, and populates [availableVersions].
  ///
  /// When [acceptPreRelease] is `false`, pre-release versions (marked by
  /// GitHub's `prerelease` field) are excluded from the list.
  /// When [acceptPreRelease] is `true`, all versions including pre-releases
  /// are included.
  ///
  /// The resulting list is sorted descending (newest first), with the first
  /// entry selected by default. Skipped versions are excluded.
  Future<void> _checkForUpdates({required bool silent}) async {
    final response = await _dio.get(_kAllReleasesUrl);
    if (response.statusCode != 200) {
      if (!silent) {
        state = state.copyWith(
          isChecking: false,
          updateAvailable: false,
          error: '检查更新失败: HTTP ${response.statusCode}',
        );
      } else {
        state = _resetState();
      }
      return;
    }

    final releases = response.data as List<dynamic>;
    final currentVersionStr = appVersion;

    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_kSkippedVersionKey);

    // Find the current version's release in the GitHub list to get its
    // published_at date. This enables date-based comparison: only releases
    // published AFTER the current version's release date are shown, regardless
    // of version number. This way, a hotfix published after a major version
    // won't re-prompt the user about that older major version.
    DateTime? cutoffDate;
    Version? currentVersion;
    for (final release in releases) {
      final tagName = release['tag_name'] as String? ?? '';
      final versionStr = tagName.replaceAll(RegExp(r'^v'), '');
      if (versionStr == currentVersionStr) {
        final publishedAtStr = release['published_at'] as String?;
        if (publishedAtStr != null) {
          cutoffDate = DateTime.tryParse(publishedAtStr);
        }
        currentVersion = Version.parse(versionStr);
        break;
      }
    }
    // Fall back to version-based comparison when the current version is not
    // found in the releases list (e.g., very old version or custom build).
    currentVersion ??= Version.parse(currentVersionStr);

    // Collect all available updates newer than current version.
    // The acceptPreRelease toggle only controls the default SELECTION and
    // DISPLAY in the dialog — ALL versions (including pre-releases) are
    // always collected here.
    final List<AvailableUpdate> availableList = [];

    for (final release in releases) {
      final tagName = release['tag_name'] as String? ?? '';
      final versionStr = tagName.replaceAll(RegExp(r'^v'), '');
      final parsed = Version.parse(versionStr);

      // Skip the current version itself: either exact string match or
      // same base version (major.minor.patch). The base version check
      // handles pre-release/hotfix suffixes so that e.g., "39-hotfix"
      // does NOT re-prompt about "v39.0.0" (same base).
      if (versionStr == currentVersionStr ||
          (parsed.major == currentVersion.major &&
              parsed.minor == currentVersion.minor &&
              parsed.patch == currentVersion.patch)) continue;

      // Date-based comparison (when we found the current version's publish date)
      if (cutoffDate != null) {
        final publishedAtStr = release['published_at'] as String?;
        if (publishedAtStr == null) continue;
        final publishedAt = DateTime.tryParse(publishedAtStr);
        if (publishedAt == null || !publishedAt.isAfter(cutoffDate)) continue;
      } else {
        // Fall back to version-based comparison when the current version
        // is not in the releases list or has no published_at field.
        if (!(parsed > currentVersion)) continue;
      }

      // Skip the version the user chose to skip
      if (versionStr == skippedVersion) continue;

      // Find download URL for this release on current platform
      final assets = release['assets'] as List<dynamic>? ?? [];
      final htmlUrl = release['html_url'] as String? ?? '';
      final directDownloadUrl = getPlatformDownloadUrl(assets);
      final downloadUrl = directDownloadUrl ?? htmlUrl;
      final body = release['body'] as String? ?? '';
      final isPrerelease = release['prerelease'] as bool? ?? false;

      availableList.add(AvailableUpdate(
        version: versionStr,
        releaseNotes: body,
        downloadUrl: downloadUrl,
        isPreRelease: isPrerelease,
      ));
    }

    // Sort descending (newest first)
    availableList.sort((a, b) {
      final va = Version.parse(a.version);
      final vb = Version.parse(b.version);
      return vb.compareTo(va); // descending
    });

    if (availableList.isNotEmpty) {
      // Determine default selection index based on display filter.
      // When acceptPreRelease=false, skip pre-releases and select first stable.
      int defaultIndex = 0;
      if (!state.acceptPreRelease) {
        for (int i = 0; i < availableList.length; i++) {
          if (!availableList[i].isPreRelease) {
            defaultIndex = i;
            break;
          }
        }
      }

      // Only show dialog if at least one version matches the display filter
      // (e.g., hide dialog when only pre-releases exist and toggle is off).
      final hasVisibleVersion =
          state.acceptPreRelease || availableList.any((v) => !v.isPreRelease);

      if (hasVisibleVersion) {
        final first = availableList[defaultIndex];

        // Persist the newly selected version's data for pending update detection
        final updateData = jsonEncode({
          'latest_version': first.version,
          'release_notes': first.releaseNotes,
          'download_url': first.downloadUrl,
        });
        await prefs.setString(_kUpdateAvailableKey, updateData);

        state = UpdateState(
          acceptPreRelease: state.acceptPreRelease,
          updateAvailable: true,
          availableVersions: availableList,
          selectedVersionIndex: defaultIndex,
          latestVersion: first.version,
          releaseNotes: first.releaseNotes,
          downloadUrl: first.downloadUrl,
        );
      } else {
        state = _resetState();
      }
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

        // 持久化文件路径，以便下次启动时清理残留安装包
        await _saveDownloadedFilePath();

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
  ///
  /// 启动安装程序后，会尝试清理下载的安装包文件。如果文件被占用，
  /// 将在下次启动时通过 [cleanupStaleInstallerFiles] 清理。
  Future<void> _installOnDesktop(String filePath) async {
    final fileName = filePath.split(Platform.pathSeparator).last.toLowerCase();

    if (Platform.isWindows) {
      if (fileName.endsWith('.exe') || fileName.endsWith('.msi')) {
        // Windows: 直接启动安装程序
        await Process.start(filePath, [], runInShell: true);
        // 启动后尝试清理安装包
        await cleanupDownloadedFile();
        return;
      }
    } else if (Platform.isMacOS) {
      if (fileName.endsWith('.dmg') || fileName.endsWith('.pkg')) {
        // macOS: 挂载 dmg 或启动 pkg 安装器
        final uri = Uri.file(filePath);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // 启动后尝试清理安装包
        await cleanupDownloadedFile();
        return;
      }
    } else if (Platform.isLinux) {
      if (fileName.endsWith('.AppImage')) {
        // Linux AppImage: 加执行权限后直接运行
        await Process.run('chmod', ['+x', filePath]);
        await Process.run(filePath, []);
        // 启动后尝试清理安装包
        await cleanupDownloadedFile();
        return;
      }
      if (fileName.endsWith('.deb') || fileName.endsWith('.rpm')) {
        // Linux 包: 通过系统默认打开（会调起包管理器）
        final uri = Uri.file(filePath);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // 启动后尝试清理安装包
        await cleanupDownloadedFile();
        return;
      }
    }

    // .zip：自更新流程（解压 → 替换 → 重启）
    // 安装包将在下次启动时通过 cleanupStaleInstallerFiles 清理
    if (fileName.endsWith('.zip')) {
      await _selfUpdateFromZip(filePath);
      return;
    }

    // 其他类型，用系统默认打开
    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // 启动后尝试清理安装包
      await cleanupDownloadedFile();
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
  /// This is used by the update dialog's "手动安装" (and "打开安装包") button
  /// when auto-install fails or the user wants to re-open the installer —
  /// the file is already on disk and only needs to be re-triggered.
  Future<void> retryInstall() async {
    state = state.copyWith(isInstalling: true, downloadError: null);
    try {
      await installDownloadedFile();
    } finally {
      state = state.copyWith(isInstalling: false);
    }
  }

  /// Deletes the downloaded installer file at [state.downloadedFilePath].
  ///
  /// This is called after the installer process has been launched:
  /// - For direct installers (.exe/.msi etc.): called immediately after
  ///   [Process.start] returns, best-effort deletion.
  /// - For zip self-update: the file is cleaned up on next app startup via
  ///   [cleanupStaleInstallerFiles].
  ///
  /// Does nothing if [state.downloadedFilePath] is null, empty, or the
  /// file does not exist. Errors are silently caught.
  Future<void> cleanupDownloadedFile() async {
    final path = state.downloadedFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[UpdateNotifier] Cleaned up downloaded file: $path');
      }
    } catch (e) {
      // File may still be in use (e.g., installer process is reading it).
      // It will be cleaned up on next startup.
      debugPrint('[UpdateNotifier] Failed to delete $path: $e');
    }
  }

  /// Persists the downloaded file path to SharedPreferences so it can be
  /// cleaned up on the next app startup if the file was not deleted before.
  Future<void> _saveDownloadedFilePath() async {
    final path = state.downloadedFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDownloadedFilePathKey, path);
    } catch (e) {
      debugPrint('[UpdateNotifier] Failed to save file path: $e');
    }
  }

  /// Cleans up stale installer files from a previous update session.
  ///
  /// Called on app startup ([Application._runPostStartupTasks]). Reads the
  /// persisted file path from SharedPreferences, deletes the file if it
  /// exists, and removes the key from SharedPreferences.
  ///
  /// This handles the case where:
  /// - The app was restarted after a zip self-update.
  /// - The installer file could not be deleted immediately after launch
  ///   (file in use).
  /// - The user launched the app after a manual update.
  Future<void> cleanupStaleInstallerFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kDownloadedFilePathKey);
      if (path == null || path.isEmpty) return;

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[UpdateNotifier] Cleaned up stale installer: $path');
      }
      // Remove the key regardless (file may have already been deleted).
      await prefs.remove(_kDownloadedFilePathKey);
    } catch (e) {
      debugPrint('[UpdateNotifier] Failed to clean up stale installers: $e');
    }
  }

  /// Android 专用：通过 FileProvider 生成 content:// URI 并触发安装
  ///
  /// Native side ([MainActivity.kt]) returns `"ok"` on success or throws a
  /// [PlatformException] on failure with a Chinese error message in the
  /// exception details. The error message is displayed directly in the dialog.
  ///
  /// Before launching the installer, saves a [pending_update_restart] flag in
  /// SharedPreferences AND sets the in-memory flag.  These are checked by the
  /// startup/lifecycle code to detect the "reopen after update" scenario and
  /// handle it gracefully (avoiding crashes caused by stale state or
  /// data inconsistency between the old and new APK).
  Future<void> _installOnAndroid(String filePath) async {
    // Save flags BEFORE launching the installer, so they survive a
    // potential process kill during APK installation.
    // Only set the in-memory flag AFTER the SharedPreferences write succeeds,
    // ensuring both flags are consistent.
    bool prefsOk = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPendingUpdateRestartKey, true);
      prefsOk = true;
    } catch (_) {}
    _pendingRestartInMemory = prefsOk;

    try {
      const channel = MethodChannel('com.johntsui.stroom/install');
      await channel.invokeMethod<String>('installApk', {
        'filePath': filePath,
      });
      // Success — native side successfully launched the package installer.
      // No error to report.
    } on PlatformException catch (e) {
      // Install failed — clear both flags to prevent false "update complete" dialog
      await _clearPendingRestartFlags();
      state = state.copyWith(
        downloadError: e.message ?? '安装失败，请手动打开 APK 安装',
      );
    } catch (e) {
      // Install failed — clear both flags
      await _clearPendingRestartFlags();
      state = state.copyWith(
        downloadError: '安装失败: $e',
      );
    }
  }

  /// Clears both the SharedPreferences and in-memory pending-restart flags.
  /// Called when the install attempt fails or is cancelled.
  Future<void> _clearPendingRestartFlags() async {
    _pendingRestartInMemory = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingUpdateRestartKey);
    } catch (_) {}
  }
}
