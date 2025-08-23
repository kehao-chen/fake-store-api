# 部署架構

## 1. 目標環境
- 單一 Docker Host（4~8GB）：學習/測試環境
- 反向代理：Caddy（自動 HTTPS）
- 應用：Spring Boot WebFlux（API Gateway 可選）
- 資料：PostgreSQL、Valkey

## 2. 範例 Docker Compose（簡化）
```yaml
version: '3.9'
services:
  caddy:
    image: caddy:2
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
    depends_on: [api]

  api:
    image: fakestore/api:latest
    env_file: [.env]
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - DB_URL=jdbc:postgresql://postgres:5432/fakestore
      - DB_USER=fakestore
      - DB_PASSWORD=${DB_PASSWORD}
      - VALKEY_HOST=valkey
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
    ports: ["8081:8081"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=fakestore
      - POSTGRES_USER=fakestore
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

  valkey:
    image: valkey/valkey:latest
    command: ["valkey-server", "--appendonly", "yes"]

volumes:
  pgdata: {}
```

## 3. 環境變數（重點）
- `DB_PASSWORD`, `STRIPE_SECRET_KEY`, `JWT_SECRET` 以 secrets/ENV 注入，避免硬編碼。
- OpenAPI servers 使用 `https://{host}/v1`，由部署流程以 `host` 變數替換。

## 4. 零停機策略（簡案）
- 滾動更新：`docker service update` 或 Compose 停一啟一（學習場景可簡化）。
- 健康檢查：`/actuator/health` 合格才切流量；反向代理設定 fail_timeout 與重試。
- 回滾：保留上一版映像與資料快照，快速切回。

## 5. 觀測性與告警
- 指標：API latency/RPS/error、DB 連線池、快取命中率
- 日誌：結合 `X-Request-ID`/trace-id；敏感資訊遮罩
- 告警：健康檢查失敗、錯誤率升高、對賬落差、Webhook 失敗堆積

## 6. 安全實務
- 非 root user，唯讀檔案系統，限制 capabilities
- 僅暴露必要埠口；Caddy 統一 TLS 終止
- CSRF 不適用 API；加固安全標頭

## Server Variables（OpenAPI servers）
- `servers.url`: `https://{host}/v1`
- `variables.host.enum`: `fakestore.happyhacking.ninja`, `staging.fakestore.happyhacking.ninja`, `localhost:8080`
- 部署時以環境變數或 CI 參數替換 `host` 用於產出對應環境的 API 文件/SDK。
