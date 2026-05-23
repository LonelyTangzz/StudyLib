# playground/

试验靶子。让 Claude 在这里做任何修改都安全，不会影响 `.claude/` 教学样例。

## 文件

| 文件 | 用途 |
|---|---|
| [sample.py](sample.py) | 一个最小 Python 脚本，用于触发 hooks / subagent / slash command 演示 |

## 推荐试验流程

1. **触发 PostToolUse hook**
   - 让 Claude 改 [sample.py](sample.py)（例如加一个参数）
   - 看 `.claude/logs/edits.log` 是否新增一行

2. **触发 PreToolUse hook 拦截**
   - 让 Claude 跑 `rm -rf /tmp/test`（演示用，安全路径但命中正则）
   - 应被 [.claude/hooks/block-dangerous.ps1](../../.claude/hooks/block-dangerous.ps1) 拦下

3. **触发 Subagent**
   - 说"用 code-explainer 解释 [sample.py](sample.py)"
   - 观察主对话拿到的只是结论摘要

4. **触发 Slash Command**
   - 改完 sample.py 后输入 `/changelog v0.1.0`
   - 看生成的 Keep-a-Changelog 条目

5. **触发 Skill**
   - 说"问候一下用户"
   - 观察 greet-user skill 被加载并产出问候语

6. **触发 Stop hook**
   - 任意完成一次对话回合
   - 看 `.claude/logs/stop.log` 是否新增一行
