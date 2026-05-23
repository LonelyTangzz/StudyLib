# 01 · Harness 整体架构与生命周期

> Claude Code 不是"模型 + 一个聊天框"。模型只会输出文本和调用工具，**所有其他能力都来自 Harness**。这一章解释 Harness 由哪些组件组成、一次对话从输入到输出经过哪些步骤。

---

## 1.1 三层心智模型

```
       用户输入
           │
           ▼
┌───────────────────────┐
│   Harness（CLI 进程）   │  ← 你能改的所有"扩展点"都在这一层
│                       │
│  • Settings 合并       │
│  • CLAUDE.md 注入      │
│  • 权限检查 / Hook     │
│  • 工具实现 / MCP 代理 │
└──────────┬────────────┘
           │ 把"系统提示 + 历史 + 用户消息 + 工具结果"打包发给 API
           ▼
┌───────────────────────┐
│   Anthropic API        │
│   (Claude Opus 等)     │  ← 模型只做两件事：生成文本 / 请求工具调用
└──────────┬────────────┘
           │ 返回文本 / tool_use
           ▼
┌───────────────────────┐
│   Harness 再次接管     │
│   • 渲染文本给用户      │
│   • 执行 tool_use      │
│   • 把结果塞回历史      │  ← 循环往复，直到模型不再请求工具
└───────────────────────┘
```

**关键启示**：你看到的每个 Claude "行为"——拒绝运行 `rm -rf`、自动读 CLAUDE.md、把 `/changelog` 翻译成具体提示——都是 Harness 在某一步插的手。模型本身没那么"聪明"，它只是被喂了 Harness 准备好的上下文。

---

## 1.2 一次对话的完整生命周期

以"用户说『把 sample.py 改成支持参数』"为例：

| 步骤 | 由谁执行 | 做什么 |
|---|---|---|
| 1 | Harness | 启动时合并 user/project/local 三层 settings |
| 2 | Harness | 把 [CLAUDE.md](../../CLAUDE.md) 与父目录 CLAUDE.md 拼接到系统提示 |
| 3 | Harness | 把可用工具清单（含 MCP server 暴露的）也塞进系统提示 |
| 4 | Harness | 列出 skills 的 frontmatter（name + description），**正文不加载** |
| 5 | Harness | 把用户消息附上"环境块"（OS、cwd、git 状态）发给模型 |
| 6 | 模型 | 决定先 Read sample.py |
| 7 | Harness | **PreToolUse hook 触发**（[block-dangerous.ps1](../../.claude/hooks/block-dangerous.ps1) 检查；Read 不命中黑名单，放行） |
| 8 | Harness | 检查 permissions：Read 命中 allow，免提示直接执行 |
| 9 | Harness | 把文件内容作为 tool_result 喂回模型 |
| 10 | 模型 | 决定 Edit 修改文件 |
| 11 | Harness | PreToolUse → permissions → 执行 Edit |
| 12 | Harness | **PostToolUse hook 触发**（[log-edits.ps1](../../.claude/hooks/log-edits.ps1) 写日志） |
| 13 | 模型 | 输出"我把 sample.py 改好了" |
| 14 | Harness | **Stop hook 触发**（[stop-notify.ps1](../../.claude/hooks/stop-notify.ps1) 记录回合结束） |

---

## 1.3 八类 Hook 事件全景

| 事件 | 何时触发 | 典型用途 |
|---|---|---|
| `SessionStart` | 新会话开始 | 注入项目专属上下文、读密钥 |
| `UserPromptSubmit` | 用户按下回车，但模型还没看到 | 重写/审查用户输入 |
| `PreToolUse` | 模型请求调用工具，但还没执行 | **拦截**危险操作、改参数 |
| `PostToolUse` | 工具执行完，结果还没回模型 | 日志、追加上下文、检查输出 |
| `Notification` | Harness 想弹通知（如等待审批） | 桥接到外部告警 |
| `Stop` | 主对话回合结束 | 总结、推送、清理 |
| `SubagentStop` | 子 Agent 回合结束 | 子任务审计 |
| `PreCompact` | 上下文将被压缩前 | 抢救要保留的信息 |

详细写法见 [03-hooks.md](03-hooks.md)。

---

## 1.4 为什么要理解这套生命周期？

- **调试**：模型"行为怪异"时，90% 是 Harness 的某个 hook/permission/CLAUDE.md 在干预，不是模型本身。
- **定制**：你能想到的几乎所有"我希望 Claude 自动 X"的需求，都是用 hook + skill + slash command 三件套实现的。
- **安全**：理解了"工具调用先经 PreToolUse → permissions → 才真正执行"，你就知道把守密钥/破坏性操作的钩子应该挂在哪。

下一章：[02-settings.md](02-settings.md) — 三层 settings 合并与权限系统。
