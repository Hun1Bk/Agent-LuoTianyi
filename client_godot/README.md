# AgentLuo · Godot Windows 客户端

功能基线：`79ae2c0`。当前为独立开发工程，实际完成范围见 [进度](../docs/开发进程文档/开发进度/Godot-Windows客户端.md)。尚未替换旧端，不读取旧端凭据。

## 构建

使用 Godot **4.7.1 standard / Windows x64**。通过 Godot 的 Manage Export Templates 安装同版本模板，或将锁定模板包中的 Windows x64 文件和 version.txt 放入 `%APPDATA%/Godot/export_templates/4.7.1.stable/`。依赖来源和 SHA-256 见 `dependencies.lock.json`。

```powershell
$env:GODOT_BIN = 'D:\godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File client_godot/scripts/check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File client_godot/scripts/build.ps1
```

也可以显式传入 `-Godot <exe>`。构建脚本不下载依赖、不连接服务端；失败返回非零并保留 `artifacts/` 中的日志。输出 `dist/` 整个目录（EXE、PCK、插件 DLL 和 licenses）必须一起分发。headless 启动检查不代表视觉、GPU 或真机验收。

开发时在 Godot 中导入 `project.godot`。本地数据使用独立的 `%APPDATA%/AgentLuo-Godot`，不写入安装目录。

## Live2D 构建

工程附带锁定的 Windows x64 插件二进制和 shader。重建时检出 lock 中的 gd_cubism commit 及其 godot-cpp submodule，按上游文档将 Cubism SDK 5-r.1 放入插件源码 `thirdparty/`，使用 VS2022 C++ Build Tools、Python 3.11.9 和 SCons 4.7.0：

```powershell
python client_godot/scripts/build_cubism.py --source '<gd_cubism源码目录>'
```

脚本检查源码版本，在当前进程处理 Windows OEM 编码兼容问题，输出二进制 SHA-256；重建工具链变化时应复验并更新 lock，不能无声替换。许可和素材来源见 `licenses/`。

独立模型场景：`res://scenes/avatar_preview.tscn`。当前主入口显示真实账户表单；传入 `-- --preview` 才加载独立离线样板 `res://scenes/chat_preview.tscn`。Godot 4.7.1 官方 release 模板禁止命令行覆盖主场景，验证不得依赖该能力。

## 体验离线样板

运行 `dist/AgentLuo.exe -- --preview`。角色区滚轮缩放、右键拖动，底部按钮重置；中间分隔条调整宽度，以上设置会保存。左上切换真实模型表情；右上切换日常聊天、空白、断网、加载失败和思考状态。

聊天文本可选择复制；Enter 本地模拟发送，Shift+Enter 换行。图片按钮或 Ctrl+V 粘贴图片先打开预览，点击发送才追加演示消息；缩略图可再次打开。查看旧消息时发送不会强制滚到底部，使用“回到最新”。模拟口型按钮没有声音；样板不连接真实账户、消息或音频服务。

`check.ps1` 覆盖角色、构图、离线消息控制器和主场景键盘输入回归。真实 Windows IME、剪贴板、多档 DPI、拖动手感和集显性能尚需人工验收。此导出目录是视觉检查产物，不是最终安装程序。

截取账户页：`AgentLuo.exe -- --capture=<绝对PNG路径>`；截取样板增加 `--preview`，可再增加 `--scenario=empty/disconnected/error/thinking`。截图和 headless 检查不会自动登录真实账户。

## Windows 凭据扩展

`WindowsSecurity` 使用 CNG RSA-OAEP/SHA256 和当前用户 DPAPI。源码位于 `native/`，不需要额外运行时 DLL；编译使用上述锁定 godot-cpp 和 VS2022 工具链。

```powershell
python client_godot/scripts/build_security.py --godot-cpp '<锁定的godot-cpp目录>'
python client_godot/tests/run_security_interop.py --godot $env:GODOT_BIN
```

互操作测试 Python 需 `cryptography` 和 `fastapi`，仅测试时需要；测试隔离执行仓库 account.py 中原样的密钥生成/解密函数，避免其数据库及供应商导入副作用。它不验证整个 HTTP 服务。

若 MSVC 响应文件不能解析源码目录中的中文，可以 `New-Item -ItemType Junction -Path client_godot/native/godot-cpp -Value '<真实目录>'` 建立本地目录联接，然后以该联接路径传入 `--godot-cpp`。构建仍检查源码 commit；联接和对象文件不进入 Git 或导出包。

账户模块的本地 HTTP/凭据回归：在独立 Python 环境安装 `tests/requirements-auth.txt`，运行 `scripts/check_accounts.ps1 -Godot <exe> -Python <python.exe>`。测试只监听 127.0.0.1 随机端口，使用合成账户；客户端运行不依赖 Python。

聊天传输与界面回归：测试 Python 安装 `tests/requirements-websocket.txt`，运行 `scripts/check_network.ps1 -Godot <exe> -Python <python.exe>`。真实 Godot WebSocketPeer 连接随机端口的本地 fixture，覆盖认证、心跳、断线和稳定 ID 重试、真实输入框收发和退出清理；不连接真实账户服务器。`contracts/chat/reply_events.json` 由 Godot 收包链路与旧 Python 客户端实际解析器共同消费。

默认入口登录后进入真实文字聊天，图片、历史、语音等以进度文档中的实际完成范围为准；离线样板中的模拟能力不代表正式功能已经接入。

## 回复语音与诊断

正式聊天自动播放服务端 WAV/PCM 分片；同 UUID 聚合，后续回复等前一句实际播完再呈现。支持口型、音量保存、停止当前语音、错误及断线清理；完整语音以临时文件接收、成功终止及原生验证后提交，提供消息重放/暂停/继续/停止，波形来自原生 RMS，进度来自混音器消耗帧。在线语音抢占重放；停止在线声音不取消后续接收和缓存。原生 `PcmStreamDecoder` 与 `WindowsSecurity` 共用 DLL，按上面的 `build_security.py` 命令重建，需分发完整目录。

“更多 → 打开日志”查看 `user://logs/client.jsonl`，默认实际目录 `%APPDATA%/AgentLuo-Godot/logs`；最多三份、每份 2 MiB。用哈希 reply_id 关联 `reply_received → audio_received → audio_format/audio_decoded → audio_receive_finished → audio_playback_started/finished`（接收/播放可交错）。`audio_error` 的 code 定位错误，`audio_underrun` 记录供给不足；不会写入正文、token、密钥或 Base64。

`check.ps1` 增量解码及真实混音测试默认使用合成音频；`check_network.ps1` 还验证 loopback WebSocket 到播放器链路、顺序、隐藏音频、停止及断线。Windows 输出驱动验证可运行：

```powershell
& $env:GODOT_BIN --headless --audio-driver WASAPI --verbose --path client_godot --script res://tests/test_reply_audio.gd
```

该命令会向本机默认音频设备播放短合成音；AudioEffectCapture 检查非零混音输出及静音，不等同人工听感或真实服务验收。

未登录时仅显示 660×800 账户窗口，登录成功后展开角色和聊天，退出再收起。默认服务器沿用旧端 release_config.base_url；已保存的自定义地址优先。账户回归含窗口切换测试，原生窗口验证可运行 `run_account_tests.py --godot <exe> --script res://tests/test_application_window.gd --gpu`，仍仅连接本地 HTTP fixture。

语音缓存在 user://audio 按规范化服务器、账户与 UUID 隔离，退出及重启保留，只能手动清理，无自动容量/时间淘汰。“更多 → 清理本账号语音缓存”有确认窗口；清理同时取消在途流的缓存写入，保留正在输出的声音与聊天文字。当前没有历史加载，所以只为当前可见消息提供重放。日志记录 cache_committed/cache_error、replay_started/paused/resumed/stopped/finished/preempted，不写音频原文。

重放回归：`--headless --audio-driver WASAPI --path client_godot --script res://tests/test_voice_replay.gd`。真实 UI/角色截图：`tests/run_websocket_tests.py --godot <exe> --script res://tests/capture_voice_ui.gd --gpu`，只连接 loopback、使用合成语音，输出默认/最小/暂停/125%及150%内容缩放截图到 artifacts。内容缩放检查不能替代操作系统 DPI 切换与跨显示器验收。
