# 07 · MCP（Model Context Protocol）集成

> MCP 是 Anthropic 主导的开放协议，专门用来**把外部系统包装成一组模型能调用的工具**。Claude Code Harness 是 MCP 的一个 host —— 你配置一个 MCP server，它的工具就自动出现在模型的工具清单里。

---

## 7.1 一个比喻

把 MCP 想成"USB for AI"：

- **MCP server** = 一个 USB 设备（数据库、Jira、Slack、文件系统、Browser），自带"驱动"声明自己有哪些操作。
- **MCP host**（Claude Code）= 电脑，插上设备后，"鼠标动得了"。
- **协议**（JSON-RPC over stdio/SSE/HTTP）= USB 协议，统一握手方式。

好处：一个 MCP server 写一次，所有支持 MCP 的 host（Claude Desktop、Claude Code、Cursor、Zed 等）都能用。

---

## 7.2 三种 transport

| Transport | 用在哪 | 启动方式 |
|---|---|---|
| **stdio** | 本地子进程 | Harness `spawn` 一个进程，stdin/stdout 收发 JSON-RPC |
| **HTTP** | 远程服务（推荐用于云端 SaaS） | Harness 发 POST 到指定 URL |
| **SSE** | 远程长连接 | Harness 走 Server-Sent Events |

---

## 7.3 在本仓库配置 MCP

[.claude/mcp.json.example](../.claude/mcp.json.example) 演示了三种 server：

### stdio 例：filesystem

```json
"filesystem": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "E:/WorkSpace/Harness Demo/playground"]
}
```

启用后，模型会获得 `mcp__filesystem__read_file`、`mcp__filesystem__write_file` 等工具，**作用域被限制在 playground 目录**。

### stdio 例：sqlite

```json
"sqlite": {
  "type": "stdio",
  "command": "uvx",
  "args": ["mcp-server-sqlite", "--db-path", "./playground/demo.db"]
}
```

模型能直接 `list_tables`、`query`、`describe_schema` —— 把数据库变成"上下文里的可查源"。

### HTTP 例：Linear

```json
"linear": {
  "type": "http",
  "url": "https://mcp.linear.app/sse",
  "headers": { "Authorization": "Bearer ${LINEAR_API_KEY}" }
}
```

`${LINEAR_API_KEY}` 从 settings 的 env 或系统环境变量解析。

---

## 7.4 启用流程

1. 把 `mcp.json.example` 复制为 `.mcp.json`（无前缀点也行：`mcp.json`，看版本）。
2. 在 [.claude/settings.json](../.claude/settings.json) 里加 `"enableAllProjectMcpServers": true`，或第一次启动时按提示授权。
3. 重启 Claude Code。
4. 让模型 "list available tools" —— 应该看到 `mcp__filesystem__*` 之类的工具。

---

## 7.5 MCP 工具的权限

MCP 工具走和 Bash/Edit 同一套 permissions 系统。例如只允许查询不允许写：

```json
"permissions": {
  "allow": ["mcp__sqlite__query", "mcp__sqlite__list_tables"],
  "deny":  ["mcp__sqlite__write_query"]
}
```

PreToolUse hook 也能拦 MCP 调用，matcher 写成 `mcp__sqlite__.*` 即可。

---

## 7.6 MCP vs Skill vs 自己写 Bash

| 我想接入... | 推荐 |
|---|---|
| 一个已有 MCP server 的成熟系统（Linear、GitHub、Postgres） | **MCP** |
| 一个 CLI 工具，命令简单 | **直接让模型 Bash 调它** |
| 一段固定多步操作流程 | **Skill** + Bash |

MCP 的好处是工具发现自动化 + 协议统一；坏处是要装/跑 server 进程。

---

## 7.7 试试看（不需要真启用）

1. 阅读 [mcp.json.example](../.claude/mcp.json.example) 三种配置。
2. 想想你日常用的哪个系统适合接 MCP（数据库？工单？知识库？）。
3. 去 [modelcontextprotocol.io](https://modelcontextprotocol.io) 浏览现成的 server 列表。

---

## 总结回到主线

到这里你已经走完了 Harness 的 7 个核心扩展点：

| 章节 | 扩展点 |
|---|---|
| [01](01-architecture.md) | 心智模型 + 生命周期 |
| [02](02-settings.md) | settings.json + permissions |
| [03](03-hooks.md) | 8 类 hook 事件 |
| [04](04-skills.md) | Skills 按需加载 |
| [05](05-subagents.md) | 独立上下文子 agent |
| [06](06-slash-commands.md) | 自定义 /命令 |
| [07](07-mcp.md) | MCP 外部系统接入 |

加上 [CLAUDE.md](../CLAUDE.md) 自动注入，**共 8 个机制**就构成了 Claude Code Harness 的全部"用户可定制面"。
