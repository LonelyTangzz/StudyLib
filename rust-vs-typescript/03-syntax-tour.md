# 03 · Rust 语法 30 分钟速览

> 不教语法书厚度，只教够你**看懂示例、和同事讨论、判断"我能不能写得出来"** 的最小集合。每节都附 TS 对照。最后一节给一个完整的保费计算示例可直接 `cargo run`。

---

## 1. Hello, Cargo

Rust 项目都用 `cargo` 管理：

```bash
cargo new premium-calc          # 新建项目
cd premium-calc
cargo run                       # 编译并运行
cargo test                      # 跑测试
cargo build --release           # 优化构建
cargo add rust_decimal          # 加依赖
cargo fmt                       # 格式化
cargo clippy                    # lint
```

项目结构：

```
premium-calc/
├── Cargo.toml          ← 依赖与项目元数据（类似 package.json）
├── Cargo.lock          ← 锁版本（类似 package-lock.json）
└── src/
    └── main.rs         ← 入口
```

**Hello World** (`src/main.rs`)：

```rust
fn main() {
    println!("Hello, premium calc!");
}
```

---

## 2. 变量与可变性

```rust
let base = 1000;            // 不可变（默认）
let mut count = 0;          // mut = 可变
count += 1;
let base: f64 = 1000.0;     // 显式类型标注
const MAX_AGE: u32 = 100;   // 常量，必须类型 + 大写
```

| TS | Rust |
| --- | --- |
| `const x = 1` | `let x = 1` |
| `let x = 1` (可重新赋值) | `let mut x = 1` |
| `const X = 100` (基本常量) | `const X: u32 = 100` |

**核心区别**：Rust 的 `let` 默认**不可变**。想改要显式 `mut`。这逼你思考"这个值真的需要变吗"。

### Shadowing（变量遮蔽）

```rust
let raw = "1000";
let raw: i32 = raw.parse().unwrap();   // 同名，但变成 i32
let raw = raw * 2;                     // 又一次遮蔽，类型可换
```

跟 `mut` 不同：shadowing 创建**新变量**，类型可以变。

---

## 3. 基础类型

```rust
// 整数：i8/i16/i32/i64/i128 (有符号)，u8/u16/u32/u64/u128 (无符号)
let age: u8 = 35;
let count: i64 = -1;

// 浮点：f32 / f64
let rate: f64 = 0.05;

// 布尔
let active: bool = true;

// 字符（Unicode 标量，4 字节）
let ch: char = '中';

// 字符串：&str 和 String
let s1: &str = "hello";          // 字符串切片，借用，固定长度
let s2: String = String::from("hello");  // 拥有的字符串，可变长度
let s3: String = "hello".to_string();

// 元组
let person: (String, u8) = (String::from("Alice"), 30);
let (name, age) = person;        // 解构

// 数组（固定长度）
let nums: [i32; 3] = [1, 2, 3];

// 向量（动态数组）
let mut v: Vec<i32> = vec![1, 2, 3];
v.push(4);

// HashMap
use std::collections::HashMap;
let mut rates: HashMap<String, f64> = HashMap::new();
rates.insert("car".to_string(), 0.05);
```

| TS | Rust |
| --- | --- |
| `number` | `i32`/`f64`/... 必须明确 |
| `string` | `&str` 或 `String`（区分借用 vs 拥有） |
| `boolean` | `bool` |
| `T[]` | `Vec<T>` (动态) 或 `[T; N]` (固定) |
| `Map<K, V>` | `HashMap<K, V>` |

**`&str` vs `String` 是新人最常困惑的事**：
- `String` = 拥有的、堆上分配的、可增长的字符串
- `&str` = 字符串切片，借用别人的（不拥有，定长）
- 函数参数通常用 `&str`（更通用，能接受 `String` 的引用，也能接受字面量）
- 字段或返回拥有的字符串用 `String`

---

## 4. 函数

```rust
// 基本函数
fn add(a: i32, b: i32) -> i32 {
    a + b                  // 最后一个表达式（无分号）就是返回值
}

// 显式 return 也行
fn add2(a: i32, b: i32) -> i32 {
    return a + b;
}

// 无返回值（其实返回 unit type ()）
fn greet(name: &str) {
    println!("Hello, {}!", name);
}
```

| TS | Rust |
| --- | --- |
| `function f(x: number): number` | `fn f(x: i32) -> i32` |
| `(x) => x + 1` (箭头函数) | `\|x\| x + 1` (闭包) |

**关键约定**：`if`, `match`, `loop` 都是**表达式**有返回值；语句末尾不带分号就是返回值。

---

## 5. 控制流

### if 是表达式

```rust
let age = 30;
let category = if age < 18 {
    "child"
} else if age < 65 {
    "adult"
} else {
    "senior"
};
```

类似 TS 的三元运算符，但支持任意复杂的块。

### match：**Rust 最强大的特性之一**

```rust
let factor = match policy_type {
    "auto" => 1.2,
    "home" => 0.9,
    "health" => 1.5,
    _ => 1.0,  // _ 是默认分支，必须有（穷尽性检查）
};
```

带值的 enum 匹配：

```rust
enum Discount {
    Percent(u8),       // 百分比折扣
    Fixed(Decimal),    // 固定金额减免
    None,
}

let amount = match discount {
    Discount::Percent(p) => base * (100 - p as i32) / 100,
    Discount::Fixed(amt) => base - amt,
    Discount::None => base,
};
```

**强制穷尽**：少处理一个分支编译就报错。这是 Rust 替 TS 的 switch 解决的核心问题。

### 循环

```rust
// loop 无限循环
let result = loop {
    if some_condition {
        break 42;        // loop 可以带返回值！
    }
};

// while
while count < 10 {
    count += 1;
}

// for + 迭代器
for i in 0..10 {                  // 0..10 是 Range，0 包含、10 不包含
    println!("{}", i);
}

for policy in &policies {         // 借用迭代
    println!("{}", policy.id);
}
```

### if let / while let（简化 match）

```rust
// 只关心一种情况时
if let Some(rate) = lookup_rate(id) {
    use_it(rate);
}

// 等价于
match lookup_rate(id) {
    Some(rate) => use_it(rate),
    None => (),
}
```

---

## 6. struct 与 impl

```rust
// 定义
struct Policy {
    id: String,
    holder_age: u8,
    base_premium: Decimal,
    active: bool,
}

// 方法实现（impl 块）
impl Policy {
    // 关联函数（类似 TS 的 static method）—— 通常做构造器
    fn new(id: String, holder_age: u8, base_premium: Decimal) -> Self {
        Self {
            id,
            holder_age,
            base_premium,
            active: true,
        }
    }

    // 方法：&self 借用自身
    fn annual_premium(&self) -> Decimal {
        self.base_premium * Decimal::from(12)
    }

    // 可变方法
    fn deactivate(&mut self) {
        self.active = false;
    }
}

// 使用
let mut p = Policy::new("P001".to_string(), 35, Decimal::new(100, 0));
let annual = p.annual_premium();
p.deactivate();
```

| TS | Rust |
| --- | --- |
| `class` | `struct` + `impl` 块 |
| `constructor()` | 关联函数 `fn new() -> Self` |
| `this` | `self` / `&self` / `&mut self` |
| `public X` (默认) | 字段默认私有；要 `pub` 显式 |

**没有继承**。复用通过 **trait**（见下节）。

---

## 7. enum：Rust 的杀手锏

```rust
enum PolicyState {
    Draft,                                          // 无数据
    Active { effective_from: NaiveDate },           // 带命名字段
    Suspended(String),                              // 带元组字段（暂停理由）
    Expired,
}

let state = PolicyState::Active {
    effective_from: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
};

match state {
    PolicyState::Draft => println!("起草中"),
    PolicyState::Active { effective_from } => println!("生效自 {}", effective_from),
    PolicyState::Suspended(reason) => println!("暂停: {}", reason),
    PolicyState::Expired => println!("过期"),
}
```

### 两个内置 enum 你天天用

```rust
// Option<T>：可能没值
enum Option<T> {
    Some(T),
    None,
}

// Result<T, E>：可能成功可能失败
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

**几乎所有 Rust 程序都围绕这两个 enum 在转**。详见 [05-error-handling.md](05-error-handling.md)。

---

## 8. trait：Rust 的"接口"

```rust
// 定义 trait（类比 TS interface）
trait PremiumCalculator {
    fn base_rate(&self) -> Decimal;
    fn factor(&self) -> Decimal;

    // 默认实现
    fn calculate(&self) -> Decimal {
        self.base_rate() * self.factor()
    }
}

// 为 struct 实现 trait
struct AutoPolicy { /* ... */ }

impl PremiumCalculator for AutoPolicy {
    fn base_rate(&self) -> Decimal { Decimal::from(1000) }
    fn factor(&self) -> Decimal { Decimal::from_str("1.2").unwrap() }
    // 不写 calculate，用默认实现
}

// 函数接受任何实现了 trait 的类型
fn print_premium<T: PremiumCalculator>(p: &T) {
    println!("{}", p.calculate());
}
```

| TS | Rust |
| --- | --- |
| `interface` | `trait` |
| `class X implements Y` | `impl Y for X` |
| 没有"默认方法" | trait 可有默认实现 |

**重要**：trait 是 Rust 实现"多态"和"代码复用"的唯一方式（没有类继承）。

---

## 9. 错误处理速览

```rust
use std::num::ParseIntError;

fn parse_age(s: &str) -> Result<u8, ParseIntError> {
    s.parse::<u8>()
}

fn main() {
    match parse_age("35") {
        Ok(age) => println!("年龄 {}", age),
        Err(e) => println!("解析失败: {}", e),
    }

    // ? 操作符自动传播
    let result = (|| -> Result<u8, ParseIntError> {
        let a = parse_age("35")?;     // 错误就直接返回
        let b = parse_age("60")?;
        Ok(a + b)
    })();
}
```

详见 [05-error-handling.md](05-error-handling.md)。

---

## 10. 闭包与迭代器

```rust
let policies: Vec<Policy> = load_policies();

// 闭包语法 |params| body
let high_value: Vec<&Policy> = policies
    .iter()
    .filter(|p| p.base_premium > Decimal::from(10000))
    .collect();

// map + sum
let total: Decimal = policies
    .iter()
    .map(|p| p.annual_premium())
    .sum();

// 排序（按字段）
let mut sorted = policies.clone();
sorted.sort_by_key(|p| p.holder_age);
```

| TS | Rust |
| --- | --- |
| `(x) => x + 1` | `\|x\| x + 1` |
| `.filter().map().reduce()` | `.iter().filter().map().sum/fold/collect` |

**关键差异**：Rust 的迭代器是**惰性的**（lazy），到 `.collect()` / `.sum()` / `for` 才真正执行。性能比手写循环还好（编译器内联优化）。

---

## 11. 模块与可见性

```rust
// src/main.rs
mod calc;            // 引入 src/calc.rs 或 src/calc/mod.rs
mod model;

use calc::calculate;
use model::Policy;

fn main() {
    let p = Policy::new(...);
    let v = calculate(&p);
}
```

```rust
// src/calc.rs
use crate::model::Policy;

pub fn calculate(p: &Policy) -> Decimal {  // pub = 公开
    // ...
}

fn internal_helper() {                       // 不写 pub = 模块私有
    // ...
}
```

| TS | Rust |
| --- | --- |
| `import { x } from './x'` | `use crate::x::x` |
| `export const x` | `pub const x` |
| 默认导出 | 没有，必须 `pub` |
| 文件 = 模块 | 文件 = 模块 (但要 `mod x;` 注册) |

---

## 12. 一个完整的保费计算示例

下面是一个能 `cargo run` 的小项目。包含 struct、enum、impl、Result、迭代器。

`Cargo.toml`：

```toml
[package]
name = "premium-calc"
version = "0.1.0"
edition = "2021"

[dependencies]
rust_decimal = "1.36"
rust_decimal_macros = "1.36"
thiserror = "1.0"
```

`src/main.rs`：

```rust
use rust_decimal::Decimal;
use rust_decimal_macros::dec;
use thiserror::Error;

// === 数据模型 ===

#[derive(Debug, Clone)]
struct Policy {
    id: String,
    holder_age: u8,
    coverage_amount: Decimal,
    policy_type: PolicyType,
}

#[derive(Debug, Clone)]
enum PolicyType {
    Auto,
    Health,
    Life,
}

// === 错误类型 ===

#[derive(Debug, Error)]
enum CalcError {
    #[error("年龄超出承保范围: {0}")]
    AgeOutOfRange(u8),

    #[error("保额必须大于零")]
    InvalidCoverage,
}

// === 计算逻辑 ===

impl Policy {
    fn calculate_premium(&self) -> Result<Decimal, CalcError> {
        if self.coverage_amount <= Decimal::ZERO {
            return Err(CalcError::InvalidCoverage);
        }
        if self.holder_age < 18 || self.holder_age > 80 {
            return Err(CalcError::AgeOutOfRange(self.holder_age));
        }

        let base_rate = self.base_rate();
        let age_factor = self.age_factor();

        Ok(self.coverage_amount * base_rate * age_factor)
    }

    fn base_rate(&self) -> Decimal {
        match self.policy_type {
            PolicyType::Auto => dec!(0.05),
            PolicyType::Health => dec!(0.08),
            PolicyType::Life => dec!(0.02),
        }
    }

    fn age_factor(&self) -> Decimal {
        match self.holder_age {
            18..=30 => dec!(1.0),
            31..=50 => dec!(1.2),
            51..=65 => dec!(1.5),
            _ => dec!(2.0),
        }
    }
}

// === 入口 ===

fn main() {
    let policies = vec![
        Policy {
            id: "P001".to_string(),
            holder_age: 35,
            coverage_amount: dec!(100000),
            policy_type: PolicyType::Auto,
        },
        Policy {
            id: "P002".to_string(),
            holder_age: 60,
            coverage_amount: dec!(500000),
            policy_type: PolicyType::Health,
        },
        Policy {
            id: "P003".to_string(),
            holder_age: 25,
            coverage_amount: dec!(1000000),
            policy_type: PolicyType::Life,
        },
    ];

    let mut total = Decimal::ZERO;

    for p in &policies {
        match p.calculate_premium() {
            Ok(premium) => {
                println!("保单 {}: 保费 {}", p.id, premium);
                total += premium;
            }
            Err(e) => {
                eprintln!("保单 {} 计算失败: {}", p.id, e);
            }
        }
    }

    println!("合计保费: {}", total);
}
```

跑一下：

```
保单 P001: 保费 6000
保单 P002: 保费 60000
保单 P003: 保费 20000
合计保费: 86000
```

注意到这段代码的**每个 Decimal 都是精确算的**（不存在 `6000.00000001`），并且**任何分支没处理编译都过不去**。

---

## 13. 跟 TS 的对照速查表

| 我想... | TS | Rust |
| --- | --- | --- |
| 声明常量 | `const x = 1` | `let x = 1` |
| 声明变量 | `let x = 1` | `let mut x = 1` |
| 数组 | `[1, 2, 3]` | `vec![1, 2, 3]` |
| 对象/结构 | `interface` + `{ }` | `struct` |
| 类 | `class Foo {}` | `struct Foo;` + `impl Foo {}` |
| 接口 | `interface Foo` | `trait Foo` |
| 联合类型 | `'a' \| 'b'` | `enum E { A, B }` |
| 可能空 | `T \| undefined` | `Option<T>` |
| 异步函数 | `async function f()` | `async fn f()` |
| 等待 | `await x` | `x.await` |
| 异常 | `throw new Error(...)` | `return Err(...)` |
| 处理异常 | `try { } catch (e) { }` | `match` 或 `?` |
| 范围 | `[...Array(10).keys()]` | `0..10` |
| 解构 | `const { a, b } = obj` | `let Foo { a, b } = obj` |

---

## 14. 自检清单

- [ ] 我能写一个简单 struct + impl + 计算方法
- [ ] 我知道 `&str` 和 `String` 的区别和何时用哪个
- [ ] 我能讲清 `let` vs `let mut` vs `const` 三者
- [ ] 我能用 `match` 处理 enum 的所有分支
- [ ] 我能写一个返回 `Result<T, E>` 的函数并用 `?` 传播错误
- [ ] 我能用 `iter().map().filter().collect()` 做集合处理
- [ ] 我能初始化 `cargo new` 项目并加依赖

下一章：[04-ownership.md](04-ownership.md) —— 所有权和借用，**Rust 跟所有其他语言最大的不同**。
