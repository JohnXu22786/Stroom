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
  String get taskFlowOcrInputMissing => '找不到图片文件，请重新选择图片。';

  @override
  String get taskFlowOcrInputReadFailed => '无法读取图片文件，请检查文件访问权限后重试。';

  @override
  String get taskFlowOcrModelUnavailable =>
      '未配置可用的 OCR 模型，请在流程设置中选择 OCR 服务和模型。';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'OCR 请求大小预算（$size MiB）';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return '任务流图片输入上限（$size MiB）';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return '图片超过$limit，请缩小图片后重试。';
  }

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
  String get updateApkInstallerUnavailable => '未找到可安装 APK 的应用，请手动打开 APK 安装。';

  @override
  String get updateApkInstallPermissionDenied => '请在系统设置中允许 Stroom 安装未知来源应用。';

  @override
  String get updateRestartDialogTitle => '更新检测';

  @override
  String get updateRestartDialogBody => '检测到应用已更新，建议重启应用以确保稳定性。';

  @override
  String get updateRestartDialogLater => '稍后重启';

  @override
  String get updateRestartDialogNow => '立即重启';

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
  String get taskFlowCardRetryInfo =>
      '从头运行会重新下载并调用模型。可按启动时的原配置重试，或明确选择当前最新配置。要复用已完成步骤，请选择“从中断步骤继续”。';

  @override
  String get taskFlowCardRunLatest => '按最新配置运行';

  @override
  String get taskFlowCardRetryOriginal => '按原配置重试';

  @override
  String get taskFlowCardDeleteRecord => '删除任务流记录';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      '删除此运行记录将取消整个批次尚未完成的任务，并清除其子任务记录。确定删除？';

  @override
  String get taskFlowCardDeleteRunningConfirm => '任务流正在运行，删除将取消其中正在运行的任务。确定删除？';

  @override
  String get taskFlowCardDeleteRecordConfirm => '确定删除此任务流记录？其子任务记录也会一并删除。';

  @override
  String get taskFlowCardDeleteConfirm => '确定删除此任务流记录？';

  @override
  String get taskFlowCardSaveCancelStateError => '任务流取消状态无法保存，请重试删除';

  @override
  String get taskFlowCardStillRunning => '任务流取消后仍在运行';

  @override
  String get taskFlowCardSaveDeleteStateError => '任务流记录删除状态无法保存，请重试删除';

  @override
  String get taskFlowCardConfirm => '确定';

  @override
  String get taskFlowCardWaiting => '等待中';

  @override
  String get taskFlowCardRunning => '进行中';

  @override
  String get taskFlowCardPaused => '已暂停';

  @override
  String get taskFlowCardCompleted => '已完成';

  @override
  String get taskFlowCardFailed => '失败';

  @override
  String get taskFlowCardCanceled => '已取消';

  @override
  String get taskFlowCardInterrupted => '已中断';

  @override
  String get taskFlowCardSucceeded => '已跳过';

  @override
  String get taskFlowCardPause => '暂停流程';

  @override
  String get taskFlowCardResume => '继续流程';

  @override
  String get taskFlowCardResumeInterrupted => '从中断步骤继续';

  @override
  String get taskFlowCardCancel => '取消';

  @override
  String get unifiedTaskType => '任务类型';

  @override
  String get unifiedTaskCreatedAt => '创建时间';

  @override
  String get unifiedTaskCompletedAt => '完成时间';

  @override
  String get unifiedTaskResultStatus => '结果状态';

  @override
  String get unifiedTaskPartialResult => '部分结果，内容可能不完整';

  @override
  String get unifiedTaskErrorDetails => '错误详情';

  @override
  String get unifiedTaskViewErrorDetails => '查看错误详情';

  @override
  String get unifiedTaskOcrPerImage => '逐张识别';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return '第 $index 张';
  }

  @override
  String get unifiedTaskOcrPending => '待识别';

  @override
  String get unifiedTaskOcrRunning => '识别中';

  @override
  String get unifiedTaskCompleted => '已完成';

  @override
  String get unifiedTaskIncomplete => '结果不完整';

  @override
  String get unifiedTaskOcrFailed => '识别失败';

  @override
  String get unifiedTaskCancelled => '已取消';

  @override
  String get unifiedTaskWaitingStart => '等待开始...';

  @override
  String get unifiedTaskSteps => '执行步骤';

  @override
  String get unifiedTaskStartNow => '立即开始';

  @override
  String get unifiedTaskOpenFile => '打开文件';

  @override
  String get unifiedTaskRetrySave => '仅重试保存';

  @override
  String get unifiedTaskRetryPartialSave => '仅重试保存部分结果';

  @override
  String get unifiedTaskSavePartialResult => '保存部分结果';

  @override
  String get unifiedTaskRetry => '重试';

  @override
  String get unifiedTaskCancel => '取消';

  @override
  String get unifiedTaskDelete => '删除';

  @override
  String get unifiedTaskFormatUnsupported => '不支持此格式预览';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return '播放失败: $error';
  }

  @override
  String get unifiedTaskAudioFile => '音频文件';

  @override
  String get unifiedTaskPreviewLoadFailed => '无法加载预览';

  @override
  String get unifiedTaskUnknownSize => '未知大小';

  @override
  String get unifiedTaskUnnamedRecording => '未命名录音';

  @override
  String get unifiedTaskPause => '暂停';

  @override
  String get unifiedTaskClearTask => '清除任务';

  @override
  String get unifiedTaskContinue => '继续';

  @override
  String get unifiedTaskRemoveFromList => '从列表移除';

  @override
  String get unifiedTaskSynthesisText => '合成文本';

  @override
  String get unifiedTaskStatus => '状态';

  @override
  String get unifiedTaskDetails => '详情';

  @override
  String get unifiedTaskSynthesisError => '合成错误详情';

  @override
  String get unifiedTaskClose => '关闭';

  @override
  String get unifiedTaskRawRequestResponse => '原始请求与响应';

  @override
  String get unifiedTaskRawRequestBody => '原始请求体:';

  @override
  String get unifiedTaskRawResponseBody => '原始响应体:';

  @override
  String get commonJustNow => '刚刚';

  @override
  String commonMinutesAgo(Object count) {
    return '$count分钟前';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count小时前';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours时$minutes分';
  }

  @override
  String get unifiedTaskTypeOcr => '文字识别';

  @override
  String get unifiedTaskTypeAsr => '音频转写';

  @override
  String get unifiedTaskTypeAudioSeparation => '音频分离';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return '文字识别_$basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return '音频分离_$basename';
  }

  @override
  String get unifiedTaskTypeChat => '助手对话';

  @override
  String get unifiedTaskPlayAudio => '播放音频';

  @override
  String get unifiedTaskPauseAudio => '暂停音频';

  @override
  String get catcatchFlowActionNotStarted => '任务流操作未执行，请检查流程状态后重试';

  @override
  String catcatchFlowActionFailed(Object error) {
    return '任务流操作失败：$error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      '自动获取网页资源连续超时。请在此页面登录或设置用户脚本；检测到媒体资源后，点击“继续流程”。';

  @override
  String get browserRecoveryContinue => '继续流程';

  @override
  String get catcatchSkipped => '已跳过（无需处理）';

  @override
  String catCatchDetailMediaResources(Object count) {
    return '获取到$count个媒体资源';
  }

  @override
  String catCatchDetailResources(Object count) {
    return '获取到$count个资源';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return '浏览器中获取到$count个资源';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return '获取到$total个资源（播放列表$segments个分段）';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return '共$count个资源，请用户选择';
  }

  @override
  String get catCatchDetailAutoSelectFirst => '自动选择第1个结果，进入下载';

  @override
  String get catCatchDetailAutoSelectRemaining => '剩余1个结果，自动进入下载';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return '.$extension 格式无需转换，已跳过';
  }

  @override
  String get catCatchDetailSkipNoExtension => '. 格式无需转换，已跳过';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return '按照$duration时长筛选后剩余$remaining个结果（已排除$removed个不匹配的资源）';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return '按时长$duration筛选，$count个资源全部匹配';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '$count小时';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '$count分钟';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count秒';
  }

  @override
  String get catcatchRetryStep => '重试此步骤';

  @override
  String catcatchCollapseSegments(Object count) {
    return '收起 $count 个分片';
  }

  @override
  String catcatchShowSegments(Object count) {
    return '显示 $count 个分片';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '已选 $selected/$total 个资源';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '检测到 $count 个媒体资源';
  }

  @override
  String get catcatchFlowSelectOrCombine => '（选择一个资源或合并一组音视频）';

  @override
  String get catcatchSelectMultiple => '（点击选择，可多选）';

  @override
  String get catcatchWaitingForResources => '正在等待任务流资源';

  @override
  String catcatchDownloadSelected(Object count) {
    return '下载选中的 $count 个资源';
  }

  @override
  String get catcatchSelectResources => '请选择要下载的资源';

  @override
  String get catcatchPossibleSplit => '⚠ 疑似音视频分离';

  @override
  String get catcatchSplitExplanation =>
      '检测到此组资源可能是同一个视频的音频和视频分离的流，您可以选择合并音视频，或仅下载其中一种。';

  @override
  String get catcatchAudioStream => '🎵 音频流';

  @override
  String get catcatchVideoStream => '🎬 视频流';

  @override
  String get catcatchMergeAudioVideo => '合并音视频';

  @override
  String get catcatchVideoOnly => '仅视频';

  @override
  String get catcatchAudioOnly => '仅音频';

  @override
  String get catcatchSegmentsPlaylistPreview => '分片需通过播放列表预览';

  @override
  String get catcatchPreviewAudio => '预览音频';

  @override
  String get catcatchPreviewVideo => '预览视频';

  @override
  String catcatchDuration(Object duration) {
    return '时长: $duration';
  }

  @override
  String get catcatchSegment => '分片';

  @override
  String get catcatchPlaylist => '播放列表';

  @override
  String get catcatchFullVideo => '整片';

  @override
  String get catcatchSeparateTracks => '分轨';

  @override
  String get catcatchPreviewPlaylistOnly => '请通过播放列表预览';

  @override
  String get catcatchPreviewUnsupported => '不支持预览';

  @override
  String get catcatchUnknownFormat => '未知格式';

  @override
  String get catcatchNeedPlaylistProcessing => '需要处理播放列表';

  @override
  String get catcatchSpecialFormatDetected => '检测到特殊格式';

  @override
  String catcatchPlaylistInfo(Object format) {
    return '该资源是一个播放列表（$format），需要自动解析并下载所有分段后合并为可播放的视频文件。';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return '下载的文件格式为 $format，并不是标准的 MP4 格式。将使用内置的纯 Dart 转封装引擎转换为 MP4（TS/FLV/EV1 免外部依赖）。';
  }

  @override
  String get catcatchContinueBeforeConfirm => '请先继续流程，再确认格式处理';

  @override
  String get catcatchAutoProcess => '自动处理';

  @override
  String get catcatchKeepOriginalFormat => '保留原始格式';

  @override
  String get catcatchResumeSupported => '支持断点续传';

  @override
  String get catcatchResumeUnsupported => '该站点不支持断点续传';

  @override
  String get catcatchPauseDownload => '暂停下载';

  @override
  String get catcatchResumeDownload => '继续下载';

  @override
  String get catcatchRestartDownload => '重新下载';

  @override
  String get catcatchPendingFormatAction => '正在等待任务流资源';

  @override
  String get quitDialogTitle => '退出应用？';

  @override
  String quitDialogRunningTasks(Object count) {
    return '有 $count 个任务正在运行，退出将中断这些任务。确定要退出吗？';
  }

  @override
  String get quitDialogNoTasks => '确定要退出 Stroom 吗？';

  @override
  String get quitDialogCancel => '取消';

  @override
  String get quitDialogExit => '退出';

  @override
  String get searchPanelNewConversation => '新对话';

  @override
  String get searchPanelTitle => '搜索对话';

  @override
  String get searchPanelHint => '输入关键词...';

  @override
  String get searchPanelByTitle => '搜标题';

  @override
  String get searchPanelByContent => '搜内容';

  @override
  String searchPanelResults(Object count) {
    return '$count 个结果';
  }

  @override
  String get searchPanelPrompt => '输入关键词开始搜索';

  @override
  String get searchPanelNoResults => '没有找到匹配的对话';

  @override
  String get topicItemNew => '新话题';

  @override
  String get topicItemUnpin => '取消置顶';

  @override
  String get topicItemPin => '置顶';

  @override
  String get topicItemRename => '重命名';

  @override
  String get topicItemAutoName => '自动命名';

  @override
  String get topicItemDelete => '删除';

  @override
  String get galleryChoiceTitle => '选择图片来源';

  @override
  String get galleryChoiceDevice => '设备相册';

  @override
  String get galleryChoiceDeviceDescription => '浏览设备中的照片和视频';

  @override
  String get galleryChoiceApp => '应用相册';

  @override
  String get galleryChoiceAppDescription => '从应用内部相册选择';

  @override
  String get appMediaUnreadable => '无法读取文件';

  @override
  String appMediaLoadError(Object error) {
    return '加载文件失败：$error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return '清除 ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return '确定 ($count)';
  }

  @override
  String get appMediaConfirmSelection => '确定';

  @override
  String get appMediaEmptyFolder => '此文件夹为空';

  @override
  String get appMediaRoot => '返回根目录';

  @override
  String appMediaParentFolder(Object name) {
    return '返回: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '已选择 $count 个文件';
  }

  @override
  String get chatAlbumPickerTitle => '应用内相册';

  @override
  String get chatAlbumPickerEmpty => '暂无图片';

  @override
  String appAlbumPickerSelectedImages(num count) {
    return '已选择 $count 张图片';
  }

  @override
  String get chatFilePickerTitle => '选择文件';

  @override
  String get chatFilePickerTabText => '文本';

  @override
  String get chatFilePickerTabImages => '图片';

  @override
  String get chatFilePickerTabVideos => '视频';

  @override
  String get chatFilePickerTabAudio => '音频';

  @override
  String get chatFilePickerEmpty => '暂无文件';

  @override
  String get chatFilePickerLoadFailed => '加载失败';

  @override
  String get chatVideoPickerTitle => '选择应用内视频';

  @override
  String get chatVideoPickerEmpty => '暂无视频';

  @override
  String get imagePreviewCrop => '裁剪';

  @override
  String get imagePreviewEdit => '编辑';

  @override
  String get imagePreviewLoadFailed => '无法加载图片';

  @override
  String runningElapsed(Object elapsed) {
    return '已运行 $elapsed';
  }

  @override
  String get chatAttachmentFile => '传文件';

  @override
  String get chatAttachmentCamera => '拍照';

  @override
  String get chatAttachmentDeviceGallery => '设备相册';

  @override
  String get chatAttachmentDeviceFiles => '设备文件';

  @override
  String get chatAttachmentAppFiles => '应用内文件';

  @override
  String fileManagerTodayTime(Object time) {
    return '今天 $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return '昨天 $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days天前 $time';
  }

  @override
  String get markdownGenerating => '正在生成...';

  @override
  String get htmlPreview => '预览';

  @override
  String get htmlReturnToCard => '返回卡片';

  @override
  String get htmlGenerating => '正在生成中...';

  @override
  String get htmlFullscreen => '全屏查看';

  @override
  String get htmlViewCode => '查看代码';

  @override
  String get codeScrollToBottom => '滚动到底部';

  @override
  String get codeSave => '保存';

  @override
  String get codeDisableWrap => '取消换行';

  @override
  String get codeEnableWrap => '换行显示';

  @override
  String codeCopyFailed(Object error) {
    return '复制失败: $error';
  }

  @override
  String get codeCopied => '已复制';

  @override
  String get codeCopy => '复制';

  @override
  String get codeEmptySave => '代码为空，无法保存';

  @override
  String get codeSaveTitle => '保存代码';

  @override
  String codeSavedTo(Object path) {
    return '已保存到: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get fileManagerCopy => '复制';

  @override
  String get fileManagerMove => '移动';

  @override
  String get fileManagerRename => '重命名';

  @override
  String get fileManagerExport => '导出';

  @override
  String get fileManagerDelete => '删除';

  @override
  String get fileManagerAncestorFolders => '祖先文件夹';

  @override
  String get fileManagerRoot => '根目录';

  @override
  String fileManagerSelectedItems(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get fileManagerSelectAll => '全选';

  @override
  String get fileManagerRenameUndo => '上次批量重命名结果与撤销';

  @override
  String fileManagerSortBy(Object field) {
    return '排序（$field）';
  }

  @override
  String get fileManagerSortCreated => '按创建时间';

  @override
  String get fileManagerSortModified => '按修改时间';

  @override
  String get fileManagerSortName => '按文件名';

  @override
  String get fileManagerSortSize => '按大小';

  @override
  String get fileManagerListView => '列表视图';

  @override
  String get fileManagerThumbnailView => '缩略图视图';

  @override
  String get fileManagerCreateFolder => '创建文件夹';

  @override
  String get fileManagerRefresh => '刷新列表';

  @override
  String get fileManagerEmptyFolder => '此文件夹为空';

  @override
  String get fileManagerNoFiles => '暂无文件';

  @override
  String get fileManagerBackRoot => '返回根目录';

  @override
  String fileManagerBackFolder(Object name) {
    return '返回: $name';
  }

  @override
  String get fileManagerMultiSelect => '多选';

  @override
  String get fileManagerOpen => '打开';

  @override
  String get fileManagerPreview => '预览';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '$files 个文件, $folders 个子文件夹';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '$count 个子文件夹';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '$count 个文件';
  }

  @override
  String get fileManagerEmptyFolderLabel => '空文件夹';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return '文件 “$name.$format” 已存在';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return '重命名失败: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => '选择目标文件夹';

  @override
  String get fileManagerAlreadyAtDestination => '文件已在目标位置';

  @override
  String get fileManagerMoveNameConflict => '目标文件夹已存在同名文件，移动已取消';

  @override
  String fileManagerMoveFailed(Object error) {
    return '移动失败: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => '选择复制到的目标文件夹';

  @override
  String fileManagerCopyFailed(Object error) {
    return '复制失败: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => '确认删除';

  @override
  String get fileManagerDeleteFileConfirm => '确定要删除此文件吗？此操作不可恢复。';

  @override
  String get fileManagerCancel => '取消';

  @override
  String fileManagerDeleteFailed(Object error) {
    return '删除失败: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere => '文件夹已在目标位置，操作已取消';

  @override
  String get fileManagerFolderConflict => '所选文件夹在目标位置存在同名冲突或位于自身内部，操作已取消';

  @override
  String get fileManagerBatchDeleteTitle => '确认批量删除';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '确定要删除选中的 $count 项吗？此操作不可恢复。';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return '批量删除失败: $error';
  }

  @override
  String get fileManagerExportConflict => '所选文件与文件夹的导出路径冲突';

  @override
  String get fileManagerSelectedAlreadyThere => '所选文件已在目标位置，移动已取消';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return '批量移动失败: $error';
  }

  @override
  String get fileManagerCopyConflict => '所选文件中存在同名文件，复制已取消（请逐个复制）';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return '批量复制失败: $error';
  }

  @override
  String get fileManagerClosedError => '文件页面已关闭';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return '批量重命名失败：$error';
  }

  @override
  String get fileManagerFolderNameHint => '输入文件夹名称';

  @override
  String get fileManagerCreate => '创建';

  @override
  String get fileManagerFolderExists => '文件夹已存在';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return '创建文件夹失败: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return '文件夹 “$name” 创建成功';
  }

  @override
  String get fileManagerRenameFolderTitle => '重命名文件夹';

  @override
  String get fileManagerNewNameHint => '输入新名称';

  @override
  String get fileManagerTargetFolderConflict => '目标位置已存在同名文件夹，操作已取消';

  @override
  String get fileManagerMoveFolderTitle => '移动文件夹到…';

  @override
  String get fileManagerCopyFolderTitle => '复制文件夹到…';

  @override
  String get fileManagerFolderSelfConflict => '目标位置已存在同名文件夹或为文件夹自身，操作已取消';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return '确定要删除文件夹 “$name” 吗？其中的 $count 个文件也将被删除。';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '确定要删除空文件夹 “$name” 吗？';
  }

  @override
  String get fileManagerDeleteFolderTitle => '确认删除文件夹';

  @override
  String fileManagerRefreshFailed(Object error) {
    return '刷新失败: $error';
  }

  @override
  String get fileManagerRefreshed => '文件列表已刷新';

  @override
  String get fileManagerRenameFileTitle => '重命名文件';

  @override
  String get fileManagerFormat => '格式';

  @override
  String get fileManagerFolderAtDestination => '文件夹已在目标位置';

  @override
  String get folderPickerTitle => '选择文件夹';

  @override
  String get folderPickerExists => '文件夹已存在';

  @override
  String folderPickerCreateFailed(Object error) {
    return '创建文件夹失败: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return '刷新文件夹列表失败: $error';
  }

  @override
  String get folderPickerInstruction => '单击选中，双击进入查看子文件夹';

  @override
  String get folderPickerFileName => '文件名';

  @override
  String get folderPickerFileNameHint => '输入文件名';

  @override
  String get folderPickerBack => '返回上级';

  @override
  String folderPickerPath(Object path) {
    return '根目录 > $path';
  }

  @override
  String get folderPickerRoot => '根目录';

  @override
  String get folderPickerCurrentFolder => '当前文件夹';

  @override
  String get folderPickerSubfolders => '子文件夹';

  @override
  String get folderPickerExistingFolders => '现有文件夹';

  @override
  String get folderPickerCreateNew => '创建新文件夹';

  @override
  String get folderPickerFolderNameHint => '输入文件夹名称';

  @override
  String get folderPickerCancelCreate => '取消新建';

  @override
  String get folderPickerCancel => '取消';

  @override
  String get folderPickerConfirm => '确定';

  @override
  String batchRunReadFailed(Object error) {
    return '无法读取文件列表：$error';
  }

  @override
  String get batchRunPreparing => '准备中…';

  @override
  String get batchRunUndo => '撤销';

  @override
  String get batchRunRename => '重命名';

  @override
  String batchRunFailedAction(Object label) {
    return '未能执行$label';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '已$label $count 项';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label：成功 $completed 项，失败 $failed 项，剩余 $remaining 项';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return '失败：$id → $name';
  }

  @override
  String get batchRunReportCopied => '已复制执行报告';

  @override
  String get batchRunCopyFailed => '复制失败，请重试';

  @override
  String batchRunWorking(Object label) {
    return '正在$label…';
  }

  @override
  String get batchRunTitle => '批量重命名结果';

  @override
  String get batchRunStoppedRetain => '停止后会保留当前已完成的项目，可在结果页撤销。';

  @override
  String get batchRunFailedRemaining => '失败；后续项目未执行';

  @override
  String get batchRunUndoInfo => '撤销会恢复本次已成功项目的原名；后续列表变化时将拒绝撤销。';

  @override
  String get batchRunUncertain => '有项目状态无法确认，请检查文件列表；为避免覆盖，不提供自动撤销。';

  @override
  String get batchRunUndoing => '正在恢复原名，请稍候';

  @override
  String get batchRunStopping => '正在停止…';

  @override
  String get batchRunStopRemaining => '停止后续操作';

  @override
  String get batchRunCopyReport => '复制报告';

  @override
  String batchRunUndoRemaining(Object count) {
    return '继续撤销剩余 $count 项';
  }

  @override
  String get batchRunUndoCompleted => '撤销已完成改名';

  @override
  String get batchRunDone => '完成';

  @override
  String get codeEditorTitle => '编辑参数值';

  @override
  String get codeEditorFormat => '格式化';

  @override
  String get codeEditorCancel => '取消';

  @override
  String get codeEditorConfirm => '确定';

  @override
  String get codeEditorInvalidJson => 'JSON 格式有误，请修正后再保存';

  @override
  String get codeEditorParamPath => '参数名路径（请求时展开为嵌套 JSON）';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return '第 $line 行第 $column 列: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON 格式错误: $message';
  }

  @override
  String get codeEditorInvalidFormat => 'JSON 格式不正确';

  @override
  String get toolCallCompacted => '已压缩';

  @override
  String get mermaidSaveEmpty => 'Mermaid 代码为空，无法保存';

  @override
  String mermaidFolderLoadFailed(String error) {
    return '获取文件夹失败: $error';
  }

  @override
  String get mermaidSaveTitle => '保存 Mermaid 图表';

  @override
  String get mermaidSaveHint => '选择或创建文件夹保存 .mmd 文件';

  @override
  String get mermaidSaveFilenameHint => '输入文件名（自动添加 .mmd 后缀）';

  @override
  String get mermaidFilenameEmpty => '文件名不能为空';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return '已保存到文本储存区: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get mermaidPrepareEngine => '正在准备渲染引擎...';

  @override
  String get mermaidRetry => '重试';

  @override
  String get batchRuleEmpty => '不能为空';

  @override
  String get batchRuleNumber => '请输入数字';

  @override
  String get batchRulePositive => '请输入大于 0 的数字';

  @override
  String batchRuleMin(String min) {
    return '不能小于 $min';
  }

  @override
  String batchRuleMax(String max) {
    return '不能大于 $max';
  }

  @override
  String get batchRulePrefix => '前缀';

  @override
  String get batchRuleSuffix => '后缀';

  @override
  String get batchRuleStart => '起始';

  @override
  String get batchRuleStep => '步长';

  @override
  String get batchRuleDigits => '位数';

  @override
  String get batchRuleSeparator => '分隔符';

  @override
  String get batchRuleRestartFolder => '每个目录重新编号';

  @override
  String get batchRuleNumberHelp => '编号按预览顺序分配；排除项不占序号。步长可为负数或 0。';

  @override
  String get batchRuleFind => '查找内容';

  @override
  String get batchRuleReplace => '替换为（留空删除）';

  @override
  String get batchRuleCaseSensitive => '区分大小写';

  @override
  String get batchRuleRegex => '正则表达式';

  @override
  String get batchRuleFirstOnly => '仅替换首次匹配';

  @override
  String get batchRuleRegexHelp =>
      '捕获组：\$1、\$2；完整匹配：\$0；字面 \$：\$\$。例如 ^IMG_(\\d+)\$ → 照片_\$1';

  @override
  String get batchRuleFindRequired => '填写查找内容后生效。';

  @override
  String get batchRuleBeginning => '开头';

  @override
  String get batchRuleEnd => '结尾';

  @override
  String get batchRulePosition => '指定位置';

  @override
  String get batchRuleInsertText => '插入文本';

  @override
  String get batchRuleBeforeChar => '第 N 个字符前';

  @override
  String get batchRulePositionHelp => '位置从 1 开始；超过末尾时追加。组合 emoji 按一个字符计算。';

  @override
  String get batchRuleFromBeginning => '从开头';

  @override
  String get batchRuleFromEnd => '从结尾';

  @override
  String get batchRuleFromChar => '从第 N 个字符起';

  @override
  String get batchRuleCount => '数量';

  @override
  String get batchRuleDeleteHelp => '名称删空后需由后续插入规则补充，才能执行。';

  @override
  String get batchRuleUpper => '全大写';

  @override
  String get batchRuleLower => '全小写';

  @override
  String get batchRuleFirstUpper => '首字母大写';

  @override
  String get batchRuleTitleCase => '每词首字母大写';

  @override
  String get batchRuleTemplate => '新名称模板';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return '课程_${n}_$name';
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
    return '$name 原名 · $n 序号 · $folder 所在目录名\n$created 创建日期 · $modified 修改日期 · $ext 原扩展名\n日期格式 YYYY-MM-DD；缺少日期时会提示。模板替换整个基础名，扩展名仍自动保留。';
  }

  @override
  String get batchRuleTrim => '去掉首尾空白';

  @override
  String get batchRuleCollapseSpaces => '连续空白合并为一个空格';

  @override
  String get batchRuleActions => '规则操作';

  @override
  String get batchRuleDuplicate => '复制规则';

  @override
  String get batchRuleRemove => '删除规则';

  @override
  String get batchRuleMoveUp => '上移规则';

  @override
  String get batchRuleMoveDown => '下移规则';

  @override
  String get batchDlgSavePreset => '保存重命名方案';

  @override
  String get batchDlgPresetName => '方案名称';

  @override
  String get batchDlgPresetHint => '保存规则及顺序，不包含排除项或手动名称';

  @override
  String get batchDlgCancel => '取消';

  @override
  String get batchDlgSave => '保存';

  @override
  String get batchDlgOverwriteTitle => '覆盖已有方案？';

  @override
  String batchDlgOverwriteBody(String name) {
    return '将更新“$name”的规则。';
  }

  @override
  String get batchDlgOverwrite => '覆盖';

  @override
  String get batchDlgManagePresets => '管理方案';

  @override
  String get batchDlgNoPresets => '尚未保存方案';

  @override
  String get batchDlgDeletePreset => '删除方案';

  @override
  String get batchDlgDone => '完成';

  @override
  String get batchDlgEditName => '单独修改名称';

  @override
  String get batchDlgBaseName => '基础名称';

  @override
  String get batchDlgOverrideHelp => '此名称覆盖规则结果';

  @override
  String batchDlgExtensionRetained(String extension) {
    return '扩展名 .$extension 自动保留';
  }

  @override
  String get batchDlgConfirm => '确定';

  @override
  String get batchDlgHelp => '使用说明';

  @override
  String get batchDlgClose => '关闭';

  @override
  String get batchDlgLoadPreset => '加载方案（替换规则并清除手动名称）';

  @override
  String get batchDlgLoad => '加载方案';

  @override
  String get batchDlgSaving => '保存中…';

  @override
  String get batchDlgReset => '重置全部规则与参与项目';

  @override
  String get batchDlgRuleInstructions => '规则从上到下依次执行；可复制、移动或关闭。扩展名保持不变。';

  @override
  String get batchDlgSortName => '名称';

  @override
  String get batchDlgSortCreated => '创建时间';

  @override
  String get batchDlgSortModified => '修改时间';

  @override
  String get batchDlgSortSize => '大小';

  @override
  String get batchDlgAscending => '升序';

  @override
  String get batchDlgDescending => '降序';

  @override
  String get batchDlgFolderSort => '文件夹在前；同名按所在目录排序。';

  @override
  String get batchDlgAddRule => '＋ 添加规则';

  @override
  String get batchDlgMaxRules => '最多 50 条规则';

  @override
  String get batchDlgPreviewWorking => '正在计算预览，可继续修改规则或取消…';

  @override
  String get batchDlgSearch => '搜索原名、新名或所在目录';

  @override
  String get batchDlgFilterAll => '全部';

  @override
  String get batchDlgFilterChanged => '有更改';

  @override
  String get batchDlgFilterErrors => '有问题';

  @override
  String get batchDlgFilterUnchanged => '未变化';

  @override
  String get batchDlgFilterExcluded => '已排除';

  @override
  String get batchDlgParticipants => '选择参与项目';

  @override
  String get batchDlgIncludeAll => '全部参与';

  @override
  String get batchDlgOnlyFiles => '仅文件';

  @override
  String get batchDlgOnlyFolders => '仅文件夹';

  @override
  String get batchDlgExcludeAll => '全部排除';

  @override
  String get batchDlgScope => '参与范围';

  @override
  String get batchDlgCopyList => '复制清单';

  @override
  String get batchDlgConflictBlock => '同名冲突：阻止执行';

  @override
  String get batchDlgConflictSuffix => '同名冲突：追加 (2)、(3)…';

  @override
  String get batchDlgNoMatches => '没有符合筛选条件的项目';

  @override
  String get batchDlgRoot => '根目录';

  @override
  String get batchDlgFile => '文件';

  @override
  String get batchDlgFolder => '文件夹';

  @override
  String batchDlgTargetFolder(String folder) {
    return '目标目录：$folder';
  }

  @override
  String get batchDlgEditNameTooltip => '单独修改名称';

  @override
  String get batchDlgRestoreNameTooltip => '恢复规则生成的名称';

  @override
  String get batchDlgCopied => '已复制完整预览清单（CSV）';

  @override
  String get batchDlgCopyFailed => '复制失败，请重试';

  @override
  String get batchDlgHelpTitle => '批量重命名使用说明';

  @override
  String get batchDlgHelpDismiss => '知道了';

  @override
  String get batchDlgRulesTab => '规则';

  @override
  String batchDlgPreviewTab(String count) {
    return '预览（$count）';
  }

  @override
  String batchDlgRenameCount(String count) {
    return '重命名 $count 项';
  }

  @override
  String get batchDlgPresetLoadFailed => '暂时无法读取方案，仍可编辑和执行规则';

  @override
  String get batchDlgPreviewFailed => '预览计算失败，请调整规则后重试';

  @override
  String batchDlgSavedName(String name) {
    return '已保存方案：$name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get batchDlgPresetWriteFailed => '无法保存方案';

  @override
  String batchDlgDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get batchDlgSavePresetFallback => '保存方案';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return '预览 · $changes 项更改 · $conflicts 项问题 · $excluded 项排除';
  }

  @override
  String get batchDlgInvalidInput => '请修正规则中的输入；当前预览尚未采用无效输入。';

  @override
  String get batchDlgConflictError => '存在冲突或非法名称，无法应用。请调整规则。';

  @override
  String get batchDlgManualNameStatus => '手动名称';

  @override
  String get batchDlgPendingRename => '待重命名';

  @override
  String get batchDlgCsvHeader => '原路径,原名称,目标路径,状态';

  @override
  String get batchDlgHelpBody =>
      '1. 选择方案或启用规则，按需复制规则并调整上下顺序。\n\n2. 预览显示实际执行的名称。搜索与筛选只影响显示；取消勾选会排除该项并重新编号。可单独修改名称，或恢复为规则结果。\n\n3. 所有问题解决后才能执行。自动后缀只处理重名，不会覆盖其他文件。互换文件夹名称需要分批改名。\n\n4. 执行中可停止后续项目；当前项目会先完成。完成页显示结果，可撤销本次已完成的改名。列表发生后续变化时会阻止撤销。\n\n仅修改名称及目录路径，文件内容和扩展名保持不变。排除父目录自身的改名不会阻止已勾选子项改名；父目录改名时其内部路径仍会随之移动。';

  @override
  String batchDlgPreviewCount(String count) {
    return '预览（$count）';
  }

  @override
  String get batchBuiltinPhoto => '照片：日期与编号';

  @override
  String get batchBuiltinCourse => '课程：统一名称与编号';

  @override
  String get batchBuiltinDownloads => '下载文件：清理空白';

  @override
  String get taskListDetail => '详情';

  @override
  String get taskListOwnershipChecking => '正在确认任务归属';

  @override
  String get taskListOwnershipFailed => '任务流记录读取失败，操作暂不可用';

  @override
  String get taskListViewFlow => '查看任务流';

  @override
  String get taskListPause => '暂停';

  @override
  String get taskListClear => '清除任务';

  @override
  String get taskListResume => '继续';

  @override
  String get taskListRetry => '重试';

  @override
  String get taskListDismissError => '关闭错误信息';

  @override
  String get taskListRemove => '从列表移除';

  @override
  String get taskListSynthesisErrorTitle => '合成错误详情';

  @override
  String get taskListClose => '关闭';

  @override
  String get taskListOriginalExchange => '原始请求与响应';

  @override
  String get taskListOriginalRequest => '原始请求体:';

  @override
  String get taskListOriginalResponse => '原始响应体:';

  @override
  String get taskFlowIoTypeText => '文本';

  @override
  String get taskFlowIoTypeAudio => '音频';

  @override
  String get taskFlowIoTypeVideo => '视频';

  @override
  String get taskFlowIoTypeImage => '图片';

  @override
  String get taskFlowIoTypeLink => '链接';

  @override
  String get taskFlowIoTypeFile => '文件';

  @override
  String get taskFlowIoTypeAny => '任意';

  @override
  String get mermaidZoomOut => '缩小';

  @override
  String get mermaidZoomIn => '放大';

  @override
  String get mermaidFullscreen => '全屏';

  @override
  String get mermaidSaveButton => '保存';

  @override
  String get mermaidSourceButton => '查看源码';

  @override
  String get mermaidDiagramSemantic => '查看图表';

  @override
  String get taskFlowCardCatCatchDeletePersistError => '猫抓子任务删除状态无法保存，请重试';

  @override
  String get taskFlowCardSynthesisDeletePersistError => '合成子任务删除状态无法保存，请重试';

  @override
  String get taskFlowCardBackgroundDeletePersistError => '后台子任务删除状态无法保存，请重试';

  @override
  String get mathParseError => '数学解析错误';

  @override
  String get mermaidEmptyPlaceholder => '没有可渲染的 Mermaid 代码';

  @override
  String get mathClose => '关闭';

  @override
  String get mermaidLoadTimeout => 'Mermaid 加载超时：请检查网络连接后重试';

  @override
  String get mermaidCdnLoadFailed => 'Mermaid 加载失败：无法访问 cdn.jsdelivr.net';

  @override
  String get mermaidLoadingDiagram => '图表加载中...';

  @override
  String get mermaidEngineInitFailed => '图表渲染引擎初始化失败，请重试';

  @override
  String get mermaidPageTimeout => '页面加载超时，请重试';

  @override
  String get mermaidCodeLoadFailed => '图表代码加载失败，请重试';

  @override
  String mermaidPageLoadFailed(String description) {
    return '页面加载失败: $description';
  }

  @override
  String get mermaidLoadingEngine => '加载渲染引擎...';

  @override
  String get mermaidRenderErrorTitle => '渲染图表时出错';

  @override
  String get taskFlowOutputVideoAudioDownstream => '视频或音频（按下游筛选）';

  @override
  String get taskFlowOutputUnknown => '未知';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label已停止：成功 $completed 项，失败 $failed 项，未执行 $remaining 项';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Mermaid 渲染错误：$message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Mermaid 初始化错误：$message';
  }

  @override
  String get mermaidResourceError => 'Mermaid 图表中的资源加载失败。';

  @override
  String get taskFlowParamRecognitionModel => '识别模型';

  @override
  String get taskFlowParamSynthesisModel => '合成模型';

  @override
  String get taskFlowParamSaveFolder => '保存文件夹';

  @override
  String get taskFlowParamResourceSelection => '资源选择方式';

  @override
  String get taskFlowParamOutputType => '输出类型';

  @override
  String get taskFlowParamVideoFolder => '视频保存文件夹';

  @override
  String get taskFlowParamAudioFolder => '音频保存文件夹';

  @override
  String get taskFlowParamExpectedDuration => '预期时长';

  @override
  String get taskFlowParamVoice => '语音';

  @override
  String get taskFlowParamSpeechRate => '语速';

  @override
  String get taskFlowParamAssistant => '助手';

  @override
  String get taskFlowHintResourceSelection =>
      '手动模式由你选择；自动模式按既有规则确定选择；自动并询问会在唯一安全资源时自动选择，否则打开资源列表让你确认。';

  @override
  String get taskFlowHintOutputType =>
      '视频或音频可显式指定；跟随下游时按下一功能块的输入类型筛选资源。下游接受两种类型或没有下游时，两种类型都会保留。';

  @override
  String get taskFlowHintExpectedDuration => '按视频时长筛选，留空表示不筛选。';

  @override
  String get taskFlowHintVoice => '选择音色（选择后自动切换到对应模型）。';

  @override
  String get taskFlowUiUnsupportedBlockStep => '此功能块类型已不受支持，请替换或删除此步骤。';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return '下一步需要$requiredType。下载资源可输出视频或音频，请修改下一步或输出策略。';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source为任意类型，但“$block”需要明确的文本、链接、图片、音频、视频或文件类型。请修改输入类型、移动或替换功能块，或撤销更改。';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source为$actualType，但“$block”需要$requiredType。请修改输入类型、移动或替换功能块，或撤销更改。';
  }

  @override
  String get fileManagerSortFieldCreated => '创建时间';

  @override
  String get fileManagerSortFieldModified => '修改时间';

  @override
  String get fileManagerSortFieldName => '文件名';

  @override
  String get fileManagerSortFieldSize => '大小';

  @override
  String get fileManagerSortDateNewest => '新到旧';

  @override
  String get fileManagerSortDateOldest => '旧到新';

  @override
  String get fileManagerSortSizeLargest => '大到小';

  @override
  String get fileManagerSortSizeSmallest => '小到大';

  @override
  String get catcatchStatusRunning => '运行中';

  @override
  String get catcatchStatusCompleted => '已完成';

  @override
  String get catcatchStatusFailed => '失败';

  @override
  String get catcatchStatusPaused => '已暂停';

  @override
  String get catcatchStatusWaiting => '等待中';

  @override
  String get catcatchStepFetching => '获取网页内容';

  @override
  String get catcatchStepAnalyzing => '分析媒体资源';

  @override
  String get catcatchStepParsingPlaylist => '解析播放列表';

  @override
  String get catcatchStepFiltering => '按时长筛选';

  @override
  String get catcatchStepUserSelecting => '等待用户选择';

  @override
  String get catcatchStepDownloading => '下载';

  @override
  String get catcatchStepConverting => '转码/合并';

  @override
  String get catcatchStepSaving => '保存到本地';

  @override
  String get bgStepConnectServer => '连接服务器';

  @override
  String get bgStepUploadImage => '上传图片';

  @override
  String get bgStepWaitRecognition => '等待识别结果';

  @override
  String get bgStepParseResult => '解析结果';

  @override
  String get bgStepSaveFile => '保存文件';

  @override
  String get bgStepUploadAudio => '上传音频';

  @override
  String get bgStepTranscribing => '转写中';

  @override
  String get bgStepReceiveResult => '接收结果';

  @override
  String get bgStepSeparateAudio => '分离音频';

  @override
  String get bgStepSaveToFile => '保存到文件';

  @override
  String get bgStepSendRequest => '发送请求';

  @override
  String get bgStepWaitReply => '等待回复';

  @override
  String get fileManagerSortNameAscending => 'A 到 Z';

  @override
  String get fileManagerSortNameDescending => 'Z 到 A';

  @override
  String get taskFlowValidationNoSteps => '任务流没有步骤，请先添加功能块。';

  @override
  String get taskFlowValidationInputRequired => '请添加运行输入。';

  @override
  String get taskFlowValidationFlowRemoved => '任务流已删除，请重新选择。';

  @override
  String get taskFlowValidationInputTypeChanged => '初始输入类型已修改，请重新选择运行输入。';

  @override
  String get taskFlowValidationSnapshotMissing => '旧记录没有运行快照，请选择使用最新配置重试。';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      '助手模型未选择或不可用，请先在对话页选择模型或给助手设置默认模型。';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      '已保存的步骤文件不存在、为空或无法读取，请重新运行。';

  @override
  String get taskFlowValidationUnsupportedBlock => '功能块已不受支持，请替换或删除此步骤。';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return '下一步需要$requiredType。下载资源可输出音频或视频，请修改下一步或输出策略。';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '“$parameter”为必填项，请在“$block”设置中配置。';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return '旧版模型选择需要确认，请在“$block”设置中重新选择模型。';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return '模型未选择、已删除或供应商配置不可用，请在“$block”设置中重新选择模型并检查供应商地址和密钥。';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return '助手未选择或已删除，请在“$block”设置中重新选择助手。';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      '助手绑定的模型已删除或供应商配置不可用，请在助手设置中重新选择模型。';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return '资源选择策略或输出类型无效，请在“$block”设置中重新选择。';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return '输出类型无效，请在“$block”设置中重新选择。';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return '资源选择策略无效，请在“$block”设置中重新选择。';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return '第 $index 个输入：文件不存在、为空或无法读取，请重新选择文件。';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return '第 $index 个输入：请输入有效的 HTTP 或 HTTPS 链接。';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return '第 $index 个输入：$error';
  }

  @override
  String get batchRuleValidationMaxRules => '最多支持 50 条规则。';

  @override
  String get batchRuleValidationDigits => '编号位数应为 1–12。';

  @override
  String get batchRuleValidationNumberRange => '编号起始值和步长须在 ±999999999 以内。';

  @override
  String get batchRuleValidationReplacementLength => '替换规则过长。';

  @override
  String get batchRuleValidationRegex => '正则表达式无效。';

  @override
  String get batchRuleValidationDeleteIndex => '删除位置必须从 1 开始。';

  @override
  String get batchRuleValidationInsertLength => '插入文本过长。';

  @override
  String get batchRuleValidationTemplateNumber =>
      '模板编号设置无效：位数 1–12，起始和步长在 ±999999999 以内。';

  @override
  String get batchRuleValidationTemplateLength => '模板过长。';

  @override
  String get batchRuleValidationTemplateVariable => '未知模板变量或未闭合的大括号。';

  @override
  String get batchRuleTypeNumber => '编号';

  @override
  String get batchRuleTypeReplace => '替换';

  @override
  String get batchRuleTypeInsert => '插入文本';

  @override
  String get batchRuleTypeDelete => '删除字符';

  @override
  String get batchRuleTypeCase => '大小写转换';

  @override
  String get batchRuleTypeTemplate => '命名模板';

  @override
  String get batchRuleTypeCleanup => '清理空白';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return '第 $index 个输入：请输入文本或选择文件。';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return '第 $index 个输入：图片超过 20 MB，请选择较小的图片。';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return '第 $index 个输入：附件超过 10 MB，请选择较小的文件。';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return '第 $index 个输入：文件实际类型为$actualType，需要$requiredType，请重新选择文件。';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return '第 $index 个输入：助手对话不支持 SVG 图片附件，请转换为 PNG 或 JPEG。';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return '第 $index 个输入：助手对话不支持 $mime 图片附件，请转换为 PNG、JPEG、GIF 或 WebP。';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return '第 $index 个输入：助手对话不支持 $mime 音频附件，请转换为 MP3、WAV 或 M4A。';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return '第 $index 个输入：此助手的 Anthropic 对话格式不支持$type附件，请选择支持此媒体的助手。';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return '第 $index 个输入：此助手的 Anthropic 对话格式只支持图片和 PDF 附件，请选择支持此文件的助手。';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return '第 $index 个输入：助手对话图片无法压缩到 10 MB 以下，请选择较小图片。';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return '第 $index 个输入：文本附件不是有效的 UTF-8 编码，请转换后重试。';
  }

  @override
  String get assistantParamValueTypeString => '字符串';

  @override
  String get assistantParamValueTypeNumber => '数字';

  @override
  String get assistantParamValueTypeBoolean => '布尔值';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields => '供应商名称、API 地址和密钥均为必填项。';

  @override
  String get providerJsonSizePositive => '请求 JSON 大小必须是大于 0 的 MiB 数值。';

  @override
  String get providerCustomParamRequired => '自定义参数的名称和值不能为空。';

  @override
  String providerParamNameInvalid(String name) {
    return '参数名格式不正确（点号分段不能为空）：$name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return '参数已存在：$name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return '参数“$name”的默认值不是合法 JSON：$value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return '参数“$name”的数值选项不能为空。';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return '参数“$name”的值不是合法数字：$value';
  }

  @override
  String get providerReasoningIncomplete => '请先完整填写推理开关，其他推理参数才能生效。';

  @override
  String providerReasoningError(String error) {
    return '推理参数错误：$error';
  }

  @override
  String providerParamNameConflict(String name) {
    return '推理参数与自定义参数重名：$name';
  }

  @override
  String get providerMaxTokensMissing => '已启用最大输出 Token 数，但未填写数值。';

  @override
  String get providerMaxTokensPositive => '最大输出 Token 数必须为正整数。';

  @override
  String get providerSeedInteger => '随机种子必须为整数。';

  @override
  String get providerNotConfigured => '未设置';

  @override
  String get providerAudioChunkingTitle => '音频切块';

  @override
  String get providerAudioChunkingHint => '智能切块会分析音频和候选切点，优先在句末切分；各片段不会重叠。';

  @override
  String get providerChunkingMode => '切块方式';

  @override
  String get providerChunkNone => '不切块';

  @override
  String get providerChunkSmart => '智能切块（推荐）';

  @override
  String get providerChunkFixedDuration => '固定时长切块';

  @override
  String get providerChunkFixedSize => '固定大小切块';

  @override
  String get providerCompressionTitle => '压缩编码';

  @override
  String get providerCompressionHint =>
      '启用后，通用兜底会先压缩完整 WAV；若编码文件或请求体仍超限，再切分源 PCM 并逐块编码。';

  @override
  String get providerCompressionMode => '压缩方式';

  @override
  String get providerCompressionNone => '无（原样发送）';

  @override
  String get providerCompressionAdpcm => 'ADPCM（约 4 倍压缩）';

  @override
  String get providerCompressionFlac => 'FLAC（无损，约 2 倍）';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM，4:1 有损压缩。纯 Dart 实现，音质适合语音转写。';

  @override
  String get providerCompressionFlacDescription =>
      'FLAC 无损压缩，纯 Dart 实现，体积约缩小一半。';

  @override
  String get providerCompressionWavDescription => '不压缩，以 WAV 文件原样发送。';

  @override
  String get providerLlmParams => 'LLM 参数';

  @override
  String get providerEnabledParamsHelp => '开启的参数将作为默认值发送到 API 请求中。';

  @override
  String get providerTemperatureLabel => '温度';

  @override
  String get providerTemperatureHelp => '控制输出的随机性，值越高越有创造性。';

  @override
  String get providerTopPHelp => '核采样参数，控制词汇选择的累积概率。';

  @override
  String get providerFrequencyPenaltyLabel => '频率惩罚';

  @override
  String get providerFrequencyPenaltyHelp => '减少重复词，负值会增加重复。';

  @override
  String get providerPresencePenaltyLabel => '存在惩罚';

  @override
  String get providerPresencePenaltyHelp => '鼓励讨论新话题，负值会鼓励重复话题。';

  @override
  String get providerMaxOutputTokensLabel => '最大输出 Token 数';

  @override
  String providerOptionalExample(String example) {
    return '可选，例如 $example';
  }

  @override
  String get providerResponseTokensHelp => '每次响应最多生成的 Token 数。';

  @override
  String get providerSeedLabel => '随机种子';

  @override
  String get providerSeedHelp => '设置后可使输出结果可复现。';

  @override
  String get providerChunkSmartDescription =>
      '分析音频和候选切点，优先在句末或长静音处切分且不重叠。默认最短 20 秒、目标 45 秒、最长 60 秒。仅由通用兜底使用；压缩切块仅支持 PCM WAV。';

  @override
  String get providerChunkDurationDescription =>
      '每 N 秒切分一次（默认 60 秒）。方式简单，但可能截断语句。仅由通用兜底使用；压缩切块仅支持 PCM WAV。';

  @override
  String get providerChunkSizeDescription =>
      '先按音频数据大小初步切分，再根据编码文件和请求体大小细分。仅由通用兜底使用；压缩切块仅支持 PCM WAV。';

  @override
  String get providerChunkNoneDescription => '不切块。完整压缩后仍超出限制时，将拒绝该文件。';

  @override
  String get providerNameLabel => '供应商名称';

  @override
  String get providerNameHint => '输入供应商名称';

  @override
  String get providerApiUrlLabel => 'API 地址';

  @override
  String get providerApiUrlHint => '输入完整的 API 端点地址';

  @override
  String providerApiKeyHint(String hint) {
    return '提示：$hint';
  }

  @override
  String get providerEndpointTypeLabel => '端点类型';

  @override
  String get providerEndpointOpenAi => '兼容 OpenAI（Chat Completions）';

  @override
  String get providerEndpointAnthropic => 'Anthropic 格式（Messages API）';

  @override
  String get providerAnthropicEndpointHelp =>
      '使用官方 Anthropic Messages API 格式（x-api-key 请求头）。API 地址示例：https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      '使用官方 OpenAI Chat Completions 兼容格式（Bearer 请求头）。API 地址示例：https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => '请求 JSON 大小默认值';

  @override
  String get providerUseAppDefault => '留空则使用应用默认值';

  @override
  String get providerModelJsonBudgetHelp =>
      '模型可单独设置覆盖值；此处和模型均未设置时，使用 20 MiB 默认值。';

  @override
  String get providerRequestParamsHelp =>
      '请求会使用供应商和模型中所有已启用的参数。若参数重名，则以模型参数值为准。';

  @override
  String get providerUploadSettings => '上传设置';

  @override
  String get providerUploadMethodHelp => '不同供应商支持的音频上传方式和大小限制不同。';

  @override
  String get providerUploadMethod => '上传方式';

  @override
  String get providerMultipart => 'Multipart（通用）';

  @override
  String get providerUrlUpload => 'URL（链接）';

  @override
  String get providerMaxUploadSize => '最大上传大小';

  @override
  String get providerFallbackStrategy => '兜底策略';

  @override
  String get providerFallbackMethod => '兜底方式';

  @override
  String get providerPreprocessing => '音频预处理';

  @override
  String get providerPreprocessingHelp => '降低音频文件大小，不影响转写准确率。';

  @override
  String get providerPreprocessingMethod => '预处理方式';

  @override
  String get providerUploadMultipartHelp =>
      '直接以 multipart/form-data 上传。请求体包括音频、表单字段和分段边界。';

  @override
  String get providerUploadBase64Help =>
      '以 JSON 发送 Base64，可绕过部分供应商对 multipart 的专属限制。Base64 膨胀和 JSON 字段均计入上传上限。';

  @override
  String get providerUploadUrlHelp =>
      '提供公网 URL，由供应商下载。支持较大的文件（例如 Together AI 的 1 GB）。';

  @override
  String get providerUploadBudgetHelp =>
      '此值用于触发原始音频兜底并限制最终请求体。应用会分别检查原始音频、编码文件和上传大小。Multipart 计入表单字段和边界；Base64 JSON 计入编码膨胀和字段。默认 25 MB 与 OpenAI 音频 API 上限一致。';

  @override
  String get providerFallbackTriggerHelp =>
      '原始音频或完整请求体超出上限时触发。特定兜底（Base64）优先于通用兜底（压缩/切块）。';

  @override
  String get providerFallbackNone => '无（直接拒绝）';

  @override
  String get providerFallbackSpecific => '特定兜底（Base64）';

  @override
  String get providerFallbackGeneric => '通用兜底（压缩/切块）';

  @override
  String get providerFallbackAll => '全部尝试（推荐）';

  @override
  String get providerFallbackSpecificHelp =>
      '尝试 Base64 JSON。只有计入 Base64 膨胀和 JSON 字段后的请求体未超限时才发送。';

  @override
  String get providerFallbackGenericHelp =>
      '若已启用压缩，则先压缩完整 WAV。仍超限且已启用切块时，再切分源 PCM 并逐块编码。仅支持 PCM WAV。';

  @override
  String get providerFallbackAllHelp =>
      '先尝试符合请求体上限的 Base64；然后在启用压缩时压缩完整 WAV。若仍超限且已启用切块，则切分源 PCM 并逐块编码。仅支持 PCM WAV。';

  @override
  String get providerFallbackRejectHelp => '文件超出限制时直接拒绝，不尝试兜底。';

  @override
  String get providerPreprocessNone => '无';

  @override
  String get providerPreprocessResample => 'WAV 优化（16 kHz 单声道）';

  @override
  String get providerPreprocessResampleHelp =>
      '重采样至 16 kHz 并混合为单声道。文件大小约缩小 4–6 倍，基本不影响转写准确率。';

  @override
  String get providerPreprocessNoneHelp => '不进行预处理，原样发送。';

  @override
  String get assistantDefaultsScopeHelp =>
      '默认模型和工具仅用于在此助手下新建的话题。现有话题保留各自设置。工具结果截断适用于全部话题。';

  @override
  String get assistantDefaultModelTitle => '默认模型';

  @override
  String get assistantDefaultModelHelp => '新话题使用的模型；留空则不指定默认模型。';

  @override
  String get assistantNoDefault => '暂不设置';

  @override
  String get assistantNoModelsAvailable => '暂无可用模型，请在设置中配置 LLM 供应商。';

  @override
  String get assistantDefaultToolsTitle => '默认启用工具';

  @override
  String get assistantDisabledToolsHelp => '已关闭的工具不会在新话题中自动启用。';

  @override
  String get assistantUnconfiguredToolsHelp => '尚未配置默认工具；新话题将自动启用全部工具。';

  @override
  String get assistantEnableAll => '全部启用';

  @override
  String get assistantDisableAll => '全部关闭';

  @override
  String get assistantNoToolsAvailable => '暂无可用工具';

  @override
  String get assistantTruncateToolOutput => '工具结果截断';

  @override
  String get assistantTruncateToolOutputHelp =>
      '发送给模型前，单个工具结果的最大字符数。适用于此助手下的全部话题。';

  @override
  String get assistantEnableTruncation => '启用截断';

  @override
  String assistantTruncatedTo(String count) {
    return '超长结果将截断至 $count 个字符';
  }

  @override
  String get assistantSendFullResult => '完整发送（仍受 50 KB 存储上限约束）';

  @override
  String get assistantMaxCharacters => '最大字符数';

  @override
  String get assistantCharactersNotTokens => '单位：字符（不是 token）';

  @override
  String assistantDefaultCharacterCount(String count) {
    return '默认值：$count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return '有效范围：$minimum–$maximum 个字符';
  }

  @override
  String get assistantNewConversationPreview => '新建话题效果';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '已启用 $enabled / $total 个';
  }

  @override
  String get assistantAllToolsAutoEnabled => '全部自动启用（未配置）';

  @override
  String get assistantMoreActions => '更多操作';

  @override
  String get assistantChooseEmoji => '选择表情';

  @override
  String get assistantNameLabel => '助手名称';

  @override
  String get assistantDescriptionOptional => '描述（可选）';

  @override
  String get assistantSelectionTitle => '选择助手';

  @override
  String get assistantMarketTooltip => '助手市场';

  @override
  String get assistantDefaultPrompt => '你是一个有帮助的AI助手。请用中文回答用户的问题。';

  @override
  String get assistantCreateNew => '新建助手';

  @override
  String get assistantEmptyState => '暂无助手，请先创建。';

  @override
  String get assistantCreate => '创建';

  @override
  String get assistantReorderHint => '长按并拖动即可调整助手顺序';

  @override
  String get assistantNewNameHint => '输入助手名称';

  @override
  String get assistantNewDescriptionHint => '简要描述此助手的功能';

  @override
  String get assistantDeleteTitle => '删除助手';

  @override
  String assistantDeleteConfirmation(String name) {
    return '确定要删除助手“$name”吗？此操作无法撤销。';
  }

  @override
  String get assistantEditTitle => '编辑助手';

  @override
  String get assistantBasicTab => '基本设置';

  @override
  String get assistantParametersTab => '参数设置';

  @override
  String get assistantDefaultsTab => '默认设置';

  @override
  String get assistantAddCustomParameter => '添加自定义参数';

  @override
  String get assistantEditCustomParameter => '编辑自定义参数';

  @override
  String get assistantParameterName => '参数名';

  @override
  String get assistantParameterNameHint => '例如 top_k 或 provider.only';

  @override
  String get assistantParameterNameInvalid => '参数名格式不正确（点号分段不能为空）';

  @override
  String get assistantParameterType => '类型';

  @override
  String get assistantValue => '值';

  @override
  String get assistantTrueFalseHint => 'true 或 false';

  @override
  String get assistantNumberHint => '输入数字';

  @override
  String assistantJsonHint(String example) {
    return '例如：$example';
  }

  @override
  String get assistantValueHint => '输入值';

  @override
  String get assistantCancel => '取消';

  @override
  String get assistantSave => '保存';

  @override
  String get assistantParamOverrideHelp => '启用时助手参数会覆盖模型参数；关闭时使用模型参数。';

  @override
  String get assistantTemperature => '温度 (Temperature)';

  @override
  String get assistantMaxTokens => '最大 Token 数';

  @override
  String get assistantMaxToolCalls => '工具调用上限';

  @override
  String assistantRounds(String count) {
    return '$count 轮';
  }

  @override
  String get assistantUnlimited => '无限制';

  @override
  String get assistantStreamOutput => '流式输出';

  @override
  String get assistantFrequencyPenalty => '频率惩罚';

  @override
  String get assistantPresencePenalty => '存在惩罚';

  @override
  String get assistantRandomSeed => '随机种子';

  @override
  String get assistantNotSet => '未设置';

  @override
  String get assistantSeedValue => '种子值';

  @override
  String get assistantIntegerSeedHint => '输入整数种子';

  @override
  String get assistantWebSearch => '联网搜索';

  @override
  String get assistantAddParameter => '添加参数';

  @override
  String get assistantNoCustomParameters => '暂无自定义参数';

  @override
  String get assistantRoundsLabel => '轮数';

  @override
  String get modelCreateTitle => '添加模型';

  @override
  String get modelEditTitle => '编辑模型';

  @override
  String get modelDiscardTitle => '放弃修改？';

  @override
  String get modelDiscardBody => '当前有未保存的修改，确定要放弃吗？';

  @override
  String get modelNameLabel => '模型名称';

  @override
  String get modelNameHint => '输入显示名称（可选）';

  @override
  String get modelIdLabel => '模型 ID';

  @override
  String modelIdExample(String id) {
    return '例如 $id';
  }

  @override
  String get modelIdRequired => '模型 ID 为必填项。';

  @override
  String get modelCustomParamRequired => '自定义参数的参数名和默认值不能为空。';

  @override
  String modelParamDuplicate(String name) {
    return '参数已存在：$name';
  }

  @override
  String modelParamReserved(String name) {
    return '不能使用保留的 OCR 参数名：$name';
  }

  @override
  String get modelParamName => '参数名';

  @override
  String get modelParamDefaultValue => '默认参数值';

  @override
  String get modelParamDelete => '删除参数';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return '参数“$name”的默认值不是合法 JSON：$value';
  }

  @override
  String get modelAddParameter => '添加参数';

  @override
  String get modelNoCustomParams => '暂无自定义参数';

  @override
  String get modelBasicSettings => '基本设置';

  @override
  String get modelDiscardCancel => '取消';

  @override
  String get modelSave => '保存';

  @override
  String get modelUnsavedMaxTokens => '最大输出 Token 数已启用但未填写。';

  @override
  String get modelMaxTokensPositive => '最大输出 Token 数必须为正整数。';

  @override
  String get modelSeedInteger => '随机种子必须为整数。';

  @override
  String get modelContextLengthRequired => '上下文长度为必填项。';

  @override
  String get modelContextLengthPositive => '上下文长度必须为正整数。';

  @override
  String get modelAsrLanguageCode => '语言代码（Language）';

  @override
  String get modelAsrLanguageHint => '例如 zh、en、ja';

  @override
  String get modelAsrLanguageHelp => 'ISO-639-1 语言代码；留空则由模型自动检测。';

  @override
  String get modelTemperature => '温度';

  @override
  String get modelTemperatureHelp => '控制输出的随机性，建议使用较低的值。';

  @override
  String get modelAsrPrompt => '提示词';

  @override
  String get modelAsrPromptHint => '输入上下文提示词（可选）';

  @override
  String get modelAsrPromptHelp => '提供上下文以提高转写准确性，例如专业术语列表。';

  @override
  String get modelAsrParams => 'ASR 参数';

  @override
  String get modelEnabledParamsHelp => '开启的参数将作为默认值发送到 API 请求中。';

  @override
  String get modelAsrResponseFormat => '响应格式';

  @override
  String get modelAsrResponseHelp => '转写结果的返回格式。';

  @override
  String get modelAsrTimestampGranularity => '时间戳粒度';

  @override
  String get modelAsrVerboseHelp => '仅在 response_format 为 verbose_json 时生效。';

  @override
  String get modelNoTrim => '不裁切';

  @override
  String get modelAudioTrimTitle => '音频裁切';

  @override
  String get modelAudioTrimHelp => '选择音频裁切方式。';

  @override
  String get modelDeleteTrimPreset => '删除裁切预设';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return '确定要删除裁切预设“$name”吗？';
  }

  @override
  String get modelAddTrimPreset => '添加自定义裁切';

  @override
  String get modelPlayTestAudio => '播放测试音频';

  @override
  String get modelPlayingTestAudio => '播放中...';

  @override
  String get modelParamExists => '该参数已存在';

  @override
  String get asrModelIdExample => '例如 whisper-1';

  @override
  String get asrPromptLabel => '提示词';

  @override
  String get asrResponseFormatJson => 'json – JSON 格式';

  @override
  String get asrResponseFormatText => 'text – 纯文本';

  @override
  String get asrResponseFormatSrt => 'srt – 字幕';

  @override
  String get asrResponseFormatVtt => 'vtt – 字幕';

  @override
  String get asrResponseFormatVerbose => 'verbose_json – 详细 JSON（含时间戳）';

  @override
  String get asrVerboseTimestampHelp => '选择 verbose_json 后可启用下方时间戳粒度选项。';

  @override
  String get asrTimestampSegment => 'segment – 段落级';

  @override
  String get asrTimestampWord => 'word – 单词级';

  @override
  String get asrWordTimestampHelp => '单词级时间戳的准确性可能低于段落级。';

  @override
  String get reasoningAddOptionValue => '添加选项值';

  @override
  String get reasoningEditOptionValue => '编辑选项值';

  @override
  String get reasoningOptionExample => '例如 low、medium、high';

  @override
  String get reasoningOptionSelectionHelp =>
      '点按选项块可选中或取消。选中的值会发送；拖动可排序。供应商提供的值不能删除，但可以取消选中来隐藏。';

  @override
  String get reasoningAddOption => '添加选项';

  @override
  String get reasoningCurrentProvider => '当前：供应商';

  @override
  String get reasoningCurrentModel => '当前：模型自定义';

  @override
  String get reasoningAddEffortValue => '添加推理力度值';

  @override
  String get reasoningEffortExample => '例如 max、ultra、deep';

  @override
  String get reasoningAddToggle => '添加推理开关';

  @override
  String get reasoningToggle => '推理开关';

  @override
  String get reasoningResetParameter => '还原此参数';

  @override
  String get reasoningDisableToggle => '停用推理开关';

  @override
  String get reasoningEnableToggle => '启用推理开关';

  @override
  String reasoningParameterNameSource(String source) {
    return '参数名（$source）';
  }

  @override
  String get reasoningNameExample => '例如 thinking.type、reasoning';

  @override
  String get reasoningBooleanHelp => '布尔参数无需配置值；聊天面板提供开关。';

  @override
  String get reasoningOnValue => '开启时的值';

  @override
  String get reasoningOnExample => '例如 enabled、true';

  @override
  String get reasoningOffValue => '关闭时的值';

  @override
  String get reasoningOffExample => '例如 disabled、false';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return '开启时发送“$onValue”，关闭时发送“$offValue”。';
  }

  @override
  String get reasoningAddEffort => '添加推理力度';

  @override
  String get reasoningFillToggleFirst => '请先完整填写推理开关';

  @override
  String get reasoningFillToggleBeforeEffort => '请先完整填写推理开关，再配置推理力度。';

  @override
  String get reasoningAddValue => '添加值';

  @override
  String get reasoningJsonValue => 'JSON 值';

  @override
  String reasoningJsonExample(String example) {
    return '例如 $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      '点按选项块可选中或取消。选中的值会显示在聊天推理面板；拖动可排序。供应商提供的值不能删除，但可以隐藏。';

  @override
  String get reasoningAddParameter => '添加推理参数';

  @override
  String get reasoningToggleIncomplete => '请先完整填写推理开关，再配置推理力度。';

  @override
  String get llmContextLength => '上下文长度';

  @override
  String get llmContextHint => '输入上下文长度';

  @override
  String get llmContextHelp => '模型的最大上下文窗口大小（Token 数）。';

  @override
  String get llmReasoningParams => '推理参数';

  @override
  String get llmReasoningHelp =>
      '配置聊天推理参数。推理开关用于设置参数名和开关值；可添加、排序推理力度选项，并选择显示在聊天面板中的值。打开本页时会同步供应商提供的值。这些设置控制模型参数；聊天面板中的推理开关独立管理。';

  @override
  String get llmAddReasoningParam => '添加推理参数';

  @override
  String get llmCustomEndpointType => '自定义端点类型';

  @override
  String get llmInheritEndpointType => '关闭时使用供应商设置的端点类型。';

  @override
  String get llmEndpointType => '端点类型';

  @override
  String get llmEndpointOpenAi => '兼容 OpenAI（Chat Completions）';

  @override
  String get llmEndpointAnthropic => 'Anthropic 格式（Messages API）';

  @override
  String get llmEndpointHelp => '端点类型必须与供应商 API 地址匹配。更改后，此模型的新对话会使用相应格式。';

  @override
  String get llmTopPHelp => '核采样参数，用于控制词汇选择的累积概率。';

  @override
  String get llmFrequencyPenaltyLabel => '频率惩罚';

  @override
  String get llmFrequencyPenaltyHelp => '减少重复，负值会增加重复。';

  @override
  String get llmPresencePenaltyLabel => '存在惩罚';

  @override
  String get llmPresencePenaltyHelp => '鼓励讨论新话题，负值会鼓励重复话题。';

  @override
  String get llmMaxTokensHint => '可选，例如 4096';

  @override
  String get llmTokensPerResponse => '每次响应最多生成的 Token 数。';

  @override
  String get llmSeedLabel => '随机种子（Seed）';

  @override
  String get llmSeedHint => '可选，例如 42';

  @override
  String get llmSeedHelp => '设置后可使输出结果可复现。';

  @override
  String get llmInheritedCustomHelp => '供应商已配置的自定义参数会显示在此处，并在每次打开页面时同步。';

  @override
  String get llmBooleanParamHelp => '布尔类型无需配置参数值。';

  @override
  String get modelContextReq => '上下文长度为必填项。';

  @override
  String get modelContextPositive => '上下文长度必须为正整数。';

  @override
  String modelParamNameInvalid(String name) {
    return '参数名格式不正确（点号分段不能为空）：$name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return '参数“$name”的$valueLabel必须是有限数字：$value';
  }

  @override
  String get modelReasoningIncomplete => '请先完整填写推理开关，其他推理参数才能生效。';

  @override
  String get modelReasoningOptionsRequired => '推理参数必须至少添加一个选项值。';

  @override
  String modelReasoningError(String error) {
    return '推理参数错误：$error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return '推理参数重名：$name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return '推理参数与自定义参数重名：$name';
  }

  @override
  String get modelSeedRequired => '随机种子已启用但未填写。';

  @override
  String get ocrParamsTitle => 'OCR 参数';

  @override
  String get ocrParamsHelp =>
      '使用兼容 OpenAI 的视觉 Chat Completions 格式。以下参数均为可选；未填写或未启用的参数不会发送。供应商特有参数可在下方添加（需接口支持）。';

  @override
  String get ocrRequestSizeOverride => '请求 JSON 大小覆盖值';

  @override
  String get ocrInheritProvider => '留空则继承供应商设置';

  @override
  String get ocrBudgetDefault => '留空时继承供应商设置；供应商也未设置时使用 20 MiB 默认值。';

  @override
  String ocrBudgetValue(String size) {
    return '留空时继承供应商设置（$size MiB）；供应商也未设置时使用 20 MiB 默认值。';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return '裁切$direction $seconds 秒';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return '裁切开头 $seconds 秒';
  }

  @override
  String get audioTrimNone => '不裁切音频';

  @override
  String get trimNameLabel => '裁切方式名称 *';

  @override
  String get trimNameHint => '例如静音裁切';

  @override
  String get trimDurationLabel => '裁切时长（秒）*';

  @override
  String get trimDurationHint => '例如 0.123';

  @override
  String get trimNameAndDurationRequired => '名称和时长为必填项。';

  @override
  String get trimDurationInvalid => '请输入有效的正数时长。';

  @override
  String get testAudioHostMissing => '尚未配置 Host。';

  @override
  String get testAudioKeyMissing => '尚未配置 Key。';

  @override
  String testAudioContentTypeError(String contentType) {
    return '响应 Content-Type 为 $contentType，不是音频数据。';
  }

  @override
  String get testAudioEmpty => '服务器返回了空音频数据。';

  @override
  String testAudioTimeoutConnection(String details) {
    return '连接超时，请检查网络。$details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return '接收超时，服务器响应过慢。$details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return '请求已取消。$details';
  }

  @override
  String testAudioNetworkError(String message) {
    return '网络错误：$message';
  }

  @override
  String get testAudioNoBody => '无响应体';

  @override
  String testAudioCorsHelp(String details) {
    return '无法连接到服务器。Web 端可能因 CORS 限制或 API 地址错误导致；请检查供应商 API 地址及服务器跨域设置。$details';
  }

  @override
  String get trimModelNameHint =>
      '用于显示和识别的易读名称，例如“GPT-4o Mini TTS”。同一供应商下的模型可用名称区分。';

  @override
  String get trimModelIdHelp =>
      'API 调用使用的唯一标识符，例如“gpt-4o-mini-tts”。必须与供应商提供的模型 ID 一致。';

  @override
  String get ttsVoiceRangeTitle => '音量范围';

  @override
  String get ttsMinVolume => '最小音量';

  @override
  String get ttsMaxVolume => '最大音量';

  @override
  String get ttsSpeedRangeTitle => '语速范围';

  @override
  String get ttsMinSpeed => '最小语速';

  @override
  String get ttsMaxSpeed => '最大语速';

  @override
  String get ttsMaxAudioLength => '单次最长音频字数 *';

  @override
  String get ttsAudioLengthHint => '例如 1000';

  @override
  String get ttsNoVoices => '暂无音色，点击进入编辑';

  @override
  String get ttsInstructionSupported => '模型是否支持 instruction 参数';

  @override
  String get ttsInstructionHelp => '启用后可在 TTS 请求中附加语气、情绪、语速等指令描述。';

  @override
  String get ttsStreamSupported => '模型是否支持流式输出';

  @override
  String get ttsStreamHelp => '启用后此模型可用于需要流式输出的场景；请先确认模型支持流式输出。';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return '参数“$name”的值必须是 true 或 false：$value';
  }

  @override
  String get ttsMaxAudioLengthRequired => '单次最长音频字数为必填项，请输入大于 0 的整数。';

  @override
  String get asrLanguageExample => '例如 zh、en、ja';

  @override
  String get llmReasoningFullHelp =>
      '推理开关控制是否发送推理参数，并允许设置参数名和开关值。推理力度参数只有一个，可选择值并拖动排序；选中的值会显示在聊天推理面板中。可在下方添加其他推理参数。参数名支持点号嵌套，例如 thinking.type 会转换为嵌套 JSON 对象。打开本页时会同步供应商配置的推理参数。此处开关控制模型参数；聊天中的推理开关独立控制。';

  @override
  String get llmTemperatureHelp => '控制输出的随机性，值越高越有创造性。';

  @override
  String get llmBooleanValueHelp => '布尔类型无需配置参数值。';

  @override
  String get reasoningDisableEffort => '停用推理力度';

  @override
  String get reasoningEnableEffort => '启用推理力度';

  @override
  String get ocrJsonSizePositive => '请求 JSON 大小必须是大于 0 的 MiB 数值。';

  @override
  String ttsRangePair(String kind) {
    return '最小和最大$kind必须同时填写，或同时留空。';
  }

  @override
  String get ttsEditTrimTitle => '编辑自定义裁切';

  @override
  String ttsVoicesCount(String count) {
    return '音色 ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return '在请求格式中生成：$syntax';
  }

  @override
  String get mcpServerNameRequired => '请输入 MCP 服务器名称。';

  @override
  String get mcpStdioCommandRequired => 'stdio 模式需要指定命令。';

  @override
  String get mcpSseUrlRequired => 'SSE 模式需要指定 URL。';

  @override
  String get mcpEditServerTitle => '编辑 MCP 服务器';

  @override
  String get mcpCreateServerTitle => '新建 MCP 服务器';

  @override
  String get mcpUnsavedChangesTitle => '未保存的更改';

  @override
  String get mcpUnsavedChangesConfirm => '有未保存的更改，确定要放弃吗？';

  @override
  String get mcpTransportType => '传输方式';

  @override
  String get mcpServerName => '服务器名称';

  @override
  String get mcpServerNameHint => '输入 MCP 服务器名称';

  @override
  String get mcpCommand => '命令';

  @override
  String get mcpCommandExample => '例如：npx';

  @override
  String get mcpArguments => '参数';

  @override
  String get mcpArgumentsHint =>
      '用逗号分隔参数，例如：-y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => '例如：http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'API 密钥';

  @override
  String get mcpApiKeyHint => '输入 API Key（可选）';

  @override
  String get mcpShowKey => '显示密钥';

  @override
  String get mcpHideKey => '隐藏密钥';

  @override
  String get mcpDescriptionHint => '输入此 MCP 服务器的描述信息（可选）';

  @override
  String get mcpStdioDescription =>
      'stdio 会在本地启动子进程作为 MCP 服务器，并通过标准输入/输出通信。适用于本地工具。';

  @override
  String get mcpSseDescription => 'SSE 通过 HTTP SSE 连接远程 MCP 服务器。适用于远程服务。';

  @override
  String get mcpLocalStdio => '本地 (stdio)';

  @override
  String get mcpRemoteSse => '远程 (SSE)';

  @override
  String get mcpSaving => '保存中…';

  @override
  String get providerTestSafetyNote =>
      '此测试会向对应服务发送真实请求。MCP 仅调用只读的 tools/list；HTTP 和网页搜索会执行一次查询。Todo 默认读取清单；为保护当前数据，请省略 todos 参数或将其设为 null。';

  @override
  String get providerDeleteConfigTitle => '删除配置';

  @override
  String get providerDeleteConfigConfirm => '确定要删除此供应商配置及其所有模型吗？';

  @override
  String get providerCreateGroup => '新建组别';

  @override
  String get providerEditGroup => '编辑组别';

  @override
  String get providerGroupName => '组别名称';

  @override
  String get providerGroupNameExists => '组别名称已存在。';

  @override
  String get providerDeleteGroup => '删除组别';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return '删除“$groupName”后，其中的配置会移到“其他 MCP 服务”。';
  }

  @override
  String get providerMoveToGroup => '移动到组别';

  @override
  String get providerUnnamed => '（未命名）';

  @override
  String get providerHttpSearch => 'HTTP 搜索';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP 工具：$url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return '本地 (stdio)：$command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return '远程 (SSE)：$url';
  }

  @override
  String get providerServices => '服务配置';

  @override
  String get providerServicesDescription => '按组管理远程连接、本地 stdio 与 HTTP 搜索';

  @override
  String get providerCreateGroupAction => '新建组别';

  @override
  String get providerGroupEmpty => '此组暂无配置，点击“添加”加入内容。';

  @override
  String get providerBuiltinTools => '内置工具';

  @override
  String get providerBuiltinToolsDescription => 'Stroom 提供的本地工具接口；网页搜索归入对应服务组。';

  @override
  String get providerBuiltinToolInterface => '内置工具接口';

  @override
  String get providerViewInterface => '查看接口';

  @override
  String get providerConfigTitle => '配置';

  @override
  String get providerNotFound => '供应商未找到';

  @override
  String get providerConfigurationHeading => '供应商配置';

  @override
  String get providerBuiltinWebSearchEmpty =>
      '内置网络搜索支持 Google、Bing 和百度，模型调用名为 web_search。';

  @override
  String get providerNoConfigsAdd => '暂无供应商配置，请点击“添加”创建。';

  @override
  String get providerNoHost => '(未设置 Host)';

  @override
  String get providerServicesAndTools => '服务与工具';

  @override
  String get providerManageServicesDescription =>
      '管理 MCP 服务器、HTTP 搜索和 Stroom 内置工具。';

  @override
  String get providerNoServices => '还没有服务配置';

  @override
  String get providerAddServiceDescription =>
      '添加 MCP 服务或 HTTP 搜索接口，连接后即可在助手中使用。';

  @override
  String get providerAddService => '添加服务';

  @override
  String get providerBuiltinBadge => '内置';

  @override
  String get providerBuiltinTtsName => 'TTS供应商';

  @override
  String get providerBuiltinLlmName => 'LLM供应商';

  @override
  String get providerBuiltinOcrName => 'OCR供应商';

  @override
  String get providerBuiltinAsrName => '音频转写供应商';

  @override
  String get providerBuiltinMcpName => 'MCP供应商';

  @override
  String get providerBuiltinSearchGroupName => '搜索';

  @override
  String get providerBuiltinMcpServicesGroupName => '其他 MCP 服务';

  @override
  String get providerConnectivityTest => '连通性测试';

  @override
  String get providerMoveGroupTooltip => '移动到组别';

  @override
  String get providerDeleteTooltip => '删除配置';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 项内容',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => '组别操作';

  @override
  String get providerEditGroupAction => '编辑组别';

  @override
  String get providerDeleteGroupAction => '删除组别';

  @override
  String get providerAddItem => '添加内容';

  @override
  String get providerMcpMasterLabel => 'MCP 服务器';

  @override
  String get providerMcpMasterDescription => '控制 MCP 服务器与内置搜索工具在助手和对话中的可用性。';

  @override
  String get providerEnabled => '已启用';

  @override
  String get providerDisabled => '已停用';

  @override
  String get providerEditSettings => '编辑供应商设置';

  @override
  String get providerModelList => '模型列表';

  @override
  String get providerNoModels => '暂无模型';

  @override
  String get providerDeleteModel => '删除模型';

  @override
  String get providerDeleteModelConfirm => '确定要删除此模型吗？';

  @override
  String get providerEditConfig => '编辑配置';

  @override
  String providerCreateNamedConfig(String entryName) {
    return '新建$entryName配置';
  }

  @override
  String get toolHttpSearchType => '接入类型：HTTP 搜索';

  @override
  String toolInterface(String name) {
    return '工具接口：$name';
  }

  @override
  String get toolParameterDefinitions => '参数定义';

  @override
  String get toolHttpAddress => 'HTTP 接口地址';

  @override
  String get toolInvalidHttpUrl => '请输入有效的 HTTP 或 HTTPS 地址。';

  @override
  String get toolBuiltinType => '接入类型：Stroom 内置工具';

  @override
  String get toolBuiltinEnableHelp => '是否在助手中启用，由该助手的默认工具设置管理。';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return '模型 ID：$modelId';
  }

  @override
  String get providerValueNotSet => '（未设置）';

  @override
  String get providerApiKeyInputHint => '输入 API 密钥';

  @override
  String get providerSettingsTitle => '供应商配置';

  @override
  String get providerBasicInfoTab => '基本信息';

  @override
  String get providerParameterSettingsTab => '参数设置';

  @override
  String get providerOptionValuesReorderHelp => '选项值（长按把手拖拽排序）';

  @override
  String providerOptionIndexLabel(String index) {
    return '选项 $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return '如 $example';
  }

  @override
  String get providerDeleteOptionTooltip => '删除选项';

  @override
  String get providerAddOption => '添加选项';

  @override
  String get providerAddCustomParam => '添加参数';

  @override
  String get providerNoCustomParams => '暂无自定义参数';

  @override
  String get providerParamNameLabel => '参数名';

  @override
  String get providerParamDefaultValueLabel => '默认参数值';

  @override
  String get providerBooleanParamNoValue => '布尔类型无需配置参数值，聊天面板提供开/关切换。';

  @override
  String get providerReasoningParamsHeading => '推理参数';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return '推理开关控制聊天页面中推理功能的开启和关闭，由您定义参数名和对应的开/关值。推理力度参数最多配置一个，参数名必填，选项值可选；仅填参数名时，参数值由模型配置提供。您还可以通过底部按钮添加额外的推理参数。参数名支持点号嵌套，例如 $parameterName 会展开为 $jsonExample。';
  }

  @override
  String get providerAddReasoningParam => '添加推理参数';

  @override
  String get providerAddReasoningToggle => '添加推理开关';

  @override
  String get providerReasoningToggle => '推理开关';

  @override
  String get providerDeleteReasoningToggle => '删除推理开关';

  @override
  String providerParamNameHint(String examples) {
    return '如 $examples';
  }

  @override
  String get providerReasoningBooleanHelp => '布尔类型无需配置参数值，聊天面板提供开/关切换。';

  @override
  String get providerToggleOnValueLabel => '开启时值';

  @override
  String get providerToggleOffValueLabel => '关闭时值';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return '推理开关打开时发送「$onValue」，关闭时发送「$offValue」。';
  }

  @override
  String get providerAddReasoningEffort => '添加推理力度';

  @override
  String get providerDeleteReasoningEffort => '删除推理力度参数';

  @override
  String get providerReasoningEffortLockedHint => '请先完整填写推理开关后再配置推理力度。';

  @override
  String get providerJsonValueLabel => 'JSON 值';

  @override
  String get providerReasoningOptionsHelp =>
      '选项值（可选，仅填参数名时参数值由模型配置提供；长按把手拖拽排序）';

  @override
  String get providerParamNameNestedLabel => '参数名（支持点号嵌套）';

  @override
  String get providerToggleEffortPrerequisite => '请先完整填写推理开关后再配置推理力度。';

  @override
  String get providerToggleRequiredHint => '请先填写推理开关';

  @override
  String get providerDeleteCustomParam => '删除参数';

  @override
  String get modelSaveSuccess => '模型已保存';

  @override
  String get modelSaving => '保存中…';

  @override
  String modelOriginalError(String error) {
    return '原始错误：$error';
  }

  @override
  String get paramTypeStringLabel => '字符串';

  @override
  String get paramTypeNumberLabel => '数字';

  @override
  String get paramTypeBooleanLabel => '布尔';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return '不支持的类型：$type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return '参数“$name”使用了不支持的类型“$type”，请替换为支持的类型或删除该参数后再保存。';
  }

  @override
  String get paramTypeStringHint => '例如: cheerful';

  @override
  String get paramTypeNumberHint => '例如: 0.8';

  @override
  String get paramTypeBooleanHint => '例如: true';

  @override
  String get paramTypeJsonHint => '例如: ';

  @override
  String get ankiPageTitle => 'Anki闪卡';

  @override
  String get ankiStatsTooltip => '学习统计';

  @override
  String get ankiBrowseCardsTooltip => '浏览卡片';

  @override
  String get ankiStatsTotalCards => '总卡片数';

  @override
  String get ankiStatsNewCards => '待学习';

  @override
  String get ankiStatsLearning => '学习中';

  @override
  String get ankiStatsDueForReview => '待复习';

  @override
  String get ankiStatsReviewHistory => '历史复习次数';

  @override
  String get ankiStatsLearningProgress => '学习进度';

  @override
  String get ankiStatsReviewRate => '复习率';

  @override
  String get ankiBrowserSearchHint => '搜索卡片...';

  @override
  String get ankiBrowserEmpty => '无卡片';

  @override
  String get ankiSyncTooltip => 'AnkiWeb 同步';

  @override
  String get ankiNewDeckTooltip => '新建牌组';

  @override
  String ankiDeckLoadError(String error) {
    return '加载失败: $error';
  }

  @override
  String get ankiEmptyDecksTitle => '还没有牌组';

  @override
  String get ankiEmptyDecksDescription => '创建一个牌组开始学习';

  @override
  String get ankiNewDeckTitle => '新建牌组';

  @override
  String get ankiDeckNameHint => '牌组名称';

  @override
  String get ankiCreateDeck => '创建';

  @override
  String get ankiRenameDeck => '重命名';

  @override
  String get ankiConfirm => '确定';

  @override
  String get ankiDeleteDeckTitle => '删除牌组';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '确定删除“$deckName”及其所有卡片吗？';
  }

  @override
  String get ankiAddCardTitle => '添加卡片';

  @override
  String get ankiNoteTypeLabel => '笔记类型';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return '正文 (用 $clozeSyntax 标记挖空)';
  }

  @override
  String get ankiFrontQuestionHint => '正面 (问题)';

  @override
  String get ankiBackExtraLabel => '背面/额外';

  @override
  String get ankiTagsLabel => '标签 (空格分隔)';

  @override
  String get ankiTagsHint => '例如: 数学 物理';

  @override
  String get ankiAdd => '添加';

  @override
  String get ankiStatNew => '新';

  @override
  String get ankiStatLearning => '学';

  @override
  String get ankiStatReview => '复习';

  @override
  String get ankiAddCardAction => '添加卡片';

  @override
  String get ankiRenameAction => '重命名';

  @override
  String get ankiDeleteAction => '删除';

  @override
  String get ankiNoCardContent => '(无内容)';

  @override
  String get ankiStudy => '学习';

  @override
  String get ankiWhiteboardTooltip => '白板';

  @override
  String get ankiFrontLabel => '正面';

  @override
  String get ankiBackLabel => '背面';

  @override
  String get ankiShowAnswer => '显示答案';

  @override
  String get ankiRatingAgain => '忘记';

  @override
  String get ankiRatingHard => '困难';

  @override
  String get ankiRatingGood => '良好';

  @override
  String get ankiRatingEasy => '简单';

  @override
  String get ankiNoCardsToStudy => '当前没有待学习的卡片';

  @override
  String get ankiNoCardsHint => '你可以添加新卡片或稍后再来';

  @override
  String get ankiBack => '返回';

  @override
  String get ankiSyncPageTitle => 'Anki 同步';

  @override
  String get ankiSyncChooseMode => '选择同步方式';

  @override
  String get ankiSyncModeHelp => '登录状态按服务分别保存。切换方式不会合并或覆盖数据。';

  @override
  String get ankiSyncSelfHostedMode => '自建服务器';

  @override
  String get ankiSyncServerAddress => '服务器地址';

  @override
  String get ankiSyncServerHelp =>
      '自建远程服务器需使用 HTTPS；本机地址可使用 HTTP。服务器需支持 Anki sync v10，证书验证默认开启。';

  @override
  String get ankiSyncCustomCaTitle => '自定义 CA 证书（可选）';

  @override
  String get ankiSyncCustomCaHelp => '仅在服务器使用自签名证书时填写';

  @override
  String get ankiSyncOfficialHelp =>
      '使用官方 AnkiWeb 同步服务。密码只在登录时发送，不会保存在 Stroom。';

  @override
  String ankiSyncConnected(String service) {
    return '已连接 $service';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return '未连接 $service';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return '登录$service';
  }

  @override
  String get ankiSyncCheckServerStatus => '检查服务器状态';

  @override
  String get ankiSyncLogout => '登出';

  @override
  String get ankiSyncBothWays => '双向同步';

  @override
  String get ankiSyncOverwriteServer => '用本地数据覆盖服务器';

  @override
  String get ankiSyncReplaceLocal => '用服务器数据替换本地';

  @override
  String get ankiSyncHelp =>
      '双向同步会合并 collection 的增量变更并传输媒体文件；结构戳不一致时，请选择完整上传或下载。完整下载失败会尝试恢复原 collection 和媒体目录。';

  @override
  String get ankiSyncStatusRestored => '已恢复安全保存的登录状态';

  @override
  String get ankiSyncStatusReadSavedSessionFailed => '无法读取已保存的登录状态，请重新登录';

  @override
  String get ankiSyncInvalidServerUrl =>
      '服务器地址须为 HTTPS URL；仅本机 loopback 地址可使用 HTTP，且不能包含用户名、密码或 query 参数';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return '设置未保存：$error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged => '服务器地址已更改，请重新登录后继续';

  @override
  String get ankiSyncStatusVerifyingLogin => '正在验证登录…';

  @override
  String get ankiSyncStatusLoginSuccess => '登录成功。密码未保存，同步密钥已加密保存。';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      '登录成功，但无法安全保存同步密钥；关闭页面后需要重新登录。';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => '登录 AnkiWeb';

  @override
  String get ankiSyncLoginSelfHosted => '登录自建服务器';

  @override
  String get ankiSyncEmailOrUsername => '邮箱 / 用户名';

  @override
  String get ankiSyncEmailOrUsernameRequired => '请输入邮箱或用户名';

  @override
  String get ankiSyncPassword => '密码';

  @override
  String get ankiSyncPasswordRequired => '请输入密码';

  @override
  String get ankiSyncLogin => '登录';

  @override
  String get ankiSyncStatusPreparingServerSettings => '正在准备服务器设置…';

  @override
  String get ankiSyncStatusReadingCollection => '正在读取服务器 collection 状态…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty => '连接成功，服务器 collection 为空';

  @override
  String get ankiSyncStatusConnectedStatusRead => '连接成功，服务器状态已读取';

  @override
  String get ankiSyncStatusUpgradeClient => '此服务器要求升级同步客户端';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return '状态检查失败：$error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => '正在准备上传设置…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle => '用本地 collection 覆盖服务器？';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      '服务器上的 collection 将被本地数据完整替换。Stroom 会先保留一份本地数据库备份。\n\n随后仍会按服务器媒体清单双向同步文件。';

  @override
  String get ankiSyncOverwriteServerAction => '覆盖服务器';

  @override
  String get ankiSyncStatusBackingUpUploading => '正在备份并上传 collection…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return '服务器已接受本地 collection，媒体同步完成：上传 $uploaded 个，下载 $downloaded 个，删除 $deleted 个。$backup请重新检查服务器状态。';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return '\n本地备份：$path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      '服务器 collection 已替换，但媒体同步未完成：';

  @override
  String get ankiSyncStatusUploadFailed => '上传失败：';

  @override
  String get ankiSyncStatusPreparingDownload => '正在准备下载设置…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle => '用服务器 collection 替换本地？';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      '本地 collection 将被服务器数据替换。Stroom 会先保留一份本地数据库备份。\n\n随后会用服务器媒体替换本地媒体并下载缺失文件。若任一步失败或应用中途退出，Stroom 会在下次打开牌组前恢复本地 collection 和媒体。';

  @override
  String get ankiSyncReplaceLocalAction => '替换本地数据';

  @override
  String get ankiSyncStatusDownloadingValidating => '正在下载并验证 collection…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return '本地 collection 已替换，SQLite 检查通过；媒体同步完成：下载 $downloaded 个，上传 $uploaded 个，删除 $deleted 个。$backup请重新检查服务器状态。';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get ankiSyncStatusPreparingSync => '正在准备同步…';

  @override
  String get ankiSyncStatusMergingChanges => '正在合并 collection 变更…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'Collection 增量合并完成，正在同步媒体文件…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '新增/更新 $notes 个笔记、$cards 张卡片、$reviews 条复习记录';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges => 'collection 没有待合并变更';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return '双向同步完成：$collection；媒体上传 $uploaded 个、下载 $downloaded 个、删除 $deleted 个。';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'Collection 已合并，但媒体同步未完成：';

  @override
  String get ankiSyncStatusSyncIncomplete => '同步未完成：';

  @override
  String get ankiSyncStatusClearingLogin => '正在清除登录状态…';

  @override
  String get ankiSyncStatusLoggedOut => '已登出，安全存储中的同步密钥已删除';

  @override
  String get ankiSyncStatusClearLoginFailed => '无法清除已保存的登录状态';

  @override
  String get ankiSyncStatusOperationIncomplete => '操作未完成，请检查安全存储、网络和服务器地址';

  @override
  String get ankiSyncUnknown => '未知';

  @override
  String get ankiSyncServerCollectionEmpty => '服务器 collection 为空';

  @override
  String get ankiSyncServerCollectionAvailable => '服务器 collection 可用';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return '结构版本戳 $schema · USN $usn · 修改时间 $modified';
  }

  @override
  String get asrPageTitle => '音频转写';

  @override
  String get clear => '清空';

  @override
  String get configure => '去配置';

  @override
  String get asrModel => '识别模型';

  @override
  String get reselectModel => '请重新选择模型';

  @override
  String get selectAsrModel => '选择识别模型';

  @override
  String get enterPublicAudioUrl => '输入公网音频链接';

  @override
  String get recordingSelection => '录音选择';

  @override
  String get audioFiles => '音频文件';

  @override
  String get noAudioSelected => '暂未选择音频文件';

  @override
  String get supportedAudioFormats => '支持 wav、mp3、m4a、ogg 等常见音频格式';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 个音频文件',
      one: '已选择 $count 个音频文件',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 个音频',
      one: '已选 $count 个音频',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => '重新选择';

  @override
  String get asrUrlLabel => 'URL  |  公网链接';

  @override
  String get asrErrorDetails => '查看详细错误';

  @override
  String get asrResultSaved => '识别结果已保存';

  @override
  String get asrWorking => '识别中...';

  @override
  String get asrStart => '开始识别';

  @override
  String get saveTo => '保存至';

  @override
  String get rootFolder => '根目录';

  @override
  String get chooseSaveFolder => '选择保存文件夹';

  @override
  String get linkAlreadyAdded => '该链接已在列表中';

  @override
  String get chooseAudioSource => '选择音频来源';

  @override
  String get inAppRecordings => '应用内录音';

  @override
  String get chooseGeneratedRecordings => '从已生成的录音中选择';

  @override
  String get systemAudioFiles => '系统音频文件';

  @override
  String get chooseDeviceAudioFiles => '从设备文件中选择';

  @override
  String get cannotReadAudioFile => '无法读取音频文件';

  @override
  String chooseAudioFileFailed(String details) {
    return '选择音频文件失败: $details';
  }

  @override
  String get chooseInAppRecording => '选择应用内录音';

  @override
  String get noRecordings => '暂无录音';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds秒',
      one: '$seconds秒',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider => '请先在设置中配置音频转写供应商和模型';

  @override
  String get asrModelUnavailable => '原识别模型已失效或无法确认，请重新选择识别模型';

  @override
  String get asrUrlProviderRemoveFiles => '当前供应商使用 URL 上传方式，请移除本地音频文件后重试';

  @override
  String get asrFileProviderRemoveUrls => '当前供应商使用文件上传方式，不支持链接转写，请移除链接后重试';

  @override
  String asrTaskStartFailed(String details) {
    return '任务启动失败: $details';
  }

  @override
  String get asrInvalidUrl => '无效链接，必须以 http:// 或 https:// 开头';

  @override
  String get asrEnterAudioUrl => '输入音频链接';

  @override
  String get asrUrlProviderHelp => '当前供应商使用 URL 上传方式，请输入公网音频链接（http/https）。';

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get ttsPageTitle => '音频';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个音频文件',
      one: '已导入 $count 个音频文件',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return '导入失败: $details';
  }

  @override
  String get ttsFileReadFailed => '文件数据读取失败';

  @override
  String get ttsExportAudioFile => '导出音频文件';

  @override
  String ttsExportedTo(String path) {
    return '已导出到: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return '导出失败: $details';
  }

  @override
  String get ttsConfirmRegenerate => '确认重新生成';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return '确定要重新生成音频 “$fileName” 吗？';
  }

  @override
  String get ttsRegenerateOverwrite => '重新生成后将覆盖原音频文件。';

  @override
  String get ttsRegenerate => '确认重新生成';

  @override
  String ttsCopiedFailed(String details) {
    return '复制失败: $details';
  }

  @override
  String get ttsChooseExportFolder => '选择导出目录';

  @override
  String get ttsExportAudio => '导出音频';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导出 $count 个文件',
      one: '已导出 $count 个文件',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => '文件夹导出';

  @override
  String get ttsWebFolderExportHelp => '浏览器无法选择导出目录，将下载保留文件夹层级的 ZIP 文件。';

  @override
  String get ttsDownloadZip => '下载 ZIP 文件';

  @override
  String get ttsExportAudioFolder => '导出音频文件夹';

  @override
  String get ttsRecord => '录音';

  @override
  String get ttsImport => '导入';

  @override
  String get ttsPlay => '播放';

  @override
  String get ttsExportLocal => '导出到本地';

  @override
  String get ttsRegenerateQuestion => '重新生成';

  @override
  String get ttsNeedsProvider => '请先在设置中配置语音合成供应商和模型';

  @override
  String get ttsAddedToTasks => '已添加到任务列表，后台生成中…';

  @override
  String get ttsCreateTitle => '语音合成';

  @override
  String get ttsOriginalTitle => '录音标题';

  @override
  String get ttsUseOriginalTitle => '使用原标题';

  @override
  String get ttsAudioFileNameHint => '保存的音频文件名（可选）';

  @override
  String get ttsTextToConvert => '转换文本';

  @override
  String get ttsSpeechContent => '语音内容';

  @override
  String get ttsTextHint => '请输入要转换为语音的文本...';

  @override
  String get ttsFullscreenEdit => '全屏编辑';

  @override
  String ttsTextLimitWarning(int limit) {
    return '文字超出限制（最多 $limit 字）';
  }

  @override
  String get ttsSynthesisConfig => '合成配置';

  @override
  String get ttsVoiceAndSoundHelp => '调整音色与声音表现';

  @override
  String get ttsProviderSettingsLead => '在';

  @override
  String get ttsProviderSettings => 'TTS供应商设置';

  @override
  String get ttsProviderSettingsTail => '页面设置更多参数';

  @override
  String get ttsEditText => '编辑文本';

  @override
  String get ttsClose => '关闭';

  @override
  String get ttsVoice => '音色';

  @override
  String get ttsSelectVoice => '选择音色';

  @override
  String get ttsSpeed => '语速';

  @override
  String get ttsNormal => '正常';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsInstruction => '语气指令（instruction）';

  @override
  String get ttsInstructionHint => '例如：请用愉快、兴奋的语气说话';

  @override
  String get ttsCustomParams => '自定义参数';

  @override
  String ttsDefaultValue(Object value) {
    return '默认: $value';
  }

  @override
  String get ttsGenerateRecording => '生成录音';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return '将保存为: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => '选择保存文件夹';

  @override
  String get ttsFillTextError => '请输入要转换的文本';

  @override
  String get voiceBatchTitle => '批量添加音色';

  @override
  String get voiceBatchConfirm => '确认添加';

  @override
  String get voiceBatchSeparator => '分隔符：';

  @override
  String get voiceBatchCustomSeparatorHint => '请输入自定义分隔符';

  @override
  String get voiceBatchFieldOrder => '字段顺序：';

  @override
  String get voiceBatchNameThenId => '第1个=名称, 第2个=ID';

  @override
  String get voiceBatchIdThenName => '第1个=ID, 第2个=名称';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '检测到 $count 列，请选择作为名称/ID的起始列：',
      one: '检测到 1 列，请选择作为名称/ID的起始列：',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return '第$index列：$sample';
  }

  @override
  String get voiceBatchSingleColumn => '识别到单列数据，将全部作为ID处理（名称 = ID）';

  @override
  String get voiceBatchInputHint => '支持 Tab / 逗号 / 分号 / 竖线 作为分隔符，每行两个内容';

  @override
  String get voiceBatchNoPreview => '暂无解析结果';

  @override
  String get voiceName => '音色名称';

  @override
  String get voiceId => '音色ID';

  @override
  String get status => '状态';

  @override
  String get voiceNew => '✅ 新增';

  @override
  String get voiceIdExists => '⚠️ ID已存在';

  @override
  String voiceFormatError(String details) {
    return '❌ 格式错误$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发现 $count 个重复ID: $ids',
      one: '发现 $count 个重复ID: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData => '所选列数据不足';

  @override
  String get voiceCustomSeparator => '自定义...';

  @override
  String get voiceCommaSeparator => '逗号 (,)';

  @override
  String get voiceSemicolonSeparator => '分号 (;)';

  @override
  String get voicePipeSeparator => '竖线 (|)';

  @override
  String get voiceTabSeparator => 'Tab';

  @override
  String get voiceEditorTitle => '音色编辑';

  @override
  String get save => '保存';

  @override
  String get voiceAddRow => '添加一行';

  @override
  String get voiceBatchAdd => '批量添加';

  @override
  String get voiceNoneAdd => '暂无音色，请添加';

  @override
  String get delete => '删除';

  @override
  String get voiceDuplicateResolution => '发现以下重复音色ID，逐条选择处理方式：';

  @override
  String get update => '更新';

  @override
  String get skip => '跳过';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 个重复未处理',
      one: '还有 $count 个重复未处理',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => '继续编辑';

  @override
  String get asrRetryIncomplete => '重试音频不完整，请清空后重新选择全部音频';

  @override
  String asrRetryAudioUnreadable(String details) {
    return '重试音频数据无法读取，请重新选择音频: $details';
  }

  @override
  String get asrLegacyRetryUnavailable => '旧版重试音频不可用，请重新选择音频';

  @override
  String get asrRetryDataUnreadable => '重试数据无法读取，请重新选择音频';

  @override
  String get ttsSynthesisModel => '合成模型';

  @override
  String get asrRetryUnavailable => '重试音频不可用，请重新选择音频';

  @override
  String get chatRequest => '请求 (Request)';

  @override
  String get chatResponse => '响应 (Response)';

  @override
  String get chatNoErrorDetails => '无详细数据';

  @override
  String get ttsInstructionDescription => '通过自然语言描述语气、情绪、语速、口音等，模型将据此调整合成语音的风格';

  @override
  String get audioPlayerSourceTextSource => '选择源文本来源';

  @override
  String get audioPlayerChooseInAppText => '从应用内文本选择';

  @override
  String get audioPlayerChooseSavedTextSubtitle => '从应用内已保存的文本文件中选择';

  @override
  String get audioPlayerChooseSystemText => '从系统文本文件选择';

  @override
  String get audioPlayerChooseDeviceTextSubtitle => '从设备文件中选择文本文件';

  @override
  String get audioPlayerSelectInAppText => '选择应用内文本';

  @override
  String get audioPlayerNoTextFiles => '暂无文本文件';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count字';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return '选择文本失败: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => '无法读取文本文件';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return '上传源文本失败: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => '文本内容为空';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return '保存源文本失败: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => '源文本已上传';

  @override
  String get audioPlayerSourceTextUpdated => '源文本已更新';

  @override
  String get audioPlayerConfigureTtsProvider => '请先配置TTS供应商';

  @override
  String get audioPlayerNoStreamingModels => '没有支持流式播放的模型';

  @override
  String get audioPlayerSelectStreamingModel => '选择流式播放模型';

  @override
  String get audioPlayerProviderFallback => '供应商';

  @override
  String audioPlayerStartStreaming(String model) {
    return '开始流式播放: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return '无法找到音频文件: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => '无法加载音频数据';

  @override
  String get audioPlayerSourceText => '源文本';

  @override
  String get audioPlayerNoSourceText => '（无源文本）';

  @override
  String get audioPlayerUploadSourceText => '上传源文本';

  @override
  String get audioPlayerEditSourceText => '修改源文本';

  @override
  String get audioPlayerCompanionTextMissing => '未找到伴生文本文件';

  @override
  String get audioPlayerPlaySelection => '播放选中';

  @override
  String get audioPlayerGenerateSelection => '生成选中';

  @override
  String get audioPlayerPlaying => '正在播放...';

  @override
  String get audioPlayerPaused => '已暂停';

  @override
  String get audioPlayerPlaybackSpeed => '播放速度';

  @override
  String get audioPlayerFailed => '播放失败';

  @override
  String get audioPlayerRetry => '重试';

  @override
  String get audioPlayerLoading => '正在加载音频...';

  @override
  String get audioPlayerClose => '关闭';

  @override
  String get audioRecordingBrowserUnsupportedShort => '浏览器暂不支持录音功能，请使用 App 版本';

  @override
  String get audioRecordingMicrophonePermissionRequired => '需要麦克风权限才能录音';

  @override
  String audioRecordingStartFailure(String error) {
    return '开始录音失败: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return '暂停录音失败: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return '恢复录音失败: $error';
  }

  @override
  String get audioRecordingInvalidFile => '录音文件无效，请重新录制';

  @override
  String audioRecordingStopFailure(String error) {
    return '停止录音失败: $error';
  }

  @override
  String get audioRecordingFileNotFound => '录音文件不存在';

  @override
  String get audioRecordingFileEmpty => '录音文件为空';

  @override
  String audioRecordingSaved(String name) {
    return '录音已保存: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return '保存录音失败: $error';
  }

  @override
  String get audioRecordingTitle => '录音';

  @override
  String get audioRecordingBrowserUnsupported => '浏览器暂不支持录音功能';

  @override
  String get audioRecordingUseApp => '请使用 App 版本进行录音';

  @override
  String get audioRecordingDraftRecoveryHint => '检测到未保存的录音草稿，可保存到音频库。';

  @override
  String get audioRecordingRecording => '录制中 ●';

  @override
  String get audioRecordingPaused => '已暂停 ||';

  @override
  String get audioRecordingPreparing => '准备中...';

  @override
  String get audioRecordingStart => '开始录音';

  @override
  String get audioRecordingPause => '暂停';

  @override
  String get audioRecordingStopping => '停止中...';

  @override
  String get audioRecordingStop => '停止';

  @override
  String get audioRecordingResume => '恢复';

  @override
  String get audioRecordingSaving => '保存中...';

  @override
  String get audioRecordingSave => '保存录音';

  @override
  String get audioRecordingRecordAgain => '重新录制';

  @override
  String get audioRecordingWaveformPaused => '暂停录制，波形已冻结';

  @override
  String get audioRecordingWaveformLive => '音量波形实时显示';

  @override
  String get audioSeparationTitle => '视频音频分离';

  @override
  String get audioSeparationChooseVideoSource => '选择视频来源';

  @override
  String get audioSeparationChooseAppAlbum => '从应用相册选择';

  @override
  String get audioSeparationChooseSavedVideoSubtitle => '从应用内已保存的视频中选择';

  @override
  String get audioSeparationChooseSystemAlbum => '从系统相册选择';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle => '从设备存储中选择视频文件';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return '选择视频失败: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix => '音频提取失败: ';

  @override
  String get audioSeparationEngineMissing => '未检测到音频分离引擎';

  @override
  String get audioSeparationEngineMissingHelp => '请重启应用或检查应用资源完整性。';

  @override
  String get audioSeparationNoVideoSelected => '暂未选择视频文件';

  @override
  String get audioSeparationSupportedFormatsHint => '支持 mp4、mov、m4v、3gp 格式';

  @override
  String get audioSeparationSuccess => '音频已成功提取并保存到音频库';

  @override
  String get audioSeparationView => '查看';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 个视频',
      one: '已选 $count 个视频',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => '提取中...';

  @override
  String get audioSeparationExtractAudio => '提取音频';

  @override
  String get audioSeparationSaveTo => '保存至';

  @override
  String get audioSeparationChooseSaveFolder => '选择保存文件夹';

  @override
  String get audioSeparationCannotReadVideoFile => '无法读取视频文件';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return '选择视频文件失败: $error';
  }

  @override
  String get audioSeparationUnknownFormat => '未知';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return '暂不支持 $formats 格式，仅支持 MP4、MOV、M4V、3GP。';
  }

  @override
  String get audioSeparationEngineUnavailable => '音频分离引擎不可用。';

  @override
  String get backgroundOptimizationTitle => '后台运行优化';

  @override
  String get backgroundOptimizationEnvironment => '系统环境检测';

  @override
  String get backgroundOptimizationChecks => '后台优化检测';

  @override
  String get backgroundOptimizationKeepAliveStrategies => '保活策略';

  @override
  String get backgroundOptimizationDetecting => '正在检测...';

  @override
  String get backgroundOptimizationUnsupportedStatus => '当前平台不支持后台服务';

  @override
  String get backgroundOptimizationServiceRunning => '后台服务运行中';

  @override
  String get backgroundOptimizationServiceStopped => '后台服务未启动';

  @override
  String get backgroundOptimizationServiceCheckFailed => '无法检测后台服务状态';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      '桌面端托盘暂不可用，关闭窗口将直接退出';

  @override
  String get backgroundOptimizationDesktopCloseExits => '桌面端关闭窗口时退出应用';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive => '桌面端使用托盘驻留保活';

  @override
  String get backgroundOptimizationStartFailed => '启动服务失败';

  @override
  String get backgroundOptimizationStopFailed => '停止服务失败';

  @override
  String get backgroundOptimizationRestartFailed => '重启服务失败';

  @override
  String get backgroundOptimizationStopService => '停止服务';

  @override
  String get backgroundOptimizationRestartService => '重新启动服务';

  @override
  String get backgroundOptimizationStartService => '启动服务';

  @override
  String get backgroundOptimizationRedetect => '重新检测';

  @override
  String get backgroundOptimizationUnsupportedControl => '当前平台不支持后台服务控制。';

  @override
  String get backgroundOptimizationCheckingBattery => '正在检测电池优化状态...';

  @override
  String get backgroundOptimizationBatteryIgnored => '已忽略电池优化';

  @override
  String get backgroundOptimizationBatteryMayKill => '未忽略电池优化 — 后台可能被杀';

  @override
  String get backgroundOptimizationIgnoreBattery => '忽略电池优化';

  @override
  String get backgroundOptimizationExactAlarm => '允许精确闹钟（保活更可靠）';

  @override
  String get backgroundOptimizationWatchdogTitle => 'AlarmManager 看门狗';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      '启用后，Android 系统会每 5 分钟用原生闹钟检查后台服务是否还活着。如果进程被系统杀掉，闹钟会触发自动重启。\n\n闹钟在设备休眠（Doze）模式下依然生效，重启后也会自动重新调度。\n\n适用场景：对后台任务要求极高的用户。\n耗电影响：极低（每次仅短暂唤醒检查一次）。';

  @override
  String get backgroundOptimizationSaveWatchdogFailed => '保存失败，看门狗设置未更改';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      '看门狗激活失败，后台服务保活状态未确认';

  @override
  String get backgroundOptimizationColdStartTitle => '冷启动自动恢复';

  @override
  String get backgroundOptimizationColdStartDetail =>
      '启用后，每次重新打开 App 时，会自动检测并恢复之前正在运行的后台服务。\n\n如果 App 进程被系统或用户手动杀掉，下次打开 App 时后台服务会自动重启，无需手动操作。\n\n适用场景：所有用户都建议开启。\n耗电影响：无（仅在 App 启动时检查一次）。';

  @override
  String get backgroundOptimizationSaveColdStartFailed => '保存失败，冷启动恢复设置未更改';

  @override
  String get backgroundOptimizationBatteryReminderTitle => '电池优化提醒';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      '启用后，本页面会显示电池优化状态卡片。如果检测到 App 未被添加到省电白名单，会提供一键跳转至系统设置进行豁免。\n\n电池优化是安卓系统省电机制（Doze），会限制后台应用的运行。添加到白名单后，系统不会因省电而杀掉本 App。\n\n适用场景：关闭本开关仅隐藏提醒卡片，不影响实际的电池优化豁免状态。';

  @override
  String get backgroundOptimizationStrategyIntro =>
      '以下策略可独立开关。默认全部启用以获得最强保活效果。关闭某项仅影响该策略，不会影响后台服务本身的运行。';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOS 后台任务提示';

  @override
  String get backgroundOptimizationIosSupported =>
      '当前系统（iOS 26 及以上）支持任务常驻后台：任务运行期间切换 App 或锁屏，任务通常会继续执行（系统资源紧张时可能终止），并可在锁屏界面查看进度。';

  @override
  String get backgroundOptimizationIosUnsupported =>
      '当前系统（低于 iOS 26）不支持任务常驻后台。任务运行时请每隔几分钟返回一次 App（建议 5–10 分钟，具体由系统决定），刷新后台执行时间，防止任务被系统挂起。';

  @override
  String get backgroundOptimizationIosWarning =>
      '注意：所有 iOS 版本都请勿在 App 切换器中划掉 Stroom——划掉会立即终止所有运行中的任务。';

  @override
  String get backgroundOptimizationDesktopIntro =>
      '桌面端没有移动系统的进程保活机制，但可以让应用在关闭窗口后继续运行。';

  @override
  String get backgroundOptimizationCloseMinimizeTitle => '关闭窗口时最小化';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      '启用后，点击窗口关闭按钮不会退出应用，而是隐藏到系统托盘继续运行，后台任务不受影响。\n\n可从托盘图标（或右键菜单「显示主窗口」）恢复窗口；需要真正退出时，点击下方「完全退出应用」按钮。\n\n适用场景：所有桌面用户都建议开启。';

  @override
  String get backgroundOptimizationQuitApp => '完全退出应用';

  @override
  String get backgroundOptimizationGotIt => '知道了';

  @override
  String get backgroundOptimizationWebNoteTitle => 'Web 后台任务提示';

  @override
  String get backgroundOptimizationWebNote =>
      '浏览器没有应用常驻后台的机制。关闭标签页、刷新页面，或浏览器冻结长时间不活跃的后台标签页，都会立即中断运行中的任务。任务运行时请保持 Stroom 标签页打开并处于前台。';

  @override
  String get backgroundOptimizationTutorial => '平台教程';

  @override
  String get backgroundOptimizationTutorialDescription => '查看各个平台的后台运行优化教程';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      '正在检测后台服务状态...';

  @override
  String get backgroundOptimizationServiceUnknown => '后台服务状态未知，请重新检测以确认服务是否运行。';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      '后台服务正在运行，任务将在后台正常执行。';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'Web 浏览器环境不支持后台服务运行。请保持页面打开以继续任务。';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      '桌面平台托盘暂不可用（Linux 构建需安装 libayatana-appindicator3-dev），关闭窗口将直接退出应用。';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      '桌面平台托盘暂不可用，关闭窗口将直接退出应用。';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      '桌面平台已设置为关闭窗口时退出：关闭窗口后应用会按现有退出确认流程处理并退出，不会在托盘继续运行。';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      '桌面平台已启用托盘驻留：关闭窗口后应用会隐藏到系统托盘继续运行，从托盘菜单选择「显示主窗口」即可恢复窗口。如需彻底退出，请从托盘菜单选择「退出 Stroom」。';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      '桌面平台已启用托盘驻留：关闭窗口后应用会最小化到系统托盘继续运行，点击托盘图标（或托盘菜单「显示主窗口」）即可恢复窗口。如需彻底退出，请从托盘菜单选择「退出 Stroom」。';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      '后台服务未启动。请点击下方「启动服务」按钮启动后台服务，或查看平台教程了解如何优化后台运行设置。';

  @override
  String get notificationSettingsPageTitle => '通知权限设置';

  @override
  String get notificationSettingsWebUnsupported => 'Web 环境不支持通知权限';

  @override
  String get notificationSettingsChecking => '正在检测...';

  @override
  String get notificationSettingsPermissionGranted => '通知权限已授权';

  @override
  String get notificationSettingsPermissionDenied => '通知权限未授予';

  @override
  String get notificationSettingsPermissionRestricted => '通知权限受限';

  @override
  String get notificationSettingsPermissionBlocked => '通知权限已被永久屏蔽';

  @override
  String get notificationSettingsPermissionProvisional => '通知权限为临时授权';

  @override
  String get notificationSettingsWebGuide => '当前为 Web 环境，不支持系统通知功能。';

  @override
  String get notificationSettingsCheckingPermission => '正在检测通知权限状态...';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      '通知权限已授予，您可以开启任务完成通知，在任务完成或失败时收到系统通知。';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      '通知权限尚未授予。您可以点击下方按钮请求权限，或在系统设置中手动开启 Stroom 的通知权限。';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      '通知权限受系统限制（如家长控制）。请在系统设置中检查 Stroom 的通知权限设置。';

  @override
  String get notificationSettingsEnvironment => '系统环境检测';

  @override
  String get notificationSettingsPermissionSection => '通知权限检测';

  @override
  String get notificationSettingsPlatformGuides => '平台指南';

  @override
  String get notificationSettingsGuideIntro =>
      '根据您的操作系统，按照以下步骤开启 Stroom 的通知权限。';

  @override
  String get notificationSettingsTaskCompleteTitle => '任务完成通知';

  @override
  String get notificationSettingsTaskCompleteDescription => '任务完成或失败时发送通知';

  @override
  String get notificationSettingsCheckAgain => '重新检测';

  @override
  String get notificationSettingsOpenSystemSettings => '前往系统设置';

  @override
  String get notificationSettingsRequestPermission => '请求权限';

  @override
  String get notificationSettingsGuideUnsupported => '当前平台暂不支持通知权限设置指南。';

  @override
  String get notificationSettingsUsageReason => '用于在任务完成时发送通知';

  @override
  String get notificationSettingsAndroidEnableTitle => '开启通知权限';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      '进入「设置」→「应用」→「Stroom」→「通知管理」，确保已允许通知权限。如果找不到 Stroom，请确认应用已安装。如果权限被禁用，请手动开启。';

  @override
  String get notificationSettingsAndroidDndTitle => '检查勿扰模式';

  @override
  String get notificationSettingsAndroidDndDescription =>
      '进入「设置」→「声音与振动」→「勿扰模式」，确认勿扰模式未开启，或已将在其中允许 Stroom 的通知。';

  @override
  String get notificationSettingsAndroidPopupTitle => '允许后台弹出通知';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      '部分 Android 系统（如 MIUI、EMUI、ColorOS 等）需要额外在应用信息中开启「允许通知」和「允许弹窗」。建议同时关闭该应用的「通知过滤」或「智能通知」功能。';

  @override
  String get notificationSettingsReturnTitle => '完成后返回此页面';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。如果权限已显示为已授权，即可开启任务完成通知开关。';

  @override
  String get notificationSettingsIosEnableDescription =>
      '进入「设置」→「通知」→「Stroom」，开启「允许通知」。建议同时开启「横幅」和「通知中心」以便及时获知任务状态。';

  @override
  String get notificationSettingsIosFocusTitle => '关闭专注模式';

  @override
  String get notificationSettingsIosFocusDescription =>
      '进入「设置」→「专注模式」，确保未开启或已将 Stroom 加入允许的应用列表。专注模式可能会屏蔽应用通知。';

  @override
  String get notificationSettingsIosReturnDescription =>
      '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。iOS 上通知权限通常需要用户手动在系统设置中开启。';

  @override
  String get notificationSettingsWindowsEnableTitle => '开启系统通知';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      '进入「设置」→「系统」→「通知和操作」，确保「获取来自应用和其他发送者的通知」已开启。在下方应用列表中找到 Stroom 并确保通知已开启。';

  @override
  String get notificationSettingsWindowsFocusTitle => '开启专注助手排除项';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      '进入「设置」→「系统」→「专注助手」，确保 Stroom 已加入「仅优先打断」或「关闭专注助手」。专注助手开启时会屏蔽通知。';

  @override
  String get notificationSettingsMacEnableTitle => '开启通知权限';

  @override
  String get notificationSettingsMacEnableDescription =>
      '进入「系统设置」→「通知」→「Stroom」，开启「允许通知」。建议同时开启「横幅」和「通知中心」。';

  @override
  String get notificationSettingsMacFocusDescription =>
      '进入「系统设置」→「专注模式」，确保未开启或已将 Stroom 加入允许的应用列表。';

  @override
  String get notificationSettingsLinuxDesktopTitle => '检查桌面环境通知设置';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      '根据您使用的桌面环境（GNOME、KDE、XFCE 等），进入「系统设置」→「通知」→ 找到 Stroom 并确保通知已开启。';

  @override
  String get notificationSettingsLinuxDaemonTitle => '检查是否安装了通知守护进程';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux 桌面环境需要安装通知守护进程（如 notify-osd 或 dunst）来显示系统通知。请确认您的系统中已安装并运行了通知守护进程。';

  @override
  String get backupRestorePageTitle => '数据备份与恢复';

  @override
  String get backupRestoreSelectBackupCategory => '请至少选择一项要备份的数据类别';

  @override
  String get backupRestorePreparingData => '正在准备数据...';

  @override
  String get backupRestoreExportingBackup => '正在导出备份';

  @override
  String get backupRestoreCollectingDatabase => '正在收集数据库记录...';

  @override
  String get backupRestoreProcessingSettings => '正在处理配置数据...';

  @override
  String get backupRestoreAddingTasks => '正在添加任务文件...';

  @override
  String get backupRestoreAddingPictures => '正在添加图片文件...';

  @override
  String get backupRestoreAddingAudio => '正在添加音频文件...';

  @override
  String get backupRestoreAddingVideo => '正在添加视频文件...';

  @override
  String get backupRestoreAddingText => '正在添加文本文件...';

  @override
  String get backupRestoreAddingChat => '正在添加聊天记录和附件...';

  @override
  String get backupRestoreCompressing => '正在压缩打包...';

  @override
  String get backupRestoreCompleted => '已完成';

  @override
  String get backupRestoreSelectRestoreCategory => '请至少选择一项要恢复的数据类别';

  @override
  String get backupRestoreConfirmRestore => '确认恢复';

  @override
  String get backupRestoreSelectedCategories => '已勾选的数据类别：';

  @override
  String get backupRestoreRestoreInfo =>
      '备份中实际包含的已勾选类别会恢复到本机。除内置浏览器 Cookies 外，其余类别会替换本机对应数据；Cookies 按域名、名称和路径写入，备份中没有的本机 Cookies 保持原样。未勾选或备份中缺少的类别保持原样；缺少的类别会跳过并提示。';

  @override
  String get backupRestoreRestartNotice => '恢复完成后需重启应用才能生效，请确保已保存当前工作。';

  @override
  String get backupRestoreCancel => '取消';

  @override
  String get backupRestoreConfirmRestoreButton => '确定恢复';

  @override
  String get backupRestoreIncompleteTitle => '恢复未完成';

  @override
  String get backupRestoreIncompleteMessage => '数据未能完整恢复，部分数据可能已被清除。请重启应用后重试。';

  @override
  String get backupRestoreSelectClearCategory => '请至少选择一项要清除的数据类别';

  @override
  String get backupRestoreClearingData => '正在清除数据';

  @override
  String get backupRestoreDeletingCategories => '正在删除所选类别的数据...';

  @override
  String get backupRestoreClearedTitle => '数据清除完成';

  @override
  String get backupRestorePartiallyClearedTitle => '部分数据已清除';

  @override
  String get backupRestoreClearedMessage => '所选数据已清除。请重启应用以生效。';

  @override
  String get backupRestorePartialClearMessage =>
      '其他所选数据已清除。当前平台不支持完整清除内置浏览器网站存储（localStorage、IndexedDB 等）；未能清除的浏览器数据仍会保留。请重启应用使已清除的数据生效。';

  @override
  String backupRestoreClearFailed(String error) {
    return '清除失败: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => '清除未完成';

  @override
  String get backupRestoreClearIncompleteMessage => '部分数据未能清除。请重启应用后重试清除操作。';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki闪卡片组已导出到: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get backupRestoreApkgRequired => '请选择 .apkg 格式的文件';

  @override
  String backupRestoreImportFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return '备份已保存到: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return '备份失败: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return '恢复失败: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected => '尚未选择备份目录，请在启动流程中授权';

  @override
  String get backupRestoreRestoreSuccessTitle => '数据恢复成功';

  @override
  String get backupRestoreRestoredMessage => '数据已从备份中恢复。请重启应用以使用恢复的数据。';

  @override
  String get backupRestoreExitApp => '退出应用';

  @override
  String get backupRestoreRestartNow => '立即重启';

  @override
  String get backupRestoreSkippedTitle => '部分数据已跳过';

  @override
  String get backupRestoreNothingRestoredTitle => '未恢复任何数据';

  @override
  String get backupRestoreGotIt => '知道了';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return '备份中未能确认以下勾选的数据类型包含可恢复内容，已跳过；当前数据保持不变：$categories。';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      '如果这是旧版备份，空任务文件无法区分“任务列表为空”和“该平台未导出任务”；为避免覆盖当前任务，任务类别已跳过并保留原数据。';

  @override
  String get backupRestoreSkippedCookies =>
      '备份中没有可导入的内置浏览器 Cookies，已跳过；本机现有 Cookies 保持不变。';

  @override
  String get backupRestoreSkippedWebsiteData =>
      '旧版备份中的网站存储目录已跳过；备份包若包含 Cookies 且该类别已勾选，仍可单独导入。';

  @override
  String get backupRestoreApkgTitle => 'Anki闪卡牌组';

  @override
  String get backupRestoreApkgInfoTitle => 'Anki 闪卡牌组导入/导出';

  @override
  String get backupRestoreApkgInfoMessage => '只包含卡片信息，不包含媒体内容';

  @override
  String get backupRestoreApkgDescription => '导入/导出 .apkg 格式的 Anki 牌组';

  @override
  String get backupRestoreExportingApkg => '导出中...';

  @override
  String get backupRestoreExportApkg => '导出 .apkg';

  @override
  String get backupRestoreImportingApkg => '导入中...';

  @override
  String get backupRestoreImportApkg => '导入 .apkg';

  @override
  String get backupRestoreCategoryHeading => '选择要备份或恢复的数据类别';

  @override
  String get backupRestoreExporting => '正在导出...';

  @override
  String get backupRestoreExportBackup => '导出备份';

  @override
  String get backupRestoreRestoring => '正在恢复...';

  @override
  String get backupRestoreChooseBackup => '选择备份文件并恢复';

  @override
  String get backupRestoreClearSelected => '清除所选数据';

  @override
  String get backupRestoreClearDescription =>
      '直接清除当前勾选的数据类别（不需要备份文件）。未勾选的类别将保持原样。此操作不可撤销。';

  @override
  String get backupRestoreClearing => '正在清除...';

  @override
  String get backupRestoreCategoryChat => '聊天记录和附件';

  @override
  String get backupRestoreCategoryChatDescription => '聊天对话记录、消息内容与附件文件';

  @override
  String get backupRestoreCategorySettings => '设置';

  @override
  String get backupRestoreCategorySettingsDescription => '应用配置、提供商设置与界面偏好';

  @override
  String get backupRestoreCategoryPictures => '图片';

  @override
  String get backupRestoreCategoryPicturesDescription => '照片和缩略图';

  @override
  String get backupRestoreCategoryAudio => '音频';

  @override
  String get backupRestoreCategoryAudioDescription => '语音合成和录音';

  @override
  String get backupRestoreCategoryVideos => '视频';

  @override
  String get backupRestoreCategoryVideosDescription => '视频文件';

  @override
  String get backupRestoreCategoryTexts => '文本';

  @override
  String get backupRestoreCategoryTextsDescription => '文本文档';

  @override
  String get backupRestoreCategoryTasks => '任务';

  @override
  String get backupRestoreCategoryTasksDescription => '后台任务记录';

  @override
  String get backupRestoreCategoryAnki => 'Anki闪卡数据';

  @override
  String get backupRestoreCategoryAnkiDescription => 'Anki 原始数据库';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki 闪卡数据';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      '备份和恢复 Anki 闪卡数据时会包含 collection.media 目录中的卡片媒体内容。';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'Anki 闪卡数据说明';

  @override
  String get backupRestoreCategoryBrowser => '内置浏览器数据';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      '仅备份与恢复 Cookies；清除时同时清理可支持的网站存储';

  @override
  String get backupRestoreViewInfo => '查看说明';

  @override
  String get backupRestoreApkgInfoTooltip => 'Anki 牌组导入导出说明';

  @override
  String get backupRestoreConfirmClear => '确认清除';

  @override
  String get backupRestoreClearCategoriesIntro => '将清除以下数据类别（不经过备份文件）：';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      '当前平台不支持完整清除内置浏览器网站存储（localStorage、IndexedDB 等）；确认后会清除其他所选数据，无法清除的浏览器数据将保留。';

  @override
  String get backupRestoreUnselectedUnchanged => '未勾选的类别将保持原样，不会被清除。';

  @override
  String get backupRestoreClearWarning => '此操作不可撤销。清除完成后需重启应用才能生效。';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return '确定清除（$seconds）';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => '浏览器环境';

  @override
  String get backupRestoreIntro =>
      '手动导出可按数据类别选择备份内容。导入时，只恢复已勾选且备份包中包含的类别；若备份缺少某类别或其必需文件不完整，该类别会自动跳过并提示，未勾选的类别保持原样。也可直接清除所选类别的数据。';

  @override
  String get backupRestoreOtherSelectedRestored => '其余所选数据已恢复，请重启应用以生效。';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      '通知已被系统屏蔽，请前往系统设置允许 Stroom 的通知权限。';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      '通知已被系统屏蔽。请前往系统设置 > 应用 > Stroom > 通知管理，允许通知权限。';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      '通知已被系统屏蔽。请前往系统设置 > Stroom > 通知，允许通知权限。';

  @override
  String get textPreviewDiscardEditsTitle => '放弃编辑？';

  @override
  String get textPreviewUnsavedChangesConfirm => '你有未保存的更改，确定要放弃吗？';

  @override
  String get textPreviewCancel => '取消';

  @override
  String get textPreviewDiscard => '放弃';

  @override
  String get textPreviewFontSize => '字号调整';

  @override
  String get textPreviewRestoreDefault => '恢复默认';

  @override
  String get textPreviewClose => '关闭';

  @override
  String textPreviewSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get textPreviewUndo => '撤销';

  @override
  String get textPreviewRedo => '重做';

  @override
  String get textPreviewSave => '保存';

  @override
  String get textPreviewEdit => '编辑';

  @override
  String get textPreviewChartEdit => '图表编辑';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return '跳过不支持的格式：$format';
  }

  @override
  String textStorageImportSuccess(int count) {
    return '已导入 $count 个文本文件';
  }

  @override
  String textStorageImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get textStorageSaved => '文本已保存';

  @override
  String get textStorageLoadFailed => '无法加载文本内容';

  @override
  String get textStorageReadFailed => '文件数据读取失败';

  @override
  String get textStorageExportTitle => '导出文本';

  @override
  String textStorageExportedTo(String path) {
    return '已导出到：$path';
  }

  @override
  String textStorageExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get textStorageChooseExportDirectory => '选择导出目录';

  @override
  String get textStorageFolderExportTitle => '文件夹导出';

  @override
  String get textStorageWebFolderExportInfo =>
      '浏览器无法选择导出目录，将下载保留文件夹层级的 ZIP 文件。';

  @override
  String get textStorageCancel => '取消';

  @override
  String get textStorageDownloadZip => '下载 ZIP 文件';

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
  String get batchDlgFileName => '文件名';

  @override
  String get batchDlgFolderName => '文件夹名';

  @override
  String get batchDlgFileNameConflict => '同一文件夹内存在同名文件';

  @override
  String get batchDlgFolderNameConflict => '目标位置已存在同名文件夹';

  @override
  String get batchDlgFolderNameSwapConflict => '文件夹之间不能在同一批次互换名称';

  @override
  String get batchDlgControlCharacterError => '名称不能包含控制字符';

  @override
  String get batchDlgNameWhitespaceError => '名称不能以空白开头或结尾，可添加空白清理规则';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind不能为空';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind不能以空白结尾';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind不能超过$count个字符';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind不能包含 Windows 非法字符';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind不能以 . 结尾';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind不能使用 Windows 保留名称';
  }

  @override
  String get batchDlgIntermediateNameTooLong => '中间名称过长，请调整规则';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return '该项目没有$date，请调整模板';
  }

  @override
  String get batchDlgCreatedDate => '创建时间';

  @override
  String get batchDlgModifiedDate => '修改时间';

  @override
  String get connectivityTestHttpSuccess => 'HTTP 工具请求成功';

  @override
  String get connectivityTestHttpFailure => 'HTTP 工具请求失败';

  @override
  String get connectivityTestInvalidMcpConfig => 'MCP 配置无效';

  @override
  String get connectivityTestMissingTransport => '缺少有效的传输类型配置。';

  @override
  String get connectivityTestStdioUnsupported => '当前平台不支持 stdio';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP 需要启动本地进程，请在 Stroom 桌面版中测试。';

  @override
  String get connectivityTestInvalidContent => '测试内容无效';

  @override
  String get connectivityTestMethodMustBeString => 'method 必须是字符串。';

  @override
  String get connectivityTestUnsupportedMethod => '不支持的测试方法';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      '为避免测试写入远程业务数据，MCP 连通性测试只允许只读的 tools/list 方法。';

  @override
  String get connectivityTestParamsMustBeObject => 'params 必须是 JSON 对象。';

  @override
  String get connectivityTestMcpConnectionFailed => '无法连接 MCP 服务';

  @override
  String get connectivityTestCheckConnectionSettings =>
      '请检查地址、认证信息和网络，或查看应用日志获取连接详情。';

  @override
  String get connectivityTestRemainingToolsOmitted => '；其余工具已省略';

  @override
  String get connectivityTestMcpSuccess => 'MCP 连通性测试成功';

  @override
  String connectivityTestToolNames(Object names) {
    return '：$names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return '连接及 tools/list 请求成功，共发现 $count 个工具$names$suffix。';
  }

  @override
  String get connectivityTestTodoMutationBlocked => '测试参数会修改待办数据';

  @override
  String get connectivityTestTodoReadOnly =>
      '为保护当前会话待办列表，连通性测试只允许省略 todos 或设置为 null。';

  @override
  String get connectivityTestUnknownBuiltin => '未知的内置工具';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return '找不到工具“$toolName”的测试执行器。';
  }

  @override
  String get connectivityTestBuiltinSuccess => '内置工具测试成功';

  @override
  String get connectivityTestBuiltinFailure => '内置工具测试失败';

  @override
  String get connectivityTestTopLevelObjectRequired => '测试内容顶层必须是 JSON 对象。';

  @override
  String get connectivityTestRequestTimeout => '请求超时，请检查服务响应和网络。';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'MCP 请求超时：$method';
  }

  @override
  String get connectivityTestResultTruncated => '…（结果已截断）';

  @override
  String get toolResultWebSearchEmptyQuery => '错误：搜索关键词不能为空。';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return '错误：不支持的搜索引擎“$source”。可选值：google、bing、baidu。';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return '首选引擎 $preferred $reason，已切换到 $fallback。';
  }

  @override
  String get toolResultWebSearchNotFound => '未找到相关搜索结果。';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return '未找到相关搜索结果（$sources 均明确返回无结果）。';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return '搜索不完整：$sources 明确返回无结果；其他引擎不可用或返回了无法解析的页面：$failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return '错误：所有搜索引擎均不可用。$failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return '来自 $source 的搜索结果：';
  }

  @override
  String get toolResultWebSearchLinkLabel => '链接';

  @override
  String get toolResultWebSearchSummaryLabel => '摘要';

  @override
  String get toolResultWebSearchEmptyResults => '未找到相关搜索结果。';

  @override
  String get toolResultTodoInvalid => '错误：todos 参数必须是数组（省略或传 null 表示读取待办列表）。';

  @override
  String get toolResultTodoEmpty => '当前没有待办事项。';

  @override
  String toolResultTodoCount(Object count) {
    return '$count 个待办事项未完成';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return '错误：MCP 服务器“$server”重新连接失败。';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return '错误：MCP 服务器“$server”当前不可用。';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return '错误：MCP 服务器“$server”连接失败或未返回任何工具，请检查服务器配置。';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return '真实工具“$tool”在此服务器上的调用名为“$alias”。';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return '同名工具“$tool”由多个 MCP 服务器提供；请使用对应调用名：$routes。';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return '错误：真实工具“$tool”存在名称冲突，请使用上面列出的调用名。';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return '错误：MCP 服务器“$server”没有名为“$tool”的工具。';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return '该服务器可用的工具：$tools。请改用这些工具名调用。';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return '错误：MCP 工具“$tool”当前使用了冲突别名。请使用对应调用名：$routes。';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return '错误：工具“$tool”已停用。';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return '错误：未知工具“$tool”';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => '未找到相关结果';

  @override
  String get toolResultWebSearchFallbackUnavailable => '暂不可用';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '（MCP 服务器 $server）';
  }

  @override
  String get toolResultWebSearchUnparsedResults => '未返回可解析的搜索结果';

  @override
  String get toolResultSearchTitleLabel => '标题';

  @override
  String get toolResultSearchContentLabel => '内容';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return '错误：$provider API Key 未配置，请在设置页面配置。';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return '错误：$provider 实例 URL 未配置，请在设置页面配置。';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return '错误：$provider 请求失败 (HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return '错误：$provider 请求失败：$detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return '错误：未知的 HTTP 工具“$provider”';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return '错误：MCP 服务器“$server”未连接。';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return '错误：MCP 工具“$tool”无响应。';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return '错误：$detail';
  }

  @override
  String get httpToolBraveDescription =>
      '使用 Brave Search API 搜索网络。需要配置 API Key。';

  @override
  String get httpToolBochaDescription =>
      '使用博查 AI Search API 搜索网络。需要配置 API Key。';

  @override
  String get httpToolQueritDescription => '使用 Querit Search 搜索网络。需要配置 API Key。';

  @override
  String get httpToolSearxngDescription =>
      '注重隐私保护的自托管元搜索引擎，可聚合多种搜索源。需要配置实例 URL。';

  @override
  String get httpToolSearchQueryDescription => '搜索关键词。';

  @override
  String get httpToolSearchCountDescription => '返回结果数量。';

  @override
  String get httpToolSearchCountMax20Description => '返回结果数量（最大 20）。';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return '导入完成：$decks 个牌组，$notes 个笔记，$cards 张卡片';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '找不到所选的 .apkg 文件：$path';
  }

  @override
  String get backupRestoreApkgInvalidArchive => '所选的 .apkg 文件已损坏或不是有效的压缩包。';

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
  String backupRestoreApkgLocalFileFailure(String path) {
    return '无法访问本地 Anki 文件：$path';
  }

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
  String get ankiSyncStatusProtocolFailed =>
      '同步服务器响应无效或不完整。请确认服务器支持 Anki sync v10。';

  @override
  String get ankiSyncStatusLoginRequired => '请先登录 Anki 同步账户，再继续操作。';

  @override
  String get ankiSyncStatusInvalidServerUrl => '请输入有效的 HTTP 或 HTTPS 同步服务器地址。';

  @override
  String get ankiSyncStatusHttpsRequired => '远程自建同步服务器必须使用 HTTPS。';

  @override
  String get ankiSyncStatusConnectionTimeout => '同步请求超时。请检查服务器地址和网络后重试。';

  @override
  String get ankiSyncStatusTlsFailure => '无法验证服务器证书。请检查证书或配置自定义 CA。';

  @override
  String get ankiSyncStatusConnectionFailure => '无法连接到同步服务器。请检查服务器地址和网络。';

  @override
  String get ankiSyncStatusRequestFailure => '同步请求失败。请检查服务器和网络后重试。';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return '同步服务器返回了 HTTP $statusCode。';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return '同步响应超过 $limitMb MB 限制。';
  }

  @override
  String get ankiSyncStatusLocalFileFailure => '无法读取或清理本地同步文件。请检查磁盘访问权限后重试。';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      '无法打开或更新 collection，或该文件未通过 SQLite/schema 校验。请恢复有效的 collection 备份或重新下载。';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return '同步服务器拒绝了请求（HTTP $statusCode）。请检查登录凭据和服务器权限。';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return '找不到同步接口（HTTP $statusCode）。请检查服务器地址。';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      '媒体同步服务器返回了无效响应。请确认服务器支持 Anki 媒体同步后重试。';

  @override
  String get ankiSyncStatusMediaIndexCorrupt => '本地媒体同步索引已损坏。请重置媒体同步数据后重试。';

  @override
  String get ankiSyncStatusMediaIndexFailure => '本地媒体同步索引无法读取或更新。';

  @override
  String get ankiSyncStatusMediaChecksumMismatch => '下载的媒体文件校验失败。请重试媒体同步。';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return '媒体文件“$filename”在本地和服务器上均有修改。请先备份并解决同名冲突，再重试。';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return '媒体文件名“$filename”无法同步。请将其重命名为符合 Anki 规则的名称后重试。';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return '媒体文件为空或超过 $limitMb MB 限制。';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return '媒体压缩包包含 $count 个条目，最多允许 $limit 个（含清单）。';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed => '媒体同步校验失败。请重试同步。';

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

  @override
  String get emojiCategorySmileys => '表情';

  @override
  String get emojiCategoryPeople => '人物';

  @override
  String get emojiCategoryAnimals => '动物';

  @override
  String get emojiCategoryFood => '食物';

  @override
  String get emojiCategoryActivities => '活动';

  @override
  String get emojiCategoryTravel => '旅行';

  @override
  String get emojiCategoryObjects => '物品';

  @override
  String get emojiCategorySymbols => '符号';

  @override
  String get emojiCategoryFlags => '旗帜';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

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
  String get taskFlowOcrInputMissing => '找不到图片文件，请重新选择图片。';

  @override
  String get taskFlowOcrInputReadFailed => '无法读取图片文件，请检查文件访问权限后重试。';

  @override
  String get taskFlowOcrModelUnavailable =>
      '未配置可用的 OCR 模型，请在流程设置中选择 OCR 服务和模型。';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'OCR 请求大小预算（$size MiB）';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return '任务流图片输入上限（$size MiB）';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return '图片超过$limit，请缩小图片后重试。';
  }

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
  String get updateApkInstallerUnavailable => '未找到可安装 APK 的应用，请手动打开 APK 安装。';

  @override
  String get updateApkInstallPermissionDenied => '请在系统设置中允许 Stroom 安装未知来源应用。';

  @override
  String get updateRestartDialogTitle => '更新检测';

  @override
  String get updateRestartDialogBody => '检测到应用已更新，建议重启应用以确保稳定性。';

  @override
  String get updateRestartDialogLater => '稍后重启';

  @override
  String get updateRestartDialogNow => '立即重启';

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
  String get taskFlowCardRetryInfo =>
      '从头运行会重新下载并调用模型。可按启动时的原配置重试，或明确选择当前最新配置。要复用已完成步骤，请选择“从中断步骤继续”。';

  @override
  String get taskFlowCardRunLatest => '按最新配置运行';

  @override
  String get taskFlowCardRetryOriginal => '按原配置重试';

  @override
  String get taskFlowCardDeleteRecord => '删除任务流记录';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      '删除此运行记录将取消整个批次尚未完成的任务，并清除其子任务记录。确定删除？';

  @override
  String get taskFlowCardDeleteRunningConfirm => '任务流正在运行，删除将取消其中正在运行的任务。确定删除？';

  @override
  String get taskFlowCardDeleteRecordConfirm => '确定删除此任务流记录？其子任务记录也会一并删除。';

  @override
  String get taskFlowCardDeleteConfirm => '确定删除此任务流记录？';

  @override
  String get taskFlowCardSaveCancelStateError => '任务流取消状态无法保存，请重试删除';

  @override
  String get taskFlowCardStillRunning => '任务流取消后仍在运行';

  @override
  String get taskFlowCardSaveDeleteStateError => '任务流记录删除状态无法保存，请重试删除';

  @override
  String get taskFlowCardConfirm => '确定';

  @override
  String get taskFlowCardWaiting => '等待中';

  @override
  String get taskFlowCardRunning => '进行中';

  @override
  String get taskFlowCardPaused => '已暂停';

  @override
  String get taskFlowCardCompleted => '已完成';

  @override
  String get taskFlowCardFailed => '失败';

  @override
  String get taskFlowCardCanceled => '已取消';

  @override
  String get taskFlowCardInterrupted => '已中断';

  @override
  String get taskFlowCardSucceeded => '已跳过';

  @override
  String get taskFlowCardPause => '暂停流程';

  @override
  String get taskFlowCardResume => '继续流程';

  @override
  String get taskFlowCardResumeInterrupted => '从中断步骤继续';

  @override
  String get taskFlowCardCancel => '取消';

  @override
  String get unifiedTaskType => '任务类型';

  @override
  String get unifiedTaskCreatedAt => '创建时间';

  @override
  String get unifiedTaskCompletedAt => '完成时间';

  @override
  String get unifiedTaskResultStatus => '结果状态';

  @override
  String get unifiedTaskPartialResult => '部分结果，内容可能不完整';

  @override
  String get unifiedTaskErrorDetails => '错误详情';

  @override
  String get unifiedTaskViewErrorDetails => '查看错误详情';

  @override
  String get unifiedTaskOcrPerImage => '逐张识别';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return '第 $index 张';
  }

  @override
  String get unifiedTaskOcrPending => '待识别';

  @override
  String get unifiedTaskOcrRunning => '识别中';

  @override
  String get unifiedTaskCompleted => '已完成';

  @override
  String get unifiedTaskIncomplete => '结果不完整';

  @override
  String get unifiedTaskOcrFailed => '识别失败';

  @override
  String get unifiedTaskCancelled => '已取消';

  @override
  String get unifiedTaskWaitingStart => '等待开始...';

  @override
  String get unifiedTaskSteps => '执行步骤';

  @override
  String get unifiedTaskStartNow => '立即开始';

  @override
  String get unifiedTaskOpenFile => '打开文件';

  @override
  String get unifiedTaskRetrySave => '仅重试保存';

  @override
  String get unifiedTaskRetryPartialSave => '仅重试保存部分结果';

  @override
  String get unifiedTaskSavePartialResult => '保存部分结果';

  @override
  String get unifiedTaskRetry => '重试';

  @override
  String get unifiedTaskCancel => '取消';

  @override
  String get unifiedTaskDelete => '删除';

  @override
  String get unifiedTaskFormatUnsupported => '不支持此格式预览';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return '播放失败: $error';
  }

  @override
  String get unifiedTaskAudioFile => '音频文件';

  @override
  String get unifiedTaskPreviewLoadFailed => '无法加载预览';

  @override
  String get unifiedTaskUnknownSize => '未知大小';

  @override
  String get unifiedTaskUnnamedRecording => '未命名录音';

  @override
  String get unifiedTaskPause => '暂停';

  @override
  String get unifiedTaskClearTask => '清除任务';

  @override
  String get unifiedTaskContinue => '继续';

  @override
  String get unifiedTaskRemoveFromList => '从列表移除';

  @override
  String get unifiedTaskSynthesisText => '合成文本';

  @override
  String get unifiedTaskStatus => '状态';

  @override
  String get unifiedTaskDetails => '详情';

  @override
  String get unifiedTaskSynthesisError => '合成错误详情';

  @override
  String get unifiedTaskClose => '关闭';

  @override
  String get unifiedTaskRawRequestResponse => '原始请求与响应';

  @override
  String get unifiedTaskRawRequestBody => '原始请求体:';

  @override
  String get unifiedTaskRawResponseBody => '原始响应体:';

  @override
  String get commonJustNow => '刚刚';

  @override
  String commonMinutesAgo(Object count) {
    return '$count分钟前';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count小时前';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours时$minutes分';
  }

  @override
  String get unifiedTaskTypeOcr => '文字识别';

  @override
  String get unifiedTaskTypeAsr => '音频转写';

  @override
  String get unifiedTaskTypeAudioSeparation => '音频分离';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return '文字识别_$basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return '音频分离_$basename';
  }

  @override
  String get unifiedTaskTypeChat => '助手对话';

  @override
  String get unifiedTaskPlayAudio => '播放音频';

  @override
  String get unifiedTaskPauseAudio => '暂停音频';

  @override
  String get catcatchFlowActionNotStarted => '任务流操作未执行，请检查流程状态后重试';

  @override
  String catcatchFlowActionFailed(Object error) {
    return '任务流操作失败：$error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      '自动获取网页资源连续超时。请在此页面登录或设置用户脚本；检测到媒体资源后，点击“继续流程”。';

  @override
  String get browserRecoveryContinue => '继续流程';

  @override
  String get catcatchSkipped => '已跳过（无需处理）';

  @override
  String catCatchDetailMediaResources(Object count) {
    return '获取到$count个媒体资源';
  }

  @override
  String catCatchDetailResources(Object count) {
    return '获取到$count个资源';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return '浏览器中获取到$count个资源';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return '获取到$total个资源（播放列表$segments个分段）';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return '共$count个资源，请用户选择';
  }

  @override
  String get catCatchDetailAutoSelectFirst => '自动选择第1个结果，进入下载';

  @override
  String get catCatchDetailAutoSelectRemaining => '剩余1个结果，自动进入下载';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return '.$extension 格式无需转换，已跳过';
  }

  @override
  String get catCatchDetailSkipNoExtension => '. 格式无需转换，已跳过';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return '按照$duration时长筛选后剩余$remaining个结果（已排除$removed个不匹配的资源）';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return '按时长$duration筛选，$count个资源全部匹配';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '$count小时';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '$count分钟';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count秒';
  }

  @override
  String get catcatchRetryStep => '重试此步骤';

  @override
  String catcatchCollapseSegments(Object count) {
    return '收起 $count 个分片';
  }

  @override
  String catcatchShowSegments(Object count) {
    return '显示 $count 个分片';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '已选 $selected/$total 个资源';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '检测到 $count 个媒体资源';
  }

  @override
  String get catcatchFlowSelectOrCombine => '（选择一个资源或合并一组音视频）';

  @override
  String get catcatchSelectMultiple => '（点击选择，可多选）';

  @override
  String get catcatchWaitingForResources => '正在等待任务流资源';

  @override
  String catcatchDownloadSelected(Object count) {
    return '下载选中的 $count 个资源';
  }

  @override
  String get catcatchSelectResources => '请选择要下载的资源';

  @override
  String get catcatchPossibleSplit => '⚠ 疑似音视频分离';

  @override
  String get catcatchSplitExplanation =>
      '检测到此组资源可能是同一个视频的音频和视频分离的流，您可以选择合并音视频，或仅下载其中一种。';

  @override
  String get catcatchAudioStream => '🎵 音频流';

  @override
  String get catcatchVideoStream => '🎬 视频流';

  @override
  String get catcatchMergeAudioVideo => '合并音视频';

  @override
  String get catcatchVideoOnly => '仅视频';

  @override
  String get catcatchAudioOnly => '仅音频';

  @override
  String get catcatchSegmentsPlaylistPreview => '分片需通过播放列表预览';

  @override
  String get catcatchPreviewAudio => '预览音频';

  @override
  String get catcatchPreviewVideo => '预览视频';

  @override
  String catcatchDuration(Object duration) {
    return '时长: $duration';
  }

  @override
  String get catcatchSegment => '分片';

  @override
  String get catcatchPlaylist => '播放列表';

  @override
  String get catcatchFullVideo => '整片';

  @override
  String get catcatchSeparateTracks => '分轨';

  @override
  String get catcatchPreviewPlaylistOnly => '请通过播放列表预览';

  @override
  String get catcatchPreviewUnsupported => '不支持预览';

  @override
  String get catcatchUnknownFormat => '未知格式';

  @override
  String get catcatchNeedPlaylistProcessing => '需要处理播放列表';

  @override
  String get catcatchSpecialFormatDetected => '检测到特殊格式';

  @override
  String catcatchPlaylistInfo(Object format) {
    return '该资源是一个播放列表（$format），需要自动解析并下载所有分段后合并为可播放的视频文件。';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return '下载的文件格式为 $format，并不是标准的 MP4 格式。将使用内置的纯 Dart 转封装引擎转换为 MP4（TS/FLV/EV1 免外部依赖）。';
  }

  @override
  String get catcatchContinueBeforeConfirm => '请先继续流程，再确认格式处理';

  @override
  String get catcatchAutoProcess => '自动处理';

  @override
  String get catcatchKeepOriginalFormat => '保留原始格式';

  @override
  String get catcatchResumeSupported => '支持断点续传';

  @override
  String get catcatchResumeUnsupported => '该站点不支持断点续传';

  @override
  String get catcatchPauseDownload => '暂停下载';

  @override
  String get catcatchResumeDownload => '继续下载';

  @override
  String get catcatchRestartDownload => '重新下载';

  @override
  String get catcatchPendingFormatAction => '正在等待任务流资源';

  @override
  String get quitDialogTitle => '退出应用？';

  @override
  String quitDialogRunningTasks(Object count) {
    return '有 $count 个任务正在运行，退出将中断这些任务。确定要退出吗？';
  }

  @override
  String get quitDialogNoTasks => '确定要退出 Stroom 吗？';

  @override
  String get quitDialogCancel => '取消';

  @override
  String get quitDialogExit => '退出';

  @override
  String get searchPanelNewConversation => '新对话';

  @override
  String get searchPanelTitle => '搜索对话';

  @override
  String get searchPanelHint => '输入关键词...';

  @override
  String get searchPanelByTitle => '搜标题';

  @override
  String get searchPanelByContent => '搜内容';

  @override
  String searchPanelResults(Object count) {
    return '$count 个结果';
  }

  @override
  String get searchPanelPrompt => '输入关键词开始搜索';

  @override
  String get searchPanelNoResults => '没有找到匹配的对话';

  @override
  String get topicItemNew => '新话题';

  @override
  String get topicItemUnpin => '取消置顶';

  @override
  String get topicItemPin => '置顶';

  @override
  String get topicItemRename => '重命名';

  @override
  String get topicItemAutoName => '自动命名';

  @override
  String get topicItemDelete => '删除';

  @override
  String get galleryChoiceTitle => '选择图片来源';

  @override
  String get galleryChoiceDevice => '设备相册';

  @override
  String get galleryChoiceDeviceDescription => '浏览设备中的照片和视频';

  @override
  String get galleryChoiceApp => '应用相册';

  @override
  String get galleryChoiceAppDescription => '从应用内部相册选择';

  @override
  String get appMediaUnreadable => '无法读取文件';

  @override
  String appMediaLoadError(Object error) {
    return '加载文件失败：$error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return '清除 ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return '确定 ($count)';
  }

  @override
  String get appMediaConfirmSelection => '确定';

  @override
  String get appMediaEmptyFolder => '此文件夹为空';

  @override
  String get appMediaRoot => '返回根目录';

  @override
  String appMediaParentFolder(Object name) {
    return '返回: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '已选择 $count 个文件';
  }

  @override
  String get chatAlbumPickerTitle => '应用内相册';

  @override
  String get chatAlbumPickerEmpty => '暂无图片';

  @override
  String appAlbumPickerSelectedImages(num count) {
    return '已选择 $count 张图片';
  }

  @override
  String get chatFilePickerTitle => '选择文件';

  @override
  String get chatFilePickerTabText => '文本';

  @override
  String get chatFilePickerTabImages => '图片';

  @override
  String get chatFilePickerTabVideos => '视频';

  @override
  String get chatFilePickerTabAudio => '音频';

  @override
  String get chatFilePickerEmpty => '暂无文件';

  @override
  String get chatFilePickerLoadFailed => '加载失败';

  @override
  String get chatVideoPickerTitle => '选择应用内视频';

  @override
  String get chatVideoPickerEmpty => '暂无视频';

  @override
  String get imagePreviewCrop => '裁剪';

  @override
  String get imagePreviewEdit => '编辑';

  @override
  String get imagePreviewLoadFailed => '无法加载图片';

  @override
  String runningElapsed(Object elapsed) {
    return '已运行 $elapsed';
  }

  @override
  String get chatAttachmentFile => '传文件';

  @override
  String get chatAttachmentCamera => '拍照';

  @override
  String get chatAttachmentDeviceGallery => '设备相册';

  @override
  String get chatAttachmentDeviceFiles => '设备文件';

  @override
  String get chatAttachmentAppFiles => '应用内文件';

  @override
  String fileManagerTodayTime(Object time) {
    return '今天 $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return '昨天 $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days天前 $time';
  }

  @override
  String get markdownGenerating => '正在生成...';

  @override
  String get htmlPreview => '预览';

  @override
  String get htmlReturnToCard => '返回卡片';

  @override
  String get htmlGenerating => '正在生成中...';

  @override
  String get htmlFullscreen => '全屏查看';

  @override
  String get htmlViewCode => '查看代码';

  @override
  String get codeScrollToBottom => '滚动到底部';

  @override
  String get codeSave => '保存';

  @override
  String get codeDisableWrap => '取消换行';

  @override
  String get codeEnableWrap => '换行显示';

  @override
  String codeCopyFailed(Object error) {
    return '复制失败: $error';
  }

  @override
  String get codeCopied => '已复制';

  @override
  String get codeCopy => '复制';

  @override
  String get codeEmptySave => '代码为空，无法保存';

  @override
  String get codeSaveTitle => '保存代码';

  @override
  String codeSavedTo(Object path) {
    return '已保存到: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get fileManagerCopy => '复制';

  @override
  String get fileManagerMove => '移动';

  @override
  String get fileManagerRename => '重命名';

  @override
  String get fileManagerExport => '导出';

  @override
  String get fileManagerDelete => '删除';

  @override
  String get fileManagerAncestorFolders => '祖先文件夹';

  @override
  String get fileManagerRoot => '根目录';

  @override
  String fileManagerSelectedItems(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get fileManagerSelectAll => '全选';

  @override
  String get fileManagerRenameUndo => '上次批量重命名结果与撤销';

  @override
  String fileManagerSortBy(Object field) {
    return '排序（$field）';
  }

  @override
  String get fileManagerSortCreated => '按创建时间';

  @override
  String get fileManagerSortModified => '按修改时间';

  @override
  String get fileManagerSortName => '按文件名';

  @override
  String get fileManagerSortSize => '按大小';

  @override
  String get fileManagerListView => '列表视图';

  @override
  String get fileManagerThumbnailView => '缩略图视图';

  @override
  String get fileManagerCreateFolder => '创建文件夹';

  @override
  String get fileManagerRefresh => '刷新列表';

  @override
  String get fileManagerEmptyFolder => '此文件夹为空';

  @override
  String get fileManagerNoFiles => '暂无文件';

  @override
  String get fileManagerBackRoot => '返回根目录';

  @override
  String fileManagerBackFolder(Object name) {
    return '返回: $name';
  }

  @override
  String get fileManagerMultiSelect => '多选';

  @override
  String get fileManagerOpen => '打开';

  @override
  String get fileManagerPreview => '预览';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '$files 个文件, $folders 个子文件夹';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '$count 个子文件夹';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '$count 个文件';
  }

  @override
  String get fileManagerEmptyFolderLabel => '空文件夹';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return '文件 “$name.$format” 已存在';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return '重命名失败: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => '选择目标文件夹';

  @override
  String get fileManagerAlreadyAtDestination => '文件已在目标位置';

  @override
  String get fileManagerMoveNameConflict => '目标文件夹已存在同名文件，移动已取消';

  @override
  String fileManagerMoveFailed(Object error) {
    return '移动失败: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => '选择复制到的目标文件夹';

  @override
  String fileManagerCopyFailed(Object error) {
    return '复制失败: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => '确认删除';

  @override
  String get fileManagerDeleteFileConfirm => '确定要删除此文件吗？此操作不可恢复。';

  @override
  String get fileManagerCancel => '取消';

  @override
  String fileManagerDeleteFailed(Object error) {
    return '删除失败: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere => '文件夹已在目标位置，操作已取消';

  @override
  String get fileManagerFolderConflict => '所选文件夹在目标位置存在同名冲突或位于自身内部，操作已取消';

  @override
  String get fileManagerBatchDeleteTitle => '确认批量删除';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '确定要删除选中的 $count 项吗？此操作不可恢复。';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return '批量删除失败: $error';
  }

  @override
  String get fileManagerExportConflict => '所选文件与文件夹的导出路径冲突';

  @override
  String get fileManagerSelectedAlreadyThere => '所选文件已在目标位置，移动已取消';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return '批量移动失败: $error';
  }

  @override
  String get fileManagerCopyConflict => '所选文件中存在同名文件，复制已取消（请逐个复制）';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return '批量复制失败: $error';
  }

  @override
  String get fileManagerClosedError => '文件页面已关闭';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return '批量重命名失败：$error';
  }

  @override
  String get fileManagerFolderNameHint => '输入文件夹名称';

  @override
  String get fileManagerCreate => '创建';

  @override
  String get fileManagerFolderExists => '文件夹已存在';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return '创建文件夹失败: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return '文件夹 “$name” 创建成功';
  }

  @override
  String get fileManagerRenameFolderTitle => '重命名文件夹';

  @override
  String get fileManagerNewNameHint => '输入新名称';

  @override
  String get fileManagerTargetFolderConflict => '目标位置已存在同名文件夹，操作已取消';

  @override
  String get fileManagerMoveFolderTitle => '移动文件夹到…';

  @override
  String get fileManagerCopyFolderTitle => '复制文件夹到…';

  @override
  String get fileManagerFolderSelfConflict => '目标位置已存在同名文件夹或为文件夹自身，操作已取消';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return '确定要删除文件夹 “$name” 吗？其中的 $count 个文件也将被删除。';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '确定要删除空文件夹 “$name” 吗？';
  }

  @override
  String get fileManagerDeleteFolderTitle => '确认删除文件夹';

  @override
  String fileManagerRefreshFailed(Object error) {
    return '刷新失败: $error';
  }

  @override
  String get fileManagerRefreshed => '文件列表已刷新';

  @override
  String get fileManagerRenameFileTitle => '重命名文件';

  @override
  String get fileManagerFormat => '格式';

  @override
  String get fileManagerFolderAtDestination => '文件夹已在目标位置';

  @override
  String get folderPickerTitle => '选择文件夹';

  @override
  String get folderPickerExists => '文件夹已存在';

  @override
  String folderPickerCreateFailed(Object error) {
    return '创建文件夹失败: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return '刷新文件夹列表失败: $error';
  }

  @override
  String get folderPickerInstruction => '单击选中，双击进入查看子文件夹';

  @override
  String get folderPickerFileName => '文件名';

  @override
  String get folderPickerFileNameHint => '输入文件名';

  @override
  String get folderPickerBack => '返回上级';

  @override
  String folderPickerPath(Object path) {
    return '根目录 > $path';
  }

  @override
  String get folderPickerRoot => '根目录';

  @override
  String get folderPickerCurrentFolder => '当前文件夹';

  @override
  String get folderPickerSubfolders => '子文件夹';

  @override
  String get folderPickerExistingFolders => '现有文件夹';

  @override
  String get folderPickerCreateNew => '创建新文件夹';

  @override
  String get folderPickerFolderNameHint => '输入文件夹名称';

  @override
  String get folderPickerCancelCreate => '取消新建';

  @override
  String get folderPickerCancel => '取消';

  @override
  String get folderPickerConfirm => '确定';

  @override
  String batchRunReadFailed(Object error) {
    return '无法读取文件列表：$error';
  }

  @override
  String get batchRunPreparing => '准备中…';

  @override
  String get batchRunUndo => '撤销';

  @override
  String get batchRunRename => '重命名';

  @override
  String batchRunFailedAction(Object label) {
    return '未能执行$label';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '已$label $count 项';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label：成功 $completed 项，失败 $failed 项，剩余 $remaining 项';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return '失败：$id → $name';
  }

  @override
  String get batchRunReportCopied => '已复制执行报告';

  @override
  String get batchRunCopyFailed => '复制失败，请重试';

  @override
  String batchRunWorking(Object label) {
    return '正在$label…';
  }

  @override
  String get batchRunTitle => '批量重命名结果';

  @override
  String get batchRunStoppedRetain => '停止后会保留当前已完成的项目，可在结果页撤销。';

  @override
  String get batchRunFailedRemaining => '失败；后续项目未执行';

  @override
  String get batchRunUndoInfo => '撤销会恢复本次已成功项目的原名；后续列表变化时将拒绝撤销。';

  @override
  String get batchRunUncertain => '有项目状态无法确认，请检查文件列表；为避免覆盖，不提供自动撤销。';

  @override
  String get batchRunUndoing => '正在恢复原名，请稍候';

  @override
  String get batchRunStopping => '正在停止…';

  @override
  String get batchRunStopRemaining => '停止后续操作';

  @override
  String get batchRunCopyReport => '复制报告';

  @override
  String batchRunUndoRemaining(Object count) {
    return '继续撤销剩余 $count 项';
  }

  @override
  String get batchRunUndoCompleted => '撤销已完成改名';

  @override
  String get batchRunDone => '完成';

  @override
  String get codeEditorTitle => '编辑参数值';

  @override
  String get codeEditorFormat => '格式化';

  @override
  String get codeEditorCancel => '取消';

  @override
  String get codeEditorConfirm => '确定';

  @override
  String get codeEditorInvalidJson => 'JSON 格式有误，请修正后再保存';

  @override
  String get codeEditorParamPath => '参数名路径（请求时展开为嵌套 JSON）';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return '第 $line 行第 $column 列: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON 格式错误: $message';
  }

  @override
  String get codeEditorInvalidFormat => 'JSON 格式不正确';

  @override
  String get toolCallCompacted => '已压缩';

  @override
  String get mermaidSaveEmpty => 'Mermaid 代码为空，无法保存';

  @override
  String mermaidFolderLoadFailed(String error) {
    return '获取文件夹失败: $error';
  }

  @override
  String get mermaidSaveTitle => '保存 Mermaid 图表';

  @override
  String get mermaidSaveHint => '选择或创建文件夹保存 .mmd 文件';

  @override
  String get mermaidSaveFilenameHint => '输入文件名（自动添加 .mmd 后缀）';

  @override
  String get mermaidFilenameEmpty => '文件名不能为空';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return '已保存到文本储存区: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get mermaidPrepareEngine => '正在准备渲染引擎...';

  @override
  String get mermaidRetry => '重试';

  @override
  String get batchRuleEmpty => '不能为空';

  @override
  String get batchRuleNumber => '请输入数字';

  @override
  String get batchRulePositive => '请输入大于 0 的数字';

  @override
  String batchRuleMin(String min) {
    return '不能小于 $min';
  }

  @override
  String batchRuleMax(String max) {
    return '不能大于 $max';
  }

  @override
  String get batchRulePrefix => '前缀';

  @override
  String get batchRuleSuffix => '后缀';

  @override
  String get batchRuleStart => '起始';

  @override
  String get batchRuleStep => '步长';

  @override
  String get batchRuleDigits => '位数';

  @override
  String get batchRuleSeparator => '分隔符';

  @override
  String get batchRuleRestartFolder => '每个目录重新编号';

  @override
  String get batchRuleNumberHelp => '编号按预览顺序分配；排除项不占序号。步长可为负数或 0。';

  @override
  String get batchRuleFind => '查找内容';

  @override
  String get batchRuleReplace => '替换为（留空删除）';

  @override
  String get batchRuleCaseSensitive => '区分大小写';

  @override
  String get batchRuleRegex => '正则表达式';

  @override
  String get batchRuleFirstOnly => '仅替换首次匹配';

  @override
  String get batchRuleRegexHelp =>
      '捕获组：\$1、\$2；完整匹配：\$0；字面 \$：\$\$。例如 ^IMG_(\\d+)\$ → 照片_\$1';

  @override
  String get batchRuleFindRequired => '填写查找内容后生效。';

  @override
  String get batchRuleBeginning => '开头';

  @override
  String get batchRuleEnd => '结尾';

  @override
  String get batchRulePosition => '指定位置';

  @override
  String get batchRuleInsertText => '插入文本';

  @override
  String get batchRuleBeforeChar => '第 N 个字符前';

  @override
  String get batchRulePositionHelp => '位置从 1 开始；超过末尾时追加。组合 emoji 按一个字符计算。';

  @override
  String get batchRuleFromBeginning => '从开头';

  @override
  String get batchRuleFromEnd => '从结尾';

  @override
  String get batchRuleFromChar => '从第 N 个字符起';

  @override
  String get batchRuleCount => '数量';

  @override
  String get batchRuleDeleteHelp => '名称删空后需由后续插入规则补充，才能执行。';

  @override
  String get batchRuleUpper => '全大写';

  @override
  String get batchRuleLower => '全小写';

  @override
  String get batchRuleFirstUpper => '首字母大写';

  @override
  String get batchRuleTitleCase => '每词首字母大写';

  @override
  String get batchRuleTemplate => '新名称模板';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return '课程_${n}_$name';
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
    return '$name 原名 · $n 序号 · $folder 所在目录名\n$created 创建日期 · $modified 修改日期 · $ext 原扩展名\n日期格式 YYYY-MM-DD；缺少日期时会提示。模板替换整个基础名，扩展名仍自动保留。';
  }

  @override
  String get batchRuleTrim => '去掉首尾空白';

  @override
  String get batchRuleCollapseSpaces => '连续空白合并为一个空格';

  @override
  String get batchRuleActions => '规则操作';

  @override
  String get batchRuleDuplicate => '复制规则';

  @override
  String get batchRuleRemove => '删除规则';

  @override
  String get batchRuleMoveUp => '上移规则';

  @override
  String get batchRuleMoveDown => '下移规则';

  @override
  String get batchDlgSavePreset => '保存重命名方案';

  @override
  String get batchDlgPresetName => '方案名称';

  @override
  String get batchDlgPresetHint => '保存规则及顺序，不包含排除项或手动名称';

  @override
  String get batchDlgCancel => '取消';

  @override
  String get batchDlgSave => '保存';

  @override
  String get batchDlgOverwriteTitle => '覆盖已有方案？';

  @override
  String batchDlgOverwriteBody(String name) {
    return '将更新“$name”的规则。';
  }

  @override
  String get batchDlgOverwrite => '覆盖';

  @override
  String get batchDlgManagePresets => '管理方案';

  @override
  String get batchDlgNoPresets => '尚未保存方案';

  @override
  String get batchDlgDeletePreset => '删除方案';

  @override
  String get batchDlgDone => '完成';

  @override
  String get batchDlgEditName => '单独修改名称';

  @override
  String get batchDlgBaseName => '基础名称';

  @override
  String get batchDlgOverrideHelp => '此名称覆盖规则结果';

  @override
  String batchDlgExtensionRetained(String extension) {
    return '扩展名 .$extension 自动保留';
  }

  @override
  String get batchDlgConfirm => '确定';

  @override
  String get batchDlgHelp => '使用说明';

  @override
  String get batchDlgClose => '关闭';

  @override
  String get batchDlgLoadPreset => '加载方案（替换规则并清除手动名称）';

  @override
  String get batchDlgLoad => '加载方案';

  @override
  String get batchDlgSaving => '保存中…';

  @override
  String get batchDlgReset => '重置全部规则与参与项目';

  @override
  String get batchDlgRuleInstructions => '规则从上到下依次执行；可复制、移动或关闭。扩展名保持不变。';

  @override
  String get batchDlgSortName => '名称';

  @override
  String get batchDlgSortCreated => '创建时间';

  @override
  String get batchDlgSortModified => '修改时间';

  @override
  String get batchDlgSortSize => '大小';

  @override
  String get batchDlgAscending => '升序';

  @override
  String get batchDlgDescending => '降序';

  @override
  String get batchDlgFolderSort => '文件夹在前；同名按所在目录排序。';

  @override
  String get batchDlgAddRule => '＋ 添加规则';

  @override
  String get batchDlgMaxRules => '最多 50 条规则';

  @override
  String get batchDlgPreviewWorking => '正在计算预览，可继续修改规则或取消…';

  @override
  String get batchDlgSearch => '搜索原名、新名或所在目录';

  @override
  String get batchDlgFilterAll => '全部';

  @override
  String get batchDlgFilterChanged => '有更改';

  @override
  String get batchDlgFilterErrors => '有问题';

  @override
  String get batchDlgFilterUnchanged => '未变化';

  @override
  String get batchDlgFilterExcluded => '已排除';

  @override
  String get batchDlgParticipants => '选择参与项目';

  @override
  String get batchDlgIncludeAll => '全部参与';

  @override
  String get batchDlgOnlyFiles => '仅文件';

  @override
  String get batchDlgOnlyFolders => '仅文件夹';

  @override
  String get batchDlgExcludeAll => '全部排除';

  @override
  String get batchDlgScope => '参与范围';

  @override
  String get batchDlgCopyList => '复制清单';

  @override
  String get batchDlgConflictBlock => '同名冲突：阻止执行';

  @override
  String get batchDlgConflictSuffix => '同名冲突：追加 (2)、(3)…';

  @override
  String get batchDlgNoMatches => '没有符合筛选条件的项目';

  @override
  String get batchDlgRoot => '根目录';

  @override
  String get batchDlgFile => '文件';

  @override
  String get batchDlgFolder => '文件夹';

  @override
  String batchDlgTargetFolder(String folder) {
    return '目标目录：$folder';
  }

  @override
  String get batchDlgEditNameTooltip => '单独修改名称';

  @override
  String get batchDlgRestoreNameTooltip => '恢复规则生成的名称';

  @override
  String get batchDlgCopied => '已复制完整预览清单（CSV）';

  @override
  String get batchDlgCopyFailed => '复制失败，请重试';

  @override
  String get batchDlgHelpTitle => '批量重命名使用说明';

  @override
  String get batchDlgHelpDismiss => '知道了';

  @override
  String get batchDlgRulesTab => '规则';

  @override
  String batchDlgPreviewTab(String count) {
    return '预览（$count）';
  }

  @override
  String batchDlgRenameCount(String count) {
    return '重命名 $count 项';
  }

  @override
  String get batchDlgPresetLoadFailed => '暂时无法读取方案，仍可编辑和执行规则';

  @override
  String get batchDlgPreviewFailed => '预览计算失败，请调整规则后重试';

  @override
  String batchDlgSavedName(String name) {
    return '已保存方案：$name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get batchDlgPresetWriteFailed => '无法保存方案';

  @override
  String batchDlgDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get batchDlgSavePresetFallback => '保存方案';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return '预览 · $changes 项更改 · $conflicts 项问题 · $excluded 项排除';
  }

  @override
  String get batchDlgInvalidInput => '请修正规则中的输入；当前预览尚未采用无效输入。';

  @override
  String get batchDlgConflictError => '存在冲突或非法名称，无法应用。请调整规则。';

  @override
  String get batchDlgManualNameStatus => '手动名称';

  @override
  String get batchDlgPendingRename => '待重命名';

  @override
  String get batchDlgCsvHeader => '原路径,原名称,目标路径,状态';

  @override
  String get batchDlgHelpBody =>
      '1. 选择方案或启用规则，按需复制规则并调整上下顺序。\n\n2. 预览显示实际执行的名称。搜索与筛选只影响显示；取消勾选会排除该项并重新编号。可单独修改名称，或恢复为规则结果。\n\n3. 所有问题解决后才能执行。自动后缀只处理重名，不会覆盖其他文件。互换文件夹名称需要分批改名。\n\n4. 执行中可停止后续项目；当前项目会先完成。完成页显示结果，可撤销本次已完成的改名。列表发生后续变化时会阻止撤销。\n\n仅修改名称及目录路径，文件内容和扩展名保持不变。排除父目录自身的改名不会阻止已勾选子项改名；父目录改名时其内部路径仍会随之移动。';

  @override
  String batchDlgPreviewCount(String count) {
    return '预览（$count）';
  }

  @override
  String get batchBuiltinPhoto => '照片：日期与编号';

  @override
  String get batchBuiltinCourse => '课程：统一名称与编号';

  @override
  String get batchBuiltinDownloads => '下载文件：清理空白';

  @override
  String get taskListDetail => '详情';

  @override
  String get taskListOwnershipChecking => '正在确认任务归属';

  @override
  String get taskListOwnershipFailed => '任务流记录读取失败，操作暂不可用';

  @override
  String get taskListViewFlow => '查看任务流';

  @override
  String get taskListPause => '暂停';

  @override
  String get taskListClear => '清除任务';

  @override
  String get taskListResume => '继续';

  @override
  String get taskListRetry => '重试';

  @override
  String get taskListDismissError => '关闭错误信息';

  @override
  String get taskListRemove => '从列表移除';

  @override
  String get taskListSynthesisErrorTitle => '合成错误详情';

  @override
  String get taskListClose => '关闭';

  @override
  String get taskListOriginalExchange => '原始请求与响应';

  @override
  String get taskListOriginalRequest => '原始请求体:';

  @override
  String get taskListOriginalResponse => '原始响应体:';

  @override
  String get taskFlowIoTypeText => '文本';

  @override
  String get taskFlowIoTypeAudio => '音频';

  @override
  String get taskFlowIoTypeVideo => '视频';

  @override
  String get taskFlowIoTypeImage => '图片';

  @override
  String get taskFlowIoTypeLink => '链接';

  @override
  String get taskFlowIoTypeFile => '文件';

  @override
  String get taskFlowIoTypeAny => '任意';

  @override
  String get mermaidZoomOut => '缩小';

  @override
  String get mermaidZoomIn => '放大';

  @override
  String get mermaidFullscreen => '全屏';

  @override
  String get mermaidSaveButton => '保存';

  @override
  String get mermaidSourceButton => '查看源码';

  @override
  String get mermaidDiagramSemantic => '查看图表';

  @override
  String get taskFlowCardCatCatchDeletePersistError => '猫抓子任务删除状态无法保存，请重试';

  @override
  String get taskFlowCardSynthesisDeletePersistError => '合成子任务删除状态无法保存，请重试';

  @override
  String get taskFlowCardBackgroundDeletePersistError => '后台子任务删除状态无法保存，请重试';

  @override
  String get mathParseError => '数学解析错误';

  @override
  String get mermaidEmptyPlaceholder => '没有可渲染的 Mermaid 代码';

  @override
  String get mathClose => '关闭';

  @override
  String get mermaidLoadTimeout => 'Mermaid 加载超时：请检查网络连接后重试';

  @override
  String get mermaidCdnLoadFailed => 'Mermaid 加载失败：无法访问 cdn.jsdelivr.net';

  @override
  String get mermaidLoadingDiagram => '图表加载中...';

  @override
  String get mermaidEngineInitFailed => '图表渲染引擎初始化失败，请重试';

  @override
  String get mermaidPageTimeout => '页面加载超时，请重试';

  @override
  String get mermaidCodeLoadFailed => '图表代码加载失败，请重试';

  @override
  String mermaidPageLoadFailed(String description) {
    return '页面加载失败: $description';
  }

  @override
  String get mermaidLoadingEngine => '加载渲染引擎...';

  @override
  String get mermaidRenderErrorTitle => '渲染图表时出错';

  @override
  String get taskFlowOutputVideoAudioDownstream => '视频或音频（按下游筛选）';

  @override
  String get taskFlowOutputUnknown => '未知';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label已停止：成功 $completed 项，失败 $failed 项，未执行 $remaining 项';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Mermaid 渲染错误：$message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Mermaid 初始化错误：$message';
  }

  @override
  String get mermaidResourceError => 'Mermaid 图表中的资源加载失败。';

  @override
  String get taskFlowParamRecognitionModel => '识别模型';

  @override
  String get taskFlowParamSynthesisModel => '合成模型';

  @override
  String get taskFlowParamSaveFolder => '保存文件夹';

  @override
  String get taskFlowParamResourceSelection => '资源选择方式';

  @override
  String get taskFlowParamOutputType => '输出类型';

  @override
  String get taskFlowParamVideoFolder => '视频保存文件夹';

  @override
  String get taskFlowParamAudioFolder => '音频保存文件夹';

  @override
  String get taskFlowParamExpectedDuration => '预期时长';

  @override
  String get taskFlowParamVoice => '语音';

  @override
  String get taskFlowParamSpeechRate => '语速';

  @override
  String get taskFlowParamAssistant => '助手';

  @override
  String get taskFlowHintResourceSelection =>
      '手动模式由你选择；自动模式按既有规则确定选择；自动并询问会在唯一安全资源时自动选择，否则打开资源列表让你确认。';

  @override
  String get taskFlowHintOutputType =>
      '视频或音频可显式指定；跟随下游时按下一功能块的输入类型筛选资源。下游接受两种类型或没有下游时，两种类型都会保留。';

  @override
  String get taskFlowHintExpectedDuration => '按视频时长筛选，留空表示不筛选。';

  @override
  String get taskFlowHintVoice => '选择音色（选择后自动切换到对应模型）。';

  @override
  String get taskFlowUiUnsupportedBlockStep => '此功能块类型已不受支持，请替换或删除此步骤。';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return '下一步需要$requiredType。下载资源可输出视频或音频，请修改下一步或输出策略。';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source为任意类型，但“$block”需要明确的文本、链接、图片、音频、视频或文件类型。请修改输入类型、移动或替换功能块，或撤销更改。';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source为$actualType，但“$block”需要$requiredType。请修改输入类型、移动或替换功能块，或撤销更改。';
  }

  @override
  String get fileManagerSortFieldCreated => '创建时间';

  @override
  String get fileManagerSortFieldModified => '修改时间';

  @override
  String get fileManagerSortFieldName => '文件名';

  @override
  String get fileManagerSortFieldSize => '大小';

  @override
  String get fileManagerSortDateNewest => '新到旧';

  @override
  String get fileManagerSortDateOldest => '旧到新';

  @override
  String get fileManagerSortSizeLargest => '大到小';

  @override
  String get fileManagerSortSizeSmallest => '小到大';

  @override
  String get catcatchStatusRunning => '运行中';

  @override
  String get catcatchStatusCompleted => '已完成';

  @override
  String get catcatchStatusFailed => '失败';

  @override
  String get catcatchStatusPaused => '已暂停';

  @override
  String get catcatchStatusWaiting => '等待中';

  @override
  String get catcatchStepFetching => '获取网页内容';

  @override
  String get catcatchStepAnalyzing => '分析媒体资源';

  @override
  String get catcatchStepParsingPlaylist => '解析播放列表';

  @override
  String get catcatchStepFiltering => '按时长筛选';

  @override
  String get catcatchStepUserSelecting => '等待用户选择';

  @override
  String get catcatchStepDownloading => '下载';

  @override
  String get catcatchStepConverting => '转码/合并';

  @override
  String get catcatchStepSaving => '保存到本地';

  @override
  String get bgStepConnectServer => '连接服务器';

  @override
  String get bgStepUploadImage => '上传图片';

  @override
  String get bgStepWaitRecognition => '等待识别结果';

  @override
  String get bgStepParseResult => '解析结果';

  @override
  String get bgStepSaveFile => '保存文件';

  @override
  String get bgStepUploadAudio => '上传音频';

  @override
  String get bgStepTranscribing => '转写中';

  @override
  String get bgStepReceiveResult => '接收结果';

  @override
  String get bgStepSeparateAudio => '分离音频';

  @override
  String get bgStepSaveToFile => '保存到文件';

  @override
  String get bgStepSendRequest => '发送请求';

  @override
  String get bgStepWaitReply => '等待回复';

  @override
  String get fileManagerSortNameAscending => 'A 到 Z';

  @override
  String get fileManagerSortNameDescending => 'Z 到 A';

  @override
  String get taskFlowValidationNoSteps => '任务流没有步骤，请先添加功能块。';

  @override
  String get taskFlowValidationInputRequired => '请添加运行输入。';

  @override
  String get taskFlowValidationFlowRemoved => '任务流已删除，请重新选择。';

  @override
  String get taskFlowValidationInputTypeChanged => '初始输入类型已修改，请重新选择运行输入。';

  @override
  String get taskFlowValidationSnapshotMissing => '旧记录没有运行快照，请选择使用最新配置重试。';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      '助手模型未选择或不可用，请先在对话页选择模型或给助手设置默认模型。';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      '已保存的步骤文件不存在、为空或无法读取，请重新运行。';

  @override
  String get taskFlowValidationUnsupportedBlock => '功能块已不受支持，请替换或删除此步骤。';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return '下一步需要$requiredType。下载资源可输出音频或视频，请修改下一步或输出策略。';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '“$parameter”为必填项，请在“$block”设置中配置。';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return '旧版模型选择需要确认，请在“$block”设置中重新选择模型。';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return '模型未选择、已删除或供应商配置不可用，请在“$block”设置中重新选择模型并检查供应商地址和密钥。';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return '助手未选择或已删除，请在“$block”设置中重新选择助手。';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      '助手绑定的模型已删除或供应商配置不可用，请在助手设置中重新选择模型。';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return '资源选择策略或输出类型无效，请在“$block”设置中重新选择。';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return '输出类型无效，请在“$block”设置中重新选择。';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return '资源选择策略无效，请在“$block”设置中重新选择。';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return '第 $index 个输入：文件不存在、为空或无法读取，请重新选择文件。';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return '第 $index 个输入：请输入有效的 HTTP 或 HTTPS 链接。';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return '第 $index 个输入：$error';
  }

  @override
  String get batchRuleValidationMaxRules => '最多支持 50 条规则。';

  @override
  String get batchRuleValidationDigits => '编号位数应为 1–12。';

  @override
  String get batchRuleValidationNumberRange => '编号起始值和步长须在 ±999999999 以内。';

  @override
  String get batchRuleValidationReplacementLength => '替换规则过长。';

  @override
  String get batchRuleValidationRegex => '正则表达式无效。';

  @override
  String get batchRuleValidationDeleteIndex => '删除位置必须从 1 开始。';

  @override
  String get batchRuleValidationInsertLength => '插入文本过长。';

  @override
  String get batchRuleValidationTemplateNumber =>
      '模板编号设置无效：位数 1–12，起始和步长在 ±999999999 以内。';

  @override
  String get batchRuleValidationTemplateLength => '模板过长。';

  @override
  String get batchRuleValidationTemplateVariable => '未知模板变量或未闭合的大括号。';

  @override
  String get batchRuleTypeNumber => '编号';

  @override
  String get batchRuleTypeReplace => '替换';

  @override
  String get batchRuleTypeInsert => '插入文本';

  @override
  String get batchRuleTypeDelete => '删除字符';

  @override
  String get batchRuleTypeCase => '大小写转换';

  @override
  String get batchRuleTypeTemplate => '命名模板';

  @override
  String get batchRuleTypeCleanup => '清理空白';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return '第 $index 个输入：请输入文本或选择文件。';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return '第 $index 个输入：图片超过 20 MB，请选择较小的图片。';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return '第 $index 个输入：附件超过 10 MB，请选择较小的文件。';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return '第 $index 个输入：文件实际类型为$actualType，需要$requiredType，请重新选择文件。';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return '第 $index 个输入：助手对话不支持 SVG 图片附件，请转换为 PNG 或 JPEG。';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return '第 $index 个输入：助手对话不支持 $mime 图片附件，请转换为 PNG、JPEG、GIF 或 WebP。';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return '第 $index 个输入：助手对话不支持 $mime 音频附件，请转换为 MP3、WAV 或 M4A。';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return '第 $index 个输入：此助手的 Anthropic 对话格式不支持$type附件，请选择支持此媒体的助手。';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return '第 $index 个输入：此助手的 Anthropic 对话格式只支持图片和 PDF 附件，请选择支持此文件的助手。';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return '第 $index 个输入：助手对话图片无法压缩到 10 MB 以下，请选择较小图片。';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return '第 $index 个输入：文本附件不是有效的 UTF-8 编码，请转换后重试。';
  }

  @override
  String get assistantParamValueTypeString => '字符串';

  @override
  String get assistantParamValueTypeNumber => '数字';

  @override
  String get assistantParamValueTypeBoolean => '布尔值';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields => '供应商名称、API 地址和密钥均为必填项。';

  @override
  String get providerJsonSizePositive => '请求 JSON 大小必须是大于 0 的 MiB 数值。';

  @override
  String get providerCustomParamRequired => '自定义参数的名称和值不能为空。';

  @override
  String providerParamNameInvalid(String name) {
    return '参数名格式不正确（点号分段不能为空）：$name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return '参数已存在：$name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return '参数“$name”的默认值不是合法 JSON：$value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return '参数“$name”的数值选项不能为空。';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return '参数“$name”的值不是合法数字：$value';
  }

  @override
  String get providerReasoningIncomplete => '请先完整填写推理开关，其他推理参数才能生效。';

  @override
  String providerReasoningError(String error) {
    return '推理参数错误：$error';
  }

  @override
  String providerParamNameConflict(String name) {
    return '推理参数与自定义参数重名：$name';
  }

  @override
  String get providerMaxTokensMissing => '已启用最大输出 Token 数，但未填写数值。';

  @override
  String get providerMaxTokensPositive => '最大输出 Token 数必须为正整数。';

  @override
  String get providerSeedInteger => '随机种子必须为整数。';

  @override
  String get providerNotConfigured => '未设置';

  @override
  String get providerAudioChunkingTitle => '音频切块';

  @override
  String get providerAudioChunkingHint => '智能切块会分析音频和候选切点，优先在句末切分；各片段不会重叠。';

  @override
  String get providerChunkingMode => '切块方式';

  @override
  String get providerChunkNone => '不切块';

  @override
  String get providerChunkSmart => '智能切块（推荐）';

  @override
  String get providerChunkFixedDuration => '固定时长切块';

  @override
  String get providerChunkFixedSize => '固定大小切块';

  @override
  String get providerCompressionTitle => '压缩编码';

  @override
  String get providerCompressionHint =>
      '启用后，通用兜底会先压缩完整 WAV；若编码文件或请求体仍超限，再切分源 PCM 并逐块编码。';

  @override
  String get providerCompressionMode => '压缩方式';

  @override
  String get providerCompressionNone => '无（原样发送）';

  @override
  String get providerCompressionAdpcm => 'ADPCM（约 4 倍压缩）';

  @override
  String get providerCompressionFlac => 'FLAC（无损，约 2 倍）';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM，4:1 有损压缩。纯 Dart 实现，音质适合语音转写。';

  @override
  String get providerCompressionFlacDescription =>
      'FLAC 无损压缩，纯 Dart 实现，体积约缩小一半。';

  @override
  String get providerCompressionWavDescription => '不压缩，以 WAV 文件原样发送。';

  @override
  String get providerLlmParams => 'LLM 参数';

  @override
  String get providerEnabledParamsHelp => '开启的参数将作为默认值发送到 API 请求中。';

  @override
  String get providerTemperatureLabel => '温度';

  @override
  String get providerTemperatureHelp => '控制输出的随机性，值越高越有创造性。';

  @override
  String get providerTopPHelp => '核采样参数，控制词汇选择的累积概率。';

  @override
  String get providerFrequencyPenaltyLabel => '频率惩罚';

  @override
  String get providerFrequencyPenaltyHelp => '减少重复词，负值会增加重复。';

  @override
  String get providerPresencePenaltyLabel => '存在惩罚';

  @override
  String get providerPresencePenaltyHelp => '鼓励讨论新话题，负值会鼓励重复话题。';

  @override
  String get providerMaxOutputTokensLabel => '最大输出 Token 数';

  @override
  String providerOptionalExample(String example) {
    return '可选，例如 $example';
  }

  @override
  String get providerResponseTokensHelp => '每次响应最多生成的 Token 数。';

  @override
  String get providerSeedLabel => '随机种子';

  @override
  String get providerSeedHelp => '设置后可使输出结果可复现。';

  @override
  String get providerChunkSmartDescription =>
      '分析音频和候选切点，优先在句末或长静音处切分且不重叠。默认最短 20 秒、目标 45 秒、最长 60 秒。仅由通用兜底使用；压缩切块仅支持 PCM WAV。';

  @override
  String get providerChunkDurationDescription =>
      '每 N 秒切分一次（默认 60 秒）。方式简单，但可能截断语句。仅由通用兜底使用；压缩切块仅支持 PCM WAV。';

  @override
  String get providerChunkSizeDescription =>
      '先按音频数据大小初步切分，再根据编码文件和请求体大小细分。仅由通用兜底使用；压缩切块仅支持 PCM WAV。';

  @override
  String get providerChunkNoneDescription => '不切块。完整压缩后仍超出限制时，将拒绝该文件。';

  @override
  String get providerNameLabel => '供应商名称';

  @override
  String get providerNameHint => '输入供应商名称';

  @override
  String get providerApiUrlLabel => 'API 地址';

  @override
  String get providerApiUrlHint => '输入完整的 API 端点地址';

  @override
  String providerApiKeyHint(String hint) {
    return '提示：$hint';
  }

  @override
  String get providerEndpointTypeLabel => '端点类型';

  @override
  String get providerEndpointOpenAi => '兼容 OpenAI（Chat Completions）';

  @override
  String get providerEndpointAnthropic => 'Anthropic 格式（Messages API）';

  @override
  String get providerAnthropicEndpointHelp =>
      '使用官方 Anthropic Messages API 格式（x-api-key 请求头）。API 地址示例：https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      '使用官方 OpenAI Chat Completions 兼容格式（Bearer 请求头）。API 地址示例：https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => '请求 JSON 大小默认值';

  @override
  String get providerUseAppDefault => '留空则使用应用默认值';

  @override
  String get providerModelJsonBudgetHelp =>
      '模型可单独设置覆盖值；此处和模型均未设置时，使用 20 MiB 默认值。';

  @override
  String get providerRequestParamsHelp =>
      '请求会使用供应商和模型中所有已启用的参数。若参数重名，则以模型参数值为准。';

  @override
  String get providerUploadSettings => '上传设置';

  @override
  String get providerUploadMethodHelp => '不同供应商支持的音频上传方式和大小限制不同。';

  @override
  String get providerUploadMethod => '上传方式';

  @override
  String get providerMultipart => 'Multipart（通用）';

  @override
  String get providerUrlUpload => 'URL（链接）';

  @override
  String get providerMaxUploadSize => '最大上传大小';

  @override
  String get providerFallbackStrategy => '兜底策略';

  @override
  String get providerFallbackMethod => '兜底方式';

  @override
  String get providerPreprocessing => '音频预处理';

  @override
  String get providerPreprocessingHelp => '降低音频文件大小，不影响转写准确率。';

  @override
  String get providerPreprocessingMethod => '预处理方式';

  @override
  String get providerUploadMultipartHelp =>
      '直接以 multipart/form-data 上传。请求体包括音频、表单字段和分段边界。';

  @override
  String get providerUploadBase64Help =>
      '以 JSON 发送 Base64，可绕过部分供应商对 multipart 的专属限制。Base64 膨胀和 JSON 字段均计入上传上限。';

  @override
  String get providerUploadUrlHelp =>
      '提供公网 URL，由供应商下载。支持较大的文件（例如 Together AI 的 1 GB）。';

  @override
  String get providerUploadBudgetHelp =>
      '此值用于触发原始音频兜底并限制最终请求体。应用会分别检查原始音频、编码文件和上传大小。Multipart 计入表单字段和边界；Base64 JSON 计入编码膨胀和字段。默认 25 MB 与 OpenAI 音频 API 上限一致。';

  @override
  String get providerFallbackTriggerHelp =>
      '原始音频或完整请求体超出上限时触发。特定兜底（Base64）优先于通用兜底（压缩/切块）。';

  @override
  String get providerFallbackNone => '无（直接拒绝）';

  @override
  String get providerFallbackSpecific => '特定兜底（Base64）';

  @override
  String get providerFallbackGeneric => '通用兜底（压缩/切块）';

  @override
  String get providerFallbackAll => '全部尝试（推荐）';

  @override
  String get providerFallbackSpecificHelp =>
      '尝试 Base64 JSON。只有计入 Base64 膨胀和 JSON 字段后的请求体未超限时才发送。';

  @override
  String get providerFallbackGenericHelp =>
      '若已启用压缩，则先压缩完整 WAV。仍超限且已启用切块时，再切分源 PCM 并逐块编码。仅支持 PCM WAV。';

  @override
  String get providerFallbackAllHelp =>
      '先尝试符合请求体上限的 Base64；然后在启用压缩时压缩完整 WAV。若仍超限且已启用切块，则切分源 PCM 并逐块编码。仅支持 PCM WAV。';

  @override
  String get providerFallbackRejectHelp => '文件超出限制时直接拒绝，不尝试兜底。';

  @override
  String get providerPreprocessNone => '无';

  @override
  String get providerPreprocessResample => 'WAV 优化（16 kHz 单声道）';

  @override
  String get providerPreprocessResampleHelp =>
      '重采样至 16 kHz 并混合为单声道。文件大小约缩小 4–6 倍，基本不影响转写准确率。';

  @override
  String get providerPreprocessNoneHelp => '不进行预处理，原样发送。';

  @override
  String get assistantDefaultsScopeHelp =>
      '默认模型和工具仅用于在此助手下新建的话题。现有话题保留各自设置。工具结果截断适用于全部话题。';

  @override
  String get assistantDefaultModelTitle => '默认模型';

  @override
  String get assistantDefaultModelHelp => '新话题使用的模型；留空则不指定默认模型。';

  @override
  String get assistantNoDefault => '暂不设置';

  @override
  String get assistantNoModelsAvailable => '暂无可用模型，请在设置中配置 LLM 供应商。';

  @override
  String get assistantDefaultToolsTitle => '默认启用工具';

  @override
  String get assistantDisabledToolsHelp => '已关闭的工具不会在新话题中自动启用。';

  @override
  String get assistantUnconfiguredToolsHelp => '尚未配置默认工具；新话题将自动启用全部工具。';

  @override
  String get assistantEnableAll => '全部启用';

  @override
  String get assistantDisableAll => '全部关闭';

  @override
  String get assistantNoToolsAvailable => '暂无可用工具';

  @override
  String get assistantTruncateToolOutput => '工具结果截断';

  @override
  String get assistantTruncateToolOutputHelp =>
      '发送给模型前，单个工具结果的最大字符数。适用于此助手下的全部话题。';

  @override
  String get assistantEnableTruncation => '启用截断';

  @override
  String assistantTruncatedTo(String count) {
    return '超长结果将截断至 $count 个字符';
  }

  @override
  String get assistantSendFullResult => '完整发送（仍受 50 KB 存储上限约束）';

  @override
  String get assistantMaxCharacters => '最大字符数';

  @override
  String get assistantCharactersNotTokens => '单位：字符（不是 token）';

  @override
  String assistantDefaultCharacterCount(String count) {
    return '默认值：$count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return '有效范围：$minimum–$maximum 个字符';
  }

  @override
  String get assistantNewConversationPreview => '新建话题效果';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '已启用 $enabled / $total 个';
  }

  @override
  String get assistantAllToolsAutoEnabled => '全部自动启用（未配置）';

  @override
  String get assistantMoreActions => '更多操作';

  @override
  String get assistantChooseEmoji => '选择表情';

  @override
  String get assistantNameLabel => '助手名称';

  @override
  String get assistantDescriptionOptional => '描述（可选）';

  @override
  String get assistantSelectionTitle => '选择助手';

  @override
  String get assistantMarketTooltip => '助手市场';

  @override
  String get assistantDefaultPrompt => '你是一个有帮助的AI助手。请用中文回答用户的问题。';

  @override
  String get assistantCreateNew => '新建助手';

  @override
  String get assistantEmptyState => '暂无助手，请先创建。';

  @override
  String get assistantCreate => '创建';

  @override
  String get assistantReorderHint => '长按并拖动即可调整助手顺序';

  @override
  String get assistantNewNameHint => '输入助手名称';

  @override
  String get assistantNewDescriptionHint => '简要描述此助手的功能';

  @override
  String get assistantDeleteTitle => '删除助手';

  @override
  String assistantDeleteConfirmation(String name) {
    return '确定要删除助手“$name”吗？此操作无法撤销。';
  }

  @override
  String get assistantEditTitle => '编辑助手';

  @override
  String get assistantBasicTab => '基本设置';

  @override
  String get assistantParametersTab => '参数设置';

  @override
  String get assistantDefaultsTab => '默认设置';

  @override
  String get assistantAddCustomParameter => '添加自定义参数';

  @override
  String get assistantEditCustomParameter => '编辑自定义参数';

  @override
  String get assistantParameterName => '参数名';

  @override
  String get assistantParameterNameHint => '例如 top_k 或 provider.only';

  @override
  String get assistantParameterNameInvalid => '参数名格式不正确（点号分段不能为空）';

  @override
  String get assistantParameterType => '类型';

  @override
  String get assistantValue => '值';

  @override
  String get assistantTrueFalseHint => 'true 或 false';

  @override
  String get assistantNumberHint => '输入数字';

  @override
  String assistantJsonHint(String example) {
    return '例如：$example';
  }

  @override
  String get assistantValueHint => '输入值';

  @override
  String get assistantCancel => '取消';

  @override
  String get assistantSave => '保存';

  @override
  String get assistantParamOverrideHelp => '启用时助手参数会覆盖模型参数；关闭时使用模型参数。';

  @override
  String get assistantTemperature => '温度 (Temperature)';

  @override
  String get assistantMaxTokens => '最大 Token 数';

  @override
  String get assistantMaxToolCalls => '工具调用上限';

  @override
  String assistantRounds(String count) {
    return '$count 轮';
  }

  @override
  String get assistantUnlimited => '无限制';

  @override
  String get assistantStreamOutput => '流式输出';

  @override
  String get assistantFrequencyPenalty => '频率惩罚';

  @override
  String get assistantPresencePenalty => '存在惩罚';

  @override
  String get assistantRandomSeed => '随机种子';

  @override
  String get assistantNotSet => '未设置';

  @override
  String get assistantSeedValue => '种子值';

  @override
  String get assistantIntegerSeedHint => '输入整数种子';

  @override
  String get assistantWebSearch => '联网搜索';

  @override
  String get assistantAddParameter => '添加参数';

  @override
  String get assistantNoCustomParameters => '暂无自定义参数';

  @override
  String get assistantRoundsLabel => '轮数';

  @override
  String get modelCreateTitle => '添加模型';

  @override
  String get modelEditTitle => '编辑模型';

  @override
  String get modelDiscardTitle => '放弃修改？';

  @override
  String get modelDiscardBody => '当前有未保存的修改，确定要放弃吗？';

  @override
  String get modelNameLabel => '模型名称';

  @override
  String get modelNameHint => '输入显示名称（可选）';

  @override
  String get modelIdLabel => '模型 ID';

  @override
  String modelIdExample(String id) {
    return '例如 $id';
  }

  @override
  String get modelIdRequired => '模型 ID 为必填项。';

  @override
  String get modelCustomParamRequired => '自定义参数的参数名和默认值不能为空。';

  @override
  String modelParamDuplicate(String name) {
    return '参数已存在：$name';
  }

  @override
  String modelParamReserved(String name) {
    return '不能使用保留的 OCR 参数名：$name';
  }

  @override
  String get modelParamName => '参数名';

  @override
  String get modelParamDefaultValue => '默认参数值';

  @override
  String get modelParamDelete => '删除参数';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return '参数“$name”的默认值不是合法 JSON：$value';
  }

  @override
  String get modelAddParameter => '添加参数';

  @override
  String get modelNoCustomParams => '暂无自定义参数';

  @override
  String get modelBasicSettings => '基本设置';

  @override
  String get modelDiscardCancel => '取消';

  @override
  String get modelSave => '保存';

  @override
  String get modelUnsavedMaxTokens => '最大输出 Token 数已启用但未填写。';

  @override
  String get modelMaxTokensPositive => '最大输出 Token 数必须为正整数。';

  @override
  String get modelSeedInteger => '随机种子必须为整数。';

  @override
  String get modelContextLengthRequired => '上下文长度为必填项。';

  @override
  String get modelContextLengthPositive => '上下文长度必须为正整数。';

  @override
  String get modelAsrLanguageCode => '语言代码（Language）';

  @override
  String get modelAsrLanguageHint => '例如 zh、en、ja';

  @override
  String get modelAsrLanguageHelp => 'ISO-639-1 语言代码；留空则由模型自动检测。';

  @override
  String get modelTemperature => '温度';

  @override
  String get modelTemperatureHelp => '控制输出的随机性，建议使用较低的值。';

  @override
  String get modelAsrPrompt => '提示词';

  @override
  String get modelAsrPromptHint => '输入上下文提示词（可选）';

  @override
  String get modelAsrPromptHelp => '提供上下文以提高转写准确性，例如专业术语列表。';

  @override
  String get modelAsrParams => 'ASR 参数';

  @override
  String get modelEnabledParamsHelp => '开启的参数将作为默认值发送到 API 请求中。';

  @override
  String get modelAsrResponseFormat => '响应格式';

  @override
  String get modelAsrResponseHelp => '转写结果的返回格式。';

  @override
  String get modelAsrTimestampGranularity => '时间戳粒度';

  @override
  String get modelAsrVerboseHelp => '仅在 response_format 为 verbose_json 时生效。';

  @override
  String get modelNoTrim => '不裁切';

  @override
  String get modelAudioTrimTitle => '音频裁切';

  @override
  String get modelAudioTrimHelp => '选择音频裁切方式。';

  @override
  String get modelDeleteTrimPreset => '删除裁切预设';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return '确定要删除裁切预设“$name”吗？';
  }

  @override
  String get modelAddTrimPreset => '添加自定义裁切';

  @override
  String get modelPlayTestAudio => '播放测试音频';

  @override
  String get modelPlayingTestAudio => '播放中...';

  @override
  String get modelParamExists => '该参数已存在';

  @override
  String get asrModelIdExample => '例如 whisper-1';

  @override
  String get asrPromptLabel => '提示词';

  @override
  String get asrResponseFormatJson => 'json – JSON 格式';

  @override
  String get asrResponseFormatText => 'text – 纯文本';

  @override
  String get asrResponseFormatSrt => 'srt – 字幕';

  @override
  String get asrResponseFormatVtt => 'vtt – 字幕';

  @override
  String get asrResponseFormatVerbose => 'verbose_json – 详细 JSON（含时间戳）';

  @override
  String get asrVerboseTimestampHelp => '选择 verbose_json 后可启用下方时间戳粒度选项。';

  @override
  String get asrTimestampSegment => 'segment – 段落级';

  @override
  String get asrTimestampWord => 'word – 单词级';

  @override
  String get asrWordTimestampHelp => '单词级时间戳的准确性可能低于段落级。';

  @override
  String get reasoningAddOptionValue => '添加选项值';

  @override
  String get reasoningEditOptionValue => '编辑选项值';

  @override
  String get reasoningOptionExample => '例如 low、medium、high';

  @override
  String get reasoningOptionSelectionHelp =>
      '点按选项块可选中或取消。选中的值会发送；拖动可排序。供应商提供的值不能删除，但可以取消选中来隐藏。';

  @override
  String get reasoningAddOption => '添加选项';

  @override
  String get reasoningCurrentProvider => '当前：供应商';

  @override
  String get reasoningCurrentModel => '当前：模型自定义';

  @override
  String get reasoningAddEffortValue => '添加推理力度值';

  @override
  String get reasoningEffortExample => '例如 max、ultra、deep';

  @override
  String get reasoningAddToggle => '添加推理开关';

  @override
  String get reasoningToggle => '推理开关';

  @override
  String get reasoningResetParameter => '还原此参数';

  @override
  String get reasoningDisableToggle => '停用推理开关';

  @override
  String get reasoningEnableToggle => '启用推理开关';

  @override
  String reasoningParameterNameSource(String source) {
    return '参数名（$source）';
  }

  @override
  String get reasoningNameExample => '例如 thinking.type、reasoning';

  @override
  String get reasoningBooleanHelp => '布尔参数无需配置值；聊天面板提供开关。';

  @override
  String get reasoningOnValue => '开启时的值';

  @override
  String get reasoningOnExample => '例如 enabled、true';

  @override
  String get reasoningOffValue => '关闭时的值';

  @override
  String get reasoningOffExample => '例如 disabled、false';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return '开启时发送“$onValue”，关闭时发送“$offValue”。';
  }

  @override
  String get reasoningAddEffort => '添加推理力度';

  @override
  String get reasoningFillToggleFirst => '请先完整填写推理开关';

  @override
  String get reasoningFillToggleBeforeEffort => '请先完整填写推理开关，再配置推理力度。';

  @override
  String get reasoningAddValue => '添加值';

  @override
  String get reasoningJsonValue => 'JSON 值';

  @override
  String reasoningJsonExample(String example) {
    return '例如 $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      '点按选项块可选中或取消。选中的值会显示在聊天推理面板；拖动可排序。供应商提供的值不能删除，但可以隐藏。';

  @override
  String get reasoningAddParameter => '添加推理参数';

  @override
  String get reasoningToggleIncomplete => '请先完整填写推理开关，再配置推理力度。';

  @override
  String get llmContextLength => '上下文长度';

  @override
  String get llmContextHint => '输入上下文长度';

  @override
  String get llmContextHelp => '模型的最大上下文窗口大小（Token 数）。';

  @override
  String get llmReasoningParams => '推理参数';

  @override
  String get llmReasoningHelp =>
      '配置聊天推理参数。推理开关用于设置参数名和开关值；可添加、排序推理力度选项，并选择显示在聊天面板中的值。打开本页时会同步供应商提供的值。这些设置控制模型参数；聊天面板中的推理开关独立管理。';

  @override
  String get llmAddReasoningParam => '添加推理参数';

  @override
  String get llmCustomEndpointType => '自定义端点类型';

  @override
  String get llmInheritEndpointType => '关闭时使用供应商设置的端点类型。';

  @override
  String get llmEndpointType => '端点类型';

  @override
  String get llmEndpointOpenAi => '兼容 OpenAI（Chat Completions）';

  @override
  String get llmEndpointAnthropic => 'Anthropic 格式（Messages API）';

  @override
  String get llmEndpointHelp => '端点类型必须与供应商 API 地址匹配。更改后，此模型的新对话会使用相应格式。';

  @override
  String get llmTopPHelp => '核采样参数，用于控制词汇选择的累积概率。';

  @override
  String get llmFrequencyPenaltyLabel => '频率惩罚';

  @override
  String get llmFrequencyPenaltyHelp => '减少重复，负值会增加重复。';

  @override
  String get llmPresencePenaltyLabel => '存在惩罚';

  @override
  String get llmPresencePenaltyHelp => '鼓励讨论新话题，负值会鼓励重复话题。';

  @override
  String get llmMaxTokensHint => '可选，例如 4096';

  @override
  String get llmTokensPerResponse => '每次响应最多生成的 Token 数。';

  @override
  String get llmSeedLabel => '随机种子（Seed）';

  @override
  String get llmSeedHint => '可选，例如 42';

  @override
  String get llmSeedHelp => '设置后可使输出结果可复现。';

  @override
  String get llmInheritedCustomHelp => '供应商已配置的自定义参数会显示在此处，并在每次打开页面时同步。';

  @override
  String get llmBooleanParamHelp => '布尔类型无需配置参数值。';

  @override
  String get modelContextReq => '上下文长度为必填项。';

  @override
  String get modelContextPositive => '上下文长度必须为正整数。';

  @override
  String modelParamNameInvalid(String name) {
    return '参数名格式不正确（点号分段不能为空）：$name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return '参数“$name”的$valueLabel必须是有限数字：$value';
  }

  @override
  String get modelReasoningIncomplete => '请先完整填写推理开关，其他推理参数才能生效。';

  @override
  String get modelReasoningOptionsRequired => '推理参数必须至少添加一个选项值。';

  @override
  String modelReasoningError(String error) {
    return '推理参数错误：$error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return '推理参数重名：$name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return '推理参数与自定义参数重名：$name';
  }

  @override
  String get modelSeedRequired => '随机种子已启用但未填写。';

  @override
  String get ocrParamsTitle => 'OCR 参数';

  @override
  String get ocrParamsHelp =>
      '使用兼容 OpenAI 的视觉 Chat Completions 格式。以下参数均为可选；未填写或未启用的参数不会发送。供应商特有参数可在下方添加（需接口支持）。';

  @override
  String get ocrRequestSizeOverride => '请求 JSON 大小覆盖值';

  @override
  String get ocrInheritProvider => '留空则继承供应商设置';

  @override
  String get ocrBudgetDefault => '留空时继承供应商设置；供应商也未设置时使用 20 MiB 默认值。';

  @override
  String ocrBudgetValue(String size) {
    return '留空时继承供应商设置（$size MiB）；供应商也未设置时使用 20 MiB 默认值。';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return '裁切$direction $seconds 秒';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return '裁切开头 $seconds 秒';
  }

  @override
  String get audioTrimNone => '不裁切音频';

  @override
  String get trimNameLabel => '裁切方式名称 *';

  @override
  String get trimNameHint => '例如静音裁切';

  @override
  String get trimDurationLabel => '裁切时长（秒）*';

  @override
  String get trimDurationHint => '例如 0.123';

  @override
  String get trimNameAndDurationRequired => '名称和时长为必填项。';

  @override
  String get trimDurationInvalid => '请输入有效的正数时长。';

  @override
  String get testAudioHostMissing => '尚未配置 Host。';

  @override
  String get testAudioKeyMissing => '尚未配置 Key。';

  @override
  String testAudioContentTypeError(String contentType) {
    return '响应 Content-Type 为 $contentType，不是音频数据。';
  }

  @override
  String get testAudioEmpty => '服务器返回了空音频数据。';

  @override
  String testAudioTimeoutConnection(String details) {
    return '连接超时，请检查网络。$details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return '接收超时，服务器响应过慢。$details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return '请求已取消。$details';
  }

  @override
  String testAudioNetworkError(String message) {
    return '网络错误：$message';
  }

  @override
  String get testAudioNoBody => '无响应体';

  @override
  String testAudioCorsHelp(String details) {
    return '无法连接到服务器。Web 端可能因 CORS 限制或 API 地址错误导致；请检查供应商 API 地址及服务器跨域设置。$details';
  }

  @override
  String get trimModelNameHint =>
      '用于显示和识别的易读名称，例如“GPT-4o Mini TTS”。同一供应商下的模型可用名称区分。';

  @override
  String get trimModelIdHelp =>
      'API 调用使用的唯一标识符，例如“gpt-4o-mini-tts”。必须与供应商提供的模型 ID 一致。';

  @override
  String get ttsVoiceRangeTitle => '音量范围';

  @override
  String get ttsMinVolume => '最小音量';

  @override
  String get ttsMaxVolume => '最大音量';

  @override
  String get ttsSpeedRangeTitle => '语速范围';

  @override
  String get ttsMinSpeed => '最小语速';

  @override
  String get ttsMaxSpeed => '最大语速';

  @override
  String get ttsMaxAudioLength => '单次最长音频字数 *';

  @override
  String get ttsAudioLengthHint => '例如 1000';

  @override
  String get ttsNoVoices => '暂无音色，点击进入编辑';

  @override
  String get ttsInstructionSupported => '模型是否支持 instruction 参数';

  @override
  String get ttsInstructionHelp => '启用后可在 TTS 请求中附加语气、情绪、语速等指令描述。';

  @override
  String get ttsStreamSupported => '模型是否支持流式输出';

  @override
  String get ttsStreamHelp => '启用后此模型可用于需要流式输出的场景；请先确认模型支持流式输出。';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return '参数“$name”的值必须是 true 或 false：$value';
  }

  @override
  String get ttsMaxAudioLengthRequired => '单次最长音频字数为必填项，请输入大于 0 的整数。';

  @override
  String get asrLanguageExample => '例如 zh、en、ja';

  @override
  String get llmReasoningFullHelp =>
      '推理开关控制是否发送推理参数，并允许设置参数名和开关值。推理力度参数只有一个，可选择值并拖动排序；选中的值会显示在聊天推理面板中。可在下方添加其他推理参数。参数名支持点号嵌套，例如 thinking.type 会转换为嵌套 JSON 对象。打开本页时会同步供应商配置的推理参数。此处开关控制模型参数；聊天中的推理开关独立控制。';

  @override
  String get llmTemperatureHelp => '控制输出的随机性，值越高越有创造性。';

  @override
  String get llmBooleanValueHelp => '布尔类型无需配置参数值。';

  @override
  String get reasoningDisableEffort => '停用推理力度';

  @override
  String get reasoningEnableEffort => '启用推理力度';

  @override
  String get ocrJsonSizePositive => '请求 JSON 大小必须是大于 0 的 MiB 数值。';

  @override
  String ttsRangePair(String kind) {
    return '最小和最大$kind必须同时填写，或同时留空。';
  }

  @override
  String get ttsEditTrimTitle => '编辑自定义裁切';

  @override
  String ttsVoicesCount(String count) {
    return '音色 ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return '在请求格式中生成：$syntax';
  }

  @override
  String get mcpServerNameRequired => '请输入 MCP 服务器名称。';

  @override
  String get mcpStdioCommandRequired => 'stdio 模式需要指定命令。';

  @override
  String get mcpSseUrlRequired => 'SSE 模式需要指定 URL。';

  @override
  String get mcpEditServerTitle => '编辑 MCP 服务器';

  @override
  String get mcpCreateServerTitle => '新建 MCP 服务器';

  @override
  String get mcpUnsavedChangesTitle => '未保存的更改';

  @override
  String get mcpUnsavedChangesConfirm => '有未保存的更改，确定要放弃吗？';

  @override
  String get mcpTransportType => '传输方式';

  @override
  String get mcpServerName => '服务器名称';

  @override
  String get mcpServerNameHint => '输入 MCP 服务器名称';

  @override
  String get mcpCommand => '命令';

  @override
  String get mcpCommandExample => '例如：npx';

  @override
  String get mcpArguments => '参数';

  @override
  String get mcpArgumentsHint =>
      '用逗号分隔参数，例如：-y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => '例如：http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'API 密钥';

  @override
  String get mcpApiKeyHint => '输入 API Key（可选）';

  @override
  String get mcpShowKey => '显示密钥';

  @override
  String get mcpHideKey => '隐藏密钥';

  @override
  String get mcpDescriptionHint => '输入此 MCP 服务器的描述信息（可选）';

  @override
  String get mcpStdioDescription =>
      'stdio 会在本地启动子进程作为 MCP 服务器，并通过标准输入/输出通信。适用于本地工具。';

  @override
  String get mcpSseDescription => 'SSE 通过 HTTP SSE 连接远程 MCP 服务器。适用于远程服务。';

  @override
  String get mcpLocalStdio => '本地 (stdio)';

  @override
  String get mcpRemoteSse => '远程 (SSE)';

  @override
  String get mcpSaving => '保存中…';

  @override
  String get providerTestSafetyNote =>
      '此测试会向对应服务发送真实请求。MCP 仅调用只读的 tools/list；HTTP 和网页搜索会执行一次查询。Todo 默认读取清单；为保护当前数据，请省略 todos 参数或将其设为 null。';

  @override
  String get providerDeleteConfigTitle => '删除配置';

  @override
  String get providerDeleteConfigConfirm => '确定要删除此供应商配置及其所有模型吗？';

  @override
  String get providerCreateGroup => '新建组别';

  @override
  String get providerEditGroup => '编辑组别';

  @override
  String get providerGroupName => '组别名称';

  @override
  String get providerGroupNameExists => '组别名称已存在。';

  @override
  String get providerDeleteGroup => '删除组别';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return '删除“$groupName”后，其中的配置会移到“其他 MCP 服务”。';
  }

  @override
  String get providerMoveToGroup => '移动到组别';

  @override
  String get providerUnnamed => '（未命名）';

  @override
  String get providerHttpSearch => 'HTTP 搜索';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP 工具：$url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return '本地 (stdio)：$command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return '远程 (SSE)：$url';
  }

  @override
  String get providerServices => '服务配置';

  @override
  String get providerServicesDescription => '按组管理远程连接、本地 stdio 与 HTTP 搜索';

  @override
  String get providerCreateGroupAction => '新建组别';

  @override
  String get providerGroupEmpty => '此组暂无配置，点击“添加”加入内容。';

  @override
  String get providerBuiltinTools => '内置工具';

  @override
  String get providerBuiltinToolsDescription => 'Stroom 提供的本地工具接口；网页搜索归入对应服务组。';

  @override
  String get providerBuiltinToolInterface => '内置工具接口';

  @override
  String get providerViewInterface => '查看接口';

  @override
  String get providerConfigTitle => '配置';

  @override
  String get providerNotFound => '供应商未找到';

  @override
  String get providerConfigurationHeading => '供应商配置';

  @override
  String get providerBuiltinWebSearchEmpty =>
      '内置网络搜索支持 Google、Bing 和百度，模型调用名为 web_search。';

  @override
  String get providerNoConfigsAdd => '暂无供应商配置，请点击“添加”创建。';

  @override
  String get providerNoHost => '(未设置 Host)';

  @override
  String get providerServicesAndTools => '服务与工具';

  @override
  String get providerManageServicesDescription =>
      '管理 MCP 服务器、HTTP 搜索和 Stroom 内置工具。';

  @override
  String get providerNoServices => '还没有服务配置';

  @override
  String get providerAddServiceDescription =>
      '添加 MCP 服务或 HTTP 搜索接口，连接后即可在助手中使用。';

  @override
  String get providerAddService => '添加服务';

  @override
  String get providerBuiltinBadge => '内置';

  @override
  String get providerBuiltinTtsName => 'TTS供应商';

  @override
  String get providerBuiltinLlmName => 'LLM供应商';

  @override
  String get providerBuiltinOcrName => 'OCR供应商';

  @override
  String get providerBuiltinAsrName => '音频转写供应商';

  @override
  String get providerBuiltinMcpName => 'MCP供应商';

  @override
  String get providerBuiltinSearchGroupName => '搜索';

  @override
  String get providerBuiltinMcpServicesGroupName => '其他 MCP 服务';

  @override
  String get providerConnectivityTest => '连通性测试';

  @override
  String get providerMoveGroupTooltip => '移动到组别';

  @override
  String get providerDeleteTooltip => '删除配置';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 项内容',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => '组别操作';

  @override
  String get providerEditGroupAction => '编辑组别';

  @override
  String get providerDeleteGroupAction => '删除组别';

  @override
  String get providerAddItem => '添加内容';

  @override
  String get providerMcpMasterLabel => 'MCP 服务器';

  @override
  String get providerMcpMasterDescription => '控制 MCP 服务器与内置搜索工具在助手和对话中的可用性。';

  @override
  String get providerEnabled => '已启用';

  @override
  String get providerDisabled => '已停用';

  @override
  String get providerEditSettings => '编辑供应商设置';

  @override
  String get providerModelList => '模型列表';

  @override
  String get providerNoModels => '暂无模型';

  @override
  String get providerDeleteModel => '删除模型';

  @override
  String get providerDeleteModelConfirm => '确定要删除此模型吗？';

  @override
  String get providerEditConfig => '编辑配置';

  @override
  String providerCreateNamedConfig(String entryName) {
    return '新建$entryName配置';
  }

  @override
  String get toolHttpSearchType => '接入类型：HTTP 搜索';

  @override
  String toolInterface(String name) {
    return '工具接口：$name';
  }

  @override
  String get toolParameterDefinitions => '参数定义';

  @override
  String get toolHttpAddress => 'HTTP 接口地址';

  @override
  String get toolInvalidHttpUrl => '请输入有效的 HTTP 或 HTTPS 地址。';

  @override
  String get toolBuiltinType => '接入类型：Stroom 内置工具';

  @override
  String get toolBuiltinEnableHelp => '是否在助手中启用，由该助手的默认工具设置管理。';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return '模型 ID：$modelId';
  }

  @override
  String get providerValueNotSet => '（未设置）';

  @override
  String get providerApiKeyInputHint => '输入 API 密钥';

  @override
  String get providerSettingsTitle => '供应商配置';

  @override
  String get providerBasicInfoTab => '基本信息';

  @override
  String get providerParameterSettingsTab => '参数设置';

  @override
  String get providerOptionValuesReorderHelp => '选项值（长按把手拖拽排序）';

  @override
  String providerOptionIndexLabel(String index) {
    return '选项 $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return '如 $example';
  }

  @override
  String get providerDeleteOptionTooltip => '删除选项';

  @override
  String get providerAddOption => '添加选项';

  @override
  String get providerAddCustomParam => '添加参数';

  @override
  String get providerNoCustomParams => '暂无自定义参数';

  @override
  String get providerParamNameLabel => '参数名';

  @override
  String get providerParamDefaultValueLabel => '默认参数值';

  @override
  String get providerBooleanParamNoValue => '布尔类型无需配置参数值，聊天面板提供开/关切换。';

  @override
  String get providerReasoningParamsHeading => '推理参数';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return '推理开关控制聊天页面中推理功能的开启和关闭，由您定义参数名和对应的开/关值。推理力度参数最多配置一个，参数名必填，选项值可选；仅填参数名时，参数值由模型配置提供。您还可以通过底部按钮添加额外的推理参数。参数名支持点号嵌套，例如 $parameterName 会展开为 $jsonExample。';
  }

  @override
  String get providerAddReasoningParam => '添加推理参数';

  @override
  String get providerAddReasoningToggle => '添加推理开关';

  @override
  String get providerReasoningToggle => '推理开关';

  @override
  String get providerDeleteReasoningToggle => '删除推理开关';

  @override
  String providerParamNameHint(String examples) {
    return '如 $examples';
  }

  @override
  String get providerReasoningBooleanHelp => '布尔类型无需配置参数值，聊天面板提供开/关切换。';

  @override
  String get providerToggleOnValueLabel => '开启时值';

  @override
  String get providerToggleOffValueLabel => '关闭时值';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return '推理开关打开时发送「$onValue」，关闭时发送「$offValue」。';
  }

  @override
  String get providerAddReasoningEffort => '添加推理力度';

  @override
  String get providerDeleteReasoningEffort => '删除推理力度参数';

  @override
  String get providerReasoningEffortLockedHint => '请先完整填写推理开关后再配置推理力度。';

  @override
  String get providerJsonValueLabel => 'JSON 值';

  @override
  String get providerReasoningOptionsHelp =>
      '选项值（可选，仅填参数名时参数值由模型配置提供；长按把手拖拽排序）';

  @override
  String get providerParamNameNestedLabel => '参数名（支持点号嵌套）';

  @override
  String get providerToggleEffortPrerequisite => '请先完整填写推理开关后再配置推理力度。';

  @override
  String get providerToggleRequiredHint => '请先填写推理开关';

  @override
  String get providerDeleteCustomParam => '删除参数';

  @override
  String get modelSaveSuccess => '模型已保存';

  @override
  String get modelSaving => '保存中…';

  @override
  String modelOriginalError(String error) {
    return '原始错误：$error';
  }

  @override
  String get paramTypeStringLabel => '字符串';

  @override
  String get paramTypeNumberLabel => '数字';

  @override
  String get paramTypeBooleanLabel => '布尔';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return '不支持的类型：$type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return '参数“$name”使用了不支持的类型“$type”，请替换为支持的类型或删除该参数后再保存。';
  }

  @override
  String get paramTypeStringHint => '例如: cheerful';

  @override
  String get paramTypeNumberHint => '例如: 0.8';

  @override
  String get paramTypeBooleanHint => '例如: true';

  @override
  String get paramTypeJsonHint => '例如: ';

  @override
  String get ankiPageTitle => 'Anki闪卡';

  @override
  String get ankiStatsTooltip => '学习统计';

  @override
  String get ankiBrowseCardsTooltip => '浏览卡片';

  @override
  String get ankiStatsTotalCards => '总卡片数';

  @override
  String get ankiStatsNewCards => '待学习';

  @override
  String get ankiStatsLearning => '学习中';

  @override
  String get ankiStatsDueForReview => '待复习';

  @override
  String get ankiStatsReviewHistory => '历史复习次数';

  @override
  String get ankiStatsLearningProgress => '学习进度';

  @override
  String get ankiStatsReviewRate => '复习率';

  @override
  String get ankiBrowserSearchHint => '搜索卡片...';

  @override
  String get ankiBrowserEmpty => '无卡片';

  @override
  String get ankiSyncTooltip => 'AnkiWeb 同步';

  @override
  String get ankiNewDeckTooltip => '新建牌组';

  @override
  String ankiDeckLoadError(String error) {
    return '加载失败: $error';
  }

  @override
  String get ankiEmptyDecksTitle => '还没有牌组';

  @override
  String get ankiEmptyDecksDescription => '创建一个牌组开始学习';

  @override
  String get ankiNewDeckTitle => '新建牌组';

  @override
  String get ankiDeckNameHint => '牌组名称';

  @override
  String get ankiCreateDeck => '创建';

  @override
  String get ankiRenameDeck => '重命名';

  @override
  String get ankiConfirm => '确定';

  @override
  String get ankiDeleteDeckTitle => '删除牌组';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '确定删除“$deckName”及其所有卡片吗？';
  }

  @override
  String get ankiAddCardTitle => '添加卡片';

  @override
  String get ankiNoteTypeLabel => '笔记类型';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return '正文 (用 $clozeSyntax 标记挖空)';
  }

  @override
  String get ankiFrontQuestionHint => '正面 (问题)';

  @override
  String get ankiBackExtraLabel => '背面/额外';

  @override
  String get ankiTagsLabel => '标签 (空格分隔)';

  @override
  String get ankiTagsHint => '例如: 数学 物理';

  @override
  String get ankiAdd => '添加';

  @override
  String get ankiStatNew => '新';

  @override
  String get ankiStatLearning => '学';

  @override
  String get ankiStatReview => '复习';

  @override
  String get ankiAddCardAction => '添加卡片';

  @override
  String get ankiRenameAction => '重命名';

  @override
  String get ankiDeleteAction => '删除';

  @override
  String get ankiNoCardContent => '(无内容)';

  @override
  String get ankiStudy => '学习';

  @override
  String get ankiWhiteboardTooltip => '白板';

  @override
  String get ankiFrontLabel => '正面';

  @override
  String get ankiBackLabel => '背面';

  @override
  String get ankiShowAnswer => '显示答案';

  @override
  String get ankiRatingAgain => '忘记';

  @override
  String get ankiRatingHard => '困难';

  @override
  String get ankiRatingGood => '良好';

  @override
  String get ankiRatingEasy => '简单';

  @override
  String get ankiNoCardsToStudy => '当前没有待学习的卡片';

  @override
  String get ankiNoCardsHint => '你可以添加新卡片或稍后再来';

  @override
  String get ankiBack => '返回';

  @override
  String get ankiSyncPageTitle => 'Anki 同步';

  @override
  String get ankiSyncChooseMode => '选择同步方式';

  @override
  String get ankiSyncModeHelp => '登录状态按服务分别保存。切换方式不会合并或覆盖数据。';

  @override
  String get ankiSyncSelfHostedMode => '自建服务器';

  @override
  String get ankiSyncServerAddress => '服务器地址';

  @override
  String get ankiSyncServerHelp =>
      '自建远程服务器需使用 HTTPS；本机地址可使用 HTTP。服务器需支持 Anki sync v10，证书验证默认开启。';

  @override
  String get ankiSyncCustomCaTitle => '自定义 CA 证书（可选）';

  @override
  String get ankiSyncCustomCaHelp => '仅在服务器使用自签名证书时填写';

  @override
  String get ankiSyncOfficialHelp =>
      '使用官方 AnkiWeb 同步服务。密码只在登录时发送，不会保存在 Stroom。';

  @override
  String ankiSyncConnected(String service) {
    return '已连接 $service';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return '未连接 $service';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return '登录$service';
  }

  @override
  String get ankiSyncCheckServerStatus => '检查服务器状态';

  @override
  String get ankiSyncLogout => '登出';

  @override
  String get ankiSyncBothWays => '双向同步';

  @override
  String get ankiSyncOverwriteServer => '用本地数据覆盖服务器';

  @override
  String get ankiSyncReplaceLocal => '用服务器数据替换本地';

  @override
  String get ankiSyncHelp =>
      '双向同步会合并 collection 的增量变更并传输媒体文件；结构戳不一致时，请选择完整上传或下载。完整下载失败会尝试恢复原 collection 和媒体目录。';

  @override
  String get ankiSyncStatusRestored => '已恢复安全保存的登录状态';

  @override
  String get ankiSyncStatusReadSavedSessionFailed => '无法读取已保存的登录状态，请重新登录';

  @override
  String get ankiSyncInvalidServerUrl =>
      '服务器地址须为 HTTPS URL；仅本机 loopback 地址可使用 HTTP，且不能包含用户名、密码或 query 参数';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return '设置未保存：$error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged => '服务器地址已更改，请重新登录后继续';

  @override
  String get ankiSyncStatusVerifyingLogin => '正在验证登录…';

  @override
  String get ankiSyncStatusLoginSuccess => '登录成功。密码未保存，同步密钥已加密保存。';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      '登录成功，但无法安全保存同步密钥；关闭页面后需要重新登录。';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => '登录 AnkiWeb';

  @override
  String get ankiSyncLoginSelfHosted => '登录自建服务器';

  @override
  String get ankiSyncEmailOrUsername => '邮箱 / 用户名';

  @override
  String get ankiSyncEmailOrUsernameRequired => '请输入邮箱或用户名';

  @override
  String get ankiSyncPassword => '密码';

  @override
  String get ankiSyncPasswordRequired => '请输入密码';

  @override
  String get ankiSyncLogin => '登录';

  @override
  String get ankiSyncStatusPreparingServerSettings => '正在准备服务器设置…';

  @override
  String get ankiSyncStatusReadingCollection => '正在读取服务器 collection 状态…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty => '连接成功，服务器 collection 为空';

  @override
  String get ankiSyncStatusConnectedStatusRead => '连接成功，服务器状态已读取';

  @override
  String get ankiSyncStatusUpgradeClient => '此服务器要求升级同步客户端';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return '状态检查失败：$error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => '正在准备上传设置…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle => '用本地 collection 覆盖服务器？';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      '服务器上的 collection 将被本地数据完整替换。Stroom 会先保留一份本地数据库备份。\n\n随后仍会按服务器媒体清单双向同步文件。';

  @override
  String get ankiSyncOverwriteServerAction => '覆盖服务器';

  @override
  String get ankiSyncStatusBackingUpUploading => '正在备份并上传 collection…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return '服务器已接受本地 collection，媒体同步完成：上传 $uploaded 个，下载 $downloaded 个，删除 $deleted 个。$backup请重新检查服务器状态。';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return '\n本地备份：$path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      '服务器 collection 已替换，但媒体同步未完成：';

  @override
  String get ankiSyncStatusUploadFailed => '上传失败：';

  @override
  String get ankiSyncStatusPreparingDownload => '正在准备下载设置…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle => '用服务器 collection 替换本地？';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      '本地 collection 将被服务器数据替换。Stroom 会先保留一份本地数据库备份。\n\n随后会用服务器媒体替换本地媒体并下载缺失文件。若任一步失败或应用中途退出，Stroom 会在下次打开牌组前恢复本地 collection 和媒体。';

  @override
  String get ankiSyncReplaceLocalAction => '替换本地数据';

  @override
  String get ankiSyncStatusDownloadingValidating => '正在下载并验证 collection…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return '本地 collection 已替换，SQLite 检查通过；媒体同步完成：下载 $downloaded 个，上传 $uploaded 个，删除 $deleted 个。$backup请重新检查服务器状态。';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get ankiSyncStatusPreparingSync => '正在准备同步…';

  @override
  String get ankiSyncStatusMergingChanges => '正在合并 collection 变更…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'Collection 增量合并完成，正在同步媒体文件…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '新增/更新 $notes 个笔记、$cards 张卡片、$reviews 条复习记录';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges => 'collection 没有待合并变更';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return '双向同步完成：$collection；媒体上传 $uploaded 个、下载 $downloaded 个、删除 $deleted 个。';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'Collection 已合并，但媒体同步未完成：';

  @override
  String get ankiSyncStatusSyncIncomplete => '同步未完成：';

  @override
  String get ankiSyncStatusClearingLogin => '正在清除登录状态…';

  @override
  String get ankiSyncStatusLoggedOut => '已登出，安全存储中的同步密钥已删除';

  @override
  String get ankiSyncStatusClearLoginFailed => '无法清除已保存的登录状态';

  @override
  String get ankiSyncStatusOperationIncomplete => '操作未完成，请检查安全存储、网络和服务器地址';

  @override
  String get ankiSyncUnknown => '未知';

  @override
  String get ankiSyncServerCollectionEmpty => '服务器 collection 为空';

  @override
  String get ankiSyncServerCollectionAvailable => '服务器 collection 可用';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return '结构版本戳 $schema · USN $usn · 修改时间 $modified';
  }

  @override
  String get asrPageTitle => '音频转写';

  @override
  String get clear => '清空';

  @override
  String get configure => '去配置';

  @override
  String get asrModel => '识别模型';

  @override
  String get reselectModel => '请重新选择模型';

  @override
  String get selectAsrModel => '选择识别模型';

  @override
  String get enterPublicAudioUrl => '输入公网音频链接';

  @override
  String get recordingSelection => '录音选择';

  @override
  String get audioFiles => '音频文件';

  @override
  String get noAudioSelected => '暂未选择音频文件';

  @override
  String get supportedAudioFormats => '支持 wav、mp3、m4a、ogg 等常见音频格式';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 个音频文件',
      one: '已选择 $count 个音频文件',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 个音频',
      one: '已选 $count 个音频',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => '重新选择';

  @override
  String get asrUrlLabel => 'URL  |  公网链接';

  @override
  String get asrErrorDetails => '查看详细错误';

  @override
  String get asrResultSaved => '识别结果已保存';

  @override
  String get asrWorking => '识别中...';

  @override
  String get asrStart => '开始识别';

  @override
  String get saveTo => '保存至';

  @override
  String get rootFolder => '根目录';

  @override
  String get chooseSaveFolder => '选择保存文件夹';

  @override
  String get linkAlreadyAdded => '该链接已在列表中';

  @override
  String get chooseAudioSource => '选择音频来源';

  @override
  String get inAppRecordings => '应用内录音';

  @override
  String get chooseGeneratedRecordings => '从已生成的录音中选择';

  @override
  String get systemAudioFiles => '系统音频文件';

  @override
  String get chooseDeviceAudioFiles => '从设备文件中选择';

  @override
  String get cannotReadAudioFile => '无法读取音频文件';

  @override
  String chooseAudioFileFailed(String details) {
    return '选择音频文件失败: $details';
  }

  @override
  String get chooseInAppRecording => '选择应用内录音';

  @override
  String get noRecordings => '暂无录音';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds秒',
      one: '$seconds秒',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider => '请先在设置中配置音频转写供应商和模型';

  @override
  String get asrModelUnavailable => '原识别模型已失效或无法确认，请重新选择识别模型';

  @override
  String get asrUrlProviderRemoveFiles => '当前供应商使用 URL 上传方式，请移除本地音频文件后重试';

  @override
  String get asrFileProviderRemoveUrls => '当前供应商使用文件上传方式，不支持链接转写，请移除链接后重试';

  @override
  String asrTaskStartFailed(String details) {
    return '任务启动失败: $details';
  }

  @override
  String get asrInvalidUrl => '无效链接，必须以 http:// 或 https:// 开头';

  @override
  String get asrEnterAudioUrl => '输入音频链接';

  @override
  String get asrUrlProviderHelp => '当前供应商使用 URL 上传方式，请输入公网音频链接（http/https）。';

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get ttsPageTitle => '音频';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个音频文件',
      one: '已导入 $count 个音频文件',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return '导入失败: $details';
  }

  @override
  String get ttsFileReadFailed => '文件数据读取失败';

  @override
  String get ttsExportAudioFile => '导出音频文件';

  @override
  String ttsExportedTo(String path) {
    return '已导出到: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return '导出失败: $details';
  }

  @override
  String get ttsConfirmRegenerate => '确认重新生成';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return '确定要重新生成音频 “$fileName” 吗？';
  }

  @override
  String get ttsRegenerateOverwrite => '重新生成后将覆盖原音频文件。';

  @override
  String get ttsRegenerate => '确认重新生成';

  @override
  String ttsCopiedFailed(String details) {
    return '复制失败: $details';
  }

  @override
  String get ttsChooseExportFolder => '选择导出目录';

  @override
  String get ttsExportAudio => '导出音频';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导出 $count 个文件',
      one: '已导出 $count 个文件',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => '文件夹导出';

  @override
  String get ttsWebFolderExportHelp => '浏览器无法选择导出目录，将下载保留文件夹层级的 ZIP 文件。';

  @override
  String get ttsDownloadZip => '下载 ZIP 文件';

  @override
  String get ttsExportAudioFolder => '导出音频文件夹';

  @override
  String get ttsRecord => '录音';

  @override
  String get ttsImport => '导入';

  @override
  String get ttsPlay => '播放';

  @override
  String get ttsExportLocal => '导出到本地';

  @override
  String get ttsRegenerateQuestion => '重新生成';

  @override
  String get ttsNeedsProvider => '请先在设置中配置语音合成供应商和模型';

  @override
  String get ttsAddedToTasks => '已添加到任务列表，后台生成中…';

  @override
  String get ttsCreateTitle => '语音合成';

  @override
  String get ttsOriginalTitle => '录音标题';

  @override
  String get ttsUseOriginalTitle => '使用原标题';

  @override
  String get ttsAudioFileNameHint => '保存的音频文件名（可选）';

  @override
  String get ttsTextToConvert => '转换文本';

  @override
  String get ttsSpeechContent => '语音内容';

  @override
  String get ttsTextHint => '请输入要转换为语音的文本...';

  @override
  String get ttsFullscreenEdit => '全屏编辑';

  @override
  String ttsTextLimitWarning(int limit) {
    return '文字超出限制（最多 $limit 字）';
  }

  @override
  String get ttsSynthesisConfig => '合成配置';

  @override
  String get ttsVoiceAndSoundHelp => '调整音色与声音表现';

  @override
  String get ttsProviderSettingsLead => '在';

  @override
  String get ttsProviderSettings => 'TTS供应商设置';

  @override
  String get ttsProviderSettingsTail => '页面设置更多参数';

  @override
  String get ttsEditText => '编辑文本';

  @override
  String get ttsClose => '关闭';

  @override
  String get ttsVoice => '音色';

  @override
  String get ttsSelectVoice => '选择音色';

  @override
  String get ttsSpeed => '语速';

  @override
  String get ttsNormal => '正常';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsInstruction => '语气指令（instruction）';

  @override
  String get ttsInstructionHint => '例如：请用愉快、兴奋的语气说话';

  @override
  String get ttsCustomParams => '自定义参数';

  @override
  String ttsDefaultValue(Object value) {
    return '默认: $value';
  }

  @override
  String get ttsGenerateRecording => '生成录音';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return '将保存为: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => '选择保存文件夹';

  @override
  String get ttsFillTextError => '请输入要转换的文本';

  @override
  String get voiceBatchTitle => '批量添加音色';

  @override
  String get voiceBatchConfirm => '确认添加';

  @override
  String get voiceBatchSeparator => '分隔符：';

  @override
  String get voiceBatchCustomSeparatorHint => '请输入自定义分隔符';

  @override
  String get voiceBatchFieldOrder => '字段顺序：';

  @override
  String get voiceBatchNameThenId => '第1个=名称, 第2个=ID';

  @override
  String get voiceBatchIdThenName => '第1个=ID, 第2个=名称';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '检测到 $count 列，请选择作为名称/ID的起始列：',
      one: '检测到 1 列，请选择作为名称/ID的起始列：',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return '第$index列：$sample';
  }

  @override
  String get voiceBatchSingleColumn => '识别到单列数据，将全部作为ID处理（名称 = ID）';

  @override
  String get voiceBatchInputHint => '支持 Tab / 逗号 / 分号 / 竖线 作为分隔符，每行两个内容';

  @override
  String get voiceBatchNoPreview => '暂无解析结果';

  @override
  String get voiceName => '音色名称';

  @override
  String get voiceId => '音色ID';

  @override
  String get status => '状态';

  @override
  String get voiceNew => '✅ 新增';

  @override
  String get voiceIdExists => '⚠️ ID已存在';

  @override
  String voiceFormatError(String details) {
    return '❌ 格式错误$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发现 $count 个重复ID: $ids',
      one: '发现 $count 个重复ID: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData => '所选列数据不足';

  @override
  String get voiceCustomSeparator => '自定义...';

  @override
  String get voiceCommaSeparator => '逗号 (,)';

  @override
  String get voiceSemicolonSeparator => '分号 (;)';

  @override
  String get voicePipeSeparator => '竖线 (|)';

  @override
  String get voiceTabSeparator => 'Tab';

  @override
  String get voiceEditorTitle => '音色编辑';

  @override
  String get save => '保存';

  @override
  String get voiceAddRow => '添加一行';

  @override
  String get voiceBatchAdd => '批量添加';

  @override
  String get voiceNoneAdd => '暂无音色，请添加';

  @override
  String get delete => '删除';

  @override
  String get voiceDuplicateResolution => '发现以下重复音色ID，逐条选择处理方式：';

  @override
  String get update => '更新';

  @override
  String get skip => '跳过';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 个重复未处理',
      one: '还有 $count 个重复未处理',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => '继续编辑';

  @override
  String get asrRetryIncomplete => '重试音频不完整，请清空后重新选择全部音频';

  @override
  String asrRetryAudioUnreadable(String details) {
    return '重试音频数据无法读取，请重新选择音频: $details';
  }

  @override
  String get asrLegacyRetryUnavailable => '旧版重试音频不可用，请重新选择音频';

  @override
  String get asrRetryDataUnreadable => '重试数据无法读取，请重新选择音频';

  @override
  String get ttsSynthesisModel => '合成模型';

  @override
  String get asrRetryUnavailable => '重试音频不可用，请重新选择音频';

  @override
  String get chatRequest => '请求 (Request)';

  @override
  String get chatResponse => '响应 (Response)';

  @override
  String get chatNoErrorDetails => '无详细数据';

  @override
  String get ttsInstructionDescription => '通过自然语言描述语气、情绪、语速、口音等，模型将据此调整合成语音的风格';

  @override
  String get audioPlayerSourceTextSource => '选择源文本来源';

  @override
  String get audioPlayerChooseInAppText => '从应用内文本选择';

  @override
  String get audioPlayerChooseSavedTextSubtitle => '从应用内已保存的文本文件中选择';

  @override
  String get audioPlayerChooseSystemText => '从系统文本文件选择';

  @override
  String get audioPlayerChooseDeviceTextSubtitle => '从设备文件中选择文本文件';

  @override
  String get audioPlayerSelectInAppText => '选择应用内文本';

  @override
  String get audioPlayerNoTextFiles => '暂无文本文件';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count字';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return '选择文本失败: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => '无法读取文本文件';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return '上传源文本失败: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => '文本内容为空';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return '保存源文本失败: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => '源文本已上传';

  @override
  String get audioPlayerSourceTextUpdated => '源文本已更新';

  @override
  String get audioPlayerConfigureTtsProvider => '请先配置TTS供应商';

  @override
  String get audioPlayerNoStreamingModels => '没有支持流式播放的模型';

  @override
  String get audioPlayerSelectStreamingModel => '选择流式播放模型';

  @override
  String get audioPlayerProviderFallback => '供应商';

  @override
  String audioPlayerStartStreaming(String model) {
    return '开始流式播放: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return '无法找到音频文件: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => '无法加载音频数据';

  @override
  String get audioPlayerSourceText => '源文本';

  @override
  String get audioPlayerNoSourceText => '（无源文本）';

  @override
  String get audioPlayerUploadSourceText => '上传源文本';

  @override
  String get audioPlayerEditSourceText => '修改源文本';

  @override
  String get audioPlayerCompanionTextMissing => '未找到伴生文本文件';

  @override
  String get audioPlayerPlaySelection => '播放选中';

  @override
  String get audioPlayerGenerateSelection => '生成选中';

  @override
  String get audioPlayerPlaying => '正在播放...';

  @override
  String get audioPlayerPaused => '已暂停';

  @override
  String get audioPlayerPlaybackSpeed => '播放速度';

  @override
  String get audioPlayerFailed => '播放失败';

  @override
  String get audioPlayerRetry => '重试';

  @override
  String get audioPlayerLoading => '正在加载音频...';

  @override
  String get audioPlayerClose => '关闭';

  @override
  String get audioRecordingBrowserUnsupportedShort => '浏览器暂不支持录音功能，请使用 App 版本';

  @override
  String get audioRecordingMicrophonePermissionRequired => '需要麦克风权限才能录音';

  @override
  String audioRecordingStartFailure(String error) {
    return '开始录音失败: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return '暂停录音失败: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return '恢复录音失败: $error';
  }

  @override
  String get audioRecordingInvalidFile => '录音文件无效，请重新录制';

  @override
  String audioRecordingStopFailure(String error) {
    return '停止录音失败: $error';
  }

  @override
  String get audioRecordingFileNotFound => '录音文件不存在';

  @override
  String get audioRecordingFileEmpty => '录音文件为空';

  @override
  String audioRecordingSaved(String name) {
    return '录音已保存: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return '保存录音失败: $error';
  }

  @override
  String get audioRecordingTitle => '录音';

  @override
  String get audioRecordingBrowserUnsupported => '浏览器暂不支持录音功能';

  @override
  String get audioRecordingUseApp => '请使用 App 版本进行录音';

  @override
  String get audioRecordingDraftRecoveryHint => '检测到未保存的录音草稿，可保存到音频库。';

  @override
  String get audioRecordingRecording => '录制中 ●';

  @override
  String get audioRecordingPaused => '已暂停 ||';

  @override
  String get audioRecordingPreparing => '准备中...';

  @override
  String get audioRecordingStart => '开始录音';

  @override
  String get audioRecordingPause => '暂停';

  @override
  String get audioRecordingStopping => '停止中...';

  @override
  String get audioRecordingStop => '停止';

  @override
  String get audioRecordingResume => '恢复';

  @override
  String get audioRecordingSaving => '保存中...';

  @override
  String get audioRecordingSave => '保存录音';

  @override
  String get audioRecordingRecordAgain => '重新录制';

  @override
  String get audioRecordingWaveformPaused => '暂停录制，波形已冻结';

  @override
  String get audioRecordingWaveformLive => '音量波形实时显示';

  @override
  String get audioSeparationTitle => '视频音频分离';

  @override
  String get audioSeparationChooseVideoSource => '选择视频来源';

  @override
  String get audioSeparationChooseAppAlbum => '从应用相册选择';

  @override
  String get audioSeparationChooseSavedVideoSubtitle => '从应用内已保存的视频中选择';

  @override
  String get audioSeparationChooseSystemAlbum => '从系统相册选择';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle => '从设备存储中选择视频文件';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return '选择视频失败: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix => '音频提取失败: ';

  @override
  String get audioSeparationEngineMissing => '未检测到音频分离引擎';

  @override
  String get audioSeparationEngineMissingHelp => '请重启应用或检查应用资源完整性。';

  @override
  String get audioSeparationNoVideoSelected => '暂未选择视频文件';

  @override
  String get audioSeparationSupportedFormatsHint => '支持 mp4、mov、m4v、3gp 格式';

  @override
  String get audioSeparationSuccess => '音频已成功提取并保存到音频库';

  @override
  String get audioSeparationView => '查看';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 个视频',
      one: '已选 $count 个视频',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => '提取中...';

  @override
  String get audioSeparationExtractAudio => '提取音频';

  @override
  String get audioSeparationSaveTo => '保存至';

  @override
  String get audioSeparationChooseSaveFolder => '选择保存文件夹';

  @override
  String get audioSeparationCannotReadVideoFile => '无法读取视频文件';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return '选择视频文件失败: $error';
  }

  @override
  String get audioSeparationUnknownFormat => '未知';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return '暂不支持 $formats 格式，仅支持 MP4、MOV、M4V、3GP。';
  }

  @override
  String get audioSeparationEngineUnavailable => '音频分离引擎不可用。';

  @override
  String get backgroundOptimizationTitle => '后台运行优化';

  @override
  String get backgroundOptimizationEnvironment => '系统环境检测';

  @override
  String get backgroundOptimizationChecks => '后台优化检测';

  @override
  String get backgroundOptimizationKeepAliveStrategies => '保活策略';

  @override
  String get backgroundOptimizationDetecting => '正在检测...';

  @override
  String get backgroundOptimizationUnsupportedStatus => '当前平台不支持后台服务';

  @override
  String get backgroundOptimizationServiceRunning => '后台服务运行中';

  @override
  String get backgroundOptimizationServiceStopped => '后台服务未启动';

  @override
  String get backgroundOptimizationServiceCheckFailed => '无法检测后台服务状态';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      '桌面端托盘暂不可用，关闭窗口将直接退出';

  @override
  String get backgroundOptimizationDesktopCloseExits => '桌面端关闭窗口时退出应用';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive => '桌面端使用托盘驻留保活';

  @override
  String get backgroundOptimizationStartFailed => '启动服务失败';

  @override
  String get backgroundOptimizationStopFailed => '停止服务失败';

  @override
  String get backgroundOptimizationRestartFailed => '重启服务失败';

  @override
  String get backgroundOptimizationStopService => '停止服务';

  @override
  String get backgroundOptimizationRestartService => '重新启动服务';

  @override
  String get backgroundOptimizationStartService => '启动服务';

  @override
  String get backgroundOptimizationRedetect => '重新检测';

  @override
  String get backgroundOptimizationUnsupportedControl => '当前平台不支持后台服务控制。';

  @override
  String get backgroundOptimizationCheckingBattery => '正在检测电池优化状态...';

  @override
  String get backgroundOptimizationBatteryIgnored => '已忽略电池优化';

  @override
  String get backgroundOptimizationBatteryMayKill => '未忽略电池优化 — 后台可能被杀';

  @override
  String get backgroundOptimizationIgnoreBattery => '忽略电池优化';

  @override
  String get backgroundOptimizationExactAlarm => '允许精确闹钟（保活更可靠）';

  @override
  String get backgroundOptimizationWatchdogTitle => 'AlarmManager 看门狗';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      '启用后，Android 系统会每 5 分钟用原生闹钟检查后台服务是否还活着。如果进程被系统杀掉，闹钟会触发自动重启。\n\n闹钟在设备休眠（Doze）模式下依然生效，重启后也会自动重新调度。\n\n适用场景：对后台任务要求极高的用户。\n耗电影响：极低（每次仅短暂唤醒检查一次）。';

  @override
  String get backgroundOptimizationSaveWatchdogFailed => '保存失败，看门狗设置未更改';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      '看门狗激活失败，后台服务保活状态未确认';

  @override
  String get backgroundOptimizationColdStartTitle => '冷启动自动恢复';

  @override
  String get backgroundOptimizationColdStartDetail =>
      '启用后，每次重新打开 App 时，会自动检测并恢复之前正在运行的后台服务。\n\n如果 App 进程被系统或用户手动杀掉，下次打开 App 时后台服务会自动重启，无需手动操作。\n\n适用场景：所有用户都建议开启。\n耗电影响：无（仅在 App 启动时检查一次）。';

  @override
  String get backgroundOptimizationSaveColdStartFailed => '保存失败，冷启动恢复设置未更改';

  @override
  String get backgroundOptimizationBatteryReminderTitle => '电池优化提醒';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      '启用后，本页面会显示电池优化状态卡片。如果检测到 App 未被添加到省电白名单，会提供一键跳转至系统设置进行豁免。\n\n电池优化是安卓系统省电机制（Doze），会限制后台应用的运行。添加到白名单后，系统不会因省电而杀掉本 App。\n\n适用场景：关闭本开关仅隐藏提醒卡片，不影响实际的电池优化豁免状态。';

  @override
  String get backgroundOptimizationStrategyIntro =>
      '以下策略可独立开关。默认全部启用以获得最强保活效果。关闭某项仅影响该策略，不会影响后台服务本身的运行。';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOS 后台任务提示';

  @override
  String get backgroundOptimizationIosSupported =>
      '当前系统（iOS 26 及以上）支持任务常驻后台：任务运行期间切换 App 或锁屏，任务通常会继续执行（系统资源紧张时可能终止），并可在锁屏界面查看进度。';

  @override
  String get backgroundOptimizationIosUnsupported =>
      '当前系统（低于 iOS 26）不支持任务常驻后台。任务运行时请每隔几分钟返回一次 App（建议 5–10 分钟，具体由系统决定），刷新后台执行时间，防止任务被系统挂起。';

  @override
  String get backgroundOptimizationIosWarning =>
      '注意：所有 iOS 版本都请勿在 App 切换器中划掉 Stroom——划掉会立即终止所有运行中的任务。';

  @override
  String get backgroundOptimizationDesktopIntro =>
      '桌面端没有移动系统的进程保活机制，但可以让应用在关闭窗口后继续运行。';

  @override
  String get backgroundOptimizationCloseMinimizeTitle => '关闭窗口时最小化';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      '启用后，点击窗口关闭按钮不会退出应用，而是隐藏到系统托盘继续运行，后台任务不受影响。\n\n可从托盘图标（或右键菜单「显示主窗口」）恢复窗口；需要真正退出时，点击下方「完全退出应用」按钮。\n\n适用场景：所有桌面用户都建议开启。';

  @override
  String get backgroundOptimizationQuitApp => '完全退出应用';

  @override
  String get backgroundOptimizationGotIt => '知道了';

  @override
  String get backgroundOptimizationWebNoteTitle => 'Web 后台任务提示';

  @override
  String get backgroundOptimizationWebNote =>
      '浏览器没有应用常驻后台的机制。关闭标签页、刷新页面，或浏览器冻结长时间不活跃的后台标签页，都会立即中断运行中的任务。任务运行时请保持 Stroom 标签页打开并处于前台。';

  @override
  String get backgroundOptimizationTutorial => '平台教程';

  @override
  String get backgroundOptimizationTutorialDescription => '查看各个平台的后台运行优化教程';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      '正在检测后台服务状态...';

  @override
  String get backgroundOptimizationServiceUnknown => '后台服务状态未知，请重新检测以确认服务是否运行。';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      '后台服务正在运行，任务将在后台正常执行。';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'Web 浏览器环境不支持后台服务运行。请保持页面打开以继续任务。';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      '桌面平台托盘暂不可用（Linux 构建需安装 libayatana-appindicator3-dev），关闭窗口将直接退出应用。';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      '桌面平台托盘暂不可用，关闭窗口将直接退出应用。';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      '桌面平台已设置为关闭窗口时退出：关闭窗口后应用会按现有退出确认流程处理并退出，不会在托盘继续运行。';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      '桌面平台已启用托盘驻留：关闭窗口后应用会隐藏到系统托盘继续运行，从托盘菜单选择「显示主窗口」即可恢复窗口。如需彻底退出，请从托盘菜单选择「退出 Stroom」。';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      '桌面平台已启用托盘驻留：关闭窗口后应用会最小化到系统托盘继续运行，点击托盘图标（或托盘菜单「显示主窗口」）即可恢复窗口。如需彻底退出，请从托盘菜单选择「退出 Stroom」。';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      '后台服务未启动。请点击下方「启动服务」按钮启动后台服务，或查看平台教程了解如何优化后台运行设置。';

  @override
  String get notificationSettingsPageTitle => '通知权限设置';

  @override
  String get notificationSettingsWebUnsupported => 'Web 环境不支持通知权限';

  @override
  String get notificationSettingsChecking => '正在检测...';

  @override
  String get notificationSettingsPermissionGranted => '通知权限已授权';

  @override
  String get notificationSettingsPermissionDenied => '通知权限未授予';

  @override
  String get notificationSettingsPermissionRestricted => '通知权限受限';

  @override
  String get notificationSettingsPermissionBlocked => '通知权限已被永久屏蔽';

  @override
  String get notificationSettingsPermissionProvisional => '通知权限为临时授权';

  @override
  String get notificationSettingsWebGuide => '当前为 Web 环境，不支持系统通知功能。';

  @override
  String get notificationSettingsCheckingPermission => '正在检测通知权限状态...';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      '通知权限已授予，您可以开启任务完成通知，在任务完成或失败时收到系统通知。';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      '通知权限尚未授予。您可以点击下方按钮请求权限，或在系统设置中手动开启 Stroom 的通知权限。';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      '通知权限受系统限制（如家长控制）。请在系统设置中检查 Stroom 的通知权限设置。';

  @override
  String get notificationSettingsEnvironment => '系统环境检测';

  @override
  String get notificationSettingsPermissionSection => '通知权限检测';

  @override
  String get notificationSettingsPlatformGuides => '平台指南';

  @override
  String get notificationSettingsGuideIntro =>
      '根据您的操作系统，按照以下步骤开启 Stroom 的通知权限。';

  @override
  String get notificationSettingsTaskCompleteTitle => '任务完成通知';

  @override
  String get notificationSettingsTaskCompleteDescription => '任务完成或失败时发送通知';

  @override
  String get notificationSettingsCheckAgain => '重新检测';

  @override
  String get notificationSettingsOpenSystemSettings => '前往系统设置';

  @override
  String get notificationSettingsRequestPermission => '请求权限';

  @override
  String get notificationSettingsGuideUnsupported => '当前平台暂不支持通知权限设置指南。';

  @override
  String get notificationSettingsUsageReason => '用于在任务完成时发送通知';

  @override
  String get notificationSettingsAndroidEnableTitle => '开启通知权限';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      '进入「设置」→「应用」→「Stroom」→「通知管理」，确保已允许通知权限。如果找不到 Stroom，请确认应用已安装。如果权限被禁用，请手动开启。';

  @override
  String get notificationSettingsAndroidDndTitle => '检查勿扰模式';

  @override
  String get notificationSettingsAndroidDndDescription =>
      '进入「设置」→「声音与振动」→「勿扰模式」，确认勿扰模式未开启，或已将在其中允许 Stroom 的通知。';

  @override
  String get notificationSettingsAndroidPopupTitle => '允许后台弹出通知';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      '部分 Android 系统（如 MIUI、EMUI、ColorOS 等）需要额外在应用信息中开启「允许通知」和「允许弹窗」。建议同时关闭该应用的「通知过滤」或「智能通知」功能。';

  @override
  String get notificationSettingsReturnTitle => '完成后返回此页面';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。如果权限已显示为已授权，即可开启任务完成通知开关。';

  @override
  String get notificationSettingsIosEnableDescription =>
      '进入「设置」→「通知」→「Stroom」，开启「允许通知」。建议同时开启「横幅」和「通知中心」以便及时获知任务状态。';

  @override
  String get notificationSettingsIosFocusTitle => '关闭专注模式';

  @override
  String get notificationSettingsIosFocusDescription =>
      '进入「设置」→「专注模式」，确保未开启或已将 Stroom 加入允许的应用列表。专注模式可能会屏蔽应用通知。';

  @override
  String get notificationSettingsIosReturnDescription =>
      '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。iOS 上通知权限通常需要用户手动在系统设置中开启。';

  @override
  String get notificationSettingsWindowsEnableTitle => '开启系统通知';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      '进入「设置」→「系统」→「通知和操作」，确保「获取来自应用和其他发送者的通知」已开启。在下方应用列表中找到 Stroom 并确保通知已开启。';

  @override
  String get notificationSettingsWindowsFocusTitle => '开启专注助手排除项';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      '进入「设置」→「系统」→「专注助手」，确保 Stroom 已加入「仅优先打断」或「关闭专注助手」。专注助手开启时会屏蔽通知。';

  @override
  String get notificationSettingsMacEnableTitle => '开启通知权限';

  @override
  String get notificationSettingsMacEnableDescription =>
      '进入「系统设置」→「通知」→「Stroom」，开启「允许通知」。建议同时开启「横幅」和「通知中心」。';

  @override
  String get notificationSettingsMacFocusDescription =>
      '进入「系统设置」→「专注模式」，确保未开启或已将 Stroom 加入允许的应用列表。';

  @override
  String get notificationSettingsLinuxDesktopTitle => '检查桌面环境通知设置';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      '根据您使用的桌面环境（GNOME、KDE、XFCE 等），进入「系统设置」→「通知」→ 找到 Stroom 并确保通知已开启。';

  @override
  String get notificationSettingsLinuxDaemonTitle => '检查是否安装了通知守护进程';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux 桌面环境需要安装通知守护进程（如 notify-osd 或 dunst）来显示系统通知。请确认您的系统中已安装并运行了通知守护进程。';

  @override
  String get backupRestorePageTitle => '数据备份与恢复';

  @override
  String get backupRestoreSelectBackupCategory => '请至少选择一项要备份的数据类别';

  @override
  String get backupRestorePreparingData => '正在准备数据...';

  @override
  String get backupRestoreExportingBackup => '正在导出备份';

  @override
  String get backupRestoreCollectingDatabase => '正在收集数据库记录...';

  @override
  String get backupRestoreProcessingSettings => '正在处理配置数据...';

  @override
  String get backupRestoreAddingTasks => '正在添加任务文件...';

  @override
  String get backupRestoreAddingPictures => '正在添加图片文件...';

  @override
  String get backupRestoreAddingAudio => '正在添加音频文件...';

  @override
  String get backupRestoreAddingVideo => '正在添加视频文件...';

  @override
  String get backupRestoreAddingText => '正在添加文本文件...';

  @override
  String get backupRestoreAddingChat => '正在添加聊天记录和附件...';

  @override
  String get backupRestoreCompressing => '正在压缩打包...';

  @override
  String get backupRestoreCompleted => '已完成';

  @override
  String get backupRestoreSelectRestoreCategory => '请至少选择一项要恢复的数据类别';

  @override
  String get backupRestoreConfirmRestore => '确认恢复';

  @override
  String get backupRestoreSelectedCategories => '已勾选的数据类别：';

  @override
  String get backupRestoreRestoreInfo =>
      '备份中实际包含的已勾选类别会恢复到本机。除内置浏览器 Cookies 外，其余类别会替换本机对应数据；Cookies 按域名、名称和路径写入，备份中没有的本机 Cookies 保持原样。未勾选或备份中缺少的类别保持原样；缺少的类别会跳过并提示。';

  @override
  String get backupRestoreRestartNotice => '恢复完成后需重启应用才能生效，请确保已保存当前工作。';

  @override
  String get backupRestoreCancel => '取消';

  @override
  String get backupRestoreConfirmRestoreButton => '确定恢复';

  @override
  String get backupRestoreIncompleteTitle => '恢复未完成';

  @override
  String get backupRestoreIncompleteMessage => '数据未能完整恢复，部分数据可能已被清除。请重启应用后重试。';

  @override
  String get backupRestoreSelectClearCategory => '请至少选择一项要清除的数据类别';

  @override
  String get backupRestoreClearingData => '正在清除数据';

  @override
  String get backupRestoreDeletingCategories => '正在删除所选类别的数据...';

  @override
  String get backupRestoreClearedTitle => '数据清除完成';

  @override
  String get backupRestorePartiallyClearedTitle => '部分数据已清除';

  @override
  String get backupRestoreClearedMessage => '所选数据已清除。请重启应用以生效。';

  @override
  String get backupRestorePartialClearMessage =>
      '其他所选数据已清除。当前平台不支持完整清除内置浏览器网站存储（localStorage、IndexedDB 等）；未能清除的浏览器数据仍会保留。请重启应用使已清除的数据生效。';

  @override
  String backupRestoreClearFailed(String error) {
    return '清除失败: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => '清除未完成';

  @override
  String get backupRestoreClearIncompleteMessage => '部分数据未能清除。请重启应用后重试清除操作。';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki闪卡片组已导出到: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get backupRestoreApkgRequired => '请选择 .apkg 格式的文件';

  @override
  String backupRestoreImportFailed(String error) {
    return '导入失败: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return '备份已保存到: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return '备份失败: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return '恢复失败: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected => '尚未选择备份目录，请在启动流程中授权';

  @override
  String get backupRestoreRestoreSuccessTitle => '数据恢复成功';

  @override
  String get backupRestoreRestoredMessage => '数据已从备份中恢复。请重启应用以使用恢复的数据。';

  @override
  String get backupRestoreExitApp => '退出应用';

  @override
  String get backupRestoreRestartNow => '立即重启';

  @override
  String get backupRestoreSkippedTitle => '部分数据已跳过';

  @override
  String get backupRestoreNothingRestoredTitle => '未恢复任何数据';

  @override
  String get backupRestoreGotIt => '知道了';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return '备份中未能确认以下勾选的数据类型包含可恢复内容，已跳过；当前数据保持不变：$categories。';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      '如果这是旧版备份，空任务文件无法区分“任务列表为空”和“该平台未导出任务”；为避免覆盖当前任务，任务类别已跳过并保留原数据。';

  @override
  String get backupRestoreSkippedCookies =>
      '备份中没有可导入的内置浏览器 Cookies，已跳过；本机现有 Cookies 保持不变。';

  @override
  String get backupRestoreSkippedWebsiteData =>
      '旧版备份中的网站存储目录已跳过；备份包若包含 Cookies 且该类别已勾选，仍可单独导入。';

  @override
  String get backupRestoreApkgTitle => 'Anki闪卡牌组';

  @override
  String get backupRestoreApkgInfoTitle => 'Anki 闪卡牌组导入/导出';

  @override
  String get backupRestoreApkgInfoMessage => '只包含卡片信息，不包含媒体内容';

  @override
  String get backupRestoreApkgDescription => '导入/导出 .apkg 格式的 Anki 牌组';

  @override
  String get backupRestoreExportingApkg => '导出中...';

  @override
  String get backupRestoreExportApkg => '导出 .apkg';

  @override
  String get backupRestoreImportingApkg => '导入中...';

  @override
  String get backupRestoreImportApkg => '导入 .apkg';

  @override
  String get backupRestoreCategoryHeading => '选择要备份或恢复的数据类别';

  @override
  String get backupRestoreExporting => '正在导出...';

  @override
  String get backupRestoreExportBackup => '导出备份';

  @override
  String get backupRestoreRestoring => '正在恢复...';

  @override
  String get backupRestoreChooseBackup => '选择备份文件并恢复';

  @override
  String get backupRestoreClearSelected => '清除所选数据';

  @override
  String get backupRestoreClearDescription =>
      '直接清除当前勾选的数据类别（不需要备份文件）。未勾选的类别将保持原样。此操作不可撤销。';

  @override
  String get backupRestoreClearing => '正在清除...';

  @override
  String get backupRestoreCategoryChat => '聊天记录和附件';

  @override
  String get backupRestoreCategoryChatDescription => '聊天对话记录、消息内容与附件文件';

  @override
  String get backupRestoreCategorySettings => '设置';

  @override
  String get backupRestoreCategorySettingsDescription => '应用配置、提供商设置与界面偏好';

  @override
  String get backupRestoreCategoryPictures => '图片';

  @override
  String get backupRestoreCategoryPicturesDescription => '照片和缩略图';

  @override
  String get backupRestoreCategoryAudio => '音频';

  @override
  String get backupRestoreCategoryAudioDescription => '语音合成和录音';

  @override
  String get backupRestoreCategoryVideos => '视频';

  @override
  String get backupRestoreCategoryVideosDescription => '视频文件';

  @override
  String get backupRestoreCategoryTexts => '文本';

  @override
  String get backupRestoreCategoryTextsDescription => '文本文档';

  @override
  String get backupRestoreCategoryTasks => '任务';

  @override
  String get backupRestoreCategoryTasksDescription => '后台任务记录';

  @override
  String get backupRestoreCategoryAnki => 'Anki闪卡数据';

  @override
  String get backupRestoreCategoryAnkiDescription => 'Anki 原始数据库';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki 闪卡数据';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      '备份和恢复 Anki 闪卡数据时会包含 collection.media 目录中的卡片媒体内容。';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'Anki 闪卡数据说明';

  @override
  String get backupRestoreCategoryBrowser => '内置浏览器数据';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      '仅备份与恢复 Cookies；清除时同时清理可支持的网站存储';

  @override
  String get backupRestoreViewInfo => '查看说明';

  @override
  String get backupRestoreApkgInfoTooltip => 'Anki 牌组导入导出说明';

  @override
  String get backupRestoreConfirmClear => '确认清除';

  @override
  String get backupRestoreClearCategoriesIntro => '将清除以下数据类别（不经过备份文件）：';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      '当前平台不支持完整清除内置浏览器网站存储（localStorage、IndexedDB 等）；确认后会清除其他所选数据，无法清除的浏览器数据将保留。';

  @override
  String get backupRestoreUnselectedUnchanged => '未勾选的类别将保持原样，不会被清除。';

  @override
  String get backupRestoreClearWarning => '此操作不可撤销。清除完成后需重启应用才能生效。';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return '确定清除（$seconds）';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => '浏览器环境';

  @override
  String get backupRestoreIntro =>
      '手动导出可按数据类别选择备份内容。导入时，只恢复已勾选且备份包中包含的类别；若备份缺少某类别或其必需文件不完整，该类别会自动跳过并提示，未勾选的类别保持原样。也可直接清除所选类别的数据。';

  @override
  String get backupRestoreOtherSelectedRestored => '其余所选数据已恢复，请重启应用以生效。';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      '通知已被系统屏蔽，请前往系统设置允许 Stroom 的通知权限。';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      '通知已被系统屏蔽。请前往系统设置 > 应用 > Stroom > 通知管理，允许通知权限。';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      '通知已被系统屏蔽。请前往系统设置 > Stroom > 通知，允许通知权限。';

  @override
  String get textPreviewDiscardEditsTitle => '放弃编辑？';

  @override
  String get textPreviewUnsavedChangesConfirm => '你有未保存的更改，确定要放弃吗？';

  @override
  String get textPreviewCancel => '取消';

  @override
  String get textPreviewDiscard => '放弃';

  @override
  String get textPreviewFontSize => '字号调整';

  @override
  String get textPreviewRestoreDefault => '恢复默认';

  @override
  String get textPreviewClose => '关闭';

  @override
  String textPreviewSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get textPreviewUndo => '撤销';

  @override
  String get textPreviewRedo => '重做';

  @override
  String get textPreviewSave => '保存';

  @override
  String get textPreviewEdit => '编辑';

  @override
  String get textPreviewChartEdit => '图表编辑';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return '跳过不支持的格式：$format';
  }

  @override
  String textStorageImportSuccess(int count) {
    return '已导入 $count 个文本文件';
  }

  @override
  String textStorageImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get textStorageSaved => '文本已保存';

  @override
  String get textStorageLoadFailed => '无法加载文本内容';

  @override
  String get textStorageReadFailed => '文件数据读取失败';

  @override
  String get textStorageExportTitle => '导出文本';

  @override
  String textStorageExportedTo(String path) {
    return '已导出到：$path';
  }

  @override
  String textStorageExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get textStorageChooseExportDirectory => '选择导出目录';

  @override
  String get textStorageFolderExportTitle => '文件夹导出';

  @override
  String get textStorageWebFolderExportInfo =>
      '浏览器无法选择导出目录，将下载保留文件夹层级的 ZIP 文件。';

  @override
  String get textStorageCancel => '取消';

  @override
  String get textStorageDownloadZip => '下载 ZIP 文件';

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
  String get batchDlgFileName => '文件名';

  @override
  String get batchDlgFolderName => '文件夹名';

  @override
  String get batchDlgFileNameConflict => '同一文件夹内存在同名文件';

  @override
  String get batchDlgFolderNameConflict => '目标位置已存在同名文件夹';

  @override
  String get batchDlgFolderNameSwapConflict => '文件夹之间不能在同一批次互换名称';

  @override
  String get batchDlgControlCharacterError => '名称不能包含控制字符';

  @override
  String get batchDlgNameWhitespaceError => '名称不能以空白开头或结尾，可添加空白清理规则';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind不能为空';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind不能以空白结尾';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind不能超过$count个字符';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind不能包含 Windows 非法字符';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind不能以 . 结尾';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind不能使用 Windows 保留名称';
  }

  @override
  String get batchDlgIntermediateNameTooLong => '中间名称过长，请调整规则';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return '该项目没有$date，请调整模板';
  }

  @override
  String get batchDlgCreatedDate => '创建时间';

  @override
  String get batchDlgModifiedDate => '修改时间';

  @override
  String get connectivityTestHttpSuccess => 'HTTP 工具请求成功';

  @override
  String get connectivityTestHttpFailure => 'HTTP 工具请求失败';

  @override
  String get connectivityTestInvalidMcpConfig => 'MCP 配置无效';

  @override
  String get connectivityTestMissingTransport => '缺少有效的传输类型配置。';

  @override
  String get connectivityTestStdioUnsupported => '当前平台不支持 stdio';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP 需要启动本地进程，请在 Stroom 桌面版中测试。';

  @override
  String get connectivityTestInvalidContent => '测试内容无效';

  @override
  String get connectivityTestMethodMustBeString => 'method 必须是字符串。';

  @override
  String get connectivityTestUnsupportedMethod => '不支持的测试方法';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      '为避免测试写入远程业务数据，MCP 连通性测试只允许只读的 tools/list 方法。';

  @override
  String get connectivityTestParamsMustBeObject => 'params 必须是 JSON 对象。';

  @override
  String get connectivityTestMcpConnectionFailed => '无法连接 MCP 服务';

  @override
  String get connectivityTestCheckConnectionSettings =>
      '请检查地址、认证信息和网络，或查看应用日志获取连接详情。';

  @override
  String get connectivityTestRemainingToolsOmitted => '；其余工具已省略';

  @override
  String get connectivityTestMcpSuccess => 'MCP 连通性测试成功';

  @override
  String connectivityTestToolNames(Object names) {
    return '：$names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return '连接及 tools/list 请求成功，共发现 $count 个工具$names$suffix。';
  }

  @override
  String get connectivityTestTodoMutationBlocked => '测试参数会修改待办数据';

  @override
  String get connectivityTestTodoReadOnly =>
      '为保护当前会话待办列表，连通性测试只允许省略 todos 或设置为 null。';

  @override
  String get connectivityTestUnknownBuiltin => '未知的内置工具';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return '找不到工具“$toolName”的测试执行器。';
  }

  @override
  String get connectivityTestBuiltinSuccess => '内置工具测试成功';

  @override
  String get connectivityTestBuiltinFailure => '内置工具测试失败';

  @override
  String get connectivityTestTopLevelObjectRequired => '测试内容顶层必须是 JSON 对象。';

  @override
  String get connectivityTestRequestTimeout => '请求超时，请检查服务响应和网络。';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'MCP 请求超时：$method';
  }

  @override
  String get connectivityTestResultTruncated => '…（结果已截断）';

  @override
  String get toolResultWebSearchEmptyQuery => '错误：搜索关键词不能为空。';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return '错误：不支持的搜索引擎“$source”。可选值：google、bing、baidu。';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return '首选引擎 $preferred $reason，已切换到 $fallback。';
  }

  @override
  String get toolResultWebSearchNotFound => '未找到相关搜索结果。';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return '未找到相关搜索结果（$sources 均明确返回无结果）。';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return '搜索不完整：$sources 明确返回无结果；其他引擎不可用或返回了无法解析的页面：$failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return '错误：所有搜索引擎均不可用。$failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return '来自 $source 的搜索结果：';
  }

  @override
  String get toolResultWebSearchLinkLabel => '链接';

  @override
  String get toolResultWebSearchSummaryLabel => '摘要';

  @override
  String get toolResultWebSearchEmptyResults => '未找到相关搜索结果。';

  @override
  String get toolResultTodoInvalid => '错误：todos 参数必须是数组（省略或传 null 表示读取待办列表）。';

  @override
  String get toolResultTodoEmpty => '当前没有待办事项。';

  @override
  String toolResultTodoCount(Object count) {
    return '$count 个待办事项未完成';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return '错误：MCP 服务器“$server”重新连接失败。';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return '错误：MCP 服务器“$server”当前不可用。';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return '错误：MCP 服务器“$server”连接失败或未返回任何工具，请检查服务器配置。';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return '真实工具“$tool”在此服务器上的调用名为“$alias”。';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return '同名工具“$tool”由多个 MCP 服务器提供；请使用对应调用名：$routes。';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return '错误：真实工具“$tool”存在名称冲突，请使用上面列出的调用名。';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return '错误：MCP 服务器“$server”没有名为“$tool”的工具。';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return '该服务器可用的工具：$tools。请改用这些工具名调用。';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return '错误：MCP 工具“$tool”当前使用了冲突别名。请使用对应调用名：$routes。';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return '错误：工具“$tool”已停用。';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return '错误：未知工具“$tool”';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => '未找到相关结果';

  @override
  String get toolResultWebSearchFallbackUnavailable => '暂不可用';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '（MCP 服务器 $server）';
  }

  @override
  String get toolResultWebSearchUnparsedResults => '未返回可解析的搜索结果';

  @override
  String get toolResultSearchTitleLabel => '标题';

  @override
  String get toolResultSearchContentLabel => '内容';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return '错误：$provider API Key 未配置，请在设置页面配置。';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return '错误：$provider 实例 URL 未配置，请在设置页面配置。';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return '错误：$provider 请求失败 (HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return '错误：$provider 请求失败：$detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return '错误：未知的 HTTP 工具“$provider”';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return '错误：MCP 服务器“$server”未连接。';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return '错误：MCP 工具“$tool”无响应。';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return '错误：$detail';
  }

  @override
  String get httpToolBraveDescription =>
      '使用 Brave Search API 搜索网络。需要配置 API Key。';

  @override
  String get httpToolBochaDescription =>
      '使用博查 AI Search API 搜索网络。需要配置 API Key。';

  @override
  String get httpToolQueritDescription => '使用 Querit Search 搜索网络。需要配置 API Key。';

  @override
  String get httpToolSearxngDescription =>
      '注重隐私保护的自托管元搜索引擎，可聚合多种搜索源。需要配置实例 URL。';

  @override
  String get httpToolSearchQueryDescription => '搜索关键词。';

  @override
  String get httpToolSearchCountDescription => '返回结果数量。';

  @override
  String get httpToolSearchCountMax20Description => '返回结果数量（最大 20）。';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return '导入完成：$decks 个牌组，$notes 个笔记，$cards 张卡片';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '找不到所选的 .apkg 文件：$path';
  }

  @override
  String get backupRestoreApkgInvalidArchive => '所选的 .apkg 文件已损坏或不是有效的压缩包。';

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
  String backupRestoreApkgLocalFileFailure(String path) {
    return '无法访问本地 Anki 文件：$path';
  }

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
  String get ankiSyncStatusProtocolFailed =>
      '同步服务器响应无效或不完整。请确认服务器支持 Anki sync v10。';

  @override
  String get ankiSyncStatusLoginRequired => '请先登录 Anki 同步账户，再继续操作。';

  @override
  String get ankiSyncStatusInvalidServerUrl => '请输入有效的 HTTP 或 HTTPS 同步服务器地址。';

  @override
  String get ankiSyncStatusHttpsRequired => '远程自建同步服务器必须使用 HTTPS。';

  @override
  String get ankiSyncStatusConnectionTimeout => '同步请求超时。请检查服务器地址和网络后重试。';

  @override
  String get ankiSyncStatusTlsFailure => '无法验证服务器证书。请检查证书或配置自定义 CA。';

  @override
  String get ankiSyncStatusConnectionFailure => '无法连接到同步服务器。请检查服务器地址和网络。';

  @override
  String get ankiSyncStatusRequestFailure => '同步请求失败。请检查服务器和网络后重试。';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return '同步服务器返回了 HTTP $statusCode。';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return '同步响应超过 $limitMb MB 限制。';
  }

  @override
  String get ankiSyncStatusLocalFileFailure => '无法读取或清理本地同步文件。请检查磁盘访问权限后重试。';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      '无法打开或更新 collection，或该文件未通过 SQLite/schema 校验。请恢复有效的 collection 备份或重新下载。';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return '同步服务器拒绝了请求（HTTP $statusCode）。请检查登录凭据和服务器权限。';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return '找不到同步接口（HTTP $statusCode）。请检查服务器地址。';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      '媒体同步服务器返回了无效响应。请确认服务器支持 Anki 媒体同步后重试。';

  @override
  String get ankiSyncStatusMediaIndexCorrupt => '本地媒体同步索引已损坏。请重置媒体同步数据后重试。';

  @override
  String get ankiSyncStatusMediaIndexFailure => '本地媒体同步索引无法读取或更新。';

  @override
  String get ankiSyncStatusMediaChecksumMismatch => '下载的媒体文件校验失败。请重试媒体同步。';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return '媒体文件“$filename”在本地和服务器上均有修改。请先备份并解决同名冲突，再重试。';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return '媒体文件名“$filename”无法同步。请将其重命名为符合 Anki 规则的名称后重试。';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return '媒体文件为空或超过 $limitMb MB 限制。';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return '媒体压缩包包含 $count 个条目，最多允许 $limit 个（含清单）。';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed => '媒体同步校验失败。请重试同步。';

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

  @override
  String get emojiCategorySmileys => '表情';

  @override
  String get emojiCategoryPeople => '人物';

  @override
  String get emojiCategoryAnimals => '动物';

  @override
  String get emojiCategoryFood => '食物';

  @override
  String get emojiCategoryActivities => '活动';

  @override
  String get emojiCategoryTravel => '旅行';

  @override
  String get emojiCategoryObjects => '物品';

  @override
  String get emojiCategorySymbols => '符号';

  @override
  String get emojiCategoryFlags => '旗帜';
}
