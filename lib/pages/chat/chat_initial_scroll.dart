/// Resolves the initial scroll offset for a freshly loaded conversation.
///
/// The chat page should open showing the TOP of the last user message at the
/// top of the viewport, so the user immediately sees their most recent
/// question with the reply below it (this is what they care about). If the
/// content after the last user message (the assistant reply) fits within one
/// viewport height — "凑不满一个屏幕" — the bottom is preferred instead:
/// everything is visible and the very end of the conversation is shown.
///
/// [lastUserMessageTop] and [tailBottom] are measured geometry in scroll
/// content space (the top of the last user message and the bottom of the
/// LAST message in the list); [maxScrollExtent] is the exact bottom offset
/// of the scroll view.
double resolveInitialChatScrollTarget({
  required double lastUserMessageTop,
  required double tailBottom,
  required double maxScrollExtent,
  required double viewportDimension,
}) {
  final tailFitsInViewport =
      tailBottom - lastUserMessageTop <= viewportDimension + 1.0;
  final target = tailFitsInViewport ? maxScrollExtent : lastUserMessageTop;
  return target.clamp(0.0, maxScrollExtent);
}
