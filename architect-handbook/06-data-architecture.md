# 06 · 数据架构

> 一句话：**应用代码可以重写，数据迁移要命。** 数据架构是架构师做的所有决策里最不可逆的一类。

---

## 1. OLTP vs OLAP

| 维度 | OLTP（在线事务） | OLAP（在线分析） |
|---|---|---|
| 典型负载 | 高频小事务（下单、扣库存） | 低频大查询（报表、聚合） |
| 数据量级 | GB ~ 数 TB | TB ~ PB |
| 一致性要求 | 强（ACID） | 弱（最终一致也行） |
| 查询模式 | 已知模式、点查 / 短范围 | 任意模式、全表扫 / GROUP BY |
| 代表系统 | MySQL, PostgreSQL, Oracle | ClickHouse, Snowflake, BigQuery, Doris |
| 索引重点 | B+ Tree | 列存 + Bitmap |

**架构原则**：不要在 OLTP 库上跑 OLAP 查询。一个 `SELECT ... GROUP BY` 全表扫，能把主库压垮，影响整个业务。

---

## 2. 数据库选型地图

### 2.1 关系型 (RDBMS)

代表：MySQL、PostgreSQL、Oracle、SQL Server。

**强项**：
- ACID 事务
- 灵活的查询（JOIN、子查询）
- 成熟生态、人才储备

**短板**：
- 水平扩展难（分库分表是工程，不是天然能力）
- 大数据量下索引维护成本高

**PostgreSQL vs MySQL 速判**：
- PG 功能强（JSONB、地理空间、扩展机制、CTE/窗口函数完整），SQL 标准严格。
- MySQL 工具生态丰富、运维资料多、读写分离简单。
- **新项目无特殊要求 → PostgreSQL** 是越来越多人的默认。

### 2.2 键值 (Key-Value)

代表：Redis、Memcached、RocksDB、DynamoDB。

**强项**：
- 极致低延迟（μs 级）
- 简单 API、易扩展

**用途**：
- 缓存（最常见）
- 会话存储
- 排行榜（Redis Sorted Set）
- 分布式锁（带 TTL 的 SET NX）
- 限流（INCR + EXPIRE）
- 消息队列（List / Stream）

### 2.3 文档型 (Document)

代表：MongoDB、CouchDB、Elasticsearch。

**强项**：
- 灵活 schema（嵌套字段、数组）
- 适合"半结构化"数据

**短板**：
- 跨文档事务弱
- JOIN 难

**用途**：
- 内容管理（文章、配置）
- 商品详情（属性多变）
- 日志（ES 是事实标准的日志后端）

### 2.4 列存 (Columnar)

代表：ClickHouse、Druid、Doris、HBase。

**强项**：
- 大表聚合查询快几个数量级
- 高压缩比

**短板**：
- 单行更新慢
- 实时点查不擅长

**用途**：
- 数据仓库
- 实时报表
- 时序数据分析

### 2.5 时序 (Time Series)

代表：InfluxDB、Prometheus、TimescaleDB、TDengine。

**强项**：
- 按时间分片自动管理
- 自动降采样（Rollup）
- 高写入吞吐

**用途**：
- 监控指标
- IoT 设备数据
- 日志聚合

### 2.6 图 (Graph)

代表：Neo4j、JanusGraph、Nebula。

**强项**：
- 多跳关系查询（朋友的朋友的朋友）
- 复杂关联推理

**用途**：
- 社交网络
- 推荐系统（基于关系）
- 风控（资金链路、团伙识别）
- 知识图谱

### 2.7 搜索 (Search)

代表：Elasticsearch、OpenSearch、Solr、Meilisearch。

**强项**：
- 全文检索（分词、相关性打分）
- 复杂过滤 + 排序 + 聚合

**短板**：
- 不是事务型存储（不要当主 DB）
- 写延迟（refresh interval）

**用途**：
- 商品搜索、文档搜索
- 日志查询
- 监控聚合

### 2.8 选型决策表

| 你要的 | 选 |
|---|---|
| 复杂事务 + 关系查询 | RDBMS |
| 极低延迟 + 简单 KV | Redis |
| 灵活 schema 文档 | MongoDB |
| 大数据聚合分析 | ClickHouse / Doris |
| 时序监控数据 | InfluxDB / Prometheus |
| 图关系查询 | Neo4j |
| 全文检索 | Elasticsearch |
| 海量写入、最终一致 | Cassandra / ScyllaDB |
| 跨地域全球强一致 | Spanner / CockroachDB / TiDB |

---

## 3. 索引设计

### 3.1 索引类型

| 类型 | 用途 |
|---|---|
| **B+ Tree** | 等值、范围查询（最常用） |
| **Hash** | 仅等值，内存表 |
| **Bitmap** | 基数低的字段（性别、状态） |
| **倒排索引** | 全文检索 |
| **GIN / GiST** | PG 的 JSON / 地理空间 |
| **R-Tree** | 空间索引 |
| **LSM 内的稀疏索引** | RocksDB 系 |

### 3.2 复合索引的"最左前缀"原则

`INDEX (a, b, c)` 能服务：
- `WHERE a = ?`
- `WHERE a = ? AND b = ?`
- `WHERE a = ? AND b = ? AND c = ?`
- `WHERE a = ? ORDER BY b`

**不能**服务（或退化扫描）：
- `WHERE b = ?`（跳过 a）
- `WHERE c = ?`

### 3.3 覆盖索引

如果查询的所有字段都在索引里，**不用回表**。能把 P99 从 50ms 降到 5ms。

### 3.4 索引的代价

- 写入要维护索引（INSERT/UPDATE 变慢）
- 占磁盘 + 内存（Buffer Pool 命中率下降）

**经验**：表 ≤ 5 个索引为佳。超过 10 个就该审视。

### 3.5 索引设计套路

1. 先确定**核心查询模式**。
2. 为高频查询设复合索引，按"等值 → 范围 → 排序"顺序放字段。
3. 检查执行计划，确认走了索引。
4. 删掉**从未被使用的索引**（MySQL 8.0 / PG 都能看索引使用统计）。

---

## 4. 数据建模

### 4.1 范式 vs 反范式

- **范式 (Normalization)**：消除冗余，更新一致。代价是 JOIN 多。
- **反范式 (Denormalization)**：冗余字段，读快写麻烦。

**经验**：先 3NF 建模，识别出读热点后**有选择地反范式**。读多写少的字段冗余化收益大。

### 4.2 软删除 vs 硬删除

- **软删除**：加 `deleted_at` 字段。可恢复、审计友好，但查询都得加条件。
- **硬删除**：DELETE 真删。简单但不可逆。

**经验**：业务实体软删除，关联表（中间表、日志）硬删除。

### 4.3 雪花 ID vs 自增 ID

| 维度 | 自增 ID | Snowflake / UUID |
|---|---|---|
| 全局唯一 | 单库唯一 | 全局 |
| 顺序性 | 严格递增 | 趋势递增 / 无序 |
| 索引友好 | ✓ | UUID 差，Snowflake 还行 |
| 安全性（猜不到下一个） | 差 | 好 |
| 分库分表 | 不能用 | 必须用 |

### 4.4 关键字段命名约定

- 时间字段：`created_at`、`updated_at`、`deleted_at`（统一用 UTC）
- 状态字段：用枚举/字符串而非数字（"PENDING" 比 1 直观）
- 金额字段：用整数（分），不用浮点
- 布尔字段：`is_active`、`has_paid`（含义自解释）

---

## 5. 分库分表

### 5.1 何时需要

通常是单库 OLTP 撑不住时：
- 单表 > 1 亿行 + 索引大到放不进内存
- 写 QPS > 5k（单机 MySQL 上限）
- 单库容量 > 1 TB

不到这个量**不要分**。分库分表的复杂度是单库的 5-10 倍。

### 5.2 分片键 (Sharding Key) 选择

**最重要的设计决策。** 一旦选定，几乎不可改。

原则：
- **高基数**（分散均匀）
- **查询友好**（绝大多数查询能带上它）
- **跨片操作少**

常见选择：
- 用户 ID（用户维度业务）
- 订单 ID（订单维度业务）
- 租户 ID（多租户 SaaS）

**反例**：用时间分片做 OLTP，最新分片永远热点。

### 5.3 跨分片查询

四种解决思路：

| 方案 | 适用 |
|---|---|
| **避免**（重设计查询） | 首选 |
| **聚合查询全分片 (scatter-gather)** | 偶尔的运营报表 |
| **冗余/反范式**（多份按不同分片键存） | 高频次查询 |
| **外部索引**（同步到 ES/数仓） | 复杂搜索 |

### 5.4 分库分表工具

代表：ShardingSphere、MyCAT、Vitess、TiDB（NewSQL 直接帮你做）。

NewSQL（TiDB、CockroachDB、OceanBase）是**新一代选择**：分布式 + SQL + 事务，让你"看起来还在用单库 MySQL"，但要付出一致性延迟和成本代价。

---

## 6. 复制与读写分离

### 6.1 基本套路

```
应用 → 写主库
     → 读从库（多个，负载均衡）
```

### 6.2 必须处理的问题

- **复制延迟**：从库滞后导致读不到刚写的数据。
  - 关键查询强制走主库
  - "读你所写"语义：写后 N 秒内同一会话走主
- **从库挂**：负载均衡器要做健康检查。
- **主库挂**：故障切换（手动/自动），需要选主机制（VIP、MHA、Orchestrator、云数据库的自动 failover）。

### 6.3 读写分离的反例

- 把 OLAP 查询甩给从库 → 从库慢/挂，复制延迟拖累所有读。
  正确做法：单独同步到数仓 / ClickHouse 做分析。

---

## 7. CDC (Change Data Capture)

### 7.1 是什么

把数据库的**变更**（INSERT/UPDATE/DELETE）实时捕获并下发到下游（消息队列、数仓、缓存、ES）。

### 7.2 两种实现

| 方式 | 原理 | 代表 |
|---|---|---|
| 基于日志 | 解析 DB binlog/WAL | Debezium、Canal、Maxwell |
| 基于触发器 / 查询 | 在表上加触发器或定时扫 | 老土方案 |

**首选基于日志**：对业务库零侵入、低延迟、不丢数据。

### 7.3 用途

- 同步到 ES / 数仓
- 缓存失效通知
- 跨服务最终一致（替代分布式事务）
- 异地复制
- 审计

### 7.4 实现 Outbox 模式时的 CDC

```
1. 业务事务里同时写 outbox 表
2. CDC 监听 outbox 表的 INSERT
3. CDC 转发到 Kafka
4. 下游消费
```

避免了"双写不一致"问题（业务 DB + Kafka 写一个挂另一个不挂）。

---

## 8. 数据湖、数据仓库、湖仓一体

| 概念 | 特点 | 代表 |
|---|---|---|
| **数据仓库 (Data Warehouse)** | schema-on-write，结构化，BI 友好 | Snowflake、BigQuery、Redshift |
| **数据湖 (Data Lake)** | schema-on-read，原始格式存，便宜 | S3 + Parquet/ORC、HDFS |
| **湖仓一体 (Lakehouse)** | 湖的便宜 + 仓的能力（ACID、事务） | Delta Lake、Iceberg、Hudi |

### 8.1 现代数据栈典型

```
业务库 → CDC → Kafka → Spark/Flink → 数据湖（S3 + Iceberg）
                                         ↓
                                  ETL/ELT (dbt)
                                         ↓
                                  数仓 / 报表 (ClickHouse / Snowflake)
                                         ↓
                                  BI (Superset / Tableau)
```

---

## 9. 缓存设计（仅概念，详见 [07](07-middleware-and-messaging.md)）

数据层视角：
- **多级缓存**：浏览器 → CDN → 网关缓存 → 应用本地缓存 → 分布式缓存 → DB
- **缓存就是冗余**：必须接受"缓存可能脏"
- **缓存失效**：cache aside（最常用）、write-through、write-behind
- **三大问题**：缓存穿透、缓存击穿、缓存雪崩

---

## 10. 反模式

| 反模式 | 痛点 |
|---|---|
| OLTP 库跑 OLAP 查询 | 拖慢全业务 |
| 大字段（TEXT/BLOB）混在主表 | 内存浪费、IO 暴涨 |
| ENUM 字段无版本管理 | 加值要改表 |
| 时间字段用本地时区 | 跨地域 BUG |
| 一开始就分库分表 | 复杂度爆炸 |
| 缓存当唯一数据源 | 挂了数据没了 |
| 共享数据库的微服务 | 拆服务的努力全废 |
| Schema-free 当借口不设计 | 半年后没人知道字段含义 |

---

## 11. 自检清单

- [ ] 我能讲清 OLTP 和 OLAP 的差异，并能识别"OLAP 跑在 OLTP 库"的反模式。
- [ ] 我能为一个新业务做出合理的数据库选型（带理由）。
- [ ] 我能讲最左前缀原则和覆盖索引。
- [ ] 我能讲分片键的选择原则和"一旦选定不可改"的代价。
- [ ] 我知道 CDC 是什么、能解决什么。
- [ ] 我能讲数据湖 vs 数仓 vs 湖仓的差异。
- [ ] 我能说出我系统所有金额字段的存储方式（整数分）。
- [ ] 我能讲清现有系统的复制拓扑和容灾边界。

下一章：[07-middleware-and-messaging.md](07-middleware-and-messaging.md)。
