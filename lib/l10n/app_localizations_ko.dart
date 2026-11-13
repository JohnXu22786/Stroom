// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get galleryPermissionTitle => '사진 라이브러리 접근 권한 필요';

  @override
  String get galleryPermissionMessage =>
      '시스템 설정에서 Stroom이 사진과 동영상에 접근하도록 허용해 주세요.';

  @override
  String get galleryPermissionCancel => '취소';

  @override
  String get galleryPermissionOpenSettings => '설정 열기';

  @override
  String get languageSettingsTitle => '언어';

  @override
  String get followSystemLanguage => '시스템 설정 따르기';

  @override
  String get themeDisplaySettingsTitle => '테마 및 디스플레이';

  @override
  String get themeDisplayThemeSection => '테마';

  @override
  String get themeModeLight => '라이트 모드';

  @override
  String get themeModeDark => '다크 모드';

  @override
  String get themeModeSystem => '시스템 설정 따르기';

  @override
  String get languageNameEnglish => '영어';

  @override
  String get languageNameChinese => '중국어(간체)';

  @override
  String get languageNameKorean => '한국어';

  @override
  String get languageNamePortuguese => '포르투갈어 (브라질)';

  @override
  String get languageSearchHint => '언어 검색';

  @override
  String get languageNoMatches => '일치하는 언어가 없습니다';

  @override
  String get builtInPromptGeneralName => '일반 어시스턴트';

  @override
  String get builtInPromptGeneralDescription =>
      '일상적인 대화와 다양한 질문에 답하는 다목적 AI 어시스턴트입니다.';

  @override
  String get builtInPromptGeneralPrompt =>
      '도움이 되는 AI 어시스턴트입니다. 사용자가 사용하는 언어로 답변하세요. 간결하고 명확하며 논리적으로 정리해 답하세요. 확실하지 않은 내용은 솔직하게 모른다고 말하세요.';

  @override
  String get builtInPromptCodeExpertName => '코드 전문가';

  @override
  String get builtInPromptCodeExpertDescription =>
      '다양한 프로그래밍 언어와 기술 스택에 능숙한 숙련된 프로그래머입니다.';

  @override
  String get builtInPromptCodeExpertPrompt =>
      '다양한 프로그래밍 언어와 기술 스택에 능숙한 숙련된 소프트웨어 엔지니어입니다. 사용자의 질문에 따라 품질 높은 코드 예시, 기술 설명, 모범 사례를 제시하세요. 가독성, 성능, 보안을 우선하세요. 코드를 제공할 때는 언어를 표시하고 적절한 형식을 사용하세요. 시스템 설계 질문에는 아키텍처 관점에서 장단점을 분석하세요.';

  @override
  String get builtInPromptTranslationName => '번역 어시스턴트';

  @override
  String get builtInPromptTranslationDescription =>
      '다국어 번역과 현지화 조언을 제공하는 전문 번역가입니다.';

  @override
  String get builtInPromptTranslationPrompt =>
      '전문 번역가입니다. 다음을 수행하세요:\n1. 사용자가 제공한 내용을 문체와 어조를 유지해 정확하게 번역하세요.\n2. 특정 언어로 어떻게 말하는지 물으면 자연스러운 표현을 알려 주세요.\n3. 문화적 맥락에 맞는 현지화 조언을 제공하세요.\n4. 번역이 여러 가지로 가능하면 각각을 제시하고 차이를 설명하세요.\n먼저 출발어와 도착어를 확인하고, 둘 중 하나라도 불분명하면 사용자에게 물어보세요.';

  @override
  String get builtInPromptEnglishTeacherName => '영어 교사';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      '듣기, 말하기, 읽기, 쓰기 실력을 높여 주는 영어 학습 튜터입니다.';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      '숙련된 영어 교사입니다. 다음과 같이 사용자의 요구를 도와주세요:\n1. 문법 설명: 규칙을 명확히 설명하고 예문을 포함하세요.\n2. 어휘 학습: 단어의 용법, 연어, 의미 차이를 설명하세요.\n3. 글 다듬기: 영어 문장이 자연스럽게 들리도록 개선하세요.\n4. 회화 연습: 영어권 상황을 시뮬레이션하세요.\n5. 발음 안내: 발음 기호와 비슷한 소리로 발음을 설명하세요.\n사용자의 영어 수준에 맞춰 난이도를 조절하고, 설명을 보조할 때는 중국어를 사용하세요.';

  @override
  String get builtInPromptInterviewerName => '면접관';

  @override
  String get builtInPromptInterviewerDescription =>
      '기술 면접과 인성 면접을 연습하는 모의 면접관입니다.';

  @override
  String get builtInPromptInterviewerPrompt =>
      '전문 면접관입니다. 사용자가 목표로 하는 직무의 모의 면접을 진행하세요:\n1. 먼저 목표 직무와 업계를 파악하세요.\n2. 관련 기술, 인성, 시스템 설계 질문을 하세요.\n3. 사용자의 답변을 평가하고 개선점을 제안하세요.\n4. 예시 답변과 그 이유를 제시하세요.\n5. 현실적인 속도로 진행하세요. 한두 가지 질문을 한 뒤 사용자의 답변을 기다리세요.\n사용자가 면접 역량을 높일 수 있도록 전문적이고 친근하게 진행하세요.';

  @override
  String get builtInPromptWritingName => '글쓰기 어시스턴트';

  @override
  String get builtInPromptWritingDescription =>
      '다양한 장르와 창작 글쓰기를 돕는 글쓰기 및 편집 어시스턴트입니다.';

  @override
  String get builtInPromptWritingPrompt =>
      '전문 글쓰기 컨설턴트입니다. 사용자의 필요에 따라 다음을 제공하세요:\n1. 초안 작성: 논증문, 설명문, 서사문 등의 장르로 작성하세요.\n2. 편집: 문법, 어휘 선택, 논리, 구성, 표현을 개선하세요.\n3. 개요 작성: 글의 틀을 만들고 핵심 내용을 찾도록 도우세요.\n4. 창의적 아이디어: 영감과 가능한 관점을 제안하세요.\n5. 형식 지정: 대상 장르의 관례와 제출 요건을 따르세요.\n먼저 목적, 대상 독자, 원하는 문체를 파악한 뒤 초점을 맞춰 조언하세요.';

  @override
  String get builtInPromptCreativeThinkerName => '창의적 사고 파트너';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      '새로운 아이디어를 이끌어 내는 창의적 발상 및 브레인스토밍 파트너입니다.';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      '창의적 사고 파트너입니다. 다음을 수행하세요:\n1. 브레인스토밍: 주제를 중심으로 다양한 창의적 방향을 제안하세요.\n2. 개념 발전: 기존 아이디어를 심화하고 확장하세요.\n3. 분야 연결: 서로 다른 분야의 개념을 새로운 방식으로 결합하세요.\n4. 역발상: 관습적인 사고에 도전하고 색다른 관점을 제시하세요.\n5. 실현 가능성 검토: 구현상의 어려움과 잠재적 가치를 분석하세요.\n발산적 사고를 장려하되 적절한 시점에 논의를 정리하세요. 답변마다 세 가지에서 다섯 가지 방향을 제안하세요.';

  @override
  String get builtInPromptDataAnalystName => '데이터 분석가';

  @override
  String get builtInPromptDataAnalystDescription =>
      '데이터를 이해하고 모델링하며 시각화하도록 돕는 데이터 분석 전문가입니다.';

  @override
  String get builtInPromptDataAnalystPrompt =>
      '데이터 분석 전문가입니다. 사용자의 질문에 따라 다음을 제공하세요:\n1. 분석 방법: 적절한 통계 방법과 분석 프레임워크를 선택하세요.\n2. SQL/Python/R 코드: 데이터 처리와 분석을 위한 예제를 제시하세요.\n3. 시각화 조언: 적절한 차트 유형과 도구를 추천하세요.\n4. 해석: 분석 결과와 비즈니스상 의미를 설명하세요.\n5. 데이터 정리: 결측값, 이상치 및 기타 품질 문제를 처리하세요.\n먼저 분석 목표와 데이터 특성을 파악하세요. Python 생태계(pandas, numpy, matplotlib, seaborn)를 우선적으로 사용하세요.';

  @override
  String get builtInPromptRoleplayName => '역할극';

  @override
  String get builtInPromptRoleplayDescription => '여러 등장인물과 몰입감 있게 역할극을 진행합니다.';

  @override
  String get builtInPromptRoleplayPrompt =>
      '이제 역할극 모드입니다. 사용자가 지정한 인물을 연기하고 그 인물의 성격, 어조, 지식에 맞춰 대화하세요:\n1. 사용자가 “[캐릭터]를 연기해”라고 말하면 즉시 해당 인물로 전환하세요.\n2. 대화 내내 역할을 유지하세요.\n3. 인물의 말투와 지식을 설명에 맞추세요.\n4. 사용자는 “역할극을 종료해”라고 말해 역할극을 끝낼 수 있습니다.\n5. 인물에 어울리는 합리적인 허구의 세부 사항을 추가해도 됩니다.\n사용자가 인물을 지정할 때까지 기다리세요.';

  @override
  String get builtInPromptLifeAdvisorName => '생활 상담가';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      '정신 건강 지원과 일상 조언을 따뜻하고 사려 깊게 제공하는 경청자입니다.';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      '따뜻하고 사려 깊은 생활 상담가입니다. 다음을 수행하세요:\n1. 적극적으로 경청하고 사용자의 걱정과 감정적 필요를 이해하세요.\n2. 문제를 합리적으로 분석하고 여러 측면을 정리하도록 도우세요.\n3. 일상을 개선할 수 있는 구체적이고 실행 가능한 방법을 제안하세요.\n4. 이해와 격려, 긍정적인 지지를 전하세요.\n5. 필요할 때 전문가의 도움을 권하세요.\n기억하세요. 공인 정신 건강 상담사가 아닙니다. 심각한 정신 건강 위기에는 전문가의 도움을 받도록 권하세요. 선을 넘지 않으면서 공감하고, 사용자를 대신해 결정하지 말고 지원하세요.';

  @override
  String get builtInSystemTitleName => '제목 생성 어시스턴트';

  @override
  String get builtInSystemTitleDescription => '대화에서 짧은 제목을 자동으로 생성합니다.';

  @override
  String get builtInSystemTitlePrompt =>
      '제목 생성기입니다. 대화 제목 하나만 출력하고 다른 내용은 쓰지 마세요.\n\n규칙:\n- 한 줄로 쓰고 50자를 넘기지 마세요.\n- 설명하거나 따옴표를 사용하지 마세요.\n- 사용자의 메시지와 같은 언어를 사용하세요.\n- 제목에 web_search나 todowrite 같은 도구 이름을 넣지 마세요.\n\n예시:\n“운영 환경의 500 오류를 디버깅하는 방법을 알려주세요” → 운영 환경의 500 오류 디버깅\n“사용자 서비스를 리팩터링해 주세요” → 사용자 서비스 리팩터링\n“app.js는 왜 실패하나요?” → app.js 오류 원인 파악\n\n사용자의 메시지가 매우 짧거나 단순한 인사(예: “안녕하세요”, “하하”, “지금 있나요?”)라면 인사, 가벼운 대화, 간단한 확인처럼 어조나 의도를 반영하는 제목을 만드세요.';

  @override
  String get builtInSystemCompactionName => '대화 요약 어시스턴트';

  @override
  String get builtInSystemCompactionDescription =>
      '긴 대화를 구조화된 고정 요약으로 압축해 컨텍스트 공간을 확보합니다.';

  @override
  String get builtInSystemCompactionPrompt =>
      '고정 컨텍스트 요약 어시스턴트입니다. 긴 대화를 구조화된 요약으로 압축하세요.\n\n제공된 대화 기록만 요약하세요. 최근 메시지는 원문 그대로 보존될 수 있으므로 여전히 중요한 오래된 맥락에 집중하세요.\n\n프롬프트에 <previous-summary> 블록이 있으면 이를 현재 고정 요약으로 취급하세요. 여전히 유효한 내용은 유지하고, 오래된 내용은 제거하며, 새로운 사실을 반영하세요.\n\n다음 구조를 정확히 따르세요. 순서를 유지하고 비어 있는 경우에도 모든 섹션을 포함하세요:\n<template>\n## 목표\n- [사용자 목표를 한두 문장으로 작성]\n\n## 중요 정보\n- [제약/선호, 결정과 이유, 중요 사실/가정, 이어서 진행하는 데 필요한 정확한 맥락. 비어 있으면 (없음) 작성]\n\n## 작업 상태\n### 완료\n- [완료된 작업, 확인된 사실 또는 변경 사항. 비어 있으면 (없음) 작성]\n\n### 진행 중\n- [현재 진행 중인 작업, 부분 변경 또는 조사. 비어 있으면 (없음) 작성]\n\n### 차단됨\n- [장애 요인, 실패한 명령 또는 확인되지 않은 사항. 비어 있으면 (없음) 작성]\n\n## 다음 단계\n1. [다음에 수행할 구체적인 작업 또는 (없음)]\n2. [예정된 후속 작업 또는 (없음)]\n\n## 관련 파일\n- [관련 파일 또는 디렉터리 경로와 중요성. 비어 있으면 (없음) 작성]\n</template>\n\n규칙:\n- 빈 섹션도 포함해 모든 섹션을 작성하세요.\n- 문단 대신 간결한 글머리표를 사용하세요.\n- 정확한 파일 경로, 기호, 명령, 오류 메시지, URL, 식별자를 보존하세요.\n- 요약, 압축, 맥락 통합을 하고 있다고 언급하지 마세요.\n- 대화와 같은 언어를 사용하세요.';

  @override
  String get builtInPromptMarketTitle => '어시스턴트 마켓';

  @override
  String get builtInPromptClose => '닫기';

  @override
  String get builtInPromptImportHint =>
      '가져온 프롬프트는 자유롭게 편집할 수 있는 일반 어시스턴트가 됩니다.';

  @override
  String get builtInPromptView => '프롬프트 보기';

  @override
  String get builtInPromptAdd => '추가';

  @override
  String get builtInPromptDescriptionHeading => '설명';

  @override
  String get builtInPromptSystemPromptHeading => '시스템 프롬프트';

  @override
  String get builtInPromptAddAssistant => '어시스턴트 추가';

  @override
  String builtInPromptViewerTitle(Object name) {
    return '프롬프트 · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      '자동 제목 생성과 대화 요약에 사용할 별도의 모델과 프롬프트를 설정합니다. 기본적으로 현재 채팅 모델과 내장 프롬프트를 사용합니다.';

  @override
  String get systemAssistantTitleName => '제목 생성 어시스턴트';

  @override
  String get systemAssistantTitleDescription => '대화 제목을 자동으로 생성합니다';

  @override
  String get systemAssistantCompactionName => '대화 요약 어시스턴트';

  @override
  String get systemAssistantCompactionDescription => '대화를 고정 요약으로 압축합니다';

  @override
  String get systemAssistantFollowCurrentModel => '현재 채팅 모델 따르기';

  @override
  String get systemAssistantChooseModel => '모델 선택';

  @override
  String get systemAssistantResetPromptTitle => '기본 프롬프트로 재설정';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '“$taskTitle”의 내장 기본 프롬프트를 복원할까요? 현재 사용자 지정 프롬프트는 삭제됩니다.';
  }

  @override
  String get systemAssistantCancel => '취소';

  @override
  String get systemAssistantReset => '재설정';

  @override
  String get systemAssistantModelHeading => '모델';

  @override
  String get systemAssistantPromptHeading => '프롬프트';

  @override
  String get systemAssistantCustomPromptHint => '변경 사항은 사용자 지정 프롬프트로 사용됩니다';

  @override
  String get systemAssistantUsingCustomPrompt => '사용자 지정 프롬프트 사용 중';

  @override
  String get systemAssistantUsingDefaultPrompt => '기본 프롬프트 사용 중';

  @override
  String get systemAssistantSave => '저장';

  @override
  String get systemAssistantResetButton => '기본 프롬프트로 재설정';

  @override
  String get taskFlowPageTitle => '작업 흐름';

  @override
  String get taskFlowSampleTemplatesTooltip => '예시 템플릿';

  @override
  String get taskFlowEmptyState => '아직 작업 흐름이 없습니다. +를 눌러 만드세요.';

  @override
  String get taskFlowStartFromTemplate => '템플릿에서 시작';

  @override
  String get taskFlowChooseTemplate => '예시 템플릿 선택';

  @override
  String get taskFlowTemplateIntroduction =>
      '필요한 작업과 가장 비슷한 흐름을 선택하세요. 나중에 조정할 수 있습니다.';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 템플릿',
      one: '$count개 템플릿',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      '템플릿은 설정이 필요한 초안으로 열립니다. 저장하기 전에 모델과 어시스턴트를 선택하세요.';

  @override
  String get taskFlowTemplateRecordingName => '녹음 파일 받아쓰기 및 요약';

  @override
  String get taskFlowTemplateRecordingDescription => '녹음 선택 → 음성 인식 → 어시스턴트 요약';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'ASR 모델을 설정하고 요약을 담당할 어시스턴트를 선택하세요.';

  @override
  String get taskFlowTemplateImageTextName => '이미지 텍스트 인식 및 정리';

  @override
  String get taskFlowTemplateImageTextDescription =>
      '이미지 선택 → 텍스트 인식 → 어시스턴트 정리';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'OCR 모델을 설정하고 텍스트를 정리할 어시스턴트를 선택하세요.';

  @override
  String get taskFlowTemplateReadImageName => '이미지에서 텍스트 읽기';

  @override
  String get taskFlowTemplateReadImageDescription => '이미지 선택 → 텍스트 인식 → 음성 재생';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'OCR 및 음성 합성 모델을 설정한 다음 음성을 선택하세요.';

  @override
  String get taskFlowActions => '흐름 작업';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 블록',
      one: '$count개 블록',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'OCR';

  @override
  String get taskFlowBlockAsr => '음성 인식';

  @override
  String get taskFlowBlockAudioSeparation => '오디오 분리';

  @override
  String get taskFlowBlockCatCatch => '웹 리소스 다운로드';

  @override
  String get taskFlowBlockTts => '음성 합성';

  @override
  String get taskFlowBlockChat => '어시스턴트 채팅';

  @override
  String get taskFlowBlockCustom => '사용자 지정 블록';

  @override
  String get taskFlowEdit => '편집';

  @override
  String get taskFlowCopy => '복사';

  @override
  String get taskFlowCopied => '복사됨';

  @override
  String get taskFlowDelete => '삭제';

  @override
  String get taskFlowConfirmDelete => '삭제 확인';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return '작업 흐름 “$flowName”을(를) 삭제할까요?';
  }

  @override
  String get taskFlowUseTemplate => '사용';

  @override
  String get taskFlowOcrInputMissing => '이미지 파일을 찾을 수 없습니다. 이미지를 다시 선택하세요.';

  @override
  String get taskFlowOcrInputReadFailed =>
      '이미지 파일을 읽을 수 없습니다. 파일 접근 권한을 확인하고 다시 시도하세요.';

  @override
  String get taskFlowOcrModelUnavailable =>
      '사용 가능한 OCR 모델이 설정되지 않았습니다. 흐름 설정에서 OCR 제공업체와 모델을 선택하세요.';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'OCR 요청 크기 한도($size MiB)';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return '작업 흐름 이미지 입력 한도($size MiB)';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return '이미지가 $limit을(를) 초과합니다. 더 작은 이미지를 선택하고 다시 시도하세요.';
  }

  @override
  String get ocrTemplatePlainTextLabel => '일반 텍스트';

  @override
  String get ocrTemplatePlainTextContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기고 줄바꿈과 문단을 유지하세요. 설명이나 추론을 덧붙이지 말고 일반 텍스트만 반환하세요.';

  @override
  String get ocrTemplateMarkdownLabel => 'Markdown';

  @override
  String get ocrTemplateMarkdownContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기고 제목, 목록, 표를 보존하도록 Markdown을 사용하세요. 수식은 LaTeX로 표시하세요. 설명이나 추론을 덧붙이지 말고 옮긴 내용만 반환하세요.';

  @override
  String get ocrTemplateTableLabel => '표';

  @override
  String get ocrTemplateTableContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기세요. 표에서는 머리글, 행과 열의 관계, 빈 셀을 유지하고 Markdown 표로 출력하세요. 나머지 내용은 일반 텍스트로 작성하세요. 설명이나 추론을 덧붙이지 말고 옮긴 내용만 반환하세요.';

  @override
  String get ocrTemplateLatexLabel => 'LaTeX';

  @override
  String get ocrTemplateLatexContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기세요. 수식이 아닌 텍스트는 그대로 유지하고 수학 수식은 LaTeX로 표시하세요. 인라인 수식에는 \$...\$, 디스플레이 수식에는 \$\$...\$\$를 사용하세요. 설명이나 추론을 덧붙이지 말고 옮긴 내용만 반환하세요.';

  @override
  String get ocrDefaultImagesOnly => '기본값(이미지만 전송)';

  @override
  String get ocrDefaultSystemPrompt =>
      '이미지의 모든 텍스트를 원래 서식과 레이아웃을 유지해 추출하세요. 설명을 덧붙이지 말고 추출한 텍스트만 반환하세요.';

  @override
  String get ocrSavedInstructionSnapshot => '저장된 지침 스냅샷';

  @override
  String get ocrPageTitle => '이미지 텍스트 인식';

  @override
  String get ocrImageQualitySettings => '이미지 품질 설정';

  @override
  String get ocrImageQualityStandard => '표준 품질';

  @override
  String get ocrImageQualityStandardHint => '대부분의 경우에 적합한 작은 이미지';

  @override
  String get ocrImageQualityOriginal => '원본 / 고해상도';

  @override
  String get ocrImageQualityOriginalHint =>
      '더 많은 세부 정보를 유지합니다. 이미지와 요청 크기가 커집니다.';

  @override
  String get ocrReorderDone => '완료';

  @override
  String get ocrReorderAction => '순서 변경';

  @override
  String get ocrClearAction => '지우기';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return '이전 작업에서 모델 $modelId을(를) 사용했습니다. 제공업체와 모델을 다시 선택하세요.';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      '이전 재시도 기록의 모델 위치가 올바르지 않습니다. 모델을 다시 선택하세요.';

  @override
  String get ocrLegacyModelPositionConfirm =>
      '이전 재시도 기록에는 모델 위치만 저장되어 있습니다. 계속하기 전에 현재 모델을 확인하세요.';

  @override
  String get ocrModelUnavailable =>
      '원래 OCR 제공업체 또는 모델을 더 이상 사용할 수 없습니다. 다른 모델을 선택하세요.';

  @override
  String get ocrModelLabel => '모델';

  @override
  String get ocrConfigure => '설정';

  @override
  String get ocrSelectModel => '모델 선택';

  @override
  String get ocrInstructionLabel => '지침';

  @override
  String get ocrManageInstructions => '인식 지침 관리';

  @override
  String get ocrInstructionManageGuidance =>
      '이 지침은 모든 인식 모델에 적용됩니다. 선택한 지침이 없으면 이미지만 전송됩니다.';

  @override
  String get ocrInstructionManageEmpty => '아직 지침이 없습니다';

  @override
  String get ocrInstructionEditTooltip => '지침 편집';

  @override
  String get ocrInstructionDeleteTooltip => '지침 삭제';

  @override
  String get ocrInstructionAdd => '지침 추가';

  @override
  String get ocrInstructionEditorEditTitle => '지침 편집';

  @override
  String get ocrInstructionNameLabel => '지침 이름(선택 사항)';

  @override
  String get ocrInstructionContentLabel => '지침 내용';

  @override
  String get ocrBatchMode => '일괄 처리 모드';

  @override
  String get ocrMergeRecognition => '결과 합치기';

  @override
  String get ocrRecognizeEachImage => '이미지를 각각 인식';

  @override
  String get ocrMaxConcurrency => '최대 동시 요청 2개';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동시 요청 $count개',
      one: '동시 요청 $count개',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동시 요청 $count개',
      one: '동시 요청 $count개',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint =>
      '완료된 페이지는 유지됩니다. 재시도하면 미완료 페이지에만 요청을 보냅니다.';

  @override
  String get ocrTakePhoto => '사진 촬영';

  @override
  String get ocrChooseFromAlbum => '앨범에서 선택';

  @override
  String get ocrNoImagesSelected => '선택한 이미지가 없습니다';

  @override
  String get ocrSelectImagesHint => '사진을 찍거나 앨범에서 여러 이미지를 선택해 인식하세요.';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '재시도하기 전에 이미지 $_temp0를 모두 다시 선택하세요.';
  }

  @override
  String ocrImageLabel(Object index) {
    return '이미지 $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return '이미지_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => '잘못된 이미지 인덱스';

  @override
  String get ocrViewErrorDetails => '오류 세부 정보 보기';

  @override
  String get ocrConfirmModel => '이 모델 확인';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미지 $count개 선택됨',
      one: '이미지 $count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => '이미지 준비 중…';

  @override
  String get ocrSavingRetryImages => '재시도 이미지 저장 중…';

  @override
  String get ocrRecognizing => '인식 중…';

  @override
  String get ocrReadingRetryImages => '재시도 이미지 읽는 중…';

  @override
  String get ocrImportingImages => '이미지 가져오는 중…';

  @override
  String get ocrStartRecognition => '인식 시작';

  @override
  String get ocrSaveTo => '저장 위치';

  @override
  String get ocrRootDirectory => '루트 디렉터리';

  @override
  String get ocrChooseSaveFolder => '저장할 폴더 선택';

  @override
  String get ocrChooseImageSource => '이미지 소스 선택';

  @override
  String get ocrChooseAppAlbum => '앱 앨범에서 선택';

  @override
  String get ocrAppAlbumDescription => '앱에 이미 저장된 이미지 선택';

  @override
  String get ocrChooseSystemAlbum => '시스템 앨범에서 선택';

  @override
  String get ocrSystemAlbumDescription => '이 기기의 이미지를 찾아 선택';

  @override
  String ocrTakePhotoFailed(Object error) {
    return '사진 촬영 실패: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return '이미지 선택 실패: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '이미지 $_temp0를 불러왔습니다';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return '이미지 처리 실패: $error';
  }

  @override
  String get ocrUnknownSourceImageCount => '원본 이미지 수를 확인할 수 없습니다';

  @override
  String get ocrConfirmClear => '지우기 확인';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      '원본 OCR 이미지 캐시를 사용할 수 없어 이미지 수를 복구할 수 없습니다. 지우면 이전 재시도 상태가 초기화됩니다. 이 OCR 작업에 사용할 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrConfirmClearSelected => '선택한 OCR 이미지를 지울까요?';

  @override
  String get ocrCancel => '취소';

  @override
  String get ocrConfirmResetAndReselect => '초기화하고 이미지를 다시 선택';

  @override
  String get ocrRequestCheckFailed => 'OCR 요청을 확인할 수 없습니다. 모델 매개변수를 확인하세요.';

  @override
  String get ocrCancelledAdjustAndRetry =>
      '인식이 취소되었습니다. 제공업체/모델 요청 크기 또는 이미지 품질을 조정한 뒤 다시 시도하세요.';

  @override
  String get ocrRequestSizeExceededTitle => 'OCR 요청이 설정된 크기 한도를 초과했습니다';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return '요청 크기는 약 $requestSize MiB로 설정된 한도 $limit MiB를 초과합니다.';
  }

  @override
  String get ocrRequestSizeHelp =>
      '제공업체 기본값이나 모델 재정의에서 요청 크기를 조정하거나 다른 이미지 품질을 선택하세요. 품질을 변경한 뒤에는 이미지를 지우고 다시 가져오세요.';

  @override
  String get ocrUsePerImageMode => '이미지별 인식 사용';

  @override
  String get ocrGotIt => '확인';

  @override
  String get ocrWaitForImport => '인식을 시작하기 전에 이미지 가져오기가 끝날 때까지 기다리세요.';

  @override
  String get ocrWaitForRetryImages => '재시도 이미지를 읽는 중입니다. 잠시 기다려 주세요.';

  @override
  String get ocrConfigureProviderModel => '먼저 설정에서 OCR 제공업체와 모델을 구성하세요.';

  @override
  String get ocrReselectProviderModel => 'OCR 제공업체와 모델을 다시 선택하세요.';

  @override
  String get ocrConfirmLegacyModel => '먼저 이전 재시도 기록의 OCR 모델을 확인하세요.';

  @override
  String get ocrRetryImagesUnavailable =>
      '원본 OCR 이미지 캐시를 사용할 수 없습니다. 작업을 지우고 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImageCountUnknown =>
      '원본 OCR 이미지 캐시를 사용할 수 없어 이미지 수를 알 수 없습니다. 초기화한 뒤 이 OCR 작업의 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImageReset =>
      '이전 재시도 입력이 초기화되었습니다. 이 OCR 작업의 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImagesUnreadable =>
      '원본 OCR 이미지 캐시를 읽을 수 없습니다. 작업을 지우고 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImagesMissing =>
      '원본 OCR 이미지 캐시가 없거나 손상되었습니다. 작업을 지우고 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrImageListChanged => '이미지 목록이 변경되었습니다. 인식을 다시 시작하세요.';

  @override
  String get ocrReadInstructionFailed => '인식 지침을 읽을 수 없습니다. 다시 시도하세요.';

  @override
  String get ocrErrorDetails => '오류 세부 정보';

  @override
  String get ocrRequestHeading => '요청';

  @override
  String get ocrResponseHeading => '응답';

  @override
  String get ocrNoDetails => '사용 가능한 세부 정보가 없습니다';

  @override
  String get ocrImageLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get ocrCrop => '자르기';

  @override
  String get ocrEdit => '편집';

  @override
  String get ocrProcessingOcrFailed => 'OCR 이미지를 처리하지 못했습니다. 다시 시도하세요.';

  @override
  String get settingsPageTitle => '설정';

  @override
  String get settingsSectionGeneral => '일반';

  @override
  String get settingsSectionProviders => '제공업체';

  @override
  String get settingsSectionSystemAssistant => '시스템 어시스턴트';

  @override
  String get settingsSectionContextManagement => '컨텍스트 관리';

  @override
  String get settingsSectionManagement => '관리';

  @override
  String get settingsSectionAbout => '정보';

  @override
  String get settingsBackupRestore => '백업 및 복원';

  @override
  String get settingsBackupRestoreDescription => '앱 데이터 내보내기 또는 가져오기';

  @override
  String get settingsCookies => '쿠키 및 브라우저 데이터';

  @override
  String get settingsCookiesDescription => '영구 쿠키와 브라우저 저장 공간 관리';

  @override
  String get settingsAppLogs => '앱 로그';

  @override
  String get settingsAppLogsDescription => '앱 실행 로그 보기';

  @override
  String get settingsThemeDisplay => '테마 및 디스플레이';

  @override
  String get settingsThemeDisplayDescription => '다크 모드 및 표시 언어';

  @override
  String get settingsTaskNotifications => '작업 완료 알림';

  @override
  String get settingsTaskNotificationsDescription =>
      '알림 권한과 시스템 설정을 확인하고 알림 안내 보기';

  @override
  String get settingsBackgroundOptimization => '백그라운드 동작 최적화';

  @override
  String get settingsBackgroundOptimizationDescription =>
      '시스템 환경과 백그라운드 서비스 상태를 확인하고 최적화 안내 보기';

  @override
  String get aboutVersionInfo => '버전 정보 보기';

  @override
  String get aboutCheckUpdates => '업데이트 확인';

  @override
  String aboutNewVersionFound(Object version) {
    return '새 버전 $version을(를) 사용할 수 있습니다';
  }

  @override
  String get aboutNewVersion => '새 버전';

  @override
  String get aboutPreviewUpdates => '프리뷰 업데이트';

  @override
  String get aboutPreviewUpdatesDescription => '프리뷰 릴리스 확인 사용';

  @override
  String get aboutProjectHome => '프로젝트 홈';

  @override
  String get aboutFeedback => '문제 신고';

  @override
  String get aboutPrivacyPolicy => '개인정보 처리방침';

  @override
  String get aboutOpenSourceAgreement => '오픈 소스 계약';

  @override
  String get aboutOpenSourceLicenses => '오픈 소스 라이선스';

  @override
  String get aboutCheckingUpdates => '업데이트 확인 중…';

  @override
  String get aboutUpToDate => '최신 버전을 사용하고 있습니다';

  @override
  String aboutUpdateNetworkError(Object details) {
    return '네트워크 오류: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return 'HTTP 상태 $statusCode(으)로 업데이트 확인에 실패했습니다.';
  }

  @override
  String get aboutUpdateInvalidResponse => '업데이트 서버에서 예상하지 못한 응답을 반환했습니다.';

  @override
  String get aboutUpdateCheckFailed => '업데이트 확인에 실패했습니다. 다시 시도하세요.';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return '어시스턴트 업데이트 확인 실패: $error';
  }

  @override
  String get aboutPrivacyContent =>
      'Stroom은 서비스를 이용하는 모든 사람의 개인정보를 존중하고 보호합니다.\n\n1. 카메라 권한: 사진 촬영에만 사용됩니다. 이미지 데이터를 수집하거나 업로드하지 않습니다.\n\n2. 사진 라이브러리 권한: 사진을 선택하고 저장하는 데만 사용됩니다. 모든 사진은 기기에 로컬로 저장됩니다.\n\n3. 데이터 보안: 촬영한 사진은 모두 기기에 로컬로 저장됩니다. 사용자 데이터에 접근하거나 업로드하지 않습니다.\n\n4. 제3자 서비스: 이 앱에는 제3자 분석 또는 광고 서비스가 포함되어 있지 않습니다.\n\n궁금한 점이 있으면 문의해 주세요.';

  @override
  String get aboutClose => '닫기';

  @override
  String get contextToolPruneTitle => '도구 결과 자동 정리(Prune)';

  @override
  String get contextToolPruneDescription =>
      '기준을 초과한 오래된 도구 결과를 자리표시자로 자동 대체해 저장 공간과 컨텍스트를 확보합니다.';

  @override
  String get contextCompactionTriggerSettings => '요약 시작 조건 설정';

  @override
  String get contextCompactionDisabled => '사용 안 함(요약을 실행하지 않음)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return '전역 시작 기준 $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '모델별 재정의 $_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => '요약 시작 조건 설정';

  @override
  String get contextAutoCompaction => '자동 컨텍스트 요약';

  @override
  String get contextAutoCompactionDisabled =>
      '사용하지 않으면 어떤 모델에서도 요약이 실행되지 않습니다.';

  @override
  String get contextGlobalTrigger => '전역 시작 비율';

  @override
  String get contextGlobalTriggerDescription =>
      '개별 설정이 없는 모델은 모델 컨텍스트 창에서 이 비율에 도달하면 요약을 시작합니다.';

  @override
  String contextResetPercent(Object percent) {
    return '$percent%로 재설정';
  }

  @override
  String get contextPerModelSettings => '모델별 설정';

  @override
  String get contextNoConfiguredModels => '설정된 모델이 없습니다';

  @override
  String contextIndependentThreshold(Object threshold) {
    return '독립 기준: $threshold 토큰';
  }

  @override
  String get contextEnterIndependentThreshold => '아래에 독립 기준을 입력하세요';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return '전역 기준 $percent% 따르기';
  }

  @override
  String get contextThresholdField => '독립 기준(토큰)';

  @override
  String get contextThresholdHint => '예: 48000(백분율이 아닌 토큰 수)';

  @override
  String get contextPercentField => '비율';

  @override
  String contextPercentHint(Object percent) {
    return '예: $percent';
  }

  @override
  String get versionInfoTitle => '버전 정보';

  @override
  String get versionNumberLabel => '버전';

  @override
  String get versionReleaseTimeLabel => '릴리스 시간';

  @override
  String get versionLocalBuild => '로컬 빌드';

  @override
  String get versionReleaseNotesLabel => '릴리스 노트';

  @override
  String get versionClose => '닫기';

  @override
  String get updateDialogTitle => '새 버전을 사용할 수 있습니다';

  @override
  String get updateLatestVersionLabel => '최신 버전';

  @override
  String get updateSelectedVersionLabel => '선택한 버전';

  @override
  String get updateReleaseNotesLabel => '릴리스 노트';

  @override
  String get updateInstalling => '설치 중…';

  @override
  String get updateDownloadComplete => '다운로드 완료';

  @override
  String get updateClose => '닫기';

  @override
  String get updateManualInstall => '수동 설치';

  @override
  String get updateOpenInstaller => '설치 프로그램 열기';

  @override
  String get updateRetryDownload => '다운로드 재시도';

  @override
  String get updateSkipVersion => '이 버전 건너뛰기';

  @override
  String get updateRemindLater => '나중에 알림';

  @override
  String get updateOpenBrowser => '브라우저에서 다운로드';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updatePreviewBadge => '프리뷰';

  @override
  String get updateLatestBadge => '최신';

  @override
  String get updateSelectVersion => '버전 선택';

  @override
  String get updateDownloading => '업데이트 다운로드 중…';

  @override
  String updateCheckNetworkError(Object details) {
    return '네트워크 오류: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return '업데이트 확인 실패: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      '업데이트 확인 실패: 서버에서 인식할 수 없는 데이터를 반환했습니다';

  @override
  String get updateDownloadUrlUnavailable => '다운로드 URL을 사용할 수 없습니다.';

  @override
  String get updateNoDirectDownloadLink =>
      '이 플랫폼에는 직접 다운로드 링크가 없습니다. 브라우저에서 다운로드하세요.';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return '자동 설치 실패: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return '다운로드 실패: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return '다운로드 실패: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return '설치 실패: $details';
  }

  @override
  String updateFailed(Object details) {
    return '업데이트 실패: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return '파일을 열 수 없습니다. 수동으로 설치하세요: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return '설치에 실패했습니다. APK를 직접 여세요: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails => '설치에 실패했습니다. APK를 직접 여세요.';

  @override
  String get updateApkInstallerUnavailable =>
      '이 APK를 설치할 앱을 찾을 수 없습니다. APK를 직접 여세요.';

  @override
  String get updateApkInstallPermissionDenied =>
      '시스템 설정에서 Stroom의 알 수 없는 앱 설치를 허용하세요.';

  @override
  String get updateRestartDialogTitle => '앱 업데이트 완료';

  @override
  String get updateRestartDialogBody =>
      '앱이 업데이트되었습니다. 안정적인 사용을 위해 앱을 다시 시작하세요.';

  @override
  String get updateRestartDialogLater => '나중에 다시 시작';

  @override
  String get updateRestartDialogNow => '지금 다시 시작';

  @override
  String get contextCompactionHistoryIntro => '요약할 대화 기록:';

  @override
  String get contextCompactionUserRole => '사용자';

  @override
  String get contextCompactionAssistantRole => '어시스턴트';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role이(가) 도구 $toolName을(를) 호출함: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      '위 대화 기록을 지정된 템플릿에 따라 고정 요약으로 압축하세요.';

  @override
  String get ocrImageEmpty => '이미지가 비어 있습니다. 다시 선택하세요.';

  @override
  String get ocrImageUnsupportedFormat =>
      '지원하지 않는 이미지 형식입니다. PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'HEIC, SVG, TIFF 이미지는 아직 지원되지 않습니다. PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImageDecodeFailed =>
      '이미지가 손상되었거나 디코딩할 수 없습니다. 다시 선택하거나 PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImageDimensionsTooLarge =>
      '이미지 해상도가 너무 큽니다. OCR은 이미지당 최대 5천만 픽셀을 지원합니다. 크기를 줄인 뒤 다시 시도하세요.';

  @override
  String get ocrImageOrientationPngTooLarge =>
      '이미지 방향을 바로잡는 데 필요한 PNG가 OCR 요청 크기 한도를 초과합니다. 이미지 크기를 줄인 뒤 다시 시도하세요.';

  @override
  String get ocrImageOrientationFailed =>
      '이미지 방향을 바로잡을 수 없습니다. PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImagePreparationFailed => '이미지를 처리할 수 없습니다. 다시 선택한 뒤 재시도하세요.';

  @override
  String get homeTitle => '홈';

  @override
  String get homeWelcome => 'Stroom에 오신 것을 환영합니다';

  @override
  String get homeChooseModule => '시작하려면 모듈을 선택하세요';

  @override
  String get homeOcrSubtitle => '텍스트 인식';

  @override
  String get homeAsrTitle => '음성 인식';

  @override
  String get homeAsrSubtitle => '음성을 텍스트로 변환';

  @override
  String get homeWebDownloadTitle => '웹 미디어 다운로드';

  @override
  String get homeWebDownloadSubtitle => '웹페이지에서 오디오와 동영상 다운로드';

  @override
  String get homeAudioSeparationTitle => '오디오 분리';

  @override
  String get homeAudioSeparationSubtitle => '동영상에서 오디오 추출';

  @override
  String get homeTtsTitle => '텍스트 음성 변환';

  @override
  String get homeTtsSubtitle => '텍스트를 음성으로 변환';

  @override
  String get homeChartsTitle => '차트 만들기';

  @override
  String get homeChartsSubtitle => 'Mermaid 차트 편집기';

  @override
  String get homeMathTitle => '수학 그래프';

  @override
  String get homeMathSubtitle => '함수 그래프 그리기';

  @override
  String get homeAnkiTitle => 'Anki 플래시카드';

  @override
  String get homeAnkiSubtitle => '기억 보조 시스템';

  @override
  String get homeTaskFlowTitle => '작업 흐름';

  @override
  String get homeTaskFlowEmpty => '여러 모듈을 차례로 실행하는 자동화 흐름을 만드세요';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 · 관리',
      one: '$count개 · 관리',
    );
    return '작업 흐름 $_temp0';
  }

  @override
  String get homeRecentTasks => '최근 작업';

  @override
  String get homeViewAll => '모두 보기';

  @override
  String get statusInProgress => '진행 중';

  @override
  String get statusCompleted => '완료';

  @override
  String get statusFailed => '실패';

  @override
  String get navHome => '홈';

  @override
  String get navChat => '채팅';

  @override
  String get navFiles => '파일';

  @override
  String get navSettings => '설정';

  @override
  String get conversationsTitle => '대화 기록';

  @override
  String get conversationNew => '새 대화';

  @override
  String get conversationSelectTitle => '대화 선택';

  @override
  String get topicSelectionEmptyTitle => '대화가 없습니다';

  @override
  String get topicSelectionEmptyMessage => '새 대화를 만들어 시작하세요';

  @override
  String get topicSelectionNewTopic => '새 대화';

  @override
  String get topicSelectionNoAssistant => '선택된 어시스턴트 없음';

  @override
  String get topicSelectionBackToAssistants => '어시스턴트 선택으로 돌아가기';

  @override
  String get topicSelectionEditAssistant => '어시스턴트 편집';

  @override
  String get topicSelectionReorderHint => '길게 누른 뒤 끌어서 대화 순서를 변경하세요';

  @override
  String conversationDeleteNamed(String title) {
    return '대화 “$title”을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get conversationDeleteTitle => '대화 삭제';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 대화 $count개를 삭제할까요? 이 작업은 되돌릴 수 없습니다.',
      one: '선택한 대화 $count개를 삭제할까요? 이 작업은 되돌릴 수 없습니다.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => '취소';

  @override
  String get actionDelete => '삭제';

  @override
  String get conversationRename => '대화 이름 변경';

  @override
  String get conversationRenameHint => '새 이름 입력';

  @override
  String get actionConfirm => '확인';

  @override
  String get conversationNoMatches => '일치하는 대화를 찾을 수 없습니다';

  @override
  String get conversationEmpty => '대화 기록이 없습니다';

  @override
  String get conversationSearchHint => '모든 대화에서 메시지 검색...';

  @override
  String conversationSelected(int count) {
    return '$count개 선택됨';
  }

  @override
  String get conversationSearch => '검색';

  @override
  String get conversationDeleteSelected => '선택 항목 삭제';

  @override
  String get actionUnselect => '선택 취소';

  @override
  String get actionSelect => '선택';

  @override
  String conversationDeleteCount(int count) {
    return '$count개 삭제';
  }

  @override
  String get conversationPin => '고정';

  @override
  String get conversationUnpin => '고정 해제';

  @override
  String get actionRename => '이름 변경';

  @override
  String get conversationAutoRename => '자동 이름 지정';

  @override
  String get conversationTemporary => '임시 대화';

  @override
  String get conversationSetTemporary => '임시 대화로 설정';

  @override
  String get conversationCloseTemporary => '임시 대화 닫기';

  @override
  String get conversationKeep => '대화 유지';

  @override
  String get conversationTemporaryStatus => '임시';

  @override
  String get conversationTemporaryWarning => '곧 만료';

  @override
  String get conversationTemporaryExplanation =>
      '이 대화는 1시간 후 삭제됩니다. 메시지를 보내면 타이머가 다시 시작됩니다. 임시 모드를 끄면 대화가 보존됩니다.';

  @override
  String get conversationEnableTemporary => '임시 모드 사용';

  @override
  String get chatLoadingConversation => '대화 불러오는 중…';

  @override
  String get chatEmptyConversation => '메시지를 보내 대화를 시작하세요.';

  @override
  String get chatNoActiveConversation => '대화를 시작하려면 대화를 선택하거나 새로 만드세요.';

  @override
  String get chatConversationLoadError => '대화를 불러오지 못했습니다.';

  @override
  String get chatRetryLoadConversation => '다시 시도';

  @override
  String get taskListTitle => '작업 목록';

  @override
  String get taskListEmpty => '작업이 없습니다';

  @override
  String get unifiedTaskListTabAll => '전체';

  @override
  String get unifiedTaskListTabInProgress => '진행 중';

  @override
  String get unifiedTaskListTabCompleted => '완료';

  @override
  String get unifiedTaskListTabFailed => '실패';

  @override
  String get unifiedTaskListTabStopped => '중지됨';

  @override
  String get unifiedTaskListConfirmClear => '지우기 확인';

  @override
  String get unifiedTaskListConfirmClearFailedMessage => '실패한 작업을 모두 지울까요?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      '작업을 모두 지울까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get unifiedTaskListCancel => '취소';

  @override
  String get unifiedTaskListConfirm => '확인';

  @override
  String get unifiedTaskListClearCompleted => '완료된 작업 지우기';

  @override
  String get unifiedTaskListClearFailed => '실패한 작업 지우기';

  @override
  String get unifiedTaskListClearAll => '모든 작업 지우기';

  @override
  String get unifiedTaskListRestoreInProgress => '작업 흐름 기록 복원 중…';

  @override
  String get unifiedTaskListRestoreFailed =>
      '작업 흐름 기록을 읽을 수 없습니다. 작업이 일시 중지되었습니다';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return '미완료 항목 지우기 실패: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning =>
      '취소한 뒤에도 작업 흐름이 계속 실행 중입니다.';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      '작업 흐름 취소 상태를 저장할 수 없습니다. 다시 지워 보세요.';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      '작업 흐름 기록 삭제를 저장할 수 없습니다. 다시 지워 보세요.';

  @override
  String get chatAutoContinuePrompt => '끝나지 않았다면 계속하세요.';

  @override
  String get chatSearchCurrent => '이 대화 검색...';

  @override
  String get chatSearchAll => '모든 대화 검색...';

  @override
  String get searchPrevious => '이전 일치 항목';

  @override
  String get searchNext => '다음 일치 항목';

  @override
  String get searchClose => '검색 닫기';

  @override
  String get searchCurrentConversation => '현재 대화';

  @override
  String get searchAllConversations => '모든 대화';

  @override
  String get chatReasoning => '추론';

  @override
  String get chatTools => '도구';

  @override
  String get chatCustomParameters => '사용자 지정 매개변수';

  @override
  String get chatEditMessage => '메시지 편집';

  @override
  String get actionClose => '닫기';

  @override
  String get chatEditWarning => '편집 후 다시 보내면 아래에 있는 모든 메시지가 삭제됩니다';

  @override
  String get chatAttachment => '첨부 파일';

  @override
  String get chatMessageHint => '메시지를 입력하세요...';

  @override
  String get chatFullscreenEdit => '전체 화면 편집기';

  @override
  String get chatStopGeneration => '생성 중지';

  @override
  String get actionSend => '보내기';

  @override
  String get chatCopy => '복사';

  @override
  String get actionSave => '저장';

  @override
  String get actionRetry => '재시도';

  @override
  String get actionEdit => '편집';

  @override
  String get chatViewResponseData => '응답 데이터 보기';

  @override
  String get chatViewRequestData => '요청 데이터 보기';

  @override
  String get chatInspectJson => 'JSON 검사';

  @override
  String get chatConfirmEditTitle => '메시지 편집';

  @override
  String get chatConfirmEditDeleteFollowing =>
      '이 메시지를 편집할까요? 이 메시지와 이후의 모든 메시지가 삭제됩니다.';

  @override
  String get chatConfirmResend => '이 메시지를 다시 보낼까요?';

  @override
  String get chatConfirmRetryTitle => '재시도';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      '이 응답을 재시도할까요? 이 메시지와 이후의 모든 메시지가 삭제됩니다.';

  @override
  String get chatConfirmRegenerate => '응답을 다시 생성할까요?';

  @override
  String get chatDeleteMessageTitle => '메시지 삭제';

  @override
  String get chatDeleteMessageConfirm => '이 메시지를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get chatThinking => '생각 중';

  @override
  String get chatThinkingComplete => '생각 완료';

  @override
  String get conversationDeleteOne => '이 대화를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '리소스 $total개 중 $selected개 선택',
      one: '리소스 $total개 중 $selected개 선택',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => '다운로드할 미디어 선택';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '세그먼트 $count개 숨기기',
      one: '세그먼트 $count개 숨기기',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '세그먼트 $count개 표시',
      one: '세그먼트 $count개 표시',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => '감지된 리소스가 없습니다';

  @override
  String get mediaSegment => '세그먼트';

  @override
  String get mediaPlaylist => '재생목록';

  @override
  String get mediaFullVideo => '전체 동영상';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours시간 $minutes분 $seconds초';
  }

  @override
  String mediaDuration(String value) {
    return '길이: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return '해상도: ${width}x$height';
  }

  @override
  String get mediaPreview => '미리보기';

  @override
  String get mediaSegmentPreviewHint => '재생목록에서 세그먼트 미리보기';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 리소스 $count개 다운로드',
      one: '선택한 리소스 $count개 다운로드',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => '다운로드 확인';

  @override
  String get chatNoMoreHistory => '더 이상 메시지가 없습니다';

  @override
  String get chatSendFailed => '메시지를 보내지 못했습니다';

  @override
  String get chatViewErrorDetails => '오류 세부 정보 보기';

  @override
  String get chatCompactionCollapsed => '컨텍스트 요약됨 · 이전 메시지가 요약되었습니다(눌러서 접기)';

  @override
  String get chatCompactionExpanded => '컨텍스트 요약됨 · 이전 메시지가 요약되었습니다(눌러서 요약 보기)';

  @override
  String get chatEditConversationTitle => '대화 제목 편집';

  @override
  String get chatSearchMessages => '메시지 검색';

  @override
  String get chatApiMissingSettings => '⚠️ 채팅 API가 설정되지 않았습니다 — 설정으로 이동하세요';

  @override
  String get appSettings => '설정';

  @override
  String get chatCopied => '복사됨';

  @override
  String get chatNoSavableText => '저장할 텍스트가 없습니다';

  @override
  String get chatSaveMarkdownTitle => '메시지를 Markdown으로 저장';

  @override
  String get chatSaveToolCallChoice => '이 답변에는 여러 도구 호출이 있습니다. 저장할 항목을 선택하세요:';

  @override
  String get chatSaveCompleteMessage => '전체 메시지 저장';

  @override
  String get chatSaveLastMessage => '마지막 메시지 저장';

  @override
  String get chatSaveToAppFiles => '앱 파일에 저장';

  @override
  String get chatSaveFolderHint => '.md 파일을 저장할 폴더를 선택하거나 만드세요';

  @override
  String get chatSaveFilenameHint => '파일 이름을 입력하세요(.md 확장자는 자동으로 추가됩니다)';

  @override
  String get chatFilenameRequired => '파일 이름을 입력해야 합니다';

  @override
  String chatSavedToPath(String path) {
    return '저장 위치: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return '앱 파일에 저장됨: $path';
  }

  @override
  String get chatSelectModel => '모델 선택';

  @override
  String get chatModelFallback => '모델';

  @override
  String get chatNoModelsAvailable => '사용 가능한 모델이 없습니다';

  @override
  String get chatAvailableTools => '사용 가능한 도구';

  @override
  String get chatNoToolsAvailable => '사용 가능한 도구가 없습니다';

  @override
  String get chatReasoningSettings => '추론 설정';

  @override
  String get chatReasoningNotConfigured =>
      '이 모델에 설정된 추론 매개변수가 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatReasoningEffort => '추론 강도';

  @override
  String get chatReasoningEffortNotConfigured =>
      '이 모델에 설정된 추론 강도 매개변수가 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatParameterNoOptions => '이 매개변수에는 선택 항목이 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatOtherReasoningNotConfigured =>
      '이 모델에는 다른 추론 매개변수가 설정되어 있지 않습니다.\n모델 설정에서 추가하세요.';

  @override
  String get chatCustomParamsNotConfigured =>
      '이 모델에는 사용자 지정 매개변수가 설정되어 있지 않습니다.\n모델 설정에서 추가하세요.';

  @override
  String get chatNoOptionValues => '선택 항목이 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatImageLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get chatVideoLoadFailed => '동영상을 불러올 수 없습니다';

  @override
  String get chatHtmlLoading => 'HTML 미리보기 로딩 중...';

  @override
  String get chatPreviewLoadFailed => '미리보기를 불러오지 못했습니다';

  @override
  String get albumPickerLoadFailed => '앱 앨범을 불러올 수 없습니다';

  @override
  String get chatHtmlPreview => 'HTML 미리보기';

  @override
  String get chatMermaidLoading => '차트 미리보기 로딩 중...';

  @override
  String get chatMermaidPreview => 'Mermaid 미리보기';

  @override
  String get chatZoomOut => '축소';

  @override
  String get chatZoomIn => '확대';

  @override
  String get chatJsonInspection => 'JSON 검사';

  @override
  String get chatNoRequestData => '요청 데이터가 없습니다';

  @override
  String get chatNoResponseData => '응답 데이터가 없습니다';

  @override
  String get chatSaveMessage => '메시지 저장';

  @override
  String get chatChooseSaveLocation => '메시지를 저장할 위치 선택';

  @override
  String get chatChooseSaveLocationLabel => '저장 위치 선택:';

  @override
  String get chatSaveAppFile => '앱 파일에 저장';

  @override
  String get chatSaveDevice => '기기에 저장';

  @override
  String get chatFileTypeAudio => '오디오 파일';

  @override
  String get chatFileTypeVideo => '동영상 파일';

  @override
  String get chatFileTypeDocument => '문서';

  @override
  String get chatFileTypeGeneric => '파일';

  @override
  String get chatInfoType => '유형';

  @override
  String get chatInfoSize => '크기';

  @override
  String get chatInfoPath => '경로';

  @override
  String get chatErrorBack => '뒤로';

  @override
  String get chatErrorPrefix => '오류: ';

  @override
  String get chatErrorCancelled => '사용자가 출력을 중단했습니다';

  @override
  String get chatErrorProviderNotConfigured =>
      '채팅 API가 설정되지 않았습니다. 설정을 열어 제공업체를 구성하세요.';

  @override
  String get chatErrorApiKeyNotConfigured => 'API 키가 설정되지 않았습니다. 설정을 확인하세요.';

  @override
  String get chatErrorServerConnection =>
      '서버에 연결할 수 없습니다. 네트워크 연결과 API 주소를 확인하세요.';

  @override
  String get chatErrorNetworkConnection => '네트워크 연결에 실패했습니다. 네트워크 연결을 확인하세요.';

  @override
  String get chatErrorTimeout => '연결 시간이 초과되었습니다. 서버가 응답하지 않았습니다.';

  @override
  String chatAttachmentImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return '사진을 촬영할 수 없습니다: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform에서는 기기 갤러리에 접근할 수 없습니다: $error';
  }

  @override
  String get chatAttachmentWebPlatform => '웹 브라우저';

  @override
  String get chatAttachmentCurrentPlatform => '이 기기';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      '사진 라이브러리 접근 권한을 허용한 뒤 다시 시도하세요.';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      '브라우저 설정에서 이 웹사이트의 파일 접근을 허용하세요.';

  @override
  String get chatAttachmentGalleryFallbackHint => '기기에서 갤러리 선택을 지원하는지 확인하세요.';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return '이미지를 가져올 수 없습니다: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform에서는 파일 선택을 지원하지 않습니다: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint => '파일 접근 권한을 허용한 뒤 다시 시도하세요.';

  @override
  String get chatAttachmentFileFallbackHint => '기기에서 파일 선택을 지원하는지 확인하세요.';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return '파일을 가져올 수 없습니다: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return '$fileName 가져옴';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return '편집한 이미지를 저장할 수 없습니다: $error';
  }

  @override
  String get chatDataDetails => '데이터 세부 정보';

  @override
  String get chatErrorDetailOcrDiagnostics => 'OCR 진단';

  @override
  String get chatErrorDetailRequestUrl => '요청 URL';

  @override
  String get chatErrorDetailRequestHeaders => '요청 헤더';

  @override
  String get chatErrorDetailRequestBody => '요청 본문';

  @override
  String get chatErrorDetailStatusCode => '상태 코드';

  @override
  String get chatErrorDetailResponseHeaders => '응답 헤더';

  @override
  String get chatErrorDetailResponseBody => '응답 본문';

  @override
  String get chatErrorDetailEmpty => '사용할 수 있는 세부 정보가 없습니다';

  @override
  String get chatAudioPreviewClose => '닫기';

  @override
  String get chatPreviewClose => '미리보기 닫기';

  @override
  String get actionBack => '뒤로';

  @override
  String get chatCannotLoadFile => '파일을 불러올 수 없습니다';

  @override
  String chatThinkingNumbered(int index) {
    return '생각 중 $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '저장하지 않은 변경 사항을 버릴까요?';

  @override
  String get taskFlowUiDiscardBody => '돌아가면 저장하지 않은 변경 사항이 모두 사라집니다.';

  @override
  String get taskFlowUiContinueEditing => '계속 편집';

  @override
  String get taskFlowUiDiscard => '버리기';

  @override
  String get taskFlowUiUndo => '실행 취소';

  @override
  String get taskFlowUiSave => '저장';

  @override
  String get taskFlowUiNameHint => '작업 흐름 이름 입력';

  @override
  String get taskFlowUiDescriptionHint => '설명 추가(선택 사항)';

  @override
  String get taskFlowUiNameRequired => '작업 흐름 이름을 입력하세요';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return '단계 $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '“$block”에는 “$parameter”이(가) 필요합니다';
  }

  @override
  String get taskFlowUiSaveFailed => '저장하지 못했습니다. 변경 사항은 그대로 있습니다. 다시 시도하세요.';

  @override
  String get taskFlowUiRetry => '재시도';

  @override
  String get taskFlowUiUpdated => '작업 흐름이 업데이트되었습니다';

  @override
  String get taskFlowUiCreated => '작업 흐름이 생성되었습니다';

  @override
  String get taskFlowUiTitle => '작업 흐름';

  @override
  String get taskFlowUiNotFound => '작업을 찾을 수 없습니다';

  @override
  String get taskFlowUiBack => '뒤로';

  @override
  String get taskFlowUiEdit => '편집';

  @override
  String taskFlowUiInput(Object label) {
    return '입력($label)';
  }

  @override
  String get taskFlowUiInputHint => '텍스트 또는 링크 입력';

  @override
  String get taskFlowUiStart => '작업 흐름 시작';

  @override
  String get taskFlowUiNoInput => '입력이 없습니다. 아래를 눌러 웹 리소스 URL을 추가하세요.';

  @override
  String get taskFlowUiAddResource => '웹 리소스 추가';

  @override
  String get taskFlowUiUrlHint => '동영상 또는 오디오 웹페이지 URL 입력';

  @override
  String get taskFlowUiDeleteInput => '이 입력 삭제';

  @override
  String get taskFlowUiHour => '시간';

  @override
  String get taskFlowUiMinute => '분';

  @override
  String get taskFlowUiSecond => '초';

  @override
  String get taskFlowUiPreview => '미리보기: ';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      '선택 사항: 길이로 동영상 리소스를 필터링합니다. 비워 두면 사용 가능한 모든 리소스를 표시합니다.';

  @override
  String get taskFlowUiSelectImages => '이미지 선택(여러 개)';

  @override
  String get taskFlowUiSelectAudio => '오디오 선택(여러 개)';

  @override
  String get taskFlowUiSelectFiles => '파일 선택(여러 개)';

  @override
  String get taskFlowUiSelectVideo => '동영상 선택(여러 개)';

  @override
  String get taskFlowUiRemove => '제거';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return '제거한 파일을 정리할 수 없습니다: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0. 초기 입력';

  @override
  String taskFlowUiInputType(Object type) {
    return '입력 유형: $type';
  }

  @override
  String get taskFlowUiUserFlowInput => '사용자가 작업 흐름을 실행할 때 제공하는 입력';

  @override
  String taskFlowUiBlockInput(Object type) {
    return '입력: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return '출력: $type';
  }

  @override
  String get taskFlowUiParameters => '매개변수:';

  @override
  String get taskFlowUiClose => '닫기';

  @override
  String get taskFlowUiSelectAppImages => '앱에서 이미지 선택(여러 개)';

  @override
  String get taskFlowUiNoImages => '이미지가 없습니다';

  @override
  String get taskFlowUiSelectAppAudio => '앱에서 오디오 선택(여러 개)';

  @override
  String get taskFlowUiNoAudio => '오디오가 없습니다';

  @override
  String get taskFlowUiSelectAppVideo => '앱에서 동영상 선택(여러 개)';

  @override
  String get taskFlowUiNoVideo => '동영상이 없습니다';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return '파일을 선택할 수 없습니다: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '“$name”의 크기가 $limit MB를 초과합니다. 더 작은 파일을 선택하세요.';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '“$name”이(가) 비어 있거나 읽을 수 없습니다';
  }

  @override
  String get taskFlowUiSomeFilesMissing => '일부 파일이 없어 건너뛰었습니다';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return '선택한 파일 $count개에 접근할 수 없습니다. 모든 파일을 다시 선택하세요.';
  }

  @override
  String get taskFlowUiQueuedOne => '작업 흐름을 대기열에 추가했습니다';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return '작업 흐름 $count개를 대기열에 추가했습니다';
  }

  @override
  String get taskFlowUiRunTitle => '이번 실행';

  @override
  String get taskFlowUiCancelBatch => '전체 일괄 작업 취소';

  @override
  String get taskFlowUiRestoringRecords => '작업 흐름 기록 복원 중…';

  @override
  String get taskFlowUiRecordsPaused => '작업 흐름 기록을 불러올 수 없습니다. 작업이 일시 중지되었습니다.';

  @override
  String get taskFlowUiRecordsCleared => '이번 실행의 기록을 지웠습니다';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$total개 중 $finished개 실행 완료';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return ' · 기록 $count개 삭제됨';
  }

  @override
  String get taskFlowUiTemporaryFiles => '임시 중간 파일';

  @override
  String get taskFlowUiAddBlock => '블록 추가';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return '단계 $index 앞에 블록 삽입';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      '앞뒤 단계와 모두 호환되는 블록이 없습니다. 먼저 앞뒤 단계를 조정하세요.';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return '단계 $index 앞에 삽입';
  }

  @override
  String get taskFlowUiUnknown => '알 수 없음';

  @override
  String get taskFlowUiChooseBlock => '블록 선택';

  @override
  String get taskFlowUiInsertBlock => '블록 삽입';

  @override
  String get taskFlowUiPreviousOutput => '이전 단계 출력';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '; 다음 단계에 필요한 항목: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock => '현재 유형과 호환되는 블록이 없습니다';

  @override
  String get taskFlowUiReplaceBlock => '블록 바꾸기';

  @override
  String get taskFlowUiBlockCompatibility =>
      '입력 및 출력 유형이 호환되는 블록으로만 바꿀 수 있습니다.';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      '다음 단계에서 결과를 성공적으로 저장한 뒤 정리합니다. 마지막 단계의 결과는 항상 보존됩니다.';

  @override
  String get taskFlowUiSetParameters => '매개변수 설정';

  @override
  String get taskFlowUiReplace => '바꾸기';

  @override
  String get taskFlowUiViewParameters => '눌러서 매개변수 보기';

  @override
  String get taskFlowUiTapSetParameters => '눌러서 매개변수 설정';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return '알 수 없는 블록: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => '이 블록 유형은 등록되어 있지 않습니다';

  @override
  String taskFlowUiStepActions(Object index) {
    return '단계 $index 작업';
  }

  @override
  String get taskFlowUiInsertBefore => '앞에 삽입';

  @override
  String get taskFlowUiInsertAfter => '뒤에 삽입';

  @override
  String get taskFlowUiCopyBlock => '블록 복제';

  @override
  String get taskFlowUiMoveUp => '위로 이동';

  @override
  String get taskFlowUiMoveUpDisabled => '위로 이동(이미 첫 번째)';

  @override
  String get taskFlowUiMoveDown => '아래로 이동';

  @override
  String get taskFlowUiMoveDownDisabled => '아래로 이동(이미 마지막)';

  @override
  String get taskFlowUiDeleteBlock => '블록 삭제';

  @override
  String taskFlowUiInputLabel(Object label) {
    return '입력: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return '출력: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return '블록 유형 “$name”은(는) 등록되어 있지 않습니다';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$label 설정';
  }

  @override
  String get taskFlowUiSendToAssistant => '어시스턴트에게 보내는 사용자 메시지는 이전 단계의 출력입니다';

  @override
  String get taskFlowUiTempSpaceInfo =>
      '이 단계의 출력은 흐름의 임시 공간에 저장됩니다. 다음 단계에서 결과를 성공적으로 저장하면 출력이 정리됩니다. 임시 모드를 끄면 원래 저장 폴더가 보존되고 복원됩니다.';

  @override
  String get taskFlowUiNoExtraParameters => '이 블록에는 추가 매개변수가 없습니다';

  @override
  String get taskFlowUiCancel => '취소';

  @override
  String get taskFlowUiConfirm => '확인';

  @override
  String get taskFlowUiConfigureModelFirst => '먼저 모델을 설정하세요';

  @override
  String get taskFlowUiModelUnavailable =>
      '모델을 선택하지 않았거나 선택한 모델을 사용할 수 없습니다. 다른 모델을 선택하세요.';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return '모델 $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => '이름 없는 제공업체';

  @override
  String get taskFlowUiCustomModelParameters => '사용자 지정 모델 매개변수';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      '음성이 설정된 TTS 모델이 없습니다. ID를 직접 입력할 수 있습니다.';

  @override
  String get taskFlowUiVoiceUnavailable => '음성을 사용할 수 없습니다. 다른 음성을 선택하세요.';

  @override
  String get taskFlowUiSelectVoice => '음성 선택';

  @override
  String get taskFlowUiAssistantUnavailable => '어시스턴트를 사용할 수 없습니다';

  @override
  String get taskFlowUiAssistantUseCurrent => '지정 안 함(현재 선택된 어시스턴트 사용)';

  @override
  String get taskFlowUiAssistantDeleted =>
      '설정된 어시스턴트가 삭제되었습니다. 다른 어시스턴트를 선택하세요.';

  @override
  String get taskFlowUiChooseAssistant => '어시스턴트 선택';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      '“내 어시스턴트”만 선택할 수 있습니다(“채팅 → 어시스턴트”에서 추가).';

  @override
  String get taskFlowUiMyAssistants => '내 어시스턴트';

  @override
  String get taskFlowUiNoCustomAssistants =>
      '사용자 지정 어시스턴트가 없습니다. “채팅 → 어시스턴트”에서 만드세요.';

  @override
  String get taskFlowUiYes => '예';

  @override
  String get taskFlowUiNo => '아니요';

  @override
  String get taskFlowUiDefaultRoot => '기본값(루트 폴더)';

  @override
  String get taskFlowUiSelect => '선택';

  @override
  String get taskFlowUiSelectSaveFolder => '저장 폴더 선택';

  @override
  String get taskFlowUiCatCatchVideo => '동영상';

  @override
  String get taskFlowUiCatCatchAudio => '오디오';

  @override
  String get taskFlowUiCatCatchEither => '동영상 또는 오디오(후속 단계에 따라 필터링)';

  @override
  String get taskFlowUiManual => '수동';

  @override
  String get taskFlowUiAutomatic => '자동';

  @override
  String get taskFlowUiAutomaticPrompt => '확인 후 자동 실행';

  @override
  String get taskFlowUiEditTitle => '작업 흐름 편집';

  @override
  String get taskFlowUiCreateTitle => '새 작업 흐름';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return '단계 $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return '입력 유형: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return '입력: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return '출력: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return '제거한 파일을 정리할 수 없습니다: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return '파일을 선택할 수 없습니다: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '“$name”의 크기가 $limit MB를 초과합니다. 더 작은 파일을 선택하세요.';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '“$name”이(가) 비어 있거나 읽을 수 없습니다';
  }

  @override
  String get taskFlowUiTemporary => '임시';

  @override
  String get taskFlowUiTemporaryFileHint => '임시 파일(다음 단계가 성공하면 정리됨)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return '블록 유형 “$name”은(는) 등록되어 있지 않습니다';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$total개 중 $finished개 실행 완료';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return ' · 기록 $count개 삭제됨';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return '입력: $input → 출력: $output';
  }

  @override
  String get taskFlowCardTag => '작업 흐름';

  @override
  String get taskFlowCardQueued => '대기열에 있음(리소스를 기다리는 중)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$total개 중 $done개 완료';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$label $count개';
  }

  @override
  String get taskFlowCardFailedLabel => '실패';

  @override
  String get taskFlowCardSkippedLabel => '건너뜀';

  @override
  String get taskFlowCardCancelledLabel => '취소됨';

  @override
  String get taskFlowCardInterruptedLabel => '중단됨';

  @override
  String get taskFlowCardCancelFlow => '흐름 취소';

  @override
  String get taskFlowCardRetry => '재시도';

  @override
  String get taskFlowCardCancelBatch => '전체 일괄 작업 취소';

  @override
  String get taskFlowCardDelete => '삭제';

  @override
  String get taskFlowCardRetryFlow => '작업 흐름 재시도';

  @override
  String get taskFlowCardNoSnapshot =>
      '이 실행에는 스냅샷이 없습니다. 현재 흐름 설정을 사용해 처음부터 다시 시작합니다.';

  @override
  String get taskFlowCardRetryInfo =>
      '처음부터 다시 시작하면 파일을 다시 다운로드하고 모델을 다시 호출합니다. 시작할 때 사용한 설정으로 재시도하거나 최신 설정을 직접 선택하세요. 완료된 단계를 재사용하려면 “중단된 단계부터 다시 시작”을 선택하세요.';

  @override
  String get taskFlowCardRunLatest => '최신 설정으로 실행';

  @override
  String get taskFlowCardRetryOriginal => '원래 설정으로 재시도';

  @override
  String get taskFlowCardDeleteRecord => '작업 흐름 기록 삭제';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      '이 실행을 삭제하면 일괄 작업의 미완료 작업이 취소되고 하위 작업 기록이 지워집니다. 삭제할까요?';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      '이 흐름은 실행 중입니다. 삭제하면 진행 중인 작업이 취소됩니다. 삭제할까요?';

  @override
  String get taskFlowCardDeleteRecordConfirm => '이 흐름 기록과 하위 작업 기록을 삭제할까요?';

  @override
  String get taskFlowCardDeleteConfirm => '이 흐름 기록을 삭제할까요?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      '흐름 취소 상태를 저장할 수 없습니다. 다시 삭제해 보세요.';

  @override
  String get taskFlowCardStillRunning => '취소한 뒤에도 흐름이 계속 실행 중입니다.';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      '흐름 기록 삭제 상태를 저장할 수 없습니다. 다시 삭제해 보세요.';

  @override
  String get taskFlowCardConfirm => '확인';

  @override
  String get taskFlowCardWaiting => '대기 중';

  @override
  String get taskFlowCardRunning => '실행 중';

  @override
  String get taskFlowCardPaused => '일시 중지됨';

  @override
  String get taskFlowCardCompleted => '완료';

  @override
  String get taskFlowCardFailed => '실패';

  @override
  String get taskFlowCardCanceled => '취소됨';

  @override
  String get taskFlowCardInterrupted => '중단됨';

  @override
  String get taskFlowCardSucceeded => '건너뜀';

  @override
  String get taskFlowCardPause => '흐름 일시 중지';

  @override
  String get taskFlowCardResume => '흐름 재개';

  @override
  String get taskFlowCardResumeInterrupted => '중단된 단계부터 다시 시작';

  @override
  String get taskFlowCardCancel => '취소';

  @override
  String get unifiedTaskType => '작업 유형';

  @override
  String get unifiedTaskCreatedAt => '생성 시간';

  @override
  String get unifiedTaskCompletedAt => '완료 시간';

  @override
  String get unifiedTaskResultStatus => '결과 상태';

  @override
  String get unifiedTaskPartialResult => '부분 결과입니다. 내용이 불완전할 수 있습니다';

  @override
  String get unifiedTaskErrorDetails => '오류 세부 정보';

  @override
  String get unifiedTaskViewErrorDetails => '오류 세부 정보 보기';

  @override
  String get unifiedTaskOcrPerImage => '이미지를 각각 인식';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return '이미지 $index';
  }

  @override
  String get unifiedTaskOcrPending => '인식 대기 중';

  @override
  String get unifiedTaskOcrRunning => '인식 중';

  @override
  String get unifiedTaskCompleted => '완료';

  @override
  String get unifiedTaskIncomplete => '불완전한 결과';

  @override
  String get unifiedTaskOcrFailed => '인식 실패';

  @override
  String get unifiedTaskCancelled => '취소됨';

  @override
  String get unifiedTaskWaitingStart => '시작 대기 중...';

  @override
  String get unifiedTaskSteps => '단계';

  @override
  String get unifiedTaskStartNow => '지금 시작';

  @override
  String get unifiedTaskOpenFile => '파일 열기';

  @override
  String get unifiedTaskRetrySave => '저장만 재시도';

  @override
  String get unifiedTaskRetryPartialSave => '부분 결과 저장만 재시도';

  @override
  String get unifiedTaskSavePartialResult => '부분 결과 저장';

  @override
  String get unifiedTaskRetry => '재시도';

  @override
  String get unifiedTaskCancel => '취소';

  @override
  String get unifiedTaskDelete => '삭제';

  @override
  String get unifiedTaskFormatUnsupported => '이 형식은 미리보기를 지원하지 않습니다';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return '불러오기 실패: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return '재생 실패: $error';
  }

  @override
  String get unifiedTaskAudioFile => '오디오 파일';

  @override
  String get unifiedTaskPreviewLoadFailed => '미리보기를 불러올 수 없습니다';

  @override
  String get unifiedTaskUnknownSize => '크기 알 수 없음';

  @override
  String get unifiedTaskUnnamedRecording => '제목 없는 녹음';

  @override
  String get unifiedTaskPause => '일시 중지';

  @override
  String get unifiedTaskClearTask => '작업 지우기';

  @override
  String get unifiedTaskContinue => '계속';

  @override
  String get unifiedTaskRemoveFromList => '목록에서 제거';

  @override
  String get unifiedTaskSynthesisText => '합성된 텍스트';

  @override
  String get unifiedTaskStatus => '상태';

  @override
  String get unifiedTaskDetails => '세부 정보';

  @override
  String get unifiedTaskSynthesisError => '합성 오류 세부 정보';

  @override
  String get unifiedTaskClose => '닫기';

  @override
  String get unifiedTaskRawRequestResponse => '원시 요청 및 응답';

  @override
  String get unifiedTaskRawRequestBody => '원시 요청 본문:';

  @override
  String get unifiedTaskRawResponseBody => '원시 응답 본문:';

  @override
  String get commonJustNow => '방금 전';

  @override
  String commonMinutesAgo(Object count) {
    return '$count분 전';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count시간 전';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds초';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String get unifiedTaskTypeOcr => '이미지 문자 인식';

  @override
  String get unifiedTaskTypeAsr => '음성 전사';

  @override
  String get unifiedTaskTypeAudioSeparation => '오디오 분리';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return 'OCR: $basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return '오디오 분리: $basename';
  }

  @override
  String get unifiedTaskTypeChat => '어시스턴트 채팅';

  @override
  String get unifiedTaskPlayAudio => '오디오 재생';

  @override
  String get unifiedTaskPauseAudio => '오디오 일시 중지';

  @override
  String get catcatchFlowActionNotStarted =>
      '흐름 작업이 시작되지 않았습니다. 흐름 상태를 확인한 뒤 다시 시도하세요.';

  @override
  String catcatchFlowActionFailed(Object error) {
    return '흐름 작업 실패: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      '페이지 자동 검색 시간이 초과되었습니다. 이 페이지에 로그인하거나 사용자 스크립트를 설정하세요. 미디어가 감지되면 ‘흐름 계속’을 선택하세요.';

  @override
  String get browserRecoveryContinue => '흐름 계속';

  @override
  String get catcatchSkipped => '건너뜀(처리할 항목 없음)';

  @override
  String catCatchDetailMediaResources(Object count) {
    return '미디어 리소스 $count개를 찾았습니다';
  }

  @override
  String catCatchDetailResources(Object count) {
    return '리소스 $count개를 찾았습니다';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return '브라우저에서 리소스 $count개를 찾았습니다';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return '리소스 $total개를 찾았습니다(재생 목록 세그먼트 $segments개)';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return '리소스 $count개를 찾았습니다. 하나를 선택하세요.';
  }

  @override
  String get catCatchDetailAutoSelectFirst => '첫 번째 결과를 자동으로 선택하고 다운로드를 시작했습니다';

  @override
  String get catCatchDetailAutoSelectRemaining => '결과 1개가 남아 자동으로 다운로드를 시작했습니다';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return '.$extension 형식은 변환할 필요가 없어 건너뛰었습니다';
  }

  @override
  String get catCatchDetailSkipNoExtension => '이 형식은 변환할 필요가 없어 변환을 건너뛰었습니다';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return '길이 $duration으로 필터링한 후 결과 $remaining개가 남았습니다(조건에 맞지 않는 리소스 $removed개 제외)';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return '리소스 $count개가 모두 길이 $duration 필터에 맞습니다';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '$count시간';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '$count분';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count초';
  }

  @override
  String get catcatchRetryStep => '이 단계 다시 시도';

  @override
  String catcatchCollapseSegments(Object count) {
    return '세그먼트 $count개 숨기기';
  }

  @override
  String catcatchShowSegments(Object count) {
    return '세그먼트 $count개 표시';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '리소스 $total개 중 $selected개 선택됨';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '미디어 리소스 $count개 감지됨';
  }

  @override
  String get catcatchFlowSelectOrCombine => '(리소스 하나를 선택하거나 오디오와 동영상 쌍을 결합하세요)';

  @override
  String get catcatchSelectMultiple => '(탭하여 선택, 여러 항목 선택 가능)';

  @override
  String get catcatchWaitingForResources => '흐름 리소스 대기 중';

  @override
  String catcatchDownloadSelected(Object count) {
    return '선택한 리소스 $count개 다운로드';
  }

  @override
  String get catcatchSelectResources => '다운로드할 리소스 선택';

  @override
  String get catcatchPossibleSplit => '⚠ 오디오와 동영상 스트림이 분리되어 있을 수 있습니다';

  @override
  String get catcatchSplitExplanation =>
      '이 리소스들은 같은 동영상의 오디오와 동영상 스트림으로 분리되어 있을 수 있습니다. 두 스트림을 결합하거나 하나만 다운로드할 수 있습니다.';

  @override
  String get catcatchAudioStream => '🎵 오디오 스트림';

  @override
  String get catcatchVideoStream => '🎬 동영상 스트림';

  @override
  String get catcatchMergeAudioVideo => '오디오와 동영상 결합';

  @override
  String get catcatchVideoOnly => '동영상만';

  @override
  String get catcatchAudioOnly => '오디오만';

  @override
  String get catcatchSegmentsPlaylistPreview => '재생 목록으로 세그먼트 미리보기';

  @override
  String get catcatchPreviewAudio => '오디오 미리보기';

  @override
  String get catcatchPreviewVideo => '동영상 미리보기';

  @override
  String catcatchDuration(Object duration) {
    return '길이: $duration';
  }

  @override
  String get catcatchSegment => '세그먼트';

  @override
  String get catcatchPlaylist => '재생 목록';

  @override
  String get catcatchFullVideo => '전체 동영상';

  @override
  String get catcatchSeparateTracks => '트랙 분리';

  @override
  String get catcatchPreviewPlaylistOnly => '재생 목록으로 미리보기';

  @override
  String get catcatchPreviewUnsupported => '미리보기를 지원하지 않습니다';

  @override
  String get catcatchUnknownFormat => '알 수 없는 형식';

  @override
  String get catcatchNeedPlaylistProcessing => '재생 목록 처리가 필요합니다';

  @override
  String get catcatchSpecialFormatDetected => '특수 형식이 감지되었습니다';

  @override
  String catcatchPlaylistInfo(Object format) {
    return '이 리소스는 재생 목록($format)입니다. 재생 가능한 동영상으로 만들려면 재생 목록을 분석하고 모든 세그먼트를 다운로드한 뒤 결합해야 합니다.';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return '다운로드한 파일은 표준 MP4가 아니라 $format입니다. 내장된 순수 Dart 리먹서가 MP4로 변환합니다(TS/FLV/EV1은 외부 종속성이 필요하지 않습니다).';
  }

  @override
  String get catcatchContinueBeforeConfirm => '형식 처리 방법을 확인하기 전에 흐름을 재개하세요';

  @override
  String get catcatchAutoProcess => '자동으로 처리';

  @override
  String get catcatchKeepOriginalFormat => '원래 형식 유지';

  @override
  String get catcatchResumeSupported => '이어받기를 지원합니다';

  @override
  String get catcatchResumeUnsupported => '이 사이트는 이어받기를 지원하지 않습니다';

  @override
  String get catcatchPauseDownload => '다운로드 일시 중지';

  @override
  String get catcatchResumeDownload => '다운로드 재개';

  @override
  String get catcatchRestartDownload => '다시 다운로드';

  @override
  String get catcatchPendingFormatAction => '흐름 리소스 대기 중';

  @override
  String get quitDialogTitle => '앱을 종료할까요?';

  @override
  String quitDialogRunningTasks(Object count) {
    return '작업 $count개가 실행 중입니다. 종료하면 작업이 중단됩니다. 종료할까요?';
  }

  @override
  String get quitDialogNoTasks => 'Stroom을 종료할까요?';

  @override
  String get quitDialogCancel => '취소';

  @override
  String get quitDialogExit => '종료';

  @override
  String get searchPanelNewConversation => '새 대화';

  @override
  String get searchPanelTitle => '대화 검색';

  @override
  String get searchPanelHint => '키워드 입력…';

  @override
  String get searchPanelByTitle => '제목으로 검색';

  @override
  String get searchPanelByContent => '내용으로 검색';

  @override
  String searchPanelResults(Object count) {
    return '결과 $count개';
  }

  @override
  String get searchPanelPrompt => '검색할 키워드를 입력하세요';

  @override
  String get searchPanelNoResults => '일치하는 대화가 없습니다';

  @override
  String get topicItemNew => '새 주제';

  @override
  String get topicItemUnpin => '고정 해제';

  @override
  String get topicItemPin => '고정';

  @override
  String get topicItemRename => '이름 변경';

  @override
  String get topicItemAutoName => '자동 이름 지정';

  @override
  String get topicItemDelete => '삭제';

  @override
  String get galleryChoiceTitle => '이미지 소스 선택';

  @override
  String get galleryChoiceDevice => '기기 갤러리';

  @override
  String get galleryChoiceDeviceDescription => '기기에 있는 사진과 동영상 찾아보기';

  @override
  String get galleryChoiceApp => '앱 갤러리';

  @override
  String get galleryChoiceAppDescription => '앱 갤러리에서 선택';

  @override
  String get appMediaUnreadable => '파일을 읽을 수 없습니다';

  @override
  String appMediaLoadError(Object error) {
    return '파일을 불러오지 못했습니다: $error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return '선택 해제($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return '완료($count)';
  }

  @override
  String get appMediaConfirmSelection => '완료';

  @override
  String get appMediaEmptyFolder => '이 폴더는 비어 있습니다';

  @override
  String get appMediaRoot => '루트 폴더로 이동';

  @override
  String appMediaParentFolder(Object name) {
    return '뒤로: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '파일 $count개 선택됨';
  }

  @override
  String get chatAlbumPickerTitle => '앱 앨범';

  @override
  String get chatAlbumPickerEmpty => '사용 가능한 이미지가 없습니다';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 이미지 선택됨',
      one: '$count개 이미지 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => '파일 선택';

  @override
  String get chatFilePickerTabText => '텍스트';

  @override
  String get chatFilePickerTabImages => '이미지';

  @override
  String get chatFilePickerTabVideos => '동영상';

  @override
  String get chatFilePickerTabAudio => '오디오';

  @override
  String get chatFilePickerEmpty => '사용 가능한 파일이 없습니다';

  @override
  String get chatFilePickerLoadFailed => '파일을 불러오지 못했습니다';

  @override
  String get chatVideoPickerTitle => '앱 동영상 선택';

  @override
  String get chatVideoPickerEmpty => '사용 가능한 동영상이 없습니다';

  @override
  String get imagePreviewCrop => '자르기';

  @override
  String get imagePreviewEdit => '편집';

  @override
  String get imagePreviewLoadFailed => '이미지를 불러오지 못했습니다';

  @override
  String runningElapsed(Object elapsed) {
    return '실행 시간: $elapsed';
  }

  @override
  String get chatAttachmentFile => '파일 첨부';

  @override
  String get chatAttachmentCamera => '사진 촬영';

  @override
  String get chatAttachmentDeviceGallery => '기기 갤러리';

  @override
  String get chatAttachmentDeviceFiles => '기기 파일';

  @override
  String get chatAttachmentAppFiles => '앱 파일';

  @override
  String fileManagerTodayTime(Object time) {
    return '오늘 $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return '어제 $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days일 전 $time';
  }

  @override
  String get markdownGenerating => '생성 중…';

  @override
  String get htmlPreview => '미리보기';

  @override
  String get htmlReturnToCard => '카드로 돌아가기';

  @override
  String get htmlGenerating => '생성 중…';

  @override
  String get htmlFullscreen => '전체 화면으로 보기';

  @override
  String get htmlViewCode => '코드 보기';

  @override
  String get codeScrollToBottom => '맨 아래로 스크롤';

  @override
  String get codeSave => '저장';

  @override
  String get codeDisableWrap => '줄 바꿈 끄기';

  @override
  String get codeEnableWrap => '줄 바꿈 켜기';

  @override
  String codeCopyFailed(Object error) {
    return '복사하지 못했습니다: $error';
  }

  @override
  String get codeCopied => '복사됨';

  @override
  String get codeCopy => '복사';

  @override
  String get codeEmptySave => '코드가 비어 있어 저장할 수 없습니다';

  @override
  String get codeSaveTitle => '코드 저장';

  @override
  String codeSavedTo(Object path) {
    return '저장 위치: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get fileManagerCopy => '복사';

  @override
  String get fileManagerMove => '이동';

  @override
  String get fileManagerRename => '이름 변경';

  @override
  String get fileManagerExport => '내보내기';

  @override
  String get fileManagerDelete => '삭제';

  @override
  String get fileManagerAncestorFolders => '상위 폴더';

  @override
  String get fileManagerRoot => '루트';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$count개 선택됨';
  }

  @override
  String get fileManagerSelectAll => '모두 선택';

  @override
  String get fileManagerRenameUndo => '최근 일괄 이름 변경 결과 및 실행 취소';

  @override
  String fileManagerSortBy(Object field) {
    return '정렬($field)';
  }

  @override
  String get fileManagerSortCreated => '만든 날짜순 정렬';

  @override
  String get fileManagerSortModified => '수정한 날짜순 정렬';

  @override
  String get fileManagerSortName => '이름순 정렬';

  @override
  String get fileManagerSortSize => '크기순 정렬';

  @override
  String get fileManagerListView => '목록 보기';

  @override
  String get fileManagerThumbnailView => '썸네일 보기';

  @override
  String get fileManagerCreateFolder => '폴더 만들기';

  @override
  String get fileManagerRefresh => '목록 새로고침';

  @override
  String get fileManagerEmptyFolder => '이 폴더는 비어 있습니다';

  @override
  String get fileManagerNoFiles => '파일 없음';

  @override
  String get fileManagerBackRoot => '루트로 이동';

  @override
  String fileManagerBackFolder(Object name) {
    return '뒤로: $name';
  }

  @override
  String get fileManagerMultiSelect => '여러 항목 선택';

  @override
  String get fileManagerOpen => '열기';

  @override
  String get fileManagerPreview => '미리보기';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '파일 $files개, 하위 폴더 $folders개';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '하위 폴더 $count개';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '파일 $count개';
  }

  @override
  String get fileManagerEmptyFolderLabel => '빈 폴더';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return '파일 “$name.$format”이(가) 이미 있습니다';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return '이름을 변경하지 못했습니다: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => '대상 폴더 선택';

  @override
  String get fileManagerAlreadyAtDestination => '파일이 이미 대상 위치에 있습니다';

  @override
  String get fileManagerMoveNameConflict =>
      '대상 위치에 같은 이름의 파일이 있습니다. 이동을 취소했습니다.';

  @override
  String fileManagerMoveFailed(Object error) {
    return '이동하지 못했습니다: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => '복사할 폴더 선택';

  @override
  String fileManagerCopyFailed(Object error) {
    return '복사하지 못했습니다: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => '삭제 확인';

  @override
  String get fileManagerDeleteFileConfirm => '이 파일을 삭제할까요? 이 작업은 취소할 수 없습니다.';

  @override
  String get fileManagerCancel => '취소';

  @override
  String fileManagerDeleteFailed(Object error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere => '폴더가 이미 대상 위치에 있습니다. 작업을 취소했습니다.';

  @override
  String get fileManagerFolderConflict =>
      '대상 위치에 같은 이름의 폴더가 있거나 대상 폴더가 선택한 폴더 안에 있습니다. 작업을 취소했습니다.';

  @override
  String get fileManagerBatchDeleteTitle => '일괄 삭제 확인';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '선택한 항목 $count개를 삭제할까요? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return '일괄 삭제하지 못했습니다: $error';
  }

  @override
  String get fileManagerExportConflict => '선택한 파일과 폴더의 내보내기 경로가 서로 충돌합니다';

  @override
  String get fileManagerSelectedAlreadyThere =>
      '선택한 파일이 이미 대상 위치에 있습니다. 이동을 취소했습니다.';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return '일괄 이동하지 못했습니다: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      '선택 항목에 이름이 중복된 파일이 있습니다. 복사를 취소했습니다. 한 번에 하나씩 복사하세요.';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return '일괄 복사하지 못했습니다: $error';
  }

  @override
  String get fileManagerClosedError => '파일 페이지가 닫혀 있습니다';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return '일괄 이름 변경에 실패했습니다: $error';
  }

  @override
  String get fileManagerFolderNameHint => '폴더 이름 입력';

  @override
  String get fileManagerCreate => '만들기';

  @override
  String get fileManagerFolderExists => '폴더가 이미 있습니다';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return '폴더를 만들지 못했습니다: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return '폴더 “$name”을(를) 만들었습니다';
  }

  @override
  String get fileManagerRenameFolderTitle => '폴더 이름 변경';

  @override
  String get fileManagerNewNameHint => '새 이름 입력';

  @override
  String get fileManagerTargetFolderConflict =>
      '대상 위치에 같은 이름의 폴더가 이미 있습니다. 작업을 취소했습니다.';

  @override
  String get fileManagerMoveFolderTitle => '폴더 이동…';

  @override
  String get fileManagerCopyFolderTitle => '폴더 복사…';

  @override
  String get fileManagerFolderSelfConflict =>
      '대상 위치에 같은 이름의 폴더가 있거나 대상이 폴더 자체입니다. 작업을 취소했습니다.';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return '폴더 “$name”을(를) 삭제할까요? 안에 있는 파일 $count개도 삭제됩니다.';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '빈 폴더 “$name”을(를) 삭제할까요?';
  }

  @override
  String get fileManagerDeleteFolderTitle => '폴더 삭제 확인';

  @override
  String fileManagerRefreshFailed(Object error) {
    return '새로고침 실패: $error';
  }

  @override
  String get fileManagerRefreshed => '파일 목록을 새로고침했습니다';

  @override
  String get fileManagerRenameFileTitle => '파일 이름 변경';

  @override
  String get fileManagerFormat => '형식';

  @override
  String get fileManagerFolderAtDestination => '폴더가 이미 대상 위치에 있습니다';

  @override
  String get folderPickerTitle => '폴더 선택';

  @override
  String get folderPickerExists => '폴더가 이미 있습니다';

  @override
  String folderPickerCreateFailed(Object error) {
    return '폴더를 만들지 못했습니다: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return '폴더 목록을 새로고침하지 못했습니다: $error';
  }

  @override
  String get folderPickerInstruction => '클릭하여 선택하고 두 번 클릭하여 폴더 열기';

  @override
  String get folderPickerFileName => '파일 이름';

  @override
  String get folderPickerFileNameHint => '파일 이름 입력';

  @override
  String get folderPickerBack => '상위 폴더로 이동';

  @override
  String folderPickerPath(Object path) {
    return '루트 > $path';
  }

  @override
  String get folderPickerRoot => '루트';

  @override
  String get folderPickerCurrentFolder => '현재 폴더';

  @override
  String get folderPickerSubfolders => '하위 폴더';

  @override
  String get folderPickerExistingFolders => '기존 폴더';

  @override
  String get folderPickerCreateNew => '새 폴더 만들기';

  @override
  String get folderPickerFolderNameHint => '폴더 이름 입력';

  @override
  String get folderPickerCancelCreate => '만들기 취소';

  @override
  String get folderPickerCancel => '취소';

  @override
  String get folderPickerConfirm => '완료';

  @override
  String batchRunReadFailed(Object error) {
    return '파일 목록을 읽지 못했습니다: $error';
  }

  @override
  String get batchRunPreparing => '준비 중…';

  @override
  String get batchRunUndo => '실행 취소';

  @override
  String get batchRunRename => '이름 변경';

  @override
  String batchRunFailedAction(Object label) {
    return '$label할 수 없습니다';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label 항목 $count개';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed개 성공, $failed개 실패, $remaining개 남음';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return '실패: $id → $name';
  }

  @override
  String get batchRunReportCopied => '실행 보고서를 복사했습니다';

  @override
  String get batchRunCopyFailed => '복사에 실패했습니다. 다시 시도하세요.';

  @override
  String batchRunWorking(Object label) {
    return '$label 중…';
  }

  @override
  String get batchRunTitle => '일괄 이름 변경 결과';

  @override
  String get batchRunStoppedRetain =>
      '중지해도 완료된 항목은 유지됩니다. 결과 페이지에서 실행을 취소할 수 있습니다.';

  @override
  String get batchRunFailedRemaining => '실패했습니다. 남은 항목은 처리되지 않았습니다.';

  @override
  String get batchRunUndoInfo =>
      '실행 취소하면 이번 작업에서 이름을 바꾼 항목이 원래 이름으로 돌아갑니다. 이후 파일 목록이 변경된 경우에는 실행 취소가 거부됩니다.';

  @override
  String get batchRunUncertain =>
      '일부 항목의 상태를 확인할 수 없습니다. 파일 목록을 확인하세요. 파일을 덮어쓰지 않도록 자동 실행 취소를 사용할 수 없습니다.';

  @override
  String get batchRunUndoing => '원래 이름으로 복원 중…';

  @override
  String get batchRunStopping => '중지 중…';

  @override
  String get batchRunStopRemaining => '남은 항목 중지';

  @override
  String get batchRunCopyReport => '보고서 복사';

  @override
  String batchRunUndoRemaining(Object count) {
    return '남은 $count개 실행 취소 계속하기';
  }

  @override
  String get batchRunUndoCompleted => '완료된 이름 변경 실행 취소';

  @override
  String get batchRunDone => '완료';

  @override
  String get codeEditorTitle => '매개변수 값 편집';

  @override
  String get codeEditorFormat => '서식 지정';

  @override
  String get codeEditorCancel => '취소';

  @override
  String get codeEditorConfirm => '확인';

  @override
  String get codeEditorInvalidJson => 'JSON 형식이 잘못되었습니다. 저장하기 전에 수정하세요.';

  @override
  String get codeEditorParamPath => '매개변수 이름 경로(전송 시 중첩 JSON으로 변환됨)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return '$line행 $column열: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON 형식 오류: $message';
  }

  @override
  String get codeEditorInvalidFormat => '잘못된 JSON 형식';

  @override
  String get toolCallCompacted => '요약됨';

  @override
  String get mermaidSaveEmpty => 'Mermaid 코드가 비어 있어 저장할 내용이 없습니다.';

  @override
  String mermaidFolderLoadFailed(String error) {
    return '폴더를 불러오지 못했습니다: $error';
  }

  @override
  String get mermaidSaveTitle => 'Mermaid 다이어그램 저장';

  @override
  String get mermaidSaveHint => '.mmd 파일을 저장할 폴더를 선택하거나 만드세요';

  @override
  String get mermaidSaveFilenameHint => '파일 이름 입력(.mmd 확장자는 자동으로 추가됨)';

  @override
  String get mermaidFilenameEmpty => '파일 이름을 입력해야 합니다';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return '텍스트 저장소에 저장했습니다: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get mermaidPrepareEngine => '렌더링 엔진 준비 중…';

  @override
  String get mermaidRetry => '다시 시도';

  @override
  String get batchRuleEmpty => '비워 둘 수 없습니다';

  @override
  String get batchRuleNumber => '숫자를 입력하세요';

  @override
  String get batchRulePositive => '0보다 큰 숫자를 입력하세요';

  @override
  String batchRuleMin(String min) {
    return '최소 $min이어야 합니다';
  }

  @override
  String batchRuleMax(String max) {
    return '$max 이하여야 합니다';
  }

  @override
  String get batchRulePrefix => '접두사';

  @override
  String get batchRuleSuffix => '접미사';

  @override
  String get batchRuleStart => '시작값';

  @override
  String get batchRuleStep => '간격';

  @override
  String get batchRuleDigits => '자릿수';

  @override
  String get batchRuleSeparator => '구분자';

  @override
  String get batchRuleRestartFolder => '각 폴더에서 번호 다시 시작';

  @override
  String get batchRuleNumberHelp =>
      '번호는 미리보기 순서대로 매겨집니다. 제외된 항목에는 번호를 사용하지 않습니다. 간격은 음수나 0일 수 있습니다.';

  @override
  String get batchRuleFind => '찾기';

  @override
  String get batchRuleReplace => '바꿀 내용(비워 두면 삭제)';

  @override
  String get batchRuleCaseSensitive => '대소문자 구분';

  @override
  String get batchRuleRegex => '정규식';

  @override
  String get batchRuleFirstOnly => '첫 번째 일치 항목만 바꾸기';

  @override
  String get batchRuleRegexHelp =>
      '캡처 그룹: \$1, \$2; 전체 일치: \$0; 달러 기호 자체: \$\$. 예: ^IMG_(\\d+)\$ → Photo_\$1';

  @override
  String get batchRuleFindRequired => '이 규칙을 사용하려면 찾을 텍스트를 입력하세요.';

  @override
  String get batchRuleBeginning => '시작';

  @override
  String get batchRuleEnd => '끝';

  @override
  String get batchRulePosition => '위치';

  @override
  String get batchRuleInsertText => '삽입할 텍스트';

  @override
  String get batchRuleBeforeChar => 'N번째 문자 앞';

  @override
  String get batchRulePositionHelp =>
      '위치는 1부터 시작하며, 끝을 넘는 위치는 텍스트 끝에 추가됩니다. 결합된 이모지는 한 글자로 계산됩니다.';

  @override
  String get batchRuleFromBeginning => '앞에서부터';

  @override
  String get batchRuleFromEnd => '뒤에서부터';

  @override
  String get batchRuleFromChar => 'N번째 문자부터';

  @override
  String get batchRuleCount => '개수';

  @override
  String get batchRuleDeleteHelp =>
      '삭제 후 이름이 비게 되면 실행 전에 뒤에 오는 삽입 규칙으로 텍스트를 추가해야 합니다.';

  @override
  String get batchRuleUpper => '대문자로';

  @override
  String get batchRuleLower => '소문자로';

  @override
  String get batchRuleFirstUpper => '첫 글자 대문자로';

  @override
  String get batchRuleTitleCase => '각 단어의 첫 글자를 대문자로';

  @override
  String get batchRuleTemplate => '새 이름 템플릿';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return '강의_${n}_$name';
  }

  @override
  String batchRuleTemplateHelp(
    String name,
    String n,
    String folder,
    String created,
    String modified,
    String ext,
  ) {
    return '$name 원래 이름 · $n 순번 · $folder 폴더 이름\n$created 만든 날짜 · $modified 수정한 날짜 · $ext 원래 확장자\n날짜 형식은 YYYY-MM-DD입니다. 날짜가 없으면 알림이 표시됩니다. 템플릿은 기본 이름 전체를 바꾸며 확장자는 자동으로 유지됩니다.';
  }

  @override
  String get batchRuleTrim => '앞뒤 공백 제거';

  @override
  String get batchRuleCollapseSpaces => '연속된 공백을 하나로 바꾸기';

  @override
  String get batchRuleActions => '규칙 작업';

  @override
  String get batchRuleDuplicate => '규칙 복제';

  @override
  String get batchRuleRemove => '규칙 삭제';

  @override
  String get batchRuleMoveUp => '규칙 위로 이동';

  @override
  String get batchRuleMoveDown => '규칙 아래로 이동';

  @override
  String get batchDlgSavePreset => '프리셋 저장';

  @override
  String get batchDlgPresetName => '프리셋 이름';

  @override
  String get batchDlgPresetHint => '규칙과 순서는 저장하지만 제외 항목이나 직접 지정한 이름은 저장하지 않습니다';

  @override
  String get batchDlgCancel => '취소';

  @override
  String get batchDlgSave => '저장';

  @override
  String get batchDlgOverwriteTitle => '기존 프리셋을 덮어쓸까요?';

  @override
  String batchDlgOverwriteBody(String name) {
    return '“$name”의 규칙을 업데이트합니다.';
  }

  @override
  String get batchDlgOverwrite => '덮어쓰기';

  @override
  String get batchDlgManagePresets => '프리셋 관리';

  @override
  String get batchDlgNoPresets => '저장된 프리셋이 없습니다';

  @override
  String get batchDlgDeletePreset => '프리셋 삭제';

  @override
  String get batchDlgDone => '완료';

  @override
  String get batchDlgEditName => '이름을 개별 편집';

  @override
  String get batchDlgBaseName => '기본 이름';

  @override
  String get batchDlgOverrideHelp => '이 이름이 규칙 적용 결과를 대신합니다';

  @override
  String batchDlgExtensionRetained(String extension) {
    return '.$extension 확장자는 자동으로 유지됩니다';
  }

  @override
  String get batchDlgConfirm => '확인';

  @override
  String get batchDlgHelp => '안내';

  @override
  String get batchDlgClose => '닫기';

  @override
  String get batchDlgLoadPreset => '프리셋 불러오기(규칙을 대체하고 직접 지정한 이름 삭제)';

  @override
  String get batchDlgLoad => '프리셋 불러오기';

  @override
  String get batchDlgSaving => '저장 중…';

  @override
  String get batchDlgReset => '모든 규칙과 포함 항목 초기화';

  @override
  String get batchDlgRuleInstructions =>
      '규칙은 위에서 아래 순서로 적용됩니다. 복사, 이동 또는 사용 중지할 수 있습니다. 파일 확장자는 그대로 유지됩니다.';

  @override
  String get batchDlgSortName => '이름';

  @override
  String get batchDlgSortCreated => '만든 날짜';

  @override
  String get batchDlgSortModified => '수정한 날짜';

  @override
  String get batchDlgSortSize => '크기';

  @override
  String get batchDlgAscending => '오름차순';

  @override
  String get batchDlgDescending => '내림차순';

  @override
  String get batchDlgFolderSort => '폴더가 먼저 표시되며 이름이 같으면 폴더별로 정렬됩니다.';

  @override
  String get batchDlgAddRule => '＋ 규칙 추가';

  @override
  String get batchDlgMaxRules => '규칙은 최대 50개까지 설정할 수 있습니다';

  @override
  String get batchDlgPreviewWorking => '미리보기 계산 중… 규칙을 계속 편집하거나 취소할 수 있습니다.';

  @override
  String get batchDlgSearch => '원래 이름, 새 이름 또는 폴더 검색';

  @override
  String get batchDlgFilterAll => '전체';

  @override
  String get batchDlgFilterChanged => '변경됨';

  @override
  String get batchDlgFilterErrors => '문제';

  @override
  String get batchDlgFilterUnchanged => '변경되지 않음';

  @override
  String get batchDlgFilterExcluded => '제외됨';

  @override
  String get batchDlgParticipants => '포함할 항목 선택';

  @override
  String get batchDlgIncludeAll => '모두 포함';

  @override
  String get batchDlgOnlyFiles => '파일만';

  @override
  String get batchDlgOnlyFolders => '폴더만';

  @override
  String get batchDlgExcludeAll => '모두 제외';

  @override
  String get batchDlgScope => '포함 항목';

  @override
  String get batchDlgCopyList => '목록 복사';

  @override
  String get batchDlgConflictBlock => '이름 충돌: 실행 차단';

  @override
  String get batchDlgConflictSuffix => '이름 충돌: (2), (3)… 추가';

  @override
  String get batchDlgNoMatches => '필터와 일치하는 항목이 없습니다';

  @override
  String get batchDlgRoot => '루트';

  @override
  String get batchDlgFile => '파일';

  @override
  String get batchDlgFolder => '폴더';

  @override
  String batchDlgTargetFolder(String folder) {
    return '대상 폴더: $folder';
  }

  @override
  String get batchDlgEditNameTooltip => '이름을 개별 편집';

  @override
  String get batchDlgRestoreNameTooltip => '규칙으로 생성한 이름 복원';

  @override
  String get batchDlgCopied => '전체 미리보기 목록을 복사했습니다(CSV)';

  @override
  String get batchDlgCopyFailed => '복사에 실패했습니다. 다시 시도하세요.';

  @override
  String get batchDlgHelpTitle => '일괄 이름 변경 안내';

  @override
  String get batchDlgHelpDismiss => '알겠습니다';

  @override
  String get batchDlgRulesTab => '규칙';

  @override
  String batchDlgPreviewTab(String count) {
    return '미리보기($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return '항목 $count개 이름 변경';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      '프리셋을 불러오지 못했습니다. 규칙은 계속 편집하고 실행할 수 있습니다.';

  @override
  String get batchDlgPreviewFailed => '미리보기를 계산하지 못했습니다. 규칙을 조정한 뒤 다시 시도하세요.';

  @override
  String batchDlgSavedName(String name) {
    return '프리셋 저장됨: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get batchDlgPresetWriteFailed => '프리셋을 저장하지 못했습니다.';

  @override
  String batchDlgDeleteFailed(String error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String get batchDlgSavePresetFallback => '프리셋 저장';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return '미리보기 · 변경 $changes개 · 문제 $conflicts개 · 제외 $excluded개';
  }

  @override
  String get batchDlgInvalidInput => '잘못된 규칙 입력을 수정하세요. 아직 미리보기에 반영되지 않았습니다.';

  @override
  String get batchDlgConflictError => '충돌 또는 잘못된 이름이 있어 적용할 수 없습니다. 규칙을 조정하세요.';

  @override
  String get batchDlgManualNameStatus => '직접 지정한 이름';

  @override
  String get batchDlgPendingRename => '이름 변경 준비 완료';

  @override
  String get batchDlgCsvHeader => '원래 경로,원래 이름,대상 경로,상태';

  @override
  String get batchDlgHelpBody =>
      '1. 프리셋을 선택하거나 규칙을 켠 다음 규칙을 복사하고 필요에 따라 순서를 조정하세요.\n\n2. 미리보기에는 적용될 이름이 표시됩니다. 검색과 필터는 표시만 바꿉니다. 항목 선택을 해제하면 해당 항목이 제외되고 번호가 다시 계산됩니다. 이름을 개별 편집하거나 규칙 적용 결과를 복원할 수 있습니다.\n\n3. 실행 전에 모든 문제를 해결하세요. 자동 접미사는 파일을 덮어쓰지 않고 중복 이름을 처리합니다. 이름이 서로 바뀌는 폴더는 별도 묶음으로 이름을 변경하세요.\n\n4. 실행 중 나중 항목을 중지할 수 있으며 현재 항목은 먼저 완료됩니다. 결과 페이지에서 완료된 변경 사항을 확인하고 실행을 취소할 수 있습니다. 실행 후 목록이 변경되면 실행 취소가 차단됩니다.\n\n이 작업은 이름과 폴더 경로만 변경하며 파일 내용과 확장자는 그대로 둡니다. 상위 폴더 이름을 변경해도 선택된 하위 항목의 이름은 변경할 수 있으며, 상위 폴더를 이동하면 하위 항목도 함께 이동합니다.';

  @override
  String batchDlgPreviewCount(String count) {
    return '미리보기($count)';
  }

  @override
  String get batchBuiltinPhoto => '사진: 날짜와 번호';

  @override
  String get batchBuiltinCourse => '강의: 이름과 번호 통일';

  @override
  String get batchBuiltinDownloads => '다운로드: 공백 정리';

  @override
  String get taskListDetail => '세부정보';

  @override
  String get taskListOwnershipChecking => '작업 소유권 확인 중';

  @override
  String get taskListOwnershipFailed => '작업 흐름 기록을 읽지 못해 작업을 사용할 수 없습니다';

  @override
  String get taskListViewFlow => '작업 흐름 보기';

  @override
  String get taskListPause => '일시 중지';

  @override
  String get taskListClear => '작업 지우기';

  @override
  String get taskListResume => '재개';

  @override
  String get taskListRetry => '다시 시도';

  @override
  String get taskListDismissError => '오류 닫기';

  @override
  String get taskListRemove => '목록에서 제거';

  @override
  String get taskListSynthesisErrorTitle => '합성 오류 세부정보';

  @override
  String get taskListClose => '닫기';

  @override
  String get taskListOriginalExchange => '원래 요청 및 응답';

  @override
  String get taskListOriginalRequest => '원래 요청 본문:';

  @override
  String get taskListOriginalResponse => '원래 응답 본문:';

  @override
  String get taskFlowIoTypeText => '텍스트';

  @override
  String get taskFlowIoTypeAudio => '오디오';

  @override
  String get taskFlowIoTypeVideo => '동영상';

  @override
  String get taskFlowIoTypeImage => '이미지';

  @override
  String get taskFlowIoTypeLink => '링크';

  @override
  String get taskFlowIoTypeFile => '파일';

  @override
  String get taskFlowIoTypeAny => '모든 유형';

  @override
  String get mermaidZoomOut => '축소';

  @override
  String get mermaidZoomIn => '확대';

  @override
  String get mermaidFullscreen => '전체 화면';

  @override
  String get mermaidSaveButton => '저장';

  @override
  String get mermaidSourceButton => '소스 보기';

  @override
  String get mermaidDiagramSemantic => '다이어그램 보기';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'CatCatch 하위 작업 삭제 상태를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      '합성 하위 작업 삭제 상태를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      '백그라운드 하위 작업 삭제 상태를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get mathParseError => '수식 구문 분석 오류';

  @override
  String get mermaidEmptyPlaceholder => '표시할 Mermaid 코드가 없습니다';

  @override
  String get mathClose => '닫기';

  @override
  String get mermaidLoadTimeout =>
      'Mermaid를 불러오는 시간이 초과되었습니다. 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get mermaidCdnLoadFailed =>
      'Mermaid를 불러오기 위해 cdn.jsdelivr.net에 연결하지 못했습니다.';

  @override
  String get mermaidLoadingDiagram => '다이어그램 불러오는 중…';

  @override
  String get mermaidEngineInitFailed => '다이어그램 렌더러를 초기화하지 못했습니다. 다시 시도하세요.';

  @override
  String get mermaidPageTimeout => '페이지 로드 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get mermaidCodeLoadFailed => '다이어그램 코드를 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String mermaidPageLoadFailed(String description) {
    return '페이지를 불러오지 못했습니다: $description';
  }

  @override
  String get mermaidLoadingEngine => '렌더링 엔진 불러오는 중…';

  @override
  String get mermaidRenderErrorTitle => '다이어그램 렌더링 오류';

  @override
  String get taskFlowOutputVideoAudioDownstream => '동영상 또는 오디오(다음 단계에서 필터링)';

  @override
  String get taskFlowOutputUnknown => '알 수 없음';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label 중지됨: $completed개 성공, $failed개 실패, $remaining개 남음';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Mermaid 렌더링 오류: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Mermaid 초기화 오류: $message';
  }

  @override
  String get mermaidResourceError => 'Mermaid 다이어그램의 리소스를 불러오지 못했습니다.';

  @override
  String get taskFlowParamRecognitionModel => '인식 모델';

  @override
  String get taskFlowParamSynthesisModel => '합성 모델';

  @override
  String get taskFlowParamSaveFolder => '저장 폴더';

  @override
  String get taskFlowParamResourceSelection => '리소스 선택';

  @override
  String get taskFlowParamOutputType => '출력 유형';

  @override
  String get taskFlowParamVideoFolder => '동영상 저장 폴더';

  @override
  String get taskFlowParamAudioFolder => '오디오 저장 폴더';

  @override
  String get taskFlowParamExpectedDuration => '예상 길이';

  @override
  String get taskFlowParamVoice => '음성';

  @override
  String get taskFlowParamSpeechRate => '말하기 속도';

  @override
  String get taskFlowParamAssistant => '어시스턴트';

  @override
  String get taskFlowHintResourceSelection =>
      '수동 모드에서는 직접 선택할 수 있습니다. 자동 모드는 기존 규칙을 따릅니다. 모호할 때 질문 모드는 안전한 선택지가 하나뿐이면 자동으로 선택하고, 그렇지 않으면 확인을 위해 리소스 목록을 엽니다.';

  @override
  String get taskFlowHintOutputType =>
      '동영상 또는 오디오를 명시적으로 선택하세요. 다음 단계 입력 유형에 따라 리소스를 필터링하려면 ‘다음 단계 따르기’를 선택하세요. 다음 단계가 두 유형을 모두 받거나 다음 단계가 없으면 두 유형 모두 유지됩니다.';

  @override
  String get taskFlowHintExpectedDuration =>
      '동영상 길이로 리소스를 필터링합니다. 필터링하지 않으려면 비워 두세요.';

  @override
  String get taskFlowHintVoice => '음성을 선택하세요. 해당 음성과 일치하는 합성 모델이 자동으로 선택됩니다.';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      '이 블록 유형은 더 이상 지원되지 않습니다. 이 단계를 바꾸거나 삭제하세요.';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return '다음 블록에는 $requiredType 유형이 필요합니다. 다운로더는 동영상 또는 오디오를 출력할 수 있습니다. 다음 단계나 출력 정책을 변경하세요.';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source의 유형은 모두이지만 “$block”에는 텍스트, 링크, 이미지, 오디오, 동영상 또는 파일 유형을 명시해야 합니다. 입력 유형을 바꾸거나 블록을 이동 또는 교체하거나 변경을 취소하세요.';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source의 유형은 $actualType이지만 “$block”에는 $requiredType 유형이 필요합니다. 입력 유형을 바꾸거나 블록을 이동 또는 교체하거나 변경을 취소하세요.';
  }

  @override
  String get fileManagerSortFieldCreated => '만든 날짜';

  @override
  String get fileManagerSortFieldModified => '수정한 날짜';

  @override
  String get fileManagerSortFieldName => '이름';

  @override
  String get fileManagerSortFieldSize => '크기';

  @override
  String get fileManagerSortDateNewest => '최신순';

  @override
  String get fileManagerSortDateOldest => '오래된순';

  @override
  String get fileManagerSortSizeLargest => '큰 항목부터';

  @override
  String get fileManagerSortSizeSmallest => '작은 항목부터';

  @override
  String get catcatchStatusRunning => '실행 중';

  @override
  String get catcatchStatusCompleted => '완료';

  @override
  String get catcatchStatusFailed => '실패';

  @override
  String get catcatchStatusPaused => '일시 중지됨';

  @override
  String get catcatchStatusWaiting => '대기 중';

  @override
  String get catcatchStepFetching => '웹페이지 가져오는 중';

  @override
  String get catcatchStepAnalyzing => '미디어 분석 중';

  @override
  String get catcatchStepParsingPlaylist => '재생 목록 분석 중';

  @override
  String get catcatchStepFiltering => '길이로 필터링 중';

  @override
  String get catcatchStepUserSelecting => '선택 대기 중';

  @override
  String get catcatchStepDownloading => '다운로드 중';

  @override
  String get catcatchStepConverting => '변환/결합 중';

  @override
  String get catcatchStepSaving => '기기에 저장 중';

  @override
  String get bgStepConnectServer => '서버에 연결 중';

  @override
  String get bgStepUploadImage => '이미지 업로드 중';

  @override
  String get bgStepWaitRecognition => '인식 대기 중';

  @override
  String get bgStepParseResult => '결과 분석 중';

  @override
  String get bgStepSaveFile => '파일 저장 중';

  @override
  String get bgStepUploadAudio => '오디오 업로드 중';

  @override
  String get bgStepTranscribing => '전사 중';

  @override
  String get bgStepReceiveResult => '결과 수신 중';

  @override
  String get bgStepSeparateAudio => '오디오 분리 중';

  @override
  String get bgStepSaveToFile => '파일로 저장 중';

  @override
  String get bgStepSendRequest => '요청 전송 중';

  @override
  String get bgStepWaitReply => '응답 대기 중';

  @override
  String get fileManagerSortNameAscending => '가나다순';

  @override
  String get fileManagerSortNameDescending => '가나다 역순';

  @override
  String get taskFlowValidationNoSteps => '이 작업 흐름에는 단계가 없습니다. 먼저 블록을 추가하세요.';

  @override
  String get taskFlowValidationInputRequired =>
      '이 작업 흐름을 실행하려면 입력을 하나 이상 추가하세요.';

  @override
  String get taskFlowValidationFlowRemoved => '이 작업 흐름이 삭제되었습니다. 다시 선택하세요.';

  @override
  String get taskFlowValidationInputTypeChanged =>
      '초기 입력 유형이 변경되었습니다. 실행 입력을 다시 선택하세요.';

  @override
  String get taskFlowValidationSnapshotMissing =>
      '이전 기록에 실행 스냅샷이 없습니다. 최신 설정으로 다시 시도하세요.';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      '어시스턴트 모델이 없거나 사용할 수 없습니다. 채팅 페이지에서 모델을 선택하거나 어시스턴트의 기본 모델을 설정하세요.';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      '저장된 단계 파일이 없거나 비어 있거나 읽을 수 없습니다. 작업 흐름을 다시 실행하세요.';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      '이 블록 유형은 더 이상 지원되지 않습니다. 이 단계를 바꾸거나 삭제하세요.';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return '다음 블록에는 $requiredType 유형이 필요합니다. 다운로더는 오디오 또는 동영상을 출력할 수 있습니다. 다음 단계나 출력 정책을 변경하세요.';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '“$block”에 “$parameter” 매개변수가 필요합니다. 블록 설정에서 구성하세요.';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return '이전 모델 선택을 확인해야 합니다. “$block” 설정에서 모델을 다시 선택하세요.';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return '모델이 없거나 제공자에서 사용할 수 없습니다. “$block” 설정에서 모델을 다시 선택하고 제공자 URL과 키를 확인하세요.';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return '어시스턴트가 없거나 삭제되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      '어시스턴트 모델이 삭제되었거나 제공자 설정을 사용할 수 없습니다. 어시스턴트 설정에서 모델을 다시 선택하세요.';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return '리소스 선택 정책 또는 출력 유형이 잘못되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return '출력 유형이 잘못되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return '리소스 선택 정책이 잘못되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return '입력 $index: 파일이 없거나 비어 있거나 읽을 수 없습니다. 다시 선택하세요.';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return '입력 $index: 올바른 HTTP 또는 HTTPS 링크를 입력하세요.';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return '입력 $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules => '규칙은 최대 50개까지 설정할 수 있습니다.';

  @override
  String get batchRuleValidationDigits => '자릿수는 1~12여야 합니다.';

  @override
  String get batchRuleValidationNumberRange =>
      '시작 번호와 간격은 ±999,999,999 범위여야 합니다.';

  @override
  String get batchRuleValidationReplacementLength => '바꿀 내용이 너무 깁니다.';

  @override
  String get batchRuleValidationRegex => '정규식이 잘못되었습니다.';

  @override
  String get batchRuleValidationDeleteIndex => '삭제 위치는 1부터 시작해야 합니다.';

  @override
  String get batchRuleValidationInsertLength => '삽입할 텍스트가 너무 깁니다.';

  @override
  String get batchRuleValidationTemplateNumber =>
      '템플릿 번호 설정이 잘못되었습니다. 자릿수는 1~12여야 하며 시작값과 간격은 ±999,999,999 범위여야 합니다.';

  @override
  String get batchRuleValidationTemplateLength => '템플릿이 너무 깁니다.';

  @override
  String get batchRuleValidationTemplateVariable =>
      '알 수 없는 템플릿 변수이거나 닫는 중괄호가 없습니다.';

  @override
  String get batchRuleTypeNumber => '번호 추가';

  @override
  String get batchRuleTypeReplace => '찾아 바꾸기';

  @override
  String get batchRuleTypeInsert => '텍스트 삽입';

  @override
  String get batchRuleTypeDelete => '문자 삭제';

  @override
  String get batchRuleTypeCase => '대소문자 변경';

  @override
  String get batchRuleTypeTemplate => '이름 템플릿';

  @override
  String get batchRuleTypeCleanup => '공백 정리';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return '입력 $index: 텍스트를 입력하거나 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return '입력 $index: 이미지가 20MB를 초과합니다. 더 작은 이미지를 선택하세요.';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return '입력 $index: 첨부 파일이 10MB를 초과합니다. 더 작은 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return '입력 $index: 파일 유형은 $actualType이지만 $requiredType 유형이 필요합니다. 다른 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return '입력 $index: 어시스턴트 채팅은 SVG 이미지 첨부를 지원하지 않습니다. PNG 또는 JPEG로 변환하세요.';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return '입력 $index: 어시스턴트 채팅은 $mime 이미지 첨부를 지원하지 않습니다. PNG, JPEG, GIF 또는 WebP로 변환하세요.';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return '입력 $index: 어시스턴트 채팅은 $mime 오디오 첨부를 지원하지 않습니다. MP3, WAV 또는 M4A로 변환하세요.';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return '입력 $index: 이 Anthropic 채팅 형식은 $type 첨부를 지원하지 않습니다. 해당 미디어를 지원하는 어시스턴트를 선택하세요.';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return '입력 $index: 이 Anthropic 채팅 형식은 이미지와 PDF 첨부만 지원합니다. 지원되는 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return '입력 $index: 어시스턴트 채팅에서 이미지를 10MB 미만으로 압축하지 못했습니다. 더 작은 이미지를 선택하세요.';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return '입력 $index: 텍스트 첨부가 올바른 UTF-8 형식이 아닙니다. 변환한 뒤 다시 시도하세요.';
  }

  @override
  String get assistantParamValueTypeString => '문자열';

  @override
  String get assistantParamValueTypeNumber => '숫자';

  @override
  String get assistantParamValueTypeBoolean => '불리언';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields => '제공자 이름, API URL, API 키를 입력해야 합니다.';

  @override
  String get providerJsonSizePositive => '요청 JSON 크기는 0보다 큰 MiB 값이어야 합니다.';

  @override
  String get providerCustomParamRequired => '사용자 지정 매개변수 이름과 값을 입력하세요.';

  @override
  String providerParamNameInvalid(String name) {
    return '매개변수 이름이 잘못되었습니다(점으로 구분한 항목은 비어 있을 수 없음): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return '이미 있는 매개변수입니다: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return '매개변수 “$name”의 기본값이 올바른 JSON이 아닙니다: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return '매개변수 “$name”의 숫자 옵션을 입력하세요.';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return '매개변수 “$name”의 값이 올바른 숫자가 아닙니다: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      '다른 추론 매개변수를 활성화하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String providerReasoningError(String error) {
    return '추론 매개변수 오류: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return '추론 매개변수와 사용자 지정 매개변수의 이름이 같습니다: $name';
  }

  @override
  String get providerMaxTokensMissing => '최대 출력 토큰이 켜져 있지만 값이 입력되지 않았습니다.';

  @override
  String get providerMaxTokensPositive => '최대 출력 토큰은 양의 정수여야 합니다.';

  @override
  String get providerSeedInteger => '난수 시드는 정수여야 합니다.';

  @override
  String get providerNotConfigured => '설정되지 않음';

  @override
  String get providerAudioChunkingTitle => '오디오 분할';

  @override
  String get providerAudioChunkingHint =>
      '스마트 분할은 오디오와 분할 후보 지점을 분석하고 문장 끝을 우선합니다. 분할 구간은 서로 겹치지 않습니다.';

  @override
  String get providerChunkingMode => '분할 방식';

  @override
  String get providerChunkNone => '분할 안 함';

  @override
  String get providerChunkSmart => '스마트 분할(권장)';

  @override
  String get providerChunkFixedDuration => '고정 길이로 분할';

  @override
  String get providerChunkFixedSize => '고정 크기로 분할';

  @override
  String get providerCompressionTitle => '압축 인코딩';

  @override
  String get providerCompressionHint =>
      '이 옵션을 켜면 일반 대체 처리에서 먼저 WAV 전체를 압축합니다. 인코딩된 파일이나 요청 본문이 여전히 한도를 초과하면 원본 PCM을 여러 구간으로 나누어 인코딩합니다.';

  @override
  String get providerCompressionMode => '압축 방식';

  @override
  String get providerCompressionNone => '없음(그대로 전송)';

  @override
  String get providerCompressionAdpcm => 'ADPCM(약 4배 압축)';

  @override
  String get providerCompressionFlac => 'FLAC(무손실, 약 2배 압축, 권장)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM 손실 압축(4:1)입니다. 순수 Dart로 구현했으며 음질은 전사에 적합합니다.';

  @override
  String get providerCompressionFlacDescription =>
      '순수 Dart로 구현한 무손실 FLAC 압축입니다. 크기를 약 절반으로 줄입니다.';

  @override
  String get providerCompressionWavDescription => '압축하지 않고 WAV 파일로 전송합니다.';

  @override
  String get providerLlmParams => 'LLM 매개변수';

  @override
  String get providerEnabledParamsHelp => '활성화한 매개변수는 API 요청의 기본값으로 전송됩니다.';

  @override
  String get providerTemperatureLabel => '온도';

  @override
  String get providerTemperatureHelp =>
      '출력의 무작위성을 조절합니다. 값이 높을수록 더 창의적인 결과가 나옵니다.';

  @override
  String get providerTopPHelp => '단어 선택에 사용할 누적 확률을 조절하는 뉴클리어스 샘플링 매개변수입니다.';

  @override
  String get providerFrequencyPenaltyLabel => '빈도 페널티';

  @override
  String get providerFrequencyPenaltyHelp => '반복되는 단어를 줄입니다. 음수 값은 반복을 늘립니다.';

  @override
  String get providerPresencePenaltyLabel => '존재 페널티';

  @override
  String get providerPresencePenaltyHelp =>
      '새로운 주제를 유도합니다. 음수 값은 이전 주제로 돌아가도록 유도합니다.';

  @override
  String get providerMaxOutputTokensLabel => '최대 출력 토큰';

  @override
  String providerOptionalExample(String example) {
    return '선택 사항(예: $example)';
  }

  @override
  String get providerResponseTokensHelp => '응답 하나에서 생성할 최대 토큰 수입니다.';

  @override
  String get providerSeedLabel => '난수 시드';

  @override
  String get providerSeedHelp => '같은 결과를 재현하려면 값을 설정하세요.';

  @override
  String get providerChunkSmartDescription =>
      '오디오와 분할 후보 지점을 분석해 문장 끝이나 긴 무음 구간을 우선하며 구간이 겹치지 않도록 합니다. 기본값: 최소 20초 / 목표 45초 / 최대 60초. 일반 대체 처리에서만 사용하며 압축 분할은 PCM WAV만 지원합니다.';

  @override
  String get providerChunkDurationDescription =>
      'N초마다 분할합니다(기본값 60초). 간단하지만 음성이 잘릴 수 있습니다. 일반 대체 처리에서만 사용하며 압축 분할은 PCM WAV만 지원합니다.';

  @override
  String get providerChunkSizeDescription =>
      '먼저 오디오 데이터 크기로 분할한 다음 인코딩된 파일과 요청 본문 크기에 맞게 조정합니다. 일반 대체 처리에서만 사용하며 압축 분할은 PCM WAV만 지원합니다.';

  @override
  String get providerChunkNoneDescription =>
      '분할하지 않습니다. 전체 압축 후에도 파일이 한도를 초과하면 거부됩니다.';

  @override
  String get providerNameLabel => '제공자 이름';

  @override
  String get providerNameHint => '제공자 이름 입력';

  @override
  String get providerApiUrlLabel => 'API URL';

  @override
  String get providerApiUrlHint => '전체 API 엔드포인트 URL 입력';

  @override
  String providerApiKeyHint(String hint) {
    return '힌트: $hint';
  }

  @override
  String get providerEndpointTypeLabel => '엔드포인트 유형';

  @override
  String get providerEndpointOpenAi => 'OpenAI 호환(Chat Completions)';

  @override
  String get providerEndpointAnthropic => 'Anthropic 형식(Messages API)';

  @override
  String get providerAnthropicEndpointHelp =>
      '공식 Anthropic Messages API 형식을 사용합니다(x-api-key 헤더). API URL 예시: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      '공식 OpenAI Chat Completions 호환 형식을 사용합니다(Bearer 헤더). API URL 예시: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => '기본 요청 JSON 크기';

  @override
  String get providerUseAppDefault => '앱 기본값을 사용하려면 비워 두세요';

  @override
  String get providerModelJsonBudgetHelp =>
      '모델에서 이 값을 재정의할 수 있습니다. 제공자와 모델 모두 값을 설정하지 않으면 기본값은 20MiB입니다.';

  @override
  String get providerRequestParamsHelp =>
      '요청에는 활성화된 제공자 및 모델 매개변수가 모두 사용됩니다. 이름이 겹치면 모델 값이 우선합니다.';

  @override
  String get providerUploadSettings => '업로드 설정';

  @override
  String get providerUploadMethodHelp => '오디오 업로드 방식과 크기 제한은 제공자마다 다릅니다.';

  @override
  String get providerUploadMethod => '업로드 방식';

  @override
  String get providerMultipart => '멀티파트(일반)';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => '최대 업로드 크기';

  @override
  String get providerFallbackStrategy => '대체 전략';

  @override
  String get providerFallbackMethod => '대체 방식';

  @override
  String get providerPreprocessing => '오디오 전처리';

  @override
  String get providerPreprocessingHelp =>
      '전사 정확도에 영향을 거의 주지 않으면서 오디오 파일 크기를 줄입니다.';

  @override
  String get providerPreprocessingMethod => '전처리 방식';

  @override
  String get providerUploadMultipartHelp =>
      'multipart/form-data로 직접 업로드합니다. 요청 본문에는 오디오, 폼 필드, 멀티파트 경계가 포함됩니다.';

  @override
  String get providerUploadBase64Help =>
      '일부 제공자의 멀티파트 전용 제한을 피할 수 있도록 JSON에 Base64로 담아 전송합니다. Base64 인코딩으로 늘어난 크기와 JSON 필드도 업로드 한도에 포함됩니다.';

  @override
  String get providerUploadUrlHelp =>
      '제공자가 다운로드할 수 있는 공개 URL을 입력하세요. 매우 큰 파일도 지원합니다(예: Together AI 1GB).';

  @override
  String get providerUploadBudgetHelp =>
      '이 값은 원본 오디오 대체 처리를 시작하는 기준이자 최종 요청 본문의 크기 제한입니다. 앱은 원본 오디오, 인코딩된 파일, 업로드 크기를 확인합니다. 멀티파트에는 폼 필드와 경계가 포함되고 Base64 JSON에는 인코딩으로 늘어난 크기와 필드가 포함됩니다. 기본값 25MB는 OpenAI 오디오 API의 한도와 같습니다.';

  @override
  String get providerFallbackTriggerHelp =>
      '원본 오디오나 전체 요청 본문이 한도를 초과하면 실행됩니다. 구체적인 대체 방식(Base64)이 일반 대체 방식(압축/분할)보다 우선합니다.';

  @override
  String get providerFallbackNone => '없음(즉시 거부)';

  @override
  String get providerFallbackSpecific => '구체적인 대체 방식(Base64)';

  @override
  String get providerFallbackGeneric => '일반 대체 방식(압축/분할)';

  @override
  String get providerFallbackAll => '모두 시도(권장)';

  @override
  String get providerFallbackSpecificHelp =>
      'Base64 JSON을 시도합니다. Base64 인코딩으로 늘어난 크기와 JSON 필드를 포함한 요청 본문이 한도 이내일 때만 전송합니다.';

  @override
  String get providerFallbackGenericHelp =>
      '켜져 있으면 먼저 WAV 전체를 압축합니다. 그래도 한도를 초과하고 분할이 켜져 있으면 원본 PCM을 나누어 각 구간을 인코딩합니다. PCM WAV만 지원합니다.';

  @override
  String get providerFallbackAllHelp =>
      '먼저 요청 본문 한도 내에서 Base64를 시도합니다. 그다음 켜져 있으면 WAV 전체를 압축합니다. 그래도 한도를 초과하고 분할이 켜져 있으면 원본 PCM을 나누어 각 구간을 인코딩합니다. PCM WAV만 지원합니다.';

  @override
  String get providerFallbackRejectHelp => '파일이 한도를 초과하면 대체 처리를 시도하지 않고 거부합니다.';

  @override
  String get providerPreprocessNone => '없음';

  @override
  String get providerPreprocessResample => 'WAV 최적화(16kHz 모노, 권장)';

  @override
  String get providerPreprocessResampleHelp =>
      '16kHz로 리샘플링하고 모노로 믹스합니다. 전사 정확도에 미치는 영향은 적으면서 크기를 약 4~6배 줄입니다.';

  @override
  String get providerPreprocessNoneHelp => '전처리 없이 원본 그대로 전송합니다.';

  @override
  String get assistantDefaultsScopeHelp =>
      '기본 모델과 도구는 이 어시스턴트에서 새로 만드는 대화에만 적용됩니다. 기존 대화는 기존 설정을 유지합니다. 도구 출력 자르기는 이 어시스턴트의 모든 대화에 적용됩니다.';

  @override
  String get assistantDefaultModelTitle => '기본 모델';

  @override
  String get assistantDefaultModelHelp =>
      '새 대화에서 사용할 모델입니다. 대화에서 직접 선택하게 하려면 설정하지 마세요.';

  @override
  String get assistantNoDefault => '설정되지 않음';

  @override
  String get assistantNoModelsAvailable =>
      '사용할 수 있는 모델이 없습니다. 설정에서 LLM 제공자를 구성하세요.';

  @override
  String get assistantDefaultToolsTitle => '기본 활성화 도구';

  @override
  String get assistantDisabledToolsHelp => '사용 중지한 도구는 새 대화에서 자동으로 켜지지 않습니다.';

  @override
  String get assistantUnconfiguredToolsHelp =>
      '기본 도구가 설정되지 않았습니다. 새 대화에서는 모든 도구가 자동으로 활성화됩니다.';

  @override
  String get assistantEnableAll => '모두 활성화';

  @override
  String get assistantDisableAll => '모두 사용 중지';

  @override
  String get assistantNoToolsAvailable => '사용할 수 있는 도구가 없습니다';

  @override
  String get assistantTruncateToolOutput => '도구 출력 자르기';

  @override
  String get assistantTruncateToolOutputHelp =>
      '모델에 보내기 전에 각 도구 결과에서 허용할 최대 문자 수입니다. 이 어시스턴트의 모든 대화에 적용됩니다.';

  @override
  String get assistantEnableTruncation => '출력 자르기 사용';

  @override
  String assistantTruncatedTo(String count) {
    return '긴 결과는 $count자로 줄입니다';
  }

  @override
  String get assistantSendFullResult => '전체 결과 전송(저장 한도 50KB 적용)';

  @override
  String get assistantMaxCharacters => '최대 문자 수';

  @override
  String get assistantCharactersNotTokens => '단위: 문자(토큰 아님)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return '기본값: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return '허용 범위: $minimum~$maximum자';
  }

  @override
  String get assistantNewConversationPreview => '새 대화 미리보기';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled/$total개 활성화';
  }

  @override
  String get assistantAllToolsAutoEnabled => '설정되지 않아 모든 도구가 자동으로 활성화됩니다';

  @override
  String get assistantMoreActions => '추가 작업';

  @override
  String get assistantChooseEmoji => '이모지 선택';

  @override
  String get assistantNameLabel => '어시스턴트 이름';

  @override
  String get assistantDescriptionOptional => '설명(선택 사항)';

  @override
  String get assistantSelectionTitle => '어시스턴트 선택';

  @override
  String get assistantMarketTooltip => '어시스턴트 마켓플레이스';

  @override
  String get assistantDefaultPrompt =>
      '당신은 유용한 AI 어시스턴트입니다. 사용자의 질문에 명확하고 친절하게 답변하세요.';

  @override
  String get assistantCreateNew => '어시스턴트 만들기';

  @override
  String get assistantEmptyState => '아직 어시스턴트가 없습니다. 새 어시스턴트를 만들어 시작하세요.';

  @override
  String get assistantCreate => '만들기';

  @override
  String get assistantReorderHint => '길게 누른 다음 드래그하여 어시스턴트 순서 변경';

  @override
  String get assistantNewNameHint => '어시스턴트 이름 입력';

  @override
  String get assistantNewDescriptionHint => '어시스턴트의 기능을 간단히 설명하세요';

  @override
  String get assistantDeleteTitle => '어시스턴트 삭제';

  @override
  String assistantDeleteConfirmation(String name) {
    return '어시스턴트 “$name”을(를) 삭제할까요? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get assistantEditTitle => '어시스턴트 편집';

  @override
  String get assistantBasicTab => '기본 설정';

  @override
  String get assistantParametersTab => '매개변수';

  @override
  String get assistantDefaultsTab => '기본값';

  @override
  String get assistantAddCustomParameter => '사용자 지정 매개변수 추가';

  @override
  String get assistantEditCustomParameter => '사용자 지정 매개변수 편집';

  @override
  String get assistantParameterName => '매개변수 이름';

  @override
  String get assistantParameterNameHint => '예: top_k 또는 provider.only';

  @override
  String get assistantParameterNameInvalid =>
      '매개변수 이름이 잘못되었습니다(점으로 구분한 항목은 비어 있을 수 없음)';

  @override
  String get assistantParameterType => '유형';

  @override
  String get assistantValue => '값';

  @override
  String get assistantTrueFalseHint => 'true 또는 false';

  @override
  String get assistantNumberHint => '숫자를 입력하세요';

  @override
  String assistantJsonHint(String example) {
    return '예: $example';
  }

  @override
  String get assistantValueHint => '값 입력';

  @override
  String get assistantCancel => '취소';

  @override
  String get assistantSave => '저장';

  @override
  String get assistantParamOverrideHelp =>
      '켜면 어시스턴트 매개변수가 모델 매개변수보다 우선하며, 끄면 모델 매개변수를 사용합니다.';

  @override
  String get assistantTemperature => '온도';

  @override
  String get assistantMaxTokens => '최대 토큰 수';

  @override
  String get assistantMaxToolCalls => '최대 도구 호출 수';

  @override
  String assistantRounds(String count) {
    return '$count회';
  }

  @override
  String get assistantUnlimited => '무제한';

  @override
  String get assistantStreamOutput => '스트리밍 출력';

  @override
  String get assistantFrequencyPenalty => '빈도 페널티';

  @override
  String get assistantPresencePenalty => '존재 페널티';

  @override
  String get assistantRandomSeed => '난수 시드';

  @override
  String get assistantNotSet => '설정되지 않음';

  @override
  String get assistantSeedValue => '시드 값';

  @override
  String get assistantIntegerSeedHint => '정수 시드를 입력하세요';

  @override
  String get assistantWebSearch => '웹 검색';

  @override
  String get assistantAddParameter => '매개변수 추가';

  @override
  String get assistantNoCustomParameters => '사용자 지정 매개변수가 없습니다';

  @override
  String get assistantRoundsLabel => '라운드 수';

  @override
  String get modelCreateTitle => '모델 추가';

  @override
  String get modelEditTitle => '모델 편집';

  @override
  String get modelDiscardTitle => '변경사항을 버릴까요?';

  @override
  String get modelDiscardBody => '저장하지 않은 변경사항이 있습니다. 버릴까요?';

  @override
  String get modelNameLabel => '모델 이름';

  @override
  String get modelNameHint => '표시 이름 입력(선택 사항)';

  @override
  String get modelIdLabel => '모델 ID';

  @override
  String modelIdExample(String id) {
    return '예: $id';
  }

  @override
  String get modelIdRequired => '모델 ID를 입력해야 합니다.';

  @override
  String get modelCustomParamRequired => '사용자 지정 매개변수 이름과 기본값을 입력해야 합니다.';

  @override
  String modelParamDuplicate(String name) {
    return '이미 있는 매개변수입니다: $name';
  }

  @override
  String modelParamReserved(String name) {
    return '예약된 OCR 매개변수 이름입니다: $name';
  }

  @override
  String get modelParamName => '매개변수 이름';

  @override
  String get modelParamDefaultValue => '매개변수 기본값';

  @override
  String get modelParamDelete => '매개변수 삭제';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return '매개변수 “$name”의 기본값이 올바른 JSON이 아닙니다: $value';
  }

  @override
  String get modelAddParameter => '매개변수 추가';

  @override
  String get modelNoCustomParams => '사용자 지정 매개변수가 없습니다';

  @override
  String get modelBasicSettings => '기본 설정';

  @override
  String get modelDiscardCancel => '취소';

  @override
  String get modelSave => '저장';

  @override
  String get modelUnsavedMaxTokens => '최대 출력 토큰이 켜져 있지만 값이 입력되지 않았습니다.';

  @override
  String get modelMaxTokensPositive => '최대 출력 토큰은 양의 정수여야 합니다.';

  @override
  String get modelSeedInteger => '난수 시드는 정수여야 합니다.';

  @override
  String get modelContextLengthRequired => '컨텍스트 길이를 입력해야 합니다.';

  @override
  String get modelContextLengthPositive => '컨텍스트 길이는 양의 정수여야 합니다.';

  @override
  String get modelAsrLanguageCode => '언어 코드(언어)';

  @override
  String get modelAsrLanguageHint => '예: zh, en, ja';

  @override
  String get modelAsrLanguageHelp => 'ISO-639-1 언어 코드입니다. 자동 감지를 사용하려면 비워 두세요.';

  @override
  String get modelTemperature => '온도';

  @override
  String get modelTemperatureHelp => '출력의 무작위성을 조절합니다. 낮은 값을 권장합니다.';

  @override
  String get modelAsrPrompt => '프롬프트';

  @override
  String get modelAsrPromptHint => '문맥 프롬프트 입력(선택 사항)';

  @override
  String get modelAsrPromptHelp => '전문 용어 목록과 같은 문맥을 제공하면 전사 정확도를 높일 수 있습니다.';

  @override
  String get modelAsrParams => 'ASR 매개변수';

  @override
  String get modelEnabledParamsHelp => '활성화한 매개변수는 API 요청의 기본값으로 전송됩니다.';

  @override
  String get modelAsrResponseFormat => '응답 형식';

  @override
  String get modelAsrResponseHelp => '반환되는 전사의 형식입니다.';

  @override
  String get modelAsrTimestampGranularity => '타임스탬프 단위';

  @override
  String get modelAsrVerboseHelp =>
      'response_format이 verbose_json일 때만 사용할 수 있습니다.';

  @override
  String get modelNoTrim => '자르지 않음';

  @override
  String get modelAudioTrimTitle => '오디오 자르기';

  @override
  String get modelAudioTrimHelp => '오디오를 자르는 방법을 선택하세요.';

  @override
  String get modelDeleteTrimPreset => '자르기 프리셋 삭제';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return '자르기 프리셋 “$name”을(를) 삭제할까요?';
  }

  @override
  String get modelAddTrimPreset => '사용자 지정 자르기 추가';

  @override
  String get modelPlayTestAudio => '테스트 오디오 재생';

  @override
  String get modelPlayingTestAudio => '재생 중…';

  @override
  String get modelParamExists => '매개변수가 이미 있습니다';

  @override
  String get asrModelIdExample => '예: whisper-1';

  @override
  String get asrPromptLabel => '프롬프트';

  @override
  String get asrResponseFormatJson => 'json – JSON';

  @override
  String get asrResponseFormatText => 'text – 일반 텍스트';

  @override
  String get asrResponseFormatSrt => 'srt – 자막';

  @override
  String get asrResponseFormatVtt => 'vtt – 자막';

  @override
  String get asrResponseFormatVerbose => 'verbose_json – 상세 JSON(타임스탬프 포함)';

  @override
  String get asrVerboseTimestampHelp =>
      'verbose_json을 선택하면 아래의 타임스탬프 단위 옵션을 사용할 수 있습니다.';

  @override
  String get asrTimestampSegment => 'segment – 세그먼트 단위';

  @override
  String get asrTimestampWord => 'word – 단어 단위';

  @override
  String get asrWordTimestampHelp => '단어 단위 타임스탬프는 세그먼트 단위보다 정확도가 낮을 수 있습니다.';

  @override
  String get reasoningAddOptionValue => '옵션 값 추가';

  @override
  String get reasoningEditOptionValue => '옵션 값 편집';

  @override
  String get reasoningOptionExample => '예: low, medium, high';

  @override
  String get reasoningOptionSelectionHelp =>
      '칩을 탭하여 값을 선택하거나 선택 해제하세요. 선택한 값이 전송되며 드래그하여 순서를 바꿀 수 있습니다. 제공자 값은 삭제할 수 없지만 선택을 해제해 숨길 수 있습니다.';

  @override
  String get reasoningAddOption => '옵션 추가';

  @override
  String get reasoningCurrentProvider => '현재: 제공자';

  @override
  String get reasoningCurrentModel => '현재: 모델 사용자 지정 값';

  @override
  String get reasoningAddEffortValue => '추론 강도 값 추가';

  @override
  String get reasoningEffortExample => '예: max, ultra, deep';

  @override
  String get reasoningAddToggle => '추론 전환 추가';

  @override
  String get reasoningToggle => '추론 전환';

  @override
  String get reasoningResetParameter => '이 매개변수 초기화';

  @override
  String get reasoningDisableToggle => '추론 전환 사용 중지';

  @override
  String get reasoningEnableToggle => '추론 전환 활성화';

  @override
  String reasoningParameterNameSource(String source) {
    return '매개변수 이름($source)';
  }

  @override
  String get reasoningNameExample => '예: thinking.type, reasoning';

  @override
  String get reasoningBooleanHelp =>
      '불리언 매개변수에는 값이 필요하지 않으며, 채팅 패널에서 켜기/끄기 스위치를 제공합니다.';

  @override
  String get reasoningOnValue => '활성화 시 값';

  @override
  String get reasoningOnExample => '예: enabled, true';

  @override
  String get reasoningOffValue => '비활성화 시 값';

  @override
  String get reasoningOffExample => '예: disabled, false';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return '활성화하면 ‘$onValue’를 전송하고, 비활성화하면 ‘$offValue’를 전송합니다.';
  }

  @override
  String get reasoningAddEffort => '추론 수준 추가';

  @override
  String get reasoningFillToggleFirst => '먼저 추론 전환 설정을 완료하세요';

  @override
  String get reasoningFillToggleBeforeEffort =>
      '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get reasoningAddValue => '값 추가';

  @override
  String get reasoningJsonValue => 'JSON 값';

  @override
  String reasoningJsonExample(String example) {
    return '예: $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      '칩을 탭해 선택하거나 선택 해제하세요. 선택한 값은 채팅 추론 패널에 표시되며 드래그해 순서를 바꿀 수 있습니다. 제공업체 값은 삭제할 수 없지만 숨길 수 있습니다.';

  @override
  String get reasoningAddParameter => '추론 매개변수 추가';

  @override
  String get reasoningToggleIncomplete => '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get llmContextLength => '컨텍스트 길이';

  @override
  String get llmContextHint => '컨텍스트 길이 입력';

  @override
  String get llmContextHelp => '모델의 최대 컨텍스트 창 크기(토큰)입니다.';

  @override
  String get llmReasoningParams => '추론 매개변수';

  @override
  String get llmReasoningHelp =>
      '채팅의 추론 매개변수를 설정합니다. 추론 전환은 매개변수 이름과 켜기/끄기 값을 제어합니다. 추론 수준 값을 추가하고 순서를 바꾼 다음 채팅 패널에 표시할 값을 선택하세요. 이 페이지를 열 때 제공업체 값이 동기화됩니다. 이 설정은 모델 매개변수 사용 가능 여부를 제어하며, 채팅 패널 전환은 별도로 관리됩니다.';

  @override
  String get llmAddReasoningParam => '추론 매개변수 추가';

  @override
  String get llmCustomEndpointType => '사용자 지정 엔드포인트 유형';

  @override
  String get llmInheritEndpointType => '비활성화하면 제공업체 설정의 엔드포인트 유형을 사용합니다.';

  @override
  String get llmEndpointType => '엔드포인트 유형';

  @override
  String get llmEndpointOpenAi => 'OpenAI 호환(Chat Completions)';

  @override
  String get llmEndpointAnthropic => 'Anthropic 형식(Messages API)';

  @override
  String get llmEndpointHelp =>
      '엔드포인트 유형은 제공업체 API URL과 일치해야 합니다. 유형을 변경하면 이 모델로 새 대화를 만들 때 사용하는 형식이 달라집니다.';

  @override
  String get llmTopPHelp => '누클리어스 샘플링 매개변수로, 단어 선택에 사용할 누적 확률을 제어합니다.';

  @override
  String get llmFrequencyPenaltyLabel => '빈도 페널티';

  @override
  String get llmFrequencyPenaltyHelp => '반복을 줄입니다. 음수 값은 반복을 늘립니다.';

  @override
  String get llmPresencePenaltyLabel => '존재 페널티';

  @override
  String get llmPresencePenaltyHelp => '새로운 주제를 유도합니다. 음수 값은 반복을 유도합니다.';

  @override
  String get llmMaxTokensHint => '선택 사항, 예: 4096';

  @override
  String get llmTokensPerResponse => '응답당 생성할 최대 토큰 수입니다.';

  @override
  String get llmSeedLabel => '랜덤 시드(Seed)';

  @override
  String get llmSeedHint => '선택 사항, 예: 42';

  @override
  String get llmSeedHelp => '이 값을 설정하면 출력을 재현할 수 있습니다.';

  @override
  String get llmInheritedCustomHelp =>
      '제공업체의 사용자 지정 매개변수가 여기에 표시되며, 이 페이지를 열 때마다 동기화됩니다.';

  @override
  String get llmBooleanParamHelp => '불리언 매개변수에는 값이 필요하지 않습니다.';

  @override
  String get modelContextReq => '컨텍스트 길이는 필수입니다.';

  @override
  String get modelContextPositive => '컨텍스트 길이는 양의 정수여야 합니다.';

  @override
  String modelParamNameInvalid(String name) {
    return '매개변수 이름이 올바르지 않습니다(점으로 구분된 각 부분은 비어 있을 수 없음): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return '매개변수 ‘$name’의 $valueLabel은(는) 유한한 숫자여야 합니다: $value';
  }

  @override
  String get modelReasoningIncomplete =>
      '다른 추론 매개변수를 활성화하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get modelReasoningOptionsRequired => '추론 매개변수에 옵션 값을 하나 이상 추가하세요.';

  @override
  String modelReasoningError(String error) {
    return '추론 매개변수 오류: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return '중복된 추론 매개변수: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return '추론 매개변수와 사용자 지정 매개변수 이름이 중복됩니다: $name';
  }

  @override
  String get modelSeedRequired => '랜덤 시드가 활성화되었지만 값이 비어 있습니다.';

  @override
  String get ocrParamsTitle => 'OCR 매개변수';

  @override
  String get ocrParamsHelp =>
      'OpenAI 호환 Vision Chat Completions 형식을 사용합니다. 아래 매개변수는 선택 사항이며, 설정하지 않았거나 비활성화한 매개변수는 전송되지 않습니다. API에서 지원하는 제공업체별 매개변수는 아래에 추가하세요.';

  @override
  String get ocrRequestSizeOverride => '요청 JSON 크기 재정의';

  @override
  String get ocrInheritProvider => '비워 두면 제공업체 설정을 따릅니다';

  @override
  String get ocrBudgetDefault =>
      '비워 두면 제공업체 설정을 따릅니다. 제공업체에 값이 없으면 기본값 20 MiB를 사용합니다.';

  @override
  String ocrBudgetValue(String size) {
    return '비워 두면 제공업체 설정($size MiB)을 따릅니다. 제공업체에 값이 없으면 기본값 20 MiB를 사용합니다.';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return '오디오 $direction $seconds초 자르기';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return '처음 $seconds초 자르기';
  }

  @override
  String get audioTrimNone => '오디오를 자르지 않음';

  @override
  String get trimNameLabel => '자르기 방식 이름 *';

  @override
  String get trimNameHint => '예: 무음 구간 자르기';

  @override
  String get trimDurationLabel => '자르기 길이(초) *';

  @override
  String get trimDurationHint => '예: 0.123';

  @override
  String get trimNameAndDurationRequired => '이름과 길이를 입력해야 합니다.';

  @override
  String get trimDurationInvalid => '올바른 양의 길이를 입력하세요.';

  @override
  String get testAudioHostMissing => '호스트가 설정되지 않았습니다.';

  @override
  String get testAudioKeyMissing => '키가 설정되지 않았습니다.';

  @override
  String testAudioContentTypeError(String contentType) {
    return '응답 Content-Type이 $contentType이며, 오디오 형식이 아닙니다.';
  }

  @override
  String get testAudioEmpty => '서버가 빈 오디오 데이터를 반환했습니다.';

  @override
  String testAudioTimeoutConnection(String details) {
    return '연결 시간이 초과되었습니다. 네트워크를 확인하세요. $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return '응답 수신 시간이 초과되었습니다. 서버 응답이 너무 느립니다. $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return '요청이 취소되었습니다. $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return '네트워크 오류: $message';
  }

  @override
  String get testAudioNoBody => '응답 본문이 없습니다';

  @override
  String testAudioCorsHelp(String details) {
    return '서버에 연결할 수 없습니다. 웹에서는 CORS 또는 잘못된 API URL이 원인일 수 있습니다. 제공업체 API URL과 서버의 교차 출처 요청 허용 여부를 확인하세요. $details';
  }

  @override
  String get trimModelNameHint =>
      '표시와 식별에 사용할 알아보기 쉬운 이름입니다(예: ‘GPT-4o Mini TTS’). 같은 제공업체의 모델을 구분하려면 서로 다른 이름을 사용하세요.';

  @override
  String get trimModelIdHelp =>
      'API 호출에 사용하는 고유 식별자입니다(예: ‘gpt-4o-mini-tts’). 공급업체가 제공한 모델 ID와 일치해야 합니다.';

  @override
  String get ttsVoiceRangeTitle => '음량 범위';

  @override
  String get ttsMinVolume => '최소 음량';

  @override
  String get ttsMaxVolume => '최대 음량';

  @override
  String get ttsSpeedRangeTitle => '속도 범위';

  @override
  String get ttsMinSpeed => '최저 속도';

  @override
  String get ttsMaxSpeed => '최고 속도';

  @override
  String get ttsMaxAudioLength => '요청당 최대 오디오 길이 *';

  @override
  String get ttsAudioLengthHint => '예: 1000';

  @override
  String get ttsNoVoices => '음성이 없습니다. 탭하여 편집하세요.';

  @override
  String get ttsInstructionSupported => '모델이 지시문 매개변수를 지원합니다';

  @override
  String get ttsInstructionHelp =>
      '활성화하면 TTS 요청에 어조, 감정, 말하기 속도 등에 관한 지시문을 포함할 수 있습니다.';

  @override
  String get ttsStreamSupported => '모델이 스트리밍 출력을 지원합니다';

  @override
  String get ttsStreamHelp =>
      '스트리밍 시나리오에서 이 모델을 사용할 수 있습니다. 활성화하기 전에 모델의 스트리밍 지원 여부를 확인하세요.';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return '매개변수 ‘$name’은(는) true 또는 false여야 합니다: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired => '요청당 최대 오디오 길이는 필수입니다. 양의 정수를 입력하세요.';

  @override
  String get asrLanguageExample => '예: zh, en, ja';

  @override
  String get llmReasoningFullHelp =>
      '추론 전환은 추론 전송 여부를 제어하고 매개변수 이름과 켜기/끄기 값을 설정합니다. 추론 수준 매개변수는 하나만 사용할 수 있습니다. 값을 선택하고 드래그해 순서를 바꾸세요. 선택한 값은 채팅 추론 패널에 표시됩니다. 다른 추론 매개변수는 아래에 추가하세요. thinking.type처럼 점 표기법을 사용하는 매개변수 이름은 중첩된 JSON 객체가 됩니다. 이 페이지를 열 때 제공업체의 추론 매개변수가 동기화됩니다. 여기의 스위치는 모델 매개변수를 제어하며 채팅 추론 전환과는 별개입니다.';

  @override
  String get llmTemperatureHelp => '출력의 무작위성을 제어합니다. 값이 높을수록 더 창의적인 결과가 나옵니다.';

  @override
  String get llmBooleanValueHelp => '불리언 매개변수에는 값이 필요하지 않습니다.';

  @override
  String get reasoningDisableEffort => '추론 수준 비활성화';

  @override
  String get reasoningEnableEffort => '추론 수준 활성화';

  @override
  String get ocrJsonSizePositive => '요청 JSON 크기는 양의 MiB 값이어야 합니다.';

  @override
  String ttsRangePair(String kind) {
    return '최솟값과 최댓값 $kind을(를) 모두 입력하거나 둘 다 비워 두세요.';
  }

  @override
  String get ttsEditTrimTitle => '사용자 지정 자르기 편집';

  @override
  String ttsVoicesCount(String count) {
    return '음성($count개)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return '요청 형식으로 생성됨: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'MCP 서버 이름을 입력하세요.';

  @override
  String get mcpStdioCommandRequired => 'stdio 모드에는 명령이 필요합니다.';

  @override
  String get mcpSseUrlRequired => 'SSE 모드에는 URL이 필요합니다.';

  @override
  String get mcpEditServerTitle => 'MCP 서버 편집';

  @override
  String get mcpCreateServerTitle => '새 MCP 서버';

  @override
  String get mcpUnsavedChangesTitle => '저장하지 않은 변경사항';

  @override
  String get mcpUnsavedChangesConfirm => '저장하지 않은 변경사항이 있습니다. 버리시겠습니까?';

  @override
  String get mcpTransportType => '전송 유형';

  @override
  String get mcpServerName => '서버 이름';

  @override
  String get mcpServerNameHint => 'MCP 서버 이름 입력';

  @override
  String get mcpCommand => '명령';

  @override
  String get mcpCommandExample => '예: npx';

  @override
  String get mcpArguments => '인수';

  @override
  String get mcpArgumentsHint =>
      '인수를 쉼표로 구분하세요. 예: -y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => '예: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'API 키';

  @override
  String get mcpApiKeyHint => 'API 키 입력(선택 사항)';

  @override
  String get mcpShowKey => '키 표시';

  @override
  String get mcpHideKey => '키 숨기기';

  @override
  String get mcpDescriptionHint => '이 MCP 서버에 대한 설명 입력(선택 사항)';

  @override
  String get mcpStdioDescription =>
      'stdio는 로컬 자식 프로세스를 MCP 서버로 실행하고 표준 입력/출력으로 통신합니다. 로컬 도구에 권장됩니다.';

  @override
  String get mcpSseDescription =>
      'SSE는 HTTP SSE를 통해 원격 MCP 서버에 연결합니다. 원격 서비스에 권장됩니다.';

  @override
  String get mcpLocalStdio => '로컬(stdio)';

  @override
  String get mcpRemoteSse => '원격(SSE)';

  @override
  String get mcpSaving => '저장 중…';

  @override
  String get providerTestSafetyNote =>
      '이 테스트는 선택한 서비스에 실제 요청을 보냅니다. MCP는 읽기 전용 tools/list 메서드만 호출하고, HTTP와 웹 검색은 한 번씩 검색합니다. Todo는 기본적으로 목록을 읽습니다. 기존 데이터를 보호하려면 todos 매개변수를 생략하거나 null로 설정하세요.';

  @override
  String get providerDeleteConfigTitle => '구성 삭제';

  @override
  String get providerDeleteConfigConfirm => '이 제공업체 구성과 모든 모델을 삭제하시겠습니까?';

  @override
  String get providerCreateGroup => '새 그룹';

  @override
  String get providerEditGroup => '그룹 편집';

  @override
  String get providerGroupName => '그룹 이름';

  @override
  String get providerGroupNameExists => '이 이름을 사용하는 그룹이 이미 있습니다.';

  @override
  String get providerDeleteGroup => '그룹 삭제';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return '‘$groupName’을(를) 삭제하면 해당 구성이 ‘기타 MCP 서비스’로 이동합니다.';
  }

  @override
  String get providerMoveToGroup => '그룹으로 이동';

  @override
  String get providerUnnamed => '(이름 없음)';

  @override
  String get providerHttpSearch => 'HTTP 검색';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP 도구: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return '로컬(stdio): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return '원격(SSE): $url';
  }

  @override
  String get providerServices => '서비스 구성';

  @override
  String get providerServicesDescription =>
      '그룹별로 원격 연결, 로컬 stdio, HTTP 검색을 관리합니다.';

  @override
  String get providerCreateGroupAction => '새 그룹';

  @override
  String get providerGroupEmpty => '이 그룹에 구성이 없습니다. ‘추가’를 선택해 항목을 추가하세요.';

  @override
  String get providerBuiltinTools => '기본 제공 도구';

  @override
  String get providerBuiltinToolsDescription =>
      'Stroom이 제공하는 로컬 도구 인터페이스입니다. 웹 검색은 해당 서비스 그룹에 표시됩니다.';

  @override
  String get providerBuiltinToolInterface => '기본 제공 도구 인터페이스';

  @override
  String get providerViewInterface => '인터페이스 보기';

  @override
  String get providerConfigTitle => '구성';

  @override
  String get providerNotFound => '제공업체를 찾을 수 없습니다.';

  @override
  String get providerConfigurationHeading => '제공업체 구성';

  @override
  String get providerBuiltinWebSearchEmpty =>
      '기본 제공 웹 검색은 Google, Bing, Baidu를 지원합니다. 모델 도구 이름은 web_search입니다.';

  @override
  String get providerNoConfigsAdd => '아직 제공업체 구성이 없습니다. ‘추가’를 선택해 만드세요.';

  @override
  String get providerNoHost => '(호스트 설정 안 됨)';

  @override
  String get providerServicesAndTools => '서비스 및 도구';

  @override
  String get providerManageServicesDescription =>
      'MCP 서버, HTTP 검색, Stroom 기본 제공 도구를 관리합니다.';

  @override
  String get providerNoServices => '아직 서비스 구성이 없습니다.';

  @override
  String get providerAddServiceDescription =>
      'MCP 서비스 또는 HTTP 검색 인터페이스를 추가해 어시스턴트에서 사용하세요.';

  @override
  String get providerAddService => '서비스 추가';

  @override
  String get providerBuiltinBadge => '기본 제공';

  @override
  String get providerBuiltinTtsName => 'TTS 제공업체';

  @override
  String get providerBuiltinLlmName => 'LLM 제공업체';

  @override
  String get providerBuiltinOcrName => 'OCR 제공업체';

  @override
  String get providerBuiltinAsrName => '음성 인식 제공업체';

  @override
  String get providerBuiltinMcpName => 'MCP 제공업체';

  @override
  String get providerBuiltinSearchGroupName => '검색';

  @override
  String get providerBuiltinMcpServicesGroupName => '기타 MCP 서비스';

  @override
  String get providerConnectivityTest => '연결 테스트';

  @override
  String get providerMoveGroupTooltip => '그룹으로 이동';

  @override
  String get providerDeleteTooltip => '구성 삭제';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '항목 #개',
      one: '항목 #개',
      zero: '항목 없음',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => '그룹 작업';

  @override
  String get providerEditGroupAction => '그룹 편집';

  @override
  String get providerDeleteGroupAction => '그룹 삭제';

  @override
  String get providerAddItem => '항목 추가';

  @override
  String get providerMcpMasterLabel => 'MCP 서버';

  @override
  String get providerMcpMasterDescription =>
      'MCP 서버와 기본 제공 검색 도구를 어시스턴트 및 채팅에서 사용할 수 있는지 제어합니다.';

  @override
  String get providerEnabled => '사용';

  @override
  String get providerDisabled => '사용 안 함';

  @override
  String get providerEditSettings => '제공업체 설정 편집';

  @override
  String get providerModelList => '모델';

  @override
  String get providerNoModels => '아직 모델이 없습니다.';

  @override
  String get providerDeleteModel => '모델 삭제';

  @override
  String get providerDeleteModelConfirm => '이 모델을 삭제하시겠습니까?';

  @override
  String get providerEditConfig => '구성 편집';

  @override
  String providerCreateNamedConfig(String entryName) {
    return '새 $entryName 구성';
  }

  @override
  String get toolHttpSearchType => '연결 유형: HTTP 검색';

  @override
  String toolInterface(String name) {
    return '도구 인터페이스: $name';
  }

  @override
  String get toolParameterDefinitions => '매개변수 정의';

  @override
  String get toolHttpAddress => 'HTTP 엔드포인트 URL';

  @override
  String get toolInvalidHttpUrl => '올바른 HTTP 또는 HTTPS URL을 입력하세요.';

  @override
  String get toolBuiltinType => '연결 유형: Stroom 기본 제공 도구';

  @override
  String get toolBuiltinEnableHelp =>
      '어시스턴트의 기본 도구 설정에서 이 도구를 사용할 수 있도록 설정합니다.';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return '모델 ID: $modelId';
  }

  @override
  String get providerValueNotSet => '(설정되지 않음)';

  @override
  String get providerApiKeyInputHint => 'API 키 입력';

  @override
  String get providerSettingsTitle => '제공업체 구성';

  @override
  String get providerBasicInfoTab => '기본 정보';

  @override
  String get providerParameterSettingsTab => '매개변수 설정';

  @override
  String get providerOptionValuesReorderHelp => '옵션 값(손잡이를 길게 눌러 드래그하고 순서 변경)';

  @override
  String providerOptionIndexLabel(String index) {
    return '옵션 $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return '예: $example';
  }

  @override
  String get providerDeleteOptionTooltip => '옵션 삭제';

  @override
  String get providerAddOption => '옵션 추가';

  @override
  String get providerAddCustomParam => '매개변수 추가';

  @override
  String get providerNoCustomParams => '아직 사용자 지정 매개변수가 없습니다.';

  @override
  String get providerParamNameLabel => '매개변수 이름';

  @override
  String get providerParamDefaultValueLabel => '매개변수 기본값';

  @override
  String get providerBooleanParamNoValue =>
      '불리언 매개변수에는 값이 필요하지 않습니다. 채팅 패널에서 켜기/끄기를 전환할 수 있습니다.';

  @override
  String get providerReasoningParamsHeading => '추론 매개변수';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return '추론 전환을 사용해 채팅에서 추론을 켜거나 끕니다. 매개변수 이름과 켜기/끄기 값을 지정할 수 있습니다. 이름이 필수이고 선택 값은 선택 사항인 추론 수준 매개변수를 하나 설정할 수 있습니다. 이름만 입력하면 모델 구성에서 값을 제공할 수 있습니다. 아래 버튼으로 다른 추론 매개변수를 추가하세요. 매개변수 이름은 점 표기 중첩을 지원합니다. 예를 들어 $parameterName은(는) $jsonExample(으)로 확장됩니다.';
  }

  @override
  String get providerAddReasoningParam => '추론 매개변수 추가';

  @override
  String get providerAddReasoningToggle => '추론 전환 추가';

  @override
  String get providerReasoningToggle => '추론 전환';

  @override
  String get providerDeleteReasoningToggle => '추론 전환 삭제';

  @override
  String providerParamNameHint(String examples) {
    return '예: $examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      '불리언 매개변수에는 값이 필요하지 않습니다. 채팅 패널에서 켜기/끄기를 전환할 수 있습니다.';

  @override
  String get providerToggleOnValueLabel => '켜기 값';

  @override
  String get providerToggleOffValueLabel => '끄기 값';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return '추론이 켜져 있으면 ‘$onValue’를 보내고, 꺼져 있으면 ‘$offValue’를 보냅니다.';
  }

  @override
  String get providerAddReasoningEffort => '추론 수준 추가';

  @override
  String get providerDeleteReasoningEffort => '추론 수준 매개변수 삭제';

  @override
  String get providerReasoningEffortLockedHint =>
      '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get providerJsonValueLabel => 'JSON 값';

  @override
  String get providerReasoningOptionsHelp =>
      '옵션 값(선택 사항; 매개변수 이름만 입력하면 모델 구성이 값을 제공합니다). 손잡이를 길게 눌러 드래그하고 순서를 변경하세요.';

  @override
  String get providerParamNameNestedLabel => '매개변수 이름(점 표기 중첩 지원)';

  @override
  String get providerToggleEffortPrerequisite =>
      '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get providerToggleRequiredHint => '먼저 추론 전환 설정을 완료하세요.';

  @override
  String get providerDeleteCustomParam => '매개변수 삭제';

  @override
  String get modelSaveSuccess => '모델 저장됨';

  @override
  String get modelSaving => '저장 중…';

  @override
  String modelOriginalError(String error) {
    return '원래 오류: $error';
  }

  @override
  String get paramTypeStringLabel => '문자열';

  @override
  String get paramTypeNumberLabel => '숫자';

  @override
  String get paramTypeBooleanLabel => '불리언';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return '지원하지 않는 유형: $type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return '매개변수 ‘$name’은(는) 지원하지 않는 유형 ‘$type’을(를) 사용합니다. 저장하기 전에 지원되는 유형으로 바꾸거나 매개변수를 삭제하세요.';
  }

  @override
  String get paramTypeStringHint => '예: cheerful';

  @override
  String get paramTypeNumberHint => '예: 0.8';

  @override
  String get paramTypeBooleanHint => '예: true';

  @override
  String get paramTypeJsonHint => '예: ';

  @override
  String get ankiPageTitle => 'Anki 플래시카드';

  @override
  String get ankiStatsTooltip => '학습 통계';

  @override
  String get ankiBrowseCardsTooltip => '카드 둘러보기';

  @override
  String get ankiStatsTotalCards => '전체 카드';

  @override
  String get ankiStatsNewCards => '새 카드';

  @override
  String get ankiStatsLearning => '학습 중';

  @override
  String get ankiStatsDueForReview => '복습 예정';

  @override
  String get ankiStatsReviewHistory => '복습 기록';

  @override
  String get ankiStatsLearningProgress => '학습 진행 상황';

  @override
  String get ankiStatsReviewRate => '복습률';

  @override
  String get ankiBrowserSearchHint => '카드 검색...';

  @override
  String get ankiBrowserEmpty => '카드가 없습니다';

  @override
  String get ankiSyncTooltip => 'AnkiWeb 동기화';

  @override
  String get ankiNewDeckTooltip => '새 덱';

  @override
  String ankiDeckLoadError(String error) {
    return '덱을 불러오지 못했습니다: $error';
  }

  @override
  String get ankiEmptyDecksTitle => '아직 덱이 없습니다';

  @override
  String get ankiEmptyDecksDescription => '덱을 만들어 학습을 시작하세요';

  @override
  String get ankiNewDeckTitle => '새 덱';

  @override
  String get ankiDeckNameHint => '덱 이름';

  @override
  String get ankiCreateDeck => '만들기';

  @override
  String get ankiRenameDeck => '덱 이름 변경';

  @override
  String get ankiConfirm => '확인';

  @override
  String get ankiDeleteDeckTitle => '덱 삭제';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '‘$deckName’과(와) 그 안의 모든 카드를 삭제하시겠습니까?';
  }

  @override
  String get ankiAddCardTitle => '카드 추가';

  @override
  String get ankiNoteTypeLabel => '노트 유형';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return '텍스트($clozeSyntax로 삭제할 부분 표시)';
  }

  @override
  String get ankiFrontQuestionHint => '앞면(질문)';

  @override
  String get ankiBackExtraLabel => '뒷면 / 추가 정보';

  @override
  String get ankiTagsLabel => '태그(공백으로 구분)';

  @override
  String get ankiTagsHint => '예: 수학 물리';

  @override
  String get ankiAdd => '추가';

  @override
  String get ankiStatNew => '새 카드';

  @override
  String get ankiStatLearning => '학습 중';

  @override
  String get ankiStatReview => '복습';

  @override
  String get ankiAddCardAction => '카드 추가';

  @override
  String get ankiRenameAction => '이름 변경';

  @override
  String get ankiDeleteAction => '삭제';

  @override
  String get ankiNoCardContent => '카드 내용이 없습니다';

  @override
  String get ankiStudy => '학습';

  @override
  String get ankiWhiteboardTooltip => '화이트보드';

  @override
  String get ankiFrontLabel => '앞면';

  @override
  String get ankiBackLabel => '뒷면';

  @override
  String get ankiShowAnswer => '정답 보기';

  @override
  String get ankiRatingAgain => '다시';

  @override
  String get ankiRatingHard => '어려움';

  @override
  String get ankiRatingGood => '알맞음';

  @override
  String get ankiRatingEasy => '쉬움';

  @override
  String get ankiNoCardsToStudy => '지금 학습할 카드가 없습니다';

  @override
  String get ankiNoCardsHint => '새 카드를 추가하거나 나중에 다시 확인하세요';

  @override
  String get ankiBack => '뒤로';

  @override
  String get ankiSyncPageTitle => 'Anki 동기화';

  @override
  String get ankiSyncChooseMode => '동기화 모드 선택';

  @override
  String get ankiSyncModeHelp =>
      '로그인 상태는 서비스별로 따로 저장됩니다. 모드를 전환해도 데이터가 병합되거나 덮어써지지 않습니다.';

  @override
  String get ankiSyncSelfHostedMode => '자체 호스팅 서버';

  @override
  String get ankiSyncServerAddress => '서버 주소';

  @override
  String get ankiSyncServerHelp =>
      '원격 자체 호스팅 서버에는 HTTPS를 사용해야 합니다. 로컬 주소에는 HTTP를 사용할 수 있습니다. 서버는 Anki 동기화 v10을 지원해야 하며, 인증서 검증은 기본적으로 활성화되어 있습니다.';

  @override
  String get ankiSyncCustomCaTitle => '사용자 지정 CA 인증서(선택 사항)';

  @override
  String get ankiSyncCustomCaHelp => '서버가 자체 서명 인증서를 사용하는 경우에만 입력하세요.';

  @override
  String get ankiSyncOfficialHelp =>
      '공식 AnkiWeb 동기화 서비스를 사용합니다. 비밀번호는 로그인할 때만 전송되며 Stroom에 저장되지 않습니다.';

  @override
  String ankiSyncConnected(String service) {
    return '$service에 연결됨';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return '$service에 연결되지 않음';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return '$service에 로그인';
  }

  @override
  String get ankiSyncCheckServerStatus => '서버 상태 확인';

  @override
  String get ankiSyncLogout => '로그아웃';

  @override
  String get ankiSyncBothWays => '양방향 동기화';

  @override
  String get ankiSyncOverwriteServer => '서버 데이터를 로컬 데이터로 교체';

  @override
  String get ankiSyncReplaceLocal => '로컬 데이터를 서버 데이터로 교체';

  @override
  String get ankiSyncHelp =>
      '양방향 동기화는 컬렉션의 변경사항을 병합하고 미디어 파일을 전송합니다. 스키마 버전이 다르면 전체 업로드 또는 다운로드를 선택하세요. 전체 다운로드에 실패하면 기존 컬렉션과 미디어 디렉터리 복원을 시도합니다.';

  @override
  String get ankiSyncStatusRestored => '안전하게 저장된 로그인 세션을 복원했습니다';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      '저장된 로그인 세션을 읽을 수 없습니다. 다시 로그인하세요.';

  @override
  String get ankiSyncInvalidServerUrl =>
      '서버 주소는 HTTPS URL이어야 합니다. 로컬 루프백 주소에만 HTTP를 사용할 수 있습니다. 사용자 정보와 쿼리 매개변수는 허용되지 않습니다.';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return '설정을 저장하지 못했습니다: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      '서버 주소가 변경되었습니다. 계속하려면 다시 로그인하세요.';

  @override
  String get ankiSyncStatusVerifyingLogin => '로그인 확인 중…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      '로그인했습니다. 비밀번호는 저장되지 않았으며 동기화 키는 암호화해 저장했습니다.';

  @override
  String get ankiSyncLoginSuccessPromptTitle => '로그인 성공';

  @override
  String get ankiSyncLoginSuccessPromptMessage => '지금 컬렉션을 동기화하시겠습니까?';

  @override
  String get ankiSyncLoginSuccessPromptSync => '지금 동기화';

  @override
  String get ankiSyncLoginSuccessPromptLater => '계속';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      '로그인했지만 동기화 키를 안전하게 저장하지 못했습니다. 이 페이지를 닫은 후 다시 로그인해야 합니다.';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return '로그인 실패: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'AnkiWeb에 로그인';

  @override
  String get ankiSyncLoginSelfHosted => '자체 호스팅 서버에 로그인';

  @override
  String get ankiSyncEmailOrUsername => '이메일 / 사용자 이름';

  @override
  String get ankiSyncEmailOrUsernameRequired => '이메일 또는 사용자 이름을 입력하세요';

  @override
  String get ankiSyncPassword => '비밀번호';

  @override
  String get ankiSyncPasswordRequired => '비밀번호를 입력하세요';

  @override
  String get ankiSyncLogin => '로그인';

  @override
  String get ankiSyncStatusPreparingServerSettings => '서버 설정 준비 중…';

  @override
  String get ankiSyncStatusReadingCollection => '서버 컬렉션 상태 읽는 중…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      '연결되었습니다. 서버 컬렉션이 비어 있습니다.';

  @override
  String get ankiSyncStatusConnectedStatusRead => '연결되었습니다. 서버 상태를 읽었습니다.';

  @override
  String get ankiSyncStatusUpgradeClient => '이 서버에는 최신 동기화 클라이언트가 필요합니다.';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return '상태 확인 실패: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => '업로드 설정 준비 중…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle => '서버 컬렉션을 로컬 컬렉션으로 바꾸시겠습니까?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      '서버 컬렉션을 로컬 데이터로 완전히 교체합니다. 먼저 로컬 데이터베이스를 백업합니다.\n\n서버의 미디어 목록에 따라 미디어 파일은 계속 양방향으로 동기화됩니다.';

  @override
  String get ankiSyncOverwriteServerAction => '서버 컬렉션 교체';

  @override
  String get ankiSyncStatusBackingUpUploading => '컬렉션 백업 및 업로드 중…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return '서버가 로컬 컬렉션을 수락했습니다. 미디어 동기화 완료: 파일 $uploaded개 업로드, $downloaded개 다운로드, $deleted개 삭제.$backup 서버 상태를 다시 확인하세요.';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return '\n로컬 백업: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      '서버 컬렉션을 교체했지만 미디어 동기화를 완료하지 못했습니다: ';

  @override
  String get ankiSyncStatusUploadFailed => '업로드 실패: ';

  @override
  String get ankiSyncStatusPreparingDownload => '다운로드 설정 준비 중…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle => '로컬 컬렉션을 서버 컬렉션으로 바꾸시겠습니까?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      '로컬 컬렉션을 서버 데이터로 교체합니다. 먼저 로컬 데이터베이스를 백업합니다.\n\n서버 미디어가 로컬 미디어를 대체하고, 없는 파일은 다운로드됩니다. 어느 단계에서든 실패하거나 앱이 중간에 종료되면 다음에 덱을 열기 전에 Stroom이 로컬 컬렉션과 미디어를 복원합니다.';

  @override
  String get ankiSyncReplaceLocalAction => '로컬 데이터 교체';

  @override
  String get ankiSyncStatusDownloadingValidating => '컬렉션 다운로드 및 검증 중…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return '로컬 컬렉션을 교체했고 SQLite 검사를 통과했습니다. 미디어 동기화 완료: 파일 $downloaded개 다운로드, $uploaded개 업로드, $deleted개 삭제.$backup 서버 상태를 다시 확인하세요.';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return '다운로드 실패: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => '동기화 준비 중…';

  @override
  String get ankiSyncStatusMergingChanges => '컬렉션 변경사항 병합 중…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      '컬렉션 변경사항을 병합했습니다. 미디어 파일 동기화 중…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '노트 $notes개, 카드 $cards개, 복습 기록 $reviews개를 추가하거나 업데이트했습니다';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges => '병합할 컬렉션 변경사항이 없습니다';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return '양방향 동기화 완료: $collection; 미디어 $uploaded개 업로드, $downloaded개 다운로드, $deleted개 삭제.';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      '컬렉션 변경사항은 병합했지만 미디어 동기화를 완료하지 못했습니다: ';

  @override
  String get ankiSyncStatusSyncIncomplete => '동기화를 완료하지 못했습니다: ';

  @override
  String get ankiSyncStatusClearingLogin => '로그인 세션 삭제 중…';

  @override
  String get ankiSyncStatusLoggedOut => '로그아웃했습니다. 보안 저장소에서 동기화 키를 삭제했습니다.';

  @override
  String get ankiSyncStatusClearLoginFailed => '저장된 로그인 세션을 삭제할 수 없습니다';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      '작업을 완료하지 못했습니다. 보안 저장소, 네트워크, 서버 주소를 확인하세요.';

  @override
  String get ankiSyncUnknown => '알 수 없음';

  @override
  String get ankiSyncServerCollectionEmpty => '서버 컬렉션이 비어 있음';

  @override
  String get ankiSyncServerCollectionAvailable => '서버 컬렉션을 사용할 수 있음';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return '스키마 버전 $schema · USN $usn · 수정됨 $modified';
  }

  @override
  String get asrPageTitle => '오디오 받아쓰기';

  @override
  String get clear => '지우기';

  @override
  String get configure => '구성';

  @override
  String get asrModel => '음성 인식 모델';

  @override
  String get reselectModel => '모델을 다시 선택하세요';

  @override
  String get selectAsrModel => '음성 인식 모델 선택';

  @override
  String get enterPublicAudioUrl => '공개 오디오 URL 입력';

  @override
  String get recordingSelection => '녹음';

  @override
  String get audioFiles => '오디오 파일';

  @override
  String get noAudioSelected => '선택한 오디오 파일이 없습니다';

  @override
  String get supportedAudioFormats => 'WAV, MP3, M4A, OGG 등 일반적인 오디오 형식을 지원합니다';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 파일 $count개 선택됨',
      one: '오디오 파일 $count개 선택됨',
      zero: '선택한 오디오 파일 없음',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 파일 $count개 선택됨',
      one: '오디오 파일 $count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => '다시 선택';

  @override
  String get asrUrlLabel => 'URL | 공개 링크';

  @override
  String get asrErrorDetails => '오류 세부정보 보기';

  @override
  String get asrResultSaved => '받아쓰기 결과 저장됨';

  @override
  String get asrWorking => '받아쓰는 중…';

  @override
  String get asrStart => '받아쓰기 시작';

  @override
  String get saveTo => '저장 위치';

  @override
  String get rootFolder => '루트 폴더';

  @override
  String get chooseSaveFolder => '폴더 선택';

  @override
  String get linkAlreadyAdded => '이 링크는 이미 목록에 있습니다';

  @override
  String get chooseAudioSource => '오디오 소스 선택';

  @override
  String get inAppRecordings => '앱 내 녹음';

  @override
  String get chooseGeneratedRecordings => '생성된 녹음 중에서 선택';

  @override
  String get systemAudioFiles => '시스템 오디오 파일';

  @override
  String get chooseDeviceAudioFiles => '기기에서 파일 선택';

  @override
  String get cannotReadAudioFile => '오디오 파일을 읽을 수 없습니다';

  @override
  String chooseAudioFileFailed(String details) {
    return '오디오 파일을 선택할 수 없습니다: $details';
  }

  @override
  String get chooseInAppRecording => '앱 내 녹음 선택';

  @override
  String get noRecordings => '녹음이 없습니다';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds초',
      one: '$seconds초',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider => '먼저 설정에서 오디오 받아쓰기 제공업체와 모델을 구성하세요';

  @override
  String get asrModelUnavailable =>
      '기존 음성 인식 모델을 사용할 수 없거나 확인할 수 없습니다. 모델을 다시 선택하세요.';

  @override
  String get asrUrlProviderRemoveFiles =>
      '이 제공업체는 URL로 오디오를 업로드합니다. 로컬 오디오 파일을 제거하고 다시 시도하세요.';

  @override
  String get asrFileProviderRemoveUrls =>
      '이 제공업체는 오디오 파일을 업로드하며 링크 받아쓰기를 지원하지 않습니다. 링크를 제거하고 다시 시도하세요.';

  @override
  String asrTaskStartFailed(String details) {
    return '작업을 시작하지 못했습니다: $details';
  }

  @override
  String get asrInvalidUrl => '올바르지 않은 URL입니다. http:// 또는 https://로 시작해야 합니다.';

  @override
  String get asrEnterAudioUrl => '오디오 URL 입력';

  @override
  String get asrUrlProviderHelp =>
      '이 제공업체는 URL로 오디오를 업로드합니다. 공개 오디오 URL(http/https)을 입력하세요.';

  @override
  String get cancel => '취소';

  @override
  String get add => '추가';

  @override
  String get ttsPageTitle => '오디오';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 파일 $count개 가져옴',
      one: '오디오 파일 $count개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return '가져오기 실패: $details';
  }

  @override
  String get ttsFileReadFailed => '파일 데이터를 읽을 수 없습니다';

  @override
  String get ttsExportAudioFile => '오디오 파일 내보내기';

  @override
  String ttsExportedTo(String path) {
    return '다음 위치로 내보냄: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return '내보내기 실패: $details';
  }

  @override
  String get ttsConfirmRegenerate => '다시 생성 확인';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return '오디오 ‘$fileName’을(를) 다시 생성하시겠습니까?';
  }

  @override
  String get ttsRegenerateOverwrite => '다시 생성한 후 원본 오디오 파일을 교체합니다.';

  @override
  String get ttsRegenerate => '오디오 다시 생성';

  @override
  String ttsCopiedFailed(String details) {
    return '복사할 수 없습니다: $details';
  }

  @override
  String get ttsChooseExportFolder => '내보낼 폴더 선택';

  @override
  String get ttsExportAudio => '오디오 내보내기';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 $count개 내보냄',
      one: '파일 $count개 내보냄',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => '폴더 내보내기';

  @override
  String get ttsWebFolderExportHelp =>
      '브라우저에서 내보낼 폴더를 선택할 수 없습니다. 폴더 구조를 유지한 ZIP 파일을 다운로드합니다.';

  @override
  String get ttsDownloadZip => 'ZIP 파일 다운로드';

  @override
  String get ttsExportAudioFolder => '오디오 폴더 내보내기';

  @override
  String get ttsRecord => '녹음';

  @override
  String get ttsImport => '가져오기';

  @override
  String get ttsPlay => '재생';

  @override
  String get ttsExportLocal => '기기로 내보내기';

  @override
  String get ttsRegenerateQuestion => '다시 생성';

  @override
  String get ttsNeedsProvider => '먼저 설정에서 음성 합성 제공업체와 모델을 구성하세요';

  @override
  String get ttsAddedToTasks => '작업 목록에 추가했습니다. 백그라운드에서 생성 중…';

  @override
  String get ttsCreateTitle => '음성 합성';

  @override
  String get ttsOriginalTitle => '녹음 제목';

  @override
  String get ttsUseOriginalTitle => '원래 제목 사용';

  @override
  String get ttsAudioFileNameHint => '저장할 오디오 파일 이름(선택 사항)';

  @override
  String get ttsTextToConvert => '변환할 텍스트';

  @override
  String get ttsSpeechContent => '음성 내용';

  @override
  String get ttsTextHint => '음성으로 변환할 텍스트 입력…';

  @override
  String get ttsFullscreenEdit => '전체 화면에서 편집';

  @override
  String ttsTextLimitWarning(int limit) {
    return '텍스트가 제한을 초과했습니다(최대 $limit자)';
  }

  @override
  String get ttsSynthesisConfig => '합성 설정';

  @override
  String get ttsVoiceAndSoundHelp => '음성과 소리를 조정합니다';

  @override
  String get ttsProviderSettingsLead => '에서 ';

  @override
  String get ttsProviderSettings => 'TTS 제공업체 설정';

  @override
  String get ttsProviderSettingsTail => ' 더 많은 매개변수를 구성합니다';

  @override
  String get ttsEditText => '텍스트 편집';

  @override
  String get ttsClose => '닫기';

  @override
  String get ttsVoice => '음성';

  @override
  String get ttsSelectVoice => '음성 선택';

  @override
  String get ttsSpeed => '속도';

  @override
  String get ttsNormal => '보통';

  @override
  String get ttsVolume => '음량';

  @override
  String get ttsInstruction => '말하기 스타일 지시문';

  @override
  String get ttsInstructionHint => '예: 밝고 신나는 어조로 말하기';

  @override
  String get ttsCustomParams => '사용자 지정 매개변수';

  @override
  String ttsDefaultValue(Object value) {
    return '기본값: $value';
  }

  @override
  String get ttsGenerateRecording => '녹음 생성';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return '다른 이름으로 저장: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => '폴더 선택';

  @override
  String get ttsFillTextError => '변환할 텍스트를 입력하세요';

  @override
  String get voiceBatchTitle => '음성 일괄 추가';

  @override
  String get voiceBatchConfirm => '선택한 음성 추가';

  @override
  String get voiceBatchSeparator => '구분 기호:';

  @override
  String get voiceBatchCustomSeparatorHint => '사용자 지정 구분 기호 입력';

  @override
  String get voiceBatchFieldOrder => '필드 순서:';

  @override
  String get voiceBatchNameThenId => '첫 번째 = 이름, 두 번째 = ID';

  @override
  String get voiceBatchIdThenName => '첫 번째 = ID, 두 번째 = 이름';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '열 $count개를 찾았습니다. 이름/ID의 시작 열을 선택하세요:',
      one: '열 $count개를 찾았습니다. 이름/ID의 시작 열을 선택하세요:',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return '열 $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn => '열 하나를 찾았습니다. 모든 값을 ID로 사용합니다(이름 = ID).';

  @override
  String get voiceBatchInputHint =>
      '탭, 쉼표, 세미콜론 또는 세로 막대로 이름과 ID를 구분하세요(줄마다 한 쌍).';

  @override
  String get voiceBatchNoPreview => '미리 볼 내용이 없습니다';

  @override
  String get voiceName => '음성 이름';

  @override
  String get voiceId => '음성 ID';

  @override
  String get status => '상태';

  @override
  String get voiceNew => '✅ 새 항목';

  @override
  String get voiceIdExists => '⚠️ ID가 이미 있습니다';

  @override
  String voiceFormatError(String details) {
    return '❌ 형식 오류$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '중복된 ID $count개: $ids',
      one: '중복된 ID $count개: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData => '선택한 열에 데이터가 부족합니다';

  @override
  String get voiceCustomSeparator => '사용자 지정…';

  @override
  String get voiceCommaSeparator => '쉼표 (,)';

  @override
  String get voiceSemicolonSeparator => '세미콜론 (;)';

  @override
  String get voicePipeSeparator => '세로 막대 (|)';

  @override
  String get voiceTabSeparator => '탭';

  @override
  String get voiceEditorTitle => '음성 편집';

  @override
  String get save => '저장';

  @override
  String get voiceAddRow => '행 추가';

  @override
  String get voiceBatchAdd => '일괄 추가';

  @override
  String get voiceNoneAdd => '아직 음성이 없습니다. 음성을 추가해 시작하세요.';

  @override
  String get delete => '삭제';

  @override
  String get voiceDuplicateResolution =>
      '다음 음성 ID가 중복됩니다. 각 ID를 어떻게 처리할지 선택하세요:';

  @override
  String get update => '업데이트';

  @override
  String get skip => '건너뛰기';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 중복 항목 남음',
      one: '$count개 중복 항목 남음',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => '계속 편집';

  @override
  String get asrRetryIncomplete =>
      '다시 시도할 오디오가 완전하지 않습니다. 목록을 지우고 모든 오디오를 다시 선택하세요.';

  @override
  String asrRetryAudioUnreadable(String details) {
    return '다시 시도할 오디오 데이터를 읽을 수 없습니다. 오디오를 다시 선택하세요: $details';
  }

  @override
  String get asrLegacyRetryUnavailable =>
      '이전 형식의 다시 시도용 오디오를 사용할 수 없습니다. 오디오를 다시 선택하세요.';

  @override
  String get asrRetryDataUnreadable => '다시 시도할 데이터를 읽을 수 없습니다. 오디오를 다시 선택하세요.';

  @override
  String get ttsSynthesisModel => '합성 모델';

  @override
  String get asrRetryUnavailable => '다시 시도할 오디오를 사용할 수 없습니다. 오디오를 다시 선택하세요.';

  @override
  String get chatRequest => '요청';

  @override
  String get chatResponse => '응답';

  @override
  String get chatNoErrorDetails => '사용할 수 있는 세부정보가 없습니다';

  @override
  String get ttsInstructionDescription =>
      '어조, 감정, 속도, 억양 및 기타 특성을 자연어로 설명하세요. 모델이 설명에 맞춰 합성 음성을 조정합니다.';

  @override
  String get audioPlayerSourceTextSource => '원문 텍스트 선택';

  @override
  String get audioPlayerChooseInAppText => '앱 내 텍스트 선택';

  @override
  String get audioPlayerChooseSavedTextSubtitle => '앱에 저장된 텍스트 파일 선택';

  @override
  String get audioPlayerChooseSystemText => '시스템 텍스트 파일 선택';

  @override
  String get audioPlayerChooseDeviceTextSubtitle => '기기 저장소에서 텍스트 파일 선택';

  @override
  String get audioPlayerSelectInAppText => '앱 내 텍스트 선택';

  @override
  String get audioPlayerNoTextFiles => '아직 텍스트 파일이 없습니다';

  @override
  String audioPlayerCharacterCount(int count) {
    return '문자 $count개';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return '텍스트를 선택하지 못했습니다: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => '텍스트 파일을 읽을 수 없습니다';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return '원문 텍스트를 업로드하지 못했습니다: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => '텍스트가 비어 있습니다';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return '원문 텍스트를 저장하지 못했습니다: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => '원문 텍스트 업로드됨';

  @override
  String get audioPlayerSourceTextUpdated => '원문 텍스트 업데이트됨';

  @override
  String get audioPlayerConfigureTtsProvider => '먼저 TTS 제공업체를 구성하세요';

  @override
  String get audioPlayerNoStreamingModels => '스트리밍 재생을 지원하는 모델이 없습니다';

  @override
  String get audioPlayerSelectStreamingModel => '스트리밍 재생 모델 선택';

  @override
  String get audioPlayerProviderFallback => '제공업체';

  @override
  String audioPlayerStartStreaming(String model) {
    return '스트리밍 재생 시작: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return '오디오 파일을 찾을 수 없습니다: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => '오디오 데이터를 불러올 수 없습니다';

  @override
  String get audioPlayerSourceText => '원문 텍스트';

  @override
  String get audioPlayerNoSourceText => '(원문 텍스트 없음)';

  @override
  String get audioPlayerUploadSourceText => '원문 텍스트 업로드';

  @override
  String get audioPlayerEditSourceText => '원문 텍스트 편집';

  @override
  String get audioPlayerCompanionTextMissing => '연결된 텍스트 파일을 찾을 수 없습니다';

  @override
  String get audioPlayerPlaySelection => '선택 항목 재생';

  @override
  String get audioPlayerGenerateSelection => '선택 항목 생성';

  @override
  String get audioPlayerPlaying => '재생 중...';

  @override
  String get audioPlayerPaused => '일시 정지됨';

  @override
  String get audioPlayerPlaybackSpeed => '재생 속도';

  @override
  String get audioPlayerFailed => '재생 실패';

  @override
  String get audioPlayerRetry => '다시 시도';

  @override
  String get audioPlayerLoading => '오디오 불러오는 중...';

  @override
  String get audioPlayerClose => '닫기';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      '브라우저에서 녹음을 지원하지 않습니다. 앱 버전을 사용하세요.';

  @override
  String get audioRecordingMicrophonePermissionRequired =>
      '녹음하려면 마이크 권한이 필요합니다';

  @override
  String audioRecordingStartFailure(String error) {
    return '녹음을 시작하지 못했습니다: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return '녹음을 일시 정지하지 못했습니다: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return '녹음을 재개하지 못했습니다: $error';
  }

  @override
  String get audioRecordingInvalidFile => '녹음 파일이 올바르지 않습니다. 다시 녹음하세요.';

  @override
  String audioRecordingStopFailure(String error) {
    return '녹음을 중지하지 못했습니다: $error';
  }

  @override
  String get audioRecordingFileNotFound => '녹음 파일을 찾을 수 없습니다';

  @override
  String get audioRecordingFileEmpty => '녹음 파일이 비어 있습니다';

  @override
  String audioRecordingSaved(String name) {
    return '녹음 저장됨: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return '녹음을 저장하지 못했습니다: $error';
  }

  @override
  String get audioRecordingTitle => '녹음';

  @override
  String get audioRecordingBrowserUnsupported => '브라우저에서 녹음을 지원하지 않습니다';

  @override
  String get audioRecordingUseApp => '녹음하려면 앱 버전을 사용하세요';

  @override
  String get audioRecordingDraftRecoveryHint =>
      '저장하지 않은 녹음 초안이 있습니다. 오디오 라이브러리에 저장할 수 있습니다.';

  @override
  String get audioRecordingRecording => '녹음 중 ●';

  @override
  String get audioRecordingPaused => '일시 정지됨 ||';

  @override
  String get audioRecordingPreparing => '준비 중...';

  @override
  String get audioRecordingStart => '녹음 시작';

  @override
  String get audioRecordingPause => '일시 정지';

  @override
  String get audioRecordingStopping => '중지 중...';

  @override
  String get audioRecordingStop => '중지';

  @override
  String get audioRecordingResume => '재개';

  @override
  String get audioRecordingSaving => '저장 중...';

  @override
  String get audioRecordingSave => '녹음 저장';

  @override
  String get audioRecordingRecordAgain => '다시 녹음';

  @override
  String get audioRecordingWaveformPaused => '녹음이 일시 정지되어 파형이 고정되었습니다';

  @override
  String get audioRecordingWaveformLive => '실시간 오디오 파형';

  @override
  String get audioSeparationTitle => '동영상 오디오 분리';

  @override
  String get audioSeparationChooseVideoSource => '동영상 소스 선택';

  @override
  String get audioSeparationChooseAppAlbum => '앱 라이브러리에서 선택';

  @override
  String get audioSeparationChooseSavedVideoSubtitle => '앱에 저장된 동영상 선택';

  @override
  String get audioSeparationChooseSystemAlbum => '시스템 저장소에서 선택';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle => '기기 저장소에서 동영상 파일 선택';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return '동영상을 선택하지 못했습니다: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix => '오디오 추출 실패: ';

  @override
  String get audioSeparationEngineMissing => '오디오 분리 엔진을 찾을 수 없습니다';

  @override
  String get audioSeparationEngineMissingHelp =>
      '앱을 다시 시작하거나 리소스가 모두 있는지 확인하세요.';

  @override
  String get audioSeparationNoVideoSelected => '선택한 동영상이 없습니다';

  @override
  String get audioSeparationSupportedFormatsHint => '지원 형식: mp4, mov, m4v, 3gp';

  @override
  String get audioSeparationSuccess => '오디오를 추출해 오디오 라이브러리에 저장했습니다';

  @override
  String get audioSeparationView => '보기';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동영상 $count개 선택됨',
      one: '동영상 $count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => '추출 중...';

  @override
  String get audioSeparationExtractAudio => '오디오 추출';

  @override
  String get audioSeparationSaveTo => '저장 위치';

  @override
  String get audioSeparationChooseSaveFolder => '저장 폴더 선택';

  @override
  String get audioSeparationCannotReadVideoFile => '동영상 파일을 읽을 수 없습니다';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return '동영상 파일을 선택하지 못했습니다: $error';
  }

  @override
  String get audioSeparationUnknownFormat => '알 수 없음';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return '지원하지 않는 형식: $formats. 지원 형식: MP4, MOV, M4V, 3GP.';
  }

  @override
  String get audioSeparationEngineUnavailable => '오디오 분리 엔진을 사용할 수 없습니다.';

  @override
  String get backgroundOptimizationTitle => '백그라운드 최적화';

  @override
  String get backgroundOptimizationEnvironment => '시스템 환경';

  @override
  String get backgroundOptimizationChecks => '백그라운드 서비스 상태';

  @override
  String get backgroundOptimizationKeepAliveStrategies => '백그라운드 유지 전략';

  @override
  String get backgroundOptimizationDetecting => '확인 중…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      '이 플랫폼에서는 백그라운드 서비스를 지원하지 않습니다';

  @override
  String get backgroundOptimizationServiceRunning => '백그라운드 서비스가 실행 중입니다';

  @override
  String get backgroundOptimizationServiceStopped => '백그라운드 서비스가 실행되고 있지 않습니다';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      '백그라운드 서비스 상태를 확인할 수 없습니다';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      '데스크톱 트레이를 사용할 수 없습니다. 창을 닫으면 앱이 종료됩니다.';

  @override
  String get backgroundOptimizationDesktopCloseExits => '데스크톱 창을 닫으면 앱이 종료됩니다';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      '데스크톱 트레이가 앱을 계속 실행합니다';

  @override
  String get backgroundOptimizationStartFailed => '서비스를 시작할 수 없습니다';

  @override
  String get backgroundOptimizationStopFailed => '서비스를 중지할 수 없습니다';

  @override
  String get backgroundOptimizationRestartFailed => '서비스를 다시 시작할 수 없습니다';

  @override
  String get backgroundOptimizationStopService => '서비스 중지';

  @override
  String get backgroundOptimizationRestartService => '서비스 다시 시작';

  @override
  String get backgroundOptimizationStartService => '서비스 시작';

  @override
  String get backgroundOptimizationRedetect => '다시 확인';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      '이 플랫폼에서는 백그라운드 서비스를 제어할 수 없습니다.';

  @override
  String get backgroundOptimizationCheckingBattery => '배터리 최적화 상태 확인 중…';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      '이 앱은 배터리 최적화 대상에서 제외되어 있습니다';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      '배터리 최적화가 활성화되어 있습니다. 백그라운드 작업이 중지될 수 있습니다';

  @override
  String get backgroundOptimizationIgnoreBattery => '배터리 최적화 사용 중지';

  @override
  String get backgroundOptimizationExactAlarm => '정확한 알람 허용(백그라운드 작업의 신뢰도 향상)';

  @override
  String get backgroundOptimizationWatchdogTitle => 'AlarmManager 감시 기능';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      '활성화하면 Android가 기본 알람을 사용해 5분마다 백그라운드 서비스를 확인합니다. 시스템이 프로세스를 종료하면 알람이 서비스를 다시 시작합니다.\n\n기기가 Doze 모드인 동안에도 알람이 작동하며, 재부팅 후 다시 예약됩니다.\n\n백그라운드 작업을 자주 사용하는 사용자에게 권장합니다.\n배터리 영향: 매우 낮음. 확인할 때마다 기기가 잠시 깨어납니다.';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      '감시 기능 설정을 저장할 수 없어 변경되지 않았습니다';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      '감시 기능을 활성화할 수 없습니다. 백그라운드 서비스 상태를 확인하지 못했습니다';

  @override
  String get backgroundOptimizationColdStartTitle => '앱 실행 시 서비스 복원';

  @override
  String get backgroundOptimizationColdStartDetail =>
      '활성화하면 앱을 열 때마다 이전에 실행 중이던 백그라운드 서비스가 있는지 확인하고 복원합니다.\n\n시스템이나 사용자가 앱 프로세스를 중지해도 앱을 다음에 열면 백그라운드 서비스가 다시 시작됩니다.\n\n모든 사용자에게 권장합니다.\n배터리 영향: 없음. 앱 실행 시 한 번만 확인합니다.';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      '실행 시 복구 설정을 저장할 수 없어 변경되지 않았습니다';

  @override
  String get backgroundOptimizationBatteryReminderTitle => '배터리 최적화 알림';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      '활성화하면 이 페이지에 배터리 최적화 상태가 표시됩니다. 앱이 배터리 제외 목록에 없으면 시스템 설정을 열어 제외할 수 있습니다.\n\nAndroid 배터리 최적화(Doze)는 백그라운드 앱의 활동을 제한합니다. 이 앱을 제외 목록에 추가하면 시스템이 절전을 위해 앱을 중지하지 않습니다.\n\n이 옵션을 끄면 알림 카드만 숨겨지고 앱의 배터리 제외 설정은 바뀌지 않습니다.';

  @override
  String get backgroundOptimizationStrategyIntro =>
      '각 전략은 독립적으로 활성화할 수 있습니다. 백그라운드 작업의 신뢰도를 높이기 위해 기본적으로 모두 켜져 있습니다. 전략을 끄면 해당 전략에만 영향을 주며 백그라운드 서비스 자체에는 영향을 주지 않습니다.';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOS 백그라운드 작업';

  @override
  String get backgroundOptimizationIosSupported =>
      'iOS 26 이상은 진행 중인 백그라운드 작업을 지원합니다. 앱을 전환하거나 화면을 잠가도 작업은 대체로 계속되지만, 리소스가 부족하면 시스템이 중지할 수 있습니다. 잠금 화면에서 진행 상황을 확인할 수 있습니다.';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'iOS 26보다 이전 버전은 진행 중인 백그라운드 작업을 지원하지 않습니다. 작업이 실행되는 동안 몇 분마다(약 5~10분, 간격은 iOS에 따라 다름) 앱으로 돌아와 백그라운드 실행 시간을 갱신하고 일시 중지되지 않도록 하세요.';

  @override
  String get backgroundOptimizationIosWarning =>
      '모든 iOS 버전에서 앱 전환 화면을 밀어 Stroom을 종료하지 마세요. 실행 중인 모든 작업이 즉시 중지됩니다.';

  @override
  String get backgroundOptimizationDesktopIntro =>
      '데스크톱 시스템에는 모바일 플랫폼의 프로세스 유지 기능이 없지만, 창을 닫은 뒤에도 앱을 계속 실행할 수 있습니다.';

  @override
  String get backgroundOptimizationCloseMinimizeTitle => '창을 닫을 때 트레이로 최소화';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      '활성화하면 창의 닫기 버튼을 눌러도 앱이 종료되지 않고 시스템 트레이에 숨겨집니다. 백그라운드 작업은 계속 실행됩니다.\n\n트레이 아이콘 또는 ‘기본 창 표시’ 메뉴 항목으로 창을 다시 여세요. 앱을 종료하려면 아래의 ‘앱 종료’ 버튼을 사용하세요.\n\n모든 데스크톱 사용자에게 권장합니다.';

  @override
  String get backgroundOptimizationQuitApp => '앱 종료';

  @override
  String get backgroundOptimizationGotIt => '확인';

  @override
  String get backgroundOptimizationWebNoteTitle => '웹 백그라운드 작업';

  @override
  String get backgroundOptimizationWebNote =>
      '브라우저는 앱을 백그라운드에서 계속 실행할 수 없습니다. 이 탭을 닫거나 새로 고치거나, 비활성 탭이 브라우저에 의해 일시 중지되면 실행 중인 작업도 즉시 중단됩니다. 작업이 실행되는 동안 Stroom 탭을 열어 두고 활성 상태로 유지하세요.';

  @override
  String get backgroundOptimizationTutorial => '플랫폼별 안내';

  @override
  String get backgroundOptimizationTutorialDescription =>
      '플랫폼별 백그라운드 최적화 안내 보기';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      '백그라운드 서비스 상태를 확인하고 있습니다…';

  @override
  String get backgroundOptimizationServiceUnknown =>
      '백그라운드 서비스 상태를 알 수 없습니다. 서비스 실행 여부를 확인하려면 다시 확인하세요.';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      '백그라운드 서비스가 실행 중입니다. 작업을 백그라운드에서 계속 진행할 수 있습니다.';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      '웹 브라우저에서는 백그라운드 서비스를 지원하지 않습니다. 작업을 계속하려면 이 페이지를 열어 두세요.';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      '데스크톱 트레이를 사용할 수 없습니다(Linux 빌드에는 libayatana-appindicator3-dev가 필요합니다). 창을 닫으면 앱이 종료됩니다.';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      '데스크톱 트레이를 사용할 수 없습니다. 창을 닫으면 앱이 종료됩니다.';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      '데스크톱 창을 닫으면 앱이 종료되도록 설정되어 있습니다. 기존 종료 확인 절차를 따르며 트레이에서 계속 실행되지 않습니다.';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      '데스크톱 트레이가 활성화되어 있습니다. 창을 닫으면 앱이 시스템 트레이로 숨겨진 채 계속 실행됩니다. 트레이 메뉴에서 ‘기본 창 표시’를 선택해 다시 여세요. 완전히 종료하려면 트레이 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      '데스크톱 트레이가 활성화되어 있습니다. 창을 닫으면 앱이 시스템 트레이로 최소화되어 계속 실행됩니다. 트레이 아이콘을 클릭하거나 메뉴에서 ‘기본 창 표시’를 선택해 창을 다시 여세요. 완전히 종료하려면 트레이 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      '백그라운드 서비스가 실행되고 있지 않습니다. 아래의 ‘서비스 시작’을 선택하거나 플랫폼별 안내에서 백그라운드 작업 최적화 방법을 확인하세요.';

  @override
  String get notificationSettingsPageTitle => '알림 권한 설정';

  @override
  String get notificationSettingsWebUnsupported => '웹 브라우저에서는 알림을 지원하지 않습니다';

  @override
  String get notificationSettingsChecking => '확인 중…';

  @override
  String get notificationSettingsPermissionGranted => '알림 권한 허용됨';

  @override
  String get notificationSettingsPermissionDenied => '알림 권한이 허용되지 않음';

  @override
  String get notificationSettingsPermissionRestricted => '알림 권한이 제한됨';

  @override
  String get notificationSettingsPermissionBlocked => '알림 권한이 영구적으로 차단됨';

  @override
  String get notificationSettingsPermissionProvisional => '알림 권한이 임시로 허용됨';

  @override
  String get notificationSettingsWebGuide => '웹 브라우저에서는 시스템 알림을 지원하지 않습니다.';

  @override
  String get notificationSettingsCheckingPermission => '알림 권한 확인 중…';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      '알림 권한이 허용되었습니다. 작업이 완료되거나 실패할 때 시스템 알림을 받으려면 작업 완료 알림을 켜세요.';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      '알림 권한이 허용되지 않았습니다. 아래 버튼을 눌러 권한을 요청하거나 시스템 설정에서 Stroom 알림을 켜세요.';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      '자녀 보호 기능 등으로 시스템이 알림 권한을 제한하고 있습니다. 시스템 설정에서 Stroom의 알림 설정을 확인하세요.';

  @override
  String get notificationSettingsEnvironment => '시스템 환경';

  @override
  String get notificationSettingsPermissionSection => '알림 권한';

  @override
  String get notificationSettingsPlatformGuides => '플랫폼별 안내';

  @override
  String get notificationSettingsGuideIntro =>
      '운영체제에 맞는 다음 단계를 따라 Stroom 알림을 켜세요.';

  @override
  String get notificationSettingsTaskCompleteTitle => '작업 완료 알림';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      '작업이 완료되거나 실패하면 알림 보내기';

  @override
  String get notificationSettingsCheckAgain => '다시 확인';

  @override
  String get notificationSettingsOpenSystemSettings => '시스템 설정 열기';

  @override
  String get notificationSettingsRequestPermission => '권한 요청';

  @override
  String get notificationSettingsGuideUnsupported =>
      '이 플랫폼에서는 알림 설정 안내를 사용할 수 없습니다.';

  @override
  String get notificationSettingsUsageReason => '작업 완료 시 알림을 보내기 위해';

  @override
  String get notificationSettingsAndroidEnableTitle => '알림 켜기';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      '설정 → 앱 → Stroom → 알림 관리로 이동해 알림을 허용하세요. 목록에서 Stroom을 찾을 수 없다면 설치 여부를 확인하세요. 알림이 꺼져 있으면 켜세요.';

  @override
  String get notificationSettingsAndroidDndTitle => '방해 금지 확인';

  @override
  String get notificationSettingsAndroidDndDescription =>
      '설정 → 소리 및 진동 → 방해 금지로 이동하세요. 방해 금지를 끄거나 Stroom 알림을 허용하세요.';

  @override
  String get notificationSettingsAndroidPopupTitle => '팝업 알림 허용';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'MIUI, EMUI, ColorOS 등 일부 Android 시스템에서는 앱 정보에서 ‘알림 허용’과 ‘팝업 허용’을 켜야 합니다. 앱의 ‘알림 필터링’ 또는 ‘스마트 알림’도 꺼 보세요.';

  @override
  String get notificationSettingsReturnTitle => '이 페이지로 돌아오기';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      '설정을 변경한 뒤 ‘다시 확인’을 선택해 권한 상태를 확인하세요. 권한이 허용되면 작업 완료 알림을 켤 수 있습니다.';

  @override
  String get notificationSettingsIosEnableDescription =>
      '설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 작업 상태를 확인할 수 있도록 배너와 알림 센터도 활성화하세요.';

  @override
  String get notificationSettingsIosFocusTitle => '집중 모드 끄기';

  @override
  String get notificationSettingsIosFocusDescription =>
      '설정 → 집중 모드로 이동하세요. 집중 모드를 끄거나 허용된 앱 목록에 Stroom을 추가하세요. 집중 모드에서는 앱 알림이 차단될 수 있습니다.';

  @override
  String get notificationSettingsIosReturnDescription =>
      '설정을 변경한 뒤 ‘다시 확인’을 선택해 권한 상태를 확인하세요. iOS에서는 보통 시스템 설정에서 알림 권한을 직접 허용해야 합니다.';

  @override
  String get notificationSettingsWindowsEnableTitle => '시스템 알림 켜기';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      '설정 → 시스템 → 알림 및 작업으로 이동해 ‘앱 및 다른 보낸 사람의 알림 받기’를 켜세요. 아래 앱 목록에서 Stroom을 찾아 알림이 켜져 있는지 확인하세요.';

  @override
  String get notificationSettingsWindowsFocusTitle => '집중 지원 예외 추가';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      '설정 → 시스템 → 집중 지원으로 이동하세요. Stroom을 ‘우선 순위만’ 목록에 추가하거나 집중 지원을 끄세요. 집중 지원은 알림을 차단할 수 있습니다.';

  @override
  String get notificationSettingsMacEnableTitle => '알림 켜기';

  @override
  String get notificationSettingsMacEnableDescription =>
      '시스템 설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 배너와 알림 센터도 활성화하세요.';

  @override
  String get notificationSettingsMacFocusDescription =>
      '시스템 설정 → 집중 모드로 이동하세요. 집중 모드를 끄거나 허용된 앱 목록에 Stroom을 추가하세요.';

  @override
  String get notificationSettingsLinuxDesktopTitle => '데스크톱 알림 설정 확인';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      '데스크톱 환경(GNOME, KDE, XFCE 등)에 따라 시스템 설정 → 알림으로 이동해 Stroom을 찾고 알림이 켜져 있는지 확인하세요.';

  @override
  String get notificationSettingsLinuxDaemonTitle => '알림 데몬 확인';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux 데스크톱 환경에서 시스템 알림을 표시하려면 notify-osd 또는 dunst와 같은 알림 데몬이 필요합니다. 하나가 설치되어 실행 중인지 확인하세요.';

  @override
  String get backupRestorePageTitle => '백업 및 복원';

  @override
  String get backupRestoreSelectBackupCategory => '백업할 데이터 범주를 하나 이상 선택하세요';

  @override
  String get backupRestorePreparingData => '데이터 준비 중…';

  @override
  String get backupRestoreExportingBackup => '백업 내보내는 중';

  @override
  String get backupRestoreCollectingDatabase => '데이터베이스 기록 수집 중…';

  @override
  String get backupRestoreProcessingSettings => '설정 처리 중…';

  @override
  String get backupRestoreAddingTasks => '작업 파일 추가 중…';

  @override
  String get backupRestoreAddingPictures => '이미지 파일 추가 중…';

  @override
  String get backupRestoreAddingAudio => '오디오 파일 추가 중…';

  @override
  String get backupRestoreAddingVideo => '동영상 파일 추가 중…';

  @override
  String get backupRestoreAddingText => '텍스트 파일 추가 중…';

  @override
  String get backupRestoreAddingChat => '채팅 기록과 첨부 파일 추가 중…';

  @override
  String get backupRestoreCompressing => '압축 파일 만드는 중…';

  @override
  String get backupRestoreCompleted => '완료';

  @override
  String get backupRestoreSelectRestoreCategory => '복원할 데이터 범주를 하나 이상 선택하세요';

  @override
  String get backupRestoreConfirmRestore => '복원 확인';

  @override
  String get backupRestoreSelectedCategories => '선택한 데이터 범주:';

  @override
  String get backupRestoreRestoreInfo =>
      '백업에서 선택한 범주를 찾아 이 기기에 복원합니다. 기본 제공 브라우저 쿠키를 제외한 모든 범주는 해당 로컬 데이터를 대체합니다. 쿠키는 도메인, 이름, 경로별로 기록하며 백업에 포함되지 않은 로컬 쿠키는 유지됩니다. 선택하지 않은 범주와 백업에 없는 범주는 변경되지 않습니다. 누락된 범주는 알림과 함께 건너뜁니다.';

  @override
  String get backupRestoreRestartNotice =>
      '복원한 변경사항을 적용하려면 앱을 다시 시작하세요. 현재 작업을 저장했는지 확인하세요.';

  @override
  String get backupRestoreCancel => '취소';

  @override
  String get backupRestoreConfirmRestoreButton => '복원';

  @override
  String get backupRestoreIncompleteTitle => '복원 미완료';

  @override
  String get backupRestoreIncompleteMessage =>
      '데이터를 완전히 복원하지 못해 일부 데이터가 삭제되었을 수 있습니다. 앱을 다시 시작한 후 다시 시도하세요.';

  @override
  String get backupRestoreSelectClearCategory => '삭제할 데이터 범주를 하나 이상 선택하세요';

  @override
  String get backupRestoreClearingData => '데이터 삭제 중';

  @override
  String get backupRestoreDeletingCategories => '선택한 데이터 범주 삭제 중…';

  @override
  String get backupRestoreClearedTitle => '데이터 삭제됨';

  @override
  String get backupRestorePartiallyClearedTitle => '일부 데이터 삭제됨';

  @override
  String get backupRestoreClearedMessage =>
      '선택한 데이터를 삭제했습니다. 변경사항을 적용하려면 앱을 다시 시작하세요.';

  @override
  String get backupRestorePartialClearMessage =>
      '선택한 다른 데이터는 삭제했습니다. 이 플랫폼에서는 기본 제공 브라우저의 웹사이트 저장소(localStorage, IndexedDB 등)를 완전히 삭제할 수 없으므로 삭제하지 못한 브라우저 데이터가 남아 있습니다. 삭제 결과를 적용하려면 앱을 다시 시작하세요.';

  @override
  String backupRestoreClearFailed(String error) {
    return '데이터를 삭제할 수 없습니다: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => '삭제 미완료';

  @override
  String get backupRestoreClearIncompleteMessage =>
      '일부 데이터를 삭제하지 못했습니다. 앱을 다시 시작한 뒤 다시 삭제해 보세요.';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki 덱을 다음 위치로 내보냈습니다: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get backupRestoreApkgRequired => '.apkg 파일을 선택하세요';

  @override
  String backupRestoreImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return '백업을 다음 위치에 저장했습니다: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return '백업 실패: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return '복원 실패: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected =>
      '백업 폴더가 선택되지 않았습니다. 시작할 때 폴더에 대한 액세스 권한을 허용하세요.';

  @override
  String get backupRestoreRestoreSuccessTitle => '데이터 복원됨';

  @override
  String get backupRestoreRestoredMessage =>
      '백업에서 데이터를 복원했습니다. 복원한 데이터를 사용하려면 앱을 다시 시작하세요.';

  @override
  String get backupRestoreExitApp => '앱 종료';

  @override
  String get backupRestoreRestartNow => '지금 다시 시작';

  @override
  String get backupRestoreSkippedTitle => '일부 데이터 건너뜀';

  @override
  String get backupRestoreNothingRestoredTitle => '복원된 데이터 없음';

  @override
  String get backupRestoreGotIt => '확인';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return '백업에서 선택한 다음 범주를 복원할 수 있는 콘텐츠로 확인하지 못해 건너뛰었으며 기존 데이터는 유지했습니다: $categories.';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      '이전 백업에서는 빈 작업 파일만으로 작업 목록이 비어 있는지 해당 플랫폼에서 작업을 내보내지 않았는지 구분할 수 없습니다. 현재 작업을 덮어쓰지 않도록 작업 범주를 건너뛰고 기존 데이터를 유지했습니다.';

  @override
  String get backupRestoreSkippedCookies =>
      '백업에 가져올 기본 제공 브라우저 쿠키가 없어 이 범주를 건너뛰고 기존 쿠키를 유지했습니다.';

  @override
  String get backupRestoreSkippedWebsiteData =>
      '이전 백업의 웹사이트 저장소 디렉터리를 건너뛰었습니다. 아카이브에 쿠키가 포함되어 있고 해당 범주를 선택한 경우 쿠키는 별도로 가져올 수 있습니다.';

  @override
  String get backupRestoreApkgTitle => 'Anki 덱';

  @override
  String get backupRestoreApkgInfoTitle => 'Anki 덱 가져오기 또는 내보내기';

  @override
  String get backupRestoreApkgInfoMessage => '카드 정보만 포함하며 미디어는 포함하지 않습니다';

  @override
  String get backupRestoreApkgDescription => '.apkg 형식의 Anki 덱을 가져오거나 내보냅니다';

  @override
  String get backupRestoreExportingApkg => '내보내는 중…';

  @override
  String get backupRestoreExportApkg => '.apkg 내보내기';

  @override
  String get backupRestoreImportingApkg => '가져오는 중…';

  @override
  String get backupRestoreImportApkg => '.apkg 가져오기';

  @override
  String get backupRestoreCategoryHeading => '백업 또는 복원할 데이터 범주 선택';

  @override
  String get backupRestoreExporting => '내보내는 중…';

  @override
  String get backupRestoreExportBackup => '백업 내보내기';

  @override
  String get backupRestoreRestoring => '복원 중…';

  @override
  String get backupRestoreChooseBackup => '백업 파일 선택 및 복원';

  @override
  String get backupRestoreClearSelected => '선택한 데이터 삭제';

  @override
  String get backupRestoreClearDescription =>
      '백업 파일 없이 선택한 데이터 범주를 바로 삭제합니다. 선택하지 않은 범주는 변경되지 않습니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get backupRestoreClearing => '삭제 중…';

  @override
  String get backupRestoreCategoryChat => '채팅 기록 및 첨부 파일';

  @override
  String get backupRestoreCategoryChatDescription => '채팅 대화, 메시지 내용, 첨부 파일';

  @override
  String get backupRestoreCategorySettings => '설정';

  @override
  String get backupRestoreCategorySettingsDescription =>
      '앱 구성, 제공업체 설정, 인터페이스 환경설정';

  @override
  String get backupRestoreCategoryPictures => '이미지';

  @override
  String get backupRestoreCategoryPicturesDescription => '사진 및 미리보기 이미지';

  @override
  String get backupRestoreCategoryAudio => '오디오';

  @override
  String get backupRestoreCategoryAudioDescription => '음성 합성 및 녹음';

  @override
  String get backupRestoreCategoryVideos => '동영상';

  @override
  String get backupRestoreCategoryVideosDescription => '동영상 파일';

  @override
  String get backupRestoreCategoryTexts => '텍스트';

  @override
  String get backupRestoreCategoryTextsDescription => '텍스트 문서';

  @override
  String get backupRestoreCategoryTasks => '작업';

  @override
  String get backupRestoreCategoryTasksDescription => '백그라운드 작업 기록';

  @override
  String get backupRestoreCategoryAnki => 'Anki 플래시카드 데이터';

  @override
  String get backupRestoreCategoryAnkiDescription => 'Anki 데이터베이스';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki 플래시카드 데이터';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Anki 플래시카드 데이터를 백업하거나 복원하면 collection.media 디렉터리의 카드 미디어도 포함됩니다.';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'Anki 플래시카드 데이터 정보';

  @override
  String get backupRestoreCategoryBrowser => '기본 제공 브라우저 데이터';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      '쿠키만 백업 및 복원하며, 삭제 시 지원되는 웹사이트 저장소도 제거합니다';

  @override
  String get backupRestoreViewInfo => '정보 보기';

  @override
  String get backupRestoreApkgInfoTooltip => 'Anki 덱 가져오기 및 내보내기 정보';

  @override
  String get backupRestoreConfirmClear => '삭제 확인';

  @override
  String get backupRestoreClearCategoriesIntro =>
      '백업 파일을 사용하지 않고 다음 데이터 범주를 삭제합니다:';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      '이 플랫폼에서는 기본 제공 브라우저의 웹사이트 저장소(localStorage, IndexedDB 등)를 완전히 삭제할 수 없습니다. 확인하면 선택한 다른 데이터는 삭제되지만, 삭제할 수 없는 브라우저 데이터는 남습니다.';

  @override
  String get backupRestoreUnselectedUnchanged => '선택하지 않은 범주는 변경되지 않습니다.';

  @override
  String get backupRestoreClearWarning =>
      '이 작업은 취소할 수 없습니다. 삭제한 변경사항을 적용하려면 앱을 다시 시작하세요.';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return '삭제($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => '브라우저 환경';

  @override
  String get backupRestoreIntro =>
      '선택한 데이터 범주를 수동으로 내보냅니다. 가져올 때는 아카이브에서 선택한 범주만 복원합니다. 범주나 필수 파일이 없으면 알림과 함께 건너뛰고, 선택하지 않은 범주는 변경되지 않습니다. 선택한 범주를 바로 삭제할 수도 있습니다.';

  @override
  String get backupRestoreOtherSelectedRestored =>
      '선택한 다른 데이터는 복원했습니다. 변경사항을 적용하려면 앱을 다시 시작하세요.';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      '알림이 차단되어 있습니다. 시스템 설정을 열고 Stroom의 알림을 허용하세요.';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      '알림이 차단되어 있습니다. 시스템 설정 → 앱 → Stroom → 알림 관리로 이동해 알림을 허용하세요.';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      '알림이 차단되어 있습니다. 시스템 설정 → Stroom → 알림으로 이동해 알림을 허용하세요.';

  @override
  String get textPreviewDiscardEditsTitle => '편집 내용 버리기';

  @override
  String get textPreviewUnsavedChangesConfirm => '저장하지 않은 변경사항이 있습니다. 버리시겠습니까?';

  @override
  String get textPreviewCancel => '취소';

  @override
  String get textPreviewDiscard => '버리기';

  @override
  String get textPreviewFontSize => '글자 크기 조정';

  @override
  String get textPreviewRestoreDefault => '기본값 복원';

  @override
  String get textPreviewClose => '닫기';

  @override
  String textPreviewSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get textPreviewUndo => '실행 취소';

  @override
  String get textPreviewRedo => '다시 실행';

  @override
  String get textPreviewSave => '저장';

  @override
  String get textPreviewEdit => '편집';

  @override
  String get textPreviewChartEdit => '차트 편집';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return '지원하지 않는 형식을 건너뜀: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '텍스트 파일 #개 가져옴',
      one: '텍스트 파일 #개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get textStorageSaved => '텍스트 저장됨';

  @override
  String get textStorageLoadFailed => '텍스트 내용을 불러올 수 없습니다';

  @override
  String get textStorageReadFailed => '파일 데이터를 읽지 못했습니다';

  @override
  String get textStorageExportTitle => '텍스트 내보내기';

  @override
  String textStorageExportedTo(String path) {
    return '다음 위치로 내보냄: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get textStorageChooseExportDirectory => '내보낼 디렉터리 선택';

  @override
  String get textStorageFolderExportTitle => '폴더 내보내기';

  @override
  String get textStorageWebFolderExportInfo =>
      '브라우저에서 내보낼 디렉터리를 선택할 수 없습니다. 폴더 구조를 유지하는 ZIP 파일을 다운로드합니다.';

  @override
  String get textStorageCancel => '취소';

  @override
  String get textStorageDownloadZip => 'ZIP 파일 다운로드';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 #개 내보냄',
      one: '파일 #개 내보냄',
    );
    return '$_temp0';
  }

  @override
  String get textStorageExportFolderTitle => '텍스트 폴더 내보내기';

  @override
  String textStorageCopyFailed(String error) {
    return '복사 실패: $error';
  }

  @override
  String get textStorageCreateNew => '새로 만들기';

  @override
  String get textStorageImport => '가져오기';

  @override
  String get textStorageTitle => '텍스트';

  @override
  String get textStorageExportToLocal => '로컬로 내보내기';

  @override
  String get textCreateEnterTitle => '제목을 입력하세요';

  @override
  String textCreateSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get textCreateNewTitle => '새로 만들기';

  @override
  String get textCreateSave => '저장';

  @override
  String get textCreateTitleLabel => '제목';

  @override
  String get textCreateTitleHint => '텍스트 제목 입력';

  @override
  String get textCreateFormatLabel => '형식';

  @override
  String get textCreateContentLabel => '텍스트 내용';

  @override
  String get textCreateContentHint => '텍스트 내용 입력...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform 백그라운드 최적화 안내';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform 백그라운드 실행 안내';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform 백그라운드 최적화 가이드';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return '다음 단계를 따르면 $platform 기기에서 Stroom의 백그라운드 실행을 최적화해 작업을 계속 진행할 수 있습니다.';
  }

  @override
  String get platformTutorialStepsHeading => '최적화 단계';

  @override
  String get platformTutorialTipsHeading => '팁';

  @override
  String get platformTutorialTipsDescription =>
      '설정을 마친 뒤 ‘백그라운드 최적화’ 페이지로 돌아와 상태가 업데이트되었는지 확인하세요. 문제가 계속되면 다른 플랫폼의 안내를 확인하거나 GitHub에 문제를 보고하세요.';

  @override
  String get platformTutorialAndroidStep1Title => '배터리 최적화 끄기';

  @override
  String get platformTutorialAndroidStep1Description =>
      '설정 → 앱 → Stroom → 배터리로 이동한 뒤 ‘제한 없음’ 또는 ‘최적화하지 않음’을 선택하세요. 또는 Stroom의 ‘백그라운드 최적화’ 페이지에서 ‘배터리 최적화 사용 중지’를 눌러 시스템 절전 허용 목록에 추가할 수 있습니다. 메뉴 경로는 기기 제조사에 따라 다릅니다.';

  @override
  String get platformTutorialAndroidStep2Title => '백그라운드 활동 허용';

  @override
  String get platformTutorialAndroidStep2Description =>
      '설정 → 앱 → Stroom으로 이동해 ‘백그라운드 활동 허용’과 ‘자동 시작 허용’을 켜세요. 일부 휴대전화에서는 보안 센터나 휴대전화 관리자에서도 자동 시작을 허용해야 합니다.';

  @override
  String get platformTutorialAndroidStep3Title => '백그라운드 프로세스 잠금';

  @override
  String get platformTutorialAndroidStep3Description =>
      '최근 앱 화면에서 Stroom 카드를 아래로 밀거나 잠금 아이콘을 눌러 시스템이 앱을 지우지 못하게 하세요.';

  @override
  String get platformTutorialAndroidStep4Title => '알림 허용(Android 13 이상)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 이상에서는 알림 권한이 필요합니다. 권한이 없으면 백그라운드 서비스 알림이 숨겨지지만 서비스는 계속 실행됩니다. ‘서비스 시작’을 처음 누르면 권한을 요청하며 설정 → 앱 → Stroom → 알림에서도 허용할 수 있습니다.';

  @override
  String get platformTutorialAndroidStep5Title => '배터리 최적화 제외';

  @override
  String get platformTutorialAndroidStep5Description =>
      'Stroom에서 ‘작업 완료 알림’을 켜면 관련 권한을 요청합니다. 설정 → 앱 → 특별한 앱 액세스 → 배터리 최적화에서 Stroom이 ‘최적화하지 않음’으로 설정되어 있는지도 확인할 수 있습니다.';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Android 기기의 자동 시작 및 백그라운드 관리';

  @override
  String get platformTutorialAndroidStep6Description =>
      '기기 제조사는 자체 백그라운드 제어 기능을 추가하는 경우가 많습니다.\n• Xiaomi/Redmi(MIUI/HyperOS): 설정 → 앱 → 권한 → 자동 시작에서 Stroom을 허용하세요. 그런 다음 배터리 → 앱 배터리 절약 → Stroom → 제한 없음으로 설정하세요.\n• Huawei/Honor(EMUI/HarmonyOS): 설정 → 앱 → 앱 실행 → Stroom → 수동 관리에서 자동 실행, 보조 실행, 백그라운드 활동을 허용하세요.\n• OPPO/OnePlus/realme(ColorOS): 설정 → 배터리 → 앱 배터리 관리 → Stroom에서 백그라운드 활동을 모두 허용하세요.\n• vivo/iQOO(OriginOS): iManager → 앱 관리 → 자동 시작에서 Stroom을 허용하세요.';

  @override
  String get platformTutorialAndroidStep7Title => '화면 잠금 시 정리 및 절전 모드 끄기';

  @override
  String get platformTutorialAndroidStep7Description =>
      '설정 → 배터리로 이동해 ‘절전’ 또는 ‘초절전’을 끄세요. ‘잠금 후 메모리 정리’도 ‘정리 안 함’으로 설정하세요. 절전 모드는 백그라운드 활동을 제한해 작업 완료에 영향을 줄 수 있습니다.';

  @override
  String get platformTutorialIosStep1Title => '백그라운드 앱 새로 고침 켜기';

  @override
  String get platformTutorialIosStep1Description =>
      '설정 → 일반 → 백그라운드 앱 새로 고침으로 이동해 Stroom을 찾아 켜세요. 최상의 사용 환경을 위해 ‘Wi-Fi 및 셀룰러 데이터’를 선택하세요.';

  @override
  String get platformTutorialIosStep2Title => '알림 허용';

  @override
  String get platformTutorialIosStep2Description =>
      '설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 작업 업데이트를 바로 확인할 수 있도록 배너와 알림 센터를 모두 활성화하세요.';

  @override
  String get platformTutorialIosStep3Title => '저전력 모드 끄기';

  @override
  String get platformTutorialIosStep3Description =>
      '설정 → 배터리로 이동해 ‘저전력 모드’를 끄세요. 이 모드가 켜져 있으면 시스템이 백그라운드 활동을 제한합니다.';

  @override
  String get platformTutorialIosStep4Title => 'iOS 백그라운드 제한 이해하기';

  @override
  String get platformTutorialIosStep4Description =>
      'iOS 26 이전 버전에서는 Android처럼 앱을 백그라운드에 계속 둘 수 없습니다. 백그라운드 앱 새로 고침, 위치 업데이트, 오디오 재생 등 특정 시점에만 잠시 실행할 수 있으며, 장시간 작업은 일시 중지될 수 있습니다. 다음을 권장합니다:\n• 장시간 작업 중에는 Stroom을 전면에 두세요.\n• 주기적으로 앱으로 돌아와 백그라운드 실행 시간을 갱신하세요.\n• 중요한 작업은 ‘작업 완료 알림’을 켜세요.';

  @override
  String get platformTutorialIosStep5Title => '작업 중 백그라운드 실행 팁';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 이상에서는 지속적인 백그라운드 작업을 지원합니다. 앱을 전환하거나 화면을 잠가도 작업은 대체로 계속되지만, 리소스가 부족하면 시스템이 중지할 수 있습니다. 진행 상황은 잠금 화면에 표시됩니다.\n\niOS 26 이전 버전에서는 지속적인 백그라운드 작업을 지원하지 않습니다. 몇 분마다(5~10분은 참고 기준이며 실제 간격은 시스템이 결정) 앱으로 돌아와 백그라운드 실행 시간을 갱신하고 일시 중지를 방지하세요.\n\n모든 버전에서 앱 전환 화면을 밀어 Stroom을 종료하지 마세요. 실행 중인 모든 작업이 즉시 중지됩니다.';

  @override
  String get platformTutorialIosStep6Title => '앱을 전면에 유지';

  @override
  String get platformTutorialIosStep6Description =>
      'iOS 26 이전 버전에서는 앱의 백그라운드 실행 시간이 제한됩니다. 장시간 작업 중에는 Stroom을 전면에 두거나 주기적으로 앱으로 돌아와 실행 시간을 연장하세요.';

  @override
  String get platformTutorialWindowsStep1Title => '창을 닫을 때 트레이로 최소화';

  @override
  String get platformTutorialWindowsStep1Description =>
      '기본적으로 창의 닫기 버튼을 누르면 Stroom이 종료되지 않고 시계 근처의 시스템 트레이로 최소화되어 계속 실행됩니다. 트레이 아이콘이나 ‘기본 창 표시’ 메뉴에서 다시 여세요. 작업 실행 중에는 앱을 종료하지 마세요. 종료하려면 ‘백그라운드 최적화’ 페이지의 ‘앱 완전히 종료’ 또는 트레이 메뉴의 ‘Stroom 종료’를 사용하세요.';

  @override
  String get platformTutorialWindowsStep2Title => '배터리 절약 모드 끄기';

  @override
  String get platformTutorialWindowsStep2Description =>
      '설정 → 시스템 → 전원 및 절전으로 이동해 배터리 절약 모드를 끄세요. 또는 배터리가 지정한 수준 아래로 떨어질 때만 켜지도록 설정할 수 있습니다.';

  @override
  String get platformTutorialWindowsStep3Title => '백그라운드 앱 허용';

  @override
  String get platformTutorialWindowsStep3Description =>
      '설정 → 개인 정보 및 보안 → 백그라운드 앱으로 이동해 Stroom을 찾아 켜져 있는지 확인하세요. Windows 11에서는 설정 → 앱 → 설치된 앱 → Stroom → 고급 옵션 → 백그라운드 앱 권한으로 이동해 ‘항상’을 선택하세요.';

  @override
  String get platformTutorialWindowsStep4Title => '절전 모드 끄기(선택 사항)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'Stroom을 장시간 실행하려면 설정 → 시스템 → 전원에서 ‘절전’을 ‘안 함’으로 설정하세요(전원에 연결된 경우에만).';

  @override
  String get platformTutorialWindowsStep5Title => 'Stroom을 시작 프로그램에 추가';

  @override
  String get platformTutorialWindowsStep5Description =>
      '작업 관리자(Ctrl+Shift+Esc) → 시작 앱으로 이동해 Stroom을 찾아 마우스 오른쪽 버튼으로 ‘사용’을 선택하세요. 또는 설정 → 앱 → 시작 프로그램에서 Stroom을 켜세요.';

  @override
  String get platformTutorialMacosStep1Title => '창을 닫을 때 트레이로 최소화';

  @override
  String get platformTutorialMacosStep1Description =>
      '기본적으로 창을 닫아도 Stroom은 화면 오른쪽 위의 메뉴 막대에서 계속 실행됩니다. 메뉴 막대 아이콘을 클릭하거나 ‘기본 창 표시’를 선택해 다시 여세요. 작업이 실행 중일 때 앱을 종료하지 마세요. 종료하려면 ‘백그라운드 최적화’ 페이지에서 ‘앱 완전히 종료’를 사용하거나 메뉴 막대 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get platformTutorialMacosStep2Title => '알림 허용';

  @override
  String get platformTutorialMacosStep2Description =>
      '시스템 설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 배너와 알림 센터를 모두 활성화하는 것이 좋습니다.';

  @override
  String get platformTutorialMacosStep3Title => '저전력 모드 끄기(MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      '시스템 설정 → 배터리 → 전원 어댑터로 이동해 ‘저전력 모드’를 끄세요. 이 모드는 백그라운드 활동을 제한합니다.';

  @override
  String get platformTutorialMacosStep4Title => '앱을 활성 상태로 유지';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS는 백그라운드 앱을 거의 제한하지 않습니다. 장시간 작업을 실행하려면 Stroom 창을 열어 두세요. 앱을 강제 종료하지 마세요. 창만 닫으면 됩니다.';

  @override
  String get platformTutorialMacosStep5Title => '로그인 시 자동 실행(선택 사항)';

  @override
  String get platformTutorialMacosStep5Description =>
      '시스템 설정 → 일반 → 로그인 항목으로 이동해 Stroom을 추가하면 컴퓨터를 켤 때 자동으로 시작됩니다.';

  @override
  String get platformTutorialLinuxStep1Title => '창을 닫을 때 트레이로 최소화';

  @override
  String get platformTutorialLinuxStep1Description =>
      '기본적으로 창을 닫으면 Stroom이 시스템 트레이에 숨겨집니다(빌드 시 StatusNotifierItem을 지원하는 데스크톱 환경과 libayatana-appindicator3-dev가 필요합니다). 트레이 메뉴에서 ‘기본 창 표시’를 선택해 다시 여세요. 작업이 실행 중일 때 앱을 종료하지 마세요. 종료하려면 ‘백그라운드 최적화’ 페이지의 ‘앱 완전히 종료’를 사용하거나 트레이 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get platformTutorialLinuxStep2Title => '데스크톱 환경 설정';

  @override
  String get platformTutorialLinuxStep2Description =>
      '데스크톱 환경(GNOME, KDE, XFCE 등)에 따라 시스템 설정 → 앱으로 이동해 Stroom을 찾고 백그라운드 활동이 제한되지 않았는지 확인하세요.';

  @override
  String get platformTutorialLinuxStep3Title => 'systemd 서비스 사용(선택 사항)';

  @override
  String get platformTutorialLinuxStep3Description =>
      '장시간 백그라운드 작업을 실행하려면 systemd 사용자 서비스를 만드세요. ~/.config/systemd/user/ 아래에 stroom.service 파일을 만들고 ExecStart를 Stroom 실행 파일로 설정합니다.';

  @override
  String get platformTutorialLinuxStep4Title => '절전 비활성화';

  @override
  String get platformTutorialLinuxStep4Description =>
      '장시간 실행해야 하는 서버나 데스크톱에서는 /etc/systemd/logind.conf에서 HandleLidSwitch=ignore로 설정해 덮개를 닫아도 절전 상태가 되지 않도록 하세요.';

  @override
  String get platformTutorialLinuxStep5Title => '자동 시작 활성화';

  @override
  String get platformTutorialLinuxStep5Description =>
      'GNOME에서는 Tweaks → 시작 프로그램 → Stroom 추가를 사용하세요. 또는 ~/.config/autostart/ 아래에 stroom.desktop 파일을 만드세요.';

  @override
  String get platformTutorialWebStep1Title => '탭을 열어 두기';

  @override
  String get platformTutorialWebStep1Description =>
      '웹 브라우저는 백그라운드 서비스를 지원하지 않습니다. 작업이 실행되는 동안 Stroom 탭을 열어 두세요. 탭을 닫거나 페이지를 새로 고치면 작업이 즉시 중단됩니다.';

  @override
  String get platformTutorialWebStep2Title => '브라우저가 탭을 일시 중지하지 않도록 하기';

  @override
  String get platformTutorialWebStep2Description =>
      '브라우저는 리소스를 절약하기 위해 비활성 백그라운드 탭을 정지할 수 있습니다. 작업이 실행되는 동안 Stroom 탭을 전면에 두거나 페이지를 주기적으로 사용해 활성 상태를 유지하세요.';

  @override
  String get browserNavigationFailed => '페이지 이동 실패; 주소를 복원했습니다';

  @override
  String get browserAddressHint => '웹 주소 입력';

  @override
  String get browserUserScripts => '사용자 스크립트';

  @override
  String get browserSwitchToMobile => '모바일 보기로 전환';

  @override
  String get browserSwitchToDesktop => '데스크톱 보기로 전환';

  @override
  String get browserUaSwitchedDesktop => '데스크톱 사용자 에이전트로 전환됨';

  @override
  String get browserUaSwitchedMobile => '모바일 사용자 에이전트로 전환됨';

  @override
  String get browserCookieRetentionOnTooltip => '쿠키 유지(켜짐)';

  @override
  String get browserCookieRetentionOffTooltip => '쿠키 유지(꺼짐)';

  @override
  String get browserCookiePersistenceEnabled => '쿠키 저장 활성화됨';

  @override
  String get browserCookiePersistenceDisabled => '쿠키 저장 비활성화됨';

  @override
  String get browserSniffPanelHideTooltip => '감지 패널 숨기기';

  @override
  String get browserSniffPanelShowTooltip => '감지 패널 표시';

  @override
  String get browserAdd => '추가';

  @override
  String get browserNoScripts => '아직 스크립트가 없습니다. ‘추가’를 눌러 만드세요.';

  @override
  String get browserUnnamedScript => '이름 없는 스크립트';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '일치하는 규칙 $_temp0';
  }

  @override
  String get browserScriptOriginManual => '수동으로 추가됨';

  @override
  String browserScriptVersion(Object version) {
    return '@버전 $version';
  }

  @override
  String get browserScriptEnabled => '사용';

  @override
  String get browserScriptDisabled => '사용 안 함';

  @override
  String get browserScriptRuntimeError =>
      '이 스크립트에서 실행 오류가 발생했습니다. 코드와 페이지 호환성을 확인하세요.';

  @override
  String get browserScriptDelete => '삭제';

  @override
  String get browserDeleteScriptTitle => '스크립트를 삭제하시겠습니까?';

  @override
  String get browserDeleteScriptConfirmation =>
      '이 브라우저에서 스크립트를 제거합니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get browserEditScript => '스크립트 편집';

  @override
  String get browserScriptName => '스크립트 이름';

  @override
  String get browserScriptCode => '스크립트 코드(JavaScript)';

  @override
  String get browserAddScriptMethod => '스크립트 추가 방법 선택';

  @override
  String get browserImportFromUrl => 'URL에서 가져오기';

  @override
  String get browserEnterManually => '직접 입력';

  @override
  String get browserScriptTrustWarningTitle => '신뢰하는 스크립트만 가져오세요';

  @override
  String get browserScriptTrustWarning =>
      '스크립트는 데이터를 유출할 수 있으므로 신뢰하는 것만 추가하세요. 스크립트는 웹페이지 콘텐츠를 읽거나 수정할 수 있습니다.';

  @override
  String get browserContinue => '계속';

  @override
  String get browserManualUserscriptLabel => 'Tampermonkey 사용자 스크립트';

  @override
  String get browserScriptImportUrl => '스크립트 URL';

  @override
  String get browserScriptImportFetch => '미리보기 가져오기';

  @override
  String get browserScriptPreview => '스크립트 원본 미리보기';

  @override
  String get browserScriptImportInvalidUrl => '올바른 HTTPS URL을 입력하세요.';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Greasy Fork의 .user.js URL 또는 GitHub Raw URL을 사용하세요.';

  @override
  String get browserScriptImportRedirectedUrl =>
      '지원되지 않거나 안전하지 않은 주소로 리디렉션되었습니다.';

  @override
  String get browserScriptImportNotScript =>
      '응답이 비어 있거나 JavaScript 스크립트로 보이지 않습니다.';

  @override
  String get browserScriptImportNetworkError =>
      '스크립트를 가져올 수 없습니다. URL과 연결 상태를 확인하세요.';

  @override
  String browserScriptImportHttpError(Object status) {
    return '서버가 HTTP $status를 반환했습니다.';
  }

  @override
  String get browserCancel => '취소';

  @override
  String get browserSave => '저장';

  @override
  String get browserCookiesConfirmClear => '삭제 확인';

  @override
  String get browserCookiesConfirmClearAll =>
      '쿠키를 모두 삭제하시겠습니까?\n이 작업은 취소할 수 없습니다.';

  @override
  String get browserCookiesClear => '삭제';

  @override
  String get browserCookiesCancel => '취소';

  @override
  String get browserCookiesClearedAll => '쿠키를 모두 삭제했습니다';

  @override
  String get browserCookiesClearFailed => '삭제할 수 없습니다. 다시 시도하세요.';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return '$domain의 쿠키를 모두 삭제했습니다';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '$domain의 쿠키를 모두 삭제하시겠습니까?';
  }

  @override
  String get browserCookiesPageTitle => '브라우저 데이터 관리';

  @override
  String get browserCookiesRetentionTitle => '종료할 때 쿠키 유지';

  @override
  String get browserCookiesRetentionOn => '사용 — 종료할 때 쿠키를 유지합니다';

  @override
  String get browserCookiesRetentionOff => '사용 안 함 — 종료할 때 쿠키를 삭제합니다';

  @override
  String get browserCookiesClearAllTitle => '쿠키 모두 삭제';

  @override
  String get browserCookiesClearAllDescription => '저장된 웹사이트 쿠키를 모두 삭제합니다';

  @override
  String get browserCookiesEmptyTitle => '저장된 데이터 없음';

  @override
  String get browserCookiesEmptyDescription =>
      '기본 제공 브라우저를 사용하고 쿠키 저장을 켜면 여기에 저장된 데이터가 표시됩니다.';

  @override
  String browserCookiesStoredCount(Object count) {
    return '저장된 쿠키($count개)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '쿠키 $_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip => '이 도메인의 쿠키 모두 삭제';

  @override
  String get browserCookiesDeleteOneTooltip => '이 쿠키 삭제';

  @override
  String get browserCookiesDeletedOne => '쿠키 삭제됨';

  @override
  String get browserCookiesDeleteFailed => '삭제할 수 없습니다. 다시 시도하세요.';

  @override
  String get browserCookiesEmptyValue => '(빈 값)';

  @override
  String get platformTutorialPageTitle => '플랫폼별 안내';

  @override
  String get browserRecoveryOpenPage => '복구 페이지 열기';

  @override
  String galleryUnsupportedPreview(String format) {
    return '.$format 파일은 미리보기를 지원하지 않습니다';
  }

  @override
  String galleryCameraFailed(String error) {
    return '사진을 찍을 수 없습니다: $error';
  }

  @override
  String get galleryPhotoSaved => '사진 저장됨';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return '지원하지 않는 형식을 건너뜀: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미지 #개 가져옴',
      one: '이미지 #개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동영상 #개 가져옴',
      one: '동영상 #개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get galleryFileReadFailed => '파일 데이터를 읽을 수 없습니다';

  @override
  String get galleryExportImageTitle => '이미지 내보내기';

  @override
  String get galleryExportVideoTitle => '동영상 내보내기';

  @override
  String galleryExportedTo(String path) {
    return '다음 위치로 내보냄: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get galleryChooseExportDirectory => '내보낼 디렉터리 선택';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 #개 내보냄',
      one: '파일 #개 내보냄',
    );
    return '$_temp0';
  }

  @override
  String get galleryFolderExportTitle => '폴더 내보내기';

  @override
  String get galleryWebFolderExportInfo =>
      '브라우저에서 내보낼 디렉터리를 선택할 수 없습니다. 폴더 구조를 유지하는 ZIP 파일을 다운로드합니다.';

  @override
  String get galleryDownloadZip => 'ZIP 파일 다운로드';

  @override
  String get galleryExportImageFolderTitle => '이미지 폴더 내보내기';

  @override
  String get galleryExportVideoFolderTitle => '동영상 폴더 내보내기';

  @override
  String get galleryImagePageTitle => '갤러리';

  @override
  String get galleryVideoPageTitle => '동영상';

  @override
  String get galleryTakePhoto => '사진 촬영';

  @override
  String get galleryRecordVideo => '녹화';

  @override
  String get galleryImport => '가져오기';

  @override
  String get galleryExportToLocal => '로컬로 내보내기';

  @override
  String get galleryPlayVideo => '재생';

  @override
  String galleryCopyFailed(String error) {
    return '복사 실패: $error';
  }

  @override
  String get galleryVideoSaved => '동영상 저장됨';

  @override
  String galleryVideoRecordFailed(String error) {
    return '녹화 실패: $error';
  }

  @override
  String get galleryVideoLoadFailed => '동영상을 불러올 수 없습니다';

  @override
  String get imageEditorSaveImageTitle => '이미지 저장';

  @override
  String get imageEditorSaveImagePrompt => '이미지를 저장할 방법 선택:';

  @override
  String get imageEditorOverwrite => '덮어쓰기';

  @override
  String get imageEditorSaveAs => '다른 이름으로 저장';

  @override
  String get imageEditorSavePhotoTitle => '사진 저장';

  @override
  String get imageEditorSavePhotoPrompt => '이 사진을 저장하시겠습니까?';

  @override
  String get imageEditorDiscard => '버리기';

  @override
  String get imageEditorDoneLoading => '이미지를 생성하는 중입니다. 잠시 기다려 주세요…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return '빠른 편집 – $fileName';
  }

  @override
  String get imageEditorNotReady => '편집기를 아직 사용할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String imageEditorProcessingFailed(String error) {
    return '이미지를 처리할 수 없습니다: $error';
  }

  @override
  String get imageEditorLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get imageEditorProcessing => '이미지를 처리하는 중입니다. 잠시 기다려 주세요…';

  @override
  String get imageEditorRotateLeft => '왼쪽으로 회전';

  @override
  String get imageEditorRotateRight => '오른쪽으로 회전';

  @override
  String get imageEditorFlip => '뒤집기';

  @override
  String get imageEditorCrop => '자르기';

  @override
  String get imageViewerImageSavedAsCopy => '이미지를 복사본으로 저장했습니다';

  @override
  String get imageViewerImageUpdated => '이미지를 업데이트했습니다';

  @override
  String imageViewerSaveFailed(String error) {
    return '이미지를 저장할 수 없습니다: $error';
  }

  @override
  String get imageViewerInvalidIndex => '잘못된 이미지 인덱스';

  @override
  String get galleryExportImageArchiveFileName => '이미지-내보내기.zip';

  @override
  String get galleryExportVideoArchiveFileName => '동영상-내보내기.zip';

  @override
  String get galleryExportImageFolderArchiveFileName => '이미지-폴더-내보내기.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName => '동영상-폴더-내보내기.zip';

  @override
  String get catCatchPageTitle => '웹 리소스 다운로드';

  @override
  String get catCatchAddTask => '작업 추가';

  @override
  String get catCatchOpenBrowser => '기본 제공 브라우저';

  @override
  String get catCatchEmptyState => '아직 다운로드 작업이 없습니다';

  @override
  String get catCatchEmptyStateHint => '오른쪽 위의 +를 눌러 다운로드 작업을 추가하세요';

  @override
  String get catCatchInvalidCapturedUrl => '캡처한 URL이 올바르지 않습니다';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return '브라우저에서 캡처함: $url';
  }

  @override
  String get catCatchEnterValidUrl => '올바른 URL을 하나 이상 입력하세요';

  @override
  String get catCatchTaskAdded => '작업 추가됨';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 추가됨',
      one: '$count개 추가됨',
    );
    return '작업 $_temp0';
  }

  @override
  String get catCatchViewTaskList => '작업 목록 보기';

  @override
  String get catCatchUrlHint => '동영상/오디오 웹페이지 URL 입력';

  @override
  String get catCatchDeleteTask => '이 작업 삭제';

  @override
  String get catCatchHour => '시간';

  @override
  String get catCatchMinute => '분';

  @override
  String get catCatchSecond => '초';

  @override
  String get catCatchDurationPreview => '미리보기: ';

  @override
  String get catCatchDurationFormat => '시:분:초';

  @override
  String get catCatchDurationFilterHint =>
      '선택 사항: 길이로 동영상 리소스를 필터링합니다. 비워 두면 선택 가능한 모든 리소스를 표시합니다.';

  @override
  String get catCatchVideoSaveTo => '동영상 저장 위치';

  @override
  String get catCatchAudioSaveTo => '오디오 저장 위치';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 추가됨',
      one: '$count개 추가됨',
    );
    return '작업 $_temp0';
  }

  @override
  String get catCatchStartAnalysis => '분석';

  @override
  String get catCatchVideoFolderTitle => '동영상 저장 폴더';

  @override
  String get catCatchAudioFolderTitle => '오디오 저장 폴더';

  @override
  String get catCatchRootFolder => '루트 폴더';

  @override
  String connectivityTestTitle(String title) {
    return '$title · 연결 테스트';
  }

  @override
  String get connectivityTestJsonLabel => '테스트 내용(JSON)';

  @override
  String get connectivityTestJsonHelp =>
      '변경사항을 바로 실행하거나 저장할 수 있습니다. MCP는 읽기 전용 tools/list를 사용하고, 검색 도구에서는 검색어/결과 수를 변경할 수 있습니다. Todo는 기본적으로 읽기 전용입니다.';

  @override
  String connectivityTestSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get connectivityTestSaved => '테스트 내용 저장됨';

  @override
  String get connectivityTestClose => '닫기';

  @override
  String get connectivityTestSaveContent => '내용 저장';

  @override
  String get connectivityTestTesting => '테스트 중…';

  @override
  String get connectivityTestRun => '테스트 실행';

  @override
  String get connectivityTestFailedSummary => '테스트를 완료하지 못했습니다';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds초';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds밀리초';
  }

  @override
  String get messageSearchTitle => '메시지 검색';

  @override
  String get messageSearchHint => '모든 대화에서 메시지 검색...';

  @override
  String get messageSearchInitialState => '모든 대화에서 메시지를 검색하려면 키워드를 입력하세요';

  @override
  String get messageSearchEmptyState => '일치하는 메시지가 없습니다';

  @override
  String get messageSearchNewConversation => '새 대화';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '일치 항목 $_temp0';
  }

  @override
  String get filesTabText => '텍스트';

  @override
  String get filesTabAudio => '오디오';

  @override
  String get filesTabImages => '이미지';

  @override
  String get filesTabVideos => '동영상';

  @override
  String get filesReorderTabs => '탭 순서 변경';

  @override
  String get filesReorderCancel => '취소';

  @override
  String get filesReorderDone => '완료';

  @override
  String get bgTaskCancelled => '취소됨';

  @override
  String bgTaskAsrError(String details) {
    return '음성 받아쓰기 실패: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return '음성 받아쓰기 저장 실패: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR 실패: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'OCR 결과 저장 실패: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR 결과가 불완전합니다: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => '일부 OCR 페이지를 완료하지 못했습니다';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return ' · 단계 ${phaseElapsedMs}ms · 요청 $completedRequests개 · 청크 $completedChunks/$chunkCount개 완료';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return '오디오$chunk 업로드 중 $percent% · $bytes바이트$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return '오디오$chunk 업로드 중$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return ' (청크 $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return '음성 받아쓰는 중$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return '음성 받아쓰는 중(청크 $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return '음성 받아쓰는 중(청크 $index/$count 수신)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return '결과 수신 중 $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => '결과 수신 중';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return '음성 받아쓰는 중(청크 $index/$count개 완료)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return '음성 받아쓰는 중(청크 $index/$count 반환됨)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return '이미지 $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return '$details 업로드 중';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return '이미지 업로드 중 $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR 복구 체크포인트를 저장하지 못해 요청 결과를 확인할 수 없습니다. 작업을 중지했습니다: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR 복구 체크포인트를 저장하지 못해 이 청크를 전송하지 않았습니다. 로컬 저장소를 수정한 후 다시 시도할 수 있습니다: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return '취소하기 전에 ASR 청크 상태를 저장하지 못해 이 청크의 결과를 확인할 수 없습니다: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'ASR 다시 시도용 오디오를 저장하지 못해 작업을 전송하지 않았습니다: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError => '다른 오디오 파일을 저장하지 못해 전송을 취소했습니다';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR 결과가 불완전합니다(finish_reason=$finishReason)';
  }

  @override
  String ocrResultPageHeading(String index) {
    return '이미지 $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return '이미지 $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => ' (일부 결과)';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return '일부 이미지를 완전히 인식하지 못했습니다: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return '이미지 $index: 결과 불완전';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return '이미지 $index: 인식 실패';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => '; ';

  @override
  String get bgTaskInterruptedOnRestart => '앱을 다시 시작하는 동안 중단됨';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR 오류 세부정보가 숨겨졌습니다';

  @override
  String get bgTaskErrorDetailsHidden => '오류 세부정보가 숨겨졌습니다';

  @override
  String get notificationBannerTaskCompletedHeading => '작업 완료';

  @override
  String get notificationBannerTaskFailedHeading => '작업 실패';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return '작업 완료: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return '작업 실패: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title 완료됨';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title 실패: $error';
  }

  @override
  String get notificationUnknownError => '알 수 없는 오류';

  @override
  String get desktopTrayTooltip => 'Stroom이 백그라운드에서 실행 중입니다';

  @override
  String get desktopTrayOpen => 'Stroom 열기';

  @override
  String get desktopTrayShowMainWindow => '기본 창 표시';

  @override
  String get desktopTrayQuitStroom => 'Stroom 종료';

  @override
  String get providerPresetExaDescription =>
      'Exa MCP를 통해 웹을 검색하고 페이지 콘텐츠를 추출하며, 시맨틱 및 키워드 검색으로 심층 조사를 지원합니다.';

  @override
  String get providerPresetExaApiKeyHint => 'Exa 웹사이트에서 API 키를 받으세요.';

  @override
  String get providerPresetTavilyDescription =>
      '대규모 언어 모델에 최적화된 실시간 웹 검색을 제공하는 AI 기반 검색 엔진입니다.';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Tavily에서 API 키를 받으세요. ?tavilyApiKey= 또는 Authorization: Bearer 헤더를 지원합니다.';

  @override
  String get providerPresetJinaDescription =>
      '웹 콘텐츠 추출, 임베딩 생성, 검색 결과 조회를 제공하는 멀티모달 AI 서비스입니다.';

  @override
  String get providerPresetJinaApiKeyHint =>
      '웹사이트에서 Jina AI API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetFirecrawlDescription =>
      '웹페이지를 깔끔한 Markdown이나 구조화된 데이터로 변환하는 웹 크롤링 및 추출 서비스입니다.';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Firecrawl API 키를 받거나 무료 사용량 한도 내에서 키 없이 사용해 보세요.';

  @override
  String get providerPresetZhipuDescription =>
      '웹페이지를 가져오고 이해하는 Zhipu AI 웹 리더 MCP 서비스입니다.';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Zhipu AI 오픈 플랫폼에서 API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetBraveSearchDescription =>
      '고품질 검색 결과를 제공하는 개인정보 보호 중심의 독립 검색 엔진입니다.';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Brave Search 웹사이트에서 API 키를 받으세요.';

  @override
  String get providerPresetBochaDescription =>
      'Bocha AI 웹 검색은 중국어 페이지에 대한 지능형 검색 결과를 제공합니다.';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Bocha AI 오픈 플랫폼에서 API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetQueritDescription =>
      'Querit AI 검색은 지능형 검색과 콘텐츠 탐색을 제공합니다.';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Querit 웹사이트에서 API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetSearxngDescription =>
      '개인정보 보호에 중점을 두고 여러 검색 소스를 통합하는 자체 호스팅 메타 검색 엔진입니다.';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'SearXNG 인스턴스 URL을 설정하세요(예: http://your-instance:8080). API 키는 선택 사항입니다.';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS 합성 실패: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '\n원래 오류: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      '네트워크 연결 시간이 초과되었습니다. 네트워크 또는 API 주소를 확인하세요.';

  @override
  String get ttsErrorServerResponseTimeout =>
      '서버 응답 시간이 초과되었습니다. 나중에 다시 시도하세요.';

  @override
  String ttsErrorConnectionFailed(String details) {
    return '서버에 연결할 수 없습니다($details).';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return '서버에 연결할 수 없습니다. 웹 앱에서는 CORS 제한 또는 잘못된 API 주소가 원인일 수 있습니다. $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API 오류(HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return '연결 시간이 초과되었습니다. 네트워크를 확인하세요$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return '응답 수신 시간이 초과되었습니다. 서버 응답이 느립니다$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API 키가 올바르지 않거나 권한이 없습니다(HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return '요청이 너무 많습니다. 나중에 다시 시도하세요(HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API 엔드포인트를 찾을 수 없습니다(HTTP $status): $body\nAPI 기본 URL이 올바른지 확인하세요$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return '서버 내부 오류(HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return '서버 오류(HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return '요청이 취소되었습니다$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return '서버에 연결할 수 없습니다. 웹 앱에서는 CORS 제한 또는 잘못된 API 주소가 원인일 수 있습니다. 제공업체 API 주소가 올바르고 서버가 교차 출처 요청을 허용하는지 확인하세요.$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return '네트워크 오류: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => '알 수 없는 네트워크 오류';

  @override
  String get ttsErrorNoResponseBody => '응답 본문이 없습니다';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return '스트리밍 합성 실패: $details';
  }

  @override
  String get mermaidEditorTitle => 'Mermaid 차트 편집기';

  @override
  String get mermaidEditorModeEdit => '편집';

  @override
  String get mermaidEditorModeSplit => '편집 + 미리보기';

  @override
  String get mermaidEditorModePreview => '미리보기';

  @override
  String get mermaidEditorSwitchViewMode => '보기 모드 전환';

  @override
  String get mermaidEditorSaveToTextStorage => '텍스트 저장소에 저장';

  @override
  String get mermaidEditorEmptyChart => '차트 내용이 비어 있어 저장할 수 없습니다';

  @override
  String get mermaidEditorSaveChartTitle => '차트 저장';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      '.mmd 차트 파일을 저장할 폴더를 선택하거나 만드세요';

  @override
  String get mermaidEditorFileNameHint => '파일 이름 입력(.mmd 자동 추가)';

  @override
  String get mermaidEditorEmptyFileName => '파일 이름은 비워 둘 수 없습니다';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return '텍스트 저장소에 저장됨: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor => '미리보기와 편집기 패널 전환';

  @override
  String get mermaidEditorCodeLabel => 'Mermaid 코드';

  @override
  String get mermaidEditorCodeHint => 'Mermaid 코드 입력...';

  @override
  String get mermaidEditorSplitCodeLabel => '코드';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'SSE 연결 실패(HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'SSE 연결 실패(HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable => 'SSE 연결 실패: 서버에 연결할 수 없습니다';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'HTTP 요청 실패(HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => '요청 실패';

  @override
  String get sseNetworkRequestFailed => '네트워크 요청 실패';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return '네트워크 요청 실패(HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return '네트워크 요청 실패(HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable => '네트워크 요청 실패: 서버에 연결할 수 없습니다';

  @override
  String get sseRequestCancelled => '요청이 취소되었습니다';

  @override
  String get startupSafetyTitle => '데이터 안전 보호';

  @override
  String get startupSafetyExportButton => '데이터 내보내기';

  @override
  String get startupSafetyExitButton => '앱 종료';

  @override
  String get startupSafetyUpdateButton => '앱 업데이트';

  @override
  String get startupSafetyCheckingUpdates => '업데이트 확인 중...';

  @override
  String get startupSafetyUpToDate => '최신 버전을 사용 중입니다';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return '이 데이터는 앱의 최신 버전($version)에서 생성되었습니다.\n\n현재 앱 버전에서는 데이터를 안전하게 읽을 수 없습니다. 최신 버전을 설치한 후 계속하세요. 데이터는 변경되지 않았습니다.';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      '데이터 안전 상태를 확인할 수 없습니다(상태 표시를 읽을 수 없거나 올바르지 않습니다).\n\n멈춘 상태를 덮어쓰지 않도록 데이터를 복구하거나 형식을 마이그레이션하지 않고 시작을 차단했습니다. 먼저 데이터 파일을 내보낸 다음 앱을 종료하고 상태 표시를 복구한 후 다시 시도하세요.';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return '데이터 형식 마이그레이션에 실패했습니다($part).\n\n데이터를 보호하기 위해 아무것도 변경하지 않았습니다. 이전 앱 버전으로 돌아가거나 수정된 버전이 나올 때까지 기다리세요.';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return '데이터 형식 마이그레이션에 실패했습니다($part).\n\n데이터를 마이그레이션 전 상태로 복원했습니다. 데이터 보호를 위해 이전 앱 버전으로 돌아가거나 수정된 버전이 나올 때까지 기다리세요.';
  }

  @override
  String get startupSafetyDataCorrupted =>
      '데이터가 손상되어 자동으로 복구할 수 없습니다.\n\n추가 손상을 막기 위해 앱을 정지했습니다. 데이터 파일을 내보낸 후 직접 가져오거나 앱을 다시 설치하세요.';

  @override
  String get startupSafetyPreferencesUnavailable =>
      '시작 확인에 필요한 환경설정을 읽지 못해 데이터를 보호하기 위해 앱 시작을 차단했습니다.\n\n저장 공간이나 권한을 확인한 뒤 앱을 다시 여세요.';

  @override
  String get startupSafetyValidationUnavailable =>
      '시작 데이터 안전 검사를 완료하지 못해 데이터를 보호하기 위해 앱 시작을 차단했습니다.\n\n브라우저 설정을 확인한 뒤 앱을 다시 여세요.';

  @override
  String startupSafetyCheckFailed(String detail) {
    return '시작 확인 실패: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      '시작 확인 후에도 데이터 안전 상태를 확인할 수 없습니다(상태 표시를 읽을 수 없거나 올바르지 않습니다).\n\n데이터가 더 변경되지 않도록 시작을 중지했습니다. 데이터 파일을 내보내고 앱을 종료한 뒤 상태 표시를 복구하고 다시 시도하세요.';

  @override
  String get catCatchConnectionTimeout =>
      '연결 시간이 초과되었습니다. 네트워크 또는 서버 상태를 확인하세요.';

  @override
  String get catCatchSendTimeout => '요청을 보내는 중 시간이 초과되었습니다.';

  @override
  String get catCatchReceiveTimeout => '서버 응답이 너무 느려 응답 시간이 초과되었습니다.';

  @override
  String get catCatchCannotConnect => '서버에 연결할 수 없습니다.';

  @override
  String get catCatchConnectionError => '서버에 연결할 수 없습니다. URL이 올바른지 확인하세요.';

  @override
  String get catCatchBadCertificate => '서버 인증서를 확인할 수 없습니다.';

  @override
  String catCatchBadResponse(int statusCode) {
    return '서버 오류(HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => '요청이 취소되었습니다.';

  @override
  String catCatchNetworkError(String message) {
    return '네트워크 오류: $message';
  }

  @override
  String get catCatchUnknownError => '알 수 없는 오류';

  @override
  String catCatchOriginalError(String message) {
    return '원래 오류: $message';
  }

  @override
  String get catCatchWebDownloadHint => '웹 브라우저에서는 미디어 파일을 직접 다운로드할 수 없습니다.';

  @override
  String get catCatchWebInstallExtension =>
      'CatCatch 브라우저 확장 프로그램을 설치한 후 다시 시도하세요.';

  @override
  String get catCatchWebAuthorAttribution =>
      '제작자: 笨笨猫 (xifangczy). 무료 오픈 소스입니다.';

  @override
  String get catCatchWebOfficialWarning =>
      '제작자가 배포한 버전인지 확인하고, 유료 버전이나 모방 버전은 피하세요.';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      '이 기능을 사용하려면 로그인해야 합니다. 오른쪽 위의 브라우저에서 로그인하세요.';

  @override
  String get catCatchNoUsableMedia =>
      '사용 가능한 미디어 리소스가 없습니다. URL과 웹사이트 연결 상태를 확인하세요.';

  @override
  String get catCatchRedownloadFileMissing => '다운로드한 파일이 없어 다운로드에 실패했습니다.';

  @override
  String get catCatchRedownloadPathEmpty => '다운로드한 파일 경로가 비어 있어 다운로드에 실패했습니다.';

  @override
  String get catCatchWebBrowserRequired =>
      '브라우저 환경 없이는 이 페이지의 리소스를 가져올 수 없습니다. 모바일 또는 데스크톱에서 기능을 사용하거나 동영상/오디오 파일의 직접 URL을 붙여넣으세요.';

  @override
  String get catCatchPlaylistNoSegments => '재생 목록에 다운로드할 세그먼트가 없습니다.';

  @override
  String get catCatchDownloadedSourceMissing =>
      '다운로드한 원본 파일이 없습니다. 다시 다운로드하세요.';

  @override
  String get appLogPageTitle => '앱 로그';

  @override
  String get appLogRefresh => '새로 고침';

  @override
  String get appLogCleanupOldLogs => '오래된 로그 정리';

  @override
  String get appLogCleanupDone => '오래된 로그를 정리했습니다';

  @override
  String appLogRetentionNotice(int days) {
    return '로그 보관 기간: 최근 $days일의 로그만 보관하며, $days일이 지난 로그는 자동으로 정리됩니다.';
  }

  @override
  String get appLogWebUnsupported => '웹에서는 로컬 로그를 지원하지 않습니다';

  @override
  String get appLogNoFiles => '아직 로그 파일이 없습니다';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '자동 새로 고침 중(시도 $count회)...',
      one: '자동 새로 고침 중(시도 $count회)...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated => '앱이 실행 중일 때 로그가 생성됩니다';

  @override
  String get appLogExport => '내보내기';

  @override
  String get appLogDelete => '삭제';

  @override
  String get appLogConfirmDeleteTitle => '삭제 확인';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return '로그 파일 ‘$fileName’을(를) 삭제하시겠습니까?';
  }

  @override
  String get appLogCancel => '취소';

  @override
  String appLogLoadFilesError(Object error) {
    return '로그 파일 목록을 불러오지 못했습니다: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return '로그 파일 ‘$fileName’이(가) 있지만 읽을 수 없습니다. 손상되었을 수 있습니다.';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return '로그 파일 ‘$fileName’을(를) 찾을 수 없습니다. 이미 정리되었을 수 있습니다.';
  }

  @override
  String appLogReadFileError(Object error) {
    return '로그 파일을 읽지 못했습니다: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return '삭제됨: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return '삭제 실패: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return '로그 파일 ‘$fileName’을(를) 찾을 수 없습니다';
  }

  @override
  String appLogPathCopied(String filePath) {
    return '경로 복사됨: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return '내보내기 실패: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '줄 $count개',
      one: '줄 $count개',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => '모두 복사';

  @override
  String get appLogStructuredView => '구조화된 보기';

  @override
  String get appLogRawView => '원시 보기';

  @override
  String appLogCopyError(Object error) {
    return '복사 실패: $error';
  }

  @override
  String get appLogCopyDone => '모든 로그 내용을 복사했습니다';

  @override
  String get iosContinuedTaskTitle => '백그라운드 작업';

  @override
  String get mermaidCatalogTypeFlowchart => '순서도';

  @override
  String get mermaidCatalogDescriptionFlowchart => '순서도 — 단계, 분기, 반복을 표시합니다';

  @override
  String get mermaidCatalogTypeSequenceDiagram => '시퀀스 다이어그램';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      '시퀀스 다이어그램 — 참여자 간 상호작용을 표시합니다';

  @override
  String get mermaidCatalogTypeClassDiagram => '클래스 다이어그램';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      '클래스 다이어그램 — 클래스 속성과 메서드 간 관계를 표시합니다';

  @override
  String get mermaidCatalogTypeStateDiagram => '상태 다이어그램';

  @override
  String get mermaidCatalogDescriptionStateDiagram => '상태 다이어그램 — 상태 전환을 표시합니다';

  @override
  String get mermaidCatalogTypeErDiagram => 'ER 다이어그램';

  @override
  String get mermaidCatalogDescriptionErDiagram => 'ER 다이어그램 — 엔터티 간 관계를 표시합니다';

  @override
  String get mermaidCatalogTypeGantt => '간트 차트';

  @override
  String get mermaidCatalogDescriptionGantt => '간트 차트 — 프로젝트 일정을 표시합니다';

  @override
  String get mermaidCatalogTypePie => '원형 차트';

  @override
  String get mermaidCatalogDescriptionPie => '원형 차트 — 비율 데이터를 표시합니다';

  @override
  String get mermaidCatalogTypeJourney => '사용자 여정';

  @override
  String get mermaidCatalogDescriptionJourney => '사용자 여정 — 사용자 경험의 흐름을 표시합니다';

  @override
  String get mermaidCatalogTypeGitGraph => 'Git 그래프';

  @override
  String get mermaidCatalogDescriptionGitGraph => 'Git 그래프 — 브랜치와 커밋을 표시합니다';

  @override
  String get mermaidCatalogTypeMindmap => '마인드맵';

  @override
  String get mermaidCatalogDescriptionMindmap => '마인드맵 — 계층 구조를 표시합니다';

  @override
  String get mermaidCatalogTypeTimeline => '타임라인';

  @override
  String get mermaidCatalogDescriptionTimeline => '타임라인 — 시간순으로 이벤트를 표시합니다';

  @override
  String get mermaidCatalogTypeBlock => '블록 다이어그램';

  @override
  String get mermaidCatalogDescriptionBlock => '블록 다이어그램 — 블록 배치와 관계를 표시합니다';

  @override
  String get mermaidCatalogTypeRequirement => '요구사항 다이어그램';

  @override
  String get mermaidCatalogDescriptionRequirement =>
      '요구사항 다이어그램 — 요구사항과 구현 간 관계를 표시합니다';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[시작]\n  B[처리 단계]\n  C<MERMAID_OPEN_BRACE>조건<MERMAID_CLOSE_BRACE>\n  D[종료]\n\n  A --> B\n  B --> C\n  C -->|예| D\n  C -->|아니요| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"사용자\" as user\n  participant \"시스템\" as system\n  participant \"데이터베이스\" as database\n\n  user->>system: 요청 전송\n  system->>database: 데이터 조회\n  database-->>system: 결과 반환\n  system-->>user: 결과 표시';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String 이름\n    +int 나이\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String 학생ID\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String 교사ID\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"대기 중\" as pending\n  state \"처리 중\" as processing\n  state \"완료\" as completed\n  state \"실패\" as failed\n  [*] --> pending\n  pending --> processing\n  processing --> completed\n  processing --> failed\n  failed --> pending\n  completed --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : 주문\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : 포함\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : 구성\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title 프로젝트 간트 차트\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section 요구사항\n  요구사항 분석      :a1, 2024-01-01, 14d\n  프로토타입 설계    :a2, after a1, 10d\n\n  section 개발\n  프런트엔드 개발   :b1, after a2, 20d\n  백엔드 개발       :b2, after a2, 20d\n  API 통합          :b3, after b1, 7d\n\n  section 테스트\n  기능 테스트       :c1, after b3, 10d\n  배포              :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title 데이터 분포\n  \"범주 A\" : 40\n  \"범주 B\" : 25\n  \"범주 C\" : 20\n  \"범주 D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title 사용자 등록\n  section 가입\n    가입 페이지 열기: 5: 사용자\n    정보 입력: 3: 사용자\n    요청 제출: 4: 사용자\n  section 확인\n    코드 받기: 3: 시스템\n    코드 입력: 4: 사용자\n    확인 완료: 5: 시스템, 사용자';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"초기 커밋\"\n  commit id: \"기능 A 추가\"\n  branch develop\n  checkout develop\n  commit id: \"새 기능 개발\"\n  commit id: \"버그 수정\"\n  checkout main\n  merge develop\n  commit id: \"v1.0 출시\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((프로젝트 관리))\n    요구사항\n      기능\n      비기능\n    개발\n      프런트엔드\n      백엔드\n    테스트\n      단위 테스트\n      통합 테스트\n    배포\n      테스트 환경\n      운영 환경';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title 프로젝트 주요 일정\n  2024-Q1 : 요구사항 조사 : 계획 확정\n  2024-Q2 : 개발 : 기능 구현\n  2024-Q3 : 테스트 : 버그 수정 : 성능 조정\n  2024-Q4 : 배포 : 운영 및 유지보수';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"요구사항\"] B[\"개발\"] C[\"테스트\"]\n  D[\"배포\"] E[\"운영\"] F[\"모니터링\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement 사용자 로그인 <MERMAID_OPEN_BRACE>\n    id: 1\n    text: 사용자는 계정과 비밀번호로 로그인할 수 있습니다\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element 로그인 페이지 <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element 인증 서비스 <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  로그인 페이지 - satisfies -> 사용자 로그인\n  인증 서비스 - verifies -> 사용자 로그인';

  @override
  String get mermaidCatalogDefaultFileName => '내 차트';

  @override
  String get mermaidCatalogActionAddNode => '노드 추가';

  @override
  String get mermaidCatalogActionAddDecision => '분기 추가';

  @override
  String get mermaidCatalogActionAddEdge => '연결선 추가';

  @override
  String get mermaidCatalogActionAddSubgraph => '하위 그래프 추가';

  @override
  String get mermaidCatalogActionAddParticipant => '참여자 추가';

  @override
  String get mermaidCatalogActionAddRequest => '요청 추가';

  @override
  String get mermaidCatalogActionAddResponse => '응답 추가';

  @override
  String get mermaidCatalogActionAddNote => '메모 추가';

  @override
  String get mermaidCatalogActionAddClass => '클래스 추가';

  @override
  String get mermaidCatalogActionAddInheritance => '상속 추가';

  @override
  String get mermaidCatalogActionAddRelationship => '관계 추가';

  @override
  String get mermaidCatalogActionAddAggregation => '집합 관계 추가';

  @override
  String get mermaidCatalogActionAddState => '상태 추가';

  @override
  String get mermaidCatalogActionAddTransition => '전환 추가';

  @override
  String get mermaidCatalogActionAddStart => '시작 추가';

  @override
  String get mermaidCatalogActionAddEnd => '종료 추가';

  @override
  String get mermaidCatalogActionAddEntity => '엔터티 추가';

  @override
  String get mermaidCatalogActionAddOneToMany => '일대다 관계 추가';

  @override
  String get mermaidCatalogActionAddManyToMany => '다대다 관계 추가';

  @override
  String get mermaidCatalogActionAddOneToOne => '일대일 관계 추가';

  @override
  String get mermaidCatalogActionAddPhase => '단계 추가';

  @override
  String get mermaidCatalogActionAddTask => '작업 추가';

  @override
  String get mermaidCatalogActionAddDependentTask => '후속 작업 추가';

  @override
  String get mermaidCatalogActionAddMilestone => '마일스톤 추가';

  @override
  String get mermaidCatalogActionAddCategory => '범주 추가';

  @override
  String get mermaidCatalogActionAddTitle => '제목 추가';

  @override
  String get mermaidCatalogActionAddSystemTask => '시스템 작업 추가';

  @override
  String get mermaidCatalogActionAddMultiPersonTask => '다인 작업 추가';

  @override
  String get mermaidCatalogActionAddCommit => '커밋 추가';

  @override
  String get mermaidCatalogActionCreateBranch => '브랜치 만들기';

  @override
  String get mermaidCatalogActionSwitchBranch => '브랜치 전환';

  @override
  String get mermaidCatalogActionMergeBranch => '브랜치 병합';

  @override
  String get mermaidCatalogActionAddBranch => '브랜치 추가';

  @override
  String get mermaidCatalogActionAddChildBranch => '하위 브랜치 추가';

  @override
  String get mermaidCatalogActionAddTopic => '주제 추가';

  @override
  String get mermaidCatalogActionAddPeriod => '기간 추가';

  @override
  String get mermaidCatalogActionAddBlock => '블록 추가';

  @override
  String get mermaidCatalogActionAddColumns => '열 추가';

  @override
  String get mermaidCatalogActionAddConnection => '연결 추가';

  @override
  String get mermaidCatalogActionAddChildBlock => '하위 블록 추가';

  @override
  String get mermaidCatalogActionAddRequirement => '요구사항 추가';

  @override
  String get mermaidCatalogActionAddElement => '요소 추가';

  @override
  String get mermaidCatalogActionAddVerification => '검증 방법 추가';

  @override
  String get mermaidCatalogGanttDependencyBaseTask => '선행 작업';

  @override
  String get mermaidCatalogGanttDependentTaskName => '후속 작업';

  @override
  String get startupMigrationTitle => '데이터 형식 업그레이드 완료';

  @override
  String get startupMigrationBody =>
      '데이터를 새 형식으로 마이그레이션했습니다. 업데이트된 버전을 사용하려면 앱을 다시 시작하세요.';

  @override
  String get startupMigrationExit => '앱 종료';

  @override
  String get startupMigrationRestart => '지금 다시 시작';

  @override
  String get startupRecoveryTitle => '앱 시작 오류';

  @override
  String get startupRecoveryFallbackMessage =>
      '시작 중 데이터 형식 문제가 발생해 자동으로 복구했습니다. 다시 시도하세요.';

  @override
  String get startupRecoveryRetry => '다시 시도';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return 'ASR $category $stage 단계$chunk: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return ', 청크 $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return '요청 실패: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return '청크 음성 받아쓰기 실패($count개 청크 중 성공 없음)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return '청크 음성 받아쓰기 미완료($count개 중 $succeeded개 성공)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return '성공: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return '실패: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return '결과 불확실: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return '청크 $index($start~$end초) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return '청크 상태 저장 실패: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      '요청 결과를 확인할 수 없습니다. 중복 제출을 방지하기 위해 다시 시도를 중지했습니다. 새 작업을 만들려면 오디오를 다시 선택하세요.';

  @override
  String asrRetryAudioLost(Object audioName) {
    return '원본 오디오 파일이 없어졌습니다. 다시 시도하려면 오디오를 다시 선택하세요: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return '원본 오디오 파일이 손상되었습니다. 다시 시도하려면 오디오를 다시 선택하세요: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return ', 청크 $index';
  }

  @override
  String get asrChunkDetailsSeparator => '; ';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'ASR 인식 실패: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => '인증';

  @override
  String get asrFailureCategoryRateLimit => '요청 한도';

  @override
  String get asrFailureCategorySizeLimit => '크기 제한';

  @override
  String get asrFailureCategoryNetwork => '네트워크';

  @override
  String get asrFailureCategoryResponseParsing => '응답 구문 분석';

  @override
  String get asrFailureCategoryLocalProcessing => '로컬 처리';

  @override
  String get asrFailureCategoryProvider => '제공업체';

  @override
  String get asrFailureCategoryUnknown => '알 수 없음';

  @override
  String get asrFailureStagePreprocessing => '전처리';

  @override
  String get asrFailureStageEncoding => '인코딩';

  @override
  String get asrFailureStageValidation => '검증';

  @override
  String get asrFailureStageRequest => '요청';

  @override
  String get asrFailureStageUploading => '업로드';

  @override
  String get asrFailureStageWaiting => '대기';

  @override
  String get asrFailureStageReceiving => '수신';

  @override
  String get asrFailureStageResponse => '응답';

  @override
  String get asrFailureStageParsing => '구문 분석';

  @override
  String get asrFailureStageStorage => '저장';

  @override
  String get chatMissingProvider => '먼저 채팅 제공업체를 구성하세요';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Anthropic API 오류: $detail';
  }

  @override
  String get anthropicStreamUnknownError => '알 수 없는 오류';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'API 요청 실패(HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing => 'API 키가 설정되지 않아 파일을 업로드할 수 없습니다';

  @override
  String get fileUploadApiUrlMissing => 'API URL이 설정되지 않아 파일을 업로드할 수 없습니다';

  @override
  String get fileUploadContentEmpty => '파일 내용이 비어 있습니다';

  @override
  String get fileUploadFilenameEmpty => '파일 이름이 비어 있습니다';

  @override
  String get fileUploadMimeTypeEmpty => 'MIME 유형이 비어 있습니다';

  @override
  String get fileUploadPurposeEmpty => '업로드 목적이 비어 있습니다';

  @override
  String get fileUploadCanceled => '파일 업로드가 취소되었습니다';

  @override
  String get fileUploadCreateMissingId => '업로드를 만들지 못했습니다: 응답에 업로드 ID가 없습니다';

  @override
  String get fileUploadPartMissingId => '파일 일부를 업로드하지 못했습니다: 응답에 일부 ID가 없습니다';

  @override
  String get fileUploadCompleteMissingFile =>
      '업로드를 완료하지 못했습니다: 응답에 파일 객체가 없습니다';

  @override
  String get fileUploadMissingFileId => '파일을 업로드하지 못했습니다: 응답에 파일 ID가 없습니다';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return '파일 업로드 요청 실패(HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return '파일 업로드 요청 실패: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'API 키가 설정되지 않았습니다';

  @override
  String chatStreamError(Object detail) {
    return 'API 스트림 오류: $detail';
  }

  @override
  String get chatChoicesMissing => 'API 응답에 선택 항목이 없습니다';

  @override
  String get chatContentBlocksMissing => 'API 응답에 콘텐츠 블록이 없습니다';

  @override
  String get chatResponseContentEmpty => 'API 응답 내용이 비어 있습니다';

  @override
  String chatRequestFailed(Object detail) {
    return '요청 실패: $detail';
  }

  @override
  String get startupTagline => '학습 도우미';

  @override
  String get startupProgressDataSafety => '데이터 안전 확인 중...';

  @override
  String get startupProgressFormatVersion => '데이터 형식 버전 확인 중...';

  @override
  String get startupProgressDataFormat => '데이터 형식 검증 중...';

  @override
  String get startupProgressDataIntegrity => '데이터 무결성 확인 중...';

  @override
  String get startupProgressResults => '검사 결과 처리 중...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return '시작 완료(참고: $warning)';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      '데이터 검사를 마쳤습니다. 앱을 시작할 준비 중입니다.';

  @override
  String get startupProgressReady => '앱을 시작할 준비 중입니다.';

  @override
  String startupWarningErrorCount(Object count) {
    return '데이터 문제 $count개 발견:';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return '경고 $count개:';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      '제공업체 항목 형식이 올바르지 않습니다. JSON 배열이어야 합니다.';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return '제공업체 항목 $index이(가) null이거나 유형이 올바르지 않습니다.';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return '제공업체 항목 $index에 ID가 없거나 ID가 비어 있습니다.';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return '제공업체 항목 $index에 유형이 없거나 유형이 비어 있습니다.';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return '제공업체 항목 $index에 이름이 없거나 이름이 비어 있습니다.';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return '제공업체 항목 $index의 $field 필드가 올바른 목록이 아닙니다.';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return '제공업체 항목 $index의 $field에 구문 분석 실패를 일으킬 수 있는 잘못된 항목이 있습니다.';
  }

  @override
  String get startupIssueConversationsInvalid =>
      '대화 형식이 올바르지 않습니다. JSON 배열이어야 합니다.';

  @override
  String startupIssueConversationInvalid(Object index) {
    return '대화 $index이(가) null이거나 유형이 올바르지 않습니다.';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return '대화 $index에 ID가 없습니다.';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return '대화 $index에 메시지 필드가 없습니다.';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return '대화 $index의 메시지 필드가 올바른 목록이 아닙니다.';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return '제공업체 항목 $index에서 알 수 없는 제공업체 유형 ‘$type’을(를) 사용합니다. 올바르게 작동하지 않을 수 있습니다.';
  }

  @override
  String get startupErrorTitle => '앱 시작 실패';

  @override
  String startupErrorDetails(Object error) {
    return '오류: $error';
  }

  @override
  String get renderErrorTitle => '인터페이스 렌더링 오류';

  @override
  String get renderErrorDebugTitle => '인터페이스 렌더링 오류(디버그 모드)';

  @override
  String get renderErrorRestartMessage => '앱을 다시 시작해 보세요.';

  @override
  String get batchDlgFileName => '파일 이름';

  @override
  String get batchDlgFolderName => '폴더 이름';

  @override
  String get batchDlgFileNameConflict => '이 폴더에 같은 이름의 파일이 이미 있습니다';

  @override
  String get batchDlgFolderNameConflict => '대상 위치에 같은 이름의 폴더가 이미 있습니다';

  @override
  String get batchDlgFolderNameSwapConflict => '같은 일괄 작업에서 폴더 이름을 서로 바꿀 수 없습니다';

  @override
  String get batchDlgControlCharacterError => '이름에 제어 문자를 사용할 수 없습니다';

  @override
  String get batchDlgNameWhitespaceError =>
      '이름 앞뒤에 공백을 넣을 수 없습니다. 공백 정리 규칙을 사용하세요';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind은(는) 비워 둘 수 없습니다';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind 끝에 공백을 넣을 수 없습니다';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind은(는) $count자를 초과할 수 없습니다';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind에 Windows에서 허용하지 않는 문자를 사용할 수 없습니다';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind 끝에 마침표를 넣을 수 없습니다';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind에 Windows 예약 이름을 사용할 수 없습니다';
  }

  @override
  String get batchDlgIntermediateNameTooLong => '중간 이름이 너무 깁니다. 규칙을 조정하세요';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return '이 항목에는 $date 날짜가 없습니다. 템플릿을 조정하세요';
  }

  @override
  String get batchDlgCreatedDate => '생성';

  @override
  String get batchDlgModifiedDate => '수정';

  @override
  String get connectivityTestHttpSuccess => 'HTTP 도구 요청 성공';

  @override
  String get connectivityTestHttpFailure => 'HTTP 도구 요청 실패';

  @override
  String get connectivityTestInvalidMcpConfig => 'MCP 구성이 올바르지 않습니다';

  @override
  String get connectivityTestMissingTransport => '유효한 전송 유형 구성이 필요합니다.';

  @override
  String get connectivityTestStdioUnsupported => '이 플랫폼에서는 stdio를 지원하지 않습니다';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP는 로컬 프로세스를 시작해야 합니다. Stroom 데스크톱 앱에서 테스트하세요.';

  @override
  String get connectivityTestInvalidContent => '테스트 내용이 올바르지 않습니다';

  @override
  String get connectivityTestMethodMustBeString => 'method는 문자열이어야 합니다.';

  @override
  String get connectivityTestUnsupportedMethod => '지원하지 않는 테스트 메서드';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      '원격 업무 데이터에 기록하지 않도록 MCP 연결 테스트에서는 읽기 전용 tools/list 메서드만 허용합니다.';

  @override
  String get connectivityTestParamsMustBeObject => 'params는 JSON 객체여야 합니다.';

  @override
  String get connectivityTestMcpConnectionFailed => 'MCP 서비스에 연결할 수 없습니다';

  @override
  String get connectivityTestCheckConnectionSettings =>
      '주소, 인증, 네트워크를 확인하거나 앱 로그에서 연결 세부정보를 확인하세요.';

  @override
  String get connectivityTestRemainingToolsOmitted => '; 나머지 도구는 생략됨';

  @override
  String get connectivityTestMcpSuccess => 'MCP 연결 테스트 성공';

  @override
  String connectivityTestToolNames(Object names) {
    return ': $names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return '연결 및 tools/list 요청 성공. 도구 $count개를 찾았습니다$names$suffix.';
  }

  @override
  String get connectivityTestTodoMutationBlocked =>
      '테스트 매개변수가 todo 데이터를 수정하려고 합니다';

  @override
  String get connectivityTestTodoReadOnly =>
      '현재 세션의 todo 목록을 보호하려면 연결 테스트에서 todos를 생략하거나 null로 설정하세요.';

  @override
  String get connectivityTestUnknownBuiltin => '알 수 없는 기본 제공 도구';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return '도구 ‘$toolName’의 테스트 실행기를 찾을 수 없습니다.';
  }

  @override
  String get connectivityTestBuiltinSuccess => '기본 제공 도구 테스트 성공';

  @override
  String get connectivityTestBuiltinFailure => '기본 제공 도구 테스트 실패';

  @override
  String get connectivityTestTopLevelObjectRequired =>
      '테스트 내용은 최상위 JSON 객체여야 합니다.';

  @override
  String get connectivityTestRequestTimeout =>
      '요청 시간이 초과되었습니다. 서비스 응답과 네트워크를 확인하세요.';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'MCP 요청 시간 초과: $method';
  }

  @override
  String get connectivityTestResultTruncated => '… (결과 잘림)';

  @override
  String get toolResultWebSearchEmptyQuery => '오류: 검색어를 입력해야 합니다.';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return '오류: 지원하지 않는 검색 엔진 ‘$source’입니다. 지원 값: google, bing, baidu.';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return '기본 엔진 $preferred $reason; $fallback(으)로 전환했습니다.';
  }

  @override
  String get toolResultWebSearchNotFound => '관련 검색 결과를 찾을 수 없습니다.';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return '관련 검색 결과를 찾을 수 없습니다($sources에서 결과가 없다고 명시적으로 응답함).';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return '검색 미완료: $sources에서 결과가 없다고 명시적으로 응답했습니다. 다른 엔진은 사용할 수 없거나 구문 분석할 수 없는 페이지를 반환했습니다: $failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return '오류: 모든 검색 엔진을 사용할 수 없습니다. $failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return '$source의 검색 결과:';
  }

  @override
  String get toolResultWebSearchLinkLabel => '링크';

  @override
  String get toolResultWebSearchSummaryLabel => '요약';

  @override
  String get toolResultWebSearchEmptyResults => '관련 검색 결과를 찾을 수 없습니다.';

  @override
  String get toolResultTodoInvalid =>
      '오류: todos 매개변수는 배열이어야 합니다(todo 목록을 읽으려면 생략하거나 null을 전달하세요).';

  @override
  String get toolResultTodoEmpty => '아직 todo 항목이 없습니다.';

  @override
  String toolResultTodoCount(Object count) {
    return '활성 todo 항목: $count';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return '오류: MCP 서버 ‘$server’에 다시 연결할 수 없습니다.';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return '오류: MCP 서버 ‘$server’를 현재 사용할 수 없습니다.';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return '오류: MCP 서버 ‘$server’에 연결하지 못했거나 도구가 없습니다. 서버 구성을 확인하세요.';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return '실제 도구 ‘$tool’은(는) 이 서버에서 호출 이름 ‘$alias’로 공개되어 있습니다.';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return '여러 MCP 서버에서 도구 ‘$tool’을(를) 제공합니다. 일치하는 호출 이름을 사용하세요: $routes.';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return '오류: 실제 도구 ‘$tool’의 이름이 충돌합니다. 위에 나열된 호출 이름 중 하나를 사용하세요.';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return '오류: MCP 서버 ‘$server’에 ‘$tool’ 도구가 없습니다.';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return '이 서버에서 사용할 수 있는 도구: $tools. 대신 이 이름을 사용하세요.';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return '오류: MCP 도구 ‘$tool’의 별칭이 현재 충돌합니다. 일치하는 호출 이름을 사용하세요: $routes.';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return '오류: 도구 ‘$tool’이(가) 비활성화되어 있습니다.';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return '오류: 알 수 없는 도구 ‘$tool’';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => '결과를 반환하지 않음';

  @override
  String get toolResultWebSearchFallbackUnavailable => '일시적으로 사용할 수 없음';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '(MCP 서버 $server)';
  }

  @override
  String get toolResultWebSearchUnparsedResults => '구문 분석할 수 없는 페이지를 반환함';

  @override
  String get toolResultSearchTitleLabel => '제목';

  @override
  String get toolResultSearchContentLabel => '내용';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return '오류: $provider API 키가 설정되지 않았습니다. 설정에서 구성하세요.';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return '오류: $provider 인스턴스 URL이 설정되지 않았습니다. 설정에서 구성하세요.';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return '오류: $provider 요청 실패(HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return '오류: $provider 요청 실패: $detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return '오류: 알 수 없는 HTTP 도구 ‘$provider’';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return '오류: MCP 서버 ‘$server’에 연결되어 있지 않습니다.';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return '오류: MCP 도구 ‘$tool’에서 응답이 없습니다.';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return '오류: $detail';
  }

  @override
  String get httpToolBraveDescription =>
      'Brave Search API로 웹을 검색합니다. API 키가 필요합니다.';

  @override
  String get httpToolBochaDescription =>
      'Bocha AI Search API로 웹을 검색합니다. API 키가 필요합니다.';

  @override
  String get httpToolQueritDescription =>
      'Querit Search로 웹을 검색합니다. API 키가 필요합니다.';

  @override
  String get httpToolSearxngDescription =>
      '여러 검색 소스를 통합하는 개인정보 보호 중심의 자체 호스팅 메타 검색 엔진입니다. 인스턴스 URL이 필요합니다.';

  @override
  String get httpToolSearchQueryDescription => '검색어입니다.';

  @override
  String get httpToolSearchCountDescription => '반환할 결과 수입니다.';

  @override
  String get httpToolSearchCountMax20Description => '반환할 결과 수(최대 20개)입니다.';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return '덱 $decks개, 노트 $notes개, 카드 $cards개 가져옴';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '선택한 .apkg 파일을 찾을 수 없습니다: $path';
  }

  @override
  String get backupRestoreApkgInvalidArchive =>
      '선택한 .apkg 파일이 손상되었거나 올바른 아카이브가 아닙니다.';

  @override
  String get backupRestoreApkgCollectionMissing =>
      '.apkg 파일에 collection.anki2가 없습니다.';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return '덱을 가져오거나 내보내려면 Anki 플래시카드를 먼저 여세요: $path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt => 'Anki 컬렉션 데이터베이스가 손상되었습니다.';

  @override
  String backupRestoreApkgLocalFileFailure(String path) {
    return '로컬 Anki 파일에 액세스할 수 없습니다: $path';
  }

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return '이 경로의 파일에 액세스하는 동안 .apkg 작업 실패: $path';
  }

  @override
  String get backupRestoreApkgOperationFailed =>
      '파일 또는 데이터베이스를 읽을 수 없어 .apkg 작업에 실패했습니다.';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return '이 데이터베이스에서 Anki 덱을 패키징할 수 없습니다: $path';
  }

  @override
  String get ankiSyncStatusProtocolFailed =>
      '동기화 서버 응답이 올바르지 않거나 불완전합니다. 서버가 Anki 동기화 v10을 지원하는지 확인하세요.';

  @override
  String get ankiSyncStatusLoginRequired => '계속하려면 Anki 동기화에 로그인하세요.';

  @override
  String get ankiSyncStatusInvalidServerUrl =>
      '유효한 HTTP 또는 HTTPS 동기화 서버 주소를 입력하세요.';

  @override
  String get ankiSyncStatusHttpsRequired =>
      '원격 자체 호스팅 동기화 서버에는 HTTPS를 사용해야 합니다.';

  @override
  String get ankiSyncStatusConnectionTimeout =>
      '동기화 요청 시간이 초과되었습니다. 서버 주소와 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get ankiSyncStatusTlsFailure =>
      '서버 인증서를 확인할 수 없습니다. 인증서를 확인하거나 사용자 지정 CA를 구성하세요.';

  @override
  String get ankiSyncStatusConnectionFailure =>
      '동기화 서버에 연결할 수 없습니다. 주소와 네트워크를 확인하세요.';

  @override
  String get ankiSyncStatusRequestFailure =>
      '동기화 요청에 실패했습니다. 서버와 네트워크를 확인한 후 다시 시도하세요.';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return '동기화 서버가 HTTP $statusCode를 반환했습니다.';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return '동기화 응답이 ${limitMb}MB 제한을 초과했습니다.';
  }

  @override
  String get ankiSyncStatusLocalFileFailure =>
      '로컬 동기화 파일을 읽거나 정리할 수 없습니다. 디스크 액세스를 확인하고 다시 시도하세요.';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      '컬렉션을 열거나 업데이트하지 못했거나 SQLite/스키마 검증에 실패했습니다. 유효한 컬렉션을 복원하거나 다시 다운로드하세요.';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return '동기화 서버가 요청을 거부했습니다(HTTP $statusCode). 로그인 정보와 서버 권한을 확인하세요.';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return '동기화 엔드포인트를 찾을 수 없습니다(HTTP $statusCode). 서버 주소를 확인하세요.';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      '미디어 동기화 서버 응답이 올바르지 않습니다. Anki 미디어 동기화를 지원하는지 확인한 후 다시 시도하세요.';

  @override
  String get ankiSyncStatusMediaIndexCorrupt =>
      '로컬 미디어 동기화 인덱스가 손상되었습니다. 미디어 동기화 데이터를 초기화하고 다시 시도하세요.';

  @override
  String get ankiSyncStatusMediaIndexFailure =>
      '로컬 미디어 동기화 인덱스를 읽거나 업데이트할 수 없습니다.';

  @override
  String get ankiSyncStatusMediaChecksumMismatch =>
      '다운로드한 미디어 파일의 체크섬 검증에 실패했습니다. 미디어 동기화를 다시 시도하세요.';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return '미디어 파일 ‘$filename’의 로컬 변경사항과 서버 변경사항이 충돌합니다. 백업한 뒤 파일 이름 충돌을 해결하고 다시 시도하세요.';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return '미디어 파일 이름 ‘$filename’을(를) 동기화할 수 없습니다. Anki에서 사용할 수 있는 파일 이름으로 바꾼 뒤 다시 시도하세요.';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return '미디어 파일이 비어 있거나 ${limitMb}MB 제한을 초과했습니다.';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return '미디어 아카이브에 항목이 $count개 있습니다. 매니페스트를 포함한 최대 항목 수는 $limit개입니다.';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed =>
      '미디어 동기화 검증에 실패했습니다. 동기화를 다시 시도하세요.';

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      '웹에서 동기화하려면 AnkiWeb에 로그인하세요. 클라우드 아이콘으로 Anki 설정을 열고 로그인할 수 있습니다.';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      '웹에서 덱을 둘러보거나 관리하려면 클라우드 아이콘을 사용해 AnkiWeb에 로그인하세요.';

  @override
  String get ankiStatsUnsupportedPlatform => '이 플랫폼에서는 Anki 통계를 사용할 수 없습니다.';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      '기기 시계와 동기화 서버의 시간이 5분 넘게 차이 납니다. 시계를 맞춘 뒤 다시 시도하세요.';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      '동기화 무결성 검사에 실패해 로컬 변경사항을 되돌렸습니다. 서버 컬렉션 전체를 다운로드한 뒤 다시 시도하세요.';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      '이 컬렉션은 증분 동기화를 지원하지 않습니다. 계속하려면 전체 업로드 또는 다운로드를 선택하세요.';

  @override
  String get ankiSyncStatusIncrementalSyncFailed =>
      '증분 동기화를 완료하지 못했습니다. 서버와 연결을 확인한 후 다시 시도하세요.';

  @override
  String get emojiCategorySmileys => '스마일리';

  @override
  String get emojiCategoryPeople => '사람';

  @override
  String get emojiCategoryAnimals => '동물';

  @override
  String get emojiCategoryFood => '음식';

  @override
  String get emojiCategoryActivities => '활동';

  @override
  String get emojiCategoryTravel => '여행';

  @override
  String get emojiCategoryObjects => '사물';

  @override
  String get emojiCategorySymbols => '기호';

  @override
  String get emojiCategoryFlags => '깃발';

  @override
  String get languageNameSpanish => '스페인어';

  @override
  String get languageNameJapanese => '일본어';

  @override
  String get languageNameFrench => '프랑스어';

  @override
  String get languageNameGerman => '독일어';

  @override
  String get languageNameArabic => '아랍어';

  @override
  String fileManagerDeleteEmptyFolderWithSubfoldersConfirm(
    num count,
    Object name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개도 함께 삭제됩니다',
      one: '1개도 함께 삭제됩니다',
    );
    return '빈 폴더 ‘$name’을(를) 삭제하시겠습니까? 중첩 폴더 $_temp0.';
  }

  @override
  String get providerMaxUploadSizePositive => '최대 업로드 크기는 양수여야 합니다.';
}

/// The translations for Korean, as used in Republic of Korea (`ko_KR`).
class AppLocalizationsKoKr extends AppLocalizationsKo {
  AppLocalizationsKoKr() : super('ko_KR');

  @override
  String get galleryPermissionTitle => '사진 라이브러리 접근 권한 필요';

  @override
  String get galleryPermissionMessage =>
      '시스템 설정에서 Stroom이 사진과 동영상에 접근하도록 허용해 주세요.';

  @override
  String get galleryPermissionCancel => '취소';

  @override
  String get galleryPermissionOpenSettings => '설정 열기';

  @override
  String get languageSettingsTitle => '언어';

  @override
  String get followSystemLanguage => '시스템 설정 따르기';

  @override
  String get themeDisplaySettingsTitle => '테마 및 디스플레이';

  @override
  String get themeDisplayThemeSection => '테마';

  @override
  String get themeModeLight => '라이트 모드';

  @override
  String get themeModeDark => '다크 모드';

  @override
  String get themeModeSystem => '시스템 설정 따르기';

  @override
  String get languageNameEnglish => '영어';

  @override
  String get languageNameChinese => '중국어(간체)';

  @override
  String get languageNameKorean => '한국어';

  @override
  String get languageNamePortuguese => '포르투갈어 (브라질)';

  @override
  String get languageSearchHint => '언어 검색';

  @override
  String get languageNoMatches => '일치하는 언어가 없습니다';

  @override
  String get builtInPromptGeneralName => '일반 어시스턴트';

  @override
  String get builtInPromptGeneralDescription =>
      '일상적인 대화와 다양한 질문에 답하는 다목적 AI 어시스턴트입니다.';

  @override
  String get builtInPromptGeneralPrompt =>
      '도움이 되는 AI 어시스턴트입니다. 사용자가 사용하는 언어로 답변하세요. 간결하고 명확하며 논리적으로 정리해 답하세요. 확실하지 않은 내용은 솔직하게 모른다고 말하세요.';

  @override
  String get builtInPromptCodeExpertName => '코드 전문가';

  @override
  String get builtInPromptCodeExpertDescription =>
      '다양한 프로그래밍 언어와 기술 스택에 능숙한 숙련된 프로그래머입니다.';

  @override
  String get builtInPromptCodeExpertPrompt =>
      '다양한 프로그래밍 언어와 기술 스택에 능숙한 숙련된 소프트웨어 엔지니어입니다. 사용자의 질문에 따라 품질 높은 코드 예시, 기술 설명, 모범 사례를 제시하세요. 가독성, 성능, 보안을 우선하세요. 코드를 제공할 때는 언어를 표시하고 적절한 형식을 사용하세요. 시스템 설계 질문에는 아키텍처 관점에서 장단점을 분석하세요.';

  @override
  String get builtInPromptTranslationName => '번역 어시스턴트';

  @override
  String get builtInPromptTranslationDescription =>
      '다국어 번역과 현지화 조언을 제공하는 전문 번역가입니다.';

  @override
  String get builtInPromptTranslationPrompt =>
      '전문 번역가입니다. 다음을 수행하세요:\n1. 사용자가 제공한 내용을 문체와 어조를 유지해 정확하게 번역하세요.\n2. 특정 언어로 어떻게 말하는지 물으면 자연스러운 표현을 알려 주세요.\n3. 문화적 맥락에 맞는 현지화 조언을 제공하세요.\n4. 번역이 여러 가지로 가능하면 각각을 제시하고 차이를 설명하세요.\n먼저 출발어와 도착어를 확인하고, 둘 중 하나라도 불분명하면 사용자에게 물어보세요.';

  @override
  String get builtInPromptEnglishTeacherName => '영어 교사';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      '듣기, 말하기, 읽기, 쓰기 실력을 높여 주는 영어 학습 튜터입니다.';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      '숙련된 영어 교사입니다. 다음과 같이 사용자의 요구를 도와주세요:\n1. 문법 설명: 규칙을 명확히 설명하고 예문을 포함하세요.\n2. 어휘 학습: 단어의 용법, 연어, 의미 차이를 설명하세요.\n3. 글 다듬기: 영어 문장이 자연스럽게 들리도록 개선하세요.\n4. 회화 연습: 영어권 상황을 시뮬레이션하세요.\n5. 발음 안내: 발음 기호와 비슷한 소리로 발음을 설명하세요.\n사용자의 영어 수준에 맞춰 난이도를 조절하고, 설명을 보조할 때는 중국어를 사용하세요.';

  @override
  String get builtInPromptInterviewerName => '면접관';

  @override
  String get builtInPromptInterviewerDescription =>
      '기술 면접과 인성 면접을 연습하는 모의 면접관입니다.';

  @override
  String get builtInPromptInterviewerPrompt =>
      '전문 면접관입니다. 사용자가 목표로 하는 직무의 모의 면접을 진행하세요:\n1. 먼저 목표 직무와 업계를 파악하세요.\n2. 관련 기술, 인성, 시스템 설계 질문을 하세요.\n3. 사용자의 답변을 평가하고 개선점을 제안하세요.\n4. 예시 답변과 그 이유를 제시하세요.\n5. 현실적인 속도로 진행하세요. 한두 가지 질문을 한 뒤 사용자의 답변을 기다리세요.\n사용자가 면접 역량을 높일 수 있도록 전문적이고 친근하게 진행하세요.';

  @override
  String get builtInPromptWritingName => '글쓰기 어시스턴트';

  @override
  String get builtInPromptWritingDescription =>
      '다양한 장르와 창작 글쓰기를 돕는 글쓰기 및 편집 어시스턴트입니다.';

  @override
  String get builtInPromptWritingPrompt =>
      '전문 글쓰기 컨설턴트입니다. 사용자의 필요에 따라 다음을 제공하세요:\n1. 초안 작성: 논증문, 설명문, 서사문 등의 장르로 작성하세요.\n2. 편집: 문법, 어휘 선택, 논리, 구성, 표현을 개선하세요.\n3. 개요 작성: 글의 틀을 만들고 핵심 내용을 찾도록 도우세요.\n4. 창의적 아이디어: 영감과 가능한 관점을 제안하세요.\n5. 형식 지정: 대상 장르의 관례와 제출 요건을 따르세요.\n먼저 목적, 대상 독자, 원하는 문체를 파악한 뒤 초점을 맞춰 조언하세요.';

  @override
  String get builtInPromptCreativeThinkerName => '창의적 사고 파트너';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      '새로운 아이디어를 이끌어 내는 창의적 발상 및 브레인스토밍 파트너입니다.';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      '창의적 사고 파트너입니다. 다음을 수행하세요:\n1. 브레인스토밍: 주제를 중심으로 다양한 창의적 방향을 제안하세요.\n2. 개념 발전: 기존 아이디어를 심화하고 확장하세요.\n3. 분야 연결: 서로 다른 분야의 개념을 새로운 방식으로 결합하세요.\n4. 역발상: 관습적인 사고에 도전하고 색다른 관점을 제시하세요.\n5. 실현 가능성 검토: 구현상의 어려움과 잠재적 가치를 분석하세요.\n발산적 사고를 장려하되 적절한 시점에 논의를 정리하세요. 답변마다 세 가지에서 다섯 가지 방향을 제안하세요.';

  @override
  String get builtInPromptDataAnalystName => '데이터 분석가';

  @override
  String get builtInPromptDataAnalystDescription =>
      '데이터를 이해하고 모델링하며 시각화하도록 돕는 데이터 분석 전문가입니다.';

  @override
  String get builtInPromptDataAnalystPrompt =>
      '데이터 분석 전문가입니다. 사용자의 질문에 따라 다음을 제공하세요:\n1. 분석 방법: 적절한 통계 방법과 분석 프레임워크를 선택하세요.\n2. SQL/Python/R 코드: 데이터 처리와 분석을 위한 예제를 제시하세요.\n3. 시각화 조언: 적절한 차트 유형과 도구를 추천하세요.\n4. 해석: 분석 결과와 비즈니스상 의미를 설명하세요.\n5. 데이터 정리: 결측값, 이상치 및 기타 품질 문제를 처리하세요.\n먼저 분석 목표와 데이터 특성을 파악하세요. Python 생태계(pandas, numpy, matplotlib, seaborn)를 우선적으로 사용하세요.';

  @override
  String get builtInPromptRoleplayName => '역할극';

  @override
  String get builtInPromptRoleplayDescription => '여러 등장인물과 몰입감 있게 역할극을 진행합니다.';

  @override
  String get builtInPromptRoleplayPrompt =>
      '이제 역할극 모드입니다. 사용자가 지정한 인물을 연기하고 그 인물의 성격, 어조, 지식에 맞춰 대화하세요:\n1. 사용자가 “[캐릭터]를 연기해”라고 말하면 즉시 해당 인물로 전환하세요.\n2. 대화 내내 역할을 유지하세요.\n3. 인물의 말투와 지식을 설명에 맞추세요.\n4. 사용자는 “역할극을 종료해”라고 말해 역할극을 끝낼 수 있습니다.\n5. 인물에 어울리는 합리적인 허구의 세부 사항을 추가해도 됩니다.\n사용자가 인물을 지정할 때까지 기다리세요.';

  @override
  String get builtInPromptLifeAdvisorName => '생활 상담가';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      '정신 건강 지원과 일상 조언을 따뜻하고 사려 깊게 제공하는 경청자입니다.';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      '따뜻하고 사려 깊은 생활 상담가입니다. 다음을 수행하세요:\n1. 적극적으로 경청하고 사용자의 걱정과 감정적 필요를 이해하세요.\n2. 문제를 합리적으로 분석하고 여러 측면을 정리하도록 도우세요.\n3. 일상을 개선할 수 있는 구체적이고 실행 가능한 방법을 제안하세요.\n4. 이해와 격려, 긍정적인 지지를 전하세요.\n5. 필요할 때 전문가의 도움을 권하세요.\n기억하세요. 공인 정신 건강 상담사가 아닙니다. 심각한 정신 건강 위기에는 전문가의 도움을 받도록 권하세요. 선을 넘지 않으면서 공감하고, 사용자를 대신해 결정하지 말고 지원하세요.';

  @override
  String get builtInSystemTitleName => '제목 생성 어시스턴트';

  @override
  String get builtInSystemTitleDescription => '대화에서 짧은 제목을 자동으로 생성합니다.';

  @override
  String get builtInSystemTitlePrompt =>
      '제목 생성기입니다. 대화 제목 하나만 출력하고 다른 내용은 쓰지 마세요.\n\n규칙:\n- 한 줄로 쓰고 50자를 넘기지 마세요.\n- 설명하거나 따옴표를 사용하지 마세요.\n- 사용자의 메시지와 같은 언어를 사용하세요.\n- 제목에 web_search나 todowrite 같은 도구 이름을 넣지 마세요.\n\n예시:\n“운영 환경의 500 오류를 디버깅하는 방법을 알려주세요” → 운영 환경의 500 오류 디버깅\n“사용자 서비스를 리팩터링해 주세요” → 사용자 서비스 리팩터링\n“app.js는 왜 실패하나요?” → app.js 오류 원인 파악\n\n사용자의 메시지가 매우 짧거나 단순한 인사(예: “안녕하세요”, “하하”, “지금 있나요?”)라면 인사, 가벼운 대화, 간단한 확인처럼 어조나 의도를 반영하는 제목을 만드세요.';

  @override
  String get builtInSystemCompactionName => '대화 요약 어시스턴트';

  @override
  String get builtInSystemCompactionDescription =>
      '긴 대화를 구조화된 고정 요약으로 압축해 컨텍스트 공간을 확보합니다.';

  @override
  String get builtInSystemCompactionPrompt =>
      '고정 컨텍스트 요약 어시스턴트입니다. 긴 대화를 구조화된 요약으로 압축하세요.\n\n제공된 대화 기록만 요약하세요. 최근 메시지는 원문 그대로 보존될 수 있으므로 여전히 중요한 오래된 맥락에 집중하세요.\n\n프롬프트에 <previous-summary> 블록이 있으면 이를 현재 고정 요약으로 취급하세요. 여전히 유효한 내용은 유지하고, 오래된 내용은 제거하며, 새로운 사실을 반영하세요.\n\n다음 구조를 정확히 따르세요. 순서를 유지하고 비어 있는 경우에도 모든 섹션을 포함하세요:\n<template>\n## 목표\n- [사용자 목표를 한두 문장으로 작성]\n\n## 중요 정보\n- [제약/선호, 결정과 이유, 중요 사실/가정, 이어서 진행하는 데 필요한 정확한 맥락. 비어 있으면 (없음) 작성]\n\n## 작업 상태\n### 완료\n- [완료된 작업, 확인된 사실 또는 변경 사항. 비어 있으면 (없음) 작성]\n\n### 진행 중\n- [현재 진행 중인 작업, 부분 변경 또는 조사. 비어 있으면 (없음) 작성]\n\n### 차단됨\n- [장애 요인, 실패한 명령 또는 확인되지 않은 사항. 비어 있으면 (없음) 작성]\n\n## 다음 단계\n1. [다음에 수행할 구체적인 작업 또는 (없음)]\n2. [예정된 후속 작업 또는 (없음)]\n\n## 관련 파일\n- [관련 파일 또는 디렉터리 경로와 중요성. 비어 있으면 (없음) 작성]\n</template>\n\n규칙:\n- 빈 섹션도 포함해 모든 섹션을 작성하세요.\n- 문단 대신 간결한 글머리표를 사용하세요.\n- 정확한 파일 경로, 기호, 명령, 오류 메시지, URL, 식별자를 보존하세요.\n- 요약, 압축, 맥락 통합을 하고 있다고 언급하지 마세요.\n- 대화와 같은 언어를 사용하세요.';

  @override
  String get builtInPromptMarketTitle => '어시스턴트 마켓';

  @override
  String get builtInPromptClose => '닫기';

  @override
  String get builtInPromptImportHint =>
      '가져온 프롬프트는 자유롭게 편집할 수 있는 일반 어시스턴트가 됩니다.';

  @override
  String get builtInPromptView => '프롬프트 보기';

  @override
  String get builtInPromptAdd => '추가';

  @override
  String get builtInPromptDescriptionHeading => '설명';

  @override
  String get builtInPromptSystemPromptHeading => '시스템 프롬프트';

  @override
  String get builtInPromptAddAssistant => '어시스턴트 추가';

  @override
  String builtInPromptViewerTitle(Object name) {
    return '프롬프트 · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      '자동 제목 생성과 대화 요약에 사용할 별도의 모델과 프롬프트를 설정합니다. 기본적으로 현재 채팅 모델과 내장 프롬프트를 사용합니다.';

  @override
  String get systemAssistantTitleName => '제목 생성 어시스턴트';

  @override
  String get systemAssistantTitleDescription => '대화 제목을 자동으로 생성합니다';

  @override
  String get systemAssistantCompactionName => '대화 요약 어시스턴트';

  @override
  String get systemAssistantCompactionDescription => '대화를 고정 요약으로 압축합니다';

  @override
  String get systemAssistantFollowCurrentModel => '현재 채팅 모델 따르기';

  @override
  String get systemAssistantChooseModel => '모델 선택';

  @override
  String get systemAssistantResetPromptTitle => '기본 프롬프트로 재설정';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '“$taskTitle”의 내장 기본 프롬프트를 복원할까요? 현재 사용자 지정 프롬프트는 삭제됩니다.';
  }

  @override
  String get systemAssistantCancel => '취소';

  @override
  String get systemAssistantReset => '재설정';

  @override
  String get systemAssistantModelHeading => '모델';

  @override
  String get systemAssistantPromptHeading => '프롬프트';

  @override
  String get systemAssistantCustomPromptHint => '변경 사항은 사용자 지정 프롬프트로 사용됩니다';

  @override
  String get systemAssistantUsingCustomPrompt => '사용자 지정 프롬프트 사용 중';

  @override
  String get systemAssistantUsingDefaultPrompt => '기본 프롬프트 사용 중';

  @override
  String get systemAssistantSave => '저장';

  @override
  String get systemAssistantResetButton => '기본 프롬프트로 재설정';

  @override
  String get taskFlowPageTitle => '작업 흐름';

  @override
  String get taskFlowSampleTemplatesTooltip => '예시 템플릿';

  @override
  String get taskFlowEmptyState => '아직 작업 흐름이 없습니다. +를 눌러 만드세요.';

  @override
  String get taskFlowStartFromTemplate => '템플릿에서 시작';

  @override
  String get taskFlowChooseTemplate => '예시 템플릿 선택';

  @override
  String get taskFlowTemplateIntroduction =>
      '필요한 작업과 가장 비슷한 흐름을 선택하세요. 나중에 조정할 수 있습니다.';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 템플릿',
      one: '$count개 템플릿',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      '템플릿은 설정이 필요한 초안으로 열립니다. 저장하기 전에 모델과 어시스턴트를 선택하세요.';

  @override
  String get taskFlowTemplateRecordingName => '녹음 파일 받아쓰기 및 요약';

  @override
  String get taskFlowTemplateRecordingDescription => '녹음 선택 → 음성 인식 → 어시스턴트 요약';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'ASR 모델을 설정하고 요약을 담당할 어시스턴트를 선택하세요.';

  @override
  String get taskFlowTemplateImageTextName => '이미지 텍스트 인식 및 정리';

  @override
  String get taskFlowTemplateImageTextDescription =>
      '이미지 선택 → 텍스트 인식 → 어시스턴트 정리';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'OCR 모델을 설정하고 텍스트를 정리할 어시스턴트를 선택하세요.';

  @override
  String get taskFlowTemplateReadImageName => '이미지에서 텍스트 읽기';

  @override
  String get taskFlowTemplateReadImageDescription => '이미지 선택 → 텍스트 인식 → 음성 재생';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'OCR 및 음성 합성 모델을 설정한 다음 음성을 선택하세요.';

  @override
  String get taskFlowActions => '흐름 작업';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 블록',
      one: '$count개 블록',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'OCR';

  @override
  String get taskFlowBlockAsr => '음성 인식';

  @override
  String get taskFlowBlockAudioSeparation => '오디오 분리';

  @override
  String get taskFlowBlockCatCatch => '웹 리소스 다운로드';

  @override
  String get taskFlowBlockTts => '음성 합성';

  @override
  String get taskFlowBlockChat => '어시스턴트 채팅';

  @override
  String get taskFlowBlockCustom => '사용자 지정 블록';

  @override
  String get taskFlowEdit => '편집';

  @override
  String get taskFlowCopy => '복사';

  @override
  String get taskFlowCopied => '복사됨';

  @override
  String get taskFlowDelete => '삭제';

  @override
  String get taskFlowConfirmDelete => '삭제 확인';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return '작업 흐름 “$flowName”을(를) 삭제할까요?';
  }

  @override
  String get taskFlowUseTemplate => '사용';

  @override
  String get taskFlowOcrInputMissing => '이미지 파일을 찾을 수 없습니다. 이미지를 다시 선택하세요.';

  @override
  String get taskFlowOcrInputReadFailed =>
      '이미지 파일을 읽을 수 없습니다. 파일 접근 권한을 확인하고 다시 시도하세요.';

  @override
  String get taskFlowOcrModelUnavailable =>
      '사용 가능한 OCR 모델이 설정되지 않았습니다. 흐름 설정에서 OCR 제공업체와 모델을 선택하세요.';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'OCR 요청 크기 한도($size MiB)';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return '작업 흐름 이미지 입력 한도($size MiB)';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return '이미지가 $limit을(를) 초과합니다. 더 작은 이미지를 선택하고 다시 시도하세요.';
  }

  @override
  String get ocrTemplatePlainTextLabel => '일반 텍스트';

  @override
  String get ocrTemplatePlainTextContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기고 줄바꿈과 문단을 유지하세요. 설명이나 추론을 덧붙이지 말고 일반 텍스트만 반환하세요.';

  @override
  String get ocrTemplateMarkdownLabel => 'Markdown';

  @override
  String get ocrTemplateMarkdownContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기고 제목, 목록, 표를 보존하도록 Markdown을 사용하세요. 수식은 LaTeX로 표시하세요. 설명이나 추론을 덧붙이지 말고 옮긴 내용만 반환하세요.';

  @override
  String get ocrTemplateTableLabel => '표';

  @override
  String get ocrTemplateTableContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기세요. 표에서는 머리글, 행과 열의 관계, 빈 셀을 유지하고 Markdown 표로 출력하세요. 나머지 내용은 일반 텍스트로 작성하세요. 설명이나 추론을 덧붙이지 말고 옮긴 내용만 반환하세요.';

  @override
  String get ocrTemplateLatexLabel => 'LaTeX';

  @override
  String get ocrTemplateLatexContent =>
      '페이지에 보이는 모든 텍스트를 자연스러운 읽기 순서대로 옮기세요. 수식이 아닌 텍스트는 그대로 유지하고 수학 수식은 LaTeX로 표시하세요. 인라인 수식에는 \$...\$, 디스플레이 수식에는 \$\$...\$\$를 사용하세요. 설명이나 추론을 덧붙이지 말고 옮긴 내용만 반환하세요.';

  @override
  String get ocrDefaultImagesOnly => '기본값(이미지만 전송)';

  @override
  String get ocrDefaultSystemPrompt =>
      '이미지의 모든 텍스트를 원래 서식과 레이아웃을 유지해 추출하세요. 설명을 덧붙이지 말고 추출한 텍스트만 반환하세요.';

  @override
  String get ocrSavedInstructionSnapshot => '저장된 지침 스냅샷';

  @override
  String get ocrPageTitle => '이미지 텍스트 인식';

  @override
  String get ocrImageQualitySettings => '이미지 품질 설정';

  @override
  String get ocrImageQualityStandard => '표준 품질';

  @override
  String get ocrImageQualityStandardHint => '대부분의 경우에 적합한 작은 이미지';

  @override
  String get ocrImageQualityOriginal => '원본 / 고해상도';

  @override
  String get ocrImageQualityOriginalHint =>
      '더 많은 세부 정보를 유지합니다. 이미지와 요청 크기가 커집니다.';

  @override
  String get ocrReorderDone => '완료';

  @override
  String get ocrReorderAction => '순서 변경';

  @override
  String get ocrClearAction => '지우기';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return '이전 작업에서 모델 $modelId을(를) 사용했습니다. 제공업체와 모델을 다시 선택하세요.';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      '이전 재시도 기록의 모델 위치가 올바르지 않습니다. 모델을 다시 선택하세요.';

  @override
  String get ocrLegacyModelPositionConfirm =>
      '이전 재시도 기록에는 모델 위치만 저장되어 있습니다. 계속하기 전에 현재 모델을 확인하세요.';

  @override
  String get ocrModelUnavailable =>
      '원래 OCR 제공업체 또는 모델을 더 이상 사용할 수 없습니다. 다른 모델을 선택하세요.';

  @override
  String get ocrModelLabel => '모델';

  @override
  String get ocrConfigure => '설정';

  @override
  String get ocrSelectModel => '모델 선택';

  @override
  String get ocrInstructionLabel => '지침';

  @override
  String get ocrManageInstructions => '인식 지침 관리';

  @override
  String get ocrInstructionManageGuidance =>
      '이 지침은 모든 인식 모델에 적용됩니다. 선택한 지침이 없으면 이미지만 전송됩니다.';

  @override
  String get ocrInstructionManageEmpty => '아직 지침이 없습니다';

  @override
  String get ocrInstructionEditTooltip => '지침 편집';

  @override
  String get ocrInstructionDeleteTooltip => '지침 삭제';

  @override
  String get ocrInstructionAdd => '지침 추가';

  @override
  String get ocrInstructionEditorEditTitle => '지침 편집';

  @override
  String get ocrInstructionNameLabel => '지침 이름(선택 사항)';

  @override
  String get ocrInstructionContentLabel => '지침 내용';

  @override
  String get ocrBatchMode => '일괄 처리 모드';

  @override
  String get ocrMergeRecognition => '결과 합치기';

  @override
  String get ocrRecognizeEachImage => '이미지를 각각 인식';

  @override
  String get ocrMaxConcurrency => '최대 동시 요청 2개';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동시 요청 $count개',
      one: '동시 요청 $count개',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동시 요청 $count개',
      one: '동시 요청 $count개',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint =>
      '완료된 페이지는 유지됩니다. 재시도하면 미완료 페이지에만 요청을 보냅니다.';

  @override
  String get ocrTakePhoto => '사진 촬영';

  @override
  String get ocrChooseFromAlbum => '앨범에서 선택';

  @override
  String get ocrNoImagesSelected => '선택한 이미지가 없습니다';

  @override
  String get ocrSelectImagesHint => '사진을 찍거나 앨범에서 여러 이미지를 선택해 인식하세요.';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '재시도하기 전에 이미지 $_temp0를 모두 다시 선택하세요.';
  }

  @override
  String ocrImageLabel(Object index) {
    return '이미지 $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return '이미지_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => '잘못된 이미지 인덱스';

  @override
  String get ocrViewErrorDetails => '오류 세부 정보 보기';

  @override
  String get ocrConfirmModel => '이 모델 확인';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미지 $count개 선택됨',
      one: '이미지 $count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => '이미지 준비 중…';

  @override
  String get ocrSavingRetryImages => '재시도 이미지 저장 중…';

  @override
  String get ocrRecognizing => '인식 중…';

  @override
  String get ocrReadingRetryImages => '재시도 이미지 읽는 중…';

  @override
  String get ocrImportingImages => '이미지 가져오는 중…';

  @override
  String get ocrStartRecognition => '인식 시작';

  @override
  String get ocrSaveTo => '저장 위치';

  @override
  String get ocrRootDirectory => '루트 디렉터리';

  @override
  String get ocrChooseSaveFolder => '저장할 폴더 선택';

  @override
  String get ocrChooseImageSource => '이미지 소스 선택';

  @override
  String get ocrChooseAppAlbum => '앱 앨범에서 선택';

  @override
  String get ocrAppAlbumDescription => '앱에 이미 저장된 이미지 선택';

  @override
  String get ocrChooseSystemAlbum => '시스템 앨범에서 선택';

  @override
  String get ocrSystemAlbumDescription => '이 기기의 이미지를 찾아 선택';

  @override
  String ocrTakePhotoFailed(Object error) {
    return '사진 촬영 실패: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return '이미지 선택 실패: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '이미지 $_temp0를 불러왔습니다';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return '이미지 처리 실패: $error';
  }

  @override
  String get ocrUnknownSourceImageCount => '원본 이미지 수를 확인할 수 없습니다';

  @override
  String get ocrConfirmClear => '지우기 확인';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      '원본 OCR 이미지 캐시를 사용할 수 없어 이미지 수를 복구할 수 없습니다. 지우면 이전 재시도 상태가 초기화됩니다. 이 OCR 작업에 사용할 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrConfirmClearSelected => '선택한 OCR 이미지를 지울까요?';

  @override
  String get ocrCancel => '취소';

  @override
  String get ocrConfirmResetAndReselect => '초기화하고 이미지를 다시 선택';

  @override
  String get ocrRequestCheckFailed => 'OCR 요청을 확인할 수 없습니다. 모델 매개변수를 확인하세요.';

  @override
  String get ocrCancelledAdjustAndRetry =>
      '인식이 취소되었습니다. 제공업체/모델 요청 크기 또는 이미지 품질을 조정한 뒤 다시 시도하세요.';

  @override
  String get ocrRequestSizeExceededTitle => 'OCR 요청이 설정된 크기 한도를 초과했습니다';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return '요청 크기는 약 $requestSize MiB로 설정된 한도 $limit MiB를 초과합니다.';
  }

  @override
  String get ocrRequestSizeHelp =>
      '제공업체 기본값이나 모델 재정의에서 요청 크기를 조정하거나 다른 이미지 품질을 선택하세요. 품질을 변경한 뒤에는 이미지를 지우고 다시 가져오세요.';

  @override
  String get ocrUsePerImageMode => '이미지별 인식 사용';

  @override
  String get ocrGotIt => '확인';

  @override
  String get ocrWaitForImport => '인식을 시작하기 전에 이미지 가져오기가 끝날 때까지 기다리세요.';

  @override
  String get ocrWaitForRetryImages => '재시도 이미지를 읽는 중입니다. 잠시 기다려 주세요.';

  @override
  String get ocrConfigureProviderModel => '먼저 설정에서 OCR 제공업체와 모델을 구성하세요.';

  @override
  String get ocrReselectProviderModel => 'OCR 제공업체와 모델을 다시 선택하세요.';

  @override
  String get ocrConfirmLegacyModel => '먼저 이전 재시도 기록의 OCR 모델을 확인하세요.';

  @override
  String get ocrRetryImagesUnavailable =>
      '원본 OCR 이미지 캐시를 사용할 수 없습니다. 작업을 지우고 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImageCountUnknown =>
      '원본 OCR 이미지 캐시를 사용할 수 없어 이미지 수를 알 수 없습니다. 초기화한 뒤 이 OCR 작업의 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImageReset =>
      '이전 재시도 입력이 초기화되었습니다. 이 OCR 작업의 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImagesUnreadable =>
      '원본 OCR 이미지 캐시를 읽을 수 없습니다. 작업을 지우고 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrRetryImagesMissing =>
      '원본 OCR 이미지 캐시가 없거나 손상되었습니다. 작업을 지우고 이미지를 모두 다시 선택하세요.';

  @override
  String get ocrImageListChanged => '이미지 목록이 변경되었습니다. 인식을 다시 시작하세요.';

  @override
  String get ocrReadInstructionFailed => '인식 지침을 읽을 수 없습니다. 다시 시도하세요.';

  @override
  String get ocrErrorDetails => '오류 세부 정보';

  @override
  String get ocrRequestHeading => '요청';

  @override
  String get ocrResponseHeading => '응답';

  @override
  String get ocrNoDetails => '사용 가능한 세부 정보가 없습니다';

  @override
  String get ocrImageLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get ocrCrop => '자르기';

  @override
  String get ocrEdit => '편집';

  @override
  String get ocrProcessingOcrFailed => 'OCR 이미지를 처리하지 못했습니다. 다시 시도하세요.';

  @override
  String get settingsPageTitle => '설정';

  @override
  String get settingsSectionGeneral => '일반';

  @override
  String get settingsSectionProviders => '제공업체';

  @override
  String get settingsSectionSystemAssistant => '시스템 어시스턴트';

  @override
  String get settingsSectionContextManagement => '컨텍스트 관리';

  @override
  String get settingsSectionManagement => '관리';

  @override
  String get settingsSectionAbout => '정보';

  @override
  String get settingsBackupRestore => '백업 및 복원';

  @override
  String get settingsBackupRestoreDescription => '앱 데이터 내보내기 또는 가져오기';

  @override
  String get settingsCookies => '쿠키 및 브라우저 데이터';

  @override
  String get settingsCookiesDescription => '영구 쿠키와 브라우저 저장 공간 관리';

  @override
  String get settingsAppLogs => '앱 로그';

  @override
  String get settingsAppLogsDescription => '앱 실행 로그 보기';

  @override
  String get settingsThemeDisplay => '테마 및 디스플레이';

  @override
  String get settingsThemeDisplayDescription => '다크 모드 및 표시 언어';

  @override
  String get settingsTaskNotifications => '작업 완료 알림';

  @override
  String get settingsTaskNotificationsDescription =>
      '알림 권한과 시스템 설정을 확인하고 알림 안내 보기';

  @override
  String get settingsBackgroundOptimization => '백그라운드 동작 최적화';

  @override
  String get settingsBackgroundOptimizationDescription =>
      '시스템 환경과 백그라운드 서비스 상태를 확인하고 최적화 안내 보기';

  @override
  String get aboutVersionInfo => '버전 정보 보기';

  @override
  String get aboutCheckUpdates => '업데이트 확인';

  @override
  String aboutNewVersionFound(Object version) {
    return '새 버전 $version을(를) 사용할 수 있습니다';
  }

  @override
  String get aboutNewVersion => '새 버전';

  @override
  String get aboutPreviewUpdates => '프리뷰 업데이트';

  @override
  String get aboutPreviewUpdatesDescription => '프리뷰 릴리스 확인 사용';

  @override
  String get aboutProjectHome => '프로젝트 홈';

  @override
  String get aboutFeedback => '문제 신고';

  @override
  String get aboutPrivacyPolicy => '개인정보 처리방침';

  @override
  String get aboutOpenSourceAgreement => '오픈 소스 계약';

  @override
  String get aboutOpenSourceLicenses => '오픈 소스 라이선스';

  @override
  String get aboutCheckingUpdates => '업데이트 확인 중…';

  @override
  String get aboutUpToDate => '최신 버전을 사용하고 있습니다';

  @override
  String aboutUpdateNetworkError(Object details) {
    return '네트워크 오류: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return 'HTTP 상태 $statusCode(으)로 업데이트 확인에 실패했습니다.';
  }

  @override
  String get aboutUpdateInvalidResponse => '업데이트 서버에서 예상하지 못한 응답을 반환했습니다.';

  @override
  String get aboutUpdateCheckFailed => '업데이트 확인에 실패했습니다. 다시 시도하세요.';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return '어시스턴트 업데이트 확인 실패: $error';
  }

  @override
  String get aboutPrivacyContent =>
      'Stroom은 서비스를 이용하는 모든 사람의 개인정보를 존중하고 보호합니다.\n\n1. 카메라 권한: 사진 촬영에만 사용됩니다. 이미지 데이터를 수집하거나 업로드하지 않습니다.\n\n2. 사진 라이브러리 권한: 사진을 선택하고 저장하는 데만 사용됩니다. 모든 사진은 기기에 로컬로 저장됩니다.\n\n3. 데이터 보안: 촬영한 사진은 모두 기기에 로컬로 저장됩니다. 사용자 데이터에 접근하거나 업로드하지 않습니다.\n\n4. 제3자 서비스: 이 앱에는 제3자 분석 또는 광고 서비스가 포함되어 있지 않습니다.\n\n궁금한 점이 있으면 문의해 주세요.';

  @override
  String get aboutClose => '닫기';

  @override
  String get contextToolPruneTitle => '도구 결과 자동 정리(Prune)';

  @override
  String get contextToolPruneDescription =>
      '기준을 초과한 오래된 도구 결과를 자리표시자로 자동 대체해 저장 공간과 컨텍스트를 확보합니다.';

  @override
  String get contextCompactionTriggerSettings => '요약 시작 조건 설정';

  @override
  String get contextCompactionDisabled => '사용 안 함(요약을 실행하지 않음)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return '전역 시작 기준 $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '모델별 재정의 $_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => '요약 시작 조건 설정';

  @override
  String get contextAutoCompaction => '자동 컨텍스트 요약';

  @override
  String get contextAutoCompactionDisabled =>
      '사용하지 않으면 어떤 모델에서도 요약이 실행되지 않습니다.';

  @override
  String get contextGlobalTrigger => '전역 시작 비율';

  @override
  String get contextGlobalTriggerDescription =>
      '개별 설정이 없는 모델은 모델 컨텍스트 창에서 이 비율에 도달하면 요약을 시작합니다.';

  @override
  String contextResetPercent(Object percent) {
    return '$percent%로 재설정';
  }

  @override
  String get contextPerModelSettings => '모델별 설정';

  @override
  String get contextNoConfiguredModels => '설정된 모델이 없습니다';

  @override
  String contextIndependentThreshold(Object threshold) {
    return '독립 기준: $threshold 토큰';
  }

  @override
  String get contextEnterIndependentThreshold => '아래에 독립 기준을 입력하세요';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return '전역 기준 $percent% 따르기';
  }

  @override
  String get contextThresholdField => '독립 기준(토큰)';

  @override
  String get contextThresholdHint => '예: 48000(백분율이 아닌 토큰 수)';

  @override
  String get contextPercentField => '비율';

  @override
  String contextPercentHint(Object percent) {
    return '예: $percent';
  }

  @override
  String get versionInfoTitle => '버전 정보';

  @override
  String get versionNumberLabel => '버전';

  @override
  String get versionReleaseTimeLabel => '릴리스 시간';

  @override
  String get versionLocalBuild => '로컬 빌드';

  @override
  String get versionReleaseNotesLabel => '릴리스 노트';

  @override
  String get versionClose => '닫기';

  @override
  String get updateDialogTitle => '새 버전을 사용할 수 있습니다';

  @override
  String get updateLatestVersionLabel => '최신 버전';

  @override
  String get updateSelectedVersionLabel => '선택한 버전';

  @override
  String get updateReleaseNotesLabel => '릴리스 노트';

  @override
  String get updateInstalling => '설치 중…';

  @override
  String get updateDownloadComplete => '다운로드 완료';

  @override
  String get updateClose => '닫기';

  @override
  String get updateManualInstall => '수동 설치';

  @override
  String get updateOpenInstaller => '설치 프로그램 열기';

  @override
  String get updateRetryDownload => '다운로드 재시도';

  @override
  String get updateSkipVersion => '이 버전 건너뛰기';

  @override
  String get updateRemindLater => '나중에 알림';

  @override
  String get updateOpenBrowser => '브라우저에서 다운로드';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updatePreviewBadge => '프리뷰';

  @override
  String get updateLatestBadge => '최신';

  @override
  String get updateSelectVersion => '버전 선택';

  @override
  String get updateDownloading => '업데이트 다운로드 중…';

  @override
  String updateCheckNetworkError(Object details) {
    return '네트워크 오류: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return '업데이트 확인 실패: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      '업데이트 확인 실패: 서버에서 인식할 수 없는 데이터를 반환했습니다';

  @override
  String get updateDownloadUrlUnavailable => '다운로드 URL을 사용할 수 없습니다.';

  @override
  String get updateNoDirectDownloadLink =>
      '이 플랫폼에는 직접 다운로드 링크가 없습니다. 브라우저에서 다운로드하세요.';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return '자동 설치 실패: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return '다운로드 실패: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return '다운로드 실패: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return '설치 실패: $details';
  }

  @override
  String updateFailed(Object details) {
    return '업데이트 실패: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return '파일을 열 수 없습니다. 수동으로 설치하세요: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return '설치에 실패했습니다. APK를 직접 여세요: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails => '설치에 실패했습니다. APK를 직접 여세요.';

  @override
  String get updateApkInstallerUnavailable =>
      '이 APK를 설치할 앱을 찾을 수 없습니다. APK를 직접 여세요.';

  @override
  String get updateApkInstallPermissionDenied =>
      '시스템 설정에서 Stroom의 알 수 없는 앱 설치를 허용하세요.';

  @override
  String get updateRestartDialogTitle => '앱 업데이트 완료';

  @override
  String get updateRestartDialogBody =>
      '앱이 업데이트되었습니다. 안정적인 사용을 위해 앱을 다시 시작하세요.';

  @override
  String get updateRestartDialogLater => '나중에 다시 시작';

  @override
  String get updateRestartDialogNow => '지금 다시 시작';

  @override
  String get contextCompactionHistoryIntro => '요약할 대화 기록:';

  @override
  String get contextCompactionUserRole => '사용자';

  @override
  String get contextCompactionAssistantRole => '어시스턴트';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role이(가) 도구 $toolName을(를) 호출함: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      '위 대화 기록을 지정된 템플릿에 따라 고정 요약으로 압축하세요.';

  @override
  String get ocrImageEmpty => '이미지가 비어 있습니다. 다시 선택하세요.';

  @override
  String get ocrImageUnsupportedFormat =>
      '지원하지 않는 이미지 형식입니다. PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'HEIC, SVG, TIFF 이미지는 아직 지원되지 않습니다. PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImageDecodeFailed =>
      '이미지가 손상되었거나 디코딩할 수 없습니다. 다시 선택하거나 PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImageDimensionsTooLarge =>
      '이미지 해상도가 너무 큽니다. OCR은 이미지당 최대 5천만 픽셀을 지원합니다. 크기를 줄인 뒤 다시 시도하세요.';

  @override
  String get ocrImageOrientationPngTooLarge =>
      '이미지 방향을 바로잡는 데 필요한 PNG가 OCR 요청 크기 한도를 초과합니다. 이미지 크기를 줄인 뒤 다시 시도하세요.';

  @override
  String get ocrImageOrientationFailed =>
      '이미지 방향을 바로잡을 수 없습니다. PNG, JPEG 또는 WebP로 변환한 뒤 다시 시도하세요.';

  @override
  String get ocrImagePreparationFailed => '이미지를 처리할 수 없습니다. 다시 선택한 뒤 재시도하세요.';

  @override
  String get homeTitle => '홈';

  @override
  String get homeWelcome => 'Stroom에 오신 것을 환영합니다';

  @override
  String get homeChooseModule => '시작하려면 모듈을 선택하세요';

  @override
  String get homeOcrSubtitle => '텍스트 인식';

  @override
  String get homeAsrTitle => '음성 인식';

  @override
  String get homeAsrSubtitle => '음성을 텍스트로 변환';

  @override
  String get homeWebDownloadTitle => '웹 미디어 다운로드';

  @override
  String get homeWebDownloadSubtitle => '웹페이지에서 오디오와 동영상 다운로드';

  @override
  String get homeAudioSeparationTitle => '오디오 분리';

  @override
  String get homeAudioSeparationSubtitle => '동영상에서 오디오 추출';

  @override
  String get homeTtsTitle => '텍스트 음성 변환';

  @override
  String get homeTtsSubtitle => '텍스트를 음성으로 변환';

  @override
  String get homeChartsTitle => '차트 만들기';

  @override
  String get homeChartsSubtitle => 'Mermaid 차트 편집기';

  @override
  String get homeMathTitle => '수학 그래프';

  @override
  String get homeMathSubtitle => '함수 그래프 그리기';

  @override
  String get homeAnkiTitle => 'Anki 플래시카드';

  @override
  String get homeAnkiSubtitle => '기억 보조 시스템';

  @override
  String get homeTaskFlowTitle => '작업 흐름';

  @override
  String get homeTaskFlowEmpty => '여러 모듈을 차례로 실행하는 자동화 흐름을 만드세요';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 · 관리',
      one: '$count개 · 관리',
    );
    return '작업 흐름 $_temp0';
  }

  @override
  String get homeRecentTasks => '최근 작업';

  @override
  String get homeViewAll => '모두 보기';

  @override
  String get statusInProgress => '진행 중';

  @override
  String get statusCompleted => '완료';

  @override
  String get statusFailed => '실패';

  @override
  String get navHome => '홈';

  @override
  String get navChat => '채팅';

  @override
  String get navFiles => '파일';

  @override
  String get navSettings => '설정';

  @override
  String get conversationsTitle => '대화 기록';

  @override
  String get conversationNew => '새 대화';

  @override
  String get conversationSelectTitle => '대화 선택';

  @override
  String get topicSelectionEmptyTitle => '대화가 없습니다';

  @override
  String get topicSelectionEmptyMessage => '새 대화를 만들어 시작하세요';

  @override
  String get topicSelectionNewTopic => '새 대화';

  @override
  String get topicSelectionNoAssistant => '선택된 어시스턴트 없음';

  @override
  String get topicSelectionBackToAssistants => '어시스턴트 선택으로 돌아가기';

  @override
  String get topicSelectionEditAssistant => '어시스턴트 편집';

  @override
  String get topicSelectionReorderHint => '길게 누른 뒤 끌어서 대화 순서를 변경하세요';

  @override
  String conversationDeleteNamed(String title) {
    return '대화 “$title”을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get conversationDeleteTitle => '대화 삭제';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 대화 $count개를 삭제할까요? 이 작업은 되돌릴 수 없습니다.',
      one: '선택한 대화 $count개를 삭제할까요? 이 작업은 되돌릴 수 없습니다.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => '취소';

  @override
  String get actionDelete => '삭제';

  @override
  String get conversationRename => '대화 이름 변경';

  @override
  String get conversationRenameHint => '새 이름 입력';

  @override
  String get actionConfirm => '확인';

  @override
  String get conversationNoMatches => '일치하는 대화를 찾을 수 없습니다';

  @override
  String get conversationEmpty => '대화 기록이 없습니다';

  @override
  String get conversationSearchHint => '모든 대화에서 메시지 검색...';

  @override
  String conversationSelected(int count) {
    return '$count개 선택됨';
  }

  @override
  String get conversationSearch => '검색';

  @override
  String get conversationDeleteSelected => '선택 항목 삭제';

  @override
  String get actionUnselect => '선택 취소';

  @override
  String get actionSelect => '선택';

  @override
  String conversationDeleteCount(int count) {
    return '$count개 삭제';
  }

  @override
  String get conversationPin => '고정';

  @override
  String get conversationUnpin => '고정 해제';

  @override
  String get actionRename => '이름 변경';

  @override
  String get conversationAutoRename => '자동 이름 지정';

  @override
  String get conversationTemporary => '임시 대화';

  @override
  String get conversationSetTemporary => '임시 대화로 설정';

  @override
  String get conversationCloseTemporary => '임시 대화 닫기';

  @override
  String get conversationKeep => '대화 유지';

  @override
  String get conversationTemporaryStatus => '임시';

  @override
  String get conversationTemporaryWarning => '곧 만료';

  @override
  String get conversationTemporaryExplanation =>
      '이 대화는 1시간 후 삭제됩니다. 메시지를 보내면 타이머가 다시 시작됩니다. 임시 모드를 끄면 대화가 보존됩니다.';

  @override
  String get conversationEnableTemporary => '임시 모드 사용';

  @override
  String get chatLoadingConversation => '대화 불러오는 중…';

  @override
  String get chatEmptyConversation => '메시지를 보내 대화를 시작하세요.';

  @override
  String get chatNoActiveConversation => '대화를 시작하려면 대화를 선택하거나 새로 만드세요.';

  @override
  String get chatConversationLoadError => '대화를 불러오지 못했습니다.';

  @override
  String get chatRetryLoadConversation => '다시 시도';

  @override
  String get taskListTitle => '작업 목록';

  @override
  String get taskListEmpty => '작업이 없습니다';

  @override
  String get unifiedTaskListTabAll => '전체';

  @override
  String get unifiedTaskListTabInProgress => '진행 중';

  @override
  String get unifiedTaskListTabCompleted => '완료';

  @override
  String get unifiedTaskListTabFailed => '실패';

  @override
  String get unifiedTaskListTabStopped => '중지됨';

  @override
  String get unifiedTaskListConfirmClear => '지우기 확인';

  @override
  String get unifiedTaskListConfirmClearFailedMessage => '실패한 작업을 모두 지울까요?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      '작업을 모두 지울까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get unifiedTaskListCancel => '취소';

  @override
  String get unifiedTaskListConfirm => '확인';

  @override
  String get unifiedTaskListClearCompleted => '완료된 작업 지우기';

  @override
  String get unifiedTaskListClearFailed => '실패한 작업 지우기';

  @override
  String get unifiedTaskListClearAll => '모든 작업 지우기';

  @override
  String get unifiedTaskListRestoreInProgress => '작업 흐름 기록 복원 중…';

  @override
  String get unifiedTaskListRestoreFailed =>
      '작업 흐름 기록을 읽을 수 없습니다. 작업이 일시 중지되었습니다';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return '미완료 항목 지우기 실패: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning =>
      '취소한 뒤에도 작업 흐름이 계속 실행 중입니다.';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      '작업 흐름 취소 상태를 저장할 수 없습니다. 다시 지워 보세요.';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      '작업 흐름 기록 삭제를 저장할 수 없습니다. 다시 지워 보세요.';

  @override
  String get chatAutoContinuePrompt => '끝나지 않았다면 계속하세요.';

  @override
  String get chatSearchCurrent => '이 대화 검색...';

  @override
  String get chatSearchAll => '모든 대화 검색...';

  @override
  String get searchPrevious => '이전 일치 항목';

  @override
  String get searchNext => '다음 일치 항목';

  @override
  String get searchClose => '검색 닫기';

  @override
  String get searchCurrentConversation => '현재 대화';

  @override
  String get searchAllConversations => '모든 대화';

  @override
  String get chatReasoning => '추론';

  @override
  String get chatTools => '도구';

  @override
  String get chatCustomParameters => '사용자 지정 매개변수';

  @override
  String get chatEditMessage => '메시지 편집';

  @override
  String get actionClose => '닫기';

  @override
  String get chatEditWarning => '편집 후 다시 보내면 아래에 있는 모든 메시지가 삭제됩니다';

  @override
  String get chatAttachment => '첨부 파일';

  @override
  String get chatMessageHint => '메시지를 입력하세요...';

  @override
  String get chatFullscreenEdit => '전체 화면 편집기';

  @override
  String get chatStopGeneration => '생성 중지';

  @override
  String get actionSend => '보내기';

  @override
  String get chatCopy => '복사';

  @override
  String get actionSave => '저장';

  @override
  String get actionRetry => '재시도';

  @override
  String get actionEdit => '편집';

  @override
  String get chatViewResponseData => '응답 데이터 보기';

  @override
  String get chatViewRequestData => '요청 데이터 보기';

  @override
  String get chatInspectJson => 'JSON 검사';

  @override
  String get chatConfirmEditTitle => '메시지 편집';

  @override
  String get chatConfirmEditDeleteFollowing =>
      '이 메시지를 편집할까요? 이 메시지와 이후의 모든 메시지가 삭제됩니다.';

  @override
  String get chatConfirmResend => '이 메시지를 다시 보낼까요?';

  @override
  String get chatConfirmRetryTitle => '재시도';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      '이 응답을 재시도할까요? 이 메시지와 이후의 모든 메시지가 삭제됩니다.';

  @override
  String get chatConfirmRegenerate => '응답을 다시 생성할까요?';

  @override
  String get chatDeleteMessageTitle => '메시지 삭제';

  @override
  String get chatDeleteMessageConfirm => '이 메시지를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get chatThinking => '생각 중';

  @override
  String get chatThinkingComplete => '생각 완료';

  @override
  String get conversationDeleteOne => '이 대화를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '리소스 $total개 중 $selected개 선택',
      one: '리소스 $total개 중 $selected개 선택',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => '다운로드할 미디어 선택';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '세그먼트 $count개 숨기기',
      one: '세그먼트 $count개 숨기기',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '세그먼트 $count개 표시',
      one: '세그먼트 $count개 표시',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => '감지된 리소스가 없습니다';

  @override
  String get mediaSegment => '세그먼트';

  @override
  String get mediaPlaylist => '재생목록';

  @override
  String get mediaFullVideo => '전체 동영상';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours시간 $minutes분 $seconds초';
  }

  @override
  String mediaDuration(String value) {
    return '길이: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return '해상도: ${width}x$height';
  }

  @override
  String get mediaPreview => '미리보기';

  @override
  String get mediaSegmentPreviewHint => '재생목록에서 세그먼트 미리보기';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 리소스 $count개 다운로드',
      one: '선택한 리소스 $count개 다운로드',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => '다운로드 확인';

  @override
  String get chatNoMoreHistory => '더 이상 메시지가 없습니다';

  @override
  String get chatSendFailed => '메시지를 보내지 못했습니다';

  @override
  String get chatViewErrorDetails => '오류 세부 정보 보기';

  @override
  String get chatCompactionCollapsed => '컨텍스트 요약됨 · 이전 메시지가 요약되었습니다(눌러서 접기)';

  @override
  String get chatCompactionExpanded => '컨텍스트 요약됨 · 이전 메시지가 요약되었습니다(눌러서 요약 보기)';

  @override
  String get chatEditConversationTitle => '대화 제목 편집';

  @override
  String get chatSearchMessages => '메시지 검색';

  @override
  String get chatApiMissingSettings => '⚠️ 채팅 API가 설정되지 않았습니다 — 설정으로 이동하세요';

  @override
  String get appSettings => '설정';

  @override
  String get chatCopied => '복사됨';

  @override
  String get chatNoSavableText => '저장할 텍스트가 없습니다';

  @override
  String get chatSaveMarkdownTitle => '메시지를 Markdown으로 저장';

  @override
  String get chatSaveToolCallChoice => '이 답변에는 여러 도구 호출이 있습니다. 저장할 항목을 선택하세요:';

  @override
  String get chatSaveCompleteMessage => '전체 메시지 저장';

  @override
  String get chatSaveLastMessage => '마지막 메시지 저장';

  @override
  String get chatSaveToAppFiles => '앱 파일에 저장';

  @override
  String get chatSaveFolderHint => '.md 파일을 저장할 폴더를 선택하거나 만드세요';

  @override
  String get chatSaveFilenameHint => '파일 이름을 입력하세요(.md 확장자는 자동으로 추가됩니다)';

  @override
  String get chatFilenameRequired => '파일 이름을 입력해야 합니다';

  @override
  String chatSavedToPath(String path) {
    return '저장 위치: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return '앱 파일에 저장됨: $path';
  }

  @override
  String get chatSelectModel => '모델 선택';

  @override
  String get chatModelFallback => '모델';

  @override
  String get chatNoModelsAvailable => '사용 가능한 모델이 없습니다';

  @override
  String get chatAvailableTools => '사용 가능한 도구';

  @override
  String get chatNoToolsAvailable => '사용 가능한 도구가 없습니다';

  @override
  String get chatReasoningSettings => '추론 설정';

  @override
  String get chatReasoningNotConfigured =>
      '이 모델에 설정된 추론 매개변수가 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatReasoningEffort => '추론 강도';

  @override
  String get chatReasoningEffortNotConfigured =>
      '이 모델에 설정된 추론 강도 매개변수가 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatParameterNoOptions => '이 매개변수에는 선택 항목이 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatOtherReasoningNotConfigured =>
      '이 모델에는 다른 추론 매개변수가 설정되어 있지 않습니다.\n모델 설정에서 추가하세요.';

  @override
  String get chatCustomParamsNotConfigured =>
      '이 모델에는 사용자 지정 매개변수가 설정되어 있지 않습니다.\n모델 설정에서 추가하세요.';

  @override
  String get chatNoOptionValues => '선택 항목이 없습니다. 모델 설정에서 추가하세요.';

  @override
  String get chatImageLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get chatVideoLoadFailed => '동영상을 불러올 수 없습니다';

  @override
  String get chatHtmlLoading => 'HTML 미리보기 로딩 중...';

  @override
  String get chatPreviewLoadFailed => '미리보기를 불러오지 못했습니다';

  @override
  String get albumPickerLoadFailed => '앱 앨범을 불러올 수 없습니다';

  @override
  String get chatHtmlPreview => 'HTML 미리보기';

  @override
  String get chatMermaidLoading => '차트 미리보기 로딩 중...';

  @override
  String get chatMermaidPreview => 'Mermaid 미리보기';

  @override
  String get chatZoomOut => '축소';

  @override
  String get chatZoomIn => '확대';

  @override
  String get chatJsonInspection => 'JSON 검사';

  @override
  String get chatNoRequestData => '요청 데이터가 없습니다';

  @override
  String get chatNoResponseData => '응답 데이터가 없습니다';

  @override
  String get chatSaveMessage => '메시지 저장';

  @override
  String get chatChooseSaveLocation => '메시지를 저장할 위치 선택';

  @override
  String get chatChooseSaveLocationLabel => '저장 위치 선택:';

  @override
  String get chatSaveAppFile => '앱 파일에 저장';

  @override
  String get chatSaveDevice => '기기에 저장';

  @override
  String get chatFileTypeAudio => '오디오 파일';

  @override
  String get chatFileTypeVideo => '동영상 파일';

  @override
  String get chatFileTypeDocument => '문서';

  @override
  String get chatFileTypeGeneric => '파일';

  @override
  String get chatInfoType => '유형';

  @override
  String get chatInfoSize => '크기';

  @override
  String get chatInfoPath => '경로';

  @override
  String get chatErrorBack => '뒤로';

  @override
  String get chatErrorPrefix => '오류: ';

  @override
  String get chatErrorCancelled => '사용자가 출력을 중단했습니다';

  @override
  String get chatErrorProviderNotConfigured =>
      '채팅 API가 설정되지 않았습니다. 설정을 열어 제공업체를 구성하세요.';

  @override
  String get chatErrorApiKeyNotConfigured => 'API 키가 설정되지 않았습니다. 설정을 확인하세요.';

  @override
  String get chatErrorServerConnection =>
      '서버에 연결할 수 없습니다. 네트워크 연결과 API 주소를 확인하세요.';

  @override
  String get chatErrorNetworkConnection => '네트워크 연결에 실패했습니다. 네트워크 연결을 확인하세요.';

  @override
  String get chatErrorTimeout => '연결 시간이 초과되었습니다. 서버가 응답하지 않았습니다.';

  @override
  String chatAttachmentImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return '사진을 촬영할 수 없습니다: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform에서는 기기 갤러리에 접근할 수 없습니다: $error';
  }

  @override
  String get chatAttachmentWebPlatform => '웹 브라우저';

  @override
  String get chatAttachmentCurrentPlatform => '이 기기';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      '사진 라이브러리 접근 권한을 허용한 뒤 다시 시도하세요.';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      '브라우저 설정에서 이 웹사이트의 파일 접근을 허용하세요.';

  @override
  String get chatAttachmentGalleryFallbackHint => '기기에서 갤러리 선택을 지원하는지 확인하세요.';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return '이미지를 가져올 수 없습니다: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform에서는 파일 선택을 지원하지 않습니다: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint => '파일 접근 권한을 허용한 뒤 다시 시도하세요.';

  @override
  String get chatAttachmentFileFallbackHint => '기기에서 파일 선택을 지원하는지 확인하세요.';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return '파일을 가져올 수 없습니다: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return '$fileName 가져옴';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return '편집한 이미지를 저장할 수 없습니다: $error';
  }

  @override
  String get chatDataDetails => '데이터 세부 정보';

  @override
  String get chatErrorDetailOcrDiagnostics => 'OCR 진단';

  @override
  String get chatErrorDetailRequestUrl => '요청 URL';

  @override
  String get chatErrorDetailRequestHeaders => '요청 헤더';

  @override
  String get chatErrorDetailRequestBody => '요청 본문';

  @override
  String get chatErrorDetailStatusCode => '상태 코드';

  @override
  String get chatErrorDetailResponseHeaders => '응답 헤더';

  @override
  String get chatErrorDetailResponseBody => '응답 본문';

  @override
  String get chatErrorDetailEmpty => '사용할 수 있는 세부 정보가 없습니다';

  @override
  String get chatAudioPreviewClose => '닫기';

  @override
  String get chatPreviewClose => '미리보기 닫기';

  @override
  String get actionBack => '뒤로';

  @override
  String get chatCannotLoadFile => '파일을 불러올 수 없습니다';

  @override
  String chatThinkingNumbered(int index) {
    return '생각 중 $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '저장하지 않은 변경 사항을 버릴까요?';

  @override
  String get taskFlowUiDiscardBody => '돌아가면 저장하지 않은 변경 사항이 모두 사라집니다.';

  @override
  String get taskFlowUiContinueEditing => '계속 편집';

  @override
  String get taskFlowUiDiscard => '버리기';

  @override
  String get taskFlowUiUndo => '실행 취소';

  @override
  String get taskFlowUiSave => '저장';

  @override
  String get taskFlowUiNameHint => '작업 흐름 이름 입력';

  @override
  String get taskFlowUiDescriptionHint => '설명 추가(선택 사항)';

  @override
  String get taskFlowUiNameRequired => '작업 흐름 이름을 입력하세요';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return '단계 $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '“$block”에는 “$parameter”이(가) 필요합니다';
  }

  @override
  String get taskFlowUiSaveFailed => '저장하지 못했습니다. 변경 사항은 그대로 있습니다. 다시 시도하세요.';

  @override
  String get taskFlowUiRetry => '재시도';

  @override
  String get taskFlowUiUpdated => '작업 흐름이 업데이트되었습니다';

  @override
  String get taskFlowUiCreated => '작업 흐름이 생성되었습니다';

  @override
  String get taskFlowUiTitle => '작업 흐름';

  @override
  String get taskFlowUiNotFound => '작업을 찾을 수 없습니다';

  @override
  String get taskFlowUiBack => '뒤로';

  @override
  String get taskFlowUiEdit => '편집';

  @override
  String taskFlowUiInput(Object label) {
    return '입력($label)';
  }

  @override
  String get taskFlowUiInputHint => '텍스트 또는 링크 입력';

  @override
  String get taskFlowUiStart => '작업 흐름 시작';

  @override
  String get taskFlowUiNoInput => '입력이 없습니다. 아래를 눌러 웹 리소스 URL을 추가하세요.';

  @override
  String get taskFlowUiAddResource => '웹 리소스 추가';

  @override
  String get taskFlowUiUrlHint => '동영상 또는 오디오 웹페이지 URL 입력';

  @override
  String get taskFlowUiDeleteInput => '이 입력 삭제';

  @override
  String get taskFlowUiHour => '시간';

  @override
  String get taskFlowUiMinute => '분';

  @override
  String get taskFlowUiSecond => '초';

  @override
  String get taskFlowUiPreview => '미리보기: ';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      '선택 사항: 길이로 동영상 리소스를 필터링합니다. 비워 두면 사용 가능한 모든 리소스를 표시합니다.';

  @override
  String get taskFlowUiSelectImages => '이미지 선택(여러 개)';

  @override
  String get taskFlowUiSelectAudio => '오디오 선택(여러 개)';

  @override
  String get taskFlowUiSelectFiles => '파일 선택(여러 개)';

  @override
  String get taskFlowUiSelectVideo => '동영상 선택(여러 개)';

  @override
  String get taskFlowUiRemove => '제거';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return '제거한 파일을 정리할 수 없습니다: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0. 초기 입력';

  @override
  String taskFlowUiInputType(Object type) {
    return '입력 유형: $type';
  }

  @override
  String get taskFlowUiUserFlowInput => '사용자가 작업 흐름을 실행할 때 제공하는 입력';

  @override
  String taskFlowUiBlockInput(Object type) {
    return '입력: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return '출력: $type';
  }

  @override
  String get taskFlowUiParameters => '매개변수:';

  @override
  String get taskFlowUiClose => '닫기';

  @override
  String get taskFlowUiSelectAppImages => '앱에서 이미지 선택(여러 개)';

  @override
  String get taskFlowUiNoImages => '이미지가 없습니다';

  @override
  String get taskFlowUiSelectAppAudio => '앱에서 오디오 선택(여러 개)';

  @override
  String get taskFlowUiNoAudio => '오디오가 없습니다';

  @override
  String get taskFlowUiSelectAppVideo => '앱에서 동영상 선택(여러 개)';

  @override
  String get taskFlowUiNoVideo => '동영상이 없습니다';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return '파일을 선택할 수 없습니다: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '“$name”의 크기가 $limit MB를 초과합니다. 더 작은 파일을 선택하세요.';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '“$name”이(가) 비어 있거나 읽을 수 없습니다';
  }

  @override
  String get taskFlowUiSomeFilesMissing => '일부 파일이 없어 건너뛰었습니다';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return '선택한 파일 $count개에 접근할 수 없습니다. 모든 파일을 다시 선택하세요.';
  }

  @override
  String get taskFlowUiQueuedOne => '작업 흐름을 대기열에 추가했습니다';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return '작업 흐름 $count개를 대기열에 추가했습니다';
  }

  @override
  String get taskFlowUiRunTitle => '이번 실행';

  @override
  String get taskFlowUiCancelBatch => '전체 일괄 작업 취소';

  @override
  String get taskFlowUiRestoringRecords => '작업 흐름 기록 복원 중…';

  @override
  String get taskFlowUiRecordsPaused => '작업 흐름 기록을 불러올 수 없습니다. 작업이 일시 중지되었습니다.';

  @override
  String get taskFlowUiRecordsCleared => '이번 실행의 기록을 지웠습니다';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$total개 중 $finished개 실행 완료';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return ' · 기록 $count개 삭제됨';
  }

  @override
  String get taskFlowUiTemporaryFiles => '임시 중간 파일';

  @override
  String get taskFlowUiAddBlock => '블록 추가';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return '단계 $index 앞에 블록 삽입';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      '앞뒤 단계와 모두 호환되는 블록이 없습니다. 먼저 앞뒤 단계를 조정하세요.';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return '단계 $index 앞에 삽입';
  }

  @override
  String get taskFlowUiUnknown => '알 수 없음';

  @override
  String get taskFlowUiChooseBlock => '블록 선택';

  @override
  String get taskFlowUiInsertBlock => '블록 삽입';

  @override
  String get taskFlowUiPreviousOutput => '이전 단계 출력';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '; 다음 단계에 필요한 항목: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock => '현재 유형과 호환되는 블록이 없습니다';

  @override
  String get taskFlowUiReplaceBlock => '블록 바꾸기';

  @override
  String get taskFlowUiBlockCompatibility =>
      '입력 및 출력 유형이 호환되는 블록으로만 바꿀 수 있습니다.';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      '다음 단계에서 결과를 성공적으로 저장한 뒤 정리합니다. 마지막 단계의 결과는 항상 보존됩니다.';

  @override
  String get taskFlowUiSetParameters => '매개변수 설정';

  @override
  String get taskFlowUiReplace => '바꾸기';

  @override
  String get taskFlowUiViewParameters => '눌러서 매개변수 보기';

  @override
  String get taskFlowUiTapSetParameters => '눌러서 매개변수 설정';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return '알 수 없는 블록: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => '이 블록 유형은 등록되어 있지 않습니다';

  @override
  String taskFlowUiStepActions(Object index) {
    return '단계 $index 작업';
  }

  @override
  String get taskFlowUiInsertBefore => '앞에 삽입';

  @override
  String get taskFlowUiInsertAfter => '뒤에 삽입';

  @override
  String get taskFlowUiCopyBlock => '블록 복제';

  @override
  String get taskFlowUiMoveUp => '위로 이동';

  @override
  String get taskFlowUiMoveUpDisabled => '위로 이동(이미 첫 번째)';

  @override
  String get taskFlowUiMoveDown => '아래로 이동';

  @override
  String get taskFlowUiMoveDownDisabled => '아래로 이동(이미 마지막)';

  @override
  String get taskFlowUiDeleteBlock => '블록 삭제';

  @override
  String taskFlowUiInputLabel(Object label) {
    return '입력: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return '출력: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return '블록 유형 “$name”은(는) 등록되어 있지 않습니다';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$label 설정';
  }

  @override
  String get taskFlowUiSendToAssistant => '어시스턴트에게 보내는 사용자 메시지는 이전 단계의 출력입니다';

  @override
  String get taskFlowUiTempSpaceInfo =>
      '이 단계의 출력은 흐름의 임시 공간에 저장됩니다. 다음 단계에서 결과를 성공적으로 저장하면 출력이 정리됩니다. 임시 모드를 끄면 원래 저장 폴더가 보존되고 복원됩니다.';

  @override
  String get taskFlowUiNoExtraParameters => '이 블록에는 추가 매개변수가 없습니다';

  @override
  String get taskFlowUiCancel => '취소';

  @override
  String get taskFlowUiConfirm => '확인';

  @override
  String get taskFlowUiConfigureModelFirst => '먼저 모델을 설정하세요';

  @override
  String get taskFlowUiModelUnavailable =>
      '모델을 선택하지 않았거나 선택한 모델을 사용할 수 없습니다. 다른 모델을 선택하세요.';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return '모델 $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => '이름 없는 제공업체';

  @override
  String get taskFlowUiCustomModelParameters => '사용자 지정 모델 매개변수';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      '음성이 설정된 TTS 모델이 없습니다. ID를 직접 입력할 수 있습니다.';

  @override
  String get taskFlowUiVoiceUnavailable => '음성을 사용할 수 없습니다. 다른 음성을 선택하세요.';

  @override
  String get taskFlowUiSelectVoice => '음성 선택';

  @override
  String get taskFlowUiAssistantUnavailable => '어시스턴트를 사용할 수 없습니다';

  @override
  String get taskFlowUiAssistantUseCurrent => '지정 안 함(현재 선택된 어시스턴트 사용)';

  @override
  String get taskFlowUiAssistantDeleted =>
      '설정된 어시스턴트가 삭제되었습니다. 다른 어시스턴트를 선택하세요.';

  @override
  String get taskFlowUiChooseAssistant => '어시스턴트 선택';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      '“내 어시스턴트”만 선택할 수 있습니다(“채팅 → 어시스턴트”에서 추가).';

  @override
  String get taskFlowUiMyAssistants => '내 어시스턴트';

  @override
  String get taskFlowUiNoCustomAssistants =>
      '사용자 지정 어시스턴트가 없습니다. “채팅 → 어시스턴트”에서 만드세요.';

  @override
  String get taskFlowUiYes => '예';

  @override
  String get taskFlowUiNo => '아니요';

  @override
  String get taskFlowUiDefaultRoot => '기본값(루트 폴더)';

  @override
  String get taskFlowUiSelect => '선택';

  @override
  String get taskFlowUiSelectSaveFolder => '저장 폴더 선택';

  @override
  String get taskFlowUiCatCatchVideo => '동영상';

  @override
  String get taskFlowUiCatCatchAudio => '오디오';

  @override
  String get taskFlowUiCatCatchEither => '동영상 또는 오디오(후속 단계에 따라 필터링)';

  @override
  String get taskFlowUiManual => '수동';

  @override
  String get taskFlowUiAutomatic => '자동';

  @override
  String get taskFlowUiAutomaticPrompt => '확인 후 자동 실행';

  @override
  String get taskFlowUiEditTitle => '작업 흐름 편집';

  @override
  String get taskFlowUiCreateTitle => '새 작업 흐름';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return '단계 $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return '입력 유형: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return '입력: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return '출력: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return '제거한 파일을 정리할 수 없습니다: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return '파일을 선택할 수 없습니다: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '“$name”의 크기가 $limit MB를 초과합니다. 더 작은 파일을 선택하세요.';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '“$name”이(가) 비어 있거나 읽을 수 없습니다';
  }

  @override
  String get taskFlowUiTemporary => '임시';

  @override
  String get taskFlowUiTemporaryFileHint => '임시 파일(다음 단계가 성공하면 정리됨)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return '블록 유형 “$name”은(는) 등록되어 있지 않습니다';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$total개 중 $finished개 실행 완료';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return ' · 기록 $count개 삭제됨';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return '입력: $input → 출력: $output';
  }

  @override
  String get taskFlowCardTag => '작업 흐름';

  @override
  String get taskFlowCardQueued => '대기열에 있음(리소스를 기다리는 중)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$total개 중 $done개 완료';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$label $count개';
  }

  @override
  String get taskFlowCardFailedLabel => '실패';

  @override
  String get taskFlowCardSkippedLabel => '건너뜀';

  @override
  String get taskFlowCardCancelledLabel => '취소됨';

  @override
  String get taskFlowCardInterruptedLabel => '중단됨';

  @override
  String get taskFlowCardCancelFlow => '흐름 취소';

  @override
  String get taskFlowCardRetry => '재시도';

  @override
  String get taskFlowCardCancelBatch => '전체 일괄 작업 취소';

  @override
  String get taskFlowCardDelete => '삭제';

  @override
  String get taskFlowCardRetryFlow => '작업 흐름 재시도';

  @override
  String get taskFlowCardNoSnapshot =>
      '이 실행에는 스냅샷이 없습니다. 현재 흐름 설정을 사용해 처음부터 다시 시작합니다.';

  @override
  String get taskFlowCardRetryInfo =>
      '처음부터 다시 시작하면 파일을 다시 다운로드하고 모델을 다시 호출합니다. 시작할 때 사용한 설정으로 재시도하거나 최신 설정을 직접 선택하세요. 완료된 단계를 재사용하려면 “중단된 단계부터 다시 시작”을 선택하세요.';

  @override
  String get taskFlowCardRunLatest => '최신 설정으로 실행';

  @override
  String get taskFlowCardRetryOriginal => '원래 설정으로 재시도';

  @override
  String get taskFlowCardDeleteRecord => '작업 흐름 기록 삭제';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      '이 실행을 삭제하면 일괄 작업의 미완료 작업이 취소되고 하위 작업 기록이 지워집니다. 삭제할까요?';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      '이 흐름은 실행 중입니다. 삭제하면 진행 중인 작업이 취소됩니다. 삭제할까요?';

  @override
  String get taskFlowCardDeleteRecordConfirm => '이 흐름 기록과 하위 작업 기록을 삭제할까요?';

  @override
  String get taskFlowCardDeleteConfirm => '이 흐름 기록을 삭제할까요?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      '흐름 취소 상태를 저장할 수 없습니다. 다시 삭제해 보세요.';

  @override
  String get taskFlowCardStillRunning => '취소한 뒤에도 흐름이 계속 실행 중입니다.';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      '흐름 기록 삭제 상태를 저장할 수 없습니다. 다시 삭제해 보세요.';

  @override
  String get taskFlowCardConfirm => '확인';

  @override
  String get taskFlowCardWaiting => '대기 중';

  @override
  String get taskFlowCardRunning => '실행 중';

  @override
  String get taskFlowCardPaused => '일시 중지됨';

  @override
  String get taskFlowCardCompleted => '완료';

  @override
  String get taskFlowCardFailed => '실패';

  @override
  String get taskFlowCardCanceled => '취소됨';

  @override
  String get taskFlowCardInterrupted => '중단됨';

  @override
  String get taskFlowCardSucceeded => '건너뜀';

  @override
  String get taskFlowCardPause => '흐름 일시 중지';

  @override
  String get taskFlowCardResume => '흐름 재개';

  @override
  String get taskFlowCardResumeInterrupted => '중단된 단계부터 다시 시작';

  @override
  String get taskFlowCardCancel => '취소';

  @override
  String get unifiedTaskType => '작업 유형';

  @override
  String get unifiedTaskCreatedAt => '생성 시간';

  @override
  String get unifiedTaskCompletedAt => '완료 시간';

  @override
  String get unifiedTaskResultStatus => '결과 상태';

  @override
  String get unifiedTaskPartialResult => '부분 결과입니다. 내용이 불완전할 수 있습니다';

  @override
  String get unifiedTaskErrorDetails => '오류 세부 정보';

  @override
  String get unifiedTaskViewErrorDetails => '오류 세부 정보 보기';

  @override
  String get unifiedTaskOcrPerImage => '이미지를 각각 인식';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return '이미지 $index';
  }

  @override
  String get unifiedTaskOcrPending => '인식 대기 중';

  @override
  String get unifiedTaskOcrRunning => '인식 중';

  @override
  String get unifiedTaskCompleted => '완료';

  @override
  String get unifiedTaskIncomplete => '불완전한 결과';

  @override
  String get unifiedTaskOcrFailed => '인식 실패';

  @override
  String get unifiedTaskCancelled => '취소됨';

  @override
  String get unifiedTaskWaitingStart => '시작 대기 중...';

  @override
  String get unifiedTaskSteps => '단계';

  @override
  String get unifiedTaskStartNow => '지금 시작';

  @override
  String get unifiedTaskOpenFile => '파일 열기';

  @override
  String get unifiedTaskRetrySave => '저장만 재시도';

  @override
  String get unifiedTaskRetryPartialSave => '부분 결과 저장만 재시도';

  @override
  String get unifiedTaskSavePartialResult => '부분 결과 저장';

  @override
  String get unifiedTaskRetry => '재시도';

  @override
  String get unifiedTaskCancel => '취소';

  @override
  String get unifiedTaskDelete => '삭제';

  @override
  String get unifiedTaskFormatUnsupported => '이 형식은 미리보기를 지원하지 않습니다';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return '불러오기 실패: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return '재생 실패: $error';
  }

  @override
  String get unifiedTaskAudioFile => '오디오 파일';

  @override
  String get unifiedTaskPreviewLoadFailed => '미리보기를 불러올 수 없습니다';

  @override
  String get unifiedTaskUnknownSize => '크기 알 수 없음';

  @override
  String get unifiedTaskUnnamedRecording => '제목 없는 녹음';

  @override
  String get unifiedTaskPause => '일시 중지';

  @override
  String get unifiedTaskClearTask => '작업 지우기';

  @override
  String get unifiedTaskContinue => '계속';

  @override
  String get unifiedTaskRemoveFromList => '목록에서 제거';

  @override
  String get unifiedTaskSynthesisText => '합성된 텍스트';

  @override
  String get unifiedTaskStatus => '상태';

  @override
  String get unifiedTaskDetails => '세부 정보';

  @override
  String get unifiedTaskSynthesisError => '합성 오류 세부 정보';

  @override
  String get unifiedTaskClose => '닫기';

  @override
  String get unifiedTaskRawRequestResponse => '원시 요청 및 응답';

  @override
  String get unifiedTaskRawRequestBody => '원시 요청 본문:';

  @override
  String get unifiedTaskRawResponseBody => '원시 응답 본문:';

  @override
  String get commonJustNow => '방금 전';

  @override
  String commonMinutesAgo(Object count) {
    return '$count분 전';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count시간 전';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds초';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String get unifiedTaskTypeOcr => '이미지 문자 인식';

  @override
  String get unifiedTaskTypeAsr => '음성 전사';

  @override
  String get unifiedTaskTypeAudioSeparation => '오디오 분리';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return 'OCR: $basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return '오디오 분리: $basename';
  }

  @override
  String get unifiedTaskTypeChat => '어시스턴트 채팅';

  @override
  String get unifiedTaskPlayAudio => '오디오 재생';

  @override
  String get unifiedTaskPauseAudio => '오디오 일시 중지';

  @override
  String get catcatchFlowActionNotStarted =>
      '흐름 작업이 시작되지 않았습니다. 흐름 상태를 확인한 뒤 다시 시도하세요.';

  @override
  String catcatchFlowActionFailed(Object error) {
    return '흐름 작업 실패: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      '페이지 자동 검색 시간이 초과되었습니다. 이 페이지에 로그인하거나 사용자 스크립트를 설정하세요. 미디어가 감지되면 ‘흐름 계속’을 선택하세요.';

  @override
  String get browserRecoveryContinue => '흐름 계속';

  @override
  String get catcatchSkipped => '건너뜀(처리할 항목 없음)';

  @override
  String catCatchDetailMediaResources(Object count) {
    return '미디어 리소스 $count개를 찾았습니다';
  }

  @override
  String catCatchDetailResources(Object count) {
    return '리소스 $count개를 찾았습니다';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return '브라우저에서 리소스 $count개를 찾았습니다';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return '리소스 $total개를 찾았습니다(재생 목록 세그먼트 $segments개)';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return '리소스 $count개를 찾았습니다. 하나를 선택하세요.';
  }

  @override
  String get catCatchDetailAutoSelectFirst => '첫 번째 결과를 자동으로 선택하고 다운로드를 시작했습니다';

  @override
  String get catCatchDetailAutoSelectRemaining => '결과 1개가 남아 자동으로 다운로드를 시작했습니다';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return '.$extension 형식은 변환할 필요가 없어 건너뛰었습니다';
  }

  @override
  String get catCatchDetailSkipNoExtension => '이 형식은 변환할 필요가 없어 변환을 건너뛰었습니다';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return '길이 $duration으로 필터링한 후 결과 $remaining개가 남았습니다(조건에 맞지 않는 리소스 $removed개 제외)';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return '리소스 $count개가 모두 길이 $duration 필터에 맞습니다';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '$count시간';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '$count분';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count초';
  }

  @override
  String get catcatchRetryStep => '이 단계 다시 시도';

  @override
  String catcatchCollapseSegments(Object count) {
    return '세그먼트 $count개 숨기기';
  }

  @override
  String catcatchShowSegments(Object count) {
    return '세그먼트 $count개 표시';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '리소스 $total개 중 $selected개 선택됨';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '미디어 리소스 $count개 감지됨';
  }

  @override
  String get catcatchFlowSelectOrCombine => '(리소스 하나를 선택하거나 오디오와 동영상 쌍을 결합하세요)';

  @override
  String get catcatchSelectMultiple => '(탭하여 선택, 여러 항목 선택 가능)';

  @override
  String get catcatchWaitingForResources => '흐름 리소스 대기 중';

  @override
  String catcatchDownloadSelected(Object count) {
    return '선택한 리소스 $count개 다운로드';
  }

  @override
  String get catcatchSelectResources => '다운로드할 리소스 선택';

  @override
  String get catcatchPossibleSplit => '⚠ 오디오와 동영상 스트림이 분리되어 있을 수 있습니다';

  @override
  String get catcatchSplitExplanation =>
      '이 리소스들은 같은 동영상의 오디오와 동영상 스트림으로 분리되어 있을 수 있습니다. 두 스트림을 결합하거나 하나만 다운로드할 수 있습니다.';

  @override
  String get catcatchAudioStream => '🎵 오디오 스트림';

  @override
  String get catcatchVideoStream => '🎬 동영상 스트림';

  @override
  String get catcatchMergeAudioVideo => '오디오와 동영상 결합';

  @override
  String get catcatchVideoOnly => '동영상만';

  @override
  String get catcatchAudioOnly => '오디오만';

  @override
  String get catcatchSegmentsPlaylistPreview => '재생 목록으로 세그먼트 미리보기';

  @override
  String get catcatchPreviewAudio => '오디오 미리보기';

  @override
  String get catcatchPreviewVideo => '동영상 미리보기';

  @override
  String catcatchDuration(Object duration) {
    return '길이: $duration';
  }

  @override
  String get catcatchSegment => '세그먼트';

  @override
  String get catcatchPlaylist => '재생 목록';

  @override
  String get catcatchFullVideo => '전체 동영상';

  @override
  String get catcatchSeparateTracks => '트랙 분리';

  @override
  String get catcatchPreviewPlaylistOnly => '재생 목록으로 미리보기';

  @override
  String get catcatchPreviewUnsupported => '미리보기를 지원하지 않습니다';

  @override
  String get catcatchUnknownFormat => '알 수 없는 형식';

  @override
  String get catcatchNeedPlaylistProcessing => '재생 목록 처리가 필요합니다';

  @override
  String get catcatchSpecialFormatDetected => '특수 형식이 감지되었습니다';

  @override
  String catcatchPlaylistInfo(Object format) {
    return '이 리소스는 재생 목록($format)입니다. 재생 가능한 동영상으로 만들려면 재생 목록을 분석하고 모든 세그먼트를 다운로드한 뒤 결합해야 합니다.';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return '다운로드한 파일은 표준 MP4가 아니라 $format입니다. 내장된 순수 Dart 리먹서가 MP4로 변환합니다(TS/FLV/EV1은 외부 종속성이 필요하지 않습니다).';
  }

  @override
  String get catcatchContinueBeforeConfirm => '형식 처리 방법을 확인하기 전에 흐름을 재개하세요';

  @override
  String get catcatchAutoProcess => '자동으로 처리';

  @override
  String get catcatchKeepOriginalFormat => '원래 형식 유지';

  @override
  String get catcatchResumeSupported => '이어받기를 지원합니다';

  @override
  String get catcatchResumeUnsupported => '이 사이트는 이어받기를 지원하지 않습니다';

  @override
  String get catcatchPauseDownload => '다운로드 일시 중지';

  @override
  String get catcatchResumeDownload => '다운로드 재개';

  @override
  String get catcatchRestartDownload => '다시 다운로드';

  @override
  String get catcatchPendingFormatAction => '흐름 리소스 대기 중';

  @override
  String get quitDialogTitle => '앱을 종료할까요?';

  @override
  String quitDialogRunningTasks(Object count) {
    return '작업 $count개가 실행 중입니다. 종료하면 작업이 중단됩니다. 종료할까요?';
  }

  @override
  String get quitDialogNoTasks => 'Stroom을 종료할까요?';

  @override
  String get quitDialogCancel => '취소';

  @override
  String get quitDialogExit => '종료';

  @override
  String get searchPanelNewConversation => '새 대화';

  @override
  String get searchPanelTitle => '대화 검색';

  @override
  String get searchPanelHint => '키워드 입력…';

  @override
  String get searchPanelByTitle => '제목으로 검색';

  @override
  String get searchPanelByContent => '내용으로 검색';

  @override
  String searchPanelResults(Object count) {
    return '결과 $count개';
  }

  @override
  String get searchPanelPrompt => '검색할 키워드를 입력하세요';

  @override
  String get searchPanelNoResults => '일치하는 대화가 없습니다';

  @override
  String get topicItemNew => '새 주제';

  @override
  String get topicItemUnpin => '고정 해제';

  @override
  String get topicItemPin => '고정';

  @override
  String get topicItemRename => '이름 변경';

  @override
  String get topicItemAutoName => '자동 이름 지정';

  @override
  String get topicItemDelete => '삭제';

  @override
  String get galleryChoiceTitle => '이미지 소스 선택';

  @override
  String get galleryChoiceDevice => '기기 갤러리';

  @override
  String get galleryChoiceDeviceDescription => '기기에 있는 사진과 동영상 찾아보기';

  @override
  String get galleryChoiceApp => '앱 갤러리';

  @override
  String get galleryChoiceAppDescription => '앱 갤러리에서 선택';

  @override
  String get appMediaUnreadable => '파일을 읽을 수 없습니다';

  @override
  String appMediaLoadError(Object error) {
    return '파일을 불러오지 못했습니다: $error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return '선택 해제($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return '완료($count)';
  }

  @override
  String get appMediaConfirmSelection => '완료';

  @override
  String get appMediaEmptyFolder => '이 폴더는 비어 있습니다';

  @override
  String get appMediaRoot => '루트 폴더로 이동';

  @override
  String appMediaParentFolder(Object name) {
    return '뒤로: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '파일 $count개 선택됨';
  }

  @override
  String get chatAlbumPickerTitle => '앱 앨범';

  @override
  String get chatAlbumPickerEmpty => '사용 가능한 이미지가 없습니다';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 이미지 선택됨',
      one: '$count개 이미지 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => '파일 선택';

  @override
  String get chatFilePickerTabText => '텍스트';

  @override
  String get chatFilePickerTabImages => '이미지';

  @override
  String get chatFilePickerTabVideos => '동영상';

  @override
  String get chatFilePickerTabAudio => '오디오';

  @override
  String get chatFilePickerEmpty => '사용 가능한 파일이 없습니다';

  @override
  String get chatFilePickerLoadFailed => '파일을 불러오지 못했습니다';

  @override
  String get chatVideoPickerTitle => '앱 동영상 선택';

  @override
  String get chatVideoPickerEmpty => '사용 가능한 동영상이 없습니다';

  @override
  String get imagePreviewCrop => '자르기';

  @override
  String get imagePreviewEdit => '편집';

  @override
  String get imagePreviewLoadFailed => '이미지를 불러오지 못했습니다';

  @override
  String runningElapsed(Object elapsed) {
    return '실행 시간: $elapsed';
  }

  @override
  String get chatAttachmentFile => '파일 첨부';

  @override
  String get chatAttachmentCamera => '사진 촬영';

  @override
  String get chatAttachmentDeviceGallery => '기기 갤러리';

  @override
  String get chatAttachmentDeviceFiles => '기기 파일';

  @override
  String get chatAttachmentAppFiles => '앱 파일';

  @override
  String fileManagerTodayTime(Object time) {
    return '오늘 $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return '어제 $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days일 전 $time';
  }

  @override
  String get markdownGenerating => '생성 중…';

  @override
  String get htmlPreview => '미리보기';

  @override
  String get htmlReturnToCard => '카드로 돌아가기';

  @override
  String get htmlGenerating => '생성 중…';

  @override
  String get htmlFullscreen => '전체 화면으로 보기';

  @override
  String get htmlViewCode => '코드 보기';

  @override
  String get codeScrollToBottom => '맨 아래로 스크롤';

  @override
  String get codeSave => '저장';

  @override
  String get codeDisableWrap => '줄 바꿈 끄기';

  @override
  String get codeEnableWrap => '줄 바꿈 켜기';

  @override
  String codeCopyFailed(Object error) {
    return '복사하지 못했습니다: $error';
  }

  @override
  String get codeCopied => '복사됨';

  @override
  String get codeCopy => '복사';

  @override
  String get codeEmptySave => '코드가 비어 있어 저장할 수 없습니다';

  @override
  String get codeSaveTitle => '코드 저장';

  @override
  String codeSavedTo(Object path) {
    return '저장 위치: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get fileManagerCopy => '복사';

  @override
  String get fileManagerMove => '이동';

  @override
  String get fileManagerRename => '이름 변경';

  @override
  String get fileManagerExport => '내보내기';

  @override
  String get fileManagerDelete => '삭제';

  @override
  String get fileManagerAncestorFolders => '상위 폴더';

  @override
  String get fileManagerRoot => '루트';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$count개 선택됨';
  }

  @override
  String get fileManagerSelectAll => '모두 선택';

  @override
  String get fileManagerRenameUndo => '최근 일괄 이름 변경 결과 및 실행 취소';

  @override
  String fileManagerSortBy(Object field) {
    return '정렬($field)';
  }

  @override
  String get fileManagerSortCreated => '만든 날짜순 정렬';

  @override
  String get fileManagerSortModified => '수정한 날짜순 정렬';

  @override
  String get fileManagerSortName => '이름순 정렬';

  @override
  String get fileManagerSortSize => '크기순 정렬';

  @override
  String get fileManagerListView => '목록 보기';

  @override
  String get fileManagerThumbnailView => '썸네일 보기';

  @override
  String get fileManagerCreateFolder => '폴더 만들기';

  @override
  String get fileManagerRefresh => '목록 새로고침';

  @override
  String get fileManagerEmptyFolder => '이 폴더는 비어 있습니다';

  @override
  String get fileManagerNoFiles => '파일 없음';

  @override
  String get fileManagerBackRoot => '루트로 이동';

  @override
  String fileManagerBackFolder(Object name) {
    return '뒤로: $name';
  }

  @override
  String get fileManagerMultiSelect => '여러 항목 선택';

  @override
  String get fileManagerOpen => '열기';

  @override
  String get fileManagerPreview => '미리보기';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '파일 $files개, 하위 폴더 $folders개';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '하위 폴더 $count개';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '파일 $count개';
  }

  @override
  String get fileManagerEmptyFolderLabel => '빈 폴더';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return '파일 “$name.$format”이(가) 이미 있습니다';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return '이름을 변경하지 못했습니다: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => '대상 폴더 선택';

  @override
  String get fileManagerAlreadyAtDestination => '파일이 이미 대상 위치에 있습니다';

  @override
  String get fileManagerMoveNameConflict =>
      '대상 위치에 같은 이름의 파일이 있습니다. 이동을 취소했습니다.';

  @override
  String fileManagerMoveFailed(Object error) {
    return '이동하지 못했습니다: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => '복사할 폴더 선택';

  @override
  String fileManagerCopyFailed(Object error) {
    return '복사하지 못했습니다: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => '삭제 확인';

  @override
  String get fileManagerDeleteFileConfirm => '이 파일을 삭제할까요? 이 작업은 취소할 수 없습니다.';

  @override
  String get fileManagerCancel => '취소';

  @override
  String fileManagerDeleteFailed(Object error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere => '폴더가 이미 대상 위치에 있습니다. 작업을 취소했습니다.';

  @override
  String get fileManagerFolderConflict =>
      '대상 위치에 같은 이름의 폴더가 있거나 대상 폴더가 선택한 폴더 안에 있습니다. 작업을 취소했습니다.';

  @override
  String get fileManagerBatchDeleteTitle => '일괄 삭제 확인';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '선택한 항목 $count개를 삭제할까요? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return '일괄 삭제하지 못했습니다: $error';
  }

  @override
  String get fileManagerExportConflict => '선택한 파일과 폴더의 내보내기 경로가 서로 충돌합니다';

  @override
  String get fileManagerSelectedAlreadyThere =>
      '선택한 파일이 이미 대상 위치에 있습니다. 이동을 취소했습니다.';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return '일괄 이동하지 못했습니다: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      '선택 항목에 이름이 중복된 파일이 있습니다. 복사를 취소했습니다. 한 번에 하나씩 복사하세요.';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return '일괄 복사하지 못했습니다: $error';
  }

  @override
  String get fileManagerClosedError => '파일 페이지가 닫혀 있습니다';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return '일괄 이름 변경에 실패했습니다: $error';
  }

  @override
  String get fileManagerFolderNameHint => '폴더 이름 입력';

  @override
  String get fileManagerCreate => '만들기';

  @override
  String get fileManagerFolderExists => '폴더가 이미 있습니다';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return '폴더를 만들지 못했습니다: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return '폴더 “$name”을(를) 만들었습니다';
  }

  @override
  String get fileManagerRenameFolderTitle => '폴더 이름 변경';

  @override
  String get fileManagerNewNameHint => '새 이름 입력';

  @override
  String get fileManagerTargetFolderConflict =>
      '대상 위치에 같은 이름의 폴더가 이미 있습니다. 작업을 취소했습니다.';

  @override
  String get fileManagerMoveFolderTitle => '폴더 이동…';

  @override
  String get fileManagerCopyFolderTitle => '폴더 복사…';

  @override
  String get fileManagerFolderSelfConflict =>
      '대상 위치에 같은 이름의 폴더가 있거나 대상이 폴더 자체입니다. 작업을 취소했습니다.';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return '폴더 “$name”을(를) 삭제할까요? 안에 있는 파일 $count개도 삭제됩니다.';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '빈 폴더 “$name”을(를) 삭제할까요?';
  }

  @override
  String get fileManagerDeleteFolderTitle => '폴더 삭제 확인';

  @override
  String fileManagerRefreshFailed(Object error) {
    return '새로고침 실패: $error';
  }

  @override
  String get fileManagerRefreshed => '파일 목록을 새로고침했습니다';

  @override
  String get fileManagerRenameFileTitle => '파일 이름 변경';

  @override
  String get fileManagerFormat => '형식';

  @override
  String get fileManagerFolderAtDestination => '폴더가 이미 대상 위치에 있습니다';

  @override
  String get folderPickerTitle => '폴더 선택';

  @override
  String get folderPickerExists => '폴더가 이미 있습니다';

  @override
  String folderPickerCreateFailed(Object error) {
    return '폴더를 만들지 못했습니다: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return '폴더 목록을 새로고침하지 못했습니다: $error';
  }

  @override
  String get folderPickerInstruction => '클릭하여 선택하고 두 번 클릭하여 폴더 열기';

  @override
  String get folderPickerFileName => '파일 이름';

  @override
  String get folderPickerFileNameHint => '파일 이름 입력';

  @override
  String get folderPickerBack => '상위 폴더로 이동';

  @override
  String folderPickerPath(Object path) {
    return '루트 > $path';
  }

  @override
  String get folderPickerRoot => '루트';

  @override
  String get folderPickerCurrentFolder => '현재 폴더';

  @override
  String get folderPickerSubfolders => '하위 폴더';

  @override
  String get folderPickerExistingFolders => '기존 폴더';

  @override
  String get folderPickerCreateNew => '새 폴더 만들기';

  @override
  String get folderPickerFolderNameHint => '폴더 이름 입력';

  @override
  String get folderPickerCancelCreate => '만들기 취소';

  @override
  String get folderPickerCancel => '취소';

  @override
  String get folderPickerConfirm => '완료';

  @override
  String batchRunReadFailed(Object error) {
    return '파일 목록을 읽지 못했습니다: $error';
  }

  @override
  String get batchRunPreparing => '준비 중…';

  @override
  String get batchRunUndo => '실행 취소';

  @override
  String get batchRunRename => '이름 변경';

  @override
  String batchRunFailedAction(Object label) {
    return '$label할 수 없습니다';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label 항목 $count개';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed개 성공, $failed개 실패, $remaining개 남음';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return '실패: $id → $name';
  }

  @override
  String get batchRunReportCopied => '실행 보고서를 복사했습니다';

  @override
  String get batchRunCopyFailed => '복사에 실패했습니다. 다시 시도하세요.';

  @override
  String batchRunWorking(Object label) {
    return '$label 중…';
  }

  @override
  String get batchRunTitle => '일괄 이름 변경 결과';

  @override
  String get batchRunStoppedRetain =>
      '중지해도 완료된 항목은 유지됩니다. 결과 페이지에서 실행을 취소할 수 있습니다.';

  @override
  String get batchRunFailedRemaining => '실패했습니다. 남은 항목은 처리되지 않았습니다.';

  @override
  String get batchRunUndoInfo =>
      '실행 취소하면 이번 작업에서 이름을 바꾼 항목이 원래 이름으로 돌아갑니다. 이후 파일 목록이 변경된 경우에는 실행 취소가 거부됩니다.';

  @override
  String get batchRunUncertain =>
      '일부 항목의 상태를 확인할 수 없습니다. 파일 목록을 확인하세요. 파일을 덮어쓰지 않도록 자동 실행 취소를 사용할 수 없습니다.';

  @override
  String get batchRunUndoing => '원래 이름으로 복원 중…';

  @override
  String get batchRunStopping => '중지 중…';

  @override
  String get batchRunStopRemaining => '남은 항목 중지';

  @override
  String get batchRunCopyReport => '보고서 복사';

  @override
  String batchRunUndoRemaining(Object count) {
    return '남은 $count개 실행 취소 계속하기';
  }

  @override
  String get batchRunUndoCompleted => '완료된 이름 변경 실행 취소';

  @override
  String get batchRunDone => '완료';

  @override
  String get codeEditorTitle => '매개변수 값 편집';

  @override
  String get codeEditorFormat => '서식 지정';

  @override
  String get codeEditorCancel => '취소';

  @override
  String get codeEditorConfirm => '확인';

  @override
  String get codeEditorInvalidJson => 'JSON 형식이 잘못되었습니다. 저장하기 전에 수정하세요.';

  @override
  String get codeEditorParamPath => '매개변수 이름 경로(전송 시 중첩 JSON으로 변환됨)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return '$line행 $column열: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON 형식 오류: $message';
  }

  @override
  String get codeEditorInvalidFormat => '잘못된 JSON 형식';

  @override
  String get toolCallCompacted => '요약됨';

  @override
  String get mermaidSaveEmpty => 'Mermaid 코드가 비어 있어 저장할 내용이 없습니다.';

  @override
  String mermaidFolderLoadFailed(String error) {
    return '폴더를 불러오지 못했습니다: $error';
  }

  @override
  String get mermaidSaveTitle => 'Mermaid 다이어그램 저장';

  @override
  String get mermaidSaveHint => '.mmd 파일을 저장할 폴더를 선택하거나 만드세요';

  @override
  String get mermaidSaveFilenameHint => '파일 이름 입력(.mmd 확장자는 자동으로 추가됨)';

  @override
  String get mermaidFilenameEmpty => '파일 이름을 입력해야 합니다';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return '텍스트 저장소에 저장했습니다: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get mermaidPrepareEngine => '렌더링 엔진 준비 중…';

  @override
  String get mermaidRetry => '다시 시도';

  @override
  String get batchRuleEmpty => '비워 둘 수 없습니다';

  @override
  String get batchRuleNumber => '숫자를 입력하세요';

  @override
  String get batchRulePositive => '0보다 큰 숫자를 입력하세요';

  @override
  String batchRuleMin(String min) {
    return '최소 $min이어야 합니다';
  }

  @override
  String batchRuleMax(String max) {
    return '$max 이하여야 합니다';
  }

  @override
  String get batchRulePrefix => '접두사';

  @override
  String get batchRuleSuffix => '접미사';

  @override
  String get batchRuleStart => '시작값';

  @override
  String get batchRuleStep => '간격';

  @override
  String get batchRuleDigits => '자릿수';

  @override
  String get batchRuleSeparator => '구분자';

  @override
  String get batchRuleRestartFolder => '각 폴더에서 번호 다시 시작';

  @override
  String get batchRuleNumberHelp =>
      '번호는 미리보기 순서대로 매겨집니다. 제외된 항목에는 번호를 사용하지 않습니다. 간격은 음수나 0일 수 있습니다.';

  @override
  String get batchRuleFind => '찾기';

  @override
  String get batchRuleReplace => '바꿀 내용(비워 두면 삭제)';

  @override
  String get batchRuleCaseSensitive => '대소문자 구분';

  @override
  String get batchRuleRegex => '정규식';

  @override
  String get batchRuleFirstOnly => '첫 번째 일치 항목만 바꾸기';

  @override
  String get batchRuleRegexHelp =>
      '캡처 그룹: \$1, \$2; 전체 일치: \$0; 달러 기호 자체: \$\$. 예: ^IMG_(\\d+)\$ → Photo_\$1';

  @override
  String get batchRuleFindRequired => '이 규칙을 사용하려면 찾을 텍스트를 입력하세요.';

  @override
  String get batchRuleBeginning => '시작';

  @override
  String get batchRuleEnd => '끝';

  @override
  String get batchRulePosition => '위치';

  @override
  String get batchRuleInsertText => '삽입할 텍스트';

  @override
  String get batchRuleBeforeChar => 'N번째 문자 앞';

  @override
  String get batchRulePositionHelp =>
      '위치는 1부터 시작하며, 끝을 넘는 위치는 텍스트 끝에 추가됩니다. 결합된 이모지는 한 글자로 계산됩니다.';

  @override
  String get batchRuleFromBeginning => '앞에서부터';

  @override
  String get batchRuleFromEnd => '뒤에서부터';

  @override
  String get batchRuleFromChar => 'N번째 문자부터';

  @override
  String get batchRuleCount => '개수';

  @override
  String get batchRuleDeleteHelp =>
      '삭제 후 이름이 비게 되면 실행 전에 뒤에 오는 삽입 규칙으로 텍스트를 추가해야 합니다.';

  @override
  String get batchRuleUpper => '대문자로';

  @override
  String get batchRuleLower => '소문자로';

  @override
  String get batchRuleFirstUpper => '첫 글자 대문자로';

  @override
  String get batchRuleTitleCase => '각 단어의 첫 글자를 대문자로';

  @override
  String get batchRuleTemplate => '새 이름 템플릿';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return '강의_${n}_$name';
  }

  @override
  String batchRuleTemplateHelp(
    String name,
    String n,
    String folder,
    String created,
    String modified,
    String ext,
  ) {
    return '$name 원래 이름 · $n 순번 · $folder 폴더 이름\n$created 만든 날짜 · $modified 수정한 날짜 · $ext 원래 확장자\n날짜 형식은 YYYY-MM-DD입니다. 날짜가 없으면 알림이 표시됩니다. 템플릿은 기본 이름 전체를 바꾸며 확장자는 자동으로 유지됩니다.';
  }

  @override
  String get batchRuleTrim => '앞뒤 공백 제거';

  @override
  String get batchRuleCollapseSpaces => '연속된 공백을 하나로 바꾸기';

  @override
  String get batchRuleActions => '규칙 작업';

  @override
  String get batchRuleDuplicate => '규칙 복제';

  @override
  String get batchRuleRemove => '규칙 삭제';

  @override
  String get batchRuleMoveUp => '규칙 위로 이동';

  @override
  String get batchRuleMoveDown => '규칙 아래로 이동';

  @override
  String get batchDlgSavePreset => '프리셋 저장';

  @override
  String get batchDlgPresetName => '프리셋 이름';

  @override
  String get batchDlgPresetHint => '규칙과 순서는 저장하지만 제외 항목이나 직접 지정한 이름은 저장하지 않습니다';

  @override
  String get batchDlgCancel => '취소';

  @override
  String get batchDlgSave => '저장';

  @override
  String get batchDlgOverwriteTitle => '기존 프리셋을 덮어쓸까요?';

  @override
  String batchDlgOverwriteBody(String name) {
    return '“$name”의 규칙을 업데이트합니다.';
  }

  @override
  String get batchDlgOverwrite => '덮어쓰기';

  @override
  String get batchDlgManagePresets => '프리셋 관리';

  @override
  String get batchDlgNoPresets => '저장된 프리셋이 없습니다';

  @override
  String get batchDlgDeletePreset => '프리셋 삭제';

  @override
  String get batchDlgDone => '완료';

  @override
  String get batchDlgEditName => '이름을 개별 편집';

  @override
  String get batchDlgBaseName => '기본 이름';

  @override
  String get batchDlgOverrideHelp => '이 이름이 규칙 적용 결과를 대신합니다';

  @override
  String batchDlgExtensionRetained(String extension) {
    return '.$extension 확장자는 자동으로 유지됩니다';
  }

  @override
  String get batchDlgConfirm => '확인';

  @override
  String get batchDlgHelp => '안내';

  @override
  String get batchDlgClose => '닫기';

  @override
  String get batchDlgLoadPreset => '프리셋 불러오기(규칙을 대체하고 직접 지정한 이름 삭제)';

  @override
  String get batchDlgLoad => '프리셋 불러오기';

  @override
  String get batchDlgSaving => '저장 중…';

  @override
  String get batchDlgReset => '모든 규칙과 포함 항목 초기화';

  @override
  String get batchDlgRuleInstructions =>
      '규칙은 위에서 아래 순서로 적용됩니다. 복사, 이동 또는 사용 중지할 수 있습니다. 파일 확장자는 그대로 유지됩니다.';

  @override
  String get batchDlgSortName => '이름';

  @override
  String get batchDlgSortCreated => '만든 날짜';

  @override
  String get batchDlgSortModified => '수정한 날짜';

  @override
  String get batchDlgSortSize => '크기';

  @override
  String get batchDlgAscending => '오름차순';

  @override
  String get batchDlgDescending => '내림차순';

  @override
  String get batchDlgFolderSort => '폴더가 먼저 표시되며 이름이 같으면 폴더별로 정렬됩니다.';

  @override
  String get batchDlgAddRule => '＋ 규칙 추가';

  @override
  String get batchDlgMaxRules => '규칙은 최대 50개까지 설정할 수 있습니다';

  @override
  String get batchDlgPreviewWorking => '미리보기 계산 중… 규칙을 계속 편집하거나 취소할 수 있습니다.';

  @override
  String get batchDlgSearch => '원래 이름, 새 이름 또는 폴더 검색';

  @override
  String get batchDlgFilterAll => '전체';

  @override
  String get batchDlgFilterChanged => '변경됨';

  @override
  String get batchDlgFilterErrors => '문제';

  @override
  String get batchDlgFilterUnchanged => '변경되지 않음';

  @override
  String get batchDlgFilterExcluded => '제외됨';

  @override
  String get batchDlgParticipants => '포함할 항목 선택';

  @override
  String get batchDlgIncludeAll => '모두 포함';

  @override
  String get batchDlgOnlyFiles => '파일만';

  @override
  String get batchDlgOnlyFolders => '폴더만';

  @override
  String get batchDlgExcludeAll => '모두 제외';

  @override
  String get batchDlgScope => '포함 항목';

  @override
  String get batchDlgCopyList => '목록 복사';

  @override
  String get batchDlgConflictBlock => '이름 충돌: 실행 차단';

  @override
  String get batchDlgConflictSuffix => '이름 충돌: (2), (3)… 추가';

  @override
  String get batchDlgNoMatches => '필터와 일치하는 항목이 없습니다';

  @override
  String get batchDlgRoot => '루트';

  @override
  String get batchDlgFile => '파일';

  @override
  String get batchDlgFolder => '폴더';

  @override
  String batchDlgTargetFolder(String folder) {
    return '대상 폴더: $folder';
  }

  @override
  String get batchDlgEditNameTooltip => '이름을 개별 편집';

  @override
  String get batchDlgRestoreNameTooltip => '규칙으로 생성한 이름 복원';

  @override
  String get batchDlgCopied => '전체 미리보기 목록을 복사했습니다(CSV)';

  @override
  String get batchDlgCopyFailed => '복사에 실패했습니다. 다시 시도하세요.';

  @override
  String get batchDlgHelpTitle => '일괄 이름 변경 안내';

  @override
  String get batchDlgHelpDismiss => '알겠습니다';

  @override
  String get batchDlgRulesTab => '규칙';

  @override
  String batchDlgPreviewTab(String count) {
    return '미리보기($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return '항목 $count개 이름 변경';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      '프리셋을 불러오지 못했습니다. 규칙은 계속 편집하고 실행할 수 있습니다.';

  @override
  String get batchDlgPreviewFailed => '미리보기를 계산하지 못했습니다. 규칙을 조정한 뒤 다시 시도하세요.';

  @override
  String batchDlgSavedName(String name) {
    return '프리셋 저장됨: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get batchDlgPresetWriteFailed => '프리셋을 저장하지 못했습니다.';

  @override
  String batchDlgDeleteFailed(String error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String get batchDlgSavePresetFallback => '프리셋 저장';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return '미리보기 · 변경 $changes개 · 문제 $conflicts개 · 제외 $excluded개';
  }

  @override
  String get batchDlgInvalidInput => '잘못된 규칙 입력을 수정하세요. 아직 미리보기에 반영되지 않았습니다.';

  @override
  String get batchDlgConflictError => '충돌 또는 잘못된 이름이 있어 적용할 수 없습니다. 규칙을 조정하세요.';

  @override
  String get batchDlgManualNameStatus => '직접 지정한 이름';

  @override
  String get batchDlgPendingRename => '이름 변경 준비 완료';

  @override
  String get batchDlgCsvHeader => '원래 경로,원래 이름,대상 경로,상태';

  @override
  String get batchDlgHelpBody =>
      '1. 프리셋을 선택하거나 규칙을 켠 다음 규칙을 복사하고 필요에 따라 순서를 조정하세요.\n\n2. 미리보기에는 적용될 이름이 표시됩니다. 검색과 필터는 표시만 바꿉니다. 항목 선택을 해제하면 해당 항목이 제외되고 번호가 다시 계산됩니다. 이름을 개별 편집하거나 규칙 적용 결과를 복원할 수 있습니다.\n\n3. 실행 전에 모든 문제를 해결하세요. 자동 접미사는 파일을 덮어쓰지 않고 중복 이름을 처리합니다. 이름이 서로 바뀌는 폴더는 별도 묶음으로 이름을 변경하세요.\n\n4. 실행 중 나중 항목을 중지할 수 있으며 현재 항목은 먼저 완료됩니다. 결과 페이지에서 완료된 변경 사항을 확인하고 실행을 취소할 수 있습니다. 실행 후 목록이 변경되면 실행 취소가 차단됩니다.\n\n이 작업은 이름과 폴더 경로만 변경하며 파일 내용과 확장자는 그대로 둡니다. 상위 폴더 이름을 변경해도 선택된 하위 항목의 이름은 변경할 수 있으며, 상위 폴더를 이동하면 하위 항목도 함께 이동합니다.';

  @override
  String batchDlgPreviewCount(String count) {
    return '미리보기($count)';
  }

  @override
  String get batchBuiltinPhoto => '사진: 날짜와 번호';

  @override
  String get batchBuiltinCourse => '강의: 이름과 번호 통일';

  @override
  String get batchBuiltinDownloads => '다운로드: 공백 정리';

  @override
  String get taskListDetail => '세부정보';

  @override
  String get taskListOwnershipChecking => '작업 소유권 확인 중';

  @override
  String get taskListOwnershipFailed => '작업 흐름 기록을 읽지 못해 작업을 사용할 수 없습니다';

  @override
  String get taskListViewFlow => '작업 흐름 보기';

  @override
  String get taskListPause => '일시 중지';

  @override
  String get taskListClear => '작업 지우기';

  @override
  String get taskListResume => '재개';

  @override
  String get taskListRetry => '다시 시도';

  @override
  String get taskListDismissError => '오류 닫기';

  @override
  String get taskListRemove => '목록에서 제거';

  @override
  String get taskListSynthesisErrorTitle => '합성 오류 세부정보';

  @override
  String get taskListClose => '닫기';

  @override
  String get taskListOriginalExchange => '원래 요청 및 응답';

  @override
  String get taskListOriginalRequest => '원래 요청 본문:';

  @override
  String get taskListOriginalResponse => '원래 응답 본문:';

  @override
  String get taskFlowIoTypeText => '텍스트';

  @override
  String get taskFlowIoTypeAudio => '오디오';

  @override
  String get taskFlowIoTypeVideo => '동영상';

  @override
  String get taskFlowIoTypeImage => '이미지';

  @override
  String get taskFlowIoTypeLink => '링크';

  @override
  String get taskFlowIoTypeFile => '파일';

  @override
  String get taskFlowIoTypeAny => '모든 유형';

  @override
  String get mermaidZoomOut => '축소';

  @override
  String get mermaidZoomIn => '확대';

  @override
  String get mermaidFullscreen => '전체 화면';

  @override
  String get mermaidSaveButton => '저장';

  @override
  String get mermaidSourceButton => '소스 보기';

  @override
  String get mermaidDiagramSemantic => '다이어그램 보기';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'CatCatch 하위 작업 삭제 상태를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      '합성 하위 작업 삭제 상태를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      '백그라운드 하위 작업 삭제 상태를 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get mathParseError => '수식 구문 분석 오류';

  @override
  String get mermaidEmptyPlaceholder => '표시할 Mermaid 코드가 없습니다';

  @override
  String get mathClose => '닫기';

  @override
  String get mermaidLoadTimeout =>
      'Mermaid를 불러오는 시간이 초과되었습니다. 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get mermaidCdnLoadFailed =>
      'Mermaid를 불러오기 위해 cdn.jsdelivr.net에 연결하지 못했습니다.';

  @override
  String get mermaidLoadingDiagram => '다이어그램 불러오는 중…';

  @override
  String get mermaidEngineInitFailed => '다이어그램 렌더러를 초기화하지 못했습니다. 다시 시도하세요.';

  @override
  String get mermaidPageTimeout => '페이지 로드 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get mermaidCodeLoadFailed => '다이어그램 코드를 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String mermaidPageLoadFailed(String description) {
    return '페이지를 불러오지 못했습니다: $description';
  }

  @override
  String get mermaidLoadingEngine => '렌더링 엔진 불러오는 중…';

  @override
  String get mermaidRenderErrorTitle => '다이어그램 렌더링 오류';

  @override
  String get taskFlowOutputVideoAudioDownstream => '동영상 또는 오디오(다음 단계에서 필터링)';

  @override
  String get taskFlowOutputUnknown => '알 수 없음';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label 중지됨: $completed개 성공, $failed개 실패, $remaining개 남음';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Mermaid 렌더링 오류: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Mermaid 초기화 오류: $message';
  }

  @override
  String get mermaidResourceError => 'Mermaid 다이어그램의 리소스를 불러오지 못했습니다.';

  @override
  String get taskFlowParamRecognitionModel => '인식 모델';

  @override
  String get taskFlowParamSynthesisModel => '합성 모델';

  @override
  String get taskFlowParamSaveFolder => '저장 폴더';

  @override
  String get taskFlowParamResourceSelection => '리소스 선택';

  @override
  String get taskFlowParamOutputType => '출력 유형';

  @override
  String get taskFlowParamVideoFolder => '동영상 저장 폴더';

  @override
  String get taskFlowParamAudioFolder => '오디오 저장 폴더';

  @override
  String get taskFlowParamExpectedDuration => '예상 길이';

  @override
  String get taskFlowParamVoice => '음성';

  @override
  String get taskFlowParamSpeechRate => '말하기 속도';

  @override
  String get taskFlowParamAssistant => '어시스턴트';

  @override
  String get taskFlowHintResourceSelection =>
      '수동 모드에서는 직접 선택할 수 있습니다. 자동 모드는 기존 규칙을 따릅니다. 모호할 때 질문 모드는 안전한 선택지가 하나뿐이면 자동으로 선택하고, 그렇지 않으면 확인을 위해 리소스 목록을 엽니다.';

  @override
  String get taskFlowHintOutputType =>
      '동영상 또는 오디오를 명시적으로 선택하세요. 다음 단계 입력 유형에 따라 리소스를 필터링하려면 ‘다음 단계 따르기’를 선택하세요. 다음 단계가 두 유형을 모두 받거나 다음 단계가 없으면 두 유형 모두 유지됩니다.';

  @override
  String get taskFlowHintExpectedDuration =>
      '동영상 길이로 리소스를 필터링합니다. 필터링하지 않으려면 비워 두세요.';

  @override
  String get taskFlowHintVoice => '음성을 선택하세요. 해당 음성과 일치하는 합성 모델이 자동으로 선택됩니다.';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      '이 블록 유형은 더 이상 지원되지 않습니다. 이 단계를 바꾸거나 삭제하세요.';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return '다음 블록에는 $requiredType 유형이 필요합니다. 다운로더는 동영상 또는 오디오를 출력할 수 있습니다. 다음 단계나 출력 정책을 변경하세요.';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source의 유형은 모두이지만 “$block”에는 텍스트, 링크, 이미지, 오디오, 동영상 또는 파일 유형을 명시해야 합니다. 입력 유형을 바꾸거나 블록을 이동 또는 교체하거나 변경을 취소하세요.';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source의 유형은 $actualType이지만 “$block”에는 $requiredType 유형이 필요합니다. 입력 유형을 바꾸거나 블록을 이동 또는 교체하거나 변경을 취소하세요.';
  }

  @override
  String get fileManagerSortFieldCreated => '만든 날짜';

  @override
  String get fileManagerSortFieldModified => '수정한 날짜';

  @override
  String get fileManagerSortFieldName => '이름';

  @override
  String get fileManagerSortFieldSize => '크기';

  @override
  String get fileManagerSortDateNewest => '최신순';

  @override
  String get fileManagerSortDateOldest => '오래된순';

  @override
  String get fileManagerSortSizeLargest => '큰 항목부터';

  @override
  String get fileManagerSortSizeSmallest => '작은 항목부터';

  @override
  String get catcatchStatusRunning => '실행 중';

  @override
  String get catcatchStatusCompleted => '완료';

  @override
  String get catcatchStatusFailed => '실패';

  @override
  String get catcatchStatusPaused => '일시 중지됨';

  @override
  String get catcatchStatusWaiting => '대기 중';

  @override
  String get catcatchStepFetching => '웹페이지 가져오는 중';

  @override
  String get catcatchStepAnalyzing => '미디어 분석 중';

  @override
  String get catcatchStepParsingPlaylist => '재생 목록 분석 중';

  @override
  String get catcatchStepFiltering => '길이로 필터링 중';

  @override
  String get catcatchStepUserSelecting => '선택 대기 중';

  @override
  String get catcatchStepDownloading => '다운로드 중';

  @override
  String get catcatchStepConverting => '변환/결합 중';

  @override
  String get catcatchStepSaving => '기기에 저장 중';

  @override
  String get bgStepConnectServer => '서버에 연결 중';

  @override
  String get bgStepUploadImage => '이미지 업로드 중';

  @override
  String get bgStepWaitRecognition => '인식 대기 중';

  @override
  String get bgStepParseResult => '결과 분석 중';

  @override
  String get bgStepSaveFile => '파일 저장 중';

  @override
  String get bgStepUploadAudio => '오디오 업로드 중';

  @override
  String get bgStepTranscribing => '전사 중';

  @override
  String get bgStepReceiveResult => '결과 수신 중';

  @override
  String get bgStepSeparateAudio => '오디오 분리 중';

  @override
  String get bgStepSaveToFile => '파일로 저장 중';

  @override
  String get bgStepSendRequest => '요청 전송 중';

  @override
  String get bgStepWaitReply => '응답 대기 중';

  @override
  String get fileManagerSortNameAscending => '가나다순';

  @override
  String get fileManagerSortNameDescending => '가나다 역순';

  @override
  String get taskFlowValidationNoSteps => '이 작업 흐름에는 단계가 없습니다. 먼저 블록을 추가하세요.';

  @override
  String get taskFlowValidationInputRequired =>
      '이 작업 흐름을 실행하려면 입력을 하나 이상 추가하세요.';

  @override
  String get taskFlowValidationFlowRemoved => '이 작업 흐름이 삭제되었습니다. 다시 선택하세요.';

  @override
  String get taskFlowValidationInputTypeChanged =>
      '초기 입력 유형이 변경되었습니다. 실행 입력을 다시 선택하세요.';

  @override
  String get taskFlowValidationSnapshotMissing =>
      '이전 기록에 실행 스냅샷이 없습니다. 최신 설정으로 다시 시도하세요.';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      '어시스턴트 모델이 없거나 사용할 수 없습니다. 채팅 페이지에서 모델을 선택하거나 어시스턴트의 기본 모델을 설정하세요.';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      '저장된 단계 파일이 없거나 비어 있거나 읽을 수 없습니다. 작업 흐름을 다시 실행하세요.';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      '이 블록 유형은 더 이상 지원되지 않습니다. 이 단계를 바꾸거나 삭제하세요.';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return '다음 블록에는 $requiredType 유형이 필요합니다. 다운로더는 오디오 또는 동영상을 출력할 수 있습니다. 다음 단계나 출력 정책을 변경하세요.';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '“$block”에 “$parameter” 매개변수가 필요합니다. 블록 설정에서 구성하세요.';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return '이전 모델 선택을 확인해야 합니다. “$block” 설정에서 모델을 다시 선택하세요.';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return '모델이 없거나 제공자에서 사용할 수 없습니다. “$block” 설정에서 모델을 다시 선택하고 제공자 URL과 키를 확인하세요.';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return '어시스턴트가 없거나 삭제되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      '어시스턴트 모델이 삭제되었거나 제공자 설정을 사용할 수 없습니다. 어시스턴트 설정에서 모델을 다시 선택하세요.';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return '리소스 선택 정책 또는 출력 유형이 잘못되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return '출력 유형이 잘못되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return '리소스 선택 정책이 잘못되었습니다. “$block” 설정에서 다시 선택하세요.';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return '입력 $index: 파일이 없거나 비어 있거나 읽을 수 없습니다. 다시 선택하세요.';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return '입력 $index: 올바른 HTTP 또는 HTTPS 링크를 입력하세요.';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return '입력 $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules => '규칙은 최대 50개까지 설정할 수 있습니다.';

  @override
  String get batchRuleValidationDigits => '자릿수는 1~12여야 합니다.';

  @override
  String get batchRuleValidationNumberRange =>
      '시작 번호와 간격은 ±999,999,999 범위여야 합니다.';

  @override
  String get batchRuleValidationReplacementLength => '바꿀 내용이 너무 깁니다.';

  @override
  String get batchRuleValidationRegex => '정규식이 잘못되었습니다.';

  @override
  String get batchRuleValidationDeleteIndex => '삭제 위치는 1부터 시작해야 합니다.';

  @override
  String get batchRuleValidationInsertLength => '삽입할 텍스트가 너무 깁니다.';

  @override
  String get batchRuleValidationTemplateNumber =>
      '템플릿 번호 설정이 잘못되었습니다. 자릿수는 1~12여야 하며 시작값과 간격은 ±999,999,999 범위여야 합니다.';

  @override
  String get batchRuleValidationTemplateLength => '템플릿이 너무 깁니다.';

  @override
  String get batchRuleValidationTemplateVariable =>
      '알 수 없는 템플릿 변수이거나 닫는 중괄호가 없습니다.';

  @override
  String get batchRuleTypeNumber => '번호 추가';

  @override
  String get batchRuleTypeReplace => '찾아 바꾸기';

  @override
  String get batchRuleTypeInsert => '텍스트 삽입';

  @override
  String get batchRuleTypeDelete => '문자 삭제';

  @override
  String get batchRuleTypeCase => '대소문자 변경';

  @override
  String get batchRuleTypeTemplate => '이름 템플릿';

  @override
  String get batchRuleTypeCleanup => '공백 정리';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return '입력 $index: 텍스트를 입력하거나 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return '입력 $index: 이미지가 20MB를 초과합니다. 더 작은 이미지를 선택하세요.';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return '입력 $index: 첨부 파일이 10MB를 초과합니다. 더 작은 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return '입력 $index: 파일 유형은 $actualType이지만 $requiredType 유형이 필요합니다. 다른 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return '입력 $index: 어시스턴트 채팅은 SVG 이미지 첨부를 지원하지 않습니다. PNG 또는 JPEG로 변환하세요.';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return '입력 $index: 어시스턴트 채팅은 $mime 이미지 첨부를 지원하지 않습니다. PNG, JPEG, GIF 또는 WebP로 변환하세요.';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return '입력 $index: 어시스턴트 채팅은 $mime 오디오 첨부를 지원하지 않습니다. MP3, WAV 또는 M4A로 변환하세요.';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return '입력 $index: 이 Anthropic 채팅 형식은 $type 첨부를 지원하지 않습니다. 해당 미디어를 지원하는 어시스턴트를 선택하세요.';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return '입력 $index: 이 Anthropic 채팅 형식은 이미지와 PDF 첨부만 지원합니다. 지원되는 파일을 선택하세요.';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return '입력 $index: 어시스턴트 채팅에서 이미지를 10MB 미만으로 압축하지 못했습니다. 더 작은 이미지를 선택하세요.';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return '입력 $index: 텍스트 첨부가 올바른 UTF-8 형식이 아닙니다. 변환한 뒤 다시 시도하세요.';
  }

  @override
  String get assistantParamValueTypeString => '문자열';

  @override
  String get assistantParamValueTypeNumber => '숫자';

  @override
  String get assistantParamValueTypeBoolean => '불리언';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields => '제공자 이름, API URL, API 키를 입력해야 합니다.';

  @override
  String get providerJsonSizePositive => '요청 JSON 크기는 0보다 큰 MiB 값이어야 합니다.';

  @override
  String get providerCustomParamRequired => '사용자 지정 매개변수 이름과 값을 입력하세요.';

  @override
  String providerParamNameInvalid(String name) {
    return '매개변수 이름이 잘못되었습니다(점으로 구분한 항목은 비어 있을 수 없음): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return '이미 있는 매개변수입니다: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return '매개변수 “$name”의 기본값이 올바른 JSON이 아닙니다: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return '매개변수 “$name”의 숫자 옵션을 입력하세요.';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return '매개변수 “$name”의 값이 올바른 숫자가 아닙니다: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      '다른 추론 매개변수를 활성화하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String providerReasoningError(String error) {
    return '추론 매개변수 오류: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return '추론 매개변수와 사용자 지정 매개변수의 이름이 같습니다: $name';
  }

  @override
  String get providerMaxTokensMissing => '최대 출력 토큰이 켜져 있지만 값이 입력되지 않았습니다.';

  @override
  String get providerMaxTokensPositive => '최대 출력 토큰은 양의 정수여야 합니다.';

  @override
  String get providerSeedInteger => '난수 시드는 정수여야 합니다.';

  @override
  String get providerNotConfigured => '설정되지 않음';

  @override
  String get providerAudioChunkingTitle => '오디오 분할';

  @override
  String get providerAudioChunkingHint =>
      '스마트 분할은 오디오와 분할 후보 지점을 분석하고 문장 끝을 우선합니다. 분할 구간은 서로 겹치지 않습니다.';

  @override
  String get providerChunkingMode => '분할 방식';

  @override
  String get providerChunkNone => '분할 안 함';

  @override
  String get providerChunkSmart => '스마트 분할(권장)';

  @override
  String get providerChunkFixedDuration => '고정 길이로 분할';

  @override
  String get providerChunkFixedSize => '고정 크기로 분할';

  @override
  String get providerCompressionTitle => '압축 인코딩';

  @override
  String get providerCompressionHint =>
      '이 옵션을 켜면 일반 대체 처리에서 먼저 WAV 전체를 압축합니다. 인코딩된 파일이나 요청 본문이 여전히 한도를 초과하면 원본 PCM을 여러 구간으로 나누어 인코딩합니다.';

  @override
  String get providerCompressionMode => '압축 방식';

  @override
  String get providerCompressionNone => '없음(그대로 전송)';

  @override
  String get providerCompressionAdpcm => 'ADPCM(약 4배 압축)';

  @override
  String get providerCompressionFlac => 'FLAC(무손실, 약 2배 압축, 권장)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM 손실 압축(4:1)입니다. 순수 Dart로 구현했으며 음질은 전사에 적합합니다.';

  @override
  String get providerCompressionFlacDescription =>
      '순수 Dart로 구현한 무손실 FLAC 압축입니다. 크기를 약 절반으로 줄입니다.';

  @override
  String get providerCompressionWavDescription => '압축하지 않고 WAV 파일로 전송합니다.';

  @override
  String get providerLlmParams => 'LLM 매개변수';

  @override
  String get providerEnabledParamsHelp => '활성화한 매개변수는 API 요청의 기본값으로 전송됩니다.';

  @override
  String get providerTemperatureLabel => '온도';

  @override
  String get providerTemperatureHelp =>
      '출력의 무작위성을 조절합니다. 값이 높을수록 더 창의적인 결과가 나옵니다.';

  @override
  String get providerTopPHelp => '단어 선택에 사용할 누적 확률을 조절하는 뉴클리어스 샘플링 매개변수입니다.';

  @override
  String get providerFrequencyPenaltyLabel => '빈도 페널티';

  @override
  String get providerFrequencyPenaltyHelp => '반복되는 단어를 줄입니다. 음수 값은 반복을 늘립니다.';

  @override
  String get providerPresencePenaltyLabel => '존재 페널티';

  @override
  String get providerPresencePenaltyHelp =>
      '새로운 주제를 유도합니다. 음수 값은 이전 주제로 돌아가도록 유도합니다.';

  @override
  String get providerMaxOutputTokensLabel => '최대 출력 토큰';

  @override
  String providerOptionalExample(String example) {
    return '선택 사항(예: $example)';
  }

  @override
  String get providerResponseTokensHelp => '응답 하나에서 생성할 최대 토큰 수입니다.';

  @override
  String get providerSeedLabel => '난수 시드';

  @override
  String get providerSeedHelp => '같은 결과를 재현하려면 값을 설정하세요.';

  @override
  String get providerChunkSmartDescription =>
      '오디오와 분할 후보 지점을 분석해 문장 끝이나 긴 무음 구간을 우선하며 구간이 겹치지 않도록 합니다. 기본값: 최소 20초 / 목표 45초 / 최대 60초. 일반 대체 처리에서만 사용하며 압축 분할은 PCM WAV만 지원합니다.';

  @override
  String get providerChunkDurationDescription =>
      'N초마다 분할합니다(기본값 60초). 간단하지만 음성이 잘릴 수 있습니다. 일반 대체 처리에서만 사용하며 압축 분할은 PCM WAV만 지원합니다.';

  @override
  String get providerChunkSizeDescription =>
      '먼저 오디오 데이터 크기로 분할한 다음 인코딩된 파일과 요청 본문 크기에 맞게 조정합니다. 일반 대체 처리에서만 사용하며 압축 분할은 PCM WAV만 지원합니다.';

  @override
  String get providerChunkNoneDescription =>
      '분할하지 않습니다. 전체 압축 후에도 파일이 한도를 초과하면 거부됩니다.';

  @override
  String get providerNameLabel => '제공자 이름';

  @override
  String get providerNameHint => '제공자 이름 입력';

  @override
  String get providerApiUrlLabel => 'API URL';

  @override
  String get providerApiUrlHint => '전체 API 엔드포인트 URL 입력';

  @override
  String providerApiKeyHint(String hint) {
    return '힌트: $hint';
  }

  @override
  String get providerEndpointTypeLabel => '엔드포인트 유형';

  @override
  String get providerEndpointOpenAi => 'OpenAI 호환(Chat Completions)';

  @override
  String get providerEndpointAnthropic => 'Anthropic 형식(Messages API)';

  @override
  String get providerAnthropicEndpointHelp =>
      '공식 Anthropic Messages API 형식을 사용합니다(x-api-key 헤더). API URL 예시: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      '공식 OpenAI Chat Completions 호환 형식을 사용합니다(Bearer 헤더). API URL 예시: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => '기본 요청 JSON 크기';

  @override
  String get providerUseAppDefault => '앱 기본값을 사용하려면 비워 두세요';

  @override
  String get providerModelJsonBudgetHelp =>
      '모델에서 이 값을 재정의할 수 있습니다. 제공자와 모델 모두 값을 설정하지 않으면 기본값은 20MiB입니다.';

  @override
  String get providerRequestParamsHelp =>
      '요청에는 활성화된 제공자 및 모델 매개변수가 모두 사용됩니다. 이름이 겹치면 모델 값이 우선합니다.';

  @override
  String get providerUploadSettings => '업로드 설정';

  @override
  String get providerUploadMethodHelp => '오디오 업로드 방식과 크기 제한은 제공자마다 다릅니다.';

  @override
  String get providerUploadMethod => '업로드 방식';

  @override
  String get providerMultipart => '멀티파트(일반)';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => '최대 업로드 크기';

  @override
  String get providerFallbackStrategy => '대체 전략';

  @override
  String get providerFallbackMethod => '대체 방식';

  @override
  String get providerPreprocessing => '오디오 전처리';

  @override
  String get providerPreprocessingHelp =>
      '전사 정확도에 영향을 거의 주지 않으면서 오디오 파일 크기를 줄입니다.';

  @override
  String get providerPreprocessingMethod => '전처리 방식';

  @override
  String get providerUploadMultipartHelp =>
      'multipart/form-data로 직접 업로드합니다. 요청 본문에는 오디오, 폼 필드, 멀티파트 경계가 포함됩니다.';

  @override
  String get providerUploadBase64Help =>
      '일부 제공자의 멀티파트 전용 제한을 피할 수 있도록 JSON에 Base64로 담아 전송합니다. Base64 인코딩으로 늘어난 크기와 JSON 필드도 업로드 한도에 포함됩니다.';

  @override
  String get providerUploadUrlHelp =>
      '제공자가 다운로드할 수 있는 공개 URL을 입력하세요. 매우 큰 파일도 지원합니다(예: Together AI 1GB).';

  @override
  String get providerUploadBudgetHelp =>
      '이 값은 원본 오디오 대체 처리를 시작하는 기준이자 최종 요청 본문의 크기 제한입니다. 앱은 원본 오디오, 인코딩된 파일, 업로드 크기를 확인합니다. 멀티파트에는 폼 필드와 경계가 포함되고 Base64 JSON에는 인코딩으로 늘어난 크기와 필드가 포함됩니다. 기본값 25MB는 OpenAI 오디오 API의 한도와 같습니다.';

  @override
  String get providerFallbackTriggerHelp =>
      '원본 오디오나 전체 요청 본문이 한도를 초과하면 실행됩니다. 구체적인 대체 방식(Base64)이 일반 대체 방식(압축/분할)보다 우선합니다.';

  @override
  String get providerFallbackNone => '없음(즉시 거부)';

  @override
  String get providerFallbackSpecific => '구체적인 대체 방식(Base64)';

  @override
  String get providerFallbackGeneric => '일반 대체 방식(압축/분할)';

  @override
  String get providerFallbackAll => '모두 시도(권장)';

  @override
  String get providerFallbackSpecificHelp =>
      'Base64 JSON을 시도합니다. Base64 인코딩으로 늘어난 크기와 JSON 필드를 포함한 요청 본문이 한도 이내일 때만 전송합니다.';

  @override
  String get providerFallbackGenericHelp =>
      '켜져 있으면 먼저 WAV 전체를 압축합니다. 그래도 한도를 초과하고 분할이 켜져 있으면 원본 PCM을 나누어 각 구간을 인코딩합니다. PCM WAV만 지원합니다.';

  @override
  String get providerFallbackAllHelp =>
      '먼저 요청 본문 한도 내에서 Base64를 시도합니다. 그다음 켜져 있으면 WAV 전체를 압축합니다. 그래도 한도를 초과하고 분할이 켜져 있으면 원본 PCM을 나누어 각 구간을 인코딩합니다. PCM WAV만 지원합니다.';

  @override
  String get providerFallbackRejectHelp => '파일이 한도를 초과하면 대체 처리를 시도하지 않고 거부합니다.';

  @override
  String get providerPreprocessNone => '없음';

  @override
  String get providerPreprocessResample => 'WAV 최적화(16kHz 모노, 권장)';

  @override
  String get providerPreprocessResampleHelp =>
      '16kHz로 리샘플링하고 모노로 믹스합니다. 전사 정확도에 미치는 영향은 적으면서 크기를 약 4~6배 줄입니다.';

  @override
  String get providerPreprocessNoneHelp => '전처리 없이 원본 그대로 전송합니다.';

  @override
  String get assistantDefaultsScopeHelp =>
      '기본 모델과 도구는 이 어시스턴트에서 새로 만드는 대화에만 적용됩니다. 기존 대화는 기존 설정을 유지합니다. 도구 출력 자르기는 이 어시스턴트의 모든 대화에 적용됩니다.';

  @override
  String get assistantDefaultModelTitle => '기본 모델';

  @override
  String get assistantDefaultModelHelp =>
      '새 대화에서 사용할 모델입니다. 대화에서 직접 선택하게 하려면 설정하지 마세요.';

  @override
  String get assistantNoDefault => '설정되지 않음';

  @override
  String get assistantNoModelsAvailable =>
      '사용할 수 있는 모델이 없습니다. 설정에서 LLM 제공자를 구성하세요.';

  @override
  String get assistantDefaultToolsTitle => '기본 활성화 도구';

  @override
  String get assistantDisabledToolsHelp => '사용 중지한 도구는 새 대화에서 자동으로 켜지지 않습니다.';

  @override
  String get assistantUnconfiguredToolsHelp =>
      '기본 도구가 설정되지 않았습니다. 새 대화에서는 모든 도구가 자동으로 활성화됩니다.';

  @override
  String get assistantEnableAll => '모두 활성화';

  @override
  String get assistantDisableAll => '모두 사용 중지';

  @override
  String get assistantNoToolsAvailable => '사용할 수 있는 도구가 없습니다';

  @override
  String get assistantTruncateToolOutput => '도구 출력 자르기';

  @override
  String get assistantTruncateToolOutputHelp =>
      '모델에 보내기 전에 각 도구 결과에서 허용할 최대 문자 수입니다. 이 어시스턴트의 모든 대화에 적용됩니다.';

  @override
  String get assistantEnableTruncation => '출력 자르기 사용';

  @override
  String assistantTruncatedTo(String count) {
    return '긴 결과는 $count자로 줄입니다';
  }

  @override
  String get assistantSendFullResult => '전체 결과 전송(저장 한도 50KB 적용)';

  @override
  String get assistantMaxCharacters => '최대 문자 수';

  @override
  String get assistantCharactersNotTokens => '단위: 문자(토큰 아님)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return '기본값: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return '허용 범위: $minimum~$maximum자';
  }

  @override
  String get assistantNewConversationPreview => '새 대화 미리보기';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled/$total개 활성화';
  }

  @override
  String get assistantAllToolsAutoEnabled => '설정되지 않아 모든 도구가 자동으로 활성화됩니다';

  @override
  String get assistantMoreActions => '추가 작업';

  @override
  String get assistantChooseEmoji => '이모지 선택';

  @override
  String get assistantNameLabel => '어시스턴트 이름';

  @override
  String get assistantDescriptionOptional => '설명(선택 사항)';

  @override
  String get assistantSelectionTitle => '어시스턴트 선택';

  @override
  String get assistantMarketTooltip => '어시스턴트 마켓플레이스';

  @override
  String get assistantDefaultPrompt =>
      '당신은 유용한 AI 어시스턴트입니다. 사용자의 질문에 명확하고 친절하게 답변하세요.';

  @override
  String get assistantCreateNew => '어시스턴트 만들기';

  @override
  String get assistantEmptyState => '아직 어시스턴트가 없습니다. 새 어시스턴트를 만들어 시작하세요.';

  @override
  String get assistantCreate => '만들기';

  @override
  String get assistantReorderHint => '길게 누른 다음 드래그하여 어시스턴트 순서 변경';

  @override
  String get assistantNewNameHint => '어시스턴트 이름 입력';

  @override
  String get assistantNewDescriptionHint => '어시스턴트의 기능을 간단히 설명하세요';

  @override
  String get assistantDeleteTitle => '어시스턴트 삭제';

  @override
  String assistantDeleteConfirmation(String name) {
    return '어시스턴트 “$name”을(를) 삭제할까요? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get assistantEditTitle => '어시스턴트 편집';

  @override
  String get assistantBasicTab => '기본 설정';

  @override
  String get assistantParametersTab => '매개변수';

  @override
  String get assistantDefaultsTab => '기본값';

  @override
  String get assistantAddCustomParameter => '사용자 지정 매개변수 추가';

  @override
  String get assistantEditCustomParameter => '사용자 지정 매개변수 편집';

  @override
  String get assistantParameterName => '매개변수 이름';

  @override
  String get assistantParameterNameHint => '예: top_k 또는 provider.only';

  @override
  String get assistantParameterNameInvalid =>
      '매개변수 이름이 잘못되었습니다(점으로 구분한 항목은 비어 있을 수 없음)';

  @override
  String get assistantParameterType => '유형';

  @override
  String get assistantValue => '값';

  @override
  String get assistantTrueFalseHint => 'true 또는 false';

  @override
  String get assistantNumberHint => '숫자를 입력하세요';

  @override
  String assistantJsonHint(String example) {
    return '예: $example';
  }

  @override
  String get assistantValueHint => '값 입력';

  @override
  String get assistantCancel => '취소';

  @override
  String get assistantSave => '저장';

  @override
  String get assistantParamOverrideHelp =>
      '켜면 어시스턴트 매개변수가 모델 매개변수보다 우선하며, 끄면 모델 매개변수를 사용합니다.';

  @override
  String get assistantTemperature => '온도';

  @override
  String get assistantMaxTokens => '최대 토큰 수';

  @override
  String get assistantMaxToolCalls => '최대 도구 호출 수';

  @override
  String assistantRounds(String count) {
    return '$count회';
  }

  @override
  String get assistantUnlimited => '무제한';

  @override
  String get assistantStreamOutput => '스트리밍 출력';

  @override
  String get assistantFrequencyPenalty => '빈도 페널티';

  @override
  String get assistantPresencePenalty => '존재 페널티';

  @override
  String get assistantRandomSeed => '난수 시드';

  @override
  String get assistantNotSet => '설정되지 않음';

  @override
  String get assistantSeedValue => '시드 값';

  @override
  String get assistantIntegerSeedHint => '정수 시드를 입력하세요';

  @override
  String get assistantWebSearch => '웹 검색';

  @override
  String get assistantAddParameter => '매개변수 추가';

  @override
  String get assistantNoCustomParameters => '사용자 지정 매개변수가 없습니다';

  @override
  String get assistantRoundsLabel => '라운드 수';

  @override
  String get modelCreateTitle => '모델 추가';

  @override
  String get modelEditTitle => '모델 편집';

  @override
  String get modelDiscardTitle => '변경사항을 버릴까요?';

  @override
  String get modelDiscardBody => '저장하지 않은 변경사항이 있습니다. 버릴까요?';

  @override
  String get modelNameLabel => '모델 이름';

  @override
  String get modelNameHint => '표시 이름 입력(선택 사항)';

  @override
  String get modelIdLabel => '모델 ID';

  @override
  String modelIdExample(String id) {
    return '예: $id';
  }

  @override
  String get modelIdRequired => '모델 ID를 입력해야 합니다.';

  @override
  String get modelCustomParamRequired => '사용자 지정 매개변수 이름과 기본값을 입력해야 합니다.';

  @override
  String modelParamDuplicate(String name) {
    return '이미 있는 매개변수입니다: $name';
  }

  @override
  String modelParamReserved(String name) {
    return '예약된 OCR 매개변수 이름입니다: $name';
  }

  @override
  String get modelParamName => '매개변수 이름';

  @override
  String get modelParamDefaultValue => '매개변수 기본값';

  @override
  String get modelParamDelete => '매개변수 삭제';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return '매개변수 “$name”의 기본값이 올바른 JSON이 아닙니다: $value';
  }

  @override
  String get modelAddParameter => '매개변수 추가';

  @override
  String get modelNoCustomParams => '사용자 지정 매개변수가 없습니다';

  @override
  String get modelBasicSettings => '기본 설정';

  @override
  String get modelDiscardCancel => '취소';

  @override
  String get modelSave => '저장';

  @override
  String get modelUnsavedMaxTokens => '최대 출력 토큰이 켜져 있지만 값이 입력되지 않았습니다.';

  @override
  String get modelMaxTokensPositive => '최대 출력 토큰은 양의 정수여야 합니다.';

  @override
  String get modelSeedInteger => '난수 시드는 정수여야 합니다.';

  @override
  String get modelContextLengthRequired => '컨텍스트 길이를 입력해야 합니다.';

  @override
  String get modelContextLengthPositive => '컨텍스트 길이는 양의 정수여야 합니다.';

  @override
  String get modelAsrLanguageCode => '언어 코드(언어)';

  @override
  String get modelAsrLanguageHint => '예: zh, en, ja';

  @override
  String get modelAsrLanguageHelp => 'ISO-639-1 언어 코드입니다. 자동 감지를 사용하려면 비워 두세요.';

  @override
  String get modelTemperature => '온도';

  @override
  String get modelTemperatureHelp => '출력의 무작위성을 조절합니다. 낮은 값을 권장합니다.';

  @override
  String get modelAsrPrompt => '프롬프트';

  @override
  String get modelAsrPromptHint => '문맥 프롬프트 입력(선택 사항)';

  @override
  String get modelAsrPromptHelp => '전문 용어 목록과 같은 문맥을 제공하면 전사 정확도를 높일 수 있습니다.';

  @override
  String get modelAsrParams => 'ASR 매개변수';

  @override
  String get modelEnabledParamsHelp => '활성화한 매개변수는 API 요청의 기본값으로 전송됩니다.';

  @override
  String get modelAsrResponseFormat => '응답 형식';

  @override
  String get modelAsrResponseHelp => '반환되는 전사의 형식입니다.';

  @override
  String get modelAsrTimestampGranularity => '타임스탬프 단위';

  @override
  String get modelAsrVerboseHelp =>
      'response_format이 verbose_json일 때만 사용할 수 있습니다.';

  @override
  String get modelNoTrim => '자르지 않음';

  @override
  String get modelAudioTrimTitle => '오디오 자르기';

  @override
  String get modelAudioTrimHelp => '오디오를 자르는 방법을 선택하세요.';

  @override
  String get modelDeleteTrimPreset => '자르기 프리셋 삭제';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return '자르기 프리셋 “$name”을(를) 삭제할까요?';
  }

  @override
  String get modelAddTrimPreset => '사용자 지정 자르기 추가';

  @override
  String get modelPlayTestAudio => '테스트 오디오 재생';

  @override
  String get modelPlayingTestAudio => '재생 중…';

  @override
  String get modelParamExists => '매개변수가 이미 있습니다';

  @override
  String get asrModelIdExample => '예: whisper-1';

  @override
  String get asrPromptLabel => '프롬프트';

  @override
  String get asrResponseFormatJson => 'json – JSON';

  @override
  String get asrResponseFormatText => 'text – 일반 텍스트';

  @override
  String get asrResponseFormatSrt => 'srt – 자막';

  @override
  String get asrResponseFormatVtt => 'vtt – 자막';

  @override
  String get asrResponseFormatVerbose => 'verbose_json – 상세 JSON(타임스탬프 포함)';

  @override
  String get asrVerboseTimestampHelp =>
      'verbose_json을 선택하면 아래의 타임스탬프 단위 옵션을 사용할 수 있습니다.';

  @override
  String get asrTimestampSegment => 'segment – 세그먼트 단위';

  @override
  String get asrTimestampWord => 'word – 단어 단위';

  @override
  String get asrWordTimestampHelp => '단어 단위 타임스탬프는 세그먼트 단위보다 정확도가 낮을 수 있습니다.';

  @override
  String get reasoningAddOptionValue => '옵션 값 추가';

  @override
  String get reasoningEditOptionValue => '옵션 값 편집';

  @override
  String get reasoningOptionExample => '예: low, medium, high';

  @override
  String get reasoningOptionSelectionHelp =>
      '칩을 탭하여 값을 선택하거나 선택 해제하세요. 선택한 값이 전송되며 드래그하여 순서를 바꿀 수 있습니다. 제공자 값은 삭제할 수 없지만 선택을 해제해 숨길 수 있습니다.';

  @override
  String get reasoningAddOption => '옵션 추가';

  @override
  String get reasoningCurrentProvider => '현재: 제공자';

  @override
  String get reasoningCurrentModel => '현재: 모델 사용자 지정 값';

  @override
  String get reasoningAddEffortValue => '추론 강도 값 추가';

  @override
  String get reasoningEffortExample => '예: max, ultra, deep';

  @override
  String get reasoningAddToggle => '추론 전환 추가';

  @override
  String get reasoningToggle => '추론 전환';

  @override
  String get reasoningResetParameter => '이 매개변수 초기화';

  @override
  String get reasoningDisableToggle => '추론 전환 사용 중지';

  @override
  String get reasoningEnableToggle => '추론 전환 활성화';

  @override
  String reasoningParameterNameSource(String source) {
    return '매개변수 이름($source)';
  }

  @override
  String get reasoningNameExample => '예: thinking.type, reasoning';

  @override
  String get reasoningBooleanHelp =>
      '불리언 매개변수에는 값이 필요하지 않으며, 채팅 패널에서 켜기/끄기 스위치를 제공합니다.';

  @override
  String get reasoningOnValue => '활성화 시 값';

  @override
  String get reasoningOnExample => '예: enabled, true';

  @override
  String get reasoningOffValue => '비활성화 시 값';

  @override
  String get reasoningOffExample => '예: disabled, false';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return '활성화하면 ‘$onValue’를 전송하고, 비활성화하면 ‘$offValue’를 전송합니다.';
  }

  @override
  String get reasoningAddEffort => '추론 수준 추가';

  @override
  String get reasoningFillToggleFirst => '먼저 추론 전환 설정을 완료하세요';

  @override
  String get reasoningFillToggleBeforeEffort =>
      '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get reasoningAddValue => '값 추가';

  @override
  String get reasoningJsonValue => 'JSON 값';

  @override
  String reasoningJsonExample(String example) {
    return '예: $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      '칩을 탭해 선택하거나 선택 해제하세요. 선택한 값은 채팅 추론 패널에 표시되며 드래그해 순서를 바꿀 수 있습니다. 제공업체 값은 삭제할 수 없지만 숨길 수 있습니다.';

  @override
  String get reasoningAddParameter => '추론 매개변수 추가';

  @override
  String get reasoningToggleIncomplete => '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get llmContextLength => '컨텍스트 길이';

  @override
  String get llmContextHint => '컨텍스트 길이 입력';

  @override
  String get llmContextHelp => '모델의 최대 컨텍스트 창 크기(토큰)입니다.';

  @override
  String get llmReasoningParams => '추론 매개변수';

  @override
  String get llmReasoningHelp =>
      '채팅의 추론 매개변수를 설정합니다. 추론 전환은 매개변수 이름과 켜기/끄기 값을 제어합니다. 추론 수준 값을 추가하고 순서를 바꾼 다음 채팅 패널에 표시할 값을 선택하세요. 이 페이지를 열 때 제공업체 값이 동기화됩니다. 이 설정은 모델 매개변수 사용 가능 여부를 제어하며, 채팅 패널 전환은 별도로 관리됩니다.';

  @override
  String get llmAddReasoningParam => '추론 매개변수 추가';

  @override
  String get llmCustomEndpointType => '사용자 지정 엔드포인트 유형';

  @override
  String get llmInheritEndpointType => '비활성화하면 제공업체 설정의 엔드포인트 유형을 사용합니다.';

  @override
  String get llmEndpointType => '엔드포인트 유형';

  @override
  String get llmEndpointOpenAi => 'OpenAI 호환(Chat Completions)';

  @override
  String get llmEndpointAnthropic => 'Anthropic 형식(Messages API)';

  @override
  String get llmEndpointHelp =>
      '엔드포인트 유형은 제공업체 API URL과 일치해야 합니다. 유형을 변경하면 이 모델로 새 대화를 만들 때 사용하는 형식이 달라집니다.';

  @override
  String get llmTopPHelp => '누클리어스 샘플링 매개변수로, 단어 선택에 사용할 누적 확률을 제어합니다.';

  @override
  String get llmFrequencyPenaltyLabel => '빈도 페널티';

  @override
  String get llmFrequencyPenaltyHelp => '반복을 줄입니다. 음수 값은 반복을 늘립니다.';

  @override
  String get llmPresencePenaltyLabel => '존재 페널티';

  @override
  String get llmPresencePenaltyHelp => '새로운 주제를 유도합니다. 음수 값은 반복을 유도합니다.';

  @override
  String get llmMaxTokensHint => '선택 사항, 예: 4096';

  @override
  String get llmTokensPerResponse => '응답당 생성할 최대 토큰 수입니다.';

  @override
  String get llmSeedLabel => '랜덤 시드(Seed)';

  @override
  String get llmSeedHint => '선택 사항, 예: 42';

  @override
  String get llmSeedHelp => '이 값을 설정하면 출력을 재현할 수 있습니다.';

  @override
  String get llmInheritedCustomHelp =>
      '제공업체의 사용자 지정 매개변수가 여기에 표시되며, 이 페이지를 열 때마다 동기화됩니다.';

  @override
  String get llmBooleanParamHelp => '불리언 매개변수에는 값이 필요하지 않습니다.';

  @override
  String get modelContextReq => '컨텍스트 길이는 필수입니다.';

  @override
  String get modelContextPositive => '컨텍스트 길이는 양의 정수여야 합니다.';

  @override
  String modelParamNameInvalid(String name) {
    return '매개변수 이름이 올바르지 않습니다(점으로 구분된 각 부분은 비어 있을 수 없음): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return '매개변수 ‘$name’의 $valueLabel은(는) 유한한 숫자여야 합니다: $value';
  }

  @override
  String get modelReasoningIncomplete =>
      '다른 추론 매개변수를 활성화하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get modelReasoningOptionsRequired => '추론 매개변수에 옵션 값을 하나 이상 추가하세요.';

  @override
  String modelReasoningError(String error) {
    return '추론 매개변수 오류: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return '중복된 추론 매개변수: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return '추론 매개변수와 사용자 지정 매개변수 이름이 중복됩니다: $name';
  }

  @override
  String get modelSeedRequired => '랜덤 시드가 활성화되었지만 값이 비어 있습니다.';

  @override
  String get ocrParamsTitle => 'OCR 매개변수';

  @override
  String get ocrParamsHelp =>
      'OpenAI 호환 Vision Chat Completions 형식을 사용합니다. 아래 매개변수는 선택 사항이며, 설정하지 않았거나 비활성화한 매개변수는 전송되지 않습니다. API에서 지원하는 제공업체별 매개변수는 아래에 추가하세요.';

  @override
  String get ocrRequestSizeOverride => '요청 JSON 크기 재정의';

  @override
  String get ocrInheritProvider => '비워 두면 제공업체 설정을 따릅니다';

  @override
  String get ocrBudgetDefault =>
      '비워 두면 제공업체 설정을 따릅니다. 제공업체에 값이 없으면 기본값 20 MiB를 사용합니다.';

  @override
  String ocrBudgetValue(String size) {
    return '비워 두면 제공업체 설정($size MiB)을 따릅니다. 제공업체에 값이 없으면 기본값 20 MiB를 사용합니다.';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return '오디오 $direction $seconds초 자르기';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return '처음 $seconds초 자르기';
  }

  @override
  String get audioTrimNone => '오디오를 자르지 않음';

  @override
  String get trimNameLabel => '자르기 방식 이름 *';

  @override
  String get trimNameHint => '예: 무음 구간 자르기';

  @override
  String get trimDurationLabel => '자르기 길이(초) *';

  @override
  String get trimDurationHint => '예: 0.123';

  @override
  String get trimNameAndDurationRequired => '이름과 길이를 입력해야 합니다.';

  @override
  String get trimDurationInvalid => '올바른 양의 길이를 입력하세요.';

  @override
  String get testAudioHostMissing => '호스트가 설정되지 않았습니다.';

  @override
  String get testAudioKeyMissing => '키가 설정되지 않았습니다.';

  @override
  String testAudioContentTypeError(String contentType) {
    return '응답 Content-Type이 $contentType이며, 오디오 형식이 아닙니다.';
  }

  @override
  String get testAudioEmpty => '서버가 빈 오디오 데이터를 반환했습니다.';

  @override
  String testAudioTimeoutConnection(String details) {
    return '연결 시간이 초과되었습니다. 네트워크를 확인하세요. $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return '응답 수신 시간이 초과되었습니다. 서버 응답이 너무 느립니다. $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return '요청이 취소되었습니다. $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return '네트워크 오류: $message';
  }

  @override
  String get testAudioNoBody => '응답 본문이 없습니다';

  @override
  String testAudioCorsHelp(String details) {
    return '서버에 연결할 수 없습니다. 웹에서는 CORS 또는 잘못된 API URL이 원인일 수 있습니다. 제공업체 API URL과 서버의 교차 출처 요청 허용 여부를 확인하세요. $details';
  }

  @override
  String get trimModelNameHint =>
      '표시와 식별에 사용할 알아보기 쉬운 이름입니다(예: ‘GPT-4o Mini TTS’). 같은 제공업체의 모델을 구분하려면 서로 다른 이름을 사용하세요.';

  @override
  String get trimModelIdHelp =>
      'API 호출에 사용하는 고유 식별자입니다(예: ‘gpt-4o-mini-tts’). 공급업체가 제공한 모델 ID와 일치해야 합니다.';

  @override
  String get ttsVoiceRangeTitle => '음량 범위';

  @override
  String get ttsMinVolume => '최소 음량';

  @override
  String get ttsMaxVolume => '최대 음량';

  @override
  String get ttsSpeedRangeTitle => '속도 범위';

  @override
  String get ttsMinSpeed => '최저 속도';

  @override
  String get ttsMaxSpeed => '최고 속도';

  @override
  String get ttsMaxAudioLength => '요청당 최대 오디오 길이 *';

  @override
  String get ttsAudioLengthHint => '예: 1000';

  @override
  String get ttsNoVoices => '음성이 없습니다. 탭하여 편집하세요.';

  @override
  String get ttsInstructionSupported => '모델이 지시문 매개변수를 지원합니다';

  @override
  String get ttsInstructionHelp =>
      '활성화하면 TTS 요청에 어조, 감정, 말하기 속도 등에 관한 지시문을 포함할 수 있습니다.';

  @override
  String get ttsStreamSupported => '모델이 스트리밍 출력을 지원합니다';

  @override
  String get ttsStreamHelp =>
      '스트리밍 시나리오에서 이 모델을 사용할 수 있습니다. 활성화하기 전에 모델의 스트리밍 지원 여부를 확인하세요.';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return '매개변수 ‘$name’은(는) true 또는 false여야 합니다: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired => '요청당 최대 오디오 길이는 필수입니다. 양의 정수를 입력하세요.';

  @override
  String get asrLanguageExample => '예: zh, en, ja';

  @override
  String get llmReasoningFullHelp =>
      '추론 전환은 추론 전송 여부를 제어하고 매개변수 이름과 켜기/끄기 값을 설정합니다. 추론 수준 매개변수는 하나만 사용할 수 있습니다. 값을 선택하고 드래그해 순서를 바꾸세요. 선택한 값은 채팅 추론 패널에 표시됩니다. 다른 추론 매개변수는 아래에 추가하세요. thinking.type처럼 점 표기법을 사용하는 매개변수 이름은 중첩된 JSON 객체가 됩니다. 이 페이지를 열 때 제공업체의 추론 매개변수가 동기화됩니다. 여기의 스위치는 모델 매개변수를 제어하며 채팅 추론 전환과는 별개입니다.';

  @override
  String get llmTemperatureHelp => '출력의 무작위성을 제어합니다. 값이 높을수록 더 창의적인 결과가 나옵니다.';

  @override
  String get llmBooleanValueHelp => '불리언 매개변수에는 값이 필요하지 않습니다.';

  @override
  String get reasoningDisableEffort => '추론 수준 비활성화';

  @override
  String get reasoningEnableEffort => '추론 수준 활성화';

  @override
  String get ocrJsonSizePositive => '요청 JSON 크기는 양의 MiB 값이어야 합니다.';

  @override
  String ttsRangePair(String kind) {
    return '최솟값과 최댓값 $kind을(를) 모두 입력하거나 둘 다 비워 두세요.';
  }

  @override
  String get ttsEditTrimTitle => '사용자 지정 자르기 편집';

  @override
  String ttsVoicesCount(String count) {
    return '음성($count개)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return '요청 형식으로 생성됨: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'MCP 서버 이름을 입력하세요.';

  @override
  String get mcpStdioCommandRequired => 'stdio 모드에는 명령이 필요합니다.';

  @override
  String get mcpSseUrlRequired => 'SSE 모드에는 URL이 필요합니다.';

  @override
  String get mcpEditServerTitle => 'MCP 서버 편집';

  @override
  String get mcpCreateServerTitle => '새 MCP 서버';

  @override
  String get mcpUnsavedChangesTitle => '저장하지 않은 변경사항';

  @override
  String get mcpUnsavedChangesConfirm => '저장하지 않은 변경사항이 있습니다. 버리시겠습니까?';

  @override
  String get mcpTransportType => '전송 유형';

  @override
  String get mcpServerName => '서버 이름';

  @override
  String get mcpServerNameHint => 'MCP 서버 이름 입력';

  @override
  String get mcpCommand => '명령';

  @override
  String get mcpCommandExample => '예: npx';

  @override
  String get mcpArguments => '인수';

  @override
  String get mcpArgumentsHint =>
      '인수를 쉼표로 구분하세요. 예: -y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => '예: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'API 키';

  @override
  String get mcpApiKeyHint => 'API 키 입력(선택 사항)';

  @override
  String get mcpShowKey => '키 표시';

  @override
  String get mcpHideKey => '키 숨기기';

  @override
  String get mcpDescriptionHint => '이 MCP 서버에 대한 설명 입력(선택 사항)';

  @override
  String get mcpStdioDescription =>
      'stdio는 로컬 자식 프로세스를 MCP 서버로 실행하고 표준 입력/출력으로 통신합니다. 로컬 도구에 권장됩니다.';

  @override
  String get mcpSseDescription =>
      'SSE는 HTTP SSE를 통해 원격 MCP 서버에 연결합니다. 원격 서비스에 권장됩니다.';

  @override
  String get mcpLocalStdio => '로컬(stdio)';

  @override
  String get mcpRemoteSse => '원격(SSE)';

  @override
  String get mcpSaving => '저장 중…';

  @override
  String get providerTestSafetyNote =>
      '이 테스트는 선택한 서비스에 실제 요청을 보냅니다. MCP는 읽기 전용 tools/list 메서드만 호출하고, HTTP와 웹 검색은 한 번씩 검색합니다. Todo는 기본적으로 목록을 읽습니다. 기존 데이터를 보호하려면 todos 매개변수를 생략하거나 null로 설정하세요.';

  @override
  String get providerDeleteConfigTitle => '구성 삭제';

  @override
  String get providerDeleteConfigConfirm => '이 제공업체 구성과 모든 모델을 삭제하시겠습니까?';

  @override
  String get providerCreateGroup => '새 그룹';

  @override
  String get providerEditGroup => '그룹 편집';

  @override
  String get providerGroupName => '그룹 이름';

  @override
  String get providerGroupNameExists => '이 이름을 사용하는 그룹이 이미 있습니다.';

  @override
  String get providerDeleteGroup => '그룹 삭제';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return '‘$groupName’을(를) 삭제하면 해당 구성이 ‘기타 MCP 서비스’로 이동합니다.';
  }

  @override
  String get providerMoveToGroup => '그룹으로 이동';

  @override
  String get providerUnnamed => '(이름 없음)';

  @override
  String get providerHttpSearch => 'HTTP 검색';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP 도구: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return '로컬(stdio): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return '원격(SSE): $url';
  }

  @override
  String get providerServices => '서비스 구성';

  @override
  String get providerServicesDescription =>
      '그룹별로 원격 연결, 로컬 stdio, HTTP 검색을 관리합니다.';

  @override
  String get providerCreateGroupAction => '새 그룹';

  @override
  String get providerGroupEmpty => '이 그룹에 구성이 없습니다. ‘추가’를 선택해 항목을 추가하세요.';

  @override
  String get providerBuiltinTools => '기본 제공 도구';

  @override
  String get providerBuiltinToolsDescription =>
      'Stroom이 제공하는 로컬 도구 인터페이스입니다. 웹 검색은 해당 서비스 그룹에 표시됩니다.';

  @override
  String get providerBuiltinToolInterface => '기본 제공 도구 인터페이스';

  @override
  String get providerViewInterface => '인터페이스 보기';

  @override
  String get providerConfigTitle => '구성';

  @override
  String get providerNotFound => '제공업체를 찾을 수 없습니다.';

  @override
  String get providerConfigurationHeading => '제공업체 구성';

  @override
  String get providerBuiltinWebSearchEmpty =>
      '기본 제공 웹 검색은 Google, Bing, Baidu를 지원합니다. 모델 도구 이름은 web_search입니다.';

  @override
  String get providerNoConfigsAdd => '아직 제공업체 구성이 없습니다. ‘추가’를 선택해 만드세요.';

  @override
  String get providerNoHost => '(호스트 설정 안 됨)';

  @override
  String get providerServicesAndTools => '서비스 및 도구';

  @override
  String get providerManageServicesDescription =>
      'MCP 서버, HTTP 검색, Stroom 기본 제공 도구를 관리합니다.';

  @override
  String get providerNoServices => '아직 서비스 구성이 없습니다.';

  @override
  String get providerAddServiceDescription =>
      'MCP 서비스 또는 HTTP 검색 인터페이스를 추가해 어시스턴트에서 사용하세요.';

  @override
  String get providerAddService => '서비스 추가';

  @override
  String get providerBuiltinBadge => '기본 제공';

  @override
  String get providerBuiltinTtsName => 'TTS 제공업체';

  @override
  String get providerBuiltinLlmName => 'LLM 제공업체';

  @override
  String get providerBuiltinOcrName => 'OCR 제공업체';

  @override
  String get providerBuiltinAsrName => '음성 인식 제공업체';

  @override
  String get providerBuiltinMcpName => 'MCP 제공업체';

  @override
  String get providerBuiltinSearchGroupName => '검색';

  @override
  String get providerBuiltinMcpServicesGroupName => '기타 MCP 서비스';

  @override
  String get providerConnectivityTest => '연결 테스트';

  @override
  String get providerMoveGroupTooltip => '그룹으로 이동';

  @override
  String get providerDeleteTooltip => '구성 삭제';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '항목 #개',
      one: '항목 #개',
      zero: '항목 없음',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => '그룹 작업';

  @override
  String get providerEditGroupAction => '그룹 편집';

  @override
  String get providerDeleteGroupAction => '그룹 삭제';

  @override
  String get providerAddItem => '항목 추가';

  @override
  String get providerMcpMasterLabel => 'MCP 서버';

  @override
  String get providerMcpMasterDescription =>
      'MCP 서버와 기본 제공 검색 도구를 어시스턴트 및 채팅에서 사용할 수 있는지 제어합니다.';

  @override
  String get providerEnabled => '사용';

  @override
  String get providerDisabled => '사용 안 함';

  @override
  String get providerEditSettings => '제공업체 설정 편집';

  @override
  String get providerModelList => '모델';

  @override
  String get providerNoModels => '아직 모델이 없습니다.';

  @override
  String get providerDeleteModel => '모델 삭제';

  @override
  String get providerDeleteModelConfirm => '이 모델을 삭제하시겠습니까?';

  @override
  String get providerEditConfig => '구성 편집';

  @override
  String providerCreateNamedConfig(String entryName) {
    return '새 $entryName 구성';
  }

  @override
  String get toolHttpSearchType => '연결 유형: HTTP 검색';

  @override
  String toolInterface(String name) {
    return '도구 인터페이스: $name';
  }

  @override
  String get toolParameterDefinitions => '매개변수 정의';

  @override
  String get toolHttpAddress => 'HTTP 엔드포인트 URL';

  @override
  String get toolInvalidHttpUrl => '올바른 HTTP 또는 HTTPS URL을 입력하세요.';

  @override
  String get toolBuiltinType => '연결 유형: Stroom 기본 제공 도구';

  @override
  String get toolBuiltinEnableHelp =>
      '어시스턴트의 기본 도구 설정에서 이 도구를 사용할 수 있도록 설정합니다.';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return '모델 ID: $modelId';
  }

  @override
  String get providerValueNotSet => '(설정되지 않음)';

  @override
  String get providerApiKeyInputHint => 'API 키 입력';

  @override
  String get providerSettingsTitle => '제공업체 구성';

  @override
  String get providerBasicInfoTab => '기본 정보';

  @override
  String get providerParameterSettingsTab => '매개변수 설정';

  @override
  String get providerOptionValuesReorderHelp => '옵션 값(손잡이를 길게 눌러 드래그하고 순서 변경)';

  @override
  String providerOptionIndexLabel(String index) {
    return '옵션 $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return '예: $example';
  }

  @override
  String get providerDeleteOptionTooltip => '옵션 삭제';

  @override
  String get providerAddOption => '옵션 추가';

  @override
  String get providerAddCustomParam => '매개변수 추가';

  @override
  String get providerNoCustomParams => '아직 사용자 지정 매개변수가 없습니다.';

  @override
  String get providerParamNameLabel => '매개변수 이름';

  @override
  String get providerParamDefaultValueLabel => '매개변수 기본값';

  @override
  String get providerBooleanParamNoValue =>
      '불리언 매개변수에는 값이 필요하지 않습니다. 채팅 패널에서 켜기/끄기를 전환할 수 있습니다.';

  @override
  String get providerReasoningParamsHeading => '추론 매개변수';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return '추론 전환을 사용해 채팅에서 추론을 켜거나 끕니다. 매개변수 이름과 켜기/끄기 값을 지정할 수 있습니다. 이름이 필수이고 선택 값은 선택 사항인 추론 수준 매개변수를 하나 설정할 수 있습니다. 이름만 입력하면 모델 구성에서 값을 제공할 수 있습니다. 아래 버튼으로 다른 추론 매개변수를 추가하세요. 매개변수 이름은 점 표기 중첩을 지원합니다. 예를 들어 $parameterName은(는) $jsonExample(으)로 확장됩니다.';
  }

  @override
  String get providerAddReasoningParam => '추론 매개변수 추가';

  @override
  String get providerAddReasoningToggle => '추론 전환 추가';

  @override
  String get providerReasoningToggle => '추론 전환';

  @override
  String get providerDeleteReasoningToggle => '추론 전환 삭제';

  @override
  String providerParamNameHint(String examples) {
    return '예: $examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      '불리언 매개변수에는 값이 필요하지 않습니다. 채팅 패널에서 켜기/끄기를 전환할 수 있습니다.';

  @override
  String get providerToggleOnValueLabel => '켜기 값';

  @override
  String get providerToggleOffValueLabel => '끄기 값';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return '추론이 켜져 있으면 ‘$onValue’를 보내고, 꺼져 있으면 ‘$offValue’를 보냅니다.';
  }

  @override
  String get providerAddReasoningEffort => '추론 수준 추가';

  @override
  String get providerDeleteReasoningEffort => '추론 수준 매개변수 삭제';

  @override
  String get providerReasoningEffortLockedHint =>
      '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get providerJsonValueLabel => 'JSON 값';

  @override
  String get providerReasoningOptionsHelp =>
      '옵션 값(선택 사항; 매개변수 이름만 입력하면 모델 구성이 값을 제공합니다). 손잡이를 길게 눌러 드래그하고 순서를 변경하세요.';

  @override
  String get providerParamNameNestedLabel => '매개변수 이름(점 표기 중첩 지원)';

  @override
  String get providerToggleEffortPrerequisite =>
      '추론 수준을 설정하기 전에 추론 전환 설정을 완료하세요.';

  @override
  String get providerToggleRequiredHint => '먼저 추론 전환 설정을 완료하세요.';

  @override
  String get providerDeleteCustomParam => '매개변수 삭제';

  @override
  String get modelSaveSuccess => '모델 저장됨';

  @override
  String get modelSaving => '저장 중…';

  @override
  String modelOriginalError(String error) {
    return '원래 오류: $error';
  }

  @override
  String get paramTypeStringLabel => '문자열';

  @override
  String get paramTypeNumberLabel => '숫자';

  @override
  String get paramTypeBooleanLabel => '불리언';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return '지원하지 않는 유형: $type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return '매개변수 ‘$name’은(는) 지원하지 않는 유형 ‘$type’을(를) 사용합니다. 저장하기 전에 지원되는 유형으로 바꾸거나 매개변수를 삭제하세요.';
  }

  @override
  String get paramTypeStringHint => '예: cheerful';

  @override
  String get paramTypeNumberHint => '예: 0.8';

  @override
  String get paramTypeBooleanHint => '예: true';

  @override
  String get paramTypeJsonHint => '예: ';

  @override
  String get ankiPageTitle => 'Anki 플래시카드';

  @override
  String get ankiStatsTooltip => '학습 통계';

  @override
  String get ankiBrowseCardsTooltip => '카드 둘러보기';

  @override
  String get ankiStatsTotalCards => '전체 카드';

  @override
  String get ankiStatsNewCards => '새 카드';

  @override
  String get ankiStatsLearning => '학습 중';

  @override
  String get ankiStatsDueForReview => '복습 예정';

  @override
  String get ankiStatsReviewHistory => '복습 기록';

  @override
  String get ankiStatsLearningProgress => '학습 진행 상황';

  @override
  String get ankiStatsReviewRate => '복습률';

  @override
  String get ankiBrowserSearchHint => '카드 검색...';

  @override
  String get ankiBrowserEmpty => '카드가 없습니다';

  @override
  String get ankiSyncTooltip => 'AnkiWeb 동기화';

  @override
  String get ankiNewDeckTooltip => '새 덱';

  @override
  String ankiDeckLoadError(String error) {
    return '덱을 불러오지 못했습니다: $error';
  }

  @override
  String get ankiEmptyDecksTitle => '아직 덱이 없습니다';

  @override
  String get ankiEmptyDecksDescription => '덱을 만들어 학습을 시작하세요';

  @override
  String get ankiNewDeckTitle => '새 덱';

  @override
  String get ankiDeckNameHint => '덱 이름';

  @override
  String get ankiCreateDeck => '만들기';

  @override
  String get ankiRenameDeck => '덱 이름 변경';

  @override
  String get ankiConfirm => '확인';

  @override
  String get ankiDeleteDeckTitle => '덱 삭제';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '‘$deckName’과(와) 그 안의 모든 카드를 삭제하시겠습니까?';
  }

  @override
  String get ankiAddCardTitle => '카드 추가';

  @override
  String get ankiNoteTypeLabel => '노트 유형';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return '텍스트($clozeSyntax로 삭제할 부분 표시)';
  }

  @override
  String get ankiFrontQuestionHint => '앞면(질문)';

  @override
  String get ankiBackExtraLabel => '뒷면 / 추가 정보';

  @override
  String get ankiTagsLabel => '태그(공백으로 구분)';

  @override
  String get ankiTagsHint => '예: 수학 물리';

  @override
  String get ankiAdd => '추가';

  @override
  String get ankiStatNew => '새 카드';

  @override
  String get ankiStatLearning => '학습 중';

  @override
  String get ankiStatReview => '복습';

  @override
  String get ankiAddCardAction => '카드 추가';

  @override
  String get ankiRenameAction => '이름 변경';

  @override
  String get ankiDeleteAction => '삭제';

  @override
  String get ankiNoCardContent => '카드 내용이 없습니다';

  @override
  String get ankiStudy => '학습';

  @override
  String get ankiWhiteboardTooltip => '화이트보드';

  @override
  String get ankiFrontLabel => '앞면';

  @override
  String get ankiBackLabel => '뒷면';

  @override
  String get ankiShowAnswer => '정답 보기';

  @override
  String get ankiRatingAgain => '다시';

  @override
  String get ankiRatingHard => '어려움';

  @override
  String get ankiRatingGood => '알맞음';

  @override
  String get ankiRatingEasy => '쉬움';

  @override
  String get ankiNoCardsToStudy => '지금 학습할 카드가 없습니다';

  @override
  String get ankiNoCardsHint => '새 카드를 추가하거나 나중에 다시 확인하세요';

  @override
  String get ankiBack => '뒤로';

  @override
  String get ankiSyncPageTitle => 'Anki 동기화';

  @override
  String get ankiSyncChooseMode => '동기화 모드 선택';

  @override
  String get ankiSyncModeHelp =>
      '로그인 상태는 서비스별로 따로 저장됩니다. 모드를 전환해도 데이터가 병합되거나 덮어써지지 않습니다.';

  @override
  String get ankiSyncSelfHostedMode => '자체 호스팅 서버';

  @override
  String get ankiSyncServerAddress => '서버 주소';

  @override
  String get ankiSyncServerHelp =>
      '원격 자체 호스팅 서버에는 HTTPS를 사용해야 합니다. 로컬 주소에는 HTTP를 사용할 수 있습니다. 서버는 Anki 동기화 v10을 지원해야 하며, 인증서 검증은 기본적으로 활성화되어 있습니다.';

  @override
  String get ankiSyncCustomCaTitle => '사용자 지정 CA 인증서(선택 사항)';

  @override
  String get ankiSyncCustomCaHelp => '서버가 자체 서명 인증서를 사용하는 경우에만 입력하세요.';

  @override
  String get ankiSyncOfficialHelp =>
      '공식 AnkiWeb 동기화 서비스를 사용합니다. 비밀번호는 로그인할 때만 전송되며 Stroom에 저장되지 않습니다.';

  @override
  String ankiSyncConnected(String service) {
    return '$service에 연결됨';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return '$service에 연결되지 않음';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return '$service에 로그인';
  }

  @override
  String get ankiSyncCheckServerStatus => '서버 상태 확인';

  @override
  String get ankiSyncLogout => '로그아웃';

  @override
  String get ankiSyncBothWays => '양방향 동기화';

  @override
  String get ankiSyncOverwriteServer => '서버 데이터를 로컬 데이터로 교체';

  @override
  String get ankiSyncReplaceLocal => '로컬 데이터를 서버 데이터로 교체';

  @override
  String get ankiSyncHelp =>
      '양방향 동기화는 컬렉션의 변경사항을 병합하고 미디어 파일을 전송합니다. 스키마 버전이 다르면 전체 업로드 또는 다운로드를 선택하세요. 전체 다운로드에 실패하면 기존 컬렉션과 미디어 디렉터리 복원을 시도합니다.';

  @override
  String get ankiSyncStatusRestored => '안전하게 저장된 로그인 세션을 복원했습니다';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      '저장된 로그인 세션을 읽을 수 없습니다. 다시 로그인하세요.';

  @override
  String get ankiSyncInvalidServerUrl =>
      '서버 주소는 HTTPS URL이어야 합니다. 로컬 루프백 주소에만 HTTP를 사용할 수 있습니다. 사용자 정보와 쿼리 매개변수는 허용되지 않습니다.';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return '설정을 저장하지 못했습니다: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      '서버 주소가 변경되었습니다. 계속하려면 다시 로그인하세요.';

  @override
  String get ankiSyncStatusVerifyingLogin => '로그인 확인 중…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      '로그인했습니다. 비밀번호는 저장되지 않았으며 동기화 키는 암호화해 저장했습니다.';

  @override
  String get ankiSyncLoginSuccessPromptTitle => '로그인 성공';

  @override
  String get ankiSyncLoginSuccessPromptMessage => '지금 컬렉션을 동기화하시겠습니까?';

  @override
  String get ankiSyncLoginSuccessPromptSync => '지금 동기화';

  @override
  String get ankiSyncLoginSuccessPromptLater => '계속';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      '로그인했지만 동기화 키를 안전하게 저장하지 못했습니다. 이 페이지를 닫은 후 다시 로그인해야 합니다.';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return '로그인 실패: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'AnkiWeb에 로그인';

  @override
  String get ankiSyncLoginSelfHosted => '자체 호스팅 서버에 로그인';

  @override
  String get ankiSyncEmailOrUsername => '이메일 / 사용자 이름';

  @override
  String get ankiSyncEmailOrUsernameRequired => '이메일 또는 사용자 이름을 입력하세요';

  @override
  String get ankiSyncPassword => '비밀번호';

  @override
  String get ankiSyncPasswordRequired => '비밀번호를 입력하세요';

  @override
  String get ankiSyncLogin => '로그인';

  @override
  String get ankiSyncStatusPreparingServerSettings => '서버 설정 준비 중…';

  @override
  String get ankiSyncStatusReadingCollection => '서버 컬렉션 상태 읽는 중…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      '연결되었습니다. 서버 컬렉션이 비어 있습니다.';

  @override
  String get ankiSyncStatusConnectedStatusRead => '연결되었습니다. 서버 상태를 읽었습니다.';

  @override
  String get ankiSyncStatusUpgradeClient => '이 서버에는 최신 동기화 클라이언트가 필요합니다.';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return '상태 확인 실패: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => '업로드 설정 준비 중…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle => '서버 컬렉션을 로컬 컬렉션으로 바꾸시겠습니까?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      '서버 컬렉션을 로컬 데이터로 완전히 교체합니다. 먼저 로컬 데이터베이스를 백업합니다.\n\n서버의 미디어 목록에 따라 미디어 파일은 계속 양방향으로 동기화됩니다.';

  @override
  String get ankiSyncOverwriteServerAction => '서버 컬렉션 교체';

  @override
  String get ankiSyncStatusBackingUpUploading => '컬렉션 백업 및 업로드 중…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return '서버가 로컬 컬렉션을 수락했습니다. 미디어 동기화 완료: 파일 $uploaded개 업로드, $downloaded개 다운로드, $deleted개 삭제.$backup 서버 상태를 다시 확인하세요.';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return '\n로컬 백업: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      '서버 컬렉션을 교체했지만 미디어 동기화를 완료하지 못했습니다: ';

  @override
  String get ankiSyncStatusUploadFailed => '업로드 실패: ';

  @override
  String get ankiSyncStatusPreparingDownload => '다운로드 설정 준비 중…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle => '로컬 컬렉션을 서버 컬렉션으로 바꾸시겠습니까?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      '로컬 컬렉션을 서버 데이터로 교체합니다. 먼저 로컬 데이터베이스를 백업합니다.\n\n서버 미디어가 로컬 미디어를 대체하고, 없는 파일은 다운로드됩니다. 어느 단계에서든 실패하거나 앱이 중간에 종료되면 다음에 덱을 열기 전에 Stroom이 로컬 컬렉션과 미디어를 복원합니다.';

  @override
  String get ankiSyncReplaceLocalAction => '로컬 데이터 교체';

  @override
  String get ankiSyncStatusDownloadingValidating => '컬렉션 다운로드 및 검증 중…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return '로컬 컬렉션을 교체했고 SQLite 검사를 통과했습니다. 미디어 동기화 완료: 파일 $downloaded개 다운로드, $uploaded개 업로드, $deleted개 삭제.$backup 서버 상태를 다시 확인하세요.';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return '다운로드 실패: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => '동기화 준비 중…';

  @override
  String get ankiSyncStatusMergingChanges => '컬렉션 변경사항 병합 중…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      '컬렉션 변경사항을 병합했습니다. 미디어 파일 동기화 중…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '노트 $notes개, 카드 $cards개, 복습 기록 $reviews개를 추가하거나 업데이트했습니다';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges => '병합할 컬렉션 변경사항이 없습니다';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return '양방향 동기화 완료: $collection; 미디어 $uploaded개 업로드, $downloaded개 다운로드, $deleted개 삭제.';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      '컬렉션 변경사항은 병합했지만 미디어 동기화를 완료하지 못했습니다: ';

  @override
  String get ankiSyncStatusSyncIncomplete => '동기화를 완료하지 못했습니다: ';

  @override
  String get ankiSyncStatusClearingLogin => '로그인 세션 삭제 중…';

  @override
  String get ankiSyncStatusLoggedOut => '로그아웃했습니다. 보안 저장소에서 동기화 키를 삭제했습니다.';

  @override
  String get ankiSyncStatusClearLoginFailed => '저장된 로그인 세션을 삭제할 수 없습니다';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      '작업을 완료하지 못했습니다. 보안 저장소, 네트워크, 서버 주소를 확인하세요.';

  @override
  String get ankiSyncUnknown => '알 수 없음';

  @override
  String get ankiSyncServerCollectionEmpty => '서버 컬렉션이 비어 있음';

  @override
  String get ankiSyncServerCollectionAvailable => '서버 컬렉션을 사용할 수 있음';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return '스키마 버전 $schema · USN $usn · 수정됨 $modified';
  }

  @override
  String get asrPageTitle => '오디오 받아쓰기';

  @override
  String get clear => '지우기';

  @override
  String get configure => '구성';

  @override
  String get asrModel => '음성 인식 모델';

  @override
  String get reselectModel => '모델을 다시 선택하세요';

  @override
  String get selectAsrModel => '음성 인식 모델 선택';

  @override
  String get enterPublicAudioUrl => '공개 오디오 URL 입력';

  @override
  String get recordingSelection => '녹음';

  @override
  String get audioFiles => '오디오 파일';

  @override
  String get noAudioSelected => '선택한 오디오 파일이 없습니다';

  @override
  String get supportedAudioFormats => 'WAV, MP3, M4A, OGG 등 일반적인 오디오 형식을 지원합니다';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 파일 $count개 선택됨',
      one: '오디오 파일 $count개 선택됨',
      zero: '선택한 오디오 파일 없음',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 파일 $count개 선택됨',
      one: '오디오 파일 $count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => '다시 선택';

  @override
  String get asrUrlLabel => 'URL | 공개 링크';

  @override
  String get asrErrorDetails => '오류 세부정보 보기';

  @override
  String get asrResultSaved => '받아쓰기 결과 저장됨';

  @override
  String get asrWorking => '받아쓰는 중…';

  @override
  String get asrStart => '받아쓰기 시작';

  @override
  String get saveTo => '저장 위치';

  @override
  String get rootFolder => '루트 폴더';

  @override
  String get chooseSaveFolder => '폴더 선택';

  @override
  String get linkAlreadyAdded => '이 링크는 이미 목록에 있습니다';

  @override
  String get chooseAudioSource => '오디오 소스 선택';

  @override
  String get inAppRecordings => '앱 내 녹음';

  @override
  String get chooseGeneratedRecordings => '생성된 녹음 중에서 선택';

  @override
  String get systemAudioFiles => '시스템 오디오 파일';

  @override
  String get chooseDeviceAudioFiles => '기기에서 파일 선택';

  @override
  String get cannotReadAudioFile => '오디오 파일을 읽을 수 없습니다';

  @override
  String chooseAudioFileFailed(String details) {
    return '오디오 파일을 선택할 수 없습니다: $details';
  }

  @override
  String get chooseInAppRecording => '앱 내 녹음 선택';

  @override
  String get noRecordings => '녹음이 없습니다';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds초',
      one: '$seconds초',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider => '먼저 설정에서 오디오 받아쓰기 제공업체와 모델을 구성하세요';

  @override
  String get asrModelUnavailable =>
      '기존 음성 인식 모델을 사용할 수 없거나 확인할 수 없습니다. 모델을 다시 선택하세요.';

  @override
  String get asrUrlProviderRemoveFiles =>
      '이 제공업체는 URL로 오디오를 업로드합니다. 로컬 오디오 파일을 제거하고 다시 시도하세요.';

  @override
  String get asrFileProviderRemoveUrls =>
      '이 제공업체는 오디오 파일을 업로드하며 링크 받아쓰기를 지원하지 않습니다. 링크를 제거하고 다시 시도하세요.';

  @override
  String asrTaskStartFailed(String details) {
    return '작업을 시작하지 못했습니다: $details';
  }

  @override
  String get asrInvalidUrl => '올바르지 않은 URL입니다. http:// 또는 https://로 시작해야 합니다.';

  @override
  String get asrEnterAudioUrl => '오디오 URL 입력';

  @override
  String get asrUrlProviderHelp =>
      '이 제공업체는 URL로 오디오를 업로드합니다. 공개 오디오 URL(http/https)을 입력하세요.';

  @override
  String get cancel => '취소';

  @override
  String get add => '추가';

  @override
  String get ttsPageTitle => '오디오';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 파일 $count개 가져옴',
      one: '오디오 파일 $count개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return '가져오기 실패: $details';
  }

  @override
  String get ttsFileReadFailed => '파일 데이터를 읽을 수 없습니다';

  @override
  String get ttsExportAudioFile => '오디오 파일 내보내기';

  @override
  String ttsExportedTo(String path) {
    return '다음 위치로 내보냄: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return '내보내기 실패: $details';
  }

  @override
  String get ttsConfirmRegenerate => '다시 생성 확인';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return '오디오 ‘$fileName’을(를) 다시 생성하시겠습니까?';
  }

  @override
  String get ttsRegenerateOverwrite => '다시 생성한 후 원본 오디오 파일을 교체합니다.';

  @override
  String get ttsRegenerate => '오디오 다시 생성';

  @override
  String ttsCopiedFailed(String details) {
    return '복사할 수 없습니다: $details';
  }

  @override
  String get ttsChooseExportFolder => '내보낼 폴더 선택';

  @override
  String get ttsExportAudio => '오디오 내보내기';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 $count개 내보냄',
      one: '파일 $count개 내보냄',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => '폴더 내보내기';

  @override
  String get ttsWebFolderExportHelp =>
      '브라우저에서 내보낼 폴더를 선택할 수 없습니다. 폴더 구조를 유지한 ZIP 파일을 다운로드합니다.';

  @override
  String get ttsDownloadZip => 'ZIP 파일 다운로드';

  @override
  String get ttsExportAudioFolder => '오디오 폴더 내보내기';

  @override
  String get ttsRecord => '녹음';

  @override
  String get ttsImport => '가져오기';

  @override
  String get ttsPlay => '재생';

  @override
  String get ttsExportLocal => '기기로 내보내기';

  @override
  String get ttsRegenerateQuestion => '다시 생성';

  @override
  String get ttsNeedsProvider => '먼저 설정에서 음성 합성 제공업체와 모델을 구성하세요';

  @override
  String get ttsAddedToTasks => '작업 목록에 추가했습니다. 백그라운드에서 생성 중…';

  @override
  String get ttsCreateTitle => '음성 합성';

  @override
  String get ttsOriginalTitle => '녹음 제목';

  @override
  String get ttsUseOriginalTitle => '원래 제목 사용';

  @override
  String get ttsAudioFileNameHint => '저장할 오디오 파일 이름(선택 사항)';

  @override
  String get ttsTextToConvert => '변환할 텍스트';

  @override
  String get ttsSpeechContent => '음성 내용';

  @override
  String get ttsTextHint => '음성으로 변환할 텍스트 입력…';

  @override
  String get ttsFullscreenEdit => '전체 화면에서 편집';

  @override
  String ttsTextLimitWarning(int limit) {
    return '텍스트가 제한을 초과했습니다(최대 $limit자)';
  }

  @override
  String get ttsSynthesisConfig => '합성 설정';

  @override
  String get ttsVoiceAndSoundHelp => '음성과 소리를 조정합니다';

  @override
  String get ttsProviderSettingsLead => '에서 ';

  @override
  String get ttsProviderSettings => 'TTS 제공업체 설정';

  @override
  String get ttsProviderSettingsTail => ' 더 많은 매개변수를 구성합니다';

  @override
  String get ttsEditText => '텍스트 편집';

  @override
  String get ttsClose => '닫기';

  @override
  String get ttsVoice => '음성';

  @override
  String get ttsSelectVoice => '음성 선택';

  @override
  String get ttsSpeed => '속도';

  @override
  String get ttsNormal => '보통';

  @override
  String get ttsVolume => '음량';

  @override
  String get ttsInstruction => '말하기 스타일 지시문';

  @override
  String get ttsInstructionHint => '예: 밝고 신나는 어조로 말하기';

  @override
  String get ttsCustomParams => '사용자 지정 매개변수';

  @override
  String ttsDefaultValue(Object value) {
    return '기본값: $value';
  }

  @override
  String get ttsGenerateRecording => '녹음 생성';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return '다른 이름으로 저장: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => '폴더 선택';

  @override
  String get ttsFillTextError => '변환할 텍스트를 입력하세요';

  @override
  String get voiceBatchTitle => '음성 일괄 추가';

  @override
  String get voiceBatchConfirm => '선택한 음성 추가';

  @override
  String get voiceBatchSeparator => '구분 기호:';

  @override
  String get voiceBatchCustomSeparatorHint => '사용자 지정 구분 기호 입력';

  @override
  String get voiceBatchFieldOrder => '필드 순서:';

  @override
  String get voiceBatchNameThenId => '첫 번째 = 이름, 두 번째 = ID';

  @override
  String get voiceBatchIdThenName => '첫 번째 = ID, 두 번째 = 이름';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '열 $count개를 찾았습니다. 이름/ID의 시작 열을 선택하세요:',
      one: '열 $count개를 찾았습니다. 이름/ID의 시작 열을 선택하세요:',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return '열 $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn => '열 하나를 찾았습니다. 모든 값을 ID로 사용합니다(이름 = ID).';

  @override
  String get voiceBatchInputHint =>
      '탭, 쉼표, 세미콜론 또는 세로 막대로 이름과 ID를 구분하세요(줄마다 한 쌍).';

  @override
  String get voiceBatchNoPreview => '미리 볼 내용이 없습니다';

  @override
  String get voiceName => '음성 이름';

  @override
  String get voiceId => '음성 ID';

  @override
  String get status => '상태';

  @override
  String get voiceNew => '✅ 새 항목';

  @override
  String get voiceIdExists => '⚠️ ID가 이미 있습니다';

  @override
  String voiceFormatError(String details) {
    return '❌ 형식 오류$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '중복된 ID $count개: $ids',
      one: '중복된 ID $count개: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData => '선택한 열에 데이터가 부족합니다';

  @override
  String get voiceCustomSeparator => '사용자 지정…';

  @override
  String get voiceCommaSeparator => '쉼표 (,)';

  @override
  String get voiceSemicolonSeparator => '세미콜론 (;)';

  @override
  String get voicePipeSeparator => '세로 막대 (|)';

  @override
  String get voiceTabSeparator => '탭';

  @override
  String get voiceEditorTitle => '음성 편집';

  @override
  String get save => '저장';

  @override
  String get voiceAddRow => '행 추가';

  @override
  String get voiceBatchAdd => '일괄 추가';

  @override
  String get voiceNoneAdd => '아직 음성이 없습니다. 음성을 추가해 시작하세요.';

  @override
  String get delete => '삭제';

  @override
  String get voiceDuplicateResolution =>
      '다음 음성 ID가 중복됩니다. 각 ID를 어떻게 처리할지 선택하세요:';

  @override
  String get update => '업데이트';

  @override
  String get skip => '건너뛰기';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 중복 항목 남음',
      one: '$count개 중복 항목 남음',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => '계속 편집';

  @override
  String get asrRetryIncomplete =>
      '다시 시도할 오디오가 완전하지 않습니다. 목록을 지우고 모든 오디오를 다시 선택하세요.';

  @override
  String asrRetryAudioUnreadable(String details) {
    return '다시 시도할 오디오 데이터를 읽을 수 없습니다. 오디오를 다시 선택하세요: $details';
  }

  @override
  String get asrLegacyRetryUnavailable =>
      '이전 형식의 다시 시도용 오디오를 사용할 수 없습니다. 오디오를 다시 선택하세요.';

  @override
  String get asrRetryDataUnreadable => '다시 시도할 데이터를 읽을 수 없습니다. 오디오를 다시 선택하세요.';

  @override
  String get ttsSynthesisModel => '합성 모델';

  @override
  String get asrRetryUnavailable => '다시 시도할 오디오를 사용할 수 없습니다. 오디오를 다시 선택하세요.';

  @override
  String get chatRequest => '요청';

  @override
  String get chatResponse => '응답';

  @override
  String get chatNoErrorDetails => '사용할 수 있는 세부정보가 없습니다';

  @override
  String get ttsInstructionDescription =>
      '어조, 감정, 속도, 억양 및 기타 특성을 자연어로 설명하세요. 모델이 설명에 맞춰 합성 음성을 조정합니다.';

  @override
  String get audioPlayerSourceTextSource => '원문 텍스트 선택';

  @override
  String get audioPlayerChooseInAppText => '앱 내 텍스트 선택';

  @override
  String get audioPlayerChooseSavedTextSubtitle => '앱에 저장된 텍스트 파일 선택';

  @override
  String get audioPlayerChooseSystemText => '시스템 텍스트 파일 선택';

  @override
  String get audioPlayerChooseDeviceTextSubtitle => '기기 저장소에서 텍스트 파일 선택';

  @override
  String get audioPlayerSelectInAppText => '앱 내 텍스트 선택';

  @override
  String get audioPlayerNoTextFiles => '아직 텍스트 파일이 없습니다';

  @override
  String audioPlayerCharacterCount(int count) {
    return '문자 $count개';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return '텍스트를 선택하지 못했습니다: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => '텍스트 파일을 읽을 수 없습니다';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return '원문 텍스트를 업로드하지 못했습니다: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => '텍스트가 비어 있습니다';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return '원문 텍스트를 저장하지 못했습니다: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => '원문 텍스트 업로드됨';

  @override
  String get audioPlayerSourceTextUpdated => '원문 텍스트 업데이트됨';

  @override
  String get audioPlayerConfigureTtsProvider => '먼저 TTS 제공업체를 구성하세요';

  @override
  String get audioPlayerNoStreamingModels => '스트리밍 재생을 지원하는 모델이 없습니다';

  @override
  String get audioPlayerSelectStreamingModel => '스트리밍 재생 모델 선택';

  @override
  String get audioPlayerProviderFallback => '제공업체';

  @override
  String audioPlayerStartStreaming(String model) {
    return '스트리밍 재생 시작: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return '오디오 파일을 찾을 수 없습니다: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => '오디오 데이터를 불러올 수 없습니다';

  @override
  String get audioPlayerSourceText => '원문 텍스트';

  @override
  String get audioPlayerNoSourceText => '(원문 텍스트 없음)';

  @override
  String get audioPlayerUploadSourceText => '원문 텍스트 업로드';

  @override
  String get audioPlayerEditSourceText => '원문 텍스트 편집';

  @override
  String get audioPlayerCompanionTextMissing => '연결된 텍스트 파일을 찾을 수 없습니다';

  @override
  String get audioPlayerPlaySelection => '선택 항목 재생';

  @override
  String get audioPlayerGenerateSelection => '선택 항목 생성';

  @override
  String get audioPlayerPlaying => '재생 중...';

  @override
  String get audioPlayerPaused => '일시 정지됨';

  @override
  String get audioPlayerPlaybackSpeed => '재생 속도';

  @override
  String get audioPlayerFailed => '재생 실패';

  @override
  String get audioPlayerRetry => '다시 시도';

  @override
  String get audioPlayerLoading => '오디오 불러오는 중...';

  @override
  String get audioPlayerClose => '닫기';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      '브라우저에서 녹음을 지원하지 않습니다. 앱 버전을 사용하세요.';

  @override
  String get audioRecordingMicrophonePermissionRequired =>
      '녹음하려면 마이크 권한이 필요합니다';

  @override
  String audioRecordingStartFailure(String error) {
    return '녹음을 시작하지 못했습니다: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return '녹음을 일시 정지하지 못했습니다: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return '녹음을 재개하지 못했습니다: $error';
  }

  @override
  String get audioRecordingInvalidFile => '녹음 파일이 올바르지 않습니다. 다시 녹음하세요.';

  @override
  String audioRecordingStopFailure(String error) {
    return '녹음을 중지하지 못했습니다: $error';
  }

  @override
  String get audioRecordingFileNotFound => '녹음 파일을 찾을 수 없습니다';

  @override
  String get audioRecordingFileEmpty => '녹음 파일이 비어 있습니다';

  @override
  String audioRecordingSaved(String name) {
    return '녹음 저장됨: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return '녹음을 저장하지 못했습니다: $error';
  }

  @override
  String get audioRecordingTitle => '녹음';

  @override
  String get audioRecordingBrowserUnsupported => '브라우저에서 녹음을 지원하지 않습니다';

  @override
  String get audioRecordingUseApp => '녹음하려면 앱 버전을 사용하세요';

  @override
  String get audioRecordingDraftRecoveryHint =>
      '저장하지 않은 녹음 초안이 있습니다. 오디오 라이브러리에 저장할 수 있습니다.';

  @override
  String get audioRecordingRecording => '녹음 중 ●';

  @override
  String get audioRecordingPaused => '일시 정지됨 ||';

  @override
  String get audioRecordingPreparing => '준비 중...';

  @override
  String get audioRecordingStart => '녹음 시작';

  @override
  String get audioRecordingPause => '일시 정지';

  @override
  String get audioRecordingStopping => '중지 중...';

  @override
  String get audioRecordingStop => '중지';

  @override
  String get audioRecordingResume => '재개';

  @override
  String get audioRecordingSaving => '저장 중...';

  @override
  String get audioRecordingSave => '녹음 저장';

  @override
  String get audioRecordingRecordAgain => '다시 녹음';

  @override
  String get audioRecordingWaveformPaused => '녹음이 일시 정지되어 파형이 고정되었습니다';

  @override
  String get audioRecordingWaveformLive => '실시간 오디오 파형';

  @override
  String get audioSeparationTitle => '동영상 오디오 분리';

  @override
  String get audioSeparationChooseVideoSource => '동영상 소스 선택';

  @override
  String get audioSeparationChooseAppAlbum => '앱 라이브러리에서 선택';

  @override
  String get audioSeparationChooseSavedVideoSubtitle => '앱에 저장된 동영상 선택';

  @override
  String get audioSeparationChooseSystemAlbum => '시스템 저장소에서 선택';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle => '기기 저장소에서 동영상 파일 선택';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return '동영상을 선택하지 못했습니다: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix => '오디오 추출 실패: ';

  @override
  String get audioSeparationEngineMissing => '오디오 분리 엔진을 찾을 수 없습니다';

  @override
  String get audioSeparationEngineMissingHelp =>
      '앱을 다시 시작하거나 리소스가 모두 있는지 확인하세요.';

  @override
  String get audioSeparationNoVideoSelected => '선택한 동영상이 없습니다';

  @override
  String get audioSeparationSupportedFormatsHint => '지원 형식: mp4, mov, m4v, 3gp';

  @override
  String get audioSeparationSuccess => '오디오를 추출해 오디오 라이브러리에 저장했습니다';

  @override
  String get audioSeparationView => '보기';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동영상 $count개 선택됨',
      one: '동영상 $count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => '추출 중...';

  @override
  String get audioSeparationExtractAudio => '오디오 추출';

  @override
  String get audioSeparationSaveTo => '저장 위치';

  @override
  String get audioSeparationChooseSaveFolder => '저장 폴더 선택';

  @override
  String get audioSeparationCannotReadVideoFile => '동영상 파일을 읽을 수 없습니다';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return '동영상 파일을 선택하지 못했습니다: $error';
  }

  @override
  String get audioSeparationUnknownFormat => '알 수 없음';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return '지원하지 않는 형식: $formats. 지원 형식: MP4, MOV, M4V, 3GP.';
  }

  @override
  String get audioSeparationEngineUnavailable => '오디오 분리 엔진을 사용할 수 없습니다.';

  @override
  String get backgroundOptimizationTitle => '백그라운드 최적화';

  @override
  String get backgroundOptimizationEnvironment => '시스템 환경';

  @override
  String get backgroundOptimizationChecks => '백그라운드 서비스 상태';

  @override
  String get backgroundOptimizationKeepAliveStrategies => '백그라운드 유지 전략';

  @override
  String get backgroundOptimizationDetecting => '확인 중…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      '이 플랫폼에서는 백그라운드 서비스를 지원하지 않습니다';

  @override
  String get backgroundOptimizationServiceRunning => '백그라운드 서비스가 실행 중입니다';

  @override
  String get backgroundOptimizationServiceStopped => '백그라운드 서비스가 실행되고 있지 않습니다';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      '백그라운드 서비스 상태를 확인할 수 없습니다';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      '데스크톱 트레이를 사용할 수 없습니다. 창을 닫으면 앱이 종료됩니다.';

  @override
  String get backgroundOptimizationDesktopCloseExits => '데스크톱 창을 닫으면 앱이 종료됩니다';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      '데스크톱 트레이가 앱을 계속 실행합니다';

  @override
  String get backgroundOptimizationStartFailed => '서비스를 시작할 수 없습니다';

  @override
  String get backgroundOptimizationStopFailed => '서비스를 중지할 수 없습니다';

  @override
  String get backgroundOptimizationRestartFailed => '서비스를 다시 시작할 수 없습니다';

  @override
  String get backgroundOptimizationStopService => '서비스 중지';

  @override
  String get backgroundOptimizationRestartService => '서비스 다시 시작';

  @override
  String get backgroundOptimizationStartService => '서비스 시작';

  @override
  String get backgroundOptimizationRedetect => '다시 확인';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      '이 플랫폼에서는 백그라운드 서비스를 제어할 수 없습니다.';

  @override
  String get backgroundOptimizationCheckingBattery => '배터리 최적화 상태 확인 중…';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      '이 앱은 배터리 최적화 대상에서 제외되어 있습니다';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      '배터리 최적화가 활성화되어 있습니다. 백그라운드 작업이 중지될 수 있습니다';

  @override
  String get backgroundOptimizationIgnoreBattery => '배터리 최적화 사용 중지';

  @override
  String get backgroundOptimizationExactAlarm => '정확한 알람 허용(백그라운드 작업의 신뢰도 향상)';

  @override
  String get backgroundOptimizationWatchdogTitle => 'AlarmManager 감시 기능';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      '활성화하면 Android가 기본 알람을 사용해 5분마다 백그라운드 서비스를 확인합니다. 시스템이 프로세스를 종료하면 알람이 서비스를 다시 시작합니다.\n\n기기가 Doze 모드인 동안에도 알람이 작동하며, 재부팅 후 다시 예약됩니다.\n\n백그라운드 작업을 자주 사용하는 사용자에게 권장합니다.\n배터리 영향: 매우 낮음. 확인할 때마다 기기가 잠시 깨어납니다.';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      '감시 기능 설정을 저장할 수 없어 변경되지 않았습니다';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      '감시 기능을 활성화할 수 없습니다. 백그라운드 서비스 상태를 확인하지 못했습니다';

  @override
  String get backgroundOptimizationColdStartTitle => '앱 실행 시 서비스 복원';

  @override
  String get backgroundOptimizationColdStartDetail =>
      '활성화하면 앱을 열 때마다 이전에 실행 중이던 백그라운드 서비스가 있는지 확인하고 복원합니다.\n\n시스템이나 사용자가 앱 프로세스를 중지해도 앱을 다음에 열면 백그라운드 서비스가 다시 시작됩니다.\n\n모든 사용자에게 권장합니다.\n배터리 영향: 없음. 앱 실행 시 한 번만 확인합니다.';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      '실행 시 복구 설정을 저장할 수 없어 변경되지 않았습니다';

  @override
  String get backgroundOptimizationBatteryReminderTitle => '배터리 최적화 알림';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      '활성화하면 이 페이지에 배터리 최적화 상태가 표시됩니다. 앱이 배터리 제외 목록에 없으면 시스템 설정을 열어 제외할 수 있습니다.\n\nAndroid 배터리 최적화(Doze)는 백그라운드 앱의 활동을 제한합니다. 이 앱을 제외 목록에 추가하면 시스템이 절전을 위해 앱을 중지하지 않습니다.\n\n이 옵션을 끄면 알림 카드만 숨겨지고 앱의 배터리 제외 설정은 바뀌지 않습니다.';

  @override
  String get backgroundOptimizationStrategyIntro =>
      '각 전략은 독립적으로 활성화할 수 있습니다. 백그라운드 작업의 신뢰도를 높이기 위해 기본적으로 모두 켜져 있습니다. 전략을 끄면 해당 전략에만 영향을 주며 백그라운드 서비스 자체에는 영향을 주지 않습니다.';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOS 백그라운드 작업';

  @override
  String get backgroundOptimizationIosSupported =>
      'iOS 26 이상은 진행 중인 백그라운드 작업을 지원합니다. 앱을 전환하거나 화면을 잠가도 작업은 대체로 계속되지만, 리소스가 부족하면 시스템이 중지할 수 있습니다. 잠금 화면에서 진행 상황을 확인할 수 있습니다.';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'iOS 26보다 이전 버전은 진행 중인 백그라운드 작업을 지원하지 않습니다. 작업이 실행되는 동안 몇 분마다(약 5~10분, 간격은 iOS에 따라 다름) 앱으로 돌아와 백그라운드 실행 시간을 갱신하고 일시 중지되지 않도록 하세요.';

  @override
  String get backgroundOptimizationIosWarning =>
      '모든 iOS 버전에서 앱 전환 화면을 밀어 Stroom을 종료하지 마세요. 실행 중인 모든 작업이 즉시 중지됩니다.';

  @override
  String get backgroundOptimizationDesktopIntro =>
      '데스크톱 시스템에는 모바일 플랫폼의 프로세스 유지 기능이 없지만, 창을 닫은 뒤에도 앱을 계속 실행할 수 있습니다.';

  @override
  String get backgroundOptimizationCloseMinimizeTitle => '창을 닫을 때 트레이로 최소화';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      '활성화하면 창의 닫기 버튼을 눌러도 앱이 종료되지 않고 시스템 트레이에 숨겨집니다. 백그라운드 작업은 계속 실행됩니다.\n\n트레이 아이콘 또는 ‘기본 창 표시’ 메뉴 항목으로 창을 다시 여세요. 앱을 종료하려면 아래의 ‘앱 종료’ 버튼을 사용하세요.\n\n모든 데스크톱 사용자에게 권장합니다.';

  @override
  String get backgroundOptimizationQuitApp => '앱 종료';

  @override
  String get backgroundOptimizationGotIt => '확인';

  @override
  String get backgroundOptimizationWebNoteTitle => '웹 백그라운드 작업';

  @override
  String get backgroundOptimizationWebNote =>
      '브라우저는 앱을 백그라운드에서 계속 실행할 수 없습니다. 이 탭을 닫거나 새로 고치거나, 비활성 탭이 브라우저에 의해 일시 중지되면 실행 중인 작업도 즉시 중단됩니다. 작업이 실행되는 동안 Stroom 탭을 열어 두고 활성 상태로 유지하세요.';

  @override
  String get backgroundOptimizationTutorial => '플랫폼별 안내';

  @override
  String get backgroundOptimizationTutorialDescription =>
      '플랫폼별 백그라운드 최적화 안내 보기';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      '백그라운드 서비스 상태를 확인하고 있습니다…';

  @override
  String get backgroundOptimizationServiceUnknown =>
      '백그라운드 서비스 상태를 알 수 없습니다. 서비스 실행 여부를 확인하려면 다시 확인하세요.';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      '백그라운드 서비스가 실행 중입니다. 작업을 백그라운드에서 계속 진행할 수 있습니다.';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      '웹 브라우저에서는 백그라운드 서비스를 지원하지 않습니다. 작업을 계속하려면 이 페이지를 열어 두세요.';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      '데스크톱 트레이를 사용할 수 없습니다(Linux 빌드에는 libayatana-appindicator3-dev가 필요합니다). 창을 닫으면 앱이 종료됩니다.';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      '데스크톱 트레이를 사용할 수 없습니다. 창을 닫으면 앱이 종료됩니다.';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      '데스크톱 창을 닫으면 앱이 종료되도록 설정되어 있습니다. 기존 종료 확인 절차를 따르며 트레이에서 계속 실행되지 않습니다.';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      '데스크톱 트레이가 활성화되어 있습니다. 창을 닫으면 앱이 시스템 트레이로 숨겨진 채 계속 실행됩니다. 트레이 메뉴에서 ‘기본 창 표시’를 선택해 다시 여세요. 완전히 종료하려면 트레이 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      '데스크톱 트레이가 활성화되어 있습니다. 창을 닫으면 앱이 시스템 트레이로 최소화되어 계속 실행됩니다. 트레이 아이콘을 클릭하거나 메뉴에서 ‘기본 창 표시’를 선택해 창을 다시 여세요. 완전히 종료하려면 트레이 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      '백그라운드 서비스가 실행되고 있지 않습니다. 아래의 ‘서비스 시작’을 선택하거나 플랫폼별 안내에서 백그라운드 작업 최적화 방법을 확인하세요.';

  @override
  String get notificationSettingsPageTitle => '알림 권한 설정';

  @override
  String get notificationSettingsWebUnsupported => '웹 브라우저에서는 알림을 지원하지 않습니다';

  @override
  String get notificationSettingsChecking => '확인 중…';

  @override
  String get notificationSettingsPermissionGranted => '알림 권한 허용됨';

  @override
  String get notificationSettingsPermissionDenied => '알림 권한이 허용되지 않음';

  @override
  String get notificationSettingsPermissionRestricted => '알림 권한이 제한됨';

  @override
  String get notificationSettingsPermissionBlocked => '알림 권한이 영구적으로 차단됨';

  @override
  String get notificationSettingsPermissionProvisional => '알림 권한이 임시로 허용됨';

  @override
  String get notificationSettingsWebGuide => '웹 브라우저에서는 시스템 알림을 지원하지 않습니다.';

  @override
  String get notificationSettingsCheckingPermission => '알림 권한 확인 중…';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      '알림 권한이 허용되었습니다. 작업이 완료되거나 실패할 때 시스템 알림을 받으려면 작업 완료 알림을 켜세요.';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      '알림 권한이 허용되지 않았습니다. 아래 버튼을 눌러 권한을 요청하거나 시스템 설정에서 Stroom 알림을 켜세요.';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      '자녀 보호 기능 등으로 시스템이 알림 권한을 제한하고 있습니다. 시스템 설정에서 Stroom의 알림 설정을 확인하세요.';

  @override
  String get notificationSettingsEnvironment => '시스템 환경';

  @override
  String get notificationSettingsPermissionSection => '알림 권한';

  @override
  String get notificationSettingsPlatformGuides => '플랫폼별 안내';

  @override
  String get notificationSettingsGuideIntro =>
      '운영체제에 맞는 다음 단계를 따라 Stroom 알림을 켜세요.';

  @override
  String get notificationSettingsTaskCompleteTitle => '작업 완료 알림';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      '작업이 완료되거나 실패하면 알림 보내기';

  @override
  String get notificationSettingsCheckAgain => '다시 확인';

  @override
  String get notificationSettingsOpenSystemSettings => '시스템 설정 열기';

  @override
  String get notificationSettingsRequestPermission => '권한 요청';

  @override
  String get notificationSettingsGuideUnsupported =>
      '이 플랫폼에서는 알림 설정 안내를 사용할 수 없습니다.';

  @override
  String get notificationSettingsUsageReason => '작업 완료 시 알림을 보내기 위해';

  @override
  String get notificationSettingsAndroidEnableTitle => '알림 켜기';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      '설정 → 앱 → Stroom → 알림 관리로 이동해 알림을 허용하세요. 목록에서 Stroom을 찾을 수 없다면 설치 여부를 확인하세요. 알림이 꺼져 있으면 켜세요.';

  @override
  String get notificationSettingsAndroidDndTitle => '방해 금지 확인';

  @override
  String get notificationSettingsAndroidDndDescription =>
      '설정 → 소리 및 진동 → 방해 금지로 이동하세요. 방해 금지를 끄거나 Stroom 알림을 허용하세요.';

  @override
  String get notificationSettingsAndroidPopupTitle => '팝업 알림 허용';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'MIUI, EMUI, ColorOS 등 일부 Android 시스템에서는 앱 정보에서 ‘알림 허용’과 ‘팝업 허용’을 켜야 합니다. 앱의 ‘알림 필터링’ 또는 ‘스마트 알림’도 꺼 보세요.';

  @override
  String get notificationSettingsReturnTitle => '이 페이지로 돌아오기';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      '설정을 변경한 뒤 ‘다시 확인’을 선택해 권한 상태를 확인하세요. 권한이 허용되면 작업 완료 알림을 켤 수 있습니다.';

  @override
  String get notificationSettingsIosEnableDescription =>
      '설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 작업 상태를 확인할 수 있도록 배너와 알림 센터도 활성화하세요.';

  @override
  String get notificationSettingsIosFocusTitle => '집중 모드 끄기';

  @override
  String get notificationSettingsIosFocusDescription =>
      '설정 → 집중 모드로 이동하세요. 집중 모드를 끄거나 허용된 앱 목록에 Stroom을 추가하세요. 집중 모드에서는 앱 알림이 차단될 수 있습니다.';

  @override
  String get notificationSettingsIosReturnDescription =>
      '설정을 변경한 뒤 ‘다시 확인’을 선택해 권한 상태를 확인하세요. iOS에서는 보통 시스템 설정에서 알림 권한을 직접 허용해야 합니다.';

  @override
  String get notificationSettingsWindowsEnableTitle => '시스템 알림 켜기';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      '설정 → 시스템 → 알림 및 작업으로 이동해 ‘앱 및 다른 보낸 사람의 알림 받기’를 켜세요. 아래 앱 목록에서 Stroom을 찾아 알림이 켜져 있는지 확인하세요.';

  @override
  String get notificationSettingsWindowsFocusTitle => '집중 지원 예외 추가';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      '설정 → 시스템 → 집중 지원으로 이동하세요. Stroom을 ‘우선 순위만’ 목록에 추가하거나 집중 지원을 끄세요. 집중 지원은 알림을 차단할 수 있습니다.';

  @override
  String get notificationSettingsMacEnableTitle => '알림 켜기';

  @override
  String get notificationSettingsMacEnableDescription =>
      '시스템 설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 배너와 알림 센터도 활성화하세요.';

  @override
  String get notificationSettingsMacFocusDescription =>
      '시스템 설정 → 집중 모드로 이동하세요. 집중 모드를 끄거나 허용된 앱 목록에 Stroom을 추가하세요.';

  @override
  String get notificationSettingsLinuxDesktopTitle => '데스크톱 알림 설정 확인';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      '데스크톱 환경(GNOME, KDE, XFCE 등)에 따라 시스템 설정 → 알림으로 이동해 Stroom을 찾고 알림이 켜져 있는지 확인하세요.';

  @override
  String get notificationSettingsLinuxDaemonTitle => '알림 데몬 확인';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux 데스크톱 환경에서 시스템 알림을 표시하려면 notify-osd 또는 dunst와 같은 알림 데몬이 필요합니다. 하나가 설치되어 실행 중인지 확인하세요.';

  @override
  String get backupRestorePageTitle => '백업 및 복원';

  @override
  String get backupRestoreSelectBackupCategory => '백업할 데이터 범주를 하나 이상 선택하세요';

  @override
  String get backupRestorePreparingData => '데이터 준비 중…';

  @override
  String get backupRestoreExportingBackup => '백업 내보내는 중';

  @override
  String get backupRestoreCollectingDatabase => '데이터베이스 기록 수집 중…';

  @override
  String get backupRestoreProcessingSettings => '설정 처리 중…';

  @override
  String get backupRestoreAddingTasks => '작업 파일 추가 중…';

  @override
  String get backupRestoreAddingPictures => '이미지 파일 추가 중…';

  @override
  String get backupRestoreAddingAudio => '오디오 파일 추가 중…';

  @override
  String get backupRestoreAddingVideo => '동영상 파일 추가 중…';

  @override
  String get backupRestoreAddingText => '텍스트 파일 추가 중…';

  @override
  String get backupRestoreAddingChat => '채팅 기록과 첨부 파일 추가 중…';

  @override
  String get backupRestoreCompressing => '압축 파일 만드는 중…';

  @override
  String get backupRestoreCompleted => '완료';

  @override
  String get backupRestoreSelectRestoreCategory => '복원할 데이터 범주를 하나 이상 선택하세요';

  @override
  String get backupRestoreConfirmRestore => '복원 확인';

  @override
  String get backupRestoreSelectedCategories => '선택한 데이터 범주:';

  @override
  String get backupRestoreRestoreInfo =>
      '백업에서 선택한 범주를 찾아 이 기기에 복원합니다. 기본 제공 브라우저 쿠키를 제외한 모든 범주는 해당 로컬 데이터를 대체합니다. 쿠키는 도메인, 이름, 경로별로 기록하며 백업에 포함되지 않은 로컬 쿠키는 유지됩니다. 선택하지 않은 범주와 백업에 없는 범주는 변경되지 않습니다. 누락된 범주는 알림과 함께 건너뜁니다.';

  @override
  String get backupRestoreRestartNotice =>
      '복원한 변경사항을 적용하려면 앱을 다시 시작하세요. 현재 작업을 저장했는지 확인하세요.';

  @override
  String get backupRestoreCancel => '취소';

  @override
  String get backupRestoreConfirmRestoreButton => '복원';

  @override
  String get backupRestoreIncompleteTitle => '복원 미완료';

  @override
  String get backupRestoreIncompleteMessage =>
      '데이터를 완전히 복원하지 못해 일부 데이터가 삭제되었을 수 있습니다. 앱을 다시 시작한 후 다시 시도하세요.';

  @override
  String get backupRestoreSelectClearCategory => '삭제할 데이터 범주를 하나 이상 선택하세요';

  @override
  String get backupRestoreClearingData => '데이터 삭제 중';

  @override
  String get backupRestoreDeletingCategories => '선택한 데이터 범주 삭제 중…';

  @override
  String get backupRestoreClearedTitle => '데이터 삭제됨';

  @override
  String get backupRestorePartiallyClearedTitle => '일부 데이터 삭제됨';

  @override
  String get backupRestoreClearedMessage =>
      '선택한 데이터를 삭제했습니다. 변경사항을 적용하려면 앱을 다시 시작하세요.';

  @override
  String get backupRestorePartialClearMessage =>
      '선택한 다른 데이터는 삭제했습니다. 이 플랫폼에서는 기본 제공 브라우저의 웹사이트 저장소(localStorage, IndexedDB 등)를 완전히 삭제할 수 없으므로 삭제하지 못한 브라우저 데이터가 남아 있습니다. 삭제 결과를 적용하려면 앱을 다시 시작하세요.';

  @override
  String backupRestoreClearFailed(String error) {
    return '데이터를 삭제할 수 없습니다: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => '삭제 미완료';

  @override
  String get backupRestoreClearIncompleteMessage =>
      '일부 데이터를 삭제하지 못했습니다. 앱을 다시 시작한 뒤 다시 삭제해 보세요.';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki 덱을 다음 위치로 내보냈습니다: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get backupRestoreApkgRequired => '.apkg 파일을 선택하세요';

  @override
  String backupRestoreImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return '백업을 다음 위치에 저장했습니다: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return '백업 실패: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return '복원 실패: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected =>
      '백업 폴더가 선택되지 않았습니다. 시작할 때 폴더에 대한 액세스 권한을 허용하세요.';

  @override
  String get backupRestoreRestoreSuccessTitle => '데이터 복원됨';

  @override
  String get backupRestoreRestoredMessage =>
      '백업에서 데이터를 복원했습니다. 복원한 데이터를 사용하려면 앱을 다시 시작하세요.';

  @override
  String get backupRestoreExitApp => '앱 종료';

  @override
  String get backupRestoreRestartNow => '지금 다시 시작';

  @override
  String get backupRestoreSkippedTitle => '일부 데이터 건너뜀';

  @override
  String get backupRestoreNothingRestoredTitle => '복원된 데이터 없음';

  @override
  String get backupRestoreGotIt => '확인';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return '백업에서 선택한 다음 범주를 복원할 수 있는 콘텐츠로 확인하지 못해 건너뛰었으며 기존 데이터는 유지했습니다: $categories.';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      '이전 백업에서는 빈 작업 파일만으로 작업 목록이 비어 있는지 해당 플랫폼에서 작업을 내보내지 않았는지 구분할 수 없습니다. 현재 작업을 덮어쓰지 않도록 작업 범주를 건너뛰고 기존 데이터를 유지했습니다.';

  @override
  String get backupRestoreSkippedCookies =>
      '백업에 가져올 기본 제공 브라우저 쿠키가 없어 이 범주를 건너뛰고 기존 쿠키를 유지했습니다.';

  @override
  String get backupRestoreSkippedWebsiteData =>
      '이전 백업의 웹사이트 저장소 디렉터리를 건너뛰었습니다. 아카이브에 쿠키가 포함되어 있고 해당 범주를 선택한 경우 쿠키는 별도로 가져올 수 있습니다.';

  @override
  String get backupRestoreApkgTitle => 'Anki 덱';

  @override
  String get backupRestoreApkgInfoTitle => 'Anki 덱 가져오기 또는 내보내기';

  @override
  String get backupRestoreApkgInfoMessage => '카드 정보만 포함하며 미디어는 포함하지 않습니다';

  @override
  String get backupRestoreApkgDescription => '.apkg 형식의 Anki 덱을 가져오거나 내보냅니다';

  @override
  String get backupRestoreExportingApkg => '내보내는 중…';

  @override
  String get backupRestoreExportApkg => '.apkg 내보내기';

  @override
  String get backupRestoreImportingApkg => '가져오는 중…';

  @override
  String get backupRestoreImportApkg => '.apkg 가져오기';

  @override
  String get backupRestoreCategoryHeading => '백업 또는 복원할 데이터 범주 선택';

  @override
  String get backupRestoreExporting => '내보내는 중…';

  @override
  String get backupRestoreExportBackup => '백업 내보내기';

  @override
  String get backupRestoreRestoring => '복원 중…';

  @override
  String get backupRestoreChooseBackup => '백업 파일 선택 및 복원';

  @override
  String get backupRestoreClearSelected => '선택한 데이터 삭제';

  @override
  String get backupRestoreClearDescription =>
      '백업 파일 없이 선택한 데이터 범주를 바로 삭제합니다. 선택하지 않은 범주는 변경되지 않습니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get backupRestoreClearing => '삭제 중…';

  @override
  String get backupRestoreCategoryChat => '채팅 기록 및 첨부 파일';

  @override
  String get backupRestoreCategoryChatDescription => '채팅 대화, 메시지 내용, 첨부 파일';

  @override
  String get backupRestoreCategorySettings => '설정';

  @override
  String get backupRestoreCategorySettingsDescription =>
      '앱 구성, 제공업체 설정, 인터페이스 환경설정';

  @override
  String get backupRestoreCategoryPictures => '이미지';

  @override
  String get backupRestoreCategoryPicturesDescription => '사진 및 미리보기 이미지';

  @override
  String get backupRestoreCategoryAudio => '오디오';

  @override
  String get backupRestoreCategoryAudioDescription => '음성 합성 및 녹음';

  @override
  String get backupRestoreCategoryVideos => '동영상';

  @override
  String get backupRestoreCategoryVideosDescription => '동영상 파일';

  @override
  String get backupRestoreCategoryTexts => '텍스트';

  @override
  String get backupRestoreCategoryTextsDescription => '텍스트 문서';

  @override
  String get backupRestoreCategoryTasks => '작업';

  @override
  String get backupRestoreCategoryTasksDescription => '백그라운드 작업 기록';

  @override
  String get backupRestoreCategoryAnki => 'Anki 플래시카드 데이터';

  @override
  String get backupRestoreCategoryAnkiDescription => 'Anki 데이터베이스';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki 플래시카드 데이터';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Anki 플래시카드 데이터를 백업하거나 복원하면 collection.media 디렉터리의 카드 미디어도 포함됩니다.';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'Anki 플래시카드 데이터 정보';

  @override
  String get backupRestoreCategoryBrowser => '기본 제공 브라우저 데이터';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      '쿠키만 백업 및 복원하며, 삭제 시 지원되는 웹사이트 저장소도 제거합니다';

  @override
  String get backupRestoreViewInfo => '정보 보기';

  @override
  String get backupRestoreApkgInfoTooltip => 'Anki 덱 가져오기 및 내보내기 정보';

  @override
  String get backupRestoreConfirmClear => '삭제 확인';

  @override
  String get backupRestoreClearCategoriesIntro =>
      '백업 파일을 사용하지 않고 다음 데이터 범주를 삭제합니다:';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      '이 플랫폼에서는 기본 제공 브라우저의 웹사이트 저장소(localStorage, IndexedDB 등)를 완전히 삭제할 수 없습니다. 확인하면 선택한 다른 데이터는 삭제되지만, 삭제할 수 없는 브라우저 데이터는 남습니다.';

  @override
  String get backupRestoreUnselectedUnchanged => '선택하지 않은 범주는 변경되지 않습니다.';

  @override
  String get backupRestoreClearWarning =>
      '이 작업은 취소할 수 없습니다. 삭제한 변경사항을 적용하려면 앱을 다시 시작하세요.';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return '삭제($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => '브라우저 환경';

  @override
  String get backupRestoreIntro =>
      '선택한 데이터 범주를 수동으로 내보냅니다. 가져올 때는 아카이브에서 선택한 범주만 복원합니다. 범주나 필수 파일이 없으면 알림과 함께 건너뛰고, 선택하지 않은 범주는 변경되지 않습니다. 선택한 범주를 바로 삭제할 수도 있습니다.';

  @override
  String get backupRestoreOtherSelectedRestored =>
      '선택한 다른 데이터는 복원했습니다. 변경사항을 적용하려면 앱을 다시 시작하세요.';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      '알림이 차단되어 있습니다. 시스템 설정을 열고 Stroom의 알림을 허용하세요.';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      '알림이 차단되어 있습니다. 시스템 설정 → 앱 → Stroom → 알림 관리로 이동해 알림을 허용하세요.';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      '알림이 차단되어 있습니다. 시스템 설정 → Stroom → 알림으로 이동해 알림을 허용하세요.';

  @override
  String get textPreviewDiscardEditsTitle => '편집 내용 버리기';

  @override
  String get textPreviewUnsavedChangesConfirm => '저장하지 않은 변경사항이 있습니다. 버리시겠습니까?';

  @override
  String get textPreviewCancel => '취소';

  @override
  String get textPreviewDiscard => '버리기';

  @override
  String get textPreviewFontSize => '글자 크기 조정';

  @override
  String get textPreviewRestoreDefault => '기본값 복원';

  @override
  String get textPreviewClose => '닫기';

  @override
  String textPreviewSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get textPreviewUndo => '실행 취소';

  @override
  String get textPreviewRedo => '다시 실행';

  @override
  String get textPreviewSave => '저장';

  @override
  String get textPreviewEdit => '편집';

  @override
  String get textPreviewChartEdit => '차트 편집';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return '지원하지 않는 형식을 건너뜀: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '텍스트 파일 #개 가져옴',
      one: '텍스트 파일 #개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get textStorageSaved => '텍스트 저장됨';

  @override
  String get textStorageLoadFailed => '텍스트 내용을 불러올 수 없습니다';

  @override
  String get textStorageReadFailed => '파일 데이터를 읽지 못했습니다';

  @override
  String get textStorageExportTitle => '텍스트 내보내기';

  @override
  String textStorageExportedTo(String path) {
    return '다음 위치로 내보냄: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get textStorageChooseExportDirectory => '내보낼 디렉터리 선택';

  @override
  String get textStorageFolderExportTitle => '폴더 내보내기';

  @override
  String get textStorageWebFolderExportInfo =>
      '브라우저에서 내보낼 디렉터리를 선택할 수 없습니다. 폴더 구조를 유지하는 ZIP 파일을 다운로드합니다.';

  @override
  String get textStorageCancel => '취소';

  @override
  String get textStorageDownloadZip => 'ZIP 파일 다운로드';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 #개 내보냄',
      one: '파일 #개 내보냄',
    );
    return '$_temp0';
  }

  @override
  String get textStorageExportFolderTitle => '텍스트 폴더 내보내기';

  @override
  String textStorageCopyFailed(String error) {
    return '복사 실패: $error';
  }

  @override
  String get textStorageCreateNew => '새로 만들기';

  @override
  String get textStorageImport => '가져오기';

  @override
  String get textStorageTitle => '텍스트';

  @override
  String get textStorageExportToLocal => '로컬로 내보내기';

  @override
  String get textCreateEnterTitle => '제목을 입력하세요';

  @override
  String textCreateSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get textCreateNewTitle => '새로 만들기';

  @override
  String get textCreateSave => '저장';

  @override
  String get textCreateTitleLabel => '제목';

  @override
  String get textCreateTitleHint => '텍스트 제목 입력';

  @override
  String get textCreateFormatLabel => '형식';

  @override
  String get textCreateContentLabel => '텍스트 내용';

  @override
  String get textCreateContentHint => '텍스트 내용 입력...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform 백그라운드 최적화 안내';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform 백그라운드 실행 안내';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform 백그라운드 최적화 가이드';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return '다음 단계를 따르면 $platform 기기에서 Stroom의 백그라운드 실행을 최적화해 작업을 계속 진행할 수 있습니다.';
  }

  @override
  String get platformTutorialStepsHeading => '최적화 단계';

  @override
  String get platformTutorialTipsHeading => '팁';

  @override
  String get platformTutorialTipsDescription =>
      '설정을 마친 뒤 ‘백그라운드 최적화’ 페이지로 돌아와 상태가 업데이트되었는지 확인하세요. 문제가 계속되면 다른 플랫폼의 안내를 확인하거나 GitHub에 문제를 보고하세요.';

  @override
  String get platformTutorialAndroidStep1Title => '배터리 최적화 끄기';

  @override
  String get platformTutorialAndroidStep1Description =>
      '설정 → 앱 → Stroom → 배터리로 이동한 뒤 ‘제한 없음’ 또는 ‘최적화하지 않음’을 선택하세요. 또는 Stroom의 ‘백그라운드 최적화’ 페이지에서 ‘배터리 최적화 사용 중지’를 눌러 시스템 절전 허용 목록에 추가할 수 있습니다. 메뉴 경로는 기기 제조사에 따라 다릅니다.';

  @override
  String get platformTutorialAndroidStep2Title => '백그라운드 활동 허용';

  @override
  String get platformTutorialAndroidStep2Description =>
      '설정 → 앱 → Stroom으로 이동해 ‘백그라운드 활동 허용’과 ‘자동 시작 허용’을 켜세요. 일부 휴대전화에서는 보안 센터나 휴대전화 관리자에서도 자동 시작을 허용해야 합니다.';

  @override
  String get platformTutorialAndroidStep3Title => '백그라운드 프로세스 잠금';

  @override
  String get platformTutorialAndroidStep3Description =>
      '최근 앱 화면에서 Stroom 카드를 아래로 밀거나 잠금 아이콘을 눌러 시스템이 앱을 지우지 못하게 하세요.';

  @override
  String get platformTutorialAndroidStep4Title => '알림 허용(Android 13 이상)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 이상에서는 알림 권한이 필요합니다. 권한이 없으면 백그라운드 서비스 알림이 숨겨지지만 서비스는 계속 실행됩니다. ‘서비스 시작’을 처음 누르면 권한을 요청하며 설정 → 앱 → Stroom → 알림에서도 허용할 수 있습니다.';

  @override
  String get platformTutorialAndroidStep5Title => '배터리 최적화 제외';

  @override
  String get platformTutorialAndroidStep5Description =>
      'Stroom에서 ‘작업 완료 알림’을 켜면 관련 권한을 요청합니다. 설정 → 앱 → 특별한 앱 액세스 → 배터리 최적화에서 Stroom이 ‘최적화하지 않음’으로 설정되어 있는지도 확인할 수 있습니다.';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Android 기기의 자동 시작 및 백그라운드 관리';

  @override
  String get platformTutorialAndroidStep6Description =>
      '기기 제조사는 자체 백그라운드 제어 기능을 추가하는 경우가 많습니다.\n• Xiaomi/Redmi(MIUI/HyperOS): 설정 → 앱 → 권한 → 자동 시작에서 Stroom을 허용하세요. 그런 다음 배터리 → 앱 배터리 절약 → Stroom → 제한 없음으로 설정하세요.\n• Huawei/Honor(EMUI/HarmonyOS): 설정 → 앱 → 앱 실행 → Stroom → 수동 관리에서 자동 실행, 보조 실행, 백그라운드 활동을 허용하세요.\n• OPPO/OnePlus/realme(ColorOS): 설정 → 배터리 → 앱 배터리 관리 → Stroom에서 백그라운드 활동을 모두 허용하세요.\n• vivo/iQOO(OriginOS): iManager → 앱 관리 → 자동 시작에서 Stroom을 허용하세요.';

  @override
  String get platformTutorialAndroidStep7Title => '화면 잠금 시 정리 및 절전 모드 끄기';

  @override
  String get platformTutorialAndroidStep7Description =>
      '설정 → 배터리로 이동해 ‘절전’ 또는 ‘초절전’을 끄세요. ‘잠금 후 메모리 정리’도 ‘정리 안 함’으로 설정하세요. 절전 모드는 백그라운드 활동을 제한해 작업 완료에 영향을 줄 수 있습니다.';

  @override
  String get platformTutorialIosStep1Title => '백그라운드 앱 새로 고침 켜기';

  @override
  String get platformTutorialIosStep1Description =>
      '설정 → 일반 → 백그라운드 앱 새로 고침으로 이동해 Stroom을 찾아 켜세요. 최상의 사용 환경을 위해 ‘Wi-Fi 및 셀룰러 데이터’를 선택하세요.';

  @override
  String get platformTutorialIosStep2Title => '알림 허용';

  @override
  String get platformTutorialIosStep2Description =>
      '설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 작업 업데이트를 바로 확인할 수 있도록 배너와 알림 센터를 모두 활성화하세요.';

  @override
  String get platformTutorialIosStep3Title => '저전력 모드 끄기';

  @override
  String get platformTutorialIosStep3Description =>
      '설정 → 배터리로 이동해 ‘저전력 모드’를 끄세요. 이 모드가 켜져 있으면 시스템이 백그라운드 활동을 제한합니다.';

  @override
  String get platformTutorialIosStep4Title => 'iOS 백그라운드 제한 이해하기';

  @override
  String get platformTutorialIosStep4Description =>
      'iOS 26 이전 버전에서는 Android처럼 앱을 백그라운드에 계속 둘 수 없습니다. 백그라운드 앱 새로 고침, 위치 업데이트, 오디오 재생 등 특정 시점에만 잠시 실행할 수 있으며, 장시간 작업은 일시 중지될 수 있습니다. 다음을 권장합니다:\n• 장시간 작업 중에는 Stroom을 전면에 두세요.\n• 주기적으로 앱으로 돌아와 백그라운드 실행 시간을 갱신하세요.\n• 중요한 작업은 ‘작업 완료 알림’을 켜세요.';

  @override
  String get platformTutorialIosStep5Title => '작업 중 백그라운드 실행 팁';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 이상에서는 지속적인 백그라운드 작업을 지원합니다. 앱을 전환하거나 화면을 잠가도 작업은 대체로 계속되지만, 리소스가 부족하면 시스템이 중지할 수 있습니다. 진행 상황은 잠금 화면에 표시됩니다.\n\niOS 26 이전 버전에서는 지속적인 백그라운드 작업을 지원하지 않습니다. 몇 분마다(5~10분은 참고 기준이며 실제 간격은 시스템이 결정) 앱으로 돌아와 백그라운드 실행 시간을 갱신하고 일시 중지를 방지하세요.\n\n모든 버전에서 앱 전환 화면을 밀어 Stroom을 종료하지 마세요. 실행 중인 모든 작업이 즉시 중지됩니다.';

  @override
  String get platformTutorialIosStep6Title => '앱을 전면에 유지';

  @override
  String get platformTutorialIosStep6Description =>
      'iOS 26 이전 버전에서는 앱의 백그라운드 실행 시간이 제한됩니다. 장시간 작업 중에는 Stroom을 전면에 두거나 주기적으로 앱으로 돌아와 실행 시간을 연장하세요.';

  @override
  String get platformTutorialWindowsStep1Title => '창을 닫을 때 트레이로 최소화';

  @override
  String get platformTutorialWindowsStep1Description =>
      '기본적으로 창의 닫기 버튼을 누르면 Stroom이 종료되지 않고 시계 근처의 시스템 트레이로 최소화되어 계속 실행됩니다. 트레이 아이콘이나 ‘기본 창 표시’ 메뉴에서 다시 여세요. 작업 실행 중에는 앱을 종료하지 마세요. 종료하려면 ‘백그라운드 최적화’ 페이지의 ‘앱 완전히 종료’ 또는 트레이 메뉴의 ‘Stroom 종료’를 사용하세요.';

  @override
  String get platformTutorialWindowsStep2Title => '배터리 절약 모드 끄기';

  @override
  String get platformTutorialWindowsStep2Description =>
      '설정 → 시스템 → 전원 및 절전으로 이동해 배터리 절약 모드를 끄세요. 또는 배터리가 지정한 수준 아래로 떨어질 때만 켜지도록 설정할 수 있습니다.';

  @override
  String get platformTutorialWindowsStep3Title => '백그라운드 앱 허용';

  @override
  String get platformTutorialWindowsStep3Description =>
      '설정 → 개인 정보 및 보안 → 백그라운드 앱으로 이동해 Stroom을 찾아 켜져 있는지 확인하세요. Windows 11에서는 설정 → 앱 → 설치된 앱 → Stroom → 고급 옵션 → 백그라운드 앱 권한으로 이동해 ‘항상’을 선택하세요.';

  @override
  String get platformTutorialWindowsStep4Title => '절전 모드 끄기(선택 사항)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'Stroom을 장시간 실행하려면 설정 → 시스템 → 전원에서 ‘절전’을 ‘안 함’으로 설정하세요(전원에 연결된 경우에만).';

  @override
  String get platformTutorialWindowsStep5Title => 'Stroom을 시작 프로그램에 추가';

  @override
  String get platformTutorialWindowsStep5Description =>
      '작업 관리자(Ctrl+Shift+Esc) → 시작 앱으로 이동해 Stroom을 찾아 마우스 오른쪽 버튼으로 ‘사용’을 선택하세요. 또는 설정 → 앱 → 시작 프로그램에서 Stroom을 켜세요.';

  @override
  String get platformTutorialMacosStep1Title => '창을 닫을 때 트레이로 최소화';

  @override
  String get platformTutorialMacosStep1Description =>
      '기본적으로 창을 닫아도 Stroom은 화면 오른쪽 위의 메뉴 막대에서 계속 실행됩니다. 메뉴 막대 아이콘을 클릭하거나 ‘기본 창 표시’를 선택해 다시 여세요. 작업이 실행 중일 때 앱을 종료하지 마세요. 종료하려면 ‘백그라운드 최적화’ 페이지에서 ‘앱 완전히 종료’를 사용하거나 메뉴 막대 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get platformTutorialMacosStep2Title => '알림 허용';

  @override
  String get platformTutorialMacosStep2Description =>
      '시스템 설정 → 알림 → Stroom으로 이동해 ‘알림 허용’을 켜세요. 배너와 알림 센터를 모두 활성화하는 것이 좋습니다.';

  @override
  String get platformTutorialMacosStep3Title => '저전력 모드 끄기(MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      '시스템 설정 → 배터리 → 전원 어댑터로 이동해 ‘저전력 모드’를 끄세요. 이 모드는 백그라운드 활동을 제한합니다.';

  @override
  String get platformTutorialMacosStep4Title => '앱을 활성 상태로 유지';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS는 백그라운드 앱을 거의 제한하지 않습니다. 장시간 작업을 실행하려면 Stroom 창을 열어 두세요. 앱을 강제 종료하지 마세요. 창만 닫으면 됩니다.';

  @override
  String get platformTutorialMacosStep5Title => '로그인 시 자동 실행(선택 사항)';

  @override
  String get platformTutorialMacosStep5Description =>
      '시스템 설정 → 일반 → 로그인 항목으로 이동해 Stroom을 추가하면 컴퓨터를 켤 때 자동으로 시작됩니다.';

  @override
  String get platformTutorialLinuxStep1Title => '창을 닫을 때 트레이로 최소화';

  @override
  String get platformTutorialLinuxStep1Description =>
      '기본적으로 창을 닫으면 Stroom이 시스템 트레이에 숨겨집니다(빌드 시 StatusNotifierItem을 지원하는 데스크톱 환경과 libayatana-appindicator3-dev가 필요합니다). 트레이 메뉴에서 ‘기본 창 표시’를 선택해 다시 여세요. 작업이 실행 중일 때 앱을 종료하지 마세요. 종료하려면 ‘백그라운드 최적화’ 페이지의 ‘앱 완전히 종료’를 사용하거나 트레이 메뉴에서 ‘Stroom 종료’를 선택하세요.';

  @override
  String get platformTutorialLinuxStep2Title => '데스크톱 환경 설정';

  @override
  String get platformTutorialLinuxStep2Description =>
      '데스크톱 환경(GNOME, KDE, XFCE 등)에 따라 시스템 설정 → 앱으로 이동해 Stroom을 찾고 백그라운드 활동이 제한되지 않았는지 확인하세요.';

  @override
  String get platformTutorialLinuxStep3Title => 'systemd 서비스 사용(선택 사항)';

  @override
  String get platformTutorialLinuxStep3Description =>
      '장시간 백그라운드 작업을 실행하려면 systemd 사용자 서비스를 만드세요. ~/.config/systemd/user/ 아래에 stroom.service 파일을 만들고 ExecStart를 Stroom 실행 파일로 설정합니다.';

  @override
  String get platformTutorialLinuxStep4Title => '절전 비활성화';

  @override
  String get platformTutorialLinuxStep4Description =>
      '장시간 실행해야 하는 서버나 데스크톱에서는 /etc/systemd/logind.conf에서 HandleLidSwitch=ignore로 설정해 덮개를 닫아도 절전 상태가 되지 않도록 하세요.';

  @override
  String get platformTutorialLinuxStep5Title => '자동 시작 활성화';

  @override
  String get platformTutorialLinuxStep5Description =>
      'GNOME에서는 Tweaks → 시작 프로그램 → Stroom 추가를 사용하세요. 또는 ~/.config/autostart/ 아래에 stroom.desktop 파일을 만드세요.';

  @override
  String get platformTutorialWebStep1Title => '탭을 열어 두기';

  @override
  String get platformTutorialWebStep1Description =>
      '웹 브라우저는 백그라운드 서비스를 지원하지 않습니다. 작업이 실행되는 동안 Stroom 탭을 열어 두세요. 탭을 닫거나 페이지를 새로 고치면 작업이 즉시 중단됩니다.';

  @override
  String get platformTutorialWebStep2Title => '브라우저가 탭을 일시 중지하지 않도록 하기';

  @override
  String get platformTutorialWebStep2Description =>
      '브라우저는 리소스를 절약하기 위해 비활성 백그라운드 탭을 정지할 수 있습니다. 작업이 실행되는 동안 Stroom 탭을 전면에 두거나 페이지를 주기적으로 사용해 활성 상태를 유지하세요.';

  @override
  String get browserNavigationFailed => '페이지 이동 실패; 주소를 복원했습니다';

  @override
  String get browserAddressHint => '웹 주소 입력';

  @override
  String get browserUserScripts => '사용자 스크립트';

  @override
  String get browserSwitchToMobile => '모바일 보기로 전환';

  @override
  String get browserSwitchToDesktop => '데스크톱 보기로 전환';

  @override
  String get browserUaSwitchedDesktop => '데스크톱 사용자 에이전트로 전환됨';

  @override
  String get browserUaSwitchedMobile => '모바일 사용자 에이전트로 전환됨';

  @override
  String get browserCookieRetentionOnTooltip => '쿠키 유지(켜짐)';

  @override
  String get browserCookieRetentionOffTooltip => '쿠키 유지(꺼짐)';

  @override
  String get browserCookiePersistenceEnabled => '쿠키 저장 활성화됨';

  @override
  String get browserCookiePersistenceDisabled => '쿠키 저장 비활성화됨';

  @override
  String get browserSniffPanelHideTooltip => '감지 패널 숨기기';

  @override
  String get browserSniffPanelShowTooltip => '감지 패널 표시';

  @override
  String get browserAdd => '추가';

  @override
  String get browserNoScripts => '아직 스크립트가 없습니다. ‘추가’를 눌러 만드세요.';

  @override
  String get browserUnnamedScript => '이름 없는 스크립트';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '일치하는 규칙 $_temp0';
  }

  @override
  String get browserScriptOriginManual => '수동으로 추가됨';

  @override
  String browserScriptVersion(Object version) {
    return '@버전 $version';
  }

  @override
  String get browserScriptEnabled => '사용';

  @override
  String get browserScriptDisabled => '사용 안 함';

  @override
  String get browserScriptRuntimeError =>
      '이 스크립트에서 실행 오류가 발생했습니다. 코드와 페이지 호환성을 확인하세요.';

  @override
  String get browserScriptDelete => '삭제';

  @override
  String get browserDeleteScriptTitle => '스크립트를 삭제하시겠습니까?';

  @override
  String get browserDeleteScriptConfirmation =>
      '이 브라우저에서 스크립트를 제거합니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get browserEditScript => '스크립트 편집';

  @override
  String get browserScriptName => '스크립트 이름';

  @override
  String get browserScriptCode => '스크립트 코드(JavaScript)';

  @override
  String get browserAddScriptMethod => '스크립트 추가 방법 선택';

  @override
  String get browserImportFromUrl => 'URL에서 가져오기';

  @override
  String get browserEnterManually => '직접 입력';

  @override
  String get browserScriptTrustWarningTitle => '신뢰하는 스크립트만 가져오세요';

  @override
  String get browserScriptTrustWarning =>
      '스크립트는 데이터를 유출할 수 있으므로 신뢰하는 것만 추가하세요. 스크립트는 웹페이지 콘텐츠를 읽거나 수정할 수 있습니다.';

  @override
  String get browserContinue => '계속';

  @override
  String get browserManualUserscriptLabel => 'Tampermonkey 사용자 스크립트';

  @override
  String get browserScriptImportUrl => '스크립트 URL';

  @override
  String get browserScriptImportFetch => '미리보기 가져오기';

  @override
  String get browserScriptPreview => '스크립트 원본 미리보기';

  @override
  String get browserScriptImportInvalidUrl => '올바른 HTTPS URL을 입력하세요.';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Greasy Fork의 .user.js URL 또는 GitHub Raw URL을 사용하세요.';

  @override
  String get browserScriptImportRedirectedUrl =>
      '지원되지 않거나 안전하지 않은 주소로 리디렉션되었습니다.';

  @override
  String get browserScriptImportNotScript =>
      '응답이 비어 있거나 JavaScript 스크립트로 보이지 않습니다.';

  @override
  String get browserScriptImportNetworkError =>
      '스크립트를 가져올 수 없습니다. URL과 연결 상태를 확인하세요.';

  @override
  String browserScriptImportHttpError(Object status) {
    return '서버가 HTTP $status를 반환했습니다.';
  }

  @override
  String get browserCancel => '취소';

  @override
  String get browserSave => '저장';

  @override
  String get browserCookiesConfirmClear => '삭제 확인';

  @override
  String get browserCookiesConfirmClearAll =>
      '쿠키를 모두 삭제하시겠습니까?\n이 작업은 취소할 수 없습니다.';

  @override
  String get browserCookiesClear => '삭제';

  @override
  String get browserCookiesCancel => '취소';

  @override
  String get browserCookiesClearedAll => '쿠키를 모두 삭제했습니다';

  @override
  String get browserCookiesClearFailed => '삭제할 수 없습니다. 다시 시도하세요.';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return '$domain의 쿠키를 모두 삭제했습니다';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '$domain의 쿠키를 모두 삭제하시겠습니까?';
  }

  @override
  String get browserCookiesPageTitle => '브라우저 데이터 관리';

  @override
  String get browserCookiesRetentionTitle => '종료할 때 쿠키 유지';

  @override
  String get browserCookiesRetentionOn => '사용 — 종료할 때 쿠키를 유지합니다';

  @override
  String get browserCookiesRetentionOff => '사용 안 함 — 종료할 때 쿠키를 삭제합니다';

  @override
  String get browserCookiesClearAllTitle => '쿠키 모두 삭제';

  @override
  String get browserCookiesClearAllDescription => '저장된 웹사이트 쿠키를 모두 삭제합니다';

  @override
  String get browserCookiesEmptyTitle => '저장된 데이터 없음';

  @override
  String get browserCookiesEmptyDescription =>
      '기본 제공 브라우저를 사용하고 쿠키 저장을 켜면 여기에 저장된 데이터가 표시됩니다.';

  @override
  String browserCookiesStoredCount(Object count) {
    return '저장된 쿠키($count개)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '쿠키 $_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip => '이 도메인의 쿠키 모두 삭제';

  @override
  String get browserCookiesDeleteOneTooltip => '이 쿠키 삭제';

  @override
  String get browserCookiesDeletedOne => '쿠키 삭제됨';

  @override
  String get browserCookiesDeleteFailed => '삭제할 수 없습니다. 다시 시도하세요.';

  @override
  String get browserCookiesEmptyValue => '(빈 값)';

  @override
  String get platformTutorialPageTitle => '플랫폼별 안내';

  @override
  String get browserRecoveryOpenPage => '복구 페이지 열기';

  @override
  String galleryUnsupportedPreview(String format) {
    return '.$format 파일은 미리보기를 지원하지 않습니다';
  }

  @override
  String galleryCameraFailed(String error) {
    return '사진을 찍을 수 없습니다: $error';
  }

  @override
  String get galleryPhotoSaved => '사진 저장됨';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return '지원하지 않는 형식을 건너뜀: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미지 #개 가져옴',
      one: '이미지 #개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동영상 #개 가져옴',
      one: '동영상 #개 가져옴',
    );
    return '$_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get galleryFileReadFailed => '파일 데이터를 읽을 수 없습니다';

  @override
  String get galleryExportImageTitle => '이미지 내보내기';

  @override
  String get galleryExportVideoTitle => '동영상 내보내기';

  @override
  String galleryExportedTo(String path) {
    return '다음 위치로 내보냄: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get galleryChooseExportDirectory => '내보낼 디렉터리 선택';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 #개 내보냄',
      one: '파일 #개 내보냄',
    );
    return '$_temp0';
  }

  @override
  String get galleryFolderExportTitle => '폴더 내보내기';

  @override
  String get galleryWebFolderExportInfo =>
      '브라우저에서 내보낼 디렉터리를 선택할 수 없습니다. 폴더 구조를 유지하는 ZIP 파일을 다운로드합니다.';

  @override
  String get galleryDownloadZip => 'ZIP 파일 다운로드';

  @override
  String get galleryExportImageFolderTitle => '이미지 폴더 내보내기';

  @override
  String get galleryExportVideoFolderTitle => '동영상 폴더 내보내기';

  @override
  String get galleryImagePageTitle => '갤러리';

  @override
  String get galleryVideoPageTitle => '동영상';

  @override
  String get galleryTakePhoto => '사진 촬영';

  @override
  String get galleryRecordVideo => '녹화';

  @override
  String get galleryImport => '가져오기';

  @override
  String get galleryExportToLocal => '로컬로 내보내기';

  @override
  String get galleryPlayVideo => '재생';

  @override
  String galleryCopyFailed(String error) {
    return '복사 실패: $error';
  }

  @override
  String get galleryVideoSaved => '동영상 저장됨';

  @override
  String galleryVideoRecordFailed(String error) {
    return '녹화 실패: $error';
  }

  @override
  String get galleryVideoLoadFailed => '동영상을 불러올 수 없습니다';

  @override
  String get imageEditorSaveImageTitle => '이미지 저장';

  @override
  String get imageEditorSaveImagePrompt => '이미지를 저장할 방법 선택:';

  @override
  String get imageEditorOverwrite => '덮어쓰기';

  @override
  String get imageEditorSaveAs => '다른 이름으로 저장';

  @override
  String get imageEditorSavePhotoTitle => '사진 저장';

  @override
  String get imageEditorSavePhotoPrompt => '이 사진을 저장하시겠습니까?';

  @override
  String get imageEditorDiscard => '버리기';

  @override
  String get imageEditorDoneLoading => '이미지를 생성하는 중입니다. 잠시 기다려 주세요…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return '빠른 편집 – $fileName';
  }

  @override
  String get imageEditorNotReady => '편집기를 아직 사용할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String imageEditorProcessingFailed(String error) {
    return '이미지를 처리할 수 없습니다: $error';
  }

  @override
  String get imageEditorLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get imageEditorProcessing => '이미지를 처리하는 중입니다. 잠시 기다려 주세요…';

  @override
  String get imageEditorRotateLeft => '왼쪽으로 회전';

  @override
  String get imageEditorRotateRight => '오른쪽으로 회전';

  @override
  String get imageEditorFlip => '뒤집기';

  @override
  String get imageEditorCrop => '자르기';

  @override
  String get imageViewerImageSavedAsCopy => '이미지를 복사본으로 저장했습니다';

  @override
  String get imageViewerImageUpdated => '이미지를 업데이트했습니다';

  @override
  String imageViewerSaveFailed(String error) {
    return '이미지를 저장할 수 없습니다: $error';
  }

  @override
  String get imageViewerInvalidIndex => '잘못된 이미지 인덱스';

  @override
  String get galleryExportImageArchiveFileName => '이미지-내보내기.zip';

  @override
  String get galleryExportVideoArchiveFileName => '동영상-내보내기.zip';

  @override
  String get galleryExportImageFolderArchiveFileName => '이미지-폴더-내보내기.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName => '동영상-폴더-내보내기.zip';

  @override
  String get catCatchPageTitle => '웹 리소스 다운로드';

  @override
  String get catCatchAddTask => '작업 추가';

  @override
  String get catCatchOpenBrowser => '기본 제공 브라우저';

  @override
  String get catCatchEmptyState => '아직 다운로드 작업이 없습니다';

  @override
  String get catCatchEmptyStateHint => '오른쪽 위의 +를 눌러 다운로드 작업을 추가하세요';

  @override
  String get catCatchInvalidCapturedUrl => '캡처한 URL이 올바르지 않습니다';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return '브라우저에서 캡처함: $url';
  }

  @override
  String get catCatchEnterValidUrl => '올바른 URL을 하나 이상 입력하세요';

  @override
  String get catCatchTaskAdded => '작업 추가됨';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 추가됨',
      one: '$count개 추가됨',
    );
    return '작업 $_temp0';
  }

  @override
  String get catCatchViewTaskList => '작업 목록 보기';

  @override
  String get catCatchUrlHint => '동영상/오디오 웹페이지 URL 입력';

  @override
  String get catCatchDeleteTask => '이 작업 삭제';

  @override
  String get catCatchHour => '시간';

  @override
  String get catCatchMinute => '분';

  @override
  String get catCatchSecond => '초';

  @override
  String get catCatchDurationPreview => '미리보기: ';

  @override
  String get catCatchDurationFormat => '시:분:초';

  @override
  String get catCatchDurationFilterHint =>
      '선택 사항: 길이로 동영상 리소스를 필터링합니다. 비워 두면 선택 가능한 모든 리소스를 표시합니다.';

  @override
  String get catCatchVideoSaveTo => '동영상 저장 위치';

  @override
  String get catCatchAudioSaveTo => '오디오 저장 위치';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 추가됨',
      one: '$count개 추가됨',
    );
    return '작업 $_temp0';
  }

  @override
  String get catCatchStartAnalysis => '분석';

  @override
  String get catCatchVideoFolderTitle => '동영상 저장 폴더';

  @override
  String get catCatchAudioFolderTitle => '오디오 저장 폴더';

  @override
  String get catCatchRootFolder => '루트 폴더';

  @override
  String connectivityTestTitle(String title) {
    return '$title · 연결 테스트';
  }

  @override
  String get connectivityTestJsonLabel => '테스트 내용(JSON)';

  @override
  String get connectivityTestJsonHelp =>
      '변경사항을 바로 실행하거나 저장할 수 있습니다. MCP는 읽기 전용 tools/list를 사용하고, 검색 도구에서는 검색어/결과 수를 변경할 수 있습니다. Todo는 기본적으로 읽기 전용입니다.';

  @override
  String connectivityTestSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get connectivityTestSaved => '테스트 내용 저장됨';

  @override
  String get connectivityTestClose => '닫기';

  @override
  String get connectivityTestSaveContent => '내용 저장';

  @override
  String get connectivityTestTesting => '테스트 중…';

  @override
  String get connectivityTestRun => '테스트 실행';

  @override
  String get connectivityTestFailedSummary => '테스트를 완료하지 못했습니다';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds초';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds밀리초';
  }

  @override
  String get messageSearchTitle => '메시지 검색';

  @override
  String get messageSearchHint => '모든 대화에서 메시지 검색...';

  @override
  String get messageSearchInitialState => '모든 대화에서 메시지를 검색하려면 키워드를 입력하세요';

  @override
  String get messageSearchEmptyState => '일치하는 메시지가 없습니다';

  @override
  String get messageSearchNewConversation => '새 대화';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '$count개',
    );
    return '일치 항목 $_temp0';
  }

  @override
  String get filesTabText => '텍스트';

  @override
  String get filesTabAudio => '오디오';

  @override
  String get filesTabImages => '이미지';

  @override
  String get filesTabVideos => '동영상';

  @override
  String get filesReorderTabs => '탭 순서 변경';

  @override
  String get filesReorderCancel => '취소';

  @override
  String get filesReorderDone => '완료';

  @override
  String get bgTaskCancelled => '취소됨';

  @override
  String bgTaskAsrError(String details) {
    return '음성 받아쓰기 실패: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return '음성 받아쓰기 저장 실패: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR 실패: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'OCR 결과 저장 실패: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR 결과가 불완전합니다: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => '일부 OCR 페이지를 완료하지 못했습니다';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return ' · 단계 ${phaseElapsedMs}ms · 요청 $completedRequests개 · 청크 $completedChunks/$chunkCount개 완료';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return '오디오$chunk 업로드 중 $percent% · $bytes바이트$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return '오디오$chunk 업로드 중$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return ' (청크 $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return '음성 받아쓰는 중$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return '음성 받아쓰는 중(청크 $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return '음성 받아쓰는 중(청크 $index/$count 수신)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return '결과 수신 중 $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => '결과 수신 중';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return '음성 받아쓰는 중(청크 $index/$count개 완료)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return '음성 받아쓰는 중(청크 $index/$count 반환됨)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return '이미지 $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return '$details 업로드 중';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return '이미지 업로드 중 $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR 복구 체크포인트를 저장하지 못해 요청 결과를 확인할 수 없습니다. 작업을 중지했습니다: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR 복구 체크포인트를 저장하지 못해 이 청크를 전송하지 않았습니다. 로컬 저장소를 수정한 후 다시 시도할 수 있습니다: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return '취소하기 전에 ASR 청크 상태를 저장하지 못해 이 청크의 결과를 확인할 수 없습니다: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'ASR 다시 시도용 오디오를 저장하지 못해 작업을 전송하지 않았습니다: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError => '다른 오디오 파일을 저장하지 못해 전송을 취소했습니다';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR 결과가 불완전합니다(finish_reason=$finishReason)';
  }

  @override
  String ocrResultPageHeading(String index) {
    return '이미지 $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return '이미지 $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => ' (일부 결과)';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return '일부 이미지를 완전히 인식하지 못했습니다: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return '이미지 $index: 결과 불완전';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return '이미지 $index: 인식 실패';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => '; ';

  @override
  String get bgTaskInterruptedOnRestart => '앱을 다시 시작하는 동안 중단됨';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR 오류 세부정보가 숨겨졌습니다';

  @override
  String get bgTaskErrorDetailsHidden => '오류 세부정보가 숨겨졌습니다';

  @override
  String get notificationBannerTaskCompletedHeading => '작업 완료';

  @override
  String get notificationBannerTaskFailedHeading => '작업 실패';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return '작업 완료: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return '작업 실패: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title 완료됨';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title 실패: $error';
  }

  @override
  String get notificationUnknownError => '알 수 없는 오류';

  @override
  String get desktopTrayTooltip => 'Stroom이 백그라운드에서 실행 중입니다';

  @override
  String get desktopTrayOpen => 'Stroom 열기';

  @override
  String get desktopTrayShowMainWindow => '기본 창 표시';

  @override
  String get desktopTrayQuitStroom => 'Stroom 종료';

  @override
  String get providerPresetExaDescription =>
      'Exa MCP를 통해 웹을 검색하고 페이지 콘텐츠를 추출하며, 시맨틱 및 키워드 검색으로 심층 조사를 지원합니다.';

  @override
  String get providerPresetExaApiKeyHint => 'Exa 웹사이트에서 API 키를 받으세요.';

  @override
  String get providerPresetTavilyDescription =>
      '대규모 언어 모델에 최적화된 실시간 웹 검색을 제공하는 AI 기반 검색 엔진입니다.';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Tavily에서 API 키를 받으세요. ?tavilyApiKey= 또는 Authorization: Bearer 헤더를 지원합니다.';

  @override
  String get providerPresetJinaDescription =>
      '웹 콘텐츠 추출, 임베딩 생성, 검색 결과 조회를 제공하는 멀티모달 AI 서비스입니다.';

  @override
  String get providerPresetJinaApiKeyHint =>
      '웹사이트에서 Jina AI API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetFirecrawlDescription =>
      '웹페이지를 깔끔한 Markdown이나 구조화된 데이터로 변환하는 웹 크롤링 및 추출 서비스입니다.';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Firecrawl API 키를 받거나 무료 사용량 한도 내에서 키 없이 사용해 보세요.';

  @override
  String get providerPresetZhipuDescription =>
      '웹페이지를 가져오고 이해하는 Zhipu AI 웹 리더 MCP 서비스입니다.';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Zhipu AI 오픈 플랫폼에서 API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetBraveSearchDescription =>
      '고품질 검색 결과를 제공하는 개인정보 보호 중심의 독립 검색 엔진입니다.';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Brave Search 웹사이트에서 API 키를 받으세요.';

  @override
  String get providerPresetBochaDescription =>
      'Bocha AI 웹 검색은 중국어 페이지에 대한 지능형 검색 결과를 제공합니다.';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Bocha AI 오픈 플랫폼에서 API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetQueritDescription =>
      'Querit AI 검색은 지능형 검색과 콘텐츠 탐색을 제공합니다.';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Querit 웹사이트에서 API 키(Bearer 토큰)를 받으세요.';

  @override
  String get providerPresetSearxngDescription =>
      '개인정보 보호에 중점을 두고 여러 검색 소스를 통합하는 자체 호스팅 메타 검색 엔진입니다.';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'SearXNG 인스턴스 URL을 설정하세요(예: http://your-instance:8080). API 키는 선택 사항입니다.';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS 합성 실패: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '\n원래 오류: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      '네트워크 연결 시간이 초과되었습니다. 네트워크 또는 API 주소를 확인하세요.';

  @override
  String get ttsErrorServerResponseTimeout =>
      '서버 응답 시간이 초과되었습니다. 나중에 다시 시도하세요.';

  @override
  String ttsErrorConnectionFailed(String details) {
    return '서버에 연결할 수 없습니다($details).';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return '서버에 연결할 수 없습니다. 웹 앱에서는 CORS 제한 또는 잘못된 API 주소가 원인일 수 있습니다. $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API 오류(HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return '연결 시간이 초과되었습니다. 네트워크를 확인하세요$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return '응답 수신 시간이 초과되었습니다. 서버 응답이 느립니다$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API 키가 올바르지 않거나 권한이 없습니다(HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return '요청이 너무 많습니다. 나중에 다시 시도하세요(HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API 엔드포인트를 찾을 수 없습니다(HTTP $status): $body\nAPI 기본 URL이 올바른지 확인하세요$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return '서버 내부 오류(HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return '서버 오류(HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return '요청이 취소되었습니다$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return '서버에 연결할 수 없습니다. 웹 앱에서는 CORS 제한 또는 잘못된 API 주소가 원인일 수 있습니다. 제공업체 API 주소가 올바르고 서버가 교차 출처 요청을 허용하는지 확인하세요.$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return '네트워크 오류: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => '알 수 없는 네트워크 오류';

  @override
  String get ttsErrorNoResponseBody => '응답 본문이 없습니다';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return '스트리밍 합성 실패: $details';
  }

  @override
  String get mermaidEditorTitle => 'Mermaid 차트 편집기';

  @override
  String get mermaidEditorModeEdit => '편집';

  @override
  String get mermaidEditorModeSplit => '편집 + 미리보기';

  @override
  String get mermaidEditorModePreview => '미리보기';

  @override
  String get mermaidEditorSwitchViewMode => '보기 모드 전환';

  @override
  String get mermaidEditorSaveToTextStorage => '텍스트 저장소에 저장';

  @override
  String get mermaidEditorEmptyChart => '차트 내용이 비어 있어 저장할 수 없습니다';

  @override
  String get mermaidEditorSaveChartTitle => '차트 저장';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      '.mmd 차트 파일을 저장할 폴더를 선택하거나 만드세요';

  @override
  String get mermaidEditorFileNameHint => '파일 이름 입력(.mmd 자동 추가)';

  @override
  String get mermaidEditorEmptyFileName => '파일 이름은 비워 둘 수 없습니다';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return '텍스트 저장소에 저장됨: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor => '미리보기와 편집기 패널 전환';

  @override
  String get mermaidEditorCodeLabel => 'Mermaid 코드';

  @override
  String get mermaidEditorCodeHint => 'Mermaid 코드 입력...';

  @override
  String get mermaidEditorSplitCodeLabel => '코드';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'SSE 연결 실패(HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'SSE 연결 실패(HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable => 'SSE 연결 실패: 서버에 연결할 수 없습니다';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'HTTP 요청 실패(HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => '요청 실패';

  @override
  String get sseNetworkRequestFailed => '네트워크 요청 실패';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return '네트워크 요청 실패(HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return '네트워크 요청 실패(HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable => '네트워크 요청 실패: 서버에 연결할 수 없습니다';

  @override
  String get sseRequestCancelled => '요청이 취소되었습니다';

  @override
  String get startupSafetyTitle => '데이터 안전 보호';

  @override
  String get startupSafetyExportButton => '데이터 내보내기';

  @override
  String get startupSafetyExitButton => '앱 종료';

  @override
  String get startupSafetyUpdateButton => '앱 업데이트';

  @override
  String get startupSafetyCheckingUpdates => '업데이트 확인 중...';

  @override
  String get startupSafetyUpToDate => '최신 버전을 사용 중입니다';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return '이 데이터는 앱의 최신 버전($version)에서 생성되었습니다.\n\n현재 앱 버전에서는 데이터를 안전하게 읽을 수 없습니다. 최신 버전을 설치한 후 계속하세요. 데이터는 변경되지 않았습니다.';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      '데이터 안전 상태를 확인할 수 없습니다(상태 표시를 읽을 수 없거나 올바르지 않습니다).\n\n멈춘 상태를 덮어쓰지 않도록 데이터를 복구하거나 형식을 마이그레이션하지 않고 시작을 차단했습니다. 먼저 데이터 파일을 내보낸 다음 앱을 종료하고 상태 표시를 복구한 후 다시 시도하세요.';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return '데이터 형식 마이그레이션에 실패했습니다($part).\n\n데이터를 보호하기 위해 아무것도 변경하지 않았습니다. 이전 앱 버전으로 돌아가거나 수정된 버전이 나올 때까지 기다리세요.';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return '데이터 형식 마이그레이션에 실패했습니다($part).\n\n데이터를 마이그레이션 전 상태로 복원했습니다. 데이터 보호를 위해 이전 앱 버전으로 돌아가거나 수정된 버전이 나올 때까지 기다리세요.';
  }

  @override
  String get startupSafetyDataCorrupted =>
      '데이터가 손상되어 자동으로 복구할 수 없습니다.\n\n추가 손상을 막기 위해 앱을 정지했습니다. 데이터 파일을 내보낸 후 직접 가져오거나 앱을 다시 설치하세요.';

  @override
  String get startupSafetyPreferencesUnavailable =>
      '시작 확인에 필요한 환경설정을 읽지 못해 데이터를 보호하기 위해 앱 시작을 차단했습니다.\n\n저장 공간이나 권한을 확인한 뒤 앱을 다시 여세요.';

  @override
  String get startupSafetyValidationUnavailable =>
      '시작 데이터 안전 검사를 완료하지 못해 데이터를 보호하기 위해 앱 시작을 차단했습니다.\n\n브라우저 설정을 확인한 뒤 앱을 다시 여세요.';

  @override
  String startupSafetyCheckFailed(String detail) {
    return '시작 확인 실패: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      '시작 확인 후에도 데이터 안전 상태를 확인할 수 없습니다(상태 표시를 읽을 수 없거나 올바르지 않습니다).\n\n데이터가 더 변경되지 않도록 시작을 중지했습니다. 데이터 파일을 내보내고 앱을 종료한 뒤 상태 표시를 복구하고 다시 시도하세요.';

  @override
  String get catCatchConnectionTimeout =>
      '연결 시간이 초과되었습니다. 네트워크 또는 서버 상태를 확인하세요.';

  @override
  String get catCatchSendTimeout => '요청을 보내는 중 시간이 초과되었습니다.';

  @override
  String get catCatchReceiveTimeout => '서버 응답이 너무 느려 응답 시간이 초과되었습니다.';

  @override
  String get catCatchCannotConnect => '서버에 연결할 수 없습니다.';

  @override
  String get catCatchConnectionError => '서버에 연결할 수 없습니다. URL이 올바른지 확인하세요.';

  @override
  String get catCatchBadCertificate => '서버 인증서를 확인할 수 없습니다.';

  @override
  String catCatchBadResponse(int statusCode) {
    return '서버 오류(HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => '요청이 취소되었습니다.';

  @override
  String catCatchNetworkError(String message) {
    return '네트워크 오류: $message';
  }

  @override
  String get catCatchUnknownError => '알 수 없는 오류';

  @override
  String catCatchOriginalError(String message) {
    return '원래 오류: $message';
  }

  @override
  String get catCatchWebDownloadHint => '웹 브라우저에서는 미디어 파일을 직접 다운로드할 수 없습니다.';

  @override
  String get catCatchWebInstallExtension =>
      'CatCatch 브라우저 확장 프로그램을 설치한 후 다시 시도하세요.';

  @override
  String get catCatchWebAuthorAttribution =>
      '제작자: 笨笨猫 (xifangczy). 무료 오픈 소스입니다.';

  @override
  String get catCatchWebOfficialWarning =>
      '제작자가 배포한 버전인지 확인하고, 유료 버전이나 모방 버전은 피하세요.';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      '이 기능을 사용하려면 로그인해야 합니다. 오른쪽 위의 브라우저에서 로그인하세요.';

  @override
  String get catCatchNoUsableMedia =>
      '사용 가능한 미디어 리소스가 없습니다. URL과 웹사이트 연결 상태를 확인하세요.';

  @override
  String get catCatchRedownloadFileMissing => '다운로드한 파일이 없어 다운로드에 실패했습니다.';

  @override
  String get catCatchRedownloadPathEmpty => '다운로드한 파일 경로가 비어 있어 다운로드에 실패했습니다.';

  @override
  String get catCatchWebBrowserRequired =>
      '브라우저 환경 없이는 이 페이지의 리소스를 가져올 수 없습니다. 모바일 또는 데스크톱에서 기능을 사용하거나 동영상/오디오 파일의 직접 URL을 붙여넣으세요.';

  @override
  String get catCatchPlaylistNoSegments => '재생 목록에 다운로드할 세그먼트가 없습니다.';

  @override
  String get catCatchDownloadedSourceMissing =>
      '다운로드한 원본 파일이 없습니다. 다시 다운로드하세요.';

  @override
  String get appLogPageTitle => '앱 로그';

  @override
  String get appLogRefresh => '새로 고침';

  @override
  String get appLogCleanupOldLogs => '오래된 로그 정리';

  @override
  String get appLogCleanupDone => '오래된 로그를 정리했습니다';

  @override
  String appLogRetentionNotice(int days) {
    return '로그 보관 기간: 최근 $days일의 로그만 보관하며, $days일이 지난 로그는 자동으로 정리됩니다.';
  }

  @override
  String get appLogWebUnsupported => '웹에서는 로컬 로그를 지원하지 않습니다';

  @override
  String get appLogNoFiles => '아직 로그 파일이 없습니다';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '자동 새로 고침 중(시도 $count회)...',
      one: '자동 새로 고침 중(시도 $count회)...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated => '앱이 실행 중일 때 로그가 생성됩니다';

  @override
  String get appLogExport => '내보내기';

  @override
  String get appLogDelete => '삭제';

  @override
  String get appLogConfirmDeleteTitle => '삭제 확인';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return '로그 파일 ‘$fileName’을(를) 삭제하시겠습니까?';
  }

  @override
  String get appLogCancel => '취소';

  @override
  String appLogLoadFilesError(Object error) {
    return '로그 파일 목록을 불러오지 못했습니다: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return '로그 파일 ‘$fileName’이(가) 있지만 읽을 수 없습니다. 손상되었을 수 있습니다.';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return '로그 파일 ‘$fileName’을(를) 찾을 수 없습니다. 이미 정리되었을 수 있습니다.';
  }

  @override
  String appLogReadFileError(Object error) {
    return '로그 파일을 읽지 못했습니다: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return '삭제됨: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return '삭제 실패: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return '로그 파일 ‘$fileName’을(를) 찾을 수 없습니다';
  }

  @override
  String appLogPathCopied(String filePath) {
    return '경로 복사됨: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return '내보내기 실패: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '줄 $count개',
      one: '줄 $count개',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => '모두 복사';

  @override
  String get appLogStructuredView => '구조화된 보기';

  @override
  String get appLogRawView => '원시 보기';

  @override
  String appLogCopyError(Object error) {
    return '복사 실패: $error';
  }

  @override
  String get appLogCopyDone => '모든 로그 내용을 복사했습니다';

  @override
  String get iosContinuedTaskTitle => '백그라운드 작업';

  @override
  String get mermaidCatalogTypeFlowchart => '순서도';

  @override
  String get mermaidCatalogDescriptionFlowchart => '순서도 — 단계, 분기, 반복을 표시합니다';

  @override
  String get mermaidCatalogTypeSequenceDiagram => '시퀀스 다이어그램';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      '시퀀스 다이어그램 — 참여자 간 상호작용을 표시합니다';

  @override
  String get mermaidCatalogTypeClassDiagram => '클래스 다이어그램';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      '클래스 다이어그램 — 클래스 속성과 메서드 간 관계를 표시합니다';

  @override
  String get mermaidCatalogTypeStateDiagram => '상태 다이어그램';

  @override
  String get mermaidCatalogDescriptionStateDiagram => '상태 다이어그램 — 상태 전환을 표시합니다';

  @override
  String get mermaidCatalogTypeErDiagram => 'ER 다이어그램';

  @override
  String get mermaidCatalogDescriptionErDiagram => 'ER 다이어그램 — 엔터티 간 관계를 표시합니다';

  @override
  String get mermaidCatalogTypeGantt => '간트 차트';

  @override
  String get mermaidCatalogDescriptionGantt => '간트 차트 — 프로젝트 일정을 표시합니다';

  @override
  String get mermaidCatalogTypePie => '원형 차트';

  @override
  String get mermaidCatalogDescriptionPie => '원형 차트 — 비율 데이터를 표시합니다';

  @override
  String get mermaidCatalogTypeJourney => '사용자 여정';

  @override
  String get mermaidCatalogDescriptionJourney => '사용자 여정 — 사용자 경험의 흐름을 표시합니다';

  @override
  String get mermaidCatalogTypeGitGraph => 'Git 그래프';

  @override
  String get mermaidCatalogDescriptionGitGraph => 'Git 그래프 — 브랜치와 커밋을 표시합니다';

  @override
  String get mermaidCatalogTypeMindmap => '마인드맵';

  @override
  String get mermaidCatalogDescriptionMindmap => '마인드맵 — 계층 구조를 표시합니다';

  @override
  String get mermaidCatalogTypeTimeline => '타임라인';

  @override
  String get mermaidCatalogDescriptionTimeline => '타임라인 — 시간순으로 이벤트를 표시합니다';

  @override
  String get mermaidCatalogTypeBlock => '블록 다이어그램';

  @override
  String get mermaidCatalogDescriptionBlock => '블록 다이어그램 — 블록 배치와 관계를 표시합니다';

  @override
  String get mermaidCatalogTypeRequirement => '요구사항 다이어그램';

  @override
  String get mermaidCatalogDescriptionRequirement =>
      '요구사항 다이어그램 — 요구사항과 구현 간 관계를 표시합니다';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[시작]\n  B[처리 단계]\n  C<MERMAID_OPEN_BRACE>조건<MERMAID_CLOSE_BRACE>\n  D[종료]\n\n  A --> B\n  B --> C\n  C -->|예| D\n  C -->|아니요| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"사용자\" as user\n  participant \"시스템\" as system\n  participant \"데이터베이스\" as database\n\n  user->>system: 요청 전송\n  system->>database: 데이터 조회\n  database-->>system: 결과 반환\n  system-->>user: 결과 표시';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String 이름\n    +int 나이\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String 학생ID\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String 교사ID\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"대기 중\" as pending\n  state \"처리 중\" as processing\n  state \"완료\" as completed\n  state \"실패\" as failed\n  [*] --> pending\n  pending --> processing\n  processing --> completed\n  processing --> failed\n  failed --> pending\n  completed --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : 주문\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : 포함\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : 구성\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title 프로젝트 간트 차트\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section 요구사항\n  요구사항 분석      :a1, 2024-01-01, 14d\n  프로토타입 설계    :a2, after a1, 10d\n\n  section 개발\n  프런트엔드 개발   :b1, after a2, 20d\n  백엔드 개발       :b2, after a2, 20d\n  API 통합          :b3, after b1, 7d\n\n  section 테스트\n  기능 테스트       :c1, after b3, 10d\n  배포              :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title 데이터 분포\n  \"범주 A\" : 40\n  \"범주 B\" : 25\n  \"범주 C\" : 20\n  \"범주 D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title 사용자 등록\n  section 가입\n    가입 페이지 열기: 5: 사용자\n    정보 입력: 3: 사용자\n    요청 제출: 4: 사용자\n  section 확인\n    코드 받기: 3: 시스템\n    코드 입력: 4: 사용자\n    확인 완료: 5: 시스템, 사용자';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"초기 커밋\"\n  commit id: \"기능 A 추가\"\n  branch develop\n  checkout develop\n  commit id: \"새 기능 개발\"\n  commit id: \"버그 수정\"\n  checkout main\n  merge develop\n  commit id: \"v1.0 출시\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((프로젝트 관리))\n    요구사항\n      기능\n      비기능\n    개발\n      프런트엔드\n      백엔드\n    테스트\n      단위 테스트\n      통합 테스트\n    배포\n      테스트 환경\n      운영 환경';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title 프로젝트 주요 일정\n  2024-Q1 : 요구사항 조사 : 계획 확정\n  2024-Q2 : 개발 : 기능 구현\n  2024-Q3 : 테스트 : 버그 수정 : 성능 조정\n  2024-Q4 : 배포 : 운영 및 유지보수';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"요구사항\"] B[\"개발\"] C[\"테스트\"]\n  D[\"배포\"] E[\"운영\"] F[\"모니터링\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement 사용자 로그인 <MERMAID_OPEN_BRACE>\n    id: 1\n    text: 사용자는 계정과 비밀번호로 로그인할 수 있습니다\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element 로그인 페이지 <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element 인증 서비스 <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  로그인 페이지 - satisfies -> 사용자 로그인\n  인증 서비스 - verifies -> 사용자 로그인';

  @override
  String get mermaidCatalogDefaultFileName => '내 차트';

  @override
  String get mermaidCatalogActionAddNode => '노드 추가';

  @override
  String get mermaidCatalogActionAddDecision => '분기 추가';

  @override
  String get mermaidCatalogActionAddEdge => '연결선 추가';

  @override
  String get mermaidCatalogActionAddSubgraph => '하위 그래프 추가';

  @override
  String get mermaidCatalogActionAddParticipant => '참여자 추가';

  @override
  String get mermaidCatalogActionAddRequest => '요청 추가';

  @override
  String get mermaidCatalogActionAddResponse => '응답 추가';

  @override
  String get mermaidCatalogActionAddNote => '메모 추가';

  @override
  String get mermaidCatalogActionAddClass => '클래스 추가';

  @override
  String get mermaidCatalogActionAddInheritance => '상속 추가';

  @override
  String get mermaidCatalogActionAddRelationship => '관계 추가';

  @override
  String get mermaidCatalogActionAddAggregation => '집합 관계 추가';

  @override
  String get mermaidCatalogActionAddState => '상태 추가';

  @override
  String get mermaidCatalogActionAddTransition => '전환 추가';

  @override
  String get mermaidCatalogActionAddStart => '시작 추가';

  @override
  String get mermaidCatalogActionAddEnd => '종료 추가';

  @override
  String get mermaidCatalogActionAddEntity => '엔터티 추가';

  @override
  String get mermaidCatalogActionAddOneToMany => '일대다 관계 추가';

  @override
  String get mermaidCatalogActionAddManyToMany => '다대다 관계 추가';

  @override
  String get mermaidCatalogActionAddOneToOne => '일대일 관계 추가';

  @override
  String get mermaidCatalogActionAddPhase => '단계 추가';

  @override
  String get mermaidCatalogActionAddTask => '작업 추가';

  @override
  String get mermaidCatalogActionAddDependentTask => '후속 작업 추가';

  @override
  String get mermaidCatalogActionAddMilestone => '마일스톤 추가';

  @override
  String get mermaidCatalogActionAddCategory => '범주 추가';

  @override
  String get mermaidCatalogActionAddTitle => '제목 추가';

  @override
  String get mermaidCatalogActionAddSystemTask => '시스템 작업 추가';

  @override
  String get mermaidCatalogActionAddMultiPersonTask => '다인 작업 추가';

  @override
  String get mermaidCatalogActionAddCommit => '커밋 추가';

  @override
  String get mermaidCatalogActionCreateBranch => '브랜치 만들기';

  @override
  String get mermaidCatalogActionSwitchBranch => '브랜치 전환';

  @override
  String get mermaidCatalogActionMergeBranch => '브랜치 병합';

  @override
  String get mermaidCatalogActionAddBranch => '브랜치 추가';

  @override
  String get mermaidCatalogActionAddChildBranch => '하위 브랜치 추가';

  @override
  String get mermaidCatalogActionAddTopic => '주제 추가';

  @override
  String get mermaidCatalogActionAddPeriod => '기간 추가';

  @override
  String get mermaidCatalogActionAddBlock => '블록 추가';

  @override
  String get mermaidCatalogActionAddColumns => '열 추가';

  @override
  String get mermaidCatalogActionAddConnection => '연결 추가';

  @override
  String get mermaidCatalogActionAddChildBlock => '하위 블록 추가';

  @override
  String get mermaidCatalogActionAddRequirement => '요구사항 추가';

  @override
  String get mermaidCatalogActionAddElement => '요소 추가';

  @override
  String get mermaidCatalogActionAddVerification => '검증 방법 추가';

  @override
  String get mermaidCatalogGanttDependencyBaseTask => '선행 작업';

  @override
  String get mermaidCatalogGanttDependentTaskName => '후속 작업';

  @override
  String get startupMigrationTitle => '데이터 형식 업그레이드 완료';

  @override
  String get startupMigrationBody =>
      '데이터를 새 형식으로 마이그레이션했습니다. 업데이트된 버전을 사용하려면 앱을 다시 시작하세요.';

  @override
  String get startupMigrationExit => '앱 종료';

  @override
  String get startupMigrationRestart => '지금 다시 시작';

  @override
  String get startupRecoveryTitle => '앱 시작 오류';

  @override
  String get startupRecoveryFallbackMessage =>
      '시작 중 데이터 형식 문제가 발생해 자동으로 복구했습니다. 다시 시도하세요.';

  @override
  String get startupRecoveryRetry => '다시 시도';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return 'ASR $category $stage 단계$chunk: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return ', 청크 $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return '요청 실패: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return '청크 음성 받아쓰기 실패($count개 청크 중 성공 없음)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return '청크 음성 받아쓰기 미완료($count개 중 $succeeded개 성공)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return '성공: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return '실패: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return '결과 불확실: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return '청크 $index($start~$end초) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return '청크 상태 저장 실패: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      '요청 결과를 확인할 수 없습니다. 중복 제출을 방지하기 위해 다시 시도를 중지했습니다. 새 작업을 만들려면 오디오를 다시 선택하세요.';

  @override
  String asrRetryAudioLost(Object audioName) {
    return '원본 오디오 파일이 없어졌습니다. 다시 시도하려면 오디오를 다시 선택하세요: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return '원본 오디오 파일이 손상되었습니다. 다시 시도하려면 오디오를 다시 선택하세요: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return ', 청크 $index';
  }

  @override
  String get asrChunkDetailsSeparator => '; ';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'ASR 인식 실패: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => '인증';

  @override
  String get asrFailureCategoryRateLimit => '요청 한도';

  @override
  String get asrFailureCategorySizeLimit => '크기 제한';

  @override
  String get asrFailureCategoryNetwork => '네트워크';

  @override
  String get asrFailureCategoryResponseParsing => '응답 구문 분석';

  @override
  String get asrFailureCategoryLocalProcessing => '로컬 처리';

  @override
  String get asrFailureCategoryProvider => '제공업체';

  @override
  String get asrFailureCategoryUnknown => '알 수 없음';

  @override
  String get asrFailureStagePreprocessing => '전처리';

  @override
  String get asrFailureStageEncoding => '인코딩';

  @override
  String get asrFailureStageValidation => '검증';

  @override
  String get asrFailureStageRequest => '요청';

  @override
  String get asrFailureStageUploading => '업로드';

  @override
  String get asrFailureStageWaiting => '대기';

  @override
  String get asrFailureStageReceiving => '수신';

  @override
  String get asrFailureStageResponse => '응답';

  @override
  String get asrFailureStageParsing => '구문 분석';

  @override
  String get asrFailureStageStorage => '저장';

  @override
  String get chatMissingProvider => '먼저 채팅 제공업체를 구성하세요';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Anthropic API 오류: $detail';
  }

  @override
  String get anthropicStreamUnknownError => '알 수 없는 오류';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'API 요청 실패(HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing => 'API 키가 설정되지 않아 파일을 업로드할 수 없습니다';

  @override
  String get fileUploadApiUrlMissing => 'API URL이 설정되지 않아 파일을 업로드할 수 없습니다';

  @override
  String get fileUploadContentEmpty => '파일 내용이 비어 있습니다';

  @override
  String get fileUploadFilenameEmpty => '파일 이름이 비어 있습니다';

  @override
  String get fileUploadMimeTypeEmpty => 'MIME 유형이 비어 있습니다';

  @override
  String get fileUploadPurposeEmpty => '업로드 목적이 비어 있습니다';

  @override
  String get fileUploadCanceled => '파일 업로드가 취소되었습니다';

  @override
  String get fileUploadCreateMissingId => '업로드를 만들지 못했습니다: 응답에 업로드 ID가 없습니다';

  @override
  String get fileUploadPartMissingId => '파일 일부를 업로드하지 못했습니다: 응답에 일부 ID가 없습니다';

  @override
  String get fileUploadCompleteMissingFile =>
      '업로드를 완료하지 못했습니다: 응답에 파일 객체가 없습니다';

  @override
  String get fileUploadMissingFileId => '파일을 업로드하지 못했습니다: 응답에 파일 ID가 없습니다';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return '파일 업로드 요청 실패(HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return '파일 업로드 요청 실패: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'API 키가 설정되지 않았습니다';

  @override
  String chatStreamError(Object detail) {
    return 'API 스트림 오류: $detail';
  }

  @override
  String get chatChoicesMissing => 'API 응답에 선택 항목이 없습니다';

  @override
  String get chatContentBlocksMissing => 'API 응답에 콘텐츠 블록이 없습니다';

  @override
  String get chatResponseContentEmpty => 'API 응답 내용이 비어 있습니다';

  @override
  String chatRequestFailed(Object detail) {
    return '요청 실패: $detail';
  }

  @override
  String get startupTagline => '학습 도우미';

  @override
  String get startupProgressDataSafety => '데이터 안전 확인 중...';

  @override
  String get startupProgressFormatVersion => '데이터 형식 버전 확인 중...';

  @override
  String get startupProgressDataFormat => '데이터 형식 검증 중...';

  @override
  String get startupProgressDataIntegrity => '데이터 무결성 확인 중...';

  @override
  String get startupProgressResults => '검사 결과 처리 중...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return '시작 완료(참고: $warning)';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      '데이터 검사를 마쳤습니다. 앱을 시작할 준비 중입니다.';

  @override
  String get startupProgressReady => '앱을 시작할 준비 중입니다.';

  @override
  String startupWarningErrorCount(Object count) {
    return '데이터 문제 $count개 발견:';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return '경고 $count개:';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      '제공업체 항목 형식이 올바르지 않습니다. JSON 배열이어야 합니다.';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return '제공업체 항목 $index이(가) null이거나 유형이 올바르지 않습니다.';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return '제공업체 항목 $index에 ID가 없거나 ID가 비어 있습니다.';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return '제공업체 항목 $index에 유형이 없거나 유형이 비어 있습니다.';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return '제공업체 항목 $index에 이름이 없거나 이름이 비어 있습니다.';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return '제공업체 항목 $index의 $field 필드가 올바른 목록이 아닙니다.';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return '제공업체 항목 $index의 $field에 구문 분석 실패를 일으킬 수 있는 잘못된 항목이 있습니다.';
  }

  @override
  String get startupIssueConversationsInvalid =>
      '대화 형식이 올바르지 않습니다. JSON 배열이어야 합니다.';

  @override
  String startupIssueConversationInvalid(Object index) {
    return '대화 $index이(가) null이거나 유형이 올바르지 않습니다.';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return '대화 $index에 ID가 없습니다.';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return '대화 $index에 메시지 필드가 없습니다.';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return '대화 $index의 메시지 필드가 올바른 목록이 아닙니다.';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return '제공업체 항목 $index에서 알 수 없는 제공업체 유형 ‘$type’을(를) 사용합니다. 올바르게 작동하지 않을 수 있습니다.';
  }

  @override
  String get startupErrorTitle => '앱 시작 실패';

  @override
  String startupErrorDetails(Object error) {
    return '오류: $error';
  }

  @override
  String get renderErrorTitle => '인터페이스 렌더링 오류';

  @override
  String get renderErrorDebugTitle => '인터페이스 렌더링 오류(디버그 모드)';

  @override
  String get renderErrorRestartMessage => '앱을 다시 시작해 보세요.';

  @override
  String get batchDlgFileName => '파일 이름';

  @override
  String get batchDlgFolderName => '폴더 이름';

  @override
  String get batchDlgFileNameConflict => '이 폴더에 같은 이름의 파일이 이미 있습니다';

  @override
  String get batchDlgFolderNameConflict => '대상 위치에 같은 이름의 폴더가 이미 있습니다';

  @override
  String get batchDlgFolderNameSwapConflict => '같은 일괄 작업에서 폴더 이름을 서로 바꿀 수 없습니다';

  @override
  String get batchDlgControlCharacterError => '이름에 제어 문자를 사용할 수 없습니다';

  @override
  String get batchDlgNameWhitespaceError =>
      '이름 앞뒤에 공백을 넣을 수 없습니다. 공백 정리 규칙을 사용하세요';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind은(는) 비워 둘 수 없습니다';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind 끝에 공백을 넣을 수 없습니다';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind은(는) $count자를 초과할 수 없습니다';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind에 Windows에서 허용하지 않는 문자를 사용할 수 없습니다';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind 끝에 마침표를 넣을 수 없습니다';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind에 Windows 예약 이름을 사용할 수 없습니다';
  }

  @override
  String get batchDlgIntermediateNameTooLong => '중간 이름이 너무 깁니다. 규칙을 조정하세요';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return '이 항목에는 $date 날짜가 없습니다. 템플릿을 조정하세요';
  }

  @override
  String get batchDlgCreatedDate => '생성';

  @override
  String get batchDlgModifiedDate => '수정';

  @override
  String get connectivityTestHttpSuccess => 'HTTP 도구 요청 성공';

  @override
  String get connectivityTestHttpFailure => 'HTTP 도구 요청 실패';

  @override
  String get connectivityTestInvalidMcpConfig => 'MCP 구성이 올바르지 않습니다';

  @override
  String get connectivityTestMissingTransport => '유효한 전송 유형 구성이 필요합니다.';

  @override
  String get connectivityTestStdioUnsupported => '이 플랫폼에서는 stdio를 지원하지 않습니다';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP는 로컬 프로세스를 시작해야 합니다. Stroom 데스크톱 앱에서 테스트하세요.';

  @override
  String get connectivityTestInvalidContent => '테스트 내용이 올바르지 않습니다';

  @override
  String get connectivityTestMethodMustBeString => 'method는 문자열이어야 합니다.';

  @override
  String get connectivityTestUnsupportedMethod => '지원하지 않는 테스트 메서드';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      '원격 업무 데이터에 기록하지 않도록 MCP 연결 테스트에서는 읽기 전용 tools/list 메서드만 허용합니다.';

  @override
  String get connectivityTestParamsMustBeObject => 'params는 JSON 객체여야 합니다.';

  @override
  String get connectivityTestMcpConnectionFailed => 'MCP 서비스에 연결할 수 없습니다';

  @override
  String get connectivityTestCheckConnectionSettings =>
      '주소, 인증, 네트워크를 확인하거나 앱 로그에서 연결 세부정보를 확인하세요.';

  @override
  String get connectivityTestRemainingToolsOmitted => '; 나머지 도구는 생략됨';

  @override
  String get connectivityTestMcpSuccess => 'MCP 연결 테스트 성공';

  @override
  String connectivityTestToolNames(Object names) {
    return ': $names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return '연결 및 tools/list 요청 성공. 도구 $count개를 찾았습니다$names$suffix.';
  }

  @override
  String get connectivityTestTodoMutationBlocked =>
      '테스트 매개변수가 todo 데이터를 수정하려고 합니다';

  @override
  String get connectivityTestTodoReadOnly =>
      '현재 세션의 todo 목록을 보호하려면 연결 테스트에서 todos를 생략하거나 null로 설정하세요.';

  @override
  String get connectivityTestUnknownBuiltin => '알 수 없는 기본 제공 도구';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return '도구 ‘$toolName’의 테스트 실행기를 찾을 수 없습니다.';
  }

  @override
  String get connectivityTestBuiltinSuccess => '기본 제공 도구 테스트 성공';

  @override
  String get connectivityTestBuiltinFailure => '기본 제공 도구 테스트 실패';

  @override
  String get connectivityTestTopLevelObjectRequired =>
      '테스트 내용은 최상위 JSON 객체여야 합니다.';

  @override
  String get connectivityTestRequestTimeout =>
      '요청 시간이 초과되었습니다. 서비스 응답과 네트워크를 확인하세요.';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'MCP 요청 시간 초과: $method';
  }

  @override
  String get connectivityTestResultTruncated => '… (결과 잘림)';

  @override
  String get toolResultWebSearchEmptyQuery => '오류: 검색어를 입력해야 합니다.';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return '오류: 지원하지 않는 검색 엔진 ‘$source’입니다. 지원 값: google, bing, baidu.';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return '기본 엔진 $preferred $reason; $fallback(으)로 전환했습니다.';
  }

  @override
  String get toolResultWebSearchNotFound => '관련 검색 결과를 찾을 수 없습니다.';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return '관련 검색 결과를 찾을 수 없습니다($sources에서 결과가 없다고 명시적으로 응답함).';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return '검색 미완료: $sources에서 결과가 없다고 명시적으로 응답했습니다. 다른 엔진은 사용할 수 없거나 구문 분석할 수 없는 페이지를 반환했습니다: $failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return '오류: 모든 검색 엔진을 사용할 수 없습니다. $failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return '$source의 검색 결과:';
  }

  @override
  String get toolResultWebSearchLinkLabel => '링크';

  @override
  String get toolResultWebSearchSummaryLabel => '요약';

  @override
  String get toolResultWebSearchEmptyResults => '관련 검색 결과를 찾을 수 없습니다.';

  @override
  String get toolResultTodoInvalid =>
      '오류: todos 매개변수는 배열이어야 합니다(todo 목록을 읽으려면 생략하거나 null을 전달하세요).';

  @override
  String get toolResultTodoEmpty => '아직 todo 항목이 없습니다.';

  @override
  String toolResultTodoCount(Object count) {
    return '활성 todo 항목: $count';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return '오류: MCP 서버 ‘$server’에 다시 연결할 수 없습니다.';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return '오류: MCP 서버 ‘$server’를 현재 사용할 수 없습니다.';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return '오류: MCP 서버 ‘$server’에 연결하지 못했거나 도구가 없습니다. 서버 구성을 확인하세요.';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return '실제 도구 ‘$tool’은(는) 이 서버에서 호출 이름 ‘$alias’로 공개되어 있습니다.';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return '여러 MCP 서버에서 도구 ‘$tool’을(를) 제공합니다. 일치하는 호출 이름을 사용하세요: $routes.';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return '오류: 실제 도구 ‘$tool’의 이름이 충돌합니다. 위에 나열된 호출 이름 중 하나를 사용하세요.';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return '오류: MCP 서버 ‘$server’에 ‘$tool’ 도구가 없습니다.';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return '이 서버에서 사용할 수 있는 도구: $tools. 대신 이 이름을 사용하세요.';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return '오류: MCP 도구 ‘$tool’의 별칭이 현재 충돌합니다. 일치하는 호출 이름을 사용하세요: $routes.';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return '오류: 도구 ‘$tool’이(가) 비활성화되어 있습니다.';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return '오류: 알 수 없는 도구 ‘$tool’';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => '결과를 반환하지 않음';

  @override
  String get toolResultWebSearchFallbackUnavailable => '일시적으로 사용할 수 없음';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '(MCP 서버 $server)';
  }

  @override
  String get toolResultWebSearchUnparsedResults => '구문 분석할 수 없는 페이지를 반환함';

  @override
  String get toolResultSearchTitleLabel => '제목';

  @override
  String get toolResultSearchContentLabel => '내용';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return '오류: $provider API 키가 설정되지 않았습니다. 설정에서 구성하세요.';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return '오류: $provider 인스턴스 URL이 설정되지 않았습니다. 설정에서 구성하세요.';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return '오류: $provider 요청 실패(HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return '오류: $provider 요청 실패: $detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return '오류: 알 수 없는 HTTP 도구 ‘$provider’';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return '오류: MCP 서버 ‘$server’에 연결되어 있지 않습니다.';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return '오류: MCP 도구 ‘$tool’에서 응답이 없습니다.';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return '오류: $detail';
  }

  @override
  String get httpToolBraveDescription =>
      'Brave Search API로 웹을 검색합니다. API 키가 필요합니다.';

  @override
  String get httpToolBochaDescription =>
      'Bocha AI Search API로 웹을 검색합니다. API 키가 필요합니다.';

  @override
  String get httpToolQueritDescription =>
      'Querit Search로 웹을 검색합니다. API 키가 필요합니다.';

  @override
  String get httpToolSearxngDescription =>
      '여러 검색 소스를 통합하는 개인정보 보호 중심의 자체 호스팅 메타 검색 엔진입니다. 인스턴스 URL이 필요합니다.';

  @override
  String get httpToolSearchQueryDescription => '검색어입니다.';

  @override
  String get httpToolSearchCountDescription => '반환할 결과 수입니다.';

  @override
  String get httpToolSearchCountMax20Description => '반환할 결과 수(최대 20개)입니다.';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return '덱 $decks개, 노트 $notes개, 카드 $cards개 가져옴';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '선택한 .apkg 파일을 찾을 수 없습니다: $path';
  }

  @override
  String get backupRestoreApkgInvalidArchive =>
      '선택한 .apkg 파일이 손상되었거나 올바른 아카이브가 아닙니다.';

  @override
  String get backupRestoreApkgCollectionMissing =>
      '.apkg 파일에 collection.anki2가 없습니다.';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return '덱을 가져오거나 내보내려면 Anki 플래시카드를 먼저 여세요: $path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt => 'Anki 컬렉션 데이터베이스가 손상되었습니다.';

  @override
  String backupRestoreApkgLocalFileFailure(String path) {
    return '로컬 Anki 파일에 액세스할 수 없습니다: $path';
  }

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return '이 경로의 파일에 액세스하는 동안 .apkg 작업 실패: $path';
  }

  @override
  String get backupRestoreApkgOperationFailed =>
      '파일 또는 데이터베이스를 읽을 수 없어 .apkg 작업에 실패했습니다.';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return '이 데이터베이스에서 Anki 덱을 패키징할 수 없습니다: $path';
  }

  @override
  String get ankiSyncStatusProtocolFailed =>
      '동기화 서버 응답이 올바르지 않거나 불완전합니다. 서버가 Anki 동기화 v10을 지원하는지 확인하세요.';

  @override
  String get ankiSyncStatusLoginRequired => '계속하려면 Anki 동기화에 로그인하세요.';

  @override
  String get ankiSyncStatusInvalidServerUrl =>
      '유효한 HTTP 또는 HTTPS 동기화 서버 주소를 입력하세요.';

  @override
  String get ankiSyncStatusHttpsRequired =>
      '원격 자체 호스팅 동기화 서버에는 HTTPS를 사용해야 합니다.';

  @override
  String get ankiSyncStatusConnectionTimeout =>
      '동기화 요청 시간이 초과되었습니다. 서버 주소와 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get ankiSyncStatusTlsFailure =>
      '서버 인증서를 확인할 수 없습니다. 인증서를 확인하거나 사용자 지정 CA를 구성하세요.';

  @override
  String get ankiSyncStatusConnectionFailure =>
      '동기화 서버에 연결할 수 없습니다. 주소와 네트워크를 확인하세요.';

  @override
  String get ankiSyncStatusRequestFailure =>
      '동기화 요청에 실패했습니다. 서버와 네트워크를 확인한 후 다시 시도하세요.';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return '동기화 서버가 HTTP $statusCode를 반환했습니다.';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return '동기화 응답이 ${limitMb}MB 제한을 초과했습니다.';
  }

  @override
  String get ankiSyncStatusLocalFileFailure =>
      '로컬 동기화 파일을 읽거나 정리할 수 없습니다. 디스크 액세스를 확인하고 다시 시도하세요.';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      '컬렉션을 열거나 업데이트하지 못했거나 SQLite/스키마 검증에 실패했습니다. 유효한 컬렉션을 복원하거나 다시 다운로드하세요.';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return '동기화 서버가 요청을 거부했습니다(HTTP $statusCode). 로그인 정보와 서버 권한을 확인하세요.';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return '동기화 엔드포인트를 찾을 수 없습니다(HTTP $statusCode). 서버 주소를 확인하세요.';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      '미디어 동기화 서버 응답이 올바르지 않습니다. Anki 미디어 동기화를 지원하는지 확인한 후 다시 시도하세요.';

  @override
  String get ankiSyncStatusMediaIndexCorrupt =>
      '로컬 미디어 동기화 인덱스가 손상되었습니다. 미디어 동기화 데이터를 초기화하고 다시 시도하세요.';

  @override
  String get ankiSyncStatusMediaIndexFailure =>
      '로컬 미디어 동기화 인덱스를 읽거나 업데이트할 수 없습니다.';

  @override
  String get ankiSyncStatusMediaChecksumMismatch =>
      '다운로드한 미디어 파일의 체크섬 검증에 실패했습니다. 미디어 동기화를 다시 시도하세요.';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return '미디어 파일 ‘$filename’의 로컬 변경사항과 서버 변경사항이 충돌합니다. 백업한 뒤 파일 이름 충돌을 해결하고 다시 시도하세요.';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return '미디어 파일 이름 ‘$filename’을(를) 동기화할 수 없습니다. Anki에서 사용할 수 있는 파일 이름으로 바꾼 뒤 다시 시도하세요.';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return '미디어 파일이 비어 있거나 ${limitMb}MB 제한을 초과했습니다.';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return '미디어 아카이브에 항목이 $count개 있습니다. 매니페스트를 포함한 최대 항목 수는 $limit개입니다.';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed =>
      '미디어 동기화 검증에 실패했습니다. 동기화를 다시 시도하세요.';

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      '웹에서 동기화하려면 AnkiWeb에 로그인하세요. 클라우드 아이콘으로 Anki 설정을 열고 로그인할 수 있습니다.';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      '웹에서 덱을 둘러보거나 관리하려면 클라우드 아이콘을 사용해 AnkiWeb에 로그인하세요.';

  @override
  String get ankiStatsUnsupportedPlatform => '이 플랫폼에서는 Anki 통계를 사용할 수 없습니다.';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      '기기 시계와 동기화 서버의 시간이 5분 넘게 차이 납니다. 시계를 맞춘 뒤 다시 시도하세요.';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      '동기화 무결성 검사에 실패해 로컬 변경사항을 되돌렸습니다. 서버 컬렉션 전체를 다운로드한 뒤 다시 시도하세요.';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      '이 컬렉션은 증분 동기화를 지원하지 않습니다. 계속하려면 전체 업로드 또는 다운로드를 선택하세요.';

  @override
  String get ankiSyncStatusIncrementalSyncFailed =>
      '증분 동기화를 완료하지 못했습니다. 서버와 연결을 확인한 후 다시 시도하세요.';

  @override
  String get emojiCategorySmileys => '스마일리';

  @override
  String get emojiCategoryPeople => '사람';

  @override
  String get emojiCategoryAnimals => '동물';

  @override
  String get emojiCategoryFood => '음식';

  @override
  String get emojiCategoryActivities => '활동';

  @override
  String get emojiCategoryTravel => '여행';

  @override
  String get emojiCategoryObjects => '사물';

  @override
  String get emojiCategorySymbols => '기호';

  @override
  String get emojiCategoryFlags => '깃발';

  @override
  String get languageNameSpanish => '스페인어';

  @override
  String get languageNameJapanese => '일본어';

  @override
  String get languageNameFrench => '프랑스어';

  @override
  String get languageNameGerman => '독일어';

  @override
  String get languageNameArabic => '아랍어';

  @override
  String fileManagerDeleteEmptyFolderWithSubfoldersConfirm(
    num count,
    Object name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개도 함께 삭제됩니다',
      one: '1개도 함께 삭제됩니다',
    );
    return '빈 폴더 ‘$name’을(를) 삭제하시겠습니까? 중첩 폴더 $_temp0.';
  }

  @override
  String get providerMaxUploadSizePositive => '최대 업로드 크기는 양수여야 합니다.';
}
