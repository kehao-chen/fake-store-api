# 快速開始

[← 返回文件中心](../README.md) | **快速開始**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-25
- **目標讀者**: 開發者
- **相關文件**:
  - [開發環境設置](./setup.md)
  - [學習指南](./learning-guide.md)

## 1. 環境需求
- Java 21、Docker 20.10+、Docker Compose 2+、Node/npm（可選，用於 lint/Redoc）

## 2. 啟動服務（開發模式）
```bash
# 檢查依賴與初始化
make check-deps || true
cp .env.example .env

# 啟動（依專案腳本而定）
make dev
make logs
```

## 3. 健康檢查
```bash
curl -f http://localhost:8080/actuator/health
```

## 4. OpenAPI 文件
```bash
make lint-openapi            # Spectral 檢查
make redocly-lint-openapi    # Redocly 檢查
make redoc-build-openapi     # 產出 docs/api.html
```

## 5. 認證方式
- JWT（/v1/auth/login 或 OAuth2 + /v1/auth/token）
- API Key（登入後 POST /v1/users/me/apiKeys；使用 Authorization: Bearer <key>）

## 6. 支付雙軌
- PaymentIntent：POST /v1/payments → 回 client_secret → 前端確認
- Checkout：POST /v1/payments:createCheckoutSession → 回 checkout_url → 前端重導

## 7. 常見問題
- 401：請檢查 Authorization 標頭（Bearer JWT 或 API Key）。
- 429：限流，請參考 Retry-After。

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-25*
