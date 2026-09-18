# Godot 客户端 interface

已交付：基线与构建。当前切片：**真实 Live2D 显示与控制**。网络、媒体接口在对应切片中补充，未列接口不视为已实现。

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
