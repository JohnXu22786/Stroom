# 01 — 架构总览

## 文件布局

```
cat-catch/
├── manifest.json            # Chrome Manifest V3 清单
├── manifest.firefox.json    # Firefox 版清单
├── justfile                 # 构建脚本 (just)
├── CHANGELOG.md             # 更新日志
│
├── js/                      # 核心 JS（Service Worker + Content Script + UI）
│   ├── background.js        # Service Worker，嗅探引擎入口 (936行)
│   ├── init.js              # 全局变量/配置初始化 (438行)
│   ├── function.js          # 工具函数/模板引擎/send2local (788行)
│   ├── content-script.js    # 页面注入层，视频控制/消息桥接 (279行)
│   ├── popup.js             # 弹出窗口 UI 逻辑 (1088行)
│   ├── popup-utils.js       # 资源类型判断/Aria2/MQTT (232行)
│   ├── downloader.js        # 多线程下载器 (469行)
│   ├── m3u8.js              # m3u8 解析器
│   ├── m3u8.downloader.js   # m3u8 下载模块
│   ├── mpd.js               # MPD (DASH) 解析器
│   ├── json.js              # JSON 资源解析器
│   ├── options.js           # 配置页逻辑
│   ├── preview.js           # 预览页逻辑
│   ├── media-control.js     # 媒体控制组件
│   ├── install.js           # 安装页逻辑
│   ├── i18n.js              # 国际化
│   └── firefox.js           # Firefox 兼容
│
├── catch-script/            # 注入到页面 MAIN world 的脚本
│   ├── catch.js             # 缓存捕捉：代理 MediaSource API (948行)
│   ├── search.js            # 深度搜索：劫持 XHR/fetch/JSON (825行)
│   ├── recorder.js          # 视频录制 (368行)
│   ├── recorder2.js         # 屏幕录制 (257行)
│   ├── webrtc.js            # WebRTC 流录制 (320行)
│   └── i18n.js              # 注入脚本的国际化
│
├── lib/                     # 第三方库
│   ├── hls.min.js           # hls.js
│   ├── jquery.min.js        # jQuery
│   ├── mux.min.js           # mux.js (MP4 解封装)
│   ├── mpd-parser.min.js    # DASH MPD 解析器
│   ├── m3u8-decrypt.js      # m3u8 AES 解密
│   ├── StreamSaver.js       # 流式下载
│   ├── base64.js            # Base64 编解码
│   ├── mqtt.min.js          # MQTT 客户端
│   └── jquery.qrcode.min.js # 二维码生成
│
├── css/                     # 样式文件
├── img/                     # 图标
├── _locales/                # 多语言翻译
└── tools/                   # 构建工具脚本
```

## 三层架构

```
┌────────────────────────────────────────────────────────────────┐
│  Layer 1: Service Worker (background.js + init.js + function.js)│
│  权限: 所有 chrome.* API                                       │
│  生命周期: 浏览器事件驱动，5分钟无事件可能被杀死                   │
│  职责: 嗅探引擎、消息路由、配置管理                              │
└──────────────────────────┬─────────────────────────────────────┘
                           │ chrome.runtime.sendMessage / onMessage
                           │ chrome.tabs.sendMessage
┌──────────────────────────▼─────────────────────────────────────┐
│  Layer 2: Content Script (content-script.js)                   │
│  权限: 受限的 DOM 访问，可通信 background                       │
│  运行世界: ISOLATED (与页面隔离)                                │
│  职责: 视频控制、window → extension 消息桥接、HeartBeat          │
└──────────────────────────┬─────────────────────────────────────┘
                           │ window.postMessage
┌──────────────────────────▼─────────────────────────────────────┐
│  Layer 3: Inject Scripts (catch-script/*.js)                   │
│  权限: 完整 DOM + JS 运行时访问                                │
│  运行世界: MAIN (与页面共享)                                    │
│  职责: 劫持原生 API、捕获媒体数据                                │
└────────────────────────────────────────────────────────────────┘
```

## Manifest V3 关键配置

```json
{
  "manifest_version": 3,
  "background": {
    "service_worker": "js/background.js"
  },
  "permissions": [
    "tabs", "webRequest", "downloads", "storage",
    "webNavigation", "alarms", "declarativeNetRequest",
    "scripting", "sidePanel"
  ],
  "host_permissions": ["*://*/*", "<all_urls>"],
  "content_scripts": [{
    "matches": ["https://*/*", "http://*/*"],
    "js": ["js/content-script.js"],
    "run_at": "document_start",
    "all_frames": true
  }]
}
```

关键说明：
- **webRequest** — 使用 `onSendHeaders` 和 `onResponseStarted` 拦截所有请求，读取 URL/Headers/响应类型
- **declarativeNetRequest** — 用于修改请求头（模拟手机 UA、设置 Referer 等），替代被 MV3 废弃的 webRequestBlocking
- **scripting** — 动态注入 `catch-script/*.js` 到页面 MAIN world
- **alarms** — 定时清理冗余数据、持久化缓存
- **sidePanel** — 支持 Chrome 侧边栏模式

## 启动流程

```
Service Worker 激活
  └─ importScripts("/js/function.js", "/js/init.js")
      └─ init.js: InitOptions()
          ├─ chrome.storage.sync.get(G.OptionLists)  → 读取用户配置
          ├─ chrome.storage.session.get({ MediaData }) → 恢复缓存
          ├─ 预编译正则规则 (G.Regex)
          ├─ 转换 Ext/Type 为 Map 类型
          ├─ 注册 webRequest.onSendHeaders 监听
          ├─ 注册 webRequest.onResponseStarted 监听
          ├─ 注册 tabs.onActivated/onUpdated/onRemoved
          └─ G.initSyncComplete = true → G.initLocalComplete = true → 开始工作
```

## 在扩展中复制 Service Worker 保活机制

Chrome MV3 Service Worker 会在 30 秒无事件后休眠，5 分钟后强制终止。猫抓使用两种方法保活：

```js
// 方法1: 监听 webNavigation 事件，空操作保持活跃
chrome.webNavigation.onBeforeNavigate.addListener(function () { return; });
chrome.webNavigation.onHistoryStateUpdated.addListener(function () { return; });

// 方法2: 每个标签页 content-script 通过 runtime.connect 维持长连接
// content-script 端:
var Port = chrome.runtime.connect(chrome.runtime.id, { name: "HeartBeat" });
Port.onDisconnect.addListener(connect); // 断开立即重连

// background 端:
chrome.runtime.onConnect.addListener(function (Port) {
    if (Port.name !== "HeartBeat") return;
    // 250 秒后断开，触发 content-script 重连
    setInterval(function () { Port.disconnect(); }, 250000);
});
```
