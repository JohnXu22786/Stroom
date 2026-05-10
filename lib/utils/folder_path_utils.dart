/// 纯文件夹路径工具函数（无状态）。
/// 从 FileManifest 与 ImageManifest 中提取，共享同一份实现。
class FolderPathUtils {
  FolderPathUtils._(); // 纯静态类，禁止实例化

  /// 获取路径中的末级文件夹名
  static String getFolderBaseName(String folderPath) {
    final idx = folderPath.lastIndexOf('/');
    return idx == -1 ? folderPath : folderPath.substring(idx + 1);
  }

  /// 获取父级路径（空字符串表示根目录）
  static String getParentFolderPath(String folderPath) {
    if (folderPath.isEmpty) return '';
    final idx = folderPath.lastIndexOf('/');
    return idx == -1 ? '' : folderPath.substring(0, idx);
  }

  /// 校验文件夹名是否合法
  static String? validateFolderName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '文件夹名不能为空';
    if (trimmed.length > 100) return '文件夹名不能超过100个字符';
    if (trimmed.contains('/')) return '文件夹名不能包含斜杠 /';
    return null;
  }

  /// 获取指定父路径下的直接子文件夹路径列表
  static List<String> getChildFolderPaths(
      String parentPath, Set<String> allPaths) {
    final prefix = parentPath.isEmpty ? '' : '$parentPath/';
    final result = <String>[];
    for (final p in allPaths) {
      if (p == parentPath) continue;
      if (parentPath.isEmpty) {
        // 根目录下的顶级文件夹：不含 /
        if (!p.contains('/')) result.add(p);
      } else {
        if (p.startsWith(prefix)) {
          final suffix = p.substring(prefix.length);
          // 直接子级：不含额外的 /
          if (!suffix.contains('/')) result.add(p);
        }
      }
    }
    return result;
  }

  /// 递归获取某路径下的所有子文件夹路径（含深层）
  static List<String> getAllDescendantFolderPaths(
      String parentPath, Set<String> allPaths) {
    final result = <String>{};
    final prefix = parentPath.isEmpty ? '' : '$parentPath/';
    for (final p in allPaths) {
      if (p == parentPath) continue;
      if (parentPath.isEmpty) {
        // 根目录：取所有带 / 的路径（即非顶级文件夹）
        if (p.contains('/')) result.add(p);
      } else {
        if (p.startsWith(prefix)) result.add(p);
      }
    }
    return result.toList();
  }
}
