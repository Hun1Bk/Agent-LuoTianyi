# Godot Windows 客户端

- 大目标：新建与现有桌面端功能对齐的 Godot Windows 客户端，完成用户确认的界面改造和安装交付。
- PRD：[Godot-Windows客户端](../需求说明（PRD）/Godot-Windows客户端.md)
- 总体设计：[Godot 客户端总体设计](../../项目说明/项目架构与接口（spec）/Godot客户端总体设计.md)
- interface：[Godot 客户端](../../项目说明/项目架构与接口（spec）/接口文档/client_godot/README.md)
- 总体状态：进行中

## 已完成

### 2026-09-18 基线工程与 Windows 构建

- 交付行为：独立 Godot 4.7.1 工程、版本锁定、headless 检查和 Windows x64 release 导出脚本；保持旧端和 App 入口。
- interface：Godot 客户端「工程与构建入口」。
- 分支：`feat/godot-build-baseline`；SPEC commit：`08fc568`。
- SPEC 自审：核对 PRD、架构、interface，明确用户提供的 4.7.1 与原计划 4.7.2 差异；无服务端接口变化。
- Red：工程/构建配置不适用运行时 Red；用明确失败的非法引擎路径检查代替。
- 验证：`scripts/check.ps1` 导入与启动通过；`scripts/build.ps1` release 导出和独立 EXE headless 启动通过；非法引擎路径返回退出码 1；`git diff --check` 通过。
- 实际引擎：`4.7.1.stable.official.a13da4feb`；同版本 Windows 模板；下载校验值记录在 lock 文件。
- 未验证：真实 GPU 画面、Live2D、业务功能、安装包、Windows 10 和性能均不属于此次完成事实。

### 2026-09-18 真实 Live2D 驱动与导出资源

- 交付行为：gd_cubism v0.9.1 Windows 动态库、完整模型资源、真实模型加载、表情命令、动作及口型控制；保留上游许可及来源。原生插件重建命令复验通过，二进制 SHA-256 与 lock 一致。
- interface：`AvatarDriver`；SPEC `adebd21`，Red `60e71a7`，分支 `feat/godot-avatar-display`。
- Red 证据：实际插件已加载，测试仅因驱动尚未实现加载而失败，退出码 1，`FAIL: complete model loads through AvatarDriver`。
- 验证：驱动契约测试通过；导入、主入口 headless、release 导出和导出 EXE 检查通过。修复打包纹理预检：导出纹理须使用资源存在性而非仅检查原始 PNG。
- GPU 验证：本机 NVIDIA RTX 4070 Laptop、Compatibility/OpenGL，独立导出 EXE 加载真实模型并截图成功，静态透明与遮罩可见检查正常。截图保存在本地 `client_godot/artifacts/avatar.png`。
- 构建检查纠正：GUI 子系统 EXE 不能依赖 PowerShell `$LASTEXITCODE` 或 stdout；现显式等待进程并检查引擎日志及退出码。Godot 官方 release 模板禁止主场景命令行覆盖，模型通过正式启动场景验证。
- 作者自审：核对 SPEC、Red 原因、驱动边界、资源原始来源和日志；未将 headless 冒充 GPU 检查。
- 未验证：Windows 10、集显、长期运行、物理/动作的完整人工验收、音频同步、用户视觉确认和业务接口。

### 2026-09-18 角色构图调整

- 交付行为：滚轮缩放、右键拖动、有限范围构图、相对位置保存与重置；静态背景；最小化暂停角色绘制。
- interface：`AvatarFraming`；SPEC `b94ef3f`，Red `8bec522`，分支 `feat/godot-avatar-framing`。
- Red：公开构图入口未实现时比例、位移及保存契约失败；未使用环境或语法错误作为 Red。
- 验证：`check.ps1` 导入、启动、真实角色及构图契约全部通过；`build.ps1` 导出和独立 EXE 启动通过；本机 GPU 导出截图 `artifacts/framing.png` 确认真实角色与静态背景正常显示。
- 作者自审：检查缩放/位移边界、配置失败保留状态、数据路径和左右键分工；未改变旧端及服务端。
- 未验证：真实鼠标完整操作、多档 DPI、双屏移动与集显性能；未将模型单页作为最终视觉样板确认。

### 2026-09-18 可运行离线聊天界面样板

- 交付行为：真实 Live2D 左侧角色与右侧聊天，默认 45:55 可保存分隔；浅色气泡、头像、可选择中文正文、输入及模拟发送；单张图片选择/粘贴预览入口、缩放和显式发送；五种演示场景；真实表情及无声音的模拟口型。
- interface：`OfflinePreview`；SPEC `1865609`，Red `518abff`，分支 `feat/godot-chat-preview`。
- SPEC 自审：沿用用户已确认的样板范围，UI 使用离线控制器与角色驱动；没有新增服务端协议，也未展开账户、偏好或动态页面。
- Red：公开控制器缺少消息追加、唯一 ID 和状态结束时测试退出 1；共 10 条行为断言失败，未使用环境失败作为证据。
- Green 验证：`check.ps1` 导入、启动、角色、构图、离线消息和主场景键盘输入回归全部通过；Enter、Shift+Enter、空白输入及可见消息经过实际 Godot 输入事件验证。输入回归是补充验证，未伪造单独 Red。
- 导出验证：`build.ps1` Windows release 导出、独立 EXE 启动通过，随包复制模型/引擎/插件许可及样板说明；本机 GPU 分别截取 1200×800、960×640、断网及加载失败画面，中文可读、角色/背景正常；禁用整体窗口内容缩放以保持小窗口文字尺寸。
- 作者自审：检查场景重置后的旧回调隔离、读副本、失败保留输入、图片刷新、浮层焦点、无网络调用及许可分发；修正 RichTextLabel 默认文字颜色和 headless 不支持 IME 查询的问题。
- 本地交付：`client_godot/dist/AgentLuo.exe`；完整目录压缩包 `client_godot/artifacts/AgentLuo-visual-preview-win64.zip`；截图 `artifacts/chat-preview.png`。未合并、未发布。
- 未验证：用户视觉确认、真实 Windows IME/剪贴板/鼠标操作、多档 DPI、Windows 10、集显性能、真实服务与流式音频；本样板没有实际声音，不表示完整客户端或安装程序已经完成。

### 2026-09-18 用户确认视觉样板

- 用户反馈“暂且满意，完善其他功能”，确认当前样板可作为后续业务集成的视觉基线。
- 确认对象：`6524fa2` 的真实模型与离线聊天样板；不视为业务、声音、性能或安装验收通过。

### 2026-09-18 Windows 原生凭据保护

- 交付行为：WindowsSecurity GDExtension 提供 CNG RSA-OAEP/SHA256（MGF1 SHA256）及当前 Windows 用户 DPAPI 字节保护，错误不包含秘密，无明文降级。
- interface：`WindowsSecurity`；SPEC `773a2e0`、Red `32fddc6`，分支 `feat/godot-windows-security`。
- Red：真实扩展加载成功，DPAPI 保护、无效公钥错误码和五组 RSA 加密断言因占位实现失败；退出 1，没有将编译/路径问题算作 Red。
- 验证：`run_security_interop.py` 使用临时密钥，隔离执行仓库 account.py 中原样的密钥生成与解密函数；ASCII、中文/emoji、2048 位密钥的 190 字节边界和 OAEP 随机性通过。DPAPI 往返、不同 scope、密文篡改和上限检查通过。
- 回归：`check.ps1` 全部通过；`build.ps1` release 导出和独立 EXE 启动通过。DLL SHA256 已写入依赖锁。
- 作者自审：检查 Windows 句柄释放、UTF-8 临时明文清零、SPKI RSA 类型/位数校验、无网络/文件副作用。只读独立核验未发现具体实现缺陷，指出跨 Windows 用户测试未覆盖；同用户 scope 测试不等同跨用户验收。
- 构建：MSVC 对中文绝对源码路径的响应文件存在编码问题，使用同一锁定源码的本地目录联接构建通过；目录联接与对象文件不导出。
- 未验证：跨 Windows 用户 DPAPI、干净 Windows 10 机器和完整服务端 HTTP 登录；当前切片没有修改旧端或服务端实现。

### 2026-09-18 异步账户 HTTP 接口

- 交付行为：AccountApi 通过既有 /auth 路由完成密码登录、注册、重置和自动登录，返回校验后的结果；地址规范化、请求取消、超时与并发拒绝，禁止重定向，不记录请求秘密。
- interface：`AccountApi`；SPEC `334c8ee`、Red `3dcb6f2`，分支 `feat/godot-account-api`。
- Red：本地随机端口服务已就绪，17 条目标行为因占位实现未提供账户请求而失败，退出 1。
- 验证：`run_account_tests.py` 使用真实 Godot HTTPRequest 和 CNG 加密，四种请求字段、Python 解密、401/503、公钥失败、JSON 错误结构、空 token、超时、取消和取消后的迟到 POST 成功均通过；未知请求字段不透传。
- 回归：`check.ps1` 现有角色、构图、样板和凭据测试通过；`git diff --check` 通过。
- 作者自审：核对当前服务端字段、响应数据最小化、TLS 默认验证、无重定向、请求生命周期及旧回调隔离。模拟测试不等同真实部署验收。
- 未验证：开发服务器实际登录、TLS 部署证书与端到端账户页面；本切片不保存 token，也不建立聊天连接。

### 2026-09-18 自动登录与账户生命周期

- 交付行为：CredentialStore 按规范化服务器/账户隔离 DPAPI token，以临时文件原子替换；AccountSession 发布已校验会话、恢复自动登录、保存旋转 token、明确 401 清理和退出清理。普通设置不保存 token。
- interface：`CredentialStore`、`AccountSession`；SPEC `e85f027`、Red `6e7c7fb`，分支 `feat/godot-account-lifecycle`。
- Red：真实原生扩展与本地 HTTP 服务正常，10 项持久化/会话行为因占位实现失败。
- 验证：`check_accounts.ps1` 原生互操作、HTTP 与会话全部通过；跨服务器/账户读取隔离、重新实例化恢复、旋转 token 保存、401 清理、退出清空、存储失败仍允许在线登录且禁用自动登录均有公开入口断言。
- 作者自审：核对 settings 与 token 分离、只保存 login_token、无明文降级、深拷贝会话、错误报告及临时文件清理；失败写入测试使用独立临时路径，不碰用户配置。
- 未验证：真实部署、跨 Windows 用户、系统掉电时文件系统持久性和实际账户 UI；该切片没有建立聊天连接。

### 2026-09-19 真实账户页面与应用入口

- 交付行为：默认入口为真实登录/注册/邀请码重置表单，支持自定义服务器和自动登录；错误保留输入、确认密码校验、成功清空敏感字段、取消和退出。离线样板改用开发参数 --preview，与实际账户隔离。
- interface：`AccountView 与应用账户入口`；SPEC `439cda2`、Red `cb56b56`，分支 `feat/godot-account-ui`。
- Red：可加载的空视图未提供表单，公开可见控件断言失败；未用导入问题伪造 Red。
- 验证：真实 AccountSession + 本地 HTTP 服务的账户视图测试通过，检查错误密码保留草稿、密码确认拒绝、注册返回登录、清空密码和退出；`check.ps1`、`check_accounts.ps1` 全通过。release 导出与独立启动通过，GPU 截图确认账户页和真实角色正常显示。
- 作者自审：核对表单模式、忙碌时取消、错误提示、凭据保护注入与无模拟登录；修正 LineEdit 字体/占位文字色。headless 和截图入口不恢复真实账户连接。
- 未验证：真实开发服务器登录、Windows IME 和多档 DPI；账户页登录成功不表示聊天与媒体功能已完成。
