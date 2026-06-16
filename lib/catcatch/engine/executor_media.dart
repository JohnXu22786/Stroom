import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/media_resource.dart';
import 'media_probe.dart';
import 'executor_utils.dart';

List<MediaResource> detectSplitTracks(List<MediaResource> media) {
  if (media.length < 2) return media;

  final result = List<MediaResource>.from(media);
  final audioList = <int>[];
  final videoList = <int>[];

  for (int i = 0; i < result.length; i++) {
    if (result[i].isAudio) audioList.add(i);
    if (result[i].isVideo) videoList.add(i);
  }

  if (audioList.isEmpty || videoList.isEmpty) return result;

  for (final ai in audioList) {
    for (final vi in videoList) {
      if (result[ai].groupId != null || result[vi].groupId != null) continue;
      final aDuration = result[ai].duration;
      final vDuration = result[vi].duration;
      if (aDuration != null && vDuration != null) {
        final aSec = parseDurationToSeconds(aDuration);
        final vSec = parseDurationToSeconds(vDuration);
        if (aSec != null && vSec != null && (aSec - vSec).abs() <= 2) {
          final groupId = 'split_${result[ai].name}_${result[vi].name}';
          result[ai] = result[ai].copyWith(
            groupId: groupId,
            isLikelySplitTrack: true,
          );
          result[vi] = result[vi].copyWith(
            groupId: groupId,
            isLikelySplitTrack: true,
          );
        }
      } else {
        final aName = result[ai].name.toLowerCase();
        final vName = result[vi].name.toLowerCase();
        final commonPrefix = longestCommonPrefix(aName, vName);
        if (commonPrefix.length > 5 &&
            (aName.contains('audio') ||
                vName.contains('audio') ||
                aName.contains('video') ||
                vName.contains('video'))) {
          final groupId = 'split_$commonPrefix';
          result[ai] = result[ai].copyWith(
            groupId: groupId,
            isLikelySplitTrack: true,
          );
          result[vi] = result[vi].copyWith(
            groupId: groupId,
            isLikelySplitTrack: true,
          );
        }
      }
    }
  }

  return result;
}

String buildDurationFilterDetail(
    int beforeCount, int afterCount, int expectedDurationSec) {
  final h = expectedDurationSec ~/ 3600;
  final m = (expectedDurationSec % 3600) ~/ 60;
  final s = expectedDurationSec % 60;
  final parts = <String>[];
  if (h > 0) parts.add('${h}小时');
  if (m > 0) parts.add('${m}分钟');
  parts.add('${s}秒');
  final durationStr = parts.join('');
  final removed = beforeCount - afterCount;
  if (removed > 0) {
    return '按照${durationStr}时长筛选后剩余$afterCount个结果（已排除$removed个不匹配的资源）';
  }
  return '按时长${durationStr}筛选，$afterCount个资源全部匹配';
}

Future<List<MediaResource>> probeMediaResources(
    List<MediaResource> resources) async {
  if (kIsWeb) return resources;

  final result = <MediaResource>[];
  for (final res in resources) {
    if (res.isPlayable && (res.duration == null || res.width == null)) {
      final probe = await MediaProbe.probe(res.url);
      result.add(res.copyWith(
        duration: probe.duration != null
            ? formatExecutorDuration(probe.duration!)
            : res.duration,
        width: probe.width ?? res.width,
        height: probe.height ?? res.height,
      ));
      continue;
    }
    result.add(res);
  }
  return result;
}

bool isSpecialFormat(String ext) {
  const specialFormats = {
    'ts',
    'flv',
    'f4v',
    'hlv',
    'mkv',
    'avi',
    'wmv',
    'mpeg',
    'mpg',
    'm4s',
    'ogg',
    'ogv',
    'm3u8',
    'm3u',
    'mpd',
  };
  return specialFormats.contains(ext.toLowerCase());
}
