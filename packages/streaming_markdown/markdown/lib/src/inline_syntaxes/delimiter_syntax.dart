// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../inline_parser.dart';
import '../patterns.dart';
import 'inline_syntax.dart';

/// Matches syntax that has a pair of tags and becomes an element, like `*` for
/// `<em>`. Allows nested tags.
class DelimiterSyntax extends InlineSyntax {
  /// Whether this is parsed according to the same nesting rules as [emphasis
  /// delimiters][].
  ///
  /// [emphasis delimiters]: https://spec.commonmark.org/0.30/#can-open-emphasis
  final bool requiresDelimiterRun;

  /// Whether to allow intra-word delimiter runs. CommonMark emphasis and
  /// strong emphasis does not allow this, but GitHub-Flavored Markdown allows
  /// it on strikethrough.
  final bool allowIntraWord;

  final List<DelimiterTag>? tags;

  /// Creates a new [DelimiterSyntax] which matches text on [pattern].
  ///
  /// The [pattern] is used to find the matching text. If [requiresDelimiterRun]
  /// is passed, this syntax parses according to the same nesting rules as
  /// emphasis delimiters.  If [startCharacter] is passed, it is used as a
  /// pre-matching check which is faster than matching against [pattern].
  DelimiterSyntax(
    super.pattern, {
    this.requiresDelimiterRun = false,
    super.startCharacter,
    this.allowIntraWord = false,
    this.tags,
  });

  @override
  bool onMatch(InlineParser parser, Match match) {
    final runLength = match.group(0)!.length;
    final matchStart = parser.pos;
    final matchEnd = parser.pos + runLength;
    final text = Text(parser.source.substring(matchStart, matchEnd));
    if (!requiresDelimiterRun) {
      parser.pushDelimiter(
        SimpleDelimiter(
          node: text,
          length: runLength,
          char: parser.source.codeUnitAt(matchStart),
          canOpen: true,
          canClose: false,
          syntax: this,
          endPos: matchEnd,
        ),
      );
      parser.addNode(text);
      return true;
    }

    final delimiterRun = DelimiterRun.tryParse(
      parser,
      matchStart,
      matchEnd,
      syntax: this,
      node: text,
      allowIntraWord: allowIntraWord,
      tags: tags ?? const [],
    );
    if (delimiterRun != null) {
      parser.pushDelimiter(delimiterRun);
      parser.addNode(text);
      return true;
    } else {
      parser.advanceBy(runLength);
      return false;
    }
  }

  /// Attempts to close this tag at the current position.
  ///
  /// If a tag cannot be closed at the current position (for example, if a link
  /// reference cannot be found for a link tag's label), then `null` is
  /// returned.
  ///
  /// If a tag can be closed at the current position, then this method calls
  /// [getChildren], in which [parser] parses any nested text into child nodes.
  /// The returned [Iterable] includes these children nodes.
  Iterable<Node>? close(
    InlineParser parser,
    Delimiter opener,
    Delimiter closer, {
    required String tag,
    required List<Node> Function() getChildren,
  }) {
    return [Element(tag, getChildren())];
  }
}

class DelimiterTag {
  const DelimiterTag(this.tag, this.indicatorLength);

  // Tag name of the HTML element.
  final String tag;

  final int indicatorLength;
}

/// A delimiter indicating the possible "open" or possible "close" of a tag for
/// a [DelimiterSyntax].
abstract class Delimiter {
  /// The [Text] node representing the plain text representing this delimiter.
  abstract Text node;

  /// The type of delimiter.
  ///
  /// For the two-character image delimiter, `![`, this is `!`.
  int get char;

  /// The number of delimiters.
  int get length;

  /// Whether the delimiter is active.
  ///
  /// Links cannot be nested, so we must "deactivate" any pending ones. For
  /// example, take the following text:
  ///
  ///     Text [link and [more](links)](links).
  ///
  /// Once we have parsed `Text [`, there is one (pending) link in the state
  /// stack.  It is, by default, active. Once we parse the next possible link,
  /// `[more](links)`, as a real link, we must deactive the pending links (just
  /// the one, in this case).
  abstract bool isActive;

  /// Whether this delimiter can open emphasis or strong emphasis.
  bool get canOpen;

  /// Whether this delimiter can close emphasis or strong emphasis.
  bool get canClose;

  /// The syntax which uses this delimiter to parse a tag.
  DelimiterSyntax get syntax;
}

/// A simple delimiter implements the [Delimiter] interface with basic fields,
/// and does not have the concept of "left-flanking" or "right-flanking".
class SimpleDelimiter implements Delimiter {
  @override
  Text node;

  @override
  final int char;

  @override
  final int length;

  @override
  bool isActive;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  @override
  final DelimiterSyntax syntax;

  final int endPos;

  SimpleDelimiter({
    required this.node,
    required this.char,
    required this.length,
    required this.canOpen,
    required this.canClose,
    required this.syntax,
    required this.endPos,
  }) : isActive = true;
}

/// An implementation of [Delimiter] which uses concepts of "left-flanking" and
/// "right-flanking" to determine the values of [canOpen] and [canClose].
///
/// This is primarily used when parsing emphasis and strong emphasis, but can
/// also be used by other extensions of [DelimiterSyntax].
class DelimiterRun implements Delimiter {
  /// According to
  /// [CommonMark](https://spec.commonmark.org/0.30/#unicode-punctuation-character):
  ///
  /// > A punctuation character is an ASCII punctuation character or anything in
  /// > the general Unicode categories `Pc`, `Pd`, `Pe`, `Pf`, `Pi`, `Po`, or
  /// > `Ps`.
  // This RegExp is inspired by
  // https://github.com/commonmark/commonmark.js/blob/1f7d09099c20d7861a674674a5a88733f55ff729/lib/inlines.js#L39.
  // I don't know if there is any way to simplify it or maintain it.
  static final unicodePunctuationPattern = RegExp(
    '['
    '$asciiPunctuationEscaped'
    r'\xA1\xA7\xAB\xB6\xB7\xBB\xBF\u037E\u0387\u055A-\u055F\u0589\u058A\u05BE'
    r'\u05C0\u05C3\u05C6\u05F3\u05F4\u0609\u060A\u060C\u060D\u061B\u061E'
    r'\u061F\u066A-\u066D\u06D4\u0700-\u070D\u07F7-\u07F9\u0830-\u083E\u085E'
    r'\u0964\u0965\u0970\u0AF0\u0DF4\u0E4F\u0E5A\u0E5B\u0F04-\u0F12\u0F14'
    r'\u0F3A-\u0F3D\u0F85\u0FD0-\u0FD4\u0FD9\u0FDA\u104A-\u104F\u10FB'
    r'\u1360-\u1368\u1400\u166D\u166E\u169B\u169C\u16EB-\u16ED\u1735\u1736'
    r'\u17D4-\u17D6\u17D8-\u17DA\u1800-\u180A\u1944\u1945\u1A1E\u1A1F'
    r'\u1AA0-\u1AA6\u1AA8-\u1AAD\u1B5A-\u1B60\u1BFC-\u1BFF\u1C3B-\u1C3F\u1C7E'
    r'\u1C7F\u1CC0-\u1CC7\u1CD3\u2010-\u2027\u2030-\u2043\u2045-\u2051'
    r'\u2053-\u205E\u207D\u207E\u208D\u208E\u2308-\u230B\u2329\u232A'
    r'\u2768-\u2775\u27C5\u27C6\u27E6-\u27EF\u2983-\u2998\u29D8-\u29DB\u29FC'
    r'\u29FD\u2CF9-\u2CFC\u2CFE\u2CFF\u2D70\u2E00-\u2E2E\u2E30-\u2E42'
    r'\u3001-\u3003\u3008-\u3011\u3014-\u301F\u3030\u303D\u30A0\u30FB\uA4FE'
    r'\uA4FF\uA60D-\uA60F\uA673\uA67E\uA6F2-\uA6F7\uA874-\uA877\uA8CE\uA8CF'
    r'\uA8F8-\uA8FA\uA8FC\uA92E\uA92F\uA95F\uA9C1-\uA9CD\uA9DE\uA9DF'
    r'\uAA5C-\uAA5F\uAADE\uAADF\uAAF0\uAAF1\uABEB\uFD3E\uFD3F\uFE10-\uFE19'
    r'\uFE30-\uFE52\uFE54-\uFE61\uFE63\uFE68\uFE6A\uFE6B\uFF01-\uFF03'
    r'\uFF05-\uFF0A\uFF0C-\uFF0F\uFF1A\uFF1B\uFF1F\uFF20\uFF3B-\uFF3D\uFF3F'
    r'\uFF5B\uFF5D\uFF5F-\uFF65'
    ']',
  );

  /// Unicode 17 punctuation ranges outside the basic multilingual plane.
  ///
  /// This uses the Unicode punctuation categories from the CommonMark
  /// definition, represented as code point ranges because Dart's strings are
  /// indexed by UTF-16 code units.
  static const _supplementaryPunctuationRanges = <(int, int)>[
    (0x10100, 0x10102),
    (0x1039F, 0x1039F),
    (0x103D0, 0x103D0),
    (0x1056F, 0x1056F),
    (0x10857, 0x10857),
    (0x1091F, 0x1091F),
    (0x1093F, 0x1093F),
    (0x10A50, 0x10A58),
    (0x10A7F, 0x10A7F),
    (0x10AF0, 0x10AF6),
    (0x10B39, 0x10B3F),
    (0x10B99, 0x10B9C),
    (0x10D6E, 0x10D6E),
    (0x10EAD, 0x10EAD),
    (0x10ED0, 0x10ED0),
    (0x10F55, 0x10F59),
    (0x10F86, 0x10F89),
    (0x11047, 0x1104D),
    (0x110BB, 0x110BC),
    (0x110BE, 0x110C1),
    (0x11140, 0x11143),
    (0x11174, 0x11175),
    (0x111C5, 0x111C8),
    (0x111CD, 0x111CD),
    (0x111DB, 0x111DB),
    (0x111DD, 0x111DF),
    (0x11238, 0x1123D),
    (0x112A9, 0x112A9),
    (0x113D4, 0x113D5),
    (0x113D7, 0x113D8),
    (0x1144B, 0x1144F),
    (0x1145A, 0x1145B),
    (0x1145D, 0x1145D),
    (0x114C6, 0x114C6),
    (0x115C1, 0x115D7),
    (0x11641, 0x11643),
    (0x11660, 0x1166C),
    (0x116B9, 0x116B9),
    (0x1173C, 0x1173E),
    (0x1183B, 0x1183B),
    (0x11944, 0x11946),
    (0x119E2, 0x119E2),
    (0x11A3F, 0x11A46),
    (0x11A9A, 0x11A9C),
    (0x11A9E, 0x11AA2),
    (0x11B00, 0x11B09),
    (0x11BE1, 0x11BE1),
    (0x11C41, 0x11C45),
    (0x11C70, 0x11C71),
    (0x11EF7, 0x11EF8),
    (0x11F43, 0x11F4F),
    (0x11FFF, 0x11FFF),
    (0x12470, 0x12474),
    (0x12FF1, 0x12FF2),
    (0x16A6E, 0x16A6F),
    (0x16AF5, 0x16AF5),
    (0x16B37, 0x16B3B),
    (0x16B44, 0x16B44),
    (0x16D6D, 0x16D6F),
    (0x16E97, 0x16E9A),
    (0x16FE2, 0x16FE2),
    (0x1BC9F, 0x1BC9F),
    (0x1DA87, 0x1DA8B),
    (0x1E5FF, 0x1E5FF),
    (0x1E95E, 0x1E95F),
  ];

  /// Unicode whitespace.
  // See https://spec.commonmark.org/0.30/#unicode-whitespace-character.
  // Unicode Zs: https://www.compart.com/en/unicode/category.
  static const unicodeWhitespace = '\u0020\u0009\u000A\u000C\u000D'
      '\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008'
      '\u2009\u200A\u202F\u205F\u3000';

  @override
  Text node;

  @override
  final int char;

  @override
  int get length => node.text.length;

  @override
  bool isActive;

  @override
  final DelimiterSyntax syntax;

  final bool allowIntraWord;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  final List<DelimiterTag> tags;

  DelimiterRun._({
    required this.node,
    required this.char,
    required this.syntax,
    required this.tags,
    required bool isLeftFlanking,
    required bool isRightFlanking,
    required bool isPrecededByPunctuation,
    required bool isFollowedByPunctuation,
    required this.allowIntraWord,
  })  : canOpen = isLeftFlanking &&
            (!isRightFlanking || allowIntraWord || isPrecededByPunctuation),
        canClose = isRightFlanking &&
            (!isLeftFlanking || allowIntraWord || isFollowedByPunctuation),
        isActive = true;

  /// Tries to parse a delimiter run from [runStart] (inclusive) to [runEnd]
  /// (exclusive).
  static DelimiterRun? tryParse(
    InlineParser parser,
    int runStart,
    int runEnd, {
    required DelimiterSyntax syntax,
    required List<DelimiterTag> tags,
    required Text node,
    bool allowIntraWord = false,
  }) {
    bool precededByWhitespace;
    bool followedByWhitespace;
    bool precededByPunctuation;
    bool followedByPunctuation;

    if (runStart == 0) {
      precededByWhitespace = true;
      precededByPunctuation = false;
    } else {
      final preceding = _codePointBefore(parser.source, runStart);
      precededByWhitespace = unicodeWhitespace.contains(
        String.fromCharCode(preceding),
      );
      precededByPunctuation =
          !precededByWhitespace && _isUnicodePunctuation(preceding);
    }

    if (runEnd == parser.source.length) {
      followedByWhitespace = true;
      followedByPunctuation = false;
    } else {
      final following = _codePointAt(parser.source, runEnd);
      followedByWhitespace = unicodeWhitespace.contains(
        String.fromCharCode(following),
      );
      followedByPunctuation =
          !followedByWhitespace && _isUnicodePunctuation(following);
    }

    // If it is a left-flanking delimiter run, see
    // https://spec.commonmark.org/0.30/#left-flanking-delimiter-run.
    final isLeftFlanking = !followedByWhitespace &&
        (!followedByPunctuation ||
            precededByWhitespace ||
            precededByPunctuation);

    // If it is a right-flanking delimiter run, see
    // https://spec.commonmark.org/0.30/#right-flanking-delimiter-run.
    final isRightFlanking = !precededByWhitespace &&
        (!precededByPunctuation ||
            followedByWhitespace ||
            followedByPunctuation);

    // Make sure the shorter delimiter takes precedence without mutating the
    // caller-supplied list.
    final sortedTags = List<DelimiterTag>.of(tags)
      ..sort((a, b) => a.indicatorLength.compareTo(b.indicatorLength));

    return DelimiterRun._(
      node: node,
      char: parser.charAt(runStart),
      syntax: syntax,
      tags: sortedTags,
      isLeftFlanking: isLeftFlanking,
      isRightFlanking: isRightFlanking,
      isPrecededByPunctuation: precededByPunctuation,
      isFollowedByPunctuation: followedByPunctuation,
      allowIntraWord: allowIntraWord,
    );
  }

  static int _codePointBefore(String text, int offset) {
    final trailing = text.codeUnitAt(offset - 1);
    if (trailing >= 0xDC00 && trailing <= 0xDFFF && offset > 1) {
      final leading = text.codeUnitAt(offset - 2);
      if (leading >= 0xD800 && leading <= 0xDBFF) {
        return 0x10000 + ((leading - 0xD800) << 10) + (trailing - 0xDC00);
      }
    }
    return trailing;
  }

  static int _codePointAt(String text, int offset) {
    final leading = text.codeUnitAt(offset);
    if (leading >= 0xD800 && leading <= 0xDBFF && offset + 1 < text.length) {
      final trailing = text.codeUnitAt(offset + 1);
      if (trailing >= 0xDC00 && trailing <= 0xDFFF) {
        return 0x10000 + ((leading - 0xD800) << 10) + (trailing - 0xDC00);
      }
    }
    return leading;
  }

  static bool _isUnicodePunctuation(int codePoint) {
    if (codePoint > 0xFFFF) {
      return _supplementaryPunctuationRanges.any(
        (range) => codePoint >= range.$1 && codePoint <= range.$2,
      );
    }
    return unicodePunctuationPattern.hasMatch(String.fromCharCode(codePoint));
  }

  @override
  String toString() => '<char: $char, length: $length, canOpen: $canOpen, '
      'canClose: $canClose>';
}
