/* Stroom bridge. Drafts stay verbatim until the first mathematical edit. */
(() => {
  const field = document.getElementById('formula');
  const problem = document.getElementById('problem');
  const navigation = window.stroomNavigation(field);
  MathLive.MathfieldElement.fontsDirectory = new URL('./fonts', document.baseURI).href;
  MathLive.MathfieldElement.soundsDirectory = null;
  MathLive.MathfieldElement.keypressVibration = false;
  MathLive.MathfieldElement.keypressSound = null;
  MathLive.MathfieldElement.plonkSound = null;
  field.mathVirtualKeyboardPolicy = 'manual';
  field.smartFence = true;
  field.defaultMode = 'math';
  let revision = -1, sequence = 0, original = '', canonical = '', selection = '', edited = false, importing = false;
  // Text/operator names contain literal underscores, not mathematical scripts.
  function mapMath(source, transform, literal = text => text) {
    const groups = /\\(?:text[a-zA-Z]*|operatorname)\*?\s*\{/g;
    let result = '', from = 0, match;
    while ((match = groups.exec(source))) {
      let end = groups.lastIndex, depth = 1;
      while (end < source.length && depth) {
        if (source[end] === '\\') { end += 2; continue; }
        if (source[end] === '{') depth++;
        else if (source[end] === '}') depth--;
        end++;
      }
      if (depth) break;
      result += transform(source.slice(from,match.index)) + literal(source.slice(match.index,end));
      from = end; groups.lastIndex = end;
    }
    return result + transform(source.slice(from));
  }
  function explicitSubscripts(latex) {
    return mapMath(latex, source => source.replace(/_\{\w+\}|\\[a-zA-Z]+|\\.|_[0-9]/g,
      token => /^_[0-9]$/.test(token) ? '_{' + token[1] + '}' : token));
  }
  function plainToLatex(source) {
    // Import evaluator constants with the same structures as the keyboard.
    const constants = {
      pi:'\\pi ', e:'e', ln2:'\\ln\\left(2\\right)', ln10:'\\ln\\left(10\\right)',
      log2e:'\\log_{2}\\left(e\\right)', log10e:'\\log_{10}\\left(e\\right)',
      sqrt2:'\\sqrt{2}', sqrt1_2:'\\frac{1}{\\sqrt{2}}'
    };
    const asConstant = token => {
      const name = token.toLowerCase();
      return (token === name || token === token.toUpperCase()) && Object.prototype.hasOwnProperty.call(constants,name)
        ? constants[name] : null;
    };
    // Simple braced subscripts name parameters in the graph evaluator. Keep
    // their identifiers literal while converting expression tokens/calls.
    let marker = '\uE000';
    while (source.includes(marker)) marker += '\uE000';
    const literals = [];
    const protect = value => {
      literals.push(value);
      return '{' + marker + (literals.length-1) + '\uE001}';
    };
    source = mapMath(source, text => text, protect);
    source = source.replace(/_\{\w+\}|\\mathrm\{[a-zA-Z]\w*\}/g, protect);
    source = source.replace(/\\[a-zA-Z]+|[a-zA-Z]\w*/g, token => {
      if (asConstant(token) !== null) return token;
      const script = /^([a-zA-Z][a-zA-Z0-9]*)_(\w+)$/.exec(token);
      if (!script) return token;
      const base = script[1].length === 1 ? script[1] : '\\mathrm{' + script[1] + '}';
      return base + '_{' + script[2] + '}';
    });
    source = source.replace(/_\{\w+\}|\\mathrm\{[a-zA-Z]\w*\}/g, protect);
    source = source.replace(/\\[a-zA-Z]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|[a-zA-Z]\w*/g,
      token => asConstant(token) ?? token);
    source = source.replace(/(?<!\\)\b(asin|acos|atan)\b/g, name => 'arc' + name.slice(1));
    source = source.replace(/(?<![\w.])((?:\d+(?:\.\d*)?|\.\d+))[eE]([+-]?\d+)\b/g,
      (_, number, exponent) => number + '\\cdot10^{' + exponent + '}');
    source = source.replace(/(?<!\\)%/g, '\\bmod ');
    const calls = /(?<!\\)\b(sqrt|abs|floor|ceil|round|fact|pow|nrt|sin|cos|tan|arcsin|arccos|arctan|cot|sec|csc|sinh|cosh|tanh|coth|sech|csch|ln|log|exp)\s*\(/g;
    // Named parameters with digits/underscores must remain whole identifiers.
    if (!/[\\{}]/.test(source) && !/[a-zA-Z]\w*[0-9_]\w*/.test(source) && !calls.test(source)) return MathLive.convertAsciiMathToLatex(source);
    calls.lastIndex = 0;
    // Convert balanced legacy calls even when they are mixed with TeX. The
    // ASCII converter does not preserve floor/fact/nrt and other graph calls.
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
      const rawBody = source.slice(begin,end-1);
      const args = splitArguments(rawBody).map(plainToLatex);
      const body = args.join(',');
      const name = match[1];
      const latex = name === 'pow' && args.length === 2 ? '{' + args[0] + '}^{' + args[1] + '}'
        : name === 'nrt' && args.length === 2 ? '\\sqrt[' + args[0] + ']{' + args[1] + '}'
        : name === 'log' && args.length === 2 ? '\\log_{' + args[0] + '}\\left(' + args[1] + '\\right)'
        : name === 'sqrt' ? '\\sqrt{' + body + '}'
        : name === 'abs' ? '\\left|' + body + '\\right|'
        : name === 'floor' ? '\\left\\lfloor ' + body + '\\right\\rfloor'
        : name === 'ceil' ? '\\left\\lceil ' + body + '\\right\\rceil'
        : name === 'fact' ? '\\left(' + body + '\\right)!'
        : ['round','sech','csch','pow','nrt'].includes(name) ? '\\operatorname{' + name + '}\\left(' + body + '\\right)'
        : '\\' + name + '\\left(' + body + '\\right)';
      result += source.slice(from,match.index) + latex;
      from = end; calls.lastIndex = end;
    }
    return (result + source.slice(from)).replace(/(?<!\\)\*/g,'\\cdot ')
      .replace(new RegExp('\\{' + marker + '(\\d+)\uE001\\}', 'g'), (_, i) => literals[Number(i)]);
  }
  function splitArguments(source) {
    const result = []; let depth = 0, start = 0;
    for (let i = 0; i < source.length; i++) {
      if ('({['.includes(source[i]) && source[i-1] !== '\\') depth++;
      if (')}]'.includes(source[i]) && source[i-1] !== '\\') depth--;
      if (source[i] === ',' && depth === 0) { result.push(source.slice(start,i)); start = i+1; }
    }
    result.push(source.slice(start));
    return result;
  }
  function observeChanges() {
    const current = field.getValue('latex');
    if (!importing && current !== canonical) {
      canonical = current;
      edited = true;
      sequence++;
    }
    const caret = JSON.stringify(field.selection);
    if (!importing && caret !== selection) {
      selection = caret;
      sequence++;
    }
  }
  function snapshot() {
    // MathLive's input event is deferred. Read the model synchronously so a
    // Plot/toggle immediately after an insertion still sees that insertion.
    observeChanges();
    return {revision, sequence, latex: edited ? explicitSubscripts(field.getValue('latex')) : original,
      edited, location:navigation.location(), height: field.getBoundingClientRect().height + problem.getBoundingClientRect().height,
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
    selectedLatex() { return explicitSubscripts(field.getValue(field.selection, 'latex')); },
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
      else if (kind === 'navigate') navigation.move(value);
      else if (kind === 'next' || kind === 'previous') navigation.slot(kind);
      else field.executeCommand(value);
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
  field.addEventListener('move-out', event => event.preventDefault());
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
