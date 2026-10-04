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
  const cyclicHeaders = [];
  cyclicHeaders.push(cyclicHeaders);
  function* invalidHeaderEntries() {
    yield ['X-Invalid'];
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
  assert.deepEqual(
    messages.map(({url}) => url),
    [
      'https://cdn.example/direct.m3u8',
      'https://cdn.example/cyclic.m3u8',
      'https://cdn.example/falsey-headers.m3u8',
      'https://cdn.example/invalid-generator.m3u8',
    ],
  );
  assert.deepEqual(messages[1].requestHeaders, {});
  assert.deepEqual(messages[2].requestHeaders, {});
  assert.deepEqual(messages[3].requestHeaders, {});
});
