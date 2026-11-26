import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum ChatConversationState { loading, empty, noConversation, loadFailed }

class ChatConversationStateView extends StatelessWidget {
  const ChatConversationStateView({
    super.key,
    required this.state,
    this.onRetry,
  });

  final ChatConversationState state;
  final VoidCallback? onRetry;

  Widget _scrollableCenteredContent(
    BuildContext context,
    List<Widget> children,
  ) =>
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('chat-conversation-state-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (state == ChatConversationState.loading) {
      return _scrollableCenteredContent(
        context,
        [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            child: const AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.chatLoadingConversation),
        ],
      );
    }

    if (state == ChatConversationState.loadFailed) {
      return _scrollableCenteredContent(
        context,
        [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(l10n.chatConversationLoadError),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.chatRetryLoadConversation),
          ),
        ],
      );
    }

    return _scrollableCenteredContent(
      context,
      [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state == ChatConversationState.noConversation
                ? l10n.chatNoActiveConversation
                : l10n.chatEmptyConversation,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
