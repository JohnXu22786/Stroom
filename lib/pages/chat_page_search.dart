part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageSearchExt on _ChatPageState {
  void _performSearch(String query) {
    query = query.trim();
    _searchDebounceTimer?.cancel();
    final generation = ++_searchGeneration;
    setState(() {
      _searchQuery = query;
      _searchError = null;
      _searchMatches.clear();
      _currentMatchIndex = 0;
    });
    if (query.isEmpty) return;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      _searchConversation(query, generation);
    });
  }

  Future<void> _searchConversation(String query, int generation) async {
    final conversationId = ref.read(activeConversationIdProvider);
    if (conversationId == null) return;
    try {
      final messages = await ref
          .read(conversationsProvider.notifier)
          .loadFullMessagesForContext(conversationId);
      if (!mounted ||
          generation != _searchGeneration ||
          query != _searchQuery ||
          conversationId != ref.read(activeConversationIdProvider)) {
        return;
      }
      final lowerQuery = query.toLowerCase();
      final matches = <SearchMatch>[];
      for (final msg in messages) {
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
          matches.add(SearchMatch(msg.id, idx, idx + query.length));
          start = idx + query.length;
        }
      }
      final requestedMessageId = _pendingSearchMessageId;
      final targetMatch = requestedMessageId == null
          ? -1
          : matches.indexWhere(
              (match) => match.messageId == requestedMessageId,
            );
      setState(() {
        _searchMatches
          ..clear()
          ..addAll(matches);
        _currentMatchIndex = 0;
        if (targetMatch >= 0) _currentMatchIndex = targetMatch;
        _pendingSearchMessageId = null;
      });
      if (requestedMessageId != null && targetMatch < 0) {
        // Global search can find text inside code or math that local search
        // intentionally excludes because those widgets cannot highlight raw
        // offsets. Still navigate to the selected message.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _searchGeneration) {
            _scrollToMessageId(requestedMessageId);
          }
        });
      } else if (_searchMatches.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _searchGeneration) {
            _scrollToCurrentMatch();
          }
        });
      }
    } catch (error) {
      debugPrint('[ChatPage] failed to search conversation: $error');
      if (!mounted ||
          generation != _searchGeneration ||
          query != _searchQuery ||
          conversationId != ref.read(activeConversationIdProvider)) {
        return;
      }
      setState(() => _searchError = '搜索失败');
    }
  }

  Future<void> _scrollToMessageId(String messageId) async {
    // A selected repository page can contain more messages than the chat
    // controller window when live stream messages were merged into history.
    // Bring the target into the controller before asking it to scroll.
    final conversationId = _loadedConversationId;
    final conversationGeneration = _conversationLoadGeneration;
    var loadGuard = 0;
    var stalledRetries = 0;
    while (mounted && conversationId != null) {
      if (conversationGeneration != _conversationLoadGeneration ||
          conversationId != _loadedConversationId ||
          conversationId != ref.read(activeConversationIdProvider)) {
        return;
      }
      final historyIndex = _history.indexWhere(
        (message) => message.id == messageId,
      );
      if (historyIndex >= 0 && _loadedUpToIndex <= historyIndex) break;
      if (historyIndex < 0 && !_hasMoreMessages) break;

      final beforeLoadedUpToIndex = _loadedUpToIndex;
      final beforeHistoryLength = _history.length;
      await _loadMoreMessages(skipMinDisplayDelay: true);
      if (!mounted || conversationGeneration != _conversationLoadGeneration) {
        return;
      }
      final targetLoaded = _history.any((message) => message.id == messageId);
      if (targetLoaded ||
          _loadedUpToIndex < beforeLoadedUpToIndex ||
          _history.length > beforeHistoryLength) {
        stalledRetries = 0;
      } else if (_hasMoreMessages && ++stalledRetries <= 10) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        continue;
      } else {
        break;
      }
      if (++loadGuard > 100) break;
    }

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
      );
      return;
    }

    final controller = _controller;
    if (controller == null) return;
    final wasSwallow = _chatScrollController.swallowScrolls;
    _chatScrollController.swallowScrolls = false;
    try {
      final scrolled = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await controller.scrollToMessage(
            messageId,
            alignment: 0.3,
            duration: const Duration(milliseconds: 250),
          );
        } catch (error, stackTrace) {
          if (!scrolled.isCompleted) {
            scrolled.completeError(error, stackTrace);
          }
        } finally {
          if (!scrolled.isCompleted) scrolled.complete();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
      await scrolled.future;
    } catch (_) {
      // The target may have been removed while global search was open.
    } finally {
      _chatScrollController.swallowScrolls = wasSwallow;
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
        if (historyIdx >= 0 && _loadedUpToIndex <= historyIdx) break;
        if (historyIdx < 0 && !_hasMoreMessages) break;
        final before = _loadedUpToIndex;
        final beforeHistoryLength = _history.length;
        await _loadMoreMessages(skipMinDisplayDelay: true);
        if (!mounted) return;
        final targetLoaded = _history.any((m) => m.id == match.messageId);
        if (targetLoaded ||
            _loadedUpToIndex < before ||
            _history.length > beforeHistoryLength) {
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
            debugPrint(
              '[ChatPage] search navigation retries exhausted for '
              'message ${match.messageId}',
            );
          }
          break;
        }
        if (++loadGuard > 100) {
          debugPrint(
            '[ChatPage] search navigation gave up before reaching '
            'message ${match.messageId}',
          );
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
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _searchMatches.length) %
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
    _searchDebounceTimer?.cancel();
    _searchGeneration++;
    setState(() {
      _isSearching = false;
      _searchMode = SearchMode.current;
      _searchQuery = '';
      _searchError = null;
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
          final messageId = result['messageId'] as String?;
          final query = result['query'] as String?;
          if (conversationId == null || query == null || query.isEmpty) return;

          // Step 1: Save current conversation's messages first (before switching)
          await _saveMessages();
          if (!mounted) return;

          final conversationsNotifier = ref.read(
            conversationsProvider.notifier,
          );
          if (messageId != null) {
            await conversationsNotifier.loadMessagesAroundMessage(
              conversationId,
              messageId,
            );
            if (!mounted) return;
          }

          // Step 2: If switching to a different conversation, select it.
          // The activeConversationIdProvider listener schedules
          // _loadConversationMessages in a post-frame callback, which clears
          // search state. Schedule search activation in a subsequent
          // post-frame callback so it runs AFTER that load completes.
          final activeId = ref.read(activeConversationIdProvider);
          if (conversationId != activeId) {
            conversationsNotifier.selectConversation(conversationId);
          }
          if (messageId != null) {
            // Load the page selected above before activating local search. This
            // also handles a result in the conversation already being viewed.
            await _loadConversationMessages(force: true);
            if (!mounted) return;
          }
          // Step 2b: Sync the session assistant selection to the opened
          // conversation's bound assistant. Global search can open ANY
          // conversation (not only the session assistant's), so the session
          // selection would otherwise drift from what the chat actually uses —
          // the topic page (which filters by the session selection) would then
          // hide this conversation when navigating back. The conversation's
          // binding is the source of truth; the session selection follows it.
          // Guard: only sync when the binding still resolves to an existing
          // assistant. A conversation whose assistant was deleted must NOT
          // clobber the user's current selection with a dead id (the send path
          // already falls back gracefully for such bindings).
          final openedConv = ref
              .read(conversationsProvider)
              .where((c) => c.id == conversationId)
              .firstOrNull;
          final openedAssistantId = openedConv?.assistantId;
          if (openedAssistantId != null &&
              openedAssistantId.isNotEmpty &&
              ref
                  .read(assistantProvider)
                  .any((a) => a.id == openedAssistantId)) {
            ref.read(selectedAssistantIdProvider.notifier).state =
                openedAssistantId;
          }

          // Step 3: Schedule search activation for the next frame, after
          // _loadConversationMessages has completed its synchronous part.
          // Note: Setting _searchTextController.text triggers onChanged →
          // _performSearch internally via the controller listener, so the
          // explicit _performSearch call below is redundant but kept for
          // safety in case the listener doesn't fire as expected.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _pendingSearchMessageId = messageId;
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
    final matches = _searchMatches
        .where((m) => m.messageId == messageId)
        .toList();
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_searchMode == SearchMode.current &&
                    _searchError != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _searchError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: '重试搜索',
                    onPressed: () => _performSearch(_searchQuery),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
                if (_searchMode == SearchMode.current) ...[
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
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
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
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
                      setState(() => _searchMode = SearchMode.current);
                      _searchTextController.clear();
                      _performSearch('');
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
