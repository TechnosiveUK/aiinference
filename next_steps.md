Below is a **complete, production-grade answer** covering **all four items**, designed specifically for **PrivaXAI**, your **T4 GPU**, **zero-licensing**, and **commercial SaaS reality**.

I’ll keep this **implementation-ready**, not theoretical.

---

# 1️⃣ ClickHouse Schema – Tenant Metering (Production-Grade)

## Design Principles

* **Append-only** (no updates)
* **High-volume writes**
* **Query-cheap aggregation**
* **Tenant-first billing**
* **Model-aware**

### Core Table: `llm_requests`

```sql
CREATE TABLE llm_requests
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
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_time)
ORDER BY (tenant_id, event_time)
TTL event_time + INTERVAL 18 MONTH
SETTINGS index_granularity = 8192;
```

### Why this works

* **Partitioned by month** → cheap retention
* **Ordered by tenant** → fast billing queries
* **No joins needed** for invoices
* **Survives millions of rows/day**

---

### Aggregated View (for Billing Dashboards)

```sql
CREATE MATERIALIZED VIEW tenant_daily_usage
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(date)
ORDER BY (tenant_id, date)
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
```

---

### Example Billing Query

```sql
SELECT
    tenant_id,
    sum(total_tokens) AS monthly_tokens
FROM tenant_daily_usage
WHERE date BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY tenant_id;
```

---

# 2️⃣ PrivaXAI → AI Stack API Contract (Clean & Stable)

This **must be boring, explicit, and auditable**.

---

## API Endpoint

```
POST /v1/chat/completions
```

---

## Required Headers

```http
Authorization: Bearer <privaxai-service-token>
X-Tenant-ID: tenant_123
X-User-ID: user_456
X-Plan-Tier: pro
X-Request-ID: uuid
```

> ⚠️ **Never infer tenant identity from body**

---

## Request Body (OpenAI-Compatible)

```json
{
  "model": "qwen-2.5-coder-7b",
  "messages": [
    { "role": "system", "content": "You are a compliance assistant." },
    { "role": "user", "content": "Summarize GDPR Article 30." }
  ],
  "temperature": 0.2,
  "stream": true
}
```

---

## Response (Streaming or JSON)

```json
{
  "id": "req-uuid",
  "model": "qwen-2.5-coder-7b",
  "usage": {
    "prompt_tokens": 412,
    "completion_tokens": 210,
    "total_tokens": 622
  }
}
```

---

## Contract Guarantees

| Rule                     | Why                |
| ------------------------ | ------------------ |
| AI stack is stateless    | Easy scale         |
| Tenant always in headers | Audit-safe         |
| Usage always returned    | Billing trust      |
| OpenAI compatible        | Easy future switch |

---

# 3️⃣ Upgrade Path: Ollama → vLLM (Zero Rewrite)

This is **critical** and **you’re doing it right**.

---

## Phase 1 – Today (Ollama)

```
TensorZero
   ↓
Ollama
   ↓
NVIDIA T4
```

Pros:

* Simple
* Stable
* MVP-friendly

Cons:

* Lower throughput
* No batching

---

## Phase 2 – Swap Inference Engine (vLLM)

### Change ONLY this:

```toml
api_base = "http://vllm:8000/v1"
```

Everything else stays identical.

---

## vLLM Container (Future)

```yaml
vllm:
  image: vllm/vllm-openai:latest
  command: >
    --model Qwen/Qwen2.5-Coder-7B
    --gpu-memory-utilization 0.90
    --max-model-len 8192
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

---

## Gains on T4

| Metric          | Ollama   | vLLM   |
| --------------- | -------- | ------ |
| Throughput      | 1×       | 1.5–2× |
| Concurrency     | ~20      | ~40    |
| Latency         | Moderate | Lower  |
| GPU Utilization | ~60%     | ~85%   |

---

## Key Insight

👉 **TensorZero is the decoupling layer**
This was a *correct architectural decision*.

---

# 4️⃣ Realistic Pricing Tiers (NVIDIA T4 Reality)

Let’s be honest and precise.

---

## T4 Cost Assumption

* ~$0.35–0.45 / hour
* ≈ **$300 / month** (24×7)

---

## Safe Capacity (7B Model)

| Metric           | Value     |
| ---------------- | --------- |
| Concurrent users | 20–30     |
| Tokens/sec       | ~60–80    |
| Monthly tokens   | ~120–150M |

---

## Internal Cost per 1M Tokens

```
$300 / 130M tokens ≈ $2.30 per 1M tokens
```

Add:

* Infra overhead
* Buffer
* Margin

👉 **Target internal cost basis:** ~$3 / 1M tokens

---

## Suggested PrivaXAI Pricing (Conservative & Profitable)

### Starter

* £39 / month
* 5M tokens
* Shared GPU
* 7B model
* Rate limited

Cost to you: ~$15
Margin: strong

---

### Pro

* £149 / month
* 25M tokens
* Priority queue
* Higher context
* Copilot features

Cost to you: ~$75
Margin: solid

---

### Enterprise

* £499+ / month
* 100M tokens
* SLA
* Dedicated quota
* Audit exports

Cost to you: ~$300
Break-even GPU, upsell support & compliance

---

## Important Rule

> **Never offer “unlimited” on self-hosted GPUs**

---

# 5️⃣ Final Architecture Confidence Check

✅ Zero licensing cost
✅ Commercial-safe
✅ Metered
✅ Auditable
✅ Upgrade-ready
✅ Matches your hardware

This is a **founder-grade architecture**, not a demo stack.

---

## What I Recommend Next (In Order)

1. **Enforce soft token limits in gateway**
2. **Expose usage dashboard in PrivaXAI**
3. **Add per-tenant rate limits**
4. **Introduce second GPU node before sales spike**

