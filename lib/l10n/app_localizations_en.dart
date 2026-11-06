Warning: truncated output (original token count: 130442)
Total output lines: 18452

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
  String get homeRe…110442 tokens truncated…esponding local data. Cookies are written by domain, name, and path; local cookies not included in the backup are preserved. Unselected categories and categories missing from the backup remain unchanged. Missing categories are skipped with a notice.';

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
}
