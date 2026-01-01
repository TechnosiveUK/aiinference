-- ClickHouse initialization for PrivaXAI production-grade tenant metering
-- Design: Append-only, high-volume writes, query-cheap aggregation, tenant-first billing

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS tensorzero;

-- Use the database
USE tensorzero;

-- Core table: llm_requests
-- Production-grade schema for tenant metering and billing
CREATE TABLE IF NOT EXISTS llm_requests
(
    event_time       DateTime64(3) DEFAULT now64(),
    request_id       UUID,
    tenant_id        String,
    user_id          String,
    api_key_id       String,

    model_name       String,
    model_version    String,
    provider         LowCardinality(String), -- ollama / vllm

    request_type     LowCardinality(String), -- chat / copilot / embedding
    prompt_tokens    UInt32,
    completion_tokens UInt32,
    total_tokens     UInt32,

    latency_ms       UInt32,
    success          UInt8,
    error_code       String,

    input_chars      UInt32,
    output_chars     UInt32,

    gpu_id           UInt8,
    node_id          String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (tenant_id, event_time)
TTL event_time + INTERVAL 18 MONTH
SETTINGS index_granularity = 8192;

-- Aggregated view for billing dashboards (daily tenant usage)
-- Optimized for fast billing queries without joins
CREATE MATERIALIZED VIEW IF NOT EXISTS tenant_daily_usage
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (tenant_id, date, model_name)
AS
SELECT
    tenant_id,
    toDate(event_time) AS date,
    model_name,
    sum(prompt_tokens) AS prompt_tokens,
    sum(completion_tokens) AS completion_tokens,
    sum(total_tokens) AS total_tokens,
    count() AS requests,
    avg(latency_ms) AS avg_latency
FROM llm_requests
WHERE success = 1
GROUP BY tenant_id, date, model_name;

-- Legacy table for backward compatibility (if needed)
-- Maps to new schema structure
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

