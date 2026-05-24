# 07 · 在现有 TS 项目里渐进式引入 Rust

> 你**不必**一次重写整个系统。Rust 跟 Node 互操作的方案有四种，每种适合不同场景。这一章给你完整的选型表 + 实操示例。

---

## 1. 四种互操作方式的速判表

| 方案 | 适合 | 性能 | 复杂度 | 部署 |
| --- | --- | --- | --- | --- |
| **napi-rs** (Node 原生模块) | 把热点函数迁出去、保持单进程 | 最高（零开销 FFI） | 中 | Node 进程加 .node 文件 |
| **WASM (wasm-pack)** | 浏览器 + Node 通用、不能用 native build 的环境 | 高（比 napi 略低） | 中 | 一个 .wasm 文件 |
| **独立微服务 (HTTP/gRPC)** | 计算引擎独立部署、跨语言团队 | 中（多了网络） | 高 | 多一个服务 |
| **CLI 工具** | 批处理、离线对账、报表导出 | 高（独立进程） | 低 | 一个二进制文件 |

---

## 2. 方案 A：napi-rs（推荐入门）

### 2.1 它是什么

[napi-rs](https://napi.rs/) 让你用 Rust 写 Node 原生模块。TS 端 `import` 直接当 JS 函数用，**零开销调用** —— 没有 JSON 序列化，没有进程间通信。

```
Node 进程
├── TS / JS 代码
└── premium_calc.node    ← 你的 Rust 模块（编译产物）
       ↑ 直接函数调用
```

### 2.2 快速开始

```bash
# 装脚手架
npm install -g @napi-rs/cli

# 新建项目
napi new premium-calc-native
cd premium-calc-native
```

会生成：

```
premium-calc-native/
├── Cargo.toml             ← Rust 项目
├── package.json           ← Node 包元数据
├── src/
│   └── lib.rs             ← Rust 代码入口
├── index.js               ← TS 加载 native 模块的胶水
└── index.d.ts             ← TS 类型声明（自动生成）
```

### 2.3 写一个保费计算函数

`src/lib.rs`：

```rust
#![deny(clippy::all)]

use napi_derive::napi;
use rust_decimal::Decimal;
use rust_decimal::prelude::FromStr;

#[napi]
pub fn calculate_premium(
    base: String,       // JS 传字符串，避免 number 精度丢失
    rate: String,
    age: u32,
) -> napi::Result<String> {
    let base = Decimal::from_str(&base)
        .map_err(|e| napi::Error::from_reason(format!("base parse: {}", e)))?;
    let rate = Decimal::from_str(&rate)
        .map_err(|e| napi::Error::from_reason(format!("rate parse: {}", e)))?;

    let age_factor = match age {
        0..=29 => Decimal::from_str("1.0").unwrap(),
        30..=49 => Decimal::from_str("1.2").unwrap(),
        _ => Decimal::from_str("1.5").unwrap(),
    };

    let result = base * rate * age_factor;
    Ok(result.to_string())
}

// 批量版本：性能起飞的关键
#[napi]
pub fn calculate_premiums_batch(
    policies: Vec<PolicyInput>,
) -> napi::Result<Vec<String>> {
    policies.into_iter()
        .map(|p| calculate_premium(p.base, p.rate, p.age))
        .collect()
}

#[napi(object)]
pub struct PolicyInput {
    pub base: String,
    pub rate: String,
    pub age: u32,
}
```

### 2.4 编译

```bash
npm run build         # debug 构建
npm run build:release # 优化构建（生产用）
```

产物：`premium-calc-native.node`

### 2.5 TS 端使用

```typescript
// index.d.ts 是自动生成的：
// export function calculatePremium(base: string, rate: string, age: number): string
// export function calculatePremiumsBatch(policies: PolicyInput[]): string[]

import { calculatePremium, calculatePremiumsBatch } from 'premium-calc-native';
import { Decimal } from 'decimal.js';

const premium = calculatePremium('1000', '0.05', 35);
console.log(premium);                                 // "60"

// 批量场景（这是 Rust 真正赢的地方）
const policies = [
    { base: '1000', rate: '0.05', age: 35 },
    { base: '5000', rate: '0.08', age: 50 },
    // ... 几万到几十万条
];
const results = calculatePremiumsBatch(policies);
```

### 2.6 性能特征

| 调用方式 | 单次开销 |
| --- | --- |
| 普通 JS 函数调用 | ~5 ns |
| napi-rs 函数调用 | ~50 ns（10x 慢一点） |
| 跨进程 IPC | ~50 μs（1000x 慢） |
| HTTP localhost | ~500 μs（10000x 慢） |

所以**调用频率高、单次轻量**的场景 napi 完胜微服务。

### 2.7 何时用 napi

- ✓ 现有 Node 项目想优化热点计算
- ✓ 需要保留单进程模型（共享内存、共享配置）
- ✓ 已有 CI/CD 能跑 Rust 编译（或用 napi-rs 的 GitHub Actions 模板）

### 2.8 注意

- 不同 OS / Node 版本需要不同 .node 文件 → 用 napi-rs 官方 CI 模板预编译多平台
- 不支持浏览器（浏览器要用 WASM）
- Rust panic 会让整个 Node 进程崩 —— 必须用 `Result` 而非 panic

---

## 3. 方案 B：WebAssembly (wasm-pack)

### 3.1 它是什么

Rust 编译成 `.wasm` 字节码，**任何支持 WASM 的环境都能跑**：浏览器、Node、Deno、Cloudflare Workers。

### 3.2 快速开始

```bash
# 装 wasm-pack
cargo install wasm-pack

# 新建项目
cargo new --lib premium-calc-wasm
cd premium-calc-wasm
```

`Cargo.toml`：

```toml
[package]
name = "premium-calc-wasm"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
rust_decimal = "1.36"
```

`src/lib.rs`：

```rust
use wasm_bindgen::prelude::*;
use rust_decimal::Decimal;
use rust_decimal::prelude::FromStr;

#[wasm_bindgen]
pub fn calculate_premium(base: &str, rate: &str, age: u32) -> Result<String, JsError> {
    let base = Decimal::from_str(base)
        .map_err(|e| JsError::new(&format!("base: {}", e)))?;
    let rate = Decimal::from_str(rate)
        .map_err(|e| JsError::new(&format!("rate: {}", e)))?;

    let age_factor = match age {
        0..=29 => Decimal::from_str("1.0").unwrap(),
        30..=49 => Decimal::from_str("1.2").unwrap(),
        _ => Decimal::from_str("1.5").unwrap(),
    };

    Ok((base * rate * age_factor).to_string())
}
```

### 3.3 构建

```bash
wasm-pack build --target nodejs    # 给 Node 用
wasm-pack build --target web       # 给浏览器用
wasm-pack build --target bundler   # 给 webpack/vite 用
```

产物 `pkg/`：

```
pkg/
├── premium_calc_wasm_bg.wasm
├── premium_calc_wasm.js
├── premium_calc_wasm.d.ts
└── package.json
```

### 3.4 TS 端使用

```typescript
import { calculate_premium } from './pkg/premium_calc_wasm';

const premium = calculate_premium('1000', '0.05', 35);
console.log(premium);
```

### 3.5 何时用 WASM

- ✓ 浏览器端需要这些计算（保费计算器、报价器）
- ✓ Cloudflare Workers / Edge Function 不支持 native 模块但支持 WASM
- ✓ 不想给每个 OS 维护 .node 二进制
- ✓ 跨多种 JS 运行时（Node + Deno + Bun）

### 3.6 vs napi 的代价

| 维度 | napi | WASM |
| --- | --- | --- |
| 性能 | ★★★★★ | ★★★★（10-30% 慢） |
| 跨平台 | 多平台二进制 | 一个 .wasm |
| 浏览器 | ✗ | ✓ |
| 数据传递开销 | 几乎为零 | 字符串/数组要 copy 跨 WASM 边界 |
| 编译产物大小 | 几 MB | 几百 KB - 几 MB |

---

## 4. 方案 C：独立微服务（HTTP / gRPC）

### 4.1 何时用

- 计算引擎是**独立产品**（不只一个 TS 项目用）
- 团队按服务划分（Rust 团队独立运维）
- 计算量大到需要单独扩缩容
- 现有 Node 服务不想耦合 native 编译链

### 4.2 Rust 端：用 axum 写 HTTP

`Cargo.toml`：

```toml
[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rust_decimal = { version = "1.36", features = ["serde"] }
```

`src/main.rs`：

```rust
use axum::{routing::post, Router, Json};
use serde::{Deserialize, Serialize};
use rust_decimal::Decimal;

#[derive(Deserialize)]
struct CalcRequest {
    base: Decimal,
    rate: Decimal,
    age: u32,
}

#[derive(Serialize)]
struct CalcResponse {
    premium: Decimal,
}

async fn calculate(Json(req): Json<CalcRequest>) -> Json<CalcResponse> {
    let age_factor = match req.age {
        0..=29 => Decimal::from_str_exact("1.0").unwrap(),
        30..=49 => Decimal::from_str_exact("1.2").unwrap(),
        _ => Decimal::from_str_exact("1.5").unwrap(),
    };

    Json(CalcResponse {
        premium: req.base * req.rate * age_factor,
    })
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/calculate", post(calculate));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

### 4.3 TS 端调用

```typescript
const resp = await fetch('http://calc-service:3000/calculate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ base: '1000', rate: '0.05', age: 35 }),
});
const { premium } = await resp.json();
```

### 4.4 微服务的代价

| 优势 | 代价 |
| --- | --- |
| 独立扩缩容 | 多了一个服务的运维 |
| 团队解耦 | 网络延迟 + 序列化开销 |
| 跨语言团队 | 接口契约要维护 |
| 故障隔离 | 多了网络/超时/重试/熔断要考虑 |

---

## 5. 方案 D：CLI 工具

### 5.1 何时用

- **离线批处理**：日终对账、月末结算、年度保费精算
- 数据进出是文件（CSV、Excel、JSON）
- TS 主应用通过 `child_process.spawn` 调用

### 5.2 Rust 端

```rust
use clap::Parser;

#[derive(Parser)]
struct Args {
    /// 输入文件路径
    #[arg(short, long)]
    input: String,

    /// 输出文件路径
    #[arg(short, long)]
    output: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let policies = read_policies(&args.input)?;

    let results: Vec<_> = policies
        .into_iter()
        .map(|p| (p.id.clone(), calculate_premium(&p)))
        .collect();

    write_results(&args.output, &results)?;
    Ok(())
}
```

构建：

```bash
cargo build --release
# 产物：target/release/premium-batch
```

### 5.3 TS 端调用

```typescript
import { spawn } from 'node:child_process';

const proc = spawn('./bin/premium-batch', [
    '--input', 'policies.csv',
    '--output', 'results.csv',
]);

proc.on('close', (code) => {
    if (code === 0) console.log('done');
});
```

### 5.4 优势

- **完全隔离**：Rust 进程崩了不影响主应用
- **部署最简单**：一个二进制 + Docker
- **可在容器、K8s Job、Lambda 任意环境跑**

---

## 6. 选型决策树

```
你的计算调用频率高吗？(>1k QPS)
├── 是 → 是浏览器端吗？
│        ├── 是 → WASM
│        └── 否 → 跟主应用在同一进程更优吗？
│                 ├── 是 → napi-rs
│                 └── 否（要独立扩缩容） → 微服务
└── 否 → 是大批量（>10万条）吗？
         ├── 是 → CLI 工具
         └── 否 → 任选（napi-rs 最常见）
```

---

## 7. 一个推荐的渐进路径

适合你这种"现有 TS 项目想引入 Rust" 的场景：

### 阶段 0：评估（1-2 周）
- 团队 1-2 人学 Rust 基础（[03-syntax-tour.md](03-syntax-tour.md)）
- 找出 1-2 个最痛的计算函数（精度问题严重 / 性能瓶颈）
- 写 PoC：纯 Rust 版本对比现有 TS 版本

### 阶段 1：napi-rs 单点替换（1-2 个月）
- 把 PoC 函数用 napi-rs 包装
- 跟现有 TS 同时跑（"双跑对比"），验证结果一致
- 上灰度：5% 流量走 Rust 版本，监控

### 阶段 2：扩展（3-6 个月）
- 把所有"纯计算热点"逐步迁到同一个 napi 模块
- 沉淀 Rust 项目结构、错误处理范式、测试套路
- 团队培养：每个迁移让不同人主导

### 阶段 3：评估独立化（6+ 个月）
- 如果计算量大到值得 → 拆独立 Rust 微服务
- 如果团队上手了 → 全新项目可以考虑 Rust 全栈
- 不全栈也行：TS + Rust 并存可以是终点

---

## 8. 常见陷阱

| 陷阱 | 怎么避 |
| --- | --- |
| napi 不同平台二进制麻烦 | 用 napi-rs 官方 CI 模板（GitHub Actions），自动多平台构建 |
| Rust 编译慢拖慢 CI | 缓存 `target/` 目录，用 sccache |
| WASM 包太大 | `wasm-opt` 优化，按需切分 |
| panic 让 Node 崩 | 入口函数全用 `Result`，绝不 unwrap 用户输入 |
| Decimal JSON 反序列化退化 float | Rust 端用 `Decimal`，JSON 用字符串形式传递（不用 number） |
| 进程间数据 copy 慢 | 用 napi 不用微服务（如果场景允许） |
| 团队抗拒 | 先解决团队最痛的一个具体问题，让大家感受到 |

---

## 9. 自检清单

- [ ] 我能讲清 napi / WASM / 微服务 / CLI 四种方案各自适合什么场景
- [ ] 我能为我们项目挑出 1 个最值得用 Rust 重写的函数
- [ ] 我知道用 napi-rs 时 panic 会让 Node 崩，必须用 Result
- [ ] 我能讲清"Decimal JSON 必须用字符串传"的原因
- [ ] 我能跟团队讲清楚"渐进引入"路径，不是要一次重写

下一章：[08-decision-framework.md](08-decision-framework.md) —— 综合判断："我们到底要不要现在引入 Rust"。
