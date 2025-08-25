# 測試策略

[← 返回文件中心](../README.md) | [實作指南](../implementation/) | **測試策略**

本文件說明 Fake Store API 的測試策略設計，採用四維測試架構（架構測試、契約測試、單元測試、BDD），確保程式碼品質、架構合規性、契約一致性和業務需求滿足。

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-23
- **目標讀者**: 開發者、架構師、測試工程師
- **相關文件**: 
  - [DDD 領域模型](../architecture/ddd-model.md)
  - [C4 架構模型](../architecture/c4-model.md)
  - [架構改進建議](../../ARCHITECTURE_IMPROVEMENTS.md)

## 測試策略概覽

本專案採用**多層次測試策略**，結合架構測試、契約測試、單元測試和 BDD，確保系統的架構合規性、服務契約一致性、業務邏輯正確性和使用者需求滿足。

### 四維測試架構

**架構測試 (ArchUnit)**: 確保程式碼符合設計的架構原則和邊界約束
**契約測試 (TestContainers)**: 驗證服務間、API 層、資料層的契約一致性  
**單元測試 (JUnit)**: 驗證業務邏輯、邊界條件和異常處理
**BDD 測試**: 從使用者角度驗證業務需求和使用者旅程

### 整合測試金字塔

```
        /\     BDD E2E Tests (10%)
       /  \    Gherkin + Cucumber/SpecFlow  
      /____\   User Journey Validation
     /      \  Contract Tests (30%)
    /        \ TestContainers + Real Services
   /          \ Service/API/Data Contract Testing  
  /__________\ Unit Tests + Architecture Tests (60%)
               JUnit 5 + Mockito + ArchUnit
```

### 測試覆蓋率目標

| 測試類型 | 覆蓋率目標 | 重點關注 |
|----------|------------|----------|
| 架構測試 | 100% 規則覆蓋 | 架構原則、模組邊界、命名慣例 |
| 契約測試 | 100% 核心契約覆蓋 | API 契約、服務間契約、資料契約 |
| 單元測試 | ≥ 80% | 業務邏輯、邊界條件、異常處理 |
| BDD 測試 | 100% 核心使用者旅程 | 業務需求、使用者體驗、端到端流程 |

### 測試策略技術決策

#### 為什麼增加契約測試？
- **API 契約一致性**：確保 OpenAPI 規格與實際實現的一致性
- **服務間依賴驗證**：購物車-商品、支付-外部 API、認證-JWT 格式的契約穩定性
- **資料層契約穩定**：資料庫 Schema 變更與應用程式的相容性

#### 為什麼選擇 TestContainers？
- **真實環境模擬**：使用真實的 PostgreSQL、Redis、WireMock 容器，避免 Mock 無法捕捉的契約問題
- **環境一致性**：開發、測試、生產環境的高度一致性，解決「在我機器上可以跑」問題
- **Consumer-Driven Contract**：由消費者定義契約，確保服務演進不破壞現有依賴

#### 為什麼保留架構測試？
- **架構邊界強制**：ArchUnit 確保領域邊界和分層架構的嚴格遵守
- **設計原則驗證**：自動化檢查 DDD、Clean Architecture 等設計原則
- **程式碼品質閘門**：命名慣例、註解使用、設計模式的自動化驗證

### 契約測試實現文件

本專案已建立完整的 TestContainers 契約測試實現，詳見：

- [TestContainers 購物車契約測試](../examples/testcontainers-cart-integration.md)
- [TestContainers 支付契約測試](../examples/testcontainers-payment-integration.md)  
- [TestContainers 認證契約測試](../examples/testcontainers-auth-integration.md)
- [TestContainers CI/CD 配置](../examples/testcontainers-cicd-config.md)

## 1. 契約測試架構 (TestContainers)

### 1.1 契約測試層次

#### API Layer Contract Testing
- **HTTP 契約驗證**：status code、headers、response schema 一致性
- **OpenAPI 規格對齊**：確保 API 文件與實作的同步
- **版本相容性**：API 演進的向後相容性驗證

#### Service Layer Contract Testing  
- **服務間資料交換**：購物車服務與商品服務的資料契約
- **業務邏輯契約**：輸入輸出格式的穩定性
- **異步事件契約**：事件驅動架構的訊息格式契約

#### Data Layer Contract Testing
- **資料存取契約**：Repository 介面的穩定性
- **Schema 演進契約**：資料庫變更的影響範圍控制
- **快取契約**：Redis 資料結構與業務邏輯的一致性

### 1.2 Consumer-Driven Contract 實作策略

#### 契約定義流程
1. **Consumer 定義期望**：由服務消費者定義所需的 API 契約
2. **Provider 實現契約**：服務提供者根據契約實現功能
3. **雙向驗證**：Consumer 和 Provider 都需通過契約測試
4. **契約演進管理**：變更時的影響分析與相容性檢查

#### TestContainers 契約驗證優勢
- **真實環境契約**：使用真實資料庫容器驗證資料層契約
- **端到端契約鏈**：從 HTTP 到資料庫的完整契約驗證
- **外部服務契約**：WireMock 容器模擬外部 API 的契約測試

### 1.3 契約測試組織結構

```
src/test/java/
├── contract/
│   ├── api/
│   │   ├── ProductApiContractTest.java     # API 契約測試
│   │   ├── CartApiContractTest.java        # 購物車 API 契約
│   │   └── PaymentApiContractTest.java     # 支付 API 契約
│   ├── service/
│   │   ├── CartProductContractTest.java    # 服務間契約測試
│   │   ├── PaymentStripeContractTest.java  # 外部服務契約
│   │   └── AuthJwtContractTest.java        # 認證契約測試
│   └── data/
│       ├── ProductDataContractTest.java    # 資料契約測試
│       ├── CartCacheContractTest.java      # 快取契約測試
│       └── PaymentDataContractTest.java    # 支付資料契約
├── architecture/
│   ├── ArchitectureTest.java               # 分層架構測試
│   ├── DomainBoundaryTest.java             # 領域邊界測試
│   └── NamingConventionTest.java           # 命名慣例測試
```

## 2. 架構測試 (ArchUnit)

### 2.1 架構測試目標

ArchUnit 在四維測試架構中負責架構合規性驗證，是將 [PRD.md](../../PRD.md) 中定義的技術目標（如模組邊界、設計原則）落實到程式碼層級的關鍵工具。其主要用途包括：

- **強制模組邊界**: 防止領域間的不當依賴。
- **驗證架構原則**: 確保符合 DDD 和 Clean Architecture。
- **程式碼品質控制**: 自動化檢查命名、註解、設計模式。
- **文件化架構**: 測試即文件，是可執行的架構規範，相關討論見 [架構改進建議](../../ARCHITECTURE_IMPROVEMENTS.md)。

### 2.2 核心架構規則

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
@DisplayName("Controller 不得依賴 Repository；僅 Service 可發佈事件")
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

### 2.3 測試組織結構

```
src/test/java/
├── architecture/
│   ├── ArchitectureTest.java          # 分層架構測試
│   ├── DomainBoundaryTest.java        # 領域邊界測試
│   ├── NamingConventionTest.java      # 命名慣例測試
│   ├── SecurityArchitectureTest.java  # 安全架構測試
│   └── DddArchitectureTest.java       # DDD 原則測試
```

## 3. 單元測試

### 3.1 測試框架
- **JUnit 5**: 測試執行框架
- **Mockito**: Mock 框架
- **AssertJ**: 斷言庫

### 3.2 測試結構範例

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

### 3.3 Saga 編排器測試

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

## 4. 整合測試

### 4.1 測試環境
- **Spring Boot Test**: Spring 整合測試支援
- **TestContainers**: 真實資料庫環境

### 4.2 資料庫整合測試

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

### 4.3 Saga 整合測試

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

### 4.4 測試資料初始化（repeatable）
- TestContainers 啟動 PostgreSQL 後，以 Flyway/Liquibase 或 `schema.sql` 初始化資料。
- 建議使用 `src/test/resources/db/init/` 放置固定測試資料，確保每次測試一致。

### 4.5 測試機密管理
- JWT 簽名、Stripe 測試金鑰等敏感設定放入 `.env.test`，於 CI 以 secrets 注入。
- 禁止在測試程式碼硬編碼金鑰或提交到版本庫。

## 5. BDD 測試 (行為驅動開發)

### 5.1 BDD 測試目標

BDD 測試從使用者角度驗證業務需求，確保系統行為符合業務預期：

- **業務需求驗證**：使用 Gherkin 語法描述業務場景
- **使用者旅程測試**：端到端的使用者體驗驗證
- **跨功能協作**：讓 BA、開發者、測試人員共同理解需求

### 5.2 BDD 測試範例

#### 使用者註冊和購物流程
```gherkin
Feature: 使用者購物流程
  作為一個新使用者
  我想要能夠註冊帳戶、瀏覽產品、加入購物車並完成購買
  以便獲得完整的購物體驗

  Scenario: 成功完成購物流程
    Given 我是一個新使用者
    When 我註冊一個新帳戶使用 email "user@example.com"
    And 我瀏覽產品目錄
    And 我將產品 "iPhone 14" 加入購物車
    And 我前往結帳頁面
    And 我使用信用卡完成付款
    Then 我應該看到訂單確認頁面
    And 我應該收到訂單確認 email
    And 產品庫存應該相應減少

  Scenario: 庫存不足時的處理
    Given 產品 "限量商品" 只剩下 1 個庫存
    And 我已經登入系統
    When 我嘗試將 3 個 "限量商品" 加入購物車  
    Then 我應該看到庫存不足的錯誤訊息
    And 購物車中應該只有 1 個 "限量商品"
```

### 5.3 BDD 測試組織結構

```
src/test/resources/features/
├── user-management/
│   ├── user-registration.feature      # 使用者註冊流程
│   ├── user-authentication.feature    # 使用者認證流程
│   └── user-profile.feature           # 使用者資料管理
├── shopping/
│   ├── product-browsing.feature       # 產品瀏覽和搜尋
│   ├── cart-management.feature        # 購物車操作
│   └── checkout-process.feature       # 結帳流程
└── payment/
    ├── payment-processing.feature     # 支付處理
    └── payment-reconciliation.feature # 支付對賬
```

## 6. E2E 測試

### 6.1 測試範圍
完整的使用者流程測試，包含：
- 使用者註冊與登入
- 產品瀏覽與搜尋
- 購物車操作
- 訂單建立與支付
- Saga 編排器端到端流程驗證

### 6.2 測試架構

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

### 6.3 PaymentIntent 路徑（補充）

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

### 6.4 API Key 認證測試（Bearer）

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

### 6.5 完整 Saga 流程 E2E 測試

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
    
    // 3. 等待 Saga 完成（非同步處理）
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

## 7. CI/CD 整合

### 7.1 多層次測試的 CI/CD 整合策略

本專案的四維測試策略整合到 CI/CD 管道中，實現分層測試執行：

#### 測試執行順序
1. **架構測試 (30s)**: 最快速的合規性檢查，確保程式碼符合架構原則
2. **單元測試 (2-5min)**: 核心業務邏輯驗證，快速回饋開發者
3. **契約測試 (5-10min)**: TestContainers 啟動真實環境進行契約驗證
4. **BDD 測試 (10-20min)**: 完整的業務場景和使用者旅程驗證

#### 契約測試整合重點

#### 契約測試執行時機
- **Pre-commit Hook**: 開發者提交前的本地契約驗證
- **Feature Branch**: 分支合併前的契約相容性檢查  
- **Release Pipeline**: 發佈前的完整契約回歸測試
- **Production Monitoring**: 生產環境的契約監控與告警

#### 契約變更影響分析自動化
- **Dependency Graph**: 自動建立服務依賴關係圖
- **Impact Analysis**: 計算契約變更對下游服務的影響範圍
- **Test Suite Generation**: 根據影響範圍自動生成測試案例
- **Parallel Validation**: TestContainers 並行執行契約驗證

#### 效能最佳化策略
- **Container Reuse**: 相同配置的容器重用減少啟動成本
- **Resource Pooling**: 容器資源池化管理
- **Test Layering**: 分層執行契約測試（Smoke → Integration → Full Regression）

### 7.2 GitHub Actions 配置

針對四維測試策略的優化配置：

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

### 7.3 測試報告

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

## 8. 測試資料管理

### 8.1 測試資料建構器

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

## 8. Flaky 測試與重試策略
- 對外部依賴（Stripe sandbox）採合理 timeout 與 backoff；避免固定等待（sleep）。
- 模擬外部事件：整合測試可直接呼叫 webhook handler 並傳入測試事件 payload，以提升穩定度。
- 對網路暫時性錯誤允許有限次重試，避免掩蓋真實問題。

## 9. Webhook 事件模擬
- 建立 `WebhookTestHelper` 產生 `payment_intent.succeeded` / `checkout.session.completed` 測試 payload。
- 直接 POST 至 `/v1/webhooks/stripe`（或內部呼叫 handler），驗證對賬與訂單狀態更新流程。

### 9.1 測試環境配置

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

## 10. 測試最佳實踐

### 10.1 四維測試協調原則

#### 架構測試最佳實踐
1. **規則命名清晰**: 測試方法名描述具體的架構規則
2. **適度使用**: 避免過度約束，保持開發靈活性
3. **持續演進**: 隨架構演進調整測試規則
4. **文件化**: 每個架構規則都應有清楚的說明

#### 契約測試最佳實踐
1. **Consumer-First**: 由消費者定義契約需求
2. **版本管理**: 建立契約版本演進策略
3. **影響分析**: 自動化契約變更影響分析
4. **真實環境**: 使用 TestContainers 確保環境一致性

#### BDD 測試最佳實踐
1. **業務語言**: 使用業務人員能理解的 Gherkin 語法
2. **場景覆蓋**: 涵蓋主要使用者旅程和邊界情況
3. **可維護性**: 保持 Feature 檔案的簡潔和可讀性
4. **跨功能協作**: 讓 BA、開發、測試共同維護場景

### 10.2 測試組織原則
1. **單一職責**: 每個測試只驗證一個具體行為
2. **獨立性**: 測試間不應有依賴關係
3. **可重複**: 測試結果應一致且可重現
4. **快速執行**: 最佳化測試執行時間

## 相關文件

- [DDD 領域模型](../architecture/ddd-model.md) - 領域邊界定義
- [C4 架構模型](../architecture/c4-model.md) - 系統架構層次
- [架構改進建議](../../ARCHITECTURE_IMPROVEMENTS.md) - 四維測試架構決策
- [Saga 編排模式實作](saga-orchestration.md) - Saga 模式設計與實作
- [非功能需求](../requirements/non-functional.md) - 測試品質要求
- [ArchUnit 實作範例](../examples/archunit-implementation.md) - 具體實作指南

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-25*
