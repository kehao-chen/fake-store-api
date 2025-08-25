# 學習指南

[← 返回文件中心](../README.md) | **學習指南**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-25
- **目標讀者**: 所有專案參與者
- **相關文件**:
  - [快速開始](./getting-started.md)
  - [專案術語表](../terminology.md)

## 推薦學習路徑（8 個步驟）
1) 讀 PRD（產品需求）→ 理解業務與目標
2) 讀 OpenAPI（openapi/main.yaml）→ 端點、模型、認證/支付
3) 讀 API 設計（AIP）：design-spec、error-handling、versioning、openapi-standard
4) 讀 Architecture：C4、DDD、Data Flow、DB Schema
5) 跑 Lint（Spectral/Redocly）→ 體驗規格驗證
6) 快速啟動（guides/getting-started, setup）→ 呼叫幾個端點
7) 測試策略（implementation/testing-strategy）→ 架構/整合/E2E 測試
8) 運維（operations/deployment, performance-tuning, monitoring, backup）

## 實作練習任務（建議）
- 任務 A：在產品列表加入一個可過濾欄位（如 `stock_quantity`）
  - 更新 OpenAPI（增加 Filter 範圍與索引建議）
  - 補測試（單元/整合）、跑 Lint
- 任務 B：新增 `/v1/products:batchDelete`（AIP-136）
  - 設計 request/response、增加錯誤範例（部分成功）
  - 補 ArchUnit 規則與整合測試
- 任務 C：為 Orders 加入 `PATCH` updateMask（AIP-134）
  - 指定允許更新欄位、補錯誤案例（INVALID_ARGUMENT）
- 任務 D：完善 Checkout 對賬
  - 將 `order_id` 放入 Session metadata；模擬 Webhook 事件，完成對賬流程測試
- 任務 E：API Key 管理
  - 建立/撤銷 API Key 端點與 DB 表；以 API Key 呼叫受保護端點

## 小技巧
- Lint 綠燈先行：每次變更先跑 `make lint-openapi`。
- AIP 對照：規格增補時對照 AIP-132/134/136/160/193。
- 快取與批次：優先以快取和 batch API 降低壓力。

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-25*
