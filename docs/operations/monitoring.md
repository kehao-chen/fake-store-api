# 監控與對賬（Monitoring & Reconciliation）

本文件說明支付事件（Stripe）與系統訂單狀態之間的對賬流程（reconciliation），並補充監控建議。

## Webhook 對賬背景（Context）
- 支付成功/失敗具強業務影響（是否出貨、是否退款），必須以外部事件為準。
- 即使客戶端流程失敗或中斷（網路、瀏覽器關閉），Stripe 仍會透過 Webhook 傳送最終狀態。
- 因此系統必須實作「事件最終一致性」：以 Webhook 事件更新訂單狀態，並確保冪等（同一事件多次送達也只處理一次）。
- 採雙軌：
  - PaymentIntent：監聽 `payment_intent.succeeded` / `payment_intent.payment_failed`。
  - Checkout：監聽 `checkout.session.completed`（可從 Session `metadata.order_id` 對應訂單，或透過 `payment_intent` 關聯）。

## 對賬流程（高階）
1. 建立支付：
   - PaymentIntent 模式：建立 Intent，回 `client_secret`，前端確認。
   - Checkout 模式：建立 Session，回 `checkout_url`，前端重導。
2. 建立訂單（建議）並把 `order_id` 放入 Stripe `metadata`。
3. 等待 Webhook：
   - 收到事件 → 以 `event.id` 做冪等性（事件表/快取）
   - 解析 `payment_intent` 或 `checkout.session` → 萃取 `order_id`
   - 更新訂單狀態：`pending → paid` 或失敗狀態
   - 記錄對賬日誌，必要時重試（退避重試）

## 冪等與重入（Idempotency）
- 使用事件 ID（`evt_...`）作為冪等鍵。
- 每筆事件只可成功處理一次；重複事件應快速返回（已處理）。
- 建議保存事件 payload 供稽核；失敗事件列入死信佇列，批次補償。

## 監控與告警建議
- 指標：
  - Webhook 處理成功/失敗次數與比例、處理延遲（p95）
  - 訂單狀態對賬落差（支付成功但訂單非 paid 的數量）
  - 重試次數、死信佇列深度
- Logs/Traces：關聯 `order_id`、`payment_intent_id`、`checkout.session_id`、`event.id`
- 告警：對賬落差超閾值、Webhook 連續失敗/重試堆積

### 支付/對賬自訂指標（補充）
- payments_webhook_events_total{type}：各類事件計數
- payments_webhook_process_duration_seconds{type, status}：處理延遲
- payments_webhook_idempotency_conflicts_total：與 `payments.last_event_id` 冪等衝突
- payments_reconciliation_failures_total：對賬失敗計數

> TODO: 補充 Prometheus 指標、Grafana 儀表板、Otel Traces 與告警策略細節。

## 支付/對賬專屬指標（落地清單）
- payments_total{status}：分狀態支付計數（pending/processing/succeeded/failed/canceled）
- payments_reconciled_total：成功對賬的支付事件數
- payments_reconcile_gap：支付成功但訂單未 paid 的數量（應接近 0）
- webhook_events_total{type,result}：各事件類型（payment_intent.succeeded / checkout.session.completed）與結果（ok/error）
- webhook_processing_latency_seconds{type,quantile}：處理延遲 P50/P95/P99
- webhook_retries_total：Webhook 重試總數
- payments_idempotency_hits_total：`last_event_id` 冪等命中次數

## 告警條件（建議，示例閾值）
- ReconcileGapHigh：`payments_reconcile_gap > 0` 持續 5 分鐘
- WebhookErrorRateHigh：`rate(webhook_events_total{result="error"}[5m]) / rate(webhook_events_total[5m]) > 0.05`
- WebhookLatencyHigh：`webhook_processing_latency_seconds{quantile="0.95"} > 2`
- IdempotencyMissSpike：`increase(payments_idempotency_hits_total[5m]) == 0` 且總事件數暴增（疑似重放/重試異常）

## Prometheus 抓取設定（範例）
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'fakestore-api'
    metrics_path: /actuator/prometheus
    static_configs:
      - targets: ['api:8081']

  - job_name: 'caddy'
    metrics_path: /metrics
    static_configs:
      - targets: ['caddy:2019']  # 需啟用 Caddy metrics 模組
```

注意：請在應用設定開啟 Prometheus 支援（Spring Actuator）：
- `management.endpoints.web.exposure.include=health,info,prometheus`
- `management.endpoint.prometheus.enabled=true`

## Grafana 儀表板建議
- API 延遲（p50/p95/p99）、RPS、錯誤率
- Webhook 事件成功率、處理延遲
- 對賬落差（payments_reconcile_gap）與支付狀態分佈
- DB 連線池使用率、慢查詢
- 快取命中率與 eviction 次數

可將上述指標組成單一 dashboard，以 `order_id/payment_intent_id/event.id` 為維度進行 drill-down。
