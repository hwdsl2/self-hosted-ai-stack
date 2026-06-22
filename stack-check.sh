#!/bin/bash
#
# Script to verify that all running AI stack services are healthy
#
# This file is part of Self-Hosted AI Stack, available at:
# https://github.com/hwdsl2/self-hosted-ai-stack
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT
#
# Usage: ./stack-check.sh
#
# Automatically detects which services are running and checks each one.
# Works with the full stack and all lightweight stacks (chat-ui, chat-only,
# rag-pipeline, rag-pipeline-full, ai-tools, code-assistant, voice-pipeline,
# voice-chat).
#
# Container engine: auto-detects Docker or Podman. Override with the
# CONTAINER_ENGINE environment variable, e.g. CONTAINER_ENGINE=podman ./stack-check.sh

set -euo pipefail

# Detect the container engine (Docker or Podman).
# Honor CONTAINER_ENGINE if set; otherwise prefer docker, then podman.
if [ -n "${CONTAINER_ENGINE:-}" ]; then
  ENGINE="$CONTAINER_ENGINE"
elif command -v docker >/dev/null 2>&1; then
  ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
  ENGINE="podman"
else
  echo "Error: neither 'docker' nor 'podman' was found in PATH." >&2
  echo "Install one of them, or set CONTAINER_ENGINE to the engine you use." >&2
  exit 1
fi

if ! command -v "$ENGINE" >/dev/null 2>&1; then
  echo "Error: container engine '$ENGINE' was not found in PATH." >&2
  exit 1
fi

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

PASS=0
FAIL=0
WARN=0
MODEL_COUNT=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARN=$((WARN + 1)); }
info() { echo -e "${CYAN}▶${NC} $1"; }

# Detect running containers by image name (works even with custom container names).
container_for_image() {
  local image="$1"
  # List "<name> <image>" for running containers, then match the image column
  # against the base repository, ignoring any ":tag" or "@digest" suffix and any
  # registry prefix (e.g. Podman's "docker.io/" qualification).
  "$ENGINE" ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk -v img="$image" '
    {
      ref = $2
      sub(/@.*/, "", ref)        # strip digest
      sub(/:[^:\/]*$/, "", ref)  # strip tag (but not a registry :port)
      if (ref == img || ref ~ ("/" img "$")) { print $1; exit }
    }'
}

# Also try by container name (standard compose setup).
# Filter by name, then exact-match the Names column. Avoids the Docker-only
# "^/name$" anchor convention (Podman stores names without a leading slash),
# and the post-filter comparison prevents substring false positives.
container_running() {
  "$ENGINE" ps --filter "name=$1" --format '{{.Names}}' 2>/dev/null \
    | awk -v n="$1" '$0 == n { print; exit }'
}

# Find a running service: try container name first, then image name
find_service() {
  local name="$1"
  local image="$2"
  local c
  c=$(container_running "$name")
  if [ -z "$c" ]; then
    c=$(container_for_image "$image")
  fi
  echo "$c"
}

# Check if a URL responds with HTTP 2xx within timeout
http_ok() {
  local url="$1"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null) || true
  [[ "$code" =~ ^2 ]]
}

# Check if a URL responds to a POST with HTTP 2xx
http_post_ok() {
  local url="$1"
  shift
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 15 -X POST "$@" "$url" 2>/dev/null) || true
  [[ "$code" =~ ^2 ]]
}

echo ""
echo "Self-Hosted AI Stack — Health Check"
echo "==============================="
echo ""

# ── Ollama ──────────────────────────────────────────────
OLLAMA=$(find_service "ollama" "hwdsl2/ollama-server")
if [ -n "$OLLAMA" ]; then
  info "Ollama ($OLLAMA)"

  # Check if Ollama container is running
  pass "Container running"

  # Check if at least one model is pulled
  MODEL_COUNT=$("$ENGINE" exec "$OLLAMA" ollama_manage --listmodels | awk 'NF >= 4 && $2 ~ /^[a-f0-9]+$/ { print $1 }' | wc -l | tr -d ' ') || MODEL_COUNT=0
  if [ "$MODEL_COUNT" -gt 0 ]; then
    MODELS=$("$ENGINE" exec "$OLLAMA" ollama_manage --listmodels | awk 'NF >= 4 && $2 ~ /^[a-f0-9]+$/ { print $1 }' | paste -sd',' - | sed 's/,/, /g')
    pass "Models available ($MODEL_COUNT): $MODELS"
  else
    fail "No models pulled — run: $ENGINE exec $OLLAMA ollama_manage --pull llama3.2:3b"
  fi

  # Check API key exists
  if "$ENGINE" exec "$OLLAMA" test -f /var/lib/ollama/.api_key 2>/dev/null; then
    pass "API key generated"
  else
    warn "API key file not found"
  fi
else
  info "Ollama — not running (skipped)"
fi

echo ""

# ── PostgreSQL (LiteLLM DB) ─────────────────────────────
DB=$(find_service "litellm-db" "pgvector/pgvector")
if [ -z "$DB" ]; then
  DB=$(find_service "litellm-db" "postgres")
fi
if [ -n "$DB" ]; then
  info "PostgreSQL ($DB)"

  pass "Container running"

  if "$ENGINE" exec "$DB" pg_isready -U litellm >/dev/null 2>&1; then
    pass "Database accepts connections"
  else
    fail "Database is not ready for user litellm"
  fi

  if "$ENGINE" exec "$DB" test -r /var/lib/ai-stack-shared/litellm_postgres_password 2>/dev/null; then
    DB_PASS=$("$ENGINE" exec "$DB" sh -c 'cat /var/lib/ai-stack-shared/litellm_postgres_password 2>/dev/null' | tr -d '\r\n') || DB_PASS=""
    if [ -n "$DB_PASS" ]; then
      if [ "$DB_PASS" = "litellm" ]; then
        warn "Database uses legacy compatibility password"
      else
        pass "Database password secret present"
      fi
    else
      fail "Database password secret is empty"
    fi
  else
    warn "Database password secret not mounted (older stack or custom database configuration)"
  fi
else
  info "PostgreSQL — not running (skipped)"
fi

echo ""

# ── LiteLLM ─────────────────────────────────────────────
LITELLM=$(find_service "litellm" "hwdsl2/litellm-server")
if [ -n "$LITELLM" ]; then
  info "LiteLLM ($LITELLM)"

  pass "Container running"

  # Check health endpoint
  # LiteLLM typically exposes /health
  if http_ok "http://localhost:4000/health/liveliness"; then
    pass "Health endpoint responds"
  else
    fail "Health endpoint not responding at http://localhost:4000/health/liveliness"
  fi

  # Check API key exists
  if "$ENGINE" exec "$LITELLM" test -f /etc/litellm/.master_key 2>/dev/null; then
    pass "API key generated"
  else
    warn "API key file not found"
  fi

  if "$ENGINE" exec "$LITELLM" test -f /etc/litellm/.db_configured 2>/dev/null; then
    pass "Database integration configured"
  else
    warn "Database integration marker not found — run 'docker compose pull litellm && docker compose up -d litellm' if you recently updated the stack"
  fi

  # If Ollama is running and has models, test a routing check
  if [ -n "$OLLAMA" ] && [ "$MODEL_COUNT" -gt 0 ]; then
    LITELLM_KEY=$("$ENGINE" exec "$LITELLM" litellm_manage --showkey 2>/dev/null | sed 's/^ //' | grep '^sk-' | head -1) || LITELLM_KEY=""
    if [ -n "$LITELLM_KEY" ]; then
      FIRST_MODEL=$("$ENGINE" exec "$OLLAMA" ollama_manage --listmodels | awk 'NF >= 4 && $2 ~ /^[a-f0-9]+$/ { print $1 }' | head -1)
      echo -e "  ${CYAN}…${NC} Testing LLM routing (please wait)..."
      if http_post_ok "http://localhost:4000/v1/chat/completions" \
        -H "Authorization: Bearer $LITELLM_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"ollama/${FIRST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}"; then
        pass "LLM routing works (ollama/$FIRST_MODEL)"
      else
        fail "LLM routing failed for ollama/$FIRST_MODEL"
      fi
    else
      warn "Could not retrieve LiteLLM API key — skipping routing test"
    fi
  fi
else
  info "LiteLLM — not running (skipped)"
fi

echo ""

# ── Embeddings ──────────────────────────────────────────
EMBEDDINGS=$(find_service "embeddings" "hwdsl2/embeddings-server")
if [ -n "$EMBEDDINGS" ]; then
  info "Embeddings ($EMBEDDINGS)"

  pass "Container running"

  # Test embeddings endpoint
  if http_post_ok "http://localhost:8000/v1/embeddings" \
    -H "Content-Type: application/json" \
    -d '{"input":"test","model":"text-embedding-ada-002"}'; then
    pass "Embedding endpoint responds"
  else
    fail "Embedding endpoint not responding at http://localhost:8000/v1/embeddings"
  fi
else
  info "Embeddings — not running (skipped)"
fi

echo ""

# ── Whisper (STT) ───────────────────────────────────────
WHISPER=$(find_service "whisper" "hwdsl2/whisper-server")
if [ -n "$WHISPER" ]; then
  info "Whisper STT ($WHISPER)"

  pass "Container running"

  # Check if the transcription endpoint is reachable (GET or OPTIONS)
  if http_ok "http://localhost:9000/health" || http_ok "http://localhost:9000/"; then
    pass "Service responds"
  else
    warn "Could not verify health endpoint (service may still work)"
  fi
else
  info "Whisper STT — not running (skipped)"
fi

echo ""

# ── Kokoro (TTS) ────────────────────────────────────────
KOKORO=$(find_service "kokoro" "hwdsl2/kokoro-server")
if [ -n "$KOKORO" ]; then
  info "Kokoro TTS ($KOKORO)"

  pass "Container running"

  # Test TTS endpoint with a minimal request
  if http_post_ok "http://localhost:8880/v1/audio/speech" \
    -H "Content-Type: application/json" \
    -d '{"model":"tts-1","input":"ok","voice":"af_heart"}'; then
    pass "TTS endpoint responds"
  else
    fail "TTS endpoint not responding at http://localhost:8880/v1/audio/speech"
  fi
else
  info "Kokoro TTS — not running (skipped)"
fi

echo ""

# ── MCP Gateway ─────────────────────────────────────────
MCP=$(find_service "mcp" "hwdsl2/mcp-gateway")
if [ -n "$MCP" ]; then
  info "MCP Gateway ($MCP)"

  pass "Container running"

  # Check API key
  MCP_KEY=$("$ENGINE" exec "$MCP" mcp_manage --showkey 2>/dev/null | sed 's/^ //' | grep '^mcp-' | head -1) || MCP_KEY=""
  if [ -n "$MCP_KEY" ]; then
    pass "API key generated"

    # Test MCP initialize handshake
    INIT_RESP=$("$ENGINE" exec "$MCP" curl -sf --max-time 10 "http://127.0.0.1:3000/mcp" \
      -X POST \
      -H "Authorization: Bearer $MCP_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"stack-check","version":"1.0"}}}' 2>/dev/null) || INIT_RESP=""
    if echo "$INIT_RESP" | grep -q '"result"' 2>/dev/null || echo "$INIT_RESP" | grep -q '"serverInfo"' 2>/dev/null; then
      pass "MCP initialize handshake succeeded"
    else
      fail "MCP initialize handshake failed"
    fi
  else
    warn "Could not retrieve MCP API key — skipping handshake test"
  fi
else
  info "MCP Gateway — not running (skipped)"
fi

echo ""

# ── WhisperLive (STT) ───────────────────────────────────
WHISPERLIVE=$(find_service "whisper-live" "hwdsl2/whisper-live-server")
if [ -n "$WHISPERLIVE" ]; then
  info "WhisperLive STT ($WHISPERLIVE)"

  pass "Container running"

  # Check REST API docs endpoint (indicates server is ready)
  if http_ok "http://localhost:8001/docs"; then
    pass "REST API endpoint responds"
  else
    warn "Could not verify REST API endpoint (service may still be loading)"
  fi

else
  info "WhisperLive STT — not running (skipped)"
fi

echo ""

# ── Docling ──────────────────────────────────────────────
DOCLING=$(find_service "docling" "hwdsl2/docling-server")
if [ -n "$DOCLING" ]; then
  info "Docling ($DOCLING)"

  pass "Container running"

  # Check health endpoint
  if http_ok "http://localhost:5001/health"; then
    pass "Health endpoint responds"
  else
    fail "Health endpoint not responding at http://localhost:5001/health"
  fi

  # Check readiness
  if http_ok "http://localhost:5001/ready"; then
    pass "Service ready (models loaded)"
  else
    warn "Service not ready yet (models may still be loading)"
  fi
else
  info "Docling — not running (skipped)"
fi

echo ""

# ── AnythingLLM ──────────────────────────────────────────
ANYTHINGLLM=$(find_service "anythingllm" "mintplexlabs/anythingllm")
if [ -n "$ANYTHINGLLM" ]; then
  info "AnythingLLM ($ANYTHINGLLM)"

  pass "Container running"

  # Check health endpoint
  if http_ok "http://localhost:3001/api/ping"; then
    pass "Health endpoint responds"
  else
    fail "Health endpoint not responding at http://localhost:3001/api/ping"
  fi
else
  info "AnythingLLM — not running (skipped)"
fi

echo ""

# ── Summary ─────────────────────────────────────────────
echo "==============================="
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some checks failed. Review the output above.${NC}"
  echo -e "${YELLOW}If you just started the stack, wait a few minutes and run this check again.${NC}"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo -e "${YELLOW}All checks passed with warnings.${NC}"
  exit 0
else
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
fi
