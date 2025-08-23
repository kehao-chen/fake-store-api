# 效能調校

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

## 快取策略（API/資料）
- API 回應快取：對可公開之列表/詳情（不含個資）回應加上 `Cache-Control: public, max-age=300`（產品列表、分類列表）。
- Valkey（L2）快取：
  - 熱門產品詳情 TTL 5~10 分鐘；商品變更時主動失效對應鍵。
  - 列表查詢可快取分頁片段（filter+order_by+page_key 為快取鍵），TTL 60~120 秒。
- 本地快取（L1）：使用 Caffeine 於應用層快取 hot keys，TTL 5~30 秒，減少跨網路延遲。

## 批次介面（降低 N+1）
- 使用 `/v1/products:batchGet`、`/v1/products:batchUpdate`（AIP-136）聚合請求，降低 round-trips 與 DB 負載。
- 在 UI/SDK 層合併並行請求，寧可數次 batch 而非大量單筆。

## WebFlux 與連線池
- Reactor 線程模型：確保阻塞 I/O（外部 HTTP/DB driver 若有）包裹於專用 Scheduler，避免阻塞 event loop。
- DB 連線池（R2DBC/HikariCP）：設定上限與等待時間，建議：
  - 4GB VM：max pool 15、idle 5、timeout 30s。
  - 8GB VM：max pool 30、idle 10、timeout 30s。

## JVM 與容器資源
- JVM：以容器感知（UseContainerSupport），啟用 G1/SHENANDOAH（依 JDK 版本）。
- 記憶體：預留 20% 給 OS/快取；避免 OOM（限制 `-Xmx` < 容器 memory limit）。
- CPU：適度提升 parallelism，避免在高負載下 context switch 過多。

## 負載測試與目標
- 工具：JMeter 或 k6，腳本覆蓋核心路徑（產品列表/詳情、購物車、下單、支付）。
- 指標：P95 < 500ms；在 100 QPS 持續負載下維持錯誤率 < 1%。
- 場景：
  - 冷啟動/暖機後各 10 分鐘。
  - 快取命中/未命中混合。
  - 批次介面 vs 單筆對照。

## 觀測性
- 指標：
  - API latency（p50/p95/p99）、error rate、RPS、GC 次數/停頓
  - DB：慢查詢、連線池使用率
  - 快取：命中率、eviction 次數
- 日誌：結合 `X-Request-ID`、trace-id 與關鍵商務欄位（order_id/payment_intent_id）。
