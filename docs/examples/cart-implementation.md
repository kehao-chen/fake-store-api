# 購物車功能實作範例

[← 返回文件中心](../README.md) | [實作範例](../examples/) | **購物車實作**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-23
- **目標讀者**: 後端開發者、架構師
- **相關文件**: 
  - [功能需求](../requirements/functional.md)
  - [API 設計規格](../api/design-spec.md)
  - [產品 API 實作](./product-api.md)

## 1. 購物車領域模型

### Cart Entity

```java
package com.fakestore.domain.cart;

import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.relational.core.mapping.Table;
import org.springframework.data.relational.core.mapping.Column;

import javax.validation.constraints.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table("carts")
public class Cart {
    
    @Id
    @Column("id")
    private String id;
    
    @NotBlank(message = "使用者 ID 不能為空")
    @Column("user_id")
    private String userId;
    
    @Builder.Default
    @Column("is_active")
    private Boolean isActive = true;
    
    @CreatedDate
    @Column("created_at")
    private Instant createdAt;
    
    @LastModifiedDate
    @Column("updated_at")
    private Instant updatedAt;
    
    // 購物車項目 (一對多關聯)
    @Builder.Default
    private List<CartItem> items = new ArrayList<>();
    
    // 領域方法
    public void addItem(String productId, String productName, BigDecimal price, int quantity) {
        Optional<CartItem> existingItem = findItemByProductId(productId);
        
        if (existingItem.isPresent()) {
            existingItem.get().updateQuantity(existingItem.get().getQuantity() + quantity);
        } else {
            CartItem newItem = CartItem.builder()
                .productId(productId)
                .productName(productName)
                .price(price)
                .quantity(quantity)
                .build();
            items.add(newItem);
        }
        
        this.updatedAt = Instant.now();
    }
    
    public void updateItemQuantity(String productId, int newQuantity) {
        CartItem item = findItemByProductId(productId)
            .orElseThrow(() -> new CartItemNotFoundException(productId));
            
        if (newQuantity <= 0) {
            removeItem(productId);
        } else {
            item.updateQuantity(newQuantity);
            this.updatedAt = Instant.now();
        }
    }
    
    public void removeItem(String productId) {
        items.removeIf(item -> item.getProductId().equals(productId));
        this.updatedAt = Instant.now();
    }
    
    public void clearCart() {
        items.clear();
        this.updatedAt = Instant.now();
    }
    
    public BigDecimal getTotalAmount() {
        return items.stream()
            .map(CartItem::getSubtotal)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
    
    public int getTotalItems() {
        return items.stream()
            .mapToInt(CartItem::getQuantity)
            .sum();
    }
    
    public boolean isEmpty() {
        return items.isEmpty();
    }
    
    private Optional<CartItem> findItemByProductId(String productId) {
        return items.stream()
            .filter(item -> item.getProductId().equals(productId))
            .findFirst();
    }
    
    // 靜態工廠方法
    public static Cart createForUser(String userId) {
        return Cart.builder()
            .id("cart_" + java.util.UUID.randomUUID().toString().substring(0, 8))
            .userId(userId)
            .isActive(true)
            .build();
    }
}
```

### CartItem Entity

```java
package com.fakestore.domain.cart;

import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;
import org.springframework.data.relational.core.mapping.Column;

import javax.validation.constraints.*;
import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table("cart_items")
public class CartItem {
    
    @Id
    @Column("id")
    private String id;
    
    @NotBlank(message = "購物車 ID 不能為空")
    @Column("cart_id")
    private String cartId;
    
    @NotBlank(message = "產品 ID 不能為空")
    @Column("product_id")
    private String productId;
    
    @NotBlank(message = "產品名稱不能為空")
    @Column("product_name")
    private String productName;
    
    @NotNull(message = "價格不能為空")
    @DecimalMin(value = "0.0", inclusive = false, message = "價格必須大於 0")
    @Column("price")
    private BigDecimal price;
    
    @Min(value = 1, message = "數量必須大於 0")
    @Column("quantity")
    private Integer quantity;
    
    // 領域方法
    public void updateQuantity(int newQuantity) {
        if (newQuantity <= 0) {
            throw new IllegalArgumentException("數量必須大於 0");
        }
        this.quantity = newQuantity;
    }
    
    public BigDecimal getSubtotal() {
        return price.multiply(BigDecimal.valueOf(quantity));
    }
}
```

## 2. Cart Controller

```java
package com.fakestore.controller;

import com.fakestore.dto.request.AddToCartRequest;
import com.fakestore.dto.request.UpdateCartItemRequest;
import com.fakestore.dto.response.CartResponse;
import com.fakestore.service.CartService;
import com.fakestore.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import javax.validation.Valid;

@Slf4j
@RestController
@RequestMapping("/v1/users/me/cart")
@RequiredArgsConstructor
@Validated
@Tag(name = "Cart", description = "購物車管理 API")
@SecurityRequirement(name = "bearerAuth")
public class CartController {
    
    private final CartService cartService;
    
    @GetMapping
    @Operation(
        summary = "查看購物車",
        description = "獲取當前使用者的購物車內容"
    )
    public Mono<ResponseEntity<CartResponse>> getCart(
            @AuthenticationPrincipal UserPrincipal user) {
        
        log.info("查看購物車 - userId: {}", user.getUserId());
        
        return cartService.getCartByUserId(user.getUserId())
            .map(cart -> ResponseEntity.ok()
                .header("Cache-Control", "no-cache")
                .body(cart))
            .doOnSuccess(response -> 
                log.info("成功獲取購物車: {} 個商品", 
                    response.getBody().getTotalItems())
            );
    }
    
    @PostMapping("/items")
    @Operation(
        summary = "加入商品到購物車",
        description = "將指定商品加入到使用者的購物車中"
    )
    public Mono<ResponseEntity<CartResponse>> addToCart(
            @AuthenticationPrincipal UserPrincipal user,
            @Valid @RequestBody AddToCartRequest request) {
        
        log.info("加入購物車 - userId: {}, productId: {}, quantity: {}", 
            user.getUserId(), request.getProductId(), request.getQuantity());
        
        return cartService.addToCart(user.getUserId(), request)
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("成功加入購物車: 總計 {} 個商品", 
                    response.getBody().getTotalItems())
            );
    }
    
    @PatchMapping("/items/{productId}")
    @Operation(
        summary = "更新購物車商品數量",
        description = "更新購物車中指定商品的數量"
    )
    public Mono<ResponseEntity<CartResponse>> updateCartItem(
            @AuthenticationPrincipal UserPrincipal user,
            @Parameter(description = "商品 ID", required = true)
            @PathVariable String productId,
            @Valid @RequestBody UpdateCartItemRequest request) {
        
        log.info("更新購物車商品 - userId: {}, productId: {}, newQuantity: {}", 
            user.getUserId(), productId, request.getQuantity());
        
        return cartService.updateCartItem(user.getUserId(), productId, request.getQuantity())
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("成功更新購物車商品數量")
            );
    }
    
    @DeleteMapping("/items/{productId}")
    @Operation(
        summary = "從購物車移除商品",
        description = "從購物車中移除指定商品"
    )
    public Mono<ResponseEntity<CartResponse>> removeFromCart(
            @AuthenticationPrincipal UserPrincipal user,
            @Parameter(description = "商品 ID", required = true)
            @PathVariable String productId) {
        
        log.info("移除購物車商品 - userId: {}, productId: {}", 
            user.getUserId(), productId);
        
        return cartService.removeFromCart(user.getUserId(), productId)
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("成功移除購物車商品")
            );
    }
    
    @PostMapping(value = ":clear") // AIP-136 自訂方法：使用 value 屬性明確指定冒號路徑
    @Operation(
        summary = "清空購物車",
        description = "清空使用者購物車中的所有商品"
    )
    public Mono<ResponseEntity<CartResponse>> clearCart(
            @AuthenticationPrincipal UserPrincipal user) {
        
        log.info("清空購物車 - userId: {}", user.getUserId());
        
        return cartService.clearCart(user.getUserId())
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("成功清空購物車")
            );
    }
    
    @PostMapping(value = ":checkout") // AIP-136 自訂方法：使用 value 屬性明確指定冒號路徑
    @Operation(
        summary = "購物車結帳",
        description = "將購物車內容轉換為訂單"
    )
    public Mono<ResponseEntity<CheckoutResponse>> checkout(
            @AuthenticationPrincipal UserPrincipal user,
            @Valid @RequestBody CheckoutRequest request) {
        
        log.info("購物車結帳 - userId: {}", user.getUserId());
        
        return cartService.checkout(user.getUserId(), request)
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("結帳成功 - orderId: {}", response.getBody().getOrderId())
            );
    }
}
```

## 3. Cart Service

```java
package com.fakestore.service;

import com.fakestore.domain.cart.Cart;
import com.fakestore.domain.product.Product;
import com.fakestore.dto.request.AddToCartRequest;
import com.fakestore.dto.request.CheckoutRequest;
import com.fakestore.dto.response.CartResponse;
import com.fakestore.dto.response.CheckoutResponse;
import com.fakestore.exception.CartNotFoundException;
import com.fakestore.exception.InsufficientStockException;
import com.fakestore.exception.ProductNotFoundException;
import com.fakestore.mapper.CartMapper;
import com.fakestore.repository.CartRepository;
import com.fakestore.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Mono;

@Slf4j
@Service
@RequiredArgsConstructor
public class CartService {
    
    private final CartRepository cartRepository;
    private final ProductRepository productRepository;
    private final CartMapper cartMapper;
    private final OrderService orderService;
    private final EventPublisher eventPublisher;
    
    @Cacheable(value = "cart", key = "#userId")
    public Mono<CartResponse> getCartByUserId(String userId) {
        return cartRepository.findByUserIdAndIsActiveTrue(userId)
            .switchIfEmpty(createEmptyCart(userId))
            .flatMap(this::loadCartItems)
            .map(cartMapper::toResponse);
    }
    
    @Transactional
    @CacheEvict(value = "cart", key = "#userId")
    public Mono<CartResponse> addToCart(String userId, AddToCartRequest request) {
        return productRepository.findById(request.getProductId())
            .switchIfEmpty(Mono.error(new ProductNotFoundException(request.getProductId())))
            .flatMap(product -> validateStock(product, request.getQuantity()))
            .flatMap(product -> getOrCreateCart(userId)
                .flatMap(cart -> {
                    cart.addItem(
                        product.getId(),
                        product.getName(),
                        product.getPrice(),
                        request.getQuantity()
                    );
                    return cartRepository.save(cart);
                }))
            .flatMap(this::loadCartItems)
            .map(cartMapper::toResponse)
            .doOnSuccess(cart -> {
                eventPublisher.publishCartItemAdded(
                    userId, request.getProductId(), request.getQuantity()
                );
            });
    }
    
    @Transactional
    @CacheEvict(value = "cart", key = "#userId")
    public Mono<CartResponse> updateCartItem(String userId, String productId, int quantity) {
        return getCartByUserId(userId)
            .cast(Cart.class)
            .flatMap(cart -> {
                if (quantity > 0) {
                    // 驗證庫存
                    return productRepository.findById(productId)
                        .switchIfEmpty(Mono.error(new ProductNotFoundException(productId)))
                        .flatMap(product -> validateStock(product, quantity))
                        .then(Mono.fromRunnable(() -> cart.updateItemQuantity(productId, quantity)))
                        .then(cartRepository.save(cart));
                } else {
                    // 數量為 0 時移除商品
                    cart.removeItem(productId);
                    return cartRepository.save(cart);
                }
            })
            .flatMap(this::loadCartItems)
            .map(cartMapper::toResponse)
            .doOnSuccess(cart -> {
                eventPublisher.publishCartItemUpdated(userId, productId, quantity);
            });
    }
    
    @Transactional
    @CacheEvict(value = "cart", key = "#userId")
    public Mono<CartResponse> removeFromCart(String userId, String productId) {
        return getCartByUserId(userId)
            .cast(Cart.class)
            .flatMap(cart -> {
                cart.removeItem(productId);
                return cartRepository.save(cart);
            })
            .flatMap(this::loadCartItems)
            .map(cartMapper::toResponse)
            .doOnSuccess(cart -> {
                eventPublisher.publishCartItemRemoved(userId, productId);
            });
    }
    
    @Transactional
    @CacheEvict(value = "cart", key = "#userId")
    public Mono<CartResponse> clearCart(String userId) {
        return getCartByUserId(userId)
            .cast(Cart.class)
            .flatMap(cart -> {
                cart.clearCart();
                return cartRepository.save(cart);
            })
            .map(cartMapper::toResponse)
            .doOnSuccess(cart -> {
                eventPublisher.publishCartCleared(userId);
            });
    }
    
    @Transactional
    @CacheEvict(value = "cart", key = "#userId")
    public Mono<CheckoutResponse> checkout(String userId, CheckoutRequest request) {
        return getCartByUserId(userId)
            .cast(Cart.class)
            .flatMap(cart -> {
                if (cart.isEmpty()) {
                    return Mono.error(new EmptyCartException("購物車為空，無法結帳"));
                }
                
                // 驗證所有商品庫存
                return validateAllItemsStock(cart)
                    .then(orderService.createOrderFromCart(cart, request))
                    .flatMap(order -> {
                        // 結帳成功後清空購物車
                        cart.clearCart();
                        return cartRepository.save(cart)
                            .then(Mono.just(CheckoutResponse.builder()
                                .orderId(order.getId())
                                .totalAmount(order.getTotalAmount())
                                .status("pending")
                                .build()));
                    });
            })
            .doOnSuccess(response -> {
                eventPublisher.publishCartCheckedOut(userId, response.getOrderId());
            });
    }
    
    // 私有輔助方法
    private Mono<Cart> createEmptyCart(String userId) {
        Cart cart = Cart.createForUser(userId);
        return cartRepository.save(cart);
    }
    
    private Mono<Cart> getOrCreateCart(String userId) {
        return cartRepository.findByUserIdAndIsActiveTrue(userId)
            .switchIfEmpty(createEmptyCart(userId));
    }
    
    private Mono<Cart> loadCartItems(Cart cart) {
        return cartRepository.findCartItemsByCartId(cart.getId())
            .collectList()
            .doOnNext(cart::setItems)
            .then(Mono.just(cart));
    }
    
    private Mono<Product> validateStock(Product product, int requestedQuantity) {
        if (product.getStockQuantity() < requestedQuantity) {
            return Mono.error(new InsufficientStockException(
                String.format("庫存不足，目前庫存: %d, 請求數量: %d", 
                    product.getStockQuantity(), requestedQuantity)
            ));
        }
        return Mono.just(product);
    }
    
    private Mono<Void> validateAllItemsStock(Cart cart) {
        return Flux.fromIterable(cart.getItems())
            .flatMap(item -> 
                productRepository.findById(item.getProductId())
                    .switchIfEmpty(Mono.error(new ProductNotFoundException(item.getProductId())))
                    .flatMap(product -> validateStock(product, item.getQuantity()))
            )
            .then();
    }
}
```

## 4. Cart Repository

```java
package com.fakestore.repository;

import com.fakestore.domain.cart.Cart;
import com.fakestore.domain.cart.CartItem;
import org.springframework.data.r2dbc.repository.Query;
import org.springframework.data.r2dbc.repository.R2dbcRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Repository
public interface CartRepository extends R2dbcRepository<Cart, String> {
    
    // 基本查詢
    Mono<Cart> findByUserIdAndIsActiveTrue(String userId);
    
    // 購物車項目查詢
    @Query("SELECT * FROM cart_items WHERE cart_id = :cartId ORDER BY created_at")
    Flux<CartItem> findCartItemsByCartId(@Param("cartId") String cartId);
    
    // 批次更新購物車項目
    @Query("""
        INSERT INTO cart_items (id, cart_id, product_id, product_name, price, quantity)
        VALUES (:#{#item.id}, :#{#item.cartId}, :#{#item.productId}, 
                :#{#item.productName}, :#{#item.price}, :#{#item.quantity})
        ON CONFLICT (cart_id, product_id) 
        DO UPDATE SET 
            quantity = cart_items.quantity + :#{#item.quantity},
            updated_at = CURRENT_TIMESTAMP
        """)
    Mono<Integer> upsertCartItem(@Param("item") CartItem item);
    
    // 刪除購物車項目
    @Query("DELETE FROM cart_items WHERE cart_id = :cartId AND product_id = :productId")
    Mono<Integer> deleteCartItem(@Param("cartId") String cartId, @Param("productId") String productId);
    
    // 清空購物車
    @Query("DELETE FROM cart_items WHERE cart_id = :cartId")
    Mono<Integer> clearCartItems(@Param("cartId") String cartId);
    
    // 統計查詢
    @Query("SELECT COUNT(*) FROM cart_items WHERE cart_id = :cartId")
    Mono<Long> countCartItems(@Param("cartId") String cartId);
    
    @Query("""
        SELECT SUM(price * quantity) 
        FROM cart_items 
        WHERE cart_id = :cartId
        """)
    Mono<BigDecimal> calculateCartTotal(@Param("cartId") String cartId);
    
    // 購物車過期清理
    @Query("""
        UPDATE carts SET is_active = false 
        WHERE updated_at < :threshold AND is_active = true
        """)
    Mono<Integer> deactivateExpiredCarts(@Param("threshold") Instant threshold);
}
```

## 5. DTO Classes

### 請求 DTO

```java
// AddToCartRequest.java
package com.fakestore.dto.request;

import lombok.Data;
import javax.validation.constraints.*;

@Data
public class AddToCartRequest {
    
    @NotBlank(message = "產品 ID 不能為空")
    private String productId;
    
    @Min(value = 1, message = "數量必須大於 0")
    @Max(value = 10, message = "單次加入數量不能超過 10")
    private Integer quantity;
}

// UpdateCartItemRequest.java
package com.fakestore.dto.request;

import lombok.Data;
import javax.validation.constraints.*;

@Data
public class UpdateCartItemRequest {
    
    @Min(value = 0, message = "數量不能為負數")
    @Max(value = 100, message = "數量不能超過 100")
    private Integer quantity;
}

// CheckoutRequest.java
package com.fakestore.dto.request;

import lombok.Data;
import javax.validation.constraints.*;

@Data
public class CheckoutRequest {
    
    @NotBlank(message = "收貨地址不能為空")
    private String shippingAddress;
    
    @Pattern(regexp = "^(standard|express)$", message = "配送方式必須是 standard 或 express")
    private String shippingMethod;
    
    private String notes;
}
```

### 回應 DTO

```java
// CartResponse.java
package com.fakestore.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class CartResponse {
    
    private String id;
    private String userId;
    private List<CartItemResponse> items;
    private BigDecimal totalAmount;
    private Integer totalItems;
    private String updatedAt;
}

// CartItemResponse.java
package com.fakestore.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
public class CartItemResponse {
    
    private String productId;
    private String productName;
    private BigDecimal price;
    private Integer quantity;
    private BigDecimal subtotal;
    private String imageUrl;
    private Boolean inStock;
}

// CheckoutResponse.java
package com.fakestore.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
public class CheckoutResponse {
    
    private String orderId;
    private String status;
    private BigDecimal totalAmount;
    private String checkoutUrl; // 用於支付頁面跳轉
}
```

## 6. 測試範例

### 單元測試

```java
package com.fakestore.service;

import com.fakestore.domain.cart.Cart;
import com.fakestore.domain.product.Product;
import com.fakestore.dto.request.AddToCartRequest;
import com.fakestore.repository.CartRepository;
import com.fakestore.repository.ProductRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.math.BigDecimal;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CartServiceTest {
    
    @Mock
    private CartRepository cartRepository;
    
    @Mock
    private ProductRepository productRepository;
    
    @InjectMocks
    private CartService cartService;
    
    @Test
    void shouldAddProductToCart() {
        // Given
        String userId = "user_123";
        String productId = "prod_456";
        
        Product product = Product.builder()
            .id(productId)
            .name("測試產品")
            .price(BigDecimal.valueOf(99.99))
            .stockQuantity(10)
            .build();
            
        Cart cart = Cart.createForUser(userId);
        
        AddToCartRequest request = new AddToCartRequest();
        request.setProductId(productId);
        request.setQuantity(2);
        
        when(productRepository.findById(productId)).thenReturn(Mono.just(product));
        when(cartRepository.findByUserIdAndIsActiveTrue(userId)).thenReturn(Mono.just(cart));
        when(cartRepository.save(any(Cart.class))).thenReturn(Mono.just(cart));
        
        // When & Then
        StepVerifier.create(cartService.addToCart(userId, request))
            .expectNextMatches(response -> 
                response.getTotalItems() == 2 &&
                response.getTotalAmount().equals(BigDecimal.valueOf(199.98))
            )
            .verifyComplete();
    }
    
    @Test
    void shouldThrowExceptionWhenInsufficientStock() {
        // Given
        String userId = "user_123";
        String productId = "prod_456";
        
        Product product = Product.builder()
            .id(productId)
            .name("測試產品")
            .price(BigDecimal.valueOf(99.99))
            .stockQuantity(1) // 庫存不足
            .build();
            
        AddToCartRequest request = new AddToCartRequest();
        request.setProductId(productId);
        request.setQuantity(5); // 請求數量大於庫存
        
        when(productRepository.findById(productId)).thenReturn(Mono.just(product));
        
        // When & Then
        StepVerifier.create(cartService.addToCart(userId, request))
            .expectError(InsufficientStockException.class)
            .verify();
    }
}
```

### 整合測試

```java
package com.fakestore.controller;

import com.fakestore.dto.request.AddToCartRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.AutoConfigureWebTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.reactive.server.WebTestClient;
import org.springframework.security.test.context.support.WithMockUser;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureWebTestClient
class CartControllerIntegrationTest {
    
    @Autowired
    private WebTestClient webTestClient;
    
    @Test
    @WithMockUser(username = "user_123", roles = "USER")
    void shouldAddToCart() {
        AddToCartRequest request = new AddToCartRequest();
        request.setProductId("prod_123");
        request.setQuantity(2);
        
        webTestClient.post()
            .uri("/v1/users/me/cart/items")
            .bodyValue(request)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.totalItems").isEqualTo(2)
            .jsonPath("$.items[0].productId").isEqualTo("prod_123")
            .jsonPath("$.items[0].quantity").isEqualTo(2);
    }
    
    @Test
    @WithMockUser(username = "user_123", roles = "USER")
    void shouldGetCart() {
        webTestClient.get()
            .uri("/v1/users/me/cart")
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.userId").isEqualTo("user_123")
            .jsonPath("$.items").isArray();
    }
}
```

## 相關文件

- [產品 API 實作](./product-api.md) - 產品管理功能
- [認證實作](./auth-jwt.md) - JWT 認證機制
- [支付整合](./payments.md) - 支付處理流程
- [API 設計規格](../api/design-spec.md) - API 設計標準
- [功能需求](../requirements/functional.md) - 業務功能說明

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-23*