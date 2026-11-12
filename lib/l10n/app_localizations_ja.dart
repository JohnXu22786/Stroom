// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get galleryPermissionTitle => '写真ライブラリへのアクセスが必要です';

  @override
  String get galleryPermissionMessage =>
      'システム設定で Stroom が写真やビデオにアクセスできるようにします。';

  @override
  String get galleryPermissionCancel => 'キャンセル';

  @override
  String get galleryPermissionOpenSettings => '設定を開く';

  @override
  String get languageSettingsTitle => '言語';

  @override
  String get followSystemLanguage => 'システムの言語に従う';

  @override
  String get themeDisplaySettingsTitle => 'テーマとディスプレイ';

  @override
  String get themeDisplayThemeSection => 'テーマ';

  @override
  String get themeModeLight => 'ライトモード';

  @override
  String get themeModeDark => 'ダークモード';

  @override
  String get themeModeSystem => 'システム設定に従う';

  @override
  String get languageNameEnglish => '英語';

  @override
  String get languageNameChinese => '中国語（簡体字）';

  @override
  String get languageNameKorean => '韓国語';

  @override
  String get languageNamePortuguese => 'ポルトガル語（ブラジル）';

  @override
  String get languageSearchHint => '検索言語';

  @override
  String get languageNoMatches => '一致する言語がありません';

  @override
  String get builtInPromptGeneralName => '一般アシスタント';

  @override
  String get builtInPromptGeneralDescription => '日常会話や幅広い質問に答えてくれる万能AIアシスタント。';

  @override
  String get builtInPromptGeneralPrompt =>
      'あなたは役に立つ AI アシスタントです。ユーザーが使用する言語でユーザーに応答します。簡潔、明確、論理的に整理してください。何か不明な点がある場合は、正直に言ってください。';

  @override
  String get builtInPromptCodeExpertName => 'コードエキスパート';

  @override
  String get builtInPromptCodeExpertDescription =>
      '多くのプログラミング言語とテクノロジースタックに関する専門知識を持つ経験豊富なプログラマー。';

  @override
  String get builtInPromptCodeExpertPrompt =>
      'あなたは、多くのプログラミング言語とテクノロジー スタックに精通した経験豊富なソフトウェア エンジニアです。ユーザーの質問に基づいて、高品質のコード例、技術的な説明、ベスト プラクティスの推奨事項を提供します。読みやすさ、パフォーマンス、セキュリティを優先します。コードを提供するときは、言語にラベルを付け、適切な形式を使用してください。システム設計に関する質問については、アーキテクチャの観点からトレードオフを分析します。';

  @override
  String get builtInPromptTranslationName => '翻訳アシスタント';

  @override
  String get builtInPromptTranslationDescription =>
      'プロの翻訳者が多言語翻訳とローカリゼーションに関するアドバイスを提供します。';

  @override
  String get builtInPromptTranslationPrompt =>
      'あなたはプロの翻訳者です。あなたの責任は次のとおりです。\n1. ユーザーが提供したコンテンツを、そのスタイルとトーンを維持しながら正確に翻訳します。\n2. ユーザーが特定の言語で何かを言う方法を尋ねた場合は、自然な表現を返します。\n3. 文化的に特殊なコンテンツのローカライゼーションに関するアドバイスを提供します。\n4. 複数の翻訳が可能な場合は、それらを列挙し、その違いを説明します。\n常に最初にソース言語とターゲット言語を特定します。どちらかが不明な場合はユーザーに尋ねます。';

  @override
  String get builtInPromptEnglishTeacherName => '英語教師';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      'リスニング、スピーキング、リーディング、ライティングの向上をサポートする英語学習家庭教師。';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      'あなたは経験豊富な英語教師です。ユーザーのニーズを満たすには:\n1. 文法の説明: ルールを例を含めて明確に説明します。\n2. 語彙学習: 単語の使用法、連語、区別を説明します。\n3. 文章を磨きます: 自然に聞こえるように英語を上達させます。\n4. 会話練習: 英語を話す状況をシミュレートします。\n5. 発音ガイダンス: 発音記号とおおよその発音を使用します。\nユーザーの英語レベルに合わせて難易度を調整し、日本語で補足してください。';

  @override
  String get builtInPromptInterviewerName => 'インタビュアー';

  @override
  String get builtInPromptInterviewerDescription => '技術面接および行動面接のための模擬面接官。';

  @override
  String get builtInPromptInterviewerPrompt =>
      'あなたはプロのインタビュアーです。ユーザーの対象となる役割に対して練習用の面接を実行します。\n1. まずは目指す職種と業界を知る。\n2. 関連する技術的、動作的、およびシステム設計に関する質問をします。\n3. ユーザーの回答を評価し、改善を提案します。\n4. 回答例と推論を提供します。\n5. 現実的なペースを保ちます。1 つか 2 つの質問をして、ユーザーを待ちます。\nユーザーの面接スキルの向上を支援することを目標に、プロフェッショナルかつフレンドリーに接してください。';

  @override
  String get builtInPromptWritingName => 'ライティングアシスタント';

  @override
  String get builtInPromptWritingDescription =>
      'さまざまなジャンルのクリエイティブなライティングの執筆および編集アシスタント。';

  @override
  String get builtInPromptWritingPrompt =>
      'あなたはプロのライティングコンサルタントです。ユーザーのニーズに基づいて、以下を提供します。\n1. ドラフト: 議論、説明、物語などのジャンルで執筆します。\n2. 編集: 文法、単語の選択、論理、構造、表現を改善します。\n3. 概要: フレームワークを構築し、重要なポイントを特定するのに役立ちます。\n4. 創造的なアイデア: インスピレーションと可能な角度を提供します。\n5. フォーマット: 対象ジャンルと提出要件の規則に従います。\nまず目的、対象読者、求められるスタイルを理解し、焦点を絞ったアドバイスを行います。';

  @override
  String get builtInPromptCreativeThinkerName => 'クリエイティブシンカー';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      '新鮮なアイデアを生み出す創造的なアイデアとブレインストーミングのパートナー。';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      'あなたは創造的思考のパートナーです。あなたのタスクは次のとおりです。\n1. ブレーンストーミング: トピックに関してさまざまな創造的な方向性を提案します。\n2. コンセプトの開発: 既存のアイデアを深め、拡張します。\n3. 分野を接続する: さまざまな分野の概念を新しい方法で組み合わせます。\n4. 逆に考える: 従来の考え方に挑戦し、珍しい視点を提供します。\n5. 実現可能性のレビュー: 導入の課題と潜在的な価値を分析します。\n適切なタイミングで議論に焦点を当てながら、発散的な思考を奨励します。 1 つの応答につき 3 ～ 5 つの指示を提供します。';

  @override
  String get builtInPromptDataAnalystName => 'データアナリスト';

  @override
  String get builtInPromptDataAnalystDescription =>
      'データの理解、モデル化、視覚化を支援するデータ分析の専門家。';

  @override
  String get builtInPromptDataAnalystPrompt =>
      'あなたはデータ分析の専門家です。ユーザーの質問に基づいて、次の情報を提供します。\n1. 分析方法: 適切な統計手法と分析フレームワークを選択します。\n2. SQL/Python/R コード: データ処理と分析の例を示します。\n3. 視覚化に関するアドバイス: 適切なチャートの種類とツールを推奨します。\n4. 解釈: 調査結果とそのビジネス上の意味を説明します。\n5. データ クリーニング: 欠損値、外れ値、その他の品質問題を処理します。\nまずは分析の目的とデータの特徴を明確にします。 Python エコシステム (pandas、numpy、matplotlib、seaborn) を好みます。';

  @override
  String get builtInPromptRoleplayName => 'ロールプレイ';

  @override
  String get builtInPromptRoleplayDescription => '没入型の複数キャラクターのロールプレイング体験。';

  @override
  String get builtInPromptRoleplayPrompt =>
      'ロールプレイモードを開始しました。ユーザーが指定したキャラクターを演じ、その性格、口調、知識に沿って対話してください。\n1. ユーザーが「[キャラクター]を演じて」と言ったら、すぐにそのキャラクターに切り替えてください。\n2. 会話中はそのキャラクターを演じ続けてください。\n3. キャラクターの説明に合わせて、話し方や知識を調整してください。\n4. ユーザーは「ロールプレイを終了」と言って終了できます。\n5. キャラクターに合った自然な架空の情報を加えてもかまいません。\nユーザーが演じるキャラクターを指定するまで待ってください。';

  @override
  String get builtInPromptLifeAdvisorName => 'ライフアドバイザー';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      '温かく思慮深い聞き手で、メンタルヘルスのサポートや日常のアドバイスを提供します。';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      'あなたは温かく思慮深いライフアドバイザーです。あなたの責任は次のとおりです。\n1. 積極的に耳を傾け、ユーザーの懸念や感情的なニーズを理解します。\n2. 問題を合理的に分析し、ユーザーが問題の側面を整理できるようにします。\n3. 日常生活を改善するための具体的で実行可能な方法を提供します。\n4. 理解、励まし、積極的なサポートを提供します。\n5. 必要な場合は、専門家の助けを提案してください。\n覚えておいてください：あなたは認可されたメンタルヘルスカウンセラーではありません。深刻なメンタルヘルス危機の場合は、ユーザーに専門家の助けを求めるよう勧めてください。行き過ぎずに共感を持ちましょう。ユーザーに代わって決定を下すことなく、ユーザーをサポートします。';

  @override
  String get builtInSystemTitleName => 'タイトルアシスタント';

  @override
  String get builtInSystemTitleDescription => '会話から短いタイトルを自動的に生成します。';

  @override
  String get builtInSystemTitlePrompt =>
      'あなたはタイトルジェネレーターです。会話のタイトルを 1 つ出力し、それ以外は何も出力しません。\n\nルール:\n- 1 行、50 文字以内で入力してください。\n- 説明したり、引用符を使用したりしないでください。\n- ユーザーのメッセージと同じ言語を使用します。\n- タイトルに web_search や todowrite などのツール名を含めないでください。\n\n例:\n「プロダクション 500 エラーのデバッグを手伝ってください」 → プロダクション 500 エラーのデバッグ\n「ユーザーサービスのリファクタリング」 → ユーザーサービスのリファクタリング\n「なぜ app.js が失敗するのでしょうか?」 → app.js のトラブルシューティング\n\nユーザーのメッセージが非常に短い場合、または単なる挨拶 (「こんにちは」、「はは」、「いますか?」など) の場合は、挨拶、カジュアルなおしゃべり、簡単な確認など、その口調や意図を反映したタイトルを作成します。';

  @override
  String get builtInSystemCompactionName => 'コンテキスト圧縮アシスタント';

  @override
  String get builtInSystemCompactionDescription =>
      '長い会話を構造化されたアンカー付きの要約に凝縮し、自由なコンテキスト スペースを確保します。';

  @override
  String get builtInSystemCompactionPrompt =>
      'あなたはアンカーされたコンテキストの要約アシスタントです。長い会話を構造化された要約に凝縮します。\n\n提供された会話履歴のみを要約します。最近のメッセージはそのまま保存される場合があるため、依然として重要な古いコンテキストに注目してください。\n\nプロンプトに <previous-summary> ブロックが含まれている場合は、それを現在のアンカーされた概要として扱います。つまり、依然として真実である内容を保持し、古い内容を削除し、新しい事実を統合します。\n\nこの構造に正確に従ってください。セクションの順序を維持し、空であってもすべてのセクションを含めます。\n<テンプレート>\n## 目的\n- [ユーザーの目標を 1 ～ 2 文で説明]\n\n## 重要な詳細\n- [制約/好み、決定と理由、重要な事実/仮定、続行に必要な正確な背景。空の場合は(なし)を書き込みます]\n\n## 作業状態\n### 完了\n- [完了した作業、確認された事実、または行われた変更。空の場合は(なし)を書き込みます]\n\n### アクティブ\n- [現在の作業、一部変更、または調査;空の場合は(なし)を書き込みます]\n\n### ブロックされました\n- [ブロッカー、失敗したコマンド、または未知のもの。空の場合は(なし)を書き込みます]\n\n## 次の動き\n1. [次の特定のアクション、または (なし)]\n2. [既知のフォローアップアクション、または (なし)]\n\n## 関連ファイル\n- [ファイルまたはディレクトリのパスとそれが重要な理由;空の場合は(なし)を書き込みます]\n</テンプレート>\n\nルール:\n- 空の場合でも、すべてのセクションを含めます。\n- 段落ではなく、簡潔な箇条書きを使用します。\n- 正確なファイル パス、シンボル、コマンド、エラー メッセージ、URL、識別子を保存します。\n- コンテキストを要約、圧縮、または結合していることには触れないでください。\n- 会話と同じ言語を使用します。';

  @override
  String get builtInPromptMarketTitle => 'アシスタントマーケット';

  @override
  String get builtInPromptClose => '閉じる';

  @override
  String get builtInPromptImportHint =>
      'インポートされたプロンプトは、自由に編集できる通常のアシスタントになります。';

  @override
  String get builtInPromptView => 'プロンプトを表示';

  @override
  String get builtInPromptAdd => '追加';

  @override
  String get builtInPromptDescriptionHeading => '説明';

  @override
  String get builtInPromptSystemPromptHeading => 'システムプロンプト';

  @override
  String get builtInPromptAddAssistant => 'アシスタントの追加';

  @override
  String builtInPromptViewerTitle(Object name) {
    return 'プロンプト · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      '別のモデルを構成し、タイトルの自動生成とコンテキストの圧縮を求めるプロンプトを表示します。デフォルトでは、現在のチャット モデルと組み込みプロンプトが使用されます。';

  @override
  String get systemAssistantTitleName => 'タイトル生成アシスタント';

  @override
  String get systemAssistantTitleDescription => '会話タイトルを自動生成';

  @override
  String get systemAssistantCompactionName => 'コンテキスト圧縮アシスタント';

  @override
  String get systemAssistantCompactionDescription => '長い会話をアンカー付きの要約に凝縮する';

  @override
  String get systemAssistantFollowCurrentModel => '現在のチャット モデルに従ってください';

  @override
  String get systemAssistantChooseModel => 'モデルを選択してください';

  @override
  String get systemAssistantResetPromptTitle => 'デフォルトのプロンプトにリセット';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '「$taskTitle」の組み込みのデフォルト プロンプトを復元しますか?現在のカスタム プロンプトは破棄されます。';
  }

  @override
  String get systemAssistantCancel => 'キャンセル';

  @override
  String get systemAssistantReset => 'リセット';

  @override
  String get systemAssistantModelHeading => 'モデル';

  @override
  String get systemAssistantPromptHeading => 'プロンプト';

  @override
  String get systemAssistantCustomPromptHint => '変更はカスタム プロンプトとして使用されます';

  @override
  String get systemAssistantUsingCustomPrompt => 'カスタムプロンプトの使用';

  @override
  String get systemAssistantUsingDefaultPrompt => 'デフォルトのプロンプトを使用する';

  @override
  String get systemAssistantSave => '保存';

  @override
  String get systemAssistantResetButton => 'デフォルトのプロンプトにリセット';

  @override
  String get taskFlowPageTitle => 'タスクフロー';

  @override
  String get taskFlowSampleTemplatesTooltip => 'テンプレートの例';

  @override
  String get taskFlowEmptyState => 'まだフローはありません。 + をタップして作成します。';

  @override
  String get taskFlowStartFromTemplate => 'テンプレートから始める';

  @override
  String get taskFlowChooseTemplate => 'サンプルテンプレートを選択してください';

  @override
  String get taskFlowTemplateIntroduction => '必要なものに近いフローを選択してください。後で調整できます。';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のテンプレート',
      one: '$count 件のテンプレート',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      'テンプレートは設定が必要なドラフトとして開きます。保存する前にモデルとアシスタントを選択してください。';

  @override
  String get taskFlowTemplateRecordingName => '録音を文字に起こして要約する';

  @override
  String get taskFlowTemplateRecordingDescription => '録音を選択→音声認識→アシスタントの概要';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'ASR モデルを構成し、要約のアシスタントを選択します。';

  @override
  String get taskFlowTemplateImageTextName => '画像テキストの認識と整理';

  @override
  String get taskFlowTemplateImageTextDescription => '画像を選択→テキスト認識→アシスタント組織';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'OCR モデルを設定し、テキストを整理するアシスタントを選択します。';

  @override
  String get taskFlowTemplateReadImageName => '画像からテキストを読み取る';

  @override
  String get taskFlowTemplateReadImageDescription => '画像を選択 → テキスト認識 → 音声再生';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'OCR および音声合成モデルを設定し、音声を選択します。';

  @override
  String get taskFlowActions => 'フローアクション';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のブロック',
      one: '$count 個のブロック',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'OCR';

  @override
  String get taskFlowBlockAsr => '音声認識';

  @override
  String get taskFlowBlockAudioSeparation => '音声の分離';

  @override
  String get taskFlowBlockCatCatch => 'Webリソースのダウンロード';

  @override
  String get taskFlowBlockTts => '音声合成';

  @override
  String get taskFlowBlockChat => 'アシスタントチャット';

  @override
  String get taskFlowBlockCustom => 'カスタムブロック';

  @override
  String get taskFlowEdit => '編集';

  @override
  String get taskFlowCopy => 'コピー';

  @override
  String get taskFlowCopied => 'コピーされました';

  @override
  String get taskFlowDelete => '消去';

  @override
  String get taskFlowConfirmDelete => '削除の確認';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return 'タスクフロー「$flowName」を削除しますか?';
  }

  @override
  String get taskFlowUseTemplate => '使用';

  @override
  String get taskFlowOcrInputMissing => '画像ファイルが見つかりませんでした。再度画像を選択してください。';

  @override
  String get taskFlowOcrInputReadFailed =>
      '画像ファイルを読み取れませんでした。ファイルアクセスを確認して、再試行してください。';

  @override
  String get taskFlowOcrModelUnavailable =>
      '使用可能な OCR モデルが設定されていません。フロー設定で OCR プロバイダーとモデルを選択します。';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'OCR リクエスト サイズの予算 ($size MiB)';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return 'タスク フロー イメージの入力制限 ($size MiB)';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return '画像は$limitを超えています。より小さい画像を選択して、もう一度試してください。';
  }

  @override
  String get ocrTemplatePlainTextLabel => 'プレーンテキスト';

  @override
  String get ocrTemplatePlainTextContent =>
      '表示されているすべてのテキストをページの自然な読み順で、改行と段落を維持して転記します。プレーンテキストのみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrTemplateMarkdownLabel => 'マークダウン';

  @override
  String get ocrTemplateMarkdownContent =>
      '表示されているすべてのテキストをページの自然な読み順で転記し、Markdown を使用して見出し、リスト、表を保持します。 LaTeX で数式を表現します。転写のみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrTemplateTableLabel => 'テーブル';

  @override
  String get ocrTemplateTableContent =>
      '表示されているすべてのテキストをページの自然な読み順で書き写します。テーブルの場合、ヘッダー、行と列の関係、空のセルを保持し、Markdown テーブルとして出力します。他のコンテンツは通常のテキストとして保持します。転写のみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrTemplateLatexLabel => 'ラテックス';

  @override
  String get ocrTemplateLatexContent =>
      '表示されているすべてのテキストをページの自然な読み順で書き写します。数式以外のテキストを保持し、LaTeX で数式を表現します。インライン式には \$...\$ を使用し、表示式には \$\$...\$\$ を使用します。転写のみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrDefaultImagesOnly => 'デフォルト（画像のみ送信）';

  @override
  String get ocrDefaultSystemPrompt =>
      '元の書式とレイアウトを維持したまま、画像からすべてのテキストを抽出します。抽出されたテキストのみを返します。何も説明を加えないでください。';

  @override
  String get ocrSavedInstructionSnapshot => '保存された命令のスナップショット';

  @override
  String get ocrPageTitle => '画像テキスト認識';

  @override
  String get ocrImageQualitySettings => '画質設定';

  @override
  String get ocrImageQualityStandard => '標準品質';

  @override
  String get ocrImageQualityStandardHint => 'ほとんどのユースケースでは小さい画像';

  @override
  String get ocrImageQualityOriginal => 'オリジナル/ハイディテール';

  @override
  String get ocrImageQualityOriginalHint => 'より詳細な情報を保持します。画像とリクエストが大きくなります';

  @override
  String get ocrReorderDone => '終わり';

  @override
  String get ocrReorderAction => '再注文';

  @override
  String get ocrClearAction => 'クリア';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return '前のタスクではモデル $modelId を使用しました。プロバイダーとモデルを再度選択してください。';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      '前回の再試行レコード内のモデル位置が無効です。再度モデルを選択してください。';

  @override
  String get ocrLegacyModelPositionConfirm =>
      '前回の再試行記録では、モデルの位置のみが保存されました。続行する前に現在のモデルを確認してください。';

  @override
  String get ocrModelUnavailable =>
      '元の OCR プロバイダーまたはモデルは利用できなくなりました。別のものを選択してください。';

  @override
  String get ocrModelLabel => 'モデル';

  @override
  String get ocrConfigure => '設定する';

  @override
  String get ocrSelectModel => 'モデルを選択してください';

  @override
  String get ocrInstructionLabel => '命令';

  @override
  String get ocrManageInstructions => '認識指示の管理';

  @override
  String get ocrInstructionManageGuidance =>
      'これらの手順はすべての認識モデルに適用されます。何も選択されていない場合は、画像のみが送信されます。';

  @override
  String get ocrInstructionManageEmpty => 'まだ指示がありません';

  @override
  String get ocrInstructionEditTooltip => '編集命令';

  @override
  String get ocrInstructionDeleteTooltip => '削除命令';

  @override
  String get ocrInstructionAdd => '命令の追加';

  @override
  String get ocrInstructionEditorEditTitle => '編集命令';

  @override
  String get ocrInstructionNameLabel => '命令名(オプション)';

  @override
  String get ocrInstructionContentLabel => '指導内容';

  @override
  String get ocrBatchMode => 'バッチモード';

  @override
  String get ocrMergeRecognition => '結果を結合する';

  @override
  String get ocrRecognizeEachImage => '各画像を個別に認識する';

  @override
  String get ocrMaxConcurrency => '最大 2 つの同時リクエスト';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の同時リクエスト',
      one: '$count 件の同時リクエスト',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の同時リクエスト',
      one: '$count 件の同時リクエスト',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint => '完了したページは保持されます。再試行は未完了のページのみを送信します。';

  @override
  String get ocrTakePhoto => '写真を撮ってください';

  @override
  String get ocrChooseFromAlbum => 'アルバムから選ぶ';

  @override
  String get ocrNoImagesSelected => '画像が選択されていません';

  @override
  String get ocrSelectImagesHint => '写真を撮るか、アルバムから複数の画像を選択して認識します。';

  @override
  String ocrRechooseRequiredImages(num count) {
    return '再試行する前に、必要な画像をすべて選択し直してください（$count 枚）。';
  }

  @override
  String ocrImageLabel(Object index) {
    return '画像 $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return '画像_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => '無効な画像インデックス';

  @override
  String get ocrViewErrorDetails => 'エラーの詳細を表示する';

  @override
  String get ocrConfirmModel => 'このモデルを確認する';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枚の画像を選択中',
      one: '$count 枚の画像を選択中',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => '画像を準備中…';

  @override
  String get ocrSavingRetryImages => 'リトライ画像を保存中…';

  @override
  String get ocrRecognizing => '認識中…';

  @override
  String get ocrReadingRetryImages => 'リトライイメージを読み込んでいます…';

  @override
  String get ocrImportingImages => '画像をインポート中…';

  @override
  String get ocrStartRecognition => '認識を開始する';

  @override
  String get ocrSaveTo => '保存先';

  @override
  String get ocrRootDirectory => 'ルートディレクトリ';

  @override
  String get ocrChooseSaveFolder => '保存先のフォルダーを選択してください';

  @override
  String get ocrChooseImageSource => '画像ソースを選択してください';

  @override
  String get ocrChooseAppAlbum => 'アプリアルバムから選択';

  @override
  String get ocrAppAlbumDescription => 'アプリにすでに保存されている画像を選択してください';

  @override
  String get ocrChooseSystemAlbum => 'システムアルバムから選ぶ';

  @override
  String get ocrSystemAlbumDescription => 'このデバイス上の画像を参照して選択します';

  @override
  String ocrTakePhotoFailed(Object error) {
    return '写真の撮影に失敗しました: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枚の画像を読み込みました',
      one: '$count 枚の画像を読み込みました',
    );
    return '$_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return '画像の処理に失敗しました: $error';
  }

  @override
  String get ocrUnknownSourceImageCount => '元の画像数を特定できません';

  @override
  String get ocrConfirmClear => 'クリアを確認する';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      '元の OCR 画像キャッシュが利用できないため、その画像数を回復できません。クリアすると、古い再試行状態がリセットされます。この OCR タスク用にすべての画像を再度選択します。';

  @override
  String get ocrConfirmClearSelected => '選択した OCR 画像をクリアしますか?';

  @override
  String get ocrCancel => 'キャンセル';

  @override
  String get ocrConfirmResetAndReselect => 'リセットして再度画像を選択してください';

  @override
  String get ocrRequestCheckFailed => 'OCR リクエストを確認できません。モデルパラメータを確認してください。';

  @override
  String get ocrCancelledAdjustAndRetry =>
      '認識がキャンセルされました。プロバイダー/モデルのリクエスト サイズまたは画質を調整して、再試行してください。';

  @override
  String get ocrRequestSizeExceededTitle => 'OCR リクエストが設定されたサイズを超えています';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return 'リクエストは約 $requestSize MiB で、構成された $limit MiB 制限を超えています。';
  }

  @override
  String get ocrRequestSizeHelp =>
      'プロバイダーのデフォルトまたはモデルのオーバーライドでリクエスト サイズを調整するか、別の画質を選択します。画質を変更した後、画像をクリアして再度インポートしてください。';

  @override
  String get ocrUsePerImageMode => '画像ごとの認識を使用する';

  @override
  String get ocrGotIt => 'わかった';

  @override
  String get ocrWaitForImport => '画像のインポートが完了するまで待ってから認識を開始してください。';

  @override
  String get ocrWaitForRetryImages => 'リトライイメージの読み込み。お待ちください。';

  @override
  String get ocrConfigureProviderModel => '最初に [設定] で OCR プロバイダーとモデルを構成します。';

  @override
  String get ocrReselectProviderModel => 'OCR プロバイダーとモデルを再度選択します。';

  @override
  String get ocrConfirmLegacyModel => 'まず、前回のリトライ記録から OCR モデルを確認します。';

  @override
  String get ocrRetryImagesUnavailable =>
      'オリジナルの OCR 画像キャッシュは利用できません。タスクをクリアして、すべての画像を再度選択します。';

  @override
  String get ocrRetryImageCountUnknown =>
      '元の OCR 画像キャッシュは利用できず、その画像数は不明です。リセットして、この OCR タスクのすべての画像を再度選択します。';

  @override
  String get ocrRetryImageReset =>
      '前回の再試行入力がリセットされました。この OCR タスク用にすべての画像を再度選択します。';

  @override
  String get ocrRetryImagesUnreadable =>
      '元の OCR 画像キャッシュを読み取れませんでした。タスクをクリアして、すべての画像を再度選択します。';

  @override
  String get ocrRetryImagesMissing =>
      '元の OCR 画像キャッシュが見つからないか破損しています。タスクをクリアして、すべての画像を再度選択します。';

  @override
  String get ocrImageListChanged => '画像リストを変更しました。再度認識を開始します。';

  @override
  String get ocrReadInstructionFailed => '認識命令を読み取ることができません。もう一度やり直してください。';

  @override
  String get ocrErrorDetails => 'エラーの詳細';

  @override
  String get ocrRequestHeading => 'リクエスト';

  @override
  String get ocrResponseHeading => '応答';

  @override
  String get ocrNoDetails => '詳細はありません';

  @override
  String get ocrImageLoadFailed => '画像をロードできません';

  @override
  String get ocrCrop => '作物';

  @override
  String get ocrEdit => '編集';

  @override
  String get ocrProcessingOcrFailed => 'OCR画像の処理に失敗しました。もう一度試してください。';

  @override
  String get settingsPageTitle => '設定';

  @override
  String get settingsSectionGeneral => '一般的な';

  @override
  String get settingsSectionProviders => 'プロバイダー';

  @override
  String get settingsSectionSystemAssistant => 'システムアシスタント';

  @override
  String get settingsSectionContextManagement => 'コンテキスト管理';

  @override
  String get settingsSectionManagement => '管理';

  @override
  String get settingsSectionAbout => 'について';

  @override
  String get settingsBackupRestore => 'バックアップと復元';

  @override
  String get settingsBackupRestoreDescription => 'アプリデータのエクスポートまたはインポート';

  @override
  String get settingsCookies => 'Cookie とブラウザデータ';

  @override
  String get settingsCookiesDescription => '永続的な Cookie とブラウザのストレージを管理する';

  @override
  String get settingsAppLogs => 'アプリのログ';

  @override
  String get settingsAppLogsDescription => 'アプリの実行時ログを表示する';

  @override
  String get settingsThemeDisplay => 'テーマと表示';

  @override
  String get settingsThemeDisplayDescription => 'ダークモードと表示言語';

  @override
  String get settingsTaskNotifications => 'タスク完了通知';

  @override
  String get settingsTaskNotificationsDescription =>
      '通知の許可とシステム設定を確認し、通知ガイドを表示します';

  @override
  String get settingsBackgroundOptimization => 'バックグラウンド操作の最適化';

  @override
  String get settingsBackgroundOptimizationDescription =>
      'システム環境やバックグラウンドサービスの状態を確認し、最適化ガイダンスを表示します';

  @override
  String get aboutVersionInfo => 'バージョン情報を表示する';

  @override
  String get aboutCheckUpdates => 'アップデートをチェックする';

  @override
  String aboutNewVersionFound(Object version) {
    return '新しいバージョン $version が利用可能になりました';
  }

  @override
  String get aboutNewVersion => '新しいバージョン';

  @override
  String get aboutPreviewUpdates => 'プレビューアップデート';

  @override
  String get aboutPreviewUpdatesDescription => 'プレビュー リリースのチェックを有効にする';

  @override
  String get aboutProjectHome => 'プロジェクトホーム';

  @override
  String get aboutFeedback => '問題を報告する';

  @override
  String get aboutPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get aboutOpenSourceAgreement => 'オープンソース契約';

  @override
  String get aboutOpenSourceLicenses => 'オープンソースライセンス';

  @override
  String get aboutCheckingUpdates => 'アップデートをチェック中…';

  @override
  String get aboutUpToDate => '最新バージョンを使用しています';

  @override
  String aboutUpdateNetworkError(Object details) {
    return 'ネットワークエラー: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return '更新チェックが HTTP ステータス $statusCode で失敗しました。';
  }

  @override
  String get aboutUpdateInvalidResponse => '更新サーバーが予期しない応答を返しました。';

  @override
  String get aboutUpdateCheckFailed => 'アップデートチェックに失敗しました。もう一度試してください。';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return 'アシスタントの更新チェックに失敗しました: $error';
  }

  @override
  String get aboutPrivacyContent =>
      'Stroom は、サービスを使用するすべての人のプライバシーを尊重し、保護します。\n\n1. カメラ許可: 写真を撮るためにのみ使用されます。画像データの収集やアップロードは行われません。\n\n2. 写真ライブラリの許可: 写真を選択して保存するためにのみ使用されます。すべての写真はデバイス上にローカルに保存されます。\n\n3. データのセキュリティ: 撮影したすべての写真はデバイス上にローカルに保存されます。当社はあなたのデータにアクセスしたりアップロードしたりすることはありません。\n\n4. サードパーティのサービス: このアプリにはサードパーティの分析サービスや広告サービスは含まれません。\n\nご質問がございましたらお問い合わせください。';

  @override
  String get aboutClose => '閉じる';

  @override
  String get contextToolPruneTitle => 'ツールの結果を自動的にプルーニングする (Prune)';

  @override
  String get contextToolPruneDescription =>
      'しきい値を超える古いツールの結果をプレースホルダーに自動的に置き換えて、ストレージとコンテキストを解放します。';

  @override
  String get contextCompactionTriggerSettings => '圧縮トリガーの設定';

  @override
  String get contextCompactionDisabled => '無効 (圧縮は実行されません)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return 'グローバルトリガー $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のモデル別設定',
      one: '$count 件のモデル別設定',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => '圧縮トリガーの設定';

  @override
  String get contextAutoCompaction => '自動コンテキスト圧縮';

  @override
  String get contextAutoCompactionDisabled => '無効にすると、どのモデルでも圧縮は実行されません。';

  @override
  String get contextGlobalTrigger => 'グローバルトリガーの割合';

  @override
  String get contextGlobalTriggerDescription =>
      '個別設定のないモデルは、モデル コンテキスト ウィンドウのこのパーセンテージを圧縮トリガーとして使用します。';

  @override
  String contextResetPercent(Object percent) {
    return '$percent%にリセット';
  }

  @override
  String get contextPerModelSettings => 'モデルごとの設定';

  @override
  String get contextNoConfiguredModels => '設定されたモデルはありません';

  @override
  String contextIndependentThreshold(Object threshold) {
    return '独立したしきい値: $threshold トークン';
  }

  @override
  String get contextEnterIndependentThreshold => '以下に独立したしきい値を入力してください';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return 'グローバル $percent% をフォローしてください';
  }

  @override
  String get contextThresholdField => '独立したしきい値（トークン）';

  @override
  String get contextThresholdHint => 'たとえば、48000 (パーセントではなくトークン数)';

  @override
  String get contextPercentField => 'パーセンテージ';

  @override
  String contextPercentHint(Object percent) {
    return 'たとえば、$percent';
  }

  @override
  String get versionInfoTitle => 'バージョン情報';

  @override
  String get versionNumberLabel => 'バージョン';

  @override
  String get versionReleaseTimeLabel => 'リリース時間';

  @override
  String get versionLocalBuild => 'ローカルビルド';

  @override
  String get versionReleaseNotesLabel => 'リリースノート';

  @override
  String get versionClose => '閉じる';

  @override
  String get updateDialogTitle => '新しいバージョンが利用可能になりました';

  @override
  String get updateLatestVersionLabel => '最新バージョン';

  @override
  String get updateSelectedVersionLabel => '選択したバージョン';

  @override
  String get updateReleaseNotesLabel => 'リリースノート';

  @override
  String get updateInstalling => 'インストール中…';

  @override
  String get updateDownloadComplete => 'ダウンロード完了';

  @override
  String get updateClose => '閉じる';

  @override
  String get updateManualInstall => '手動でインストールする';

  @override
  String get updateOpenInstaller => 'インストーラーを開く';

  @override
  String get updateRetryDownload => 'ダウンロードを再試行します';

  @override
  String get updateSkipVersion => 'このバージョンをスキップする';

  @override
  String get updateRemindLater => '後で思い出してください';

  @override
  String get updateOpenBrowser => 'ブラウザでダウンロード';

  @override
  String get updateNow => '今すぐアップデートしてください';

  @override
  String get updatePreviewBadge => 'プレビュー';

  @override
  String get updateLatestBadge => '最新';

  @override
  String get updateSelectVersion => 'バージョンの選択';

  @override
  String get updateDownloading => 'アップデートをダウンロード中…';

  @override
  String updateCheckNetworkError(Object details) {
    return 'ネットワークエラー: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return 'アップデートのチェックに失敗しました: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      '更新のチェックに失敗しました: サーバーは認識できないデータを返しました';

  @override
  String get updateDownloadUrlUnavailable => 'ダウンロード URL が利用できません。';

  @override
  String get updateNoDirectDownloadLink =>
      'このプラットフォームには直接ダウンロード リンクはありません。ブラウザでダウンロードします。';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return '自動インストールに失敗しました: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return 'ダウンロードに失敗しました: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return 'ダウンロードに失敗しました: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return 'インストールに失敗しました: $details';
  }

  @override
  String updateFailed(Object details) {
    return '更新に失敗しました: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return 'ファイルを開けませんでした。手動でインストールします: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return 'インストールに失敗しました。 APKを手動で開きます: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails => 'インストールに失敗しました。 APKを手動で開きます。';

  @override
  String get updateApkInstallerUnavailable =>
      'この APK をインストールするアプリが見つかりませんでした。手動で開きます。';

  @override
  String get updateApkInstallPermissionDenied =>
      'Stroom がシステム設定で不明なアプリをインストールできるようにします。';

  @override
  String get updateRestartDialogTitle => 'アプリが更新されました';

  @override
  String get updateRestartDialogBody => 'アプリが更新されました。安定性を確保するためにアプリを再起動します。';

  @override
  String get updateRestartDialogLater => '後で再起動する';

  @override
  String get updateRestartDialogNow => '今すぐ再起動してください';

  @override
  String get contextCompactionHistoryIntro => '要約する会話履歴:';

  @override
  String get contextCompactionUserRole => 'ユーザー';

  @override
  String get contextCompactionAssistantRole => 'アシスタント';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role がツール $toolName を呼び出しました: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      'テンプレートに正確に従って、上記の会話履歴をアンカー付きの要約に要約します。';

  @override
  String get ocrImageEmpty => '画像は空です。もう一度選択してください。';

  @override
  String get ocrImageUnsupportedFormat =>
      'この画像形式はサポートされていません。 PNG、JPEG、または WebP に変換して、再試行してください。';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'HEIC、SVG、TIFF 画像はまだサポートされていません。画像を PNG、JPEG、または WebP に変換して、再試行してください。';

  @override
  String get ocrImageDecodeFailed =>
      '画像が破損しているか、デコードできません。再度選択するか、PNG、JPEG、または WebP に変換して再試行してください。';

  @override
  String get ocrImageDimensionsTooLarge =>
      '画像の解像度が大きすぎます。 OCR は、画像あたり最大 5,000 万ピクセルをサポートします。サイズを変更して再試行してください。';

  @override
  String get ocrImageOrientationPngTooLarge =>
      'この画像の方向を修正するために必要な PNG は、OCR リクエストのサイズ制限を超えます。画像のサイズを変更して再試行してください。';

  @override
  String get ocrImageOrientationFailed =>
      '画像の向きを補正できませんでした。 PNG、JPEG、または WebP に変換して、再試行してください。';

  @override
  String get ocrImagePreparationFailed => '画像を処理できませんでした。もう一度選択して、もう一度試してください。';

  @override
  String get homeTitle => '家';

  @override
  String get homeWelcome => 'スルームへようこそ';

  @override
  String get homeChooseModule => '開始するにはモジュールを選択してください';

  @override
  String get homeOcrSubtitle => 'テキスト認識';

  @override
  String get homeAsrTitle => '音声認識';

  @override
  String get homeAsrSubtitle => '音声をテキストに変換';

  @override
  String get homeWebDownloadTitle => 'ウェブメディアをダウンロードする';

  @override
  String get homeWebDownloadSubtitle => 'Webページからオーディオとビデオをダウンロードする';

  @override
  String get homeAudioSeparationTitle => '音声の分離';

  @override
  String get homeAudioSeparationSubtitle => 'ビデオから音声を抽出する';

  @override
  String get homeTtsTitle => 'テキスト読み上げ';

  @override
  String get homeTtsSubtitle => 'テキストを音声に変換する';

  @override
  String get homeChartsTitle => 'チャートメーカー';

  @override
  String get homeChartsSubtitle => 'マーメイドチャートエディター';

  @override
  String get homeMathTitle => '数学的なプロット';

  @override
  String get homeMathSubtitle => 'プロット関数';

  @override
  String get homeAnkiTitle => 'アンキのフラッシュカード';

  @override
  String get homeAnkiSubtitle => '記憶補助システム';

  @override
  String get homeTaskFlowTitle => 'タスクフロー';

  @override
  String get homeTaskFlowEmpty => '複数のモジュールを順番に実行する自動フローを作成する';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のタスクフロー · 管理',
      one: '$count 件のタスクフロー · 管理',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => '最近のタスク';

  @override
  String get homeViewAll => 'すべて見る';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusFailed => '失敗した';

  @override
  String get navHome => '家';

  @override
  String get navChat => 'チャット';

  @override
  String get navFiles => 'ファイル';

  @override
  String get navSettings => '設定';

  @override
  String get conversationsTitle => '会話履歴';

  @override
  String get conversationNew => '新しい会話';

  @override
  String get conversationSelectTitle => '会話を選択してください';

  @override
  String get topicSelectionEmptyTitle => 'まだ会話はありません';

  @override
  String get topicSelectionEmptyMessage => '新しい会話を作成して始めてください';

  @override
  String get topicSelectionNewTopic => '新しい会話';

  @override
  String get topicSelectionNoAssistant => 'アシスタントが選択されていません';

  @override
  String get topicSelectionBackToAssistants => 'アシスタントの選択に戻る';

  @override
  String get topicSelectionEditAssistant => '編集アシスタント';

  @override
  String get topicSelectionReorderHint => '長押ししてドラッグして会話を並べ替えます';

  @override
  String conversationDeleteNamed(String title) {
    return '会話「$title」を削除しますか?これを元に戻すことはできません。';
  }

  @override
  String get conversationDeleteTitle => '会話を削除する';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選択した会話を $count 件削除しますか？この操作は元に戻せません。',
      one: '選択した会話を $count 件削除しますか？この操作は元に戻せません。',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionDelete => '消去';

  @override
  String get conversationRename => '会話の名前を変更する';

  @override
  String get conversationRenameHint => '新しい名前を入力してください';

  @override
  String get actionConfirm => '確認する';

  @override
  String get conversationNoMatches => '一致する会話が見つかりませんでした';

  @override
  String get conversationEmpty => '会話履歴がありません';

  @override
  String get conversationSearchHint => 'すべての会話内のメッセージを検索します...';

  @override
  String conversationSelected(int count) {
    return '$countが選択されました';
  }

  @override
  String get conversationSearch => '検索';

  @override
  String get conversationDeleteSelected => '選択したものを削除';

  @override
  String get actionUnselect => '選択をキャンセルする';

  @override
  String get actionSelect => '選択';

  @override
  String conversationDeleteCount(int count) {
    return '$countを削除';
  }

  @override
  String get conversationPin => 'ピン';

  @override
  String get conversationUnpin => '固定を解除する';

  @override
  String get actionRename => '名前の変更';

  @override
  String get conversationAutoRename => '自動名前付け';

  @override
  String get conversationTemporary => '一時的な会話';

  @override
  String get conversationCloseTemporary => '一時的な会話を閉じる';

  @override
  String get taskListTitle => 'タスクリスト';

  @override
  String get taskListEmpty => 'タスクがありません';

  @override
  String get unifiedTaskListTabAll => '全て';

  @override
  String get unifiedTaskListTabInProgress => '進行中';

  @override
  String get unifiedTaskListTabCompleted => '完了';

  @override
  String get unifiedTaskListTabFailed => '失敗した';

  @override
  String get unifiedTaskListTabStopped => '停止しました';

  @override
  String get unifiedTaskListConfirmClear => 'クリアを確認する';

  @override
  String get unifiedTaskListConfirmClearFailedMessage =>
      '失敗したタスクをすべてクリアしてもよろしいですか?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      'すべてのタスクをクリアしてもよろしいですか?この操作は元に戻すことができません。';

  @override
  String get unifiedTaskListCancel => 'キャンセル';

  @override
  String get unifiedTaskListConfirm => '確認する';

  @override
  String get unifiedTaskListClearCompleted => '完了したタスクをクリアする';

  @override
  String get unifiedTaskListClearFailed => '失敗したタスクをクリアする';

  @override
  String get unifiedTaskListClearAll => 'すべてのタスクをクリアする';

  @override
  String get unifiedTaskListRestoreInProgress => 'タスク フロー レコードを復元しています…';

  @override
  String get unifiedTaskListRestoreFailed =>
      'タスク フロー レコードを読み取れませんでした。タスクのアクションは一時停止されます';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return '未クリア: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning => 'タスク・フローはキャンセル後も実行中です。';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      'タスク・フローのキャンセル状態を保存できませんでした。再度クリアをお試しください。';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      'タスク・フロー・レコードの削除を保存できませんでした。再度クリアをお試しください。';

  @override
  String get chatAutoContinuePrompt => '完了していない場合は続行します。';

  @override
  String get chatSearchCurrent => 'この会話を検索...';

  @override
  String get chatSearchAll => 'すべての会話を検索...';

  @override
  String get searchPrevious => '前回の試合';

  @override
  String get searchNext => '次の試合';

  @override
  String get searchClose => '検索を閉じる';

  @override
  String get searchCurrentConversation => '現在の会話';

  @override
  String get searchAllConversations => 'すべての会話';

  @override
  String get chatReasoning => '推論';

  @override
  String get chatTools => 'ツール';

  @override
  String get chatCustomParameters => 'カスタムパラメータ';

  @override
  String get chatEditMessage => 'メッセージを編集する';

  @override
  String get actionClose => '閉じる';

  @override
  String get chatEditWarning => '編集して再送信すると、以下のメッセージはすべて失われます';

  @override
  String get chatAttachment => 'アタッチメント';

  @override
  String get chatMessageHint => 'メッセージを入力してください...';

  @override
  String get chatFullscreenEdit => '全画面エディター';

  @override
  String get chatStopGeneration => '生成を停止する';

  @override
  String get actionSend => '送信';

  @override
  String get chatCopy => 'コピー';

  @override
  String get actionSave => '保存';

  @override
  String get actionRetry => 'リトライ';

  @override
  String get actionEdit => '編集';

  @override
  String get chatViewResponseData => '応答データの表示';

  @override
  String get chatViewRequestData => 'リクエストデータの表示';

  @override
  String get chatInspectJson => 'JSONを検査する';

  @override
  String get chatConfirmEditTitle => 'メッセージを編集する';

  @override
  String get chatConfirmEditDeleteFollowing =>
      'このメッセージを編集しますか?このメッセージとこれ以降のメッセージはすべて削除されます。';

  @override
  String get chatConfirmResend => 'このメッセージを再送信しますか?';

  @override
  String get chatConfirmRetryTitle => 'リトライ';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      'この応答を再試行しますか?このメッセージとこれ以降のメッセージはすべて削除されます。';

  @override
  String get chatConfirmRegenerate => '応答を再生成しますか?';

  @override
  String get chatDeleteMessageTitle => 'メッセージを削除する';

  @override
  String get chatDeleteMessageConfirm => 'このメッセージを削除しますか?これを元に戻すことはできません。';

  @override
  String get chatThinking => '考え';

  @override
  String get chatThinkingComplete => '考え';

  @override
  String get conversationDeleteOne => 'この会話を削除しますか?これを元に戻すことはできません。';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'リソース $selected/$total 件を選択中',
      one: 'リソース $selected/$total 件を選択中',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => 'ダウンロードするメディアを選択してください';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のセグメントを非表示',
      one: '$count 個のセグメントを非表示',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のセグメントを表示',
      one: '$count 個のセグメントを表示',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => 'リソースが検出されませんでした';

  @override
  String get mediaSegment => 'セグメント';

  @override
  String get mediaPlaylist => 'プレイリスト';

  @override
  String get mediaFullVideo => 'フルビデオ';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours 時間 $minutes 分 $seconds 秒';
  }

  @override
  String mediaDuration(String value) {
    return '期間: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return '解像度: ${width}x$height';
  }

  @override
  String get mediaPreview => 'プレビュー';

  @override
  String get mediaSegmentPreviewHint => 'プレイリストからセグメントをプレビューする';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選択したリソースを $count 件ダウンロード',
      one: '選択したリソースを $count 件ダウンロード',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => 'ダウンロードの確認';

  @override
  String get chatNoMoreHistory => 'これ以上のメッセージはありません';

  @override
  String get chatSendFailed => 'メッセージの送信に失敗しました';

  @override
  String get chatViewErrorDetails => 'エラーの詳細を表示する';

  @override
  String get chatCompactionCollapsed =>
      'コンテキストが圧縮され、古いメッセージが要約されました (クリックして折りたたむ)';

  @override
  String get chatCompactionExpanded =>
      'コンテキストが圧縮され、古いメッセージが要約されました (クリックして要約を表示)';

  @override
  String get chatEditConversationTitle => '会話のタイトルを編集する';

  @override
  String get chatSearchMessages => 'メッセージを検索する';

  @override
  String get chatApiMissingSettings => '⚠️ チャット API が設定されていません — 設定に移動してください';

  @override
  String get appSettings => '設定';

  @override
  String get chatCopied => 'コピーされました';

  @override
  String get chatNoSavableText => '保存するテキストがありません';

  @override
  String get chatSaveMarkdownTitle => 'メッセージをマークダウンとして保存';

  @override
  String get chatSaveToolCallChoice =>
      'この応答には複数のツール呼び出しが含まれています。保存するものを選択してください:';

  @override
  String get chatSaveCompleteMessage => '完了したメッセージを保存する';

  @override
  String get chatSaveLastMessage => '最後のメッセージを保存する';

  @override
  String get chatSaveToAppFiles => 'アプリファイルに保存';

  @override
  String get chatSaveFolderHint => '.md ファイル用のフォルダーを選択または作成します';

  @override
  String get chatSaveFilenameHint => 'ファイル名を入力します（.mdが自動的に追加されます）';

  @override
  String get chatFilenameRequired => 'ファイル名を空にすることはできません';

  @override
  String chatSavedToPath(String path) {
    return '保存先: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return 'アプリファイルに保存: $path';
  }

  @override
  String get chatSelectModel => 'モデルを選択してください';

  @override
  String get chatModelFallback => 'モデル';

  @override
  String get chatNoModelsAvailable => '利用可能なモデルはありません';

  @override
  String get chatAvailableTools => '利用可能なツール';

  @override
  String get chatNoToolsAvailable => '利用可能なツールがありません';

  @override
  String get chatReasoningSettings => '推論設定';

  @override
  String get chatReasoningNotConfigured =>
      'このモデルには推論パラメーターが構成されていません。モデル設定に追加します。';

  @override
  String get chatReasoningEffort => '推論の努力';

  @override
  String get chatReasoningEffortNotConfigured =>
      'このモデルには推論努力パラメーターが構成されていません。モデル設定に追加します。';

  @override
  String get chatParameterNoOptions => 'このパラメータにはオプション値はありません。モデル設定に追加します。';

  @override
  String get chatOtherReasoningNotConfigured =>
      'このモデルには他の推論パラメーターは構成されていません。\nモデル設定に追加します。';

  @override
  String get chatCustomParamsNotConfigured =>
      'このモデルにはカスタム パラメーターは設定されていません。\nモデル設定に追加します。';

  @override
  String get chatNoOptionValues => 'オプション値はありません。モデル設定に追加します。';

  @override
  String get chatImageLoadFailed => '画像をロードできません';

  @override
  String get chatVideoLoadFailed => 'ビデオをロードできません';

  @override
  String get chatHtmlLoading => 'HTML プレビューを読み込んでいます...';

  @override
  String get chatPreviewLoadFailed => 'プレビューの読み込みに失敗しました';

  @override
  String get albumPickerLoadFailed => 'アプリアルバムを読み込めません';

  @override
  String get chatHtmlPreview => 'HTMLプレビュー';

  @override
  String get chatMermaidLoading => 'グラフのプレビューを読み込んでいます...';

  @override
  String get chatMermaidPreview => 'マーメイドプレビュー';

  @override
  String get chatZoomOut => 'ズームアウト';

  @override
  String get chatZoomIn => 'ズームイン';

  @override
  String get chatJsonInspection => 'JSON検査';

  @override
  String get chatNoRequestData => 'リクエストデータがありません';

  @override
  String get chatNoResponseData => '応答データがありません';

  @override
  String get chatSaveMessage => 'メッセージを保存する';

  @override
  String get chatChooseSaveLocation => 'メッセージを保存する場所を選択してください';

  @override
  String get chatChooseSaveLocationLabel => '保存場所を選択します:';

  @override
  String get chatSaveAppFile => 'アプリファイルに保存';

  @override
  String get chatSaveDevice => 'デバイスに保存';

  @override
  String get chatFileTypeAudio => '音声ファイル';

  @override
  String get chatFileTypeVideo => 'ビデオファイル';

  @override
  String get chatFileTypeDocument => '書類';

  @override
  String get chatFileTypeGeneric => 'ファイル';

  @override
  String get chatInfoType => 'タイプ';

  @override
  String get chatInfoSize => 'サイズ';

  @override
  String get chatInfoPath => 'パス';

  @override
  String get chatErrorBack => '戻る';

  @override
  String get chatErrorPrefix => 'エラー：';

  @override
  String get chatErrorCancelled => 'ユーザーによって出力が中断されました';

  @override
  String get chatErrorProviderNotConfigured =>
      'チャット API が設定されていません。 「設定」を開いてプロバイダーを構成します。';

  @override
  String get chatErrorApiKeyNotConfigured => 'APIキーが設定されていません。設定を確認してください。';

  @override
  String get chatErrorServerConnection =>
      'サーバーに接続できません。ネットワーク接続と API アドレスを確認してください。';

  @override
  String get chatErrorNetworkConnection => 'ネットワーク接続に失敗しました。ネットワーク接続を確認してください。';

  @override
  String get chatErrorTimeout => '接続がタイムアウトしました。サーバーが応答しませんでした。';

  @override
  String chatAttachmentImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return '写真を撮影できませんでした: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform はデバイス ギャラリー アクセスをサポートしていません: $error';
  }

  @override
  String get chatAttachmentWebPlatform => 'ウェブブラウザ';

  @override
  String get chatAttachmentCurrentPlatform => 'このデバイス';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      'フォトライブラリへのアクセス許可を付与して、再試行してください。';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      'ブラウザの設定でこの Web サイトがファイルにアクセスできるようにしてください。';

  @override
  String get chatAttachmentGalleryFallbackHint =>
      'デバイスがギャラリーの選択をサポートしていることを確認してください。';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return '画像をインポートできませんでした: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform はファイル選択をサポートしていません: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint => 'ファイルへのアクセス権限を付与して、再試行してください。';

  @override
  String get chatAttachmentFileFallbackHint =>
      'デバイスがファイル選択をサポートしていることを確認してください。';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return 'ファイルをインポートできませんでした: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return '輸入品 $fileName';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return '編集した画像を保存できませんでした: $error';
  }

  @override
  String get chatDataDetails => 'データ詳細';

  @override
  String get chatErrorDetailOcrDiagnostics => 'OCR診断';

  @override
  String get chatErrorDetailRequestUrl => 'リクエストURL';

  @override
  String get chatErrorDetailRequestHeaders => 'リクエストヘッダー';

  @override
  String get chatErrorDetailRequestBody => 'リクエストボディ';

  @override
  String get chatErrorDetailStatusCode => 'ステータスコード';

  @override
  String get chatErrorDetailResponseHeaders => '応答ヘッダー';

  @override
  String get chatErrorDetailResponseBody => '応答本文';

  @override
  String get chatErrorDetailEmpty => '詳細なデータはありません';

  @override
  String get chatAudioPreviewClose => '閉じる';

  @override
  String get chatPreviewClose => 'プレビューを閉じる';

  @override
  String get actionBack => '戻る';

  @override
  String get chatCannotLoadFile => 'ファイルをロードできません';

  @override
  String chatThinkingNumbered(int index) {
    return '思考 $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '保存されていない変更を破棄しますか?';

  @override
  String get taskFlowUiDiscardBody => '戻ると、保存されていない変更はすべて失われます。';

  @override
  String get taskFlowUiContinueEditing => '編集を続ける';

  @override
  String get taskFlowUiDiscard => '破棄';

  @override
  String get taskFlowUiUndo => '元に戻す';

  @override
  String get taskFlowUiSave => '保存';

  @override
  String get taskFlowUiNameHint => 'タスクフロー名を入力してください';

  @override
  String get taskFlowUiDescriptionHint => '説明を追加します (オプション)';

  @override
  String get taskFlowUiNameRequired => 'タスクフロー名を入力してください';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return 'ステップ $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '「$block」には「$parameter」が必要です';
  }

  @override
  String get taskFlowUiSaveFailed => '保存できませんでした。変更内容はまだ残っています。もう一度やり直してください。';

  @override
  String get taskFlowUiRetry => 'リトライ';

  @override
  String get taskFlowUiUpdated => 'タスクフローが更新されました';

  @override
  String get taskFlowUiCreated => 'タスクフローが作成されました';

  @override
  String get taskFlowUiTitle => 'タスクフロー';

  @override
  String get taskFlowUiNotFound => 'タスクが見つかりません';

  @override
  String get taskFlowUiBack => '戻る';

  @override
  String get taskFlowUiEdit => '編集';

  @override
  String taskFlowUiInput(Object label) {
    return '入力 ($label)';
  }

  @override
  String get taskFlowUiInputHint => 'テキストまたはリンクを入力してください';

  @override
  String get taskFlowUiStart => 'タスクフローの開始';

  @override
  String get taskFlowUiNoInput => 'まだ入力がありません。以下をタップして Web リソースの URL を追加します。';

  @override
  String get taskFlowUiAddResource => 'Web リソースを追加する';

  @override
  String get taskFlowUiUrlHint => 'ビデオまたはオーディオ Web ページの URL を入力してください';

  @override
  String get taskFlowUiDeleteInput => 'この入力を削除します';

  @override
  String get taskFlowUiHour => '時';

  @override
  String get taskFlowUiMinute => '分';

  @override
  String get taskFlowUiSecond => '秒';

  @override
  String get taskFlowUiPreview => 'プレビュー:';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      'オプション: ビデオ リソースを長さによってフィルタリングします。利用可能なすべてのリソースを表示するには、空白のままにします。';

  @override
  String get taskFlowUiSelectImages => '画像を選択（複数）';

  @override
  String get taskFlowUiSelectAudio => '音声を選択（複数）';

  @override
  String get taskFlowUiSelectFiles => 'ファイルを選択（複数）';

  @override
  String get taskFlowUiSelectVideo => '動画を選択（複数）';

  @override
  String get taskFlowUiRemove => '取り除く';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return '削除されたファイルをクリーンアップできませんでした: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0.初期入力';

  @override
  String taskFlowUiInputType(Object type) {
    return '入力タイプ: $type';
  }

  @override
  String get taskFlowUiUserFlowInput => 'ユーザーがタスク・フローを実行するときに提供される入力';

  @override
  String taskFlowUiBlockInput(Object type) {
    return '入力: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return '出力: $type';
  }

  @override
  String get taskFlowUiParameters => 'パラメータ:';

  @override
  String get taskFlowUiClose => '閉じる';

  @override
  String get taskFlowUiSelectAppImages => 'アプリから画像を選択（複数）';

  @override
  String get taskFlowUiNoImages => '画像がありません';

  @override
  String get taskFlowUiSelectAppAudio => 'アプリから音声を選択（複数）';

  @override
  String get taskFlowUiNoAudio => '音声なし';

  @override
  String get taskFlowUiSelectAppVideo => 'アプリから動画を選択（複数）';

  @override
  String get taskFlowUiNoVideo => '動画はありません';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return 'ファイルを選択できませんでした: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '「$name」は$limit MBを超えています。より小さいファイルを選択してください。';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '「$name」が空であるか、読み取り不能です';
  }

  @override
  String get taskFlowUiSomeFilesMissing => '一部のファイルが欠落しているためスキップされました';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return '$count の選択されたファイルにアクセスできません。すべてのファイルを再度選択してください。';
  }

  @override
  String get taskFlowUiQueuedOne => 'タスクフローがキューに追加されました';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return '$count タスク フローをキューに追加しました';
  }

  @override
  String get taskFlowUiRunTitle => 'このラン';

  @override
  String get taskFlowUiCancelBatch => 'バッチ全体をキャンセルする';

  @override
  String get taskFlowUiRestoringRecords => 'タスク フロー レコードを復元しています…';

  @override
  String get taskFlowUiRecordsPaused =>
      'タスク フロー レコードをロードできませんでした。タスクのアクションは一時停止されます。';

  @override
  String get taskFlowUiRecordsCleared => 'この実行の記録は消去されました';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$finished/$total の実行が終了しました';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return '· $count レコードがクリアされました';
  }

  @override
  String get taskFlowUiTemporaryFiles => '一時中間ファイル';

  @override
  String get taskFlowUiAddBlock => 'ブロックの追加';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return 'ステップ $index の前にブロックを挿入';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      '隣接する両方のステップと互換性のあるブロックはありません。最初に隣接するステップを調整します。';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return 'ステップ $index の前に挿入';
  }

  @override
  String get taskFlowUiUnknown => '未知';

  @override
  String get taskFlowUiChooseBlock => 'ブロックを選択してください';

  @override
  String get taskFlowUiInsertBlock => 'インサートブロック';

  @override
  String get taskFlowUiPreviousOutput => '前のステップの出力';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return ';次のステップで必要なもの: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock => '現在のタイプと互換性のあるブロックはありません';

  @override
  String get taskFlowUiReplaceBlock => 'ブロックを置き換える';

  @override
  String get taskFlowUiBlockCompatibility =>
      'これは、互換性のある入力および出力タイプを持つブロックにのみ置き換えることができます。';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      '次のステップで結果が正常に保存された後にクリーンアップします。最後のステップは常に保持されます。';

  @override
  String get taskFlowUiSetParameters => 'パラメータを設定する';

  @override
  String get taskFlowUiReplace => '交換する';

  @override
  String get taskFlowUiViewParameters => 'タップしてパラメータを表示します';

  @override
  String get taskFlowUiTapSetParameters => 'タップしてパラメータを設定します';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return '不明なブロック: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => 'このブロック タイプは登録されていません';

  @override
  String taskFlowUiStepActions(Object index) {
    return 'ステップ $index のアクション';
  }

  @override
  String get taskFlowUiInsertBefore => '前に挿入';

  @override
  String get taskFlowUiInsertAfter => '後に挿入';

  @override
  String get taskFlowUiCopyBlock => '重複ブロック';

  @override
  String get taskFlowUiMoveUp => '上に移動';

  @override
  String get taskFlowUiMoveUpDisabled => '上に移動 (す​​でに最初)';

  @override
  String get taskFlowUiMoveDown => '下に移動';

  @override
  String get taskFlowUiMoveDownDisabled => '下に移動 (す​​でに最後)';

  @override
  String get taskFlowUiDeleteBlock => 'ブロックの削除';

  @override
  String taskFlowUiInputLabel(Object label) {
    return '入力: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return '出力: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return 'ブロックタイプ「$name」は登録されていません';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$labelの設定';
  }

  @override
  String get taskFlowUiSendToAssistant => 'アシスタントに送信されたユーザー メッセージは、前のステップの出力です';

  @override
  String get taskFlowUiTempSpaceInfo =>
      'このステップはフローの一時スペースに出力します。次のステップが正常に保存された後、出力はクリーンアップされます。一時モードが無効になっている場合、元の保存フォルダーは保存され、復元されます。';

  @override
  String get taskFlowUiNoExtraParameters => 'このブロックには追加のパラメーターはありません';

  @override
  String get taskFlowUiCancel => 'キャンセル';

  @override
  String get taskFlowUiConfirm => '確認する';

  @override
  String get taskFlowUiConfigureModelFirst => '最初にモデルを構成する';

  @override
  String get taskFlowUiModelUnavailable =>
      'モデルが選択されていないか、モデルが使用できません。別のモデルを選択してください。';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return '型式 $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => '名前のないプロバイダー';

  @override
  String get taskFlowUiCustomModelParameters => 'カスタムモデルパラメータ';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      'TTS モデルには音声が設定されていません。 ID は手動で入力できます。';

  @override
  String get taskFlowUiVoiceUnavailable => '音声が利用できません。別の音声を選択してください。';

  @override
  String get taskFlowUiSelectVoice => '音声を選択してください';

  @override
  String get taskFlowUiAssistantUnavailable => 'アシスタントが利用不可';

  @override
  String get taskFlowUiAssistantUseCurrent =>
      '指定されていません (現在選択されているアシスタントを使用します)';

  @override
  String get taskFlowUiAssistantDeleted =>
      '構成されたアシスタントが削除されました。別のアシスタントを選択してください。';

  @override
  String get taskFlowUiChooseAssistant => 'アシスタントを選択してください';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      '「マイアシスタント」のみ選択可能（「チャット→アシスタント」で追加）';

  @override
  String get taskFlowUiMyAssistants => '私のアシスタント';

  @override
  String get taskFlowUiNoCustomAssistants =>
      'カスタム アシスタントはまだありません。 「チャット→アシスタント」で作成します。';

  @override
  String get taskFlowUiYes => 'はい';

  @override
  String get taskFlowUiNo => 'いいえ';

  @override
  String get taskFlowUiDefaultRoot => 'デフォルト（ルートフォルダー）';

  @override
  String get taskFlowUiSelect => '選択';

  @override
  String get taskFlowUiSelectSaveFolder => '保存フォルダーを選択してください';

  @override
  String get taskFlowUiCatCatchVideo => 'ビデオ';

  @override
  String get taskFlowUiCatCatchAudio => 'オーディオ';

  @override
  String get taskFlowUiCatCatchEither =>
      'ビデオまたはオーディオ (ダウンストリームステップに基づいてフィルタリング)';

  @override
  String get taskFlowUiManual => 'マニュアル';

  @override
  String get taskFlowUiAutomatic => '自動';

  @override
  String get taskFlowUiAutomaticPrompt => '確認付き自動';

  @override
  String get taskFlowUiEditTitle => 'タスクフローの編集';

  @override
  String get taskFlowUiCreateTitle => '新しいタスクフロー';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return 'ステップ $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return '入力タイプ: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return '入力: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return '出力: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return '削除されたファイルをクリーンアップできませんでした: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return 'ファイルを選択できませんでした: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '「$name」は$limit MBを超えています。より小さいファイルを選択してください。';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '「$name」が空であるか、読み取り不能です';
  }

  @override
  String get taskFlowUiTemporary => '一時的';

  @override
  String get taskFlowUiTemporaryFileHint => '一時ファイル (次のステップが成功するとクリーンアップされます)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return 'ブロックタイプ「$name」は登録されていません';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$finished/$total の実行が終了しました';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return '· $count レコードがクリアされました';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return '入力：$input → 出力：$output';
  }

  @override
  String get taskFlowCardTag => 'タスクフロー';

  @override
  String get taskFlowCardQueued => 'キューに入れられています (リソースを待っています)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done/$total完成';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count $label';
  }

  @override
  String get taskFlowCardFailedLabel => '失敗した';

  @override
  String get taskFlowCardSkippedLabel => 'スキップしました';

  @override
  String get taskFlowCardCancelledLabel => 'キャンセル';

  @override
  String get taskFlowCardInterruptedLabel => '中断された';

  @override
  String get taskFlowCardCancelFlow => 'フローのキャンセル';

  @override
  String get taskFlowCardRetry => 'リトライ';

  @override
  String get taskFlowCardCancelBatch => 'バッチ全体をキャンセルする';

  @override
  String get taskFlowCardDelete => '消去';

  @override
  String get taskFlowCardRetryFlow => 'タスクフローの再試行';

  @override
  String get taskFlowCardNoSnapshot =>
      'この実行にはスナップショットがありません。現在のフロー構成を使用して最初からやり直します。';

  @override
  String get taskFlowCardRetryInfo =>
      'やり直すと、ファイルがダウンロードされ、モデルが再度呼び出されます。起動時に使用した構成で再試行するか、最新の構成を明示的に選択してください。完了したステップを再利用するには、「中断されたステップから再開」を選択します。';

  @override
  String get taskFlowCardRunLatest => '最新の構成で実行する';

  @override
  String get taskFlowCardRetryOriginal => '元の構成で再試行してください';

  @override
  String get taskFlowCardDeleteRecord => 'タスクフローレコードの削除';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      'この実行を削除すると、バッチ内の未完了のタスクがキャンセルされ、サブタスク レコードがクリアされます。消去？';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      'この流れが動いています。削除すると、アクティブなタスクがキャンセルされます。消去？';

  @override
  String get taskFlowCardDeleteRecordConfirm =>
      'このフロー レコードとそのサブタスク レコードを削除しますか?';

  @override
  String get taskFlowCardDeleteConfirm => 'このフロー記録を削除しますか?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      'フローキャンセル状態を保存できませんでした。もう一度削除してみてください。';

  @override
  String get taskFlowCardStillRunning => 'フローはキャンセル後も実行中です。';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      'フローレコードの削除状態を保存できませんでした。もう一度削除してみてください。';

  @override
  String get taskFlowCardConfirm => '確認する';

  @override
  String get taskFlowCardWaiting => '待っている';

  @override
  String get taskFlowCardRunning => 'ランニング';

  @override
  String get taskFlowCardPaused => '一時停止中';

  @override
  String get taskFlowCardCompleted => '完了';

  @override
  String get taskFlowCardFailed => '失敗した';

  @override
  String get taskFlowCardCanceled => 'キャンセル';

  @override
  String get taskFlowCardInterrupted => '中断されました';

  @override
  String get taskFlowCardSucceeded => 'スキップされました';

  @override
  String get taskFlowCardPause => 'フローを一時停止する';

  @override
  String get taskFlowCardResume => 'フローを再開する';

  @override
  String get taskFlowCardResumeInterrupted => '中断したステップから再開';

  @override
  String get taskFlowCardCancel => 'キャンセル';

  @override
  String get unifiedTaskType => 'タスクの種類';

  @override
  String get unifiedTaskCreatedAt => '作成されました';

  @override
  String get unifiedTaskCompletedAt => '完了';

  @override
  String get unifiedTaskResultStatus => '結果ステータス';

  @override
  String get unifiedTaskPartialResult => '部分的な結果。内容が不完全である可能性があります';

  @override
  String get unifiedTaskErrorDetails => 'エラーの詳細';

  @override
  String get unifiedTaskViewErrorDetails => 'エラーの詳細を表示する';

  @override
  String get unifiedTaskOcrPerImage => 'それぞれの画像を認識する';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return '画像 $index';
  }

  @override
  String get unifiedTaskOcrPending => '認識を待っています';

  @override
  String get unifiedTaskOcrRunning => '認識する';

  @override
  String get unifiedTaskCompleted => '完了';

  @override
  String get unifiedTaskIncomplete => '不完全な結果';

  @override
  String get unifiedTaskOcrFailed => '認識に失敗しました';

  @override
  String get unifiedTaskCancelled => 'キャンセル';

  @override
  String get unifiedTaskWaitingStart => '開始を待っています...';

  @override
  String get unifiedTaskSteps => 'ステップ';

  @override
  String get unifiedTaskStartNow => '今すぐ始めましょう';

  @override
  String get unifiedTaskOpenFile => 'ファイルを開く';

  @override
  String get unifiedTaskRetrySave => '保存のみを再試行する';

  @override
  String get unifiedTaskRetryPartialSave => '部分的な結果のみを保存して再試行します';

  @override
  String get unifiedTaskSavePartialResult => '部分的な結果を保存する';

  @override
  String get unifiedTaskRetry => 'リトライ';

  @override
  String get unifiedTaskCancel => 'キャンセル';

  @override
  String get unifiedTaskDelete => '消去';

  @override
  String get unifiedTaskFormatUnsupported => 'この形式ではプレビューはサポートされていません';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return 'ロード失敗: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return '再生に失敗しました: $error';
  }

  @override
  String get unifiedTaskAudioFile => '音声ファイル';

  @override
  String get unifiedTaskPreviewLoadFailed => 'プレビューを読み込めませんでした';

  @override
  String get unifiedTaskUnknownSize => '不明なサイズ';

  @override
  String get unifiedTaskUnnamedRecording => '無題の録音';

  @override
  String get unifiedTaskPause => '一時停止';

  @override
  String get unifiedTaskClearTask => 'タスクをクリアする';

  @override
  String get unifiedTaskContinue => '続く';

  @override
  String get unifiedTaskRemoveFromList => 'リストから削除';

  @override
  String get unifiedTaskSynthesisText => '合成テキスト';

  @override
  String get unifiedTaskStatus => '状態';

  @override
  String get unifiedTaskDetails => '詳細';

  @override
  String get unifiedTaskSynthesisError => '合成エラーの詳細';

  @override
  String get unifiedTaskClose => '閉じる';

  @override
  String get unifiedTaskRawRequestResponse => '生のリクエストとレスポンス';

  @override
  String get unifiedTaskRawRequestBody => '生のリクエスト本文:';

  @override
  String get unifiedTaskRawResponseBody => '生の応答本体:';

  @override
  String get commonJustNow => 'ちょうど今';

  @override
  String commonMinutesAgo(Object count) {
    return '$count 分前';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count 時間前';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes 分 $seconds 秒';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours 時間 $minutes 分';
  }

  @override
  String get unifiedTaskTypeOcr => '画像テキスト認識';

  @override
  String get unifiedTaskTypeAsr => '音声転写';

  @override
  String get unifiedTaskTypeAudioSeparation => '音声の分離';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return 'OCR: $basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return '音声分離: $basename';
  }

  @override
  String get unifiedTaskTypeChat => 'アシスタントのチャット';

  @override
  String get unifiedTaskPlayAudio => 'オーディオを再生する';

  @override
  String get unifiedTaskPauseAudio => '音声を一時停止する';

  @override
  String get catcatchFlowActionNotStarted =>
      'フローアクションが開始されませんでした。フローのステータスを確認して、再試行してください。';

  @override
  String catcatchFlowActionFailed(Object error) {
    return 'フローアクションが失敗しました: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      '自動ページスキャンがタイムアウトしました。サインインするか、このページでユーザー スクリプトを構成します。メディアが検出されたら、[フローを続行] を選択します。';

  @override
  String get browserRecoveryContinue => '流れを続ける';

  @override
  String get catcatchSkipped => 'スキップされました (処理するものは何もありません)';

  @override
  String catCatchDetailMediaResources(Object count) {
    return '$count メディア リソースが見つかりました';
  }

  @override
  String catCatchDetailResources(Object count) {
    return '$count リソースが見つかりました';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return 'ブラウザが $count リソースを見つけました';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return '$total リソースが見つかりました ($segments プレイリスト セグメント)';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return '$count リソースが見つかりました。 1 つお選びください。';
  }

  @override
  String get catCatchDetailAutoSelectFirst => '結果1が自動的に選択され、ダウンロードが開始されます';

  @override
  String get catCatchDetailAutoSelectRemaining =>
      '結果は 1 つ残っています。自動的にダウンロードを開始しました';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return '.$extension の変換はスキップされました。この形式は変換する必要がありません';
  }

  @override
  String get catCatchDetailSkipNoExtension => '変換はスキップされました。この形式は変換する必要がありません';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return '$duration でフィルタリングした後、$remaining の結果が残ります ($removed の不一致リソースは除外されます)';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return 'すべての $count リソースは $duration 期間フィルターと一致します';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '${count}h';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '${count}m';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count';
  }

  @override
  String get catcatchRetryStep => 'このステップを再試行してください';

  @override
  String catcatchCollapseSegments(Object count) {
    return '$count セグメントを非表示にする';
  }

  @override
  String catcatchShowSegments(Object count) {
    return '$count セグメントを表示';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '$total リソース中 $selected が選択されました';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '$count メディア リソースが検出されました';
  }

  @override
  String get catcatchFlowSelectOrCombine =>
      '(リソースを 1 つ選択するか、オーディオ/ビデオのペアを組み合わせます)';

  @override
  String get catcatchSelectMultiple => '(タップして選択します。複数可)';

  @override
  String get catcatchWaitingForResources => 'フローリソースを待っています';

  @override
  String catcatchDownloadSelected(Object count) {
    return '$count 選択したリソースをダウンロード';
  }

  @override
  String get catcatchSelectResources => 'ダウンロードするリソースを選択してください';

  @override
  String get catcatchPossibleSplit => '⚠ オーディオとビデオの別々のストリームが可能';

  @override
  String get catcatchSplitExplanation =>
      'これらのリソースは、同じビデオの個別のオーディオ ストリームとビデオ ストリームである場合があります。それらを組み合わせたり、1 つのストリームのみをダウンロードしたりできます。';

  @override
  String get catcatchAudioStream => '🎵 オーディオストリーム';

  @override
  String get catcatchVideoStream => '🎬 ビデオストリーム';

  @override
  String get catcatchMergeAudioVideo => 'オーディオとビデオを組み合わせる';

  @override
  String get catcatchVideoOnly => 'ビデオのみ';

  @override
  String get catcatchAudioOnly => '音声のみ';

  @override
  String get catcatchSegmentsPlaylistPreview => 'プレイリストを使用してセグメントをプレビューする';

  @override
  String get catcatchPreviewAudio => '音声をプレビューする';

  @override
  String get catcatchPreviewVideo => 'プレビュービデオ';

  @override
  String catcatchDuration(Object duration) {
    return '期間: $duration';
  }

  @override
  String get catcatchSegment => 'セグメント';

  @override
  String get catcatchPlaylist => 'プレイリスト';

  @override
  String get catcatchFullVideo => 'フルビデオ';

  @override
  String get catcatchSeparateTracks => '別々のトラック';

  @override
  String get catcatchPreviewPlaylistOnly => 'プレイリストを使用してプレビューする';

  @override
  String get catcatchPreviewUnsupported => 'プレビューはサポートされていません';

  @override
  String get catcatchUnknownFormat => '不明な形式';

  @override
  String get catcatchNeedPlaylistProcessing => 'プレイリストの処理が必要です';

  @override
  String get catcatchSpecialFormatDetected => '特殊なフォーマットが検出されました';

  @override
  String catcatchPlaylistInfo(Object format) {
    return 'このリソースはプレイリスト ($format) です。これを解析し、すべてのセグメントをダウンロードして、再生可能なビデオに結合する必要があります。';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return 'ダウンロードされたファイルは標準の MP4 ではなく、$format 形式です。内蔵の純粋な Dart リマックス エンジンは、MP4 に変換します (TS/FLV/EV1 は外部依存関係を必要としません)。';
  }

  @override
  String get catcatchContinueBeforeConfirm => 'フォーマット処理を確認する前にフローを再開する';

  @override
  String get catcatchAutoProcess => '自動処理';

  @override
  String get catcatchKeepOriginalFormat => '元の形式を維持する';

  @override
  String get catcatchResumeSupported => '履歴書対応';

  @override
  String get catcatchResumeUnsupported => 'このサイトは再開をサポートしていません';

  @override
  String get catcatchPauseDownload => 'ダウンロードを一時停止する';

  @override
  String get catcatchResumeDownload => 'ダウンロードを再開する';

  @override
  String get catcatchRestartDownload => '再度ダウンロードする';

  @override
  String get catcatchPendingFormatAction => 'フローリソースを待っています';

  @override
  String get quitDialogTitle => 'アプリを終了しますか?';

  @override
  String quitDialogRunningTasks(Object count) {
    return '$count タスクが実行中です。終了すると中断されます。辞めたいですか？';
  }

  @override
  String get quitDialogNoTasks => 'ストルームを辞めたいですか？';

  @override
  String get quitDialogCancel => 'キャンセル';

  @override
  String get quitDialogExit => 'やめる';

  @override
  String get searchPanelNewConversation => '新しい会話';

  @override
  String get searchPanelTitle => '会話を検索する';

  @override
  String get searchPanelHint => 'キーワードを入力してください...';

  @override
  String get searchPanelByTitle => 'タイトルを検索する';

  @override
  String get searchPanelByContent => 'コンテンツの検索';

  @override
  String searchPanelResults(Object count) {
    return '$countの結果';
  }

  @override
  String get searchPanelPrompt => 'キーワードを入力して検索します';

  @override
  String get searchPanelNoResults => '一致する会話が見つかりませんでした';

  @override
  String get topicItemNew => '新しいトピック';

  @override
  String get topicItemUnpin => '固定を解除する';

  @override
  String get topicItemPin => 'ピン';

  @override
  String get topicItemRename => '名前の変更';

  @override
  String get topicItemAutoName => '自動名前';

  @override
  String get topicItemDelete => '消去';

  @override
  String get galleryChoiceTitle => '画像ソースを選択してください';

  @override
  String get galleryChoiceDevice => 'デバイスギャラリー';

  @override
  String get galleryChoiceDeviceDescription => 'デバイス上の写真やビデオを閲覧する';

  @override
  String get galleryChoiceApp => 'アプリギャラリー';

  @override
  String get galleryChoiceAppDescription => 'アプリギャラリーから選択';

  @override
  String get appMediaUnreadable => 'ファイルを読み取れませんでした';

  @override
  String appMediaLoadError(Object error) {
    return 'ファイルをロードできませんでした: $error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return 'クリア ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return '完了 ($count)';
  }

  @override
  String get appMediaConfirmSelection => '終わり';

  @override
  String get appMediaEmptyFolder => 'このフォルダは空です';

  @override
  String get appMediaRoot => 'ルートフォルダーに移動します';

  @override
  String appMediaParentFolder(Object name) {
    return '戻る: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '$count ファイルが選択されました';
  }

  @override
  String get chatAlbumPickerTitle => 'アプリアルバム';

  @override
  String get chatAlbumPickerEmpty => '利用可能な画像がありません';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枚の画像を選択中',
      one: '$count 枚の画像を選択中',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => 'ファイルの選択';

  @override
  String get chatFilePickerTabText => '文章';

  @override
  String get chatFilePickerTabImages => '画像';

  @override
  String get chatFilePickerTabVideos => '動画';

  @override
  String get chatFilePickerTabAudio => 'オーディオ';

  @override
  String get chatFilePickerEmpty => '利用可能なファイルがありません';

  @override
  String get chatFilePickerLoadFailed => 'ファイルをロードできませんでした';

  @override
  String get chatVideoPickerTitle => 'アプリのビデオを選択する';

  @override
  String get chatVideoPickerEmpty => '利用できるビデオはありません';

  @override
  String get imagePreviewCrop => '作物';

  @override
  String get imagePreviewEdit => '編集';

  @override
  String get imagePreviewLoadFailed => '画像を読み込めませんでした';

  @override
  String runningElapsed(Object elapsed) {
    return '$elapsed のために実行中';
  }

  @override
  String get chatAttachmentFile => 'ファイルを添付する';

  @override
  String get chatAttachmentCamera => '写真を撮る';

  @override
  String get chatAttachmentDeviceGallery => 'デバイスギャラリー';

  @override
  String get chatAttachmentDeviceFiles => 'デバイスファイル';

  @override
  String get chatAttachmentAppFiles => 'アプリファイル';

  @override
  String fileManagerTodayTime(Object time) {
    return '今日 $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return '昨日 $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days 日前 $time';
  }

  @override
  String get markdownGenerating => '生成中...';

  @override
  String get htmlPreview => 'プレビュー';

  @override
  String get htmlReturnToCard => 'カードに戻る';

  @override
  String get htmlGenerating => '生成中...';

  @override
  String get htmlFullscreen => '全画面表示';

  @override
  String get htmlViewCode => 'コードを表示する';

  @override
  String get codeScrollToBottom => '一番下までスクロール';

  @override
  String get codeSave => '保存';

  @override
  String get codeDisableWrap => 'ラッピングを無効にする';

  @override
  String get codeEnableWrap => '折り返しライン';

  @override
  String codeCopyFailed(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get codeCopied => 'コピーされました';

  @override
  String get codeCopy => 'コピー';

  @override
  String get codeEmptySave => 'コードが空なので保存できません';

  @override
  String get codeSaveTitle => 'コードを保存する';

  @override
  String codeSavedTo(Object path) {
    return '保存先: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get fileManagerCopy => 'コピー';

  @override
  String get fileManagerMove => '動く';

  @override
  String get fileManagerRename => '名前の変更';

  @override
  String get fileManagerExport => '輸出';

  @override
  String get fileManagerDelete => '消去';

  @override
  String get fileManagerAncestorFolders => '祖先フォルダー';

  @override
  String get fileManagerRoot => '根';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$countが選択されました';
  }

  @override
  String get fileManagerSelectAll => 'すべて選択';

  @override
  String get fileManagerRenameUndo => '最後のバッチの結果の名前変更と元に戻す';

  @override
  String fileManagerSortBy(Object field) {
    return '並べ替え ($field)';
  }

  @override
  String get fileManagerSortCreated => '作成日順に並べ替える';

  @override
  String get fileManagerSortModified => '変更日順に並べ替える';

  @override
  String get fileManagerSortName => '名前順に並べ替える';

  @override
  String get fileManagerSortSize => 'サイズごとに並べ替える';

  @override
  String get fileManagerListView => 'リストビュー';

  @override
  String get fileManagerThumbnailView => 'サムネイルビュー';

  @override
  String get fileManagerCreateFolder => 'フォルダーの作成';

  @override
  String get fileManagerRefresh => 'リストを更新する';

  @override
  String get fileManagerEmptyFolder => 'このフォルダは空です';

  @override
  String get fileManagerNoFiles => 'ファイルがありません';

  @override
  String get fileManagerBackRoot => 'ルートに戻る';

  @override
  String fileManagerBackFolder(Object name) {
    return '戻る: $name';
  }

  @override
  String get fileManagerMultiSelect => '複数選択';

  @override
  String get fileManagerOpen => '開ける';

  @override
  String get fileManagerPreview => 'プレビュー';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '$files ファイル、$folders サブフォルダー';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '$count サブフォルダー';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '$count ファイル';
  }

  @override
  String get fileManagerEmptyFolderLabel => '空のフォルダー';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return 'ファイル「$name.$format」はすでに存在します';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return '名前の変更に失敗しました: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => '宛先フォルダーを選択してください';

  @override
  String get fileManagerAlreadyAtDestination => 'ファイルはすでに宛先にあります';

  @override
  String get fileManagerMoveNameConflict =>
      '移動先に同名のファイルが既に存在します。移動がキャンセルされました。';

  @override
  String fileManagerMoveFailed(Object error) {
    return '移動に失敗しました: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => 'コピー先のフォルダーを選択してください';

  @override
  String fileManagerCopyFailed(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => '削除の確認';

  @override
  String get fileManagerDeleteFileConfirm => 'このファイルを削除しますか?この操作は元に戻すことができません。';

  @override
  String get fileManagerCancel => 'キャンセル';

  @override
  String fileManagerDeleteFailed(Object error) {
    return '削除に失敗しました: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere => 'フォルダーは既に宛先にあります。操作がキャンセルされました。';

  @override
  String get fileManagerFolderConflict =>
      '移動先に同名のフォルダが存在するか、選択したフォルダ内に移動先が存在します。操作がキャンセルされました。';

  @override
  String get fileManagerBatchDeleteTitle => '一括削除の確認';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '$count の選択したアイテムを削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return '一括削除に失敗しました: $error';
  }

  @override
  String get fileManagerExportConflict => '選択したファイルとフォルダーのエクスポート パスが競合します';

  @override
  String get fileManagerSelectedAlreadyThere =>
      '選択したファイルはすでに宛先にあります。移動がキャンセルされました。';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return '一括移動が失敗しました: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      '選択範囲には重複した名前のファイルが含まれています。コピーがキャンセルされました。それらを一度に 1 つずつコピーします。';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return '一括コピーに失敗しました: $error';
  }

  @override
  String get fileManagerClosedError => 'ファイルページは閉じています';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return '名前の一括変更に失敗しました: $error';
  }

  @override
  String get fileManagerFolderNameHint => 'フォルダ名を入力してください';

  @override
  String get fileManagerCreate => '作成する';

  @override
  String get fileManagerFolderExists => 'フォルダーはすでに存在します';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return 'フォルダーを作成できませんでした: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return 'フォルダー「$name」が作成されました';
  }

  @override
  String get fileManagerRenameFolderTitle => 'フォルダーの名前を変更する';

  @override
  String get fileManagerNewNameHint => '新しい名前を入力してください';

  @override
  String get fileManagerTargetFolderConflict =>
      '移動先に同名のフォルダが存在します。操作がキャンセルされました。';

  @override
  String get fileManagerMoveFolderTitle => 'フォルダを次の場所に移動します…';

  @override
  String get fileManagerCopyFolderTitle => 'フォルダーのコピー先…';

  @override
  String get fileManagerFolderSelfConflict =>
      '移動先に同名のフォルダーが存在するか、移動先がフォルダーそのものです。操作がキャンセルされました。';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return 'フォルダ「$name」を削除しますか? $count ファイルも削除されます。';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '空のフォルダー「$name」を削除しますか?';
  }

  @override
  String get fileManagerDeleteFolderTitle => 'フォルダーの削除を確認する';

  @override
  String fileManagerRefreshFailed(Object error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get fileManagerRefreshed => 'ファイルリストが更新されました';

  @override
  String get fileManagerRenameFileTitle => 'ファイル名の変更';

  @override
  String get fileManagerFormat => '形式';

  @override
  String get fileManagerFolderAtDestination => 'フォルダーはすでに宛先にあります';

  @override
  String get folderPickerTitle => 'フォルダーを選択してください';

  @override
  String get folderPickerExists => 'フォルダーはすでに存在します';

  @override
  String folderPickerCreateFailed(Object error) {
    return 'フォルダーを作成できませんでした: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return 'フォルダーリストを更新できませんでした: $error';
  }

  @override
  String get folderPickerInstruction => 'クリックして選択します。ダブルクリックしてフォルダーを開きます';

  @override
  String get folderPickerFileName => 'ファイル名';

  @override
  String get folderPickerFileNameHint => 'ファイル名を入力してください';

  @override
  String get folderPickerBack => '1 つ上のレベルに進みます';

  @override
  String folderPickerPath(Object path) {
    return 'ルート > $path';
  }

  @override
  String get folderPickerRoot => '根';

  @override
  String get folderPickerCurrentFolder => '現在のフォルダー';

  @override
  String get folderPickerSubfolders => 'サブフォルダー';

  @override
  String get folderPickerExistingFolders => '既存のフォルダー';

  @override
  String get folderPickerCreateNew => '新しいフォルダーを作成する';

  @override
  String get folderPickerFolderNameHint => 'フォルダ名を入力してください';

  @override
  String get folderPickerCancelCreate => '作成をキャンセルする';

  @override
  String get folderPickerCancel => 'キャンセル';

  @override
  String get folderPickerConfirm => '終わり';

  @override
  String batchRunReadFailed(Object error) {
    return 'ファイルリストを読み取れませんでした: $error';
  }

  @override
  String get batchRunPreparing => '準備中…';

  @override
  String get batchRunUndo => '元に戻す';

  @override
  String get batchRunRename => '名前の変更';

  @override
  String batchRunFailedAction(Object label) {
    return '$label できませんでした';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label $count アイテム';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed は成功、$failed は失敗、残りは $remaining';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return '失敗: $id → $name';
  }

  @override
  String get batchRunReportCopied => '実行レポートがコピーされました';

  @override
  String get batchRunCopyFailed => 'コピーに失敗しました。もう一度やり直してください。';

  @override
  String batchRunWorking(Object label) {
    return '$label…';
  }

  @override
  String get batchRunTitle => 'バッチ名の変更結果';

  @override
  String get batchRunStoppedRetain =>
      '停止すると完了したアイテムが保持されます。結果ページでそれらを元に戻すことができます。';

  @override
  String get batchRunFailedRemaining => '失敗した;残りのアイテムは処理されませんでした';

  @override
  String get batchRunUndoInfo =>
      '元に戻すと、この実行で完了した項目の元の名前が復元されます。ファイルリストが変更されている場合、元に戻すことは拒否されます。';

  @override
  String get batchRunUncertain =>
      '一部商品の状態が確認できなかった場合がございます。ファイルリストを確認してください。ファイルの上書きを避けるため、自動取り消しは使用できません。';

  @override
  String get batchRunUndoing => '元の名前を復元しています…';

  @override
  String get batchRunStopping => '停止中…';

  @override
  String get batchRunStopRemaining => '残りの項目を停止する';

  @override
  String get batchRunCopyReport => 'レポートのコピー';

  @override
  String batchRunUndoRemaining(Object count) {
    return '残りの $count を元に戻し続けます。';
  }

  @override
  String get batchRunUndoCompleted => '完了した名前変更を元に戻す';

  @override
  String get batchRunDone => '終わり';

  @override
  String get codeEditorTitle => 'パラメータ値を編集する';

  @override
  String get codeEditorFormat => '形式';

  @override
  String get codeEditorCancel => 'キャンセル';

  @override
  String get codeEditorConfirm => 'わかりました';

  @override
  String get codeEditorInvalidJson => '無効な JSON。保存する前に修正してください。';

  @override
  String get codeEditorParamPath => 'パラメータ名のパス (送信時にネストされた JSON に展開されます)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return '行 $line、列 $column: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON 形式エラー: $message';
  }

  @override
  String get codeEditorInvalidFormat => '無効な JSON 形式';

  @override
  String get toolCallCompacted => '圧縮された';

  @override
  String get mermaidSaveEmpty => 'マーメイドコードが空です。保存するものは何もありません。';

  @override
  String mermaidFolderLoadFailed(String error) {
    return 'フォルダーをロードできませんでした: $error';
  }

  @override
  String get mermaidSaveTitle => '人魚図を保存';

  @override
  String get mermaidSaveHint => '.mmd ファイル用のフォルダーを選択または作成します';

  @override
  String get mermaidSaveFilenameHint => 'ファイル名を入力します（.mmdが自動的に追加されます）';

  @override
  String get mermaidFilenameEmpty => 'ファイル名を空にすることはできません';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return 'テキストストレージに保存: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get mermaidPrepareEngine => 'レンダリング エンジンを準備しています...';

  @override
  String get mermaidRetry => 'リトライ';

  @override
  String get batchRuleEmpty => '空にすることはできません';

  @override
  String get batchRuleNumber => '数字を入力してください';

  @override
  String get batchRulePositive => '0 より大きい数値を入力してください';

  @override
  String batchRuleMin(String min) {
    return '少なくとも $min である必要があります';
  }

  @override
  String batchRuleMax(String max) {
    return '$max 以下でなければなりません';
  }

  @override
  String get batchRulePrefix => 'プレフィックス';

  @override
  String get batchRuleSuffix => 'サフィックス';

  @override
  String get batchRuleStart => '始める';

  @override
  String get batchRuleStep => 'ステップ';

  @override
  String get batchRuleDigits => '数字';

  @override
  String get batchRuleSeparator => 'セパレータ';

  @override
  String get batchRuleRestartFolder => '各フォルダーの番号付けを再開します';

  @override
  String get batchRuleNumberHelp =>
      '番号はプレビューの順序に従います。除外される項目には番号は使用されません。ステップは負または 0 にすることができます。';

  @override
  String get batchRuleFind => '探す';

  @override
  String get batchRuleReplace => 'と置換します (削除するには空のままにします)';

  @override
  String get batchRuleCaseSensitive => '大文字と小文字を区別';

  @override
  String get batchRuleRegex => '正規表現';

  @override
  String get batchRuleFirstOnly => '最初の一致のみを置換する';

  @override
  String get batchRuleRegexHelp =>
      'キャプチャ グループ: \$1、\$2。完全一致: \$0;リテラル \$: \$\$。例: ^IMG_(\\d+)\$ → Photo_\$1';

  @override
  String get batchRuleFindRequired => 'このルールを有効にするには、検索するテキストを入力します。';

  @override
  String get batchRuleBeginning => '始まり';

  @override
  String get batchRuleEnd => '終わり';

  @override
  String get batchRulePosition => '位置';

  @override
  String get batchRuleInsertText => '挿入するテキスト';

  @override
  String get batchRuleBeforeChar => '文字 N の前';

  @override
  String get batchRulePositionHelp =>
      '位置は 1 から始まります。末尾を越えた値は追加されます。絵文字を組み合わせても 1 文字としてカウントされます。';

  @override
  String get batchRuleFromBeginning => '最初から';

  @override
  String get batchRuleFromEnd => '端から';

  @override
  String get batchRuleFromChar => '文字 N から始まる';

  @override
  String get batchRuleCount => 'カウント';

  @override
  String get batchRuleDeleteHelp =>
      '削除によって名前が空になった場合は、後の挿入ルールで実行前にテキストを追加する必要があります。';

  @override
  String get batchRuleUpper => '大文字';

  @override
  String get batchRuleLower => '小文字';

  @override
  String get batchRuleFirstUpper => '最初の文字を大文字にする';

  @override
  String get batchRuleTitleCase => '各単語を大文字にします';

  @override
  String get batchRuleTemplate => '新しい名前テンプレート';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return 'コース_${n}_$name';
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
    return '$nameオリジナル名・$nシーケンス・$folderフォルダ名\n$created 作成日 · $modified 変更日 · $ext 元の拡張子\n日付形式 YYYY-MM-DD。欠落している日付が報告されます。テンプレートはベース名全体を置き換えます。拡張子は自動的に保持されます。';
  }

  @override
  String get batchRuleTrim => '先頭と末尾のスペースをトリムする';

  @override
  String get batchRuleCollapseSpaces => '連続するスペースを 1 つのスペースに置き換えます';

  @override
  String get batchRuleActions => 'ルールアクション';

  @override
  String get batchRuleDuplicate => '重複ルール';

  @override
  String get batchRuleRemove => 'ルールの削除';

  @override
  String get batchRuleMoveUp => 'ルールを上に移動';

  @override
  String get batchRuleMoveDown => 'ルールを下に移動';

  @override
  String get batchDlgSavePreset => 'プリセットの保存';

  @override
  String get batchDlgPresetName => 'プリセット名';

  @override
  String get batchDlgPresetHint => 'ルールと順序は保存されますが、除外やマニュアル名は保存されません';

  @override
  String get batchDlgCancel => 'キャンセル';

  @override
  String get batchDlgSave => '保存';

  @override
  String get batchDlgOverwriteTitle => '既存のプリセットを上書きしますか?';

  @override
  String batchDlgOverwriteBody(String name) {
    return '「$name」のルールを更新します。';
  }

  @override
  String get batchDlgOverwrite => '上書き';

  @override
  String get batchDlgManagePresets => 'プリセットの管理';

  @override
  String get batchDlgNoPresets => '保存されたプリセットはありません';

  @override
  String get batchDlgDeletePreset => 'プリセットの削除';

  @override
  String get batchDlgDone => '終わり';

  @override
  String get batchDlgEditName => '名前を個別に編集する';

  @override
  String get batchDlgBaseName => 'ベース名';

  @override
  String get batchDlgOverrideHelp => 'この名前はルールの結果をオーバーライドします';

  @override
  String batchDlgExtensionRetained(String extension) {
    return '拡張子.$extensionは自動的に保持されます';
  }

  @override
  String get batchDlgConfirm => '確認する';

  @override
  String get batchDlgHelp => '説明書';

  @override
  String get batchDlgClose => '閉じる';

  @override
  String get batchDlgLoadPreset => 'プリセットのロード (ルールを置き換え、マニュアル名をクリアします)';

  @override
  String get batchDlgLoad => 'プリセットをロードする';

  @override
  String get batchDlgSaving => '保存中…';

  @override
  String get batchDlgReset => 'すべてのルールと含まれるアイテムをリセットします';

  @override
  String get batchDlgRuleInstructions =>
      'ルールは上から下へ続きます。それらをコピー、移動、または無効にします。ファイル拡張子は変更されません。';

  @override
  String get batchDlgSortName => '名前';

  @override
  String get batchDlgSortCreated => '作成されました';

  @override
  String get batchDlgSortModified => '修正済み';

  @override
  String get batchDlgSortSize => 'サイズ';

  @override
  String get batchDlgAscending => '上昇';

  @override
  String get batchDlgDescending => '降順';

  @override
  String get batchDlgFolderSort => 'フォルダーが最初に来ます。同じ名前はフォルダごとに分類されます。';

  @override
  String get batchDlgAddRule => '＋ ルールを追加';

  @override
  String get batchDlgMaxRules => '最大50のルール';

  @override
  String get batchDlgPreviewWorking =>
      'プレビューを計算中… ルールの編集を続行することも、キャンセルすることもできます。';

  @override
  String get batchDlgSearch => '元の名前、新しい名前、またはフォルダーを検索';

  @override
  String get batchDlgFilterAll => '全て';

  @override
  String get batchDlgFilterChanged => '変更されました';

  @override
  String get batchDlgFilterErrors => '問題';

  @override
  String get batchDlgFilterUnchanged => '変わらない';

  @override
  String get batchDlgFilterExcluded => '除外される';

  @override
  String get batchDlgParticipants => '同梱品を選ぶ';

  @override
  String get batchDlgIncludeAll => 'すべてを含める';

  @override
  String get batchDlgOnlyFiles => 'ファイルのみ';

  @override
  String get batchDlgOnlyFolders => 'フォルダーのみ';

  @override
  String get batchDlgExcludeAll => 'すべてを除外する';

  @override
  String get batchDlgScope => '同梱品';

  @override
  String get batchDlgCopyList => 'リストをコピーする';

  @override
  String get batchDlgConflictBlock => '名前の競合: ブロック実行';

  @override
  String get batchDlgConflictSuffix => '名前の競合: (2)、(3) を追加します。';

  @override
  String get batchDlgNoMatches => 'フィルターに一致する項目はありません';

  @override
  String get batchDlgRoot => '根';

  @override
  String get batchDlgFile => 'ファイル';

  @override
  String get batchDlgFolder => 'フォルダ';

  @override
  String batchDlgTargetFolder(String folder) {
    return '対象フォルダ：$folder';
  }

  @override
  String get batchDlgEditNameTooltip => '名前を個別に編集する';

  @override
  String get batchDlgRestoreNameTooltip => 'ルールによって生成された名前を復元する';

  @override
  String get batchDlgCopied => '完全なプレビュー リストをコピーしました (CSV)';

  @override
  String get batchDlgCopyFailed => 'コピーに失敗しました。もう一度やり直してください。';

  @override
  String get batchDlgHelpTitle => '名前変更命令のバッチ処理';

  @override
  String get batchDlgHelpDismiss => 'わかった';

  @override
  String get batchDlgRulesTab => 'ルール';

  @override
  String batchDlgPreviewTab(String count) {
    return 'プレビュー ($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return '$count アイテムの名前を変更';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      'プリセットをロードできませんでした。ルールは引き続き編集して実行できます。';

  @override
  String get batchDlgPreviewFailed => 'プレビューを計算できませんでした。ルールを調整して再試行してください。';

  @override
  String batchDlgSavedName(String name) {
    return '保存されたプリセット: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get batchDlgPresetWriteFailed => 'プリセットを保存できませんでした。';

  @override
  String batchDlgDeleteFailed(String error) {
    return '削除に失敗しました: $error';
  }

  @override
  String get batchDlgSavePresetFallback => 'プリセットの保存';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return 'プレビュー · $changes の変更 · $conflicts の問題 · $excluded の除外';
  }

  @override
  String get batchDlgInvalidInput => '無効なルール入力を修正します。プレビューにはまだそれらは含まれていません。';

  @override
  String get batchDlgConflictError => '競合または無効な名前がある場合は適用できません。ルールを調整します。';

  @override
  String get batchDlgManualNameStatus => 'マニュアル名';

  @override
  String get batchDlgPendingRename => '名前を変更する準備ができました';

  @override
  String get batchDlgCsvHeader => '元のパス、元の名前、ターゲットのパス、ステータス';

  @override
  String get batchDlgHelpBody =>
      '1. プリセットを選択するかルールを有効にし、ルールをコピーして必要に応じて順序を調整します。\n\n2. プレビューには、使用される名前が表示されます。検索とフィルターは表示のみに影響します。項目のチェックを外すと、その項目が除外され、番号付けが再計算されます。名前を個別に編集するか、ルールの結果を復元します。\n\n3. 実行する前にすべての問題を解決します。自動サフィックスは、ファイルを上書きせずに重複した名前を処理します。名前を交換するフォルダーの名前を別のバッチで変更します。\n\n4. 実行中に後の項目を停止できます。現在の項目が最初に終了します。結果ページには完了した変更が表示され、変更を元に戻すことができます。実行後にリストが変更された場合、元に戻すはブロックされます。\n\nこれにより変更されるのは名前とフォルダー パスのみです。ファイルの内容と拡張子は変更されません。親フォルダーの名前を変更しても、チェックされた子の名前が変更されることは妨げられず、親の名前を変更すると、その子も一緒に移動されます。';

  @override
  String batchDlgPreviewCount(String count) {
    return 'プレビュー ($count)';
  }

  @override
  String get batchBuiltinPhoto => '写真: 日付と番号';

  @override
  String get batchBuiltinCourse => 'コース: 一貫した名前と番号';

  @override
  String get batchBuiltinDownloads => 'ダウンロード: きれいな空白';

  @override
  String get taskListDetail => '詳細';

  @override
  String get taskListOwnershipChecking => 'タスクの所有権の確認';

  @override
  String get taskListOwnershipFailed => 'タスク フロー レコードを読み取れませんでした。アクションは使用できません';

  @override
  String get taskListViewFlow => 'タスクフローの表示';

  @override
  String get taskListPause => '一時停止';

  @override
  String get taskListClear => 'タスクをクリアする';

  @override
  String get taskListResume => '再開する';

  @override
  String get taskListRetry => 'リトライ';

  @override
  String get taskListDismissError => 'エラーを無視する';

  @override
  String get taskListRemove => 'リストから削除';

  @override
  String get taskListSynthesisErrorTitle => '合成エラーの詳細';

  @override
  String get taskListClose => '閉じる';

  @override
  String get taskListOriginalExchange => '元のリクエストとレスポンス';

  @override
  String get taskListOriginalRequest => '元のリクエスト本文:';

  @override
  String get taskListOriginalResponse => '元の応答本文:';

  @override
  String get taskFlowIoTypeText => '文章';

  @override
  String get taskFlowIoTypeAudio => 'オーディオ';

  @override
  String get taskFlowIoTypeVideo => 'ビデオ';

  @override
  String get taskFlowIoTypeImage => '画像';

  @override
  String get taskFlowIoTypeLink => 'リンク';

  @override
  String get taskFlowIoTypeFile => 'ファイル';

  @override
  String get taskFlowIoTypeAny => 'どれでも';

  @override
  String get mermaidZoomOut => 'ズームアウト';

  @override
  String get mermaidZoomIn => 'ズームイン';

  @override
  String get mermaidFullscreen => '全画面表示';

  @override
  String get mermaidSaveButton => '保存';

  @override
  String get mermaidSourceButton => 'ソースを見る';

  @override
  String get mermaidDiagramSemantic => '図を見る';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'CatCatch 子タスクの削除状態を保存できませんでした。もう一度やり直してください。';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      '合成子タスクの削除状態を保存できませんでした。もう一度やり直してください。';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      'バックグラウンドの子タスクの削除状態を保存できませんでした。もう一度やり直してください。';

  @override
  String get mathParseError => '数学解析エラー';

  @override
  String get mermaidEmptyPlaceholder => 'レンダリングする Mermaid コードがありません';

  @override
  String get mathClose => '閉じる';

  @override
  String get mermaidLoadTimeout =>
      'マーメイドの読み込みがタイムアウトしました。ネットワークを確認して、もう一度試してください。';

  @override
  String get mermaidCdnLoadFailed =>
      'cdn.jsdelivr.net にアクセスして Mermaid をロードできませんでした。';

  @override
  String get mermaidLoadingDiagram => '図を読み込み中…';

  @override
  String get mermaidEngineInitFailed =>
      'ダイアグラム レンダラーを初期化できませんでした。もう一度やり直してください。';

  @override
  String get mermaidPageTimeout => 'ページの読み込みがタイムアウトしました。もう一度やり直してください。';

  @override
  String get mermaidCodeLoadFailed => 'ダイアグラムコードをロードできませんでした。もう一度やり直してください。';

  @override
  String mermaidPageLoadFailed(String description) {
    return 'ページのロードに失敗しました: $description';
  }

  @override
  String get mermaidLoadingEngine => 'レンダリング エンジンを読み込み中…';

  @override
  String get mermaidRenderErrorTitle => '図のレンダリングエラー';

  @override
  String get taskFlowOutputVideoAudioDownstream =>
      'ビデオまたはオーディオ (ダウンストリームでフィルタリング)';

  @override
  String get taskFlowOutputUnknown => '未知';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label 停止: $completed は成功、$failed は失敗、$remaining は残り';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return '人魚のレンダリング エラー: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'マーメイド初期化エラー: $message';
  }

  @override
  String get mermaidResourceError => 'Mermaid ダイアグラム内のリソースのロードに失敗しました。';

  @override
  String get taskFlowParamRecognitionModel => '認識モデル';

  @override
  String get taskFlowParamSynthesisModel => '合成モデル';

  @override
  String get taskFlowParamSaveFolder => '保存フォルダー';

  @override
  String get taskFlowParamResourceSelection => 'リソースの選択';

  @override
  String get taskFlowParamOutputType => '出力タイプ';

  @override
  String get taskFlowParamVideoFolder => '動画保存フォルダ';

  @override
  String get taskFlowParamAudioFolder => '音声保存フォルダー';

  @override
  String get taskFlowParamExpectedDuration => '予想される期間';

  @override
  String get taskFlowParamVoice => '声';

  @override
  String get taskFlowParamSpeechRate => '発話速度';

  @override
  String get taskFlowParamAssistant => 'アシスタント';

  @override
  String get taskFlowHintResourceSelection =>
      '手動モードでは選択できます。自動モードは既存のルールに従います。安全な選択肢が 1 つある場合にのみ、曖昧な選択を自動的に行うかどうかを尋ねます。それ以外の場合は、確認のためにリソース リストが開きます。';

  @override
  String get taskFlowHintOutputType =>
      'ビデオまたはオーディオを明示的に選択します。次のブロックの入力タイプによってダウンストリーム フィルター リソースを追跡します。次のブロックが両方のタイプを受け入れるか、次のブロックがない場合は、両方のタイプが保持されます。';

  @override
  String get taskFlowHintExpectedDuration =>
      '動画の長さによってリソースをフィルターします。フィルタリングをスキップするには、空白のままにします。';

  @override
  String get taskFlowHintVoice => '声を選択してください。一致する合成モデルが自動的に選択されます。';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      'このブロック タイプはサポートされなくなりました。交換するか、このステップを削除してください。';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return '次のブロックには $requiredType が必要です。ダウンローダーはビデオまたはオーディオを出力できます。次のステップまたは出力ポリシーを変更します。';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source には任意のタイプがありますが、「$block」には明示的なテキスト、リンク、画像、オーディオ、ビデオ、またはファイル タイプが必要です。入力タイプを変更するか、ブロックを移動または置換するか、変更を元に戻します。';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$sourceには$actualTypeがありますが、「$block」には$requiredTypeが必要です。入力タイプを変更するか、ブロックを移動または置換するか、変更を元に戻します。';
  }

  @override
  String get fileManagerSortFieldCreated => '作成日';

  @override
  String get fileManagerSortFieldModified => '変更日';

  @override
  String get fileManagerSortFieldName => '名前';

  @override
  String get fileManagerSortFieldSize => 'サイズ';

  @override
  String get fileManagerSortDateNewest => '新しい順';

  @override
  String get fileManagerSortDateOldest => '古い順';

  @override
  String get fileManagerSortSizeLargest => '最大のものが最初';

  @override
  String get fileManagerSortSizeSmallest => '最小のものから順';

  @override
  String get catcatchStatusRunning => 'ランニング';

  @override
  String get catcatchStatusCompleted => '完了';

  @override
  String get catcatchStatusFailed => '失敗した';

  @override
  String get catcatchStatusPaused => '一時停止中';

  @override
  String get catcatchStatusWaiting => '待っている';

  @override
  String get catcatchStepFetching => 'Webページを取得しています';

  @override
  String get catcatchStepAnalyzing => 'メディアの分析';

  @override
  String get catcatchStepParsingPlaylist => 'プレイリストを解析しています';

  @override
  String get catcatchStepFiltering => '期間によるフィルタリング';

  @override
  String get catcatchStepUserSelecting => '選択を待っています';

  @override
  String get catcatchStepDownloading => 'ダウンロード中';

  @override
  String get catcatchStepConverting => '変換/結合';

  @override
  String get catcatchStepSaving => 'ローカルに保存する';

  @override
  String get bgStepConnectServer => 'サーバーに接続中';

  @override
  String get bgStepUploadImage => '画像のアップロード';

  @override
  String get bgStepWaitRecognition => '認識を待っています';

  @override
  String get bgStepParseResult => '解析結果';

  @override
  String get bgStepSaveFile => 'ファイルの保存';

  @override
  String get bgStepUploadAudio => '音声のアップロード';

  @override
  String get bgStepTranscribing => '文字起こし';

  @override
  String get bgStepReceiveResult => '受信結果';

  @override
  String get bgStepSeparateAudio => '音声を分離する';

  @override
  String get bgStepSaveToFile => 'ファイルに保存する';

  @override
  String get bgStepSendRequest => 'リクエストの送信';

  @override
  String get bgStepWaitReply => '返信を待っています';

  @override
  String get fileManagerSortNameAscending => 'AからZまで';

  @override
  String get fileManagerSortNameDescending => 'ZからAへ';

  @override
  String get taskFlowValidationNoSteps => 'このタスク フローにはステップがありません。まずブロックを追加します。';

  @override
  String get taskFlowValidationInputRequired =>
      'このタスク・フローを実行するには、少なくとも 1 つの入力を追加します。';

  @override
  String get taskFlowValidationFlowRemoved => 'このタスク フローは削除されました。もう一度選択してください。';

  @override
  String get taskFlowValidationInputTypeChanged =>
      '初期入力タイプが変更されました。再度実行入力を選択します。';

  @override
  String get taskFlowValidationSnapshotMissing =>
      'この古いレコードには実行スナップショットがありません。最新の構成を使用して再試行してください。';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      'アシスタント モデルが見つからないか、使用できません。チャット ページでモデルを選択するか、アシスタントのデフォルト モデルを設定します。';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      '保存されたステップ ファイルが見つからないか、空であるか、読み取り不能です。タスク・フローを再度実行します。';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      'このブロック タイプはサポートされなくなりました。このステップを置き換えるか削除します。';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return '次のブロックには $requiredType が必要です。ダウンローダーはオーディオまたはビデオを出力できます。次のステップまたは出力ポリシーを変更します。';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '「$block」には「$parameter」が必要です。ブロック設定で設定します。';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return 'レガシー モデルの選択には確認が必要です。 「$block」の設定でモデルを選択し直してください。';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return 'モデルが見つからないか、プロバイダーから入手できません。 「$block」設定で再度選択し、プロバイダーの URL とキーを確認します。';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return 'アシスタントが見つからないか、削除されました。 「$block」設定で再度選択してください。';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      'アシスタント モデルが削除されているか、そのプロバイダー構成が利用できません。アシスタント設定でモデルを再度選択してください。';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return 'リソース選択ポリシーまたは出力タイプが無効です。 「$block」設定で再度選択してください。';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return '出力タイプが無効です。 「$block」設定で再度選択してください。';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return 'リソース選択ポリシーが無効です。 「$block」設定で再度選択してください。';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return '入力 $index: ファイルが見つからないか、空であるか、読み取り不能です。もう一度選択してください。';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return '$index を入力: 有効​​な HTTP または HTTPS リンクを入力します。';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return '入力 $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules => '最大 50 個のルールが許可されます。';

  @override
  String get batchRuleValidationDigits => '桁数は 1 ～ 12 である必要があります。';

  @override
  String get batchRuleValidationNumberRange =>
      '開始番号とステップは±999,999,999以内でなければなりません。';

  @override
  String get batchRuleValidationReplacementLength => '置換ルールが長すぎます。';

  @override
  String get batchRuleValidationRegex => '正規表現が無効です。';

  @override
  String get batchRuleValidationDeleteIndex => '削除位置は 1 から開始する必要があります。';

  @override
  String get batchRuleValidationInsertLength => '挿入されたテキストが長すぎます。';

  @override
  String get batchRuleValidationTemplateNumber =>
      '無効なテンプレート番号設定: 桁数は 1 ～ 12、開始/ステップは ±999,999,999 以内である必要があります。';

  @override
  String get batchRuleValidationTemplateLength => 'テンプレートが長すぎます。';

  @override
  String get batchRuleValidationTemplateVariable =>
      '不明なテンプレート変数または閉じられていない中括弧。';

  @override
  String get batchRuleTypeNumber => '番号付けを追加する';

  @override
  String get batchRuleTypeReplace => '検索して置換する';

  @override
  String get batchRuleTypeInsert => 'テキストの挿入';

  @override
  String get batchRuleTypeDelete => '文字を削除する';

  @override
  String get batchRuleTypeCase => '大文字と小文字を変更する';

  @override
  String get batchRuleTypeTemplate => '名前テンプレート';

  @override
  String get batchRuleTypeCleanup => 'クリーンなホワイトスペース';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return '$index を入力: テキストを入力するか、ファイルを選択します。';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return '$index を入力: 画像は 20 MB を超えています。小さい画像を選択してください。';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return '$index を入力: 添付ファイルが 10 MB を超えています。より小さいファイルを選択してください。';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return '$index を入力: ファイルは $actualType ですが、$requiredType が必要です。別のファイルを選択してください。';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return '$index を入力: アシスタント チャットは SVG 画像添付をサポートしていません。 PNG または JPEG に変換します。';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return '$index を入力: アシスタント チャットは $mime の画像添付をサポートしていません。 PNG、JPEG、GIF、または WebP に変換します。';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return '$index を入力: アシスタント チャットは $mime オーディオ添付ファイルをサポートしません。 MP3、WAV、または M4A に変換します。';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return '入力 $index: この Anthropic チャット形式は $type 添付ファイルをサポートしません。このメディアをサポートするアシスタントを選択してください。';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return '入力 $index: この Anthropic チャット形式は、画像と PDF の添付ファイルのみをサポートします。サポートされているファイルを選択してください。';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return '入力 $index: アシスタント チャットは 10 MB 未満の画像を圧縮できませんでした。小さい画像を選択してください。';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return '入力 $index: テキスト添付ファイルは有効な UTF-8 ではありません。変換して再試行してください。';
  }

  @override
  String get assistantParamValueTypeString => '弦';

  @override
  String get assistantParamValueTypeNumber => '番号';

  @override
  String get assistantParamValueTypeBoolean => 'ブール値';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields => 'プロバイダー名、API URL、キーは必須です。';

  @override
  String get providerJsonSizePositive => 'リクエストの JSON サイズは正の MiB 値である必要があります。';

  @override
  String get providerCustomParamRequired => 'カスタムパラメータ名と値は必須です。';

  @override
  String providerParamNameInvalid(String name) {
    return 'パラメータ名が無効です (ドットで区切られたセグメントを空にすることはできません): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return 'パラメータはすでに存在します: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return 'パラメータ「$name」のデフォルト値が無効です JSON: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return 'パラメータ「$name」の数値オプションを空にすることはできません。';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return 'パラメータ「$name」の値は有効な数値ではありません: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      '他の推論パラメーターを有効にする前に、推論の切り替えを完了してください。';

  @override
  String providerReasoningError(String error) {
    return '推論パラメータエラー: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return '推論パラメータとカスタム パラメータは同じ名前です: $name';
  }

  @override
  String get providerMaxTokensMissing => '最大出力トークンが有効になっていますが、値が入力されていません。';

  @override
  String get providerMaxTokensPositive => '最大出力トークンは正の整数である必要があります。';

  @override
  String get providerSeedInteger => 'ランダム シードは整数でなければなりません。';

  @override
  String get providerNotConfigured => '未設定';

  @override
  String get providerAudioChunkingTitle => 'オーディオチャンキング';

  @override
  String get providerAudioChunkingHint =>
      'スマート チャンキングは音声と候補カットを分析し、文末を優先します。チャンクは重なりません。';

  @override
  String get providerChunkingMode => 'チャンク方式';

  @override
  String get providerChunkNone => 'チャンキングなし';

  @override
  String get providerChunkSmart => 'スマートチャンキング (推奨)';

  @override
  String get providerChunkFixedDuration => '固定期間チャンク';

  @override
  String get providerChunkFixedSize => '固定サイズのチャンク';

  @override
  String get providerCompressionTitle => '圧縮符号化';

  @override
  String get providerCompressionHint =>
      '有効にすると、一般的なフォールバックは最初に完全な WAV を圧縮します。エンコードされたファイルまたはリクエスト本文が依然として制限を超える場合、ソース PCM はチャンク化されてエンコードされます。';

  @override
  String get providerCompressionMode => '圧縮方式';

  @override
  String get providerCompressionNone => 'なし（そのまま送信）';

  @override
  String get providerCompressionAdpcm => 'ADPCM (約 4 倍圧縮)';

  @override
  String get providerCompressionFlac => 'FLAC (ロスレス、約2倍、推奨)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM、非可逆 4:1 圧縮。 Pure Dart の実装。音声品質は文字起こしに適しています。';

  @override
  String get providerCompressionFlacDescription =>
      '純粋な Dart で実装されたロスレス FLAC 圧縮。サイズが約半分に減ります。';

  @override
  String get providerCompressionWavDescription => '圧縮はありません。 WAVファイルとして送信します。';

  @override
  String get providerLlmParams => 'LLMパラメータ';

  @override
  String get providerEnabledParamsHelp => '有効なパラメータは、API リクエストのデフォルトとして送信されます。';

  @override
  String get providerTemperatureLabel => '温度';

  @override
  String get providerTemperatureHelp => '出力のランダム性を制御します。値が大きいほど創造的になります。';

  @override
  String get providerTopPHelp => '単語選択の累積確率を制御する核サンプリング パラメーター。';

  @override
  String get providerFrequencyPenaltyLabel => '周波数ペナルティ';

  @override
  String get providerFrequencyPenaltyHelp =>
      '繰り返される単語を減らします。負の値を指定すると、繰り返しが増加します。';

  @override
  String get providerPresencePenaltyLabel => 'プレゼンスペナルティ';

  @override
  String get providerPresencePenaltyHelp =>
      '新しいトピックを奨励します。負の値を指定すると、前のトピックに戻ることが奨励されます。';

  @override
  String get providerMaxOutputTokensLabel => '最大出力トークン';

  @override
  String providerOptionalExample(String example) {
    return 'オプション、例: $example';
  }

  @override
  String get providerResponseTokensHelp => '応答ごとに生成されるトークンの最大数。';

  @override
  String get providerSeedLabel => 'ランダムシード';

  @override
  String get providerSeedHelp => '出力を再現できるようにするには、これを設定します。';

  @override
  String get providerChunkSmartDescription =>
      '音声と候補のカットを分析し、重複のない文末や長い沈黙を優先します。デフォルト: 最小 20 秒 / 目標 45 秒 / 最大 60 秒。一般的なフォールバックによってのみ使用されます。圧縮チャンクは PCM WAV のみをサポートします。';

  @override
  String get providerChunkDurationDescription =>
      'N 秒ごとに分割します (デフォルトでは 60 秒)。シンプルですが、会話が途切れる可能性があります。一般的なフォールバックによってのみ使用されます。圧縮チャンクは PCM WAV のみをサポートします。';

  @override
  String get providerChunkSizeDescription =>
      '最初はオーディオ データ サイズによって分割され、次にエンコードされたファイルとリクエスト本文のサイズによって絞り込まれます。一般的なフォールバックによってのみ使用されます。圧縮チャンクは PCM WAV のみをサポートします。';

  @override
  String get providerChunkNoneDescription =>
      'チャンク化はありません。完全圧縮後に制限を超えると、ファイルは拒否されます。';

  @override
  String get providerNameLabel => 'プロバイダ名';

  @override
  String get providerNameHint => 'プロバイダー名を入力してください';

  @override
  String get providerApiUrlLabel => 'API URL';

  @override
  String get providerApiUrlHint => '完全な API エンドポイント URL を入力します';

  @override
  String providerApiKeyHint(String hint) {
    return 'ヒント: $hint';
  }

  @override
  String get providerEndpointTypeLabel => 'エンドポイントの種類';

  @override
  String get providerEndpointOpenAi => 'OpenAI 互換 (チャット補完)';

  @override
  String get providerEndpointAnthropic => '人間形式 (メッセージ API)';

  @override
  String get providerAnthropicEndpointHelp =>
      '公式の Anthropic Messages API 形式 (x-api-key ヘッダー) を使用します。 API URL の例: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      '公式の OpenAI Chat Completions 互換形式 (Bearer ヘッダー) を使用します。 API URL の例: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => 'デフォルトのリクエスト JSON サイズ';

  @override
  String get providerUseAppDefault => 'アプリのデフォルトを使用するには空のままにしてください';

  @override
  String get providerModelJsonBudgetHelp =>
      'モデルはこの値をオーバーライドできます。プロバイダーもモデルも設定していない場合、デフォルトは 20 MiB です。';

  @override
  String get providerRequestParamsHelp =>
      'リクエストでは、有効なプロバイダーとモデルのパラメーターをすべて使用します。名前が重複する場合は、モデルの値が優先されます。';

  @override
  String get providerUploadSettings => 'アップロード設定';

  @override
  String get providerUploadMethodHelp => '音声のアップロード方法とサイズ制限はプロバイダーによって異なります。';

  @override
  String get providerUploadMethod => 'アップロード方法';

  @override
  String get providerMultipart => 'マルチパート（一般）';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => '最大アップロードサイズ';

  @override
  String get providerFallbackStrategy => 'フォールバック戦略';

  @override
  String get providerFallbackMethod => 'フォールバック方式';

  @override
  String get providerPreprocessing => 'オーディオの前処理';

  @override
  String get providerPreprocessingHelp =>
      '音声ファイルのサイズを削減しますが、リサンプリングによって音声が変化し、文字起こしの精度に影響する場合があります。';

  @override
  String get providerPreprocessingMethod => '前処理方法';

  @override
  String get providerUploadMultipartHelp =>
      'マルチパート/フォームデータの直接アップロード。リクエスト本文には、オーディオ、フォーム フィールド、およびマルチパート境界が含まれます。';

  @override
  String get providerUploadBase64Help =>
      'JSON で Base64 を送信します。これにより、一部のプロバイダーのマルチパート固有の制限を回避できます。 Base64 拡張フィールドと JSON フィールドはアップロード制限にカウントされます。';

  @override
  String get providerUploadUrlHelp =>
      'プロバイダーがダウンロードするパブリック URL を指定します。非常に大きなファイルをサポートします (例: Together AI 1 GB)。';

  @override
  String get providerUploadBudgetHelp =>
      'この値は、生のオーディオ フォールバックをトリガーし、最終的なリクエスト本文を制限します。アプリは、生のオーディオ、エンコードされたファイル、アップロード サイズをチェックします。マルチパートにはフォーム フィールドと境界が含まれます。 Base64 JSON にはエンコード拡張とフィールドが含まれます。デフォルトの 25 MB は、OpenAI オーディオ API の制限と一致します。';

  @override
  String get providerFallbackTriggerHelp =>
      '未加工の音声または完全なリクエスト本文が制限を超えるとトリガーされます。特定のフォールバック (Base64) は、一般的なフォールバック (圧縮/チャンク) よりも優先されます。';

  @override
  String get providerFallbackNone => 'なし（即時拒否）';

  @override
  String get providerFallbackSpecific => '特定のフォールバック (Base64)';

  @override
  String get providerFallbackGeneric => '一般的なフォールバック (圧縮/チャンク化)';

  @override
  String get providerFallbackAll => 'すべて試してみる (推奨)';

  @override
  String get providerFallbackSpecificHelp =>
      'Base64 JSON を試してください。 Base64 拡張フィールドと JSON フィールドを含むリクエスト本文が制限に適合する場合にのみ送信します。';

  @override
  String get providerFallbackGenericHelp =>
      '有効にすると、最初に完全な WAV が圧縮されます。それでも制限を超えており、チャンク化が有効な場合は、ソース PCM を分割して各チャンクをエンコードします。 PCM WAVのみです。';

  @override
  String get providerFallbackAllHelp =>
      'まず、リクエスト本文の制限内で Base64 を試してください。次に、有効になっている場合は、完全な WAV を圧縮します。それでも制限を超えており、チャンク化が有効な場合は、ソース PCM を分割して各チャンクをエンコードします。 PCM WAVのみです。';

  @override
  String get providerFallbackRejectHelp =>
      '制限を超えた場合はファイルを拒否します。フォールバックは試行しないでください。';

  @override
  String get providerPreprocessNone => 'なし';

  @override
  String get providerPreprocessResample => 'WAVのリサンプリング（16kHzモノラル）';

  @override
  String get providerPreprocessResampleHelp =>
      '16 kHz にリサンプルしてモノラルに変換します。音声が変化する場合があります。';

  @override
  String get providerPreprocessNoneHelp => '前処理は必要ありません。そのまま送信します。';

  @override
  String get assistantDefaultsScopeHelp =>
      'デフォルトのモデルとツールは、このアシスタントの下で作成された新しい会話にのみ適用されます。既存の会話は独自の設定を保持します。ツール出力の切り捨てはすべての会話に適用されます。';

  @override
  String get assistantDefaultModelTitle => 'デフォルトモデル';

  @override
  String get assistantDefaultModelHelp =>
      '新しい会話に使用されるモデル。会話が選択できるようにするには、未設定のままにします。';

  @override
  String get assistantNoDefault => '未設定';

  @override
  String get assistantNoModelsAvailable =>
      '利用可能なモデルはありません。 [設定] で LLM プロバイダーを構成します。';

  @override
  String get assistantDefaultToolsTitle => 'デフォルトで有効なツール';

  @override
  String get assistantDisabledToolsHelp => '無効になったツールは、新しい会話では自動的に有効になりません。';

  @override
  String get assistantUnconfiguredToolsHelp =>
      'デフォルトのツールは設定されていません。新しい会話では、すべてのツールが自動的に有効になります。';

  @override
  String get assistantEnableAll => 'すべて有効にする';

  @override
  String get assistantDisableAll => 'すべて無効にする';

  @override
  String get assistantNoToolsAvailable => '利用可能なツールがありません';

  @override
  String get assistantTruncateToolOutput => 'ツール出力の切り捨て';

  @override
  String get assistantTruncateToolOutputHelp =>
      'モデルに送信される前の各ツールの結果の最大文字数。このアシスタントの下でのすべての会話に適用されます。';

  @override
  String get assistantEnableTruncation => '切り捨てを有効にする';

  @override
  String assistantTruncatedTo(String count) {
    return '長い結果は $count 文字に切り詰められます';
  }

  @override
  String get assistantSendFullResult => '完全な結果を送信します (50 KB のストレージ制限の対象となります)';

  @override
  String get assistantMaxCharacters => '最大文字数';

  @override
  String get assistantCharactersNotTokens => '単位: 文字 (トークンではありません)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return 'デフォルト: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return '有効範囲: $minimum ～ $maximum 文字';
  }

  @override
  String get assistantNewConversationPreview => '新しい会話のプレビュー';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled / $total 有効';
  }

  @override
  String get assistantAllToolsAutoEnabled => 'すべてのツールは自動的に有効になります (構成されていません)。';

  @override
  String get assistantMoreActions => 'さらなるアクション';

  @override
  String get assistantChooseEmoji => '絵文字を選択してください';

  @override
  String get assistantNameLabel => 'アシスタント名';

  @override
  String get assistantDescriptionOptional => '説明 (オプション)';

  @override
  String get assistantSelectionTitle => 'アシスタントを選択してください';

  @override
  String get assistantMarketTooltip => 'アシスタントマーケットプレイス';

  @override
  String get assistantDefaultPrompt =>
      'あなたは役に立つ AI アシスタントです。ユーザーの質問に明確かつ有益に答えます。';

  @override
  String get assistantCreateNew => 'アシスタントの作成';

  @override
  String get assistantEmptyState => 'まだアシスタントはいません。まずは作成してください。';

  @override
  String get assistantCreate => '作成する';

  @override
  String get assistantReorderHint => '長押ししてドラッグしてアシスタントの順序を変更します';

  @override
  String get assistantNewNameHint => 'アシスタント名を入力してください';

  @override
  String get assistantNewDescriptionHint => 'このアシスタントの機能を簡単に説明します';

  @override
  String get assistantDeleteTitle => 'アシスタントの削除';

  @override
  String assistantDeleteConfirmation(String name) {
    return 'アシスタント「$name」を削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String get assistantEditTitle => '編集アシスタント';

  @override
  String get assistantBasicTab => '基本設定';

  @override
  String get assistantParametersTab => 'パラメータ';

  @override
  String get assistantDefaultsTab => 'デフォルト';

  @override
  String get assistantAddCustomParameter => 'カスタムパラメータの追加';

  @override
  String get assistantEditCustomParameter => 'カスタムパラメータの編集';

  @override
  String get assistantParameterName => 'パラメータ名';

  @override
  String get assistantParameterNameHint => '例えばtop_k または Provider.only';

  @override
  String get assistantParameterNameInvalid =>
      'パラメータ名が無効です (ドットで区切られたセグメントを空にすることはできません)';

  @override
  String get assistantParameterType => 'タイプ';

  @override
  String get assistantValue => '価値';

  @override
  String get assistantTrueFalseHint => '真か偽か';

  @override
  String get assistantNumberHint => '数字を入力してください';

  @override
  String assistantJsonHint(String example) {
    return '例えば$example';
  }

  @override
  String get assistantValueHint => '値を入力してください';

  @override
  String get assistantCancel => 'キャンセル';

  @override
  String get assistantSave => '保存';

  @override
  String get assistantParamOverrideHelp =>
      '有効にすると、アシスタント パラメータがモデル パラメータをオーバーライドします。無効にすると、モデル パラメーターが使用されます。';

  @override
  String get assistantTemperature => '温度';

  @override
  String get assistantMaxTokens => '最大トークン数';

  @override
  String get assistantMaxToolCalls => '最大ツール呼び出し数';

  @override
  String assistantRounds(String count) {
    return '$countラウンド';
  }

  @override
  String get assistantUnlimited => '無制限';

  @override
  String get assistantStreamOutput => 'ストリーム出力';

  @override
  String get assistantFrequencyPenalty => '周波数ペナルティ';

  @override
  String get assistantPresencePenalty => 'プレゼンスペナルティ';

  @override
  String get assistantRandomSeed => 'ランダムシード';

  @override
  String get assistantNotSet => '未設定';

  @override
  String get assistantSeedValue => 'シード値';

  @override
  String get assistantIntegerSeedHint => '整数シードを入力してください';

  @override
  String get assistantWebSearch => 'ウェブ検索';

  @override
  String get assistantAddParameter => 'パラメータの追加';

  @override
  String get assistantNoCustomParameters => 'カスタムパラメータはありません';

  @override
  String get assistantRoundsLabel => 'ラウンド';

  @override
  String get modelCreateTitle => 'モデルの追加';

  @override
  String get modelEditTitle => 'モデルの編集';

  @override
  String get modelDiscardTitle => '変更を破棄しますか?';

  @override
  String get modelDiscardBody => '未保存の変更があります。それらを破棄しますか？';

  @override
  String get modelNameLabel => '機種名';

  @override
  String get modelNameHint => '表示名を入力します (オプション)';

  @override
  String get modelIdLabel => 'モデルID';

  @override
  String modelIdExample(String id) {
    return '例えば$id';
  }

  @override
  String get modelIdRequired => 'モデルIDは必須です。';

  @override
  String get modelCustomParamRequired => 'カスタムパラメータ名とデフォルト値は必須です。';

  @override
  String modelParamDuplicate(String name) {
    return 'パラメータはすでに存在します: $name';
  }

  @override
  String modelParamReserved(String name) {
    return '予約済み OCR パラメータ名: $name';
  }

  @override
  String get modelParamName => 'パラメータ名';

  @override
  String get modelParamDefaultValue => 'デフォルトのパラメータ値';

  @override
  String get modelParamDelete => 'パラメータの削除';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return 'パラメータ「$name」のデフォルト値が無効です JSON: $value';
  }

  @override
  String get modelAddParameter => 'パラメータの追加';

  @override
  String get modelNoCustomParams => 'カスタムパラメータはありません';

  @override
  String get modelBasicSettings => '基本設定';

  @override
  String get modelDiscardCancel => 'キャンセル';

  @override
  String get modelSave => '保存';

  @override
  String get modelUnsavedMaxTokens => '最大出力トークンは有効ですが、値がありません。';

  @override
  String get modelMaxTokensPositive => '最大出力トークンは正の整数である必要があります。';

  @override
  String get modelSeedInteger => 'ランダム シードは整数でなければなりません。';

  @override
  String get modelContextLengthRequired => 'コンテキストの長さは必須です。';

  @override
  String get modelContextLengthPositive => 'コンテキストの長さは正の整数である必要があります。';

  @override
  String get modelAsrLanguageCode => '言語コード（言語）';

  @override
  String get modelAsrLanguageHint => '例えばzh、ja、ja';

  @override
  String get modelAsrLanguageHelp => 'ISO-639-1 言語コード。自動検出のために空のままにしておきます。';

  @override
  String get modelTemperature => '温度';

  @override
  String get modelTemperatureHelp => '出力のランダム性を制御します。より低い値をお勧めします。';

  @override
  String get modelAsrPrompt => 'プロンプト';

  @override
  String get modelAsrPromptHint => 'コンテキスト プロンプトを入力します (オプション)';

  @override
  String get modelAsrPromptHelp => '専門用語のリストなど、文字起こしの精度を向上させるためのコンテキストを提供します。';

  @override
  String get modelAsrParams => 'ASRパラメータ';

  @override
  String get modelEnabledParamsHelp => '有効なパラメータは、API リクエストのデフォルトとして送信されます。';

  @override
  String get modelAsrResponseFormat => '応答フォーマット';

  @override
  String get modelAsrResponseHelp => '返される文字起こしの形式。';

  @override
  String get modelAsrTimestampGranularity => 'タイムスタンプの粒度';

  @override
  String get modelAsrVerboseHelp =>
      'response_format が verbose_json の場合にのみ使用できます。';

  @override
  String get modelNoTrim => 'トリミングなし';

  @override
  String get modelAudioTrimTitle => 'オーディオトリミング';

  @override
  String get modelAudioTrimHelp => '音声をトリミングする方法を選択します。';

  @override
  String get modelDeleteTrimPreset => 'トリムプリセットを削除';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return 'トリムプリセット「$name」を削除しますか?';
  }

  @override
  String get modelAddTrimPreset => 'カスタムトリムを追加する';

  @override
  String get modelPlayTestAudio => 'テスト音声を再生する';

  @override
  String get modelPlayingTestAudio => '遊んでいます...';

  @override
  String get modelParamExists => 'パラメータはすでに存在します';

  @override
  String get asrModelIdExample => '例えばささやき-1';

  @override
  String get asrPromptLabel => 'プロンプト';

  @override
  String get asrResponseFormatJson => 'json – JSON';

  @override
  String get asrResponseFormatText => 'テキスト – プレーンテキスト';

  @override
  String get asrResponseFormatSrt => 'srt – 字幕';

  @override
  String get asrResponseFormatVtt => 'vtt – 字幕';

  @override
  String get asrResponseFormatVerbose => 'verbose_json – 詳細な JSON (タイムスタンプを含む)';

  @override
  String get asrVerboseTimestampHelp =>
      'verbose_json を選択すると、以下のタイムスタンプ粒度オプションが有効になります。';

  @override
  String get asrTimestampSegment => 'セグメント – セグメントレベル';

  @override
  String get asrTimestampWord => 'word – 単語レベル';

  @override
  String get asrWordTimestampHelp =>
      'ワードレベルのタイムスタンプは、セグメントレベルのタイムスタンプよりも精度が低い場合があります。';

  @override
  String get reasoningAddOptionValue => 'オプション値を追加';

  @override
  String get reasoningEditOptionValue => 'オプション値を編集する';

  @override
  String get reasoningOptionExample => '例えば低、中、高';

  @override
  String get reasoningOptionSelectionHelp =>
      'チップをタップして選択またはクリアします。選択された値が送信されます。ドラッグして並べ替えます。プロバイダー値は削除できませんが、クリアすることで非表示にすることができます。';

  @override
  String get reasoningAddOption => 'オプションを追加';

  @override
  String get reasoningCurrentProvider => '現在: プロバイダー';

  @override
  String get reasoningCurrentModel => '現在: モデルカスタム';

  @override
  String get reasoningAddEffortValue => '推理努力値を加算';

  @override
  String get reasoningEffortExample => '例えばマックス、ウルトラ、ディープ';

  @override
  String get reasoningAddToggle => '推論の追加トグル';

  @override
  String get reasoningToggle => '推論トグル';

  @override
  String get reasoningResetParameter => 'このパラメータをリセットします';

  @override
  String get reasoningDisableToggle => '推論を無効にするトグル';

  @override
  String get reasoningEnableToggle => '推論を有効にするトグル';

  @override
  String reasoningParameterNameSource(String source) {
    return 'パラメータ名($source)';
  }

  @override
  String get reasoningNameExample => '例えば思考タイプ、推論';

  @override
  String get reasoningBooleanHelp =>
      'ブールパラメータには値は必要ありません。チャット パネルにはオン/オフ スイッチがあります。';

  @override
  String get reasoningOnValue => '有効時の値';

  @override
  String get reasoningOnExample => '例えば有効、真';

  @override
  String get reasoningOffValue => '無効時の値';

  @override
  String get reasoningOffExample => '例えば無効、偽';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return '有効にすると、「$onValue」を送信します。無効の場合、「$offValue」を送信します。';
  }

  @override
  String get reasoningAddEffort => '推論の努力を追加する';

  @override
  String get reasoningFillToggleFirst => '最初に推論トグルを完了してください';

  @override
  String get reasoningFillToggleBeforeEffort =>
      '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get reasoningAddValue => '付加価値';

  @override
  String get reasoningJsonValue => 'JSON値';

  @override
  String reasoningJsonExample(String example) {
    return '例えば$example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      'チップをタップして選択またはクリアします。選択した値がチャット推論パネルに表示されます。ドラッグして並べ替えます。プロバイダー値は削除できませんが、非表示にすることはできます。';

  @override
  String get reasoningAddParameter => '推論パラメータを追加する';

  @override
  String get reasoningToggleIncomplete => '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get llmContextLength => 'コンテキストの長さ';

  @override
  String get llmContextHint => 'コンテキストの長さを入力してください';

  @override
  String get llmContextHelp => 'モデル (トークン) のコンテキスト ウィンドウの最大サイズ。';

  @override
  String get llmReasoningParams => '推論パラメータ';

  @override
  String get llmReasoningHelp =>
      'チャットの推論パラメータを構成します。推論トグルは、パラメータ名とオン/オフ値を制御します。推論努力値を追加し、並べ替えて、チャット パネルに表示する値を選択します。このページが開くと、プロバイダーの値が同期されます。これらの設定は、モデル パラメーターの利用可能性を制御します。チャットパネルの切り替えは個別に管理されます。';

  @override
  String get llmAddReasoningParam => '推論パラメータを追加する';

  @override
  String get llmCustomEndpointType => 'カスタムエンドポイントタイプ';

  @override
  String get llmInheritEndpointType => '無効にした場合は、プロバイダー設定のエンドポイント タイプを使用します。';

  @override
  String get llmEndpointType => 'エンドポイントの種類';

  @override
  String get llmEndpointOpenAi => 'OpenAI 互換 (チャット補完)';

  @override
  String get llmEndpointAnthropic => '人間形式 (メッセージ API)';

  @override
  String get llmEndpointHelp =>
      'エンドポイントのタイプはプロバイダー API URL と一致する必要があります。これを変更すると、このモデルとの新しい会話に使用される形式に影響します。';

  @override
  String get llmTopPHelp => '核サンプリングパラメータ。単語選択の累積確率を制御します。';

  @override
  String get llmFrequencyPenaltyLabel => '周波数ペナルティ';

  @override
  String get llmFrequencyPenaltyHelp => '繰り返しを減らします。負の値を指定すると増加します。';

  @override
  String get llmPresencePenaltyLabel => 'プレゼンスペナルティ';

  @override
  String get llmPresencePenaltyHelp => '新しいトピックを奨励します。負の値は繰り返しを促します。';

  @override
  String get llmMaxTokensHint => 'オプション、例: 4096';

  @override
  String get llmTokensPerResponse => '応答ごとに生成される最大トークン。';

  @override
  String get llmSeedLabel => 'ランダムシード（シード）';

  @override
  String get llmSeedHint => 'オプション、例: 42';

  @override
  String get llmSeedHelp => 'これを設定すると出力が再現可能になります。';

  @override
  String get llmInheritedCustomHelp =>
      'プロバイダーのカスタム パラメーターがここに表示され、このページが開くたびに同期されます。';

  @override
  String get llmBooleanParamHelp => 'ブールパラメータには値は必要ありません。';

  @override
  String get modelContextReq => 'コンテキストの長さは必須です。';

  @override
  String get modelContextPositive => 'コンテキストの長さは正の整数である必要があります。';

  @override
  String modelParamNameInvalid(String name) {
    return '無効なパラメータ名 (ドットで区切られたセグメントを空にすることはできません): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return 'パラメータ「$name」 $valueLabel は有限数でなければなりません: $value';
  }

  @override
  String get modelReasoningIncomplete => '他の推論パラメーターを有効にする前に、推論の切り替えを完了してください。';

  @override
  String get modelReasoningOptionsRequired => '少なくとも 1 つのオプション値を推論パラメータに追加します。';

  @override
  String modelReasoningError(String error) {
    return '推論パラメータエラー: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return '推論パラメータが重複しています: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return '推論とカスタム パラメーターは $name という名前を共有します。';
  }

  @override
  String get modelSeedRequired => 'ランダム シードは有効ですが空です。';

  @override
  String get ocrParamsTitle => 'OCRパラメータ';

  @override
  String get ocrParamsHelp =>
      'OpenAI 互換のビジョン Chat Completions 形式を使用します。以下のパラメータはオプションです。未設定または無効なパラメータは送信されません。 API でサポートされている場合は、以下のプロバイダー固有のパラメーターを追加します。';

  @override
  String get ocrRequestSizeOverride => 'JSON サイズのオーバーライドをリクエストする';

  @override
  String get ocrInheritProvider => 'プロバイダー設定を継承するには空のままにしておきます';

  @override
  String get ocrBudgetDefault =>
      '空の場合、プロバイダー設定を継承します。プロバイダーに値がない場合、デフォルトは 20 MiB です。';

  @override
  String ocrBudgetValue(String size) {
    return '空の場合、プロバイダー設定 ($size MiB) を継承します。プロバイダーに値がない場合、デフォルトは 20 MiB です。';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return 'トリム $direction $seconds';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return '最初の $seconds をトリムします';
  }

  @override
  String get audioTrimNone => 'オーディオをトリミングしないでください';

  @override
  String get trimNameLabel => 'トリムメソッド名 *';

  @override
  String get trimNameHint => '例えばサイレントトリミング';

  @override
  String get trimDurationLabel => 'トリム期間 (秒) *';

  @override
  String get trimDurationHint => '例えば0.123';

  @override
  String get trimNameAndDurationRequired => '名前と期間は必須です。';

  @override
  String get trimDurationInvalid => '有効な正の期間を入力します。';

  @override
  String get testAudioHostMissing => 'ホストが構成されていません。';

  @override
  String get testAudioKeyMissing => 'キーが設定されていません。';

  @override
  String testAudioContentTypeError(String contentType) {
    return '応答 Content-Type は $contentType であり、オーディオではありません。';
  }

  @override
  String get testAudioEmpty => 'サーバーは空の音声データを返しました。';

  @override
  String testAudioTimeoutConnection(String details) {
    return '接続がタイムアウトしました。ネットワークを確認してください。 $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return '受信がタイムアウトしました。サーバーの応答が遅すぎました。 $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return 'リクエストはキャンセルされました。 $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return 'ネットワークエラー: $message';
  }

  @override
  String get testAudioNoBody => '応答本文がありません';

  @override
  String testAudioCorsHelp(String details) {
    return 'サーバーに接続できません。 Web では、CORS または不正な API URL が原因である可能性があります。プロバイダー API URL と、サーバーがクロスオリジン要求を許可しているかどうかを確認してください。 $details';
  }

  @override
  String get trimModelNameHint =>
      '表示と識別のためのわかりやすい名前。 「GPT-4o ミニTTS」。同じプロバイダーのモデルを区別するには、異なる名前を使用します。';

  @override
  String get trimModelIdHelp =>
      'API 呼び出しで使用される一意の識別子。 「gpt-4o-mini-tts」。ベンダーが提供するモデル ID と一致する必要があります。';

  @override
  String get ttsVoiceRangeTitle => '音量範囲';

  @override
  String get ttsMinVolume => '最小音量';

  @override
  String get ttsMaxVolume => '最大音量';

  @override
  String get ttsSpeedRangeTitle => '速度範囲';

  @override
  String get ttsMinSpeed => '最低速度';

  @override
  String get ttsMaxSpeed => '最高速度';

  @override
  String get ttsMaxAudioLength => 'リクエストあたりの最大オーディオ長 *';

  @override
  String get ttsAudioLengthHint => '例えば1000';

  @override
  String get ttsNoVoices => '音声はありません。タップして編集します。';

  @override
  String get ttsInstructionSupported => 'モデルは命令パラメータをサポートしています';

  @override
  String get ttsInstructionHelp =>
      '有効にすると、TTS リクエストに口調、感情、話す速度などの指示を含めることができます。';

  @override
  String get ttsStreamSupported => 'ストリーミング出力をサポートするモデル';

  @override
  String get ttsStreamHelp =>
      'このモデルをストリーミング シナリオで有効にします。有効にする前に、モデルがストリーミングをサポートしていることを確認してください。';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return 'パラメータ「$name」は true または false である必要があります: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired =>
      'リクエストごとの最大オーディオ長が必要です。正の整数を入力してください。';

  @override
  String get asrLanguageExample => '例えばzh、ja、ja';

  @override
  String get llmReasoningFullHelp =>
      '推論トグルは推論を送信するかどうかを制御し、パラメータ名とオン/オフ値を定義できます。推論努力パラメータが 1 つあります。値を選択し、ドラッグして順序を変更します。選択した値がチャット推論パネルに表示されます。以下に他の推論パラメーターを追加します。パラメーター名は、thing.type などのドット表記をサポートしており、ネストされた JSON オブジェクトになります。このページが開くと、プロバイダー推論パラメータが同期されます。ここのスイッチはモデルパラメータを制御します。チャット推論の切り替えは別のものです。';

  @override
  String get llmTemperatureHelp => '出力のランダム性を制御します。値が大きいほど創造的になります。';

  @override
  String get llmBooleanValueHelp => 'ブールパラメータには値は必要ありません。';

  @override
  String get reasoningDisableEffort => '推論の努力を無効にする';

  @override
  String get reasoningEnableEffort => '推論の努力を可能にする';

  @override
  String get ocrJsonSizePositive => 'リクエストの JSON サイズは正の MiB 値である必要があります。';

  @override
  String ttsRangePair(String kind) {
    return '$kind の最小値と最大値の両方を入力するか、両方を空のままにします。';
  }

  @override
  String get ttsEditTrimTitle => 'カスタムトリムを編集する';

  @override
  String ttsVoicesCount(String count) {
    return '音声 ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return 'リクエスト形式で生成: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'MCP サーバー名を入力してください。';

  @override
  String get mcpStdioCommandRequired => 'stdio モードにはコマンドが必要です。';

  @override
  String get mcpSseUrlRequired => 'SSE モードには URL が必要です。';

  @override
  String get mcpEditServerTitle => 'MCPサーバーの編集';

  @override
  String get mcpCreateServerTitle => '新しい MCP サーバー';

  @override
  String get mcpUnsavedChangesTitle => '未保存の変更';

  @override
  String get mcpUnsavedChangesConfirm => '未保存の変更があります。それらを破棄しますか？';

  @override
  String get mcpTransportType => '輸送タイプ';

  @override
  String get mcpServerName => 'サーバー名';

  @override
  String get mcpServerNameHint => 'MCP サーバー名を入力してください';

  @override
  String get mcpCommand => '指示';

  @override
  String get mcpCommandExample => '例: npx';

  @override
  String get mcpArguments => '引数';

  @override
  String get mcpArgumentsHint =>
      '引数はカンマで区切ります。例: -y、@modelcontextprotocol/server-filesystem、/tmp';

  @override
  String get mcpSseUrlExample => '例: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'APIキー';

  @override
  String get mcpApiKeyHint => 'API キーを入力します (オプション)';

  @override
  String get mcpShowKey => 'キーを表示';

  @override
  String get mcpHideKey => 'キーを隠す';

  @override
  String get mcpDescriptionHint => 'この MCP サーバーの説明を入力します (オプション)';

  @override
  String get mcpStdioDescription =>
      'stdio はローカルの子プロセスを MCP サーバーとして起動し、標準入出力を通じて通信します。ローカルツールに推奨されます。';

  @override
  String get mcpSseDescription =>
      'SSE は、HTTP SSE 経由でリモート MCP サーバーに接続します。リモートサービスに推奨されます。';

  @override
  String get mcpLocalStdio => 'ローカル (stdio)';

  @override
  String get mcpRemoteSse => 'リモート (SSE)';

  @override
  String get mcpSaving => '保存中…';

  @override
  String get providerTestSafetyNote =>
      'このテストは、選択したサービスに実際のリクエストを送信します。 MCP は読み取り専用のツール/リスト メソッドのみを呼び出します。 HTTP と Web 検索は 1 つのクエリを実行します。 Todo はデフォルトでリストを読み取ります。現在のデータを保護するには、todos パラメータを省略するか、null に設定します。';

  @override
  String get providerDeleteConfigTitle => '構成の削除';

  @override
  String get providerDeleteConfigConfirm => 'このプロバイダー構成とそのすべてのモデルを削除しますか?';

  @override
  String get providerCreateGroup => '新しいグループ';

  @override
  String get providerEditGroup => 'グループの編集';

  @override
  String get providerGroupName => 'グループ名';

  @override
  String get providerGroupNameExists => 'この名前のグループはすでに存在します。';

  @override
  String get providerDeleteGroup => 'グループの削除';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return '「$groupName」を削除すると、その構成が「その他の MCP サービス」に移動されます。';
  }

  @override
  String get providerMoveToGroup => 'グループに移動';

  @override
  String get providerUnnamed => '(名前なし)';

  @override
  String get providerHttpSearch => 'HTTP検索';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP ツール: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return 'ローカル (stdio): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return 'リモート (SSE): $url';
  }

  @override
  String get providerServices => 'サービス構成';

  @override
  String get providerServicesDescription =>
      'リモート接続、ローカル標準入出力、HTTP 検索をグループごとに管理';

  @override
  String get providerCreateGroupAction => '新しいグループ';

  @override
  String get providerGroupEmpty => 'このグループには構成がありません。 「追加」を選択して項目を追加します。';

  @override
  String get providerBuiltinTools => '内蔵ツール';

  @override
  String get providerBuiltinToolsDescription =>
      'Stroom が提供するローカル ツール インターフェイス。 Web 検索はそのサービス グループにリストされています。';

  @override
  String get providerBuiltinToolInterface => '内蔵ツールインターフェイス';

  @override
  String get providerViewInterface => 'ビューインターフェイス';

  @override
  String get providerConfigTitle => '構成';

  @override
  String get providerNotFound => 'プロバイダーが見つかりません';

  @override
  String get providerConfigurationHeading => 'プロバイダーの構成';

  @override
  String get providerBuiltinWebSearchEmpty =>
      '組み込みの Web 検索は、Google、Bing、Baidu をサポートします。そのモデル ツール名は web_search です。';

  @override
  String get providerNoConfigsAdd => 'プロバイダーの構成はまだありません。 「追加」を選択して作成します。';

  @override
  String get providerNoHost => '(ホストが設定されていません)';

  @override
  String get providerServicesAndTools => 'サービスとツール';

  @override
  String get providerManageServicesDescription =>
      'MCP サーバー、HTTP 検索、Stroom 組み込みツールを管理します。';

  @override
  String get providerNoServices => 'サービス構成はまだありません';

  @override
  String get providerAddServiceDescription =>
      'MCP サービスまたは HTTP 検索インターフェイスを追加して、アシスタントで使用します。';

  @override
  String get providerAddService => 'サービスの追加';

  @override
  String get providerBuiltinBadge => '内蔵';

  @override
  String get providerBuiltinTtsName => 'TTSプロバイダー';

  @override
  String get providerBuiltinLlmName => 'LLM プロバイダー';

  @override
  String get providerBuiltinOcrName => 'OCRプロバイダー';

  @override
  String get providerBuiltinAsrName => '音声認識プロバイダー';

  @override
  String get providerBuiltinMcpName => 'MCPプロバイダー';

  @override
  String get providerBuiltinSearchGroupName => '検索';

  @override
  String get providerBuiltinMcpServicesGroupName => 'その他のMCPサービス';

  @override
  String get providerConnectivityTest => '接続テスト';

  @override
  String get providerMoveGroupTooltip => 'グループに移動';

  @override
  String get providerDeleteTooltip => '構成の削除';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 件',
      one: '# 件',
      zero: '項目はありません',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => 'グループアクション';

  @override
  String get providerEditGroupAction => 'グループの編集';

  @override
  String get providerDeleteGroupAction => 'グループの削除';

  @override
  String get providerAddItem => 'アイテムの追加';

  @override
  String get providerMcpMasterLabel => 'MCPサーバー';

  @override
  String get providerMcpMasterDescription =>
      'MCP サーバーと組み込みの検索ツールをアシスタントとチャットで使用できるかどうかを制御します。';

  @override
  String get providerEnabled => '有効';

  @override
  String get providerDisabled => '無効';

  @override
  String get providerEditSettings => 'プロバイダー設定を編集する';

  @override
  String get providerModelList => 'モデル';

  @override
  String get providerNoModels => 'まだモデルがありません';

  @override
  String get providerDeleteModel => 'モデルの削除';

  @override
  String get providerDeleteModelConfirm => 'このモデルを削除してもよろしいですか?';

  @override
  String get providerEditConfig => '構成の編集';

  @override
  String providerCreateNamedConfig(String entryName) {
    return '新しい $entryName 構成';
  }

  @override
  String get toolHttpSearchType => '接続タイプ: HTTP 検索';

  @override
  String toolInterface(String name) {
    return 'ツールインターフェイス: $name';
  }

  @override
  String get toolParameterDefinitions => 'パラメータの定義';

  @override
  String get toolHttpAddress => 'HTTPエンドポイントURL';

  @override
  String get toolInvalidHttpUrl => '有効な HTTP または HTTPS URL を入力します。';

  @override
  String get toolBuiltinType => '接続タイプ：ストルーム内蔵ツール';

  @override
  String get toolBuiltinEnableHelp =>
      'アシスタントのデフォルトのツール設定で、アシスタントに対してこのツールを有効にします。';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return 'モデルID: $modelId';
  }

  @override
  String get providerValueNotSet => '(未設定)';

  @override
  String get providerApiKeyInputHint => 'APIキーを入力してください';

  @override
  String get providerSettingsTitle => 'プロバイダーの構成';

  @override
  String get providerBasicInfoTab => '基本情報';

  @override
  String get providerParameterSettingsTab => 'パラメータ設定';

  @override
  String get providerOptionValuesReorderHelp =>
      'オプションの値 (ハンドルを押したままドラッグして並べ替えます)';

  @override
  String providerOptionIndexLabel(String index) {
    return 'オプション $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return '例えば$example';
  }

  @override
  String get providerDeleteOptionTooltip => '削除オプション';

  @override
  String get providerAddOption => 'オプションを追加';

  @override
  String get providerAddCustomParam => 'パラメータの追加';

  @override
  String get providerNoCustomParams => 'カスタムパラメータはまだありません';

  @override
  String get providerParamNameLabel => 'パラメータ名';

  @override
  String get providerParamDefaultValueLabel => 'デフォルトのパラメータ値';

  @override
  String get providerBooleanParamNoValue =>
      'ブールパラメータには値は必要ありません。チャット パネルにはオン/オフの切り替えがあります。';

  @override
  String get providerReasoningParamsHeading => '推論パラメータ';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return '推論トグルは、チャットでの推論をオンまたはオフにします。パラメータ名とオン/オフ値を選択します。必須の名前とオプションの選択肢を使用して、1 つの推論努力パラメーターを構成できます。名前のみを入力すると、モデル設定によって値が提供されます。他の推論パラメータを追加するには、下のボタンを使用します。パラメータ名はドットのネストをサポートしています。たとえば、$parameterName は $jsonExample に展開されます。';
  }

  @override
  String get providerAddReasoningParam => '推論パラメータを追加する';

  @override
  String get providerAddReasoningToggle => '推論の追加トグル';

  @override
  String get providerReasoningToggle => '推論トグル';

  @override
  String get providerDeleteReasoningToggle => '推論の削除トグル';

  @override
  String providerParamNameHint(String examples) {
    return '例えば$examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      'ブールパラメータには値は必要ありません。チャット パネルにはオン/オフの切り替えがあります。';

  @override
  String get providerToggleOnValueLabel => 'オン値';

  @override
  String get providerToggleOffValueLabel => 'オフ値';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return '推論がオンの場合は、「$onValue」を送信します。オフの場合は「$offValue」を送信します。';
  }

  @override
  String get providerAddReasoningEffort => '推論の努力を追加する';

  @override
  String get providerDeleteReasoningEffort => '推論努力パラメータの削除';

  @override
  String get providerReasoningEffortLockedHint =>
      '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get providerJsonValueLabel => 'JSON値';

  @override
  String get providerReasoningOptionsHelp =>
      'オプション値 (オプション。パラメータ名のみを入力した場合、モデル設定によって値が提供されます)。ハンドルを押したままドラッグして並べ替えます。';

  @override
  String get providerParamNameNestedLabel => 'パラメータ名 (ドットのネストをサポート)';

  @override
  String get providerToggleEffortPrerequisite =>
      '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get providerToggleRequiredHint => 'まず推論の切り替えを完了してください。';

  @override
  String get providerDeleteCustomParam => 'パラメータの削除';

  @override
  String get modelSaveSuccess => 'モデルが保存されました';

  @override
  String get modelSaving => '保存中…';

  @override
  String modelOriginalError(String error) {
    return '元のエラー: $error';
  }

  @override
  String get paramTypeStringLabel => '弦';

  @override
  String get paramTypeNumberLabel => '番号';

  @override
  String get paramTypeBooleanLabel => 'ブール値';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return 'サポートされていないタイプ: $type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return 'パラメータ「$name」はサポートされていないタイプ「$type」を使用しています。サポートされているタイプに置き換えるか、保存する前にパラメータを削除してください。';
  }

  @override
  String get paramTypeStringHint => '例えば陽気な';

  @override
  String get paramTypeNumberHint => '例えば0.8';

  @override
  String get paramTypeBooleanHint => '例えば真実';

  @override
  String get paramTypeJsonHint => '例えば';

  @override
  String get ankiPageTitle => 'アンキのフラッシュカード';

  @override
  String get ankiStatsTooltip => '研究統計';

  @override
  String get ankiBrowseCardsTooltip => 'カードを閲覧する';

  @override
  String get ankiStatsTotalCards => 'カードの合計';

  @override
  String get ankiStatsNewCards => '新しいカード';

  @override
  String get ankiStatsLearning => '学ぶ';

  @override
  String get ankiStatsDueForReview => '審査期限中';

  @override
  String get ankiStatsReviewHistory => 'レビュー履歴';

  @override
  String get ankiStatsLearningProgress => '研究の進捗状況';

  @override
  String get ankiStatsReviewRate => 'レビュー率';

  @override
  String get ankiBrowserSearchHint => 'カードを検索...';

  @override
  String get ankiBrowserEmpty => 'カードなし';

  @override
  String get ankiSyncTooltip => 'AnkiWeb同期';

  @override
  String get ankiNewDeckTooltip => '新しいデッキ';

  @override
  String ankiDeckLoadError(String error) {
    return 'デッキのロードに失敗しました: $error';
  }

  @override
  String get ankiEmptyDecksTitle => 'まだデッキがありません';

  @override
  String get ankiEmptyDecksDescription => 'デッキを作成して勉強を始める';

  @override
  String get ankiNewDeckTitle => '新しいデッキ';

  @override
  String get ankiDeckNameHint => 'デッキ名';

  @override
  String get ankiCreateDeck => '作成する';

  @override
  String get ankiRenameDeck => 'デッキ名の変更';

  @override
  String get ankiConfirm => 'わかりました';

  @override
  String get ankiDeleteDeckTitle => 'デッキの削除';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '「$deckName」とそのすべてのカードを削除しますか?';
  }

  @override
  String get ankiAddCardTitle => 'カードを追加';

  @override
  String get ankiNoteTypeLabel => 'ノートの種類';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return 'テキスト (削除を $clozeSyntax でマーク)';
  }

  @override
  String get ankiFrontQuestionHint => 'フロント（質問）';

  @override
  String get ankiBackExtraLabel => '裏・番外編';

  @override
  String get ankiTagsLabel => 'タグ（スペースで区切る）';

  @override
  String get ankiTagsHint => '例: 数学物理学';

  @override
  String get ankiAdd => '追加';

  @override
  String get ankiStatNew => '新しい';

  @override
  String get ankiStatLearning => '学ぶ';

  @override
  String get ankiStatReview => 'レビュー';

  @override
  String get ankiAddCardAction => 'カードを追加';

  @override
  String get ankiRenameAction => '名前の変更';

  @override
  String get ankiDeleteAction => '消去';

  @override
  String get ankiNoCardContent => 'カード内容なし';

  @override
  String get ankiStudy => '勉強';

  @override
  String get ankiWhiteboardTooltip => 'ホワイトボード';

  @override
  String get ankiFrontLabel => 'フロント';

  @override
  String get ankiBackLabel => '戻る';

  @override
  String get ankiShowAnswer => '答えを表示';

  @override
  String get ankiRatingAgain => 'また';

  @override
  String get ankiRatingHard => '難しい';

  @override
  String get ankiRatingGood => '良い';

  @override
  String get ankiRatingEasy => '簡単';

  @override
  String get ankiNoCardsToStudy => '現在学習するカードはありません';

  @override
  String get ankiNoCardsHint => '新しいカードを追加するか、後で戻ってください';

  @override
  String get ankiBack => '戻る';

  @override
  String get ankiSyncPageTitle => 'アンキ同期';

  @override
  String get ankiSyncChooseMode => '同期モードを選択してください';

  @override
  String get ankiSyncModeHelp =>
      'ログイン状況はサービスごとに個別に保存されます。モードを切り替えても、データはマージまたは上書きされません。';

  @override
  String get ankiSyncSelfHostedMode => '自己ホスト型サーバー';

  @override
  String get ankiSyncServerAddress => 'サーバーアドレス';

  @override
  String get ankiSyncServerHelp =>
      'リモートのセルフホスト サーバーは HTTPS を使用する必要があります。ローカル アドレスには HTTP が許可されます。サーバーは Anki sync v10 をサポートする必要があり、証明書の検証はデフォルトで有効になっています。';

  @override
  String get ankiSyncCustomCaTitle => 'カスタム CA 証明書 (オプション)';

  @override
  String get ankiSyncCustomCaHelp => 'サーバーが自己署名証明書を使用する場合にのみこれを入力します';

  @override
  String get ankiSyncOfficialHelp =>
      '公式の AnkiWeb 同期サービスを使用します。パスワードはログイン時にのみ送信され、Stroom には保存されません。';

  @override
  String ankiSyncConnected(String service) {
    return '$serviceに接続';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return '$serviceに接続されていません';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return '$serviceにログインします';
  }

  @override
  String get ankiSyncCheckServerStatus => 'サーバーのステータスを確認する';

  @override
  String get ankiSyncLogout => 'ログアウト';

  @override
  String get ankiSyncBothWays => '双方向同期';

  @override
  String get ankiSyncOverwriteServer => 'サーバーデータをローカルデータに置き換えます';

  @override
  String get ankiSyncReplaceLocal => 'ローカルデータをサーバーデータに置き換えます';

  @override
  String get ankiSyncHelp =>
      '双方向同期は、増分コレクションの変更をマージし、メディア ファイルを転送します。スキーマのバージョンが異なる場合は、完全なアップロードまたはダウンロードを選択します。完全なダウンロードが失敗すると、元のコレクションとメディア ディレクトリの復元が試行されます。';

  @override
  String get ankiSyncStatusRestored => '安全に保存されたログインセッションを復元しました';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      '保存されたログイン セッションを読み取れませんでした。再度ログインしてください。';

  @override
  String get ankiSyncInvalidServerUrl =>
      'サーバー アドレスは HTTPS URL である必要があります。 HTTP はローカル ループバック アドレスに対してのみ許可されます。ユーザー情報とクエリパラメータは許可されません。';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return '設定が保存されていません: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      'サーバーアドレスが変更されました。続行するには再度ログインしてください。';

  @override
  String get ankiSyncStatusVerifyingLogin => 'ログインを確認しています…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      'ログインに成功しました。パスワードは保存されていませんでした。同期キーは暗号化されて保存されました。';

  @override
  String get ankiSyncLoginSuccessPromptTitle => 'ログイン成功';

  @override
  String get ankiSyncLoginSuccessPromptMessage => 'コレクションを今すぐ同期しますか？';

  @override
  String get ankiSyncLoginSuccessPromptSync => '今すぐ同期';

  @override
  String get ankiSyncLoginSuccessPromptLater => '続行';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      'ログインは成功しましたが、同期キーを安全に保存できませんでした。このページを閉じた後、再度ログインする必要があります。';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return 'ログイン失敗: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'AnkiWeb にログインする';

  @override
  String get ankiSyncLoginSelfHosted => '自己ホスト型サーバーにログインする';

  @override
  String get ankiSyncEmailOrUsername => 'メールアドレス / ユーザー名';

  @override
  String get ankiSyncEmailOrUsernameRequired => 'メールアドレスまたはユーザー名を入力してください';

  @override
  String get ankiSyncPassword => 'パスワード';

  @override
  String get ankiSyncPasswordRequired => 'パスワードを入力してください';

  @override
  String get ankiSyncLogin => 'ログイン';

  @override
  String get ankiSyncStatusPreparingServerSettings => 'サーバー設定を準備しています…';

  @override
  String get ankiSyncStatusReadingCollection => 'サーバーの収集ステータスを読み取り中…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      '接続されました。サーバー コレクションが空です。';

  @override
  String get ankiSyncStatusConnectedStatusRead =>
      '接続されました。サーバーのステータスが読み取られました。';

  @override
  String get ankiSyncStatusUpgradeClient => 'このサーバーには新しい同期クライアントが必要です。';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return 'ステータスチェックに失敗しました: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => 'アップロード設定を準備しています…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle =>
      'サーバーのコレクションをローカルのコレクションに置き換えますか?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      'サーバー コレクションはローカル データに完全に置き換えられます。 Stroom はまずローカル データベースのバックアップを保存します。\n\nメディア ファイルは、サーバーのメディア リストに従って両方向で同期されます。';

  @override
  String get ankiSyncOverwriteServerAction => 'サーバーコレクションを置き換える';

  @override
  String get ankiSyncStatusBackingUpUploading => 'コレクションのバックアップとアップロード中…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return 'サーバーはローカル コレクションを受け入れました。メディア同期が完了しました: アップロードされた $uploaded ファイル、ダウンロードされた $downloaded、削除された $deleted.$backup サーバーのステータスをもう一度確認してください。';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return 'ローカルバックアップ: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      'サーバー コレクションは置き換えられましたが、メディアの同期は完了しませんでした。';

  @override
  String get ankiSyncStatusUploadFailed => 'アップロードに失敗しました:';

  @override
  String get ankiSyncStatusPreparingDownload => 'ダウンロード設定を準備しています…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle =>
      'ローカルコレクションをサーバーコレクションに置き換えますか?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      'ローカル コレクションはサーバー データに置き換えられます。 Stroom はまずローカル データベースのバックアップを保存します。\n\nサーバー メディアがローカル メディアを置き換え、不足しているファイルがダウンロードされます。ステップが失敗した場合、またはアプリが途中で終了した場合、Stroom は次回デッキを開く前にローカルのコレクションとメディアを復元します。';

  @override
  String get ankiSyncReplaceLocalAction => 'ローカルデータを置き換える';

  @override
  String get ankiSyncStatusDownloadingValidating => 'コレクションをダウンロードして検証しています…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return 'ローカル コレクションは置き換えられ、SQLite チェックに合格しました。メディアの同期が完了しました: ダウンロードされた $downloaded ファイル、アップロードされた $uploaded、削除された $deleted.$backup サーバーのステータスをもう一度確認してください。';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => '同期を準備中…';

  @override
  String get ankiSyncStatusMergingChanges => 'コレクションの変更をマージしています…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'コレクションの変更がマージされました。メディア ファイルを同期しています…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '$notes メモ、$cards カード、および $reviews レビュー レコードが追加または更新されました';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges => 'マージするコレクションの変更はありません';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return '双方向同期が完了しました: $collection;メディアはアップロード $uploaded、ダウンロードされた $downloaded、削除された $deleted。';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'コレクションの変更はマージされましたが、メディアの同期は完了しませんでした:';

  @override
  String get ankiSyncStatusSyncIncomplete => '同期が完了しませんでした:';

  @override
  String get ankiSyncStatusClearingLogin => 'ログインセッションをクリアしています…';

  @override
  String get ankiSyncStatusLoggedOut => 'ログアウトしました。同期キーが安全なストレージから削除されました。';

  @override
  String get ankiSyncStatusClearLoginFailed => '保存されたログインセッションをクリアできませんでした';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      '操作が終了しませんでした。安全なストレージ、ネットワーク、サーバーのアドレスを確認してください。';

  @override
  String get ankiSyncUnknown => '未知';

  @override
  String get ankiSyncServerCollectionEmpty => 'サーバーコレクションが空です';

  @override
  String get ankiSyncServerCollectionAvailable => 'サーバーコレクションが利用可能です';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return 'スキーマ バージョン $schema · USN $usn · 変更された $modified';
  }

  @override
  String get asrPageTitle => '音声文字起こし';

  @override
  String get clear => 'クリア';

  @override
  String get configure => '設定する';

  @override
  String get asrModel => '認識モデル';

  @override
  String get reselectModel => 'モデルを再度選択してください';

  @override
  String get selectAsrModel => '認識モデルの選択';

  @override
  String get enterPublicAudioUrl => 'パブリックオーディオ URL を入力してください';

  @override
  String get recordingSelection => '録音';

  @override
  String get audioFiles => '音声ファイル';

  @override
  String get noAudioSelected => '音声ファイルが選択されていません';

  @override
  String get supportedAudioFormats => 'WAV、MP3、M4A、OGG などの一般的なオーディオ形式をサポート';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の音声ファイルを選択中',
      one: '$count 個の音声ファイルを選択中',
      zero: '音声ファイルは選択されていません',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の音声ファイルを選択中',
      one: '$count 個の音声ファイルを選択中',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => 'もう一度選択してください';

  @override
  String get asrUrlLabel => 'URL |パブリックリンク';

  @override
  String get asrErrorDetails => 'エラーの詳細を表示する';

  @override
  String get asrResultSaved => '文字起こし結果が保存されました';

  @override
  String get asrWorking => '文字起こし中…';

  @override
  String get asrStart => '文字起こしを開始する';

  @override
  String get saveTo => '保存先';

  @override
  String get rootFolder => 'ルートフォルダー';

  @override
  String get chooseSaveFolder => 'フォルダーを選択してください';

  @override
  String get linkAlreadyAdded => 'このリンクはすでにリストにあります';

  @override
  String get chooseAudioSource => 'オーディオソースを選択してください';

  @override
  String get inAppRecordings => 'アプリ内録音';

  @override
  String get chooseGeneratedRecordings => '生成された録音から選択する';

  @override
  String get systemAudioFiles => 'システムオーディオファイル';

  @override
  String get chooseDeviceAudioFiles => 'デバイスからファイルを選択してください';

  @override
  String get cannotReadAudioFile => '音声ファイルを読み取れませんでした';

  @override
  String chooseAudioFileFailed(String details) {
    return '音声ファイルを選択できませんでした: $details';
  }

  @override
  String get chooseInAppRecording => 'アプリ内録音を選択する';

  @override
  String get noRecordings => '録音なし';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds 秒',
      one: '$seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider => '最初に設定で音声転写プロバイダーとモデルを構成します';

  @override
  String get asrModelUnavailable => '元の認識モデルが利用できないか、検証できません。再度機種を選択してください。';

  @override
  String get asrUrlProviderRemoveFiles =>
      'このプロバイダーは、URL によって音声をアップロードします。ローカルのオーディオ ファイルを削除して、もう一度試してください。';

  @override
  String get asrFileProviderRemoveUrls =>
      'このプロバイダーは音声ファイルをアップロードしますが、リンクによる文字起こしはサポートしていません。リンクを削除して再試行してください。';

  @override
  String asrTaskStartFailed(String details) {
    return 'タスクを開始できませんでした: $details';
  }

  @override
  String get asrInvalidUrl => 'URLが無効です。 http:// または https:// で始まる必要があります';

  @override
  String get asrEnterAudioUrl => '音声の URL を入力してください';

  @override
  String get asrUrlProviderHelp =>
      'このプロバイダーは、URL によって音声をアップロードします。パブリックオーディオ URL (http/https) を入力します。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get add => '追加';

  @override
  String get ttsPageTitle => 'オーディオ';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の音声ファイルをインポートしました',
      one: '$count 個の音声ファイルをインポートしました',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return 'インポートに失敗しました: $details';
  }

  @override
  String get ttsFileReadFailed => 'ファイルデータを読み取れませんでした';

  @override
  String get ttsExportAudioFile => '音声ファイルをエクスポートする';

  @override
  String ttsExportedTo(String path) {
    return 'エクスポート先: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return 'エクスポートに失敗しました: $details';
  }

  @override
  String get ttsConfirmRegenerate => '再生を確認する';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return 'オーディオ「$fileName」を再生しますか?';
  }

  @override
  String get ttsRegenerateOverwrite => '再生後、元の音声ファイルは置き換えられます。';

  @override
  String get ttsRegenerate => 'オーディオを再生する';

  @override
  String ttsCopiedFailed(String details) {
    return 'コピーできませんでした: $details';
  }

  @override
  String get ttsChooseExportFolder => 'エクスポートフォルダーを選択してください';

  @override
  String get ttsExportAudio => 'オーディオのエクスポート';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のファイルをエクスポートしました',
      one: '$count 個のファイルをエクスポートしました',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => 'エクスポートフォルダー';

  @override
  String get ttsWebFolderExportHelp =>
      'お使いのブラウザではエクスポート フォルダーを選択できません。フォルダー構造が維持された状態で ZIP ファイルがダウンロードされます。';

  @override
  String get ttsDownloadZip => 'ZIPファイルをダウンロード';

  @override
  String get ttsExportAudioFolder => 'オーディオフォルダーをエクスポートする';

  @override
  String get ttsRecord => '記録';

  @override
  String get ttsImport => '輸入';

  @override
  String get ttsPlay => '遊ぶ';

  @override
  String get ttsExportLocal => 'デバイスにエクスポート';

  @override
  String get ttsRegenerateQuestion => '再生する';

  @override
  String get ttsNeedsProvider => '最初に設定で音声合成プロバイダーとモデルを構成します';

  @override
  String get ttsAddedToTasks => 'タスクリストに追加されました。バックグラウンドで生成中…';

  @override
  String get ttsCreateTitle => '音声合成';

  @override
  String get ttsOriginalTitle => '収録タイトル';

  @override
  String get ttsUseOriginalTitle => '元のタイトルを使用する';

  @override
  String get ttsAudioFileNameHint => '保存された音声ファイル名 (オプション)';

  @override
  String get ttsTextToConvert => '変換するテキスト';

  @override
  String get ttsSpeechContent => '講演内容';

  @override
  String get ttsTextHint => '音声に変換するテキストを入力してください…';

  @override
  String get ttsFullscreenEdit => '全画面で編集する';

  @override
  String ttsTextLimitWarning(int limit) {
    return 'テキストが制限を超えています (最大 $limit 文字)';
  }

  @override
  String get ttsSynthesisConfig => '合成設定';

  @override
  String get ttsVoiceAndSoundHelp => '音声とサウンドを調整する';

  @override
  String get ttsProviderSettingsLead => 'で';

  @override
  String get ttsProviderSettings => 'TTSプロバイダーの設定';

  @override
  String get ttsProviderSettingsTail => 'さらにパラメータを設定するには';

  @override
  String get ttsEditText => 'テキストを編集する';

  @override
  String get ttsClose => '閉じる';

  @override
  String get ttsVoice => '声';

  @override
  String get ttsSelectVoice => '音声を選択してください';

  @override
  String get ttsSpeed => 'スピード';

  @override
  String get ttsNormal => '普通';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsInstruction => '話し方指導';

  @override
  String get ttsInstructionHint => '例: 明るく興奮した口調で話す';

  @override
  String get ttsCustomParams => 'カスタムパラメータ';

  @override
  String ttsDefaultValue(Object value) {
    return 'デフォルト: $value';
  }

  @override
  String get ttsGenerateRecording => '録音の生成';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return '名前を付けて保存: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => 'フォルダーを選択してください';

  @override
  String get ttsFillTextError => '変換するテキストを入力してください';

  @override
  String get voiceBatchTitle => '音声を一括追加する';

  @override
  String get voiceBatchConfirm => '選択したボイスを追加する';

  @override
  String get voiceBatchSeparator => '区切り文字:';

  @override
  String get voiceBatchCustomSeparatorHint => 'カスタム区切り文字を入力してください';

  @override
  String get voiceBatchFieldOrder => 'フィールドの順序:';

  @override
  String get voiceBatchNameThenId => '1番目=名前、2番目=ID';

  @override
  String get voiceBatchIdThenName => '1番目 = ID、2番目 = 名前';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '列を $count 件検出しました。名前/ID の開始列を選択してください：',
      one: '列を $count 件検出しました。名前/ID の開始列を選択してください：',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return '列 $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn =>
      '1 つの列が検出されました。すべての値が ID (名前 = ID) として使用されます。';

  @override
  String get voiceBatchInputHint =>
      '名前と ID はタブ、カンマ、セミコロン、または縦棒で区切ります (1 行に 1 ペア)。';

  @override
  String get voiceBatchNoPreview => 'プレビューするものがありません';

  @override
  String get voiceName => 'ボイスネーム';

  @override
  String get voiceId => '音声ID';

  @override
  String get status => '状態';

  @override
  String get voiceNew => '✅ 新しい';

  @override
  String get voiceIdExists => '⚠️IDはすでに存在します';

  @override
  String voiceFormatError(String details) {
    return '❌ フォーマットエラー$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の重複 ID が見つかりました: $ids',
      one: '$count 件の重複 ID が見つかりました: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData => '選択した列に十分なデータがありません';

  @override
  String get voiceCustomSeparator => 'カスタム…';

  @override
  String get voiceCommaSeparator => 'カンマ(,)';

  @override
  String get voiceSemicolonSeparator => 'セミコロン(;)';

  @override
  String get voicePipeSeparator => '縦棒 (|)';

  @override
  String get voiceTabSeparator => 'タブ';

  @override
  String get voiceEditorTitle => 'ボイスを編集する';

  @override
  String get save => '保存';

  @override
  String get voiceAddRow => '行を追加';

  @override
  String get voiceBatchAdd => '一括追加';

  @override
  String get voiceNoneAdd => 'まだ声はありません。開始するには 1 つ追加してください。';

  @override
  String get delete => '消去';

  @override
  String get voiceDuplicateResolution => '以下の音声IDが重複しています。それぞれの処理方法を選択します。';

  @override
  String get update => 'アップデート';

  @override
  String get skip => 'スキップ';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の重複が残っています',
      one: '$count 件の重複が残っています',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => '編集を続ける';

  @override
  String get asrRetryIncomplete => 'リトライ音声が不完全です。リストをクリアして、すべてのオーディオを再度選択します。';

  @override
  String asrRetryAudioUnreadable(String details) {
    return 'リトライ音声データを読み込めませんでした。オーディオを再度選択します: $details';
  }

  @override
  String get asrLegacyRetryUnavailable => '従来の再試行音声は使用できません。オーディオを再度選択します。';

  @override
  String get asrRetryDataUnreadable => 'リトライデータを読み取れませんでした。オーディオを再度選択します。';

  @override
  String get ttsSynthesisModel => '合成モデル';

  @override
  String get asrRetryUnavailable => 'リトライ音声は利用できません。オーディオを再度選択します。';

  @override
  String get chatRequest => 'リクエスト';

  @override
  String get chatResponse => '応答';

  @override
  String get chatNoErrorDetails => '詳細はありません';

  @override
  String get ttsInstructionDescription =>
      'トーン、感情、スピード、アクセント、その他の性質を自然言語で説明します。モデルはそれに応じて合成音声を調整します。';

  @override
  String get audioPlayerSourceTextSource => 'ソーステキストを選択してください';

  @override
  String get audioPlayerChooseInAppText => 'アプリのテキストで選択';

  @override
  String get audioPlayerChooseSavedTextSubtitle => 'アプリから保存したテキストファイルを選択します';

  @override
  String get audioPlayerChooseSystemText => 'システムテキストファイルを選択してください';

  @override
  String get audioPlayerChooseDeviceTextSubtitle => 'デバイスストレージからテキストファイルを選択します';

  @override
  String get audioPlayerSelectInAppText => 'アプリのテキストで選択';

  @override
  String get audioPlayerNoTextFiles => 'テキスト ファイルはまだありません';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count 文字';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return 'テキストの選択に失敗しました: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => 'テキストファイルを読み取れません';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return 'ソーステキストのアップロードに失敗しました: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => 'テキストが空です';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return 'ソース テキストの保存に失敗しました: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => 'ソーステキストがアップロードされました';

  @override
  String get audioPlayerSourceTextUpdated => 'ソーステキストが更新されました';

  @override
  String get audioPlayerConfigureTtsProvider => '最初に TTS プロバイダーを構成します';

  @override
  String get audioPlayerNoStreamingModels => 'ストリーミング再生に対応している機種はありません';

  @override
  String get audioPlayerSelectStreamingModel => 'ストリーミング再生モデルを選択する';

  @override
  String get audioPlayerProviderFallback => 'プロバイダー';

  @override
  String audioPlayerStartStreaming(String model) {
    return 'ストリーミング再生開始：$model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return '音声ファイルが見つかりません: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => '音声データを読み込めません';

  @override
  String get audioPlayerSourceText => 'ソーステキスト';

  @override
  String get audioPlayerNoSourceText => '(原文なし)';

  @override
  String get audioPlayerUploadSourceText => 'ソーステキストをアップロードする';

  @override
  String get audioPlayerEditSourceText => 'ソーステキストを編集する';

  @override
  String get audioPlayerCompanionTextMissing => 'コンパニオンテキストファイルが見つかりません';

  @override
  String get audioPlayerPlaySelection => 'プレイセレクション';

  @override
  String get audioPlayerGenerateSelection => '選択範囲の生成';

  @override
  String get audioPlayerPlaying => '遊んでいます...';

  @override
  String get audioPlayerPaused => '一時停止中';

  @override
  String get audioPlayerPlaybackSpeed => '再生速度';

  @override
  String get audioPlayerFailed => '再生に失敗しました';

  @override
  String get audioPlayerRetry => 'リトライ';

  @override
  String get audioPlayerLoading => 'オーディオを読み込んでいます...';

  @override
  String get audioPlayerClose => '閉じる';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      'ブラウザでは録画はサポートされていません。アプリ版をご利用ください。';

  @override
  String get audioRecordingMicrophonePermissionRequired => '録音するにはマイクの許可が必要です';

  @override
  String audioRecordingStartFailure(String error) {
    return '記録の開始に失敗しました: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return '録画の一時停止に失敗しました: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return '記録の再開に失敗しました: $error';
  }

  @override
  String get audioRecordingInvalidFile => '録音ファイルが無効です。もう一度録音してください。';

  @override
  String audioRecordingStopFailure(String error) {
    return '記録の停止に失敗しました: $error';
  }

  @override
  String get audioRecordingFileNotFound => '録音ファイルが見つかりません';

  @override
  String get audioRecordingFileEmpty => '録音ファイルが空です';

  @override
  String audioRecordingSaved(String name) {
    return '保存された録音: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return '録画の保存に失敗しました: $error';
  }

  @override
  String get audioRecordingTitle => '録音';

  @override
  String get audioRecordingBrowserUnsupported => 'ブラウザでは録画はサポートされていません';

  @override
  String get audioRecordingUseApp => 'アプリ版を使用して録音する';

  @override
  String get audioRecordingDraftRecoveryHint =>
      '保存されていない録音ドラフトが見つかりました。オーディオライブラリに保存できます。';

  @override
  String get audioRecordingRecording => '録音 ●';

  @override
  String get audioRecordingPaused => '一時停止しました ||';

  @override
  String get audioRecordingPreparing => '準備中...';

  @override
  String get audioRecordingStart => '録音を開始する';

  @override
  String get audioRecordingPause => '一時停止';

  @override
  String get audioRecordingStopping => '停止中...';

  @override
  String get audioRecordingStop => '停止';

  @override
  String get audioRecordingResume => '再開する';

  @override
  String get audioRecordingSaving => '保存中...';

  @override
  String get audioRecordingSave => '録音を保存する';

  @override
  String get audioRecordingRecordAgain => '再度録音する';

  @override
  String get audioRecordingWaveformPaused => '録音が一時停止されました。波形がフリーズしている';

  @override
  String get audioRecordingWaveformLive => 'ライブオーディオ波形';

  @override
  String get audioSeparationTitle => 'ビデオとオーディオの分離';

  @override
  String get audioSeparationChooseVideoSource => 'ビデオソースを選択してください';

  @override
  String get audioSeparationChooseAppAlbum => 'アプリライブラリから選択';

  @override
  String get audioSeparationChooseSavedVideoSubtitle => 'アプリから保存したビデオを選択します';

  @override
  String get audioSeparationChooseSystemAlbum => 'システムストレージから選ぶ';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle =>
      'デバイスストレージからビデオファイルを選択します';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return 'ビデオの選択に失敗しました: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix => '音声抽出に失敗しました:';

  @override
  String get audioSeparationEngineMissing => '音声分離エンジンが検出されませんでした';

  @override
  String get audioSeparationEngineMissingHelp =>
      'アプリを再起動するか、アプリのリソースが完了していることを確認します。';

  @override
  String get audioSeparationNoVideoSelected => '動画が選択されていません';

  @override
  String get audioSeparationSupportedFormatsHint =>
      'サポートされている形式: mp4、mov、m4v、3gp';

  @override
  String get audioSeparationSuccess => 'オーディオが抽出され、オーディオ ライブラリに保存されました';

  @override
  String get audioSeparationView => 'ビュー';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 本の動画を選択中',
      one: '$count 本の動画を選択中',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => '抽出中...';

  @override
  String get audioSeparationExtractAudio => '音声を抽出する';

  @override
  String get audioSeparationSaveTo => '保存先';

  @override
  String get audioSeparationChooseSaveFolder => '保存フォルダーを選択してください';

  @override
  String get audioSeparationCannotReadVideoFile => 'ビデオファイルを読み取れません';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return 'ビデオ ファイルの選択に失敗しました: $error';
  }

  @override
  String get audioSeparationUnknownFormat => '未知';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return 'サポートされていない形式: $formats。サポートされている形式: MP4、MOV、M4V、3GP。';
  }

  @override
  String get audioSeparationEngineUnavailable => '音声分離エンジンが利用できません。';

  @override
  String get backgroundOptimizationTitle => 'バックグラウンドの最適化';

  @override
  String get backgroundOptimizationEnvironment => 'システム環境';

  @override
  String get backgroundOptimizationChecks => 'バックグラウンドサービスのステータス';

  @override
  String get backgroundOptimizationKeepAliveStrategies => 'キープアライブ戦略';

  @override
  String get backgroundOptimizationDetecting => 'チェック中…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      'このプラットフォームではバックグラウンド サービスがサポートされていません';

  @override
  String get backgroundOptimizationServiceRunning => 'バックグラウンドサービスが実行中です';

  @override
  String get backgroundOptimizationServiceStopped => 'バックグラウンドサービスが実行されていません';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      'バックグラウンドサービスのステータスを確認できませんでした';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      'デスクトップトレイは使用できません。ウィンドウを閉じるとアプリが終了します。';

  @override
  String get backgroundOptimizationDesktopCloseExits =>
      'デスクトップウィンドウが閉じるとアプリが終了します';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      'デスクトップトレイでアプリを実行し続ける';

  @override
  String get backgroundOptimizationStartFailed => 'サービスを開始できませんでした';

  @override
  String get backgroundOptimizationStopFailed => 'サービスを停止できませんでした';

  @override
  String get backgroundOptimizationRestartFailed => 'サービスを再起動できませんでした';

  @override
  String get backgroundOptimizationStopService => 'サービスの停止';

  @override
  String get backgroundOptimizationRestartService => 'サービスの再起動';

  @override
  String get backgroundOptimizationStartService => 'サービス開始';

  @override
  String get backgroundOptimizationRedetect => 'もう一度確認してください';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      'このプラットフォームではバックグラウンド サービス コントロールはサポートされていません。';

  @override
  String get backgroundOptimizationCheckingBattery => 'バッテリーの最適化ステータスを確認しています…';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      'このアプリではバッテリーの最適化が無効になっています';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      'バッテリーの最適化が有効になっています - バックグラウンドアクティビティが停止される可能性があります';

  @override
  String get backgroundOptimizationIgnoreBattery => 'バッテリーの最適化を無効にする';

  @override
  String get backgroundOptimizationExactAlarm =>
      '正確なアラームを許可する (より信頼性の高いバックグラウンド アクティビティ)';

  @override
  String get backgroundOptimizationWatchdogTitle => 'アラームマネージャーのウォッチドッグ';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      '有効にすると、Android はネイティブ アラームを使用して 5 分ごとにバックグラウンド サービスをチェックします。システムがプロセスを強制終了すると、アラームによってプロセスが再起動されます。\n\nデバイスが Doze モードにある間もアラームは機能し、再起動後に再スケジュールされます。\n\nバックグラウンド タスクに大きく依存するユーザーに推奨されます。\nバッテリーへの影響: 非常に低い。デバイスはチェックごとに短時間スリープ状態を解除します。';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      'ウォッチドッグ設定を保存できませんでした。変わってなかった';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      'ウォッチドッグをアクティブにできませんでした。バックグラウンドサービスのステータスは未確認です';

  @override
  String get backgroundOptimizationColdStartTitle => 'アプリ起動時にサービスを復元する';

  @override
  String get backgroundOptimizationColdStartDetail =>
      '有効にすると、アプリは開くたびに、以前に実行されていたバックグラウンド サービスを確認して復元します。\n\nシステムまたはユーザーがアプリのプロセスを停止した場合、次回アプリを開いたときにバックグラウンド サービスが再起動されます。\n\nすべてのユーザーに推奨されます。\nバッテリーへの影響: なし。アプリは起動時に 1 回だけチェックします。';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      '起動回復設定を保存できませんでした。変わってなかった';

  @override
  String get backgroundOptimizationBatteryReminderTitle => 'バッテリー最適化リマインダー';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      '有効にすると、このページにバッテリーの最適化ステータスが表示されます。アプリがバッテリー免除リストにない場合は、システム設定を開いて免除することができます。\n\nAndroid のバッテリー最適化 (Doze) により、バックグラウンド アプリが制限されます。このアプリを除外リストに追加すると、システムが電力を節約するためにアプリを停止することがなくなります。\n\nこれをオフにすると、リマインダー カードが非表示になるだけです。アプリのバッテリー免除は変わりません。';

  @override
  String get backgroundOptimizationStrategyIntro =>
      'これらの戦略は個別に有効にすることができます。最も信頼性の高いバックグラウンド アクティビティを実現するために、これらはすべてデフォルトでオンになっています。 1 つをオフにすると、その戦略のみに影響し、バックグラウンド サービス自体には影響しません。';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOSのバックグラウンドタスク';

  @override
  String get backgroundOptimizationIosSupported =>
      'このバージョンの iOS (26 以降) は、進行中のバックグラウンド タスクをサポートします。通常、アプリを切り替えたり画面をロックしたりしてもタスクは続行されますが、リソースが不足するとシステムがタスクを停止する場合があります。ロック画面で進行状況を確認できます。';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'このバージョンの iOS (26 より前) は、進行中のバックグラウンド タスクをサポートしていません。タスクの実行中は、数分ごと (約 5 ～ 10 分ごと。タイミングは iOS によって異なります) にアプリに戻ってバックグラウンド時間を更新し、一時停止を防ぎます。';

  @override
  String get backgroundOptimizationIosWarning =>
      'どの iOS バージョンでも、アプリ スイッチャーで Stroom をスワイプしないでください。これを実行すると、実行中のすべてのタスクが即座に停止します。';

  @override
  String get backgroundOptimizationDesktopIntro =>
      'デスクトップ システムにはモバイル プラットフォームのプロセス キープアライブ メカニズムがありませんが、アプリはウィンドウが閉じた後も実行を続けることができます。';

  @override
  String get backgroundOptimizationCloseMinimizeTitle => 'ウィンドウを閉じるときに最小化する';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      '有効にすると、ウィンドウの閉じるボタンをクリックすると、アプリが終了する代わりにシステム トレイに非表示になります。バックグラウンド タスクは引き続き実行されます。\n\nトレイ アイコンまたはその「メイン ウィンドウの表示」メニュー項目からウィンドウを復元します。終了するには、下の「アプリを終了」ボタンを使用してください。\n\nすべてのデスクトップ ユーザーに推奨されます。';

  @override
  String get backgroundOptimizationQuitApp => 'アプリを終了する';

  @override
  String get backgroundOptimizationGotIt => 'わかった';

  @override
  String get backgroundOptimizationWebNoteTitle => 'Web バックグラウンド タスク';

  @override
  String get backgroundOptimizationWebNote =>
      'ブラウザはアプリをバックグラウンドで実行し続けることはできません。このタブを閉じるか更新すると、ブラウザが非アクティブなバックグラウンド タブをフリーズすると、実行中のタスクが直ちに停止します。タスクの実行中は、「Stroom」タブを開いてフォアグラウンドにしておきます。';

  @override
  String get backgroundOptimizationTutorial => 'プラットフォームガイド';

  @override
  String get backgroundOptimizationTutorialDescription =>
      '各プラットフォームのバックグラウンド最適化ガイドを表示する';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      'バックグラウンド サービスのステータスを確認しています…';

  @override
  String get backgroundOptimizationServiceUnknown =>
      'バックグラウンド サービスのステータスが不明です。サービスが実行されているかどうかをもう一度確認してください。';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      'バックグラウンドサービスが実行中です。タスクはバックグラウンドで続行できます。';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'バックグラウンド サービスは Web ブラウザではサポートされていません。タスクを続行するには、このページを開いたままにしてください。';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      'デスクトップ トレイは使用できません (Linux ビルドには libaatana-appindicator3-dev が必要です)。ウィンドウを閉じるとアプリが終了します。';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      'デスクトップトレイは使用できません。ウィンドウを閉じるとアプリが終了します。';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      'アプリは、デスクトップ ウィンドウが閉じるときに終了するように設定されています。これは既存の終了確認フローに従い、トレイ内で実行を継続しません。';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      'デスクトップトレイが有効になります。ウィンドウを閉じると、アプリはシステム トレイに非表示になり、引き続き実行されます。トレイメニューの「メインウィンドウを表示」を選択すると元に戻ります。完全に終了するには、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      'デスクトップトレイが有効になります。ウィンドウを閉じると、アプリがシステム トレイに最小化され、そこで実行が継続されます。トレイアイコンをクリックするか、メニューから「メインウィンドウを表示」を選択するとウィンドウが元に戻ります。完全に終了するには、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      'バックグラウンドサービスが実行されていません。以下の「サービスの開始」を選択するか、プラットフォーム ガイドを参照してバックグラウンド アクティビティを最適化する方法を確認してください。';

  @override
  String get notificationSettingsPageTitle => '通知許可設定';

  @override
  String get notificationSettingsWebUnsupported => '通知は Web ブラウザではサポートされていません';

  @override
  String get notificationSettingsChecking => 'チェック中…';

  @override
  String get notificationSettingsPermissionGranted => '通知許可が付与されました';

  @override
  String get notificationSettingsPermissionDenied => '通知権限が付与されていません';

  @override
  String get notificationSettingsPermissionRestricted => '通知許可が制限されています';

  @override
  String get notificationSettingsPermissionBlocked => '通知許可が永久にブロックされました';

  @override
  String get notificationSettingsPermissionProvisional => '仮通知許可';

  @override
  String get notificationSettingsWebGuide => 'システム通知は Web ブラウザではサポートされていません。';

  @override
  String get notificationSettingsCheckingPermission => '通知許可を確認しています…';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      '通知許可が与えられます。タスク完了通知を有効にして、タスクが完了または失敗したときにシステム アラートを受信することができます。';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      '通知許可が与えられていません。下のボタンを選択して許可をリクエストするか、システム設定で Stroom への通知を有効にします。';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      '通知の許可は、ペアレンタルコントロールなどのシステムによって制限されています。システム設定で Stroom の通知設定を確認してください。';

  @override
  String get notificationSettingsEnvironment => 'システム環境';

  @override
  String get notificationSettingsPermissionSection => '通知の許可';

  @override
  String get notificationSettingsPlatformGuides => 'プラットフォームガイド';

  @override
  String get notificationSettingsGuideIntro =>
      'Stroom の通知を有効にするには、オペレーティング システムに応じて次の手順に従ってください。';

  @override
  String get notificationSettingsTaskCompleteTitle => 'タスク完了通知';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      'タスクが完了または失敗したときに通知を送信する';

  @override
  String get notificationSettingsCheckAgain => 'もう一度確認してください';

  @override
  String get notificationSettingsOpenSystemSettings => 'システム設定を開く';

  @override
  String get notificationSettingsRequestPermission => '許可のリクエスト';

  @override
  String get notificationSettingsGuideUnsupported =>
      'このプラットフォームでは通知設定ガイドは利用できません。';

  @override
  String get notificationSettingsUsageReason => 'タスクの完了時に通知を送信するには';

  @override
  String get notificationSettingsAndroidEnableTitle => '通知を有効にする';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      '「設定」→「アプリ」→「Stroom」→「通知管理」に移動し、通知を許可します。 Stroom が見つからない場合は、インストールされていることを確認してください。通知が無効になっている場合は、オンにします。';

  @override
  String get notificationSettingsAndroidDndTitle => '「サイレントモード」にチェックを入れる';

  @override
  String get notificationSettingsAndroidDndDescription =>
      '「設定」→「サウンドと振動」→「おやすみモード」に移動します。オフになっているか、Stroom 通知が許可されていることを確認してください。';

  @override
  String get notificationSettingsAndroidPopupTitle => '通知のポップアップを許可する';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'MIUI、EMUI、ColorOS などの一部の Android システムでは、アプリ情報で「通知を許可」と「ポップアップを許可」を有効にする必要があります。アプリの「通知フィルタリング」または「スマート通知」をオフにすることも検討してください。';

  @override
  String get notificationSettingsReturnTitle => 'このページに戻る';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      'これらの設定を変更した後、「再確認」を選択して許可状況を確認します。権限が付与されると、タスク完了通知を有効にすることができます。';

  @override
  String get notificationSettingsIosEnableDescription =>
      '「設定」→「通知」→「Stroom」に移動し、「通知を許可」をオンにします。また、バナーと通知センターでタスクのステータスを最新の状態に保つことができるようにします。';

  @override
  String get notificationSettingsIosFocusTitle => 'フォーカスをオフにする';

  @override
  String get notificationSettingsIosFocusDescription =>
      '「設定」→「フォーカス」に移動します。フォーカスがオフになっていることを確認するか、許可されたアプリのリストに Stroom を追加してください。フォーカスするとアプリの通知を沈黙させることができます。';

  @override
  String get notificationSettingsIosReturnDescription =>
      'これらの設定を変更した後、「再確認」を選択して許可状況を確認します。 iOS では、通常、システム設定で通知許可を手動で有効にする必要があります。';

  @override
  String get notificationSettingsWindowsEnableTitle => 'システム通知を有効にする';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      '「設定」→「システム」→「通知とアクション」に移動し、「アプリや他の送信者からの通知を受け取る」をオンにします。以下のアプリリストで Stroom を見つけて、通知がオンになっていることを確認してください。';

  @override
  String get notificationSettingsWindowsFocusTitle => 'フォーカスアシスト例外を追加する';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      '「設定」→「システム」→「フォーカスアシスト」に移動します。 Stroom を「優先のみ」に追加するか、フォーカス アシストをオフにします。フォーカスアシストは通知を消すことができます。';

  @override
  String get notificationSettingsMacEnableTitle => '通知を有効にする';

  @override
  String get notificationSettingsMacEnableDescription =>
      '「システム設定」→「通知」→「Stroom」に移動し、「通知を許可」をオンにします。バナーと通知センターも有効にします。';

  @override
  String get notificationSettingsMacFocusDescription =>
      '「システム設定」→「フォーカス」に移動します。フォーカスがオフになっていることを確認するか、許可されたアプリのリストに Stroom を追加してください。';

  @override
  String get notificationSettingsLinuxDesktopTitle => 'デスクトップ通知設定を確認する';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      'デスクトップ環境 (GNOME、KDE、XFCE など) に応じて、[システム設定] → [通知] に移動し、Stroom を見つけて、通知がオンになっていることを確認します。';

  @override
  String get notificationSettingsLinuxDaemonTitle => '通知デーモンを確認する';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux デスクトップ環境では、システム通知を表示するには、notify-osd や dunst などの通知デーモンが必要です。いずれかがインストールされ、実行されていることを確認してください。';

  @override
  String get backupRestorePageTitle => 'バックアップと復元';

  @override
  String get backupRestoreSelectBackupCategory =>
      'バックアップするデータ カテゴリを少なくとも 1 つ選択してください';

  @override
  String get backupRestorePreparingData => 'データを準備中…';

  @override
  String get backupRestoreExportingBackup => 'バックアップのエクスポート';

  @override
  String get backupRestoreCollectingDatabase => 'データベースレコードを収集しています…';

  @override
  String get backupRestoreProcessingSettings => '設定を処理中…';

  @override
  String get backupRestoreAddingTasks => 'タスクファイルを追加しています…';

  @override
  String get backupRestoreAddingPictures => '画像ファイルを追加しています…';

  @override
  String get backupRestoreAddingAudio => '音声ファイルを追加しています…';

  @override
  String get backupRestoreAddingVideo => 'ビデオ ファイルを追加しています…';

  @override
  String get backupRestoreAddingText => 'テキスト ファイルを追加しています…';

  @override
  String get backupRestoreAddingChat => 'チャット履歴と添付ファイルを追加しています…';

  @override
  String get backupRestoreCompressing => 'アーカイブを圧縮しています…';

  @override
  String get backupRestoreCompleted => '完了';

  @override
  String get backupRestoreSelectRestoreCategory =>
      '復元するデータ カテゴリを少なくとも 1 つ選択してください';

  @override
  String get backupRestoreConfirmRestore => '復元の確認';

  @override
  String get backupRestoreSelectedCategories => '選択されたデータ カテゴリ:';

  @override
  String get backupRestoreRestoreInfo =>
      'バックアップ内で見つかった選択したカテゴリがこのデバイスに復元されます。組み込みブラウザ Cookie を除くすべてのカテゴリは、対応するローカル データを置き換えます。 Cookie はドメイン、名前、パスによって書き込まれます。バックアップに含まれないローカル Cookie は保存されます。選択されていないカテゴリとバックアップから欠落しているカテゴリは変更されません。欠落しているカテゴリは通知とともにスキップされます。';

  @override
  String get backupRestoreRestartNotice =>
      '変更を有効にするには、復元後にアプリを再起動します。現在の作業が保存されていることを確認してください。';

  @override
  String get backupRestoreCancel => 'キャンセル';

  @override
  String get backupRestoreConfirmRestoreButton => '復元する';

  @override
  String get backupRestoreIncompleteTitle => '不完全な復元';

  @override
  String get backupRestoreIncompleteMessage =>
      'データを完全に復元できず、一部のデータが消去された可能性があります。アプリを再起動して、もう一度試してください。';

  @override
  String get backupRestoreSelectClearCategory =>
      'クリアするデータ カテゴリを少なくとも 1 つ選択してください';

  @override
  String get backupRestoreClearingData => 'データの消去';

  @override
  String get backupRestoreDeletingCategories => '選択したデータ カテゴリを削除しています…';

  @override
  String get backupRestoreClearedTitle => 'データが消去されました';

  @override
  String get backupRestorePartiallyClearedTitle => '一部のデータが消去されました';

  @override
  String get backupRestoreClearedMessage =>
      '選択したデータが消去されました。変更を有効にするには、アプリを再起動します。';

  @override
  String get backupRestorePartialClearMessage =>
      '他の選択データはクリアされました。このプラットフォームは、ブラウザーの組み込み Web サイト ストレージ (localStorage、IndexedDB など) を完全にクリアできないため、クリアできなかったブラウザー データが残ります。クリアしたデータを有効にするには、アプリを再起動します。';

  @override
  String backupRestoreClearFailed(String error) {
    return 'データをクリアできませんでした: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => '未完了をクリア';

  @override
  String get backupRestoreClearIncompleteMessage =>
      '一部のデータを消去できませんでした。アプリを再起動し、もう一度クリアしてみてください。';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki デッキのエクスポート先: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get backupRestoreApkgRequired => '.apkg ファイルを選択します';

  @override
  String backupRestoreImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return 'バックアップの保存先: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return 'バックアップ失敗: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return '復元に失敗しました: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected =>
      'バックアップフォルダーが選択されていません。起動時に 1 つを許可します。';

  @override
  String get backupRestoreRestoreSuccessTitle => 'データが復元されました';

  @override
  String get backupRestoreRestoredMessage =>
      'バックアップからデータが復元されました。復元したデータを使用するには、アプリを再起動します。';

  @override
  String get backupRestoreExitApp => 'アプリを終了する';

  @override
  String get backupRestoreRestartNow => '今すぐ再起動してください';

  @override
  String get backupRestoreSkippedTitle => '一部のデータがスキップされました';

  @override
  String get backupRestoreNothingRestoredTitle => 'データは復元されませんでした';

  @override
  String get backupRestoreGotIt => 'わかった';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return 'バックアップでは、これらの選択したカテゴリの復元可能なコンテンツが確認されなかったため、スキップされ、既存のデータが保持されました: $categories。';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      '古いバックアップでは、空のタスク ファイルは、空のタスク リストとそのプラットフォームによってエクスポートされていないタスクを区別できません。現在のタスクの上書きを避けるために、タスク カテゴリはスキップされ、既存のデータが保持されました。';

  @override
  String get backupRestoreSkippedCookies =>
      'バックアップにはインポートする組み込みのブラウザ Cookie が含まれていないため、このカテゴリはスキップされ、既存の Cookie が保持されました。';

  @override
  String get backupRestoreSkippedWebsiteData =>
      'この古いバックアップの Web サイト ストレージ ディレクトリはスキップされました。アーカイブに Cookie が含まれており、そのカテゴリが選択されている場合は、Cookie を個別にインポートできます。';

  @override
  String get backupRestoreApkgTitle => 'アンキデッキ';

  @override
  String get backupRestoreApkgInfoTitle => 'Anki デッキのインポートまたはエクスポート';

  @override
  String get backupRestoreApkgInfoMessage => 'カード情報のみが含まれ、メディアは含まれません';

  @override
  String get backupRestoreApkgDescription =>
      'Anki デッキを .apkg 形式でインポートまたはエクスポートする';

  @override
  String get backupRestoreExportingApkg => 'エクスポート中…';

  @override
  String get backupRestoreExportApkg => '.apkg をエクスポート';

  @override
  String get backupRestoreImportingApkg => 'インポート中…';

  @override
  String get backupRestoreImportApkg => '.apkgをインポートする';

  @override
  String get backupRestoreCategoryHeading => 'バックアップまたは復元するデータ カテゴリの選択';

  @override
  String get backupRestoreExporting => 'エクスポート中…';

  @override
  String get backupRestoreExportBackup => 'バックアップのエクスポート';

  @override
  String get backupRestoreRestoring => '復元中…';

  @override
  String get backupRestoreChooseBackup => 'バックアップファイルを選択して復元する';

  @override
  String get backupRestoreClearSelected => '選択したデータをクリア';

  @override
  String get backupRestoreClearDescription =>
      'バックアップ ファイルを使用せずに、選択したデータ カテゴリを直接クリアします。選択されていないカテゴリは変更されません。この操作は元に戻すことができません。';

  @override
  String get backupRestoreClearing => 'クリア中…';

  @override
  String get backupRestoreCategoryChat => 'チャット履歴と添付ファイル';

  @override
  String get backupRestoreCategoryChatDescription => 'チャットの会話、メッセージの内容、添付ファイル';

  @override
  String get backupRestoreCategorySettings => '設定';

  @override
  String get backupRestoreCategorySettingsDescription =>
      'アプリの構成、プロバイダーの設定、インターフェイスの設定';

  @override
  String get backupRestoreCategoryPictures => '画像';

  @override
  String get backupRestoreCategoryPicturesDescription => '写真とサムネイル';

  @override
  String get backupRestoreCategoryAudio => 'オーディオ';

  @override
  String get backupRestoreCategoryAudioDescription => '音声合成と録音';

  @override
  String get backupRestoreCategoryVideos => '動画';

  @override
  String get backupRestoreCategoryVideosDescription => 'ビデオファイル';

  @override
  String get backupRestoreCategoryTexts => '文章';

  @override
  String get backupRestoreCategoryTextsDescription => 'テキストドキュメント';

  @override
  String get backupRestoreCategoryTasks => 'タスク';

  @override
  String get backupRestoreCategoryTasksDescription => 'バックグラウンドタスクのレコード';

  @override
  String get backupRestoreCategoryAnki => 'Anki フラッシュカード データ';

  @override
  String get backupRestoreCategoryAnkiDescription => 'アンキデータベース';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki フラッシュカード データ';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Anki フラッシュカード データのバックアップまたは復元には、collection.media ディレクトリ内のカード メディアも含まれます。';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'Anki フラッシュカード データについて';

  @override
  String get backupRestoreCategoryBrowser => '内蔵ブラウザデータ';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      'Cookie のみをバックアップおよび復元します。クリアすると、サポートされている Web サイトのストレージも削除されます';

  @override
  String get backupRestoreViewInfo => '情報を見る';

  @override
  String get backupRestoreApkgInfoTooltip => 'Anki デッキのインポートとエクスポートについて';

  @override
  String get backupRestoreConfirmClear => 'クリアの確認';

  @override
  String get backupRestoreClearCategoriesIntro =>
      '次のデータ カテゴリは、バックアップ ファイルを使用せずにクリアされます。';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      'このプラットフォームは、ブラウザーの組み込み Web サイト ストレージ (localStorage、IndexedDB など) を完全にクリアできません。確定すると、選択した他のデータがクリアされます。消去できないブラウザデータは残ります。';

  @override
  String get backupRestoreUnselectedUnchanged => '選択されていないカテゴリは変更されません。';

  @override
  String get backupRestoreClearWarning =>
      'この操作は元に戻すことができません。変更を有効にするためにクリアした後、アプリを再起動します。';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return 'クリア ($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => 'ブラウザ環境';

  @override
  String get backupRestoreIntro =>
      '選択したデータ カテゴリを手動でエクスポートします。インポート中、アーカイブ内で見つかった選択されたカテゴリのみが復元されます。欠落しているカテゴリまたは必要なファイルは通知とともにスキップされ、選択されていないカテゴリは変更されません。選択したカテゴリを直接クリアすることもできます。';

  @override
  String get backupRestoreOtherSelectedRestored =>
      '選択した他のデータが復元されました。変更を有効にするには、アプリを再起動します。';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      '通知はブロックされています。システム設定を開き、Stroom の通知を許可します。';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      '通知はブロックされています。 「システム設定」→「アプリ」→「Stroom」→「通知管理」に移動し、通知を許可します。';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      '通知はブロックされています。 [システム設定] → [Stroom] → [通知] に移動し、通知を許可します。';

  @override
  String get textPreviewDiscardEditsTitle => '編集を破棄しますか?';

  @override
  String get textPreviewUnsavedChangesConfirm => '未保存の変更があります。本当に破棄してもよろしいですか?';

  @override
  String get textPreviewCancel => 'キャンセル';

  @override
  String get textPreviewDiscard => '破棄';

  @override
  String get textPreviewFontSize => 'フォントサイズを調整する';

  @override
  String get textPreviewRestoreDefault => 'デフォルトに戻す';

  @override
  String get textPreviewClose => '閉じる';

  @override
  String textPreviewSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get textPreviewUndo => '元に戻す';

  @override
  String get textPreviewRedo => 'やり直し';

  @override
  String get textPreviewSave => '保存';

  @override
  String get textPreviewEdit => '編集';

  @override
  String get textPreviewChartEdit => 'チャートの編集';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return 'サポートされていない形式をスキップ: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'テキストファイルを # 件インポートしました',
      one: 'テキストファイルを # 件インポートしました',
    );
    return '$_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get textStorageSaved => 'テキストが保存されました';

  @override
  String get textStorageLoadFailed => 'テキストコンテンツを読み込めません';

  @override
  String get textStorageReadFailed => 'ファイルデータの読み込みに失敗しました';

  @override
  String get textStorageExportTitle => 'テキストのエクスポート';

  @override
  String textStorageExportedTo(String path) {
    return 'エクスポート先: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get textStorageChooseExportDirectory => 'エクスポートディレクトリを選択してください';

  @override
  String get textStorageFolderExportTitle => 'エクスポートフォルダー';

  @override
  String get textStorageWebFolderExportInfo =>
      'ブラウザはエクスポート ディレクトリを選択できません。フォルダー構造を保持した ZIP ファイルがダウンロードされます。';

  @override
  String get textStorageCancel => 'キャンセル';

  @override
  String get textStorageDownloadZip => 'ZIPファイルをダウンロード';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 件のファイルをエクスポートしました',
      one: '# 件のファイルをエクスポートしました',
    );
    return '$_temp0';
  }

  @override
  String get textStorageExportFolderTitle => 'テキストフォルダーをエクスポートする';

  @override
  String textStorageCopyFailed(String error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get textStorageCreateNew => '新しい';

  @override
  String get textStorageImport => '輸入';

  @override
  String get textStorageTitle => '文章';

  @override
  String get textStorageExportToLocal => 'ローカルにエクスポート';

  @override
  String get textCreateEnterTitle => 'タイトルを入力してください';

  @override
  String textCreateSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get textCreateNewTitle => '新しい';

  @override
  String get textCreateSave => '保存';

  @override
  String get textCreateTitleLabel => 'タイトル';

  @override
  String get textCreateTitleHint => 'テキストタイトルを入力してください';

  @override
  String get textCreateFormatLabel => '形式';

  @override
  String get textCreateContentLabel => 'テキストの内容';

  @override
  String get textCreateContentHint => 'テキストコンテンツを入力してください...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform バックグラウンド最適化チュートリアル';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform バックグラウンド実行ガイド';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform バックグラウンド最適化ガイド';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return 'これらの手順は、$platform デバイスでの Stroom のバックグラウンド エクスペリエンスを最適化し、タスクをバックグラウンドで実行し続けるのに役立ちます。';
  }

  @override
  String get platformTutorialStepsHeading => '最適化の手順';

  @override
  String get platformTutorialTipsHeading => 'ヒント';

  @override
  String get platformTutorialTipsDescription =>
      'これらの設定が完了したら、「バックグラウンド最適化」ページに戻り、ステータスが更新されていることを確認します。それでも問題が解決しない場合は、別のプラットフォームのガイドを参照するか、GitHub で問題を報告してください。';

  @override
  String get platformTutorialAndroidStep1Title => 'バッテリーの最適化をオフにする';

  @override
  String get platformTutorialAndroidStep1Description =>
      '「設定」→「アプリ」→「Stroom」→「バッテリー」を開き、「制限なし」または「最適化しない」を選択します。このアプリの「バックグラウンド最適化」ページで「バッテリーの最適化を無視」をタップして、Stroom をシステムの省電力許可リストに追加することもできます。パスはデバイスのブランドによって異なります。';

  @override
  String get platformTutorialAndroidStep2Title => 'バックグラウンドアクティビティを許可する';

  @override
  String get platformTutorialAndroidStep2Description =>
      '「設定」→「アプリ」→「Stroom」を開き、「バックグラウンドアクティビティを許可」と「自動起動を許可」を有効にします。一部の電話では、セキュリティ センターまたは電話マネージャーで自動起動を許可する必要もあります。';

  @override
  String get platformTutorialAndroidStep3Title => 'バックグラウンドプロセスをロックする';

  @override
  String get platformTutorialAndroidStep3Description =>
      '最近のアプリ ビューで、Stroom カードを下にスワイプするか、ロック アイコンをタップして、システムがアプリを消去しないようにします。';

  @override
  String get platformTutorialAndroidStep4Title => '通知を許可する (Android 13 以降)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 以降では通知許可が必要です。これがないと、サービスは引き続き実行されますが、バックグラウンド サービスのフォアグラウンド通知は非表示になります。最初に「サービスを開始」をタップすると、アプリは許可を要求します。または、「設定」→「アプリ」→「Stroom」→「通知」で許可を有効にすることができます。';

  @override
  String get platformTutorialAndroidStep5Title => 'バッテリーの最適化を無視する';

  @override
  String get platformTutorialAndroidStep5Description =>
      'Stroom で「タスク完了通知」を有効にすると、アプリは関連する権限を要求します。また、「設定」→「アプリ」→「特別なアプリへのアクセス」→「バッテリーの最適化」で、Stroom が「最適化しない」に設定されていることを確認することもできます。';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Android デバイスの自動起動とバックグラウンド管理';

  @override
  String get platformTutorialAndroidStep6Description =>
      '多くの場合、デバイス メーカーは独自のバックグラウンド コントロールを追加します。\n• Xiaomi/Redmi (MIUI/HyperOS): 設定 → アプリ → 権限 → 自動起動。スルームを許可します。次に、「バッテリー」→「アプリのバッテリーセーバー」→「Stroom」→「制限なし」を開きます。\n• Huawei/Honor (EMUI/HarmonyOS): 設定 → アプリ → アプリ起動 → Stroom → 手動で管理。自動起動、二次起動、バックグラウンドアクティビティを許可します。\n• OPPO/OnePlus/realme (ColorOS): 設定 → バッテリー → アプリのバッテリー管理 → Stroom;完全なバックグラウンドアクティビティを許可します。\n• vivo/iQOO (OriginOS): iManager → アプリ管理 → 自動起動;スルームを許可します。';

  @override
  String get platformTutorialAndroidStep7Title => 'ロック画面のクリーンアップと省電力モードをオフにする';

  @override
  String get platformTutorialAndroidStep7Description =>
      '「設定」→「バッテリー」を開き、「省電力」または「超省電力」をオフにします。また、「ロック後のメモリ消去」を「消去しない」に設定してください。省電力モードはバックグラウンドアクティビティを制限し、タスクの完了に影響を与える可能性があります。';

  @override
  String get platformTutorialIosStep1Title => 'アプリのバックグラウンド更新を有効にする';

  @override
  String get platformTutorialIosStep1Description =>
      '「設定」→「一般」→「アプリのバックグラウンド更新」を開き、「Stroom」を見つけてオンにします。最高のエクスペリエンスを得るには、「Wi-Fi とモバイルデータ」を選択してください。';

  @override
  String get platformTutorialIosStep2Title => '通知を許可する';

  @override
  String get platformTutorialIosStep2Description =>
      '「設定」→「通知」→「Stroom」を開き、「通知を許可」をオンにします。タスクの更新をすぐに確認できるように、バナーと通知センターの両方を有効にします。';

  @override
  String get platformTutorialIosStep3Title => '低電力モードをオフにする';

  @override
  String get platformTutorialIosStep3Description =>
      '「設定」→「バッテリー」を開き、「低電力モード」をオフにします。このモードがオンになっている間、システムはバックグラウンド アクティビティを制限します。';

  @override
  String get platformTutorialIosStep4Title => 'iOSのバックグラウンド制限を理解する';

  @override
  String get platformTutorialIosStep4Description =>
      'iOS 26 より前のバージョンでは、Android アプリのようにアプリをバックグラウンドに残すことはできません。システムは、アプリのバックグラウンド更新、位置情報の更新、オーディオ再生などの特定の時間にのみアプリに短い実行時間を与え、長時間実行されるタスクを一時停止する場合があります。以下をお勧めします。\n• 長時間実行されるタスクの場合は、Stroom をフォアグラウンドに保ちます。\n• 定期的にアプリに戻って、バックグラウンド時間を更新します。\n• 重要なタスクについては「タスク完了通知」をオンにします。';

  @override
  String get platformTutorialIosStep5Title => 'タスク実行中のバックグラウンド ヒント';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 以降では、永続的なバックグラウンド タスクがサポートされています。通常、アプリを切り替えたり画面をロックしてもタスクは続行されますが、リソースが不足するとシステムがタスクを停止する場合があります。進行状況がロック画面に表示されます。\n\n以前の iOS バージョンは、永続的なバックグラウンド タスクをサポートしていません。数分ごとにアプリに戻り (5 ～ 10 分が目安であり、システムが決定します)、バックグラウンド時間を更新して一時停止を防ぎます。\n\nどのバージョンでも、アプリ スイッチャーで Stroom をスワイプしないでください。そうすることで、実行中のすべてのタスクが即座に停止されます。';

  @override
  String get platformTutorialIosStep6Title => 'アプリをフォアグラウンドに保ちます';

  @override
  String get platformTutorialIosStep6Description =>
      'iOS 26 より前のバージョンでは、アプリのバックグラウンド時間は限られています。長時間実行されるタスクの場合は、Stroom をフォアグラウンドに維持するか、定期的に Stroom に戻って時間を延長します。';

  @override
  String get platformTutorialWindowsStep1Title => 'ウィンドウを閉じるときに最小化する';

  @override
  String get platformTutorialWindowsStep1Description =>
      'デフォルトでは、ウィンドウの閉じるボタンをクリックすると、Stroom がシステム トレイ (時計の近く) に最小化され、実行を続けることができます。トレイアイコンまたは「メインウィンドウの表示」メニューから復元してください。タスクの実行中は終了しないでください。終了するには、「バックグラウンド最適化」ページの「アプリケーションを完全に終了する」を使用するか、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get platformTutorialWindowsStep2Title => 'バッテリーセーバーをオフにする';

  @override
  String get platformTutorialWindowsStep2Description =>
      '「設定」→「システム」→「電源とスリープ」を開き、バッテリーセーバーをオフにします。あるいは、バッテリーが選択したレベルを下回った場合にのみオンになるように設定します。';

  @override
  String get platformTutorialWindowsStep3Title => 'バックグラウンドアプリを許可する';

  @override
  String get platformTutorialWindowsStep3Description =>
      '[設定] → [プライバシーとセキュリティ] → [バックグラウンド アプリ] を開き、Stroom を見つけて有効になっていることを確認します。 Windows 11 では、「設定」→「アプリ」→「インストールされているアプリ」→「Stroom」→「詳細オプション」→「バックグラウンド アプリのアクセス許可」に移動し、「常に」を選択します。';

  @override
  String get platformTutorialWindowsStep4Title => 'スリープモードをオフにする (オプション)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'Stroom を長時間実行し続けるには、「設定」→「システム」→「電源」を開き、「スリープ」を「なし」に設定します (電源に接続されている場合のみ)。';

  @override
  String get platformTutorialWindowsStep5Title => 'Stroom をスタートアップに追加する';

  @override
  String get platformTutorialWindowsStep5Description =>
      'タスク マネージャー (Ctrl+Shift+Esc) → [スタートアップ] を開き、Stroom を見つけて [有効にする] を右クリックします。または、「設定」→「アプリ」→「スタートアップ」を開き、Stroom をオンにします。';

  @override
  String get platformTutorialMacosStep1Title => 'ウィンドウを閉じるときに最小化する';

  @override
  String get platformTutorialMacosStep1Description =>
      'デフォルトでは、ウィンドウを閉じてもメニュー バー (画面の右上) で Stroom が実行されたままになります。メニューバーアイコンをクリックするか、「メインウィンドウを表示」を選択して元に戻します。タスクの実行中は終了しないでください。終了するには、「バックグラウンド最適化」ページの「アプリケーションを完全に終了する」を使用するか、メニューバーメニューから「Quit Stroom」を選択します。';

  @override
  String get platformTutorialMacosStep2Title => '通知を許可する';

  @override
  String get platformTutorialMacosStep2Description =>
      'システム設定 → 通知 → Stroom を開き、「通知を許可」をオンにします。バナーと通知センターの両方を有効にすることをお勧めします。';

  @override
  String get platformTutorialMacosStep3Title => '低電力モードをオフにする (MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      '「システム設定」→「バッテリー」→「電源アダプター」を開き、「低電力モード」をオフにします。このモードはバックグラウンドアクティビティを制限します。';

  @override
  String get platformTutorialMacosStep4Title => 'アプリをアクティブなままにしておく';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS では、バックグラウンド アプリにほとんど制限がありません。長時間実行されるタスクの場合は、Stroom ウィンドウを開いたままにしてください。アプリを強制終了しないでください。窓を閉めれば十分です。';

  @override
  String get platformTutorialMacosStep5Title => 'ログイン時に起動 (オプション)';

  @override
  String get platformTutorialMacosStep5Description =>
      'システム設定→一般→ログイン項目を開き、コンピュータの起動時に自動的に開始されるように Stroom を追加します。';

  @override
  String get platformTutorialLinuxStep1Title => 'ウィンドウを閉じるときに最小化する';

  @override
  String get platformTutorialLinuxStep1Description =>
      'デフォルトでは、ウィンドウを閉じると Stroom がシステム トレイに非表示になります (ビルド時に StatusNotifierItem サポートと libayatana-appindicator3-dev を備えたデスクトップ環境が必要です)。トレイメニューから「メインウィンドウを表示」で元に戻してください。タスクの実行中は終了しないでください。終了するには、「バックグラウンド最適化」ページの「アプリケーションを完全に終了する」を使用するか、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get platformTutorialLinuxStep2Title => 'デスクトップ環境の設定';

  @override
  String get platformTutorialLinuxStep2Description =>
      'デスクトップ環境 (GNOME、KDE、XFCE など) に応じて、[システム設定] → [アプリ] を開き、Stroom を見つけて、バックグラウンド アクティビティが制限されていないことを確認します。';

  @override
  String get platformTutorialLinuxStep3Title => 'systemd サービスを使用する (オプション)';

  @override
  String get platformTutorialLinuxStep3Description =>
      '長時間実行されるバックグラウンド作業の場合は、systemd ユーザー サービスを作成します。 ~/.config/systemd/user/ の下に stroom.service ファイルを作成し、ExecStart を Stroom 実行可能ファイルに設定します。';

  @override
  String get platformTutorialLinuxStep4Title => 'スリープを無効にする';

  @override
  String get platformTutorialLinuxStep4Description =>
      '長時間実行する必要があるサーバーまたはデスクトップの場合は、/etc/systemd/logind.conf で HandleLidSwitch=ignore を設定して、蓋が閉じたときにスリープしないようにします。';

  @override
  String get platformTutorialLinuxStep5Title => '自動起動を有効にする';

  @override
  String get platformTutorialLinuxStep5Description =>
      'GNOME では、「調整」→「アプリケーションの起動」→「Stroom の追加」を使用します。または、~/.config/autostart/ に stroom.desktop ファイルを作成します。';

  @override
  String get platformTutorialWebStep1Title => 'タブを開いたままにしておきます';

  @override
  String get platformTutorialWebStep1Description =>
      'Web ブラウザはバックグラウンド サービスをサポートしていません。タスクの実行中は、「Stroom」タブを開いたままにしてください。タブを閉じるかページを更新すると、すぐに中断されます。';

  @override
  String get platformTutorialWebStep2Title => 'ブラウザがタブを一時停止しないようにする';

  @override
  String get platformTutorialWebStep2Description =>
      'ブラウザは、リソースを節約するために非アクティブなバックグラウンド タブをフリーズする場合があります。タスクの実行中は [Stroom] タブをフォアグラウンドに維持するか、定期的にページを操作してアクティブな状態を保ちます。';

  @override
  String get browserNavigationFailed => 'ページナビゲーションに失敗しました。アドレスが復元されました';

  @override
  String get browserAddressHint => 'Web アドレスを入力してください';

  @override
  String get browserUserScripts => 'ユーザースクリプト';

  @override
  String get browserSwitchToMobile => 'モバイル表示に切り替える';

  @override
  String get browserSwitchToDesktop => 'デスクトップビューに切り替える';

  @override
  String get browserUaSwitchedDesktop => 'デスクトップ ユーザー エージェントに切り替えました';

  @override
  String get browserUaSwitchedMobile => 'モバイル ユーザー エージェントに切り替えました';

  @override
  String get browserCookieRetentionOnTooltip => 'Cookie の永続化 (オン)';

  @override
  String get browserCookieRetentionOffTooltip => 'Cookie の永続化 (オフ)';

  @override
  String get browserCookiePersistenceEnabled => 'Cookie の永続化が有効になっています';

  @override
  String get browserCookiePersistenceDisabled => 'Cookie の永続性が無効になっています';

  @override
  String get browserSniffPanelHideTooltip => 'スニフパネルを非表示にする';

  @override
  String get browserSniffPanelShowTooltip => 'スニフパネルを表示';

  @override
  String get browserAdd => '追加';

  @override
  String get browserNoScripts => 'まだスクリプトはありません。 「追加」をタップして作成します。';

  @override
  String get browserUnnamedScript => '無題のスクリプト';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のルールに一致',
      one: '$count 件のルールに一致',
    );
    return '$_temp0';
  }

  @override
  String get browserScriptOriginManual => '手動で追加';

  @override
  String browserScriptVersion(Object version) {
    return '@バージョン $version';
  }

  @override
  String get browserScriptEnabled => '有効';

  @override
  String get browserScriptDisabled => '無効';

  @override
  String get browserScriptRuntimeError =>
      'このスクリプトで実行時エラーが発生しました。コードとページの互換性を確認してください。';

  @override
  String get browserScriptDelete => '消去';

  @override
  String get browserDeleteScriptTitle => 'スクリプトを削除しますか?';

  @override
  String get browserDeleteScriptConfirmation =>
      'このスクリプトはこのブラウザから削除されます。この操作は元に戻すことができません。';

  @override
  String get browserEditScript => 'スクリプトの編集';

  @override
  String get browserScriptName => 'スクリプト名';

  @override
  String get browserScriptCode => 'スクリプトコード（JavaScript）';

  @override
  String get browserAddScriptMethod => 'スクリプトの追加方法を選択する';

  @override
  String get browserImportFromUrl => 'URLからインポート';

  @override
  String get browserEnterManually => '手動で入力';

  @override
  String get browserScriptTrustWarningTitle => '信頼できるスクリプトのみをインポートする';

  @override
  String get browserScriptTrustWarning =>
      '信頼できるスクリプトのみを追加してください。追加しないとデータが漏洩する可能性があります。スクリプトは Web ページのコンテンツを読み取りまたは変更できます。';

  @override
  String get browserContinue => '続く';

  @override
  String get browserManualUserscriptLabel => 'Tampermonkey ユーザースクリプト';

  @override
  String get browserScriptImportUrl => 'スクリプトの URL';

  @override
  String get browserScriptImportFetch => 'プレビューを取得する';

  @override
  String get browserScriptPreview => 'スクリプトソースのプレビュー';

  @override
  String get browserScriptImportInvalidUrl => '有効な HTTPS URL を入力します。';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Greasy Fork .user.js URL または GitHub Raw URL を使用します。';

  @override
  String get browserScriptImportRedirectedUrl =>
      'URL がサポートされていないアドレスまたは安全でないアドレスにリダイレクトされました。';

  @override
  String get browserScriptImportNotScript =>
      '応答が空であるか、JavaScript スクリプトではないようです。';

  @override
  String get browserScriptImportNetworkError =>
      'スクリプトを取得できませんでした。 URL と接続を確認してください。';

  @override
  String browserScriptImportHttpError(Object status) {
    return 'サーバーは HTTP $status を返しました。';
  }

  @override
  String get browserCancel => 'キャンセル';

  @override
  String get browserSave => '保存';

  @override
  String get browserCookiesConfirmClear => 'クリアの確認';

  @override
  String get browserCookiesConfirmClearAll =>
      'すべての Cookie をクリアしますか?\nこの操作は元に戻すことができません。';

  @override
  String get browserCookiesClear => 'クリア';

  @override
  String get browserCookiesCancel => 'キャンセル';

  @override
  String get browserCookiesClearedAll => 'すべての Cookie がクリアされました';

  @override
  String get browserCookiesClearFailed => 'クリアできませんでした。もう一度やり直してください。';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return '$domain のすべての Cookie がクリアされました';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '$domain の Cookie をすべてクリアしますか?';
  }

  @override
  String get browserCookiesPageTitle => 'ブラウザのデータ管理';

  @override
  String get browserCookiesRetentionTitle => '終了時に Cookie を保持する';

  @override
  String get browserCookiesRetentionOn => '有効 — 終了時に Cookie が保持されます。';

  @override
  String get browserCookiesRetentionOff => '無効 — 終了時に Cookie がクリアされます';

  @override
  String get browserCookiesClearAllTitle => 'すべての Cookie をクリアする';

  @override
  String get browserCookiesClearAllDescription =>
      '保存されている Web サイトの Cookie をすべて削除します';

  @override
  String get browserCookiesEmptyTitle => '永続的なデータはありません';

  @override
  String get browserCookiesEmptyDescription =>
      '内蔵ブラウザを使用し、Cookie の永続化を有効にして保存されたデータをここに表示します。';

  @override
  String browserCookiesStoredCount(Object count) {
    return '保存された Cookie ($count)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の Cookie',
      one: '$count 個の Cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip => 'このドメインの Cookie をすべてクリアします';

  @override
  String get browserCookiesDeleteOneTooltip => 'このクッキーを削除します';

  @override
  String get browserCookiesDeletedOne => 'クッキーが削除されました';

  @override
  String get browserCookiesDeleteFailed => '削除できませんでした。もう一度やり直してください。';

  @override
  String get browserCookiesEmptyValue => '(空の値)';

  @override
  String get platformTutorialPageTitle => 'プラットフォームのチュートリアル';

  @override
  String get browserRecoveryOpenPage => '回復ページを開く';

  @override
  String galleryUnsupportedPreview(String format) {
    return '.$format ファイルではプレビューはサポートされていません';
  }

  @override
  String galleryCameraFailed(String error) {
    return '写真を撮影できませんでした: $error';
  }

  @override
  String get galleryPhotoSaved => '写真を保存しました';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return 'サポートされていない形式をスキップ: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '画像を # 枚インポートしました',
      one: '画像を # 枚インポートしました',
    );
    return '$_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '動画を # 本インポートしました',
      one: '動画を # 本インポートしました',
    );
    return '$_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get galleryFileReadFailed => 'ファイルデータを読み取れませんでした';

  @override
  String get galleryExportImageTitle => '画像のエクスポート';

  @override
  String get galleryExportVideoTitle => 'ビデオのエクスポート';

  @override
  String galleryExportedTo(String path) {
    return 'エクスポート先: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get galleryChooseExportDirectory => 'エクスポートディレクトリを選択してください';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 件のファイルをエクスポートしました',
      one: '# 件のファイルをエクスポートしました',
    );
    return '$_temp0';
  }

  @override
  String get galleryFolderExportTitle => 'エクスポートフォルダー';

  @override
  String get galleryWebFolderExportInfo =>
      'ブラウザはエクスポート ディレクトリを選択できません。フォルダー構造を保持した ZIP ファイルがダウンロードされます。';

  @override
  String get galleryDownloadZip => 'ZIPファイルをダウンロード';

  @override
  String get galleryExportImageFolderTitle => '画像フォルダーのエクスポート';

  @override
  String get galleryExportVideoFolderTitle => 'ビデオフォルダーをエクスポートする';

  @override
  String get galleryImagePageTitle => 'ギャラリー';

  @override
  String get galleryVideoPageTitle => '動画';

  @override
  String get galleryTakePhoto => '写真を撮る';

  @override
  String get galleryRecordVideo => '記録';

  @override
  String get galleryImport => '輸入';

  @override
  String get galleryExportToLocal => 'ローカルにエクスポート';

  @override
  String get galleryPlayVideo => '遊ぶ';

  @override
  String galleryCopyFailed(String error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get galleryVideoSaved => '保存されたビデオ';

  @override
  String galleryVideoRecordFailed(String error) {
    return '記録に失敗しました: $error';
  }

  @override
  String get galleryVideoLoadFailed => 'ビデオを読み込めませんでした';

  @override
  String get imageEditorSaveImageTitle => '画像の保存';

  @override
  String get imageEditorSaveImagePrompt => '画像の保存方法を選択します。';

  @override
  String get imageEditorOverwrite => '上書き';

  @override
  String get imageEditorSaveAs => '名前を付けて保存';

  @override
  String get imageEditorSavePhotoTitle => '写真を保存';

  @override
  String get imageEditorSavePhotoPrompt => 'この写真を保存しますか?';

  @override
  String get imageEditorDiscard => '破棄';

  @override
  String get imageEditorDoneLoading => '画像を生成中。お待ちください…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return 'クイック編集 – $fileName';
  }

  @override
  String get imageEditorNotReady => 'エディタの準備ができていません。しばらくしてからもう一度お試しください。';

  @override
  String imageEditorProcessingFailed(String error) {
    return '画像を処理できませんでした: $error';
  }

  @override
  String get imageEditorLoadFailed => '画像を読み込めませんでした';

  @override
  String get imageEditorProcessing => '画像を加工中。お待ちください…';

  @override
  String get imageEditorRotateLeft => '左に回転';

  @override
  String get imageEditorRotateRight => '右回転';

  @override
  String get imageEditorFlip => 'フリップ';

  @override
  String get imageEditorCrop => '作物';

  @override
  String get imageViewerImageSavedAsCopy => '画像をコピーとして保存しました';

  @override
  String get imageViewerImageUpdated => '画像を更新しました';

  @override
  String imageViewerSaveFailed(String error) {
    return '画像を保存できませんでした: $error';
  }

  @override
  String get imageViewerInvalidIndex => '無効な画像インデックス';

  @override
  String get galleryExportImageArchiveFileName => '画像エクスポート.zip';

  @override
  String get galleryExportVideoArchiveFileName => 'ビデオエクスポート.zip';

  @override
  String get galleryExportImageFolderArchiveFileName => '画像フォルダーのエクスポート.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName => 'ビデオフォルダーのエクスポート.zip';

  @override
  String get catCatchPageTitle => 'Web リソース ダウンローダー';

  @override
  String get catCatchAddTask => 'タスクの追加';

  @override
  String get catCatchOpenBrowser => '内蔵ブラウザ';

  @override
  String get catCatchEmptyState => 'ダウンロードタスクはまだありません';

  @override
  String get catCatchEmptyStateHint => '右上の + をタップしてダウンロードタスクを追加します';

  @override
  String get catCatchInvalidCapturedUrl => 'キャプチャされた URL は無効です';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return 'ブラウザからキャプチャ: $url';
  }

  @override
  String get catCatchEnterValidUrl => '少なくとも 1 つの有効な URL を入力してください';

  @override
  String get catCatchTaskAdded => 'タスクが追加されました';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のタスクを追加しました',
      one: '$count 件のタスクを追加しました',
    );
    return '$_temp0';
  }

  @override
  String get catCatchViewTaskList => 'タスクリストを表示する';

  @override
  String get catCatchUrlHint => 'ビデオ/オーディオ Web ページの URL を入力してください';

  @override
  String get catCatchDeleteTask => 'このタスクを削除します';

  @override
  String get catCatchHour => '営業時間';

  @override
  String get catCatchMinute => '分';

  @override
  String get catCatchSecond => '秒';

  @override
  String get catCatchDurationPreview => 'プレビュー:';

  @override
  String get catCatchDurationFormat => '時:分:秒';

  @override
  String get catCatchDurationFilterHint =>
      'オプション: ビデオ リソースを長さによってフィルタリングします。選択対象のすべてのリソースを表示するには、空白のままにします';

  @override
  String get catCatchVideoSaveTo => 'ビデオの保存先';

  @override
  String get catCatchAudioSaveTo => 'オーディオの保存先';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のタスクを追加しました',
      one: '$count 件のタスクを追加しました',
    );
    return '$_temp0';
  }

  @override
  String get catCatchStartAnalysis => '分析する';

  @override
  String get catCatchVideoFolderTitle => '動画保存フォルダ';

  @override
  String get catCatchAudioFolderTitle => '音声保存フォルダー';

  @override
  String get catCatchRootFolder => 'ルートフォルダー';

  @override
  String connectivityTestTitle(String title) {
    return '$title · 接続テスト';
  }

  @override
  String get connectivityTestJsonLabel => 'テスト内容(JSON)';

  @override
  String get connectivityTestJsonHelp =>
      '変更を直接実行または保存できます。 MCP は読み取り専用のツール/リストを使用します。検索ツールはクエリ/カウントを変更できます。 Todo はデフォルトでは読み取り専用です。';

  @override
  String connectivityTestSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get connectivityTestSaved => 'テスト内容が保存されました';

  @override
  String get connectivityTestClose => '閉じる';

  @override
  String get connectivityTestSaveContent => 'コンテンツの保存';

  @override
  String get connectivityTestTesting => 'テスト中…';

  @override
  String get connectivityTestRun => 'テストの実行';

  @override
  String get connectivityTestFailedSummary => 'テストを完了できませんでした';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds秒';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds ミリ秒';
  }

  @override
  String get messageSearchTitle => 'メッセージの検索';

  @override
  String get messageSearchHint => 'すべての会話にわたってメッセージを検索します...';

  @override
  String get messageSearchInitialState => 'キーワードを入力してすべての会話のメッセージを検索します';

  @override
  String get messageSearchEmptyState => '一致するメッセージが見つかりませんでした';

  @override
  String get messageSearchNewConversation => '新しい会話';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件一致',
      one: '$count 件一致',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => '文章';

  @override
  String get filesTabAudio => 'オーディオ';

  @override
  String get filesTabImages => '画像';

  @override
  String get filesTabVideos => '動画';

  @override
  String get filesReorderTabs => 'タブの並べ替え';

  @override
  String get filesReorderCancel => 'キャンセル';

  @override
  String get filesReorderDone => '終わり';

  @override
  String get bgTaskCancelled => 'キャンセル';

  @override
  String bgTaskAsrError(String details) {
    return '音声の文字起こしに失敗しました: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return '音声文字起こしの保存に失敗しました: $details';
  }

  @override
  String bgTaskOcrRequestSizeExceeded(int encodedBytes, int budgetBytes) {
    return 'OCRリクエストのJSONサイズは$encodedBytesバイトで、設定された上限$budgetBytesバイトを超えています。';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR が失敗しました: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'OCR 結果の保存に失敗しました: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR 結果が不完全です: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => '一部の OCR ページが完了していませんでした';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return '・フェーズ $phaseElapsedMs ms ・$completedRequests リクエスト ・$completedChunks/$chunkCount チャンクが完了';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return 'オーディオをアップロード中$chunk $percent% · $bytes バイト$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return 'オーディオをアップロード中$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return '(チャンク $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return '転記$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return '転記中 (チャンク $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return '転記中 (チャンク受信 $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return '受信結果 $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => '受信結果';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return '転写中 ($index/$count チャンクが完了しました)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return '転記中 (チャンク $index/$count が返されました)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return '画像 $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return '$details をアップロードしています';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return '画像をアップロードしています $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR リカバリ チェックポイントを保存できませんでした。リクエストの結果が不確かで、タスクが停止されました: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR リカバリ チェックポイントを保存できませんでした。このチャンクは送信されなかったので、ローカル ストレージを修正した後に再試行できます: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'ASR チャンクの状態をキャンセルする前に保存できませんでした。このチャンクの結果は依然として不確実です: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'ASR 再試行オーディオを保存できませんでした。タスクは送信されませんでした: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError =>
      '別の音声ファイルを保存できませんでした。送信がキャンセルされました';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR が不完全な結果を返しました (finish_reason=$finishReason)';
  }

  @override
  String ocrResultPageHeading(String index) {
    return '画像 $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return '画像 $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => '(結果の一部)';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return '一部の画像が完全に認識されませんでした: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return '画像 $index: 不完全な結果';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return '画像 $index: 認識に失敗しました';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => ';';

  @override
  String get bgTaskInterruptedOnRestart => 'アプリ再起動時に中断される';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR エラーの詳細は非表示になりました';

  @override
  String get bgTaskErrorDetailsHidden => 'エラーの詳細は非表示になりました';

  @override
  String get notificationBannerTaskCompletedHeading => 'タスクが完了しました';

  @override
  String get notificationBannerTaskFailedHeading => 'タスクが失敗しました';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return '完了したタスク: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return 'タスクが失敗しました: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title完成';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title が失敗しました: $error';
  }

  @override
  String get notificationUnknownError => '不明なエラー';

  @override
  String get desktopTrayTooltip => 'バックグラウンドでストルームが実行されています';

  @override
  String get desktopTrayOpen => 'オープンストルーム';

  @override
  String get desktopTrayShowMainWindow => 'メインウィンドウを表示';

  @override
  String get desktopTrayQuitStroom => 'ストルームをやめる';

  @override
  String get providerPresetExaDescription =>
      'セマンティック検索とキーワード検索を使用して、Web を検索し、ページ コンテンツを抽出し、Exa MCP を通じて詳細な調査をサポートします。';

  @override
  String get providerPresetExaApiKeyHint => 'Exa Web サイトから API キーを取得します。';

  @override
  String get providerPresetTavilyDescription =>
      '大規模な言語モデル向けに最適化されたリアルタイム Web 検索用の AI ネイティブ検索エンジン。';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Tavily から API キーを取得します。 ?tavilyApiKey= または Authorization: Bearer ヘッダーをサポートします。';

  @override
  String get providerPresetJinaDescription =>
      'Web コンテンツの抽出、埋め込みの生成、検索結果の取得を行うマルチモーダル AI サービス。';

  @override
  String get providerPresetJinaApiKeyHint =>
      'Jina AI API キー (ベアラー トークン) を Web サイトから取得します。';

  @override
  String get providerPresetFirecrawlDescription =>
      'ページをクリーンな Markdown または構造化データに変換する Web クローリングおよび抽出サービス。';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Firecrawl API キーを取得するか、無料利用枠の制限内でキーなしで試してみてください。';

  @override
  String get providerPresetZhipuDescription =>
      'Web ページを取得して理解するための Zhipu AI の Web リーダー MCP サービス。';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Zhipu AI Open Platform から API キー (ベアラー トークン) を取得します。';

  @override
  String get providerPresetBraveSearchDescription =>
      '高品質の Web 結果を提供する、プライバシーを重視した独立した検索エンジンです。';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Brave Search Web サイトから API キーを取得します。';

  @override
  String get providerPresetBochaDescription =>
      'Bocha AI Web 検索は、中国語ページのインテリジェントな検索結果を提供します。';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Bocha AI Open Platform から API キー (ベアラー トークン) を取得します。';

  @override
  String get providerPresetQueritDescription =>
      'Querit AI 検索は、インテリジェントな検索とコンテンツ検出を提供します。';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Querit WebサイトからAPIキー（ベアラートークン）を取得します。';

  @override
  String get providerPresetSearxngDescription =>
      'プライバシーに重点を置いて検索ソースを集約する自己ホスト型メタ検索エンジン。';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'SearXNG インスタンスの URL を設定します (例: http://your-instance:8080)。 API キーはオプションです。';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS 合成が失敗しました: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '元のエラー: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      'ネットワーク接続がタイムアウトしました。ネットワークまたは API アドレスを確認してください。';

  @override
  String get ttsErrorServerResponseTimeout =>
      'サーバーの応答がタイムアウトしました。後でもう一度試してください。';

  @override
  String ttsErrorConnectionFailed(String details) {
    return 'サーバーに接続できません ($details)';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return 'サーバーに接続できません。 Web アプリでの一般的な原因: CORS 制限または不正な API アドレス。 $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API がエラーを返しました (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return '接続がタイムアウトしました。ネットワークを確認してください$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return '受信がタイムアウトしました。サーバーの応答が遅い$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API キーが無効であるか、権限が拒否されました (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return 'リクエストが多すぎます。後でもう一度試してください (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API エンドポイントが見つかりません (HTTP $status): $body\nAPI ベース URL が正しいことを確認してください$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return '内部サーバー エラー (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return 'サーバーがエラーを返しました (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return 'リクエストがキャンセルされました$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return 'サーバーに接続できません。 Web アプリでの一般的な原因: CORS 制限または不正な API アドレス。プロバイダー API アドレスが正しいこと、およびサーバーがクロスオリジン リクエストを許可していることを確認してください。$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return 'ネットワークエラー: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => '不明なネットワークエラー';

  @override
  String get ttsErrorNoResponseBody => '応答本文がありません';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return 'ストリーミング合成が失敗しました: $details';
  }

  @override
  String get mermaidEditorTitle => 'マーメイドチャートエディター';

  @override
  String get mermaidEditorModeEdit => '編集';

  @override
  String get mermaidEditorModeSplit => '編集 + プレビュー';

  @override
  String get mermaidEditorModePreview => 'プレビュー';

  @override
  String get mermaidEditorSwitchViewMode => 'ビューモードを切り替える';

  @override
  String get mermaidEditorSaveToTextStorage => 'テキストストレージに保存';

  @override
  String get mermaidEditorEmptyChart => 'グラフの内容が空のため保存できません';

  @override
  String get mermaidEditorSaveChartTitle => 'チャートの保存';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      '.mmd チャート ファイルを保存するフォルダーを選択または作成します';

  @override
  String get mermaidEditorFileNameHint => 'ファイル名を入力してください (.mmd は自動的に追加されます)';

  @override
  String get mermaidEditorEmptyFileName => 'ファイル名を空にすることはできません';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return 'テキストストレージに保存: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor => 'プレビューパネルとエディターパネルを入れ替える';

  @override
  String get mermaidEditorCodeLabel => 'マーメイドコード';

  @override
  String get mermaidEditorCodeHint => 'マーメイドコードを入力してください...';

  @override
  String get mermaidEditorSplitCodeLabel => 'コード';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'SSE 接続に失敗しました (HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'SSE 接続に失敗しました (HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable => 'SSE 接続に失敗しました: サーバーに接続できません';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'HTTP リクエストが失敗しました (HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => 'リクエストが失敗しました';

  @override
  String get sseNetworkRequestFailed => 'ネットワーク要求が失敗しました';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return 'ネットワーク要求が失敗しました (HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return 'ネットワーク要求が失敗しました (HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable => 'ネットワーク要求が失敗しました: サーバーに接続できません';

  @override
  String get sseRequestCancelled => 'リクエストがキャンセルされました';

  @override
  String get startupSafetyTitle => 'データの安全性の保護';

  @override
  String get startupSafetyExportButton => 'データのエクスポート';

  @override
  String get startupSafetyExitButton => 'アプリを終了する';

  @override
  String get startupSafetyUpdateButton => 'アプリを更新する';

  @override
  String get startupSafetyCheckingUpdates => 'アップデートをチェックしています...';

  @override
  String get startupSafetyUpToDate => '最新情報を入手しました';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return 'このデータは、新しいバージョンのアプリ ($version) によって作成されました。\n\nこのアプリのバージョンではデータを安全に読み取ることができません。続行するには最新バージョンをインストールしてください。データは変更されていません。';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      'データの安全性ステータスを確認できませんでした (ステータス マーカーが読み取れなかった、または無効でした)。\n\nフリーズ状態の可能性を上書きするのを避けるため、データの修復やフォーマットの移行を行わずに起動がブロックされています。まずデータ ファイルをエクスポートし、次にアプリを終了し、ステータス マーカーを修復して、もう一度試してください。';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return 'データ形式の移行に失敗しました ($part)。\n\nデータを保護するため、変更は加えられませんでした。以前のアプリのバージョンに戻るか、修正バージョンがリリースされるまで待ってからアップグレードしてください。';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return 'データ形式の移行に失敗しました ($part)。\n\nデータは移行前の状態に復元されました。これを保護するには、以前のアプリのバージョンに戻すか、修正バージョンがリリースされるまで待ってからアップグレードしてください。';
  }

  @override
  String get startupSafetyDataCorrupted =>
      'データが破損しているため、自動的に修復できません。\n\nさらなる被害を防ぐためにアプリは凍結されました。データ ファイルをエクスポートしてから、手動でインポートするか、再インストールします。';

  @override
  String get startupSafetyPreferencesUnavailable =>
      'アプリは起動チェックに必要な環境設定を読み取れなかったため、データを保護するために起動がブロックされました。\n\nストレージ容量または権限を確認して、アプリを再度開きます。';

  @override
  String get startupSafetyValidationUnavailable =>
      'アプリは起動データの安全性チェックを完了できなかったため、データを保護するために起動がブロックされました。\n\nブラウザの設定を確認して、アプリを再度開きます。';

  @override
  String startupSafetyCheckFailed(String detail) {
    return '起動チェックに失敗しました: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      '起動チェック後にデータの安全性ステータスが確認できませんでした（ステータスマーカーが読み取れなかった、または無効でした）。\n\nこれ以上のデータ変更を避けるため、起動が停止されました。データ ファイルをエクスポートし、アプリを終了し、ステータス マーカーを修復して、再試行してください。';

  @override
  String get catCatchConnectionTimeout =>
      '接続がタイムアウトしました。ネットワークまたはサーバーのステータスを確認してください。';

  @override
  String get catCatchSendTimeout => 'リクエストの送信中にタイムアウトになりました。';

  @override
  String get catCatchReceiveTimeout => 'サーバーに時間がかかりすぎるため、応答がタイムアウトしました。';

  @override
  String get catCatchCannotConnect => 'サーバーに接続できませんでした。';

  @override
  String get catCatchConnectionError => 'サーバーに接続できませんでした。 URLが正しいことを確認してください。';

  @override
  String get catCatchBadCertificate => 'サーバー証明書を検証できませんでした。';

  @override
  String catCatchBadResponse(int statusCode) {
    return 'サーバーがエラーを返しました (HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => 'リクエストはキャンセルされました。';

  @override
  String catCatchNetworkError(String message) {
    return 'ネットワークエラー: $message';
  }

  @override
  String get catCatchUnknownError => '不明なエラー';

  @override
  String catCatchOriginalError(String message) {
    return '元のエラー: $message';
  }

  @override
  String get catCatchWebDownloadHint => 'Web ブラウザはメディア ファイルを直接ダウンロードできません。';

  @override
  String get catCatchWebInstallExtension =>
      'CatCatch ブラウザ拡張機能をインストールして、もう一度試してください。';

  @override
  String get catCatchWebAuthorAttribution => '作者: 笨笨猫 (xifangczy)無料でオープンソース。';

  @override
  String get catCatchWebOfficialWarning =>
      'それが作成者のバージョンであることを確認してください。有料版や模倣版は避けてください。';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      'この機能にはサインインしたアカウントが必要です。右上隅にあるブラウザを使用してサインインします。';

  @override
  String get catCatchNoUsableMedia =>
      '使用可能なメディア リソースが見つかりませんでした。 URL をチェックして、Web サイトにアクセスできることを確認してください。';

  @override
  String get catCatchRedownloadFileMissing =>
      'ダウンロードしたファイルが見つからないため、ダウンロードに失敗しました。';

  @override
  String get catCatchRedownloadPathEmpty =>
      'ダウンロードされたファイルのパスが空であるため、ダウンロードに失敗しました。';

  @override
  String get catCatchWebBrowserRequired =>
      'このページはブラウザ環境がないとリソースを公開できません。モバイルまたはデスクトップでこの機能を使用してみるか、ビデオまたはオーディオ ファイルの直接 URL を貼り付けてください。';

  @override
  String get catCatchPlaylistNoSegments => 'プレイリストにはダウンロード可能なセグメントがありません。';

  @override
  String get catCatchDownloadedSourceMissing =>
      'ダウンロードしたソースファイルがありません。再度ダウンロードしてください。';

  @override
  String get appLogPageTitle => 'アプリケーションログ';

  @override
  String get appLogRefresh => 'リフレッシュ';

  @override
  String get appLogCleanupOldLogs => '古いログをクリーンアップする';

  @override
  String get appLogCleanupDone => '古いログがクリーンアップされました';

  @override
  String appLogRetentionNotice(int days) {
    return 'ログの保持: 最新の $days 日のみが保持されます。 $days 日より古いログは自動的に消去されます。';
  }

  @override
  String get appLogWebUnsupported => 'ローカル ログは Web ではサポートされていません';

  @override
  String get appLogNoFiles => 'ログファイルはまだありません';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '自動更新中（$count 回試行）...',
      one: '自動更新中（$count 回目の試行）...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated => 'アプリの実行中にログが生成される';

  @override
  String get appLogExport => '輸出';

  @override
  String get appLogDelete => '消去';

  @override
  String get appLogConfirmDeleteTitle => '削除の確認';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return 'ログファイル「$fileName」を削除しますか?';
  }

  @override
  String get appLogCancel => 'キャンセル';

  @override
  String appLogLoadFilesError(Object error) {
    return 'ログ ファイル リストのロードに失敗しました: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return 'ログ ファイル「$fileName」は存在しますが、読み取れませんでした。破損している可能性があります';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return 'ログ ファイル「$fileName」が見つかりませんでした。浄化されたかもしれない';
  }

  @override
  String appLogReadFileError(Object error) {
    return 'ログ ファイルの読み取りに失敗しました: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return '削除済み: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return '削除に失敗しました: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return 'ログファイル「$fileName」が見つかりませんでした';
  }

  @override
  String appLogPathCopied(String filePath) {
    return 'コピーされたパス: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行',
      one: '$count 行',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => 'すべてコピー';

  @override
  String get appLogStructuredView => '構造化されたビュー';

  @override
  String get appLogRawView => '生のビュー';

  @override
  String appLogCopyError(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get appLogCopyDone => 'すべてのログ内容をコピーしました';

  @override
  String get appLogSettings => 'Log settings';

  @override
  String get appLogSettingsTitle => 'Application log settings';

  @override
  String appLogStorageUsage(int count, String size) {
    return '$count files · $size used';
  }

  @override
  String get appLogRetentionDays => 'Keep logs for';

  @override
  String appLogDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days',
      one: '# day',
    );
    return '$_temp0';
  }

  @override
  String get appLogMinimumLevel => 'Minimum detail level';

  @override
  String get appLogStorageLimit => 'Maximum log storage';

  @override
  String get appLogUnlimited => 'Unlimited';

  @override
  String get appLogSettingsHelp =>
      'Older logs and logs over the storage limit are removed automatically. The current hourly file is kept.';

  @override
  String get appLogSettingsSaved => 'Log settings saved';

  @override
  String appLogSettingsError(Object error) {
    return 'Could not save log settings: $error';
  }

  @override
  String get appLogSave => 'Save';

  @override
  String get appLogLevelDebug => 'Debug · most detail';

  @override
  String get appLogLevelInfo => 'Info';

  @override
  String get appLogLevelWarning => 'Warning';

  @override
  String get appLogLevelError => 'Error';

  @override
  String get appLogFilter => 'Filter log entries';

  @override
  String get appLogSearch => 'Keyword';

  @override
  String get appLogSource => 'Source';

  @override
  String get appLogLevel => 'Level';

  @override
  String get appLogAnyLevel => 'Any level';

  @override
  String get appLogFromTime => 'From';

  @override
  String get appLogUntilTime => 'Until';

  @override
  String get appLogClearFilters => 'Clear filters';

  @override
  String get appLogNoMatches => 'No entries match these filters';

  @override
  String appLogFilteredLineCount(int visible, int total) {
    return '$visible of $total lines';
  }

  @override
  String get iosContinuedTaskTitle => 'バックグラウンドタスク';

  @override
  String get mermaidCatalogTypeFlowchart => 'フローチャート';

  @override
  String get mermaidCatalogDescriptionFlowchart => 'フローチャート — ステップ、分岐、ループを表示する';

  @override
  String get mermaidCatalogTypeSequenceDiagram => 'シーケンス図';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      'シーケンス図 — 参加者間の対話を表示します';

  @override
  String get mermaidCatalogTypeClassDiagram => 'クラス図';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      'クラス図 — クラスの属性とメソッド間の関係を表示します';

  @override
  String get mermaidCatalogTypeStateDiagram => '状態図';

  @override
  String get mermaidCatalogDescriptionStateDiagram => '状態図 — 状態遷移を表示する';

  @override
  String get mermaidCatalogTypeErDiagram => 'ER図';

  @override
  String get mermaidCatalogDescriptionErDiagram => 'ER 図 — エンティティの関係を表示する';

  @override
  String get mermaidCatalogTypeGantt => 'ガントチャート';

  @override
  String get mermaidCatalogDescriptionGantt => 'ガント チャート — プロジェクトのタイムラインを表示する';

  @override
  String get mermaidCatalogTypePie => '円グラフ';

  @override
  String get mermaidCatalogDescriptionPie => '円グラフ — 比例データを表示します';

  @override
  String get mermaidCatalogTypeJourney => 'ユーザージャーニー';

  @override
  String get mermaidCatalogDescriptionJourney =>
      'ユーザー ジャーニー - ユーザー エクスペリエンス フローを表示する';

  @override
  String get mermaidCatalogTypeGitGraph => 'Git グラフ';

  @override
  String get mermaidCatalogDescriptionGitGraph => 'Git グラフ — ブランチとコミットを表示する';

  @override
  String get mermaidCatalogTypeMindmap => 'マインドマップ';

  @override
  String get mermaidCatalogDescriptionMindmap => 'マインドマップ — 階層を表示する';

  @override
  String get mermaidCatalogTypeTimeline => 'タイムライン';

  @override
  String get mermaidCatalogDescriptionTimeline => 'タイムライン — イベントを時系列で表示します';

  @override
  String get mermaidCatalogTypeBlock => 'ブロック図';

  @override
  String get mermaidCatalogDescriptionBlock => 'ブロック図 — ブロックのレイアウトと関係を表示します';

  @override
  String get mermaidCatalogTypeRequirement => '要件図';

  @override
  String get mermaidCatalogDescriptionRequirement => '要件図 — 要件と実装の関係を表示します';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[開始]\n  B[処理]\n  C<MERMAID_OPEN_BRACE>条件<MERMAID_CLOSE_BRACE>\n  D[終了]\n\n  A --> B\n  B --> C\n  C -->|はい| D\n  C -->|いいえ| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"ユーザー\" as user\n  participant \"システム\" as system\n  participant \"データベース\" as database\n\n  user->>system: リクエストを送信\n  system->>database: データを検索\n  database-->>system: 結果を返す\n  system-->>user: 結果を表示';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String 名前\n    +int 年齢\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String 学生ID\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String 教師ID\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"保留中\" as pending\n  state \"処理中\" as processing\n  state \"完了\" as completed\n  state \"失敗\" as failed\n  [*] --> pending\n  pending --> processing\n  processing --> completed\n  processing --> failed\n  failed --> pending\n  completed --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : place\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : contain\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : include\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title プロジェクト工程表\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section 要件定義\n  要件分析       :a1, 2024-01-01, 14d\n  試作設計       :a2, after a1, 10d\n\n  section 開発\n  フロントエンド開発 :b1, after a2, 20d\n  バックエンド開発   :b2, after a2, 20d\n  API 統合          :b3, after b1, 7d\n\n  section テスト\n  機能テスト       :c1, after b3, 10d\n  デプロイ         :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title データの内訳\n  \"カテゴリ A\" : 40\n  \"カテゴリ B\" : 25\n  \"カテゴリ C\" : 20\n  \"カテゴリ D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title ユーザー登録\n  section 登録\n    登録ページを開く: 5: ユーザー\n    情報を入力する: 3: ユーザー\n    リクエストを送信する: 4: ユーザー\n  section 認証\n    コードを受け取る: 3: システム\n    コードを入力する: 4: ユーザー\n    認証に成功する: 5: システム, ユーザー';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"初期コミット\"\n  commit id: \"機能 A を追加\"\n  branch develop\n  checkout develop\n  commit id: \"新機能を開発\"\n  commit id: \"不具合を修正\"\n  checkout main\n  merge develop\n  commit id: \"v1.0 をリリース\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((プロジェクト管理))\n    要件\n      機能要件\n      非機能要件\n    開発\n      フロントエンド\n      バックエンド\n    テスト\n      単体テスト\n      結合テスト\n    デプロイ\n      テスト環境\n      本番環境';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title プロジェクトの主な節目\n  2024-Q1 : 要件調査 : 計画の確認\n  2024-Q2 : 開発 : 機能の実装\n  2024-Q3 : テスト : 不具合修正 : 性能改善\n  2024-Q4 : デプロイ : 運用と保守';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"要件\"] B[\"開発\"] C[\"テスト\"]\n  D[\"デプロイ\"] E[\"運用\"] F[\"監視\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement UserLogin <MERMAID_OPEN_BRACE>\n    id: 1\n    text: アカウントとパスワードでユーザーがサインインできる\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element LoginPage <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element AuthService <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  LoginPage - satisfies -> UserLogin\n  AuthService - verifies -> UserLogin';

  @override
  String get mermaidCatalogDefaultFileName => '私のチャート';

  @override
  String get mermaidCatalogActionAddNode => 'ノードの追加';

  @override
  String get mermaidCatalogActionAddDecision => '決定を追加';

  @override
  String get mermaidCatalogActionAddEdge => 'エッジを追加する';

  @override
  String get mermaidCatalogActionAddSubgraph => 'サブグラフの追加';

  @override
  String get mermaidCatalogActionAddParticipant => '参加者を追加';

  @override
  String get mermaidCatalogActionAddRequest => 'リクエストの追加';

  @override
  String get mermaidCatalogActionAddResponse => '応答を追加';

  @override
  String get mermaidCatalogActionAddNote => 'メモを追加';

  @override
  String get mermaidCatalogActionAddClass => 'クラスの追加';

  @override
  String get mermaidCatalogActionAddInheritance => '継承の追加';

  @override
  String get mermaidCatalogActionAddRelationship => '関係を追加';

  @override
  String get mermaidCatalogActionAddAggregation => '集計の追加';

  @override
  String get mermaidCatalogActionAddState => '状態の追加';

  @override
  String get mermaidCatalogActionAddTransition => 'トランジションを追加する';

  @override
  String get mermaidCatalogActionAddStart => '開始の追加';

  @override
  String get mermaidCatalogActionAddEnd => '終わりを追加';

  @override
  String get mermaidCatalogActionAddEntity => 'エンティティの追加';

  @override
  String get mermaidCatalogActionAddOneToMany => '1対多の追加';

  @override
  String get mermaidCatalogActionAddManyToMany => '多対多の追加';

  @override
  String get mermaidCatalogActionAddOneToOne => '1対1を追加';

  @override
  String get mermaidCatalogActionAddPhase => 'フェーズの追加';

  @override
  String get mermaidCatalogActionAddTask => 'タスクの追加';

  @override
  String get mermaidCatalogActionAddDependentTask => '依存タスクを追加する';

  @override
  String get mermaidCatalogActionAddMilestone => 'マイルストーンを追加';

  @override
  String get mermaidCatalogActionAddCategory => 'カテゴリを追加';

  @override
  String get mermaidCatalogActionAddTitle => 'タイトルを追加';

  @override
  String get mermaidCatalogActionAddSystemTask => 'システムタスクの追加';

  @override
  String get mermaidCatalogActionAddMultiPersonTask => '複数人で行うタスクを追加する';

  @override
  String get mermaidCatalogActionAddCommit => 'コミットの追加';

  @override
  String get mermaidCatalogActionCreateBranch => 'ブランチの作成';

  @override
  String get mermaidCatalogActionSwitchBranch => '分岐を切り替える';

  @override
  String get mermaidCatalogActionMergeBranch => 'ブランチをマージする';

  @override
  String get mermaidCatalogActionAddBranch => 'ブランチの追加';

  @override
  String get mermaidCatalogActionAddChildBranch => '子ブランチを追加する';

  @override
  String get mermaidCatalogActionAddTopic => 'トピックを追加';

  @override
  String get mermaidCatalogActionAddPeriod => '期間を追加';

  @override
  String get mermaidCatalogActionAddBlock => 'ブロックの追加';

  @override
  String get mermaidCatalogActionAddColumns => '列を追加する';

  @override
  String get mermaidCatalogActionAddConnection => '接続の追加';

  @override
  String get mermaidCatalogActionAddChildBlock => '子ブロックを追加する';

  @override
  String get mermaidCatalogActionAddRequirement => '要件の追加';

  @override
  String get mermaidCatalogActionAddElement => '要素の追加';

  @override
  String get mermaidCatalogActionAddVerification => '検証を追加';

  @override
  String get mermaidCatalogGanttDependencyBaseTask => '依存関係ベースタスク';

  @override
  String get mermaidCatalogGanttDependentTaskName => 'フォローアップタスク';

  @override
  String get startupMigrationTitle => 'データ形式のアップグレードが完了しました';

  @override
  String get startupMigrationBody =>
      'データは新しい形式に移行されました。更新されたバージョンを使用するには、アプリを再起動します。';

  @override
  String get startupMigrationExit => 'アプリを終了する';

  @override
  String get startupMigrationRestart => '今すぐ再起動してください';

  @override
  String get startupRecoveryTitle => 'アプリ起動エラー';

  @override
  String get startupRecoveryFallbackMessage =>
      '起動中にデータ形式の問題が発生しましたが、自動的に修復されました。もう一度試してください。';

  @override
  String get startupRecoveryRetry => 'リトライ';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return '$stage$chunk の ASR $category: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return '、チャンク $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return 'リクエストが失敗しました: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return 'チャンク化された転写に失敗しました ($count チャンク、どれも成功しませんでした)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return 'チャンク化された転写は不完全です ($succeeded/$count チャンクは成功しました)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return '成功: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return '失敗: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return '結果が不確実: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return 'チャンク $index ($start ～ $end) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return 'チャンクステータスの保存に失敗しました: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      'リクエストの結果は不確実です。重複送信を避けるため、再試行は停止されました。オーディオを再度選択して、新しいタスクを作成します。';

  @override
  String asrRetryAudioLost(Object audioName) {
    return '元の音声ファイルが失われてしまいました。オーディオを再度選択して再試行します: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return '元の音声ファイルが壊れています。オーディオを再度選択して再試行します: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return '、チャンク $index';
  }

  @override
  String get asrChunkDetailsSeparator => ';';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'ASR 認識に失敗しました: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => '認証';

  @override
  String get asrFailureCategoryRateLimit => 'レート制限';

  @override
  String get asrFailureCategorySizeLimit => 'サイズ制限';

  @override
  String get asrFailureCategoryNetwork => 'ネットワーク';

  @override
  String get asrFailureCategoryResponseParsing => '応答の解析';

  @override
  String get asrFailureCategoryLocalProcessing => 'ローカル処理';

  @override
  String get asrFailureCategoryProvider => 'プロバイダー';

  @override
  String get asrFailureCategoryUnknown => '未知';

  @override
  String get asrFailureStagePreprocessing => '前処理';

  @override
  String get asrFailureStageEncoding => 'エンコーディング';

  @override
  String get asrFailureStageValidation => '検証';

  @override
  String get asrFailureStageRequest => 'リクエスト';

  @override
  String get asrFailureStageUploading => 'アップロードする';

  @override
  String get asrFailureStageWaiting => '待っている';

  @override
  String get asrFailureStageReceiving => '受信';

  @override
  String get asrFailureStageResponse => '応答';

  @override
  String get asrFailureStageParsing => '解析する';

  @override
  String get asrFailureStageStorage => 'ストレージ';

  @override
  String get chatMissingProvider => '最初にチャットプロバイダーを設定してください';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Anthropic API エラー: $detail';
  }

  @override
  String get anthropicStreamUnknownError => '不明なエラー';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'API リクエストが失敗しました (HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing => 'API キーが設定されていません。ファイルのアップロードは利用できません';

  @override
  String get fileUploadApiUrlMissing =>
      'API URL が設定されていません。ファイルのアップロードは利用できません';

  @override
  String get fileUploadContentEmpty => 'ファイルの内容が空です';

  @override
  String get fileUploadFilenameEmpty => 'ファイル名が空です';

  @override
  String get fileUploadMimeTypeEmpty => 'MIME タイプが空です';

  @override
  String get fileUploadPurposeEmpty => 'アップロード目的が空です';

  @override
  String get fileUploadCanceled => 'ファイルのアップロードがキャンセルされました';

  @override
  String get fileUploadCreateMissingId =>
      'アップロードの作成に失敗しました: 応答にアップロード ID がありません';

  @override
  String get fileUploadPartMissingId => 'パーツのアップロードに失敗しました: 応答にパーツ ID がありません';

  @override
  String get fileUploadCompleteMissingFile =>
      'アップロードの完了に失敗しました: 応答にファイル オブジェクトがありません';

  @override
  String get fileUploadMissingFileId => 'ファイルのアップロードに失敗しました: 応答にファイル ID がありません';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return 'ファイルのアップロード要求が失敗しました (HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return 'ファイルのアップロード要求が失敗しました: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'APIキーが設定されていません';

  @override
  String chatStreamError(Object detail) {
    return 'API ストリーム エラー: $detail';
  }

  @override
  String get chatChoicesMissing => 'API 応答には選択肢がありません';

  @override
  String get chatContentBlocksMissing => 'API 応答にはコンテンツ ブロックがありません';

  @override
  String get chatResponseContentEmpty => 'API 応答コンテンツが空です';

  @override
  String chatRequestFailed(Object detail) {
    return 'リクエストが失敗しました: $detail';
  }

  @override
  String get startupTagline => 'あなたの学習アシスタント';

  @override
  String get startupProgressDataSafety => 'データの安全性をチェックしています...';

  @override
  String get startupProgressFormatVersion => 'データ形式のバージョンを確認しています...';

  @override
  String get startupProgressDataFormat => 'データ形式を検証しています...';

  @override
  String get startupProgressDataIntegrity => 'データの整合性をチェックしています...';

  @override
  String get startupProgressResults => 'チェック結果を処理しています...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return '起動完了（注：$warning）';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      'データチェックが完了しました。アプリを起動する準備をしています。';

  @override
  String get startupProgressReady => 'アプリを起動する準備をしています。';

  @override
  String startupWarningErrorCount(Object count) {
    return '$count データの問題が見つかりました:';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return '$count 警告:';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      'プロバイダー エントリの形式が無効です。JSON 配列が必要です。';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return 'プロバイダー エントリ $index が null であるか、無効なタイプです。';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return 'プロバイダー エントリ $index に ID がないか、ID が空です。';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return 'プロバイダー エントリ $index に型がないか、型が空です。';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return 'プロバイダー エントリ $index に名前がないか、名前が空です。';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return 'プロバイダーエントリー $index フィールド $field は有効なリストではありません。';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return 'プロバイダー エントリ $index、$field には、解析エラーを引き起こす可能性のある無効な項目が含まれています。';
  }

  @override
  String get startupIssueConversationsInvalid => '会話の形式が無効です。JSON 配列が必要です。';

  @override
  String startupIssueConversationInvalid(Object index) {
    return '会話 $index が null であるか、無効なタイプです。';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return '会話 $index に ID がありません。';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return '会話 $index にメッセージ フィールドがありません。';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return '会話 $index メッセージ フィールドは有効なリストではありません。';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return 'プロバイダー エントリ $index は不明なプロバイダー タイプ「$type」を使用しているため、正しく動作しない可能性があります。';
  }

  @override
  String get startupErrorTitle => 'アプリの起動に失敗しました';

  @override
  String startupErrorDetails(Object error) {
    return 'エラー: $error';
  }

  @override
  String get renderErrorTitle => 'インターフェースレンダリングエラー';

  @override
  String get renderErrorDebugTitle => 'インターフェースレンダリングエラー（デバッグモード）';

  @override
  String get renderErrorRestartMessage => 'アプリを再起動してみてください。';

  @override
  String get batchDlgFileName => 'ファイル名';

  @override
  String get batchDlgFolderName => 'フォルダ名';

  @override
  String get batchDlgFileNameConflict => 'このフォルダー内の別のファイルは同じ名前です';

  @override
  String get batchDlgFolderNameConflict => '同じ名前のフォルダーがターゲットの場所にすでに存在します';

  @override
  String get batchDlgFolderNameSwapConflict => '同じバッチ内でフォルダー名を交換することはできません';

  @override
  String get batchDlgControlCharacterError => '名前に制御文字を含めることはできません';

  @override
  String get batchDlgNameWhitespaceError =>
      '名前の先頭または末尾を空白にすることはできません。空白のクリーンアップ ルールを使用する';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind を空にすることはできません';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind は空白で終わることはできません';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind は $count 文字を超えることはできません';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind には Windows で無効な文字を含めることはできません';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind はピリオドで終わることはできません';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind は Windows の予約名を使用できません';
  }

  @override
  String get batchDlgIntermediateNameTooLong => '中間名が長すぎます。ルールを調整する';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return 'このアイテムには $date 日付がありません。テンプレートを調整する';
  }

  @override
  String get batchDlgCreatedDate => '創造';

  @override
  String get batchDlgModifiedDate => '修正';

  @override
  String get connectivityTestHttpSuccess => 'HTTPツールリクエストが成功しました';

  @override
  String get connectivityTestHttpFailure => 'HTTPツールリクエストが失敗しました';

  @override
  String get connectivityTestInvalidMcpConfig => '無効な MCP 構成';

  @override
  String get connectivityTestMissingTransport => '有効なトランスポート タイプの構成がありません。';

  @override
  String get connectivityTestStdioUnsupported =>
      'stdio はこのプラットフォームではサポートされていません';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP では、ローカル プロセスを開始する必要があります。 Stroom デスクトップ アプリでテストします。';

  @override
  String get connectivityTestInvalidContent => '無効なテスト内容';

  @override
  String get connectivityTestMethodMustBeString => 'メソッドは文字列である必要があります。';

  @override
  String get connectivityTestUnsupportedMethod => 'サポートされていないテスト方法';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      'リモート ビジネス データの書き込みを避けるため、MCP 接続テストでは読み取り専用ツール/リスト メソッドのみが許可されます。';

  @override
  String get connectivityTestParamsMustBeObject =>
      'params は JSON オブジェクトである必要があります。';

  @override
  String get connectivityTestMcpConnectionFailed => 'MCP サービスに接続できませんでした';

  @override
  String get connectivityTestCheckConnectionSettings =>
      'アドレス、認証、ネットワークを確認するか、アプリ ログで接続の詳細を確認してください。';

  @override
  String get connectivityTestRemainingToolsOmitted => ';残りのツールは省略';

  @override
  String get connectivityTestMcpSuccess => 'MCP 接続テストに成功しました';

  @override
  String connectivityTestToolNames(Object names) {
    return '：$names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return '接続とツール/リストのリクエストは成功しました。 $count ツール$names$suffix が見つかりました。';
  }

  @override
  String get connectivityTestTodoMutationBlocked =>
      'テストパラメータがtodoデータを変更する可能性がある';

  @override
  String get connectivityTestTodoReadOnly =>
      '現在のセッションの Todo リストを保護するには、接続テストで Todo を省略するか、null に設定します。';

  @override
  String get connectivityTestUnknownBuiltin => '不明な組み込みツール';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return 'ツール「$toolName」のテスト実行プログラムが見つかりません。';
  }

  @override
  String get connectivityTestBuiltinSuccess => '組み込みツールのテストに成功しました';

  @override
  String get connectivityTestBuiltinFailure => '組み込みツールのテストに失敗しました';

  @override
  String get connectivityTestTopLevelObjectRequired =>
      'テスト コンテンツはトップレベルの JSON オブジェクトである必要があります。';

  @override
  String get connectivityTestRequestTimeout =>
      'リクエストがタイムアウトしました。サービスの応答とネットワークを確認してください。';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'MCP リクエストがタイムアウトしました: $method';
  }

  @override
  String get connectivityTestResultTruncated => '… (結果は切り捨てられます)';

  @override
  String get toolResultWebSearchEmptyQuery => 'エラー: 検索クエリを空にすることはできません。';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return 'エラー: サポートされていない検索エンジン「$source」。サポートされている値: google、bing、baidu。';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return '推奨エンジン $preferred $reason。 $fallbackに切り替わりました。';
  }

  @override
  String get toolResultWebSearchNotFound => '該当する検索結果は見つかりませんでした。';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return '関連する検索結果が見つかりませんでした ($sources は明示的に結果を返しませんでした)。';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return '検索が不完全です: $sources は明示的に結果を返しませんでした。他のエンジンが利用できなかったか、解析できないページが返されました: $failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return 'エラー: すべての検索エンジンが利用できません。 $failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return '$source からの検索結果:';
  }

  @override
  String get toolResultWebSearchLinkLabel => 'リンク';

  @override
  String get toolResultWebSearchSummaryLabel => 'まとめ';

  @override
  String get toolResultWebSearchEmptyResults => '該当する検索結果は見つかりませんでした。';

  @override
  String get toolResultTodoInvalid =>
      'エラー: todos パラメータは配列である必要があります (省略するか、todo リストを読み取るには null を渡します)。';

  @override
  String get toolResultTodoEmpty => 'まだToDo項目がありません。';

  @override
  String toolResultTodoCount(Object count) {
    return 'アクティブな Todo アイテム: $count';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return 'エラー: MCP サーバー「$server」に再接続できませんでした。';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return 'エラー: MCP サーバー \"$server\" は現在利用できません。';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return 'エラー: MCP サーバー「$server」は接続に失敗したか、ツールを返しませんでした。サーバーの構成を確認してください。';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return 'リアルツール「$tool」は、このサーバー上でコール名「$alias」で公開されています。';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return 'ツール「$tool」は複数の MCP サーバーによって提供されます。一致するコール名 $routes を使用します。';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return 'エラー: 実際のツール「$tool」には名前の競合があります。上記の呼び出し名のいずれかを使用します。';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return 'エラー: MCP サーバー \"$server\" には \"$tool\" という名前のツールがありません。';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return 'このサーバーで利用可能なツール: $tools。代わりにこれらの名前を使用してください。';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return 'エラー: MCP ツール \"$tool\" には現在競合するエイリアスがあります。一致するコール名 $routes を使用します。';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return 'エラー: ツール「$tool」は無効になっています。';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return 'エラー: 不明なツール「$tool」';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => '結果が返されませんでした';

  @override
  String get toolResultWebSearchFallbackUnavailable => '一時的に利用できなくなりました';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '(MCPサーバー$server)';
  }

  @override
  String get toolResultWebSearchUnparsedResults => '解析できないページが返されました';

  @override
  String get toolResultSearchTitleLabel => 'タイトル';

  @override
  String get toolResultSearchContentLabel => 'コンテンツ';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return 'エラー: $provider API キーが構成されていません。設定で設定します。';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return 'エラー: $provider インスタンス URL が構成されていません。設定で設定します。';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return 'エラー: $provider リクエストが失敗しました (HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return 'エラー: $provider リクエストが失敗しました: $detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return 'エラー: 不明な HTTP ツール「$provider」';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return 'エラー: MCP サーバー「$server」が接続されていません。';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return 'エラー: MCP ツール「$tool」からの応答がありません。';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return 'エラー: $detail';
  }

  @override
  String get httpToolBraveDescription =>
      'Brave Search API を使用して Web を検索します。 API キーが必要です。';

  @override
  String get httpToolBochaDescription =>
      'Bocha AI Search API を使用して Web を検索します。 API キーが必要です。';

  @override
  String get httpToolQueritDescription =>
      'Querit Search を使用して Web を検索します。 API キーが必要です。';

  @override
  String get httpToolSearxngDescription =>
      '検索ソースを集約する、プライバシーを重視した自己ホスト型メタ検索エンジン。インスタンス URL が必要です。';

  @override
  String get httpToolSearchQueryDescription => '検索用語。';

  @override
  String get httpToolSearchCountDescription => '返される結果の数。';

  @override
  String get httpToolSearchCountMax20Description => '返される結果の数 (最大 20)。';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return 'インポートされた $decks デッキ、$notes ノート、および $cards カード';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '選択した .apkg ファイルが見つかりませんでした: $path';
  }

  @override
  String get backupRestoreApkgInvalidArchive =>
      '選択した .apkg ファイルが破損しているか、有効なアーカイブではありません。';

  @override
  String get backupRestoreApkgCollectionMissing =>
      '.apkg ファイルには collection.anki2 が含まれていません。';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return 'デッキをインポートまたはエクスポートする前に Anki フラッシュカードを開きます: $path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt => 'Anki コレクション データベースが破損しています。';

  @override
  String backupRestoreApkgLocalFileFailure(String path) {
    return 'ローカルの Anki ファイルにアクセスできませんでした: $path';
  }

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return 'このパスへのアクセス中に .apkg 操作が失敗しました: $path';
  }

  @override
  String get backupRestoreApkgOperationFailed =>
      'ファイルまたはデータベースを読み取れなかったため、.apkg 操作は失敗しました。';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return 'Anki デッキをこのデータベースからパッケージ化できませんでした: $path';
  }

  @override
  String get ankiSyncStatusProtocolFailed =>
      '同期サーバーの応答が無効または不完全です。サーバーが Anki sync v10 をサポートしていることを確認します。';

  @override
  String get ankiSyncStatusLoginRequired => '続行する前に、Anki 同期にログインしてください。';

  @override
  String get ankiSyncStatusInvalidServerUrl =>
      '有効な HTTP または HTTPS 同期サーバーのアドレスを入力します。';

  @override
  String get ankiSyncStatusHttpsRequired =>
      'リモートのセルフホスト型同期サーバーは HTTPS を使用する必要があります。';

  @override
  String get ankiSyncStatusConnectionTimeout =>
      '同期リクエストがタイムアウトしました。サーバーアドレスとネットワークを確認して再実行してください。';

  @override
  String get ankiSyncStatusTlsFailure =>
      'サーバー証明書を検証できませんでした。証明書を確認するか、カスタム CA を構成します。';

  @override
  String get ankiSyncStatusConnectionFailure =>
      '同期サーバーに接続できませんでした。アドレスとネットワークを確認してください。';

  @override
  String get ankiSyncStatusRequestFailure =>
      '同期リクエストは失敗しました。サーバーとネットワークを確認して、再試行してください。';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return '同期サーバーは HTTP $statusCode を返しました。';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return '同期応答が $limitMb MB 制限を超えました。';
  }

  @override
  String get ankiSyncStatusLocalFileFailure =>
      'ローカル同期ファイルを読み取ることも、クリーンアップすることもできませんでした。ディスクアクセスを確認して再試行してください。';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      'コレクションを開いたり、更新したり、SQLite/スキーマ検証に合格したりできませんでした。有効なコレクションを復元するか、再度ダウンロードします。';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return '同期サーバーは要求を拒否しました (HTTP $statusCode)。ログイン認証情報とサーバー権限を確認してください。';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return '同期エンドポイントが見つかりませんでした (HTTP $statusCode)。サーバーアドレスを確認してください。';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      'メディア同期サーバーが無効な応答を返しました。 Anki メディア同期がサポートされていることを確認して、もう一度試してください。';

  @override
  String get ankiSyncStatusMediaIndexCorrupt =>
      'ローカル メディア同期インデックスが破損しています。メディア同期データをリセットして、再試行してください。';

  @override
  String get ankiSyncStatusMediaIndexFailure =>
      'ローカル メディア同期インデックスを読み取ることも更新することもできませんでした。';

  @override
  String get ankiSyncStatusMediaChecksumMismatch =>
      'ダウンロードしたメディア ファイルのチェックサム検証に失敗しました。メディアの同期を再試行します。';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return 'メディア ファイル「$filename」には、ローカルとサーバーの変更内容が競合しています。再試行する前に、バックアップして名前の競合を解決してください。';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return 'メディアファイル名「$filename」は同期できません。有効な Anki ファイル名に名前を変更して、再試行してください。';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return 'メディア ファイルが空であるか、$limitMb MB 制限を超えています。';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return 'メディア アーカイブには $count エントリが含まれています。最大値はマニフェストを含めて $limit です。';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed =>
      'メディア同期の検証に失敗しました。同期を再試行します。';

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      'Web 上で同期するには、AnkiWeb にサインインします。クラウドアイコンで Anki 設定を開いてログインします。';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      'Web 上でデッキを参照または管理するには、クラウド アイコンを使用して AnkiWeb にサインインします。';

  @override
  String get ankiStatsUnsupportedPlatform => 'Anki 統計はこのプラットフォームでは利用できません。';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      'デバイスの時計は同期サーバーと 5 分以上異なります。時計を修正して再試行してください。';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      '同期健全性チェックが失敗し、ローカルの変更がロールバックされました。サーバー コレクションを完全にダウンロードして、再試行してください。';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      'このコレクションは増分的に同期できません。続行するには、完全なアップロードまたはダウンロードを選択してください。';

  @override
  String get ankiSyncStatusIncrementalSyncFailed =>
      '増分同期を完了できませんでした。サーバーと接続を確認して、再試行してください。';

  @override
  String get emojiCategorySmileys => 'スマイリー';

  @override
  String get emojiCategoryPeople => '人々';

  @override
  String get emojiCategoryAnimals => '動物';

  @override
  String get emojiCategoryFood => '食べ物';

  @override
  String get emojiCategoryActivities => '活動内容';

  @override
  String get emojiCategoryTravel => '旅行';

  @override
  String get emojiCategoryObjects => 'オブジェクト';

  @override
  String get emojiCategorySymbols => '記号';

  @override
  String get emojiCategoryFlags => 'フラグ';

  @override
  String get languageNameSpanish => 'スペイン語';

  @override
  String get languageNameJapanese => '日本語';

  @override
  String get languageNameFrench => 'フランス語';

  @override
  String get languageNameGerman => 'ドイツ語';

  @override
  String get languageNameArabic => 'アラビア語';

  @override
  String fileManagerDeleteEmptyFolderWithSubfoldersConfirm(
    num count,
    Object name,
  ) {
    return '空のフォルダー「$name」を削除しますか? 配下の $count 個のサブフォルダーも削除されます。';
  }

  @override
  String get providerMaxUploadSizePositive => '最大アップロードサイズは正の数である必要があります。';

  @override
  String get ocrSamplingTemperatureOutOfRange =>
      '保存された温度が 0～2 の範囲外です。保存する前にスライダーを調整するか、この設定をオフにしてください。';

  @override
  String get ocrSamplingTopPOutOfRange =>
      '保存された top-P が 0～1 の範囲外です。保存する前にスライダーを調整するか、この設定をオフにしてください。';

  @override
  String get ocrSamplingSliderRepairRequired =>
      '範囲外のサンプリングスライダーを調整するか、保存する前に設定をオフにしてください。';
}

/// The translations for Japanese, as used in Japan (`ja_JP`).
class AppLocalizationsJaJp extends AppLocalizationsJa {
  AppLocalizationsJaJp() : super('ja_JP');

  @override
  String get galleryPermissionTitle => '写真ライブラリへのアクセスが必要です';

  @override
  String get galleryPermissionMessage =>
      'システム設定で Stroom が写真やビデオにアクセスできるようにします。';

  @override
  String get galleryPermissionCancel => 'キャンセル';

  @override
  String get galleryPermissionOpenSettings => '設定を開く';

  @override
  String get languageSettingsTitle => '言語';

  @override
  String get followSystemLanguage => 'システムの言語に従う';

  @override
  String get themeDisplaySettingsTitle => 'テーマとディスプレイ';

  @override
  String get themeDisplayThemeSection => 'テーマ';

  @override
  String get themeModeLight => 'ライトモード';

  @override
  String get themeModeDark => 'ダークモード';

  @override
  String get themeModeSystem => 'システム設定に従う';

  @override
  String get languageNameEnglish => '英語';

  @override
  String get languageNameChinese => '中国語（簡体字）';

  @override
  String get languageNameKorean => '韓国語';

  @override
  String get languageNamePortuguese => 'ポルトガル語（ブラジル）';

  @override
  String get languageSearchHint => '検索言語';

  @override
  String get languageNoMatches => '一致する言語がありません';

  @override
  String get builtInPromptGeneralName => '一般アシスタント';

  @override
  String get builtInPromptGeneralDescription => '日常会話や幅広い質問に答えてくれる万能AIアシスタント。';

  @override
  String get builtInPromptGeneralPrompt =>
      'あなたは役に立つ AI アシスタントです。ユーザーが使用する言語でユーザーに応答します。簡潔、明確、論理的に整理してください。何か不明な点がある場合は、正直に言ってください。';

  @override
  String get builtInPromptCodeExpertName => 'コードエキスパート';

  @override
  String get builtInPromptCodeExpertDescription =>
      '多くのプログラミング言語とテクノロジースタックに関する専門知識を持つ経験豊富なプログラマー。';

  @override
  String get builtInPromptCodeExpertPrompt =>
      'あなたは、多くのプログラミング言語とテクノロジー スタックに精通した経験豊富なソフトウェア エンジニアです。ユーザーの質問に基づいて、高品質のコード例、技術的な説明、ベスト プラクティスの推奨事項を提供します。読みやすさ、パフォーマンス、セキュリティを優先します。コードを提供するときは、言語にラベルを付け、適切な形式を使用してください。システム設計に関する質問については、アーキテクチャの観点からトレードオフを分析します。';

  @override
  String get builtInPromptTranslationName => '翻訳アシスタント';

  @override
  String get builtInPromptTranslationDescription =>
      'プロの翻訳者が多言語翻訳とローカリゼーションに関するアドバイスを提供します。';

  @override
  String get builtInPromptTranslationPrompt =>
      'あなたはプロの翻訳者です。あなたの責任は次のとおりです。\n1. ユーザーが提供したコンテンツを、そのスタイルとトーンを維持しながら正確に翻訳します。\n2. ユーザーが特定の言語で何かを言う方法を尋ねた場合は、自然な表現を返します。\n3. 文化的に特殊なコンテンツのローカライゼーションに関するアドバイスを提供します。\n4. 複数の翻訳が可能な場合は、それらを列挙し、その違いを説明します。\n常に最初にソース言語とターゲット言語を特定します。どちらかが不明な場合はユーザーに尋ねます。';

  @override
  String get builtInPromptEnglishTeacherName => '英語教師';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      'リスニング、スピーキング、リーディング、ライティングの向上をサポートする英語学習家庭教師。';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      'あなたは経験豊富な英語教師です。ユーザーのニーズを満たすには:\n1. 文法の説明: ルールを例を含めて明確に説明します。\n2. 語彙学習: 単語の使用法、連語、区別を説明します。\n3. 文章を磨きます: 自然に聞こえるように英語を上達させます。\n4. 会話練習: 英語を話す状況をシミュレートします。\n5. 発音ガイダンス: 発音記号とおおよその発音を使用します。\nユーザーの英語レベルに合わせて難易度を調整し、日本語で補足してください。';

  @override
  String get builtInPromptInterviewerName => 'インタビュアー';

  @override
  String get builtInPromptInterviewerDescription => '技術面接および行動面接のための模擬面接官。';

  @override
  String get builtInPromptInterviewerPrompt =>
      'あなたはプロのインタビュアーです。ユーザーの対象となる役割に対して練習用の面接を実行します。\n1. まずは目指す職種と業界を知る。\n2. 関連する技術的、動作的、およびシステム設計に関する質問をします。\n3. ユーザーの回答を評価し、改善を提案します。\n4. 回答例と推論を提供します。\n5. 現実的なペースを保ちます。1 つか 2 つの質問をして、ユーザーを待ちます。\nユーザーの面接スキルの向上を支援することを目標に、プロフェッショナルかつフレンドリーに接してください。';

  @override
  String get builtInPromptWritingName => 'ライティングアシスタント';

  @override
  String get builtInPromptWritingDescription =>
      'さまざまなジャンルのクリエイティブなライティングの執筆および編集アシスタント。';

  @override
  String get builtInPromptWritingPrompt =>
      'あなたはプロのライティングコンサルタントです。ユーザーのニーズに基づいて、以下を提供します。\n1. ドラフト: 議論、説明、物語などのジャンルで執筆します。\n2. 編集: 文法、単語の選択、論理、構造、表現を改善します。\n3. 概要: フレームワークを構築し、重要なポイントを特定するのに役立ちます。\n4. 創造的なアイデア: インスピレーションと可能な角度を提供します。\n5. フォーマット: 対象ジャンルと提出要件の規則に従います。\nまず目的、対象読者、求められるスタイルを理解し、焦点を絞ったアドバイスを行います。';

  @override
  String get builtInPromptCreativeThinkerName => 'クリエイティブシンカー';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      '新鮮なアイデアを生み出す創造的なアイデアとブレインストーミングのパートナー。';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      'あなたは創造的思考のパートナーです。あなたのタスクは次のとおりです。\n1. ブレーンストーミング: トピックに関してさまざまな創造的な方向性を提案します。\n2. コンセプトの開発: 既存のアイデアを深め、拡張します。\n3. 分野を接続する: さまざまな分野の概念を新しい方法で組み合わせます。\n4. 逆に考える: 従来の考え方に挑戦し、珍しい視点を提供します。\n5. 実現可能性のレビュー: 導入の課題と潜在的な価値を分析します。\n適切なタイミングで議論に焦点を当てながら、発散的な思考を奨励します。 1 つの応答につき 3 ～ 5 つの指示を提供します。';

  @override
  String get builtInPromptDataAnalystName => 'データアナリスト';

  @override
  String get builtInPromptDataAnalystDescription =>
      'データの理解、モデル化、視覚化を支援するデータ分析の専門家。';

  @override
  String get builtInPromptDataAnalystPrompt =>
      'あなたはデータ分析の専門家です。ユーザーの質問に基づいて、次の情報を提供します。\n1. 分析方法: 適切な統計手法と分析フレームワークを選択します。\n2. SQL/Python/R コード: データ処理と分析の例を示します。\n3. 視覚化に関するアドバイス: 適切なチャートの種類とツールを推奨します。\n4. 解釈: 調査結果とそのビジネス上の意味を説明します。\n5. データ クリーニング: 欠損値、外れ値、その他の品質問題を処理します。\nまずは分析の目的とデータの特徴を明確にします。 Python エコシステム (pandas、numpy、matplotlib、seaborn) を好みます。';

  @override
  String get builtInPromptRoleplayName => 'ロールプレイ';

  @override
  String get builtInPromptRoleplayDescription => '没入型の複数キャラクターのロールプレイング体験。';

  @override
  String get builtInPromptRoleplayPrompt =>
      'ロールプレイモードを開始しました。ユーザーが指定したキャラクターを演じ、その性格、口調、知識に沿って対話してください。\n1. ユーザーが「[キャラクター]を演じて」と言ったら、すぐにそのキャラクターに切り替えてください。\n2. 会話中はそのキャラクターを演じ続けてください。\n3. キャラクターの説明に合わせて、話し方や知識を調整してください。\n4. ユーザーは「ロールプレイを終了」と言って終了できます。\n5. キャラクターに合った自然な架空の情報を加えてもかまいません。\nユーザーが演じるキャラクターを指定するまで待ってください。';

  @override
  String get builtInPromptLifeAdvisorName => 'ライフアドバイザー';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      '温かく思慮深い聞き手で、メンタルヘルスのサポートや日常のアドバイスを提供します。';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      'あなたは温かく思慮深いライフアドバイザーです。あなたの責任は次のとおりです。\n1. 積極的に耳を傾け、ユーザーの懸念や感情的なニーズを理解します。\n2. 問題を合理的に分析し、ユーザーが問題の側面を整理できるようにします。\n3. 日常生活を改善するための具体的で実行可能な方法を提供します。\n4. 理解、励まし、積極的なサポートを提供します。\n5. 必要な場合は、専門家の助けを提案してください。\n覚えておいてください：あなたは認可されたメンタルヘルスカウンセラーではありません。深刻なメンタルヘルス危機の場合は、ユーザーに専門家の助けを求めるよう勧めてください。行き過ぎずに共感を持ちましょう。ユーザーに代わって決定を下すことなく、ユーザーをサポートします。';

  @override
  String get builtInSystemTitleName => 'タイトルアシスタント';

  @override
  String get builtInSystemTitleDescription => '会話から短いタイトルを自動的に生成します。';

  @override
  String get builtInSystemTitlePrompt =>
      'あなたはタイトルジェネレーターです。会話のタイトルを 1 つ出力し、それ以外は何も出力しません。\n\nルール:\n- 1 行、50 文字以内で入力してください。\n- 説明したり、引用符を使用したりしないでください。\n- ユーザーのメッセージと同じ言語を使用します。\n- タイトルに web_search や todowrite などのツール名を含めないでください。\n\n例:\n「プロダクション 500 エラーのデバッグを手伝ってください」 → プロダクション 500 エラーのデバッグ\n「ユーザーサービスのリファクタリング」 → ユーザーサービスのリファクタリング\n「なぜ app.js が失敗するのでしょうか?」 → app.js のトラブルシューティング\n\nユーザーのメッセージが非常に短い場合、または単なる挨拶 (「こんにちは」、「はは」、「いますか?」など) の場合は、挨拶、カジュアルなおしゃべり、簡単な確認など、その口調や意図を反映したタイトルを作成します。';

  @override
  String get builtInSystemCompactionName => 'コンテキスト圧縮アシスタント';

  @override
  String get builtInSystemCompactionDescription =>
      '長い会話を構造化されたアンカー付きの要約に凝縮し、自由なコンテキスト スペースを確保します。';

  @override
  String get builtInSystemCompactionPrompt =>
      'あなたはアンカーされたコンテキストの要約アシスタントです。長い会話を構造化された要約に凝縮します。\n\n提供された会話履歴のみを要約します。最近のメッセージはそのまま保存される場合があるため、依然として重要な古いコンテキストに注目してください。\n\nプロンプトに <previous-summary> ブロックが含まれている場合は、それを現在のアンカーされた概要として扱います。つまり、依然として真実である内容を保持し、古い内容を削除し、新しい事実を統合します。\n\nこの構造に正確に従ってください。セクションの順序を維持し、空であってもすべてのセクションを含めます。\n<テンプレート>\n## 目的\n- [ユーザーの目標を 1 ～ 2 文で説明]\n\n## 重要な詳細\n- [制約/好み、決定と理由、重要な事実/仮定、続行に必要な正確な背景。空の場合は(なし)を書き込みます]\n\n## 作業状態\n### 完了\n- [完了した作業、確認された事実、または行われた変更。空の場合は(なし)を書き込みます]\n\n### アクティブ\n- [現在の作業、一部変更、または調査;空の場合は(なし)を書き込みます]\n\n### ブロックされました\n- [ブロッカー、失敗したコマンド、または未知のもの。空の場合は(なし)を書き込みます]\n\n## 次の動き\n1. [次の特定のアクション、または (なし)]\n2. [既知のフォローアップアクション、または (なし)]\n\n## 関連ファイル\n- [ファイルまたはディレクトリのパスとそれが重要な理由;空の場合は(なし)を書き込みます]\n</テンプレート>\n\nルール:\n- 空の場合でも、すべてのセクションを含めます。\n- 段落ではなく、簡潔な箇条書きを使用します。\n- 正確なファイル パス、シンボル、コマンド、エラー メッセージ、URL、識別子を保存します。\n- コンテキストを要約、圧縮、または結合していることには触れないでください。\n- 会話と同じ言語を使用します。';

  @override
  String get builtInPromptMarketTitle => 'アシスタントマーケット';

  @override
  String get builtInPromptClose => '閉じる';

  @override
  String get builtInPromptImportHint =>
      'インポートされたプロンプトは、自由に編集できる通常のアシスタントになります。';

  @override
  String get builtInPromptView => 'プロンプトを表示';

  @override
  String get builtInPromptAdd => '追加';

  @override
  String get builtInPromptDescriptionHeading => '説明';

  @override
  String get builtInPromptSystemPromptHeading => 'システムプロンプト';

  @override
  String get builtInPromptAddAssistant => 'アシスタントの追加';

  @override
  String builtInPromptViewerTitle(Object name) {
    return 'プロンプト · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      '別のモデルを構成し、タイトルの自動生成とコンテキストの圧縮を求めるプロンプトを表示します。デフォルトでは、現在のチャット モデルと組み込みプロンプトが使用されます。';

  @override
  String get systemAssistantTitleName => 'タイトル生成アシスタント';

  @override
  String get systemAssistantTitleDescription => '会話タイトルを自動生成';

  @override
  String get systemAssistantCompactionName => 'コンテキスト圧縮アシスタント';

  @override
  String get systemAssistantCompactionDescription => '長い会話をアンカー付きの要約に凝縮する';

  @override
  String get systemAssistantFollowCurrentModel => '現在のチャット モデルに従ってください';

  @override
  String get systemAssistantChooseModel => 'モデルを選択してください';

  @override
  String get systemAssistantResetPromptTitle => 'デフォルトのプロンプトにリセット';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '「$taskTitle」の組み込みのデフォルト プロンプトを復元しますか?現在のカスタム プロンプトは破棄されます。';
  }

  @override
  String get systemAssistantCancel => 'キャンセル';

  @override
  String get systemAssistantReset => 'リセット';

  @override
  String get systemAssistantModelHeading => 'モデル';

  @override
  String get systemAssistantPromptHeading => 'プロンプト';

  @override
  String get systemAssistantCustomPromptHint => '変更はカスタム プロンプトとして使用されます';

  @override
  String get systemAssistantUsingCustomPrompt => 'カスタムプロンプトの使用';

  @override
  String get systemAssistantUsingDefaultPrompt => 'デフォルトのプロンプトを使用する';

  @override
  String get systemAssistantSave => '保存';

  @override
  String get systemAssistantResetButton => 'デフォルトのプロンプトにリセット';

  @override
  String get taskFlowPageTitle => 'タスクフロー';

  @override
  String get taskFlowSampleTemplatesTooltip => 'テンプレートの例';

  @override
  String get taskFlowEmptyState => 'まだフローはありません。 + をタップして作成します。';

  @override
  String get taskFlowStartFromTemplate => 'テンプレートから始める';

  @override
  String get taskFlowChooseTemplate => 'サンプルテンプレートを選択してください';

  @override
  String get taskFlowTemplateIntroduction => '必要なものに近いフローを選択してください。後で調整できます。';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のテンプレート',
      one: '$count 件のテンプレート',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      'テンプレートは設定が必要なドラフトとして開きます。保存する前にモデルとアシスタントを選択してください。';

  @override
  String get taskFlowTemplateRecordingName => '録音を文字に起こして要約する';

  @override
  String get taskFlowTemplateRecordingDescription => '録音を選択→音声認識→アシスタントの概要';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'ASR モデルを構成し、要約のアシスタントを選択します。';

  @override
  String get taskFlowTemplateImageTextName => '画像テキストの認識と整理';

  @override
  String get taskFlowTemplateImageTextDescription => '画像を選択→テキスト認識→アシスタント組織';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'OCR モデルを設定し、テキストを整理するアシスタントを選択します。';

  @override
  String get taskFlowTemplateReadImageName => '画像からテキストを読み取る';

  @override
  String get taskFlowTemplateReadImageDescription => '画像を選択 → テキスト認識 → 音声再生';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'OCR および音声合成モデルを設定し、音声を選択します。';

  @override
  String get taskFlowActions => 'フローアクション';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のブロック',
      one: '$count 個のブロック',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'OCR';

  @override
  String get taskFlowBlockAsr => '音声認識';

  @override
  String get taskFlowBlockAudioSeparation => '音声の分離';

  @override
  String get taskFlowBlockCatCatch => 'Webリソースのダウンロード';

  @override
  String get taskFlowBlockTts => '音声合成';

  @override
  String get taskFlowBlockChat => 'アシスタントチャット';

  @override
  String get taskFlowBlockCustom => 'カスタムブロック';

  @override
  String get taskFlowEdit => '編集';

  @override
  String get taskFlowCopy => 'コピー';

  @override
  String get taskFlowCopied => 'コピーされました';

  @override
  String get taskFlowDelete => '消去';

  @override
  String get taskFlowConfirmDelete => '削除の確認';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return 'タスクフロー「$flowName」を削除しますか?';
  }

  @override
  String get taskFlowUseTemplate => '使用';

  @override
  String get taskFlowOcrInputMissing => '画像ファイルが見つかりませんでした。再度画像を選択してください。';

  @override
  String get taskFlowOcrInputReadFailed =>
      '画像ファイルを読み取れませんでした。ファイルアクセスを確認して、再試行してください。';

  @override
  String get taskFlowOcrModelUnavailable =>
      '使用可能な OCR モデルが設定されていません。フロー設定で OCR プロバイダーとモデルを選択します。';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'OCR リクエスト サイズの予算 ($size MiB)';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return 'タスク フロー イメージの入力制限 ($size MiB)';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return '画像は$limitを超えています。より小さい画像を選択して、もう一度試してください。';
  }

  @override
  String get ocrTemplatePlainTextLabel => 'プレーンテキスト';

  @override
  String get ocrTemplatePlainTextContent =>
      '表示されているすべてのテキストをページの自然な読み順で、改行と段落を維持して転記します。プレーンテキストのみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrTemplateMarkdownLabel => 'マークダウン';

  @override
  String get ocrTemplateMarkdownContent =>
      '表示されているすべてのテキストをページの自然な読み順で転記し、Markdown を使用して見出し、リスト、表を保持します。 LaTeX で数式を表現します。転写のみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrTemplateTableLabel => 'テーブル';

  @override
  String get ocrTemplateTableContent =>
      '表示されているすべてのテキストをページの自然な読み順で書き写します。テーブルの場合、ヘッダー、行と列の関係、空のセルを保持し、Markdown テーブルとして出力します。他のコンテンツは通常のテキストとして保持します。転写のみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrTemplateLatexLabel => 'ラテックス';

  @override
  String get ocrTemplateLatexContent =>
      '表示されているすべてのテキストをページの自然な読み順で書き写します。数式以外のテキストを保持し、LaTeX で数式を表現します。インライン式には \$...\$ を使用し、表示式には \$\$...\$\$ を使用します。転写のみを返します。説明や推論を追加しないでください。';

  @override
  String get ocrDefaultImagesOnly => 'デフォルト（画像のみ送信）';

  @override
  String get ocrDefaultSystemPrompt =>
      '元の書式とレイアウトを維持したまま、画像からすべてのテキストを抽出します。抽出されたテキストのみを返します。何も説明を加えないでください。';

  @override
  String get ocrSavedInstructionSnapshot => '保存された命令のスナップショット';

  @override
  String get ocrPageTitle => '画像テキスト認識';

  @override
  String get ocrImageQualitySettings => '画質設定';

  @override
  String get ocrImageQualityStandard => '標準品質';

  @override
  String get ocrImageQualityStandardHint => 'ほとんどのユースケースでは小さい画像';

  @override
  String get ocrImageQualityOriginal => 'オリジナル/ハイディテール';

  @override
  String get ocrImageQualityOriginalHint => 'より詳細な情報を保持します。画像とリクエストが大きくなります';

  @override
  String get ocrReorderDone => '終わり';

  @override
  String get ocrReorderAction => '再注文';

  @override
  String get ocrClearAction => 'クリア';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return '前のタスクではモデル $modelId を使用しました。プロバイダーとモデルを再度選択してください。';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      '前回の再試行レコード内のモデル位置が無効です。再度モデルを選択してください。';

  @override
  String get ocrLegacyModelPositionConfirm =>
      '前回の再試行記録では、モデルの位置のみが保存されました。続行する前に現在のモデルを確認してください。';

  @override
  String get ocrModelUnavailable =>
      '元の OCR プロバイダーまたはモデルは利用できなくなりました。別のものを選択してください。';

  @override
  String get ocrModelLabel => 'モデル';

  @override
  String get ocrConfigure => '設定する';

  @override
  String get ocrSelectModel => 'モデルを選択してください';

  @override
  String get ocrInstructionLabel => '命令';

  @override
  String get ocrManageInstructions => '認識指示の管理';

  @override
  String get ocrInstructionManageGuidance =>
      'これらの手順はすべての認識モデルに適用されます。何も選択されていない場合は、画像のみが送信されます。';

  @override
  String get ocrInstructionManageEmpty => 'まだ指示がありません';

  @override
  String get ocrInstructionEditTooltip => '編集命令';

  @override
  String get ocrInstructionDeleteTooltip => '削除命令';

  @override
  String get ocrInstructionAdd => '命令の追加';

  @override
  String get ocrInstructionEditorEditTitle => '編集命令';

  @override
  String get ocrInstructionNameLabel => '命令名(オプション)';

  @override
  String get ocrInstructionContentLabel => '指導内容';

  @override
  String get ocrBatchMode => 'バッチモード';

  @override
  String get ocrMergeRecognition => '結果を結合する';

  @override
  String get ocrRecognizeEachImage => '各画像を個別に認識する';

  @override
  String get ocrMaxConcurrency => '最大 2 つの同時リクエスト';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の同時リクエスト',
      one: '$count 件の同時リクエスト',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の同時リクエスト',
      one: '$count 件の同時リクエスト',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint => '完了したページは保持されます。再試行は未完了のページのみを送信します。';

  @override
  String get ocrTakePhoto => '写真を撮ってください';

  @override
  String get ocrChooseFromAlbum => 'アルバムから選ぶ';

  @override
  String get ocrNoImagesSelected => '画像が選択されていません';

  @override
  String get ocrSelectImagesHint => '写真を撮るか、アルバムから複数の画像を選択して認識します。';

  @override
  String ocrRechooseRequiredImages(num count) {
    return '再試行する前に、必要な画像をすべて選択し直してください（$count 枚）。';
  }

  @override
  String ocrImageLabel(Object index) {
    return '画像 $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return '画像_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => '無効な画像インデックス';

  @override
  String get ocrViewErrorDetails => 'エラーの詳細を表示する';

  @override
  String get ocrConfirmModel => 'このモデルを確認する';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枚の画像を選択中',
      one: '$count 枚の画像を選択中',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => '画像を準備中…';

  @override
  String get ocrSavingRetryImages => 'リトライ画像を保存中…';

  @override
  String get ocrRecognizing => '認識中…';

  @override
  String get ocrReadingRetryImages => 'リトライイメージを読み込んでいます…';

  @override
  String get ocrImportingImages => '画像をインポート中…';

  @override
  String get ocrStartRecognition => '認識を開始する';

  @override
  String get ocrSaveTo => '保存先';

  @override
  String get ocrRootDirectory => 'ルートディレクトリ';

  @override
  String get ocrChooseSaveFolder => '保存先のフォルダーを選択してください';

  @override
  String get ocrChooseImageSource => '画像ソースを選択してください';

  @override
  String get ocrChooseAppAlbum => 'アプリアルバムから選択';

  @override
  String get ocrAppAlbumDescription => 'アプリにすでに保存されている画像を選択してください';

  @override
  String get ocrChooseSystemAlbum => 'システムアルバムから選ぶ';

  @override
  String get ocrSystemAlbumDescription => 'このデバイス上の画像を参照して選択します';

  @override
  String ocrTakePhotoFailed(Object error) {
    return '写真の撮影に失敗しました: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枚の画像を読み込みました',
      one: '$count 枚の画像を読み込みました',
    );
    return '$_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return '画像の処理に失敗しました: $error';
  }

  @override
  String get ocrUnknownSourceImageCount => '元の画像数を特定できません';

  @override
  String get ocrConfirmClear => 'クリアを確認する';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      '元の OCR 画像キャッシュが利用できないため、その画像数を回復できません。クリアすると、古い再試行状態がリセットされます。この OCR タスク用にすべての画像を再度選択します。';

  @override
  String get ocrConfirmClearSelected => '選択した OCR 画像をクリアしますか?';

  @override
  String get ocrCancel => 'キャンセル';

  @override
  String get ocrConfirmResetAndReselect => 'リセットして再度画像を選択してください';

  @override
  String get ocrRequestCheckFailed => 'OCR リクエストを確認できません。モデルパラメータを確認してください。';

  @override
  String get ocrCancelledAdjustAndRetry =>
      '認識がキャンセルされました。プロバイダー/モデルのリクエスト サイズまたは画質を調整して、再試行してください。';

  @override
  String get ocrRequestSizeExceededTitle => 'OCR リクエストが設定されたサイズを超えています';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return 'リクエストは約 $requestSize MiB で、構成された $limit MiB 制限を超えています。';
  }

  @override
  String get ocrRequestSizeHelp =>
      'プロバイダーのデフォルトまたはモデルのオーバーライドでリクエスト サイズを調整するか、別の画質を選択します。画質を変更した後、画像をクリアして再度インポートしてください。';

  @override
  String get ocrUsePerImageMode => '画像ごとの認識を使用する';

  @override
  String get ocrGotIt => 'わかった';

  @override
  String get ocrWaitForImport => '画像のインポートが完了するまで待ってから認識を開始してください。';

  @override
  String get ocrWaitForRetryImages => 'リトライイメージの読み込み。お待ちください。';

  @override
  String get ocrConfigureProviderModel => '最初に [設定] で OCR プロバイダーとモデルを構成します。';

  @override
  String get ocrReselectProviderModel => 'OCR プロバイダーとモデルを再度選択します。';

  @override
  String get ocrConfirmLegacyModel => 'まず、前回のリトライ記録から OCR モデルを確認します。';

  @override
  String get ocrRetryImagesUnavailable =>
      'オリジナルの OCR 画像キャッシュは利用できません。タスクをクリアして、すべての画像を再度選択します。';

  @override
  String get ocrRetryImageCountUnknown =>
      '元の OCR 画像キャッシュは利用できず、その画像数は不明です。リセットして、この OCR タスクのすべての画像を再度選択します。';

  @override
  String get ocrRetryImageReset =>
      '前回の再試行入力がリセットされました。この OCR タスク用にすべての画像を再度選択します。';

  @override
  String get ocrRetryImagesUnreadable =>
      '元の OCR 画像キャッシュを読み取れませんでした。タスクをクリアして、すべての画像を再度選択します。';

  @override
  String get ocrRetryImagesMissing =>
      '元の OCR 画像キャッシュが見つからないか破損しています。タスクをクリアして、すべての画像を再度選択します。';

  @override
  String get ocrImageListChanged => '画像リストを変更しました。再度認識を開始します。';

  @override
  String get ocrReadInstructionFailed => '認識命令を読み取ることができません。もう一度やり直してください。';

  @override
  String get ocrErrorDetails => 'エラーの詳細';

  @override
  String get ocrRequestHeading => 'リクエスト';

  @override
  String get ocrResponseHeading => '応答';

  @override
  String get ocrNoDetails => '詳細はありません';

  @override
  String get ocrImageLoadFailed => '画像をロードできません';

  @override
  String get ocrCrop => '作物';

  @override
  String get ocrEdit => '編集';

  @override
  String get ocrProcessingOcrFailed => 'OCR画像の処理に失敗しました。もう一度試してください。';

  @override
  String get settingsPageTitle => '設定';

  @override
  String get settingsSectionGeneral => '一般的な';

  @override
  String get settingsSectionProviders => 'プロバイダー';

  @override
  String get settingsSectionSystemAssistant => 'システムアシスタント';

  @override
  String get settingsSectionContextManagement => 'コンテキスト管理';

  @override
  String get settingsSectionManagement => '管理';

  @override
  String get settingsSectionAbout => 'について';

  @override
  String get settingsBackupRestore => 'バックアップと復元';

  @override
  String get settingsBackupRestoreDescription => 'アプリデータのエクスポートまたはインポート';

  @override
  String get settingsCookies => 'Cookie とブラウザデータ';

  @override
  String get settingsCookiesDescription => '永続的な Cookie とブラウザのストレージを管理する';

  @override
  String get settingsAppLogs => 'アプリのログ';

  @override
  String get settingsAppLogsDescription => 'アプリの実行時ログを表示する';

  @override
  String get settingsThemeDisplay => 'テーマと表示';

  @override
  String get settingsThemeDisplayDescription => 'ダークモードと表示言語';

  @override
  String get settingsTaskNotifications => 'タスク完了通知';

  @override
  String get settingsTaskNotificationsDescription =>
      '通知の許可とシステム設定を確認し、通知ガイドを表示します';

  @override
  String get settingsBackgroundOptimization => 'バックグラウンド操作の最適化';

  @override
  String get settingsBackgroundOptimizationDescription =>
      'システム環境やバックグラウンドサービスの状態を確認し、最適化ガイダンスを表示します';

  @override
  String get aboutVersionInfo => 'バージョン情報を表示する';

  @override
  String get aboutCheckUpdates => 'アップデートをチェックする';

  @override
  String aboutNewVersionFound(Object version) {
    return '新しいバージョン $version が利用可能になりました';
  }

  @override
  String get aboutNewVersion => '新しいバージョン';

  @override
  String get aboutPreviewUpdates => 'プレビューアップデート';

  @override
  String get aboutPreviewUpdatesDescription => 'プレビュー リリースのチェックを有効にする';

  @override
  String get aboutProjectHome => 'プロジェクトホーム';

  @override
  String get aboutFeedback => '問題を報告する';

  @override
  String get aboutPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get aboutOpenSourceAgreement => 'オープンソース契約';

  @override
  String get aboutOpenSourceLicenses => 'オープンソースライセンス';

  @override
  String get aboutCheckingUpdates => 'アップデートをチェック中…';

  @override
  String get aboutUpToDate => '最新バージョンを使用しています';

  @override
  String aboutUpdateNetworkError(Object details) {
    return 'ネットワークエラー: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return '更新チェックが HTTP ステータス $statusCode で失敗しました。';
  }

  @override
  String get aboutUpdateInvalidResponse => '更新サーバーが予期しない応答を返しました。';

  @override
  String get aboutUpdateCheckFailed => 'アップデートチェックに失敗しました。もう一度試してください。';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return 'アシスタントの更新チェックに失敗しました: $error';
  }

  @override
  String get aboutPrivacyContent =>
      'Stroom は、サービスを使用するすべての人のプライバシーを尊重し、保護します。\n\n1. カメラ許可: 写真を撮るためにのみ使用されます。画像データの収集やアップロードは行われません。\n\n2. 写真ライブラリの許可: 写真を選択して保存するためにのみ使用されます。すべての写真はデバイス上にローカルに保存されます。\n\n3. データのセキュリティ: 撮影したすべての写真はデバイス上にローカルに保存されます。当社はあなたのデータにアクセスしたりアップロードしたりすることはありません。\n\n4. サードパーティのサービス: このアプリにはサードパーティの分析サービスや広告サービスは含まれません。\n\nご質問がございましたらお問い合わせください。';

  @override
  String get aboutClose => '閉じる';

  @override
  String get contextToolPruneTitle => 'ツールの結果を自動的にプルーニングする (Prune)';

  @override
  String get contextToolPruneDescription =>
      'しきい値を超える古いツールの結果をプレースホルダーに自動的に置き換えて、ストレージとコンテキストを解放します。';

  @override
  String get contextCompactionTriggerSettings => '圧縮トリガーの設定';

  @override
  String get contextCompactionDisabled => '無効 (圧縮は実行されません)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return 'グローバルトリガー $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のモデル別設定',
      one: '$count 件のモデル別設定',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle => '圧縮トリガーの設定';

  @override
  String get contextAutoCompaction => '自動コンテキスト圧縮';

  @override
  String get contextAutoCompactionDisabled => '無効にすると、どのモデルでも圧縮は実行されません。';

  @override
  String get contextGlobalTrigger => 'グローバルトリガーの割合';

  @override
  String get contextGlobalTriggerDescription =>
      '個別設定のないモデルは、モデル コンテキスト ウィンドウのこのパーセンテージを圧縮トリガーとして使用します。';

  @override
  String contextResetPercent(Object percent) {
    return '$percent%にリセット';
  }

  @override
  String get contextPerModelSettings => 'モデルごとの設定';

  @override
  String get contextNoConfiguredModels => '設定されたモデルはありません';

  @override
  String contextIndependentThreshold(Object threshold) {
    return '独立したしきい値: $threshold トークン';
  }

  @override
  String get contextEnterIndependentThreshold => '以下に独立したしきい値を入力してください';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return 'グローバル $percent% をフォローしてください';
  }

  @override
  String get contextThresholdField => '独立したしきい値（トークン）';

  @override
  String get contextThresholdHint => 'たとえば、48000 (パーセントではなくトークン数)';

  @override
  String get contextPercentField => 'パーセンテージ';

  @override
  String contextPercentHint(Object percent) {
    return 'たとえば、$percent';
  }

  @override
  String get versionInfoTitle => 'バージョン情報';

  @override
  String get versionNumberLabel => 'バージョン';

  @override
  String get versionReleaseTimeLabel => 'リリース時間';

  @override
  String get versionLocalBuild => 'ローカルビルド';

  @override
  String get versionReleaseNotesLabel => 'リリースノート';

  @override
  String get versionClose => '閉じる';

  @override
  String get updateDialogTitle => '新しいバージョンが利用可能になりました';

  @override
  String get updateLatestVersionLabel => '最新バージョン';

  @override
  String get updateSelectedVersionLabel => '選択したバージョン';

  @override
  String get updateReleaseNotesLabel => 'リリースノート';

  @override
  String get updateInstalling => 'インストール中…';

  @override
  String get updateDownloadComplete => 'ダウンロード完了';

  @override
  String get updateClose => '閉じる';

  @override
  String get updateManualInstall => '手動でインストールする';

  @override
  String get updateOpenInstaller => 'インストーラーを開く';

  @override
  String get updateRetryDownload => 'ダウンロードを再試行します';

  @override
  String get updateSkipVersion => 'このバージョンをスキップする';

  @override
  String get updateRemindLater => '後で思い出してください';

  @override
  String get updateOpenBrowser => 'ブラウザでダウンロード';

  @override
  String get updateNow => '今すぐアップデートしてください';

  @override
  String get updatePreviewBadge => 'プレビュー';

  @override
  String get updateLatestBadge => '最新';

  @override
  String get updateSelectVersion => 'バージョンの選択';

  @override
  String get updateDownloading => 'アップデートをダウンロード中…';

  @override
  String updateCheckNetworkError(Object details) {
    return 'ネットワークエラー: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return 'アップデートのチェックに失敗しました: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      '更新のチェックに失敗しました: サーバーは認識できないデータを返しました';

  @override
  String get updateDownloadUrlUnavailable => 'ダウンロード URL が利用できません。';

  @override
  String get updateNoDirectDownloadLink =>
      'このプラットフォームには直接ダウンロード リンクはありません。ブラウザでダウンロードします。';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return '自動インストールに失敗しました: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return 'ダウンロードに失敗しました: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return 'ダウンロードに失敗しました: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return 'インストールに失敗しました: $details';
  }

  @override
  String updateFailed(Object details) {
    return '更新に失敗しました: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return 'ファイルを開けませんでした。手動でインストールします: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return 'インストールに失敗しました。 APKを手動で開きます: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails => 'インストールに失敗しました。 APKを手動で開きます。';

  @override
  String get updateApkInstallerUnavailable =>
      'この APK をインストールするアプリが見つかりませんでした。手動で開きます。';

  @override
  String get updateApkInstallPermissionDenied =>
      'Stroom がシステム設定で不明なアプリをインストールできるようにします。';

  @override
  String get updateRestartDialogTitle => 'アプリが更新されました';

  @override
  String get updateRestartDialogBody => 'アプリが更新されました。安定性を確保するためにアプリを再起動します。';

  @override
  String get updateRestartDialogLater => '後で再起動する';

  @override
  String get updateRestartDialogNow => '今すぐ再起動してください';

  @override
  String get contextCompactionHistoryIntro => '要約する会話履歴:';

  @override
  String get contextCompactionUserRole => 'ユーザー';

  @override
  String get contextCompactionAssistantRole => 'アシスタント';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role がツール $toolName を呼び出しました: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      'テンプレートに正確に従って、上記の会話履歴をアンカー付きの要約に要約します。';

  @override
  String get ocrImageEmpty => '画像は空です。もう一度選択してください。';

  @override
  String get ocrImageUnsupportedFormat =>
      'この画像形式はサポートされていません。 PNG、JPEG、または WebP に変換して、再試行してください。';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'HEIC、SVG、TIFF 画像はまだサポートされていません。画像を PNG、JPEG、または WebP に変換して、再試行してください。';

  @override
  String get ocrImageDecodeFailed =>
      '画像が破損しているか、デコードできません。再度選択するか、PNG、JPEG、または WebP に変換して再試行してください。';

  @override
  String get ocrImageDimensionsTooLarge =>
      '画像の解像度が大きすぎます。 OCR は、画像あたり最大 5,000 万ピクセルをサポートします。サイズを変更して再試行してください。';

  @override
  String get ocrImageOrientationPngTooLarge =>
      'この画像の方向を修正するために必要な PNG は、OCR リクエストのサイズ制限を超えます。画像のサイズを変更して再試行してください。';

  @override
  String get ocrImageOrientationFailed =>
      '画像の向きを補正できませんでした。 PNG、JPEG、または WebP に変換して、再試行してください。';

  @override
  String get ocrImagePreparationFailed => '画像を処理できませんでした。もう一度選択して、もう一度試してください。';

  @override
  String get homeTitle => '家';

  @override
  String get homeWelcome => 'スルームへようこそ';

  @override
  String get homeChooseModule => '開始するにはモジュールを選択してください';

  @override
  String get homeOcrSubtitle => 'テキスト認識';

  @override
  String get homeAsrTitle => '音声認識';

  @override
  String get homeAsrSubtitle => '音声をテキストに変換';

  @override
  String get homeWebDownloadTitle => 'ウェブメディアをダウンロードする';

  @override
  String get homeWebDownloadSubtitle => 'Webページからオーディオとビデオをダウンロードする';

  @override
  String get homeAudioSeparationTitle => '音声の分離';

  @override
  String get homeAudioSeparationSubtitle => 'ビデオから音声を抽出する';

  @override
  String get homeTtsTitle => 'テキスト読み上げ';

  @override
  String get homeTtsSubtitle => 'テキストを音声に変換する';

  @override
  String get homeChartsTitle => 'チャートメーカー';

  @override
  String get homeChartsSubtitle => 'マーメイドチャートエディター';

  @override
  String get homeMathTitle => '数学的なプロット';

  @override
  String get homeMathSubtitle => 'プロット関数';

  @override
  String get homeAnkiTitle => 'アンキのフラッシュカード';

  @override
  String get homeAnkiSubtitle => '記憶補助システム';

  @override
  String get homeTaskFlowTitle => 'タスクフロー';

  @override
  String get homeTaskFlowEmpty => '複数のモジュールを順番に実行する自動フローを作成する';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のタスクフロー · 管理',
      one: '$count 件のタスクフロー · 管理',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => '最近のタスク';

  @override
  String get homeViewAll => 'すべて見る';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusFailed => '失敗した';

  @override
  String get navHome => '家';

  @override
  String get navChat => 'チャット';

  @override
  String get navFiles => 'ファイル';

  @override
  String get navSettings => '設定';

  @override
  String get conversationsTitle => '会話履歴';

  @override
  String get conversationNew => '新しい会話';

  @override
  String get conversationSelectTitle => '会話を選択してください';

  @override
  String get topicSelectionEmptyTitle => 'まだ会話はありません';

  @override
  String get topicSelectionEmptyMessage => '新しい会話を作成して始めてください';

  @override
  String get topicSelectionNewTopic => '新しい会話';

  @override
  String get topicSelectionNoAssistant => 'アシスタントが選択されていません';

  @override
  String get topicSelectionBackToAssistants => 'アシスタントの選択に戻る';

  @override
  String get topicSelectionEditAssistant => '編集アシスタント';

  @override
  String get topicSelectionReorderHint => '長押ししてドラッグして会話を並べ替えます';

  @override
  String conversationDeleteNamed(String title) {
    return '会話「$title」を削除しますか?これを元に戻すことはできません。';
  }

  @override
  String get conversationDeleteTitle => '会話を削除する';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選択した会話を $count 件削除しますか？この操作は元に戻せません。',
      one: '選択した会話を $count 件削除しますか？この操作は元に戻せません。',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionDelete => '消去';

  @override
  String get conversationRename => '会話の名前を変更する';

  @override
  String get conversationRenameHint => '新しい名前を入力してください';

  @override
  String get actionConfirm => '確認する';

  @override
  String get conversationNoMatches => '一致する会話が見つかりませんでした';

  @override
  String get conversationEmpty => '会話履歴がありません';

  @override
  String get conversationSearchHint => 'すべての会話内のメッセージを検索します...';

  @override
  String conversationSelected(int count) {
    return '$countが選択されました';
  }

  @override
  String get conversationSearch => '検索';

  @override
  String get conversationDeleteSelected => '選択したものを削除';

  @override
  String get actionUnselect => '選択をキャンセルする';

  @override
  String get actionSelect => '選択';

  @override
  String conversationDeleteCount(int count) {
    return '$countを削除';
  }

  @override
  String get conversationPin => 'ピン';

  @override
  String get conversationUnpin => '固定を解除する';

  @override
  String get actionRename => '名前の変更';

  @override
  String get conversationAutoRename => '自動名前付け';

  @override
  String get conversationTemporary => '一時的な会話';

  @override
  String get conversationCloseTemporary => '一時的な会話を閉じる';

  @override
  String get taskListTitle => 'タスクリスト';

  @override
  String get taskListEmpty => 'タスクがありません';

  @override
  String get unifiedTaskListTabAll => '全て';

  @override
  String get unifiedTaskListTabInProgress => '進行中';

  @override
  String get unifiedTaskListTabCompleted => '完了';

  @override
  String get unifiedTaskListTabFailed => '失敗した';

  @override
  String get unifiedTaskListTabStopped => '停止しました';

  @override
  String get unifiedTaskListConfirmClear => 'クリアを確認する';

  @override
  String get unifiedTaskListConfirmClearFailedMessage =>
      '失敗したタスクをすべてクリアしてもよろしいですか?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      'すべてのタスクをクリアしてもよろしいですか?この操作は元に戻すことができません。';

  @override
  String get unifiedTaskListCancel => 'キャンセル';

  @override
  String get unifiedTaskListConfirm => '確認する';

  @override
  String get unifiedTaskListClearCompleted => '完了したタスクをクリアする';

  @override
  String get unifiedTaskListClearFailed => '失敗したタスクをクリアする';

  @override
  String get unifiedTaskListClearAll => 'すべてのタスクをクリアする';

  @override
  String get unifiedTaskListRestoreInProgress => 'タスク フロー レコードを復元しています…';

  @override
  String get unifiedTaskListRestoreFailed =>
      'タスク フロー レコードを読み取れませんでした。タスクのアクションは一時停止されます';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return '未クリア: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning => 'タスク・フローはキャンセル後も実行中です。';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      'タスク・フローのキャンセル状態を保存できませんでした。再度クリアをお試しください。';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      'タスク・フロー・レコードの削除を保存できませんでした。再度クリアをお試しください。';

  @override
  String get chatAutoContinuePrompt => '完了していない場合は続行します。';

  @override
  String get chatSearchCurrent => 'この会話を検索...';

  @override
  String get chatSearchAll => 'すべての会話を検索...';

  @override
  String get searchPrevious => '前回の試合';

  @override
  String get searchNext => '次の試合';

  @override
  String get searchClose => '検索を閉じる';

  @override
  String get searchCurrentConversation => '現在の会話';

  @override
  String get searchAllConversations => 'すべての会話';

  @override
  String get chatReasoning => '推論';

  @override
  String get chatTools => 'ツール';

  @override
  String get chatCustomParameters => 'カスタムパラメータ';

  @override
  String get chatEditMessage => 'メッセージを編集する';

  @override
  String get actionClose => '閉じる';

  @override
  String get chatEditWarning => '編集して再送信すると、以下のメッセージはすべて失われます';

  @override
  String get chatAttachment => 'アタッチメント';

  @override
  String get chatMessageHint => 'メッセージを入力してください...';

  @override
  String get chatFullscreenEdit => '全画面エディター';

  @override
  String get chatStopGeneration => '生成を停止する';

  @override
  String get actionSend => '送信';

  @override
  String get chatCopy => 'コピー';

  @override
  String get actionSave => '保存';

  @override
  String get actionRetry => 'リトライ';

  @override
  String get actionEdit => '編集';

  @override
  String get chatViewResponseData => '応答データの表示';

  @override
  String get chatViewRequestData => 'リクエストデータの表示';

  @override
  String get chatInspectJson => 'JSONを検査する';

  @override
  String get chatConfirmEditTitle => 'メッセージを編集する';

  @override
  String get chatConfirmEditDeleteFollowing =>
      'このメッセージを編集しますか?このメッセージとこれ以降のメッセージはすべて削除されます。';

  @override
  String get chatConfirmResend => 'このメッセージを再送信しますか?';

  @override
  String get chatConfirmRetryTitle => 'リトライ';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      'この応答を再試行しますか?このメッセージとこれ以降のメッセージはすべて削除されます。';

  @override
  String get chatConfirmRegenerate => '応答を再生成しますか?';

  @override
  String get chatDeleteMessageTitle => 'メッセージを削除する';

  @override
  String get chatDeleteMessageConfirm => 'このメッセージを削除しますか?これを元に戻すことはできません。';

  @override
  String get chatThinking => '考え';

  @override
  String get chatThinkingComplete => '考え';

  @override
  String get conversationDeleteOne => 'この会話を削除しますか?これを元に戻すことはできません。';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'リソース $selected/$total 件を選択中',
      one: 'リソース $selected/$total 件を選択中',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => 'ダウンロードするメディアを選択してください';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のセグメントを非表示',
      one: '$count 個のセグメントを非表示',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のセグメントを表示',
      one: '$count 個のセグメントを表示',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => 'リソースが検出されませんでした';

  @override
  String get mediaSegment => 'セグメント';

  @override
  String get mediaPlaylist => 'プレイリスト';

  @override
  String get mediaFullVideo => 'フルビデオ';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours 時間 $minutes 分 $seconds 秒';
  }

  @override
  String mediaDuration(String value) {
    return '期間: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return '解像度: ${width}x$height';
  }

  @override
  String get mediaPreview => 'プレビュー';

  @override
  String get mediaSegmentPreviewHint => 'プレイリストからセグメントをプレビューする';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選択したリソースを $count 件ダウンロード',
      one: '選択したリソースを $count 件ダウンロード',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => 'ダウンロードの確認';

  @override
  String get chatNoMoreHistory => 'これ以上のメッセージはありません';

  @override
  String get chatSendFailed => 'メッセージの送信に失敗しました';

  @override
  String get chatViewErrorDetails => 'エラーの詳細を表示する';

  @override
  String get chatCompactionCollapsed =>
      'コンテキストが圧縮され、古いメッセージが要約されました (クリックして折りたたむ)';

  @override
  String get chatCompactionExpanded =>
      'コンテキストが圧縮され、古いメッセージが要約されました (クリックして要約を表示)';

  @override
  String get chatEditConversationTitle => '会話のタイトルを編集する';

  @override
  String get chatSearchMessages => 'メッセージを検索する';

  @override
  String get chatApiMissingSettings => '⚠️ チャット API が設定されていません — 設定に移動してください';

  @override
  String get appSettings => '設定';

  @override
  String get chatCopied => 'コピーされました';

  @override
  String get chatNoSavableText => '保存するテキストがありません';

  @override
  String get chatSaveMarkdownTitle => 'メッセージをマークダウンとして保存';

  @override
  String get chatSaveToolCallChoice =>
      'この応答には複数のツール呼び出しが含まれています。保存するものを選択してください:';

  @override
  String get chatSaveCompleteMessage => '完了したメッセージを保存する';

  @override
  String get chatSaveLastMessage => '最後のメッセージを保存する';

  @override
  String get chatSaveToAppFiles => 'アプリファイルに保存';

  @override
  String get chatSaveFolderHint => '.md ファイル用のフォルダーを選択または作成します';

  @override
  String get chatSaveFilenameHint => 'ファイル名を入力します（.mdが自動的に追加されます）';

  @override
  String get chatFilenameRequired => 'ファイル名を空にすることはできません';

  @override
  String chatSavedToPath(String path) {
    return '保存先: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return 'アプリファイルに保存: $path';
  }

  @override
  String get chatSelectModel => 'モデルを選択してください';

  @override
  String get chatModelFallback => 'モデル';

  @override
  String get chatNoModelsAvailable => '利用可能なモデルはありません';

  @override
  String get chatAvailableTools => '利用可能なツール';

  @override
  String get chatNoToolsAvailable => '利用可能なツールがありません';

  @override
  String get chatReasoningSettings => '推論設定';

  @override
  String get chatReasoningNotConfigured =>
      'このモデルには推論パラメーターが構成されていません。モデル設定に追加します。';

  @override
  String get chatReasoningEffort => '推論の努力';

  @override
  String get chatReasoningEffortNotConfigured =>
      'このモデルには推論努力パラメーターが構成されていません。モデル設定に追加します。';

  @override
  String get chatParameterNoOptions => 'このパラメータにはオプション値はありません。モデル設定に追加します。';

  @override
  String get chatOtherReasoningNotConfigured =>
      'このモデルには他の推論パラメーターは構成されていません。\nモデル設定に追加します。';

  @override
  String get chatCustomParamsNotConfigured =>
      'このモデルにはカスタム パラメーターは設定されていません。\nモデル設定に追加します。';

  @override
  String get chatNoOptionValues => 'オプション値はありません。モデル設定に追加します。';

  @override
  String get chatImageLoadFailed => '画像をロードできません';

  @override
  String get chatVideoLoadFailed => 'ビデオをロードできません';

  @override
  String get chatHtmlLoading => 'HTML プレビューを読み込んでいます...';

  @override
  String get chatPreviewLoadFailed => 'プレビューの読み込みに失敗しました';

  @override
  String get albumPickerLoadFailed => 'アプリアルバムを読み込めません';

  @override
  String get chatHtmlPreview => 'HTMLプレビュー';

  @override
  String get chatMermaidLoading => 'グラフのプレビューを読み込んでいます...';

  @override
  String get chatMermaidPreview => 'マーメイドプレビュー';

  @override
  String get chatZoomOut => 'ズームアウト';

  @override
  String get chatZoomIn => 'ズームイン';

  @override
  String get chatJsonInspection => 'JSON検査';

  @override
  String get chatNoRequestData => 'リクエストデータがありません';

  @override
  String get chatNoResponseData => '応答データがありません';

  @override
  String get chatSaveMessage => 'メッセージを保存する';

  @override
  String get chatChooseSaveLocation => 'メッセージを保存する場所を選択してください';

  @override
  String get chatChooseSaveLocationLabel => '保存場所を選択します:';

  @override
  String get chatSaveAppFile => 'アプリファイルに保存';

  @override
  String get chatSaveDevice => 'デバイスに保存';

  @override
  String get chatFileTypeAudio => '音声ファイル';

  @override
  String get chatFileTypeVideo => 'ビデオファイル';

  @override
  String get chatFileTypeDocument => '書類';

  @override
  String get chatFileTypeGeneric => 'ファイル';

  @override
  String get chatInfoType => 'タイプ';

  @override
  String get chatInfoSize => 'サイズ';

  @override
  String get chatInfoPath => 'パス';

  @override
  String get chatErrorBack => '戻る';

  @override
  String get chatErrorPrefix => 'エラー：';

  @override
  String get chatErrorCancelled => 'ユーザーによって出力が中断されました';

  @override
  String get chatErrorProviderNotConfigured =>
      'チャット API が設定されていません。 「設定」を開いてプロバイダーを構成します。';

  @override
  String get chatErrorApiKeyNotConfigured => 'APIキーが設定されていません。設定を確認してください。';

  @override
  String get chatErrorServerConnection =>
      'サーバーに接続できません。ネットワーク接続と API アドレスを確認してください。';

  @override
  String get chatErrorNetworkConnection => 'ネットワーク接続に失敗しました。ネットワーク接続を確認してください。';

  @override
  String get chatErrorTimeout => '接続がタイムアウトしました。サーバーが応答しませんでした。';

  @override
  String chatAttachmentImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return '写真を撮影できませんでした: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform はデバイス ギャラリー アクセスをサポートしていません: $error';
  }

  @override
  String get chatAttachmentWebPlatform => 'ウェブブラウザ';

  @override
  String get chatAttachmentCurrentPlatform => 'このデバイス';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      'フォトライブラリへのアクセス許可を付与して、再試行してください。';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      'ブラウザの設定でこの Web サイトがファイルにアクセスできるようにしてください。';

  @override
  String get chatAttachmentGalleryFallbackHint =>
      'デバイスがギャラリーの選択をサポートしていることを確認してください。';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return '画像をインポートできませんでした: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform はファイル選択をサポートしていません: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint => 'ファイルへのアクセス権限を付与して、再試行してください。';

  @override
  String get chatAttachmentFileFallbackHint =>
      'デバイスがファイル選択をサポートしていることを確認してください。';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return 'ファイルをインポートできませんでした: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return '輸入品 $fileName';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return '編集した画像を保存できませんでした: $error';
  }

  @override
  String get chatDataDetails => 'データ詳細';

  @override
  String get chatErrorDetailOcrDiagnostics => 'OCR診断';

  @override
  String get chatErrorDetailRequestUrl => 'リクエストURL';

  @override
  String get chatErrorDetailRequestHeaders => 'リクエストヘッダー';

  @override
  String get chatErrorDetailRequestBody => 'リクエストボディ';

  @override
  String get chatErrorDetailStatusCode => 'ステータスコード';

  @override
  String get chatErrorDetailResponseHeaders => '応答ヘッダー';

  @override
  String get chatErrorDetailResponseBody => '応答本文';

  @override
  String get chatErrorDetailEmpty => '詳細なデータはありません';

  @override
  String get chatAudioPreviewClose => '閉じる';

  @override
  String get chatPreviewClose => 'プレビューを閉じる';

  @override
  String get actionBack => '戻る';

  @override
  String get chatCannotLoadFile => 'ファイルをロードできません';

  @override
  String chatThinkingNumbered(int index) {
    return '思考 $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '保存されていない変更を破棄しますか?';

  @override
  String get taskFlowUiDiscardBody => '戻ると、保存されていない変更はすべて失われます。';

  @override
  String get taskFlowUiContinueEditing => '編集を続ける';

  @override
  String get taskFlowUiDiscard => '破棄';

  @override
  String get taskFlowUiUndo => '元に戻す';

  @override
  String get taskFlowUiSave => '保存';

  @override
  String get taskFlowUiNameHint => 'タスクフロー名を入力してください';

  @override
  String get taskFlowUiDescriptionHint => '説明を追加します (オプション)';

  @override
  String get taskFlowUiNameRequired => 'タスクフロー名を入力してください';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return 'ステップ $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return '「$block」には「$parameter」が必要です';
  }

  @override
  String get taskFlowUiSaveFailed => '保存できませんでした。変更内容はまだ残っています。もう一度やり直してください。';

  @override
  String get taskFlowUiRetry => 'リトライ';

  @override
  String get taskFlowUiUpdated => 'タスクフローが更新されました';

  @override
  String get taskFlowUiCreated => 'タスクフローが作成されました';

  @override
  String get taskFlowUiTitle => 'タスクフロー';

  @override
  String get taskFlowUiNotFound => 'タスクが見つかりません';

  @override
  String get taskFlowUiBack => '戻る';

  @override
  String get taskFlowUiEdit => '編集';

  @override
  String taskFlowUiInput(Object label) {
    return '入力 ($label)';
  }

  @override
  String get taskFlowUiInputHint => 'テキストまたはリンクを入力してください';

  @override
  String get taskFlowUiStart => 'タスクフローの開始';

  @override
  String get taskFlowUiNoInput => 'まだ入力がありません。以下をタップして Web リソースの URL を追加します。';

  @override
  String get taskFlowUiAddResource => 'Web リソースを追加する';

  @override
  String get taskFlowUiUrlHint => 'ビデオまたはオーディオ Web ページの URL を入力してください';

  @override
  String get taskFlowUiDeleteInput => 'この入力を削除します';

  @override
  String get taskFlowUiHour => '時';

  @override
  String get taskFlowUiMinute => '分';

  @override
  String get taskFlowUiSecond => '秒';

  @override
  String get taskFlowUiPreview => 'プレビュー:';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      'オプション: ビデオ リソースを長さによってフィルタリングします。利用可能なすべてのリソースを表示するには、空白のままにします。';

  @override
  String get taskFlowUiSelectImages => '画像を選択（複数）';

  @override
  String get taskFlowUiSelectAudio => '音声を選択（複数）';

  @override
  String get taskFlowUiSelectFiles => 'ファイルを選択（複数）';

  @override
  String get taskFlowUiSelectVideo => '動画を選択（複数）';

  @override
  String get taskFlowUiRemove => '取り除く';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return '削除されたファイルをクリーンアップできませんでした: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0.初期入力';

  @override
  String taskFlowUiInputType(Object type) {
    return '入力タイプ: $type';
  }

  @override
  String get taskFlowUiUserFlowInput => 'ユーザーがタスク・フローを実行するときに提供される入力';

  @override
  String taskFlowUiBlockInput(Object type) {
    return '入力: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return '出力: $type';
  }

  @override
  String get taskFlowUiParameters => 'パラメータ:';

  @override
  String get taskFlowUiClose => '閉じる';

  @override
  String get taskFlowUiSelectAppImages => 'アプリから画像を選択（複数）';

  @override
  String get taskFlowUiNoImages => '画像がありません';

  @override
  String get taskFlowUiSelectAppAudio => 'アプリから音声を選択（複数）';

  @override
  String get taskFlowUiNoAudio => '音声なし';

  @override
  String get taskFlowUiSelectAppVideo => 'アプリから動画を選択（複数）';

  @override
  String get taskFlowUiNoVideo => '動画はありません';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return 'ファイルを選択できませんでした: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '「$name」は$limit MBを超えています。より小さいファイルを選択してください。';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '「$name」が空であるか、読み取り不能です';
  }

  @override
  String get taskFlowUiSomeFilesMissing => '一部のファイルが欠落しているためスキップされました';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return '$count の選択されたファイルにアクセスできません。すべてのファイルを再度選択してください。';
  }

  @override
  String get taskFlowUiQueuedOne => 'タスクフローがキューに追加されました';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return '$count タスク フローをキューに追加しました';
  }

  @override
  String get taskFlowUiRunTitle => 'このラン';

  @override
  String get taskFlowUiCancelBatch => 'バッチ全体をキャンセルする';

  @override
  String get taskFlowUiRestoringRecords => 'タスク フロー レコードを復元しています…';

  @override
  String get taskFlowUiRecordsPaused =>
      'タスク フロー レコードをロードできませんでした。タスクのアクションは一時停止されます。';

  @override
  String get taskFlowUiRecordsCleared => 'この実行の記録は消去されました';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return '$finished/$total の実行が終了しました';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return '· $count レコードがクリアされました';
  }

  @override
  String get taskFlowUiTemporaryFiles => '一時中間ファイル';

  @override
  String get taskFlowUiAddBlock => 'ブロックの追加';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return 'ステップ $index の前にブロックを挿入';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      '隣接する両方のステップと互換性のあるブロックはありません。最初に隣接するステップを調整します。';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return 'ステップ $index の前に挿入';
  }

  @override
  String get taskFlowUiUnknown => '未知';

  @override
  String get taskFlowUiChooseBlock => 'ブロックを選択してください';

  @override
  String get taskFlowUiInsertBlock => 'インサートブロック';

  @override
  String get taskFlowUiPreviousOutput => '前のステップの出力';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return ';次のステップで必要なもの: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock => '現在のタイプと互換性のあるブロックはありません';

  @override
  String get taskFlowUiReplaceBlock => 'ブロックを置き換える';

  @override
  String get taskFlowUiBlockCompatibility =>
      'これは、互換性のある入力および出力タイプを持つブロックにのみ置き換えることができます。';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      '次のステップで結果が正常に保存された後にクリーンアップします。最後のステップは常に保持されます。';

  @override
  String get taskFlowUiSetParameters => 'パラメータを設定する';

  @override
  String get taskFlowUiReplace => '交換する';

  @override
  String get taskFlowUiViewParameters => 'タップしてパラメータを表示します';

  @override
  String get taskFlowUiTapSetParameters => 'タップしてパラメータを設定します';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return '不明なブロック: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered => 'このブロック タイプは登録されていません';

  @override
  String taskFlowUiStepActions(Object index) {
    return 'ステップ $index のアクション';
  }

  @override
  String get taskFlowUiInsertBefore => '前に挿入';

  @override
  String get taskFlowUiInsertAfter => '後に挿入';

  @override
  String get taskFlowUiCopyBlock => '重複ブロック';

  @override
  String get taskFlowUiMoveUp => '上に移動';

  @override
  String get taskFlowUiMoveUpDisabled => '上に移動 (す​​でに最初)';

  @override
  String get taskFlowUiMoveDown => '下に移動';

  @override
  String get taskFlowUiMoveDownDisabled => '下に移動 (す​​でに最後)';

  @override
  String get taskFlowUiDeleteBlock => 'ブロックの削除';

  @override
  String taskFlowUiInputLabel(Object label) {
    return '入力: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return '出力: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return 'ブロックタイプ「$name」は登録されていません';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return '$labelの設定';
  }

  @override
  String get taskFlowUiSendToAssistant => 'アシスタントに送信されたユーザー メッセージは、前のステップの出力です';

  @override
  String get taskFlowUiTempSpaceInfo =>
      'このステップはフローの一時スペースに出力します。次のステップが正常に保存された後、出力はクリーンアップされます。一時モードが無効になっている場合、元の保存フォルダーは保存され、復元されます。';

  @override
  String get taskFlowUiNoExtraParameters => 'このブロックには追加のパラメーターはありません';

  @override
  String get taskFlowUiCancel => 'キャンセル';

  @override
  String get taskFlowUiConfirm => '確認する';

  @override
  String get taskFlowUiConfigureModelFirst => '最初にモデルを構成する';

  @override
  String get taskFlowUiModelUnavailable =>
      'モデルが選択されていないか、モデルが使用できません。別のモデルを選択してください。';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return '型式 $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => '名前のないプロバイダー';

  @override
  String get taskFlowUiCustomModelParameters => 'カスタムモデルパラメータ';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      'TTS モデルには音声が設定されていません。 ID は手動で入力できます。';

  @override
  String get taskFlowUiVoiceUnavailable => '音声が利用できません。別の音声を選択してください。';

  @override
  String get taskFlowUiSelectVoice => '音声を選択してください';

  @override
  String get taskFlowUiAssistantUnavailable => 'アシスタントが利用不可';

  @override
  String get taskFlowUiAssistantUseCurrent =>
      '指定されていません (現在選択されているアシスタントを使用します)';

  @override
  String get taskFlowUiAssistantDeleted =>
      '構成されたアシスタントが削除されました。別のアシスタントを選択してください。';

  @override
  String get taskFlowUiChooseAssistant => 'アシスタントを選択してください';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      '「マイアシスタント」のみ選択可能（「チャット→アシスタント」で追加）';

  @override
  String get taskFlowUiMyAssistants => '私のアシスタント';

  @override
  String get taskFlowUiNoCustomAssistants =>
      'カスタム アシスタントはまだありません。 「チャット→アシスタント」で作成します。';

  @override
  String get taskFlowUiYes => 'はい';

  @override
  String get taskFlowUiNo => 'いいえ';

  @override
  String get taskFlowUiDefaultRoot => 'デフォルト（ルートフォルダー）';

  @override
  String get taskFlowUiSelect => '選択';

  @override
  String get taskFlowUiSelectSaveFolder => '保存フォルダーを選択してください';

  @override
  String get taskFlowUiCatCatchVideo => 'ビデオ';

  @override
  String get taskFlowUiCatCatchAudio => 'オーディオ';

  @override
  String get taskFlowUiCatCatchEither =>
      'ビデオまたはオーディオ (ダウンストリームステップに基づいてフィルタリング)';

  @override
  String get taskFlowUiManual => 'マニュアル';

  @override
  String get taskFlowUiAutomatic => '自動';

  @override
  String get taskFlowUiAutomaticPrompt => '確認付き自動';

  @override
  String get taskFlowUiEditTitle => 'タスクフローの編集';

  @override
  String get taskFlowUiCreateTitle => '新しいタスクフロー';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return 'ステップ $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return '入力タイプ: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return '入力: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return '出力: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return '削除されたファイルをクリーンアップできませんでした: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return 'ファイルを選択できませんでした: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '「$name」は$limit MBを超えています。より小さいファイルを選択してください。';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '「$name」が空であるか、読み取り不能です';
  }

  @override
  String get taskFlowUiTemporary => '一時的';

  @override
  String get taskFlowUiTemporaryFileHint => '一時ファイル (次のステップが成功するとクリーンアップされます)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return 'ブロックタイプ「$name」は登録されていません';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return '$finished/$total の実行が終了しました';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return '· $count レコードがクリアされました';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return '入力：$input → 出力：$output';
  }

  @override
  String get taskFlowCardTag => 'タスクフロー';

  @override
  String get taskFlowCardQueued => 'キューに入れられています (リソースを待っています)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done/$total完成';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count $label';
  }

  @override
  String get taskFlowCardFailedLabel => '失敗した';

  @override
  String get taskFlowCardSkippedLabel => 'スキップしました';

  @override
  String get taskFlowCardCancelledLabel => 'キャンセル';

  @override
  String get taskFlowCardInterruptedLabel => '中断された';

  @override
  String get taskFlowCardCancelFlow => 'フローのキャンセル';

  @override
  String get taskFlowCardRetry => 'リトライ';

  @override
  String get taskFlowCardCancelBatch => 'バッチ全体をキャンセルする';

  @override
  String get taskFlowCardDelete => '消去';

  @override
  String get taskFlowCardRetryFlow => 'タスクフローの再試行';

  @override
  String get taskFlowCardNoSnapshot =>
      'この実行にはスナップショットがありません。現在のフロー構成を使用して最初からやり直します。';

  @override
  String get taskFlowCardRetryInfo =>
      'やり直すと、ファイルがダウンロードされ、モデルが再度呼び出されます。起動時に使用した構成で再試行するか、最新の構成を明示的に選択してください。完了したステップを再利用するには、「中断されたステップから再開」を選択します。';

  @override
  String get taskFlowCardRunLatest => '最新の構成で実行する';

  @override
  String get taskFlowCardRetryOriginal => '元の構成で再試行してください';

  @override
  String get taskFlowCardDeleteRecord => 'タスクフローレコードの削除';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      'この実行を削除すると、バッチ内の未完了のタスクがキャンセルされ、サブタスク レコードがクリアされます。消去？';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      'この流れが動いています。削除すると、アクティブなタスクがキャンセルされます。消去？';

  @override
  String get taskFlowCardDeleteRecordConfirm =>
      'このフロー レコードとそのサブタスク レコードを削除しますか?';

  @override
  String get taskFlowCardDeleteConfirm => 'このフロー記録を削除しますか?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      'フローキャンセル状態を保存できませんでした。もう一度削除してみてください。';

  @override
  String get taskFlowCardStillRunning => 'フローはキャンセル後も実行中です。';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      'フローレコードの削除状態を保存できませんでした。もう一度削除してみてください。';

  @override
  String get taskFlowCardConfirm => '確認する';

  @override
  String get taskFlowCardWaiting => '待っている';

  @override
  String get taskFlowCardRunning => 'ランニング';

  @override
  String get taskFlowCardPaused => '一時停止中';

  @override
  String get taskFlowCardCompleted => '完了';

  @override
  String get taskFlowCardFailed => '失敗した';

  @override
  String get taskFlowCardCanceled => 'キャンセル';

  @override
  String get taskFlowCardInterrupted => '中断されました';

  @override
  String get taskFlowCardSucceeded => 'スキップされました';

  @override
  String get taskFlowCardPause => 'フローを一時停止する';

  @override
  String get taskFlowCardResume => 'フローを再開する';

  @override
  String get taskFlowCardResumeInterrupted => '中断したステップから再開';

  @override
  String get taskFlowCardCancel => 'キャンセル';

  @override
  String get unifiedTaskType => 'タスクの種類';

  @override
  String get unifiedTaskCreatedAt => '作成されました';

  @override
  String get unifiedTaskCompletedAt => '完了';

  @override
  String get unifiedTaskResultStatus => '結果ステータス';

  @override
  String get unifiedTaskPartialResult => '部分的な結果。内容が不完全である可能性があります';

  @override
  String get unifiedTaskErrorDetails => 'エラーの詳細';

  @override
  String get unifiedTaskViewErrorDetails => 'エラーの詳細を表示する';

  @override
  String get unifiedTaskOcrPerImage => 'それぞれの画像を認識する';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return '画像 $index';
  }

  @override
  String get unifiedTaskOcrPending => '認識を待っています';

  @override
  String get unifiedTaskOcrRunning => '認識する';

  @override
  String get unifiedTaskCompleted => '完了';

  @override
  String get unifiedTaskIncomplete => '不完全な結果';

  @override
  String get unifiedTaskOcrFailed => '認識に失敗しました';

  @override
  String get unifiedTaskCancelled => 'キャンセル';

  @override
  String get unifiedTaskWaitingStart => '開始を待っています...';

  @override
  String get unifiedTaskSteps => 'ステップ';

  @override
  String get unifiedTaskStartNow => '今すぐ始めましょう';

  @override
  String get unifiedTaskOpenFile => 'ファイルを開く';

  @override
  String get unifiedTaskRetrySave => '保存のみを再試行する';

  @override
  String get unifiedTaskRetryPartialSave => '部分的な結果のみを保存して再試行します';

  @override
  String get unifiedTaskSavePartialResult => '部分的な結果を保存する';

  @override
  String get unifiedTaskRetry => 'リトライ';

  @override
  String get unifiedTaskCancel => 'キャンセル';

  @override
  String get unifiedTaskDelete => '消去';

  @override
  String get unifiedTaskFormatUnsupported => 'この形式ではプレビューはサポートされていません';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return 'ロード失敗: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return '再生に失敗しました: $error';
  }

  @override
  String get unifiedTaskAudioFile => '音声ファイル';

  @override
  String get unifiedTaskPreviewLoadFailed => 'プレビューを読み込めませんでした';

  @override
  String get unifiedTaskUnknownSize => '不明なサイズ';

  @override
  String get unifiedTaskUnnamedRecording => '無題の録音';

  @override
  String get unifiedTaskPause => '一時停止';

  @override
  String get unifiedTaskClearTask => 'タスクをクリアする';

  @override
  String get unifiedTaskContinue => '続く';

  @override
  String get unifiedTaskRemoveFromList => 'リストから削除';

  @override
  String get unifiedTaskSynthesisText => '合成テキスト';

  @override
  String get unifiedTaskStatus => '状態';

  @override
  String get unifiedTaskDetails => '詳細';

  @override
  String get unifiedTaskSynthesisError => '合成エラーの詳細';

  @override
  String get unifiedTaskClose => '閉じる';

  @override
  String get unifiedTaskRawRequestResponse => '生のリクエストとレスポンス';

  @override
  String get unifiedTaskRawRequestBody => '生のリクエスト本文:';

  @override
  String get unifiedTaskRawResponseBody => '生の応答本体:';

  @override
  String get commonJustNow => 'ちょうど今';

  @override
  String commonMinutesAgo(Object count) {
    return '$count 分前';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count 時間前';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes 分 $seconds 秒';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours 時間 $minutes 分';
  }

  @override
  String get unifiedTaskTypeOcr => '画像テキスト認識';

  @override
  String get unifiedTaskTypeAsr => '音声転写';

  @override
  String get unifiedTaskTypeAudioSeparation => '音声の分離';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return 'OCR: $basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return '音声分離: $basename';
  }

  @override
  String get unifiedTaskTypeChat => 'アシスタントのチャット';

  @override
  String get unifiedTaskPlayAudio => 'オーディオを再生する';

  @override
  String get unifiedTaskPauseAudio => '音声を一時停止する';

  @override
  String get catcatchFlowActionNotStarted =>
      'フローアクションが開始されませんでした。フローのステータスを確認して、再試行してください。';

  @override
  String catcatchFlowActionFailed(Object error) {
    return 'フローアクションが失敗しました: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      '自動ページスキャンがタイムアウトしました。サインインするか、このページでユーザー スクリプトを構成します。メディアが検出されたら、[フローを続行] を選択します。';

  @override
  String get browserRecoveryContinue => '流れを続ける';

  @override
  String get catcatchSkipped => 'スキップされました (処理するものは何もありません)';

  @override
  String catCatchDetailMediaResources(Object count) {
    return '$count メディア リソースが見つかりました';
  }

  @override
  String catCatchDetailResources(Object count) {
    return '$count リソースが見つかりました';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return 'ブラウザが $count リソースを見つけました';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return '$total リソースが見つかりました ($segments プレイリスト セグメント)';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return '$count リソースが見つかりました。 1 つお選びください。';
  }

  @override
  String get catCatchDetailAutoSelectFirst => '結果1が自動的に選択され、ダウンロードが開始されます';

  @override
  String get catCatchDetailAutoSelectRemaining =>
      '結果は 1 つ残っています。自動的にダウンロードを開始しました';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return '.$extension の変換はスキップされました。この形式は変換する必要がありません';
  }

  @override
  String get catCatchDetailSkipNoExtension => '変換はスキップされました。この形式は変換する必要がありません';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return '$duration でフィルタリングした後、$remaining の結果が残ります ($removed の不一致リソースは除外されます)';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return 'すべての $count リソースは $duration 期間フィルターと一致します';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '${count}h';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '${count}m';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count';
  }

  @override
  String get catcatchRetryStep => 'このステップを再試行してください';

  @override
  String catcatchCollapseSegments(Object count) {
    return '$count セグメントを非表示にする';
  }

  @override
  String catcatchShowSegments(Object count) {
    return '$count セグメントを表示';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '$total リソース中 $selected が選択されました';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '$count メディア リソースが検出されました';
  }

  @override
  String get catcatchFlowSelectOrCombine =>
      '(リソースを 1 つ選択するか、オーディオ/ビデオのペアを組み合わせます)';

  @override
  String get catcatchSelectMultiple => '(タップして選択します。複数可)';

  @override
  String get catcatchWaitingForResources => 'フローリソースを待っています';

  @override
  String catcatchDownloadSelected(Object count) {
    return '$count 選択したリソースをダウンロード';
  }

  @override
  String get catcatchSelectResources => 'ダウンロードするリソースを選択してください';

  @override
  String get catcatchPossibleSplit => '⚠ オーディオとビデオの別々のストリームが可能';

  @override
  String get catcatchSplitExplanation =>
      'これらのリソースは、同じビデオの個別のオーディオ ストリームとビデオ ストリームである場合があります。それらを組み合わせたり、1 つのストリームのみをダウンロードしたりできます。';

  @override
  String get catcatchAudioStream => '🎵 オーディオストリーム';

  @override
  String get catcatchVideoStream => '🎬 ビデオストリーム';

  @override
  String get catcatchMergeAudioVideo => 'オーディオとビデオを組み合わせる';

  @override
  String get catcatchVideoOnly => 'ビデオのみ';

  @override
  String get catcatchAudioOnly => '音声のみ';

  @override
  String get catcatchSegmentsPlaylistPreview => 'プレイリストを使用してセグメントをプレビューする';

  @override
  String get catcatchPreviewAudio => '音声をプレビューする';

  @override
  String get catcatchPreviewVideo => 'プレビュービデオ';

  @override
  String catcatchDuration(Object duration) {
    return '期間: $duration';
  }

  @override
  String get catcatchSegment => 'セグメント';

  @override
  String get catcatchPlaylist => 'プレイリスト';

  @override
  String get catcatchFullVideo => 'フルビデオ';

  @override
  String get catcatchSeparateTracks => '別々のトラック';

  @override
  String get catcatchPreviewPlaylistOnly => 'プレイリストを使用してプレビューする';

  @override
  String get catcatchPreviewUnsupported => 'プレビューはサポートされていません';

  @override
  String get catcatchUnknownFormat => '不明な形式';

  @override
  String get catcatchNeedPlaylistProcessing => 'プレイリストの処理が必要です';

  @override
  String get catcatchSpecialFormatDetected => '特殊なフォーマットが検出されました';

  @override
  String catcatchPlaylistInfo(Object format) {
    return 'このリソースはプレイリスト ($format) です。これを解析し、すべてのセグメントをダウンロードして、再生可能なビデオに結合する必要があります。';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return 'ダウンロードされたファイルは標準の MP4 ではなく、$format 形式です。内蔵の純粋な Dart リマックス エンジンは、MP4 に変換します (TS/FLV/EV1 は外部依存関係を必要としません)。';
  }

  @override
  String get catcatchContinueBeforeConfirm => 'フォーマット処理を確認する前にフローを再開する';

  @override
  String get catcatchAutoProcess => '自動処理';

  @override
  String get catcatchKeepOriginalFormat => '元の形式を維持する';

  @override
  String get catcatchResumeSupported => '履歴書対応';

  @override
  String get catcatchResumeUnsupported => 'このサイトは再開をサポートしていません';

  @override
  String get catcatchPauseDownload => 'ダウンロードを一時停止する';

  @override
  String get catcatchResumeDownload => 'ダウンロードを再開する';

  @override
  String get catcatchRestartDownload => '再度ダウンロードする';

  @override
  String get catcatchPendingFormatAction => 'フローリソースを待っています';

  @override
  String get quitDialogTitle => 'アプリを終了しますか?';

  @override
  String quitDialogRunningTasks(Object count) {
    return '$count タスクが実行中です。終了すると中断されます。辞めたいですか？';
  }

  @override
  String get quitDialogNoTasks => 'ストルームを辞めたいですか？';

  @override
  String get quitDialogCancel => 'キャンセル';

  @override
  String get quitDialogExit => 'やめる';

  @override
  String get searchPanelNewConversation => '新しい会話';

  @override
  String get searchPanelTitle => '会話を検索する';

  @override
  String get searchPanelHint => 'キーワードを入力してください...';

  @override
  String get searchPanelByTitle => 'タイトルを検索する';

  @override
  String get searchPanelByContent => 'コンテンツの検索';

  @override
  String searchPanelResults(Object count) {
    return '$countの結果';
  }

  @override
  String get searchPanelPrompt => 'キーワードを入力して検索します';

  @override
  String get searchPanelNoResults => '一致する会話が見つかりませんでした';

  @override
  String get topicItemNew => '新しいトピック';

  @override
  String get topicItemUnpin => '固定を解除する';

  @override
  String get topicItemPin => 'ピン';

  @override
  String get topicItemRename => '名前の変更';

  @override
  String get topicItemAutoName => '自動名前';

  @override
  String get topicItemDelete => '消去';

  @override
  String get galleryChoiceTitle => '画像ソースを選択してください';

  @override
  String get galleryChoiceDevice => 'デバイスギャラリー';

  @override
  String get galleryChoiceDeviceDescription => 'デバイス上の写真やビデオを閲覧する';

  @override
  String get galleryChoiceApp => 'アプリギャラリー';

  @override
  String get galleryChoiceAppDescription => 'アプリギャラリーから選択';

  @override
  String get appMediaUnreadable => 'ファイルを読み取れませんでした';

  @override
  String appMediaLoadError(Object error) {
    return 'ファイルをロードできませんでした: $error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return 'クリア ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return '完了 ($count)';
  }

  @override
  String get appMediaConfirmSelection => '終わり';

  @override
  String get appMediaEmptyFolder => 'このフォルダは空です';

  @override
  String get appMediaRoot => 'ルートフォルダーに移動します';

  @override
  String appMediaParentFolder(Object name) {
    return '戻る: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return '$count ファイルが選択されました';
  }

  @override
  String get chatAlbumPickerTitle => 'アプリアルバム';

  @override
  String get chatAlbumPickerEmpty => '利用可能な画像がありません';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 枚の画像を選択中',
      one: '$count 枚の画像を選択中',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => 'ファイルの選択';

  @override
  String get chatFilePickerTabText => '文章';

  @override
  String get chatFilePickerTabImages => '画像';

  @override
  String get chatFilePickerTabVideos => '動画';

  @override
  String get chatFilePickerTabAudio => 'オーディオ';

  @override
  String get chatFilePickerEmpty => '利用可能なファイルがありません';

  @override
  String get chatFilePickerLoadFailed => 'ファイルをロードできませんでした';

  @override
  String get chatVideoPickerTitle => 'アプリのビデオを選択する';

  @override
  String get chatVideoPickerEmpty => '利用できるビデオはありません';

  @override
  String get imagePreviewCrop => '作物';

  @override
  String get imagePreviewEdit => '編集';

  @override
  String get imagePreviewLoadFailed => '画像を読み込めませんでした';

  @override
  String runningElapsed(Object elapsed) {
    return '$elapsed のために実行中';
  }

  @override
  String get chatAttachmentFile => 'ファイルを添付する';

  @override
  String get chatAttachmentCamera => '写真を撮る';

  @override
  String get chatAttachmentDeviceGallery => 'デバイスギャラリー';

  @override
  String get chatAttachmentDeviceFiles => 'デバイスファイル';

  @override
  String get chatAttachmentAppFiles => 'アプリファイル';

  @override
  String fileManagerTodayTime(Object time) {
    return '今日 $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return '昨日 $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return '$days 日前 $time';
  }

  @override
  String get markdownGenerating => '生成中...';

  @override
  String get htmlPreview => 'プレビュー';

  @override
  String get htmlReturnToCard => 'カードに戻る';

  @override
  String get htmlGenerating => '生成中...';

  @override
  String get htmlFullscreen => '全画面表示';

  @override
  String get htmlViewCode => 'コードを表示する';

  @override
  String get codeScrollToBottom => '一番下までスクロール';

  @override
  String get codeSave => '保存';

  @override
  String get codeDisableWrap => 'ラッピングを無効にする';

  @override
  String get codeEnableWrap => '折り返しライン';

  @override
  String codeCopyFailed(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get codeCopied => 'コピーされました';

  @override
  String get codeCopy => 'コピー';

  @override
  String get codeEmptySave => 'コードが空なので保存できません';

  @override
  String get codeSaveTitle => 'コードを保存する';

  @override
  String codeSavedTo(Object path) {
    return '保存先: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get fileManagerCopy => 'コピー';

  @override
  String get fileManagerMove => '動く';

  @override
  String get fileManagerRename => '名前の変更';

  @override
  String get fileManagerExport => '輸出';

  @override
  String get fileManagerDelete => '消去';

  @override
  String get fileManagerAncestorFolders => '祖先フォルダー';

  @override
  String get fileManagerRoot => '根';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$countが選択されました';
  }

  @override
  String get fileManagerSelectAll => 'すべて選択';

  @override
  String get fileManagerRenameUndo => '最後のバッチの結果の名前変更と元に戻す';

  @override
  String fileManagerSortBy(Object field) {
    return '並べ替え ($field)';
  }

  @override
  String get fileManagerSortCreated => '作成日順に並べ替える';

  @override
  String get fileManagerSortModified => '変更日順に並べ替える';

  @override
  String get fileManagerSortName => '名前順に並べ替える';

  @override
  String get fileManagerSortSize => 'サイズごとに並べ替える';

  @override
  String get fileManagerListView => 'リストビュー';

  @override
  String get fileManagerThumbnailView => 'サムネイルビュー';

  @override
  String get fileManagerCreateFolder => 'フォルダーの作成';

  @override
  String get fileManagerRefresh => 'リストを更新する';

  @override
  String get fileManagerEmptyFolder => 'このフォルダは空です';

  @override
  String get fileManagerNoFiles => 'ファイルがありません';

  @override
  String get fileManagerBackRoot => 'ルートに戻る';

  @override
  String fileManagerBackFolder(Object name) {
    return '戻る: $name';
  }

  @override
  String get fileManagerMultiSelect => '複数選択';

  @override
  String get fileManagerOpen => '開ける';

  @override
  String get fileManagerPreview => 'プレビュー';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return '$files ファイル、$folders サブフォルダー';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return '$count サブフォルダー';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return '$count ファイル';
  }

  @override
  String get fileManagerEmptyFolderLabel => '空のフォルダー';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return 'ファイル「$name.$format」はすでに存在します';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return '名前の変更に失敗しました: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => '宛先フォルダーを選択してください';

  @override
  String get fileManagerAlreadyAtDestination => 'ファイルはすでに宛先にあります';

  @override
  String get fileManagerMoveNameConflict =>
      '移動先に同名のファイルが既に存在します。移動がキャンセルされました。';

  @override
  String fileManagerMoveFailed(Object error) {
    return '移動に失敗しました: $error';
  }

  @override
  String get fileManagerChooseCopyDestination => 'コピー先のフォルダーを選択してください';

  @override
  String fileManagerCopyFailed(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => '削除の確認';

  @override
  String get fileManagerDeleteFileConfirm => 'このファイルを削除しますか?この操作は元に戻すことができません。';

  @override
  String get fileManagerCancel => 'キャンセル';

  @override
  String fileManagerDeleteFailed(Object error) {
    return '削除に失敗しました: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere => 'フォルダーは既に宛先にあります。操作がキャンセルされました。';

  @override
  String get fileManagerFolderConflict =>
      '移動先に同名のフォルダが存在するか、選択したフォルダ内に移動先が存在します。操作がキャンセルされました。';

  @override
  String get fileManagerBatchDeleteTitle => '一括削除の確認';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '$count の選択したアイテムを削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return '一括削除に失敗しました: $error';
  }

  @override
  String get fileManagerExportConflict => '選択したファイルとフォルダーのエクスポート パスが競合します';

  @override
  String get fileManagerSelectedAlreadyThere =>
      '選択したファイルはすでに宛先にあります。移動がキャンセルされました。';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return '一括移動が失敗しました: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      '選択範囲には重複した名前のファイルが含まれています。コピーがキャンセルされました。それらを一度に 1 つずつコピーします。';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return '一括コピーに失敗しました: $error';
  }

  @override
  String get fileManagerClosedError => 'ファイルページは閉じています';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return '名前の一括変更に失敗しました: $error';
  }

  @override
  String get fileManagerFolderNameHint => 'フォルダ名を入力してください';

  @override
  String get fileManagerCreate => '作成する';

  @override
  String get fileManagerFolderExists => 'フォルダーはすでに存在します';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return 'フォルダーを作成できませんでした: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return 'フォルダー「$name」が作成されました';
  }

  @override
  String get fileManagerRenameFolderTitle => 'フォルダーの名前を変更する';

  @override
  String get fileManagerNewNameHint => '新しい名前を入力してください';

  @override
  String get fileManagerTargetFolderConflict =>
      '移動先に同名のフォルダが存在します。操作がキャンセルされました。';

  @override
  String get fileManagerMoveFolderTitle => 'フォルダを次の場所に移動します…';

  @override
  String get fileManagerCopyFolderTitle => 'フォルダーのコピー先…';

  @override
  String get fileManagerFolderSelfConflict =>
      '移動先に同名のフォルダーが存在するか、移動先がフォルダーそのものです。操作がキャンセルされました。';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return 'フォルダ「$name」を削除しますか? $count ファイルも削除されます。';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '空のフォルダー「$name」を削除しますか?';
  }

  @override
  String get fileManagerDeleteFolderTitle => 'フォルダーの削除を確認する';

  @override
  String fileManagerRefreshFailed(Object error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get fileManagerRefreshed => 'ファイルリストが更新されました';

  @override
  String get fileManagerRenameFileTitle => 'ファイル名の変更';

  @override
  String get fileManagerFormat => '形式';

  @override
  String get fileManagerFolderAtDestination => 'フォルダーはすでに宛先にあります';

  @override
  String get folderPickerTitle => 'フォルダーを選択してください';

  @override
  String get folderPickerExists => 'フォルダーはすでに存在します';

  @override
  String folderPickerCreateFailed(Object error) {
    return 'フォルダーを作成できませんでした: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return 'フォルダーリストを更新できませんでした: $error';
  }

  @override
  String get folderPickerInstruction => 'クリックして選択します。ダブルクリックしてフォルダーを開きます';

  @override
  String get folderPickerFileName => 'ファイル名';

  @override
  String get folderPickerFileNameHint => 'ファイル名を入力してください';

  @override
  String get folderPickerBack => '1 つ上のレベルに進みます';

  @override
  String folderPickerPath(Object path) {
    return 'ルート > $path';
  }

  @override
  String get folderPickerRoot => '根';

  @override
  String get folderPickerCurrentFolder => '現在のフォルダー';

  @override
  String get folderPickerSubfolders => 'サブフォルダー';

  @override
  String get folderPickerExistingFolders => '既存のフォルダー';

  @override
  String get folderPickerCreateNew => '新しいフォルダーを作成する';

  @override
  String get folderPickerFolderNameHint => 'フォルダ名を入力してください';

  @override
  String get folderPickerCancelCreate => '作成をキャンセルする';

  @override
  String get folderPickerCancel => 'キャンセル';

  @override
  String get folderPickerConfirm => '終わり';

  @override
  String batchRunReadFailed(Object error) {
    return 'ファイルリストを読み取れませんでした: $error';
  }

  @override
  String get batchRunPreparing => '準備中…';

  @override
  String get batchRunUndo => '元に戻す';

  @override
  String get batchRunRename => '名前の変更';

  @override
  String batchRunFailedAction(Object label) {
    return '$label できませんでした';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label $count アイテム';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed は成功、$failed は失敗、残りは $remaining';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return '失敗: $id → $name';
  }

  @override
  String get batchRunReportCopied => '実行レポートがコピーされました';

  @override
  String get batchRunCopyFailed => 'コピーに失敗しました。もう一度やり直してください。';

  @override
  String batchRunWorking(Object label) {
    return '$label…';
  }

  @override
  String get batchRunTitle => 'バッチ名の変更結果';

  @override
  String get batchRunStoppedRetain =>
      '停止すると完了したアイテムが保持されます。結果ページでそれらを元に戻すことができます。';

  @override
  String get batchRunFailedRemaining => '失敗した;残りのアイテムは処理されませんでした';

  @override
  String get batchRunUndoInfo =>
      '元に戻すと、この実行で完了した項目の元の名前が復元されます。ファイルリストが変更されている場合、元に戻すことは拒否されます。';

  @override
  String get batchRunUncertain =>
      '一部商品の状態が確認できなかった場合がございます。ファイルリストを確認してください。ファイルの上書きを避けるため、自動取り消しは使用できません。';

  @override
  String get batchRunUndoing => '元の名前を復元しています…';

  @override
  String get batchRunStopping => '停止中…';

  @override
  String get batchRunStopRemaining => '残りの項目を停止する';

  @override
  String get batchRunCopyReport => 'レポートのコピー';

  @override
  String batchRunUndoRemaining(Object count) {
    return '残りの $count を元に戻し続けます。';
  }

  @override
  String get batchRunUndoCompleted => '完了した名前変更を元に戻す';

  @override
  String get batchRunDone => '終わり';

  @override
  String get codeEditorTitle => 'パラメータ値を編集する';

  @override
  String get codeEditorFormat => '形式';

  @override
  String get codeEditorCancel => 'キャンセル';

  @override
  String get codeEditorConfirm => 'わかりました';

  @override
  String get codeEditorInvalidJson => '無効な JSON。保存する前に修正してください。';

  @override
  String get codeEditorParamPath => 'パラメータ名のパス (送信時にネストされた JSON に展開されます)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return '行 $line、列 $column: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'JSON 形式エラー: $message';
  }

  @override
  String get codeEditorInvalidFormat => '無効な JSON 形式';

  @override
  String get toolCallCompacted => '圧縮された';

  @override
  String get mermaidSaveEmpty => 'マーメイドコードが空です。保存するものは何もありません。';

  @override
  String mermaidFolderLoadFailed(String error) {
    return 'フォルダーをロードできませんでした: $error';
  }

  @override
  String get mermaidSaveTitle => '人魚図を保存';

  @override
  String get mermaidSaveHint => '.mmd ファイル用のフォルダーを選択または作成します';

  @override
  String get mermaidSaveFilenameHint => 'ファイル名を入力します（.mmdが自動的に追加されます）';

  @override
  String get mermaidFilenameEmpty => 'ファイル名を空にすることはできません';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return 'テキストストレージに保存: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get mermaidPrepareEngine => 'レンダリング エンジンを準備しています...';

  @override
  String get mermaidRetry => 'リトライ';

  @override
  String get batchRuleEmpty => '空にすることはできません';

  @override
  String get batchRuleNumber => '数字を入力してください';

  @override
  String get batchRulePositive => '0 より大きい数値を入力してください';

  @override
  String batchRuleMin(String min) {
    return '少なくとも $min である必要があります';
  }

  @override
  String batchRuleMax(String max) {
    return '$max 以下でなければなりません';
  }

  @override
  String get batchRulePrefix => 'プレフィックス';

  @override
  String get batchRuleSuffix => 'サフィックス';

  @override
  String get batchRuleStart => '始める';

  @override
  String get batchRuleStep => 'ステップ';

  @override
  String get batchRuleDigits => '数字';

  @override
  String get batchRuleSeparator => 'セパレータ';

  @override
  String get batchRuleRestartFolder => '各フォルダーの番号付けを再開します';

  @override
  String get batchRuleNumberHelp =>
      '番号はプレビューの順序に従います。除外される項目には番号は使用されません。ステップは負または 0 にすることができます。';

  @override
  String get batchRuleFind => '探す';

  @override
  String get batchRuleReplace => 'と置換します (削除するには空のままにします)';

  @override
  String get batchRuleCaseSensitive => '大文字と小文字を区別';

  @override
  String get batchRuleRegex => '正規表現';

  @override
  String get batchRuleFirstOnly => '最初の一致のみを置換する';

  @override
  String get batchRuleRegexHelp =>
      'キャプチャ グループ: \$1、\$2。完全一致: \$0;リテラル \$: \$\$。例: ^IMG_(\\d+)\$ → Photo_\$1';

  @override
  String get batchRuleFindRequired => 'このルールを有効にするには、検索するテキストを入力します。';

  @override
  String get batchRuleBeginning => '始まり';

  @override
  String get batchRuleEnd => '終わり';

  @override
  String get batchRulePosition => '位置';

  @override
  String get batchRuleInsertText => '挿入するテキスト';

  @override
  String get batchRuleBeforeChar => '文字 N の前';

  @override
  String get batchRulePositionHelp =>
      '位置は 1 から始まります。末尾を越えた値は追加されます。絵文字を組み合わせても 1 文字としてカウントされます。';

  @override
  String get batchRuleFromBeginning => '最初から';

  @override
  String get batchRuleFromEnd => '端から';

  @override
  String get batchRuleFromChar => '文字 N から始まる';

  @override
  String get batchRuleCount => 'カウント';

  @override
  String get batchRuleDeleteHelp =>
      '削除によって名前が空になった場合は、後の挿入ルールで実行前にテキストを追加する必要があります。';

  @override
  String get batchRuleUpper => '大文字';

  @override
  String get batchRuleLower => '小文字';

  @override
  String get batchRuleFirstUpper => '最初の文字を大文字にする';

  @override
  String get batchRuleTitleCase => '各単語を大文字にします';

  @override
  String get batchRuleTemplate => '新しい名前テンプレート';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return 'コース_${n}_$name';
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
    return '$nameオリジナル名・$nシーケンス・$folderフォルダ名\n$created 作成日 · $modified 変更日 · $ext 元の拡張子\n日付形式 YYYY-MM-DD。欠落している日付が報告されます。テンプレートはベース名全体を置き換えます。拡張子は自動的に保持されます。';
  }

  @override
  String get batchRuleTrim => '先頭と末尾のスペースをトリムする';

  @override
  String get batchRuleCollapseSpaces => '連続するスペースを 1 つのスペースに置き換えます';

  @override
  String get batchRuleActions => 'ルールアクション';

  @override
  String get batchRuleDuplicate => '重複ルール';

  @override
  String get batchRuleRemove => 'ルールの削除';

  @override
  String get batchRuleMoveUp => 'ルールを上に移動';

  @override
  String get batchRuleMoveDown => 'ルールを下に移動';

  @override
  String get batchDlgSavePreset => 'プリセットの保存';

  @override
  String get batchDlgPresetName => 'プリセット名';

  @override
  String get batchDlgPresetHint => 'ルールと順序は保存されますが、除外やマニュアル名は保存されません';

  @override
  String get batchDlgCancel => 'キャンセル';

  @override
  String get batchDlgSave => '保存';

  @override
  String get batchDlgOverwriteTitle => '既存のプリセットを上書きしますか?';

  @override
  String batchDlgOverwriteBody(String name) {
    return '「$name」のルールを更新します。';
  }

  @override
  String get batchDlgOverwrite => '上書き';

  @override
  String get batchDlgManagePresets => 'プリセットの管理';

  @override
  String get batchDlgNoPresets => '保存されたプリセットはありません';

  @override
  String get batchDlgDeletePreset => 'プリセットの削除';

  @override
  String get batchDlgDone => '終わり';

  @override
  String get batchDlgEditName => '名前を個別に編集する';

  @override
  String get batchDlgBaseName => 'ベース名';

  @override
  String get batchDlgOverrideHelp => 'この名前はルールの結果をオーバーライドします';

  @override
  String batchDlgExtensionRetained(String extension) {
    return '拡張子.$extensionは自動的に保持されます';
  }

  @override
  String get batchDlgConfirm => '確認する';

  @override
  String get batchDlgHelp => '説明書';

  @override
  String get batchDlgClose => '閉じる';

  @override
  String get batchDlgLoadPreset => 'プリセットのロード (ルールを置き換え、マニュアル名をクリアします)';

  @override
  String get batchDlgLoad => 'プリセットをロードする';

  @override
  String get batchDlgSaving => '保存中…';

  @override
  String get batchDlgReset => 'すべてのルールと含まれるアイテムをリセットします';

  @override
  String get batchDlgRuleInstructions =>
      'ルールは上から下へ続きます。それらをコピー、移動、または無効にします。ファイル拡張子は変更されません。';

  @override
  String get batchDlgSortName => '名前';

  @override
  String get batchDlgSortCreated => '作成されました';

  @override
  String get batchDlgSortModified => '修正済み';

  @override
  String get batchDlgSortSize => 'サイズ';

  @override
  String get batchDlgAscending => '上昇';

  @override
  String get batchDlgDescending => '降順';

  @override
  String get batchDlgFolderSort => 'フォルダーが最初に来ます。同じ名前はフォルダごとに分類されます。';

  @override
  String get batchDlgAddRule => '＋ ルールを追加';

  @override
  String get batchDlgMaxRules => '最大50のルール';

  @override
  String get batchDlgPreviewWorking =>
      'プレビューを計算中… ルールの編集を続行することも、キャンセルすることもできます。';

  @override
  String get batchDlgSearch => '元の名前、新しい名前、またはフォルダーを検索';

  @override
  String get batchDlgFilterAll => '全て';

  @override
  String get batchDlgFilterChanged => '変更されました';

  @override
  String get batchDlgFilterErrors => '問題';

  @override
  String get batchDlgFilterUnchanged => '変わらない';

  @override
  String get batchDlgFilterExcluded => '除外される';

  @override
  String get batchDlgParticipants => '同梱品を選ぶ';

  @override
  String get batchDlgIncludeAll => 'すべてを含める';

  @override
  String get batchDlgOnlyFiles => 'ファイルのみ';

  @override
  String get batchDlgOnlyFolders => 'フォルダーのみ';

  @override
  String get batchDlgExcludeAll => 'すべてを除外する';

  @override
  String get batchDlgScope => '同梱品';

  @override
  String get batchDlgCopyList => 'リストをコピーする';

  @override
  String get batchDlgConflictBlock => '名前の競合: ブロック実行';

  @override
  String get batchDlgConflictSuffix => '名前の競合: (2)、(3) を追加します。';

  @override
  String get batchDlgNoMatches => 'フィルターに一致する項目はありません';

  @override
  String get batchDlgRoot => '根';

  @override
  String get batchDlgFile => 'ファイル';

  @override
  String get batchDlgFolder => 'フォルダ';

  @override
  String batchDlgTargetFolder(String folder) {
    return '対象フォルダ：$folder';
  }

  @override
  String get batchDlgEditNameTooltip => '名前を個別に編集する';

  @override
  String get batchDlgRestoreNameTooltip => 'ルールによって生成された名前を復元する';

  @override
  String get batchDlgCopied => '完全なプレビュー リストをコピーしました (CSV)';

  @override
  String get batchDlgCopyFailed => 'コピーに失敗しました。もう一度やり直してください。';

  @override
  String get batchDlgHelpTitle => '名前変更命令のバッチ処理';

  @override
  String get batchDlgHelpDismiss => 'わかった';

  @override
  String get batchDlgRulesTab => 'ルール';

  @override
  String batchDlgPreviewTab(String count) {
    return 'プレビュー ($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return '$count アイテムの名前を変更';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      'プリセットをロードできませんでした。ルールは引き続き編集して実行できます。';

  @override
  String get batchDlgPreviewFailed => 'プレビューを計算できませんでした。ルールを調整して再試行してください。';

  @override
  String batchDlgSavedName(String name) {
    return '保存されたプリセット: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get batchDlgPresetWriteFailed => 'プリセットを保存できませんでした。';

  @override
  String batchDlgDeleteFailed(String error) {
    return '削除に失敗しました: $error';
  }

  @override
  String get batchDlgSavePresetFallback => 'プリセットの保存';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return 'プレビュー · $changes の変更 · $conflicts の問題 · $excluded の除外';
  }

  @override
  String get batchDlgInvalidInput => '無効なルール入力を修正します。プレビューにはまだそれらは含まれていません。';

  @override
  String get batchDlgConflictError => '競合または無効な名前がある場合は適用できません。ルールを調整します。';

  @override
  String get batchDlgManualNameStatus => 'マニュアル名';

  @override
  String get batchDlgPendingRename => '名前を変更する準備ができました';

  @override
  String get batchDlgCsvHeader => '元のパス、元の名前、ターゲットのパス、ステータス';

  @override
  String get batchDlgHelpBody =>
      '1. プリセットを選択するかルールを有効にし、ルールをコピーして必要に応じて順序を調整します。\n\n2. プレビューには、使用される名前が表示されます。検索とフィルターは表示のみに影響します。項目のチェックを外すと、その項目が除外され、番号付けが再計算されます。名前を個別に編集するか、ルールの結果を復元します。\n\n3. 実行する前にすべての問題を解決します。自動サフィックスは、ファイルを上書きせずに重複した名前を処理します。名前を交換するフォルダーの名前を別のバッチで変更します。\n\n4. 実行中に後の項目を停止できます。現在の項目が最初に終了します。結果ページには完了した変更が表示され、変更を元に戻すことができます。実行後にリストが変更された場合、元に戻すはブロックされます。\n\nこれにより変更されるのは名前とフォルダー パスのみです。ファイルの内容と拡張子は変更されません。親フォルダーの名前を変更しても、チェックされた子の名前が変更されることは妨げられず、親の名前を変更すると、その子も一緒に移動されます。';

  @override
  String batchDlgPreviewCount(String count) {
    return 'プレビュー ($count)';
  }

  @override
  String get batchBuiltinPhoto => '写真: 日付と番号';

  @override
  String get batchBuiltinCourse => 'コース: 一貫した名前と番号';

  @override
  String get batchBuiltinDownloads => 'ダウンロード: きれいな空白';

  @override
  String get taskListDetail => '詳細';

  @override
  String get taskListOwnershipChecking => 'タスクの所有権の確認';

  @override
  String get taskListOwnershipFailed => 'タスク フロー レコードを読み取れませんでした。アクションは使用できません';

  @override
  String get taskListViewFlow => 'タスクフローの表示';

  @override
  String get taskListPause => '一時停止';

  @override
  String get taskListClear => 'タスクをクリアする';

  @override
  String get taskListResume => '再開する';

  @override
  String get taskListRetry => 'リトライ';

  @override
  String get taskListDismissError => 'エラーを無視する';

  @override
  String get taskListRemove => 'リストから削除';

  @override
  String get taskListSynthesisErrorTitle => '合成エラーの詳細';

  @override
  String get taskListClose => '閉じる';

  @override
  String get taskListOriginalExchange => '元のリクエストとレスポンス';

  @override
  String get taskListOriginalRequest => '元のリクエスト本文:';

  @override
  String get taskListOriginalResponse => '元の応答本文:';

  @override
  String get taskFlowIoTypeText => '文章';

  @override
  String get taskFlowIoTypeAudio => 'オーディオ';

  @override
  String get taskFlowIoTypeVideo => 'ビデオ';

  @override
  String get taskFlowIoTypeImage => '画像';

  @override
  String get taskFlowIoTypeLink => 'リンク';

  @override
  String get taskFlowIoTypeFile => 'ファイル';

  @override
  String get taskFlowIoTypeAny => 'どれでも';

  @override
  String get mermaidZoomOut => 'ズームアウト';

  @override
  String get mermaidZoomIn => 'ズームイン';

  @override
  String get mermaidFullscreen => '全画面表示';

  @override
  String get mermaidSaveButton => '保存';

  @override
  String get mermaidSourceButton => 'ソースを見る';

  @override
  String get mermaidDiagramSemantic => '図を見る';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'CatCatch 子タスクの削除状態を保存できませんでした。もう一度やり直してください。';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      '合成子タスクの削除状態を保存できませんでした。もう一度やり直してください。';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      'バックグラウンドの子タスクの削除状態を保存できませんでした。もう一度やり直してください。';

  @override
  String get mathParseError => '数学解析エラー';

  @override
  String get mermaidEmptyPlaceholder => 'レンダリングする Mermaid コードがありません';

  @override
  String get mathClose => '閉じる';

  @override
  String get mermaidLoadTimeout =>
      'マーメイドの読み込みがタイムアウトしました。ネットワークを確認して、もう一度試してください。';

  @override
  String get mermaidCdnLoadFailed =>
      'cdn.jsdelivr.net にアクセスして Mermaid をロードできませんでした。';

  @override
  String get mermaidLoadingDiagram => '図を読み込み中…';

  @override
  String get mermaidEngineInitFailed =>
      'ダイアグラム レンダラーを初期化できませんでした。もう一度やり直してください。';

  @override
  String get mermaidPageTimeout => 'ページの読み込みがタイムアウトしました。もう一度やり直してください。';

  @override
  String get mermaidCodeLoadFailed => 'ダイアグラムコードをロードできませんでした。もう一度やり直してください。';

  @override
  String mermaidPageLoadFailed(String description) {
    return 'ページのロードに失敗しました: $description';
  }

  @override
  String get mermaidLoadingEngine => 'レンダリング エンジンを読み込み中…';

  @override
  String get mermaidRenderErrorTitle => '図のレンダリングエラー';

  @override
  String get taskFlowOutputVideoAudioDownstream =>
      'ビデオまたはオーディオ (ダウンストリームでフィルタリング)';

  @override
  String get taskFlowOutputUnknown => '未知';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label 停止: $completed は成功、$failed は失敗、$remaining は残り';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return '人魚のレンダリング エラー: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'マーメイド初期化エラー: $message';
  }

  @override
  String get mermaidResourceError => 'Mermaid ダイアグラム内のリソースのロードに失敗しました。';

  @override
  String get taskFlowParamRecognitionModel => '認識モデル';

  @override
  String get taskFlowParamSynthesisModel => '合成モデル';

  @override
  String get taskFlowParamSaveFolder => '保存フォルダー';

  @override
  String get taskFlowParamResourceSelection => 'リソースの選択';

  @override
  String get taskFlowParamOutputType => '出力タイプ';

  @override
  String get taskFlowParamVideoFolder => '動画保存フォルダ';

  @override
  String get taskFlowParamAudioFolder => '音声保存フォルダー';

  @override
  String get taskFlowParamExpectedDuration => '予想される期間';

  @override
  String get taskFlowParamVoice => '声';

  @override
  String get taskFlowParamSpeechRate => '発話速度';

  @override
  String get taskFlowParamAssistant => 'アシスタント';

  @override
  String get taskFlowHintResourceSelection =>
      '手動モードでは選択できます。自動モードは既存のルールに従います。安全な選択肢が 1 つある場合にのみ、曖昧な選択を自動的に行うかどうかを尋ねます。それ以外の場合は、確認のためにリソース リストが開きます。';

  @override
  String get taskFlowHintOutputType =>
      'ビデオまたはオーディオを明示的に選択します。次のブロックの入力タイプによってダウンストリーム フィルター リソースを追跡します。次のブロックが両方のタイプを受け入れるか、次のブロックがない場合は、両方のタイプが保持されます。';

  @override
  String get taskFlowHintExpectedDuration =>
      '動画の長さによってリソースをフィルターします。フィルタリングをスキップするには、空白のままにします。';

  @override
  String get taskFlowHintVoice => '声を選択してください。一致する合成モデルが自動的に選択されます。';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      'このブロック タイプはサポートされなくなりました。交換するか、このステップを削除してください。';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return '次のブロックには $requiredType が必要です。ダウンローダーはビデオまたはオーディオを出力できます。次のステップまたは出力ポリシーを変更します。';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source には任意のタイプがありますが、「$block」には明示的なテキスト、リンク、画像、オーディオ、ビデオ、またはファイル タイプが必要です。入力タイプを変更するか、ブロックを移動または置換するか、変更を元に戻します。';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$sourceには$actualTypeがありますが、「$block」には$requiredTypeが必要です。入力タイプを変更するか、ブロックを移動または置換するか、変更を元に戻します。';
  }

  @override
  String get fileManagerSortFieldCreated => '作成日';

  @override
  String get fileManagerSortFieldModified => '変更日';

  @override
  String get fileManagerSortFieldName => '名前';

  @override
  String get fileManagerSortFieldSize => 'サイズ';

  @override
  String get fileManagerSortDateNewest => '新しい順';

  @override
  String get fileManagerSortDateOldest => '古い順';

  @override
  String get fileManagerSortSizeLargest => '最大のものが最初';

  @override
  String get fileManagerSortSizeSmallest => '最小のものから順';

  @override
  String get catcatchStatusRunning => 'ランニング';

  @override
  String get catcatchStatusCompleted => '完了';

  @override
  String get catcatchStatusFailed => '失敗した';

  @override
  String get catcatchStatusPaused => '一時停止中';

  @override
  String get catcatchStatusWaiting => '待っている';

  @override
  String get catcatchStepFetching => 'Webページを取得しています';

  @override
  String get catcatchStepAnalyzing => 'メディアの分析';

  @override
  String get catcatchStepParsingPlaylist => 'プレイリストを解析しています';

  @override
  String get catcatchStepFiltering => '期間によるフィルタリング';

  @override
  String get catcatchStepUserSelecting => '選択を待っています';

  @override
  String get catcatchStepDownloading => 'ダウンロード中';

  @override
  String get catcatchStepConverting => '変換/結合';

  @override
  String get catcatchStepSaving => 'ローカルに保存する';

  @override
  String get bgStepConnectServer => 'サーバーに接続中';

  @override
  String get bgStepUploadImage => '画像のアップロード';

  @override
  String get bgStepWaitRecognition => '認識を待っています';

  @override
  String get bgStepParseResult => '解析結果';

  @override
  String get bgStepSaveFile => 'ファイルの保存';

  @override
  String get bgStepUploadAudio => '音声のアップロード';

  @override
  String get bgStepTranscribing => '文字起こし';

  @override
  String get bgStepReceiveResult => '受信結果';

  @override
  String get bgStepSeparateAudio => '音声を分離する';

  @override
  String get bgStepSaveToFile => 'ファイルに保存する';

  @override
  String get bgStepSendRequest => 'リクエストの送信';

  @override
  String get bgStepWaitReply => '返信を待っています';

  @override
  String get fileManagerSortNameAscending => 'AからZまで';

  @override
  String get fileManagerSortNameDescending => 'ZからAへ';

  @override
  String get taskFlowValidationNoSteps => 'このタスク フローにはステップがありません。まずブロックを追加します。';

  @override
  String get taskFlowValidationInputRequired =>
      'このタスク・フローを実行するには、少なくとも 1 つの入力を追加します。';

  @override
  String get taskFlowValidationFlowRemoved => 'このタスク フローは削除されました。もう一度選択してください。';

  @override
  String get taskFlowValidationInputTypeChanged =>
      '初期入力タイプが変更されました。再度実行入力を選択します。';

  @override
  String get taskFlowValidationSnapshotMissing =>
      'この古いレコードには実行スナップショットがありません。最新の構成を使用して再試行してください。';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      'アシスタント モデルが見つからないか、使用できません。チャット ページでモデルを選択するか、アシスタントのデフォルト モデルを設定します。';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      '保存されたステップ ファイルが見つからないか、空であるか、読み取り不能です。タスク・フローを再度実行します。';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      'このブロック タイプはサポートされなくなりました。このステップを置き換えるか削除します。';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return '次のブロックには $requiredType が必要です。ダウンローダーはオーディオまたはビデオを出力できます。次のステップまたは出力ポリシーを変更します。';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return '「$block」には「$parameter」が必要です。ブロック設定で設定します。';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return 'レガシー モデルの選択には確認が必要です。 「$block」の設定でモデルを選択し直してください。';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return 'モデルが見つからないか、プロバイダーから入手できません。 「$block」設定で再度選択し、プロバイダーの URL とキーを確認します。';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return 'アシスタントが見つからないか、削除されました。 「$block」設定で再度選択してください。';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      'アシスタント モデルが削除されているか、そのプロバイダー構成が利用できません。アシスタント設定でモデルを再度選択してください。';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return 'リソース選択ポリシーまたは出力タイプが無効です。 「$block」設定で再度選択してください。';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return '出力タイプが無効です。 「$block」設定で再度選択してください。';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return 'リソース選択ポリシーが無効です。 「$block」設定で再度選択してください。';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return '入力 $index: ファイルが見つからないか、空であるか、読み取り不能です。もう一度選択してください。';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return '$index を入力: 有効​​な HTTP または HTTPS リンクを入力します。';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return '入力 $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules => '最大 50 個のルールが許可されます。';

  @override
  String get batchRuleValidationDigits => '桁数は 1 ～ 12 である必要があります。';

  @override
  String get batchRuleValidationNumberRange =>
      '開始番号とステップは±999,999,999以内でなければなりません。';

  @override
  String get batchRuleValidationReplacementLength => '置換ルールが長すぎます。';

  @override
  String get batchRuleValidationRegex => '正規表現が無効です。';

  @override
  String get batchRuleValidationDeleteIndex => '削除位置は 1 から開始する必要があります。';

  @override
  String get batchRuleValidationInsertLength => '挿入されたテキストが長すぎます。';

  @override
  String get batchRuleValidationTemplateNumber =>
      '無効なテンプレート番号設定: 桁数は 1 ～ 12、開始/ステップは ±999,999,999 以内である必要があります。';

  @override
  String get batchRuleValidationTemplateLength => 'テンプレートが長すぎます。';

  @override
  String get batchRuleValidationTemplateVariable =>
      '不明なテンプレート変数または閉じられていない中括弧。';

  @override
  String get batchRuleTypeNumber => '番号付けを追加する';

  @override
  String get batchRuleTypeReplace => '検索して置換する';

  @override
  String get batchRuleTypeInsert => 'テキストの挿入';

  @override
  String get batchRuleTypeDelete => '文字を削除する';

  @override
  String get batchRuleTypeCase => '大文字と小文字を変更する';

  @override
  String get batchRuleTypeTemplate => '名前テンプレート';

  @override
  String get batchRuleTypeCleanup => 'クリーンなホワイトスペース';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return '$index を入力: テキストを入力するか、ファイルを選択します。';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return '$index を入力: 画像は 20 MB を超えています。小さい画像を選択してください。';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return '$index を入力: 添付ファイルが 10 MB を超えています。より小さいファイルを選択してください。';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return '$index を入力: ファイルは $actualType ですが、$requiredType が必要です。別のファイルを選択してください。';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return '$index を入力: アシスタント チャットは SVG 画像添付をサポートしていません。 PNG または JPEG に変換します。';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return '$index を入力: アシスタント チャットは $mime の画像添付をサポートしていません。 PNG、JPEG、GIF、または WebP に変換します。';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return '$index を入力: アシスタント チャットは $mime オーディオ添付ファイルをサポートしません。 MP3、WAV、または M4A に変換します。';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return '入力 $index: この Anthropic チャット形式は $type 添付ファイルをサポートしません。このメディアをサポートするアシスタントを選択してください。';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return '入力 $index: この Anthropic チャット形式は、画像と PDF の添付ファイルのみをサポートします。サポートされているファイルを選択してください。';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return '入力 $index: アシスタント チャットは 10 MB 未満の画像を圧縮できませんでした。小さい画像を選択してください。';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return '入力 $index: テキスト添付ファイルは有効な UTF-8 ではありません。変換して再試行してください。';
  }

  @override
  String get assistantParamValueTypeString => '弦';

  @override
  String get assistantParamValueTypeNumber => '番号';

  @override
  String get assistantParamValueTypeBoolean => 'ブール値';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields => 'プロバイダー名、API URL、キーは必須です。';

  @override
  String get providerJsonSizePositive => 'リクエストの JSON サイズは正の MiB 値である必要があります。';

  @override
  String get providerCustomParamRequired => 'カスタムパラメータ名と値は必須です。';

  @override
  String providerParamNameInvalid(String name) {
    return 'パラメータ名が無効です (ドットで区切られたセグメントを空にすることはできません): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return 'パラメータはすでに存在します: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return 'パラメータ「$name」のデフォルト値が無効です JSON: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return 'パラメータ「$name」の数値オプションを空にすることはできません。';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return 'パラメータ「$name」の値は有効な数値ではありません: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      '他の推論パラメーターを有効にする前に、推論の切り替えを完了してください。';

  @override
  String providerReasoningError(String error) {
    return '推論パラメータエラー: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return '推論パラメータとカスタム パラメータは同じ名前です: $name';
  }

  @override
  String get providerMaxTokensMissing => '最大出力トークンが有効になっていますが、値が入力されていません。';

  @override
  String get providerMaxTokensPositive => '最大出力トークンは正の整数である必要があります。';

  @override
  String get providerSeedInteger => 'ランダム シードは整数でなければなりません。';

  @override
  String get providerNotConfigured => '未設定';

  @override
  String get providerAudioChunkingTitle => 'オーディオチャンキング';

  @override
  String get providerAudioChunkingHint =>
      'スマート チャンキングは音声と候補カットを分析し、文末を優先します。チャンクは重なりません。';

  @override
  String get providerChunkingMode => 'チャンク方式';

  @override
  String get providerChunkNone => 'チャンキングなし';

  @override
  String get providerChunkSmart => 'スマートチャンキング (推奨)';

  @override
  String get providerChunkFixedDuration => '固定期間チャンク';

  @override
  String get providerChunkFixedSize => '固定サイズのチャンク';

  @override
  String get providerCompressionTitle => '圧縮符号化';

  @override
  String get providerCompressionHint =>
      '有効にすると、一般的なフォールバックは最初に完全な WAV を圧縮します。エンコードされたファイルまたはリクエスト本文が依然として制限を超える場合、ソース PCM はチャンク化されてエンコードされます。';

  @override
  String get providerCompressionMode => '圧縮方式';

  @override
  String get providerCompressionNone => 'なし（そのまま送信）';

  @override
  String get providerCompressionAdpcm => 'ADPCM (約 4 倍圧縮)';

  @override
  String get providerCompressionFlac => 'FLAC (ロスレス、約2倍、推奨)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM、非可逆 4:1 圧縮。 Pure Dart の実装。音声品質は文字起こしに適しています。';

  @override
  String get providerCompressionFlacDescription =>
      '純粋な Dart で実装されたロスレス FLAC 圧縮。サイズが約半分に減ります。';

  @override
  String get providerCompressionWavDescription => '圧縮はありません。 WAVファイルとして送信します。';

  @override
  String get providerLlmParams => 'LLMパラメータ';

  @override
  String get providerEnabledParamsHelp => '有効なパラメータは、API リクエストのデフォルトとして送信されます。';

  @override
  String get providerTemperatureLabel => '温度';

  @override
  String get providerTemperatureHelp => '出力のランダム性を制御します。値が大きいほど創造的になります。';

  @override
  String get providerTopPHelp => '単語選択の累積確率を制御する核サンプリング パラメーター。';

  @override
  String get providerFrequencyPenaltyLabel => '周波数ペナルティ';

  @override
  String get providerFrequencyPenaltyHelp =>
      '繰り返される単語を減らします。負の値を指定すると、繰り返しが増加します。';

  @override
  String get providerPresencePenaltyLabel => 'プレゼンスペナルティ';

  @override
  String get providerPresencePenaltyHelp =>
      '新しいトピックを奨励します。負の値を指定すると、前のトピックに戻ることが奨励されます。';

  @override
  String get providerMaxOutputTokensLabel => '最大出力トークン';

  @override
  String providerOptionalExample(String example) {
    return 'オプション、例: $example';
  }

  @override
  String get providerResponseTokensHelp => '応答ごとに生成されるトークンの最大数。';

  @override
  String get providerSeedLabel => 'ランダムシード';

  @override
  String get providerSeedHelp => '出力を再現できるようにするには、これを設定します。';

  @override
  String get providerChunkSmartDescription =>
      '音声と候補のカットを分析し、重複のない文末や長い沈黙を優先します。デフォルト: 最小 20 秒 / 目標 45 秒 / 最大 60 秒。一般的なフォールバックによってのみ使用されます。圧縮チャンクは PCM WAV のみをサポートします。';

  @override
  String get providerChunkDurationDescription =>
      'N 秒ごとに分割します (デフォルトでは 60 秒)。シンプルですが、会話が途切れる可能性があります。一般的なフォールバックによってのみ使用されます。圧縮チャンクは PCM WAV のみをサポートします。';

  @override
  String get providerChunkSizeDescription =>
      '最初はオーディオ データ サイズによって分割され、次にエンコードされたファイルとリクエスト本文のサイズによって絞り込まれます。一般的なフォールバックによってのみ使用されます。圧縮チャンクは PCM WAV のみをサポートします。';

  @override
  String get providerChunkNoneDescription =>
      'チャンク化はありません。完全圧縮後に制限を超えると、ファイルは拒否されます。';

  @override
  String get providerNameLabel => 'プロバイダ名';

  @override
  String get providerNameHint => 'プロバイダー名を入力してください';

  @override
  String get providerApiUrlLabel => 'API URL';

  @override
  String get providerApiUrlHint => '完全な API エンドポイント URL を入力します';

  @override
  String providerApiKeyHint(String hint) {
    return 'ヒント: $hint';
  }

  @override
  String get providerEndpointTypeLabel => 'エンドポイントの種類';

  @override
  String get providerEndpointOpenAi => 'OpenAI 互換 (チャット補完)';

  @override
  String get providerEndpointAnthropic => '人間形式 (メッセージ API)';

  @override
  String get providerAnthropicEndpointHelp =>
      '公式の Anthropic Messages API 形式 (x-api-key ヘッダー) を使用します。 API URL の例: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      '公式の OpenAI Chat Completions 互換形式 (Bearer ヘッダー) を使用します。 API URL の例: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault => 'デフォルトのリクエスト JSON サイズ';

  @override
  String get providerUseAppDefault => 'アプリのデフォルトを使用するには空のままにしてください';

  @override
  String get providerModelJsonBudgetHelp =>
      'モデルはこの値をオーバーライドできます。プロバイダーもモデルも設定していない場合、デフォルトは 20 MiB です。';

  @override
  String get providerRequestParamsHelp =>
      'リクエストでは、有効なプロバイダーとモデルのパラメーターをすべて使用します。名前が重複する場合は、モデルの値が優先されます。';

  @override
  String get providerUploadSettings => 'アップロード設定';

  @override
  String get providerUploadMethodHelp => '音声のアップロード方法とサイズ制限はプロバイダーによって異なります。';

  @override
  String get providerUploadMethod => 'アップロード方法';

  @override
  String get providerMultipart => 'マルチパート（一般）';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => '最大アップロードサイズ';

  @override
  String get providerFallbackStrategy => 'フォールバック戦略';

  @override
  String get providerFallbackMethod => 'フォールバック方式';

  @override
  String get providerPreprocessing => 'オーディオの前処理';

  @override
  String get providerPreprocessingHelp =>
      '音声ファイルのサイズを削減しますが、リサンプリングによって音声が変化し、文字起こしの精度に影響する場合があります。';

  @override
  String get providerPreprocessingMethod => '前処理方法';

  @override
  String get providerUploadMultipartHelp =>
      'マルチパート/フォームデータの直接アップロード。リクエスト本文には、オーディオ、フォーム フィールド、およびマルチパート境界が含まれます。';

  @override
  String get providerUploadBase64Help =>
      'JSON で Base64 を送信します。これにより、一部のプロバイダーのマルチパート固有の制限を回避できます。 Base64 拡張フィールドと JSON フィールドはアップロード制限にカウントされます。';

  @override
  String get providerUploadUrlHelp =>
      'プロバイダーがダウンロードするパブリック URL を指定します。非常に大きなファイルをサポートします (例: Together AI 1 GB)。';

  @override
  String get providerUploadBudgetHelp =>
      'この値は、生のオーディオ フォールバックをトリガーし、最終的なリクエスト本文を制限します。アプリは、生のオーディオ、エンコードされたファイル、アップロード サイズをチェックします。マルチパートにはフォーム フィールドと境界が含まれます。 Base64 JSON にはエンコード拡張とフィールドが含まれます。デフォルトの 25 MB は、OpenAI オーディオ API の制限と一致します。';

  @override
  String get providerFallbackTriggerHelp =>
      '未加工の音声または完全なリクエスト本文が制限を超えるとトリガーされます。特定のフォールバック (Base64) は、一般的なフォールバック (圧縮/チャンク) よりも優先されます。';

  @override
  String get providerFallbackNone => 'なし（即時拒否）';

  @override
  String get providerFallbackSpecific => '特定のフォールバック (Base64)';

  @override
  String get providerFallbackGeneric => '一般的なフォールバック (圧縮/チャンク化)';

  @override
  String get providerFallbackAll => 'すべて試してみる (推奨)';

  @override
  String get providerFallbackSpecificHelp =>
      'Base64 JSON を試してください。 Base64 拡張フィールドと JSON フィールドを含むリクエスト本文が制限に適合する場合にのみ送信します。';

  @override
  String get providerFallbackGenericHelp =>
      '有効にすると、最初に完全な WAV が圧縮されます。それでも制限を超えており、チャンク化が有効な場合は、ソース PCM を分割して各チャンクをエンコードします。 PCM WAVのみです。';

  @override
  String get providerFallbackAllHelp =>
      'まず、リクエスト本文の制限内で Base64 を試してください。次に、有効になっている場合は、完全な WAV を圧縮します。それでも制限を超えており、チャンク化が有効な場合は、ソース PCM を分割して各チャンクをエンコードします。 PCM WAVのみです。';

  @override
  String get providerFallbackRejectHelp =>
      '制限を超えた場合はファイルを拒否します。フォールバックは試行しないでください。';

  @override
  String get providerPreprocessNone => 'なし';

  @override
  String get providerPreprocessResample => 'WAVのリサンプリング（16kHzモノラル）';

  @override
  String get providerPreprocessResampleHelp =>
      '16 kHz にリサンプルしてモノラルに変換します。音声が変化する場合があります。';

  @override
  String get providerPreprocessNoneHelp => '前処理は必要ありません。そのまま送信します。';

  @override
  String get assistantDefaultsScopeHelp =>
      'デフォルトのモデルとツールは、このアシスタントの下で作成された新しい会話にのみ適用されます。既存の会話は独自の設定を保持します。ツール出力の切り捨てはすべての会話に適用されます。';

  @override
  String get assistantDefaultModelTitle => 'デフォルトモデル';

  @override
  String get assistantDefaultModelHelp =>
      '新しい会話に使用されるモデル。会話が選択できるようにするには、未設定のままにします。';

  @override
  String get assistantNoDefault => '未設定';

  @override
  String get assistantNoModelsAvailable =>
      '利用可能なモデルはありません。 [設定] で LLM プロバイダーを構成します。';

  @override
  String get assistantDefaultToolsTitle => 'デフォルトで有効なツール';

  @override
  String get assistantDisabledToolsHelp => '無効になったツールは、新しい会話では自動的に有効になりません。';

  @override
  String get assistantUnconfiguredToolsHelp =>
      'デフォルトのツールは設定されていません。新しい会話では、すべてのツールが自動的に有効になります。';

  @override
  String get assistantEnableAll => 'すべて有効にする';

  @override
  String get assistantDisableAll => 'すべて無効にする';

  @override
  String get assistantNoToolsAvailable => '利用可能なツールがありません';

  @override
  String get assistantTruncateToolOutput => 'ツール出力の切り捨て';

  @override
  String get assistantTruncateToolOutputHelp =>
      'モデルに送信される前の各ツールの結果の最大文字数。このアシスタントの下でのすべての会話に適用されます。';

  @override
  String get assistantEnableTruncation => '切り捨てを有効にする';

  @override
  String assistantTruncatedTo(String count) {
    return '長い結果は $count 文字に切り詰められます';
  }

  @override
  String get assistantSendFullResult => '完全な結果を送信します (50 KB のストレージ制限の対象となります)';

  @override
  String get assistantMaxCharacters => '最大文字数';

  @override
  String get assistantCharactersNotTokens => '単位: 文字 (トークンではありません)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return 'デフォルト: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return '有効範囲: $minimum ～ $maximum 文字';
  }

  @override
  String get assistantNewConversationPreview => '新しい会話のプレビュー';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled / $total 有効';
  }

  @override
  String get assistantAllToolsAutoEnabled => 'すべてのツールは自動的に有効になります (構成されていません)。';

  @override
  String get assistantMoreActions => 'さらなるアクション';

  @override
  String get assistantChooseEmoji => '絵文字を選択してください';

  @override
  String get assistantNameLabel => 'アシスタント名';

  @override
  String get assistantDescriptionOptional => '説明 (オプション)';

  @override
  String get assistantSelectionTitle => 'アシスタントを選択してください';

  @override
  String get assistantMarketTooltip => 'アシスタントマーケットプレイス';

  @override
  String get assistantDefaultPrompt =>
      'あなたは役に立つ AI アシスタントです。ユーザーの質問に明確かつ有益に答えます。';

  @override
  String get assistantCreateNew => 'アシスタントの作成';

  @override
  String get assistantEmptyState => 'まだアシスタントはいません。まずは作成してください。';

  @override
  String get assistantCreate => '作成する';

  @override
  String get assistantReorderHint => '長押ししてドラッグしてアシスタントの順序を変更します';

  @override
  String get assistantNewNameHint => 'アシスタント名を入力してください';

  @override
  String get assistantNewDescriptionHint => 'このアシスタントの機能を簡単に説明します';

  @override
  String get assistantDeleteTitle => 'アシスタントの削除';

  @override
  String assistantDeleteConfirmation(String name) {
    return 'アシスタント「$name」を削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String get assistantEditTitle => '編集アシスタント';

  @override
  String get assistantBasicTab => '基本設定';

  @override
  String get assistantParametersTab => 'パラメータ';

  @override
  String get assistantDefaultsTab => 'デフォルト';

  @override
  String get assistantAddCustomParameter => 'カスタムパラメータの追加';

  @override
  String get assistantEditCustomParameter => 'カスタムパラメータの編集';

  @override
  String get assistantParameterName => 'パラメータ名';

  @override
  String get assistantParameterNameHint => '例えばtop_k または Provider.only';

  @override
  String get assistantParameterNameInvalid =>
      'パラメータ名が無効です (ドットで区切られたセグメントを空にすることはできません)';

  @override
  String get assistantParameterType => 'タイプ';

  @override
  String get assistantValue => '価値';

  @override
  String get assistantTrueFalseHint => '真か偽か';

  @override
  String get assistantNumberHint => '数字を入力してください';

  @override
  String assistantJsonHint(String example) {
    return '例えば$example';
  }

  @override
  String get assistantValueHint => '値を入力してください';

  @override
  String get assistantCancel => 'キャンセル';

  @override
  String get assistantSave => '保存';

  @override
  String get assistantParamOverrideHelp =>
      '有効にすると、アシスタント パラメータがモデル パラメータをオーバーライドします。無効にすると、モデル パラメーターが使用されます。';

  @override
  String get assistantTemperature => '温度';

  @override
  String get assistantMaxTokens => '最大トークン数';

  @override
  String get assistantMaxToolCalls => '最大ツール呼び出し数';

  @override
  String assistantRounds(String count) {
    return '$countラウンド';
  }

  @override
  String get assistantUnlimited => '無制限';

  @override
  String get assistantStreamOutput => 'ストリーム出力';

  @override
  String get assistantFrequencyPenalty => '周波数ペナルティ';

  @override
  String get assistantPresencePenalty => 'プレゼンスペナルティ';

  @override
  String get assistantRandomSeed => 'ランダムシード';

  @override
  String get assistantNotSet => '未設定';

  @override
  String get assistantSeedValue => 'シード値';

  @override
  String get assistantIntegerSeedHint => '整数シードを入力してください';

  @override
  String get assistantWebSearch => 'ウェブ検索';

  @override
  String get assistantAddParameter => 'パラメータの追加';

  @override
  String get assistantNoCustomParameters => 'カスタムパラメータはありません';

  @override
  String get assistantRoundsLabel => 'ラウンド';

  @override
  String get modelCreateTitle => 'モデルの追加';

  @override
  String get modelEditTitle => 'モデルの編集';

  @override
  String get modelDiscardTitle => '変更を破棄しますか?';

  @override
  String get modelDiscardBody => '未保存の変更があります。それらを破棄しますか？';

  @override
  String get modelNameLabel => '機種名';

  @override
  String get modelNameHint => '表示名を入力します (オプション)';

  @override
  String get modelIdLabel => 'モデルID';

  @override
  String modelIdExample(String id) {
    return '例えば$id';
  }

  @override
  String get modelIdRequired => 'モデルIDは必須です。';

  @override
  String get modelCustomParamRequired => 'カスタムパラメータ名とデフォルト値は必須です。';

  @override
  String modelParamDuplicate(String name) {
    return 'パラメータはすでに存在します: $name';
  }

  @override
  String modelParamReserved(String name) {
    return '予約済み OCR パラメータ名: $name';
  }

  @override
  String get modelParamName => 'パラメータ名';

  @override
  String get modelParamDefaultValue => 'デフォルトのパラメータ値';

  @override
  String get modelParamDelete => 'パラメータの削除';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return 'パラメータ「$name」のデフォルト値が無効です JSON: $value';
  }

  @override
  String get modelAddParameter => 'パラメータの追加';

  @override
  String get modelNoCustomParams => 'カスタムパラメータはありません';

  @override
  String get modelBasicSettings => '基本設定';

  @override
  String get modelDiscardCancel => 'キャンセル';

  @override
  String get modelSave => '保存';

  @override
  String get modelUnsavedMaxTokens => '最大出力トークンは有効ですが、値がありません。';

  @override
  String get modelMaxTokensPositive => '最大出力トークンは正の整数である必要があります。';

  @override
  String get modelSeedInteger => 'ランダム シードは整数でなければなりません。';

  @override
  String get modelContextLengthRequired => 'コンテキストの長さは必須です。';

  @override
  String get modelContextLengthPositive => 'コンテキストの長さは正の整数である必要があります。';

  @override
  String get modelAsrLanguageCode => '言語コード（言語）';

  @override
  String get modelAsrLanguageHint => '例えばzh、ja、ja';

  @override
  String get modelAsrLanguageHelp => 'ISO-639-1 言語コード。自動検出のために空のままにしておきます。';

  @override
  String get modelTemperature => '温度';

  @override
  String get modelTemperatureHelp => '出力のランダム性を制御します。より低い値をお勧めします。';

  @override
  String get modelAsrPrompt => 'プロンプト';

  @override
  String get modelAsrPromptHint => 'コンテキスト プロンプトを入力します (オプション)';

  @override
  String get modelAsrPromptHelp => '専門用語のリストなど、文字起こしの精度を向上させるためのコンテキストを提供します。';

  @override
  String get modelAsrParams => 'ASRパラメータ';

  @override
  String get modelEnabledParamsHelp => '有効なパラメータは、API リクエストのデフォルトとして送信されます。';

  @override
  String get modelAsrResponseFormat => '応答フォーマット';

  @override
  String get modelAsrResponseHelp => '返される文字起こしの形式。';

  @override
  String get modelAsrTimestampGranularity => 'タイムスタンプの粒度';

  @override
  String get modelAsrVerboseHelp =>
      'response_format が verbose_json の場合にのみ使用できます。';

  @override
  String get modelNoTrim => 'トリミングなし';

  @override
  String get modelAudioTrimTitle => 'オーディオトリミング';

  @override
  String get modelAudioTrimHelp => '音声をトリミングする方法を選択します。';

  @override
  String get modelDeleteTrimPreset => 'トリムプリセットを削除';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return 'トリムプリセット「$name」を削除しますか?';
  }

  @override
  String get modelAddTrimPreset => 'カスタムトリムを追加する';

  @override
  String get modelPlayTestAudio => 'テスト音声を再生する';

  @override
  String get modelPlayingTestAudio => '遊んでいます...';

  @override
  String get modelParamExists => 'パラメータはすでに存在します';

  @override
  String get asrModelIdExample => '例えばささやき-1';

  @override
  String get asrPromptLabel => 'プロンプト';

  @override
  String get asrResponseFormatJson => 'json – JSON';

  @override
  String get asrResponseFormatText => 'テキスト – プレーンテキスト';

  @override
  String get asrResponseFormatSrt => 'srt – 字幕';

  @override
  String get asrResponseFormatVtt => 'vtt – 字幕';

  @override
  String get asrResponseFormatVerbose => 'verbose_json – 詳細な JSON (タイムスタンプを含む)';

  @override
  String get asrVerboseTimestampHelp =>
      'verbose_json を選択すると、以下のタイムスタンプ粒度オプションが有効になります。';

  @override
  String get asrTimestampSegment => 'セグメント – セグメントレベル';

  @override
  String get asrTimestampWord => 'word – 単語レベル';

  @override
  String get asrWordTimestampHelp =>
      'ワードレベルのタイムスタンプは、セグメントレベルのタイムスタンプよりも精度が低い場合があります。';

  @override
  String get reasoningAddOptionValue => 'オプション値を追加';

  @override
  String get reasoningEditOptionValue => 'オプション値を編集する';

  @override
  String get reasoningOptionExample => '例えば低、中、高';

  @override
  String get reasoningOptionSelectionHelp =>
      'チップをタップして選択またはクリアします。選択された値が送信されます。ドラッグして並べ替えます。プロバイダー値は削除できませんが、クリアすることで非表示にすることができます。';

  @override
  String get reasoningAddOption => 'オプションを追加';

  @override
  String get reasoningCurrentProvider => '現在: プロバイダー';

  @override
  String get reasoningCurrentModel => '現在: モデルカスタム';

  @override
  String get reasoningAddEffortValue => '推理努力値を加算';

  @override
  String get reasoningEffortExample => '例えばマックス、ウルトラ、ディープ';

  @override
  String get reasoningAddToggle => '推論の追加トグル';

  @override
  String get reasoningToggle => '推論トグル';

  @override
  String get reasoningResetParameter => 'このパラメータをリセットします';

  @override
  String get reasoningDisableToggle => '推論を無効にするトグル';

  @override
  String get reasoningEnableToggle => '推論を有効にするトグル';

  @override
  String reasoningParameterNameSource(String source) {
    return 'パラメータ名($source)';
  }

  @override
  String get reasoningNameExample => '例えば思考タイプ、推論';

  @override
  String get reasoningBooleanHelp =>
      'ブールパラメータには値は必要ありません。チャット パネルにはオン/オフ スイッチがあります。';

  @override
  String get reasoningOnValue => '有効時の値';

  @override
  String get reasoningOnExample => '例えば有効、真';

  @override
  String get reasoningOffValue => '無効時の値';

  @override
  String get reasoningOffExample => '例えば無効、偽';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return '有効にすると、「$onValue」を送信します。無効の場合、「$offValue」を送信します。';
  }

  @override
  String get reasoningAddEffort => '推論の努力を追加する';

  @override
  String get reasoningFillToggleFirst => '最初に推論トグルを完了してください';

  @override
  String get reasoningFillToggleBeforeEffort =>
      '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get reasoningAddValue => '付加価値';

  @override
  String get reasoningJsonValue => 'JSON値';

  @override
  String reasoningJsonExample(String example) {
    return '例えば$example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      'チップをタップして選択またはクリアします。選択した値がチャット推論パネルに表示されます。ドラッグして並べ替えます。プロバイダー値は削除できませんが、非表示にすることはできます。';

  @override
  String get reasoningAddParameter => '推論パラメータを追加する';

  @override
  String get reasoningToggleIncomplete => '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get llmContextLength => 'コンテキストの長さ';

  @override
  String get llmContextHint => 'コンテキストの長さを入力してください';

  @override
  String get llmContextHelp => 'モデル (トークン) のコンテキスト ウィンドウの最大サイズ。';

  @override
  String get llmReasoningParams => '推論パラメータ';

  @override
  String get llmReasoningHelp =>
      'チャットの推論パラメータを構成します。推論トグルは、パラメータ名とオン/オフ値を制御します。推論努力値を追加し、並べ替えて、チャット パネルに表示する値を選択します。このページが開くと、プロバイダーの値が同期されます。これらの設定は、モデル パラメーターの利用可能性を制御します。チャットパネルの切り替えは個別に管理されます。';

  @override
  String get llmAddReasoningParam => '推論パラメータを追加する';

  @override
  String get llmCustomEndpointType => 'カスタムエンドポイントタイプ';

  @override
  String get llmInheritEndpointType => '無効にした場合は、プロバイダー設定のエンドポイント タイプを使用します。';

  @override
  String get llmEndpointType => 'エンドポイントの種類';

  @override
  String get llmEndpointOpenAi => 'OpenAI 互換 (チャット補完)';

  @override
  String get llmEndpointAnthropic => '人間形式 (メッセージ API)';

  @override
  String get llmEndpointHelp =>
      'エンドポイントのタイプはプロバイダー API URL と一致する必要があります。これを変更すると、このモデルとの新しい会話に使用される形式に影響します。';

  @override
  String get llmTopPHelp => '核サンプリングパラメータ。単語選択の累積確率を制御します。';

  @override
  String get llmFrequencyPenaltyLabel => '周波数ペナルティ';

  @override
  String get llmFrequencyPenaltyHelp => '繰り返しを減らします。負の値を指定すると増加します。';

  @override
  String get llmPresencePenaltyLabel => 'プレゼンスペナルティ';

  @override
  String get llmPresencePenaltyHelp => '新しいトピックを奨励します。負の値は繰り返しを促します。';

  @override
  String get llmMaxTokensHint => 'オプション、例: 4096';

  @override
  String get llmTokensPerResponse => '応答ごとに生成される最大トークン。';

  @override
  String get llmSeedLabel => 'ランダムシード（シード）';

  @override
  String get llmSeedHint => 'オプション、例: 42';

  @override
  String get llmSeedHelp => 'これを設定すると出力が再現可能になります。';

  @override
  String get llmInheritedCustomHelp =>
      'プロバイダーのカスタム パラメーターがここに表示され、このページが開くたびに同期されます。';

  @override
  String get llmBooleanParamHelp => 'ブールパラメータには値は必要ありません。';

  @override
  String get modelContextReq => 'コンテキストの長さは必須です。';

  @override
  String get modelContextPositive => 'コンテキストの長さは正の整数である必要があります。';

  @override
  String modelParamNameInvalid(String name) {
    return '無効なパラメータ名 (ドットで区切られたセグメントを空にすることはできません): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return 'パラメータ「$name」 $valueLabel は有限数でなければなりません: $value';
  }

  @override
  String get modelReasoningIncomplete => '他の推論パラメーターを有効にする前に、推論の切り替えを完了してください。';

  @override
  String get modelReasoningOptionsRequired => '少なくとも 1 つのオプション値を推論パラメータに追加します。';

  @override
  String modelReasoningError(String error) {
    return '推論パラメータエラー: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return '推論パラメータが重複しています: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return '推論とカスタム パラメーターは $name という名前を共有します。';
  }

  @override
  String get modelSeedRequired => 'ランダム シードは有効ですが空です。';

  @override
  String get ocrParamsTitle => 'OCRパラメータ';

  @override
  String get ocrParamsHelp =>
      'OpenAI 互換のビジョン Chat Completions 形式を使用します。以下のパラメータはオプションです。未設定または無効なパラメータは送信されません。 API でサポートされている場合は、以下のプロバイダー固有のパラメーターを追加します。';

  @override
  String get ocrRequestSizeOverride => 'JSON サイズのオーバーライドをリクエストする';

  @override
  String get ocrInheritProvider => 'プロバイダー設定を継承するには空のままにしておきます';

  @override
  String get ocrBudgetDefault =>
      '空の場合、プロバイダー設定を継承します。プロバイダーに値がない場合、デフォルトは 20 MiB です。';

  @override
  String ocrBudgetValue(String size) {
    return '空の場合、プロバイダー設定 ($size MiB) を継承します。プロバイダーに値がない場合、デフォルトは 20 MiB です。';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return 'トリム $direction $seconds';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return '最初の $seconds をトリムします';
  }

  @override
  String get audioTrimNone => 'オーディオをトリミングしないでください';

  @override
  String get trimNameLabel => 'トリムメソッド名 *';

  @override
  String get trimNameHint => '例えばサイレントトリミング';

  @override
  String get trimDurationLabel => 'トリム期間 (秒) *';

  @override
  String get trimDurationHint => '例えば0.123';

  @override
  String get trimNameAndDurationRequired => '名前と期間は必須です。';

  @override
  String get trimDurationInvalid => '有効な正の期間を入力します。';

  @override
  String get testAudioHostMissing => 'ホストが構成されていません。';

  @override
  String get testAudioKeyMissing => 'キーが設定されていません。';

  @override
  String testAudioContentTypeError(String contentType) {
    return '応答 Content-Type は $contentType であり、オーディオではありません。';
  }

  @override
  String get testAudioEmpty => 'サーバーは空の音声データを返しました。';

  @override
  String testAudioTimeoutConnection(String details) {
    return '接続がタイムアウトしました。ネットワークを確認してください。 $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return '受信がタイムアウトしました。サーバーの応答が遅すぎました。 $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return 'リクエストはキャンセルされました。 $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return 'ネットワークエラー: $message';
  }

  @override
  String get testAudioNoBody => '応答本文がありません';

  @override
  String testAudioCorsHelp(String details) {
    return 'サーバーに接続できません。 Web では、CORS または不正な API URL が原因である可能性があります。プロバイダー API URL と、サーバーがクロスオリジン要求を許可しているかどうかを確認してください。 $details';
  }

  @override
  String get trimModelNameHint =>
      '表示と識別のためのわかりやすい名前。 「GPT-4o ミニTTS」。同じプロバイダーのモデルを区別するには、異なる名前を使用します。';

  @override
  String get trimModelIdHelp =>
      'API 呼び出しで使用される一意の識別子。 「gpt-4o-mini-tts」。ベンダーが提供するモデル ID と一致する必要があります。';

  @override
  String get ttsVoiceRangeTitle => '音量範囲';

  @override
  String get ttsMinVolume => '最小音量';

  @override
  String get ttsMaxVolume => '最大音量';

  @override
  String get ttsSpeedRangeTitle => '速度範囲';

  @override
  String get ttsMinSpeed => '最低速度';

  @override
  String get ttsMaxSpeed => '最高速度';

  @override
  String get ttsMaxAudioLength => 'リクエストあたりの最大オーディオ長 *';

  @override
  String get ttsAudioLengthHint => '例えば1000';

  @override
  String get ttsNoVoices => '音声はありません。タップして編集します。';

  @override
  String get ttsInstructionSupported => 'モデルは命令パラメータをサポートしています';

  @override
  String get ttsInstructionHelp =>
      '有効にすると、TTS リクエストに口調、感情、話す速度などの指示を含めることができます。';

  @override
  String get ttsStreamSupported => 'ストリーミング出力をサポートするモデル';

  @override
  String get ttsStreamHelp =>
      'このモデルをストリーミング シナリオで有効にします。有効にする前に、モデルがストリーミングをサポートしていることを確認してください。';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return 'パラメータ「$name」は true または false である必要があります: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired =>
      'リクエストごとの最大オーディオ長が必要です。正の整数を入力してください。';

  @override
  String get asrLanguageExample => '例えばzh、ja、ja';

  @override
  String get llmReasoningFullHelp =>
      '推論トグルは推論を送信するかどうかを制御し、パラメータ名とオン/オフ値を定義できます。推論努力パラメータが 1 つあります。値を選択し、ドラッグして順序を変更します。選択した値がチャット推論パネルに表示されます。以下に他の推論パラメーターを追加します。パラメーター名は、thing.type などのドット表記をサポートしており、ネストされた JSON オブジェクトになります。このページが開くと、プロバイダー推論パラメータが同期されます。ここのスイッチはモデルパラメータを制御します。チャット推論の切り替えは別のものです。';

  @override
  String get llmTemperatureHelp => '出力のランダム性を制御します。値が大きいほど創造的になります。';

  @override
  String get llmBooleanValueHelp => 'ブールパラメータには値は必要ありません。';

  @override
  String get reasoningDisableEffort => '推論の努力を無効にする';

  @override
  String get reasoningEnableEffort => '推論の努力を可能にする';

  @override
  String get ocrJsonSizePositive => 'リクエストの JSON サイズは正の MiB 値である必要があります。';

  @override
  String ttsRangePair(String kind) {
    return '$kind の最小値と最大値の両方を入力するか、両方を空のままにします。';
  }

  @override
  String get ttsEditTrimTitle => 'カスタムトリムを編集する';

  @override
  String ttsVoicesCount(String count) {
    return '音声 ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return 'リクエスト形式で生成: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'MCP サーバー名を入力してください。';

  @override
  String get mcpStdioCommandRequired => 'stdio モードにはコマンドが必要です。';

  @override
  String get mcpSseUrlRequired => 'SSE モードには URL が必要です。';

  @override
  String get mcpEditServerTitle => 'MCPサーバーの編集';

  @override
  String get mcpCreateServerTitle => '新しい MCP サーバー';

  @override
  String get mcpUnsavedChangesTitle => '未保存の変更';

  @override
  String get mcpUnsavedChangesConfirm => '未保存の変更があります。それらを破棄しますか？';

  @override
  String get mcpTransportType => '輸送タイプ';

  @override
  String get mcpServerName => 'サーバー名';

  @override
  String get mcpServerNameHint => 'MCP サーバー名を入力してください';

  @override
  String get mcpCommand => '指示';

  @override
  String get mcpCommandExample => '例: npx';

  @override
  String get mcpArguments => '引数';

  @override
  String get mcpArgumentsHint =>
      '引数はカンマで区切ります。例: -y、@modelcontextprotocol/server-filesystem、/tmp';

  @override
  String get mcpSseUrlExample => '例: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'APIキー';

  @override
  String get mcpApiKeyHint => 'API キーを入力します (オプション)';

  @override
  String get mcpShowKey => 'キーを表示';

  @override
  String get mcpHideKey => 'キーを隠す';

  @override
  String get mcpDescriptionHint => 'この MCP サーバーの説明を入力します (オプション)';

  @override
  String get mcpStdioDescription =>
      'stdio はローカルの子プロセスを MCP サーバーとして起動し、標準入出力を通じて通信します。ローカルツールに推奨されます。';

  @override
  String get mcpSseDescription =>
      'SSE は、HTTP SSE 経由でリモート MCP サーバーに接続します。リモートサービスに推奨されます。';

  @override
  String get mcpLocalStdio => 'ローカル (stdio)';

  @override
  String get mcpRemoteSse => 'リモート (SSE)';

  @override
  String get mcpSaving => '保存中…';

  @override
  String get providerTestSafetyNote =>
      'このテストは、選択したサービスに実際のリクエストを送信します。 MCP は読み取り専用のツール/リスト メソッドのみを呼び出します。 HTTP と Web 検索は 1 つのクエリを実行します。 Todo はデフォルトでリストを読み取ります。現在のデータを保護するには、todos パラメータを省略するか、null に設定します。';

  @override
  String get providerDeleteConfigTitle => '構成の削除';

  @override
  String get providerDeleteConfigConfirm => 'このプロバイダー構成とそのすべてのモデルを削除しますか?';

  @override
  String get providerCreateGroup => '新しいグループ';

  @override
  String get providerEditGroup => 'グループの編集';

  @override
  String get providerGroupName => 'グループ名';

  @override
  String get providerGroupNameExists => 'この名前のグループはすでに存在します。';

  @override
  String get providerDeleteGroup => 'グループの削除';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return '「$groupName」を削除すると、その構成が「その他の MCP サービス」に移動されます。';
  }

  @override
  String get providerMoveToGroup => 'グループに移動';

  @override
  String get providerUnnamed => '(名前なし)';

  @override
  String get providerHttpSearch => 'HTTP検索';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'HTTP ツール: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return 'ローカル (stdio): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return 'リモート (SSE): $url';
  }

  @override
  String get providerServices => 'サービス構成';

  @override
  String get providerServicesDescription =>
      'リモート接続、ローカル標準入出力、HTTP 検索をグループごとに管理';

  @override
  String get providerCreateGroupAction => '新しいグループ';

  @override
  String get providerGroupEmpty => 'このグループには構成がありません。 「追加」を選択して項目を追加します。';

  @override
  String get providerBuiltinTools => '内蔵ツール';

  @override
  String get providerBuiltinToolsDescription =>
      'Stroom が提供するローカル ツール インターフェイス。 Web 検索はそのサービス グループにリストされています。';

  @override
  String get providerBuiltinToolInterface => '内蔵ツールインターフェイス';

  @override
  String get providerViewInterface => 'ビューインターフェイス';

  @override
  String get providerConfigTitle => '構成';

  @override
  String get providerNotFound => 'プロバイダーが見つかりません';

  @override
  String get providerConfigurationHeading => 'プロバイダーの構成';

  @override
  String get providerBuiltinWebSearchEmpty =>
      '組み込みの Web 検索は、Google、Bing、Baidu をサポートします。そのモデル ツール名は web_search です。';

  @override
  String get providerNoConfigsAdd => 'プロバイダーの構成はまだありません。 「追加」を選択して作成します。';

  @override
  String get providerNoHost => '(ホストが設定されていません)';

  @override
  String get providerServicesAndTools => 'サービスとツール';

  @override
  String get providerManageServicesDescription =>
      'MCP サーバー、HTTP 検索、Stroom 組み込みツールを管理します。';

  @override
  String get providerNoServices => 'サービス構成はまだありません';

  @override
  String get providerAddServiceDescription =>
      'MCP サービスまたは HTTP 検索インターフェイスを追加して、アシスタントで使用します。';

  @override
  String get providerAddService => 'サービスの追加';

  @override
  String get providerBuiltinBadge => '内蔵';

  @override
  String get providerBuiltinTtsName => 'TTSプロバイダー';

  @override
  String get providerBuiltinLlmName => 'LLM プロバイダー';

  @override
  String get providerBuiltinOcrName => 'OCRプロバイダー';

  @override
  String get providerBuiltinAsrName => '音声認識プロバイダー';

  @override
  String get providerBuiltinMcpName => 'MCPプロバイダー';

  @override
  String get providerBuiltinSearchGroupName => '検索';

  @override
  String get providerBuiltinMcpServicesGroupName => 'その他のMCPサービス';

  @override
  String get providerConnectivityTest => '接続テスト';

  @override
  String get providerMoveGroupTooltip => 'グループに移動';

  @override
  String get providerDeleteTooltip => '構成の削除';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 件',
      one: '# 件',
      zero: '項目はありません',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => 'グループアクション';

  @override
  String get providerEditGroupAction => 'グループの編集';

  @override
  String get providerDeleteGroupAction => 'グループの削除';

  @override
  String get providerAddItem => 'アイテムの追加';

  @override
  String get providerMcpMasterLabel => 'MCPサーバー';

  @override
  String get providerMcpMasterDescription =>
      'MCP サーバーと組み込みの検索ツールをアシスタントとチャットで使用できるかどうかを制御します。';

  @override
  String get providerEnabled => '有効';

  @override
  String get providerDisabled => '無効';

  @override
  String get providerEditSettings => 'プロバイダー設定を編集する';

  @override
  String get providerModelList => 'モデル';

  @override
  String get providerNoModels => 'まだモデルがありません';

  @override
  String get providerDeleteModel => 'モデルの削除';

  @override
  String get providerDeleteModelConfirm => 'このモデルを削除してもよろしいですか?';

  @override
  String get providerEditConfig => '構成の編集';

  @override
  String providerCreateNamedConfig(String entryName) {
    return '新しい $entryName 構成';
  }

  @override
  String get toolHttpSearchType => '接続タイプ: HTTP 検索';

  @override
  String toolInterface(String name) {
    return 'ツールインターフェイス: $name';
  }

  @override
  String get toolParameterDefinitions => 'パラメータの定義';

  @override
  String get toolHttpAddress => 'HTTPエンドポイントURL';

  @override
  String get toolInvalidHttpUrl => '有効な HTTP または HTTPS URL を入力します。';

  @override
  String get toolBuiltinType => '接続タイプ：ストルーム内蔵ツール';

  @override
  String get toolBuiltinEnableHelp =>
      'アシスタントのデフォルトのツール設定で、アシスタントに対してこのツールを有効にします。';

  @override
  String get mcpSseUrlLabel => 'SSE URL';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return 'モデルID: $modelId';
  }

  @override
  String get providerValueNotSet => '(未設定)';

  @override
  String get providerApiKeyInputHint => 'APIキーを入力してください';

  @override
  String get providerSettingsTitle => 'プロバイダーの構成';

  @override
  String get providerBasicInfoTab => '基本情報';

  @override
  String get providerParameterSettingsTab => 'パラメータ設定';

  @override
  String get providerOptionValuesReorderHelp =>
      'オプションの値 (ハンドルを押したままドラッグして並べ替えます)';

  @override
  String providerOptionIndexLabel(String index) {
    return 'オプション $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return '例えば$example';
  }

  @override
  String get providerDeleteOptionTooltip => '削除オプション';

  @override
  String get providerAddOption => 'オプションを追加';

  @override
  String get providerAddCustomParam => 'パラメータの追加';

  @override
  String get providerNoCustomParams => 'カスタムパラメータはまだありません';

  @override
  String get providerParamNameLabel => 'パラメータ名';

  @override
  String get providerParamDefaultValueLabel => 'デフォルトのパラメータ値';

  @override
  String get providerBooleanParamNoValue =>
      'ブールパラメータには値は必要ありません。チャット パネルにはオン/オフの切り替えがあります。';

  @override
  String get providerReasoningParamsHeading => '推論パラメータ';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return '推論トグルは、チャットでの推論をオンまたはオフにします。パラメータ名とオン/オフ値を選択します。必須の名前とオプションの選択肢を使用して、1 つの推論努力パラメーターを構成できます。名前のみを入力すると、モデル設定によって値が提供されます。他の推論パラメータを追加するには、下のボタンを使用します。パラメータ名はドットのネストをサポートしています。たとえば、$parameterName は $jsonExample に展開されます。';
  }

  @override
  String get providerAddReasoningParam => '推論パラメータを追加する';

  @override
  String get providerAddReasoningToggle => '推論の追加トグル';

  @override
  String get providerReasoningToggle => '推論トグル';

  @override
  String get providerDeleteReasoningToggle => '推論の削除トグル';

  @override
  String providerParamNameHint(String examples) {
    return '例えば$examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      'ブールパラメータには値は必要ありません。チャット パネルにはオン/オフの切り替えがあります。';

  @override
  String get providerToggleOnValueLabel => 'オン値';

  @override
  String get providerToggleOffValueLabel => 'オフ値';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return '推論がオンの場合は、「$onValue」を送信します。オフの場合は「$offValue」を送信します。';
  }

  @override
  String get providerAddReasoningEffort => '推論の努力を追加する';

  @override
  String get providerDeleteReasoningEffort => '推論努力パラメータの削除';

  @override
  String get providerReasoningEffortLockedHint =>
      '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get providerJsonValueLabel => 'JSON値';

  @override
  String get providerReasoningOptionsHelp =>
      'オプション値 (オプション。パラメータ名のみを入力した場合、モデル設定によって値が提供されます)。ハンドルを押したままドラッグして並べ替えます。';

  @override
  String get providerParamNameNestedLabel => 'パラメータ名 (ドットのネストをサポート)';

  @override
  String get providerToggleEffortPrerequisite =>
      '推論の労力を構成する前に、推論の切り替えを完了してください。';

  @override
  String get providerToggleRequiredHint => 'まず推論の切り替えを完了してください。';

  @override
  String get providerDeleteCustomParam => 'パラメータの削除';

  @override
  String get modelSaveSuccess => 'モデルが保存されました';

  @override
  String get modelSaving => '保存中…';

  @override
  String modelOriginalError(String error) {
    return '元のエラー: $error';
  }

  @override
  String get paramTypeStringLabel => '弦';

  @override
  String get paramTypeNumberLabel => '番号';

  @override
  String get paramTypeBooleanLabel => 'ブール値';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return 'サポートされていないタイプ: $type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return 'パラメータ「$name」はサポートされていないタイプ「$type」を使用しています。サポートされているタイプに置き換えるか、保存する前にパラメータを削除してください。';
  }

  @override
  String get paramTypeStringHint => '例えば陽気な';

  @override
  String get paramTypeNumberHint => '例えば0.8';

  @override
  String get paramTypeBooleanHint => '例えば真実';

  @override
  String get paramTypeJsonHint => '例えば';

  @override
  String get ankiPageTitle => 'アンキのフラッシュカード';

  @override
  String get ankiStatsTooltip => '研究統計';

  @override
  String get ankiBrowseCardsTooltip => 'カードを閲覧する';

  @override
  String get ankiStatsTotalCards => 'カードの合計';

  @override
  String get ankiStatsNewCards => '新しいカード';

  @override
  String get ankiStatsLearning => '学ぶ';

  @override
  String get ankiStatsDueForReview => '審査期限中';

  @override
  String get ankiStatsReviewHistory => 'レビュー履歴';

  @override
  String get ankiStatsLearningProgress => '研究の進捗状況';

  @override
  String get ankiStatsReviewRate => 'レビュー率';

  @override
  String get ankiBrowserSearchHint => 'カードを検索...';

  @override
  String get ankiBrowserEmpty => 'カードなし';

  @override
  String get ankiSyncTooltip => 'AnkiWeb同期';

  @override
  String get ankiNewDeckTooltip => '新しいデッキ';

  @override
  String ankiDeckLoadError(String error) {
    return 'デッキのロードに失敗しました: $error';
  }

  @override
  String get ankiEmptyDecksTitle => 'まだデッキがありません';

  @override
  String get ankiEmptyDecksDescription => 'デッキを作成して勉強を始める';

  @override
  String get ankiNewDeckTitle => '新しいデッキ';

  @override
  String get ankiDeckNameHint => 'デッキ名';

  @override
  String get ankiCreateDeck => '作成する';

  @override
  String get ankiRenameDeck => 'デッキ名の変更';

  @override
  String get ankiConfirm => 'わかりました';

  @override
  String get ankiDeleteDeckTitle => 'デッキの削除';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '「$deckName」とそのすべてのカードを削除しますか?';
  }

  @override
  String get ankiAddCardTitle => 'カードを追加';

  @override
  String get ankiNoteTypeLabel => 'ノートの種類';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return 'テキスト (削除を $clozeSyntax でマーク)';
  }

  @override
  String get ankiFrontQuestionHint => 'フロント（質問）';

  @override
  String get ankiBackExtraLabel => '裏・番外編';

  @override
  String get ankiTagsLabel => 'タグ（スペースで区切る）';

  @override
  String get ankiTagsHint => '例: 数学物理学';

  @override
  String get ankiAdd => '追加';

  @override
  String get ankiStatNew => '新しい';

  @override
  String get ankiStatLearning => '学ぶ';

  @override
  String get ankiStatReview => 'レビュー';

  @override
  String get ankiAddCardAction => 'カードを追加';

  @override
  String get ankiRenameAction => '名前の変更';

  @override
  String get ankiDeleteAction => '消去';

  @override
  String get ankiNoCardContent => 'カード内容なし';

  @override
  String get ankiStudy => '勉強';

  @override
  String get ankiWhiteboardTooltip => 'ホワイトボード';

  @override
  String get ankiFrontLabel => 'フロント';

  @override
  String get ankiBackLabel => '戻る';

  @override
  String get ankiShowAnswer => '答えを表示';

  @override
  String get ankiRatingAgain => 'また';

  @override
  String get ankiRatingHard => '難しい';

  @override
  String get ankiRatingGood => '良い';

  @override
  String get ankiRatingEasy => '簡単';

  @override
  String get ankiNoCardsToStudy => '現在学習するカードはありません';

  @override
  String get ankiNoCardsHint => '新しいカードを追加するか、後で戻ってください';

  @override
  String get ankiBack => '戻る';

  @override
  String get ankiSyncPageTitle => 'アンキ同期';

  @override
  String get ankiSyncChooseMode => '同期モードを選択してください';

  @override
  String get ankiSyncModeHelp =>
      'ログイン状況はサービスごとに個別に保存されます。モードを切り替えても、データはマージまたは上書きされません。';

  @override
  String get ankiSyncSelfHostedMode => '自己ホスト型サーバー';

  @override
  String get ankiSyncServerAddress => 'サーバーアドレス';

  @override
  String get ankiSyncServerHelp =>
      'リモートのセルフホスト サーバーは HTTPS を使用する必要があります。ローカル アドレスには HTTP が許可されます。サーバーは Anki sync v10 をサポートする必要があり、証明書の検証はデフォルトで有効になっています。';

  @override
  String get ankiSyncCustomCaTitle => 'カスタム CA 証明書 (オプション)';

  @override
  String get ankiSyncCustomCaHelp => 'サーバーが自己署名証明書を使用する場合にのみこれを入力します';

  @override
  String get ankiSyncOfficialHelp =>
      '公式の AnkiWeb 同期サービスを使用します。パスワードはログイン時にのみ送信され、Stroom には保存されません。';

  @override
  String ankiSyncConnected(String service) {
    return '$serviceに接続';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return '$serviceに接続されていません';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return '$serviceにログインします';
  }

  @override
  String get ankiSyncCheckServerStatus => 'サーバーのステータスを確認する';

  @override
  String get ankiSyncLogout => 'ログアウト';

  @override
  String get ankiSyncBothWays => '双方向同期';

  @override
  String get ankiSyncOverwriteServer => 'サーバーデータをローカルデータに置き換えます';

  @override
  String get ankiSyncReplaceLocal => 'ローカルデータをサーバーデータに置き換えます';

  @override
  String get ankiSyncHelp =>
      '双方向同期は、増分コレクションの変更をマージし、メディア ファイルを転送します。スキーマのバージョンが異なる場合は、完全なアップロードまたはダウンロードを選択します。完全なダウンロードが失敗すると、元のコレクションとメディア ディレクトリの復元が試行されます。';

  @override
  String get ankiSyncStatusRestored => '安全に保存されたログインセッションを復元しました';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      '保存されたログイン セッションを読み取れませんでした。再度ログインしてください。';

  @override
  String get ankiSyncInvalidServerUrl =>
      'サーバー アドレスは HTTPS URL である必要があります。 HTTP はローカル ループバック アドレスに対してのみ許可されます。ユーザー情報とクエリパラメータは許可されません。';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return '設定が保存されていません: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      'サーバーアドレスが変更されました。続行するには再度ログインしてください。';

  @override
  String get ankiSyncStatusVerifyingLogin => 'ログインを確認しています…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      'ログインに成功しました。パスワードは保存されていませんでした。同期キーは暗号化されて保存されました。';

  @override
  String get ankiSyncLoginSuccessPromptTitle => 'ログイン成功';

  @override
  String get ankiSyncLoginSuccessPromptMessage => 'コレクションを今すぐ同期しますか？';

  @override
  String get ankiSyncLoginSuccessPromptSync => '今すぐ同期';

  @override
  String get ankiSyncLoginSuccessPromptLater => '続行';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      'ログインは成功しましたが、同期キーを安全に保存できませんでした。このページを閉じた後、再度ログインする必要があります。';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return 'ログイン失敗: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'AnkiWeb にログインする';

  @override
  String get ankiSyncLoginSelfHosted => '自己ホスト型サーバーにログインする';

  @override
  String get ankiSyncEmailOrUsername => 'メールアドレス / ユーザー名';

  @override
  String get ankiSyncEmailOrUsernameRequired => 'メールアドレスまたはユーザー名を入力してください';

  @override
  String get ankiSyncPassword => 'パスワード';

  @override
  String get ankiSyncPasswordRequired => 'パスワードを入力してください';

  @override
  String get ankiSyncLogin => 'ログイン';

  @override
  String get ankiSyncStatusPreparingServerSettings => 'サーバー設定を準備しています…';

  @override
  String get ankiSyncStatusReadingCollection => 'サーバーの収集ステータスを読み取り中…';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      '接続されました。サーバー コレクションが空です。';

  @override
  String get ankiSyncStatusConnectedStatusRead =>
      '接続されました。サーバーのステータスが読み取られました。';

  @override
  String get ankiSyncStatusUpgradeClient => 'このサーバーには新しい同期クライアントが必要です。';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return 'ステータスチェックに失敗しました: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload => 'アップロード設定を準備しています…';

  @override
  String get ankiSyncOverwriteServerConfirmTitle =>
      'サーバーのコレクションをローカルのコレクションに置き換えますか?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      'サーバー コレクションはローカル データに完全に置き換えられます。 Stroom はまずローカル データベースのバックアップを保存します。\n\nメディア ファイルは、サーバーのメディア リストに従って両方向で同期されます。';

  @override
  String get ankiSyncOverwriteServerAction => 'サーバーコレクションを置き換える';

  @override
  String get ankiSyncStatusBackingUpUploading => 'コレクションのバックアップとアップロード中…';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return 'サーバーはローカル コレクションを受け入れました。メディア同期が完了しました: アップロードされた $uploaded ファイル、ダウンロードされた $downloaded、削除された $deleted.$backup サーバーのステータスをもう一度確認してください。';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return 'ローカルバックアップ: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      'サーバー コレクションは置き換えられましたが、メディアの同期は完了しませんでした。';

  @override
  String get ankiSyncStatusUploadFailed => 'アップロードに失敗しました:';

  @override
  String get ankiSyncStatusPreparingDownload => 'ダウンロード設定を準備しています…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle =>
      'ローカルコレクションをサーバーコレクションに置き換えますか?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      'ローカル コレクションはサーバー データに置き換えられます。 Stroom はまずローカル データベースのバックアップを保存します。\n\nサーバー メディアがローカル メディアを置き換え、不足しているファイルがダウンロードされます。ステップが失敗した場合、またはアプリが途中で終了した場合、Stroom は次回デッキを開く前にローカルのコレクションとメディアを復元します。';

  @override
  String get ankiSyncReplaceLocalAction => 'ローカルデータを置き換える';

  @override
  String get ankiSyncStatusDownloadingValidating => 'コレクションをダウンロードして検証しています…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return 'ローカル コレクションは置き換えられ、SQLite チェックに合格しました。メディアの同期が完了しました: ダウンロードされた $downloaded ファイル、アップロードされた $uploaded、削除された $deleted.$backup サーバーのステータスをもう一度確認してください。';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => '同期を準備中…';

  @override
  String get ankiSyncStatusMergingChanges => 'コレクションの変更をマージしています…';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'コレクションの変更がマージされました。メディア ファイルを同期しています…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return '$notes メモ、$cards カード、および $reviews レビュー レコードが追加または更新されました';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges => 'マージするコレクションの変更はありません';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return '双方向同期が完了しました: $collection;メディアはアップロード $uploaded、ダウンロードされた $downloaded、削除された $deleted。';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'コレクションの変更はマージされましたが、メディアの同期は完了しませんでした:';

  @override
  String get ankiSyncStatusSyncIncomplete => '同期が完了しませんでした:';

  @override
  String get ankiSyncStatusClearingLogin => 'ログインセッションをクリアしています…';

  @override
  String get ankiSyncStatusLoggedOut => 'ログアウトしました。同期キーが安全なストレージから削除されました。';

  @override
  String get ankiSyncStatusClearLoginFailed => '保存されたログインセッションをクリアできませんでした';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      '操作が終了しませんでした。安全なストレージ、ネットワーク、サーバーのアドレスを確認してください。';

  @override
  String get ankiSyncUnknown => '未知';

  @override
  String get ankiSyncServerCollectionEmpty => 'サーバーコレクションが空です';

  @override
  String get ankiSyncServerCollectionAvailable => 'サーバーコレクションが利用可能です';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return 'スキーマ バージョン $schema · USN $usn · 変更された $modified';
  }

  @override
  String get asrPageTitle => '音声文字起こし';

  @override
  String get clear => 'クリア';

  @override
  String get configure => '設定する';

  @override
  String get asrModel => '認識モデル';

  @override
  String get reselectModel => 'モデルを再度選択してください';

  @override
  String get selectAsrModel => '認識モデルの選択';

  @override
  String get enterPublicAudioUrl => 'パブリックオーディオ URL を入力してください';

  @override
  String get recordingSelection => '録音';

  @override
  String get audioFiles => '音声ファイル';

  @override
  String get noAudioSelected => '音声ファイルが選択されていません';

  @override
  String get supportedAudioFormats => 'WAV、MP3、M4A、OGG などの一般的なオーディオ形式をサポート';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の音声ファイルを選択中',
      one: '$count 個の音声ファイルを選択中',
      zero: '音声ファイルは選択されていません',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の音声ファイルを選択中',
      one: '$count 個の音声ファイルを選択中',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => 'もう一度選択してください';

  @override
  String get asrUrlLabel => 'URL |パブリックリンク';

  @override
  String get asrErrorDetails => 'エラーの詳細を表示する';

  @override
  String get asrResultSaved => '文字起こし結果が保存されました';

  @override
  String get asrWorking => '文字起こし中…';

  @override
  String get asrStart => '文字起こしを開始する';

  @override
  String get saveTo => '保存先';

  @override
  String get rootFolder => 'ルートフォルダー';

  @override
  String get chooseSaveFolder => 'フォルダーを選択してください';

  @override
  String get linkAlreadyAdded => 'このリンクはすでにリストにあります';

  @override
  String get chooseAudioSource => 'オーディオソースを選択してください';

  @override
  String get inAppRecordings => 'アプリ内録音';

  @override
  String get chooseGeneratedRecordings => '生成された録音から選択する';

  @override
  String get systemAudioFiles => 'システムオーディオファイル';

  @override
  String get chooseDeviceAudioFiles => 'デバイスからファイルを選択してください';

  @override
  String get cannotReadAudioFile => '音声ファイルを読み取れませんでした';

  @override
  String chooseAudioFileFailed(String details) {
    return '音声ファイルを選択できませんでした: $details';
  }

  @override
  String get chooseInAppRecording => 'アプリ内録音を選択する';

  @override
  String get noRecordings => '録音なし';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds 秒',
      one: '$seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider => '最初に設定で音声転写プロバイダーとモデルを構成します';

  @override
  String get asrModelUnavailable => '元の認識モデルが利用できないか、検証できません。再度機種を選択してください。';

  @override
  String get asrUrlProviderRemoveFiles =>
      'このプロバイダーは、URL によって音声をアップロードします。ローカルのオーディオ ファイルを削除して、もう一度試してください。';

  @override
  String get asrFileProviderRemoveUrls =>
      'このプロバイダーは音声ファイルをアップロードしますが、リンクによる文字起こしはサポートしていません。リンクを削除して再試行してください。';

  @override
  String asrTaskStartFailed(String details) {
    return 'タスクを開始できませんでした: $details';
  }

  @override
  String get asrInvalidUrl => 'URLが無効です。 http:// または https:// で始まる必要があります';

  @override
  String get asrEnterAudioUrl => '音声の URL を入力してください';

  @override
  String get asrUrlProviderHelp =>
      'このプロバイダーは、URL によって音声をアップロードします。パブリックオーディオ URL (http/https) を入力します。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get add => '追加';

  @override
  String get ttsPageTitle => 'オーディオ';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の音声ファイルをインポートしました',
      one: '$count 個の音声ファイルをインポートしました',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return 'インポートに失敗しました: $details';
  }

  @override
  String get ttsFileReadFailed => 'ファイルデータを読み取れませんでした';

  @override
  String get ttsExportAudioFile => '音声ファイルをエクスポートする';

  @override
  String ttsExportedTo(String path) {
    return 'エクスポート先: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return 'エクスポートに失敗しました: $details';
  }

  @override
  String get ttsConfirmRegenerate => '再生を確認する';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return 'オーディオ「$fileName」を再生しますか?';
  }

  @override
  String get ttsRegenerateOverwrite => '再生後、元の音声ファイルは置き換えられます。';

  @override
  String get ttsRegenerate => 'オーディオを再生する';

  @override
  String ttsCopiedFailed(String details) {
    return 'コピーできませんでした: $details';
  }

  @override
  String get ttsChooseExportFolder => 'エクスポートフォルダーを選択してください';

  @override
  String get ttsExportAudio => 'オーディオのエクスポート';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のファイルをエクスポートしました',
      one: '$count 個のファイルをエクスポートしました',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => 'エクスポートフォルダー';

  @override
  String get ttsWebFolderExportHelp =>
      'お使いのブラウザではエクスポート フォルダーを選択できません。フォルダー構造が維持された状態で ZIP ファイルがダウンロードされます。';

  @override
  String get ttsDownloadZip => 'ZIPファイルをダウンロード';

  @override
  String get ttsExportAudioFolder => 'オーディオフォルダーをエクスポートする';

  @override
  String get ttsRecord => '記録';

  @override
  String get ttsImport => '輸入';

  @override
  String get ttsPlay => '遊ぶ';

  @override
  String get ttsExportLocal => 'デバイスにエクスポート';

  @override
  String get ttsRegenerateQuestion => '再生する';

  @override
  String get ttsNeedsProvider => '最初に設定で音声合成プロバイダーとモデルを構成します';

  @override
  String get ttsAddedToTasks => 'タスクリストに追加されました。バックグラウンドで生成中…';

  @override
  String get ttsCreateTitle => '音声合成';

  @override
  String get ttsOriginalTitle => '収録タイトル';

  @override
  String get ttsUseOriginalTitle => '元のタイトルを使用する';

  @override
  String get ttsAudioFileNameHint => '保存された音声ファイル名 (オプション)';

  @override
  String get ttsTextToConvert => '変換するテキスト';

  @override
  String get ttsSpeechContent => '講演内容';

  @override
  String get ttsTextHint => '音声に変換するテキストを入力してください…';

  @override
  String get ttsFullscreenEdit => '全画面で編集する';

  @override
  String ttsTextLimitWarning(int limit) {
    return 'テキストが制限を超えています (最大 $limit 文字)';
  }

  @override
  String get ttsSynthesisConfig => '合成設定';

  @override
  String get ttsVoiceAndSoundHelp => '音声とサウンドを調整する';

  @override
  String get ttsProviderSettingsLead => 'で';

  @override
  String get ttsProviderSettings => 'TTSプロバイダーの設定';

  @override
  String get ttsProviderSettingsTail => 'さらにパラメータを設定するには';

  @override
  String get ttsEditText => 'テキストを編集する';

  @override
  String get ttsClose => '閉じる';

  @override
  String get ttsVoice => '声';

  @override
  String get ttsSelectVoice => '音声を選択してください';

  @override
  String get ttsSpeed => 'スピード';

  @override
  String get ttsNormal => '普通';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsInstruction => '話し方指導';

  @override
  String get ttsInstructionHint => '例: 明るく興奮した口調で話す';

  @override
  String get ttsCustomParams => 'カスタムパラメータ';

  @override
  String ttsDefaultValue(Object value) {
    return 'デフォルト: $value';
  }

  @override
  String get ttsGenerateRecording => '録音の生成';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return '名前を付けて保存: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => 'フォルダーを選択してください';

  @override
  String get ttsFillTextError => '変換するテキストを入力してください';

  @override
  String get voiceBatchTitle => '音声を一括追加する';

  @override
  String get voiceBatchConfirm => '選択したボイスを追加する';

  @override
  String get voiceBatchSeparator => '区切り文字:';

  @override
  String get voiceBatchCustomSeparatorHint => 'カスタム区切り文字を入力してください';

  @override
  String get voiceBatchFieldOrder => 'フィールドの順序:';

  @override
  String get voiceBatchNameThenId => '1番目=名前、2番目=ID';

  @override
  String get voiceBatchIdThenName => '1番目 = ID、2番目 = 名前';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '列を $count 件検出しました。名前/ID の開始列を選択してください：',
      one: '列を $count 件検出しました。名前/ID の開始列を選択してください：',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return '列 $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn =>
      '1 つの列が検出されました。すべての値が ID (名前 = ID) として使用されます。';

  @override
  String get voiceBatchInputHint =>
      '名前と ID はタブ、カンマ、セミコロン、または縦棒で区切ります (1 行に 1 ペア)。';

  @override
  String get voiceBatchNoPreview => 'プレビューするものがありません';

  @override
  String get voiceName => 'ボイスネーム';

  @override
  String get voiceId => '音声ID';

  @override
  String get status => '状態';

  @override
  String get voiceNew => '✅ 新しい';

  @override
  String get voiceIdExists => '⚠️IDはすでに存在します';

  @override
  String voiceFormatError(String details) {
    return '❌ フォーマットエラー$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の重複 ID が見つかりました: $ids',
      one: '$count 件の重複 ID が見つかりました: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData => '選択した列に十分なデータがありません';

  @override
  String get voiceCustomSeparator => 'カスタム…';

  @override
  String get voiceCommaSeparator => 'カンマ(,)';

  @override
  String get voiceSemicolonSeparator => 'セミコロン(;)';

  @override
  String get voicePipeSeparator => '縦棒 (|)';

  @override
  String get voiceTabSeparator => 'タブ';

  @override
  String get voiceEditorTitle => 'ボイスを編集する';

  @override
  String get save => '保存';

  @override
  String get voiceAddRow => '行を追加';

  @override
  String get voiceBatchAdd => '一括追加';

  @override
  String get voiceNoneAdd => 'まだ声はありません。開始するには 1 つ追加してください。';

  @override
  String get delete => '消去';

  @override
  String get voiceDuplicateResolution => '以下の音声IDが重複しています。それぞれの処理方法を選択します。';

  @override
  String get update => 'アップデート';

  @override
  String get skip => 'スキップ';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の重複が残っています',
      one: '$count 件の重複が残っています',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => '編集を続ける';

  @override
  String get asrRetryIncomplete => 'リトライ音声が不完全です。リストをクリアして、すべてのオーディオを再度選択します。';

  @override
  String asrRetryAudioUnreadable(String details) {
    return 'リトライ音声データを読み込めませんでした。オーディオを再度選択します: $details';
  }

  @override
  String get asrLegacyRetryUnavailable => '従来の再試行音声は使用できません。オーディオを再度選択します。';

  @override
  String get asrRetryDataUnreadable => 'リトライデータを読み取れませんでした。オーディオを再度選択します。';

  @override
  String get ttsSynthesisModel => '合成モデル';

  @override
  String get asrRetryUnavailable => 'リトライ音声は利用できません。オーディオを再度選択します。';

  @override
  String get chatRequest => 'リクエスト';

  @override
  String get chatResponse => '応答';

  @override
  String get chatNoErrorDetails => '詳細はありません';

  @override
  String get ttsInstructionDescription =>
      'トーン、感情、スピード、アクセント、その他の性質を自然言語で説明します。モデルはそれに応じて合成音声を調整します。';

  @override
  String get audioPlayerSourceTextSource => 'ソーステキストを選択してください';

  @override
  String get audioPlayerChooseInAppText => 'アプリのテキストで選択';

  @override
  String get audioPlayerChooseSavedTextSubtitle => 'アプリから保存したテキストファイルを選択します';

  @override
  String get audioPlayerChooseSystemText => 'システムテキストファイルを選択してください';

  @override
  String get audioPlayerChooseDeviceTextSubtitle => 'デバイスストレージからテキストファイルを選択します';

  @override
  String get audioPlayerSelectInAppText => 'アプリのテキストで選択';

  @override
  String get audioPlayerNoTextFiles => 'テキスト ファイルはまだありません';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count 文字';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return 'テキストの選択に失敗しました: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile => 'テキストファイルを読み取れません';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return 'ソーステキストのアップロードに失敗しました: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => 'テキストが空です';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return 'ソース テキストの保存に失敗しました: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => 'ソーステキストがアップロードされました';

  @override
  String get audioPlayerSourceTextUpdated => 'ソーステキストが更新されました';

  @override
  String get audioPlayerConfigureTtsProvider => '最初に TTS プロバイダーを構成します';

  @override
  String get audioPlayerNoStreamingModels => 'ストリーミング再生に対応している機種はありません';

  @override
  String get audioPlayerSelectStreamingModel => 'ストリーミング再生モデルを選択する';

  @override
  String get audioPlayerProviderFallback => 'プロバイダー';

  @override
  String audioPlayerStartStreaming(String model) {
    return 'ストリーミング再生開始：$model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return '音声ファイルが見つかりません: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio => '音声データを読み込めません';

  @override
  String get audioPlayerSourceText => 'ソーステキスト';

  @override
  String get audioPlayerNoSourceText => '(原文なし)';

  @override
  String get audioPlayerUploadSourceText => 'ソーステキストをアップロードする';

  @override
  String get audioPlayerEditSourceText => 'ソーステキストを編集する';

  @override
  String get audioPlayerCompanionTextMissing => 'コンパニオンテキストファイルが見つかりません';

  @override
  String get audioPlayerPlaySelection => 'プレイセレクション';

  @override
  String get audioPlayerGenerateSelection => '選択範囲の生成';

  @override
  String get audioPlayerPlaying => '遊んでいます...';

  @override
  String get audioPlayerPaused => '一時停止中';

  @override
  String get audioPlayerPlaybackSpeed => '再生速度';

  @override
  String get audioPlayerFailed => '再生に失敗しました';

  @override
  String get audioPlayerRetry => 'リトライ';

  @override
  String get audioPlayerLoading => 'オーディオを読み込んでいます...';

  @override
  String get audioPlayerClose => '閉じる';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      'ブラウザでは録画はサポートされていません。アプリ版をご利用ください。';

  @override
  String get audioRecordingMicrophonePermissionRequired => '録音するにはマイクの許可が必要です';

  @override
  String audioRecordingStartFailure(String error) {
    return '記録の開始に失敗しました: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return '録画の一時停止に失敗しました: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return '記録の再開に失敗しました: $error';
  }

  @override
  String get audioRecordingInvalidFile => '録音ファイルが無効です。もう一度録音してください。';

  @override
  String audioRecordingStopFailure(String error) {
    return '記録の停止に失敗しました: $error';
  }

  @override
  String get audioRecordingFileNotFound => '録音ファイルが見つかりません';

  @override
  String get audioRecordingFileEmpty => '録音ファイルが空です';

  @override
  String audioRecordingSaved(String name) {
    return '保存された録音: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return '録画の保存に失敗しました: $error';
  }

  @override
  String get audioRecordingTitle => '録音';

  @override
  String get audioRecordingBrowserUnsupported => 'ブラウザでは録画はサポートされていません';

  @override
  String get audioRecordingUseApp => 'アプリ版を使用して録音する';

  @override
  String get audioRecordingDraftRecoveryHint =>
      '保存されていない録音ドラフトが見つかりました。オーディオライブラリに保存できます。';

  @override
  String get audioRecordingRecording => '録音 ●';

  @override
  String get audioRecordingPaused => '一時停止しました ||';

  @override
  String get audioRecordingPreparing => '準備中...';

  @override
  String get audioRecordingStart => '録音を開始する';

  @override
  String get audioRecordingPause => '一時停止';

  @override
  String get audioRecordingStopping => '停止中...';

  @override
  String get audioRecordingStop => '停止';

  @override
  String get audioRecordingResume => '再開する';

  @override
  String get audioRecordingSaving => '保存中...';

  @override
  String get audioRecordingSave => '録音を保存する';

  @override
  String get audioRecordingRecordAgain => '再度録音する';

  @override
  String get audioRecordingWaveformPaused => '録音が一時停止されました。波形がフリーズしている';

  @override
  String get audioRecordingWaveformLive => 'ライブオーディオ波形';

  @override
  String get audioSeparationTitle => 'ビデオとオーディオの分離';

  @override
  String get audioSeparationChooseVideoSource => 'ビデオソースを選択してください';

  @override
  String get audioSeparationChooseAppAlbum => 'アプリライブラリから選択';

  @override
  String get audioSeparationChooseSavedVideoSubtitle => 'アプリから保存したビデオを選択します';

  @override
  String get audioSeparationChooseSystemAlbum => 'システムストレージから選ぶ';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle =>
      'デバイスストレージからビデオファイルを選択します';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return 'ビデオの選択に失敗しました: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix => '音声抽出に失敗しました:';

  @override
  String get audioSeparationEngineMissing => '音声分離エンジンが検出されませんでした';

  @override
  String get audioSeparationEngineMissingHelp =>
      'アプリを再起動するか、アプリのリソースが完了していることを確認します。';

  @override
  String get audioSeparationNoVideoSelected => '動画が選択されていません';

  @override
  String get audioSeparationSupportedFormatsHint =>
      'サポートされている形式: mp4、mov、m4v、3gp';

  @override
  String get audioSeparationSuccess => 'オーディオが抽出され、オーディオ ライブラリに保存されました';

  @override
  String get audioSeparationView => 'ビュー';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 本の動画を選択中',
      one: '$count 本の動画を選択中',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => '抽出中...';

  @override
  String get audioSeparationExtractAudio => '音声を抽出する';

  @override
  String get audioSeparationSaveTo => '保存先';

  @override
  String get audioSeparationChooseSaveFolder => '保存フォルダーを選択してください';

  @override
  String get audioSeparationCannotReadVideoFile => 'ビデオファイルを読み取れません';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return 'ビデオ ファイルの選択に失敗しました: $error';
  }

  @override
  String get audioSeparationUnknownFormat => '未知';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return 'サポートされていない形式: $formats。サポートされている形式: MP4、MOV、M4V、3GP。';
  }

  @override
  String get audioSeparationEngineUnavailable => '音声分離エンジンが利用できません。';

  @override
  String get backgroundOptimizationTitle => 'バックグラウンドの最適化';

  @override
  String get backgroundOptimizationEnvironment => 'システム環境';

  @override
  String get backgroundOptimizationChecks => 'バックグラウンドサービスのステータス';

  @override
  String get backgroundOptimizationKeepAliveStrategies => 'キープアライブ戦略';

  @override
  String get backgroundOptimizationDetecting => 'チェック中…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      'このプラットフォームではバックグラウンド サービスがサポートされていません';

  @override
  String get backgroundOptimizationServiceRunning => 'バックグラウンドサービスが実行中です';

  @override
  String get backgroundOptimizationServiceStopped => 'バックグラウンドサービスが実行されていません';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      'バックグラウンドサービスのステータスを確認できませんでした';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      'デスクトップトレイは使用できません。ウィンドウを閉じるとアプリが終了します。';

  @override
  String get backgroundOptimizationDesktopCloseExits =>
      'デスクトップウィンドウが閉じるとアプリが終了します';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      'デスクトップトレイでアプリを実行し続ける';

  @override
  String get backgroundOptimizationStartFailed => 'サービスを開始できませんでした';

  @override
  String get backgroundOptimizationStopFailed => 'サービスを停止できませんでした';

  @override
  String get backgroundOptimizationRestartFailed => 'サービスを再起動できませんでした';

  @override
  String get backgroundOptimizationStopService => 'サービスの停止';

  @override
  String get backgroundOptimizationRestartService => 'サービスの再起動';

  @override
  String get backgroundOptimizationStartService => 'サービス開始';

  @override
  String get backgroundOptimizationRedetect => 'もう一度確認してください';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      'このプラットフォームではバックグラウンド サービス コントロールはサポートされていません。';

  @override
  String get backgroundOptimizationCheckingBattery => 'バッテリーの最適化ステータスを確認しています…';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      'このアプリではバッテリーの最適化が無効になっています';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      'バッテリーの最適化が有効になっています - バックグラウンドアクティビティが停止される可能性があります';

  @override
  String get backgroundOptimizationIgnoreBattery => 'バッテリーの最適化を無効にする';

  @override
  String get backgroundOptimizationExactAlarm =>
      '正確なアラームを許可する (より信頼性の高いバックグラウンド アクティビティ)';

  @override
  String get backgroundOptimizationWatchdogTitle => 'アラームマネージャーのウォッチドッグ';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      '有効にすると、Android はネイティブ アラームを使用して 5 分ごとにバックグラウンド サービスをチェックします。システムがプロセスを強制終了すると、アラームによってプロセスが再起動されます。\n\nデバイスが Doze モードにある間もアラームは機能し、再起動後に再スケジュールされます。\n\nバックグラウンド タスクに大きく依存するユーザーに推奨されます。\nバッテリーへの影響: 非常に低い。デバイスはチェックごとに短時間スリープ状態を解除します。';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      'ウォッチドッグ設定を保存できませんでした。変わってなかった';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      'ウォッチドッグをアクティブにできませんでした。バックグラウンドサービスのステータスは未確認です';

  @override
  String get backgroundOptimizationColdStartTitle => 'アプリ起動時にサービスを復元する';

  @override
  String get backgroundOptimizationColdStartDetail =>
      '有効にすると、アプリは開くたびに、以前に実行されていたバックグラウンド サービスを確認して復元します。\n\nシステムまたはユーザーがアプリのプロセスを停止した場合、次回アプリを開いたときにバックグラウンド サービスが再起動されます。\n\nすべてのユーザーに推奨されます。\nバッテリーへの影響: なし。アプリは起動時に 1 回だけチェックします。';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      '起動回復設定を保存できませんでした。変わってなかった';

  @override
  String get backgroundOptimizationBatteryReminderTitle => 'バッテリー最適化リマインダー';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      '有効にすると、このページにバッテリーの最適化ステータスが表示されます。アプリがバッテリー免除リストにない場合は、システム設定を開いて免除することができます。\n\nAndroid のバッテリー最適化 (Doze) により、バックグラウンド アプリが制限されます。このアプリを除外リストに追加すると、システムが電力を節約するためにアプリを停止することがなくなります。\n\nこれをオフにすると、リマインダー カードが非表示になるだけです。アプリのバッテリー免除は変わりません。';

  @override
  String get backgroundOptimizationStrategyIntro =>
      'これらの戦略は個別に有効にすることができます。最も信頼性の高いバックグラウンド アクティビティを実現するために、これらはすべてデフォルトでオンになっています。 1 つをオフにすると、その戦略のみに影響し、バックグラウンド サービス自体には影響しません。';

  @override
  String get backgroundOptimizationIosNoteTitle => 'iOSのバックグラウンドタスク';

  @override
  String get backgroundOptimizationIosSupported =>
      'このバージョンの iOS (26 以降) は、進行中のバックグラウンド タスクをサポートします。通常、アプリを切り替えたり画面をロックしたりしてもタスクは続行されますが、リソースが不足するとシステムがタスクを停止する場合があります。ロック画面で進行状況を確認できます。';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'このバージョンの iOS (26 より前) は、進行中のバックグラウンド タスクをサポートしていません。タスクの実行中は、数分ごと (約 5 ～ 10 分ごと。タイミングは iOS によって異なります) にアプリに戻ってバックグラウンド時間を更新し、一時停止を防ぎます。';

  @override
  String get backgroundOptimizationIosWarning =>
      'どの iOS バージョンでも、アプリ スイッチャーで Stroom をスワイプしないでください。これを実行すると、実行中のすべてのタスクが即座に停止します。';

  @override
  String get backgroundOptimizationDesktopIntro =>
      'デスクトップ システムにはモバイル プラットフォームのプロセス キープアライブ メカニズムがありませんが、アプリはウィンドウが閉じた後も実行を続けることができます。';

  @override
  String get backgroundOptimizationCloseMinimizeTitle => 'ウィンドウを閉じるときに最小化する';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      '有効にすると、ウィンドウの閉じるボタンをクリックすると、アプリが終了する代わりにシステム トレイに非表示になります。バックグラウンド タスクは引き続き実行されます。\n\nトレイ アイコンまたはその「メイン ウィンドウの表示」メニュー項目からウィンドウを復元します。終了するには、下の「アプリを終了」ボタンを使用してください。\n\nすべてのデスクトップ ユーザーに推奨されます。';

  @override
  String get backgroundOptimizationQuitApp => 'アプリを終了する';

  @override
  String get backgroundOptimizationGotIt => 'わかった';

  @override
  String get backgroundOptimizationWebNoteTitle => 'Web バックグラウンド タスク';

  @override
  String get backgroundOptimizationWebNote =>
      'ブラウザはアプリをバックグラウンドで実行し続けることはできません。このタブを閉じるか更新すると、ブラウザが非アクティブなバックグラウンド タブをフリーズすると、実行中のタスクが直ちに停止します。タスクの実行中は、「Stroom」タブを開いてフォアグラウンドにしておきます。';

  @override
  String get backgroundOptimizationTutorial => 'プラットフォームガイド';

  @override
  String get backgroundOptimizationTutorialDescription =>
      '各プラットフォームのバックグラウンド最適化ガイドを表示する';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      'バックグラウンド サービスのステータスを確認しています…';

  @override
  String get backgroundOptimizationServiceUnknown =>
      'バックグラウンド サービスのステータスが不明です。サービスが実行されているかどうかをもう一度確認してください。';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      'バックグラウンドサービスが実行中です。タスクはバックグラウンドで続行できます。';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'バックグラウンド サービスは Web ブラウザではサポートされていません。タスクを続行するには、このページを開いたままにしてください。';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      'デスクトップ トレイは使用できません (Linux ビルドには libaatana-appindicator3-dev が必要です)。ウィンドウを閉じるとアプリが終了します。';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      'デスクトップトレイは使用できません。ウィンドウを閉じるとアプリが終了します。';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      'アプリは、デスクトップ ウィンドウが閉じるときに終了するように設定されています。これは既存の終了確認フローに従い、トレイ内で実行を継続しません。';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      'デスクトップトレイが有効になります。ウィンドウを閉じると、アプリはシステム トレイに非表示になり、引き続き実行されます。トレイメニューの「メインウィンドウを表示」を選択すると元に戻ります。完全に終了するには、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      'デスクトップトレイが有効になります。ウィンドウを閉じると、アプリがシステム トレイに最小化され、そこで実行が継続されます。トレイアイコンをクリックするか、メニューから「メインウィンドウを表示」を選択するとウィンドウが元に戻ります。完全に終了するには、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      'バックグラウンドサービスが実行されていません。以下の「サービスの開始」を選択するか、プラットフォーム ガイドを参照してバックグラウンド アクティビティを最適化する方法を確認してください。';

  @override
  String get notificationSettingsPageTitle => '通知許可設定';

  @override
  String get notificationSettingsWebUnsupported => '通知は Web ブラウザではサポートされていません';

  @override
  String get notificationSettingsChecking => 'チェック中…';

  @override
  String get notificationSettingsPermissionGranted => '通知許可が付与されました';

  @override
  String get notificationSettingsPermissionDenied => '通知権限が付与されていません';

  @override
  String get notificationSettingsPermissionRestricted => '通知許可が制限されています';

  @override
  String get notificationSettingsPermissionBlocked => '通知許可が永久にブロックされました';

  @override
  String get notificationSettingsPermissionProvisional => '仮通知許可';

  @override
  String get notificationSettingsWebGuide => 'システム通知は Web ブラウザではサポートされていません。';

  @override
  String get notificationSettingsCheckingPermission => '通知許可を確認しています…';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      '通知許可が与えられます。タスク完了通知を有効にして、タスクが完了または失敗したときにシステム アラートを受信することができます。';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      '通知許可が与えられていません。下のボタンを選択して許可をリクエストするか、システム設定で Stroom への通知を有効にします。';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      '通知の許可は、ペアレンタルコントロールなどのシステムによって制限されています。システム設定で Stroom の通知設定を確認してください。';

  @override
  String get notificationSettingsEnvironment => 'システム環境';

  @override
  String get notificationSettingsPermissionSection => '通知の許可';

  @override
  String get notificationSettingsPlatformGuides => 'プラットフォームガイド';

  @override
  String get notificationSettingsGuideIntro =>
      'Stroom の通知を有効にするには、オペレーティング システムに応じて次の手順に従ってください。';

  @override
  String get notificationSettingsTaskCompleteTitle => 'タスク完了通知';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      'タスクが完了または失敗したときに通知を送信する';

  @override
  String get notificationSettingsCheckAgain => 'もう一度確認してください';

  @override
  String get notificationSettingsOpenSystemSettings => 'システム設定を開く';

  @override
  String get notificationSettingsRequestPermission => '許可のリクエスト';

  @override
  String get notificationSettingsGuideUnsupported =>
      'このプラットフォームでは通知設定ガイドは利用できません。';

  @override
  String get notificationSettingsUsageReason => 'タスクの完了時に通知を送信するには';

  @override
  String get notificationSettingsAndroidEnableTitle => '通知を有効にする';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      '「設定」→「アプリ」→「Stroom」→「通知管理」に移動し、通知を許可します。 Stroom が見つからない場合は、インストールされていることを確認してください。通知が無効になっている場合は、オンにします。';

  @override
  String get notificationSettingsAndroidDndTitle => '「サイレントモード」にチェックを入れる';

  @override
  String get notificationSettingsAndroidDndDescription =>
      '「設定」→「サウンドと振動」→「おやすみモード」に移動します。オフになっているか、Stroom 通知が許可されていることを確認してください。';

  @override
  String get notificationSettingsAndroidPopupTitle => '通知のポップアップを許可する';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'MIUI、EMUI、ColorOS などの一部の Android システムでは、アプリ情報で「通知を許可」と「ポップアップを許可」を有効にする必要があります。アプリの「通知フィルタリング」または「スマート通知」をオフにすることも検討してください。';

  @override
  String get notificationSettingsReturnTitle => 'このページに戻る';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      'これらの設定を変更した後、「再確認」を選択して許可状況を確認します。権限が付与されると、タスク完了通知を有効にすることができます。';

  @override
  String get notificationSettingsIosEnableDescription =>
      '「設定」→「通知」→「Stroom」に移動し、「通知を許可」をオンにします。また、バナーと通知センターでタスクのステータスを最新の状態に保つことができるようにします。';

  @override
  String get notificationSettingsIosFocusTitle => 'フォーカスをオフにする';

  @override
  String get notificationSettingsIosFocusDescription =>
      '「設定」→「フォーカス」に移動します。フォーカスがオフになっていることを確認するか、許可されたアプリのリストに Stroom を追加してください。フォーカスするとアプリの通知を沈黙させることができます。';

  @override
  String get notificationSettingsIosReturnDescription =>
      'これらの設定を変更した後、「再確認」を選択して許可状況を確認します。 iOS では、通常、システム設定で通知許可を手動で有効にする必要があります。';

  @override
  String get notificationSettingsWindowsEnableTitle => 'システム通知を有効にする';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      '「設定」→「システム」→「通知とアクション」に移動し、「アプリや他の送信者からの通知を受け取る」をオンにします。以下のアプリリストで Stroom を見つけて、通知がオンになっていることを確認してください。';

  @override
  String get notificationSettingsWindowsFocusTitle => 'フォーカスアシスト例外を追加する';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      '「設定」→「システム」→「フォーカスアシスト」に移動します。 Stroom を「優先のみ」に追加するか、フォーカス アシストをオフにします。フォーカスアシストは通知を消すことができます。';

  @override
  String get notificationSettingsMacEnableTitle => '通知を有効にする';

  @override
  String get notificationSettingsMacEnableDescription =>
      '「システム設定」→「通知」→「Stroom」に移動し、「通知を許可」をオンにします。バナーと通知センターも有効にします。';

  @override
  String get notificationSettingsMacFocusDescription =>
      '「システム設定」→「フォーカス」に移動します。フォーカスがオフになっていることを確認するか、許可されたアプリのリストに Stroom を追加してください。';

  @override
  String get notificationSettingsLinuxDesktopTitle => 'デスクトップ通知設定を確認する';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      'デスクトップ環境 (GNOME、KDE、XFCE など) に応じて、[システム設定] → [通知] に移動し、Stroom を見つけて、通知がオンになっていることを確認します。';

  @override
  String get notificationSettingsLinuxDaemonTitle => '通知デーモンを確認する';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Linux デスクトップ環境では、システム通知を表示するには、notify-osd や dunst などの通知デーモンが必要です。いずれかがインストールされ、実行されていることを確認してください。';

  @override
  String get backupRestorePageTitle => 'バックアップと復元';

  @override
  String get backupRestoreSelectBackupCategory =>
      'バックアップするデータ カテゴリを少なくとも 1 つ選択してください';

  @override
  String get backupRestorePreparingData => 'データを準備中…';

  @override
  String get backupRestoreExportingBackup => 'バックアップのエクスポート';

  @override
  String get backupRestoreCollectingDatabase => 'データベースレコードを収集しています…';

  @override
  String get backupRestoreProcessingSettings => '設定を処理中…';

  @override
  String get backupRestoreAddingTasks => 'タスクファイルを追加しています…';

  @override
  String get backupRestoreAddingPictures => '画像ファイルを追加しています…';

  @override
  String get backupRestoreAddingAudio => '音声ファイルを追加しています…';

  @override
  String get backupRestoreAddingVideo => 'ビデオ ファイルを追加しています…';

  @override
  String get backupRestoreAddingText => 'テキスト ファイルを追加しています…';

  @override
  String get backupRestoreAddingChat => 'チャット履歴と添付ファイルを追加しています…';

  @override
  String get backupRestoreCompressing => 'アーカイブを圧縮しています…';

  @override
  String get backupRestoreCompleted => '完了';

  @override
  String get backupRestoreSelectRestoreCategory =>
      '復元するデータ カテゴリを少なくとも 1 つ選択してください';

  @override
  String get backupRestoreConfirmRestore => '復元の確認';

  @override
  String get backupRestoreSelectedCategories => '選択されたデータ カテゴリ:';

  @override
  String get backupRestoreRestoreInfo =>
      'バックアップ内で見つかった選択したカテゴリがこのデバイスに復元されます。組み込みブラウザ Cookie を除くすべてのカテゴリは、対応するローカル データを置き換えます。 Cookie はドメイン、名前、パスによって書き込まれます。バックアップに含まれないローカル Cookie は保存されます。選択されていないカテゴリとバックアップから欠落しているカテゴリは変更されません。欠落しているカテゴリは通知とともにスキップされます。';

  @override
  String get backupRestoreRestartNotice =>
      '変更を有効にするには、復元後にアプリを再起動します。現在の作業が保存されていることを確認してください。';

  @override
  String get backupRestoreCancel => 'キャンセル';

  @override
  String get backupRestoreConfirmRestoreButton => '復元する';

  @override
  String get backupRestoreIncompleteTitle => '不完全な復元';

  @override
  String get backupRestoreIncompleteMessage =>
      'データを完全に復元できず、一部のデータが消去された可能性があります。アプリを再起動して、もう一度試してください。';

  @override
  String get backupRestoreSelectClearCategory =>
      'クリアするデータ カテゴリを少なくとも 1 つ選択してください';

  @override
  String get backupRestoreClearingData => 'データの消去';

  @override
  String get backupRestoreDeletingCategories => '選択したデータ カテゴリを削除しています…';

  @override
  String get backupRestoreClearedTitle => 'データが消去されました';

  @override
  String get backupRestorePartiallyClearedTitle => '一部のデータが消去されました';

  @override
  String get backupRestoreClearedMessage =>
      '選択したデータが消去されました。変更を有効にするには、アプリを再起動します。';

  @override
  String get backupRestorePartialClearMessage =>
      '他の選択データはクリアされました。このプラットフォームは、ブラウザーの組み込み Web サイト ストレージ (localStorage、IndexedDB など) を完全にクリアできないため、クリアできなかったブラウザー データが残ります。クリアしたデータを有効にするには、アプリを再起動します。';

  @override
  String backupRestoreClearFailed(String error) {
    return 'データをクリアできませんでした: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => '未完了をクリア';

  @override
  String get backupRestoreClearIncompleteMessage =>
      '一部のデータを消去できませんでした。アプリを再起動し、もう一度クリアしてみてください。';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Anki デッキのエクスポート先: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get backupRestoreApkgRequired => '.apkg ファイルを選択します';

  @override
  String backupRestoreImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return 'バックアップの保存先: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return 'バックアップ失敗: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return '復元に失敗しました: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected =>
      'バックアップフォルダーが選択されていません。起動時に 1 つを許可します。';

  @override
  String get backupRestoreRestoreSuccessTitle => 'データが復元されました';

  @override
  String get backupRestoreRestoredMessage =>
      'バックアップからデータが復元されました。復元したデータを使用するには、アプリを再起動します。';

  @override
  String get backupRestoreExitApp => 'アプリを終了する';

  @override
  String get backupRestoreRestartNow => '今すぐ再起動してください';

  @override
  String get backupRestoreSkippedTitle => '一部のデータがスキップされました';

  @override
  String get backupRestoreNothingRestoredTitle => 'データは復元されませんでした';

  @override
  String get backupRestoreGotIt => 'わかった';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return 'バックアップでは、これらの選択したカテゴリの復元可能なコンテンツが確認されなかったため、スキップされ、既存のデータが保持されました: $categories。';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      '古いバックアップでは、空のタスク ファイルは、空のタスク リストとそのプラットフォームによってエクスポートされていないタスクを区別できません。現在のタスクの上書きを避けるために、タスク カテゴリはスキップされ、既存のデータが保持されました。';

  @override
  String get backupRestoreSkippedCookies =>
      'バックアップにはインポートする組み込みのブラウザ Cookie が含まれていないため、このカテゴリはスキップされ、既存の Cookie が保持されました。';

  @override
  String get backupRestoreSkippedWebsiteData =>
      'この古いバックアップの Web サイト ストレージ ディレクトリはスキップされました。アーカイブに Cookie が含まれており、そのカテゴリが選択されている場合は、Cookie を個別にインポートできます。';

  @override
  String get backupRestoreApkgTitle => 'アンキデッキ';

  @override
  String get backupRestoreApkgInfoTitle => 'Anki デッキのインポートまたはエクスポート';

  @override
  String get backupRestoreApkgInfoMessage => 'カード情報のみが含まれ、メディアは含まれません';

  @override
  String get backupRestoreApkgDescription =>
      'Anki デッキを .apkg 形式でインポートまたはエクスポートする';

  @override
  String get backupRestoreExportingApkg => 'エクスポート中…';

  @override
  String get backupRestoreExportApkg => '.apkg をエクスポート';

  @override
  String get backupRestoreImportingApkg => 'インポート中…';

  @override
  String get backupRestoreImportApkg => '.apkgをインポートする';

  @override
  String get backupRestoreCategoryHeading => 'バックアップまたは復元するデータ カテゴリの選択';

  @override
  String get backupRestoreExporting => 'エクスポート中…';

  @override
  String get backupRestoreExportBackup => 'バックアップのエクスポート';

  @override
  String get backupRestoreRestoring => '復元中…';

  @override
  String get backupRestoreChooseBackup => 'バックアップファイルを選択して復元する';

  @override
  String get backupRestoreClearSelected => '選択したデータをクリア';

  @override
  String get backupRestoreClearDescription =>
      'バックアップ ファイルを使用せずに、選択したデータ カテゴリを直接クリアします。選択されていないカテゴリは変更されません。この操作は元に戻すことができません。';

  @override
  String get backupRestoreClearing => 'クリア中…';

  @override
  String get backupRestoreCategoryChat => 'チャット履歴と添付ファイル';

  @override
  String get backupRestoreCategoryChatDescription => 'チャットの会話、メッセージの内容、添付ファイル';

  @override
  String get backupRestoreCategorySettings => '設定';

  @override
  String get backupRestoreCategorySettingsDescription =>
      'アプリの構成、プロバイダーの設定、インターフェイスの設定';

  @override
  String get backupRestoreCategoryPictures => '画像';

  @override
  String get backupRestoreCategoryPicturesDescription => '写真とサムネイル';

  @override
  String get backupRestoreCategoryAudio => 'オーディオ';

  @override
  String get backupRestoreCategoryAudioDescription => '音声合成と録音';

  @override
  String get backupRestoreCategoryVideos => '動画';

  @override
  String get backupRestoreCategoryVideosDescription => 'ビデオファイル';

  @override
  String get backupRestoreCategoryTexts => '文章';

  @override
  String get backupRestoreCategoryTextsDescription => 'テキストドキュメント';

  @override
  String get backupRestoreCategoryTasks => 'タスク';

  @override
  String get backupRestoreCategoryTasksDescription => 'バックグラウンドタスクのレコード';

  @override
  String get backupRestoreCategoryAnki => 'Anki フラッシュカード データ';

  @override
  String get backupRestoreCategoryAnkiDescription => 'アンキデータベース';

  @override
  String get backupRestoreAnkiDataInfoTitle => 'Anki フラッシュカード データ';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Anki フラッシュカード データのバックアップまたは復元には、collection.media ディレクトリ内のカード メディアも含まれます。';

  @override
  String get backupRestoreAnkiDataInfoTooltip => 'Anki フラッシュカード データについて';

  @override
  String get backupRestoreCategoryBrowser => '内蔵ブラウザデータ';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      'Cookie のみをバックアップおよび復元します。クリアすると、サポートされている Web サイトのストレージも削除されます';

  @override
  String get backupRestoreViewInfo => '情報を見る';

  @override
  String get backupRestoreApkgInfoTooltip => 'Anki デッキのインポートとエクスポートについて';

  @override
  String get backupRestoreConfirmClear => 'クリアの確認';

  @override
  String get backupRestoreClearCategoriesIntro =>
      '次のデータ カテゴリは、バックアップ ファイルを使用せずにクリアされます。';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      'このプラットフォームは、ブラウザーの組み込み Web サイト ストレージ (localStorage、IndexedDB など) を完全にクリアできません。確定すると、選択した他のデータがクリアされます。消去できないブラウザデータは残ります。';

  @override
  String get backupRestoreUnselectedUnchanged => '選択されていないカテゴリは変更されません。';

  @override
  String get backupRestoreClearWarning =>
      'この操作は元に戻すことができません。変更を有効にするためにクリアした後、アプリを再起動します。';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return 'クリア ($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment => 'ブラウザ環境';

  @override
  String get backupRestoreIntro =>
      '選択したデータ カテゴリを手動でエクスポートします。インポート中、アーカイブ内で見つかった選択されたカテゴリのみが復元されます。欠落しているカテゴリまたは必要なファイルは通知とともにスキップされ、選択されていないカテゴリは変更されません。選択したカテゴリを直接クリアすることもできます。';

  @override
  String get backupRestoreOtherSelectedRestored =>
      '選択した他のデータが復元されました。変更を有効にするには、アプリを再起動します。';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      '通知はブロックされています。システム設定を開き、Stroom の通知を許可します。';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      '通知はブロックされています。 「システム設定」→「アプリ」→「Stroom」→「通知管理」に移動し、通知を許可します。';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      '通知はブロックされています。 [システム設定] → [Stroom] → [通知] に移動し、通知を許可します。';

  @override
  String get textPreviewDiscardEditsTitle => '編集を破棄しますか?';

  @override
  String get textPreviewUnsavedChangesConfirm => '未保存の変更があります。本当に破棄してもよろしいですか?';

  @override
  String get textPreviewCancel => 'キャンセル';

  @override
  String get textPreviewDiscard => '破棄';

  @override
  String get textPreviewFontSize => 'フォントサイズを調整する';

  @override
  String get textPreviewRestoreDefault => 'デフォルトに戻す';

  @override
  String get textPreviewClose => '閉じる';

  @override
  String textPreviewSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get textPreviewUndo => '元に戻す';

  @override
  String get textPreviewRedo => 'やり直し';

  @override
  String get textPreviewSave => '保存';

  @override
  String get textPreviewEdit => '編集';

  @override
  String get textPreviewChartEdit => 'チャートの編集';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return 'サポートされていない形式をスキップ: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'テキストファイルを # 件インポートしました',
      one: 'テキストファイルを # 件インポートしました',
    );
    return '$_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get textStorageSaved => 'テキストが保存されました';

  @override
  String get textStorageLoadFailed => 'テキストコンテンツを読み込めません';

  @override
  String get textStorageReadFailed => 'ファイルデータの読み込みに失敗しました';

  @override
  String get textStorageExportTitle => 'テキストのエクスポート';

  @override
  String textStorageExportedTo(String path) {
    return 'エクスポート先: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get textStorageChooseExportDirectory => 'エクスポートディレクトリを選択してください';

  @override
  String get textStorageFolderExportTitle => 'エクスポートフォルダー';

  @override
  String get textStorageWebFolderExportInfo =>
      'ブラウザはエクスポート ディレクトリを選択できません。フォルダー構造を保持した ZIP ファイルがダウンロードされます。';

  @override
  String get textStorageCancel => 'キャンセル';

  @override
  String get textStorageDownloadZip => 'ZIPファイルをダウンロード';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 件のファイルをエクスポートしました',
      one: '# 件のファイルをエクスポートしました',
    );
    return '$_temp0';
  }

  @override
  String get textStorageExportFolderTitle => 'テキストフォルダーをエクスポートする';

  @override
  String textStorageCopyFailed(String error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get textStorageCreateNew => '新しい';

  @override
  String get textStorageImport => '輸入';

  @override
  String get textStorageTitle => '文章';

  @override
  String get textStorageExportToLocal => 'ローカルにエクスポート';

  @override
  String get textCreateEnterTitle => 'タイトルを入力してください';

  @override
  String textCreateSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get textCreateNewTitle => '新しい';

  @override
  String get textCreateSave => '保存';

  @override
  String get textCreateTitleLabel => 'タイトル';

  @override
  String get textCreateTitleHint => 'テキストタイトルを入力してください';

  @override
  String get textCreateFormatLabel => '形式';

  @override
  String get textCreateContentLabel => 'テキストの内容';

  @override
  String get textCreateContentHint => 'テキストコンテンツを入力してください...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return '$platform バックグラウンド最適化チュートリアル';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return '$platform バックグラウンド実行ガイド';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return '$platform バックグラウンド最適化ガイド';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return 'これらの手順は、$platform デバイスでの Stroom のバックグラウンド エクスペリエンスを最適化し、タスクをバックグラウンドで実行し続けるのに役立ちます。';
  }

  @override
  String get platformTutorialStepsHeading => '最適化の手順';

  @override
  String get platformTutorialTipsHeading => 'ヒント';

  @override
  String get platformTutorialTipsDescription =>
      'これらの設定が完了したら、「バックグラウンド最適化」ページに戻り、ステータスが更新されていることを確認します。それでも問題が解決しない場合は、別のプラットフォームのガイドを参照するか、GitHub で問題を報告してください。';

  @override
  String get platformTutorialAndroidStep1Title => 'バッテリーの最適化をオフにする';

  @override
  String get platformTutorialAndroidStep1Description =>
      '「設定」→「アプリ」→「Stroom」→「バッテリー」を開き、「制限なし」または「最適化しない」を選択します。このアプリの「バックグラウンド最適化」ページで「バッテリーの最適化を無視」をタップして、Stroom をシステムの省電力許可リストに追加することもできます。パスはデバイスのブランドによって異なります。';

  @override
  String get platformTutorialAndroidStep2Title => 'バックグラウンドアクティビティを許可する';

  @override
  String get platformTutorialAndroidStep2Description =>
      '「設定」→「アプリ」→「Stroom」を開き、「バックグラウンドアクティビティを許可」と「自動起動を許可」を有効にします。一部の電話では、セキュリティ センターまたは電話マネージャーで自動起動を許可する必要もあります。';

  @override
  String get platformTutorialAndroidStep3Title => 'バックグラウンドプロセスをロックする';

  @override
  String get platformTutorialAndroidStep3Description =>
      '最近のアプリ ビューで、Stroom カードを下にスワイプするか、ロック アイコンをタップして、システムがアプリを消去しないようにします。';

  @override
  String get platformTutorialAndroidStep4Title => '通知を許可する (Android 13 以降)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 以降では通知許可が必要です。これがないと、サービスは引き続き実行されますが、バックグラウンド サービスのフォアグラウンド通知は非表示になります。最初に「サービスを開始」をタップすると、アプリは許可を要求します。または、「設定」→「アプリ」→「Stroom」→「通知」で許可を有効にすることができます。';

  @override
  String get platformTutorialAndroidStep5Title => 'バッテリーの最適化を無視する';

  @override
  String get platformTutorialAndroidStep5Description =>
      'Stroom で「タスク完了通知」を有効にすると、アプリは関連する権限を要求します。また、「設定」→「アプリ」→「特別なアプリへのアクセス」→「バッテリーの最適化」で、Stroom が「最適化しない」に設定されていることを確認することもできます。';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Android デバイスの自動起動とバックグラウンド管理';

  @override
  String get platformTutorialAndroidStep6Description =>
      '多くの場合、デバイス メーカーは独自のバックグラウンド コントロールを追加します。\n• Xiaomi/Redmi (MIUI/HyperOS): 設定 → アプリ → 権限 → 自動起動。スルームを許可します。次に、「バッテリー」→「アプリのバッテリーセーバー」→「Stroom」→「制限なし」を開きます。\n• Huawei/Honor (EMUI/HarmonyOS): 設定 → アプリ → アプリ起動 → Stroom → 手動で管理。自動起動、二次起動、バックグラウンドアクティビティを許可します。\n• OPPO/OnePlus/realme (ColorOS): 設定 → バッテリー → アプリのバッテリー管理 → Stroom;完全なバックグラウンドアクティビティを許可します。\n• vivo/iQOO (OriginOS): iManager → アプリ管理 → 自動起動;スルームを許可します。';

  @override
  String get platformTutorialAndroidStep7Title => 'ロック画面のクリーンアップと省電力モードをオフにする';

  @override
  String get platformTutorialAndroidStep7Description =>
      '「設定」→「バッテリー」を開き、「省電力」または「超省電力」をオフにします。また、「ロック後のメモリ消去」を「消去しない」に設定してください。省電力モードはバックグラウンドアクティビティを制限し、タスクの完了に影響を与える可能性があります。';

  @override
  String get platformTutorialIosStep1Title => 'アプリのバックグラウンド更新を有効にする';

  @override
  String get platformTutorialIosStep1Description =>
      '「設定」→「一般」→「アプリのバックグラウンド更新」を開き、「Stroom」を見つけてオンにします。最高のエクスペリエンスを得るには、「Wi-Fi とモバイルデータ」を選択してください。';

  @override
  String get platformTutorialIosStep2Title => '通知を許可する';

  @override
  String get platformTutorialIosStep2Description =>
      '「設定」→「通知」→「Stroom」を開き、「通知を許可」をオンにします。タスクの更新をすぐに確認できるように、バナーと通知センターの両方を有効にします。';

  @override
  String get platformTutorialIosStep3Title => '低電力モードをオフにする';

  @override
  String get platformTutorialIosStep3Description =>
      '「設定」→「バッテリー」を開き、「低電力モード」をオフにします。このモードがオンになっている間、システムはバックグラウンド アクティビティを制限します。';

  @override
  String get platformTutorialIosStep4Title => 'iOSのバックグラウンド制限を理解する';

  @override
  String get platformTutorialIosStep4Description =>
      'iOS 26 より前のバージョンでは、Android アプリのようにアプリをバックグラウンドに残すことはできません。システムは、アプリのバックグラウンド更新、位置情報の更新、オーディオ再生などの特定の時間にのみアプリに短い実行時間を与え、長時間実行されるタスクを一時停止する場合があります。以下をお勧めします。\n• 長時間実行されるタスクの場合は、Stroom をフォアグラウンドに保ちます。\n• 定期的にアプリに戻って、バックグラウンド時間を更新します。\n• 重要なタスクについては「タスク完了通知」をオンにします。';

  @override
  String get platformTutorialIosStep5Title => 'タスク実行中のバックグラウンド ヒント';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 以降では、永続的なバックグラウンド タスクがサポートされています。通常、アプリを切り替えたり画面をロックしてもタスクは続行されますが、リソースが不足するとシステムがタスクを停止する場合があります。進行状況がロック画面に表示されます。\n\n以前の iOS バージョンは、永続的なバックグラウンド タスクをサポートしていません。数分ごとにアプリに戻り (5 ～ 10 分が目安であり、システムが決定します)、バックグラウンド時間を更新して一時停止を防ぎます。\n\nどのバージョンでも、アプリ スイッチャーで Stroom をスワイプしないでください。そうすることで、実行中のすべてのタスクが即座に停止されます。';

  @override
  String get platformTutorialIosStep6Title => 'アプリをフォアグラウンドに保ちます';

  @override
  String get platformTutorialIosStep6Description =>
      'iOS 26 より前のバージョンでは、アプリのバックグラウンド時間は限られています。長時間実行されるタスクの場合は、Stroom をフォアグラウンドに維持するか、定期的に Stroom に戻って時間を延長します。';

  @override
  String get platformTutorialWindowsStep1Title => 'ウィンドウを閉じるときに最小化する';

  @override
  String get platformTutorialWindowsStep1Description =>
      'デフォルトでは、ウィンドウの閉じるボタンをクリックすると、Stroom がシステム トレイ (時計の近く) に最小化され、実行を続けることができます。トレイアイコンまたは「メインウィンドウの表示」メニューから復元してください。タスクの実行中は終了しないでください。終了するには、「バックグラウンド最適化」ページの「アプリケーションを完全に終了する」を使用するか、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get platformTutorialWindowsStep2Title => 'バッテリーセーバーをオフにする';

  @override
  String get platformTutorialWindowsStep2Description =>
      '「設定」→「システム」→「電源とスリープ」を開き、バッテリーセーバーをオフにします。あるいは、バッテリーが選択したレベルを下回った場合にのみオンになるように設定します。';

  @override
  String get platformTutorialWindowsStep3Title => 'バックグラウンドアプリを許可する';

  @override
  String get platformTutorialWindowsStep3Description =>
      '[設定] → [プライバシーとセキュリティ] → [バックグラウンド アプリ] を開き、Stroom を見つけて有効になっていることを確認します。 Windows 11 では、「設定」→「アプリ」→「インストールされているアプリ」→「Stroom」→「詳細オプション」→「バックグラウンド アプリのアクセス許可」に移動し、「常に」を選択します。';

  @override
  String get platformTutorialWindowsStep4Title => 'スリープモードをオフにする (オプション)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'Stroom を長時間実行し続けるには、「設定」→「システム」→「電源」を開き、「スリープ」を「なし」に設定します (電源に接続されている場合のみ)。';

  @override
  String get platformTutorialWindowsStep5Title => 'Stroom をスタートアップに追加する';

  @override
  String get platformTutorialWindowsStep5Description =>
      'タスク マネージャー (Ctrl+Shift+Esc) → [スタートアップ] を開き、Stroom を見つけて [有効にする] を右クリックします。または、「設定」→「アプリ」→「スタートアップ」を開き、Stroom をオンにします。';

  @override
  String get platformTutorialMacosStep1Title => 'ウィンドウを閉じるときに最小化する';

  @override
  String get platformTutorialMacosStep1Description =>
      'デフォルトでは、ウィンドウを閉じてもメニュー バー (画面の右上) で Stroom が実行されたままになります。メニューバーアイコンをクリックするか、「メインウィンドウを表示」を選択して元に戻します。タスクの実行中は終了しないでください。終了するには、「バックグラウンド最適化」ページの「アプリケーションを完全に終了する」を使用するか、メニューバーメニューから「Quit Stroom」を選択します。';

  @override
  String get platformTutorialMacosStep2Title => '通知を許可する';

  @override
  String get platformTutorialMacosStep2Description =>
      'システム設定 → 通知 → Stroom を開き、「通知を許可」をオンにします。バナーと通知センターの両方を有効にすることをお勧めします。';

  @override
  String get platformTutorialMacosStep3Title => '低電力モードをオフにする (MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      '「システム設定」→「バッテリー」→「電源アダプター」を開き、「低電力モード」をオフにします。このモードはバックグラウンドアクティビティを制限します。';

  @override
  String get platformTutorialMacosStep4Title => 'アプリをアクティブなままにしておく';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS では、バックグラウンド アプリにほとんど制限がありません。長時間実行されるタスクの場合は、Stroom ウィンドウを開いたままにしてください。アプリを強制終了しないでください。窓を閉めれば十分です。';

  @override
  String get platformTutorialMacosStep5Title => 'ログイン時に起動 (オプション)';

  @override
  String get platformTutorialMacosStep5Description =>
      'システム設定→一般→ログイン項目を開き、コンピュータの起動時に自動的に開始されるように Stroom を追加します。';

  @override
  String get platformTutorialLinuxStep1Title => 'ウィンドウを閉じるときに最小化する';

  @override
  String get platformTutorialLinuxStep1Description =>
      'デフォルトでは、ウィンドウを閉じると Stroom がシステム トレイに非表示になります (ビルド時に StatusNotifierItem サポートと libayatana-appindicator3-dev を備えたデスクトップ環境が必要です)。トレイメニューから「メインウィンドウを表示」で元に戻してください。タスクの実行中は終了しないでください。終了するには、「バックグラウンド最適化」ページの「アプリケーションを完全に終了する」を使用するか、トレイメニューから「Quit Stroom」を選択します。';

  @override
  String get platformTutorialLinuxStep2Title => 'デスクトップ環境の設定';

  @override
  String get platformTutorialLinuxStep2Description =>
      'デスクトップ環境 (GNOME、KDE、XFCE など) に応じて、[システム設定] → [アプリ] を開き、Stroom を見つけて、バックグラウンド アクティビティが制限されていないことを確認します。';

  @override
  String get platformTutorialLinuxStep3Title => 'systemd サービスを使用する (オプション)';

  @override
  String get platformTutorialLinuxStep3Description =>
      '長時間実行されるバックグラウンド作業の場合は、systemd ユーザー サービスを作成します。 ~/.config/systemd/user/ の下に stroom.service ファイルを作成し、ExecStart を Stroom 実行可能ファイルに設定します。';

  @override
  String get platformTutorialLinuxStep4Title => 'スリープを無効にする';

  @override
  String get platformTutorialLinuxStep4Description =>
      '長時間実行する必要があるサーバーまたはデスクトップの場合は、/etc/systemd/logind.conf で HandleLidSwitch=ignore を設定して、蓋が閉じたときにスリープしないようにします。';

  @override
  String get platformTutorialLinuxStep5Title => '自動起動を有効にする';

  @override
  String get platformTutorialLinuxStep5Description =>
      'GNOME では、「調整」→「アプリケーションの起動」→「Stroom の追加」を使用します。または、~/.config/autostart/ に stroom.desktop ファイルを作成します。';

  @override
  String get platformTutorialWebStep1Title => 'タブを開いたままにしておきます';

  @override
  String get platformTutorialWebStep1Description =>
      'Web ブラウザはバックグラウンド サービスをサポートしていません。タスクの実行中は、「Stroom」タブを開いたままにしてください。タブを閉じるかページを更新すると、すぐに中断されます。';

  @override
  String get platformTutorialWebStep2Title => 'ブラウザがタブを一時停止しないようにする';

  @override
  String get platformTutorialWebStep2Description =>
      'ブラウザは、リソースを節約するために非アクティブなバックグラウンド タブをフリーズする場合があります。タスクの実行中は [Stroom] タブをフォアグラウンドに維持するか、定期的にページを操作してアクティブな状態を保ちます。';

  @override
  String get browserNavigationFailed => 'ページナビゲーションに失敗しました。アドレスが復元されました';

  @override
  String get browserAddressHint => 'Web アドレスを入力してください';

  @override
  String get browserUserScripts => 'ユーザースクリプト';

  @override
  String get browserSwitchToMobile => 'モバイル表示に切り替える';

  @override
  String get browserSwitchToDesktop => 'デスクトップビューに切り替える';

  @override
  String get browserUaSwitchedDesktop => 'デスクトップ ユーザー エージェントに切り替えました';

  @override
  String get browserUaSwitchedMobile => 'モバイル ユーザー エージェントに切り替えました';

  @override
  String get browserCookieRetentionOnTooltip => 'Cookie の永続化 (オン)';

  @override
  String get browserCookieRetentionOffTooltip => 'Cookie の永続化 (オフ)';

  @override
  String get browserCookiePersistenceEnabled => 'Cookie の永続化が有効になっています';

  @override
  String get browserCookiePersistenceDisabled => 'Cookie の永続性が無効になっています';

  @override
  String get browserSniffPanelHideTooltip => 'スニフパネルを非表示にする';

  @override
  String get browserSniffPanelShowTooltip => 'スニフパネルを表示';

  @override
  String get browserAdd => '追加';

  @override
  String get browserNoScripts => 'まだスクリプトはありません。 「追加」をタップして作成します。';

  @override
  String get browserUnnamedScript => '無題のスクリプト';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のルールに一致',
      one: '$count 件のルールに一致',
    );
    return '$_temp0';
  }

  @override
  String get browserScriptOriginManual => '手動で追加';

  @override
  String browserScriptVersion(Object version) {
    return '@バージョン $version';
  }

  @override
  String get browserScriptEnabled => '有効';

  @override
  String get browserScriptDisabled => '無効';

  @override
  String get browserScriptRuntimeError =>
      'このスクリプトで実行時エラーが発生しました。コードとページの互換性を確認してください。';

  @override
  String get browserScriptDelete => '消去';

  @override
  String get browserDeleteScriptTitle => 'スクリプトを削除しますか?';

  @override
  String get browserDeleteScriptConfirmation =>
      'このスクリプトはこのブラウザから削除されます。この操作は元に戻すことができません。';

  @override
  String get browserEditScript => 'スクリプトの編集';

  @override
  String get browserScriptName => 'スクリプト名';

  @override
  String get browserScriptCode => 'スクリプトコード（JavaScript）';

  @override
  String get browserAddScriptMethod => 'スクリプトの追加方法を選択する';

  @override
  String get browserImportFromUrl => 'URLからインポート';

  @override
  String get browserEnterManually => '手動で入力';

  @override
  String get browserScriptTrustWarningTitle => '信頼できるスクリプトのみをインポートする';

  @override
  String get browserScriptTrustWarning =>
      '信頼できるスクリプトのみを追加してください。追加しないとデータが漏洩する可能性があります。スクリプトは Web ページのコンテンツを読み取りまたは変更できます。';

  @override
  String get browserContinue => '続く';

  @override
  String get browserManualUserscriptLabel => 'Tampermonkey ユーザースクリプト';

  @override
  String get browserScriptImportUrl => 'スクリプトの URL';

  @override
  String get browserScriptImportFetch => 'プレビューを取得する';

  @override
  String get browserScriptPreview => 'スクリプトソースのプレビュー';

  @override
  String get browserScriptImportInvalidUrl => '有効な HTTPS URL を入力します。';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Greasy Fork .user.js URL または GitHub Raw URL を使用します。';

  @override
  String get browserScriptImportRedirectedUrl =>
      'URL がサポートされていないアドレスまたは安全でないアドレスにリダイレクトされました。';

  @override
  String get browserScriptImportNotScript =>
      '応答が空であるか、JavaScript スクリプトではないようです。';

  @override
  String get browserScriptImportNetworkError =>
      'スクリプトを取得できませんでした。 URL と接続を確認してください。';

  @override
  String browserScriptImportHttpError(Object status) {
    return 'サーバーは HTTP $status を返しました。';
  }

  @override
  String get browserCancel => 'キャンセル';

  @override
  String get browserSave => '保存';

  @override
  String get browserCookiesConfirmClear => 'クリアの確認';

  @override
  String get browserCookiesConfirmClearAll =>
      'すべての Cookie をクリアしますか?\nこの操作は元に戻すことができません。';

  @override
  String get browserCookiesClear => 'クリア';

  @override
  String get browserCookiesCancel => 'キャンセル';

  @override
  String get browserCookiesClearedAll => 'すべての Cookie がクリアされました';

  @override
  String get browserCookiesClearFailed => 'クリアできませんでした。もう一度やり直してください。';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return '$domain のすべての Cookie がクリアされました';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '$domain の Cookie をすべてクリアしますか?';
  }

  @override
  String get browserCookiesPageTitle => 'ブラウザのデータ管理';

  @override
  String get browserCookiesRetentionTitle => '終了時に Cookie を保持する';

  @override
  String get browserCookiesRetentionOn => '有効 — 終了時に Cookie が保持されます。';

  @override
  String get browserCookiesRetentionOff => '無効 — 終了時に Cookie がクリアされます';

  @override
  String get browserCookiesClearAllTitle => 'すべての Cookie をクリアする';

  @override
  String get browserCookiesClearAllDescription =>
      '保存されている Web サイトの Cookie をすべて削除します';

  @override
  String get browserCookiesEmptyTitle => '永続的なデータはありません';

  @override
  String get browserCookiesEmptyDescription =>
      '内蔵ブラウザを使用し、Cookie の永続化を有効にして保存されたデータをここに表示します。';

  @override
  String browserCookiesStoredCount(Object count) {
    return '保存された Cookie ($count)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の Cookie',
      one: '$count 個の Cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip => 'このドメインの Cookie をすべてクリアします';

  @override
  String get browserCookiesDeleteOneTooltip => 'このクッキーを削除します';

  @override
  String get browserCookiesDeletedOne => 'クッキーが削除されました';

  @override
  String get browserCookiesDeleteFailed => '削除できませんでした。もう一度やり直してください。';

  @override
  String get browserCookiesEmptyValue => '(空の値)';

  @override
  String get platformTutorialPageTitle => 'プラットフォームのチュートリアル';

  @override
  String get browserRecoveryOpenPage => '回復ページを開く';

  @override
  String galleryUnsupportedPreview(String format) {
    return '.$format ファイルではプレビューはサポートされていません';
  }

  @override
  String galleryCameraFailed(String error) {
    return '写真を撮影できませんでした: $error';
  }

  @override
  String get galleryPhotoSaved => '写真を保存しました';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return 'サポートされていない形式をスキップ: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '画像を # 枚インポートしました',
      one: '画像を # 枚インポートしました',
    );
    return '$_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '動画を # 本インポートしました',
      one: '動画を # 本インポートしました',
    );
    return '$_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get galleryFileReadFailed => 'ファイルデータを読み取れませんでした';

  @override
  String get galleryExportImageTitle => '画像のエクスポート';

  @override
  String get galleryExportVideoTitle => 'ビデオのエクスポート';

  @override
  String galleryExportedTo(String path) {
    return 'エクスポート先: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get galleryChooseExportDirectory => 'エクスポートディレクトリを選択してください';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 件のファイルをエクスポートしました',
      one: '# 件のファイルをエクスポートしました',
    );
    return '$_temp0';
  }

  @override
  String get galleryFolderExportTitle => 'エクスポートフォルダー';

  @override
  String get galleryWebFolderExportInfo =>
      'ブラウザはエクスポート ディレクトリを選択できません。フォルダー構造を保持した ZIP ファイルがダウンロードされます。';

  @override
  String get galleryDownloadZip => 'ZIPファイルをダウンロード';

  @override
  String get galleryExportImageFolderTitle => '画像フォルダーのエクスポート';

  @override
  String get galleryExportVideoFolderTitle => 'ビデオフォルダーをエクスポートする';

  @override
  String get galleryImagePageTitle => 'ギャラリー';

  @override
  String get galleryVideoPageTitle => '動画';

  @override
  String get galleryTakePhoto => '写真を撮る';

  @override
  String get galleryRecordVideo => '記録';

  @override
  String get galleryImport => '輸入';

  @override
  String get galleryExportToLocal => 'ローカルにエクスポート';

  @override
  String get galleryPlayVideo => '遊ぶ';

  @override
  String galleryCopyFailed(String error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get galleryVideoSaved => '保存されたビデオ';

  @override
  String galleryVideoRecordFailed(String error) {
    return '記録に失敗しました: $error';
  }

  @override
  String get galleryVideoLoadFailed => 'ビデオを読み込めませんでした';

  @override
  String get imageEditorSaveImageTitle => '画像の保存';

  @override
  String get imageEditorSaveImagePrompt => '画像の保存方法を選択します。';

  @override
  String get imageEditorOverwrite => '上書き';

  @override
  String get imageEditorSaveAs => '名前を付けて保存';

  @override
  String get imageEditorSavePhotoTitle => '写真を保存';

  @override
  String get imageEditorSavePhotoPrompt => 'この写真を保存しますか?';

  @override
  String get imageEditorDiscard => '破棄';

  @override
  String get imageEditorDoneLoading => '画像を生成中。お待ちください…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return 'クイック編集 – $fileName';
  }

  @override
  String get imageEditorNotReady => 'エディタの準備ができていません。しばらくしてからもう一度お試しください。';

  @override
  String imageEditorProcessingFailed(String error) {
    return '画像を処理できませんでした: $error';
  }

  @override
  String get imageEditorLoadFailed => '画像を読み込めませんでした';

  @override
  String get imageEditorProcessing => '画像を加工中。お待ちください…';

  @override
  String get imageEditorRotateLeft => '左に回転';

  @override
  String get imageEditorRotateRight => '右回転';

  @override
  String get imageEditorFlip => 'フリップ';

  @override
  String get imageEditorCrop => '作物';

  @override
  String get imageViewerImageSavedAsCopy => '画像をコピーとして保存しました';

  @override
  String get imageViewerImageUpdated => '画像を更新しました';

  @override
  String imageViewerSaveFailed(String error) {
    return '画像を保存できませんでした: $error';
  }

  @override
  String get imageViewerInvalidIndex => '無効な画像インデックス';

  @override
  String get galleryExportImageArchiveFileName => '画像エクスポート.zip';

  @override
  String get galleryExportVideoArchiveFileName => 'ビデオエクスポート.zip';

  @override
  String get galleryExportImageFolderArchiveFileName => '画像フォルダーのエクスポート.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName => 'ビデオフォルダーのエクスポート.zip';

  @override
  String get catCatchPageTitle => 'Web リソース ダウンローダー';

  @override
  String get catCatchAddTask => 'タスクの追加';

  @override
  String get catCatchOpenBrowser => '内蔵ブラウザ';

  @override
  String get catCatchEmptyState => 'ダウンロードタスクはまだありません';

  @override
  String get catCatchEmptyStateHint => '右上の + をタップしてダウンロードタスクを追加します';

  @override
  String get catCatchInvalidCapturedUrl => 'キャプチャされた URL は無効です';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return 'ブラウザからキャプチャ: $url';
  }

  @override
  String get catCatchEnterValidUrl => '少なくとも 1 つの有効な URL を入力してください';

  @override
  String get catCatchTaskAdded => 'タスクが追加されました';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のタスクを追加しました',
      one: '$count 件のタスクを追加しました',
    );
    return '$_temp0';
  }

  @override
  String get catCatchViewTaskList => 'タスクリストを表示する';

  @override
  String get catCatchUrlHint => 'ビデオ/オーディオ Web ページの URL を入力してください';

  @override
  String get catCatchDeleteTask => 'このタスクを削除します';

  @override
  String get catCatchHour => '営業時間';

  @override
  String get catCatchMinute => '分';

  @override
  String get catCatchSecond => '秒';

  @override
  String get catCatchDurationPreview => 'プレビュー:';

  @override
  String get catCatchDurationFormat => '時:分:秒';

  @override
  String get catCatchDurationFilterHint =>
      'オプション: ビデオ リソースを長さによってフィルタリングします。選択対象のすべてのリソースを表示するには、空白のままにします';

  @override
  String get catCatchVideoSaveTo => 'ビデオの保存先';

  @override
  String get catCatchAudioSaveTo => 'オーディオの保存先';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のタスクを追加しました',
      one: '$count 件のタスクを追加しました',
    );
    return '$_temp0';
  }

  @override
  String get catCatchStartAnalysis => '分析する';

  @override
  String get catCatchVideoFolderTitle => '動画保存フォルダ';

  @override
  String get catCatchAudioFolderTitle => '音声保存フォルダー';

  @override
  String get catCatchRootFolder => 'ルートフォルダー';

  @override
  String connectivityTestTitle(String title) {
    return '$title · 接続テスト';
  }

  @override
  String get connectivityTestJsonLabel => 'テスト内容(JSON)';

  @override
  String get connectivityTestJsonHelp =>
      '変更を直接実行または保存できます。 MCP は読み取り専用のツール/リストを使用します。検索ツールはクエリ/カウントを変更できます。 Todo はデフォルトでは読み取り専用です。';

  @override
  String connectivityTestSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get connectivityTestSaved => 'テスト内容が保存されました';

  @override
  String get connectivityTestClose => '閉じる';

  @override
  String get connectivityTestSaveContent => 'コンテンツの保存';

  @override
  String get connectivityTestTesting => 'テスト中…';

  @override
  String get connectivityTestRun => 'テストの実行';

  @override
  String get connectivityTestFailedSummary => 'テストを完了できませんでした';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds秒';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds ミリ秒';
  }

  @override
  String get messageSearchTitle => 'メッセージの検索';

  @override
  String get messageSearchHint => 'すべての会話にわたってメッセージを検索します...';

  @override
  String get messageSearchInitialState => 'キーワードを入力してすべての会話のメッセージを検索します';

  @override
  String get messageSearchEmptyState => '一致するメッセージが見つかりませんでした';

  @override
  String get messageSearchNewConversation => '新しい会話';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件一致',
      one: '$count 件一致',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => '文章';

  @override
  String get filesTabAudio => 'オーディオ';

  @override
  String get filesTabImages => '画像';

  @override
  String get filesTabVideos => '動画';

  @override
  String get filesReorderTabs => 'タブの並べ替え';

  @override
  String get filesReorderCancel => 'キャンセル';

  @override
  String get filesReorderDone => '終わり';

  @override
  String get bgTaskCancelled => 'キャンセル';

  @override
  String bgTaskAsrError(String details) {
    return '音声の文字起こしに失敗しました: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return '音声文字起こしの保存に失敗しました: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'OCR が失敗しました: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'OCR 結果の保存に失敗しました: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'OCR 結果が不完全です: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback => '一部の OCR ページが完了していませんでした';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return '・フェーズ $phaseElapsedMs ms ・$completedRequests リクエスト ・$completedChunks/$chunkCount チャンクが完了';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return 'オーディオをアップロード中$chunk $percent% · $bytes バイト$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return 'オーディオをアップロード中$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return '(チャンク $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return '転記$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return '転記中 (チャンク $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return '転記中 (チャンク受信 $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return '受信結果 $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => '受信結果';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return '転写中 ($index/$count チャンクが完了しました)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return '転記中 (チャンク $index/$count が返されました)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return '画像 $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return '$details をアップロードしています';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return '画像をアップロードしています $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'ASR リカバリ チェックポイントを保存できませんでした。リクエストの結果が不確かで、タスクが停止されました: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'ASR リカバリ チェックポイントを保存できませんでした。このチャンクは送信されなかったので、ローカル ストレージを修正した後に再試行できます: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'ASR チャンクの状態をキャンセルする前に保存できませんでした。このチャンクの結果は依然として不確実です: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'ASR 再試行オーディオを保存できませんでした。タスクは送信されませんでした: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError =>
      '別の音声ファイルを保存できませんでした。送信がキャンセルされました';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'OCR が不完全な結果を返しました (finish_reason=$finishReason)';
  }

  @override
  String ocrResultPageHeading(String index) {
    return '画像 $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return '画像 $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => '(結果の一部)';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return '一部の画像が完全に認識されませんでした: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return '画像 $index: 不完全な結果';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return '画像 $index: 認識に失敗しました';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => ';';

  @override
  String get bgTaskInterruptedOnRestart => 'アプリ再起動時に中断される';

  @override
  String get bgTaskOcrErrorDetailsHidden => 'OCR エラーの詳細は非表示になりました';

  @override
  String get bgTaskErrorDetailsHidden => 'エラーの詳細は非表示になりました';

  @override
  String get notificationBannerTaskCompletedHeading => 'タスクが完了しました';

  @override
  String get notificationBannerTaskFailedHeading => 'タスクが失敗しました';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return '完了したタスク: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return 'タスクが失敗しました: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title完成';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title が失敗しました: $error';
  }

  @override
  String get notificationUnknownError => '不明なエラー';

  @override
  String get desktopTrayTooltip => 'バックグラウンドでストルームが実行されています';

  @override
  String get desktopTrayOpen => 'オープンストルーム';

  @override
  String get desktopTrayShowMainWindow => 'メインウィンドウを表示';

  @override
  String get desktopTrayQuitStroom => 'ストルームをやめる';

  @override
  String get providerPresetExaDescription =>
      'セマンティック検索とキーワード検索を使用して、Web を検索し、ページ コンテンツを抽出し、Exa MCP を通じて詳細な調査をサポートします。';

  @override
  String get providerPresetExaApiKeyHint => 'Exa Web サイトから API キーを取得します。';

  @override
  String get providerPresetTavilyDescription =>
      '大規模な言語モデル向けに最適化されたリアルタイム Web 検索用の AI ネイティブ検索エンジン。';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Tavily から API キーを取得します。 ?tavilyApiKey= または Authorization: Bearer ヘッダーをサポートします。';

  @override
  String get providerPresetJinaDescription =>
      'Web コンテンツの抽出、埋め込みの生成、検索結果の取得を行うマルチモーダル AI サービス。';

  @override
  String get providerPresetJinaApiKeyHint =>
      'Jina AI API キー (ベアラー トークン) を Web サイトから取得します。';

  @override
  String get providerPresetFirecrawlDescription =>
      'ページをクリーンな Markdown または構造化データに変換する Web クローリングおよび抽出サービス。';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Firecrawl API キーを取得するか、無料利用枠の制限内でキーなしで試してみてください。';

  @override
  String get providerPresetZhipuDescription =>
      'Web ページを取得して理解するための Zhipu AI の Web リーダー MCP サービス。';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Zhipu AI Open Platform から API キー (ベアラー トークン) を取得します。';

  @override
  String get providerPresetBraveSearchDescription =>
      '高品質の Web 結果を提供する、プライバシーを重視した独立した検索エンジンです。';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Brave Search Web サイトから API キーを取得します。';

  @override
  String get providerPresetBochaDescription =>
      'Bocha AI Web 検索は、中国語ページのインテリジェントな検索結果を提供します。';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Bocha AI Open Platform から API キー (ベアラー トークン) を取得します。';

  @override
  String get providerPresetQueritDescription =>
      'Querit AI 検索は、インテリジェントな検索とコンテンツ検出を提供します。';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Querit WebサイトからAPIキー（ベアラートークン）を取得します。';

  @override
  String get providerPresetSearxngDescription =>
      'プライバシーに重点を置いて検索ソースを集約する自己ホスト型メタ検索エンジン。';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'SearXNG インスタンスの URL を設定します (例: http://your-instance:8080)。 API キーはオプションです。';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'TTS 合成が失敗しました: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return '元のエラー: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      'ネットワーク接続がタイムアウトしました。ネットワークまたは API アドレスを確認してください。';

  @override
  String get ttsErrorServerResponseTimeout =>
      'サーバーの応答がタイムアウトしました。後でもう一度試してください。';

  @override
  String ttsErrorConnectionFailed(String details) {
    return 'サーバーに接続できません ($details)';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return 'サーバーに接続できません。 Web アプリでの一般的な原因: CORS 制限または不正な API アドレス。 $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'API がエラーを返しました (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return '接続がタイムアウトしました。ネットワークを確認してください$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return '受信がタイムアウトしました。サーバーの応答が遅い$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'API キーが無効であるか、権限が拒否されました (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return 'リクエストが多すぎます。後でもう一度試してください (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'API エンドポイントが見つかりません (HTTP $status): $body\nAPI ベース URL が正しいことを確認してください$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return '内部サーバー エラー (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return 'サーバーがエラーを返しました (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return 'リクエストがキャンセルされました$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return 'サーバーに接続できません。 Web アプリでの一般的な原因: CORS 制限または不正な API アドレス。プロバイダー API アドレスが正しいこと、およびサーバーがクロスオリジン リクエストを許可していることを確認してください。$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return 'ネットワークエラー: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => '不明なネットワークエラー';

  @override
  String get ttsErrorNoResponseBody => '応答本文がありません';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return 'ストリーミング合成が失敗しました: $details';
  }

  @override
  String get mermaidEditorTitle => 'マーメイドチャートエディター';

  @override
  String get mermaidEditorModeEdit => '編集';

  @override
  String get mermaidEditorModeSplit => '編集 + プレビュー';

  @override
  String get mermaidEditorModePreview => 'プレビュー';

  @override
  String get mermaidEditorSwitchViewMode => 'ビューモードを切り替える';

  @override
  String get mermaidEditorSaveToTextStorage => 'テキストストレージに保存';

  @override
  String get mermaidEditorEmptyChart => 'グラフの内容が空のため保存できません';

  @override
  String get mermaidEditorSaveChartTitle => 'チャートの保存';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      '.mmd チャート ファイルを保存するフォルダーを選択または作成します';

  @override
  String get mermaidEditorFileNameHint => 'ファイル名を入力してください (.mmd は自動的に追加されます)';

  @override
  String get mermaidEditorEmptyFileName => 'ファイル名を空にすることはできません';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return 'テキストストレージに保存: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor => 'プレビューパネルとエディターパネルを入れ替える';

  @override
  String get mermaidEditorCodeLabel => 'マーメイドコード';

  @override
  String get mermaidEditorCodeHint => 'マーメイドコードを入力してください...';

  @override
  String get mermaidEditorSplitCodeLabel => 'コード';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'SSE 接続に失敗しました (HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'SSE 接続に失敗しました (HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable => 'SSE 接続に失敗しました: サーバーに接続できません';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'HTTP リクエストが失敗しました (HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => 'リクエストが失敗しました';

  @override
  String get sseNetworkRequestFailed => 'ネットワーク要求が失敗しました';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return 'ネットワーク要求が失敗しました (HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return 'ネットワーク要求が失敗しました (HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable => 'ネットワーク要求が失敗しました: サーバーに接続できません';

  @override
  String get sseRequestCancelled => 'リクエストがキャンセルされました';

  @override
  String get startupSafetyTitle => 'データの安全性の保護';

  @override
  String get startupSafetyExportButton => 'データのエクスポート';

  @override
  String get startupSafetyExitButton => 'アプリを終了する';

  @override
  String get startupSafetyUpdateButton => 'アプリを更新する';

  @override
  String get startupSafetyCheckingUpdates => 'アップデートをチェックしています...';

  @override
  String get startupSafetyUpToDate => '最新情報を入手しました';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return 'このデータは、新しいバージョンのアプリ ($version) によって作成されました。\n\nこのアプリのバージョンではデータを安全に読み取ることができません。続行するには最新バージョンをインストールしてください。データは変更されていません。';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      'データの安全性ステータスを確認できませんでした (ステータス マーカーが読み取れなかった、または無効でした)。\n\nフリーズ状態の可能性を上書きするのを避けるため、データの修復やフォーマットの移行を行わずに起動がブロックされています。まずデータ ファイルをエクスポートし、次にアプリを終了し、ステータス マーカーを修復して、もう一度試してください。';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return 'データ形式の移行に失敗しました ($part)。\n\nデータを保護するため、変更は加えられませんでした。以前のアプリのバージョンに戻るか、修正バージョンがリリースされるまで待ってからアップグレードしてください。';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return 'データ形式の移行に失敗しました ($part)。\n\nデータは移行前の状態に復元されました。これを保護するには、以前のアプリのバージョンに戻すか、修正バージョンがリリースされるまで待ってからアップグレードしてください。';
  }

  @override
  String get startupSafetyDataCorrupted =>
      'データが破損しているため、自動的に修復できません。\n\nさらなる被害を防ぐためにアプリは凍結されました。データ ファイルをエクスポートしてから、手動でインポートするか、再インストールします。';

  @override
  String get startupSafetyPreferencesUnavailable =>
      'アプリは起動チェックに必要な環境設定を読み取れなかったため、データを保護するために起動がブロックされました。\n\nストレージ容量または権限を確認して、アプリを再度開きます。';

  @override
  String get startupSafetyValidationUnavailable =>
      'アプリは起動データの安全性チェックを完了できなかったため、データを保護するために起動がブロックされました。\n\nブラウザの設定を確認して、アプリを再度開きます。';

  @override
  String startupSafetyCheckFailed(String detail) {
    return '起動チェックに失敗しました: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      '起動チェック後にデータの安全性ステータスが確認できませんでした（ステータスマーカーが読み取れなかった、または無効でした）。\n\nこれ以上のデータ変更を避けるため、起動が停止されました。データ ファイルをエクスポートし、アプリを終了し、ステータス マーカーを修復して、再試行してください。';

  @override
  String get catCatchConnectionTimeout =>
      '接続がタイムアウトしました。ネットワークまたはサーバーのステータスを確認してください。';

  @override
  String get catCatchSendTimeout => 'リクエストの送信中にタイムアウトになりました。';

  @override
  String get catCatchReceiveTimeout => 'サーバーに時間がかかりすぎるため、応答がタイムアウトしました。';

  @override
  String get catCatchCannotConnect => 'サーバーに接続できませんでした。';

  @override
  String get catCatchConnectionError => 'サーバーに接続できませんでした。 URLが正しいことを確認してください。';

  @override
  String get catCatchBadCertificate => 'サーバー証明書を検証できませんでした。';

  @override
  String catCatchBadResponse(int statusCode) {
    return 'サーバーがエラーを返しました (HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => 'リクエストはキャンセルされました。';

  @override
  String catCatchNetworkError(String message) {
    return 'ネットワークエラー: $message';
  }

  @override
  String get catCatchUnknownError => '不明なエラー';

  @override
  String catCatchOriginalError(String message) {
    return '元のエラー: $message';
  }

  @override
  String get catCatchWebDownloadHint => 'Web ブラウザはメディア ファイルを直接ダウンロードできません。';

  @override
  String get catCatchWebInstallExtension =>
      'CatCatch ブラウザ拡張機能をインストールして、もう一度試してください。';

  @override
  String get catCatchWebAuthorAttribution => '作者: 笨笨猫 (xifangczy)無料でオープンソース。';

  @override
  String get catCatchWebOfficialWarning =>
      'それが作成者のバージョンであることを確認してください。有料版や模倣版は避けてください。';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      'この機能にはサインインしたアカウントが必要です。右上隅にあるブラウザを使用してサインインします。';

  @override
  String get catCatchNoUsableMedia =>
      '使用可能なメディア リソースが見つかりませんでした。 URL をチェックして、Web サイトにアクセスできることを確認してください。';

  @override
  String get catCatchRedownloadFileMissing =>
      'ダウンロードしたファイルが見つからないため、ダウンロードに失敗しました。';

  @override
  String get catCatchRedownloadPathEmpty =>
      'ダウンロードされたファイルのパスが空であるため、ダウンロードに失敗しました。';

  @override
  String get catCatchWebBrowserRequired =>
      'このページはブラウザ環境がないとリソースを公開できません。モバイルまたはデスクトップでこの機能を使用してみるか、ビデオまたはオーディオ ファイルの直接 URL を貼り付けてください。';

  @override
  String get catCatchPlaylistNoSegments => 'プレイリストにはダウンロード可能なセグメントがありません。';

  @override
  String get catCatchDownloadedSourceMissing =>
      'ダウンロードしたソースファイルがありません。再度ダウンロードしてください。';

  @override
  String get appLogPageTitle => 'アプリケーションログ';

  @override
  String get appLogRefresh => 'リフレッシュ';

  @override
  String get appLogCleanupOldLogs => '古いログをクリーンアップする';

  @override
  String get appLogCleanupDone => '古いログがクリーンアップされました';

  @override
  String appLogRetentionNotice(int days) {
    return 'ログの保持: 最新の $days 日のみが保持されます。 $days 日より古いログは自動的に消去されます。';
  }

  @override
  String get appLogWebUnsupported => 'ローカル ログは Web ではサポートされていません';

  @override
  String get appLogNoFiles => 'ログファイルはまだありません';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '自動更新中（$count 回試行）...',
      one: '自動更新中（$count 回目の試行）...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated => 'アプリの実行中にログが生成される';

  @override
  String get appLogExport => '輸出';

  @override
  String get appLogDelete => '消去';

  @override
  String get appLogConfirmDeleteTitle => '削除の確認';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return 'ログファイル「$fileName」を削除しますか?';
  }

  @override
  String get appLogCancel => 'キャンセル';

  @override
  String appLogLoadFilesError(Object error) {
    return 'ログ ファイル リストのロードに失敗しました: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return 'ログ ファイル「$fileName」は存在しますが、読み取れませんでした。破損している可能性があります';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return 'ログ ファイル「$fileName」が見つかりませんでした。浄化されたかもしれない';
  }

  @override
  String appLogReadFileError(Object error) {
    return 'ログ ファイルの読み取りに失敗しました: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return '削除済み: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return '削除に失敗しました: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return 'ログファイル「$fileName」が見つかりませんでした';
  }

  @override
  String appLogPathCopied(String filePath) {
    return 'コピーされたパス: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行',
      one: '$count 行',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => 'すべてコピー';

  @override
  String get appLogStructuredView => '構造化されたビュー';

  @override
  String get appLogRawView => '生のビュー';

  @override
  String appLogCopyError(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get appLogCopyDone => 'すべてのログ内容をコピーしました';

  @override
  String get iosContinuedTaskTitle => 'バックグラウンドタスク';

  @override
  String get mermaidCatalogTypeFlowchart => 'フローチャート';

  @override
  String get mermaidCatalogDescriptionFlowchart => 'フローチャート — ステップ、分岐、ループを表示する';

  @override
  String get mermaidCatalogTypeSequenceDiagram => 'シーケンス図';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      'シーケンス図 — 参加者間の対話を表示します';

  @override
  String get mermaidCatalogTypeClassDiagram => 'クラス図';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      'クラス図 — クラスの属性とメソッド間の関係を表示します';

  @override
  String get mermaidCatalogTypeStateDiagram => '状態図';

  @override
  String get mermaidCatalogDescriptionStateDiagram => '状態図 — 状態遷移を表示する';

  @override
  String get mermaidCatalogTypeErDiagram => 'ER図';

  @override
  String get mermaidCatalogDescriptionErDiagram => 'ER 図 — エンティティの関係を表示する';

  @override
  String get mermaidCatalogTypeGantt => 'ガントチャート';

  @override
  String get mermaidCatalogDescriptionGantt => 'ガント チャート — プロジェクトのタイムラインを表示する';

  @override
  String get mermaidCatalogTypePie => '円グラフ';

  @override
  String get mermaidCatalogDescriptionPie => '円グラフ — 比例データを表示します';

  @override
  String get mermaidCatalogTypeJourney => 'ユーザージャーニー';

  @override
  String get mermaidCatalogDescriptionJourney =>
      'ユーザー ジャーニー - ユーザー エクスペリエンス フローを表示する';

  @override
  String get mermaidCatalogTypeGitGraph => 'Git グラフ';

  @override
  String get mermaidCatalogDescriptionGitGraph => 'Git グラフ — ブランチとコミットを表示する';

  @override
  String get mermaidCatalogTypeMindmap => 'マインドマップ';

  @override
  String get mermaidCatalogDescriptionMindmap => 'マインドマップ — 階層を表示する';

  @override
  String get mermaidCatalogTypeTimeline => 'タイムライン';

  @override
  String get mermaidCatalogDescriptionTimeline => 'タイムライン — イベントを時系列で表示します';

  @override
  String get mermaidCatalogTypeBlock => 'ブロック図';

  @override
  String get mermaidCatalogDescriptionBlock => 'ブロック図 — ブロックのレイアウトと関係を表示します';

  @override
  String get mermaidCatalogTypeRequirement => '要件図';

  @override
  String get mermaidCatalogDescriptionRequirement => '要件図 — 要件と実装の関係を表示します';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[開始]\n  B[処理]\n  C<MERMAID_OPEN_BRACE>条件<MERMAID_CLOSE_BRACE>\n  D[終了]\n\n  A --> B\n  B --> C\n  C -->|はい| D\n  C -->|いいえ| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"ユーザー\" as user\n  participant \"システム\" as system\n  participant \"データベース\" as database\n\n  user->>system: リクエストを送信\n  system->>database: データを検索\n  database-->>system: 結果を返す\n  system-->>user: 結果を表示';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String 名前\n    +int 年齢\n    +getName() String\n    +setName(String name) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String 学生ID\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String 教師ID\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"保留中\" as pending\n  state \"処理中\" as processing\n  state \"完了\" as completed\n  state \"失敗\" as failed\n  [*] --> pending\n  pending --> processing\n  processing --> completed\n  processing --> failed\n  failed --> pending\n  completed --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CUSTOMER ||--o<MERMAID_OPEN_BRACE> ORDER : place\n  ORDER ||--|<MERMAID_OPEN_BRACE> ORDER_ITEM : contain\n  PRODUCT ||--o<MERMAID_OPEN_BRACE> ORDER_ITEM : include\n  CUSTOMER <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    string email\n  <MERMAID_CLOSE_BRACE>\n  ORDER <MERMAID_OPEN_BRACE>\n    int id PK\n    int customer_id FK\n    date order_date\n  <MERMAID_CLOSE_BRACE>\n  PRODUCT <MERMAID_OPEN_BRACE>\n    int id PK\n    string name\n    float price\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title プロジェクト工程表\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section 要件定義\n  要件分析       :a1, 2024-01-01, 14d\n  試作設計       :a2, after a1, 10d\n\n  section 開発\n  フロントエンド開発 :b1, after a2, 20d\n  バックエンド開発   :b2, after a2, 20d\n  API 統合          :b3, after b1, 7d\n\n  section テスト\n  機能テスト       :c1, after b3, 10d\n  デプロイ         :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title データの内訳\n  \"カテゴリ A\" : 40\n  \"カテゴリ B\" : 25\n  \"カテゴリ C\" : 20\n  \"カテゴリ D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title ユーザー登録\n  section 登録\n    登録ページを開く: 5: ユーザー\n    情報を入力する: 3: ユーザー\n    リクエストを送信する: 4: ユーザー\n  section 認証\n    コードを受け取る: 3: システム\n    コードを入力する: 4: ユーザー\n    認証に成功する: 5: システム, ユーザー';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"初期コミット\"\n  commit id: \"機能 A を追加\"\n  branch develop\n  checkout develop\n  commit id: \"新機能を開発\"\n  commit id: \"不具合を修正\"\n  checkout main\n  merge develop\n  commit id: \"v1.0 をリリース\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((プロジェクト管理))\n    要件\n      機能要件\n      非機能要件\n    開発\n      フロントエンド\n      バックエンド\n    テスト\n      単体テスト\n      結合テスト\n    デプロイ\n      テスト環境\n      本番環境';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title プロジェクトの主な節目\n  2024-Q1 : 要件調査 : 計画の確認\n  2024-Q2 : 開発 : 機能の実装\n  2024-Q3 : テスト : 不具合修正 : 性能改善\n  2024-Q4 : デプロイ : 運用と保守';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"要件\"] B[\"開発\"] C[\"テスト\"]\n  D[\"デプロイ\"] E[\"運用\"] F[\"監視\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement UserLogin <MERMAID_OPEN_BRACE>\n    id: 1\n    text: アカウントとパスワードでユーザーがサインインできる\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element LoginPage <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element AuthService <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  LoginPage - satisfies -> UserLogin\n  AuthService - verifies -> UserLogin';

  @override
  String get mermaidCatalogDefaultFileName => '私のチャート';

  @override
  String get mermaidCatalogActionAddNode => 'ノードの追加';

  @override
  String get mermaidCatalogActionAddDecision => '決定を追加';

  @override
  String get mermaidCatalogActionAddEdge => 'エッジを追加する';

  @override
  String get mermaidCatalogActionAddSubgraph => 'サブグラフの追加';

  @override
  String get mermaidCatalogActionAddParticipant => '参加者を追加';

  @override
  String get mermaidCatalogActionAddRequest => 'リクエストの追加';

  @override
  String get mermaidCatalogActionAddResponse => '応答を追加';

  @override
  String get mermaidCatalogActionAddNote => 'メモを追加';

  @override
  String get mermaidCatalogActionAddClass => 'クラスの追加';

  @override
  String get mermaidCatalogActionAddInheritance => '継承の追加';

  @override
  String get mermaidCatalogActionAddRelationship => '関係を追加';

  @override
  String get mermaidCatalogActionAddAggregation => '集計の追加';

  @override
  String get mermaidCatalogActionAddState => '状態の追加';

  @override
  String get mermaidCatalogActionAddTransition => 'トランジションを追加する';

  @override
  String get mermaidCatalogActionAddStart => '開始の追加';

  @override
  String get mermaidCatalogActionAddEnd => '終わりを追加';

  @override
  String get mermaidCatalogActionAddEntity => 'エンティティの追加';

  @override
  String get mermaidCatalogActionAddOneToMany => '1対多の追加';

  @override
  String get mermaidCatalogActionAddManyToMany => '多対多の追加';

  @override
  String get mermaidCatalogActionAddOneToOne => '1対1を追加';

  @override
  String get mermaidCatalogActionAddPhase => 'フェーズの追加';

  @override
  String get mermaidCatalogActionAddTask => 'タスクの追加';

  @override
  String get mermaidCatalogActionAddDependentTask => '依存タスクを追加する';

  @override
  String get mermaidCatalogActionAddMilestone => 'マイルストーンを追加';

  @override
  String get mermaidCatalogActionAddCategory => 'カテゴリを追加';

  @override
  String get mermaidCatalogActionAddTitle => 'タイトルを追加';

  @override
  String get mermaidCatalogActionAddSystemTask => 'システムタスクの追加';

  @override
  String get mermaidCatalogActionAddMultiPersonTask => '複数人で行うタスクを追加する';

  @override
  String get mermaidCatalogActionAddCommit => 'コミットの追加';

  @override
  String get mermaidCatalogActionCreateBranch => 'ブランチの作成';

  @override
  String get mermaidCatalogActionSwitchBranch => '分岐を切り替える';

  @override
  String get mermaidCatalogActionMergeBranch => 'ブランチをマージする';

  @override
  String get mermaidCatalogActionAddBranch => 'ブランチの追加';

  @override
  String get mermaidCatalogActionAddChildBranch => '子ブランチを追加する';

  @override
  String get mermaidCatalogActionAddTopic => 'トピックを追加';

  @override
  String get mermaidCatalogActionAddPeriod => '期間を追加';

  @override
  String get mermaidCatalogActionAddBlock => 'ブロックの追加';

  @override
  String get mermaidCatalogActionAddColumns => '列を追加する';

  @override
  String get mermaidCatalogActionAddConnection => '接続の追加';

  @override
  String get mermaidCatalogActionAddChildBlock => '子ブロックを追加する';

  @override
  String get mermaidCatalogActionAddRequirement => '要件の追加';

  @override
  String get mermaidCatalogActionAddElement => '要素の追加';

  @override
  String get mermaidCatalogActionAddVerification => '検証を追加';

  @override
  String get mermaidCatalogGanttDependencyBaseTask => '依存関係ベースタスク';

  @override
  String get mermaidCatalogGanttDependentTaskName => 'フォローアップタスク';

  @override
  String get startupMigrationTitle => 'データ形式のアップグレードが完了しました';

  @override
  String get startupMigrationBody =>
      'データは新しい形式に移行されました。更新されたバージョンを使用するには、アプリを再起動します。';

  @override
  String get startupMigrationExit => 'アプリを終了する';

  @override
  String get startupMigrationRestart => '今すぐ再起動してください';

  @override
  String get startupRecoveryTitle => 'アプリ起動エラー';

  @override
  String get startupRecoveryFallbackMessage =>
      '起動中にデータ形式の問題が発生しましたが、自動的に修復されました。もう一度試してください。';

  @override
  String get startupRecoveryRetry => 'リトライ';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return '$stage$chunk の ASR $category: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return '、チャンク $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return 'リクエストが失敗しました: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return 'チャンク化された転写に失敗しました ($count チャンク、どれも成功しませんでした)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return 'チャンク化された転写は不完全です ($succeeded/$count チャンクは成功しました)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return '成功: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return '失敗: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return '結果が不確実: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return 'チャンク $index ($start ～ $end) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return 'チャンクステータスの保存に失敗しました: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      'リクエストの結果は不確実です。重複送信を避けるため、再試行は停止されました。オーディオを再度選択して、新しいタスクを作成します。';

  @override
  String asrRetryAudioLost(Object audioName) {
    return '元の音声ファイルが失われてしまいました。オーディオを再度選択して再試行します: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return '元の音声ファイルが壊れています。オーディオを再度選択して再試行します: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return '、チャンク $index';
  }

  @override
  String get asrChunkDetailsSeparator => ';';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'ASR 認識に失敗しました: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => '認証';

  @override
  String get asrFailureCategoryRateLimit => 'レート制限';

  @override
  String get asrFailureCategorySizeLimit => 'サイズ制限';

  @override
  String get asrFailureCategoryNetwork => 'ネットワーク';

  @override
  String get asrFailureCategoryResponseParsing => '応答の解析';

  @override
  String get asrFailureCategoryLocalProcessing => 'ローカル処理';

  @override
  String get asrFailureCategoryProvider => 'プロバイダー';

  @override
  String get asrFailureCategoryUnknown => '未知';

  @override
  String get asrFailureStagePreprocessing => '前処理';

  @override
  String get asrFailureStageEncoding => 'エンコーディング';

  @override
  String get asrFailureStageValidation => '検証';

  @override
  String get asrFailureStageRequest => 'リクエスト';

  @override
  String get asrFailureStageUploading => 'アップロードする';

  @override
  String get asrFailureStageWaiting => '待っている';

  @override
  String get asrFailureStageReceiving => '受信';

  @override
  String get asrFailureStageResponse => '応答';

  @override
  String get asrFailureStageParsing => '解析する';

  @override
  String get asrFailureStageStorage => 'ストレージ';

  @override
  String get chatMissingProvider => '最初にチャットプロバイダーを設定してください';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Anthropic API エラー: $detail';
  }

  @override
  String get anthropicStreamUnknownError => '不明なエラー';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'API リクエストが失敗しました (HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing => 'API キーが設定されていません。ファイルのアップロードは利用できません';

  @override
  String get fileUploadApiUrlMissing =>
      'API URL が設定されていません。ファイルのアップロードは利用できません';

  @override
  String get fileUploadContentEmpty => 'ファイルの内容が空です';

  @override
  String get fileUploadFilenameEmpty => 'ファイル名が空です';

  @override
  String get fileUploadMimeTypeEmpty => 'MIME タイプが空です';

  @override
  String get fileUploadPurposeEmpty => 'アップロード目的が空です';

  @override
  String get fileUploadCanceled => 'ファイルのアップロードがキャンセルされました';

  @override
  String get fileUploadCreateMissingId =>
      'アップロードの作成に失敗しました: 応答にアップロード ID がありません';

  @override
  String get fileUploadPartMissingId => 'パーツのアップロードに失敗しました: 応答にパーツ ID がありません';

  @override
  String get fileUploadCompleteMissingFile =>
      'アップロードの完了に失敗しました: 応答にファイル オブジェクトがありません';

  @override
  String get fileUploadMissingFileId => 'ファイルのアップロードに失敗しました: 応答にファイル ID がありません';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return 'ファイルのアップロード要求が失敗しました (HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return 'ファイルのアップロード要求が失敗しました: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'APIキーが設定されていません';

  @override
  String chatStreamError(Object detail) {
    return 'API ストリーム エラー: $detail';
  }

  @override
  String get chatChoicesMissing => 'API 応答には選択肢がありません';

  @override
  String get chatContentBlocksMissing => 'API 応答にはコンテンツ ブロックがありません';

  @override
  String get chatResponseContentEmpty => 'API 応答コンテンツが空です';

  @override
  String chatRequestFailed(Object detail) {
    return 'リクエストが失敗しました: $detail';
  }

  @override
  String get startupTagline => 'あなたの学習アシスタント';

  @override
  String get startupProgressDataSafety => 'データの安全性をチェックしています...';

  @override
  String get startupProgressFormatVersion => 'データ形式のバージョンを確認しています...';

  @override
  String get startupProgressDataFormat => 'データ形式を検証しています...';

  @override
  String get startupProgressDataIntegrity => 'データの整合性をチェックしています...';

  @override
  String get startupProgressResults => 'チェック結果を処理しています...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return '起動完了（注：$warning）';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      'データチェックが完了しました。アプリを起動する準備をしています。';

  @override
  String get startupProgressReady => 'アプリを起動する準備をしています。';

  @override
  String startupWarningErrorCount(Object count) {
    return '$count データの問題が見つかりました:';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return '$count 警告:';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      'プロバイダー エントリの形式が無効です。JSON 配列が必要です。';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return 'プロバイダー エントリ $index が null であるか、無効なタイプです。';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return 'プロバイダー エントリ $index に ID がないか、ID が空です。';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return 'プロバイダー エントリ $index に型がないか、型が空です。';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return 'プロバイダー エントリ $index に名前がないか、名前が空です。';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return 'プロバイダーエントリー $index フィールド $field は有効なリストではありません。';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return 'プロバイダー エントリ $index、$field には、解析エラーを引き起こす可能性のある無効な項目が含まれています。';
  }

  @override
  String get startupIssueConversationsInvalid => '会話の形式が無効です。JSON 配列が必要です。';

  @override
  String startupIssueConversationInvalid(Object index) {
    return '会話 $index が null であるか、無効なタイプです。';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return '会話 $index に ID がありません。';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return '会話 $index にメッセージ フィールドがありません。';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return '会話 $index メッセージ フィールドは有効なリストではありません。';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return 'プロバイダー エントリ $index は不明なプロバイダー タイプ「$type」を使用しているため、正しく動作しない可能性があります。';
  }

  @override
  String get startupErrorTitle => 'アプリの起動に失敗しました';

  @override
  String startupErrorDetails(Object error) {
    return 'エラー: $error';
  }

  @override
  String get renderErrorTitle => 'インターフェースレンダリングエラー';

  @override
  String get renderErrorDebugTitle => 'インターフェースレンダリングエラー（デバッグモード）';

  @override
  String get renderErrorRestartMessage => 'アプリを再起動してみてください。';

  @override
  String get batchDlgFileName => 'ファイル名';

  @override
  String get batchDlgFolderName => 'フォルダ名';

  @override
  String get batchDlgFileNameConflict => 'このフォルダー内の別のファイルは同じ名前です';

  @override
  String get batchDlgFolderNameConflict => '同じ名前のフォルダーがターゲットの場所にすでに存在します';

  @override
  String get batchDlgFolderNameSwapConflict => '同じバッチ内でフォルダー名を交換することはできません';

  @override
  String get batchDlgControlCharacterError => '名前に制御文字を含めることはできません';

  @override
  String get batchDlgNameWhitespaceError =>
      '名前の先頭または末尾を空白にすることはできません。空白のクリーンアップ ルールを使用する';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind を空にすることはできません';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind は空白で終わることはできません';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind は $count 文字を超えることはできません';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind には Windows で無効な文字を含めることはできません';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind はピリオドで終わることはできません';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind は Windows の予約名を使用できません';
  }

  @override
  String get batchDlgIntermediateNameTooLong => '中間名が長すぎます。ルールを調整する';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return 'このアイテムには $date 日付がありません。テンプレートを調整する';
  }

  @override
  String get batchDlgCreatedDate => '創造';

  @override
  String get batchDlgModifiedDate => '修正';

  @override
  String get connectivityTestHttpSuccess => 'HTTPツールリクエストが成功しました';

  @override
  String get connectivityTestHttpFailure => 'HTTPツールリクエストが失敗しました';

  @override
  String get connectivityTestInvalidMcpConfig => '無効な MCP 構成';

  @override
  String get connectivityTestMissingTransport => '有効なトランスポート タイプの構成がありません。';

  @override
  String get connectivityTestStdioUnsupported =>
      'stdio はこのプラットフォームではサポートされていません';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP では、ローカル プロセスを開始する必要があります。 Stroom デスクトップ アプリでテストします。';

  @override
  String get connectivityTestInvalidContent => '無効なテスト内容';

  @override
  String get connectivityTestMethodMustBeString => 'メソッドは文字列である必要があります。';

  @override
  String get connectivityTestUnsupportedMethod => 'サポートされていないテスト方法';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      'リモート ビジネス データの書き込みを避けるため、MCP 接続テストでは読み取り専用ツール/リスト メソッドのみが許可されます。';

  @override
  String get connectivityTestParamsMustBeObject =>
      'params は JSON オブジェクトである必要があります。';

  @override
  String get connectivityTestMcpConnectionFailed => 'MCP サービスに接続できませんでした';

  @override
  String get connectivityTestCheckConnectionSettings =>
      'アドレス、認証、ネットワークを確認するか、アプリ ログで接続の詳細を確認してください。';

  @override
  String get connectivityTestRemainingToolsOmitted => ';残りのツールは省略';

  @override
  String get connectivityTestMcpSuccess => 'MCP 接続テストに成功しました';

  @override
  String connectivityTestToolNames(Object names) {
    return '：$names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return '接続とツール/リストのリクエストは成功しました。 $count ツール$names$suffix が見つかりました。';
  }

  @override
  String get connectivityTestTodoMutationBlocked =>
      'テストパラメータがtodoデータを変更する可能性がある';

  @override
  String get connectivityTestTodoReadOnly =>
      '現在のセッションの Todo リストを保護するには、接続テストで Todo を省略するか、null に設定します。';

  @override
  String get connectivityTestUnknownBuiltin => '不明な組み込みツール';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return 'ツール「$toolName」のテスト実行プログラムが見つかりません。';
  }

  @override
  String get connectivityTestBuiltinSuccess => '組み込みツールのテストに成功しました';

  @override
  String get connectivityTestBuiltinFailure => '組み込みツールのテストに失敗しました';

  @override
  String get connectivityTestTopLevelObjectRequired =>
      'テスト コンテンツはトップレベルの JSON オブジェクトである必要があります。';

  @override
  String get connectivityTestRequestTimeout =>
      'リクエストがタイムアウトしました。サービスの応答とネットワークを確認してください。';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'MCP リクエストがタイムアウトしました: $method';
  }

  @override
  String get connectivityTestResultTruncated => '… (結果は切り捨てられます)';

  @override
  String get toolResultWebSearchEmptyQuery => 'エラー: 検索クエリを空にすることはできません。';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return 'エラー: サポートされていない検索エンジン「$source」。サポートされている値: google、bing、baidu。';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return '推奨エンジン $preferred $reason。 $fallbackに切り替わりました。';
  }

  @override
  String get toolResultWebSearchNotFound => '該当する検索結果は見つかりませんでした。';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return '関連する検索結果が見つかりませんでした ($sources は明示的に結果を返しませんでした)。';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return '検索が不完全です: $sources は明示的に結果を返しませんでした。他のエンジンが利用できなかったか、解析できないページが返されました: $failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return 'エラー: すべての検索エンジンが利用できません。 $failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return '$source からの検索結果:';
  }

  @override
  String get toolResultWebSearchLinkLabel => 'リンク';

  @override
  String get toolResultWebSearchSummaryLabel => 'まとめ';

  @override
  String get toolResultWebSearchEmptyResults => '該当する検索結果は見つかりませんでした。';

  @override
  String get toolResultTodoInvalid =>
      'エラー: todos パラメータは配列である必要があります (省略するか、todo リストを読み取るには null を渡します)。';

  @override
  String get toolResultTodoEmpty => 'まだToDo項目がありません。';

  @override
  String toolResultTodoCount(Object count) {
    return 'アクティブな Todo アイテム: $count';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return 'エラー: MCP サーバー「$server」に再接続できませんでした。';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return 'エラー: MCP サーバー \"$server\" は現在利用できません。';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return 'エラー: MCP サーバー「$server」は接続に失敗したか、ツールを返しませんでした。サーバーの構成を確認してください。';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return 'リアルツール「$tool」は、このサーバー上でコール名「$alias」で公開されています。';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return 'ツール「$tool」は複数の MCP サーバーによって提供されます。一致するコール名 $routes を使用します。';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return 'エラー: 実際のツール「$tool」には名前の競合があります。上記の呼び出し名のいずれかを使用します。';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return 'エラー: MCP サーバー \"$server\" には \"$tool\" という名前のツールがありません。';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return 'このサーバーで利用可能なツール: $tools。代わりにこれらの名前を使用してください。';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return 'エラー: MCP ツール \"$tool\" には現在競合するエイリアスがあります。一致するコール名 $routes を使用します。';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return 'エラー: ツール「$tool」は無効になっています。';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return 'エラー: 不明なツール「$tool」';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => '結果が返されませんでした';

  @override
  String get toolResultWebSearchFallbackUnavailable => '一時的に利用できなくなりました';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '(MCPサーバー$server)';
  }

  @override
  String get toolResultWebSearchUnparsedResults => '解析できないページが返されました';

  @override
  String get toolResultSearchTitleLabel => 'タイトル';

  @override
  String get toolResultSearchContentLabel => 'コンテンツ';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return 'エラー: $provider API キーが構成されていません。設定で設定します。';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return 'エラー: $provider インスタンス URL が構成されていません。設定で設定します。';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return 'エラー: $provider リクエストが失敗しました (HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return 'エラー: $provider リクエストが失敗しました: $detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return 'エラー: 不明な HTTP ツール「$provider」';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return 'エラー: MCP サーバー「$server」が接続されていません。';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return 'エラー: MCP ツール「$tool」からの応答がありません。';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return 'エラー: $detail';
  }

  @override
  String get httpToolBraveDescription =>
      'Brave Search API を使用して Web を検索します。 API キーが必要です。';

  @override
  String get httpToolBochaDescription =>
      'Bocha AI Search API を使用して Web を検索します。 API キーが必要です。';

  @override
  String get httpToolQueritDescription =>
      'Querit Search を使用して Web を検索します。 API キーが必要です。';

  @override
  String get httpToolSearxngDescription =>
      '検索ソースを集約する、プライバシーを重視した自己ホスト型メタ検索エンジン。インスタンス URL が必要です。';

  @override
  String get httpToolSearchQueryDescription => '検索用語。';

  @override
  String get httpToolSearchCountDescription => '返される結果の数。';

  @override
  String get httpToolSearchCountMax20Description => '返される結果の数 (最大 20)。';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return 'インポートされた $decks デッキ、$notes ノート、および $cards カード';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return '選択した .apkg ファイルが見つかりませんでした: $path';
  }

  @override
  String get backupRestoreApkgInvalidArchive =>
      '選択した .apkg ファイルが破損しているか、有効なアーカイブではありません。';

  @override
  String get backupRestoreApkgCollectionMissing =>
      '.apkg ファイルには collection.anki2 が含まれていません。';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return 'デッキをインポートまたはエクスポートする前に Anki フラッシュカードを開きます: $path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt => 'Anki コレクション データベースが破損しています。';

  @override
  String backupRestoreApkgLocalFileFailure(String path) {
    return 'ローカルの Anki ファイルにアクセスできませんでした: $path';
  }

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return 'このパスへのアクセス中に .apkg 操作が失敗しました: $path';
  }

  @override
  String get backupRestoreApkgOperationFailed =>
      'ファイルまたはデータベースを読み取れなかったため、.apkg 操作は失敗しました。';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return 'Anki デッキをこのデータベースからパッケージ化できませんでした: $path';
  }

  @override
  String get ankiSyncStatusProtocolFailed =>
      '同期サーバーの応答が無効または不完全です。サーバーが Anki sync v10 をサポートしていることを確認します。';

  @override
  String get ankiSyncStatusLoginRequired => '続行する前に、Anki 同期にログインしてください。';

  @override
  String get ankiSyncStatusInvalidServerUrl =>
      '有効な HTTP または HTTPS 同期サーバーのアドレスを入力します。';

  @override
  String get ankiSyncStatusHttpsRequired =>
      'リモートのセルフホスト型同期サーバーは HTTPS を使用する必要があります。';

  @override
  String get ankiSyncStatusConnectionTimeout =>
      '同期リクエストがタイムアウトしました。サーバーアドレスとネットワークを確認して再実行してください。';

  @override
  String get ankiSyncStatusTlsFailure =>
      'サーバー証明書を検証できませんでした。証明書を確認するか、カスタム CA を構成します。';

  @override
  String get ankiSyncStatusConnectionFailure =>
      '同期サーバーに接続できませんでした。アドレスとネットワークを確認してください。';

  @override
  String get ankiSyncStatusRequestFailure =>
      '同期リクエストは失敗しました。サーバーとネットワークを確認して、再試行してください。';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return '同期サーバーは HTTP $statusCode を返しました。';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return '同期応答が $limitMb MB 制限を超えました。';
  }

  @override
  String get ankiSyncStatusLocalFileFailure =>
      'ローカル同期ファイルを読み取ることも、クリーンアップすることもできませんでした。ディスクアクセスを確認して再試行してください。';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      'コレクションを開いたり、更新したり、SQLite/スキーマ検証に合格したりできませんでした。有効なコレクションを復元するか、再度ダウンロードします。';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return '同期サーバーは要求を拒否しました (HTTP $statusCode)。ログイン認証情報とサーバー権限を確認してください。';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return '同期エンドポイントが見つかりませんでした (HTTP $statusCode)。サーバーアドレスを確認してください。';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      'メディア同期サーバーが無効な応答を返しました。 Anki メディア同期がサポートされていることを確認して、もう一度試してください。';

  @override
  String get ankiSyncStatusMediaIndexCorrupt =>
      'ローカル メディア同期インデックスが破損しています。メディア同期データをリセットして、再試行してください。';

  @override
  String get ankiSyncStatusMediaIndexFailure =>
      'ローカル メディア同期インデックスを読み取ることも更新することもできませんでした。';

  @override
  String get ankiSyncStatusMediaChecksumMismatch =>
      'ダウンロードしたメディア ファイルのチェックサム検証に失敗しました。メディアの同期を再試行します。';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return 'メディア ファイル「$filename」には、ローカルとサーバーの変更内容が競合しています。再試行する前に、バックアップして名前の競合を解決してください。';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return 'メディアファイル名「$filename」は同期できません。有効な Anki ファイル名に名前を変更して、再試行してください。';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return 'メディア ファイルが空であるか、$limitMb MB 制限を超えています。';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return 'メディア アーカイブには $count エントリが含まれています。最大値はマニフェストを含めて $limit です。';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed =>
      'メディア同期の検証に失敗しました。同期を再試行します。';

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      'Web 上で同期するには、AnkiWeb にサインインします。クラウドアイコンで Anki 設定を開いてログインします。';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      'Web 上でデッキを参照または管理するには、クラウド アイコンを使用して AnkiWeb にサインインします。';

  @override
  String get ankiStatsUnsupportedPlatform => 'Anki 統計はこのプラットフォームでは利用できません。';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      'デバイスの時計は同期サーバーと 5 分以上異なります。時計を修正して再試行してください。';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      '同期健全性チェックが失敗し、ローカルの変更がロールバックされました。サーバー コレクションを完全にダウンロードして、再試行してください。';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      'このコレクションは増分的に同期できません。続行するには、完全なアップロードまたはダウンロードを選択してください。';

  @override
  String get ankiSyncStatusIncrementalSyncFailed =>
      '増分同期を完了できませんでした。サーバーと接続を確認して、再試行してください。';

  @override
  String get emojiCategorySmileys => 'スマイリー';

  @override
  String get emojiCategoryPeople => '人々';

  @override
  String get emojiCategoryAnimals => '動物';

  @override
  String get emojiCategoryFood => '食べ物';

  @override
  String get emojiCategoryActivities => '活動内容';

  @override
  String get emojiCategoryTravel => '旅行';

  @override
  String get emojiCategoryObjects => 'オブジェクト';

  @override
  String get emojiCategorySymbols => '記号';

  @override
  String get emojiCategoryFlags => 'フラグ';

  @override
  String get languageNameSpanish => 'スペイン語';

  @override
  String get languageNameJapanese => '日本語';

  @override
  String get languageNameFrench => 'フランス語';

  @override
  String get languageNameGerman => 'ドイツ語';

  @override
  String get languageNameArabic => 'アラビア語';

  @override
  String fileManagerDeleteEmptyFolderWithSubfoldersConfirm(
    num count,
    Object name,
  ) {
    return '空のフォルダー「$name」を削除しますか? 配下の $count 個のサブフォルダーも削除されます。';
  }

  @override
  String get providerMaxUploadSizePositive => '最大アップロードサイズは正の数である必要があります。';
}
