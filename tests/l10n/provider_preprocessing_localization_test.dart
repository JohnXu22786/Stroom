import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';

void main() {
  test('preprocessing help explains that resampling may affect accuracy', () {
    const expectedHelpByLanguage = <String, String>{
      'ar': 'تقلل حجم الملف الصوتي، لكن إعادة أخذ العينات قد تغيّر الصوت وتؤثر في دقة التفريغ النصي.',
      'de': 'Verringert die Größe der Audiodatei, aber das Resampling kann das Audio verändern und die Transkriptionsgenauigkeit beeinträchtigen.',
      'en': 'Reduces audio file size, but resampling can change the audio and may affect transcription accuracy.',
      'es': 'Reduce el tamaño del archivo de audio, pero el remuestreo puede cambiar el audio y afectar la precisión de la transcripción.',
      'fr': 'Réduit la taille des fichiers audio, mais le rééchantillonnage peut modifier l’audio et affecter la précision de la transcription.',
      'ja': '音声ファイルのサイズを削減しますが、リサンプリングによって音声が変化し、文字起こしの精度に影響する場合があります。',
      'ko': '오디오 파일 크기를 줄이지만, 리샘플링으로 오디오가 변경되어 전사 정확도에 영향을 줄 수 있습니다.',
      'pt': 'Reduz o tamanho do arquivo de áudio, mas a reamostragem pode alterar o áudio e afetar a precisão da transcrição.',
      'zh': '降低音频文件大小，但重采样可能会改变音频并影响转写准确率。',
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final strings = lookupAppLocalizations(locale);

      expect(
        strings.providerPreprocessingHelp,
        expectedHelpByLanguage[locale.languageCode],
        reason: 'Unexpected preprocessing help for ${locale.toLanguageTag()}',
      );
    }
  });
}
