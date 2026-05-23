# 06 · 自定义 Slash Commands

> Slash command 是"用户写得最少、Claude 跑得最对"的封装：用户输入 `/changelog v0.2`，Harness 把它翻译成一段预先写好的、带参数的 prompt，喂给模型。

---

## 6.1 文件位置 = 命令名

```
.claude/commands/<name>.md   →  /<name>
```

例如 [.claude/commands/changelog.md](../../.claude/commands/changelog.md) 对应 `/changelog`。

子目录会变成命名空间：`.claude/commands/git/sync.md` → `/git:sync`（不同版本展示形式略有差异）。

---

## 6.2 Frontmatter 字段

```yaml
---
description: 列在 /help 里的一行说明
argument-hint: "[版本号，可选]"
allowed-tools: Bash(git status), Bash(git diff:*)
model: claude-sonnet-4-6
---
```

| 字段 | 作用 |
|---|---|
| `description` | `/help` 里看到的解释 |
| `argument-hint` | UI 自动补全提示 |
| `allowed-tools` | 命令期间的工具白名单（命中即免提示，相当于一次性 permissions.allow） |
| `model` | 这条命令强制用某个模型跑（不影响别的对话） |

都可省略，省略就继承会话默认。

---

## 6.3 正文 = Prompt 模板

正文是 Markdown，Harness 会把整段当作 prompt 发给模型。`$ARGUMENTS` 是占位符，会被替换成用户在命令名后输入的所有文本：

```
用户输入：/changelog v0.2.0
注入提示中的 $ARGUMENTS → "v0.2.0"
```

更多占位符：
- `$1`、`$2` ... 分别取第 N 个参数（按空格切）
- `${ENV_VAR}` 读环境变量

---

## 6.4 内置 slash command vs 自定义

内置命令（`/help`、`/config`、`/clear` 等）是 CLI 硬编码的。**用户输入的 `/<name>` 如果不是内置命令，Harness 才会去 `.claude/commands/` 找。**

所以你不能用同名覆盖内置命令。建议自定义命令的名字带项目前缀，避免歧义：`/demo-changelog` 比 `/changelog` 更稳。

---

## 6.5 命令 vs Skill vs 直接说话

| 我想要... | 推荐用 |
|---|---|
| 我（用户）频繁触发同一动作 | **Slash command** |
| 模型自己判断时机触发 | **Skill** |
| 一次性的随手任务 | 直接说话 |

Slash command 的优势是**显式 + 可控**：参数清晰、工具白名单可锁、模型可换。

---

## 6.6 试试看

1. 输入 `/changelog v0.1.0` —— 观察 Claude 把 `$ARGUMENTS` 替换后生成的 changelog 模板。
2. 把 [changelog.md](../../.claude/commands/changelog.md) 的 `model` 改成 `claude-haiku-4-5-20251001`，再跑一次 —— 速度变快、风格略变。
3. 新建 `.claude/commands/explain-file.md`，让它接收一个文件路径，调用 [code-explainer](../../.claude/agents/code-explainer.md) subagent —— 实现"命令 → subagent"组合。

下一章：[07-mcp.md](07-mcp.md) — 用 MCP 把外部系统接进来。
