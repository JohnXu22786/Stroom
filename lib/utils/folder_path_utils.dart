/// 纯文件夹路径工具函数（无状态）。
/// 从 FileManifest 与 ImageManifest 中提取，共享同一份实现。
class FolderPathUtils {
  FolderPathUtils._(); // 纯静态类，禁止实例化

  /// Windows 保留设备名：在 Windows 上无法创建/写入同名目录，
  /// 原生端导出时会直接失败，因此在校验阶段就拒绝
  static const Set<String> _reservedWindowsNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  /// Windows 非法字符集（路径分隔符与保留字符）
  static final RegExp _illegalChars = RegExp(r'[/\\:*?"<>|]');

  /// 公共名称校验：空名 / 超长 / 非法字符 / 尾点 / Windows 保留设备名
  static String? _validateName(String name, String kind, int maxLength) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '$kind不能为空';
    if (trimmed.length > maxLength) return '$kind不能超过$maxLength个字符';
    if (_illegalChars.hasMatch(trimmed)) {
      return '$kind不能包含 / \\ : * ? " < > | 字符';
    }
    // 尾点：Windows 会静默去掉目录/文件名末尾的点，
    // 导致 foo 与 foo. 在导出时合并成同一个目录（可能互相覆盖）
    if (trimmed.endsWith('.')) return '$kind不能以 . 结尾';
    // Windows 保留设备名（含带扩展名的形式，如 CON.txt ——
    // Windows 按第一个点前的分段判断设备名）
    final firstSegment = trimmed.split('.').first.toUpperCase();
    if (_reservedWindowsNames.contains(firstSegment)) {
      return '$kind不能使用 Windows 保留名称';
    }
    return null;
  }

  /// 校验文件夹名是否合法。
  /// 与 [validateFileName] 一样拒绝 Windows 非法字符与保留名称，
  /// 否则含这些字符的文件夹在原生端导出时会因路径写入失败而报错。
  static String? validateFolderName(String name) =>
      _validateName(name, '文件夹名', 100);

  /// 校验文件名是否合法（比文件夹名更严格：
  /// 额外拒绝 Windows 非法字符，否则导出时会在路径写入时失败）。
  /// 长度上限与 [sanitizeFileName] 的 110 一致，避免导入后无法重命名。
  static String? validateFileName(String name) =>
      _validateName(name, '文件名', 110);

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
