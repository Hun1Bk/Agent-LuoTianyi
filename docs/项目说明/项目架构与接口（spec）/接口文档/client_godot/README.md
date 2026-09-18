# Godot 客户端 interface

本文记录工程构建、角色显示与构图、离线视觉样板的公开契约。网络、媒体接口在对应切片中补充，未列接口不视为已实现；完成事实见开发进度。

## 工程与构建入口

- `client_godot/project.godot`：Godot 4.7.1 标准版工程；Compatibility，原生标题栏，1200×800，最小 960×640。入口是明确标识尚未连接服务的本地启动场景。
- `client_godot/scripts/build.ps1 -Godot <exe> [-OutputDirectory <dir>]`：调用方为开发者/CI；默认输出到工程 `dist/`，要求匹配的 Windows x64 导出模板。正常依次导入和 release 导出，失败返回非零，不删除旧产物伪装成功；最终启动本次导出文件验证能正常退出。
- 引擎参数优先于 `GODOT_BIN` 环境变量；两者均缺失报错。不扫描全盘，不静默下载引擎，不接受错误主/次/补丁版本。
- `client_godot/scripts/check.ps1 -Godot <exe>`：执行引擎版本检查、headless 导入及启动检查；任何 GDScript parse/script 错误即失败，即使 Godot 进程本身退出码为 0。
- `client_godot/dependencies.lock.json`：版本化构建输入；包含基线提交、引擎版本/commit、模板版本、依赖下载地址和 SHA-256。尚未取得的产物不编造哈希、不标记为验证通过。
- `client_godot/export_presets.cfg`：固定名 `Windows Desktop` 的 x86_64 release preset，使用外置 PCK，输出文件名 `AgentLuo.exe`。

副作用仅为 Godot 导入缓存、日志和指定目录的构建产物。不会启动服务端、读取旧端凭据、修改生产数据或发出网络请求。启动检查使用 `--headless --quit-after 3`，不打开交互窗口。

## 验证入口

本切片属于工程/构建配置，无有意义的运行时 Red，记录“不适用”。观察构建命令退出码及日志；验证错误引擎路径被拒绝、同版本导入/导出成功、独立产物 headless 启动成功。headless 只证明启动，不证明真实 GPU 渲染或视觉验收。

## AvatarDriver：真实模型显示与控制

位置 `client_godot/src/avatar/avatar_driver.gd`，继承 `Node2D`。调用方为角色场景及后续媒体控制器。所有调用在 Godot 主线程执行；驱动独占插件对象，其他模块不得直接调用 gd_cubism。

| 调用 | 正常行为 | 失败行为 |
| --- | --- | --- |
| `load_avatar(model_path: String) -> Error` | 加载完整 model3.json 及资源，初始化表情、动作和口型；再次成功加载替换旧模型 | 文件缺失返回 `ERR_FILE_NOT_FOUND`；插件不可用返回 `ERR_UNAVAILABLE`；资源无效返回 `ERR_INVALID_DATA`；预检失败保留原模型 |
| `apply_expression(command: String) -> bool` | 接受现有中文命令或模型表情 ID；启动表情并更新基础口型 | 未加载或未知命令返回 false，保留当前表情 |
| `play_motion(group: String, index: int = 0) -> bool` | 播放已存在的动作，用正常优先级 | 未加载、未知动作或索引越界返回 false |
| `set_mouth_openness(value: float)` | 0～1 用作当前说话口型；负数释放覆盖，恢复当前表情的基础口型 | 未加载时无操作；大于 1 截断为 1 |
| `get_status() -> Dictionary` | 返回 `loaded`、`canvas_size`、`expression`、`motion_groups`、`mouth_openness`，供布局、可用性展示和验收 | 未加载时 `loaded=false`、canvas 零、列表为空 |

模型失败必须在 UI 提示，不能以静态头像冒充加载成功。默认表情为 `normal`。现有口型映射负值表示由表情保持，不强制写入负值。驱动在模型效果处理阶段叠加口型；不从独立线程更新模型。

本切片不提供触摸上报、网络事件、音频解码或构图持久化。模型、映射及许可说明随工程打包，旧端资源不修改。打包包含 `.moc3`、JSON、纹理和插件动态库。

### 验证

`godot --headless --path client_godot --script res://tests/test_avatar_driver.gd` 从真实驱动入口验证：完整资源可加载；缺失入口被拒绝且不丢旧模型；表情命令可切换、未知命令无副作用；动作合法/越界；口型范围及恢复。插件缺失属于环境失败，不计 Red。另用真实 GPU 导出包检查透明、遮罩、物理和表情，headless 不代替画面验收。

## AvatarFraming：构图与本地保存

`src/avatar/avatar_framing.gd` 是 `RefCounted`，调用者为角色区域。公开 `zoom_by(factor)`、`pan_by(pixel_delta, panel_size)`、`reset()`、`get_transform(panel_size, canvas_size) -> Transform2D`、`save_settings(path) -> Error`、`load_settings(path) -> Error`。

- 默认缩放倍数 1.2，位置为区域中心。倍数限制 0.6～2.4；位移保存为区域宽高比例，分别限制 -0.4～0.4。零尺寸区域不移动、不产生除零。
- 布局缩放基础值为区域对模型 canvas 的等比容纳；面板改变后仍保持保存的相对位置和比例，不保存像素绝对位置。
- 正缩放因子生效；零、负数、NaN、无限值拒绝且不改变状态。无效拖动同理。
- 重置恢复默认构图。保存用 ConfigFile 写当前缩放和归一位移；文件写入错误返回 Error。加载缺失文件返回 `ERR_FILE_NOT_FOUND`，损坏或字段非法返回 `ERR_INVALID_DATA` 并保留现有构图；超界有限值截断到范围。
- 产品设置路径为 `user://avatar_framing.cfg`，它只包含本机窗口构图，不含账户数据。测试使用独立临时路径，不触碰用户配置。
- 角色区域滚轮缩放、右键拖动；左键不调整构图。拖动释放和滚轮操作后保存；保存失败给出可识别状态，不影响当前画面。最小化关闭角色绘制/更新，不暂停整棵场景树。

验证入口：`tests/test_avatar_framing.gd`，检查边界、跨尺寸恢复、重置、缺失/损坏配置与重新实例化后的恢复。本切片不实现触摸上报或账户设置。

## OfflinePreview：可运行视觉样板

独立入口 `scenes/chat_preview.tscn`，由当前开发启动场景装配，始终显示“离线样板 · 未连接服务器”；正式产品菜单不提供此入口。UI 只调用离线控制器和 AvatarDriver，完全不发 HTTP/WebSocket 请求。

`src/preview/demo_session.gd` 是离线样板控制器，继承 RefCounted，供样板 UI 和 headless 测试调用：

- `select_scenario(name: String) -> bool`：接受 `conversation/empty/disconnected/error/thinking`，替换模拟消息并重置模拟状态；未知名称返回 false 且保留数据。
- `get_messages() -> Array[Dictionary]`：返回深拷贝。消息包含 `id/role/text/status`，role 为 assistant/user/system，status 为 received/sending/sent/failed；可选 `image` 为本地资源路径。样例包括长短文字、图片和三种发送状态。
- `submit_text(text: String) -> String`：空白输入或断网/加载失败场景返回空 ID 且不修改消息；正常保留输入正文并追加 sending 消息，返回会话内唯一 ID。不假装得到服务端答复。
- `settle(id: String, success: bool) -> bool`：只将已存在的 sending 消息变为 sent/failed；未知 ID 或重复结束返回 false。
- `changed` 信号通知展示刷新；场景切换后旧 ID 的延迟回调不影响新消息。

视觉布局：原生标题栏、左45%角色、右55%聊天，分隔条可调并单独保存 `user://preview_layout.cfg`。角色沿用 AvatarPanel；浅色实底、青蓝用户气泡、左右头像；消息正文可选择。底部输入支持 Enter/Shift+Enter，IME 合成期间不发送。输入失败保留文字。新消息只在原来位于底部时自动跟随，否则显示“回到最新”。样板消息数有限，不承诺历史分页或千条虚拟列表。

图片样例点击在内部浮层预览，支持缩放与关闭；样板可选择或粘贴单张图片，进入待发送预览，显式发送或取消。图片读取失败保留输入并提示，不写长期缓存。语音按钮只切换明确标注的模拟播放状态并驱动口型，无实际声音，不冒充流式音频验证。表情通过真实 AvatarDriver 切换。

验证：`tests/test_demo_session.gd` 检查空白拒绝、唯一 ID、正文保持、状态转移幂等、坏场景无副作用、场景切换旧回调隔离、读副本不泄露内部状态。实际导出截图核对气泡、真实模型、字体、分隔和底部输入。中文输入法与系统剪贴板需人工操作验收。

## WindowsSecurity：Windows 原生密码与秘密保护

位置 `client_godot/native/windows_security.cpp`，GDExtension 类 `WindowsSecurity`，继承 RefCounted；由应用创建并注入账户/本地存储模块。只使用 Windows CNG/Crypt32，不启动外部进程，不访问磁盘或网络。

所有调用返回 `{ok: bool, data: PackedByteArray, error: String}`；成功 error 为空，失败 data 为空，错误码不包含输入内容。

- `encrypt_password(public_key_pem: String, password: String) -> Dictionary`：接收服务端 `/auth/public_key` 的 SubjectPublicKeyInfo PEM 和 UTF-8 密码，返回 RSA-OAEP 密文字节；OAEP 与 MGF1 均 SHA256，label 为空。调用方用 Base64 编码填入既有 password/new_password 字段。RSA 至少 2048 位，最大 8192 位；公钥字符串不超过 16 KiB；明文字节超出当前 OAEP 上限时返回 `INVALID_INPUT`。无效公钥 `INVALID_KEY`；CNG 失败 `ENCRYPTION_FAILED`。不使用 SHA1 降级。
- `protect_secret(plain: PackedByteArray, scope: PackedByteArray) -> Dictionary`：当前 Windows 用户 DPAPI，禁止交互提示；scope 为规范化服务器/账户标识派生的额外熵，不能跨 scope 解密。plain 与 scope 各 1～65536 字节；失败 `INVALID_INPUT` 或 `PROTECT_FAILED`。
- `unprotect_secret(cipher: PackedByteArray, scope: PackedByteArray) -> Dictionary`：相同用户及 scope 下恢复字节；篡改、不同 scope 或不同用户返回 `UNPROTECT_FAILED`，绝不降级为明文。cipher 最大 128 KiB，scope 同上。

C++ 临时明文缓冲在释放前清零；Windows 句柄和 DPAPI 输出无论成功失败都释放。GDScript 调用者仍负责及时释放自己的密码/密钥引用。此接口只转换字节，原子落盘、自动登录策略和 API key 明文选择由后续存储/业务接口承担。

验证：Godot headless 从 ClassDB 创建真实扩展，验证 DPAPI 往返、不同 scope/篡改拒绝、空值及上限；Python 临时测试进程生成密钥，用仓库 `account.py::decrypt_password` 解密 Godot 产生的 ASCII/中文/边界密码密文，并确认相同明文的密文不同。不使用生产密钥或真实凭据。扩展未加载属于环境失败，不计 Red。

## AccountApi：异步账户请求

位置 `src/network/account_api.gd`，继承 Node；组装根通过构造函数注入 WindowsSecurity 和超时（默认 15 秒）。UI/账户控制器通过 `request(operation, server, fields) -> Dictionary`（异步）调用；公开 `cancel()` 取消当前操作、`normalize_server(address) -> String` 规范化地址。单实例同时只执行一个操作，第二次调用返回 `BUSY`。

返回统一 `{ok: bool, code: String, status: int, data: Dictionary}`；成功 code 为 `OK`、data 为校验后的账户结果。失败 code 为 `INVALID_INPUT/BUSY/CANCELLED/TIMEOUT/NETWORK_ERROR/INVALID_RESPONSE/PUBLIC_KEY_ERROR/ENCRYPTION_ERROR/HTTP_ERROR/AUTH_REJECTED`；status 为 HTTP 状态，无响应为 0。错误不回显请求字段或未经处理的响应正文；UI 根据 code/status 显示明确反馈。未登录成功前不发布会话。

| operation | fields | 既有协议与成功字段 |
| --- | --- | --- |
| login | username,password,request_token(bool) | GET /auth/public_key 后 POST /auth/login；user_id/login_token/message_token 均为非空 String |
| register | username,password,invite_code | GET 公钥后 POST /auth/register；非空 message/user_id |
| reset | invite_code,new_username,new_password | GET 公钥后 POST /auth/reset_account；非空 message/username |
| auto_login | username,token | POST /auth/auto_login；非空 user_id/login_token/message_token |

- 每次密码请求重新获取公钥，避免服务端重启/切换服务器后缓存错钥；不裁剪用户名或密码。只发送当前操作需要的字段，不透传未知字段。密码由原生层加密，再 Base64 编码。
- 地址首尾空白和尾部 `/` 去除；无协议补 https；scheme/host 小写、默认端口去除，保留可选路径前缀。仅接受 http/https、合法端口、域名/IPv4/方括号 IPv6；拒绝 userinfo、query、fragment、反斜杠及路径内空白。无效返回空串。TLS 始终校验证书，不跟随重定向。
- HTTPRequest 异步执行，单响应最多 64 KiB；JSON 非对象、缺字段、字段类型错误或 token 为空均返回 INVALID_RESPONSE。鉴权 401 返回 AUTH_REJECTED，其他非 200 为 HTTP_ERROR；公钥响应非成功为 PUBLIC_KEY_ERROR（取消/超时保持原错误）。无自动重试，防止账户写操作重复。
- cancel() 可重复；取消公共密钥获取或提交后都结束等待，并使迟到回调不再建立会话。退出树也取消。此模块不保存 token、不触发 WebSocket、不写日志或本地配置。

验证 `tests/test_account_api.gd` 与本地 Python HTTP 测试服务：真实 CNG 加密可解密、四种字段转换、401/503、错误公钥/JSON、空 token、超时、取消、并发拒绝、地址规范化与服务器切换。测试绑定 127.0.0.1 随机端口，不接生产服务。
