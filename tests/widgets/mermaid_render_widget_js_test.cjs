const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dartSource = fs.readFileSync(
  path.resolve(__dirname, '../../lib/widgets/mermaid_render_widget.dart'),
  'utf8',
);
const webTemplateSource = fs.readFileSync(
  path.resolve(__dirname, '../../assets/vendor/mermaid_render.html'),
  'utf8',
);
const fitFunction = dartSource.match(
  /window\.fitToViewport\s*=\s*function\(\)\s*\{([\s\S]*?)^    \};/m,
);
assert.ok(fitFunction, 'Could not find the native fitToViewport function');

const reportErrorTargets = [
  ['native', dartSource],
  ['web', webTemplateSource],
];

for (const [templateName, templateSource] of reportErrorTargets) {
  const reportErrorFunction = templateSource.match(
    /function reportError\(msg\)\s*\{([\s\S]*?)^    \}/m,
  );
  assert.ok(
    reportErrorFunction,
    `Could not find reportError in the ${templateName} template`,
  );

  test(`${templateName} render errors display diagnostic text literally`, () => {
    const htmlAssignments = [];
    const errorElements = [];
    const bridgeCalls = [];
    const viewport = {
      children: [],
      set innerHTML(value) { htmlAssignments.push(value); },
      set textContent(value) { this.children = []; },
      appendChild(element) { this.children.push(element); },
    };
    const context = {
      document: {
        getElementById: (id) => id === 'viewport' ? viewport : null,
        createElement: (tagName) => {
          const element = {tagName, className: '', textContent: ''};
          errorElements.push(element);
          return element;
        },
      },
      window: {
        flutter_inappwebview: {
          callHandler: (...args) => bridgeCalls.push(args),
        },
      },
    };
    const reportError = vm.runInNewContext(
      `(function reportError(msg) {${reportErrorFunction[1]}\n})`,
      context,
    );
    const diagnostic =
      'Mermaid render error: unexpected token <img src=x onerror="attack()">';

    reportError(diagnostic);

    assert.deepEqual(htmlAssignments, [], 'diagnostic text must not use innerHTML');
    assert.equal(errorElements.length, 1);
    assert.equal(errorElements[0].tagName, 'div');
    assert.equal(errorElements[0].className, 'error-message');
    assert.equal(errorElements[0].textContent, diagnostic);
    assert.deepEqual(viewport.children, [errorElements[0]]);
    assert.deepEqual(bridgeCalls, [['onMermaidError', diagnostic]]);
  });
}

test('web render shows the readable Chinese loading hint', () => {
  const loadingHint = webTemplateSource.match(
    /<div id="loading-hint">([^<]*)<\/div>/,
  );

  assert.ok(loadingHint, 'Could not find the web loading hint');
  assert.equal(loadingHint[1], '图表加载中...');
});

test('fitToViewport retries once the zero-sized viewport is laid out', () => {
  const viewport = {clientWidth: 0, clientHeight: 0};
  const attributes = {};
  const svg = {
    getBBox: () => ({width: 200, height: 100}),
    setAttribute: (name, value) => { attributes[name] = value; },
  };
  const container = {querySelector: () => svg};
  const listeners = new Map();
  const transforms = [];
  let notifications = 0;

  const window = {
    addEventListener: (type, listener) => {
      const registered = listeners.get(type) || [];
      registered.push(listener);
      listeners.set(type, registered);
    },
    removeEventListener: (type, listener) => {
      listeners.set(
        type,
        (listeners.get(type) || []).filter((registered) => registered !== listener),
      );
    },
    applyZoomDeltasAfterFit: () => {},
  };
  const document = {
    getElementById: (id) =>
      id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
  };
  const context = {
    window,
    document,
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: false,
    pendingZoomDeltas: [],
    updateTransform: () => transforms.push([context.zoomLevel, context.panX, context.panY]),
    notifyTransform: () => notifications++,
  };

  vm.runInNewContext(
    `window.fitToViewport = function() {${fitFunction[1]}\n};`,
    context,
  );
  const dispatchResize = () => {
    for (const listener of [...(listeners.get('resize') || [])]) {
      listener();
    }
  };

  window.fitToViewport();
  assert.equal((listeners.get('resize') || []).length, 1);
  assert.equal(notifications, 0);
  assert.deepEqual(transforms, []);

  viewport.clientWidth = 100;
  dispatchResize();
  assert.equal((listeners.get('resize') || []).length, 1);
  assert.equal(notifications, 0, 'both viewport dimensions must be positive');

  viewport.clientHeight = 200;
  dispatchResize();
  assert.equal((listeners.get('resize') || []).length, 0);
  assert.equal(notifications, 1);
  assert.deepEqual(transforms, [[0.5, 0, 75]]);
  assert.deepEqual(attributes, {width: 200, height: 100});

  dispatchResize();
  assert.equal(notifications, 1, 'the resize retry should only run once');
});

test('native and web templates apply queued zoom after auto-fit', () => {
  for (const [templateName, templateSource] of [
    ['native', dartSource],
    ['web', webTemplateSource],
  ]) {
    const extract = (pattern, description) => {
      const match = templateSource.match(pattern);
      assert.ok(match, `Could not find ${description} in the ${templateName} template`);
      return match[0];
    };
    const state = extract(
      /    var fitComplete = false;\s*var pendingZoomDeltas = \[\];/,
      'queued zoom state',
    );
    const setZoom = extract(
      /    window\.setZoom = function\(level, centerX, centerY\) \{[\s\S]*?^    \};/m,
      'setZoom',
    );
    const applyAfterFit = extract(
      /    window\.applyZoomDeltasAfterFit = function\(deltas\) \{[\s\S]*?^    \};/m,
      'applyZoomDeltasAfterFit',
    );
    const fit = extract(
      /    window\.fitToViewport = function\(\) \{[\s\S]*?^    \};/m,
      'fitToViewport',
    );

    const viewport = {clientWidth: 200, clientHeight: 100};
    const attributes = {};
    const svg = {
      getBBox: () => ({width: 100, height: 50}),
      setAttribute: (name, value) => { attributes[name] = value; },
    };
    const container = {querySelector: () => svg};
    const transforms = [];
    const context = {
      window: {},
      document: {
        getElementById: (id) =>
          id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
      },
      zoomLevel: 1,
      panX: 0,
      panY: 0,
      updateTransform: () => transforms.push(context.zoomLevel),
      notifyTransform: () => {},
    };

    vm.runInNewContext(
      `${state}\n${setZoom}\n${applyAfterFit}\n${fit}`,
      context,
    );

    context.window.applyZoomDeltasAfterFit([0.1]);
    assert.equal(context.zoomLevel, 1, `${templateName} must wait for auto-fit`);

    context.window.fitToViewport();
    assert.equal(context.zoomLevel, 2.1);
    context.window.applyZoomDeltasAfterFit([-0.1]);
    assert.equal(context.zoomLevel, 2.0);
    assert.deepEqual(transforms, [2, 2.1, 2]);
    assert.deepEqual(attributes, {width: 100, height: 50});
  }
});

const webLibraryLoader = webTemplateSource.match(
  /^    var TEMPLATE_VERSION = '[^']+';[\s\S]*?^    \}\)\(\);/m,
);
assert.ok(webLibraryLoader, 'Could not find the web Mermaid library loader');
const webReportError = webTemplateSource.match(
  /^    function reportError\(msg\) \{[\s\S]*?^    \}/m,
);
assert.ok(webReportError, 'Could not find the web reportError function');

function createWebLibraryLoaderHarness(fetch) {
  const timers = new Map();
  const scripts = [];
  const bridgeCalls = [];
  const errorElements = [];
  let nextTimerId = 0;
  const loadingHint = {style: {display: 'block'}};
  const codeElement = {textContent: ''};
  const viewport = {
    children: [],
    set textContent(value) {
      this.children = [];
      this._textContent = value;
    },
    appendChild(element) {
      this.children.push(element);
    },
  };
  const context = {
    window: {
      location: {search: '?code=graph%20TD'},
      flutter_inappwebview: {
        callHandler: (...args) => bridgeCalls.push(args),
      },
    },
    document: {
      getElementById: (id) => {
        if (id === 'loading-hint') return loadingHint;
        if (id === 'mermaid-code') return codeElement;
        if (id === 'viewport') return viewport;
        return null;
      },
      createElement: (tagName) => {
        const element = {tagName, className: '', textContent: ''};
        if (tagName === 'div') errorElements.push(element);
        return element;
      },
      head: {
        appendChild: (script) => scripts.push(script),
      },
    },
    fetch,
    URLSearchParams,
    setTimeout: (callback, delay) => {
      const id = ++nextTimerId;
      timers.set(id, {callback, delay});
      return id;
    },
    clearTimeout: (id) => timers.delete(id),
  };

  vm.runInNewContext(
    `${webReportError[0]}\n${webLibraryLoader[0]}`,
    context,
  );

  return {
    bridgeCalls,
    errorElements,
    loadingHint,
    scripts,
    timers,
  };
}

function fireLibraryLoadTimeout(harness) {
  const timeout = [...harness.timers.entries()].find(
    ([, timer]) => Number.isFinite(timer.delay) && timer.delay > 0,
  );
  assert.ok(timeout, 'the library load should have a finite timeout');
  const [id, {callback}] = timeout;
  harness.timers.delete(id);
  callback();
}

async function flushLoaderPromises() {
  await new Promise((resolve) => setImmediate(resolve));
}

test('stalled .gz fetch reports a bounded library-load error', () => {
  let fetchCount = 0;
  const harness = createWebLibraryLoaderHarness(() => {
    fetchCount++;
    return new Promise(() => {});
  });

  assert.equal(fetchCount, 1);
  assert.equal(harness.scripts.length, 0);
  fireLibraryLoadTimeout(harness);

  assert.equal(harness.loadingHint.style.display, 'none');
  assert.equal(harness.errorElements[0].textContent, 'Mermaid 资源加载超时');
  assert.deepEqual(harness.bridgeCalls, [
    ['onMermaidError', 'Mermaid 资源加载超时'],
  ]);
});

test('stalled raw-library fallback reports a bounded library-load error', async () => {
  const harness = createWebLibraryLoaderHarness(
    () => Promise.reject(new Error('compressed asset unavailable')),
  );
  await flushLoaderPromises();

  assert.equal(harness.scripts.length, 1);
  assert.equal(harness.scripts[0].src, 'mermaid.min.js');
  fireLibraryLoadTimeout(harness);

  assert.equal(harness.loadingHint.style.display, 'none');
  assert.equal(harness.errorElements[0].textContent, 'Mermaid 资源加载超时');
  assert.deepEqual(harness.bridgeCalls, [
    ['onMermaidError', 'Mermaid 资源加载超时'],
  ]);

  harness.scripts[0].onload();
  assert.equal(harness.timers.size, 0);
  assert.deepEqual(harness.bridgeCalls, [
    ['onMermaidError', 'Mermaid 资源加载超时'],
  ]);
});
