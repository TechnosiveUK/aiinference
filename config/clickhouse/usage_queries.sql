-- ClickHouse queries for usage tracking and limit enforcement
-- Used by usage service to check tenant limits and retrieve usage data

-- Get current month usage for a tenant
-- Used to check if tenant has exceeded their tier limit
CREATE OR REPLACE VIEW current_month_usage AS
SELECT
    tenant_id,
    sum(total_tokens) AS monthly_tokens,
    count() AS requests,
    avg(latency_ms) AS avg_latency,
    min(event_time) AS first_request,
    max(event_time) AS last_request
FROM llm_requests
WHERE event_time >= toStartOfMonth(now())
  AND success = 1
GROUP BY tenant_id;

-- Get daily usage for a tenant (last 30 days)
-- Used for usage dashboard
CREATE OR REPLACE VIEW tenant_daily_stats AS
SELECT
    tenant_id,
    toDate(event_time) AS date,
    sum(total_tokens) AS daily_tokens,
    sum(prompt_tokens) AS daily_prompt_tokens,
    sum(completion_tokens) AS daily_completion_tokens,
    count() AS daily_requests,
    avg(latency_ms) AS avg_latency,
    sum(CASE WHEN success = 0 THEN 1 ELSE 0 END) AS failed_requests
FROM llm_requests
WHERE event_time >= now() - INTERVAL 30 DAY
GROUP BY tenant_id, date
ORDER BY tenant_id, date DESC;

-- Get tier limits (static reference)
-- This should be maintained in application code, but useful for queries
CREATE TABLE IF NOT EXISTS tier_limits
(
    tier_name String,
    monthly_token_limit UInt64,
    rpm_limit UInt32,
    tpm_limit UInt64,
    max_context UInt32
)
ENGINE = Memory;

-- Insert tier limits (run once)
INSERT INTO tier_limits VALUES
('starter', 5000000, 60, 100000, 4096),
('pro', 25000000, 120, 250000, 8192),
('enterprise', 100000000, 300, 1000000, 16384);

-- Check if tenant has exceeded monthly limit
-- Returns: monthly_tokens, tier_limit, overage, percentage_used
CREATE OR REPLACE VIEW tenant_limit_check AS
SELECT
    u.tenant_id,
    u.monthly_tokens,
    t.monthly_token_limit,
    CASE 
        WHEN u.monthly_tokens > t.monthly_token_limit 
        THEN u.monthly_tokens - t.monthly_token_limit 
        ELSE 0 
    END AS overage,
    (u.monthly_tokens * 100.0 / t.monthly_token_limit) AS percentage_used,
    CASE 
        WHEN u.monthly_tokens >= t.monthly_token_limit 
        THEN 1 
        ELSE 0 
    END AS limit_exceeded
FROM current_month_usage u
LEFT JOIN tier_limits t ON t.tier_name = (
    SELECT plan_tier 
    FROM llm_requests 
    WHERE tenant_id = u.tenant_id 
    ORDER BY event_time DESC 
    LIMIT 1
);

-- Get usage summary for dashboard
-- Returns comprehensive stats for a tenant
CREATE OR REPLACE VIEW tenant_usage_summary AS
SELECT
    tenant_id,
    -- Current month
    (SELECT sum(total_tokens) FROM llm_requests 
     WHERE tenant_id = t.tenant_id 
       AND event_time >= toStartOfMonth(now())
       AND success = 1) AS current_month_tokens,
    -- Last 7 days
    (SELECT sum(total_tokens) FROM llm_requests 
     WHERE tenant_id = t.tenant_id 
       AND event_time >= now() - INTERVAL 7 DAY
       AND success = 1) AS last_7_days_tokens,
    -- Last 30 days
    (SELECT sum(total_tokens) FROM llm_requests 
     WHERE tenant_id = t.tenant_id 
       AND event_time >= now() - INTERVAL 30 DAY
       AND success = 1) AS last_30_days_tokens,
    -- Total requests
    (SELECT count() FROM llm_requests 
     WHERE tenant_id = t.tenant_id 
       AND event_time >= toStartOfMonth(now())) AS current_month_requests,
    -- Average latency
    (SELECT avg(latency_ms) FROM llm_requests 
     WHERE tenant_id = t.tenant_id 
       AND event_time >= toStartOfMonth(now())
       AND success = 1) AS avg_latency_ms,
    -- Success rate
    (SELECT (sum(success) * 100.0 / count()) FROM llm_requests 
     WHERE tenant_id = t.tenant_id 
       AND event_time >= toStartOfMonth(now())) AS success_rate
FROM (SELECT DISTINCT tenant_id FROM llm_requests) t;

