Warning: truncated output (original token count: 159794)
Total output lines: 22448

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
  String get settingsBackupRestoreDescription => 'Expor…144794 tokens truncated…onnection failed: unable to connect to server';

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

  @override
  String get startupErrorTitle => 'App startup failed';

  @override
  String startupErrorDetails(Object error) {
    return 'Error: $error';
  }

  @override
  String get renderErrorTitle => 'Interface rendering error';

  @override
  String get renderErrorDebugTitle => 'Interface rendering error (Debug mode)';

  @override
  String get renderErrorRestartMessage => 'Please try restarting the app.';
}
