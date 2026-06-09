import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/conversation_provider.dart';

// ============================================================================
// Data classes for search results
// ============================================================================

/// A match found within a single message.
class SearchResultMatch {
  final ChatMessage message;
  final int matchStart;
  final int matchEnd;

  const SearchResultMatch({
    required this.message,
    required this.matchStart,
    required this.matchEnd,
  });

  String get messageId => message.id;
}

/// A conversation that contains one or more matches.
class SearchResult {
  final Conversation conversation;
  final List<SearchResultMatch> matches;

  const SearchResult({
    required this.conversation,
    required this.matches,
  });

  int get matchCount => matches.length;
}

// ============================================================================
// Message Search Page
// ============================================================================

/// Full-screen page for searching message content across all conversations.
///
/// Returns a [Map] with keys `conversationId` and `query` when a result is
/// selected via [Navigator.pop].
class MessageSearchPage extends ConsumerStatefulWidget {
  const MessageSearchPage({super.key});

  @override
  ConsumerState<MessageSearchPage> createState() => _MessageSearchPageState();

  // --------------------------------------------------------------------------
  // Static helpers (also used by tests)
  // --------------------------------------------------------------------------

  /// Search message content across all [conversations] for [query].
  /// Returns results sorted by match count descending.
  static List<SearchResult> searchMessageContents(
    List<Conversation> conversations,
    String query,
  ) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();
    final results = <SearchResult>[];

    for (final conv in conversations) {
      final matches = <SearchResultMatch>[];
      for (final msg in conv.messages) {
        final lowerContent = msg.content.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerContent.indexOf(lowerQuery, start);
          if (idx == -1) break;
          matches.add(SearchResultMatch(
            message: msg,
            matchStart: idx,
            matchEnd: idx + lowerQuery.length,
          ));
          start = idx + lowerQuery.length;
        }
      }
      if (matches.isNotEmpty) {
        results.add(SearchResult(conversation: conv, matches: matches));
      }
    }

    // Sort by match count descending, then by conversation title
    results.sort((a, b) {
      final cmp = b.matchCount.compareTo(a.matchCount);
      if (cmp != 0) return cmp;
      return a.conversation.title.compareTo(b.conversation.title);
    });

    return results;
  }

  /// Extract a snippet of text around the match for display.
  /// Returns at most ~87 characters with the match in the center.
  static String getSnippet(String text, int matchStart, int matchEnd) {
    const contextChars = 40;
    final textLen = text.length;

    int snippetStart = matchStart - contextChars;
    int snippetEnd = matchEnd + contextChars;

    if (snippetStart < 0) snippetStart = 0;
    if (snippetEnd > textLen) snippetEnd = textLen;

    String snippet = text.substring(snippetStart, snippetEnd);

    if (snippetStart > 0) snippet = '…$snippet';
    if (snippetEnd < textLen) snippet = '$snippet…';

    return snippet;
  }
}

class _MessageSearchPageState extends ConsumerState<MessageSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _results = [];
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      final conversations = ref.read(conversationsProvider);
      _results = MessageSearchPage.searchMessageContents(conversations, value);
    });
  }

  void _onResultTapped(SearchResult result) {
    Navigator.of(context).pop({
      'conversationId': result.conversation.id,
      'query': _query,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('全局消息搜索'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Search input ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索所有对话中的消息...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // ── Results or empty state ──
          Expanded(
            child: _query.isEmpty
                ? _buildInitialState(cs)
                : _results.isEmpty
                    ? _buildEmptyState(cs)
                    : _buildResultsList(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            '输入关键词搜索所有对话中的消息',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            '未找到匹配的消息',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildResultTile(result, cs);
      },
    );
  }

  Widget _buildResultTile(SearchResult result, ColorScheme cs) {
    final conv = result.conversation;
    final title = conv.title.isEmpty ? '新对话' : conv.title;

    // Build a preview of the first match
    const contextChars = 40;
    final firstMatch = result.matches.first;
    final snippetStart = (firstMatch.matchStart - contextChars).clamp(0, firstMatch.message.content.length);
    final snippet = MessageSearchPage.getSnippet(
      firstMatch.message.content,
      firstMatch.matchStart,
      firstMatch.matchEnd,
    );

    return InkWell(
      onTap: () => _onResultTapped(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: conversation title + match count ──
            Row(
              children: [
                if (conv.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin, size: 14, color: cs.primary),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${result.matchCount} 个匹配',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            // ── Snippet ──
            const SizedBox(height: 6),
            _buildHighlightedSnippet(snippet, snippetStart, firstMatch, cs),

            // ── Timestamp ──
            const SizedBox(height: 4),
            Text(
              _formatDate(conv.updatedAt),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedSnippet(
    String snippet,
    int snippetStart,
    SearchResultMatch match,
    ColorScheme cs,
  ) {
    // Compute match position relative to snippet start
    final relativeStart = match.matchStart - snippetStart;
    final queryLen = match.matchEnd - match.matchStart;

    if (relativeStart < 0 || relativeStart + queryLen > snippet.length) {
      return Text(
        snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      );
    }

    final spans = <TextSpan>[];
    if (relativeStart > 0) {
      spans.add(TextSpan(text: snippet.substring(0, relativeStart)));
    }
    spans.add(TextSpan(
      text: snippet.substring(relativeStart, relativeStart + queryLen),
      style: TextStyle(
        backgroundColor: Colors.yellow,
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    ));
    if (relativeStart + queryLen < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(relativeStart + queryLen)));
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        children: spans,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
