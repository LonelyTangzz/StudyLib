# 08 · API 与系统集成

> API 是系统的"公共承诺"。一旦发出去就很难收回。架构师的关键能力是**设计出既好用又能演进 5 年的接口**。

---

## 1. API 风格全景

| 风格 | 通信方式 | 强项 | 典型场景 |
|---|---|---|---|
| **REST** | HTTP + JSON | 通用、生态广 | 对外开放 API、Web 前后端 |
| **RPC (gRPC)** | HTTP/2 + Protobuf | 性能高、强类型 | 内部服务间 |
| **GraphQL** | HTTP + 自定义查询语言 | 客户端按需取 | 多端聚合、字段多变 |
| **WebSocket** | TCP 长连接 | 双向、实时 | 聊天、推送、协同 |
| **SSE (Server-Sent Events)** | HTTP 长连接 | 单向推送、简单 | 通知、流式响应 |
| **GraphQL Subscription** | WebSocket | 订阅模式 | 实时 GraphQL |
| **消息驱动** | MQ | 异步、解耦 | 跨服务事件 |

---

## 2. REST 详解

### 2.1 设计原则（不是教条）

- **资源 (Resource) 为中心**：URL 是名词，HTTP 动词表达操作。
- **状态码** 表达结果（200/201/204/400/401/403/404/409/422/429/500/503）。
- **无状态**：服务端不存客户端会话（认证用 token，不用 server-side session）。
- **可缓存**：合理用 ETag / Cache-Control。
- **HATEOAS**：理想很美，工程上少有人做。

### 2.2 常见 URL 设计

```
GET    /orders                  列表
GET    /orders/{id}             单个
POST   /orders                  创建
PUT    /orders/{id}             整体替换
PATCH  /orders/{id}             部分更新
DELETE /orders/{id}             删除

GET    /orders/{id}/items       子资源列表
POST   /orders/{id}/items       为订单添加项
```

### 2.3 列表接口必须设计的能力

| 能力 | 写法 |
|---|---|
| 分页 | `?page=1&size=20` 或 `?cursor=xxx&size=20`（推荐 cursor） |
| 排序 | `?sort=created_at:desc,id:asc` |
| 过滤 | `?status=PAID&min_amount=100` |
| 字段裁剪 | `?fields=id,amount,status` |
| 关联展开 | `?include=customer,items` |

### 2.4 错误响应规范化

```json
{
  "error": {
    "code": "ORDER_NOT_FOUND",
    "message": "Order #123 does not exist",
    "details": [
      { "field": "order_id", "issue": "not_found" }
    ],
    "trace_id": "abc-def-123"
  }
}
```

要点：
- 业务错误码 **(code)** 稳定，给客户端做分支；message 给人看，可变。
- `trace_id` 必带，方便用户报问题时定位日志。
- 4xx 是客户端错（别人锅），5xx 是服务端错（自己锅）。

### 2.5 状态码常见坑

- 创建成功用 **201**，并返回 `Location` 头。
- 删除成功用 **204**（无内容）。
- 表单校验失败用 **422**（Unprocessable Entity），不是 400。
- 认证失败用 **401**（未认证），权限不足用 **403**（已认证但没权限）。
- 限流用 **429**。
- 资源冲突用 **409**（例：重复创建）。
- 临时不可用用 **503** + `Retry-After` 头。

---

## 3. gRPC / RPC

### 3.1 适合场景

- **内部**服务间通信
- 强类型、跨语言（Java ↔ Go ↔ Python）
- 高吞吐、低延迟
- 流式 RPC（双向流）

### 3.2 协议设计要点

- **.proto 文件是真相**：所有语言生成代码都从它来。
- 字段编号一旦定下**永不变更**，删字段用 `reserved`。
- 不要用 `required`（proto3 已经废除）—— 加字段必须向后兼容。
- 用 `oneof` 表达多选一，比 nullable 清晰。

### 3.3 gRPC vs REST 怎么选

| 你想要 | 选 |
|---|---|
| 对外开放 | REST + JSON |
| 内部服务高性能 | gRPC |
| 浏览器直连 | REST 或 gRPC-Web |
| 流式数据 | gRPC streaming / WebSocket |
| 调试方便（curl） | REST |
| 强类型契约 | gRPC |

---

## 4. GraphQL

### 4.1 解决什么问题

REST 在多端 / 字段多变时痛苦：
- iOS 要 10 个字段、Android 要 12 个、Web 要 20 个 → 要么后端给三套接口，要么一刀切返回全部。
- 关联数据要多次请求（N+1 问题）。

GraphQL：**客户端写查询，描述要什么，服务端按需返回**。

### 4.2 优点

- 一次请求拿全所有数据，没有 over-fetch / under-fetch。
- Schema 自描述，前端开发提效。
- 字段级权限可控。

### 4.3 代价

- **N+1 查询**问题需要 DataLoader 解决。
- 缓存策略复杂（不是基于 URL）。
- 安全：恶意查询（深度、复杂度）可能打挂服务。
- 适合**字段聚合**场景，不适合简单 CRUD。

### 4.4 不要为 GraphQL 而 GraphQL

中后台、内部系统不需要 GraphQL。它的价值在公共 API + 多前端聚合。

---

## 5. 异步与事件驱动

### 5.1 消息形态

| 形态 | 含义 | 例 |
|---|---|---|
| **Command** | 命令式：要求做某事 | `PlaceOrderCommand` |
| **Event** | 事实陈述：发生了某事 | `OrderPlacedEvent` |
| **Document** | 数据传输 | 同步整表 / 批数据 |

**Event** 是事件驱动架构的核心：发布者只说"发生了"，不假设谁会处理。

### 5.2 事件命名规范

- 过去时（已发生）：`OrderPlaced`、`PaymentReceived`、`UserDeleted`
- 不带"将要"含义（`PlaceOrder` 是 Command 不是 Event）
- 不带处理意图（`SendEmailToUser` 是 Command 不是 Event）

### 5.3 事件结构

```json
{
  "event_id": "evt_abc123",
  "event_type": "OrderPlaced",
  "event_version": "1.0",
  "occurred_at": "2026-05-23T10:00:00Z",
  "producer": "order-service",
  "trace_id": "trace_xxx",
  "data": {
    "order_id": "ord_123",
    "user_id": "usr_456",
    "amount_cents": 9900
  }
}
```

要素：
- `event_id` 用于消费幂等
- `event_version` 用于 schema 演进
- `trace_id` 用于跨服务链路追踪
- `data` 是业务负载，但**不要塞整个对象**（数据冗余、版本问题），用 ID + 必要字段，下游按需查

### 5.4 Outbox 模式（必备）

如何**可靠地发布事件**：
```
START TRANSACTION;
  INSERT INTO orders ...;
  INSERT INTO outbox (event_type, payload) VALUES ('OrderPlaced', '{...}');
COMMIT;

[后台进程] 轮询 outbox → 发 Kafka → 标记已发
[或 CDC] 监听 outbox 表 → 自动发布
```

避免"业务成功但事件丢失"或"事件发了但业务回滚"。

### 5.5 反例：用事件做 RPC

把事件当请求-响应用，等回响 → 失去了异步价值，引入复杂度。需要响应就用 RPC。

---

## 6. API 版本管理

### 6.1 何时需要版本

- 删除字段
- 改字段语义
- 改返回结构
- 改错误码含义

加字段、加新接口 **通常不需要版本**（向后兼容）。

### 6.2 版本表达方式

| 方式 | 例 | 优缺 |
|---|---|---|
| **URL** | `/v1/orders`、`/v2/orders` | 直观，路由简单 |
| **Header** | `Accept: application/vnd.app.v2+json` | URL 干净，难调试 |
| **Query** | `?version=2` | 简单，但易被忽略 |

**经验**：对外用 URL，内部用 Header。

### 6.3 兼容性原则

- **向后兼容（消费者层面）**：旧客户端用新服务端不挂。
- **向前兼容（服务端层面）**：新客户端用旧服务端不挂 —— 难做到。
- 同时维护两个版本最多 6-12 个月，再砍。

### 6.4 演进策略

1. **新字段** → 直接加，老客户端忽略。
2. **改字段** → 加新字段、保留老字段一段时间、客户端切换、再删老字段。
3. **拆接口** → 新接口上线、引导客户端迁移、监控老接口流量到零、下线。

---

## 7. 幂等性设计

详见 [03](03-system-design-principles.md#4-幂等性-idempotency)。在 API 层：

- **POST 创建** 用 `Idempotency-Key` Header，服务端用唯一索引去重。
- **PUT** 天然幂等（整体替换）。
- **DELETE** 天然幂等（已删除还删返 204）。
- **状态机操作**用版本号：`PATCH /orders/{id}?version=3`，版本不匹配返 409。

---

## 8. 限流与配额

### 8.1 限流响应规范

```
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1716470400
```

客户端能据此自适应（退避 + 重试）。

### 8.2 限流维度

- 全局限流（保护整体系统）
- 按用户 / 租户限流（防一个客户拖累所有）
- 按 API 限流（核心 API 高额度、辅助 API 低额度）
- 按 IP 限流（防爬虫）

---

## 9. 认证与授权（仅 API 层视角，详见 [10](10-security-architecture.md)）

### 9.1 常见方式

- **API Key**：简单、适合服务端到服务端。
- **OAuth 2.0 / OIDC**：第三方授权（"用 Google 登录"）。
- **JWT (JSON Web Token)**：自包含、无状态，但**撤销难**。
- **mTLS**：双向证书，零信任内网。

### 9.2 JWT 的常见坑

- 不要存敏感信息（payload 是 base64，不是加密）。
- 必须**校验签名**（库要选靠谱的，注意 `alg: none` 攻击）。
- **过期时间短** + Refresh Token 配套。
- 撤销难 → 加黑名单（但失去无状态优势）。

---

## 10. 文档与契约

### 10.1 OpenAPI / Swagger

- REST API 用 **OpenAPI 3.x** 描述。
- 是给前端、QA、第三方开发者**唯一可信的接口说明**。
- 不要手写 + 手维护——**代码生成或代码注解生成 OpenAPI**。

### 10.2 Protobuf / IDL

gRPC、Thrift 都是接口先行。proto 文件应该在**独立仓库或共享目录**，版本化管理。

### 10.3 契约测试 (Contract Testing)

防止"服务端改了，客户端没跟上"的方式：
- Pact、Spring Cloud Contract
- 客户端写期望（"我期望调 /orders 拿到这样的结构"）
- 服务端 CI 跑这些期望，破坏即失败

---

## 11. 反模式

| 反模式 | 痛点 |
|---|---|
| URL 用动词 (`/getOrder`) | 不 RESTful、不规范 |
| 所有错误都返 200 + body 里写状态码 | HTTP 监控失效 |
| 字段删了直接发版 | 客户端炸 |
| GET 接口改数据 | 缓存/CDN 会重复触发副作用 |
| 没有 trace_id 的响应 | 用户报问题时无法定位 |
| 接口返回内部错误堆栈 | 信息泄露 |
| 一次性返回所有字段（包括敏感） | 隐私问题 |
| 用枚举数字 (status=2) 不用字符串 | 含义不直观、加值要文档同步 |

---

## 12. 自检清单

- [ ] 我能为新业务做出合理的 API 风格选择（REST / gRPC / GraphQL / 消息）。
- [ ] 我能设计幂等的 POST 接口（含 Idempotency-Key）。
- [ ] 我能为接口设计 cursor 分页。
- [ ] 我能讲事件 vs 命令的区别，并给出命名规范。
- [ ] 我系统的事件发布走 Outbox 或等效可靠机制。
- [ ] 我有 OpenAPI / Protobuf 契约，并能在 CI 中跑契约测试。
- [ ] 我能讲清接口版本迁移的"加 → 切 → 删"三步。
- [ ] 我的所有错误响应都带 trace_id。

下一章：[09-performance-engineering.md](09-performance-engineering.md)。
