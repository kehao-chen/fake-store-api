# 部署架構（骨架）

> TODO: 補充 Docker 建置、環境變數、健康檢查、零停機部署策略。

## Server Variables（OpenAPI servers）
- `servers.url`: `https://{host}/v1`
- `variables.host.enum`: `fakestore.happyhacking.ninja`, `staging.fakestore.happyhacking.ninja`, `localhost:8080`
- 部署時以環境變數或 CI 參數替換 `host` 用於產出對應環境的 API 文件/SDK。
