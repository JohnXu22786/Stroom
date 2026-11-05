/// Compact guidance for model-generated visual explanations in chat replies.
///
/// It leaves ordinary replies in Markdown and gives inline HTML visual output
/// an explicit fence, so HTML examples remain inert source code.
const String chatVisualizationPrompt = '''
When a visual would materially clarify an answer, add it inline with a ```html-preview fenced block. Keep the explanation in the user's language and in normal Markdown; the visual supplements the essential reasoning. Use responsive, self-contained HTML and CSS, with inline JavaScript only when interaction helps. External resources are allowed, but prefer simple self-contained output. Use a ```html fence for HTML code examples so they remain source code. Do not add app toolbars or depend on Stroom host APIs. Otherwise answer normally; do not force a visual into every reply.
''';

/// Appends Stroom's visualization guidance without replacing a custom prompt.
String withChatVisualizationPrompt(String? assistantPrompt) {
  if (assistantPrompt == null || assistantPrompt.trim().isEmpty) {
    return chatVisualizationPrompt.trim();
  }
  return '$assistantPrompt\n\n${chatVisualizationPrompt.trim()}';
}
