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
        // AI messages are rendered as markdown: matches inside code blocks,
        // inline code or math can never be highlighted (those are rendered
        // as dedicated widgets), so strip them before matching — otherwise
        // they would overstate the counter and shift the "current" match.
        // User messages are plain text and keep raw offsets (used by the
        // plain-text highlight).
        final text = msg.role == 'user'
            ? msg.content
            : stripSearchIrrelevantMarkdown(msg.content);
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
      // Scroll after the rebuild so the message list reflects the new
      // highlight state (lazy items may not be built until then).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentMatch();
      });
    }
  }

  Future<void> _scrollToCurrentMatch() async {
    // Serialize navigations: a rapid second tap must wait for the first
    // one's pagination loads instead of racing them (load-more refuses
    // concurrent runs, which would silently drop the newer navigation).
    final inFlight = _pendingSearchScroll;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {}
      if (!mounted) return;
    }

    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) {
      return;
    }
    final targetIndex = _currentMatchIndex;
    final match = _searchMatches[targetIndex];

    Future<void> navigation() async {
      // The target may still be unloaded: lazy pagination keeps only the
      // latest messages in the chat controller. Load older batches (without
      // the spinner's minimum-display delay) until the message is present.
      var loadGuard = 0;
      var stalledRetries = 0;
      while (mounted) {
        final historyIdx = _history.indexWhere((m) => m.id == match.messageId);
        if (historyIdx == -1 || _loadedUpToIndex <= historyIdx) break;
        final before = _loadedUpToIndex;
        await _loadMoreMessages(skipMinDisplayDelay: true);
        if (!mounted) return;
        if (_loadedUpToIndex < before) {
          // The batch loaded — keep going.
          stalledRetries = 0;
        } else if (_hasMoreMessages && ++stalledRetries <= 10) {
          // _loadMoreMessages refuses concurrent runs (e.g. the user's own
          // scroll already triggered onEndReached). Wait briefly and retry
          // instead of silently dropping the navigation.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          continue;
        } else {
          // Nothing more to load (or retries exhausted): the target message
          // is not in the chat controller.
          if (stalledRetries > 10) {
            debugPrint('[ChatPage] search navigation retries exhausted for '
                'message ${match.messageId}');
          }
          break;
        }
        if (++loadGuard > 100) {
          debugPrint('[ChatPage] search navigation gave up before reaching '
              'message ${match.messageId}');
          break;
        }
      }
      if (!mounted) return;

      // A newer query or navigation superseded this one: never scroll to a
      // stale match.
      if (_currentMatchIndex != targetIndex ||
          _currentMatchIndex >= _searchMatches.length ||
          _searchMatches[_currentMatchIndex].messageId != match.messageId) {
        return;
      }

      // Already-built messages: ensureVisible scrolls the exact render box
      // and bypasses the keyboard session's scroll swallow, matching the
      // original behavior for visible items.
      final key = _messageKeys[match.messageId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!, alignment: 0.3);
        return;
      }

      // Loaded but not built (scrolled out of the lazy list's cache): use
      // the library's observer-based scroll-to-message, which repeatedly
      // scrolls near the target until the item is found.
      final controller = _controller;
      if (controller == null) return;
      try {
        // The keyboard session swallows controller-initiated scrolls (they
        // fight the page's own keyboard scroll). This is a user-initiated
        // navigation, so lift the swallow for the duration of the scroll.
        final wasSwallow = _chatScrollController.swallowScrolls;
        _chatScrollController.swallowScrolls = false;
        try {
          // The load-more just inserted messages; the list has not laid them
          // out yet. Defer one frame so the observer can locate the target
          // item instead of silently aborting.
          final scrolled = Completer<void>();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await controller.scrollToMessage(
                match.messageId,
                alignment: 0.3,
                duration: const Duration(milliseconds: 250),
              );
            } catch (e, s) {
              if (!scrolled.isCompleted) scrolled.completeError(e, s);
            } finally {
              if (!scrolled.isCompleted) scrolled.complete();
            }
          });
          // Make sure a frame is scheduled so the deferred scroll always
          // runs — if no frame were pending, `scrolled.future` would never
          // complete and every later navigation would wedge behind it.
          WidgetsBinding.instance.scheduleFrame();
          await scrolled.future;
        } finally {
          _chatScrollController.swallowScrolls = wasSwallow;
        }
      } catch (_) {
        // The observer could not locate the item; nothing more to do — the
        // message simply is not in the current list.
      }
    }

    final future = navigation();
    _pendingSearchScroll = future;
    try {
      await future;
    } finally {
      if (identical(_pendingSearchScroll, future)) _pendingSearchScroll = null;
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
  ///
  /// Part of the chat-composer tap region group
  /// ([chatComposerTapRegionGroupId], shared with the message list): with
  /// the app-wide tap-outside blur, tapping a search result (in the list)
  /// or the prev/next-match buttons must NOT blur the search field — the
  /// keyboard stays up while browsing results, matching the pre-fix
  /// behavior the chat page deliberately preserves.
  Widget _buildSearchBar() {
    return TextFieldTapRegion(
      groupId: chatComposerTapRegionGroupId,
      child: Container(
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
                      // Same tap-region group as the message list: tapping a
                      // search result (in the list) must not blur the search
                      // field — the keyboard stays up while browsing results.
                      groupId: chatComposerTapRegionGroupId,
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
      ),
    );
  }
}
