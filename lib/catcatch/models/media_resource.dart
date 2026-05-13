/// 媒体资源模型
///
/// 表示从 URL 分析或页面嗅探中发现的单个媒体资源。
class MediaResource {
  /// 资源 URL
  final String url;

  /// 文件名（不含扩展名）
  final String name;

  /// 扩展名: mp4, m3u8, mpd, ts, webm...
  final String ext;

  /// MIME 类型: video/mp4, audio/mpeg...
  final String? mimeType;

  /// 资源大小（字节）
  final int? size;

  /// 来源页面 URL（referer / origin）
  final String? initiator;

  /// 是否可预览播放
  final bool isPlayable;

  /// 是否是播放列表（m3u8/mpd）
  final bool isPlaylist;

  /// 可选的时长信息（字符串形式，如 "00:12:34.567"）
  final String? duration;

  const MediaResource({
    required this.url,
    required this.name,
    required this.ext,
    this.mimeType,
    this.size,
    this.initiator,
    this.isPlayable = false,
    this.isPlaylist = false,
    this.duration,
  });

  // ---------------------------------------------------------------------------
  // 便捷类型判断
  // ---------------------------------------------------------------------------

  /// 是否 HLS 播放列表
  bool get isM3U8 => ext == 'm3u8' || ext == 'm3u';

  /// 是否 DASH 播放列表
  bool get isMPD => ext == 'mpd';

  /// 是否视频格式
  bool get isVideo => [
        'mp4',
        'webm',
        'ogg',
        'ogv',
        'mov',
        'mkv',
        'avi',
        'flv',
        'mpeg',
        'mpg'
      ].contains(ext);

  /// 是否音频格式
  bool get isAudio =>
      ['mp3', 'wav', 'm4a', 'aac', 'wma', 'opus', 'weba'].contains(ext);

  /// 是否媒体资源（视频/音频/播放列表）
  bool get isMedia => isVideo || isAudio || isPlaylist;

  /// 是否 TS 分段
  bool get isTS => ext == 'ts';

  // ---------------------------------------------------------------------------
  // 序列化
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'url': url,
        'name': name,
        'ext': ext,
        'mimeType': mimeType,
        'size': size,
        'initiator': initiator,
        'isPlayable': isPlayable,
        'isPlaylist': isPlaylist,
        'duration': duration,
      };

  factory MediaResource.fromMap(Map<String, dynamic> map) => MediaResource(
        url: map['url'] as String,
        name: map['name'] as String,
        ext: map['ext'] as String,
        mimeType: map['mimeType'] as String?,
        size: map['size'] as int?,
        initiator: map['initiator'] as String?,
        isPlayable: map['isPlayable'] as bool? ?? false,
        isPlaylist: map['isPlaylist'] as bool? ?? false,
        duration: map['duration'] as String?,
      );

  MediaResource copyWith({
    String? url,
    String? name,
    String? ext,
    String? mimeType,
    int? size,
    String? initiator,
    bool? isPlayable,
    bool? isPlaylist,
    String? duration,
  }) =>
      MediaResource(
        url: url ?? this.url,
        name: name ?? this.name,
        ext: ext ?? this.ext,
        mimeType: mimeType ?? this.mimeType,
        size: size ?? this.size,
        initiator: initiator ?? this.initiator,
        isPlayable: isPlayable ?? this.isPlayable,
        isPlaylist: isPlaylist ?? this.isPlaylist,
        duration: duration ?? this.duration,
      );

  @override
  String toString() =>
      'MediaResource($name.$ext, url=$url, size=$size, mime=$mimeType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaResource &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          name == other.name &&
          ext == other.ext;

  @override
  int get hashCode => Object.hash(url, name, ext);
}
