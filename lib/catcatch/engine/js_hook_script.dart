/// JavaScript hook script for WebView-based network request interception.
///
/// This script is injected into the WebView at page start time (`onLoadStart`).
/// It monkey-patches `fetch` and `XMLHttpRequest`, and monitors DOM mutations
/// for `<video>`/`<audio>` elements. Detected media URLs are sent back to
/// Flutter via the `CatCatchChannel` JavaScript channel.
///
/// The xifangczy/cat-catch extension was a behavioral reference for media
/// interception. This hook targets WebView's JavaScriptChannel instead of
/// `chrome.runtime`; see `docs/third-party-notices.md` for provenance notes.
class JsHookScript {
  JsHookScript._();

  /// The JavaScript hook script as a string constant.
  ///
  /// Wrapped in an IIFE (Immediately Invoked Function Expression)
  /// to avoid polluting the global scope.
  static const String script = '''
(function() {
  'use strict';

  // =========================================================================
  // Configuration
  // =========================================================================
  var seenUrls = {};
  var MEDIA_EXT_RE = /\\.(mp4|m3u8|m3u|mpd|ts|webm|flv|f4v|ev1|mkv|avi|mov|wmv|ogg|ogv|aac|m4a|m4s|wav|mp3|opus|weba)(\\?|#|\$)/i;
  var PAGE_URL = window.location.href;

  // =========================================================================
  // Core: Send URL to Flutter via CatCatchChannel
  // =========================================================================
  function sendMediaUrl(url, opts) {
    if (url && typeof url === 'object') {
      try {
        url = URL.prototype.toString.call(url);
      } catch(e) {
        // Non-URL objects keep their existing handling.
      }
    }
    if (!url || typeof url !== 'string') return;

    // Normalize before filtering so only supported network URL schemes pass.
    try {
      var parsedUrl = new URL(url, PAGE_URL);
      if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') {
        return;
      }
      url = parsedUrl.href;
    } catch(e) {
      return; // Invalid URL, skip
    }
    // Dedup
    if (seenUrls[url]) return;
    // Check media extension
    if (!MEDIA_EXT_RE.test(url)) return;
    seenUrls[url] = true;

    var method = (opts && opts.method) || 'GET';
    var initiator = (opts && opts.initiator) || PAGE_URL;
    var mimeType = (opts && opts.mimeType) || '';
    var requestHeaders = (opts && opts.headers) || {};

    var msg = JSON.stringify({
      url: url,
      method: method,
      initiator: initiator,
      mimeType: mimeType,
      requestHeaders: requestHeaders
    });

    sendToFlutter(msg);
  }

  // =========================================================================
  // Utility: Send JSON message to Flutter via CatCatchChannel
  // =========================================================================
  function sendToFlutter(msg) {
    try {
      // flutter_inappwebview 6.x: use callHandler
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('CatCatchChannel', msg);
      }
      // Fallback: direct postMessage (for WebMessageListener-based setups)
      else if (window.CatCatchChannel && window.CatCatchChannel.postMessage) {
        window.CatCatchChannel.postMessage(msg);
      }
    } catch(e) {
      console.log('[CatCatch] sendToFlutter error:', e);
    }
  }

  // =========================================================================
  // Monkey-patch: window.fetch
  // =========================================================================
  var ORIGINAL_FETCH = window.fetch;
  window.fetch = function() {
    var args = arguments;
    var url = args[0];
    var opts = args[1] || {};
    var methodOption = opts.method;
    var method = methodOption !== undefined ? String(methodOption) : 'GET';
    var headersOption = opts.headers;
    var hasHeadersOption = headersOption !== undefined;
    var shouldReplayRequestInit = args.length > 1 && args[1] &&
      (typeof args[1] === 'object' || typeof args[1] === 'function');
    var headers = hasHeadersOption ? headersOption : {};
    var fetchArgs = args;
    var requestHeaders;
    var requestMethod;

    // Resolve URL if it's a Request object
    if (url && typeof url === 'object' && url.url) {
      requestMethod = url.method;
      method = methodOption !== undefined ? method : (requestMethod || method);
      requestHeaders = url.headers;
      headers = hasHeadersOption ? headersOption : (requestHeaders || headers);
      url = url.url;
    }

    // Normalize HeadersInit forms and make them JSON-serializable.
    var hasIterableHeaders = false;
    var hasReplayMethodOption = false;
    var replayMethodOption;
    var hasReplayHeadersOption = false;
    var replayHeadersOption;
    var headerSnapshotFailed = false;
    var headerSnapshotError;
    var replayInvalidHeaderStructure = false;
    var replayHeaderPairs = [];
    var headerIteratorMethod;
    try {
      if (headers && !shouldReplayRequestInit) {
        headerIteratorMethod = headers[Symbol.iterator];
      }
      if ((hasHeadersOption &&
          typeof headerIteratorMethod === 'function') ||
          shouldReplayRequestInit) {
        replayMethodOption = methodOption !== undefined ? method : undefined;
        if (replayMethodOption !== undefined) {
          method = replayMethodOption;
        } else {
          method = requestMethod || 'GET';
        }
        hasReplayMethodOption = true;
        replayHeadersOption = headersOption;
        hasReplayHeadersOption = true;
        hasHeadersOption = replayHeadersOption !== undefined;
        headers = hasHeadersOption
          ? replayHeadersOption
          : (requestHeaders || {});
        headerIteratorMethod = headers
          ? headers[Symbol.iterator]
          : undefined;
      }
      if (typeof headerIteratorMethod === 'function') {
        hasIterableHeaders = true;
        var headerIterator = Reflect.apply(
          headerIteratorMethod,
          headers,
          [],
        );
        var replayableHeaders = {};
        replayableHeaders[Symbol.iterator] = function() {
          return headerIterator;
        };
        Array.from(replayableHeaders, function(headerPair) {
          var replayPair = headerPair;
          var pairIterator;
          var hasPairIterator = false;
          var pairIterationComplete = false;
          var pairIteratorClosed = false;
          var pairConversionPending = false;
          var replayablePair;
          if (headerPair) {
            var pairIteratorMethod = headerPair[Symbol.iterator];
            if (typeof pairIteratorMethod !== 'function') {
              if (typeof headerPair === 'object' ||
                  typeof headerPair === 'function') {
                throw new TypeError('Header pair iterator is not callable');
              }
            } else {
              var pairIterator = Reflect.apply(
                pairIteratorMethod,
                  headerPair,
                  [],
                );
              if (!pairIterator ||
                  (typeof pairIterator !== 'object' &&
                   typeof pairIterator !== 'function')) {
                throw new TypeError('Header pair iterator is not an object');
              }
              var pairNextMethod = pairIterator.next;
              hasPairIterator = true;
              replayPair = [];
              var pairSnapshotIterator = {
                next: function() {
                  pairConversionPending = false;
                  var pairResult = Reflect.apply(
                    pairNextMethod,
                    pairIterator,
                    [],
                  );
                  if (pairResult === null ||
                      (typeof pairResult !== 'object' &&
                       typeof pairResult !== 'function')) {
                    throw new TypeError(
                      'Header pair iterator result is not an object',
                    );
                  }
                  var pairResultDone = false;
                  return {
                    get done() {
                      var done = pairResult.done;
                      pairResultDone = !!done;
                      if (pairResultDone) pairIterationComplete = true;
                      return done;
                    },
                    get value() {
                      if (pairResultDone) return pairResult.value;
                      pairConversionPending = true;
                      var value = pairResult.value;
                      if (typeof value === 'symbol') {
                        throw new TypeError(
                          'Cannot convert a Symbol value to a string',
                        );
                      }
                      value = String(value);
                      replayPair.push(value);
                      return value;
                    },
                  };
                },
                return: function() {
                  if (pairIteratorClosed) {
                    return {value: undefined, done: true};
                  }
                  pairIteratorClosed = true;
                  var pairReturnMethod = pairIterator.return;
                  if (pairReturnMethod === undefined ||
                      pairReturnMethod === null) {
                    return {value: undefined, done: true};
                  }
                  return Reflect.apply(pairReturnMethod, pairIterator, []);
                },
              };
              replayablePair = {};
              replayablePair[Symbol.iterator] = function() {
                return pairSnapshotIterator;
              };
            }
          }
          try {
            var parsedPair = new Headers([
              hasPairIterator ? replayablePair : replayPair,
            ]);
            var normalizedPair;
            parsedPair.forEach(function(value, name) {
              normalizedPair = [name, value];
            });
            replayHeaderPairs.push(normalizedPair);
            return normalizedPair;
          } catch(e) {
            if (pairConversionPending && !pairIterationComplete &&
                !pairIteratorClosed) {
              try {
                pairSnapshotIterator.return();
              } catch(closeError) {
                // Preserve the original header conversion error.
              }
            }
            var invalidPairStructure = hasPairIterator
              ? pairIterationComplete && replayPair.length !== 2
              : !Array.isArray(replayPair) || replayPair.length !== 2;
            if (invalidPairStructure) {
              replayInvalidHeaderStructure = true;
              replayHeaderPairs.push(replayPair);
            }
            throw e;
          }
        });
        headers = replayHeaderPairs;
      }
    } catch(e) {
      headerSnapshotFailed = true;
      headerSnapshotError = e;
      headers = replayHeaderPairs;
    }
    var normalizedHeaders = Object.create(null);
    try {
      if (headerSnapshotFailed && !replayInvalidHeaderStructure) {
        throw headerSnapshotError;
      }
      var headersForParsing = headers;
      if (shouldReplayRequestInit && headers &&
          (typeof headers === 'object' || typeof headers === 'function') &&
          typeof headerIteratorMethod !== 'function') {
        headersForParsing = new Proxy(headers, {
          get: function(target, property) {
            if (property === Symbol.iterator) return headerIteratorMethod;
            return Reflect.get(target, property, target);
          },
        });
      }
      var replayOptions;
      var replayOptionsSource;
      var replayHeadersOverride;
      if (hasIterableHeaders || hasReplayHeadersOption) {
        replayOptionsSource = Object(opts);
        replayHeadersOverride = hasIterableHeaders
          ? headers
          : replayHeadersOption;
        replayOptions = new Proxy({}, {
          get: function(target, property) {
            if (property === 'method' && hasReplayMethodOption) {
              return replayMethodOption;
            }
            if (property === 'headers') return replayHeadersOverride;
            return Reflect.get(
              replayOptionsSource,
              property,
              replayOptionsSource,
            );
          }
        });
        fetchArgs = Array.prototype.slice.call(args);
        fetchArgs[1] = replayOptions;
      }
      var parsedHeaders = new Headers(headersForParsing);
      if (replayOptions && (hasIterableHeaders || hasHeadersOption)) {
        replayHeadersOverride = parsedHeaders;
      }
      parsedHeaders.forEach(function(value, name) {
        normalizedHeaders[name] = value;
      });
    } catch(e) {
      // Let fetch produce its normal rejected promise for invalid headers.
      try {
        sendMediaUrl(url, {
          method: method,
          headers: {},
          initiator: PAGE_URL
        });
      } catch(captureError) {
        console.log('[CatCatch] fetch request capture error:', captureError);
      }
      if ((headerSnapshotFailed && !replayInvalidHeaderStructure) ||
          (hasIterableHeaders && fetchArgs === args) ||
          (!hasIterableHeaders && headersForParsing &&
              (typeof headersForParsing === 'object' ||
               typeof headersForParsing === 'function'))) {
        return Promise.reject(e);
      }
      return ORIGINAL_FETCH.apply(this, fetchArgs);
    }
    headers = normalizedHeaders;

    // Check on request
    sendMediaUrl(url, {
      method: method,
      headers: headers,
      initiator: PAGE_URL
    });

    // Capture a media URL reached after a redirect without consuming the
    // response or changing its rejection behavior.
    return ORIGINAL_FETCH.apply(this, fetchArgs).then(function(response) {
      try {
        if (response && response.url) {
          sendMediaUrl(response.url, {
            method: method,
            headers: headers,
            initiator: PAGE_URL
          });
        }
      } catch(e) {
        console.log('[CatCatch] fetch response capture error:', e);
      }
      return response;
    });
  };

  // =========================================================================
  // Monkey-patch: XMLHttpRequest
  // =========================================================================
  var ORIGINAL_XHR_OPEN = XMLHttpRequest.prototype.open;
  var ORIGINAL_XHR_SEND = XMLHttpRequest.prototype.send;

  XMLHttpRequest.prototype.open = function(method, url) {
    this._catCatchUrl = url;
    this._catCatchMethod = method || 'GET';
    return ORIGINAL_XHR_OPEN.apply(this, arguments);
  };

  XMLHttpRequest.prototype.send = function(body) {
    var xhr = this;
    var url = xhr._catCatchUrl;

    if (url) {
      sendMediaUrl(url, {
        method: xhr._catCatchMethod || 'GET',
        initiator: PAGE_URL
      });
    }

    // Listen independently so page handlers assigned before or after send
    // remain intact.
    try {
      if (!xhr._catCatchRedirectListener) {
        xhr._catCatchRedirectListener = function() {
          if (xhr.readyState !== 4) return;

          var responseUrl = xhr.responseURL;
          if (responseUrl && responseUrl !== xhr._catCatchUrl) {
            sendMediaUrl(responseUrl, {
              method: xhr._catCatchMethod || 'GET',
              initiator: PAGE_URL
            });
          }
        };
        xhr.addEventListener('readystatechange', xhr._catCatchRedirectListener);
      }
    } catch(e) {
      // Some environments restrict event listener access
    }

    return ORIGINAL_XHR_SEND.apply(this, arguments);
  };

  // =========================================================================
  // MutationObserver: Scan for <video>/<audio> elements
  // =========================================================================
  function markSourceForRescan(source) {
    source._catCatchScanned = false;

    var parent = source.parentElement;
    while (parent && parent.nodeName !== 'VIDEO' &&
        parent.nodeName !== 'AUDIO') {
      parent = parent.parentElement;
    }
    if (parent) {
      parent._catCatchScanned = false;
    }
  }

  function scanMediaElements() {
    try {
      document.querySelectorAll('video, audio').forEach(function(el) {
        if (el._catCatchScanned) return;
        el._catCatchScanned = true;

        // Check current src
        var src = el.currentSrc || el.src || '';
        var mediaUrls = [
          src,
          el.getAttribute('data-src'),
          el.getAttribute('data-url')
        ];
        mediaUrls.forEach(function(mediaUrl) {
          if (!mediaUrl) return;
          sendMediaUrl(mediaUrl, {
            method: 'GET',
            mimeType: el.tagName === 'VIDEO' ? 'video/*' : 'audio/*',
            initiator: PAGE_URL
          });
        });

        // Check <source> children
        el.querySelectorAll('source').forEach(function(source) {
          if (!source._catCatchScanned) {
            source._catCatchScanned = true;
            var sourceUrls = [
              source.src,
              source.getAttribute('data-src'),
              source.getAttribute('data-url')
            ];
            sourceUrls.forEach(function(sourceUrl) {
              if (!sourceUrl) return;
              sendMediaUrl(sourceUrl, {
                method: 'GET',
                mimeType: source.type || (el.tagName === 'VIDEO' ? 'video/*' : 'audio/*'),
                initiator: PAGE_URL
              });
            });
          }
        });
      });
    } catch(e) {
      console.log('[CatCatch] scanMediaElements error:', e);
    }
  }

  // Initial scan
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scanMediaElements);
  } else {
    scanMediaElements();
  }

  // Watch for dynamically added media elements
  var observer = new MutationObserver(function(mutations) {
    var needsScan = false;
    for (var i = 0; i < mutations.length; i++) {
      var mutation = mutations[i];
      if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
        for (var j = 0; j < mutation.addedNodes.length; j++) {
          var node = mutation.addedNodes[j];
          if (node.nodeName === 'VIDEO' || node.nodeName === 'AUDIO' ||
              node.querySelectorAll) {
            needsScan = true;
          }
          if (node.nodeName === 'SOURCE') {
            markSourceForRescan(node);
          }
          if (node.querySelectorAll) {
            node.querySelectorAll('source').forEach(markSourceForRescan);
          }
        }
      } else if (mutation.type === 'attributes' &&
                 (mutation.attributeName === 'src' ||
                  mutation.attributeName === 'data-src' ||
                  mutation.attributeName === 'data-url')) {
        var target = mutation.target;
        if (target && (target.nodeName === 'VIDEO' || target.nodeName === 'AUDIO' ||
            target.nodeName === 'SOURCE')) {
          if (target.nodeName === 'SOURCE') {
            markSourceForRescan(target);
          } else {
            target._catCatchScanned = false;
          }
          needsScan = true;
        }
      }
    }
    if (needsScan) {
      scanMediaElements();
    }
  });

  // Start observing once DOM is ready
  function startObserver() {
    var target = document.body || document.documentElement;
    if (target) {
      observer.observe(target, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['src', 'data-src', 'data-url']
      });
    } else {
      // Retry after DOM is ready
      setTimeout(startObserver, 100);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startObserver);
  } else {
    startObserver();
  }

  console.log('[CatCatch] Hook script initialized');
})();
''';
}
