---
description: 把当前未提交改动汇总成一段 CHANGELOG 风格的条目
argument-hint: "[版本号，可选，例如 v0.2.0]"
allowed-tools: Bash(git status), Bash(git diff:*), Bash(git log:*)
model: claude-sonnet-4-6
---

# /changelog $ARGUMENTS

为当前工作树生成一段 Keep-a-Changelog 风格的条目。

## 步骤

1. 运行 `git status` 与 `git diff --stat` 看改动范围。
2. 运行 `git diff` 看具体改动（必要时分文件读，避免 diff 太大）。
3. 按以下分类组织（每类不超过 5 条）：
   - **Added** — 新功能
   - **Changed** — 既有功能的变化
   - **Fixed** — bug 修复
   - **Removed** — 删除的功能
4. 输出 Markdown，例如：

```md
## [$ARGUMENTS] - $(today)
### Added
- ...
### Changed
- ...
```

## 注意

- 如果当前不是 git 仓库，直接告知用户并退出。
- 如果没有 staged/unstaged 变更，输出"无变更"。
- `$ARGUMENTS` 是用户在 `/changelog` 后输入的文本。如果为空，用 `Unreleased` 代替。

---

## 教学注释（自定义 slash command 知识点）

文件路径：`.claude/commands/<name>.md` → 命令名就是 `/<name>`。

Frontmatter 字段：
- `description` — 列在 `/help` 里
- `argument-hint` — UI 自动补全提示
- `allowed-tools` — 工具白名单（命中即免提示）
- `model` — 强制用指定模型跑该命令

正文是一个 prompt 模板，`$ARGUMENTS` 会被替换成用户在命令后输入的文本。
