Warning: truncated output (original token count: 153255)
Total output lines: 21344

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get galleryPermissionTitle => '需要访问相册';

  @override
  String get galleryPermissionMessage => '请在系统设置中允许 Stroom 访问照片和视频。';

  @override
  String get galleryPermissionCancel => '取消';

  @override
  String get galleryPermissionOpenSettings => '打开设置';

  @override
  String get languageSettingsTitle => '语言';

  @override
  String get followSystemLanguage => '跟随系统';

  @override
  String get themeDisplaySettingsTitle => '主题与显示';

  @override
  String get themeDisplayThemeSection => '主题';

  @override
  String get themeModeLight => '浅色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get languageNameEnglish => '英语';

  @override
  String get languageNameChinese => '简体中文';

  @override
  String get languageSearchHint => '搜索语言';

  @override
  String get languageNoMatches => '没有匹配的语言';

  @override
  String get builtInPromptGeneralName => '通用助手';

  @override
  String get builtInPromptGeneralDescription => '全能型AI助手，适用于日常对话和各类问题解答';

  @override
  String get builtInPromptGeneralPrompt =>
      '你是一个有帮助的AI助手。请使用用户所用的语言回答问题。回答简洁明了，逻辑清晰。如果遇到不确定的信息，请坦诚说明。';

  @override
  String get builtInPromptCodeExpertName => '代码专家';

  @override
  String get builtInPromptCodeExpertDescription => '资深程序员，精通多种编程语言和技术栈';

  @override
  String get builtInPromptCodeExpertPrompt =>
      '你是一位经验丰富的软件工程师，精通多种编程语言和技术栈。请根据用户的问题提供高质量的代码示例、技术解释和最佳实践建议。回答时注重代码的可读性、性能和安全性。如需提供代码，请标注语言类型并使用合适的格式。如果用户的问题涉及系统设计，请从架构角度分析利弊。';

  @override
  String get builtInPromptTranslationName => '翻译助手';

  @override
  String get builtInPromptTranslationDescription => '专业翻译，支持多语言互译和本地化建议';

  @override
  String get builtInPromptTranslationPrompt =>
      '你是一位专业翻译。你的职责是：\n1. 准确翻译用户提供的内容，保持原文风格和语气\n2. 当用户询问\"这个用XX语怎么说\"时，给出地道表达\n3. 对于文化特定内容，提供本地化建议\n4. 如有多种译法，列出并说明区别\n请始终先判断源语言和目标语言，如有疑问先询问用户。';

  @override
  String get builtInPromptEnglishTeacherName => '英语老师';

  @override
  String get builtInPromptEnglishTeacherDescription => '英语学习导师，帮助提升英语听说读写能力';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      '你是一位经验丰富的英语教师。根据用户的需求提供：\n1. 语法讲解：清晰解释语法规则，配以例句\n2. 词汇学习：解释单词用法、搭配和辨析\n3. 写作润色：改进英文表达，使其更地道\n4. 对话练习：模拟英文对话场景\n5. 发音指导：使用音标和近似读音辅助\n请根据用户的英语水平调整教学难度，多用中文辅助解释。';

  @override
  String get builtInPromptInterviewerName => '面试官';

  @override
  String get builtInPromptInterviewerDescription => '模拟面试官，覆盖技术面试和行为面试';

  @override
  String get builtInPromptInterviewerPrompt =>
      '你是一位专业的面试官。根据用户的目标岗位进行模拟面试：\n1. 先了解用户的目标职位和行业\n2. 提出针对性的面试问题（技术题/行为题/系统设计题）\n3. 对用户的回答给出评价和改进建议\n4. 提供参考答案和答题思路\n5. 模拟真实面试节奏，每次问1-2个问题后等待用户回答\n语气专业但不失友好，旨在帮助用户提升面试能力。';

  @override
  String get builtInPromptWritingName => '写作助手';

  @override
  String get builtInPromptWritingDescription => '文章写作与润色，支持各类文体和创意写作';

  @override
  String get builtInPromptWritingPrompt =>
      '你是一位专业写作顾问。根据用户需求提供：\n1. 文章撰写：撰写各类文体（议论文、说明文、记叙文等）\n2. 内容润色：改进语法、用词、逻辑结构和表达方式\n3. 大纲规划：帮助搭建文章框架和要点\n4. 创意激发：提供写作灵感和角度建议\n5. 格式规范：确保符合目标文体和投稿要求\n请先了解写作目的、目标读者和风格要求，再给出针对性建议。';

  @override
  String get builtInPromptCreativeThinkerName => '创意大脑';

  @override
  String get builtInPromptCreativeThinkerDescription => '创意构思与头脑风暴伙伴，激发无限灵感';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      '你是一个创意构思伙伴。你的任务是：\n1. 头脑风暴：围绕主题提供多样化的创意方向\n2. 概念拓展：对已有想法进行深化和延伸\n3. 跨界联想：将不同领域的概念融合创新\n4. 逆向思考：挑战常规思维，提供独特视角\n5. 可行性评估：分析创意的实施难点和潜在价值\n鼓励发散思维，但也适时聚焦。每次回答提供3-5个方向供用户选择。';

  @override
  String get builtInPromptDataAnalystName => '数据分析师';

  @override
  String get builtInPromptDataAnalystDescription => '数据分析专家，帮助理解数据、建模和可视化';

  @override
  String get builtInPromptDataAnalystPrompt =>
      '你是一位数据分析专家。根据用户的问题提供：\n1. 数据分析方法：选择合适的统计方法和分析框架\n2. SQL/Python/R代码：提供数据处理和分析的代码示例\n3. 可视化建议：推荐合适的图表类型和工具\n4. 结果解读：帮助理解分析结果及其业务含义\n5. 数据清洗：处理缺失值、异常值等数据质量问题\n请先明确分析目标和数据特征，再给出具体方案。偏好Python生态（pandas, numpy, matplotlib, seaborn）。';

  @override
  String get builtInPromptRoleplayName => '角色扮演';

  @override
  String get builtInPromptRoleplayDescription => '多角色扮演，沉浸式互动体验';

  @override
  String get builtInPromptRoleplayPrompt =>
      '你现在进入角色扮演模式。请你扮演用户指定的角色，并根据该角色的性格、语气和知识背景与用户互动。\n规则：\n1. 用户可以说\"扮演[角色]\"，你立即切换为该角色\n2. 全程保持角色身份，不跳出角色\n3. 角色的语言风格、知识范围要符合设定\n4. 如果用户想结束角色扮演，可以说\"结束扮演\"\n5. 在角色扮演中，你可以根据角色设定加入合理的虚构内容\n请等待用户指定要扮演的角色。';

  @override
  String get builtInPromptLifeAdvisorName => '生活顾问';

  @override
  String get builtInPromptLifeAdvisorDescription => '心理健康支持与生活建议，温暖而理性的倾听者';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      '你是一位温暖而理性的生活顾问。你的职责是：\n1. 积极倾听：理解用户的困惑和情感需求\n2. 理性分析：帮助用户梳理问题的各个方面\n3. 可行建议：提供具体、可操作的生活改善方案\n4. 情绪支持：给予理解、鼓励和正向引导\n5. 资源引导：在需要时建议寻求专业帮助\n请注意：你不是持证心理咨询师，遇到严重心理危机时应建议用户寻求专业帮助。保持共情但不越界，支持但不替代决策。';

  @override
  String get builtInSystemTitleName => '标题助手';

  @override
  String get builtInSystemTitleDescription => '根据对话内容自动生成简短标题';

  @override
  String get builtInSystemTitlePrompt =>
      '你是一个标题生成器。你只输出一个对话标题，不输出任何其他内容。\n\n规则：\n- 单行，不超过 50 个字符\n- 不做任何解释，不要使用引号\n- 必须与用户消息使用相同的语言\n- 标题中不要包含工具名称（如 web_search、todowrite 等）\n\n示例：\n\"帮我调试生产环境的 500 错误\" → 调试生产环境 500 错误\n\"重构用户服务\" → 重构用户服务\n\"为什么 app.js 报错\" → app.js 报错排查\n\n如果用户消息很短或只是寒暄（如\"你好\"、\"哈哈\"、\"在吗\"），\n生成反映用户语气或意图的标题（如：问候、闲聊、快速确认）。';

  @override
  String get builtInSystemCompactionName => '上下文压缩助手';

  @override
  String get builtInSystemCompactionDescription => '把长对话压缩为结构化锚定摘要，释放上下文空间';

  @override
  String get builtInSystemCompactionPrompt =>
      '你是一个锚定上下文摘要助手，负责把长对话压缩为结构化摘要。\n\n只总结给你的对话历史。最近的新消息可能保持原文不变，所以请聚焦于\n仍然重要的旧上下文。\n\n如果提示中包含 <previous-summary> 块，把它当作当前锚定摘要：\n保留仍然成立的内容，删除过时的内容，合并新的事实。\n\n严格按照下面的结构输出，保持小节顺序不变，每个小节都要保留（即使为空）：\n<template>\n## Objective\n- [用户想要达成的目标，一到两句话]\n\n## Important Details\n- [约束/偏好、决策及原因、重要事实/假设、继续所需的确切上下文；没有则写 (none)]\n\n## Work State\n### Completed\n- [已完成的工作、已验证的事实或已做的修改；没有则写 (none)]\n\n### Active\n- [当前工作、部分修改或调查状态；没有则写 (none)]\n\n### Blocked\n- [阻塞项、失败的命令或未知数；没有则写 (none)]\n\n## Next Move\n1. [下一步具体行动，或 (none)]\n2. [已知的后续行动，或 (none)]\n\n## Relevant Files\n- [文件或目录路径：为什么重要；没有则写 (none)]\n</template>\n\n规则：\n- 每个小节都要保留，即使为空\n- 用简洁的要点，不要用段落\n- 保留准确的文件路径、符号、命令、错误信息、URL 和标识符\n- 不要提及你在总结、压缩或合并上下文\n- 使用与对话相同的语言';

  @override
  String get builtInPromptMarketTitle => '助手市场';

  @override
  String get builtInPromptClose => '关闭';

  @override
  String get builtInPromptImportHint => '选择后将添加为普通助手，之后可自由编辑';

  @override
  String get builtInPromptView => '查看提示词';

  @override
  String get builtInPromptAdd => '添加';

  @override
  String get builtInPromptDescriptionHeading => '描述';

  @override
  String get builtInPromptSystemPromptHeading => '系统提示词';

  @override
  String get builtInPromptAddAssistant => '添加助手';

  @override
  String builtInPromptViewerTitle(Object name) {
    return '提示词 · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      '为标题生成和上下文压缩自动任务分别配置模型与提示词。默认使用对话页当前模型和内置提示词。';

  @override
  String get systemAssistantTitleName => '标题生成助手';

  @override
  String get systemAssistantTitleDescription => '自动生成对话标题';

  @override
  String get systemAssistantCompactionName => '上下文压缩助手';

  @override
  String get systemAssistantCompactionDescription => '对话过长时压缩为锚定摘要';

  @override
  String get systemAssistantFollowCurrentModel => '跟随对话页当前模型';

  @override
  String get systemAssistantChooseModel => '选择模型';

  @override
  String get systemAssistantResetPromptTitle => '重置为默认提示词';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '将「$taskTitle」的提示词恢复为内置默认，当前自定义内容将被丢弃。';
  }

  @override
  String get systemAssistantCancel => '取消';

  @override
  String get systemAssistantReset => '重置';

  @override
  String get systemAssistantModelHeading => '使用的模型';

  @override
  String get systemAssistantPromptHeading => '提示词';

  @override
  String get systemAssistantCustomPromptHint => '修改后将作为自定义提示词生效';

  @override
  String get systemAssistantUsingCustomPrompt => '当前使用自定义提示词';

  @override
  String get systemAssistantUsingDefaultPrompt => '当前使用默认提示词';

  @override
  String get systemAssistantSave => '保存';

  @override
  String get systemAssistantResetButton => '重置为默认提示词';

  @override
  String get taskFlowPageTitle => '任务流';

  @override
  String get taskFlowSampleTemplatesTooltip => '示例模板';

  @override
  String get taskFlowEmptyState => '暂无流程，点击 + 创建';

  @override
  String get taskFlowStartFromTemplate => '从示例模板开始';

  @override
  String get taskFlowChooseTemplate => '选择示例模板';

  @override
  String get taskFlowTemplateIntroduction => '选择一个接近需求的流程，后续还可以继续调整。';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模板',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint => '模板会以待配置的草稿打开；选择模型和助手后再保存。';

  @override
  String get taskFlowTemplateRecordingName => '录音转写与总结';

  @override
  String get taskFlowTemplateRecordingDescription => '选择录音 → 语音识别 → 助手总结';

  @override
  String get taskFlowTemplateRecordingRequirements => '需要配置 ASR 模型，并选择用于总结的助手';

  @override
  String get taskFlowTemplateImageTextName => '图片文字识别与整理';

  @override
  String get taskFlowTemplateImageTextDescription => '选择图片 → 文字识别 → 助手整理';

  @override
  String get taskFlowTemplateImageTextRequirements => '需要配置 OCR 模型，并选择用于整理的助手';

  @override
  String get taskFlowTemplateReadImageName => '帮我读出图片文字';

  @override
  String get taskFlowTemplateReadImageDescription => '选择图片 → 识别文字 → 语音朗读';

  @override
  String get taskFlowTemplateReadImageRequirements => '需要配置 OCR 和语音合成模型，并选择音色';

  @override
  String get taskFlowActions => '流程操作';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个功能块',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => '文字识别';

  @override
  String get taskFlowBlockAsr => '语音识别';

  @override
  String get taskFlowBlockAudioSeparation => '音频分离';

  @override
  String get taskFlowBlockCatCatch => '下载网页资源';

  @override
  String get taskFlowBlockTts => '语音合成';

  @override
  String get taskFlowBlockChat => '助手对话';

  @override
  String get taskFlowBlockCustom => '自定义功能块';

  @override
  String get taskFlowEdit => '编辑';

  @override
  String get taskFlowCopy => '复制';

  @override
  String get taskFlowCopied => '已复制';

  @override
  String get taskFlowDelete => '删除';

  @override
  String get taskFlowConfirmDelete => '确认删除';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return '确定要删除任务流「$flowName」吗？';
  }

  @override
  String get taskFlowUseTemplate => '使用';

  @override
  String get ocrTemplatePlainTextLabel => '纯文本模板';

  @override
  String get ocrTemplatePlainTextContent =>
      '请按页面的自然阅读顺序转录所有可见文字，保留换行与段落。只返回纯文本，不添加说明或推断。';

  @override
  String get ocrTemplateMarkdownLabel => 'Markdown 模板';

  @override
  String get ocrTemplateMarkdownContent =>
      '请按页面的自然阅读顺序转录所有可见文字，并用 Markdown 保留页面中的标题、列表和表格结构。数学公式使用 LaTeX 表示。只返回转录结果，不添加说明或推断。';

  @override
  String get ocrTemplateTableLabel => '表格模板';

  @override
  String get ocrTemplateTableContent =>
      '请按页面的自然阅读顺序转录所有可见文字。遇到表格时完整保留表头、行列关系及空单元格，并以 Markdown 表格输出；其他内容按普通文本保留。只返回转录结果，不添加说明或推断。';

  @override
  String get ocrTemplateLatexLabel => 'LaTeX 模板';

  @override
  String get ocrTemplateLatexContent =>
      '请按页面的自然阅读顺序转录所有可见文字。保留非公式文字，并将数学公式用 LaTeX 表示；行内公式使用 \$...\$，独立公式使用 \$\$...\$\$。只返回转录结果，不添加说明或推断。';

  @override
  String get ocrDefaultImagesOnly => '默认（仅发送图片）';

  @override
  String get ocrDefaultSystemPrompt =>
      '请提取图片中的所有文字内容，保持原始格式和排版。只返回提取的文字，不要添加额外说明。';

  @override
  String get ocrSavedInstructionSnapshot => '已保存的指令快照';

  @override
  String get ocrPageTitle => '文字识别';

  @override
  String get ocrImageQualitySettings => '图片画质设置';

  @override
  String get ocrImageQualityStandard => '标准画质';

  @override
  String get ocrImageQualityStandardHint => '压缩尺寸，适合多数情况';

  @override
  String get ocrImageQualityOriginal => '原图 / 高细节';

  @override
  String get ocrImageQualityOriginalHint => '保留更多细节，图片和请求更大';

  @override
  String get ocrReorderDone => '完成';

  @override
  String get ocrReorderAction => '排序';

  @override
  String get ocrClearAction => '清空';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return '旧任务使用模型 $modelId，请重新选择供应商和模型';
  }

  @override
  String get ocrLegacyModelPositionInvalid => '旧重试记录中的模型位置无效，请重新选择';

  @override
  String get ocrLegacyModelPositionConfirm => '旧重试记录只保存了模型位置，请确认当前模型后继续。';

  @override
  String get ocrModelUnavailable => '原 OCR 供应商或模型已不存在，请重新选择';

  @override
  String get ocrModelLabel => '模型';

  @override
  String get ocrConfigure => '去配置';

  @override
  String get ocrSelectModel => '请选择模型';

  @override
  String get ocrInstructionLabel => '指令';

  @override
  String get ocrManageInstructions => '管理识别指令';

  @override
  String get ocrInstructionManageGuidance =>
      '这些指令是通用设置，适用于所有识别模型。未选择指令时，仅发送图片。';

  @override
  String get ocrInstructionManageEmpty => '暂无指令';

  @override
  String get ocrInstructionEditTooltip => '编辑指令';

  @override
  String get ocrInstructionDeleteTooltip => '删除指令';

  @override
  String get ocrInstructionAdd => '添加指令';

  @override
  String get ocrInstructionEditorEditTitle => '编辑指令';

  @override
  String get ocrInstructionNameLabel => '指令名称（可选）';

  @override
  String get ocrInstructionContentLabel => '指令内容';

  @override
  String get ocrBatchMode => '批量方式';

  @override
  String get ocrMergeRecognition => '合并识别';

  @override
  String get ocrRecognizeEachImage => '逐张识别';

  @override
  String get ocrMaxConcurrency => '最多 2 张同时请求';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张同时请求',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '并发 $count',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint => '已完成的页面会保留，重试时只会提交未完成的页面。';

  @override
  String get ocrTakePhoto => '拍照识别';

  @override
  String get ocrChooseFromAlbum => '相册选择';

  @override
  String get ocrNoImagesSelected => '暂无选中图片';

  @override
  String get ocrSelectImagesHint => '支持拍照或从相册批量选择图片进行识别';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '请重新选择全部 $count 张图片后重试',
    );
    return '$_temp0';
  }

  @override
  String ocrImageLabel(Object index) {
    return '图片 $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return '图片_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => '图片索引无效';

  @override
  String get ocrViewErrorDetails => '查看详细错误';

  @override
  String get ocrConfirmModel => '确认此模型';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 张图片',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => '准备图片中...';

  @override
  String get ocrSavingRetryImages => '保存重试图片...';

  @override
  String get ocrRecognizing => '识别中...';

  @override
  String get ocrReadingRetryImages => '读取重试图片...';

  @override
  String get ocrImportingImages => '正在导入图片...';

  @override
  String get ocrStartRecognition => '开始识别';

  @override
  String get ocrSaveTo => '保存至';

  @override
  String get ocrRootDirectory => '根目录';

  @override
  String get ocrChooseSaveFolder => '选择保存文件夹';

  @override
  String get ocrChooseImageSource => '选择图片来源';

  @override
  String get ocrChooseAppAlbum => '从应用相册选择';

  @override
  String get ocrAppAlbumDescription => '从应用内已保存的图片中选择';

  @override
  String get ocrChooseSystemAlbum => '从系统相册选择';

  @override
  String get ocrSystemAlbumDescription => '浏览并选择设备中的图片';

  @override
  String ocrTakePhotoFailed(Object error) {
    return '拍照失败: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return '选择图片失败: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已加载 $count 张图片',
    );
    return '$_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return '处理图片失败: $error';
  }

  @override
  String get ocrUnknownSourceImageCount => '无法确认原图片数量';

  @override
  String get ocrConfirmClear => '确认清空';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      '原始 OCR 图片缓存不可用，且图片数量无法恢复。确认后会清空旧重试状态，请重新选择本次 OCR 的全部图片。';

  @override
  String get ocrConfirmClearSelected => '确定清空已选择的 OCR 图片吗？';

  @override
  String get ocrCancel => '取消';

  @override
  String get ocrConfirmResetAndReselect => '确认重置并重新选择';

  @override
  String get ocrRequestCheckFailed => '无法检查 OCR 请求，请检查模型参数';

  @override
  String get ocrCancelledAdjustAndRetry => '本次识别已取消；请调整供应商/模型请求大小或图片画质后重试。';

  @override
  String get ocrRequestSizeExceededTitle => 'OCR 请求大小超过配置值';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return '当前 JSON 请求约为 $requestSize MiB，超过 $limit MiB 配置值。';
  }

  @override
  String get ocrRequestSizeHelp =>
      '可在供应商默认设置或模型覆盖值中调整请求大小，也可以切换图片画质。更改画质后，请清空并重新导入图片。';

  @override
  String get ocrUsePerImageMode => '改用逐张识别';

  @override
  String get ocrGotIt => '知道了';

  @override
  String get ocrWaitForImport => '请等待图片导入完成后再开始识别';

  @override
  String get ocrWaitForRetryImages => '正在读取重试图片，请稍候';

  @override
  String get ocrConfigureProviderModel => '请先在设置中配置 OCR 供应商和模型';

  @override
  String get ocrReselectProviderModel => '请重新选择 OCR 供应商和模型';

  @override
  String get ocrConfirmLegacyModel => '请先确认旧重试记录中的 OCR 模型';

  @override
  String get ocrRetryImagesUnavailable => '原始 OCR 图片缓存不可用，请清空并重新选择全部图片后重试';

  @override
  String get ocrRetryImageCountUnknown =>
      '原始 OCR 图片缓存不可用，且无法确认图片数量。请重置后重新选择本次全部图片';

  @override
  String get ocrRetryImageReset => '已重置原重试输入，请重新选择本次 OCR 的全部图片';

  @override
  String get ocrRetryImagesUnreadable => '原始 OCR 图片缓存无法读取，请清空并重新选择全部图片后重试';

  @override
  String get ocrRetryImagesMissing => '原始 OCR 图片缓存已丢失或损坏，请清空并重新选择全部图片后重试';

  @override
  String get ocrImageListChanged => '图片列表已变化，请重新开始识别。';

  @override
  String get ocrReadInstructionFailed => '读取识别指令失败，请重试';

  @override
  String get ocrErrorDetails => '错误详情';

  @override
  String get ocrRequestHeading => '请求 (Request)';

  @override
  String get ocrResponseHeading => '响应 (Response)';

  @override
  String get ocrNoDetails => '无详细数据';

  @override
  String get ocrImageLoadFailed => '无法加载图片';

  @override
  String get ocrCrop => '裁剪';

  @override
  String get ocrEdit => '编辑';

  @override
  String get ocrProcessingOcrFailed => '处理 OCR 图片失败，请重试';

  @override
  String get settingsPageTitle => '设置';

  @override
  String get settingsSectionGeneral => '常规设置';

  @override
  String get settingsSectionProviders => '供应商设置';

  @override
  String get settingsSectionSystemAssistant => '系统助手';

  @override
  String get settingsSectionContextManagement => '上下文管理';

  @override
  String get settingsSectionManagement => '管理';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsBackupRestore => '数据备份与恢复';

  @override
  String get settingsBackupRestoreDescription => '导出或导入应用数据';

  @override
  String get settingsCookies => 'Cookies与浏览器数据';

  @override
  String get settingsCookiesDescription => '管理持久化的Cookies和浏览器存储数据';

  @override
  String get settingsAppLogs => '应用日志';

  @override
  String get settingsAppLogsDescription => '查看应用运行日志';

  @override
  String get settingsThemeDisplay => '主题与显示';

  @override
  String get settingsThemeDisplayDescription => '深色模式、显示语言';

  @override
  String get settingsTaskNotifications => '任务完成通知';

  @override
  String get settingsTaskNotificationsDescription => '检测通知权限与系统设置，查看通知指南';

  @override
  String get settingsBackgroundOptimization => '后台运行优化';

  @override
  String get settingsBackgroundOptimizationDescription =>
      '检测系统环境与后台服务状态，查看优化教程';

  @override
  String get aboutVersionInfo => '查看版本信息';

  @override
  String get aboutCheckUpdates => '检查更新';

  @override
  String aboutNewVersionFound(Object version) {
    return '发现新版本 $version';
  }

  @override
  String get aboutNewVersion => '新版本';

  @override
  String get aboutPreviewUpdates => '接收预览版';

  @override
  String get aboutPreviewUpdatesDescription => '开启后可检查预览版更新';

  @override
  String get aboutProjectHome => '项目主页';

  @override
  String get aboutFeedback => '问题反馈';

  @override
  String get aboutPrivacyPolicy => '隐私政策';

  @override
  String get aboutOpenSourceAgreement => '开源协议';

  @override
  String get aboutOpenSourceLicenses => '开源许可';

  @override
  String get aboutCheckingUpdates => '正在检查更新...';

  @override
  String get aboutUpToDate => '已是最新版本';

  @override
  String aboutUpdateNetworkError(Object details) {
    return '网络错误：$details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return '检查更新失败：HTTP 状态码 $statusCode。';
  }

  @override
  String get aboutUpdateInvalidResponse => '更新服务器返回了无法识别的数据。';

  @override
  String get aboutUpdateCheckFailed => '检查更新失败，请重试。';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return '检查助手更新失败：$error';
  }

  …138255 tokens truncated…';
  }

  @override
  String get sseNetworkConnectionUnavailable => '网络请求失败：无法连接到服务器';

  @override
  String get sseRequestCancelled => '请求已取消';

  @override
  String get startupSafetyTitle => '数据安全保护';

  @override
  String get startupSafetyExportButton => '导出数据';

  @override
  String get startupSafetyExitButton => '退出应用';

  @override
  String get startupSafetyUpdateButton => '更新应用';

  @override
  String get startupSafetyCheckingUpdates => '正在检查更新...';

  @override
  String get startupSafetyUpToDate => '已是最新版本';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return '数据由更新版本的应用创建（$version）。\n\n当前版本无法安全读取这些数据。请安装最新版本的应用后再继续，数据未做任何改动。';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      '无法确认数据安全状态（状态标记无法读取或格式无效）。\n\n为避免覆盖可能存在的冻结状态，应用已阻止启动，未执行数据修复或格式迁移。请先导出数据文件，然后退出应用并修复状态标记后重试。';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return '数据格式迁移失败（$part）。\n\n为保护数据，未做任何改动。请回退到旧版本应用，或等待修复版本发布后再升级。';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return '数据格式迁移失败（$part）。\n\n已自动恢复到迁移前的数据。为保护数据，请回退到旧版本应用，或等待修复版本发布后再升级。';
  }

  @override
  String get startupSafetyDataCorrupted =>
      '数据损坏且无法自动修复。\n\n应用已冻结以防止进一步破坏。请先导出数据文件，然后手动导入或重新安装。';

  @override
  String get startupSafetyPreferencesUnavailable =>
      '无法读取启动检查所需的偏好设置，应用已阻止继续启动以保护数据。\n\n请检查存储空间或权限后重新打开应用。';

  @override
  String get startupSafetyValidationUnavailable =>
      '无法完成启动数据安全检查，应用已阻止继续启动以保护数据。\n\n请检查浏览器设置后重新打开应用。';

  @override
  String startupSafetyCheckFailed(String detail) {
    return '启动检查失败：$detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      '完成启动数据检查后，仍无法确认数据安全状态（状态标记无法读取或格式无效）。\n\n为避免继续改动数据，应用已停止启动。请先导出数据文件，然后退出应用并修复状态标记后重试。';

  @override
  String get catCatchConnectionTimeout => '连接超时，请检查网络或服务器状态';

  @override
  String get catCatchSendTimeout => '发送请求超时';

  @override
  String get catCatchReceiveTimeout => '接收响应超时，服务器响应过慢';

  @override
  String get catCatchCannotConnect => '无法连接到服务器。';

  @override
  String get catCatchConnectionError => '无法连接到服务器，请检查 URL 是否正确';

  @override
  String get catCatchBadCertificate => '服务器证书验证失败';

  @override
  String catCatchBadResponse(int statusCode) {
    return '服务器返回错误 (HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => '请求已取消';

  @override
  String catCatchNetworkError(String message) {
    return '网络错误：$message';
  }

  @override
  String get catCatchUnknownError => '未知错误';

  @override
  String catCatchOriginalError(String message) {
    return '原始错误：$message';
  }

  @override
  String get catCatchWebDownloadHint => 'Web 端不支持直接下载媒体文件。';

  @override
  String get catCatchWebInstallExtension => '请安装浏览器扩展「CatCatch（猫抓）」后再试。';

  @override
  String get catCatchWebAuthorAttribution => '作者：笨笨猫（xifangczy），完全免费开源。';

  @override
  String get catCatchWebOfficialWarning => '请认准作者，避免下载到付费版/山寨版。';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub 地址: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired => '此功能需要登录账户后使用，请使用右上角浏览器内的登录功能。';

  @override
  String get catCatchNoUsableMedia => '未能获取到可用媒体资源，请检查 URL 是否正确以及目标网站是否可访问。';

  @override
  String get catCatchRedownloadFileMissing => '重新下载失败，下载文件不存在。';

  @override
  String get catCatchRedownloadPathEmpty => '重新下载失败，下载文件路径为空。';

  @override
  String get catCatchWebBrowserRequired =>
      '网页无法在没有浏览器环境的情况下直接获取资源，请尝试在移动端或桌面端使用该功能，或者直接粘贴视频/音频文件的直链地址。';

  @override
  String get catCatchPlaylistNoSegments => '播放列表没有可下载的分段。';

  @override
  String get catCatchDownloadedSourceMissing => '下载源文件不存在，请重新下载。';

  @override
  String get appLogPageTitle => '应用日志';

  @override
  String get appLogRefresh => '刷新';

  @override
  String get appLogCleanupOldLogs => '清理旧日志';

  @override
  String get appLogCleanupDone => '旧日志已清理';

  @override
  String appLogRetentionNotice(int days) {
    return '日志保留期限：只保留最近 $days 天的日志，超过 $days 天会自动清理。';
  }

  @override
  String get appLogWebUnsupported => 'Web 平台不支持本地日志';

  @override
  String get appLogNoFiles => '暂无日志文件';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在自动刷新（第 $count 次）...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated => '应用运行后将自动生成日志';

  @override
  String get appLogExport => '导出';

  @override
  String get appLogDelete => '删除';

  @override
  String get appLogConfirmDeleteTitle => '确认删除';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return '确定要删除日志文件 \"$fileName\" 吗？';
  }

  @override
  String get appLogCancel => '取消';

  @override
  String appLogLoadFilesError(Object error) {
    return '加载日志文件列表失败: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return '日志文件 \"$fileName\" 存在但无法读取，可能文件已损坏';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return '日志文件 \"$fileName\" 不存在，可能已被清理';
  }

  @override
  String appLogReadFileError(Object error) {
    return '读取日志文件失败: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return '已删除: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return '删除失败: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return '日志文件 \"$fileName\" 不存在';
  }

  @override
  String appLogPathCopied(String filePath) {
    return '已复制路径: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return '导出失败: $error';
  }

  @override
  String appLogLineCount(int count) {
    return '共 $count 行';
  }

  @override
  String get appLogCopyAll => '复制全文';

  @override
  String get appLogStructuredView => '结构化视图';

  @override
  String get appLogRawView => '原始视图';

  @override
  String appLogCopyError(Object error) {
    return '复制失败: $error';
  }

  @override
  String get appLogCopyDone => '已复制全部日志内容';

  @override
  String get iosContinuedTaskTitle => 'Stroom 后台任务';

  @override
  String get mermaidCatalogTypeFlowchart => '流程图';

  @override
  String get mermaidCatalogDescriptionFlowchart => '流程图 — 展示步骤、分支与循环';

  @override
  String get mermaidCatalogTypeSequenceDiagram => '时序图';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram => '时序图 — 展示对象之间的交互顺序';

  @override
  String get mermaidCatalogTypeClassDiagram => '类图';

  @override
  String get mermaidCatalogDescriptionClassDiagram => '类图 — 展示类的属性与方法关系';

  @override
  String get mermaidCatalogTypeStateDiagram => '状态图';

  @override
  String get mermaidCatalogDescriptionStateDiagram => '状态图 — 展示状态流转';

  @override
  String get mermaidCatalogTypeErDiagram => 'ER图';

  @override
  String get mermaidCatalogDescriptionErDiagram => 'ER图 — 展示实体关系';

  @override
  String get mermaidCatalogTypeGantt => '甘特图';

  @override
  String get mermaidCatalogDescriptionGantt => '甘特图 — 展示项目时间线';

  @override
  String get mermaidCatalogTypePie => '饼图';

  @override
  String get mermaidCatalogDescriptionPie => '饼图 — 展示占比数据';

  @override
  String get mermaidCatalogTypeJourney => '用户旅程图';

  @override
  String get mermaidCatalogDescriptionJourney => '用户旅程图 — 展示用户体验流程';

  @override
  String get mermaidCatalogTypeGitGraph => 'Git分支图';

  @override
  String get mermaidCatalogDescriptionGitGraph => 'Git分支图 — 展示Git分支与提交';

  @override
  String get mermaidCatalogTypeMindmap => '思维导图';

  @override
  String get mermaidCatalogDescriptionMindmap => '思维导图 — 展示层级结构';

  @override
  String get mermaidCatalogTypeTimeline => '时间线';

  @override
  String get mermaidCatalogDescriptionTimeline => '时间线 — 按时间顺序展示事件';

  @override
  String get mermaidCatalogTypeBlock => '块图';

  @override
  String get mermaidCatalogDescriptionBlock => '块图 — 展示块级布局与关系';

  @override
  String get mermaidCatalogTypeRequirement => '需求图';

  @override
  String get mermaidCatalogDescriptionRequirement => '需求图 — 展示需求与实现关系';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[开始]\n  B[处理步骤]\n  C<MERMAID_OPEN_BRACE>判断条件<MERMAID_CLOSE_BRACE>\n  D[结束]\n\n  A --> B\n  B --> C\n  C -->|是| D\n  C -->|否| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant 用户\n  participant 系统\n  participant 数据库\n\n  用户->>系统: 发送请求\n  系统->>数据库: 查询数据\n  数据库-->>系统: 返回结果\n  系统-->>用户: 显示结果';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String name\n    +int age\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String studentId\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String teacherId\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  [*] --> 待处理\n  待处理 --> 处理中\n  处理中 --> 已完成\n  处理中 --> 失败\n  失败 --> 待处理\n  已完成 --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : 下单\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : 包含\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : 商品\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title 项目甘特图\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section 需求阶段\n  需求分析     :a1, 2024-01-01, 14d\n  原型设计     :a2, after a1, 10d\n\n  section 开发阶段\n  前端开发     :b1, after a2, 20d\n  后端开发     :b2, after a2, 20d\n  接口联调     :b3, after b1, 7d\n\n  section 测试阶段\n  功能测试     :c1, after b3, 10d\n  部署上线     :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title 数据分布\n  \"类别A\" : 40\n  \"类别B\" : 25\n  \"类别C\" : 20\n  \"类别D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title 用户注册流程\n  section 注册页面\n    打开注册页: 5: 用户\n    填写信息: 3: 用户\n    提交申请: 4: 用户\n  section 验证阶段\n    接收验证码: 3: 系统\n    输入验证码: 4: 用户\n    验证成功: 5: 系统, 用户';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"初始提交\"\n  commit id: \"添加功能A\"\n  branch develop\n  checkout develop\n  commit id: \"开发新功能\"\n  commit id: \"修复bug\"\n  checkout main\n  merge develop\n  commit id: \"发布v1.0\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((项目管理))\n    需求\n      功能需求\n      非功能需求\n    开发\n      前端\n      后端\n    测试\n      单元测试\n      集成测试\n    部署\n      测试环境\n      生产环境';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title 项目里程碑\n  2024-Q1 : 需求调研 : 方案确定\n  2024-Q2 : 开发阶段 : 功能实现\n  2024-Q3 : 测试阶段 : Bug修复 : 性能优化\n  2024-Q4 : 部署上线 : 运营维护';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"需求\"] B[\"开发\"] C[\"测试\"]\n  D[\"部署\"] E[\"运维\"] F[\"监控\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement 用户登录 <MERMAID_OPEN_BRACE>\n    id: 1\n    text: 用户能够使用账号密码登录系统\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element 登录页面 <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element 认证服务 <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  登录页面 - satisfies -> 用户登录\n  认证服务 - verifies -> 用户登录';

  @override
  String get mermaidCatalogDefaultFileName => '我的图表';

  @override
  String get mermaidCatalogActionAddNode => '添加节点';

  @override
  String get mermaidCatalogActionAddDecision => '添加菱形判断';

  @override
  String get mermaidCatalogActionAddEdge => '添加连接线';

  @override
  String get mermaidCatalogActionAddSubgraph => '添加子图';

  @override
  String get mermaidCatalogActionAddParticipant => '添加参与者';

  @override
  String get mermaidCatalogActionAddRequest => '添加请求';

  @override
  String get mermaidCatalogActionAddResponse => '添加响应';

  @override
  String get mermaidCatalogActionAddNote => '添加备注';

  @override
  String get mermaidCatalogActionAddClass => '添加类';

  @override
  String get mermaidCatalogActionAddInheritance => '添加继承';

  @override
  String get mermaidCatalogActionAddRelationship => '添加关联';

  @override
  String get mermaidCatalogActionAddAggregation => '添加聚合';

  @override
  String get mermaidCatalogActionAddState => '添加状态';

  @override
  String get mermaidCatalogActionAddTransition => '添加转换';

  @override
  String get mermaidCatalogActionAddStart => '添加开始';

  @override
  String get mermaidCatalogActionAddEnd => '添加结束';

  @override
  String get mermaidCatalogActionAddEntity => '添加实体';

  @override
  String get mermaidCatalogActionAddOneToMany => '添加一对多';

  @override
  String get mermaidCatalogActionAddManyToMany => '添加多对多';

  @override
  String get mermaidCatalogActionAddOneToOne => '添加一对一';

  @override
  String get mermaidCatalogActionAddPhase => '添加阶段';

  @override
  String get mermaidCatalogActionAddTask => '添加任务';

  @override
  String get mermaidCatalogActionAddDependentTask => '添加依赖任务';

  @override
  String get mermaidCatalogActionAddMilestone => '添加里程碑';

  @override
  String get mermaidCatalogActionAddCategory => '添加类别';

  @override
  String get mermaidCatalogActionAddTitle => '添加标题';

  @override
  String get mermaidCatalogActionAddSystemTask => '添加系统任务';

  @override
  String get mermaidCatalogActionAddMultiPersonTask => '添加多人任务';

  @override
  String get mermaidCatalogActionAddCommit => '添加提交';

  @override
  String get mermaidCatalogActionCreateBranch => '创建分支';

  @override
  String get mermaidCatalogActionSwitchBranch => '切换分支';

  @override
  String get mermaidCatalogActionMergeBranch => '合并分支';

  @override
  String get mermaidCatalogActionAddBranch => '添加分支';

  @override
  String get mermaidCatalogActionAddChildBranch => '添加子分支';

  @override
  String get mermaidCatalogActionAddTopic => '添加主题';

  @override
  String get mermaidCatalogActionAddPeriod => '添加时间段';

  @override
  String get mermaidCatalogActionAddBlock => '添加块';

  @override
  String get mermaidCatalogActionAddColumns => '添加列';

  @override
  String get mermaidCatalogActionAddConnection => '添加连接';

  @override
  String get mermaidCatalogActionAddChildBlock => '添加子块';

  @override
  String get mermaidCatalogActionAddRequirement => '添加需求';

  @override
  String get mermaidCatalogActionAddElement => '添加元素';

  @override
  String get mermaidCatalogActionAddVerification => '添加验证';

  @override
  String get mermaidCatalogGanttDependencyBaseTask => '依赖基准任务';

  @override
  String get mermaidCatalogGanttDependentTaskName => '后续任务';

  @override
  String get startupMigrationTitle => '数据格式升级完成';

  @override
  String get startupMigrationBody => '数据已迁移到新版格式。请重启应用以使用新版本。';

  @override
  String get startupMigrationExit => '退出应用';

  @override
  String get startupMigrationRestart => '立即重启';

  @override
  String get startupRecoveryTitle => '应用启动异常';

  @override
  String get startupRecoveryFallbackMessage => '启动过程中遇到数据格式问题，已自动修复，请重试。';

  @override
  String get startupRecoveryRetry => '重试';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return 'ASR $category（$stage）$chunk：$message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return '，第 $index/$count 段';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return '请求失败：$detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return '分段转写全部失败（共 $count 段，均未成功）';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return '分段转写未完成（$succeeded/$count 段成功）';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return '成功：$detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return '失败：$detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return '结果不确定：$detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return '第 $index 段（$start–$end 秒）$status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return '保存分段状态失败：$detail';
  }

  @override
  String get asrChunkUncertainGuidance => '请求结果不确定。为避免重复提交，已停止重试。请重新选择音频后新建任务。';

  @override
  String asrRetryAudioLost(Object audioName) {
    return '原始音频文件已丢失，请重新选择音频后重试：$audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return '原始音频文件已损坏，请重新选择音频后重试：$audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return '，分段 $index';
  }

  @override
  String get asrChunkDetailsSeparator => '；';

  @override
  String asrRecognitionFailed(Object detail) {
    return '语音识别失败：$detail';
  }

  @override
  String get asrFailureCategoryAuthentication => '认证失败';

  @override
  String get asrFailureCategoryRateLimit => '请求过于频繁';

  @override
  String get asrFailureCategorySizeLimit => '文件过大';

  @override
  String get asrFailureCategoryNetwork => '网络';

  @override
  String get asrFailureCategoryResponseParsing => '响应解析';

  @override
  String get asrFailureCategoryLocalProcessing => '本地处理';

  @override
  String get asrFailureCategoryProvider => '服务商';

  @override
  String get asrFailureCategoryUnknown => '未知';

  @override
  String get asrFailureStagePreprocessing => '预处理';

  @override
  String get asrFailureStageEncoding => '编码';

  @override
  String get asrFailureStageValidation => '验证';

  @override
  String get asrFailureStageRequest => '请求';

  @override
  String get asrFailureStageUploading => '上传';

  @override
  String get asrFailureStageWaiting => '等待';

  @override
  String get asrFailureStageReceiving => '接收响应';

  @override
  String get asrFailureStageResponse => '响应';

  @override
  String get asrFailureStageParsing => '解析';

  @override
  String get asrFailureStageStorage => '保存';

  @override
  String get chatMissingProvider => '请先配置聊天供应商';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Anthropic API 错误：$detail';
  }

  @override
  String get anthropicStreamUnknownError => '未知错误';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'API 请求失败 (HTTP $statusCode)：$detail';
  }

  @override
  String get fileUploadApiKeyMissing => 'API 密钥未配置，无法上传文件';

  @override
  String get fileUploadApiUrlMissing => 'API 地址未配置，无法上传文件';

  @override
  String get fileUploadContentEmpty => '文件内容为空';

  @override
  String get fileUploadFilenameEmpty => '文件名为空';

  @override
  String get fileUploadMimeTypeEmpty => 'MIME 类型为空';

  @override
  String get fileUploadPurposeEmpty => '上传用途（purpose）为空';

  @override
  String get fileUploadCanceled => '上传已取消';

  @override
  String get fileUploadCreateMissingId => '创建上传失败：响应中缺少 upload id';

  @override
  String get fileUploadPartMissingId => '上传分片失败：响应中缺少 part id';

  @override
  String get fileUploadCompleteMissingFile => '完成上传失败：响应中缺少 file 对象';

  @override
  String get fileUploadMissingFileId => '上传失败：响应中缺少 file id';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return '文件上传请求失败 (HTTP $statusCode)：$detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return '文件上传请求失败：$detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'API 密钥未配置';

  @override
  String chatStreamError(Object detail) {
    return 'API 流式错误：$detail';
  }

  @override
  String get chatChoicesMissing => 'API 返回的 choices 列表为空';

  @override
  String get chatContentBlocksMissing => 'API 返回的 content 列表为空';

  @override
  String get chatResponseContentEmpty => 'API 返回内容为空';

  @override
  String chatRequestFailed(Object detail) {
    return '请求失败：$detail';
  }

  @override
  String get startupTagline => '你的学习助手';

  @override
  String get startupProgressDataSafety => '正在检查数据安全...';

  @override
  String get startupProgressFormatVersion => '正在检查数据格式版本...';

  @override
  String get startupProgressDataFormat => '正在验证数据格式...';

  @override
  String get startupProgressDataIntegrity => '正在检查数据完整性...';

  @override
  String get startupProgressResults => '正在处理检查结果...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return '启动完成（注意：$warning）';
  }

  @override
  String get startupProgressCompleteAfterMigration => '数据检查完成，正在准备启动应用。';

  @override
  String get startupProgressReady => '正在准备启动应用。';

  @override
  String startupWarningErrorCount(Object count) {
    return '发现 $count 个数据问题：';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return '$count 个警告：';
  }

  @override
  String get startupIssueProviderEntriesInvalid => '服务商条目格式错误：应为 JSON 数组。';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return '服务商条目 $index 为空或类型无效。';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return '服务商条目 $index 缺少 ID 或 ID 为空。';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return '服务商条目 $index 缺少类型或类型为空。';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return '服务商条目 $index 缺少名称或名称为空。';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return '服务商条目 $index 的 $field 字段不是有效列表。';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return '服务商条目 $index 的 $field 中有无效项目，可能导致解析失败。';
  }

  @override
  String get startupIssueConversationsInvalid => '会话数据格式错误：应为 JSON 数组。';

  @override
  String startupIssueConversationInvalid(Object index) {
    return '会话 $index 为空或类型无效。';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return '会话 $index 缺少 ID。';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return '会话 $index 缺少消息字段。';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return '会话 $index 的消息字段不是有效列表。';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return '服务商条目 $index 使用未知类型“$type”，可能无法正常工作。';
  }

  @override
  String get startupErrorTitle => '应用启动失败';

  @override
  String startupErrorDetails(Object error) {
    return '错误：$error';
  }

  @override
  String get renderErrorTitle => '界面渲染异常';

  @override
  String get renderErrorDebugTitle => '界面渲染异常（调试模式）';

  @override
  String get renderErrorRestartMessage => '请尝试重启应用。';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return '导入完成：$decks 个牌组，$notes 个笔记，$cards 张卡片';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '找不到所选的 .apkg 文件：$path';
  }

  @override
  String get backupRestoreApkgCollectionMissing =>
      '.apkg 文件中缺少 collection.anki2。';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return '请先打开 Anki 闪卡功能，再导入或导出牌组：$path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt => 'Anki collection 数据库已损坏。';

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return '.apkg 操作访问此路径时失败：$path';
  }

  @override
  String get backupRestoreApkgOperationFailed => '.apkg 操作失败，无法读取文件或数据库。';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return '无法从此数据库打包导出 Anki 牌组：$path';
  }

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      '网页端需登录 AnkiWeb 才能同步。请点击云朵图标打开 Anki 设置并登录。';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      '如需在网页端浏览或管理牌组，请点击云朵图标登录 AnkiWeb。';

  @override
  String get ankiStatsUnsupportedPlatform => '当前平台无法查看 Anki 统计数据。';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      '设备时间与同步服务器相差超过 5 分钟，请校准设备时间后重试。';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      '同步数据校验失败，本地更改已回滚。请完整下载服务器 collection 后重试。';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      '此 collection 无法增量同步。请选择完整上传或下载后继续。';

  @override
  String get ankiSyncStatusIncrementalSyncFailed => '增量同步未能完成。请检查服务器和网络连接后重试。';
}
