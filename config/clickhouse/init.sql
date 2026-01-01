-- ClickHouse initialization for TensorZero telemetry
-- This creates the database and table for token usage tracking

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS tensorzero;

-- Use the database
USE tensorzero;

-- Create token usage table
-- This table stores inference requests, token counts, and tenant information
CREATE TABLE IF NOT EXISTS token_usage
(
    timestamp DateTime DEFAULT now(),
    tenant_id String,
    model String,
    request_id String,
    prompt_tokens UInt32,
    completion_tokens UInt32,
    total_tokens UInt32,
    request_duration_ms UInt32,
    status_code UInt16,
    endpoint String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (tenant_id, timestamp)
TTL timestamp + INTERVAL 90 DAY
SETTINGS index_granularity = 8192;

-- Create materialized view for hourly aggregations (optional, for faster queries)
CREATE MATERIALIZED VIEW IF NOT EXISTS token_usage_hourly
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (tenant_id, model, timestamp)
AS SELECT
    toStartOfHour(timestamp) as timestamp,
    tenant_id,
    model,
    sum(prompt_tokens) as prompt_tokens,
    sum(completion_tokens) as completion_tokens,
    sum(total_tokens) as total_tokens,
    count() as request_count,
    avg(request_duration_ms) as avg_duration_ms
FROM token_usage
GROUP BY tenant_id, model, timestamp;

