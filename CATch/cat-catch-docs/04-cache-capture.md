# 04 — 缓存捕捉 (catch.js)

## 文件位置

`catch-script/catch.js` (948行)

## 原理

对于使用 **MediaSource API**（MSE）进行流式播放的视频（如 HLS.js 播放的 m3u8、DASH.js 播放的 mpd），通过代理 `MediaSource` 的 `addSourceBuffer` 和 `endOfStream` 方法，在数据进入解码器之前截获原始编码数据。

```
视频源 → fetch → ArrayBuffer → appendBuffer(proxy) → SourceBuffer → 解码 → 播放
                                    │
                                    └─ 拷贝一份到 catchMedia[] → 下载
```

## 核心类结构

```js
class CatCatcher {
    constructor() {
        this.enable = true;
        this.catchMedia = [];    // [{ mimeType, bufferList: [ArrayBuffer, ...] }]
        this.mediaSize = 0;      // 已捕获的字节数
        this.isComplete = false; // endOfStream 是否已调用

        this.setupIframeProcessing();    // 移除 iframe sandbox 属性
        this.initTrustedTypes();         // 初始化 Trusted Types 策略
        this.createUI();                 // 在 Shadow DOM 中创建控制面板
        this.proxyMediaSourceMethods();  // 核心: 代理 MediaSource API
    }
}
```

## 核心代理逻辑

### 1. 代理 addSourceBuffer

```js
proxyMediaSourceMethods() {
    window.MediaSource.prototype.addSourceBuffer = new Proxy(
        window.MediaSource.prototype.addSourceBuffer, {
        apply: (target, thisArg, argumentsList) => {
            // 正常调用原始方法获取 SourceBuffer 实例
            const result = Reflect.apply(target, thisArg, argumentsList);

            // 创建捕获条目
            this.catchMedia.push({
                mimeType: argumentsList[0],     // 如 "video/mp4;codecs=avc1.64001e"
                bufferList: []
            });
            const index = this.catchMedia.length - 1;

            // 代理返回的 SourceBuffer 的 appendBuffer 方法
            result.appendBuffer = new Proxy(result.appendBuffer, {
                apply: (target, thisArg, argumentsList) => {
                    // 先正常调用，不影响播放
                    Reflect.apply(target, thisArg, argumentsList);

                    if (this.enable && argumentsList[0]) {
                        this.mediaSize += argumentsList[0].byteLength || 0;

                        // 每 1GB 自动保存一次
                        if (this.mediaSize >= 1*1024*1024*1024
                            && localStorage.getItem("CatCatchCatch_save1GB") == "checked") {
                            this.catchDownload();
                            this.clearCache();
                        }

                        // 累加原始数据
                        this.catchMedia[index].bufferList.push(argumentsList[0]);
                    }
                }
            });
            return result;
        }
    });
}
```

### 2. 代理 endOfStream

```js
window.MediaSource.prototype.endOfStream = new Proxy(
    window.MediaSource.prototype.endOfStream, {
    apply: (target, thisArg, argumentsList) => {
        Reflect.apply(target, thisArg, argumentsList);
        if (this.enable) {
            this.isComplete = true;
            // 自动下载模式
            if (localStorage.getItem("CatCatchCatch_autoDown") == "checked") {
                setTimeout(() => this.catchDownload(), 500);
            }
        }
    }
});
```

## 下载处理

```js
catchDownload() {
    if (this.catchMedia.length == 0) {
        alert("没抓到有效数据");
        return;
    }

    // 检查是否使用 FFmpeg 合并
    let downloadWithFFmpeg = this.catchMedia.length >= 2
        && localStorage.getItem("CatCatchCatch_ffmpeg") == "checked";

    // 头部检查：检测 MP4 ftyp / WebM 头部
    for (let key in this.catchMedia) {
        let lastHeaderIndex = -1;
        for (let i = 0; i < this.catchMedia[key].bufferList.length; i++) {
            const data = new Uint8Array(this.catchMedia[key].bufferList[i]);
            // MP4 头部: ftyp (0x66 0x74 0x79 0x70)
            if (data[4] === 0x66 && data[5] === 0x74
                && data[6] === 0x79 && data[7] === 0x70) {
                lastHeaderIndex = i;
            }
            // WebM 头部: 1A 45 DF A3
            else if (data[0] === 0x1A && data[1] === 0x45
                  && data[2] === 0xDF && data[3] === 0xA3) {
                lastHeaderIndex = i;
            }
        }
        // 清理多余的头部数据
        if (lastHeaderIndex > 0) {
            this.catchMedia[key].bufferList.splice(0, lastHeaderIndex);
        }
    }

    downloadWithFFmpeg ? this.downloadWithFFmpeg() : this.downloadDirect();
}

// 方式A: 直接 Blob 下载
downloadDirect() {
    for (let item of this.catchMedia) {
        const mime = item.mimeType.split(';')[0] || 'video/mp4';
        const fileBlob = new Blob(item.bufferList, { type: mime });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(fileBlob);
        a.download = `${document.title}.mp4`;
        a.click();
    }
}

// 方式B: FFmpeg 合并
downloadWithFFmpeg() {
    const media = [];
    for (let item of this.catchMedia) {
        const mime = item.mimeType.split(';')[0] || 'video/mp4';
        const fileBlob = new Blob(item.bufferList, { type: mime });
        media.push({ data: URL.createObjectURL(fileBlob), type: mime.split('/')[0] });
    }
    window.postMessage({
        action: "catCatchFFmpeg",
        use: "catchMerge",
        files: media,
        title: document.title
    });
}
```

## UI 控制面板

使用 **Shadow DOM (closed mode)** 隔离样式：

```js
createShadowRoot() {
    const getPristineAttachShadow = () => {
        // 从 iframe 中获取原生的 attachShadow 方法
        // 确保页面没有劫持 Element.prototype.attachShadow
        const iframe = document.createElement('iframe');
        document.body.appendChild(iframe);
        const pristineMethod = iframe.contentDocument.createElement('div').attachShadow;
        iframe.remove();
        return pristineMethod || Element.prototype.attachShadow;
    };
    const executor = getPristineAttachShadow().bind(element);
    const shadowRoot = executor({ mode: 'closed' });
    shadowRoot.appendChild(this.catCatch);
    document.getElementsByTagName('html')[0].appendChild(divShadow);
}
```

面板包含的功能：
- 捕获开关和状态显示
- 下载/清理按钮
- 自动下载、FFmpeg 合并、1GB 自动保存等复选框
- CSS 选择器和正则表达式提取文件名
- 从缓冲末尾自动跳转播放

## 迁移要点

| 概念 | 说明 |
|------|------|
| MediaSource 代理 | `addSourceBuffer` 的返回值和 `appendBuffer` 的参数都需要代理，用 `Proxy` 的 `apply` trap |
| 数据完整性 | 必须先 `Reflect.apply` 调用原始方法，再处理拷贝 |
| 头部清理 | MP4 需要以 ftyp box 开头，`catch.js` 通过二进制标记位识别 |
| Shadow DOM | 使用 closed mode + 原生方法获取，防止页面样式污染或 JS 篡改 |
| Trusted Types | 如果页面启用了 Trusted Types 策略，需要先注册自定义策略 |
