# Godot 客户端 interface

## ClientLog 启动归档契约（替代旧三文件轮换）

构造 `ClientLog(directory="user://logs", legacy_max_bytes=2097152)`，第二参数仅保留调用兼容、无截断效果。`record(event, fields={}) -> Error` 保留原有白名单与 UUID 哈希；新增安全 level/module 枚举及数字 count/status/index/duration_ms。事件与错误码限字母数字下划线，不能传正文。每条包含时间、相对启动毫秒、级别、模块、事件及固定中文说明；持续 flush。首次记录创建唯一 run ID（时间/PID/随机），当前内存记录不会因写盘失败丢失；`write_failed(error)` 明确报告失败，`entry_added(entry)` 供实时视图。

`get_run_id() -> String`、`list_runs() -> Array[Dictionary]`（id/started/pid/closed/active/complete）和 `read_entries(run_id="") -> Array[Dictionary]` 供日志窗口；空 ID 表示当前启动、返回副本。历史 ID 仅从归档目录枚举、安全校验，不接受路径。未知/损坏行跳过且 complete=false，不将损坏文件当完整。`finish()` 幂等写 client_stopped 并更新关闭标记；关闭后 record 拒绝。无结束标記的退出被标识未正常结束。

每次启动独立 jsonl 与 json 元数据，保留最近 50 次，清理仅删除该格式的完整启动文件；使用 PID 活跃检测保护其他仍在运行的实例，旧 client*.jsonl 不删除。`get_directory()` 保持可用。每条读写结果返回错误，记录存储是否完整；只记录允许的环境信息，不含路径、用户名或凭据。

`export_run(run_id, destination_zip) -> Error` 导出全部选定记录，固定条目 events.jsonl、readable.txt、environment.json，版本来自 release.json；不接受筛选参数、不覆盖已有文件、不上传。写盘失败或损坏记录在摘要 complete=false，禁止宣称完整。测试通过独立目录、重建实例、50 次边界、活跃保护、错误路径和 ZIP 读取验证公开结果。

## 版本化构建

`release.json` 为唯一版本来源：`product=agentluo, version=0.1.0`。`src/release_info.gd` 的静态 `get_info() -> Dictionary` 返回副本，`title() -> String` 返回 agentluo + 版本。Application 原生窗口标题使用该值；不更改既有 user:// 目录。

`scripts/build.ps1 -Godot <path> [-OutputDirectory <root>] [-Package]` 默认构建至 dist/agentluo-<version>/agentluo.exe 和同名 pck。输出版本资源与 licenses；可选 Package 在 artifacts 下创建同名 ZIP，包含唯一顶层目录。已有 ZIP 时构建前失败，不覆盖；版本不自动递增。包内 DLL 保持导出引擎收集结果，不手工省略。构建仍检查锁定引擎版本、导出与独立启动，版本格式拒绝非三段数字。脚本与元数据属于构建配置切片，Red 不适用；实际导出、ZIP 条目与重复打包拒绝验证其行为。

## 统一主题与正式聊天布局

Style.make_theme() 统一账户与聊天控件的背景、文字、按钮、输入焦点、选中及滑块；主按钮/滑块为 #66CCFF，深色文字，悬停/按下/禁用与键盘焦点可辨。Style.primary(button) 应用主按钮变体，Style.avatar(texture_path, size=38) 返回带圆形浅底的头像控件。颜色集中定义，不用各页面覆盖旧青绿色。

正式 ChatView 顶部为头像、标题、连接状态及“更多”MenuButton；PopupMenu 提供“打开日志”(ID 0)、“清理本账号语音缓存”(ID 1)、“退出登录”(ID 2)，以可见菜单操作触发现有行为。未注入日志时相应项禁用。音量与停止当前在线语音移至输入区上方，发送按钮使用统一主题；当前不显示尚未实现的图片/历史/动态与模拟未读。

保持现有 ChatSession/AccountSession 调用、输入行为、快照增量刷新及阅读位置；原生标题栏、登录收起/展开、45:55 分隔、构图不改变。正文纯文本可选择复制。气泡白/浅蓝，头像圆形；以真实截图验收配色，不增加镜像样式实现的单元测试。菜单改动通过已有真实聊天及账户应用测试验证，确认菜单退出确实返回账户页。

## PcmStreamDecoder：增量 WAV 音频

原生 RefCounted 类，由媒体模块在主线程创建；与 WindowsSecurity 共用扩展，无网络或文件副作用。

- `append(bytes: PackedByteArray) -> Dictionary`：首片及跨片头按 RIFF/WAVE 解析，随后按 data 区接收 PCM；支持未知 data 长度 0xFFFFFFFF。PCM 8/16/24/32 位及 IEEE float32，单/双声道，8000～192000 Hz；单声道复制为左右声道，输出归一浮点。支持对应完整 GUID 的 WAVE_FORMAT_EXTENSIBLE，拒绝压缩格式和其他声道数。
- `finish() -> Dictionary`：标记接收结束；空音频、残缺头、残缺帧或已知 data 长度不足报错。重复 finish 幂等，成功结束后 append 返回 STREAM_FINISHED 且不修改已完成数据。
- `read_frames(max_count: int) -> PackedVector2Array`：取走至多指定数量立体声帧，供 AudioStreamGeneratorPlayback.push_buffer；GDScript 不逐样本解码。
- `get_status() -> Dictionary`：ok/code/sample_rate/channels/bits/queued_frames/decoded_frames/input_bytes/finished。错误码 INVALID_WAV、UNSUPPORTED_FORMAT、TRUNCATED_AUDIO、EMPTY_AUDIO、BUFFER_LIMIT 为粘性错误并释放音频缓冲。
- `get_amplitude(frame_index: int) -> float`：返回指定绝对帧所在约 10ms 窗口的 RMS（0～1）；越界返回 0。调用方使用实际播放进度，不能以收包进度驱动口型。
- `get_waveform(buckets: int = 24) -> PackedFloat32Array`：成功 finish 后，按时间均分为 1～128 桶，各桶取原生 RMS 窗口峰值；不受 read_frames 消耗影响。未结束、失败、空音频或桶数非法返回空数组；极短声音覆盖的窗口可重复用于多个桶。

## AudioCache：按账户保存完整语音

`src/storage/audio_cache.gd` 是 RefCounted，构造 `(root="user://audio", logger=null)`；主线程通过 begin/append/commit 分块写文件，不解码样本。

- `set_scope(server, username) -> Error`：用 AccountApi.normalize_server 规范化地址，与账户一起 SHA256 隔离目录；切换前 abort_all，完整缓存保留。非法账户范围返回 ERR_INVALID_PARAMETER 并禁用缓存；目录不可写返回对应 Error。
- `begin(id) / append(id, bytes) -> Error`：非空 UUID 的 SHA256 为文件名；临时 .part 只写入当前流的原始 WAV/PCM 字节，不攒整段音频。最多 16 个在途文件；已有可用完整缓存 begin 返回 ERR_ALREADY_EXISTS 且不覆盖。append 单次上限 8 MiB，失败取消该临时文件。
- `commit(id, decoder_status, waveform) -> Error`：仅接受成功且 finished、正帧数及合法格式、24 个有限幅值的原生结果；校验字节数与已写数据一致。先关闭/重命名音频，再原子提交元数据作为完整标记。任何失败不公开部分流。原始流保留未知长度 WAV 头，后续必须交给 PcmStreamDecoder 重放，不假定普通 WAV 文件播放器可读。
- `lookup(id) -> Dictionary`：无可用缓存返回空字典；成功返回 path/sample_rate/channels/bits/frames/duration/waveform/bytes。元数据版本、范围、文件存在性和长度经验证，path 由本地命名构造，不信任文件中的路径。不开启或修改聊天正文存储。
- `abort(id)` / `abort_all()`：关闭并移除在途临时文件，幂等；`clear() -> Error` 删除当前范围内自有缓存文件，部分失败返回 Error，不跨账户、不递归删除任意文件。会话层负责先停止重放与阻止当前流再次缓存。

完整缓存仅 clear 手动删除，无容量/时间淘汰。set_scope 清理本目录未完成 .part/.json.tmp，不清理完整文件。记录 cache_committed/cache_error/cache_cleared，不记录账户或原始 UUID。验证独立临时目录中的跨实例恢复、隔离、未完成不可见、非法提交、文件损坏/不可写、清理及波形。

每次 append 上限 8 MiB，WAV 前置头累计上限 1 MiB，未读解码队列上限 128 MiB，单流时长上限 30 分钟。无效数值拒绝；未知辅助 chunk 按声明长度及偶数字节填充跳过。已知 data 结束后的尾部元数据不作为 PCM。每个 UUID 一个解码器，不猜测无头 PCM 中的采样率变化。

验证入口 tests/test_pcm_decoder.gd：跨片头/半帧、未知长度、正常 WAV、声道/采样率/位深、幅值、非法/空/残缺流及资源边界；真实加载 DLL。此接口只解码，不表示声卡已输出。

本文记录工程构建、角色显示与构图、离线视觉样板的公开契约。网络、媒体接口在对应切片中补充，未列接口不视为已实现；完成事实见开发进度。

## 工程与构建入口

- `client_godot/project.godot`：Godot 4.7.1 标准版工程；Compatibility，原生标题栏。默认入口为紧凑账户窗口（660×800，最小 480×640），登录后展开为角色与聊天窗口（1200×800，最小 960×640）；离线演示通过 --preview 独立进入。
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

## CredentialStore 与 AccountSession：账户生命周期

`src/storage/credential_store.gd`（RefCounted）由 WindowsSecurity 和根目录（默认 `user://accounts`）构造；只接受已规范化的 server 和非空 username。作用域是 JSON `[server, username]` 的 SHA256，目录及 DPAPI entropy 均由此派生。

- `save(server, username, token) -> Error`：仅保存 DPAPI 保护后的 login_token，先写临时文件再原子替换；失败返回错误，不保存明文、不读取旧端数据。
- `read(server, username) -> Dictionary`：返回 `{ok, code, token}`，成功 token 为解密后的字符串；缺失 NOT_FOUND，损坏/无法解密 UNAVAILABLE，失败 token 为空。
- `forget(server, username) -> Error`：删除指定作用域自动登录凭据；缺失视为成功。媒体缓存不受影响。

`src/session/account_session.gd`（Node）由 AccountApi、CredentialStore、普通设置文件路径构造，拥有 API 节点；默认设置文件 `user://account.cfg` 只含上次服务器、用户名与 auto_login 布尔值。

- `perform(operation, server, fields, remember=false) -> Dictionary`（异步）：通过 AccountApi 处理账户操作。登录/自动登录成功才进入 signed_in；注册/重置成功保持 signed_out，提示回到登录。重复提交 BUSY；错误保留 UI 草稿。成功记住登录时只保存 login_token，message_token 只在内存。
- `resume() -> Dictionary`（异步）：配置启用自动登录且凭据可解密时尝试一次；成功旋转并保存新 token。明确 AUTH_REJECTED 后清除凭据并关闭自动登录，不自动循环。配置缺失返回 NO_SAVED_LOGIN；无法读取凭据返回 CREDENTIAL_UNAVAILABLE。网络暂时失败不会把 token 误认为鉴权失败。
- `cancel()`：取消在途操作，结束 busy 状态；迟到结果不建立会话。
- `logout() -> Error`：取消在途请求、清空内存会话、清除当前作用域自动登录凭据、禁用自动登录，发送 signed_out 状态；文件删除/保存失败返回实际错误，不伪装清除成功。
- `get_login_defaults() -> Dictionary`：server/username/remember，用于登录表单，不含秘密。`get_session() -> Dictionary`：仅向应用/网络控制器返回当前会话深拷贝（server/username/user_id/login_token/message_token），退出后为空。
- `changed(state: Dictionary)`：只包含 phase（signed_out/busy/signed_in）、code、storage_error，不含 token/密码。写凭据或配置失败不撤销已经成功的在线登录；返回 `storage_error=true`，并关闭自动登录，不自动明文降级。

普通设置同样采用临时文件和原子替换。切换服务器/账户前取消旧操作并清空旧会话；后续网络组装监听 signed_out/busy 关闭连接。本切片尚不创建聊天连接。

验证从以上公开入口使用真实 DPAPI、本地 HTTP fixture、隔离临时目录：跨服务器/账户不可读、重新实例化恢复、token 旋转、401 清理、退出后无会话/凭据、重复取消、保存失败仍可在线登录。测试不触碰真实 user://account.cfg。

## AccountView 与应用账户入口

`src/ui/account_view.gd` 是 Control 视图，由组装根注入 AccountSession，监听 changed 展示状态。主入口默认显示实际账户页面；离线样板只通过开发参数 `--preview` 进入，不放入产品菜单。

- 统一账户页面提供密码登录/注册/邀请码重置三个模式；字段为服务器地址、用户名、密码、确认密码、邀请码及自动登录勾选（按模式显示）。密码默认遮蔽；登录不裁剪用户名/密码；确认密码不一致时在本地拒绝且不发请求。
- 点击提交或密码框 Enter 调用 AccountSession.perform；忙碌时禁用模式、表单、提交并显示取消。失败保留用户输入；成功清空密码/确认密码/邀请码；注册/重置成功返回密码登录模式，保留服务器及新用户名。
- AUTH_REJECTED、超时、公钥/加密错误、响应错误和存储失败均以系统状态展示；不把错误显示成角色发言，不回显 token 或服务端未经校验的正文。
- signed_in 显示账户身份与退出入口；退出调用 logout，清除密码框，并明确报告凭据清除失败。后续聊天场景由组装根按会话状态装配，本视图不创建 WebSocket。
- 组装根创建真实 WindowsSecurity、CredentialStore、AccountApi、AccountSession。正常 GUI 启动尝试一次 resume；headless 构建检查和 `--capture` 截图模式不自动访问配置中的服务器。自动化账户测试注入独立配置路径及本地 HTTP 服务。

验证：`test_account_view.gd` 通过可见表单、按钮和状态文本观察错误密码后保留输入、确认密码拒绝、成功后清空敏感字段与退出状态；使用真实账户控制器和本地 HTTP fixture。导出截图检查默认/最小窗口及中文字段布局。系统 IME 仍由实际 Windows 人工验收。

## ReliableOutbox：消息投递队列

位置 `src/network/reliable_outbox.gd`（RefCounted），调用方为 WebSocketTransport。时钟以调用参数的单调毫秒值注入，测试不用真实等待。

- `enqueue(type, payload, durable, now_ms) -> String`：分配稳定 client_msg_id 并复制 payload；上限 128 个在途事件，单包 UTF-8 JSON 不超过 8 MiB，拒绝返回空串。packet 顶层含 type/payload/client_msg_id/ts/reply_to。durable 用于 user_text（含 proactive）、user_image；typing/touch/image selecting/cancel 为瞬时事件。
- `take_ready(now_ms, connected) -> Array[Dictionary]`：先处理到期，再返回可以发送的包；持久消息按入队顺序最多一条等待 ACK，瞬时事件独立发送，不阻塞持久队列。未连接时瞬时事件丢弃；持久事件保留到重连或到达龄期。
- `acknowledge(reply_to, payload, now_ms)`：旧格式无 ok:false 视为成功；负 ACK 仅 retryable 严格 true 时重试。成功或终止后忽略重复 ACK、未知 ID。收到 ACK 前已经发送过的消息，即使正在退避也可接受确认。
- `disconnected(now_ms)`：将已发未确认的持久事件安排重试，瞬时事件丢弃。`stop(code="TRANSPORT_STOPPED")`：结束全部在途事件并释放 payload；不可在重新登录后继续发送旧账户的事件。
- `delivery_changed(id, state, code)`：queued/sending/sent/failed/uncertain；失败未知送达使用 uncertain + DELIVERY_UNCERTAIN，不自动生成新 ID。

ACK 超时 10 秒，图片选择/取消为 5 秒。持久消息首发后最多重试 8 次，退避 1/2/4/8/16/30/30/30 秒；若排队龄期达到 240 秒或下一次重试将达到龄期上限，即结束为 DELIVERY_UNCERTAIN。正常 NACK 的 code 只保留字符串错误码，不传原始 message 给日志。瞬时事件不重试。依据 client/src/delivery_policy.py 及 ws_transport.py。

验证 `tests/test_reliable_outbox.gd`：成功/旧格式/重复 ACK，非重试 NACK，ACK 丢失和可重试 NACK 保留 ID，重试与龄期边界，瞬时事件不挡文本，断线和显式停止。
## WebSocketTransport：认证连接与事件传输

`src/network/websocket_transport.gd` 为 Node，由应用创建并注入单调毫秒时钟 Callable（默认 Time.get_ticks_msec）。拥有 WebSocketPeer 和 ReliableOutbox，在主线程逐帧 poll；不阻塞 UI，不保存凭据，不写原始网络日志。

- `start(session: Dictionary) -> Error`：接受 server/username/message_token；规范化 HTTP(S) 地址为 WS(S) 的 `/chat_ws`，保留路径前缀。无效输入返回 ERR_INVALID_PARAMETER；启动替换旧连接和投递队列。连接后发送 `user_auth`，使用 message_token 和 capabilities:[negative_ack_v1]；只有 `auth_ok` 才进入 ready，`system_ready` 本身不算认证成功。
- `send_event(type, payload, durable=false) -> String`：通过 ReliableOutbox 返回稳定 ID；ready/connecting/authenticating/reconnecting 可接受，idle/auth_rejected 拒绝返回空串。持久消息可等待重连；瞬时事件离线终止。UI 仍经消息控制器调用，不直接生成协议包。
- `get_state() -> Dictionary` 与 `state_changed(state)`：返回 phase（idle/connecting/authenticating/ready/reconnecting/auth_rejected）和 code，不含身份秘密。`delivery_changed(id,state,code)` 转发投递状态；`event_received(event)` 交付已校验 type/payload 的业务事件；`system_error(code)` 只报告错误码，不把 error 伪装角色消息。
- `stop()`：关闭 socket、清理内存凭据、终止队列及心跳；重复调用安全，退出树自动调用。后续显式 start 可使用新的会话。
- 明确 `auth_error` 或认证期 `error` 后停止同凭据自动/手动重连，以规范化服务器/用户名/token 的 SHA256 指纹记住拒绝；相同凭据 start 返回 ERR_UNAUTHORIZED，更新凭据才可继续。不把临时网络断开当鉴权拒绝。
- 连接期限 8 秒、打开后认证期限 5 秒；断开/超时按 2/4/8/16/30 秒退避，认证成功后复位。ready 后立即心跳，之后每 10 秒 hb_ping（ping_id 递增）；hb_pong 不产生角色事件，沿用旧端无独立 pong 超时规则。
- `server_ack` 按顶层 reply_to 交给 outbox；包大小上限 8 MiB，二进制帧、非对象 JSON 或缺少 type/payload 对象视为 INVALID_RESPONSE 并断线重连。TLS 使用 Godot 默认验证；每帧最多处理 64 包，防止网络洪峰独占界面。

验证：本地 Python websockets fixture + 真实 Godot WebSocketPeer；检查 URL、user_auth/message_token/capabilities、auth_ok、立即心跳、ACK/业务事件、连接断开后同 ID 重试、拒绝凭据不重连、更新凭据恢复、认证超时、退出清理；单调时钟注入用于加速退避和心跳，不访问生产服务。

认证阶段收到 WebSocket 关闭码 1008 同样视为 AUTH_REJECTED，禁止同凭据重连；这是服务端认证期限/尝试次数耗尽的实际关闭语义。Godot peer 在同次 poll 收到最终数据帧与关闭帧时可能已清空入站队列，因此不能仅依赖最后一帧 auth_error；普通关闭与 1013 仍按网络退避处理。
## ChatSession 与 ChatView：真实文字聊天

`src/session/chat_session.gd`（Node）由真实 WebSocketTransport 构造并拥有其生命周期；应用在账户 signed_in 时调用 `start(account_session) -> Error`，退出或账户切换调用 `stop()`。UI 使用下列接口，不发送协议包：

- `send_text(text) -> String`：拒绝纯空白/未登录，正常保留正文，发送 user_text，llm_mode.types 默认空列表；返回网络的稳定 ID，立即产生 user 消息，不等待回复。重连期间可排队；无法入队返回空串且保留输入。
- `get_messages() -> Array[Dictionary]` 返回深拷贝；消息含 id/role/text/status/code（queued/sending/sent/failed/uncertain 或 received）。投递状态更新原消息，不增加气泡；DELIVERY_UNCERTAIN 明确显示“无法确认送达”，不提供换 ID 自动重发。
- `get_state() -> Dictionary` 与 `state_changed(state)` 提供连接 phase/code、thinking 和系统提示；`changed` 表示消息内容/状态改变；`expression_requested(command)` 由应用连接 AvatarDriver。stop 关闭传输并清空消息、回复 UUID 和账户状态，不泄漏给下一账户。
- 接收 agent_state_changed 的 thinking/waiting；agent_message 按 payload.uuid 合并。重复分片不增加气泡，非空 text 更新同 UUID 的正文，空尾包不清文字；display_in_chat=false 不出气泡，is_ephemeral 保留显示语义且禁止该流持久缓存。
- 按 UUID 首次到达顺序展示文本/表情/声音，前一回复实际播放结束前后续回复暂存；is_final_package 表示接收结束，实际播放结束才推进下一句。audio_error 保留文字并结束声音。断线释放未完成回复等待及播放器，保留已显示文字。
- 无效回复（缺 uuid/text 类型错误）只产生安全系统提示；网络 error/auth_error 不进入天依消息。重复终止包忽略，不重放表情。

`src/ui/chat_view.gd`（Control）注入 ChatSession，发送/状态/正文使用真实控制器；公开 `logout_requested` 交给应用调用 AccountSession.logout。沿用已确认的气泡、输入控件和主题，正式发送状态不带“演示”。Enter/Shift+Enter/IME 规则不变；只有接受发送后清输入，失败保留。已有气泡更新而不全部重建，保持文字选择；在底部跟随新消息，阅读旧内容保留滚动位置并提供回到最新。提供音量和停止当前语音按钮，不提供尚未接入的图片/历史入口，完整缓存成功后提供消息语音重放。

## ReplyAudio：实际流式播放

`src/media/reply_audio.gd` 为 Node，由组装根创建，构造参数 `(logger=null, clock=Callable(), cache=null)` 可注入 ClientLog 与返回单调毫秒的时钟（默认 Time.get_ticks_msec，测试可控）；ChatSession 构造可接收第三个参数 media，未传则创建真实 ReplyAudio（保留既有调用兼容）。媒体拥有 AudioStreamPlayer/Generator 与每 UUID 的 PcmStreamDecoder，不直接改变气泡或角色。

- `append_reply_audio(id, encoded, final, audio_error=false, ephemeral=false)`：接收每包 Base64 字符串，先解码/缓存。空音频可用于文字回复及终止；坏 Base64、原生失败、服务端 audio_error 产生可识别错误，保留聊天文字，不落盘部分流。
- `play_reply(id)`：允许一个活跃 UUID；可在首片到达后调用，约 80ms 预缓冲或 final 后自动开始实际播放。后续 UUID 先解码，等待会话按顺序调用；每 UUID 采样率来自 WAV，由 Godot 混音器重采样。
- `receive_finished(id, code)` 表示接收结束；`playback_finished(id, code)` 表示播放器排空并等待输出延迟后结束或中断，两者各一次；`mouth_changed(value)` 为实际消耗帧对应 RMS（适当放大截断至 0～1），停止为 -1 恢复表情基础口型。
- `get_state()` 返回 active_id/playing/queued/volume；`state_changed(state)` 通知变化。`set_volume(value)` 接受有限 0～1 并截断；默认 1。`stop_current()` 中止当前声音，后续同 UUID 继续解码验证与缓存，丢弃待播放帧；仍接收文字/终止直到推进下一句；`reset()` 释放全部流，无旧账户完成回调，重复安全。
- 最多 16 个待处理 UUID，累计未读解码帧上限 128 MiB；60 秒未收到续片则 AUDIO_TIMEOUT，恢复队列。格式/容量错误、退出、断线均释放未完成资源。process_mode=ALWAYS，不随角色最小化停绘而暂停声音。
- 记录 audio_received（字节数）、audio_format（格式）、audio_decoded（帧数）、audio_receive_finished、audio_playback_started、audio_playback_finished、audio_underrun 及 audio_error。日志只含安全元数据，不能声称实际扬声器听感已验证。

ChatSession 公开 set_volume/get_audio_state/stop_voice，转发媒体 mouth_changed 信号给组装根；get_state 追加 speaking 布尔值。UI 显示播放/错误状态；停止只影响当前声音，后续回复默认仍自动播放。音量使用现有窗口配置保存，拒绝非法配置值。隐藏回复仍播放；临时回复不写缓存。完整音频缓存及重放契约如下。

验证 tests/test_reply_audio.gd 用真实原生解码/AudioStreamGenerator，AudioEffectCapture 观察非零输出及静音/停止；loopback WebSocket 到 ChatSession 验证分片、顺序、隐藏、坏流和断线。默认只用合成音频，实际 Windows 音频驱动另跑并记录，不连接生产服务。

应用沿用左角色右聊天；账户成功显示 ChatView、隐藏账户表单；退出返回账户表单并取消连接。分隔比例保存到 user://window_layout.cfg，窗口缩放保持比例。离线 preview 保持独立。

### 账户窗口展开与默认服务器

- 未登录、登录失败、注册/重置、取消和自动登录等待期间，只显示右侧账户表单；窗口初始 660×800、最小 480×640，不显示角色、聊天及分隔条。
- AccountSession 的 signed_in 才展开为角色/聊天窗口（首次 1200×800，最小 960×640），成功登录再创建角色节点；退出后收回账户窗口并释放角色绘制资源，重新登录按已保存构图加载。重复 busy/signed_out 通知不反复调整窗口。登录后用户调整的普通窗口尺寸在本次运行内保留，重新登录恢复；展开/收起保持窗口中心并限制在当前屏幕可用区域内。
- 源工程的原生启动窗口也使用账户尺寸，避免出现完整窗口后闪缩；独立 --preview 仍使用原 1200×800 样板尺寸。
- AccountSession.get_login_defaults 的 server 在首次使用、配置缺失/损坏、空地址或无效地址时为 `https://www-api.u3493359.nyat.app:11664`（来源 client/config/config.json 的 release_config.base_url）。已保存的有效地址优先，仍可编辑；回退地址时关闭自动登录，不读取旧端配置或凭据、不主动探测默认服务器。
- Application 可由构造参数注入真实 AccountSession 与普通布局文件路径，默认仍由组装根创建服务并使用 user://window_layout.cfg；测试用独立存储路径及 loopback HTTP 服务，不修改用户设置。

验证 tests/test_application_window.gd：通过可见账户表单及真实 AccountSession/AccountApi 观察初始/失败/成功/退出窗口状态；检查自定义地址恢复与空配置回退，默认测试不连接预填地址。实际导出截图检查紧凑表单布局。

## ClientLog：客户端诊断日志

`src/storage/client_log.gd` 为 RefCounted，由应用创建并注入聊天/媒体；构造参数及归档规则见本文开头 ClientLog 启动归档契约，公开 `record(event, fields={}) -> Error` 与 `get_directory() -> String`。

- 按启动写独立 JSON Lines，逐条 flush；旧三文件不再写入或清理。单条不超过 4 KiB；目录/写入失败返回 Error，不阻塞聊天或谎报日志成功。只在主线程记录。
- 每条含 UTC time、单调 elapsed_ms 与固定格式 event。字段采用白名单：连接 phase/code，回复 reply_id 的 SHA256 前 12 位，has_audio/audio_chars/bytes/frames/sample_rate/channels/bits/final/audio_error/queued/volume/latency_ms 等布尔/数字；phase/code 只允许短 ASCII 字母数字下划线。忽略未知字段，不写用户名、密码、token、API key、正文、完整委托提示词或 Base64 音频。
- ChatSession 构造可注入 logger；记录 connection_state、reply_received（是否带音频、编码长度、终止/错误标志）及 system_error，不输出 payload 原文。应用启动记录 client_started。
- `ChatSession.get_log_directory() -> String` 供 ChatView 的“打开日志”按钮使用；无 logger 返回空串、按钮禁用。打开目录只经用户点击，不自动上传日志。

验证 tests/test_client_log.gd 的白名单、回复标识哈希、启动归档和失败返回；现有 loopback 聊天测试检查接收日志并确保合成秘密不出现。日志证明实际收包，不把接收结束等同播放结束。

验证：真实 ChatSession + WebSocketTransport + loopback 服务，观察发送状态、同 UUID 多包/隐藏/临时/音频错误文字、思考、表情顺序、断线和退出；通过 ChatView 可见控件触发发送，验证草稿与真实回复；默认自动化不访问真实账户。

## 完整语音重放与消息控件

ReplyAudio 由 Application 注入 AudioCache，缺少 cache 的既有调用保留在线播放。ChatSession.start 按 server/username 设置范围；stop 关闭范围，断线 reset 仅取消在途流与重放，保留范围及已完成缓存。以下接口为本轮重放切片契约：

- `set_scope(server, username) -> Error`：先 reset，再设置缓存账户范围；空值关闭范围。存储失败不阻止聊天及在线声音。
- `get_message_audio(id) -> Dictionary`：返回 available、duration、waveform（24 个真实幅值）、status（idle/playing/paused）、position（秒）、blocked（在线正在输出）、code；不向 UI 返回磁盘路径。未完整提交不可重放；缓存失败 code=CACHE_WRITE_FAILED。
- `replay(id) -> Error`：在线正在输出返回 ERR_BUSY；没有有效缓存返回 ERR_DOES_NOT_EXIST；同一正在播放 UUID 幂等；另一 UUID 停止旧声并从头开始。分块读取原始缓存交给 PcmStreamDecoder，错误终止并报告 REPLAY_FAILED。
- `pause_replay()` / `resume_replay()` / `stop_replay()`：幂等；暂停冻结混音与进度，继续从原位置，停止/自然结束回 idle、position=0；每次再播放从头开始。不提供寻址接口。
- `clear_cache() -> Error`：停止本地重放，取消当前所有在途流的缓存且不再创建同流文件；在线声音继续，完整文件仅按当前账户手动清理。失败报告 CACHE_CLEAR_FAILED，重新查询实际可用性。
- `message_audio_changed(id, state)`：缓存结果及约 20Hz 的实际重放进度定向通知，不触发聊天 changed。在线输出开始/结束同时通知已有音频控件 blocked 变化。`replay_finished(id, code)` 独立于仅在线使用的 playback_finished，绝不推进在线回复队列。

成功终止包、原生 finish 成功、文件提交成功三个条件同时满足才提供 available。临时标记为粘性，错误/断线/退出 abort 临时文件。写盘失败不影响解码/声音；现有完整缓存退出保留，无自动淘汰。在线实际开始输出时同步抢占播放或暂停的重放。所有嘴型按实际消耗帧，暂停/结束为 -1；重放不发出表情命令。日志增加 replay_started/replay_paused/replay_resumed/replay_stopped/replay_finished/replay_preempted，沿用白名单与 UUID 哈希。

ChatSession 公开同名 get_message_audio/replay/pause_replay/resume_replay/stop_replay/clear_cache 及 message_audio_changed；仅允许当前显示的 assistant 消息发起 replay，不接受任意路径。清理失败通过系统状态报告。UI 只调用 ChatSession。MessageBubble 提供 `set_audio_state(state)`、`audio_action(action)`（play/pause/resume/stop），只更新独立音频行，不重建气泡或设置正文。完整语音行显示重放、时长和非交互波形；播放/暂停时显示进度与停止。不可用时隐藏控件，保存失败显示“语音未能保存”。更多菜单清理须经 ConfirmationDialog 确认，取消不调用 clear_cache。

验证 tests/test_voice_replay.gd 从 ReplyAudio 观察真实混音、暂停进度、恢复、停止/切换、自然结束、抢占、终止后缓存、临时/错误/写盘失败、清理抑制与跨实例恢复；loopback test_voice_chat.gd 从 ChatSession 与可见控件验证按钮、消息不重复、表情不重发、文字选择不被进度刷新破坏。默认只用合成声音，WASAPI、真实服务听感分别记录。
