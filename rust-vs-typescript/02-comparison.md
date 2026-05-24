# 02 · 全面对比：Rust vs TypeScript

> 上一章讲为什么关注，这一章按 10 个维度逐项对比。每项都给"在保费计算场景里意味着什么"。

---

## 1. 类型系统

### TypeScript
- **结构化类型 (Structural)**：两个类型字段一致就兼容
- `strict: true` 后接近"严格"，但仍有 `any`、`unknown`、`as`、`// @ts-ignore` 几个逃生口
- 运行时**没有**类型信息（编译后类型擦除）
- 没有代数数据类型（要用 union + 判别字段模拟）

```typescript
type PolicyState =
  | { kind: 'draft'; createdAt: Date }
  | { kind: 'active'; effectiveFrom: Date; premium: number }
  | { kind: 'expired'; expiredAt: Date };

// 必须用 switch + kind 判别
function process(p: PolicyState) {
  switch (p.kind) {
    case 'draft': /* ... */ break;
    case 'active': /* ... */ break;
    case 'expired': /* ... */ break;
    // TS 能告诉你 switch 不全 (if --strict)
  }
}
```

### Rust
- **名义化类型 (Nominal)**：名字一样才一样，结构一致也不兼容
- 没有 `any`，没有逃生口（只有不安全的 `unsafe` 区块，**显式标注**）
- 类型在运行时也存在（trait 对象、`std::any::Any` 等）
- 原生支持**代数数据类型 (enum)** + **强制穷尽匹配 (match)**

```rust
enum PolicyState {
    Draft { created_at: DateTime<Utc> },
    Active { effective_from: DateTime<Utc>, premium: Decimal },
    Expired { expired_at: DateTime<Utc> },
}

fn process(p: PolicyState) {
    match p {
        PolicyState::Draft { created_at } => { /* ... */ }
        PolicyState::Active { effective_from, premium } => { /* ... */ }
        PolicyState::Expired { expired_at } => { /* ... */ }
        // 漏一个，编译期就报错
    }
}
```

**保费场景含义**：你的保单状态机、险种枚举、规则分支非常多。Rust 的 enum + 穷尽匹配让"新加一个状态忘了处理"在编译期就被抓出来。TS 能做到，但要 strict + 团队纪律。

---

## 2. 内存管理

### TypeScript
- V8 自动 GC（分代垃圾回收）
- 优点：你完全不用管内存
- 缺点：GC pause（毫秒级，偶尔到秒），峰值内存高，大量小对象有压力

### Rust
- **所有权 (Ownership)**：每个值有唯一所有者，所有者离开作用域值就销毁
- 没有 GC，没有 stop-the-world pause
- 编译期决定何时释放，可预测
- 学习曲线：借用检查器 (borrow checker) 是新人最大障碍

**保费场景含义**：批量处理百万保单时，TS 会因 GC 出现毛刺；Rust 性能曲线平稳。延迟敏感的实时报价场景差别显著。

详见 [04-ownership.md](04-ownership.md)。

---

## 3. 错误处理

### TypeScript
```typescript
function calculate(p: Policy): number {
  // 异常不在签名里
  if (p.invalid) throw new Error('bad policy');
  return p.base * factor;
}

// 调用方根本看不出来会 throw
const result = calculate(policy);  // 可能崩
```

- 异常通过 `throw` / `try-catch`，**不在类型签名里**
- 调用方完全可以不处理，编译过得去，运行时炸
- `Promise.reject` 同样，`.catch` 没写就 unhandled rejection

### Rust
```rust
fn calculate(p: &Policy) -> Result<Decimal, CalcError> {
    if p.invalid {
        return Err(CalcError::Invalid);
    }
    Ok(p.base * factor)
}

// 调用方必须处理
let result = calculate(&policy);  // result 类型是 Result<Decimal, CalcError>
// 想拿值要 ? / match / unwrap
let v = result?;  // 用 ? 自动传播错误
```

- 所有可失败操作返回 `Result<T, E>`，**错误是类型的一部分**
- 不处理 `Result` 编译器警告 (`#[must_use]`)
- `?` 操作符简化错误传播
- `panic!` 是不可恢复错误（类似 abort），跟 `Result` 区分开

**保费场景含义**：这类系统每一步都可能失败（参数缺失、规则不匹配、精度溢出）。Rust 让你**不可能写出"看起来成功了但其实跳过了一步"**的代码。详见 [05-error-handling.md](05-error-handling.md)。

---

## 4. Null / 缺失值

### TypeScript
- `null` 和 `undefined` 都存在（历史问题），TS 区分两者
- `strictNullChecks` 后必须显式 `string | null`
- 但运行时仍有方法可绕：`obj!.foo`（非空断言）、`obj?.foo`（可选链兜底）

### Rust
- **没有 null**
- 用 `Option<T>` 表达"可能没值"
- 编译期强制处理 `None` 分支

```rust
fn find_rate(id: &str) -> Option<Decimal> {
    // ...
}

let rate = find_rate("X-001");
// rate 类型是 Option<Decimal>，不处理 None 编译不过
match rate {
    Some(v) => use_it(v),
    None => default_rate(),
}
```

**保费场景含义**：参数缺失是核保最常见错误。Rust 让"忘了处理缺参"成为不可能。

---

## 5. 并发模型

### TypeScript (Node)
- **单线程事件循环 + 异步 I/O**（`async`/`await`）
- I/O 密集场景效率高
- CPU 密集场景**一核跑死**，无法利用多核
- 多线程要走 `worker_threads`，通信成本高
- 数据共享靠 SharedArrayBuffer（少用、复杂）

### Rust
- **真正的多线程** + 异步（`async`/`.await`，运行时如 tokio）
- `Send` / `Sync` trait 让编译器**在编译期就阻止数据竞争**
- 无 GIL（不像 Python）
- `rayon` crate 让并行迭代器一行代码切多核：

```rust
use rayon::prelude::*;

let total: Decimal = policies
    .par_iter()  // 并行迭代（自动多核）
    .map(|p| calculate_premium(p))
    .sum();
```

**保费场景含义**：批量结算百万保单，Rust 自然吃满 CPU；Node 要么拆 worker 要么横向扩进程。Rust 的"无畏并发 (fearless concurrency)"是个真东西 —— 数据竞争 BUG 编译期消灭。

---

## 6. 性能

实测数量级（粗略，依任务类型不同）：

| 任务 | Rust 相对 Node (V8) |
| --- | --- |
| 纯算术循环 | 5-30x |
| 字符串处理 | 3-10x |
| JSON 解析 | 2-5x |
| 内存占用 | 1/5 - 1/20 |
| 启动时间 | 50-200x（10ms vs 500ms） |
| GC 毛刺 | 无 vs 偶发几十-几百 ms |

**保费场景含义**：
- 单次保费计算可能就 10μs，TS 和 Rust 差别小
- 但**百万次批量**，Rust 1 分钟跑完 vs Node 10 分钟
- 高并发实时报价，Rust 单机能扛 Node 5-10x QPS

---

## 7. 生态系统

| 维度 | TypeScript / Node | Rust |
| --- | --- | --- |
| 包数量 | 600 万+ (npm) | 15 万 (crates.io) |
| 金融/精算专门库 | 多 | 少 |
| Decimal | `decimal.js`, `big.js` 等多个 | `rust_decimal` 几乎事实标准 |
| 日期时间 | `Date`, `dayjs`, `date-fns`, `moment` | `chrono`, `time` |
| HTTP server | Express, Fastify, Koa, Hapi | actix-web, axum, warp |
| ORM | TypeORM, Prisma, Drizzle, MikroORM | Diesel, SeaORM, sqlx |
| 异步运行时 | Node 自带 | tokio, async-std |
| 测试 | Jest, Vitest, Mocha | 内置 `#[test]` + `cargo test` |

**保费场景含义**：你需要的核心库（Decimal、日期、HTTP、DB、CSV/Excel 导出、PDF 生成）Rust 都有，但选择少。**少不一定坏**：选型决策快、社区集中。

---

## 8. 工具链

| 工作 | Node 工具 | Rust 工具 |
| --- | --- | --- |
| 包管理 | npm / pnpm / yarn | cargo |
| 构建 | tsc / esbuild / swc / vite | cargo build |
| 测试 | jest / vitest | cargo test |
| Lint | eslint | clippy |
| 格式化 | prettier | rustfmt |
| 文档 | typedoc | cargo doc |
| 跑脚本 | ts-node / npm scripts | cargo run |
| 发布 | npm publish | cargo publish |

**关键差异**：Rust **一个 cargo 全搞定**，无须自己拼工具链。Node 生态的"工具选型疲劳"在 Rust 里基本不存在。

---

## 9. 部署

### TypeScript
- 需要 Node 运行时（每台机）
- `node_modules` 几百 MB 到几 GB
- 容器镜像通常 100MB+
- 启动 100ms-2s

### Rust
- **一个二进制文件**，几 MB
- 编译时把依赖静态链接
- 容器镜像可小到 < 10 MB（用 distroless / scratch）
- 启动 < 10ms
- 跨编译方便（一台机出多平台二进制）

**保费场景含义**：
- 微服务多了，部署密度 Rust 高得多
- 冷启动快，Serverless / 函数计算友好
- 边缘部署（保险代理终端、IoT）更可行

---

## 10. 团队 / 招聘

| 维度 | TypeScript | Rust |
| --- | --- | --- |
| 工程师数量 | 数百万 | 数十万 |
| 平均薪资 | 基准 | 比 TS 高 20-50% |
| 新人上手到能产出 | 1-2 周 | 2-3 个月 |
| 资深人才招聘难度 | 中 | 高 |
| 团队转型成本 (5 人组全员转) | 几乎为零（已会 JS） | 6-12 个月 |
| 老板/PM 接受度 | 默认认可 | 需要解释 |

**保费场景含义**：在国内**金融行业**，Rust 工程师特别少。引入需要做好"自己培养"的准备，而不是"从市场挖"。

---

## 11. 学习曲线对照

```
易上手 ─────────────────────────────────────────► 难上手

JavaScript ◄──TypeScript──Python──Go──Java──C#──C++──◄ Rust

```

具体到时间感受：

| 阶段 | TS | Rust |
| --- | --- | --- |
| Hello World 跑通 | 5 分钟 | 5 分钟 |
| 写一个简单 CRUD | 1 天 | 1 周 |
| 写一个有点复杂的功能 | 1 周 | 1 个月 |
| 调试别人的代码不抓狂 | 1 个月 | 3 个月 |
| 能 review 别人 PR 提出有质量的意见 | 3 个月 | 6 个月 |
| 能给团队定规范 | 6 个月 | 1 年 |

**Rust 难在哪里**：所有权 / 借用 / 生命周期 是别的语言完全没有的概念。前 2-3 周你会**经常被编译器拒绝**，看半天才明白为什么不能这么写。**度过这个阶段后**，写起来比 TS 还顺（因为编译器接管了一大堆心智负担）。

---

## 12. 互调能力

### Rust 调 TS / JS
- 几乎不做 (反方向意义不大)

### TS / Node 调 Rust（**关键能力**）
- **napi-rs**：写 Rust，编译成 Node native module，TS 端 `import` 就用
- **WebAssembly (wasm-pack)**：编译到 WASM，浏览器 + Node 都能跑
- **HTTP/gRPC 微服务**：Rust 独立服务，TS 调用
- **CLI**：Rust 编译二进制，Node 用 `child_process` 调

**这意味着**：不必"一次重写"。可以**先把痛点函数迁出去**，主项目继续 TS。详见 [07-interop-with-typescript.md](07-interop-with-typescript.md)。

---

## 13. 一张总结表

| 维度 | TS 强 | Rust 强 |
| --- | --- | --- |
| 业务编排、CRUD | ✓ | |
| 前端 / BFF | ✓ | |
| 快速原型 | ✓ | |
| 全栈复用（前后端共享类型） | ✓ | |
| 高性能计算 | | ✓ |
| 高并发服务 | | ✓ |
| 金额精度 | | ✓ |
| 错误正确处理 | | ✓ |
| 大规模重构安全 | | ✓ |
| 长生命周期项目可维护性 | | ✓ |
| 团队上手快 | ✓ | |
| 招聘容易 | ✓ | |
| 部署轻量 | | ✓ |
| 启动 / 内存 | | ✓ |
| 生态广度 | ✓ | |
| 工具链统一 | | ✓ |

---

## 14. 自检清单

- [ ] 我能讲清 Rust 的 enum + match 比 TS 的 union + switch 强在哪。
- [ ] 我能讲清 Rust 的 `Result<T, E>` 跟 TS 的 throw 各自的工程影响。
- [ ] 我知道 Rust 没有 null，用 `Option<T>` 替代。
- [ ] 我能列出我项目里至少 3 个"如果用 Rust 写更稳"的具体函数。
- [ ] 我清楚 Rust 引入到团队需要的真实成本（不是单纯学习，是协作和招聘）。
- [ ] 我能给老板讲清楚"我们要不要碰 Rust" 的决策路径。

下一章：[03-syntax-tour.md](03-syntax-tour.md) —— Rust 语法 30 分钟速览。
