import 'package:mime/mime.dart';

import 'catcatch_task.dart';

enum CatCatchMediaKind { audio, video, other }

/// Use the selected source when it states a track kind explicitly. A shared
/// container extension such as MP4 or OGG cannot identify that kind alone.
CatCatchMediaKind catCatchMediaKind(CatCatchTask task, String savedPath) {
  final selected = task.selectedMedia;
  final selectedMime =
      selected?.mimeType?.split(';').first.trim().toLowerCase();
  if (selectedMime?.startsWith('audio/') == true) {
    return CatCatchMediaKind.audio;
  }
  if (selectedMime?.startsWith('video/') == true) {
    return CatCatchMediaKind.video;
  }
  if (selected?.isAudio == true) return CatCatchMediaKind.audio;

  final savedMime = lookupMimeType(savedPath) ?? '';
  if (savedMime.startsWith('audio/')) return CatCatchMediaKind.audio;
  if (savedMime.startsWith('video/')) return CatCatchMediaKind.video;
  return CatCatchMediaKind.other;
}
