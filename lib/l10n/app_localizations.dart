Warning: truncated output (original token count: 153263)
Total output lines: 18323

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

  /// No description provided for @galleryPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo library access required'**
  String get galleryPermissionTitle;

  /// No description provided for @galleryPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow Stroom to access photos and videos in system settings.'**
  String get galleryPermissionMessage;

  /// No description provided for @galleryPermissionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get galleryPermissionCancel;

  /// No description provided for @galleryPermissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get galleryPermissionOpenSettings;

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

  /// No description provided for @themeDisplaySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme & Display'**
  String get themeDisplaySettingsTitle;

  /// No description provided for @themeDisplayThemeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeDisplayThemeSection;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get themeModeDark;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeModeSystem;

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

  /// No description provided for @languageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get languageSearchHint;

  /// No description provided for @languageNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching languages'**
  String get languageNoMatches;

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

  /// No description provided for @ocrDefaultSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'Extract all text from the image, preserving its original formatting and layout. Return only the extracted text; do not add any explanation.'**
  String get ocrDefaultSystemPrompt;

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

  /// No description provided for @ocrInstructionManageGuidance.
  ///
  /// In en, this message translates to:
  /// **'These instructions apply to all recognition models. If none is selected, only the image is sent.'**
  String get ocrInstructionManageGuidance;

  /// No description provided for @ocrInstructionManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No instructions yet'**
  String get ocrInstructionManageEmpty;

  /// No description provided for @ocrInstructionEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit instruction'**
  String get ocrInstructionEditTooltip;

  /// No description provided for @ocrInstructionDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete instruction'**
  String get ocrInstructionDeleteTooltip;

  /// No description provided for @ocrInstructionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add instruction'**
  String get ocrInstructionAdd;

  /// No description provided for @ocrInstructionEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit instruction'**
  String get ocrInstructionEditorEditTitle;

  /// No description provided for @ocrInstructionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Instruction name (optional)'**
  String get ocrInstructionNameLabel;

  /// No description provided for @ocrInstructionContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Instruction content'**
  String get ocrInstructionContentLabel;

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

  /// Assistant update check failure shown on the topic selection page.
  String topicAssistantUpdateCheckFailed(Object error);

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

  /// No description provided for @updateCheckNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {details}'**
  String updateCheckNetworkError(Object details);

  /// No description provided for @updateCheckHttpFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check for updates: HTTP {statusCode}'**
  String updateCheckHttpFailed(Object statusCode);

  /// No description provided for @updateCheckInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Failed to check for updates: the server returned unrecognized data'**
  String get updateCheckInvalidRespons…118263 tokens truncated…icationTaskFailedTitle(String typeLabel);

  /// No description provided for @notificationTaskCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'{title} completed'**
  String notificationTaskCompletedBody(String title);

  /// No description provided for @notificationTaskFailedBody.
  ///
  /// In en, this message translates to:
  /// **'{title} failed: {error}'**
  String notificationTaskFailedBody(String title, String error);

  /// No description provided for @notificationUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get notificationUnknownError;

  /// No description provided for @desktopTrayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stroom is running in the background'**
  String get desktopTrayTooltip;

  /// No description provided for @desktopTrayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Stroom'**
  String get desktopTrayOpen;

  /// No description provided for @desktopTrayShowMainWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Main Window'**
  String get desktopTrayShowMainWindow;

  /// No description provided for @desktopTrayQuitStroom.
  ///
  /// In en, this message translates to:
  /// **'Quit Stroom'**
  String get desktopTrayQuitStroom;

  /// No description provided for @providerPresetExaDescription.
  ///
  /// In en, this message translates to:
  /// **'Search the web, extract page content, and support in-depth research through Exa MCP, with semantic and keyword search.'**
  String get providerPresetExaDescription;

  /// No description provided for @providerPresetExaApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key from the Exa website.'**
  String get providerPresetExaApiKeyHint;

  /// No description provided for @providerPresetTavilyDescription.
  ///
  /// In en, this message translates to:
  /// **'An AI-native search engine for real-time web search optimized for large language models.'**
  String get providerPresetTavilyDescription;

  /// No description provided for @providerPresetTavilyApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key from Tavily. It supports ?tavilyApiKey= or an Authorization: Bearer header.'**
  String get providerPresetTavilyApiKeyHint;

  /// No description provided for @providerPresetJinaDescription.
  ///
  /// In en, this message translates to:
  /// **'A multimodal AI service for extracting web content, generating embeddings, and retrieving search results.'**
  String get providerPresetJinaDescription;

  /// No description provided for @providerPresetJinaApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get a Jina AI API key (Bearer token) from its website.'**
  String get providerPresetJinaApiKeyHint;

  /// No description provided for @providerPresetFirecrawlDescription.
  ///
  /// In en, this message translates to:
  /// **'A web crawling and extraction service that turns pages into clean Markdown or structured data.'**
  String get providerPresetFirecrawlDescription;

  /// No description provided for @providerPresetFirecrawlApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get a Firecrawl API key, or try it without a key with the free tier limits.'**
  String get providerPresetFirecrawlApiKeyHint;

  /// No description provided for @providerPresetZhipuDescription.
  ///
  /// In en, this message translates to:
  /// **'Zhipu AI’s web reader MCP service for fetching and understanding web pages.'**
  String get providerPresetZhipuDescription;

  /// No description provided for @providerPresetZhipuApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key (Bearer token) from the Zhipu AI Open Platform.'**
  String get providerPresetZhipuApiKeyHint;

  /// No description provided for @providerPresetBraveSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'A privacy-focused independent search engine with high-quality web results.'**
  String get providerPresetBraveSearchDescription;

  /// No description provided for @providerPresetBraveSearchApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key from the Brave Search website.'**
  String get providerPresetBraveSearchApiKeyHint;

  /// No description provided for @providerPresetBochaDescription.
  ///
  /// In en, this message translates to:
  /// **'Bocha AI web search provides intelligent search results for Chinese-language pages.'**
  String get providerPresetBochaDescription;

  /// No description provided for @providerPresetBochaApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key (Bearer token) from the Bocha AI Open Platform.'**
  String get providerPresetBochaApiKeyHint;

  /// No description provided for @providerPresetQueritDescription.
  ///
  /// In en, this message translates to:
  /// **'Querit AI search offers intelligent search and content discovery.'**
  String get providerPresetQueritDescription;

  /// No description provided for @providerPresetQueritApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key (Bearer token) from the Querit website.'**
  String get providerPresetQueritApiKeyHint;

  /// No description provided for @providerPresetSearxngDescription.
  ///
  /// In en, this message translates to:
  /// **'A self-hosted metasearch engine that aggregates search sources with a focus on privacy.'**
  String get providerPresetSearxngDescription;

  /// No description provided for @providerPresetSearxngApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Set your SearXNG instance URL (for example, http://your-instance:8080); an API key is optional.'**
  String get providerPresetSearxngApiKeyHint;

  /// No description provided for @ttsErrorSynthesisFailed.
  ///
  /// In en, this message translates to:
  /// **'TTS synthesis failed: {details}'**
  String ttsErrorSynthesisFailed(String details);

  /// No description provided for @ttsErrorOriginalError.
  ///
  /// In en, this message translates to:
  /// **'\nOriginal error: {details}'**
  String ttsErrorOriginalError(String details);

  /// No description provided for @ttsErrorNetworkConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network connection timed out. Check your network or API address.'**
  String get ttsErrorNetworkConnectionTimeout;

  /// No description provided for @ttsErrorServerResponseTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server response timed out. Try again later.'**
  String get ttsErrorServerResponseTimeout;

  /// No description provided for @ttsErrorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server ({details})'**
  String ttsErrorConnectionFailed(String details);

  /// No description provided for @ttsErrorWebConnectionGuidance.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Common causes in the web app: CORS restrictions or an incorrect API address. {details}'**
  String ttsErrorWebConnectionGuidance(String details);

  /// No description provided for @ttsErrorApiResponse.
  ///
  /// In en, this message translates to:
  /// **'API returned an error (HTTP {status}{body})'**
  String ttsErrorApiResponse(String body, String status);

  /// No description provided for @ttsErrorConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check your network{details}'**
  String ttsErrorConnectTimeout(String details);

  /// No description provided for @ttsErrorReceiveTimeout.
  ///
  /// In en, this message translates to:
  /// **'Receive timed out; the server is responding slowly{details}'**
  String ttsErrorReceiveTimeout(String details);

  /// No description provided for @ttsErrorInvalidApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key is invalid or permission denied (HTTP {status}): {body}{details}'**
  String ttsErrorInvalidApiKey(String body, String details, String status);

  /// No description provided for @ttsErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests; try again later (HTTP {status}){details}'**
  String ttsErrorTooManyRequests(String details, String status);

  /// No description provided for @ttsErrorEndpointNotFound.
  ///
  /// In en, this message translates to:
  /// **'API endpoint not found (HTTP {status}): {body}\nCheck that the API base URL is correct{details}'**
  String ttsErrorEndpointNotFound(String body, String details, String status);

  /// No description provided for @ttsErrorServerInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal server error (HTTP {status}): {body}{details}'**
  String ttsErrorServerInternal(String body, String details, String status);

  /// No description provided for @ttsErrorServerResponse.
  ///
  /// In en, this message translates to:
  /// **'Server returned an error (HTTP {status}): {body}{details}'**
  String ttsErrorServerResponse(String body, String details, String status);

  /// No description provided for @ttsErrorRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled{details}'**
  String ttsErrorRequestCancelled(String details);

  /// No description provided for @ttsErrorWebNetworkGuidance.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Common causes in the web app: CORS restrictions or an incorrect API address. Check that the provider API address is correct and that the server allows cross-origin requests.{details}'**
  String ttsErrorWebNetworkGuidance(String details);

  /// No description provided for @ttsErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error: {details}'**
  String ttsErrorNetwork(String details);

  /// No description provided for @ttsErrorUnknownNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unknown network error'**
  String get ttsErrorUnknownNetwork;

  /// No description provided for @ttsErrorNoResponseBody.
  ///
  /// In en, this message translates to:
  /// **'No response body'**
  String get ttsErrorNoResponseBody;

  /// No description provided for @ttsErrorStreamingSynthesisFailed.
  ///
  /// In en, this message translates to:
  /// **'Streaming synthesis failed: {details}'**
  String ttsErrorStreamingSynthesisFailed(String details);

  /// No description provided for @mermaidEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Mermaid Chart Editor'**
  String get mermaidEditorTitle;

  /// No description provided for @mermaidEditorModeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get mermaidEditorModeEdit;

  /// No description provided for @mermaidEditorModeSplit.
  ///
  /// In en, this message translates to:
  /// **'Edit + Preview'**
  String get mermaidEditorModeSplit;

  /// No description provided for @mermaidEditorModePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get mermaidEditorModePreview;

  /// No description provided for @mermaidEditorSwitchViewMode.
  ///
  /// In en, this message translates to:
  /// **'Switch view mode'**
  String get mermaidEditorSwitchViewMode;

  /// No description provided for @mermaidEditorSaveToTextStorage.
  ///
  /// In en, this message translates to:
  /// **'Save to Text Storage'**
  String get mermaidEditorSaveToTextStorage;

  /// No description provided for @mermaidEditorEmptyChart.
  ///
  /// In en, this message translates to:
  /// **'Chart content is empty and cannot be saved'**
  String get mermaidEditorEmptyChart;

  /// No description provided for @mermaidEditorSaveChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Save chart'**
  String get mermaidEditorSaveChartTitle;

  /// No description provided for @mermaidEditorSaveFolderGuidance.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a folder to save the .mmd chart file'**
  String get mermaidEditorSaveFolderGuidance;

  /// No description provided for @mermaidEditorFileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a filename (.mmd added automatically)'**
  String get mermaidEditorFileNameHint;

  /// No description provided for @mermaidEditorEmptyFileName.
  ///
  /// In en, this message translates to:
  /// **'Filename cannot be empty'**
  String get mermaidEditorEmptyFileName;

  /// No description provided for @mermaidEditorSavedToTextStorage.
  ///
  /// In en, this message translates to:
  /// **'Saved to text storage: {path}'**
  String mermaidEditorSavedToTextStorage(String path);

  /// No description provided for @mermaidEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String mermaidEditorSaveFailed(String error);

  /// No description provided for @mermaidEditorSwapPreviewAndEditor.
  ///
  /// In en, this message translates to:
  /// **'Swap preview and editor panels'**
  String get mermaidEditorSwapPreviewAndEditor;

  /// No description provided for @mermaidEditorCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mermaid code'**
  String get mermaidEditorCodeLabel;

  /// No description provided for @mermaidEditorCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Mermaid code...'**
  String get mermaidEditorCodeHint;

  /// No description provided for @mermaidEditorSplitCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get mermaidEditorSplitCodeLabel;

  /// No description provided for @sseConnectionFailedWithStatus.
  ///
  /// In en, this message translates to:
  /// **'SSE connection failed (HTTP {statusCode}: {statusText})'**
  String sseConnectionFailedWithStatus(int statusCode, String statusText);

  /// No description provided for @sseConnectionFailedWithoutStatusText.
  ///
  /// In en, this message translates to:
  /// **'SSE connection failed (HTTP {statusCode})'**
  String sseConnectionFailedWithoutStatusText(int statusCode);

  /// No description provided for @sseConnectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SSE connection failed: unable to connect to server'**
  String get sseConnectionUnavailable;

  /// No description provided for @sseHttpRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'HTTP request failed (HTTP {statusCode}: {statusText})'**
  String sseHttpRequestFailed(int statusCode, String statusText);

  /// No description provided for @sseRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed'**
  String get sseRequestFailed;

  /// No description provided for @sseNetworkRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Network request failed'**
  String get sseNetworkRequestFailed;

  /// No description provided for @sseNetworkRequestFailedWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Network request failed (HTTP {statusCode}: {statusText})'**
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText);

  /// No description provided for @sseNetworkRequestFailedWithoutStatusText.
  ///
  /// In en, this message translates to:
  /// **'Network request failed (HTTP {statusCode})'**
  String sseNetworkRequestFailedWithoutStatusText(int statusCode);

  /// No description provided for @sseNetworkConnectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Network request failed: unable to connect to server'**
  String get sseNetworkConnectionUnavailable;

  /// No description provided for @sseRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get sseRequestCancelled;

  /// No description provided for @startupSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data safety protection'**
  String get startupSafetyTitle;

  /// No description provided for @startupSafetyExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get startupSafetyExportButton;

  /// No description provided for @startupSafetyExitButton.
  ///
  /// In en, this message translates to:
  /// **'Exit app'**
  String get startupSafetyExitButton;

  /// No description provided for @startupSafetyUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update app'**
  String get startupSafetyUpdateButton;

  /// No description provided for @startupSafetyCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get startupSafetyCheckingUpdates;

  /// No description provided for @startupSafetyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get startupSafetyUpToDate;

  /// No description provided for @startupSafetyNewerDataVersion.
  ///
  /// In en, this message translates to:
  /// **'This data was created by a newer version of the app ({version}).\n\nThis app version cannot safely read the data. Install the latest version to continue. Your data has not been changed.'**
  String startupSafetyNewerDataVersion(String version);

  /// No description provided for @startupSafetyStatusUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The data safety status could not be confirmed (the status marker could not be read or was invalid).\n\nTo avoid overwriting a possible frozen state, startup has been blocked without repairing data or migrating formats. First export your data file, then exit the app, repair the status marker, and try again.'**
  String get startupSafetyStatusUnreadable;

  /// No description provided for @startupSafetyMigrationFailedNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Data format migration failed ({part}).\n\nTo protect your data, no changes were made. Return to the previous app version, or wait for a fixed version before upgrading.'**
  String startupSafetyMigrationFailedNoChanges(String part);

  /// No description provided for @startupSafetyMigrationFailedRestored.
  ///
  /// In en, this message translates to:
  /// **'Data format migration failed ({part}).\n\nYour data was restored to its pre-migration state. To protect it, return to the previous app version, or wait for a fixed version before upgrading.'**
  String startupSafetyMigrationFailedRestored(String part);

  /// No description provided for @startupSafetyDataCorrupted.
  ///
  /// In en, this message translates to:
  /// **'Data is damaged and could not be repaired automatically.\n\nThe app has been frozen to prevent further damage. Export your data file, then import it manually or reinstall.'**
  String get startupSafetyDataCorrupted;

  /// No description provided for @startupSafetyPreferencesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The app could not read preferences required for startup checks, so startup has been blocked to protect your data.\n\nCheck storage space or permissions, then reopen the app.'**
  String get startupSafetyPreferencesUnavailable;

  /// No description provided for @startupSafetyValidationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The app could not complete its startup data-safety check, so startup has been blocked to protect your data.\n\nCheck browser settings, then reopen the app.'**
  String get startupSafetyValidationUnavailable;

  /// No description provided for @startupSafetyCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Startup check failed: {detail}'**
  String startupSafetyCheckFailed(String detail);

  /// No description provided for @startupSafetyStatusUnreadableAfterChecks.
  ///
  /// In en, this message translates to:
  /// **'The data safety status could not be confirmed after startup checks (the status marker could not be read or was invalid).\n\nStartup has stopped to avoid making further data changes. Export your data file, exit the app, repair the status marker, and try again.'**
  String get startupSafetyStatusUnreadableAfterChecks;

  /// No description provided for @catCatchConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check your network or server status.'**
  String get catCatchConnectionTimeout;

  /// No description provided for @catCatchSendTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out while sending.'**
  String get catCatchSendTimeout;

  /// No description provided for @catCatchReceiveTimeout.
  ///
  /// In en, this message translates to:
  /// **'The response timed out because the server is taking too long.'**
  String get catCatchReceiveTimeout;

  /// No description provided for @catCatchCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server.'**
  String get catCatchCannotConnect;

  /// No description provided for @catCatchConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server. Check that the URL is correct.'**
  String get catCatchConnectionError;

  /// No description provided for @catCatchBadCertificate.
  ///
  /// In en, this message translates to:
  /// **'The server certificate could not be verified.'**
  String get catCatchBadCertificate;

  /// No description provided for @catCatchBadResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error (HTTP {statusCode})'**
  String catCatchBadResponse(int statusCode);

  /// No description provided for @catCatchRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get catCatchRequestCancelled;

  /// No description provided for @catCatchNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {message}'**
  String catCatchNetworkError(String message);

  /// No description provided for @catCatchUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get catCatchUnknownError;

  /// No description provided for @catCatchOriginalError.
  ///
  /// In en, this message translates to:
  /// **'Original error: {message}'**
  String catCatchOriginalError(String message);

  /// No description provided for @catCatchWebDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Web browsers cannot download media files directly.'**
  String get catCatchWebDownloadHint;

  /// No description provided for @catCatchWebInstallExtension.
  ///
  /// In en, this message translates to:
  /// **'Install the CatCatch browser extension and try again.'**
  String get catCatchWebInstallExtension;

  /// No description provided for @catCatchWebAuthorAttribution.
  ///
  /// In en, this message translates to:
  /// **'Author: 笨笨猫 (xifangczy). Free and open source.'**
  String get catCatchWebAuthorAttribution;

  /// No description provided for @catCatchWebOfficialWarning.
  ///
  /// In en, this message translates to:
  /// **'Make sure it is the author’s version; avoid paid or imitation versions.'**
  String get catCatchWebOfficialWarning;

  /// No description provided for @catCatchWebGitHubAddress.
  ///
  /// In en, this message translates to:
  /// **'GitHub: https://github.com/xifangczy/cat-catch'**
  String get catCatchWebGitHubAddress;

  /// No description provided for @catCatchLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'This feature requires a signed-in account. Sign in using the browser in the top-right corner.'**
  String get catCatchLoginRequired;

  /// No description provided for @catCatchNoUsableMedia.
  ///
  /// In en, this message translates to:
  /// **'No usable media resource was found. Check the URL and make sure the website is reachable.'**
  String get catCatchNoUsableMedia;

  /// No description provided for @catCatchRedownloadFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The download failed because the downloaded file is missing.'**
  String get catCatchRedownloadFileMissing;

  /// No description provided for @catCatchRedownloadPathEmpty.
  ///
  /// In en, this message translates to:
  /// **'The download failed because the downloaded file path is empty.'**
  String get catCatchRedownloadPathEmpty;

  /// No description provided for @catCatchWebBrowserRequired.
  ///
  /// In en, this message translates to:
  /// **'This page cannot expose its resources without a browser environment. Try using the feature on mobile or desktop, or paste a direct video or audio file URL.'**
  String get catCatchWebBrowserRequired;

  /// No description provided for @catCatchPlaylistNoSegments.
  ///
  /// In en, this message translates to:
  /// **'The playlist has no downloadable segments.'**
  String get catCatchPlaylistNoSegments;

  /// No description provided for @catCatchDownloadedSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'The downloaded source file is missing. Please download it again.'**
  String get catCatchDownloadedSourceMissing;

  /// No description provided for @appLogPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Application logs'**
  String get appLogPageTitle;

  /// No description provided for @appLogRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get appLogRefresh;

  /// No description provided for @appLogCleanupOldLogs.
  ///
  /// In en, this message translates to:
  /// **'Clean up old logs'**
  String get appLogCleanupOldLogs;

  /// No description provided for @appLogCleanupDone.
  ///
  /// In en, this message translates to:
  /// **'Old logs were cleaned up'**
  String get appLogCleanupDone;

  /// Explains the automatic log retention policy.
  ///
  /// In en, this message translates to:
  /// **'Log retention: Only the most recent {days} days are kept. Logs older than {days} days are cleaned automatically.'**
  String appLogRetentionNotice(int days);

  /// No description provided for @appLogWebUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Local logs are not supported on web'**
  String get appLogWebUnsupported;

  /// No description provided for @appLogNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No log files yet'**
  String get appLogNoFiles;

  /// Status shown while the log list retries loading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Refreshing automatically (attempt {count})...} other{Refreshing automatically (attempts {count})...}}'**
  String appLogAutoRefresh(int count);

  /// No description provided for @appLogWillBeCreated.
  ///
  /// In en, this message translates to:
  /// **'Logs are generated while the app is running'**
  String get appLogWillBeCreated;

  /// No description provided for @appLogExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get appLogExport;

  /// No description provided for @appLogDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get appLogDelete;

  /// No description provided for @appLogConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get appLogConfirmDeleteTitle;

  /// Confirmation message for deleting a log file.
  ///
  /// In en, this message translates to:
  /// **'Delete log file \"{fileName}\"?'**
  String appLogConfirmDeleteMessage(String fileName);

  /// No description provided for @appLogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get appLogCancel;

  /// Error shown when loading the log file list fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load log file list: {error}'**
  String appLogLoadFilesError(Object error);

  /// Error shown when an existing log file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Log file \"{fileName}\" exists but could not be read; it may be corrupted'**
  String appLogReadFileUnreadable(String fileName);

  /// Error shown when a log file is missing.
  ///
  /// In en, this message translates to:
  /// **'Log file \"{fileName}\" was not found; it may have been cleaned up'**
  String appLogReadFileMissing(String fileName);

  /// Error shown when reading a log file fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to read log file: {error}'**
  String appLogReadFileError(Object error);

  /// Status shown after deleting a log file.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {fileName}'**
  String appLogDeleteDone(String fileName);

  /// Error shown when deleting a log file fails.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String appLogDeleteError(Object error);

  /// Error shown when the log file to export is missing.
  ///
  /// In en, this message translates to:
  /// **'Log file \"{fileName}\" was not found'**
  String appLogExportMissing(String fileName);

  /// Status shown after copying a log file path.
  ///
  /// In en, this message translates to:
  /// **'Path copied: {filePath}'**
  String appLogPathCopied(String filePath);

  /// Error shown when exporting a log file fails.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String appLogExportError(Object error);

  /// Number of lines in the log file.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} line} other{{count} lines}}'**
  String appLogLineCount(int count);

  /// No description provided for @appLogCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get appLogCopyAll;

  /// No description provided for @appLogStructuredView.
  ///
  /// In en, this message translates to:
  /// **'Structured view'**
  String get appLogStructuredView;

  /// No description provided for @appLogRawView.
  ///
  /// In en, this message translates to:
  /// **'Raw view'**
  String get appLogRawView;

  /// Error shown when copying log content fails.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String appLogCopyError(Object error);

  /// No description provided for @appLogCopyDone.
  ///
  /// In en, this message translates to:
  /// **'Copied all log content'**
  String get appLogCopyDone;

  /// Title shown in iOS continued-task system UI.
  ///
  /// In en, this message translates to:
  /// **'Background task'**
  String get iosContinuedTaskTitle;

  /// No description provided for @mermaidCatalogTypeFlowchart.
  ///
  /// In en, this message translates to:
  /// **'Flowchart'**
  String get mermaidCatalogTypeFlowchart;

  /// No description provided for @mermaidCatalogDescriptionFlowchart.
  ///
  /// In en, this message translates to:
  /// **'Flowchart — show steps, branches, and loops'**
  String get mermaidCatalogDescriptionFlowchart;

  /// No description provided for @mermaidCatalogTypeSequenceDiagram.
  ///
  /// In en, this message translates to:
  /// **'Sequence diagram'**
  String get mermaidCatalogTypeSequenceDiagram;

  /// No description provided for @mermaidCatalogDescriptionSequenceDiagram.
  ///
  /// In en, this message translates to:
  /// **'Sequence diagram — show interactions between participants'**
  String get mermaidCatalogDescriptionSequenceDiagram;

  /// No description provided for @mermaidCatalogTypeClassDiagram.
  ///
  /// In en, this message translates to:
  /// **'Class diagram'**
  String get mermaidCatalogTypeClassDiagram;

  /// No description provided for @mermaidCatalogDescriptionClassDiagram.
  ///
  /// In en, this message translates to:
  /// **'Class diagram — show relationships between class attributes and methods'**
  String get mermaidCatalogDescriptionClassDiagram;

  /// No description provided for @mermaidCatalogTypeStateDiagram.
  ///
  /// In en, this message translates to:
  /// **'State diagram'**
  String get mermaidCatalogTypeStateDiagram;

  /// No description provided for @mermaidCatalogDescriptionStateDiagram.
  ///
  /// In en, this message translates to:
  /// **'State diagram — show state transitions'**
  String get mermaidCatalogDescriptionStateDiagram;

  /// No description provided for @mermaidCatalogTypeErDiagram.
  ///
  /// In en, this message translates to:
  /// **'ER diagram'**
  String get mermaidCatalogTypeErDiagram;

  /// No description provided for @mermaidCatalogDescriptionErDiagram.
  ///
  /// In en, this message translates to:
  /// **'ER diagram — show entity relationships'**
  String get mermaidCatalogDescriptionErDiagram;

  /// No description provided for @mermaidCatalogTypeGantt.
  ///
  /// In en, this message translates to:
  /// **'Gantt chart'**
  String get mermaidCatalogTypeGantt;

  /// No description provided for @mermaidCatalogDescriptionGantt.
  ///
  /// In en, this message translates to:
  /// **'Gantt chart — show a project timeline'**
  String get mermaidCatalogDescriptionGantt;

  /// No description provided for @mermaidCatalogTypePie.
  ///
  /// In en, this message translates to:
  /// **'Pie chart'**
  String get mermaidCatalogTypePie;

  /// No description provided for @mermaidCatalogDescriptionPie.
  ///
  /// In en, this message translates to:
  /// **'Pie chart — show proportional data'**
  String get mermaidCatalogDescriptionPie;

  /// No description provided for @mermaidCatalogTypeJourney.
  ///
  /// In en, this message translates to:
  /// **'User journey'**
  String get mermaidCatalogTypeJourney;

  /// No description provided for @mermaidCatalogDescriptionJourney.
  ///
  /// In en, this message translates to:
  /// **'User journey — show a user experience flow'**
  String get mermaidCatalogDescriptionJourney;

  /// No description provided for @mermaidCatalogTypeGitGraph.
  ///
  /// In en, this message translates to:
  /// **'Git graph'**
  String get mermaidCatalogTypeGitGraph;

  /// No description provided for @mermaidCatalogDescriptionGitGraph.
  ///
  /// In en, this message translates to:
  /// **'Git graph — show branches and commits'**
  String get mermaidCatalogDescriptionGitGraph;

  /// No description provided for @mermaidCatalogTypeMindmap.
  ///
  /// In en, this message translates to:
  /// **'Mind map'**
  String get mermaidCatalogTypeMindmap;

  /// No description provided for @mermaidCatalogDescriptionMindmap.
  ///
  /// In en, this message translates to:
  /// **'Mind map — show a hierarchy'**
  String get mermaidCatalogDescriptionMindmap;

  /// No description provided for @mermaidCatalogTypeTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get mermaidCatalogTypeTimeline;

  /// No description provided for @mermaidCatalogDescriptionTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline — show events in chronological order'**
  String get mermaidCatalogDescriptionTimeline;

  /// No description provided for @mermaidCatalogTypeBlock.
  ///
  /// In en, this message translates to:
  /// **'Block diagram'**
  String get mermaidCatalogTypeBlock;

  /// No description provided for @mermaidCatalogDescriptionBlock.
  ///
  /// In en, this message translates to:
  /// **'Block diagram — show block layout and relationships'**
  String get mermaidCatalogDescriptionBlock;

  /// No description provided for @mermaidCatalogTypeRequirement.
  ///
  /// In en, this message translates to:
  /// **'Requirement diagram'**
  String get mermaidCatalogTypeRequirement;

  /// No description provided for @mermaidCatalogDescriptionRequirement.
  ///
  /// In en, this message translates to:
  /// **'Requirement diagram — show requirements and implementation relationships'**
  String get mermaidCatalogDescriptionRequirement;

  /// No description provided for @mermaidCatalogTemplateFlowchart.
  ///
  /// In en, this message translates to:
  /// **'graph TD\n  A[Start]\n  B[Process step]\n  C<MERMAID_OPEN_BRACE>Condition<MERMAID_CLOSE_BRACE>\n  D[End]\n\n  A --> B\n  B --> C\n  C -->|Yes| D\n  C -->|No| B'**
  String get mermaidCatalogTemplateFlowchart;

  /// No description provided for @mermaidCatalogTemplateSequenceDiagram.
  ///
  /// In en, this message translates to:
  /// **'sequenceDiagram\n  participant \"User\" as 用户\n  participant \"System\" as 系统\n  participant \"Database\" as 数据库\n\n  用户->>系统: Send request\n  系统->>数据库: Query data\n  数据库-->>系统: Return result\n  系统-->>用户: Show result'**
  String get mermaidCatalogTemplateSequenceDiagram;

  /// No description provided for @mermaidCatalogTemplateClassDiagram.
  ///
  /// In en, this message translates to:
  /// **'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String name\n    +int age\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String studentId\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String teacherId\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person'**
  String get mermaidCatalogTemplateClassDiagram;

  /// No description provided for @mermaidCatalogTemplateStateDiagram.
  ///
  /// In en, this message translates to:
  /// **'stateDiagram-v2\n  state \"Pending\" as 待处理\n  state \"Processing\" as 处理中\n  state \"Completed\" as 已完成\n  state \"Failed\" as 失败\n  [*] --> 待处理\n  待处理 --> 处理中\n  处理中 --> 已完成\n  处理中 --> 失败\n  失败 --> 待处理\n  已完成 --> [*]'**
  String get mermaidCatalogTemplateStateDiagram;

  /// No description provided for @mermaidCatalogTemplateErDiagram.
  ///
  /// In en, this message translates to:
  /// **'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : places\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : contains\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : includes\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>'**
  String get mermaidCatalogTemplateErDiagram;

  /// No description provided for @mermaidCatalogTemplateGantt.
  ///
  /// In en, this message translates to:
  /// **'gantt\n  title Project Gantt chart\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section Requirements\n  Requirements analysis :a1, 2024-01-01, 14d\n  Prototype design     :a2, after a1, 10d\n\n  section Development\n  Frontend development  :b1, after a2, 20d\n  Backend development  :b2, after a2, 20d\n  API integration      :b3, after b1, 7d\n\n  section Testing\n  Feature testing      :c1, after b3, 10d\n  Deployment           :c2, after c1, 3d'**
  String get mermaidCatalogTemplateGantt;

  /// No description provided for @mermaidCatalogTemplatePie.
  ///
  /// In en, this message translates to:
  /// **'pie showData\n  title Data distribution\n  \"Category A\" : 40\n  \"Category B\" : 25\n  \"Category C\" : 20\n  \"Category D\" : 15'**
  String get mermaidCatalogTemplatePie;

  /// No description provided for @mermaidCatalogTemplateJourney.
  ///
  /// In en, this message translates to:
  /// **'journey\n  title User registration\n  section Sign-up\n    Open sign-up page: 5: User\n    Enter information: 3: User\n    Submit request: 4: User\n  section Verification\n    Receive code: 3: System\n    Enter code: 4: User\n    Verification succeeds: 5: System, User'**
  String get mermaidCatalogTemplateJourney;

  /// No description provided for @mermaidCatalogTemplateGitGraph.
  ///
  /// In en, this message translates to:
  /// **'gitGraph\n  commit id: \"初始提交\"\n  commit id: \"添加功能A\"\n  branch develop\n  checkout develop\n  commit id: \"开发新功能\"\n  commit id: \"修复bug\"\n  checkout main\n  merge develop\n  commit id: \"发布v1.0\"'**
  String get mermaidCatalogTemplateGitGraph;

  /// No description provided for @mermaidCatalogTemplateMindmap.
  ///
  /// In en, this message translates to:
  /// **'mindmap\n  root((Project management))\n    Requirements\n      Functional\n      Non-functional\n    Development\n      Frontend\n      Backend\n    Testing\n      Unit tests\n      Integration tests\n    Deployment\n      Test environment\n      Production environment'**
  String get mermaidCatalogTemplateMindmap;

  /// No description provided for @mermaidCatalogTemplateTimeline.
  ///
  /// In en, this message translates to:
  /// **'timeline\n  title Project milestones\n  2024-Q1 : Requirements research : Plan confirmed\n  2024-Q2 : Development : Features implemented\n  2024-Q3 : Testing : Bug fixes : Performance tuning\n  2024-Q4 : Deployment : Operations and maintenance'**
  String get mermaidCatalogTemplateTimeline;

  /// No description provided for @mermaidCatalogTemplateBlock.
  ///
  /// In en, this message translates to:
  /// **'block-beta\n  columns 3\n  A[\"Requirements\"] B[\"Development\"] C[\"Testing\"]\n  D[\"Deployment\"] E[\"Operations\"] F[\"Monitoring\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F'**
  String get mermaidCatalogTemplateBlock;

  /// No description provided for @mermaidCatalogTemplateRequirement.
  ///
  /// In en, this message translates to:
  /// **'requirementDiagram\n  requirement 用户登录 <MERMAID_OPEN_BRACE>\n    id: 1\n    text: A user can sign in with an account and password\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element 登录页面 <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element 认证服务 <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  登录页面 - satisfies -> 用户登录\n  认证服务 - verifies -> 用户登录'**
  String get mermaidCatalogTemplateRequirement;

  /// No description provided for @mermaidCatalogDefaultFileName.
  ///
  /// In en, this message translates to:
  /// **'My chart'**
  String get mermaidCatalogDefaultFileName;

  /// No description provided for @mermaidCatalogActionAddNode.
  ///
  /// In en, this message translates to:
  /// **'Add node'**
  String get mermaidCatalogActionAddNode;

  /// No description provided for @mermaidCatalogActionAddDecision.
  ///
  /// In en, this message translates to:
  /// **'Add decision'**
  String get mermaidCatalogActionAddDecision;

  /// No description provided for @mermaidCatalogActionAddEdge.
  ///
  /// In en, this message translates to:
  /// **'Add edge'**
  String get mermaidCatalogActionAddEdge;

  /// No description provided for @mermaidCatalogActionAddSubgraph.
  ///
  /// In en, this message translates to:
  /// **'Add subgraph'**
  String get mermaidCatalogActionAddSubgraph;

  /// No description provided for @mermaidCatalogActionAddParticipant.
  ///
  /// In en, this message translates to:
  /// **'Add participant'**
  String get mermaidCatalogActionAddParticipant;

  /// No description provided for @mermaidCatalogActionAddRequest.
  ///
  /// In en, this message translates to:
  /// **'Add request'**
  String get mermaidCatalogActionAddRequest;

  /// No description provided for @mermaidCatalogActionAddResponse.
  ///
  /// In en, this message translates to:
  /// **'Add response'**
  String get mermaidCatalogActionAddResponse;

  /// No description provided for @mermaidCatalogActionAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get mermaidCatalogActionAddNote;

  /// No description provided for @mermaidCatalogActionAddClass.
  ///
  /// In en, this message translates to:
  /// **'Add class'**
  String get mermaidCatalogActionAddClass;

  /// No description provided for @mermaidCatalogActionAddInheritance.
  ///
  /// In en, this message translates to:
  /// **'Add inheritance'**
  String get mermaidCatalogActionAddInheritance;

  /// No description provided for @mermaidCatalogActionAddRelationship.
  ///
  /// In en, this message translates to:
  /// **'Add relationship'**
  String get mermaidCatalogActionAddRelationship;

  /// No description provided for @mermaidCatalogActionAddAggregation.
  ///
  /// In en, this message translates to:
  /// **'Add aggregation'**
  String get mermaidCatalogActionAddAggregation;

  /// No description provided for @mermaidCatalogActionAddState.
  ///
  /// In en, this message translates to:
  /// **'Add state'**
  String get mermaidCatalogActionAddState;

  /// No description provided for @mermaidCatalogActionAddTransition.
  ///
  /// In en, this message translates to:
  /// **'Add transition'**
  String get mermaidCatalogActionAddTransition;

  /// No description provided for @mermaidCatalogActionAddStart.
  ///
  /// In en, this message translates to:
  /// **'Add start'**
  String get mermaidCatalogActionAddStart;

  /// No description provided for @mermaidCatalogActionAddEnd.
  ///
  /// In en, this message translates to:
  /// **'Add end'**
  String get mermaidCatalogActionAddEnd;

  /// No description provided for @mermaidCatalogActionAddEntity.
  ///
  /// In en, this message translates to:
  /// **'Add entity'**
  String get mermaidCatalogActionAddEntity;

  /// No description provided for @mermaidCatalogActionAddOneToMany.
  ///
  /// In en, this message translates to:
  /// **'Add one-to-many'**
  String get mermaidCatalogActionAddOneToMany;

  /// No description provided for @mermaidCatalogActionAddManyToMany.
  ///
  /// In en, this message translates to:
  /// **'Add many-to-many'**
  String get mermaidCatalogActionAddManyToMany;

  /// No description provided for @mermaidCatalogActionAddOneToOne.
  ///
  /// In en, this message translates to:
  /// **'Add one-to-one'**
  String get mermaidCatalogActionAddOneToOne;

  /// No description provided for @mermaidCatalogActionAddPhase.
  ///
  /// In en, this message translates to:
  /// **'Add phase'**
  String get mermaidCatalogActionAddPhase;

  /// No description provided for @mermaidCatalogActionAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get mermaidCatalogActionAddTask;

  /// No description provided for @mermaidCatalogActionAddDependentTask.
  ///
  /// In en, this message translates to:
  /// **'Add dependent task'**
  String get mermaidCatalogActionAddDependentTask;

  /// No description provided for @mermaidCatalogActionAddMilestone.
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get mermaidCatalogActionAddMilestone;

  /// No description provided for @mermaidCatalogActionAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get mermaidCatalogActionAddCategory;

  /// No description provided for @mermaidCatalogActionAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add title'**
  String get mermaidCatalogActionAddTitle;

  /// No description provided for @mermaidCatalogActionAddSystemTask.
  ///
  /// In en, this message translates to:
  /// **'Add system task'**
  String get mermaidCatalogActionAddSystemTask;

  /// No description provided for @mermaidCatalogActionAddMultiPersonTask.
  ///
  /// In en, this message translates to:
  /// **'Add multi-person task'**
  String get mermaidCatalogActionAddMultiPersonTask;

  /// No description provided for @mermaidCatalogActionAddCommit.
  ///
  /// In en, this message translates to:
  /// **'Add commit'**
  String get mermaidCatalogActionAddCommit;

  /// No description provided for @mermaidCatalogActionCreateBranch.
  ///
  /// In en, this message translates to:
  /// **'Create branch'**
  String get mermaidCatalogActionCreateBranch;

  /// No description provided for @mermaidCatalogActionSwitchBranch.
  ///
  /// In en, this message translates to:
  /// **'Switch branch'**
  String get mermaidCatalogActionSwitchBranch;

  /// No description provided for @mermaidCatalogActionMergeBranch.
  ///
  /// In en, this message translates to:
  /// **'Merge branch'**
  String get mermaidCatalogActionMergeBranch;

  /// No description provided for @mermaidCatalogActionAddBranch.
  ///
  /// In en, this message translates to:
  /// **'Add branch'**
  String get mermaidCatalogActionAddBranch;

  /// No description provided for @mermaidCatalogActionAddChildBranch.
  ///
  /// In en, this message translates to:
  /// **'Add child branch'**
  String get mermaidCatalogActionAddChildBranch;

  /// No description provided for @mermaidCatalogActionAddTopic.
  ///
  /// In en, this message translates to:
  /// **'Add topic'**
  String get mermaidCatalogActionAddTopic;

  /// No description provided for @mermaidCatalogActionAddPeriod.
  ///
  /// In en, this message translates to:
  /// **'Add period'**
  String get mermaidCatalogActionAddPeriod;

  /// No description provided for @mermaidCatalogActionAddBlock.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get mermaidCatalogActionAddBlock;

  /// No description provided for @mermaidCatalogActionAddColumns.
  ///
  /// In en, this message translates to:
  /// **'Add columns'**
  String get mermaidCatalogActionAddColumns;

  /// No description provided for @mermaidCatalogActionAddConnection.
  ///
  /// In en, this message translates to:
  /// **'Add connection'**
  String get mermaidCatalogActionAddConnection;

  /// No description provided for @mermaidCatalogActionAddChildBlock.
  ///
  /// In en, this message translates to:
  /// **'Add child block'**
  String get mermaidCatalogActionAddChildBlock;

  /// No description provided for @mermaidCatalogActionAddRequirement.
  ///
  /// In en, this message translates to:
  /// **'Add requirement'**
  String get mermaidCatalogActionAddRequirement;

  /// No description provided for @mermaidCatalogActionAddElement.
  ///
  /// In en, this message translates to:
  /// **'Add element'**
  String get mermaidCatalogActionAddElement;

  /// No description provided for @mermaidCatalogActionAddVerification.
  ///
  /// In en, this message translates to:
  /// **'Add verification'**
  String get mermaidCatalogActionAddVerification;

  /// No description provided for @mermaidCatalogGanttDependencyBaseTask.
  ///
  /// In en, this message translates to:
  /// **'Dependency base task'**
  String get mermaidCatalogGanttDependencyBaseTask;

  /// No description provided for @mermaidCatalogGanttDependentTaskName.
  ///
  /// In en, this message translates to:
  /// **'Follow-up task'**
  String get mermaidCatalogGanttDependentTaskName;

  /// No description provided for @startupMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Data format upgrade complete'**
  String get startupMigrationTitle;

  /// No description provided for @startupMigrationBody.
  ///
  /// In en, this message translates to:
  /// **'Your data has been migrated to the new format. Restart the app to use the updated version.'**
  String get startupMigrationBody;

  /// No description provided for @startupMigrationExit.
  ///
  /// In en, this message translates to:
  /// **'Exit app'**
  String get startupMigrationExit;

  /// No description provided for @startupMigrationRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get startupMigrationRestart;

  /// No description provided for @startupRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'App startup error'**
  String get startupRecoveryTitle;

  /// No description provided for @startupRecoveryFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'A data format issue was encountered during startup and repaired automatically. Please try again.'**
  String get startupRecoveryFallbackMessage;

  /// No description provided for @startupRecoveryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get startupRecoveryRetry;

  /// No description provided for @asrFailureDiagnosticFormat.
  ///
  /// In en, this message translates to:
  /// **'ASR {category} at {stage}{chunk}: {message}'**
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  );

  /// No description provided for @asrFailureChunkPosition.
  ///
  /// In en, this message translates to:
  /// **', chunk {index}/{count}'**
  String asrFailureChunkPosition(Object index, Object count);

  /// No description provided for @asrFailureRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {detail}'**
  String asrFailureRequestFailed(Object detail);

  /// No description provided for @asrChunkAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Chunked transcription failed ({count} chunks, none succeeded)'**
  String asrChunkAllFailed(Object count);

  /// No description provided for @asrChunkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Chunked transcription is incomplete ({succeeded}/{count} chunks succeeded)'**
  String asrChunkIncomplete(Object succeeded, Object count);

  /// No description provided for @asrChunkSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded: {detail}'**
  String asrChunkSucceeded(Object detail);

  /// No description provided for @asrChunkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {detail}'**
  String asrChunkFailed(Object detail);

  /// No description provided for @asrChunkUncertain.
  ///
  /// In en, this message translates to:
  /// **'Outcome uncertain: {detail}'**
  String asrChunkUncertain(Object detail);

  /// No description provided for @asrChunkDetails.
  ///
  /// In en, this message translates to:
  /// **'Chunk {index} ({start}–{end}s) {status}'**
  String asrChunkDetails(Object index, Object start, Object end, Object status);

  /// No description provided for @asrChunkCheckpointFailure.
  ///
  /// In en, this message translates to:
  /// **'Saving chunk status failed: {detail}'**
  String asrChunkCheckpointFailure(Object detail);

  /// No description provided for @asrChunkUncertainGuidance.
  ///
  /// In en, this message translates to:
  /// **'Request outcome is uncertain. Retrying has stopped to avoid duplicate submissions. Select the audio again to create a new task.'**
  String get asrChunkUncertainGuidance;

  /// No description provided for @asrRetryAudioLost.
  ///
  /// In en, this message translates to:
  /// **'The original audio file was lost. Select the audio again to retry: {audioName}'**
  String asrRetryAudioLost(Object audioName);

  /// No description provided for @asrRetryAudioCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The original audio file is corrupted. Select the audio again to retry: {audioName}'**
  String asrRetryAudioCorrupt(Object audioName);

  /// No description provided for @asrFailureChunkIndex.
  ///
  /// In en, this message translates to:
  /// **', chunk {index}'**
  String asrFailureChunkIndex(Object index);

  /// No description provided for @asrChunkDetailsSeparator.
  ///
  /// In en, this message translates to:
  /// **'; '**
  String get asrChunkDetailsSeparator;

  /// No description provided for @asrRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'ASR recognition failed: {detail}'**
  String asrRecognitionFailed(Object detail);

  /// No description provided for @asrFailureCategoryAuthentication.
  ///
  /// In en, this message translates to:
  /// **'authentication'**
  String get asrFailureCategoryAuthentication;

  /// No description provided for @asrFailureCategoryRateLimit.
  ///
  /// In en, this message translates to:
  /// **'rate limit'**
  String get asrFailureCategoryRateLimit;

  /// No description provided for @asrFailureCategorySizeLimit.
  ///
  /// In en, this message translates to:
  /// **'size limit'**
  String get asrFailureCategorySizeLimit;

  /// No description provided for @asrFailureCategoryNetwork.
  ///
  /// In en, this message translates to:
  /// **'network'**
  String get asrFailureCategoryNetwork;

  /// No description provided for @asrFailureCategoryResponseParsing.
  ///
  /// In en, this message translates to:
  /// **'response parsing'**
  String get asrFailureCategoryResponseParsing;

  /// No description provided for @asrFailureCategoryLocalProcessing.
  ///
  /// In en, this message translates to:
  /// **'local processing'**
  String get asrFailureCategoryLocalProcessing;

  /// No description provided for @asrFailureCategoryProvider.
  ///
  /// In en, this message translates to:
  /// **'provider'**
  String get asrFailureCategoryProvider;

  /// No description provided for @asrFailureCategoryUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get asrFailureCategoryUnknown;

  /// No description provided for @asrFailureStagePreprocessing.
  ///
  /// In en, this message translates to:
  /// **'preprocessing'**
  String get asrFailureStagePreprocessing;

  /// No description provided for @asrFailureStageEncoding.
  ///
  /// In en, this message translates to:
  /// **'encoding'**
  String get asrFailureStageEncoding;

  /// No description provided for @asrFailureStageValidation.
  ///
  /// In en, this message translates to:
  /// **'validation'**
  String get asrFailureStageValidation;

  /// No description provided for @asrFailureStageRequest.
  ///
  /// In en, this message translates to:
  /// **'request'**
  String get asrFailureStageRequest;

  /// No description provided for @asrFailureStageUploading.
  ///
  /// In en, this message translates to:
  /// **'uploading'**
  String get asrFailureStageUploading;

  /// No description provided for @asrFailureStageWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get asrFailureStageWaiting;

  /// No description provided for @asrFailureStageReceiving.
  ///
  /// In en, this message translates to:
  /// **'receiving'**
  String get asrFailureStageReceiving;

  /// No description provided for @asrFailureStageResponse.
  ///
  /// In en, this message translates to:
  /// **'response'**
  String get asrFailureStageResponse;

  /// No description provided for @asrFailureStageParsing.
  ///
  /// In en, this message translates to:
  /// **'parsing'**
  String get asrFailureStageParsing;

  /// No description provided for @asrFailureStageStorage.
  ///
  /// In en, this message translates to:
  /// **'storage'**
  String get asrFailureStageStorage;

  /// No description provided for @chatMissingProvider.
  ///
  /// In en, this message translates to:
  /// **'Please configure a chat provider first'**
  String get chatMissingProvider;

  /// No description provided for @anthropicStreamApiError.
  ///
  /// In en, this message translates to:
  /// **'Anthropic API error: {detail}'**
  String anthropicStreamApiError(Object detail);

  /// No description provided for @anthropicStreamUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get anthropicStreamUnknownError;

  /// No description provided for @chatHttpRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'API request failed (HTTP {statusCode}): {detail}'**
  String chatHttpRequestFailed(Object statusCode, Object detail);

  /// No description provided for @fileUploadApiKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'API key is not configured; file upload is unavailable'**
  String get fileUploadApiKeyMissing;

  /// No description provided for @fileUploadApiUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'API URL is not configured; file upload is unavailable'**
  String get fileUploadApiUrlMissing;

  /// No description provided for @fileUploadContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'File content is empty'**
  String get fileUploadContentEmpty;

  /// No description provided for @fileUploadFilenameEmpty.
  ///
  /// In en, this message translates to:
  /// **'File name is empty'**
  String get fileUploadFilenameEmpty;

  /// No description provided for @fileUploadMimeTypeEmpty.
  ///
  /// In en, this message translates to:
  /// **'MIME type is empty'**
  String get fileUploadMimeTypeEmpty;

  /// No description provided for @fileUploadPurposeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Upload purpose is empty'**
  String get fileUploadPurposeEmpty;

  /// No description provided for @fileUploadCanceled.
  ///
  /// In en, this message translates to:
  /// **'File upload was canceled'**
  String get fileUploadCanceled;

  /// No description provided for @fileUploadCreateMissingId.
  ///
  /// In en, this message translates to:
  /// **'Upload creation failed: response is missing upload id'**
  String get fileUploadCreateMissingId;

  /// No description provided for @fileUploadPartMissingId.
  ///
  /// In en, this message translates to:
  /// **'Part upload failed: response is missing part id'**
  String get fileUploadPartMissingId;

  /// No description provided for @fileUploadCompleteMissingFile.
  ///
  /// In en, this message translates to:
  /// **'Upload completion failed: response is missing file object'**
  String get fileUploadCompleteMissingFile;

  /// No description provided for @fileUploadMissingFileId.
  ///
  /// In en, this message translates to:
  /// **'File upload failed: response is missing file id'**
  String get fileUploadMissingFileId;

  /// No description provided for @fileUploadRequestFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'File upload request failed (HTTP {statusCode}): {detail}'**
  String fileUploadRequestFailedStatus(Object statusCode, Object detail);

  /// No description provided for @fileUploadRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'File upload request failed: {detail}'**
  String fileUploadRequestFailed(Object detail);

  /// No description provided for @chatApiKeyNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'API key is not configured'**
  String get chatApiKeyNotConfigured;

  /// No description provided for @chatStreamError.
  ///
  /// In en, this message translates to:
  /// **'API stream error: {detail}'**
  String chatStreamError(Object detail);

  /// No description provided for @chatChoicesMissing.
  ///
  /// In en, this message translates to:
  /// **'API response has no choices'**
  String get chatChoicesMissing;

  /// No description provided for @chatContentBlocksMissing.
  ///
  /// In en, this message translates to:
  /// **'API response has no content blocks'**
  String get chatContentBlocksMissing;

  /// No description provided for @chatResponseContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'API response content is empty'**
  String get chatResponseContentEmpty;

  /// No description provided for @chatRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {detail}'**
  String chatRequestFailed(Object detail);

  /// No description provided for @startupTagline.
  ///
  /// In en, this message translates to:
  /// **'Your learning assistant'**
  String get startupTagline;

  /// No description provided for @startupProgressDataSafety.
  ///
  /// In en, this message translates to:
  /// **'Checking data safety...'**
  String get startupProgressDataSafety;

  /// No description provided for @startupProgressFormatVersion.
  ///
  /// In en, this message translates to:
  /// **'Checking data format version...'**
  String get startupProgressFormatVersion;

  /// No description provided for @startupProgressDataFormat.
  ///
  /// In en, this message translates to:
  /// **'Validating data formats...'**
  String get startupProgressDataFormat;

  /// No description provided for @startupProgressDataIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Checking data integrity...'**
  String get startupProgressDataIntegrity;

  /// No description provided for @startupProgressResults.
  ///
  /// In en, this message translates to:
  /// **'Processing check results...'**
  String get startupProgressResults;

  /// No description provided for @startupProgressCompleteWithWarnings.
  ///
  /// In en, this message translates to:
  /// **'Startup complete (note: {warning})'**
  String startupProgressCompleteWithWarnings(Object warning);

  /// No description provided for @startupProgressCompleteAfterMigration.
  ///
  /// In en, this message translates to:
  /// **'Data checks complete. Preparing to start the app.'**
  String get startupProgressCompleteAfterMigration;

  /// No description provided for @startupProgressReady.
  ///
  /// In en, this message translates to:
  /// **'Preparing to start the app.'**
  String get startupProgressReady;

  /// No description provided for @startupWarningErrorCount.
  ///
  /// In en, this message translates to:
  /// **'Found {count} data issue(s):'**
  String startupWarningErrorCount(Object count);

  /// No description provided for @startupWarningWarningCount.
  ///
  /// In en, this message translates to:
  /// **'{count} warning(s):'**
  String startupWarningWarningCount(Object count);

  /// No description provided for @startupIssueProviderEntriesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Provider entries have an invalid format: expected a JSON array.'**
  String get startupIssueProviderEntriesInvalid;

  /// No description provided for @startupIssueProviderEntryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index} is null or has an invalid type.'**
  String startupIssueProviderEntryInvalid(Object index);

  /// No description provided for @startupIssueProviderIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index} is missing an ID or has an empty ID.'**
  String startupIssueProviderIdMissing(Object index);

  /// No description provided for @startupIssueProviderTypeMissing.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index} is missing a type or has an empty type.'**
  String startupIssueProviderTypeMissing(Object index);

  /// No description provided for @startupIssueProviderNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index} is missing a name or has an empty name.'**
  String startupIssueProviderNameMissing(Object index);

  /// No description provided for @startupIssueProviderListInvalid.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index} field {field} is not a valid list.'**
  String startupIssueProviderListInvalid(Object index, Object field);

  /// No description provided for @startupIssueProviderNestedItemInvalid.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index}, {field} contains an invalid item that may cause a parsing failure.'**
  String startupIssueProviderNestedItemInvalid(Object index, Object field);

  /// No description provided for @startupIssueConversationsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Conversations have an invalid format: expected a JSON array.'**
  String get startupIssueConversationsInvalid;

  /// No description provided for @startupIssueConversationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Conversation {index} is null or has an invalid type.'**
  String startupIssueConversationInvalid(Object index);

  /// No description provided for @startupIssueConversationIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Conversation {index} is missing an ID.'**
  String startupIssueConversationIdMissing(Object index);

  /// No description provided for @startupIssueConversationMessagesMissing.
  ///
  /// In en, this message translates to:
  /// **'Conversation {index} is missing its messages field.'**
  String startupIssueConversationMessagesMissing(Object index);

  /// No description provided for @startupIssueConversationMessagesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Conversation {index} messages field is not a valid list.'**
  String startupIssueConversationMessagesInvalid(Object index);

  /// No description provided for @startupIssueUnknownProviderType.
  ///
  /// In en, this message translates to:
  /// **'Provider entry {index} uses unknown provider type \"{type}\" and may not work correctly.'**
  String startupIssueUnknownProviderType(Object index, Object type);
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
