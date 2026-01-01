# Pricing Tiers & Rate Limiting Configuration

**Realistic pricing tiers based on NVIDIA T4 capacity and costs**

## T4 Cost Basis

- **GPU Cost**: ~$0.35–0.45 / hour
- **Monthly Cost** (24×7): ≈ **$300 / month**
- **Safe Capacity** (7B model):
  - Concurrent users: 20–30
  - Tokens/sec: ~60–80
  - Monthly tokens: ~120–150M

## Internal Cost Calculation

```
$300 / 130M tokens ≈ $2.30 per 1M tokens
```

Adding infrastructure overhead, buffer, and margin:
👉 **Target internal cost basis: ~$3 / 1M tokens**

## Recommended Pricing Tiers

### Starter Tier

- **Price**: £39 / month
- **Tokens**: 5M tokens
- **Features**:
  - Shared GPU
  - 7B model
  - Rate limited
  - Standard support

**Cost to you**: ~$15  
**Margin**: Strong (60%+)

**Rate Limits**:
- Requests: 60/minute
- Tokens: 100k/minute
- Max context: 4k tokens

### Pro Tier

- **Price**: £149 / month
- **Tokens**: 25M tokens
- **Features**:
  - Priority queue
  - Higher context (8k tokens)
  - Copilot features
  - Email support

**Cost to you**: ~$75  
**Margin**: Solid (50%+)

**Rate Limits**:
- Requests: 120/minute
- Tokens: 250k/minute
- Max context: 8k tokens

### Enterprise Tier

- **Price**: £499+ / month
- **Tokens**: 100M tokens
- **Features**:
  - SLA guarantees
  - Dedicated quota
  - Audit exports
  - Priority support
  - Custom integrations

**Cost to you**: ~$300  
**Break-even on GPU**, upsell support & compliance

**Rate Limits**:
- Requests: 300/minute
- Tokens: 1M/minute
- Max context: 16k tokens

## Important Rule

> **Never offer "unlimited" on self-hosted GPUs**

Hard limits prevent cost overruns and ensure fair resource allocation.

## Rate Limiting Configuration

### TensorZero Configuration

Update `config/tensorzero.toml`:

```toml
[rate_limiting]
enabled = true

# Per-tier rate limits
[rate_limiting.tiers.starter]
rpm = 60          # requests per minute
tpm = 100000      # tokens per minute
max_context = 4096

[rate_limiting.tiers.pro]
rpm = 120
tpm = 250000
max_context = 8192

[rate_limiting.tiers.enterprise]
rpm = 300
tpm = 1000000
max_context = 16384

# Default (fallback)
default_rpm = 60
default_tpm = 100000
```

### Per-Tenant Rate Limiting

Rate limits are enforced based on `X-Plan-Tier` header:

```http
X-Plan-Tier: starter  # Uses starter tier limits
X-Plan-Tier: pro       # Uses pro tier limits
X-Plan-Tier: enterprise # Uses enterprise tier limits
```

## Usage Monitoring

### Daily Usage Query

```sql
SELECT
    tenant_id,
    sum(total_tokens) AS daily_tokens,
    count() AS requests
FROM llm_requests
WHERE event_time >= today()
  AND tenant_id = 'tenant_123'
GROUP BY tenant_id;
```

### Monthly Billing Query

```sql
SELECT
    tenant_id,
    sum(total_tokens) AS monthly_tokens,
    count() AS requests,
    avg(latency_ms) AS avg_latency
FROM tenant_daily_usage
WHERE date BETWEEN '2026-01-01' AND '2026-01-31'
  AND tenant_id = 'tenant_123'
GROUP BY tenant_id;
```

### Overage Detection

```sql
-- Find tenants exceeding their tier limits
SELECT
    tenant_id,
    plan_tier,
    sum(total_tokens) AS monthly_tokens,
    CASE plan_tier
        WHEN 'starter' THEN 5000000
        WHEN 'pro' THEN 25000000
        WHEN 'enterprise' THEN 100000000
    END AS tier_limit,
    sum(total_tokens) - CASE plan_tier
        WHEN 'starter' THEN 5000000
        WHEN 'pro' THEN 25000000
        WHEN 'enterprise' THEN 100000000
    END AS overage
FROM llm_requests
WHERE event_time >= toStartOfMonth(now())
GROUP BY tenant_id, plan_tier
HAVING overage > 0;
```

## Scaling Considerations

### When to Add Second GPU Node

Add a second T4 node when:
- **Consistent >80% GPU utilization**
- **Regular queue delays >5 seconds**
- **Monthly tokens >100M across all tenants**

### Cost per Additional Node

- **Hardware**: ~$300/month
- **Capacity**: +130M tokens/month
- **Break-even**: ~£500/month in additional revenue

## Billing Integration

### PrivaXAI Platform Integration

The PrivaXAI platform should:

1. **Track usage** - Query ClickHouse for token counts
2. **Enforce limits** - Check tier limits before requests
3. **Handle overages** - Charge per 1M tokens over limit
4. **Generate invoices** - Use monthly usage data
5. **Alert on limits** - Notify users at 80% of tier limit

### Overage Pricing

- **Overage rate**: £5 / 1M tokens
- **Applied when**: Monthly usage exceeds tier limit
- **Billed**: Next billing cycle

## Example Billing Calculation

**Starter Tier User:**
- Monthly tokens: 6M (1M over limit)
- Base cost: £39
- Overage: 1M × £5 = £5
- **Total**: £44

**Pro Tier User:**
- Monthly tokens: 20M (under limit)
- **Total**: £149 (no overage)

## Monitoring Dashboard Queries

### Top Tenants

```sql
SELECT
    tenant_id,
    sum(total_tokens) AS total_tokens,
    count() AS requests,
    avg(latency_ms) AS avg_latency
FROM llm_requests
WHERE event_time >= toStartOfMonth(now())
GROUP BY tenant_id
ORDER BY total_tokens DESC
LIMIT 10;
```

### Revenue Projection

```sql
SELECT
    plan_tier,
    count(DISTINCT tenant_id) AS tenant_count,
    sum(total_tokens) AS total_tokens,
    CASE plan_tier
        WHEN 'starter' THEN count(DISTINCT tenant_id) * 39
        WHEN 'pro' THEN count(DISTINCT tenant_id) * 149
        WHEN 'enterprise' THEN count(DISTINCT tenant_id) * 499
    END AS monthly_revenue
FROM llm_requests
WHERE event_time >= toStartOfMonth(now())
GROUP BY plan_tier;
```

