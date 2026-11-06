import '../l10n/app_localizations.dart';

/// Localizes an unchanged built-in provider description for display only.
///
/// Persisted descriptions can be user-edited, so only an exact match for the
/// original built-in Chinese default is translated. All other text is returned
/// unchanged.
String? localizedProviderPresetDescription(
  AppLocalizations l10n,
  String? providerName,
  String? description,
) {
  final preset = switch (providerName) {
    'Exa' => (
        '通过 Exa MCP 接口进行网络搜索、内容提取和深度研究，支持语义搜索与关键词搜索',
        l10n.providerPresetExaDescription,
      ),
    'Tavily' => (
        'AI 原生搜索引擎，专为大语言模型优化的实时网络搜索服务',
        l10n.providerPresetTavilyDescription,
      ),
    'Jina AI' => (
        '多模态 AI 服务，支持网页内容提取、Embedding 和搜索结果抓取',
        l10n.providerPresetJinaDescription,
      ),
    'Firecrawl' => (
        '网页抓取与内容提取服务，可将任意网页转为干净的 Markdown 或结构化数据',
        l10n.providerPresetFirecrawlDescription,
      ),
    'Zhipu' => (
        '智谱 AI 开放平台的网页阅读器 MCP 服务，支持网页内容抓取与理解',
        l10n.providerPresetZhipuDescription,
      ),
    'Brave Search' => (
        '隐私优先的独立搜索引擎，提供高质量网络搜索结果（需配置 API Key）',
        l10n.providerPresetBraveSearchDescription,
      ),
    'Bocha' => (
        '博查 AI 网络搜索服务，提供智能化的中文网页搜索结果',
        l10n.providerPresetBochaDescription,
      ),
    'Querit' => (
        'Querit AI 搜索服务，提供智能搜索与内容发现能力',
        l10n.providerPresetQueritDescription,
      ),
    'Searxng' => (
        '自托管的元搜索引擎，聚合多种搜索源，注重隐私保护（需自建实例）',
        l10n.providerPresetSearxngDescription,
      ),
    _ => null,
  };
  return _localizeExactDefault(description, preset);
}

/// Localizes an unchanged built-in API/setup hint for display only.
String? localizedProviderPresetApiKeyHint(
  AppLocalizations l10n,
  String? providerName,
  String? apiKeyHint,
) {
  final preset = switch (providerName) {
    'Exa' => ('请在 Exa 官网获取 API Key', l10n.providerPresetExaApiKeyHint),
    'Tavily' => (
        '请在 Tavily 官网获取 API Key，支持 ?tavilyApiKey= 或 Authorization: Bearer',
        l10n.providerPresetTavilyApiKeyHint,
      ),
    'Jina AI' => (
        '请在 Jina AI 官网获取 API Key (Bearer Token)',
        l10n.providerPresetJinaApiKeyHint,
      ),
    'Firecrawl' => (
        '请在 Firecrawl 官网获取 API Key，也可免 Key 试用（免费版有限额）',
        l10n.providerPresetFirecrawlApiKeyHint,
      ),
    'Zhipu' => (
        '请在智谱 AI 开放平台获取 API Key (Bearer Token)',
        l10n.providerPresetZhipuApiKeyHint,
      ),
    'Brave Search' => (
        '请在 Brave Search 官网获取 API Key',
        l10n.providerPresetBraveSearchApiKeyHint,
      ),
    'Bocha' => (
        '请在博查 AI 开放平台获取 API Key (Bearer Token)',
        l10n.providerPresetBochaApiKeyHint,
      ),
    'Querit' => (
        '请在 Querit 官网获取 API Key (Bearer Token)',
        l10n.providerPresetQueritApiKeyHint,
      ),
    'Searxng' => (
        '设置 SearXNG 实例 URL（如 http://your-instance:8080），可选 API Key',
        l10n.providerPresetSearxngApiKeyHint,
      ),
    _ => null,
  };
  return _localizeExactDefault(apiKeyHint, preset);
}

String? _localizeExactDefault(String? storedValue, (String, String)? preset) {
  if (storedValue == null || preset == null || storedValue != preset.$1) {
    return storedValue;
  }
  return preset.$2;
}
