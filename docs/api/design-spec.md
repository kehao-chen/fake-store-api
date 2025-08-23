# API 設計規格（骨架）

> TODO: 補充 AIP-160 篩選語法、排序、分頁 token 設計與錯誤對應。

## AIP-160 查詢語法（草案）
- 支援欄位：
  - products: `name`, `price`, `category_id`, `is_active`, `created_at`, `updated_at`
  - users: `email`, `username`, `is_active`, `created_at`, `updated_at`
  - categories: `name`, `is_active`, `created_at`, `updated_at`
  - orders: `status`, `total_amount`, `created_at`, `updated_at`
- 運算子：=, !=, >, >=, <, <=, :（包含/全文，依欄位類型限制）
- 範例：
  - `category_id:"cat_electronics" AND price>50 AND price<200`
  - `name:"wireless" OR description:"mouse"`
- 錯誤對應：
  - 無效欄位/運算子 → `INVALID_ARGUMENT` + details.badRequest.field_violations
  - 解析失敗 → `INVALID_ARGUMENT`（field: filter）

### 互斥參數規則
- 軟刪除查詢：
  - `include_deleted=true` 僅用於擴增結果含已刪除資料（僅管理員）。
  - `only_deleted=true` 僅返回已刪除資料（僅管理員）。
  - 二者互斥，若同時為 true → `INVALID_ARGUMENT`（field: include_deleted / only_deleted）。

## 分頁 Token（草案）
- 格式：Base64 編碼的 JSON，包括：
  - `offset` 或 `cursor_keys`（如 created_at, id）
  - `order_by` / `filter_hash`（避免參數變更導致游標失效）
  - `ttl`（可選）
- 失效策略：排序或篩選變更時，token 視為無效。
- 錯誤：
  - token 解碼失敗 / 參數不匹配 → `INVALID_ARGUMENT`（field: page_token）
 
### 建議的游標結構（示例）
```json
{
  "v": 1,
  "keys": {"created_at": "2025-01-20T10:00:00Z", "id": "prod_4d5e6f"},
  "order": "created_at desc",
  "filter_hash": "sha256:abcd...",
  "exp": 1737350400
}
```

- 篩選語法（AIP-160）：
  - 支援欄位、運算子、大小寫、跳躍與跳脫規則
  - 錯誤對應：`INVALID_ARGUMENT` + details.badRequest.field_violations
- 排序 `order_by`：允許欄位清單與方向
- 分頁 token：格式、有效期、排序/過濾耦合策略與不可變性
- 安全與速率限制：全域與端點級策略
