# StudyLib · 学习资料合集

> 我个人的学习资料库。当前收录两个方向的完整整理：**Claude Code Harness（AI 编程运行时）** 和 **架构师能力手册**。
>
> 每个板块自包含、可独立阅读，结构上做到"打开就能学、跑得起来、查得到"。

---

## 板块一览

| 板块 | 路径 | 一句话定位 | 篇幅 |
| --- | --- | --- | --- |
| 🤖 Claude Code Harness 演示 | [claude-code-harness/](claude-code-harness/) | 用一个**可运行**的完整 demo 讲清 Claude Code 运行时的所有扩展点（settings、hooks、skills、subagents、slash commands、MCP、CLAUDE.md） | 7 章 + 1 套可运行配置 |
| 🏛️ 架构师能力手册 | [architect-handbook/](architect-handbook/) | 系统讲解架构师需掌握的能力体系：从技术基础到分布式、从安全到 DevOps、从业务到软技能 | 16 章 / 约 5000 行 |

---

## 仓库结构

```
StudyLib/
├── README.md                       ← 你正在看的总览
├── CLAUDE.md                       ← 顶层项目上下文（被 Claude Code 自动注入）
│
├── .claude/                        ← Harness 配置（必须在根目录才生效）
│   ├── settings.json               ← 权限 / 环境变量 / hook 注册
│   ├── hooks/                      ← PreToolUse / PostToolUse / Stop 脚本
│   ├── skills/                     ← 自定义 skill
│   ├── agents/                     ← 自定义 subagent
│   ├── commands/                   ← 自定义 slash command
│   └── mcp.json.example            ← MCP server 配置范例
│
├── claude-code-harness/            ← 板块 1：Harness 学习资料
│   ├── README.md                   ← Harness 板块的导览
│   ├── docs/                       ← 7 章详解
│   └── playground/                 ← 触发各机制的试验场
│
└── architect-handbook/             ← 板块 2：架构师手册
    ├── README.md                   ← 手册总索引
    └── 01-…-16-….md                ← 16 章
```

> ⚠️ **注意**：`.claude/` 必须留在仓库根目录，因为 Claude Code 启动时只会读取当前工作目录下的 `.claude/`。不要把它挪进 `claude-code-harness/`，否则配置全部失效。

---

## 怎么开始

- **想学 Claude Code 怎么定制 / 怎么写 hook / 怎么接 MCP**
  → 进 [claude-code-harness/](claude-code-harness/)，从它的 README 开始读

- **想系统补架构师知识 / 准备晋升答辩 / 找特定主题查阅**
  → 进 [architect-handbook/](architect-handbook/)，从它的 README 开始读

- **想知道这个仓库为什么这么组织、CLAUDE.md / .claude/ 是什么**
  → 继续读下面

---

## 关于 CLAUDE.md 和 .claude/

如果你在这个目录里用 Claude Code 打开对话：

1. 根目录的 [CLAUDE.md](CLAUDE.md) 会被**自动注入**到系统提示，告诉模型这个仓库是什么、协作规则是什么。
2. [.claude/](.claude/) 下的配置（权限、hooks、skills、subagents、slash commands）会全部生效。
3. 也就是说，这个仓库本身就在**演示** Claude Code Harness 的全部能力——你正在用的工具就是被你正在学的东西。

具体怎么配置、每个文件什么作用，看 [claude-code-harness/](claude-code-harness/) 板块。

---

## 后续可能添加的方向

这是一个会持续扩充的库。如果你打算往里加新板块，建议保持以下约定：

- 每个板块一个**顶层文件夹**（`xxx-handbook/`、`xxx-notes/` 之类）
- 板块内自包含：自己的 README + 自己的内部链接
- 板块之间**不互相引用**，方便独立读、独立删
- 跨板块的"工具级"配置（`.claude/`、`.github/` 等）放仓库根
