# 非功能需求規範

[← 返回文件中心](../README.md) | [需求文件](../requirements/) | **非功能需求**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-20
- **目標讀者**: 架構師、開發者、DevOps 工程師
- **相關文件**: 
  - [功能需求](./functional.md)
  - [部署架構](../operations/deployment.md)
  - [監控系統](../operations/monitoring.md)

## 1. 效能需求 (Performance Requirements)

### 1.1 效能目標

針對單台 VM 主機（4-8GB 記憶體）的學習環境：

| 指標 | 目標值 | 測量方法 |
|------|--------|----------|
| **QPS (每秒查詢數)** | 100 QPS (持續), 300 QPS (峰值) | JMeter 負載測試 |
| **API 回應時間** | < 500ms (95th percentile) | Prometheus 監控 |
| **資料庫查詢時間** | < 300ms | 查詢日誌分析 |
| **併發使用者** | 500 名同時線上使用者 | 負載測試 |
| **資料處理能力** | 50萬產品記錄, 5萬使用者記錄 | 資料庫容量測試 |

### 1.2 容器資源分配

#### 4GB VM 配置（最小學習環境）
```yaml
services:
  api-service:
    resources:
      limits: { memory: 1G, cpus: '1.0' }
      reservations: { memory: 600M, cpus: '0.5' }
  
  postgresql:
    resources:
      limits: { memory: 1.5G, cpus: '0.8' }
      reservations: { memory: 1G, cpus: '0.4' }
  
  valkey-cache:
    resources:
      limits: { memory: 800M, cpus: '0.3' }
      reservations: { memory: 400M, cpus: '0.2' }
```

#### 8GB VM 配置（舒適學習環境）
```yaml
services:
  api-service:
    resources:
      limits: { memory: 2G, cpus: '2.0' }
      reservations: { memory: 1G, cpus: '0.8' }
  
  postgresql:
    resources:
      limits: { memory: 2.5G, cpus: '1.2' }
      reservations: { memory: 1.5G, cpus: '0.6' }
  
  valkey-cache:
    resources:
      limits: { memory: 1.5G, cpus: '0.5' }
      reservations: { memory: 800M, cpus: '0.3' }
```

### 1.3 效能監控指標

- **系統資源**: CPU 使用率 < 75%, 記憶體使用率 < 85%
- **資料庫連線池**: 最大 15 連線, 使用率 < 80%
- **快取命中率**: Valkey 快取命中率 > 80%
- **容器健康檢查**: 每個服務回應時間 < 10 秒

## 2. 安全性需求 (Security Requirements)

### 2.1 容器安全基線

```yaml
security_opt:
  - no-new-privileges:true
  - apparmor:docker-default

user: "1001:1001"  # 非 root 使用者執行

read_only: true     # 檔案系統保護
tmpfs:
  - /tmp
  - /var/cache

ulimits:           # 資源限制 (防止 DoS)
  nproc: 2048
  nofile: 4096
```

### 2.2 網路安全

- **容器網路隔離**: 自訂 Docker network, 禁用預設 bridge
- **Port 暴露最小化**: 僅暴露必要端口 (API: 8080, DB: 5432)
- **TLS 終止**: 使用 Caddy 作為反向代理 (自動 HTTPS 憑證)
- **內部通訊**: 容器間使用內部 DNS 名稱通訊

### 2.3 機密資料管理

- **環境變數**: 敏感配置透過 `.env` 檔案或 Docker secrets
- **資料庫認證**: 使用 Docker secrets 存儲密碼
- **API 金鑰**: Stripe 測試金鑰儲存在安全的環境變數中
- **JWT 簽章**: 使用強隨機金鑰, 定期輪換

### 2.4 存取控制 (RBAC)

- **API 權限**: 基於 JWT 聲明的細粒度權限控制
- **資料庫存取**: 應用程式專用資料庫使用者, 最小權限原則
- **容器執行**: 非特權模式執行, 禁用不必要的 Linux capabilities

## 3. 可用性需求 (Availability Requirements)

### 3.1 服務可用性目標

| 指標 | 目標值 | 說明 |
|------|--------|------|
| **SLA** | 99.5% | 學習環境適當目標, 約 3.6 小時/月停機 |
| **復原時間目標 (RTO)** | < 15 分鐘 | 服務復原時間 |
| **復原點目標 (RPO)** | < 1 小時 | 資料損失容忍度 |

### 3.2 健康檢查機制

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### 3.3 容器故障復原

- **自動重啟**: `restart: unless-stopped` 策略
- **優雅關閉**: SIGTERM 處理, 30 秒超時
- **資料持久化**: 資料庫和快取資料掛載到宿主機
- **備份策略**: 每日自動資料庫備份到本地目錄

## 4. 擴展性需求 (Scalability Requirements)

### 4.1 水平擴展準備

- **無狀態設計**: API 服務無狀態, session 資料存於 Valkey
- **資料庫最佳化**: 連線池管理, 查詢最佳化, 索引策略
- **快取分層**: 應用快取 + 資料庫查詢快取 + 靜態資源快取
- **負載均衡準備**: 支援多實例部署 (學習進階時使用)

### 4.2 垂直擴展指標

```yaml
scaling_thresholds:
  cpu_scale_up: 75%    # CPU 使用率超過 75% 持續 5 分鐘
  memory_scale_up: 85% # 記憶體使用率超過 85% 持續 5 分鐘  
  response_time: 600ms # 95th percentile 回應時間超過 600ms
```

## 5. 限流策略 (Rate Limiting)

### 5.1 限流配置

使用 Spring Cloud Gateway + Redis Rate Limiter + Valkey；依「金鑰 或 來源 IP」實施基礎速率限制：
- 具備 `Authorization: Bearer <token>` 者以「金鑰」為主（JWT 或 API Key 皆可作為限流鍵）。
- 無金鑰時，退回以來源 IP 作為限流鍵。

| 使用者類型 | API 分類 | 每秒限制 | 桶容量 | 實際效果 |
|-----------|---------|----------|--------|----------|
| **匿名使用者** | 產品查詢 | 60/s | 100 | ~3600/小時 |
| | 認證 API | 10/s | 30 | ~600/小時 |
| **認證使用者** | 產品查詢 | 120/s | 200 | ~7200/小時 |
| | 購物車操作 | 20/s | 60 | ~1200/小時 |
| | 支付操作 | 1/s | 10 | ~10/小時 |
| **管理員** | 管理 API | 100/s | 500 | ~6000/小時 |

### 5.2 限流錯誤處理

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1692454800
```

## 6. 相容性需求 (Compatibility Requirements)

### 6.1 技術堆疊版本要求

| 技術 | 最低版本 | 推薦版本 |
|------|----------|----------|
| Java | JDK 21 LTS | Eclipse Temurin 21 |
| Spring Boot | 3.2+ | 最新穩定版 |
| PostgreSQL | 15+ | 15 或 16 |
| Docker | 20.10+ | 最新版 |
| Docker Compose | 2.0+ | 最新版 |

### 6.2 瀏覽器 API 相容性

- Chrome 100+
- Firefox 100+
- Safari 15+
- Edge 100+
- 移動端: iOS Safari 15+, Chrome Mobile 100+

### 6.3 作業系統支援

- **開發**: Windows 10+, macOS 12+, Ubuntu 20.04+
- **部署**: Ubuntu 20.04+, CentOS 8+, Amazon Linux 2023

## 7. 維護性需求 (Maintainability Requirements)

### 7.1 程式碼品質標準

```yaml
code_quality_metrics:
  test_coverage: 
    unit_tests: ">= 80%"
    integration_tests: ">= 70%"
    critical_path: ">= 90%"
  
  code_complexity:
    cyclomatic_complexity: "< 10 per method"
    cognitive_complexity: "< 15 per method"  
    max_method_lines: "< 50"
    max_class_lines: "< 500"
  
  documentation:
    api_documentation: "100% (OpenAPI)"
    public_methods: ">= 80%"
    complex_business_logic: "100%"
```

### 7.2 技術債務管理

- **SonarQube 整合**: 程式碼品質門檻，阻止品質下降
- **定期重構**: 每個 Sprint 分配 20% 時間處理技術債務
- **程式碼審查**: 所有 PR 必須經過同儕審查
- **自動化檢查**: pre-commit hooks 執行格式化和基礎檢查

### 7.3 日誌與除錯支援

```yaml
logging_strategy:
  levels:
    production: "INFO, WARN, ERROR"
    development: "DEBUG, INFO, WARN, ERROR"
    testing: "WARN, ERROR"
  
  structured_logging:
    format: "OpenTelemetry JSON"
    correlation_id: "每個請求追蹤"
    performance_metrics: "回應時間, 資源使用"
  
  log_retention:
    application_logs: "30 days"
    access_logs: "90 days" 
    error_logs: "1 year"
    audit_logs: "7 years"
```

## 8. 災難復原需求 (Disaster Recovery Requirements)

### 8.1 備份策略

```yaml
backup_schedule:
  database:
    frequency: "每日 02:00"
    retention: "7 天本地, 30 天雲端"
    verification: "每週復原測試"
  
  application_config:
    frequency: "配置變更時"
    storage: "Git repository + 本地備份"
  
  user_uploaded_files:
    frequency: "每日 03:00" 
    retention: "30 天"
```

### 8.2 災難恢復程序

1. **檢測**: 監控系統自動偵測或人工發現故障
2. **評估**: 判斷影響範圍和復原優先級
3. **復原**: 
   - RTO < 15 分鐘: 容器重啟或資料庫復原
   - RPO < 1 小時: 最大可接受資料損失
4. **驗證**: 功能測試確認服務正常
5. **記錄**: 事後分析和程序改進

## 9. 法規遵循需求 (Compliance Requirements)

### 9.1 資料保護法規（學習目的）

- **GDPR 模擬**: 使用者資料刪除權、資料匯出權
- **資料加密**: 
  - 傳輸中: TLS 1.2+
  - 靜態資料: 敏感欄位加密 (密碼、PII)
- **資料保留**: 
  - 使用者帳號: 3 年未活動自動標記刪除
  - 交易記錄: 7 年保留 (模擬金融法規)

### 9.2 安全標準遵循

- **OWASP Top 10**: 定期檢查和修復
- **容器安全**: CIS Docker Benchmark 基礎遵循
- **API 安全**: OAuth 2.0 + OpenID Connect 標準實作

## 10. 監控與可觀測性需求

### 10.1 系統監控指標

- **資源使用**: CPU, 記憶體, 磁碟 I/O, 網路流量
- **應用程式指標**: QPS, 回應時間, 錯誤率, 活躍使用者數
- **容器健康**: 容器狀態, 重啟次數, 資源配額使用情況
- **業務指標**: 註冊使用者數, 訂單成交量, API 使用統計

### 10.2 告警規則

- **嚴重告警**: 服務完全不可用, 資料庫連線失敗, 記憶體使用率 > 95%
- **警告告警**: CPU > 75%, 記憶體 > 85%, 錯誤率 > 5%, 回應時間 > 600ms
- **資訊告警**: 效能下降, 快取命中率低於 75%, 磁碟空間 < 20%

## 相關文件

- [功能需求](./functional.md) - 功能規格說明
- [部署架構](../operations/deployment.md) - 容器化部署設計
- [監控系統](../operations/monitoring.md) - 監控告警設計
- [測試策略](../implementation/testing-strategy.md) - 測試計畫

---

*本文件是 Fake Store API 專案的一部分*
