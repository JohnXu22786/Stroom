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
      '你是一个有帮助的AI助手。请用中文回答用户的问题。回答简洁明了，逻辑清晰。如果遇到不确定的信息，请坦诚说明。';

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
    return '$count 个模板';
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
    return '$count 个功能块';
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
    return '$count 张同时请求';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    return '并发 $count';
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
    return '请重新选择全部 $count 张图片后重试';
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
    return '已选 $count 张图片';
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
    return '已加载 $count 张图片';
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
    return '$count 个模型独立设置';
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
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

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
      '你是一个有帮助的AI助手。请用中文回答用户的问题。回答简洁明了，逻辑清晰。如果遇到不确定的信息，请坦诚说明。';

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
    return '$count 个模板';
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
    return '$count 个功能块';
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
    return '$count 张同时请求';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    return '并发 $count';
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
    return '请重新选择全部 $count 张图片后重试';
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
    return '已选 $count 张图片';
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
    return '已加载 $count 张图片';
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
    return '$count 个模型独立设置';
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
}
