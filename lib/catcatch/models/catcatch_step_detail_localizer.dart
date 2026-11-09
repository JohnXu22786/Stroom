import '../../l10n/app_localizations.dart';

/// Localizes CatCatch step details, including Chinese text persisted by older
/// app versions. Unrecognized details are kept intact because they may be
/// errors or data supplied by an external source.
String localizeCatCatchStepDetail(String detail, AppLocalizations strings) {
  var match = RegExp(r'^获取到(\d+)个媒体资源$').firstMatch(detail);
  if (match != null) {
    return strings.catCatchDetailMediaResources(int.parse(match[1]!));
  }

  match = RegExp(r'^浏览器中获取到(\d+)个资源$').firstMatch(detail);
  if (match != null) {
    return strings.catCatchDetailBrowserResources(int.parse(match[1]!));
  }

  match = RegExp(r'^获取到(\d+)个资源$').firstMatch(detail);
  if (match != null) {
    return strings.catCatchDetailResources(int.parse(match[1]!));
  }

  match = RegExp(r'^获取到(\d+)个资源（播放列表(\d+)个分段）$').firstMatch(detail);
  if (match != null) {
    return strings.catCatchDetailPlaylistResources(
      int.parse(match[1]!),
      int.parse(match[2]!),
    );
  }

  match = RegExp(r'^共(\d+)个资源，请用户选择$').firstMatch(detail);
  if (match != null) {
    return strings.catCatchDetailChooseResource(int.parse(match[1]!));
  }

  if (detail == '自动选择第1个结果，进入下载') {
    return strings.catCatchDetailAutoSelectFirst;
  }
  if (detail == '剩余1个结果，自动进入下载') {
    return strings.catCatchDetailAutoSelectRemaining;
  }

  match = RegExp(r'^\.(\S*) 格式无需转换，已跳过$').firstMatch(detail);
  if (match != null) {
    if (match[1]!.isEmpty) return strings.catCatchDetailSkipNoExtension;
    return strings.catCatchDetailSkipFormat(match[1]!);
  }

  match = RegExp(r'^按照(.+)时长筛选后剩余(\d+)个结果（已排除(\d+)个不匹配的资源）$')
      .firstMatch(detail);
  if (match != null) {
    final duration = _localizeDuration(match[1]!, strings);
    if (duration != null) {
      return strings.catCatchDetailDurationFiltered(
        duration,
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    }
  }

  match = RegExp(r'^按时长(.+)筛选，(\d+)个资源全部匹配$').firstMatch(detail);
  if (match != null) {
    final duration = _localizeDuration(match[1]!, strings);
    if (duration != null) {
      return strings.catCatchDetailDurationAllMatch(
        int.parse(match[2]!),
        duration,
      );
    }
  }

  return detail;
}

String? _localizeDuration(String value, AppLocalizations strings) {
  final match = RegExp(r'^(?:(\d+)小时)?(?:(\d+)分钟)?(\d+)秒$').firstMatch(value);
  if (match == null) return null;

  final hours = int.tryParse(match[1] ?? '0');
  final minutes = int.tryParse(match[2] ?? '0');
  final seconds = int.tryParse(match[3]!);
  if (hours == null || minutes == null || seconds == null) return null;

  final parts = [
    if (hours > 0) strings.catCatchDurationHours(hours),
    if (minutes > 0) strings.catCatchDurationMinutes(minutes),
    strings.catCatchDurationSeconds(seconds),
  ];
  return parts.join(strings.localeName.startsWith('zh') ? '' : ' ');
}
