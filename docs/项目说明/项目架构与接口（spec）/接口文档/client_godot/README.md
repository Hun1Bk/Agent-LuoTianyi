# Godot 客户端 interface

当前切片：**基线与构建**。以下是本切片要交付的契约；后续角色、网络、媒体接口在对应切片中补充，未列接口不视为已实现。

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
