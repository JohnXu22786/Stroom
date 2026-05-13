# 03 — 深度搜索引擎 (search.js)

## 文件位置

`catch-script/search.js` (825行)

## 作用

注入到页面 MAIN world 中，劫持原生 JavaScript API，从任意数据流转中嗅探媒体资源。这是猫抓的核心技术亮点。

## 劫持清单

### 网络层

```js
// 劫持 XMLHttpRequest
const _xhrOpen = XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open = function (method) {
    this.addEventListener("readystatechange", function (event) {
        if (this.status != 200) return;

        // 检查 response 是否为 ArrayBuffer（可能是密钥）
        if (this.responseType === "arraybuffer" && this.response?.byteLength) {
            if (this.response.byteLength === 16 || this.response.byteLength === 32)
                postData({ action: "catCatchAddKey", key: this.response, ... });
        }

        // 检查 response 是否为 JSON/对象
        if (typeof this.response == "object") {
            findMedia(this.response); // 递归遍历 JSON 中的 URL
            return;
        }

        // 检查 m3u8 内容
        const responseUpper = this.response.toUpperCase();
        if (responseUpper.includes("#EXTM3U")) {
            toUrl(this.response); // 转换为可下载对象
            postData({ action: "catCatchAddMedia", url: this.responseURL, ext: "m3u8" });
        }

        // 检查 JSON 字符串
        const isJson = isJSON(this.response);
        if (isJson) findMedia(isJson);
    });
    _xhrOpen.apply(this, arguments);
};

// 劫持 Fetch API
const _fetch = fetch;
fetch = async function (input, init) {
    let response = await _fetch.apply(this, arguments);
    const clone = response.clone();
    response.arrayBuffer().then(arrayBuffer => {
        // 检查 16 字节密钥
        if (arrayBuffer.byteLength == 16) {
            postData({ action: "catCatchAddKey", key: arrayBuffer, ... });
            return;
        }
        let text = new TextDecoder().decode(arrayBuffer);
        let isJson = isJSON(text);
        if (isJson) { findMedia(isJson); return; }
        if (text.startsWith("#EXTM3U")) {
            toUrl(addBaseUrl(getBaseUrl(input), text));
            postData({ action: "catCatchAddMedia", url: input, ext: "m3u8" });
        }
    });
    return clone; // 返回原始响应，不影响页面功能
};
```

### 数据处理层

```js
// 劫持 JSON.parse — 递归遍历所有 JSON 字段找 URL
const _JSONparse = JSON.parse;
JSON.parse = function () {
    let data = _JSONparse.apply(this, arguments);
    findMedia(data); // 递归搜索
    return data;
};

// 劫持 String.fromCharCode — 捕获 m3u8 文本拼接
const originalFromCharCode = String.fromCharCode;
String.fromCharCode = new Proxy(originalFromCharCode, {
    apply(target, thisArg, argumentsList) {
        const data = Reflect.apply(target, thisArg, argumentsList);
        if (data.length < 7) return data;
        if (data.startsWith("#EXTM3U") || data.includes("#EXTINF:")) {
            m3u8Text += data;
            if (m3u8Text.includes("#EXT-X-ENDLIST")) {
                toUrl(m3u8Text.split("#EXT-X-ENDLIST")[0] + "#EXT-X-ENDLIST");
                m3u8Text = '';
            }
        }
        return data;
    }
});
```

### 密钥嗅探

```js
// 劫持 btoa — 检测 24 字符 base64 (16字节 AES 密钥的 base64 编码)
const _btoa = btoa;
btoa = function (data) {
    const base64 = _btoa.apply(this, arguments);
    if (base64.length == 24 && base64.substring(22, 24) == "==") {
        postData({ action: "catCatchAddKey", key: base64, ext: "base64Key" });
    }
    return base64;
};

// 劫持 Uint8Array/Uint16Array/Uint32Array — 捕获 16 字节的密钥
const findTypedArray = (target, args) => {
    const isArray = Array.isArray(args[0]) && args[0].length === 16;
    const instance = new target(...args);
    if (isArray || args[0] instanceof ArrayBuffer && args[0].byteLength === 16) {
        postData({ action: "catCatchAddKey", key: args[0], ... });
    } else if (instance.buffer.byteLength === 16) {
        postData({ action: "catCatchAddKey", key: instance.buffer, ... });
    }
    return instance;
};
Uint8Array = new Proxy(Uint8Array, { construct: (target, args) => findTypedArray(target, args) });

// 劫持 DataView — 同上
DataView = function () {
    const instance = new _DataView(...arguments);
    for (const methodName of ['setInt8', 'setUint8', ...]) {
        const originalMethod = instance[methodName];
        instance[methodName] = function (...args) {
            const result = originalMethod.apply(this, args);
            if (this.byteLength === 16)
                postData({ action: "catCatchAddKey", key: this.buffer, ... });
            return result;
        };
    }
    return instance;
};

// 劫持 Array.prototype.slice — 检测 32→16 的密钥截取
const _slice = Array.prototype.slice;
Array.prototype.slice = function (start, end) {
    const data = _slice.apply(this, arguments);
    if (end == 16 && this.length == 32) {
        for (let item of data) {
            if (typeof item != "number" || item > 255) return data;
        }
        postData({ action: "catCatchAddKey", key: data, ... });
    }
    return data;
};
```

### Worker 注入

```js
// 劫持 Worker 构造函数，将 search.js 自身注入到 Worker 作用域
const _Worker = Worker;
self.Worker = function (scriptURL, options) {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', scriptURL, false);
    xhr.send();
    if (xhr.status === 200) {
        const blob = new Blob([
            `(${__CAT_CATCH_CATCH_SCRIPT__.toString()})();`, // 先执行 search.js
            xhr.response                                      // 再执行原始 Worker 代码
        ], { type: 'text/javascript' });
        const newWorker = new _Worker(URL.createObjectURL(blob), options);
        // 监听 Worker 发出的消息
        newWorker.addEventListener("message", function (event) {
            if (event.data?.action == "catCatchAddKey" || event.data?.action == "catCatchAddMedia") {
                postData(event.data);
            }
        });
        return newWorker;
    }
    return new _Worker(scriptURL, options);
};
```

### Vimeo 特殊处理

```js
async function vimeo(originalUrl, json) {
    if (!regexVimeo.test(originalUrl) || videoSet.has(originalUrl)) return;
    const data = isJSON(json);
    if (!data?.base_url || !data?.video) return;
    videoSet.add(originalUrl);

    // 将 Vimeo 的 JSON playlist 转换为标准 M3U8
    let M3U8List = ["#EXTM3U", "#EXT-X-INDEPENDENT-SEGMENTS", "#EXT-X-VERSION:3"];
    for (const stream of data.video) {
        const blobUrl = toM3U8(stream); // 构造标准 m3u8
        M3U8List.push(`#EXT-X-STREAM-INF:BANDWIDTH=${stream.bitrate},RESOLUTION=${stream.width}x${stream.height}`);
        M3U8List.push(blobUrl);
    }
    // 通过 Blob URL 提交
    const blobUrl = URL.createObjectURL(new Blob([M3U8List.join("\n")]));
    postData({ action: "catCatchAddMedia", url: blobUrl, ext: "m3u8" });
}
```

## 配置对象 `G.scriptList`

```js
G.scriptList = new Map();
G.scriptList.set("search.js", {
    key: "search",         // 按钮 ID
    refresh: true,         // 开启后需要刷新页面
    allFrames: true,       // 注入所有 frame
    world: "MAIN",         // MAIN world (与页面共享 JS 上下文)
    name: i18n.deepSearch, // 显示名称
    off: i18n.closeSearch, // 关闭时的名称
    i18n: false,           // 不需要预先注入 i18n
    tabId: new Set()       // 记录了哪些标签页开启了此脚本
});
```

## 数据通信方式

```
search.js (MAIN world)
  └─ self.postMessage({ action: "catCatchAddMedia", url, href, ext, ... })
      └─ content-script.js 监听 window message
          └─ chrome.runtime.sendMessage({ Message: "addMedia", ... })
              └─ background.js findMedia()
                  └─ chrome.runtime.sendMessage({ Message: "popupAddData" })
                      └─ popup.js 渲染到 UI
```

## 迁移要点

| 技巧 | 实现方式 |
|------|---------|
| 无痕劫持 | 保存原始函数引用（`const _fetch = fetch`），劫持后暴露 `toString()` 返回原始函数字符串 |
| 数据完整性 | 所有劫持函数需返回原始结果，不影响页面功能 |
| Worker 注入 | 将自身代码拼接后创建 Blob，再传给 Worker |
| 递归搜索 | `findMedia()` 递归遍历对象树，深度限制 10 层 |
| 防重复 | `filter` Set 按 URL 值去重 |
| Blob URL 处理 | 对于非完整 URL 的 m3u8，使用 `URL.createObjectURL(new Blob([...]))` 创建可访问的 Blob URL |
