const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dartSource = fs.readFileSync(
  path.resolve(__dirname, '../../lib/widgets/mermaid_render_widget.dart'),
  'utf8',
);
const fitFunction = dartSource.match(
  /window\.fitToViewport\s*=\s*function\(\)\s*\{([\s\S]*?)^    \};/m,
);
assert.ok(fitFunction, 'Could not find the native fitToViewport function');

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
