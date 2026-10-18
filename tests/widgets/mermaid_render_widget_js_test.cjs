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
const webWheelZoomHandler = webTemplateSource.match(
  /^    document\.addEventListener\('wheel', function\(e\) \{([\s\S]*?)^    \}, \{ passive: false \}\);/m,
);
assert.ok(webWheelZoomHandler, 'Could not find the web wheel zoom handler');
const nativeWheelZoomHandler = dartSource.match(
  /^    document\.addEventListener\('wheel', function\(e\) \{([\s\S]*?)^    \}, \{ passive: false \}\);/m,
);
assert.ok(nativeWheelZoomHandler, 'Could not find the fullscreen inline wheel zoom handler');
const fitFunction = dartSource.match(
  /window\.fitToViewport\s*=\s*function\(\)\s*\{([\s\S]*?)^    \};/m,
);
assert.ok(fitFunction, 'Could not find the native fitToViewport function');
const nativeResizeFitListener = dartSource.match(
  /^    window\.addEventListener\('resize', function\(\) \{[\s\S]*?^    \}\);/m,
);
assert.ok(nativeResizeFitListener, 'Could not find the native resize refit listener');
const webFitFunction = webTemplateSource.match(
  /^    window\.fitToViewport = function\(\) \{[\s\S]*?^    \};/m,
);
assert.ok(webFitFunction, 'Could not find the web fitToViewport function');
const webResizeFitListener = webTemplateSource.match(
  /^    window\.addEventListener\('resize', function\(\) \{[\s\S]*?^    \}\);/m,
);

const reportErrorTargets = [
  ['native', dartSource],
  ['web', webTemplateSource],
];

const generationScopedResourceErrorListener = dartSource.match(
  /skeleton\.replaceFirst\(\s*'\/\*MERMAID_GENERATION_SCOPED_RESOURCE_ERROR_LISTENER\*\/',\s*'''([\s\S]*?)''',\s*\);/,
);
assert.ok(
  generationScopedResourceErrorListener,
  'Could not find the generation-scoped resource error listener',
);

function createResourceErrorListenerHarness() {
  const listeners = new Map();
  const reportedErrors = [];
  const diagramContainer = {contains: () => true};
  const context = {
    document: {
      baseURI: 'https://app.example/mermaid/',
      getElementById: (id) => id === 'diagram-container' ? diagramContainer : null,
    },
    window: {
      location: {origin: 'https://app.example'},
      addEventListener: (type, listener, options) => {
        const registered = listeners.get(type) || [];
        registered.push({listener, options});
        listeners.set(type, registered);
      },
    },
    URL,
    reportError: (message) => reportedErrors.push(message),
  };
  vm.runInNewContext(generationScopedResourceErrorListener[1], context);

  return {
    dispatchResourceError(resourceUrl) {
      const errorListener = listeners.get('error')?.[0]?.listener;
      assert.ok(errorListener, 'The resource error listener was not registered');
      errorListener({
        target: {
          currentSrc: resourceUrl,
          getAttribute: () => null,
        },
      });
    },
    reportedErrors,
  };
}

test('generation-scoped resource error listener ignores malformed URLs', () => {
  const harness = createResourceErrorListenerHarness();

  harness.dispatchResourceError('http://[');

  assert.deepEqual(harness.reportedErrors, []);
});

test('generation-scoped resource error listener suppresses same-origin failures', () => {
  const harness = createResourceErrorListenerHarness();

  harness.dispatchResourceError('/assets/node.svg');

  assert.deepEqual(harness.reportedErrors, []);
});

test('generation-scoped resource error listener reports external failures', () => {
  const harness = createResourceErrorListenerHarness();

  harness.dispatchResourceError('https://cdn.example.com/assets/node.svg');

  assert.deepEqual(harness.reportedErrors, ['Mermaid resource failed to load']);
});

const mouseGestureTargets = [
  ['web', webTemplateSource],
  ['fullscreen inline', dartSource],
];

function extractMouseGestureScript(templateName, templateSource) {
  const start = templateSource.indexOf('    var isDragging = false;');
  assert.notEqual(start, -1, `Could not find mouse gesture state in ${templateName}`);
  const end = templateSource.indexOf(
    '    // Zoom with Ctrl/Meta + MouseWheel',
    start,
  );
  assert.notEqual(end, -1, `Could not find the end of mouse handlers in ${templateName}`);
  return templateSource.slice(start, end);
}

function createMouseGestureHarness(mouseGestureScript) {
  const listeners = new Map();
  const timers = new Map();
  const panUpdates = [];
  let nextTimerId = 0;
  let mermaidTargetClicks = 0;
  const context = {
    document: {
      addEventListener: (type, listener, options) => {
        const registered = listeners.get(type) || [];
        registered.push({listener, options});
        listeners.set(type, registered);
      },
    },
    window: {},
    panX: 0,
    panY: 0,
    zoomLevel: 1,
    updateTransform: () => panUpdates.push([context.panX, context.panY]),
    notifyTransform: () => {},
    setTimeout: (callback, delay) => {
      const id = ++nextTimerId;
      timers.set(id, {callback, delay});
      return id;
    },
    clearTimeout: (id) => timers.delete(id),
  };
  const diagramTarget = {closest: (selector) => selector === '#diagram-container'};
  vm.runInNewContext(mouseGestureScript, context);

  function dispatch(type, properties = {}) {
    let defaultPrevented = false;
    let propagationStopped = false;
    const event = {
      target: diagramTarget,
      clientX: 0,
      clientY: 0,
      detail: 1,
      preventDefault: () => { defaultPrevented = true; },
      stopPropagation: () => { propagationStopped = true; },
      stopImmediatePropagation: () => { propagationStopped = true; },
      ...properties,
    };
    const registeredListeners = listeners.get(type) || [];
    if (type === 'click') {
      const isCapture = (options) =>
        options === true || options?.capture === true;
      for (const {listener, options} of registeredListeners) {
        if (isCapture(options)) listener(event);
      }
      if (!propagationStopped) mermaidTargetClicks++;
      for (const {listener, options} of registeredListeners) {
        if (!isCapture(options)) listener(event);
      }
    } else {
      for (const {listener} of registeredListeners) {
        listener(event);
      }
    }
    return {defaultPrevented, propagationStopped};
  }

  return {
    dispatch,
    get mermaidTargetClicks() { return mermaidTargetClicks; },
    panUpdates,
    runPendingTimers() {
      for (const [id, {callback}] of [...timers]) {
        timers.delete(id);
        callback();
      }
    },
    get timerCount() { return timers.size; },
  };
}

function extractTouchGestureScript() {
  const start = webTemplateSource.indexOf('    // Touch events for mobile pan');
  assert.notEqual(start, -1, 'Could not find web touch gesture handlers');
  const end = webTemplateSource.indexOf(
    '    // Asset version: the mermaid code arrives via the ?code= query',
    start,
  );
  assert.notEqual(end, -1, 'Could not find the end of web touch gesture handlers');
  return webTemplateSource.slice(start, end);
}

function extractInlineTouchGestureScript() {
  const start = dartSource.indexOf('    // Touch events for mobile pan');
  assert.notEqual(start, -1, 'Could not find fullscreen inline touch gesture handlers');
  const end = dartSource.indexOf("\n''';", start);
  assert.notEqual(end, -1, 'Could not find the end of fullscreen inline touch gesture handlers');
  return dartSource.slice(start, end);
}

function createTouchGestureHarness(touchGestureScript) {
  const listeners = new Map();
  const zoomCalls = [];
  const viewport = {
    getBoundingClientRect: () => ({left: 10, top: 20}),
  };
  const context = {
    document: {
      addEventListener: (type, listener) => {
        const registered = listeners.get(type) || [];
        registered.push(listener);
        listeners.set(type, registered);
      },
      getElementById: (id) => id === 'viewport' ? viewport : null,
    },
    window: {
      setZoom: (...args) => zoomCalls.push(args),
    },
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: true,
    updateTransform: () => {},
    notifyTransform: () => {},
  };
  vm.runInNewContext(touchGestureScript, context);

  function dispatch(type, touches) {
    let defaultPrevented = false;
    const event = {
      touches,
      preventDefault: () => { defaultPrevented = true; },
    };
    for (const listener of listeners.get(type) || []) {
      listener(event);
    }
    return {defaultPrevented};
  }

  return {dispatch, zoomCalls};
}

function createTouchZoomHarness(
  templateName,
  templateSource,
  fit,
  touchGestureScript,
  diagramSize,
) {
  const setZoom = templateSource.match(
    /^    window\.setZoom = function\(level, centerX, centerY(?:, preserveSubFloorPinch)?\) \{[\s\S]*?^    \};/m,
  );
  const zoomState = templateSource.match(
    /^    var zoomLevel = 1;\s*var panX = 0;\s*var panY = 0;\s*var fitComplete = false;\s*var pendingZoomOperations = \[\];/m,
  );
  const timestampHelper = templateSource.match(
    /^    function zoomInputTimestamp\(\) \{[\s\S]*?^    \}/m,
  );
  const queueHelper = templateSource.match(
    /^    function queuePendingZoomOperation\(operation\) \{[\s\S]*?^    \}/m,
  );
  assert.ok(setZoom, `Could not find ${templateName} setZoom`);
  assert.ok(zoomState, `Could not find ${templateName} zoom state`);
  assert.ok(timestampHelper, `Could not find ${templateName} timestamp helper`);
  assert.ok(queueHelper, `Could not find ${templateName} queue helper`);

  const listeners = new Map();
  const viewport = {
    clientWidth: 200,
    clientHeight: 100,
    getBoundingClientRect: () => ({left: 10, top: 20}),
  };
  const svg = {
    getBBox: () => diagramSize,
    setAttribute: () => {},
  };
  const container = {querySelector: () => svg};
  const context = {
    window: {performance: {timeOrigin: 1000, now: () => 1}},
    document: {
      addEventListener: (type, listener) => {
        const registered = listeners.get(type) || [];
        registered.push(listener);
        listeners.set(type, registered);
      },
      getElementById: (id) =>
        id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
    },
    activeNativeGestureId: null,
    nativeGestureZoomLevel: 1,
    updateTransform: () => {},
    notifyTransform: () => {},
  };

  vm.runInNewContext(
    [
      zoomState[0],
      timestampHelper[0],
      queueHelper[0],
      setZoom[0],
      fit[0],
      touchGestureScript,
    ].join('\n'),
    context,
  );

  return {
    context,
    fit: () => context.window.fitToViewport(),
    dispatch(type, touches) {
      let defaultPrevented = false;
      const event = {
        touches,
        preventDefault: () => { defaultPrevented = true; },
      };
      for (const listener of listeners.get(type) || []) {
        listener(event);
      }
      return {defaultPrevented};
    },
  };
}

test('native and web pre-fit DOM touch pan replays after first auto-fit', () => {
  for (const [templateName, templateSource, fit, touchGestureScript] of [
    ['native', dartSource, fitFunction, extractInlineTouchGestureScript()],
    ['web', webTemplateSource, webFitFunction, extractTouchGestureScript()],
  ]) {
    const harness = createTouchZoomHarness(
      templateName,
      templateSource,
      fit,
      touchGestureScript,
      {width: 50, height: 50},
    );

    harness.dispatch('touchstart', [{clientX: 20, clientY: 30}]);
    const move = harness.dispatch('touchmove', [{clientX: 45, clientY: 55}]);
    assert.equal(move.defaultPrevented, true);

    harness.fit();

    assert.equal(harness.context.panX, 75, `${templateName} must retain touch pan X`);
    assert.equal(harness.context.panY, 25, `${templateName} must retain touch pan Y`);

    harness.dispatch('touchmove', [{clientX: 50, clientY: 65}]);
    assert.equal(harness.context.panX, 80, `${templateName} must continue touch pan X after fit`);
    assert.equal(harness.context.panY, 35, `${templateName} must continue touch pan Y after fit`);
  }
});

test('native and web pre-fit DOM touch pinch replays after first auto-fit', () => {
  for (const [templateName, templateSource, fit, touchGestureScript] of [
    ['native', dartSource, fitFunction, extractInlineTouchGestureScript()],
    ['web', webTemplateSource, webFitFunction, extractTouchGestureScript()],
  ]) {
    const harness = createTouchZoomHarness(
      templateName,
      templateSource,
      fit,
      touchGestureScript,
      {width: 100, height: 50},
    );

    harness.dispatch('touchstart', [
      {clientX: 30, clientY: 40},
      {clientX: 50, clientY: 40},
    ]);
    const move = harness.dispatch('touchmove', [
      {clientX: 20, clientY: 50},
      {clientX: 80, clientY: 50},
    ]);
    assert.equal(move.defaultPrevented, true);

    harness.fit();

    assert.equal(harness.context.zoomLevel, 6, `${templateName} must apply pinch scale to fit zoom`);
    assert.equal(harness.context.panX, -80, `${templateName} must preserve pinch center X`);
    assert.equal(harness.context.panY, -60, `${templateName} must preserve pinch center Y`);
  }
});

test('native and web touch pinches scale from a sub-floor fit and keep the normal zoom floor', () => {
  for (const [templateName, templateSource, fit, touchGestureScript] of [
    ['native', dartSource, fitFunction, extractInlineTouchGestureScript()],
    ['web', webTemplateSource, webFitFunction, extractTouchGestureScript()],
  ]) {
    const subFloor = createTouchZoomHarness(
      templateName,
      templateSource,
      fit,
      touchGestureScript,
      {width: 3000, height: 1000},
    );
    subFloor.fit();
    const fittedZoom = subFloor.context.zoomLevel;
    assert.ok(fittedZoom < 0.1, `${templateName} fit should produce a sub-floor zoom`);
    assert.ok(Math.abs(fittedZoom - 1 / 15) < 1e-12);
    const touchesAtDistance = (distance) => [
      {clientX: 110 - distance / 2, clientY: 70},
      {clientX: 110 + distance / 2, clientY: 70},
    ];
    subFloor.dispatch('touchstart', touchesAtDistance(100));
    const pinch = subFloor.dispatch('touchmove', touchesAtDistance(120));

    assert.equal(pinch.defaultPrevented, true);
    assert.ok(
      Math.abs(subFloor.context.zoomLevel - fittedZoom * 1.2) < 1e-12,
      `${templateName} modest pinch-in should scale from the fit instead of jumping to 0.1`,
    );
    assert.ok(subFloor.context.zoomLevel < 0.1);

    const normalFloor = createTouchZoomHarness(
      templateName,
      templateSource,
      fit,
      touchGestureScript,
      {width: 1000, height: 500},
    );
    normalFloor.fit();
    assert.equal(normalFloor.context.zoomLevel, 0.2);
    normalFloor.dispatch('touchstart', touchesAtDistance(100));
    normalFloor.dispatch('touchmove', touchesAtDistance(25));
    assert.equal(
      normalFloor.context.zoomLevel,
      0.1,
      `${templateName} pinch-out from a normal fit should stop at the 0.1 floor`,
    );
  }
});

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

test('native and web Ctrl/Meta wheel zoom ignore horizontal-only input', () => {
  for (const [templateName, wheelHandler] of [
    ['fullscreen inline', nativeWheelZoomHandler],
    ['web', webWheelZoomHandler],
  ]) {
    const zoomCalls = [];
    let preventDefaultCount = 0;
    const context = {
      document: {
        getElementById: (id) => {
          assert.equal(id, 'viewport');
          return {getBoundingClientRect: () => ({left: 10, top: 20})};
        },
      },
      window: {
        setZoom: (...args) => zoomCalls.push(['setZoom', ...args]),
        applyWheelZoomAfterFit: (...args) => zoomCalls.push(['wheel', ...args]),
      },
      zoomLevel: 1.5,
    };
    const handleWheel = vm.runInNewContext(
      `(function(e) {${wheelHandler[1]}\n})`,
      context,
    );

    for (const modifier of ['ctrlKey', 'metaKey']) {
      handleWheel({
        [modifier]: true,
        deltaY: 0,
        clientX: 80,
        clientY: 70,
        preventDefault: () => preventDefaultCount++,
      });
    }

    assert.deepEqual(zoomCalls, [], `${templateName} must ignore horizontal-only input`);
    assert.equal(preventDefaultCount, 0);

    handleWheel({
      ctrlKey: true,
      deltaY: 16,
      clientX: 80,
      clientY: 70,
      preventDefault: () => preventDefaultCount++,
    });
    assert.deepEqual(zoomCalls, [['wheel', -0.1, 70, 50]]);
    assert.equal(preventDefaultCount, 1);
  }
});

test('pre-fit Ctrl/Meta wheel zoom stays anchored through fit in both templates', () => {
  const targets = [
    ['fullscreen inline', dartSource, nativeWheelZoomHandler],
    ['web', webTemplateSource, webWheelZoomHandler],
  ];

  function createHarness(templateName, templateSource, wheelHandler, viewportSize, diagramSize) {
    const extract = (pattern, description, optional = false) => {
      const match = templateSource.match(pattern);
      if (optional && !match) return null;
      assert.ok(match, `Could not find ${description} in the ${templateName} template`);
      return match[0];
    };
    const state = extract(
      /    var fitComplete = false;/,
      'fit state',
    );
    const timestampHelper = extract(
      /^    function zoomInputTimestamp\(\) \{[\s\S]*?^    \}/m,
      'zoom input timestamp helper',
      true,
    );
    const queueHelper = extract(
      /^    function queuePendingZoomOperation\(operation\) \{[\s\S]*?^    \}/m,
      'pending zoom queue helper',
      true,
    );
    const setZoom = extract(
      /    window\.setZoom = function\(level, centerX, centerY(?:, preserveSubFloorPinch)?\) \{[\s\S]*?^    \};/m,
      'setZoom',
    );
    const applyWheelZoom = extract(
      /    window\.applyWheelZoomAfterFit = function\(delta, centerX, centerY(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
      'applyWheelZoomAfterFit',
      true,
    );
    const applyZoomOperations = extract(
      /    window\.applyZoomOperationsAfterFit = function\(operations\) \{[\s\S]*?^    \};/m,
      'applyZoomOperationsAfterFit',
    );
    const applyZoomDeltas = extract(
      /    window\.applyZoomDeltasAfterFit = function\(deltas(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
      'applyZoomDeltasAfterFit',
    );
    const fit = extract(
      /    window\.fitToViewport = function\(\) \{[\s\S]*?^    \};/m,
      'fitToViewport',
    );
    const viewport = {
      clientWidth: viewportSize.width,
      clientHeight: viewportSize.height,
      getBoundingClientRect: () => ({left: 10, top: 20}),
    };
    const svg = {
      getBBox: () => ({width: diagramSize.width, height: diagramSize.height}),
      setAttribute: () => {},
    };
    const container = {querySelector: () => svg};
    const context = {
      window: {},
      document: {
        getElementById: (id) =>
          id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
      },
      zoomLevel: 1,
      panX: 0,
      panY: 0,
      fitComplete: false,
      pendingZoomDeltas: [],
      pendingWheelZooms: [],
      pendingZoomOperations: [],
      updateTransform: () => {},
      notifyTransform: () => {},
    };

    vm.runInNewContext(
      [state, timestampHelper, queueHelper, setZoom, applyWheelZoom,
        applyZoomOperations, applyZoomDeltas, fit]
        .filter(Boolean)
        .join('\n'),
      context,
    );
    const handleWheel = vm.runInNewContext(
      `(function(e) {${wheelHandler[1]}\n})`,
      context,
    );
    return {context, handleWheel};
  }

  function dispatch(handleWheel, modifier, deltaY, clientX, clientY) {
    let prevented = false;
    handleWheel({
      [modifier]: true,
      deltaY,
      clientX,
      clientY,
      preventDefault: () => { prevented = true; },
    });
    return prevented;
  }

  function anchor(pan, center, oldZoom, newZoom) {
    return center - (center - pan) * (newZoom / oldZoom);
  }

  const failures = [];
  for (const [templateName, templateSource, wheelHandler] of targets) {
    try {
      const {context, handleWheel} = createHarness(
        templateName,
        templateSource,
        wheelHandler,
        {width: 200, height: 100},
        {width: 100, height: 50},
      );
      dispatch(handleWheel, 'ctrlKey', -10, 60, 50);
      context.window.applyZoomOperationsAfterFit([
        {kind: 'toolbar', delta: -0.1},
      ]);
      dispatch(handleWheel, 'metaKey', -10, 160, 70);
      assert.equal(context.zoomLevel, 1, `${templateName} should queue zoom before fit`);

      context.window.fitToViewport();
      assert.equal(context.zoomLevel, 2.1, `${templateName} should apply queued zooms in input order`);
      let expectedPanX = anchor(0, 50, 2, 2.1);
      let expectedPanY = anchor(0, 30, 2, 2.1);
      expectedPanX = anchor(expectedPanX, 100, 2.1, 2);
      expectedPanY = anchor(expectedPanY, 50, 2.1, 2);
      expectedPanX = anchor(expectedPanX, 150, 2, 2.1);
      expectedPanY = anchor(expectedPanY, 50, 2, 2.1);
      assert.ok(Math.abs(context.panX - expectedPanX) < 1e-9);
      assert.ok(Math.abs(context.panY - expectedPanY) < 1e-9);

      // Post-fit wheel input remains immediate, and a later fit cannot replay
      // events already consumed by the first successful fit.
      dispatch(handleWheel, 'ctrlKey', -10, 70, 60);
      assert.ok(Math.abs(context.zoomLevel - 2.2) < 1e-9);
      context.window.fitToViewport();
      assert.equal(context.zoomLevel, 2);

      const clamped = createHarness(
        templateName,
        templateSource,
        wheelHandler,
        {width: 199, height: 100},
        {width: 20, height: 10},
      );
      dispatch(clamped.handleWheel, 'ctrlKey', -10, 60, 50);
      dispatch(clamped.handleWheel, 'metaKey', -10, 160, 70);
      dispatch(clamped.handleWheel, 'ctrlKey', 10, 110, 95);
      assert.equal(clamped.context.zoomLevel, 1);
      clamped.context.window.fitToViewport();
      assert.equal(clamped.context.zoomLevel, 9.9, `${templateName} should clamp each queued step`);
      let clampPanX = anchor(0, 50, 9.95, 10);
      let clampPanY = anchor(0.25, 30, 9.95, 10);
      clampPanX = anchor(clampPanX, 100, 10, 9.9);
      clampPanY = anchor(clampPanY, 75, 10, 9.9);
      assert.ok(Math.abs(clamped.context.panX - clampPanX) < 1e-9);
      assert.ok(Math.abs(clamped.context.panY - clampPanY) < 1e-9);
    } catch (error) {
      failures.push(`${templateName}: ${error.message}`);
    }
  }
  assert.deepEqual(failures, []);
});

test('web toolbar zoom queued before iframe wheel keeps input order through fit', () => {
  const extract = (pattern, description, optional = false) => {
    const match = webTemplateSource.match(pattern);
    if (optional && !match) return null;
    assert.ok(match, `Could not find ${description} in the web template`);
    return match[0];
  };
  const state = extract(
    /^    var zoomLevel = 1;\s*var panX = 0;\s*var panY = 0;\s*var fitComplete = false;\s*var pendingZoomOperations = \[\];/m,
    'zoom state',
  );
  const timestampHelper = extract(
    /^    function zoomInputTimestamp\(\) \{[\s\S]*?^    \}/m,
    'zoom input timestamp helper',
    true,
  );
  const queueHelper = extract(
    /^    function queuePendingZoomOperation\(operation\) \{[\s\S]*?^    \}/m,
    'pending zoom queue helper',
    true,
  );
  const setZoom = extract(
    /^    window\.setZoom = function\(level, centerX, centerY(?:, preserveSubFloorPinch)?\) \{[\s\S]*?^    \};/m,
    'setZoom',
  );
  const applyWheelZoom = extract(
    /^    window\.applyWheelZoomAfterFit = function\(delta, centerX, centerY(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
    'applyWheelZoomAfterFit',
  );
  const applyZoomDeltas = extract(
    /^    window\.applyZoomDeltasAfterFit = function\(deltas(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
    'applyZoomDeltasAfterFit',
  );
  const applyZoomOperations = extract(
    /^    window\.applyZoomOperationsAfterFit = function\(operations\) \{[\s\S]*?^    \};/m,
    'applyZoomOperationsAfterFit',
  );
  const fit = extract(
    /^    window\.fitToViewport = function\(\) \{[\s\S]*?^    \};/m,
    'fitToViewport',
  );
  const viewport = {
    clientWidth: 200,
    clientHeight: 100,
    getBoundingClientRect: () => ({left: 10, top: 20}),
  };
  const svg = {getBBox: () => ({width: 100, height: 50}), setAttribute: () => {}};
  const container = {querySelector: () => svg};
  const context = {
    window: {performance: {timeOrigin: 1000, now: () => 20}},
    document: {
      getElementById: (id) =>
        id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
    },
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: false,
    pendingZoomOperations: [],
    updateTransform: () => {},
    notifyTransform: () => {},
  };

  vm.runInNewContext(
    [state, timestampHelper, queueHelper, setZoom, applyWheelZoom,
      applyZoomDeltas, applyZoomOperations, fit].filter(Boolean).join('\n'),
    context,
  );
  const handleWheel = vm.runInNewContext(
    `(function(e) {${webWheelZoomHandler[1]}\n})`,
    context,
  );

  // The first toolbar click is still queued in Dart when the iframe receives
  // the later wheel event. onLoadStop then transfers that earlier click.
  handleWheel({
    ctrlKey: true,
    deltaY: -10,
    clientX: 160,
    clientY: 100,
    preventDefault: () => {},
  });
  context.window.applyZoomOperationsAfterFit([
    {kind: 'toolbar', delta: 0.1, inputTimestamp: 1010},
  ]);
  assert.equal(context.zoomLevel, 1, 'both inputs must wait for the first fit');

  context.window.fitToViewport();

  assert.equal(context.zoomLevel, 2.2);
  const anchor = (pan, center, oldZoom, newZoom) =>
    center - (center - pan) * (newZoom / oldZoom);
  const expectedPanX = anchor(anchor(0, 100, 2, 2.1), 150, 2.1, 2.2);
  const expectedPanY = anchor(anchor(0, 50, 2, 2.1), 80, 2.1, 2.2);
  assert.ok(Math.abs(context.panX - expectedPanX) < 1e-9);
  assert.ok(Math.abs(context.panY - expectedPanY) < 1e-9);
});

test('native and web auto-fit contain diagrams that need less than 0.1 zoom', () => {
  for (const [templateName, fit] of [
    ['native', fitFunction],
    ['web', webFitFunction],
  ]) {
    const viewport = {clientWidth: 200, clientHeight: 100};
    const diagramSize = {width: 3000, height: 1000};
    const svg = {
      getBBox: () => diagramSize,
      setAttribute: () => {},
    };
    const container = {querySelector: () => svg};
    const context = {
      window: {},
      document: {
        getElementById: (id) =>
          id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
      },
      zoomLevel: 1,
      panX: 0,
      panY: 0,
      fitComplete: false,
      pendingZoomOperations: [],
      activeNativeGestureId: null,
      nativeGestureZoomLevel: 1,
      updateTransform: () => {},
      notifyTransform: () => {},
    };

    vm.runInNewContext(fit[0], context);
    context.window.fitToViewport();

    assert.ok(context.zoomLevel < 0.1, `${templateName} fit should use a zoom below 0.1`);
    assert.ok(
      diagramSize.width * context.zoomLevel <= viewport.clientWidth,
      `${templateName} fit should keep the diagram within the viewport width`,
    );
    assert.ok(
      diagramSize.height * context.zoomLevel <= viewport.clientHeight,
      `${templateName} fit should keep the diagram within the viewport height`,
    );
    assert.ok(Math.abs(context.zoomLevel - 1 / 15) < 1e-12);
  }
});

test('manual zoom-out keeps sub-0.1 fitted diagrams at their fitted scale', () => {
  for (const [templateName, templateSource, fit, nativeGesture] of [
    ['native', dartSource, fitFunction, true],
    ['web', webTemplateSource, webFitFunction, false],
  ]) {
    const setZoom = templateSource.match(
      /^    window\.setZoom = function\(level, centerX, centerY(?:, preserveSubFloorPinch)?\) \{[\s\S]*?^    \};/m,
    );
    const setPanZoom = templateSource.match(
      /^    window\.setPanZoom = function\(x, y, level\) \{[\s\S]*?^    \};/m,
    );
    const applyZoomDeltas = templateSource.match(
      /^    window\.applyZoomDeltasAfterFit = function\(deltas(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
    );
    const applyWheelZoom = templateSource.match(
      /^    window\.applyWheelZoomAfterFit = function\(delta, centerX, centerY(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
    );
    assert.ok(setZoom, `Could not find ${templateName} setZoom`);
    assert.ok(setPanZoom, `Could not find ${templateName} setPanZoom`);
    assert.ok(applyZoomDeltas, `Could not find ${templateName} applyZoomDeltasAfterFit`);
    assert.ok(applyWheelZoom, `Could not find ${templateName} applyWheelZoomAfterFit`);

    const viewport = {clientWidth: 200, clientHeight: 100};
    const svg = {
      getBBox: () => ({width: 3000, height: 1000}),
      setAttribute: () => {},
    };
    const container = {querySelector: () => svg};
    const context = {
      window: {},
      document: {
        getElementById: (id) =>
          id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
      },
      zoomLevel: 1,
      panX: 0,
      panY: 0,
      fitComplete: false,
      pendingZoomOperations: [],
      activeNativeGestureId: null,
      nativeGestureZoomLevel: 1,
      updateTransform: () => {},
      notifyTransform: () => {},
    };
    const functions = [
      setZoom[0],
      setPanZoom[0],
      applyZoomDeltas[0],
      applyWheelZoom[0],
      fit[0],
    ];
    if (nativeGesture) {
      const applyGestureTransform = templateSource.match(
        /^    window\.applyGestureTransformAfterFit = function\(gestureId, scale, panDeltaX, panDeltaY, centerX, centerY\) \{[\s\S]*?^    \};/m,
      );
      assert.ok(applyGestureTransform, 'Could not find native applyGestureTransformAfterFit');
      functions.splice(2, 0, applyGestureTransform[0]);
    }
    vm.runInNewContext(functions.join('\n'), context);
    context.window.fitToViewport();

    const fittedZoom = context.zoomLevel;
    const fittedPanX = context.panX;
    const fittedPanY = context.panY;
    assert.ok(fittedZoom < 0.1, `${templateName} must start below the manual zoom floor`);
    context.window.setZoom(fittedZoom, 100, 50);
    assert.equal(
      context.zoomLevel,
      fittedZoom,
      `${templateName} unchanged zoom must preserve a sub-0.1 fit`,
    );
    if (nativeGesture) {
      context.window.applyGestureTransformAfterFit(1, 1, 5, -3, null, null);
      assert.equal(
        context.zoomLevel,
        fittedZoom,
        'native pan-only input must preserve a sub-0.1 fit',
      );
      assert.equal(context.panX, fittedPanX + 5);
      assert.equal(context.panY, fittedPanY - 3);
    }
    context.window.setPanZoom(17, 23, fittedZoom);
    assert.equal(
      context.zoomLevel,
      fittedZoom,
      `${templateName} pan-only setPanZoom must preserve a sub-0.1 fit`,
    );
    assert.equal(context.panX, 17);
    assert.equal(context.panY, 23);
    context.window.applyZoomDeltasAfterFit([-0.1]);
    assert.equal(
      context.zoomLevel,
      fittedZoom,
      `${templateName} toolbar zoom-out must not increase a sub-0.1 fit`,
    );
    context.window.applyWheelZoomAfterFit(-0.1, 100, 50);
    assert.equal(
      context.zoomLevel,
      fittedZoom,
      `${templateName} wheel zoom-out must not increase a sub-0.1 fit`,
    );
    if (nativeGesture) {
      context.window.applyGestureTransformAfterFit(1, 0.9, 0, 0, 100, 50);
      assert.equal(
        context.zoomLevel,
        fittedZoom,
        'native pinch-out must not increase a sub-0.1 fit',
      );
    }
    context.window.setZoom(0.08, 100, 50);
    assert.equal(context.zoomLevel, 0.1, `${templateName} zoom-in should retain its 0.1 floor`);
    context.window.setZoom(0.05, 100, 50);
    assert.equal(context.zoomLevel, 0.1, `${templateName} zoom-out should stop at its 0.1 floor`);
  }
});

test('native pinch-in preserves a sub-floor fit and ordinary zoom bounds', () => {
  const applyGestureTransform = dartSource.match(
    /^    window\.applyGestureTransformAfterFit = function\(gestureId, scale, panDeltaX, panDeltaY, centerX, centerY\) \{[\s\S]*?^    \};/m,
  );
  assert.ok(applyGestureTransform, 'Could not find native applyGestureTransformAfterFit');

  const context = {
    window: {},
    fitComplete: true,
    activeNativeGestureId: null,
    nativeGestureZoomLevel: 1,
    zoomLevel: 1 / 15,
    panX: 0,
    panY: 0,
    pendingZoomOperations: [],
    updateTransform: () => {},
    notifyTransform: () => {},
  };
  vm.runInNewContext(applyGestureTransform[0], context);

  context.window.applyGestureTransformAfterFit(1, 1.05, 0, 0, null, null);
  assert.ok(
    Math.abs(context.zoomLevel - (1 / 15) * 1.05) < 1e-12,
    'a small native zoom-in should use its relative scale below 0.1',
  );
  assert.ok(context.zoomLevel < 0.1);

  context.zoomLevel = 0.2;
  context.window.applyGestureTransformAfterFit(2, 0.25, 0, 0, null, null);
  assert.equal(context.zoomLevel, 0.1, 'a normal fit should retain the 0.1 lower bound');

  context.zoomLevel = 1;
  context.window.applyGestureTransformAfterFit(3, 11, 0, 0, null, null);
  assert.equal(context.zoomLevel, 10, 'native pinch-in should retain the 10.0 upper bound');
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
    pendingWheelZooms: [],
    pendingZoomOperations: [],
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

test('native fitToViewport refits after a successful viewport resize', () => {
  const viewport = {clientWidth: 200, clientHeight: 100};
  const attributes = {};
  const svg = {
    getBBox: () => ({width: 100, height: 50}),
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
  const context = {
    window,
    document: {
      getElementById: (id) =>
        id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
    },
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: false,
    pendingZoomOperations: [],
    activeNativeGestureId: null,
    nativeGestureZoomLevel: 1,
    updateTransform: () => transforms.push([context.zoomLevel, context.panX, context.panY]),
    notifyTransform: () => notifications++,
  };

  vm.runInNewContext(
    [fitFunction[0], nativeResizeFitListener[0]].join('\n'),
    context,
  );
  const dispatchResize = () => {
    for (const listener of [...(listeners.get('resize') || [])]) {
      listener();
    }
  };

  window.fitToViewport();
  assert.deepEqual(transforms, [[2, 0, 0]]);
  assert.equal(notifications, 1);
  assert.deepEqual(attributes, {width: 100, height: 50});

  viewport.clientWidth = 100;
  viewport.clientHeight = 200;
  dispatchResize();
  assert.deepEqual(transforms, [[2, 0, 0], [1, 0, 75]]);
  assert.equal(notifications, 2);

  viewport.clientHeight = 100;
  dispatchResize();
  assert.deepEqual(transforms, [[2, 0, 0], [1, 0, 75], [1, 0, 25]]);
  assert.equal(notifications, 3);
  assert.equal((listeners.get('resize') || []).length, 1);
});

test('web fitToViewport refits after the viewport resizes', () => {
  const viewport = {clientWidth: 200, clientHeight: 100};
  const svg = {
    getBBox: () => ({width: 100, height: 50}),
    setAttribute: () => {},
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
  const context = {
    window,
    document: {
      getElementById: (id) =>
        id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
    },
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: false,
    pendingZoomOperations: [],
    updateTransform: () => transforms.push([context.zoomLevel, context.panX, context.panY]),
    notifyTransform: () => notifications++,
  };

  vm.runInNewContext(
    [webFitFunction[0], webResizeFitListener?.[0]].filter(Boolean).join('\n'),
    context,
  );
  const dispatchResize = () => {
    for (const listener of [...(listeners.get('resize') || [])]) {
      listener();
    }
  };

  window.fitToViewport();
  assert.deepEqual(transforms, [[2, 0, 0]]);

  viewport.clientWidth = 100;
  viewport.clientHeight = 200;
  dispatchResize();
  assert.deepEqual(transforms, [[2, 0, 0], [1, 0, 75]]);

  viewport.clientHeight = 100;
  dispatchResize();
  assert.deepEqual(transforms, [[2, 0, 0], [1, 0, 75], [1, 0, 25]]);
  assert.equal(notifications, 3);
  assert.equal((listeners.get('resize') || []).length, 1);
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
      /    var fitComplete = false;\s*var pendingZoomOperations = \[\];/,
      'queued zoom state',
    );
    const setZoom = extract(
      /    window\.setZoom = function\(level, centerX, centerY(?:, preserveSubFloorPinch)?\) \{[\s\S]*?^    \};/m,
      'setZoom',
    );
    const applyAfterFit = extract(
      /    window\.applyZoomDeltasAfterFit = function\(deltas(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
      'applyZoomDeltasAfterFit',
    );
    const timestampHelper = extract(
      /^    function zoomInputTimestamp\(\) \{[\s\S]*?^    \}/m,
      'zoom input timestamp helper',
    );
    const queueHelper = extract(
      /^    function queuePendingZoomOperation\(operation\) \{[\s\S]*?^    \}/m,
      'pending zoom queue helper',
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
      `${state}\n${timestampHelper}\n${queueHelper}\n${setZoom}\n${applyAfterFit}\n${fit}`,
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

test('native pre-fit pan and pinch transforms apply after the first fit', () => {
  const extract = (pattern, description) => {
    const match = dartSource.match(pattern);
    assert.ok(match, `Could not find ${description} in the native template`);
    return match[0];
  };
  const state = extract(
    /    var fitComplete = false;\s*var pendingZoomOperations = \[\];\s*var activeNativeGestureId = null;\s*var nativeGestureZoomLevel = 1/,
    'queued transform state',
  );
  const setZoom = extract(
    /    window\.setZoom = function\(level, centerX, centerY(?:, preserveSubFloorPinch)?\) \{[\s\S]*?^    \};/m,
    'setZoom',
  );
  const applyGestureTransform = extract(
    /    window\.applyGestureTransformAfterFit = function\(gestureId, scale, panDeltaX, panDeltaY, centerX, centerY\) \{[\s\S]*?^    \};/m,
    'applyGestureTransformAfterFit',
  );
  const applyZoomDeltas = extract(
    /    window\.applyZoomDeltasAfterFit = function\(deltas(?:, inputTimestamp)?\) \{[\s\S]*?^    \};/m,
    'applyZoomDeltasAfterFit',
  );
  const fit = extract(
    /    window\.fitToViewport = function\(\) \{[\s\S]*?^    \};/m,
    'fitToViewport',
  );

  const viewport = {clientWidth: 200, clientHeight: 100};
  const svg = {
    getBBox: () => ({width: 100, height: 50}),
    setAttribute: () => {},
  };
  const container = {querySelector: () => svg};
  const context = {
    window: {},
    document: {
      getElementById: (id) =>
        id === 'viewport' ? viewport : id === 'diagram-container' ? container : null,
    },
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: false,
    pendingZoomOperations: [],
    activeNativeGestureId: null,
    nativeGestureZoomLevel: 1,
    updateTransform: () => {},
    notifyTransform: () => {},
  };
  const timestampHelper = extract(
    /^    function zoomInputTimestamp\(\) \{[\s\S]*?^    \}/m,
    'zoom input timestamp helper',
  );
  const queueHelper = extract(
    /^    function queuePendingZoomOperation\(operation\) \{[\s\S]*?^    \}/m,
    'pending zoom queue helper',
  );
  vm.runInNewContext(
    `${state}\n${timestampHelper}\n${queueHelper}\n${setZoom}\n${applyGestureTransform}\n${applyZoomDeltas}\n${fit}`,
    context,
  );

  context.window.applyGestureTransformAfterFit(1, 1, 20, -10, null, null);
  context.window.applyZoomDeltasAfterFit([0.1]);
  context.window.applyGestureTransformAfterFit(1, 1.5, 0, 0, 100, 50);
  assert.equal(context.zoomLevel, 1, 'pre-fit inputs must wait for the first fit');
  assert.equal(context.pendingZoomOperations.length, 3);

  context.window.fitToViewport();
  assert.ok(Math.abs(context.zoomLevel - 3.15) < 1e-9);
  assert.equal(context.panX, -26);
  assert.equal(context.panY, -44.5);
  assert.equal(context.pendingZoomOperations.length, 0);

  context.window.applyGestureTransformAfterFit(1, 1, 7, 4, null, null);
  assert.ok(
    Math.abs(context.zoomLevel - 3.15) < 1e-9,
    'post-fit pan should keep the current zoom',
  );
  assert.equal(context.panX, -19);
  assert.equal(context.panY, -40.5);

  const clampedViewport = {clientWidth: 200, clientHeight: 100};
  const clampedSvg = {
    getBBox: () => ({width: 20, height: 10}),
    setAttribute: () => {},
  };
  const clampedContainer = {querySelector: () => clampedSvg};
  const clampedContext = {
    window: {},
    document: {
      getElementById: (id) =>
        id === 'viewport' ? clampedViewport : id === 'diagram-container' ? clampedContainer : null,
    },
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    fitComplete: false,
    pendingZoomOperations: [],
    activeNativeGestureId: null,
    nativeGestureZoomLevel: 1,
    updateTransform: () => {},
    notifyTransform: () => {},
  };
  vm.runInNewContext(
    `${state}\n${timestampHelper}\n${queueHelper}\n${setZoom}\n${applyGestureTransform}\n${applyZoomDeltas}\n${fit}`,
    clampedContext,
  );

  clampedContext.window.applyGestureTransformAfterFit(2, 2, 0, 0, 100, 50);
  clampedContext.window.fitToViewport();
  assert.equal(clampedContext.zoomLevel, 10);
  assert.equal(clampedContext.panX, 0, 'a clamped stationary pinch keeps its anchor');
  assert.equal(clampedContext.panY, 0, 'a clamped stationary pinch keeps its anchor');

  const contextForSvg = (targetSvg) => {
    const targetContainer = {querySelector: () => targetSvg};
    const targetContext = {
      window: {},
      document: {
        getElementById: (id) =>
          id === 'viewport' ? clampedViewport : id === 'diagram-container' ? targetContainer : null,
      },
      zoomLevel: 1,
      panX: 0,
      panY: 0,
      fitComplete: false,
      pendingZoomOperations: [],
      activeNativeGestureId: null,
      nativeGestureZoomLevel: 1,
      updateTransform: () => {},
      notifyTransform: () => {},
    };
    vm.runInNewContext(
      `${state}\n${timestampHelper}\n${queueHelper}\n${setZoom}\n${applyGestureTransform}\n${applyZoomDeltas}\n${fit}`,
      targetContext,
    );
    return targetContext;
  };

  const fittedContext = contextForSvg({
    getBBox: () => ({width: 400, height: 200}),
    setAttribute: () => {},
  });
  fittedContext.window.applyGestureTransformAfterFit(3, 5, 0, 0, 100, 50);
  fittedContext.window.applyGestureTransformAfterFit(3, 2.2, 0, 0, 100, 50);
  fittedContext.window.fitToViewport();
  assert.equal(fittedContext.zoomLevel, 5.5);

  const boundedContext = contextForSvg({
    getBBox: () => ({width: 200, height: 100}),
    setAttribute: () => {},
  });
  boundedContext.window.applyGestureTransformAfterFit(4, 5, 0, 0, 100, 50);
  boundedContext.window.applyGestureTransformAfterFit(4, 2.6, 0, 0, 100, 50);
  boundedContext.window.applyGestureTransformAfterFit(4, 11 / 13, 0, 0, 100, 50);
  boundedContext.window.fitToViewport();
  assert.ok(
    Math.abs(boundedContext.zoomLevel - (10 * 11 / 13)) < 1e-9,
    'a reverse pinch step should apply from the clamped zoom',
  );
});

test('native pinch reverses immediately after hitting zoom cap', () => {
  const applyGestureTransform = dartSource.match(
    /    window\.applyGestureTransformAfterFit = function\(gestureId, scale, panDeltaX, panDeltaY, centerX, centerY\) \{[\s\S]*?^    \};/m,
  );
  assert.ok(applyGestureTransform, 'Could not find applyGestureTransformAfterFit');

  const context = {
    window: {},
    fitComplete: true,
    activeNativeGestureId: null,
    nativeGestureZoomLevel: 1,
    zoomLevel: 1,
    panX: 0,
    panY: 0,
    pendingZoomOperations: [],
    updateTransform: () => {},
    notifyTransform: () => {},
  };
  vm.runInNewContext(applyGestureTransform[0], context);

  context.window.applyGestureTransformAfterFit(1, 11, 0, 0, null, null);
  assert.equal(context.zoomLevel, 10, 'the first pinch update should clamp at zoom 10');

  context.window.applyGestureTransformAfterFit(1, 0.95, 0, 0, null, null);
  assert.equal(
    context.zoomLevel,
    9.5,
    'reversing the pinch should reduce zoom from the clamped level immediately',
  );
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

for (const [templateName, templateSource] of mouseGestureTargets) {
  const mouseGestureScript = extractMouseGestureScript(
    templateName,
    templateSource,
  );

  test(`${templateName} mouse pan suppresses exactly its follow-up click`, () => {
    const harness = createMouseGestureHarness(mouseGestureScript);

    harness.dispatch('mousedown', {clientX: 10, clientY: 20});
    harness.dispatch('mouseup');
    assert.deepEqual(harness.dispatch('click'), {
      defaultPrevented: false,
      propagationStopped: false,
    }, 'an ordinary mouse click must reach Mermaid');
    assert.equal(harness.mermaidTargetClicks, 1);

    harness.dispatch('mousedown', {clientX: 10, clientY: 20});
    harness.dispatch('mousemove', {clientX: 25, clientY: 40});
    assert.deepEqual(harness.panUpdates, [[15, 20]], 'mouse movement must pan');
    harness.dispatch('mouseup');

    assert.deepEqual(harness.dispatch('click', {detail: 0}), {
      defaultPrevented: false,
      propagationStopped: false,
    }, 'keyboard activation must remain unaffected');
    assert.equal(harness.mermaidTargetClicks, 2);

    assert.deepEqual(harness.dispatch('click'), {
      defaultPrevented: true,
      propagationStopped: true,
    }, 'the browser click after a pan must be stopped during capture');
    assert.equal(harness.mermaidTargetClicks, 2);
    assert.equal(harness.timerCount, 0, 'the consumed click should clear expiry');

    assert.deepEqual(harness.dispatch('click'), {
      defaultPrevented: false,
      propagationStopped: false,
    }, 'suppression must be consumed exactly once');
    assert.equal(harness.mermaidTargetClicks, 3);
  });

  test(`${templateName} expires pan suppression if its click never arrives`, () => {
    const harness = createMouseGestureHarness(mouseGestureScript);

    harness.dispatch('mousedown', {clientX: 10, clientY: 20});
    harness.dispatch('mousemove', {clientX: 25, clientY: 40});
    harness.dispatch('mouseup');
    assert.equal(harness.timerCount, 1, 'pan suppression should be temporary');

    harness.runPendingTimers();
    assert.equal(harness.timerCount, 0);
    assert.deepEqual(harness.dispatch('click'), {
      defaultPrevented: false,
      propagationStopped: false,
    }, 'a later unrelated click must not inherit a missing post-pan click');
    assert.equal(harness.mermaidTargetClicks, 1);
  });
}

test('web mouse click after slight pointer jitter reaches Mermaid', () => {
  const harness = createMouseGestureHarness(
    extractMouseGestureScript('web', webTemplateSource),
  );

  harness.dispatch('mousedown', {clientX: 10, clientY: 20});
  harness.dispatch('mousemove', {clientX: 11, clientY: 20});
  harness.dispatch('mouseup');

  assert.deepEqual(harness.dispatch('click'), {
    defaultPrevented: false,
    propagationStopped: false,
  }, 'a click after slight pointer jitter must reach Mermaid');
  assert.equal(harness.mermaidTargetClicks, 1);
});

test('fullscreen inline mouse click after slight pointer jitter reaches Mermaid', () => {
  const harness = createMouseGestureHarness(
    extractMouseGestureScript('fullscreen inline', dartSource),
  );

  harness.dispatch('mousedown', {clientX: 10, clientY: 20});
  harness.dispatch('mousemove', {clientX: 11, clientY: 20});
  harness.dispatch('mouseup');

  assert.deepEqual(harness.dispatch('click'), {
    defaultPrevented: false,
    propagationStopped: false,
  }, 'a click after slight pointer jitter must reach Mermaid');
  assert.equal(harness.mermaidTargetClicks, 1);
});

test('web pinch restarts from the remaining fingers after a three-to-two touch transition', () => {
  const harness = createTouchGestureHarness(extractTouchGestureScript());
  const twoTouches = [
    {clientX: 10, clientY: 10},
    {clientX: 30, clientY: 10},
  ];

  harness.dispatch('touchstart', twoTouches);
  harness.dispatch('touchstart', [
    ...twoTouches,
    {clientX: 50, clientY: 10},
  ]);
  harness.dispatch('touchend', twoTouches);
  const move = harness.dispatch('touchmove', [
    {clientX: 10, clientY: 10},
    {clientX: 32, clientY: 10},
  ]);

  assert.equal(move.defaultPrevented, true);
  assert.deepEqual(harness.zoomCalls, [[1.1, 11, -10, true]]);
});

test('fullscreen inline pinch restarts from the remaining fingers after a three-to-two touch transition', () => {
  const harness = createTouchGestureHarness(extractInlineTouchGestureScript());
  const twoTouches = [
    {clientX: 10, clientY: 10},
    {clientX: 30, clientY: 10},
  ];

  harness.dispatch('touchstart', twoTouches);
  harness.dispatch('touchstart', [
    ...twoTouches,
    {clientX: 50, clientY: 10},
  ]);
  harness.dispatch('touchend', twoTouches);
  const move = harness.dispatch('touchmove', [
    {clientX: 10, clientY: 10},
    {clientX: 32, clientY: 10},
  ]);

  assert.equal(move.defaultPrevented, true);
  assert.deepEqual(harness.zoomCalls, [[1.1, 11, -10, true]]);
});
