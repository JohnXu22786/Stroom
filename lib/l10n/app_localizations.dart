Warning: truncated output (original token count: 128682)
Total output lines: 15534

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

  /// No description pr…108682 tokens truncated… ///
  /// In en, this message translates to:
  /// **'Keep the app in the foreground'**
  String get platformTutorialIosStep6Title;

  /// No description provided for @platformTutorialIosStep6Description.
  ///
  /// In en, this message translates to:
  /// **'On versions earlier than iOS 26, apps have limited background time. For long-running tasks, keep Stroom in the foreground or return to it periodically to extend that time.'**
  String get platformTutorialIosStep6Description;

  /// No description provided for @platformTutorialWindowsStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Minimize when closing the window'**
  String get platformTutorialWindowsStep1Title;

  /// No description provided for @platformTutorialWindowsStep1Description.
  ///
  /// In en, this message translates to:
  /// **'By default, clicking the window’s close button minimizes Stroom to the system tray (near the clock) so it can keep running. Restore it from the tray icon or “Show main window” menu. Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the tray menu.'**
  String get platformTutorialWindowsStep1Description;

  /// No description provided for @platformTutorialWindowsStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Turn off Battery Saver'**
  String get platformTutorialWindowsStep2Title;

  /// No description provided for @platformTutorialWindowsStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Open Settings → System → Power & sleep and turn off Battery Saver. Alternatively, configure it to turn on only when the battery falls below a chosen level.'**
  String get platformTutorialWindowsStep2Description;

  /// No description provided for @platformTutorialWindowsStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Allow background apps'**
  String get platformTutorialWindowsStep3Title;

  /// No description provided for @platformTutorialWindowsStep3Description.
  ///
  /// In en, this message translates to:
  /// **'Open Settings → Privacy & security → Background apps, find Stroom, and make sure it is enabled. On Windows 11, go to Settings → Apps → Installed apps → Stroom → Advanced options → Background app permissions and choose “Always.”'**
  String get platformTutorialWindowsStep3Description;

  /// No description provided for @platformTutorialWindowsStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Turn off sleep mode (optional)'**
  String get platformTutorialWindowsStep4Title;

  /// No description provided for @platformTutorialWindowsStep4Description.
  ///
  /// In en, this message translates to:
  /// **'To keep Stroom running for long periods, open Settings → System → Power and set “Sleep” to “Never” (when plugged in only).'**
  String get platformTutorialWindowsStep4Description;

  /// No description provided for @platformTutorialWindowsStep5Title.
  ///
  /// In en, this message translates to:
  /// **'Add Stroom to startup'**
  String get platformTutorialWindowsStep5Title;

  /// No description provided for @platformTutorialWindowsStep5Description.
  ///
  /// In en, this message translates to:
  /// **'Open Task Manager (Ctrl+Shift+Esc) → Startup, find Stroom, and right-click “Enable.” Or open Settings → Apps → Startup and turn on Stroom.'**
  String get platformTutorialWindowsStep5Description;

  /// No description provided for @platformTutorialMacosStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Minimize when closing the window'**
  String get platformTutorialMacosStep1Title;

  /// No description provided for @platformTutorialMacosStep1Description.
  ///
  /// In en, this message translates to:
  /// **'By default, closing the window keeps Stroom running in the menu bar (top-right of the screen). Click its menu bar icon or choose “Show main window” to restore it. Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the menu bar menu.'**
  String get platformTutorialMacosStep1Description;

  /// No description provided for @platformTutorialMacosStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get platformTutorialMacosStep2Title;

  /// No description provided for @platformTutorialMacosStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings → Notifications → Stroom and turn on “Allow Notifications.” We recommend enabling both banners and Notification Center.'**
  String get platformTutorialMacosStep2Description;

  /// No description provided for @platformTutorialMacosStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Turn off Low Power Mode (MacBook)'**
  String get platformTutorialMacosStep3Title;

  /// No description provided for @platformTutorialMacosStep3Description.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings → Battery → Power Adapter and turn off “Low Power Mode.” This mode restricts background activity.'**
  String get platformTutorialMacosStep3Description;

  /// No description provided for @platformTutorialMacosStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Keep the app active'**
  String get platformTutorialMacosStep4Title;

  /// No description provided for @platformTutorialMacosStep4Description.
  ///
  /// In en, this message translates to:
  /// **'macOS places few restrictions on background apps. For long-running tasks, leave the Stroom window open. Avoid force-quitting the app; closing the window is enough.'**
  String get platformTutorialMacosStep4Description;

  /// No description provided for @platformTutorialMacosStep5Title.
  ///
  /// In en, this message translates to:
  /// **'Launch at login (optional)'**
  String get platformTutorialMacosStep5Title;

  /// No description provided for @platformTutorialMacosStep5Description.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings → General → Login Items and add Stroom so it starts automatically when your computer starts.'**
  String get platformTutorialMacosStep5Description;

  /// No description provided for @platformTutorialLinuxStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Minimize when closing the window'**
  String get platformTutorialLinuxStep1Title;

  /// No description provided for @platformTutorialLinuxStep1Description.
  ///
  /// In en, this message translates to:
  /// **'By default, closing the window hides Stroom in the system tray (requires a desktop environment with StatusNotifierItem support and libayatana-appindicator3-dev at build time). Restore it from the tray menu using “Show main window.” Do not quit while tasks are running. To exit, use “Exit application completely” on the “Background Optimization” page or choose “Quit Stroom” from the tray menu.'**
  String get platformTutorialLinuxStep1Description;

  /// No description provided for @platformTutorialLinuxStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Desktop environment settings'**
  String get platformTutorialLinuxStep2Title;

  /// No description provided for @platformTutorialLinuxStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Depending on your desktop environment (GNOME, KDE, XFCE, etc.), open System Settings → Apps, find Stroom, and make sure background activity is not restricted.'**
  String get platformTutorialLinuxStep2Description;

  /// No description provided for @platformTutorialLinuxStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Use a systemd service (optional)'**
  String get platformTutorialLinuxStep3Title;

  /// No description provided for @platformTutorialLinuxStep3Description.
  ///
  /// In en, this message translates to:
  /// **'For long-running background work, create a systemd user service. Create a stroom.service file under ~/.config/systemd/user/ and set ExecStart to the Stroom executable.'**
  String get platformTutorialLinuxStep3Description;

  /// No description provided for @platformTutorialLinuxStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Disable sleep'**
  String get platformTutorialLinuxStep4Title;

  /// No description provided for @platformTutorialLinuxStep4Description.
  ///
  /// In en, this message translates to:
  /// **'For a server or desktop that needs to run for a long time, set HandleLidSwitch=ignore in /etc/systemd/logind.conf to prevent sleep when the lid closes.'**
  String get platformTutorialLinuxStep4Description;

  /// No description provided for @platformTutorialLinuxStep5Title.
  ///
  /// In en, this message translates to:
  /// **'Enable autostart'**
  String get platformTutorialLinuxStep5Title;

  /// No description provided for @platformTutorialLinuxStep5Description.
  ///
  /// In en, this message translates to:
  /// **'In GNOME, use Tweaks → Startup Applications → Add Stroom. Or create a stroom.desktop file under ~/.config/autostart/.'**
  String get platformTutorialLinuxStep5Description;

  /// No description provided for @platformTutorialWebStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Keep the tab open'**
  String get platformTutorialWebStep1Title;

  /// No description provided for @platformTutorialWebStep1Description.
  ///
  /// In en, this message translates to:
  /// **'Web browsers do not support background services. Keep the Stroom tab open while tasks run; closing the tab or refreshing the page immediately interrupts them.'**
  String get platformTutorialWebStep1Description;

  /// No description provided for @platformTutorialWebStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Prevent the browser from suspending the tab'**
  String get platformTutorialWebStep2Title;

  /// No description provided for @platformTutorialWebStep2Description.
  ///
  /// In en, this message translates to:
  /// **'Browsers may freeze inactive background tabs to save resources. Keep the Stroom tab in the foreground while tasks run, or interact with the page periodically to keep it active.'**
  String get platformTutorialWebStep2Description;

  /// No description provided for @browserNavigationFailed.
  ///
  /// In en, this message translates to:
  /// **'Page navigation failed; address restored'**
  String get browserNavigationFailed;

  /// No description provided for @browserAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a web address'**
  String get browserAddressHint;

  /// No description provided for @browserUserScripts.
  ///
  /// In en, this message translates to:
  /// **'User scripts'**
  String get browserUserScripts;

  /// No description provided for @browserSwitchToMobile.
  ///
  /// In en, this message translates to:
  /// **'Switch to mobile view'**
  String get browserSwitchToMobile;

  /// No description provided for @browserSwitchToDesktop.
  ///
  /// In en, this message translates to:
  /// **'Switch to desktop view'**
  String get browserSwitchToDesktop;

  /// No description provided for @browserUaSwitchedDesktop.
  ///
  /// In en, this message translates to:
  /// **'Switched to desktop user agent'**
  String get browserUaSwitchedDesktop;

  /// No description provided for @browserUaSwitchedMobile.
  ///
  /// In en, this message translates to:
  /// **'Switched to mobile user agent'**
  String get browserUaSwitchedMobile;

  /// No description provided for @browserCookieRetentionOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cookie persistence (on)'**
  String get browserCookieRetentionOnTooltip;

  /// No description provided for @browserCookieRetentionOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cookie persistence (off)'**
  String get browserCookieRetentionOffTooltip;

  /// No description provided for @browserCookiePersistenceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Cookie persistence enabled'**
  String get browserCookiePersistenceEnabled;

  /// No description provided for @browserCookiePersistenceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Cookie persistence disabled'**
  String get browserCookiePersistenceDisabled;

  /// No description provided for @browserSniffPanelHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide sniff panel'**
  String get browserSniffPanelHideTooltip;

  /// No description provided for @browserSniffPanelShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show sniff panel'**
  String get browserSniffPanelShowTooltip;

  /// No description provided for @browserAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get browserAdd;

  /// No description provided for @browserNoScripts.
  ///
  /// In en, this message translates to:
  /// **'No scripts yet. Tap “Add” to create one.'**
  String get browserNoScripts;

  /// No description provided for @browserUnnamedScript.
  ///
  /// In en, this message translates to:
  /// **'Untitled script'**
  String get browserUnnamedScript;

  /// No description provided for @browserScriptMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} matching rule} other{{count} matching rules}}'**
  String browserScriptMatchCount(num count);

  /// No description provided for @browserEditScript.
  ///
  /// In en, this message translates to:
  /// **'Edit script'**
  String get browserEditScript;

  /// No description provided for @browserScriptName.
  ///
  /// In en, this message translates to:
  /// **'Script name'**
  String get browserScriptName;

  /// No description provided for @browserScriptCode.
  ///
  /// In en, this message translates to:
  /// **'Script code (JavaScript)'**
  String get browserScriptCode;

  /// No description provided for @browserMatchUrls.
  ///
  /// In en, this message translates to:
  /// **'URL patterns (one per line)'**
  String get browserMatchUrls;

  /// No description provided for @browserScriptMatchHint.
  ///
  /// In en, this message translates to:
  /// **'*://*.example.com/*'**
  String get browserScriptMatchHint;

  /// No description provided for @browserCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get browserCancel;

  /// No description provided for @browserSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get browserSave;

  /// No description provided for @browserCookiesConfirmClear.
  ///
  /// In en, this message translates to:
  /// **'Confirm clearing'**
  String get browserCookiesConfirmClear;

  /// No description provided for @browserCookiesConfirmClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all cookies?\nThis action cannot be undone.'**
  String get browserCookiesConfirmClearAll;

  /// No description provided for @browserCookiesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get browserCookiesClear;

  /// No description provided for @browserCookiesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get browserCookiesCancel;

  /// No description provided for @browserCookiesClearedAll.
  ///
  /// In en, this message translates to:
  /// **'All cookies cleared'**
  String get browserCookiesClearedAll;

  /// No description provided for @browserCookiesClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear. Try again.'**
  String get browserCookiesClearFailed;

  /// No description provided for @browserCookiesClearedDomain.
  ///
  /// In en, this message translates to:
  /// **'All cookies for {domain} cleared'**
  String browserCookiesClearedDomain(Object domain);

  /// No description provided for @browserCookiesClearDomainConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all cookies for {domain}?'**
  String browserCookiesClearDomainConfirm(Object domain);

  /// No description provided for @browserCookiesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser data management'**
  String get browserCookiesPageTitle;

  /// No description provided for @browserCookiesRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep cookies when exiting'**
  String get browserCookiesRetentionTitle;

  /// No description provided for @browserCookiesRetentionOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled — cookies are kept when exiting'**
  String get browserCookiesRetentionOn;

  /// No description provided for @browserCookiesRetentionOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled — cookies are cleared when exiting'**
  String get browserCookiesRetentionOff;

  /// No description provided for @browserCookiesClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all cookies'**
  String get browserCookiesClearAllTitle;

  /// No description provided for @browserCookiesClearAllDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete all saved website cookies'**
  String get browserCookiesClearAllDescription;

  /// No description provided for @browserCookiesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No persistent data'**
  String get browserCookiesEmptyTitle;

  /// No description provided for @browserCookiesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the built-in browser and enable cookie persistence to see saved data here.'**
  String get browserCookiesEmptyDescription;

  /// No description provided for @browserCookiesStoredCount.
  ///
  /// In en, this message translates to:
  /// **'Stored cookies ({count})'**
  String browserCookiesStoredCount(Object count);

  /// No description provided for @browserCookiesDomainCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} cookie} other{{count} cookies}}'**
  String browserCookiesDomainCount(num count);

  /// No description provided for @browserCookiesClearDomainTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all cookies for this domain'**
  String get browserCookiesClearDomainTooltip;

  /// No description provided for @browserCookiesDeleteOneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete this cookie'**
  String get browserCookiesDeleteOneTooltip;

  /// No description provided for @browserCookiesDeletedOne.
  ///
  /// In en, this message translates to:
  /// **'Cookie deleted'**
  String get browserCookiesDeletedOne;

  /// No description provided for @browserCookiesDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete. Try again.'**
  String get browserCookiesDeleteFailed;

  /// No description provided for @browserCookiesEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'(empty value)'**
  String get browserCookiesEmptyValue;

  /// No description provided for @platformTutorialPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform tutorials'**
  String get platformTutorialPageTitle;

  /// No description provided for @browserRecoveryOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open recovery page'**
  String get browserRecoveryOpenPage;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preview is not supported for .{format} files'**
  String galleryUnsupportedPreview(String format);

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not take a photo: {error}'**
  String galleryCameraFailed(String error);

  /// No description provided for @galleryPhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo saved'**
  String get galleryPhotoSaved;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skipped unsupported format: {format}'**
  String galleryUnsupportedImportFormat(String format);

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Imported {count, plural, =1{# image} other{# images}}'**
  String galleryImportImagesCount(int count);

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Imported {count, plural, =1{# video} other{# videos}}'**
  String galleryImportVideosCount(int count);

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String galleryImportFailed(String error);

  /// No description provided for @galleryFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read file data'**
  String get galleryFileReadFailed;

  /// No description provided for @galleryExportImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Export image'**
  String get galleryExportImageTitle;

  /// No description provided for @galleryExportVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Export video'**
  String get galleryExportVideoTitle;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Exported to: {path}'**
  String galleryExportedTo(String path);

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String galleryExportFailed(String error);

  /// No description provided for @galleryChooseExportDirectory.
  ///
  /// In en, this message translates to:
  /// **'Choose export directory'**
  String get galleryChooseExportDirectory;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Exported {count, plural, =1{# file} other{# files}}'**
  String galleryExportedFilesCount(int count);

  /// No description provided for @galleryFolderExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export folder'**
  String get galleryFolderExportTitle;

  /// No description provided for @galleryWebFolderExportInfo.
  ///
  /// In en, this message translates to:
  /// **'The browser cannot select an export directory. A ZIP file that preserves the folder structure will be downloaded.'**
  String get galleryWebFolderExportInfo;

  /// No description provided for @galleryDownloadZip.
  ///
  /// In en, this message translates to:
  /// **'Download ZIP file'**
  String get galleryDownloadZip;

  /// No description provided for @galleryExportImageFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Export image folder'**
  String get galleryExportImageFolderTitle;

  /// No description provided for @galleryExportVideoFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Export video folder'**
  String get galleryExportVideoFolderTitle;

  /// No description provided for @galleryImagePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryImagePageTitle;

  /// No description provided for @galleryVideoPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get galleryVideoPageTitle;

  /// No description provided for @galleryTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get galleryTakePhoto;

  /// No description provided for @galleryRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get galleryRecordVideo;

  /// No description provided for @galleryImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get galleryImport;

  /// No description provided for @galleryExportToLocal.
  ///
  /// In en, this message translates to:
  /// **'Export to local'**
  String get galleryExportToLocal;

  /// No description provided for @galleryPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get galleryPlayVideo;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String galleryCopyFailed(String error);

  /// No description provided for @galleryVideoSaved.
  ///
  /// In en, this message translates to:
  /// **'Video saved'**
  String get galleryVideoSaved;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Recording failed: {error}'**
  String galleryVideoRecordFailed(String error);

  /// No description provided for @galleryVideoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load video'**
  String get galleryVideoLoadFailed;

  /// No description provided for @imageEditorSaveImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get imageEditorSaveImageTitle;

  /// No description provided for @imageEditorSaveImagePrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose how to save the image:'**
  String get imageEditorSaveImagePrompt;

  /// No description provided for @imageEditorOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get imageEditorOverwrite;

  /// No description provided for @imageEditorSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get imageEditorSaveAs;

  /// No description provided for @imageEditorSavePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Save photo'**
  String get imageEditorSavePhotoTitle;

  /// No description provided for @imageEditorSavePhotoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save this photo?'**
  String get imageEditorSavePhotoPrompt;

  /// No description provided for @imageEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get imageEditorDiscard;

  /// No description provided for @imageEditorDoneLoading.
  ///
  /// In en, this message translates to:
  /// **'Generating image. Please wait…'**
  String get imageEditorDoneLoading;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quick edit – {fileName}'**
  String imageEditorQuickTitle(String fileName);

  /// No description provided for @imageEditorNotReady.
  ///
  /// In en, this message translates to:
  /// **'The editor is not ready. Please try again in a moment.'**
  String get imageEditorNotReady;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not process image: {error}'**
  String imageEditorProcessingFailed(String error);

  /// No description provided for @imageEditorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get imageEditorLoadFailed;

  /// No description provided for @imageEditorProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing image. Please wait…'**
  String get imageEditorProcessing;

  /// No description provided for @imageEditorRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get imageEditorRotateLeft;

  /// No description provided for @imageEditorRotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get imageEditorRotateRight;

  /// No description provided for @imageEditorFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get imageEditorFlip;

  /// No description provided for @imageEditorCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get imageEditorCrop;

  /// No description provided for @imageViewerImageSavedAsCopy.
  ///
  /// In en, this message translates to:
  /// **'Image saved as a copy'**
  String get imageViewerImageSavedAsCopy;

  /// No description provided for @imageViewerImageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Image updated'**
  String get imageViewerImageUpdated;

  /// Media gallery and image editor interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not save image: {error}'**
  String imageViewerSaveFailed(String error);

  /// No description provided for @imageViewerInvalidIndex.
  ///
  /// In en, this message translates to:
  /// **'Invalid image index'**
  String get imageViewerInvalidIndex;

  /// Suggested archive filename shown when exporting gallery media.
  ///
  /// In en, this message translates to:
  /// **'image-export.zip'**
  String get galleryExportImageArchiveFileName;

  /// Suggested archive filename shown when exporting gallery media.
  ///
  /// In en, this message translates to:
  /// **'video-export.zip'**
  String get galleryExportVideoArchiveFileName;

  /// Suggested archive filename shown when exporting a gallery folder.
  ///
  /// In en, this message translates to:
  /// **'image-folder-export.zip'**
  String get galleryExportImageFolderArchiveFileName;

  /// Suggested archive filename shown when exporting a gallery folder.
  ///
  /// In en, this message translates to:
  /// **'video-folder-export.zip'**
  String get galleryExportVideoFolderArchiveFileName;

  /// No description provided for @catCatchPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Web Resource Downloader'**
  String get catCatchPageTitle;

  /// No description provided for @catCatchAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get catCatchAddTask;

  /// No description provided for @catCatchOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Built-in browser'**
  String get catCatchOpenBrowser;

  /// No description provided for @catCatchEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No download tasks yet'**
  String get catCatchEmptyState;

  /// No description provided for @catCatchEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + in the top right to add a download task'**
  String get catCatchEmptyStateHint;

  /// No description provided for @catCatchInvalidCapturedUrl.
  ///
  /// In en, this message translates to:
  /// **'The captured URL is invalid'**
  String get catCatchInvalidCapturedUrl;

  /// No description provided for @catCatchCapturedFromBrowser.
  ///
  /// In en, this message translates to:
  /// **'Captured from browser: {url}'**
  String catCatchCapturedFromBrowser(String url);

  /// No description provided for @catCatchEnterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one valid URL'**
  String get catCatchEnterValidUrl;

  /// No description provided for @catCatchTaskAdded.
  ///
  /// In en, this message translates to:
  /// **'Task added'**
  String get catCatchTaskAdded;

  /// No description provided for @catCatchTasksAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task added} other{{count} tasks added}}'**
  String catCatchTasksAdded(int count);

  /// No description provided for @catCatchViewTaskList.
  ///
  /// In en, this message translates to:
  /// **'View task list'**
  String get catCatchViewTaskList;

  /// No description provided for @catCatchUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a video/audio webpage URL'**
  String get catCatchUrlHint;

  /// No description provided for @catCatchDeleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete this task'**
  String get catCatchDeleteTask;

  /// No description provided for @catCatchHour.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get catCatchHour;

  /// No description provided for @catCatchMinute.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get catCatchMinute;

  /// No description provided for @catCatchSecond.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get catCatchSecond;

  /// No description provided for @catCatchDurationPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: '**
  String get catCatchDurationPreview;

  /// No description provided for @catCatchDurationFormat.
  ///
  /// In en, this message translates to:
  /// **'hr:min:sec'**
  String get catCatchDurationFormat;

  /// No description provided for @catCatchDurationFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Optional: filter video resources by duration. Leave blank to show all resources for selection'**
  String get catCatchDurationFilterHint;

  /// No description provided for @catCatchVideoSaveTo.
  ///
  /// In en, this message translates to:
  /// **'Save video to'**
  String get catCatchVideoSaveTo;

  /// No description provided for @catCatchAudioSaveTo.
  ///
  /// In en, this message translates to:
  /// **'Save audio to'**
  String get catCatchAudioSaveTo;

  /// No description provided for @catCatchTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task added} other{{count} tasks added}}'**
  String catCatchTaskCount(int count);

  /// No description provided for @catCatchStartAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get catCatchStartAnalysis;

  /// No description provided for @catCatchVideoFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Video save folder'**
  String get catCatchVideoFolderTitle;

  /// No description provided for @catCatchAudioFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio save folder'**
  String get catCatchAudioFolderTitle;

  /// No description provided for @catCatchRootFolder.
  ///
  /// In en, this message translates to:
  /// **'Root folder'**
  String get catCatchRootFolder;

  /// No description provided for @connectivityTestTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} · Connectivity Test'**
  String connectivityTestTitle(String title);

  /// No description provided for @connectivityTestJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'Test content (JSON)'**
  String get connectivityTestJsonLabel;

  /// No description provided for @connectivityTestJsonHelp.
  ///
  /// In en, this message translates to:
  /// **'You can run or save changes directly. MCP uses read-only tools/list; search tools can change query/count; Todo is read-only by default.'**
  String get connectivityTestJsonHelp;

  /// No description provided for @connectivityTestSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String connectivityTestSaveFailed(String error);

  /// No description provided for @connectivityTestSaved.
  ///
  /// In en, this message translates to:
  /// **'Test content saved'**
  String get connectivityTestSaved;

  /// No description provided for @connectivityTestClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get connectivityTestClose;

  /// No description provided for @connectivityTestSaveContent.
  ///
  /// In en, this message translates to:
  /// **'Save Content'**
  String get connectivityTestSaveContent;

  /// No description provided for @connectivityTestTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get connectivityTestTesting;

  /// No description provided for @connectivityTestRun.
  ///
  /// In en, this message translates to:
  /// **'Run Test'**
  String get connectivityTestRun;

  /// No description provided for @connectivityTestFailedSummary.
  ///
  /// In en, this message translates to:
  /// **'Test could not be completed'**
  String get connectivityTestFailedSummary;

  /// No description provided for @connectivityTestDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} sec'**
  String connectivityTestDurationSeconds(String seconds);

  /// No description provided for @connectivityTestDurationMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'{milliseconds} ms'**
  String connectivityTestDurationMilliseconds(int milliseconds);

  /// No description provided for @messageSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Messages'**
  String get messageSearchTitle;

  /// No description provided for @messageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages across all conversations...'**
  String get messageSearchHint;

  /// No description provided for @messageSearchInitialState.
  ///
  /// In en, this message translates to:
  /// **'Type a keyword to search messages in all conversations'**
  String get messageSearchInitialState;

  /// No description provided for @messageSearchEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No matching messages found'**
  String get messageSearchEmptyState;

  /// No description provided for @messageSearchNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get messageSearchNewConversation;

  /// No description provided for @messageSearchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} match} other{{count} matches}}'**
  String messageSearchMatchCount(int count);

  /// No description provided for @filesTabText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get filesTabText;

  /// No description provided for @filesTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get filesTabAudio;

  /// No description provided for @filesTabImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get filesTabImages;

  /// No description provided for @filesTabVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get filesTabVideos;

  /// No description provided for @filesReorderTabs.
  ///
  /// In en, this message translates to:
  /// **'Reorder Tabs'**
  String get filesReorderTabs;

  /// No description provided for @filesReorderCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get filesReorderCancel;

  /// No description provided for @filesReorderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get filesReorderDone;
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
