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

  /// No description provided for @taskFlowBlockCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom block'**
  String get taskFlowBlockCustom;

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

  /// No description provided for @taskFlowUiDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get taskFlowUiDiscardTitle;

  /// No description provided for @taskFlowUiDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'All unsaved changes will be lost if you go back.'**
  String get taskFlowUiDiscardBody;

  /// No description provided for @taskFlowUiContinueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get taskFlowUiContinueEditing;

  /// No description provided for @taskFlowUiDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get taskFlowUiDiscard;

  /// No description provided for @taskFlowUiUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get taskFlowUiUndo;

  /// No description provided for @taskFlowUiSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get taskFlowUiSave;

  /// No description provided for @taskFlowUiNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a task flow name'**
  String get taskFlowUiNameHint;

  /// No description provided for @taskFlowUiDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a description (optional)'**
  String get taskFlowUiDescriptionHint;

  /// No description provided for @taskFlowUiNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a task flow name'**
  String get taskFlowUiNameRequired;

  /// No description provided for @taskFlowUiStepRequired.
  ///
  /// In en, this message translates to:
  /// **'Step {index}: {message}'**
  String taskFlowUiStepRequired(Object index, Object message);

  /// No description provided for @taskFlowUiParameterRequired.
  ///
  /// In en, this message translates to:
  /// **'“{parameter}” is required for “{block}”'**
  String taskFlowUiParameterRequired(Object block, Object parameter);

  /// No description provided for @taskFlowUiSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Your changes are still here. Try again.'**
  String get taskFlowUiSaveFailed;

  /// No description provided for @taskFlowUiRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get taskFlowUiRetry;

  /// No description provided for @taskFlowUiUpdated.
  ///
  /// In en, this message translates to:
  /// **'Task flow updated'**
  String get taskFlowUiUpdated;

  /// No description provided for @taskFlowUiCreated.
  ///
  /// In en, this message translates to:
  /// **'Task flow created'**
  String get taskFlowUiCreated;

  /// No description provided for @taskFlowUiTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Flow'**
  String get taskFlowUiTitle;

  /// No description provided for @taskFlowUiNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get taskFlowUiNotFound;

  /// No description provided for @taskFlowUiBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get taskFlowUiBack;

  /// No description provided for @taskFlowUiEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get taskFlowUiEdit;

  /// No description provided for @taskFlowUiInput.
  ///
  /// In en, this message translates to:
  /// **'Input ({label})'**
  String taskFlowUiInput(Object label);

  /// No description provided for @taskFlowUiInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text or a link'**
  String get taskFlowUiInputHint;

  /// No description provided for @taskFlowUiStart.
  ///
  /// In en, this message translates to:
  /// **'Start task flow'**
  String get taskFlowUiStart;

  /// No description provided for @taskFlowUiNoInput.
  ///
  /// In en, this message translates to:
  /// **'No inputs yet. Tap below to add a web resource URL.'**
  String get taskFlowUiNoInput;

  /// No description provided for @taskFlowUiAddResource.
  ///
  /// In en, this message translates to:
  /// **'Add web resource'**
  String get taskFlowUiAddResource;

  /// No description provided for @taskFlowUiUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a video or audio webpage URL'**
  String get taskFlowUiUrlHint;

  /// No description provided for @taskFlowUiDeleteInput.
  ///
  /// In en, this message translates to:
  /// **'Remove this input'**
  String get taskFlowUiDeleteInput;

  /// No description provided for @taskFlowUiHour.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get taskFlowUiHour;

  /// No description provided for @taskFlowUiMinute.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get taskFlowUiMinute;

  /// No description provided for @taskFlowUiSecond.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get taskFlowUiSecond;

  /// No description provided for @taskFlowUiPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: '**
  String get taskFlowUiPreview;

  /// No description provided for @taskFlowUiDurationFormat.
  ///
  /// In en, this message translates to:
  /// **'hh:mm:ss'**
  String get taskFlowUiDurationFormat;

  /// No description provided for @taskFlowUiDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Optional: filter video resources by duration. Leave blank to show all available resources.'**
  String get taskFlowUiDurationHint;

  /// No description provided for @taskFlowUiSelectImages.
  ///
  /// In en, this message translates to:
  /// **'Select images (multiple)'**
  String get taskFlowUiSelectImages;

  /// No description provided for @taskFlowUiSelectAudio.
  ///
  /// In en, this message translates to:
  /// **'Select audio (multiple)'**
  String get taskFlowUiSelectAudio;

  /// No description provided for @taskFlowUiSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files (multiple)'**
  String get taskFlowUiSelectFiles;

  /// No description provided for @taskFlowUiSelectVideo.
  ///
  /// In en, this message translates to:
  /// **'Select videos (multiple)'**
  String get taskFlowUiSelectVideo;

  /// No description provided for @taskFlowUiRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get taskFlowUiRemove;

  /// No description provided for @taskFlowUiRemovedFileCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clean up the removed file: {error}'**
  String taskFlowUiRemovedFileCleanupFailed(Object error);

  /// No description provided for @taskFlowUiInitialInput.
  ///
  /// In en, this message translates to:
  /// **'0. Initial input'**
  String get taskFlowUiInitialInput;

  /// No description provided for @taskFlowUiInputType.
  ///
  /// In en, this message translates to:
  /// **'Input type: {type}'**
  String taskFlowUiInputType(Object type);

  /// No description provided for @taskFlowUiUserFlowInput.
  ///
  /// In en, this message translates to:
  /// **'Input provided when the user runs the task flow'**
  String get taskFlowUiUserFlowInput;

  /// No description provided for @taskFlowUiBlockInput.
  ///
  /// In en, this message translates to:
  /// **'Input: {type}'**
  String taskFlowUiBlockInput(Object type);

  /// No description provided for @taskFlowUiBlockOutput.
  ///
  /// In en, this message translates to:
  /// **'Output: {type}'**
  String taskFlowUiBlockOutput(Object type);

  /// No description provided for @taskFlowUiParameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters:'**
  String get taskFlowUiParameters;

  /// No description provided for @taskFlowUiClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get taskFlowUiClose;

  /// No description provided for @taskFlowUiSelectAppImages.
  ///
  /// In en, this message translates to:
  /// **'Select images from the app (multiple)'**
  String get taskFlowUiSelectAppImages;

  /// No description provided for @taskFlowUiNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get taskFlowUiNoImages;

  /// No description provided for @taskFlowUiSelectAppAudio.
  ///
  /// In en, this message translates to:
  /// **'Select audio from the app (multiple)'**
  String get taskFlowUiSelectAppAudio;

  /// No description provided for @taskFlowUiNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio'**
  String get taskFlowUiNoAudio;

  /// No description provided for @taskFlowUiSelectAppVideo.
  ///
  /// In en, this message translates to:
  /// **'Select videos from the app (multiple)'**
  String get taskFlowUiSelectAppVideo;

  /// No description provided for @taskFlowUiNoVideo.
  ///
  /// In en, this message translates to:
  /// **'No videos'**
  String get taskFlowUiNoVideo;

  /// No description provided for @taskFlowUiFileSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select the file: {error}'**
  String taskFlowUiFileSelectFailed(Object error);

  /// No description provided for @taskFlowUiFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'“{name}” exceeds {limit} MB. Choose a smaller file.'**
  String taskFlowUiFileTooLarge(Object limit, Object name);

  /// No description provided for @taskFlowUiFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is empty or unreadable'**
  String taskFlowUiFileUnreadable(Object name);

  /// No description provided for @taskFlowUiSomeFilesMissing.
  ///
  /// In en, this message translates to:
  /// **'Some files are missing and were skipped'**
  String get taskFlowUiSomeFilesMissing;

  /// No description provided for @taskFlowUiQueuedOne.
  ///
  /// In en, this message translates to:
  /// **'Task flow added to the queue'**
  String get taskFlowUiQueuedOne;

  /// No description provided for @taskFlowUiQueuedMany.
  ///
  /// In en, this message translates to:
  /// **'Added {count} task flows to the queue'**
  String taskFlowUiQueuedMany(Object count);

  /// No description provided for @taskFlowUiRunTitle.
  ///
  /// In en, this message translates to:
  /// **'This Run'**
  String get taskFlowUiRunTitle;

  /// No description provided for @taskFlowUiCancelBatch.
  ///
  /// In en, this message translates to:
  /// **'Cancel entire batch'**
  String get taskFlowUiCancelBatch;

  /// No description provided for @taskFlowUiRestoringRecords.
  ///
  /// In en, this message translates to:
  /// **'Restoring task flow records…'**
  String get taskFlowUiRestoringRecords;

  /// No description provided for @taskFlowUiRecordsPaused.
  ///
  /// In en, this message translates to:
  /// **'Could not load task flow records. Task actions are paused.'**
  String get taskFlowUiRecordsPaused;

  /// No description provided for @taskFlowUiRecordsCleared.
  ///
  /// In en, this message translates to:
  /// **'Records for this run have been cleared'**
  String get taskFlowUiRecordsCleared;

  /// No description provided for @taskFlowUiRunsFinished.
  ///
  /// In en, this message translates to:
  /// **'{finished} of {total} runs finished'**
  String taskFlowUiRunsFinished(Object finished, Object total);

  /// No description provided for @taskFlowUiRecordsRemoved.
  ///
  /// In en, this message translates to:
  /// **' · {count} records cleared'**
  String taskFlowUiRecordsRemoved(Object count);

  /// No description provided for @taskFlowUiTemporaryFiles.
  ///
  /// In en, this message translates to:
  /// **'Temporary intermediate files'**
  String get taskFlowUiTemporaryFiles;

  /// No description provided for @taskFlowUiAddBlock.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get taskFlowUiAddBlock;

  /// No description provided for @taskFlowUiInsertBlockBefore.
  ///
  /// In en, this message translates to:
  /// **'Insert block before step {index}'**
  String taskFlowUiInsertBlockBefore(Object index);

  /// No description provided for @taskFlowUiIncompatibleAdjacentBlocks.
  ///
  /// In en, this message translates to:
  /// **'No block is compatible with both adjacent steps. Adjust the adjacent steps first.'**
  String get taskFlowUiIncompatibleAdjacentBlocks;

  /// No description provided for @taskFlowUiInsertBeforeStep.
  ///
  /// In en, this message translates to:
  /// **'Insert before step {index}'**
  String taskFlowUiInsertBeforeStep(Object index);

  /// No description provided for @taskFlowUiUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get taskFlowUiUnknown;

  /// No description provided for @taskFlowUiChooseBlock.
  ///
  /// In en, this message translates to:
  /// **'Choose a block'**
  String get taskFlowUiChooseBlock;

  /// No description provided for @taskFlowUiInsertBlock.
  ///
  /// In en, this message translates to:
  /// **'Insert block'**
  String get taskFlowUiInsertBlock;

  /// No description provided for @taskFlowUiPreviousOutput.
  ///
  /// In en, this message translates to:
  /// **'Previous step output'**
  String get taskFlowUiPreviousOutput;

  /// No description provided for @taskFlowUiNextStepNeeds.
  ///
  /// In en, this message translates to:
  /// **'; next step needs: {label}'**
  String taskFlowUiNextStepNeeds(Object label);

  /// No description provided for @taskFlowUiNoCompatibleBlock.
  ///
  /// In en, this message translates to:
  /// **'No block is compatible with the current type'**
  String get taskFlowUiNoCompatibleBlock;

  /// No description provided for @taskFlowUiReplaceBlock.
  ///
  /// In en, this message translates to:
  /// **'Replace block'**
  String get taskFlowUiReplaceBlock;

  /// No description provided for @taskFlowUiBlockCompatibility.
  ///
  /// In en, this message translates to:
  /// **'You can only replace this with a block that has compatible input and output types.'**
  String get taskFlowUiBlockCompatibility;

  /// No description provided for @taskFlowUiTemporaryCleanupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clean up after the next step saves its result successfully; the final step is always kept.'**
  String get taskFlowUiTemporaryCleanupTooltip;

  /// No description provided for @taskFlowUiSetParameters.
  ///
  /// In en, this message translates to:
  /// **'Set parameters'**
  String get taskFlowUiSetParameters;

  /// No description provided for @taskFlowUiReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get taskFlowUiReplace;

  /// No description provided for @taskFlowUiViewParameters.
  ///
  /// In en, this message translates to:
  /// **'Tap to view parameters'**
  String get taskFlowUiViewParameters;

  /// No description provided for @taskFlowUiTapSetParameters.
  ///
  /// In en, this message translates to:
  /// **'Tap to set parameters'**
  String get taskFlowUiTapSetParameters;

  /// No description provided for @taskFlowUiUnknownBlockType.
  ///
  /// In en, this message translates to:
  /// **'Unknown block: {name}'**
  String taskFlowUiUnknownBlockType(Object name);

  /// No description provided for @taskFlowUiBlockUnregistered.
  ///
  /// In en, this message translates to:
  /// **'This block type is not registered'**
  String get taskFlowUiBlockUnregistered;

  /// No description provided for @taskFlowUiStepActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for step {index}'**
  String taskFlowUiStepActions(Object index);

  /// No description provided for @taskFlowUiInsertBefore.
  ///
  /// In en, this message translates to:
  /// **'Insert before'**
  String get taskFlowUiInsertBefore;

  /// No description provided for @taskFlowUiInsertAfter.
  ///
  /// In en, this message translates to:
  /// **'Insert after'**
  String get taskFlowUiInsertAfter;

  /// No description provided for @taskFlowUiCopyBlock.
  ///
  /// In en, this message translates to:
  /// **'Duplicate block'**
  String get taskFlowUiCopyBlock;

  /// No description provided for @taskFlowUiMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get taskFlowUiMoveUp;

  /// No description provided for @taskFlowUiMoveUpDisabled.
  ///
  /// In en, this message translates to:
  /// **'Move up (already first)'**
  String get taskFlowUiMoveUpDisabled;

  /// No description provided for @taskFlowUiMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get taskFlowUiMoveDown;

  /// No description provided for @taskFlowUiMoveDownDisabled.
  ///
  /// In en, this message translates to:
  /// **'Move down (already last)'**
  String get taskFlowUiMoveDownDisabled;

  /// No description provided for @taskFlowUiDeleteBlock.
  ///
  /// In en, this message translates to:
  /// **'Delete block'**
  String get taskFlowUiDeleteBlock;

  /// No description provided for @taskFlowUiInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input: {label}'**
  String taskFlowUiInputLabel(Object label);

  /// No description provided for @taskFlowUiOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output: {label}'**
  String taskFlowUiOutputLabel(Object label);

  /// No description provided for @taskFlowUiUnregisteredBlockType.
  ///
  /// In en, this message translates to:
  /// **'Block type “{name}” is not registered'**
  String taskFlowUiUnregisteredBlockType(Object name);

  /// No description provided for @taskFlowUiBlockSettings.
  ///
  /// In en, this message translates to:
  /// **'{label} settings'**
  String taskFlowUiBlockSettings(Object label);

  /// No description provided for @taskFlowUiSendToAssistant.
  ///
  /// In en, this message translates to:
  /// **'The user message sent to the assistant is the previous step’s output'**
  String get taskFlowUiSendToAssistant;

  /// No description provided for @taskFlowUiTempSpaceInfo.
  ///
  /// In en, this message translates to:
  /// **'This step outputs to the flow’s temporary space. Its output is cleaned up after the next step saves successfully. The original save folder is preserved and restored when temporary mode is disabled.'**
  String get taskFlowUiTempSpaceInfo;

  /// No description provided for @taskFlowUiNoExtraParameters.
  ///
  /// In en, this message translates to:
  /// **'This block has no additional parameters'**
  String get taskFlowUiNoExtraParameters;

  /// No description provided for @taskFlowUiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskFlowUiCancel;

  /// No description provided for @taskFlowUiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get taskFlowUiConfirm;

  /// No description provided for @taskFlowUiConfigureModelFirst.
  ///
  /// In en, this message translates to:
  /// **'Configure a model first'**
  String get taskFlowUiConfigureModelFirst;

  /// No description provided for @taskFlowUiModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No model is selected or the model is unavailable. Select another model.'**
  String get taskFlowUiModelUnavailable;

  /// No description provided for @taskFlowUiModelIndexed.
  ///
  /// In en, this message translates to:
  /// **'Model {index}'**
  String taskFlowUiModelIndexed(Object index);

  /// No description provided for @taskFlowUiUnnamedProvider.
  ///
  /// In en, this message translates to:
  /// **'Unnamed provider'**
  String get taskFlowUiUnnamedProvider;

  /// No description provided for @taskFlowUiCustomModelParameters.
  ///
  /// In en, this message translates to:
  /// **'Custom model parameters'**
  String get taskFlowUiCustomModelParameters;

  /// No description provided for @taskFlowUiTtsVoiceMissing.
  ///
  /// In en, this message translates to:
  /// **'No TTS models have configured voices. You can enter an ID manually.'**
  String get taskFlowUiTtsVoiceMissing;

  /// No description provided for @taskFlowUiVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice is unavailable. Select another voice.'**
  String get taskFlowUiVoiceUnavailable;

  /// No description provided for @taskFlowUiSelectVoice.
  ///
  /// In en, this message translates to:
  /// **'Select a voice'**
  String get taskFlowUiSelectVoice;

  /// No description provided for @taskFlowUiAssistantUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Assistant unavailable'**
  String get taskFlowUiAssistantUnavailable;

  /// No description provided for @taskFlowUiAssistantUseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Not specified (use the currently selected assistant)'**
  String get taskFlowUiAssistantUseCurrent;

  /// No description provided for @taskFlowUiAssistantDeleted.
  ///
  /// In en, this message translates to:
  /// **'The configured assistant was deleted. Select another assistant.'**
  String get taskFlowUiAssistantDeleted;

  /// No description provided for @taskFlowUiChooseAssistant.
  ///
  /// In en, this message translates to:
  /// **'Choose an assistant'**
  String get taskFlowUiChooseAssistant;

  /// No description provided for @taskFlowUiOnlyCustomAssistants.
  ///
  /// In en, this message translates to:
  /// **'Only “My Assistants” can be selected (add one in “Chat → Assistants”)'**
  String get taskFlowUiOnlyCustomAssistants;

  /// No description provided for @taskFlowUiMyAssistants.
  ///
  /// In en, this message translates to:
  /// **'My Assistants'**
  String get taskFlowUiMyAssistants;

  /// No description provided for @taskFlowUiNoCustomAssistants.
  ///
  /// In en, this message translates to:
  /// **'No custom assistants yet. Create one in “Chat → Assistants”.'**
  String get taskFlowUiNoCustomAssistants;

  /// No description provided for @taskFlowUiYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get taskFlowUiYes;

  /// No description provided for @taskFlowUiNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get taskFlowUiNo;

  /// No description provided for @taskFlowUiDefaultRoot.
  ///
  /// In en, this message translates to:
  /// **'Default (root folder)'**
  String get taskFlowUiDefaultRoot;

  /// No description provided for @taskFlowUiSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get taskFlowUiSelect;

  /// No description provided for @taskFlowUiSelectSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a save folder'**
  String get taskFlowUiSelectSaveFolder;

  /// No description provided for @taskFlowUiCatCatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get taskFlowUiCatCatchVideo;

  /// No description provided for @taskFlowUiCatCatchAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get taskFlowUiCatCatchAudio;

  /// No description provided for @taskFlowUiCatCatchEither.
  ///
  /// In en, this message translates to:
  /// **'Video or audio (filter based on downstream steps)'**
  String get taskFlowUiCatCatchEither;

  /// No description provided for @taskFlowUiManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get taskFlowUiManual;

  /// No description provided for @taskFlowUiAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get taskFlowUiAutomatic;

  /// No description provided for @taskFlowUiAutomaticPrompt.
  ///
  /// In en, this message translates to:
  /// **'Automatic with confirmation'**
  String get taskFlowUiAutomaticPrompt;

  /// No description provided for @taskFlowUiEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Task Flow'**
  String get taskFlowUiEditTitle;

  /// No description provided for @taskFlowUiCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Task Flow'**
  String get taskFlowUiCreateTitle;

  /// No description provided for @taskFlowUiStepNumber.
  ///
  /// In en, this message translates to:
  /// **'Step {index}: {message}'**
  String taskFlowUiStepNumber(Object index, Object message);

  /// No description provided for @taskFlowUiInputTypeValue.
  ///
  /// In en, this message translates to:
  /// **'Input type: {type}'**
  String taskFlowUiInputTypeValue(Object type);

  /// No description provided for @taskFlowUiBlockInputValue.
  ///
  /// In en, this message translates to:
  /// **'Input: {type}'**
  String taskFlowUiBlockInputValue(Object type);

  /// No description provided for @taskFlowUiBlockOutputValue.
  ///
  /// In en, this message translates to:
  /// **'Output: {type}'**
  String taskFlowUiBlockOutputValue(Object type);

  /// No description provided for @taskFlowUiCleanupError.
  ///
  /// In en, this message translates to:
  /// **'Could not clean up the removed file: {error}'**
  String taskFlowUiCleanupError(Object error);

  /// No description provided for @taskFlowUiSelectFileError.
  ///
  /// In en, this message translates to:
  /// **'Could not select the file: {error}'**
  String taskFlowUiSelectFileError(Object error);

  /// No description provided for @taskFlowUiLargeFile.
  ///
  /// In en, this message translates to:
  /// **'“{name}” exceeds {limit} MB. Choose a smaller file.'**
  String taskFlowUiLargeFile(Object limit, Object name);

  /// No description provided for @taskFlowUiUnreadableFile.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is empty or unreadable'**
  String taskFlowUiUnreadableFile(Object name);

  /// No description provided for @taskFlowUiTemporary.
  ///
  /// In en, this message translates to:
  /// **'Temporary'**
  String get taskFlowUiTemporary;

  /// No description provided for @taskFlowUiTemporaryFileHint.
  ///
  /// In en, this message translates to:
  /// **'Temporary file (cleaned up after the next step succeeds)'**
  String get taskFlowUiTemporaryFileHint;

  /// No description provided for @taskFlowUiUnregisteredBlock.
  ///
  /// In en, this message translates to:
  /// **'Block type “{name}” is not registered'**
  String taskFlowUiUnregisteredBlock(Object name);

  /// No description provided for @taskFlowUiRunSummary.
  ///
  /// In en, this message translates to:
  /// **'{finished} of {total} runs finished'**
  String taskFlowUiRunSummary(Object finished, Object total);

  /// No description provided for @taskFlowUiClearedRecordCount.
  ///
  /// In en, this message translates to:
  /// **' · {count} records cleared'**
  String taskFlowUiClearedRecordCount(Object count);

  /// No description provided for @taskFlowUiInputOutput.
  ///
  /// In en, this message translates to:
  /// **'Input: {input} → Output: {output}'**
  String taskFlowUiInputOutput(Object input, Object output);

  /// No description provided for @taskFlowCardTag.
  ///
  /// In en, this message translates to:
  /// **'Task Flow'**
  String get taskFlowCardTag;

  /// No description provided for @taskFlowCardQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued (waiting for resources)'**
  String get taskFlowCardQueued;

  /// No description provided for @taskFlowCardCompletedProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} completed'**
  String taskFlowCardCompletedProgress(Object done, Object total);

  /// No description provided for @taskFlowCardCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} {label}'**
  String taskFlowCardCountLabel(Object count, Object label);

  /// No description provided for @taskFlowCardFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get taskFlowCardFailedLabel;

  /// No description provided for @taskFlowCardSkippedLabel.
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get taskFlowCardSkippedLabel;

  /// No description provided for @taskFlowCardCancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get taskFlowCardCancelledLabel;

  /// No description provided for @taskFlowCardInterruptedLabel.
  ///
  /// In en, this message translates to:
  /// **'interrupted'**
  String get taskFlowCardInterruptedLabel;

  /// No description provided for @taskFlowCardCancelFlow.
  ///
  /// In en, this message translates to:
  /// **'Cancel flow'**
  String get taskFlowCardCancelFlow;

  /// No description provided for @taskFlowCardRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get taskFlowCardRetry;

  /// No description provided for @taskFlowCardCancelBatch.
  ///
  /// In en, this message translates to:
  /// **'Cancel entire batch'**
  String get taskFlowCardCancelBatch;

  /// No description provided for @taskFlowCardDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taskFlowCardDelete;

  /// No description provided for @taskFlowCardRetryFlow.
  ///
  /// In en, this message translates to:
  /// **'Retry task flow'**
  String get taskFlowCardRetryFlow;

  /// No description provided for @taskFlowCardNoSnapshot.
  ///
  /// In en, this message translates to:
  /// **'This run has no snapshot. It will start over using the current flow configuration.'**
  String get taskFlowCardNoSnapshot;

  /// No description provided for @taskFlowCardRetryInfo.
  ///
  /// In en, this message translates to:
  /// **'Starting over downloads files and calls models again. Retry with the configuration used at launch, or explicitly choose the latest configuration. To reuse completed steps, choose “Resume from interrupted step.”'**
  String get taskFlowCardRetryInfo;

  /// No description provided for @taskFlowCardRunLatest.
  ///
  /// In en, this message translates to:
  /// **'Run with latest configuration'**
  String get taskFlowCardRunLatest;

  /// No description provided for @taskFlowCardRetryOriginal.
  ///
  /// In en, this message translates to:
  /// **'Retry with original configuration'**
  String get taskFlowCardRetryOriginal;

  /// No description provided for @taskFlowCardDeleteRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete task flow record'**
  String get taskFlowCardDeleteRecord;

  /// No description provided for @taskFlowCardDeleteBatchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deleting this run will cancel unfinished tasks in the batch and clear their subtask records. Delete?'**
  String get taskFlowCardDeleteBatchConfirm;

  /// No description provided for @taskFlowCardDeleteRunningConfirm.
  ///
  /// In en, this message translates to:
  /// **'This flow is running. Deleting it will cancel its active tasks. Delete?'**
  String get taskFlowCardDeleteRunningConfirm;

  /// No description provided for @taskFlowCardDeleteRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this flow record and its subtask records?'**
  String get taskFlowCardDeleteRecordConfirm;

  /// No description provided for @taskFlowCardDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this flow record?'**
  String get taskFlowCardDeleteConfirm;

  /// No description provided for @taskFlowCardSaveCancelStateError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the flow cancellation state. Try deleting again.'**
  String get taskFlowCardSaveCancelStateError;

  /// No description provided for @taskFlowCardStillRunning.
  ///
  /// In en, this message translates to:
  /// **'The flow is still running after cancellation.'**
  String get taskFlowCardStillRunning;

  /// No description provided for @taskFlowCardSaveDeleteStateError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the flow record deletion state. Try deleting again.'**
  String get taskFlowCardSaveDeleteStateError;

  /// No description provided for @taskFlowCardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get taskFlowCardConfirm;

  /// No description provided for @taskFlowCardWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get taskFlowCardWaiting;

  /// No description provided for @taskFlowCardRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get taskFlowCardRunning;

  /// No description provided for @taskFlowCardPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get taskFlowCardPaused;

  /// No description provided for @taskFlowCardCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskFlowCardCompleted;

  /// No description provided for @taskFlowCardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get taskFlowCardFailed;

  /// No description provided for @taskFlowCardCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get taskFlowCardCanceled;

  /// No description provided for @taskFlowCardInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get taskFlowCardInterrupted;

  /// No description provided for @taskFlowCardSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get taskFlowCardSucceeded;

  /// No description provided for @taskFlowCardPause.
  ///
  /// In en, this message translates to:
  /// **'Pause flow'**
  String get taskFlowCardPause;

  /// No description provided for @taskFlowCardResume.
  ///
  /// In en, this message translates to:
  /// **'Resume flow'**
  String get taskFlowCardResume;

  /// No description provided for @taskFlowCardResumeInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Resume from interrupted step'**
  String get taskFlowCardResumeInterrupted;

  /// No description provided for @taskFlowCardCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskFlowCardCancel;

  /// No description provided for @unifiedTaskType.
  ///
  /// In en, this message translates to:
  /// **'Task type'**
  String get unifiedTaskType;

  /// No description provided for @unifiedTaskCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get unifiedTaskCreatedAt;

  /// No description provided for @unifiedTaskCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get unifiedTaskCompletedAt;

  /// No description provided for @unifiedTaskResultStatus.
  ///
  /// In en, this message translates to:
  /// **'Result status'**
  String get unifiedTaskResultStatus;

  /// No description provided for @unifiedTaskPartialResult.
  ///
  /// In en, this message translates to:
  /// **'Partial result; content may be incomplete'**
  String get unifiedTaskPartialResult;

  /// No description provided for @unifiedTaskErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get unifiedTaskErrorDetails;

  /// No description provided for @unifiedTaskViewErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'View error details'**
  String get unifiedTaskViewErrorDetails;

  /// No description provided for @unifiedTaskOcrPerImage.
  ///
  /// In en, this message translates to:
  /// **'Recognize each image'**
  String get unifiedTaskOcrPerImage;

  /// No description provided for @unifiedTaskOcrPageIndex.
  ///
  /// In en, this message translates to:
  /// **'Image {index}'**
  String unifiedTaskOcrPageIndex(Object index);

  /// No description provided for @unifiedTaskOcrPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to recognize'**
  String get unifiedTaskOcrPending;

  /// No description provided for @unifiedTaskOcrRunning.
  ///
  /// In en, this message translates to:
  /// **'Recognizing'**
  String get unifiedTaskOcrRunning;

  /// No description provided for @unifiedTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get unifiedTaskCompleted;

  /// No description provided for @unifiedTaskIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete result'**
  String get unifiedTaskIncomplete;

  /// No description provided for @unifiedTaskOcrFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed'**
  String get unifiedTaskOcrFailed;

  /// No description provided for @unifiedTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get unifiedTaskCancelled;

  /// No description provided for @unifiedTaskWaitingStart.
  ///
  /// In en, this message translates to:
  /// **'Waiting to start...'**
  String get unifiedTaskWaitingStart;

  /// No description provided for @unifiedTaskSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get unifiedTaskSteps;

  /// No description provided for @unifiedTaskStartNow.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get unifiedTaskStartNow;

  /// No description provided for @unifiedTaskOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get unifiedTaskOpenFile;

  /// No description provided for @unifiedTaskRetrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry saving only'**
  String get unifiedTaskRetrySave;

  /// No description provided for @unifiedTaskRetryPartialSave.
  ///
  /// In en, this message translates to:
  /// **'Retry saving partial result only'**
  String get unifiedTaskRetryPartialSave;

  /// No description provided for @unifiedTaskSavePartialResult.
  ///
  /// In en, this message translates to:
  /// **'Save partial result'**
  String get unifiedTaskSavePartialResult;

  /// No description provided for @unifiedTaskRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get unifiedTaskRetry;

  /// No description provided for @unifiedTaskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get unifiedTaskCancel;

  /// No description provided for @unifiedTaskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get unifiedTaskDelete;

  /// No description provided for @unifiedTaskFormatUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Preview is not supported for this format'**
  String get unifiedTaskFormatUnsupported;

  /// No description provided for @unifiedTaskLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String unifiedTaskLoadFailed(Object error);

  /// No description provided for @unifiedTaskPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String unifiedTaskPlaybackFailed(Object error);

  /// No description provided for @unifiedTaskAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get unifiedTaskAudioFile;

  /// No description provided for @unifiedTaskPreviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load preview'**
  String get unifiedTaskPreviewLoadFailed;

  /// No description provided for @unifiedTaskUnknownSize.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get unifiedTaskUnknownSize;

  /// No description provided for @unifiedTaskUnnamedRecording.
  ///
  /// In en, this message translates to:
  /// **'Untitled recording'**
  String get unifiedTaskUnnamedRecording;

  /// No description provided for @unifiedTaskPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get unifiedTaskPause;

  /// No description provided for @unifiedTaskClearTask.
  ///
  /// In en, this message translates to:
  /// **'Clear task'**
  String get unifiedTaskClearTask;

  /// No description provided for @unifiedTaskContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get unifiedTaskContinue;

  /// No description provided for @unifiedTaskRemoveFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get unifiedTaskRemoveFromList;

  /// No description provided for @unifiedTaskSynthesisText.
  ///
  /// In en, this message translates to:
  /// **'Synthesized text'**
  String get unifiedTaskSynthesisText;

  /// No description provided for @unifiedTaskStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get unifiedTaskStatus;

  /// No description provided for @unifiedTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get unifiedTaskDetails;

  /// No description provided for @unifiedTaskSynthesisError.
  ///
  /// In en, this message translates to:
  /// **'Synthesis error details'**
  String get unifiedTaskSynthesisError;

  /// No description provided for @unifiedTaskClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get unifiedTaskClose;

  /// No description provided for @unifiedTaskRawRequestResponse.
  ///
  /// In en, this message translates to:
  /// **'Raw request and response'**
  String get unifiedTaskRawRequestResponse;

  /// No description provided for @unifiedTaskRawRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Raw request body:'**
  String get unifiedTaskRawRequestBody;

  /// No description provided for @unifiedTaskRawResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Raw response body:'**
  String get unifiedTaskRawResponseBody;

  /// No description provided for @commonJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get commonJustNow;

  /// No description provided for @commonMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String commonMinutesAgo(Object count);

  /// No description provided for @commonHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hr ago'**
  String commonHoursAgo(Object count);

  /// No description provided for @unifiedDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} sec'**
  String unifiedDurationSeconds(Object seconds);

  /// No description provided for @unifiedDurationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} sec'**
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds);

  /// No description provided for @unifiedDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String unifiedDurationHoursMinutes(Object hours, Object minutes);

  /// No description provided for @unifiedTaskTypeOcr.
  ///
  /// In en, this message translates to:
  /// **'Image text recognition'**
  String get unifiedTaskTypeOcr;

  /// No description provided for @unifiedTaskTypeAsr.
  ///
  /// In en, this message translates to:
  /// **'Audio transcription'**
  String get unifiedTaskTypeAsr;

  /// No description provided for @unifiedTaskTypeAudioSeparation.
  ///
  /// In en, this message translates to:
  /// **'Audio separation'**
  String get unifiedTaskTypeAudioSeparation;

  /// No description provided for @unifiedTaskTypeChat.
  ///
  /// In en, this message translates to:
  /// **'Assistant chat'**
  String get unifiedTaskTypeChat;

  /// No description provided for @unifiedTaskPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get unifiedTaskPlayAudio;

  /// No description provided for @unifiedTaskPauseAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause audio'**
  String get unifiedTaskPauseAudio;

  /// No description provided for @catcatchFlowActionNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Flow action did not start. Check the flow status and try again.'**
  String get catcatchFlowActionNotStarted;

  /// No description provided for @catcatchFlowActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Flow action failed: {error}'**
  String catcatchFlowActionFailed(Object error);

  /// No description provided for @catcatchSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped (nothing to process)'**
  String get catcatchSkipped;

  /// No description provided for @catcatchRetryStep.
  ///
  /// In en, this message translates to:
  /// **'Retry this step'**
  String get catcatchRetryStep;

  /// No description provided for @catcatchCollapseSegments.
  ///
  /// In en, this message translates to:
  /// **'Hide {count} segments'**
  String catcatchCollapseSegments(Object count);

  /// No description provided for @catcatchShowSegments.
  ///
  /// In en, this message translates to:
  /// **'Show {count} segments'**
  String catcatchShowSegments(Object count);

  /// No description provided for @catcatchSelectedResources.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} resources selected'**
  String catcatchSelectedResources(Object selected, Object total);

  /// No description provided for @catcatchDetectedMediaResources.
  ///
  /// In en, this message translates to:
  /// **'{count} media resources detected'**
  String catcatchDetectedMediaResources(Object count);

  /// No description provided for @catcatchFlowSelectOrCombine.
  ///
  /// In en, this message translates to:
  /// **'(select one resource or combine an audio/video pair)'**
  String get catcatchFlowSelectOrCombine;

  /// No description provided for @catcatchSelectMultiple.
  ///
  /// In en, this message translates to:
  /// **'(tap to select; multiple allowed)'**
  String get catcatchSelectMultiple;

  /// No description provided for @catcatchWaitingForResources.
  ///
  /// In en, this message translates to:
  /// **'Waiting for flow resources'**
  String get catcatchWaitingForResources;

  /// No description provided for @catcatchDownloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download {count} selected resources'**
  String catcatchDownloadSelected(Object count);

  /// No description provided for @catcatchSelectResources.
  ///
  /// In en, this message translates to:
  /// **'Select resources to download'**
  String get catcatchSelectResources;

  /// No description provided for @catcatchPossibleSplit.
  ///
  /// In en, this message translates to:
  /// **'⚠ Possible separate audio and video streams'**
  String get catcatchPossibleSplit;

  /// No description provided for @catcatchSplitExplanation.
  ///
  /// In en, this message translates to:
  /// **'These resources may be separate audio and video streams for the same video. You can combine them or download only one stream.'**
  String get catcatchSplitExplanation;

  /// No description provided for @catcatchAudioStream.
  ///
  /// In en, this message translates to:
  /// **'🎵 Audio stream'**
  String get catcatchAudioStream;

  /// No description provided for @catcatchVideoStream.
  ///
  /// In en, this message translates to:
  /// **'🎬 Video stream'**
  String get catcatchVideoStream;

  /// No description provided for @catcatchMergeAudioVideo.
  ///
  /// In en, this message translates to:
  /// **'Combine audio and video'**
  String get catcatchMergeAudioVideo;

  /// No description provided for @catcatchVideoOnly.
  ///
  /// In en, this message translates to:
  /// **'Video only'**
  String get catcatchVideoOnly;

  /// No description provided for @catcatchAudioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get catcatchAudioOnly;

  /// No description provided for @catcatchSegmentsPlaylistPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview segments using the playlist'**
  String get catcatchSegmentsPlaylistPreview;

  /// No description provided for @catcatchPreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'Preview audio'**
  String get catcatchPreviewAudio;

  /// No description provided for @catcatchPreviewVideo.
  ///
  /// In en, this message translates to:
  /// **'Preview video'**
  String get catcatchPreviewVideo;

  /// No description provided for @catcatchDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String catcatchDuration(Object duration);

  /// No description provided for @catcatchSegment.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get catcatchSegment;

  /// No description provided for @catcatchPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get catcatchPlaylist;

  /// No description provided for @catcatchFullVideo.
  ///
  /// In en, this message translates to:
  /// **'Full video'**
  String get catcatchFullVideo;

  /// No description provided for @catcatchSeparateTracks.
  ///
  /// In en, this message translates to:
  /// **'Separate tracks'**
  String get catcatchSeparateTracks;

  /// No description provided for @catcatchPreviewPlaylistOnly.
  ///
  /// In en, this message translates to:
  /// **'Preview using the playlist'**
  String get catcatchPreviewPlaylistOnly;

  /// No description provided for @catcatchPreviewUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Preview is not supported'**
  String get catcatchPreviewUnsupported;

  /// No description provided for @catcatchUnknownFormat.
  ///
  /// In en, this message translates to:
  /// **'Unknown format'**
  String get catcatchUnknownFormat;

  /// No description provided for @catcatchNeedPlaylistProcessing.
  ///
  /// In en, this message translates to:
  /// **'Playlist processing required'**
  String get catcatchNeedPlaylistProcessing;

  /// No description provided for @catcatchSpecialFormatDetected.
  ///
  /// In en, this message translates to:
  /// **'Special format detected'**
  String get catcatchSpecialFormatDetected;

  /// No description provided for @catcatchPlaylistInfo.
  ///
  /// In en, this message translates to:
  /// **'This resource is a playlist ({format}). It must be parsed and all segments downloaded and combined into a playable video.'**
  String catcatchPlaylistInfo(Object format);

  /// No description provided for @catcatchFormatInfo.
  ///
  /// In en, this message translates to:
  /// **'The downloaded file is in {format}, not standard MP4. The built-in pure Dart remux engine will convert it to MP4 (TS/FLV/EV1 require no external dependencies).'**
  String catcatchFormatInfo(Object format);

  /// No description provided for @catcatchContinueBeforeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Resume the flow before confirming format handling'**
  String get catcatchContinueBeforeConfirm;

  /// No description provided for @catcatchAutoProcess.
  ///
  /// In en, this message translates to:
  /// **'Process automatically'**
  String get catcatchAutoProcess;

  /// No description provided for @catcatchKeepOriginalFormat.
  ///
  /// In en, this message translates to:
  /// **'Keep original format'**
  String get catcatchKeepOriginalFormat;

  /// No description provided for @catcatchResumeSupported.
  ///
  /// In en, this message translates to:
  /// **'Resume supported'**
  String get catcatchResumeSupported;

  /// No description provided for @catcatchResumeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This site does not support resuming'**
  String get catcatchResumeUnsupported;

  /// No description provided for @catcatchPauseDownload.
  ///
  /// In en, this message translates to:
  /// **'Pause download'**
  String get catcatchPauseDownload;

  /// No description provided for @catcatchResumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get catcatchResumeDownload;

  /// No description provided for @catcatchRestartDownload.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get catcatchRestartDownload;

  /// No description provided for @catcatchPendingFormatAction.
  ///
  /// In en, this message translates to:
  /// **'Waiting for flow resources'**
  String get catcatchPendingFormatAction;

  /// No description provided for @quitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Quit app?'**
  String get quitDialogTitle;

  /// No description provided for @quitDialogRunningTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks are running. Quitting will interrupt them. Do you want to quit?'**
  String quitDialogRunningTasks(Object count);

  /// No description provided for @quitDialogNoTasks.
  ///
  /// In en, this message translates to:
  /// **'Do you want to quit Stroom?'**
  String get quitDialogNoTasks;

  /// No description provided for @quitDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get quitDialogCancel;

  /// No description provided for @quitDialogExit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quitDialogExit;

  /// No description provided for @searchPanelNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get searchPanelNewConversation;

  /// No description provided for @searchPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get searchPanelTitle;

  /// No description provided for @searchPanelHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword...'**
  String get searchPanelHint;

  /// No description provided for @searchPanelByTitle.
  ///
  /// In en, this message translates to:
  /// **'Search titles'**
  String get searchPanelByTitle;

  /// No description provided for @searchPanelByContent.
  ///
  /// In en, this message translates to:
  /// **'Search content'**
  String get searchPanelByContent;

  /// No description provided for @searchPanelResults.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String searchPanelResults(Object count);

  /// No description provided for @searchPanelPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword to search'**
  String get searchPanelPrompt;

  /// No description provided for @searchPanelNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations found'**
  String get searchPanelNoResults;

  /// No description provided for @topicItemNew.
  ///
  /// In en, this message translates to:
  /// **'New topic'**
  String get topicItemNew;

  /// No description provided for @topicItemUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get topicItemUnpin;

  /// No description provided for @topicItemPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get topicItemPin;

  /// No description provided for @topicItemRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get topicItemRename;

  /// No description provided for @topicItemAutoName.
  ///
  /// In en, this message translates to:
  /// **'Auto name'**
  String get topicItemAutoName;

  /// No description provided for @topicItemDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get topicItemDelete;

  /// No description provided for @galleryChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an image source'**
  String get galleryChoiceTitle;

  /// No description provided for @galleryChoiceDevice.
  ///
  /// In en, this message translates to:
  /// **'Device gallery'**
  String get galleryChoiceDevice;

  /// No description provided for @galleryChoiceDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse photos and videos on your device'**
  String get galleryChoiceDeviceDescription;

  /// No description provided for @galleryChoiceApp.
  ///
  /// In en, this message translates to:
  /// **'App gallery'**
  String get galleryChoiceApp;

  /// No description provided for @galleryChoiceAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose from the app gallery'**
  String get galleryChoiceAppDescription;

  /// No description provided for @appMediaUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read file'**
  String get appMediaUnreadable;

  /// No description provided for @appMediaClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear ({count})'**
  String appMediaClearSelection(Object count);

  /// No description provided for @appMediaConfirmSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String appMediaConfirmSelectionCount(Object count);

  /// No description provided for @appMediaConfirmSelection.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get appMediaConfirmSelection;

  /// No description provided for @appMediaEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get appMediaEmptyFolder;

  /// No description provided for @appMediaRoot.
  ///
  /// In en, this message translates to:
  /// **'Go to root folder'**
  String get appMediaRoot;

  /// No description provided for @appMediaParentFolder.
  ///
  /// In en, this message translates to:
  /// **'Back: {name}'**
  String appMediaParentFolder(Object name);

  /// No description provided for @appMediaSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files selected'**
  String appMediaSelectedFiles(Object count);

  /// No description provided for @imagePreviewCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get imagePreviewCrop;

  /// No description provided for @imagePreviewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get imagePreviewEdit;

  /// No description provided for @imagePreviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get imagePreviewLoadFailed;

  /// No description provided for @runningElapsed.
  ///
  /// In en, this message translates to:
  /// **'Running for {elapsed}'**
  String runningElapsed(Object elapsed);

  /// No description provided for @chatAttachmentFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get chatAttachmentFile;

  /// No description provided for @chatAttachmentCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get chatAttachmentCamera;

  /// No description provided for @chatAttachmentDeviceGallery.
  ///
  /// In en, this message translates to:
  /// **'Device gallery'**
  String get chatAttachmentDeviceGallery;

  /// No description provided for @chatAttachmentDeviceFiles.
  ///
  /// In en, this message translates to:
  /// **'Device files'**
  String get chatAttachmentDeviceFiles;

  /// No description provided for @chatAttachmentAppFiles.
  ///
  /// In en, this message translates to:
  /// **'App files'**
  String get chatAttachmentAppFiles;

  /// No description provided for @fileManagerTodayTime.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String fileManagerTodayTime(Object time);

  /// No description provided for @fileManagerYesterdayTime.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String fileManagerYesterdayTime(Object time);

  /// No description provided for @fileManagerDaysAgoTime.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago {time}'**
  String fileManagerDaysAgoTime(Object days, Object time);

  /// No description provided for @markdownGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get markdownGenerating;

  /// No description provided for @htmlPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get htmlPreview;

  /// No description provided for @htmlReturnToCard.
  ///
  /// In en, this message translates to:
  /// **'Return to card'**
  String get htmlReturnToCard;

  /// No description provided for @htmlGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get htmlGenerating;

  /// No description provided for @htmlFullscreen.
  ///
  /// In en, this message translates to:
  /// **'View fullscreen'**
  String get htmlFullscreen;

  /// No description provided for @htmlViewCode.
  ///
  /// In en, this message translates to:
  /// **'View code'**
  String get htmlViewCode;

  /// No description provided for @codeScrollToBottom.
  ///
  /// In en, this message translates to:
  /// **'Scroll to bottom'**
  String get codeScrollToBottom;

  /// No description provided for @codeSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get codeSave;

  /// No description provided for @codeDisableWrap.
  ///
  /// In en, this message translates to:
  /// **'Disable wrapping'**
  String get codeDisableWrap;

  /// No description provided for @codeEnableWrap.
  ///
  /// In en, this message translates to:
  /// **'Wrap lines'**
  String get codeEnableWrap;

  /// No description provided for @codeCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String codeCopyFailed(Object error);

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get codeCopied;

  /// No description provided for @codeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get codeCopy;

  /// No description provided for @codeEmptySave.
  ///
  /// In en, this message translates to:
  /// **'Code is empty and cannot be saved'**
  String get codeEmptySave;

  /// No description provided for @codeSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save code'**
  String get codeSaveTitle;

  /// No description provided for @codeSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String codeSavedTo(Object path);

  /// No description provided for @codeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String codeSaveFailed(Object error);

  /// No description provided for @fileManagerCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fileManagerCopy;

  /// No description provided for @fileManagerMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get fileManagerMove;

  /// No description provided for @fileManagerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get fileManagerRename;

  /// No description provided for @fileManagerExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get fileManagerExport;

  /// No description provided for @fileManagerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get fileManagerDelete;

  /// No description provided for @fileManagerAncestorFolders.
  ///
  /// In en, this message translates to:
  /// **'Ancestor folders'**
  String get fileManagerAncestorFolders;

  /// No description provided for @fileManagerRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get fileManagerRoot;

  /// No description provided for @fileManagerSelectedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String fileManagerSelectedItems(Object count);

  /// No description provided for @fileManagerSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get fileManagerSelectAll;

  /// No description provided for @fileManagerRenameUndo.
  ///
  /// In en, this message translates to:
  /// **'Last batch rename result and undo'**
  String get fileManagerRenameUndo;

  /// No description provided for @fileManagerSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort ({field})'**
  String fileManagerSortBy(Object field);

  /// No description provided for @fileManagerSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Sort by created date'**
  String get fileManagerSortCreated;

  /// No description provided for @fileManagerSortModified.
  ///
  /// In en, this message translates to:
  /// **'Sort by modified date'**
  String get fileManagerSortModified;

  /// No description provided for @fileManagerSortName.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get fileManagerSortName;

  /// No description provided for @fileManagerSortSize.
  ///
  /// In en, this message translates to:
  /// **'Sort by size'**
  String get fileManagerSortSize;

  /// No description provided for @fileManagerListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get fileManagerListView;

  /// No description provided for @fileManagerThumbnailView.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail view'**
  String get fileManagerThumbnailView;

  /// No description provided for @fileManagerCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Create folder'**
  String get fileManagerCreateFolder;

  /// No description provided for @fileManagerRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get fileManagerRefresh;

  /// No description provided for @fileManagerEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get fileManagerEmptyFolder;

  /// No description provided for @fileManagerNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get fileManagerNoFiles;

  /// No description provided for @fileManagerBackRoot.
  ///
  /// In en, this message translates to:
  /// **'Back to root'**
  String get fileManagerBackRoot;

  /// No description provided for @fileManagerBackFolder.
  ///
  /// In en, this message translates to:
  /// **'Back: {name}'**
  String fileManagerBackFolder(Object name);

  /// No description provided for @fileManagerMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Select multiple'**
  String get fileManagerMultiSelect;

  /// No description provided for @fileManagerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fileManagerOpen;

  /// No description provided for @fileManagerPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get fileManagerPreview;

  /// No description provided for @fileManagerFolderAndFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{files} files, {folders} subfolders'**
  String fileManagerFolderAndFilesCount(Object files, Object folders);

  /// No description provided for @fileManagerSubfoldersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subfolders'**
  String fileManagerSubfoldersCount(Object count);

  /// No description provided for @fileManagerFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String fileManagerFilesCount(Object count);

  /// No description provided for @fileManagerEmptyFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get fileManagerEmptyFolderLabel;

  /// No description provided for @fileManagerFileExists.
  ///
  /// In en, this message translates to:
  /// **'File “{name}.{format}” already exists'**
  String fileManagerFileExists(Object format, Object name);

  /// No description provided for @fileManagerRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Rename failed: {error}'**
  String fileManagerRenameFailed(Object error);

  /// No description provided for @fileManagerChooseTargetFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination folder'**
  String get fileManagerChooseTargetFolder;

  /// No description provided for @fileManagerAlreadyAtDestination.
  ///
  /// In en, this message translates to:
  /// **'The file is already at the destination'**
  String get fileManagerAlreadyAtDestination;

  /// No description provided for @fileManagerMoveNameConflict.
  ///
  /// In en, this message translates to:
  /// **'A file with the same name already exists in the destination. Move canceled.'**
  String get fileManagerMoveNameConflict;

  /// No description provided for @fileManagerMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Move failed: {error}'**
  String fileManagerMoveFailed(Object error);

  /// No description provided for @fileManagerChooseCopyDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder to copy to'**
  String get fileManagerChooseCopyDestination;

  /// No description provided for @fileManagerCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String fileManagerCopyFailed(Object error);

  /// No description provided for @fileManagerDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get fileManagerDeleteConfirmTitle;

  /// No description provided for @fileManagerDeleteFileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this file? This action cannot be undone.'**
  String get fileManagerDeleteFileConfirm;

  /// No description provided for @fileManagerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get fileManagerCancel;

  /// No description provided for @fileManagerDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String fileManagerDeleteFailed(Object error);

  /// No description provided for @fileManagerFolderAlreadyThere.
  ///
  /// In en, this message translates to:
  /// **'The folder is already at the destination. Operation canceled.'**
  String get fileManagerFolderAlreadyThere;

  /// No description provided for @fileManagerFolderConflict.
  ///
  /// In en, this message translates to:
  /// **'A folder with the same name exists at the destination, or the destination is inside the selected folder. Operation canceled.'**
  String get fileManagerFolderConflict;

  /// No description provided for @fileManagerBatchDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm bulk deletion'**
  String get fileManagerBatchDeleteTitle;

  /// No description provided for @fileManagerDeleteSelectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the {count} selected items? This action cannot be undone.'**
  String fileManagerDeleteSelectedConfirm(Object count);

  /// No description provided for @fileManagerBatchDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Bulk delete failed: {error}'**
  String fileManagerBatchDeleteFailed(Object error);

  /// No description provided for @fileManagerExportConflict.
  ///
  /// In en, this message translates to:
  /// **'Export paths for the selected files and folders conflict'**
  String get fileManagerExportConflict;

  /// No description provided for @fileManagerSelectedAlreadyThere.
  ///
  /// In en, this message translates to:
  /// **'The selected file is already at the destination. Move canceled.'**
  String get fileManagerSelectedAlreadyThere;

  /// No description provided for @fileManagerBatchMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Bulk move failed: {error}'**
  String fileManagerBatchMoveFailed(Object error);

  /// No description provided for @fileManagerCopyConflict.
  ///
  /// In en, this message translates to:
  /// **'The selection contains files with duplicate names. Copy canceled; copy them one at a time.'**
  String get fileManagerCopyConflict;

  /// No description provided for @fileManagerBatchCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Bulk copy failed: {error}'**
  String fileManagerBatchCopyFailed(Object error);

  /// No description provided for @fileManagerClosedError.
  ///
  /// In en, this message translates to:
  /// **'The file page is closed'**
  String get fileManagerClosedError;

  /// No description provided for @fileManagerBatchRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Bulk rename failed: {error}'**
  String fileManagerBatchRenameFailed(Object error);

  /// No description provided for @fileManagerFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a folder name'**
  String get fileManagerFolderNameHint;

  /// No description provided for @fileManagerCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get fileManagerCreate;

  /// No description provided for @fileManagerFolderExists.
  ///
  /// In en, this message translates to:
  /// **'Folder already exists'**
  String get fileManagerFolderExists;

  /// No description provided for @fileManagerCreateFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create folder: {error}'**
  String fileManagerCreateFolderFailed(Object error);

  /// No description provided for @fileManagerFolderCreated.
  ///
  /// In en, this message translates to:
  /// **'Folder “{name}” created'**
  String fileManagerFolderCreated(Object name);

  /// No description provided for @fileManagerRenameFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get fileManagerRenameFolderTitle;

  /// No description provided for @fileManagerNewNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new name'**
  String get fileManagerNewNameHint;

  /// No description provided for @fileManagerTargetFolderConflict.
  ///
  /// In en, this message translates to:
  /// **'A folder with the same name already exists at the destination. Operation canceled.'**
  String get fileManagerTargetFolderConflict;

  /// No description provided for @fileManagerMoveFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Move folder to…'**
  String get fileManagerMoveFolderTitle;

  /// No description provided for @fileManagerCopyFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy folder to…'**
  String get fileManagerCopyFolderTitle;

  /// No description provided for @fileManagerFolderSelfConflict.
  ///
  /// In en, this message translates to:
  /// **'A folder with the same name exists at the destination, or the destination is the folder itself. Operation canceled.'**
  String get fileManagerFolderSelfConflict;

  /// No description provided for @fileManagerDeleteFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete folder “{name}”? Its {count} files will also be deleted.'**
  String fileManagerDeleteFolderConfirm(Object count, Object name);

  /// No description provided for @fileManagerDeleteEmptyFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete empty folder “{name}”?'**
  String fileManagerDeleteEmptyFolderConfirm(Object name);

  /// No description provided for @fileManagerDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm folder deletion'**
  String get fileManagerDeleteFolderTitle;

  /// No description provided for @fileManagerRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String fileManagerRefreshFailed(Object error);

  /// No description provided for @fileManagerRefreshed.
  ///
  /// In en, this message translates to:
  /// **'File list refreshed'**
  String get fileManagerRefreshed;

  /// No description provided for @fileManagerRenameFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename file'**
  String get fileManagerRenameFileTitle;

  /// No description provided for @fileManagerFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get fileManagerFormat;

  /// No description provided for @fileManagerFolderAtDestination.
  ///
  /// In en, this message translates to:
  /// **'Folder is already at the destination'**
  String get fileManagerFolderAtDestination;

  /// No description provided for @folderPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get folderPickerTitle;

  /// No description provided for @folderPickerExists.
  ///
  /// In en, this message translates to:
  /// **'Folder already exists'**
  String get folderPickerExists;

  /// No description provided for @folderPickerCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create folder: {error}'**
  String folderPickerCreateFailed(Object error);

  /// No description provided for @folderPickerRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh folder list: {error}'**
  String folderPickerRefreshFailed(Object error);

  /// No description provided for @folderPickerInstruction.
  ///
  /// In en, this message translates to:
  /// **'Click to select; double-click to open a folder'**
  String get folderPickerInstruction;

  /// No description provided for @folderPickerFileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get folderPickerFileName;

  /// No description provided for @folderPickerFileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name'**
  String get folderPickerFileNameHint;

  /// No description provided for @folderPickerBack.
  ///
  /// In en, this message translates to:
  /// **'Go up one level'**
  String get folderPickerBack;

  /// No description provided for @folderPickerPath.
  ///
  /// In en, this message translates to:
  /// **'Root > {path}'**
  String folderPickerPath(Object path);

  /// No description provided for @folderPickerRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get folderPickerRoot;

  /// No description provided for @folderPickerCurrentFolder.
  ///
  /// In en, this message translates to:
  /// **'Current folder'**
  String get folderPickerCurrentFolder;

  /// No description provided for @folderPickerSubfolders.
  ///
  /// In en, this message translates to:
  /// **'Subfolders'**
  String get folderPickerSubfolders;

  /// No description provided for @folderPickerExistingFolders.
  ///
  /// In en, this message translates to:
  /// **'Existing folders'**
  String get folderPickerExistingFolders;

  /// No description provided for @folderPickerCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new folder'**
  String get folderPickerCreateNew;

  /// No description provided for @folderPickerFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a folder name'**
  String get folderPickerFolderNameHint;

  /// No description provided for @folderPickerCancelCreate.
  ///
  /// In en, this message translates to:
  /// **'Cancel creation'**
  String get folderPickerCancelCreate;

  /// No description provided for @folderPickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get folderPickerCancel;

  /// No description provided for @folderPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get folderPickerConfirm;

  /// No description provided for @batchRunReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read file list: {error}'**
  String batchRunReadFailed(Object error);

  /// No description provided for @batchRunPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get batchRunPreparing;

  /// No description provided for @batchRunUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get batchRunUndo;

  /// No description provided for @batchRunRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get batchRunRename;

  /// No description provided for @batchRunFailedAction.
  ///
  /// In en, this message translates to:
  /// **'Could not {label}'**
  String batchRunFailedAction(Object label);

  /// No description provided for @batchRunCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{label} {count} items'**
  String batchRunCompletedCount(Object count, Object label);

  /// No description provided for @batchRunSummary.
  ///
  /// In en, this message translates to:
  /// **'{label}: {completed} succeeded, {failed} failed, {remaining} remaining'**
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  );

  /// No description provided for @batchRunFailedItem.
  ///
  /// In en, this message translates to:
  /// **'Failed: {id} → {name}'**
  String batchRunFailedItem(Object id, Object name);

  /// No description provided for @batchRunReportCopied.
  ///
  /// In en, this message translates to:
  /// **'Execution report copied'**
  String get batchRunReportCopied;

  /// No description provided for @batchRunCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed. Try again.'**
  String get batchRunCopyFailed;

  /// No description provided for @batchRunWorking.
  ///
  /// In en, this message translates to:
  /// **'{label}…'**
  String batchRunWorking(Object label);

  /// No description provided for @batchRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch rename results'**
  String get batchRunTitle;

  /// No description provided for @batchRunStoppedRetain.
  ///
  /// In en, this message translates to:
  /// **'Stopping keeps completed items. You can undo them on the results page.'**
  String get batchRunStoppedRetain;

  /// No description provided for @batchRunFailedRemaining.
  ///
  /// In en, this message translates to:
  /// **'Failed; remaining items were not processed'**
  String get batchRunFailedRemaining;

  /// No description provided for @batchRunUndoInfo.
  ///
  /// In en, this message translates to:
  /// **'Undo restores the original names for items completed in this run. Undo is refused if the file list has changed since.'**
  String get batchRunUndoInfo;

  /// No description provided for @batchRunUncertain.
  ///
  /// In en, this message translates to:
  /// **'Some item states could not be confirmed. Check the file list; automatic undo is unavailable to avoid overwriting files.'**
  String get batchRunUncertain;

  /// No description provided for @batchRunUndoing.
  ///
  /// In en, this message translates to:
  /// **'Restoring original names…'**
  String get batchRunUndoing;

  /// No description provided for @batchRunStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get batchRunStopping;

  /// No description provided for @batchRunStopRemaining.
  ///
  /// In en, this message translates to:
  /// **'Stop remaining items'**
  String get batchRunStopRemaining;

  /// No description provided for @batchRunCopyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get batchRunCopyReport;

  /// No description provided for @batchRunUndoRemaining.
  ///
  /// In en, this message translates to:
  /// **'Continue undoing the remaining {count}'**
  String batchRunUndoRemaining(Object count);

  /// No description provided for @batchRunUndoCompleted.
  ///
  /// In en, this message translates to:
  /// **'Undo completed renames'**
  String get batchRunUndoCompleted;

  /// No description provided for @batchRunDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get batchRunDone;

  /// No description provided for @codeEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit parameter value'**
  String get codeEditorTitle;

  /// No description provided for @codeEditorFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get codeEditorFormat;

  /// No description provided for @codeEditorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get codeEditorCancel;

  /// No description provided for @codeEditorConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get codeEditorConfirm;

  /// No description provided for @codeEditorInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON. Fix it before saving.'**
  String get codeEditorInvalidJson;

  /// No description provided for @codeEditorParamPath.
  ///
  /// In en, this message translates to:
  /// **'Parameter name path (expanded into nested JSON when sent)'**
  String get codeEditorParamPath;

  /// No description provided for @codeEditorErrorPosition.
  ///
  /// In en, this message translates to:
  /// **'Line {line}, column {column}: {message}'**
  String codeEditorErrorPosition(String line, String column, String message);

  /// No description provided for @codeEditorJsonError.
  ///
  /// In en, this message translates to:
  /// **'JSON format error: {message}'**
  String codeEditorJsonError(String message);

  /// No description provided for @codeEditorInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON format'**
  String get codeEditorInvalidFormat;

  /// No description provided for @toolCallCompacted.
  ///
  /// In en, this message translates to:
  /// **'Compacted'**
  String get toolCallCompacted;

  /// No description provided for @mermaidSaveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Mermaid code is empty. Nothing to save.'**
  String get mermaidSaveEmpty;

  /// No description provided for @mermaidFolderLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load folders: {error}'**
  String mermaidFolderLoadFailed(String error);

  /// No description provided for @mermaidSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Mermaid diagram'**
  String get mermaidSaveTitle;

  /// No description provided for @mermaidSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a folder for the .mmd file'**
  String get mermaidSaveHint;

  /// No description provided for @mermaidSaveFilenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name (.mmd is added automatically)'**
  String get mermaidSaveFilenameHint;

  /// No description provided for @mermaidFilenameEmpty.
  ///
  /// In en, this message translates to:
  /// **'File name cannot be empty'**
  String get mermaidFilenameEmpty;

  /// No description provided for @mermaidSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to text storage: {folder}/{name}.mmd'**
  String mermaidSaveSuccess(String folder, String name);

  /// No description provided for @mermaidSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String mermaidSaveFailed(String error);

  /// No description provided for @mermaidPrepareEngine.
  ///
  /// In en, this message translates to:
  /// **'Preparing rendering engine...'**
  String get mermaidPrepareEngine;

  /// No description provided for @mermaidRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mermaidRetry;

  /// No description provided for @batchRuleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cannot be empty'**
  String get batchRuleEmpty;

  /// No description provided for @batchRuleNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get batchRuleNumber;

  /// No description provided for @batchRulePositive.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than 0'**
  String get batchRulePositive;

  /// No description provided for @batchRuleMin.
  ///
  /// In en, this message translates to:
  /// **'Must be at least {min}'**
  String batchRuleMin(String min);

  /// No description provided for @batchRuleMax.
  ///
  /// In en, this message translates to:
  /// **'Must be no greater than {max}'**
  String batchRuleMax(String max);

  /// No description provided for @batchRulePrefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get batchRulePrefix;

  /// No description provided for @batchRuleSuffix.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get batchRuleSuffix;

  /// No description provided for @batchRuleStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get batchRuleStart;

  /// No description provided for @batchRuleStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get batchRuleStep;

  /// No description provided for @batchRuleDigits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get batchRuleDigits;

  /// No description provided for @batchRuleSeparator.
  ///
  /// In en, this message translates to:
  /// **'Separator'**
  String get batchRuleSeparator;

  /// No description provided for @batchRuleRestartFolder.
  ///
  /// In en, this message translates to:
  /// **'Restart numbering in each folder'**
  String get batchRuleRestartFolder;

  /// No description provided for @batchRuleNumberHelp.
  ///
  /// In en, this message translates to:
  /// **'Numbers follow preview order; excluded items do not use a number. Step can be negative or 0.'**
  String get batchRuleNumberHelp;

  /// No description provided for @batchRuleFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get batchRuleFind;

  /// No description provided for @batchRuleReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace with (leave empty to delete)'**
  String get batchRuleReplace;

  /// No description provided for @batchRuleCaseSensitive.
  ///
  /// In en, this message translates to:
  /// **'Case sensitive'**
  String get batchRuleCaseSensitive;

  /// No description provided for @batchRuleRegex.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get batchRuleRegex;

  /// No description provided for @batchRuleFirstOnly.
  ///
  /// In en, this message translates to:
  /// **'Replace first match only'**
  String get batchRuleFirstOnly;

  /// No description provided for @batchRuleRegexHelp.
  ///
  /// In en, this message translates to:
  /// **'Capture groups: \$1, \$2; full match: \$0; literal \$: \$\$. Example: ^IMG_(\\d+)\$ → Photo_\$1'**
  String get batchRuleRegexHelp;

  /// No description provided for @batchRuleFindRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter text to find to enable this rule.'**
  String get batchRuleFindRequired;

  /// No description provided for @batchRuleBeginning.
  ///
  /// In en, this message translates to:
  /// **'Beginning'**
  String get batchRuleBeginning;

  /// No description provided for @batchRuleEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get batchRuleEnd;

  /// No description provided for @batchRulePosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get batchRulePosition;

  /// No description provided for @batchRuleInsertText.
  ///
  /// In en, this message translates to:
  /// **'Text to insert'**
  String get batchRuleInsertText;

  /// No description provided for @batchRuleBeforeChar.
  ///
  /// In en, this message translates to:
  /// **'Before character N'**
  String get batchRuleBeforeChar;

  /// No description provided for @batchRulePositionHelp.
  ///
  /// In en, this message translates to:
  /// **'Positions start at 1; values beyond the end are appended. Combined emoji count as one character.'**
  String get batchRulePositionHelp;

  /// No description provided for @batchRuleFromBeginning.
  ///
  /// In en, this message translates to:
  /// **'From beginning'**
  String get batchRuleFromBeginning;

  /// No description provided for @batchRuleFromEnd.
  ///
  /// In en, this message translates to:
  /// **'From end'**
  String get batchRuleFromEnd;

  /// No description provided for @batchRuleFromChar.
  ///
  /// In en, this message translates to:
  /// **'Starting at character N'**
  String get batchRuleFromChar;

  /// No description provided for @batchRuleCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get batchRuleCount;

  /// No description provided for @batchRuleDeleteHelp.
  ///
  /// In en, this message translates to:
  /// **'If deletion empties the name, a later insert rule must add text before execution.'**
  String get batchRuleDeleteHelp;

  /// No description provided for @batchRuleUpper.
  ///
  /// In en, this message translates to:
  /// **'UPPERCASE'**
  String get batchRuleUpper;

  /// No description provided for @batchRuleLower.
  ///
  /// In en, this message translates to:
  /// **'lowercase'**
  String get batchRuleLower;

  /// No description provided for @batchRuleFirstUpper.
  ///
  /// In en, this message translates to:
  /// **'Capitalize first letter'**
  String get batchRuleFirstUpper;

  /// No description provided for @batchRuleTitleCase.
  ///
  /// In en, this message translates to:
  /// **'Capitalize Each Word'**
  String get batchRuleTitleCase;

  /// No description provided for @batchRuleTemplate.
  ///
  /// In en, this message translates to:
  /// **'New name template'**
  String get batchRuleTemplate;

  /// No description provided for @batchRuleTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'Course_{n}_{name}'**
  String batchRuleTemplateHint(String n, String name);

  /// No description provided for @batchRuleTemplateHelp.
  ///
  /// In en, this message translates to:
  /// **'{name} original name · {n} sequence · {folder} folder name\n{created} creation date · {modified} modified date · {ext} original extension\nDate format YYYY-MM-DD; missing dates are reported. The template replaces the whole base name; the extension is kept automatically.'**
  String batchRuleTemplateHelp(
    String name,
    String n,
    String folder,
    String created,
    String modified,
    String ext,
  );

  /// No description provided for @batchRuleTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim leading and trailing spaces'**
  String get batchRuleTrim;

  /// No description provided for @batchRuleCollapseSpaces.
  ///
  /// In en, this message translates to:
  /// **'Replace consecutive spaces with one space'**
  String get batchRuleCollapseSpaces;

  /// No description provided for @batchRuleActions.
  ///
  /// In en, this message translates to:
  /// **'Rule actions'**
  String get batchRuleActions;

  /// No description provided for @batchRuleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate rule'**
  String get batchRuleDuplicate;

  /// No description provided for @batchRuleRemove.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get batchRuleRemove;

  /// No description provided for @batchRuleMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move rule up'**
  String get batchRuleMoveUp;

  /// No description provided for @batchRuleMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move rule down'**
  String get batchRuleMoveDown;

  /// No description provided for @batchDlgSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get batchDlgSavePreset;

  /// No description provided for @batchDlgPresetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get batchDlgPresetName;

  /// No description provided for @batchDlgPresetHint.
  ///
  /// In en, this message translates to:
  /// **'Saves rules and order, but not exclusions or manual names'**
  String get batchDlgPresetHint;

  /// No description provided for @batchDlgCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get batchDlgCancel;

  /// No description provided for @batchDlgSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get batchDlgSave;

  /// No description provided for @batchDlgOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing preset?'**
  String get batchDlgOverwriteTitle;

  /// No description provided for @batchDlgOverwriteBody.
  ///
  /// In en, this message translates to:
  /// **'Update the rules in “{name}”.'**
  String batchDlgOverwriteBody(String name);

  /// No description provided for @batchDlgOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get batchDlgOverwrite;

  /// No description provided for @batchDlgManagePresets.
  ///
  /// In en, this message translates to:
  /// **'Manage presets'**
  String get batchDlgManagePresets;

  /// No description provided for @batchDlgNoPresets.
  ///
  /// In en, this message translates to:
  /// **'No saved presets'**
  String get batchDlgNoPresets;

  /// No description provided for @batchDlgDeletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get batchDlgDeletePreset;

  /// No description provided for @batchDlgDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get batchDlgDone;

  /// No description provided for @batchDlgEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name individually'**
  String get batchDlgEditName;

  /// No description provided for @batchDlgBaseName.
  ///
  /// In en, this message translates to:
  /// **'Base name'**
  String get batchDlgBaseName;

  /// No description provided for @batchDlgOverrideHelp.
  ///
  /// In en, this message translates to:
  /// **'This name overrides the rule result'**
  String get batchDlgOverrideHelp;

  /// No description provided for @batchDlgExtensionRetained.
  ///
  /// In en, this message translates to:
  /// **'Extension .{extension} is kept automatically'**
  String batchDlgExtensionRetained(String extension);

  /// No description provided for @batchDlgConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get batchDlgConfirm;

  /// No description provided for @batchDlgHelp.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get batchDlgHelp;

  /// No description provided for @batchDlgClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get batchDlgClose;

  /// No description provided for @batchDlgLoadPreset.
  ///
  /// In en, this message translates to:
  /// **'Load preset (replaces rules and clears manual names)'**
  String get batchDlgLoadPreset;

  /// No description provided for @batchDlgLoad.
  ///
  /// In en, this message translates to:
  /// **'Load preset'**
  String get batchDlgLoad;

  /// No description provided for @batchDlgSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get batchDlgSaving;

  /// No description provided for @batchDlgReset.
  ///
  /// In en, this message translates to:
  /// **'Reset all rules and included items'**
  String get batchDlgReset;

  /// No description provided for @batchDlgRuleInstructions.
  ///
  /// In en, this message translates to:
  /// **'Rules run from top to bottom. Copy, move, or disable them. File extensions stay unchanged.'**
  String get batchDlgRuleInstructions;

  /// No description provided for @batchDlgSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get batchDlgSortName;

  /// No description provided for @batchDlgSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get batchDlgSortCreated;

  /// No description provided for @batchDlgSortModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get batchDlgSortModified;

  /// No description provided for @batchDlgSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get batchDlgSortSize;

  /// No description provided for @batchDlgAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get batchDlgAscending;

  /// No description provided for @batchDlgDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get batchDlgDescending;

  /// No description provided for @batchDlgFolderSort.
  ///
  /// In en, this message translates to:
  /// **'Folders come first; same names are sorted by folder.'**
  String get batchDlgFolderSort;

  /// No description provided for @batchDlgAddRule.
  ///
  /// In en, this message translates to:
  /// **'＋ Add rule'**
  String get batchDlgAddRule;

  /// No description provided for @batchDlgMaxRules.
  ///
  /// In en, this message translates to:
  /// **'Maximum 50 rules'**
  String get batchDlgMaxRules;

  /// No description provided for @batchDlgPreviewWorking.
  ///
  /// In en, this message translates to:
  /// **'Calculating preview… You can keep editing rules or cancel.'**
  String get batchDlgPreviewWorking;

  /// No description provided for @batchDlgSearch.
  ///
  /// In en, this message translates to:
  /// **'Search original name, new name, or folder'**
  String get batchDlgSearch;

  /// No description provided for @batchDlgFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get batchDlgFilterAll;

  /// No description provided for @batchDlgFilterChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get batchDlgFilterChanged;

  /// No description provided for @batchDlgFilterErrors.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get batchDlgFilterErrors;

  /// No description provided for @batchDlgFilterUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get batchDlgFilterUnchanged;

  /// No description provided for @batchDlgFilterExcluded.
  ///
  /// In en, this message translates to:
  /// **'Excluded'**
  String get batchDlgFilterExcluded;

  /// No description provided for @batchDlgParticipants.
  ///
  /// In en, this message translates to:
  /// **'Choose included items'**
  String get batchDlgParticipants;

  /// No description provided for @batchDlgIncludeAll.
  ///
  /// In en, this message translates to:
  /// **'Include all'**
  String get batchDlgIncludeAll;

  /// No description provided for @batchDlgOnlyFiles.
  ///
  /// In en, this message translates to:
  /// **'Files only'**
  String get batchDlgOnlyFiles;

  /// No description provided for @batchDlgOnlyFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders only'**
  String get batchDlgOnlyFolders;

  /// No description provided for @batchDlgExcludeAll.
  ///
  /// In en, this message translates to:
  /// **'Exclude all'**
  String get batchDlgExcludeAll;

  /// No description provided for @batchDlgScope.
  ///
  /// In en, this message translates to:
  /// **'Included items'**
  String get batchDlgScope;

  /// No description provided for @batchDlgCopyList.
  ///
  /// In en, this message translates to:
  /// **'Copy list'**
  String get batchDlgCopyList;

  /// No description provided for @batchDlgConflictBlock.
  ///
  /// In en, this message translates to:
  /// **'Name conflict: block execution'**
  String get batchDlgConflictBlock;

  /// No description provided for @batchDlgConflictSuffix.
  ///
  /// In en, this message translates to:
  /// **'Name conflict: append (2), (3)…'**
  String get batchDlgConflictSuffix;

  /// No description provided for @batchDlgNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No items match the filter'**
  String get batchDlgNoMatches;

  /// No description provided for @batchDlgRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get batchDlgRoot;

  /// No description provided for @batchDlgFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get batchDlgFile;

  /// No description provided for @batchDlgFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get batchDlgFolder;

  /// No description provided for @batchDlgTargetFolder.
  ///
  /// In en, this message translates to:
  /// **'Target folder: {folder}'**
  String batchDlgTargetFolder(String folder);

  /// No description provided for @batchDlgEditNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit name individually'**
  String get batchDlgEditNameTooltip;

  /// No description provided for @batchDlgRestoreNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore rule-generated name'**
  String get batchDlgRestoreNameTooltip;

  /// No description provided for @batchDlgCopied.
  ///
  /// In en, this message translates to:
  /// **'Full preview list copied (CSV)'**
  String get batchDlgCopied;

  /// No description provided for @batchDlgCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed. Try again.'**
  String get batchDlgCopyFailed;

  /// No description provided for @batchDlgHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch rename instructions'**
  String get batchDlgHelpTitle;

  /// No description provided for @batchDlgHelpDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get batchDlgHelpDismiss;

  /// No description provided for @batchDlgRulesTab.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get batchDlgRulesTab;

  /// No description provided for @batchDlgPreviewTab.
  ///
  /// In en, this message translates to:
  /// **'Preview ({count})'**
  String batchDlgPreviewTab(String count);

  /// No description provided for @batchDlgRenameCount.
  ///
  /// In en, this message translates to:
  /// **'Rename {count} items'**
  String batchDlgRenameCount(String count);

  /// No description provided for @batchDlgPresetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load presets. You can still edit and run rules.'**
  String get batchDlgPresetLoadFailed;

  /// No description provided for @batchDlgPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate preview. Adjust the rules and try again.'**
  String get batchDlgPreviewFailed;

  /// No description provided for @batchDlgSavedName.
  ///
  /// In en, this message translates to:
  /// **'Preset saved: {name}'**
  String batchDlgSavedName(String name);

  /// No description provided for @batchDlgSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String batchDlgSaveFailed(String error);

  /// No description provided for @batchDlgDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String batchDlgDeleteFailed(String error);

  /// No description provided for @batchDlgSavePresetFallback.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get batchDlgSavePresetFallback;

  /// No description provided for @batchDlgPreviewSummary.
  ///
  /// In en, this message translates to:
  /// **'Preview · {changes} changes · {conflicts} issues · {excluded} excluded'**
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  );

  /// No description provided for @batchDlgInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Fix invalid rule inputs. The preview does not include them yet.'**
  String get batchDlgInvalidInput;

  /// No description provided for @batchDlgConflictError.
  ///
  /// In en, this message translates to:
  /// **'Conflicts or invalid names prevent applying. Adjust the rules.'**
  String get batchDlgConflictError;

  /// No description provided for @batchDlgManualNameStatus.
  ///
  /// In en, this message translates to:
  /// **'Manual name'**
  String get batchDlgManualNameStatus;

  /// No description provided for @batchDlgPendingRename.
  ///
  /// In en, this message translates to:
  /// **'Ready to rename'**
  String get batchDlgPendingRename;

  /// No description provided for @batchDlgCsvHeader.
  ///
  /// In en, this message translates to:
  /// **'Original path,Original name,Target path,Status'**
  String get batchDlgCsvHeader;

  /// No description provided for @batchDlgHelpBody.
  ///
  /// In en, this message translates to:
  /// **'1. Choose a preset or enable rules, then copy rules and adjust their order as needed.\n\n2. The preview shows the names that will be used. Search and filters affect display only. Unchecking an item excludes it and recalculates numbering. Edit a name individually or restore the rule result.\n\n3. Resolve all issues before running. Automatic suffixes handle duplicate names without overwriting files. Rename folders that exchange names in separate batches.\n\n4. You can stop later items during execution; the current item finishes first. The results page shows completed changes and lets you undo them. Undo is blocked if the list has changed since execution.\n\nThis changes names and folder paths only; file contents and extensions stay unchanged. Renaming a parent folder does not prevent checked children from being renamed, and renaming a parent moves its children with it.'**
  String get batchDlgHelpBody;

  /// No description provided for @batchDlgPreviewCount.
  ///
  /// In en, this message translates to:
  /// **'Preview ({count})'**
  String batchDlgPreviewCount(String count);

  /// No description provided for @batchBuiltinPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photos: date and number'**
  String get batchBuiltinPhoto;

  /// No description provided for @batchBuiltinCourse.
  ///
  /// In en, this message translates to:
  /// **'Courses: consistent name and number'**
  String get batchBuiltinCourse;

  /// No description provided for @batchBuiltinDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads: clean whitespace'**
  String get batchBuiltinDownloads;

  /// No description provided for @taskListDetail.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get taskListDetail;

  /// No description provided for @taskListOwnershipChecking.
  ///
  /// In en, this message translates to:
  /// **'Confirming task ownership'**
  String get taskListOwnershipChecking;

  /// No description provided for @taskListOwnershipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read task flow record; actions are unavailable'**
  String get taskListOwnershipFailed;

  /// No description provided for @taskListViewFlow.
  ///
  /// In en, this message translates to:
  /// **'View task flow'**
  String get taskListViewFlow;

  /// No description provided for @taskListPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get taskListPause;

  /// No description provided for @taskListClear.
  ///
  /// In en, this message translates to:
  /// **'Clear task'**
  String get taskListClear;

  /// No description provided for @taskListResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get taskListResume;

  /// No description provided for @taskListRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get taskListRetry;

  /// No description provided for @taskListDismissError.
  ///
  /// In en, this message translates to:
  /// **'Dismiss error'**
  String get taskListDismissError;

  /// No description provided for @taskListRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get taskListRemove;

  /// No description provided for @taskListSynthesisErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Synthesis error details'**
  String get taskListSynthesisErrorTitle;

  /// No description provided for @taskListClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get taskListClose;

  /// No description provided for @taskListOriginalExchange.
  ///
  /// In en, this message translates to:
  /// **'Original request and response'**
  String get taskListOriginalExchange;

  /// No description provided for @taskListOriginalRequest.
  ///
  /// In en, this message translates to:
  /// **'Original request body:'**
  String get taskListOriginalRequest;

  /// No description provided for @taskListOriginalResponse.
  ///
  /// In en, this message translates to:
  /// **'Original response body:'**
  String get taskListOriginalResponse;

  /// No description provided for @taskFlowIoTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get taskFlowIoTypeText;

  /// No description provided for @taskFlowIoTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get taskFlowIoTypeAudio;

  /// No description provided for @taskFlowIoTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get taskFlowIoTypeVideo;

  /// No description provided for @taskFlowIoTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get taskFlowIoTypeImage;

  /// No description provided for @taskFlowIoTypeLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get taskFlowIoTypeLink;

  /// No description provided for @taskFlowIoTypeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get taskFlowIoTypeFile;

  /// No description provided for @taskFlowIoTypeAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get taskFlowIoTypeAny;

  /// No description provided for @mermaidZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mermaidZoomOut;

  /// No description provided for @mermaidZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get mermaidZoomIn;

  /// No description provided for @mermaidFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get mermaidFullscreen;

  /// No description provided for @mermaidSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mermaidSaveButton;

  /// No description provided for @mermaidSourceButton.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get mermaidSourceButton;

  /// No description provided for @mermaidDiagramSemantic.
  ///
  /// In en, this message translates to:
  /// **'View diagram'**
  String get mermaidDiagramSemantic;

  /// No description provided for @taskFlowCardCatCatchDeletePersistError.
  ///
  /// In en, this message translates to:
  /// **'Could not save CatCatch child task deletion state. Try again.'**
  String get taskFlowCardCatCatchDeletePersistError;

  /// No description provided for @taskFlowCardSynthesisDeletePersistError.
  ///
  /// In en, this message translates to:
  /// **'Could not save synthesis child task deletion state. Try again.'**
  String get taskFlowCardSynthesisDeletePersistError;

  /// No description provided for @taskFlowCardBackgroundDeletePersistError.
  ///
  /// In en, this message translates to:
  /// **'Could not save background child task deletion state. Try again.'**
  String get taskFlowCardBackgroundDeletePersistError;

  /// No description provided for @mathParseError.
  ///
  /// In en, this message translates to:
  /// **'Math parse error'**
  String get mathParseError;

  /// No description provided for @mermaidEmptyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No Mermaid code to render'**
  String get mermaidEmptyPlaceholder;

  /// No description provided for @mathClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get mathClose;

  /// No description provided for @mermaidLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Mermaid loading timed out. Check your network and try again.'**
  String get mermaidLoadTimeout;

  /// No description provided for @mermaidCdnLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach cdn.jsdelivr.net to load Mermaid.'**
  String get mermaidCdnLoadFailed;

  /// No description provided for @mermaidLoadingDiagram.
  ///
  /// In en, this message translates to:
  /// **'Loading diagram…'**
  String get mermaidLoadingDiagram;

  /// No description provided for @mermaidEngineInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize the diagram renderer. Try again.'**
  String get mermaidEngineInitFailed;

  /// No description provided for @mermaidPageTimeout.
  ///
  /// In en, this message translates to:
  /// **'Page load timed out. Try again.'**
  String get mermaidPageTimeout;

  /// No description provided for @mermaidCodeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load diagram code. Try again.'**
  String get mermaidCodeLoadFailed;

  /// No description provided for @mermaidPageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Page load failed: {description}'**
  String mermaidPageLoadFailed(String description);

  /// No description provided for @mermaidLoadingEngine.
  ///
  /// In en, this message translates to:
  /// **'Loading rendering engine…'**
  String get mermaidLoadingEngine;

  /// No description provided for @mermaidRenderErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagram rendering error'**
  String get mermaidRenderErrorTitle;

  /// No description provided for @taskFlowOutputVideoAudioDownstream.
  ///
  /// In en, this message translates to:
  /// **'Video or audio (filtered by downstream)'**
  String get taskFlowOutputVideoAudioDownstream;

  /// No description provided for @taskFlowOutputUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get taskFlowOutputUnknown;

  /// No description provided for @batchRunCancelledSummary.
  ///
  /// In en, this message translates to:
  /// **'{label} stopped: {completed} succeeded, {failed} failed, {remaining} remaining'**
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  );

  /// No description provided for @mermaidRenderErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Mermaid render error: {message}'**
  String mermaidRenderErrorPrefix(String message);

  /// No description provided for @mermaidInitializeErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Mermaid initialization error: {message}'**
  String mermaidInitializeErrorPrefix(String message);

  /// No description provided for @mermaidResourceError.
  ///
  /// In en, this message translates to:
  /// **'A resource in the Mermaid diagram failed to load.'**
  String get mermaidResourceError;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Recognition model'**
  String get taskFlowParamRecognitionModel;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Synthesis model'**
  String get taskFlowParamSynthesisModel;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Save folder'**
  String get taskFlowParamSaveFolder;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Resource selection'**
  String get taskFlowParamResourceSelection;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Output type'**
  String get taskFlowParamOutputType;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Video save folder'**
  String get taskFlowParamVideoFolder;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Audio save folder'**
  String get taskFlowParamAudioFolder;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Expected duration'**
  String get taskFlowParamExpectedDuration;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get taskFlowParamVoice;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get taskFlowParamSpeechRate;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get taskFlowParamAssistant;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Manual mode lets you choose. Automatic mode follows the existing rules. Ask when ambiguous selects automatically only when there is one safe choice; otherwise it opens the resource list for confirmation.'**
  String get taskFlowHintResourceSelection;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Choose video or audio explicitly. Follow downstream filters resources by the next block’s input type. If the next block accepts both types or there is no next block, both types are kept.'**
  String get taskFlowHintOutputType;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Filter resources by video duration. Leave blank to skip filtering.'**
  String get taskFlowHintExpectedDuration;

  /// Localized label or help text for the built-in TaskFlow block parameter.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice. The matching synthesis model is selected automatically.'**
  String get taskFlowHintVoice;

  /// TaskFlow block connection validation message.
  ///
  /// In en, this message translates to:
  /// **'This block type is no longer supported. Replace it or remove this step.'**
  String get taskFlowUiUnsupportedBlockStep;

  /// TaskFlow block connection validation message.
  ///
  /// In en, this message translates to:
  /// **'The next block requires {requiredType}. The downloader can output video or audio. Change the next step or output policy.'**
  String taskFlowUiDownstreamTypeMismatch(String requiredType);

  /// TaskFlow block connection validation message.
  ///
  /// In en, this message translates to:
  /// **'{source} has any type, but “{block}” needs an explicit text, link, image, audio, video, or file type. Change the input type, move or replace the block, or undo the change.'**
  String taskFlowUiAnyTypeMismatch(String source, String block);

  /// TaskFlow block connection validation message.
  ///
  /// In en, this message translates to:
  /// **'{source} has {actualType}, but “{block}” requires {requiredType}. Change the input type, move or replace the block, or undo the change.'**
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  );

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Created date'**
  String get fileManagerSortFieldCreated;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Modified date'**
  String get fileManagerSortFieldModified;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fileManagerSortFieldName;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileManagerSortFieldSize;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'newest first'**
  String get fileManagerSortDateNewest;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'oldest first'**
  String get fileManagerSortDateOldest;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'largest first'**
  String get fileManagerSortSizeLargest;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'smallest first'**
  String get fileManagerSortSizeSmallest;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get catcatchStatusRunning;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get catcatchStatusCompleted;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get catcatchStatusFailed;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get catcatchStatusPaused;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get catcatchStatusWaiting;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Fetching webpage'**
  String get catcatchStepFetching;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Analyzing media'**
  String get catcatchStepAnalyzing;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Parsing playlist'**
  String get catcatchStepParsingPlaylist;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Filtering by duration'**
  String get catcatchStepFiltering;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for selection'**
  String get catcatchStepUserSelecting;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get catcatchStepDownloading;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Converting/merging'**
  String get catcatchStepConverting;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Saving locally'**
  String get catcatchStepSaving;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Connecting to server'**
  String get bgStepConnectServer;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Uploading images'**
  String get bgStepUploadImage;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for recognition'**
  String get bgStepWaitRecognition;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Parsing result'**
  String get bgStepParseResult;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Saving file'**
  String get bgStepSaveFile;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Uploading audio'**
  String get bgStepUploadAudio;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get bgStepTranscribing;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Receiving result'**
  String get bgStepReceiveResult;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Separating audio'**
  String get bgStepSeparateAudio;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Saving to file'**
  String get bgStepSaveToFile;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Sending request'**
  String get bgStepSendRequest;

  /// Localized app-owned task state, step, or sort presentation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for reply'**
  String get bgStepWaitReply;

  /// Alphabetical file sort direction.
  ///
  /// In en, this message translates to:
  /// **'A to Z'**
  String get fileManagerSortNameAscending;

  /// Alphabetical file sort direction.
  ///
  /// In en, this message translates to:
  /// **'Z to A'**
  String get fileManagerSortNameDescending;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'This task flow has no steps. Add a block first.'**
  String get taskFlowValidationNoSteps;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'Add at least one input to run this task flow.'**
  String get taskFlowValidationInputRequired;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'This task flow was deleted. Select it again.'**
  String get taskFlowValidationFlowRemoved;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The initial input type changed. Choose the run input again.'**
  String get taskFlowValidationInputTypeChanged;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'This older record has no run snapshot. Retry using the latest configuration.'**
  String get taskFlowValidationSnapshotMissing;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The assistant model is missing or unavailable. Select a model on the chat page or set a default model for the assistant.'**
  String get taskFlowValidationAssistantModelMissing;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'A saved step file is missing, empty, or unreadable. Run the task flow again.'**
  String get taskFlowValidationSavedFileUnavailable;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'This block type is no longer supported. Replace or remove this step.'**
  String get taskFlowValidationUnsupportedBlock;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The next block requires {requiredType}. The downloader can output audio or video. Change the next step or output policy.'**
  String taskFlowValidationDownstreamMismatch(String requiredType);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'“{parameter}” is required for “{block}”. Configure it in the block settings.'**
  String taskFlowValidationRequiredParameter(String parameter, String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The legacy model selection needs confirmation. Choose the model again in “{block}” settings.'**
  String taskFlowValidationLegacyModel(String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The model is missing or unavailable from its provider. Choose it again in “{block}” settings and check the provider URL and key.'**
  String taskFlowValidationModelUnavailable(String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The assistant is missing or was deleted. Choose it again in “{block}” settings.'**
  String taskFlowValidationAssistantUnavailable(String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The assistant model was deleted or its provider configuration is unavailable. Choose a model again in assistant settings.'**
  String get taskFlowValidationAssistantModelUnavailable;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The resource selection policy or output type is invalid. Choose it again in “{block}” settings.'**
  String taskFlowValidationPolicyInvalid(String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The output type is invalid. Choose it again in “{block}” settings.'**
  String taskFlowValidationOutputInvalid(String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The resource selection policy is invalid. Choose it again in “{block}” settings.'**
  String taskFlowValidationResourcePolicyInvalid(String block);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: The file is missing, empty, or unreadable. Choose it again.'**
  String taskFlowValidationInputFileUnavailable(String index);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: Enter a valid HTTP or HTTPS link.'**
  String taskFlowValidationInputUrlInvalid(String index);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: {error}'**
  String taskFlowValidationInputError(String index, String error);

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'At most 50 rules are allowed.'**
  String get batchRuleValidationMaxRules;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The number of digits must be from 1 to 12.'**
  String get batchRuleValidationDigits;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The starting number and step must be within ±999,999,999.'**
  String get batchRuleValidationNumberRange;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The replacement rule is too long.'**
  String get batchRuleValidationReplacementLength;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The regular expression is invalid.'**
  String get batchRuleValidationRegex;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The deletion position must start at 1.'**
  String get batchRuleValidationDeleteIndex;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The inserted text is too long.'**
  String get batchRuleValidationInsertLength;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'Invalid template number settings: digits must be 1 to 12 and start/step within ±999,999,999.'**
  String get batchRuleValidationTemplateNumber;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'The template is too long.'**
  String get batchRuleValidationTemplateLength;

  /// Localized user-facing TaskFlow or batch rule validation message.
  ///
  /// In en, this message translates to:
  /// **'Unknown template variable or an unclosed brace.'**
  String get batchRuleValidationTemplateVariable;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Add numbering'**
  String get batchRuleTypeNumber;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get batchRuleTypeReplace;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Insert text'**
  String get batchRuleTypeInsert;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Delete characters'**
  String get batchRuleTypeDelete;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Change case'**
  String get batchRuleTypeCase;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Name template'**
  String get batchRuleTypeTemplate;

  /// Visible label for a built-in batch rename operation.
  ///
  /// In en, this message translates to:
  /// **'Clean whitespace'**
  String get batchRuleTypeCleanup;

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: Enter text or choose a file.'**
  String taskFlowValidationInputEmpty(String index);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: The image is over 20 MB. Choose a smaller image.'**
  String taskFlowValidationImageTooLarge(String index);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: The attachment is over 10 MB. Choose a smaller file.'**
  String taskFlowValidationAttachmentTooLarge(String index);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: The file is {actualType}, but {requiredType} is required. Choose another file.'**
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  );

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: Assistant chat does not support SVG image attachments. Convert it to PNG or JPEG.'**
  String taskFlowValidationSvgUnsupported(String index);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: Assistant chat does not support {mime} image attachments. Convert it to PNG, JPEG, GIF, or WebP.'**
  String taskFlowValidationImageMimeUnsupported(String index, String mime);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: Assistant chat does not support {mime} audio attachments. Convert it to MP3, WAV, or M4A.'**
  String taskFlowValidationAudioMimeUnsupported(String index, String mime);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: This Anthropic chat format does not support {type} attachments. Choose an assistant that supports this media.'**
  String taskFlowValidationEndpointMediaUnsupported(String index, String type);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: This Anthropic chat format supports only image and PDF attachments. Choose a supported file.'**
  String taskFlowValidationEndpointPdfOnly(String index);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: Assistant chat could not compress the image below 10 MB. Choose a smaller image.'**
  String taskFlowValidationImageCompressionFailed(String index);

  /// Localized TaskFlow input validation message.
  ///
  /// In en, this message translates to:
  /// **'Input {index}: The text attachment is not valid UTF-8. Convert it and try again.'**
  String taskFlowValidationTextEncodingFailed(String index);

  /// No description provided for @assistantParamValueTypeString.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get assistantParamValueTypeString;

  /// No description provided for @assistantParamValueTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get assistantParamValueTypeNumber;

  /// No description provided for @assistantParamValueTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get assistantParamValueTypeBoolean;

  /// No description provided for @assistantParamValueTypeJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get assistantParamValueTypeJson;

  /// No description provided for @providerRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Provider name, API URL, and key are required.'**
  String get providerRequiredFields;

  /// No description provided for @providerJsonSizePositive.
  ///
  /// In en, this message translates to:
  /// **'Request JSON size must be a positive MiB value.'**
  String get providerJsonSizePositive;

  /// No description provided for @providerCustomParamRequired.
  ///
  /// In en, this message translates to:
  /// **'Custom parameter name and value are required.'**
  String get providerCustomParamRequired;

  /// No description provided for @providerParamNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Parameter name is invalid (dot-separated segments cannot be empty): {name}'**
  String providerParamNameInvalid(String name);

  /// No description provided for @providerParamAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Parameter already exists: {name}'**
  String providerParamAlreadyExists(String name);

  /// No description provided for @providerParamInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Default value for parameter \"{name}\" is not valid JSON: {value}'**
  String providerParamInvalidJson(String name, String value);

  /// No description provided for @providerParamOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Numeric options for parameter \"{name}\" cannot be empty.'**
  String providerParamOptionsRequired(String name);

  /// No description provided for @providerParamInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Value for parameter \"{name}\" is not a valid number: {value}'**
  String providerParamInvalidNumber(String name, String value);

  /// No description provided for @providerReasoningIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle before enabling other reasoning parameters.'**
  String get providerReasoningIncomplete;

  /// No description provided for @providerReasoningError.
  ///
  /// In en, this message translates to:
  /// **'Reasoning parameter error: {error}'**
  String providerReasoningError(String error);

  /// No description provided for @providerParamNameConflict.
  ///
  /// In en, this message translates to:
  /// **'Reasoning and custom parameters have the same name: {name}'**
  String providerParamNameConflict(String name);

  /// No description provided for @providerMaxTokensMissing.
  ///
  /// In en, this message translates to:
  /// **'Maximum output tokens is enabled, but no value was entered.'**
  String get providerMaxTokensMissing;

  /// No description provided for @providerMaxTokensPositive.
  ///
  /// In en, this message translates to:
  /// **'Maximum output tokens must be a positive integer.'**
  String get providerMaxTokensPositive;

  /// No description provided for @providerSeedInteger.
  ///
  /// In en, this message translates to:
  /// **'Random seed must be an integer.'**
  String get providerSeedInteger;

  /// No description provided for @providerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get providerNotConfigured;

  /// No description provided for @providerAudioChunkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio chunking'**
  String get providerAudioChunkingTitle;

  /// No description provided for @providerAudioChunkingHint.
  ///
  /// In en, this message translates to:
  /// **'Smart chunking analyzes the audio and candidate cuts, preferring sentence endings. Chunks do not overlap.'**
  String get providerAudioChunkingHint;

  /// No description provided for @providerChunkingMode.
  ///
  /// In en, this message translates to:
  /// **'Chunking method'**
  String get providerChunkingMode;

  /// No description provided for @providerChunkNone.
  ///
  /// In en, this message translates to:
  /// **'No chunking'**
  String get providerChunkNone;

  /// No description provided for @providerChunkSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart chunking (recommended)'**
  String get providerChunkSmart;

  /// No description provided for @providerChunkFixedDuration.
  ///
  /// In en, this message translates to:
  /// **'Fixed-duration chunks'**
  String get providerChunkFixedDuration;

  /// No description provided for @providerChunkFixedSize.
  ///
  /// In en, this message translates to:
  /// **'Fixed-size chunks'**
  String get providerChunkFixedSize;

  /// No description provided for @providerCompressionTitle.
  ///
  /// In en, this message translates to:
  /// **'Compression encoding'**
  String get providerCompressionTitle;

  /// No description provided for @providerCompressionHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the general fallback first compresses the full WAV. If the encoded file or request body still exceeds the limit, the source PCM is chunked and encoded.'**
  String get providerCompressionHint;

  /// No description provided for @providerCompressionMode.
  ///
  /// In en, this message translates to:
  /// **'Compression method'**
  String get providerCompressionMode;

  /// No description provided for @providerCompressionNone.
  ///
  /// In en, this message translates to:
  /// **'None (send as is)'**
  String get providerCompressionNone;

  /// No description provided for @providerCompressionAdpcm.
  ///
  /// In en, this message translates to:
  /// **'ADPCM (~4x compression)'**
  String get providerCompressionAdpcm;

  /// No description provided for @providerCompressionFlac.
  ///
  /// In en, this message translates to:
  /// **'FLAC (lossless, ~2x)'**
  String get providerCompressionFlac;

  /// No description provided for @providerCompressionAdpcmDescription.
  ///
  /// In en, this message translates to:
  /// **'IMA ADPCM, lossy 4:1 compression. Pure Dart implementation; audio quality suits transcription.'**
  String get providerCompressionAdpcmDescription;

  /// No description provided for @providerCompressionFlacDescription.
  ///
  /// In en, this message translates to:
  /// **'Lossless FLAC compression, implemented in pure Dart. Reduces size by about half.'**
  String get providerCompressionFlacDescription;

  /// No description provided for @providerCompressionWavDescription.
  ///
  /// In en, this message translates to:
  /// **'No compression; send as a WAV file.'**
  String get providerCompressionWavDescription;

  /// No description provided for @providerLlmParams.
  ///
  /// In en, this message translates to:
  /// **'LLM parameters'**
  String get providerLlmParams;

  /// No description provided for @providerEnabledParamsHelp.
  ///
  /// In en, this message translates to:
  /// **'Enabled parameters are sent as defaults in API requests.'**
  String get providerEnabledParamsHelp;

  /// No description provided for @providerTemperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get providerTemperatureLabel;

  /// No description provided for @providerTemperatureHelp.
  ///
  /// In en, this message translates to:
  /// **'Controls output randomness; higher values are more creative.'**
  String get providerTemperatureHelp;

  /// No description provided for @providerTopPHelp.
  ///
  /// In en, this message translates to:
  /// **'Nucleus sampling parameter that controls cumulative probability for word selection.'**
  String get providerTopPHelp;

  /// No description provided for @providerFrequencyPenaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency penalty'**
  String get providerFrequencyPenaltyLabel;

  /// No description provided for @providerFrequencyPenaltyHelp.
  ///
  /// In en, this message translates to:
  /// **'Reduces repeated words; negative values increase repetition.'**
  String get providerFrequencyPenaltyHelp;

  /// No description provided for @providerPresencePenaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'Presence penalty'**
  String get providerPresencePenaltyLabel;

  /// No description provided for @providerPresencePenaltyHelp.
  ///
  /// In en, this message translates to:
  /// **'Encourages new topics; negative values encourage returning to previous topics.'**
  String get providerPresencePenaltyHelp;

  /// No description provided for @providerMaxOutputTokensLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum output tokens'**
  String get providerMaxOutputTokensLabel;

  /// No description provided for @providerOptionalExample.
  ///
  /// In en, this message translates to:
  /// **'Optional, e.g. {example}'**
  String providerOptionalExample(String example);

  /// No description provided for @providerResponseTokensHelp.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of tokens generated per response.'**
  String get providerResponseTokensHelp;

  /// No description provided for @providerSeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Random seed'**
  String get providerSeedLabel;

  /// No description provided for @providerSeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Set this to make output reproducible.'**
  String get providerSeedHelp;

  /// No description provided for @providerChunkSmartDescription.
  ///
  /// In en, this message translates to:
  /// **'Analyzes audio and candidate cuts, preferring sentence endings or long silences without overlap. Defaults: 20s minimum / 45s target / 60s maximum. Used only by the general fallback; compression chunking supports PCM WAV only.'**
  String get providerChunkSmartDescription;

  /// No description provided for @providerChunkDurationDescription.
  ///
  /// In en, this message translates to:
  /// **'Splits every N seconds (60 by default). Simple, but may cut off speech. Used only by the general fallback; compression chunking supports PCM WAV only.'**
  String get providerChunkDurationDescription;

  /// No description provided for @providerChunkSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Initially splits by audio data size, then refines by encoded file and request body size. Used only by the general fallback; compression chunking supports PCM WAV only.'**
  String get providerChunkSizeDescription;

  /// No description provided for @providerChunkNoneDescription.
  ///
  /// In en, this message translates to:
  /// **'No chunking. The file is rejected if it exceeds the limit after full compression.'**
  String get providerChunkNoneDescription;

  /// No description provided for @providerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider name'**
  String get providerNameLabel;

  /// No description provided for @providerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter provider name'**
  String get providerNameHint;

  /// No description provided for @providerApiUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API URL'**
  String get providerApiUrlLabel;

  /// No description provided for @providerApiUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the full API endpoint URL'**
  String get providerApiUrlHint;

  /// No description provided for @providerApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Hint: {hint}'**
  String providerApiKeyHint(String hint);

  /// No description provided for @providerEndpointTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint type'**
  String get providerEndpointTypeLabel;

  /// No description provided for @providerEndpointOpenAi.
  ///
  /// In en, this message translates to:
  /// **'OpenAI compatible (Chat Completions)'**
  String get providerEndpointOpenAi;

  /// No description provided for @providerEndpointAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Anthropic format (Messages API)'**
  String get providerEndpointAnthropic;

  /// No description provided for @providerAnthropicEndpointHelp.
  ///
  /// In en, this message translates to:
  /// **'Uses the official Anthropic Messages API format (x-api-key header). API URL example: https://api.anthropic.com/v1/messages'**
  String get providerAnthropicEndpointHelp;

  /// No description provided for @providerOpenAiEndpointHelp.
  ///
  /// In en, this message translates to:
  /// **'Uses the official OpenAI Chat Completions compatible format (Bearer header). API URL example: https://api.openai.com/v1/chat/completions'**
  String get providerOpenAiEndpointHelp;

  /// No description provided for @providerRequestJsonDefault.
  ///
  /// In en, this message translates to:
  /// **'Default request JSON size'**
  String get providerRequestJsonDefault;

  /// No description provided for @providerUseAppDefault.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the app default'**
  String get providerUseAppDefault;

  /// No description provided for @providerModelJsonBudgetHelp.
  ///
  /// In en, this message translates to:
  /// **'Models can override this value. If neither the provider nor model sets it, the default is 20 MiB.'**
  String get providerModelJsonBudgetHelp;

  /// No description provided for @providerRequestParamsHelp.
  ///
  /// In en, this message translates to:
  /// **'Requests use all enabled provider and model parameters. When names overlap, the model value takes precedence.'**
  String get providerRequestParamsHelp;

  /// No description provided for @providerUploadSettings.
  ///
  /// In en, this message translates to:
  /// **'Upload settings'**
  String get providerUploadSettings;

  /// No description provided for @providerUploadMethodHelp.
  ///
  /// In en, this message translates to:
  /// **'Audio upload methods and size limits vary by provider.'**
  String get providerUploadMethodHelp;

  /// No description provided for @providerUploadMethod.
  ///
  /// In en, this message translates to:
  /// **'Upload method'**
  String get providerUploadMethod;

  /// No description provided for @providerMultipart.
  ///
  /// In en, this message translates to:
  /// **'Multipart (general)'**
  String get providerMultipart;

  /// No description provided for @providerUrlUpload.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get providerUrlUpload;

  /// No description provided for @providerMaxUploadSize.
  ///
  /// In en, this message translates to:
  /// **'Maximum upload size'**
  String get providerMaxUploadSize;

  /// No description provided for @providerFallbackStrategy.
  ///
  /// In en, this message translates to:
  /// **'Fallback strategy'**
  String get providerFallbackStrategy;

  /// No description provided for @providerFallbackMethod.
  ///
  /// In en, this message translates to:
  /// **'Fallback method'**
  String get providerFallbackMethod;

  /// No description provided for @providerPreprocessing.
  ///
  /// In en, this message translates to:
  /// **'Audio preprocessing'**
  String get providerPreprocessing;

  /// No description provided for @providerPreprocessingHelp.
  ///
  /// In en, this message translates to:
  /// **'Reduces audio file size without affecting transcription accuracy.'**
  String get providerPreprocessingHelp;

  /// No description provided for @providerPreprocessingMethod.
  ///
  /// In en, this message translates to:
  /// **'Preprocessing method'**
  String get providerPreprocessingMethod;

  /// No description provided for @providerUploadMultipartHelp.
  ///
  /// In en, this message translates to:
  /// **'Direct multipart/form-data upload. The request body includes audio, form fields, and multipart boundaries.'**
  String get providerUploadMultipartHelp;

  /// No description provided for @providerUploadBase64Help.
  ///
  /// In en, this message translates to:
  /// **'Sends Base64 in JSON, which can bypass some providers’ multipart-specific limits. Base64 expansion and JSON fields count toward the upload limit.'**
  String get providerUploadBase64Help;

  /// No description provided for @providerUploadUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Provide a public URL for the provider to download. Supports very large files (e.g. Together AI 1 GB).'**
  String get providerUploadUrlHelp;

  /// No description provided for @providerUploadBudgetHelp.
  ///
  /// In en, this message translates to:
  /// **'This value triggers raw-audio fallback and limits the final request body. The app checks raw audio, encoded files, and upload size. Multipart includes form fields and boundaries; Base64 JSON includes encoding expansion and fields. The 25 MB default matches the OpenAI audio API limit.'**
  String get providerUploadBudgetHelp;

  /// No description provided for @providerFallbackTriggerHelp.
  ///
  /// In en, this message translates to:
  /// **'Triggered when raw audio or the complete request body exceeds its limit. Specific fallback (Base64) takes priority over general fallback (compression/chunking).'**
  String get providerFallbackTriggerHelp;

  /// No description provided for @providerFallbackNone.
  ///
  /// In en, this message translates to:
  /// **'None (reject immediately)'**
  String get providerFallbackNone;

  /// No description provided for @providerFallbackSpecific.
  ///
  /// In en, this message translates to:
  /// **'Specific fallback (Base64)'**
  String get providerFallbackSpecific;

  /// No description provided for @providerFallbackGeneric.
  ///
  /// In en, this message translates to:
  /// **'General fallback (compression/chunking)'**
  String get providerFallbackGeneric;

  /// No description provided for @providerFallbackAll.
  ///
  /// In en, this message translates to:
  /// **'Try all (recommended)'**
  String get providerFallbackAll;

  /// No description provided for @providerFallbackSpecificHelp.
  ///
  /// In en, this message translates to:
  /// **'Try Base64 JSON. Send only if the request body, including Base64 expansion and JSON fields, fits the limit.'**
  String get providerFallbackSpecificHelp;

  /// No description provided for @providerFallbackGenericHelp.
  ///
  /// In en, this message translates to:
  /// **'If enabled, compress the full WAV first. If it still exceeds the limit and chunking is enabled, split the source PCM and encode each chunk. PCM WAV only.'**
  String get providerFallbackGenericHelp;

  /// No description provided for @providerFallbackAllHelp.
  ///
  /// In en, this message translates to:
  /// **'Try Base64 within the request-body limit first. Then, if enabled, compress the full WAV; if it still exceeds the limit and chunking is enabled, split the source PCM and encode each chunk. PCM WAV only.'**
  String get providerFallbackAllHelp;

  /// No description provided for @providerFallbackRejectHelp.
  ///
  /// In en, this message translates to:
  /// **'Reject the file if it exceeds the limit; do not try a fallback.'**
  String get providerFallbackRejectHelp;

  /// No description provided for @providerPreprocessNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get providerPreprocessNone;

  /// No description provided for @providerPreprocessResample.
  ///
  /// In en, this message translates to:
  /// **'WAV optimization (16 kHz mono)'**
  String get providerPreprocessResample;

  /// No description provided for @providerPreprocessResampleHelp.
  ///
  /// In en, this message translates to:
  /// **'Resamples to 16 kHz and mixes to mono. Reduces size by about 4–6x with little effect on transcription accuracy.'**
  String get providerPreprocessResampleHelp;

  /// No description provided for @providerPreprocessNoneHelp.
  ///
  /// In en, this message translates to:
  /// **'No preprocessing; send as is.'**
  String get providerPreprocessNoneHelp;

  /// No description provided for @assistantDefaultsScopeHelp.
  ///
  /// In en, this message translates to:
  /// **'Default model and tools apply only to new conversations created under this assistant. Existing conversations keep their own settings. Tool output truncation applies to all conversations.'**
  String get assistantDefaultsScopeHelp;

  /// No description provided for @assistantDefaultModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get assistantDefaultModelTitle;

  /// No description provided for @assistantDefaultModelHelp.
  ///
  /// In en, this message translates to:
  /// **'Model used for new conversations; leave unset to let the conversation choose.'**
  String get assistantDefaultModelHelp;

  /// No description provided for @assistantNoDefault.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get assistantNoDefault;

  /// No description provided for @assistantNoModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available. Configure an LLM provider in Settings.'**
  String get assistantNoModelsAvailable;

  /// No description provided for @assistantDefaultToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Default enabled tools'**
  String get assistantDefaultToolsTitle;

  /// No description provided for @assistantDisabledToolsHelp.
  ///
  /// In en, this message translates to:
  /// **'Disabled tools will not be enabled automatically in new conversations.'**
  String get assistantDisabledToolsHelp;

  /// No description provided for @assistantUnconfiguredToolsHelp.
  ///
  /// In en, this message translates to:
  /// **'Default tools are not configured. New conversations will enable all tools automatically.'**
  String get assistantUnconfiguredToolsHelp;

  /// No description provided for @assistantEnableAll.
  ///
  /// In en, this message translates to:
  /// **'Enable all'**
  String get assistantEnableAll;

  /// No description provided for @assistantDisableAll.
  ///
  /// In en, this message translates to:
  /// **'Disable all'**
  String get assistantDisableAll;

  /// No description provided for @assistantNoToolsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tools available'**
  String get assistantNoToolsAvailable;

  /// No description provided for @assistantTruncateToolOutput.
  ///
  /// In en, this message translates to:
  /// **'Tool output truncation'**
  String get assistantTruncateToolOutput;

  /// No description provided for @assistantTruncateToolOutputHelp.
  ///
  /// In en, this message translates to:
  /// **'Maximum characters in each tool result before it is sent to the model. Applies to all conversations under this assistant.'**
  String get assistantTruncateToolOutputHelp;

  /// No description provided for @assistantEnableTruncation.
  ///
  /// In en, this message translates to:
  /// **'Enable truncation'**
  String get assistantEnableTruncation;

  /// No description provided for @assistantTruncatedTo.
  ///
  /// In en, this message translates to:
  /// **'Long results are truncated to {count} characters'**
  String assistantTruncatedTo(String count);

  /// No description provided for @assistantSendFullResult.
  ///
  /// In en, this message translates to:
  /// **'Send full result (subject to the 50 KB storage limit)'**
  String get assistantSendFullResult;

  /// No description provided for @assistantMaxCharacters.
  ///
  /// In en, this message translates to:
  /// **'Maximum characters'**
  String get assistantMaxCharacters;

  /// No description provided for @assistantCharactersNotTokens.
  ///
  /// In en, this message translates to:
  /// **'Unit: characters (not tokens)'**
  String get assistantCharactersNotTokens;

  /// No description provided for @assistantDefaultCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'Default: {count}'**
  String assistantDefaultCharacterCount(String count);

  /// No description provided for @assistantCharacterRange.
  ///
  /// In en, this message translates to:
  /// **'Valid range: {minimum}–{maximum} characters'**
  String assistantCharacterRange(String minimum, String maximum);

  /// No description provided for @assistantNewConversationPreview.
  ///
  /// In en, this message translates to:
  /// **'New conversation preview'**
  String get assistantNewConversationPreview;

  /// No description provided for @assistantEnabledToolCount.
  ///
  /// In en, this message translates to:
  /// **'{enabled} / {total} enabled'**
  String assistantEnabledToolCount(String enabled, String total);

  /// No description provided for @assistantAllToolsAutoEnabled.
  ///
  /// In en, this message translates to:
  /// **'All tools are enabled automatically (not configured)'**
  String get assistantAllToolsAutoEnabled;

  /// No description provided for @assistantMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get assistantMoreActions;

  /// No description provided for @assistantChooseEmoji.
  ///
  /// In en, this message translates to:
  /// **'Choose emoji'**
  String get assistantChooseEmoji;

  /// No description provided for @assistantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistant name'**
  String get assistantNameLabel;

  /// No description provided for @assistantDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get assistantDescriptionOptional;

  /// No description provided for @assistantSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an assistant'**
  String get assistantSelectionTitle;

  /// No description provided for @assistantMarketTooltip.
  ///
  /// In en, this message translates to:
  /// **'Assistant marketplace'**
  String get assistantMarketTooltip;

  /// No description provided for @assistantCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create assistant'**
  String get assistantCreateNew;

  /// No description provided for @assistantEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No assistants yet. Create one to get started.'**
  String get assistantEmptyState;

  /// No description provided for @assistantCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get assistantCreate;

  /// No description provided for @assistantReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press and drag to reorder assistants'**
  String get assistantReorderHint;

  /// No description provided for @assistantNewNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter assistant name'**
  String get assistantNewNameHint;

  /// No description provided for @assistantNewDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Briefly describe what this assistant does'**
  String get assistantNewDescriptionHint;

  /// No description provided for @assistantDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete assistant'**
  String get assistantDeleteTitle;

  /// No description provided for @assistantDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete assistant “{name}”? This action cannot be undone.'**
  String assistantDeleteConfirmation(String name);

  /// No description provided for @assistantEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit assistant'**
  String get assistantEditTitle;

  /// No description provided for @assistantBasicTab.
  ///
  /// In en, this message translates to:
  /// **'Basic settings'**
  String get assistantBasicTab;

  /// No description provided for @assistantParametersTab.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get assistantParametersTab;

  /// No description provided for @assistantDefaultsTab.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get assistantDefaultsTab;

  /// No description provided for @assistantAddCustomParameter.
  ///
  /// In en, this message translates to:
  /// **'Add custom parameter'**
  String get assistantAddCustomParameter;

  /// No description provided for @assistantEditCustomParameter.
  ///
  /// In en, this message translates to:
  /// **'Edit custom parameter'**
  String get assistantEditCustomParameter;

  /// No description provided for @assistantParameterName.
  ///
  /// In en, this message translates to:
  /// **'Parameter name'**
  String get assistantParameterName;

  /// No description provided for @assistantParameterNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. top_k or provider.only'**
  String get assistantParameterNameHint;

  /// No description provided for @assistantParameterNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid parameter name (dot-separated segments cannot be empty)'**
  String get assistantParameterNameInvalid;

  /// No description provided for @assistantParameterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get assistantParameterType;

  /// No description provided for @assistantValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get assistantValue;

  /// No description provided for @assistantTrueFalseHint.
  ///
  /// In en, this message translates to:
  /// **'true or false'**
  String get assistantTrueFalseHint;

  /// No description provided for @assistantNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get assistantNumberHint;

  /// No description provided for @assistantJsonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}'**
  String assistantJsonHint(String example);

  /// No description provided for @assistantValueHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get assistantValueHint;

  /// No description provided for @assistantCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantCancel;

  /// No description provided for @assistantSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantSave;

  /// No description provided for @assistantParamOverrideHelp.
  ///
  /// In en, this message translates to:
  /// **'When enabled, assistant parameters override model parameters; when disabled, model parameters are used.'**
  String get assistantParamOverrideHelp;

  /// No description provided for @assistantTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get assistantTemperature;

  /// No description provided for @assistantMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Maximum tokens'**
  String get assistantMaxTokens;

  /// No description provided for @assistantMaxToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Maximum tool calls'**
  String get assistantMaxToolCalls;

  /// No description provided for @assistantRounds.
  ///
  /// In en, this message translates to:
  /// **'{count} rounds'**
  String assistantRounds(String count);

  /// No description provided for @assistantUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get assistantUnlimited;

  /// No description provided for @assistantStreamOutput.
  ///
  /// In en, this message translates to:
  /// **'Stream output'**
  String get assistantStreamOutput;

  /// No description provided for @assistantFrequencyPenalty.
  ///
  /// In en, this message translates to:
  /// **'Frequency penalty'**
  String get assistantFrequencyPenalty;

  /// No description provided for @assistantPresencePenalty.
  ///
  /// In en, this message translates to:
  /// **'Presence penalty'**
  String get assistantPresencePenalty;

  /// No description provided for @assistantRandomSeed.
  ///
  /// In en, this message translates to:
  /// **'Random seed'**
  String get assistantRandomSeed;

  /// No description provided for @assistantNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get assistantNotSet;

  /// No description provided for @assistantSeedValue.
  ///
  /// In en, this message translates to:
  /// **'Seed value'**
  String get assistantSeedValue;

  /// No description provided for @assistantIntegerSeedHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an integer seed'**
  String get assistantIntegerSeedHint;

  /// No description provided for @assistantWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web search'**
  String get assistantWebSearch;

  /// No description provided for @assistantAddParameter.
  ///
  /// In en, this message translates to:
  /// **'Add parameter'**
  String get assistantAddParameter;

  /// No description provided for @assistantNoCustomParameters.
  ///
  /// In en, this message translates to:
  /// **'No custom parameters'**
  String get assistantNoCustomParameters;

  /// No description provided for @assistantRoundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get assistantRoundsLabel;

  /// No description provided for @modelCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Add model'**
  String get modelCreateTitle;

  /// No description provided for @modelEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit model'**
  String get modelEditTitle;

  /// No description provided for @modelDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get modelDiscardTitle;

  /// No description provided for @modelDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Discard them?'**
  String get modelDiscardBody;

  /// No description provided for @modelNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get modelNameLabel;

  /// No description provided for @modelNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name (optional)'**
  String get modelNameHint;

  /// No description provided for @modelIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get modelIdLabel;

  /// No description provided for @modelIdExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. {id}'**
  String modelIdExample(String id);

  /// No description provided for @modelIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Model ID is required.'**
  String get modelIdRequired;

  /// No description provided for @modelCustomParamRequired.
  ///
  /// In en, this message translates to:
  /// **'Custom parameter name and default value are required.'**
  String get modelCustomParamRequired;

  /// No description provided for @modelParamDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Parameter already exists: {name}'**
  String modelParamDuplicate(String name);

  /// No description provided for @modelParamName.
  ///
  /// In en, this message translates to:
  /// **'Parameter name'**
  String get modelParamName;

  /// No description provided for @modelParamDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'Default parameter value'**
  String get modelParamDefaultValue;

  /// No description provided for @modelParamDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete parameter'**
  String get modelParamDelete;

  /// No description provided for @modelParamJsonInvalid.
  ///
  /// In en, this message translates to:
  /// **'Default value for parameter \"{name}\" is not valid JSON: {value}'**
  String modelParamJsonInvalid(String name, String value);

  /// No description provided for @modelAddParameter.
  ///
  /// In en, this message translates to:
  /// **'Add parameter'**
  String get modelAddParameter;

  /// No description provided for @modelNoCustomParams.
  ///
  /// In en, this message translates to:
  /// **'No custom parameters'**
  String get modelNoCustomParams;

  /// No description provided for @modelBasicSettings.
  ///
  /// In en, this message translates to:
  /// **'Basic settings'**
  String get modelBasicSettings;

  /// No description provided for @modelDiscardCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get modelDiscardCancel;

  /// No description provided for @modelSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get modelSave;

  /// No description provided for @modelUnsavedMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Maximum output tokens is enabled but has no value.'**
  String get modelUnsavedMaxTokens;

  /// No description provided for @modelMaxTokensPositive.
  ///
  /// In en, this message translates to:
  /// **'Maximum output tokens must be a positive integer.'**
  String get modelMaxTokensPositive;

  /// No description provided for @modelSeedInteger.
  ///
  /// In en, this message translates to:
  /// **'Random seed must be an integer.'**
  String get modelSeedInteger;

  /// No description provided for @modelContextLengthRequired.
  ///
  /// In en, this message translates to:
  /// **'Context length is required.'**
  String get modelContextLengthRequired;

  /// No description provided for @modelContextLengthPositive.
  ///
  /// In en, this message translates to:
  /// **'Context length must be a positive integer.'**
  String get modelContextLengthPositive;

  /// No description provided for @modelAsrLanguageCode.
  ///
  /// In en, this message translates to:
  /// **'Language code (Language)'**
  String get modelAsrLanguageCode;

  /// No description provided for @modelAsrLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. zh, en, ja'**
  String get modelAsrLanguageHint;

  /// No description provided for @modelAsrLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'ISO-639-1 language code; leave empty for automatic detection.'**
  String get modelAsrLanguageHelp;

  /// No description provided for @modelTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get modelTemperature;

  /// No description provided for @modelTemperatureHelp.
  ///
  /// In en, this message translates to:
  /// **'Controls output randomness; a lower value is recommended.'**
  String get modelTemperatureHelp;

  /// No description provided for @modelAsrPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get modelAsrPrompt;

  /// No description provided for @modelAsrPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a context prompt (optional)'**
  String get modelAsrPromptHint;

  /// No description provided for @modelAsrPromptHelp.
  ///
  /// In en, this message translates to:
  /// **'Provide context to improve transcription accuracy, such as a list of specialist terms.'**
  String get modelAsrPromptHelp;

  /// No description provided for @modelAsrParams.
  ///
  /// In en, this message translates to:
  /// **'ASR parameters'**
  String get modelAsrParams;

  /// No description provided for @modelEnabledParamsHelp.
  ///
  /// In en, this message translates to:
  /// **'Enabled parameters are sent as defaults in API requests.'**
  String get modelEnabledParamsHelp;

  /// No description provided for @modelAsrResponseFormat.
  ///
  /// In en, this message translates to:
  /// **'Response format'**
  String get modelAsrResponseFormat;

  /// No description provided for @modelAsrResponseHelp.
  ///
  /// In en, this message translates to:
  /// **'Format of the returned transcription.'**
  String get modelAsrResponseHelp;

  /// No description provided for @modelAsrTimestampGranularity.
  ///
  /// In en, this message translates to:
  /// **'Timestamp granularity'**
  String get modelAsrTimestampGranularity;

  /// No description provided for @modelAsrVerboseHelp.
  ///
  /// In en, this message translates to:
  /// **'Available only when response_format is verbose_json.'**
  String get modelAsrVerboseHelp;

  /// No description provided for @modelNoTrim.
  ///
  /// In en, this message translates to:
  /// **'No trimming'**
  String get modelNoTrim;

  /// No description provided for @modelAudioTrimTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio trimming'**
  String get modelAudioTrimTitle;

  /// No description provided for @modelAudioTrimHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose how to trim the audio.'**
  String get modelAudioTrimHelp;

  /// No description provided for @modelDeleteTrimPreset.
  ///
  /// In en, this message translates to:
  /// **'Delete trim preset'**
  String get modelDeleteTrimPreset;

  /// No description provided for @modelDeleteTrimConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete trim preset \"{name}\"?'**
  String modelDeleteTrimConfirmation(String name);

  /// No description provided for @modelAddTrimPreset.
  ///
  /// In en, this message translates to:
  /// **'Add custom trim'**
  String get modelAddTrimPreset;

  /// No description provided for @modelPlayTestAudio.
  ///
  /// In en, this message translates to:
  /// **'Play test audio'**
  String get modelPlayTestAudio;

  /// No description provided for @modelPlayingTestAudio.
  ///
  /// In en, this message translates to:
  /// **'Playing...'**
  String get modelPlayingTestAudio;

  /// No description provided for @modelParamExists.
  ///
  /// In en, this message translates to:
  /// **'Parameter already exists'**
  String get modelParamExists;

  /// No description provided for @asrModelIdExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. whisper-1'**
  String get asrModelIdExample;

  /// No description provided for @asrPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get asrPromptLabel;

  /// No description provided for @asrResponseFormatJson.
  ///
  /// In en, this message translates to:
  /// **'json – JSON'**
  String get asrResponseFormatJson;

  /// No description provided for @asrResponseFormatText.
  ///
  /// In en, this message translates to:
  /// **'text – Plain text'**
  String get asrResponseFormatText;

  /// No description provided for @asrResponseFormatSrt.
  ///
  /// In en, this message translates to:
  /// **'srt – Subtitles'**
  String get asrResponseFormatSrt;

  /// No description provided for @asrResponseFormatVtt.
  ///
  /// In en, this message translates to:
  /// **'vtt – Subtitles'**
  String get asrResponseFormatVtt;

  /// No description provided for @asrResponseFormatVerbose.
  ///
  /// In en, this message translates to:
  /// **'verbose_json – Detailed JSON (includes timestamps)'**
  String get asrResponseFormatVerbose;

  /// No description provided for @asrVerboseTimestampHelp.
  ///
  /// In en, this message translates to:
  /// **'Selecting verbose_json enables the timestamp granularity option below.'**
  String get asrVerboseTimestampHelp;

  /// No description provided for @asrTimestampSegment.
  ///
  /// In en, this message translates to:
  /// **'segment – Segment level'**
  String get asrTimestampSegment;

  /// No description provided for @asrTimestampWord.
  ///
  /// In en, this message translates to:
  /// **'word – Word level'**
  String get asrTimestampWord;

  /// No description provided for @asrWordTimestampHelp.
  ///
  /// In en, this message translates to:
  /// **'Word-level timestamps may be less accurate than segment-level timestamps.'**
  String get asrWordTimestampHelp;

  /// No description provided for @reasoningAddOptionValue.
  ///
  /// In en, this message translates to:
  /// **'Add option value'**
  String get reasoningAddOptionValue;

  /// No description provided for @reasoningEditOptionValue.
  ///
  /// In en, this message translates to:
  /// **'Edit option value'**
  String get reasoningEditOptionValue;

  /// No description provided for @reasoningOptionExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. low, medium, high'**
  String get reasoningOptionExample;

  /// No description provided for @reasoningOptionSelectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a chip to select or clear it. Selected values are sent; drag to reorder. Provider values cannot be deleted, but can be hidden by clearing them.'**
  String get reasoningOptionSelectionHelp;

  /// No description provided for @reasoningAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get reasoningAddOption;

  /// No description provided for @reasoningCurrentProvider.
  ///
  /// In en, this message translates to:
  /// **'Current: provider'**
  String get reasoningCurrentProvider;

  /// No description provided for @reasoningCurrentModel.
  ///
  /// In en, this message translates to:
  /// **'Current: model custom'**
  String get reasoningCurrentModel;

  /// No description provided for @reasoningAddEffortValue.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning effort value'**
  String get reasoningAddEffortValue;

  /// No description provided for @reasoningEffortExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. max, ultra, deep'**
  String get reasoningEffortExample;

  /// No description provided for @reasoningAddToggle.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning toggle'**
  String get reasoningAddToggle;

  /// No description provided for @reasoningToggle.
  ///
  /// In en, this message translates to:
  /// **'Reasoning toggle'**
  String get reasoningToggle;

  /// No description provided for @reasoningResetParameter.
  ///
  /// In en, this message translates to:
  /// **'Reset this parameter'**
  String get reasoningResetParameter;

  /// No description provided for @reasoningDisableToggle.
  ///
  /// In en, this message translates to:
  /// **'Disable reasoning toggle'**
  String get reasoningDisableToggle;

  /// No description provided for @reasoningEnableToggle.
  ///
  /// In en, this message translates to:
  /// **'Enable reasoning toggle'**
  String get reasoningEnableToggle;

  /// No description provided for @reasoningParameterNameSource.
  ///
  /// In en, this message translates to:
  /// **'Parameter name ({source})'**
  String reasoningParameterNameSource(String source);

  /// No description provided for @reasoningNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. thinking.type, reasoning'**
  String get reasoningNameExample;

  /// No description provided for @reasoningBooleanHelp.
  ///
  /// In en, this message translates to:
  /// **'Boolean parameters need no value; the chat panel provides an on/off switch.'**
  String get reasoningBooleanHelp;

  /// No description provided for @reasoningOnValue.
  ///
  /// In en, this message translates to:
  /// **'Value when enabled'**
  String get reasoningOnValue;

  /// No description provided for @reasoningOnExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. enabled, true'**
  String get reasoningOnExample;

  /// No description provided for @reasoningOffValue.
  ///
  /// In en, this message translates to:
  /// **'Value when disabled'**
  String get reasoningOffValue;

  /// No description provided for @reasoningOffExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. disabled, false'**
  String get reasoningOffExample;

  /// No description provided for @reasoningToggleValuesHelp.
  ///
  /// In en, this message translates to:
  /// **'When enabled, sends “{onValue}”; when disabled, sends “{offValue}”.'**
  String reasoningToggleValuesHelp(String onValue, String offValue);

  /// No description provided for @reasoningAddEffort.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning effort'**
  String get reasoningAddEffort;

  /// No description provided for @reasoningFillToggleFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle first'**
  String get reasoningFillToggleFirst;

  /// No description provided for @reasoningFillToggleBeforeEffort.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle before configuring reasoning effort.'**
  String get reasoningFillToggleBeforeEffort;

  /// No description provided for @reasoningAddValue.
  ///
  /// In en, this message translates to:
  /// **'Add value'**
  String get reasoningAddValue;

  /// No description provided for @reasoningJsonValue.
  ///
  /// In en, this message translates to:
  /// **'JSON value'**
  String get reasoningJsonValue;

  /// No description provided for @reasoningJsonExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}'**
  String reasoningJsonExample(String example);

  /// No description provided for @reasoningSelectedChipHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a chip to select or clear it. Selected values appear in the chat reasoning panel; drag to reorder. Provider values cannot be deleted, but can be hidden.'**
  String get reasoningSelectedChipHelp;

  /// No description provided for @reasoningAddParameter.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning parameter'**
  String get reasoningAddParameter;

  /// No description provided for @reasoningToggleIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle before configuring reasoning effort.'**
  String get reasoningToggleIncomplete;

  /// No description provided for @llmContextLength.
  ///
  /// In en, this message translates to:
  /// **'Context length'**
  String get llmContextLength;

  /// No description provided for @llmContextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter context length'**
  String get llmContextHint;

  /// No description provided for @llmContextHelp.
  ///
  /// In en, this message translates to:
  /// **'Maximum context window size for the model (tokens).'**
  String get llmContextHelp;

  /// No description provided for @llmReasoningParams.
  ///
  /// In en, this message translates to:
  /// **'Reasoning parameters'**
  String get llmReasoningParams;

  /// No description provided for @llmReasoningHelp.
  ///
  /// In en, this message translates to:
  /// **'Configure reasoning parameters for chat. The reasoning toggle controls its parameter name and on/off values. Add reasoning effort values, reorder them, and select which values appear in the chat panel. Provider values are synchronized when this page opens. These settings control model parameter availability; the chat panel toggle is managed separately.'**
  String get llmReasoningHelp;

  /// No description provided for @llmAddReasoningParam.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning parameter'**
  String get llmAddReasoningParam;

  /// No description provided for @llmCustomEndpointType.
  ///
  /// In en, this message translates to:
  /// **'Custom endpoint type'**
  String get llmCustomEndpointType;

  /// No description provided for @llmInheritEndpointType.
  ///
  /// In en, this message translates to:
  /// **'When disabled, use the endpoint type from provider settings.'**
  String get llmInheritEndpointType;

  /// No description provided for @llmEndpointType.
  ///
  /// In en, this message translates to:
  /// **'Endpoint type'**
  String get llmEndpointType;

  /// No description provided for @llmEndpointOpenAi.
  ///
  /// In en, this message translates to:
  /// **'OpenAI compatible (Chat Completions)'**
  String get llmEndpointOpenAi;

  /// No description provided for @llmEndpointAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Anthropic format (Messages API)'**
  String get llmEndpointAnthropic;

  /// No description provided for @llmEndpointHelp.
  ///
  /// In en, this message translates to:
  /// **'The endpoint type must match the provider API URL. Changing it affects the format used for new conversations with this model.'**
  String get llmEndpointHelp;

  /// No description provided for @llmTopPHelp.
  ///
  /// In en, this message translates to:
  /// **'Nucleus sampling parameter; controls cumulative probability for word selection.'**
  String get llmTopPHelp;

  /// No description provided for @llmFrequencyPenaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency penalty'**
  String get llmFrequencyPenaltyLabel;

  /// No description provided for @llmFrequencyPenaltyHelp.
  ///
  /// In en, this message translates to:
  /// **'Reduces repetition; negative values increase it.'**
  String get llmFrequencyPenaltyHelp;

  /// No description provided for @llmPresencePenaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'Presence penalty'**
  String get llmPresencePenaltyLabel;

  /// No description provided for @llmPresencePenaltyHelp.
  ///
  /// In en, this message translates to:
  /// **'Encourages new topics; negative values encourage repetition.'**
  String get llmPresencePenaltyHelp;

  /// No description provided for @llmMaxTokensHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, e.g. 4096'**
  String get llmMaxTokensHint;

  /// No description provided for @llmTokensPerResponse.
  ///
  /// In en, this message translates to:
  /// **'Maximum tokens generated per response.'**
  String get llmTokensPerResponse;

  /// No description provided for @llmSeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Random seed (Seed)'**
  String get llmSeedLabel;

  /// No description provided for @llmSeedHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, e.g. 42'**
  String get llmSeedHint;

  /// No description provided for @llmSeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Setting this makes output reproducible.'**
  String get llmSeedHelp;

  /// No description provided for @llmInheritedCustomHelp.
  ///
  /// In en, this message translates to:
  /// **'Provider custom parameters are shown here and synchronized whenever this page opens.'**
  String get llmInheritedCustomHelp;

  /// No description provided for @llmBooleanParamHelp.
  ///
  /// In en, this message translates to:
  /// **'Boolean parameters do not need a value.'**
  String get llmBooleanParamHelp;

  /// No description provided for @modelContextReq.
  ///
  /// In en, this message translates to:
  /// **'Context length is required.'**
  String get modelContextReq;

  /// No description provided for @modelContextPositive.
  ///
  /// In en, this message translates to:
  /// **'Context length must be a positive integer.'**
  String get modelContextPositive;

  /// No description provided for @modelParamNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid parameter name (dot-separated segments cannot be empty): {name}'**
  String modelParamNameInvalid(String name);

  /// No description provided for @modelParamFinite.
  ///
  /// In en, this message translates to:
  /// **'Parameter \"{name}\" {valueLabel} must be a finite number: {value}'**
  String modelParamFinite(String name, String valueLabel, String value);

  /// No description provided for @modelReasoningIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle before enabling other reasoning parameters.'**
  String get modelReasoningIncomplete;

  /// No description provided for @modelReasoningOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one option value to the reasoning parameter.'**
  String get modelReasoningOptionsRequired;

  /// No description provided for @modelReasoningError.
  ///
  /// In en, this message translates to:
  /// **'Reasoning parameter error: {error}'**
  String modelReasoningError(String error);

  /// No description provided for @modelReasoningDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate reasoning parameter: {name}'**
  String modelReasoningDuplicate(String name);

  /// No description provided for @modelReasoningCustomDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Reasoning and custom parameters share the name: {name}'**
  String modelReasoningCustomDuplicate(String name);

  /// No description provided for @modelSeedRequired.
  ///
  /// In en, this message translates to:
  /// **'Random seed is enabled but empty.'**
  String get modelSeedRequired;

  /// No description provided for @ocrParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'OCR parameters'**
  String get ocrParamsTitle;

  /// No description provided for @ocrParamsHelp.
  ///
  /// In en, this message translates to:
  /// **'Uses the OpenAI-compatible vision Chat Completions format. Parameters below are optional; unset or disabled parameters are not sent. Add provider-specific parameters below if supported by its API.'**
  String get ocrParamsHelp;

  /// No description provided for @ocrRequestSizeOverride.
  ///
  /// In en, this message translates to:
  /// **'Request JSON size override'**
  String get ocrRequestSizeOverride;

  /// No description provided for @ocrInheritProvider.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to inherit provider settings'**
  String get ocrInheritProvider;

  /// No description provided for @ocrBudgetDefault.
  ///
  /// In en, this message translates to:
  /// **'When empty, inherits provider settings; if the provider has no value, the default is 20 MiB.'**
  String get ocrBudgetDefault;

  /// No description provided for @ocrBudgetValue.
  ///
  /// In en, this message translates to:
  /// **'When empty, inherits provider settings ({size} MiB); if the provider has no value, the default is 20 MiB.'**
  String ocrBudgetValue(String size);

  /// No description provided for @audioTrimDirection.
  ///
  /// In en, this message translates to:
  /// **'Trim {direction} {seconds}s'**
  String audioTrimDirection(String direction, String seconds);

  /// No description provided for @audioTrimBeginning.
  ///
  /// In en, this message translates to:
  /// **'Trim the first {seconds}s'**
  String audioTrimBeginning(String seconds);

  /// No description provided for @audioTrimNone.
  ///
  /// In en, this message translates to:
  /// **'Do not trim audio'**
  String get audioTrimNone;

  /// No description provided for @trimNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Trim method name *'**
  String get trimNameLabel;

  /// No description provided for @trimNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. silence trimming'**
  String get trimNameHint;

  /// No description provided for @trimDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Trim duration (seconds) *'**
  String get trimDurationLabel;

  /// No description provided for @trimDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0.123'**
  String get trimDurationHint;

  /// No description provided for @trimNameAndDurationRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and duration are required.'**
  String get trimNameAndDurationRequired;

  /// No description provided for @trimDurationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid positive duration.'**
  String get trimDurationInvalid;

  /// No description provided for @testAudioHostMissing.
  ///
  /// In en, this message translates to:
  /// **'Host is not configured.'**
  String get testAudioHostMissing;

  /// No description provided for @testAudioKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Key is not configured.'**
  String get testAudioKeyMissing;

  /// No description provided for @testAudioContentTypeError.
  ///
  /// In en, this message translates to:
  /// **'Response Content-Type is {contentType}, not audio.'**
  String testAudioContentTypeError(String contentType);

  /// No description provided for @testAudioEmpty.
  ///
  /// In en, this message translates to:
  /// **'The server returned empty audio data.'**
  String get testAudioEmpty;

  /// No description provided for @testAudioTimeoutConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check your network. {details}'**
  String testAudioTimeoutConnection(String details);

  /// No description provided for @testAudioTimeoutReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive timed out; the server responded too slowly. {details}'**
  String testAudioTimeoutReceive(String details);

  /// No description provided for @testAudioRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled. {details}'**
  String testAudioRequestCancelled(String details);

  /// No description provided for @testAudioNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {message}'**
  String testAudioNetworkError(String message);

  /// No description provided for @testAudioNoBody.
  ///
  /// In en, this message translates to:
  /// **'No response body'**
  String get testAudioNoBody;

  /// No description provided for @testAudioCorsHelp.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to server. On web, this may be caused by CORS or an incorrect API URL. Check the provider API URL and whether the server allows cross-origin requests. {details}'**
  String testAudioCorsHelp(String details);

  /// No description provided for @trimModelNameHint.
  ///
  /// In en, this message translates to:
  /// **'A friendly name for display and identification, e.g. \"GPT-4o Mini TTS\". Use different names to distinguish models from the same provider.'**
  String get trimModelNameHint;

  /// No description provided for @trimModelIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Unique identifier used in API calls, e.g. \"gpt-4o-mini-tts\". It must match the model ID provided by the vendor.'**
  String get trimModelIdHelp;

  /// No description provided for @ttsVoiceRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Volume range'**
  String get ttsVoiceRangeTitle;

  /// No description provided for @ttsMinVolume.
  ///
  /// In en, this message translates to:
  /// **'Minimum volume'**
  String get ttsMinVolume;

  /// No description provided for @ttsMaxVolume.
  ///
  /// In en, this message translates to:
  /// **'Maximum volume'**
  String get ttsMaxVolume;

  /// No description provided for @ttsSpeedRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed range'**
  String get ttsSpeedRangeTitle;

  /// No description provided for @ttsMinSpeed.
  ///
  /// In en, this message translates to:
  /// **'Minimum speed'**
  String get ttsMinSpeed;

  /// No description provided for @ttsMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Maximum speed'**
  String get ttsMaxSpeed;

  /// No description provided for @ttsMaxAudioLength.
  ///
  /// In en, this message translates to:
  /// **'Maximum audio length per request *'**
  String get ttsMaxAudioLength;

  /// No description provided for @ttsAudioLengthHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1000'**
  String get ttsAudioLengthHint;

  /// No description provided for @ttsNoVoices.
  ///
  /// In en, this message translates to:
  /// **'No voices. Tap to edit.'**
  String get ttsNoVoices;

  /// No description provided for @ttsInstructionSupported.
  ///
  /// In en, this message translates to:
  /// **'Model supports the instruction parameter'**
  String get ttsInstructionSupported;

  /// No description provided for @ttsInstructionHelp.
  ///
  /// In en, this message translates to:
  /// **'When enabled, TTS requests can include instructions for tone, emotion, speaking speed, and more.'**
  String get ttsInstructionHelp;

  /// No description provided for @ttsStreamSupported.
  ///
  /// In en, this message translates to:
  /// **'Model supports streaming output'**
  String get ttsStreamSupported;

  /// No description provided for @ttsStreamHelp.
  ///
  /// In en, this message translates to:
  /// **'Enables this model for streaming scenarios. Confirm the model supports streaming before enabling.'**
  String get ttsStreamHelp;

  /// No description provided for @modelParamBooleanExpected.
  ///
  /// In en, this message translates to:
  /// **'Parameter “{name}” must be true or false: {value}'**
  String modelParamBooleanExpected(String name, String value);

  /// No description provided for @ttsMaxAudioLengthRequired.
  ///
  /// In en, this message translates to:
  /// **'Maximum audio length per request is required; enter a positive integer.'**
  String get ttsMaxAudioLengthRequired;

  /// No description provided for @asrLanguageExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. zh, en, ja'**
  String get asrLanguageExample;

  /// No description provided for @llmReasoningFullHelp.
  ///
  /// In en, this message translates to:
  /// **'The reasoning toggle controls whether reasoning is sent and lets you define the parameter name and on/off values. There is one reasoning-effort parameter. Select values and drag to reorder them; selected values appear in the chat reasoning panel. Add other reasoning parameters below. Parameter names support dot notation such as thinking.type, which becomes a nested JSON object. Provider reasoning parameters synchronize when this page opens. The switches here control model parameters; the chat reasoning toggle is separate.'**
  String get llmReasoningFullHelp;

  /// No description provided for @llmTemperatureHelp.
  ///
  /// In en, this message translates to:
  /// **'Controls output randomness; higher values are more creative.'**
  String get llmTemperatureHelp;

  /// No description provided for @llmBooleanValueHelp.
  ///
  /// In en, this message translates to:
  /// **'Boolean parameters do not need a value.'**
  String get llmBooleanValueHelp;

  /// No description provided for @reasoningDisableEffort.
  ///
  /// In en, this message translates to:
  /// **'Disable reasoning effort'**
  String get reasoningDisableEffort;

  /// No description provided for @reasoningEnableEffort.
  ///
  /// In en, this message translates to:
  /// **'Enable reasoning effort'**
  String get reasoningEnableEffort;

  /// No description provided for @ocrJsonSizePositive.
  ///
  /// In en, this message translates to:
  /// **'Request JSON size must be a positive MiB value.'**
  String get ocrJsonSizePositive;

  /// No description provided for @ttsRangePair.
  ///
  /// In en, this message translates to:
  /// **'Enter both the minimum and maximum {kind}, or leave both empty.'**
  String ttsRangePair(String kind);

  /// No description provided for @ttsEditTrimTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit custom trim'**
  String get ttsEditTrimTitle;

  /// No description provided for @ttsVoicesCount.
  ///
  /// In en, this message translates to:
  /// **'Voices ({count})'**
  String ttsVoicesCount(String count);

  /// No description provided for @ttsRequestFormatExample.
  ///
  /// In en, this message translates to:
  /// **'Generated in the request format: {syntax}'**
  String ttsRequestFormatExample(String syntax);

  /// No description provided for @mcpServerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an MCP server name.'**
  String get mcpServerNameRequired;

  /// No description provided for @mcpStdioCommandRequired.
  ///
  /// In en, this message translates to:
  /// **'stdio mode requires a command.'**
  String get mcpStdioCommandRequired;

  /// No description provided for @mcpSseUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'SSE mode requires a URL.'**
  String get mcpSseUrlRequired;

  /// No description provided for @mcpEditServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit MCP server'**
  String get mcpEditServerTitle;

  /// No description provided for @mcpCreateServerTitle.
  ///
  /// In en, this message translates to:
  /// **'New MCP server'**
  String get mcpCreateServerTitle;

  /// No description provided for @mcpUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get mcpUnsavedChangesTitle;

  /// No description provided for @mcpUnsavedChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Discard them?'**
  String get mcpUnsavedChangesConfirm;

  /// No description provided for @mcpTransportType.
  ///
  /// In en, this message translates to:
  /// **'Transport type'**
  String get mcpTransportType;

  /// No description provided for @mcpServerName.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get mcpServerName;

  /// No description provided for @mcpServerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an MCP server name'**
  String get mcpServerNameHint;

  /// No description provided for @mcpCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpCommand;

  /// No description provided for @mcpCommandExample.
  ///
  /// In en, this message translates to:
  /// **'Example: npx'**
  String get mcpCommandExample;

  /// No description provided for @mcpArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get mcpArguments;

  /// No description provided for @mcpArgumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate arguments with commas, for example: -y, @modelcontextprotocol/server-filesystem, /tmp'**
  String get mcpArgumentsHint;

  /// No description provided for @mcpSseUrlExample.
  ///
  /// In en, this message translates to:
  /// **'Example: http://localhost:3001/sse'**
  String get mcpSseUrlExample;

  /// No description provided for @mcpApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get mcpApiKey;

  /// No description provided for @mcpApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key (optional)'**
  String get mcpApiKeyHint;

  /// No description provided for @mcpShowKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get mcpShowKey;

  /// No description provided for @mcpHideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get mcpHideKey;

  /// No description provided for @mcpDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a description for this MCP server (optional)'**
  String get mcpDescriptionHint;

  /// No description provided for @mcpStdioDescription.
  ///
  /// In en, this message translates to:
  /// **'stdio starts a local child process as an MCP server and communicates through standard input/output. Recommended for local tools.'**
  String get mcpStdioDescription;

  /// No description provided for @mcpSseDescription.
  ///
  /// In en, this message translates to:
  /// **'SSE connects to a remote MCP server over HTTP SSE. Recommended for remote services.'**
  String get mcpSseDescription;

  /// No description provided for @mcpLocalStdio.
  ///
  /// In en, this message translates to:
  /// **'Local (stdio)'**
  String get mcpLocalStdio;

  /// No description provided for @mcpRemoteSse.
  ///
  /// In en, this message translates to:
  /// **'Remote (SSE)'**
  String get mcpRemoteSse;

  /// No description provided for @mcpSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get mcpSaving;

  /// No description provided for @providerTestSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'This test sends a real request to the selected service. MCP only calls the read-only tools/list method; HTTP and web search run one query. Todo reads the list by default; to protect current data, omit the todos parameter or set it to null.'**
  String get providerTestSafetyNote;

  /// No description provided for @providerDeleteConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete configuration'**
  String get providerDeleteConfigTitle;

  /// No description provided for @providerDeleteConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this provider configuration and all of its models?'**
  String get providerDeleteConfigConfirm;

  /// No description provided for @providerCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get providerCreateGroup;

  /// No description provided for @providerEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get providerEditGroup;

  /// No description provided for @providerGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get providerGroupName;

  /// No description provided for @providerGroupNameExists.
  ///
  /// In en, this message translates to:
  /// **'A group with this name already exists.'**
  String get providerGroupNameExists;

  /// No description provided for @providerDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get providerDeleteGroup;

  /// No description provided for @providerDeleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deleting “{groupName}” will move its configurations to “Other MCP services”.'**
  String providerDeleteGroupConfirm(String groupName);

  /// No description provided for @providerMoveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get providerMoveToGroup;

  /// No description provided for @providerUnnamed.
  ///
  /// In en, this message translates to:
  /// **'(Unnamed)'**
  String get providerUnnamed;

  /// No description provided for @providerHttpSearch.
  ///
  /// In en, this message translates to:
  /// **'HTTP search'**
  String get providerHttpSearch;

  /// No description provided for @providerHttpToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP tool: {url}'**
  String providerHttpToolSubtitle(String url);

  /// No description provided for @providerLocalStdioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local (stdio): {command}'**
  String providerLocalStdioSubtitle(String command);

  /// No description provided for @providerRemoteSseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remote (SSE): {url}'**
  String providerRemoteSseSubtitle(String url);

  /// No description provided for @providerServices.
  ///
  /// In en, this message translates to:
  /// **'Service configurations'**
  String get providerServices;

  /// No description provided for @providerServicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage remote connections, local stdio, and HTTP search by group'**
  String get providerServicesDescription;

  /// No description provided for @providerCreateGroupAction.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get providerCreateGroupAction;

  /// No description provided for @providerGroupEmpty.
  ///
  /// In en, this message translates to:
  /// **'This group has no configurations. Select “Add” to add an item.'**
  String get providerGroupEmpty;

  /// No description provided for @providerBuiltinTools.
  ///
  /// In en, this message translates to:
  /// **'Built-in tools'**
  String get providerBuiltinTools;

  /// No description provided for @providerBuiltinToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Stroom-provided local tool interfaces. Web search is listed in its service group.'**
  String get providerBuiltinToolsDescription;

  /// No description provided for @providerBuiltinToolInterface.
  ///
  /// In en, this message translates to:
  /// **'Built-in tool interface'**
  String get providerBuiltinToolInterface;

  /// No description provided for @providerViewInterface.
  ///
  /// In en, this message translates to:
  /// **'View interface'**
  String get providerViewInterface;

  /// No description provided for @providerConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get providerConfigTitle;

  /// No description provided for @providerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Provider not found'**
  String get providerNotFound;

  /// No description provided for @providerConfigurationHeading.
  ///
  /// In en, this message translates to:
  /// **'Provider configuration'**
  String get providerConfigurationHeading;

  /// No description provided for @providerBuiltinWebSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Built-in web search supports Google, Bing, and Baidu. Its model tool name is web_search.'**
  String get providerBuiltinWebSearchEmpty;

  /// No description provided for @providerNoConfigsAdd.
  ///
  /// In en, this message translates to:
  /// **'No provider configurations yet. Select “Add” to create one.'**
  String get providerNoConfigsAdd;

  /// No description provided for @providerNoHost.
  ///
  /// In en, this message translates to:
  /// **'(Host not set)'**
  String get providerNoHost;

  /// No description provided for @providerServicesAndTools.
  ///
  /// In en, this message translates to:
  /// **'Services and tools'**
  String get providerServicesAndTools;

  /// No description provided for @providerManageServicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage MCP servers, HTTP search, and Stroom built-in tools.'**
  String get providerManageServicesDescription;

  /// No description provided for @providerNoServices.
  ///
  /// In en, this message translates to:
  /// **'No service configurations yet'**
  String get providerNoServices;

  /// No description provided for @providerAddServiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Add an MCP service or HTTP search interface to use it in assistants.'**
  String get providerAddServiceDescription;

  /// No description provided for @providerAddService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get providerAddService;

  /// No description provided for @providerBuiltinBadge.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get providerBuiltinBadge;

  /// No description provided for @providerConnectivityTest.
  ///
  /// In en, this message translates to:
  /// **'Connectivity test'**
  String get providerConnectivityTest;

  /// No description provided for @providerMoveGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get providerMoveGroupTooltip;

  /// No description provided for @providerDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete configuration'**
  String get providerDeleteTooltip;

  /// No description provided for @providerGroupItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} one{# item} other{# items}}'**
  String providerGroupItemCount(num count);

  /// No description provided for @providerGroupActions.
  ///
  /// In en, this message translates to:
  /// **'Group actions'**
  String get providerGroupActions;

  /// No description provided for @providerEditGroupAction.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get providerEditGroupAction;

  /// No description provided for @providerDeleteGroupAction.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get providerDeleteGroupAction;

  /// No description provided for @providerAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get providerAddItem;

  /// No description provided for @providerMcpMasterLabel.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get providerMcpMasterLabel;

  /// No description provided for @providerMcpMasterDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls whether MCP servers and built-in search tools are available in assistants and chats.'**
  String get providerMcpMasterDescription;

  /// No description provided for @providerEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get providerEnabled;

  /// No description provided for @providerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get providerDisabled;

  /// No description provided for @providerEditSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit provider settings'**
  String get providerEditSettings;

  /// No description provided for @providerModelList.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get providerModelList;

  /// No description provided for @providerNoModels.
  ///
  /// In en, this message translates to:
  /// **'No models yet'**
  String get providerNoModels;

  /// No description provided for @providerDeleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get providerDeleteModel;

  /// No description provided for @providerDeleteModelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this model?'**
  String get providerDeleteModelConfirm;

  /// No description provided for @providerEditConfig.
  ///
  /// In en, this message translates to:
  /// **'Edit configuration'**
  String get providerEditConfig;

  /// No description provided for @providerCreateNamedConfig.
  ///
  /// In en, this message translates to:
  /// **'New {entryName} configuration'**
  String providerCreateNamedConfig(String entryName);

  /// No description provided for @toolHttpSearchType.
  ///
  /// In en, this message translates to:
  /// **'Connection type: HTTP search'**
  String get toolHttpSearchType;

  /// No description provided for @toolInterface.
  ///
  /// In en, this message translates to:
  /// **'Tool interface: {name}'**
  String toolInterface(String name);

  /// No description provided for @toolParameterDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Parameter definitions'**
  String get toolParameterDefinitions;

  /// No description provided for @toolHttpAddress.
  ///
  /// In en, this message translates to:
  /// **'HTTP endpoint URL'**
  String get toolHttpAddress;

  /// No description provided for @toolInvalidHttpUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS URL.'**
  String get toolInvalidHttpUrl;

  /// No description provided for @toolBuiltinType.
  ///
  /// In en, this message translates to:
  /// **'Connection type: Stroom built-in tool'**
  String get toolBuiltinType;

  /// No description provided for @toolBuiltinEnableHelp.
  ///
  /// In en, this message translates to:
  /// **'Enable this tool for an assistant in that assistant’s default tool settings.'**
  String get toolBuiltinEnableHelp;

  /// No description provided for @mcpSseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'SSE URL'**
  String get mcpSseUrlLabel;

  /// No description provided for @mcpUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get mcpUrlLabel;

  /// No description provided for @providerModelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID: {modelId}'**
  String providerModelId(String modelId);

  /// No description provided for @providerValueNotSet.
  ///
  /// In en, this message translates to:
  /// **'(Not set)'**
  String get providerValueNotSet;

  /// No description provided for @providerApiKeyInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key'**
  String get providerApiKeyInputHint;

  /// No description provided for @providerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider configuration'**
  String get providerSettingsTitle;

  /// No description provided for @providerBasicInfoTab.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get providerBasicInfoTab;

  /// No description provided for @providerParameterSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'Parameter settings'**
  String get providerParameterSettingsTab;

  /// No description provided for @providerOptionValuesReorderHelp.
  ///
  /// In en, this message translates to:
  /// **'Option values (hold the handle to drag and reorder)'**
  String get providerOptionValuesReorderHelp;

  /// No description provided for @providerOptionIndexLabel.
  ///
  /// In en, this message translates to:
  /// **'Option {index}'**
  String providerOptionIndexLabel(String index);

  /// No description provided for @providerOptionExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}'**
  String providerOptionExampleHint(String example);

  /// No description provided for @providerDeleteOptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete option'**
  String get providerDeleteOptionTooltip;

  /// No description provided for @providerAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get providerAddOption;

  /// No description provided for @providerAddCustomParam.
  ///
  /// In en, this message translates to:
  /// **'Add parameter'**
  String get providerAddCustomParam;

  /// No description provided for @providerNoCustomParams.
  ///
  /// In en, this message translates to:
  /// **'No custom parameters yet'**
  String get providerNoCustomParams;

  /// No description provided for @providerParamNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Parameter name'**
  String get providerParamNameLabel;

  /// No description provided for @providerParamDefaultValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Default parameter value'**
  String get providerParamDefaultValueLabel;

  /// No description provided for @providerBooleanParamNoValue.
  ///
  /// In en, this message translates to:
  /// **'Boolean parameters do not need a value. The chat panel provides an on/off toggle.'**
  String get providerBooleanParamNoValue;

  /// No description provided for @providerReasoningParamsHeading.
  ///
  /// In en, this message translates to:
  /// **'Reasoning parameters'**
  String get providerReasoningParamsHeading;

  /// No description provided for @providerReasoningSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'The reasoning toggle turns reasoning on or off in chat; you choose its parameter name and on/off values. You can configure one reasoning effort parameter with a required name and optional choices. If you enter only a name, the model configuration can provide the values. Use the buttons below to add other reasoning parameters. Parameter names support dot nesting, for example {parameterName} expands to {jsonExample}.'**
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  );

  /// No description provided for @providerAddReasoningParam.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning parameter'**
  String get providerAddReasoningParam;

  /// No description provided for @providerAddReasoningToggle.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning toggle'**
  String get providerAddReasoningToggle;

  /// No description provided for @providerReasoningToggle.
  ///
  /// In en, this message translates to:
  /// **'Reasoning toggle'**
  String get providerReasoningToggle;

  /// No description provided for @providerDeleteReasoningToggle.
  ///
  /// In en, this message translates to:
  /// **'Delete reasoning toggle'**
  String get providerDeleteReasoningToggle;

  /// No description provided for @providerParamNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {examples}'**
  String providerParamNameHint(String examples);

  /// No description provided for @providerReasoningBooleanHelp.
  ///
  /// In en, this message translates to:
  /// **'Boolean parameters do not need a value. The chat panel provides an on/off toggle.'**
  String get providerReasoningBooleanHelp;

  /// No description provided for @providerToggleOnValueLabel.
  ///
  /// In en, this message translates to:
  /// **'On value'**
  String get providerToggleOnValueLabel;

  /// No description provided for @providerToggleOffValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Off value'**
  String get providerToggleOffValueLabel;

  /// No description provided for @providerReasoningToggleSummary.
  ///
  /// In en, this message translates to:
  /// **'When reasoning is on, send “{onValue}”; when it is off, send “{offValue}”.'**
  String providerReasoningToggleSummary(String onValue, String offValue);

  /// No description provided for @providerAddReasoningEffort.
  ///
  /// In en, this message translates to:
  /// **'Add reasoning effort'**
  String get providerAddReasoningEffort;

  /// No description provided for @providerDeleteReasoningEffort.
  ///
  /// In en, this message translates to:
  /// **'Delete reasoning effort parameter'**
  String get providerDeleteReasoningEffort;

  /// No description provided for @providerReasoningEffortLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle before configuring reasoning effort.'**
  String get providerReasoningEffortLockedHint;

  /// No description provided for @providerJsonValueLabel.
  ///
  /// In en, this message translates to:
  /// **'JSON value'**
  String get providerJsonValueLabel;

  /// No description provided for @providerReasoningOptionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Option values (optional; if only the parameter name is entered, the model configuration supplies the value). Hold the handle to drag and reorder.'**
  String get providerReasoningOptionsHelp;

  /// No description provided for @providerParamNameNestedLabel.
  ///
  /// In en, this message translates to:
  /// **'Parameter name (supports dot nesting)'**
  String get providerParamNameNestedLabel;

  /// No description provided for @providerToggleEffortPrerequisite.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle before configuring reasoning effort.'**
  String get providerToggleEffortPrerequisite;

  /// No description provided for @providerToggleRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Complete the reasoning toggle first.'**
  String get providerToggleRequiredHint;

  /// No description provided for @providerDeleteCustomParam.
  ///
  /// In en, this message translates to:
  /// **'Delete parameter'**
  String get providerDeleteCustomParam;

  /// No description provided for @modelSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Model saved'**
  String get modelSaveSuccess;

  /// No description provided for @modelSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get modelSaving;

  /// No description provided for @modelOriginalError.
  ///
  /// In en, this message translates to:
  /// **'Original error: {error}'**
  String modelOriginalError(String error);

  /// No description provided for @paramTypeStringLabel.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get paramTypeStringLabel;

  /// No description provided for @paramTypeNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get paramTypeNumberLabel;

  /// No description provided for @paramTypeBooleanLabel.
  ///
  /// In en, this message translates to:
  /// **'Boolean'**
  String get paramTypeBooleanLabel;

  /// No description provided for @paramTypeJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get paramTypeJsonLabel;

  /// No description provided for @paramTypeStringHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. cheerful'**
  String get paramTypeStringHint;

  /// No description provided for @paramTypeNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0.8'**
  String get paramTypeNumberHint;

  /// No description provided for @paramTypeBooleanHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. true'**
  String get paramTypeBooleanHint;

  /// No description provided for @paramTypeJsonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. '**
  String get paramTypeJsonHint;

  /// No description provided for @ankiPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Anki flashcards'**
  String get ankiPageTitle;

  /// No description provided for @ankiStatsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Study statistics'**
  String get ankiStatsTooltip;

  /// No description provided for @ankiBrowseCardsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Browse cards'**
  String get ankiBrowseCardsTooltip;

  /// No description provided for @ankiSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'AnkiWeb sync'**
  String get ankiSyncTooltip;

  /// No description provided for @ankiNewDeckTooltip.
  ///
  /// In en, this message translates to:
  /// **'New deck'**
  String get ankiNewDeckTooltip;

  /// No description provided for @ankiDeckLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load decks: {error}'**
  String ankiDeckLoadError(String error);

  /// No description provided for @ankiEmptyDecksTitle.
  ///
  /// In en, this message translates to:
  /// **'No decks yet'**
  String get ankiEmptyDecksTitle;

  /// No description provided for @ankiEmptyDecksDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a deck to start studying'**
  String get ankiEmptyDecksDescription;

  /// No description provided for @ankiNewDeckTitle.
  ///
  /// In en, this message translates to:
  /// **'New deck'**
  String get ankiNewDeckTitle;

  /// No description provided for @ankiDeckNameHint.
  ///
  /// In en, this message translates to:
  /// **'Deck name'**
  String get ankiDeckNameHint;

  /// No description provided for @ankiCreateDeck.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get ankiCreateDeck;

  /// No description provided for @ankiRenameDeck.
  ///
  /// In en, this message translates to:
  /// **'Rename deck'**
  String get ankiRenameDeck;

  /// No description provided for @ankiConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ankiConfirm;

  /// No description provided for @ankiDeleteDeckTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete deck'**
  String get ankiDeleteDeckTitle;

  /// No description provided for @ankiDeleteDeckConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete “{deckName}” and all its cards?'**
  String ankiDeleteDeckConfirmation(String deckName);

  /// No description provided for @ankiAddCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get ankiAddCardTitle;

  /// No description provided for @ankiNoteTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Note type'**
  String get ankiNoteTypeLabel;

  /// No description provided for @ankiClozeTextHint.
  ///
  /// In en, this message translates to:
  /// **'Text (mark deletions with {clozeSyntax})'**
  String ankiClozeTextHint(String clozeSyntax);

  /// No description provided for @ankiFrontQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Front (question)'**
  String get ankiFrontQuestionHint;

  /// No description provided for @ankiBackExtraLabel.
  ///
  /// In en, this message translates to:
  /// **'Back / extra'**
  String get ankiBackExtraLabel;

  /// No description provided for @ankiTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags (separated by spaces)'**
  String get ankiTagsLabel;

  /// No description provided for @ankiTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Example: math physics'**
  String get ankiTagsHint;

  /// No description provided for @ankiAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ankiAdd;

  /// No description provided for @ankiStatNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get ankiStatNew;

  /// No description provided for @ankiStatLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get ankiStatLearning;

  /// No description provided for @ankiStatReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get ankiStatReview;

  /// No description provided for @ankiAddCardAction.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get ankiAddCardAction;

  /// No description provided for @ankiRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get ankiRenameAction;

  /// No description provided for @ankiDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get ankiDeleteAction;

  /// No description provided for @ankiNoCardContent.
  ///
  /// In en, this message translates to:
  /// **'No card content'**
  String get ankiNoCardContent;

  /// No description provided for @ankiStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get ankiStudy;

  /// No description provided for @ankiWhiteboardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard'**
  String get ankiWhiteboardTooltip;

  /// No description provided for @ankiFrontLabel.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get ankiFrontLabel;

  /// No description provided for @ankiBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get ankiBackLabel;

  /// No description provided for @ankiShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get ankiShowAnswer;

  /// No description provided for @ankiRatingAgain.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get ankiRatingAgain;

  /// No description provided for @ankiRatingHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get ankiRatingHard;

  /// No description provided for @ankiRatingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ankiRatingGood;

  /// No description provided for @ankiRatingEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get ankiRatingEasy;

  /// No description provided for @ankiNoCardsToStudy.
  ///
  /// In en, this message translates to:
  /// **'No cards to study right now'**
  String get ankiNoCardsToStudy;

  /// No description provided for @ankiNoCardsHint.
  ///
  /// In en, this message translates to:
  /// **'Add new cards or come back later'**
  String get ankiNoCardsHint;

  /// No description provided for @ankiBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get ankiBack;

  /// No description provided for @ankiSyncPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Anki sync'**
  String get ankiSyncPageTitle;

  /// No description provided for @ankiSyncChooseMode.
  ///
  /// In en, this message translates to:
  /// **'Choose a sync mode'**
  String get ankiSyncChooseMode;

  /// No description provided for @ankiSyncModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Login status is stored separately for each service. Switching modes does not merge or overwrite data.'**
  String get ankiSyncModeHelp;

  /// No description provided for @ankiSyncSelfHostedMode.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted server'**
  String get ankiSyncSelfHostedMode;

  /// No description provided for @ankiSyncServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get ankiSyncServerAddress;

  /// No description provided for @ankiSyncServerHelp.
  ///
  /// In en, this message translates to:
  /// **'Remote self-hosted servers must use HTTPS; HTTP is allowed for local addresses. The server must support Anki sync v10, and certificate verification is enabled by default.'**
  String get ankiSyncServerHelp;

  /// No description provided for @ankiSyncCustomCaTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom CA certificate (optional)'**
  String get ankiSyncCustomCaTitle;

  /// No description provided for @ankiSyncCustomCaHelp.
  ///
  /// In en, this message translates to:
  /// **'Only enter this when the server uses a self-signed certificate'**
  String get ankiSyncCustomCaHelp;

  /// No description provided for @ankiSyncOfficialHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the official AnkiWeb sync service. Your password is sent only when logging in and is not stored in Stroom.'**
  String get ankiSyncOfficialHelp;

  /// No description provided for @ankiSyncConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to {service}'**
  String ankiSyncConnected(String service);

  /// No description provided for @ankiSyncNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to {service}'**
  String ankiSyncNotConnected(String service);

  /// No description provided for @ankiSyncLoginForService.
  ///
  /// In en, this message translates to:
  /// **'Log in to {service}'**
  String ankiSyncLoginForService(String service);

  /// No description provided for @ankiSyncCheckServerStatus.
  ///
  /// In en, this message translates to:
  /// **'Check server status'**
  String get ankiSyncCheckServerStatus;

  /// No description provided for @ankiSyncLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get ankiSyncLogout;

  /// No description provided for @ankiSyncBothWays.
  ///
  /// In en, this message translates to:
  /// **'Two-way sync'**
  String get ankiSyncBothWays;

  /// No description provided for @ankiSyncOverwriteServer.
  ///
  /// In en, this message translates to:
  /// **'Replace server data with local data'**
  String get ankiSyncOverwriteServer;

  /// No description provided for @ankiSyncReplaceLocal.
  ///
  /// In en, this message translates to:
  /// **'Replace local data with server data'**
  String get ankiSyncReplaceLocal;

  /// No description provided for @ankiSyncHelp.
  ///
  /// In en, this message translates to:
  /// **'Two-way sync merges incremental collection changes and transfers media files. If the schema version differs, choose a full upload or download. A failed full download will try to restore the original collection and media directory.'**
  String get ankiSyncHelp;

  /// No description provided for @ankiSyncStatusRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored the securely saved login session'**
  String get ankiSyncStatusRestored;

  /// No description provided for @ankiSyncStatusReadSavedSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the saved login session. Please log in again.'**
  String get ankiSyncStatusReadSavedSessionFailed;

  /// No description provided for @ankiSyncInvalidServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server address must be an HTTPS URL. HTTP is allowed only for a local loopback address. User information and query parameters are not allowed.'**
  String get ankiSyncInvalidServerUrl;

  /// No description provided for @ankiSyncStatusSettingsNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings not saved: {error}'**
  String ankiSyncStatusSettingsNotSaved(String error);

  /// No description provided for @ankiSyncStatusServerAddressChanged.
  ///
  /// In en, this message translates to:
  /// **'Server address changed. Please log in again to continue.'**
  String get ankiSyncStatusServerAddressChanged;

  /// No description provided for @ankiSyncStatusVerifyingLogin.
  ///
  /// In en, this message translates to:
  /// **'Verifying login…'**
  String get ankiSyncStatusVerifyingLogin;

  /// No description provided for @ankiSyncStatusLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful. Your password was not saved; the sync key was encrypted and saved.'**
  String get ankiSyncStatusLoginSuccess;

  /// No description provided for @ankiSyncStatusLoginSuccessNoSave.
  ///
  /// In en, this message translates to:
  /// **'Login successful, but the sync key could not be stored securely. You will need to log in again after closing this page.'**
  String get ankiSyncStatusLoginSuccessNoSave;

  /// No description provided for @ankiSyncStatusLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String ankiSyncStatusLoginFailed(String error);

  /// No description provided for @ankiSyncLoginAnkiWeb.
  ///
  /// In en, this message translates to:
  /// **'Log in to AnkiWeb'**
  String get ankiSyncLoginAnkiWeb;

  /// No description provided for @ankiSyncLoginSelfHosted.
  ///
  /// In en, this message translates to:
  /// **'Log in to self-hosted server'**
  String get ankiSyncLoginSelfHosted;

  /// No description provided for @ankiSyncEmailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email / username'**
  String get ankiSyncEmailOrUsername;

  /// No description provided for @ankiSyncEmailOrUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an email or username'**
  String get ankiSyncEmailOrUsernameRequired;

  /// No description provided for @ankiSyncPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get ankiSyncPassword;

  /// No description provided for @ankiSyncPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get ankiSyncPasswordRequired;

  /// No description provided for @ankiSyncLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get ankiSyncLogin;

  /// No description provided for @ankiSyncStatusPreparingServerSettings.
  ///
  /// In en, this message translates to:
  /// **'Preparing server settings…'**
  String get ankiSyncStatusPreparingServerSettings;

  /// No description provided for @ankiSyncStatusReadingCollection.
  ///
  /// In en, this message translates to:
  /// **'Reading server collection status…'**
  String get ankiSyncStatusReadingCollection;

  /// No description provided for @ankiSyncStatusConnectedCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Connected. The server collection is empty.'**
  String get ankiSyncStatusConnectedCollectionEmpty;

  /// No description provided for @ankiSyncStatusConnectedStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Connected. Server status was read.'**
  String get ankiSyncStatusConnectedStatusRead;

  /// No description provided for @ankiSyncStatusUpgradeClient.
  ///
  /// In en, this message translates to:
  /// **'This server requires a newer sync client.'**
  String get ankiSyncStatusUpgradeClient;

  /// No description provided for @ankiSyncStatusCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Status check failed: {error}'**
  String ankiSyncStatusCheckFailed(String error);

  /// No description provided for @ankiSyncStatusPreparingUpload.
  ///
  /// In en, this message translates to:
  /// **'Preparing upload settings…'**
  String get ankiSyncStatusPreparingUpload;

  /// No description provided for @ankiSyncOverwriteServerConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the server collection with the local one?'**
  String get ankiSyncOverwriteServerConfirmTitle;

  /// No description provided for @ankiSyncOverwriteServerConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The server collection will be fully replaced with local data. Stroom will first keep a backup of the local database.\n\nMedia files will still be synchronized in both directions according to the server media list.'**
  String get ankiSyncOverwriteServerConfirmMessage;

  /// No description provided for @ankiSyncOverwriteServerAction.
  ///
  /// In en, this message translates to:
  /// **'Replace server collection'**
  String get ankiSyncOverwriteServerAction;

  /// No description provided for @ankiSyncStatusBackingUpUploading.
  ///
  /// In en, this message translates to:
  /// **'Backing up and uploading collection…'**
  String get ankiSyncStatusBackingUpUploading;

  /// No description provided for @ankiSyncStatusUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'The server accepted the local collection. Media sync completed: uploaded {uploaded} files, downloaded {downloaded}, deleted {deleted}.{backup} Please check server status again.'**
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  );

  /// No description provided for @ankiSyncStatusBackupPath.
  ///
  /// In en, this message translates to:
  /// **'\nLocal backup: {path}'**
  String ankiSyncStatusBackupPath(String path);

  /// No description provided for @ankiSyncStatusMediaSyncIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The server collection was replaced, but media sync did not finish: '**
  String get ankiSyncStatusMediaSyncIncomplete;

  /// No description provided for @ankiSyncStatusUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: '**
  String get ankiSyncStatusUploadFailed;

  /// No description provided for @ankiSyncStatusPreparingDownload.
  ///
  /// In en, this message translates to:
  /// **'Preparing download settings…'**
  String get ankiSyncStatusPreparingDownload;

  /// No description provided for @ankiSyncReplaceLocalConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the local collection with the server one?'**
  String get ankiSyncReplaceLocalConfirmTitle;

  /// No description provided for @ankiSyncReplaceLocalConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The local collection will be replaced with server data. Stroom will first keep a backup of the local database.\n\nServer media will replace local media and missing files will be downloaded. If any step fails or the app exits in the middle, Stroom will restore the local collection and media before opening the decks next time.'**
  String get ankiSyncReplaceLocalConfirmMessage;

  /// No description provided for @ankiSyncReplaceLocalAction.
  ///
  /// In en, this message translates to:
  /// **'Replace local data'**
  String get ankiSyncReplaceLocalAction;

  /// No description provided for @ankiSyncStatusDownloadingValidating.
  ///
  /// In en, this message translates to:
  /// **'Downloading and validating collection…'**
  String get ankiSyncStatusDownloadingValidating;

  /// No description provided for @ankiSyncStatusDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'The local collection was replaced and passed the SQLite check. Media sync completed: downloaded {downloaded} files, uploaded {uploaded}, deleted {deleted}.{backup} Please check server status again.'**
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  );

  /// No description provided for @ankiSyncStatusDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String ankiSyncStatusDownloadFailed(String error);

  /// No description provided for @ankiSyncStatusPreparingSync.
  ///
  /// In en, this message translates to:
  /// **'Preparing sync…'**
  String get ankiSyncStatusPreparingSync;

  /// No description provided for @ankiSyncStatusMergingChanges.
  ///
  /// In en, this message translates to:
  /// **'Merging collection changes…'**
  String get ankiSyncStatusMergingChanges;

  /// No description provided for @ankiSyncStatusMergeCompleteSyncMedia.
  ///
  /// In en, this message translates to:
  /// **'Collection changes merged. Syncing media files…'**
  String get ankiSyncStatusMergeCompleteSyncMedia;

  /// No description provided for @ankiSyncStatusChangedNotes.
  ///
  /// In en, this message translates to:
  /// **'{notes} notes, {cards} cards, and {reviews} review records added or updated'**
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews);

  /// No description provided for @ankiSyncStatusNoCollectionChanges.
  ///
  /// In en, this message translates to:
  /// **'No collection changes to merge'**
  String get ankiSyncStatusNoCollectionChanges;

  /// No description provided for @ankiSyncStatusTwoWayComplete.
  ///
  /// In en, this message translates to:
  /// **'Two-way sync complete: {collection}; media uploaded {uploaded}, downloaded {downloaded}, deleted {deleted}.'**
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  );

  /// No description provided for @ankiSyncStatusCollectionMergedMediaIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Collection changes were merged, but media sync did not finish: '**
  String get ankiSyncStatusCollectionMergedMediaIncomplete;

  /// No description provided for @ankiSyncStatusSyncIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Sync did not finish: '**
  String get ankiSyncStatusSyncIncomplete;

  /// No description provided for @ankiSyncStatusClearingLogin.
  ///
  /// In en, this message translates to:
  /// **'Clearing login session…'**
  String get ankiSyncStatusClearingLogin;

  /// No description provided for @ankiSyncStatusLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Logged out. The sync key was deleted from secure storage.'**
  String get ankiSyncStatusLoggedOut;

  /// No description provided for @ankiSyncStatusClearLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the saved login session'**
  String get ankiSyncStatusClearLoginFailed;

  /// No description provided for @ankiSyncStatusOperationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Operation did not finish. Check secure storage, network, and server address.'**
  String get ankiSyncStatusOperationIncomplete;

  /// No description provided for @ankiSyncUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get ankiSyncUnknown;

  /// No description provided for @ankiSyncServerCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Server collection is empty'**
  String get ankiSyncServerCollectionEmpty;

  /// No description provided for @ankiSyncServerCollectionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Server collection is available'**
  String get ankiSyncServerCollectionAvailable;

  /// No description provided for @ankiSyncSchemaStatus.
  ///
  /// In en, this message translates to:
  /// **'Schema version {schema} · USN {usn} · Modified {modified}'**
  String ankiSyncSchemaStatus(int schema, int usn, String modified);

  /// No description provided for @asrPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Transcription'**
  String get asrPageTitle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @asrModel.
  ///
  /// In en, this message translates to:
  /// **'Recognition model'**
  String get asrModel;

  /// No description provided for @reselectModel.
  ///
  /// In en, this message translates to:
  /// **'Please select a model again'**
  String get reselectModel;

  /// No description provided for @selectAsrModel.
  ///
  /// In en, this message translates to:
  /// **'Select a recognition model'**
  String get selectAsrModel;

  /// No description provided for @enterPublicAudioUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a public audio URL'**
  String get enterPublicAudioUrl;

  /// No description provided for @recordingSelection.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get recordingSelection;

  /// No description provided for @audioFiles.
  ///
  /// In en, this message translates to:
  /// **'Audio files'**
  String get audioFiles;

  /// No description provided for @noAudioSelected.
  ///
  /// In en, this message translates to:
  /// **'No audio files selected'**
  String get noAudioSelected;

  /// No description provided for @supportedAudioFormats.
  ///
  /// In en, this message translates to:
  /// **'Supports common audio formats such as WAV, MP3, M4A, and OGG'**
  String get supportedAudioFormats;

  /// No description provided for @asrSelectedAudioCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No audio files selected} one{# audio file selected} other{# audio files selected}}'**
  String asrSelectedAudioCount(int count);

  /// No description provided for @asrSelectedAudioCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# audio file selected} other{# audio files selected}}'**
  String asrSelectedAudioCountShort(int count);

  /// No description provided for @asrReselect.
  ///
  /// In en, this message translates to:
  /// **'Select again'**
  String get asrReselect;

  /// No description provided for @asrUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL | Public link'**
  String get asrUrlLabel;

  /// No description provided for @asrErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'View error details'**
  String get asrErrorDetails;

  /// No description provided for @asrResultSaved.
  ///
  /// In en, this message translates to:
  /// **'Transcription result saved'**
  String get asrResultSaved;

  /// No description provided for @asrWorking.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get asrWorking;

  /// No description provided for @asrStart.
  ///
  /// In en, this message translates to:
  /// **'Start transcription'**
  String get asrStart;

  /// No description provided for @saveTo.
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get saveTo;

  /// No description provided for @rootFolder.
  ///
  /// In en, this message translates to:
  /// **'Root folder'**
  String get rootFolder;

  /// No description provided for @chooseSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get chooseSaveFolder;

  /// No description provided for @linkAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'This link is already in the list'**
  String get linkAlreadyAdded;

  /// No description provided for @chooseAudioSource.
  ///
  /// In en, this message translates to:
  /// **'Choose an audio source'**
  String get chooseAudioSource;

  /// No description provided for @inAppRecordings.
  ///
  /// In en, this message translates to:
  /// **'In-app recordings'**
  String get inAppRecordings;

  /// No description provided for @chooseGeneratedRecordings.
  ///
  /// In en, this message translates to:
  /// **'Choose from generated recordings'**
  String get chooseGeneratedRecordings;

  /// No description provided for @systemAudioFiles.
  ///
  /// In en, this message translates to:
  /// **'System audio files'**
  String get systemAudioFiles;

  /// No description provided for @chooseDeviceAudioFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files from your device'**
  String get chooseDeviceAudioFiles;

  /// No description provided for @cannotReadAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the audio file'**
  String get cannotReadAudioFile;

  /// No description provided for @chooseAudioFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not select audio file: {details}'**
  String chooseAudioFileFailed(String details);

  /// No description provided for @chooseInAppRecording.
  ///
  /// In en, this message translates to:
  /// **'Choose in-app recordings'**
  String get chooseInAppRecording;

  /// No description provided for @noRecordings.
  ///
  /// In en, this message translates to:
  /// **'No recordings'**
  String get noRecordings;

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{# sec} other{# secs}}'**
  String durationSeconds(int seconds);

  /// No description provided for @asrNeedsProvider.
  ///
  /// In en, this message translates to:
  /// **'Configure an audio transcription provider and model in Settings first'**
  String get asrNeedsProvider;

  /// No description provided for @asrModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The original recognition model is unavailable or cannot be verified. Please select a model again.'**
  String get asrModelUnavailable;

  /// No description provided for @asrUrlProviderRemoveFiles.
  ///
  /// In en, this message translates to:
  /// **'This provider uploads audio by URL. Remove local audio files and try again.'**
  String get asrUrlProviderRemoveFiles;

  /// No description provided for @asrFileProviderRemoveUrls.
  ///
  /// In en, this message translates to:
  /// **'This provider uploads audio files and does not support transcription by link. Remove links and try again.'**
  String get asrFileProviderRemoveUrls;

  /// No description provided for @asrTaskStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the task: {details}'**
  String asrTaskStartFailed(String details);

  /// No description provided for @asrInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL. It must start with http:// or https://'**
  String get asrInvalidUrl;

  /// No description provided for @asrEnterAudioUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter an audio URL'**
  String get asrEnterAudioUrl;

  /// No description provided for @asrUrlProviderHelp.
  ///
  /// In en, this message translates to:
  /// **'This provider uploads audio by URL. Enter a public audio URL (http/https).'**
  String get asrUrlProviderHelp;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @ttsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get ttsPageTitle;

  /// No description provided for @ttsAudioImportedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# audio file imported} other{# audio files imported}}'**
  String ttsAudioImportedCount(int count);

  /// No description provided for @ttsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {details}'**
  String ttsImportFailed(String details);

  /// No description provided for @ttsFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read file data'**
  String get ttsFileReadFailed;

  /// No description provided for @ttsExportAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Export audio file'**
  String get ttsExportAudioFile;

  /// No description provided for @ttsExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported to: {path}'**
  String ttsExportedTo(String path);

  /// No description provided for @ttsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {details}'**
  String ttsExportFailed(String details);

  /// No description provided for @ttsConfirmRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Confirm regeneration'**
  String get ttsConfirmRegenerate;

  /// No description provided for @ttsRegenerateConfirmFile.
  ///
  /// In en, this message translates to:
  /// **'Regenerate audio “{fileName}”?'**
  String ttsRegenerateConfirmFile(String fileName);

  /// No description provided for @ttsRegenerateOverwrite.
  ///
  /// In en, this message translates to:
  /// **'The original audio file will be replaced after regeneration.'**
  String get ttsRegenerateOverwrite;

  /// No description provided for @ttsRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate audio'**
  String get ttsRegenerate;

  /// No description provided for @ttsCopiedFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy: {details}'**
  String ttsCopiedFailed(String details);

  /// No description provided for @ttsChooseExportFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose export folder'**
  String get ttsChooseExportFolder;

  /// No description provided for @ttsExportAudio.
  ///
  /// In en, this message translates to:
  /// **'Export audio'**
  String get ttsExportAudio;

  /// No description provided for @ttsExportedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# file exported} other{# files exported}}'**
  String ttsExportedCount(int count);

  /// No description provided for @ttsFolderExport.
  ///
  /// In en, this message translates to:
  /// **'Export folder'**
  String get ttsFolderExport;

  /// No description provided for @ttsWebFolderExportHelp.
  ///
  /// In en, this message translates to:
  /// **'Your browser cannot choose an export folder. A ZIP file will be downloaded with the folder structure preserved.'**
  String get ttsWebFolderExportHelp;

  /// No description provided for @ttsDownloadZip.
  ///
  /// In en, this message translates to:
  /// **'Download ZIP file'**
  String get ttsDownloadZip;

  /// No description provided for @ttsExportAudioFolder.
  ///
  /// In en, this message translates to:
  /// **'Export audio folder'**
  String get ttsExportAudioFolder;

  /// No description provided for @ttsRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get ttsRecord;

  /// No description provided for @ttsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get ttsImport;

  /// No description provided for @ttsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get ttsPlay;

  /// No description provided for @ttsExportLocal.
  ///
  /// In en, this message translates to:
  /// **'Export to device'**
  String get ttsExportLocal;

  /// No description provided for @ttsRegenerateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get ttsRegenerateQuestion;

  /// No description provided for @ttsNeedsProvider.
  ///
  /// In en, this message translates to:
  /// **'Configure a speech synthesis provider and model in Settings first'**
  String get ttsNeedsProvider;

  /// No description provided for @ttsAddedToTasks.
  ///
  /// In en, this message translates to:
  /// **'Added to the task list. Generating in the background…'**
  String get ttsAddedToTasks;

  /// No description provided for @ttsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Synthesis'**
  String get ttsCreateTitle;

  /// No description provided for @ttsOriginalTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording title'**
  String get ttsOriginalTitle;

  /// No description provided for @ttsUseOriginalTitle.
  ///
  /// In en, this message translates to:
  /// **'Use original title'**
  String get ttsUseOriginalTitle;

  /// No description provided for @ttsAudioFileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Saved audio file name (optional)'**
  String get ttsAudioFileNameHint;

  /// No description provided for @ttsTextToConvert.
  ///
  /// In en, this message translates to:
  /// **'Text to convert'**
  String get ttsTextToConvert;

  /// No description provided for @ttsSpeechContent.
  ///
  /// In en, this message translates to:
  /// **'Speech content'**
  String get ttsSpeechContent;

  /// No description provided for @ttsTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text to convert to speech…'**
  String get ttsTextHint;

  /// No description provided for @ttsFullscreenEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit in full screen'**
  String get ttsFullscreenEdit;

  /// No description provided for @ttsTextLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'Text exceeds the limit (maximum {limit} characters)'**
  String ttsTextLimitWarning(int limit);

  /// No description provided for @ttsSynthesisConfig.
  ///
  /// In en, this message translates to:
  /// **'Synthesis settings'**
  String get ttsSynthesisConfig;

  /// No description provided for @ttsVoiceAndSoundHelp.
  ///
  /// In en, this message translates to:
  /// **'Adjust the voice and sound'**
  String get ttsVoiceAndSoundHelp;

  /// No description provided for @ttsProviderSettingsLead.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get ttsProviderSettingsLead;

  /// No description provided for @ttsProviderSettings.
  ///
  /// In en, this message translates to:
  /// **'TTS provider settings'**
  String get ttsProviderSettings;

  /// No description provided for @ttsProviderSettingsTail.
  ///
  /// In en, this message translates to:
  /// **'to configure more parameters'**
  String get ttsProviderSettingsTail;

  /// No description provided for @ttsEditText.
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get ttsEditText;

  /// No description provided for @ttsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get ttsClose;

  /// No description provided for @ttsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ttsVoice;

  /// No description provided for @ttsSelectVoice.
  ///
  /// In en, this message translates to:
  /// **'Select a voice'**
  String get ttsSelectVoice;

  /// No description provided for @ttsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ttsSpeed;

  /// No description provided for @ttsNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get ttsNormal;

  /// No description provided for @ttsVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ttsVolume;

  /// No description provided for @ttsInstruction.
  ///
  /// In en, this message translates to:
  /// **'Speaking style instruction'**
  String get ttsInstruction;

  /// No description provided for @ttsInstructionHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Speak in a cheerful and excited tone'**
  String get ttsInstructionHint;

  /// No description provided for @ttsCustomParams.
  ///
  /// In en, this message translates to:
  /// **'Custom parameters'**
  String get ttsCustomParams;

  /// No description provided for @ttsDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'Default: {value}'**
  String ttsDefaultValue(Object value);

  /// No description provided for @ttsGenerateRecording.
  ///
  /// In en, this message translates to:
  /// **'Generate recording'**
  String get ttsGenerateRecording;

  /// No description provided for @ttsSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as: {path}/{name}.{format}'**
  String ttsSaveAs(String path, String name, String format);

  /// No description provided for @ttsChooseSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get ttsChooseSaveFolder;

  /// No description provided for @ttsFillTextError.
  ///
  /// In en, this message translates to:
  /// **'Enter text to convert'**
  String get ttsFillTextError;

  /// No description provided for @voiceBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Add voices in bulk'**
  String get voiceBatchTitle;

  /// No description provided for @voiceBatchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add selected voices'**
  String get voiceBatchConfirm;

  /// No description provided for @voiceBatchSeparator.
  ///
  /// In en, this message translates to:
  /// **'Separator:'**
  String get voiceBatchSeparator;

  /// No description provided for @voiceBatchCustomSeparatorHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a custom separator'**
  String get voiceBatchCustomSeparatorHint;

  /// No description provided for @voiceBatchFieldOrder.
  ///
  /// In en, this message translates to:
  /// **'Field order:'**
  String get voiceBatchFieldOrder;

  /// No description provided for @voiceBatchNameThenId.
  ///
  /// In en, this message translates to:
  /// **'1st = name, 2nd = ID'**
  String get voiceBatchNameThenId;

  /// No description provided for @voiceBatchIdThenName.
  ///
  /// In en, this message translates to:
  /// **'1st = ID, 2nd = name'**
  String get voiceBatchIdThenName;

  /// No description provided for @voiceBatchColumnChoice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Detected 1 column. Choose the starting column for the name/ID:} other{Detected # columns. Choose the starting column for the name/ID:}}'**
  String voiceBatchColumnChoice(int count);

  /// No description provided for @voiceBatchColumn.
  ///
  /// In en, this message translates to:
  /// **'Column {index}: {sample}'**
  String voiceBatchColumn(int index, String sample);

  /// No description provided for @voiceBatchSingleColumn.
  ///
  /// In en, this message translates to:
  /// **'One column detected. All values will be used as IDs (name = ID).'**
  String get voiceBatchSingleColumn;

  /// No description provided for @voiceBatchInputHint.
  ///
  /// In en, this message translates to:
  /// **'Separate name and ID with Tab, commas, semicolons, or vertical bars (one pair per line)'**
  String get voiceBatchInputHint;

  /// No description provided for @voiceBatchNoPreview.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview'**
  String get voiceBatchNoPreview;

  /// No description provided for @voiceName.
  ///
  /// In en, this message translates to:
  /// **'Voice name'**
  String get voiceName;

  /// No description provided for @voiceId.
  ///
  /// In en, this message translates to:
  /// **'Voice ID'**
  String get voiceId;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @voiceNew.
  ///
  /// In en, this message translates to:
  /// **'✅ New'**
  String get voiceNew;

  /// No description provided for @voiceIdExists.
  ///
  /// In en, this message translates to:
  /// **'⚠️ ID already exists'**
  String get voiceIdExists;

  /// No description provided for @voiceFormatError.
  ///
  /// In en, this message translates to:
  /// **'❌ Format error{details}'**
  String voiceFormatError(String details);

  /// No description provided for @voiceDuplicateIds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# duplicate ID found: {ids}} other{# duplicate IDs found: {ids}}}'**
  String voiceDuplicateIds(int count, String ids);

  /// No description provided for @voiceInsufficientColumnData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data in the selected columns'**
  String get voiceInsufficientColumnData;

  /// No description provided for @voiceCustomSeparator.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get voiceCustomSeparator;

  /// No description provided for @voiceCommaSeparator.
  ///
  /// In en, this message translates to:
  /// **'Comma (,)'**
  String get voiceCommaSeparator;

  /// No description provided for @voiceSemicolonSeparator.
  ///
  /// In en, this message translates to:
  /// **'Semicolon (;)'**
  String get voiceSemicolonSeparator;

  /// No description provided for @voicePipeSeparator.
  ///
  /// In en, this message translates to:
  /// **'Vertical bar (|)'**
  String get voicePipeSeparator;

  /// No description provided for @voiceTabSeparator.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get voiceTabSeparator;

  /// No description provided for @voiceEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit voices'**
  String get voiceEditorTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @voiceAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get voiceAddRow;

  /// No description provided for @voiceBatchAdd.
  ///
  /// In en, this message translates to:
  /// **'Add in bulk'**
  String get voiceBatchAdd;

  /// No description provided for @voiceNoneAdd.
  ///
  /// In en, this message translates to:
  /// **'No voices yet. Add one to get started.'**
  String get voiceNoneAdd;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @voiceDuplicateResolution.
  ///
  /// In en, this message translates to:
  /// **'The following voice IDs are duplicated. Choose how to handle each one:'**
  String get voiceDuplicateResolution;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @voiceDuplicatesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# duplicate remains} other{# duplicates remain}}'**
  String voiceDuplicatesRemaining(int count);

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get continueEditing;

  /// No description provided for @asrRetryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Retry audio is incomplete. Clear the list and select all audio again.'**
  String get asrRetryIncomplete;

  /// No description provided for @asrRetryAudioUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Retry audio data could not be read. Select the audio again: {details}'**
  String asrRetryAudioUnreadable(String details);

  /// No description provided for @asrLegacyRetryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Legacy retry audio is unavailable. Select the audio again.'**
  String get asrLegacyRetryUnavailable;

  /// No description provided for @asrRetryDataUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Retry data could not be read. Select the audio again.'**
  String get asrRetryDataUnreadable;

  /// No description provided for @ttsSynthesisModel.
  ///
  /// In en, this message translates to:
  /// **'Synthesis model'**
  String get ttsSynthesisModel;

  /// No description provided for @asrRetryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Retry audio is unavailable. Select the audio again.'**
  String get asrRetryUnavailable;

  /// No description provided for @chatRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get chatRequest;

  /// No description provided for @chatResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get chatResponse;

  /// No description provided for @chatNoErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get chatNoErrorDetails;

  /// No description provided for @ttsBackgroundInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Synthesis interrupted because the app entered the background'**
  String get ttsBackgroundInterrupted;

  /// No description provided for @ttsAppExitedInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Synthesis interrupted because the app exited'**
  String get ttsAppExitedInterrupted;

  /// No description provided for @ttsInstructionDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe tone, emotion, speed, accent, and other qualities in natural language. The model adjusts the synthesized voice accordingly.'**
  String get ttsInstructionDescription;
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
