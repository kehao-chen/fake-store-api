# TestContainers 基礎配置與支付模組整合測試

TestContainers 技術選型的完整基礎配置和支付模組整合測試實作。

## 專案依賴配置

### Maven 依賴 (pom.xml)

```xml
<properties>
    <testcontainers.version>1.19.1</testcontainers.version>
    <wiremock.version>2.35.0</wiremock.version>
</properties>

<dependencies>
    <!-- TestContainers 核心 -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <version>${testcontainers.version}</version>
        <scope>test</scope>
    </dependency>
    
    <!-- PostgreSQL TestContainer -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>postgresql</artifactId>
        <version>${testcontainers.version}</version>
        <scope>test</scope>
    </dependency>
    
    <!-- Redis TestContainer -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>redis</artifactId>
        <version>${testcontainers.version}</version>
        <scope>test</scope>
    </dependency>
    
    <!-- WireMock 用於外部服務 Mock -->
    <dependency>
        <groupId>com.github.tomakehurst</groupId>
        <artifactId>wiremock-jre8</artifactId>
        <version>${wiremock.version}</version>
        <scope>test</scope>
    </dependency>
</dependencies>
```

### Gradle 依賴 (build.gradle)

```gradle
testImplementation 'org.testcontainers:junit-jupiter:1.19.1'
testImplementation 'org.testcontainers:postgresql:1.19.1'
testImplementation 'org.testcontainers:redis:1.19.1'
testImplementation 'com.github.tomakehurst:wiremock-jre8:2.35.0'
```

## 基礎配置類別

### 1. 核心基礎測試類別

```java
package com.fakestore.test;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
public abstract class BaseIntegrationTest {
    
    // PostgreSQL 容器 - 靜態共享提升效能
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.4")
            .withDatabaseName("fake_store_test")
            .withUsername("test_user")
            .withPassword("test_pass")
            .withInitScript("db/test-schema.sql")
            .withReuse(true); // 容器重用以提升測試效能
    
    // Redis 容器 - 用於快取測試
    @Container 
    static GenericContainer<?> redis = new GenericContainer<>("redis:7.2-alpine")
            .withExposedPorts(6379)
            .withCommand("redis-server", "--requirepass", "test_redis_pass")
            .withReuse(true);
    
    // WireMock 容器 - 用於外部服務 Mock
    @Container
    static GenericContainer<?> wiremock = new GenericContainer<>("wiremock/wiremock:2.35.0")
            .withExposedPorts(8080)
            .withFileSystemBind("src/test/resources/wiremock", "/home/wiremock", 
                BindMode.READ_ONLY)
            .withReuse(true);
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // 資料庫配置
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
        
        // JPA 配置
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "create-drop");
        registry.add("spring.jpa.show-sql", () -> "true");
        registry.add("spring.jpa.properties.hibernate.dialect", 
            () -> "org.hibernate.dialect.PostgreSQLDialect");
        
        // Redis 配置
        registry.add("spring.redis.host", redis::getHost);
        registry.add("spring.redis.port", redis::getFirstMappedPort);
        registry.add("spring.redis.password", () -> "test_redis_pass");
        registry.add("spring.cache.type", () -> "redis");
        
        // 外部服務 URL 配置
        registry.add("stripe.api.base-url", 
            () -> "http://localhost:" + wiremock.getFirstMappedPort());
        registry.add("stripe.webhook.endpoint-secret", () -> "whsec_test_secret");
        
        // 測試專用配置
        registry.add("logging.level.com.fakestore", () -> "DEBUG");
        registry.add("logging.level.org.springframework.web", () -> "DEBUG");
    }
}
```

### 2. 測試資料初始化腳本

```sql
-- src/test/resources/db/test-schema.sql

-- 清理既有資料
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;  
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS payments CASCADE;

-- 建立測試用資料表
CREATE TABLE categories (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id VARCHAR(50) REFERENCES categories(id),
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    id VARCHAR(50) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    is_email_verified BOOLEAN DEFAULT false,
    roles TEXT[] DEFAULT ARRAY['ROLE_USER'],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE carts (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) REFERENCES users(id),
    total_amount DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cart_items (
    id VARCHAR(50) PRIMARY KEY,
    cart_id VARCHAR(50) REFERENCES carts(id) ON DELETE CASCADE,
    product_id VARCHAR(50) REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) REFERENCES users(id),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'TWD',
    payment_intent_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50) REFERENCES orders(id),
    stripe_payment_intent_id VARCHAR(100),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'TWD',
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 建立索引
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_carts_user ON carts(user_id);
CREATE INDEX idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_payments_order ON payments(order_id);

-- 插入測試基礎資料
INSERT INTO categories (id, name, description) VALUES
('cat_electronics', '電子產品', '各類電子設備'),
('cat_clothing', '服飾', '男女服裝配件'),
('cat_books', '書籍', '各類書籍刊物');
```

## 支付模組 TestContainers 整合測試

### 1. 支付測試基礎類別

```java
package com.fakestore.payment;

import com.fakestore.test.BaseIntegrationTest;
import com.fakestore.security.JwtService;
import com.github.tomakehurst.wiremock.WireMockServer;
import com.github.tomakehurst.wiremock.client.WireMock;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Set;

import static com.github.tomakehurst.wiremock.client.WireMock.*;

@TestPropertySource(locations = "classpath:application-test.properties")
@Transactional
public abstract class PaymentIntegrationTestBase extends BaseIntegrationTest {
    
    @Autowired
    protected TestRestTemplate restTemplate;
    
    @Autowired
    protected JwtService jwtService;
    
    @Autowired
    protected OrderRepository orderRepository;
    
    @Autowired
    protected PaymentRepository paymentRepository;
    
    @Autowired
    protected CartRepository cartRepository;
    
    @Autowired
    protected ProductRepository productRepository;
    
    @Autowired
    protected UserRepository userRepository;
    
    // 測試常數
    protected final String TEST_USER_ID = "user_payment_test";
    protected final String TEST_ORDER_ID = "order_test_123";
    protected final String STRIPE_PAYMENT_INTENT_ID = "pi_test_123456";
    protected final String STRIPE_CLIENT_SECRET = "pi_test_123456_secret_test";
    
    protected HttpHeaders createAuthHeaders() {
        String token = jwtService.generateAccessToken(
            TEST_USER_ID, 
            "payment-test@example.com", 
            Set.of("ROLE_USER")
        );
        
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }
    
    protected void setupStripePaymentIntentMock() {
        // Mock Stripe PaymentIntent 建立
        stubFor(post(urlEqualTo("/v1/payment_intents"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody(createPaymentIntentResponse())));
        
        // Mock Stripe PaymentIntent 確認
        stubFor(post(urlMatching("/v1/payment_intents/.*/confirm"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody(createConfirmedPaymentIntentResponse())));
    }
    
    protected void setupStripeCheckoutSessionMock() {
        // Mock Stripe Checkout Session 建立
        stubFor(post(urlEqualTo("/v1/checkout/sessions"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody(createCheckoutSessionResponse())));
    }
    
    private String createPaymentIntentResponse() {
        return """
            {
                "id": "%s",
                "object": "payment_intent",
                "amount": 19998,
                "currency": "twd",
                "status": "requires_payment_method",
                "client_secret": "%s"
            }
            """.formatted(STRIPE_PAYMENT_INTENT_ID, STRIPE_CLIENT_SECRET);
    }
    
    private String createConfirmedPaymentIntentResponse() {
        return """
            {
                "id": "%s",
                "object": "payment_intent", 
                "amount": 19998,
                "currency": "twd",
                "status": "succeeded"
            }
            """.formatted(STRIPE_PAYMENT_INTENT_ID);
    }
    
    private String createCheckoutSessionResponse() {
        return """
            {
                "id": "cs_test_123456",
                "object": "checkout.session",
                "url": "https://checkout.stripe.com/c/pay/cs_test_123456",
                "payment_intent": "%s",
                "payment_status": "unpaid"
            }
            """.formatted(STRIPE_PAYMENT_INTENT_ID);
    }
    
    protected User createTestUser() {
        User user = User.builder()
            .id(TEST_USER_ID)
            .email("payment-test@example.com")
            .username("paymenttest")
            .firstName("Payment")
            .lastName("Tester")
            .roles(Set.of("ROLE_USER"))
            .isActive(true)
            .build();
        return userRepository.save(user);
    }
    
    protected Cart createTestCartWithItems() {
        // 建立測試產品
        Product product = Product.builder()
            .id("prod_payment_test")
            .name("測試商品")
            .price(new BigDecimal("199.98"))
            .stockQuantity(10)
            .categoryId("cat_electronics")
            .isActive(true)
            .build();
        productRepository.save(product);
        
        // 建立購物車
        Cart cart = Cart.builder()
            .id("cart_payment_test")
            .userId(TEST_USER_ID)
            .totalAmount(new BigDecimal("199.98"))
            .build();
        
        CartItem item = CartItem.builder()
            .id("item_payment_test")
            .productId(product.getId())
            .quantity(1)
            .unitPrice(product.getPrice())
            .build();
            
        cart.addItem(item);
        return cartRepository.save(cart);
    }
}
```

### 2. 支付流程整合測試

```java
package com.fakestore.payment;

import org.junit.jupiter.api.*;
import org.springframework.http.*;
import static org.assertj.core.api.Assertions.*;
import static com.github.tomakehurst.wiremock.client.WireMock.*;

import java.math.BigDecimal;
import java.util.concurrent.TimeUnit;

@DisplayName("支付模組整合測試")
class PaymentIntegrationTest extends PaymentIntegrationTestBase {
    
    @BeforeEach
    void setUp() {
        // 清理測試資料
        paymentRepository.deleteAll();
        orderRepository.deleteAll();
        cartRepository.deleteAll();
        productRepository.deleteAll();
        userRepository.deleteAll();
        
        // 重置 WireMock
        reset();
        
        // 建立測試資料
        createTestUser();
        createTestCartWithItems();
    }
    
    @Test
    @DisplayName("應該成功建立 PaymentIntent 支付")
    void shouldCreatePaymentIntentSuccessfully() {
        // Given
        setupStripePaymentIntentMock();
        
        CreatePaymentRequest request = CreatePaymentRequest.builder()
            .paymentMethod("payment_intent")
            .successUrl("https://example.com/success")
            .cancelUrl("https://example.com/cancel")
            .build();
        
        HttpEntity<CreatePaymentRequest> entity = 
            new HttpEntity<>(request, createAuthHeaders());
        
        // When
        ResponseEntity<PaymentResponse> response = restTemplate.exchange(
            "/v1/users/me/cart:checkout",
            HttpMethod.POST,
            entity,
            PaymentResponse.class
        );
        
        // Then - API 回應驗證
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        PaymentResponse payment = response.getBody();
        
        assertThat(payment.getPaymentIntent()).isNotNull();
        assertThat(payment.getPaymentIntent().getClientSecret()).isEqualTo(STRIPE_CLIENT_SECRET);
        assertThat(payment.getPaymentIntent().getAmount()).isEqualTo(19998); // 199.98 * 100
        assertThat(payment.getPaymentIntent().getCurrency()).isEqualTo("twd");
        
        // Then - 資料庫狀態驗證
        Order savedOrder = orderRepository.findByUserId(TEST_USER_ID)
            .stream().findFirst().orElseThrow();
        assertThat(savedOrder.getStatus()).isEqualTo(OrderStatus.PENDING);
        assertThat(savedOrder.getTotalAmount()).isEqualByComparingTo(new BigDecimal("199.98"));
        assertThat(savedOrder.getPaymentIntentId()).isEqualTo(STRIPE_PAYMENT_INTENT_ID);
        
        Payment savedPayment = paymentRepository.findByOrderId(savedOrder.getId())
            .orElseThrow();
        assertThat(savedPayment.getStripePaymentIntentId()).isEqualTo(STRIPE_PAYMENT_INTENT_ID);
        assertThat(savedPayment.getStatus()).isEqualTo(PaymentStatus.PENDING);
        
        // Then - 驗證 Stripe API 呼叫
        verify(postRequestedFor(urlEqualTo("/v1/payment_intents"))
            .withRequestBody(containing("amount=19998"))
            .withRequestBody(containing("currency=twd")));
    }
    
    @Test
    @DisplayName("應該成功建立 Checkout Session")
    void shouldCreateCheckoutSessionSuccessfully() {
        // Given
        setupStripeCheckoutSessionMock();
        
        CreatePaymentRequest request = CreatePaymentRequest.builder()
            .paymentMethod("checkout")
            .successUrl("https://example.com/success")
            .cancelUrl("https://example.com/cancel")
            .build();
        
        // When
        ResponseEntity<PaymentResponse> response = restTemplate.exchange(
            "/v1/users/me/cart:checkout",
            HttpMethod.POST,
            new HttpEntity<>(request, createAuthHeaders()),
            PaymentResponse.class
        );
        
        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        PaymentResponse payment = response.getBody();
        
        assertThat(payment.getCheckoutSession()).isNotNull();
        assertThat(payment.getCheckoutSession().getUrl())
            .isEqualTo("https://checkout.stripe.com/c/pay/cs_test_123456");
        
        // 驗證 Stripe API 呼叫
        verify(postRequestedFor(urlEqualTo("/v1/checkout/sessions"))
            .withRequestBody(containing("success_url=https://example.com/success"))
            .withRequestBody(containing("cancel_url=https://example.com/cancel")));
    }
    
    @Test
    @DisplayName("空購物車時應該拋出異常")
    void shouldThrowExceptionWhenCartIsEmpty() {
        // Given - 清空購物車
        cartRepository.deleteAll();
        
        CreatePaymentRequest request = CreatePaymentRequest.builder()
            .paymentMethod("payment_intent")
            .successUrl("https://example.com/success")
            .cancelUrl("https://example.com/cancel")
            .build();
        
        // When & Then
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/users/me/cart:checkout",
            HttpMethod.POST,
            new HttpEntity<>(request, createAuthHeaders()),
            ErrorResponse.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getCode()).isEqualTo("EMPTY_CART");
        assertThat(response.getBody().getMessage()).contains("購物車為空");
        
        // 驗證沒有建立訂單
        assertThat(orderRepository.findByUserId(TEST_USER_ID)).isEmpty();
    }
    
    @Test
    @DisplayName("應該正確處理 Stripe webhook 事件")
    void shouldHandleStripeWebhookCorrectly() throws InterruptedException {
        // Given - 先建立待支付的訂單
        setupStripePaymentIntentMock();
        CreatePaymentRequest request = CreatePaymentRequest.builder()
            .paymentMethod("payment_intent")
            .successUrl("https://example.com/success")
            .cancelUrl("https://example.com/cancel")
            .build();
        
        restTemplate.exchange("/v1/users/me/cart:checkout", HttpMethod.POST, 
            new HttpEntity<>(request, createAuthHeaders()), PaymentResponse.class);
        
        Order pendingOrder = orderRepository.findByUserId(TEST_USER_ID)
            .stream().findFirst().orElseThrow();
        
        // When - 模擬 Stripe webhook 事件
        String webhookPayload = createSuccessfulPaymentWebhookPayload();
        
        HttpHeaders webhookHeaders = new HttpHeaders();
        webhookHeaders.setContentType(MediaType.APPLICATION_JSON);
        webhookHeaders.add("Stripe-Signature", "test-signature");
        
        ResponseEntity<Void> webhookResponse = restTemplate.exchange(
            "/v1/webhooks/stripe",
            HttpMethod.POST,
            new HttpEntity<>(webhookPayload, webhookHeaders),
            Void.class
        );
        
        // Then - 驗證 webhook 處理
        assertThat(webhookResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        
        // 等待異步處理完成
        TimeUnit.MILLISECONDS.sleep(500);
        
        // 驗證訂單狀態更新
        Order updatedOrder = orderRepository.findById(pendingOrder.getId()).orElseThrow();
        assertThat(updatedOrder.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        
        // 驗證支付狀態更新
        Payment updatedPayment = paymentRepository.findByOrderId(pendingOrder.getId())
            .orElseThrow();
        assertThat(updatedPayment.getStatus()).isEqualTo(PaymentStatus.COMPLETED);
        
        // 驗證庫存扣減
        Product product = productRepository.findById("prod_payment_test").orElseThrow();
        assertThat(product.getStockQuantity()).isEqualTo(9); // 原10 - 1 = 9
        
        // 驗證購物車清空
        assertThat(cartRepository.findByUserId(TEST_USER_ID)).isEmpty();
    }
    
    @Test
    @DisplayName("Stripe API 失敗時應該正確處理")
    void shouldHandleStripeApiFailure() {
        // Given - Mock Stripe API 失敗
        stubFor(post(urlEqualTo("/v1/payment_intents"))
            .willReturn(aResponse()
                .withStatus(400)
                .withHeader("Content-Type", "application/json")
                .withBody(createStripeErrorResponse())));
        
        CreatePaymentRequest request = CreatePaymentRequest.builder()
            .paymentMethod("payment_intent")
            .successUrl("https://example.com/success")
            .cancelUrl("https://example.com/cancel")
            .build();
        
        // When
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/users/me/cart:checkout",
            HttpMethod.POST,
            new HttpEntity<>(request, createAuthHeaders()),
            ErrorResponse.class
        );
        
        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getCode()).isEqualTo("PAYMENT_CREATION_FAILED");
        
        // 驗證沒有建立訂單和支付記錄
        assertThat(orderRepository.findByUserId(TEST_USER_ID)).isEmpty();
        assertThat(paymentRepository.findAll()).isEmpty();
    }
    
    @Test
    @DisplayName("應該正確處理並發支付請求")
    void shouldHandleConcurrentPaymentRequests() throws InterruptedException {
        // Given
        setupStripePaymentIntentMock();
        
        int threadCount = 3;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);
        List<CompletableFuture<ResponseEntity<PaymentResponse>>> futures = new ArrayList<>();
        
        // When - 並發發起支付
        for (int i = 0; i < threadCount; i++) {
            CompletableFuture<ResponseEntity<PaymentResponse>> future = 
                CompletableFuture.supplyAsync(() -> {
                    try {
                        CreatePaymentRequest request = CreatePaymentRequest.builder()
                            .paymentMethod("payment_intent")
                            .successUrl("https://example.com/success")
                            .cancelUrl("https://example.com/cancel")
                            .build();
                        
                        return restTemplate.exchange(
                            "/v1/users/me/cart:checkout",
                            HttpMethod.POST,
                            new HttpEntity<>(request, createAuthHeaders()),
                            PaymentResponse.class
                        );
                    } finally {
                        latch.countDown();
                    }
                }, executor);
            
            futures.add(future);
        }
        
        latch.await(10, TimeUnit.SECONDS);
        
        // Then - 驗證只有一個成功，其他失敗
        List<ResponseEntity<PaymentResponse>> responses = futures.stream()
            .map(CompletableFuture::join)
            .collect(Collectors.toList());
        
        long successCount = responses.stream()
            .mapToLong(r -> r.getStatusCode() == HttpStatus.OK ? 1 : 0)
            .sum();
        
        assertThat(successCount).isEqualTo(1); // 只有一個成功
        
        // 驗證只建立了一個訂單
        List<Order> orders = orderRepository.findByUserId(TEST_USER_ID);
        assertThat(orders).hasSize(1);
        
        executor.shutdown();
    }
    
    private String createSuccessfulPaymentWebhookPayload() {
        return """
            {
                "id": "evt_test_webhook",
                "object": "event",
                "type": "payment_intent.succeeded",
                "data": {
                    "object": {
                        "id": "%s",
                        "object": "payment_intent",
                        "amount": 19998,
                        "currency": "twd",
                        "status": "succeeded"
                    }
                }
            }
            """.formatted(STRIPE_PAYMENT_INTENT_ID);
    }
    
    private String createStripeErrorResponse() {
        return """
            {
                "error": {
                    "type": "card_error",
                    "code": "card_declined",
                    "message": "Your card was declined."
                }
            }
            """;
    }
}
```

### 3. 支付狀態追蹤測試

```java
@Test
@DisplayName("應該正確追蹤支付狀態變化")
void shouldTrackPaymentStatusChanges() {
    // Given - 建立訂單
    setupStripePaymentIntentMock();
    
    CreatePaymentRequest request = CreatePaymentRequest.builder()
        .paymentMethod("payment_intent")
        .successUrl("https://example.com/success")
        .cancelUrl("https://example.com/cancel")
        .build();
    
    ResponseEntity<PaymentResponse> paymentResponse = restTemplate.exchange(
        "/v1/users/me/cart:checkout",
        HttpMethod.POST,
        new HttpEntity<>(request, createAuthHeaders()),
        PaymentResponse.class
    );
    
    String orderId = orderRepository.findByUserId(TEST_USER_ID)
        .stream().findFirst().orElseThrow().getId();
    
    // When - 查詢支付狀態
    ResponseEntity<PaymentStatusResponse> statusResponse = restTemplate.exchange(
        "/v1/orders/" + orderId + "/payment-status",
        HttpMethod.GET,
        new HttpEntity<>(null, createAuthHeaders()),
        PaymentStatusResponse.class
    );
    
    // Then
    assertThat(statusResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
    PaymentStatusResponse status = statusResponse.getBody();
    
    assertThat(status.getOrderId()).isEqualTo(orderId);
    assertThat(status.getPaymentStatus()).isEqualTo("PENDING");
    assertThat(status.getPaymentIntentId()).isEqualTo(STRIPE_PAYMENT_INTENT_ID);
    assertThat(status.getAmount()).isEqualByComparingTo(new BigDecimal("199.98"));
}
```

## WireMock 配置檔案

### Stripe API Mock 設定

```json
// src/test/resources/wiremock/mappings/stripe-payment-intents.json
{
  "request": {
    "method": "POST",
    "url": "/v1/payment_intents"
  },
  "response": {
    "status": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "bodyFileName": "stripe-payment-intent-response.json"
  }
}
```

```json
// src/test/resources/wiremock/__files/stripe-payment-intent-response.json
{
  "id": "pi_test_123456",
  "object": "payment_intent",
  "amount": 19998,
  "currency": "twd", 
  "status": "requires_payment_method",
  "client_secret": "pi_test_123456_secret_test",
  "metadata": {
    "order_id": "{{request.body 'metadata[order_id]'}}",
    "user_id": "{{request.body 'metadata[user_id]'}}"
  }
}
```

## CI/CD 配置

### GitHub Actions 設定

```yaml
# .github/workflows/testcontainers.yml
name: TestContainers Integration Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    
    services:
      docker:
        options: --privileged
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      
      - name: Cache Maven dependencies
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2
      
      - name: Run TestContainers tests
        run: ./mvnw test -Dtest="**/*IntegrationTest"
        env:
          TESTCONTAINERS_RYUK_DISABLED: true
      
      - name: Upload test reports
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-reports
          path: target/surefire-reports/
```

## 效能最佳化

### 容器重用設定

```java
// TestContainers 重用設定
@Container
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.4")
    .withReuse(true)  // 啟用容器重用
    .withLabel("testcontainers.reuse", "true");

// 測試類別間共享容器
@Testcontainers
class SharedContainerTest {
    
    static {
        postgres.start(); // 手動啟動以共享
    }
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        // 配置共享容器屬性
    }
}
```

### 測試執行順序最佳化

```java
@TestMethodOrder(OrderAnnotation.class)
class OptimizedPaymentTest extends PaymentIntegrationTestBase {
    
    @Test
    @Order(1)
    @DisplayName("基礎支付功能測試")
    void basicPaymentTest() {
        // 最常用的測試先執行
    }
    
    @Test 
    @Order(2)
    @DisplayName("異常情況測試") 
    void errorHandlingTest() {
        // 異常測試後執行
    }
}
```

---

*最後更新：2025-08-24*