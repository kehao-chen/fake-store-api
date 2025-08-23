# 測試策略

[← 返回文件中心](../README.md) | [實作指南](../implementation/) | **測試策略**

本文件說明 Fake Store API 的測試策略設計，採用 ArchUnit 架構測試導向方法，確保程式碼品質與架構合規性。

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-23
- **目標讀者**: 開發者、架構師、測試工程師
- **相關文件**: 
  - [DDD 領域模型](../architecture/ddd-model.md)
  - [C4 架構模型](../architecture/c4-model.md)
  - [架構改進建議](../../ARCHITECTURE_IMPROVEMENTS.md)

## 測試策略概覽

本專案採用架構測試導向的測試策略，以 ArchUnit 作為核心工具，確保程式碼符合設計的架構原則。

### 測試金字塔

```
        /\     E2E Tests (5%)
       /  \    TestContainers + Playwright
      /____\   
     /      \  Integration Tests (15%)
    /        \ Spring Boot Test
   /          \
  /__________\ Unit Tests + Architecture Tests (80%)
               JUnit 5 + Mockito + ArchUnit
```

### 測試覆蓋率目標

| 測試類型 | 覆蓋率目標 | 重點關注 |
|----------|------------|----------|
| 架構測試 | 100% 規則覆蓋 | 架構原則、模組邊界、命名慣例 |
| 單元測試 | ≥ 80% | 業務邏輯、邊界條件、異常處理 |
| 整合測試 | ≥ 70% | API 端點、資料庫互動、快取 |
| E2E 測試 | ≥ 60% | 核心業務流程、使用者旅程 |

## 1. 架構測試 (ArchUnit)

### 1.1 架構測試目標

ArchUnit 是本專案測試策略的核心特色，主要用途包括：

- **強制模組邊界**: 防止領域間的不當依賴
- **驗證架構原則**: 確保符合 DDD 和 Clean Architecture
- **代碼品質控制**: 自動化檢查命名、註解、設計模式
- **文件化架構**: 測試即文件，可執行的架構規範

### 1.2 核心架構規則

#### 領域邊界測試
確保各領域間的依賴符合 DDD 原則：

```java
@Test
@DisplayName("產品領域不應依賴購物車領域")
void productDomainShouldNotDependOnCartDomain() {
    noClasses()
        .that().resideInAPackage("..product..")
        .should().dependOnClassesThat()
        .resideInAPackage("..cart..")
        .check(importedClasses);
}
```

#### 分層架構測試
確保遵循 Clean Architecture 原則：

```java
@Test
static final ArchRule layered_architecture_is_respected =
    layeredArchitecture()
        .consideringAllDependencies()
        .layer("Controllers").definedBy("..controller..")
        .layer("Services").definedBy("..service..")
        .layer("Repositories").definedBy("..repository..")
        .layer("Saga").definedBy("..saga..")
        .whereLayer("Controllers").mayNotBeAccessedByAnyLayer()
        .whereLayer("Services").mayOnlyBeAccessedByLayers("Controllers", "Saga")
        .whereLayer("Repositories").mayOnlyBeAccessedByLayers("Services", "Saga")
        .whereLayer("Saga").mayNotBeAccessedByAnyLayer();
```

#### 命名慣例測試
確保類別命名符合專案規範：

```java
@Test
@DisplayName("Controller 類應以 Controller 結尾")
static final ArchRule controllers_should_be_suffixed =
    classes()
        .that().areAnnotatedWith(RestController.class)
        .should().haveSimpleNameEndingWith("Controller");

@Test
@DisplayName("Saga 編排器應以 Orchestrator 結尾")
static final ArchRule saga_orchestrators_should_be_suffixed =
    classes()
        .that().resideInAPackage("..saga..")
        .and().haveNameMatching(".*Orchestrator.*")
        .should().haveSimpleNameEndingWith("Orchestrator");

@Test
@DisplayName("Controller 不得依賴 Repository；僅 Service 可發布事件")
void safetyBoundaries() {
    noClasses().that().resideInAPackage("..controller..")
        .should().dependOnClassesThat().resideInAPackage("..repository..")
        .check(importedClasses);

    classes().that().resideOutsideOfPackages("..service..")
        .should().notCallMethodWhere(
            target -> target.getOwner().getName().equals("com.fakestore.common.events.EventPublisher")
        ).check(importedClasses);
}
```

### 1.3 測試組織結構

```
src/test/java/
├── architecture/
│   ├── ArchitectureTest.java          # 分層架構測試
│   ├── DomainBoundaryTest.java        # 領域邊界測試
│   ├── NamingConventionTest.java      # 命名慣例測試
│   ├── SecurityArchitectureTest.java  # 安全架構測試
│   └── DddArchitectureTest.java       # DDD 原則測試
```

## 2. 單元測試

### 2.1 測試框架
- **JUnit 5**: 測試執行框架
- **Mockito**: Mock 框架
- **AssertJ**: 斷言庫

### 2.2 測試結構範例

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("產品服務測試")
class ProductServiceTest {
    
    @Mock
    private ProductRepository productRepository;
    
    @InjectMocks
    private ProductServiceImpl productService;
    
    @Test
    @DisplayName("應能根據 ID 查詢產品")
    void shouldFindProductById() {
        // Given
        String productId = "prod_123";
        Product expectedProduct = createTestProduct(productId);
        given(productRepository.findById(productId))
            .willReturn(Optional.of(expectedProduct));
        
        // When
        Product actualProduct = productService.findById(productId);
        
        // Then
        assertThat(actualProduct).isEqualTo(expectedProduct);
    }
}
```

### 2.3 Saga 編排器測試

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("訂單 Saga 編排器測試")
class OrderSagaOrchestratorTest {
    
    @Mock private OrderService orderService;
    @Mock private InventoryService inventoryService;
    @Mock private PaymentService paymentService;
    @Mock private SagaStateRepository sagaStateRepository;
    
    @InjectMocks
    private OrderSagaOrchestrator orchestrator;
    
    @Test
    @DisplayName("應能成功完成訂單 Saga 流程")
    void shouldCompleteOrderSagaSuccessfully() {
        // Given
        OrderCreationRequest request = createOrderRequest();
        when(orderService.createOrder(any())).thenReturn(CompletableFuture.completedFuture("order-123"));
        when(inventoryService.reserveInventory(any(), any())).thenReturn(CompletableFuture.completedFuture("res-456"));
        when(paymentService.processPayment(any(), any())).thenReturn(CompletableFuture.completedFuture(paymentResult()));
        
        // When
        CompletableFuture<SagaResult> result = orchestrator.processOrder(request);
        
        // Then
        assertThat(result.join().isSuccess()).isTrue();
        verify(orderService).createOrder(any());
        verify(inventoryService).reserveInventory(eq("order-123"), any());
        verify(paymentService).processPayment(eq("order-123"), any());
    }
    
    @Test
    @DisplayName("支付失敗時應執行補償操作")
    void shouldCompensateOnPaymentFailure() {
        // Given
        when(orderService.createOrder(any())).thenReturn(CompletableFuture.completedFuture("order-123"));
        when(inventoryService.reserveInventory(any(), any())).thenReturn(CompletableFuture.completedFuture("res-456"));
        when(paymentService.processPayment(any(), any()))
            .thenReturn(CompletableFuture.failedFuture(new PaymentException("Payment failed")));
        
        // When
        CompletableFuture<SagaResult> result = orchestrator.processOrder(createOrderRequest());
        
        // Then
        assertThat(result.join().isFailed()).isTrue();
        verify(inventoryService).releaseInventory("res-456");
        verify(orderService).cancelOrder("order-123");
    }
}
```

## 3. 整合測試

### 3.1 測試環境
- **Spring Boot Test**: Spring 整合測試支援
- **TestContainers**: 真實資料庫環境

### 3.2 資料庫整合測試

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class ProductIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");
    
    @Test
    void shouldCreateProduct() {
        // 整合測試實作
    }
}
```

### 3.3 Saga 整合測試

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderSagaIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
            .withDatabaseName("saga_test")
            .withUsername("test")
            .withPassword("test");
    
    @Autowired
    private OrderSagaOrchestrator orchestrator;
    
    @Autowired
    private TestRestTemplate restTemplate;
    
    @Test
    @DisplayName("應處理完整訂單流程")
    void shouldHandleCompleteOrderFlow() {
        // Given: 設置測試資料
        setupTestData();
        
        // When: 執行完整 Saga 流程
        OrderCreationRequest request = createValidOrderRequest();
        SagaResult result = orchestrator.processOrder(request).join();
        
        // Then: 驗證結果與狀態
        assertThat(result.isSuccess()).isTrue();
        
        // 驗證訂單狀態
        String orderId = result.getOrderId();
        assertThat(getOrderStatus(orderId)).isEqualTo(OrderStatus.CONFIRMED);
        
        // 驗證庫存扣減
        assertThat(getProductStock("product-1")).isEqualTo(8); // 原10-2=8
        
        // 驗證支付記錄
        assertThat(getPaymentStatus(orderId)).isEqualTo(PaymentStatus.COMPLETED);
    }
    
    @Test
    @DisplayName("庫存不足時應回滾訂單")
    void shouldRollbackOnInventoryShortage() {
        // Given: 庫存不足的情況
        setProductStock("product-1", 1);
        
        // When
        OrderCreationRequest request = createOrderRequestForQuantity(5);
        SagaResult result = orchestrator.processOrder(request).join();
        
        // Then
        assertThat(result.isFailed()).isTrue();
        assertThat(result.getFailureReason()).contains("庫存不足");
        
        // 驗證沒有訂單被建立
        assertThat(countOrdersForUser("user-123")).isEqualTo(0);
    }
}
```

### 3.4 測試資料初始化（repeatable）
- TestContainers 啟動 PostgreSQL 後，以 Flyway/Liquibase 或 `schema.sql` 初始化資料。
- 建議使用 `src/test/resources/db/init/` 放置固定測試資料，確保每次測試一致。

### 3.5 測試機密管理
- JWT 簽名、Stripe 測試金鑰等敏感設定放入 `.env.test`，於 CI 以 secrets 注入。
- 禁止在測試程式碼硬編碼金鑰或提交到版本庫。

## 4. E2E 測試

### 4.1 測試範圍
完整的使用者流程測試，包含：
- 使用者註冊與登入
- 產品瀏覽與搜尋
- 購物車操作
- 訂單建立與支付
- Saga 編排器端到端流程驗證

### 4.2 測試架構

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestMethodOrder(OrderAnnotation.class)
class ShoppingFlowE2ETest {
    
    @Test
    @Order(1)
    @DisplayName("完整購物流程")
    void completeShoppingFlow() {
        // 1. 使用者認證
        String authToken = authenticateUser();
        
        // 2. 加入購物車
        addProductToCart(authToken, "prod_123", 2);
        
        // 3. 發起支付
        PaymentResponse response = initiatePayment(authToken);
        assertThat(response.getCheckoutUrl()).isNotBlank();
    }
}
```

### 4.3 PaymentIntent 路徑（補充）

```java
@Test
@Order(2)
@DisplayName("PaymentIntent：取得 client_secret 並由前端確認")
void paymentIntentFlow() {
    String authToken = authenticateUser();
    PaymentResponse response = initiatePaymentIntent(authToken);
    assertThat(response.getPaymentIntent().getClientSecret()).isNotBlank();
    // 整合測試可模擬 webhook 事件觸發對賬
}
```

### 4.4 API Key 認證測試（Bearer）

```java
@Test
@DisplayName("以 API Key 呼叫受保護端點")
void callProtectedWithApiKey() {
    String jwt = authenticateUser();
    String apiKey = createApiKey(jwt);
    var resp = httpGet("/v1/products", bearer(apiKey));
    assertThat(resp.getStatus()).isEqualTo(200);
}
```

### 4.5 完整 Saga 流程 E2E 測試

```java
@Test
@Order(3)
@DisplayName("完整訂單 Saga 流程端到端測試")
void completeSagaFlowE2E() {
    // Given: 準備完整的測試環境
    String authToken = authenticateUser();
    String productId = createTestProduct();
    addProductStock(productId, 10);
    
    // When: 執行完整的訂單建立流程
    // 1. 加入購物車
    addProductToCart(authToken, productId, 2);
    
    // 2. 建立訂單（觸發 Saga）
    CreateOrderRequest orderRequest = CreateOrderRequest.builder()
        .userId(getUserId(authToken))
        .build();
    
    var orderResponse = httpPost("/v1/orders", orderRequest, bearer(authToken));
    assertThat(orderResponse.getStatus()).isEqualTo(201);
    
    String orderId = orderResponse.getBody().getString("id");
    
    // 3. 等待 Saga 完成（異步處理）
    await().atMost(Duration.ofSeconds(10))
           .pollInterval(Duration.ofMillis(500))
           .until(() -> getOrderStatus(orderId).equals("CONFIRMED"));
    
    // Then: 驗證完整的狀態變化
    // 驗證訂單狀態
    var orderDetails = httpGet("/v1/orders/" + orderId, bearer(authToken));
    assertThat(orderDetails.getBody().getString("status")).isEqualTo("CONFIRMED");
    
    // 驗證庫存扣減
    var productDetails = httpGet("/v1/products/" + productId);
    assertThat(productDetails.getBody().getInt("stockQuantity")).isEqualTo(8);
    
    // 驗證支付記錄
    var paymentHistory = httpGet("/v1/orders/" + orderId + "/payments", bearer(authToken));
    assertThat(paymentHistory.getBody().getJSONArray("payments")).isNotEmpty();
}

@Test
@Order(4)
@DisplayName("Saga 補償流程端到端測試")
void sagaCompensationFlowE2E() {
    // Given: 模擬支付失敗情況
    String authToken = authenticateUser();
    String productId = createTestProduct();
    addProductStock(productId, 10);
    addProductToCart(authToken, productId, 2);
    
    // 設置支付服務返回失敗
    mockPaymentServiceToFail();
    
    // When: 建立訂單（預期 Saga 失敗並補償）
    CreateOrderRequest orderRequest = CreateOrderRequest.builder()
        .userId(getUserId(authToken))
        .build();
    
    var orderResponse = httpPost("/v1/orders", orderRequest, bearer(authToken));
    
    // Then: 應該返回失敗狀態
    assertThat(orderResponse.getStatus()).isEqualTo(400);
    
    // 驗證補償操作已執行
    // 1. 庫存應該被釋放（沒有扣減）
    var productDetails = httpGet("/v1/products/" + productId);
    assertThat(productDetails.getBody().getInt("stockQuantity")).isEqualTo(10);
    
    // 2. 不應該有已確認的訂單
    var userOrders = httpGet("/v1/users/me/orders", bearer(authToken));
    var confirmedOrders = userOrders.getBody().getJSONArray("orders")
        .toList().stream()
        .filter(order -> ((Map) order).get("status").equals("CONFIRMED"))
        .count();
    assertThat(confirmedOrders).isEqualTo(0);
}
```

## 5. CI/CD 整合

### 5.1 GitHub Actions 配置

```yaml
name: 測試套件

on: [push, pull_request]

jobs:
  architecture-tests:
    name: 架構測試
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '21'
      - name: 運行架構測試
        run: ./gradlew test --tests "*Architecture*"

  unit-and-integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '21'
      - name: Run tests with coverage
        run: ./gradlew test jacocoTestReport
      - name: Upload test report
        uses: actions/upload-artifact@v3
        with:
          name: jacoco-report
          path: build/reports/jacoco/test/html
```

### 5.2 測試報告

使用 JaCoCo 生成測試覆蓋率報告：

```gradle
jacoco {
    toolVersion = "0.8.8"
}

jacocoTestReport {
    reports {
        xml.required = true
        html.required = true
    }
}
```

## 6. 測試數據管理

### 6.1 測試數據建構器

使用 Builder 模式建立測試資料：

```java
public class ProductTestDataBuilder {
    private String id = "prod_default";
    private String name = "預設產品";
    private BigDecimal price = BigDecimal.valueOf(10.00);
    
    public static ProductTestDataBuilder aProduct() {
        return new ProductTestDataBuilder();
    }
    
    public ProductTestDataBuilder withId(String id) {
        this.id = id;
        return this;
    }
    
    public Product build() {
        return Product.builder()
            .id(id)
            .name(name)
            .price(price)
            .build();
    }
}
```

## 7. Flaky 測試與重試策略
- 對外部依賴（Stripe sandbox）採合理 timeout 與 backoff；避免固定等待（sleep）。
- 模擬外部事件：整合測試可直接呼叫 webhook handler 並傳入測試事件 payload，以提升穩定度。
- 對網路暫時性錯誤允許有限次重試，避免掩蓋真實問題。

## 8. Webhook 事件模擬
- 建立 `WebhookTestHelper` 產生 `payment_intent.succeeded` / `checkout.session.completed` 測試 payload。
- 直接 POST 至 `/v1/webhooks/stripe`（或內部呼叫 handler），驗證對賬與訂單狀態更新流程。

### 6.2 測試環境配置

```yaml
# application-test.yml
spring:
  datasource:
    url: jdbc:tc:postgresql:15:///testdb
  cache:
    type: simple

logging:
  level:
    com.fakestore: DEBUG
```

## 7. 測試最佳實踐

### 7.1 架構測試最佳實踐
1. **規則命名清晰**: 測試方法名描述具體的架構規則
2. **適度使用**: 避免過度約束，保持開發靈活性
3. **持續演進**: 隨架構演進調整測試規則
4. **文件化**: 每個架構規則都應有清楚的說明

### 7.2 測試組織原則
1. **單一職責**: 每個測試只驗證一個具體行為
2. **獨立性**: 測試間不應有依賴關係
3. **可重複**: 測試結果應一致且可重現
4. **快速執行**: 優化測試執行時間

## 相關文件

- [DDD 領域模型](../architecture/ddd-model.md) - 領域邊界定義
- [C4 架構模型](../architecture/c4-model.md) - 系統架構層次
- [架構改進建議](../../ARCHITECTURE_IMPROVEMENTS.md) - ArchUnit 技術決策
- [Saga 編排模式實作](saga-orchestration.md) - Saga 模式設計與實作
- [非功能需求](../requirements/non-functional.md) - 測試品質要求
- [ArchUnit 實作範例](../examples/archunit-implementation.md) - 具體實作指南

---

最後更新：2025-08-23
