# 05 — 下载系统

## 文件位置

- `js/downloader.js` — 下载管理器 (469行)
- `js/popup-utils.js` — Aria2 RPC / MQTT 发送 (232行)
- `js/m3u8.downloader.js` — m3u8 专有下载
- `js/m3u8.js` / `js/mpd.js` / `js/json.js` — 解析器

## 下载器架构

```
popup.js → chrome.downloads.download (直链)
         → openParser() → m3u8.html/mpd.html/json.html (解析器页面)
         → catDownload() → downloader.html (带请求头的下载器)
         → aria2AddUri() → Aria2 RPC
         → invoke() → 自定义协议/命令
         → send2local/MQTT → 外部服务
```

## 猫抓下载器 (downloader.js)

### 流程

```
用户点击下载
 └─ localStorage.setItem('downloadData', JSON.stringify(data))
 └─ chrome.runtime.sendMessage({ Message: "catDownload", data })
     ├─ 已有下载器页面 → 回复 OK → 添加下载任务
     └─ 无下载器 → 打开 downloader.html?requestId=xxx
```

### 多线程下载

```js
// 下载器使用声明式线程控制
// 每个 fragment 是一个下载单元
const down = new Downloader(_data);
down.thread = 6; // 默认 6 线程

// 事件驱动架构
down.on('itemProgress', function (fragment, state, receivedLength, contentLength) {
    // 更新进度条（限制 100ms 更新频率）
});

down.on('completed', function (buffer, fragment) {
    // 下载完单个文件
    if (fragment.fileStream) {
        fragment.fileStream.close(); // 流式下载
    } else {
        const blob = ArrayBufferToBlob(buffer);
        chrome.downloads.download({ url: URL.createObjectURL(blob), filename });
    }
});

down.on('allCompleted', function () {
    // 全部完成，可自动关闭页面
});

down.on('downloadError', function (fragment, error) {
    // 错误重试策略
    // 第1次: 添加 Range: bytes=0- 重试
    // 第2次: 添加 sec-fetch-mode/sec-fetch-site 头重试
});
```

### 错误重试

```js
down.on('downloadError', function (fragment, error) {
    // 策略1: Range 重试
    if (!fragment.retry?.Range && error?.cause == "HTTPError") {
        fragment.retry = { "Range": "bytes=0-" };
        down.stop(fragment.index);
        down.downloader(fragment);
        return;
    }
    // 策略2: sec-fetch 头重试
    if (!fragment.retry?.sec && error?.cause == "HTTPError") {
        fragment.retry.sec = true;
        fragment.requestHeaders = {
            ...fragment.requestHeaders,
            "sec-fetch-mode": "no-cors",
            "sec-fetch-site": "same-site"
        };
        setHeaders(fragment, () => {
            down.stop(fragment.index);
            down.downloader(fragment);
        }, _tabId);
        return;
    }
});
```

### 流式下载 (StreamSaver)

```js
// 对大于 2GB 的文件使用流式下载，绕过 Chrome 的 Blob URL 2GB 限制
const MAX_CHUNK_SIZE = 1024 * 1024 * 1024; // 1GB 分片
function ArrayBufferToBlob(buffer, options = {}) {
    if (buffer.byteLength >= 2 * 1024 * 1024 * 1024) {
        let offset = 0;
        const blobs = [];
        while (offset < buffer.byteLength) {
            const chunkSize = Math.min(MAX_CHUNK_SIZE, buffer.byteLength - offset);
            blobs.push(new Blob([buffer.slice(offset, offset + chunkSize)]));
            offset += chunkSize;
        }
        return new Blob(blobs, options);
    }
    return new Blob([buffer], options);
}
```

## 请求头注入下载

```js
// 使用 declarativeNetRequest 在下载时添加 Referer/Cookie
function setHeaders(data, callBack, tabId) {
    const rules = { removeRuleIds: [], addRules: [] };
    for (let item of data) {
        const rule = {
            id: parseInt(item.requestId),
            action: {
                type: "modifyHeaders",
                requestHeaders: Object.keys(item.requestHeaders).map(
                    key => ({ header: key, operation: "set", value: item.requestHeaders[key] })
                )
            },
            condition: {
                resourceTypes: ["xmlhttprequest", "media", "image"],
                tabIds: [tabId],
                urlFilter: item.url
            }
        };
        if (item.cookie) {
            rule.action.requestHeaders.push({ header: "Cookie", operation: "set", value: item.cookie });
        }
        rules.addRules.push(rule);
    }
    chrome.declarativeNetRequest.updateSessionRules(rules, callBack);
}
```

## Aria2 RPC

```js
function aria2AddUri(data, success, error) {
    const json = {
        "jsonrpc": "2.0",
        "id": "cat-catch-" + data.requestId,
        "method": "aria2.addUri",
        "params": []
    };
    if (G.aria2RpcToken) {
        json.params.push(`token:${G.aria2RpcToken}`);
    }
    const params = { out: data.downFileName };
    params.header = [];
    params.header.push("User-Agent: " + navigator.userAgent);
    if (data.requestHeaders?.referer)
        params.header.push("Referer: " + data.requestHeaders.referer);
    if (data.cookie)
        params.header.push("Cookie: " + data.cookie);

    json.params.push([data.url], params);
    fetch(G.aria2Rpc, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(json)
    });
}
```

## MQTT 发送

```js
function sendToMQTT(data) {
    // 使用 mqtt.min.js 连接代理
    const mqttUrl = `${G.mqttProtocol}://${G.mqttBroker}:${G.mqttPort}${G.mqttPath}`;
    const client = mqtt.connect(mqttUrl, {
        clientId: G.mqttClientId + "-" + Math.random().toString(16).slice(2),
        clean: true, connectTimeout: 10000
    });
    client.on('connect', () => {
        const topic = G.mqttTopic || "cat-catch/media";
        const message = G.mqttDataFormat
            ? templates(G.mqttDataFormat, data)
            : JSON.stringify(data);
        client.publish(topic, message, { qos: G.mqttQos });
    });
}
```

## FFmpeg 集成

猫抓集成了在线 FFmpeg 服务（`https://ffmpeg.bmmmd.com/`），用于：
- m3u8 下载后合并为 MP4
- 多个媒体文件合并
- 录制的视频转码

```js
// 通过 chrome.runtime.sendMessage 将数据发送到 FFmpeg 页面
function sendFile(action, data, fragment) {
    chrome.tabs.query({ url: G.ffmpegConfig.url + "*" }, function (tabs) {
        const baseData = {
            Message: "catCatchFFmpeg",
            action: action,       // "transcode" / "merge" / "catchMerge"
            files: [{
                data: URL.createObjectURL(data),
                name: fragment.title,
                index: fragment.index
            }],
            title: fragment.title,
            tabId: _tabId
        };
        chrome.runtime.sendMessage(baseData);
    });
}
```

## m3u8 解析器

解析 m3u8 播放列表并下载 TS 分片：

```
m3u8.html
  ├─ 解析 m3u8 playlist → 获取所有 TS 分片 URL
  ├─ 多线程下载 TS 分片 (可配置线程数)
  ├─ AES-128 解密 (解密密钥通过 search.js 捕获)
  ├─ 合并为 MP4 (纯前端: mux.js 或 在线 FFmpeg)
  └─ 下载合并后的文件
```

## 迁移要点

| 功能 | 实现方式 |
|------|---------|
| 多线程下载 | 使用 XHR + ArrayBuffer + Promise 队列控制并发数 |
| 请求头带 Referer 下载 | `declarativeNetRequest.updateSessionRules` 在下载器标签动态修改请求头 |
| 大文件下载 | StreamSaver.js (Service Worker 流式写入) 或分片 Blob |
| 错误重试 | Range 请求头重试 → sec-fetch 头重试，2 层策略 |
| 自动下载 | `G.featAutoDownTabId` Set 记录开启自动下载的标签 ID |
| 第三方工具集成 | 自定义协议 `m3u8dl:` → N_m3u8DL-CLI；`aria2:` → Aria2 RPC |
