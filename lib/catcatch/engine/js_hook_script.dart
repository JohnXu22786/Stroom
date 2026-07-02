/// JavaScript hook script for WebView-based network request interception.
///
/// This script is injected into the WebView at page start time (`onLoadStart`).
/// It monkey-patches `fetch` and `XMLHttpRequest`, and monitors DOM mutations
/// for `<video>`/`<audio>` elements. Detected media URLs are sent back to
/// Flutter via the `CatCatchChannel` JavaScript channel.
///
/// Design inspired by the official cat-catch extension's intercept patterns,
/// but adapted for WebView JavaScriptChannel instead of `chrome.runtime`.
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
  var MEDIA_EXT_RE = /\\.(mp4|m3u8|m3u|mpd|ts|webm|flv|f4v|mkv|avi|mov|wmv|ogg|ogv|aac|m4a|m4s|wav|mp3|opus|weba)(\\?|#|\$)/i;
  var PAGE_URL = window.location.href;

  // =========================================================================
  // Core: Send URL to Flutter via CatCatchChannel
  // =========================================================================
  function sendMediaUrl(url, opts) {
    if (!url || typeof url !== 'string') return;

    // Handle blob: URLs — report them but skip extension check
    if (url.startsWith('blob:')) {
      if (seenUrls[url]) return;
      seenUrls[url] = true;
      var method = (opts && opts.method) || 'GET';
      var initiator = (opts && opts.initiator) || PAGE_URL;
      var msg = JSON.stringify({
        url: url,
        method: method,
        initiator: initiator,
        mimeType: (opts && opts.mimeType) || '',
        requestHeaders: (opts && opts.headers) || {}
      });
      sendToFlutter(msg);
      return;
    }

    // Normalize: ensure absolute URL
    try {
      url = new URL(url, PAGE_URL).href;
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

    // Resolve URL if it's a Request object
    if (url && typeof url === 'object' && url.url) {
      url = url.url;
    }

    // Check on request
    sendMediaUrl(url, {
      method: opts.method || 'GET',
      headers: opts.headers || {},
      initiator: PAGE_URL
    });

    // Return original promise
    return ORIGINAL_FETCH.apply(this, args);
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

    // Also intercept on loadend to catch redirected URLs
    try {
      var originalOnReadyStateChange = xhr.onreadystatechange;
      xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
          var responseUrl = xhr.responseURL;
          if (responseUrl && responseUrl !== url) {
            sendMediaUrl(responseUrl, {
              method: xhr._catCatchMethod || 'GET',
              initiator: PAGE_URL
            });
          }
        }
        if (originalOnReadyStateChange) {
          originalOnReadyStateChange.apply(xhr, arguments);
        }
      };
    } catch(e) {
      // Some environments restrict onreadystatechange access
    }

    return ORIGINAL_XHR_SEND.apply(this, arguments);
  };

  // =========================================================================
  // MutationObserver: Scan for <video>/<audio> elements
  // =========================================================================
  function scanMediaElements() {
    try {
      document.querySelectorAll('video, audio').forEach(function(el) {
        if (el._catCatchScanned) return;
        el._catCatchScanned = true;

        // Check current src
        var src = el.currentSrc || el.src || '';
        if (src) {
          sendMediaUrl(src, {
            method: 'GET',
            mimeType: el.tagName === 'VIDEO' ? 'video/*' : 'audio/*',
            initiator: PAGE_URL
          });
        }

        // Check <source> children
        el.querySelectorAll('source').forEach(function(source) {
          if (source.src && !source._catCatchScanned) {
            source._catCatchScanned = true;
            sendMediaUrl(source.src, {
              method: 'GET',
              mimeType: source.type || (el.tagName === 'VIDEO' ? 'video/*' : 'audio/*'),
              initiator: PAGE_URL
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
            break;
          }
        }
      } else if (mutation.type === 'attributes' &&
                 (mutation.attributeName === 'src' ||
                  mutation.attributeName === 'data-src' ||
                  mutation.attributeName === 'data-url')) {
        var target = mutation.target;
        if (target && (target.nodeName === 'VIDEO' || target.nodeName === 'AUDIO' ||
            target.nodeName === 'SOURCE')) {
          target._catCatchScanned = false;
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
