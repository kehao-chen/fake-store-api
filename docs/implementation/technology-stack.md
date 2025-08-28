# 技術堆疊詳細說明

[← 返回文件中心](../README.md) | [實作指南](../implementation/) | **技術堆疊**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-28
- **目標讀者**: 開發者、架構師、DevOps 工程師
- **相關文件**: 
  - [C4 架構模型](../architecture/c4-model.md)
  - [部署架構](../operations/deployment.md)
  - [測試策略](./testing-strategy.md)
  - [安全實作](./security.md)

## 技術堆疊總覽

Fake Store API 採用現代化的技術堆疊，強調雲原生、響應式編程和微服務架構準備。

### 核心技術選擇
- **後端框架**: Spring Boot 3.x with WebFlux
- **程式語言**: Java 21 LTS
- **資料庫**: PostgreSQL 15+
- **快取**: Valkey (Redis-compatible)
- **容器化**: Docker & Docker Compose
- **API 閘道**: Spring Cloud Gateway
- **監控**: Prometheus + Grafana

## 1. 後端技術堆疊

### 1.1 核心框架 - Spring Boot 3.x

#### 版本選擇
```xml
<spring-boot.version>3.2.0</spring-boot.version>
<spring-cloud.version>2023.0.0</spring-cloud.version>
```

#### 選擇理由
- **生產就緒**: 內建健康檢查、指標、配置管理
- **響應式編程**: WebFlux 支援高並發、非阻塞 I/O
- **雲原生支援**: Kubernetes 友好、容器化最佳化
- **社群活躍**: 豐富的生態系統和第三方整合

#### 核心依賴
```xml
<dependencies>
    <!-- Spring Boot Starters -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
</dependencies>
```

### 1.2 程式語言 - Java 21 LTS

#### 版本選擇理由
- **LTS 支援**: 長期支援版本，穩定性保證
- **虛擬線程**: Project Loom 提供的輕量級並發
- **Pattern Matching**: 增強的模式匹配功能
- **Record Classes**: 不可變資料載體
- **性能改進**: ZGC、Shenandoah GC 優化

#### JVM 設定
```properties
# JVM Options for Production
-Xms1g
-Xmx2g
-XX:+UseZGC
-XX:+EnableDynamicAgentLoading
-XX:MaxMetaspaceSize=256m
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/heap-dump.hprof
```

### 1.3 響應式編程 - Spring WebFlux

#### 技術特性
- **非阻塞 I/O**: Netty 底層支援
- **背壓處理**: 自動流量控制
- **函數式編程**: Mono/Flux 響應式流
- **高並發**: 適合 I/O 密集型應用

#### 實作範例
```java
@RestController
@RequestMapping("/v1/products")
public class ProductController {
    
    @GetMapping
    public Flux<Product> getProducts(
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(required = false) String pageToken) {
        return productService.findProducts(pageSize, pageToken)
            .delayElements(Duration.ofMillis(10)) // 背壓控制
            .timeout(Duration.ofSeconds(5));      // 超時處理
    }
}
```

## 2. 資料層技術

### 2.1 主資料庫 - PostgreSQL 15+

#### 選擇理由
- **ACID 合規**: 完整的事務支援
- **JSON 支援**: JSONB 類型提供 NoSQL 彈性
- **效能優化**: 平行查詢、分區表、索引優化
- **擴展性**: 支援複製、分片、讀寫分離

#### 連線池配置 (HikariCP)
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 15
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
      leak-detection-threshold: 60000
```

#### 資料庫最佳化
```sql
-- 關鍵索引策略
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
CREATE INDEX idx_cart_items_user ON cart_items(user_id);

-- 分區策略 (訂單表按月分區)
CREATE TABLE orders_2025_01 PARTITION OF orders
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

### 2.2 快取層 - Valkey (Redis-compatible)

#### 選擇理由
- **Redis 相容**: 無縫遷移，豐富的資料結構
- **開源授權**: 避免 Redis 授權問題
- **高性能**: 記憶體儲存，微秒級延遲
- **持久化選項**: RDB 快照、AOF 日誌

#### 快取策略
```yaml
cache:
  valkey:
    host: valkey-cache
    port: 6379
    timeout: 2000
    pool:
      max-active: 8
      max-idle: 8
      min-idle: 2
    ttl:
      products: 300      # 5 分鐘
      categories: 600    # 10 分鐘
      user-sessions: 900 # 15 分鐘
```

#### 資料結構使用
| 用途 | Redis 資料型別 | 範例 |
|-----|---------------|------|
| 產品快取 | String | `product:123` → JSON |
| 購物車 | Hash | `cart:user:456` → items |
| 熱門產品 | Sorted Set | `popular:products` → score |
| 限流計數 | String + TTL | `rate:api:user:789` → count |
| Session | Hash | `session:abc123` → data |

### 2.3 ORM - Spring Data JPA + Hibernate

#### 配置最佳化
```yaml
spring:
  jpa:
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        jdbc:
          batch_size: 20
          fetch_size: 100
        order_inserts: true
        order_updates: true
        query:
          in_clause_parameter_padding: true
        generate_statistics: false
    hibernate:
      ddl-auto: validate
    show-sql: false
```

## 3. API 層技術

### 3.1 API 閘道 - Spring Cloud Gateway

#### 功能特性
- **路由管理**: 動態路由配置
- **限流**: 基於令牌桶算法
- **認證整合**: JWT、OAuth2 支援
- **監控整合**: Micrometer metrics

#### 限流配置
```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: products-route
          uri: http://api-service:8080
          predicates:
            - Path=/v1/products/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter:
                  replenishRate: 100
                  burstCapacity: 200
                  requestedTokens: 1
```

### 3.2 API 文件 - OpenAPI 3.0

#### SpringDoc 整合
```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webflux-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

#### 配置
```yaml
springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
    tagsSorter: alpha
  show-actuator: true
```

## 4. 安全技術

### 4.1 認證 - Spring Security + JWT

#### JWT 配置
```yaml
jwt:
  secret: ${JWT_SECRET:your-256-bit-secret}
  algorithm: RS256
  access-token-lifetime: 900    # 15 分鐘
  refresh-token-lifetime: 604800 # 7 天
  issuer: fake-store-api
```

### 4.2 OAuth 2.0 整合

#### 支援的提供者
- Google OAuth 2.0
- GitHub OAuth
- 自訂 OAuth Server

## 5. 容器化技術

### 5.1 Docker

#### 基礎映像選擇
```dockerfile
# Multi-stage build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 5.2 Docker Compose

#### 服務編排
```yaml
version: '3.9'

services:
  api-service:
    build: .
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: docker
    depends_on:
      - postgresql
      - valkey-cache
    networks:
      - fake-store-network

  postgresql:
    image: postgres:15-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: fakestore
      POSTGRES_USER: fakestore
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    networks:
      - fake-store-network

  valkey-cache:
    image: valkey/valkey:7-alpine
    volumes:
      - valkey-data:/data
    networks:
      - fake-store-network

networks:
  fake-store-network:
    driver: bridge

volumes:
  postgres-data:
  valkey-data:
```

## 6. 測試技術

### 6.1 測試框架

| 框架 | 用途 | 版本 |
|------|------|------|
| JUnit 5 | 單元測試 | 5.10.0 |
| Mockito | Mock 框架 | 5.5.0 |
| TestContainers | 整合測試 | 1.19.0 |
| RestAssured | API 測試 | 5.3.0 |
| ArchUnit | 架構測試 | 1.1.0 |
| WireMock | API Mock | 3.0.0 |

### 6.2 TestContainers 設定

```java
@SpringBootTest
@Testcontainers
class IntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = 
        new PostgreSQLContainer<>("postgres:15-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");
    
    @Container
    static GenericContainer<?> valkey = 
        new GenericContainer<>("valkey/valkey:7-alpine")
            .withExposedPorts(6379);
}
```

## 7. 監控與可觀測性

### 7.1 Prometheus + Grafana

#### Micrometer 配置
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: fake-store-api
      environment: ${ENVIRONMENT:development}
```

### 7.2 日誌 - SLF4J + Logback

#### 結構化日誌配置
```xml
<configuration>
    <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeContext>true</includeContext>
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>spanId</includeMdcKeyName>
        </encoder>
    </appender>
    
    <root level="INFO">
        <appender-ref ref="JSON"/>
    </root>
</configuration>
```

### 7.3 追蹤 - OpenTelemetry

```yaml
opentelemetry:
  traces:
    exporter: jaeger
    endpoint: http://jaeger:14250
  metrics:
    exporter: prometheus
```

## 8. 開發工具

### 8.1 建置工具 - Maven

```xml
<properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
</properties>
```

### 8.2 程式碼品質工具

| 工具 | 用途 | 整合方式 |
|------|------|----------|
| SonarQube | 程式碼品質 | Maven Plugin |
| Checkstyle | 程式碼風格 | Maven Plugin |
| SpotBugs | Bug 檢測 | Maven Plugin |
| JaCoCo | 覆蓋率 | Maven Plugin |

### 8.3 IDE 支援

- **IntelliJ IDEA**: 推薦使用，完整 Spring 支援
- **VS Code**: 輕量級選擇，需安裝 Java 擴展
- **Eclipse**: 傳統選擇，Spring Tools Suite

## 9. 第三方服務整合

### 9.1 支付 - Stripe

```java
@Configuration
public class StripeConfig {
    @Value("${stripe.api.key}")
    private String apiKey;
    
    @Bean
    public Stripe stripeClient() {
        Stripe.apiKey = apiKey;
        return new Stripe();
    }
}
```

### 9.2 郵件服務

- **開發環境**: MailHog (SMTP 測試)
- **生產環境**: SendGrid / AWS SES

## 10. 技術決策理由

### 為什麼選擇 Spring Boot？
1. **成熟穩定**: 企業級框架，生產驗證
2. **生態豐富**: 完整的 Spring 生態系統
3. **雲原生**: Kubernetes、容器化友好
4. **社群支援**: 活躍的社群和文件

### 為什麼選擇 PostgreSQL？
1. **ACID 合規**: 金融級事務支援
2. **擴展性強**: 支援大數據量
3. **功能豐富**: JSONB、全文搜索、GIS
4. **開源免費**: 無授權成本

### 為什麼選擇 Valkey？
1. **Redis 相容**: 無痛遷移
2. **開源許可**: BSD 3-Clause
3. **性能優異**: 微秒級延遲
4. **功能完整**: 支援所有 Redis 資料結構

### 為什麼選擇 WebFlux？
1. **高並發**: 非阻塞 I/O
2. **資源效率**: 少量線程處理大量請求
3. **響應式**: 背壓、流量控制
4. **現代化**: 函數式編程支援

## 技術升級路徑

### 短期計畫（3個月）
- 升級到 Spring Boot 3.3
- 整合 OpenTelemetry
- 加入 GraalVM Native Image 支援

### 中期計畫（6個月）
- 微服務拆分準備
- Event Sourcing 探索
- GraphQL API 支援

### 長期計畫（12個月）
- Kubernetes 部署
- Service Mesh (Istio)
- 多區域部署

## 相關文件

- [C4 架構模型](../architecture/c4-model.md) - 系統架構設計
- [部署架構](../operations/deployment.md) - 容器化部署
- [測試策略](./testing-strategy.md) - 測試技術選擇
- [安全實作](./security.md) - 安全技術實作
- [效能調優](../operations/performance-tuning.md) - 效能優化

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-28*