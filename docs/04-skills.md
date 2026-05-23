# 04 · Skills 详解

> Skill 是给模型的一份"操作手册"。它的关键特性是**按需加载**：手册的标题永远在系统提示里，但正文只有模型决定需要时才会被读入上下文。

---

## 4.1 Skill 的文件结构

```
.claude/skills/
└── <skill-name>/
    ├── SKILL.md          ← 必须，frontmatter + 正文
    ├── helpers/          ← 可选，任意辅助文件
    │   └── template.txt
    └── scripts/
        └── do-it.ps1
```

SKILL.md 的 frontmatter 只有两个**必填**字段：

```yaml
---
name: greet-user
description: 按本机时区给用户打个招呼。当用户说"问候一下"...
---
```

正文是 Markdown，没有结构强制 —— 但通常会写：
1. 何时触发
2. 步骤
3. 输出格式
4. 约束 / 反例

---

## 4.2 加载机制（最关键的概念）

Claude Code 启动时：

1. 扫描所有 skill 目录，把每个 SKILL.md 的 frontmatter（**只有 name + description**）拼成一张"可用 skills 清单"塞进系统提示。
2. 正文**不加载**。
3. 模型在对话中如果"觉得"某个 skill 描述跟当前需求匹配，会发起一次"加载 skill"调用，Harness 才把正文喂进去。

**为什么这样设计？**
- 你可以写几十个 skill，每个 SKILL.md 写得很长（操作手册嘛），都不会膨胀上下文。
- 模型自己根据 description 做匹配，不需要你手动 invoke。
- 加载是显式动作，可以审计。

**因此 description 字段决定一切。** 写得越具体，匹配越准：
- ✅ "当用户说『打个招呼』、『say hi』、明确触发 /greet-user 时使用"
- ❌ "处理问候相关操作"

---

## 4.3 本仓库的 skill

[.claude/skills/greet-user/SKILL.md](../.claude/skills/greet-user/SKILL.md)

打开看 frontmatter 和正文的写法。试触发方法：说"问候一下用户" —— Harness 会通知模型 skill 可用，模型会请求加载。

---

## 4.4 Skill vs Subagent vs Slash Command —— 用哪个？

三者经常被混淆。判断标准：

| 你想要 | 用 |
|---|---|
| 模型在合适时机自动用一段操作手册 | **Skill** |
| 派一个独立上下文窗口的子 Claude 做活、只回传结论 | **Subagent** |
| 用户通过 `/foo` 触发一段固定 prompt | **Slash command** |

它们能组合：slash command 调用时可以写"请使用 X skill 完成 Y"，让用户的快捷指令触发 skill。

---

## 4.5 内置 skills

Claude Code 自带一些 skills（如 `update-config`、`verify`、`simplify`、`review`、`security-review` 等）。机制完全一样，只是装在 CLI 里而不是你项目里。

你可以列出当前可用 skill 的方法：让 Claude 回答 "当前会话有哪些 skills 可用？"，它从系统提示里就能答。

---

## 4.6 试试看

1. 说："问候我一下" —— 观察是否触发 greet-user。
2. 在 [SKILL.md](../.claude/skills/greet-user/SKILL.md) 的 description 里删掉"问候"两个字，再问同样的话 —— 你会发现模型不再触发，因为描述匹配度下降了。
3. 新建 `.claude/skills/echo-reverse/SKILL.md`，让它"接收一段文字、反转后输出"。重启对话，看模型能否在合适时机调用。

下一章：[05-subagents.md](05-subagents.md) — Subagent 独立上下文窗口。
