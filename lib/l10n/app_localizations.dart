Warning: truncated output (original token count: 155823)
Total output lines: 18595

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

  /// …140823 tokens truncated…milestone'**
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

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'App startup failed'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String startupErrorDetails(Object error);

  /// No description provided for @renderErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface rendering error'**
  String get renderErrorTitle;

  /// No description provided for @renderErrorDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface rendering error (Debug mode)'**
  String get renderErrorDebugTitle;

  /// No description provided for @renderErrorRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'Please try restarting the app.'**
  String get renderErrorRestartMessage;

  /// No description provided for @backupRestoreApkgImportSummary.
  ///
  /// In en, this message translates to:
  /// **'Imported {decks} decks, {notes} notes, and {cards} cards'**
  String backupRestoreApkgImportSummary(int decks, int notes, int cards);

  /// No description provided for @backupRestoreApkgFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The selected .apkg file could not be found: {path}'**
  String backupRestoreApkgFileNotFound(String path);

  /// No description provided for @backupRestoreApkgCollectionMissing.
  ///
  /// In en, this message translates to:
  /// **'The .apkg file does not contain collection.anki2.'**
  String get backupRestoreApkgCollectionMissing;

  /// No description provided for @backupRestoreApkgTargetMissing.
  ///
  /// In en, this message translates to:
  /// **'Open Anki flashcards before importing or exporting a deck: {path}'**
  String backupRestoreApkgTargetMissing(String path);

  /// No description provided for @backupRestoreApkgDatabaseCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The Anki collection database is damaged.'**
  String get backupRestoreApkgDatabaseCorrupt;

  /// No description provided for @backupRestoreApkgUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'The .apkg operation failed while accessing this path: {path}'**
  String backupRestoreApkgUnexpectedError(String path);

  /// No description provided for @backupRestoreApkgOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The .apkg operation failed because the file or database could not be read.'**
  String get backupRestoreApkgOperationFailed;

  /// No description provided for @backupRestoreApkgExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The Anki deck could not be packaged from this database: {path}'**
  String backupRestoreApkgExportFailed(String path);

  /// No description provided for @ankiWebSyncUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Sign in to AnkiWeb to sync on web. Open Anki settings with the cloud icon to log in.'**
  String get ankiWebSyncUnsupportedPlatform;

  /// No description provided for @ankiWebDecksUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'To browse or manage decks on web, sign in to AnkiWeb using the cloud icon.'**
  String get ankiWebDecksUnsupportedPlatform;

  /// No description provided for @ankiStatsUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Anki statistics are unavailable on this platform.'**
  String get ankiStatsUnsupportedPlatform;

  /// No description provided for @ankiSyncStatusDeviceClockMismatch.
  ///
  /// In en, this message translates to:
  /// **'The device clock differs from the sync server by more than 5 minutes. Correct the clock and try again.'**
  String get ankiSyncStatusDeviceClockMismatch;

  /// No description provided for @ankiSyncStatusFullDownloadRequired.
  ///
  /// In en, this message translates to:
  /// **'The sync sanity check failed and local changes were rolled back. Download the server collection in full, then try again.'**
  String get ankiSyncStatusFullDownloadRequired;

  /// No description provided for @ankiSyncStatusFullTransferRequired.
  ///
  /// In en, this message translates to:
  /// **'This collection cannot be synchronized incrementally. Choose a full upload or download to continue.'**
  String get ankiSyncStatusFullTransferRequired;

  /// No description provided for @ankiSyncStatusIncrementalSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Incremental sync could not complete. Check the server and connection, then try again.'**
  String get ankiSyncStatusIncrementalSyncFailed;

  /// No description provided for @ankiSyncStatusProtocolFailed.
  String get ankiSyncStatusProtocolFailed;
  /// No description provided for @ankiSyncStatusLoginRequired.
  String get ankiSyncStatusLoginRequired;
  /// No description provided for @ankiSyncStatusInvalidServerUrl.
  String get ankiSyncStatusInvalidServerUrl;
  /// No description provided for @ankiSyncStatusHttpsRequired.
  String get ankiSyncStatusHttpsRequired;
  /// No description provided for @ankiSyncStatusConnectionTimeout.
  String get ankiSyncStatusConnectionTimeout;
  /// No description provided for @ankiSyncStatusTlsFailure.
  String get ankiSyncStatusTlsFailure;
  /// No description provided for @ankiSyncStatusConnectionFailure.
  String get ankiSyncStatusConnectionFailure;
  /// No description provided for @ankiSyncStatusRequestFailure.
  String get ankiSyncStatusRequestFailure;
  /// No description provided for @ankiSyncStatusServerHttpError.
  String ankiSyncStatusServerHttpError(int statusCode);
  /// No description provided for @ankiSyncStatusResponseTooLarge.
  String ankiSyncStatusResponseTooLarge(int limitMb);
  /// No description provided for @ankiSyncStatusLocalFileFailure.
  String get ankiSyncStatusLocalFileFailure;

  String get batchDlgFileName;
  String get batchDlgFolderName;
  String get batchDlgFileNameConflict;
  String get batchDlgFolderNameConflict;
  String get batchDlgFolderNameSwapConflict;
  String get batchDlgControlCharacterError;
  String get batchDlgNameWhitespaceError;
  String batchDlgNameEmpty(String kind);
  String batchDlgNameTrailingWhitespace(String kind);
  String batchDlgNameTooLong(String kind, String count);
  String batchDlgNameIllegalCharacters(String kind);
  String batchDlgNameTrailingDot(String kind);
  String batchDlgNameReserved(String kind);
  String get batchDlgIntermediateNameTooLong;
  String batchDlgTemplateMissingDate(String date);
  String get batchDlgCreatedDate;
  String get batchDlgModifiedDate;
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
