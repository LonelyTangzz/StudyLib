# 10 · 安全架构

> 安全不是"上线后再加"的功能。它是横切关注点，必须从架构第一天就考虑。这一章覆盖架构师必懂的认证、授权、加密、零信任、OWASP、供应链安全。

---

## 1. 安全的三大目标（CIA）

| 目标 | 含义 |
|---|---|
| **Confidentiality 机密性** | 数据只让有权的人看见 |
| **Integrity 完整性** | 数据不被未授权篡改 |
| **Availability 可用性** | 服务持续可访问（DoS 也是安全问题） |

加一个常被忽视的：**可追溯性 (Accountability)** —— 谁干的、什么时候。

---

## 2. 认证 (Authentication) 与授权 (Authorization)

### 2.1 区分

- **认证**：你是谁？（验证身份）
- **授权**：你能做什么？（验证权限）

两者必须分开设计。常见错误是认证通过就赋予所有权限。

### 2.2 常见认证方式

| 方式 | 适用场景 | 注意 |
|---|---|---|
| 用户名密码 | 传统 Web | 必须**哈希存储**（bcrypt/argon2），不可逆 |
| 手机号 + 验证码 | 移动端 | 验证码限频、限次 |
| 邮箱 + 链接 | Web | 链接带短效 token |
| 第三方登录（OAuth） | "用 Google 登录" | OIDC 是规范 |
| **MFA / 2FA** | 高安全要求 | TOTP、短信、硬件 key（推 TOTP） |
| **Passkey / WebAuthn** | 现代无密码 | 未来方向 |
| **mTLS** | 服务间 / 零信任 | 双向证书 |

### 2.3 OAuth 2.0 / OIDC

#### OAuth 2.0 = 授权框架，OIDC = OAuth 之上的认证层

四种 Grant Type（实际只该用前两个）：

| Grant | 适用 |
|---|---|
| **Authorization Code + PKCE** | 所有 Web/移动/SPA 推荐 |
| **Client Credentials** | 服务到服务（无用户参与） |
| ~~Implicit~~ | 已废弃，不要用 |
| ~~Resource Owner Password~~ | 几乎已废弃 |

**关键概念**：
- Authorization Server：发 token
- Resource Server：被访问的 API
- Client：应用
- Resource Owner：用户
- **Scope**：权限粒度

#### Token 类型

- **Access Token**：短时（5-60 分钟），调 API 用
- **Refresh Token**：长时（天-月），换新 Access Token，**绝对保密**
- **ID Token**：OIDC 才有，包含用户身份信息（JWT 格式）

### 2.4 JWT 详解

#### 结构

```
header.payload.signature
```

三部分都是 base64url。**Header 和 Payload 是明文（可读）**，只有 signature 保护篡改。

#### 常见坑

1. **`alg: none` 攻击**：库要拒绝 none 签名。
2. **算法混淆**：服务期望 RS256，攻击者用 HS256 + 公钥作为密钥签 —— 库要锁定 alg。
3. **不验过期**：必须校验 `exp`、`nbf`。
4. **不验 issuer / audience**：跨域被复用。
5. **存敏感信息**：Payload 不是加密的。
6. **撤销难**：天然限制，加黑名单又失去无状态优势。

### 2.5 授权模型

| 模型 | 描述 | 适用 |
|---|---|---|
| **DAC** (Discretionary) | 资源所有者自定权限 | 文件系统 |
| **MAC** (Mandatory) | 系统强制规则 | 军事、合规 |
| **RBAC** (Role-Based) | 用户 → 角色 → 权限 | 企业应用主流 |
| **ABAC** (Attribute-Based) | 基于属性策略（用户属性、资源属性、环境） | 复杂权限 |
| **ReBAC** (Relationship-Based) | 基于关系图（Google Zanzibar） | 共享文档、社交 |
| **PBAC / Policy-Based** | OPA、Cedar 这种 Policy as Code | 现代趋势 |

**实际工程**：90% 项目从 RBAC 开始，部分加 ABAC 扩展。复杂权限直接上 OPA / Cedar。

### 2.6 多租户隔离

- **物理隔离**：每租户独立 DB / 集群（贵、安全）
- **Schema 隔离**：共享 DB，独立 schema
- **行级隔离**：共享表，按 `tenant_id` 过滤（最常见）

**行级隔离的陷阱**：任何 SQL 漏掉 `tenant_id` 就泄露。必须在 ORM/中间件层强制注入，不靠开发自觉。

---

## 3. 加密

### 3.1 对称 vs 非对称

| 类型 | 特点 | 用途 |
|---|---|---|
| **对称加密** (AES) | 同一密钥加解密，快 | 数据加密 |
| **非对称加密** (RSA, ECC) | 公钥加密私钥解，慢 | 密钥交换、签名 |

TLS 用**非对称**协商对称密钥，然后用**对称**加密通信内容。

### 3.2 哈希 vs 加密

- **哈希** (SHA-256)：不可逆，验证完整性。
- **加密**：可逆。

**密码必须用专用哈希**：bcrypt、argon2、scrypt。它们**故意慢**，防止暴力破解。**不要用 MD5、SHA1、SHA256 存密码**。

### 3.3 传输加密

- **TLS**：所有公网通信必须。
- **TLS 1.3**：握手快、安全好，**默认必选**。
- **HSTS**：浏览器强制 HTTPS。
- **mTLS**：服务间双向，零信任基础。

### 3.4 存储加密

- **At-Rest 加密**：磁盘级、DB 级、字段级。
- 字段级（如身份证号、银行卡）—— 应用层用 AES + KMS 管密钥。
- 不要把密钥写代码 / 配置文件，用 KMS / Vault。

### 3.5 密钥管理

- **KMS** (AWS KMS、阿里 KMS、HashiCorp Vault)：托管密钥、自动轮换、审计。
- 密钥分层：根密钥（KMS 管）+ 数据密钥（用根密钥加密后存）。
- 定期轮换。
- 应用永远拿不到明文根密钥。

---

## 4. OWASP Top 10（每年看一遍）

应用层最常见的漏洞类别。架构师**必须熟知前 10**：

### 4.1 注入 (Injection)

- SQL 注入：用**参数化查询**，永远不拼字符串。
- 命令注入：避免 `shell=True` 拼用户输入。
- LDAP 注入、NoSQL 注入同理。

### 4.2 失效的身份验证

- 弱密码策略
- 会话 ID 可预测
- Session Fixation
- Session 永不过期

### 4.3 敏感数据泄露

- 日志打了密码 / 银行卡 / 身份证
- 错误响应带堆栈
- 备份不加密
- 隐私字段未脱敏返回

### 4.4 XML 外部实体 (XXE)

XML 解析器允许加载外部实体 → 任意文件读取。**默认禁用外部实体**。

### 4.5 失效的访问控制 (Broken Access Control)

- 改 URL 参数能看别人数据（IDOR - Insecure Direct Object Reference）
- 越权访问
- 接口没鉴权

**所有接口默认拒绝**，显式授权放行。

### 4.6 安全配置错误

- 默认密码没改
- 调试模式上线
- 不必要的端口/服务开放
- CORS 配置 `*`

### 4.7 跨站脚本 (XSS)

- 用户输入直接渲染到 HTML → 执行恶意 JS
- 防御：**输出转义**（不是输入过滤）+ CSP 头

### 4.8 不安全的反序列化

Java 的 ObjectInputStream、PHP 的 unserialize，反序列化用户控制的字节流 → 远程执行。

- 用 JSON 这类**只数据不代码**的格式
- 必须反序列化对象时，白名单允许的类

### 4.9 使用含已知漏洞的组件

- 依赖库不更新
- Log4Shell / OpenSSL Heartbleed 都是这类

防御：**SCA (Software Composition Analysis)** 工具扫，CI 卡。

### 4.10 不足的日志与监控

- 攻击发生没人知道
- 没有审计日志
- 关键操作（登录失败、权限提升、敏感数据访问）必须留痕

### 4.11 SSRF (Server-Side Request Forgery)

- 服务端帮用户去请求 URL，攻击者构造 `http://169.254.169.254/...` 拿云元数据 / 内网信息。
- 防御：URL 白名单、禁内网 IP、禁 file://、禁元数据 IP。

### 4.12 CSRF (Cross-Site Request Forgery)

- 用户被诱导点链接，浏览器自动带上 cookie 发请求 → 替用户执行操作。
- 防御：SameSite Cookie、CSRF Token、关键操作要二次确认。

---

## 5. 零信任 (Zero Trust)

### 5.1 核心原则

"**Never trust, always verify.**" —— 不再假设"内网安全"。

- 每次访问都验证（不靠"在内网"豁免）
- 最小权限（按需授权，不给"管理员"通行证）
- 假设已被攻破（设计时考虑泄露后如何减损）

### 5.2 落地实践

- **mTLS** 服务间双向认证
- **SPIFFE / SPIRE** 服务身份框架
- **BeyondCorp** 模式（Google 推动）：员工不用 VPN，所有内网应用通过身份代理访问
- **Service Mesh** 天然支持 mTLS

### 5.3 跟传统"内外网"对比

| 传统 | 零信任 |
|---|---|
| 防火墙 = 城墙 | 每个服务自带门禁 |
| 内网即可信 | 任何请求都要带身份 |
| VPN 接入 | 应用级认证代理 |
| 静态规则 | 动态策略（基于身份、设备、行为） |

---

## 6. 供应链安全 (Supply Chain Security)

### 6.1 攻击面

- 依赖库被投毒（npm、PyPI 经常出事）
- 构建链路被篡改（CI runner、镜像基础层）
- 签名密钥泄露 → 发恶意更新

### 6.2 防御

- **依赖锁定** (lockfile、go.sum、Cargo.lock)
- **SCA 扫描**（Snyk、Dependabot、GitHub Advisory）
- **SBOM** (Software Bill of Materials)：列出所有组件清单
- **SLSA** 框架：等级化的供应链完整性
- **镜像签名**（Cosign、Notation）
- **构建可复现**（同输入同输出，发现篡改）

---

## 7. 隐私与合规

### 7.1 主要法规

| 法规 | 范围 |
|---|---|
| **GDPR** | 欧盟 |
| **CCPA** | 加州 |
| **PIPL** | 中国《个人信息保护法》 |
| **HIPAA** | 美国医疗 |
| **PCI-DSS** | 信用卡 |

### 7.2 共同要求

- 明确告知收集的数据用途
- 用户有权访问、修改、删除自己的数据
- 数据最小化原则
- 跨境传输有限制
- 出事必须通报

### 7.3 架构落地

- **数据分类**：哪些是 PII、敏感、机密
- **脱敏**：日志、备份、测试环境
- **删除能力**：能按用户 ID 真删（含所有副本、备份、缓存）
- **审计日志**：谁访问了什么数据

---

## 8. 安全开发生命周期 (SDLC)

集成到日常开发流程：

```
设计阶段:    威胁建模 (STRIDE)
开发阶段:    安全编码规范、SAST 静态扫描
依赖管理:    SCA 扫描 + 锁版本
测试阶段:    DAST 动态扫描、渗透测试
发布阶段:    镜像签名、SBOM、配置审计
运行阶段:    WAF、入侵检测、日志审计、事件响应
```

### 8.1 威胁建模 (STRIDE)

设计阶段问六种威胁：
- **S**poofing 假冒
- **T**ampering 篡改
- **R**epudiation 抵赖
- **I**nformation Disclosure 信息泄露
- **D**enial of Service 拒绝服务
- **E**levation of Privilege 提权

每个威胁问"哪里可能发生"、"怎么防"。

---

## 9. 反模式

| 反模式 | 痛点 |
|---|---|
| 密码用 MD5 存 | 暴破秒杀 |
| 内网就不加 TLS | 任何泄露都全开 |
| 接口靠"前端不调用"做安全 | API 直接调爆 |
| 错误响应带堆栈 | 信息泄露给攻击者 |
| 拼字符串构造 SQL | SQL 注入 |
| JWT 永不过期 + 存敏感信息 | 撤不了 + 泄露 |
| 密钥写代码里 | 仓库泄露 = 完蛋 |
| 安全是"安全团队的事" | 上线前才介入，全部推倒重做 |
| 多租户行级靠开发自觉过滤 | 漏一个 SQL 全公司炸 |

---

## 10. 自检清单

- [ ] 我能区分认证和授权，并能为新业务选合适的方案。
- [ ] 我系统的密码用 bcrypt/argon2 存。
- [ ] 我系统所有公网流量走 TLS 1.3。
- [ ] 我能讲 OWASP Top 10 至少 7 项的防御方法。
- [ ] 我系统的所有接口默认拒绝、显式授权。
- [ ] 我系统的密钥用 KMS / Vault 管理，不在代码里。
- [ ] 我有依赖扫描 (SCA) 在 CI 中卡门禁。
- [ ] 我能做基础威胁建模（STRIDE）。
- [ ] 我系统的关键操作有审计日志且不可篡改。

下一章：[11-observability.md](11-observability.md)。
