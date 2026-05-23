# 12 · DevOps 与交付

> 架构再好，发不到生产就没用。**部署的频率和质量是架构成熟度的指标**。这一章覆盖 CI/CD、IaC、容器、K8s、发布策略。

---

## 1. DevOps 是什么 (架构师视角)

不是工具集，是**开发与运维之间的协作模型**：
- 开发负责到底（写完不丢给运维，要参与运行）
- 运维代码化（基础设施和流水线都是代码）
- 持续集成、持续部署（小步快跑而非大版本）
- 测量驱动（指标好坏决定改进方向）

**关键四个指标 (DORA)**：
- **Deployment Frequency**：发布频率（精英团队每天多次）
- **Lead Time for Changes**：从提交到上生产的时间（精英 < 1 天）
- **Change Failure Rate**：变更引发故障率（精英 < 15%）
- **Mean Time to Recover**：故障恢复时间（精英 < 1 小时）

把这四个数字摆出来，团队成熟度就一目了然。

---

## 2. CI/CD 流水线

### 2.1 标准阶段

```
[提交] → [Lint] → [Build] → [Unit Test] → [集成测试]
       → [安全扫描] → [打包] → [部署 Dev] → [E2E 测试]
       → [部署 Staging] → [人工审批] → [部署 Prod] → [冒烟测试]
```

每个阶段失败就**停**，不让烂代码往后走。

### 2.2 关键原则

| 原则 | 含义 |
|---|---|
| **快速反馈** | 流水线 < 10 分钟，超过就会被绕过 |
| **可重现** | 同一 commit 跑十次结果一致 |
| **不可变制品** | 一次构建，多环境部署同一镜像 |
| **左移测试** | 单测、集成测试在前，E2E 在后 |
| **门禁化** | 测试覆盖率、安全扫描、性能基线都能卡 |

### 2.3 工具

| 工具 | 特点 |
|---|---|
| **GitHub Actions** | YAML、托管、生态强 |
| **GitLab CI** | YAML、自托管友好 |
| **Jenkins** | 老牌、插件多、UI 老 |
| **CircleCI / TravisCI** | SaaS |
| **Argo Workflows** | K8s 原生 |
| **Tekton** | 云原生 CD 框架 |

### 2.4 制品仓库

| 类型 | 工具 |
|---|---|
| 容器镜像 | Harbor, ECR, GCR, Docker Hub |
| Maven/Npm/PyPI | Nexus, Artifactory |
| Helm Chart | ChartMuseum, Harbor |

---

## 3. 基础设施即代码 (IaC)

### 3.1 为什么 IaC

- 环境可重现（不再"在我机器上能跑"）
- 变更可审计（PR 评审、git 历史）
- 灾难恢复快（重建集群一行命令）
- 多环境一致

### 3.2 工具

| 工具 | 适用 |
|---|---|
| **Terraform** | 多云 IaC 事实标准 |
| **OpenTofu** | Terraform 的开源分叉 |
| **Pulumi** | 用编程语言（TS/Python/Go）写 IaC |
| **AWS CloudFormation** | AWS 专用 |
| **CDK** (AWS / Terraform CDK) | 高层抽象 |
| **Ansible** | 配置管理（不只是基础设施） |
| **Crossplane** | K8s 原生 IaC |

### 3.3 状态管理

- Terraform 的 state 文件**不可丢**，放远程后端（S3 + DynamoDB lock、Terraform Cloud）。
- 多人协作必须有 state 锁。
- 不要手动改云资源（drift 灾难）。

### 3.4 模块化

```
modules/
  vpc/
  rds/
  k8s-cluster/

environments/
  dev/
    main.tf       (引用 modules + dev 参数)
  prod/
    main.tf       (引用 modules + prod 参数)
```

绝大多数差异通过参数体现，公共结构在 module 里。

---

## 4. 容器 (Container)

### 4.1 核心概念

- **镜像 (Image)**：静态文件，分层 (layer)
- **容器 (Container)**：镜像的运行实例，进程级隔离
- **底层**：Linux namespaces（隔离）+ cgroups（限额）+ UnionFS（分层文件系统）

### 4.2 Dockerfile 最佳实践

```dockerfile
# 多阶段构建：build 阶段大、runtime 阶段小
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o app

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/app /app
USER nonroot
ENTRYPOINT ["/app"]
```

要点：
- **多阶段构建**：runtime 镜像不含 build 工具
- **缓存友好的层顺序**：变得少的（依赖）在前，变得多的（源码）在后
- **小基础镜像**：distroless、alpine（注意 musl 兼容性）
- **不要 root 跑**
- **不要 latest tag**（版本明确）
- **不要带敏感信息进镜像**

### 4.3 镜像安全

- 用 **Trivy / Grype** 扫漏洞
- 镜像签名（Cosign）
- 私有 registry + 镜像同步策略

---

## 5. Kubernetes (K8s)

K8s 是云原生事实标准。架构师**必须懂核心抽象**，不必懂全部细节。

### 5.1 核心对象

| 对象 | 用途 |
|---|---|
| **Pod** | 调度的最小单位，1 个或多个容器 |
| **Deployment** | 管理无状态 Pod 副本（rolling update） |
| **StatefulSet** | 有状态服务（DB、Kafka）：稳定网络 ID、持久存储 |
| **DaemonSet** | 每节点跑一个（日志收集、监控） |
| **Job / CronJob** | 一次性 / 定时任务 |
| **Service** | 稳定的内部访问入口（ClusterIP / NodePort / LoadBalancer） |
| **Ingress** | L7 流量入口、路由 |
| **ConfigMap / Secret** | 配置注入 |
| **PersistentVolume / PVC** | 持久存储 |
| **Namespace** | 逻辑隔离 |

### 5.2 架构师视角的 K8s 心智

#### 5.2.1 控制循环 (Reconciliation Loop)

K8s 的本质：你声明"期望状态"，控制器不断对比"实际状态"，朝期望状态收敛。

这意味着：
- 不要直接改 Pod，改 Deployment（高一级的期望）
- 任何手工修改都会被控制器"修正"
- 自定义 Operator 也是这个模式（CRD + Controller）

#### 5.2.2 资源管理

```yaml
resources:
  requests:    # 调度参考、最低保证
    cpu: 100m
    memory: 256Mi
  limits:      # 上限
    cpu: 500m
    memory: 512Mi
```

- **requests 太低 / 不设** → 节点超卖，资源紧张时被 Throttling/OOM
- **limits 太低** → 容易 OOM Kill
- **CPU 用 limits 是有争议的**：limit 会限速即使节点空闲。生产推荐**只设 requests，不设 CPU limits**（内存还是要 limits）

#### 5.2.3 健康检查

```yaml
livenessProbe:    # 失败就重启容器
  ...
readinessProbe:   # 失败就从 Service 摘掉，不重启
  ...
startupProbe:     # 启动慢的服务用，避免被 liveness 提前杀
  ...
```

**Readiness 比 Liveness 更重要**。Liveness 太敏感会反复重启。

#### 5.2.4 调度

- **NodeSelector / Affinity / Taints & Tolerations**：选/避节点
- **PodAffinity / Anti-Affinity**：把相关 Pod 放一起，把同类 Pod 分散
- **PDB (PodDisruptionBudget)**：保证 N 个副本以上始终在跑

### 5.3 工具链

| 工具 | 用途 |
|---|---|
| **kubectl** | CLI |
| **Helm** | 应用包管理器（Chart） |
| **Kustomize** | 配置变体（dev/staging/prod） |
| **ArgoCD / Flux** | GitOps 持续部署 |
| **Lens / k9s** | 集群可视化 |

### 5.4 不要犯的错

- 把 K8s 当成 VM 用（手工 kubectl 改东西、不写 YAML）
- 一个集群跑所有环境（爆炸半径太大）
- 把状态服务放 K8s 但不用 StatefulSet
- 不设 resource requests/limits
- 不做 PDB → 节点维护时业务挂

---

## 6. GitOps

### 6.1 思想

**Git 仓库 = 系统期望状态的唯一真相源 (SSoT)**。

- 应用配置、K8s manifest、基础设施 IaC 都在 Git
- 部署不靠 push（CI 推到集群），而是 **pull**（集群里的 Operator 看到 Git 变了就同步）
- 改动通过 PR 评审、合并触发部署
- 回滚 = git revert

### 6.2 工具

- **ArgoCD**（用得最多）
- **Flux**

### 6.3 价值

- 部署可审计（所有变更都在 Git）
- 灾难恢复快（重建集群 = 重 sync Git）
- 多集群一致

---

## 7. 发布策略

### 7.1 几种主流

| 策略 | 描述 | 优缺 |
|---|---|---|
| **Recreate (停-启)** | 老的全停，新的全起 | 简单、有停机 |
| **Rolling Update** | 逐批替换 | K8s 默认，无停机但混合状态 |
| **Blue-Green** | 蓝绿两套并存，切流量 | 回滚秒级，要双倍资源 |
| **Canary 灰度** | 小比例流量切到新版本 | 可控、可观察、可回滚 |
| **A/B 测试** | 按用户特征分流 | 验证业务效果 |
| **Shadow / Dark Launch** | 复制流量给新版本但不返回 | 真实压测、零风险 |

### 7.2 选型

- 一般 Web 服务 → Rolling Update + 健康检查 + 灰度
- 强一致服务 / 大版本变更 → Blue-Green
- 业务实验 → A/B
- 新算法 / 新存储 → Shadow

### 7.3 关键技术

- **服务网格 / Ingress** 控制流量比例（Istio、Argo Rollouts）
- **Feature Flag** 解耦"部署"和"放量"
- **数据库变更与代码变更解耦**（兼容性发布：先加字段、再用、再删）

---

## 8. Feature Flag (功能开关)

把"上线 = 发布"分为：
- **Deploy**：代码到生产，但功能关着
- **Release**：开关打开，功能可见

### 8.1 价值

- 减小变更风险（出问题秒切回）
- 灰度放量（按用户/百分比）
- A/B 实验
- 临时关键功能（黑名单、紧急下线）

### 8.2 工具

- **LaunchDarkly**（商业）
- **Unleash**（开源）
- **GrowthBook**
- 自研：配置中心 + 简单判断

### 8.3 反模式

- 开关不清理（半年后 200 个开关没人懂）
- 开关代码深度耦合业务（删都不敢删）

**规则**：每个开关定上线日期 + 清理日期 + Owner。

---

## 9. 数据库变更 (Schema Migration)

### 9.1 痛点

代码可以蓝绿，数据库不行。在线变更要兼容新老代码同时跑。

### 9.2 安全变更原则

| 变更 | 是否安全 |
|---|---|
| 加列（NULL 或带默认值，且默认计算不锁表） | ✓ |
| 删列 | ✗（先停代码用，再发版删） |
| 改列名 | ✗（新加 → 双写 → 切读 → 删旧） |
| 改列类型 | 危险（看 DB 实现） |
| 加非空约束 | 危险（先填默认值再加） |
| 加索引 | 大表很慢，用 ONLINE / CONCURRENTLY |

### 9.3 工具

- **Flyway** / **Liquibase**：版本化迁移
- **gh-ost** / **pt-online-schema-change**：MySQL 大表 online DDL
- **PG**：原生 `CREATE INDEX CONCURRENTLY`、`ALTER TABLE ... USING`

---

## 10. 平台工程 (Platform Engineering)

新兴方向：**把内部工具/平台当产品做**。

- 给开发者提供"自助式"基础设施（一键创建环境、一键部署）
- 减少 cognitive load
- IDP (Internal Developer Platform)：Backstage 等

架构师在大公司经常参与平台工程，**用户是开发者**，目标是开发效能。

---

## 11. 反模式

| 反模式 | 痛点 |
|---|---|
| 手工部署 | 不可复现、易错 |
| 各环境配置散落 | 漂移、上线时炸 |
| 没有回滚机制 | 出事只能向前修 |
| 把 K8s 当 VM | 配置爆炸、不可复现 |
| 不用 Probe | Pod 挂着不被识别 |
| Feature Flag 永不清理 | 代码逻辑爆炸 |
| 数据库变更不兼容老代码 | 部署期间炸 |
| 大版本一次性上 | 风险无法控制 |

---

## 12. 自检清单

- [ ] 我能讲清 DORA 四指标，并知道我团队当前的数值。
- [ ] 我的流水线 < 10 分钟。
- [ ] 我的基础设施 100% 用 IaC 管。
- [ ] 我的镜像走多阶段构建、非 root、有扫描。
- [ ] 我能讲清 K8s 控制循环和 Reconciliation 模式。
- [ ] 我系统所有 Pod 设了 resource requests + readiness probe。
- [ ] 我团队部署用 GitOps 模式。
- [ ] 我系统的功能上线和部署解耦（Feature Flag）。
- [ ] 我的数据库变更脚本可前向兼容。

下一章：[13-cloud-and-cost.md](13-cloud-and-cost.md)。
