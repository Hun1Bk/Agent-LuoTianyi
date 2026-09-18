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
