Below is a **Cursor-ready, copy-paste prompt** tailored **exactly** to your hardware and to **power the PrivaXAI platform** as a **commercial, zero-license-cost AI stack**.

I’ll first answer the **workspace decision**, then give you the **Cursor prompt**.

---

## 1️⃣ Workspace Decision (Very Important)

### ✅ **Use a SEPARATE “AI Inference Stack” workspace**

**Do NOT deploy this inside the core PrivaXAI workspace.**

### Why (non-negotiable for your scale & vision):

| Reason                        | Explanation                           |
| ----------------------------- | ------------------------------------- |
| **Fault isolation**           | GPU crashes ≠ platform outage         |
| **Independent scaling**       | AI stack evolves faster than core app |
| **Security boundary**         | Inference ≠ business logic            |
| **Future multi-platform use** | You already plan this                 |
| **Cleaner billing/metering**  | Tokens ≠ API requests                 |
| **Kubernetes readiness**      | Clean migration later                 |

### Recommended layout

```
privaxai-platform/        ← Core SaaS (auth, tenants, UI)
privaxai-ai-stack/        ← GPU inference + metering
```

👉 **PrivaXAI calls the AI stack over private network only.**

---

## 2️⃣ Hardware-Aware Design (NVIDIA T4 Reality)

Your **NVIDIA T4 (16GB VRAM)** means:

| Capability       | Decision                   |
| ---------------- | -------------------------- |
| Max safe model   | **7B (primary)**           |
| Concurrent users | ~20–30                     |
| Context size     | 8k–16k max                 |
| Inference engine | Ollama (now), vLLM (later) |
| Embeddings       | CPU-based (not GPU)        |

This is **perfect for MVP → early commercial SaaS**.

---

## 3️⃣ Cursor Prompt – AI Stack Deployment for PrivaXAI

> 📌 **Paste this directly into Cursor**
> (Workspace: `privaxai-ai-stack`)

---

### 🎯 CURSOR PROMPT START

```
You are a Senior Platform Engineer and MLOps Architect.

Goal:
Deploy a production-grade, zero-licensing-cost AI inference stack to power the PrivaXAI SaaS platform using the following hardware:

- OS: Ubuntu Server 24.04 LTS
- CPU: 8 cores
- RAM: 32 GiB
- GPU: NVIDIA T4 (16GB VRAM)
- Disk: 50 GiB SSD

Constraints:
- Commercial SaaS usage
- No paid or restrictive licenses
- GPU is shared across tenants
- Stack must be isolated from core PrivaXAI platform
- Must support future migration to Kubernetes
- Must support usage metering and rate limiting

Architecture Requirements:
- Ollama for GPU inference (initial phase)
- Qwen 2.5 Coder 7B as primary model
- TensorZero as LLM Gateway (routing, observability)
- ClickHouse for telemetry and token usage
- Postgres (external, optional) for future RAG
- No public exposure of inference or telemetry services
- Nginx reverse proxy ready (but not exposed yet)
- Docker Compose (v2)
- NVIDIA Container Toolkit enabled

Tasks:
1. Validate NVIDIA driver compatibility for Ubuntu 24.04 + T4
2. Install NVIDIA Container Toolkit
3. Create a secure directory structure:
   - config/
   - ollama/
   - clickhouse_data/
   - logs/
4. Generate `tensorzero.toml` configured for:
   - Qwen 2.5 Coder 7B
   - Chat + Copilot use cases
   - Future multi-model routing
5. Generate a production-ready `docker-compose.yaml` with:
   - restart policies
   - internal networking
   - GPU reservations
   - health checks
6. Ensure:
   - Ollama and ClickHouse are NOT publicly exposed
   - Only Gateway API is accessible internally
7. Provide startup and verification commands:
   - Model pull
   - GPU verification
   - Health checks
8. Include security notes:
   - Firewall ports
   - Network isolation
9. Add comments explaining:
   - Why each component exists
   - How PrivaXAI platform should call this stack
10. Ensure everything fits within:
    - 32GB RAM
    - 16GB VRAM
    - 50GB disk

Output format:
- Clear file tree
- Full config files
- Full docker-compose.yaml
- Shell commands
- Short operational notes (no marketing text)

Assume:
- This stack will be used by PrivaXAI via private API
- Tenant identity is passed via headers (x-tenant-id)
- Rate limiting will be enforced at gateway layer later

Do NOT:
- Use paid services
- Use cloud-managed offerings
- Expose internal ports publicly
- Over-engineer Kubernetes (this is VPS phase)

Proceed.
```

### 🎯 CURSOR PROMPT END

---

## 4️⃣ Why This Will Work Well for PrivaXAI

### ✅ Aligned with your product

* RegTech / Compliance Copilot
* Predictable usage patterns
* Auditability

### ✅ Cost-safe

* One T4 ≈ controlled concurrency
* No token leakage
* No vendor billing surprises

### ✅ Clean evolution path

| Phase       | Change              |
| ----------- | ------------------- |
| Scale       | Add second GPU node |
| Performance | Ollama → vLLM       |
| Control     | Per-tenant quotas   |
| Enterprise  | Dedicated GPU pools |

---


