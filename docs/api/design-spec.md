# API 設計規格

[← 返回文件中心](../README.md) | [API 文件](../api/) | **設計規格**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-23
- **目標讀者**: 開發者、API 設計師、前端工程師
- **相關文件**:
  - [功能需求](../requirements/functional.md)
  - [認證授權](./authentication.md)
  - [錯誤處理](./error-handling.md)
  - [OpenAPI 規範](../../openapi/)

## 設計原則

本 API 遵循 **Google API Improvement Proposals (AIP)** 標準，確保一致性、可擴展性和開發者友好性。

### 核心原則
- **一致性**: 統一的命名慣例和結構模式
- **可預測性**: 符合 RESTful 設計和 HTTP 語義
- **向後相容**: API 版本管理確保穩定性
- **開發者友好**: 清晰的文檔和錯誤訊息

## API 版本管理

### URL 版本控制
```
https://api.fakestore.example.com/v1/products
```

### 版本策略
- **v1**: 當前穩定版本
- **向後相容**: 同版本內保證向後相容
- **棄用政策**: 舊版本至少維護 12 個月

## 認證與授權

### 支援的認證方式
1. **JWT Bearer Token**
   ```
   Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
   ```

2. **API Key**
   ```
   Authorization: Bearer fsk_live_12345abcdef...
   ```

### 權限模型
- **Public**: 無需認證的端點
- **User**: 需要使用者認證
- **Admin**: 需要管理員權限

## 請求與回應格式

### 內容類型
- **請求**: `application/json`
- **回應**: `application/json`
- **字符編碼**: UTF-8

### 標準請求標頭
```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>
X-Request-ID: uuid (可選，用於追蹤)
```

### 標準回應標頭
```http
Content-Type: application/json; charset=utf-8
X-Request-ID: <request-id>
X-Response-Time: <response-time-ms>
Cache-Control: <cache-policy>
```

## AIP 標準實作

### AIP-132: 標準方法 - List

**格式**: `GET /v1/{collection}`

**範例**: `GET /v1/products`

**查詢參數**:
- `page_size`: 每頁項目數 (1-100，預設 20)
- `page_token`: 分頁令牌
- `filter`: 篩選條件 (AIP-160 格式)
- `order_by`: 排序規則

**回應格式**:
```json
{
  "products": [
    {
      "id": "prod_12345",
      "name": "無線耳機",
      "price": "99.99",
      "created_at": "2025-01-20T10:00:00Z"
    }
  ],
  "next_page_token": "eyJvZmZzZXQiOjIwfQ==",
  "total_size": 150
}
```

### AIP-131: 標準方法 - Get

**格式**: `GET /v1/{collection}/{id}`

**範例**: `GET /v1/products/prod_12345`

**回應格式**:
```json
{
  "id": "prod_12345",
  "name": "無線耳機",
  "description": "高品質藍牙耳機",
  "price": "99.99",
  "category_id": "cat_electronics",
  "image_url": "https://cdn.example.com/product.jpg",
  "stock_quantity": 150,
  "is_active": true,
  "created_at": "2025-01-20T10:00:00Z",
  "updated_at": "2025-01-22T15:30:00Z"
}
```

### AIP-133: 標準方法 - Create

**格式**: `POST /v1/{collection}`

**範例**: `POST /v1/products`

**請求格式**:
```json
{
  "name": "新產品",
  "description": "產品描述",
  "price": "199.99",
  "category_id": "cat_electronics",
  "stock_quantity": 100
}
```

**回應**: 201 Created + 完整資源物件

### AIP-134: 標準方法 - Update

**格式**: `PATCH /v1/{collection}/{id}`

**範例**: `PATCH /v1/products/prod_12345?update_mask=name,price`

**請求格式**:
```json
{
  "name": "更新的產品名稱",
  "price": "149.99"
}
```

**重要特性**:
- 使用 `update_mask` 指定要更新的欄位
- 只更新指定欄位，其他欄位保持不變
- 回應包含完整的更新後資源

### AIP-135: 標準方法 - Delete

**格式**: `DELETE /v1/{collection}/{id}`

**範例**: `DELETE /v1/products/prod_12345`

**行為**: 軟刪除，標記 `is_active: false`
**回應**: 204 No Content

### AIP-136: 自訂方法

**格式**: `POST /v1/{collection}:{verb}` 或 `POST /v1/{resource}:{verb}`

**範例**:
```http
POST /v1/users/me/cart:clear
POST /v1/users/me/cart:checkout
POST /v1/payments:createCheckoutSession
```

## AIP-160 篩選語法詳解

### 支援欄位

#### Products 篩選
```
name, description, price, category_id, is_active, created_at, updated_at, stock_quantity
```

#### Users 篩選
```
email, username, is_active, created_at, updated_at, last_login_at
```

#### Categories 篩選
```
name, description, is_active, created_at, updated_at
```

#### Orders 篩選
```
status, total_amount, created_at, updated_at, user_id
```

### 運算子支援

| 運算子 | 說明 | 適用類型 | 範例 |
|--------|------|----------|------|
| `=` | 等於 | 所有 | `status="pending"` |
| `!=` | 不等於 | 所有 | `status!="cancelled"` |
| `>` | 大於 | 數值、日期 | `price>100` |
| `>=` | 大於等於 | 數值、日期 | `created_at>="2025-01-01T00:00:00Z"` |
| `<` | 小於 | 數值、日期 | `price<500` |
| `<=` | 小於等於 | 數值、日期 | `updated_at<="2025-12-31T23:59:59Z"` |
| `:` | 包含/模糊搜尋 | 字串 | `name:"wireless"` |

### 邏輯運算子
- `AND`: 邏輯且
- `OR`: 邏輯或
- `NOT`: 邏輯非
- `()`: 群組

### 篩選範例

#### 基本篩選
```http
GET /v1/products?filter=category_id="cat_electronics"
GET /v1/products?filter=price>50 AND price<200
GET /v1/products?filter=name:"wireless" OR description:"bluetooth"
```

#### 複雜篩選
```http
GET /v1/products?filter=(category_id="cat_electronics" OR category_id="cat_mobile") AND price<1000 AND is_active=true
```

#### 日期篩選
```http
GET /v1/orders?filter=created_at>="2025-01-01T00:00:00Z" AND created_at<="2025-01-31T23:59:59Z"
```

## 分頁機制

### 游標式分頁 (推薦)

**優點**: 效能穩定，適合大資料集

**Token 結構**:
```json
{
  "v": 1,
  "keys": {
    "created_at": "2025-01-20T10:00:00Z",
    "id": "prod_4d5e6f"
  },
  "order": "created_at desc",
  "filter_hash": "sha256:abc123...",
  "exp": 1737350400
}
```

**使用方式**:
```http
GET /v1/products?page_size=20
GET /v1/products?page_size=20&page_token=eyJrZXlzIjp7fX0=
```

### Offset 分頁 (特殊情況)

僅在需要跳轉到特定頁面時使用：
```http
GET /v1/products?page_size=20&offset=40
```

## 排序規則

### order_by 語法
```
order_by=field1 [asc|desc][,field2 [asc|desc]]...
```

### 範例
```http
GET /v1/products?order_by=price desc
GET /v1/products?order_by=category_id asc,created_at desc
GET /v1/products?order_by=name  # 預設為 asc
```

### 預設排序
- 大多數資源: `created_at desc`
- 列表資源: 按名稱或標題排序

## 錯誤處理

### 錯誤格式 (AIP-193)
```json
{
  "error": {
    "code": "INVALID_ARGUMENT",
    "message": "Request contains invalid arguments",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.BadRequest",
        "field_violations": [
          {
            "field": "filter",
            "description": "Unknown field 'invalid_field' in filter expression"
          }
        ]
      }
    ]
  }
}
```

### 常見錯誤碼
- `INVALID_ARGUMENT`: 請求參數錯誤
- `NOT_FOUND`: 資源不存在
- `PERMISSION_DENIED`: 權限不足
- `UNAUTHENTICATED`: 認證失敗
- `RESOURCE_EXHAUSTED`: 超出限制

## 速率限制

### 限制策略
- **未認證**: 100 req/hour
- **已認證使用者**: 1000 req/hour
- **API Key**: 5000 req/hour
- **管理員**: 10000 req/hour

### 限制標頭
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
X-RateLimit-Window: 3600
```

### 超限回應
```http
HTTP/1.1 429 Too Many Requests
Retry-After: 3600

{
  "error": {
    "code": "RESOURCE_EXHAUSTED",
    "message": "API rate limit exceeded"
  }
}
```

## 快取策略

### 快取標頭
```http
Cache-Control: public, max-age=300
ETag: "abc123"
Last-Modified: Wed, 21 Jan 2025 10:00:00 GMT
```

### 快取政策
- **產品列表**: 5 分鐘
- **產品詳情**: 15 分鐘
- **分類列表**: 1 小時
- **使用者資料**: 不快取

## API 端點總覽

### 產品管理
```http
GET    /v1/products                    # 產品列表
GET    /v1/products/{id}               # 產品詳情
POST   /v1/products                    # 建立產品 [Admin]
PATCH  /v1/products/{id}               # 更新產品 [Admin]
DELETE /v1/products/{id}               # 刪除產品 [Admin]
POST   /v1/products:batchGet          # 批量取得
```

### 分類管理
```http
GET    /v1/categories                  # 分類列表
GET    /v1/categories/{id}             # 分類詳情
GET    /v1/categories/{id}/products    # 分類下的產品
POST   /v1/categories                  # 建立分類 [Admin]
PATCH  /v1/categories/{id}             # 更新分類 [Admin]
```

### 認證授權
```http
POST   /v1/auth/login                  # 登入
POST   /v1/auth/refresh                # 刷新 Token
GET    /v1/auth/google                 # Google OAuth
GET    /v1/auth/google/callback        # OAuth 回調
```

### 使用者管理
```http
GET    /v1/users/me                    # 個人資料 [Auth]
PATCH  /v1/users/me                    # 更新資料 [Auth]
GET    /v1/users                       # 使用者列表 [Admin]
GET    /v1/users/{id}                  # 使用者詳情 [Admin]
```

### 購物車
```http
GET    /v1/users/me/cart               # 查看購物車 [Auth]
POST   /v1/users/me/cart/items         # 加入商品 [Auth]
PATCH  /v1/users/me/cart/items/{id}    # 更新數量 [Auth]
DELETE /v1/users/me/cart/items/{id}    # 移除商品 [Auth]
POST   /v1/users/me/cart:clear         # 清空購物車 [Auth]
POST   /v1/users/me/cart:checkout      # 結帳 [Auth]
```

### 訂單管理
```http
GET    /v1/orders/me                   # 我的訂單 [Auth]
GET    /v1/orders/me/{id}              # 訂單詳情 [Auth]
GET    /v1/orders                      # 所有訂單 [Admin]
PATCH  /v1/orders/{id}                 # 更新狀態 [Admin]
```

### 支付處理
```http
POST   /v1/payments:createCheckoutSession    # 建立支付 [Auth]
POST   /v1/payments/webhook                  # Stripe Webhook
GET    /v1/payments/{id}/status              # 支付狀態 [Auth]
```

## 開發工具

### cURL 範例
```bash
# 取得產品列表
curl -X GET "https://api.fakestore.example.com/v1/products?page_size=10&filter=price<100" \
  -H "Accept: application/json"

# 建立產品
curl -X POST "https://api.fakestore.example.com/v1/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "新產品",
    "price": "99.99",
    "category_id": "cat_electronics"
  }'
```

### JavaScript SDK 範例
```javascript
// 使用 Fetch API
const response = await fetch('/v1/products?filter=category_id="cat_electronics"', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});

const data = await response.json();
```

## 測試環境

### Base URLs
- **生產環境**: `https://api.fakestore.com`
- **測試環境**: `https://api-staging.fakestore.com`
- **開發環境**: `http://localhost:8080`

### 測試資料
- 測試用 JWT Token: 提供預設的測試使用者認證
- 範例產品資料: 預載入的測試產品和分類
- Stripe 測試模式: 使用 Stripe 測試金鑰

## 相關文件

- [認證授權設計](./authentication.md) - 詳細認證流程
- [錯誤處理規範](./error-handling.md) - 錯誤代碼說明
- [版本控制策略](./versioning.md) - API 版本管理
- [OpenAPI 規範](../../openapi/) - 機器可讀的 API 定義
- [功能需求](../requirements/functional.md) - 業務功能說明

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-23*
