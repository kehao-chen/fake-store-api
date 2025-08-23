# 備份與災難復原

## 目標與指標
- RPO：< 1 小時（見非功能需求）
- RTO：< 15 分鐘（見非功能需求）

## 備份策略
- 資料庫：每日全備 + 每小時增量備份（WAL）；保留 7~14 天。
- 物件儲存：備份檔案壓縮加密（AES-256），存放本地與雲端兩份。
- 金鑰管理：備份加密金鑰存於密鑰管理系統（KMS）或離線保存。

## 還原演練
- 每月演練：在 staging 環境從零還原（DB schema + 資料 + 應用配置）。
- 演練內容：驗證應用啟動、健康檢查、核心流程（登入/下單/支付）。

## 自動化示例（PostgreSQL）
```bash
# 每日全備
pg_dump -Fc -Z9 -f backups/fakestore_$(date +%F).dump fakestore

# 增量（WAL）
pg_basebackup -D backups/wal_$(date +%F_%H) -X fetch -F tar

# 驗證備份（簡單示例）
pg_restore -l backups/fakestore_$(date +%F).dump > /dev/null
```

## 還原流程（示意）
```bash
createdb fakestore_restore
pg_restore -d fakestore_restore backups/fakestore_YYYY-MM-DD.dump
# 視需要重播 WAL 以復原至目標時間點
```

## 注意事項
- 保護 `.env`、API 金鑰與 JWT 金鑰；避免與備份一起存放。
- 還原後重新設定 webhook endpoint 與第三方憑證（Stripe/OAuth）。
