# Godot Windows 客户端

### 2026-09-19 agentluo 版本化构建

- 交付行为：release.json 单一版本来源、运行窗口标题及版本目录 agentluo-0.1.0，程序 agentluo.exe；旧包和用户数据目录保留。
- SPEC defa465，自审确认只更新已授权需求与当前构建契约；Red 不适用（构建配置与命名切片），未伪造运行失败。
- 验证：build.ps1 使用锁定 4.7.1 引擎完成 import、release 导出及独立启动；输出 dist/agentluo-0.1.0/agentluo.exe。作者自审核对版本格式、提前拒绝覆盖 ZIP 与固定用户目录。
- 未验证：最终 ZIP 及新版全部业务尚未作为本条验收；此次未打包为最终交付，不代表 0.1.0 已完成。分支 feat/agentluo-0.1.0。

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
### 2026-09-19 可靠消息投递队列

- 交付行为：稳定消息 ID、顺序投递、成功/负 ACK、超时与断线退避、最多 8 次重试和 240 秒龄期；瞬时事件独立发送，停止释放旧账户队列。
- interface：`ReliableOutbox`；SPEC `d67f829`、Red `12bab74`，分支 `feat/godot-message-outbox`。
- Red：可运行占位实现缺少投递行为，25 项公开行为断言失败，退出 1；没有环境/解析错误。
- 验证：`check.ps1` 全部通过，包含可控时钟队列测试；覆盖原 ID 重试、迟到/重复 ACK、终止 NACK、容量与包大小、跨龄期拒绝、断线及停止。独立核验指出图片取消事件名和迟到确认边界，新增测试先失败后修正通过。
- 作者自审：核对 SPEC、旧端事件名及退避策略、payload 深拷贝和终态释放；未改动旧端或服务端。
- 未验证：实际 WebSocket 连接及聊天 UI；本切片为投递队列，不表示真实聊天已接入。
### 2026-09-19 WebSocket 认证、心跳与重连

- 交付行为：真实 WebSocketPeer 连接路径前缀下的 chat_ws，以 message_token/user_auth/negative_ack_v1 鉴权；auth_ok 后心跳及业务投递；断线退避、超时、明确拒绝凭据停止重连、退出清理。
- interface：`WebSocketTransport`；SPEC `02ea78c`、补充 `048dbf4`，Red `d1a7ea9`、`9864666`；分支 `feat/godot-websocket-transport`。
- Red：本地服务正常，占位实现 19 项行为失败；补充认证关闭码 1008 用例先失败，修复后通过。测试服务普通拒绝保持连接与现有服务一致，单测另覆盖尝试耗尽立即关闭。
- 验证：`check_network.ps1` 使用真实 socket 与 loopback websockets 16.0 fixture，鉴权字段、心跳、ACK、回复、同 ID 重连、同凭据拒绝和新 token 恢复、认证超时、无效 JSON 全通过；`check.ps1` 全通过。
- 作者自审：核对 URL/TLS、队列资源、收包数量与字节限制、不输出原始秘密。发现 Godot 对立即关闭时最终帧的保留存在边界，认证关闭码 1008 单独终止，不依赖最后一帧错误文本。
- 未验证：真实开发服务、TLS 部署、复杂代理网络；当前尚未接入正式聊天界面。
### 2026-09-19 正式文字聊天与账户入口集成

- 交付行为：登录后进入真实文字聊天；发送状态由 ACK 更新，重连期间可排队，无法确认送达明确提示；同 UUID 分片聚合、回复与表情顺序、思考状态、隐藏/临时回复、语音错误保留文字。退出清理连接、队列和会话，返回账户页。
- interface：`ChatSession 与 ChatView`；SPEC `1659b9a`，Red `f7a95ee`，补充回归 Red `3e86dfc`、`745182d`；分支 `feat/godot-text-chat`。
- Red：可运行占位控制器/视图的 8 项真实聊天行为失败；后续复现同帧重启残留旧气泡和重复分片撤销终止状态，修复后通过。
- 验证：`check.ps1`、`check_network.ps1`、`check_accounts.ps1` 全部通过；真实输入事件经 ChatView/ChatSession/WebSocketPeer 到 loopback 服务后收到回复，验证发送确认、正文保留、隐藏消息、表情排序和退出清理。共享 `contracts/chat/reply_events.json` 同时由旧 Python 客户端实际解析器与 Godot 网络链路消费。
- 导出：`build.ps1` Windows release 导出和独立 EXE headless 启动通过，产物 `client_godot/dist/AgentLuo.exe`，随包说明明确正式功能与离线演示差别；旧客户端和既有样板压缩包保留。
- 作者自审：核对消息快照、重复终止、更新原气泡、延迟布局时的滚动、账户退出及分隔比例；未混入 project.godot 的原有编辑器修改。独立聊天核验代理因服务不可用而中止，没有独立审核结论；作者自审不能替代他人审核。
- 未验证：真实开发服务器、完整登录到聊天的部署联调、Windows 10、集显性能、多档 DPI 和系统 IME；当前正式聊天没有图片、历史、流式声音或回放，本次不是全功能替换验收或安装程序交付。
### 2026-09-19 紧凑账户窗口与旧端默认服务器

- 交付行为：未登录只显示 660×800 账户窗口，最小 480×640；成功登录展开角色/聊天，首次 1200×800，最小 960×640；失败和等待不展开，退出收起并释放角色绘制资源，重新登录恢复本次运行的普通窗口尺寸。离线样板保持原宽窗口。
- 默认地址：沿用 client/config/config.json release_config.base_url 的 https://www-api.u3493359.nyat.app:11664；有效自定义地址优先，空/坏配置回退且不自动登录，不读取旧端凭据。
- interface：账户窗口展开与默认服务器；SPEC `9947683`、Red `13d2e80`，分支 `feat/godot-compact-login`。
- Red：真实账户服务和视图正常运行，旧行为因默认地址为空、窗口未收起、退出后角色仍存在等断言失败，无环境/解析错误。
- 验证：check.ps1、check_accounts.ps1、check_network.ps1 全通过；新增应用测试以真实 AccountSession/AccountApi 和可见按钮验证初始、失败、成功、退出和地址恢复。headless 不支持原生窗口模式的尺寸恢复断言明确跳过，随后 --gpu 在本机 RTX 4070 Laptop 原生窗口执行相同测试全部通过、无跳过。
- 导出：build.ps1 release 导出与独立 EXE 启动通过；导出 EXE 截图 artifacts/compact-login.png，确认 660×800 账户页、无角色区、默认地址完整显示。截图模式没有自动登录或访问默认服务器。
- 作者自审：检查状态切换、角色生命周期、原生窗口尺寸、屏幕边界、自定义地址优先及无默认服务器探测。project.godot 仅提交本次两项宽度变更，保留原有编辑器改动；无远程合并/发布。
- 未验证：默认服务器实际登录、多屏/多档 DPI、Windows 10；本次截图和原生窗口测试不替代这些验收。
### 2026-09-19 客户端音频接收诊断日志

- 交付行为：应用启动、连接状态、回复音频是否存在/编码长度/终止标志及系统错误写入 user://logs/client.jsonl；最多三份轮换日志，聊天区提供打开日志入口。
- interface：ClientLog；SPEC d82ae42、Red 3397382；分支 feat/godot-audio-diagnostics。
- 验证：日志白名单、哈希关联 ID、轮换、不可写路径返回错误通过；check.ps1 和 check_network.ps1 通过，真实 loopback 回复产生接收日志，日志不含合成 token 或消息正文。
- 作者自审：未知字段丢弃、逐条 flush、有界文件、测试目录隔离；记录仅证明接收，当前切片不代表音频已播放。
- 未验证：真实服务器音频、实际声音输出；日志没有上传功能。

### 2026-09-19 原生增量 WAV/PCM 解码

- 交付行为：PcmStreamDecoder 接收跨片 WAV 头及连续 PCM，支持服务端未知 data 长度、常用整数/浮点位深及单/双声道；批量返回立体声帧与按播放帧查询的 RMS，错误释放缓冲。
- interface：PcmStreamDecoder；SPEC 156d497、Red b11c6a5、边界回归 Red 627415a；分支 feat/godot-pcm-decoder。
- 验证：check.ps1 全通过；原有 Python RSA 解密互操作通过；8 MiB 输入、1 MiB 头、128 MiB 未读帧及 30 分钟时长边界有执行断言。独立只读核验发现 data 头漏计 8 字节，回归先失败，修正后通过。
- 作者自审：核对完整 extensible GUID、半帧、非有限样本、辅助 chunk、已知长度尾部及错误粘性；DLL 已重建并更新锁定 SHA256。
- 未验证：本切片只验证真实原生解码，不代表扬声器输出、真实服务或口型同步已验收。

### 2026-09-19 回复语音实际播放与诊断闭环

- 修复根因：ChatSession 原先只处理文字/表情，没有把 payload.audio 接入播放器。现通过 ReplyAudio 和原生解码驱动 AudioStreamGenerator，自动播放，按实际播放结束推进文本/表情/下一句；口型按消耗帧查询 RMS，结束恢复基础口型。
- 交付行为：音量调节并保存、停止当前语音、隐藏回复声音、音频错误保留文字、断线/退出清理；接收/格式/解码/开始/结束/错误日志与打开日志入口。没有写入音频缓存或新增回放按钮。
- interface：ReplyAudio、ChatSession；SPEC f3e6a51、4ffabce；Red 9b66997、87d4464，边界 Red 011c271；分支 feat/godot-streaming-playback。原生解码 Green d072d33，诊断日志 Green 368cec7。
- 验证：check.ps1、check_network.ps1 通过；账户全套回归通过，更新后的应用窗口/音量测试又在本机原生 GPU 窗口通过。真实 loopback WebSocket 验证跨片 WAV、先缓存后播放、隐藏音频、停止后最终文字、错误及断线；AudioEffectCapture 测得非零输出和静音效果。
- 原生输出验证：本机 WASAPI 激活双声道 192000 Hz 输出，Godot 报告 10ms 缓冲延迟，test_reply_audio.gd 通过；这不是人工听感结论。build.ps1 release 导出/独立 EXE 启动通过，随包 DLL SHA256 与 lock 一致。
- 导出资源验证：官方 release EXE 忽略外部 --script，已识别且未将其普通启动冒充测试；用同版本标准引擎加载实际导出的 AgentLuo.pck，并在同目录放置本次随包 DLL，WASAPI 播放测试通过，记录 artifacts/export-pack-audio-verified.log。
- 作者自审与独立核验：修正重复终止、容量拒绝后重复 UUID、停止覆盖错误码和越界音量配置；可控时钟验证 60 秒无续片超时，跨 UUID 累计缓冲及 16 个待处理回复上限有断言。中途停止导致提前丢弃最终文字的疑点经真实网络测试未复现，确认 STOPPED 完成信号等待终止包。未改动旧端或服务端，保留 project.godot 既有编辑器修改。
- 未验证：真实部署的 TTS/唱歌联调、人工听感、口型实测偏差、30 分钟运行、Windows 10 与集显性能；未合并、未正式发布，也不是安装程序或全功能替换验收。

### 2026-09-19 主题蓝与正式聊天布局

- 交付行为：#66CCFF 主题、主按钮/滑块/输入焦点状态、圆形头像、白/浅蓝气泡、更多菜单及底部音量；登录窗口行为保持。
- SPEC 7776cc6；Red 72b7194（真实聊天缺少更多菜单与菜单退出）；分支 feat/godot-blue-ui。
- 验证：check.ps1、真实 loopback 聊天测试、账户应用窗口测试通过；作者自审核对菜单退出、可读文字、原有配置和未实现入口隐藏。视觉截图与 DPI 检查在最终导出验收单独记录，不将 headless 当视觉验收。

### 2026-09-19 完整语音缓存与原生波形

- 交付行为：AudioCache 分块保存原始流，成功终止与文件提交后才可查询；规范化服务器/账户/UUID 隔离，无自动淘汰，手动清理。PcmStreamDecoder 原生输出 24 桶波形摘要。
- SPEC fbf3c44；Red a19fa19、e5866d4；分支 feat/godot-audio-cache。
- 验证：缓存及解码 focused tests 通过，包含跨实例、残缺/损坏文件、错误提交、只读临时文件清理失败、隔离、极短波形；原有全套检查除新增缓存用例外通过，修正缓存类型检查后该用例重跑通过；原生 RSA/Python 互操作通过。
- 作者自审：核对双文件提交顺序、只删除当前范围自有文件、无完整文件自动淘汰；日志原始 UUID 疑点经 ClientLog 的 SHA256 白名单逻辑确认不会落盘。DLL 重建及 SHA256 锁定更新。本切片尚未将缓存接入在线媒体与界面。

### 2026-09-19 完整语音重放媒体链路

- 交付行为：ReplyAudio 注入缓存，完整流提交后可重放；暂停/继续/停止、在线抢占、停止在线后继续完整缓存；断线中断清理、范围隔离、手动清理抑制当前流写入。原生波形与实际消耗帧提供进度/口型，重放完成与在线完成分开。
- SPEC ba5e025；Red 738f21a（可运行测试确认缺少重放能力）；分支 feat/godot-voice-replay。
- 验证：test_voice_replay.gd 的真实 AudioEffectCapture 输出、暂停静音/进度冻结、续播、停止/切换/抢占、完整缓存和不可写路径全部通过；test_reply_audio、test_audio_lifecycle、test_audio_cache 回归通过。
- 作者自审：核对缓存三项提交条件、重复操作、只有一个声音输出、无旧账户完成信号；本条只记录媒体公开接口，尚不表示正式消息按钮已接通。独立核验在限时内未返回结论，不能视为他人审核通过。

### 2026-09-19 正式消息重放控件与清理确认

- 交付行为：Application 注入按账户隔离缓存，ChatSession 提供消息音频操作；气泡下方重放/暂停/继续/停止、真实波形/进度，定向更新不重建文字。更多菜单提供清理确认，取消保留文件，确认移除重放按钮但保留正文。
- SPEC ba5e025；Red ad0ec6f（真实 loopback 声音可播，但没有消息重放控件及清理确认）；媒体 Green 57b96f0；分支 feat/godot-voice-replay。
- 验证：check.ps1、check_network.ps1、check_accounts.ps1 全部通过；voice_chat 验证文字选择保持、消息/表情不重复、取消/确认清理。账户窗口测试在本机 GPU 窗口另跑通过，没有 headless 尺寸跳过。
- 本机 WASAPI：test_voice_replay.gd 通过，双声道 48000Hz、10ms 缓冲；AudioEffectCapture 检查非零输出、暂停静音和进度冻结。日志 artifacts/replay-wasapi.log；不代表人工听感。
- 截图：真实 ChatView/ChatSession/WebSocket/Avatar 与合成语音，1200×800、960×640、暂停态、125%/150% 内容缩放通过控件边界检查；截图 artifacts/voice-ui-*.png。RTX 4070 Laptop GPU、NVIDIA 610.74；本次是内容缩放检查，不是操作系统 DPI 切换验收。
- 作者自审：正文选择与播放进度分别更新，UI 不接触音频路径；退出关闭范围，完整缓存保留；手动清理默认聚焦取消。project.godot 原有编辑器改动保留未提交；未改服务端协议及旧客户端。
- 未验证：真实服务器 TTS/唱歌听感、长期运行/内存、Windows 10、集显性能、系统 DPI 切换和双屏。未正式替换交付入口。

### 2026-09-19 重放版 Windows ZIP 导出核验

- 候选代码 869d3bd；build.ps1 导出/独立启动通过。同版本标准引擎加载实际 AgentLuo.pck 与随包 DLL，完整重放 WASAPI 测试通过（artifacts/export-replay-verified.log）。
- ZIP：artifacts/AgentLuo-replay-869d3bd-win64.zip，43,061,194 字节，13 个文件；CRC、EXE/PCK/DLL/许可核验通过，DLL 哈希与依赖锁一致。SHA256 eeacb6bef3cc3a61dfad385cc308e5f36e7d714c56402e5d3c66bd888264ee29。
- 旧 AgentLuo-voice-fix-win64.zip 保留；本地 PR 说明、提交/自审与实际测试记录见 artifacts/voice-replay-review.md。没有推送/合并或切换正式下载入口；未验证范围沿用上一条记录。
