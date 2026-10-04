const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dartSource = fs.readFileSync(
  path.resolve(__dirname, '../../lib/catcatch/engine/js_hook_script.dart'),
  'utf8',
);
const scriptMatch = dartSource.match(
  /static const String script = '''([\s\S]*?)''';/,
);
assert.ok(
  scriptMatch,
  'The CatCatch hook script must remain a Dart triple-quoted string',
);

// The hook only uses Dart's escaped backslashes and dollar signs in this
// string. Decode those escapes so the test evaluates the injected JavaScript.
const hookScript = scriptMatch[1]
  .replace(/\\\\/g, '\\')
  .replace(/\\\$/g, '$');

class FakeSource {
  constructor(src, parentElement = null, {dataSrc = '', dataUrl = ''} = {}) {
    this.nodeName = 'SOURCE';
    this.src = src;
    this.type = '';
    this.parentElement = parentElement;
    this.attributes = {'data-src': dataSrc, 'data-url': dataUrl};
    this._catCatchScanned = false;
  }

  getAttribute(name) {
    return this.attributes[name] || null;
  }

  setAttribute(name, value) {
    this.attributes[name] = value;
  }

  querySelectorAll() {
    return [];
  }
}

class FakeMedia {
  constructor(
    tagName,
    {src = '', dataSrc = '', dataUrl = '', sources = []} = {},
  ) {
    this.nodeName = tagName;
    this.tagName = tagName;
    this.currentSrc = '';
    this.src = src;
    this.parentElement = null;
    this.attributes = {'data-src': dataSrc, 'data-url': dataUrl};
    this.sources = [];
    this._catCatchScanned = false;
    sources.forEach((source) => this.appendSource(source));
  }

  getAttribute(name) {
    return this.attributes[name] || null;
  }

  setAttribute(name, value) {
    this.attributes[name] = value;
  }

  querySelectorAll(selector) {
    return selector === 'source' ? this.sources : [];
  }

  appendSource(source) {
    source.parentElement = this;
    this.sources.push(source);
  }
}

class FakeXMLHttpRequest {
  constructor() {
    this.readyState = 0;
    this.responseURL = '';
    this.listeners = {};
  }

  open() {}

  send() {}

  addEventListener(type, listener) {
    this.listeners[type] ??= [];
    this.listeners[type].push(listener);
  }

  complete(responseURL) {
    this.responseURL = responseURL;
    this.readyState = 4;
    const event = {type: 'readystatechange'};
    for (const listener of this.listeners.readystatechange || []) {
      listener.call(this, event);
    }
    this.onreadystatechange?.call(this, event);
  }
}

function installHook(mediaElements, fetch = () => Promise.resolve()) {
  const messages = [];
  const observers = [];
  const window = {
    fetch,
    location: {href: 'https://page.example/watch'},
    flutter_inappwebview: {
      callHandler: (_, message) => messages.push(JSON.parse(message)),
    },
  };
  const document = {
    readyState: 'complete',
    body: {},
    documentElement: {},
    querySelectorAll: (selector) =>
      selector === 'video, audio' ? mediaElements : [],
    addEventListener() {},
  };
  class FakeMutationObserver {
    constructor(callback) {
      this.callback = callback;
      observers.push(this);
    }

    observe() {}
  }
  vm.runInNewContext(hookScript, {
    window,
    document,
    XMLHttpRequest: FakeXMLHttpRequest,
    MutationObserver: FakeMutationObserver,
    Headers,
    URL,
    console: {log() {}},
    setTimeout,
  });

  return {
    messages,
    observer: observers[0],
    XMLHttpRequest: FakeXMLHttpRequest,
    window,
  };
}

test('reports a source URL changed after its media element was scanned', () => {
  const source = new FakeSource('https://cdn.example/initial.mp4');
  const video = new FakeMedia('VIDEO', {
    src: 'https://cdn.example/direct.mp4',
    sources: [source],
  });
  const {messages, observer} = installHook([video]);

  source.src = 'https://cdn.example/changed.mp4';
  observer.callback([{
    type: 'attributes',
    attributeName: 'src',
    target: source,
  }]);
  observer.callback([{
    type: 'attributes',
    attributeName: 'src',
    target: source,
  }]);

  assert.deepEqual(
    messages.map(({url}) => url),
    [
      'https://cdn.example/direct.mp4',
      'https://cdn.example/initial.mp4',
      'https://cdn.example/changed.mp4',
    ],
  );
});

test('reports a source added after its media element was scanned and keeps URL deduplication', () => {
  const initialSource = new FakeSource('https://cdn.example/initial.mp4');
  const video = new FakeMedia('VIDEO', {sources: [initialSource]});
  const {messages, observer} = installHook([video]);

  const addedSource = new FakeSource('https://cdn.example/added.mp4');
  video.appendSource(addedSource);
  observer.callback([{
    type: 'childList',
    addedNodes: [addedSource],
  }]);

  const duplicateSource = new FakeSource('https://cdn.example/initial.mp4');
  video.appendSource(duplicateSource);
  observer.callback([{
    type: 'childList',
    addedNodes: [duplicateSource],
  }]);

  assert.deepEqual(
    messages.map(({url}) => url),
    [
      'https://cdn.example/initial.mp4',
      'https://cdn.example/added.mp4',
    ],
  );
});

test('reports lazy media and source URLs initially and after watched attribute changes', () => {
  const source = new FakeSource('', null, {
    dataSrc: 'https://cdn.example/source-lazy.mp4',
    dataUrl: 'https://cdn.example/source-lazy.m3u8',
  });
  const video = new FakeMedia('VIDEO', {
    src: 'https://cdn.example/direct.mp4',
    dataSrc: 'https://cdn.example/video-lazy.mp4',
    dataUrl: 'https://cdn.example/video-lazy.mpd',
    sources: [source],
  });
  const audio = new FakeMedia('AUDIO', {
    dataSrc: 'https://cdn.example/audio-lazy.m4a',
    dataUrl: 'https://cdn.example/audio-lazy.mp3',
  });
  const {messages, observer} = installHook([video, audio]);

  video.setAttribute('data-url', 'https://cdn.example/video-updated.webm');
  observer.callback([{
    type: 'attributes',
    attributeName: 'data-url',
    target: video,
  }]);
  observer.callback([{
    type: 'attributes',
    attributeName: 'data-url',
    target: video,
  }]);

  source.setAttribute('data-src', 'https://cdn.example/source-updated.m4a');
  observer.callback([{
    type: 'attributes',
    attributeName: 'data-src',
    target: source,
  }]);

  video.setAttribute('data-src', 'https://cdn.example/poster.jpg');
  observer.callback([{
    type: 'attributes',
    attributeName: 'data-src',
    target: video,
  }]);

  assert.deepEqual(
    messages.map(({url}) => url),
    [
      'https://cdn.example/direct.mp4',
      'https://cdn.example/video-lazy.mp4',
      'https://cdn.example/video-lazy.mpd',
      'https://cdn.example/source-lazy.mp4',
      'https://cdn.example/source-lazy.m3u8',
      'https://cdn.example/audio-lazy.m4a',
      'https://cdn.example/audio-lazy.mp3',
      'https://cdn.example/video-updated.webm',
      'https://cdn.example/source-updated.m4a',
    ],
  );
});

test('does not offer opaque Blob URLs while keeping HTTP media candidates', () => {
  const video = new FakeMedia('VIDEO', {
    src: 'blob:https://page.example/video.mp4',
    sources: [
      new FakeSource('https://cdn.example/video.m3u8'),
      new FakeSource('http://cdn.example/audio.mp3'),
    ],
  });
  const {messages} = installHook([video]);

  assert.deepEqual(
    messages.map(({url}) => url),
    [
      'https://cdn.example/video.m3u8',
      'http://cdn.example/audio.mp3',
    ],
  );
});

test('replays nested one-shot header pairs for fetch and media capture', async () => {
  const response = {url: 'https://cdn.example/nested-pair.m3u8'};
  let originalRequestHeader;
  let headerValueStringifications = 0;
  const statefulHeaderValue = {
    toString() {
      headerValueStringifications++;
      return `from-nested-generator-${headerValueStringifications}`;
    },
  };
  const {messages, window} = installHook([], (...args) =>
    Promise.resolve().then(() => {
      const requestOptions = args[1] || {};
      originalRequestHeader = new Headers(requestOptions.headers)
        .get('x-request');
      return response;
    }),
  );
  function* makeHeaderPair() {
    yield 'X-Request';
    yield statefulHeaderValue;
  }

  const result = await window.fetch('https://api.example/redirect', {
    headers: [makeHeaderPair()],
  });

  assert.equal(result, response);
  assert.equal(originalRequestHeader, 'from-nested-generator-1');
  assert.equal(headerValueStringifications, 1);
  assert.deepEqual(messages, [{
    url: 'https://cdn.example/nested-pair.m3u8',
    method: 'GET',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-nested-generator-1'},
  }]);
});

test(
  'replays the converted values of record headers without recoercing them',
  async () => {
    const response = {url: 'https://cdn.example/record-header.m3u8'};
    let originalRequestHeader;
    let headerValueStringifications = 0;
    const statefulHeaderValue = {
      toString() {
        headerValueStringifications++;
        return `from-record-${headerValueStringifications}`;
      },
    };
    const {messages, window} = installHook([], (...args) => {
      originalRequestHeader = new Headers(args[1].headers).get('x-request');
      return Promise.resolve(response);
    });

    const result = await window.fetch('https://api.example/redirect', {
      headers: {'X-Request': statefulHeaderValue},
    });

    assert.equal(result, response);
    assert.equal(headerValueStringifications, 1);
    assert.equal(originalRequestHeader, 'from-record-1');
    assert.deepEqual(messages, [{
      url: 'https://cdn.example/record-header.m3u8',
      method: 'GET',
      initiator: 'https://page.example/watch',
      mimeType: '',
      requestHeaders: {'x-request': 'from-record-1'},
    }]);
  },
);

test('replays nested one-shot pairs with non-iterable iterator wrappers', async () => {
  const response = {url: 'https://cdn.example/non-iterable-pair.m3u8'};
  let originalRequestHeader;
  const {messages, window} = installHook([], (...args) =>
    Promise.resolve().then(() => {
      originalRequestHeader = new Headers(args[1].headers).get('x-request');
      return response;
    }),
  );
  const values = ['X-Request', 'from-custom-iterator'];
  let valueIndex = 0;
  const oneShotPair = {
    [Symbol.iterator]() {
      return {
        next() {
          if (valueIndex >= values.length) return {done: true};
          return {done: false, value: values[valueIndex++]};
        },
      };
    },
  };

  const result = await window.fetch('https://api.example/redirect', {
    headers: [oneShotPair],
  });

  assert.equal(result, response);
  assert.equal(originalRequestHeader, 'from-custom-iterator');
  assert.deepEqual(messages, [{
    url: 'https://cdn.example/non-iterable-pair.m3u8',
    method: 'GET',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-custom-iterator'},
  }]);
});

test('reads each nested iterator method once during header replay', async () => {
  const response = {url: 'https://cdn.example/getter-pair.m3u8'};
  let iteratorMethodReads = 0;
  let nextMethodReads = 0;
  let pairIndex = 0;
  const pairIterator = {};
  Object.defineProperty(pairIterator, 'next', {
    get() {
      nextMethodReads++;
      if (nextMethodReads > 1) {
        throw new Error('nested next getter read more than once');
      }
      return function() {
        if (pairIndex === 0) {
          pairIndex++;
          return {done: false, value: 'X-Request'};
        }
        if (pairIndex === 1) {
          pairIndex++;
          return {done: false, value: 'from-getter-pair'};
        }
        return {done: true};
      };
    },
  });
  const getterPair = {};
  Object.defineProperty(getterPair, Symbol.iterator, {
    get() {
      iteratorMethodReads++;
      if (iteratorMethodReads > 1) {
        throw new Error('nested iterator getter read more than once');
      }
      return function() {
        return pairIterator;
      };
    },
  });
  let originalRequestHeader;
  const {window} = installHook([], (...args) => {
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', {
    headers: [getterPair],
  });

  assert.equal(result, response);
  assert.equal(iteratorMethodReads, 1);
  assert.equal(nextMethodReads, 1);
  assert.equal(originalRequestHeader, 'from-getter-pair');
});

test('rejects a non-callable first nested iterator method result', async () => {
  let iteratorMethodReads = 0;
  let originalFetchCalls = 0;
  const alternatingPair = {};
  Object.defineProperty(alternatingPair, Symbol.iterator, {
    get() {
      iteratorMethodReads++;
      if (iteratorMethodReads === 1) return 1;
      return function*() {
        yield 'X-Request';
        yield 'from-second-iterator-read';
      };
    },
  });
  const {window} = installHook([], () => {
    originalFetchCalls++;
    return Promise.resolve();
  });

  const fetchPromise = window.fetch('https://api.example/redirect', {
    headers: [alternatingPair],
  });

  await assert.rejects(fetchPromise, (error) => error.name === 'TypeError');
  assert.equal(iteratorMethodReads, 1);
  assert.equal(originalFetchCalls, 0);
});

test('converts each header pair before advancing the outer iterator', async () => {
  const response = {url: 'https://cdn.example/ordered-pairs.m3u8'};
  let firstValueCoercions = 0;
  let outerIndex = 0;
  const orderedHeaders = {
    [Symbol.iterator]() {
      return {
        next() {
          if (outerIndex === 0) {
            outerIndex++;
            return {
              done: false,
              value: ['X-First', {
                toString() {
                  firstValueCoercions++;
                  return 'first';
                },
              }],
            };
          }
          if (outerIndex === 1) {
            outerIndex++;
            return {
              done: false,
              value: [
                'X-Second',
                firstValueCoercions === 0 ? 'before-coercion' : 'after-coercion',
              ],
            };
          }
          return {done: true};
        },
      };
    },
  };
  let originalRequestHeaders;
  const {messages, window} = installHook([], (...args) => {
    originalRequestHeaders = new Headers(args[1].headers);
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', {
    headers: orderedHeaders,
  });

  assert.equal(result, response);
  assert.equal(firstValueCoercions, 1);
  assert.equal(originalRequestHeaders.get('x-second'), 'after-coercion');
  assert.equal(messages[0].requestHeaders['x-second'], 'after-coercion');
});

test('coerces each nested pair value before advancing its iterator', async () => {
  const response = {url: 'https://cdn.example/ordered-pair-values.m3u8'};
  let nameValueCoercions = 0;
  let pairIndex = 0;
  let nameWasCoerced = false;
  const orderedPair = {
    [Symbol.iterator]() {
      return {
        next() {
          if (pairIndex === 0) {
            pairIndex++;
            return {
              done: false,
              value: {
                toString() {
                  nameValueCoercions++;
                  nameWasCoerced = true;
                  return 'X-Request';
                },
              },
            };
          }
          if (pairIndex === 1) {
            pairIndex++;
            return {
              done: false,
              value: nameWasCoerced
                ? 'after-coercion'
                : 'before-coercion',
            };
          }
          return {done: true};
        },
      };
    },
  };
  let originalRequestHeaders;
  const {messages, window} = installHook([], (...args) => {
    originalRequestHeaders = new Headers(args[1].headers);
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', {
    headers: [orderedPair],
  });

  assert.equal(result, response);
  assert.equal(nameValueCoercions, 1);
  assert.equal(originalRequestHeaders.get('x-request'), 'after-coercion');
  assert.equal(messages[0].requestHeaders['x-request'], 'after-coercion');
});

test('rejects primitive results from nested header iterators', async () => {
  const unexpectedSecondNext = new Error('iterator advanced after bad result');
  let pairNextCalls = 0;
  let originalFetchCalls = 0;
  const malformedPair = {
    [Symbol.iterator]() {
      return {
        next() {
          pairNextCalls++;
          if (pairNextCalls === 1) return 1;
          throw unexpectedSecondNext;
        },
      };
    },
  };
  const {window} = installHook([], () => {
    originalFetchCalls++;
    return Promise.resolve();
  });

  const fetchPromise = window.fetch('https://api.example/redirect', {
    headers: [malformedPair],
  });

  await assert.rejects(fetchPromise, (error) => error.name === 'TypeError');
  assert.equal(pairNextCalls, 1);
  assert.equal(originalFetchCalls, 0);
});

test('preserves truthy primitive RequestInit during header replay', async () => {
  const response = {url: 'https://cdn.example/primitive-init.m3u8'};
  const request = new Request('https://api.example/redirect', {
    headers: {'X-Request': 'from-request'},
  });
  let originalFetchCalls = 0;
  let originalFetchArgs;
  const {window} = installHook([], (...args) => {
    originalFetchCalls++;
    originalFetchArgs = args;
    return Promise.resolve(response);
  });

  const result = await window.fetch(request, 'primitive-init');

  assert.equal(result, response);
  assert.equal(originalFetchCalls, 1);
  assert.equal(originalFetchArgs[0], request);
  assert.equal(typeof originalFetchArgs[1], 'object');
  assert.equal(
    new Headers(originalFetchArgs[1].headers).get('x-request'),
    'from-request',
  );
});

test('preserves the RequestInit accessor receiver during header replay', async () => {
  const response = {url: 'https://cdn.example/accessor-init.m3u8'};
  const requestOptions = {headers: [['X-Request', 'from-init']]};
  const methodGetterReceivers = [];
  Object.defineProperty(requestOptions, 'method', {
    enumerable: true,
    get() {
      methodGetterReceivers.push(this);
      return this === requestOptions ? 'PATCH' : 'GET';
    },
  });
  Object.freeze(requestOptions);
  let originalMethod;
  let originalRequestHeader;
  const {messages, window} = installHook([], (...args) => {
    originalMethod = args[1].method;
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', requestOptions);

  assert.equal(result, response);
  assert.equal(originalMethod, 'PATCH');
  assert.equal(originalRequestHeader, 'from-init');
  assert.deepEqual(methodGetterReceivers, [requestOptions]);
  assert.equal(messages[0].method, 'PATCH');
});

test('reuses the initial RequestInit headers accessor value during replay', async () => {
  const response = {url: 'https://cdn.example/header-accessor.m3u8'};
  const firstHeaders = [['X-Request', 'from-first-read']];
  const secondHeaders = [['X-Request', 'from-second-read']];
  const requestOptions = {};
  const headerGetterReceivers = [];
  let headerGetterReads = 0;
  Object.defineProperty(requestOptions, 'headers', {
    enumerable: true,
    get() {
      headerGetterReads++;
      headerGetterReceivers.push(this);
      return headerGetterReads === 1 ? firstHeaders : secondHeaders;
    },
  });
  let originalRequestHeader;
  const {messages, window} = installHook([], (...args) => {
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', requestOptions);

  assert.equal(result, response);
  assert.equal(headerGetterReads, 1);
  assert.deepEqual(headerGetterReceivers, [requestOptions]);
  assert.equal(originalRequestHeader, 'from-first-read');
  assert.equal(messages[0].requestHeaders['x-request'], 'from-first-read');
});

test('uses the cached RequestInit header iterator lookup for record headers', async () => {
  const response = {url: 'https://cdn.example/cached-record-headers.m3u8'};
  let iteratorGetterReads = 0;
  let iteratorCalls = 0;
  const headers = {'X-Request': 'from-record'};
  Object.defineProperty(headers, Symbol.iterator, {
    get() {
      iteratorGetterReads++;
      if (iteratorGetterReads === 1) return undefined;
      return function*() {
        iteratorCalls++;
        yield ['X-Request', 'from-iterator'];
      };
    },
  });
  let originalRequestHeader;
  const {messages, window} = installHook([], (...args) => {
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', {headers});

  assert.equal(result, response);
  assert.equal(iteratorGetterReads, 1);
  assert.equal(iteratorCalls, 0);
  assert.equal(originalRequestHeader, 'from-record');
  assert.equal(messages[0].requestHeaders['x-request'], 'from-record');
});

test('captures a RequestInit headers accessor value after an undefined first read', async () => {
  const response = {url: 'https://cdn.example/header-accessor-undefined.m3u8'};
  const requestOptions = {};
  const getterOrder = [];
  const methodGetterReceivers = [];
  const headerGetterReceivers = [];
  let methodGetterReads = 0;
  let headerGetterReads = 0;
  function* oneShotHeaderPair() {
    yield 'X-Request';
    yield 'from-second-read';
  }
  const secondHeaders = [oneShotHeaderPair()];
  Object.defineProperty(requestOptions, 'method', {
    enumerable: true,
    get() {
      methodGetterReads++;
      getterOrder.push(`method-${methodGetterReads}`);
      methodGetterReceivers.push(this);
      return 'PATCH';
    },
  });
  Object.defineProperty(requestOptions, 'headers', {
    enumerable: true,
    get() {
      headerGetterReads++;
      getterOrder.push(`headers-${headerGetterReads}`);
      headerGetterReceivers.push(this);
      return headerGetterReads === 1 ? undefined : secondHeaders;
    },
  });
  let originalRequestHeader;
  const {messages, window} = installHook([], (...args) => {
    args[1].method;
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch(
    'https://api.example/redirect',
    requestOptions,
  );

  assert.equal(result, response);
  assert.equal(originalRequestHeader, null);
  assert.equal(messages[0].requestHeaders['x-request'], undefined);
  assert.deepEqual(getterOrder, ['method-1', 'headers-1']);
  assert.deepEqual(methodGetterReceivers, [requestOptions]);
  assert.deepEqual(headerGetterReceivers, [requestOptions]);
});

test('reads RequestInit.method before its replayed headers accessor', async () => {
  const response = {url: 'https://cdn.example/header-read-order.m3u8'};
  const firstHeaders = [['X-Request', 'from-first-read']];
  const earlyHeaders = [['X-Request', 'before-method-read']];
  const secondHeaders = [['X-Request', 'after-method-read']];
  const requestOptions = {};
  const getterOrder = [];
  const methodGetterReceivers = [];
  const headerGetterReceivers = [];
  let methodGetterReads = 0;
  let headerGetterReads = 0;
  Object.defineProperty(requestOptions, 'method', {
    enumerable: true,
    get() {
      methodGetterReads++;
      getterOrder.push(`method-${methodGetterReads}`);
      methodGetterReceivers.push(this);
      return 'PATCH';
    },
  });
  Object.defineProperty(requestOptions, 'headers', {
    enumerable: true,
    get() {
      headerGetterReads++;
      getterOrder.push(`headers-${headerGetterReads}`);
      headerGetterReceivers.push(this);
      if (headerGetterReads === 1) return firstHeaders;
      return methodGetterReads >= 2 ? secondHeaders : earlyHeaders;
    },
  });
  let originalMethod;
  let originalRequestHeader;
  const {messages, window} = installHook([], (...args) => {
    originalMethod = args[1].method;
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch(
    'https://api.example/redirect',
    requestOptions,
  );

  assert.equal(result, response);
  assert.equal(originalMethod, 'PATCH');
  assert.equal(originalRequestHeader, 'from-first-read');
  assert.equal(messages[0].requestHeaders['x-request'], 'from-first-read');
  assert.deepEqual(getterOrder, ['method-1', 'headers-1']);
  assert.deepEqual(methodGetterReceivers, [requestOptions]);
  assert.deepEqual(headerGetterReceivers, [requestOptions]);
});

test('replays invalid entries after snapshotting shared-cursor headers', async () => {
  let entryIndex = 0;
  const sharedCursorHeaders = {
    [Symbol.iterator]() {
      return {
        next() {
          if (entryIndex === 0) {
            entryIndex++;
            return {done: false, value: 7};
          }
          return {done: true};
        },
      };
    },
  };
  let originalFetchCalls = 0;
  let originalFetchArgs;
  const {window} = installHook([], (...args) => {
    originalFetchCalls++;
    originalFetchArgs = args;
    return Promise.resolve().then(() => new Headers(args[1].headers));
  });

  const fetchPromise = window.fetch('https://api.example/redirect', {
    headers: sharedCursorHeaders,
  });

  await assert.rejects(fetchPromise, TypeError);
  assert.equal(originalFetchCalls, 1);
  assert.equal(Array.isArray(originalFetchArgs[1].headers), true);
  assert.equal(originalFetchArgs[1].headers.length, 1);
  assert.equal(originalFetchArgs[1].headers[0], 7);
});

test('rejects a failing initial headers accessor value without rereading it', async () => {
  const response = {url: 'https://cdn.example/header-accessor-throw.m3u8'};
  const firstHeaders = {};
  const iteratorError = new Error('initial headers iterator getter was read');
  Object.defineProperty(firstHeaders, Symbol.iterator, {
    get() {
      throw iteratorError;
    },
  });
  const secondHeaders = [['X-Request', 'from-second-read']];
  const requestOptions = {};
  let headerGetterReads = 0;
  Object.defineProperty(requestOptions, 'headers', {
    get() {
      headerGetterReads++;
      return headerGetterReads === 1 ? firstHeaders : secondHeaders;
    },
  });
  let originalRequestHeader;
  let originalFetchCalls = 0;
  const {messages, window} = installHook([], (...args) => {
    originalFetchCalls++;
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const fetchPromise = window.fetch('https://api.example/redirect', requestOptions);

  await assert.rejects(fetchPromise, (error) => error === iteratorError);
  assert.equal(headerGetterReads, 1);
  assert.equal(originalFetchCalls, 0);
  assert.equal(originalRequestHeader, undefined);
  assert.deepEqual(messages, []);
});

test('continues fetch when RequestInit proxy introspection traps throw', async () => {
  const response = {url: 'https://cdn.example/proxy-init.m3u8'};
  const trapCases = [
    {
      getOwnPropertyDescriptor() {
        throw new Error('descriptor introspection should not block fetch');
      },
    },
    {
      getOwnPropertyDescriptor() {
        return undefined;
      },
      getPrototypeOf() {
        throw new Error('prototype introspection should not block fetch');
      },
    },
  ];

  for (const traps of trapCases) {
    let originalRequestHeader;
    const {messages, window} = installHook([], (...args) => {
      originalRequestHeader = new Headers(args[1].headers).get('x-request');
      return Promise.resolve(response);
    });
    const requestOptions = new Proxy({}, {
      get(target, property, receiver) {
        if (property === 'method') return 'PATCH';
        if (property === 'headers') return [['X-Request', 'from-proxy']];
        return Reflect.get(target, property, receiver);
      },
      ...traps,
    });

    const result = await window.fetch('https://api.example/redirect', requestOptions);

    assert.equal(result, response);
    assert.equal(originalRequestHeader, 'from-proxy');
    assert.equal(messages[0].requestHeaders['x-request'], 'from-proxy');
  }
});

test('uses the initial RequestInit.method value for fetch and capture', async () => {
  const response = {url: 'https://cdn.example/replayed-method.m3u8'};
  const requestOptions = {headers: [['X-Request', 'from-init']]};
  let methodReads = 0;
  Object.defineProperty(requestOptions, 'method', {
    get() {
      methodReads++;
      return methodReads === 1 ? 'POST' : 'PATCH';
    },
  });
  let originalMethod;
  const {messages, window} = installHook([], (...args) => {
    originalMethod = args[1].method;
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', requestOptions);

  assert.equal(result, response);
  assert.equal(methodReads, 1);
  assert.equal(originalMethod, 'POST');
  assert.equal(messages[0].method, 'POST');
});

test('replays the converted values of malformed nested header pairs', async () => {
  let valueCoercions = 0;
  const singleValuePair = [{
    toString() {
      valueCoercions++;
      if (valueCoercions > 1) {
        throw new Error('malformed pair value was converted again');
      }
      return 'X-Invalid';
    },
  }];
  let originalFetchCalls = 0;
  const {window} = installHook([], (...args) => {
    originalFetchCalls++;
    return Promise.resolve().then(() => new Headers(args[1].headers));
  });

  const fetchPromise = window.fetch('https://api.example/redirect', {
    headers: [singleValuePair],
  });

  await assert.rejects(fetchPromise, TypeError);
  assert.equal(originalFetchCalls, 1);
  assert.equal(valueCoercions, 1);
});

test('closes a nested header iterator when value conversion throws', async () => {
  const conversionError = new Error('header name conversion failed');
  let pairIteratorClosed = false;
  let originalFetchCalls = 0;
  function* throwingHeaderPair() {
    try {
      yield {
        toString() {
          throw conversionError;
        },
      };
      yield 'unreachable';
    } finally {
      pairIteratorClosed = true;
    }
  }
  const {window} = installHook([], () => {
    originalFetchCalls++;
    return Promise.resolve();
  });

  const fetchPromise = window.fetch('https://api.example/redirect', {
    headers: [throwingHeaderPair()],
  });

  await assert.rejects(fetchPromise, (error) => error === conversionError);
  assert.equal(pairIteratorClosed, true);
  assert.equal(originalFetchCalls, 0);
});

test('reuses headers supplied by a descriptorless RequestInit proxy', async () => {
  const response = {url: 'https://cdn.example/proxy-dynamic-headers.m3u8'};
  const secondHeaders = [['X-Request', 'from-second-proxy-read']];
  let headerReads = 0;
  let originalRequestHeader;
  const requestOptions = new Proxy({}, {
    get(target, property, receiver) {
      if (property === 'headers') {
        headerReads++;
        return headerReads === 1 ? {} : secondHeaders;
      }
      if (property === 'method') return 'PATCH';
      return Reflect.get(target, property, receiver);
    },
    getOwnPropertyDescriptor() {
      return undefined;
    },
  });
  const {messages, window} = installHook([], (...args) => {
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', requestOptions);

  assert.equal(result, response);
  assert.equal(headerReads, 1);
  assert.equal(originalRequestHeader, null);
  assert.equal(messages[0].requestHeaders['x-request'], undefined);
});

test('reuses the initial headers from a RequestInit proxy data descriptor', async () => {
  const response = {url: 'https://cdn.example/proxy-data-headers.m3u8'};
  const secondHeaders = [['X-Request', 'from-second-proxy-read']];
  let headerReads = 0;
  let originalRequestHeader;
  const requestOptions = new Proxy({headers: {}}, {
    get(target, property, receiver) {
      if (property === 'headers') {
        headerReads++;
        return headerReads === 1 ? {} : secondHeaders;
      }
      if (property === 'method') return 'PATCH';
      return Reflect.get(target, property, receiver);
    },
    getOwnPropertyDescriptor(target, property) {
      return Reflect.getOwnPropertyDescriptor(target, property);
    },
  });
  const {messages, window} = installHook([], (...args) => {
    originalRequestHeader = new Headers(args[1].headers).get('x-request');
    return Promise.resolve(response);
  });

  const result = await window.fetch('https://api.example/redirect', requestOptions);

  assert.equal(result, response);
  assert.equal(headerReads, 1);
  assert.equal(originalRequestHeader, null);
  assert.equal(messages[0].requestHeaders['x-request'], undefined);
});

test('keeps redirect capture when the page assigns onreadystatechange after send', () => {
  const {messages, XMLHttpRequest} = installHook([]);
  const xhr = new XMLHttpRequest();
  let pageHandlerCalls = 0;

  xhr.open('GET', 'https://api.example/redirect');
  xhr.send();
  xhr.onreadystatechange = function(event) {
    pageHandlerCalls++;
    assert.equal(this, xhr);
    assert.equal(event.type, 'readystatechange');
  };
  xhr.complete('https://cdn.example/video.m3u8');

  assert.equal(pageHandlerCalls, 1);
  assert.deepEqual(
    messages.map(({url}) => url),
    ['https://cdn.example/video.m3u8'],
  );
});

test('captures only HTTP(S) media fetches and preserves native fetch outcomes', async () => {
  const unsupportedFetchError = new TypeError(
    'fetch rejected unsupported URL scheme',
  );
  const urls = [
    'ftp://cdn.example/video.mp4',
    'http://cdn.example/video.mp4',
    'https://cdn.example/video.mp4',
  ];
  const responses = new Map(
    urls.slice(1).map((url) => [url, {url}]),
  );
  const fetchCalls = [];
  const {messages, window} = installHook([], (url) => {
    fetchCalls.push(url);
    if (url.startsWith('ftp:')) return Promise.reject(unsupportedFetchError);
    return Promise.resolve(responses.get(url));
  });

  await assert.rejects(
    window.fetch(urls[0]),
    (error) => error === unsupportedFetchError,
  );
  const httpResponse = await window.fetch(urls[1]);
  const httpsResponse = await window.fetch(urls[2]);

  assert.deepEqual(fetchCalls, urls);
  assert.equal(httpResponse, responses.get(urls[1]));
  assert.equal(httpsResponse, responses.get(urls[2]));
  assert.deepEqual(
    messages.map(({url}) => url),
    urls.slice(1),
  );
});

test('captures HTTP(S) media URLs passed to fetch as URL objects', async () => {
  const crossRealmUrl = new URL('https://cdn.example/cross-realm.mp4');
  const foreignUrlPrototype = vm.runInNewContext('Object.create(null)');
  Object.defineProperty(
    foreignUrlPrototype,
    'href',
    Object.getOwnPropertyDescriptor(URL.prototype, 'href'),
  );
  Object.defineProperty(foreignUrlPrototype, 'toString', {
    value: URL.prototype.toString,
  });
  Object.setPrototypeOf(crossRealmUrl, foreignUrlPrototype);
  assert.equal(crossRealmUrl instanceof URL, false);
  const urls = [
    new URL('http://cdn.example/video.mp4'),
    new URL('https://cdn.example/video.m3u8'),
    crossRealmUrl,
  ];
  const responses = [{ok: true}, {ok: true}, {ok: true}];
  const fetchCalls = [];
  let responseIndex = 0;
  const {messages, window} = installHook([], (url) => {
    fetchCalls.push(url);
    return Promise.resolve(responses[responseIndex++]);
  });

  const results = await Promise.all(urls.map((url) => window.fetch(url)));

  assert.equal(fetchCalls[0], urls[0]);
  assert.equal(fetchCalls[1], urls[1]);
  assert.equal(fetchCalls[2], urls[2]);
  assert.equal(results[0], responses[0]);
  assert.equal(results[1], responses[1]);
  assert.equal(results[2], responses[2]);
  assert.deepEqual(
    messages.map(({url}) => url),
    urls.map((url) => url.href),
  );
});

test('reports fetch redirect media URLs with request metadata and usable responses', async () => {
  const response = {
    url: 'https://cdn.example/video.m3u8',
    text: () => Promise.resolve('#EXTM3U'),
  };
  const overriddenResponse = {
    url: 'https://cdn.example/overridden.m3u8',
    text: () => Promise.resolve('#EXTM3U override'),
  };
  const numericMethodResponse = {
    url: 'https://cdn.example/numeric-method.m3u8',
    text: () => Promise.resolve('#EXTM3U numeric method'),
  };
  const generatorHeadersResponse = {
    url: 'https://cdn.example/generator-headers.m3u8',
    text: () => Promise.resolve('#EXTM3U generator headers'),
  };
  const protoHeaderResponse = {
    url: 'https://cdn.example/proto-header.m3u8',
    text: () => Promise.resolve('#EXTM3U proto header'),
  };
  const sharedIteratorResponse = {
    url: 'https://cdn.example/shared-iterator.m3u8',
    text: () => Promise.resolve('#EXTM3U shared iterator'),
  };
  const request = new Request('https://api.example/redirect', {
    method: 'POST',
    headers: {'X-Request': 'from-request'},
  });
  const responses = [
    response,
    overriddenResponse,
    numericMethodResponse,
    generatorHeadersResponse,
    protoHeaderResponse,
    sharedIteratorResponse,
  ];
  const originalRequestHeaders = [];
  const {messages, window} = installHook(
    [],
    (...args) => {
      const requestOptions = args[1] || {};
      const requestHeaders = requestOptions.headers === undefined
        ? args[0].headers
        : requestOptions.headers;
      const parsedHeaders = new Headers(requestHeaders);
      originalRequestHeaders.push(
        parsedHeaders.get('x-request') || parsedHeaders.get('__proto__'),
      );
      return Promise.resolve(responses.shift());
    },
  );

  const result = await window.fetch(request);
  const overriddenResult = await window.fetch(request, {
    method: 'PUT',
    headers: [['X-Request', 'from-init']],
  });
  const numericMethodResult = await window.fetch(request, {
    method: 0,
    headers: [['X-Request', 'from-zero']],
  });
  function* makeGeneratorHeaders() {
    yield ['X-Request', 'from-generator'];
  }
  const sharedHeaderIterator = [
    ['X-Request', 'from-shared-iterator'],
  ][Symbol.iterator]();
  const sharedIteratorHeaders = {
    [Symbol.iterator]() {
      return sharedHeaderIterator;
    },
  };
  const generatorHeadersResult = await window.fetch(request, {
    method: 'PATCH',
    headers: makeGeneratorHeaders(),
  });
  const protoHeaderResult = await window.fetch(request, {
    method: 'DELETE',
    headers: [['__proto__', 'from-proto']],
  });
  const sharedIteratorResult = await window.fetch(request, {
    method: 'OPTIONS',
    headers: sharedIteratorHeaders,
  });

  assert.equal(result, response);
  assert.equal(await result.text(), '#EXTM3U');
  assert.equal(overriddenResult, overriddenResponse);
  assert.equal(await overriddenResult.text(), '#EXTM3U override');
  assert.equal(numericMethodResult, numericMethodResponse);
  assert.equal(generatorHeadersResult, generatorHeadersResponse);
  assert.equal(protoHeaderResult, protoHeaderResponse);
  assert.equal(sharedIteratorResult, sharedIteratorResponse);
  assert.deepEqual(originalRequestHeaders, [
    'from-request',
    'from-init',
    'from-zero',
    'from-generator',
    'from-proto',
    'from-shared-iterator',
  ]);
  assert.deepEqual(messages, [{
    url: 'https://cdn.example/video.m3u8',
    method: 'POST',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-request'},
  }, {
    url: 'https://cdn.example/overridden.m3u8',
    method: 'PUT',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-init'},
  }, {
    url: 'https://cdn.example/numeric-method.m3u8',
    method: '0',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-zero'},
  }, {
    url: 'https://cdn.example/generator-headers.m3u8',
    method: 'PATCH',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-generator'},
  }, {
    url: 'https://cdn.example/proto-header.m3u8',
    method: 'DELETE',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: Object.fromEntries([['__proto__', 'from-proto']]),
  }, {
    url: 'https://cdn.example/shared-iterator.m3u8',
    method: 'OPTIONS',
    initiator: 'https://page.example/watch',
    mimeType: '',
    requestHeaders: {'x-request': 'from-shared-iterator'},
  }]);
});

test('preserves fetch rejection and direct capture for invalid HeadersInit', async () => {
  const fetchError = new TypeError('fetch rejected invalid headers');
  let originalFetchCalls = 0;
  let replayedInvalidHeaders;
  const headerIteratorError = new TypeError('header iterator failed');
  const sharedHeaderIteratorError = new TypeError(
    'shared header iterator failed',
  );
  const nestedPairIteratorError = new TypeError('nested header pair failed');
  const cyclicHeaders = [];
  cyclicHeaders.push(cyclicHeaders);
  function* invalidHeaderEntries() {
    yield ['X-Invalid'];
  }
  function* throwingHeaderEntries() {
    yield ['X-Request', 'before-error'];
    throw headerIteratorError;
  }
  let sharedHeaderIndex = 0;
  let sharedHeaderIteratorThrew = false;
  const sharedWrapperThrowingHeaders = {
    [Symbol.iterator]() {
      return {
        next() {
          if (sharedHeaderIndex === 0) {
            sharedHeaderIndex++;
            return {done: false, value: ['X-Request', 'before-error']};
          }
          if (!sharedHeaderIteratorThrew) {
            sharedHeaderIteratorThrew = true;
            throw sharedHeaderIteratorError;
          }
          return {done: true};
        },
      };
    },
  };
  function* throwingNestedHeaderPair() {
    yield 'X-Request';
    throw nestedPairIteratorError;
  }
  const oneShotInvalidHeaders = invalidHeaderEntries();
  const requestWithHeaders = new Request(
    'https://cdn.example/falsey-headers.m3u8',
    {headers: {'X-Request': 'inherited'}},
  );
  const {messages, window} = installHook([], (...args) => {
    originalFetchCalls++;
    if (args[0] === 'https://cdn.example/invalid-generator.m3u8') {
      replayedInvalidHeaders = JSON.parse(JSON.stringify(args[1].headers));
    }
    return Promise.reject(fetchError);
  });
  let fetchPromise;

  assert.doesNotThrow(() => {
    fetchPromise = window.fetch('https://api.example/redirect', {
      headers: [['X-Invalid']],
    });
  });
  assert.equal(originalFetchCalls, 1);
  await assert.rejects(fetchPromise, (error) => error === fetchError);

  let directFetchPromise;
  assert.doesNotThrow(() => {
    directFetchPromise = window.fetch('https://cdn.example/direct.m3u8', {
      headers: [['X-Invalid']],
    });
  });
  assert.equal(originalFetchCalls, 2);
  await assert.rejects(directFetchPromise, (error) => error === fetchError);

  let cyclicFetchPromise;
  assert.doesNotThrow(() => {
    cyclicFetchPromise = window.fetch('https://cdn.example/cyclic.m3u8', {
      headers: cyclicHeaders,
    });
  });
  assert.equal(originalFetchCalls, 3);
  await assert.rejects(cyclicFetchPromise, (error) => error === fetchError);

  let falseyOverridePromise;
  assert.doesNotThrow(() => {
    falseyOverridePromise = window.fetch(requestWithHeaders, {headers: ''});
  });
  assert.equal(originalFetchCalls, 4);
  await assert.rejects(falseyOverridePromise, (error) => error === fetchError);
  assert.deepEqual(messages[2].requestHeaders, {});

  let invalidGeneratorPromise;
  assert.doesNotThrow(() => {
    invalidGeneratorPromise = window.fetch(
      'https://cdn.example/invalid-generator.m3u8',
      {headers: oneShotInvalidHeaders},
    );
  });
  await assert.rejects(invalidGeneratorPromise, (error) => error === fetchError);
  assert.equal(originalFetchCalls, 5);
  assert.deepEqual(replayedInvalidHeaders, [['X-Invalid']]);

  let throwingIteratorPromise;
  assert.doesNotThrow(() => {
    throwingIteratorPromise = window.fetch(
      'https://cdn.example/throwing-iterator.m3u8',
      {headers: throwingHeaderEntries()},
    );
  });
  await assert.rejects(
    throwingIteratorPromise,
    (error) => error === headerIteratorError,
  );
  assert.equal(originalFetchCalls, 5);

  let throwingPairPromise;
  assert.doesNotThrow(() => {
    throwingPairPromise = window.fetch(
      'https://cdn.example/throwing-pair.m3u8',
      {headers: [throwingNestedHeaderPair()]},
    );
  });
  await assert.rejects(
    throwingPairPromise,
    (error) => error === nestedPairIteratorError,
  );
  assert.equal(originalFetchCalls, 5);

  let sharedWrapperPromise;
  assert.doesNotThrow(() => {
    sharedWrapperPromise = window.fetch(
      'https://cdn.example/shared-wrapper-throw.m3u8',
      {headers: sharedWrapperThrowingHeaders},
    );
  });
  await assert.rejects(
    sharedWrapperPromise,
    (error) => error === sharedHeaderIteratorError,
  );
  assert.equal(originalFetchCalls, 5);

  assert.deepEqual(
    messages.map(({url}) => url),
    [
      'https://cdn.example/direct.m3u8',
      'https://cdn.example/cyclic.m3u8',
      'https://cdn.example/falsey-headers.m3u8',
      'https://cdn.example/invalid-generator.m3u8',
      'https://cdn.example/throwing-iterator.m3u8',
      'https://cdn.example/throwing-pair.m3u8',
      'https://cdn.example/shared-wrapper-throw.m3u8',
    ],
  );
  assert.deepEqual(messages[1].requestHeaders, {});
  assert.deepEqual(messages[2].requestHeaders, {});
  assert.deepEqual(messages[3].requestHeaders, {});
  assert.deepEqual(messages[4].requestHeaders, {});
  assert.deepEqual(messages[5].requestHeaders, {});
  assert.deepEqual(messages[6].requestHeaders, {});
});
