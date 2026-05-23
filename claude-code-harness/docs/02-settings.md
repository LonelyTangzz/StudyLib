# 02 · settings.json 与权限系统

> Settings 是你给 Harness 写的"运行手册"。它决定：哪些工具能免提示跑、哪些被直接拒、环境变量是什么、hooks 怎么挂、模型选哪一款。

---

## 2.1 三层合并

Claude Code 启动时按下面的优先级合并 settings：

```
~/.claude/settings.json                      ← user（全局，跨项目）
        ▼ 覆盖
<project>/.claude/settings.json              ← project（跟随仓库，可提交）
        ▼ 覆盖
<project>/.claude/settings.local.json        ← local（本机私有，应进 .gitignore）
```

合并规则：**对象浅合并、数组拼接、原子值覆盖**。所以 user 里的 `permissions.allow: ["Bash(ls)"]` 和 project 里的 `permissions.allow: ["Bash(git status)"]` 最终会得到两条。

---

## 2.2 本仓库的实际配置

看 [.claude/settings.json](../../.claude/settings.json)。重点字段：

### env

```json
"env": {
  "CLAUDE_DEMO_PROJECT": "harness-demo",
  "CLAUDE_DEMO_LOG_DIR": "${CLAUDE_PROJECT_DIR}/.claude/logs"
}
```

会在 Claude Code 进程启动时注入到环境变量，hook 脚本/bash 命令都能读。`${CLAUDE_PROJECT_DIR}` 是 Harness 内置变量，等于"包含 `.claude/` 的那个目录的绝对路径"。

### permissions（核心）

```json
"permissions": {
  "allow": [...],   // 命中即免提示
  "ask":   [...],   // 仍要弹确认
  "deny":  [...]    // 直接拒绝，模型会看到"被拒"的反馈
}
```

写法语法：

| 模式 | 含义 |
|---|---|
| `"Bash"` | 所有 Bash 调用 |
| `"Bash(git status)"` | 精确匹配命令 |
| `"Bash(git diff:*)"` | 前缀匹配（注意是冒号星号，不是空格星号） |
| `"Read(//**)"` | 所有文件读（`//` 前缀表示绝对路径根） |
| `"Read(./**/.env)"` | 所有 .env 文件 |
| `"Edit"` / `"Write"` | 所有写操作 |
| `"mcp__<server>__<tool>"` | 特定 MCP 工具 |

**优先级**：`deny > ask > allow`。所以即使 allow 写了 `Bash`，deny 里写了 `Bash(rm -rf /*)` 也会被拦。

### hooks

settings.json 是 hook 的**注册中心**。注册的脚本由外部 shell 执行，详见 [03-hooks.md](03-hooks.md)。

---

## 2.3 settings.local.json 是什么、要不要提交

`settings.local.json` 用来放**只属于这台机器/这个开发者**的覆盖：

- 公司 VPN 后才能用的 MCP server 配置
- 你个人偏好的 `defaultModel`
- 调试用的临时 `deny`

**强烈建议**把 `.claude/settings.local.json` 加进 `.gitignore`。本仓库为了演示没创建它，但真实项目里建议这样组织：

```
.claude/
  settings.json          ← 团队共享，提交
  settings.local.json    ← 个人私有，gitignore
```

---

## 2.4 常用 settings 字段速查

| 字段 | 作用 | 示例 |
|---|---|---|
| `model` | 默认模型 | `"claude-opus-4-7"` |
| `env` | 注入环境变量 | 见上 |
| `permissions` | 工具权限 | 见上 |
| `hooks` | 事件钩子注册 | 见 [03](03-hooks.md) |
| `enableAllProjectMcpServers` | 自动加载项目 `.mcp.json` | `true` / `false` |
| `apiKeyHelper` | 动态拿 API key 的脚本 | `"./scripts/get-key.sh"` |
| `cleanupPeriodDays` | 历史保留天数 | `30` |

完整字段表见官方文档（搜 "Claude Code settings reference"）。

---

## 2.5 试试看

1. 让 Claude 跑 `git status` —— 因为命中 allow，不会弹确认。
2. 让 Claude 跑 `git push origin main` —— 命中 ask，会弹确认。
3. 让 Claude 读 `./.env`（即便文件不存在）—— 命中 deny，直接被拒。
4. 在 [.claude/settings.json](../../.claude/settings.json) 里临时把 `Bash(git push:*)` 改成 deny，再让 Claude push，对比反馈。

下一章：[03-hooks.md](03-hooks.md) — Hook 协议、JSON I/O、阻塞工具的实战。
