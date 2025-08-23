# SDK 使用指南

## 生成 SDK（OpenAPI Generator）

### TypeScript Axios
```bash
openapi-generator-cli generate -i openapi/main.yaml -g typescript-axios -o generated/typescript-client
```

### Python
```bash
openapi-generator-cli generate -i openapi/main.yaml -g python -o generated/python-client
```

### Java
```bash
openapi-generator-cli generate -i openapi/main.yaml -g java -o generated/java-client
```

## 使用範例（TypeScript）
```ts
import { Configuration, ProductsApi } from './generated/typescript-client';

const config = new Configuration({
  basePath: 'https://fakestore.happyhacking.ninja/v1',
  headers: { Authorization: 'Bearer sk_test_123...' },
});

const api = new ProductsApi(config);
const res = await api.listProducts({ pageSize: 20, filter: 'price>50' });
console.log(res.data);
```

## 注意事項
- 認證：JWT 或 API Key 皆放在 `Authorization: Bearer <token>`。
- 端點與模型以 `openapi/main.yaml` 為準，更新規格後請重新生成。
