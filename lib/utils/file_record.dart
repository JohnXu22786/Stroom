/// 文件记录统一接口
/// ImageRecord 和 AudioRecord 都实现此接口
abstract class FileRecord {
  String get id;
  String get name;
  String get format;
  DateTime get createdAt;
  int get size;
  String get folder;
}

/// 可被 manifest 管理的记录需要提供哈希值用于去重。
mixin Hashable {
  String get hash;
}

/// 可被 manifest 管理的记录需要提供存储路径。
mixin Storable {
  String get storagePath;
}

/// 支持通过 copyWith 重命名的记录。
mixin Renamable<Self> {
  Self copyWithName(String name);
}

/// 支持通过 copyWith 移动文件夹的记录。
mixin Movable<Self> {
  Self copyWithFolder(String folder);
}
