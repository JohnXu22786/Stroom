// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'assets/case_folding.dart';
import 'assets/html_entities.dart';
import 'charcode.dart';
import 'line.dart';
import 'patterns.dart';

/// One or more whitespace, for compressing.
final _oneOrMoreWhitespacePattern = RegExp('[ \n\r\t]+');

/// Escapes (`"`), (`<`), (`>`) and (`&`) characters.
/// Escapes (`'`) if [escapeApos] is `true`.
String escapeHtml(String html, {bool escapeApos = true}) => HtmlEscape(
      HtmlEscapeMode(
          escapeApos: escapeApos, escapeLtGt: true, escapeQuot: true),
    ).convert(html);

/// Escapes (`"`), (`<`) and (`>`) characters.
String escapeHtmlAttribute(String text) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

/// "Normalizes" a link label, according to the [CommonMark spec].
///
/// [CommonMark spec] https://spec.commonmark.org/0.30/#link-label
String normalizeLinkLabel(String label) {
  final text = label.trim().replaceAll(_oneOrMoreWhitespacePattern, ' ');
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    var charLength = 1;
    final firstCodeUnit = text.codeUnitAt(i);
    if (firstCodeUnit >= 0xd800 &&
        firstCodeUnit <= 0xdbff &&
        i + 1 < text.length) {
      final secondCodeUnit = text.codeUnitAt(i + 1);
      if (secondCodeUnit >= 0xdc00 && secondCodeUnit <= 0xdfff) {
        charLength = 2;
      }
    }

    final character = text.substring(i, i + charLength);
    buffer.write(caseFoldingMap[character] ?? character);
    i += charLength - 1;
  }
  return buffer.toString();
}

/// Normalizes a link destination, including the process of HTML characters
/// decoding and percent encoding.
// See the description of these examples:
// https://spec.commonmark.org/0.30/#example-501
// https://spec.commonmark.org/0.30/#example-502
String normalizeLinkDestination(String destination) {
  // Split by url escaping characters
  // Concatenate them with unmodified URL-escaping.
  // URL-escaping should be left alone inside the destination
  // Refer: https://spec.commonmark.org/0.30/#example-502.

  final regex = RegExp('%[0-9A-Fa-f]{2}');

  return destination.splitMapJoin(
    regex,
    onMatch: (m) => m.match,
    onNonMatch: (e) {
      try {
        e = Uri.decodeFull(e);
      } catch (_) {}
      return Uri.encodeFull(decodeHtmlCharacters(e));
    },
  );
}

/// Normalizes a link title by decoding HTML character references.
// See the description of these examples:
// https://spec.commonmark.org/0.30/#example-505
// https://spec.commonmark.org/0.30/#example-506
// https://spec.commonmark.org/0.30/#example-507
// https://spec.commonmark.org/0.30/#example-508
String normalizeLinkTitle(String title) => decodeHtmlCharacters(title);

///  Decodes HTML entity and numeric character references, for example decode
/// `&#35` to `#`.
String decodeHtmlCharacters(String input) =>
    input.replaceAllMapped(htmlCharactersPattern, decodeHtmlCharacterFromMatch);

/// Decodes HTML entity and numeric character references from the given [match].
String decodeHtmlCharacterFromMatch(Match match) {
  final text = match.match;
  final entity = match[1];
  final decimalNumber = match[2];
  final hexadecimalNumber = match[3];

  // Entity references, see
  // https://spec.commonmark.org/0.30/#entity-references.
  if (entity != null) {
    return htmlEntitiesMap[text] ?? text;
  }
  // Decimal numeric character references, see
  // https://spec.commonmark.org/0.30/#decimal-numeric-character-references.
  else if (decimalNumber != null) {
    return _decodeNumericCharacterReference(decimalNumber, radix: 10);
  }
  // Hexadecimal numeric character references, see
  // https://spec.commonmark.org/0.30/#hexadecimal-numeric-character-references.
  else if (hexadecimalNumber != null) {
    return _decodeNumericCharacterReference(hexadecimalNumber, radix: 16);
  }

  return text;
}

const _windows1252C1Remappings = <int>[
  0x20ac,
  0x0081,
  0x201a,
  0x0192,
  0x201e,
  0x2026,
  0x2020,
  0x2021,
  0x02c6,
  0x2030,
  0x0160,
  0x2039,
  0x0152,
  0x008d,
  0x017d,
  0x008f,
  0x0090,
  0x2018,
  0x2019,
  0x201c,
  0x201d,
  0x2022,
  0x2013,
  0x2014,
  0x02dc,
  0x2122,
  0x0161,
  0x203a,
  0x0153,
  0x009d,
  0x017e,
  0x0178,
];

String _decodeNumericCharacterReference(String digits, {required int radix}) {
  var value = 0;
  for (final digit in digits.codeUnits) {
    final digitValue =
        digit <= 0x39 ? digit - 0x30 : (digit | 0x20) - 0x61 + 10;
    if (value > (0x10ffff - digitValue) ~/ radix) {
      return '\uFFFD';
    }
    value = value * radix + digitValue;
  }

  if (value == 0 || (value >= 0xd800 && value <= 0xdfff)) {
    return '\uFFFD';
  }
  if (value >= 0x80 && value <= 0x9f) {
    value = _windows1252C1Remappings[value - 0x80];
  }
  return String.fromCharCode(value);
}

extension MatchExtensions on Match {
  /// Returns the whole match String
  String get match => this[0]!;
}

/// Escapes the ASCII punctuation characters after backslash(`\`).
String escapePunctuation(String input) {
  final buffer = StringBuffer();

  for (var i = 0; i < input.length; i++) {
    if (input.codeUnitAt(i) == $backslash) {
      final next = i + 1 < input.length ? input[i + 1] : null;
      if (next != null && asciiPunctuationCharacters.contains(next)) {
        i++;
      }
    }
    buffer.write(input[i]);
  }

  return buffer.toString();
}

extension StringExtensions on String {
  /// Calculates the length of indentation a `String` has.
  ///
  // The behavior of tabs: https://spec.commonmark.org/0.30/#tabs
  int indentation() {
    var length = 0;
    for (final char in codeUnits) {
      if (char != $space && char != $tab) {
        break;
      }
      length += char == $tab ? 4 - (length % 4) : 1;
    }
    return length;
  }

  /// Removes up to [length] characters of leading whitespace.
  // The way of handling tabs: https://spec.commonmark.org/0.30/#tabs
  DedentedText dedent([int length = 4]) {
    final whitespaceMatch = RegExp('^[ \t]{0,$length}').firstMatch(this);
    const tabSize = 4;

    int? tabRemaining;
    var start = 0;
    final whitespaces = whitespaceMatch?[0];
    if (whitespaces != null) {
      var indentLength = 0;
      for (; start < whitespaces.length; start++) {
        final isTab = whitespaces[start] == '\t';
        if (isTab) {
          indentLength += tabSize - (indentLength % tabSize);
          tabRemaining = indentLength;
        } else {
          indentLength += 1;
        }
        if (indentLength >= length) {
          if (tabRemaining != null) {
            tabRemaining = indentLength - length;
          }
          if (indentLength == length || isTab) {
            start += 1;
          }
          break;
        }
        if (tabRemaining != null) {
          tabRemaining = 0;
        }
      }
    }
    return DedentedText(substring(start), tabRemaining);
  }

  /// Adds [width] of spaces to the beginning of this string.
  String prependSpace(int width) => '${" " * width}$this';

  /// Whether this string contains only whitespaces.
  bool get isBlank => trim().isEmpty;

  /// Converts this string to a list of [Line].
  List<Line> toLines() => LineSplitter.split(this).map(Line.new).toList();

  /// Returns the last character.
  String last([int n = 1]) => substring(length - n);
}

/// A class that describes a dedented text.
class DedentedText {
  /// The dedented text.
  final String text;

  /// How many spaces of a tab that remains after part of it has been consumed.
  ///
  /// `null` means we did not read a `tab`.
  final int? tabRemaining;

  DedentedText(this.text, this.tabRemaining);
}
