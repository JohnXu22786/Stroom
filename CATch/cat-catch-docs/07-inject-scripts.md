# 07 — 注入脚本 (recorder / recorder2 / webrtc)

## 文件位置

| 文件 | 行数 | 功能 |
|------|------|------|
| `catch-script/catch.js` | 948 | 缓存捕捉（见第4章） |
| `catch-script/search.js` | 825 | 深度搜索（见第3章） |
| `catch-script/recorder.js` | 368 | 视频元素录制 |
| `catch-script/recorder2.js` | 257 | 屏幕录制（画中画模式） |
| `catch-script/webrtc.js` | 320 | WebRTC 流录制 |
| `catch-script/i18n.js` | - | 注入脚本的国际化翻译 |

## 通用模式

所有注入脚本都遵循相同的模式：

```js
(function () {
    // 1. 防重复注入
    if (document.getElementById("catCatchRecorder")) return;

    // 2. i18n 语言检测
    let language = navigator.language.replace("-", "_");
    if (window.CatCatchI18n) {
        if (!window.CatCatchI18n.languages.includes(language)) {
            language = language.split("_")[0];
            if (!window.CatCatchI18n.languages.includes(language)) language = "en";
        }
    }

    // 3. 创建 Shadow DOM (closed mode) 隔离样式
    const divShadow = document.createElement('div');
    const shadowRoot = divShadow.attachShadow({ mode: 'closed' });
    shadowRoot.appendChild(uiElement);
    document.getElementsByTagName('html')[0].appendChild(divShadow);

    // 4. 拖拽面板事件
    let x, y;
    uiElement.addEventListener('mousedown', function (event) {
        x = event.pageX - uiElement.offsetLeft;
        y = event.pageY - uiElement.offsetTop;
        document.addEventListener('mousemove', move);
        document.addEventListener('mouseup', function () {
            document.removeEventListener('mousemove', move);
        });
    });

    // 5. 清理 iframe sandbox 属性
    setupIframeProcessing(); // 解决跨域 iframe 脚本无法注入的问题
})();
```

## recorder.js — 视频元素录制

基于 `HTMLMediaElement.captureStream()` API 录制页面上的 `<video>` 元素。

```js
// 核心流程:
// 1. 读取页面上所有 video/audio 元素
function getVideo() {
    videoList = [];
    document.querySelectorAll("video, audio").forEach(function (video, index) {
        if (video.currentSrc) {
            videoList.push(video);
            // 添加到下拉选择框
        }
    });
}

// 2. 开始录制
CatCatch.querySelector("#start").addEventListener('click', function () {
    const index = $videoList.value;
    const captureStream = getCaptureStreamMethod(videoList[index]);
    const stream = captureStream(frameRate);

    // Firefox 修补: captureStream 没有音频，使用 Web Audio API
    if (isMozCaptureStream) {
        const audioCtx = new AudioContext();
        const source = audioCtx.createMediaStreamSource(stream);
        source.connect(audioCtx.destination);
    }

    // 3. MediaRecorder 录制
    recorder = new MediaRecorder(stream, {
        mimeType: option.mimeType,
        audioBitsPerSecond,
        videoBitsPerSecond
    });
    recorder.ondataavailable = function (event) {
        if (useFFmpeg) {
            // 发送到在线 FFmpeg 转码
            window.postMessage({ action: "catCatchFFmpeg", use: "transcode", files: [{ data: blob }] });
        } else {
            // 直接下载
            const a = document.createElement('a');
            a.href = URL.createObjectURL(event.data);
            a.download = document.title;
            a.click();
        }
    };
    recorder.start();

    // 4. 每1小时自动保存
    autoSave1Timer = setInterval(function () {
        recorder.stop();
        recorder.start();
    }, 3600000);
});
```

## recorder2.js — 屏幕录制

使用 `getDisplayMedia()` API 进行屏幕录制，带有画中画裁剪区域。

```js
// 核心 UI: 一个可拖拽、可调整大小的裁剪框
// 使用 CSS outline 动画指示录制状态
cat.innerHTML = `
    <div id="catCatchRecorderinnerCropArea"></div>  <!-- 裁剪区域 -->
    <div id="catCatchRecorderHeader">
        <select id="videoBits">...</select>
        <select id="audioBits">...</select>
        <div id="catCatchRecorderStart">开始录制</div>
        <div id="catCatchRecorderTitle">拖动窗口</div>
        <div id="catCatchRecorderClose">关闭</div>
    </div>
`;

async function startRecording() {
    // 使用 CropTarget 精确裁剪录制区域
    const cropTarget = await CropTarget.fromElement(catCatchRecorderinnerCropArea);

    const stream = await navigator.mediaDevices.getDisplayMedia({
        preferCurrentTab: true,
        video: { cursor: "never" },
        audio: { sampleRate: 48000, sampleSize: 16, channelCount: 2 }
    });

    const [track] = stream.getVideoTracks();
    await track.cropTo(cropTarget); // 只录制裁剪框内的内容

    recorder = new MediaRecorder(stream, option);
    recorder.ondataavailable = function (e) { buffer.push(e.data); };
    recorder.onstop = function () {
        const fileBlob = new Blob(buffer, { type: option });
        // 下载为 webm
        const a = document.createElement('a');
        a.href = URL.createObjectURL(fileBlob);
        a.download = `${document.title}.webm`;
        a.click();
    };
    recorder.start();
}
```

## webrtc.js — WebRTC 流录制

劫持 `RTCPeerConnection` 捕获 WebRTC 音视频流。

```js
// 核心: 代理 RTCPeerConnection 构造函数
window.RTCPeerConnection = new Proxy(window.RTCPeerConnection, {
    construct(target, args) {
        const pc = new target(...args);

        // 监听 track 事件获取音视频流
        pc.addEventListener('track', (event) => {
            const track = event.track;
            if (track.kind === 'video' || track.kind === 'audio') {
                // 添加到下拉选择列表
                tracks[track.kind].push(track);
            }
        });

        // 监听 ICE 断开，自动停止录制
        pc.addEventListener('iceconnectionstatechange', (event) => {
            if (pc.iceConnectionState === 'disconnected' && recorder?.state === 'recording') {
                recorder.stop();
            }
        });
        return pc;
    }
});

// 用户点击"开始录制" → 从捕获的 tracks 中选择 → MediaRecorder
CatCatch.querySelector("#start").addEventListener('click', function () {
    const streamTrack = [];
    if (videoTrack !== -1) streamTrack.push(tracks.video[videoTrack]);
    if (audioTrack !== -1) streamTrack.push(tracks.audio[audioTrack]);

    const mediaStream = new MediaStream(streamTrack);
    recorder = new MediaRecorder(mediaStream, option);
    recorder.ondataavailable = event => chunks.push(event.data);
    recorder.onstop = () => download(chunks);
    recorder.start(60000); // 每60秒一个 chunk
});
```

## 注入触发机制

```js
// background.js 中 onCommitted 事件触发注入
chrome.webNavigation.onCommitted.addListener(function (details) {
    // 遍历 scriptList, 对开启了该脚本的标签注入
    G.scriptList.forEach(function (item, script) {
        if (!item.tabId.has(details.tabId) || !item.allFrames) return;

        const files = [`catch-script/${script}`];
        item.i18n && files.unshift("catch-script/i18n.js");
        chrome.scripting.executeScript({
            target: { tabId: details.tabId, frameIds: [details.frameId] },
            files: files,
            injectImmediately: true,
            world: item.world  // "MAIN" 或 "ISOLATED"
        });
    });
});
```

## 脚本配置汇总

```js
G.scriptList.set("search.js", {
    key: "search", world: "MAIN",   refresh: true,  allFrames: true,  i18n: false
});
G.scriptList.set("catch.js", {
    key: "catch", world: "MAIN",    refresh: true,  allFrames: true,  i18n: true
});
G.scriptList.set("recorder.js", {
    key: "recorder", world: "MAIN", refresh: false, allFrames: true,  i18n: true
});
G.scriptList.set("recorder2.js", {
    key: "recorder2", world: "ISOLATED", refresh: false, allFrames: false, i18n: true
});
G.scriptList.set("webrtc.js", {
    key: "webrtc", world: "MAIN",   refresh: true,  allFrames: true,  i18n: true
});
```

- `refresh: true` — 开启/关闭需要刷新页面
- `world: "MAIN"` — 可以劫持页面 JS 环境
- `world: "ISOLATED"` — 使用 content_script 的隔离环境
- `i18n: true` — 需要预先注入 `catch-script/i18n.js` 提供翻译

## 迁移要点

| 脚本 | 核心 API | 适用场景 |
|------|----------|---------|
| catch.js | `MediaSource.addSourceBuffer` Proxy | 使用 MSE 播放的 HLS/DASH 视频 |
| search.js | 劫持 XHR/fetch/JSON.parse/btoa/... | 任何 JS 加载的视频资源 |
| recorder.js | `HTMLVideoElement.captureStream()` + `MediaRecorder` | 页面中现有的 video 元素 |
| recorder2.js | `getDisplayMedia()` + `CropTarget` | 需要截屏录制的场景 |
| webrtc.js | `RTCPeerConnection` Proxy | WebRTC 视频通话/直播流 |

**Shadow DOM 注入**是所有脚本的通用最佳实践 — 使用 closed mode 避免 CSS 冲突。
