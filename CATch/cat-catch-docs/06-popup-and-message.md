# 06 — Popup UI 与消息系统

## 文件位置

- `js/popup.js` — 弹出窗口 UI 逻辑 (1088行)
- `js/popup-utils.js` — 工具函数 (232行)
- `js/content-script.js` — 页面层消息桥接 (279行)
- `popup.html` — 弹出窗口 HTML

## 完整消息列表

### background → popup

| Message | 时机 | 数据 |
|---------|------|------|
| `popupAddData` | 发现新资源 | `{ Message, data: infoObject }` |
| `popupAddKey` | 发现疑似密钥 | `{ Message, data: key, url }` |

### popup → background

| Message | 用途 | 参数 |
|---------|------|------|
| `getAllData` | 拉取所有标签缓存 | `{ Message }` → 返回 `cacheData` |
| `getData` | 拉取指定标签缓存 | `{ Message, tabId }` → 返回 `cacheData[tabId]` |
| `getData` (requestId) | 按 requestId 查数据 | `{ Message, requestId[] }` |
| `getButtonState` | 获取按钮状态 | `{ Message, tabId }` → `{ MobileUserAgent, AutoDown, enable, scripts }` |
| `enable` | 切换启用/暂停 | `{ Message }` → 返回新状态 |
| `mobileUserAgent` | 切换模拟手机 | `{ Message, tabId }` |
| `autoDown` | 切换自动下载 | `{ Message, tabId }` |
| `script` | 切换脚本注入 | `{ Message, tabId, script }` |
| `clearData` | 清空缓存 | `{ Message, tabId, type }` |
| `clearRedundant` | 清理冗余数据 | `{ Message }` |
| `pushData` | 保存缓存到 storage | `{ Message }` |
| `HeartBeat` | 保活 / 获取当前 tabId | `{ Message }` |
| `ClearIcon` | 清除图标角标 | `{ Message, tabId?, type? }` |

### content-script → background

| Message | 来源 | 数据 |
|---------|------|------|
| `addMedia` | window postMessage → content-script | `{ url, href, ext, mime, requestHeaders }` |
| `catCatchFFmpeg` | window postMessage | 在线 FFmpeg 数据 |

### background → content-script

| Message | 用途 |
|---------|------|
| `getVideoState` | 获取页面 video 元素状态 |
| `speed` | 设置播放速度 |
| `pip` | 画中画切换 |
| `fullScreen` | 全屏切换 |
| `play/pause/loop/muted/setVolume/setTime` | 视频控制 |
| `screenshot` | 视频截图 |
| `getKey` | 获取已捕获的密钥 |
| `getPage` | 获取页面 HTML (用于模板引擎 `find`) |

## Popup 的核心数据结构

```js
// 储存所有资源
const allData = new Map([
    [true, new Map()],   // 当前标签
    [false, new Map()]   // 其他标签
]);

// 每条资源的 key 是 requestId, value 是:
{
    requestId, name, url, ext, type, size, tabId,
    title, webUrl, favIconUrl, initiator,
    requestHeaders, cookie, isRegex,
    parsing: "m3u8" | "mpd" | "json" | false,
    isPlay: boolean,
    downFileName: string,
    html: jQuery DOM,           // 渲染后的 DOM 元素
    checked: boolean,           // 复选框状态
    urlPanelShow: boolean,      // 是否展开 URL
    pageDOM: Document | null,   // 页面 DOM (用于 find 模板)
}
```

## 资源 DOM 结构

```html
<div class="panel">
  <div class="panel-heading">
    <input type="checkbox" class="DownCheck"/>
    <img class="favicon" />          <!-- 网站图标 -->
    <img class="regex" />            <!-- 正则匹配标记 -->
    <span class="name">xxx.mp4</span> <!-- 文件名 -->
    <span class="size">12.3MB</span>  <!-- 大小 -->
    <img class="icon copy" />        <!-- 复制 URL -->
    <img class="icon parsing" />     <!-- 解析 (m3u8/mpd) -->
    <img class="icon play" />        <!-- 预览播放 -->
    <img class="icon download" />    <!-- 下载 -->
    <img class="icon aria2" />       <!-- 发送到 Aria2 -->
    <img class="icon invoke" />      <!-- 外部调用 -->
    <img class="icon send" />        <!-- 发送到本地 -->
    <img class="icon mqtt" />        <!-- 发送到 MQTT -->
  </div>
  <div class="url hide">
    <div id="mediaInfo">             <!-- 资源元信息 -->
    <div class="moreButton">         <!-- 更多操作 -->
    <a href="..." download="...">    <!-- 直链 -->
    <video id="preview">             <!-- 预览 (m3u8 使用 hls.js) -->
    <img id="screenshots">           <!-- 图片预览 -->
  </div>
</div>
```

## AddMedia 关键代码

```js
function AddMedia(data, currentTab = true) {
    data.name = isEmpty(data.name)
        ? data.title + '.' + data.ext
        : decodeURIComponent(stringModify(data.name));

    // 判断是否需要解析 (m3u8 / mpd / json)
    data.parsing = false;
    if (isM3U8(data))       data.parsing = "m3u8";
    else if (isMPD(data))   data.parsing = "mpd";
    else if (isJSON(data))  data.parsing = "json";

    // 判断是否可播放预览
    data.isPlay = isPlay(data);

    // 构建 DOM
    data.html = $(`<div class="panel">...`);

    // 创建筛选器 (按扩展名)
    if (!filterExt.has(data.ext)) {
        filterExt.set(data.ext, true);
        // 添加筛选 checkbox
    }

    return data.html;
}
```

## 筛选器

```
按扩展名筛选: 动态生成 checkbox，点击切换显示/隐藏
按正则筛选: 输入正则表达式，匹配 URL
去重: 按文件名去重
展开/折叠: 全部展开 / 可播放展开 / 选中展开 / 全部折叠
```

## 数据加载流程

```js
// 等待 G 变量初始化完成
const interval = setInterval(function () {
    if (!G.initSyncComplete || !G.initLocalComplete || !G.tabId) return;
    clearInterval(interval);

    // 1. 拉取当前标签的缓存数据
    chrome.runtime.sendMessage({ Message: "getData", tabId: G.tabId }, function (data) {
        for (let key = 0; key < data.length; key++) {
            $current.append(AddMedia(data[key]));
        }
        $mediaList.append($current);
    });

    // 2. 监听实时推送的新资源
    chrome.runtime.onMessage.addListener(function (Message) {
        if (Message.Message == "popupAddData") {
            const html = AddMedia(Message.data);
            $current.append(html);
        }
        if (Message.Message == "popupAddKey") {
            $maybeKey.append(AddKey(Message.data));
        }
    });

    // 3. 获取按钮状态
    updateButton();
}, 0);
```

## 类型判断函数

```js
// 来自 popup-utils.js
function isM3U8(data) {
    return data.ext == "m3u8" || data.ext == "m3u"
        || data.type?.endsWith("/vnd.apple.mpegurl")
        || data.type?.endsWith("/x-mpegurl")
        || data.type?.endsWith("/mpegurl");
}
function isMPD(data) {
    return data.ext == "mpd" || data.type == "application/dash+xml";
}
function isJSON(data) {
    return data.ext == "json" || data.type == "application/json";
}
function isPicture(data) {
    return data.type?.startsWith("image/") || ["jpg","png","jpeg","bmp","gif","webp","svg"].includes(data.ext);
}
function isMediaExt(ext) {
    return ['ogg','ogv','mp4','webm','mp3','wav','m4a','3gp','mpeg','mov','m4s','aac'].includes(ext);
}
function isPlay(data) {
    // 可播放: 有 Player 配置 / 非 JSON 非图片 / 媒体扩展名 / m3u8
    return (G.Player && !isJSON(data) && !isPicture(data))
        || isMediaExt(data.ext)
        || isM3U8(data);
}
```

## HeartBeat 保活

```js
// content-script.js
var Port;
function connect() {
    Port = chrome.runtime.connect(chrome.runtime.id, { name: "HeartBeat" });
    Port.postMessage("HeartBeat");
    Port.onDisconnect.addListener(connect);  // 断线自动重连
}
connect();

// background.js
chrome.runtime.onConnect.addListener(function (Port) {
    if (Port.name !== "HeartBeat") return;
    Port.postMessage("HeartBeat");
    // 250 秒后断开 → 触发 content-script 重连
    setInterval(function () { Port.disconnect(); }, 250000);
});
```

## 迁移要点

| 概念 | 实现 |
|------|------|
| 实时推送 | background 通过 `chrome.runtime.sendMessage` 实时推送新资源到 popup |
| 双面板 | "当前标签" + "其他标签" 两个资源列表，通过 TabButton 切换 |
| 懒加载 | "其他标签" 在用户点击后才拉取数据，避免不必要的性能开销 |
| 内存控制 | 500 条以上提示确认是否加载，避免大量 DOM 操作导致卡顿 |
| 数据绑定 | 每个资源对象持有其 DOM 引用，使用 `allData Map` 统一管理 |
| 消息桥接 | MAIN world → postMessage → content-script (ISOLATED) → runtime.sendMessage → background |
