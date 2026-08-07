// mhchem support for the math renderer.
//
// The app renders math with flutter_math_fork (a pure-Dart port of KaTeX).
// KaTeX does not load the mhchem extension by default, so `\ce{...}` (and
// `\pu{...}`) are undefined control sequences: every chemical formula used
// to fall back to the raw error text. This file rewrites the mhchem syntax
// into plain KaTeX that the port can render:
//
//   \ce{H2O}            -> {\mathrm{H_2O}}
//   \ce{2H2 + O2 -> 2H2O} -> {2\,\mathrm{H_2} {}+{} \mathrm{O_2}
//                             {}\mathrel{\longrightarrow}{} 2\,\mathrm{H_2O}}
//   \ce{SO4^2-}         -> {\mathrm{SO_4}^{2-}}
//   \pu{123 kJ/mol}     -> {123\,\mathrm{kJ}\,/\,\mathrm{mol}}
//
// The output follows the official mhchemParser (mhchem/mhchemParser, the
// parser used by KaTeX's mhchem contrib), simplified to the command set the
// Dart port supports and to what chat messages realistically use. Everything
// that is NOT `\ce{...}`/`\pu{...}` passes through untouched, and any
// conversion failure falls back to the original expression so rendering can
// never crash.

/// Expands the mhchem syntax (`\ce{...}` and `\pu{...}`) in [tex] into
/// KaTeX-compatible LaTeX that flutter_math_fork can render.
///
/// Returns [tex] unchanged when the input is malformed (e.g. an unclosed
/// `\ce{`), so the caller's existing error fallback keeps working.
String preprocessMhchem(String tex) {
  final out = StringBuffer();
  var i = 0;
  try {
    while (i < tex.length) {
      final open = _mhchemOpenBrace(tex, i);
      if (open == -1) {
        out.write(tex[i]);
        i++;
        continue;
      }
      final close = _matchingBrace(tex, open);
      if (close == -1) {
        // Unbalanced braces: leave the text as-is.
        out.write(tex[i]);
        i++;
        continue;
      }
      final isPu = tex[open - 2] == 'p'; // \pu vs \ce (\ p u {)
      final inner = tex.substring(open + 1, close);
      final converted = isPu ? _convertPu(inner) : _convertCe(inner);
      // `&` / `\\` belong to the surrounding alignment environment and must
      // not be wrapped in a group (mhchemParser skips the outer braces too).
      final needsTopLevel =
          converted.contains('&') || converted.contains(r'\\');
      out.write(needsTopLevel ? converted : '{$converted}');
      i = close + 1;
    }
  } on Object {
    // Never let a conversion failure break rendering.
    return tex;
  }
  return out.toString();
}

/// Index of the `{` after a `\ce`/`\pu` at [i], or -1 when [i] is not the
/// start of an mhchem command.
int _mhchemOpenBrace(String s, int i) {
  if (s[i] != r'\') return -1;
  if (i + 3 >= s.length) return -1;
  final ok = (s[i + 1] == 'c' && s[i + 2] == 'e') ||
      (s[i + 1] == 'p' && s[i + 2] == 'u');
  if (!ok) return -1;
  if (s[i + 3] != '{') return -1;
  return i + 3;
}

/// Index of the `}` matching the `{` at [open], counting nested braces,
/// or -1 when unbalanced.
int _matchingBrace(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') {
      depth++;
    } else if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

// ---------------------------------------------------------------------------
// \ce
// ---------------------------------------------------------------------------

String _convertCe(String input) => _CeParser(input).parse();

class _CeParser {
  _CeParser(this.src);

  final String src;
  int _pos = 0;
  int _depth = 0; // nesting level of ( [ inside the formula

  final StringBuffer _out = StringBuffer();
  final StringBuffer _formula = StringBuffer();

  // Pending unit state (mirrors mhchemParser's chemfive fields).
  String? _amount;
  String _leftSup = '';
  String _leftSub = '';
  String _rightSup = '';
  String _rightSub = '';
  bool _unitOpen = false; // any content attached to the current unit
  bool _spacePending = false; // space seen after a completed unit
  bool _afterBond = false; // the last emission was a bond (digit handling)

  String parse() {
    _loop();
    _flushUnit();
    return _out.toString();
  }

  bool get _atPhraseStart => _amount == null && !_unitOpen;

  bool get _hasUnitContent =>
      _unitOpen ||
      _amount != null ||
      _leftSup.isNotEmpty ||
      _leftSub.isNotEmpty;

  void _loop() {
    while (_pos < src.length) {
      final c = src[_pos];

      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        _onSpace();
        continue;
      }

      if (_atPhraseStart) {
        // Precipitate/gas arrows (`v`, `^`), checked before anything else
        // because a lone `^` or `v` at a phrase end is an arrow, not a
        // script or a variable.
        if (c == 'v' && _isPhraseEnd(_pos + 1)) {
          _pos++;
          _spacePending = false;
          _out.write(r'\downarrow');
          continue;
        }
        if (c == '^' && _isPhraseEnd(_pos + 1)) {
          _pos++;
          _spacePending = false;
          _out.write(r'\uparrow');
          continue;
        }
        // Upright entities (pH, pOH, ...) are formulas, not amounts —
        // checked before the amount scan like mhchemParser does.
        if (_tryUprightEntity()) continue;
        final amount = _tryScanAmount();
        if (amount != null) {
          _amount = amount;
          _unitOpen = true;
          continue;
        }
      }

      if (c == ')' || c == ']') {
        _pos++;
        if (_depth > 0) {
          _depth--;
          _appendFormula(c);
        } else {
          _appendRaw(c);
        }
        continue;
      }

      if (c == '(' || c == '[') {
        _onOpenGroup(c);
        continue;
      }

      if (c == r'$') {
        _onMathEscape();
        continue;
      }

      if (c == '{') {
        _onBraces();
        continue;
      }

      if (c == '^' || c == '_') {
        _onScript(c == '^');
        continue;
      }

      if (c == r'\') {
        _onBackslash();
        continue;
      }

      // Arrows must win over the single-char operators below.
      if (c == '-' || c == '<' || c == '→' || c == '⟶' || c == '⇌') {
        if (_tryArrow()) continue;
      }

      if (c == '+') {
        _pos++;
        if (_formula.isNotEmpty ||
            _rightSup.isNotEmpty ||
            _rightSub.isNotEmpty) {
          _rightSup += '+'; // charge
        } else {
          _flushUnit(); // flush a pending amount: `2 + 3H2O` -> `2\, {}+{} ...`
          _spacePending = false;
          _out.write(' {}+{} '); // binary operator
        }
        continue;
      }

      if (c == '-') {
        _onMinus();
        continue;
      }

      if (c == '=') {
        _pos++;
        if (_atPhraseStart) {
          _flushUnit();
          _spacePending = false;
          _out.write(' {}={} ');
        } else {
          _appendBond('{=}'); // double bond
        }
        continue;
      }

      if (c == '<' || c == '>') {
        _pos++;
        if (_atPhraseStart) {
          _flushUnit();
          _spacePending = false;
          _out.write(c == '<' ? ' {}<{} ' : ' {}>{} ');
        } else {
          _appendBond(c == '<' ? '{<}' : '{>}'); // bond
        }
        continue;
      }

      if (c == '#') {
        _pos++;
        _appendBond(r'{\equiv}'); // triple bond
        continue;
      }

      if (c == '.' || c == '·' || c == '⋅' || c == '∙' || c == '•') {
        _onDot();
        continue;
      }

      if (c == '*') {
        _pos++;
        while (_pos < src.length && src[_pos] == ' ') {
          _pos++;
        }
        _flushUnit();
        _out.write(r'\,{\cdot}\,');
        continue;
      }

      if (c == '&') {
        _pos++;
        _appendRaw('&');
        continue;
      }

      if (c == ',') {
        // Commas stay part of the formula (e.g. states like (aq, sat)).
        _pos++;
        _appendFormula(',');
        continue;
      }

      if (_isDigit(c)) {
        if (_atPhraseStart) {
          // Unreachable (amounts are scanned earlier), kept defensive.
          _amount = _scanDigits();
          _unitOpen = true;
        } else {
          final digits = _scanDigits();
          if (_afterBond) {
            // A digit right after a bond is a literal character
            // (mhchemParser's `-9` hyphen case): `X-2` -> `\mathrm{X}{-}\mathrm{2}`.
            _appendFormula(digits);
          } else {
            _appendFormula(digits.length == 1 ? '_$digits' : '_{$digits}');
          }
        }
        continue;
      }

      if (_isLetter(c)) {
        final start = _pos;
        while (_pos < src.length && _isLetter(src[_pos])) {
          _pos++;
        }
        _appendFormula(src.substring(start, _pos));
        continue;
      }

      // Anything else (`;`, `~`, `/`, `|`, `%`, unicode, ...) passes
      // through verbatim, like mhchemParser's "others" transition.
      if (c == '°' &&
          _pos + 1 < src.length &&
          (src[_pos + 1] == 'C' || src[_pos + 1] == 'F')) {
        _appendFormula('{}^{\\circ}${src[_pos + 1]}');
        _pos += 2;
        continue;
      }
      if (c == '%') {
        // `%` starts a TeX comment; escape it so the rest of the
        // expression (including the closing brace) is not swallowed.
        _appendFormula(r'\%');
        _pos++;
        continue;
      }
      _appendRaw(c);
      _pos++;
    }
  }

  // -- spaces ---------------------------------------------------------------

  void _onSpace() {
    _pos++;
    // A space right after a bare amount (`2 H2O`) attaches silently; once
    // the formula has started (`2e- + ...`) the space ends the unit.
    if (_amount != null &&
        _formula.isEmpty &&
        _rightSup.isEmpty &&
        _rightSub.isEmpty) {
      return;
    }
    if (_hasUnitContent) {
      _flushUnit();
      _spacePending = true;
    }
    // A space at a phrase start is insignificant.
  }

  // -- groups and states ----------------------------------------------------

  void _onOpenGroup(String open) {
    if (open == '(') {
      // (v) / (^) precipitate and gas arrows win at a phrase start.
      if (_atPhraseStart &&
          _pos + 2 < src.length &&
          (src[_pos + 1] == 'v' || src[_pos + 1] == '^') &&
          src[_pos + 2] == ')' &&
          _isPhraseEnd(_pos + 3)) {
        _pos += 3;
        _spacePending = false;
        _out.write(src[_pos - 2] == 'v' ? r'\downarrow' : r'\uparrow');
        return;
      }
      // State of aggregation / crystal system, e.g. (aq), (l), (s).
      // mhchemParser: `\([a-z]{1,3}` followed by `)` and a phrase end.
      final close = src.indexOf(')', _pos + 1);
      if (close != -1) {
        final content = src.substring(_pos + 1, close);
        final state = RegExp(r'^[a-z]{1,3}$').hasMatch(content);
        if (state && _isPhraseEnd(close + 1)) {
          _pos = close + 1;
          _emitPendingSpace();
          _flushUnit();
          _out.write(r'\mskip2mu \mathrm{(' + content + r')}');
          return;
        }
      }
    }
    _pos++;
    _appendFormula(open);
    _depth++;
  }

  // -- math escapes ($...$) --------------------------------------------------

  void _onMathEscape() {
    final close = src.indexOf(r'$', _pos + 1);
    if (close == -1) {
      _appendRaw(r'$');
      _pos++;
      return;
    }
    final content = src.substring(_pos + 1, close);
    if (_atPhraseStart && _amountLike(content) && _isElementAhead(close + 1)) {
      _amount = content; // e.g. `\ce{$n$ H2O}` -> `n\,\mathrm{H_2O}`
      _unitOpen = true;
    } else {
      _appendRaw(preprocessMhchem(content)); // italic math, nested \ce kept
    }
    _pos = close + 1;
  }

  // -- braces ---------------------------------------------------------------

  void _onBraces() {
    final close = _matchingBrace(src, _pos);
    if (close == -1) {
      _appendRaw('{');
      _pos++;
      return;
    }
    final content = src.substring(_pos + 1, close);
    if (content.isEmpty) {
      // `{}` separates scripts from a formula: `H{}^3HO` -> `\mathrm{H}{}^{3}...`
      _flushUnit();
    } else {
      _appendRaw(r'\text{' + content + r'}'); // upright text
    }
    _pos = close + 1;
  }

  // -- scripts (^ and _) ------------------------------------------------------

  void _onScript(bool isSup) {
    final isLeft = _atPhraseStart;
    _pos++; // consume ^ or _
    final content = _scriptContent();
    if (content == null) return; // e.g. a trailing `^` alone: dropped
    if (isLeft) {
      if (isSup) {
        _leftSup = content;
      } else {
        _leftSub = content;
      }
    } else {
      _unitOpen = true;
      if (isSup) {
        _rightSup += content;
      } else {
        _rightSub += content;
      }
    }
  }

  String? _scriptContent() {
    if (_pos >= src.length) return null;
    final c = src[_pos];
    if (c == '{') {
      final close = _matchingBrace(src, _pos);
      if (close == -1) return null;
      final content = src.substring(_pos + 1, close);
      _pos = close + 1;
      return content;
    }
    if (_isDigit(c)) {
      final start = _pos;
      while (_pos < src.length && _isDigit(src[_pos])) {
        _pos++;
      }
      return src.substring(start, _pos);
    }
    if (c == r'$') {
      final close = src.indexOf(r'$', _pos + 1);
      if (close == -1) return null;
      final content = src.substring(_pos + 1, close);
      _pos = close + 1;
      return content;
    }
    if (c == '-' || c == '+') {
      _pos++;
      if (_pos < src.length && _isDigit(src[_pos])) {
        final start = _pos;
        while (_pos < src.length && _isDigit(src[_pos])) {
          _pos++;
        }
        return c + src.substring(start, _pos);
      }
      return c;
    }
    if (c == r'\') {
      // e.g. `^\alpha`
      final start = _pos;
      _pos++;
      while (_pos < src.length && _isLetter(src[_pos])) {
        _pos++;
      }
      return src.substring(start, _pos);
    }
    if (c != '^' && c != '_') {
      _pos++;
      return c;
    }
    return null;
  }

  // -- backslash commands ------------------------------------------------------

  void _onBackslash() {
    // `\\` line break (alignment environments).
    if (_pos + 1 < src.length && src[_pos + 1] == r'\') {
      _pos += 2;
      _appendRaw(r'\\');
      return;
    }
    // Nested \ce{...} / \pu{...}.
    final nestedOpen = _mhchemOpenBrace(src, _pos);
    if (nestedOpen != -1) {
      final close = _matchingBrace(src, nestedOpen);
      if (close != -1) {
        _flushUnit();
        _out.write(preprocessMhchem(src.substring(_pos, close + 1)));
        _pos = close + 1;
        return;
      }
    }
    // \bond{...}
    if (_pos + 6 <= src.length && src.substring(_pos, _pos + 6) == r'\bond{') {
      final close = _matchingBrace(src, _pos + 5);
      if (close != -1) {
        final kind = src.substring(_pos + 6, close);
        _appendBond(_bondToTex(kind));
        _pos = close + 1;
        return;
      }
    }
    // \text{...}
    if (_pos + 6 <= src.length && src.substring(_pos, _pos + 6) == r'\text{') {
      final close = _matchingBrace(src, _pos + 5);
      if (close != -1) {
        _appendRaw(src.substring(_pos, close + 1));
        _pos = close + 1;
        return;
      }
    }
    // \frac{...}{...} — both arguments use the \ce syntax.
    final frac = _twoArgCommand(r'\frac{');
    if (frac != null) {
      _appendFormula('\\frac{${frac[0]}}{${frac[1]}}');
      return;
    }
    // \color{name}{...} — the color name is literal, the content is \ce.
    if (_pos + 7 <= src.length && src.substring(_pos, _pos + 7) == r'\color{') {
      final close1 = _matchingBrace(src, _pos + 6);
      if (close1 != -1) {
        final name = src.substring(_pos + 7, close1);
        final hasContent = close1 + 1 < src.length && src[close1 + 1] == '{';
        if (hasContent) {
          final close2 = _matchingBrace(src, close1 + 1);
          if (close2 != -1) {
            final content = src.substring(close1 + 2, close2);
            _appendRaw('{\\color{$name}{${_convertCe(content)}}}');
            _pos = close2 + 1;
            return;
          }
        }
        // \color{name} without content: a color switch for the rest of the
        // formula (mhchemParser's "color0" transition).
        _appendRaw('\\color{$name}');
        _pos = close1 + 1;
        return;
      }
    }
    // \ca (circa)
    if (_pos + 3 <= src.length &&
        src.substring(_pos, _pos + 3) == r'\ca' &&
        (_pos + 3 >= src.length || !_isLetter(src[_pos + 3]))) {
      _pos += 3;
      _appendFormula(r'{\sim}');
      return;
    }
    // \cdot — the compound-dot spelling: `\ce{CuSO4\cdot5H2O}`.
    if (_pos + 5 <= src.length &&
        src.substring(_pos, _pos + 5) == r'\cdot' &&
        (_pos + 5 >= src.length || !_isLetter(src[_pos + 5]))) {
      _pos += 5;
      _flushUnit();
      _out.write(r'\,{\cdot}\,');
      return;
    }
    // \pm operator
    if (_pos + 3 <= src.length &&
        src.substring(_pos, _pos + 3) == r'\pm' &&
        (_pos + 3 >= src.length || !_isLetter(src[_pos + 3]))) {
      _pos += 3;
      _flushUnit();
      _spacePending = false;
      _out.write(r' {}\pm{} ');
      return;
    }
    // Any other command: pass through. Greek letters (\alpha, \gamma, ...)
    // and math symbols belong inside the formula; `\left`/`\right` pairs
    // pass through as-is.
    var end = _pos + 1;
    while (end < src.length && _isLetter(src[end])) {
      end++;
    }
    if (end > _pos + 1) {
      final cmd = src.substring(_pos, end);
      _pos = end;
      // `\gamma{}` — mhchemParser consumes the empty braces with the command.
      if (_pos + 1 < src.length && src[_pos] == '{' && src[_pos + 1] == '}') {
        _pos += 2;
      }
      _appendFormula(cmd);
      return;
    }
    // Non-letter commands like `\,` `\;` `\ ` `\{` `\}` pass through.
    _appendRaw(src[_pos]);
    if (_pos + 1 < src.length) {
      _appendRaw(src[_pos + 1]);
      _pos += 2;
    } else {
      _pos++;
    }
  }

  /// For `\frac{..}{..}`-style commands: returns the two brace-group
  /// contents (each converted with the \ce syntax), or null when the
  /// command does not have two well-formed brace groups.
  List<String>? _twoArgCommand(String prefix) {
    if (_pos + prefix.length >= src.length ||
        src.substring(_pos, _pos + prefix.length) != prefix) {
      return null;
    }
    final open1 = _pos + prefix.length - 1; // the `{` in `\frac{`
    final close1 = _matchingBrace(src, open1);
    if (close1 == -1) return null;
    final open2 = close1 + 1;
    if (open2 >= src.length || src[open2] != '{') return null;
    final close2 = _matchingBrace(src, open2);
    if (close2 == -1) return null;
    final arg1 = src.substring(open1 + 1, close1);
    final arg2 = src.substring(open2 + 1, close2);
    _pos = close2 + 1;
    // The \ce conversion turns a bare number into an amount with a trailing
    // `\,` (e.g. `1/2`); strip it so `\frac{1}{2}` stays tight.
    String convert(String a) {
      var s = _convertCe(a);
      if (s.endsWith(r'\,')) s = s.substring(0, s.length - 2);
      return s;
    }

    return [convert(arg1), convert(arg2)];
  }

  // -- minus (charge / bond / operator) --------------------------------------

  void _onMinus() {
    if (_atPhraseStart) {
      _pos++;
      _flushUnit();
      _spacePending = false;
      _out.write(' {}-{} ');
      return;
    }
    final next = _pos + 1 < src.length ? src[_pos + 1] : null;
    final isCharge = next == null ||
        next == ' ' ||
        next == ')' ||
        next == ']' ||
        next == ',' ||
        next == ';' ||
        next == '/' ||
        next == '_' ||
        (next == '(' && _pos + 2 < src.length && _isLower(src[_pos + 2]));
    _pos++;
    if (isCharge) {
      _rightSup += '-';
      _unitOpen = true;
    } else {
      _appendBond('{-}'); // bond
    }
  }

  // -- dots -------------------------------------------------------------------

  void _onDot() {
    // `...` is a special bond; a single `.` is an addition compound.
    if (_pos + 2 < src.length &&
        src[_pos + 1] == '.' &&
        src[_pos + 2] == '.' &&
        (_pos + 3 >= src.length || src[_pos + 3] != '.')) {
      _pos += 3;
      _appendBond(r'{{\cdot}{\cdot}{\cdot}}');
      return;
    }
    _pos++;
    while (_pos < src.length && src[_pos] == ' ') {
      _pos++;
    }
    _flushUnit();
    _out.write(r'\,{\cdot}\,');
  }

  // -- arrows -----------------------------------------------------------------

  static const _arrowTable = <String, (String, String)>{
    // mhchem symbol -> (plain arrow, stretchy `\x...` variant).
    // `<=>>`/`<<=>` fall back to the closest symbol the port has
    // (\Rightleftharpoons and \Leftrightharpoons are not defined in
    // flutter_math_fork), and `<-->` uses \leftrightarrow because there is
    // no long double-headed arrow in the port.
    '<=>>': (r'\rightleftharpoons', r'\xrightleftharpoons'),
    '<<=>': (r'\leftrightarrows', r'\xleftrightharpoons'),
    '<=>': (r'\rightleftharpoons', r'\xrightleftharpoons'),
    '<-->': (r'\leftrightarrow', r'\xleftrightarrow'),
    '<->': (r'\leftrightarrow', r'\xleftrightarrow'),
    '<-': (r'\leftarrow', r'\xleftarrow'),
    '->': (r'\rightarrow', r'\xrightarrow'),
  };

  bool _tryArrow() {
    final rest = src.substring(_pos);
    String? symbol;
    for (final key in const [
      '<=>>',
      '<<=>',
      '<-->',
      '<=>',
      '<->',
      '<-',
      '->'
    ]) {
      if (rest.startsWith(key)) {
        symbol = key;
        break;
      }
    }
    var consumed = 0;
    if (symbol == null) {
      final c = src[_pos];
      if (c == '→' || c == '⟶') {
        symbol = '->';
        consumed = 1;
      } else if (c == '⇌') {
        symbol = '<=>';
        consumed = 1;
      } else {
        return false;
      }
    } else {
      consumed = symbol.length;
    }
    var after = _pos + consumed;
    // Optional labels: ->[above][below].
    var above = '';
    var below = '';
    var hasLabels = false;
    if (after < src.length && src[after] == '[') {
      hasLabels = true;
      final close = src.indexOf(']', after + 1);
      if (close == -1) return false; // malformed: not an arrow
      above = _convertCe(src.substring(after + 1, close));
      after = close + 1;
      if (after < src.length && src[after] == '[') {
        final close2 = src.indexOf(']', after + 1);
        if (close2 != -1) {
          below = _convertCe(src.substring(after + 1, close2));
          after = close2 + 1;
        }
      }
    }
    _pos = after;
    final (plain, x) = _arrowTable[symbol]!;
    _flushUnit();
    _spacePending = false;
    if (hasLabels) {
      final arrow = below.isEmpty ? '$x{$above}' : '$x[$below]{$above}';
      _out.write(' {}\\mathrel{$arrow}{} ');
    } else {
      // mhchemParser renders unlabeled arrows as `\long` + arrow.
      final long =
          plain == r'\rightleftharpoons' || plain == r'\leftrightarrows'
              ? plain
              : r'\long' + plain.substring(1);
      _out.write(' {}\\mathrel{$long}{} ');
    }
    return true;
  }

  // -- amounts ---------------------------------------------------------------

  /// `pH`, `pOH`, `pK`, `pC`, `iPr`, `iBu` are upright entities, not a
  /// variable coefficient followed by an element (mhchemParser checks these
  /// before its amount pattern too).
  bool _tryUprightEntity() {
    for (final e in const ['pH', 'pOH', 'pC', 'pK', 'iPr', 'iBu']) {
      if (src.startsWith(e, _pos) &&
          (_pos + e.length >= src.length || !_isLetter(src[_pos + e.length]))) {
        _pos += e.length;
        _appendFormula(e);
        return true;
      }
    }
    return false;
  }

  String? _tryScanAmount() {
    final i = _pos;
    final n = src.length;
    // Single lowercase variable: `x Na(NH4)HPO4`, `n H2O`.
    if (_isLower(src[i]) && _isElementAhead(i + 1)) {
      _pos = i + 1;
      return src[i];
    }
    // (n/m) parenthesized fraction.
    final parenFrac = RegExp(r'\([0-9]+\/[0-9]+\)').matchAsPrefix(src, i);
    if (parenFrac != null) {
      _pos = i + parenFrac[0]!.length;
      return parenFrac[0]!;
    }
    // Number (integer or decimal).
    final number =
        RegExp(r'(?:[0-9]+[.,][0-9]+|\.[0-9]+|[0-9]+)').matchAsPrefix(src, i);
    if (number == null) return null;
    var end = i + number[0]!.length;
    // Variable suffix: `2n H2O`.
    if (end < n && _isLower(src[end]) && _isElementAhead(end + 1)) {
      end++;
    } else if (end < n &&
        src[end] == '/' &&
        end + 1 < n &&
        _isDigit(src[end + 1])) {
      // Fraction coefficient: `1/2 H2O` -> `\frac{1}{2}\,\mathrm{H_2O}`.
      var j = end + 1;
      while (j < n && _isDigit(src[j])) {
        j++;
      }
      end = j;
    }
    _pos = end;
    return src.substring(i, end);
  }

  /// True when the `$...$` [content] looks like an amount (`$n$`, `$2n-1$`).
  bool _amountLike(String content) {
    if (content == '+' || content == '-') return true;
    return RegExp(r'^\(?[+\-]?(?:[0-9]*[a-z]?[+\-])?[0-9]*[a-z]'
            r'(?:[+\-][0-9]*[a-z]?)?\)?$')
        .hasMatch(content);
  }

  /// True when an element (or a math escape) follows after optional spaces.
  bool _isElementAhead(int i) {
    var j = i;
    while (j < src.length && (src[j] == ' ' || src[j] == '\t')) {
      j++;
    }
    if (j >= src.length) return false;
    final c = src[j];
    return _isUpper(c) || c == r'\' || c == r'$';
  }

  bool _isPhraseEnd(int i) {
    if (i >= src.length) return true;
    final c = src[i];
    return c == ' ' ||
        c == '\t' ||
        c == ')' ||
        c == ']' ||
        c == ',' ||
        c == ';';
  }

  // -- output helpers ----------------------------------------------------------

  void _appendFormula(String s) {
    _unitOpen = true;
    _afterBond = false;
    _formula.write(s);
  }

  /// A bond (`{-}`, `{=}`, `{\equiv}`, ...) renders outside `\mathrm{}`,
  /// like mhchemParser does.
  void _appendBond(String s) {
    _unitOpen = true;
    _afterBond = true;
    _flushFormulaSegment();
    _out.write(s);
  }

  void _appendRaw(String s) {
    _emitPendingSpace();
    _flushFormulaSegment();
    _out.write(s);
    _unitOpen = true;
    _afterBond = false;
  }

  void _emitPendingSpace() {
    if (_spacePending) {
      _out.write('~');
      _spacePending = false;
    }
  }

  void _flushFormulaSegment() {
    if (_formula.isNotEmpty) {
      _out.write('\\mathrm{${_formula.toString()}}');
      _formula.clear();
    }
  }

  void _flushUnit() {
    if (!_hasUnitContent) {
      _spacePending = false;
      return;
    }
    _emitPendingSpace();
    if (_amount != null) {
      var a = _amount!;
      // `1/2` becomes a proper fraction; `(1/2)` stays verbatim.
      if (RegExp(r'^[0-9]+\/[0-9]+$').hasMatch(a)) {
        final parts = a.split('/');
        a = r'\frac{' + parts[0] + r'}{' + parts[1] + r'}';
      }
      if (a.startsWith('+') || a.startsWith('-')) a = '{$a}';
      _out.write('$a\\,');
      _amount = null;
    }
    if (_leftSup.isNotEmpty || _leftSub.isNotEmpty) {
      _out.write('{}');
      if (_leftSup.isNotEmpty) _out.write('^{$_leftSup}');
      if (_leftSub.isNotEmpty) _out.write('_{$_leftSub}');
      _leftSup = '';
      _leftSub = '';
    }
    _flushFormulaSegment();
    if (_rightSup.isNotEmpty || _rightSub.isNotEmpty) {
      if (_rightSup.isNotEmpty) _out.write('^{$_rightSup}');
      if (_rightSub.isNotEmpty) _out.write('_{$_rightSub}');
      _rightSup = '';
      _rightSub = '';
    }
    _unitOpen = false;
  }

  String _scanDigits() {
    final start = _pos;
    while (_pos < src.length && _isDigit(src[_pos])) {
      _pos++;
    }
    return src.substring(start, _pos);
  }

  static String _bondToTex(String kind) {
    switch (kind) {
      case '-':
      case '1':
        return '{-}';
      case '=':
      case '2':
        return '{=}';
      case '#':
      case '3':
        return r'{\equiv}';
      case '->':
        return r'{\rightarrow}';
      case '<-':
        return r'{\leftarrow}';
      case '<':
        return '{<}';
      case '>':
        return '{>}';
      case '...':
        return r'{{\cdot}{\cdot}{\cdot}}';
      default:
        // `~` (wavy bond) and friends are not in the port's symbol table.
        return '{-}';
    }
  }
}

// ---------------------------------------------------------------------------
// \pu
// ---------------------------------------------------------------------------

String _convertPu(String input) {
  final out = StringBuffer();
  var i = 0;
  final n = input.length;
  while (i < n) {
    final c = input[i];

    if (c == ' ' || c == '\t') {
      i++;
      out.write(r'\,');
      continue;
    }

    if (c == r'\') {
      // \pm, \times, \text{...} and other commands pass through.
      var end = i + 1;
      while (end < n && _isLetter(input[end])) {
        end++;
      }
      if (end > i + 1) {
        final cmd = input.substring(i, end);
        i = end;
        if (i < n && input[i] == '{') {
          final close = _matchingBrace(input, i);
          if (close != -1) {
            out.write(cmd + input.substring(i, close + 1));
            i = close + 1;
            continue;
          }
        }
        out.write(cmd);
        continue;
      }
      out.write(input[i]);
      i++;
      continue;
    }

    // `//` stacked fraction: \pu{123 kJ//mol}.
    if (c == '/' && i + 1 < n && input[i + 1] == '/') {
      final numerator = out.toString();
      out.clear();
      final end = _puDenominatorEnd(input, i + 2);
      final denom = _convertPu(input.substring(i + 2, end).trim());
      out.write('\\frac{$numerator}{$denom}');
      i = end;
      continue;
    }
    // Single `/`: \pu{123 kJ/mol}.
    if (c == '/') {
      final end = _puDenominatorEnd(input, i + 1);
      out.write(r'\,/\,');
      out.write(_convertPu(input.substring(i + 1, end).trim()));
      i = end;
      continue;
    }

    // `*` / `.` between units: \pu{123 kJ*mol-1}.
    if (c == '*' || c == '.') {
      i++;
      out.write(r'\,{\cdot}\,');
      continue;
    }

    // Numbers (with optional sign, decimal point and exponent).
    if (_isDigit(c) ||
        ((c == '+' || c == '-' || c == '.') &&
            i + 1 < n &&
            _isDigit(input[i + 1]))) {
      final number = RegExp(r'[+\-]?(?:[0-9]+[.,][0-9]+|\.[0-9]+|[0-9]+)')
          .matchAsPrefix(input, i);
      if (number != null) {
        final num = number[0]!;
        var end = i + num.length;
        // Exponent: 1.2e7 -> 1.2\cdot 10^{7}; 2x10^5 -> 2\times 10^{5}.
        final exp = RegExp(r'(?:[eE]([+\-]?[0-9]+)|'
                r'\s*((?:\*|x|\\times|×))\s*10\^([+\-]?[0-9]+|\{[+\-]?[0-9]+\}))')
            .matchAsPrefix(input, end);
        if (exp != null) {
          final e = exp.group(1);
          final mult = exp.group(2);
          final power = exp.group(3);
          if (e != null) {
            // 1.2e7 -> 1.2\cdot 10^{7}
            out.write('$num\\cdot 10^{$e}');
          } else {
            final times = mult == 'x' || mult == r'\times' || mult == '×';
            out.write('$num${times ? r'\times ' : r'\cdot '}10^{$power}');
          }
          end += exp[0]!.length;
        } else {
          out.write(num);
          if (end < n && input[end] == '^') {
            // 2^3 -> 2^{3}
            final sup = _puScriptContent(input, end + 1);
            if (sup != null) {
              out.write('^{${sup.content}}');
              end = sup.end;
            } else {
              end++;
            }
          }
        }
        i = end;
        continue;
      }
    }

    // Exponents on units: m^2, s^-2.
    if (c == '^') {
      final sup = _puScriptContent(input, i + 1);
      if (sup != null) {
        out.write('^{${sup.content}}');
        i = sup.end;
        continue;
      }
      i++;
      continue;
    }
    if (c == '_') {
      final sub = _puScriptContent(input, i + 1);
      if (sub != null) {
        out.write('_{${sub.content}}');
        i = sub.end;
        continue;
      }
      i++;
      continue;
    }

    // `{...}` group: \pu{{123 kJ}} -> {123\,\mathrm{kJ}}.
    if (c == '{') {
      final close = _matchingBrace(input, i);
      if (close != -1) {
        out.write(_convertPu(input.substring(i + 1, close)));
        i = close + 1;
        continue;
      }
    }

    // `°C` / `°F` temperatures.
    if (c == '°' && i + 1 < n) {
      if (input[i + 1] == 'C' || input[i + 1] == 'F') {
        out.write('{}^{\\circ}${input[i + 1]}');
        i += 2;
        continue;
      }
    }

    // Unit letter run: kJ, mol, m, s...
    if (_isLetter(c)) {
      final start = i;
      while (i < n && _isLetter(input[i])) {
        i++;
      }
      out.write('\\mathrm{${input.substring(start, i)}}');
      // mol-1 -> mol^{-1}
      if (i < n && input[i] == '-' && i + 1 < n && _isDigit(input[i + 1])) {
        final startExp = i;
        i++;
        while (i < n && _isDigit(input[i])) {
          i++;
        }
        out.write('^{${input.substring(startExp, i)}}');
      }
      continue;
    }

    // Anything else (operators like = < >, |, ...) passes through; `%`
    // must be escaped because it starts a TeX comment.
    if (c == '%') {
      out.write(r'\%');
      i++;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// End index of a `\pu` denominator: everything up to the next operator.
int _puDenominatorEnd(String input, int from) {
  var i = from;
  while (i < input.length) {
    final c = input[i];
    if (c == '+' || c == '=' || c == '<' || c == '>') break;
    if (c == '-' && i + 1 < input.length && _isDigit(input[i + 1])) break;
    i++;
  }
  return i;
}

/// Content of a `^`/`_` script in `\pu` (digits or a braced group).
({String content, int end})? _puScriptContent(String input, int from) {
  if (from >= input.length) return null;
  if (input[from] == '{') {
    final close = _matchingBrace(input, from);
    if (close == -1) return null;
    return (content: input.substring(from + 1, close), end: close + 1);
  }
  final sign = input[from] == '-' || input[from] == '+' ? 1 : 0;
  final start = from + sign;
  if (start >= input.length || !_isDigit(input[start])) return null;
  var end = start;
  while (end < input.length && _isDigit(input[end])) {
    end++;
  }
  return (content: input.substring(from, end), end: end);
}

// -- character helpers --------------------------------------------------------

bool _isDigit(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x30 && u <= 0x39;
}

bool _isUpper(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x41 && u <= 0x5a;
}

bool _isLower(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x61 && u <= 0x7a;
}

bool _isLetter(String c) => _isUpper(c) || _isLower(c);
