# MCP 制作工具链

本项目保留两类 Godot 工具，职责不重叠：

- 仓库内 `res://addons/godot_ai` 3.0.7：Godot 编辑器内的场景检查、截图和 `McpTestSuite` 测试。
- `@coding-solo/godot-mcp` 0.1.1：从 Codex 启动/停止 Godot、读取运行日志和执行项目级场景操作。
- `blender-mcp` 1.6.0（GitHub 提交 `e3ece087`）：仅在需要制作或检查 3D 资产时连接 Blender；核心 HUD 不依赖它。当前 PyPI 依赖解析缺少 `mcp.server.fastmcp`，因此固定使用已验证的 GitHub 提交。

## 前置环境

- Godot 4.7.1
- Node.js 18+
- Blender 3.0+
- `uv/uvx`，Blender MCP 固定使用 Python 3.11

首次克隆后先让 Godot 完成一次编辑器导入，再通过 MCP 运行项目，否则全局 GDScript 类缓存可能尚未生成。

## Codex 配置

仓库的 `.codex/config.toml` 使用可移植命令。若从 Windows 桌面启动 Codex 时找不到 `uvx`，在个人 `~/.codex/config.toml` 中将 Blender 的 `command` 改为 `where uvx` 返回的绝对路径；不要把个人路径提交到仓库。

Blender MCP 默认设置 `DISABLE_TELEMETRY=true`。Blender 插件内的 Poly Haven、Sketchfab、Hyper3D、Hunyuan3D 等在线资产和生成入口保持关闭，除非具体任务明确需要并已确认授权和来源。

同一时间只由一个 Codex 客户端启动一份 Blender MCP；在 Blender 的 3D View 侧栏中点击连接后再调用场景工具。

## 验证

1. `codex mcp list` 显示 `godot` 和 `blender` 已启用。
2. Godot MCP 返回 4.7.1，能运行项目并读取无错误日志。
3. Blender 中启用 `Interface: Blender MCP`，启动连接后能读取默认场景信息。
4. 不将 API 密钥、个人绝对路径、Blender 偏好文件或 MCP 缓存提交到 Git。
