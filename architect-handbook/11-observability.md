# 11 · 可观测性 (Observability)

> **Monitoring 告诉你"系统活没活"，Observability 告诉你"它为什么这样"。** 架构师的可观测性能力直接决定线上事故的恢复时间。

---

## 1. 三大支柱

| 支柱 | 回答 | 典型工具 |
|---|---|---|
| **Logs 日志** | "发生了什么？" | Loki, ELK, OpenSearch, ClickHouse |
| **Metrics 指标** | "情况怎么样？"（量化趋势） | Prometheus, VictoriaMetrics, InfluxDB |
| **Traces 链路追踪** | "请求经过哪些环节？哪儿慢？" | Jaeger, Tempo, Zipkin, SkyWalking |

加一个常被列为"第四支柱"：

| 第四支柱 | 回答 | 工具 |
|---|---|---|
| **Profiling 持续剖析** | "CPU/内存被谁吃了？" | Pyroscope, Parca |

---

## 2. 日志 (Logging)

### 2.1 结构化日志

**别再用拼字符串**：
```
// 差
log("user " + userId + " placed order " + orderId)

// 好
log.info("order placed", {
  user_id: userId,
  order_id: orderId,
  amount_cents: 9900,
  trace_id: traceId
})
```

JSON 日志可被检索、聚合、关联，**这是非协商项**。

### 2.2 日志级别

| 级别 | 用途 | 量 |
|---|---|---|
| **TRACE** | 极细粒度（一般关闭） | 巨量 |
| **DEBUG** | 调试，本地/灰度开 | 大 |
| **INFO** | 关键业务事件（订单创建、支付成功） | 中 |
| **WARN** | 异常但不影响业务 | 小 |
| **ERROR** | 真正的错误（要看的） | 极小 |

**规则**：ERROR 必须每条都值得人看。如果 ERROR 太多没人看 = 系统是 ERROR 字段失效。

### 2.3 必须有的字段

每条日志至少：
- `timestamp`（UTC + 毫秒精度）
- `level`
- `service`（哪个服务）
- `trace_id` / `span_id`（跨服务关联）
- `user_id` / `request_id`（业务关联）
- `message`
- 业务上下文（订单号、错误码等）

### 2.4 不要打的日志

- **敏感信息**：密码、token、身份证、银行卡（必须脱敏）
- **超大对象**：完整请求体、几 MB 的 response
- **高频琐碎信息**：心跳成功、健康检查通过（日志被洗刷掉真正重要的）

### 2.5 日志采集与存储

```
应用 → stdout / 文件
     ↓
日志收集 Agent (Fluent Bit / Vector / Filebeat)
     ↓
消息缓冲 (Kafka)
     ↓
索引存储 (ES / Loki / ClickHouse)
     ↓
查询 + 看板 (Kibana / Grafana)
```

**ClickHouse 做日志后端**正在成为新趋势：成本低（10x）、查询快、聚合强。

### 2.6 日志保留与成本

日志最贵的是存储。常见策略：
- **热数据** 1-7 天，全文索引
- **温数据** 7-30 天，仅聚合可查
- **冷数据** 30-365 天，归档到对象存储
- **删除** 超期硬删

---

## 3. 指标 (Metrics)

### 3.1 四种基础类型

| 类型 | 含义 | 例 |
|---|---|---|
| **Counter** | 单调递增计数 | 请求总数、错误总数 |
| **Gauge** | 任意上下变化 | 当前连接数、CPU 使用率 |
| **Histogram** | 分布统计 | 请求延迟 (能算出 P99) |
| **Summary** | 客户端预计算的分位数 | 同上，但难聚合 |

**重要**：用 Histogram，不要用 Summary（除非你能接受不能跨实例聚合分位数）。

### 3.2 RED 方法（服务指标）

每个服务/接口必采：
- **R**ate 请求率
- **E**rrors 错误率
- **D**uration 延迟（Histogram）

### 3.3 USE 方法（资源指标）

每个资源必采：
- **U**tilization 利用率
- **S**aturation 饱和度（队列长度）
- **E**rrors 错误数

### 3.4 业务指标

技术指标之外，业务指标才是 SRE 的最高优先级：
- 每分钟订单数
- 支付成功率
- 注册转化率
- 关键页面 PV

**业务指标突变 = 立刻报警**。它比任何技术指标都先反映用户损失。

### 3.5 Prometheus 心智

- Pull 模式：Prometheus 定时拉应用的 `/metrics`
- 服务发现：通过 K8s / Consul / 静态配置找目标
- PromQL：查询语言，能算分位数、增长率、组合
- **TSDB**：本地时间序列库，长期存储用 VictoriaMetrics / Thanos / Mimir 等扩展

### 3.6 指标设计反模式

- **高基数 label**：把 `user_id` 当 label → 时间序列爆炸（一个 label 一组 series）
- **采集太多**：每个组件几千指标，没人看
- **没有告警**：监控建了不用
- **告警泛滥**：一晚上 200 条，没人理

---

## 4. 链路追踪 (Distributed Tracing)

### 4.1 核心概念

- **Trace**：一次完整的请求，跨多个服务
- **Span**：一次操作（一次方法调用、一次 RPC）
- **Trace ID**：全 Trace 唯一 ID
- **Span ID** + **Parent Span ID**：构成调用树

```
Trace: trace_abc
├── span_1: API Gateway (200ms)
│   ├── span_2: Order Service (150ms)
│   │   ├── span_3: User Service (40ms)
│   │   └── span_4: DB Query (80ms)
│   └── span_5: Notification Service (30ms)
```

### 4.2 协议与工具

| 协议 | 状态 |
|---|---|
| **OpenTelemetry (OTel)** | 事实标准、统一日志 / 指标 / 追踪 |
| OpenTracing | 已合并到 OTel |
| OpenCensus | 已合并到 OTel |

**新项目无脑选 OpenTelemetry**。

### 4.3 采样

全量采集成本太高。两种策略：

| 策略 | 描述 | 优缺 |
|---|---|---|
| **Head Sampling** | 链路开始就决定采不采 | 简单，但不能保留所有"错误"链路 |
| **Tail Sampling** | 链路结束后决定 | 能定向采集慢 / 错的请求 |

实际：默认低采样率（1%）+ 错误链路 100% + 慢链路 100%。

### 4.4 关联日志 + 指标 + 追踪

可观测性的"圣杯"：
- 日志里有 trace_id → 一条慢 trace 能跳到对应日志
- 指标里挂 trace exemplar → 一条 P99 高的指标能跳到具体 trace
- Grafana 一站式跳转

---

## 5. 持续 Profiling

线上跑火焰图，不需要复现：
- **Pyroscope** / **Parca**：低开销的持续 profiling
- 能回答"昨天下午 3 点 CPU 飙到 90% 时，是谁在烧？"

---

## 6. SLO 与告警 (Alerting)

### 6.1 SLI / SLO / 错误预算

回顾 [03](03-system-design-principles.md#21-sla--slo--sli)：

- **SLI**：你测的指标（成功率 99.95%）
- **SLO**：目标（99.9%）
- **错误预算 (Error Budget)**：1 - SLO = 0.1%。一个月的 0.1% = 43 分钟，可以"花"在故障 / 发版风险上。

**用错误预算驱动发版节奏**：预算还多 → 加速发版尝试新东西；预算烧完 → 冻结、稳定优先。

### 6.2 告警的两个等级

| 等级 | 触发 | 处理 |
|---|---|---|
| **Page** | 立刻威胁 SLO，必须现在处理 | 半夜爬起来 |
| **Ticket** | 趋势恶化或非紧急异常 | 工作时间处理 |

**别什么都 Page**。Page 多了大家不再敏感，真出事时反应慢。

### 6.3 好告警的特征

1. **可执行 (Actionable)**：告警里写清楚"看哪儿、做什么"
2. **关联 SLO**：服务于业务目标，不是为了告警而告警
3. **有 runbook**：告警链接打开 → 处理手册
4. **不重复 / 不抖动**：合理去抖、聚合

### 6.4 常见告警反模式

| 反模式 | 痛点 |
|---|---|
| 凭直觉设阈值 | 抖动报警一晚百条 |
| CPU > 80% 就报 | CPU 高 ≠ 业务受损 |
| 没值班响应人 | 告警发去无人区 |
| 一个故障引发 50 条告警 | 噪音淹没根因 |

---

## 7. 事件响应 (Incident Response)

### 7.1 角色

- **Incident Commander (IC)**：协调全场、做决策、对外沟通
- **Tech Lead**：技术诊断与决策
- **Communications Lead**：对客户 / 上层 / 内部沟通
- **Scribe**：记录时间线

小事故一人多角，大事故必须拆分。

### 7.2 故障三步

1. **缓解 (Mitigate)**：先恢复，不查根因。回滚、降级、重启、扩容都行。
2. **根因 (Diagnose)**：业务恢复后再深查。
3. **复盘 (Postmortem)**：写文档、分享、改进。

### 7.3 复盘 (Postmortem) 原则

- **无指责 (Blameless)**：错的是系统/流程，不是人。
- **时间线 + 决策点**：每一刻发生了什么、做了什么决定
- **根因分析**：用 5-Whys 或类似方法
- **可执行 Action**：每条 action 有 owner 和 ETA
- **公开**：组织内可读，避免重复犯

---

## 8. 故障演练 (Chaos Engineering)

### 8.1 思想

> "**Hope is not a strategy.**" 不主动测试故障，就只能等真出事来测试。

主动注入故障：杀进程、断网、加延迟、CPU 烧满、磁盘填满 —— 看系统怎么表现。

### 8.2 工具

- **Chaos Monkey** (Netflix 开创)
- **Chaos Mesh** / **Litmus** (K8s 原生)
- **Gremlin** (商业)

### 8.3 实施原则

- 先在 **staging 跑通**，再上生产
- **限制爆炸半径**：从单实例 → 单 AZ → 单 region
- **明确假设和验证标准**：注入 X，期望 Y
- 有"**stop button**"：随时能终止

---

## 9. 可观测性的成本

要正视：**可观测性是一项大开销**。一些大厂可观测性成本占总基础设施成本的 20-30%。

控制：
- 指标基数控制（label 数量）
- 日志采样、分层存储
- Trace 智能采样
- 定期审计：删没人看的指标 / 报表

---

## 10. 反模式

| 反模式 | 痛点 |
|---|---|
| 非结构化日志 | 检索全靠 grep，聚合不可能 |
| 把 user_id 做 label | 时间序列爆炸 |
| 全量 trace | 成本爆炸 |
| 监控没告警 | 不知道事 |
| 告警没人响应 | 等于没告警 |
| 故障后不复盘 | 同样问题反复出 |
| 不演练故障 | 真出事时手忙脚乱 |
| 日志打全 trace 全 metric 但无关联 | 三孤岛、查不下去 |

---

## 11. 自检清单

- [ ] 我系统所有日志结构化，且每条带 trace_id。
- [ ] 我能用 PromQL 算出我服务的 P99 延迟。
- [ ] 我系统所有跨服务调用都有 OpenTelemetry trace。
- [ ] 我定了 SLO 且能算出错误预算。
- [ ] 我所有 Page 级告警都有 runbook。
- [ ] 我团队每月至少有一次故障演练。
- [ ] 我团队每次故障都写无指责复盘。
- [ ] 我系统能 5 分钟内从一条 P99 高的告警跳到具体慢 trace。

下一章：[12-devops-and-delivery.md](12-devops-and-delivery.md)。
