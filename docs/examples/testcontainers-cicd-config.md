# TestContainers CI/CD 配置與最佳實踐

完整的 TestContainers 在 CI/CD 環境中的配置、最佳化和生產部署策略。

## GitHub Actions CI/CD 配置

### 1. 主要工作流程配置

```yaml
# .github/workflows/testcontainers-ci.yml
name: TestContainers CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    # 每天午夜執行完整測試
    - cron: '0 0 * * *'

env:
  JAVA_VERSION: '21'
  MAVEN_OPTS: '-Xmx1024m'
  TESTCONTAINERS_RYUK_DISABLED: true
  TESTCONTAINERS_CHECKS_DISABLE: true

jobs:
  # 快速檢查作業
  quick-checks:
    name: 快速檢查 (編譯 + 單元測試)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Set up JDK ${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          
      - name: Cache Maven dependencies
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2
          
      - name: Compile project
        run: ./mvnw clean compile test-compile
        
      - name: Run unit tests
        run: ./mvnw test -Dtest="!**/*IntegrationTest,!**/*E2ETest"
        
      - name: Upload unit test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: unit-test-results
          path: target/surefire-reports/

  # TestContainers 整合測試
  integration-tests:
    name: TestContainers 整合測試
    runs-on: ubuntu-latest
    needs: quick-checks
    timeout-minutes: 30
    
    strategy:
      matrix:
        test-group: [cart, payment, auth, e2e]
        
    services:
      docker:
        image: docker:20.10.17
        options: --privileged
        
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Set up JDK ${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          
      - name: Cache Maven dependencies
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2
          
      - name: Cache TestContainers images
        uses: actions/cache@v3
        with:
          path: ~/.testcontainers
          key: ${{ runner.os }}-testcontainers-${{ hashFiles('**/pom.xml') }}
          restore-keys: ${{ runner.os }}-testcontainers
          
      - name: Start Docker Daemon
        run: |
          sudo systemctl start docker
          sudo docker info
          
      - name: Pre-pull TestContainers images
        run: |
          docker pull postgres:15.4
          docker pull redis:7.2-alpine
          docker pull wiremock/wiremock:2.35.0
          
      - name: Run integration tests - ${{ matrix.test-group }}
        run: |
          case "${{ matrix.test-group }}" in
            "cart")
              ./mvnw test -Dtest="**/*Cart*IntegrationTest"
              ;;
            "payment") 
              ./mvnw test -Dtest="**/*Payment*IntegrationTest"
              ;;
            "auth")
              ./mvnw test -Dtest="**/*Auth*IntegrationTest"
              ;;
            "e2e")
              ./mvnw test -Dtest="**/*E2ETest"
              ;;
          esac
        env:
          SPRING_PROFILES_ACTIVE: test
          
      - name: Upload integration test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: integration-test-results-${{ matrix.test-group }}
          path: target/surefire-reports/
          
      - name: Upload test logs
        uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: test-logs-${{ matrix.test-group }}
          path: |
            target/testcontainers-logs/
            target/spring.log

  # 測試覆蓋率報告
  coverage-report:
    name: 測試覆蓋率報告
    runs-on: ubuntu-latest
    needs: integration-tests
    timeout-minutes: 15
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Set up JDK ${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          
      - name: Cache Maven dependencies
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          
      - name: Run tests with coverage
        run: ./mvnw test jacoco:report
        env:
          TESTCONTAINERS_RYUK_DISABLED: true
          
      - name: Generate coverage report
        run: ./mvnw jacoco:report
        
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: target/site/jacoco/jacoco.xml
          flags: integration-tests
          name: codecov-testcontainers
          
      - name: Upload coverage reports
        uses: actions/upload-artifact@v3
        with:
          name: coverage-reports
          path: target/site/jacoco/

  # 效能測試
  performance-tests:
    name: 效能測試
    runs-on: ubuntu-latest
    needs: integration-tests
    if: github.ref == 'refs/heads/main'
    timeout-minutes: 20
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Set up JDK ${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          
      - name: Cache Maven dependencies
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          
      - name: Run performance tests
        run: ./mvnw test -Dtest="**/*PerformanceTest" -DperformanceTest.enabled=true
        env:
          TESTCONTAINERS_RYUK_DISABLED: true
          PERFORMANCE_TEST_DURATION: 300 # 5 分鐘
          
      - name: Upload performance results
        uses: actions/upload-artifact@v3
        with:
          name: performance-results
          path: target/performance-reports/

  # 程式碼品質檢查
  code-quality:
    name: 程式碼品質檢查
    runs-on: ubuntu-latest
    needs: quick-checks
    timeout-minutes: 15
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # SonarQube 需要完整歷史
          
      - name: Set up JDK ${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          
      - name: Cache SonarQube packages
        uses: actions/cache@v3
        with:
          path: ~/.sonar/cache
          key: ${{ runner.os }}-sonar
          restore-keys: ${{ runner.os }}-sonar
          
      - name: Cache Maven dependencies
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          
      - name: Run SonarQube analysis
        run: |
          ./mvnw verify sonar:sonar \
            -Dsonar.projectKey=fake-store-api \
            -Dsonar.organization=your-org \
            -Dsonar.host.url=https://sonarcloud.io \
            -Dsonar.login=${{ secrets.SONAR_TOKEN }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  # 部署作業
  deploy:
    name: 部署到測試環境
    runs-on: ubuntu-latest
    needs: [integration-tests, coverage-report, code-quality]
    if: github.ref == 'refs/heads/main'
    timeout-minutes: 10
    
    environment:
      name: staging
      url: https://fake-store-api-staging.example.com
      
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Set up JDK ${{ env.JAVA_VERSION }}
        uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          
      - name: Build application
        run: ./mvnw clean package -DskipTests
        
      - name: Build Docker image
        run: |
          docker build -t fake-store-api:${{ github.sha }} .
          docker tag fake-store-api:${{ github.sha }} fake-store-api:latest
          
      - name: Deploy to staging
        run: |
          echo "部署到測試環境..."
          # 這裡會是實際的部署指令
```

### 2. Docker Compose 測試環境

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  # 應用服務
  fake-store-api:
    build:
      context: .
      dockerfile: Dockerfile.test
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=test
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/fake_store_test
      - SPRING_REDIS_HOST=redis
    depends_on:
      - postgres
      - redis
      - wiremock
    networks:
      - test-network

  # PostgreSQL 測試資料庫
  postgres:
    image: postgres:15.4
    environment:
      POSTGRES_DB: fake_store_test
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./src/test/resources/db:/docker-entrypoint-initdb.d
    networks:
      - test-network

  # Redis 測試快取
  redis:
    image: redis:7.2-alpine
    command: redis-server --requirepass test_redis_pass
    ports:
      - "6379:6379"
    networks:
      - test-network

  # WireMock 外部服務模擬
  wiremock:
    image: wiremock/wiremock:2.35.0
    ports:
      - "8081:8080"
    volumes:
      - ./src/test/resources/wiremock:/home/wiremock
    networks:
      - test-network

volumes:
  postgres-data:

networks:
  test-network:
    driver: bridge
```

### 3. 測試用 Dockerfile

```dockerfile
# Dockerfile.test
FROM openjdk:21-jdk-slim as builder

WORKDIR /app
COPY . .
RUN chmod +x mvnw
RUN ./mvnw clean package -DskipTests

FROM openjdk:21-jre-slim

WORKDIR /app

# 安裝測試工具
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/*.jar app.jar

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 等待依賴服務腳本
COPY scripts/wait-for-services.sh /wait-for-services.sh
RUN chmod +x /wait-for-services.sh

EXPOSE 8080

CMD ["/wait-for-services.sh", "java", "-jar", "app.jar"]
```

### 4. 等待依賴服務腳本

```bash
#!/bin/bash
# scripts/wait-for-services.sh

set -e

echo "等待 PostgreSQL 啟動..."
until nc -z postgres 5432; do
  echo "PostgreSQL 未就緒，等待..."
  sleep 2
done
echo "PostgreSQL 已就緒！"

echo "等待 Redis 啟動..."
until nc -z redis 6379; do
  echo "Redis 未就緒，等待..."
  sleep 2
done
echo "Redis 已就緒！"

echo "等待 WireMock 啟動..."
until nc -z wiremock 8080; do
  echo "WireMock 未就緒，等待..."
  sleep 2
done
echo "WireMock 已就緒！"

echo "所有服務已就緒，啟動應用..."
exec "$@"
```

## 效能最佳化策略

### 1. TestContainers 效能配置

```java
// TestContainersConfig.java
package com.fakestore.test.config;

import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.DockerImageName;

@TestConfiguration
public class TestContainersConfig {
    
    // 使用較小的映像檔提升啟動速度
    @Bean
    @Primary
    public PostgreSQLContainer<?> fastPostgreSQL() {
        return new PostgreSQLContainer<>(DockerImageName.parse("postgres:15.4-alpine"))
            .withDatabaseName("fast_test_db")
            .withUsername("test")
            .withPassword("test")
            // 效能最佳化設定
            .withCommand("postgres", 
                "-c", "fsync=off",           // 關閉 fsync 提升寫入速度
                "-c", "synchronous_commit=off", // 關閉同步提交
                "-c", "full_page_writes=off",   // 關閉全頁寫入
                "-c", "max_connections=50",     // 限制連接數
                "-c", "shared_buffers=128MB",   // 調整共享緩衝區
                "-c", "effective_cache_size=256MB") // 調整快取大小
            .withReuse(true)  // 容器重用
            .withStartupTimeout(Duration.ofSeconds(60)); // 啟動超時
    }
    
    @Bean
    @Primary 
    public GenericContainer<?> fastRedis() {
        return new GenericContainer<>(DockerImageName.parse("redis:7.2-alpine"))
            .withExposedPorts(6379)
            .withCommand("redis-server",
                "--save", "",              // 關閉持久化
                "--appendonly", "no",      // 關閉 AOF
                "--maxmemory", "128mb",    // 限制記憶體使用
                "--maxmemory-policy", "allkeys-lru") // LRU 回收策略
            .withReuse(true)
            .withStartupTimeout(Duration.ofSeconds(30));
    }
}
```

### 2. 並行測試配置

```properties
# junit-platform.properties
junit.jupiter.execution.parallel.enabled=true
junit.jupiter.execution.parallel.mode.default=concurrent
junit.jupiter.execution.parallel.mode.classes.default=concurrent
junit.jupiter.execution.parallel.config.strategy=dynamic
junit.jupiter.execution.parallel.config.fixed.parallelism=4
```

```java
// 並行測試資源管理
@Execution(ExecutionMode.CONCURRENT)
@ResourceLock(value = "DATABASE", mode = ResourceAccessMode.READ_WRITE)
class ParallelSafeIntegrationTest extends BaseIntegrationTest {
    
    @Test
    void concurrentSafeTest() {
        // 使用獨立的資料命名空間
        String testId = UUID.randomUUID().toString();
        // 測試實作...
    }
}
```

### 3. 測試資料隔離策略

```java
package com.fakestore.test.isolation;

import org.springframework.test.context.TestContext;
import org.springframework.test.context.TestExecutionListener;

/**
 * 測試資料命名空間隔離
 */
public class TestDataIsolationListener implements TestExecutionListener {
    
    @Override
    public void beforeTestMethod(TestContext testContext) {
        // 為每個測試方法建立獨立的資料命名空間
        String testId = generateTestId(testContext);
        TestDataNamespace.setCurrent(testId);
    }
    
    @Override
    public void afterTestMethod(TestContext testContext) {
        // 清理測試資料命名空間
        TestDataNamespace.clear();
    }
    
    private String generateTestId(TestContext testContext) {
        return testContext.getTestClass().getSimpleName() + "_" +
               testContext.getTestMethod().getName() + "_" +
               System.currentTimeMillis();
    }
}

@Component
public class TestDataNamespace {
    private static final ThreadLocal<String> CURRENT_NAMESPACE = new ThreadLocal<>();
    
    public static void setCurrent(String namespace) {
        CURRENT_NAMESPACE.set(namespace);
    }
    
    public static String getCurrent() {
        return CURRENT_NAMESPACE.get();
    }
    
    public static void clear() {
        CURRENT_NAMESPACE.remove();
    }
    
    public static String prefixWithNamespace(String identifier) {
        String namespace = getCurrent();
        return namespace != null ? namespace + "_" + identifier : identifier;
    }
}
```

## 監控與診斷

### 1. 測試效能監控

```java
package com.fakestore.test.monitoring;

import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.junit.jupiter.api.extension.TestWatcher;

/**
 * 測試效能監控擴展
 */
public class TestPerformanceWatcher implements TestWatcher {
    
    private final Map<String, Long> testStartTimes = new ConcurrentHashMap<>();
    
    @Override
    public void testStarted(ExtensionContext context) {
        String testName = getTestName(context);
        testStartTimes.put(testName, System.currentTimeMillis());
        System.out.println("🚀 開始測試: " + testName);
    }
    
    @Override
    public void testSuccessful(ExtensionContext context) {
        String testName = getTestName(context);
        long duration = calculateDuration(testName);
        System.out.println("✅ 測試成功: " + testName + " (" + duration + "ms)");
        
        // 記錄效能指標
        recordPerformanceMetric(testName, duration, "SUCCESS");
    }
    
    @Override
    public void testFailed(ExtensionContext context, Throwable cause) {
        String testName = getTestName(context);
        long duration = calculateDuration(testName);
        System.out.println("❌ 測試失敗: " + testName + " (" + duration + "ms)");
        System.out.println("錯誤: " + cause.getMessage());
        
        recordPerformanceMetric(testName, duration, "FAILED");
    }
    
    private long calculateDuration(String testName) {
        Long startTime = testStartTimes.remove(testName);
        return startTime != null ? System.currentTimeMillis() - startTime : -1;
    }
    
    private void recordPerformanceMetric(String testName, long duration, String status) {
        // 記錄到監控系統或檔案
        TestMetrics.record(testName, duration, status);
    }
    
    private String getTestName(ExtensionContext context) {
        return context.getTestClass().get().getSimpleName() + "." +
               context.getTestMethod().get().getName();
    }
}

// 使用方式
@ExtendWith(TestPerformanceWatcher.class)
class MonitoredIntegrationTest extends BaseIntegrationTest {
    // 測試實作
}
```

### 2. 容器健康檢查

```java
package com.fakestore.test.health;

import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.containers.PostgreSQLContainer;

public class HealthCheckConfig {
    
    public static PostgreSQLContainer<?> createHealthyPostgres() {
        return new PostgreSQLContainer<>("postgres:15.4")
            .waitingFor(Wait.forListeningPort())
            .waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*", 2))
            .withStartupTimeout(Duration.ofMinutes(2))
            .withConnectTimeoutSeconds(60)
            // 自訂健康檢查
            .waitingFor(Wait.forHealthcheck().withStartupTimeout(Duration.ofMinutes(2)));
    }
    
    public static GenericContainer<?> createHealthyRedis() {
        return new GenericContainer<>("redis:7.2-alpine")
            .withExposedPorts(6379)
            .waitingFor(Wait.forListeningPort())
            .waitingFor(Wait.forLogMessage(".*Ready to accept connections.*", 1))
            .withStartupTimeout(Duration.ofMinutes(1));
    }
}
```

## 故障排除指南

### 1. 常見問題與解決方案

```java
// 1. 容器啟動超時
@Container
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.4")
    .withStartupTimeout(Duration.ofMinutes(5)) // 增加啟動超時
    .withConnectTimeoutSeconds(120); // 增加連接超時

// 2. 資源不足
@Container
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.4-alpine") // 使用精簡版映像
    .withSharedMemorySize(256 * 1024 * 1024L) // 設定共享記憶體
    .withTmpFs(Map.of("/var/lib/postgresql/data", "rw")); // 使用臨時檔案系統

// 3. 埠衝突
@Container
static GenericContainer<?> redis = new GenericContainer<>("redis:7.2-alpine")
    .withExposedPorts(6379)
    .withCreateContainerCmdModifier(cmd -> 
        cmd.getHostConfig().withPortBindings(new PortBinding(Ports.Binding.empty(), ExposedPort.tcp(6379))));

// 4. 網路隔離問題
@Testcontainers
class NetworkIsolationTest {
    
    @Container
    static Network network = Network.newNetwork();
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.4")
        .withNetwork(network)
        .withNetworkAliases("postgres");
        
    @Container
    static GenericContainer<?> app = new GenericContainer<>("fake-store-api:test")
        .withNetwork(network)
        .withEnv("DB_HOST", "postgres");
}
```

### 2. 日誌收集和分析

```java
package com.fakestore.test.logging;

@TestMethodOrder(OrderAnnotation.class)
class LoggingIntegrationTest extends BaseIntegrationTest {
    
    @Test
    @Order(1)
    void collectContainerLogs() {
        // 收集容器日誌
        String postgresLogs = postgres.getLogs();
        String redisLogs = redis.getLogs();
        
        // 保存日誌到檔案
        saveLogsToFile("postgres", postgresLogs);
        saveLogsToFile("redis", redisLogs);
        
        // 分析日誌中的錯誤
        if (postgresLogs.contains("ERROR") || postgresLogs.contains("FATAL")) {
            fail("PostgreSQL 容器出現錯誤: " + extractErrors(postgresLogs));
        }
    }
    
    private void saveLogsToFile(String containerName, String logs) {
        try {
            Path logDir = Paths.get("target", "testcontainers-logs");
            Files.createDirectories(logDir);
            
            Path logFile = logDir.resolve(containerName + "-" + System.currentTimeMillis() + ".log");
            Files.write(logFile, logs.getBytes(StandardCharsets.UTF_8));
        } catch (IOException e) {
            System.err.println("無法保存日誌: " + e.getMessage());
        }
    }
}
```

### 3. 測試環境清理

```bash
#!/bin/bash
# scripts/cleanup-test-environment.sh

echo "清理 TestContainers 測試環境..."

# 停止所有測試容器
docker stop $(docker ps -q --filter "label=org.testcontainers=true") 2>/dev/null || true

# 移除測試容器
docker rm $(docker ps -aq --filter "label=org.testcontainers=true") 2>/dev/null || true

# 清理未使用的映像檔
docker image prune -f

# 清理測試網路
docker network prune -f

# 清理測試卷
docker volume prune -f

echo "測試環境清理完成！"
```

## 最佳實踐總結

### ✅ 推薦做法

1. **容器重用**: 使用 `.withReuse(true)` 提升測試執行速度
2. **映像檔優化**: 選擇 Alpine 版本減少映像檔大小
3. **並行測試**: 合理配置並行度，避免資源競爭
4. **資料隔離**: 使用命名空間隔離測試資料
5. **健康檢查**: 配置適當的健康檢查確保容器就緒
6. **監控診斷**: 收集測試指標和日誌便於問題排查

### ❌ 避免做法

1. **過度並行**: 避免超過系統資源限制的並行測試
2. **資料污染**: 避免測試間的資料相互影響
3. **超時設定**: 避免過短的容器啟動超時設定
4. **資源洩漏**: 確保測試後正確清理容器資源
5. **硬編碼配置**: 避免在測試中硬編碼容器配置

---

*最後更新：2025-08-24*