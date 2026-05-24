# 04 · 所有权与借用 —— Rust 最核心、最独特、TS 来人最大的"坎"

> 其他语言（包括 TS）都用 GC 来管内存：你随便传对象，垃圾回收器替你收尾。Rust 用**所有权 + 借用**在编译期决定每个值什么时候被释放，达成"无 GC 也内存安全"。
>
> 这是 Rust 跟 TS 最大的差别，也是新人前两个月最痛的地方。一旦理解，写 Rust 才真的舒服。

---

## 1. 为什么要这套东西

C/C++ 用"手动 free" 来管内存：
- 优势：性能、可预测
- 代价：忘了 free → 内存泄露；free 两次 → crash；持有已 free 的指针 → 安全漏洞

Java / Go / JS 用 GC：
- 优势：开发者完全不用管
- 代价：GC pause、内存占用大、不能用在嵌入式 / 内核

Rust 想要**前者的性能、后者的安全**。靠的是：**在编译期就把"谁拥有内存、什么时候释放"算清楚**，运行时无 GC。

---

## 2. 三条所有权规则

> **必背**，后面所有理解都基于这三条：

1. **每个值都有一个唯一的所有者 (owner)**
2. **所有者离开作用域时，值被销毁 (drop)**
3. **同一时刻只能有一个所有者**

```rust
fn main() {
    let s = String::from("hello");   // s 是 "hello" 的所有者
    println!("{}", s);
}   // s 离开作用域，"hello" 被释放（编译器在这里自动插入 drop）
```

---

## 3. 移动 (Move) 语义

```rust
let s1 = String::from("hello");
let s2 = s1;                          // 所有权 move 给 s2

println!("{}", s1);                   // ❌ 编译错误：s1 已经失效
```

跟 TS 完全不同！TS 里：

```typescript
const s1 = "hello";
const s2 = s1;
console.log(s1);                      // ✓ 没问题，s1 还能用
```

**为什么 Rust 这么严**：避免双重释放（s1 和 s2 都 drop "hello" 会 crash）。

### 例外：Copy 类型

整数、浮点、bool、char、不含堆数据的 tuple/struct，实现了 `Copy` trait，赋值是**拷贝**而非移动：

```rust
let a = 5;
let b = a;          // 拷贝
println!("{}", a);  // ✓ a 仍然可用
```

记忆口诀：**栈上数据自动 Copy，堆上数据默认 Move**。`String`、`Vec`、`Box` 等都是堆上数据，默认 Move。

---

## 4. 函数参数的所有权

```rust
fn process(s: String) {
    println!("{}", s);
}   // s 在这里 drop

fn main() {
    let s = String::from("hello");
    process(s);                       // s 的所有权 move 进函数
    println!("{}", s);                // ❌ s 已经失效
}
```

如果你想保留 s，有两个选择：
1. **借用**（最常见，下一节讲）
2. **克隆**（`s.clone()` 拷贝一份给函数）

```rust
process(s.clone());                   // ✓ 但有内存开销
println!("{}", s);                    // ✓
```

**经验**：能借就别 clone。clone 是性能 / 工程的妥协，不是常态。

---

## 5. 借用 (Borrowing)

借用 = 创建引用，**不转移所有权**。

### 5.1 不可变借用 `&T`

```rust
fn print_length(s: &String) {         // 注意 &
    println!("{}", s.len());
}

fn main() {
    let s = String::from("hello");
    print_length(&s);                 // 借用 s 给函数
    println!("{}", s);                // ✓ s 还在
}
```

可以同时存在**任意多个不可变借用**：

```rust
let s = String::from("hello");
let r1 = &s;
let r2 = &s;
let r3 = &s;
println!("{} {} {}", r1, r2, r3);     // ✓
```

### 5.2 可变借用 `&mut T`

```rust
fn append_world(s: &mut String) {
    s.push_str(", world");
}

fn main() {
    let mut s = String::from("hello");
    append_world(&mut s);
    println!("{}", s);                // hello, world
}
```

**但同一时刻只能有一个可变借用**：

```rust
let mut s = String::from("hello");
let r1 = &mut s;
let r2 = &mut s;                      // ❌ 编译错误
println!("{} {}", r1, r2);
```

### 5.3 借用的黄金法则

> **在任意时刻，对一个值，要么有一个 `&mut`，要么有任意多个 `&`。不能同时存在。**

```
情况                                 OK?
─────────────────────────────────────────
&T &T &T                              ✓
&mut T                                ✓
&T 然后 &mut T （时段不重叠）          ✓
&mut T 然后 &T  （时段不重叠）         ✓
&T &mut T 同时                        ✗
&mut T &mut T 同时                    ✗
```

**为什么这么设计**：这条规则在编译期消灭了**数据竞争 (data race)** 和**迭代时修改集合**这两类 BUG。

---

## 6. 借用检查器的"非词法"理解

老版本：变量从声明到作用域结束都"活着"。
现在 (NLL, Non-Lexical Lifetimes)：变量只在"最后一次使用"之前活着。

```rust
let mut s = String::from("hello");

let r = &s;              // 不可变借用开始
println!("{}", r);       // 不可变借用最后一次使用 → 这里结束

s.push_str(" world");    // ✓ 此处 &s 已不存在，可以 &mut s
```

新人写代码常被卡是因为还以为"借用一直到作用域底"。其实只到最后一次使用。

---

## 7. 悬垂引用：编译期拒绝

```rust
fn dangling() -> &String {            // ❌ 想返回引用
    let s = String::from("hello");
    &s
}   // s 在这里 drop，但 &s 想活着 —— 矛盾，编译器拒绝
```

C/C++ 写这种就是"用 free 后的内存"，安全漏洞之源。Rust 让你**根本写不出来**。

正确写法：返回拥有的值：

```rust
fn safe() -> String {                 // ✓ 返回 String，所有权 move 出来
    let s = String::from("hello");
    s
}
```

---

## 8. 生命周期 (Lifetimes) —— 基础

大部分时候编译器**自动推导**生命周期，你不需要写。少数函数返回引用时要标：

```rust
// 标 'a 告诉编译器：返回的 &str 跟 x、y 中的某一个一样长
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}
```

| 你不写时 | 编译器自动 |
| --- | --- |
| 单个引用参数 | 输出生命周期 = 输入 |
| `&self` 在方法里 | 输出 = `self` 的 |
| 复杂情况 | 编译器报错让你显式标 |

**新人建议**：前 1 个月不要主动学生命周期标注。遇到编译器报错让加 `'a` 时再学。**90% 的代码不写生命周期标注**。

---

## 9. 实战示例：保单计算里的常见模式

### 模式 1：函数参数用借用，让调用方保留所有权

```rust
fn calculate_premium(policy: &Policy) -> Decimal {
    // ... 计算
}

// 调用方
let p = load_policy();
let premium = calculate_premium(&p);   // 借用，p 仍然可用
let report = generate_report(&p, premium);
```

如果 `calculate_premium(policy: Policy)`（不带 &），p 就被 move 走了，后面 `generate_report(&p, ...)` 就用不了。

### 模式 2：迭代集合用 `iter()` 借用，避免 move

```rust
let policies: Vec<Policy> = load_all();

// ❌ 错的：for 默认 move
for p in policies {
    process(&p);
}
// policies 已经 move 完，下面用不了
calculate_total(&policies);   // ❌

// ✓ 对的：iter() 借用
for p in policies.iter() {
    process(p);
}
calculate_total(&policies);   // ✓
```

### 模式 3：要在多处长期持有，用 `Arc<T>`（线程安全）或 `Rc<T>`（单线程）

```rust
use std::sync::Arc;

let rate_table = Arc::new(load_rate_table());

let table1 = Arc::clone(&rate_table);
let table2 = Arc::clone(&rate_table);
// table1 和 table2 共享同一份数据（引用计数）
```

类似 TS 里的"对象引用满天飞"，Rust 用 `Arc` 显式表达"我要共享所有权"。

### 模式 4：内部可变性 (Interior Mutability)

借用规则太严时（同时多人读、偶尔写），用 `RefCell<T>`（单线程）或 `Mutex<T>`（多线程）：

```rust
use std::sync::Mutex;

let cache = Mutex::new(HashMap::new());

let mut guard = cache.lock().unwrap();
guard.insert("key", "value");
// 离开作用域自动解锁
```

---

## 10. TS 来人最容易犯的错误

| 错误 | 修法 |
| --- | --- |
| 把值传函数后又想用 | 改成传 `&`（借用） |
| 在循环里改集合 | 收集要改的索引/键，循环外改 |
| 想"返回结构体内部的引用" | 通常改成返回拥有的值，或用生命周期标注 |
| 用 String 到处传 | 函数参数用 `&str`，函数内部需要拥有再 `.to_string()` |
| 想"两个变量共享"一个东西 | 用 `Arc<T>` |

---

## 11. 心智模型：把借用想成 RWLock

读写锁的语义：
- 读锁可以并发多个
- 写锁排他

Rust 借用就是**编译期的读写锁**：
- `&T` = 读锁，可以多个
- `&mut T` = 写锁，排他
- 编译器替你做"锁检查"

只是没有运行时开销 —— 都在编译期搞定了。

---

## 12. 自检清单

- [ ] 我能背三条所有权规则
- [ ] 我能解释为什么 `let s2 = s1` 后 s1 失效（String 场景）
- [ ] 我能讲清"任意多 `&` xor 一个 `&mut`" 的借用规则
- [ ] 我会用 `iter()` 借用迭代而不 move 整个集合
- [ ] 我能识别什么时候需要 `clone()`、什么时候用 `Arc`、什么时候用 `&`
- [ ] 我看到借用检查器报错时不慌（能想到 "哦 NLL、哦同时只能一个 mut"）

---

## 13. 如果只能记一句话

> **"想用就借，借完归还，所有权别乱跑。"**

下一章：[05-error-handling.md](05-error-handling.md) —— `Result` / `Option` / `?`，跟 try-catch 完全不同的另一套世界观。
