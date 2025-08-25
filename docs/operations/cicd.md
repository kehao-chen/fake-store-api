# CI/CD 流程

[← 返回文件中心](../README.md) | [運維部署](./README.md) | **CI/CD 流程**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-25
- **目標讀者**: DevOps 工程師, 開發者
- **相關文件**:
  - [部署架構](./deployment.md)
  - [測試策略](../implementation/testing-strategy.md)

## 驗證階段
- 建構與測試：`./gradlew build test`
- OpenAPI Lint：`make lint-openapi`（Spectral） + `make redocly-lint-openapi`
- 產出 OpenAPI HTML：`make redoc-build-openapi`（可上傳 artifact）

## 觀測性（可選步驟）
- 啟動 Prometheus/Grafana 容器（staging）：抓取 `/actuator/prometheus` 指標。
- 導入監控儀表板（API/Webhook/對賬），配合告警策略。

## 版本控制與發佈
- 遵循 `docs/api/versioning.md`：/v1 穩定；破壞性變更須升主版並公告。
- 變更紀錄（Changelog）：每次 PR 合併產生摘要。

## 部署（示意）
- Staging：推送 `main` → 自動部署測試環境。
- Production：打 tag（v1.x.y）→ 觸發生產部署流程。
- 零停機：藍綠或滾動部署（學習專案可簡化）。

## 回滾策略
- 保留前一版本映像（鏡像/Compose）與資料備份。
- 回滾步驟標準化（runbook），並在 PRD/Docs 更新公告。

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-25*
