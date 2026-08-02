part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageSearchExt on _ChatPageState {
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchMatches.clear();
      _currentMatchIndex = 0;
      if (query.isEmpty) return;
      final lowerQuery = query.toLowerCase();
      for (final msg in _history) {
        final text = msg.content;
        final lowerContent = text.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerContent.indexOf(lowerQuery, start);
          if (idx == -1) break;
          _searchMatches.add(SearchMatch(msg.id, idx, idx + query.length));
          start = idx + query.length;
        }
      }
    });
    if (_searchMatches.isNotEmpty) {
      _scrollToCurrentMatch();
    }
  }

  void _scrollToCurrentMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) {
      return;
    }
    final match = _searchMatches[_currentMatchIndex];
    final key = _messageKeys[match.messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, alignment: 0.3);
    }
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchMode = SearchMode.current;
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = 0;
      _searchTextController.clear();
    });
  }

  Widget _buildModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _openGlobalSearch() {
    Navigator.of(context, rootNavigator: true)
        .push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const MessageSearchPage()),
    )
        .then((result) async {
      if (!mounted || result == null) return;
      final conversationId = result['conversationId'] as String?;
      final query = result['query'] as String?;
      if (conversationId == null || query == null || query.isEmpty) return;

      // Step 1: Save current conversation's messages first (before switching)
      await _saveMessages();
      if (!mounted) return;

      // Step 2: If switching to a different conversation, select it.
      // The activeConversationIdProvider listener schedules
      // _loadConversationMessages in a post-frame callback, which clears
      // search state. Schedule search activation in a subsequent
      // post-frame callback so it runs AFTER that load completes.
      final activeId = ref.read(activeConversationIdProvider);
      if (conversationId != activeId) {
        ref
            .read(conversationsProvider.notifier)
            .selectConversation(conversationId);
      }

      // Step 3: Schedule search activation for the next frame, after
      // _loadConversationMessages has completed its synchronous part.
      // Note: Setting _searchTextController.text triggers onChanged →
      // _performSearch internally via the controller listener, so the
      // explicit _performSearch call below is redundant but kept for
      // safety in case the listener doesn't fire as expected.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _searchTextController.text = query;
          _isSearching = true;
        });
        _performSearch(query);
      });
    });
  }

  Widget _buildHighlightedText(
    String text,
    String messageId, {
    Color? textColor,
  }) {
    if (_searchQuery.isEmpty) {
      return SelectableText(
        text,
        style: textColor != null ? TextStyle(color: textColor) : null,
      );
    }
    final matches =
        _searchMatches.where((m) => m.messageId == messageId).toList();
    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: textColor != null ? TextStyle(color: textColor) : null,
      );
    }
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      if (match.matchStart > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.matchStart)));
      }
      final matchText = text.substring(match.matchStart, match.matchEnd);
      final isCurrent = _searchMatches.indexOf(match) == _currentMatchIndex;
      spans.add(
        TextSpan(
          text: matchText,
          style: TextStyle(
            backgroundColor: isCurrent ? Colors.orangeAccent : Colors.yellow,
            color: Colors.black87,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
      lastEnd = match.matchEnd;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return SelectableText.rich(
      TextSpan(style: DefaultTextStyle.of(context).style, children: spans),
    );
  }

  /// Search bar with input field, match navigation and mode toggle chips.
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Search field + nav controls
          Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchTextController,
                    autofocus: true,
                    onChanged: (query) {
                      if (_searchMode == SearchMode.current) {
                        _performSearch(query);
                      } else if (query.isNotEmpty) {
                        // Global mode: defer to full search page
                        _openGlobalSearch();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _searchMode == SearchMode.current
                          ? '搜索当前对话...'
                          : '搜索所有对话...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (_searchMode == SearchMode.current &&
                  _searchMatches.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '${_currentMatchIndex + 1}/${_searchMatches.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_searchMode == SearchMode.current) ...[
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_up,
                    size: 20,
                  ),
                  tooltip: '上一个',
                  onPressed: _previousMatch,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                  tooltip: '下一个',
                  onPressed: _nextMatch,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: '关闭搜索',
                onPressed: _closeSearch,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
          // Row 2: Mode toggle chips
          const SizedBox(height: 4),
          Row(
            children: [
              _buildModeChip(
                label: '当前对话',
                selected: _searchMode == SearchMode.current,
                onTap: () {
                  if (_searchMode != SearchMode.current) {
                    setState(() {
                      _searchMode = SearchMode.current;
                      _searchTextController.clear();
                      _performSearch('');
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                label: '所有对话',
                selected: _searchMode == SearchMode.global,
                onTap: () {
                  if (_searchMode != SearchMode.global) {
                    setState(() => _searchMode = SearchMode.global);
                    _openGlobalSearch();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
