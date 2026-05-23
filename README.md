# Claude Code Harness 演示项目

> 一个**可运行**的 Claude Code 运行时（Harness）完整示例，覆盖 settings、hooks、skills、subagents、slash commands、CLAUDE.md、MCP 等核心机制。
>
> 目标：在一个项目里把所有"扩展点"摆出来，让你看得见、改得动、跑得起来。

---

## 1. 什么是 Claude Code Harness？

**Harness（运行时/外壳）** 是 Claude Code CLI 包裹在大模型外面的那一整套机制。模型本身只会"生成文本和调用工具"，但你能感知到的一切——权限提示、文件读写边界、自动注入的上下文、斜杠命令、subagent、hook 拦截、MCP 连接的外部系统——都是 Harness 在背后调度。

```
┌─────────────────────────────────────────────────────────┐
│                  Claude Code Harness                     │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐   │
│  │ Settings │───▶│  Hooks   │───▶│  Tool Execution  │   │
│  │  + Perms │    │ (拦截/记录)│    │ (Read/Bash/...)  │   │
│  └──────────┘    └──────────┘    └──────────────────┘   │
│        │                                  ▲              │
│        ▼                                  │              │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐   │
│  │ CLAUDE.md│───▶│  Model   │───▶│ Skills / Agents  │   │
│  │  (上下文) │    │ (Opus/...) │    │  / MCP / Slash  │   │
│  └──────────┘    └──────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 2. 项目结构与导览

```
Harness Demo/
├── README.md                       ← 你正在看的这份导览
├── CLAUDE.md                       ← 项目级"系统提示"（每轮自动注入）
│
├── docs/                           ← 分章节讲解（建议按编号顺序读）
│   ├── 01-architecture.md          ← Harness 整体架构与生命周期
│   ├── 02-settings.md              ← settings.json 三层合并 + 权限
│   ├── 03-hooks.md                 ← 8 类 hook 事件 + 拦截 / 日志实战
│   ├── 04-skills.md                ← Skills 是什么、怎么写、怎么触发
│   ├── 05-subagents.md             ← Subagent 独立上下文 + 并行调度
│   ├── 06-slash-commands.md        ← 自定义 /命令 的 frontmatter
│   └── 07-mcp.md                   ← MCP 协议把外部系统接进来
│
├── .claude/                        ← 项目级 Harness 配置（核心目录）
│   ├── settings.json               ← 权限 / 环境变量 / hook 注册
│   ├── hooks/
│   │   ├── block-dangerous.ps1     ← PreToolUse 拦截危险命令
│   │   ├── log-edits.ps1           ← PostToolUse 记录所有文件改动
│   │   └── stop-notify.ps1         ← Stop 事件桌面通知
│   ├── skills/
│   │   └── greet-user/
│   │       └── SKILL.md            ← 自定义 skill：按时区问候
│   ├── agents/
│   │   └── code-explainer.md       ← 自定义 subagent：解释代码片段
│   ├── commands/
│   │   └── changelog.md            ← 自定义 /changelog 命令
│   └── mcp.json.example            ← MCP server 配置范例
│
└── playground/                     ← 试验场：触发上面机制用的样例代码
    ├── sample.py
    └── README.md
```

---

## 3. 阅读路线（推荐顺序）

| 步骤 | 文件 | 你将学会 |
|---|---|---|
| 1 | [docs/01-architecture.md](docs/01-architecture.md) | 一次对话里 Harness 做了哪些事、各组件如何协作 |
| 2 | [docs/02-settings.md](docs/02-settings.md) | 三层 settings 合并、permissions 写法、env 注入 |
| 3 | [docs/03-hooks.md](docs/03-hooks.md) | 8 类 hook 事件、JSON 输入输出协议、阻塞工具调用 |
| 4 | [docs/04-skills.md](docs/04-skills.md) | SKILL.md frontmatter、按需加载、用户可见 vs 后台 |
| 5 | [docs/05-subagents.md](docs/05-subagents.md) | Subagent 独立上下文窗口、工具白名单、并行调度 |
| 6 | [docs/06-slash-commands.md](docs/06-slash-commands.md) | Markdown 写命令、参数占位符、模型/工具锁定 |
| 7 | [docs/07-mcp.md](docs/07-mcp.md) | MCP 是什么、stdio/SSE/HTTP、把数据库/Linear 等接进来 |

---

## 4. 怎么"跑"这个 demo

这个项目本身就是被 Claude Code 加载的对象。换句话说，**只要你在 `e:\WorkSpace\Harness Demo` 这个目录里和 Claude Code 对话，`.claude/` 下的所有配置就已经在生效了**。

试试这些动作来分别验证各机制：

- **验证 settings 权限**：让我运行 `git status` —— 应该免提示（已 allow）
- **验证 hook 拦截**：让我运行 `rm -rf /` —— [block-dangerous.ps1](.claude/hooks/block-dangerous.ps1) 应该返回 deny
- **验证 hook 日志**：让我编辑 [playground/sample.py](playground/sample.py) —— `.claude/logs/edits.log` 会追加一行
- **验证 skill 触发**：说"帮我问候一下用户" —— 应该触发 [greet-user](.claude/skills/greet-user/SKILL.md)
- **验证 subagent**：说"用 code-explainer 解释 sample.py" —— 会派发独立 agent
- **验证 slash 命令**：输入 `/changelog` —— 执行 [.claude/commands/changelog.md](.claude/commands/changelog.md)

---

## 5. 关键术语速查

| 术语 | 一句话定义 |
|---|---|
| **Harness** | Claude Code CLI 在模型外的整套调度层（权限、hooks、工具、UI） |
| **Settings** | `settings.json`，三层合并：user → project → local |
| **Permissions** | 工具调用白名单/黑名单，决定哪些 Bash/Edit 免提示 |
| **Hook** | 在特定事件（工具调用前/后、Stop 等）触发的外部脚本 |
| **Skill** | 一段按需加载的"操作手册"，由模型决定何时调用 |
| **Subagent** | 拥有独立上下文窗口的子 Claude，主线程拿到的只有它的最终结论 |
| **Slash Command** | `/foo` 形式的快捷指令，本质是预写好的 prompt 模板 |
| **MCP** | Model Context Protocol，把外部系统（DB、Jira、Slack）暴露成工具 |
| **CLAUDE.md** | 项目级"系统提示"，每次对话自动注入到上下文 |

进入 [docs/01-architecture.md](docs/01-architecture.md) 开始正式学习。
