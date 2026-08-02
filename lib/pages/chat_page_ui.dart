part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageUiExt on _ChatPageState {
  /// Scrolls the chat list to the bottom-most message immediately when the
  /// keyboard opens, keeping the input area and latest message visible.
  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_chatScrollController.hasClients) {
          _scrollToBottom();
        }
      });
    }
  }

  /// Restores the scroll position that was captured before the keyboard
  /// opened, so the user returns to where they were reading.
  void _restoreScrollPositionAfterKeyboard() {
    final savedPos = _lastScrollPositionBeforeKeyboard;
    _lastScrollPositionBeforeKeyboard = null;
    if (savedPos == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chatScrollController.hasClients) {
        final maxScroll = _chatScrollController.position.maxScrollExtent;
        _chatScrollController.jumpTo(savedPos.clamp(0.0, maxScroll));
      }
    });
  }

  /// Handles chat list scroll events to track auto-scroll state.
  void _onChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final maxScroll = _chatScrollController.position.maxScrollExtent;
    final currentScroll = _chatScrollController.position.pixels;
    final isAtBottom = (maxScroll - currentScroll) <= 80;

    if (isAtBottom) {
      // At bottom — user sees latest messages
      if (_showScrollToBottomButton || (!_autoScrollEnabled)) {
        setState(() {
          _showScrollToBottomButton = false;
          // Enable auto-scroll when user is at bottom (so new messages
          // automatically keep them at the bottom).
          if (_chatScrollController.hasClients &&
              _chatScrollController.position.maxScrollExtent > 0) {
            _autoScrollEnabled = true;
          }
        });
      }
    } else {
      // Scrolled up — disable auto-scroll and show button
      if (!_showScrollToBottomButton || _autoScrollEnabled) {
        setState(() {
          _autoScrollEnabled = false;
          _showScrollToBottomButton = true;
        });
      }
    }
  }

  /// Called when the user taps the scroll-to-bottom button.
  /// Enables auto-scroll and scrolls to the bottom.
  void _onScrollToBottomTap() {
    _scrollToBottom();
    setState(() {
      _autoScrollEnabled = true;
      _showScrollToBottomButton = false;
    });
  }

  void _showJsonInspection(String msgId) {
    final chatMsg = _history.where((m) => m.id == msgId).firstOrNull;
    if (chatMsg == null) return;

    showJsonInspectionDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
    );
  }

  /// 上下文统计行：显示实际 context（API usage）、使用比例、累计花费。
  ///
  /// 与 opencode sidebar 一致的三项：
  /// - context：最近一次请求的实际输入 token 数（来自 API usage，不估算）
  /// - 使用比例：context / 模型上下文窗口（模型页"上下文长度"）
  /// - 花费：按模型价格累计的美元
  Widget _buildContextStatusLine(String convId) {
    final conv = ref
        .watch(conversationsProvider)
        .where((c) => c.id == convId)
        .firstOrNull;
    final modelContext =
        (_adapter.modelConfig?.typeConfig['context'] as num?)?.toInt();
    final inputTokens = conv?.lastInputTokens;
    final cost = conv?.totalCost ?? 0;
    final cs = Theme.of(context).colorScheme;

    final parts = <String>[];
    if (inputTokens != null) {
      parts.add('ctx ${formatTokenCount(inputTokens)}');
      if (modelContext != null && modelContext > 0) {
        final pct = (inputTokens / modelContext * 100);
        parts.add('${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%');
      }
    }
    parts.add('\$${formatCost(cost)}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 上下文压缩 banner：对话被压缩过时显示，点击可展开摘要预览。
  Widget _buildCompactionBanner(String convId) {
    final conv = ref
        .watch(conversationsProvider)
        .where((c) => c.id == convId)
        .firstOrNull;
    final summary = conv?.contextSummary;
    if (summary == null || summary.isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () =>
            setState(() => _showCompactionSummary = !_showCompactionSummary),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.compress, size: 14, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '上下文已压缩，旧对话已总结'
                      '${_showCompactionSummary ? '（点击收起）' : '（点击查看摘要）'}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              if (_showCompactionSummary) ...[
                const SizedBox(height: 4),
                SelectableText(
                  summary,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onTertiaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetailDialog(BuildContext context, String messageId) {
    final chatMsg = _history.where((m) => m.id == messageId).firstOrNull;
    if (chatMsg == null) return;

    showDataDetailDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
    );
  }

  /// Shows a dialog with raw HTTP request/response data for the given message.
  void _showRawDataDialog(BuildContext context, String messageId) {
    _showErrorDetailDialog(context, messageId);
  }

  /// Formats an error value for display in the error bubble.
  /// If the value is a Map/List, converts to JSON string.
  /// If the value is already a String, returns it as-is (up to 200 chars).
  String _formatErrorValue(dynamic value) {
    if (value is String) {
      return value.length > 200 ? '${value.substring(0, 200)}...' : value;
    }
    if (value is Map || value is List) {
      try {
        final json = const JsonEncoder.withIndent('  ').convert(value);
        return json.length > 200 ? '${json.substring(0, 200)}...' : json;
      } catch (_) {
        return value.toString();
      }
    }
    return value?.toString() ?? '';
  }

  /// Top bar with title and search toggle.
  Widget _buildTopBar({required String title}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button when inside nested navigator and not first route
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                // Allow navigation back at any time, even during
                // streaming. The stream continues in the background,
                // messages are saved when streaming completes.
                Navigator.of(context).pop();
              },
            ),
          Expanded(
            child: GestureDetector(
              onLongPress: () =>
                  setState(() => _developerMode = !_developerMode),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (_developerMode)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'DEV',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Search toggle ──
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off : Icons.search,
              color:
                  _isSearching ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: '搜索消息',
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchMode = SearchMode.current;
            }),
          ),
        ],
      ),
    );
  }

  /// Banner shown when no chat API is configured.
  Widget _buildUnconfiguredBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚠️ 未配置聊天API — 前往设置',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: _navigateToProviderConfig,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scroll-to-bottom overlay button shown when the user scrolls up.
  Widget _buildScrollToBottomButton({required bool isDark}) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 4,
        shape: const CircleBorder(),
        color: isDark ? Colors.grey[700] : Colors.grey[300],
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _onScrollToBottomTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_downward,
              size: 20,
              color: isDark ? Colors.grey[200] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  /// Action buttons (copy / retry or edit / raw data / JSON / delete).
  Widget _buildMessageActionButtons({
    required BuildContext context,
    required TextMessage message,
    required bool isAi,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionButton(
          icon: Icons.copy,
          tooltip: '复制',
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: message.text,
              ),
            );
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              const SnackBar(
                content: Text('已复制'),
                duration: Duration(
                  seconds: 1,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 2),
        if (isAi)
          ActionButton(
            icon: Icons.refresh,
            tooltip: '重试',
            onPressed: () => _confirmRetryOrEdit(
              message.id,
            ),
          )
        else
          ActionButton(
            icon: Icons.edit_outlined,
            tooltip: '编辑',
            onPressed: () => _startEditMessage(
              message.id,
            ),
          ),
        // Raw data view button: only shown for AI messages when data exists.
        if (isAi &&
            _history.any(
              (m) =>
                  m.id == message.id &&
                  (m.rawRequest != null || m.rawResponse != null),
            )) ...[
          const SizedBox(width: 2),
          ActionButton(
            icon: Icons.data_exploration,
            tooltip: '查看数据详情',
            onPressed: () => _showRawDataDialog(
              context,
              message.id,
            ),
          ),
        ],
        if (_developerMode &&
            isAi &&
            _history.any(
              (m) =>
                  m.id == message.id &&
                  (m.rawRequest != null || m.rawResponse != null),
            )) ...[
          const SizedBox(width: 2),
          ActionButton(
            icon: Icons.code,
            tooltip: 'JSON 审查',
            onPressed: () => _showJsonInspection(
              message.id,
            ),
          ),
        ],
        const SizedBox(width: 2),
        ActionButton(
          icon: Icons.delete_outline,
          tooltip: '删除',
          onPressed: () => _confirmDeleteMessage(
            message.id,
          ),
        ),
      ],
    );
  }
}
