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
