import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// All editing is structural: templates use MathLive's selection/placeholder
/// arguments, and navigation operates on the rendered document, not text.
class MathKeyboard extends StatefulWidget {
  final Future<void> Function(String kind, String value) onCommand;
  final VoidCallback onDismiss;
  final VoidCallback onPlot;
  final String activeLabel;
  final bool enabled;
  const MathKeyboard(
      {super.key,
      required this.onCommand,
      required this.onDismiss,
      required this.onPlot,
      required this.activeLabel,
      this.enabled = true});

  @override
  State<MathKeyboard> createState() => _MathKeyboardState();
}

class _MathKeyboardState extends State<MathKeyboard> {
  String _category = '常用';
  int _page = 0;
  static const _numbers = [
    '7',
    '8',
    '9',
    '4',
    '5',
    '6',
    '1',
    '2',
    '3',
    '0',
    '.',
    '⌫'
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keys = _groups[_category]!;
    final pageCount = (keys.length / 12).ceil();
    return Material(
        color: cs.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                height: 44,
                child: Row(children: [
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          widget.enabled
                              ? '${widget.activeLabel} · 点击公式定位，长按选择'
                              : '${widget.activeLabel} · 正在准备数学输入…',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 1)),
                  _action(Icons.undo, '撤销', 'undo'),
                  _action(Icons.redo, '重做', 'redo'),
                  PopupMenuButton<String>(
                    tooltip: '选择与剪贴板',
                    enabled: widget.enabled,
                    onSelected: (action) => widget.onCommand(
                        action == 'selectAll' ? 'command' : 'clipboard',
                        action),
                    itemBuilder: (_) => [
                      for (final entry in {
                        'selectAll': '全选',
                        'copy': '复制 LaTeX',
                        'cut': '剪切',
                        'paste': '粘贴公式'
                      }.entries)
                        PopupMenuItem(
                            value: entry.key, child: Text(entry.value))
                    ],
                  ),
                  IconButton(
                      onPressed: widget.onDismiss,
                      tooltip: '收起数学键盘',
                      icon: const Icon(Icons.keyboard_hide)),
                ])),
            SizedBox(
                height: 38,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final category in _groups.keys)
                        Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: category == _category,
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() {
                                _category = category;
                                _page = 0;
                              }),
                            )),
                    ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: Column(children: [
                  for (var row = 0; row < 4; row++)
                    Row(children: [
                      for (var col = 0; col < 6; col++)
                        Expanded(
                            child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _key(col < 3
                              ? (_page * 12 + row * 3 + col < keys.length
                                  ? keys[_page * 12 + row * 3 + col]
                                  : null)
                              : _MathKey(_numbers[row * 3 + col - 3],
                                  _numbers[row * 3 + col - 3],
                                  command: _numbers[row * 3 + col - 3] == '⌫'
                                      ? 'deleteBackward'
                                      : null)),
                        )),
                    ]),
                ])),
            SizedBox(
                height: 44,
                child: Row(children: [
                  Expanded(
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            _action(Icons.chevron_left, '光标左移',
                                'moveToPreviousChar'),
                            _action(
                                Icons.chevron_right, '光标右移', 'moveToNextChar'),
                            TextButton(
                                onPressed: widget.enabled
                                    ? () => widget.onCommand('previous', '')
                                    : null,
                                child: const Text('上一项')),
                            TextButton(
                                onPressed: widget.enabled
                                    ? () => widget.onCommand('next', '')
                                    : null,
                                child: const Text('下一项')),
                            if (pageCount > 1)
                              TextButton(
                                  onPressed: () => setState(
                                      () => _page = (_page + 1) % pageCount),
                                  child: Text('${_page + 1}/$pageCount ▸')),
                          ]))),
                  TextButton(onPressed: widget.onPlot, child: const Text('绘图')),
                ])),
          ]),
        ));
  }

  Widget _action(IconData icon, String label, String command) => IconButton(
        icon: Icon(icon, size: 20),
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed:
            widget.enabled ? () => widget.onCommand('command', command) : null,
      );

  Widget _key(_MathKey? key) => SizedBox(
      height: 44,
      child: key == null
          ? const SizedBox.shrink()
          : Tooltip(
              message: key.description ?? key.label,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6))),
                onPressed: !widget.enabled
                    ? null
                    : () => widget.onCommand(
                        key.command == null ? 'insert' : 'command',
                        key.command ?? key.value),
                child: key.label == '⌫'
                    ? const Icon(Icons.backspace_outlined, size: 20)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Math.tex(key.label,
                            textStyle: const TextStyle(fontSize: 18),
                            onErrorFallback: (_) => Text(key.label,
                                style: const TextStyle(fontSize: 13)))),
              ),
            ));
}

class _MathKey {
  final String label, value;
  final String? command, description;
  const _MathKey(this.label, this.value, {this.command, this.description});
}

final Map<String, List<_MathKey>> _groups = {
  '常用': const [
    _MathKey('x', 'x'),
    _MathKey('y', 'y'),
    _MathKey('=', '='),
    _MathKey(r'\frac{a}{b}', r'\frac{#0}{#?}', description: '分数：选区放入分子'),
    _MathKey(r'x^2', r'#@^{2}', description: '平方：选区或左侧完整项'),
    _MathKey(r'x^n', r'#@^{#?}', description: '幂：进入指数'),
    _MathKey(r'\sqrt{x}', r'\sqrt{#0}'),
    _MathKey(r'\left(x\right)', r'\left(#0\right)'),
    _MathKey('+', '+'),
    _MathKey('-', '-'),
    _MathKey(r'\times', r'\cdot'),
    _MathKey(r'\pi', r'\pi'),
    _MathKey('e', 'e'),
    _MathKey(r'\div', r'\frac{#@}{#?}'),
    _MathKey(r'\left|x\right|', r'\left|#0\right|'),
    _MathKey(r'\sqrt[n]{x}', r'\sqrt[#?]{#0}'),
    _MathKey(r'x_n', r'#@_{#?}'),
    _MathKey(r'\pm', r'\pm'),
    _MathKey(r'\%', r'\%'),
    _MathKey(r'\infty', r'\infty'),
    _MathKey(', ', ','),
  ],
  '函数': [
    for (final name in [
      'sin',
      'cos',
      'tan',
      'cot',
      'sec',
      'csc',
      'arcsin',
      'arccos',
      'arctan',
      'sinh',
      'cosh',
      'tanh',
      'ln',
      'log',
      'exp'
    ])
      _MathKey('\\$name', '\\$name\\left(#0\\right)',
          description: '$name（角度用弧度）'),
    const _MathKey(r'\log_a x', r'\log_{#?}\left(#0\right)'),
    const _MathKey(r'e^x', r'e^{#0}'),
    const _MathKey(r'\lfloor x\rfloor', r'\left\lfloor#0\right\rfloor'),
    const _MathKey(r'\lceil x\rceil', r'\left\lceil#0\right\rceil'),
    const _MathKey('n!', r'#@!'),
    for (final name in ['min', 'max', 'det', 'gcd', 'arg', 'Re', 'Im'])
      _MathKey('\\$name', '\\$name\\left(#0\\right)'),
  ],
  '结构': const [
    _MathKey(r'\sum', r'\sum_{#?}^{#?}#0'),
    _MathKey(r'\prod', r'\prod_{#?}^{#?}#0'),
    _MathKey(r'\int', r'\int_{#?}^{#?}#0\,\mathrm{d}x'),
    _MathKey(r'\iint', r'\iint_{#?}#0'),
    _MathKey(r'\oint', r'\oint_{#?}#0'),
    _MathKey(r'\lim', r'\lim_{x\to#?}#0'),
    _MathKey(r'\frac{\mathrm{d}}{\mathrm{d}x}',
        r'\frac{\mathrm{d}}{\mathrm{d}x}\left(#0\right)'),
    _MathKey(r'\frac{\partial}{\partial x}', r'\frac{\partial #0}{\partial x}'),
    _MathKey(r'\binom{n}{k}', r'\binom{#0}{#?}'),
    _MathKey(r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
        r'\begin{pmatrix}#?&#?\\#?&#?\end{pmatrix}'),
    _MathKey(r'\begin{bmatrix}a&b\\c&d\end{bmatrix}',
        r'\begin{bmatrix}#?&#?\\#?&#?\end{bmatrix}'),
    _MathKey(r'\begin{cases}a&x>0\\b&x\le0\end{cases}',
        r'\begin{cases}#?&#?\\#?&#?\end{cases}'),
    _MathKey('加行', '', command: 'addRowAfter'),
    _MathKey('加列', '', command: 'addColumnAfter'),
    _MathKey('删行', '', command: 'removeRow'),
    _MathKey('删列', '', command: 'removeColumn'),
    _MathKey(r'\left[x\right]', r'\left[#0\right]'),
    _MathKey(r'\left\{x\right\}', r'\left\{#0\right\}'),
    _MathKey(r'\langle x\rangle', r'\left\langle#0\right\rangle'),
    _MathKey(r'\left\|x\right\|', r'\left\|#0\right\|'),
  ],
  '关系': [
    for (final symbol in [
      r'\ne',
      r'\le',
      r'\ge',
      '<',
      '>',
      r'\approx',
      r'\equiv',
      r'\propto',
      r'\in',
      r'\notin',
      r'\subset',
      r'\subseteq',
      r'\supset',
      r'\cup',
      r'\cap',
      r'\emptyset',
      r'\forall',
      r'\exists',
      r'\neg',
      r'\land',
      r'\lor',
      r'\to',
      r'\Rightarrow',
      r'\Leftrightarrow',
      r'\mapsto',
      r'\perp',
      r'\parallel',
      r'\angle',
      r'\circ',
      r'\cdots',
      r'\vdots',
      r'\ddots'
    ])
      _MathKey(symbol, symbol)
  ],
  '希腊': [
    for (final name in [
      'alpha',
      'beta',
      'gamma',
      'delta',
      'epsilon',
      'varepsilon',
      'zeta',
      'eta',
      'theta',
      'vartheta',
      'iota',
      'kappa',
      'lambda',
      'mu',
      'nu',
      'xi',
      'pi',
      'rho',
      'sigma',
      'tau',
      'upsilon',
      'phi',
      'varphi',
      'chi',
      'psi',
      'omega',
      'Gamma',
      'Delta',
      'Theta',
      'Lambda',
      'Xi',
      'Pi',
      'Sigma',
      'Upsilon',
      'Phi',
      'Psi',
      'Omega'
    ])
      _MathKey('\\$name', '\\$name')
  ],
  '字母': [
    for (final letter
        in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
      _MathKey(letter, letter)
  ],
  '样式': [
    for (final name in [
      'vec',
      'hat',
      'bar',
      'dot',
      'ddot',
      'overline',
      'underline',
      'overbrace',
      'underbrace',
      'overrightarrow',
      'overleftarrow',
      'widetilde'
    ])
      _MathKey('\\$name{x}', '\\$name{#0}'),
    for (final name in [
      'mathrm',
      'mathbf',
      'mathit',
      'mathbb',
      'mathcal',
      'mathfrak',
      'mathsf',
      'mathtt'
    ])
      _MathKey('\\$name{A}', '\\$name{#0}'),
  ],
};
