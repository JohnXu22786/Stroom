# 08 — 工具函数与配置系统

## 文件位置

- `js/function.js` — 工具函数、模板引擎、send2local (788行)
- `js/init.js` — 全局变量、配置初始化、storage 变化监听 (438行)

## 配置系统

### 配置层级

```
G.OptionLists (定义在 init.js 中的默认值)
  └─ chrome.storage.sync.get() → 用户存储的配置
      └─ 合并到全局对象 G
```

### 默认配置 (`init.js: G.OptionLists`)

```js
G.OptionLists = {
    // 过滤规则
    Ext: [   // 允许的扩展名列表
        { ext: "mp4",  size: 0, operator: ">=", unit: "KB", state: true },
        { ext: "m3u8", size: 0, operator: ">=", unit: "KB", state: true },
        { ext: "ts",   size: 0, operator: ">=", unit: "KB", state: false }, // 默认关闭
        // ... 共 33 种扩展名
    ],
    Type: [  // 允许的 Content-Type
        { type: "video/*",              size: 0, operator: ">=", unit: "KB", state: true },
        { type: "audio/*",              size: 0, operator: ">=", unit: "KB", state: true },
        { type: "application/dash+xml", size: 0, operator: ">=", unit: "KB", state: true },
        // ...
    ],
    Regex: [ // 正则匹配规则
        { type: "ig", regex: "https://cache\\.video\\.[a-z]*\\.com/dash\\?tvid=.*", ext: "json", state: false },
        // ...
    ],
    blockUrl: [],      // 屏蔽网址列表
    blockUrlWhite: false, // 白名单模式

    // UI 配置
    TitleName: false,
    Player: "",
    ShowWebIco: !G.isMobile,
    badgeNumber: true,
    popup: false,
    popupMode: 0,

    // 下载配置
    catDownload: false,
    downActive: true,
    downAutoClose: true,
    downStream: false,
    saveAs: false,
    chromeLimitSize: 1.8 * 1024 * 1024 * 1024,
    maxLength: G.isMobile ? 999 : 9999,
    checkDuplicates: true,

    // 自动下载
    downFileName: "${title}.${ext}",

    // 外部工具
    m3u8dl: 0,
    enableAria2Rpc: false,
    aria2Rpc: "http://localhost:6800/jsonrpc",

    // send2local (HTTP 推送)
    send2local: false,
    send2localManual: false,
    send2localURL: "http://127.0.0.1:8000/",
    send2localMethod: "POST",
    send2localBody: '{"action": "${action}", "data": ${data}, "tabId": "${tabId}"}',
    send2localType: 0,     // 0=JSON, 1=FormData, 2=URLEncoded, 3=Text

    // MQTT
    send2MQTT: false,
    mqttEnable: false,
    mqttBroker: "test.mosquitto.org",
    mqttPort: 8081,
    mqttTopic: "cat-catch/media",

    // 其他
    MobileUserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3...)",
    playbackRate: 2,
    autoClearMode: 1,
    deepSearch: false,
};
```

### 初始化流程

```js
function InitOptions() {
    // 1. 恢复缓存
    chrome.storage.session.get({ MediaData: {} }, function (items) {
        cacheData = items.MediaData.init ? {} : items.MediaData;
    });

    // 2. 读取 sync 配置
    chrome.storage.sync.get(G.OptionLists, function (items) {
        // 确保有默认值
        for (let key in G.OptionLists) {
            if (items[key] === undefined) items[key] = G.OptionLists[key];
        }

        // 3. 类型转换: Array → Map
        items.Ext = new Map(items.Ext.map(item => [item.ext, item]));
        items.Type = new Map(items.Type.map(item => [item.type, item]));

        // 4. 预编译正则
        items.Regex = items.Regex.map(item => {
            let reg = new RegExp(item.regex, item.type);
            return { regex: reg, ... };
        });

        // 5. 通配符转正则 (blockUrl)
        items.blockUrl = items.blockUrl.map(item => {
            return { url: wildcardToRegex(item.url), state: item.state };
        });

        // 6. 合并到 G
        G = { ...items, ...G };
        G.initSyncComplete = true;
    });

    // 7. 读取 local 配置
    chrome.storage.session.get(G.LocalVar, function (items) {
        items.featMobileTabId = new Set(items.featMobileTabId);
        items.featAutoDownTabId = new Set(items.featAutoDownTabId);
        G = { ...items, ...G };
        G.initLocalComplete = true;
    });
}
```

### 配置热更新

```js
// storage.onChanged 监听器使配置实时生效，无需重新加载
chrome.storage.onChanged.addListener(function (changes, namespace) {
    for (let [key, { newValue }] of Object.entries(changes)) {
        if (key == "Ext")  G.Ext = new Map(newValue.map(item => [item.ext, item]));
        if (key == "Type") G.Type = new Map(newValue.map(item => [item.type, item]));
        if (key == "Regex") G.Regex = newValue.map(item => ({ regex: new RegExp(item.regex, item.type), ... }));
        G[key] = newValue;
    }
});
```

## 模板引擎

猫抓实现了强大的模板系统，用于文件名生成、复制链接、外部调用参数等。

### 语法

```
${variable}                    → 直接替换
${variable|pipe:arg1,arg2}     → 管道处理
${variable|pipe1:arg|pipe2}    → 链式管道
```

### 变量列表

```js
// 媒体资源变量
${url}       // 完整 URL
${title}     // 页面标题
${ext}       // 文件扩展名
${referer}   // 请求 Referer
${origin}    // 请求 Origin
${initiator} // 发起页面
${cookie}    // Cookie
${tabId}     // 标签 ID
${fileName}  // 无扩展名的文件名
${fullFileName} // 完整文件名

// 时间变量
${year}, ${month}, ${date}, ${day}
${fullDate}, ${time}
${hours}, ${minutes}, ${seconds}
${now}, ${timestamp}

// 其他
${userAgent}, ${mobileUserAgent}
```

### 管道处理器

```js
const templatesProcessors = {
    slice:    (txt, arg) => txt.slice(...arg),
    replace:  (txt, arg) => txt.replace(...arg),
    replaceAll: (txt, arg) => txt.replaceAll(...arg),
    regexp:   (txt, arg) => txt.match(new RegExp(...arg))?.slice(1).join("") || "",
    exists:   (txt, arg) => txt ? arg[0]?.replaceAll("*", txt) : arg[1] || "",
    prepend:  (txt, arg) => arg[0] + txt,
    concat:   (txt, arg) => txt + arg[0],
    to:       (txt, arg) => {
        // base64, urlEncode, urlDecode, lowerCase, upperCase, trim, filter
    },
    find:     (txt, arg, data) => data?.pageDOM?.querySelector(arg[0])?.innerText || "",
    filter:   (txt, arg) => stringModify(txt, arg[0]),
    prompt:   (txt) => window.prompt("", txt) || ""
};
```

### 模板替换核心

```js
function templates(text, data) {
    const trimData = {
        url: data.url, title: data.title, ext: data.ext,
        year: date.getFullYear(), month: appendZero(date.getMonth()+1), ...
    };
    text = text.replace(/\${([^}|]+)(?:\|([^}]+))?}/g, function (original, tag, action) {
        if (action) return templatesFunction(trimData[tag], action.trim(), trimData);
        return trimData[tag] ?? original;
    });
    return text;
}
```

### 使用示例

```
// 默认下载文件名
${title}.${ext}
→ "My Video.mp4"

// 下载文件名（自定义）
${fileName|to:trim}_${now}.${ext}
→ "My_Video_2026-05-03T12-30-00Z.mp4"

// m3u8dl 参数模板
"${url}" --save-dir "%USERPROFILE%\\Downloads" --save-name "${title}_${now}" \
  ${referer|exists:'-H "Referer: *"'} ${cookie|exists:'-H "Cookie: *"'} --no-log

// 复制链接模板
${url}
```

## send2local — HTTP 推送系统

猫抓支持将发现的资源实时推送到本地 HTTP 服务。

### 发送流程

```js
function send2local(action, data, tabId) {
    // 1. 模板替换 Body
    let body = G.send2localBody.replaceAll('${data}', JSON.stringify(data));
    let postData = templates(body, data);
    postData = JSONparse(postData, { action, data, tabId });

    // 2. 执行请求
    return executeCoreRequest(postData, data);
}

function executeCoreRequest(postData, templateContext) {
    const option = { method: G.send2localMethod }; // POST / GET

    // 处理 URL 模板
    let send2localURL = templates(G.send2localURL, templateContext);
    send2localURL = new URL(send2localURL);

    if (option.method === 'GET') {
        // GET: 参数拼接到 URL
        send2localURL.search = new URLSearchParams(flattenObject(postData)).toString();
    } else {
        // POST: 按配置的 Content-Type 序列化
        switch (G.send2localType) {
            case 0: option.body = JSON.stringify(postData); break;
            case 1: // multipart/form-data
            case 2: // application/x-www-form-urlencoded
            case 3: // text/plain
        }
    }

    // 自定义 Headers
    if (G.send2localHeaders) {
        let customHeaders = templates(G.send2localHeaders, templateContext);
        Object.assign(option.headers, JSONparse(customHeaders));
    }

    return fetch(send2localURL.toString(), option);
}
```

### 支持的推送目标

| 目标 | 配置 | 协议 |
|------|------|------|
| 本地 HTTP | send2local=true | HTTP POST/GET |
| MQTT | mqttEnable=true | WebSocket MQTT |
| Aria2 | enableAria2Rpc=true | JSON-RPC |

## 通配符转正则

```js
function wildcardToRegex(urlPattern) {
    const regexPattern = urlPattern
        .replace(/[.+^${}()|[\]\\]/g, '\\$&')  // 转义正则特殊字符
        .replace(/\*/g, '.*')                   // * → .*
        .replace(/\?/g, '.');                   // ? → .
    return new RegExp(`^${regexPattern}$`, 'i'); // 忽略大小写
}
```

## 所有正则常量

```js
const reFilename = /filename="?([^"]+)"?/;
const reStringModify = /[<>:"\/\\|?*~]/g;
const reFilterFileName = /[<>:"|?*~]/g;
const reTemplates = /\${([^}|]+)(?:\|([^}]+))?}/g;
const reJSONparse = /([{,]\s*)([\w-]+)(\s*:)/g;
```

## 兼容性处理

```js
// 低版本 Chrome 缺少 chrome.i18n.getMessage
if (chrome.i18n.getMessage === undefined) {
    chrome.i18n.getMessage = (key) => key;
    // 从 _locales/zh_CN/messages.json 加载
}

// 部分修改版浏览器（如夸克）没有 chrome.downloads
if (!chrome.downloads) {
    chrome.downloads = {
        download: function (options, callback) {
            let a = document.createElement('a');
            a.href = options.url;
            a.download = options.filename;
            a.click();
            callback && callback();
        },
        onChanged: { addListener: function () {} },
    };
}

// Chrome 114 以下没有 chrome.sidePanel
if (!chrome.sidePanel || !chrome.sidePanel.setPanelBehavior) {
    chrome.sidePanel = { setOptions: function () {}, setPanelBehavior: function () {} };
}
```

## 迁移要点

| 功能 | 代码位置 | 核心逻辑 |
|------|---------|---------|
| 配置系统 | `init.js:InitOptions` | `chrome.storage.sync.get` → 类型转换 → 合并到 G |
| 热更新 | `init.js:storage.onChanged` | 监听 storage 变化，增量更新 G 属性 |
| 模板引擎 | `function.js:templates` | `replace(reTemplates, ...)` + 管道链处理 |
| HTTP 推送 | `function.js:send2local` | 模板替换 Body → 按 Content-Type 序列化 → fetch |
| 文件名过滤 | `function.js:filterFileName` | 替换 `<>:"\|?*~` + 前后不能是 `.` |
| 兼容层 | `init.js` 开头 | 低版本 API 降级 polyfill |
