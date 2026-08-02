import 'folder_path_utils.dart';

/// Bundles file-manager helper methods that were previously passed as
/// individual callbacks.  Each manifest creates a singleton bridge.
class ManifestBridge {
  final String Function(String) getFolderBaseName;
  final String Function(String) getParentFolderPath;
  final List<String> Function(String, Set<String>) getChildFolderPaths;
  final String? Function(String) validateFolderName;

  /// 文件名校验（默认使用共享实现 [FolderPathUtils.validateFileName]）
  final String? Function(String) validateFileName;
  final List<String> Function(String, Set<String>) getAllDescendantFolderPaths;

  const ManifestBridge({
    required this.getFolderBaseName,
    required this.getParentFolderPath,
    required this.getChildFolderPaths,
    required this.validateFolderName,
    this.validateFileName = FolderPathUtils.validateFileName,
    required this.getAllDescendantFolderPaths,
  });

  /// Bridge that uses the shared [FolderPathUtils] implementations.
  factory ManifestBridge.defaultBridge() => const ManifestBridge(
        getFolderBaseName: FolderPathUtils.getFolderBaseName,
        getParentFolderPath: FolderPathUtils.getParentFolderPath,
        getChildFolderPaths: FolderPathUtils.getChildFolderPaths,
        validateFolderName: FolderPathUtils.validateFolderName,
        validateFileName: FolderPathUtils.validateFileName,
        getAllDescendantFolderPaths:
            FolderPathUtils.getAllDescendantFolderPaths,
      );
}
