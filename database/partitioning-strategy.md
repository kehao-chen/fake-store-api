# 資料庫分區策略

本文件說明 Fake Store API 的資料庫分區（Partitioning）策略，用於處理大規模資料和提升查詢效能。

## 分區策略概覽

### 1. 訂單表分區（按時間）

```sql
-- 按月份分區訂單表
CREATE TABLE orders (
    id varchar(50),
    user_id varchar(50),
    created_at timestamptz,
    -- 其他欄位...
) PARTITION BY RANGE (created_at);

-- 建立月份分區
CREATE TABLE orders_2025_01 PARTITION OF orders
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
    
CREATE TABLE orders_2025_02 PARTITION OF orders
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
```

**優點**：
- 歷史訂單查詢效能提升
- 易於歸檔舊資料
- 可以針對特定時期進行維護

### 2. 使用者活動日誌分區（按日期）

```sql
-- 按日分區活動日誌
CREATE TABLE user_activity_logs (
    id bigserial,
    user_id varchar(50),
    action varchar(100),
    created_at timestamptz,
    -- 其他欄位...
) PARTITION BY RANGE (created_at);

-- 自動建立每日分區的函數
CREATE OR REPLACE FUNCTION create_daily_partition()
RETURNS void AS $$
DECLARE
    partition_date date;
    partition_name text;
BEGIN
    partition_date := CURRENT_DATE;
    partition_name := 'user_activity_logs_' || to_char(partition_date, 'YYYY_MM_DD');
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF user_activity_logs
        FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        partition_date,
        partition_date + interval '1 day'
    );
END;
$$ LANGUAGE plpgsql;
```

### 3. 產品表分區（按分類）

```sql
-- 按分類 ID 雜湊分區
CREATE TABLE products (
    id varchar(50),
    category_id varchar(50),
    -- 其他欄位...
) PARTITION BY HASH (category_id);

-- 建立 4 個雜湊分區
CREATE TABLE products_p0 PARTITION OF products
    FOR VALUES WITH (modulus 4, remainder 0);
    
CREATE TABLE products_p1 PARTITION OF products
    FOR VALUES WITH (modulus 4, remainder 1);
    
CREATE TABLE products_p2 PARTITION OF products
    FOR VALUES WITH (modulus 4, remainder 2);
    
CREATE TABLE products_p3 PARTITION OF products
    FOR VALUES WITH (modulus 4, remainder 3);
```

## 分區維護策略

### 1. 自動分區建立

```sql
-- 每月自動建立下個月的訂單分區
CREATE OR REPLACE FUNCTION create_monthly_order_partition()
RETURNS void AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := date_trunc('month', CURRENT_DATE + interval '1 month');
    end_date := start_date + interval '1 month';
    partition_name := 'orders_' || to_char(start_date, 'YYYY_MM');
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF orders
        FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        start_date,
        end_date
    );
END;
$$ LANGUAGE plpgsql;

-- 排程每月執行
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('create-order-partition', '0 0 25 * *', 
    'SELECT create_monthly_order_partition()');
```

### 2. 舊分區歸檔

```sql
-- 歸檔超過 6 個月的訂單分區
CREATE OR REPLACE FUNCTION archive_old_partitions()
RETURNS void AS $$
DECLARE
    partition_name text;
    archive_date date;
BEGIN
    archive_date := CURRENT_DATE - interval '6 months';
    
    FOR partition_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE tablename LIKE 'orders_%' 
        AND tablename < 'orders_' || to_char(archive_date, 'YYYY_MM')
    LOOP
        -- 移動到歸檔 schema
        EXECUTE format('ALTER TABLE %I SET SCHEMA archive', partition_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## 查詢最佳化

### 1. 分區修剪（Partition Pruning）

```sql
-- 啟用分區修剪
SET enable_partition_pruning = on;

-- 查詢特定月份的訂單（只掃描相關分區）
SELECT * FROM orders 
WHERE created_at >= '2025-01-01' 
AND created_at < '2025-02-01';
```

### 2. 平行查詢

```sql
-- 啟用分區平行查詢
SET max_parallel_workers_per_gather = 4;
SET parallel_setup_cost = 100;
SET parallel_tuple_cost = 0.01;

-- 跨分區聚合查詢
SELECT 
    date_trunc('month', created_at) as month,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue
FROM orders
WHERE created_at >= '2025-01-01'
GROUP BY 1
ORDER BY 1;
```

## 監控與維護

### 1. 分區大小監控

```sql
-- 檢查各分區大小
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE tablename LIKE 'orders_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### 2. 分區效能監控

```sql
-- 監控分區查詢效能
CREATE VIEW partition_stats AS
SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'public'
AND tablename LIKE '%_p%' OR tablename LIKE '%_20%';
```

## 最佳實踐

1. **選擇正確的分區鍵**
   - 時間序列資料：使用日期/時間欄位
   - 分類資料：使用分類 ID 或地區
   - 避免使用經常變更的欄位

2. **分區粒度**
   - 每個分區保持 1-10GB 大小
   - 避免過多小分區（管理開銷）
   - 避免過大分區（查詢效能）

3. **索引策略**
   - 在分區表上建立全域索引
   - 每個分區可有本地索引
   - 定期維護索引統計資訊

4. **維護窗口**
   - 在低峰期執行分區維護
   - 使用 CONCURRENTLY 選項
   - 監控鎖定和阻塞情況