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

function installHook(mediaElements) {
  const messages = [];
  const observers = [];
  const window = {
    fetch: () => Promise.resolve(),
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
    URL,
    console: {log() {}},
    setTimeout,
  });

  return {messages, observer: observers[0], XMLHttpRequest: FakeXMLHttpRequest};
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
