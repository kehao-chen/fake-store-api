# 資料庫架構設計

本文件說明 Fake Store API 的資料庫架構設計。完整的資料庫定義請參考 [database 目錄](../../database/)。

## 概覽

Fake Store API 使用 PostgreSQL 作為主要資料庫，採用以下設計原則：

- **正規化設計**：遵循第三正規化形式（3NF）
- **效能最佳化**：策略性索引和分區設計
- **資料完整性**：完整的外鍵約束和檢查約束
- **稽核追蹤**：所有表都包含 created_at 和 updated_at

## 核心資料表

### 1. 使用者相關
- `users` - 使用者主表
- `user_oauth_providers` - OAuth 提供者整合

### 2. 產品目錄
- `products` - 產品資料
- `categories` - 產品分類

### 3. 購物與訂單
- `carts` - 購物車
- `cart_items` - 購物車項目
- `orders` - 訂單
- `order_items` - 訂單項目

### 4. 認證授權
- `oauth_clients` - OAuth 2.0 客戶端
- `api_keys` - 使用者 API Key（僅儲存雜湊與前綴）

### 5. 支付與對賬
- `payments` - 支付記錄（intent_id/session_id、狀態、amount、currency、order_id、last_event_id、paid_at）

## 資料庫設計文件

完整的資料庫設計使用 DBML（Database Markup Language）撰寫：

- **[資料庫結構定義](../../database/schema.dbml)** - 完整的表結構定義
- **[索引策略](../../database/indexes.dbml)** - 效能最佳化索引
- **[觸發器與函數](../../database/triggers.dbml)** - 自動化邏輯
- **[關聯設計](../../database/relationships.md)** - 實體關聯說明
- **[分區策略](../../database/partitioning-strategy.md)** - 大規模資料處理

## 關鍵設計模式

### 1. 價格快照模式
購物車和訂單項目都保存產品價格快照，確保價格變動不影響已存在的購物車和訂單。

```sql
-- 購物車項目
cart_items.unit_price  -- 加入購物車時的價格

-- 訂單項目
order_items.unit_price -- 下單時的最終價格
```

### 2. 軟刪除模式
重要資料表支援軟刪除，保留資料完整性：

```sql
products.is_active
users.is_active
categories.is_active
```

### 3. 互斥擁有者模式
購物車支援已認證使用者和訪客：

```sql
-- user_id 和 session_id 必須有且只有一個
CHECK ((user_id IS NOT NULL AND session_id IS NULL) OR 
       (user_id IS NULL AND session_id IS NOT NULL))
```

### 4. API Key 儲存模式
- 只儲存 Key 雜湊與前綴；完整 Key 僅在建立時回傳。
- 欄位建議：`id`、`user_id`、`name`、`prefix`、`key_hash`、`last_used_at`、`created_at`、`revoked_at`。

## 效能考量

### 1. 索引策略
- 主鍵索引（自動）
- 外鍵索引（關聯查詢）
- 業務查詢索引（email、username、status）
- 全文搜尋索引（產品名稱和描述）

### 2. 分區設計
- 訂單表按月分區
- 活動日誌按日分區
- 產品表按分類雜湊分區

### 3. 查詢最佳化
- 使用部分索引減少索引大小
- 適當的反正規化（如訂單中的產品快照）
- 連線池管理

## 資料遷移

### 初始化腳本
```bash
# 從 DBML 生成 SQL
dbml2sql database/schema.dbml --postgres -o init.sql

# 執行初始化
psql -U postgres -d fakestore -f init.sql
```

### 版本控制
所有資料庫變更都通過 DBML 檔案進行版本控制，確保變更可追蹤。

## 監控與維護

### 1. 效能監控
- 慢查詢日誌
- 索引使用率分析
- 表膨脹監控

### 2. 定期維護
- VACUUM 和 ANALYZE
- 索引重建
- 分區清理

## 相關文件

- [C4 架構模型](./c4-model.md) - 系統整體架構
- [DDD 領域模型](./ddd-model.md) - 領域驅動設計
- [資料流程圖](./data-flow.md) - 資料流動說明
