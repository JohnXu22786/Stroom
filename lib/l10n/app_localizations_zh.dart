Warning: truncated output (original token count: 149988)
Total output lines: 20918

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
  String topicAssistantUpdateCheckFailed(Object error) =>
      '检查助手更新失败：$error';

  @override
  String get aboutPrivacyContent =>
      'Stroom 尊重并保护所有使用服务用户的个人隐私权。\n\n1. 相机权限：仅用于拍摄照片，不会收集或上传任何图像数据。\n\n2. 相册权限：仅用于选择照片和保存照片，所有照片都保存在本地设备。\n\n3. 数据安全：所有拍摄的照片都保存在您的设备本地，我们不会访问或上传任何数据。\n\n4. 第三方服务：本应用不包含任何第三方分析或广告服务。\n\n如果您有任何疑问，请联系我们。';

  @override
  String get aboutClose => '关闭';

  @override
  String get contextToolPruneTitle => '工具结果自动清理 (Prune)';

  @override
  String get contextToolPruneDescription => '旧工具结果超过阈值时自动压缩为占位符，释放存储与上下文';

  @override
  String get contextCompactionTriggerSettings => '压缩触发设置';

  @override
  String get contextCompactionDisabled => '已关闭（不触发压缩）';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return '全局触发 $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模型独立设置',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => '压缩触发设置';

  @override
  String get contextAutoCompaction => '上下文自动压缩';

  @override
  String get contextAutoCompactionDisabled => '关闭后所有模型都不触发压缩';

  @override
  String get contextGlobalTrigger => '全局触发百分比';

  @override
  String get contextGlobalTriggerDescription => '未单独设置的模型，按模型上下文窗口的该百分比触发压缩';

  @override
  String contextResetPercent(Object percent) {
    return '重置为 $percent%';
  }

  @override
  String get contextPerModelSettings => '按模型设置';

  @override
  String get contextNoConfiguredModels => '暂无已配置的模型';

  @override
  String contextIndependentThreshold(Object threshold) {
    return '独立触发值 $threshold token';
  }

  @override
  String get contextEnterIndependentThreshold => '填写下方独立触发值';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return '跟随全局 $percent%';
  }

  @override
  String get contextThresholdField => '独立触发值 (token)';

  @override
  String get contextThresholdHint => '如 48000（非百分比，直接填写 token 数）';

  @override
  String get contextPercentField => '百分比';

  @override
  String contextPercentHint(Object percent) {
    return '如 $percent';
  }

  @override
  String get versionInfoTitle => '版本信息';

  @override
  String get versionNumberLabel => '版本号';

  @override
  String get versionReleaseTimeLabel => '发布时间';

  @override
  String get versionLocalBuild => '本地构建';

  @override
  String get versionReleaseNotesLabel => '更新内容';

  @override
  String get versionClose => '关闭';

  @override
  String get updateDialogTitle => '发现新版本';

  @override
  String get updateLatestVersionLabel => '最新版本';

  @override
  String get updateSelectedVersionLabel => '已选择';

  @override
  String get updateReleaseNotesLabel => '更新内容';

  @override
  String get updateInstalling => '正在安装...';

  @override
  String get updateDownloadComplete => '下载完成';

  @override
  String get updateClose => '关闭';

  @override
  String get updateManualInstall => '手动安装';

  @override
  String get updateOpenInstaller => '打开安装包';

  @override
  String get updateRetryDownload => '重试下载';

  @override
  String get updateSkipVersion => '跳过此版本';

  @override
  String get updateRemindLater => '稍后提醒';

  @override
  String get updateOpenBrowser => '前往浏览器下载';

  @override
  String get updateNow => '立即更新';

  @override
  String get updatePreviewBadge => '预览版';

  @override
  String get updateLatestBadge => '最新';

  @override
  String get updateSelectVersion => '选择版本';

  @override
  String get updateDownloading => '正在下载更新...';

  @override
  String updateCheckNetworkError(Object details) {
    return '网络错误：$details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return '检查更新失败：HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse => '检查更新失败：服务器返回了无法识别的数据';

  @override
  String get updateDownloadUrlUnavailable => '下载地址不可用';

  @override
  String get updateNoDirectDownloadLink => '当前平台暂无直接下载链接，请前往浏览器手动下载';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return '自动安装失败：$details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return '下载失败：HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return '下载失败：$details';
  }

  @override
  String updateInstallFailed(Object details) {
    return '安装失败：$details';
  }

  @override
  String updateFailed(Object details) {
    return '更新失败：$details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return '无法打开文件，请手动安装：$path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return '安装失败，请手动打开 APK 安装：$details';
  }

  @override
  String get updateApkInstallFailedNoDetails => '安装失败，请手动打开 APK 安装';

  @override
  String get contextCompactionHistoryIntro => '以下是需要压缩的对话历史：';

  @override
  String get contextCompactionUserRole => '用户';

  @override
  String get contextCompactionAssistantRole => '助手';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role 调用了工具 $toolName：$result';
  }

  @override
  String get contextCompactionFinalInstruction => '请将以上对话历史压缩为锚定摘要，严格按模板输出。';

  @override
  String get ocrImageEmpty => '图片为空，请重新选择。';

  @override
  String get ocrImageUnsupportedFormat => '不支持此图片格式，请先转换为 PNG、JPEG 或 WebP 后重试。';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      '暂不支持 HEIC、SVG 或 TIFF 图片，请先转换为 PNG、JPEG 或 WebP 后重试。';

  @override
  String get ocrImageDecodeFailed =>
      '图片内容损坏或无法解码，请重新选择，或转换为 PNG、JPEG、WebP 后重试。';

  @override
  String get ocrImageDimensionsTooLarge =>
      '图片分辨率过大，OCR 每张图片最多支持 5000 万像素，请缩小图片后重试。';

  @override
  String get ocrImageOrientationPngTooLarge =>
      '校正图片方向后的 PNG 会超过 OCR 请求大小上限，请先缩小图片后重试。';

  @override
  String get ocrImageOrientationFailed => '无法校正图片方向，请转换为 PNG、JPEG 或 WebP 后重试。';

  @override
  String get ocrImagePreparationFailed => '无法处理图片，请重新选择后重试。';

  @override
  String get homeTitle => '主页';

  @override
  String get homeWelcome => '欢迎使用 Stroom';

  @override
  String get homeChooseModule => '选择一个功能模块开始使用';

  @override
  String get homeOcrSubtitle => '文字识别';

  @override
  String get homeAsrTitle => '语音识别';

  @override
  String get homeAsrSubtitle => '语音转文字';

  @override
  String get homeWebDownloadTitle => '下载网页资源';

  @override
  String get homeWebDownloadSubtitle => '下载网页中的音视频';

  @override
  String get homeAudioSeparationTitle => '音频分离';

  @override
  String get homeAudioSeparationSubtitle => '从视频中提取音频';

  @override
  String get homeTtsTitle => '语音合成';

  @override
  String get homeTtsSubtitle => '文字转语音';

  @override
  String get homeChartsTitle => '图表制作';

  @override
  String get homeChartsSubtitle => 'Mermaid 图表编辑';

  @override
  String get homeMathTitle => '数学绘图';

  @override
  String get homeMathSubtitle => '函数绘图';

  @override
  String get homeAnkiTitle => 'Anki 闪卡';

  @override
  String get homeAnkiSubtitle => '记忆辅助系统';

  @override
  String get homeTaskFlowTitle => '任务流';

  @override
  String get homeTaskFlowEmpty => '创建一个自动化任务流，依次执行多个功能';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个任务流 · 点击管理',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => '最近任务';

  @override
  String get homeViewAll => '查看全部';

  @override
  String get statusInProgress => '进行中';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get navHome => '主页';

  @override
  String get navChat => '对话';

  @override
  String get navFiles => '文件';

  @override
  String get navSettings => '设置';

  @override
  String get conversationsTitle => '对话历史';

  @override
  String get conversationNew => '新对话';

  @override
  String get conversationSelectTitle => '选择对话';

  @override
  String get topicSelectionEmptyTitle => '暂无对话';

  @override
  String get topicSelectionEmptyMessage => '创建一个新对话开始对话';

  @override
  String get topicSelectionNewTopic => '新话题';

  @override
  String get topicSelectionNoAssistant => '未选择助手';

  @override
  String get topicSelectionBackToAssistants => '返回选择助手';

  @override
  String get topicSelectionEditAssistant => '编辑助手';

  @override
  String get topicSelectionReorderHint => '长按拖拽即可调整对话顺序';

  @override
  String conversationDeleteNamed(String title) {
    return '确定要删除对话“$title”吗？此操作无法撤销。';
  }

  @override
  String get conversationDeleteTitle => '删除对话';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '确定要删除选中的 $count 个对话吗？此操作无法撤销。',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => '取消';

  @override
  String get actionDelete => '删除';

  @override
  String get conversationRename => '重命名对话';

  @override
  String get conversationRenameHint => '输入新名称';

  @override
  String get actionConfirm => '确定';

  @override
  String get conversationNoMatches => '没有找到匹配的对话';

  @override
  String get conversationEmpty => '暂无历史记录';

  @override
  String get conversationSearchHint => '搜索所有对话中的消息...';

  @override
  String conversationSelected(int count) {
    return '已选 $count 个';
  }

  @override
  String get conversationSearch => '搜索';

  @override
  String get conversationDeleteSelected => '删除选中';

  @override
  String get actionUnselect => '取消选择';

  @override
  String get actionSelect => '选择';

  @override
  String conversationDeleteCount(int count) {
    return '删除 $count 个';
  }

  @override
  String get conversationPin => '置顶';

  @override
  String get conversationUnpin => '取消置顶';

  @override
  String get actionRename => '重命名';

  @override
  String get conversationAutoRename => '自动命名';

  @override
  String get conversationTemporary => '临时对话';

  @override
  String get conversationCloseTemporary => '关闭临时对话';

  @override
  String get taskListTitle => '任务列表';

  @override
  String get taskListEmpty => '暂无任务';

  @override
  String get unifiedTaskListTabAll => '全部';

  @override
  String get unifiedTaskListTabInProgress => '进行中';

  @override
  String get unifiedTaskListTabCompleted => '已完成';

  @override
  String get unifiedTaskListTabFailed => '失败';

  @override
  String get unifiedTaskListTabStopped => '已停止';

  @override
  String get unifiedTaskListConfirmClear => '确认清除';

  @override
  String get unifiedTaskListConfirmClearFailedMessage => '确定要清除所有失败任务吗？';

  @override
  String get unifiedTaskListConfirmClearAllMessage => '确定要清除所有任务吗？此操作不可撤销。';

  @override
  String get unifiedTaskListCancel => '取消';

  @override
  String get unifiedTaskListConfirm => '确定';

  @override
  String get unifiedTaskListClearCompleted => '清除已完成';

  @override
  String get unifiedTaskListClearFailed => '清除失败任务';

  @override
  String get unifiedTaskListClearAll => '清除所有';

  @override
  String get unifiedTaskListRestoreInProgress => '正在恢复任务流记录…';

  @override
  String get unifiedTaskListRestoreFailed => '任务流记录读取失败，任务操作已暂停';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return '清除未完成：$error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning => '任务流取消后仍在运行';

  @override
  String get unifiedTaskListCancellationSaveFailed => '无法保存任务流的取消状态，请重试清除。';

  @override
  String get unifiedTaskListRemovalSaveFailed => '无法保存任务流记录的删除状态，请重试清除。';

  @override
  String get chatAutoContinuePrompt => '如果还没完成，请继续。';

  @override
  String get chatSearchCurrent => '搜索当前对话...';

  @override
  String get chatSearchAll => '搜索所有对话...';

  @override
  String get searchPrevious => '上一个';

  @override
  String get searchNext => '下一个';

  @override
  String get searchClose => '关闭搜索';

  @override
  String get searchCurrentConversation => '当前对话';

  @override
  String get searchAllConversations => '所有对话';

  @override
  String get chatReasoning => '推理';

  @override
  String get chatTools => '工具';

  @override
  String get chatCustomParameters => '自定义参数';

  @override
  String get chatEditMessage => '编辑消息';

  @override
  String get actionClose => '关闭';

  @override
  String get chatEditWarning => '重新编辑发送后下面所有的消息将丢失';

  @override
  String get chatAttachment => '附件';

  @override
  String get chatMessageHint => '输入消息...';

  @override
  String get chatFullscreenEdit => '全屏编辑';

  @override
  String get chatStopGeneration => '停止生成';

  @override
  String get actionSend => '发送';

  @override
  String get chatCopy => '复制';

  @override
  String get actionSave => '保存';

  @override
  String get actionRetry => '重试';

  @override
  String get actionEdit => '编辑';

  @override
  String get chatViewResponseData => '查看响应数据';

  @override
  String get chatViewRequestData => '查看请求数据';

  @override
  String get chatInspectJson => 'JSON 审查';

  @override
  String get chatConfirmEditTitle => '编辑消息';

  @override
  String get chatConfirmEditDeleteFollowing => '确定要编辑这条消息吗？此操作将删除此消息及之后的所有消息。';

  @override
  String get chatConfirmResend => '确定要重新发送这条消息吗？';

  @override
  String get chatConfirmRetryTitle => '重试';

  @override
  String get chatConfirmRetryDeleteFollowing => '确定要重试这条回复吗？此操作将删除此消息及之后的所有消息。';

  @override
  String get chatConfirmRegenerate => '确定要重新生成回复吗？';

  @override
  String get chatDeleteMessageTitle => '删除消息';

  @override
  String get chatDeleteMessageConfirm => '确定要删除这条消息吗？此操作无法撤销。';

  @override
  String get chatThinking => '思考中';

  @override
  String get chatThinkingComplete => '思考完成';

  @override
  String get conversationDeleteOne => '确定要删除这个对话吗？此操作无法撤销。';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '已选 $selected/$total 个资源',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => '选择要下载的资源';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '收起 $count 个分片',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '显示 $count 个分片',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => '检测到 0 个资源';

  @override
  String get mediaSegment => '分片';

  @override
  String get mediaPlaylist => '播放列表';

  @override
  String get mediaFullVideo => '整片';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours时$minutes分$seconds秒';
  }

  @override
  String mediaDuration(String value) {
    return '时长：$value';
  }

  @override
  String mediaResolution(int width, int height) {
    return '分辨率：${width}x$height';
  }

  @override
  String get mediaPreview => '预览';

  @override
  String get mediaSegmentPreviewHint => '分片需通过播放列表预览';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '下载选中的 $count 个资源',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => '确认下载';

  @override
  String get chatNoMoreHistory => '没有更多内容了';

  @override
  String get chatSendFailed => '发送失败';

  @override
  String get chatViewErrorDetails => '查看详细错误';

  @override
  String get chatCompactionCollapsed => '上下文已压缩，旧对话已总结（点击收起）';

  @override
  String get chatCompactionExpanded => '上下文已压缩，旧对话已总结（点击查看摘要）';

  @override
  String get chatEditConversationTitle => '编辑对话标题';

  @override
  String get chatSearchMessages => '搜索消息';

  @override
  String get chatApiMissingSettings => '⚠️ 未配置聊天 API — 前往设置';

  @override
  String get appSettings => '设置';

  @override
  String get chatCopied => '已复制';

  @override
  String get chatNoSavableText => '没有可保存的文本内容';

  @override
  String get chatSaveMarkdownTitle => '保存消息为 Markdown';

  @override
  String get chatSaveToolCallChoice => '该回复包含多步工具调用，选择要保存的内容：';

  @override
  String get chatSaveCompleteMessage => '保存完整消息';

  @override
  String get chatSaveLastMessage => '保存最后的消息';

  @override
  String get chatSaveToAppFiles => '保存到应用文件';

  @override
  String get chatSaveFolderHint => '选择或创建文件夹保存 .md 文件';

  @override
  String get chatSaveFilenameHint => '输入文件名（自动添加 .md 后缀）';

  @override
  String get chatFilenameRequired => '文件名不能为空';

  @override
  String chatSavedToPath(String path) {
    return '已保存到：$path';
  }

  @override
  String chatSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return '已保存到应用文件：$path';
  }

  @override
  String get chatSelectModel => '选择模型';

  @override
  String get chatModelFallback => '模型';

  @override
  String get chatNoModelsAvailable => '暂无可用模型';

  @override
  String get chatAvailableTools => '可用工具';

  @override
  String get chatNoToolsAvailable => '暂无可用工具';

  @override
  String get chatReasoningSettings => '推理设置';

  @override
  String get chatReasoningNotConfigured => '当前模型未配置推理参数，请在模型设置中添加';

  @override
  String get chatReasoningEffort => '推理力度';

  @override
  String get chatReasoningEffortNotConfigured => '当前模型未配置推理力度参数，请在模型设置中添加';

  @override
  String get chatParameterNoOptions => '该参数暂无选项值，请在模型设置中添加';

  @override
  String get chatOtherReasoningNotConfigured => '当前模型未配置其他推理参数\n请在模型设置中添加';

  @override
  String get chatCustomParamsNotConfigured => '当前模型未配置自定义参数\n请在模型设置中添加';

  @override
  String get chatNoOptionValues => '无选项值，请在模型设置中添加';

  @override
  String get chatImageLoadFailed => '无法加载图片';

  @override
  String get chatVideoLoadFailed => '视频加载失败';

  @override
  String get chatHtmlLoading => '加载 HTML 预览...';

  @override
  String get chatPreviewLoadFailed => '加载失败';

  @override
  String get albumPickerLoadFailed => '加载应用内相册失败';

  @override
  String get chatHtmlPreview => 'HTML 预览';

  @override
  String get chatMermaidLoading => '加载图表预览...';

  @override
  String get chatMermaidPreview => 'Mermaid 预览';

  @override
  String get chatZoomOut => '缩小';

  @override
  String get chatZoomIn => '放大';

  @override
  String get chatJsonInspection => 'JSON 审查';

  @override
  String get chatNoRequestData => '无请求数据';

  @override
  String get chatNoResponseData => '无响应数据';

  @override
  String get chatSaveMessage => '保存消息';

  @override
  String get chatChooseSaveLocation => '选择消息保存位置';

  @override
  String get chatChooseSaveLocationLabel => '选择保存位置：';

  @override
  String get chatSaveAppFile => '保存到应用文件';

  @override
  String get chatSaveDevice => '保存到设备';

  @override
  String get chatFileTypeAudio => '音频文件';

  @override
  String get chatFileTypeVideo => '视频文件';

  @override
  String get chatFileTypeDocument => '文档';

  @override
  String get chatFileTypeGeneric => '文件';

  @override
  String get chatInfoType => '类型';

  @override
  String get chatInfoSize => '大小';

  @override
  String get chatInfoPath => '路径';

  @override
  String get chatErrorBack => '返回';

  @override
  String get chatErrorPrefix => '错误: ';

  @override
  String get chatErrorCancelled => '用户中断了输出';

  @override
  String get chatErrorProviderNotConfigured => '聊天 API 未配置，请先前往设置页面配置';

  @override
  String get chatErrorApiKeyNotConfigured => 'API Key 未配置，请检查设置';

  @override
  String get chatErrorServerConnection => '无法连接到服务器，请检查网络连接和 API 地址';

  @override
  String get chatErrorNetworkConnection => '网络连接失败，请检查网络连接';

  @override
  String get chatErrorTimeout => '连接超时，服务器无响应';

  @override
  String chatAttachmentImportFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return '拍照失败: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform不支持设备相册功能: $error';
  }

  @override
  String get chatAttachmentWebPlatform => 'Web浏览器';

  @override
  String get chatAttachmentCurrentPlatform => '当前设备';

  @override
  String get chatAttachmentGalleryPermissionHint => '请授予相册访问权限后重试';

  @override
  String get chatAttachmentBrowserPermissionHint => '请在浏览器设置中允许此网站访问文件';

  @override
  String get chatAttachmentGalleryFallbackHint => '请检查设备是否支持相册选择功能';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return '导入图片失败: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform不支持文件选择功能: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint => '请授予文件访问权限后重试';

  @override
  String get chatAttachmentFileFallbackHint => '请确保设备支持文件选择功能';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return '导入文件失败: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return '已导入 $fileName';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return '保存编辑后的图片失败: $error';
  }

  @override
  String get chatDataDetails => '数据详情';

  @override
  String get chatErrorDetailOcrDiagnostics => 'OCR 诊断';

  @override
  String get chatErrorDetailRequestUrl => '请求 URL';

  @override
  String get chatErrorDetailRequestHeaders => '请求标头';

  @override
  String get chatErrorDetailRequestBody => '请求正文';

  @override
  String get chatErrorDetailStatusCode => '状态码';

  @override
  String get chatErrorDetailResponseHeaders => '响应标头';

  @override
  String get chatErrorDetailResponseBody => '响应正文';

  @override
  String get chatErrorDetailEmpty => '暂无详细信息';

  @override
  String get chatAudioPreviewClose => '关闭';

  @override
  String get chatPreviewClose => '关闭预览';

  @override
  String get actionBack => '返回';

  @override
  String get chatCannotLoadFile => '无法加载文件';

  @override
  String chatThinkingNumbered(int index) {
    return '思考 $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '放弃未保存的更改？';

  @override
  String get taskFlowUiDiscardBody => '返回后，所有未保存的更改将会丢失。';

  @override
  String get taskFlowUiContinueEditing => '继续编辑';

  @override
  String get taskFlowUiDiscard => '放弃';

  @override
  String get taskFlowUiUndo => '撤销';

  @override
  String get taskFlowUiSave => '保存';

  @override
  String get taskFlowUiNameHint => '输入任务流名称';

  @override
  String get taskFlowUiDescriptionHint => '添加描述（可选）';

  @override
  String get taskFlowUiNameRequired => '请输入任务流名称';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return '步骤 $index：$message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '「$block」的「$parameter」为必填项';
  }

  @override
  String get taskFlowUiSaveFailed => '保存失败，更改仍保留，请重试';

  @override
  String get taskFlowUiRetry => '重试';

  @override
  String get taskFlowUiUpdated => '任务流已更新';

  @override
  String get taskFlowUiCreated => '任务流已创建';

  @override
  String get taskFlowUiTitle => '任务流';

  @override
  String get taskFlowUiNotFound => '任务未找到';

  @override
  String get taskFlowUiBack => '返回';

  @override
  String get taskFlowUiEdit => '编辑';

  @override
  String taskFlowUiInput(Object label) {
    return '输入（$label）';
  }

  @override
  String get taskFlowUiInputHint => '输入文本或链接';

  @override
  String get taskFlowUiStart => '开始任务流';

  @override
  String get taskFlowUiNoInput => '暂无输入，点击下方按钮添加网页资源 URL';

  @override
  String get taskFlowUiAddResource => '添加网页资源';

  @override
  String get taskFlowUiUrlHint => '请输入视频/音频网页URL';

  @override
  String get taskFlowUiDeleteInput => '删除此输入';

  @override
  String get taskFlowUiHour => '时';

  @override
  String get taskFlowUiMinute => '分';

  @override
  String get taskFlowUiSecond => '秒';

  @override
  String get taskFlowUiPreview => '预览: ';

  @override
  String get taskFlowUiDurationFormat => '时:分:秒';

  @override
  String get taskFlowUiDurationHint => '可选：按时长筛选视频资源。留空则展示全部资源供选择';

  @override
  String get taskFlowUiSelectImages => '选择图片（可多选）';

  @override
  String get taskFlowUiSelectAudio => '选择音频（可多选）';

  @override
  String get taskFlowUiSelectFiles => '选择文件（可多选）';

  @override
  String get taskFlowUiSelectVideo => '选择视频（可多选）';

  @override
  String get taskFlowUiRemove => '移除';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return '清理已移除文件失败：$error';
  }

  @override
  String get taskFlowUiInitialInput => '0. 初始输入';

  @override
  String taskFlowUiInputType(Object type) {
    return '输入类型: $type';
  }

  @override
  String get taskFlowUiUserFlowInput => '用户运行任务流时输入';

  @override
  String taskFlowUiBlockInput(Object type) {
    return '输入: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return '输出: $type';
  }

  @override
  String get taskFlowUiParameters => '参数:';

  @override
  String get taskFlowUiClose => '关闭';

  @override
  String get taskFlowUiSelectAppImages => '选择应用内图片（可多选）';

  @override
  String get taskFlowUiNoImages => '暂无图片';

  @override
  String get taskFlowUiSelectAppAudio => '选择应用内音频（可多选）';

  @override
  String get taskFlowUiNoAudio => '暂无音频';

  @override
  String get taskFlowUiSelectAppVideo => '选择应用内视频（可多选）';

  @override
  String get taskFlowUiNoVideo => '暂无视频';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return '选择文件失败：$error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '「$name」超过 $limit MB，请选择较小文件';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '「$name」为空或无法读取';
  }

  @override
  String get taskFlowUiSomeFilesMissing => '部分文件不存在，已跳过';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return '有 $count 个已选文件无法找到或读取，请重新选择全部文件。';
  }

  @override
  String get taskFlowUiQueuedOne => '任务流已加入队列';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return '已将 $count 个任务流加入队列';
  }

  @override
  String get taskFlowUiRunTitle => '本次运行';

  @override
  String get taskFlowUiCancelBatch => '取消整个批次';

  @override
  String get taskFlowUiRestoringRecords => '正在恢复任务流记录…';

  @override
  String get taskFlowUiRecordsPaused => '任务流记录读取失败，任务操作已暂停';

  @override
  String get taskFlowUiRecordsCleared => '本次运行记录已清除';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$finished/$total 个运行已结束';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return ' · $count 个记录已清除';
  }

  @override
  String get taskFlowUiTemporaryFiles => '临时中间文件';

  @override
  String get taskFlowUiAddBlock => '添加功能块';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return '在步骤 $index 前插入功能块';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks => '没有同时兼容相邻步骤的功能块，请先调整相邻步骤';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return '在步骤 $index 前插入';
  }

  @override
  String get taskFlowUiUnknown => '未知';

  @override
  String get taskFlowUiChooseBlock => '选择功能块';

  @override
  String get taskFlowUiInsertBlock => '插入功能块';

  @override
  String get taskFlowUiPreviousOutput => '上一步输出';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '，下一步需要: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock => '没有与当前类型兼容的功能块';

  @override
  String get taskFlowUiReplaceBlock => '替换功能块';

  @override
  String get taskFlowUiBlockCompatibility => '只能替换为输入输出兼容的功能块（同类输入输出）';

  @override
  String get taskFlowUiTemporaryCleanupTooltip => '下一个步骤成功保存结果后清理；最终步骤始终保留';

  @override
  String get taskFlowUiSetParameters => '设置参数';

  @override
  String get taskFlowUiReplace => '替换';

  @override
  String get taskFlowUiViewParameters => '点击查看参数';

  @override
  String get taskFlowUiTapSetParameters => '点击设置参数';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return '未知功能块: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => '该功能块类型未注册';

  @override
  String taskFlowUiStepActions(Object index) {
    return '步骤 $index 操作';
  }

  @override
  String get taskFlowUiInsertBefore => '在前面插入';

  @override
  String get taskFlowUiInsertAfter => '在后面插入';

  @override
  String get taskFlowUiCopyBlock => '复制功能块';

  @override
  String get taskFlowUiMoveUp => '上移';

  @override
  String get taskFlowUiMoveUpDisabled => '上移（已在最前）';

  @override
  String get taskFlowUiMoveDown => '下移';

  @override
  String get taskFlowUiMoveDownDisabled => '下移（已在最后）';

  @override
  String get taskFlowUiDeleteBlock => '删除功能块';

  @override
  String taskFlowUiInputLabel(Object label) {
    return '输入: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return '输出: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return '功能块类型 “$name” 未注册';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$label 设置';
  }

  @override
  String get taskFlowUiSendToAssistant => '发送给助手的用户消息 = 上一步的输出';

  @override
  String get taskFlowUiTempSpaceInfo =>
      '此步骤会输出到任务流的临时空间，下一个步骤成功保存结果后自动清理。原保存文件夹会保留，关闭临时模式后恢复。';

  @override
  String get taskFlowUiNoExtraParameters => '该功能块无额外参数';

  @override
  String get taskFlowUiCancel => '取消';

  @override
  String get taskFlowUiConfirm => '确认';

  @override
  String get taskFlowUiConfigureModelFirst => '请先配置模型';

  @override
  String get taskFlowUiModelUnavailable => '模型未选择或已失效，请重新选择';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return '模型 $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => '未命名供应商';

  @override
  String get taskFlowUiCustomModelParameters => '模型自定义参数';

  @override
  String get taskFlowUiTtsVoiceMissing => '所有TTS模型均未配置音色，可手动输入ID';

  @override
  String get taskFlowUiVoiceUnavailable => '音色已失效，请重新选择';

  @override
  String get taskFlowUiSelectVoice => '选择音色';

  @override
  String get taskFlowUiAssistantUnavailable => '助手不存在';

  @override
  String get taskFlowUiAssistantUseCurrent => '未指定（使用当前选中的助手）';

  @override
  String get taskFlowUiAssistantDeleted => '配置的助手已删除，请重新选择';

  @override
  String get taskFlowUiChooseAssistant => '选择助手';

  @override
  String get taskFlowUiOnlyCustomAssistants => '只能选择\"我的助手\"（在\"聊天 → 助手\"中添加）';

  @override
  String get taskFlowUiMyAssistants => '我的助手';

  @override
  String get taskFlowUiNoCustomAssistants => '还没有自定义助手，可在\"聊天 → 助手\"中创建';

  @override
  String get taskFlowUiYes => '是';

  @override
  String get taskFlowUiNo => '否';

  @override
  String get taskFlowUiDefaultRoot => '默认 (根目录)';

  @override
  String get taskFlowUiSelect => '选择';

  @override
  String get taskFlowUiSelectSaveFolder => '选择保存文件夹';

  @override
  String get taskFlowUiCatCatchVideo => '视频';

  @override
  String get taskFlowUiCatCatchAudio => '音频';

  @override
  String get taskFlowUiCatCatchEither => '视频或音频（按下游筛选）';

  @override
  String get taskFlowUiManual => '手动';

  @override
  String get taskFlowUiAutomatic => '自动';

  @override
  String get taskFlowUiAutomaticPrompt => '自动并询问';

  @override
  String get taskFlowUiEditTitle => '编辑任务流';

  @override
  String get taskFlowUiCreateTitle => '新建任务流';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return '步骤 $index：$message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return '输入类型: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return '输入: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return '输出: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return '清理已移除文件失败：$error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return '选择文件失败：$error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '「$name」超过 $limit MB，请选择较小文件';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '「$name」为空或无法读取';
  }

  @override
  String get taskFlowUiTemporary => '临时';

  @override
  String get taskFlowUiTemporaryFileHint => '临时文件（下一步成功后清理）';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return '功能块类型 “$name” 未注册';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$finished/$total 个运行已结束';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return ' · $count 个记录已清除';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return '输入: $input → 输出: $output';
  }

  @override
  String get taskFlowCardTag => '任务流';

  @override
  String get taskFlowCardQueued => '排队中（等待资源）';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done/$total 已完成';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count 个$label';
  }

  @override
  String get taskFlowCardFailedLabel => '失败';

  @override
  String get taskFlowCardSkippedLabel => '跳过';

  @override
  String get taskFlowCardCancelledLabel => '取消';

  @override
  String get taskFlowCardInterruptedLabel => '中断';

  @override
  String get taskFlowCardCancelFlow => '取消流程';

  @override
  String get taskFlowCardRetry => '重试';

  @override
  String get taskFlowCardCancelBatch => '取消整个批次';

  @override
  String get taskFlowCardDelete => '删除';

  @override
  String get taskFlowCardRetryFlow => '重试任务流';

  @override
  String get taskFlowCardNoSnapshot => '此历史记录没有运行快照，将使用当前流程配置从头运行。';

  @override
  St…114988 tokens truncated…下载 ZIP 文件';

  @override
  String textStorageExportedFiles(int count) {
    return '已导出 $count 个文件';
  }

  @override
  String get textStorageExportFolderTitle => '导出文本文件夹';

  @override
  String textStorageCopyFailed(String error) {
    return '复制失败：$error';
  }

  @override
  String get textStorageCreateNew => '新建';

  @override
  String get textStorageImport => '导入';

  @override
  String get textStorageTitle => '文本';

  @override
  String get textStorageExportToLocal => '导出到本地';

  @override
  String get textCreateEnterTitle => '请输入标题';

  @override
  String textCreateSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get textCreateNewTitle => '新建';

  @override
  String get textCreateSave => '保存';

  @override
  String get textCreateTitleLabel => '标题';

  @override
  String get textCreateTitleHint => '输入文本标题';

  @override
  String get textCreateFormatLabel => '格式';

  @override
  String get textCreateContentLabel => '文本内容';

  @override
  String get textCreateContentHint => '输入文本内容...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform 后台运行优化教程';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform 后台运行教程';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform 后台运行优化指南';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return '以下步骤可帮助您在 $platform 设备上优化 Stroom 的后台运行体验，确保任务在后台持续执行。';
  }

  @override
  String get platformTutorialStepsHeading => '优化步骤';

  @override
  String get platformTutorialTipsHeading => '小提示';

  @override
  String get platformTutorialTipsDescription =>
      '完成以上设置后，建议回到「后台运行优化」页面确认检测状态已更新。如果仍有问题，请查看其他平台的教程或前往 GitHub 提交反馈。';

  @override
  String get platformTutorialAndroidStep1Title => '关闭电池优化';

  @override
  String get platformTutorialAndroidStep1Description =>
      '进入「设置」→「应用」→「Stroom」→「电池」→ 选择「无限制」或「不优化」。也可以直接在本 App 的「后台运行优化」页面点击「忽略电池优化」，一键加入系统省电白名单。不同品牌手机路径可能略有不同。';

  @override
  String get platformTutorialAndroidStep2Title => '允许后台活动';

  @override
  String get platformTutorialAndroidStep2Description =>
      '进入「设置」→「应用」→「Stroom」→ 开启「允许后台活动」和「允许自启动」。部分手机还需在「安全中心」或「手机管家」中允许自启动。';

  @override
  String get platformTutorialAndroidStep3Title => '锁定后台进程';

  @override
  String get platformTutorialAndroidStep3Description =>
      '在多任务界面（最近任务列表）中，将 Stroom 卡片向下拉或点击锁定图标，锁定应用使其不被系统清理。';

  @override
  String get platformTutorialAndroidStep4Title => '允许通知权限（Android 13+）';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 及以上系统需要单独授予通知权限，否则后台服务的前台通知不会显示（服务仍会运行）。首次点击「启动服务」时 App 会自动请求该权限，也可以前往「设置」→「应用」→「Stroom」→「通知」手动开启。';

  @override
  String get platformTutorialAndroidStep5Title => '忽略电池优化权限';

  @override
  String get platformTutorialAndroidStep5Description =>
      '在 Stroom 中开启「任务完成通知」时，App 会自动请求相关权限。您也可以手动前往「设置」→「应用」→「特殊权限」→「电池优化」中确认 Stroom 已设为「不优化」。';

  @override
  String get platformTutorialAndroidStep6Title => '国产系统自启动与后台管理';

  @override
  String get platformTutorialAndroidStep6Description =>
      '国产系统通常有自己的后台管理策略，请按品牌操作：\n• 小米/红米（MIUI/HyperOS）：设置 → 应用设置 → 授权管理 → 自启动管理 → 允许 Stroom 自启动；「省电与电池」→「应用智能省电」→ Stroom → 无限制。\n• 华为/荣耀（EMUI/HarmonyOS）：设置 → 应用 → 应用启动管理 → Stroom → 手动管理 → 允许自启动/关联启动/后台活动。\n• OPPO/一加/真我（ColorOS）：设置 → 电池 → 应用耗电管理 → Stroom → 允许完全后台行为。\n• vivo/iQOO（OriginOS）：i管家 → 应用管理 → 自启动 → 允许 Stroom。';

  @override
  String get platformTutorialAndroidStep7Title => '关闭锁屏清理与省电模式';

  @override
  String get platformTutorialAndroidStep7Description =>
      '进入「设置」→「电池」→ 关闭「省电模式」或「超级省电」，并将「锁屏后清理内存」设为「不清理」。省电模式会限制后台应用活动，影响任务完成。';

  @override
  String get platformTutorialIosStep1Title => '开启后台应用刷新';

  @override
  String get platformTutorialIosStep1Description =>
      '进入「设置」→「通用」→「后台应用刷新」→ 找到 Stroom 并开启。建议选择「无线局域网与蜂窝数据」以获得最佳体验。';

  @override
  String get platformTutorialIosStep2Title => '允许通知';

  @override
  String get platformTutorialIosStep2Description =>
      '进入「设置」→「通知」→「Stroom」→ 开启「允许通知」。确保通知样式设为「横幅」和「通知中心」以便及时获知任务状态。';

  @override
  String get platformTutorialIosStep3Title => '关闭低电量模式';

  @override
  String get platformTutorialIosStep3Description =>
      '进入「设置」→「电池」→ 关闭「低电量模式」。低电量模式下系统会限制后台活动。';

  @override
  String get platformTutorialIosStep4Title => '理解 iOS 的后台运行限制';

  @override
  String get platformTutorialIosStep4Description =>
      'iOS 26 以下系统不允许应用像 Android 那样常驻后台运行。系统仅在特定时机（如后台 App 刷新、定位、播放音频）给应用少量执行时间，长时间任务会被系统挂起。建议：\n• 需要长时间运行的任务保持 Stroom 在前台；\n• 定期切换回 App 以刷新后台执行时间；\n• 重要任务配合「任务完成通知」及时获知结果。';

  @override
  String get platformTutorialIosStep5Title => '任务运行时的后台注意事项';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 及以上系统支持任务常驻后台：任务运行期间切换 App 或锁屏，任务通常会继续执行（系统资源紧张时可能终止），锁屏界面会显示任务进度。\n\niOS 26 以下系统不支持常驻后台：任务运行时请每隔几分钟返回一次 App（建议 5–10 分钟，具体由系统决定），刷新后台执行时间，防止任务被挂起。\n\n所有版本都请勿在 App 切换器中划掉 Stroom——划掉会立即终止所有运行中的任务。';

  @override
  String get platformTutorialIosStep6Title => '保持 App 在前台';

  @override
  String get platformTutorialIosStep6Description =>
      '在 iOS 26 以下系统上，App 在后台的运行时间有限。建议在需要长时间运行任务时，保持 Stroom 在前台或定期切换回来以延长后台时间。';

  @override
  String get platformTutorialWindowsStep1Title => '关闭窗口时最小化';

  @override
  String get platformTutorialWindowsStep1Description =>
      '默认情况下，点击窗口关闭按钮不会退出 Stroom，而是最小化到系统托盘（任务栏右下角）继续后台运行。点击托盘图标（或托盘菜单「显示主窗口」）可恢复窗口。任务运行时请勿直接退出应用；确实需要退出时，请使用「后台运行优化」页面的「完全退出应用」按钮，或托盘菜单中的「退出 Stroom」。';

  @override
  String get platformTutorialWindowsStep2Title => '关闭节电模式';

  @override
  String get platformTutorialWindowsStep2Description =>
      '进入「设置」→「系统」→「电源和睡眠」→ 关闭「节电模式」。或将节电模式设置为仅在电池电量低于指定百分比时自动开启。';

  @override
  String get platformTutorialWindowsStep3Title => '允许后台运行';

  @override
  String get platformTutorialWindowsStep3Description =>
      '进入「设置」→「隐私和安全性」→「后台应用」→ 找到 Stroom 并确保已开启。Windows 11 中此选项位于「设置」→「应用」→「已安装的应用」→ Stroom →「高级选项」→「后台应用权限」→ 选择「始终」。';

  @override
  String get platformTutorialWindowsStep4Title => '关闭睡眠模式（可选）';

  @override
  String get platformTutorialWindowsStep4Description =>
      '如果希望 Stroom 在电脑长时间运行时持续工作，可以进入「设置」→「系统」→「电源」→ 将「睡眠」设置为「从不」（仅在连接电源时）。';

  @override
  String get platformTutorialWindowsStep5Title => '添加到开机自启';

  @override
  String get platformTutorialWindowsStep5Description =>
      '打开任务管理器（Ctrl+Shift+Esc）→「启动」→ 找到 Stroom → 右键「启用」。或进入「设置」→「应用」→「启动」→ 开启 Stroom。';

  @override
  String get platformTutorialMacosStep1Title => '关闭窗口时最小化';

  @override
  String get platformTutorialMacosStep1Description =>
      '默认情况下，点击窗口关闭按钮不会退出 Stroom，而是最小化到菜单栏（屏幕右上角）继续后台运行。点击菜单栏图标（或菜单「显示主窗口」）可恢复窗口。任务运行时请勿直接退出应用；确实需要退出时，请使用「后台运行优化」页面的「完全退出应用」按钮，或菜单栏菜单中的「退出 Stroom」。';

  @override
  String get platformTutorialMacosStep2Title => '允许通知';

  @override
  String get platformTutorialMacosStep2Description =>
      '进入「系统设置」→「通知」→「Stroom」→ 开启「允许通知」。建议同时开启「横幅」和「通知中心」。';

  @override
  String get platformTutorialMacosStep3Title => '关闭低电量模式（MacBook）';

  @override
  String get platformTutorialMacosStep3Description =>
      '进入「系统设置」→「电池」→ 选择「电源适配器」→ 关闭「低电量模式」。低电量模式会限制后台活动。';

  @override
  String get platformTutorialMacosStep4Title => '保持 App 激活状态';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS 对后台应用的限制较少。如需长时间运行，保持 Stroom 窗口打开即可。建议不要强制退出应用，直接关闭窗口即可。';

  @override
  String get platformTutorialMacosStep5Title => '登录时启动（可选）';

  @override
  String get platformTutorialMacosStep5Description =>
      '进入「系统设置」→「通用」→「登录项」→ 添加 Stroom，这样电脑启动时 Stroom 会自动运行。';

  @override
  String get platformTutorialLinuxStep1Title => '关闭窗口时最小化';

  @override
  String get platformTutorialLinuxStep1Description =>
      '默认情况下，点击窗口关闭按钮不会退出 Stroom，而是隐藏到系统托盘（需桌面环境支持 StatusNotifierItem，且构建时已安装 libayatana-appindicator3-dev）继续后台运行。在托盘菜单选择「显示主窗口」可恢复窗口。任务运行时请勿直接退出应用；确实需要退出时，请使用「后台运行优化」页面的「完全退出应用」按钮，或托盘菜单中的「退出 Stroom」。';

  @override
  String get platformTutorialLinuxStep2Title => '桌面环境设置';

  @override
  String get platformTutorialLinuxStep2Description =>
      '根据您使用的桌面环境（GNOME、KDE、XFCE 等），进入「系统设置」→「应用」→ 找到 Stroom 并确保没有限制后台活动。';

  @override
  String get platformTutorialLinuxStep3Title => '使用 systemd 服务（可选）';

  @override
  String get platformTutorialLinuxStep3Description =>
      '如需长时间后台运行，可以创建 systemd 用户服务。在 ~/.config/systemd/user/ 下创建 stroom.service 文件，配置 ExecStart 指向 Stroom 可执行文件。';

  @override
  String get platformTutorialLinuxStep4Title => '禁止休眠';

  @override
  String get platformTutorialLinuxStep4Description =>
      '如果服务器或桌面需要长期运行，可以修改 /etc/systemd/logind.conf 中的 HandleLidSwitch=ignore 防止合盖休眠。';

  @override
  String get platformTutorialLinuxStep5Title => '开启自动启动';

  @override
  String get platformTutorialLinuxStep5Description =>
      '在 GNOME 中，使用「优化」(Tweaks) 工具 →「开机启动程序」→ 添加 Stroom。或在 ~/.config/autostart/ 下创建 stroom.desktop 文件。';

  @override
  String get platformTutorialWebStep1Title => '保持标签页打开';

  @override
  String get platformTutorialWebStep1Description =>
      'Web 浏览器环境不支持后台服务运行。任务运行时请保持 Stroom 标签页打开，关闭标签页或刷新页面会立即中断任务。';

  @override
  String get platformTutorialWebStep2Title => '避免浏览器挂起标签页';

  @override
  String get platformTutorialWebStep2Description =>
      '浏览器会冻结长时间不活跃的后台标签页以节省资源。任务运行时请将 Stroom 标签页保持在前台，或定期点击页面保持其活跃。';

  @override
  String get browserNavigationFailed => '页面导航失败，地址已恢复';

  @override
  String get browserAddressHint => '输入网址';

  @override
  String get browserUserScripts => '用户脚本';

  @override
  String get browserSwitchToMobile => '切换到手机版';

  @override
  String get browserSwitchToDesktop => '切换到电脑版';

  @override
  String get browserUaSwitchedDesktop => '已切换到电脑版 UA';

  @override
  String get browserUaSwitchedMobile => '已切换到手机版 UA';

  @override
  String get browserCookieRetentionOnTooltip => 'Cookie 持久化（已开启）';

  @override
  String get browserCookieRetentionOffTooltip => 'Cookie 持久化（已关闭）';

  @override
  String get browserCookiePersistenceEnabled => '已启用 Cookie 持久化';

  @override
  String get browserCookiePersistenceDisabled => '已关闭 Cookie 持久化';

  @override
  String get browserSniffPanelHideTooltip => '隐藏嗅探面板';

  @override
  String get browserSniffPanelShowTooltip => '显示嗅探面板';

  @override
  String get browserAdd => '添加';

  @override
  String get browserNoScripts => '暂无脚本，点击“添加”创建';

  @override
  String get browserUnnamedScript => '未命名脚本';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个匹配规则',
    );
    return '$_temp0';
  }

  @override
  String get browserScriptOriginManual => '手动添加';

  @override
  String browserScriptVersion(Object version) {
    return '@version $version';
  }

  @override
  String get browserScriptEnabled => '已启用';

  @override
  String get browserScriptDisabled => '已停用';

  @override
  String get browserScriptRuntimeError => '此脚本运行时发生错误，请检查代码和网页兼容性。';

  @override
  String get browserScriptDelete => '删除';

  @override
  String get browserDeleteScriptTitle => '删除脚本？';

  @override
  String get browserDeleteScriptConfirmation => '此脚本将从此浏览器中移除，且无法撤销。';

  @override
  String get browserEditScript => '编辑脚本';

  @override
  String get browserScriptName => '脚本名称';

  @override
  String get browserScriptCode => '脚本代码 (JavaScript)';

  @override
  String get browserAddScriptMethod => '选择添加方式';

  @override
  String get browserImportFromUrl => '从 URL 导入';

  @override
  String get browserEnterManually => '手动输入';

  @override
  String get browserScriptTrustWarningTitle => '只添加自己信任的脚本';

  @override
  String get browserScriptTrustWarning => '只添加自己信任的脚本，否则可能会泄露数据。脚本可以读取或修改网页内容。';

  @override
  String get browserContinue => '继续';

  @override
  String get browserManualUserscriptLabel => '油猴脚本 (Tampermonkey 用户脚本)';

  @override
  String get browserScriptImportUrl => '脚本 URL';

  @override
  String get browserScriptImportFetch => '获取预览';

  @override
  String get browserScriptPreview => '脚本源码预览';

  @override
  String get browserScriptImportInvalidUrl => '请输入有效的 HTTPS URL。';

  @override
  String get browserScriptImportUnsupportedUrl =>
      '请使用 Greasy Fork 的 .user.js 地址或 GitHub Raw 地址。';

  @override
  String get browserScriptImportRedirectedUrl => '该 URL 跳转到了不受支持或不安全的地址。';

  @override
  String get browserScriptImportNotScript => '返回内容为空或看起来不是 JavaScript 脚本。';

  @override
  String get browserScriptImportNetworkError => '获取脚本失败，请检查 URL 和网络连接。';

  @override
  String browserScriptImportHttpError(Object status) {
    return '服务器返回 HTTP $status。';
  }

  @override
  String get browserCancel => '取消';

  @override
  String get browserSave => '保存';

  @override
  String get browserCookiesConfirmClear => '确认清除';

  @override
  String get browserCookiesConfirmClearAll => '确定要清除所有 Cookie 吗？\n此操作不可撤销。';

  @override
  String get browserCookiesClear => '清除';

  @override
  String get browserCookiesCancel => '取消';

  @override
  String get browserCookiesClearedAll => '已清除所有 Cookie';

  @override
  String get browserCookiesClearFailed => '清除失败，请重试';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return '已清除 $domain 的所有 Cookie';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '确定要清除 $domain 的所有 Cookie 吗？';
  }

  @override
  String get browserCookiesPageTitle => '浏览器数据管理';

  @override
  String get browserCookiesRetentionTitle => '退出时保留 Cookie 数据';

  @override
  String get browserCookiesRetentionOn => '已启用 — 退出时保留 Cookie';

  @override
  String get browserCookiesRetentionOff => '已禁用 — 退出时清除 Cookie';

  @override
  String get browserCookiesClearAllTitle => '清除所有 Cookie';

  @override
  String get browserCookiesClearAllDescription => '删除所有已保存的网站 Cookie';

  @override
  String get browserCookiesEmptyTitle => '暂无持久化数据';

  @override
  String get browserCookiesEmptyDescription =>
      '使用内置浏览器并开启 Cookie 持久化后，已保存的数据将在此处显示。';

  @override
  String browserCookiesStoredCount(Object count) {
    return '已存储的 Cookie（$count）';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个 Cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip => '清除此域名下的所有 Cookie';

  @override
  String get browserCookiesDeleteOneTooltip => '删除此 Cookie';

  @override
  String get browserCookiesDeletedOne => '已删除 Cookie';

  @override
  String get browserCookiesDeleteFailed => '删除失败，请重试';

  @override
  String get browserCookiesEmptyValue => '（空值）';

  @override
  String get platformTutorialPageTitle => '平台教程';

  @override
  String get browserRecoveryOpenPage => '打开恢复页面';

  @override
  String galleryUnsupportedPreview(String format) {
    return '不支持预览 .$format 格式';
  }

  @override
  String galleryCameraFailed(String error) {
    return '拍照失败：$error';
  }

  @override
  String get galleryPhotoSaved => '照片已保存';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return '已跳过不支持的格式：$format';
  }

  @override
  String galleryImportImagesCount(int count) {
    return '已导入 $count 张图片';
  }

  @override
  String galleryImportVideosCount(int count) {
    return '已导入 $count 个视频';
  }

  @override
  String galleryImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get galleryFileReadFailed => '文件数据读取失败';

  @override
  String get galleryExportImageTitle => '导出图片';

  @override
  String get galleryExportVideoTitle => '导出视频';

  @override
  String galleryExportedTo(String path) {
    return '已导出到：$path';
  }

  @override
  String galleryExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get galleryChooseExportDirectory => '选择导出目录';

  @override
  String galleryExportedFilesCount(int count) {
    return '已导出 $count 个文件';
  }

  @override
  String get galleryFolderExportTitle => '导出文件夹';

  @override
  String get galleryWebFolderExportInfo => '浏览器无法选择导出目录，将下载保留文件夹层级的 ZIP 文件。';

  @override
  String get galleryDownloadZip => '下载 ZIP 文件';

  @override
  String get galleryExportImageFolderTitle => '导出图片文件夹';

  @override
  String get galleryExportVideoFolderTitle => '导出视频文件夹';

  @override
  String get galleryImagePageTitle => '相册';

  @override
  String get galleryVideoPageTitle => '视频';

  @override
  String get galleryTakePhoto => '拍照';

  @override
  String get galleryRecordVideo => '录制';

  @override
  String get galleryImport => '导入';

  @override
  String get galleryExportToLocal => '导出到本地';

  @override
  String get galleryPlayVideo => '播放';

  @override
  String galleryCopyFailed(String error) {
    return '复制失败：$error';
  }

  @override
  String get galleryVideoSaved => '视频已保存';

  @override
  String galleryVideoRecordFailed(String error) {
    return '录制失败：$error';
  }

  @override
  String get galleryVideoLoadFailed => '无法加载视频';

  @override
  String get imageEditorSaveImageTitle => '保存图片';

  @override
  String get imageEditorSaveImagePrompt => '请选择保存方式：';

  @override
  String get imageEditorOverwrite => '覆盖';

  @override
  String get imageEditorSaveAs => '另存为';

  @override
  String get imageEditorSavePhotoTitle => '保存照片';

  @override
  String get imageEditorSavePhotoPrompt => '是否保存当前照片？';

  @override
  String get imageEditorDiscard => '不保存';

  @override
  String get imageEditorDoneLoading => '正在生成图片，请稍候…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return '快速编辑 - $fileName';
  }

  @override
  String get imageEditorNotReady => '编辑器尚未就绪，请稍后重试';

  @override
  String imageEditorProcessingFailed(String error) {
    return '图片处理失败：$error';
  }

  @override
  String get imageEditorLoadFailed => '无法加载图片';

  @override
  String get imageEditorProcessing => '正在处理图片，请稍候…';

  @override
  String get imageEditorRotateLeft => '左旋';

  @override
  String get imageEditorRotateRight => '右旋';

  @override
  String get imageEditorFlip => '翻转';

  @override
  String get imageEditorCrop => '裁剪';

  @override
  String get imageViewerImageSavedAsCopy => '图片已另存为副本';

  @override
  String get imageViewerImageUpdated => '图片已更新';

  @override
  String imageViewerSaveFailed(String error) {
    return '图片保存失败：$error';
  }

  @override
  String get imageViewerInvalidIndex => '图片索引无效';

  @override
  String get galleryExportImageArchiveFileName => '图片导出.zip';

  @override
  String get galleryExportVideoArchiveFileName => '视频导出.zip';

  @override
  String get galleryExportImageFolderArchiveFileName => '图片文件夹导出.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName => '视频文件夹导出.zip';

  @override
  String get catCatchPageTitle => '下载网页资源';

  @override
  String get catCatchAddTask => '添加任务';

  @override
  String get catCatchOpenBrowser => '内置浏览器';

  @override
  String get catCatchEmptyState => '暂无下载任务';

  @override
  String get catCatchEmptyStateHint => '点击右上角 + 添加下载任务';

  @override
  String get catCatchInvalidCapturedUrl => '捕获的URL无效';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return '已从浏览器捕获：$url';
  }

  @override
  String get catCatchEnterValidUrl => '请至少输入一个有效的URL';

  @override
  String get catCatchTaskAdded => '任务已添加';

  @override
  String catCatchTasksAdded(int count) {
    return '已添加 $count 个任务';
  }

  @override
  String get catCatchViewTaskList => '查看任务列表';

  @override
  String get catCatchUrlHint => '请输入视频/音频网页URL';

  @override
  String get catCatchDeleteTask => '删除此任务';

  @override
  String get catCatchHour => '时';

  @override
  String get catCatchMinute => '分';

  @override
  String get catCatchSecond => '秒';

  @override
  String get catCatchDurationPreview => '预览：';

  @override
  String get catCatchDurationFormat => '时:分:秒';

  @override
  String get catCatchDurationFilterHint => '可选：按时长筛选视频资源。留空则展示全部资源供选择';

  @override
  String get catCatchVideoSaveTo => '视频保存至';

  @override
  String get catCatchAudioSaveTo => '音频保存至';

  @override
  String catCatchTaskCount(int count) {
    return '已添加 $count 个任务';
  }

  @override
  String get catCatchStartAnalysis => '开始分析';

  @override
  String get catCatchVideoFolderTitle => '视频保存至文件夹';

  @override
  String get catCatchAudioFolderTitle => '音频保存至文件夹';

  @override
  String get catCatchRootFolder => '根目录';

  @override
  String connectivityTestTitle(String title) {
    return '$title · 连通性测试';
  }

  @override
  String get connectivityTestJsonLabel => '测试内容（JSON）';

  @override
  String get connectivityTestJsonHelp =>
      '修改后可直接运行或保存。MCP 使用只读 tools/list；搜索工具可改 query/count；Todo 默认只读。';

  @override
  String connectivityTestSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get connectivityTestSaved => '测试内容已保存';

  @override
  String get connectivityTestClose => '关闭';

  @override
  String get connectivityTestSaveContent => '保存内容';

  @override
  String get connectivityTestTesting => '测试中…';

  @override
  String get connectivityTestRun => '运行测试';

  @override
  String get connectivityTestFailedSummary => '测试未能完成';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds 毫秒';
  }

  @override
  String get messageSearchTitle => '全局消息搜索';

  @override
  String get messageSearchHint => '搜索所有对话中的消息...';

  @override
  String get messageSearchInitialState => '输入关键词搜索所有对话中的消息';

  @override
  String get messageSearchEmptyState => '未找到匹配的消息';

  @override
  String get messageSearchNewConversation => '新对话';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个匹配',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => '文本';

  @override
  String get filesTabAudio => '音频';

  @override
  String get filesTabImages => '图片';

  @override
  String get filesTabVideos => '视频';

  @override
  String get filesReorderTabs => '排序标签';

  @override
  String get filesReorderCancel => '取消';

  @override
  String get filesReorderDone => '确定';

  @override
  String get bgTaskCancelled => '已取消';

  @override
  String bgTaskAsrError(String details) {
    return '音频转写失败：$details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return '音频转写结果保存失败：$details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR识别失败：$details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'OCR结果保存失败：$details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR结果不完整：$details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => 'OCR 部分页面未完成';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return ' · 阶段 ${phaseElapsedMs}ms · 请求 $completedRequests · 已完成片段 $completedChunks/$chunkCount';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return '上传音频$chunk $percent% · $bytes bytes$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return '上传音频$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return '（片段 $index/$count）';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return '转写中$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return '转写中（片段 $index/$count）$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return '转写中（接收片段 $index/$count）$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return '接收结果 $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => '接收结果';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return '转写中（已完成片段 $index/$count）$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return '转写中（片段 $index/$count 已返回）$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return '第 $index/$total 张图片 $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return '上传$details';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return '上传图片 $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR 分段恢复记录写入失败；当前请求结果可能不确定，任务已停止：$details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR 分段恢复记录写入失败；该片段尚未发送，可修复本地存储后重试：$details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'ASR 取消前的分段状态写入失败；该片段仍按结果不确定处理：$details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return '无法保存 ASR 重试音频，任务未发送：$details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError => '批次中的其他音频无法保存，已取消发送';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR 返回了不完整结果（finish_reason=$finishReason）';
  }

  @override
  String ocrResultPageHeading(String index) {
    return '第 $index 张图片';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return '第 $index 张图片：$name';
  }

  @override
  String get ocrPartialResultSuffix => '（部分结果）';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return '部分图片 OCR 未完成：$details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return '第 $index 张图片结果不完整';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return '第 $index 张图片识别失败';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => '；';

  @override
  String get bgTaskInterruptedOnRestart => '应用重启，已中断';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR 错误详情已隐藏';

  @override
  String get bgTaskErrorDetailsHidden => '错误详情已隐藏';

  @override
  String get notificationBannerTaskCompletedHeading => '任务完成';

  @override
  String get notificationBannerTaskFailedHeading => '任务失败';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return '任务完成：$typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return '任务失败：$typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title 已完成';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title 失败：$error';
  }

  @override
  String get notificationUnknownError => '未知错误';

  @override
  String get desktopTrayTooltip => 'Stroom 正在后台运行';

  @override
  String get desktopTrayOpen => '打开 Stroom';

  @override
  String get desktopTrayShowMainWindow => '显示主窗口';

  @override
  String get desktopTrayQuitStroom => '退出 Stroom';

  @override
  String get providerPresetExaDescription =>
      '通过 Exa MCP 搜索网页、提取内容并开展深入研究，支持语义搜索和关键词搜索。';

  @override
  String get providerPresetExaApiKeyHint => '请在 Exa 官网获取 API Key。';

  @override
  String get providerPresetTavilyDescription => '面向大语言模型优化的 AI 原生实时网络搜索引擎。';

  @override
  String get providerPresetTavilyApiKeyHint =>
      '请在 Tavily 官网获取 API Key，支持 ?tavilyApiKey= 或 Authorization: Bearer 请求头。';

  @override
  String get providerPresetJinaDescription =>
      '多模态 AI 服务，支持网页内容提取、Embedding 生成和搜索结果抓取。';

  @override
  String get providerPresetJinaApiKeyHint =>
      '请在 Jina AI 官网获取 API Key（Bearer Token）。';

  @override
  String get providerPresetFirecrawlDescription =>
      '网页抓取与内容提取服务，可将网页转换为清晰的 Markdown 或结构化数据。';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      '请在 Firecrawl 官网获取 API Key，也可免 Key 试用（免费版有使用限额）。';

  @override
  String get providerPresetZhipuDescription =>
      '智谱 AI 网页阅读器 MCP 服务，用于抓取和理解网页内容。';

  @override
  String get providerPresetZhipuApiKeyHint =>
      '请在智谱 AI 开放平台获取 API Key（Bearer Token）。';

  @override
  String get providerPresetBraveSearchDescription => '注重隐私的独立搜索引擎，提供高质量网页搜索结果。';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      '请在 Brave Search 官网获取 API Key。';

  @override
  String get providerPresetBochaDescription => '博查 AI 网页搜索服务，为中文网页提供智能搜索结果。';

  @override
  String get providerPresetBochaApiKeyHint =>
      '请在博查 AI 开放平台获取 API Key（Bearer Token）。';

  @override
  String get providerPresetQueritDescription => 'Querit AI 搜索服务，提供智能搜索和内容发现能力。';

  @override
  String get providerPresetQueritApiKeyHint =>
      '请在 Querit 官网获取 API Key（Bearer Token）。';

  @override
  String get providerPresetSearxngDescription => '自托管的元搜索引擎，可聚合多种搜索源并注重隐私保护。';

  @override
  String get providerPresetSearxngApiKeyHint =>
      '请设置 SearXNG 实例 URL（如 http://your-instance:8080）；API Key 可选。';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS 合成失败：$details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '\n原始错误：$details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout => '网络连接超时，请检查网络或 API 地址。';

  @override
  String get ttsErrorServerResponseTimeout => '服务器响应超时，请稍后重试。';

  @override
  String ttsErrorConnectionFailed(String details) {
    return '无法连接到服务器（$details）';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return '无法连接到服务器。Web 端常见原因：CORS 跨域限制或 API 地址不正确。$details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API 返回错误 (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return '连接超时，请检查网络$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return '接收超时，服务器响应过慢$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API 密钥无效或权限不足 (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return '请求过于频繁，请稍后重试 (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API 端点不存在 (HTTP $status): $body\n请检查 API 基础 URL 设置是否正确$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return '服务器内部错误 (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return '服务器返回错误 (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return '请求已取消$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return '无法连接到服务器。Web 端常见原因：CORS 跨域限制或 API 地址不正确。请检查供应商配置中的 API 地址是否正确，以及服务器是否允许跨域请求。$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return '网络错误：$details';
  }

  @override
  String get ttsErrorUnknownNetwork => '未知网络错误';

  @override
  String get ttsErrorNoResponseBody => '无响应体';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return '流式合成失败：$details';
  }

  @override
  String get mermaidEditorTitle => '图表制作';

  @override
  String get mermaidEditorModeEdit => '编辑模式';

  @override
  String get mermaidEditorModeSplit => '编辑+预览';

  @override
  String get mermaidEditorModePreview => '预览模式';

  @override
  String get mermaidEditorSwitchViewMode => '切换视图模式';

  @override
  String get mermaidEditorSaveToTextStorage => '保存到文本储存区';

  @override
  String get mermaidEditorEmptyChart => '图表内容为空，无法保存';

  @override
  String get mermaidEditorSaveChartTitle => '保存图表';

  @override
  String get mermaidEditorSaveFolderGuidance => '选择或创建文件夹保存 .mmd 图表文件';

  @override
  String get mermaidEditorFileNameHint => '输入文件名（自动添加 .mmd 后缀）';

  @override
  String get mermaidEditorEmptyFileName => '文件名不能为空';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return '已保存到文本储存区: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor => '交换预览和编辑面板';

  @override
  String get mermaidEditorCodeLabel => 'Mermaid 代码';

  @override
  String get mermaidEditorCodeHint => '输入 Mermaid 代码...';

  @override
  String get mermaidEditorSplitCodeLabel => '代码';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'SSE 连接失败（HTTP $statusCode：$statusText）';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'SSE 连接失败（HTTP $statusCode）';
  }

  @override
  String get sseConnectionUnavailable => 'SSE 连接失败：无法连接到服务器';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'HTTP 请求失败（HTTP $statusCode：$statusText）';
  }

  @override
  String get sseRequestFailed => '请求失败';

  @override
  String get sseNetworkRequestFailed => '网络请求失败';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return '网络请求失败（HTTP $statusCode：$statusText）';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return '网络请求失败（HTTP $statusCode）';
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
}
