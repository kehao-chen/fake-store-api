# DDD 領域模型設計

本文件描述 Fake Store API 的領域驅動設計（Domain-Driven Design）模型。

## 領域概覽

```mermaid
graph TB
    subgraph "核心領域 (Core Domain)"
        Product[產品管理]
        Cart[購物車]
        Order[訂單處理]
        Payment[支付處理]
    end
    
    subgraph "支援領域 (Supporting Domain)"
        User[使用者管理]
        Category[分類管理]
        Notification[通知服務]
    end
    
    subgraph "通用領域 (Generic Domain)"
        Auth[認證授權]
        Email[郵件服務]
    end
    
    Cart --> Product
    Order --> Cart
    Order --> Payment
    Payment --> Notification
    Payment -->|Webhook 對賬| Order
    User --> Auth
    Product --> Category
```

## 聚合根（Aggregate Roots）

### 1. Product 聚合

```mermaid
classDiagram
    class Product {
        <<Aggregate Root>>
        +String id
        +String name
        +String description
        +BigDecimal price
        +String categoryId
        +Integer stockQuantity
        +Boolean isActive
        +Instant createdAt
        +Instant updatedAt
        +updateStock(quantity)
        +changePrice(newPrice)
        +deactivate()
        +validate()
    }
    
    class ProductImage {
        <<Value Object>>
        +String url
        +String alt
        +Integer order
    }
    
    class Price {
        <<Value Object>>
        +BigDecimal amount
        +String currency
        +isValid()
    }
    
    class StockLevel {
        <<Value Object>>
        +Integer quantity
        +Integer reserved
        +Integer available
        +canFulfill(requested)
    }
    
    Product "1" --> "*" ProductImage
    Product "1" --> "1" Price
    Product "1" --> "1" StockLevel
```

### 2. Cart 聚合

```mermaid
classDiagram
    class Cart {
        <<Aggregate Root>>
        +String id
        +String userId
        +String sessionId
        +List~CartItem~ items
        +BigDecimal totalAmount
        +Instant expiresAt
        +addItem(productId, quantity)
        +removeItem(productId)
        +updateQuantity(productId, quantity)
        +clear()
        +checkout()
        +recalculateTotal()
    }
    
    class CartItem {
        <<Entity>>
        +String productId
        +String productName
        +Integer quantity
        +BigDecimal unitPrice
        +BigDecimal totalPrice
        +updateQuantity(newQuantity)
        +calculateTotal()
    }
    
    class CartStatus {
        <<Value Object>>
        +StatusType status
        +Instant lastModified
        +isExpired()
        +canCheckout()
    }
    
    Cart "1" --> "*" CartItem
    Cart "1" --> "1" CartStatus
```

### 3. Order 聚合

```mermaid
classDiagram
    class Order {
        <<Aggregate Root>>
        +String id
        +String userId
        +List~OrderItem~ items
        +BigDecimal totalAmount
        +OrderStatus status
        +PaymentInfo paymentInfo
        +ShippingInfo shippingInfo
        +Instant createdAt
        +create()
        +pay()
        +ship()
        +deliver()
        +cancel()
        +refund()
    }
    
    class OrderItem {
        <<Entity>>
        +String productId
        +String productName
        +Integer quantity
        +BigDecimal unitPrice
        +BigDecimal totalPrice
        +String productSnapshot
    }
    
    class OrderStatus {
        <<Value Object>>
        +StatusType type
        +Instant changedAt
        +String reason
        +canTransitionTo(newStatus)
    }
    
    class PaymentInfo {
        <<Value Object>>
        +String method
        +String transactionId
        +BigDecimal amount
        +String currency
        +PaymentStatus status
    }
    
    class ShippingInfo {
        <<Value Object>>
        +Address address
        +String carrier
        +String trackingNumber
        +Instant estimatedDelivery
    }
    
    Order "1" --> "*" OrderItem
    Order "1" --> "1" OrderStatus
    Order "1" --> "1" PaymentInfo
    Order "1" --> "1" ShippingInfo
```

### 4. User 聚合

```mermaid
classDiagram
    class User {
        <<Aggregate Root>>
        +String id
        +Email email
        +String username
        +Password password
        +UserProfile profile
        +Set~Role~ roles
        +Boolean isActive
        +register()
        +authenticate()
        +updateProfile()
        +changePassword()
        +deactivate()
    }
    
    class UserProfile {
        <<Value Object>>
        +String firstName
        +String lastName
        +String phone
        +Address address
        +Instant birthDate
    }
    
    class Email {
        <<Value Object>>
        +String value
        +Boolean verified
        +validate()
        +sendVerification()
    }
    
    class Password {
        <<Value Object>>
        +String hash
        +String salt
        +verify(plainPassword)
        +meetsCriteria(plainPassword)
    }
    
    class Role {
        <<Value Object>>
        +String name
        +Set~Permission~ permissions
        +hasPermission(permission)
    }
    
    User "1" --> "1" UserProfile
    User "1" --> "1" Email
    User "1" --> "1" Password
    User "1" --> "*" Role
```

## 領域事件（Domain Events）

```mermaid
graph LR
    subgraph "產品事件"
        ProductCreated[產品建立]
        ProductUpdated[產品更新]
        ProductDeleted[產品刪除]
        StockUpdated[庫存更新]
        PriceChanged[價格變更]
    end
    
    subgraph "購物車事件"
        ItemAddedToCart[商品加入購物車]
        ItemRemovedFromCart[商品移除購物車]
        CartCleared[購物車清空]
        CartExpired[購物車過期]
    end
    
    subgraph "訂單與支付事件"
        OrderCreated[訂單建立]
        OrderPaid[訂單支付]
        OrderShipped[訂單出貨]
        OrderDelivered[訂單送達]
        OrderCancelled[訂單取消]
        OrderRefunded[訂單退款]
        PaymentSucceeded[支付成功]
        PaymentFailed[支付失敗]
        WebhookEventReceived[Webhook 事件收到]
    end
    
    subgraph "Saga 協調事件"
        SagaStarted[Saga 開始]
        SagaStepCompleted[Saga 步驟完成]
        SagaStepFailed[Saga 步驟失敗]
        SagaCompleted[Saga 完成]
        SagaCompensated[Saga 補償]
    end
    
    WebhookEventReceived --> PaymentSucceeded
    WebhookEventReceived --> PaymentFailed
    PaymentSucceeded --> OrderPaid
    SagaStarted --> OrderCreated
    SagaStepCompleted --> OrderPaid
    SagaStepFailed --> SagaCompensated
    subgraph "使用者事件"
        UserRegistered[使用者註冊]
        UserLoggedIn[使用者登入]
        UserProfileUpdated[資料更新]
        PasswordChanged[密碼變更]
    end
```

## 領域服務（Domain Services）

### 1. 庫存服務
```java
public interface InventoryService {
    boolean checkAvailability(String productId, int quantity);
    void reserveStock(String productId, int quantity);
    void releaseStock(String productId, int quantity);
    void updateStock(String productId, int adjustment);
}
```

### 2. 定價服務
```java
public interface PricingService {
    BigDecimal calculatePrice(Product product, int quantity);
    BigDecimal applyDiscount(BigDecimal price, Discount discount);
    BigDecimal calculateTax(BigDecimal price, Address address);
    BigDecimal calculateShipping(List<OrderItem> items, Address address);
}
```

### 3. 支付服務
```java
public interface PaymentService {
    PaymentResult processPayment(Order order, PaymentMethod method);
    RefundResult processRefund(Order order, BigDecimal amount);
    PaymentStatus checkPaymentStatus(String transactionId);
}
```

### 4. Saga 編排服務
```java
public interface SagaOrchestrationService {
    CompletableFuture<SagaResult> processOrderSaga(OrderCreationRequest request);
    void compensateOrderSaga(String sagaId, SagaStep failedStep);
    SagaState getSagaState(String sagaId);
}
```

## 倉儲介面（Repository Interfaces）

### 1. 產品倉儲
```java
public interface ProductRepository {
    // 基本 CRUD
    Product findById(String id);
    List<Product> findAll(Pageable pageable);
    Product save(Product product);
    void delete(String id);
    
    // 領域特定查詢
    List<Product> findByCategory(String categoryId);
    List<Product> findByPriceRange(BigDecimal min, BigDecimal max);
    List<Product> searchByName(String keyword);
    boolean existsBySku(String sku);
}
```

### 2. 訂單倉儲
```java
public interface OrderRepository {
    Order findById(String id);
    List<Order> findByUserId(String userId);
    List<Order> findByStatus(OrderStatus status);
    Order save(Order order);
    
    // 統計查詢
    BigDecimal getTotalSalesByDateRange(LocalDate start, LocalDate end);
    List<Order> findPendingOrders();
}
```

## 限界上下文（Bounded Contexts）

```mermaid
graph TB
    subgraph "產品上下文"
        PM[產品管理]
        CAT[分類管理]
        INV[庫存管理]
    end
    
    subgraph "銷售上下文"
        CART[購物車]
        ORDER[訂單]
        PROMO[促銷]
        SAGA[Saga 編排器]
    end
    
    subgraph "支付上下文"
        PAY[支付處理]
        REF[退款處理]
        TRANS[交易記錄]
    end
    
    subgraph "使用者上下文"
        USER[使用者管理]
        AUTH[認證授權]
        PROF[個人資料]
    end
    
    CART --> PM
    ORDER --> CART
    SAGA --> ORDER
    SAGA --> PAY
    SAGA --> INV
    PAY --> TRANS
    USER --> AUTH
```

## 防腐層（Anti-Corruption Layer）

### 外部服務整合
```java
// Stripe 支付整合防腐層
public class StripePaymentAdapter implements PaymentService {
    private final StripeClient stripeClient;
    
    @Override
    public PaymentResult processPayment(Order order, PaymentMethod method) {
        // 將領域模型轉換為 Stripe API 格式
        StripePaymentRequest request = convertToStripeFormat(order, method);
        StripeResponse response = stripeClient.createPayment(request);
        // 將 Stripe 回應轉換回領域模型
        return convertToDomainModel(response);
    }
}

// OAuth 認證整合防腐層
public class OAuthAdapter implements AuthenticationService {
    private final GoogleOAuthClient googleClient;
    private final GitHubOAuthClient githubClient;
    
    public AuthResult authenticate(OAuthProvider provider, String code) {
        // 統一不同 OAuth 提供者的介面
        switch (provider) {
            case GOOGLE:
                return adaptGoogleAuth(googleClient.authenticate(code));
            case GITHUB:
                return adaptGitHubAuth(githubClient.authenticate(code));
            default:
                throw new UnsupportedProviderException(provider);
        }
    }
}
```

## 領域規則與不變量（Invariants）

### 業務規則
1. **產品庫存規則**：庫存數量不能為負數
2. **購物車規則**：購物車商品總數不能超過 100 件
3. **訂單規則**：訂單總金額必須大於 0
4. **價格規則**：產品價格必須大於 0
5. **使用者規則**：Email 必須唯一

### 狀態轉換規則
```mermaid
stateDiagram-v2
    [*] --> Created: 建立訂單
    Created --> Paid: 支付成功
    Created --> Cancelled: 取消訂單
    Paid --> Processing: 開始處理
    Processing --> Shipped: 出貨
    Shipped --> Delivered: 送達
    Delivered --> [*]
    Paid --> Refunded: 退款
    Refunded --> [*]
    Cancelled --> [*]
```

---

最後更新：2025-08-20
