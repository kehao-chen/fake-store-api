# 認證與授權（骨架）

> TODO: 補充 OAuth2 流程、JWT 格式、Token Rotation 與撤銷策略、安全標頭與全域中介層設定。

- OAuth2 授權碼 + PKCE 流程細節
- JWT 結構、簽名演算法與有效期
- 刷新令牌輪換與重放攻擊偵測
- 權限範圍（scopes）與角色（roles）
- 全域安全標頭注入策略（成功/錯誤皆一致）
- 全域安全標頭（建議由 API Gateway 或全域 Filter 注入）
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Cache-Control: no-store`（於敏感回應）

- 審計欄位注入規則
  - `created_by/updated_by/deleted_by` 由伺服器端依當前使用者（或 system）注入，API 標示 `readOnly`。
