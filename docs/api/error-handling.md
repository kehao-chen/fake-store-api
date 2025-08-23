# 錯誤處理規範（骨架）

> TODO: 補充 AIP-193 錯誤對應表、`details` 結構、常見錯誤案例、對應 HTTP 狀態碼與標頭。

- AIP-193 錯誤碼對應與語義
- 驗證錯誤 `BadRequest` 的 `field_violations` 結構
- 範例：過濾語法錯、未認證、未授權、資源不存在、限流、內部錯誤
- 全域 `X-Request-ID`、`Retry-After` 等標頭策略
