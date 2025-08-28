# 認證模組 TestContainers 整合測試 & 測試資料管理策略

完整的認證模組 TestContainers 整合測試實作，以及專案級的測試資料管理策略。

## 認證模組整合測試

### 1. 認證測試基礎類別

```java
package com.fakestore.auth;

import com.fakestore.test.BaseIntegrationTest;
import com.fakestore.security.JwtService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Set;

@TestPropertySource(locations = "classpath:application-test.properties")
@Transactional
public abstract class AuthIntegrationTestBase extends BaseIntegrationTest {
    
    @Autowired
    protected TestRestTemplate restTemplate;
    
    @Autowired
    protected JwtService jwtService;
    
    @Autowired
    protected UserRepository userRepository;
    
    @Autowired
    protected PasswordEncoder passwordEncoder;
    
    @Autowired
    protected RedisTemplate<String, Object> redisTemplate;
    
    // 測試常數
    protected final String TEST_USER_EMAIL = "auth-test@example.com";
    protected final String TEST_USER_PASSWORD = "TestPassword123!";
    protected final String TEST_USER_ID = "user_auth_test";
    
    protected HttpHeaders createJsonHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }
    
    protected HttpHeaders createAuthHeaders(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }
    
    protected User createTestUser() {
        User user = User.builder()
            .id(TEST_USER_ID)
            .email(TEST_USER_EMAIL)
            .username("authtest")
            .passwordHash(passwordEncoder.encode(TEST_USER_PASSWORD))
            .firstName("Auth")
            .lastName("Tester")
            .roles(Set.of("ROLE_USER"))
            .isActive(true)
            .isEmailVerified(true)
            .build();
        return userRepository.save(user);
    }
    
    protected User createTestAdminUser() {
        User admin = User.builder()
            .id("admin_test")
            .email("admin@example.com")
            .username("admin")
            .passwordHash(passwordEncoder.encode("AdminPass123!"))
            .firstName("Admin")
            .lastName("User")
            .roles(Set.of("ROLE_USER", "ROLE_ADMIN"))
            .isActive(true)
            .isEmailVerified(true)
            .build();
        return userRepository.save(admin);
    }
    
    protected String generateValidToken() {
        return jwtService.generateAccessToken(
            TEST_USER_ID, 
            TEST_USER_EMAIL, 
            Set.of("ROLE_USER")
        );
    }
    
    protected String generateExpiredToken() {
        // 建立已過期的 token（過期時間設為過去）
        Instant pastTime = Instant.now().minus(1, ChronoUnit.HOURS);
        return Jwts.builder()
            .setSubject(TEST_USER_ID)
            .setIssuedAt(Date.from(pastTime.minus(1, ChronoUnit.HOURS)))
            .setExpiration(Date.from(pastTime))
            .claim("email", TEST_USER_EMAIL)
            .claim("roles", Set.of("ROLE_USER"))
            .signWith(getPrivateKey(), SignatureAlgorithm.RS256)
            .compact();
    }
}
```

### 2. JWT 認證流程測試

```java
package com.fakestore.auth;

import org.junit.jupiter.api.*;
import org.springframework.http.*;
import static org.assertj.core.api.Assertions.*;
import static org.awaitility.Awaitility.*;

import java.time.Duration;
import java.util.concurrent.*;

@DisplayName("JWT 認證整合測試")
class JwtAuthIntegrationTest extends AuthIntegrationTestBase {
    
    @BeforeEach
    void setUp() {
        // 清理測試資料
        userRepository.deleteAll();
        redisTemplate.getConnectionFactory().getConnection().flushAll();
        
        // 建立測試用戶
        createTestUser();
    }
    
    @Test
    @DisplayName("應該成功登入並返回有效的 JWT Token")
    void shouldLoginSuccessfullyAndReturnValidJWT() {
        // Given
        LoginRequest request = LoginRequest.builder()
            .email(TEST_USER_EMAIL)
            .password(TEST_USER_PASSWORD)
            .build();
        
        HttpEntity<LoginRequest> entity = new HttpEntity<>(request, createJsonHeaders());
        
        // When
        ResponseEntity<AuthResponse> response = restTemplate.exchange(
            "/v1/auth/login",
            HttpMethod.POST,
            entity,
            AuthResponse.class
        );
        
        // Then - API 回應驗證
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        AuthResponse auth = response.getBody();
        
        assertThat(auth.getAccessToken()).isNotBlank();
        assertThat(auth.getRefreshToken()).isNotBlank();
        assertThat(auth.getTokenType()).isEqualTo("Bearer");
        assertThat(auth.getExpiresIn()).isEqualTo(900); // 15 分鐘 = 900 秒
        
        // 驗證用戶資訊
        assertThat(auth.getUser()).isNotNull();
        assertThat(auth.getUser().getId()).isEqualTo(TEST_USER_ID);
        assertThat(auth.getUser().getEmail()).isEqualTo(TEST_USER_EMAIL);
        
        // Then - Token 有效性驗證
        Claims claims = jwtService.validateToken(auth.getAccessToken());
        assertThat(claims.getSubject()).isEqualTo(TEST_USER_ID);
        assertThat(claims.get("email", String.class)).isEqualTo(TEST_USER_EMAIL);
        assertThat(claims.get("type", String.class)).isEqualTo("access");
        
        // Then - 資料庫狀態驗證（最後登入時間更新）
        User updatedUser = userRepository.findById(TEST_USER_ID).orElseThrow();
        assertThat(updatedUser.getLastLoginAt()).isNotNull();
        assertThat(updatedUser.getLastLoginAt()).isAfter(
            Instant.now().minus(10, ChronoUnit.SECONDS)
        );
    }
    
    @Test
    @DisplayName("錯誤密碼應該返回認證失敗")
    void shouldFailWithWrongPassword() {
        // Given
        LoginRequest request = LoginRequest.builder()
            .email(TEST_USER_EMAIL)
            .password("WrongPassword123!")
            .build();
        
        // When
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/auth/login",
            HttpMethod.POST,
            new HttpEntity<>(request, createJsonHeaders()),
            ErrorResponse.class
        );
        
        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody().getCode()).isEqualTo("INVALID_CREDENTIALS");
        assertThat(response.getBody().getMessage()).contains("帳號或密碼錯誤");
    }
    
    @Test
    @DisplayName("不存在的用戶應該返回認證失敗")
    void shouldFailWithNonExistentUser() {
        // Given
        LoginRequest request = LoginRequest.builder()
            .email("nonexistent@example.com")
            .password(TEST_USER_PASSWORD)
            .build();
        
        // When & Then
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/auth/login",
            HttpMethod.POST,
            new HttpEntity<>(request, createJsonHeaders()),
            ErrorResponse.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody().getCode()).isEqualTo("INVALID_CREDENTIALS");
    }
    
    @Test
    @DisplayName("應該成功刷新 Token")
    void shouldRefreshTokenSuccessfully() {
        // Given - 先登入獲取 Token
        LoginRequest loginRequest = LoginRequest.builder()
            .email(TEST_USER_EMAIL)
            .password(TEST_USER_PASSWORD)
            .build();
        
        ResponseEntity<AuthResponse> loginResponse = restTemplate.exchange(
            "/v1/auth/login",
            HttpMethod.POST,
            new HttpEntity<>(loginRequest, createJsonHeaders()),
            AuthResponse.class
        );
        
        String refreshToken = loginResponse.getBody().getRefreshToken();
        
        // When - 刷新 Token
        RefreshTokenRequest refreshRequest = RefreshTokenRequest.builder()
            .refreshToken(refreshToken)
            .build();
        
        ResponseEntity<AuthResponse> refreshResponse = restTemplate.exchange(
            "/v1/auth/refresh",
            HttpMethod.POST,
            new HttpEntity<>(refreshRequest, createJsonHeaders()),
            AuthResponse.class
        );
        
        // Then
        assertThat(refreshResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        AuthResponse newAuth = refreshResponse.getBody();
        
        assertThat(newAuth.getAccessToken()).isNotBlank();
        assertThat(newAuth.getRefreshToken()).isNotBlank();
        assertThat(newAuth.getAccessToken()).isNotEqualTo(loginResponse.getBody().getAccessToken());
        assertThat(newAuth.getRefreshToken()).isNotEqualTo(refreshToken); // Token 輪換
        
        // 驗證新 Token 有效性
        Claims newClaims = jwtService.validateToken(newAuth.getAccessToken());
        assertThat(newClaims.getSubject()).isEqualTo(TEST_USER_ID);
        
        // 驗證舊 Refresh Token 已失效
        ResponseEntity<ErrorResponse> oldTokenResponse = restTemplate.exchange(
            "/v1/auth/refresh",
            HttpMethod.POST,
            new HttpEntity<>(RefreshTokenRequest.builder().refreshToken(refreshToken).build(), 
                createJsonHeaders()),
            ErrorResponse.class
        );
        
        assertThat(oldTokenResponse.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
    
    @Test
    @DisplayName("無效的 Refresh Token 應該失敗")
    void shouldFailWithInvalidRefreshToken() {
        // Given
        RefreshTokenRequest request = RefreshTokenRequest.builder()
            .refreshToken("invalid_refresh_token")
            .build();
        
        // When & Then
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/auth/refresh",
            HttpMethod.POST,
            new HttpEntity<>(request, createJsonHeaders()),
            ErrorResponse.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody().getCode()).isEqualTo("INVALID_TOKEN");
    }
    
    @Test
    @DisplayName("應該成功登出並撤銷 Token")
    void shouldLogoutAndRevokeToken() {
        // Given - 先登入
        String token = generateValidToken();
        
        // When - 登出
        ResponseEntity<Void> response = restTemplate.exchange(
            "/v1/auth/logout",
            HttpMethod.POST,
            new HttpEntity<>(null, createAuthHeaders(token)),
            Void.class
        );
        
        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        
        // 驗證 Token 已被撤銷（嘗試存取受保護資源）
        ResponseEntity<ErrorResponse> protectedResponse = restTemplate.exchange(
            "/v1/users/me",
            HttpMethod.GET,
            new HttpEntity<>(null, createAuthHeaders(token)),
            ErrorResponse.class
        );
        
        assertThat(protectedResponse.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        
        // 驗證 Redis 中的撤銷記錄
        Claims claims = jwtService.validateToken(token);
        String jti = claims.getId();
        Object revokedToken = redisTemplate.opsForValue().get("revoked:" + jti);
        assertThat(revokedToken).isNotNull();
    }
    
    @Test
    @DisplayName("過期的 Token 應該被拒絕")
    void shouldRejectExpiredToken() {
        // Given
        String expiredToken = generateExpiredToken();
        
        // When & Then
        ResponseEntity<ErrorResponse> response = restTemplate.exchange(
            "/v1/users/me",
            HttpMethod.GET,
            new HttpEntity<>(null, createAuthHeaders(expiredToken)),
            ErrorResponse.class
        );
        
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody().getCode()).isEqualTo("TOKEN_EXPIRED");
    }
    
    @Test
    @DisplayName("應該正確處理並發登入")
    void shouldHandleConcurrentLogin() throws InterruptedException {
        // Given
        int threadCount = 5;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);
        List<CompletableFuture<ResponseEntity<AuthResponse>>> futures = new ArrayList<>();
        
        // When - 並發登入
        for (int i = 0; i < threadCount; i++) {
            CompletableFuture<ResponseEntity<AuthResponse>> future = 
                CompletableFuture.supplyAsync(() -> {
                    try {
                        LoginRequest request = LoginRequest.builder()
                            .email(TEST_USER_EMAIL)
                            .password(TEST_USER_PASSWORD)
                            .build();
                        
                        return restTemplate.exchange(
                            "/v1/auth/login",
                            HttpMethod.POST,
                            new HttpEntity<>(request, createJsonHeaders()),
                            AuthResponse.class
                        );
                    } finally {
                        latch.countDown();
                    }
                }, executor);
            
            futures.add(future);
        }
        
        latch.await(10, TimeUnit.SECONDS);
        
        // Then - 所有請求都應該成功
        List<ResponseEntity<AuthResponse>> responses = futures.stream()
            .map(CompletableFuture::join)
            .collect(Collectors.toList());
        
        responses.forEach(response -> {
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody().getAccessToken()).isNotBlank();
        });
        
        // 驗證所有 Token 都不相同
        Set<String> uniqueTokens = responses.stream()
            .map(r -> r.getBody().getAccessToken())
            .collect(Collectors.toSet());
        
        assertThat(uniqueTokens).hasSize(threadCount);
        
        executor.shutdown();
    }
}
```

### 3. 權限控制測試

```java
@Test
@DisplayName("一般用戶不應該存取管理員端點")
void shouldDenyUserAccessToAdminEndpoints() {
    // Given
    String userToken = generateValidToken();
    
    // When & Then
    ResponseEntity<ErrorResponse> response = restTemplate.exchange(
        "/v1/products",
        HttpMethod.POST,
        new HttpEntity<>(createTestProductRequest(), createAuthHeaders(userToken)),
        ErrorResponse.class
    );
    
    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    assertThat(response.getBody().getCode()).isEqualTo("ACCESS_DENIED");
}

@Test
@DisplayName("管理員應該可以存取管理員端點")
void shouldAllowAdminAccessToAdminEndpoints() {
    // Given
    User admin = createTestAdminUser();
    String adminToken = jwtService.generateAccessToken(
        admin.getId(), 
        admin.getEmail(), 
        admin.getRoles()
    );
    
    // When
    ResponseEntity<ProductResponse> response = restTemplate.exchange(
        "/v1/products",
        HttpMethod.POST,
        new HttpEntity<>(createTestProductRequest(), createAuthHeaders(adminToken)),
        ProductResponse.class
    );
    
    // Then
    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    assertThat(response.getBody()).isNotNull();
}
```

### 4. JWT 快取測試

```java
@Test
@DisplayName("應該正確快取用戶認證資訊")
void shouldCacheUserAuthenticationInfo() {
    // Given
    String token = generateValidToken();
    
    // When - 第一次存取受保護資源
    ResponseEntity<UserResponse> firstResponse = restTemplate.exchange(
        "/v1/users/me",
        HttpMethod.GET,
        new HttpEntity<>(null, createAuthHeaders(token)),
        UserResponse.class
    );
    
    // Then
    assertThat(firstResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
    
    // 驗證 Redis 快取
    String cacheKey = "user_auth:" + TEST_USER_ID;
    Object cachedAuth = redisTemplate.opsForValue().get(cacheKey);
    assertThat(cachedAuth).isNotNull();
    
    // 清空資料庫但保留快取
    userRepository.deleteAll();
    
    // 再次請求應該從快取返回
    ResponseEntity<UserResponse> cachedResponse = restTemplate.exchange(
        "/v1/users/me",
        HttpMethod.GET,
        new HttpEntity<>(null, createAuthHeaders(token)),
        UserResponse.class
    );
    
    assertThat(cachedResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(cachedResponse.getBody().getId()).isEqualTo(TEST_USER_ID);
}
```

## 測試資料管理策略

### 1. 測試資料建構器模式

```java
package com.fakestore.test.builders;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Set;

/**
 * 測試資料建構器 - Builder Pattern 實作
 * 提供流暢的 API 來建立測試資料
 */
public class TestDataBuilders {
    
    // 用戶資料建構器
    public static class UserBuilder {
        private String id = "user_" + System.currentTimeMillis();
        private String email = "test@example.com";
        private String username = "testuser";
        private String passwordHash = "$2a$12$hashed_password";
        private String firstName = "Test";
        private String lastName = "User";
        private Set<String> roles = Set.of("ROLE_USER");
        private boolean isActive = true;
        private boolean isEmailVerified = true;
        
        public static UserBuilder aUser() {
            return new UserBuilder();
        }
        
        public UserBuilder withId(String id) {
            this.id = id;
            return this;
        }
        
        public UserBuilder withEmail(String email) {
            this.email = email;
            return this;
        }
        
        public UserBuilder withUsername(String username) {
            this.username = username;
            return this;
        }
        
        public UserBuilder withRoles(Set<String> roles) {
            this.roles = roles;
            return this;
        }
        
        public UserBuilder asAdmin() {
            this.roles = Set.of("ROLE_USER", "ROLE_ADMIN");
            return this;
        }
        
        public UserBuilder inactive() {
            this.isActive = false;
            return this;
        }
        
        public UserBuilder unverified() {
            this.isEmailVerified = false;
            return this;
        }
        
        public User build() {
            return User.builder()
                .id(id)
                .email(email)
                .username(username)
                .passwordHash(passwordHash)
                .firstName(firstName)
                .lastName(lastName)
                .roles(roles)
                .isActive(isActive)
                .isEmailVerified(isEmailVerified)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        }
    }
    
    // 產品資料建構器
    public static class ProductBuilder {
        private String id = "prod_" + System.currentTimeMillis();
        private String name = "測試產品";
        private String description = "測試用產品描述";
        private BigDecimal price = new BigDecimal("99.99");
        private String categoryId = "cat_electronics";
        private int stockQuantity = 10;
        private boolean isActive = true;
        
        public static ProductBuilder aProduct() {
            return new ProductBuilder();
        }
        
        public ProductBuilder withId(String id) {
            this.id = id;
            return this;
        }
        
        public ProductBuilder withName(String name) {
            this.name = name;
            return this;
        }
        
        public ProductBuilder withPrice(BigDecimal price) {
            this.price = price;
            return this;
        }
        
        public ProductBuilder withStock(int quantity) {
            this.stockQuantity = quantity;
            return this;
        }
        
        public ProductBuilder outOfStock() {
            this.stockQuantity = 0;
            return this;
        }
        
        public ProductBuilder inactive() {
            this.isActive = false;
            return this;
        }
        
        public Product build() {
            return Product.builder()
                .id(id)
                .name(name)
                .description(description)
                .price(price)
                .categoryId(categoryId)
                .stockQuantity(stockQuantity)
                .isActive(isActive)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        }
    }
    
    // 訂單資料建構器
    public static class OrderBuilder {
        private String id = "order_" + System.currentTimeMillis();
        private String userId;
        private OrderStatus status = OrderStatus.PENDING;
        private BigDecimal totalAmount = BigDecimal.ZERO;
        private String currency = "TWD";
        private List<OrderItem> items = new ArrayList<>();
        
        public static OrderBuilder anOrder() {
            return new OrderBuilder();
        }
        
        public OrderBuilder withId(String id) {
            this.id = id;
            return this;
        }
        
        public OrderBuilder forUser(String userId) {
            this.userId = userId;
            return this;
        }
        
        public OrderBuilder withStatus(OrderStatus status) {
            this.status = status;
            return this;
        }
        
        public OrderBuilder withAmount(BigDecimal amount) {
            this.totalAmount = amount;
            return this;
        }
        
        public OrderBuilder addItem(String productId, int quantity, BigDecimal unitPrice) {
            OrderItem item = OrderItem.builder()
                .id("item_" + System.currentTimeMillis())
                .productId(productId)
                .quantity(quantity)
                .unitPrice(unitPrice)
                .build();
            items.add(item);
            return this;
        }
        
        public Order build() {
            Order order = Order.builder()
                .id(id)
                .userId(userId)
                .status(status)
                .totalAmount(totalAmount)
                .currency(currency)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
            
            items.forEach(order::addItem);
            return order;
        }
    }
    
    // 購物車資料建構器
    public static class CartBuilder {
        private String id = "cart_" + System.currentTimeMillis();
        private String userId;
        private BigDecimal totalAmount = BigDecimal.ZERO;
        private List<CartItem> items = new ArrayList<>();
        
        public static CartBuilder aCart() {
            return new CartBuilder();
        }
        
        public CartBuilder withId(String id) {
            this.id = id;
            return this;
        }
        
        public CartBuilder forUser(String userId) {
            this.userId = userId;
            return this;
        }
        
        public CartBuilder addItem(String productId, int quantity, BigDecimal unitPrice) {
            CartItem item = CartItem.builder()
                .id("cart_item_" + System.currentTimeMillis())
                .productId(productId)
                .quantity(quantity)
                .unitPrice(unitPrice)
                .build();
            items.add(item);
            
            // 自動計算總金額
            BigDecimal itemTotal = unitPrice.multiply(BigDecimal.valueOf(quantity));
            this.totalAmount = this.totalAmount.add(itemTotal);
            return this;
        }
        
        public Cart build() {
            Cart cart = Cart.builder()
                .id(id)
                .userId(userId)
                .totalAmount(totalAmount)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
            
            items.forEach(cart::addItem);
            return cart;
        }
    }
}
```

### 2. 測試資料工廠

```java
package com.fakestore.test.fixtures;

import com.fakestore.test.builders.TestDataBuilders;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 測試資料工廠
 * 提供預設的測試資料組合
 */
@Component
public class TestDataFactory {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private ProductRepository productRepository;
    
    @Autowired
    private CartRepository cartRepository;
    
    @Autowired
    private PasswordEncoder passwordEncoder;
    
    // 標準測試用戶
    public User createStandardUser() {
        return userRepository.save(
            TestDataBuilders.UserBuilder.aUser()
                .withId("user_standard")
                .withEmail("user@example.com")
                .withUsername("standarduser")
                .build()
        );
    }
    
    // 管理員用戶
    public User createAdminUser() {
        return userRepository.save(
            TestDataBuilders.UserBuilder.aUser()
                .withId("admin_test")
                .withEmail("admin@example.com")
                .withUsername("admin")
                .asAdmin()
                .build()
        );
    }
    
    // 完整的購物情境
    public ShoppingScenario createShoppingScenario() {
        // 建立用戶
        User user = createStandardUser();
        
        // 建立產品
        Product product1 = productRepository.save(
            TestDataBuilders.ProductBuilder.aProduct()
                .withId("prod_scenario_1")
                .withName("iPhone 15")
                .withPrice(new BigDecimal("30000"))
                .withStock(5)
                .build()
        );
        
        Product product2 = productRepository.save(
            TestDataBuilders.ProductBuilder.aProduct()
                .withId("prod_scenario_2")
                .withName("MacBook Pro")
                .withPrice(new BigDecimal("60000"))
                .withStock(3)
                .build()
        );
        
        // 建立購物車
        Cart cart = cartRepository.save(
            TestDataBuilders.CartBuilder.aCart()
                .withId("cart_scenario")
                .forUser(user.getId())
                .addItem(product1.getId(), 1, product1.getPrice())
                .addItem(product2.getId(), 1, product2.getPrice())
                .build()
        );
        
        return ShoppingScenario.builder()
            .user(user)
            .products(List.of(product1, product2))
            .cart(cart)
            .build();
    }
    
    // 庫存不足情境
    public OutOfStockScenario createOutOfStockScenario() {
        User user = createStandardUser();
        
        Product product = productRepository.save(
            TestDataBuilders.ProductBuilder.aProduct()
                .withId("prod_out_of_stock")
                .withName("Limited Edition Item")
                .withPrice(new BigDecimal("500"))
                .withStock(1) // 只有1個庫存
                .build()
        );
        
        return OutOfStockScenario.builder()
            .user(user)
            .product(product)
            .build();
    }
    
    // 測試情境資料類別
    @Data
    @Builder
    public static class ShoppingScenario {
        private User user;
        private List<Product> products;
        private Cart cart;
    }
    
    @Data
    @Builder
    public static class OutOfStockScenario {
        private User user;
        private Product product;
    }
}
```

### 3. 測試資料清理策略

```java
package com.fakestore.test.cleanup;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * 測試資料清理工具
 * 確保測試間的資料隔離
 */
@Component
public class TestDataCleaner {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private ProductRepository productRepository;
    
    @Autowired
    private CartRepository cartRepository;
    
    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private PaymentRepository paymentRepository;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    /**
     * 清理所有測試資料
     */
    @Transactional
    public void cleanAll() {
        // 依據外鍵約束順序清理
        paymentRepository.deleteAll();
        orderRepository.deleteAll();
        cartRepository.deleteAll();
        productRepository.deleteAll();
        userRepository.deleteAll();
        
        // 清理 Redis 快取
        redisTemplate.getConnectionFactory().getConnection().flushAll();
    }
    
    /**
     * 清理特定用戶的資料
     */
    @Transactional
    public void cleanUserData(String userId) {
        // 清理用戶相關資料
        paymentRepository.deleteByUserId(userId);
        orderRepository.deleteByUserId(userId);
        cartRepository.deleteByUserId(userId);
        userRepository.deleteById(userId);
        
        // 清理 Redis 中的用戶快取
        redisTemplate.delete("user_auth:" + userId);
        redisTemplate.delete("cart:" + userId);
    }
    
    /**
     * 重設產品庫存
     */
    public void resetProductStock() {
        productRepository.findAll().forEach(product -> {
            product.setStockQuantity(10); // 重設為預設庫存
            productRepository.save(product);
        });
    }
}
```

### 4. 測試執行順序管理

```java
package com.fakestore.test.execution;

import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.test.context.TestExecutionListeners;
import org.springframework.test.context.support.DependencyInjectionTestExecutionListener;
import org.springframework.test.context.transaction.TransactionalTestExecutionListener;

/**
 * 自訂測試執行監聽器
 * 管理測試資料的生命週期
 */
public class TestDataLifecycleListener extends AbstractTestExecutionListener {
    
    @Override
    public void beforeTestMethod(TestContext testContext) throws Exception {
        TestDataCleaner cleaner = testContext.getApplicationContext()
            .getBean(TestDataCleaner.class);
        
        // 每個測試方法執行前清理資料
        cleaner.cleanAll();
    }
    
    @Override
    public void afterTestMethod(TestContext testContext) throws Exception {
        // 測試完成後的清理工作（可選）
        // 通常交由 @Transactional 處理回滾
    }
}

// 使用方式
@TestExecutionListeners({
    DependencyInjectionTestExecutionListener.class,
    TransactionalTestExecutionListener.class,
    TestDataLifecycleListener.class
})
public abstract class BaseIntegrationTest {
    // 基礎測試類別
}
```

### 5. 測試環境配置檔案

```properties
# application-test.properties

# 資料庫配置 - 由 TestContainers 動態配置
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

# Redis 配置 - 由 TestContainers 動態配置
spring.redis.timeout=2000ms
spring.cache.type=redis
spring.cache.redis.time-to-live=300000

# JWT 測試配置
jwt.access-token-expiration=900
jwt.refresh-token-expiration=604800
jwt.key-id=test-key-1
jwt.issuer=fake-store-test

# 外部服務配置
stripe.api.timeout=5000
stripe.webhook.endpoint-secret=whsec_test_secret

# 日誌配置
logging.level.com.fakestore=INFO
logging.level.org.springframework.security=DEBUG
logging.level.org.hibernate.SQL=ERROR
logging.level.org.testcontainers=INFO

# 測試專用設定
spring.main.lazy-initialization=true
spring.jpa.defer-datasource-initialization=true
```

## 效能最佳化建議

### 1. 容器共享策略

```java
// 跨測試類別共享容器
@Testcontainers
public class SharedTestContainers {
    
    @Container
    static PostgreSQLContainer<?> sharedPostgres = 
        new PostgreSQLContainer<>("postgres:15.4")
            .withReuse(true)
            .withLabel("testcontainers.reuse", "true");
    
    static {
        sharedPostgres.start();
    }
    
    public static String getJdbcUrl() {
        return sharedPostgres.getJdbcUrl();
    }
}
```

### 2. 測試分組執行

```java
// 快速測試組
@Tag("fast")
class FastIntegrationTest extends BaseIntegrationTest {
    // 執行時間 < 5 秒的測試
}

// 慢速測試組  
@Tag("slow")
class SlowIntegrationTest extends BaseIntegrationTest {
    // 執行時間 > 5 秒的測試
}
```

### 3. 並行測試配置

```properties
# junit-platform.properties
junit.jupiter.execution.parallel.enabled=true
junit.jupiter.execution.parallel.mode.default=concurrent
junit.jupiter.execution.parallel.config.strategy=dynamic
```

---

*最後更新：2025-08-24*