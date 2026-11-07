// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSettingsTitle => 'Language';

  @override
  String get followSystemLanguage => 'Follow system';

  @override
  String get themeDisplaySettingsTitle => 'Theme & Display';

  @override
  String get themeDisplayThemeSection => 'Theme';

  @override
  String get themeModeLight => 'Light mode';

  @override
  String get themeModeDark => 'Dark mode';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameChinese => 'Chinese (Simplified)';

  @override
  String get builtInPromptGeneralName => 'General Assistant';

  @override
  String get builtInPromptGeneralDescription =>
      'An all-purpose AI assistant for everyday conversation and answers to a wide range of questions.';

  @override
  String get builtInPromptGeneralPrompt =>
      'You are a helpful AI assistant. Answer the user in the language they use. Be concise, clear, and logically organized. If you are unsure about something, say so honestly.';

  @override
  String get builtInPromptCodeExpertName => 'Code Expert';

  @override
  String get builtInPromptCodeExpertDescription =>
      'An experienced programmer with expertise in many programming languages and technology stacks.';

  @override
  String get builtInPromptCodeExpertPrompt =>
      'You are an experienced software engineer skilled in many programming languages and technology stacks. Based on the user’s question, provide high-quality code examples, technical explanations, and best-practice recommendations. Prioritize readability, performance, and security. When providing code, label the language and use suitable formatting. For system-design questions, analyze trade-offs from an architecture perspective.';

  @override
  String get builtInPromptTranslationName => 'Translation Assistant';

  @override
  String get builtInPromptTranslationDescription =>
      'A professional translator for multilingual translation and localization advice.';

  @override
  String get builtInPromptTranslationPrompt =>
      'You are a professional translator. Your responsibilities are:\n1. Accurately translate the content the user provides while preserving its style and tone.\n2. Give a natural expression when the user asks how to say something in a particular language.\n3. Offer localization advice for culturally specific content.\n4. When several translations are possible, list them and explain their differences.\nAlways identify the source and target languages first; ask the user if either is unclear.';

  @override
  String get builtInPromptEnglishTeacherName => 'English Teacher';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      'An English learning tutor who helps improve listening, speaking, reading, and writing.';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      'You are an experienced English teacher. Meet the user’s needs with:\n1. Grammar explanations: explain rules clearly and include examples.\n2. Vocabulary learning: explain word usage, collocations, and distinctions.\n3. Writing polish: improve English so it sounds natural.\n4. Conversation practice: simulate English-speaking situations.\n5. Pronunciation guidance: use phonetic symbols and approximate pronunciation.\nAdjust the difficulty to the user’s English level and use Chinese to support explanations.';

  @override
  String get builtInPromptInterviewerName => 'Interviewer';

  @override
  String get builtInPromptInterviewerDescription =>
      'A simulated interviewer for technical and behavioral interviews.';

  @override
  String get builtInPromptInterviewerPrompt =>
      'You are a professional interviewer. Run a practice interview for the user’s target role:\n1. First learn the target position and industry.\n2. Ask relevant technical, behavioral, and system-design questions.\n3. Evaluate the user’s answers and suggest improvements.\n4. Provide sample answers and reasoning.\n5. Keep a realistic pace: ask one or two questions, then wait for the user.\nBe professional and friendly, with the goal of helping the user improve their interview skills.';

  @override
  String get builtInPromptWritingName => 'Writing Assistant';

  @override
  String get builtInPromptWritingDescription =>
      'A writing and editing assistant for many genres and creative writing.';

  @override
  String get builtInPromptWritingPrompt =>
      'You are a professional writing consultant. Based on the user’s needs, provide:\n1. Drafting: write in genres such as argumentative, expository, and narrative.\n2. Editing: improve grammar, word choice, logic, structure, and expression.\n3. Outlining: help build a framework and identify key points.\n4. Creative ideas: offer inspiration and possible angles.\n5. Formatting: follow the conventions of the target genre and submission requirements.\nFirst understand the purpose, intended readers, and desired style, then give focused advice.';

  @override
  String get builtInPromptCreativeThinkerName => 'Creative Thinker';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      'A creative ideation and brainstorming partner who sparks fresh ideas.';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      'You are a creative thinking partner. Your tasks are:\n1. Brainstorming: offer varied creative directions around a topic.\n2. Developing concepts: deepen and extend existing ideas.\n3. Connecting fields: combine concepts from different areas in new ways.\n4. Thinking in reverse: challenge conventional thinking and offer unusual perspectives.\n5. Feasibility review: analyze implementation challenges and potential value.\nEncourage divergent thinking while bringing the discussion into focus at the right time. Offer three to five directions per response.';

  @override
  String get builtInPromptDataAnalystName => 'Data Analyst';

  @override
  String get builtInPromptDataAnalystDescription =>
      'A data analysis expert who helps understand, model, and visualize data.';

  @override
  String get builtInPromptDataAnalystPrompt =>
      'You are a data analysis expert. Based on the user’s question, provide:\n1. Analysis methods: choose suitable statistical methods and analytical frameworks.\n2. SQL/Python/R code: give examples for data processing and analysis.\n3. Visualization advice: recommend suitable chart types and tools.\n4. Interpretation: explain findings and their business meaning.\n5. Data cleaning: handle missing values, outliers, and other quality issues.\nClarify the analysis goal and data characteristics first. Prefer the Python ecosystem (pandas, numpy, matplotlib, seaborn).';

  @override
  String get builtInPromptRoleplayName => 'Roleplay';

  @override
  String get builtInPromptRoleplayDescription =>
      'An immersive, multi-character roleplaying experience.';

  @override
  String get builtInPromptRoleplayPrompt =>
      'You are now in roleplay mode. Play the character specified by the user and interact according to that character’s personality, tone, and knowledge:\n1. When the user says “play [character],” switch to that character immediately.\n2. Stay in character throughout the conversation.\n3. Match the character’s language style and knowledge to the description.\n4. The user can say “end roleplay” to stop.\n5. You may add reasonable fictional details that fit the character.\nWait for the user to specify a character.';

  @override
  String get builtInPromptLifeAdvisorName => 'Life Advisor';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      'A warm, thoughtful listener offering mental-health support and everyday advice.';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      'You are a warm and thoughtful life advisor. Your responsibilities are:\n1. Listen actively and understand the user’s concerns and emotional needs.\n2. Analyze issues rationally and help the user sort through their aspects.\n3. Offer concrete, actionable ways to improve everyday life.\n4. Provide understanding, encouragement, and positive support.\n5. Suggest professional help when it is needed.\nRemember: you are not a licensed mental-health counselor. For a serious mental-health crisis, encourage the user to seek professional help. Be empathetic without overstepping; support the user without making decisions for them.';

  @override
  String get builtInSystemTitleName => 'Title Assistant';

  @override
  String get builtInSystemTitleDescription =>
      'Generates a short title automatically from the conversation.';

  @override
  String get builtInSystemTitlePrompt =>
      'You are a title generator. Output one conversation title and nothing else.\n\nRules:\n- Use one line and no more than 50 characters.\n- Do not explain or use quotation marks.\n- Use the same language as the user’s messages.\n- Do not include tool names such as web_search or todowrite in the title.\n\nExamples:\n“Help me debug a production 500 error” → Debugging a production 500 error\n“Refactor the user service” → Refactoring the user service\n“Why is app.js failing?” → Troubleshooting app.js\n\nIf the user’s message is very short or just a greeting (such as “hello,” “haha,” or “are you there?”), create a title that reflects its tone or intent, such as greeting, casual chat, or quick confirmation.';

  @override
  String get builtInSystemCompactionName => 'Context Compaction Assistant';

  @override
  String get builtInSystemCompactionDescription =>
      'Condenses a long conversation into a structured, anchored summary to free context space.';

  @override
  String get builtInSystemCompactionPrompt =>
      'You are an anchored-context summarization assistant. Condense long conversations into structured summaries.\n\nSummarize only the conversation history provided. Recent messages may be preserved verbatim, so focus on older context that is still important.\n\nIf the prompt contains a <previous-summary> block, treat it as the current anchored summary: keep what is still true, remove outdated material, and integrate new facts.\n\nFollow this structure exactly. Keep the section order and include every section, even if it is empty:\n<template>\n## Objective\n- [The user’s goal in one or two sentences]\n\n## Important Details\n- [Constraints/preferences, decisions and reasons, important facts/assumptions, and precise context needed to continue; write (none) if empty]\n\n## Work State\n### Completed\n- [Completed work, verified facts, or changes made; write (none) if empty]\n\n### Active\n- [Current work, partial changes, or investigation; write (none) if empty]\n\n### Blocked\n- [Blockers, failed commands, or unknowns; write (none) if empty]\n\n## Next Move\n1. [The next specific action, or (none)]\n2. [Known follow-up action, or (none)]\n\n## Relevant Files\n- [File or directory path and why it matters; write (none) if empty]\n</template>\n\nRules:\n- Include every section, even if empty.\n- Use concise bullet points, not paragraphs.\n- Preserve exact file paths, symbols, commands, error messages, URLs, and identifiers.\n- Do not mention that you are summarizing, compacting, or merging context.\n- Use the same language as the conversation.';

  @override
  String get builtInPromptMarketTitle => 'Assistant Market';

  @override
  String get builtInPromptClose => 'Close';

  @override
  String get builtInPromptImportHint =>
      'Imported prompts become regular assistants that you can edit freely.';

  @override
  String get builtInPromptView => 'View prompt';

  @override
  String get builtInPromptAdd => 'Add';

  @override
  String get builtInPromptDescriptionHeading => 'Description';

  @override
  String get builtInPromptSystemPromptHeading => 'System Prompt';

  @override
  String get builtInPromptAddAssistant => 'Add Assistant';

  @override
  String builtInPromptViewerTitle(Object name) {
    return 'Prompt · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      'Configure a separate model and prompt for automatic title generation and context compaction. By default, the current chat model and built-in prompts are used.';

  @override
  String get systemAssistantTitleName => 'Title Generation Assistant';

  @override
  String get systemAssistantTitleDescription =>
      'Automatically generates conversation titles';

  @override
  String get systemAssistantCompactionName => 'Context Compaction Assistant';

  @override
  String get systemAssistantCompactionDescription =>
      'Condenses long conversations into anchored summaries';

  @override
  String get systemAssistantFollowCurrentModel =>
      'Follow the current chat model';

  @override
  String get systemAssistantChooseModel => 'Choose a model';

  @override
  String get systemAssistantResetPromptTitle => 'Reset to Default Prompt';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return 'Restore the built-in default prompt for “$taskTitle”? Your current custom prompt will be discarded.';
  }

  @override
  String get systemAssistantCancel => 'Cancel';

  @override
  String get systemAssistantReset => 'Reset';

  @override
  String get systemAssistantModelHeading => 'Model';

  @override
  String get systemAssistantPromptHeading => 'Prompt';

  @override
  String get systemAssistantCustomPromptHint =>
      'Changes will be used as a custom prompt';

  @override
  String get systemAssistantUsingCustomPrompt => 'Using custom prompt';

  @override
  String get systemAssistantUsingDefaultPrompt => 'Using default prompt';

  @override
  String get systemAssistantSave => 'Save';

  @override
  String get systemAssistantResetButton => 'Reset to default prompt';

  @override
  String get taskFlowPageTitle => 'Task Flows';

  @override
  String get taskFlowSampleTemplatesTooltip => 'Example templates';

  @override
  String get taskFlowEmptyState => 'No flows yet. Tap + to create one.';

  @override
  String get taskFlowStartFromTemplate => 'Start from a template';

  @override
  String get taskFlowChooseTemplate => 'Choose an Example Template';

  @override
  String get taskFlowTemplateIntroduction =>
      'Choose a flow close to what you need; you can adjust it later.';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count templates',
      one: '$count template',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      'Templates open as drafts that need configuration. Choose a model and assistant before saving.';

  @override
  String get taskFlowTemplateRecordingName =>
      'Transcribe and Summarize a Recording';

  @override
  String get taskFlowTemplateRecordingDescription =>
      'Choose a recording → speech recognition → assistant summary';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'Configure an ASR model and choose an assistant for the summary.';

  @override
  String get taskFlowTemplateImageTextName =>
      'Recognize and Organize Image Text';

  @override
  String get taskFlowTemplateImageTextDescription =>
      'Choose an image → text recognition → assistant organization';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'Configure an OCR model and choose an assistant to organize the text.';

  @override
  String get taskFlowTemplateReadImageName => 'Read Text from an Image';

  @override
  String get taskFlowTemplateReadImageDescription =>
      'Choose an image → text recognition → speech playback';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'Configure OCR and speech synthesis models, then choose a voice.';

  @override
  String get taskFlowActions => 'Flow actions';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '$count block',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'OCR';

  @override
  String get taskFlowBlockAsr => 'Speech Recognition';

  @override
  String get taskFlowBlockAudioSeparation => 'Audio Separation';

  @override
  String get taskFlowBlockCatCatch => 'Web Resource Download';

  @override
  String get taskFlowBlockTts => 'Speech Synthesis';

  @override
  String get taskFlowBlockChat => 'Assistant Chat';

  @override
  String get taskFlowBlockCustom => 'Custom block';

  @override
  String get taskFlowEdit => 'Edit';

  @override
  String get taskFlowCopy => 'Copy';

  @override
  String get taskFlowCopied => 'Copied';

  @override
  String get taskFlowDelete => 'Delete';

  @override
  String get taskFlowConfirmDelete => 'Confirm deletion';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return 'Delete the task flow “$flowName”?';
  }

  @override
  String get taskFlowUseTemplate => 'Use';

  @override
  String get ocrTemplatePlainTextLabel => 'Plain Text';

  @override
  String get ocrTemplatePlainTextContent =>
      'Transcribe all visible text in the page’s natural reading order, preserving line breaks and paragraphs. Return plain text only; do not add explanations or inferences.';

  @override
  String get ocrTemplateMarkdownLabel => 'Markdown';

  @override
  String get ocrTemplateMarkdownContent =>
      'Transcribe all visible text in the page’s natural reading order and use Markdown to preserve headings, lists, and tables. Represent mathematical formulas in LaTeX. Return only the transcription; do not add explanations or inferences.';

  @override
  String get ocrTemplateTableLabel => 'Tables';

  @override
  String get ocrTemplateTableContent =>
      'Transcribe all visible text in the page’s natural reading order. For tables, preserve the headers, row and column relationships, and empty cells, and output them as Markdown tables. Keep other content as ordinary text. Return only the transcription; do not add explanations or inferences.';

  @override
  String get ocrTemplateLatexLabel => 'LaTeX';

  @override
  String get ocrTemplateLatexContent =>
      'Transcribe all visible text in the page’s natural reading order. Preserve non-formula text and represent mathematical formulas in LaTeX; use \$...\$ for inline formulas and \$\$...\$\$ for display formulas. Return only the transcription; do not add explanations or inferences.';

  @override
  String get ocrDefaultImagesOnly => 'Default (send images only)';

  @override
  String get ocrSavedInstructionSnapshot => 'Saved instruction snapshot';

  @override
  String get ocrPageTitle => 'Image Text Recognition';

  @override
  String get ocrImageQualitySettings => 'Image quality settings';

  @override
  String get ocrImageQualityStandard => 'Standard quality';

  @override
  String get ocrImageQualityStandardHint => 'Smaller images for most use cases';

  @override
  String get ocrImageQualityOriginal => 'Original / high detail';

  @override
  String get ocrImageQualityOriginalHint =>
      'Keeps more detail; images and requests are larger';

  @override
  String get ocrReorderDone => 'Done';

  @override
  String get ocrReorderAction => 'Reorder';

  @override
  String get ocrClearAction => 'Clear';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return 'The previous task used model $modelId. Choose a provider and model again.';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      'The model position in the previous retry record is invalid. Choose a model again.';

  @override
  String get ocrLegacyModelPositionConfirm =>
      'The previous retry record saved only the model position. Confirm the current model before continuing.';

  @override
  String get ocrModelUnavailable =>
      'The original OCR provider or model is no longer available. Choose another one.';

  @override
  String get ocrModelLabel => 'Model';

  @override
  String get ocrConfigure => 'Configure';

  @override
  String get ocrSelectModel => 'Select a model';

  @override
  String get ocrInstructionLabel => 'Instruction';

  @override
  String get ocrManageInstructions => 'Manage recognition instructions';

  @override
  String get ocrBatchMode => 'Batch mode';

  @override
  String get ocrMergeRecognition => 'Combine results';

  @override
  String get ocrRecognizeEachImage => 'Recognize each image separately';

  @override
  String get ocrMaxConcurrency => 'Up to 2 concurrent requests';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count concurrent requests',
      one: '$count concurrent request',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count concurrent requests',
      one: '$count concurrent request',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint =>
      'Completed pages are kept; retry submits only unfinished pages.';

  @override
  String get ocrTakePhoto => 'Take a photo';

  @override
  String get ocrChooseFromAlbum => 'Choose from album';

  @override
  String get ocrNoImagesSelected => 'No images selected';

  @override
  String get ocrSelectImagesHint =>
      'Take a photo or select multiple images from your album to recognize.';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return 'Select all $_temp0 again before retrying.';
  }

  @override
  String ocrImageLabel(Object index) {
    return 'Image $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return 'Image_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => 'Invalid image index';

  @override
  String get ocrViewErrorDetails => 'View error details';

  @override
  String get ocrConfirmModel => 'Confirm this model';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images selected',
      one: '$count image selected',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => 'Preparing images…';

  @override
  String get ocrSavingRetryImages => 'Saving retry images…';

  @override
  String get ocrRecognizing => 'Recognizing…';

  @override
  String get ocrReadingRetryImages => 'Reading retry images…';

  @override
  String get ocrImportingImages => 'Importing images…';

  @override
  String get ocrStartRecognition => 'Start recognition';

  @override
  String get ocrSaveTo => 'Save to';

  @override
  String get ocrRootDirectory => 'Root directory';

  @override
  String get ocrChooseSaveFolder => 'Choose a folder to save to';

  @override
  String get ocrChooseImageSource => 'Choose image source';

  @override
  String get ocrChooseAppAlbum => 'Choose from app album';

  @override
  String get ocrAppAlbumDescription => 'Choose images already saved in the app';

  @override
  String get ocrChooseSystemAlbum => 'Choose from system album';

  @override
  String get ocrSystemAlbumDescription =>
      'Browse and choose images on this device';

  @override
  String ocrTakePhotoFailed(Object error) {
    return 'Taking photo failed: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return 'Selecting image failed: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return 'Loaded $_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return 'Processing image failed: $error';
  }

  @override
  String get ocrUnknownSourceImageCount =>
      'Cannot determine the original image count';

  @override
  String get ocrConfirmClear => 'Confirm clear';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      'The original OCR image cache is unavailable and its image count cannot be recovered. Clearing will reset the old retry state. Select all images for this OCR task again.';

  @override
  String get ocrConfirmClearSelected => 'Clear the selected OCR images?';

  @override
  String get ocrCancel => 'Cancel';

  @override
  String get ocrConfirmResetAndReselect => 'Reset and select images again';

  @override
  String get ocrRequestCheckFailed =>
      'Unable to check the OCR request. Check the model parameters.';

  @override
  String get ocrCancelledAdjustAndRetry =>
      'Recognition was cancelled. Adjust the provider/model request size or image quality, then try again.';

  @override
  String get ocrRequestSizeExceededTitle =>
      'OCR request exceeds the configured size';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return 'The request is about $requestSize MiB, which exceeds the configured $limit MiB limit.';
  }

  @override
  String get ocrRequestSizeHelp =>
      'Adjust the request size in provider defaults or model overrides, or choose a different image quality. After changing quality, clear and import the images again.';

  @override
  String get ocrUsePerImageMode => 'Use per-image recognition';

  @override
  String get ocrGotIt => 'Got it';

  @override
  String get ocrWaitForImport =>
      'Wait for image import to finish before starting recognition.';

  @override
  String get ocrWaitForRetryImages => 'Reading retry images. Please wait.';

  @override
  String get ocrConfigureProviderModel =>
      'Configure an OCR provider and model in Settings first.';

  @override
  String get ocrReselectProviderModel =>
      'Select an OCR provider and model again.';

  @override
  String get ocrConfirmLegacyModel =>
      'Confirm the OCR model from the previous retry record first.';

  @override
  String get ocrRetryImagesUnavailable =>
      'The original OCR image cache is unavailable. Clear the task and select all images again.';

  @override
  String get ocrRetryImageCountUnknown =>
      'The original OCR image cache is unavailable and its image count is unknown. Reset and select all images for this OCR task again.';

  @override
  String get ocrRetryImageReset =>
      'The previous retry input was reset. Select all images for this OCR task again.';

  @override
  String get ocrRetryImagesUnreadable =>
      'The original OCR image cache could not be read. Clear the task and select all images again.';

  @override
  String get ocrRetryImagesMissing =>
      'The original OCR image cache is missing or damaged. Clear the task and select all images again.';

  @override
  String get ocrImageListChanged =>
      'The image list changed. Start recognition again.';

  @override
  String get ocrReadInstructionFailed =>
      'Unable to read the recognition instruction. Try again.';

  @override
  String get ocrErrorDetails => 'Error details';

  @override
  String get ocrRequestHeading => 'Request';

  @override
  String get ocrResponseHeading => 'Response';

  @override
  String get ocrNoDetails => 'No details available';

  @override
  String get ocrImageLoadFailed => 'Unable to load image';

  @override
  String get ocrCrop => 'Crop';

  @override
  String get ocrEdit => 'Edit';

  @override
  String get ocrProcessingOcrFailed =>
      'Failed to process the OCR images. Please try again.';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionProviders => 'Providers';

  @override
  String get settingsSectionSystemAssistant => 'System Assistants';

  @override
  String get settingsSectionContextManagement => 'Context Management';

  @override
  String get settingsSectionManagement => 'Management';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsBackupRestore => 'Backup and Restore';

  @override
  String get settingsBackupRestoreDescription => 'Export or import app data';

  @override
  String get settingsCookies => 'Cookies and Browser Data';

  @override
  String get settingsCookiesDescription =>
      'Manage persistent cookies and browser storage';

  @override
  String get settingsAppLogs => 'App Logs';

  @override
  String get settingsAppLogsDescription => 'View app runtime logs';

  @override
  String get settingsThemeDisplay => 'Theme and Display';

  @override
  String get settingsThemeDisplayDescription =>
      'Dark mode and display language';

  @override
  String get settingsTaskNotifications => 'Task Completion Notifications';

  @override
  String get settingsTaskNotificationsDescription =>
      'Check notification permission and system settings, and view the notification guide';

  @override
  String get settingsBackgroundOptimization =>
      'Background Operation Optimization';

  @override
  String get settingsBackgroundOptimizationDescription =>
      'Check system environment and background service status, and view optimization guidance';

  @override
  String get aboutVersionInfo => 'View version information';

  @override
  String get aboutCheckUpdates => 'Check for Updates';

  @override
  String aboutNewVersionFound(Object version) {
    return 'New version $version available';
  }

  @override
  String get aboutNewVersion => 'New Version';

  @override
  String get aboutPreviewUpdates => 'Preview Updates';

  @override
  String get aboutPreviewUpdatesDescription =>
      'Enable checks for preview releases';

  @override
  String get aboutProjectHome => 'Project Home';

  @override
  String get aboutFeedback => 'Report an Issue';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutOpenSourceAgreement => 'Open Source Agreement';

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutCheckingUpdates => 'Checking for updates…';

  @override
  String get aboutUpToDate => 'You are using the latest version';

  @override
  String aboutUpdateNetworkError(Object details) {
    return 'Network error: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return 'Update check failed with HTTP status $statusCode.';
  }

  @override
  String get aboutUpdateInvalidResponse =>
      'The update server returned an unexpected response.';

  @override
  String get aboutUpdateCheckFailed =>
      'The update check failed. Please try again.';

  @override
  String get aboutPrivacyContent =>
      'Stroom respects and protects the privacy of everyone who uses the service.\n\n1. Camera permission: Used only to take photos. No image data is collected or uploaded.\n\n2. Photo library permission: Used only to choose and save photos. All photos are stored locally on your device.\n\n3. Data security: All photos you take are stored locally on your device. We do not access or upload your data.\n\n4. Third-party services: This app contains no third-party analytics or advertising services.\n\nContact us if you have questions.';

  @override
  String get aboutClose => 'Close';

  @override
  String get contextToolPruneTitle =>
      'Automatically prune tool results (Prune)';

  @override
  String get contextToolPruneDescription =>
      'Automatically replace old tool results above the threshold with placeholders to free storage and context.';

  @override
  String get contextCompactionTriggerSettings => 'Compaction Trigger Settings';

  @override
  String get contextCompactionDisabled => 'Disabled (compaction will not run)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return 'Global trigger $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count model-specific overrides',
      one: '$count model-specific override',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => 'Compaction Trigger Settings';

  @override
  String get contextAutoCompaction => 'Automatic Context Compaction';

  @override
  String get contextAutoCompactionDisabled =>
      'When disabled, compaction will not run for any model.';

  @override
  String get contextGlobalTrigger => 'Global trigger percentage';

  @override
  String get contextGlobalTriggerDescription =>
      'Models without an individual setting use this percentage of the model context window as the compaction trigger.';

  @override
  String contextResetPercent(Object percent) {
    return 'Reset to $percent%';
  }

  @override
  String get contextPerModelSettings => 'Per-model settings';

  @override
  String get contextNoConfiguredModels => 'No configured models';

  @override
  String contextIndependentThreshold(Object threshold) {
    return 'Independent threshold: $threshold tokens';
  }

  @override
  String get contextEnterIndependentThreshold =>
      'Enter an independent threshold below';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return 'Follow global $percent%';
  }

  @override
  String get contextThresholdField => 'Independent threshold (tokens)';

  @override
  String get contextThresholdHint =>
      'For example, 48000 (token count, not a percentage)';

  @override
  String get contextPercentField => 'Percentage';

  @override
  String contextPercentHint(Object percent) {
    return 'For example, $percent';
  }

  @override
  String get versionInfoTitle => 'Version information';

  @override
  String get versionNumberLabel => 'Version';

  @override
  String get versionReleaseTimeLabel => 'Release time';

  @override
  String get versionLocalBuild => 'Local build';

  @override
  String get versionReleaseNotesLabel => 'Release notes';

  @override
  String get versionClose => 'Close';

  @override
  String get updateDialogTitle => 'New version available';

  @override
  String get updateLatestVersionLabel => 'Latest version';

  @override
  String get updateSelectedVersionLabel => 'Selected version';

  @override
  String get updateReleaseNotesLabel => 'Release notes';

  @override
  String get updateInstalling => 'Installing…';

  @override
  String get updateDownloadComplete => 'Download complete';

  @override
  String get updateClose => 'Close';

  @override
  String get updateManualInstall => 'Install manually';

  @override
  String get updateOpenInstaller => 'Open installer';

  @override
  String get updateRetryDownload => 'Retry download';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateRemindLater => 'Remind me later';

  @override
  String get updateOpenBrowser => 'Download in browser';

  @override
  String get updateNow => 'Update now';

  @override
  String get updatePreviewBadge => 'Preview';

  @override
  String get updateLatestBadge => 'Latest';

  @override
  String get updateSelectVersion => 'Select version';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String updateCheckNetworkError(Object details) {
    return 'Network error: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return 'Failed to check for updates: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      'Failed to check for updates: the server returned unrecognized data';

  @override
  String get updateDownloadUrlUnavailable => 'The download URL is unavailable.';

  @override
  String get updateNoDirectDownloadLink =>
      'There is no direct download link for this platform. Download it in a browser.';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return 'Automatic installation failed: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return 'Download failed: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return 'Download failed: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return 'Installation failed: $details';
  }

  @override
  String updateFailed(Object details) {
    return 'Update failed: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return 'Could not open the file. Install it manually: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return 'Installation failed. Open the APK manually: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails =>
      'Installation failed. Open the APK manually.';

  @override
  String get contextCompactionHistoryIntro =>
      'Conversation history to condense:';

  @override
  String get contextCompactionUserRole => 'User';

  @override
  String get contextCompactionAssistantRole => 'Assistant';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role called tool $toolName: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      'Condense the conversation history above into an anchored summary, following the template exactly.';

  @override
  String get ocrImageEmpty => 'The image is empty. Select it again.';

  @override
  String get ocrImageUnsupportedFormat =>
      'This image format is not supported. Convert it to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'HEIC, SVG, and TIFF images are not supported yet. Convert the image to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImageDecodeFailed =>
      'The image is damaged or cannot be decoded. Select it again, or convert it to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImageDimensionsTooLarge =>
      'The image resolution is too large. OCR supports up to 50 million pixels per image. Resize it and try again.';

  @override
  String get ocrImageOrientationPngTooLarge =>
      'The PNG needed to correct this image orientation would exceed the OCR request size limit. Resize the image and try again.';

  @override
  String get ocrImageOrientationFailed =>
      'The image orientation could not be corrected. Convert it to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImagePreparationFailed =>
      'The image could not be processed. Select it again and try again.';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeWelcome => 'Welcome to Stroom';

  @override
  String get homeChooseModule => 'Choose a module to get started';

  @override
  String get homeOcrSubtitle => 'Text recognition';

  @override
  String get homeAsrTitle => 'Speech recognition';

  @override
  String get homeAsrSubtitle => 'Speech to text';

  @override
  String get homeWebDownloadTitle => 'Download web media';

  @override
  String get homeWebDownloadSubtitle =>
      'Download audio and video from webpages';

  @override
  String get homeAudioSeparationTitle => 'Audio separation';

  @override
  String get homeAudioSeparationSubtitle => 'Extract audio from video';

  @override
  String get homeTtsTitle => 'Text to speech';

  @override
  String get homeTtsSubtitle => 'Convert text to speech';

  @override
  String get homeChartsTitle => 'Chart maker';

  @override
  String get homeChartsSubtitle => 'Mermaid chart editor';

  @override
  String get homeMathTitle => 'Math plotting';

  @override
  String get homeMathSubtitle => 'Plot functions';

  @override
  String get homeAnkiTitle => 'Anki flashcards';

  @override
  String get homeAnkiSubtitle => 'Memory aid system';

  @override
  String get homeTaskFlowTitle => 'Task flows';

  @override
  String get homeTaskFlowEmpty =>
      'Create an automated flow to run multiple modules in sequence';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count task flows · Manage',
      one: '$count task flow · Manage',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => 'Recent tasks';

  @override
  String get homeViewAll => 'View all';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get navHome => 'Home';

  @override
  String get navChat => 'Chat';

  @override
  String get navFiles => 'Files';

  @override
  String get navSettings => 'Settings';

  @override
  String get conversationsTitle => 'Conversation history';

  @override
  String get conversationNew => 'New conversation';

  @override
  String get conversationSelectTitle => 'Choose a conversation';

  @override
  String get topicSelectionEmptyTitle => 'No conversations yet';

  @override
  String get topicSelectionEmptyMessage =>
      'Create a new conversation to get started';

  @override
  String get topicSelectionNewTopic => 'New conversation';

  @override
  String get topicSelectionNoAssistant => 'No assistant selected';

  @override
  String get topicSelectionBackToAssistants => 'Back to assistant selection';

  @override
  String get topicSelectionEditAssistant => 'Edit assistant';

  @override
  String get topicSelectionReorderHint =>
      'Long-press and drag to reorder conversations';

  @override
  String conversationDeleteNamed(String title) {
    return 'Delete conversation “$title”? This cannot be undone.';
  }

  @override
  String get conversationDeleteTitle => 'Delete conversation';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the selected $count conversations? This cannot be undone.',
      one: 'Delete the selected $count conversation? This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get conversationRename => 'Rename conversation';

  @override
  String get conversationRenameHint => 'Enter a new name';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get conversationNoMatches => 'No matching conversations found';

  @override
  String get conversationEmpty => 'No conversation history';

  @override
  String get conversationSearchHint =>
      'Search messages in all conversations...';

  @override
  String conversationSelected(int count) {
    return '$count selected';
  }

  @override
  String get conversationSearch => 'Search';

  @override
  String get conversationDeleteSelected => 'Delete selected';

  @override
  String get actionUnselect => 'Cancel selection';

  @override
  String get actionSelect => 'Select';

  @override
  String conversationDeleteCount(int count) {
    return 'Delete $count';
  }

  @override
  String get conversationPin => 'Pin';

  @override
  String get conversationUnpin => 'Unpin';

  @override
  String get actionRename => 'Rename';

  @override
  String get conversationAutoRename => 'Auto-name';

  @override
  String get conversationTemporary => 'Temporary conversation';

  @override
  String get conversationCloseTemporary => 'Close temporary conversation';

  @override
  String get taskListTitle => 'Task list';

  @override
  String get taskListEmpty => 'No tasks';

  @override
  String get unifiedTaskListTabAll => 'All';

  @override
  String get unifiedTaskListTabInProgress => 'In progress';

  @override
  String get unifiedTaskListTabCompleted => 'Completed';

  @override
  String get unifiedTaskListTabFailed => 'Failed';

  @override
  String get unifiedTaskListTabStopped => 'Stopped';

  @override
  String get unifiedTaskListConfirmClear => 'Confirm clear';

  @override
  String get unifiedTaskListConfirmClearFailedMessage =>
      'Are you sure you want to clear all failed tasks?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      'Are you sure you want to clear all tasks? This action cannot be undone.';

  @override
  String get unifiedTaskListCancel => 'Cancel';

  @override
  String get unifiedTaskListConfirm => 'Confirm';

  @override
  String get unifiedTaskListClearCompleted => 'Clear completed tasks';

  @override
  String get unifiedTaskListClearFailed => 'Clear failed tasks';

  @override
  String get unifiedTaskListClearAll => 'Clear all tasks';

  @override
  String get unifiedTaskListRestoreInProgress => 'Restoring task flow records…';

  @override
  String get unifiedTaskListRestoreFailed =>
      'Could not read task flow records; task actions are paused';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return 'Clear incomplete: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning =>
      'The task flow is still running after cancellation.';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      'Could not save the task flow cancellation state. Please retry clearing.';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      'Could not save deletion of task flow records. Please retry clearing.';

  @override
  String get chatAutoContinuePrompt => 'Continue if not finished.';

  @override
  String get chatSearchCurrent => 'Search this conversation...';

  @override
  String get chatSearchAll => 'Search all conversations...';

  @override
  String get searchPrevious => 'Previous match';

  @override
  String get searchNext => 'Next match';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchCurrentConversation => 'Current conversation';

  @override
  String get searchAllConversations => 'All conversations';

  @override
  String get chatReasoning => 'Reasoning';

  @override
  String get chatTools => 'Tools';

  @override
  String get chatCustomParameters => 'Custom parameters';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get actionClose => 'Close';

  @override
  String get chatEditWarning =>
      'All messages below will be lost when you edit and resend';

  @override
  String get chatAttachment => 'Attachment';

  @override
  String get chatMessageHint => 'Enter a message...';

  @override
  String get chatFullscreenEdit => 'Full-screen editor';

  @override
  String get chatStopGeneration => 'Stop generating';

  @override
  String get actionSend => 'Send';

  @override
  String get chatCopy => 'Copy';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionEdit => 'Edit';

  @override
  String get chatViewResponseData => 'View response data';

  @override
  String get chatViewRequestData => 'View request data';

  @override
  String get chatInspectJson => 'Inspect JSON';

  @override
  String get chatConfirmEditTitle => 'Edit message';

  @override
  String get chatConfirmEditDeleteFollowing =>
      'Edit this message? This message and all following messages will be deleted.';

  @override
  String get chatConfirmResend => 'Resend this message?';

  @override
  String get chatConfirmRetryTitle => 'Retry';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      'Retry this response? This message and all following messages will be deleted.';

  @override
  String get chatConfirmRegenerate => 'Regenerate the response?';

  @override
  String get chatDeleteMessageTitle => 'Delete message';

  @override
  String get chatDeleteMessageConfirm =>
      'Delete this message? This cannot be undone.';

  @override
  String get chatThinking => 'Thinking';

  @override
  String get chatThinkingComplete => 'Thought';

  @override
  String get conversationDeleteOne =>
      'Delete this conversation? This cannot be undone.';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Selected $selected/$total resources',
      one: 'Selected $selected/$total resource',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => 'Select media to download';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hide $count segments',
      one: 'Hide $count segment',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count segments',
      one: 'Show $count segment',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => 'No resources detected';

  @override
  String get mediaSegment => 'Segment';

  @override
  String get mediaPlaylist => 'Playlist';

  @override
  String get mediaFullVideo => 'Full video';

  @override
  String mediaDuration(String value) {
    return 'Duration: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return 'Resolution: ${width}x$height';
  }

  @override
  String get mediaPreview => 'Preview';

  @override
  String get mediaSegmentPreviewHint => 'Preview segments from the playlist';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count selected resources',
      one: 'Download $count selected resource',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => 'Confirm download';

  @override
  String get chatNoMoreHistory => 'No more messages';

  @override
  String get chatSendFailed => 'Message failed to send';

  @override
  String get chatViewErrorDetails => 'View error details';

  @override
  String get chatCompactionCollapsed =>
      'Context compacted · older messages summarized (click to collapse)';

  @override
  String get chatCompactionExpanded =>
      'Context compacted · older messages summarized (click to view summary)';

  @override
  String get chatEditConversationTitle => 'Edit conversation title';

  @override
  String get chatSearchMessages => 'Search messages';

  @override
  String get chatApiMissingSettings =>
      '⚠️ Chat API is not configured — go to Settings';

  @override
  String get appSettings => 'Settings';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatNoSavableText => 'There is no text to save';

  @override
  String get chatSaveMarkdownTitle => 'Save message as Markdown';

  @override
  String get chatSaveToolCallChoice =>
      'This reply contains multiple tool calls. Choose what to save:';

  @override
  String get chatSaveCompleteMessage => 'Save complete message';

  @override
  String get chatSaveLastMessage => 'Save last message';

  @override
  String get chatSaveToAppFiles => 'Save to app files';

  @override
  String get chatSaveFolderHint => 'Choose or create a folder for the .md file';

  @override
  String get chatSaveFilenameHint =>
      'Enter a file name (.md is added automatically)';

  @override
  String get chatFilenameRequired => 'The file name cannot be empty';

  @override
  String chatSavedToPath(String path) {
    return 'Saved to: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return 'Saved to app files: $path';
  }

  @override
  String get chatSelectModel => 'Select a model';

  @override
  String get chatNoModelsAvailable => 'No models available';

  @override
  String get chatAvailableTools => 'Available tools';

  @override
  String get chatNoToolsAvailable => 'No tools available';

  @override
  String get chatReasoningSettings => 'Reasoning settings';

  @override
  String get chatReasoningNotConfigured =>
      'No reasoning parameters are configured for this model. Add them in model settings.';

  @override
  String get chatReasoningEffort => 'Reasoning effort';

  @override
  String get chatReasoningEffortNotConfigured =>
      'No reasoning effort parameter is configured for this model. Add it in model settings.';

  @override
  String get chatParameterNoOptions =>
      'This parameter has no option values. Add them in model settings.';

  @override
  String get chatOtherReasoningNotConfigured =>
      'No other reasoning parameters are configured for this model.\nAdd them in model settings.';

  @override
  String get chatCustomParamsNotConfigured =>
      'No custom parameters are configured for this model.\nAdd them in model settings.';

  @override
  String get chatNoOptionValues =>
      'No option values. Add them in model settings.';

  @override
  String get chatImageLoadFailed => 'Unable to load image';

  @override
  String get chatVideoLoadFailed => 'Unable to load video';

  @override
  String get chatHtmlLoading => 'Loading HTML preview...';

  @override
  String get chatPreviewLoadFailed => 'Preview failed to load';

  @override
  String get albumPickerLoadFailed => 'Unable to load the app album';

  @override
  String get chatHtmlPreview => 'HTML preview';

  @override
  String get chatMermaidLoading => 'Loading chart preview...';

  @override
  String get chatMermaidPreview => 'Mermaid preview';

  @override
  String get chatZoomOut => 'Zoom out';

  @override
  String get chatZoomIn => 'Zoom in';

  @override
  String get chatJsonInspection => 'JSON inspection';

  @override
  String get chatNoRequestData => 'No request data';

  @override
  String get chatNoResponseData => 'No response data';

  @override
  String get chatSaveMessage => 'Save message';

  @override
  String get chatChooseSaveLocation => 'Choose where to save the message';

  @override
  String get chatChooseSaveLocationLabel => 'Choose a save location:';

  @override
  String get chatSaveAppFile => 'Save to app files';

  @override
  String get chatSaveDevice => 'Save to device';

  @override
  String get chatFileTypeAudio => 'Audio file';

  @override
  String get chatFileTypeVideo => 'Video file';

  @override
  String get chatFileTypeDocument => 'Document';

  @override
  String get chatFileTypeGeneric => 'File';

  @override
  String get chatInfoType => 'Type';

  @override
  String get chatInfoSize => 'Size';

  @override
  String get chatInfoPath => 'Path';

  @override
  String get chatErrorBack => 'Back';

  @override
  String get chatDataDetails => 'Data details';

  @override
  String get chatAudioPreviewClose => 'Close';

  @override
  String get chatPreviewClose => 'Close preview';

  @override
  String get actionBack => 'Back';

  @override
  String get chatCannotLoadFile => 'Unable to load file';

  @override
  String chatThinkingNumbered(int index) {
    return 'Thinking $index';
  }

  @override
  String get taskFlowUiDiscardTitle => 'Discard unsaved changes?';

  @override
  String get taskFlowUiDiscardBody =>
      'All unsaved changes will be lost if you go back.';

  @override
  String get taskFlowUiContinueEditing => 'Continue editing';

  @override
  String get taskFlowUiDiscard => 'Discard';

  @override
  String get taskFlowUiUndo => 'Undo';

  @override
  String get taskFlowUiSave => 'Save';

  @override
  String get taskFlowUiNameHint => 'Enter a task flow name';

  @override
  String get taskFlowUiDescriptionHint => 'Add a description (optional)';

  @override
  String get taskFlowUiNameRequired => 'Enter a task flow name';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return 'Step $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '“$parameter” is required for “$block”';
  }

  @override
  String get taskFlowUiSaveFailed =>
      'Could not save. Your changes are still here. Try again.';

  @override
  String get taskFlowUiRetry => 'Retry';

  @override
  String get taskFlowUiUpdated => 'Task flow updated';

  @override
  String get taskFlowUiCreated => 'Task flow created';

  @override
  String get taskFlowUiTitle => 'Task Flow';

  @override
  String get taskFlowUiNotFound => 'Task not found';

  @override
  String get taskFlowUiBack => 'Back';

  @override
  String get taskFlowUiEdit => 'Edit';

  @override
  String taskFlowUiInput(Object label) {
    return 'Input ($label)';
  }

  @override
  String get taskFlowUiInputHint => 'Enter text or a link';

  @override
  String get taskFlowUiStart => 'Start task flow';

  @override
  String get taskFlowUiNoInput =>
      'No inputs yet. Tap below to add a web resource URL.';

  @override
  String get taskFlowUiAddResource => 'Add web resource';

  @override
  String get taskFlowUiUrlHint => 'Enter a video or audio webpage URL';

  @override
  String get taskFlowUiDeleteInput => 'Remove this input';

  @override
  String get taskFlowUiHour => 'hr';

  @override
  String get taskFlowUiMinute => 'min';

  @override
  String get taskFlowUiSecond => 'sec';

  @override
  String get taskFlowUiPreview => 'Preview: ';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      'Optional: filter video resources by duration. Leave blank to show all available resources.';

  @override
  String get taskFlowUiSelectImages => 'Select images (multiple)';

  @override
  String get taskFlowUiSelectAudio => 'Select audio (multiple)';

  @override
  String get taskFlowUiSelectFiles => 'Select files (multiple)';

  @override
  String get taskFlowUiSelectVideo => 'Select videos (multiple)';

  @override
  String get taskFlowUiRemove => 'Remove';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return 'Could not clean up the removed file: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0. Initial input';

  @override
  String taskFlowUiInputType(Object type) {
    return 'Input type: $type';
  }

  @override
  String get taskFlowUiUserFlowInput =>
      'Input provided when the user runs the task flow';

  @override
  String taskFlowUiBlockInput(Object type) {
    return 'Input: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return 'Output: $type';
  }

  @override
  String get taskFlowUiParameters => 'Parameters:';

  @override
  String get taskFlowUiClose => 'Close';

  @override
  String get taskFlowUiSelectAppImages =>
      'Select images from the app (multiple)';

  @override
  String get taskFlowUiNoImages => 'No images';

  @override
  String get taskFlowUiSelectAppAudio => 'Select audio from the app (multiple)';

  @override
  String get taskFlowUiNoAudio => 'No audio';

  @override
  String get taskFlowUiSelectAppVideo =>
      'Select videos from the app (multiple)';

  @override
  String get taskFlowUiNoVideo => 'No videos';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return 'Could not select the file: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '“$name” exceeds $limit MB. Choose a smaller file.';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '“$name” is empty or unreadable';
  }

  @override
  String get taskFlowUiSomeFilesMissing =>
      'Some files are missing and were skipped';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return 'Unable to access $count selected file(s). Please select all files again.';
  }

  @override
  String get taskFlowUiQueuedOne => 'Task flow added to the queue';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return 'Added $count task flows to the queue';
  }

  @override
  String get taskFlowUiRunTitle => 'This Run';

  @override
  String get taskFlowUiCancelBatch => 'Cancel entire batch';

  @override
  String get taskFlowUiRestoringRecords => 'Restoring task flow records…';

  @override
  String get taskFlowUiRecordsPaused =>
      'Could not load task flow records. Task actions are paused.';

  @override
  String get taskFlowUiRecordsCleared =>
      'Records for this run have been cleared';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$finished of $total runs finished';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return ' · $count records cleared';
  }

  @override
  String get taskFlowUiTemporaryFiles => 'Temporary intermediate files';

  @override
  String get taskFlowUiAddBlock => 'Add block';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return 'Insert block before step $index';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      'No block is compatible with both adjacent steps. Adjust the adjacent steps first.';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return 'Insert before step $index';
  }

  @override
  String get taskFlowUiUnknown => 'Unknown';

  @override
  String get taskFlowUiChooseBlock => 'Choose a block';

  @override
  String get taskFlowUiInsertBlock => 'Insert block';

  @override
  String get taskFlowUiPreviousOutput => 'Previous step output';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '; next step needs: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock =>
      'No block is compatible with the current type';

  @override
  String get taskFlowUiReplaceBlock => 'Replace block';

  @override
  String get taskFlowUiBlockCompatibility =>
      'You can only replace this with a block that has compatible input and output types.';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      'Clean up after the next step saves its result successfully; the final step is always kept.';

  @override
  String get taskFlowUiSetParameters => 'Set parameters';

  @override
  String get taskFlowUiReplace => 'Replace';

  @override
  String get taskFlowUiViewParameters => 'Tap to view parameters';

  @override
  String get taskFlowUiTapSetParameters => 'Tap to set parameters';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return 'Unknown block: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => 'This block type is not registered';

  @override
  String taskFlowUiStepActions(Object index) {
    return 'Actions for step $index';
  }

  @override
  String get taskFlowUiInsertBefore => 'Insert before';

  @override
  String get taskFlowUiInsertAfter => 'Insert after';

  @override
  String get taskFlowUiCopyBlock => 'Duplicate block';

  @override
  String get taskFlowUiMoveUp => 'Move up';

  @override
  String get taskFlowUiMoveUpDisabled => 'Move up (already first)';

  @override
  String get taskFlowUiMoveDown => 'Move down';

  @override
  String get taskFlowUiMoveDownDisabled => 'Move down (already last)';

  @override
  String get taskFlowUiDeleteBlock => 'Delete block';

  @override
  String taskFlowUiInputLabel(Object label) {
    return 'Input: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return 'Output: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return 'Block type “$name” is not registered';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$label settings';
  }

  @override
  String get taskFlowUiSendToAssistant =>
      'The user message sent to the assistant is the previous step’s output';

  @override
  String get taskFlowUiTempSpaceInfo =>
      'This step outputs to the flow’s temporary space. Its output is cleaned up after the next step saves successfully. The original save folder is preserved and restored when temporary mode is disabled.';

  @override
  String get taskFlowUiNoExtraParameters =>
      'This block has no additional parameters';

  @override
  String get taskFlowUiCancel => 'Cancel';

  @override
  String get taskFlowUiConfirm => 'Confirm';

  @override
  String get taskFlowUiConfigureModelFirst => 'Configure a model first';

  @override
  String get taskFlowUiModelUnavailable =>
      'No model is selected or the model is unavailable. Select another model.';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return 'Model $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => 'Unnamed provider';

  @override
  String get taskFlowUiCustomModelParameters => 'Custom model parameters';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      'No TTS models have configured voices. You can enter an ID manually.';

  @override
  String get taskFlowUiVoiceUnavailable =>
      'Voice is unavailable. Select another voice.';

  @override
  String get taskFlowUiSelectVoice => 'Select a voice';

  @override
  String get taskFlowUiAssistantUnavailable => 'Assistant unavailable';

  @override
  String get taskFlowUiAssistantUseCurrent =>
      'Not specified (use the currently selected assistant)';

  @override
  String get taskFlowUiAssistantDeleted =>
      'The configured assistant was deleted. Select another assistant.';

  @override
  String get taskFlowUiChooseAssistant => 'Choose an assistant';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      'Only “My Assistants” can be selected (add one in “Chat → Assistants”)';

  @override
  String get taskFlowUiMyAssistants => 'My Assistants';

  @override
  String get taskFlowUiNoCustomAssistants =>
      'No custom assistants yet. Create one in “Chat → Assistants”.';

  @override
  String get taskFlowUiYes => 'Yes';

  @override
  String get taskFlowUiNo => 'No';

  @override
  String get taskFlowUiDefaultRoot => 'Default (root folder)';

  @override
  String get taskFlowUiSelect => 'Select';

  @override
  String get taskFlowUiSelectSaveFolder => 'Choose a save folder';

  @override
  String get taskFlowUiCatCatchVideo => 'Video';

  @override
  String get taskFlowUiCatCatchAudio => 'Audio';

  @override
  String get taskFlowUiCatCatchEither =>
      'Video or audio (filter based on downstream steps)';

  @override
  String get taskFlowUiManual => 'Manual';

  @override
  String get taskFlowUiAutomatic => 'Automatic';

  @override
  String get taskFlowUiAutomaticPrompt => 'Automatic with confirmation';

  @override
  String get taskFlowUiEditTitle => 'Edit Task Flow';

  @override
  String get taskFlowUiCreateTitle => 'New Task Flow';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return 'Step $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return 'Input type: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return 'Input: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return 'Output: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return 'Could not clean up the removed file: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return 'Could not select the file: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '“$name” exceeds $limit MB. Choose a smaller file.';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '“$name” is empty or unreadable';
  }

  @override
  String get taskFlowUiTemporary => 'Temporary';

  @override
  String get taskFlowUiTemporaryFileHint =>
      'Temporary file (cleaned up after the next step succeeds)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return 'Block type “$name” is not registered';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$finished of $total runs finished';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return ' · $count records cleared';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return 'Input: $input → Output: $output';
  }

  @override
  String get taskFlowCardTag => 'Task Flow';

  @override
  String get taskFlowCardQueued => 'Queued (waiting for resources)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done of $total completed';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count $label';
  }

  @override
  String get taskFlowCardFailedLabel => 'failed';

  @override
  String get taskFlowCardSkippedLabel => 'skipped';

  @override
  String get taskFlowCardCancelledLabel => 'cancelled';

  @override
  String get taskFlowCardInterruptedLabel => 'interrupted';

  @override
  String get taskFlowCardCancelFlow => 'Cancel flow';

  @override
  String get taskFlowCardRetry => 'Retry';

  @override
  String get taskFlowCardCancelBatch => 'Cancel entire batch';

  @override
  String get taskFlowCardDelete => 'Delete';

  @override
  String get taskFlowCardRetryFlow => 'Retry task flow';

  @override
  String get taskFlowCardNoSnapshot =>
      'This run has no snapshot. It will start over using the current flow configuration.';

  @override
  String get taskFlowCardRetryInfo =>
      'Starting over downloads files and calls models again. Retry with the configuration used at launch, or explicitly choose the latest configuration. To reuse completed steps, choose “Resume from interrupted step.”';

  @override
  String get taskFlowCardRunLatest => 'Run with latest configuration';

  @override
  String get taskFlowCardRetryOriginal => 'Retry with original configuration';

  @override
  String get taskFlowCardDeleteRecord => 'Delete task flow record';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      'Deleting this run will cancel unfinished tasks in the batch and clear their subtask records. Delete?';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      'This flow is running. Deleting it will cancel its active tasks. Delete?';

  @override
  String get taskFlowCardDeleteRecordConfirm =>
      'Delete this flow record and its subtask records?';

  @override
  String get taskFlowCardDeleteConfirm => 'Delete this flow record?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      'Could not save the flow cancellation state. Try deleting again.';

  @override
  String get taskFlowCardStillRunning =>
      'The flow is still running after cancellation.';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      'Could not save the flow record deletion state. Try deleting again.';

  @override
  String get taskFlowCardConfirm => 'Confirm';

  @override
  String get taskFlowCardWaiting => 'Waiting';

  @override
  String get taskFlowCardRunning => 'Running';

  @override
  String get taskFlowCardPaused => 'Paused';

  @override
  String get taskFlowCardCompleted => 'Completed';

  @override
  String get taskFlowCardFailed => 'Failed';

  @override
  String get taskFlowCardCanceled => 'Canceled';

  @override
  String get taskFlowCardInterrupted => 'Interrupted';

  @override
  String get taskFlowCardSucceeded => 'Skipped';

  @override
  String get taskFlowCardPause => 'Pause flow';

  @override
  String get taskFlowCardResume => 'Resume flow';

  @override
  String get taskFlowCardResumeInterrupted => 'Resume from interrupted step';

  @override
  String get taskFlowCardCancel => 'Cancel';

  @override
  String get unifiedTaskType => 'Task type';

  @override
  String get unifiedTaskCreatedAt => 'Created';

  @override
  String get unifiedTaskCompletedAt => 'Completed';

  @override
  String get unifiedTaskResultStatus => 'Result status';

  @override
  String get unifiedTaskPartialResult =>
      'Partial result; content may be incomplete';

  @override
  String get unifiedTaskErrorDetails => 'Error details';

  @override
  String get unifiedTaskViewErrorDetails => 'View error details';

  @override
  String get unifiedTaskOcrPerImage => 'Recognize each image';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return 'Image $index';
  }

  @override
  String get unifiedTaskOcrPending => 'Waiting to recognize';

  @override
  String get unifiedTaskOcrRunning => 'Recognizing';

  @override
  String get unifiedTaskCompleted => 'Completed';

  @override
  String get unifiedTaskIncomplete => 'Incomplete result';

  @override
  String get unifiedTaskOcrFailed => 'Recognition failed';

  @override
  String get unifiedTaskCancelled => 'Canceled';

  @override
  String get unifiedTaskWaitingStart => 'Waiting to start...';

  @override
  String get unifiedTaskSteps => 'Steps';

  @override
  String get unifiedTaskStartNow => 'Start now';

  @override
  String get unifiedTaskOpenFile => 'Open file';

  @override
  String get unifiedTaskRetrySave => 'Retry saving only';

  @override
  String get unifiedTaskRetryPartialSave => 'Retry saving partial result only';

  @override
  String get unifiedTaskSavePartialResult => 'Save partial result';

  @override
  String get unifiedTaskRetry => 'Retry';

  @override
  String get unifiedTaskCancel => 'Cancel';

  @override
  String get unifiedTaskDelete => 'Delete';

  @override
  String get unifiedTaskFormatUnsupported =>
      'Preview is not supported for this format';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String get unifiedTaskAudioFile => 'Audio file';

  @override
  String get unifiedTaskPreviewLoadFailed => 'Could not load preview';

  @override
  String get unifiedTaskUnknownSize => 'Unknown size';

  @override
  String get unifiedTaskUnnamedRecording => 'Untitled recording';

  @override
  String get unifiedTaskPause => 'Pause';

  @override
  String get unifiedTaskClearTask => 'Clear task';

  @override
  String get unifiedTaskContinue => 'Continue';

  @override
  String get unifiedTaskRemoveFromList => 'Remove from list';

  @override
  String get unifiedTaskSynthesisText => 'Synthesized text';

  @override
  String get unifiedTaskStatus => 'Status';

  @override
  String get unifiedTaskDetails => 'Details';

  @override
  String get unifiedTaskSynthesisError => 'Synthesis error details';

  @override
  String get unifiedTaskClose => 'Close';

  @override
  String get unifiedTaskRawRequestResponse => 'Raw request and response';

  @override
  String get unifiedTaskRawRequestBody => 'Raw request body:';

  @override
  String get unifiedTaskRawResponseBody => 'Raw response body:';

  @override
  String get commonJustNow => 'Just now';

  @override
  String commonMinutesAgo(Object count) {
    return '$count min ago';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count hr ago';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds sec';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds sec';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String get unifiedTaskTypeOcr => 'Image text recognition';

  @override
  String get unifiedTaskTypeAsr => 'Audio transcription';

  @override
  String get unifiedTaskTypeAudioSeparation => 'Audio separation';

  @override
  String get unifiedTaskTypeChat => 'Assistant chat';

  @override
  String get unifiedTaskPlayAudio => 'Play audio';

  @override
  String get unifiedTaskPauseAudio => 'Pause audio';

  @override
  String get catcatchFlowActionNotStarted =>
      'Flow action did not start. Check the flow status and try again.';

  @override
  String catcatchFlowActionFailed(Object error) {
    return 'Flow action failed: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      'Automatic page scanning timed out. Sign in or configure a user script on this page; after media is detected, choose Continue flow.';

  @override
  String get browserRecoveryContinue => 'Continue flow';

  @override
  String get catcatchSkipped => 'Skipped (nothing to process)';

  @override
  String get catcatchRetryStep => 'Retry this step';

  @override
  String catcatchCollapseSegments(Object count) {
    return 'Hide $count segments';
  }

  @override
  String catcatchShowSegments(Object count) {
    return 'Show $count segments';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '$selected of $total resources selected';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '$count media resources detected';
  }

  @override
  String get catcatchFlowSelectOrCombine =>
      '(select one resource or combine an audio/video pair)';

  @override
  String get catcatchSelectMultiple => '(tap to select; multiple allowed)';

  @override
  String get catcatchWaitingForResources => 'Waiting for flow resources';

  @override
  String catcatchDownloadSelected(Object count) {
    return 'Download $count selected resources';
  }

  @override
  String get catcatchSelectResources => 'Select resources to download';

  @override
  String get catcatchPossibleSplit =>
      '⚠ Possible separate audio and video streams';

  @override
  String get catcatchSplitExplanation =>
      'These resources may be separate audio and video streams for the same video. You can combine them or download only one stream.';

  @override
  String get catcatchAudioStream => '🎵 Audio stream';

  @override
  String get catcatchVideoStream => '🎬 Video stream';

  @override
  String get catcatchMergeAudioVideo => 'Combine audio and video';

  @override
  String get catcatchVideoOnly => 'Video only';

  @override
  String get catcatchAudioOnly => 'Audio only';

  @override
  String get catcatchSegmentsPlaylistPreview =>
      'Preview segments using the playlist';

  @override
  String get catcatchPreviewAudio => 'Preview audio';

  @override
  String get catcatchPreviewVideo => 'Preview video';

  @override
  String catcatchDuration(Object duration) {
    return 'Duration: $duration';
  }

  @override
  String get catcatchSegment => 'Segment';

  @override
  String get catcatchPlaylist => 'Playlist';

  @override
  String get catcatchFullVideo => 'Full video';

  @override
  String get catcatchSeparateTracks => 'Separate tracks';

  @override
  String get catcatchPreviewPlaylistOnly => 'Preview using the playlist';

  @override
  String get catcatchPreviewUnsupported => 'Preview is not supported';

  @override
  String get catcatchUnknownFormat => 'Unknown format';

  @override
  String get catcatchNeedPlaylistProcessing => 'Playlist processing required';

  @override
  String get catcatchSpecialFormatDetected => 'Special format detected';

  @override
  String catcatchPlaylistInfo(Object format) {
    return 'This resource is a playlist ($format). It must be parsed and all segments downloaded and combined into a playable video.';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return 'The downloaded file is in $format, not standard MP4. The built-in pure Dart remux engine will convert it to MP4 (TS/FLV/EV1 require no external dependencies).';
  }

  @override
  String get catcatchContinueBeforeConfirm =>
      'Resume the flow before confirming format handling';

  @override
  String get catcatchAutoProcess => 'Process automatically';

  @override
  String get catcatchKeepOriginalFormat => 'Keep original format';

  @override
  String get catcatchResumeSupported => 'Resume supported';

  @override
  String get catcatchResumeUnsupported => 'This site does not support resuming';

  @override
  String get catcatchPauseDownload => 'Pause download';

  @override
  String get catcatchResumeDownload => 'Resume download';

  @override
  String get catcatchRestartDownload => 'Download again';

  @override
  String get catcatchPendingFormatAction => 'Waiting for flow resources';

  @override
  String get quitDialogTitle => 'Quit app?';

  @override
  String quitDialogRunningTasks(Object count) {
    return '$count tasks are running. Quitting will interrupt them. Do you want to quit?';
  }

  @override
  String get quitDialogNoTasks => 'Do you want to quit Stroom?';

  @override
  String get quitDialogCancel => 'Cancel';

  @override
  String get quitDialogExit => 'Quit';

  @override
  String get searchPanelNewConversation => 'New conversation';

  @override
  String get searchPanelTitle => 'Search conversations';

  @override
  String get searchPanelHint => 'Enter a keyword...';

  @override
  String get searchPanelByTitle => 'Search titles';

  @override
  String get searchPanelByContent => 'Search content';

  @override
  String searchPanelResults(Object count) {
    return '$count results';
  }

  @override
  String get searchPanelPrompt => 'Enter a keyword to search';

  @override
  String get searchPanelNoResults => 'No matching conversations found';

  @override
  String get topicItemNew => 'New topic';

  @override
  String get topicItemUnpin => 'Unpin';

  @override
  String get topicItemPin => 'Pin';

  @override
  String get topicItemRename => 'Rename';

  @override
  String get topicItemAutoName => 'Auto name';

  @override
  String get topicItemDelete => 'Delete';

  @override
  String get galleryChoiceTitle => 'Choose an image source';

  @override
  String get galleryChoiceDevice => 'Device gallery';

  @override
  String get galleryChoiceDeviceDescription =>
      'Browse photos and videos on your device';

  @override
  String get galleryChoiceApp => 'App gallery';

  @override
  String get galleryChoiceAppDescription => 'Choose from the app gallery';

  @override
  String get appMediaUnreadable => 'Could not read file';

  @override
  String appMediaClearSelection(Object count) {
    return 'Clear ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return 'Done ($count)';
  }

  @override
  String get appMediaConfirmSelection => 'Done';

  @override
  String get appMediaEmptyFolder => 'This folder is empty';

  @override
  String get appMediaRoot => 'Go to root folder';

  @override
  String appMediaParentFolder(Object name) {
    return 'Back: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '$count files selected';
  }

  @override
  String get chatAlbumPickerTitle => 'App album';

  @override
  String get chatAlbumPickerEmpty => 'No images available';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images selected',
      one: '$count image selected',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => 'Choose files';

  @override
  String get chatFilePickerTabText => 'Text';

  @override
  String get chatFilePickerTabImages => 'Images';

  @override
  String get chatFilePickerTabVideos => 'Videos';

  @override
  String get chatFilePickerTabAudio => 'Audio';

  @override
  String get chatFilePickerEmpty => 'No files available';

  @override
  String get chatFilePickerLoadFailed => 'Could not load files';

  @override
  String get chatVideoPickerTitle => 'Choose app videos';

  @override
  String get chatVideoPickerEmpty => 'No videos available';

  @override
  String get imagePreviewCrop => 'Crop';

  @override
  String get imagePreviewEdit => 'Edit';

  @override
  String get imagePreviewLoadFailed => 'Could not load image';

  @override
  String runningElapsed(Object elapsed) {
    return 'Running for $elapsed';
  }

  @override
  String get chatAttachmentFile => 'Attach file';

  @override
  String get chatAttachmentCamera => 'Take photo';

  @override
  String get chatAttachmentDeviceGallery => 'Device gallery';

  @override
  String get chatAttachmentDeviceFiles => 'Device files';

  @override
  String get chatAttachmentAppFiles => 'App files';

  @override
  String fileManagerTodayTime(Object time) {
    return 'Today $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return 'Yesterday $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days days ago $time';
  }

  @override
  String get markdownGenerating => 'Generating...';

  @override
  String get htmlPreview => 'Preview';

  @override
  String get htmlReturnToCard => 'Return to card';

  @override
  String get htmlGenerating => 'Generating...';

  @override
  String get htmlFullscreen => 'View fullscreen';

  @override
  String get htmlViewCode => 'View code';

  @override
  String get codeScrollToBottom => 'Scroll to bottom';

  @override
  String get codeSave => 'Save';

  @override
  String get codeDisableWrap => 'Disable wrapping';

  @override
  String get codeEnableWrap => 'Wrap lines';

  @override
  String codeCopyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get codeCopied => 'Copied';

  @override
  String get codeCopy => 'Copy';

  @override
  String get codeEmptySave => 'Code is empty and cannot be saved';

  @override
  String get codeSaveTitle => 'Save code';

  @override
  String codeSavedTo(Object path) {
    return 'Saved to: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get fileManagerCopy => 'Copy';

  @override
  String get fileManagerMove => 'Move';

  @override
  String get fileManagerRename => 'Rename';

  @override
  String get fileManagerExport => 'Export';

  @override
  String get fileManagerDelete => 'Delete';

  @override
  String get fileManagerAncestorFolders => 'Ancestor folders';

  @override
  String get fileManagerRoot => 'Root';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$count selected';
  }

  @override
  String get fileManagerSelectAll => 'Select all';

  @override
  String get fileManagerRenameUndo => 'Last batch rename result and undo';

  @override
  String fileManagerSortBy(Object field) {
    return 'Sort ($field)';
  }

  @override
  String get fileManagerSortCreated => 'Sort by created date';

  @override
  String get fileManagerSortModified => 'Sort by modified date';

  @override
  String get fileManagerSortName => 'Sort by name';

  @override
  String get fileManagerSortSize => 'Sort by size';

  @override
  String get fileManagerListView => 'List view';

  @override
  String get fileManagerThumbnailView => 'Thumbnail view';

  @override
  String get fileManagerCreateFolder => 'Create folder';

  @override
  String get fileManagerRefresh => 'Refresh list';

  @override
  String get fileManagerEmptyFolder => 'This folder is empty';

  @override
  String get fileManagerNoFiles => 'No files';

  @override
  String get fileManagerBackRoot => 'Back to root';

  @override
  String fileManagerBackFolder(Object name) {
    return 'Back: $name';
  }

  @override
  String get fileManagerMultiSelect => 'Select multiple';

  @override
  String get fileManagerOpen => 'Open';

  @override
  String get fileManagerPreview => 'Preview';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '$files files, $folders subfolders';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '$count subfolders';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '$count files';
  }

  @override
  String get fileManagerEmptyFolderLabel => 'Empty folder';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return 'File “$name.$format” already exists';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return 'Rename failed: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => 'Choose a destination folder';

  @override
  String get fileManagerAlreadyAtDestination =>
      'The file is already at the destination';

  @override
  String get fileManagerMoveNameConflict =>
      'A file with the same name already exists in the destination. Move canceled.';

  @override
  String fileManagerMoveFailed(Object error) {
    return 'Move failed: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => 'Choose a folder to copy to';

  @override
  String fileManagerCopyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => 'Confirm deletion';

  @override
  String get fileManagerDeleteFileConfirm =>
      'Delete this file? This action cannot be undone.';

  @override
  String get fileManagerCancel => 'Cancel';

  @override
  String fileManagerDeleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere =>
      'The folder is already at the destination. Operation canceled.';

  @override
  String get fileManagerFolderConflict =>
      'A folder with the same name exists at the destination, or the destination is inside the selected folder. Operation canceled.';

  @override
  String get fileManagerBatchDeleteTitle => 'Confirm bulk deletion';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return 'Delete the $count selected items? This action cannot be undone.';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return 'Bulk delete failed: $error';
  }

  @override
  String get fileManagerExportConflict =>
      'Export paths for the selected files and folders conflict';

  @override
  String get fileManagerSelectedAlreadyThere =>
      'The selected file is already at the destination. Move canceled.';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return 'Bulk move failed: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      'The selection contains files with duplicate names. Copy canceled; copy them one at a time.';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return 'Bulk copy failed: $error';
  }

  @override
  String get fileManagerClosedError => 'The file page is closed';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return 'Bulk rename failed: $error';
  }

  @override
  String get fileManagerFolderNameHint => 'Enter a folder name';

  @override
  String get fileManagerCreate => 'Create';

  @override
  String get fileManagerFolderExists => 'Folder already exists';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return 'Could not create folder: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return 'Folder “$name” created';
  }

  @override
  String get fileManagerRenameFolderTitle => 'Rename folder';

  @override
  String get fileManagerNewNameHint => 'Enter a new name';

  @override
  String get fileManagerTargetFolderConflict =>
      'A folder with the same name already exists at the destination. Operation canceled.';

  @override
  String get fileManagerMoveFolderTitle => 'Move folder to…';

  @override
  String get fileManagerCopyFolderTitle => 'Copy folder to…';

  @override
  String get fileManagerFolderSelfConflict =>
      'A folder with the same name exists at the destination, or the destination is the folder itself. Operation canceled.';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return 'Delete folder “$name”? Its $count files will also be deleted.';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return 'Delete empty folder “$name”?';
  }

  @override
  String get fileManagerDeleteFolderTitle => 'Confirm folder deletion';

  @override
  String fileManagerRefreshFailed(Object error) {
    return 'Refresh failed: $error';
  }

  @override
  String get fileManagerRefreshed => 'File list refreshed';

  @override
  String get fileManagerRenameFileTitle => 'Rename file';

  @override
  String get fileManagerFormat => 'Format';

  @override
  String get fileManagerFolderAtDestination =>
      'Folder is already at the destination';

  @override
  String get folderPickerTitle => 'Choose folder';

  @override
  String get folderPickerExists => 'Folder already exists';

  @override
  String folderPickerCreateFailed(Object error) {
    return 'Could not create folder: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return 'Could not refresh folder list: $error';
  }

  @override
  String get folderPickerInstruction =>
      'Click to select; double-click to open a folder';

  @override
  String get folderPickerFileName => 'File name';

  @override
  String get folderPickerFileNameHint => 'Enter a file name';

  @override
  String get folderPickerBack => 'Go up one level';

  @override
  String folderPickerPath(Object path) {
    return 'Root > $path';
  }

  @override
  String get folderPickerRoot => 'Root';

  @override
  String get folderPickerCurrentFolder => 'Current folder';

  @override
  String get folderPickerSubfolders => 'Subfolders';

  @override
  String get folderPickerExistingFolders => 'Existing folders';

  @override
  String get folderPickerCreateNew => 'Create new folder';

  @override
  String get folderPickerFolderNameHint => 'Enter a folder name';

  @override
  String get folderPickerCancelCreate => 'Cancel creation';

  @override
  String get folderPickerCancel => 'Cancel';

  @override
  String get folderPickerConfirm => 'Done';

  @override
  String batchRunReadFailed(Object error) {
    return 'Could not read file list: $error';
  }

  @override
  String get batchRunPreparing => 'Preparing…';

  @override
  String get batchRunUndo => 'Undo';

  @override
  String get batchRunRename => 'Rename';

  @override
  String batchRunFailedAction(Object label) {
    return 'Could not $label';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label $count items';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed succeeded, $failed failed, $remaining remaining';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return 'Failed: $id → $name';
  }

  @override
  String get batchRunReportCopied => 'Execution report copied';

  @override
  String get batchRunCopyFailed => 'Copy failed. Try again.';

  @override
  String batchRunWorking(Object label) {
    return '$label…';
  }

  @override
  String get batchRunTitle => 'Batch rename results';

  @override
  String get batchRunStoppedRetain =>
      'Stopping keeps completed items. You can undo them on the results page.';

  @override
  String get batchRunFailedRemaining =>
      'Failed; remaining items were not processed';

  @override
  String get batchRunUndoInfo =>
      'Undo restores the original names for items completed in this run. Undo is refused if the file list has changed since.';

  @override
  String get batchRunUncertain =>
      'Some item states could not be confirmed. Check the file list; automatic undo is unavailable to avoid overwriting files.';

  @override
  String get batchRunUndoing => 'Restoring original names…';

  @override
  String get batchRunStopping => 'Stopping…';

  @override
  String get batchRunStopRemaining => 'Stop remaining items';

  @override
  String get batchRunCopyReport => 'Copy report';

  @override
  String batchRunUndoRemaining(Object count) {
    return 'Continue undoing the remaining $count';
  }

  @override
  String get batchRunUndoCompleted => 'Undo completed renames';

  @override
  String get batchRunDone => 'Done';

  @override
  String get codeEditorTitle => 'Edit parameter value';

  @override
  String get codeEditorFormat => 'Format';

  @override
  String get codeEditorCancel => 'Cancel';

  @override
  String get codeEditorConfirm => 'OK';

  @override
  String get codeEditorInvalidJson => 'Invalid JSON. Fix it before saving.';

  @override
  String get codeEditorParamPath =>
      'Parameter name path (expanded into nested JSON when sent)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return 'Line $line, column $column: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON format error: $message';
  }

  @override
  String get codeEditorInvalidFormat => 'Invalid JSON format';

  @override
  String get toolCallCompacted => 'Compacted';

  @override
  String get mermaidSaveEmpty => 'Mermaid code is empty. Nothing to save.';

  @override
  String mermaidFolderLoadFailed(String error) {
    return 'Could not load folders: $error';
  }

  @override
  String get mermaidSaveTitle => 'Save Mermaid diagram';

  @override
  String get mermaidSaveHint => 'Choose or create a folder for the .mmd file';

  @override
  String get mermaidSaveFilenameHint =>
      'Enter a file name (.mmd is added automatically)';

  @override
  String get mermaidFilenameEmpty => 'File name cannot be empty';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return 'Saved to text storage: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get mermaidPrepareEngine => 'Preparing rendering engine...';

  @override
  String get mermaidRetry => 'Retry';

  @override
  String get batchRuleEmpty => 'Cannot be empty';

  @override
  String get batchRuleNumber => 'Enter a number';

  @override
  String get batchRulePositive => 'Enter a number greater than 0';

  @override
  String batchRuleMin(String min) {
    return 'Must be at least $min';
  }

  @override
  String batchRuleMax(String max) {
    return 'Must be no greater than $max';
  }

  @override
  String get batchRulePrefix => 'Prefix';

  @override
  String get batchRuleSuffix => 'Suffix';

  @override
  String get batchRuleStart => 'Start';

  @override
  String get batchRuleStep => 'Step';

  @override
  String get batchRuleDigits => 'Digits';

  @override
  String get batchRuleSeparator => 'Separator';

  @override
  String get batchRuleRestartFolder => 'Restart numbering in each folder';

  @override
  String get batchRuleNumberHelp =>
      'Numbers follow preview order; excluded items do not use a number. Step can be negative or 0.';

  @override
  String get batchRuleFind => 'Find';

  @override
  String get batchRuleReplace => 'Replace with (leave empty to delete)';

  @override
  String get batchRuleCaseSensitive => 'Case sensitive';

  @override
  String get batchRuleRegex => 'Regular expression';

  @override
  String get batchRuleFirstOnly => 'Replace first match only';

  @override
  String get batchRuleRegexHelp =>
      'Capture groups: \$1, \$2; full match: \$0; literal \$: \$\$. Example: ^IMG_(\\d+)\$ → Photo_\$1';

  @override
  String get batchRuleFindRequired => 'Enter text to find to enable this rule.';

  @override
  String get batchRuleBeginning => 'Beginning';

  @override
  String get batchRuleEnd => 'End';

  @override
  String get batchRulePosition => 'Position';

  @override
  String get batchRuleInsertText => 'Text to insert';

  @override
  String get batchRuleBeforeChar => 'Before character N';

  @override
  String get batchRulePositionHelp =>
      'Positions start at 1; values beyond the end are appended. Combined emoji count as one character.';

  @override
  String get batchRuleFromBeginning => 'From beginning';

  @override
  String get batchRuleFromEnd => 'From end';

  @override
  String get batchRuleFromChar => 'Starting at character N';

  @override
  String get batchRuleCount => 'Count';

  @override
  String get batchRuleDeleteHelp =>
      'If deletion empties the name, a later insert rule must add text before execution.';

  @override
  String get batchRuleUpper => 'UPPERCASE';

  @override
  String get batchRuleLower => 'lowercase';

  @override
  String get batchRuleFirstUpper => 'Capitalize first letter';

  @override
  String get batchRuleTitleCase => 'Capitalize Each Word';

  @override
  String get batchRuleTemplate => 'New name template';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return 'Course_${n}_$name';
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
    return '$name original name · $n sequence · $folder folder name\n$created creation date · $modified modified date · $ext original extension\nDate format YYYY-MM-DD; missing dates are reported. The template replaces the whole base name; the extension is kept automatically.';
  }

  @override
  String get batchRuleTrim => 'Trim leading and trailing spaces';

  @override
  String get batchRuleCollapseSpaces =>
      'Replace consecutive spaces with one space';

  @override
  String get batchRuleActions => 'Rule actions';

  @override
  String get batchRuleDuplicate => 'Duplicate rule';

  @override
  String get batchRuleRemove => 'Delete rule';

  @override
  String get batchRuleMoveUp => 'Move rule up';

  @override
  String get batchRuleMoveDown => 'Move rule down';

  @override
  String get batchDlgSavePreset => 'Save preset';

  @override
  String get batchDlgPresetName => 'Preset name';

  @override
  String get batchDlgPresetHint =>
      'Saves rules and order, but not exclusions or manual names';

  @override
  String get batchDlgCancel => 'Cancel';

  @override
  String get batchDlgSave => 'Save';

  @override
  String get batchDlgOverwriteTitle => 'Overwrite existing preset?';

  @override
  String batchDlgOverwriteBody(String name) {
    return 'Update the rules in “$name”.';
  }

  @override
  String get batchDlgOverwrite => 'Overwrite';

  @override
  String get batchDlgManagePresets => 'Manage presets';

  @override
  String get batchDlgNoPresets => 'No saved presets';

  @override
  String get batchDlgDeletePreset => 'Delete preset';

  @override
  String get batchDlgDone => 'Done';

  @override
  String get batchDlgEditName => 'Edit name individually';

  @override
  String get batchDlgBaseName => 'Base name';

  @override
  String get batchDlgOverrideHelp => 'This name overrides the rule result';

  @override
  String batchDlgExtensionRetained(String extension) {
    return 'Extension .$extension is kept automatically';
  }

  @override
  String get batchDlgConfirm => 'Confirm';

  @override
  String get batchDlgHelp => 'Instructions';

  @override
  String get batchDlgClose => 'Close';

  @override
  String get batchDlgLoadPreset =>
      'Load preset (replaces rules and clears manual names)';

  @override
  String get batchDlgLoad => 'Load preset';

  @override
  String get batchDlgSaving => 'Saving…';

  @override
  String get batchDlgReset => 'Reset all rules and included items';

  @override
  String get batchDlgRuleInstructions =>
      'Rules run from top to bottom. Copy, move, or disable them. File extensions stay unchanged.';

  @override
  String get batchDlgSortName => 'Name';

  @override
  String get batchDlgSortCreated => 'Created';

  @override
  String get batchDlgSortModified => 'Modified';

  @override
  String get batchDlgSortSize => 'Size';

  @override
  String get batchDlgAscending => 'Ascending';

  @override
  String get batchDlgDescending => 'Descending';

  @override
  String get batchDlgFolderSort =>
      'Folders come first; same names are sorted by folder.';

  @override
  String get batchDlgAddRule => '＋ Add rule';

  @override
  String get batchDlgMaxRules => 'Maximum 50 rules';

  @override
  String get batchDlgPreviewWorking =>
      'Calculating preview… You can keep editing rules or cancel.';

  @override
  String get batchDlgSearch => 'Search original name, new name, or folder';

  @override
  String get batchDlgFilterAll => 'All';

  @override
  String get batchDlgFilterChanged => 'Changed';

  @override
  String get batchDlgFilterErrors => 'Issues';

  @override
  String get batchDlgFilterUnchanged => 'Unchanged';

  @override
  String get batchDlgFilterExcluded => 'Excluded';

  @override
  String get batchDlgParticipants => 'Choose included items';

  @override
  String get batchDlgIncludeAll => 'Include all';

  @override
  String get batchDlgOnlyFiles => 'Files only';

  @override
  String get batchDlgOnlyFolders => 'Folders only';

  @override
  String get batchDlgExcludeAll => 'Exclude all';

  @override
  String get batchDlgScope => 'Included items';

  @override
  String get batchDlgCopyList => 'Copy list';

  @override
  String get batchDlgConflictBlock => 'Name conflict: block execution';

  @override
  String get batchDlgConflictSuffix => 'Name conflict: append (2), (3)…';

  @override
  String get batchDlgNoMatches => 'No items match the filter';

  @override
  String get batchDlgRoot => 'Root';

  @override
  String get batchDlgFile => 'File';

  @override
  String get batchDlgFolder => 'Folder';

  @override
  String batchDlgTargetFolder(String folder) {
    return 'Target folder: $folder';
  }

  @override
  String get batchDlgEditNameTooltip => 'Edit name individually';

  @override
  String get batchDlgRestoreNameTooltip => 'Restore rule-generated name';

  @override
  String get batchDlgCopied => 'Full preview list copied (CSV)';

  @override
  String get batchDlgCopyFailed => 'Copy failed. Try again.';

  @override
  String get batchDlgHelpTitle => 'Batch rename instructions';

  @override
  String get batchDlgHelpDismiss => 'Got it';

  @override
  String get batchDlgRulesTab => 'Rules';

  @override
  String batchDlgPreviewTab(String count) {
    return 'Preview ($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return 'Rename $count items';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      'Could not load presets. You can still edit and run rules.';

  @override
  String get batchDlgPreviewFailed =>
      'Could not calculate preview. Adjust the rules and try again.';

  @override
  String batchDlgSavedName(String name) {
    return 'Preset saved: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String batchDlgDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get batchDlgSavePresetFallback => 'Save preset';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return 'Preview · $changes changes · $conflicts issues · $excluded excluded';
  }

  @override
  String get batchDlgInvalidInput =>
      'Fix invalid rule inputs. The preview does not include them yet.';

  @override
  String get batchDlgConflictError =>
      'Conflicts or invalid names prevent applying. Adjust the rules.';

  @override
  String get batchDlgManualNameStatus => 'Manual name';

  @override
  String get batchDlgPendingRename => 'Ready to rename';

  @override
  String get batchDlgCsvHeader =>
      'Original path,Original name,Target path,Status';

  @override
  String get batchDlgHelpBody =>
      '1. Choose a preset or enable rules, then copy rules and adjust their order as needed.\n\n2. The preview shows the names that will be used. Search and filters affect display only. Unchecking an item excludes it and recalculates numbering. Edit a name individually or restore the rule result.\n\n3. Resolve all issues before running. Automatic suffixes handle duplicate names without overwriting files. Rename folders that exchange names in separate batches.\n\n4. You can stop later items during execution; the current item finishes first. The results page shows completed changes and lets you undo them. Undo is blocked if the list has changed since execution.\n\nThis changes names and folder paths only; file contents and extensions stay unchanged. Renaming a parent folder does not prevent checked children from being renamed, and renaming a parent moves its children with it.';

  @override
  String batchDlgPreviewCount(String count) {
    return 'Preview ($count)';
  }

  @override
  String get batchBuiltinPhoto => 'Photos: date and number';

  @override
  String get batchBuiltinCourse => 'Courses: consistent name and number';

  @override
  String get batchBuiltinDownloads => 'Downloads: clean whitespace';

  @override
  String get taskListDetail => 'Details';

  @override
  String get taskListOwnershipChecking => 'Confirming task ownership';

  @override
  String get taskListOwnershipFailed =>
      'Could not read task flow record; actions are unavailable';

  @override
  String get taskListViewFlow => 'View task flow';

  @override
  String get taskListPause => 'Pause';

  @override
  String get taskListClear => 'Clear task';

  @override
  String get taskListResume => 'Resume';

  @override
  String get taskListRetry => 'Retry';

  @override
  String get taskListDismissError => 'Dismiss error';

  @override
  String get taskListRemove => 'Remove from list';

  @override
  String get taskListSynthesisErrorTitle => 'Synthesis error details';

  @override
  String get taskListClose => 'Close';

  @override
  String get taskListOriginalExchange => 'Original request and response';

  @override
  String get taskListOriginalRequest => 'Original request body:';

  @override
  String get taskListOriginalResponse => 'Original response body:';

  @override
  String get taskFlowIoTypeText => 'Text';

  @override
  String get taskFlowIoTypeAudio => 'Audio';

  @override
  String get taskFlowIoTypeVideo => 'Video';

  @override
  String get taskFlowIoTypeImage => 'Image';

  @override
  String get taskFlowIoTypeLink => 'Link';

  @override
  String get taskFlowIoTypeFile => 'File';

  @override
  String get taskFlowIoTypeAny => 'Any';

  @override
  String get mermaidZoomOut => 'Zoom out';

  @override
  String get mermaidZoomIn => 'Zoom in';

  @override
  String get mermaidFullscreen => 'Fullscreen';

  @override
  String get mermaidSaveButton => 'Save';

  @override
  String get mermaidSourceButton => 'View source';

  @override
  String get mermaidDiagramSemantic => 'View diagram';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'Could not save CatCatch child task deletion state. Try again.';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      'Could not save synthesis child task deletion state. Try again.';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      'Could not save background child task deletion state. Try again.';

  @override
  String get mathParseError => 'Math parse error';

  @override
  String get mermaidEmptyPlaceholder => 'No Mermaid code to render';

  @override
  String get mathClose => 'Close';

  @override
  String get mermaidLoadTimeout =>
      'Mermaid loading timed out. Check your network and try again.';

  @override
  String get mermaidCdnLoadFailed =>
      'Could not reach cdn.jsdelivr.net to load Mermaid.';

  @override
  String get mermaidLoadingDiagram => 'Loading diagram…';

  @override
  String get mermaidEngineInitFailed =>
      'Could not initialize the diagram renderer. Try again.';

  @override
  String get mermaidPageTimeout => 'Page load timed out. Try again.';

  @override
  String get mermaidCodeLoadFailed => 'Could not load diagram code. Try again.';

  @override
  String mermaidPageLoadFailed(String description) {
    return 'Page load failed: $description';
  }

  @override
  String get mermaidLoadingEngine => 'Loading rendering engine…';

  @override
  String get mermaidRenderErrorTitle => 'Diagram rendering error';

  @override
  String get taskFlowOutputVideoAudioDownstream =>
      'Video or audio (filtered by downstream)';

  @override
  String get taskFlowOutputUnknown => 'Unknown';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label stopped: $completed succeeded, $failed failed, $remaining remaining';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Mermaid render error: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Mermaid initialization error: $message';
  }

  @override
  String get mermaidResourceError =>
      'A resource in the Mermaid diagram failed to load.';

  @override
  String get taskFlowParamRecognitionModel => 'Recognition model';

  @override
  String get taskFlowParamSynthesisModel => 'Synthesis model';

  @override
  String get taskFlowParamSaveFolder => 'Save folder';

  @override
  String get taskFlowParamResourceSelection => 'Resource selection';

  @override
  String get taskFlowParamOutputType => 'Output type';

  @override
  String get taskFlowParamVideoFolder => 'Video save folder';

  @override
  String get taskFlowParamAudioFolder => 'Audio save folder';

  @override
  String get taskFlowParamExpectedDuration => 'Expected duration';

  @override
  String get taskFlowParamVoice => 'Voice';

  @override
  String get taskFlowParamSpeechRate => 'Speech rate';

  @override
  String get taskFlowParamAssistant => 'Assistant';

  @override
  String get taskFlowHintResourceSelection =>
      'Manual mode lets you choose. Automatic mode follows the existing rules. Ask when ambiguous selects automatically only when there is one safe choice; otherwise it opens the resource list for confirmation.';

  @override
  String get taskFlowHintOutputType =>
      'Choose video or audio explicitly. Follow downstream filters resources by the next block’s input type. If the next block accepts both types or there is no next block, both types are kept.';

  @override
  String get taskFlowHintExpectedDuration =>
      'Filter resources by video duration. Leave blank to skip filtering.';

  @override
  String get taskFlowHintVoice =>
      'Choose a voice. The matching synthesis model is selected automatically.';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      'This block type is no longer supported. Replace it or remove this step.';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return 'The next block requires $requiredType. The downloader can output video or audio. Change the next step or output policy.';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source has any type, but “$block” needs an explicit text, link, image, audio, video, or file type. Change the input type, move or replace the block, or undo the change.';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source has $actualType, but “$block” requires $requiredType. Change the input type, move or replace the block, or undo the change.';
  }

  @override
  String get fileManagerSortFieldCreated => 'Created date';

  @override
  String get fileManagerSortFieldModified => 'Modified date';

  @override
  String get fileManagerSortFieldName => 'Name';

  @override
  String get fileManagerSortFieldSize => 'Size';

  @override
  String get fileManagerSortDateNewest => 'newest first';

  @override
  String get fileManagerSortDateOldest => 'oldest first';

  @override
  String get fileManagerSortSizeLargest => 'largest first';

  @override
  String get fileManagerSortSizeSmallest => 'smallest first';

  @override
  String get catcatchStatusRunning => 'Running';

  @override
  String get catcatchStatusCompleted => 'Completed';

  @override
  String get catcatchStatusFailed => 'Failed';

  @override
  String get catcatchStatusPaused => 'Paused';

  @override
  String get catcatchStatusWaiting => 'Waiting';

  @override
  String get catcatchStepFetching => 'Fetching webpage';

  @override
  String get catcatchStepAnalyzing => 'Analyzing media';

  @override
  String get catcatchStepParsingPlaylist => 'Parsing playlist';

  @override
  String get catcatchStepFiltering => 'Filtering by duration';

  @override
  String get catcatchStepUserSelecting => 'Waiting for selection';

  @override
  String get catcatchStepDownloading => 'Downloading';

  @override
  String get catcatchStepConverting => 'Converting/merging';

  @override
  String get catcatchStepSaving => 'Saving locally';

  @override
  String get bgStepConnectServer => 'Connecting to server';

  @override
  String get bgStepUploadImage => 'Uploading images';

  @override
  String get bgStepWaitRecognition => 'Waiting for recognition';

  @override
  String get bgStepParseResult => 'Parsing result';

  @override
  String get bgStepSaveFile => 'Saving file';

  @override
  String get bgStepUploadAudio => 'Uploading audio';

  @override
  String get bgStepTranscribing => 'Transcribing';

  @override
  String get bgStepReceiveResult => 'Receiving result';

  @override
  String get bgStepSeparateAudio => 'Separating audio';

  @override
  String get bgStepSaveToFile => 'Saving to file';

  @override
  String get bgStepSendRequest => 'Sending request';

  @override
  String get bgStepWaitReply => 'Waiting for reply';

  @override
  String get fileManagerSortNameAscending => 'A to Z';

  @override
  String get fileManagerSortNameDescending => 'Z to A';

  @override
  String get taskFlowValidationNoSteps =>
      'This task flow has no steps. Add a block first.';

  @override
  String get taskFlowValidationInputRequired =>
      'Add at least one input to run this task flow.';

  @override
  String get taskFlowValidationFlowRemoved =>
      'This task flow was deleted. Select it again.';

  @override
  String get taskFlowValidationInputTypeChanged =>
      'The initial input type changed. Choose the run input again.';

  @override
  String get taskFlowValidationSnapshotMissing =>
      'This older record has no run snapshot. Retry using the latest configuration.';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      'The assistant model is missing or unavailable. Select a model on the chat page or set a default model for the assistant.';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      'A saved step file is missing, empty, or unreadable. Run the task flow again.';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      'This block type is no longer supported. Replace or remove this step.';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return 'The next block requires $requiredType. The downloader can output audio or video. Change the next step or output policy.';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '“$parameter” is required for “$block”. Configure it in the block settings.';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return 'The legacy model selection needs confirmation. Choose the model again in “$block” settings.';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return 'The model is missing or unavailable from its provider. Choose it again in “$block” settings and check the provider URL and key.';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return 'The assistant is missing or was deleted. Choose it again in “$block” settings.';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      'The assistant model was deleted or its provider configuration is unavailable. Choose a model again in assistant settings.';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return 'The resource selection policy or output type is invalid. Choose it again in “$block” settings.';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return 'The output type is invalid. Choose it again in “$block” settings.';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return 'The resource selection policy is invalid. Choose it again in “$block” settings.';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return 'Input $index: The file is missing, empty, or unreadable. Choose it again.';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return 'Input $index: Enter a valid HTTP or HTTPS link.';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return 'Input $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules => 'At most 50 rules are allowed.';

  @override
  String get batchRuleValidationDigits =>
      'The number of digits must be from 1 to 12.';

  @override
  String get batchRuleValidationNumberRange =>
      'The starting number and step must be within ±999,999,999.';

  @override
  String get batchRuleValidationReplacementLength =>
      'The replacement rule is too long.';

  @override
  String get batchRuleValidationRegex => 'The regular expression is invalid.';

  @override
  String get batchRuleValidationDeleteIndex =>
      'The deletion position must start at 1.';

  @override
  String get batchRuleValidationInsertLength =>
      'The inserted text is too long.';

  @override
  String get batchRuleValidationTemplateNumber =>
      'Invalid template number settings: digits must be 1 to 12 and start/step within ±999,999,999.';

  @override
  String get batchRuleValidationTemplateLength => 'The template is too long.';

  @override
  String get batchRuleValidationTemplateVariable =>
      'Unknown template variable or an unclosed brace.';

  @override
  String get batchRuleTypeNumber => 'Add numbering';

  @override
  String get batchRuleTypeReplace => 'Find and replace';

  @override
  String get batchRuleTypeInsert => 'Insert text';

  @override
  String get batchRuleTypeDelete => 'Delete characters';

  @override
  String get batchRuleTypeCase => 'Change case';

  @override
  String get batchRuleTypeTemplate => 'Name template';

  @override
  String get batchRuleTypeCleanup => 'Clean whitespace';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return 'Input $index: Enter text or choose a file.';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return 'Input $index: The image is over 20 MB. Choose a smaller image.';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return 'Input $index: The attachment is over 10 MB. Choose a smaller file.';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return 'Input $index: The file is $actualType, but $requiredType is required. Choose another file.';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return 'Input $index: Assistant chat does not support SVG image attachments. Convert it to PNG or JPEG.';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return 'Input $index: Assistant chat does not support $mime image attachments. Convert it to PNG, JPEG, GIF, or WebP.';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return 'Input $index: Assistant chat does not support $mime audio attachments. Convert it to MP3, WAV, or M4A.';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return 'Input $index: This Anthropic chat format does not support $type attachments. Choose an assistant that supports this media.';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return 'Input $index: This Anthropic chat format supports only image and PDF attachments. Choose a supported file.';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return 'Input $index: Assistant chat could not compress the image below 10 MB. Choose a smaller image.';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return 'Input $index: The text attachment is not valid UTF-8. Convert it and try again.';
  }

  @override
  String get assistantParamValueTypeString => 'String';

  @override
  String get assistantParamValueTypeNumber => 'Number';

  @override
  String get assistantParamValueTypeBoolean => 'Boolean';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields =>
      'Provider name, API URL, and key are required.';

  @override
  String get providerJsonSizePositive =>
      'Request JSON size must be a positive MiB value.';

  @override
  String get providerCustomParamRequired =>
      'Custom parameter name and value are required.';

  @override
  String providerParamNameInvalid(String name) {
    return 'Parameter name is invalid (dot-separated segments cannot be empty): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return 'Parameter already exists: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return 'Default value for parameter \"$name\" is not valid JSON: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return 'Numeric options for parameter \"$name\" cannot be empty.';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return 'Value for parameter \"$name\" is not a valid number: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      'Complete the reasoning toggle before enabling other reasoning parameters.';

  @override
  String providerReasoningError(String error) {
    return 'Reasoning parameter error: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return 'Reasoning and custom parameters have the same name: $name';
  }

  @override
  String get providerMaxTokensMissing =>
      'Maximum output tokens is enabled, but no value was entered.';

  @override
  String get providerMaxTokensPositive =>
      'Maximum output tokens must be a positive integer.';

  @override
  String get providerSeedInteger => 'Random seed must be an integer.';

  @override
  String get providerNotConfigured => 'Not set';

  @override
  String get providerAudioChunkingTitle => 'Audio chunking';

  @override
  String get providerAudioChunkingHint =>
      'Smart chunking analyzes the audio and candidate cuts, preferring sentence endings. Chunks do not overlap.';

  @override
  String get providerChunkingMode => 'Chunking method';

  @override
  String get providerChunkNone => 'No chunking';

  @override
  String get providerChunkSmart => 'Smart chunking (recommended)';

  @override
  String get providerChunkFixedDuration => 'Fixed-duration chunks';

  @override
  String get providerChunkFixedSize => 'Fixed-size chunks';

  @override
  String get providerCompressionTitle => 'Compression encoding';

  @override
  String get providerCompressionHint =>
      'When enabled, the general fallback first compresses the full WAV. If the encoded file or request body still exceeds the limit, the source PCM is chunked and encoded.';

  @override
  String get providerCompressionMode => 'Compression method';

  @override
  String get providerCompressionNone => 'None (send as is)';

  @override
  String get providerCompressionAdpcm => 'ADPCM (~4x compression)';

  @override
  String get providerCompressionFlac => 'FLAC (lossless, ~2x)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM, lossy 4:1 compression. Pure Dart implementation; audio quality suits transcription.';

  @override
  String get providerCompressionFlacDescription =>
      'Lossless FLAC compression, implemented in pure Dart. Reduces size by about half.';

  @override
  String get providerCompressionWavDescription =>
      'No compression; send as a WAV file.';

  @override
  String get providerLlmParams => 'LLM parameters';

  @override
  String get providerEnabledParamsHelp =>
      'Enabled parameters are sent as defaults in API requests.';

  @override
  String get providerTemperatureLabel => 'Temperature';

  @override
  String get providerTemperatureHelp =>
      'Controls output randomness; higher values are more creative.';

  @override
  String get providerTopPHelp =>
      'Nucleus sampling parameter that controls cumulative probability for word selection.';

  @override
  String get providerFrequencyPenaltyLabel => 'Frequency penalty';

  @override
  String get providerFrequencyPenaltyHelp =>
      'Reduces repeated words; negative values increase repetition.';

  @override
  String get providerPresencePenaltyLabel => 'Presence penalty';

  @override
  String get providerPresencePenaltyHelp =>
      'Encourages new topics; negative values encourage returning to previous topics.';

  @override
  String get providerMaxOutputTokensLabel => 'Maximum output tokens';

  @override
  String providerOptionalExample(String example) {
    return 'Optional, e.g. $example';
  }

  @override
  String get providerResponseTokensHelp =>
      'Maximum number of tokens generated per response.';

  @override
  String get providerSeedLabel => 'Random seed';

  @override
  String get providerSeedHelp => 'Set this to make output reproducible.';

  @override
  String get providerChunkSmartDescription =>
      'Analyzes audio and candidate cuts, preferring sentence endings or long silences without overlap. Defaults: 20s minimum / 45s target / 60s maximum. Used only by the general fallback; compression chunking supports PCM WAV only.';

  @override
  String get providerChunkDurationDescription =>
      'Splits every N seconds (60 by default). Simple, but may cut off speech. Used only by the general fallback; compression chunking supports PCM WAV only.';

  @override
  String get providerChunkSizeDescription =>
      'Initially splits by audio data size, then refines by encoded file and request body size. Used only by the general fallback; compression chunking supports PCM WAV only.';

  @override
  String get providerChunkNoneDescription =>
      'No chunking. The file is rejected if it exceeds the limit after full compression.';

  @override
  String get providerNameLabel => 'Provider name';

  @override
  String get providerNameHint => 'Enter provider name';

  @override
  String get providerApiUrlLabel => 'API URL';

  @override
  String get providerApiUrlHint => 'Enter the full API endpoint URL';

  @override
  String providerApiKeyHint(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get providerEndpointTypeLabel => 'Endpoint type';

  @override
  String get providerEndpointOpenAi => 'OpenAI compatible (Chat Completions)';

  @override
  String get providerEndpointAnthropic => 'Anthropic format (Messages API)';

  @override
  String get providerAnthropicEndpointHelp =>
      'Uses the official Anthropic Messages API format (x-api-key header). API URL example: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      'Uses the official OpenAI Chat Completions compatible format (Bearer header). API URL example: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => 'Default request JSON size';

  @override
  String get providerUseAppDefault => 'Leave empty to use the app default';

  @override
  String get providerModelJsonBudgetHelp =>
      'Models can override this value. If neither the provider nor model sets it, the default is 20 MiB.';

  @override
  String get providerRequestParamsHelp =>
      'Requests use all enabled provider and model parameters. When names overlap, the model value takes precedence.';

  @override
  String get providerUploadSettings => 'Upload settings';

  @override
  String get providerUploadMethodHelp =>
      'Audio upload methods and size limits vary by provider.';

  @override
  String get providerUploadMethod => 'Upload method';

  @override
  String get providerMultipart => 'Multipart (general)';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => 'Maximum upload size';

  @override
  String get providerFallbackStrategy => 'Fallback strategy';

  @override
  String get providerFallbackMethod => 'Fallback method';

  @override
  String get providerPreprocessing => 'Audio preprocessing';

  @override
  String get providerPreprocessingHelp =>
      'Reduces audio file size without affecting transcription accuracy.';

  @override
  String get providerPreprocessingMethod => 'Preprocessing method';

  @override
  String get providerUploadMultipartHelp =>
      'Direct multipart/form-data upload. The request body includes audio, form fields, and multipart boundaries.';

  @override
  String get providerUploadBase64Help =>
      'Sends Base64 in JSON, which can bypass some providers’ multipart-specific limits. Base64 expansion and JSON fields count toward the upload limit.';

  @override
  String get providerUploadUrlHelp =>
      'Provide a public URL for the provider to download. Supports very large files (e.g. Together AI 1 GB).';

  @override
  String get providerUploadBudgetHelp =>
      'This value triggers raw-audio fallback and limits the final request body. The app checks raw audio, encoded files, and upload size. Multipart includes form fields and boundaries; Base64 JSON includes encoding expansion and fields. The 25 MB default matches the OpenAI audio API limit.';

  @override
  String get providerFallbackTriggerHelp =>
      'Triggered when raw audio or the complete request body exceeds its limit. Specific fallback (Base64) takes priority over general fallback (compression/chunking).';

  @override
  String get providerFallbackNone => 'None (reject immediately)';

  @override
  String get providerFallbackSpecific => 'Specific fallback (Base64)';

  @override
  String get providerFallbackGeneric =>
      'General fallback (compression/chunking)';

  @override
  String get providerFallbackAll => 'Try all (recommended)';

  @override
  String get providerFallbackSpecificHelp =>
      'Try Base64 JSON. Send only if the request body, including Base64 expansion and JSON fields, fits the limit.';

  @override
  String get providerFallbackGenericHelp =>
      'If enabled, compress the full WAV first. If it still exceeds the limit and chunking is enabled, split the source PCM and encode each chunk. PCM WAV only.';

  @override
  String get providerFallbackAllHelp =>
      'Try Base64 within the request-body limit first. Then, if enabled, compress the full WAV; if it still exceeds the limit and chunking is enabled, split the source PCM and encode each chunk. PCM WAV only.';

  @override
  String get providerFallbackRejectHelp =>
      'Reject the file if it exceeds the limit; do not try a fallback.';

  @override
  String get providerPreprocessNone => 'None';

  @override
  String get providerPreprocessResample => 'WAV optimization (16 kHz mono)';

  @override
  String get providerPreprocessResampleHelp =>
      'Resamples to 16 kHz and mixes to mono. Reduces size by about 4–6x with little effect on transcription accuracy.';

  @override
  String get providerPreprocessNoneHelp => 'No preprocessing; send as is.';

  @override
  String get assistantDefaultsScopeHelp =>
      'Default model and tools apply only to new conversations created under this assistant. Existing conversations keep their own settings. Tool output truncation applies to all conversations.';

  @override
  String get assistantDefaultModelTitle => 'Default model';

  @override
  String get assistantDefaultModelHelp =>
      'Model used for new conversations; leave unset to let the conversation choose.';

  @override
  String get assistantNoDefault => 'Not set';

  @override
  String get assistantNoModelsAvailable =>
      'No models available. Configure an LLM provider in Settings.';

  @override
  String get assistantDefaultToolsTitle => 'Default enabled tools';

  @override
  String get assistantDisabledToolsHelp =>
      'Disabled tools will not be enabled automatically in new conversations.';

  @override
  String get assistantUnconfiguredToolsHelp =>
      'Default tools are not configured. New conversations will enable all tools automatically.';

  @override
  String get assistantEnableAll => 'Enable all';

  @override
  String get assistantDisableAll => 'Disable all';

  @override
  String get assistantNoToolsAvailable => 'No tools available';

  @override
  String get assistantTruncateToolOutput => 'Tool output truncation';

  @override
  String get assistantTruncateToolOutputHelp =>
      'Maximum characters in each tool result before it is sent to the model. Applies to all conversations under this assistant.';

  @override
  String get assistantEnableTruncation => 'Enable truncation';

  @override
  String assistantTruncatedTo(String count) {
    return 'Long results are truncated to $count characters';
  }

  @override
  String get assistantSendFullResult =>
      'Send full result (subject to the 50 KB storage limit)';

  @override
  String get assistantMaxCharacters => 'Maximum characters';

  @override
  String get assistantCharactersNotTokens => 'Unit: characters (not tokens)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return 'Default: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return 'Valid range: $minimum–$maximum characters';
  }

  @override
  String get assistantNewConversationPreview => 'New conversation preview';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled / $total enabled';
  }

  @override
  String get assistantAllToolsAutoEnabled =>
      'All tools are enabled automatically (not configured)';

  @override
  String get assistantMoreActions => 'More actions';

  @override
  String get assistantChooseEmoji => 'Choose emoji';

  @override
  String get assistantNameLabel => 'Assistant name';

  @override
  String get assistantDescriptionOptional => 'Description (optional)';

  @override
  String get assistantSelectionTitle => 'Choose an assistant';

  @override
  String get assistantMarketTooltip => 'Assistant marketplace';

  @override
  String get assistantDefaultPrompt =>
      'You are a helpful AI assistant. Answer the user\'s questions clearly and helpfully.';

  @override
  String get assistantCreateNew => 'Create assistant';

  @override
  String get assistantEmptyState =>
      'No assistants yet. Create one to get started.';

  @override
  String get assistantCreate => 'Create';

  @override
  String get assistantReorderHint =>
      'Long-press and drag to reorder assistants';

  @override
  String get assistantNewNameHint => 'Enter assistant name';

  @override
  String get assistantNewDescriptionHint =>
      'Briefly describe what this assistant does';

  @override
  String get assistantDeleteTitle => 'Delete assistant';

  @override
  String assistantDeleteConfirmation(String name) {
    return 'Delete assistant “$name”? This action cannot be undone.';
  }

  @override
  String get assistantEditTitle => 'Edit assistant';

  @override
  String get assistantBasicTab => 'Basic settings';

  @override
  String get assistantParametersTab => 'Parameters';

  @override
  String get assistantDefaultsTab => 'Defaults';

  @override
  String get assistantAddCustomParameter => 'Add custom parameter';

  @override
  String get assistantEditCustomParameter => 'Edit custom parameter';

  @override
  String get assistantParameterName => 'Parameter name';

  @override
  String get assistantParameterNameHint => 'e.g. top_k or provider.only';

  @override
  String get assistantParameterNameInvalid =>
      'Invalid parameter name (dot-separated segments cannot be empty)';

  @override
  String get assistantParameterType => 'Type';

  @override
  String get assistantValue => 'Value';

  @override
  String get assistantTrueFalseHint => 'true or false';

  @override
  String get assistantNumberHint => 'Enter a number';

  @override
  String assistantJsonHint(String example) {
    return 'e.g. $example';
  }

  @override
  String get assistantValueHint => 'Enter a value';

  @override
  String get assistantCancel => 'Cancel';

  @override
  String get assistantSave => 'Save';

  @override
  String get assistantParamOverrideHelp =>
      'When enabled, assistant parameters override model parameters; when disabled, model parameters are used.';

  @override
  String get assistantTemperature => 'Temperature';

  @override
  String get assistantMaxTokens => 'Maximum tokens';

  @override
  String get assistantMaxToolCalls => 'Maximum tool calls';

  @override
  String assistantRounds(String count) {
    return '$count rounds';
  }

  @override
  String get assistantUnlimited => 'Unlimited';

  @override
  String get assistantStreamOutput => 'Stream output';

  @override
  String get assistantFrequencyPenalty => 'Frequency penalty';

  @override
  String get assistantPresencePenalty => 'Presence penalty';

  @override
  String get assistantRandomSeed => 'Random seed';

  @override
  String get assistantNotSet => 'Not set';

  @override
  String get assistantSeedValue => 'Seed value';

  @override
  String get assistantIntegerSeedHint => 'Enter an integer seed';

  @override
  String get assistantWebSearch => 'Web search';

  @override
  String get assistantAddParameter => 'Add parameter';

  @override
  String get assistantNoCustomParameters => 'No custom parameters';

  @override
  String get assistantRoundsLabel => 'Rounds';

  @override
  String get modelCreateTitle => 'Add model';

  @override
  String get modelEditTitle => 'Edit model';

  @override
  String get modelDiscardTitle => 'Discard changes?';

  @override
  String get modelDiscardBody => 'You have unsaved changes. Discard them?';

  @override
  String get modelNameLabel => 'Model name';

  @override
  String get modelNameHint => 'Enter a display name (optional)';

  @override
  String get modelIdLabel => 'Model ID';

  @override
  String modelIdExample(String id) {
    return 'e.g. $id';
  }

  @override
  String get modelIdRequired => 'Model ID is required.';

  @override
  String get modelCustomParamRequired =>
      'Custom parameter name and default value are required.';

  @override
  String modelParamDuplicate(String name) {
    return 'Parameter already exists: $name';
  }

  @override
  String get modelParamName => 'Parameter name';

  @override
  String get modelParamDefaultValue => 'Default parameter value';

  @override
  String get modelParamDelete => 'Delete parameter';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return 'Default value for parameter \"$name\" is not valid JSON: $value';
  }

  @override
  String get modelAddParameter => 'Add parameter';

  @override
  String get modelNoCustomParams => 'No custom parameters';

  @override
  String get modelBasicSettings => 'Basic settings';

  @override
  String get modelDiscardCancel => 'Cancel';

  @override
  String get modelSave => 'Save';

  @override
  String get modelUnsavedMaxTokens =>
      'Maximum output tokens is enabled but has no value.';

  @override
  String get modelMaxTokensPositive =>
      'Maximum output tokens must be a positive integer.';

  @override
  String get modelSeedInteger => 'Random seed must be an integer.';

  @override
  String get modelContextLengthRequired => 'Context length is required.';

  @override
  String get modelContextLengthPositive =>
      'Context length must be a positive integer.';

  @override
  String get modelAsrLanguageCode => 'Language code (Language)';

  @override
  String get modelAsrLanguageHint => 'e.g. zh, en, ja';

  @override
  String get modelAsrLanguageHelp =>
      'ISO-639-1 language code; leave empty for automatic detection.';

  @override
  String get modelTemperature => 'Temperature';

  @override
  String get modelTemperatureHelp =>
      'Controls output randomness; a lower value is recommended.';

  @override
  String get modelAsrPrompt => 'Prompt';

  @override
  String get modelAsrPromptHint => 'Enter a context prompt (optional)';

  @override
  String get modelAsrPromptHelp =>
      'Provide context to improve transcription accuracy, such as a list of specialist terms.';

  @override
  String get modelAsrParams => 'ASR parameters';

  @override
  String get modelEnabledParamsHelp =>
      'Enabled parameters are sent as defaults in API requests.';

  @override
  String get modelAsrResponseFormat => 'Response format';

  @override
  String get modelAsrResponseHelp => 'Format of the returned transcription.';

  @override
  String get modelAsrTimestampGranularity => 'Timestamp granularity';

  @override
  String get modelAsrVerboseHelp =>
      'Available only when response_format is verbose_json.';

  @override
  String get modelNoTrim => 'No trimming';

  @override
  String get modelAudioTrimTitle => 'Audio trimming';

  @override
  String get modelAudioTrimHelp => 'Choose how to trim the audio.';

  @override
  String get modelDeleteTrimPreset => 'Delete trim preset';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return 'Delete trim preset \"$name\"?';
  }

  @override
  String get modelAddTrimPreset => 'Add custom trim';

  @override
  String get modelPlayTestAudio => 'Play test audio';

  @override
  String get modelPlayingTestAudio => 'Playing...';

  @override
  String get modelParamExists => 'Parameter already exists';

  @override
  String get asrModelIdExample => 'e.g. whisper-1';

  @override
  String get asrPromptLabel => 'Prompt';

  @override
  String get asrResponseFormatJson => 'json – JSON';

  @override
  String get asrResponseFormatText => 'text – Plain text';

  @override
  String get asrResponseFormatSrt => 'srt – Subtitles';

  @override
  String get asrResponseFormatVtt => 'vtt – Subtitles';

  @override
  String get asrResponseFormatVerbose =>
      'verbose_json – Detailed JSON (includes timestamps)';

  @override
  String get asrVerboseTimestampHelp =>
      'Selecting verbose_json enables the timestamp granularity option below.';

  @override
  String get asrTimestampSegment => 'segment – Segment level';

  @override
  String get asrTimestampWord => 'word – Word level';

  @override
  String get asrWordTimestampHelp =>
      'Word-level timestamps may be less accurate than segment-level timestamps.';

  @override
  String get reasoningAddOptionValue => 'Add option value';

  @override
  String get reasoningEditOptionValue => 'Edit option value';

  @override
  String get reasoningOptionExample => 'e.g. low, medium, high';

  @override
  String get reasoningOptionSelectionHelp =>
      'Tap a chip to select or clear it. Selected values are sent; drag to reorder. Provider values cannot be deleted, but can be hidden by clearing them.';

  @override
  String get reasoningAddOption => 'Add option';

  @override
  String get reasoningCurrentProvider => 'Current: provider';

  @override
  String get reasoningCurrentModel => 'Current: model custom';

  @override
  String get reasoningAddEffortValue => 'Add reasoning effort value';

  @override
  String get reasoningEffortExample => 'e.g. max, ultra, deep';

  @override
  String get reasoningAddToggle => 'Add reasoning toggle';

  @override
  String get reasoningToggle => 'Reasoning toggle';

  @override
  String get reasoningResetParameter => 'Reset this parameter';

  @override
  String get reasoningDisableToggle => 'Disable reasoning toggle';

  @override
  String get reasoningEnableToggle => 'Enable reasoning toggle';

  @override
  String reasoningParameterNameSource(String source) {
    return 'Parameter name ($source)';
  }

  @override
  String get reasoningNameExample => 'e.g. thinking.type, reasoning';

  @override
  String get reasoningBooleanHelp =>
      'Boolean parameters need no value; the chat panel provides an on/off switch.';

  @override
  String get reasoningOnValue => 'Value when enabled';

  @override
  String get reasoningOnExample => 'e.g. enabled, true';

  @override
  String get reasoningOffValue => 'Value when disabled';

  @override
  String get reasoningOffExample => 'e.g. disabled, false';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return 'When enabled, sends “$onValue”; when disabled, sends “$offValue”.';
  }

  @override
  String get reasoningAddEffort => 'Add reasoning effort';

  @override
  String get reasoningFillToggleFirst => 'Complete the reasoning toggle first';

  @override
  String get reasoningFillToggleBeforeEffort =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get reasoningAddValue => 'Add value';

  @override
  String get reasoningJsonValue => 'JSON value';

  @override
  String reasoningJsonExample(String example) {
    return 'e.g. $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      'Tap a chip to select or clear it. Selected values appear in the chat reasoning panel; drag to reorder. Provider values cannot be deleted, but can be hidden.';

  @override
  String get reasoningAddParameter => 'Add reasoning parameter';

  @override
  String get reasoningToggleIncomplete =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get llmContextLength => 'Context length';

  @override
  String get llmContextHint => 'Enter context length';

  @override
  String get llmContextHelp =>
      'Maximum context window size for the model (tokens).';

  @override
  String get llmReasoningParams => 'Reasoning parameters';

  @override
  String get llmReasoningHelp =>
      'Configure reasoning parameters for chat. The reasoning toggle controls its parameter name and on/off values. Add reasoning effort values, reorder them, and select which values appear in the chat panel. Provider values are synchronized when this page opens. These settings control model parameter availability; the chat panel toggle is managed separately.';

  @override
  String get llmAddReasoningParam => 'Add reasoning parameter';

  @override
  String get llmCustomEndpointType => 'Custom endpoint type';

  @override
  String get llmInheritEndpointType =>
      'When disabled, use the endpoint type from provider settings.';

  @override
  String get llmEndpointType => 'Endpoint type';

  @override
  String get llmEndpointOpenAi => 'OpenAI compatible (Chat Completions)';

  @override
  String get llmEndpointAnthropic => 'Anthropic format (Messages API)';

  @override
  String get llmEndpointHelp =>
      'The endpoint type must match the provider API URL. Changing it affects the format used for new conversations with this model.';

  @override
  String get llmTopPHelp =>
      'Nucleus sampling parameter; controls cumulative probability for word selection.';

  @override
  String get llmFrequencyPenaltyLabel => 'Frequency penalty';

  @override
  String get llmFrequencyPenaltyHelp =>
      'Reduces repetition; negative values increase it.';

  @override
  String get llmPresencePenaltyLabel => 'Presence penalty';

  @override
  String get llmPresencePenaltyHelp =>
      'Encourages new topics; negative values encourage repetition.';

  @override
  String get llmMaxTokensHint => 'Optional, e.g. 4096';

  @override
  String get llmTokensPerResponse => 'Maximum tokens generated per response.';

  @override
  String get llmSeedLabel => 'Random seed (Seed)';

  @override
  String get llmSeedHint => 'Optional, e.g. 42';

  @override
  String get llmSeedHelp => 'Setting this makes output reproducible.';

  @override
  String get llmInheritedCustomHelp =>
      'Provider custom parameters are shown here and synchronized whenever this page opens.';

  @override
  String get llmBooleanParamHelp => 'Boolean parameters do not need a value.';

  @override
  String get modelContextReq => 'Context length is required.';

  @override
  String get modelContextPositive =>
      'Context length must be a positive integer.';

  @override
  String modelParamNameInvalid(String name) {
    return 'Invalid parameter name (dot-separated segments cannot be empty): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return 'Parameter \"$name\" $valueLabel must be a finite number: $value';
  }

  @override
  String get modelReasoningIncomplete =>
      'Complete the reasoning toggle before enabling other reasoning parameters.';

  @override
  String get modelReasoningOptionsRequired =>
      'Add at least one option value to the reasoning parameter.';

  @override
  String modelReasoningError(String error) {
    return 'Reasoning parameter error: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return 'Duplicate reasoning parameter: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return 'Reasoning and custom parameters share the name: $name';
  }

  @override
  String get modelSeedRequired => 'Random seed is enabled but empty.';

  @override
  String get ocrParamsTitle => 'OCR parameters';

  @override
  String get ocrParamsHelp =>
      'Uses the OpenAI-compatible vision Chat Completions format. Parameters below are optional; unset or disabled parameters are not sent. Add provider-specific parameters below if supported by its API.';

  @override
  String get ocrRequestSizeOverride => 'Request JSON size override';

  @override
  String get ocrInheritProvider => 'Leave empty to inherit provider settings';

  @override
  String get ocrBudgetDefault =>
      'When empty, inherits provider settings; if the provider has no value, the default is 20 MiB.';

  @override
  String ocrBudgetValue(String size) {
    return 'When empty, inherits provider settings ($size MiB); if the provider has no value, the default is 20 MiB.';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return 'Trim $direction ${seconds}s';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return 'Trim the first ${seconds}s';
  }

  @override
  String get audioTrimNone => 'Do not trim audio';

  @override
  String get trimNameLabel => 'Trim method name *';

  @override
  String get trimNameHint => 'e.g. silence trimming';

  @override
  String get trimDurationLabel => 'Trim duration (seconds) *';

  @override
  String get trimDurationHint => 'e.g. 0.123';

  @override
  String get trimNameAndDurationRequired => 'Name and duration are required.';

  @override
  String get trimDurationInvalid => 'Enter a valid positive duration.';

  @override
  String get testAudioHostMissing => 'Host is not configured.';

  @override
  String get testAudioKeyMissing => 'Key is not configured.';

  @override
  String testAudioContentTypeError(String contentType) {
    return 'Response Content-Type is $contentType, not audio.';
  }

  @override
  String get testAudioEmpty => 'The server returned empty audio data.';

  @override
  String testAudioTimeoutConnection(String details) {
    return 'Connection timed out. Check your network. $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return 'Receive timed out; the server responded too slowly. $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return 'Request cancelled. $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return 'Network error: $message';
  }

  @override
  String get testAudioNoBody => 'No response body';

  @override
  String testAudioCorsHelp(String details) {
    return 'Unable to connect to server. On web, this may be caused by CORS or an incorrect API URL. Check the provider API URL and whether the server allows cross-origin requests. $details';
  }

  @override
  String get trimModelNameHint =>
      'A friendly name for display and identification, e.g. \"GPT-4o Mini TTS\". Use different names to distinguish models from the same provider.';

  @override
  String get trimModelIdHelp =>
      'Unique identifier used in API calls, e.g. \"gpt-4o-mini-tts\". It must match the model ID provided by the vendor.';

  @override
  String get ttsVoiceRangeTitle => 'Volume range';

  @override
  String get ttsMinVolume => 'Minimum volume';

  @override
  String get ttsMaxVolume => 'Maximum volume';

  @override
  String get ttsSpeedRangeTitle => 'Speed range';

  @override
  String get ttsMinSpeed => 'Minimum speed';

  @override
  String get ttsMaxSpeed => 'Maximum speed';

  @override
  String get ttsMaxAudioLength => 'Maximum audio length per request *';

  @override
  String get ttsAudioLengthHint => 'e.g. 1000';

  @override
  String get ttsNoVoices => 'No voices. Tap to edit.';

  @override
  String get ttsInstructionSupported =>
      'Model supports the instruction parameter';

  @override
  String get ttsInstructionHelp =>
      'When enabled, TTS requests can include instructions for tone, emotion, speaking speed, and more.';

  @override
  String get ttsStreamSupported => 'Model supports streaming output';

  @override
  String get ttsStreamHelp =>
      'Enables this model for streaming scenarios. Confirm the model supports streaming before enabling.';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return 'Parameter “$name” must be true or false: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired =>
      'Maximum audio length per request is required; enter a positive integer.';

  @override
  String get asrLanguageExample => 'e.g. zh, en, ja';

  @override
  String get llmReasoningFullHelp =>
      'The reasoning toggle controls whether reasoning is sent and lets you define the parameter name and on/off values. There is one reasoning-effort parameter. Select values and drag to reorder them; selected values appear in the chat reasoning panel. Add other reasoning parameters below. Parameter names support dot notation such as thinking.type, which becomes a nested JSON object. Provider reasoning parameters synchronize when this page opens. The switches here control model parameters; the chat reasoning toggle is separate.';

  @override
  String get llmTemperatureHelp =>
      'Controls output randomness; higher values are more creative.';

  @override
  String get llmBooleanValueHelp => 'Boolean parameters do not need a value.';

  @override
  String get reasoningDisableEffort => 'Disable reasoning effort';

  @override
  String get reasoningEnableEffort => 'Enable reasoning effort';

  @override
  String get ocrJsonSizePositive =>
      'Request JSON size must be a positive MiB value.';

  @override
  String ttsRangePair(String kind) {
    return 'Enter both the minimum and maximum $kind, or leave both empty.';
  }

  @override
  String get ttsEditTrimTitle => 'Edit custom trim';

  @override
  String ttsVoicesCount(String count) {
    return 'Voices ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return 'Generated in the request format: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'Please enter an MCP server name.';

  @override
  String get mcpStdioCommandRequired => 'stdio mode requires a command.';

  @override
  String get mcpSseUrlRequired => 'SSE mode requires a URL.';

  @override
  String get mcpEditServerTitle => 'Edit MCP server';

  @override
  String get mcpCreateServerTitle => 'New MCP server';

  @override
  String get mcpUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get mcpUnsavedChangesConfirm =>
      'You have unsaved changes. Discard them?';

  @override
  String get mcpTransportType => 'Transport type';

  @override
  String get mcpServerName => 'Server name';

  @override
  String get mcpServerNameHint => 'Enter an MCP server name';

  @override
  String get mcpCommand => 'Command';

  @override
  String get mcpCommandExample => 'Example: npx';

  @override
  String get mcpArguments => 'Arguments';

  @override
  String get mcpArgumentsHint =>
      'Separate arguments with commas, for example: -y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => 'Example: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'API key';

  @override
  String get mcpApiKeyHint => 'Enter an API key (optional)';

  @override
  String get mcpShowKey => 'Show key';

  @override
  String get mcpHideKey => 'Hide key';

  @override
  String get mcpDescriptionHint =>
      'Enter a description for this MCP server (optional)';

  @override
  String get mcpStdioDescription =>
      'stdio starts a local child process as an MCP server and communicates through standard input/output. Recommended for local tools.';

  @override
  String get mcpSseDescription =>
      'SSE connects to a remote MCP server over HTTP SSE. Recommended for remote services.';

  @override
  String get mcpLocalStdio => 'Local (stdio)';

  @override
  String get mcpRemoteSse => 'Remote (SSE)';

  @override
  String get mcpSaving => 'Saving…';

  @override
  String get providerTestSafetyNote =>
      'This test sends a real request to the selected service. MCP only calls the read-only tools/list method; HTTP and web search run one query. Todo reads the list by default; to protect current data, omit the todos parameter or set it to null.';

  @override
  String get providerDeleteConfigTitle => 'Delete configuration';

  @override
  String get providerDeleteConfigConfirm =>
      'Delete this provider configuration and all of its models?';

  @override
  String get providerCreateGroup => 'New group';

  @override
  String get providerEditGroup => 'Edit group';

  @override
  String get providerGroupName => 'Group name';

  @override
  String get providerGroupNameExists =>
      'A group with this name already exists.';

  @override
  String get providerDeleteGroup => 'Delete group';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return 'Deleting “$groupName” will move its configurations to “Other MCP services”.';
  }

  @override
  String get providerMoveToGroup => 'Move to group';

  @override
  String get providerUnnamed => '(Unnamed)';

  @override
  String get providerHttpSearch => 'HTTP search';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP tool: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return 'Local (stdio): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return 'Remote (SSE): $url';
  }

  @override
  String get providerServices => 'Service configurations';

  @override
  String get providerServicesDescription =>
      'Manage remote connections, local stdio, and HTTP search by group';

  @override
  String get providerCreateGroupAction => 'New group';

  @override
  String get providerGroupEmpty =>
      'This group has no configurations. Select “Add” to add an item.';

  @override
  String get providerBuiltinTools => 'Built-in tools';

  @override
  String get providerBuiltinToolsDescription =>
      'Stroom-provided local tool interfaces. Web search is listed in its service group.';

  @override
  String get providerBuiltinToolInterface => 'Built-in tool interface';

  @override
  String get providerViewInterface => 'View interface';

  @override
  String get providerConfigTitle => 'Configuration';

  @override
  String get providerNotFound => 'Provider not found';

  @override
  String get providerConfigurationHeading => 'Provider configuration';

  @override
  String get providerBuiltinWebSearchEmpty =>
      'Built-in web search supports Google, Bing, and Baidu. Its model tool name is web_search.';

  @override
  String get providerNoConfigsAdd =>
      'No provider configurations yet. Select “Add” to create one.';

  @override
  String get providerNoHost => '(Host not set)';

  @override
  String get providerServicesAndTools => 'Services and tools';

  @override
  String get providerManageServicesDescription =>
      'Manage MCP servers, HTTP search, and Stroom built-in tools.';

  @override
  String get providerNoServices => 'No service configurations yet';

  @override
  String get providerAddServiceDescription =>
      'Add an MCP service or HTTP search interface to use it in assistants.';

  @override
  String get providerAddService => 'Add service';

  @override
  String get providerBuiltinBadge => 'Built-in';

  @override
  String get providerConnectivityTest => 'Connectivity test';

  @override
  String get providerMoveGroupTooltip => 'Move to group';

  @override
  String get providerDeleteTooltip => 'Delete configuration';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# items',
      one: '# item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => 'Group actions';

  @override
  String get providerEditGroupAction => 'Edit group';

  @override
  String get providerDeleteGroupAction => 'Delete group';

  @override
  String get providerAddItem => 'Add item';

  @override
  String get providerMcpMasterLabel => 'MCP servers';

  @override
  String get providerMcpMasterDescription =>
      'Controls whether MCP servers and built-in search tools are available in assistants and chats.';

  @override
  String get providerEnabled => 'Enabled';

  @override
  String get providerDisabled => 'Disabled';

  @override
  String get providerEditSettings => 'Edit provider settings';

  @override
  String get providerModelList => 'Models';

  @override
  String get providerNoModels => 'No models yet';

  @override
  String get providerDeleteModel => 'Delete model';

  @override
  String get providerDeleteModelConfirm =>
      'Are you sure you want to delete this model?';

  @override
  String get providerEditConfig => 'Edit configuration';

  @override
  String providerCreateNamedConfig(String entryName) {
    return 'New $entryName configuration';
  }

  @override
  String get toolHttpSearchType => 'Connection type: HTTP search';

  @override
  String toolInterface(String name) {
    return 'Tool interface: $name';
  }

  @override
  String get toolParameterDefinitions => 'Parameter definitions';

  @override
  String get toolHttpAddress => 'HTTP endpoint URL';

  @override
  String get toolInvalidHttpUrl => 'Enter a valid HTTP or HTTPS URL.';

  @override
  String get toolBuiltinType => 'Connection type: Stroom built-in tool';

  @override
  String get toolBuiltinEnableHelp =>
      'Enable this tool for an assistant in that assistant’s default tool settings.';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return 'Model ID: $modelId';
  }

  @override
  String get providerValueNotSet => '(Not set)';

  @override
  String get providerApiKeyInputHint => 'Enter an API key';

  @override
  String get providerSettingsTitle => 'Provider configuration';

  @override
  String get providerBasicInfoTab => 'Basic information';

  @override
  String get providerParameterSettingsTab => 'Parameter settings';

  @override
  String get providerOptionValuesReorderHelp =>
      'Option values (hold the handle to drag and reorder)';

  @override
  String providerOptionIndexLabel(String index) {
    return 'Option $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return 'e.g. $example';
  }

  @override
  String get providerDeleteOptionTooltip => 'Delete option';

  @override
  String get providerAddOption => 'Add option';

  @override
  String get providerAddCustomParam => 'Add parameter';

  @override
  String get providerNoCustomParams => 'No custom parameters yet';

  @override
  String get providerParamNameLabel => 'Parameter name';

  @override
  String get providerParamDefaultValueLabel => 'Default parameter value';

  @override
  String get providerBooleanParamNoValue =>
      'Boolean parameters do not need a value. The chat panel provides an on/off toggle.';

  @override
  String get providerReasoningParamsHeading => 'Reasoning parameters';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return 'The reasoning toggle turns reasoning on or off in chat; you choose its parameter name and on/off values. You can configure one reasoning effort parameter with a required name and optional choices. If you enter only a name, the model configuration can provide the values. Use the buttons below to add other reasoning parameters. Parameter names support dot nesting, for example $parameterName expands to $jsonExample.';
  }

  @override
  String get providerAddReasoningParam => 'Add reasoning parameter';

  @override
  String get providerAddReasoningToggle => 'Add reasoning toggle';

  @override
  String get providerReasoningToggle => 'Reasoning toggle';

  @override
  String get providerDeleteReasoningToggle => 'Delete reasoning toggle';

  @override
  String providerParamNameHint(String examples) {
    return 'e.g. $examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      'Boolean parameters do not need a value. The chat panel provides an on/off toggle.';

  @override
  String get providerToggleOnValueLabel => 'On value';

  @override
  String get providerToggleOffValueLabel => 'Off value';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return 'When reasoning is on, send “$onValue”; when it is off, send “$offValue”.';
  }

  @override
  String get providerAddReasoningEffort => 'Add reasoning effort';

  @override
  String get providerDeleteReasoningEffort =>
      'Delete reasoning effort parameter';

  @override
  String get providerReasoningEffortLockedHint =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get providerJsonValueLabel => 'JSON value';

  @override
  String get providerReasoningOptionsHelp =>
      'Option values (optional; if only the parameter name is entered, the model configuration supplies the value). Hold the handle to drag and reorder.';

  @override
  String get providerParamNameNestedLabel =>
      'Parameter name (supports dot nesting)';

  @override
  String get providerToggleEffortPrerequisite =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get providerToggleRequiredHint =>
      'Complete the reasoning toggle first.';

  @override
  String get providerDeleteCustomParam => 'Delete parameter';

  @override
  String get modelSaveSuccess => 'Model saved';

  @override
  String get modelSaving => 'Saving…';

  @override
  String modelOriginalError(String error) {
    return 'Original error: $error';
  }

  @override
  String get paramTypeStringLabel => 'String';

  @override
  String get paramTypeNumberLabel => 'Number';

  @override
  String get paramTypeBooleanLabel => 'Boolean';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String get paramTypeStringHint => 'e.g. cheerful';

  @override
  String get paramTypeNumberHint => 'e.g. 0.8';

  @override
  String get paramTypeBooleanHint => 'e.g. true';

  @override
  String get paramTypeJsonHint => 'e.g. ';

  @override
  String get ankiPageTitle => 'Anki flashcards';

  @override
  String get ankiStatsTooltip => 'Study statistics';

  @override
  String get ankiBrowseCardsTooltip => 'Browse cards';

  @override
  String get ankiSyncTooltip => 'AnkiWeb sync';

  @override
  String get ankiNewDeckTooltip => 'New deck';

  @override
  String ankiDeckLoadError(String error) {
    return 'Failed to load decks: $error';
  }

  @override
  String get ankiEmptyDecksTitle => 'No decks yet';

  @override
  String get ankiEmptyDecksDescription => 'Create a deck to start studying';

  @override
  String get ankiNewDeckTitle => 'New deck';

  @override
  String get ankiDeckNameHint => 'Deck name';

  @override
  String get ankiCreateDeck => 'Create';

  @override
  String get ankiRenameDeck => 'Rename deck';

  @override
  String get ankiConfirm => 'OK';

  @override
  String get ankiDeleteDeckTitle => 'Delete deck';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return 'Delete “$deckName” and all its cards?';
  }

  @override
  String get ankiAddCardTitle => 'Add card';

  @override
  String get ankiNoteTypeLabel => 'Note type';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return 'Text (mark deletions with $clozeSyntax)';
  }

  @override
  String get ankiFrontQuestionHint => 'Front (question)';

  @override
  String get ankiBackExtraLabel => 'Back / extra';

  @override
  String get ankiTagsLabel => 'Tags (separated by spaces)';

  @override
  String get ankiTagsHint => 'Example: math physics';

  @override
  String get ankiAdd => 'Add';

  @override
  String get ankiStatNew => 'New';

  @override
  String get ankiStatLearning => 'Learning';

  @override
  String get ankiStatReview => 'Review';

  @override
  String get ankiAddCardAction => 'Add card';

  @override
  String get ankiRenameAction => 'Rename';

  @override
  String get ankiDeleteAction => 'Delete';

  @override
  String get ankiNoCardContent => 'No card content';

  @override
  String get ankiStudy => 'Study';

  @override
  String get ankiWhiteboardTooltip => 'Whiteboard';

  @override
  String get ankiFrontLabel => 'Front';

  @override
  String get ankiBackLabel => 'Back';

  @override
  String get ankiShowAnswer => 'Show answer';

  @override
  String get ankiRatingAgain => 'Again';

  @override
  String get ankiRatingHard => 'Hard';

  @override
  String get ankiRatingGood => 'Good';

  @override
  String get ankiRatingEasy => 'Easy';

  @override
  String get ankiNoCardsToStudy => 'No cards to study right now';

  @override
  String get ankiNoCardsHint => 'Add new cards or come back later';

  @override
  String get ankiBack => 'Back';

  @override
  String get ankiSyncPageTitle => 'Anki sync';

  @override
  String get ankiSyncChooseMode => 'Choose a sync mode';

  @override
  String get ankiSyncModeHelp =>
      'Login status is stored separately for each service. Switching modes does not merge or overwrite data.';

  @override
  String get ankiSyncSelfHostedMode => 'Self-hosted server';

  @override
  String get ankiSyncServerAddress => 'Server address';

  @override
  String get ankiSyncServerHelp =>
      'Remote self-hosted servers must use HTTPS; HTTP is allowed for local addresses. The server must support Anki sync v10, and certificate verification is enabled by default.';

  @override
  String get ankiSyncCustomCaTitle => 'Custom CA certificate (optional)';

  @override
  String get ankiSyncCustomCaHelp =>
      'Only enter this when the server uses a self-signed certificate';

  @override
  String get ankiSyncOfficialHelp =>
      'Use the official AnkiWeb sync service. Your password is sent only when logging in and is not stored in Stroom.';

  @override
  String ankiSyncConnected(String service) {
    return 'Connected to $service';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return 'Not connected to $service';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return 'Log in to $service';
  }

  @override
  String get ankiSyncCheckServerStatus => 'Check server status';

  @override
  String get ankiSyncLogout => 'Log out';

  @override
  String get ankiSyncBothWays => 'Two-way sync';

  @override
  String get ankiSyncOverwriteServer => 'Replace server data with local data';

  @override
  String get ankiSyncReplaceLocal => 'Replace local data with server data';

  @override
  String get ankiSyncHelp =>
      'Two-way sync merges incremental collection changes and transfers media files. If the schema version differs, choose a full upload or download. A failed full download will try to restore the original collection and media directory.';

  @override
  String get ankiSyncStatusRestored =>
      'Restored the securely saved login session';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      'Could not read the saved login session. Please log in again.';

  @override
  String get ankiSyncInvalidServerUrl =>
      'Server address must be an HTTPS URL. HTTP is allowed only for a local loopback address. User information and query parameters are not allowed.';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return 'Settings not saved: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      'Server address changed. Please log in again to continue.';

  @override
  String get ankiSyncStatusVerifyingLogin => 'Verifying login…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      'Login successful. Your password was not saved; the sync key was encrypted and saved.';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      'Login successful, but the sync key could not be stored securely. You will need to log in again after closing this page.';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'Log in to AnkiWeb';

  @override
  String get ankiSyncLoginSelfHosted => 'Log in to self-hosted server';

  @override
  String get ankiSyncEmailOrUsername => 'Email / username';

  @override
  String get ankiSyncEmailOrUsernameRequired => 'Enter an email or username';

  @override
  String get ankiSyncPassword => 'Password';

  @override
  String get ankiSyncPasswordRequired => 'Enter a password';

  @override
  String get ankiSyncLogin => 'Log in';

  @override
  String get ankiSyncStatusPreparingServerSettings =>
      'Preparing server settings…';

  @override
  String get ankiSyncStatusReadingCollection =>
      'Reading server collection status…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      'Connected. The server collection is empty.';

  @override
  String get ankiSyncStatusConnectedStatusRead =>
      'Connected. Server status was read.';

  @override
  String get ankiSyncStatusUpgradeClient =>
      'This server requires a newer sync client.';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return 'Status check failed: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => 'Preparing upload settings…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle =>
      'Replace the server collection with the local one?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      'The server collection will be fully replaced with local data. Stroom will first keep a backup of the local database.\n\nMedia files will still be synchronized in both directions according to the server media list.';

  @override
  String get ankiSyncOverwriteServerAction => 'Replace server collection';

  @override
  String get ankiSyncStatusBackingUpUploading =>
      'Backing up and uploading collection…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return 'The server accepted the local collection. Media sync completed: uploaded $uploaded files, downloaded $downloaded, deleted $deleted.$backup Please check server status again.';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return '\nLocal backup: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      'The server collection was replaced, but media sync did not finish: ';

  @override
  String get ankiSyncStatusUploadFailed => 'Upload failed: ';

  @override
  String get ankiSyncStatusPreparingDownload => 'Preparing download settings…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle =>
      'Replace the local collection with the server one?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      'The local collection will be replaced with server data. Stroom will first keep a backup of the local database.\n\nServer media will replace local media and missing files will be downloaded. If any step fails or the app exits in the middle, Stroom will restore the local collection and media before opening the decks next time.';

  @override
  String get ankiSyncReplaceLocalAction => 'Replace local data';

  @override
  String get ankiSyncStatusDownloadingValidating =>
      'Downloading and validating collection…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return 'The local collection was replaced and passed the SQLite check. Media sync completed: downloaded $downloaded files, uploaded $uploaded, deleted $deleted.$backup Please check server status again.';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => 'Preparing sync…';

  @override
  String get ankiSyncStatusMergingChanges => 'Merging collection changes…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'Collection changes merged. Syncing media files…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '$notes notes, $cards cards, and $reviews review records added or updated';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges =>
      'No collection changes to merge';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return 'Two-way sync complete: $collection; media uploaded $uploaded, downloaded $downloaded, deleted $deleted.';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'Collection changes were merged, but media sync did not finish: ';

  @override
  String get ankiSyncStatusSyncIncomplete => 'Sync did not finish: ';

  @override
  String get ankiSyncStatusClearingLogin => 'Clearing login session…';

  @override
  String get ankiSyncStatusLoggedOut =>
      'Logged out. The sync key was deleted from secure storage.';

  @override
  String get ankiSyncStatusClearLoginFailed =>
      'Could not clear the saved login session';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      'Operation did not finish. Check secure storage, network, and server address.';

  @override
  String get ankiSyncUnknown => 'Unknown';

  @override
  String get ankiSyncServerCollectionEmpty => 'Server collection is empty';

  @override
  String get ankiSyncServerCollectionAvailable =>
      'Server collection is available';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return 'Schema version $schema · USN $usn · Modified $modified';
  }

  @override
  String get asrPageTitle => 'Audio Transcription';

  @override
  String get clear => 'Clear';

  @override
  String get configure => 'Configure';

  @override
  String get asrModel => 'Recognition model';

  @override
  String get reselectModel => 'Please select a model again';

  @override
  String get selectAsrModel => 'Select a recognition model';

  @override
  String get enterPublicAudioUrl => 'Enter a public audio URL';

  @override
  String get recordingSelection => 'Recordings';

  @override
  String get audioFiles => 'Audio files';

  @override
  String get noAudioSelected => 'No audio files selected';

  @override
  String get supportedAudioFormats =>
      'Supports common audio formats such as WAV, MP3, M4A, and OGG';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files selected',
      one: '$count audio file selected',
      zero: 'No audio files selected',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files selected',
      one: '$count audio file selected',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => 'Select again';

  @override
  String get asrUrlLabel => 'URL | Public link';

  @override
  String get asrErrorDetails => 'View error details';

  @override
  String get asrResultSaved => 'Transcription result saved';

  @override
  String get asrWorking => 'Transcribing…';

  @override
  String get asrStart => 'Start transcription';

  @override
  String get saveTo => 'Save to';

  @override
  String get rootFolder => 'Root folder';

  @override
  String get chooseSaveFolder => 'Choose a folder';

  @override
  String get linkAlreadyAdded => 'This link is already in the list';

  @override
  String get chooseAudioSource => 'Choose an audio source';

  @override
  String get inAppRecordings => 'In-app recordings';

  @override
  String get chooseGeneratedRecordings => 'Choose from generated recordings';

  @override
  String get systemAudioFiles => 'System audio files';

  @override
  String get chooseDeviceAudioFiles => 'Choose files from your device';

  @override
  String get cannotReadAudioFile => 'Could not read the audio file';

  @override
  String chooseAudioFileFailed(String details) {
    return 'Could not select audio file: $details';
  }

  @override
  String get chooseInAppRecording => 'Choose in-app recordings';

  @override
  String get noRecordings => 'No recordings';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secs',
      one: '$seconds sec',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider =>
      'Configure an audio transcription provider and model in Settings first';

  @override
  String get asrModelUnavailable =>
      'The original recognition model is unavailable or cannot be verified. Please select a model again.';

  @override
  String get asrUrlProviderRemoveFiles =>
      'This provider uploads audio by URL. Remove local audio files and try again.';

  @override
  String get asrFileProviderRemoveUrls =>
      'This provider uploads audio files and does not support transcription by link. Remove links and try again.';

  @override
  String asrTaskStartFailed(String details) {
    return 'Could not start the task: $details';
  }

  @override
  String get asrInvalidUrl =>
      'Invalid URL. It must start with http:// or https://';

  @override
  String get asrEnterAudioUrl => 'Enter an audio URL';

  @override
  String get asrUrlProviderHelp =>
      'This provider uploads audio by URL. Enter a public audio URL (http/https).';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get ttsPageTitle => 'Audio';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files imported',
      one: '$count audio file imported',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return 'Import failed: $details';
  }

  @override
  String get ttsFileReadFailed => 'Could not read file data';

  @override
  String get ttsExportAudioFile => 'Export audio file';

  @override
  String ttsExportedTo(String path) {
    return 'Exported to: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return 'Export failed: $details';
  }

  @override
  String get ttsConfirmRegenerate => 'Confirm regeneration';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return 'Regenerate audio “$fileName”?';
  }

  @override
  String get ttsRegenerateOverwrite =>
      'The original audio file will be replaced after regeneration.';

  @override
  String get ttsRegenerate => 'Regenerate audio';

  @override
  String ttsCopiedFailed(String details) {
    return 'Could not copy: $details';
  }

  @override
  String get ttsChooseExportFolder => 'Choose export folder';

  @override
  String get ttsExportAudio => 'Export audio';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files exported',
      one: '$count file exported',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => 'Export folder';

  @override
  String get ttsWebFolderExportHelp =>
      'Your browser cannot choose an export folder. A ZIP file will be downloaded with the folder structure preserved.';

  @override
  String get ttsDownloadZip => 'Download ZIP file';

  @override
  String get ttsExportAudioFolder => 'Export audio folder';

  @override
  String get ttsRecord => 'Record';

  @override
  String get ttsImport => 'Import';

  @override
  String get ttsPlay => 'Play';

  @override
  String get ttsExportLocal => 'Export to device';

  @override
  String get ttsRegenerateQuestion => 'Regenerate';

  @override
  String get ttsNeedsProvider =>
      'Configure a speech synthesis provider and model in Settings first';

  @override
  String get ttsAddedToTasks =>
      'Added to the task list. Generating in the background…';

  @override
  String get ttsCreateTitle => 'Speech Synthesis';

  @override
  String get ttsOriginalTitle => 'Recording title';

  @override
  String get ttsUseOriginalTitle => 'Use original title';

  @override
  String get ttsAudioFileNameHint => 'Saved audio file name (optional)';

  @override
  String get ttsTextToConvert => 'Text to convert';

  @override
  String get ttsSpeechContent => 'Speech content';

  @override
  String get ttsTextHint => 'Enter text to convert to speech…';

  @override
  String get ttsFullscreenEdit => 'Edit in full screen';

  @override
  String ttsTextLimitWarning(int limit) {
    return 'Text exceeds the limit (maximum $limit characters)';
  }

  @override
  String get ttsSynthesisConfig => 'Synthesis settings';

  @override
  String get ttsVoiceAndSoundHelp => 'Adjust the voice and sound';

  @override
  String get ttsProviderSettingsLead => 'in ';

  @override
  String get ttsProviderSettings => 'TTS provider settings';

  @override
  String get ttsProviderSettingsTail => ' to configure more parameters';

  @override
  String get ttsEditText => 'Edit text';

  @override
  String get ttsClose => 'Close';

  @override
  String get ttsVoice => 'Voice';

  @override
  String get ttsSelectVoice => 'Select a voice';

  @override
  String get ttsSpeed => 'Speed';

  @override
  String get ttsNormal => 'Normal';

  @override
  String get ttsVolume => 'Volume';

  @override
  String get ttsInstruction => 'Speaking style instruction';

  @override
  String get ttsInstructionHint =>
      'For example: Speak in a cheerful and excited tone';

  @override
  String get ttsCustomParams => 'Custom parameters';

  @override
  String ttsDefaultValue(Object value) {
    return 'Default: $value';
  }

  @override
  String get ttsGenerateRecording => 'Generate recording';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return 'Save as: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => 'Choose a folder';

  @override
  String get ttsFillTextError => 'Enter text to convert';

  @override
  String get voiceBatchTitle => 'Add voices in bulk';

  @override
  String get voiceBatchConfirm => 'Add selected voices';

  @override
  String get voiceBatchSeparator => 'Separator:';

  @override
  String get voiceBatchCustomSeparatorHint => 'Enter a custom separator';

  @override
  String get voiceBatchFieldOrder => 'Field order:';

  @override
  String get voiceBatchNameThenId => '1st = name, 2nd = ID';

  @override
  String get voiceBatchIdThenName => '1st = ID, 2nd = name';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Detected $count columns. Choose the starting column for the name/ID:',
      one:
          'Detected $count column. Choose the starting column for the name/ID:',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return 'Column $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn =>
      'One column detected. All values will be used as IDs (name = ID).';

  @override
  String get voiceBatchInputHint =>
      'Separate name and ID with Tab, commas, semicolons, or vertical bars (one pair per line)';

  @override
  String get voiceBatchNoPreview => 'Nothing to preview';

  @override
  String get voiceName => 'Voice name';

  @override
  String get voiceId => 'Voice ID';

  @override
  String get status => 'Status';

  @override
  String get voiceNew => '✅ New';

  @override
  String get voiceIdExists => '⚠️ ID already exists';

  @override
  String voiceFormatError(String details) {
    return '❌ Format error$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicate IDs found: $ids',
      one: '$count duplicate ID found: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData =>
      'Not enough data in the selected columns';

  @override
  String get voiceCustomSeparator => 'Custom…';

  @override
  String get voiceCommaSeparator => 'Comma (,)';

  @override
  String get voiceSemicolonSeparator => 'Semicolon (;)';

  @override
  String get voicePipeSeparator => 'Vertical bar (|)';

  @override
  String get voiceTabSeparator => 'Tab';

  @override
  String get voiceEditorTitle => 'Edit voices';

  @override
  String get save => 'Save';

  @override
  String get voiceAddRow => 'Add row';

  @override
  String get voiceBatchAdd => 'Add in bulk';

  @override
  String get voiceNoneAdd => 'No voices yet. Add one to get started.';

  @override
  String get delete => 'Delete';

  @override
  String get voiceDuplicateResolution =>
      'The following voice IDs are duplicated. Choose how to handle each one:';

  @override
  String get update => 'Update';

  @override
  String get skip => 'Skip';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates remain',
      one: '$count duplicate remains',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => 'Continue editing';

  @override
  String get asrRetryIncomplete =>
      'Retry audio is incomplete. Clear the list and select all audio again.';

  @override
  String asrRetryAudioUnreadable(String details) {
    return 'Retry audio data could not be read. Select the audio again: $details';
  }

  @override
  String get asrLegacyRetryUnavailable =>
      'Legacy retry audio is unavailable. Select the audio again.';

  @override
  String get asrRetryDataUnreadable =>
      'Retry data could not be read. Select the audio again.';

  @override
  String get ttsSynthesisModel => 'Synthesis model';

  @override
  String get asrRetryUnavailable =>
      'Retry audio is unavailable. Select the audio again.';

  @override
  String get chatRequest => 'Request';

  @override
  String get chatResponse => 'Response';

  @override
  String get chatNoErrorDetails => 'No details available';

  @override
  String get ttsInstructionDescription =>
      'Describe tone, emotion, speed, accent, and other qualities in natural language. The model adjusts the synthesized voice accordingly.';

  @override
  String get audioPlayerSourceTextSource => 'Choose source text';

  @override
  String get audioPlayerChooseInAppText => 'Choose in app text';

  @override
  String get audioPlayerChooseSavedTextSubtitle =>
      'Choose a saved text file from the app';

  @override
  String get audioPlayerChooseSystemText => 'Choose system text file';

  @override
  String get audioPlayerChooseDeviceTextSubtitle =>
      'Choose a text file from device storage';

  @override
  String get audioPlayerSelectInAppText => 'Choose in app text';

  @override
  String get audioPlayerNoTextFiles => 'No text files yet';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count characters';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return 'Failed to select text: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => 'Unable to read text file';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return 'Failed to upload source text: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => 'Text is empty';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return 'Failed to save source text: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => 'Source text uploaded';

  @override
  String get audioPlayerSourceTextUpdated => 'Source text updated';

  @override
  String get audioPlayerConfigureTtsProvider =>
      'Configure a TTS provider first';

  @override
  String get audioPlayerNoStreamingModels =>
      'No model supports streaming playback';

  @override
  String get audioPlayerSelectStreamingModel =>
      'Select a streaming playback model';

  @override
  String get audioPlayerProviderFallback => 'Provider';

  @override
  String audioPlayerStartStreaming(String model) {
    return 'Starting streaming playback: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return 'Audio file not found: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => 'Unable to load audio data';

  @override
  String get audioPlayerSourceText => 'Source text';

  @override
  String get audioPlayerNoSourceText => '(No source text)';

  @override
  String get audioPlayerUploadSourceText => 'Upload source text';

  @override
  String get audioPlayerEditSourceText => 'Edit source text';

  @override
  String get audioPlayerCompanionTextMissing => 'No companion text file found';

  @override
  String get audioPlayerPlaySelection => 'Play selection';

  @override
  String get audioPlayerGenerateSelection => 'Generate selection';

  @override
  String get audioPlayerPlaying => 'Playing...';

  @override
  String get audioPlayerPaused => 'Paused';

  @override
  String get audioPlayerPlaybackSpeed => 'Playback speed';

  @override
  String get audioPlayerFailed => 'Playback failed';

  @override
  String get audioPlayerRetry => 'Retry';

  @override
  String get audioPlayerLoading => 'Loading audio...';

  @override
  String get audioPlayerClose => 'Close';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      'Recording is not supported in the browser. Use the app version.';

  @override
  String get audioRecordingMicrophonePermissionRequired =>
      'Microphone permission is required to record';

  @override
  String audioRecordingStartFailure(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return 'Failed to pause recording: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return 'Failed to resume recording: $error';
  }

  @override
  String get audioRecordingInvalidFile =>
      'Recording file is invalid. Record again.';

  @override
  String audioRecordingStopFailure(String error) {
    return 'Failed to stop recording: $error';
  }

  @override
  String get audioRecordingFileNotFound => 'Recording file not found';

  @override
  String get audioRecordingFileEmpty => 'Recording file is empty';

  @override
  String audioRecordingSaved(String name) {
    return 'Recording saved: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return 'Failed to save recording: $error';
  }

  @override
  String get audioRecordingTitle => 'Recording';

  @override
  String get audioRecordingBrowserUnsupported =>
      'Recording is not supported in the browser';

  @override
  String get audioRecordingUseApp => 'Use the app version to record';

  @override
  String get audioRecordingDraftRecoveryHint =>
      'An unsaved recording draft was found. You can save it to the audio library.';

  @override
  String get audioRecordingRecording => 'Recording ●';

  @override
  String get audioRecordingPaused => 'Paused ||';

  @override
  String get audioRecordingPreparing => 'Preparing...';

  @override
  String get audioRecordingStart => 'Start recording';

  @override
  String get audioRecordingPause => 'Pause';

  @override
  String get audioRecordingStopping => 'Stopping...';

  @override
  String get audioRecordingStop => 'Stop';

  @override
  String get audioRecordingResume => 'Resume';

  @override
  String get audioRecordingSaving => 'Saving...';

  @override
  String get audioRecordingSave => 'Save recording';

  @override
  String get audioRecordingRecordAgain => 'Record again';

  @override
  String get audioRecordingWaveformPaused =>
      'Recording paused; waveform is frozen';

  @override
  String get audioRecordingWaveformLive => 'Live audio waveform';

  @override
  String get audioSeparationTitle => 'Video audio separation';

  @override
  String get audioSeparationChooseVideoSource => 'Choose video source';

  @override
  String get audioSeparationChooseAppAlbum => 'Choose from app library';

  @override
  String get audioSeparationChooseSavedVideoSubtitle =>
      'Choose a saved video from the app';

  @override
  String get audioSeparationChooseSystemAlbum => 'Choose from system storage';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle =>
      'Choose a video file from device storage';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return 'Failed to choose video: $error';
  }

  @override
  String get audioSeparationEngineMissing =>
      'Audio separation engine not detected';

  @override
  String get audioSeparationEngineMissingHelp =>
      'Restart the app or check that its resources are complete.';

  @override
  String get audioSeparationNoVideoSelected => 'No video selected';

  @override
  String get audioSeparationSupportedFormatsHint =>
      'Supported formats: mp4, mov, m4v, 3gp';

  @override
  String get audioSeparationSuccess =>
      'Audio extracted and saved to the audio library';

  @override
  String get audioSeparationView => 'View';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selected $count videos',
      one: 'Selected $count video',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => 'Extracting...';

  @override
  String get audioSeparationExtractAudio => 'Extract audio';

  @override
  String get audioSeparationSaveTo => 'Save to';

  @override
  String get audioSeparationChooseSaveFolder => 'Choose save folder';

  @override
  String get audioSeparationCannotReadVideoFile => 'Unable to read video file';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return 'Failed to select video file: $error';
  }

  @override
  String get audioSeparationUnknownFormat => 'Unknown';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return 'Unsupported formats: $formats. Supported formats: MP4, MOV, M4V, 3GP.';
  }

  @override
  String get audioSeparationEngineUnavailable =>
      'Audio separation engine is unavailable.';

  @override
  String get backgroundOptimizationTitle => 'Background Optimization';

  @override
  String get backgroundOptimizationEnvironment => 'System Environment';

  @override
  String get backgroundOptimizationChecks => 'Background Service Status';

  @override
  String get backgroundOptimizationKeepAliveStrategies =>
      'Keep-Alive Strategies';

  @override
  String get backgroundOptimizationDetecting => 'Checking…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      'Background services are not supported on this platform';

  @override
  String get backgroundOptimizationServiceRunning =>
      'Background service is running';

  @override
  String get backgroundOptimizationServiceStopped =>
      'Background service is not running';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      'Could not check background service status';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      'The desktop tray is unavailable. Closing the window will exit the app.';

  @override
  String get backgroundOptimizationDesktopCloseExits =>
      'The app exits when the desktop window closes';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      'The desktop tray keeps the app running';

  @override
  String get backgroundOptimizationStartFailed => 'Could not start the service';

  @override
  String get backgroundOptimizationStopFailed => 'Could not stop the service';

  @override
  String get backgroundOptimizationRestartFailed =>
      'Could not restart the service';

  @override
  String get backgroundOptimizationStopService => 'Stop Service';

  @override
  String get backgroundOptimizationRestartService => 'Restart Service';

  @override
  String get backgroundOptimizationStartService => 'Start Service';

  @override
  String get backgroundOptimizationRedetect => 'Check Again';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      'Background service controls are not supported on this platform.';

  @override
  String get backgroundOptimizationCheckingBattery =>
      'Checking battery optimization status…';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      'Battery optimization is disabled for this app';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      'Battery optimization is enabled — background activity may be stopped';

  @override
  String get backgroundOptimizationIgnoreBattery =>
      'Disable Battery Optimization';

  @override
  String get backgroundOptimizationExactAlarm =>
      'Allow Exact Alarms (more reliable background activity)';

  @override
  String get backgroundOptimizationWatchdogTitle => 'AlarmManager Watchdog';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      'When enabled, Android checks the background service every 5 minutes using a native alarm. If the system kills the process, the alarm restarts it.\n\nThe alarm still works while the device is in Doze mode and is rescheduled after a reboot.\n\nRecommended for users who rely heavily on background tasks.\nBattery impact: very low; the device wakes briefly for each check.';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      'Could not save the watchdog setting; it was not changed';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      'Could not activate the watchdog; background service status is unconfirmed';

  @override
  String get backgroundOptimizationColdStartTitle =>
      'Restore Service on App Launch';

  @override
  String get backgroundOptimizationColdStartDetail =>
      'When enabled, the app checks for and restores a previously running background service each time it opens.\n\nIf the system or user stops the app process, the background service restarts the next time you open the app.\n\nRecommended for all users.\nBattery impact: none; the app checks only once at launch.';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      'Could not save the launch recovery setting; it was not changed';

  @override
  String get backgroundOptimizationBatteryReminderTitle =>
      'Battery Optimization Reminder';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      'When enabled, this page shows the battery optimization status. If the app is not on the battery exemption list, you can open system settings to exempt it.\n\nAndroid battery optimization (Doze) limits background apps. Adding this app to the exemption list prevents the system from stopping it to save power.\n\nTurning this off only hides the reminder card; it does not change the app’s battery exemption.';

  @override
  String get backgroundOptimizationStrategyIntro =>
      'These strategies can be enabled independently. They are all on by default for the most reliable background activity. Turning one off affects only that strategy, not the background service itself.';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOS Background Tasks';

  @override
  String get backgroundOptimizationIosSupported =>
      'This version of iOS (26 or later) supports ongoing background tasks. Tasks usually continue when you switch apps or lock the screen, though the system may stop them when resources are low. You can view progress on the Lock Screen.';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'This version of iOS (earlier than 26) does not support ongoing background tasks. While a task is running, return to the app every few minutes (about every 5–10 minutes; timing depends on iOS) to refresh its background time and prevent suspension.';

  @override
  String get backgroundOptimizationIosWarning =>
      'On every iOS version, do not swipe Stroom away in the app switcher. Doing so immediately stops all running tasks.';

  @override
  String get backgroundOptimizationDesktopIntro =>
      'Desktop systems do not have the mobile platforms’ process keep-alive mechanism, but the app can continue running after its window closes.';

  @override
  String get backgroundOptimizationCloseMinimizeTitle =>
      'Minimize on Window Close';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      'When enabled, clicking the window’s close button hides the app in the system tray instead of exiting. Background tasks continue running.\n\nRestore the window from the tray icon or its “Show Main Window” menu item. To exit, use the “Quit App” button below.\n\nRecommended for all desktop users.';

  @override
  String get backgroundOptimizationQuitApp => 'Quit App';

  @override
  String get backgroundOptimizationGotIt => 'Got it';

  @override
  String get backgroundOptimizationWebNoteTitle => 'Web Background Tasks';

  @override
  String get backgroundOptimizationWebNote =>
      'Browsers cannot keep apps running in the background. Closing or refreshing this tab, or the browser freezing an inactive background tab, immediately stops running tasks. Keep the Stroom tab open and in the foreground while tasks run.';

  @override
  String get backgroundOptimizationTutorial => 'Platform Guides';

  @override
  String get backgroundOptimizationTutorialDescription =>
      'View background optimization guides for each platform';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      'Checking background service status…';

  @override
  String get backgroundOptimizationServiceUnknown =>
      'Background service status is unknown. Check again to confirm whether the service is running.';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      'The background service is running. Tasks can continue in the background.';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'Background services are not supported in web browsers. Keep this page open to continue tasks.';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      'The desktop tray is unavailable (Linux builds require libayatana-appindicator3-dev). Closing the window will exit the app.';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      'The desktop tray is unavailable. Closing the window will exit the app.';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      'The app is set to exit when the desktop window closes. It will follow the existing exit confirmation flow and will not continue running in the tray.';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      'The desktop tray is enabled. Closing the window hides the app in the system tray, where it continues running. Select “Show Main Window” in the tray menu to restore it. To exit completely, select “Quit Stroom” from the tray menu.';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      'The desktop tray is enabled. Closing the window minimizes the app to the system tray, where it continues running. Click the tray icon or select “Show Main Window” from its menu to restore the window. To exit completely, select “Quit Stroom” from the tray menu.';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      'The background service is not running. Select “Start Service” below, or view the platform guides to learn how to optimize background activity.';

  @override
  String get notificationSettingsPageTitle =>
      'Notification Permission Settings';

  @override
  String get notificationSettingsWebUnsupported =>
      'Notifications are not supported in web browsers';

  @override
  String get notificationSettingsChecking => 'Checking…';

  @override
  String get notificationSettingsPermissionGranted =>
      'Notification permission granted';

  @override
  String get notificationSettingsPermissionDenied =>
      'Notification permission not granted';

  @override
  String get notificationSettingsPermissionRestricted =>
      'Notification permission restricted';

  @override
  String get notificationSettingsPermissionBlocked =>
      'Notification permission permanently blocked';

  @override
  String get notificationSettingsPermissionProvisional =>
      'Provisional notification permission';

  @override
  String get notificationSettingsWebGuide =>
      'System notifications are not supported in web browsers.';

  @override
  String get notificationSettingsCheckingPermission =>
      'Checking notification permission…';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      'Notification permission is granted. You can enable task completion notifications to receive system alerts when a task completes or fails.';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      'Notification permission has not been granted. Select the button below to request permission, or enable notifications for Stroom in system settings.';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      'Notification permission is restricted by the system, for example by parental controls. Check Stroom’s notification settings in system settings.';

  @override
  String get notificationSettingsEnvironment => 'System Environment';

  @override
  String get notificationSettingsPermissionSection => 'Notification Permission';

  @override
  String get notificationSettingsPlatformGuides => 'Platform Guide';

  @override
  String get notificationSettingsGuideIntro =>
      'Follow these steps for your operating system to enable notifications for Stroom.';

  @override
  String get notificationSettingsTaskCompleteTitle =>
      'Task Completion Notifications';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      'Send a notification when a task completes or fails';

  @override
  String get notificationSettingsCheckAgain => 'Check Again';

  @override
  String get notificationSettingsOpenSystemSettings => 'Open System Settings';

  @override
  String get notificationSettingsRequestPermission => 'Request Permission';

  @override
  String get notificationSettingsGuideUnsupported =>
      'Notification setup guides are not available for this platform.';

  @override
  String get notificationSettingsUsageReason =>
      'To send notifications when tasks complete';

  @override
  String get notificationSettingsAndroidEnableTitle => 'Enable Notifications';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      'Go to Settings → Apps → Stroom → Notification Management and allow notifications. If you cannot find Stroom, make sure it is installed. If notifications are disabled, turn them on.';

  @override
  String get notificationSettingsAndroidDndTitle => 'Check Do Not Disturb';

  @override
  String get notificationSettingsAndroidDndDescription =>
      'Go to Settings → Sound & Vibration → Do Not Disturb. Make sure it is off or that Stroom notifications are allowed.';

  @override
  String get notificationSettingsAndroidPopupTitle =>
      'Allow Notifications to Pop Up';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'Some Android systems, such as MIUI, EMUI, and ColorOS, require “Allow notifications” and “Allow pop-ups” to be enabled in App Info. Also consider turning off “Notification filtering” or “Smart notifications” for the app.';

  @override
  String get notificationSettingsReturnTitle => 'Return to This Page';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      'After changing these settings, select “Check Again” to confirm the permission status. When permission is granted, you can enable task completion notifications.';

  @override
  String get notificationSettingsIosEnableDescription =>
      'Go to Settings → Notifications → Stroom and turn on “Allow Notifications”. Also enable Banners and Notification Center to stay up to date on task status.';

  @override
  String get notificationSettingsIosFocusTitle => 'Turn Off Focus';

  @override
  String get notificationSettingsIosFocusDescription =>
      'Go to Settings → Focus. Make sure Focus is off or add Stroom to the list of allowed apps. Focus can silence app notifications.';

  @override
  String get notificationSettingsIosReturnDescription =>
      'After changing these settings, select “Check Again” to confirm the permission status. On iOS, notification permission usually must be enabled manually in system settings.';

  @override
  String get notificationSettingsWindowsEnableTitle =>
      'Enable System Notifications';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      'Go to Settings → System → Notifications & actions and turn on “Get notifications from apps and other senders”. Find Stroom in the app list below and make sure its notifications are on.';

  @override
  String get notificationSettingsWindowsFocusTitle =>
      'Add a Focus Assist Exception';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      'Go to Settings → System → Focus Assist. Add Stroom to “Priority only” or turn Focus Assist off; Focus Assist can silence notifications.';

  @override
  String get notificationSettingsMacEnableTitle => 'Enable Notifications';

  @override
  String get notificationSettingsMacEnableDescription =>
      'Go to System Settings → Notifications → Stroom and turn on “Allow Notifications”. Also enable Banners and Notification Center.';

  @override
  String get notificationSettingsMacFocusDescription =>
      'Go to System Settings → Focus. Make sure Focus is off or add Stroom to the list of allowed apps.';

  @override
  String get notificationSettingsLinuxDesktopTitle =>
      'Check Desktop Notification Settings';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      'Depending on your desktop environment (GNOME, KDE, XFCE, etc.), go to System Settings → Notifications, find Stroom, and make sure notifications are on.';

  @override
  String get notificationSettingsLinuxDaemonTitle =>
      'Check the Notification Daemon';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux desktop environments need a notification daemon, such as notify-osd or dunst, to show system notifications. Make sure one is installed and running.';

  @override
  String get backupRestorePageTitle => 'Backup and Restore';

  @override
  String get backupRestoreSelectBackupCategory =>
      'Select at least one data category to back up';

  @override
  String get backupRestorePreparingData => 'Preparing data…';

  @override
  String get backupRestoreExportingBackup => 'Exporting backup';

  @override
  String get backupRestoreCollectingDatabase => 'Collecting database records…';

  @override
  String get backupRestoreProcessingSettings => 'Processing settings…';

  @override
  String get backupRestoreAddingTasks => 'Adding task files…';

  @override
  String get backupRestoreAddingPictures => 'Adding image files…';

  @override
  String get backupRestoreAddingAudio => 'Adding audio files…';

  @override
  String get backupRestoreAddingVideo => 'Adding video files…';

  @override
  String get backupRestoreAddingText => 'Adding text files…';

  @override
  String get backupRestoreAddingChat => 'Adding chat history and attachments…';

  @override
  String get backupRestoreCompressing => 'Compressing archive…';

  @override
  String get backupRestoreCompleted => 'Complete';

  @override
  String get backupRestoreSelectRestoreCategory =>
      'Select at least one data category to restore';

  @override
  String get backupRestoreConfirmRestore => 'Confirm Restore';

  @override
  String get backupRestoreSelectedCategories => 'Selected data categories:';

  @override
  String get backupRestoreRestoreInfo =>
      'Selected categories found in the backup will be restored to this device. All categories except built-in browser cookies replace the corresponding local data. Cookies are written by domain, name, and path; local cookies not included in the backup are preserved. Unselected categories and categories missing from the backup remain unchanged. Missing categories are skipped with a notice.';

  @override
  String get backupRestoreRestartNotice =>
      'Restart the app after restoring for the changes to take effect. Make sure your current work is saved.';

  @override
  String get backupRestoreCancel => 'Cancel';

  @override
  String get backupRestoreConfirmRestoreButton => 'Restore';

  @override
  String get backupRestoreIncompleteTitle => 'Restore Incomplete';

  @override
  String get backupRestoreIncompleteMessage =>
      'Data could not be fully restored and some data may have been cleared. Restart the app and try again.';

  @override
  String get backupRestoreSelectClearCategory =>
      'Select at least one data category to clear';

  @override
  String get backupRestoreClearingData => 'Clearing Data';

  @override
  String get backupRestoreDeletingCategories =>
      'Deleting selected data categories…';

  @override
  String get backupRestoreClearedTitle => 'Data Cleared';

  @override
  String get backupRestorePartiallyClearedTitle => 'Some Data Cleared';

  @override
  String get backupRestoreClearedMessage =>
      'Selected data was cleared. Restart the app for the changes to take effect.';

  @override
  String get backupRestorePartialClearMessage =>
      'Other selected data was cleared. This platform cannot fully clear built-in browser website storage (localStorage, IndexedDB, etc.), so browser data that could not be cleared remains. Restart the app for the cleared data to take effect.';

  @override
  String backupRestoreClearFailed(String error) {
    return 'Could not clear data: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => 'Clear Incomplete';

  @override
  String get backupRestoreClearIncompleteMessage =>
      'Some data could not be cleared. Restart the app and try clearing it again.';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki deck exported to: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get backupRestoreApkgRequired => 'Select an .apkg file';

  @override
  String backupRestoreImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get backupRestoreRestoreSuccessTitle => 'Data Restored';

  @override
  String get backupRestoreRestoredMessage =>
      'Data was restored from the backup. Restart the app to use the restored data.';

  @override
  String get backupRestoreExitApp => 'Quit App';

  @override
  String get backupRestoreRestartNow => 'Restart Now';

  @override
  String get backupRestoreSkippedTitle => 'Some Data Skipped';

  @override
  String get backupRestoreNothingRestoredTitle => 'No Data Restored';

  @override
  String get backupRestoreGotIt => 'Got it';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return 'The backup did not confirm restorable content for these selected categories, so they were skipped and existing data was kept: $categories.';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      'In older backups, an empty task file cannot distinguish an empty task list from tasks not exported by that platform. To avoid overwriting current tasks, the task category was skipped and existing data was kept.';

  @override
  String get backupRestoreSkippedCookies =>
      'The backup contains no built-in browser cookies to import, so this category was skipped and existing cookies were kept.';

  @override
  String get backupRestoreSkippedWebsiteData =>
      'The website storage directory in this older backup was skipped. Cookies can still be imported separately if the archive contains them and that category is selected.';

  @override
  String get backupRestoreApkgTitle => 'Anki Deck';

  @override
  String get backupRestoreApkgInfoTitle => 'Import or Export an Anki Deck';

  @override
  String get backupRestoreApkgInfoMessage =>
      'Includes card information only, not media';

  @override
  String get backupRestoreApkgDescription =>
      'Import or export Anki decks in .apkg format';

  @override
  String get backupRestoreExportingApkg => 'Exporting…';

  @override
  String get backupRestoreExportApkg => 'Export .apkg';

  @override
  String get backupRestoreImportingApkg => 'Importing…';

  @override
  String get backupRestoreImportApkg => 'Import .apkg';

  @override
  String get backupRestoreCategoryHeading =>
      'Choose Data Categories to Back Up or Restore';

  @override
  String get backupRestoreExporting => 'Exporting…';

  @override
  String get backupRestoreExportBackup => 'Export Backup';

  @override
  String get backupRestoreRestoring => 'Restoring…';

  @override
  String get backupRestoreChooseBackup => 'Choose Backup File and Restore';

  @override
  String get backupRestoreClearSelected => 'Clear Selected Data';

  @override
  String get backupRestoreClearDescription =>
      'Clear the selected data categories directly without a backup file. Unselected categories will remain unchanged. This action cannot be undone.';

  @override
  String get backupRestoreClearing => 'Clearing…';

  @override
  String get backupRestoreCategoryChat => 'Chat History and Attachments';

  @override
  String get backupRestoreCategoryChatDescription =>
      'Chat conversations, message content, and attachments';

  @override
  String get backupRestoreCategorySettings => 'Settings';

  @override
  String get backupRestoreCategorySettingsDescription =>
      'App configuration, provider settings, and interface preferences';

  @override
  String get backupRestoreCategoryPictures => 'Images';

  @override
  String get backupRestoreCategoryPicturesDescription =>
      'Photos and thumbnails';

  @override
  String get backupRestoreCategoryAudio => 'Audio';

  @override
  String get backupRestoreCategoryAudioDescription =>
      'Speech synthesis and recordings';

  @override
  String get backupRestoreCategoryVideos => 'Videos';

  @override
  String get backupRestoreCategoryVideosDescription => 'Video files';

  @override
  String get backupRestoreCategoryTexts => 'Text';

  @override
  String get backupRestoreCategoryTextsDescription => 'Text documents';

  @override
  String get backupRestoreCategoryTasks => 'Tasks';

  @override
  String get backupRestoreCategoryTasksDescription => 'Background task records';

  @override
  String get backupRestoreCategoryAnki => 'Anki Flashcard Data';

  @override
  String get backupRestoreCategoryAnkiDescription => 'Anki database';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki Flashcard Data';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Backing up or restoring Anki flashcard data also includes card media in the collection.media directory.';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'About Anki Flashcard Data';

  @override
  String get backupRestoreCategoryBrowser => 'Built-in Browser Data';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      'Backs up and restores cookies only; clearing also removes supported website storage';

  @override
  String get backupRestoreViewInfo => 'View information';

  @override
  String get backupRestoreApkgInfoTooltip =>
      'About Anki Deck Import and Export';

  @override
  String get backupRestoreConfirmClear => 'Confirm Clear';

  @override
  String get backupRestoreClearCategoriesIntro =>
      'The following data categories will be cleared without using a backup file:';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      'This platform cannot fully clear built-in browser website storage (localStorage, IndexedDB, etc.). Confirming clears the other selected data; browser data that cannot be cleared will remain.';

  @override
  String get backupRestoreUnselectedUnchanged =>
      'Unselected categories will remain unchanged.';

  @override
  String get backupRestoreClearWarning =>
      'This action cannot be undone. Restart the app after clearing for the changes to take effect.';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return 'Clear ($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => 'Browser environment';

  @override
  String get backupRestoreIntro =>
      'Export selected data categories manually. During import, only selected categories found in the archive are restored. A missing category or required file is skipped with a notice, and unselected categories remain unchanged. You can also clear selected categories directly.';

  @override
  String get backupRestoreOtherSelectedRestored =>
      'The other selected data was restored. Restart the app for the changes to take effect.';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      'Notifications are blocked. Open system settings and allow notifications for Stroom.';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      'Notifications are blocked. Go to System Settings → Apps → Stroom → Notification Management and allow notifications.';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      'Notifications are blocked. Go to System Settings → Stroom → Notifications and allow notifications.';

  @override
  String get textPreviewDiscardEditsTitle => 'Discard edits?';

  @override
  String get textPreviewUnsavedChangesConfirm =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get textPreviewCancel => 'Cancel';

  @override
  String get textPreviewDiscard => 'Discard';

  @override
  String get textPreviewFontSize => 'Adjust font size';

  @override
  String get textPreviewRestoreDefault => 'Restore default';

  @override
  String get textPreviewClose => 'Close';

  @override
  String textPreviewSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get textPreviewUndo => 'Undo';

  @override
  String get textPreviewRedo => 'Redo';

  @override
  String get textPreviewSave => 'Save';

  @override
  String get textPreviewEdit => 'Edit';

  @override
  String get textPreviewChartEdit => 'Edit chart';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return 'Skipped unsupported format: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# text files',
      one: '# text file',
    );
    return 'Imported $_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get textStorageSaved => 'Text saved';

  @override
  String get textStorageLoadFailed => 'Unable to load text content';

  @override
  String get textStorageReadFailed => 'Failed to read file data';

  @override
  String get textStorageExportTitle => 'Export text';

  @override
  String textStorageExportedTo(String path) {
    return 'Exported to: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get textStorageChooseExportDirectory => 'Choose export directory';

  @override
  String get textStorageFolderExportTitle => 'Export folder';

  @override
  String get textStorageWebFolderExportInfo =>
      'The browser cannot select an export directory. A ZIP file that preserves the folder structure will be downloaded.';

  @override
  String get textStorageCancel => 'Cancel';

  @override
  String get textStorageDownloadZip => 'Download ZIP file';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# files',
      one: '# file',
    );
    return 'Exported $_temp0';
  }

  @override
  String get textStorageExportFolderTitle => 'Export text folder';

  @override
  String textStorageCopyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String get textStorageCreateNew => 'New';

  @override
  String get textStorageImport => 'Import';

  @override
  String get textStorageTitle => 'Text';

  @override
  String get textStorageExportToLocal => 'Export to local';

  @override
  String get textCreateEnterTitle => 'Please enter a title';

  @override
  String textCreateSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get textCreateNewTitle => 'New';

  @override
  String get textCreateSave => 'Save';

  @override
  String get textCreateTitleLabel => 'Title';

  @override
  String get textCreateTitleHint => 'Enter text title';

  @override
  String get textCreateFormatLabel => 'Format';

  @override
  String get textCreateContentLabel => 'Text content';

  @override
  String get textCreateContentHint => 'Enter text content...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform background optimization tutorial';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform background running guide';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform background optimization guide';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return 'These steps can help optimize Stroom’s background experience on $platform devices so tasks can continue running in the background.';
  }

  @override
  String get platformTutorialStepsHeading => 'Optimization steps';

  @override
  String get platformTutorialTipsHeading => 'Tip';

  @override
  String get platformTutorialTipsDescription =>
      'After completing these settings, return to the “Background Optimization” page and check that the status has updated. If you still have problems, see another platform’s guide or report the issue on GitHub.';

  @override
  String get platformTutorialAndroidStep1Title =>
      'Turn off battery optimization';

  @override
  String get platformTutorialAndroidStep1Description =>
      'Open Settings → Apps → Stroom → Battery, then choose “Unrestricted” or “Don’t optimize.” You can also tap “Ignore battery optimization” on this app’s “Background Optimization” page to add Stroom to the system power-saving allowlist. Paths vary by device brand.';

  @override
  String get platformTutorialAndroidStep2Title => 'Allow background activity';

  @override
  String get platformTutorialAndroidStep2Description =>
      'Open Settings → Apps → Stroom and enable “Allow background activity” and “Allow auto-start.” Some phones also require allowing auto-start in Security Center or Phone Manager.';

  @override
  String get platformTutorialAndroidStep3Title => 'Lock the background process';

  @override
  String get platformTutorialAndroidStep3Description =>
      'In the recent-apps view, swipe down on the Stroom card or tap its lock icon to prevent the system from clearing the app.';

  @override
  String get platformTutorialAndroidStep4Title =>
      'Allow notifications (Android 13+)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 and later require notification permission. Without it, the foreground notification for the background service is hidden, though the service still runs. The app requests permission when you first tap “Start service,” or you can enable it in Settings → Apps → Stroom → Notifications.';

  @override
  String get platformTutorialAndroidStep5Title => 'Ignore battery optimization';

  @override
  String get platformTutorialAndroidStep5Description =>
      'When you enable “Task completion notifications” in Stroom, the app requests the related permission. You can also check that Stroom is set to “Don’t optimize” in Settings → Apps → Special app access → Battery optimization.';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Auto-start and background management on Android devices';

  @override
  String get platformTutorialAndroidStep6Description =>
      'Device manufacturers often add their own background controls:\n• Xiaomi/Redmi (MIUI/HyperOS): Settings → Apps → Permissions → Autostart; allow Stroom. Then open Battery → App battery saver → Stroom → No restrictions.\n• Huawei/Honor (EMUI/HarmonyOS): Settings → Apps → App launch → Stroom → Manage manually; allow auto-launch, secondary launch, and background activity.\n• OPPO/OnePlus/realme (ColorOS): Settings → Battery → App battery management → Stroom; allow full background activity.\n• vivo/iQOO (OriginOS): iManager → App management → Autostart; allow Stroom.';

  @override
  String get platformTutorialAndroidStep7Title =>
      'Turn off lock-screen cleanup and power-saving modes';

  @override
  String get platformTutorialAndroidStep7Description =>
      'Open Settings → Battery and turn off “Power saving” or “Ultra power saving.” Also set “Clear memory after locking” to “Don’t clear.” Power-saving modes restrict background activity and may affect task completion.';

  @override
  String get platformTutorialIosStep1Title => 'Enable Background App Refresh';

  @override
  String get platformTutorialIosStep1Description =>
      'Open Settings → General → Background App Refresh, find Stroom, and turn it on. Choose “Wi-Fi & Cellular Data” for the best experience.';

  @override
  String get platformTutorialIosStep2Title => 'Allow notifications';

  @override
  String get platformTutorialIosStep2Description =>
      'Open Settings → Notifications → Stroom and turn on “Allow Notifications.” Enable both banners and Notification Center so you can see task updates promptly.';

  @override
  String get platformTutorialIosStep3Title => 'Turn off Low Power Mode';

  @override
  String get platformTutorialIosStep3Description =>
      'Open Settings → Battery and turn off “Low Power Mode.” The system restricts background activity while this mode is on.';

  @override
  String get platformTutorialIosStep4Title =>
      'Understand iOS background limits';

  @override
  String get platformTutorialIosStep4Description =>
      'Versions before iOS 26 do not allow apps to stay in the background like Android apps. The system gives apps brief execution time only at certain times, such as Background App Refresh, location updates, or audio playback, and may suspend long-running tasks. We recommend:\n• Keep Stroom in the foreground for long-running tasks.\n• Return to the app periodically to refresh its background time.\n• Turn on “Task completion notifications” for important tasks.';

  @override
  String get platformTutorialIosStep5Title => 'Background tips while tasks run';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 and later support persistent background tasks. Tasks usually continue if you switch apps or lock the screen, though the system may stop them when resources are scarce; progress appears on the Lock Screen.\n\nEarlier iOS versions do not support persistent background tasks. Return to the app every few minutes (5–10 minutes is a guideline; the system decides) to refresh background time and prevent suspension.\n\nOn every version, do not swipe Stroom away in the app switcher; doing so immediately stops all running tasks.';

  @override
  String get platformTutorialIosStep6Title => 'Keep the app in the foreground';

  @override
  String get platformTutorialIosStep6Description =>
      'On versions earlier than iOS 26, apps have limited background time. For long-running tasks, keep Stroom in the foreground or return to it periodically to extend that time.';

  @override
  String get platformTutorialWindowsStep1Title =>
      'Minimize when closing the window';

  @override
  String get platformTutorialWindowsStep1Description =>
      'By default, clicking the window’s close button minimizes Stroom to the system tray (near the clock) so it can keep running. Restore it from the tray icon or “Show main window” menu. Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the tray menu.';

  @override
  String get platformTutorialWindowsStep2Title => 'Turn off Battery Saver';

  @override
  String get platformTutorialWindowsStep2Description =>
      'Open Settings → System → Power & sleep and turn off Battery Saver. Alternatively, configure it to turn on only when the battery falls below a chosen level.';

  @override
  String get platformTutorialWindowsStep3Title => 'Allow background apps';

  @override
  String get platformTutorialWindowsStep3Description =>
      'Open Settings → Privacy & security → Background apps, find Stroom, and make sure it is enabled. On Windows 11, go to Settings → Apps → Installed apps → Stroom → Advanced options → Background app permissions and choose “Always.”';

  @override
  String get platformTutorialWindowsStep4Title =>
      'Turn off sleep mode (optional)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'To keep Stroom running for long periods, open Settings → System → Power and set “Sleep” to “Never” (when plugged in only).';

  @override
  String get platformTutorialWindowsStep5Title => 'Add Stroom to startup';

  @override
  String get platformTutorialWindowsStep5Description =>
      'Open Task Manager (Ctrl+Shift+Esc) → Startup, find Stroom, and right-click “Enable.” Or open Settings → Apps → Startup and turn on Stroom.';

  @override
  String get platformTutorialMacosStep1Title =>
      'Minimize when closing the window';

  @override
  String get platformTutorialMacosStep1Description =>
      'By default, closing the window keeps Stroom running in the menu bar (top-right of the screen). Click its menu bar icon or choose “Show main window” to restore it. Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the menu bar menu.';

  @override
  String get platformTutorialMacosStep2Title => 'Allow notifications';

  @override
  String get platformTutorialMacosStep2Description =>
      'Open System Settings → Notifications → Stroom and turn on “Allow Notifications.” We recommend enabling both banners and Notification Center.';

  @override
  String get platformTutorialMacosStep3Title =>
      'Turn off Low Power Mode (MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      'Open System Settings → Battery → Power Adapter and turn off “Low Power Mode.” This mode restricts background activity.';

  @override
  String get platformTutorialMacosStep4Title => 'Keep the app active';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS places few restrictions on background apps. For long-running tasks, leave the Stroom window open. Avoid force-quitting the app; closing the window is enough.';

  @override
  String get platformTutorialMacosStep5Title => 'Launch at login (optional)';

  @override
  String get platformTutorialMacosStep5Description =>
      'Open System Settings → General → Login Items and add Stroom so it starts automatically when your computer starts.';

  @override
  String get platformTutorialLinuxStep1Title =>
      'Minimize when closing the window';

  @override
  String get platformTutorialLinuxStep1Description =>
      'By default, closing the window hides Stroom in the system tray (requires a desktop environment with StatusNotifierItem support and libayatana-appindicator3-dev at build time). Restore it from the tray menu using “Show main window.” Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the tray menu.';

  @override
  String get platformTutorialLinuxStep2Title => 'Desktop environment settings';

  @override
  String get platformTutorialLinuxStep2Description =>
      'Depending on your desktop environment (GNOME, KDE, XFCE, etc.), open System Settings → Apps, find Stroom, and make sure background activity is not restricted.';

  @override
  String get platformTutorialLinuxStep3Title =>
      'Use a systemd service (optional)';

  @override
  String get platformTutorialLinuxStep3Description =>
      'For long-running background work, create a systemd user service. Create a stroom.service file under ~/.config/systemd/user/ and set ExecStart to the Stroom executable.';

  @override
  String get platformTutorialLinuxStep4Title => 'Disable sleep';

  @override
  String get platformTutorialLinuxStep4Description =>
      'For a server or desktop that needs to run for a long time, set HandleLidSwitch=ignore in /etc/systemd/logind.conf to prevent sleep when the lid closes.';

  @override
  String get platformTutorialLinuxStep5Title => 'Enable autostart';

  @override
  String get platformTutorialLinuxStep5Description =>
      'In GNOME, use Tweaks → Startup Applications → Add Stroom. Or create a stroom.desktop file under ~/.config/autostart/.';

  @override
  String get platformTutorialWebStep1Title => 'Keep the tab open';

  @override
  String get platformTutorialWebStep1Description =>
      'Web browsers do not support background services. Keep the Stroom tab open while tasks run; closing the tab or refreshing the page immediately interrupts them.';

  @override
  String get platformTutorialWebStep2Title =>
      'Prevent the browser from suspending the tab';

  @override
  String get platformTutorialWebStep2Description =>
      'Browsers may freeze inactive background tabs to save resources. Keep the Stroom tab in the foreground while tasks run, or interact with the page periodically to keep it active.';

  @override
  String get browserNavigationFailed =>
      'Page navigation failed; address restored';

  @override
  String get browserAddressHint => 'Enter a web address';

  @override
  String get browserUserScripts => 'User scripts';

  @override
  String get browserSwitchToMobile => 'Switch to mobile view';

  @override
  String get browserSwitchToDesktop => 'Switch to desktop view';

  @override
  String get browserUaSwitchedDesktop => 'Switched to desktop user agent';

  @override
  String get browserUaSwitchedMobile => 'Switched to mobile user agent';

  @override
  String get browserCookieRetentionOnTooltip => 'Cookie persistence (on)';

  @override
  String get browserCookieRetentionOffTooltip => 'Cookie persistence (off)';

  @override
  String get browserCookiePersistenceEnabled => 'Cookie persistence enabled';

  @override
  String get browserCookiePersistenceDisabled => 'Cookie persistence disabled';

  @override
  String get browserSniffPanelHideTooltip => 'Hide sniff panel';

  @override
  String get browserSniffPanelShowTooltip => 'Show sniff panel';

  @override
  String get browserAdd => 'Add';

  @override
  String get browserNoScripts => 'No scripts yet. Tap “Add” to create one.';

  @override
  String get browserUnnamedScript => 'Untitled script';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matching rules',
      one: '$count matching rule',
    );
    return '$_temp0';
  }

  @override
  String get browserEditScript => 'Edit script';

  @override
  String get browserScriptName => 'Script name';

  @override
  String get browserScriptCode => 'Script code (JavaScript)';

  @override
  String get browserMatchUrls => 'URL patterns (one per line)';

  @override
  String get browserScriptMatchHint => '*://*.example.com/*';

  @override
  String get browserCancel => 'Cancel';

  @override
  String get browserSave => 'Save';

  @override
  String get browserCookiesConfirmClear => 'Confirm clearing';

  @override
  String get browserCookiesConfirmClearAll =>
      'Clear all cookies?\nThis action cannot be undone.';

  @override
  String get browserCookiesClear => 'Clear';

  @override
  String get browserCookiesCancel => 'Cancel';

  @override
  String get browserCookiesClearedAll => 'All cookies cleared';

  @override
  String get browserCookiesClearFailed => 'Could not clear. Try again.';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return 'All cookies for $domain cleared';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return 'Clear all cookies for $domain?';
  }

  @override
  String get browserCookiesPageTitle => 'Browser data management';

  @override
  String get browserCookiesRetentionTitle => 'Keep cookies when exiting';

  @override
  String get browserCookiesRetentionOn =>
      'Enabled — cookies are kept when exiting';

  @override
  String get browserCookiesRetentionOff =>
      'Disabled — cookies are cleared when exiting';

  @override
  String get browserCookiesClearAllTitle => 'Clear all cookies';

  @override
  String get browserCookiesClearAllDescription =>
      'Delete all saved website cookies';

  @override
  String get browserCookiesEmptyTitle => 'No persistent data';

  @override
  String get browserCookiesEmptyDescription =>
      'Use the built-in browser and enable cookie persistence to see saved data here.';

  @override
  String browserCookiesStoredCount(Object count) {
    return 'Stored cookies ($count)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cookies',
      one: '$count cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip =>
      'Clear all cookies for this domain';

  @override
  String get browserCookiesDeleteOneTooltip => 'Delete this cookie';

  @override
  String get browserCookiesDeletedOne => 'Cookie deleted';

  @override
  String get browserCookiesDeleteFailed => 'Could not delete. Try again.';

  @override
  String get browserCookiesEmptyValue => '(empty value)';

  @override
  String get platformTutorialPageTitle => 'Platform tutorials';

  @override
  String get browserRecoveryOpenPage => 'Open recovery page';

  @override
  String galleryUnsupportedPreview(String format) {
    return 'Preview is not supported for .$format files';
  }

  @override
  String galleryCameraFailed(String error) {
    return 'Could not take a photo: $error';
  }

  @override
  String get galleryPhotoSaved => 'Photo saved';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return 'Skipped unsupported format: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# images',
      one: '# image',
    );
    return 'Imported $_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# videos',
      one: '# video',
    );
    return 'Imported $_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get galleryFileReadFailed => 'Could not read file data';

  @override
  String get galleryExportImageTitle => 'Export image';

  @override
  String get galleryExportVideoTitle => 'Export video';

  @override
  String galleryExportedTo(String path) {
    return 'Exported to: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get galleryChooseExportDirectory => 'Choose export directory';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# files',
      one: '# file',
    );
    return 'Exported $_temp0';
  }

  @override
  String get galleryFolderExportTitle => 'Export folder';

  @override
  String get galleryWebFolderExportInfo =>
      'The browser cannot select an export directory. A ZIP file that preserves the folder structure will be downloaded.';

  @override
  String get galleryDownloadZip => 'Download ZIP file';

  @override
  String get galleryExportImageFolderTitle => 'Export image folder';

  @override
  String get galleryExportVideoFolderTitle => 'Export video folder';

  @override
  String get galleryImagePageTitle => 'Gallery';

  @override
  String get galleryVideoPageTitle => 'Videos';

  @override
  String get galleryTakePhoto => 'Take photo';

  @override
  String get galleryRecordVideo => 'Record';

  @override
  String get galleryImport => 'Import';

  @override
  String get galleryExportToLocal => 'Export to local';

  @override
  String get galleryPlayVideo => 'Play';

  @override
  String galleryCopyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String get galleryVideoSaved => 'Video saved';

  @override
  String galleryVideoRecordFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String get galleryVideoLoadFailed => 'Could not load video';

  @override
  String get imageEditorSaveImageTitle => 'Save image';

  @override
  String get imageEditorSaveImagePrompt => 'Choose how to save the image:';

  @override
  String get imageEditorOverwrite => 'Overwrite';

  @override
  String get imageEditorSaveAs => 'Save as';

  @override
  String get imageEditorSavePhotoTitle => 'Save photo';

  @override
  String get imageEditorSavePhotoPrompt => 'Save this photo?';

  @override
  String get imageEditorDiscard => 'Discard';

  @override
  String get imageEditorDoneLoading => 'Generating image. Please wait…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return 'Quick edit – $fileName';
  }

  @override
  String get imageEditorNotReady =>
      'The editor is not ready. Please try again in a moment.';

  @override
  String imageEditorProcessingFailed(String error) {
    return 'Could not process image: $error';
  }

  @override
  String get imageEditorLoadFailed => 'Could not load image';

  @override
  String get imageEditorProcessing => 'Processing image. Please wait…';

  @override
  String get imageEditorRotateLeft => 'Rotate left';

  @override
  String get imageEditorRotateRight => 'Rotate right';

  @override
  String get imageEditorFlip => 'Flip';

  @override
  String get imageEditorCrop => 'Crop';

  @override
  String get imageViewerImageSavedAsCopy => 'Image saved as a copy';

  @override
  String get imageViewerImageUpdated => 'Image updated';

  @override
  String imageViewerSaveFailed(String error) {
    return 'Could not save image: $error';
  }

  @override
  String get imageViewerInvalidIndex => 'Invalid image index';

  @override
  String get galleryExportImageArchiveFileName => 'image-export.zip';

  @override
  String get galleryExportVideoArchiveFileName => 'video-export.zip';

  @override
  String get galleryExportImageFolderArchiveFileName =>
      'image-folder-export.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName =>
      'video-folder-export.zip';

  @override
  String get catCatchPageTitle => 'Web Resource Downloader';

  @override
  String get catCatchAddTask => 'Add task';

  @override
  String get catCatchOpenBrowser => 'Built-in browser';

  @override
  String get catCatchEmptyState => 'No download tasks yet';

  @override
  String get catCatchEmptyStateHint =>
      'Tap + in the top right to add a download task';

  @override
  String get catCatchInvalidCapturedUrl => 'The captured URL is invalid';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return 'Captured from browser: $url';
  }

  @override
  String get catCatchEnterValidUrl => 'Enter at least one valid URL';

  @override
  String get catCatchTaskAdded => 'Task added';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks added',
      one: '$count task added',
    );
    return '$_temp0';
  }

  @override
  String get catCatchViewTaskList => 'View task list';

  @override
  String get catCatchUrlHint => 'Enter a video/audio webpage URL';

  @override
  String get catCatchDeleteTask => 'Delete this task';

  @override
  String get catCatchHour => 'Hours';

  @override
  String get catCatchMinute => 'Minutes';

  @override
  String get catCatchSecond => 'Seconds';

  @override
  String get catCatchDurationPreview => 'Preview: ';

  @override
  String get catCatchDurationFormat => 'hr:min:sec';

  @override
  String get catCatchDurationFilterHint =>
      'Optional: filter video resources by duration. Leave blank to show all resources for selection';

  @override
  String get catCatchVideoSaveTo => 'Save video to';

  @override
  String get catCatchAudioSaveTo => 'Save audio to';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks added',
      one: '$count task added',
    );
    return '$_temp0';
  }

  @override
  String get catCatchStartAnalysis => 'Analyze';

  @override
  String get catCatchVideoFolderTitle => 'Video save folder';

  @override
  String get catCatchAudioFolderTitle => 'Audio save folder';

  @override
  String get catCatchRootFolder => 'Root folder';

  @override
  String connectivityTestTitle(String title) {
    return '$title · Connectivity Test';
  }

  @override
  String get connectivityTestJsonLabel => 'Test content (JSON)';

  @override
  String get connectivityTestJsonHelp =>
      'You can run or save changes directly. MCP uses read-only tools/list; search tools can change query/count; Todo is read-only by default.';

  @override
  String connectivityTestSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get connectivityTestSaved => 'Test content saved';

  @override
  String get connectivityTestClose => 'Close';

  @override
  String get connectivityTestSaveContent => 'Save Content';

  @override
  String get connectivityTestTesting => 'Testing…';

  @override
  String get connectivityTestRun => 'Run Test';

  @override
  String get connectivityTestFailedSummary => 'Test could not be completed';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds sec';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get messageSearchTitle => 'Search Messages';

  @override
  String get messageSearchHint => 'Search messages across all conversations...';

  @override
  String get messageSearchInitialState =>
      'Type a keyword to search messages in all conversations';

  @override
  String get messageSearchEmptyState => 'No matching messages found';

  @override
  String get messageSearchNewConversation => 'New conversation';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '$count match',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => 'Text';

  @override
  String get filesTabAudio => 'Audio';

  @override
  String get filesTabImages => 'Images';

  @override
  String get filesTabVideos => 'Videos';

  @override
  String get filesReorderTabs => 'Reorder Tabs';

  @override
  String get filesReorderCancel => 'Cancel';

  @override
  String get filesReorderDone => 'Done';

  @override
  String get bgTaskCancelled => 'Canceled';

  @override
  String bgTaskAsrError(String details) {
    return 'Speech transcription failed: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return 'Saving speech transcription failed: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR failed: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'Saving OCR results failed: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR result is incomplete: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => 'Some OCR pages were not completed';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return ' · phase $phaseElapsedMs ms · $completedRequests requests · $completedChunks/$chunkCount chunks completed';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return 'Uploading audio$chunk $percent% · $bytes bytes$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return 'Uploading audio$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return ' (chunk $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return 'Transcribing$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return 'Transcribing (chunk $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return 'Transcribing (receiving chunk $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return 'Receiving result $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => 'Receiving result';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return 'Transcribing ($index/$count chunks completed)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return 'Transcribing (chunk $index/$count returned)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return 'Image $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return 'Uploading $details';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return 'Uploading images $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR recovery checkpoint could not be saved; the request outcome is uncertain and the task was stopped: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR recovery checkpoint could not be saved; this chunk was not sent and can be retried after fixing local storage: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'ASR chunk state could not be saved before cancellation; this chunk outcome remains uncertain: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'Could not save ASR retry audio; the task was not sent: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError =>
      'Another audio file could not be saved; sending was canceled';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR returned an incomplete result (finish_reason=$finishReason)';
  }

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return 'Some images were not fully recognized: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return 'Image $index: incomplete result';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return 'Image $index: recognition failed';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => '; ';

  @override
  String get bgTaskInterruptedOnRestart => 'Interrupted when the app restarted';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR error details were hidden';

  @override
  String get bgTaskErrorDetailsHidden => 'Error details were hidden';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return 'Task completed: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return 'Task failed: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title completed';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title failed: $error';
  }

  @override
  String get notificationUnknownError => 'Unknown error';

  @override
  String get desktopTrayTooltip => 'Stroom is running in the background';

  @override
  String get desktopTrayOpen => 'Open Stroom';

  @override
  String get desktopTrayShowMainWindow => 'Show Main Window';

  @override
  String get desktopTrayQuitStroom => 'Quit Stroom';

  @override
  String get providerPresetExaDescription =>
      'Search the web, extract page content, and support in-depth research through Exa MCP, with semantic and keyword search.';

  @override
  String get providerPresetExaApiKeyHint =>
      'Get an API key from the Exa website.';

  @override
  String get providerPresetTavilyDescription =>
      'An AI-native search engine for real-time web search optimized for large language models.';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Get an API key from Tavily. It supports ?tavilyApiKey= or an Authorization: Bearer header.';

  @override
  String get providerPresetJinaDescription =>
      'A multimodal AI service for extracting web content, generating embeddings, and retrieving search results.';

  @override
  String get providerPresetJinaApiKeyHint =>
      'Get a Jina AI API key (Bearer token) from its website.';

  @override
  String get providerPresetFirecrawlDescription =>
      'A web crawling and extraction service that turns pages into clean Markdown or structured data.';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Get a Firecrawl API key, or try it without a key with the free tier limits.';

  @override
  String get providerPresetZhipuDescription =>
      'Zhipu AI’s web reader MCP service for fetching and understanding web pages.';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Get an API key (Bearer token) from the Zhipu AI Open Platform.';

  @override
  String get providerPresetBraveSearchDescription =>
      'A privacy-focused independent search engine with high-quality web results.';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Get an API key from the Brave Search website.';

  @override
  String get providerPresetBochaDescription =>
      'Bocha AI web search provides intelligent search results for Chinese-language pages.';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Get an API key (Bearer token) from the Bocha AI Open Platform.';

  @override
  String get providerPresetQueritDescription =>
      'Querit AI search offers intelligent search and content discovery.';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Get an API key (Bearer token) from the Querit website.';

  @override
  String get providerPresetSearxngDescription =>
      'A self-hosted metasearch engine that aggregates search sources with a focus on privacy.';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'Set your SearXNG instance URL (for example, http://your-instance:8080); an API key is optional.';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS synthesis failed: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '\nOriginal error: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      'Network connection timed out. Check your network or API address.';

  @override
  String get ttsErrorServerResponseTimeout =>
      'The server response timed out. Try again later.';

  @override
  String ttsErrorConnectionFailed(String details) {
    return 'Unable to connect to the server ($details)';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return 'Unable to connect to the server. Common causes in the web app: CORS restrictions or an incorrect API address. $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API returned an error (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return 'Connection timed out. Check your network$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return 'Receive timed out; the server is responding slowly$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API key is invalid or permission denied (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return 'Too many requests; try again later (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API endpoint not found (HTTP $status): $body\nCheck that the API base URL is correct$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return 'Internal server error (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return 'Server returned an error (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return 'Request cancelled$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return 'Unable to connect to the server. Common causes in the web app: CORS restrictions or an incorrect API address. Check that the provider API address is correct and that the server allows cross-origin requests.$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return 'Network error: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => 'Unknown network error';

  @override
  String get ttsErrorNoResponseBody => 'No response body';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return 'Streaming synthesis failed: $details';
  }

  @override
  String get mermaidEditorTitle => 'Mermaid Chart Editor';

  @override
  String get mermaidEditorModeEdit => 'Edit';

  @override
  String get mermaidEditorModeSplit => 'Edit + Preview';

  @override
  String get mermaidEditorModePreview => 'Preview';

  @override
  String get mermaidEditorSwitchViewMode => 'Switch view mode';

  @override
  String get mermaidEditorSaveToTextStorage => 'Save to Text Storage';

  @override
  String get mermaidEditorEmptyChart =>
      'Chart content is empty and cannot be saved';

  @override
  String get mermaidEditorSaveChartTitle => 'Save chart';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      'Choose or create a folder to save the .mmd chart file';

  @override
  String get mermaidEditorFileNameHint =>
      'Enter a filename (.mmd added automatically)';

  @override
  String get mermaidEditorEmptyFileName => 'Filename cannot be empty';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return 'Saved to text storage: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor =>
      'Swap preview and editor panels';

  @override
  String get mermaidEditorCodeLabel => 'Mermaid code';

  @override
  String get mermaidEditorCodeHint => 'Enter Mermaid code...';

  @override
  String get mermaidEditorSplitCodeLabel => 'Code';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get languageSettingsTitle => 'Language';

  @override
  String get followSystemLanguage => 'Follow system';

  @override
  String get themeDisplaySettingsTitle => 'Theme & Display';

  @override
  String get themeDisplayThemeSection => 'Theme';

  @override
  String get themeModeLight => 'Light mode';

  @override
  String get themeModeDark => 'Dark mode';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameChinese => 'Chinese (Simplified)';

  @override
  String get builtInPromptGeneralName => 'General Assistant';

  @override
  String get builtInPromptGeneralDescription =>
      'An all-purpose AI assistant for everyday conversation and answers to a wide range of questions.';

  @override
  String get builtInPromptGeneralPrompt =>
      'You are a helpful AI assistant. Answer the user in the language they use. Be concise, clear, and logically organized. If you are unsure about something, say so honestly.';

  @override
  String get builtInPromptCodeExpertName => 'Code Expert';

  @override
  String get builtInPromptCodeExpertDescription =>
      'An experienced programmer with expertise in many programming languages and technology stacks.';

  @override
  String get builtInPromptCodeExpertPrompt =>
      'You are an experienced software engineer skilled in many programming languages and technology stacks. Based on the user’s question, provide high-quality code examples, technical explanations, and best-practice recommendations. Prioritize readability, performance, and security. When providing code, label the language and use suitable formatting. For system-design questions, analyze trade-offs from an architecture perspective.';

  @override
  String get builtInPromptTranslationName => 'Translation Assistant';

  @override
  String get builtInPromptTranslationDescription =>
      'A professional translator for multilingual translation and localization advice.';

  @override
  String get builtInPromptTranslationPrompt =>
      'You are a professional translator. Your responsibilities are:\n1. Accurately translate the content the user provides while preserving its style and tone.\n2. Give a natural expression when the user asks how to say something in a particular language.\n3. Offer localization advice for culturally specific content.\n4. When several translations are possible, list them and explain their differences.\nAlways identify the source and target languages first; ask the user if either is unclear.';

  @override
  String get builtInPromptEnglishTeacherName => 'English Teacher';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      'An English learning tutor who helps improve listening, speaking, reading, and writing.';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      'You are an experienced English teacher. Meet the user’s needs with:\n1. Grammar explanations: explain rules clearly and include examples.\n2. Vocabulary learning: explain word usage, collocations, and distinctions.\n3. Writing polish: improve English so it sounds natural.\n4. Conversation practice: simulate English-speaking situations.\n5. Pronunciation guidance: use phonetic symbols and approximate pronunciation.\nAdjust the difficulty to the user’s English level and use Chinese to support explanations.';

  @override
  String get builtInPromptInterviewerName => 'Interviewer';

  @override
  String get builtInPromptInterviewerDescription =>
      'A simulated interviewer for technical and behavioral interviews.';

  @override
  String get builtInPromptInterviewerPrompt =>
      'You are a professional interviewer. Run a practice interview for the user’s target role:\n1. First learn the target position and industry.\n2. Ask relevant technical, behavioral, and system-design questions.\n3. Evaluate the user’s answers and suggest improvements.\n4. Provide sample answers and reasoning.\n5. Keep a realistic pace: ask one or two questions, then wait for the user.\nBe professional and friendly, with the goal of helping the user improve their interview skills.';

  @override
  String get builtInPromptWritingName => 'Writing Assistant';

  @override
  String get builtInPromptWritingDescription =>
      'A writing and editing assistant for many genres and creative writing.';

  @override
  String get builtInPromptWritingPrompt =>
      'You are a professional writing consultant. Based on the user’s needs, provide:\n1. Drafting: write in genres such as argumentative, expository, and narrative.\n2. Editing: improve grammar, word choice, logic, structure, and expression.\n3. Outlining: help build a framework and identify key points.\n4. Creative ideas: offer inspiration and possible angles.\n5. Formatting: follow the conventions of the target genre and submission requirements.\nFirst understand the purpose, intended readers, and desired style, then give focused advice.';

  @override
  String get builtInPromptCreativeThinkerName => 'Creative Thinker';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      'A creative ideation and brainstorming partner who sparks fresh ideas.';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      'You are a creative thinking partner. Your tasks are:\n1. Brainstorming: offer varied creative directions around a topic.\n2. Developing concepts: deepen and extend existing ideas.\n3. Connecting fields: combine concepts from different areas in new ways.\n4. Thinking in reverse: challenge conventional thinking and offer unusual perspectives.\n5. Feasibility review: analyze implementation challenges and potential value.\nEncourage divergent thinking while bringing the discussion into focus at the right time. Offer three to five directions per response.';

  @override
  String get builtInPromptDataAnalystName => 'Data Analyst';

  @override
  String get builtInPromptDataAnalystDescription =>
      'A data analysis expert who helps understand, model, and visualize data.';

  @override
  String get builtInPromptDataAnalystPrompt =>
      'You are a data analysis expert. Based on the user’s question, provide:\n1. Analysis methods: choose suitable statistical methods and analytical frameworks.\n2. SQL/Python/R code: give examples for data processing and analysis.\n3. Visualization advice: recommend suitable chart types and tools.\n4. Interpretation: explain findings and their business meaning.\n5. Data cleaning: handle missing values, outliers, and other quality issues.\nClarify the analysis goal and data characteristics first. Prefer the Python ecosystem (pandas, numpy, matplotlib, seaborn).';

  @override
  String get builtInPromptRoleplayName => 'Roleplay';

  @override
  String get builtInPromptRoleplayDescription =>
      'An immersive, multi-character roleplaying experience.';

  @override
  String get builtInPromptRoleplayPrompt =>
      'You are now in roleplay mode. Play the character specified by the user and interact according to that character’s personality, tone, and knowledge:\n1. When the user says “play [character],” switch to that character immediately.\n2. Stay in character throughout the conversation.\n3. Match the character’s language style and knowledge to the description.\n4. The user can say “end roleplay” to stop.\n5. You may add reasonable fictional details that fit the character.\nWait for the user to specify a character.';

  @override
  String get builtInPromptLifeAdvisorName => 'Life Advisor';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      'A warm, thoughtful listener offering mental-health support and everyday advice.';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      'You are a warm and thoughtful life advisor. Your responsibilities are:\n1. Listen actively and understand the user’s concerns and emotional needs.\n2. Analyze issues rationally and help the user sort through their aspects.\n3. Offer concrete, actionable ways to improve everyday life.\n4. Provide understanding, encouragement, and positive support.\n5. Suggest professional help when it is needed.\nRemember: you are not a licensed mental-health counselor. For a serious mental-health crisis, encourage the user to seek professional help. Be empathetic without overstepping; support the user without making decisions for them.';

  @override
  String get builtInSystemTitleName => 'Title Assistant';

  @override
  String get builtInSystemTitleDescription =>
      'Generates a short title automatically from the conversation.';

  @override
  String get builtInSystemTitlePrompt =>
      'You are a title generator. Output one conversation title and nothing else.\n\nRules:\n- Use one line and no more than 50 characters.\n- Do not explain or use quotation marks.\n- Use the same language as the user’s messages.\n- Do not include tool names such as web_search or todowrite in the title.\n\nExamples:\n“Help me debug a production 500 error” → Debugging a production 500 error\n“Refactor the user service” → Refactoring the user service\n“Why is app.js failing?” → Troubleshooting app.js\n\nIf the user’s message is very short or just a greeting (such as “hello,” “haha,” or “are you there?”), create a title that reflects its tone or intent, such as greeting, casual chat, or quick confirmation.';

  @override
  String get builtInSystemCompactionName => 'Context Compaction Assistant';

  @override
  String get builtInSystemCompactionDescription =>
      'Condenses a long conversation into a structured, anchored summary to free context space.';

  @override
  String get builtInSystemCompactionPrompt =>
      'You are an anchored-context summarization assistant. Condense long conversations into structured summaries.\n\nSummarize only the conversation history provided. Recent messages may be preserved verbatim, so focus on older context that is still important.\n\nIf the prompt contains a <previous-summary> block, treat it as the current anchored summary: keep what is still true, remove outdated material, and integrate new facts.\n\nFollow this structure exactly. Keep the section order and include every section, even if it is empty:\n<template>\n## Objective\n- [The user’s goal in one or two sentences]\n\n## Important Details\n- [Constraints/preferences, decisions and reasons, important facts/assumptions, and precise context needed to continue; write (none) if empty]\n\n## Work State\n### Completed\n- [Completed work, verified facts, or changes made; write (none) if empty]\n\n### Active\n- [Current work, partial changes, or investigation; write (none) if empty]\n\n### Blocked\n- [Blockers, failed commands, or unknowns; write (none) if empty]\n\n## Next Move\n1. [The next specific action, or (none)]\n2. [Known follow-up action, or (none)]\n\n## Relevant Files\n- [File or directory path and why it matters; write (none) if empty]\n</template>\n\nRules:\n- Include every section, even if empty.\n- Use concise bullet points, not paragraphs.\n- Preserve exact file paths, symbols, commands, error messages, URLs, and identifiers.\n- Do not mention that you are summarizing, compacting, or merging context.\n- Use the same language as the conversation.';

  @override
  String get builtInPromptMarketTitle => 'Assistant Market';

  @override
  String get builtInPromptClose => 'Close';

  @override
  String get builtInPromptImportHint =>
      'Imported prompts become regular assistants that you can edit freely.';

  @override
  String get builtInPromptView => 'View prompt';

  @override
  String get builtInPromptAdd => 'Add';

  @override
  String get builtInPromptDescriptionHeading => 'Description';

  @override
  String get builtInPromptSystemPromptHeading => 'System Prompt';

  @override
  String get builtInPromptAddAssistant => 'Add Assistant';

  @override
  String builtInPromptViewerTitle(Object name) {
    return 'Prompt · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      'Configure a separate model and prompt for automatic title generation and context compaction. By default, the current chat model and built-in prompts are used.';

  @override
  String get systemAssistantTitleName => 'Title Generation Assistant';

  @override
  String get systemAssistantTitleDescription =>
      'Automatically generates conversation titles';

  @override
  String get systemAssistantCompactionName => 'Context Compaction Assistant';

  @override
  String get systemAssistantCompactionDescription =>
      'Condenses long conversations into anchored summaries';

  @override
  String get systemAssistantFollowCurrentModel =>
      'Follow the current chat model';

  @override
  String get systemAssistantChooseModel => 'Choose a model';

  @override
  String get systemAssistantResetPromptTitle => 'Reset to Default Prompt';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return 'Restore the built-in default prompt for “$taskTitle”? Your current custom prompt will be discarded.';
  }

  @override
  String get systemAssistantCancel => 'Cancel';

  @override
  String get systemAssistantReset => 'Reset';

  @override
  String get systemAssistantModelHeading => 'Model';

  @override
  String get systemAssistantPromptHeading => 'Prompt';

  @override
  String get systemAssistantCustomPromptHint =>
      'Changes will be used as a custom prompt';

  @override
  String get systemAssistantUsingCustomPrompt => 'Using custom prompt';

  @override
  String get systemAssistantUsingDefaultPrompt => 'Using default prompt';

  @override
  String get systemAssistantSave => 'Save';

  @override
  String get systemAssistantResetButton => 'Reset to default prompt';

  @override
  String get taskFlowPageTitle => 'Task Flows';

  @override
  String get taskFlowSampleTemplatesTooltip => 'Example templates';

  @override
  String get taskFlowEmptyState => 'No flows yet. Tap + to create one.';

  @override
  String get taskFlowStartFromTemplate => 'Start from a template';

  @override
  String get taskFlowChooseTemplate => 'Choose an Example Template';

  @override
  String get taskFlowTemplateIntroduction =>
      'Choose a flow close to what you need; you can adjust it later.';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count templates',
      one: '$count template',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      'Templates open as drafts that need configuration. Choose a model and assistant before saving.';

  @override
  String get taskFlowTemplateRecordingName =>
      'Transcribe and Summarize a Recording';

  @override
  String get taskFlowTemplateRecordingDescription =>
      'Choose a recording → speech recognition → assistant summary';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'Configure an ASR model and choose an assistant for the summary.';

  @override
  String get taskFlowTemplateImageTextName =>
      'Recognize and Organize Image Text';

  @override
  String get taskFlowTemplateImageTextDescription =>
      'Choose an image → text recognition → assistant organization';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'Configure an OCR model and choose an assistant to organize the text.';

  @override
  String get taskFlowTemplateReadImageName => 'Read Text from an Image';

  @override
  String get taskFlowTemplateReadImageDescription =>
      'Choose an image → text recognition → speech playback';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'Configure OCR and speech synthesis models, then choose a voice.';

  @override
  String get taskFlowActions => 'Flow actions';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '$count block',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'OCR';

  @override
  String get taskFlowBlockAsr => 'Speech Recognition';

  @override
  String get taskFlowBlockAudioSeparation => 'Audio Separation';

  @override
  String get taskFlowBlockCatCatch => 'Web Resource Download';

  @override
  String get taskFlowBlockTts => 'Speech Synthesis';

  @override
  String get taskFlowBlockChat => 'Assistant Chat';

  @override
  String get taskFlowBlockCustom => 'Custom block';

  @override
  String get taskFlowEdit => 'Edit';

  @override
  String get taskFlowCopy => 'Copy';

  @override
  String get taskFlowCopied => 'Copied';

  @override
  String get taskFlowDelete => 'Delete';

  @override
  String get taskFlowConfirmDelete => 'Confirm deletion';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return 'Delete the task flow “$flowName”?';
  }

  @override
  String get taskFlowUseTemplate => 'Use';

  @override
  String get ocrTemplatePlainTextLabel => 'Plain Text';

  @override
  String get ocrTemplatePlainTextContent =>
      'Transcribe all visible text in the page’s natural reading order, preserving line breaks and paragraphs. Return plain text only; do not add explanations or inferences.';

  @override
  String get ocrTemplateMarkdownLabel => 'Markdown';

  @override
  String get ocrTemplateMarkdownContent =>
      'Transcribe all visible text in the page’s natural reading order and use Markdown to preserve headings, lists, and tables. Represent mathematical formulas in LaTeX. Return only the transcription; do not add explanations or inferences.';

  @override
  String get ocrTemplateTableLabel => 'Tables';

  @override
  String get ocrTemplateTableContent =>
      'Transcribe all visible text in the page’s natural reading order. For tables, preserve the headers, row and column relationships, and empty cells, and output them as Markdown tables. Keep other content as ordinary text. Return only the transcription; do not add explanations or inferences.';

  @override
  String get ocrTemplateLatexLabel => 'LaTeX';

  @override
  String get ocrTemplateLatexContent =>
      'Transcribe all visible text in the page’s natural reading order. Preserve non-formula text and represent mathematical formulas in LaTeX; use \$...\$ for inline formulas and \$\$...\$\$ for display formulas. Return only the transcription; do not add explanations or inferences.';

  @override
  String get ocrDefaultImagesOnly => 'Default (send images only)';

  @override
  String get ocrSavedInstructionSnapshot => 'Saved instruction snapshot';

  @override
  String get ocrPageTitle => 'Image Text Recognition';

  @override
  String get ocrImageQualitySettings => 'Image quality settings';

  @override
  String get ocrImageQualityStandard => 'Standard quality';

  @override
  String get ocrImageQualityStandardHint => 'Smaller images for most use cases';

  @override
  String get ocrImageQualityOriginal => 'Original / high detail';

  @override
  String get ocrImageQualityOriginalHint =>
      'Keeps more detail; images and requests are larger';

  @override
  String get ocrReorderDone => 'Done';

  @override
  String get ocrReorderAction => 'Reorder';

  @override
  String get ocrClearAction => 'Clear';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return 'The previous task used model $modelId. Choose a provider and model again.';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      'The model position in the previous retry record is invalid. Choose a model again.';

  @override
  String get ocrLegacyModelPositionConfirm =>
      'The previous retry record saved only the model position. Confirm the current model before continuing.';

  @override
  String get ocrModelUnavailable =>
      'The original OCR provider or model is no longer available. Choose another one.';

  @override
  String get ocrModelLabel => 'Model';

  @override
  String get ocrConfigure => 'Configure';

  @override
  String get ocrSelectModel => 'Select a model';

  @override
  String get ocrInstructionLabel => 'Instruction';

  @override
  String get ocrManageInstructions => 'Manage recognition instructions';

  @override
  String get ocrBatchMode => 'Batch mode';

  @override
  String get ocrMergeRecognition => 'Combine results';

  @override
  String get ocrRecognizeEachImage => 'Recognize each image separately';

  @override
  String get ocrMaxConcurrency => 'Up to 2 concurrent requests';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count concurrent requests',
      one: '$count concurrent request',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count concurrent requests',
      one: '$count concurrent request',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint =>
      'Completed pages are kept; retry submits only unfinished pages.';

  @override
  String get ocrTakePhoto => 'Take a photo';

  @override
  String get ocrChooseFromAlbum => 'Choose from album';

  @override
  String get ocrNoImagesSelected => 'No images selected';

  @override
  String get ocrSelectImagesHint =>
      'Take a photo or select multiple images from your album to recognize.';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return 'Select all $_temp0 again before retrying.';
  }

  @override
  String ocrImageLabel(Object index) {
    return 'Image $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return 'Image_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => 'Invalid image index';

  @override
  String get ocrViewErrorDetails => 'View error details';

  @override
  String get ocrConfirmModel => 'Confirm this model';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images selected',
      one: '$count image selected',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => 'Preparing images…';

  @override
  String get ocrSavingRetryImages => 'Saving retry images…';

  @override
  String get ocrRecognizing => 'Recognizing…';

  @override
  String get ocrReadingRetryImages => 'Reading retry images…';

  @override
  String get ocrImportingImages => 'Importing images…';

  @override
  String get ocrStartRecognition => 'Start recognition';

  @override
  String get ocrSaveTo => 'Save to';

  @override
  String get ocrRootDirectory => 'Root directory';

  @override
  String get ocrChooseSaveFolder => 'Choose a folder to save to';

  @override
  String get ocrChooseImageSource => 'Choose image source';

  @override
  String get ocrChooseAppAlbum => 'Choose from app album';

  @override
  String get ocrAppAlbumDescription => 'Choose images already saved in the app';

  @override
  String get ocrChooseSystemAlbum => 'Choose from system album';

  @override
  String get ocrSystemAlbumDescription =>
      'Browse and choose images on this device';

  @override
  String ocrTakePhotoFailed(Object error) {
    return 'Taking photo failed: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return 'Selecting image failed: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return 'Loaded $_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return 'Processing image failed: $error';
  }

  @override
  String get ocrUnknownSourceImageCount =>
      'Cannot determine the original image count';

  @override
  String get ocrConfirmClear => 'Confirm clear';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      'The original OCR image cache is unavailable and its image count cannot be recovered. Clearing will reset the old retry state. Select all images for this OCR task again.';

  @override
  String get ocrConfirmClearSelected => 'Clear the selected OCR images?';

  @override
  String get ocrCancel => 'Cancel';

  @override
  String get ocrConfirmResetAndReselect => 'Reset and select images again';

  @override
  String get ocrRequestCheckFailed =>
      'Unable to check the OCR request. Check the model parameters.';

  @override
  String get ocrCancelledAdjustAndRetry =>
      'Recognition was cancelled. Adjust the provider/model request size or image quality, then try again.';

  @override
  String get ocrRequestSizeExceededTitle =>
      'OCR request exceeds the configured size';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return 'The request is about $requestSize MiB, which exceeds the configured $limit MiB limit.';
  }

  @override
  String get ocrRequestSizeHelp =>
      'Adjust the request size in provider defaults or model overrides, or choose a different image quality. After changing quality, clear and import the images again.';

  @override
  String get ocrUsePerImageMode => 'Use per-image recognition';

  @override
  String get ocrGotIt => 'Got it';

  @override
  String get ocrWaitForImport =>
      'Wait for image import to finish before starting recognition.';

  @override
  String get ocrWaitForRetryImages => 'Reading retry images. Please wait.';

  @override
  String get ocrConfigureProviderModel =>
      'Configure an OCR provider and model in Settings first.';

  @override
  String get ocrReselectProviderModel =>
      'Select an OCR provider and model again.';

  @override
  String get ocrConfirmLegacyModel =>
      'Confirm the OCR model from the previous retry record first.';

  @override
  String get ocrRetryImagesUnavailable =>
      'The original OCR image cache is unavailable. Clear the task and select all images again.';

  @override
  String get ocrRetryImageCountUnknown =>
      'The original OCR image cache is unavailable and its image count is unknown. Reset and select all images for this OCR task again.';

  @override
  String get ocrRetryImageReset =>
      'The previous retry input was reset. Select all images for this OCR task again.';

  @override
  String get ocrRetryImagesUnreadable =>
      'The original OCR image cache could not be read. Clear the task and select all images again.';

  @override
  String get ocrRetryImagesMissing =>
      'The original OCR image cache is missing or damaged. Clear the task and select all images again.';

  @override
  String get ocrImageListChanged =>
      'The image list changed. Start recognition again.';

  @override
  String get ocrReadInstructionFailed =>
      'Unable to read the recognition instruction. Try again.';

  @override
  String get ocrErrorDetails => 'Error details';

  @override
  String get ocrRequestHeading => 'Request';

  @override
  String get ocrResponseHeading => 'Response';

  @override
  String get ocrNoDetails => 'No details available';

  @override
  String get ocrImageLoadFailed => 'Unable to load image';

  @override
  String get ocrCrop => 'Crop';

  @override
  String get ocrEdit => 'Edit';

  @override
  String get ocrProcessingOcrFailed =>
      'Failed to process the OCR images. Please try again.';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionProviders => 'Providers';

  @override
  String get settingsSectionSystemAssistant => 'System Assistants';

  @override
  String get settingsSectionContextManagement => 'Context Management';

  @override
  String get settingsSectionManagement => 'Management';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsBackupRestore => 'Backup and Restore';

  @override
  String get settingsBackupRestoreDescription => 'Export or import app data';

  @override
  String get settingsCookies => 'Cookies and Browser Data';

  @override
  String get settingsCookiesDescription =>
      'Manage persistent cookies and browser storage';

  @override
  String get settingsAppLogs => 'App Logs';

  @override
  String get settingsAppLogsDescription => 'View app runtime logs';

  @override
  String get settingsThemeDisplay => 'Theme and Display';

  @override
  String get settingsThemeDisplayDescription =>
      'Dark mode and display language';

  @override
  String get settingsTaskNotifications => 'Task Completion Notifications';

  @override
  String get settingsTaskNotificationsDescription =>
      'Check notification permission and system settings, and view the notification guide';

  @override
  String get settingsBackgroundOptimization =>
      'Background Operation Optimization';

  @override
  String get settingsBackgroundOptimizationDescription =>
      'Check system environment and background service status, and view optimization guidance';

  @override
  String get aboutVersionInfo => 'View version information';

  @override
  String get aboutCheckUpdates => 'Check for Updates';

  @override
  String aboutNewVersionFound(Object version) {
    return 'New version $version available';
  }

  @override
  String get aboutNewVersion => 'New Version';

  @override
  String get aboutPreviewUpdates => 'Preview Updates';

  @override
  String get aboutPreviewUpdatesDescription =>
      'Enable checks for preview releases';

  @override
  String get aboutProjectHome => 'Project Home';

  @override
  String get aboutFeedback => 'Report an Issue';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutOpenSourceAgreement => 'Open Source Agreement';

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutCheckingUpdates => 'Checking for updates…';

  @override
  String get aboutUpToDate => 'You are using the latest version';

  @override
  String aboutUpdateNetworkError(Object details) {
    return 'Network error: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return 'Update check failed with HTTP status $statusCode.';
  }

  @override
  String get aboutUpdateInvalidResponse =>
      'The update server returned an unexpected response.';

  @override
  String get aboutUpdateCheckFailed =>
      'The update check failed. Please try again.';

  @override
  String get aboutPrivacyContent =>
      'Stroom respects and protects the privacy of everyone who uses the service.\n\n1. Camera permission: Used only to take photos. No image data is collected or uploaded.\n\n2. Photo library permission: Used only to choose and save photos. All photos are stored locally on your device.\n\n3. Data security: All photos you take are stored locally on your device. We do not access or upload your data.\n\n4. Third-party services: This app contains no third-party analytics or advertising services.\n\nContact us if you have questions.';

  @override
  String get aboutClose => 'Close';

  @override
  String get contextToolPruneTitle =>
      'Automatically prune tool results (Prune)';

  @override
  String get contextToolPruneDescription =>
      'Automatically replace old tool results above the threshold with placeholders to free storage and context.';

  @override
  String get contextCompactionTriggerSettings => 'Compaction Trigger Settings';

  @override
  String get contextCompactionDisabled => 'Disabled (compaction will not run)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return 'Global trigger $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count model-specific overrides',
      one: '$count model-specific override',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => 'Compaction Trigger Settings';

  @override
  String get contextAutoCompaction => 'Automatic Context Compaction';

  @override
  String get contextAutoCompactionDisabled =>
      'When disabled, compaction will not run for any model.';

  @override
  String get contextGlobalTrigger => 'Global trigger percentage';

  @override
  String get contextGlobalTriggerDescription =>
      'Models without an individual setting use this percentage of the model context window as the compaction trigger.';

  @override
  String contextResetPercent(Object percent) {
    return 'Reset to $percent%';
  }

  @override
  String get contextPerModelSettings => 'Per-model settings';

  @override
  String get contextNoConfiguredModels => 'No configured models';

  @override
  String contextIndependentThreshold(Object threshold) {
    return 'Independent threshold: $threshold tokens';
  }

  @override
  String get contextEnterIndependentThreshold =>
      'Enter an independent threshold below';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return 'Follow global $percent%';
  }

  @override
  String get contextThresholdField => 'Independent threshold (tokens)';

  @override
  String get contextThresholdHint =>
      'For example, 48000 (token count, not a percentage)';

  @override
  String get contextPercentField => 'Percentage';

  @override
  String contextPercentHint(Object percent) {
    return 'For example, $percent';
  }

  @override
  String get versionInfoTitle => 'Version information';

  @override
  String get versionNumberLabel => 'Version';

  @override
  String get versionReleaseTimeLabel => 'Release time';

  @override
  String get versionLocalBuild => 'Local build';

  @override
  String get versionReleaseNotesLabel => 'Release notes';

  @override
  String get versionClose => 'Close';

  @override
  String get updateDialogTitle => 'New version available';

  @override
  String get updateLatestVersionLabel => 'Latest version';

  @override
  String get updateSelectedVersionLabel => 'Selected version';

  @override
  String get updateReleaseNotesLabel => 'Release notes';

  @override
  String get updateInstalling => 'Installing…';

  @override
  String get updateDownloadComplete => 'Download complete';

  @override
  String get updateClose => 'Close';

  @override
  String get updateManualInstall => 'Install manually';

  @override
  String get updateOpenInstaller => 'Open installer';

  @override
  String get updateRetryDownload => 'Retry download';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateRemindLater => 'Remind me later';

  @override
  String get updateOpenBrowser => 'Download in browser';

  @override
  String get updateNow => 'Update now';

  @override
  String get updatePreviewBadge => 'Preview';

  @override
  String get updateLatestBadge => 'Latest';

  @override
  String get updateSelectVersion => 'Select version';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String updateCheckNetworkError(Object details) {
    return 'Network error: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return 'Failed to check for updates: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      'Failed to check for updates: the server returned unrecognized data';

  @override
  String get updateDownloadUrlUnavailable => 'The download URL is unavailable.';

  @override
  String get updateNoDirectDownloadLink =>
      'There is no direct download link for this platform. Download it in a browser.';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return 'Automatic installation failed: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return 'Download failed: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return 'Download failed: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return 'Installation failed: $details';
  }

  @override
  String updateFailed(Object details) {
    return 'Update failed: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return 'Could not open the file. Install it manually: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return 'Installation failed. Open the APK manually: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails =>
      'Installation failed. Open the APK manually.';

  @override
  String get contextCompactionHistoryIntro =>
      'Conversation history to condense:';

  @override
  String get contextCompactionUserRole => 'User';

  @override
  String get contextCompactionAssistantRole => 'Assistant';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role called tool $toolName: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      'Condense the conversation history above into an anchored summary, following the template exactly.';

  @override
  String get ocrImageEmpty => 'The image is empty. Select it again.';

  @override
  String get ocrImageUnsupportedFormat =>
      'This image format is not supported. Convert it to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'HEIC, SVG, and TIFF images are not supported yet. Convert the image to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImageDecodeFailed =>
      'The image is damaged or cannot be decoded. Select it again, or convert it to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImageDimensionsTooLarge =>
      'The image resolution is too large. OCR supports up to 50 million pixels per image. Resize it and try again.';

  @override
  String get ocrImageOrientationPngTooLarge =>
      'The PNG needed to correct this image orientation would exceed the OCR request size limit. Resize the image and try again.';

  @override
  String get ocrImageOrientationFailed =>
      'The image orientation could not be corrected. Convert it to PNG, JPEG, or WebP and try again.';

  @override
  String get ocrImagePreparationFailed =>
      'The image could not be processed. Select it again and try again.';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeWelcome => 'Welcome to Stroom';

  @override
  String get homeChooseModule => 'Choose a module to get started';

  @override
  String get homeOcrSubtitle => 'Text recognition';

  @override
  String get homeAsrTitle => 'Speech recognition';

  @override
  String get homeAsrSubtitle => 'Speech to text';

  @override
  String get homeWebDownloadTitle => 'Download web media';

  @override
  String get homeWebDownloadSubtitle =>
      'Download audio and video from webpages';

  @override
  String get homeAudioSeparationTitle => 'Audio separation';

  @override
  String get homeAudioSeparationSubtitle => 'Extract audio from video';

  @override
  String get homeTtsTitle => 'Text to speech';

  @override
  String get homeTtsSubtitle => 'Convert text to speech';

  @override
  String get homeChartsTitle => 'Chart maker';

  @override
  String get homeChartsSubtitle => 'Mermaid chart editor';

  @override
  String get homeMathTitle => 'Math plotting';

  @override
  String get homeMathSubtitle => 'Plot functions';

  @override
  String get homeAnkiTitle => 'Anki flashcards';

  @override
  String get homeAnkiSubtitle => 'Memory aid system';

  @override
  String get homeTaskFlowTitle => 'Task flows';

  @override
  String get homeTaskFlowEmpty =>
      'Create an automated flow to run multiple modules in sequence';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count task flows · Manage',
      one: '$count task flow · Manage',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => 'Recent tasks';

  @override
  String get homeViewAll => 'View all';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get navHome => 'Home';

  @override
  String get navChat => 'Chat';

  @override
  String get navFiles => 'Files';

  @override
  String get navSettings => 'Settings';

  @override
  String get conversationsTitle => 'Conversation history';

  @override
  String get conversationNew => 'New conversation';

  @override
  String get conversationSelectTitle => 'Choose a conversation';

  @override
  String get topicSelectionEmptyTitle => 'No conversations yet';

  @override
  String get topicSelectionEmptyMessage =>
      'Create a new conversation to get started';

  @override
  String get topicSelectionNewTopic => 'New conversation';

  @override
  String get topicSelectionNoAssistant => 'No assistant selected';

  @override
  String get topicSelectionBackToAssistants => 'Back to assistant selection';

  @override
  String get topicSelectionEditAssistant => 'Edit assistant';

  @override
  String get topicSelectionReorderHint =>
      'Long-press and drag to reorder conversations';

  @override
  String conversationDeleteNamed(String title) {
    return 'Delete conversation “$title”? This cannot be undone.';
  }

  @override
  String get conversationDeleteTitle => 'Delete conversation';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the selected $count conversations? This cannot be undone.',
      one: 'Delete the selected $count conversation? This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get conversationRename => 'Rename conversation';

  @override
  String get conversationRenameHint => 'Enter a new name';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get conversationNoMatches => 'No matching conversations found';

  @override
  String get conversationEmpty => 'No conversation history';

  @override
  String get conversationSearchHint =>
      'Search messages in all conversations...';

  @override
  String conversationSelected(int count) {
    return '$count selected';
  }

  @override
  String get conversationSearch => 'Search';

  @override
  String get conversationDeleteSelected => 'Delete selected';

  @override
  String get actionUnselect => 'Cancel selection';

  @override
  String get actionSelect => 'Select';

  @override
  String conversationDeleteCount(int count) {
    return 'Delete $count';
  }

  @override
  String get conversationPin => 'Pin';

  @override
  String get conversationUnpin => 'Unpin';

  @override
  String get actionRename => 'Rename';

  @override
  String get conversationAutoRename => 'Auto-name';

  @override
  String get conversationTemporary => 'Temporary conversation';

  @override
  String get conversationCloseTemporary => 'Close temporary conversation';

  @override
  String get taskListTitle => 'Task list';

  @override
  String get taskListEmpty => 'No tasks';

  @override
  String get unifiedTaskListTabAll => 'All';

  @override
  String get unifiedTaskListTabInProgress => 'In progress';

  @override
  String get unifiedTaskListTabCompleted => 'Completed';

  @override
  String get unifiedTaskListTabFailed => 'Failed';

  @override
  String get unifiedTaskListTabStopped => 'Stopped';

  @override
  String get unifiedTaskListConfirmClear => 'Confirm clear';

  @override
  String get unifiedTaskListConfirmClearFailedMessage =>
      'Are you sure you want to clear all failed tasks?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      'Are you sure you want to clear all tasks? This action cannot be undone.';

  @override
  String get unifiedTaskListCancel => 'Cancel';

  @override
  String get unifiedTaskListConfirm => 'Confirm';

  @override
  String get unifiedTaskListClearCompleted => 'Clear completed tasks';

  @override
  String get unifiedTaskListClearFailed => 'Clear failed tasks';

  @override
  String get unifiedTaskListClearAll => 'Clear all tasks';

  @override
  String get unifiedTaskListRestoreInProgress => 'Restoring task flow records…';

  @override
  String get unifiedTaskListRestoreFailed =>
      'Could not read task flow records; task actions are paused';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return 'Clear incomplete: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning =>
      'The task flow is still running after cancellation.';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      'Could not save the task flow cancellation state. Please retry clearing.';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      'Could not save deletion of task flow records. Please retry clearing.';

  @override
  String get chatAutoContinuePrompt => 'Continue if not finished.';

  @override
  String get chatSearchCurrent => 'Search this conversation...';

  @override
  String get chatSearchAll => 'Search all conversations...';

  @override
  String get searchPrevious => 'Previous match';

  @override
  String get searchNext => 'Next match';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchCurrentConversation => 'Current conversation';

  @override
  String get searchAllConversations => 'All conversations';

  @override
  String get chatReasoning => 'Reasoning';

  @override
  String get chatTools => 'Tools';

  @override
  String get chatCustomParameters => 'Custom parameters';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get actionClose => 'Close';

  @override
  String get chatEditWarning =>
      'All messages below will be lost when you edit and resend';

  @override
  String get chatAttachment => 'Attachment';

  @override
  String get chatMessageHint => 'Enter a message...';

  @override
  String get chatFullscreenEdit => 'Full-screen editor';

  @override
  String get chatStopGeneration => 'Stop generating';

  @override
  String get actionSend => 'Send';

  @override
  String get chatCopy => 'Copy';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionEdit => 'Edit';

  @override
  String get chatViewResponseData => 'View response data';

  @override
  String get chatViewRequestData => 'View request data';

  @override
  String get chatInspectJson => 'Inspect JSON';

  @override
  String get chatConfirmEditTitle => 'Edit message';

  @override
  String get chatConfirmEditDeleteFollowing =>
      'Edit this message? This message and all following messages will be deleted.';

  @override
  String get chatConfirmResend => 'Resend this message?';

  @override
  String get chatConfirmRetryTitle => 'Retry';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      'Retry this response? This message and all following messages will be deleted.';

  @override
  String get chatConfirmRegenerate => 'Regenerate the response?';

  @override
  String get chatDeleteMessageTitle => 'Delete message';

  @override
  String get chatDeleteMessageConfirm =>
      'Delete this message? This cannot be undone.';

  @override
  String get chatThinking => 'Thinking';

  @override
  String get chatThinkingComplete => 'Thought';

  @override
  String get conversationDeleteOne =>
      'Delete this conversation? This cannot be undone.';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Selected $selected/$total resources',
      one: 'Selected $selected/$total resource',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => 'Select media to download';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hide $count segments',
      one: 'Hide $count segment',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count segments',
      one: 'Show $count segment',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => 'No resources detected';

  @override
  String get mediaSegment => 'Segment';

  @override
  String get mediaPlaylist => 'Playlist';

  @override
  String get mediaFullVideo => 'Full video';

  @override
  String mediaDuration(String value) {
    return 'Duration: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return 'Resolution: ${width}x$height';
  }

  @override
  String get mediaPreview => 'Preview';

  @override
  String get mediaSegmentPreviewHint => 'Preview segments from the playlist';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count selected resources',
      one: 'Download $count selected resource',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => 'Confirm download';

  @override
  String get chatNoMoreHistory => 'No more messages';

  @override
  String get chatSendFailed => 'Message failed to send';

  @override
  String get chatViewErrorDetails => 'View error details';

  @override
  String get chatCompactionCollapsed =>
      'Context compacted · older messages summarized (click to collapse)';

  @override
  String get chatCompactionExpanded =>
      'Context compacted · older messages summarized (click to view summary)';

  @override
  String get chatEditConversationTitle => 'Edit conversation title';

  @override
  String get chatSearchMessages => 'Search messages';

  @override
  String get chatApiMissingSettings =>
      '⚠️ Chat API is not configured — go to Settings';

  @override
  String get appSettings => 'Settings';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatNoSavableText => 'There is no text to save';

  @override
  String get chatSaveMarkdownTitle => 'Save message as Markdown';

  @override
  String get chatSaveToolCallChoice =>
      'This reply contains multiple tool calls. Choose what to save:';

  @override
  String get chatSaveCompleteMessage => 'Save complete message';

  @override
  String get chatSaveLastMessage => 'Save last message';

  @override
  String get chatSaveToAppFiles => 'Save to app files';

  @override
  String get chatSaveFolderHint => 'Choose or create a folder for the .md file';

  @override
  String get chatSaveFilenameHint =>
      'Enter a file name (.md is added automatically)';

  @override
  String get chatFilenameRequired => 'The file name cannot be empty';

  @override
  String chatSavedToPath(String path) {
    return 'Saved to: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return 'Saved to app files: $path';
  }

  @override
  String get chatSelectModel => 'Select a model';

  @override
  String get chatNoModelsAvailable => 'No models available';

  @override
  String get chatAvailableTools => 'Available tools';

  @override
  String get chatNoToolsAvailable => 'No tools available';

  @override
  String get chatReasoningSettings => 'Reasoning settings';

  @override
  String get chatReasoningNotConfigured =>
      'No reasoning parameters are configured for this model. Add them in model settings.';

  @override
  String get chatReasoningEffort => 'Reasoning effort';

  @override
  String get chatReasoningEffortNotConfigured =>
      'No reasoning effort parameter is configured for this model. Add it in model settings.';

  @override
  String get chatParameterNoOptions =>
      'This parameter has no option values. Add them in model settings.';

  @override
  String get chatOtherReasoningNotConfigured =>
      'No other reasoning parameters are configured for this model.\nAdd them in model settings.';

  @override
  String get chatCustomParamsNotConfigured =>
      'No custom parameters are configured for this model.\nAdd them in model settings.';

  @override
  String get chatNoOptionValues =>
      'No option values. Add them in model settings.';

  @override
  String get chatImageLoadFailed => 'Unable to load image';

  @override
  String get chatVideoLoadFailed => 'Unable to load video';

  @override
  String get chatHtmlLoading => 'Loading HTML preview...';

  @override
  String get chatPreviewLoadFailed => 'Preview failed to load';

  @override
  String get albumPickerLoadFailed => 'Unable to load the app album';

  @override
  String get chatHtmlPreview => 'HTML preview';

  @override
  String get chatMermaidLoading => 'Loading chart preview...';

  @override
  String get chatMermaidPreview => 'Mermaid preview';

  @override
  String get chatZoomOut => 'Zoom out';

  @override
  String get chatZoomIn => 'Zoom in';

  @override
  String get chatJsonInspection => 'JSON inspection';

  @override
  String get chatNoRequestData => 'No request data';

  @override
  String get chatNoResponseData => 'No response data';

  @override
  String get chatSaveMessage => 'Save message';

  @override
  String get chatChooseSaveLocation => 'Choose where to save the message';

  @override
  String get chatChooseSaveLocationLabel => 'Choose a save location:';

  @override
  String get chatSaveAppFile => 'Save to app files';

  @override
  String get chatSaveDevice => 'Save to device';

  @override
  String get chatFileTypeAudio => 'Audio file';

  @override
  String get chatFileTypeVideo => 'Video file';

  @override
  String get chatFileTypeDocument => 'Document';

  @override
  String get chatFileTypeGeneric => 'File';

  @override
  String get chatInfoType => 'Type';

  @override
  String get chatInfoSize => 'Size';

  @override
  String get chatInfoPath => 'Path';

  @override
  String get chatErrorBack => 'Back';

  @override
  String get chatDataDetails => 'Data details';

  @override
  String get chatAudioPreviewClose => 'Close';

  @override
  String get chatPreviewClose => 'Close preview';

  @override
  String get actionBack => 'Back';

  @override
  String get chatCannotLoadFile => 'Unable to load file';

  @override
  String chatThinkingNumbered(int index) {
    return 'Thinking $index';
  }

  @override
  String get taskFlowUiDiscardTitle => 'Discard unsaved changes?';

  @override
  String get taskFlowUiDiscardBody =>
      'All unsaved changes will be lost if you go back.';

  @override
  String get taskFlowUiContinueEditing => 'Continue editing';

  @override
  String get taskFlowUiDiscard => 'Discard';

  @override
  String get taskFlowUiUndo => 'Undo';

  @override
  String get taskFlowUiSave => 'Save';

  @override
  String get taskFlowUiNameHint => 'Enter a task flow name';

  @override
  String get taskFlowUiDescriptionHint => 'Add a description (optional)';

  @override
  String get taskFlowUiNameRequired => 'Enter a task flow name';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return 'Step $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '“$parameter” is required for “$block”';
  }

  @override
  String get taskFlowUiSaveFailed =>
      'Could not save. Your changes are still here. Try again.';

  @override
  String get taskFlowUiRetry => 'Retry';

  @override
  String get taskFlowUiUpdated => 'Task flow updated';

  @override
  String get taskFlowUiCreated => 'Task flow created';

  @override
  String get taskFlowUiTitle => 'Task Flow';

  @override
  String get taskFlowUiNotFound => 'Task not found';

  @override
  String get taskFlowUiBack => 'Back';

  @override
  String get taskFlowUiEdit => 'Edit';

  @override
  String taskFlowUiInput(Object label) {
    return 'Input ($label)';
  }

  @override
  String get taskFlowUiInputHint => 'Enter text or a link';

  @override
  String get taskFlowUiStart => 'Start task flow';

  @override
  String get taskFlowUiNoInput =>
      'No inputs yet. Tap below to add a web resource URL.';

  @override
  String get taskFlowUiAddResource => 'Add web resource';

  @override
  String get taskFlowUiUrlHint => 'Enter a video or audio webpage URL';

  @override
  String get taskFlowUiDeleteInput => 'Remove this input';

  @override
  String get taskFlowUiHour => 'hr';

  @override
  String get taskFlowUiMinute => 'min';

  @override
  String get taskFlowUiSecond => 'sec';

  @override
  String get taskFlowUiPreview => 'Preview: ';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      'Optional: filter video resources by duration. Leave blank to show all available resources.';

  @override
  String get taskFlowUiSelectImages => 'Select images (multiple)';

  @override
  String get taskFlowUiSelectAudio => 'Select audio (multiple)';

  @override
  String get taskFlowUiSelectFiles => 'Select files (multiple)';

  @override
  String get taskFlowUiSelectVideo => 'Select videos (multiple)';

  @override
  String get taskFlowUiRemove => 'Remove';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return 'Could not clean up the removed file: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0. Initial input';

  @override
  String taskFlowUiInputType(Object type) {
    return 'Input type: $type';
  }

  @override
  String get taskFlowUiUserFlowInput =>
      'Input provided when the user runs the task flow';

  @override
  String taskFlowUiBlockInput(Object type) {
    return 'Input: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return 'Output: $type';
  }

  @override
  String get taskFlowUiParameters => 'Parameters:';

  @override
  String get taskFlowUiClose => 'Close';

  @override
  String get taskFlowUiSelectAppImages =>
      'Select images from the app (multiple)';

  @override
  String get taskFlowUiNoImages => 'No images';

  @override
  String get taskFlowUiSelectAppAudio => 'Select audio from the app (multiple)';

  @override
  String get taskFlowUiNoAudio => 'No audio';

  @override
  String get taskFlowUiSelectAppVideo =>
      'Select videos from the app (multiple)';

  @override
  String get taskFlowUiNoVideo => 'No videos';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return 'Could not select the file: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '“$name” exceeds $limit MB. Choose a smaller file.';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '“$name” is empty or unreadable';
  }

  @override
  String get taskFlowUiSomeFilesMissing =>
      'Some files are missing and were skipped';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return 'Unable to access $count selected file(s). Please select all files again.';
  }

  @override
  String get taskFlowUiQueuedOne => 'Task flow added to the queue';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return 'Added $count task flows to the queue';
  }

  @override
  String get taskFlowUiRunTitle => 'This Run';

  @override
  String get taskFlowUiCancelBatch => 'Cancel entire batch';

  @override
  String get taskFlowUiRestoringRecords => 'Restoring task flow records…';

  @override
  String get taskFlowUiRecordsPaused =>
      'Could not load task flow records. Task actions are paused.';

  @override
  String get taskFlowUiRecordsCleared =>
      'Records for this run have been cleared';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$finished of $total runs finished';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return ' · $count records cleared';
  }

  @override
  String get taskFlowUiTemporaryFiles => 'Temporary intermediate files';

  @override
  String get taskFlowUiAddBlock => 'Add block';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return 'Insert block before step $index';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      'No block is compatible with both adjacent steps. Adjust the adjacent steps first.';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return 'Insert before step $index';
  }

  @override
  String get taskFlowUiUnknown => 'Unknown';

  @override
  String get taskFlowUiChooseBlock => 'Choose a block';

  @override
  String get taskFlowUiInsertBlock => 'Insert block';

  @override
  String get taskFlowUiPreviousOutput => 'Previous step output';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '; next step needs: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock =>
      'No block is compatible with the current type';

  @override
  String get taskFlowUiReplaceBlock => 'Replace block';

  @override
  String get taskFlowUiBlockCompatibility =>
      'You can only replace this with a block that has compatible input and output types.';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      'Clean up after the next step saves its result successfully; the final step is always kept.';

  @override
  String get taskFlowUiSetParameters => 'Set parameters';

  @override
  String get taskFlowUiReplace => 'Replace';

  @override
  String get taskFlowUiViewParameters => 'Tap to view parameters';

  @override
  String get taskFlowUiTapSetParameters => 'Tap to set parameters';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return 'Unknown block: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => 'This block type is not registered';

  @override
  String taskFlowUiStepActions(Object index) {
    return 'Actions for step $index';
  }

  @override
  String get taskFlowUiInsertBefore => 'Insert before';

  @override
  String get taskFlowUiInsertAfter => 'Insert after';

  @override
  String get taskFlowUiCopyBlock => 'Duplicate block';

  @override
  String get taskFlowUiMoveUp => 'Move up';

  @override
  String get taskFlowUiMoveUpDisabled => 'Move up (already first)';

  @override
  String get taskFlowUiMoveDown => 'Move down';

  @override
  String get taskFlowUiMoveDownDisabled => 'Move down (already last)';

  @override
  String get taskFlowUiDeleteBlock => 'Delete block';

  @override
  String taskFlowUiInputLabel(Object label) {
    return 'Input: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return 'Output: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return 'Block type “$name” is not registered';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$label settings';
  }

  @override
  String get taskFlowUiSendToAssistant =>
      'The user message sent to the assistant is the previous step’s output';

  @override
  String get taskFlowUiTempSpaceInfo =>
      'This step outputs to the flow’s temporary space. Its output is cleaned up after the next step saves successfully. The original save folder is preserved and restored when temporary mode is disabled.';

  @override
  String get taskFlowUiNoExtraParameters =>
      'This block has no additional parameters';

  @override
  String get taskFlowUiCancel => 'Cancel';

  @override
  String get taskFlowUiConfirm => 'Confirm';

  @override
  String get taskFlowUiConfigureModelFirst => 'Configure a model first';

  @override
  String get taskFlowUiModelUnavailable =>
      'No model is selected or the model is unavailable. Select another model.';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return 'Model $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => 'Unnamed provider';

  @override
  String get taskFlowUiCustomModelParameters => 'Custom model parameters';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      'No TTS models have configured voices. You can enter an ID manually.';

  @override
  String get taskFlowUiVoiceUnavailable =>
      'Voice is unavailable. Select another voice.';

  @override
  String get taskFlowUiSelectVoice => 'Select a voice';

  @override
  String get taskFlowUiAssistantUnavailable => 'Assistant unavailable';

  @override
  String get taskFlowUiAssistantUseCurrent =>
      'Not specified (use the currently selected assistant)';

  @override
  String get taskFlowUiAssistantDeleted =>
      'The configured assistant was deleted. Select another assistant.';

  @override
  String get taskFlowUiChooseAssistant => 'Choose an assistant';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      'Only “My Assistants” can be selected (add one in “Chat → Assistants”)';

  @override
  String get taskFlowUiMyAssistants => 'My Assistants';

  @override
  String get taskFlowUiNoCustomAssistants =>
      'No custom assistants yet. Create one in “Chat → Assistants”.';

  @override
  String get taskFlowUiYes => 'Yes';

  @override
  String get taskFlowUiNo => 'No';

  @override
  String get taskFlowUiDefaultRoot => 'Default (root folder)';

  @override
  String get taskFlowUiSelect => 'Select';

  @override
  String get taskFlowUiSelectSaveFolder => 'Choose a save folder';

  @override
  String get taskFlowUiCatCatchVideo => 'Video';

  @override
  String get taskFlowUiCatCatchAudio => 'Audio';

  @override
  String get taskFlowUiCatCatchEither =>
      'Video or audio (filter based on downstream steps)';

  @override
  String get taskFlowUiManual => 'Manual';

  @override
  String get taskFlowUiAutomatic => 'Automatic';

  @override
  String get taskFlowUiAutomaticPrompt => 'Automatic with confirmation';

  @override
  String get taskFlowUiEditTitle => 'Edit Task Flow';

  @override
  String get taskFlowUiCreateTitle => 'New Task Flow';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return 'Step $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return 'Input type: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return 'Input: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return 'Output: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return 'Could not clean up the removed file: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return 'Could not select the file: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '“$name” exceeds $limit MB. Choose a smaller file.';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '“$name” is empty or unreadable';
  }

  @override
  String get taskFlowUiTemporary => 'Temporary';

  @override
  String get taskFlowUiTemporaryFileHint =>
      'Temporary file (cleaned up after the next step succeeds)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return 'Block type “$name” is not registered';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$finished of $total runs finished';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return ' · $count records cleared';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return 'Input: $input → Output: $output';
  }

  @override
  String get taskFlowCardTag => 'Task Flow';

  @override
  String get taskFlowCardQueued => 'Queued (waiting for resources)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done of $total completed';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count $label';
  }

  @override
  String get taskFlowCardFailedLabel => 'failed';

  @override
  String get taskFlowCardSkippedLabel => 'skipped';

  @override
  String get taskFlowCardCancelledLabel => 'cancelled';

  @override
  String get taskFlowCardInterruptedLabel => 'interrupted';

  @override
  String get taskFlowCardCancelFlow => 'Cancel flow';

  @override
  String get taskFlowCardRetry => 'Retry';

  @override
  String get taskFlowCardCancelBatch => 'Cancel entire batch';

  @override
  String get taskFlowCardDelete => 'Delete';

  @override
  String get taskFlowCardRetryFlow => 'Retry task flow';

  @override
  String get taskFlowCardNoSnapshot =>
      'This run has no snapshot. It will start over using the current flow configuration.';

  @override
  String get taskFlowCardRetryInfo =>
      'Starting over downloads files and calls models again. Retry with the configuration used at launch, or explicitly choose the latest configuration. To reuse completed steps, choose “Resume from interrupted step.”';

  @override
  String get taskFlowCardRunLatest => 'Run with latest configuration';

  @override
  String get taskFlowCardRetryOriginal => 'Retry with original configuration';

  @override
  String get taskFlowCardDeleteRecord => 'Delete task flow record';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      'Deleting this run will cancel unfinished tasks in the batch and clear their subtask records. Delete?';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      'This flow is running. Deleting it will cancel its active tasks. Delete?';

  @override
  String get taskFlowCardDeleteRecordConfirm =>
      'Delete this flow record and its subtask records?';

  @override
  String get taskFlowCardDeleteConfirm => 'Delete this flow record?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      'Could not save the flow cancellation state. Try deleting again.';

  @override
  String get taskFlowCardStillRunning =>
      'The flow is still running after cancellation.';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      'Could not save the flow record deletion state. Try deleting again.';

  @override
  String get taskFlowCardConfirm => 'Confirm';

  @override
  String get taskFlowCardWaiting => 'Waiting';

  @override
  String get taskFlowCardRunning => 'Running';

  @override
  String get taskFlowCardPaused => 'Paused';

  @override
  String get taskFlowCardCompleted => 'Completed';

  @override
  String get taskFlowCardFailed => 'Failed';

  @override
  String get taskFlowCardCanceled => 'Canceled';

  @override
  String get taskFlowCardInterrupted => 'Interrupted';

  @override
  String get taskFlowCardSucceeded => 'Skipped';

  @override
  String get taskFlowCardPause => 'Pause flow';

  @override
  String get taskFlowCardResume => 'Resume flow';

  @override
  String get taskFlowCardResumeInterrupted => 'Resume from interrupted step';

  @override
  String get taskFlowCardCancel => 'Cancel';

  @override
  String get unifiedTaskType => 'Task type';

  @override
  String get unifiedTaskCreatedAt => 'Created';

  @override
  String get unifiedTaskCompletedAt => 'Completed';

  @override
  String get unifiedTaskResultStatus => 'Result status';

  @override
  String get unifiedTaskPartialResult =>
      'Partial result; content may be incomplete';

  @override
  String get unifiedTaskErrorDetails => 'Error details';

  @override
  String get unifiedTaskViewErrorDetails => 'View error details';

  @override
  String get unifiedTaskOcrPerImage => 'Recognize each image';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return 'Image $index';
  }

  @override
  String get unifiedTaskOcrPending => 'Waiting to recognize';

  @override
  String get unifiedTaskOcrRunning => 'Recognizing';

  @override
  String get unifiedTaskCompleted => 'Completed';

  @override
  String get unifiedTaskIncomplete => 'Incomplete result';

  @override
  String get unifiedTaskOcrFailed => 'Recognition failed';

  @override
  String get unifiedTaskCancelled => 'Canceled';

  @override
  String get unifiedTaskWaitingStart => 'Waiting to start...';

  @override
  String get unifiedTaskSteps => 'Steps';

  @override
  String get unifiedTaskStartNow => 'Start now';

  @override
  String get unifiedTaskOpenFile => 'Open file';

  @override
  String get unifiedTaskRetrySave => 'Retry saving only';

  @override
  String get unifiedTaskRetryPartialSave => 'Retry saving partial result only';

  @override
  String get unifiedTaskSavePartialResult => 'Save partial result';

  @override
  String get unifiedTaskRetry => 'Retry';

  @override
  String get unifiedTaskCancel => 'Cancel';

  @override
  String get unifiedTaskDelete => 'Delete';

  @override
  String get unifiedTaskFormatUnsupported =>
      'Preview is not supported for this format';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String get unifiedTaskAudioFile => 'Audio file';

  @override
  String get unifiedTaskPreviewLoadFailed => 'Could not load preview';

  @override
  String get unifiedTaskUnknownSize => 'Unknown size';

  @override
  String get unifiedTaskUnnamedRecording => 'Untitled recording';

  @override
  String get unifiedTaskPause => 'Pause';

  @override
  String get unifiedTaskClearTask => 'Clear task';

  @override
  String get unifiedTaskContinue => 'Continue';

  @override
  String get unifiedTaskRemoveFromList => 'Remove from list';

  @override
  String get unifiedTaskSynthesisText => 'Synthesized text';

  @override
  String get unifiedTaskStatus => 'Status';

  @override
  String get unifiedTaskDetails => 'Details';

  @override
  String get unifiedTaskSynthesisError => 'Synthesis error details';

  @override
  String get unifiedTaskClose => 'Close';

  @override
  String get unifiedTaskRawRequestResponse => 'Raw request and response';

  @override
  String get unifiedTaskRawRequestBody => 'Raw request body:';

  @override
  String get unifiedTaskRawResponseBody => 'Raw response body:';

  @override
  String get commonJustNow => 'Just now';

  @override
  String commonMinutesAgo(Object count) {
    return '$count min ago';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count hr ago';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds sec';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds sec';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String get unifiedTaskTypeOcr => 'Image text recognition';

  @override
  String get unifiedTaskTypeAsr => 'Audio transcription';

  @override
  String get unifiedTaskTypeAudioSeparation => 'Audio separation';

  @override
  String get unifiedTaskTypeChat => 'Assistant chat';

  @override
  String get unifiedTaskPlayAudio => 'Play audio';

  @override
  String get unifiedTaskPauseAudio => 'Pause audio';

  @override
  String get catcatchFlowActionNotStarted =>
      'Flow action did not start. Check the flow status and try again.';

  @override
  String catcatchFlowActionFailed(Object error) {
    return 'Flow action failed: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      'Automatic page scanning timed out. Sign in or configure a user script on this page; after media is detected, choose Continue flow.';

  @override
  String get browserRecoveryContinue => 'Continue flow';

  @override
  String get catcatchSkipped => 'Skipped (nothing to process)';

  @override
  String get catcatchRetryStep => 'Retry this step';

  @override
  String catcatchCollapseSegments(Object count) {
    return 'Hide $count segments';
  }

  @override
  String catcatchShowSegments(Object count) {
    return 'Show $count segments';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '$selected of $total resources selected';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '$count media resources detected';
  }

  @override
  String get catcatchFlowSelectOrCombine =>
      '(select one resource or combine an audio/video pair)';

  @override
  String get catcatchSelectMultiple => '(tap to select; multiple allowed)';

  @override
  String get catcatchWaitingForResources => 'Waiting for flow resources';

  @override
  String catcatchDownloadSelected(Object count) {
    return 'Download $count selected resources';
  }

  @override
  String get catcatchSelectResources => 'Select resources to download';

  @override
  String get catcatchPossibleSplit =>
      '⚠ Possible separate audio and video streams';

  @override
  String get catcatchSplitExplanation =>
      'These resources may be separate audio and video streams for the same video. You can combine them or download only one stream.';

  @override
  String get catcatchAudioStream => '🎵 Audio stream';

  @override
  String get catcatchVideoStream => '🎬 Video stream';

  @override
  String get catcatchMergeAudioVideo => 'Combine audio and video';

  @override
  String get catcatchVideoOnly => 'Video only';

  @override
  String get catcatchAudioOnly => 'Audio only';

  @override
  String get catcatchSegmentsPlaylistPreview =>
      'Preview segments using the playlist';

  @override
  String get catcatchPreviewAudio => 'Preview audio';

  @override
  String get catcatchPreviewVideo => 'Preview video';

  @override
  String catcatchDuration(Object duration) {
    return 'Duration: $duration';
  }

  @override
  String get catcatchSegment => 'Segment';

  @override
  String get catcatchPlaylist => 'Playlist';

  @override
  String get catcatchFullVideo => 'Full video';

  @override
  String get catcatchSeparateTracks => 'Separate tracks';

  @override
  String get catcatchPreviewPlaylistOnly => 'Preview using the playlist';

  @override
  String get catcatchPreviewUnsupported => 'Preview is not supported';

  @override
  String get catcatchUnknownFormat => 'Unknown format';

  @override
  String get catcatchNeedPlaylistProcessing => 'Playlist processing required';

  @override
  String get catcatchSpecialFormatDetected => 'Special format detected';

  @override
  String catcatchPlaylistInfo(Object format) {
    return 'This resource is a playlist ($format). It must be parsed and all segments downloaded and combined into a playable video.';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return 'The downloaded file is in $format, not standard MP4. The built-in pure Dart remux engine will convert it to MP4 (TS/FLV/EV1 require no external dependencies).';
  }

  @override
  String get catcatchContinueBeforeConfirm =>
      'Resume the flow before confirming format handling';

  @override
  String get catcatchAutoProcess => 'Process automatically';

  @override
  String get catcatchKeepOriginalFormat => 'Keep original format';

  @override
  String get catcatchResumeSupported => 'Resume supported';

  @override
  String get catcatchResumeUnsupported => 'This site does not support resuming';

  @override
  String get catcatchPauseDownload => 'Pause download';

  @override
  String get catcatchResumeDownload => 'Resume download';

  @override
  String get catcatchRestartDownload => 'Download again';

  @override
  String get catcatchPendingFormatAction => 'Waiting for flow resources';

  @override
  String get quitDialogTitle => 'Quit app?';

  @override
  String quitDialogRunningTasks(Object count) {
    return '$count tasks are running. Quitting will interrupt them. Do you want to quit?';
  }

  @override
  String get quitDialogNoTasks => 'Do you want to quit Stroom?';

  @override
  String get quitDialogCancel => 'Cancel';

  @override
  String get quitDialogExit => 'Quit';

  @override
  String get searchPanelNewConversation => 'New conversation';

  @override
  String get searchPanelTitle => 'Search conversations';

  @override
  String get searchPanelHint => 'Enter a keyword...';

  @override
  String get searchPanelByTitle => 'Search titles';

  @override
  String get searchPanelByContent => 'Search content';

  @override
  String searchPanelResults(Object count) {
    return '$count results';
  }

  @override
  String get searchPanelPrompt => 'Enter a keyword to search';

  @override
  String get searchPanelNoResults => 'No matching conversations found';

  @override
  String get topicItemNew => 'New topic';

  @override
  String get topicItemUnpin => 'Unpin';

  @override
  String get topicItemPin => 'Pin';

  @override
  String get topicItemRename => 'Rename';

  @override
  String get topicItemAutoName => 'Auto name';

  @override
  String get topicItemDelete => 'Delete';

  @override
  String get galleryChoiceTitle => 'Choose an image source';

  @override
  String get galleryChoiceDevice => 'Device gallery';

  @override
  String get galleryChoiceDeviceDescription =>
      'Browse photos and videos on your device';

  @override
  String get galleryChoiceApp => 'App gallery';

  @override
  String get galleryChoiceAppDescription => 'Choose from the app gallery';

  @override
  String get appMediaUnreadable => 'Could not read file';

  @override
  String appMediaClearSelection(Object count) {
    return 'Clear ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return 'Done ($count)';
  }

  @override
  String get appMediaConfirmSelection => 'Done';

  @override
  String get appMediaEmptyFolder => 'This folder is empty';

  @override
  String get appMediaRoot => 'Go to root folder';

  @override
  String appMediaParentFolder(Object name) {
    return 'Back: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '$count files selected';
  }

  @override
  String get chatAlbumPickerTitle => 'App album';

  @override
  String get chatAlbumPickerEmpty => 'No images available';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images selected',
      one: '$count image selected',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => 'Choose files';

  @override
  String get chatFilePickerTabText => 'Text';

  @override
  String get chatFilePickerTabImages => 'Images';

  @override
  String get chatFilePickerTabVideos => 'Videos';

  @override
  String get chatFilePickerTabAudio => 'Audio';

  @override
  String get chatFilePickerEmpty => 'No files available';

  @override
  String get chatFilePickerLoadFailed => 'Could not load files';

  @override
  String get chatVideoPickerTitle => 'Choose app videos';

  @override
  String get chatVideoPickerEmpty => 'No videos available';

  @override
  String get imagePreviewCrop => 'Crop';

  @override
  String get imagePreviewEdit => 'Edit';

  @override
  String get imagePreviewLoadFailed => 'Could not load image';

  @override
  String runningElapsed(Object elapsed) {
    return 'Running for $elapsed';
  }

  @override
  String get chatAttachmentFile => 'Attach file';

  @override
  String get chatAttachmentCamera => 'Take photo';

  @override
  String get chatAttachmentDeviceGallery => 'Device gallery';

  @override
  String get chatAttachmentDeviceFiles => 'Device files';

  @override
  String get chatAttachmentAppFiles => 'App files';

  @override
  String fileManagerTodayTime(Object time) {
    return 'Today $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return 'Yesterday $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days days ago $time';
  }

  @override
  String get markdownGenerating => 'Generating...';

  @override
  String get htmlPreview => 'Preview';

  @override
  String get htmlReturnToCard => 'Return to card';

  @override
  String get htmlGenerating => 'Generating...';

  @override
  String get htmlFullscreen => 'View fullscreen';

  @override
  String get htmlViewCode => 'View code';

  @override
  String get codeScrollToBottom => 'Scroll to bottom';

  @override
  String get codeSave => 'Save';

  @override
  String get codeDisableWrap => 'Disable wrapping';

  @override
  String get codeEnableWrap => 'Wrap lines';

  @override
  String codeCopyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get codeCopied => 'Copied';

  @override
  String get codeCopy => 'Copy';

  @override
  String get codeEmptySave => 'Code is empty and cannot be saved';

  @override
  String get codeSaveTitle => 'Save code';

  @override
  String codeSavedTo(Object path) {
    return 'Saved to: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get fileManagerCopy => 'Copy';

  @override
  String get fileManagerMove => 'Move';

  @override
  String get fileManagerRename => 'Rename';

  @override
  String get fileManagerExport => 'Export';

  @override
  String get fileManagerDelete => 'Delete';

  @override
  String get fileManagerAncestorFolders => 'Ancestor folders';

  @override
  String get fileManagerRoot => 'Root';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$count selected';
  }

  @override
  String get fileManagerSelectAll => 'Select all';

  @override
  String get fileManagerRenameUndo => 'Last batch rename result and undo';

  @override
  String fileManagerSortBy(Object field) {
    return 'Sort ($field)';
  }

  @override
  String get fileManagerSortCreated => 'Sort by created date';

  @override
  String get fileManagerSortModified => 'Sort by modified date';

  @override
  String get fileManagerSortName => 'Sort by name';

  @override
  String get fileManagerSortSize => 'Sort by size';

  @override
  String get fileManagerListView => 'List view';

  @override
  String get fileManagerThumbnailView => 'Thumbnail view';

  @override
  String get fileManagerCreateFolder => 'Create folder';

  @override
  String get fileManagerRefresh => 'Refresh list';

  @override
  String get fileManagerEmptyFolder => 'This folder is empty';

  @override
  String get fileManagerNoFiles => 'No files';

  @override
  String get fileManagerBackRoot => 'Back to root';

  @override
  String fileManagerBackFolder(Object name) {
    return 'Back: $name';
  }

  @override
  String get fileManagerMultiSelect => 'Select multiple';

  @override
  String get fileManagerOpen => 'Open';

  @override
  String get fileManagerPreview => 'Preview';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '$files files, $folders subfolders';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '$count subfolders';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '$count files';
  }

  @override
  String get fileManagerEmptyFolderLabel => 'Empty folder';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return 'File “$name.$format” already exists';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return 'Rename failed: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => 'Choose a destination folder';

  @override
  String get fileManagerAlreadyAtDestination =>
      'The file is already at the destination';

  @override
  String get fileManagerMoveNameConflict =>
      'A file with the same name already exists in the destination. Move canceled.';

  @override
  String fileManagerMoveFailed(Object error) {
    return 'Move failed: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => 'Choose a folder to copy to';

  @override
  String fileManagerCopyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => 'Confirm deletion';

  @override
  String get fileManagerDeleteFileConfirm =>
      'Delete this file? This action cannot be undone.';

  @override
  String get fileManagerCancel => 'Cancel';

  @override
  String fileManagerDeleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere =>
      'The folder is already at the destination. Operation canceled.';

  @override
  String get fileManagerFolderConflict =>
      'A folder with the same name exists at the destination, or the destination is inside the selected folder. Operation canceled.';

  @override
  String get fileManagerBatchDeleteTitle => 'Confirm bulk deletion';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return 'Delete the $count selected items? This action cannot be undone.';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return 'Bulk delete failed: $error';
  }

  @override
  String get fileManagerExportConflict =>
      'Export paths for the selected files and folders conflict';

  @override
  String get fileManagerSelectedAlreadyThere =>
      'The selected file is already at the destination. Move canceled.';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return 'Bulk move failed: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      'The selection contains files with duplicate names. Copy canceled; copy them one at a time.';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return 'Bulk copy failed: $error';
  }

  @override
  String get fileManagerClosedError => 'The file page is closed';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return 'Bulk rename failed: $error';
  }

  @override
  String get fileManagerFolderNameHint => 'Enter a folder name';

  @override
  String get fileManagerCreate => 'Create';

  @override
  String get fileManagerFolderExists => 'Folder already exists';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return 'Could not create folder: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return 'Folder “$name” created';
  }

  @override
  String get fileManagerRenameFolderTitle => 'Rename folder';

  @override
  String get fileManagerNewNameHint => 'Enter a new name';

  @override
  String get fileManagerTargetFolderConflict =>
      'A folder with the same name already exists at the destination. Operation canceled.';

  @override
  String get fileManagerMoveFolderTitle => 'Move folder to…';

  @override
  String get fileManagerCopyFolderTitle => 'Copy folder to…';

  @override
  String get fileManagerFolderSelfConflict =>
      'A folder with the same name exists at the destination, or the destination is the folder itself. Operation canceled.';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return 'Delete folder “$name”? Its $count files will also be deleted.';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return 'Delete empty folder “$name”?';
  }

  @override
  String get fileManagerDeleteFolderTitle => 'Confirm folder deletion';

  @override
  String fileManagerRefreshFailed(Object error) {
    return 'Refresh failed: $error';
  }

  @override
  String get fileManagerRefreshed => 'File list refreshed';

  @override
  String get fileManagerRenameFileTitle => 'Rename file';

  @override
  String get fileManagerFormat => 'Format';

  @override
  String get fileManagerFolderAtDestination =>
      'Folder is already at the destination';

  @override
  String get folderPickerTitle => 'Choose folder';

  @override
  String get folderPickerExists => 'Folder already exists';

  @override
  String folderPickerCreateFailed(Object error) {
    return 'Could not create folder: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return 'Could not refresh folder list: $error';
  }

  @override
  String get folderPickerInstruction =>
      'Click to select; double-click to open a folder';

  @override
  String get folderPickerFileName => 'File name';

  @override
  String get folderPickerFileNameHint => 'Enter a file name';

  @override
  String get folderPickerBack => 'Go up one level';

  @override
  String folderPickerPath(Object path) {
    return 'Root > $path';
  }

  @override
  String get folderPickerRoot => 'Root';

  @override
  String get folderPickerCurrentFolder => 'Current folder';

  @override
  String get folderPickerSubfolders => 'Subfolders';

  @override
  String get folderPickerExistingFolders => 'Existing folders';

  @override
  String get folderPickerCreateNew => 'Create new folder';

  @override
  String get folderPickerFolderNameHint => 'Enter a folder name';

  @override
  String get folderPickerCancelCreate => 'Cancel creation';

  @override
  String get folderPickerCancel => 'Cancel';

  @override
  String get folderPickerConfirm => 'Done';

  @override
  String batchRunReadFailed(Object error) {
    return 'Could not read file list: $error';
  }

  @override
  String get batchRunPreparing => 'Preparing…';

  @override
  String get batchRunUndo => 'Undo';

  @override
  String get batchRunRename => 'Rename';

  @override
  String batchRunFailedAction(Object label) {
    return 'Could not $label';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label $count items';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed succeeded, $failed failed, $remaining remaining';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return 'Failed: $id → $name';
  }

  @override
  String get batchRunReportCopied => 'Execution report copied';

  @override
  String get batchRunCopyFailed => 'Copy failed. Try again.';

  @override
  String batchRunWorking(Object label) {
    return '$label…';
  }

  @override
  String get batchRunTitle => 'Batch rename results';

  @override
  String get batchRunStoppedRetain =>
      'Stopping keeps completed items. You can undo them on the results page.';

  @override
  String get batchRunFailedRemaining =>
      'Failed; remaining items were not processed';

  @override
  String get batchRunUndoInfo =>
      'Undo restores the original names for items completed in this run. Undo is refused if the file list has changed since.';

  @override
  String get batchRunUncertain =>
      'Some item states could not be confirmed. Check the file list; automatic undo is unavailable to avoid overwriting files.';

  @override
  String get batchRunUndoing => 'Restoring original names…';

  @override
  String get batchRunStopping => 'Stopping…';

  @override
  String get batchRunStopRemaining => 'Stop remaining items';

  @override
  String get batchRunCopyReport => 'Copy report';

  @override
  String batchRunUndoRemaining(Object count) {
    return 'Continue undoing the remaining $count';
  }

  @override
  String get batchRunUndoCompleted => 'Undo completed renames';

  @override
  String get batchRunDone => 'Done';

  @override
  String get codeEditorTitle => 'Edit parameter value';

  @override
  String get codeEditorFormat => 'Format';

  @override
  String get codeEditorCancel => 'Cancel';

  @override
  String get codeEditorConfirm => 'OK';

  @override
  String get codeEditorInvalidJson => 'Invalid JSON. Fix it before saving.';

  @override
  String get codeEditorParamPath =>
      'Parameter name path (expanded into nested JSON when sent)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return 'Line $line, column $column: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON format error: $message';
  }

  @override
  String get codeEditorInvalidFormat => 'Invalid JSON format';

  @override
  String get toolCallCompacted => 'Compacted';

  @override
  String get mermaidSaveEmpty => 'Mermaid code is empty. Nothing to save.';

  @override
  String mermaidFolderLoadFailed(String error) {
    return 'Could not load folders: $error';
  }

  @override
  String get mermaidSaveTitle => 'Save Mermaid diagram';

  @override
  String get mermaidSaveHint => 'Choose or create a folder for the .mmd file';

  @override
  String get mermaidSaveFilenameHint =>
      'Enter a file name (.mmd is added automatically)';

  @override
  String get mermaidFilenameEmpty => 'File name cannot be empty';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return 'Saved to text storage: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get mermaidPrepareEngine => 'Preparing rendering engine...';

  @override
  String get mermaidRetry => 'Retry';

  @override
  String get batchRuleEmpty => 'Cannot be empty';

  @override
  String get batchRuleNumber => 'Enter a number';

  @override
  String get batchRulePositive => 'Enter a number greater than 0';

  @override
  String batchRuleMin(String min) {
    return 'Must be at least $min';
  }

  @override
  String batchRuleMax(String max) {
    return 'Must be no greater than $max';
  }

  @override
  String get batchRulePrefix => 'Prefix';

  @override
  String get batchRuleSuffix => 'Suffix';

  @override
  String get batchRuleStart => 'Start';

  @override
  String get batchRuleStep => 'Step';

  @override
  String get batchRuleDigits => 'Digits';

  @override
  String get batchRuleSeparator => 'Separator';

  @override
  String get batchRuleRestartFolder => 'Restart numbering in each folder';

  @override
  String get batchRuleNumberHelp =>
      'Numbers follow preview order; excluded items do not use a number. Step can be negative or 0.';

  @override
  String get batchRuleFind => 'Find';

  @override
  String get batchRuleReplace => 'Replace with (leave empty to delete)';

  @override
  String get batchRuleCaseSensitive => 'Case sensitive';

  @override
  String get batchRuleRegex => 'Regular expression';

  @override
  String get batchRuleFirstOnly => 'Replace first match only';

  @override
  String get batchRuleRegexHelp =>
      'Capture groups: \$1, \$2; full match: \$0; literal \$: \$\$. Example: ^IMG_(\\d+)\$ → Photo_\$1';

  @override
  String get batchRuleFindRequired => 'Enter text to find to enable this rule.';

  @override
  String get batchRuleBeginning => 'Beginning';

  @override
  String get batchRuleEnd => 'End';

  @override
  String get batchRulePosition => 'Position';

  @override
  String get batchRuleInsertText => 'Text to insert';

  @override
  String get batchRuleBeforeChar => 'Before character N';

  @override
  String get batchRulePositionHelp =>
      'Positions start at 1; values beyond the end are appended. Combined emoji count as one character.';

  @override
  String get batchRuleFromBeginning => 'From beginning';

  @override
  String get batchRuleFromEnd => 'From end';

  @override
  String get batchRuleFromChar => 'Starting at character N';

  @override
  String get batchRuleCount => 'Count';

  @override
  String get batchRuleDeleteHelp =>
      'If deletion empties the name, a later insert rule must add text before execution.';

  @override
  String get batchRuleUpper => 'UPPERCASE';

  @override
  String get batchRuleLower => 'lowercase';

  @override
  String get batchRuleFirstUpper => 'Capitalize first letter';

  @override
  String get batchRuleTitleCase => 'Capitalize Each Word';

  @override
  String get batchRuleTemplate => 'New name template';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return 'Course_${n}_$name';
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
    return '$name original name · $n sequence · $folder folder name\n$created creation date · $modified modified date · $ext original extension\nDate format YYYY-MM-DD; missing dates are reported. The template replaces the whole base name; the extension is kept automatically.';
  }

  @override
  String get batchRuleTrim => 'Trim leading and trailing spaces';

  @override
  String get batchRuleCollapseSpaces =>
      'Replace consecutive spaces with one space';

  @override
  String get batchRuleActions => 'Rule actions';

  @override
  String get batchRuleDuplicate => 'Duplicate rule';

  @override
  String get batchRuleRemove => 'Delete rule';

  @override
  String get batchRuleMoveUp => 'Move rule up';

  @override
  String get batchRuleMoveDown => 'Move rule down';

  @override
  String get batchDlgSavePreset => 'Save preset';

  @override
  String get batchDlgPresetName => 'Preset name';

  @override
  String get batchDlgPresetHint =>
      'Saves rules and order, but not exclusions or manual names';

  @override
  String get batchDlgCancel => 'Cancel';

  @override
  String get batchDlgSave => 'Save';

  @override
  String get batchDlgOverwriteTitle => 'Overwrite existing preset?';

  @override
  String batchDlgOverwriteBody(String name) {
    return 'Update the rules in “$name”.';
  }

  @override
  String get batchDlgOverwrite => 'Overwrite';

  @override
  String get batchDlgManagePresets => 'Manage presets';

  @override
  String get batchDlgNoPresets => 'No saved presets';

  @override
  String get batchDlgDeletePreset => 'Delete preset';

  @override
  String get batchDlgDone => 'Done';

  @override
  String get batchDlgEditName => 'Edit name individually';

  @override
  String get batchDlgBaseName => 'Base name';

  @override
  String get batchDlgOverrideHelp => 'This name overrides the rule result';

  @override
  String batchDlgExtensionRetained(String extension) {
    return 'Extension .$extension is kept automatically';
  }

  @override
  String get batchDlgConfirm => 'Confirm';

  @override
  String get batchDlgHelp => 'Instructions';

  @override
  String get batchDlgClose => 'Close';

  @override
  String get batchDlgLoadPreset =>
      'Load preset (replaces rules and clears manual names)';

  @override
  String get batchDlgLoad => 'Load preset';

  @override
  String get batchDlgSaving => 'Saving…';

  @override
  String get batchDlgReset => 'Reset all rules and included items';

  @override
  String get batchDlgRuleInstructions =>
      'Rules run from top to bottom. Copy, move, or disable them. File extensions stay unchanged.';

  @override
  String get batchDlgSortName => 'Name';

  @override
  String get batchDlgSortCreated => 'Created';

  @override
  String get batchDlgSortModified => 'Modified';

  @override
  String get batchDlgSortSize => 'Size';

  @override
  String get batchDlgAscending => 'Ascending';

  @override
  String get batchDlgDescending => 'Descending';

  @override
  String get batchDlgFolderSort =>
      'Folders come first; same names are sorted by folder.';

  @override
  String get batchDlgAddRule => '＋ Add rule';

  @override
  String get batchDlgMaxRules => 'Maximum 50 rules';

  @override
  String get batchDlgPreviewWorking =>
      'Calculating preview… You can keep editing rules or cancel.';

  @override
  String get batchDlgSearch => 'Search original name, new name, or folder';

  @override
  String get batchDlgFilterAll => 'All';

  @override
  String get batchDlgFilterChanged => 'Changed';

  @override
  String get batchDlgFilterErrors => 'Issues';

  @override
  String get batchDlgFilterUnchanged => 'Unchanged';

  @override
  String get batchDlgFilterExcluded => 'Excluded';

  @override
  String get batchDlgParticipants => 'Choose included items';

  @override
  String get batchDlgIncludeAll => 'Include all';

  @override
  String get batchDlgOnlyFiles => 'Files only';

  @override
  String get batchDlgOnlyFolders => 'Folders only';

  @override
  String get batchDlgExcludeAll => 'Exclude all';

  @override
  String get batchDlgScope => 'Included items';

  @override
  String get batchDlgCopyList => 'Copy list';

  @override
  String get batchDlgConflictBlock => 'Name conflict: block execution';

  @override
  String get batchDlgConflictSuffix => 'Name conflict: append (2), (3)…';

  @override
  String get batchDlgNoMatches => 'No items match the filter';

  @override
  String get batchDlgRoot => 'Root';

  @override
  String get batchDlgFile => 'File';

  @override
  String get batchDlgFolder => 'Folder';

  @override
  String batchDlgTargetFolder(String folder) {
    return 'Target folder: $folder';
  }

  @override
  String get batchDlgEditNameTooltip => 'Edit name individually';

  @override
  String get batchDlgRestoreNameTooltip => 'Restore rule-generated name';

  @override
  String get batchDlgCopied => 'Full preview list copied (CSV)';

  @override
  String get batchDlgCopyFailed => 'Copy failed. Try again.';

  @override
  String get batchDlgHelpTitle => 'Batch rename instructions';

  @override
  String get batchDlgHelpDismiss => 'Got it';

  @override
  String get batchDlgRulesTab => 'Rules';

  @override
  String batchDlgPreviewTab(String count) {
    return 'Preview ($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return 'Rename $count items';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      'Could not load presets. You can still edit and run rules.';

  @override
  String get batchDlgPreviewFailed =>
      'Could not calculate preview. Adjust the rules and try again.';

  @override
  String batchDlgSavedName(String name) {
    return 'Preset saved: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String batchDlgDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get batchDlgSavePresetFallback => 'Save preset';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return 'Preview · $changes changes · $conflicts issues · $excluded excluded';
  }

  @override
  String get batchDlgInvalidInput =>
      'Fix invalid rule inputs. The preview does not include them yet.';

  @override
  String get batchDlgConflictError =>
      'Conflicts or invalid names prevent applying. Adjust the rules.';

  @override
  String get batchDlgManualNameStatus => 'Manual name';

  @override
  String get batchDlgPendingRename => 'Ready to rename';

  @override
  String get batchDlgCsvHeader =>
      'Original path,Original name,Target path,Status';

  @override
  String get batchDlgHelpBody =>
      '1. Choose a preset or enable rules, then copy rules and adjust their order as needed.\n\n2. The preview shows the names that will be used. Search and filters affect display only. Unchecking an item excludes it and recalculates numbering. Edit a name individually or restore the rule result.\n\n3. Resolve all issues before running. Automatic suffixes handle duplicate names without overwriting files. Rename folders that exchange names in separate batches.\n\n4. You can stop later items during execution; the current item finishes first. The results page shows completed changes and lets you undo them. Undo is blocked if the list has changed since execution.\n\nThis changes names and folder paths only; file contents and extensions stay unchanged. Renaming a parent folder does not prevent checked children from being renamed, and renaming a parent moves its children with it.';

  @override
  String batchDlgPreviewCount(String count) {
    return 'Preview ($count)';
  }

  @override
  String get batchBuiltinPhoto => 'Photos: date and number';

  @override
  String get batchBuiltinCourse => 'Courses: consistent name and number';

  @override
  String get batchBuiltinDownloads => 'Downloads: clean whitespace';

  @override
  String get taskListDetail => 'Details';

  @override
  String get taskListOwnershipChecking => 'Confirming task ownership';

  @override
  String get taskListOwnershipFailed =>
      'Could not read task flow record; actions are unavailable';

  @override
  String get taskListViewFlow => 'View task flow';

  @override
  String get taskListPause => 'Pause';

  @override
  String get taskListClear => 'Clear task';

  @override
  String get taskListResume => 'Resume';

  @override
  String get taskListRetry => 'Retry';

  @override
  String get taskListDismissError => 'Dismiss error';

  @override
  String get taskListRemove => 'Remove from list';

  @override
  String get taskListSynthesisErrorTitle => 'Synthesis error details';

  @override
  String get taskListClose => 'Close';

  @override
  String get taskListOriginalExchange => 'Original request and response';

  @override
  String get taskListOriginalRequest => 'Original request body:';

  @override
  String get taskListOriginalResponse => 'Original response body:';

  @override
  String get taskFlowIoTypeText => 'Text';

  @override
  String get taskFlowIoTypeAudio => 'Audio';

  @override
  String get taskFlowIoTypeVideo => 'Video';

  @override
  String get taskFlowIoTypeImage => 'Image';

  @override
  String get taskFlowIoTypeLink => 'Link';

  @override
  String get taskFlowIoTypeFile => 'File';

  @override
  String get taskFlowIoTypeAny => 'Any';

  @override
  String get mermaidZoomOut => 'Zoom out';

  @override
  String get mermaidZoomIn => 'Zoom in';

  @override
  String get mermaidFullscreen => 'Fullscreen';

  @override
  String get mermaidSaveButton => 'Save';

  @override
  String get mermaidSourceButton => 'View source';

  @override
  String get mermaidDiagramSemantic => 'View diagram';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'Could not save CatCatch child task deletion state. Try again.';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      'Could not save synthesis child task deletion state. Try again.';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      'Could not save background child task deletion state. Try again.';

  @override
  String get mathParseError => 'Math parse error';

  @override
  String get mermaidEmptyPlaceholder => 'No Mermaid code to render';

  @override
  String get mathClose => 'Close';

  @override
  String get mermaidLoadTimeout =>
      'Mermaid loading timed out. Check your network and try again.';

  @override
  String get mermaidCdnLoadFailed =>
      'Could not reach cdn.jsdelivr.net to load Mermaid.';

  @override
  String get mermaidLoadingDiagram => 'Loading diagram…';

  @override
  String get mermaidEngineInitFailed =>
      'Could not initialize the diagram renderer. Try again.';

  @override
  String get mermaidPageTimeout => 'Page load timed out. Try again.';

  @override
  String get mermaidCodeLoadFailed => 'Could not load diagram code. Try again.';

  @override
  String mermaidPageLoadFailed(String description) {
    return 'Page load failed: $description';
  }

  @override
  String get mermaidLoadingEngine => 'Loading rendering engine…';

  @override
  String get mermaidRenderErrorTitle => 'Diagram rendering error';

  @override
  String get taskFlowOutputVideoAudioDownstream =>
      'Video or audio (filtered by downstream)';

  @override
  String get taskFlowOutputUnknown => 'Unknown';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label stopped: $completed succeeded, $failed failed, $remaining remaining';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Mermaid render error: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Mermaid initialization error: $message';
  }

  @override
  String get mermaidResourceError =>
      'A resource in the Mermaid diagram failed to load.';

  @override
  String get taskFlowParamRecognitionModel => 'Recognition model';

  @override
  String get taskFlowParamSynthesisModel => 'Synthesis model';

  @override
  String get taskFlowParamSaveFolder => 'Save folder';

  @override
  String get taskFlowParamResourceSelection => 'Resource selection';

  @override
  String get taskFlowParamOutputType => 'Output type';

  @override
  String get taskFlowParamVideoFolder => 'Video save folder';

  @override
  String get taskFlowParamAudioFolder => 'Audio save folder';

  @override
  String get taskFlowParamExpectedDuration => 'Expected duration';

  @override
  String get taskFlowParamVoice => 'Voice';

  @override
  String get taskFlowParamSpeechRate => 'Speech rate';

  @override
  String get taskFlowParamAssistant => 'Assistant';

  @override
  String get taskFlowHintResourceSelection =>
      'Manual mode lets you choose. Automatic mode follows the existing rules. Ask when ambiguous selects automatically only when there is one safe choice; otherwise it opens the resource list for confirmation.';

  @override
  String get taskFlowHintOutputType =>
      'Choose video or audio explicitly. Follow downstream filters resources by the next block’s input type. If the next block accepts both types or there is no next block, both types are kept.';

  @override
  String get taskFlowHintExpectedDuration =>
      'Filter resources by video duration. Leave blank to skip filtering.';

  @override
  String get taskFlowHintVoice =>
      'Choose a voice. The matching synthesis model is selected automatically.';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      'This block type is no longer supported. Replace it or remove this step.';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return 'The next block requires $requiredType. The downloader can output video or audio. Change the next step or output policy.';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source has any type, but “$block” needs an explicit text, link, image, audio, video, or file type. Change the input type, move or replace the block, or undo the change.';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source has $actualType, but “$block” requires $requiredType. Change the input type, move or replace the block, or undo the change.';
  }

  @override
  String get fileManagerSortFieldCreated => 'Created date';

  @override
  String get fileManagerSortFieldModified => 'Modified date';

  @override
  String get fileManagerSortFieldName => 'Name';

  @override
  String get fileManagerSortFieldSize => 'Size';

  @override
  String get fileManagerSortDateNewest => 'newest first';

  @override
  String get fileManagerSortDateOldest => 'oldest first';

  @override
  String get fileManagerSortSizeLargest => 'largest first';

  @override
  String get fileManagerSortSizeSmallest => 'smallest first';

  @override
  String get catcatchStatusRunning => 'Running';

  @override
  String get catcatchStatusCompleted => 'Completed';

  @override
  String get catcatchStatusFailed => 'Failed';

  @override
  String get catcatchStatusPaused => 'Paused';

  @override
  String get catcatchStatusWaiting => 'Waiting';

  @override
  String get catcatchStepFetching => 'Fetching webpage';

  @override
  String get catcatchStepAnalyzing => 'Analyzing media';

  @override
  String get catcatchStepParsingPlaylist => 'Parsing playlist';

  @override
  String get catcatchStepFiltering => 'Filtering by duration';

  @override
  String get catcatchStepUserSelecting => 'Waiting for selection';

  @override
  String get catcatchStepDownloading => 'Downloading';

  @override
  String get catcatchStepConverting => 'Converting/merging';

  @override
  String get catcatchStepSaving => 'Saving locally';

  @override
  String get bgStepConnectServer => 'Connecting to server';

  @override
  String get bgStepUploadImage => 'Uploading images';

  @override
  String get bgStepWaitRecognition => 'Waiting for recognition';

  @override
  String get bgStepParseResult => 'Parsing result';

  @override
  String get bgStepSaveFile => 'Saving file';

  @override
  String get bgStepUploadAudio => 'Uploading audio';

  @override
  String get bgStepTranscribing => 'Transcribing';

  @override
  String get bgStepReceiveResult => 'Receiving result';

  @override
  String get bgStepSeparateAudio => 'Separating audio';

  @override
  String get bgStepSaveToFile => 'Saving to file';

  @override
  String get bgStepSendRequest => 'Sending request';

  @override
  String get bgStepWaitReply => 'Waiting for reply';

  @override
  String get fileManagerSortNameAscending => 'A to Z';

  @override
  String get fileManagerSortNameDescending => 'Z to A';

  @override
  String get taskFlowValidationNoSteps =>
      'This task flow has no steps. Add a block first.';

  @override
  String get taskFlowValidationInputRequired =>
      'Add at least one input to run this task flow.';

  @override
  String get taskFlowValidationFlowRemoved =>
      'This task flow was deleted. Select it again.';

  @override
  String get taskFlowValidationInputTypeChanged =>
      'The initial input type changed. Choose the run input again.';

  @override
  String get taskFlowValidationSnapshotMissing =>
      'This older record has no run snapshot. Retry using the latest configuration.';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      'The assistant model is missing or unavailable. Select a model on the chat page or set a default model for the assistant.';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      'A saved step file is missing, empty, or unreadable. Run the task flow again.';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      'This block type is no longer supported. Replace or remove this step.';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return 'The next block requires $requiredType. The downloader can output audio or video. Change the next step or output policy.';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '“$parameter” is required for “$block”. Configure it in the block settings.';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return 'The legacy model selection needs confirmation. Choose the model again in “$block” settings.';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return 'The model is missing or unavailable from its provider. Choose it again in “$block” settings and check the provider URL and key.';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return 'The assistant is missing or was deleted. Choose it again in “$block” settings.';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      'The assistant model was deleted or its provider configuration is unavailable. Choose a model again in assistant settings.';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return 'The resource selection policy or output type is invalid. Choose it again in “$block” settings.';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return 'The output type is invalid. Choose it again in “$block” settings.';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return 'The resource selection policy is invalid. Choose it again in “$block” settings.';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return 'Input $index: The file is missing, empty, or unreadable. Choose it again.';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return 'Input $index: Enter a valid HTTP or HTTPS link.';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return 'Input $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules => 'At most 50 rules are allowed.';

  @override
  String get batchRuleValidationDigits =>
      'The number of digits must be from 1 to 12.';

  @override
  String get batchRuleValidationNumberRange =>
      'The starting number and step must be within ±999,999,999.';

  @override
  String get batchRuleValidationReplacementLength =>
      'The replacement rule is too long.';

  @override
  String get batchRuleValidationRegex => 'The regular expression is invalid.';

  @override
  String get batchRuleValidationDeleteIndex =>
      'The deletion position must start at 1.';

  @override
  String get batchRuleValidationInsertLength =>
      'The inserted text is too long.';

  @override
  String get batchRuleValidationTemplateNumber =>
      'Invalid template number settings: digits must be 1 to 12 and start/step within ±999,999,999.';

  @override
  String get batchRuleValidationTemplateLength => 'The template is too long.';

  @override
  String get batchRuleValidationTemplateVariable =>
      'Unknown template variable or an unclosed brace.';

  @override
  String get batchRuleTypeNumber => 'Add numbering';

  @override
  String get batchRuleTypeReplace => 'Find and replace';

  @override
  String get batchRuleTypeInsert => 'Insert text';

  @override
  String get batchRuleTypeDelete => 'Delete characters';

  @override
  String get batchRuleTypeCase => 'Change case';

  @override
  String get batchRuleTypeTemplate => 'Name template';

  @override
  String get batchRuleTypeCleanup => 'Clean whitespace';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return 'Input $index: Enter text or choose a file.';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return 'Input $index: The image is over 20 MB. Choose a smaller image.';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return 'Input $index: The attachment is over 10 MB. Choose a smaller file.';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return 'Input $index: The file is $actualType, but $requiredType is required. Choose another file.';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return 'Input $index: Assistant chat does not support SVG image attachments. Convert it to PNG or JPEG.';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return 'Input $index: Assistant chat does not support $mime image attachments. Convert it to PNG, JPEG, GIF, or WebP.';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return 'Input $index: Assistant chat does not support $mime audio attachments. Convert it to MP3, WAV, or M4A.';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return 'Input $index: This Anthropic chat format does not support $type attachments. Choose an assistant that supports this media.';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return 'Input $index: This Anthropic chat format supports only image and PDF attachments. Choose a supported file.';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return 'Input $index: Assistant chat could not compress the image below 10 MB. Choose a smaller image.';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return 'Input $index: The text attachment is not valid UTF-8. Convert it and try again.';
  }

  @override
  String get assistantParamValueTypeString => 'String';

  @override
  String get assistantParamValueTypeNumber => 'Number';

  @override
  String get assistantParamValueTypeBoolean => 'Boolean';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields =>
      'Provider name, API URL, and key are required.';

  @override
  String get providerJsonSizePositive =>
      'Request JSON size must be a positive MiB value.';

  @override
  String get providerCustomParamRequired =>
      'Custom parameter name and value are required.';

  @override
  String providerParamNameInvalid(String name) {
    return 'Parameter name is invalid (dot-separated segments cannot be empty): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return 'Parameter already exists: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return 'Default value for parameter \"$name\" is not valid JSON: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return 'Numeric options for parameter \"$name\" cannot be empty.';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return 'Value for parameter \"$name\" is not a valid number: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      'Complete the reasoning toggle before enabling other reasoning parameters.';

  @override
  String providerReasoningError(String error) {
    return 'Reasoning parameter error: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return 'Reasoning and custom parameters have the same name: $name';
  }

  @override
  String get providerMaxTokensMissing =>
      'Maximum output tokens is enabled, but no value was entered.';

  @override
  String get providerMaxTokensPositive =>
      'Maximum output tokens must be a positive integer.';

  @override
  String get providerSeedInteger => 'Random seed must be an integer.';

  @override
  String get providerNotConfigured => 'Not set';

  @override
  String get providerAudioChunkingTitle => 'Audio chunking';

  @override
  String get providerAudioChunkingHint =>
      'Smart chunking analyzes the audio and candidate cuts, preferring sentence endings. Chunks do not overlap.';

  @override
  String get providerChunkingMode => 'Chunking method';

  @override
  String get providerChunkNone => 'No chunking';

  @override
  String get providerChunkSmart => 'Smart chunking (recommended)';

  @override
  String get providerChunkFixedDuration => 'Fixed-duration chunks';

  @override
  String get providerChunkFixedSize => 'Fixed-size chunks';

  @override
  String get providerCompressionTitle => 'Compression encoding';

  @override
  String get providerCompressionHint =>
      'When enabled, the general fallback first compresses the full WAV. If the encoded file or request body still exceeds the limit, the source PCM is chunked and encoded.';

  @override
  String get providerCompressionMode => 'Compression method';

  @override
  String get providerCompressionNone => 'None (send as is)';

  @override
  String get providerCompressionAdpcm => 'ADPCM (~4x compression)';

  @override
  String get providerCompressionFlac => 'FLAC (lossless, ~2x)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM, lossy 4:1 compression. Pure Dart implementation; audio quality suits transcription.';

  @override
  String get providerCompressionFlacDescription =>
      'Lossless FLAC compression, implemented in pure Dart. Reduces size by about half.';

  @override
  String get providerCompressionWavDescription =>
      'No compression; send as a WAV file.';

  @override
  String get providerLlmParams => 'LLM parameters';

  @override
  String get providerEnabledParamsHelp =>
      'Enabled parameters are sent as defaults in API requests.';

  @override
  String get providerTemperatureLabel => 'Temperature';

  @override
  String get providerTemperatureHelp =>
      'Controls output randomness; higher values are more creative.';

  @override
  String get providerTopPHelp =>
      'Nucleus sampling parameter that controls cumulative probability for word selection.';

  @override
  String get providerFrequencyPenaltyLabel => 'Frequency penalty';

  @override
  String get providerFrequencyPenaltyHelp =>
      'Reduces repeated words; negative values increase repetition.';

  @override
  String get providerPresencePenaltyLabel => 'Presence penalty';

  @override
  String get providerPresencePenaltyHelp =>
      'Encourages new topics; negative values encourage returning to previous topics.';

  @override
  String get providerMaxOutputTokensLabel => 'Maximum output tokens';

  @override
  String providerOptionalExample(String example) {
    return 'Optional, e.g. $example';
  }

  @override
  String get providerResponseTokensHelp =>
      'Maximum number of tokens generated per response.';

  @override
  String get providerSeedLabel => 'Random seed';

  @override
  String get providerSeedHelp => 'Set this to make output reproducible.';

  @override
  String get providerChunkSmartDescription =>
      'Analyzes audio and candidate cuts, preferring sentence endings or long silences without overlap. Defaults: 20s minimum / 45s target / 60s maximum. Used only by the general fallback; compression chunking supports PCM WAV only.';

  @override
  String get providerChunkDurationDescription =>
      'Splits every N seconds (60 by default). Simple, but may cut off speech. Used only by the general fallback; compression chunking supports PCM WAV only.';

  @override
  String get providerChunkSizeDescription =>
      'Initially splits by audio data size, then refines by encoded file and request body size. Used only by the general fallback; compression chunking supports PCM WAV only.';

  @override
  String get providerChunkNoneDescription =>
      'No chunking. The file is rejected if it exceeds the limit after full compression.';

  @override
  String get providerNameLabel => 'Provider name';

  @override
  String get providerNameHint => 'Enter provider name';

  @override
  String get providerApiUrlLabel => 'API URL';

  @override
  String get providerApiUrlHint => 'Enter the full API endpoint URL';

  @override
  String providerApiKeyHint(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get providerEndpointTypeLabel => 'Endpoint type';

  @override
  String get providerEndpointOpenAi => 'OpenAI compatible (Chat Completions)';

  @override
  String get providerEndpointAnthropic => 'Anthropic format (Messages API)';

  @override
  String get providerAnthropicEndpointHelp =>
      'Uses the official Anthropic Messages API format (x-api-key header). API URL example: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      'Uses the official OpenAI Chat Completions compatible format (Bearer header). API URL example: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => 'Default request JSON size';

  @override
  String get providerUseAppDefault => 'Leave empty to use the app default';

  @override
  String get providerModelJsonBudgetHelp =>
      'Models can override this value. If neither the provider nor model sets it, the default is 20 MiB.';

  @override
  String get providerRequestParamsHelp =>
      'Requests use all enabled provider and model parameters. When names overlap, the model value takes precedence.';

  @override
  String get providerUploadSettings => 'Upload settings';

  @override
  String get providerUploadMethodHelp =>
      'Audio upload methods and size limits vary by provider.';

  @override
  String get providerUploadMethod => 'Upload method';

  @override
  String get providerMultipart => 'Multipart (general)';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => 'Maximum upload size';

  @override
  String get providerFallbackStrategy => 'Fallback strategy';

  @override
  String get providerFallbackMethod => 'Fallback method';

  @override
  String get providerPreprocessing => 'Audio preprocessing';

  @override
  String get providerPreprocessingHelp =>
      'Reduces audio file size without affecting transcription accuracy.';

  @override
  String get providerPreprocessingMethod => 'Preprocessing method';

  @override
  String get providerUploadMultipartHelp =>
      'Direct multipart/form-data upload. The request body includes audio, form fields, and multipart boundaries.';

  @override
  String get providerUploadBase64Help =>
      'Sends Base64 in JSON, which can bypass some providers’ multipart-specific limits. Base64 expansion and JSON fields count toward the upload limit.';

  @override
  String get providerUploadUrlHelp =>
      'Provide a public URL for the provider to download. Supports very large files (e.g. Together AI 1 GB).';

  @override
  String get providerUploadBudgetHelp =>
      'This value triggers raw-audio fallback and limits the final request body. The app checks raw audio, encoded files, and upload size. Multipart includes form fields and boundaries; Base64 JSON includes encoding expansion and fields. The 25 MB default matches the OpenAI audio API limit.';

  @override
  String get providerFallbackTriggerHelp =>
      'Triggered when raw audio or the complete request body exceeds its limit. Specific fallback (Base64) takes priority over general fallback (compression/chunking).';

  @override
  String get providerFallbackNone => 'None (reject immediately)';

  @override
  String get providerFallbackSpecific => 'Specific fallback (Base64)';

  @override
  String get providerFallbackGeneric =>
      'General fallback (compression/chunking)';

  @override
  String get providerFallbackAll => 'Try all (recommended)';

  @override
  String get providerFallbackSpecificHelp =>
      'Try Base64 JSON. Send only if the request body, including Base64 expansion and JSON fields, fits the limit.';

  @override
  String get providerFallbackGenericHelp =>
      'If enabled, compress the full WAV first. If it still exceeds the limit and chunking is enabled, split the source PCM and encode each chunk. PCM WAV only.';

  @override
  String get providerFallbackAllHelp =>
      'Try Base64 within the request-body limit first. Then, if enabled, compress the full WAV; if it still exceeds the limit and chunking is enabled, split the source PCM and encode each chunk. PCM WAV only.';

  @override
  String get providerFallbackRejectHelp =>
      'Reject the file if it exceeds the limit; do not try a fallback.';

  @override
  String get providerPreprocessNone => 'None';

  @override
  String get providerPreprocessResample => 'WAV optimization (16 kHz mono)';

  @override
  String get providerPreprocessResampleHelp =>
      'Resamples to 16 kHz and mixes to mono. Reduces size by about 4–6x with little effect on transcription accuracy.';

  @override
  String get providerPreprocessNoneHelp => 'No preprocessing; send as is.';

  @override
  String get assistantDefaultsScopeHelp =>
      'Default model and tools apply only to new conversations created under this assistant. Existing conversations keep their own settings. Tool output truncation applies to all conversations.';

  @override
  String get assistantDefaultModelTitle => 'Default model';

  @override
  String get assistantDefaultModelHelp =>
      'Model used for new conversations; leave unset to let the conversation choose.';

  @override
  String get assistantNoDefault => 'Not set';

  @override
  String get assistantNoModelsAvailable =>
      'No models available. Configure an LLM provider in Settings.';

  @override
  String get assistantDefaultToolsTitle => 'Default enabled tools';

  @override
  String get assistantDisabledToolsHelp =>
      'Disabled tools will not be enabled automatically in new conversations.';

  @override
  String get assistantUnconfiguredToolsHelp =>
      'Default tools are not configured. New conversations will enable all tools automatically.';

  @override
  String get assistantEnableAll => 'Enable all';

  @override
  String get assistantDisableAll => 'Disable all';

  @override
  String get assistantNoToolsAvailable => 'No tools available';

  @override
  String get assistantTruncateToolOutput => 'Tool output truncation';

  @override
  String get assistantTruncateToolOutputHelp =>
      'Maximum characters in each tool result before it is sent to the model. Applies to all conversations under this assistant.';

  @override
  String get assistantEnableTruncation => 'Enable truncation';

  @override
  String assistantTruncatedTo(String count) {
    return 'Long results are truncated to $count characters';
  }

  @override
  String get assistantSendFullResult =>
      'Send full result (subject to the 50 KB storage limit)';

  @override
  String get assistantMaxCharacters => 'Maximum characters';

  @override
  String get assistantCharactersNotTokens => 'Unit: characters (not tokens)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return 'Default: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return 'Valid range: $minimum–$maximum characters';
  }

  @override
  String get assistantNewConversationPreview => 'New conversation preview';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled / $total enabled';
  }

  @override
  String get assistantAllToolsAutoEnabled =>
      'All tools are enabled automatically (not configured)';

  @override
  String get assistantMoreActions => 'More actions';

  @override
  String get assistantChooseEmoji => 'Choose emoji';

  @override
  String get assistantNameLabel => 'Assistant name';

  @override
  String get assistantDescriptionOptional => 'Description (optional)';

  @override
  String get assistantSelectionTitle => 'Choose an assistant';

  @override
  String get assistantMarketTooltip => 'Assistant marketplace';

  @override
  String get assistantDefaultPrompt =>
      'You are a helpful AI assistant. Answer the user\'s questions clearly and helpfully.';

  @override
  String get assistantCreateNew => 'Create assistant';

  @override
  String get assistantEmptyState =>
      'No assistants yet. Create one to get started.';

  @override
  String get assistantCreate => 'Create';

  @override
  String get assistantReorderHint =>
      'Long-press and drag to reorder assistants';

  @override
  String get assistantNewNameHint => 'Enter assistant name';

  @override
  String get assistantNewDescriptionHint =>
      'Briefly describe what this assistant does';

  @override
  String get assistantDeleteTitle => 'Delete assistant';

  @override
  String assistantDeleteConfirmation(String name) {
    return 'Delete assistant “$name”? This action cannot be undone.';
  }

  @override
  String get assistantEditTitle => 'Edit assistant';

  @override
  String get assistantBasicTab => 'Basic settings';

  @override
  String get assistantParametersTab => 'Parameters';

  @override
  String get assistantDefaultsTab => 'Defaults';

  @override
  String get assistantAddCustomParameter => 'Add custom parameter';

  @override
  String get assistantEditCustomParameter => 'Edit custom parameter';

  @override
  String get assistantParameterName => 'Parameter name';

  @override
  String get assistantParameterNameHint => 'e.g. top_k or provider.only';

  @override
  String get assistantParameterNameInvalid =>
      'Invalid parameter name (dot-separated segments cannot be empty)';

  @override
  String get assistantParameterType => 'Type';

  @override
  String get assistantValue => 'Value';

  @override
  String get assistantTrueFalseHint => 'true or false';

  @override
  String get assistantNumberHint => 'Enter a number';

  @override
  String assistantJsonHint(String example) {
    return 'e.g. $example';
  }

  @override
  String get assistantValueHint => 'Enter a value';

  @override
  String get assistantCancel => 'Cancel';

  @override
  String get assistantSave => 'Save';

  @override
  String get assistantParamOverrideHelp =>
      'When enabled, assistant parameters override model parameters; when disabled, model parameters are used.';

  @override
  String get assistantTemperature => 'Temperature';

  @override
  String get assistantMaxTokens => 'Maximum tokens';

  @override
  String get assistantMaxToolCalls => 'Maximum tool calls';

  @override
  String assistantRounds(String count) {
    return '$count rounds';
  }

  @override
  String get assistantUnlimited => 'Unlimited';

  @override
  String get assistantStreamOutput => 'Stream output';

  @override
  String get assistantFrequencyPenalty => 'Frequency penalty';

  @override
  String get assistantPresencePenalty => 'Presence penalty';

  @override
  String get assistantRandomSeed => 'Random seed';

  @override
  String get assistantNotSet => 'Not set';

  @override
  String get assistantSeedValue => 'Seed value';

  @override
  String get assistantIntegerSeedHint => 'Enter an integer seed';

  @override
  String get assistantWebSearch => 'Web search';

  @override
  String get assistantAddParameter => 'Add parameter';

  @override
  String get assistantNoCustomParameters => 'No custom parameters';

  @override
  String get assistantRoundsLabel => 'Rounds';

  @override
  String get modelCreateTitle => 'Add model';

  @override
  String get modelEditTitle => 'Edit model';

  @override
  String get modelDiscardTitle => 'Discard changes?';

  @override
  String get modelDiscardBody => 'You have unsaved changes. Discard them?';

  @override
  String get modelNameLabel => 'Model name';

  @override
  String get modelNameHint => 'Enter a display name (optional)';

  @override
  String get modelIdLabel => 'Model ID';

  @override
  String modelIdExample(String id) {
    return 'e.g. $id';
  }

  @override
  String get modelIdRequired => 'Model ID is required.';

  @override
  String get modelCustomParamRequired =>
      'Custom parameter name and default value are required.';

  @override
  String modelParamDuplicate(String name) {
    return 'Parameter already exists: $name';
  }

  @override
  String get modelParamName => 'Parameter name';

  @override
  String get modelParamDefaultValue => 'Default parameter value';

  @override
  String get modelParamDelete => 'Delete parameter';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return 'Default value for parameter \"$name\" is not valid JSON: $value';
  }

  @override
  String get modelAddParameter => 'Add parameter';

  @override
  String get modelNoCustomParams => 'No custom parameters';

  @override
  String get modelBasicSettings => 'Basic settings';

  @override
  String get modelDiscardCancel => 'Cancel';

  @override
  String get modelSave => 'Save';

  @override
  String get modelUnsavedMaxTokens =>
      'Maximum output tokens is enabled but has no value.';

  @override
  String get modelMaxTokensPositive =>
      'Maximum output tokens must be a positive integer.';

  @override
  String get modelSeedInteger => 'Random seed must be an integer.';

  @override
  String get modelContextLengthRequired => 'Context length is required.';

  @override
  String get modelContextLengthPositive =>
      'Context length must be a positive integer.';

  @override
  String get modelAsrLanguageCode => 'Language code (Language)';

  @override
  String get modelAsrLanguageHint => 'e.g. zh, en, ja';

  @override
  String get modelAsrLanguageHelp =>
      'ISO-639-1 language code; leave empty for automatic detection.';

  @override
  String get modelTemperature => 'Temperature';

  @override
  String get modelTemperatureHelp =>
      'Controls output randomness; a lower value is recommended.';

  @override
  String get modelAsrPrompt => 'Prompt';

  @override
  String get modelAsrPromptHint => 'Enter a context prompt (optional)';

  @override
  String get modelAsrPromptHelp =>
      'Provide context to improve transcription accuracy, such as a list of specialist terms.';

  @override
  String get modelAsrParams => 'ASR parameters';

  @override
  String get modelEnabledParamsHelp =>
      'Enabled parameters are sent as defaults in API requests.';

  @override
  String get modelAsrResponseFormat => 'Response format';

  @override
  String get modelAsrResponseHelp => 'Format of the returned transcription.';

  @override
  String get modelAsrTimestampGranularity => 'Timestamp granularity';

  @override
  String get modelAsrVerboseHelp =>
      'Available only when response_format is verbose_json.';

  @override
  String get modelNoTrim => 'No trimming';

  @override
  String get modelAudioTrimTitle => 'Audio trimming';

  @override
  String get modelAudioTrimHelp => 'Choose how to trim the audio.';

  @override
  String get modelDeleteTrimPreset => 'Delete trim preset';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return 'Delete trim preset \"$name\"?';
  }

  @override
  String get modelAddTrimPreset => 'Add custom trim';

  @override
  String get modelPlayTestAudio => 'Play test audio';

  @override
  String get modelPlayingTestAudio => 'Playing...';

  @override
  String get modelParamExists => 'Parameter already exists';

  @override
  String get asrModelIdExample => 'e.g. whisper-1';

  @override
  String get asrPromptLabel => 'Prompt';

  @override
  String get asrResponseFormatJson => 'json – JSON';

  @override
  String get asrResponseFormatText => 'text – Plain text';

  @override
  String get asrResponseFormatSrt => 'srt – Subtitles';

  @override
  String get asrResponseFormatVtt => 'vtt – Subtitles';

  @override
  String get asrResponseFormatVerbose =>
      'verbose_json – Detailed JSON (includes timestamps)';

  @override
  String get asrVerboseTimestampHelp =>
      'Selecting verbose_json enables the timestamp granularity option below.';

  @override
  String get asrTimestampSegment => 'segment – Segment level';

  @override
  String get asrTimestampWord => 'word – Word level';

  @override
  String get asrWordTimestampHelp =>
      'Word-level timestamps may be less accurate than segment-level timestamps.';

  @override
  String get reasoningAddOptionValue => 'Add option value';

  @override
  String get reasoningEditOptionValue => 'Edit option value';

  @override
  String get reasoningOptionExample => 'e.g. low, medium, high';

  @override
  String get reasoningOptionSelectionHelp =>
      'Tap a chip to select or clear it. Selected values are sent; drag to reorder. Provider values cannot be deleted, but can be hidden by clearing them.';

  @override
  String get reasoningAddOption => 'Add option';

  @override
  String get reasoningCurrentProvider => 'Current: provider';

  @override
  String get reasoningCurrentModel => 'Current: model custom';

  @override
  String get reasoningAddEffortValue => 'Add reasoning effort value';

  @override
  String get reasoningEffortExample => 'e.g. max, ultra, deep';

  @override
  String get reasoningAddToggle => 'Add reasoning toggle';

  @override
  String get reasoningToggle => 'Reasoning toggle';

  @override
  String get reasoningResetParameter => 'Reset this parameter';

  @override
  String get reasoningDisableToggle => 'Disable reasoning toggle';

  @override
  String get reasoningEnableToggle => 'Enable reasoning toggle';

  @override
  String reasoningParameterNameSource(String source) {
    return 'Parameter name ($source)';
  }

  @override
  String get reasoningNameExample => 'e.g. thinking.type, reasoning';

  @override
  String get reasoningBooleanHelp =>
      'Boolean parameters need no value; the chat panel provides an on/off switch.';

  @override
  String get reasoningOnValue => 'Value when enabled';

  @override
  String get reasoningOnExample => 'e.g. enabled, true';

  @override
  String get reasoningOffValue => 'Value when disabled';

  @override
  String get reasoningOffExample => 'e.g. disabled, false';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return 'When enabled, sends “$onValue”; when disabled, sends “$offValue”.';
  }

  @override
  String get reasoningAddEffort => 'Add reasoning effort';

  @override
  String get reasoningFillToggleFirst => 'Complete the reasoning toggle first';

  @override
  String get reasoningFillToggleBeforeEffort =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get reasoningAddValue => 'Add value';

  @override
  String get reasoningJsonValue => 'JSON value';

  @override
  String reasoningJsonExample(String example) {
    return 'e.g. $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      'Tap a chip to select or clear it. Selected values appear in the chat reasoning panel; drag to reorder. Provider values cannot be deleted, but can be hidden.';

  @override
  String get reasoningAddParameter => 'Add reasoning parameter';

  @override
  String get reasoningToggleIncomplete =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get llmContextLength => 'Context length';

  @override
  String get llmContextHint => 'Enter context length';

  @override
  String get llmContextHelp =>
      'Maximum context window size for the model (tokens).';

  @override
  String get llmReasoningParams => 'Reasoning parameters';

  @override
  String get llmReasoningHelp =>
      'Configure reasoning parameters for chat. The reasoning toggle controls its parameter name and on/off values. Add reasoning effort values, reorder them, and select which values appear in the chat panel. Provider values are synchronized when this page opens. These settings control model parameter availability; the chat panel toggle is managed separately.';

  @override
  String get llmAddReasoningParam => 'Add reasoning parameter';

  @override
  String get llmCustomEndpointType => 'Custom endpoint type';

  @override
  String get llmInheritEndpointType =>
      'When disabled, use the endpoint type from provider settings.';

  @override
  String get llmEndpointType => 'Endpoint type';

  @override
  String get llmEndpointOpenAi => 'OpenAI compatible (Chat Completions)';

  @override
  String get llmEndpointAnthropic => 'Anthropic format (Messages API)';

  @override
  String get llmEndpointHelp =>
      'The endpoint type must match the provider API URL. Changing it affects the format used for new conversations with this model.';

  @override
  String get llmTopPHelp =>
      'Nucleus sampling parameter; controls cumulative probability for word selection.';

  @override
  String get llmFrequencyPenaltyLabel => 'Frequency penalty';

  @override
  String get llmFrequencyPenaltyHelp =>
      'Reduces repetition; negative values increase it.';

  @override
  String get llmPresencePenaltyLabel => 'Presence penalty';

  @override
  String get llmPresencePenaltyHelp =>
      'Encourages new topics; negative values encourage repetition.';

  @override
  String get llmMaxTokensHint => 'Optional, e.g. 4096';

  @override
  String get llmTokensPerResponse => 'Maximum tokens generated per response.';

  @override
  String get llmSeedLabel => 'Random seed (Seed)';

  @override
  String get llmSeedHint => 'Optional, e.g. 42';

  @override
  String get llmSeedHelp => 'Setting this makes output reproducible.';

  @override
  String get llmInheritedCustomHelp =>
      'Provider custom parameters are shown here and synchronized whenever this page opens.';

  @override
  String get llmBooleanParamHelp => 'Boolean parameters do not need a value.';

  @override
  String get modelContextReq => 'Context length is required.';

  @override
  String get modelContextPositive =>
      'Context length must be a positive integer.';

  @override
  String modelParamNameInvalid(String name) {
    return 'Invalid parameter name (dot-separated segments cannot be empty): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return 'Parameter \"$name\" $valueLabel must be a finite number: $value';
  }

  @override
  String get modelReasoningIncomplete =>
      'Complete the reasoning toggle before enabling other reasoning parameters.';

  @override
  String get modelReasoningOptionsRequired =>
      'Add at least one option value to the reasoning parameter.';

  @override
  String modelReasoningError(String error) {
    return 'Reasoning parameter error: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return 'Duplicate reasoning parameter: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return 'Reasoning and custom parameters share the name: $name';
  }

  @override
  String get modelSeedRequired => 'Random seed is enabled but empty.';

  @override
  String get ocrParamsTitle => 'OCR parameters';

  @override
  String get ocrParamsHelp =>
      'Uses the OpenAI-compatible vision Chat Completions format. Parameters below are optional; unset or disabled parameters are not sent. Add provider-specific parameters below if supported by its API.';

  @override
  String get ocrRequestSizeOverride => 'Request JSON size override';

  @override
  String get ocrInheritProvider => 'Leave empty to inherit provider settings';

  @override
  String get ocrBudgetDefault =>
      'When empty, inherits provider settings; if the provider has no value, the default is 20 MiB.';

  @override
  String ocrBudgetValue(String size) {
    return 'When empty, inherits provider settings ($size MiB); if the provider has no value, the default is 20 MiB.';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return 'Trim $direction ${seconds}s';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return 'Trim the first ${seconds}s';
  }

  @override
  String get audioTrimNone => 'Do not trim audio';

  @override
  String get trimNameLabel => 'Trim method name *';

  @override
  String get trimNameHint => 'e.g. silence trimming';

  @override
  String get trimDurationLabel => 'Trim duration (seconds) *';

  @override
  String get trimDurationHint => 'e.g. 0.123';

  @override
  String get trimNameAndDurationRequired => 'Name and duration are required.';

  @override
  String get trimDurationInvalid => 'Enter a valid positive duration.';

  @override
  String get testAudioHostMissing => 'Host is not configured.';

  @override
  String get testAudioKeyMissing => 'Key is not configured.';

  @override
  String testAudioContentTypeError(String contentType) {
    return 'Response Content-Type is $contentType, not audio.';
  }

  @override
  String get testAudioEmpty => 'The server returned empty audio data.';

  @override
  String testAudioTimeoutConnection(String details) {
    return 'Connection timed out. Check your network. $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return 'Receive timed out; the server responded too slowly. $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return 'Request cancelled. $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return 'Network error: $message';
  }

  @override
  String get testAudioNoBody => 'No response body';

  @override
  String testAudioCorsHelp(String details) {
    return 'Unable to connect to server. On web, this may be caused by CORS or an incorrect API URL. Check the provider API URL and whether the server allows cross-origin requests. $details';
  }

  @override
  String get trimModelNameHint =>
      'A friendly name for display and identification, e.g. \"GPT-4o Mini TTS\". Use different names to distinguish models from the same provider.';

  @override
  String get trimModelIdHelp =>
      'Unique identifier used in API calls, e.g. \"gpt-4o-mini-tts\". It must match the model ID provided by the vendor.';

  @override
  String get ttsVoiceRangeTitle => 'Volume range';

  @override
  String get ttsMinVolume => 'Minimum volume';

  @override
  String get ttsMaxVolume => 'Maximum volume';

  @override
  String get ttsSpeedRangeTitle => 'Speed range';

  @override
  String get ttsMinSpeed => 'Minimum speed';

  @override
  String get ttsMaxSpeed => 'Maximum speed';

  @override
  String get ttsMaxAudioLength => 'Maximum audio length per request *';

  @override
  String get ttsAudioLengthHint => 'e.g. 1000';

  @override
  String get ttsNoVoices => 'No voices. Tap to edit.';

  @override
  String get ttsInstructionSupported =>
      'Model supports the instruction parameter';

  @override
  String get ttsInstructionHelp =>
      'When enabled, TTS requests can include instructions for tone, emotion, speaking speed, and more.';

  @override
  String get ttsStreamSupported => 'Model supports streaming output';

  @override
  String get ttsStreamHelp =>
      'Enables this model for streaming scenarios. Confirm the model supports streaming before enabling.';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return 'Parameter “$name” must be true or false: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired =>
      'Maximum audio length per request is required; enter a positive integer.';

  @override
  String get asrLanguageExample => 'e.g. zh, en, ja';

  @override
  String get llmReasoningFullHelp =>
      'The reasoning toggle controls whether reasoning is sent and lets you define the parameter name and on/off values. There is one reasoning-effort parameter. Select values and drag to reorder them; selected values appear in the chat reasoning panel. Add other reasoning parameters below. Parameter names support dot notation such as thinking.type, which becomes a nested JSON object. Provider reasoning parameters synchronize when this page opens. The switches here control model parameters; the chat reasoning toggle is separate.';

  @override
  String get llmTemperatureHelp =>
      'Controls output randomness; higher values are more creative.';

  @override
  String get llmBooleanValueHelp => 'Boolean parameters do not need a value.';

  @override
  String get reasoningDisableEffort => 'Disable reasoning effort';

  @override
  String get reasoningEnableEffort => 'Enable reasoning effort';

  @override
  String get ocrJsonSizePositive =>
      'Request JSON size must be a positive MiB value.';

  @override
  String ttsRangePair(String kind) {
    return 'Enter both the minimum and maximum $kind, or leave both empty.';
  }

  @override
  String get ttsEditTrimTitle => 'Edit custom trim';

  @override
  String ttsVoicesCount(String count) {
    return 'Voices ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return 'Generated in the request format: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'Please enter an MCP server name.';

  @override
  String get mcpStdioCommandRequired => 'stdio mode requires a command.';

  @override
  String get mcpSseUrlRequired => 'SSE mode requires a URL.';

  @override
  String get mcpEditServerTitle => 'Edit MCP server';

  @override
  String get mcpCreateServerTitle => 'New MCP server';

  @override
  String get mcpUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get mcpUnsavedChangesConfirm =>
      'You have unsaved changes. Discard them?';

  @override
  String get mcpTransportType => 'Transport type';

  @override
  String get mcpServerName => 'Server name';

  @override
  String get mcpServerNameHint => 'Enter an MCP server name';

  @override
  String get mcpCommand => 'Command';

  @override
  String get mcpCommandExample => 'Example: npx';

  @override
  String get mcpArguments => 'Arguments';

  @override
  String get mcpArgumentsHint =>
      'Separate arguments with commas, for example: -y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => 'Example: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'API key';

  @override
  String get mcpApiKeyHint => 'Enter an API key (optional)';

  @override
  String get mcpShowKey => 'Show key';

  @override
  String get mcpHideKey => 'Hide key';

  @override
  String get mcpDescriptionHint =>
      'Enter a description for this MCP server (optional)';

  @override
  String get mcpStdioDescription =>
      'stdio starts a local child process as an MCP server and communicates through standard input/output. Recommended for local tools.';

  @override
  String get mcpSseDescription =>
      'SSE connects to a remote MCP server over HTTP SSE. Recommended for remote services.';

  @override
  String get mcpLocalStdio => 'Local (stdio)';

  @override
  String get mcpRemoteSse => 'Remote (SSE)';

  @override
  String get mcpSaving => 'Saving…';

  @override
  String get providerTestSafetyNote =>
      'This test sends a real request to the selected service. MCP only calls the read-only tools/list method; HTTP and web search run one query. Todo reads the list by default; to protect current data, omit the todos parameter or set it to null.';

  @override
  String get providerDeleteConfigTitle => 'Delete configuration';

  @override
  String get providerDeleteConfigConfirm =>
      'Delete this provider configuration and all of its models?';

  @override
  String get providerCreateGroup => 'New group';

  @override
  String get providerEditGroup => 'Edit group';

  @override
  String get providerGroupName => 'Group name';

  @override
  String get providerGroupNameExists =>
      'A group with this name already exists.';

  @override
  String get providerDeleteGroup => 'Delete group';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return 'Deleting “$groupName” will move its configurations to “Other MCP services”.';
  }

  @override
  String get providerMoveToGroup => 'Move to group';

  @override
  String get providerUnnamed => '(Unnamed)';

  @override
  String get providerHttpSearch => 'HTTP search';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP tool: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return 'Local (stdio): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return 'Remote (SSE): $url';
  }

  @override
  String get providerServices => 'Service configurations';

  @override
  String get providerServicesDescription =>
      'Manage remote connections, local stdio, and HTTP search by group';

  @override
  String get providerCreateGroupAction => 'New group';

  @override
  String get providerGroupEmpty =>
      'This group has no configurations. Select “Add” to add an item.';

  @override
  String get providerBuiltinTools => 'Built-in tools';

  @override
  String get providerBuiltinToolsDescription =>
      'Stroom-provided local tool interfaces. Web search is listed in its service group.';

  @override
  String get providerBuiltinToolInterface => 'Built-in tool interface';

  @override
  String get providerViewInterface => 'View interface';

  @override
  String get providerConfigTitle => 'Configuration';

  @override
  String get providerNotFound => 'Provider not found';

  @override
  String get providerConfigurationHeading => 'Provider configuration';

  @override
  String get providerBuiltinWebSearchEmpty =>
      'Built-in web search supports Google, Bing, and Baidu. Its model tool name is web_search.';

  @override
  String get providerNoConfigsAdd =>
      'No provider configurations yet. Select “Add” to create one.';

  @override
  String get providerNoHost => '(Host not set)';

  @override
  String get providerServicesAndTools => 'Services and tools';

  @override
  String get providerManageServicesDescription =>
      'Manage MCP servers, HTTP search, and Stroom built-in tools.';

  @override
  String get providerNoServices => 'No service configurations yet';

  @override
  String get providerAddServiceDescription =>
      'Add an MCP service or HTTP search interface to use it in assistants.';

  @override
  String get providerAddService => 'Add service';

  @override
  String get providerBuiltinBadge => 'Built-in';

  @override
  String get providerConnectivityTest => 'Connectivity test';

  @override
  String get providerMoveGroupTooltip => 'Move to group';

  @override
  String get providerDeleteTooltip => 'Delete configuration';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# items',
      one: '# item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => 'Group actions';

  @override
  String get providerEditGroupAction => 'Edit group';

  @override
  String get providerDeleteGroupAction => 'Delete group';

  @override
  String get providerAddItem => 'Add item';

  @override
  String get providerMcpMasterLabel => 'MCP servers';

  @override
  String get providerMcpMasterDescription =>
      'Controls whether MCP servers and built-in search tools are available in assistants and chats.';

  @override
  String get providerEnabled => 'Enabled';

  @override
  String get providerDisabled => 'Disabled';

  @override
  String get providerEditSettings => 'Edit provider settings';

  @override
  String get providerModelList => 'Models';

  @override
  String get providerNoModels => 'No models yet';

  @override
  String get providerDeleteModel => 'Delete model';

  @override
  String get providerDeleteModelConfirm =>
      'Are you sure you want to delete this model?';

  @override
  String get providerEditConfig => 'Edit configuration';

  @override
  String providerCreateNamedConfig(String entryName) {
    return 'New $entryName configuration';
  }

  @override
  String get toolHttpSearchType => 'Connection type: HTTP search';

  @override
  String toolInterface(String name) {
    return 'Tool interface: $name';
  }

  @override
  String get toolParameterDefinitions => 'Parameter definitions';

  @override
  String get toolHttpAddress => 'HTTP endpoint URL';

  @override
  String get toolInvalidHttpUrl => 'Enter a valid HTTP or HTTPS URL.';

  @override
  String get toolBuiltinType => 'Connection type: Stroom built-in tool';

  @override
  String get toolBuiltinEnableHelp =>
      'Enable this tool for an assistant in that assistant’s default tool settings.';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return 'Model ID: $modelId';
  }

  @override
  String get providerValueNotSet => '(Not set)';

  @override
  String get providerApiKeyInputHint => 'Enter an API key';

  @override
  String get providerSettingsTitle => 'Provider configuration';

  @override
  String get providerBasicInfoTab => 'Basic information';

  @override
  String get providerParameterSettingsTab => 'Parameter settings';

  @override
  String get providerOptionValuesReorderHelp =>
      'Option values (hold the handle to drag and reorder)';

  @override
  String providerOptionIndexLabel(String index) {
    return 'Option $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return 'e.g. $example';
  }

  @override
  String get providerDeleteOptionTooltip => 'Delete option';

  @override
  String get providerAddOption => 'Add option';

  @override
  String get providerAddCustomParam => 'Add parameter';

  @override
  String get providerNoCustomParams => 'No custom parameters yet';

  @override
  String get providerParamNameLabel => 'Parameter name';

  @override
  String get providerParamDefaultValueLabel => 'Default parameter value';

  @override
  String get providerBooleanParamNoValue =>
      'Boolean parameters do not need a value. The chat panel provides an on/off toggle.';

  @override
  String get providerReasoningParamsHeading => 'Reasoning parameters';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return 'The reasoning toggle turns reasoning on or off in chat; you choose its parameter name and on/off values. You can configure one reasoning effort parameter with a required name and optional choices. If you enter only a name, the model configuration can provide the values. Use the buttons below to add other reasoning parameters. Parameter names support dot nesting, for example $parameterName expands to $jsonExample.';
  }

  @override
  String get providerAddReasoningParam => 'Add reasoning parameter';

  @override
  String get providerAddReasoningToggle => 'Add reasoning toggle';

  @override
  String get providerReasoningToggle => 'Reasoning toggle';

  @override
  String get providerDeleteReasoningToggle => 'Delete reasoning toggle';

  @override
  String providerParamNameHint(String examples) {
    return 'e.g. $examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      'Boolean parameters do not need a value. The chat panel provides an on/off toggle.';

  @override
  String get providerToggleOnValueLabel => 'On value';

  @override
  String get providerToggleOffValueLabel => 'Off value';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return 'When reasoning is on, send “$onValue”; when it is off, send “$offValue”.';
  }

  @override
  String get providerAddReasoningEffort => 'Add reasoning effort';

  @override
  String get providerDeleteReasoningEffort =>
      'Delete reasoning effort parameter';

  @override
  String get providerReasoningEffortLockedHint =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get providerJsonValueLabel => 'JSON value';

  @override
  String get providerReasoningOptionsHelp =>
      'Option values (optional; if only the parameter name is entered, the model configuration supplies the value). Hold the handle to drag and reorder.';

  @override
  String get providerParamNameNestedLabel =>
      'Parameter name (supports dot nesting)';

  @override
  String get providerToggleEffortPrerequisite =>
      'Complete the reasoning toggle before configuring reasoning effort.';

  @override
  String get providerToggleRequiredHint =>
      'Complete the reasoning toggle first.';

  @override
  String get providerDeleteCustomParam => 'Delete parameter';

  @override
  String get modelSaveSuccess => 'Model saved';

  @override
  String get modelSaving => 'Saving…';

  @override
  String modelOriginalError(String error) {
    return 'Original error: $error';
  }

  @override
  String get paramTypeStringLabel => 'String';

  @override
  String get paramTypeNumberLabel => 'Number';

  @override
  String get paramTypeBooleanLabel => 'Boolean';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String get paramTypeStringHint => 'e.g. cheerful';

  @override
  String get paramTypeNumberHint => 'e.g. 0.8';

  @override
  String get paramTypeBooleanHint => 'e.g. true';

  @override
  String get paramTypeJsonHint => 'e.g. ';

  @override
  String get ankiPageTitle => 'Anki flashcards';

  @override
  String get ankiStatsTooltip => 'Study statistics';

  @override
  String get ankiBrowseCardsTooltip => 'Browse cards';

  @override
  String get ankiSyncTooltip => 'AnkiWeb sync';

  @override
  String get ankiNewDeckTooltip => 'New deck';

  @override
  String ankiDeckLoadError(String error) {
    return 'Failed to load decks: $error';
  }

  @override
  String get ankiEmptyDecksTitle => 'No decks yet';

  @override
  String get ankiEmptyDecksDescription => 'Create a deck to start studying';

  @override
  String get ankiNewDeckTitle => 'New deck';

  @override
  String get ankiDeckNameHint => 'Deck name';

  @override
  String get ankiCreateDeck => 'Create';

  @override
  String get ankiRenameDeck => 'Rename deck';

  @override
  String get ankiConfirm => 'OK';

  @override
  String get ankiDeleteDeckTitle => 'Delete deck';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return 'Delete “$deckName” and all its cards?';
  }

  @override
  String get ankiAddCardTitle => 'Add card';

  @override
  String get ankiNoteTypeLabel => 'Note type';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return 'Text (mark deletions with $clozeSyntax)';
  }

  @override
  String get ankiFrontQuestionHint => 'Front (question)';

  @override
  String get ankiBackExtraLabel => 'Back / extra';

  @override
  String get ankiTagsLabel => 'Tags (separated by spaces)';

  @override
  String get ankiTagsHint => 'Example: math physics';

  @override
  String get ankiAdd => 'Add';

  @override
  String get ankiStatNew => 'New';

  @override
  String get ankiStatLearning => 'Learning';

  @override
  String get ankiStatReview => 'Review';

  @override
  String get ankiAddCardAction => 'Add card';

  @override
  String get ankiRenameAction => 'Rename';

  @override
  String get ankiDeleteAction => 'Delete';

  @override
  String get ankiNoCardContent => 'No card content';

  @override
  String get ankiStudy => 'Study';

  @override
  String get ankiWhiteboardTooltip => 'Whiteboard';

  @override
  String get ankiFrontLabel => 'Front';

  @override
  String get ankiBackLabel => 'Back';

  @override
  String get ankiShowAnswer => 'Show answer';

  @override
  String get ankiRatingAgain => 'Again';

  @override
  String get ankiRatingHard => 'Hard';

  @override
  String get ankiRatingGood => 'Good';

  @override
  String get ankiRatingEasy => 'Easy';

  @override
  String get ankiNoCardsToStudy => 'No cards to study right now';

  @override
  String get ankiNoCardsHint => 'Add new cards or come back later';

  @override
  String get ankiBack => 'Back';

  @override
  String get ankiSyncPageTitle => 'Anki sync';

  @override
  String get ankiSyncChooseMode => 'Choose a sync mode';

  @override
  String get ankiSyncModeHelp =>
      'Login status is stored separately for each service. Switching modes does not merge or overwrite data.';

  @override
  String get ankiSyncSelfHostedMode => 'Self-hosted server';

  @override
  String get ankiSyncServerAddress => 'Server address';

  @override
  String get ankiSyncServerHelp =>
      'Remote self-hosted servers must use HTTPS; HTTP is allowed for local addresses. The server must support Anki sync v10, and certificate verification is enabled by default.';

  @override
  String get ankiSyncCustomCaTitle => 'Custom CA certificate (optional)';

  @override
  String get ankiSyncCustomCaHelp =>
      'Only enter this when the server uses a self-signed certificate';

  @override
  String get ankiSyncOfficialHelp =>
      'Use the official AnkiWeb sync service. Your password is sent only when logging in and is not stored in Stroom.';

  @override
  String ankiSyncConnected(String service) {
    return 'Connected to $service';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return 'Not connected to $service';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return 'Log in to $service';
  }

  @override
  String get ankiSyncCheckServerStatus => 'Check server status';

  @override
  String get ankiSyncLogout => 'Log out';

  @override
  String get ankiSyncBothWays => 'Two-way sync';

  @override
  String get ankiSyncOverwriteServer => 'Replace server data with local data';

  @override
  String get ankiSyncReplaceLocal => 'Replace local data with server data';

  @override
  String get ankiSyncHelp =>
      'Two-way sync merges incremental collection changes and transfers media files. If the schema version differs, choose a full upload or download. A failed full download will try to restore the original collection and media directory.';

  @override
  String get ankiSyncStatusRestored =>
      'Restored the securely saved login session';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      'Could not read the saved login session. Please log in again.';

  @override
  String get ankiSyncInvalidServerUrl =>
      'Server address must be an HTTPS URL. HTTP is allowed only for a local loopback address. User information and query parameters are not allowed.';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return 'Settings not saved: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      'Server address changed. Please log in again to continue.';

  @override
  String get ankiSyncStatusVerifyingLogin => 'Verifying login…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      'Login successful. Your password was not saved; the sync key was encrypted and saved.';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      'Login successful, but the sync key could not be stored securely. You will need to log in again after closing this page.';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'Log in to AnkiWeb';

  @override
  String get ankiSyncLoginSelfHosted => 'Log in to self-hosted server';

  @override
  String get ankiSyncEmailOrUsername => 'Email / username';

  @override
  String get ankiSyncEmailOrUsernameRequired => 'Enter an email or username';

  @override
  String get ankiSyncPassword => 'Password';

  @override
  String get ankiSyncPasswordRequired => 'Enter a password';

  @override
  String get ankiSyncLogin => 'Log in';

  @override
  String get ankiSyncStatusPreparingServerSettings =>
      'Preparing server settings…';

  @override
  String get ankiSyncStatusReadingCollection =>
      'Reading server collection status…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      'Connected. The server collection is empty.';

  @override
  String get ankiSyncStatusConnectedStatusRead =>
      'Connected. Server status was read.';

  @override
  String get ankiSyncStatusUpgradeClient =>
      'This server requires a newer sync client.';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return 'Status check failed: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => 'Preparing upload settings…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle =>
      'Replace the server collection with the local one?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      'The server collection will be fully replaced with local data. Stroom will first keep a backup of the local database.\n\nMedia files will still be synchronized in both directions according to the server media list.';

  @override
  String get ankiSyncOverwriteServerAction => 'Replace server collection';

  @override
  String get ankiSyncStatusBackingUpUploading =>
      'Backing up and uploading collection…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return 'The server accepted the local collection. Media sync completed: uploaded $uploaded files, downloaded $downloaded, deleted $deleted.$backup Please check server status again.';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return '\nLocal backup: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      'The server collection was replaced, but media sync did not finish: ';

  @override
  String get ankiSyncStatusUploadFailed => 'Upload failed: ';

  @override
  String get ankiSyncStatusPreparingDownload => 'Preparing download settings…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle =>
      'Replace the local collection with the server one?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      'The local collection will be replaced with server data. Stroom will first keep a backup of the local database.\n\nServer media will replace local media and missing files will be downloaded. If any step fails or the app exits in the middle, Stroom will restore the local collection and media before opening the decks next time.';

  @override
  String get ankiSyncReplaceLocalAction => 'Replace local data';

  @override
  String get ankiSyncStatusDownloadingValidating =>
      'Downloading and validating collection…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return 'The local collection was replaced and passed the SQLite check. Media sync completed: downloaded $downloaded files, uploaded $uploaded, deleted $deleted.$backup Please check server status again.';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => 'Preparing sync…';

  @override
  String get ankiSyncStatusMergingChanges => 'Merging collection changes…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'Collection changes merged. Syncing media files…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '$notes notes, $cards cards, and $reviews review records added or updated';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges =>
      'No collection changes to merge';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return 'Two-way sync complete: $collection; media uploaded $uploaded, downloaded $downloaded, deleted $deleted.';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'Collection changes were merged, but media sync did not finish: ';

  @override
  String get ankiSyncStatusSyncIncomplete => 'Sync did not finish: ';

  @override
  String get ankiSyncStatusClearingLogin => 'Clearing login session…';

  @override
  String get ankiSyncStatusLoggedOut =>
      'Logged out. The sync key was deleted from secure storage.';

  @override
  String get ankiSyncStatusClearLoginFailed =>
      'Could not clear the saved login session';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      'Operation did not finish. Check secure storage, network, and server address.';

  @override
  String get ankiSyncUnknown => 'Unknown';

  @override
  String get ankiSyncServerCollectionEmpty => 'Server collection is empty';

  @override
  String get ankiSyncServerCollectionAvailable =>
      'Server collection is available';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return 'Schema version $schema · USN $usn · Modified $modified';
  }

  @override
  String get asrPageTitle => 'Audio Transcription';

  @override
  String get clear => 'Clear';

  @override
  String get configure => 'Configure';

  @override
  String get asrModel => 'Recognition model';

  @override
  String get reselectModel => 'Please select a model again';

  @override
  String get selectAsrModel => 'Select a recognition model';

  @override
  String get enterPublicAudioUrl => 'Enter a public audio URL';

  @override
  String get recordingSelection => 'Recordings';

  @override
  String get audioFiles => 'Audio files';

  @override
  String get noAudioSelected => 'No audio files selected';

  @override
  String get supportedAudioFormats =>
      'Supports common audio formats such as WAV, MP3, M4A, and OGG';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files selected',
      one: '$count audio file selected',
      zero: 'No audio files selected',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files selected',
      one: '$count audio file selected',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => 'Select again';

  @override
  String get asrUrlLabel => 'URL | Public link';

  @override
  String get asrErrorDetails => 'View error details';

  @override
  String get asrResultSaved => 'Transcription result saved';

  @override
  String get asrWorking => 'Transcribing…';

  @override
  String get asrStart => 'Start transcription';

  @override
  String get saveTo => 'Save to';

  @override
  String get rootFolder => 'Root folder';

  @override
  String get chooseSaveFolder => 'Choose a folder';

  @override
  String get linkAlreadyAdded => 'This link is already in the list';

  @override
  String get chooseAudioSource => 'Choose an audio source';

  @override
  String get inAppRecordings => 'In-app recordings';

  @override
  String get chooseGeneratedRecordings => 'Choose from generated recordings';

  @override
  String get systemAudioFiles => 'System audio files';

  @override
  String get chooseDeviceAudioFiles => 'Choose files from your device';

  @override
  String get cannotReadAudioFile => 'Could not read the audio file';

  @override
  String chooseAudioFileFailed(String details) {
    return 'Could not select audio file: $details';
  }

  @override
  String get chooseInAppRecording => 'Choose in-app recordings';

  @override
  String get noRecordings => 'No recordings';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secs',
      one: '$seconds sec',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider =>
      'Configure an audio transcription provider and model in Settings first';

  @override
  String get asrModelUnavailable =>
      'The original recognition model is unavailable or cannot be verified. Please select a model again.';

  @override
  String get asrUrlProviderRemoveFiles =>
      'This provider uploads audio by URL. Remove local audio files and try again.';

  @override
  String get asrFileProviderRemoveUrls =>
      'This provider uploads audio files and does not support transcription by link. Remove links and try again.';

  @override
  String asrTaskStartFailed(String details) {
    return 'Could not start the task: $details';
  }

  @override
  String get asrInvalidUrl =>
      'Invalid URL. It must start with http:// or https://';

  @override
  String get asrEnterAudioUrl => 'Enter an audio URL';

  @override
  String get asrUrlProviderHelp =>
      'This provider uploads audio by URL. Enter a public audio URL (http/https).';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get ttsPageTitle => 'Audio';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files imported',
      one: '$count audio file imported',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return 'Import failed: $details';
  }

  @override
  String get ttsFileReadFailed => 'Could not read file data';

  @override
  String get ttsExportAudioFile => 'Export audio file';

  @override
  String ttsExportedTo(String path) {
    return 'Exported to: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return 'Export failed: $details';
  }

  @override
  String get ttsConfirmRegenerate => 'Confirm regeneration';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return 'Regenerate audio “$fileName”?';
  }

  @override
  String get ttsRegenerateOverwrite =>
      'The original audio file will be replaced after regeneration.';

  @override
  String get ttsRegenerate => 'Regenerate audio';

  @override
  String ttsCopiedFailed(String details) {
    return 'Could not copy: $details';
  }

  @override
  String get ttsChooseExportFolder => 'Choose export folder';

  @override
  String get ttsExportAudio => 'Export audio';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files exported',
      one: '$count file exported',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => 'Export folder';

  @override
  String get ttsWebFolderExportHelp =>
      'Your browser cannot choose an export folder. A ZIP file will be downloaded with the folder structure preserved.';

  @override
  String get ttsDownloadZip => 'Download ZIP file';

  @override
  String get ttsExportAudioFolder => 'Export audio folder';

  @override
  String get ttsRecord => 'Record';

  @override
  String get ttsImport => 'Import';

  @override
  String get ttsPlay => 'Play';

  @override
  String get ttsExportLocal => 'Export to device';

  @override
  String get ttsRegenerateQuestion => 'Regenerate';

  @override
  String get ttsNeedsProvider =>
      'Configure a speech synthesis provider and model in Settings first';

  @override
  String get ttsAddedToTasks =>
      'Added to the task list. Generating in the background…';

  @override
  String get ttsCreateTitle => 'Speech Synthesis';

  @override
  String get ttsOriginalTitle => 'Recording title';

  @override
  String get ttsUseOriginalTitle => 'Use original title';

  @override
  String get ttsAudioFileNameHint => 'Saved audio file name (optional)';

  @override
  String get ttsTextToConvert => 'Text to convert';

  @override
  String get ttsSpeechContent => 'Speech content';

  @override
  String get ttsTextHint => 'Enter text to convert to speech…';

  @override
  String get ttsFullscreenEdit => 'Edit in full screen';

  @override
  String ttsTextLimitWarning(int limit) {
    return 'Text exceeds the limit (maximum $limit characters)';
  }

  @override
  String get ttsSynthesisConfig => 'Synthesis settings';

  @override
  String get ttsVoiceAndSoundHelp => 'Adjust the voice and sound';

  @override
  String get ttsProviderSettingsLead => 'in ';

  @override
  String get ttsProviderSettings => 'TTS provider settings';

  @override
  String get ttsProviderSettingsTail => ' to configure more parameters';

  @override
  String get ttsEditText => 'Edit text';

  @override
  String get ttsClose => 'Close';

  @override
  String get ttsVoice => 'Voice';

  @override
  String get ttsSelectVoice => 'Select a voice';

  @override
  String get ttsSpeed => 'Speed';

  @override
  String get ttsNormal => 'Normal';

  @override
  String get ttsVolume => 'Volume';

  @override
  String get ttsInstruction => 'Speaking style instruction';

  @override
  String get ttsInstructionHint =>
      'For example: Speak in a cheerful and excited tone';

  @override
  String get ttsCustomParams => 'Custom parameters';

  @override
  String ttsDefaultValue(Object value) {
    return 'Default: $value';
  }

  @override
  String get ttsGenerateRecording => 'Generate recording';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return 'Save as: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => 'Choose a folder';

  @override
  String get ttsFillTextError => 'Enter text to convert';

  @override
  String get voiceBatchTitle => 'Add voices in bulk';

  @override
  String get voiceBatchConfirm => 'Add selected voices';

  @override
  String get voiceBatchSeparator => 'Separator:';

  @override
  String get voiceBatchCustomSeparatorHint => 'Enter a custom separator';

  @override
  String get voiceBatchFieldOrder => 'Field order:';

  @override
  String get voiceBatchNameThenId => '1st = name, 2nd = ID';

  @override
  String get voiceBatchIdThenName => '1st = ID, 2nd = name';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Detected $count columns. Choose the starting column for the name/ID:',
      one:
          'Detected $count column. Choose the starting column for the name/ID:',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return 'Column $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn =>
      'One column detected. All values will be used as IDs (name = ID).';

  @override
  String get voiceBatchInputHint =>
      'Separate name and ID with Tab, commas, semicolons, or vertical bars (one pair per line)';

  @override
  String get voiceBatchNoPreview => 'Nothing to preview';

  @override
  String get voiceName => 'Voice name';

  @override
  String get voiceId => 'Voice ID';

  @override
  String get status => 'Status';

  @override
  String get voiceNew => '✅ New';

  @override
  String get voiceIdExists => '⚠️ ID already exists';

  @override
  String voiceFormatError(String details) {
    return '❌ Format error$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicate IDs found: $ids',
      one: '$count duplicate ID found: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData =>
      'Not enough data in the selected columns';

  @override
  String get voiceCustomSeparator => 'Custom…';

  @override
  String get voiceCommaSeparator => 'Comma (,)';

  @override
  String get voiceSemicolonSeparator => 'Semicolon (;)';

  @override
  String get voicePipeSeparator => 'Vertical bar (|)';

  @override
  String get voiceTabSeparator => 'Tab';

  @override
  String get voiceEditorTitle => 'Edit voices';

  @override
  String get save => 'Save';

  @override
  String get voiceAddRow => 'Add row';

  @override
  String get voiceBatchAdd => 'Add in bulk';

  @override
  String get voiceNoneAdd => 'No voices yet. Add one to get started.';

  @override
  String get delete => 'Delete';

  @override
  String get voiceDuplicateResolution =>
      'The following voice IDs are duplicated. Choose how to handle each one:';

  @override
  String get update => 'Update';

  @override
  String get skip => 'Skip';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates remain',
      one: '$count duplicate remains',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => 'Continue editing';

  @override
  String get asrRetryIncomplete =>
      'Retry audio is incomplete. Clear the list and select all audio again.';

  @override
  String asrRetryAudioUnreadable(String details) {
    return 'Retry audio data could not be read. Select the audio again: $details';
  }

  @override
  String get asrLegacyRetryUnavailable =>
      'Legacy retry audio is unavailable. Select the audio again.';

  @override
  String get asrRetryDataUnreadable =>
      'Retry data could not be read. Select the audio again.';

  @override
  String get ttsSynthesisModel => 'Synthesis model';

  @override
  String get asrRetryUnavailable =>
      'Retry audio is unavailable. Select the audio again.';

  @override
  String get chatRequest => 'Request';

  @override
  String get chatResponse => 'Response';

  @override
  String get chatNoErrorDetails => 'No details available';

  @override
  String get ttsInstructionDescription =>
      'Describe tone, emotion, speed, accent, and other qualities in natural language. The model adjusts the synthesized voice accordingly.';

  @override
  String get audioPlayerSourceTextSource => 'Choose source text';

  @override
  String get audioPlayerChooseInAppText => 'Choose in app text';

  @override
  String get audioPlayerChooseSavedTextSubtitle =>
      'Choose a saved text file from the app';

  @override
  String get audioPlayerChooseSystemText => 'Choose system text file';

  @override
  String get audioPlayerChooseDeviceTextSubtitle =>
      'Choose a text file from device storage';

  @override
  String get audioPlayerSelectInAppText => 'Choose in app text';

  @override
  String get audioPlayerNoTextFiles => 'No text files yet';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count characters';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return 'Failed to select text: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => 'Unable to read text file';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return 'Failed to upload source text: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => 'Text is empty';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return 'Failed to save source text: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => 'Source text uploaded';

  @override
  String get audioPlayerSourceTextUpdated => 'Source text updated';

  @override
  String get audioPlayerConfigureTtsProvider =>
      'Configure a TTS provider first';

  @override
  String get audioPlayerNoStreamingModels =>
      'No model supports streaming playback';

  @override
  String get audioPlayerSelectStreamingModel =>
      'Select a streaming playback model';

  @override
  String get audioPlayerProviderFallback => 'Provider';

  @override
  String audioPlayerStartStreaming(String model) {
    return 'Starting streaming playback: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return 'Audio file not found: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => 'Unable to load audio data';

  @override
  String get audioPlayerSourceText => 'Source text';

  @override
  String get audioPlayerNoSourceText => '(No source text)';

  @override
  String get audioPlayerUploadSourceText => 'Upload source text';

  @override
  String get audioPlayerEditSourceText => 'Edit source text';

  @override
  String get audioPlayerCompanionTextMissing => 'No companion text file found';

  @override
  String get audioPlayerPlaySelection => 'Play selection';

  @override
  String get audioPlayerGenerateSelection => 'Generate selection';

  @override
  String get audioPlayerPlaying => 'Playing...';

  @override
  String get audioPlayerPaused => 'Paused';

  @override
  String get audioPlayerPlaybackSpeed => 'Playback speed';

  @override
  String get audioPlayerFailed => 'Playback failed';

  @override
  String get audioPlayerRetry => 'Retry';

  @override
  String get audioPlayerLoading => 'Loading audio...';

  @override
  String get audioPlayerClose => 'Close';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      'Recording is not supported in the browser. Use the app version.';

  @override
  String get audioRecordingMicrophonePermissionRequired =>
      'Microphone permission is required to record';

  @override
  String audioRecordingStartFailure(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return 'Failed to pause recording: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return 'Failed to resume recording: $error';
  }

  @override
  String get audioRecordingInvalidFile =>
      'Recording file is invalid. Record again.';

  @override
  String audioRecordingStopFailure(String error) {
    return 'Failed to stop recording: $error';
  }

  @override
  String get audioRecordingFileNotFound => 'Recording file not found';

  @override
  String get audioRecordingFileEmpty => 'Recording file is empty';

  @override
  String audioRecordingSaved(String name) {
    return 'Recording saved: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return 'Failed to save recording: $error';
  }

  @override
  String get audioRecordingTitle => 'Recording';

  @override
  String get audioRecordingBrowserUnsupported =>
      'Recording is not supported in the browser';

  @override
  String get audioRecordingUseApp => 'Use the app version to record';

  @override
  String get audioRecordingDraftRecoveryHint =>
      'An unsaved recording draft was found. You can save it to the audio library.';

  @override
  String get audioRecordingRecording => 'Recording ●';

  @override
  String get audioRecordingPaused => 'Paused ||';

  @override
  String get audioRecordingPreparing => 'Preparing...';

  @override
  String get audioRecordingStart => 'Start recording';

  @override
  String get audioRecordingPause => 'Pause';

  @override
  String get audioRecordingStopping => 'Stopping...';

  @override
  String get audioRecordingStop => 'Stop';

  @override
  String get audioRecordingResume => 'Resume';

  @override
  String get audioRecordingSaving => 'Saving...';

  @override
  String get audioRecordingSave => 'Save recording';

  @override
  String get audioRecordingRecordAgain => 'Record again';

  @override
  String get audioRecordingWaveformPaused =>
      'Recording paused; waveform is frozen';

  @override
  String get audioRecordingWaveformLive => 'Live audio waveform';

  @override
  String get audioSeparationTitle => 'Video audio separation';

  @override
  String get audioSeparationChooseVideoSource => 'Choose video source';

  @override
  String get audioSeparationChooseAppAlbum => 'Choose from app library';

  @override
  String get audioSeparationChooseSavedVideoSubtitle =>
      'Choose a saved video from the app';

  @override
  String get audioSeparationChooseSystemAlbum => 'Choose from system storage';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle =>
      'Choose a video file from device storage';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return 'Failed to choose video: $error';
  }

  @override
  String get audioSeparationEngineMissing =>
      'Audio separation engine not detected';

  @override
  String get audioSeparationEngineMissingHelp =>
      'Restart the app or check that its resources are complete.';

  @override
  String get audioSeparationNoVideoSelected => 'No video selected';

  @override
  String get audioSeparationSupportedFormatsHint =>
      'Supported formats: mp4, mov, m4v, 3gp';

  @override
  String get audioSeparationSuccess =>
      'Audio extracted and saved to the audio library';

  @override
  String get audioSeparationView => 'View';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selected $count videos',
      one: 'Selected $count video',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => 'Extracting...';

  @override
  String get audioSeparationExtractAudio => 'Extract audio';

  @override
  String get audioSeparationSaveTo => 'Save to';

  @override
  String get audioSeparationChooseSaveFolder => 'Choose save folder';

  @override
  String get audioSeparationCannotReadVideoFile => 'Unable to read video file';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return 'Failed to select video file: $error';
  }

  @override
  String get audioSeparationUnknownFormat => 'Unknown';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return 'Unsupported formats: $formats. Supported formats: MP4, MOV, M4V, 3GP.';
  }

  @override
  String get audioSeparationEngineUnavailable =>
      'Audio separation engine is unavailable.';

  @override
  String get backgroundOptimizationTitle => 'Background Optimization';

  @override
  String get backgroundOptimizationEnvironment => 'System Environment';

  @override
  String get backgroundOptimizationChecks => 'Background Service Status';

  @override
  String get backgroundOptimizationKeepAliveStrategies =>
      'Keep-Alive Strategies';

  @override
  String get backgroundOptimizationDetecting => 'Checking…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      'Background services are not supported on this platform';

  @override
  String get backgroundOptimizationServiceRunning =>
      'Background service is running';

  @override
  String get backgroundOptimizationServiceStopped =>
      'Background service is not running';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      'Could not check background service status';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      'The desktop tray is unavailable. Closing the window will exit the app.';

  @override
  String get backgroundOptimizationDesktopCloseExits =>
      'The app exits when the desktop window closes';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      'The desktop tray keeps the app running';

  @override
  String get backgroundOptimizationStartFailed => 'Could not start the service';

  @override
  String get backgroundOptimizationStopFailed => 'Could not stop the service';

  @override
  String get backgroundOptimizationRestartFailed =>
      'Could not restart the service';

  @override
  String get backgroundOptimizationStopService => 'Stop Service';

  @override
  String get backgroundOptimizationRestartService => 'Restart Service';

  @override
  String get backgroundOptimizationStartService => 'Start Service';

  @override
  String get backgroundOptimizationRedetect => 'Check Again';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      'Background service controls are not supported on this platform.';

  @override
  String get backgroundOptimizationCheckingBattery =>
      'Checking battery optimization status…';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      'Battery optimization is disabled for this app';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      'Battery optimization is enabled — background activity may be stopped';

  @override
  String get backgroundOptimizationIgnoreBattery =>
      'Disable Battery Optimization';

  @override
  String get backgroundOptimizationExactAlarm =>
      'Allow Exact Alarms (more reliable background activity)';

  @override
  String get backgroundOptimizationWatchdogTitle => 'AlarmManager Watchdog';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      'When enabled, Android checks the background service every 5 minutes using a native alarm. If the system kills the process, the alarm restarts it.\n\nThe alarm still works while the device is in Doze mode and is rescheduled after a reboot.\n\nRecommended for users who rely heavily on background tasks.\nBattery impact: very low; the device wakes briefly for each check.';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      'Could not save the watchdog setting; it was not changed';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      'Could not activate the watchdog; background service status is unconfirmed';

  @override
  String get backgroundOptimizationColdStartTitle =>
      'Restore Service on App Launch';

  @override
  String get backgroundOptimizationColdStartDetail =>
      'When enabled, the app checks for and restores a previously running background service each time it opens.\n\nIf the system or user stops the app process, the background service restarts the next time you open the app.\n\nRecommended for all users.\nBattery impact: none; the app checks only once at launch.';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      'Could not save the launch recovery setting; it was not changed';

  @override
  String get backgroundOptimizationBatteryReminderTitle =>
      'Battery Optimization Reminder';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      'When enabled, this page shows the battery optimization status. If the app is not on the battery exemption list, you can open system settings to exempt it.\n\nAndroid battery optimization (Doze) limits background apps. Adding this app to the exemption list prevents the system from stopping it to save power.\n\nTurning this off only hides the reminder card; it does not change the app’s battery exemption.';

  @override
  String get backgroundOptimizationStrategyIntro =>
      'These strategies can be enabled independently. They are all on by default for the most reliable background activity. Turning one off affects only that strategy, not the background service itself.';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOS Background Tasks';

  @override
  String get backgroundOptimizationIosSupported =>
      'This version of iOS (26 or later) supports ongoing background tasks. Tasks usually continue when you switch apps or lock the screen, though the system may stop them when resources are low. You can view progress on the Lock Screen.';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'This version of iOS (earlier than 26) does not support ongoing background tasks. While a task is running, return to the app every few minutes (about every 5–10 minutes; timing depends on iOS) to refresh its background time and prevent suspension.';

  @override
  String get backgroundOptimizationIosWarning =>
      'On every iOS version, do not swipe Stroom away in the app switcher. Doing so immediately stops all running tasks.';

  @override
  String get backgroundOptimizationDesktopIntro =>
      'Desktop systems do not have the mobile platforms’ process keep-alive mechanism, but the app can continue running after its window closes.';

  @override
  String get backgroundOptimizationCloseMinimizeTitle =>
      'Minimize on Window Close';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      'When enabled, clicking the window’s close button hides the app in the system tray instead of exiting. Background tasks continue running.\n\nRestore the window from the tray icon or its “Show Main Window” menu item. To exit, use the “Quit App” button below.\n\nRecommended for all desktop users.';

  @override
  String get backgroundOptimizationQuitApp => 'Quit App';

  @override
  String get backgroundOptimizationGotIt => 'Got it';

  @override
  String get backgroundOptimizationWebNoteTitle => 'Web Background Tasks';

  @override
  String get backgroundOptimizationWebNote =>
      'Browsers cannot keep apps running in the background. Closing or refreshing this tab, or the browser freezing an inactive background tab, immediately stops running tasks. Keep the Stroom tab open and in the foreground while tasks run.';

  @override
  String get backgroundOptimizationTutorial => 'Platform Guides';

  @override
  String get backgroundOptimizationTutorialDescription =>
      'View background optimization guides for each platform';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      'Checking background service status…';

  @override
  String get backgroundOptimizationServiceUnknown =>
      'Background service status is unknown. Check again to confirm whether the service is running.';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      'The background service is running. Tasks can continue in the background.';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'Background services are not supported in web browsers. Keep this page open to continue tasks.';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      'The desktop tray is unavailable (Linux builds require libayatana-appindicator3-dev). Closing the window will exit the app.';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      'The desktop tray is unavailable. Closing the window will exit the app.';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      'The app is set to exit when the desktop window closes. It will follow the existing exit confirmation flow and will not continue running in the tray.';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      'The desktop tray is enabled. Closing the window hides the app in the system tray, where it continues running. Select “Show Main Window” in the tray menu to restore it. To exit completely, select “Quit Stroom” from the tray menu.';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      'The desktop tray is enabled. Closing the window minimizes the app to the system tray, where it continues running. Click the tray icon or select “Show Main Window” from its menu to restore the window. To exit completely, select “Quit Stroom” from the tray menu.';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      'The background service is not running. Select “Start Service” below, or view the platform guides to learn how to optimize background activity.';

  @override
  String get notificationSettingsPageTitle =>
      'Notification Permission Settings';

  @override
  String get notificationSettingsWebUnsupported =>
      'Notifications are not supported in web browsers';

  @override
  String get notificationSettingsChecking => 'Checking…';

  @override
  String get notificationSettingsPermissionGranted =>
      'Notification permission granted';

  @override
  String get notificationSettingsPermissionDenied =>
      'Notification permission not granted';

  @override
  String get notificationSettingsPermissionRestricted =>
      'Notification permission restricted';

  @override
  String get notificationSettingsPermissionBlocked =>
      'Notification permission permanently blocked';

  @override
  String get notificationSettingsPermissionProvisional =>
      'Provisional notification permission';

  @override
  String get notificationSettingsWebGuide =>
      'System notifications are not supported in web browsers.';

  @override
  String get notificationSettingsCheckingPermission =>
      'Checking notification permission…';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      'Notification permission is granted. You can enable task completion notifications to receive system alerts when a task completes or fails.';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      'Notification permission has not been granted. Select the button below to request permission, or enable notifications for Stroom in system settings.';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      'Notification permission is restricted by the system, for example by parental controls. Check Stroom’s notification settings in system settings.';

  @override
  String get notificationSettingsEnvironment => 'System Environment';

  @override
  String get notificationSettingsPermissionSection => 'Notification Permission';

  @override
  String get notificationSettingsPlatformGuides => 'Platform Guide';

  @override
  String get notificationSettingsGuideIntro =>
      'Follow these steps for your operating system to enable notifications for Stroom.';

  @override
  String get notificationSettingsTaskCompleteTitle =>
      'Task Completion Notifications';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      'Send a notification when a task completes or fails';

  @override
  String get notificationSettingsCheckAgain => 'Check Again';

  @override
  String get notificationSettingsOpenSystemSettings => 'Open System Settings';

  @override
  String get notificationSettingsRequestPermission => 'Request Permission';

  @override
  String get notificationSettingsGuideUnsupported =>
      'Notification setup guides are not available for this platform.';

  @override
  String get notificationSettingsUsageReason =>
      'To send notifications when tasks complete';

  @override
  String get notificationSettingsAndroidEnableTitle => 'Enable Notifications';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      'Go to Settings → Apps → Stroom → Notification Management and allow notifications. If you cannot find Stroom, make sure it is installed. If notifications are disabled, turn them on.';

  @override
  String get notificationSettingsAndroidDndTitle => 'Check Do Not Disturb';

  @override
  String get notificationSettingsAndroidDndDescription =>
      'Go to Settings → Sound & Vibration → Do Not Disturb. Make sure it is off or that Stroom notifications are allowed.';

  @override
  String get notificationSettingsAndroidPopupTitle =>
      'Allow Notifications to Pop Up';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'Some Android systems, such as MIUI, EMUI, and ColorOS, require “Allow notifications” and “Allow pop-ups” to be enabled in App Info. Also consider turning off “Notification filtering” or “Smart notifications” for the app.';

  @override
  String get notificationSettingsReturnTitle => 'Return to This Page';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      'After changing these settings, select “Check Again” to confirm the permission status. When permission is granted, you can enable task completion notifications.';

  @override
  String get notificationSettingsIosEnableDescription =>
      'Go to Settings → Notifications → Stroom and turn on “Allow Notifications”. Also enable Banners and Notification Center to stay up to date on task status.';

  @override
  String get notificationSettingsIosFocusTitle => 'Turn Off Focus';

  @override
  String get notificationSettingsIosFocusDescription =>
      'Go to Settings → Focus. Make sure Focus is off or add Stroom to the list of allowed apps. Focus can silence app notifications.';

  @override
  String get notificationSettingsIosReturnDescription =>
      'After changing these settings, select “Check Again” to confirm the permission status. On iOS, notification permission usually must be enabled manually in system settings.';

  @override
  String get notificationSettingsWindowsEnableTitle =>
      'Enable System Notifications';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      'Go to Settings → System → Notifications & actions and turn on “Get notifications from apps and other senders”. Find Stroom in the app list below and make sure its notifications are on.';

  @override
  String get notificationSettingsWindowsFocusTitle =>
      'Add a Focus Assist Exception';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      'Go to Settings → System → Focus Assist. Add Stroom to “Priority only” or turn Focus Assist off; Focus Assist can silence notifications.';

  @override
  String get notificationSettingsMacEnableTitle => 'Enable Notifications';

  @override
  String get notificationSettingsMacEnableDescription =>
      'Go to System Settings → Notifications → Stroom and turn on “Allow Notifications”. Also enable Banners and Notification Center.';

  @override
  String get notificationSettingsMacFocusDescription =>
      'Go to System Settings → Focus. Make sure Focus is off or add Stroom to the list of allowed apps.';

  @override
  String get notificationSettingsLinuxDesktopTitle =>
      'Check Desktop Notification Settings';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      'Depending on your desktop environment (GNOME, KDE, XFCE, etc.), go to System Settings → Notifications, find Stroom, and make sure notifications are on.';

  @override
  String get notificationSettingsLinuxDaemonTitle =>
      'Check the Notification Daemon';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux desktop environments need a notification daemon, such as notify-osd or dunst, to show system notifications. Make sure one is installed and running.';

  @override
  String get backupRestorePageTitle => 'Backup and Restore';

  @override
  String get backupRestoreSelectBackupCategory =>
      'Select at least one data category to back up';

  @override
  String get backupRestorePreparingData => 'Preparing data…';

  @override
  String get backupRestoreExportingBackup => 'Exporting backup';

  @override
  String get backupRestoreCollectingDatabase => 'Collecting database records…';

  @override
  String get backupRestoreProcessingSettings => 'Processing settings…';

  @override
  String get backupRestoreAddingTasks => 'Adding task files…';

  @override
  String get backupRestoreAddingPictures => 'Adding image files…';

  @override
  String get backupRestoreAddingAudio => 'Adding audio files…';

  @override
  String get backupRestoreAddingVideo => 'Adding video files…';

  @override
  String get backupRestoreAddingText => 'Adding text files…';

  @override
  String get backupRestoreAddingChat => 'Adding chat history and attachments…';

  @override
  String get backupRestoreCompressing => 'Compressing archive…';

  @override
  String get backupRestoreCompleted => 'Complete';

  @override
  String get backupRestoreSelectRestoreCategory =>
      'Select at least one data category to restore';

  @override
  String get backupRestoreConfirmRestore => 'Confirm Restore';

  @override
  String get backupRestoreSelectedCategories => 'Selected data categories:';

  @override
  String get backupRestoreRestoreInfo =>
      'Selected categories found in the backup will be restored to this device. All categories except built-in browser cookies replace the corresponding local data. Cookies are written by domain, name, and path; local cookies not included in the backup are preserved. Unselected categories and categories missing from the backup remain unchanged. Missing categories are skipped with a notice.';

  @override
  String get backupRestoreRestartNotice =>
      'Restart the app after restoring for the changes to take effect. Make sure your current work is saved.';

  @override
  String get backupRestoreCancel => 'Cancel';

  @override
  String get backupRestoreConfirmRestoreButton => 'Restore';

  @override
  String get backupRestoreIncompleteTitle => 'Restore Incomplete';

  @override
  String get backupRestoreIncompleteMessage =>
      'Data could not be fully restored and some data may have been cleared. Restart the app and try again.';

  @override
  String get backupRestoreSelectClearCategory =>
      'Select at least one data category to clear';

  @override
  String get backupRestoreClearingData => 'Clearing Data';

  @override
  String get backupRestoreDeletingCategories =>
      'Deleting selected data categories…';

  @override
  String get backupRestoreClearedTitle => 'Data Cleared';

  @override
  String get backupRestorePartiallyClearedTitle => 'Some Data Cleared';

  @override
  String get backupRestoreClearedMessage =>
      'Selected data was cleared. Restart the app for the changes to take effect.';

  @override
  String get backupRestorePartialClearMessage =>
      'Other selected data was cleared. This platform cannot fully clear built-in browser website storage (localStorage, IndexedDB, etc.), so browser data that could not be cleared remains. Restart the app for the cleared data to take effect.';

  @override
  String backupRestoreClearFailed(String error) {
    return 'Could not clear data: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => 'Clear Incomplete';

  @override
  String get backupRestoreClearIncompleteMessage =>
      'Some data could not be cleared. Restart the app and try clearing it again.';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki deck exported to: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get backupRestoreApkgRequired => 'Select an .apkg file';

  @override
  String backupRestoreImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get backupRestoreRestoreSuccessTitle => 'Data Restored';

  @override
  String get backupRestoreRestoredMessage =>
      'Data was restored from the backup. Restart the app to use the restored data.';

  @override
  String get backupRestoreExitApp => 'Quit App';

  @override
  String get backupRestoreRestartNow => 'Restart Now';

  @override
  String get backupRestoreSkippedTitle => 'Some Data Skipped';

  @override
  String get backupRestoreNothingRestoredTitle => 'No Data Restored';

  @override
  String get backupRestoreGotIt => 'Got it';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return 'The backup did not confirm restorable content for these selected categories, so they were skipped and existing data was kept: $categories.';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      'In older backups, an empty task file cannot distinguish an empty task list from tasks not exported by that platform. To avoid overwriting current tasks, the task category was skipped and existing data was kept.';

  @override
  String get backupRestoreSkippedCookies =>
      'The backup contains no built-in browser cookies to import, so this category was skipped and existing cookies were kept.';

  @override
  String get backupRestoreSkippedWebsiteData =>
      'The website storage directory in this older backup was skipped. Cookies can still be imported separately if the archive contains them and that category is selected.';

  @override
  String get backupRestoreApkgTitle => 'Anki Deck';

  @override
  String get backupRestoreApkgInfoTitle => 'Import or Export an Anki Deck';

  @override
  String get backupRestoreApkgInfoMessage =>
      'Includes card information only, not media';

  @override
  String get backupRestoreApkgDescription =>
      'Import or export Anki decks in .apkg format';

  @override
  String get backupRestoreExportingApkg => 'Exporting…';

  @override
  String get backupRestoreExportApkg => 'Export .apkg';

  @override
  String get backupRestoreImportingApkg => 'Importing…';

  @override
  String get backupRestoreImportApkg => 'Import .apkg';

  @override
  String get backupRestoreCategoryHeading =>
      'Choose Data Categories to Back Up or Restore';

  @override
  String get backupRestoreExporting => 'Exporting…';

  @override
  String get backupRestoreExportBackup => 'Export Backup';

  @override
  String get backupRestoreRestoring => 'Restoring…';

  @override
  String get backupRestoreChooseBackup => 'Choose Backup File and Restore';

  @override
  String get backupRestoreClearSelected => 'Clear Selected Data';

  @override
  String get backupRestoreClearDescription =>
      'Clear the selected data categories directly without a backup file. Unselected categories will remain unchanged. This action cannot be undone.';

  @override
  String get backupRestoreClearing => 'Clearing…';

  @override
  String get backupRestoreCategoryChat => 'Chat History and Attachments';

  @override
  String get backupRestoreCategoryChatDescription =>
      'Chat conversations, message content, and attachments';

  @override
  String get backupRestoreCategorySettings => 'Settings';

  @override
  String get backupRestoreCategorySettingsDescription =>
      'App configuration, provider settings, and interface preferences';

  @override
  String get backupRestoreCategoryPictures => 'Images';

  @override
  String get backupRestoreCategoryPicturesDescription =>
      'Photos and thumbnails';

  @override
  String get backupRestoreCategoryAudio => 'Audio';

  @override
  String get backupRestoreCategoryAudioDescription =>
      'Speech synthesis and recordings';

  @override
  String get backupRestoreCategoryVideos => 'Videos';

  @override
  String get backupRestoreCategoryVideosDescription => 'Video files';

  @override
  String get backupRestoreCategoryTexts => 'Text';

  @override
  String get backupRestoreCategoryTextsDescription => 'Text documents';

  @override
  String get backupRestoreCategoryTasks => 'Tasks';

  @override
  String get backupRestoreCategoryTasksDescription => 'Background task records';

  @override
  String get backupRestoreCategoryAnki => 'Anki Flashcard Data';

  @override
  String get backupRestoreCategoryAnkiDescription => 'Anki database';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki Flashcard Data';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Backing up or restoring Anki flashcard data also includes card media in the collection.media directory.';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'About Anki Flashcard Data';

  @override
  String get backupRestoreCategoryBrowser => 'Built-in Browser Data';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      'Backs up and restores cookies only; clearing also removes supported website storage';

  @override
  String get backupRestoreViewInfo => 'View information';

  @override
  String get backupRestoreApkgInfoTooltip =>
      'About Anki Deck Import and Export';

  @override
  String get backupRestoreConfirmClear => 'Confirm Clear';

  @override
  String get backupRestoreClearCategoriesIntro =>
      'The following data categories will be cleared without using a backup file:';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      'This platform cannot fully clear built-in browser website storage (localStorage, IndexedDB, etc.). Confirming clears the other selected data; browser data that cannot be cleared will remain.';

  @override
  String get backupRestoreUnselectedUnchanged =>
      'Unselected categories will remain unchanged.';

  @override
  String get backupRestoreClearWarning =>
      'This action cannot be undone. Restart the app after clearing for the changes to take effect.';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return 'Clear ($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => 'Browser environment';

  @override
  String get backupRestoreIntro =>
      'Export selected data categories manually. During import, only selected categories found in the archive are restored. A missing category or required file is skipped with a notice, and unselected categories remain unchanged. You can also clear selected categories directly.';

  @override
  String get backupRestoreOtherSelectedRestored =>
      'The other selected data was restored. Restart the app for the changes to take effect.';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      'Notifications are blocked. Open system settings and allow notifications for Stroom.';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      'Notifications are blocked. Go to System Settings → Apps → Stroom → Notification Management and allow notifications.';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      'Notifications are blocked. Go to System Settings → Stroom → Notifications and allow notifications.';

  @override
  String get textPreviewDiscardEditsTitle => 'Discard edits?';

  @override
  String get textPreviewUnsavedChangesConfirm =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get textPreviewCancel => 'Cancel';

  @override
  String get textPreviewDiscard => 'Discard';

  @override
  String get textPreviewFontSize => 'Adjust font size';

  @override
  String get textPreviewRestoreDefault => 'Restore default';

  @override
  String get textPreviewClose => 'Close';

  @override
  String textPreviewSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get textPreviewUndo => 'Undo';

  @override
  String get textPreviewRedo => 'Redo';

  @override
  String get textPreviewSave => 'Save';

  @override
  String get textPreviewEdit => 'Edit';

  @override
  String get textPreviewChartEdit => 'Edit chart';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return 'Skipped unsupported format: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# text files',
      one: '# text file',
    );
    return 'Imported $_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get textStorageSaved => 'Text saved';

  @override
  String get textStorageLoadFailed => 'Unable to load text content';

  @override
  String get textStorageReadFailed => 'Failed to read file data';

  @override
  String get textStorageExportTitle => 'Export text';

  @override
  String textStorageExportedTo(String path) {
    return 'Exported to: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get textStorageChooseExportDirectory => 'Choose export directory';

  @override
  String get textStorageFolderExportTitle => 'Export folder';

  @override
  String get textStorageWebFolderExportInfo =>
      'The browser cannot select an export directory. A ZIP file that preserves the folder structure will be downloaded.';

  @override
  String get textStorageCancel => 'Cancel';

  @override
  String get textStorageDownloadZip => 'Download ZIP file';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# files',
      one: '# file',
    );
    return 'Exported $_temp0';
  }

  @override
  String get textStorageExportFolderTitle => 'Export text folder';

  @override
  String textStorageCopyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String get textStorageCreateNew => 'New';

  @override
  String get textStorageImport => 'Import';

  @override
  String get textStorageTitle => 'Text';

  @override
  String get textStorageExportToLocal => 'Export to local';

  @override
  String get textCreateEnterTitle => 'Please enter a title';

  @override
  String textCreateSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get textCreateNewTitle => 'New';

  @override
  String get textCreateSave => 'Save';

  @override
  String get textCreateTitleLabel => 'Title';

  @override
  String get textCreateTitleHint => 'Enter text title';

  @override
  String get textCreateFormatLabel => 'Format';

  @override
  String get textCreateContentLabel => 'Text content';

  @override
  String get textCreateContentHint => 'Enter text content...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform background optimization tutorial';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform background running guide';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform background optimization guide';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return 'These steps can help optimize Stroom’s background experience on $platform devices so tasks can continue running in the background.';
  }

  @override
  String get platformTutorialStepsHeading => 'Optimization steps';

  @override
  String get platformTutorialTipsHeading => 'Tip';

  @override
  String get platformTutorialTipsDescription =>
      'After completing these settings, return to the “Background Optimization” page and check that the status has updated. If you still have problems, see another platform’s guide or report the issue on GitHub.';

  @override
  String get platformTutorialAndroidStep1Title =>
      'Turn off battery optimization';

  @override
  String get platformTutorialAndroidStep1Description =>
      'Open Settings → Apps → Stroom → Battery, then choose “Unrestricted” or “Don’t optimize.” You can also tap “Ignore battery optimization” on this app’s “Background Optimization” page to add Stroom to the system power-saving allowlist. Paths vary by device brand.';

  @override
  String get platformTutorialAndroidStep2Title => 'Allow background activity';

  @override
  String get platformTutorialAndroidStep2Description =>
      'Open Settings → Apps → Stroom and enable “Allow background activity” and “Allow auto-start.” Some phones also require allowing auto-start in Security Center or Phone Manager.';

  @override
  String get platformTutorialAndroidStep3Title => 'Lock the background process';

  @override
  String get platformTutorialAndroidStep3Description =>
      'In the recent-apps view, swipe down on the Stroom card or tap its lock icon to prevent the system from clearing the app.';

  @override
  String get platformTutorialAndroidStep4Title =>
      'Allow notifications (Android 13+)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 and later require notification permission. Without it, the foreground notification for the background service is hidden, though the service still runs. The app requests permission when you first tap “Start service,” or you can enable it in Settings → Apps → Stroom → Notifications.';

  @override
  String get platformTutorialAndroidStep5Title => 'Ignore battery optimization';

  @override
  String get platformTutorialAndroidStep5Description =>
      'When you enable “Task completion notifications” in Stroom, the app requests the related permission. You can also check that Stroom is set to “Don’t optimize” in Settings → Apps → Special app access → Battery optimization.';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Auto-start and background management on Android devices';

  @override
  String get platformTutorialAndroidStep6Description =>
      'Device manufacturers often add their own background controls:\n• Xiaomi/Redmi (MIUI/HyperOS): Settings → Apps → Permissions → Autostart; allow Stroom. Then open Battery → App battery saver → Stroom → No restrictions.\n• Huawei/Honor (EMUI/HarmonyOS): Settings → Apps → App launch → Stroom → Manage manually; allow auto-launch, secondary launch, and background activity.\n• OPPO/OnePlus/realme (ColorOS): Settings → Battery → App battery management → Stroom; allow full background activity.\n• vivo/iQOO (OriginOS): iManager → App management → Autostart; allow Stroom.';

  @override
  String get platformTutorialAndroidStep7Title =>
      'Turn off lock-screen cleanup and power-saving modes';

  @override
  String get platformTutorialAndroidStep7Description =>
      'Open Settings → Battery and turn off “Power saving” or “Ultra power saving.” Also set “Clear memory after locking” to “Don’t clear.” Power-saving modes restrict background activity and may affect task completion.';

  @override
  String get platformTutorialIosStep1Title => 'Enable Background App Refresh';

  @override
  String get platformTutorialIosStep1Description =>
      'Open Settings → General → Background App Refresh, find Stroom, and turn it on. Choose “Wi-Fi & Cellular Data” for the best experience.';

  @override
  String get platformTutorialIosStep2Title => 'Allow notifications';

  @override
  String get platformTutorialIosStep2Description =>
      'Open Settings → Notifications → Stroom and turn on “Allow Notifications.” Enable both banners and Notification Center so you can see task updates promptly.';

  @override
  String get platformTutorialIosStep3Title => 'Turn off Low Power Mode';

  @override
  String get platformTutorialIosStep3Description =>
      'Open Settings → Battery and turn off “Low Power Mode.” The system restricts background activity while this mode is on.';

  @override
  String get platformTutorialIosStep4Title =>
      'Understand iOS background limits';

  @override
  String get platformTutorialIosStep4Description =>
      'Versions before iOS 26 do not allow apps to stay in the background like Android apps. The system gives apps brief execution time only at certain times, such as Background App Refresh, location updates, or audio playback, and may suspend long-running tasks. We recommend:\n• Keep Stroom in the foreground for long-running tasks.\n• Return to the app periodically to refresh its background time.\n• Turn on “Task completion notifications” for important tasks.';

  @override
  String get platformTutorialIosStep5Title => 'Background tips while tasks run';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 and later support persistent background tasks. Tasks usually continue if you switch apps or lock the screen, though the system may stop them when resources are scarce; progress appears on the Lock Screen.\n\nEarlier iOS versions do not support persistent background tasks. Return to the app every few minutes (5–10 minutes is a guideline; the system decides) to refresh background time and prevent suspension.\n\nOn every version, do not swipe Stroom away in the app switcher; doing so immediately stops all running tasks.';

  @override
  String get platformTutorialIosStep6Title => 'Keep the app in the foreground';

  @override
  String get platformTutorialIosStep6Description =>
      'On versions earlier than iOS 26, apps have limited background time. For long-running tasks, keep Stroom in the foreground or return to it periodically to extend that time.';

  @override
  String get platformTutorialWindowsStep1Title =>
      'Minimize when closing the window';

  @override
  String get platformTutorialWindowsStep1Description =>
      'By default, clicking the window’s close button minimizes Stroom to the system tray (near the clock) so it can keep running. Restore it from the tray icon or “Show main window” menu. Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the tray menu.';

  @override
  String get platformTutorialWindowsStep2Title => 'Turn off Battery Saver';

  @override
  String get platformTutorialWindowsStep2Description =>
      'Open Settings → System → Power & sleep and turn off Battery Saver. Alternatively, configure it to turn on only when the battery falls below a chosen level.';

  @override
  String get platformTutorialWindowsStep3Title => 'Allow background apps';

  @override
  String get platformTutorialWindowsStep3Description =>
      'Open Settings → Privacy & security → Background apps, find Stroom, and make sure it is enabled. On Windows 11, go to Settings → Apps → Installed apps → Stroom → Advanced options → Background app permissions and choose “Always.”';

  @override
  String get platformTutorialWindowsStep4Title =>
      'Turn off sleep mode (optional)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'To keep Stroom running for long periods, open Settings → System → Power and set “Sleep” to “Never” (when plugged in only).';

  @override
  String get platformTutorialWindowsStep5Title => 'Add Stroom to startup';

  @override
  String get platformTutorialWindowsStep5Description =>
      'Open Task Manager (Ctrl+Shift+Esc) → Startup, find Stroom, and right-click “Enable.” Or open Settings → Apps → Startup and turn on Stroom.';

  @override
  String get platformTutorialMacosStep1Title =>
      'Minimize when closing the window';

  @override
  String get platformTutorialMacosStep1Description =>
      'By default, closing the window keeps Stroom running in the menu bar (top-right of the screen). Click its menu bar icon or choose “Show main window” to restore it. Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the menu bar menu.';

  @override
  String get platformTutorialMacosStep2Title => 'Allow notifications';

  @override
  String get platformTutorialMacosStep2Description =>
      'Open System Settings → Notifications → Stroom and turn on “Allow Notifications.” We recommend enabling both banners and Notification Center.';

  @override
  String get platformTutorialMacosStep3Title =>
      'Turn off Low Power Mode (MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      'Open System Settings → Battery → Power Adapter and turn off “Low Power Mode.” This mode restricts background activity.';

  @override
  String get platformTutorialMacosStep4Title => 'Keep the app active';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS places few restrictions on background apps. For long-running tasks, leave the Stroom window open. Avoid force-quitting the app; closing the window is enough.';

  @override
  String get platformTutorialMacosStep5Title => 'Launch at login (optional)';

  @override
  String get platformTutorialMacosStep5Description =>
      'Open System Settings → General → Login Items and add Stroom so it starts automatically when your computer starts.';

  @override
  String get platformTutorialLinuxStep1Title =>
      'Minimize when closing the window';

  @override
  String get platformTutorialLinuxStep1Description =>
      'By default, closing the window hides Stroom in the system tray (requires a desktop environment with StatusNotifierItem support and libayatana-appindicator3-dev at build time). Restore it from the tray menu using “Show main window.” Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the tray menu.';

  @override
  String get platformTutorialLinuxStep2Title => 'Desktop environment settings';

  @override
  String get platformTutorialLinuxStep2Description =>
      'Depending on your desktop environment (GNOME, KDE, XFCE, etc.), open System Settings → Apps, find Stroom, and make sure background activity is not restricted.';

  @override
  String get platformTutorialLinuxStep3Title =>
      'Use a systemd service (optional)';

  @override
  String get platformTutorialLinuxStep3Description =>
      'For long-running background work, create a systemd user service. Create a stroom.service file under ~/.config/systemd/user/ and set ExecStart to the Stroom executable.';

  @override
  String get platformTutorialLinuxStep4Title => 'Disable sleep';

  @override
  String get platformTutorialLinuxStep4Description =>
      'For a server or desktop that needs to run for a long time, set HandleLidSwitch=ignore in /etc/systemd/logind.conf to prevent sleep when the lid closes.';

  @override
  String get platformTutorialLinuxStep5Title => 'Enable autostart';

  @override
  String get platformTutorialLinuxStep5Description =>
      'In GNOME, use Tweaks → Startup Applications → Add Stroom. Or create a stroom.desktop file under ~/.config/autostart/.';

  @override
  String get platformTutorialWebStep1Title => 'Keep the tab open';

  @override
  String get platformTutorialWebStep1Description =>
      'Web browsers do not support background services. Keep the Stroom tab open while tasks run; closing the tab or refreshing the page immediately interrupts them.';

  @override
  String get platformTutorialWebStep2Title =>
      'Prevent the browser from suspending the tab';

  @override
  String get platformTutorialWebStep2Description =>
      'Browsers may freeze inactive background tabs to save resources. Keep the Stroom tab in the foreground while tasks run, or interact with the page periodically to keep it active.';

  @override
  String get browserNavigationFailed =>
      'Page navigation failed; address restored';

  @override
  String get browserAddressHint => 'Enter a web address';

  @override
  String get browserUserScripts => 'User scripts';

  @override
  String get browserSwitchToMobile => 'Switch to mobile view';

  @override
  String get browserSwitchToDesktop => 'Switch to desktop view';

  @override
  String get browserUaSwitchedDesktop => 'Switched to desktop user agent';

  @override
  String get browserUaSwitchedMobile => 'Switched to mobile user agent';

  @override
  String get browserCookieRetentionOnTooltip => 'Cookie persistence (on)';

  @override
  String get browserCookieRetentionOffTooltip => 'Cookie persistence (off)';

  @override
  String get browserCookiePersistenceEnabled => 'Cookie persistence enabled';

  @override
  String get browserCookiePersistenceDisabled => 'Cookie persistence disabled';

  @override
  String get browserSniffPanelHideTooltip => 'Hide sniff panel';

  @override
  String get browserSniffPanelShowTooltip => 'Show sniff panel';

  @override
  String get browserAdd => 'Add';

  @override
  String get browserNoScripts => 'No scripts yet. Tap “Add” to create one.';

  @override
  String get browserUnnamedScript => 'Untitled script';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matching rules',
      one: '$count matching rule',
    );
    return '$_temp0';
  }

  @override
  String get browserEditScript => 'Edit script';

  @override
  String get browserScriptName => 'Script name';

  @override
  String get browserScriptCode => 'Script code (JavaScript)';

  @override
  String get browserMatchUrls => 'URL patterns (one per line)';

  @override
  String get browserScriptMatchHint => '*://*.example.com/*';

  @override
  String get browserCancel => 'Cancel';

  @override
  String get browserSave => 'Save';

  @override
  String get browserCookiesConfirmClear => 'Confirm clearing';

  @override
  String get browserCookiesConfirmClearAll =>
      'Clear all cookies?\nThis action cannot be undone.';

  @override
  String get browserCookiesClear => 'Clear';

  @override
  String get browserCookiesCancel => 'Cancel';

  @override
  String get browserCookiesClearedAll => 'All cookies cleared';

  @override
  String get browserCookiesClearFailed => 'Could not clear. Try again.';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return 'All cookies for $domain cleared';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return 'Clear all cookies for $domain?';
  }

  @override
  String get browserCookiesPageTitle => 'Browser data management';

  @override
  String get browserCookiesRetentionTitle => 'Keep cookies when exiting';

  @override
  String get browserCookiesRetentionOn =>
      'Enabled — cookies are kept when exiting';

  @override
  String get browserCookiesRetentionOff =>
      'Disabled — cookies are cleared when exiting';

  @override
  String get browserCookiesClearAllTitle => 'Clear all cookies';

  @override
  String get browserCookiesClearAllDescription =>
      'Delete all saved website cookies';

  @override
  String get browserCookiesEmptyTitle => 'No persistent data';

  @override
  String get browserCookiesEmptyDescription =>
      'Use the built-in browser and enable cookie persistence to see saved data here.';

  @override
  String browserCookiesStoredCount(Object count) {
    return 'Stored cookies ($count)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cookies',
      one: '$count cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip =>
      'Clear all cookies for this domain';

  @override
  String get browserCookiesDeleteOneTooltip => 'Delete this cookie';

  @override
  String get browserCookiesDeletedOne => 'Cookie deleted';

  @override
  String get browserCookiesDeleteFailed => 'Could not delete. Try again.';

  @override
  String get browserCookiesEmptyValue => '(empty value)';

  @override
  String get platformTutorialPageTitle => 'Platform tutorials';

  @override
  String get browserRecoveryOpenPage => 'Open recovery page';

  @override
  String galleryUnsupportedPreview(String format) {
    return 'Preview is not supported for .$format files';
  }

  @override
  String galleryCameraFailed(String error) {
    return 'Could not take a photo: $error';
  }

  @override
  String get galleryPhotoSaved => 'Photo saved';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return 'Skipped unsupported format: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# images',
      one: '# image',
    );
    return 'Imported $_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# videos',
      one: '# video',
    );
    return 'Imported $_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get galleryFileReadFailed => 'Could not read file data';

  @override
  String get galleryExportImageTitle => 'Export image';

  @override
  String get galleryExportVideoTitle => 'Export video';

  @override
  String galleryExportedTo(String path) {
    return 'Exported to: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get galleryChooseExportDirectory => 'Choose export directory';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# files',
      one: '# file',
    );
    return 'Exported $_temp0';
  }

  @override
  String get galleryFolderExportTitle => 'Export folder';

  @override
  String get galleryWebFolderExportInfo =>
      'The browser cannot select an export directory. A ZIP file that preserves the folder structure will be downloaded.';

  @override
  String get galleryDownloadZip => 'Download ZIP file';

  @override
  String get galleryExportImageFolderTitle => 'Export image folder';

  @override
  String get galleryExportVideoFolderTitle => 'Export video folder';

  @override
  String get galleryImagePageTitle => 'Gallery';

  @override
  String get galleryVideoPageTitle => 'Videos';

  @override
  String get galleryTakePhoto => 'Take photo';

  @override
  String get galleryRecordVideo => 'Record';

  @override
  String get galleryImport => 'Import';

  @override
  String get galleryExportToLocal => 'Export to local';

  @override
  String get galleryPlayVideo => 'Play';

  @override
  String galleryCopyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String get galleryVideoSaved => 'Video saved';

  @override
  String galleryVideoRecordFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String get galleryVideoLoadFailed => 'Could not load video';

  @override
  String get imageEditorSaveImageTitle => 'Save image';

  @override
  String get imageEditorSaveImagePrompt => 'Choose how to save the image:';

  @override
  String get imageEditorOverwrite => 'Overwrite';

  @override
  String get imageEditorSaveAs => 'Save as';

  @override
  String get imageEditorSavePhotoTitle => 'Save photo';

  @override
  String get imageEditorSavePhotoPrompt => 'Save this photo?';

  @override
  String get imageEditorDiscard => 'Discard';

  @override
  String get imageEditorDoneLoading => 'Generating image. Please wait…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return 'Quick edit – $fileName';
  }

  @override
  String get imageEditorNotReady =>
      'The editor is not ready. Please try again in a moment.';

  @override
  String imageEditorProcessingFailed(String error) {
    return 'Could not process image: $error';
  }

  @override
  String get imageEditorLoadFailed => 'Could not load image';

  @override
  String get imageEditorProcessing => 'Processing image. Please wait…';

  @override
  String get imageEditorRotateLeft => 'Rotate left';

  @override
  String get imageEditorRotateRight => 'Rotate right';

  @override
  String get imageEditorFlip => 'Flip';

  @override
  String get imageEditorCrop => 'Crop';

  @override
  String get imageViewerImageSavedAsCopy => 'Image saved as a copy';

  @override
  String get imageViewerImageUpdated => 'Image updated';

  @override
  String imageViewerSaveFailed(String error) {
    return 'Could not save image: $error';
  }

  @override
  String get imageViewerInvalidIndex => 'Invalid image index';

  @override
  String get galleryExportImageArchiveFileName => 'image-export.zip';

  @override
  String get galleryExportVideoArchiveFileName => 'video-export.zip';

  @override
  String get galleryExportImageFolderArchiveFileName =>
      'image-folder-export.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName =>
      'video-folder-export.zip';

  @override
  String get catCatchPageTitle => 'Web Resource Downloader';

  @override
  String get catCatchAddTask => 'Add task';

  @override
  String get catCatchOpenBrowser => 'Built-in browser';

  @override
  String get catCatchEmptyState => 'No download tasks yet';

  @override
  String get catCatchEmptyStateHint =>
      'Tap + in the top right to add a download task';

  @override
  String get catCatchInvalidCapturedUrl => 'The captured URL is invalid';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return 'Captured from browser: $url';
  }

  @override
  String get catCatchEnterValidUrl => 'Enter at least one valid URL';

  @override
  String get catCatchTaskAdded => 'Task added';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks added',
      one: '$count task added',
    );
    return '$_temp0';
  }

  @override
  String get catCatchViewTaskList => 'View task list';

  @override
  String get catCatchUrlHint => 'Enter a video/audio webpage URL';

  @override
  String get catCatchDeleteTask => 'Delete this task';

  @override
  String get catCatchHour => 'Hours';

  @override
  String get catCatchMinute => 'Minutes';

  @override
  String get catCatchSecond => 'Seconds';

  @override
  String get catCatchDurationPreview => 'Preview: ';

  @override
  String get catCatchDurationFormat => 'hr:min:sec';

  @override
  String get catCatchDurationFilterHint =>
      'Optional: filter video resources by duration. Leave blank to show all resources for selection';

  @override
  String get catCatchVideoSaveTo => 'Save video to';

  @override
  String get catCatchAudioSaveTo => 'Save audio to';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks added',
      one: '$count task added',
    );
    return '$_temp0';
  }

  @override
  String get catCatchStartAnalysis => 'Analyze';

  @override
  String get catCatchVideoFolderTitle => 'Video save folder';

  @override
  String get catCatchAudioFolderTitle => 'Audio save folder';

  @override
  String get catCatchRootFolder => 'Root folder';

  @override
  String connectivityTestTitle(String title) {
    return '$title · Connectivity Test';
  }

  @override
  String get connectivityTestJsonLabel => 'Test content (JSON)';

  @override
  String get connectivityTestJsonHelp =>
      'You can run or save changes directly. MCP uses read-only tools/list; search tools can change query/count; Todo is read-only by default.';

  @override
  String connectivityTestSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get connectivityTestSaved => 'Test content saved';

  @override
  String get connectivityTestClose => 'Close';

  @override
  String get connectivityTestSaveContent => 'Save Content';

  @override
  String get connectivityTestTesting => 'Testing…';

  @override
  String get connectivityTestRun => 'Run Test';

  @override
  String get connectivityTestFailedSummary => 'Test could not be completed';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds sec';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get messageSearchTitle => 'Search Messages';

  @override
  String get messageSearchHint => 'Search messages across all conversations...';

  @override
  String get messageSearchInitialState =>
      'Type a keyword to search messages in all conversations';

  @override
  String get messageSearchEmptyState => 'No matching messages found';

  @override
  String get messageSearchNewConversation => 'New conversation';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '$count match',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => 'Text';

  @override
  String get filesTabAudio => 'Audio';

  @override
  String get filesTabImages => 'Images';

  @override
  String get filesTabVideos => 'Videos';

  @override
  String get filesReorderTabs => 'Reorder Tabs';

  @override
  String get filesReorderCancel => 'Cancel';

  @override
  String get filesReorderDone => 'Done';

  @override
  String get bgTaskCancelled => 'Canceled';

  @override
  String bgTaskAsrError(String details) {
    return 'Speech transcription failed: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return 'Saving speech transcription failed: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR failed: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'Saving OCR results failed: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR result is incomplete: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => 'Some OCR pages were not completed';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return ' · phase $phaseElapsedMs ms · $completedRequests requests · $completedChunks/$chunkCount chunks completed';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return 'Uploading audio$chunk $percent% · $bytes bytes$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return 'Uploading audio$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return ' (chunk $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return 'Transcribing$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return 'Transcribing (chunk $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return 'Transcribing (receiving chunk $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return 'Receiving result $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => 'Receiving result';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return 'Transcribing ($index/$count chunks completed)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return 'Transcribing (chunk $index/$count returned)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return 'Image $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return 'Uploading $details';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return 'Uploading images $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR recovery checkpoint could not be saved; the request outcome is uncertain and the task was stopped: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR recovery checkpoint could not be saved; this chunk was not sent and can be retried after fixing local storage: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'ASR chunk state could not be saved before cancellation; this chunk outcome remains uncertain: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'Could not save ASR retry audio; the task was not sent: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError =>
      'Another audio file could not be saved; sending was canceled';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR returned an incomplete result (finish_reason=$finishReason)';
  }

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return 'Some images were not fully recognized: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return 'Image $index: incomplete result';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return 'Image $index: recognition failed';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => '; ';

  @override
  String get bgTaskInterruptedOnRestart => 'Interrupted when the app restarted';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR error details were hidden';

  @override
  String get bgTaskErrorDetailsHidden => 'Error details were hidden';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return 'Task completed: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return 'Task failed: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title completed';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title failed: $error';
  }

  @override
  String get notificationUnknownError => 'Unknown error';

  @override
  String get desktopTrayTooltip => 'Stroom is running in the background';

  @override
  String get desktopTrayOpen => 'Open Stroom';

  @override
  String get desktopTrayShowMainWindow => 'Show Main Window';

  @override
  String get desktopTrayQuitStroom => 'Quit Stroom';

  @override
  String get providerPresetExaDescription =>
      'Search the web, extract page content, and support in-depth research through Exa MCP, with semantic and keyword search.';

  @override
  String get providerPresetExaApiKeyHint =>
      'Get an API key from the Exa website.';

  @override
  String get providerPresetTavilyDescription =>
      'An AI-native search engine for real-time web search optimized for large language models.';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Get an API key from Tavily. It supports ?tavilyApiKey= or an Authorization: Bearer header.';

  @override
  String get providerPresetJinaDescription =>
      'A multimodal AI service for extracting web content, generating embeddings, and retrieving search results.';

  @override
  String get providerPresetJinaApiKeyHint =>
      'Get a Jina AI API key (Bearer token) from its website.';

  @override
  String get providerPresetFirecrawlDescription =>
      'A web crawling and extraction service that turns pages into clean Markdown or structured data.';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Get a Firecrawl API key, or try it without a key with the free tier limits.';

  @override
  String get providerPresetZhipuDescription =>
      'Zhipu AI’s web reader MCP service for fetching and understanding web pages.';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Get an API key (Bearer token) from the Zhipu AI Open Platform.';

  @override
  String get providerPresetBraveSearchDescription =>
      'A privacy-focused independent search engine with high-quality web results.';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Get an API key from the Brave Search website.';

  @override
  String get providerPresetBochaDescription =>
      'Bocha AI web search provides intelligent search results for Chinese-language pages.';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Get an API key (Bearer token) from the Bocha AI Open Platform.';

  @override
  String get providerPresetQueritDescription =>
      'Querit AI search offers intelligent search and content discovery.';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Get an API key (Bearer token) from the Querit website.';

  @override
  String get providerPresetSearxngDescription =>
      'A self-hosted metasearch engine that aggregates search sources with a focus on privacy.';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'Set your SearXNG instance URL (for example, http://your-instance:8080); an API key is optional.';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS synthesis failed: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '\nOriginal error: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      'Network connection timed out. Check your network or API address.';

  @override
  String get ttsErrorServerResponseTimeout =>
      'The server response timed out. Try again later.';

  @override
  String ttsErrorConnectionFailed(String details) {
    return 'Unable to connect to the server ($details)';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return 'Unable to connect to the server. Common causes in the web app: CORS restrictions or an incorrect API address. $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API returned an error (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return 'Connection timed out. Check your network$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return 'Receive timed out; the server is responding slowly$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API key is invalid or permission denied (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return 'Too many requests; try again later (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API endpoint not found (HTTP $status): $body\nCheck that the API base URL is correct$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return 'Internal server error (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return 'Server returned an error (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return 'Request cancelled$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return 'Unable to connect to the server. Common causes in the web app: CORS restrictions or an incorrect API address. Check that the provider API address is correct and that the server allows cross-origin requests.$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return 'Network error: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => 'Unknown network error';

  @override
  String get ttsErrorNoResponseBody => 'No response body';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return 'Streaming synthesis failed: $details';
  }

  @override
  String get mermaidEditorTitle => 'Mermaid Chart Editor';

  @override
  String get mermaidEditorModeEdit => 'Edit';

  @override
  String get mermaidEditorModeSplit => 'Edit + Preview';

  @override
  String get mermaidEditorModePreview => 'Preview';

  @override
  String get mermaidEditorSwitchViewMode => 'Switch view mode';

  @override
  String get mermaidEditorSaveToTextStorage => 'Save to Text Storage';

  @override
  String get mermaidEditorEmptyChart =>
      'Chart content is empty and cannot be saved';

  @override
  String get mermaidEditorSaveChartTitle => 'Save chart';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      'Choose or create a folder to save the .mmd chart file';

  @override
  String get mermaidEditorFileNameHint =>
      'Enter a filename (.mmd added automatically)';

  @override
  String get mermaidEditorEmptyFileName => 'Filename cannot be empty';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return 'Saved to text storage: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor =>
      'Swap preview and editor panels';

  @override
  String get mermaidEditorCodeLabel => 'Mermaid code';

  @override
  String get mermaidEditorCodeHint => 'Enter Mermaid code...';

  @override
  String get mermaidEditorSplitCodeLabel => 'Code';
}
