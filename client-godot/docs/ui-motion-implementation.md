# 登录与 P1 UI 动效实施说明

日期：2026-10-02。参考工作区的 `docs/ui-motion-plan.md`、登录与聊天 HTML 预览，在已有未提交 UI 改动上继续实现。保留 480×690 登录窗口和现有账户、草稿、阅读位置与窗口所有权行为。

## 已实现的行为

- 登录使用约 48px 输入框、16px 正文与主按钮、12px 辅助文字；头像圆环与蓝色光晕、半透明卡片、聚焦外发光、原生渐变纹理与圆角按钮遮罩。登录专用面板不再经过通用面板样式改写。
- 接通加载 spinner、错误文字强调与表单抖动、50ms 间隔的模式字段入场、弹层入场。自动登录结束前抑制工作区转场；手动登录播放转场。
- 气泡显示等待历史同步、排队、发送中、服务器已接收、失败、无法确认送达。ACK 只代表服务器内存接纳，文案不宣称业务完成或持久送达。
- 文本和图片仅在明确拒收或尚未入队时提供重发。已有请求复用原 `client_msg_id` 和完整发送内容；历史屏障后未入队的请求重新入队并映射回原本地气泡 ID。保持原时间，不增加气泡。未知送达、停止传输和活动请求不可手动重发。
- 新到达动画使用明确的实时信号，历史分页、流式更新与节点复用不重播。跳点占位是虚拟列表内部的装饰节点，不进入消息集合、可见业务 ID、时间分组或阅读锚点。首条实时回复移除占位。
- Latest/Unread 使用独立布局槽播放短过渡，隐藏时停止点击；平滑滚动被用户输入打断，并在布局变化后重算目标。语音按钮按压回弹，波形分界使用颜色插值和缩放。
- 动态、设置、日志和图片窗口的内容节点统一播放开关过渡，原生窗口仍交给 Host。关闭后重开取消旧回调。退出账号、来源失效和应用退出立即释放业务窗口，保持草稿确认与日志保留规则。
- 发布层遮罩淡入与面板滑入，关闭前保护草稿。图片通过独立变换节点实现按钮与滚轮缩放、鼠标中心缩放、左键平移、小图居中和大图边界限制；手动比例 5%–800%，换图、拖动和关闭取消旧动画。
- 模式变化、隐藏、释放及原生窗口最小化停止并复位循环动效，恢复窗口重新启动有效循环。玻璃与头像 shader 保留 CanvasItem 透明度，使父节点淡入淡出实际生效。

本轮不包含骨架屏、设置切页、用量圆环、动态详情或主题切换过渡，也不改服务器协议或存储格式。

## 接口与生命周期

- `UiMotion` 按节点和动画通道管理 Tween，支持 `cancel`、`cancel_all`、图片 `transform_to`、滚动 `property_to`；`update_window(window, active)` 接收平台适配器提供的显示状态。节点退出时释放 Tween，取消循环不等待 `finished`。
- `WindowHost.is_presentation_active()` 由桌面实现判断隐藏和最小化；UI 层不直接查询平台 API。`WindowChrome.motion_target_path` 指向内容节点，`close_window(on_closed, immediate=false)` 保持已有隐藏或销毁策略。
- `ChatSession.live_message_added(id, role)` 只在本地新增消息和首次展示实时回复时发出。`can_retry_message(id)` 查询当前重发资格，`retry_message(id)` 返回 `Error`。
- `WebSocketTransport.can_retry_event/retry_event` 与 outbox 的 `can_retry/retry` 保留终态拒收快照；停止账号时清理快照。重发期间同一消息不能再次入队。
- `VirtualMessageList.set_messages(messages, fresh_ids=[])` 显式接收入场 ID；`set_typing(active)` 只改变装饰；`is_scrolling_to_latest()` 用于浮动按钮显示。所有原有消息 ID 和阅读恢复契约保留。
- `MotionSlot` 接收容器布局，内容节点只在尺寸变化时同步静态尺寸，动画不逐帧修改布局大小。位移只作用于槽内内容。

## 验证入口

引擎为锁定的 Godot 4.7.1 Windows x64，GUI SHA-256：`323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a`。测试依赖安装在独立的 `artifacts/test-env`，保持仓库固定版本。正式运行器使用隔离 APPDATA 与本地 HTTP/WebSocket 夹具。

从客户端目录运行：

```powershell
$engine = 'D:\godot\godot4.7.1\godot.exe'
$python = (Resolve-Path 'artifacts/test-env/Scripts/python.exe').Path
./scripts/check.ps1 -Godot $engine -Python $python -SkipImport
./scripts/check_accounts.ps1 -Godot $engine -Python $python
./scripts/check_features.ps1 -Godot $engine -Python $python
./scripts/check_network.ps1 -Godot $engine -Python $python
& $python tests/run_feature_tests.py --godot $engine --script res://tests/ui/test_motion_presentation.gd --gpu
& $python tests/run_feature_tests.py --godot $engine --script res://tests/ui/test_login_presentation.gd --gpu
& $python tests/run_feature_tests.py --godot $engine --script res://tests/ui/test_ui_style_application.gd --gpu
& $python tests/run_feature_tests.py --godot $engine --script res://tests/ui/test_chat_review_layout.gd --gpu
& $python tests/run_dynamics_tests.py --godot $engine --script res://tests/test_dynamics_detail.gd --gpu
```

`tests/session/test_message_retry.gd` 和 `tests/ui/test_ui_motion.gd` 已接入基础检查。前者检查拒收重发、原始 envelope、重复点击、未知送达、停止、容量耗尽和图片；后者检查取消复位、历史门控、占位隔离、滚动更新、窗口重开、图片锚点和平移。GPU 运行后者还检查真实原生窗口最小化后的循环恢复。

冷缓存检查在不含 `.godot` 的独立副本执行完整 `check.ps1`。原工作区已有编辑器占用扩展 DLL，不能通过关闭用户编辑器或删除用户缓存获取通过；热缓存检查使用 `-SkipImport`，复杂度门禁仍执行。冷导入仅使用官方入口针对主题纹理生成竞态的单次重试。

## 证据与限制

本次最后运行的结果：

| 检查 | 结果 | 日志（相对 `artifacts/ui-motion/`） |
| --- | --- | --- |
| 原工程基础门禁与契约 | PASS，复杂度与解析零违规 | `core-final.log` |
| 冷缓存副本完整基础入口 | PASS，含导入 | `cold-final.log` |
| 账号与依赖边界 | PASS | `accounts-final.log` |
| 历史、图片发送、动态、设置、草稿与退出 | PASS | `features-final.log` |
| WebSocket、真实聊天、语音与触摸 | PASS | `network-final.log` |
| GPU 登录及逻辑缩放 | PASS | `login-gpu-final.log` |
| GPU 两主题 × 两图标组合 | PASS | `style-gpu-final.log` |
| GPU 1280×800 / 960×640 聊天布局 | PASS | `chat-layout-gpu-final.log` |
| GPU 动态发布与详情 | PASS | `dynamics-gpu-final.log` |
| GPU 动效、原生最小化恢复、图片操作 | PASS | `gpu-contract-final.log` |
| GPU P1 截图与自动登录转场抑制 | PASS | `motion-presentation-gpu.log` |

基线核心检查通过；登录聚焦样式两条断言失败，已通过清理重复 focus 并接入聚焦样式修复。基线账号表单实际通过，不沿用参考文档中需要忽略该测试的判断。系统 Python 缺失复杂度依赖，使用独立环境补齐后进行门禁检查。

正式检查和 GPU 日志保存在 `artifacts/ui-motion/`，实际引擎截图包括：

- `captures/login-register.png`、`login-failed.png`、`login-spinner.png`。
- `captures/chat-sending.png`、`chat-retry.png`、`chat-accepted.png`、`chat-typing-flat.png`、`chat-typing-crystal.png`。
- `captures/publish-overlay.png`、`publish-confirm.png`、`image-fit.png`、`image-wheel-zoom.png`、`image-original.png`。
- `artifacts/release-013/login-*.png`、`artifacts/ui-style/` 四种主题/图标组合，以及 `artifacts/ui-redraw-client/` 两种聊天尺寸。

已有部分热缓存运行打印主题 UID 回退到路径的警告；它不等同于解析失败，实际结果需同时检查退出码、错误输出与 PASS 标记。截图验证来自真实 OpenGL 引擎与本地夹具，不证明公共服务、真实系统 DPI、多屏、Windows 10、集显或长期性能；本轮没有打包、发布或提交 Git。
