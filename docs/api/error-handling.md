# 錯誤處理規範

[← 返回文件中心](../README.md) | [API 文件](./README.md) | **錯誤處理**

## 文件資訊

- **版本**: 1.0.0
- **最後更新**: 2025-08-25
- **目標讀者**: 開發者
- **相關文件**:
  - [API 設計規格](./design-spec.md)
  - [OpenAPI 錯誤回應範本](../../openapi/components/responses/errors.yaml)

本專案遵循 Google AIP-193 的錯誤格式，統一錯誤 envelope 與錯誤碼語義，並對應適當的 HTTP 狀態與標頭。

## 統一錯誤格式

```json
{
  "error": {
    "code": "INVALID_ARGUMENT",
    "message": "The request contains invalid parameters.",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.BadRequest",
        "field_violations": [
          { "field": "product.price", "description": "Price must be greater than 0" }
        ]
      }
    ]
  },
  "request_id": "req_abc123",
  "timestamp": "2025-08-19T15:30:00Z"
}
```

要點：
- `error.code` 使用 AIP-193 規範之語義名稱（非 HTTP code）。
- `details` 可攜帶型別化 payload（如 `google.rpc.BadRequest`）。
- 附帶 `request_id` 與 `timestamp` 以利追蹤。

## 常見錯誤對應

- 400 Bad Request → `INVALID_ARGUMENT`
  - 解析失敗、參數不合法、過濾語法錯（field: `filter`）。
- 401 Unauthorized → `UNAUTHENTICATED`
  - 缺少或無效的 Authorization Bearer；包含 `WWW-Authenticate` 挑戰標頭。
- 403 Forbidden → `PERMISSION_DENIED`
  - 權限不足（未具備 role/scope）。
- 404 Not Found → `NOT_FOUND`
  - 資源不存在。
- 409 Conflict / 412 Precondition Failed → `FAILED_PRECONDITION`
  - 版本衝突、資源狀態不一致。
- 402 Payment Required → `PAYMENT_REQUIRED`
  - 支付被拒；細節附 `google.rpc.ErrorInfo`（`reason`, `domain`）。
- 429 Too Many Requests → `RATE_LIMIT_EXCEEDED`
  - 回應 `Retry-After` 與速率限制標頭。
- 500 Internal Server Error → `INTERNAL`
  - 未預期錯誤。

## 標頭策略

- `X-Request-ID`：每個請求的追蹤 ID（回應與錯誤皆包含）。
- `Retry-After`：限流/暫時性失敗時提供重試建議（秒或日期）。
- `WWW-Authenticate`（401）：提供 Bearer 挑戰與失敗原因。
- 安全標頭：`X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `Referrer-Policy`。

## 參考 OpenAPI 範例

- `openapi/components/responses/errors.yaml` 定義了 BAD_REQUEST、UNAUTHORIZED、FORBIDDEN、NOT_FOUND、PAYMENT_REQUIRED 等回應與範例；請優先引用這些元件以保持一致。

---

*本文件是 Fake Store API 專案的一部分*

*最後更新: 2025-08-25*
