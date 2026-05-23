# 05 · Subagents 详解

> Subagent 是一个**完整的 Claude 实例**，但跑在一个独立的上下文窗口里，工具集可单独限制，跑完后只把"最终消息"回传给主 agent。

---

## 5.1 为什么需要 Subagent

主对话的上下文是有限的。两类工作特别会"刷屏"，浪费上下文：

1. **大量搜索**：grep 几十次、读上百个文件找一个符号。
2. **重复的小活**：把同一个分析模板套到 10 个文件上。

如果主 agent 直接做这些，几万 tokens 的中间结果就塞满了上下文，后面的工作就憋屈。**派 subagent 做，主 agent 只拿到一段结论**，干净。

第二个理由是**并行**：你可以一次性派多个 subagent 同时调研不同问题，主 agent 等齐结果再综合。

---

## 5.2 Subagent 的定义

```
.claude/agents/
└── <agent-name>.md
```

frontmatter：

```yaml
---
name: code-explainer
description: 用 Subagent 独立上下文逐行解释一段代码...
tools: Read, Grep, Glob       # 工具白名单，硬约束
model: sonnet                  # 可选：换便宜/快速模型
---
```

正文就是 subagent 的系统提示。它会被 Harness 当作"派单 prompt 模板"。

本仓库的例子：[.claude/agents/code-explainer.md](../../.claude/agents/code-explainer.md)

---

## 5.3 调用方式

主 agent 用内置的 `Agent` 工具派单。用户层面有几种触发：

1. **显式**：用户说"用 code-explainer 解释 sample.py" —— 主 agent 看到名字会调度。
2. **隐式**：subagent 的 description 写得明确（"自动调用此 agent 当…"），主 agent 自行判断派单。
3. **强制**：在自定义 slash command 里直接写"调用 code-explainer agent…"。

派单时，主 agent 传给 subagent 的 prompt 是**自包含的** —— subagent 看不到主对话历史，所以 prompt 里要把背景、目标、约束都写清楚。

---

## 5.4 Subagent 不见的 vs 看得见的

| 主 agent 看得到 | Subagent 看得到 |
|---|---|
| 用户原始消息 | 主 agent 写给 subagent 的派单 prompt |
| 所有工具结果 | 自己调用的工具结果 |
| Subagent 的**最后一条消息** | 自己的对话历史 |
| ❌ Subagent 的中间步骤 | ❌ 主对话历史 |
| | ❌ 别的 subagent 在做什么 |

这是"独立上下文窗口"的字面含义。

---

## 5.5 工具白名单的实际效果

frontmatter 里的 `tools: Read, Grep, Glob` 是**硬约束**：subagent 即使想调 Edit 也不会被 Harness 放行。这让你能造"只读研究员" subagent，安心派去探索。

留空 `tools` 字段表示继承主 agent 的全部工具。

---

## 5.6 并行 / 串行 / 后台

- **并行**：主 agent 在同一条消息里发出多个 Agent 调用 → 并行执行。
- **串行**：分多条消息发出 → 串行。
- **后台**：`run_in_background: true` → 立刻返回 ID，subagent 在后台跑，主 agent 继续做别的，跑完会被通知。

---

## 5.7 与 Skill 的对比

| 维度 | Skill | Subagent |
|---|---|---|
| 上下文 | 共享主线程 | 独立窗口 |
| 加载成本 | 描述常驻、正文按需 | 派一个就开一个 Claude 实例 |
| 输出 | 直接产文本/调工具 | 把结论作为"工具结果"返回 |
| 适合场景 | "怎么做某件事"的操作手册 | "把这件事做完、告诉我结果"的封装任务 |

---

## 5.8 试试看

1. 说："用 code-explainer 解释 [playground/sample.py](../playground/sample.py)" —— 主 agent 应该派单。
2. 观察 subagent 跑完后，主 agent 拿到的只是结论摘要，而不是整个文件的逐块解释。
3. 试试让主 agent 同时派 `code-explainer` 解释 sample.py 和另一个文件 —— 看两个 subagent 是否并行。

下一章：[06-slash-commands.md](06-slash-commands.md) — 自定义 /命令。
