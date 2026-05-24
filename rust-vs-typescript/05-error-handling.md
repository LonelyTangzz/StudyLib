# 05 · 错误处理：`Result` / `Option` / `?` vs try-catch

> TS 的 `throw` / `try-catch` 不在类型签名里、可以被忽略、容易让错误悄悄渗透到生产。Rust 把错误**做成类型系统的一部分**，编译器盯着你处理。
>
> 这是保费计算这种"任何一步出错都不能假装成功"的场景里，Rust 最直接的工程优势。

---

## 1. TS 错误处理回顾

TS 有几种错误表达：

```typescript
// 1. throw + try-catch
function lookupRate(id: string): number {
    if (!validId(id)) throw new Error("invalid id");
    return rateTable[id];
}

try {
    const r = lookupRate("X");
} catch (e) {
    // 处理
}

// 2. undefined/null 返回
function findPolicy(id: string): Policy | undefined {
    return store.get(id);
}

const p = findPolicy("X");
if (p) { /* ... */ }      // strictNullChecks 会强制

// 3. Promise 的 reject
async function chargePremium(p: Policy): Promise<void> {
    if (!p.active) return Promise.reject("inactive");
    // ...
}

// 4. 自定义"结果"对象（少数团队会这么写）
type Result<T> = { ok: true; value: T } | { ok: false; error: string };
```

### TS 的痛点

| 痛点 | 表现 |
| --- | --- |
| **异常不在签名里** | 调用方不知道某函数会 throw |
| **catch 可以不写** | 编译过，运行时崩 |
| **catch 接到的是 unknown** | `catch (e: any)` 然后 `e.message`，毫无类型保护 |
| **异步异常更隐蔽** | 漏 await 一个 reject 是 unhandled rejection |
| **null/undefined 通过 strict 一部分** | 但 `obj!.x` 这种逃生口仍在 |

实际工程后果：保费计算里某条规则函数 throw 了，调用方没 catch，**整个请求 500**。或者更糟，catch 但只是 `log.error("...")` 然后 `return 0`，**保费就变成 0** 入库，对账才发现。

---

## 2. Rust 错误处理的两个核心 enum

```rust
// 表达"可能没值" —— 替代 null
enum Option<T> {
    Some(T),
    None,
}

// 表达"可能失败" —— 替代 throw
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

**任何"可能失败" / "可能没值" 的函数，都返回这俩之一**。

### 例子

```rust
use std::collections::HashMap;

fn find_rate(table: &HashMap<String, Decimal>, id: &str) -> Option<Decimal> {
    table.get(id).copied()  // HashMap::get 返回 Option<&Decimal>
}

fn parse_age(s: &str) -> Result<u8, std::num::ParseIntError> {
    s.parse::<u8>()
}
```

调用方**不可能"忘了处理"**：

```rust
let r = find_rate(&table, "X");
// r 是 Option<Decimal>，你不能直接当 Decimal 用
let rate = r + dec!(0.1);   // ❌ 编译错误
```

---

## 3. 处理 Option / Result 的几种姿势

### 3.1 `match`：最直接

```rust
match find_rate(&table, "X") {
    Some(rate) => use_it(rate),
    None => default_rate(),
}

match parse_age("35") {
    Ok(age) => println!("年龄 {}", age),
    Err(e) => println!("解析失败: {}", e),
}
```

### 3.2 `if let`：只关心一种情况

```rust
if let Some(rate) = find_rate(&table, "X") {
    use_it(rate);
}
// 等价于上面 match 的简写
```

### 3.3 `unwrap` / `expect`：相信有值，没有就 panic

```rust
let rate = find_rate(&table, "X").unwrap();              // None 就 panic
let rate = find_rate(&table, "X").expect("rate missing"); // 同上，附消息
```

**生产代码慎用**：panic 等于让程序崩。只在**绝对不可能为 None** 的场景用（启动配置、单元测试）。

### 3.4 `unwrap_or` / `unwrap_or_else`：给默认值

```rust
let rate = find_rate(&table, "X").unwrap_or(Decimal::ZERO);
let rate = find_rate(&table, "X").unwrap_or_else(|| compute_default());
```

### 3.5 `?` 操作符：自动传播错误

这是 Rust 最优雅的部分。

```rust
fn calculate(id: &str) -> Result<Decimal, CalcError> {
    let policy = load_policy(id)?;          // 失败就直接 return Err
    let rate = lookup_rate(&policy)?;       // 失败就直接 return Err
    let factor = age_factor(policy.age)?;   // 失败就直接 return Err
    Ok(rate * factor)
}
```

等价于（但啰嗦得多）：

```rust
fn calculate(id: &str) -> Result<Decimal, CalcError> {
    let policy = match load_policy(id) {
        Ok(v) => v,
        Err(e) => return Err(e),
    };
    let rate = match lookup_rate(&policy) {
        Ok(v) => v,
        Err(e) => return Err(e),
    };
    // ...
}
```

`?` 也能用于 `Option`：

```rust
fn first_word_length(s: &str) -> Option<usize> {
    let first = s.split_whitespace().next()?;   // None 就直接 return None
    Some(first.len())
}
```

---

## 4. 自定义错误类型

实战中你会有自己的错误枚举：

```rust
use thiserror::Error;

#[derive(Debug, Error)]
enum CalcError {
    #[error("保单未找到: {0}")]
    PolicyNotFound(String),

    #[error("年龄超出承保范围: {age} (允许 18-80)")]
    AgeOutOfRange { age: u8 },

    #[error("保额必须大于零")]
    InvalidCoverage,

    #[error("费率表查询失败")]
    RateLookup(#[from] std::io::Error),  // 自动从 io::Error 转
}
```

`thiserror` crate 帮你自动实现 `Display` / `Error` 等 trait，省去样板代码。

### 自动转换：`#[from]` + `?`

```rust
#[derive(Debug, Error)]
enum AppError {
    #[error("DB 错误: {0}")]
    Db(#[from] sqlx::Error),

    #[error("解析错误: {0}")]
    Parse(#[from] std::num::ParseIntError),

    #[error("业务错误: {0}")]
    Business(String),
}

fn process(id: &str) -> Result<(), AppError> {
    let policy = load_from_db(id)?;        // sqlx::Error 自动转 AppError::Db
    let age: u8 = policy.age_str.parse()?; // ParseIntError 自动转 AppError::Parse
    Ok(())
}
```

这就是 Rust 错误处理优雅的核心：**`?` + `#[from]` 把多种底层错误自动汇总到你的应用错误枚举里**。

---

## 5. `panic!` vs `Result` —— 该用哪个

| 用 panic | 用 Result |
| --- | --- |
| **不可恢复**的错误 | **可恢复**的错误 |
| 程序员错误 / BUG（数组越界） | 用户输入错误、外部依赖故障 |
| 启动配置错（没法跑） | 单笔保费计算失败 |
| 单元测试断言失败 | 业务规则未匹配 |

**保费计算的具体例子**：
- 找不到费率表（启动期检查不到，没法工作）→ `panic!` 或启动期失败
- 单条保单参数缺失（其他保单还能算）→ `Result::Err`
- 算除以零（理论上不该发生 → 是 BUG）→ `panic!`
- 第三方汇率服务超时 → `Result::Err`，可重试

---

## 6. 异步里的错误

Rust 的 `async fn` 也返回 `Result`，跟同步一样用 `?`：

```rust
async fn fetch_rate(id: &str) -> Result<Decimal, AppError> {
    let resp = http_client.get(url).send().await?;
    let rate = resp.json::<Decimal>().await?;
    Ok(rate)
}

async fn calculate(id: &str) -> Result<Decimal, AppError> {
    let rate = fetch_rate(id).await?;   // .await? 组合
    Ok(rate * dec!(1.2))
}
```

跟 TS 比：

```typescript
// TS 异步错误：靠 try-catch 包 await
async function calculate(id: string): Promise<number> {
    try {
        const rate = await fetchRate(id);
        return rate * 1.2;
    } catch (e) {
        // 怎么处理？只能 throw 或返回默认
        throw e;
    }
}
```

Rust 异步错误**类型在签名里**、传播靠 `?`、不会"漏 await"。

---

## 7. 一个完整保费计算 + 错误处理示例

```rust
use rust_decimal::Decimal;
use rust_decimal_macros::dec;
use std::collections::HashMap;
use thiserror::Error;

#[derive(Debug, Error)]
enum CalcError {
    #[error("保单未找到: {0}")]
    PolicyNotFound(String),

    #[error("年龄超出承保范围: {0}")]
    AgeOutOfRange(u8),

    #[error("费率表缺少类型: {0}")]
    MissingRate(String),
}

struct Policy {
    id: String,
    policy_type: String,
    age: u8,
    coverage: Decimal,
}

struct Engine {
    policies: HashMap<String, Policy>,
    rates: HashMap<String, Decimal>,
}

impl Engine {
    fn calculate(&self, id: &str) -> Result<Decimal, CalcError> {
        // 1. 找保单
        let policy = self.policies
            .get(id)
            .ok_or_else(|| CalcError::PolicyNotFound(id.to_string()))?;

        // 2. 校验年龄
        if policy.age < 18 || policy.age > 80 {
            return Err(CalcError::AgeOutOfRange(policy.age));
        }

        // 3. 查费率
        let rate = self.rates
            .get(&policy.policy_type)
            .copied()
            .ok_or_else(|| CalcError::MissingRate(policy.policy_type.clone()))?;

        // 4. 算保费
        Ok(policy.coverage * rate * age_factor(policy.age))
    }
}

fn age_factor(age: u8) -> Decimal {
    match age {
        18..=30 => dec!(1.0),
        31..=50 => dec!(1.2),
        _ => dec!(1.5),
    }
}

fn main() {
    let engine = build_engine();

    let ids = vec!["P001", "P002", "P-bad-age", "P-missing"];

    for id in ids {
        match engine.calculate(id) {
            Ok(premium) => println!("{}: 保费 = {}", id, premium),
            Err(e) => eprintln!("{}: 失败 - {}", id, e),
        }
    }
}

fn build_engine() -> Engine {
    // ... 略
    unimplemented!()
}
```

输出大致：

```
P001: 保费 = 6000
P002: 保费 = 60000
P-bad-age: 失败 - 年龄超出承保范围: 90
P-missing: 失败 - 保单未找到: P-missing
```

**关键观察**：
- 每个失败都**显式**、**带上下文**、**不会被忽略**
- 加新错误类型只要扩 enum，编译器逼你处理新分支
- 多个错误源（保单缺失、年龄越界、费率缺失）汇到同一个 `Result`，调用方一次性处理

---

## 8. 跟 TS 的对照

| 概念 | TS | Rust |
| --- | --- | --- |
| 可能没值 | `T \| undefined` | `Option<T>` |
| 可能失败 | `throw` | `Result<T, E>` |
| 处理"没值" | `if (x !== undefined)` | `match`, `if let`, `unwrap_or` |
| 处理"失败" | `try { } catch (e) { }` | `match`, `?` |
| 传播失败 | rethrow / 不写 catch | `?` 一个符号 |
| 错误类型 | 通常 `Error` 子类 / unknown | 自定义 enum + `thiserror` |
| 多个错误源汇总 | union type 或全部 catch | enum + `#[from]` |
| 调用方能否漏处理 | **能**（编译过） | **不能**（编译报错） |

---

## 9. 工程上立竿见影的好处

引入 Rust 风格的错误处理后，**这些 BUG 类别消失**：

| 类型 | TS 易踩 | Rust 已编译期消灭 |
| --- | --- | --- |
| 忘了 try-catch | ✓ | ✗ |
| catch 之后默默吞了错 | ✓ | 需要主动写 ".unwrap_or" 才能吞 |
| undefined 渗透到运算成 NaN | ✓ | ✗ |
| Promise reject 没 await | ✓ | ✗ |
| 加新错误类型忘了在某处处理 | ✓ | ✗（match 穷尽性） |

---

## 10. 自检清单

- [ ] 我能解释为什么 Rust 没有 throw 是好事
- [ ] 我能写一个返回 `Result<T, MyError>` 的函数
- [ ] 我会用 `?` 链式传播错误
- [ ] 我能用 `thiserror` 定义自己的错误枚举
- [ ] 我知道什么时候 panic、什么时候 Result
- [ ] 我能讲清"为什么 `Option` 比 null 安全"

下一章：[06-decimal-precision.md](06-decimal-precision.md) —— 金额精度，**保费场景里 Rust 真正"碾压"的领域**。
