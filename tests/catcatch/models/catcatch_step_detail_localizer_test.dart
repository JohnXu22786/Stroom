import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_step_detail_localizer.dart';
import 'package:stroom/l10n/app_localizations.dart';

void main() {
  test('localizes legacy count, selection, playlist, and skip details', () {
    final english = lookupAppLocalizations(const Locale('en', 'US'));
    final chinese = lookupAppLocalizations(const Locale('zh', 'CN'));

    expect(
      localizeCatCatchStepDetail('获取到3个媒体资源', english),
      'Found 3 media resources',
    );
    expect(
      localizeCatCatchStepDetail('共2个资源，请用户选择', english),
      '2 resources found. Choose one.',
    );
    expect(
      localizeCatCatchStepDetail('自动选择第1个结果，进入下载', english),
      'Automatically selected result 1 and started downloading',
    );
    expect(
      localizeCatCatchStepDetail('获取到8个资源（播放列表6个分段）', english),
      'Found 8 resources (6 playlist segments)',
    );
    expect(
      localizeCatCatchStepDetail('浏览器中获取到3个资源', english),
      'Browser found 3 resources',
    );
    expect(
      localizeCatCatchStepDetail('.mp4 格式无需转换，已跳过', english),
      'Conversion skipped for .mp4; this format needs no conversion',
    );
    expect(
      localizeCatCatchStepDetail('. 格式无需转换，已跳过', english),
      'Conversion skipped; this format needs no conversion',
    );

    expect(localizeCatCatchStepDetail('获取到3个媒体资源', chinese), '获取到3个媒体资源');
    expect(localizeCatCatchStepDetail('共2个资源，请用户选择', chinese), '共2个资源，请用户选择');
  });

  test(
      'localizes legacy duration details without losing values and preserves unknown text',
      () {
    final english = lookupAppLocalizations(const Locale('en', 'US'));
    final chinese = lookupAppLocalizations(const Locale('zh', 'CN'));

    expect(
      localizeCatCatchStepDetail('按照1小时2分钟3秒时长筛选后剩余4个结果（已排除5个不匹配的资源）', english),
      'After filtering for 1h 2m 3s, 4 results remain (5 unmatched resources excluded)',
    );
    expect(
      localizeCatCatchStepDetail('按时长3秒筛选，4个资源全部匹配', english),
      'All 4 resources match the 3s duration filter',
    );
    expect(
      localizeCatCatchStepDetail('按时长3秒筛选，4个资源全部匹配', chinese),
      '按时长3秒筛选，4个资源全部匹配',
    );
    expect(
      localizeCatCatchStepDetail('download failed: network error', english),
      'download failed: network error',
    );
  });
}
