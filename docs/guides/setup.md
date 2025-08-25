# 開發環境設置

[← 返回文件中心](../README.md) | **環境設置**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-25
- **目標讀者**: 開發者
- **相關文件**:
  - [快速開始](./getting-started.md)

## 必要軟體
- Java 21（Eclipse Temurin 推薦）
- Docker 20.10+、Docker Compose 2+
- Node/npm 或 bun/pnpm（可選，用於 Lint/Redoc CLI）

## 專案初始化
```bash
git clone https://github.com/kehao-chen/fake-store-api.git
cd fake-store-api
cp .env.example .env
```

## 本地啟動
```bash
make dev
make logs
```

## 驗證 OpenAPI
```bash
make lint-openapi
make redocly-lint-openapi
```

## 常見問題
- Port 佔用：調整 Compose/應用的埠號或關閉衝突服務。
- Lint 工具缺少：安裝 Node 或改用 bun/pnpm，或在 CI 執行。

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-25*
