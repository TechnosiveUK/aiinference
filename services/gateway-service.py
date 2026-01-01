#!/usr/bin/env python3
"""
PrivaXAI LLM Gateway Service
Purpose: Routes requests to Ollama, handles tenant headers, logs to ClickHouse
Replaces TensorZero (which doesn't exist as a Docker image)
"""

from flask import Flask, request, jsonify, Response, stream_with_context
from clickhouse_driver import Client
import requests
import os
import logging
import uuid
from datetime import datetime
import json

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
OLLAMA_URL = os.getenv('OLLAMA_URL', 'http://ollama:11434')
CLICKHOUSE_HOST = os.getenv('CLICKHOUSE_HOST', 'clickhouse')
CLICKHOUSE_PORT = int(os.getenv('CLICKHOUSE_PORT', '9000'))
CLICKHOUSE_DB = os.getenv('CLICKHOUSE_DB', 'tensorzero')

# ClickHouse client
try:
    ch_client = Client(host=CLICKHOUSE_HOST, port=CLICKHOUSE_PORT, database=CLICKHOUSE_DB)
except Exception as e:
    logger.warning(f"ClickHouse connection failed: {e}. Logging will be disabled.")
    ch_client = None

def log_request(tenant_id, user_id, plan_tier, request_id, model, prompt_tokens, completion_tokens, total_tokens, latency_ms, success, error_code=None):
    """Log request to ClickHouse"""
    if not ch_client:
        return
    
    try:
        ch_client.execute(
            """
            INSERT INTO llm_requests (
                event_time, request_id, tenant_id, user_id, api_key_id,
                model_name, model_version, provider, request_type,
                prompt_tokens, completion_tokens, total_tokens,
                latency_ms, success, error_code, input_chars, output_chars,
                gpu_id, node_id
            ) VALUES
            """,
            [(
                datetime.now(),
                uuid.UUID(request_id) if request_id else uuid.uuid4(),
                tenant_id or '',
                user_id or '',
                '',
                model or 'qwen2.5-coder:7b',
                '',
                'ollama',
                'chat',
                prompt_tokens or 0,
                completion_tokens or 0,
                total_tokens or 0,
                latency_ms or 0,
                1 if success else 0,
                error_code or '',
                0,
                0,
                0,
                'node1'
            )]
        )
    except Exception as e:
        logger.error(f"Failed to log to ClickHouse: {e}")

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'privaxai-gateway'}), 200

@app.route('/v1/models', methods=['GET'])
def list_models():
    """List available models"""
    try:
        response = requests.get(f'{OLLAMA_URL}/api/tags', timeout=5)
        if response.status_code == 200:
            models = response.json().get('models', [])
            return jsonify({
                'object': 'list',
                'data': [
                    {
                        'id': model.get('name', ''),
                        'object': 'model',
                        'created': model.get('modified_at', 0),
                        'owned_by': 'privaxai'
                    }
                    for model in models
                ]
            }), 200
        return jsonify({'error': 'Failed to fetch models'}), 500
    except Exception as e:
        logger.error(f"Error listing models: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/v1/chat/completions', methods=['POST'])
def chat_completions():
    """Handle chat completion requests"""
    start_time = datetime.now()
    request_id = request.headers.get('X-Request-ID') or str(uuid.uuid4())
    tenant_id = request.headers.get('X-Tenant-ID')
    user_id = request.headers.get('X-User-ID')
    plan_tier = request.headers.get('X-Plan-Tier', 'starter')
    
    if not tenant_id:
        return jsonify({
            'error': {
                'message': 'Missing required header: X-Tenant-ID',
                'type': 'invalid_request_error',
                'code': 'missing_header'
            }
        }), 400
    
    try:
        data = request.get_json()
        model = data.get('model', 'qwen2.5-coder:7b')
        messages = data.get('messages', [])
        stream = data.get('stream', False)
        max_tokens = data.get('max_tokens', 512)
        temperature = data.get('temperature', 0.7)
        
        # Convert to Ollama format
        ollama_prompt = "\n".join([f"{msg['role']}: {msg['content']}" for msg in messages])
        
        ollama_data = {
            'model': model,
            'prompt': ollama_prompt,
            'stream': stream,
            'options': {
                'num_predict': max_tokens,
                'temperature': temperature
            }
        }
        
        # Make request to Ollama
        ollama_url = f'{OLLAMA_URL}/api/generate' if not stream else f'{OLLAMA_URL}/api/generate'
        response = requests.post(ollama_url, json=ollama_data, stream=stream, timeout=300)
        
        if response.status_code != 200:
            error_msg = response.text
            latency_ms = int((datetime.now() - start_time).total_seconds() * 1000)
            log_request(tenant_id, user_id, plan_tier, request_id, model, 0, 0, 0, latency_ms, False, error_code=str(response.status_code))
            return jsonify({'error': error_msg}), response.status_code
        
        if stream:
            def generate():
                full_response = ""
                for line in response.iter_lines():
                    if line:
                        try:
                            chunk = json.loads(line)
                            content = chunk.get('response', '')
                            full_response += content
                            if chunk.get('done', False):
                                # Final chunk with usage
                                latency_ms = int((datetime.now() - start_time).total_seconds() * 1000)
                                # Estimate tokens (rough: 1 token ≈ 4 chars)
                                total_tokens = len(full_response) // 4
                                log_request(tenant_id, user_id, plan_tier, request_id, model, 0, total_tokens, total_tokens, latency_ms, True)
                                yield f"data: {json.dumps({'done': True, 'usage': {'total_tokens': total_tokens}})}\n\n"
                            else:
                                yield f"data: {json.dumps({'choices': [{'delta': {'content': content}}]})}\n\n"
                        except json.JSONDecodeError:
                            continue
                yield "data: [DONE]\n\n"
            
            return Response(stream_with_context(generate()), mimetype='text/event-stream')
        else:
            result = response.json()
            latency_ms = int((datetime.now() - start_time).total_seconds() * 1000)
            response_text = result.get('response', '')
            # Estimate tokens
            total_tokens = len(response_text) // 4
            log_request(tenant_id, user_id, plan_tier, request_id, model, 0, total_tokens, total_tokens, latency_ms, True)
            
            return jsonify({
                'id': request_id,
                'object': 'chat.completion',
                'created': int(datetime.now().timestamp()),
                'model': model,
                'choices': [{
                    'index': 0,
                    'message': {
                        'role': 'assistant',
                        'content': response_text
                    },
                    'finish_reason': 'stop'
                }],
                'usage': {
                    'prompt_tokens': 0,  # Ollama doesn't provide this easily
                    'completion_tokens': total_tokens,
                    'total_tokens': total_tokens
                }
            }), 200
            
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        latency_ms = int((datetime.now() - start_time).total_seconds() * 1000)
        log_request(tenant_id, user_id, plan_tier, request_id, model, 0, 0, 0, latency_ms, False, error_code=str(e))
        return jsonify({
            'error': {
                'message': str(e),
                'type': 'server_error',
                'code': 'internal_error'
            }
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)

