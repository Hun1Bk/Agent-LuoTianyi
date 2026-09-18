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
