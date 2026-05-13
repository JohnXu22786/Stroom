# 猫抓 (cat-catch) 核心逻辑文档

> 基于 [xifangczy/cat-catch](https://github.com/xifangczy/cat-catch) v2.6.8 源码分析
>
> 目标：理解猫抓的完整运行机制，便于迁移到其他应用

---

## 快速定位

### 我想了解...

| 如果你想了解 | 看哪个文档 |
|-------------|-----------|
| 整体架构是什么样的？哪些文件是干什么的？ | [01-architecture-overview.md](01-architecture-overview.md) |
| 它是怎么抓取网页上的视频/音频资源的？ | [02-sniffing-engine.md](02-sniffing-engine.md) |
| "深度搜索"是怎么劫持 JS 找资源的？ | [03-deep-search.md](03-deep-search.md) |
| "缓存捕捉"是怎么从 MediaSource 拿原始数据的？ | [04-cache-capture.md](04-cache-capture.md) |
| 下载系统是怎么工作的？多线程/Aria2/FFmpeg？ | [05-download-system.md](05-download-system.md) |
| Popup 怎么实时展示资源？消息是怎么传递的？ | [06-popup-and-message.md](06-popup-and-message.md) |
| 录屏/录制/WebRTC 脚本是怎么注入的？ | [07-inject-scripts.md](07-inject-scripts.md) |
| 配置系统/模板引擎/send2local 是怎么实现的？ | [08-utility-and-config.md](08-utility-and-config.md) |

### 我只想看某个具体的实现

| 主题 | 章节 |
|------|------|
| Manifest V3 配置和权限 | [01 → Manifest V3 关键配置](01-architecture-overview.md#manifest-v3-关键配置) |
| Service Worker 保活机制 | [01 → 在扩展中复制 Service Worker 保活机制](01-architecture-overview.md#在扩展中复制-service-worker-保活机制) |
| findMedia 完整过滤链 | [02 → findMedia 函数的完整过滤链](02-sniffing-engine.md#findmedia-函数的完整过滤链) |
| 过滤规则引擎(CheckExtension/CheckType) | [02 → 过滤规则引擎](02-sniffing-engine.md#过滤规则引擎) |
| 响应头/请求头解析 | [02 → 响应头解析](02-sniffing-engine.md#响应头解析) |
| 默认允许的资源类型列表 | [02 → 默认过滤规则](02-sniffing-engine.md#默认过滤规则) |
| XHR/fetch 劫持 | [03 → 网络层](03-deep-search.md#网络层) |
| JSON.parse / String.fromCharCode 劫持 | [03 → 数据处理层](03-deep-search.md#数据处理层) |
| AES-128 密钥嗅探 | [03 → 密钥嗅探](03-deep-search.md#密钥嗅探) |
| Worker 注入 | [03 → Worker 注入](03-deep-search.md#worker-注入) |
| MediaSource addSourceBuffer 代理 | [04 → 核心代理逻辑](04-cache-capture.md#核心代理逻辑) |
| 缓存的 MP4 头部检测与清理 | [04 → 下载处理](04-cache-capture.md#下载处理) |
| Shadow DOM closed mode | [04 → UI 控制面板](04-cache-capture.md#ui-控制面板) |
| 多线程下载器事件体系 | [05 → 猫抓下载器](05-download-system.md#猫抓下载器-downloaderjs) |
| 错误重试策略(Range/sec-fetch) | [05 → 错误重试](05-download-system.md#错误重试) |
| StreamSaver 大文件流式下载 | [05 → 流式下载](05-download-system.md#流式下载-streamsaver) |
| Aria2 RPC 集成 | [05 → Aria2 RPC](05-download-system.md#aria2-rpc) |
| MQTT 发送 | [05 → MQTT 发送](05-download-system.md#mqtt-发送) |
| 完整消息列表(background/popup/content) | [06 → 完整消息列表](06-popup-and-message.md#完整消息列表) |
| 资源 DOM 结构和渲染流程 | [06 → 资源 DOM 结构](06-popup-and-message.md#资源-dom-结构) |
| 类型判断函数(isM3U8/isMPD/isPlay) | [06 → 类型判断函数](06-popup-and-message.md#类型判断函数) |
| HeartBeat 保活 | [06 → HeartBeat 保活](06-popup-and-message.md#heartbeat-保活) |
| video 元素录制 (recorder.js) | [07 → recorder.js](07-inject-scripts.md#recorderjs--视频元素录制) |
| 屏幕录制 (recorder2.js) | [07 → recorder2.js](07-inject-scripts.md#recorder2js--屏幕录制) |
| WebRTC 流录制 (webrtc.js) | [07 → webrtc.js](07-inject-scripts.md#webrtcjs--webrtc-流录制) |
| 脚本注入触发机制 | [07 → 注入触发机制](07-inject-scripts.md#注入触发机制) |
| 配置系统(G.OptionLists) | [08 → 配置系统](08-utility-and-config.md#配置系统) |
| 模板引擎(变量/管道) | [08 → 模板引擎](08-utility-and-config.md#模板引擎) |
| send2local HTTP 推送 | [08 → send2local](08-utility-and-config.md#send2local--http-推送系统) |
| 通配符转正则 | [08 → 通配符转正则](08-utility-and-config.md#通配符转正则) |
| 浏览器兼容层 | [08 → 兼容性处理](08-utility-and-config.md#兼容性处理) |

---

## 技术速查表

### 核心架构

```
Layer 1: Service Worker (background.js)  ← 嗅探引擎、消息路由、配置管理
    ↕ chrome.runtime.sendMessage
Layer 2: Content Script (content-script.js)  ← 视频控制、消息桥接
    ↕ window.postMessage
Layer 3: Inject Scripts (catch-script/*.js)  ← 劫持原生 API、捕获媒体
```

### 嗅探过滤链

```
URL 到来 → 开关检查 → 网站白/黑名单 → 正则匹配 → 扩展名匹配 → Content-Type →
Content-Disposition → media type → 查重 → 存入缓存并通知 popup
```

### 三种嗅探方式

| 方式 | 匹配依据 | 代码位置 |
|------|---------|---------|
| 正则嗅探 | `G.Regex[]` 预编译正则匹配 URL | `background.js:findMedia()` 正则分支 |
| 后缀嗅探 | `G.Ext` Map → 文件扩展名 | `background.js:CheckExtension()` |
| 类型嗅探 | `G.Type` Map → Content-Type 头 | `background.js:CheckType()` |

### 深度搜索劫持清单

| 劫持对象 | 目的 |
|---------|------|
| `XMLHttpRequest.prototype.open` | 拦截 XHR 请求/响应 |
| `fetch` | 拦截 Fetch API |
| `JSON.parse` | 递归遍历 JSON 中的 URL |
| `Worker` 构造函数 | 注入钩子到 Worker |
| `btoa` / `atob` | 捕获 base64 编码的密钥和 m3u8 |
| `String.fromCharCode` | 捕获 m3u8 文本拼接 |
| `Uint8Array` / `Uint16Array` / `Uint32Array` | 捕获 16 字节 AES 密钥 |
| `DataView.setUint8` 等 | 同上 |
| `Array.prototype.slice` | 检测 32→16 的密钥截取 |
| `Array.prototype.join` | 检测 m3u8 拼接 |
| `String.prototype.indexOf` | 检测 `#EXTM3U` 标记 |

### 消息类型

- **background → popup**: `popupAddData`, `popupAddKey`
- **popup → background**: `getAllData`, `getData`, `getButtonState`, `enable`, `mobileUserAgent`, `autoDown`, `script`, `clearData`, `HeartBeat`
- **content-script → background**: `addMedia`, `catCatchFFmpeg`
- **background → content-script**: `getVideoState`, `speed`, `pip`, `play`, `pause`, `screenshot`, `getKey`, `getPage`

---

## 源码对照

源码位于 `../cat-catch/`，关键文件行数统计：

| 文件 | 行数 | 重要性 |
|------|------|--------|
| `js/background.js` | 936 | ⭐⭐⭐⭐ 核心嗅探引擎 |
| `js/init.js` | 438 | ⭐⭐⭐ 配置初始化 |
| `js/function.js` | 788 | ⭐⭐⭐ 工具函数/模板/send2local |
| `js/popup.js` | 1088 | ⭐⭐⭐ Popup UI |
| `js/content-script.js` | 279 | ⭐⭐ 页面桥接 |
| `js/downloader.js` | 469 | ⭐⭐ 下载管理器 |
| `catch-script/search.js` | 825 | ⭐⭐⭐⭐ 深度搜索 |
| `catch-script/catch.js` | 948 | ⭐⭐⭐ 缓存捕捉 |
| `catch-script/recorder.js` | 368 | ⭐ 视频录制 |
| `catch-script/recorder2.js` | 257 | ⭐ 屏幕录制 |
| `catch-script/webrtc.js` | 320 | ⭐ WebRTC 录制 |

---

## 迁移路线图建议

```
第1步：理解嗅探引擎 (02)
  └─ 理解背景: 拦截 HTTP 请求 → 过滤 → 存储 → 通知
第2步：实现过滤规则 (02 + 08)
  └─ 扩展名/MIME/正则三层过滤 + 大小比较器
第3步：实现消息系统 (06)
  └─ background ↔ popup ↔ content 三层桥梁
第4步：实现弹窗 UI (06)
  └─ 双面板、实时推送、筛选、展开/折叠
第5步：实现下载器 (05)
  └─ 多线程、错误重试、StreamSaver、请求头注入
第6步：实现深度搜索 (03)
  └─ 劫持 XHR/fetch/JSON.parse 等原生 API
第7步：实现缓存捕捉 (04)
  └─ MediaSource addSourceBuffer 代理
第8步：扩展功能 (07)
  └─ 录制、WebRTC、FFmpeg、MQTT、send2local
```

---

> 文档由 opencode 自动分析源码生成。如有疏漏请以实际源码为准。
