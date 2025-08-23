# 效能調校（骨架）

> TODO: 補充資料庫索引對應、快取策略、批次介面與負載測試策略。

## 查詢與索引對應（初稿）
- 產品列表：
  - 索引：`idx_products_category`, `idx_products_price`, `idx_products_created_at`, `idx_products_stock`（皆含 `deleted_at IS NULL`）
  - 建議排序：`created_at desc`（預設）
- 使用者查詢：
  - 索引：`idx_users_email`, `idx_users_username`（皆含 `deleted_at IS NULL`）
  - 唯一性：`uq_users_email_active`, `uq_users_username_active`（條件唯一）
- 分類查詢：
  - 索引：`idx_categories_name_active`, `idx_categories_active`（含 `deleted_at IS NULL`）
  - 唯一性：`uq_categories_name_active`（條件唯一）
- 訂單：
  - 索引：`idx_orders_user`, `idx_orders_status`, `idx_orders_created_at`

## 建議
- 將 `filter` 欄位白名單與索引欄位對齊，避免非索引欄位篩選導致全表掃描。
- `page_token` 游標包含排序鍵（如 `created_at`, `id`）以支援穩定分頁。
