# Multi-Node Setup Guide

**Scaling PrivaXAI AI Stack across multiple GPU nodes**

## When to Scale

Add a second GPU node when:
- ✅ **Consistent >80% GPU utilization** on primary node
- ✅ **Regular queue delays >5 seconds**
- ✅ **Monthly tokens >100M** across all tenants
- ✅ **Concurrent users >25** regularly

## Architecture Overview

### Single Node (Current)
```
PrivaXAI Platform
    ↓
TensorZero Gateway (Node 1)
    ↓
Ollama/vLLM (Node 1, GPU 0)
```

### Multi-Node (Scaled)
```
PrivaXAI Platform
    ↓
Load Balancer (Nginx/Traefik)
    ↓
├─→ TensorZero Gateway (Node 1)
│       ↓
│   Ollama/vLLM (Node 1, GPU 0)
│
└─→ TensorZero Gateway (Node 2)
        ↓
    Ollama/vLLM (Node 2, GPU 0)
        ↓
    Shared ClickHouse (Node 1 or separate)
```

## Prerequisites

- **Node 1**: Existing setup (primary)
- **Node 2**: Fresh Ubuntu 24.04 LTS with NVIDIA T4
- **Shared Network**: Both nodes on same private network
- **Shared Storage**: For ClickHouse (or replicate)

## Setup Steps

### Step 1: Prepare Node 2

On Node 2, follow the same setup as Node 1:

```bash
# Install NVIDIA drivers
sudo apt update
sudo apt install -y nvidia-driver-535
sudo reboot

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install -y docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker

# Clone repository
sudo mkdir -p /opt/aiinference
sudo chown $USER:$USER /opt/aiinference
cd /opt/aiinference
git clone https://github.com/TechnosiveUK/aiinference.git .
```

### Step 2: Configure Node 2

Edit `docker-compose.yaml` on Node 2:

```yaml
services:
  # Only run inference services on Node 2
  ollama:
    # ... same config ...
    # Use different container name
    container_name: privaxai-ollama-node2

  # Don't run ClickHouse on Node 2 (use shared from Node 1)
  # clickhouse:
  #   ...

  # Gateway on Node 2
  tensorzero:
    container_name: privaxai-gateway-node2
    # Point to shared ClickHouse on Node 1
    environment:
      - CLICKHOUSE_URL=http://node1-ip:8123
```

### Step 3: Configure Shared ClickHouse

On Node 1, update ClickHouse to accept remote connections:

Edit `config/clickhouse/remote-access.xml`:

```xml
<clickhouse>
    <listen_host>0.0.0.0</listen_host>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
</clickhouse>
```

Update `docker-compose.yaml` on Node 1:

```yaml
clickhouse:
  ports:
    - "8123:8123"  # Expose for Node 2
    - "9000:9000"
  # Add network access
  networks:
    - ai-stack-internal
    - shared-network  # New network for cross-node
```

### Step 4: Setup Load Balancer

On a separate server or Node 1, setup Nginx:

```nginx
upstream ai_gateway {
    least_conn;  # Load balancing method
    server node1-ip:8000;
    server node2-ip:8000;
}

server {
    listen 80;
    server_name ai-stack.privaxai.com;

    location / {
        proxy_pass http://ai_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Preserve tenant headers
        proxy_set_header X-Tenant-ID $http_x_tenant_id;
        proxy_set_header X-User-ID $http_x_user_id;
        proxy_set_header X-Plan-Tier $http_x_plan_tier;
    }
}
```

### Step 5: Update PrivaXAI Platform

Point PrivaXAI platform to load balancer:

```python
# In PrivaXAI platform config
AI_STACK_URL = "http://load-balancer-ip"  # Instead of node1-ip:8000
```

## Alternative: DNS-Based Load Balancing

If using DNS:

```bash
# Add both nodes to DNS
ai-stack.privaxai.com  A  node1-ip
ai-stack.privaxai.com  A  node2-ip
```

DNS will round-robin between nodes.

## Monitoring Multi-Node Setup

### Check Node Status

```bash
# Node 1
docker compose ps
nvidia-smi

# Node 2
docker compose ps
nvidia-smi
```

### Check Load Distribution

Query ClickHouse for request distribution:

```sql
SELECT
    node_id,
    count() AS requests,
    sum(total_tokens) AS tokens
FROM llm_requests
WHERE event_time >= now() - INTERVAL 1 HOUR
GROUP BY node_id;
```

### Monitor GPU Utilization

```bash
# On each node
watch -n 1 nvidia-smi
```

## Cost Analysis

### Single Node
- **Cost**: ~$300/month
- **Capacity**: 130M tokens/month
- **Break-even**: ~£500/month revenue

### Two Nodes
- **Cost**: ~$600/month
- **Capacity**: 260M tokens/month
- **Break-even**: ~£1,000/month revenue

### ROI Calculation

```
Additional cost: $300/month
Additional capacity: 130M tokens/month
Additional revenue needed: £500/month (at current pricing)
```

**Break-even point**: When monthly revenue exceeds £1,000

## Scaling Strategy

### Phase 1: Single Node (Current)
- **Capacity**: 130M tokens/month
- **Users**: 20-30 concurrent
- **Revenue target**: £500-1,000/month

### Phase 2: Two Nodes (Scale Point)
- **Capacity**: 260M tokens/month
- **Users**: 40-60 concurrent
- **Revenue target**: £1,000-2,000/month

### Phase 3: Three+ Nodes (Enterprise)
- **Capacity**: 390M+ tokens/month
- **Users**: 60-90+ concurrent
- **Revenue target**: £2,000+/month

## Health Checks

### Automated Health Monitoring

Create `scripts/check-nodes.sh`:

```bash
#!/bin/bash
# Check all nodes are healthy

NODES=("node1-ip" "node2-ip")

for NODE in "${NODES[@]}"; do
    echo "Checking $NODE..."
    
    # Check gateway
    if curl -f http://$NODE:8000/health &>/dev/null; then
        echo "✓ Gateway healthy"
    else
        echo "✗ Gateway unhealthy"
    fi
    
    # Check GPU
    ssh $NODE "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader"
done
```

## Failover Strategy

### Automatic Failover

Configure load balancer for health checks:

```nginx
upstream ai_gateway {
    server node1-ip:8000 max_fails=3 fail_timeout=30s;
    server node2-ip:8000 max_fails=3 fail_timeout=30s backup;
}
```

If Node 1 fails, traffic automatically routes to Node 2.

### Manual Failover

If a node fails:

1. **Remove from load balancer**
2. **Check logs**: `docker compose logs` on failed node
3. **Restart services**: `docker compose restart`
4. **Re-add to load balancer** when healthy

## Data Consistency

### ClickHouse Replication (Optional)

For high availability, replicate ClickHouse:

```yaml
# On Node 1
clickhouse:
  environment:
    - CLICKHOUSE_REPLICATION=true
    - CLICKHOUSE_REPLICA=node1

# On Node 2 (or separate DB node)
clickhouse:
  environment:
    - CLICKHOUSE_REPLICATION=true
    - CLICKHOUSE_REPLICA=node2
```

## Best Practices

1. **Monitor GPU utilization** - Scale before hitting 90%
2. **Balance load evenly** - Use least_conn or round-robin
3. **Keep ClickHouse centralized** - Easier to query and maintain
4. **Use health checks** - Automatic failover
5. **Track per-node metrics** - Identify bottlenecks

## Troubleshooting

### Node Not Receiving Traffic

```bash
# Check load balancer config
nginx -t

# Check node health
curl http://node-ip:8000/health

# Check network connectivity
ping node-ip
```

### ClickHouse Connection Issues

```bash
# Test connection from Node 2 to Node 1
curl http://node1-ip:8123

# Check ClickHouse logs
docker compose logs clickhouse
```

### Uneven Load Distribution

- Check health of both nodes
- Verify load balancer configuration
- Monitor request distribution in ClickHouse

---

**Next**: Once you have 2+ nodes, consider Kubernetes for orchestration.

