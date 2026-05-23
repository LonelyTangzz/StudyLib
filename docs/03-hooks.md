# 03 · Hooks 机制详解

> Hook 是 Harness 暴露给你的"事件总线"。它在固定的时机调用你写的外部脚本，让你能拦截、记录、改写、通知 —— 不用碰模型，也不用碰 CLI 源码。

---

## 3.1 Hook 的本质

> **Hook 是个外部进程。** Harness 把事件相关的 JSON 写到该进程的 stdin，等它结束后读 stdout/exit code，根据约定执行下一步。

这意味着：
- Hook 可以用任何语言写（PowerShell、Bash、Python、Go 二进制都行）。
- Hook 出错（崩溃、超时）不应该让 Claude 卡死 —— Harness 有默认放行策略。
- Hook 拿不到模型上下文，只拿到当前事件的小 JSON。

---

## 3.2 输入 / 输出协议

**stdin**（Harness → hook）一定是一个 JSON 对象，至少包含：

```json
{
  "session_id":    "abc123",
  "transcript_path": "C:/.../transcript.jsonl",
  "cwd":           "E:/WorkSpace/Harness Demo",
  "hook_event_name": "PreToolUse",
  "tool_name":     "Bash",
  "tool_input":    { "command": "git status" }
}
```

不同事件附加字段不同（PostToolUse 还会有 `tool_response`、Stop 没有 `tool_name` 等）。

**输出**有两种方式控制 Harness：

### 方式 A：exit code

| 退出码 | 含义 |
|---|---|
| 0 | 成功（默认放行） |
| 2 | **阻塞**当前工具，stderr 内容会作为错误反馈给模型 |
| 其他非 0 | 视为脚本错误，不阻塞 |

### 方式 B：stdout JSON（更精细）

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",       // "allow" / "deny" / "ask"
    "permissionDecisionReason": "命中黑名单"
  }
}
```

PostToolUse 还能用 `additionalContext` 字段往模型上下文里追加信息。

---

## 3.3 八类事件回顾（带触发时机示意）

```
对话开始 ──▶ SessionStart
用户输入 ──▶ UserPromptSubmit
              │
              ▼
        模型决定调用工具
              │
              ▼ ←─── PreToolUse  ★ 能拦截
        执行工具
              │
              ▼ ←─── PostToolUse  ★ 能改上下文
        把结果回传模型
              │
              ▼
        模型继续生成 / 再次工具调用 ...
              │
回合结束 ──▶ Stop
子 agent 回合结束 ──▶ SubagentStop
上下文将被压缩 ──▶ PreCompact
任意时刻弹通知 ──▶ Notification
```

---

## 3.4 本仓库的三个 hook

### [block-dangerous.ps1](../.claude/hooks/block-dangerous.ps1) — PreToolUse 拦截

用正则匹配 `rm -rf /`、`mkfs`、`dd if= of=/dev/`、fork bomb。命中就输出 `permissionDecision: deny` 的 JSON。

试触发：让 Claude 跑 `Bash("rm -rf /")` —— 模型应该会收到 deny 反馈，并解释为何不执行。

### [log-edits.ps1](../.claude/hooks/log-edits.ps1) — PostToolUse 日志

在 Edit/Write/NotebookEdit 成功后追加一行到 `.claude/logs/edits.log`：

```
[2026-05-23 21:42:11] Edit  E:/WorkSpace/Harness Demo/playground/sample.py
```

不阻塞，纯审计。

### [stop-notify.ps1](../.claude/hooks/stop-notify.ps1) — Stop 回合结束

写 `.claude/logs/stop.log` 一行。注释里也演示了用 BurntToast 弹桌面通知的写法。

---

## 3.5 Hook 设计的几条经验

1. **快**。Hook 串行在工具调用路径上，慢 hook 会让对话感觉卡顿。控制在 200ms 内。
2. **稳**。Hook 崩溃不应该影响工作。用 try/catch 兜底，宁可"漏掉一次记录"也别"卡死一次对话"。
3. **小**。一个 hook 只做一件事。要同时挂"日志 + 通知 + 校验"就注册三个 hook，不要塞一个大脚本。
4. **可观测**。Hook 自己写日志，否则它出问题你完全不知道。
5. **路径用绝对**。`${CLAUDE_PROJECT_DIR}` 是你的好朋友，别假设 cwd 是项目根。

---

## 3.6 试试看

1. 让 Claude 编辑 [playground/sample.py](../playground/sample.py)，然后 cat [.claude/logs/edits.log](../.claude/logs/edits.log) 看是否出现新行。
2. 让 Claude 跑 `dd if=/dev/zero of=/dev/sda` —— 应该被拦。
3. 在 [block-dangerous.ps1](../.claude/hooks/block-dangerous.ps1) 里加一行 `Write-Host "DEBUG: $cmd"`，再观察 Claude Code 输出 —— 你会看到 hook 的 stderr 被透出。

下一章：[04-skills.md](04-skills.md) — Skills 的写法、触发与最佳实践。
