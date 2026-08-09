import 'free_space_stub.dart' if (dart.library.ffi) 'free_space_ffi.dart'
    as impl;

/// 获取 [path] 所在文件系统的剩余可用空间（字节）。
///
/// - Android: 通过 SAF 通道（见 BackupLocationManager.getFreeDiskSpaceBytes）
/// - iOS: 通过原生通道
/// - 桌面（Windows/macOS/Linux）: 通过 dart:ffi 调用系统 API
/// - Web / 无法获取的平台: 返回 null
///
/// 返回 null 表示当前平台无法获取（调用方应跳过空间相关逻辑，不阻塞功能）。
int? getFreeDiskSpaceBytes(String path) => impl.getFreeDiskSpaceBytes(path);
