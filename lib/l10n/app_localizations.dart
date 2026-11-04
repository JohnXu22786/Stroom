import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', 'US'),
    Locale('zh', 'CN'),
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @languageSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingsTitle;

  /// No description provided for @followSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystemLanguage;

  /// No description provided for @languageNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEnglish;

  /// No description provided for @languageNameChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get languageNameChinese;

  /// No description provided for @builtInPromptGeneralName.
  ///
  /// In en, this message translates to:
  /// **'General Assistant'**
  String get builtInPromptGeneralName;

  /// No description provided for @builtInPromptGeneralDescription.
  ///
  /// In en, this message translates to:
  /// **'An all-purpose AI assistant for everyday conversation and answers to a wide range of questions.'**
  String get builtInPromptGeneralDescription;

  /// No description provided for @builtInPromptGeneralPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a helpful AI assistant. Answer the user in the language they use. Be concise, clear, and logically organized. If you are unsure about something, say so honestly.'**
  String get builtInPromptGeneralPrompt;

  /// No description provided for @builtInPromptCodeExpertName.
  ///
  /// In en, this message translates to:
  /// **'Code Expert'**
  String get builtInPromptCodeExpertName;

  /// No description provided for @builtInPromptCodeExpertDescription.
  ///
  /// In en, this message translates to:
  /// **'An experienced programmer with expertise in many programming languages and technology stacks.'**
  String get builtInPromptCodeExpertDescription;

  /// No description provided for @builtInPromptCodeExpertPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are an experienced software engineer skilled in many programming languages and technology stacks. Based on the user’s question, provide high-quality code examples, technical explanations, and best-practice recommendations. Prioritize readability, performance, and security. When providing code, label the language and use suitable formatting. For system-design questions, analyze trade-offs from an architecture perspective.'**
  String get builtInPromptCodeExpertPrompt;

  /// No description provided for @builtInPromptTranslationName.
  ///
  /// In en, this message translates to:
  /// **'Translation Assistant'**
  String get builtInPromptTranslationName;

  /// No description provided for @builtInPromptTranslationDescription.
  ///
  /// In en, this message translates to:
  /// **'A professional translator for multilingual translation and localization advice.'**
  String get builtInPromptTranslationDescription;

  /// No description provided for @builtInPromptTranslationPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a professional translator. Your responsibilities are:\n1. Accurately translate the content the user provides while preserving its style and tone.\n2. Give a natural expression when the user asks how to say something in a particular language.\n3. Offer localization advice for culturally specific content.\n4. When several translations are possible, list them and explain their differences.\nAlways identify the source and target languages first; ask the user if either is unclear.'**
  String get builtInPromptTranslationPrompt;

  /// No description provided for @builtInPromptEnglishTeacherName.
  ///
  /// In en, this message translates to:
  /// **'English Teacher'**
  String get builtInPromptEnglishTeacherName;

  /// No description provided for @builtInPromptEnglishTeacherDescription.
  ///
  /// In en, this message translates to:
  /// **'An English learning tutor who helps improve listening, speaking, reading, and writing.'**
  String get builtInPromptEnglishTeacherDescription;

  /// No description provided for @builtInPromptEnglishTeacherPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are an experienced English teacher. Meet the user’s needs with:\n1. Grammar explanations: explain rules clearly and include examples.\n2. Vocabulary learning: explain word usage, collocations, and distinctions.\n3. Writing polish: improve English so it sounds natural.\n4. Conversation practice: simulate English-speaking situations.\n5. Pronunciation guidance: use phonetic symbols and approximate pronunciation.\nAdjust the difficulty to the user’s English level and use Chinese to support explanations.'**
  String get builtInPromptEnglishTeacherPrompt;

  /// No description provided for @builtInPromptInterviewerName.
  ///
  /// In en, this message translates to:
  /// **'Interviewer'**
  String get builtInPromptInterviewerName;

  /// No description provided for @builtInPromptInterviewerDescription.
  ///
  /// In en, this message translates to:
  /// **'A simulated interviewer for technical and behavioral interviews.'**
  String get builtInPromptInterviewerDescription;

  /// No description provided for @builtInPromptInterviewerPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a professional interviewer. Run a practice interview for the user’s target role:\n1. First learn the target position and industry.\n2. Ask relevant technical, behavioral, and system-design questions.\n3. Evaluate the user’s answers and suggest improvements.\n4. Provide sample answers and reasoning.\n5. Keep a realistic pace: ask one or two questions, then wait for the user.\nBe professional and friendly, with the goal of helping the user improve their interview skills.'**
  String get builtInPromptInterviewerPrompt;

  /// No description provided for @builtInPromptWritingName.
  ///
  /// In en, this message translates to:
  /// **'Writing Assistant'**
  String get builtInPromptWritingName;

  /// No description provided for @builtInPromptWritingDescription.
  ///
  /// In en, this message translates to:
  /// **'A writing and editing assistant for many genres and creative writing.'**
  String get builtInPromptWritingDescription;

  /// No description provided for @builtInPromptWritingPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a professional writing consultant. Based on the user’s needs, provide:\n1. Drafting: write in genres such as argumentative, expository, and narrative.\n2. Editing: improve grammar, word choice, logic, structure, and expression.\n3. Outlining: help build a framework and identify key points.\n4. Creative ideas: offer inspiration and possible angles.\n5. Formatting: follow the conventions of the target genre and submission requirements.\nFirst understand the purpose, intended readers, and desired style, then give focused advice.'**
  String get builtInPromptWritingPrompt;

  /// No description provided for @builtInPromptCreativeThinkerName.
  ///
  /// In en, this message translates to:
  /// **'Creative Thinker'**
  String get builtInPromptCreativeThinkerName;

  /// No description provided for @builtInPromptCreativeThinkerDescription.
  ///
  /// In en, this message translates to:
  /// **'A creative ideation and brainstorming partner who sparks fresh ideas.'**
  String get builtInPromptCreativeThinkerDescription;

  /// No description provided for @builtInPromptCreativeThinkerPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a creative thinking partner. Your tasks are:\n1. Brainstorming: offer varied creative directions around a topic.\n2. Developing concepts: deepen and extend existing ideas.\n3. Connecting fields: combine concepts from different areas in new ways.\n4. Thinking in reverse: challenge conventional thinking and offer unusual perspectives.\n5. Feasibility review: analyze implementation challenges and potential value.\nEncourage divergent thinking while bringing the discussion into focus at the right time. Offer three to five directions per response.'**
  String get builtInPromptCreativeThinkerPrompt;

  /// No description provided for @builtInPromptDataAnalystName.
  ///
  /// In en, this message translates to:
  /// **'Data Analyst'**
  String get builtInPromptDataAnalystName;

  /// No description provided for @builtInPromptDataAnalystDescription.
  ///
  /// In en, this message translates to:
  /// **'A data analysis expert who helps understand, model, and visualize data.'**
  String get builtInPromptDataAnalystDescription;

  /// No description provided for @builtInPromptDataAnalystPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a data analysis expert. Based on the user’s question, provide:\n1. Analysis methods: choose suitable statistical methods and analytical frameworks.\n2. SQL/Python/R code: give examples for data processing and analysis.\n3. Visualization advice: recommend suitable chart types and tools.\n4. Interpretation: explain findings and their business meaning.\n5. Data cleaning: handle missing values, outliers, and other quality issues.\nClarify the analysis goal and data characteristics first. Prefer the Python ecosystem (pandas, numpy, matplotlib, seaborn).'**
  String get builtInPromptDataAnalystPrompt;

  /// No description provided for @builtInPromptRoleplayName.
  ///
  /// In en, this message translates to:
  /// **'Roleplay'**
  String get builtInPromptRoleplayName;

  /// No description provided for @builtInPromptRoleplayDescription.
  ///
  /// In en, this message translates to:
  /// **'An immersive, multi-character roleplaying experience.'**
  String get builtInPromptRoleplayDescription;

  /// No description provided for @builtInPromptRoleplayPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are now in roleplay mode. Play the character specified by the user and interact according to that character’s personality, tone, and knowledge:\n1. When the user says “play [character],” switch to that character immediately.\n2. Stay in character throughout the conversation.\n3. Match the character’s language style and knowledge to the description.\n4. The user can say “end roleplay” to stop.\n5. You may add reasonable fictional details that fit the character.\nWait for the user to specify a character.'**
  String get builtInPromptRoleplayPrompt;

  /// No description provided for @builtInPromptLifeAdvisorName.
  ///
  /// In en, this message translates to:
  /// **'Life Advisor'**
  String get builtInPromptLifeAdvisorName;

  /// No description provided for @builtInPromptLifeAdvisorDescription.
  ///
  /// In en, this message translates to:
  /// **'A warm, thoughtful listener offering mental-health support and everyday advice.'**
  String get builtInPromptLifeAdvisorDescription;

  /// No description provided for @builtInPromptLifeAdvisorPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a warm and thoughtful life advisor. Your responsibilities are:\n1. Listen actively and understand the user’s concerns and emotional needs.\n2. Analyze issues rationally and help the user sort through their aspects.\n3. Offer concrete, actionable ways to improve everyday life.\n4. Provide understanding, encouragement, and positive support.\n5. Suggest professional help when it is needed.\nRemember: you are not a licensed mental-health counselor. For a serious mental-health crisis, encourage the user to seek professional help. Be empathetic without overstepping; support the user without making decisions for them.'**
  String get builtInPromptLifeAdvisorPrompt;

  /// No description provided for @builtInSystemTitleName.
  ///
  /// In en, this message translates to:
  /// **'Title Assistant'**
  String get builtInSystemTitleName;

  /// No description provided for @builtInSystemTitleDescription.
  ///
  /// In en, this message translates to:
  /// **'Generates a short title automatically from the conversation.'**
  String get builtInSystemTitleDescription;

  /// No description provided for @builtInSystemTitlePrompt.
  ///
  /// In en, this message translates to:
  /// **'You are a title generator. Output one conversation title and nothing else.\n\nRules:\n- Use one line and no more than 50 characters.\n- Do not explain or use quotation marks.\n- Use the same language as the user’s messages.\n- Do not include tool names such as web_search or todowrite in the title.\n\nExamples:\n“Help me debug a production 500 error” → Debugging a production 500 error\n“Refactor the user service” → Refactoring the user service\n“Why is app.js failing?” → Troubleshooting app.js\n\nIf the user’s message is very short or just a greeting (such as “hello,” “haha,” or “are you there?”), create a title that reflects its tone or intent, such as greeting, casual chat, or quick confirmation.'**
  String get builtInSystemTitlePrompt;

  /// No description provided for @builtInSystemCompactionName.
  ///
  /// In en, this message translates to:
  /// **'Context Compaction Assistant'**
  String get builtInSystemCompactionName;

  /// No description provided for @builtInSystemCompactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Condenses a long conversation into a structured, anchored summary to free context space.'**
  String get builtInSystemCompactionDescription;

  /// No description provided for @builtInSystemCompactionPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are an anchored-context summarization assistant. Condense long conversations into structured summaries.\n\nSummarize only the conversation history provided. Recent messages may be preserved verbatim, so focus on older context that is still important.\n\nIf the prompt contains a <previous-summary> block, treat it as the current anchored summary: keep what is still true, remove outdated material, and integrate new facts.\n\nFollow this structure exactly. Keep the section order and include every section, even if it is empty:\n<template>\n## Objective\n- [The user’s goal in one or two sentences]\n\n## Important Details\n- [Constraints/preferences, decisions and reasons, important facts/assumptions, and precise context needed to continue; write (none) if empty]\n\n## Work State\n### Completed\n- [Completed work, verified facts, or changes made; write (none) if empty]\n\n### Active\n- [Current work, partial changes, or investigation; write (none) if empty]\n\n### Blocked\n- [Blockers, failed commands, or unknowns; write (none) if empty]\n\n## Next Move\n1. [The next specific action, or (none)]\n2. [Known follow-up action, or (none)]\n\n## Relevant Files\n- [File or directory path and why it matters; write (none) if empty]\n</template>\n\nRules:\n- Include every section, even if empty.\n- Use concise bullet points, not paragraphs.\n- Preserve exact file paths, symbols, commands, error messages, URLs, and identifiers.\n- Do not mention that you are summarizing, compacting, or merging context.\n- Use the same language as the conversation.'**
  String get builtInSystemCompactionPrompt;

  /// No description provided for @builtInPromptMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant Market'**
  String get builtInPromptMarketTitle;

  /// No description provided for @builtInPromptClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get builtInPromptClose;

  /// No description provided for @builtInPromptImportHint.
  ///
  /// In en, this message translates to:
  /// **'Imported prompts become regular assistants that you can edit freely.'**
  String get builtInPromptImportHint;

  /// No description provided for @builtInPromptView.
  ///
  /// In en, this message translates to:
  /// **'View prompt'**
  String get builtInPromptView;

  /// No description provided for @builtInPromptAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get builtInPromptAdd;

  /// No description provided for @builtInPromptDescriptionHeading.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get builtInPromptDescriptionHeading;

  /// No description provided for @builtInPromptSystemPromptHeading.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get builtInPromptSystemPromptHeading;

  /// No description provided for @builtInPromptAddAssistant.
  ///
  /// In en, this message translates to:
  /// **'Add Assistant'**
  String get builtInPromptAddAssistant;

  /// No description provided for @builtInPromptViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt · {name}'**
  String builtInPromptViewerTitle(Object name);

  /// No description provided for @systemAssistantSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Configure a separate model and prompt for automatic title generation and context compaction. By default, the current chat model and built-in prompts are used.'**
  String get systemAssistantSettingsIntro;

  /// No description provided for @systemAssistantTitleName.
  ///
  /// In en, this message translates to:
  /// **'Title Generation Assistant'**
  String get systemAssistantTitleName;

  /// No description provided for @systemAssistantTitleDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically generates conversation titles'**
  String get systemAssistantTitleDescription;

  /// No description provided for @systemAssistantCompactionName.
  ///
  /// In en, this message translates to:
  /// **'Context Compaction Assistant'**
  String get systemAssistantCompactionName;

  /// No description provided for @systemAssistantCompactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Condenses long conversations into anchored summaries'**
  String get systemAssistantCompactionDescription;

  /// No description provided for @systemAssistantFollowCurrentModel.
  ///
  /// In en, this message translates to:
  /// **'Follow the current chat model'**
  String get systemAssistantFollowCurrentModel;

  /// No description provided for @systemAssistantChooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get systemAssistantChooseModel;

  /// No description provided for @systemAssistantResetPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default Prompt'**
  String get systemAssistantResetPromptTitle;

  /// No description provided for @systemAssistantResetPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Restore the built-in default prompt for “{taskTitle}”? Your current custom prompt will be discarded.'**
  String systemAssistantResetPromptBody(Object taskTitle);

  /// No description provided for @systemAssistantCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get systemAssistantCancel;

  /// No description provided for @systemAssistantReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get systemAssistantReset;

  /// No description provided for @systemAssistantModelHeading.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get systemAssistantModelHeading;

  /// No description provided for @systemAssistantPromptHeading.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get systemAssistantPromptHeading;

  /// No description provided for @systemAssistantCustomPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Changes will be used as a custom prompt'**
  String get systemAssistantCustomPromptHint;

  /// No description provided for @systemAssistantUsingCustomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Using custom prompt'**
  String get systemAssistantUsingCustomPrompt;

  /// No description provided for @systemAssistantUsingDefaultPrompt.
  ///
  /// In en, this message translates to:
  /// **'Using default prompt'**
  String get systemAssistantUsingDefaultPrompt;

  /// No description provided for @systemAssistantSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get systemAssistantSave;

  /// No description provided for @systemAssistantResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset to default prompt'**
  String get systemAssistantResetButton;

  /// No description provided for @taskFlowPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Flows'**
  String get taskFlowPageTitle;

  /// No description provided for @taskFlowSampleTemplatesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Example templates'**
  String get taskFlowSampleTemplatesTooltip;

  /// No description provided for @taskFlowEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No flows yet. Tap + to create one.'**
  String get taskFlowEmptyState;

  /// No description provided for @taskFlowStartFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get taskFlowStartFromTemplate;

  /// No description provided for @taskFlowChooseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Choose an Example Template'**
  String get taskFlowChooseTemplate;

  /// No description provided for @taskFlowTemplateIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Choose a flow close to what you need; you can adjust it later.'**
  String get taskFlowTemplateIntroduction;

  /// No description provided for @taskFlowTemplateCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} template} other{{count} templates}}'**
  String taskFlowTemplateCount(num count);

  /// No description provided for @taskFlowTemplateDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Templates open as drafts that need configuration. Choose a model and assistant before saving.'**
  String get taskFlowTemplateDraftHint;

  /// No description provided for @taskFlowTemplateRecordingName.
  ///
  /// In en, this message translates to:
  /// **'Transcribe and Summarize a Recording'**
  String get taskFlowTemplateRecordingName;

  /// No description provided for @taskFlowTemplateRecordingDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a recording → speech recognition → assistant summary'**
  String get taskFlowTemplateRecordingDescription;

  /// No description provided for @taskFlowTemplateRecordingRequirements.
  ///
  /// In en, this message translates to:
  /// **'Configure an ASR model and choose an assistant for the summary.'**
  String get taskFlowTemplateRecordingRequirements;

  /// No description provided for @taskFlowTemplateImageTextName.
  ///
  /// In en, this message translates to:
  /// **'Recognize and Organize Image Text'**
  String get taskFlowTemplateImageTextName;

  /// No description provided for @taskFlowTemplateImageTextDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an image → text recognition → assistant organization'**
  String get taskFlowTemplateImageTextDescription;

  /// No description provided for @taskFlowTemplateImageTextRequirements.
  ///
  /// In en, this message translates to:
  /// **'Configure an OCR model and choose an assistant to organize the text.'**
  String get taskFlowTemplateImageTextRequirements;

  /// No description provided for @taskFlowTemplateReadImageName.
  ///
  /// In en, this message translates to:
  /// **'Read Text from an Image'**
  String get taskFlowTemplateReadImageName;

  /// No description provided for @taskFlowTemplateReadImageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an image → text recognition → speech playback'**
  String get taskFlowTemplateReadImageDescription;

  /// No description provided for @taskFlowTemplateReadImageRequirements.
  ///
  /// In en, this message translates to:
  /// **'Configure OCR and speech synthesis models, then choose a voice.'**
  String get taskFlowTemplateReadImageRequirements;

  /// No description provided for @taskFlowActions.
  ///
  /// In en, this message translates to:
  /// **'Flow actions'**
  String get taskFlowActions;

  /// No description provided for @taskFlowBlockCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} block} other{{count} blocks}}'**
  String taskFlowBlockCount(num count);

  /// No description provided for @taskFlowBlockOcr.
  ///
  /// In en, this message translates to:
  /// **'OCR'**
  String get taskFlowBlockOcr;

  /// No description provided for @taskFlowBlockAsr.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition'**
  String get taskFlowBlockAsr;

  /// No description provided for @taskFlowBlockAudioSeparation.
  ///
  /// In en, this message translates to:
  /// **'Audio Separation'**
  String get taskFlowBlockAudioSeparation;

  /// No description provided for @taskFlowBlockCatCatch.
  ///
  /// In en, this message translates to:
  /// **'Web Resource Download'**
  String get taskFlowBlockCatCatch;

  /// No description provided for @taskFlowBlockTts.
  ///
  /// In en, this message translates to:
  /// **'Speech Synthesis'**
  String get taskFlowBlockTts;

  /// No description provided for @taskFlowBlockChat.
  ///
  /// In en, this message translates to:
  /// **'Assistant Chat'**
  String get taskFlowBlockChat;

  /// No description provided for @taskFlowEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get taskFlowEdit;

  /// No description provided for @taskFlowCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get taskFlowCopy;

  /// No description provided for @taskFlowCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get taskFlowCopied;

  /// No description provided for @taskFlowDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taskFlowDelete;

  /// No description provided for @taskFlowConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get taskFlowConfirmDelete;

  /// No description provided for @taskFlowConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete the task flow “{flowName}”?'**
  String taskFlowConfirmDeleteBody(Object flowName);

  /// No description provided for @taskFlowUseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get taskFlowUseTemplate;

  /// No description provided for @ocrTemplatePlainTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Plain Text'**
  String get ocrTemplatePlainTextLabel;

  /// No description provided for @ocrTemplatePlainTextContent.
  ///
  /// In en, this message translates to:
  /// **'Transcribe all visible text in the page’s natural reading order, preserving line breaks and paragraphs. Return plain text only; do not add explanations or inferences.'**
  String get ocrTemplatePlainTextContent;

  /// No description provided for @ocrTemplateMarkdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get ocrTemplateMarkdownLabel;

  /// No description provided for @ocrTemplateMarkdownContent.
  ///
  /// In en, this message translates to:
  /// **'Transcribe all visible text in the page’s natural reading order and use Markdown to preserve headings, lists, and tables. Represent mathematical formulas in LaTeX. Return only the transcription; do not add explanations or inferences.'**
  String get ocrTemplateMarkdownContent;

  /// No description provided for @ocrTemplateTableLabel.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get ocrTemplateTableLabel;

  /// No description provided for @ocrTemplateTableContent.
  ///
  /// In en, this message translates to:
  /// **'Transcribe all visible text in the page’s natural reading order. For tables, preserve the headers, row and column relationships, and empty cells, and output them as Markdown tables. Keep other content as ordinary text. Return only the transcription; do not add explanations or inferences.'**
  String get ocrTemplateTableContent;

  /// No description provided for @ocrTemplateLatexLabel.
  ///
  /// In en, this message translates to:
  /// **'LaTeX'**
  String get ocrTemplateLatexLabel;

  /// No description provided for @ocrTemplateLatexContent.
  ///
  /// In en, this message translates to:
  /// **'Transcribe all visible text in the page’s natural reading order. Preserve non-formula text and represent mathematical formulas in LaTeX; use \$...\$ for inline formulas and \$\$...\$\$ for display formulas. Return only the transcription; do not add explanations or inferences.'**
  String get ocrTemplateLatexContent;

  /// No description provided for @ocrDefaultImagesOnly.
  ///
  /// In en, this message translates to:
  /// **'Default (send images only)'**
  String get ocrDefaultImagesOnly;

  /// No description provided for @ocrSavedInstructionSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Saved instruction snapshot'**
  String get ocrSavedInstructionSnapshot;

  /// No description provided for @ocrPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Text Recognition'**
  String get ocrPageTitle;

  /// No description provided for @ocrImageQualitySettings.
  ///
  /// In en, this message translates to:
  /// **'Image quality settings'**
  String get ocrImageQualitySettings;

  /// No description provided for @ocrImageQualityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard quality'**
  String get ocrImageQualityStandard;

  /// No description provided for @ocrImageQualityStandardHint.
  ///
  /// In en, this message translates to:
  /// **'Smaller images for most use cases'**
  String get ocrImageQualityStandardHint;

  /// No description provided for @ocrImageQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original / high detail'**
  String get ocrImageQualityOriginal;

  /// No description provided for @ocrImageQualityOriginalHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps more detail; images and requests are larger'**
  String get ocrImageQualityOriginalHint;

  /// No description provided for @ocrReorderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get ocrReorderDone;

  /// No description provided for @ocrReorderAction.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get ocrReorderAction;

  /// No description provided for @ocrClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get ocrClearAction;

  /// No description provided for @ocrLegacyModelHint.
  ///
  /// In en, this message translates to:
  /// **'The previous task used model {modelId}. Choose a provider and model again.'**
  String ocrLegacyModelHint(Object modelId);

  /// No description provided for @ocrLegacyModelPositionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The model position in the previous retry record is invalid. Choose a model again.'**
  String get ocrLegacyModelPositionInvalid;

  /// No description provided for @ocrLegacyModelPositionConfirm.
  ///
  /// In en, this message translates to:
  /// **'The previous retry record saved only the model position. Confirm the current model before continuing.'**
  String get ocrLegacyModelPositionConfirm;

  /// No description provided for @ocrModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The original OCR provider or model is no longer available. Choose another one.'**
  String get ocrModelUnavailable;

  /// No description provided for @ocrModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get ocrModelLabel;

  /// No description provided for @ocrConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get ocrConfigure;

  /// No description provided for @ocrSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get ocrSelectModel;

  /// No description provided for @ocrInstructionLabel.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get ocrInstructionLabel;

  /// No description provided for @ocrManageInstructions.
  ///
  /// In en, this message translates to:
  /// **'Manage recognition instructions'**
  String get ocrManageInstructions;

  /// No description provided for @ocrBatchMode.
  ///
  /// In en, this message translates to:
  /// **'Batch mode'**
  String get ocrBatchMode;

  /// No description provided for @ocrMergeRecognition.
  ///
  /// In en, this message translates to:
  /// **'Combine results'**
  String get ocrMergeRecognition;

  /// No description provided for @ocrRecognizeEachImage.
  ///
  /// In en, this message translates to:
  /// **'Recognize each image separately'**
  String get ocrRecognizeEachImage;

  /// No description provided for @ocrMaxConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Up to 2 concurrent requests'**
  String get ocrMaxConcurrency;

  /// No description provided for @ocrConcurrencyOption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} concurrent request} other{{count} concurrent requests}}'**
  String ocrConcurrencyOption(num count);

  /// No description provided for @ocrConcurrencyStatus.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} concurrent request} other{{count} concurrent requests}}'**
  String ocrConcurrencyStatus(num count);

  /// No description provided for @ocrRetryCompletedHint.
  ///
  /// In en, this message translates to:
  /// **'Completed pages are kept; retry submits only unfinished pages.'**
  String get ocrRetryCompletedHint;

  /// No description provided for @ocrTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get ocrTakePhoto;

  /// No description provided for @ocrChooseFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'Choose from album'**
  String get ocrChooseFromAlbum;

  /// No description provided for @ocrNoImagesSelected.
  ///
  /// In en, this message translates to:
  /// **'No images selected'**
  String get ocrNoImagesSelected;

  /// No description provided for @ocrSelectImagesHint.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or select multiple images from your album to recognize.'**
  String get ocrSelectImagesHint;

  /// No description provided for @ocrRechooseRequiredImages.
  ///
  /// In en, this message translates to:
  /// **'Select all {count, plural, one{{count} image} other{{count} images}} again before retrying.'**
  String ocrRechooseRequiredImages(num count);

  /// No description provided for @ocrImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Image {index}'**
  String ocrImageLabel(Object index);

  /// No description provided for @ocrImageFileName.
  ///
  /// In en, this message translates to:
  /// **'Image_{index}.{format}'**
  String ocrImageFileName(Object format, Object index);

  /// No description provided for @ocrPreviewInvalidIndex.
  ///
  /// In en, this message translates to:
  /// **'Invalid image index'**
  String get ocrPreviewInvalidIndex;

  /// No description provided for @ocrViewErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'View error details'**
  String get ocrViewErrorDetails;

  /// No description provided for @ocrConfirmModel.
  ///
  /// In en, this message translates to:
  /// **'Confirm this model'**
  String get ocrConfirmModel;

  /// No description provided for @ocrSelectedImagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} image selected} other{{count} images selected}}'**
  String ocrSelectedImagesCount(num count);

  /// No description provided for @ocrPreparingImages.
  ///
  /// In en, this message translates to:
  /// **'Preparing images…'**
  String get ocrPreparingImages;

  /// No description provided for @ocrSavingRetryImages.
  ///
  /// In en, this message translates to:
  /// **'Saving retry images…'**
  String get ocrSavingRetryImages;

  /// No description provided for @ocrRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get ocrRecognizing;

  /// No description provided for @ocrReadingRetryImages.
  ///
  /// In en, this message translates to:
  /// **'Reading retry images…'**
  String get ocrReadingRetryImages;

  /// No description provided for @ocrImportingImages.
  ///
  /// In en, this message translates to:
  /// **'Importing images…'**
  String get ocrImportingImages;

  /// No description provided for @ocrStartRecognition.
  ///
  /// In en, this message translates to:
  /// **'Start recognition'**
  String get ocrStartRecognition;

  /// No description provided for @ocrSaveTo.
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get ocrSaveTo;

  /// No description provided for @ocrRootDirectory.
  ///
  /// In en, this message translates to:
  /// **'Root directory'**
  String get ocrRootDirectory;

  /// No description provided for @ocrChooseSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder to save to'**
  String get ocrChooseSaveFolder;

  /// No description provided for @ocrChooseImageSource.
  ///
  /// In en, this message translates to:
  /// **'Choose image source'**
  String get ocrChooseImageSource;

  /// No description provided for @ocrChooseAppAlbum.
  ///
  /// In en, this message translates to:
  /// **'Choose from app album'**
  String get ocrChooseAppAlbum;

  /// No description provided for @ocrAppAlbumDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose images already saved in the app'**
  String get ocrAppAlbumDescription;

  /// No description provided for @ocrChooseSystemAlbum.
  ///
  /// In en, this message translates to:
  /// **'Choose from system album'**
  String get ocrChooseSystemAlbum;

  /// No description provided for @ocrSystemAlbumDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse and choose images on this device'**
  String get ocrSystemAlbumDescription;

  /// No description provided for @ocrTakePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Taking photo failed: {error}'**
  String ocrTakePhotoFailed(Object error);

  /// No description provided for @ocrChooseImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Selecting image failed: {error}'**
  String ocrChooseImageFailed(Object error);

  /// No description provided for @ocrImagesLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count, plural, one{{count} image} other{{count} images}}'**
  String ocrImagesLoaded(num count);

  /// No description provided for @ocrProcessImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing image failed: {error}'**
  String ocrProcessImageFailed(Object error);

  /// No description provided for @ocrUnknownSourceImageCount.
  ///
  /// In en, this message translates to:
  /// **'Cannot determine the original image count'**
  String get ocrUnknownSourceImageCount;

  /// No description provided for @ocrConfirmClear.
  ///
  /// In en, this message translates to:
  /// **'Confirm clear'**
  String get ocrConfirmClear;

  /// No description provided for @ocrRetryUnavailableConfirmClear.
  ///
  /// In en, this message translates to:
  /// **'The original OCR image cache is unavailable and its image count cannot be recovered. Clearing will reset the old retry state. Select all images for this OCR task again.'**
  String get ocrRetryUnavailableConfirmClear;

  /// No description provided for @ocrConfirmClearSelected.
  ///
  /// In en, this message translates to:
  /// **'Clear the selected OCR images?'**
  String get ocrConfirmClearSelected;

  /// No description provided for @ocrCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ocrCancel;

  /// No description provided for @ocrConfirmResetAndReselect.
  ///
  /// In en, this message translates to:
  /// **'Reset and select images again'**
  String get ocrConfirmResetAndReselect;

  /// No description provided for @ocrRequestCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check the OCR request. Check the model parameters.'**
  String get ocrRequestCheckFailed;

  /// No description provided for @ocrCancelledAdjustAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Recognition was cancelled. Adjust the provider/model request size or image quality, then try again.'**
  String get ocrCancelledAdjustAndRetry;

  /// No description provided for @ocrRequestSizeExceededTitle.
  ///
  /// In en, this message translates to:
  /// **'OCR request exceeds the configured size'**
  String get ocrRequestSizeExceededTitle;

  /// No description provided for @ocrRequestSizeExceededBody.
  ///
  /// In en, this message translates to:
  /// **'The request is about {requestSize} MiB, which exceeds the configured {limit} MiB limit.'**
  String ocrRequestSizeExceededBody(Object limit, Object requestSize);

  /// No description provided for @ocrRequestSizeHelp.
  ///
  /// In en, this message translates to:
  /// **'Adjust the request size in provider defaults or model overrides, or choose a different image quality. After changing quality, clear and import the images again.'**
  String get ocrRequestSizeHelp;

  /// No description provided for @ocrUsePerImageMode.
  ///
  /// In en, this message translates to:
  /// **'Use per-image recognition'**
  String get ocrUsePerImageMode;

  /// No description provided for @ocrGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get ocrGotIt;

  /// No description provided for @ocrWaitForImport.
  ///
  /// In en, this message translates to:
  /// **'Wait for image import to finish before starting recognition.'**
  String get ocrWaitForImport;

  /// No description provided for @ocrWaitForRetryImages.
  ///
  /// In en, this message translates to:
  /// **'Reading retry images. Please wait.'**
  String get ocrWaitForRetryImages;

  /// No description provided for @ocrConfigureProviderModel.
  ///
  /// In en, this message translates to:
  /// **'Configure an OCR provider and model in Settings first.'**
  String get ocrConfigureProviderModel;

  /// No description provided for @ocrReselectProviderModel.
  ///
  /// In en, this message translates to:
  /// **'Select an OCR provider and model again.'**
  String get ocrReselectProviderModel;

  /// No description provided for @ocrConfirmLegacyModel.
  ///
  /// In en, this message translates to:
  /// **'Confirm the OCR model from the previous retry record first.'**
  String get ocrConfirmLegacyModel;

  /// No description provided for @ocrRetryImagesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The original OCR image cache is unavailable. Clear the task and select all images again.'**
  String get ocrRetryImagesUnavailable;

  /// No description provided for @ocrRetryImageCountUnknown.
  ///
  /// In en, this message translates to:
  /// **'The original OCR image cache is unavailable and its image count is unknown. Reset and select all images for this OCR task again.'**
  String get ocrRetryImageCountUnknown;

  /// No description provided for @ocrRetryImageReset.
  ///
  /// In en, this message translates to:
  /// **'The previous retry input was reset. Select all images for this OCR task again.'**
  String get ocrRetryImageReset;

  /// No description provided for @ocrRetryImagesUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The original OCR image cache could not be read. Clear the task and select all images again.'**
  String get ocrRetryImagesUnreadable;

  /// No description provided for @ocrRetryImagesMissing.
  ///
  /// In en, this message translates to:
  /// **'The original OCR image cache is missing or damaged. Clear the task and select all images again.'**
  String get ocrRetryImagesMissing;

  /// No description provided for @ocrImageListChanged.
  ///
  /// In en, this message translates to:
  /// **'The image list changed. Start recognition again.'**
  String get ocrImageListChanged;

  /// No description provided for @ocrReadInstructionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the recognition instruction. Try again.'**
  String get ocrReadInstructionFailed;

  /// No description provided for @ocrErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get ocrErrorDetails;

  /// No description provided for @ocrRequestHeading.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get ocrRequestHeading;

  /// No description provided for @ocrResponseHeading.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get ocrResponseHeading;

  /// No description provided for @ocrNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get ocrNoDetails;

  /// No description provided for @ocrImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load image'**
  String get ocrImageLoadFailed;

  /// No description provided for @ocrCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get ocrCrop;

  /// No description provided for @ocrEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ocrEdit;

  /// No description provided for @ocrProcessingOcrFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to process the OCR images. Please try again.'**
  String get ocrProcessingOcrFailed;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get settingsSectionProviders;

  /// No description provided for @settingsSectionSystemAssistant.
  ///
  /// In en, this message translates to:
  /// **'System Assistants'**
  String get settingsSectionSystemAssistant;

  /// No description provided for @settingsSectionContextManagement.
  ///
  /// In en, this message translates to:
  /// **'Context Management'**
  String get settingsSectionContextManagement;

  /// No description provided for @settingsSectionManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get settingsSectionManagement;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and Restore'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Export or import app data'**
  String get settingsBackupRestoreDescription;

  /// No description provided for @settingsCookies.
  ///
  /// In en, this message translates to:
  /// **'Cookies and Browser Data'**
  String get settingsCookies;

  /// No description provided for @settingsCookiesDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage persistent cookies and browser storage'**
  String get settingsCookiesDescription;

  /// No description provided for @settingsAppLogs.
  ///
  /// In en, this message translates to:
  /// **'App Logs'**
  String get settingsAppLogs;

  /// No description provided for @settingsAppLogsDescription.
  ///
  /// In en, this message translates to:
  /// **'View app runtime logs'**
  String get settingsAppLogsDescription;

  /// No description provided for @settingsThemeDisplay.
  ///
  /// In en, this message translates to:
  /// **'Theme and Display'**
  String get settingsThemeDisplay;

  /// No description provided for @settingsThemeDisplayDescription.
  ///
  /// In en, this message translates to:
  /// **'Dark mode and display language'**
  String get settingsThemeDisplayDescription;

  /// No description provided for @settingsTaskNotifications.
  ///
  /// In en, this message translates to:
  /// **'Task Completion Notifications'**
  String get settingsTaskNotifications;

  /// No description provided for @settingsTaskNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Check notification permission and system settings, and view the notification guide'**
  String get settingsTaskNotificationsDescription;

  /// No description provided for @settingsBackgroundOptimization.
  ///
  /// In en, this message translates to:
  /// **'Background Operation Optimization'**
  String get settingsBackgroundOptimization;

  /// No description provided for @settingsBackgroundOptimizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Check system environment and background service status, and view optimization guidance'**
  String get settingsBackgroundOptimizationDescription;

  /// No description provided for @aboutVersionInfo.
  ///
  /// In en, this message translates to:
  /// **'View version information'**
  String get aboutVersionInfo;

  /// No description provided for @aboutCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get aboutCheckUpdates;

  /// No description provided for @aboutNewVersionFound.
  ///
  /// In en, this message translates to:
  /// **'New version {version} available'**
  String aboutNewVersionFound(Object version);

  /// No description provided for @aboutNewVersion.
  ///
  /// In en, this message translates to:
  /// **'New Version'**
  String get aboutNewVersion;

  /// No description provided for @aboutPreviewUpdates.
  ///
  /// In en, this message translates to:
  /// **'Preview Updates'**
  String get aboutPreviewUpdates;

  /// No description provided for @aboutPreviewUpdatesDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable checks for preview releases'**
  String get aboutPreviewUpdatesDescription;

  /// No description provided for @aboutProjectHome.
  ///
  /// In en, this message translates to:
  /// **'Project Home'**
  String get aboutProjectHome;

  /// No description provided for @aboutFeedback.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get aboutFeedback;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutOpenSourceAgreement.
  ///
  /// In en, this message translates to:
  /// **'Open Source Agreement'**
  String get aboutOpenSourceAgreement;

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get aboutCheckingUpdates;

  /// No description provided for @aboutUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version'**
  String get aboutUpToDate;

  /// No description provided for @aboutUpdateNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {details}'**
  String aboutUpdateNetworkError(Object details);

  /// No description provided for @aboutUpdateHttpError.
  ///
  /// In en, this message translates to:
  /// **'Update check failed with HTTP status {statusCode}.'**
  String aboutUpdateHttpError(Object statusCode);

  /// No description provided for @aboutUpdateInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The update server returned an unexpected response.'**
  String get aboutUpdateInvalidResponse;

  /// No description provided for @aboutUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'The update check failed. Please try again.'**
  String get aboutUpdateCheckFailed;

  /// No description provided for @aboutPrivacyContent.
  ///
  /// In en, this message translates to:
  /// **'Stroom respects and protects the privacy of everyone who uses the service.\n\n1. Camera permission: Used only to take photos. No image data is collected or uploaded.\n\n2. Photo library permission: Used only to choose and save photos. All photos are stored locally on your device.\n\n3. Data security: All photos you take are stored locally on your device. We do not access or upload your data.\n\n4. Third-party services: This app contains no third-party analytics or advertising services.\n\nContact us if you have questions.'**
  String get aboutPrivacyContent;

  /// No description provided for @aboutClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutClose;

  /// No description provided for @contextToolPruneTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically prune tool results (Prune)'**
  String get contextToolPruneTitle;

  /// No description provided for @contextToolPruneDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically replace old tool results above the threshold with placeholders to free storage and context.'**
  String get contextToolPruneDescription;

  /// No description provided for @contextCompactionTriggerSettings.
  ///
  /// In en, this message translates to:
  /// **'Compaction Trigger Settings'**
  String get contextCompactionTriggerSettings;

  /// No description provided for @contextCompactionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled (compaction will not run)'**
  String get contextCompactionDisabled;

  /// No description provided for @contextGlobalTriggerPercent.
  ///
  /// In en, this message translates to:
  /// **'Global trigger {percent}%'**
  String contextGlobalTriggerPercent(Object percent);

  /// No description provided for @contextModelOverrideCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} model-specific override} other{{count} model-specific overrides}}'**
  String contextModelOverrideCount(num count);

  /// No description provided for @contextCompressionTriggerTitle.
  ///
  /// In en, this message translates to:
  /// **'Compaction Trigger Settings'**
  String get contextCompressionTriggerTitle;

  /// No description provided for @contextAutoCompaction.
  ///
  /// In en, this message translates to:
  /// **'Automatic Context Compaction'**
  String get contextAutoCompaction;

  /// No description provided for @contextAutoCompactionDisabled.
  ///
  /// In en, this message translates to:
  /// **'When disabled, compaction will not run for any model.'**
  String get contextAutoCompactionDisabled;

  /// No description provided for @contextGlobalTrigger.
  ///
  /// In en, this message translates to:
  /// **'Global trigger percentage'**
  String get contextGlobalTrigger;

  /// No description provided for @contextGlobalTriggerDescription.
  ///
  /// In en, this message translates to:
  /// **'Models without an individual setting use this percentage of the model context window as the compaction trigger.'**
  String get contextGlobalTriggerDescription;

  /// No description provided for @contextResetPercent.
  ///
  /// In en, this message translates to:
  /// **'Reset to {percent}%'**
  String contextResetPercent(Object percent);

  /// No description provided for @contextPerModelSettings.
  ///
  /// In en, this message translates to:
  /// **'Per-model settings'**
  String get contextPerModelSettings;

  /// No description provided for @contextNoConfiguredModels.
  ///
  /// In en, this message translates to:
  /// **'No configured models'**
  String get contextNoConfiguredModels;

  /// No description provided for @contextIndependentThreshold.
  ///
  /// In en, this message translates to:
  /// **'Independent threshold: {threshold} tokens'**
  String contextIndependentThreshold(Object threshold);

  /// No description provided for @contextEnterIndependentThreshold.
  ///
  /// In en, this message translates to:
  /// **'Enter an independent threshold below'**
  String get contextEnterIndependentThreshold;

  /// No description provided for @contextFollowGlobalPercent.
  ///
  /// In en, this message translates to:
  /// **'Follow global {percent}%'**
  String contextFollowGlobalPercent(Object percent);

  /// No description provided for @contextThresholdField.
  ///
  /// In en, this message translates to:
  /// **'Independent threshold (tokens)'**
  String get contextThresholdField;

  /// No description provided for @contextThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'For example, 48000 (token count, not a percentage)'**
  String get contextThresholdHint;

  /// No description provided for @contextPercentField.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get contextPercentField;

  /// No description provided for @contextPercentHint.
  ///
  /// In en, this message translates to:
  /// **'For example, {percent}'**
  String contextPercentHint(Object percent);

  /// No description provided for @versionInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Version information'**
  String get versionInfoTitle;

  /// No description provided for @versionNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionNumberLabel;

  /// No description provided for @versionReleaseTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Release time'**
  String get versionReleaseTimeLabel;

  /// No description provided for @versionLocalBuild.
  ///
  /// In en, this message translates to:
  /// **'Local build'**
  String get versionLocalBuild;

  /// No description provided for @versionReleaseNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get versionReleaseNotesLabel;

  /// No description provided for @versionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get versionClose;

  /// No description provided for @updateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateDialogTitle;

  /// No description provided for @updateLatestVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get updateLatestVersionLabel;

  /// No description provided for @updateSelectedVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected version'**
  String get updateSelectedVersionLabel;

  /// No description provided for @updateReleaseNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get updateReleaseNotesLabel;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get updateInstalling;

  /// No description provided for @updateDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get updateDownloadComplete;

  /// No description provided for @updateClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get updateClose;

  /// No description provided for @updateManualInstall.
  ///
  /// In en, this message translates to:
  /// **'Install manually'**
  String get updateManualInstall;

  /// No description provided for @updateOpenInstaller.
  ///
  /// In en, this message translates to:
  /// **'Open installer'**
  String get updateOpenInstaller;

  /// No description provided for @updateRetryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get updateRetryDownload;

  /// No description provided for @updateSkipVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkipVersion;

  /// No description provided for @updateRemindLater.
  ///
  /// In en, this message translates to:
  /// **'Remind me later'**
  String get updateRemindLater;

  /// No description provided for @updateOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Download in browser'**
  String get updateOpenBrowser;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updatePreviewBadge.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get updatePreviewBadge;

  /// No description provided for @updateLatestBadge.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get updateLatestBadge;

  /// No description provided for @updateSelectVersion.
  ///
  /// In en, this message translates to:
  /// **'Select version'**
  String get updateSelectVersion;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get updateDownloading;

  /// No description provided for @updateDownloadUrlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The download URL is unavailable.'**
  String get updateDownloadUrlUnavailable;

  /// No description provided for @updateNoDirectDownloadLink.
  ///
  /// In en, this message translates to:
  /// **'There is no direct download link for this platform. Download it in a browser.'**
  String get updateNoDirectDownloadLink;

  /// No description provided for @updateAutomaticInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic installation failed: {details}'**
  String updateAutomaticInstallFailed(Object details);

  /// No description provided for @updateDownloadHttpFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: HTTP {statusCode}'**
  String updateDownloadHttpFailed(Object statusCode);

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {details}'**
  String updateDownloadFailed(Object details);

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed: {details}'**
  String updateInstallFailed(Object details);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {details}'**
  String updateFailed(Object details);

  /// No description provided for @updateManualInstallFileError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file. Install it manually: {path}'**
  String updateManualInstallFileError(Object path);

  /// No description provided for @updateApkInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed. Open the APK manually: {details}'**
  String updateApkInstallFailed(Object details);

  /// No description provided for @updateApkInstallFailedNoDetails.
  ///
  /// In en, this message translates to:
  /// **'Installation failed. Open the APK manually.'**
  String get updateApkInstallFailedNoDetails;

  /// No description provided for @contextCompactionHistoryIntro.
  ///
  /// In en, this message translates to:
  /// **'Conversation history to condense:'**
  String get contextCompactionHistoryIntro;

  /// No description provided for @contextCompactionUserRole.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get contextCompactionUserRole;

  /// No description provided for @contextCompactionAssistantRole.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get contextCompactionAssistantRole;

  /// No description provided for @contextCompactionToolCall.
  ///
  /// In en, this message translates to:
  /// **'{role} called tool {toolName}: {result}'**
  String contextCompactionToolCall(Object result, Object role, Object toolName);

  /// No description provided for @contextCompactionFinalInstruction.
  ///
  /// In en, this message translates to:
  /// **'Condense the conversation history above into an anchored summary, following the template exactly.'**
  String get contextCompactionFinalInstruction;

  /// No description provided for @ocrImageEmpty.
  ///
  /// In en, this message translates to:
  /// **'The image is empty. Select it again.'**
  String get ocrImageEmpty;

  /// No description provided for @ocrImageUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'This image format is not supported. Convert it to PNG, JPEG, or WebP and try again.'**
  String get ocrImageUnsupportedFormat;

  /// No description provided for @ocrImageUnsupportedSpecialFormat.
  ///
  /// In en, this message translates to:
  /// **'HEIC, SVG, and TIFF images are not supported yet. Convert the image to PNG, JPEG, or WebP and try again.'**
  String get ocrImageUnsupportedSpecialFormat;

  /// No description provided for @ocrImageDecodeFailed.
  ///
  /// In en, this message translates to:
  /// **'The image is damaged or cannot be decoded. Select it again, or convert it to PNG, JPEG, or WebP and try again.'**
  String get ocrImageDecodeFailed;

  /// No description provided for @ocrImageDimensionsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image resolution is too large. OCR supports up to 50 million pixels per image. Resize it and try again.'**
  String get ocrImageDimensionsTooLarge;

  /// No description provided for @ocrImageOrientationPngTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The PNG needed to correct this image orientation would exceed the OCR request size limit. Resize the image and try again.'**
  String get ocrImageOrientationPngTooLarge;

  /// No description provided for @ocrImageOrientationFailed.
  ///
  /// In en, this message translates to:
  /// **'The image orientation could not be corrected. Convert it to PNG, JPEG, or WebP and try again.'**
  String get ocrImageOrientationFailed;

  /// No description provided for @ocrImagePreparationFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be processed. Select it again and try again.'**
  String get ocrImagePreparationFailed;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Stroom'**
  String get homeWelcome;

  /// No description provided for @homeChooseModule.
  ///
  /// In en, this message translates to:
  /// **'Choose a module to get started'**
  String get homeChooseModule;

  /// No description provided for @homeOcrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Text recognition'**
  String get homeOcrSubtitle;

  /// No description provided for @homeAsrTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get homeAsrTitle;

  /// No description provided for @homeAsrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Speech to text'**
  String get homeAsrSubtitle;

  /// No description provided for @homeWebDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download web media'**
  String get homeWebDownloadTitle;

  /// No description provided for @homeWebDownloadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download audio and video from webpages'**
  String get homeWebDownloadSubtitle;

  /// No description provided for @homeAudioSeparationTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio separation'**
  String get homeAudioSeparationTitle;

  /// No description provided for @homeAudioSeparationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extract audio from video'**
  String get homeAudioSeparationSubtitle;

  /// No description provided for @homeTtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Text to speech'**
  String get homeTtsTitle;

  /// No description provided for @homeTtsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Convert text to speech'**
  String get homeTtsSubtitle;

  /// No description provided for @homeChartsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart maker'**
  String get homeChartsTitle;

  /// No description provided for @homeChartsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mermaid chart editor'**
  String get homeChartsSubtitle;

  /// No description provided for @homeMathTitle.
  ///
  /// In en, this message translates to:
  /// **'Math plotting'**
  String get homeMathTitle;

  /// No description provided for @homeMathSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plot functions'**
  String get homeMathSubtitle;

  /// No description provided for @homeAnkiTitle.
  ///
  /// In en, this message translates to:
  /// **'Anki flashcards'**
  String get homeAnkiTitle;

  /// No description provided for @homeAnkiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Memory aid system'**
  String get homeAnkiSubtitle;

  /// No description provided for @homeTaskFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Task flows'**
  String get homeTaskFlowTitle;

  /// No description provided for @homeTaskFlowEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create an automated flow to run multiple modules in sequence'**
  String get homeTaskFlowEmpty;

  /// Number of task flows on the home screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task flow · Manage} other{{count} task flows · Manage}}'**
  String homeTaskFlowManage(int count);

  /// No description provided for @homeRecentTasks.
  ///
  /// In en, this message translates to:
  /// **'Recent tasks'**
  String get homeRecentTasks;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get navFiles;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @conversationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation history'**
  String get conversationsTitle;

  /// No description provided for @conversationNew.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get conversationNew;

  /// No description provided for @conversationDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation'**
  String get conversationDeleteTitle;

  /// Confirmation for deleting multiple conversations
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete the selected {count} conversation? This cannot be undone.} other{Delete the selected {count} conversations? This cannot be undone.}}'**
  String conversationDeleteMany(int count);

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @conversationRename.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get conversationRename;

  /// No description provided for @conversationRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new name'**
  String get conversationRenameHint;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @conversationNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations found'**
  String get conversationNoMatches;

  /// No description provided for @conversationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversation history'**
  String get conversationEmpty;

  /// No description provided for @conversationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages in all conversations...'**
  String get conversationSearchHint;

  /// Selected conversation count
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String conversationSelected(int count);

  /// No description provided for @conversationSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get conversationSearch;

  /// No description provided for @conversationDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get conversationDeleteSelected;

  /// No description provided for @actionUnselect.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get actionUnselect;

  /// No description provided for @actionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get actionSelect;

  /// Delete action with selected count
  ///
  /// In en, this message translates to:
  /// **'Delete {count}'**
  String conversationDeleteCount(int count);

  /// No description provided for @conversationPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get conversationPin;

  /// No description provided for @conversationUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get conversationUnpin;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @conversationAutoRename.
  ///
  /// In en, this message translates to:
  /// **'Auto-name'**
  String get conversationAutoRename;

  /// No description provided for @conversationTemporary.
  ///
  /// In en, this message translates to:
  /// **'Temporary conversation'**
  String get conversationTemporary;

  /// No description provided for @conversationCloseTemporary.
  ///
  /// In en, this message translates to:
  /// **'Close temporary conversation'**
  String get conversationCloseTemporary;

  /// No description provided for @taskListTitle.
  ///
  /// In en, this message translates to:
  /// **'Task list'**
  String get taskListTitle;

  /// No description provided for @taskListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get taskListEmpty;

  /// No description provided for @chatSearchCurrent.
  ///
  /// In en, this message translates to:
  /// **'Search this conversation...'**
  String get chatSearchCurrent;

  /// No description provided for @chatSearchAll.
  ///
  /// In en, this message translates to:
  /// **'Search all conversations...'**
  String get chatSearchAll;

  /// No description provided for @searchPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get searchPrevious;

  /// No description provided for @searchNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get searchNext;

  /// No description provided for @searchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchClose;

  /// No description provided for @searchCurrentConversation.
  ///
  /// In en, this message translates to:
  /// **'Current conversation'**
  String get searchCurrentConversation;

  /// No description provided for @searchAllConversations.
  ///
  /// In en, this message translates to:
  /// **'All conversations'**
  String get searchAllConversations;

  /// No description provided for @chatReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get chatReasoning;

  /// No description provided for @chatTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get chatTools;

  /// No description provided for @chatCustomParameters.
  ///
  /// In en, this message translates to:
  /// **'Custom parameters'**
  String get chatCustomParameters;

  /// No description provided for @chatEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessage;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @chatEditWarning.
  ///
  /// In en, this message translates to:
  /// **'All messages below will be lost when you edit and resend'**
  String get chatEditWarning;

  /// No description provided for @chatAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatAttachment;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a message...'**
  String get chatMessageHint;

  /// No description provided for @chatFullscreenEdit.
  ///
  /// In en, this message translates to:
  /// **'Full-screen editor'**
  String get chatFullscreenEdit;

  /// No description provided for @chatStopGeneration.
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get chatStopGeneration;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @chatViewResponseData.
  ///
  /// In en, this message translates to:
  /// **'View response data'**
  String get chatViewResponseData;

  /// No description provided for @chatViewRequestData.
  ///
  /// In en, this message translates to:
  /// **'View request data'**
  String get chatViewRequestData;

  /// No description provided for @chatInspectJson.
  ///
  /// In en, this message translates to:
  /// **'Inspect JSON'**
  String get chatInspectJson;

  /// No description provided for @chatConfirmEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatConfirmEditTitle;

  /// No description provided for @chatConfirmEditDeleteFollowing.
  ///
  /// In en, this message translates to:
  /// **'Edit this message? This message and all following messages will be deleted.'**
  String get chatConfirmEditDeleteFollowing;

  /// No description provided for @chatConfirmResend.
  ///
  /// In en, this message translates to:
  /// **'Resend this message?'**
  String get chatConfirmResend;

  /// No description provided for @chatConfirmRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatConfirmRetryTitle;

  /// No description provided for @chatConfirmRetryDeleteFollowing.
  ///
  /// In en, this message translates to:
  /// **'Retry this response? This message and all following messages will be deleted.'**
  String get chatConfirmRetryDeleteFollowing;

  /// No description provided for @chatConfirmRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate the response?'**
  String get chatConfirmRegenerate;

  /// No description provided for @chatDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessageTitle;

  /// No description provided for @chatDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this message? This cannot be undone.'**
  String get chatDeleteMessageConfirm;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get chatThinking;

  /// No description provided for @chatThinkingComplete.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get chatThinkingComplete;

  /// No description provided for @conversationDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation? This cannot be undone.'**
  String get conversationDeleteOne;

  /// Selected and total detected resource counts
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one{Selected {selected}/{total} resource} other{Selected {selected}/{total} resources}}'**
  String mediaSelectionCount(int selected, int total);

  /// No description provided for @mediaSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select media to download'**
  String get mediaSelectionTitle;

  /// Hide media playlist segments
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Hide {count} segment} other{Hide {count} segments}}'**
  String mediaCollapseSegments(int count);

  /// Show media playlist segments
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show {count} segment} other{Show {count} segments}}'**
  String mediaExpandSegments(int count);

  /// No description provided for @mediaNoResources.
  ///
  /// In en, this message translates to:
  /// **'No resources detected'**
  String get mediaNoResources;

  /// No description provided for @mediaSegment.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get mediaSegment;

  /// No description provided for @mediaPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get mediaPlaylist;

  /// No description provided for @mediaFullVideo.
  ///
  /// In en, this message translates to:
  /// **'Full video'**
  String get mediaFullVideo;

  /// Media duration display
  ///
  /// In en, this message translates to:
  /// **'Duration: {value}'**
  String mediaDuration(String value);

  /// Media dimensions display
  ///
  /// In en, this message translates to:
  /// **'Resolution: {width}x{height}'**
  String mediaResolution(int width, int height);

  /// No description provided for @mediaPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get mediaPreview;

  /// No description provided for @mediaSegmentPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Preview segments from the playlist'**
  String get mediaSegmentPreviewHint;

  /// Download selected resources
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Download {count} selected resource} other{Download {count} selected resources}}'**
  String mediaDownloadSelected(int count);

  /// No description provided for @mediaConfirmDownload.
  ///
  /// In en, this message translates to:
  /// **'Confirm download'**
  String get mediaConfirmDownload;

  /// No description provided for @chatNoMoreHistory.
  ///
  /// In en, this message translates to:
  /// **'No more messages'**
  String get chatNoMoreHistory;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message failed to send'**
  String get chatSendFailed;

  /// No description provided for @chatViewErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'View error details'**
  String get chatViewErrorDetails;

  /// No description provided for @chatCompactionCollapsed.
  ///
  /// In en, this message translates to:
  /// **'Context compacted · older messages summarized (click to collapse)'**
  String get chatCompactionCollapsed;

  /// No description provided for @chatCompactionExpanded.
  ///
  /// In en, this message translates to:
  /// **'Context compacted · older messages summarized (click to view summary)'**
  String get chatCompactionExpanded;

  /// No description provided for @chatEditConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit conversation title'**
  String get chatEditConversationTitle;

  /// No description provided for @chatSearchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchMessages;

  /// No description provided for @chatApiMissingSettings.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Chat API is not configured — go to Settings'**
  String get chatApiMissingSettings;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appSettings;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// No description provided for @chatNoSavableText.
  ///
  /// In en, this message translates to:
  /// **'There is no text to save'**
  String get chatNoSavableText;

  /// No description provided for @chatSaveMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Save message as Markdown'**
  String get chatSaveMarkdownTitle;

  /// No description provided for @chatSaveToolCallChoice.
  ///
  /// In en, this message translates to:
  /// **'This reply contains multiple tool calls. Choose what to save:'**
  String get chatSaveToolCallChoice;

  /// No description provided for @chatSaveCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Save complete message'**
  String get chatSaveCompleteMessage;

  /// No description provided for @chatSaveLastMessage.
  ///
  /// In en, this message translates to:
  /// **'Save last message'**
  String get chatSaveLastMessage;

  /// No description provided for @chatSaveToAppFiles.
  ///
  /// In en, this message translates to:
  /// **'Save to app files'**
  String get chatSaveToAppFiles;

  /// No description provided for @chatSaveFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a folder for the .md file'**
  String get chatSaveFolderHint;

  /// No description provided for @chatSaveFilenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name (.md is added automatically)'**
  String get chatSaveFilenameHint;

  /// No description provided for @chatFilenameRequired.
  ///
  /// In en, this message translates to:
  /// **'The file name cannot be empty'**
  String get chatFilenameRequired;

  /// Path of the saved Markdown file
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String chatSavedToPath(String path);

  /// Error from a failed save operation
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String chatSaveFailed(String error);

  /// Path of the saved application file
  ///
  /// In en, this message translates to:
  /// **'Saved to app files: {path}'**
  String chatSavedToAppFiles(String path);

  /// No description provided for @chatSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get chatSelectModel;

  /// No description provided for @chatNoModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get chatNoModelsAvailable;

  /// No description provided for @chatAvailableTools.
  ///
  /// In en, this message translates to:
  /// **'Available tools'**
  String get chatAvailableTools;

  /// No description provided for @chatNoToolsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tools available'**
  String get chatNoToolsAvailable;

  /// No description provided for @chatReasoningSettings.
  ///
  /// In en, this message translates to:
  /// **'Reasoning settings'**
  String get chatReasoningSettings;

  /// No description provided for @chatReasoningNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No reasoning parameters are configured for this model. Add them in model settings.'**
  String get chatReasoningNotConfigured;

  /// No description provided for @chatReasoningEffort.
  ///
  /// In en, this message translates to:
  /// **'Reasoning effort'**
  String get chatReasoningEffort;

  /// No description provided for @chatReasoningEffortNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No reasoning effort parameter is configured for this model. Add it in model settings.'**
  String get chatReasoningEffortNotConfigured;

  /// No description provided for @chatParameterNoOptions.
  ///
  /// In en, this message translates to:
  /// **'This parameter has no option values. Add them in model settings.'**
  String get chatParameterNoOptions;

  /// No description provided for @chatOtherReasoningNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No other reasoning parameters are configured for this model.\nAdd them in model settings.'**
  String get chatOtherReasoningNotConfigured;

  /// No description provided for @chatCustomParamsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No custom parameters are configured for this model.\nAdd them in model settings.'**
  String get chatCustomParamsNotConfigured;

  /// No description provided for @chatNoOptionValues.
  ///
  /// In en, this message translates to:
  /// **'No option values. Add them in model settings.'**
  String get chatNoOptionValues;

  /// No description provided for @chatImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load image'**
  String get chatImageLoadFailed;

  /// No description provided for @chatVideoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load video'**
  String get chatVideoLoadFailed;

  /// No description provided for @chatHtmlLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading HTML preview...'**
  String get chatHtmlLoading;

  /// No description provided for @chatPreviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview failed to load'**
  String get chatPreviewLoadFailed;

  /// No description provided for @chatHtmlPreview.
  ///
  /// In en, this message translates to:
  /// **'HTML preview'**
  String get chatHtmlPreview;

  /// No description provided for @chatMermaidLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading chart preview...'**
  String get chatMermaidLoading;

  /// No description provided for @chatMermaidPreview.
  ///
  /// In en, this message translates to:
  /// **'Mermaid preview'**
  String get chatMermaidPreview;

  /// No description provided for @chatZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get chatZoomOut;

  /// No description provided for @chatZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get chatZoomIn;

  /// No description provided for @chatJsonInspection.
  ///
  /// In en, this message translates to:
  /// **'JSON inspection'**
  String get chatJsonInspection;

  /// No description provided for @chatNoRequestData.
  ///
  /// In en, this message translates to:
  /// **'No request data'**
  String get chatNoRequestData;

  /// No description provided for @chatNoResponseData.
  ///
  /// In en, this message translates to:
  /// **'No response data'**
  String get chatNoResponseData;

  /// No description provided for @chatSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Save message'**
  String get chatSaveMessage;

  /// No description provided for @chatChooseSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose where to save the message'**
  String get chatChooseSaveLocation;

  /// No description provided for @chatChooseSaveLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose a save location:'**
  String get chatChooseSaveLocationLabel;

  /// No description provided for @chatSaveAppFile.
  ///
  /// In en, this message translates to:
  /// **'Save to app files'**
  String get chatSaveAppFile;

  /// No description provided for @chatSaveDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get chatSaveDevice;

  /// No description provided for @chatFileTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get chatFileTypeAudio;

  /// No description provided for @chatFileTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video file'**
  String get chatFileTypeVideo;

  /// No description provided for @chatFileTypeDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get chatFileTypeDocument;

  /// No description provided for @chatFileTypeGeneric.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileTypeGeneric;

  /// No description provided for @chatInfoType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get chatInfoType;

  /// No description provided for @chatInfoSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get chatInfoSize;

  /// No description provided for @chatInfoPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get chatInfoPath;

  /// No description provided for @chatErrorBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get chatErrorBack;

  /// No description provided for @chatDataDetails.
  ///
  /// In en, this message translates to:
  /// **'Data details'**
  String get chatDataDetails;

  /// No description provided for @chatAudioPreviewClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chatAudioPreviewClose;

  /// No description provided for @chatPreviewClose.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get chatPreviewClose;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @chatCannotLoadFile.
  ///
  /// In en, this message translates to:
  /// **'Unable to load file'**
  String get chatCannotLoadFile;

  /// Label for a numbered reasoning section
  ///
  /// In en, this message translates to:
  /// **'Thinking {index}'**
  String chatThinkingNumbered(int index);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
