Warning: truncated output (original token count: 156919)
Total output lines: 22056

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get galleryPermissionTitle => 'Photo library access required';

  @override
  String get galleryPermissionMessage =>
      'Allow Stroom to access photos and videos in system settings.';

  @override
  String get galleryPermissionCancel => 'Cancel';

  @override
  String get galleryPermissionOpenSettings => 'Open settings';

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
  String get languageSearchHint => 'Search languages';

  @override
  String get languageNoMatches => 'No matching languages';

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
  String get ocrDefaultSystemPrompt =>
      'Extract all text from the image, preserving its original formatting and layout. Return only the extracted text; do not add any explanation.';

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
  String get ocrInstructionManageGuidance =>
      'These instructions apply to all recognition models. If none is selected, only the image is sent.';

  @override
  String get ocrInstructionManageEmpty => 'No instructions yet';

  @override
  String get ocrInstructionEditTooltip => 'Edit instruction';

  @override
  String get ocrInstructionDeleteTooltip => 'Delete instruction';

  @override
  String get ocrInstructionAdd => 'Add instruction';

  @override
  String get ocrInstructionEditorEditTitle => 'Edit instruction';

  @override
  String get ocrInstructionNameLabel => 'Instruction name (optional)';

  @override
  String get ocrInstructionContentLabel => 'Instruction content';

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
  String topicAssistantUpdateCheckFailed(Object error) =>
      'Assistant update check failed: $error';

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
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours hr $minutes min $seconds sec';
  }

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
  String get chatModelFallback => 'Model';

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
  String get chatErrorPrefix => 'Error: ';

  @override
  String get chatErrorCancelled => 'Output was interrupted by the user';

  @override
  String get chatErrorProviderNotConfigured =>
      'Chat API is not configured. Open Settings to configure a provider.';

  @override
  String get chatErrorApiKeyNotConfigured =>
      'API key is not configured. Check Settings.';

  @override
  String get chatErrorServerConnection =>
      'Unable to connect to the server. Check your network connection and API address.';

  @override
  String get chatErrorNetworkConnection =>
      'Network connection failed. Check your network connection.';

  @override
  String get chatErrorTimeout =>
      'Connection timed out. The server did not respond.';

  @override
  String chatAttachmentImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return 'Could not take a photo: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform does not support device gallery access: $error';
  }

  @override
  String get chatAttachmentWebPlatform => 'Web browser';

  @override
  String get chatAttachmentCurrentPlatform => 'This device';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      'Grant photo library access permission and try again.';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      'Allow this website to access files in your browser settings.';

  @override
  String get chatAttachmentGalleryFallbackHint =>
      'Check that your device supports gallery selection.';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return 'Could not import image: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform does not support file selection: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint =>
      'Grant file access permission and try again.';

  @override
  String get chatAttachmentFileFallbackHint =>
      'Check that your device supports file selection.';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return 'Could not import file: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return 'Imported $fileName';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return 'Could not save the edited image: $error';
  }

  @override
  String get chatDataDetails => 'Data details';

  @override
  String get chatErrorDetailOcrDiagnostics => 'OCR Diagnostics';

  @override
  String get chatErrorDetailRequestUrl => 'Request URL';

  @override
  String get chatErrorDetailRequestHeaders => 'Request Headers';

  @override
  String get chatErrorDetailRequestBody => 'Request Body';

  @override
  String get chatErrorDetailStatusCode => 'Status Code';

  @override
  String get chatErrorDetailResponseHeaders => 'Response Headers';

  @override
  String get chatErrorDetailResponseBody => 'Response Body';

  @override
  String get chatErrorDetailEmpty => 'No detail data available';

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
      'N…121919 tokens truncated…AndroidStep2Description =>
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
  String get browserScriptOriginManual => 'Added manually';

  @override
  String browserScriptVersion(Object version) {
    return '@version $version';
  }

  @override
  String get browserScriptEnabled => 'Enabled';

  @override
  String get browserScriptDisabled => 'Disabled';

  @override
  String get browserScriptRuntimeError =>
      'This script encountered a runtime error. Check its code and page compatibility.';

  @override
  String get browserScriptDelete => 'Delete';

  @override
  String get browserDeleteScriptTitle => 'Delete script?';

  @override
  String get browserDeleteScriptConfirmation =>
      'This script will be removed from this browser. This action cannot be undone.';

  @override
  String get browserEditScript => 'Edit script';

  @override
  String get browserScriptName => 'Script name';

  @override
  String get browserScriptCode => 'Script code (JavaScript)';

  @override
  String get browserAddScriptMethod => 'Choose how to add a script';

  @override
  String get browserImportFromUrl => 'Import from URL';

  @override
  String get browserEnterManually => 'Enter manually';

  @override
  String get browserScriptTrustWarningTitle => 'Only import scripts you trust';

  @override
  String get browserScriptTrustWarning =>
      'Only add scripts you trust, or they may leak data. Scripts can read or modify webpage content.';

  @override
  String get browserContinue => 'Continue';

  @override
  String get browserManualUserscriptLabel => 'Tampermonkey userscript';

  @override
  String get browserScriptImportUrl => 'Script URL';

  @override
  String get browserScriptImportFetch => 'Fetch preview';

  @override
  String get browserScriptPreview => 'Script source preview';

  @override
  String get browserScriptImportInvalidUrl => 'Enter a valid HTTPS URL.';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Use a Greasy Fork .user.js URL or a GitHub Raw URL.';

  @override
  String get browserScriptImportRedirectedUrl =>
      'The URL redirected to an unsupported or insecure address.';

  @override
  String get browserScriptImportNotScript =>
      'The response is empty or does not appear to be a JavaScript script.';

  @override
  String get browserScriptImportNetworkError =>
      'Could not fetch the script. Check the URL and your connection.';

  @override
  String browserScriptImportHttpError(Object status) {
    return 'The server returned HTTP $status.';
  }

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
  String ocrResultPageHeading(String index) {
    return 'Image $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return 'Image $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => ' (partial result)';

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
  String get notificationBannerTaskCompletedHeading => 'Task completed';

  @override
  String get notificationBannerTaskFailedHeading => 'Task failed';

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

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'SSE connection failed (HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'SSE connection failed (HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable =>
      'SSE connection failed: unable to connect to server';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'HTTP request failed (HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => 'Request failed';

  @override
  String get sseNetworkRequestFailed => 'Network request failed';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return 'Network request failed (HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return 'Network request failed (HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable =>
      'Network request failed: unable to connect to server';

  @override
  String get sseRequestCancelled => 'Request cancelled';

  @override
  String get startupSafetyTitle => 'Data safety protection';

  @override
  String get startupSafetyExportButton => 'Export data';

  @override
  String get startupSafetyExitButton => 'Exit app';

  @override
  String get startupSafetyUpdateButton => 'Update app';

  @override
  String get startupSafetyCheckingUpdates => 'Checking for updates...';

  @override
  String get startupSafetyUpToDate => 'You\'re up to date';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return 'This data was created by a newer version of the app ($version).\n\nThis app version cannot safely read the data. Install the latest version to continue. Your data has not been changed.';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      'The data safety status could not be confirmed (the status marker could not be read or was invalid).\n\nTo avoid overwriting a possible frozen state, startup has been blocked without repairing data or migrating formats. First export your data file, then exit the app, repair the status marker, and try again.';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return 'Data format migration failed ($part).\n\nTo protect your data, no changes were made. Return to the previous app version, or wait for a fixed version before upgrading.';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return 'Data format migration failed ($part).\n\nYour data was restored to its pre-migration state. To protect it, return to the previous app version, or wait for a fixed version before upgrading.';
  }

  @override
  String get startupSafetyDataCorrupted =>
      'Data is damaged and could not be repaired automatically.\n\nThe app has been frozen to prevent further damage. Export your data file, then import it manually or reinstall.';

  @override
  String get startupSafetyPreferencesUnavailable =>
      'The app could not read preferences required for startup checks, so startup has been blocked to protect your data.\n\nCheck storage space or permissions, then reopen the app.';

  @override
  String get startupSafetyValidationUnavailable =>
      'The app could not complete its startup data-safety check, so startup has been blocked to protect your data.\n\nCheck browser settings, then reopen the app.';

  @override
  String startupSafetyCheckFailed(String detail) {
    return 'Startup check failed: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      'The data safety status could not be confirmed after startup checks (the status marker could not be read or was invalid).\n\nStartup has stopped to avoid making further data changes. Export your data file, exit the app, repair the status marker, and try again.';

  @override
  String get catCatchConnectionTimeout =>
      'Connection timed out. Check your network or server status.';

  @override
  String get catCatchSendTimeout => 'The request timed out while sending.';

  @override
  String get catCatchReceiveTimeout =>
      'The response timed out because the server is taking too long.';

  @override
  String get catCatchCannotConnect => 'Could not connect to the server.';

  @override
  String get catCatchConnectionError =>
      'Could not connect to the server. Check that the URL is correct.';

  @override
  String get catCatchBadCertificate =>
      'The server certificate could not be verified.';

  @override
  String catCatchBadResponse(int statusCode) {
    return 'The server returned an error (HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => 'The request was cancelled.';

  @override
  String catCatchNetworkError(String message) {
    return 'Network error: $message';
  }

  @override
  String get catCatchUnknownError => 'Unknown error';

  @override
  String catCatchOriginalError(String message) {
    return 'Original error: $message';
  }

  @override
  String get catCatchWebDownloadHint =>
      'Web browsers cannot download media files directly.';

  @override
  String get catCatchWebInstallExtension =>
      'Install the CatCatch browser extension and try again.';

  @override
  String get catCatchWebAuthorAttribution =>
      'Author: 笨笨猫 (xifangczy). Free and open source.';

  @override
  String get catCatchWebOfficialWarning =>
      'Make sure it is the author’s version; avoid paid or imitation versions.';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      'This feature requires a signed-in account. Sign in using the browser in the top-right corner.';

  @override
  String get catCatchNoUsableMedia =>
      'No usable media resource was found. Check the URL and make sure the website is reachable.';

  @override
  String get catCatchRedownloadFileMissing =>
      'The download failed because the downloaded file is missing.';

  @override
  String get catCatchRedownloadPathEmpty =>
      'The download failed because the downloaded file path is empty.';

  @override
  String get catCatchWebBrowserRequired =>
      'This page cannot expose its resources without a browser environment. Try using the feature on mobile or desktop, or paste a direct video or audio file URL.';

  @override
  String get catCatchPlaylistNoSegments =>
      'The playlist has no downloadable segments.';

  @override
  String get catCatchDownloadedSourceMissing =>
      'The downloaded source file is missing. Please download it again.';

  @override
  String get appLogPageTitle => 'Application logs';

  @override
  String get appLogRefresh => 'Refresh';

  @override
  String get appLogCleanupOldLogs => 'Clean up old logs';

  @override
  String get appLogCleanupDone => 'Old logs were cleaned up';

  @override
  String appLogRetentionNotice(int days) {
    return 'Log retention: Only the most recent $days days are kept. Logs older than $days days are cleaned automatically.';
  }

  @override
  String get appLogWebUnsupported => 'Local logs are not supported on web';

  @override
  String get appLogNoFiles => 'No log files yet';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Refreshing automatically (attempts $count)...',
      one: 'Refreshing automatically (attempt $count)...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated =>
      'Logs are generated while the app is running';

  @override
  String get appLogExport => 'Export';

  @override
  String get appLogDelete => 'Delete';

  @override
  String get appLogConfirmDeleteTitle => 'Confirm deletion';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return 'Delete log file \"$fileName\"?';
  }

  @override
  String get appLogCancel => 'Cancel';

  @override
  String appLogLoadFilesError(Object error) {
    return 'Failed to load log file list: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return 'Log file \"$fileName\" exists but could not be read; it may be corrupted';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return 'Log file \"$fileName\" was not found; it may have been cleaned up';
  }

  @override
  String appLogReadFileError(Object error) {
    return 'Failed to read log file: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return 'Deleted: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return 'Log file \"$fileName\" was not found';
  }

  @override
  String appLogPathCopied(String filePath) {
    return 'Path copied: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return 'Export failed: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => 'Copy all';

  @override
  String get appLogStructuredView => 'Structured view';

  @override
  String get appLogRawView => 'Raw view';

  @override
  String appLogCopyError(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get appLogCopyDone => 'Copied all log content';

  @override
  String get iosContinuedTaskTitle => 'Background task';

  @override
  String get mermaidCatalogTypeFlowchart => 'Flowchart';

  @override
  String get mermaidCatalogDescriptionFlowchart =>
      'Flowchart — show steps, branches, and loops';

  @override
  String get mermaidCatalogTypeSequenceDiagram => 'Sequence diagram';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      'Sequence diagram — show interactions between participants';

  @override
  String get mermaidCatalogTypeClassDiagram => 'Class diagram';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      'Class diagram — show relationships between class attributes and methods';

  @override
  String get mermaidCatalogTypeStateDiagram => 'State diagram';

  @override
  String get mermaidCatalogDescriptionStateDiagram =>
      'State diagram — show state transitions';

  @override
  String get mermaidCatalogTypeErDiagram => 'ER diagram';

  @override
  String get mermaidCatalogDescriptionErDiagram =>
      'ER diagram — show entity relationships';

  @override
  String get mermaidCatalogTypeGantt => 'Gantt chart';

  @override
  String get mermaidCatalogDescriptionGantt =>
      'Gantt chart — show a project timeline';

  @override
  String get mermaidCatalogTypePie => 'Pie chart';

  @override
  String get mermaidCatalogDescriptionPie =>
      'Pie chart — show proportional data';

  @override
  String get mermaidCatalogTypeJourney => 'User journey';

  @override
  String get mermaidCatalogDescriptionJourney =>
      'User journey — show a user experience flow';

  @override
  String get mermaidCatalogTypeGitGraph => 'Git graph';

  @override
  String get mermaidCatalogDescriptionGitGraph =>
      'Git graph — show branches and commits';

  @override
  String get mermaidCatalogTypeMindmap => 'Mind map';

  @override
  String get mermaidCatalogDescriptionMindmap => 'Mind map — show a hierarchy';

  @override
  String get mermaidCatalogTypeTimeline => 'Timeline';

  @override
  String get mermaidCatalogDescriptionTimeline =>
      'Timeline — show events in chronological order';

  @override
  String get mermaidCatalogTypeBlock => 'Block diagram';

  @override
  String get mermaidCatalogDescriptionBlock =>
      'Block diagram — show block layout and relationships';

  @override
  String get mermaidCatalogTypeRequirement => 'Requirement diagram';

  @override
  String get mermaidCatalogDescriptionRequirement =>
      'Requirement diagram — show requirements and implementation relationships';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[Start]\n  B[Process step]\n  C<MERMAID_OPEN_BRACE>Condition<MERMAID_CLOSE_BRACE>\n  D[End]\n\n  A --> B\n  B --> C\n  C -->|Yes| D\n  C -->|No| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"User\" as 用户\n  participant \"System\" as 系统\n  participant \"Database\" as 数据库\n\n  用户->>系统: Send request\n  系统->>数据库: Query data\n  数据库-->>系统: Return result\n  系统-->>用户: Show result';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String name\n    +int age\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String studentId\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String teacherId\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"Pending\" as 待处理\n  state \"Processing\" as 处理中\n  state \"Completed\" as 已完成\n  state \"Failed\" as 失败\n  [*] --> 待处理\n  待处理 --> 处理中\n  处理中 --> 已完成\n  处理中 --> 失败\n  失败 --> 待处理\n  已完成 --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : places\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : contains\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : includes\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title Project Gantt chart\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section Requirements\n  Requirements analysis :a1, 2024-01-01, 14d\n  Prototype design     :a2, after a1, 10d\n\n  section Development\n  Frontend development  :b1, after a2, 20d\n  Backend development  :b2, after a2, 20d\n  API integration      :b3, after b1, 7d\n\n  section Testing\n  Feature testing      :c1, after b3, 10d\n  Deployment           :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title Data distribution\n  \"Category A\" : 40\n  \"Category B\" : 25\n  \"Category C\" : 20\n  \"Category D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title User registration\n  section Sign-up\n    Open sign-up page: 5: User\n    Enter information: 3: User\n    Submit request: 4: User\n  section Verification\n    Receive code: 3: System\n    Enter code: 4: User\n    Verification succeeds: 5: System, User';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"初始提交\"\n  commit id: \"添加功能A\"\n  branch develop\n  checkout develop\n  commit id: \"开发新功能\"\n  commit id: \"修复bug\"\n  checkout main\n  merge develop\n  commit id: \"发布v1.0\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((Project management))\n    Requirements\n      Functional\n      Non-functional\n    Development\n      Frontend\n      Backend\n    Testing\n      Unit tests\n      Integration tests\n    Deployment\n      Test environment\n      Production environment';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title Project milestones\n  2024-Q1 : Requirements research : Plan confirmed\n  2024-Q2 : Development : Features implemented\n  2024-Q3 : Testing : Bug fixes : Performance tuning\n  2024-Q4 : Deployment : Operations and maintenance';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"Requirements\"] B[\"Development\"] C[\"Testing\"]\n  D[\"Deployment\"] E[\"Operations\"] F[\"Monitoring\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement 用户登录 <MERMAID_OPEN_BRACE>\n    id: 1\n    text: A user can sign in with an account and password\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element 登录页面 <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element 认证服务 <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  登录页面 - satisfies -> 用户登录\n  认证服务 - verifies -> 用户登录';

  @override
  String get mermaidCatalogDefaultFileName => 'My chart';

  @override
  String get mermaidCatalogActionAddNode => 'Add node';

  @override
  String get mermaidCatalogActionAddDecision => 'Add decision';

  @override
  String get mermaidCatalogActionAddEdge => 'Add edge';

  @override
  String get mermaidCatalogActionAddSubgraph => 'Add subgraph';

  @override
  String get mermaidCatalogActionAddParticipant => 'Add participant';

  @override
  String get mermaidCatalogActionAddRequest => 'Add request';

  @override
  String get mermaidCatalogActionAddResponse => 'Add response';

  @override
  String get mermaidCatalogActionAddNote => 'Add note';

  @override
  String get mermaidCatalogActionAddClass => 'Add class';

  @override
  String get mermaidCatalogActionAddInheritance => 'Add inheritance';

  @override
  String get mermaidCatalogActionAddRelationship => 'Add relationship';

  @override
  String get mermaidCatalogActionAddAggregation => 'Add aggregation';

  @override
  String get mermaidCatalogActionAddState => 'Add state';

  @override
  String get mermaidCatalogActionAddTransition => 'Add transition';

  @override
  String get mermaidCatalogActionAddStart => 'Add start';

  @override
  String get mermaidCatalogActionAddEnd => 'Add end';

  @override
  String get mermaidCatalogActionAddEntity => 'Add entity';

  @override
  String get mermaidCatalogActionAddOneToMany => 'Add one-to-many';

  @override
  String get mermaidCatalogActionAddManyToMany => 'Add many-to-many';

  @override
  String get mermaidCatalogActionAddOneToOne => 'Add one-to-one';

  @override
  String get mermaidCatalogActionAddPhase => 'Add phase';

  @override
  String get mermaidCatalogActionAddTask => 'Add task';

  @override
  String get mermaidCatalogActionAddDependentTask => 'Add dependent task';

  @override
  String get mermaidCatalogActionAddMilestone => 'Add milestone';

  @override
  String get mermaidCatalogActionAddCategory => 'Add category';

  @override
  String get mermaidCatalogActionAddTitle => 'Add title';

  @override
  String get mermaidCatalogActionAddSystemTask => 'Add system task';

  @override
  String get mermaidCatalogActionAddMultiPersonTask => 'Add multi-person task';

  @override
  String get mermaidCatalogActionAddCommit => 'Add commit';

  @override
  String get mermaidCatalogActionCreateBranch => 'Create branch';

  @override
  String get mermaidCatalogActionSwitchBranch => 'Switch branch';

  @override
  String get mermaidCatalogActionMergeBranch => 'Merge branch';

  @override
  String get mermaidCatalogActionAddBranch => 'Add branch';

  @override
  String get mermaidCatalogActionAddChildBranch => 'Add child branch';

  @override
  String get mermaidCatalogActionAddTopic => 'Add topic';

  @override
  String get mermaidCatalogActionAddPeriod => 'Add period';

  @override
  String get mermaidCatalogActionAddBlock => 'Add block';

  @override
  String get mermaidCatalogActionAddColumns => 'Add columns';

  @override
  String get mermaidCatalogActionAddConnection => 'Add connection';

  @override
  String get mermaidCatalogActionAddChildBlock => 'Add child block';

  @override
  String get mermaidCatalogActionAddRequirement => 'Add requirement';

  @override
  String get mermaidCatalogActionAddElement => 'Add element';

  @override
  String get mermaidCatalogActionAddVerification => 'Add verification';

  @override
  String get mermaidCatalogGanttDependencyBaseTask => 'Dependency base task';

  @override
  String get mermaidCatalogGanttDependentTaskName => 'Follow-up task';

  @override
  String get startupMigrationTitle => 'Data format upgrade complete';

  @override
  String get startupMigrationBody =>
      'Your data has been migrated to the new format. Restart the app to use the updated version.';

  @override
  String get startupMigrationExit => 'Exit app';

  @override
  String get startupMigrationRestart => 'Restart now';

  @override
  String get startupRecoveryTitle => 'App startup error';

  @override
  String get startupRecoveryFallbackMessage =>
      'A data format issue was encountered during startup and repaired automatically. Please try again.';

  @override
  String get startupRecoveryRetry => 'Retry';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return 'ASR $category at $stage$chunk: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return ', chunk $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return 'Request failed: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return 'Chunked transcription failed ($count chunks, none succeeded)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return 'Chunked transcription is incomplete ($succeeded/$count chunks succeeded)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return 'Succeeded: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return 'Failed: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return 'Outcome uncertain: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return 'Chunk $index ($start–${end}s) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return 'Saving chunk status failed: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      'Request outcome is uncertain. Retrying has stopped to avoid duplicate submissions. Select the audio again to create a new task.';

  @override
  String asrRetryAudioLost(Object audioName) {
    return 'The original audio file was lost. Select the audio again to retry: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return 'The original audio file is corrupted. Select the audio again to retry: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return ', chunk $index';
  }

  @override
  String get asrChunkDetailsSeparator => '; ';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'ASR recognition failed: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => 'authentication';

  @override
  String get asrFailureCategoryRateLimit => 'rate limit';

  @override
  String get asrFailureCategorySizeLimit => 'size limit';

  @override
  String get asrFailureCategoryNetwork => 'network';

  @override
  String get asrFailureCategoryResponseParsing => 'response parsing';

  @override
  String get asrFailureCategoryLocalProcessing => 'local processing';

  @override
  String get asrFailureCategoryProvider => 'provider';

  @override
  String get asrFailureCategoryUnknown => 'unknown';

  @override
  String get asrFailureStagePreprocessing => 'preprocessing';

  @override
  String get asrFailureStageEncoding => 'encoding';

  @override
  String get asrFailureStageValidation => 'validation';

  @override
  String get asrFailureStageRequest => 'request';

  @override
  String get asrFailureStageUploading => 'uploading';

  @override
  String get asrFailureStageWaiting => 'waiting';

  @override
  String get asrFailureStageReceiving => 'receiving';

  @override
  String get asrFailureStageResponse => 'response';

  @override
  String get asrFailureStageParsing => 'parsing';

  @override
  String get asrFailureStageStorage => 'storage';

  @override
  String get chatMissingProvider => 'Please configure a chat provider first';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Anthropic API error: $detail';
  }

  @override
  String get anthropicStreamUnknownError => 'Unknown error';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'API request failed (HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing =>
      'API key is not configured; file upload is unavailable';

  @override
  String get fileUploadApiUrlMissing =>
      'API URL is not configured; file upload is unavailable';

  @override
  String get fileUploadContentEmpty => 'File content is empty';

  @override
  String get fileUploadFilenameEmpty => 'File name is empty';

  @override
  String get fileUploadMimeTypeEmpty => 'MIME type is empty';

  @override
  String get fileUploadPurposeEmpty => 'Upload purpose is empty';

  @override
  String get fileUploadCanceled => 'File upload was canceled';

  @override
  String get fileUploadCreateMissingId =>
      'Upload creation failed: response is missing upload id';

  @override
  String get fileUploadPartMissingId =>
      'Part upload failed: response is missing part id';

  @override
  String get fileUploadCompleteMissingFile =>
      'Upload completion failed: response is missing file object';

  @override
  String get fileUploadMissingFileId =>
      'File upload failed: response is missing file id';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return 'File upload request failed (HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return 'File upload request failed: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'API key is not configured';

  @override
  String chatStreamError(Object detail) {
    return 'API stream error: $detail';
  }

  @override
  String get chatChoicesMissing => 'API response has no choices';

  @override
  String get chatContentBlocksMissing => 'API response has no content blocks';

  @override
  String get chatResponseContentEmpty => 'API response content is empty';

  @override
  String chatRequestFailed(Object detail) {
    return 'Request failed: $detail';
  }

  @override
  String get startupTagline => 'Your learning assistant';

  @override
  String get startupProgressDataSafety => 'Checking data safety...';

  @override
  String get startupProgressFormatVersion => 'Checking data format version...';

  @override
  String get startupProgressDataFormat => 'Validating data formats...';

  @override
  String get startupProgressDataIntegrity => 'Checking data integrity...';

  @override
  String get startupProgressResults => 'Processing check results...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return 'Startup complete (note: $warning)';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      'Data checks complete. Preparing to start the app.';

  @override
  String get startupProgressReady => 'Preparing to start the app.';

  @override
  String startupWarningErrorCount(Object count) {
    return 'Found $count data issue(s):';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return '$count warning(s):';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      'Provider entries have an invalid format: expected a JSON array.';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return 'Provider entry $index is null or has an invalid type.';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return 'Provider entry $index is missing an ID or has an empty ID.';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return 'Provider entry $index is missing a type or has an empty type.';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return 'Provider entry $index is missing a name or has an empty name.';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return 'Provider entry $index field $field is not a valid list.';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return 'Provider entry $index, $field contains an invalid item that may cause a parsing failure.';
  }

  @override
  String get startupIssueConversationsInvalid =>
      'Conversations have an invalid format: expected a JSON array.';

  @override
  String startupIssueConversationInvalid(Object index) {
    return 'Conversation $index is null or has an invalid type.';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return 'Conversation $index is missing an ID.';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return 'Conversation $index is missing its messages field.';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return 'Conversation $index messages field is not a valid list.';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return 'Provider entry $index uses unknown provider type \"$type\" and may not work correctly.';
  }
}
