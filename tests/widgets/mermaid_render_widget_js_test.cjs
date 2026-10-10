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
