import 'package:flutter/material.dart';

import '../providers/conversation_provider.dart';
import '../utils/conversation_utils.dart';

class SearchPanel extends StatefulWidget {
  final List<Conversation> conversations;
  final void Function(Conversation) onConversationSelected;

  const SearchPanel({
    super.key,
    required this.conversations,
    required this.onConversationSelected,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchByContent = false;
  String _query = '';

  List<Conversation> get _filteredConversations {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return [];

    final sorted = List<Conversation>.from(widget.conversations);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return sorted.where((c) {
      final displayTitle = c.title.isEmpty ? '新对话' : c.title;
      if (!_searchByContent) {
        return displayTitle.toLowerCase().contains(query);
      } else {
        if (displayTitle.toLowerCase().contains(query)) return true;
        return countMessageMatches(c, query) > 0;
      }
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredConversations;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Text(
                      '搜索对话',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '输入关键词...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('搜标题'),
                      selected: !_searchByContent,
                      onSelected: (_) => setState(() => _searchByContent = false),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('搜内容'),
                      selected: _searchByContent,
                      onSelected: (_) => setState(() => _searchByContent = true),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                    const Spacer(),
                    if (_query.isNotEmpty)
                      Text(
                        '${filtered.length} 个结果',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 40,
                                color: cs.onSurfaceVariant.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? '输入关键词开始搜索'
                                  : '没有找到匹配的对话',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final conv = filtered[index];
                          return _buildSearchResultCard(conv, cs);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultCard(Conversation conv, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = conv.title.isEmpty ? '新对话' : conv.title;
    final matchCount = countMessageMatches(conv, _query);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onConversationSelected(conv),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  conv.isPinned
                      ? Icons.push_pin
                      : Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: conv.isPinned
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conv.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin,
                                size: 12, color: cs.primary),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        if (_searchByContent && matchCount > 0)
                          _buildMatchBadge(cs, matchCount),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatDate(conv.updatedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (conv.messages.length > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.message_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            '${conv.messages.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchBadge(ColorScheme cs, int matchCount) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$matchCount',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
