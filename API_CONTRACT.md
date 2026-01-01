# PrivaXAI → AI Stack API Contract

**Clean, explicit, and auditable API contract for production use**

## Endpoint

```
POST /v1/chat/completions
```

## Required Headers

```http
Authorization: Bearer <privaxai-service-token>
X-Tenant-ID: tenant_123
X-User-ID: user_456
X-Plan-Tier: pro
X-Request-ID: uuid
```

> ⚠️ **Never infer tenant identity from body** - Always use headers for audit safety

## Request Body (OpenAI-Compatible)

```json
{
  "model": "qwen-2.5-coder-7b",
  "messages": [
    { "role": "system", "content": "You are a compliance assistant." },
    { "role": "user", "content": "Summarize GDPR Article 30." }
  ],
  "temperature": 0.2,
  "max_tokens": 512,
  "stream": true
}
```

## Response (Streaming or JSON)

### Non-Streaming Response

```json
{
  "id": "req-uuid",
  "object": "chat.completion",
  "created": 1704067200,
  "model": "qwen-2.5-coder-7b",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "GDPR Article 30 requires..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 412,
    "completion_tokens": 210,
    "total_tokens": 622
  }
}
```

### Streaming Response

```
data: {"id":"req-uuid","object":"chat.completion.chunk","choices":[{"delta":{"content":"GDPR"},"index":0}]}

data: {"id":"req-uuid","object":"chat.completion.chunk","choices":[{"delta":{"content":" Article"},"index":0}]}

data: [DONE]
```

## Contract Guarantees

| Rule                     | Why                |
| ------------------------ | ------------------ |
| AI stack is stateless    | Easy scale         |
| Tenant always in headers | Audit-safe         |
| Usage always returned    | Billing trust      |
| OpenAI compatible        | Easy future switch |

## Error Responses

### 400 Bad Request
```json
{
  "error": {
    "message": "Missing required header: X-Tenant-ID",
    "type": "invalid_request_error",
    "code": "missing_header"
  }
}
```

### 401 Unauthorized
```json
{
  "error": {
    "message": "Invalid or missing authorization token",
    "type": "authentication_error",
    "code": "invalid_token"
  }
}
```

### 429 Too Many Requests
```json
{
  "error": {
    "message": "Rate limit exceeded. Limit: 60 requests/minute",
    "type": "rate_limit_error",
    "code": "rate_limit_exceeded"
  }
}
```

### 500 Internal Server Error
```json
{
  "error": {
    "message": "Internal server error",
    "type": "server_error",
    "code": "internal_error"
  }
}
```

## Usage Tracking

All requests are automatically logged to ClickHouse with:
- Tenant ID
- User ID
- Request ID
- Token counts
- Latency
- Success/failure status
- Model information

This enables:
- Per-tenant billing
- Usage analytics
- Audit trails
- Performance monitoring

## Example cURL Request

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-service-token" \
  -H "X-Tenant-ID: tenant_123" \
  -H "X-User-ID: user_456" \
  -H "X-Plan-Tier: pro" \
  -H "X-Request-ID: $(uuidgen)" \
  -d '{
    "model": "qwen-2.5-coder-7b",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 100
  }'
```

## Integration with PrivaXAI Platform

The PrivaXAI platform should:

1. **Always include headers** - Never rely on body for tenant identification
2. **Generate request IDs** - Use UUIDs for request tracking
3. **Handle streaming** - Support both streaming and non-streaming responses
4. **Track usage** - Store token counts from response for billing
5. **Handle errors gracefully** - Implement retry logic for transient errors

## Rate Limiting

Rate limits are enforced per tenant based on plan tier:

- **Starter**: 60 requests/minute, 100k tokens/minute
- **Pro**: 120 requests/minute, 250k tokens/minute
- **Enterprise**: 300 requests/minute, 1M tokens/minute

Rate limit headers are included in responses:
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1704067260
```

