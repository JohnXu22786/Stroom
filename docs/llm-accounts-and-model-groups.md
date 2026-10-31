# LLM 账号与模型组使用说明

Stroom 将上游账号、凭据和会话中保存的模型名称分别管理。请在供应商设置中的 **LLM 账号与模型组** 页面进行配置。

## 添加、编辑和删除账号

1. 添加账号并选择连接器和认证方式。
2. 填写账号名称、需要的端点、凭据和上游模型 ID。`streaming`、`vision`、`tools` 等能力字段是显式声明；未填写的能力仍为未知。
3. 保存账号后，把它的上游模型加入模型组，再在聊天或 Task Flow 中选择该模型组。

编辑账号时，凭据栏留空会保留当前安全凭据。删除账号会将其从模型组移除；只有没有其他账号引用该凭据时，Stroom 才删除本地安全存储中的值。对于支持撤销的 OAuth 连接器，删除时会尝试撤销授权；撤销失败不会阻止删除，也不会让上游账号退出登录。

请按连接器支持的方式准备凭据。Gemini Developer API 和 AI Studio OAuth 会打开 Google OAuth 同意页，并要求配置桌面客户端及 Cloud 项目；账号保存成功不代表已通过上游实时验证。状态为 `unknown` 表示 Stroom 没有已验证的结果，路由仍可能尝试该账号；`paused` 和 `needs attention` 账号不会参与路由。

## 模型组和路由

模型组为会话提供稳定的 Stroom 模型身份，并将它映射到一个或多个上游模型 ID。添加账号/模型成员并设置优先级层级后，路由会先尝试最高的可用层级；该层没有可用成员时才会降到下一层。同一层默认按最少使用选择账号，也可设置轮询或余额偏好。回退范围可以限制在同一账号/供应商池，也可以包括当前模型组的其他成员；请求不会静默切换到模型组之外。

账号和模型组都可以设置并发限制，以及五小时、日、周、月窗口。窗口默认按滚动周期计算；日历窗口使用配置的本地时区。余额保留线和使用量上限是两项独立设置。百分比限制需要已知总量。Stroom 会记录实际观察到的请求数或 token；若上游提供余额或重置时间，则会连同来源显示。未知额度始终保持未知，不表示无限额度或保证可用。模型目录中出现某个模型或保存了模型 ID，也不代表上游账号已获得该模型的权限。

## 连接器和额度限制

仓库中的 [v0.6 连接器矩阵](roadmap/v0.6-connector-matrix-and-callsite-audit.md)以 CLIProxyAPI `d318bcc3afb9ea8782862f5e8cdb541afdc9dfa5` 版本的代码为依据，记录连接器行为及尚未进行的实时验证。主要区别如下：

- AI Studio 连接器使用 Google Generative Language API HTTP 接口。API Key 通过 `x-goog-api-key` 发送；受支持的 OAuth 使用 Google Gemini Developer API OAuth、bearer token 和 Cloud 项目归属。它不读取 WebView 页面、Cookie 或浏览器会话。
- 旧版 AI Studio WebView relay 账号会保留以便迁移，但不会再发送请求；编辑账号时请显式改为 API Key 或受支持的 OAuth。
- Kimi 原生账号连接器使用 OAuth。若使用 Kimi API Key，应通过 OpenAI 兼容端点账号配置。
- OAuth 刷新能力由连接器实现决定；通常在请求遇到认证失败时尝试刷新。Devin 使用会话令牌，并刷新账号状态，不交换 refresh token。API Key 账号不会执行 OAuth 刷新。
- 当前实现中，Codex 和 Antigravity 会报告账号额度信号，Devin 会报告账号状态额度。其他连接器可能只提供请求用量，没有查询剩余额度的接口。实时可用性、模型权限和方案限制仍需真实上游账号验证。
- ChatAdapter 和 Task Flow 模型选择器通过协议桥接路由 Claude、Google Generative Language、OpenAI 兼容和其他已接入的原生聊天连接器。连接器的可用模型及媒体能力以其模型目录和协议桥接结果为准。

## 凭据、备份和日志

凭据值通过 `flutter_secure_storage` 保存；普通账号配置中只保留引用。运行支持取决于平台：Linux 需要可用的 Secret Service/libsecret 会话。Web 在安全的 WebCrypto 浏览器环境中使用与来源绑定的存储，因此凭据不能跨站点来源迁移，同来源脚本访问仍然构成风险。本次 M5 没有在真实桌面、移动端或浏览器运行环境中验证安全存储。

配置备份会从导出记录中移除凭据值，但保留非机密的引用元数据。备份不包含平台密钥库；恢复到其他设备或浏览器来源后，请检查账号，并为无法访问的凭据重新输入或建立连接。本地确定性测试覆盖了备份处理；恢复后的上游访问尚未验证。

连接器异常和路由诊断会避免包含凭据或请求内容。`AppLogService` 会原样保存调用方传入的日志消息，不会进行通用机密信息清理；自定义日志和导出日志中不要写入 API Key、token 或敏感提示词。

迁移、备份和恢复详情见[数据安全架构](data-safety-architecture.md)和 [v0.6 发布验收记录](roadmap/v0.6-release-acceptance.md)。
