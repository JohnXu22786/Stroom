Warning: truncated output (original token count: 124662)
Total output lines: 17480

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get languageSettingsTitle => '语言';

  @override
  String get followSystemLanguage => '跟随系统';

  @override
  String get languageNameEnglish => '英语';

  @override
  String get languageNameChinese => '简体中文';

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
  String get unifiedTas…104662 tokens truncated…护进程。';

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
  String get browserEditScript => '编辑脚本';

  @override
  String get browserScriptName => '脚本名称';

  @override
  String get browserScriptCode => '脚本代码 (JavaScript)';

  @override
  String get browserMatchUrls => '匹配网址（每行一个）';

  @override
  String get browserScriptMatchHint => '*://*.example.com/*';

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
}
