/* Stroom bridge. Drafts stay verbatim until the first mathematical edit. */
(() => {
  const field = document.getElementById('formula');
  const problem = document.getElementById('problem');
  MathLive.MathfieldElement.fontsDirectory = new URL('./fonts', document.baseURI).href;
  MathLive.MathfieldElement.soundsDirectory = null;
  MathLive.MathfieldElement.keypressVibration = false;
  MathLive.MathfieldElement.keypressSound = null;
  MathLive.MathfieldElement.plonkSound = null;
  field.mathVirtualKeyboardPolicy = 'manual';
  field.smartFence = true;
  field.defaultMode = 'math';
  let revision = -1, sequence = 0, original = '', canonical = '', edited = false, importing = false;
  function plainToLatex(source) {
    source = source.replace(/(?<!\\)\b(asin|acos|atan)\b/g, name => 'arc' + name.slice(1));
    if (!/[\\{}]/.test(source)) return MathLive.convertAsciiMathToLatex(source);
    // Existing source can mix legacy function calls with braced powers. Keep
    // TeX groups intact; convert only complete unescaped function calls.
    const calls = /(?<!\\)\b(sqrt|abs|sin|cos|tan|arcsin|arccos|arctan|cot|sec|csc|sinh|cosh|tanh|ln|log|exp)\s*\(/g;
    let result = '', from = 0, match;
    while ((match = calls.exec(source))) {
      const begin = calls.lastIndex;
      let depth = 1, end = begin;
      while (end < source.length && depth) {
        if (source[end] === '(') depth++;
        if (source[end] === ')') depth--;
        end++;
      }
      if (depth) break;
      const body = plainToLatex(source.slice(begin,end-1));
      const name = match[1];
      const latex = name === 'sqrt' ? '\\sqrt{' + body + '}'
        : name === 'abs' ? '\\left|' + body + '\\right|'
        : '\\' + name + '\\left(' + body + '\\right)';
      result += source.slice(from,match.index) + latex;
      from = end; calls.lastIndex = end;
    }
    return (result + source.slice(from)).replace(/(?<!\\)\bpi\b/g,'\\pi');
  }
  function observeChanges() {
    const current = field.getValue('latex');
    if (!importing && current !== canonical) {
      canonical = current;
      edited = true;
      sequence++;
    }
  }
  function snapshot() {
    // MathLive's input event is deferred. Read the model synchronously so a
    // Plot/toggle immediately after an insertion still sees that insertion.
    observeChanges();
    return {revision, sequence, latex: edited ? field.getValue('latex') : original,
      edited, height: field.getBoundingClientRect().height + problem.getBoundingClientRect().height,
      errors: field.errors.map(e => e.code), canUndo: field.canUndo(), canRedo: field.canRedo()};
  }
  function send(type) {
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('StroomMathEditor', {type, ...snapshot()});
    }
  }
  function showProblem() {
    const bad = field.errors.length > 0;
    field.readOnly = bad;
    problem.style.display = bad ? 'block' : 'none';
    problem.textContent = bad ? '此源码含暂不支持或未完成的语法，请用右侧按钮切换源码修正。原文已保留。' : '';
  }
  window.stroomMath = {
    setSource(source, version) {
      importing = true;
      const unchanged = source === snapshot().latex;
      revision = version; original = source;
      if (!unchanged) {
        edited = false;
        field.setValue(plainToLatex(source), {silenceNotifications:true});
        canonical = field.getValue('latex');
        if (version === 0) field.resetUndo();
      }
      importing = false;
      showProblem();
      return snapshot();
    },
    snapshot,
    selectedLatex() { return field.getValue(field.selection, 'latex'); },
    activate() { field.focus(); return snapshot(); },
    blur() { field.blur(); return snapshot(); },
    theme(ink, accent, error) {
      document.documentElement.style.setProperty('--ink', ink);
      document.documentElement.style.setProperty('--accent', accent);
      document.documentElement.style.setProperty('--error', error);
    },
    command(kind, value) {
      if (field.readOnly) return snapshot();
      field.focus();
      if (kind === 'insert') field.insert(value, {format:'latex', selectionMode:'placeholder'});
      else if (kind === 'next') {
        if (!field.executeCommand('moveToNextPlaceholder')) field.executeCommand('moveAfterParent');
      } else if (kind === 'previous') {
        if (!field.executeCommand('moveToPreviousPlaceholder')) field.executeCommand('moveBeforeParent');
      } else field.executeCommand(value);
      return snapshot();
    }
  };
  field.addEventListener('input', () => {
    if (importing) return;
    observeChanges();
    send('input');
  });
  field.addEventListener('focus', () => send('focus'));
  field.addEventListener('selection-change', () => send('selection'));
  // Rendering and font loading can finish after a command returns. Observe
  // actual layout rather than measuring only the pre-render command snapshot.
  const sizeObserver = new ResizeObserver(() => send('resize'));
  sizeObserver.observe(field);
  sizeObserver.observe(problem);
  field.addEventListener('mount', () => {
    // MathLive's hidden textarea must never summon the system IME here.
    const keyboardSink = field.shadowRoot.querySelector('[part=keyboard-sink]');
    if (keyboardSink) keyboardSink.setAttribute('inputmode','none');
    send('ready');
  });
  field.addEventListener('keydown', event => {
    if (event.key === 'Enter') { event.preventDefault(); send('submit'); }
  });
})();
