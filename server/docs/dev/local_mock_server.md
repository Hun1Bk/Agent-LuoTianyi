# 本地空服务端

`local_mock_server.py` 是一个不加载生产运行时的本地协议服务，供 Godot 和 Python 客户端联调及行为对比。

## 启动

在 `server` 目录执行：

```powershell
python local_mock_server.py
```

默认地址是 `http://127.0.0.1:60030`。也可以指定监听地址、端口和日志文件：

```powershell
python local_mock_server.py --host 127.0.0.1 --port 60030 --verbose --log-file .\local-mock.jsonl
```

将两个客户端的服务器地址都设置为 `http://127.0.0.1:60030`。服务端的账号、登录 token 和消息 token 只在当前进程内有效。

## 支持范围

- 账户：`/auth/public_key`、`/auth/login`、`/auth/auto_login`、`/auth/register`、`/auth/reset_account`
- 空数据：`/history`、`/preference/*`、`/dynamics*`
- 客户端模型能力：`/llm/client-model-types`（返回空 `types`）
- 图片路径更新：`/update_image_client_path`
- WebSocket：`/chat_ws`

历史、偏好、动态和未读数据为空。文本和图片互动会收到 ACK 以及空内容的终止 `agent_message`，不会调用模型或生成音频。

## 行为日志

控制台每行输出一个 JSON 对象。HTTP 记录方法、路径、状态码、耗时和摘要；WebSocket 记录连接编号、方向、事件类型、消息 ID、回复关联和 payload 摘要。

`--log-file` 会把同样的记录写入 JSONL，可分别启动两个客户端并比较事件顺序。`--verbose` 只展开非敏感字段；密码、token、Authorization、公钥、图片 Base64 和音频 Base64 始终脱敏为长度与哈希摘要。

服务端退出时会输出 HTTP 请求数、WebSocket 连接数、事件数和错误数。

## 相同行为脚本与本地对比

仓库提供一套固定的传输行为序列。Python 和 Godot 脚本执行相同步骤：公钥、注册、登录、自动登录、重置、空数据接口、动态和偏好接口、图片接口，以及 WebSocket 鉴权、心跳、输入中、文本、图片选择、触摸和图片事件。

- Python：`server/scripts/client_behavior_python.py`
- Godot：`client-godot/tests/run_client_behavior_comparison.gd`
- 比较器：`server/scripts/compare_client_behavior.py`
- 一键运行：`server/scripts/run_client_behavior_comparison.py`

需要已安装 Godot 4，并在 `server` 目录运行：

```powershell
python scripts/run_client_behavior_comparison.py --godot C:\path\to\godot.exe
```

也可以分别运行两个客户端，便于接入自己的 Godot 可执行文件：

```powershell
python scripts/client_behavior_python.py --log-file .\artifacts\client-behavior\python.jsonl
godot --headless --path ..\client-godot --script res://tests/run_client_behavior_comparison.gd -- `
  --server http://127.0.0.1:60030 `
  --log-file ..\server\artifacts\client-behavior\godot.jsonl
python scripts/compare_client_behavior.py `
  --python-log .\artifacts\client-behavior\python.jsonl `
  --godot-log .\artifacts\client-behavior\godot.jsonl `
  --report .\artifacts\client-behavior\comparison.json
```

每次运行会生成以下本地文件：

- `server.jsonl`：mock 服务端观察到的 HTTP/WebSocket 行为；
- `python.jsonl`、`godot.jsonl`：两个客户端各自发出和收到的行为；
- `comparison.json`：归一化后的逐条比较结果。

比较时会忽略时间戳、随机消息 ID、token、公钥和动态 ID，只比较步骤顺序、方向、HTTP 方法/路径、状态码、事件类型和 payload 字段形状。`equal: true` 表示两份客户端脚本的传输行为一致；差异会保留在 `differences` 数组中。

## 限制

这是本地协议 mock，不提供真实账号安全、数据库持久化、Agent 回复、历史图片或 LLM 能力。它不会导入 `server_main.py`、`ServerLifecycle` 或生产路由。
