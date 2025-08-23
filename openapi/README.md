# OpenAPI 檔案結構說明
這個目錄包含完整的 OpenAPI 3.0 規範檔案，採用模組化設計。

## 檔案結構
```
openapi/
├── main.yaml                    # 主要規範檔案
├── paths/                       # API 路徑定義
│   ├── auth.yaml               # 認證端點
│   ├── products.yaml           # 產品端點
│   ├── categories.yaml         # 分類端點
│   ├── users.yaml              # 使用者和購物車端點
│   ├── events.yaml             # 事件操作端點
│   ├── event-queries.yaml      # 事件查詢端點
│   └── webhooks.yaml           # Webhook 端點
├── components/                  # 可重複使用的組件
│   ├── schemas/                # 資料模型定義
│   │   ├── index.yaml          # Schema 索引
│   │   ├── product.yaml        # 產品模型
│   │   ├── category.yaml       # 分類模型
│   │   ├── user.yaml           # 使用者模型
│   │   ├── cart.yaml           # 購物車模型
│   │   ├── order.yaml          # 訂單模型
│   │   ├── auth.yaml           # 認證模型
│   │   ├── events.yaml         # 事件模型
│   │   ├── webhook.yaml        # Webhook 模型
│   │   └── common.yaml         # 通用模型
│   ├── responses/              # 回應模板
│   │   ├── index.yaml          # 回應索引
│   │   └── errors.yaml         # 錯誤回應
│   ├── parameters/             # 參數模板
│   │   ├── index.yaml          # 參數索引
│   │   ├── common.yaml         # 通用參數
│   │   └── identifiers.yaml    # 識別符參數
│   └── examples/               # 範例資料
│       ├── index.yaml          # 範例索引
│       ├── product-examples.yaml # 產品範例
│       ├── category-examples.yaml # 分類範例
│       ├── user-examples.yaml  # 使用者範例
│       ├── auth-examples.yaml  # 認證範例
│       ├── cart-examples.yaml  # 購物車範例
│       ├── order-examples.yaml # 訂單範例
│       └── error-examples.yaml # 錯誤範例
└── README.md                   # 本說明文件
```

## 使用方式

### 1. 驗證 OpenAPI 規範
```bash
# 使用 Redocly CLI 驗證（推薦）
# 需要 bun / pnpm / npm 任一
make redocly-lint-openapi

# 或手動執行
npx @redocly/cli lint openapi/main.yaml
```

### 2. 生成 API 文件
```bash
# 使用 Redoc 生成靜態文件
# 需要 bun / pnpm / npm 任一
make redoc-build-openapi

# 或手動執行
npx redoc-cli build openapi/main.yaml --output docs/api.html
```

### 3. 生成客戶端 SDK
```bash
# TypeScript/JavaScript SDK
openapi-generator-cli generate -i openapi/main.yaml -g typescript-axios -o generated/typescript-client

# Python SDK
openapi-generator-cli generate -i openapi/main.yaml -g python -o generated/python-client

# Java SDK
openapi-generator-cli generate -i openapi/main.yaml -g java -o generated/java-client
```

### 4. 本地開發伺服器
```bash
# 使用 Swagger UI
docker run -p 8080:8080 -e SWAGGER_JSON=/openapi/main.yaml -v $(pwd)/openapi:/openapi swaggerapi/swagger-ui
```

## 技術特色

### 符合標準
- **OpenAPI 3.0.3**: 最新的 OpenAPI 規範
- **Google AIP**: 遵循 Google API Improvement Proposals
- **AIP-160**: 標準篩選語法 
- **AIP-193**: 統一錯誤回應格式

### 安全性
- **JWT Bearer Token**: 主要認證方式
- **OAuth 2.0**: 支援第三方登入
- **PKCE**: 增強 OAuth 安全性
- **Rate Limiting**: API 請求限流

### 開發者體驗
- **豐富範例**: 每個端點都有完整範例
- **詳細文件**: 清晰的描述和使用說明
- **多語言支援**: 自動生成多種語言的 SDK
- **工具整合**: 支援主流的 API 工具鏈

## 維護指南

### 更新規範
1. 修改對應的 YAML 檔案
2. 執行驗證（Redocly 與 Spectral 皆可）：
   - `make redocly-lint-openapi`
   - `make lint-openapi`
3. 更新版本號: 修改 `main.yaml` 中的 `info.version`
4. 提交變更並建立 Git 標籤

### 新增端點
1. 在 `paths/` 下建立或更新相應檔案
2. 在 `main.yaml` 中新增路徑引用
3. 更新相關的 schemas 和 examples
4. 執行完整測試

### 版本控制
- 遵循語義化版本控制 (Semantic Versioning)
- 主版本變更: 不相容的 API 變更
- 次版本變更: 新增功能，向後相容
- 修訂版本: 錯誤修復，向後相容
