# 購物車模組 TestContainers 整合測試實作

完整的購物車模組整合測試實作範例，展示 TestContainers 在複雜業務場景中的應用。

## 測試架構

### 基礎配置類別

```java
package com.fakestore.cart;

import com.fakestore.test.BaseIntegrationTest;
import com.fakestore.security.JwtService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestPropertySource(locations = "classpath:application-test.properties")
@Transactional
public abstract class CartIntegrationTestBase extends BaseIntegrationTest {
    
    @Autowired
    protected TestRestTemplate restTemplate;
    
    @Autowired
    protected JwtService jwtService;
    
    @Autowired
    protected CartRepository cartRepository;
    
    @Autowired
    protected ProductRepository productRepository;
    
    @Autowired
    protected UserRepository userRepository;
    
    // 測試用戶 ID
    protected final String TEST_USER_ID = "user_test_123";
    protected final String TEST_PRODUCT_ID = "prod_test_456";
    
    // 建立測試認證標頭
    protected HttpHeaders createAuthHeaders() {
        String token = jwtService.generateAccessToken(
            TEST_USER_ID, 
            "test@example.com", 
            Set.of("ROLE_USER")
        );
        
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }
    
    // 建立測試產品
    protected Product createTestProduct(String id, BigDecimal price, int stock) {
        Product product = Product.builder()
            .id(id)
            .name("測試產品 " + id)
            .description("測試用產品描述")
            .price(price)
            .categoryId("cat_electronics")
            .stockQuantity(stock)
            .isActive(true)
            .build();
        return productRepository.save(product);
    }
    
    // 建立測試用戶
    protected User createTestUser() {
        User user = User.builder()
            .id(TEST_USER_ID)
            .email("test@example.com")
            .username("testuser")
            .firstName("Test")
            .lastName("User")
            .roles(Set.of("ROLE_USER"))
            .isActive(true)
            .build();
        return userRepository.save(user);
    }
}
```

## 核心測試案例

### 1. 購物車基本操作測試

```java
package com.fakestore.cart;

import org.junit.jupiter.api.*;
import org.springframework.http.*;
import static org.assertj.core.api.Assertions.*;
import java.math.BigDecimal;

@DisplayName("購物車整合測試")
class CartIntegrationTest extends CartIntegrationTestBase {
    
    @BeforeEach
    void setUp() {
        // 清理測試資料
        cartRepository.deleteAll();
        productRepository.deleteAll();
        userRepository.deleteAll();
        
        // 建立測試資料
        createTestUser();
        createTestProduct(TEST_PRODUCT_ID, new BigDecimal("99.99"), 10);
    }
    
    @Test
    @DisplayName("應該成功添加商品到空購物車")
    void shouldAddItemToEmptyCart() {
        // Given
        AddItemRequest request = AddItemRequest.builder()
            .productId(TEST_PRODUCT_ID)
            .quantity(2)
            .build();
            
        HttpEntity<AddItemRequest> entity = new HttpEntity<>(request, createAuthHeaders());
        
        // When
        ResponseEntity<CartResponse> response = restTemplate.exchange(
            "/v1/users/me/cart/items",
            HttpMethod.POST,
            entity,
            CartResponse.class
        );
        
        // Then - API 回應驗證
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        CartResponse cart = response.getBody();
        assertThat(cart.getId()).isNotNull();
        assertThat(cart.getUserId()).isEqualTo(TEST_USER_ID);
        assertThat(cart.getTotalItems()).isEqualTo(1);
        assertThat(cart.getItems()).hasSize(1);
        
        CartItemResponse item = cart.getItems().get(0);
        assertThat(item.getProductId()).isEqualTo(TEST_PRODUCT_ID);
        assertThat(item.getQuantity()).isEqualTo(2);
        assertThat(item.getUnitPrice()).isEqualByComparingTo(new BigDecimal("99.99"));
        assertThat(item.getSubtotal()).isEqualByComparingTo(new BigDecimal("199.98"));
        
        assertThat(cart.getTotalAmount()).isEqualByComparingTo(new BigDecimal("199.98"));
        
        // Then - 資料庫狀態驗證
        Cart savedCart = cartRepository.findByUserId(TEST_USER_ID).orElseThrow();
        assertThat(savedCart.getItems()).hasSize(1);
        assertThat(savedCart.getTotalAmount()).isEqualByComparingTo(new BigDecimal("199.98"));
        
        // Then - 庫存扣減驗證
        Product updatedProduct = productRepository.findById(TEST_PRODUCT_ID).orElseThrow();
        assertThat(updatedProduct.getStockQuantity()).isEqualTo(8); // 10 - 2 = 8
    }
    
    @Test
    @DisplayName("應該累加相同商品的數量")
    void shouldAccumulateQuantityForSameProduct() {
        // Given - 先添加一次
        AddItemRequest firstAdd = AddItemRequest.builder()
            .productId(TEST_PRODUCT_ID)
            .quantity(2)
            .build();
        restTemplate.exchange("/v1/users/me/cart/items", HttpMethod.POST, 
            new HttpEntity<>(firstAdd, createAuthHeaders()), CartResponse.class);
        
        // When - 再次添加相同商品
        AddItemRequest secondAdd = AddItemRequest.builder()
            .productId(TEST_PRODUCT_ID)
            .quantity(3)
            .build();
            
        ResponseEntity<CartResponse> response = restTemplate.exchange(
            "/v1/users/me/cart/items",
            HttpMethod.POST,
            new HttpEntity<>(secondAdd, createAuthHeaders()),
            CartResponse.class
        );
        
        // Then
        CartResponse cart = response.getBody();
        assertThat(cart.getTotalItems()).isEqualTo(1); // 還是1個商品類型
        assertThat(cart.getItems().get(0).getQuantity()).isEqualTo(5); // 2 + 3 = 5
        assertThat(cart.getTotalAmount()).isEqualByComparingTo(new BigDecimal("499.95")); // 5 * 99.99
        
        // 驗證庫存
        Product product = productRepository.findById(TEST_PRODUCT_ID).orElseThrow();
        assertThat(product.getStockQuantity()).isEqualTo(5); // 10 - 5 = 5
    }
    
    @Test
    @DisplayName("當庫存不足時應該拋出異常")
    void shouldThrowExceptionWhenInsufficientStock() {
        // Given - 庫存只有1個
        Product limitedProduct = createTestProduct("prod_limited", new BigDecimal("50.00"), 1);
        
        AddItemRequest request = AddItemRequest.builder()
            .productId(limitedProduct.getId())
            .quantity(5) // 嘗試添加5個
            .build();
            
        // When & Then
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/users/me/cart/items",
            HttpMethod.POST,
            new HttpEntity<>(request, createAuthHeaders()),
            ErrorResponse.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody().getMessage()).contains("庫存不足");
        assertThat(response.getBody().getCode()).isEqualTo("INSUFFICIENT_STOCK");
        
        // 驗證購物車沒有被修改
        assertThat(cartRepository.findByUserId(TEST_USER_ID)).isEmpty();
        
        // 驗證庫存沒有被扣減
        Product unchangedProduct = productRepository.findById(limitedProduct.getId()).orElseThrow();
        assertThat(unchangedProduct.getStockQuantity()).isEqualTo(1);
    }
    
    @Test
    @DisplayName("應該正確更新商品數量")
    void shouldUpdateItemQuantity() {
        // Given - 先添加商品
        AddItemRequest addRequest = AddItemRequest.builder()
            .productId(TEST_PRODUCT_ID)
            .quantity(3)
            .build();
        restTemplate.exchange("/v1/users/me/cart/items", HttpMethod.POST, 
            new HttpEntity<>(addRequest, createAuthHeaders()), CartResponse.class);
        
        // When - 更新數量
        UpdateItemRequest updateRequest = UpdateItemRequest.builder()
            .quantity(5)
            .build();
            
        ResponseEntity<CartResponse> response = restTemplate.exchange(
            "/v1/users/me/cart/items/" + TEST_PRODUCT_ID,
            HttpMethod.PUT,
            new HttpEntity<>(updateRequest, createAuthHeaders()),
            CartResponse.class
        );
        
        // Then
        CartResponse cart = response.getBody();
        assertThat(cart.getItems().get(0).getQuantity()).isEqualTo(5);
        assertThat(cart.getTotalAmount()).isEqualByComparingTo(new BigDecimal("499.95"));
        
        // 驗證庫存調整（原本扣3個，現在扣5個）
        Product product = productRepository.findById(TEST_PRODUCT_ID).orElseThrow();
        assertThat(product.getStockQuantity()).isEqualTo(5); // 10 - 5 = 5
    }
    
    @Test
    @DisplayName("數量設為0時應該移除商品")
    void shouldRemoveItemWhenQuantityIsZero() {
        // Given
        AddItemRequest addRequest = AddItemRequest.builder()
            .productId(TEST_PRODUCT_ID)
            .quantity(2)
            .build();
        restTemplate.exchange("/v1/users/me/cart/items", HttpMethod.POST, 
            new HttpEntity<>(addRequest, createAuthHeaders()), CartResponse.class);
        
        // When - 將數量設為0
        UpdateItemRequest updateRequest = UpdateItemRequest.builder()
            .quantity(0)
            .build();
            
        ResponseEntity<CartResponse> response = restTemplate.exchange(
            "/v1/users/me/cart/items/" + TEST_PRODUCT_ID,
            HttpMethod.PUT,
            new HttpEntity<>(updateRequest, createAuthHeaders()),
            CartResponse.class
        );
        
        // Then
        CartResponse cart = response.getBody();
        assertThat(cart.getItems()).isEmpty();
        assertThat(cart.getTotalItems()).isEqualTo(0);
        assertThat(cart.getTotalAmount()).isEqualByComparingTo(BigDecimal.ZERO);
        
        // 驗證庫存恢復
        Product product = productRepository.findById(TEST_PRODUCT_ID).orElseThrow();
        assertThat(product.getStockQuantity()).isEqualTo(10); // 庫存恢復
    }
    
    @Test
    @DisplayName("應該成功移除指定商品")
    void shouldRemoveSpecificItem() {
        // Given - 添加兩個不同商品
        createTestProduct("prod_second", new BigDecimal("29.99"), 5);
        
        AddItemRequest firstItem = AddItemRequest.builder()
            .productId(TEST_PRODUCT_ID)
            .quantity(2)
            .build();
        restTemplate.exchange("/v1/users/me/cart/items", HttpMethod.POST, 
            new HttpEntity<>(firstItem, createAuthHeaders()), CartResponse.class);
            
        AddItemRequest secondItem = AddItemRequest.builder()
            .productId("prod_second")
            .quantity(1)
            .build();
        restTemplate.exchange("/v1/users/me/cart/items", HttpMethod.POST, 
            new HttpEntity<>(secondItem, createAuthHeaders()), CartResponse.class);
        
        // When - 移除第一個商品
        ResponseEntity<Void> response = restTemplate.exchange(
            "/v1/users/me/cart/items/" + TEST_PRODUCT_ID,
            HttpMethod.DELETE,
            new HttpEntity<>(null, createAuthHeaders()),
            Void.class
        );
        
        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        
        // 驗證購物車狀態
        ResponseEntity<CartResponse> cartResponse = restTemplate.exchange(
            "/v1/users/me/cart",
            HttpMethod.GET,
            new HttpEntity<>(null, createAuthHeaders()),
            CartResponse.class
        );
        
        CartResponse cart = cartResponse.getBody();
        assertThat(cart.getItems()).hasSize(1);
        assertThat(cart.getItems().get(0).getProductId()).isEqualTo("prod_second");
        assertThat(cart.getTotalAmount()).isEqualByComparingTo(new BigDecimal("29.99"));
        
        // 驗證第一個商品庫存恢復
        Product firstProduct = productRepository.findById(TEST_PRODUCT_ID).orElseThrow();
        assertThat(firstProduct.getStockQuantity()).isEqualTo(10);
    }
}
```

### 2. 購物車並發操作測試

```java
@Test
@DisplayName("應該正確處理並發添加操作")
void shouldHandleConcurrentAddOperations() throws InterruptedException {
    // Given
    int threadCount = 5;
    int quantityPerThread = 2;
    ExecutorService executor = Executors.newFixedThreadPool(threadCount);
    CountDownLatch latch = new CountDownLatch(threadCount);
    List<CompletableFuture<ResponseEntity<CartResponse>>> futures = new ArrayList<>();
    
    // When - 並發添加商品
    for (int i = 0; i < threadCount; i++) {
        CompletableFuture<ResponseEntity<CartResponse>> future = CompletableFuture.supplyAsync(() -> {
            try {
                AddItemRequest request = AddItemRequest.builder()
                    .productId(TEST_PRODUCT_ID)
                    .quantity(quantityPerThread)
                    .build();
                    
                return restTemplate.exchange(
                    "/v1/users/me/cart/items",
                    HttpMethod.POST,
                    new HttpEntity<>(request, createAuthHeaders()),
                    CartResponse.class
                );
            } finally {
                latch.countDown();
            }
        }, executor);
        
        futures.add(future);
    }
    
    // 等待所有請求完成
    latch.await(10, TimeUnit.SECONDS);
    
    // Then - 驗證結果
    List<ResponseEntity<CartResponse>> responses = futures.stream()
        .map(CompletableFuture::join)
        .collect(Collectors.toList());
        
    // 至少一個請求成功
    long successCount = responses.stream()
        .mapToLong(r -> r.getStatusCode() == HttpStatus.OK ? 1 : 0)
        .sum();
    assertThat(successCount).isGreaterThan(0);
    
    // 驗證最終狀態一致性
    ResponseEntity<CartResponse> finalCart = restTemplate.exchange(
        "/v1/users/me/cart",
        HttpMethod.GET,
        new HttpEntity<>(null, createAuthHeaders()),
        CartResponse.class
    );
    
    CartResponse cart = finalCart.getBody();
    assertThat(cart.getItems().get(0).getQuantity()).isEqualTo(threadCount * quantityPerThread);
    
    // 驗證庫存正確扣減
    Product product = productRepository.findById(TEST_PRODUCT_ID).orElseThrow();
    assertThat(product.getStockQuantity()).isEqualTo(10 - (threadCount * quantityPerThread));
    
    executor.shutdown();
}
```

### 3. Redis 快取整合測試

```java
@Autowired
private RedisTemplate<String, Object> redisTemplate;

@Test
@DisplayName("應該正確快取購物車資料")
void shouldCacheCartData() {
    // Given
    AddItemRequest request = AddItemRequest.builder()
        .productId(TEST_PRODUCT_ID)
        .quantity(2)
        .build();
    restTemplate.exchange("/v1/users/me/cart/items", HttpMethod.POST, 
        new HttpEntity<>(request, createAuthHeaders()), CartResponse.class);
    
    // When - 取得購物車（應觸發快取）
    ResponseEntity<CartResponse> response = restTemplate.exchange(
        "/v1/users/me/cart",
        HttpMethod.GET,
        new HttpEntity<>(null, createAuthHeaders()),
        CartResponse.class
    );
    
    // Then - 驗證 Redis 快取
    String cacheKey = "cart:" + TEST_USER_ID;
    Object cachedCart = redisTemplate.opsForValue().get(cacheKey);
    assertThat(cachedCart).isNotNull();
    
    // 清空資料庫但保留快取
    cartRepository.deleteAll();
    
    // 再次請求應該從快取返回
    ResponseEntity<CartResponse> cachedResponse = restTemplate.exchange(
        "/v1/users/me/cart",
        HttpMethod.GET,
        new HttpEntity<>(null, createAuthHeaders()),
        CartResponse.class
    );
    
    assertThat(cachedResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(cachedResponse.getBody().getTotalItems()).isEqualTo(1);
}
```

## 測試資料建構器

```java
public class CartTestDataBuilder {
    
    public static class AddItemRequestBuilder {
        private String productId = "prod_default";
        private Integer quantity = 1;
        
        public static AddItemRequestBuilder anAddItemRequest() {
            return new AddItemRequestBuilder();
        }
        
        public AddItemRequestBuilder withProduct(String productId) {
            this.productId = productId;
            return this;
        }
        
        public AddItemRequestBuilder withQuantity(int quantity) {
            this.quantity = quantity;
            return this;
        }
        
        public AddItemRequest build() {
            return AddItemRequest.builder()
                .productId(productId)
                .quantity(quantity)
                .build();
        }
    }
}
```

## 測試配置檔案

```properties
# application-test.properties

# 資料庫配置（由 TestContainers 動態配置）
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true

# Redis 配置（由 TestContainers 動態配置）
spring.cache.type=redis
spring.cache.redis.time-to-live=300000

# 日誌配置
logging.level.com.fakestore=DEBUG
logging.level.org.springframework.web=DEBUG
logging.level.org.hibernate.SQL=DEBUG

# JWT 測試配置
jwt.access-token-expiration=60
jwt.refresh-token-expiration=1440

# 外部服務配置（由 WireMock 提供）
stripe.api.timeout=5000
```

## 執行指標

### 測試覆蓋率目標
- **API 端點覆蓋**: 100% (所有購物車相關端點)
- **業務邏輯覆蓋**: ≥90% (加入、更新、移除、計算)
- **異常處理覆蓋**: ≥85% (庫存不足、商品不存在等)
- **並發安全覆蓋**: 關鍵路徑並發測試

### 效能指標
- **單一測試執行時間**: <5秒
- **完整測試套件**: <2分鐘
- **資料庫事務回滾**: <100ms

---

*最後更新：2025-08-24*