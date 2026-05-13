# 02 — 核心嗅探引擎

## 文件位置

- `js/background.js` — 主引擎，`findMedia()` 函数
- `js/init.js` — 配置加载与过滤规则预编译

## 监听器注册

三个核心 webRequest 事件构成嗅探管道：

```js
// 1. onSendHeaders — 请求即将发出，获取请求头 + 正则匹配 URL
chrome.webRequest.onSendHeaders.addListener(
    function (data) {
        // 保存请求头供后续使用
        G.requestHeaders.set(data.requestId, data.requestHeaders);
        data.allRequestHeaders = data.requestHeaders;
        findMedia(data, true);  // isRegex=true: 先走正则匹配
    },
    { urls: ["<all_urls>"] },
    ['requestHeaders', chrome.webRequest.OnBeforeSendHeadersOptions.EXTRA_HEADERS].filter(Boolean)
);

// 2. onResponseStarted — 收到第一个字节，获取 Content-Type 等响应信息
chrome.webRequest.onResponseStarted.addListener(
    function (data) {
        data.allRequestHeaders = G.requestHeaders.get(data.requestId);
        G.requestHeaders.delete(data.requestId);  // 用完即删
        findMedia(data);  // isRegex=false: 走扩展名/类型匹配
    },
    { urls: ["<all_urls>"] },
    ["responseHeaders"]
);

// 3. onErrorOccurred — 请求失败，清理临时数据
chrome.webRequest.onErrorOccurred.addListener(
    function (data) {
        G.requestHeaders.delete(data.requestId);
        G.blackList.delete(data.requestId);
    },
    { urls: ["<all_urls>"] }
);
```

## findMedia 函数的完整过滤链

```js
function findMedia(data, isRegex = false, filter = false, timer = false) {
    // --- 安全检查 ---
    if (!G || !G.initSyncComplete || !G.initLocalComplete) {
        // Service Worker 刚唤醒，全局变量未就绪，延迟重试
        return setTimeout(() => findMedia(data, isRegex, filter, true), 500);
    }

    // 屏蔽网站（如 douyin.com）直接跳过
    if (G.damn && G.damnUrlSet.has(data.tabId)) return;

    // 检查总开关和网站白/黑名单
    const blockUrlFlag = data.tabId > 0 && G.blockUrlSet.has(data.tabId);
    if (!G.enable || (G.blockUrlWhite ? !blockUrlFlag : blockUrlFlag)) return;

    // 检查正则黑名单（将 requestId 加入 G.blackList 来拦截 onResponseStarted）
    if (!isRegex && G.blackList.has(data.requestId)) {
        G.blackList.delete(data.requestId);
        return;
    }

    // 过滤 chrome://about:// 等特殊页面
    if (isSpecialPage(data.initiator)) return;
    if (isSpecialPage(data.url)) return;

    const urlParsing = new URL(data.url);
    let [name, ext] = fileNameParse(urlParsing.pathname);

    // ── 第一阶段: 正则匹配 (isRegex=true) ──
    if (isRegex && !filter) {
        for (let key in G.Regex) {
            if (!G.Regex[key].state) continue;
            G.Regex[key].regex.lastIndex = 0;
            let result = G.Regex[key].regex.exec(data.url);
            if (result == null) continue;

            // blackList=true: 该正则匹配的 URL 要屏蔽
            if (G.Regex[key].blackList) {
                G.blackList.add(data.requestId);
                return;
            }
            data.extraExt = G.Regex[key].ext || undefined;
            // 提取 URL 中的实际资源地址
            if (result.length > 1) {
                result.shift();
                result = result.map(str => decodeURIComponent(str));
                data.url = result.join("");
            }
            findMedia(data, true, true);  // filter=true 跳过正则阶段
            return;
        }
        return;  // 正则没匹配到，放弃
    }

    // ── 第二阶段: 扩展名 / Content-Type / Content-Disposition 过滤 ──
    if (!isRegex) {
        data.header = getResponseHeadersValue(data);

        // 2a. 检查文件扩展名 (.mp4, .m3u8, .ts 等)
        if (!filter && ext !== undefined) {
            filter = CheckExtension(ext, data.header?.size);
            if (filter == "break") return;
        }
        // 2b. 检查 Content-Type (video/mp4, audio/mpeg 等)
        if (!filter && data.header?.type !== undefined) {
            filter = CheckType(data.header.type, data.header?.size);
            if (filter == "break") return;
        }
        // 2c. 检查 Content-Disposition (attachment; filename="xxx.mp4")
        if (!filter && data.header?.attachment !== undefined) {
            const res = data.header.attachment.match(reFilename);
            if (res && res[1]) {
                [name, ext] = fileNameParse(decodeURIComponent(res[1]));
                filter = CheckExtension(ext, 0);
                if (filter == "break") return;
            }
        }
        // 2d. Chrome 标记为 type=media 的资源直接放过
        if (data.type == "media") filter = true;
    }

    if (!filter) return;

    // ── 第三阶段: 组装信息, 发往 popup ──
    chrome.tabs.get(data.tabId, async function (webInfo) {
        data.requestHeaders = getRequestHeaders(data);
        const info = {
            name, url: data.url, size: data.header?.size,
            ext, type: data.mime ?? data.header?.type,
            tabId: data.tabId, isRegex, requestId: data.requestId ?? Date.now().toString(),
            initiator: data.initiator, requestHeaders: data.requestHeaders,
            cookie: data.cookie, getTime: data.getTime
        };
        // 发送到 popup
        chrome.runtime.sendMessage({ Message: "popupAddData", data: info });
        // 储存到缓存
        cacheData[info.tabId].push(info);
    });
}
```

## 过滤规则引擎

### 扩展名过滤 (CheckExtension)

```js
function CheckExtension(ext, size) {
    const Ext = G.Ext.get(ext);     // 从 Map 中查找扩展名
    if (!Ext) return false;         // 不在允许列表中 → 不匹配
    if (!Ext.state) return "break"; // 关闭状态 → 中断检查
    if (Ext.size != 0 && size !== undefined && !operatorCheck(size, Ext))
        return "break";             // 大小不符合条件 → 中断
    return true;                    // 通过
}
```

### MIME 类型过滤 (CheckType)

```js
function CheckType(dataType, dataSize) {
    // 先匹配精确类型，再匹配通配符 (video/*, audio/*)
    const typeInfo = G.Type.get(dataType.split("/")[0] + "/*") || G.Type.get(dataType);
    if (!typeInfo) return false;
    if (!typeInfo.state) return "break";
    if (typeInfo.size != 0 && dataSize !== undefined && !operatorCheck(dataSize, typeInfo))
        return "break";
    return true;
}
```

### 大小比较器 (operatorCheck)

```js
function operatorCheck(size, Obj) {
    const unitNumber = {
        "B": 1, "BYTE": 1, "KB": 1024,
        "MB": 1048576, "GB": 1073741824
    };
    const targetSize = Obj.size * (unitNumber[Obj.unit] || 1);
    switch (Obj.operator) {
        case "=":  return size == targetSize;
        case "<":  return size < targetSize;
        case ">":  return size > targetSize;
        case "<=": return size <= targetSize;
        case ">=": return size >= targetSize;
        case "!=": return size != targetSize;
        case "~":  return (Obj.min ? size >= Obj.min * unitNumber... : true)
                       && (Obj.max ? size <= Obj.max * unitNumber... : true);
        default:   return size <= targetSize;
    }
}
```

## 响应头解析

```js
function getResponseHeadersValue(data) {
    const header = {};
    for (let item of data.responseHeaders || []) {
        item.name = item.name.toLowerCase();
        if (item.name == "content-length")          header.size = parseInt(item.value);
        else if (item.name == "content-type")       header.type = item.value.split(";")[0].toLowerCase();
        else if (item.name == "content-disposition") header.attachment = item.value;
        else if (item.name == "content-range") {
            let size = item.value.split('/')[1];
            if (size !== '*') header.size = parseInt(size);
        }
    }
    return header;
}
```

## 请求头获取（Referer/Cookie/Authorization）

```js
function getRequestHeaders(data) {
    if (!data.allRequestHeaders) return false;
    const header = {};
    for (let item of data.allRequestHeaders) {
        item.name = item.name.toLowerCase();
        if (item.name == "referer")        header.referer = item.value;
        else if (item.name == "origin")    header.origin = item.value;
        else if (item.name == "cookie")    header.cookie = item.value;
        else if (item.name == "authorization") header.authorization = item.value;
    }
    return Object.keys(header).length ? header : false;
}
```

## 默认过滤规则

在 `init.js` 中定义：

**允许的后缀（Map）：**
```
flv, hlv, f4v, mp4, mp3, wma, wav, m4a, ts(disabled), webm,
ogg, ogv, acc, mov, mkv, m4s, m3u8, m3u, mpeg, avi, wmv,
asf, movie, divx, mpeg4, vid, aac, mpd, weba, opus, srt(disabled), vtt(disabled)
```

**允许的 Content-Type：**
```
audio/*, video/*, application/ogg,
application/vnd.apple.mpegurl, application/x-mpegurl,
application/dash+xml, application/m4s
```

## 迁移要点

| 概念 | 在你的应用中如何实现 |
|------|-------------------|
| 网络拦截 | 使用 `webRequest.onResponseStarted` 监听响应，从 `data.url` 和 `responseHeaders` 判断资源类型 |
| 过滤链 | 先正则 URL 匹配 → 扩展名 → Content-Type → Content-Disposition → media type，逐级 Check |
| 大小过滤 | 支持 `>`, `>=`, `<`, `<=`, `=`, `!=`, `~`(范围) 运算符 |
| 查重 | 使用 `Set` 按标签存储 URL 指纹，上限 500 条后清空 |
| 存储 | `chrome.storage.session` 优先，回退到 `chrome.storage.local`，用于跨 Service Worker 生命周期持久化 |
