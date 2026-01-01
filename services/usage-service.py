#!/usr/bin/env python3
"""
PrivaXAI Usage Service
Purpose: Enforce token limits and provide usage dashboard API
Runs as a sidecar service alongside TensorZero gateway
"""

from flask import Flask, request, jsonify
from clickhouse_driver import Client
from datetime import datetime, timedelta
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ClickHouse connection
CLICKHOUSE_HOST = os.getenv('CLICKHOUSE_HOST', 'clickhouse')
CLICKHOUSE_PORT = int(os.getenv('CLICKHOUSE_PORT', '9000'))
CLICKHOUSE_DB = os.getenv('CLICKHOUSE_DB', 'tensorzero')

client = Client(host=CLICKHOUSE_HOST, port=CLICKHOUSE_PORT, database=CLICKHOUSE_DB)

# Tier limits (matches PRICING_TIERS.md)
TIER_LIMITS = {
    'starter': {
        'monthly_tokens': 5_000_000,
        'rpm': 60,
        'tpm': 100_000,
        'max_context': 4096
    },
    'pro': {
        'monthly_tokens': 25_000_000,
        'rpm': 120,
        'tpm': 250_000,
        'max_context': 8192
    },
    'enterprise': {
        'monthly_tokens': 100_000_000,
        'rpm': 300,
        'tpm': 1_000_000,
        'max_context': 16384
    }
}

def get_current_month_usage(tenant_id: str) -> int:
    """Get current month token usage for a tenant"""
    query = """
    SELECT sum(total_tokens) AS monthly_tokens
    FROM llm_requests
    WHERE tenant_id = %(tenant_id)s
      AND event_time >= toStartOfMonth(now())
      AND success = 1
    """
    result = client.execute(query, {'tenant_id': tenant_id})
    return result[0][0] if result and result[0][0] else 0

def check_token_limit(tenant_id: str, plan_tier: str) -> dict:
    """
    Check if tenant has exceeded monthly token limit
    Returns: {
        'allowed': bool,
        'monthly_tokens': int,
        'tier_limit': int,
        'percentage_used': float,
        'overage': int
    }
    """
    tier_limit = TIER_LIMITS.get(plan_tier.lower(), TIER_LIMITS['starter'])
    monthly_tokens = get_current_month_usage(tenant_id)
    tier_limit_tokens = tier_limit['monthly_tokens']
    
    percentage_used = (monthly_tokens / tier_limit_tokens * 100) if tier_limit_tokens > 0 else 0
    overage = max(0, monthly_tokens - tier_limit_tokens)
    allowed = monthly_tokens < tier_limit_tokens
    
    return {
        'allowed': allowed,
        'monthly_tokens': monthly_tokens,
        'tier_limit': tier_limit_tokens,
        'percentage_used': round(percentage_used, 2),
        'overage': overage
    }

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    try:
        client.execute('SELECT 1')
        return jsonify({'status': 'healthy', 'clickhouse': 'connected'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

@app.route('/api/v1/usage/check', methods=['POST'])
def check_usage():
    """
    Check if tenant can make a request (token limit enforcement)
    Expected JSON: {
        'tenant_id': 'tenant_123',
        'plan_tier': 'pro',
        'estimated_tokens': 1000  # optional
    }
    """
    data = request.get_json()
    tenant_id = data.get('tenant_id')
    plan_tier = data.get('plan_tier', 'starter')
    estimated_tokens = data.get('estimated_tokens', 0)
    
    if not tenant_id:
        return jsonify({'error': 'tenant_id required'}), 400
    
    limit_check = check_token_limit(tenant_id, plan_tier)
    
    # Check if adding estimated tokens would exceed limit
    if estimated_tokens > 0:
        projected = limit_check['monthly_tokens'] + estimated_tokens
        tier_limit = limit_check['tier_limit']
        if projected >= tier_limit:
            limit_check['allowed'] = False
            limit_check['would_exceed'] = True
    
    return jsonify(limit_check), 200 if limit_check['allowed'] else 429

@app.route('/api/v1/usage/<tenant_id>', methods=['GET'])
def get_usage(tenant_id: str):
    """
    Get usage statistics for a tenant
    Query params: ?period=month|week|day
    """
    period = request.args.get('period', 'month')
    
    if period == 'month':
        start_date = datetime.now().replace(day=1)
    elif period == 'week':
        start_date = datetime.now() - timedelta(days=7)
    elif period == 'day':
        start_date = datetime.now() - timedelta(days=1)
    else:
        return jsonify({'error': 'Invalid period. Use: month, week, or day'}), 400
    
    query = """
    SELECT
        sum(total_tokens) AS total_tokens,
        sum(prompt_tokens) AS prompt_tokens,
        sum(completion_tokens) AS completion_tokens,
        count() AS requests,
        avg(latency_ms) AS avg_latency,
        sum(CASE WHEN success = 0 THEN 1 ELSE 0 END) AS failed_requests
    FROM llm_requests
    WHERE tenant_id = %(tenant_id)s
      AND event_time >= %(start_date)s
    """
    
    result = client.execute(query, {
        'tenant_id': tenant_id,
        'start_date': start_date
    })
    
    if not result:
        return jsonify({
            'tenant_id': tenant_id,
            'period': period,
            'total_tokens': 0,
            'requests': 0,
            'avg_latency': 0
        }), 200
    
    row = result[0]
    return jsonify({
        'tenant_id': tenant_id,
        'period': period,
        'total_tokens': row[0] or 0,
        'prompt_tokens': row[1] or 0,
        'completion_tokens': row[2] or 0,
        'requests': row[3] or 0,
        'avg_latency_ms': round(row[4] or 0, 2),
        'failed_requests': row[5] or 0
    }), 200

@app.route('/api/v1/usage/<tenant_id>/daily', methods=['GET'])
def get_daily_usage(tenant_id: str):
    """Get daily usage for last 30 days"""
    query = """
    SELECT
        toDate(event_time) AS date,
        sum(total_tokens) AS daily_tokens,
        count() AS requests,
        avg(latency_ms) AS avg_latency
    FROM llm_requests
    WHERE tenant_id = %(tenant_id)s
      AND event_time >= now() - INTERVAL 30 DAY
      AND success = 1
    GROUP BY date
    ORDER BY date DESC
    """
    
    result = client.execute(query, {'tenant_id': tenant_id})
    
    daily_data = [
        {
            'date': str(row[0]),
            'tokens': row[1] or 0,
            'requests': row[2] or 0,
            'avg_latency_ms': round(row[3] or 0, 2)
        }
        for row in result
    ]
    
    return jsonify({
        'tenant_id': tenant_id,
        'daily_usage': daily_data
    }), 200

@app.route('/api/v1/usage/<tenant_id>/limit', methods=['GET'])
def get_limit_info(tenant_id: str):
    """Get current usage and limit information"""
    plan_tier = request.args.get('plan_tier', 'starter')
    
    limit_check = check_token_limit(tenant_id, plan_tier)
    tier_info = TIER_LIMITS.get(plan_tier.lower(), TIER_LIMITS['starter'])
    
    return jsonify({
        'tenant_id': tenant_id,
        'plan_tier': plan_tier,
        'current_usage': {
            'monthly_tokens': limit_check['monthly_tokens'],
            'percentage_used': limit_check['percentage_used'],
            'overage': limit_check['overage']
        },
        'tier_limits': tier_info,
        'limit_exceeded': not limit_check['allowed']
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)

