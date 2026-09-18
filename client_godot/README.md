# AgentLuo · Godot Windows 客户端

功能基线：`79ae2c0`。当前为独立开发工程，实际完成范围见 [进度](../docs/开发进程文档/开发进度/Godot-Windows客户端.md)。尚未替换旧端，不读取旧端凭据。

## 构建

使用 Godot **4.7.1 standard / Windows x64**。通过 Godot 的 Manage Export Templates 安装同版本模板，或将锁定模板包中的 Windows x64 文件和 version.txt 放入 `%APPDATA%/Godot/export_templates/4.7.1.stable/`。依赖来源和 SHA-256 见 `dependencies.lock.json`。

```powershell
$env:GODOT_BIN = 'D:\godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File client_godot/scripts/check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File client_godot/scripts/build.ps1
```

也可以显式传入 `-Godot <exe>`。构建脚本不下载依赖、不连接服务端；失败返回非零并保留 `artifacts/` 中的日志。输出 `dist/AgentLuo.exe` 和 `AgentLuo.pck` 必须一起分发。headless 启动检查不代表视觉、GPU 或真机验收。

开发时在 Godot 中导入 `project.godot`。本地数据使用独立的 `%APPDATA%/AgentLuo-Godot`，不写入安装目录。
