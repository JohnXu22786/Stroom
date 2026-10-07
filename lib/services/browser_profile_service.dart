import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/atomic_file.dart';
import '../utils/web_file_store.dart';
import 'storage_service.dart';

/// Access to the embedded browser profile directories stored in the app data
/// container. Apple platforms use WebKit's current on-disk website-data path
/// because WKWebView does not expose a public profile-directory API.
class BrowserProfileService {
  BrowserProfileService._();

  static const restoreStagingDirectoryName = 'browser_profile_restore';
  static const _actionFileName = 'browser_profile_action.json';

  static const _ignoredDirectoryNames = {
    'cache',
    'code cache',
    'gpucache',
    'shadercache',
    'grshadercache',
    'dawncache',
    'crashpad',
    'browsermetrics',
  };

  static const _ignoredFileNames = {
    'lock',
    'lockfile',
    'singletonlock',
    'singletoncookie',
    'singletonsocket',
    'devtoolsactiveport',
  };

  static String? get currentPlatformName {
    if (kIsWeb || WebFileStore.isTestMode) return null;
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return null;
  }

  static String get _restoreDirectoryPath =>
      p.join(_appDataPath, restoreStagingDirectoryName);

  static String get _actionFilePath => p.join(_appDataPath, _actionFileName);

  static String get _appDataPath => _resolvedAppDataPath ?? '';
  static String? _resolvedAppDataPath;
  static bool _actionInProgress = false;

  static Future<String> _getAppDataPath() async {
    final cached = _resolvedAppDataPath;
    if (cached != null) return cached;
    final path = await AppStorage.directory;
    _resolvedAppDataPath = path;
    return path;
  }

  /// Returns the WebView website-data path. The Apple path reflects WebKit's
  /// current app-container layout.
  static Future<Directory?> currentProfileDirectory() async {
    if (currentPlatformName == null) return null;
    if (Platform.isAndroid) {
      final supportDirectory = await getApplicationSupportDirectory();
      return Directory(p.join(p.dirname(supportDirectory.path), 'app_webview'));
    }
    if (Platform.isWindows) {
      final executable = Platform.resolvedExecutable;
      return Directory(
        p.join(p.dirname(executable), '${p.basename(executable)}.WebView2'),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final libraryDirectory = await getLibraryDirectory();
      return Directory(
        p.join(libraryDirectory.path, 'WebKit', 'WebsiteData'),
      );
    }
    return null;
  }

  /// Clears stale temporary data from a failed prior restore and rejects a
  /// second browser-profile operation until the user has restarted the app.
  static Future<void> prepareForRestore() async {
    if (currentPlatformName == null) return;
    await _getAppDataPath();
    if (await File(_actionFilePath).exists()) {
      throw const FileSystemException(
        'A browser profile restore or clear is already pending. Restart the app first.',
      );
    }
    final restoreDirectory = Directory(_restoreDirectoryPath);
    if (await restoreDirectory.exists()) {
      await restoreDirectory.delete(recursive: true);
    }
  }

  /// Whether a staged profile replacement or clear still needs an app restart.
  static Future<bool> hasPendingAction() async {
    if (_actionInProgress) return true;
    if (currentPlatformName == null) return false;
    try {
      await _getAppDataPath();
      return await File(_actionFilePath).exists();
    } catch (error) {
      debugPrint(
        '[BrowserProfileService] Could not check pending action: $error',
      );
      return true;
    }
  }

  /// Prevents cookie persistence while a profile restore or clear is being
  /// finalized. The persistent action marker takes over before this is ended.
  static void beginAction() {
    if (_actionInProgress) {
      throw StateError('A browser profile operation is already in progress.');
    }
    _actionInProgress = true;
  }

  static void endAction() {
    _actionInProgress = false;
  }

  /// Clears website data using the platform's supported cleanup mechanism.
  /// Android and Windows profile files are removed at the next launch because
  /// the current WebView keeps them open.
  static Future<bool> scheduleClear() async {
    if (kIsWeb || WebFileStore.isTestMode) return false;
    if (Platform.isIOS || Platform.isMacOS) {
      await WebStorageManager.instance().removeDataModifiedSince(
        dataTypes: WebsiteDataType.ALL,
        date: DateTime.fromMillisecondsSinceEpoch(0),
      );
      return true;
    }
    final platform = currentPlatformName;
    if (platform == null) return false;
    await prepareForRestore();
    await AtomicFile.writeString(
      File(_actionFilePath),
      jsonEncode({'mode': 'clear', 'platform': platform}),
    );
    return true;
  }

  /// Applies a pending browser-profile operation before the app creates any
  /// WebView. A failed operation leaves its marker in place and fails startup,
  /// so WebViews cannot open with stale profile data before the next retry.
  static Future<void> applyPendingAction() async {
    if (currentPlatformName == null) return;
    await _getAppDataPath();
    final actionFile = File(_actionFilePath);
    if (!await actionFile.exists()) {
      final staleRestore = Directory(_restoreDirectoryPath);
      if (await staleRestore.exists()) {
        try {
          await staleRestore.delete(recursive: true);
        } catch (error, stackTrace) {
          debugPrint(
            '[BrowserProfileService] Failed to remove stale restore data: '
            '$error\n$stackTrace',
          );
        }
      }
      return;
    }

    try {
      final decoded = jsonDecode(await actionFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid browser profile action.');
      }
      final mode = decoded['mode'];
      final platform = decoded['platform'];
      if (platform != currentPlatformName ||
          (mode != 'replace' && mode != 'clear')) {
        throw const FormatException('Unsupported browser profile action.');
      }

      final profileDirectory = await currentProfileDirectory();
      if (profileDirectory == null) {
        throw const FileSystemException(
          'Browser profile directory is not available on this platform.',
        );
      }
      if (mode == 'clear') {
        if (await profileDirectory.exists()) {
          await profileDirectory.delete(recursive: true);
        }
      } else {
        final stagedDirectory = Directory(
          p.join(_restoreDirectoryPath, platform as String),
        );
        if (!await stagedDirectory.exists()) {
          throw const FileSystemException('Staged browser profile is missing.');
        }
        await _replaceDirectory(profileDirectory, stagedDirectory);
      }

      await actionFile.delete();
      final restoreDirectory = Directory(_restoreDirectoryPath);
      if (await restoreDirectory.exists()) {
        await restoreDirectory.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[BrowserProfileService] Failed to apply pending browser profile action: '
        '$error\n$stackTrace',
      );
      rethrow;
    }
  }

  static Future<void> _replaceDirectory(
    Directory destination,
    Directory source,
  ) async {
    final parent = destination.parent;
    await parent.create(recursive: true);
    final temporary = Directory('${destination.path}.stroom-new');
    final previous = Directory('${destination.path}.stroom-previous');
    if (await previous.exists() && !await destination.exists()) {
      await previous.rename(destination.path);
    }
    if (await temporary.exists()) await temporary.delete(recursive: true);
    await _copyDirectory(source, temporary);

    final hadPrevious = await destination.exists();
    if (hadPrevious) {
      if (await previous.exists()) await previous.delete(recursive: true);
      await destination.rename(previous.path);
    }
    try {
      await temporary.rename(destination.path);
    } catch (_) {
      if (hadPrevious && await previous.exists()) {
        await previous.rename(destination.path);
      }
      rethrow;
    }
    if (await previous.exists()) await previous.delete(recursive: true);
  }

  static Future<void> _copyDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (_ignoredDirectoryNames.contains(name.toLowerCase())) continue;
        await _copyDirectory(entity, Directory(p.join(destination.path, name)));
      } else if (entity is File) {
        final name = p.basename(entity.path);
        if (_ignoredFileNames.contains(name.toLowerCase())) continue;
        await entity.copy(p.join(destination.path, name));
      }
    }
  }
}
