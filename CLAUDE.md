# StudyLib · 项目上下文

> 这是我的个人学习资料库。当前收录两个学习板块：
>
> 1. **Claude Code Harness 演示** ([claude-code-harness/](claude-code-harness/))
> 2. **架构师能力手册** ([architect-handbook/](architect-handbook/))
>
> 本 CLAUDE.md 会被 Claude Code 自动注入到系统提示，不消耗对话轮次 —— 这本身就是 [claude-code-harness/](claude-code-harness/) 在演示的机制之一。

---

## 协作约定

1. **不要随意改 [.claude/](.claude/) 下的东西** —— 那是 Harness 板块的教学样例，结构上是"最小可运行"，乱改会破坏演示效果。
2. **不要跨板块互相引用** —— `claude-code-harness/` 和 `architect-handbook/` 互相独立，新加内容也请保持这个边界。
3. **写新文档维持现有风格**：开头一句话定位 → 表格 / 代码块 / 列表 → 末尾"试试看"或"自检清单"小节。
4. 解释概念时优先**引用本仓库的真实文件**（用 `[name](path)` Markdown 链接），不要凭空造例。

## 内容归属

| 区域 | 谁来管 | 谁不该动 |
| --- | --- | --- |
| [.claude/](.claude/) | Harness 板块（教学样例） | 一般日常学习别动 |
| [claude-code-harness/](claude-code-harness/) | Harness 学习资料（文档 + playground） | 改前先看 README |
| [architect-handbook/](architect-handbook/) | 架构师手册（16 章） | 任意修订/扩充，但**不要引用 Harness 板块** |
| 仓库根 README/CLAUDE | 整个 StudyLib 的入口 | 加新板块时同步更新 |

## 代码风格

- 文档语言：**中文为主**，技术名词保留英文（hook、subagent、slash command、SLO、Raft 等）。
- Hook / 脚本示例：**PowerShell**（用户机器是 Windows 11 + PowerShell 5.1）。
- 代码示例：**Python 3**，最小依赖，能直接 `python` 执行。
- Markdown 表格分隔行用 `| --- | --- |` 风格（带空格，避免 lint 警告）。

## 这个文件如何在生效

当你在仓库根目录里和 Claude 对话时，这份 CLAUDE.md 的内容会通过 Harness 注入到系统提示。验证方法：问 "本仓库的协作约定第 2 条是什么？" —— Claude 应能直接答出"不要跨板块互相引用"，无需先 Read 此文件。

## 加载链路

项目根 CLAUDE.md（本文件） → 父目录 CLAUDE.md（如果有） → `~/.claude/CLAUDE.md`（用户全局，如果有）。三者拼进系统提示。

## 新增板块的约定

如果以后往 StudyLib 里加新板块（比如 `golang-deep-dive/`、`db-internals/`），请：

- 顶层文件夹一个板块，**自包含**：自己的 README + 自己的内部链接
- **不互相引用**，方便独立读、独立删
- 在根 [README.md](README.md) 的"板块一览"表里加一行
- 跨板块共享的工具配置（`.claude/`、CI 配置等）放仓库根
