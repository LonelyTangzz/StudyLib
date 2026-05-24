# Rust vs TypeScript · 面向保费保单计算场景

> 我们当前的保费保单计算系统用 TypeScript 写。这个板块帮你回答两件事：
>
> 1. **Rust 相对 TS 有哪些真实优势 / 真实代价？**（特别针对金融/精算这类"算得对、算得准、算得快"的场景）
> 2. **Rust 基础语法到底长什么样？**（够你自己评估、能读懂示例、能跟同事讨论）
>
> 不写信仰，不写"应该"，只写"在我们这种场景下"。

---

## 章节一览

| # | 文件 | 一句话 |
| --- | --- | --- |
| 01 | [01-why-rust-for-our-case.md](01-why-rust-for-our-case.md) | 为什么在保费保单计算场景里值得看 Rust |
| 02 | [02-comparison.md](02-comparison.md) | 类型/性能/错误/并发/生态/招聘 十维全面对比 |
| 03 | [03-syntax-tour.md](03-syntax-tour.md) | Rust 语法 30 分钟速览（含完整保费计算示例） |
| 04 | [04-ownership.md](04-ownership.md) | 所有权与借用 —— Rust 独有的核心、TS 来人最大的"坎" |
| 05 | [05-error-handling.md](05-error-handling.md) | `Result`/`Option`/`?` 与 TS try-catch 对比 |
| 06 | [06-decimal-precision.md](06-decimal-precision.md) | 金额精度：TS 浮点的坑、Rust Decimal 的处理 |
| 07 | [07-interop-with-typescript.md](07-interop-with-typescript.md) | 渐进式引入：napi-rs / WASM / 微服务 / CLI 四种共存方式 |
| 08 | [08-decision-framework.md](08-decision-framework.md) | 决策树：什么时候上 Rust、什么时候继续 TS |

---

## 速判表（不读全文就看这个）

| 维度 | TypeScript (Node) | Rust |
| --- | --- | --- |
| 上手速度 | ★★★★★ 一周 | ★★ 三个月 |
| 类型严格度 | ★★★ (strict 也能绕) | ★★★★★ 编译期硬卡 |
| 金额精度 | 默认 float，需自律 | 类型系统强制 Decimal |
| 单机性能 | V8 JIT，一般 | 编译到原生，5-50x |
| 并发安全 | 事件循环，无数据竞争 | 多线程 + 编译期防数据竞争 |
| 错误处理 | exception，可忽略 | `Result`，编译器盯着 |
| 启动时间 | 100ms-1s | < 10ms |
| 内存占用 | 几十 MB 起 | 几 MB |
| 生态成熟度（金融领域） | 大，但碎 | 小，但精 |
| 工具链 | npm/tsc/jest/eslint | cargo 一统天下 |
| 部署 | 需 Node 运行时 + node_modules | 一个二进制 |
| 招聘难度 | 容易 | 难（人少且贵） |
| 团队全员上手成本 | 低 | 高（3-6 个月磨合） |

**TL;DR**：

- **核心计算引擎（高频、高量、高正确性要求）** → Rust 真的会赢，但代价是团队学习成本
- **业务编排、API、前端、运营后台** → 继续 TS
- **新项目从零起步 + 团队没人懂 Rust** → 别一开始就 Rust，先 TS 做出来、痛点暴露后再迁
- **已经踩过精度 / 性能 / 并发 BUG 的模块** → 优先迁这些

---

## 怎么读

- **想 30 分钟拿决策**：[速判表](#速判表不读全文就看这个) + [08-decision-framework.md](08-decision-framework.md)
- **想给团队做技术分享**：按 01 → 08 顺序
- **想自己写第一段 Rust**：[03-syntax-tour.md](03-syntax-tour.md) + [04-ownership.md](04-ownership.md) 起手
- **想评估"这模块该不该迁"**：[06-decimal-precision.md](06-decimal-precision.md)（精度痛点）+ [07-interop-with-typescript.md](07-interop-with-typescript.md)（迁移方式）

---

## 写作约定

- 所有 Rust 代码都能 `cargo run` 跑（除非显式标注"伪代码"）
- 所有 TS 代码都用现代 `strict: true` 风格
- 例子尽量取自保费/保单/精算上下文（如基础保费 × 风险系数 × 期数）
- 不引用其他 StudyLib 板块，自包含

进入 [01-why-rust-for-our-case.md](01-why-rust-for-our-case.md) 开始。
