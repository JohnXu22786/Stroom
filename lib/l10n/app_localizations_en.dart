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
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

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
}
