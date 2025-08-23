# API Key 認證與使用案例

本文件示範如何以 API Key 或 JWT 經由 `Authorization: Bearer <token>` 呼叫 API。

## 取得 API Key

1) 以 JWT 登入（教學用帳密或 OAuth2 兌換）
2) 呼叫建立金鑰端點：

```bash
curl -X POST \
  -H "Authorization: Bearer <your-jwt>" \
  -H "Content-Type: application/json" \
  https://api.fakestore.happyhacking.ninja/v1/users/me/apiKeys
```

成功回應（僅建立時回傳完整 key 值）：

```json
{
  "api_key": {
    "id": "key_abc123",
    "name": "my-local-dev-key",
    "prefix": "sk_test_",
    "created_at": "2025-08-22T10:30:00Z",
    "last_used_at": null
  },
  "key": "sk_test_1234567890abcdef"
}
```

請妥善保存 `key`，之後只會回傳前綴與中繼資料。

## 使用 API Key 呼叫 API

以 Authorization Bearer 方式傳遞：

```bash
curl -H "Authorization: Bearer sk_test_1234567890abcdef" \
  https://api.fakestore.happyhacking.ninja/v1/products
```

使用 JWT 呼叫 API（同一標頭）：

```bash
curl -H "Authorization: Bearer eyJhbGciOi..." \
  https://api.fakestore.happyhacking.ninja/v1/users/me
```

撤銷 API Key：

```bash
curl -X DELETE \
  -H "Authorization: Bearer <your-jwt>" \
  https://api.fakestore.happyhacking.ninja/v1/users/me/apiKeys/key_abc123
```

## 常見錯誤

- 401 Unauthorized：缺少或無效的 Authorization 標頭
- 403 Forbidden：金鑰權限不足（例如嘗試管理操作）

