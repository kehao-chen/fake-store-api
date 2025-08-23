# OpenAPI 規範（文件與規則）

## 檔案組織
- 模組化結構：`openapi/main.yaml` 為入口；`paths/`、`components/` 各自拆分。
- `$ref`：使用相對路徑引用，索引檔（index.yaml）僅匯出實際使用的節點。

## 命名與標籤
- 路徑資源化：遵循 AIP（如 `/categories/{id}/products`）。
- 自訂方法：使用 `:verb`（如 `/payments:createCheckoutSession`）。
- `operationId`：動詞駝峰（如 `listProducts`, `createCheckoutSession`）。
- 單一標籤：每個 operation 僅一個主要 tag。

## 安全與授權
- 採用 OAuth2（authorizationCode + PKCE）與 ApiKeyBearer（http-bearer）。
- 端點 `security` 可設 OR（`OAuth2` 或 `ApiKeyBearer` 任一）。

## Lint 與 CI
- Spectral：專案提供 `spectral.yaml` 規則；要求 `make lint-openapi` 為綠燈。
- Redocly：`make redocly-lint-openapi` 作為補充驗證；PR 合併前需綠燈。

## 範例與 `nullable`
- 當 `$ref` 欄位需 `nullable: true`，以 `allOf + $ref + type: object` 表示，避免工具誤判。
- Examples：集中於 `components/examples/`，在對應 response/request 的 `examples` 中引用。
