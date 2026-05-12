import 'package:flutter/material.dart';

/// A simple custom Markdown renderer.
///
/// Handles the common subset of Markdown that appears in Claude responses:
/// headings, bold, italic, inline code, code blocks, lists, blockquotes,
/// links, horizontal rules, and basic tables.
///
/// Returns a single [Widget] that renders the given [data] string.
///
/// Style constants inspired by Claude's response styling:
/// - body: leading 1.7, whitespace normal, break-words
/// - h1: text-[1.375rem] font-bold, mt-3 -mb-1
/// - h2: text-[1.125rem] font-bold, mt-2 -mb-1
/// - h3: text-base font-bold
/// - code (inline): rounded bg, monospace
/// - pre (block): dark bg with rounded corners and border
/// - blockquote: left border, padding
class MarkdownRenderer extends StatelessWidget {
  final String data;
  final bool selectable;

  const MarkdownRenderer({
    super.key,
    required this.data,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blocks = _parseBlocks(data);
    final children = <InlineSpan>[];

    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      // Add spacing between blocks (except before first)
      if (i > 0 &&
          b.type != _BlockType.listItem &&
          b.type != _BlockType.orderedItem) {
        children.add(WidgetSpan(
          child: SizedBox(
              height: b.type == _BlockType.heading1
                  ? 12
                  : b.type == _BlockType.heading2
                      ? 8
                      : 6),
        ));
      }
      children.add(_buildBlockWidgetSpan(context, cs, b));
    }

    if (children.isEmpty) {
      return SizedBox.shrink();
    }

    final widget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: children),
          textScaleFactor: MediaQuery.textScaleFactorOf(context),
        ),
      ],
    );

    return widget;
  }

  WidgetSpan _buildBlockWidgetSpan(
      BuildContext context, ColorScheme cs, _Block block) {
    switch (block.type) {
      case _BlockType.heading1:
        return WidgetSpan(
          child: _buildText(
            context,
            block,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        );
      case _BlockType.heading2:
        return WidgetSpan(
          child: _buildText(
            context,
            block,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        );
      case _BlockType.heading3:
        return WidgetSpan(
          child: _buildText(
            context,
            block,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        );
      case _BlockType.heading4:
        return WidgetSpan(
          child: _buildText(
            context,
            block,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        );
      case _BlockType.paragraph:
      case _BlockType.listItem:
      case _BlockType.orderedItem:
        return WidgetSpan(
          child: _buildText(
            context,
            block,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
        );
      case _BlockType.blockquote:
        return WidgetSpan(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: cs.outlineVariant, width: 4),
              ),
            ),
            child: _buildText(
              context,
              block.copyWith(text: block.text),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      case _BlockType.codeBlock:
        return WidgetSpan(
          child: _buildCodeBlock(context, cs, block),
        );
      case _BlockType.horizontalRule:
        return WidgetSpan(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: cs.outlineVariant, height: 1),
          ),
        );
      case _BlockType.table:
        return WidgetSpan(
          child: _buildTable(context, cs, block),
        );
    }
  }

  Widget _buildText(
    BuildContext context,
    _Block block, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final spans = _parseInline(block.text, color, fontSize);
    final prefix = block.type == _BlockType.listItem
        ? '  •  '
        : block.type == _BlockType.orderedItem
            ? '  ${block.index}.  '
            : '';

    if (selectable) {
      return SelectableText.rich(
        TextSpan(
          text: prefix,
          children: spans,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: 1.7,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        text: prefix,
        children: spans,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, ColorScheme cs, _Block block) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: SelectableText(
        block.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: cs.onSurface,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, ColorScheme cs, _Block block) {
    final rows =
        block.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    // Parse header and data rows
    final headerCells =
        rows[0].split('|').where((c) => c.trim().isNotEmpty).toList();
    final dataRows = <List<String>>[];
    for (int i = 2; i < rows.length; i++) {
      final cells =
          rows[i].split('|').where((c) => c.trim().isNotEmpty).toList();
      if (cells.isNotEmpty) dataRows.add(cells);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: headerCells.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      c.trim(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            // Data rows
            ...dataRows.map((row) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: row.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        c.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Parse inline markdown: **bold**, *italic*, `code`, [text](url)
  List<InlineSpan> _parseInline(String text, Color color, double fontSize) {
    final spans = <InlineSpan>[];
    int i = 0;

    while (i < text.length) {
      // Check for `code` (inline)
      final codeIdx = text.indexOf('`', i);
      if (codeIdx >= 0 && codeIdx == i) {
        final endIdx = text.indexOf('`', i + 1);
        if (endIdx > i) {
          spans.add(WidgetSpan(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                text.substring(i + 1, endIdx),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSize - 1,
                  color: color,
                ),
              ),
            ),
          ));
          i = endIdx + 1;
          continue;
        }
      }

      // Check for **[bold]**
      final boldIdx = text.indexOf('**', i);
      if (boldIdx >= 0 && boldIdx == i) {
        final endIdx = text.indexOf('**', i + 2);
        if (endIdx > i) {
          spans.add(TextSpan(
            text: text.substring(i + 2, endIdx),
            style: TextStyle(fontWeight: FontWeight.w700),
          ));
          i = endIdx + 2;
          continue;
        }
      }

      // Check for *italic*
      final italicIdx = text.indexOf('*', i);
      if (italicIdx >= 0 && italicIdx == i) {
        final endIdx = text.indexOf('*', i + 1);
        if (endIdx > i) {
          spans.add(TextSpan(
            text: text.substring(i + 1, endIdx),
            style: TextStyle(fontStyle: FontStyle.italic),
          ));
          i = endIdx + 1;
          continue;
        }
      }

      // Check for [text](url) link
      final linkIdx = text.indexOf('[', i);
      if (linkIdx >= 0 && linkIdx == i) {
        final closeBracket = text.indexOf(']', i + 1);
        if (closeBracket > i) {
          final openParen = text.indexOf('(', closeBracket + 1);
          if (openParen == closeBracket + 1) {
            final closeParen = text.indexOf(')', openParen + 1);
            if (closeParen > openParen) {
              final linkText = text.substring(i + 1, closeBracket);
              final linkUrl = text.substring(openParen + 1, closeParen);
              spans.add(WidgetSpan(
                child: GestureDetector(
                  onTap: () {
                    // Open URL — no url_launcher dependency, so just debugPrint
                    debugPrint('Link tapped: $linkUrl');
                  },
                  child: Text(
                    linkText,
                    style: TextStyle(
                      color: color,
                      decoration: TextDecoration.underline,
                      decorationColor: color.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ));
              i = closeParen + 1;
              continue;
            }
          }
        }
      }

      // Regular character
      int end = i + 1;
      while (end < text.length) {
        final ch = text[end];
        if (ch == '`' || ch == '*' || ch == '[') break;
        if (ch == '*' && end + 1 < text.length && text[end + 1] == '*') break;
        end++;
      }
      spans.add(TextSpan(text: text.substring(i, end)));
      i = end;
    }

    return spans;
  }

  /// Parse the markdown string into a list of blocks.
  List<_Block> _parseBlocks(String md) {
    final blocks = <_Block>[];
    final lines = md.split('\n');
    int orderedIndex = 0;
    bool inCodeBlock = false;
    final codeLines = <String>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Handle code block
      if (line.trimLeft().startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          codeLines.clear();
          i++;
          continue;
        } else {
          blocks.add(_Block(
            type: _BlockType.codeBlock,
            text: codeLines.join('\n'),
          ));
          inCodeBlock = false;
          codeLines.clear();
          i++;
          continue;
        }
      }

      if (inCodeBlock) {
        codeLines.add(line);
        i++;
        continue;
      }

      final trimmed = line.trim();

      // Empty line
      if (trimmed.isEmpty) {
        orderedIndex = 0;
        i++;
        continue;
      }

      // Heading
      if (trimmed.startsWith('#### ')) {
        blocks
            .add(_Block(type: _BlockType.heading4, text: trimmed.substring(5)));
        i++;
        continue;
      }
      if (trimmed.startsWith('### ')) {
        blocks
            .add(_Block(type: _BlockType.heading3, text: trimmed.substring(4)));
        i++;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        blocks
            .add(_Block(type: _BlockType.heading2, text: trimmed.substring(3)));
        i++;
        continue;
      }
      if (trimmed.startsWith('# ')) {
        blocks
            .add(_Block(type: _BlockType.heading1, text: trimmed.substring(2)));
        i++;
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^-{3,}$').hasMatch(trimmed) ||
          RegExp(r'^\*{3,}$').hasMatch(trimmed)) {
        blocks.add(_Block(type: _BlockType.horizontalRule));
        i++;
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('> ')) {
        blocks.add(
            _Block(type: _BlockType.blockquote, text: trimmed.substring(2)));
        i++;
        continue;
      }

      // Unordered list
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks
            .add(_Block(type: _BlockType.listItem, text: trimmed.substring(2)));
        orderedIndex = 0;
        i++;
        continue;
      }

      // Ordered list
      final orderedMatch = RegExp(r'^(\d+)\.\s').firstMatch(trimmed);
      if (orderedMatch != null) {
        orderedIndex++;
        blocks.add(_Block(
          type: _BlockType.orderedItem,
          text: trimmed.substring(orderedMatch.end),
          index: int.tryParse(orderedMatch.group(1) ?? '') ?? orderedIndex,
        ));
        i++;
        continue;
      }

      // Table
      if (trimmed.contains('|') &&
          trimmed.replaceAll(RegExp(r'[^|]'), '').length >= 2) {
        final tableLines = <String>[trimmed];
        i++;
        while (i < lines.length) {
          final nextLine = lines[i].trim();
          if (nextLine.isEmpty || !nextLine.contains('|')) break;
          tableLines.add(nextLine);
          i++;
        }
        blocks.add(_Block(type: _BlockType.table, text: tableLines.join('\n')));
        orderedIndex = 0;
        continue;
      }

      // Paragraph (default)
      blocks.add(_Block(type: _BlockType.paragraph, text: trimmed));
      orderedIndex = 0;
      i++;
    }

    // Close unclosed code block
    if (inCodeBlock && codeLines.isNotEmpty) {
      blocks.add(_Block(
        type: _BlockType.codeBlock,
        text: codeLines.join('\n'),
      ));
    }

    return blocks;
  }
}

enum _BlockType {
  heading1,
  heading2,
  heading3,
  heading4,
  paragraph,
  listItem,
  orderedItem,
  codeBlock,
  blockquote,
  horizontalRule,
  table,
}

class _Block {
  final _BlockType type;
  final String text;
  final int index;

  const _Block({
    required this.type,
    this.text = '',
    this.index = 0,
  });

  _Block copyWith({String? text}) =>
      _Block(type: type, text: text ?? this.text, index: index);
}
