# Stroom DSH 消息界面迁移

## 已确认的讨论结果

2026 年 10 月 9 日确定采用 DeepSeek Harness（DSH）的 Web 消息展示代码。Flutter 页面嵌入 Web 消息区；React 是 DSH 原有的网页绘制工具。目标平台为 Android、iOS、Windows、macOS、Linux 和 Web，Linux 支持在本次任务内完成。

替换聊天记录中的消息内容展示，包括 Markdown、代码、推理、多步工具调用和附件入口。输入框、顶部栏、会话管理与其他页面继续使用 Stroom。保留原有内容能力，消息区 UI 可以修改或重新设计，不要求沿用旧 Flutter 气泡样式。推理弹窗及已有全屏预览继续调用 Flutter 原有界面。

回答底部去掉 DSH 的点赞与点踩。复制、保存 Markdown、重试回答、编辑用户消息、查看请求或响应、开发模式 JSON 审查和删除消息必须继续可用；允许调整图标、布局和更多菜单。复制等重复功能合并成一个入口。DSH 其他操作按 Stroom 实际能力接入。

旧版本消息在启动时主动迁移；新消息渲染只读取最新结构。迁移针对数据格式版本，不针对聊天记录的日期。生成中的定期保存和回答结束后的保存必须使用同一消息结构，避免中途退出后留下缺少统一 blocks 的记录。

## 实施方案

聊天记录使用一个 Web 消息区，避免每条消息创建 WebView。Flutter 负责会话、生成、持久化、权限与操作；前端接收当前消息快照和增量更新，并通过消息 ID 请求 Flutter 执行操作。前端资源随应用打包，支持离线展示，不要求运行 DSH 的 Node 服务或替换 Stroom 的 Agent。

复用 DSH 的 Markdown、代码高亮、工具输出基础组件及样式，固定上游源码版本 d743267388641bc76f17c45ce8b4c231aed1d32c。DSH 的会话插件依赖在展示层适配，不复制其运行时。保留 MIT 声明及所分发字体、依赖的许可证。

Stroom 的 Mermaid、HTML 预览、公式、化学公式、换行与下划线等内容能力在新消息区补齐。全屏 HTML、Mermaid、附件、代码和推理查看交给已有 Flutter 界面。模型生成的 HTML 在独立预览环境运行，不获得消息操作桥接接口。

## 工作顺序与验收

1. 准备独立工作区，记录讨论和任务状态。
2. 增加 chat 主动迁移，统一现有助手消息；更新定期保存和其他写入路径。验证纯正文、缺少推理的工具轮、并行工具、保存后重新读取及迁移重复执行。
3. 建立前端与 Flutter 消息桥接，验证会话切换、迟到更新、消息操作和页面重建后的恢复。
4. 接入 DSH 渲染并定制消息 UI，补齐内容扩展、原有按钮和全屏入口。验证未闭合的流式代码块、长回答、公式和多步工具顺序。
5. 接通历史分页、搜索高亮与定位、初始位置、自动跟随、回到底部、主题、字号和键盘焦点。
6. 完成六个平台的承载和资源打包。Linux 纳入插件注册与安装依赖；Web 使用隔离 iframe 嵌入和消息通信。
7. 针对性验证、完整任务差异审查、提交并创建草稿 PR。记录实际完成的验证和仍需设备验证的部分。

## 任务状态

已实现 DSH 消息区、Flutter 操作桥接、chat v2 主动迁移、定期和结束保存、历史分页、搜索定位、主题同步及内容扩展。前端固定使用官方发布包 `@deepseek-ai/dsh-client-ui-primitives@0.2.1-alpha.2`，复用其增量 Markdown、代码高亮、工具折叠行、JSON 树和图标。构建脚本针对该固定版本增加有限的代码块和安全内联标签适配，上游锚点变化时构建失败。

原生端从 Flutter 资源文件加载消息页面，避开 Windows WebView2 的内联 HTML 大小限制；Web 端使用 iframe 和受限定的消息通道。所有脚本、样式和公式字体内嵌于随应用分发的 HTML。MIT 原文与所用依赖声明保存在 `assets/vendor/dsh_message_view/`。

### 开发和平台配置

- 前端源码与锁定依赖：`tools/message_renderer/`。运行 `npm ci`，然后 `npm test` 会重新打包资源并执行行为检查。应用构建直接使用已提交的资源，不需要启动 Node 服务。
- WebView 固定为官方 `flutter_inappwebview 6.2.0-beta.3`，该预发布版本新增 Linux 实现；Linux 要求 WPE WebKit **2.0 API，版本至少 2.40**。Ubuntu 22.04 的 1.0 API 包无法编译此插件，Ubuntu 24.04 官方仓库没有 WPE。Linux CI、发布和夜间构建使用 Debian 13（trixie）官方容器与 `libwpewebkit-2.0-dev`、`libwpebackend-fdo-1.0-dev`、`libepoxy-dev`、`libsecret-1-dev`。预编译 Linux 包的系统基线因此为 Debian 13；没有声称兼容旧 Ubuntu。插件无条件调用的网页主题色 API 到 WPE 2.50 才出现：仅在较旧 WPE 上给这个可选接口返回“无主题色”，消息区继续使用 Flutter 提供的主题；2.50 及更新版本保留原生实现。WPE 动态库、子进程和资源保持使用系统包，不复制不完整的 WebKit 库到应用 bundle。运行前在 Debian 13 安装 `libwpewebkit-2.0-1`、`libwpebackend-fdo-1.0-1`、`libepoxy0`、`libsecret-1-0`（以及应用原有 GTK、mpv、托盘依赖）。其他发行版需要匹配 API 的 WPE 运行库，并在自身环境重新编译。
- 默认使用新的 Web 消息区。`--dart-define=STROOM_NATIVE_MESSAGES=true` 可临时回到原 Flutter 消息显示；数据仍使用 v2。已有 Flutter 气泡组件回归测试通过这个显式构建参数运行，新消息区另有直接测试打包 HTML 的 JS 检查和 Flutter 桥接检查。
- CI 覆盖 Android、iOS、Windows、macOS、Linux 和 Web 六个平台；各平台先构建应用，再运行消息文档与 Flutter 桥接 smoke test。Android 和 iOS 使用模拟器，桌面端使用对应原生 runner，Web 使用 Chromium 驱动集成测试。另有 DSH 前端行为与资源重建一致性检查。

### 已执行的针对性检查

- 原生主动迁移：纯正文、单段推理、空推理轮次、工具顺序、压缩标记、重复执行；既有迁移失败和损坏条目处理。
- Web Worker：迁移后的消息顺序与正文补齐，重复执行，损坏 JSON 返回错误。
- 真正的定期保存：暂停生成跨过 5 秒保存周期，比较中途和结束后的消息块。
- 消息界面：安全换行/下划线、化学公式、流式未闭合 HTML、工具顺序、会话替换、迟到事件拒绝、搜索和更新交错。
- Flutter 桥接：增量发送、会话代际切换、旧操作拒绝；代码操作的源范围、围栏闭合、引用/列表和缩进代码。
- 停止生成：先冻结正文、推理及工具块，保存未完成时仍保留回答；最终结果按消息 ID 合并，避免重复消息或覆盖后续操作。

六个平台的构建与消息桥接由远程 CI 分别验证。模拟器和桌面 smoke test 不等同于实体设备上的完整交互验收；滚动、键盘、文件选择及全屏预览仍需按实际设备做更广泛的手工验收，不能用 JS 或组件测试代替。

- 为兼容 macOS 11 WebKit，补齐 `Array.at` / `Object.hasOwn`，代码高亮使用内嵌 Oniguruma WASM，资源无需联网。旧版 WebKit 的 CSP 需要允许该编译过程；模型内容仍经过 AST 绘制，不能进入脚本或消息操作桥接。

## 范围补充：Intelligent UI 延后

2026-10-18 确认：当前 v0.7 工作继续聚焦于对话消息区迁移与生效；模型在回答中自行生成 Intelligent UI 的提示词、输出协议和 UI 选择逻辑，留待后续单独规划。本迁移中对 HTML 代码围栏的消息内预览属于普通消息内容渲染，不代表已经接入模型生成的 Intelligent UI。

### 后续研究记录

- 实际生成样本来自 Thesys 默认管线：回答模型依据 OpenUI 组件协议同时组织回答和展示形式。对 6 类自然语言问题重复生成、追问和可交互抛射演示共 22 个样本，均通过 OpenUI 解析；本次没有做浏览器截图或控件点击验证。
- CopilotKit 将展示类型选择交给 Jev（文本、表格、图表、示意图、交互图、地图、计算器等 13 类），再让回答模型按选定类型生成。Jev 是后台额外调用，不需要终端用户编写规则；公开 demo 的 BYOK 配置需要 OpenAI 和 Jev 两个密钥。
- 提示词长度是后续设计问题：Thesys 仓库中的生成系统提示词快照约 33,400 字符；CopilotKit 的基础回答提示词约 6,200 字符。CopilotKit 的路由源码是程序代码，不应按源码长度当作提示词长度；其 SVG 与高级可视化说明另有 skills 文档供按需读取。
- 后续可评估让回答模型自行选择展示方式，是否采用按需 skill，以及如何提供渲染工具。CopilotKit 本次没有真实模型输出样本，因此当前不能对两者的生成质量做等量比较。

以上 Intelligent UI 研究不属于 PR #800 的实现范围；后续重新启动时，应另行确定提示词/skill 方案并做真实渲染与交互验证。

### Current work snapshot (2026-10-31)

- The conversation message UI branch is `feat/dsh-message-renderer`, targeting `v0.7`; GitHub PR #800 remains a draft and is not merged.
- PR CI now covers build and message-view smoke tests on Android, iOS, Windows, macOS, Linux, and Web. The current workflow run is being used to verify the six targets; record its final result and any follow-up fixes here before merging PR #800.
