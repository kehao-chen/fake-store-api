# 資料流程圖

本文件描述 Fake Store API 系統中的資料流動模式和處理流程。

## 整體資料流架構

```mermaid
graph TB
    subgraph "資料輸入層"
        API[REST API 請求]
        Webhook[Webhook 事件]
        Admin[管理介面]
        Batch[批次匯入]
    end
    
    subgraph "資料驗證層"
        Validation[輸入驗證]
        Sanitization[資料清理]
        Authorization[權限檢查]
    end
    
    subgraph "業務處理層"
        BusinessLogic[業務邏輯]
        EventPublisher[事件發布]
        Workflow[工作流程]
    end
    
    subgraph "資料持久層"
        PostgreSQL[(PostgreSQL<br/>主資料庫)]
        Valkey[(Valkey<br/>快取層)]
        EventStore[(事件儲存)]
    end
    
    subgraph "資料輸出層"
        APIResponse[API 回應]
        Notification[通知推送]
        Analytics[分析報表]
        Export[資料匯出]
    end
    
    API --> Validation
    Webhook --> Validation
    Admin --> Validation
    Batch --> Validation
    
    Validation --> Sanitization
    Sanitization --> Authorization
    Authorization --> BusinessLogic
    
    BusinessLogic --> PostgreSQL
    BusinessLogic --> Valkey
    BusinessLogic --> EventPublisher
    
    EventPublisher --> EventStore
    EventPublisher --> Workflow
    
    PostgreSQL --> APIResponse
    Valkey --> APIResponse
    EventStore --> Analytics
    PostgreSQL --> Export
    
    Workflow --> Notification
```

## 核心業務流程

### 1. 產品查詢流程

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant Cache as Valkey Cache
    participant Service as Product Service
    participant DB as PostgreSQL
    
    Client->>Gateway: GET /v1/products?filter=...
    Gateway->>Gateway: 限流檢查
    Gateway->>Cache: 查詢快取
    
    alt 快取命中
        Cache-->>Gateway: 返回快取資料
        Gateway-->>Client: 200 OK (from cache)
    else 快取未命中
        Gateway->>Service: 轉發請求
        Service->>DB: 查詢資料庫
        DB-->>Service: 產品資料
        Service->>Service: 資料處理與轉換
        Service->>Cache: 更新快取
        Service-->>Gateway: 產品列表
        Gateway-->>Client: 200 OK
    end
```

### 2. 訂單建立流程

```mermaid
sequenceDiagram
    participant User
    participant API
    participant CartService
    participant OrderService
    participant InventoryService
    participant PaymentService
    participant EventBus
    participant DB
    
    User->>API: POST /v1/orders
    API->>API: JWT 驗證
    API->>CartService: 獲取購物車
    CartService->>DB: 查詢購物車項目
    DB-->>CartService: 購物車資料
    
    CartService->>InventoryService: 檢查庫存
    InventoryService->>DB: 查詢庫存
    
    alt 庫存充足
        InventoryService->>DB: 預留庫存
        InventoryService-->>CartService: 庫存確認
        
        CartService->>OrderService: 建立訂單
        OrderService->>DB: 儲存訂單
        
        OrderService->>PaymentService: 發起支付
        PaymentService->>PaymentService: 建立支付會話
        
        OrderService->>EventBus: 發布 OrderCreated 事件
        OrderService-->>API: 訂單建立成功
        API-->>User: 201 Created
    else 庫存不足
        InventoryService-->>CartService: 庫存不足錯誤
        CartService-->>API: 422 Unprocessable Entity
        API-->>User: 庫存不足提示
    end
```

### 3. 使用者認證流程

```mermaid
flowchart LR
    Start([開始]) --> Input{輸入類型?}
    
    Input -->|帳號密碼| PasswordFlow[密碼驗證流程]
    Input -->|OAuth| OAuthFlow[OAuth 流程]
    
    PasswordFlow --> ValidateCredentials[驗證憑證]
    ValidateCredentials --> CheckUser{使用者存在?}
    
    CheckUser -->|是| VerifyPassword[驗證密碼]
    CheckUser -->|否| AuthFailed[認證失敗]
    
    VerifyPassword --> PasswordMatch{密碼正確?}
    PasswordMatch -->|是| GenerateToken[產生 JWT]
    PasswordMatch -->|否| AuthFailed
    
    OAuthFlow --> RedirectProvider[重導向到提供者]
    RedirectProvider --> ProviderAuth[提供者認證]
    ProviderAuth --> Callback[回調處理]
    Callback --> CreateOrUpdate[建立或更新使用者]
    CreateOrUpdate --> GenerateToken
    
    GenerateToken --> StoreSession[儲存會話]
    StoreSession --> Success[認證成功]
    
    AuthFailed --> End([結束])
    Success --> End
```

### 4. 支付流程（雙軌）

```mermaid
sequenceDiagram
    autonumber
    participant FE as Front-end
    participant API as Fake Store API
    participant STR as Stripe

    rect rgb(233,244,255)
    note right of FE: PaymentIntent 模式
    FE->>API: POST /v1/payments
    API-->>FE: 201 { payment_intent.client_secret }
    FE->>STR: confirm with client_secret (3DS/SCA)
    end

    rect rgb(233,255,240)
    note right of FE: Checkout 模式
    FE->>API: POST /v1/payments:createCheckoutSession { success_url, cancel_url }
    API-->>FE: 201 { checkout_url, session_id }
    FE->>STR: Redirect to checkout_url
    end

    STR-->>API: Webhook (payment_intent.succeeded | checkout.session.completed)
    API->>API: Idempotent handle (by event.id)
    API->>API: Update order status (pending → paid)
```

### 5. Saga 編排（含補償）

```mermaid
sequenceDiagram
  autonumber
  participant SO as Saga Orchestrator
  participant OS as 訂單服務
  participant IS as 庫存服務
  participant PS as 支付服務

  SO->>OS: CreateOrder
  OS-->>SO: OrderCreated
  SO->>IS: ReserveInventory
  alt 庫存不足
    IS-->>SO: InventoryNotAvailable
    SO->>OS: CancelOrder (補償)
    SO-->>SO: Saga 結束（FAILED/COMPENSATED）
  else 庫存充足
    IS-->>SO: InventoryReserved
    SO->>PS: ProcessPayment (發起)
    alt 支付失敗
      PS-->>SO: PaymentFailed
      SO->>IS: ReleaseInventory (補償)
      SO->>OS: CancelOrder (補償)
      SO-->>SO: Saga 結束（FAILED/COMPENSATED）
    else 支付成功
      PS-->>SO: PaymentProcessed
      SO->>OS: ConfirmOrder
      OS-->>SO: OrderConfirmed
      SO-->>SO: Saga 結束（COMPLETED）
    end
  end
```

## 資料快取策略

### 快取層級架構

```mermaid
graph TB
    subgraph "L1 Cache - Application"
        LocalCache[本地快取<br/>Caffeine]
    end
    
    subgraph "L2 Cache - Distributed"
        Valkey[Valkey 分散式快取]
    end
    
    subgraph "L3 Storage - Database"
        PostgreSQL[(PostgreSQL)]
    end
    
    Request[請求] --> LocalCache
    LocalCache -->|未命中| Valkey
    Valkey -->|未命中| PostgreSQL
    
    PostgreSQL -->|資料| Valkey
    Valkey -->|資料| LocalCache
    LocalCache -->|資料| Request
```

### 快取更新策略

```mermaid
graph LR
    subgraph "寫入策略"
        WriteThrough[Write-Through<br/>同步寫入]
        WriteBehind[Write-Behind<br/>非同步寫入]
        WriteAround[Write-Around<br/>繞過快取]
    end
    
    subgraph "失效策略"
        TTL[TTL 過期]
        LRU[LRU 淘汰]
        Manual[手動失效]
    end
    
    subgraph "更新觸發"
        Create[建立]
        Update[更新]
        Delete[刪除]
    end
    
    Create --> WriteThrough
    Update --> WriteBehind
    Delete --> Manual
    
    WriteThrough --> TTL
    WriteBehind --> LRU
    WriteAround --> Manual
```

## 事件驅動資料流

### 事件發布訂閱模式

```mermaid
graph TB
    subgraph "事件生產者"
        OrderService[訂單服務]
        ProductService[產品服務]
        UserService[使用者服務]
    end
    
    subgraph "事件匯流排"
        EventBus[Spring Event Bus]
        EventStore[(事件儲存)]
    end
    
    subgraph "事件消費者"
        NotificationHandler[通知處理器]
        InventoryHandler[庫存處理器]
        AnalyticsHandler[分析處理器]
        AuditHandler[審計處理器]
    end
    
    OrderService -->|OrderCreated| EventBus
    ProductService -->|ProductUpdated| EventBus
    UserService -->|UserRegistered| EventBus
    
    EventBus --> EventStore
    
    EventBus --> NotificationHandler
    EventBus --> InventoryHandler
    EventBus --> AnalyticsHandler
    EventBus --> AuditHandler
```

### 事件處理流程

```mermaid
sequenceDiagram
    participant Service
    participant EventBus
    participant EventStore
    participant Handler1
    participant Handler2
    participant DeadLetter
    
    Service->>EventBus: 發布事件
    EventBus->>EventStore: 持久化事件
    
    par 並行處理
        EventBus->>Handler1: 分發事件
        Handler1->>Handler1: 處理邏輯
        Handler1-->>EventBus: 處理完成
    and
        EventBus->>Handler2: 分發事件
        Handler2->>Handler2: 處理邏輯
        Handler2-->>EventBus: 處理失敗
    end
    
    EventBus->>EventBus: 重試失敗處理
    
    alt 重試成功
        EventBus->>Handler2: 重新分發
        Handler2-->>EventBus: 處理完成
    else 重試失敗
        EventBus->>DeadLetter: 移至死信佇列
    end
```

## 資料同步機制

### 快取與資料庫同步

```mermaid
graph TB
    subgraph "寫入操作"
        Write[寫入請求] --> Transaction[開始交易]
        Transaction --> UpdateDB[更新資料庫]
        UpdateDB --> InvalidateCache[失效快取]
        InvalidateCache --> Commit[提交交易]
    end
    
    subgraph "讀取操作"
        Read[讀取請求] --> CheckCache{快取存在?}
        CheckCache -->|是| ReturnCache[返回快取]
        CheckCache -->|否| QueryDB[查詢資料庫]
        QueryDB --> UpdateCache[更新快取]
        UpdateCache --> ReturnData[返回資料]
    end
    
    subgraph "背景同步"
        Scheduler[排程器] --> SyncJob[同步任務]
        SyncJob --> CompareData[比對資料]
        CompareData --> UpdateStale[更新過期資料]
    end
```

## 資料安全流程

### 敏感資料處理

```mermaid
graph TB
    subgraph "輸入階段"
        Input[原始輸入] --> Validate[驗證]
        Validate --> Sanitize[清理]
    end
    
    subgraph "處理階段"
        Sanitize --> Encrypt[加密敏感資料]
        Encrypt --> Process[業務處理]
        Process --> Audit[審計記錄]
    end
    
    subgraph "儲存階段"
        Audit --> HashPII[雜湊 PII]
        HashPII --> Store[(儲存)]
    end
    
    subgraph "輸出階段"
        Store --> Retrieve[讀取]
        Retrieve --> Decrypt[解密]
        Decrypt --> Mask[遮罩處理]
        Mask --> Output[輸出]
    end
```

### 資料存取控制

```mermaid
graph LR
    subgraph "存取控制層"
        Request[請求] --> Auth[認證]
        Auth --> Authz[授權]
        Authz --> RBAC[角色檢查]
        RBAC --> DataFilter[資料過濾]
    end
    
    subgraph "資料層"
        DataFilter --> Query[查詢]
        Query --> RowLevel[行級安全]
        RowLevel --> ColumnLevel[列級安全]
        ColumnLevel --> Result[結果]
    end
    
    Result --> Response[回應]
```

## 效能優化策略

### 查詢優化流程

```mermaid
graph TB
    Query[查詢請求] --> Parser[解析器]
    Parser --> Optimizer[優化器]
    
    Optimizer --> IndexCheck{使用索引?}
    IndexCheck -->|是| IndexScan[索引掃描]
    IndexCheck -->|否| FullScan[全表掃描]
    
    IndexScan --> Cache{可快取?}
    FullScan --> Cache
    
    Cache -->|是| CacheResult[快取結果]
    Cache -->|否| ReturnDirect[直接返回]
    
    CacheResult --> Response[回應]
    ReturnDirect --> Response
```

### 批次處理流程

```mermaid
graph TB
    subgraph "批次收集"
        Request1[請求1] --> Queue[請求佇列]
        Request2[請求2] --> Queue
        Request3[請求3] --> Queue
    end
    
    subgraph "批次處理"
        Queue --> Batch[批次組裝]
        Batch --> BulkOp[批量操作]
        BulkOp --> DB[(資料庫)]
    end
    
    subgraph "結果分發"
        DB --> Results[批次結果]
        Results --> Split[結果拆分]
        Split --> Response1[回應1]
        Split --> Response2[回應2]
        Split --> Response3[回應3]
    end
```

---

最後更新：2025-08-20
