# 資料庫結構設計文件

本目錄包含 Fake Store API 專案的完整資料庫結構設計，使用資料庫標記語言 (DBML) 撰寫。

## Single Source of Truth 原則

本 DBML 文件作為所有資料庫相關設計決策的**權威來源**。PRD.md 檔案引用這些檔案，而非重複定義結構描述。

## 檔案架構

```
database/
├── README.md                 # 本檔案 - 概覽與說明文件
├── schema.dbml              # 主要 DBML 結構描述（所有資料表）
├── indexes.dbml             # 效能最佳化索引策略
├── triggers.dbml            # 資料庫觸發器與函數
├── relationships.md         # 視覺化關聯文件
└── partitioning-strategy.md # 資料庫分區策略
```

## DBML 相關資源

- **DBML 官方文件**: https://dbml.dbdiagram.io/docs/
- **線上編輯器**: https://dbdiagram.io/
- **命令列工具**: https://github.com/holistics/dbml

## 使用方式

1. **視覺化設計**: 將 `schema.dbml` 匯入 dbdiagram.io 進行視覺化資料庫設計
2. **程式碼產生**: 使用 DBML CLI 工具產生 PostgreSQL 的 SQL DDL
3. **文件產生**: 從 DBML 自動產生資料庫說明文件
4. **版本控制**: 透過 Git diff 追蹤 DBML 檔案的結構變更

## 資料庫設計原則

- **資源導向命名**: 資料表使用複數名詞 (例如：`products`、`users`)
- **時間戳記一致性**: 所有資料表皆包含 `created_at` 與 `updated_at` 欄位
- **軟刪除支援**: 重要資料表支援軟刪除模式
- **效能最佳化**: 針對常見查詢模式進行策略性索引設計
- **資料完整性**: 完整的約束條件與外鍵關聯設計
- **分區準備**: 支援大規模資料的分區策略