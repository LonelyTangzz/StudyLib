# Harness Demo · 项目上下文

> **这个文件是 CLAUDE.md 机制本身的演示。**
> 每次 Claude Code 在此目录下启动对话时，它的内容会被**自动**注入到系统提示里，不消耗用户的对话轮次。这就是 Claude "怎么记住项目规矩"的基础设施。

---

## 项目目的
这是一个用于讲解 Claude Code Harness（运行时）各扩展点的演示仓库。所有 `.claude/` 下的配置都是教学样例，结构上力求"最小可运行"。

## 协作约定（示例规则）
1. 编辑 [playground/](playground/) 里的文件随意；但**不要**改 [.claude/](.claude/) 里的东西，除非用户明确要求 —— 它们是教学样例。
2. 解释概念时优先引用本仓库内的真实文件（用 `[name](path)` Markdown 链接），不要凭空举例。
3. 写新文档时维持现有风格：开头一句话定位 → 表格/代码块 → "试试看"小节。

## 代码风格
- 文档：中文为主，技术名词保留英文（hook、subagent、slash command 等）。
- Hook 脚本：PowerShell（用户机器是 Windows 11 + PowerShell 5.1）。
- 示例代码：Python 3，最小依赖，能直接 `python` 执行。

## 这个文件如何在生效
当你在本目录里和 Claude 对话时，CLAUDE.md 的内容会通过 Harness 注入到上下文。验证方法：问 "本仓库的协作约定第 1 条是什么？" —— Claude 应该能直接答出来，不需要先 Read 这个文件。

## 加载链路
项目根 CLAUDE.md（本文件） → 父目录 CLAUDE.md（如果有） → `~/.claude/CLAUDE.md`（用户全局，如果有）。三者会被一起拼进系统提示。
