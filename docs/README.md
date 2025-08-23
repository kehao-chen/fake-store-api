# Fake Store API 文件中心

> 🚀 一個功能完整的模擬電子商務 API 服務，採用 Spec-Driven Development 開發方法

## 📋 專案概覽

**Fake Store API** 是一個為學習和開發而設計的完整電商 API 系統，提供產品管理、使用者認證、購物車、訂單和支付等核心功能。

- **版本**: v1.0
- **狀態**: 開發中
- **技術棧**: Java 21, Spring Boot WebFlux, PostgreSQL, Valkey, Docker
- **設計標準**: Google AIP, RESTful, OpenAPI 3.0

## 🎯 快速導航

### 📘 產品與需求
- [產品需求文件 (PRD)](../PRD.md) - 核心產品願景與商業需求
- [功能需求詳細說明](./requirements/functional.md) - 完整功能規格
- [非功能需求規範](./requirements/non-functional.md) - 效能、安全、可用性要求
- [使用案例](./requirements/use-cases.md) - 使用者故事與場景

### 🏗️ 架構設計
- [C4 架構模型](./architecture/c4-model.md) - 系統架構四層視圖
- [領域驅動設計 (DDD)](./architecture/ddd-model.md) - 領域模型與邊界
- [資料庫設計](./architecture/database-schema.md) - 資料模型與 Schema
- [資料流程圖](./architecture/data-flow.md) - 系統資料流動
- [📁 完整資料庫定義](../database/) - DBML 資料庫設計文件

### 🔌 API 設計
- [API 設計規格](./api/design-spec.md) - RESTful API 詳細規範
- [認證與授權](./api/authentication.md) - OAuth 2.0（PKCE）與教學用帳密登入
- [錯誤處理規範](./api/error-handling.md) - 統一錯誤格式
- [版本控制策略](./api/versioning.md) - API 版本管理
- [OpenAPI 規範](./api/openapi-standard.md) - API 文件標準
- [📁 OpenAPI 完整定義](../openapi/) - 模組化 OpenAPI 3.0 規範檔案

### 💻 實作指南
- [技術棧說明](./implementation/technology-stack.md) - 技術選型與理由
- [安全實作指南](./implementation/security.md) - 安全最佳實踐
- [測試策略](./implementation/testing-strategy.md) - ArchUnit 架構測試導向的完整測試策略
- [程式碼範例](./examples/) - 實作參考程式碼

### 🚀 運維部署
- [部署架構](./operations/deployment.md) - 容器化與部署策略
- [監控告警系統](./operations/monitoring.md) - 可觀測性設計
- [備份與災難恢復](./operations/backup-recovery.md) - 資料保護策略
- [效能調校](./operations/performance-tuning.md) - 最佳化指南
- [資料庫分區策略](../database/partitioning-strategy.md) - 大規模資料處理

### 📚 學習資源
- [快速開始指南](./guides/getting-started.md) - 5 分鐘上手
- [學習路徑](./guides/learning-guide.md) - 循序漸進學習計畫
- [開發環境設置](./guides/setup.md) - 環境配置指南
- [術語對照表](./terminology.md) - 中英文技術術語規範

## 👥 依角色查看

### 產品經理 / 業務分析師
- 📋 [產品需求文件](../PRD.md)
- 📊 [功能需求](./requirements/functional.md)
- 🎯 [使用案例](./requirements/use-cases.md)
- 📈 [成功指標](./requirements/success-metrics.md)

### 後端開發者
- 🛠️ [技術棧](./implementation/technology-stack.md)
- 📡 [API 設計規格](./api/design-spec.md)
- 💾 [資料庫設計](./architecture/database-schema.md)
- 🔐 [認證實作](./api/authentication.md)
- 📝 [程式碼範例](./examples/)

### 前端開發者
- 🔌 [API 文件](./api/design-spec.md)
- 📁 [OpenAPI 規範](../openapi/) - 完整 API 定義與範例
- 🔑 [認證流程](./api/authentication.md)
- ❌ [錯誤處理](./api/error-handling.md)
- 📦 [SDK 使用指南](./guides/sdk-usage.md)

### DevOps 工程師
- 🐳 [部署架構](./operations/deployment.md)
- 📊 [監控系統](./operations/monitoring.md)
- 🔄 [CI/CD 流程](./operations/cicd.md)
- 💾 [備份策略](./operations/backup-recovery.md)

### 新手開發者
- 🚀 [快速開始](./guides/getting-started.md)
- 📖 [學習指南](./guides/learning-guide.md)
- 🔧 [開發環境設置](./guides/setup.md)
- 📚 [術語解釋](./terminology.md)

## 📂 文件結構

```
docs/
├── README.md                    # 本文件 - 文件導航中心
├── requirements/                # 需求相關文件
│   ├── functional.md           # 功能需求
│   ├── non-functional.md       # 非功能需求
│   ├── use-cases.md           # 使用案例
│   └── success-metrics.md      # 成功指標
├── architecture/               # 架構設計文件
│   ├── c4-model.md            # C4 架構模型
│   ├── ddd-model.md           # DDD 領域模型
│   ├── data-flow.md           # 資料流程圖
│   └── database-schema.md     # 資料庫設計
├── api/                        # API 相關文件
│   ├── design-spec.md          # API 設計規格
│   ├── authentication.md      # 認證授權
│   ├── error-handling.md      # 錯誤處理
│   ├── versioning.md          # 版本控制
│   └── openapi-standard.md    # OpenAPI 規範
├── implementation/             # 實作相關文件
│   ├── technology-stack.md    # 技術棧
│   ├── security.md            # 安全實作
│   └── testing-strategy.md    # 測試策略
├── operations/                 # 運維相關文件
│   ├── deployment.md          # 部署架構
│   ├── monitoring.md          # 監控告警
│   ├── backup-recovery.md     # 備份恢復
│   ├── performance-tuning.md  # 效能調校
│   └── cicd.md               # CI/CD 流程
├── examples/                   # 程式碼範例
│   ├── product-api.md         # 產品 API 實作
│   └── auth-jwt.md           # JWT 認證實作
├── guides/                     # 指南文件
│   ├── getting-started.md     # 快速開始
│   ├── learning-guide.md      # 學習指南
│   ├── setup.md              # 環境設置
│   └── sdk-usage.md          # SDK 使用
└── terminology.md             # 術語對照表
```

## 🔄 文件版本

- **當前版本**: 1.0.0
- **最後更新**: 2025-08-20
- **維護者**: Fake Store API Team

## 📝 文件規範

所有文件遵循以下規範：
- 使用臺灣正體中文
- 技術術語參考[術語對照表](./terminology.md)
- Markdown 格式，支援 Mermaid 圖表
- 每個文件都有明確的目標讀者
- 包含實用的範例和程式碼片段

## 🤝 貢獻指南

歡迎對文件提出改進建議：
1. Fork 專案
2. 建立功能分支
3. 提交變更
4. 發送 Pull Request

## 📮 聯絡資訊

- GitHub: [kehao-chen/fake-store-api](https://github.com/kehao-chen/fake-store-api)
- Email: support@fakestore.happyhacking.ninja
- Discord: [開發者社群](https://discord.gg/fake-store-api)

---

*本文件是 Fake Store API 專案的一部分，採用 Apache License 2.0 授權條款*
