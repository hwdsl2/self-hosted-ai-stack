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
# Request timeouts (seconds): STACK_CHECK_LLM_TIMEOUT=120,
# STACK_CHECK_EMBEDDINGS_TIMEOUT=60, STACK_CHECK_TTS_TIMEOUT=60,
# STACK_CHECK_HEALTH_TIMEOUT=10, STACK_CHECK_CONNECT_TIMEOUT=5.

set -euo pipefail

STACK_CHECK_LLM_TIMEOUT=${STACK_CHECK_LLM_TIMEOUT-120}
STACK_CHECK_EMBEDDINGS_TIMEOUT=${STACK_CHECK_EMBEDDINGS_TIMEOUT-60}
STACK_CHECK_TTS_TIMEOUT=${STACK_CHECK_TTS_TIMEOUT-60}
STACK_CHECK_HEALTH_TIMEOUT=${STACK_CHECK_HEALTH_TIMEOUT-10}
STACK_CHECK_CONNECT_TIMEOUT=${STACK_CHECK_CONNECT_TIMEOUT-5}
for timeout_var in STACK_CHECK_LLM_TIMEOUT STACK_CHECK_EMBEDDINGS_TIMEOUT \
  STACK_CHECK_TTS_TIMEOUT STACK_CHECK_HEALTH_TIMEOUT STACK_CHECK_CONNECT_TIMEOUT; do
  if ! [[ "${!timeout_var}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: $timeout_var must be a positive integer number of seconds." >&2
    exit 1
  fi
done

# Honor CONTAINER_ENGINE; otherwise prefer Docker, then Podman.
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

if ! CONTAINERS=$("$ENGINE" ps -a --format '{{.Names}} {{.Image}} {{.State}} {{.Label "com.docker.compose.project"}}'); then
  echo "Error: cannot list containers with '$ENGINE'. Check engine access with '$ENGINE ps'." >&2
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
SERVICES_CHECKED=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARN=$((WARN + 1)); }
info() { echo -e "${CYAN}▶${NC} $1"; }

# Find services by name or image, preferring running containers.
find_service() {
  local name="$1" image="$2" alternate_image="${3:-}"
  awk -v name="$name" -v img="$image" -v alt="$alternate_image" '
    function image_matches(ref, image) {
      return image != "" && (ref == image || ref ~ ("/" image "$"))
    }
    {
      if ($1 == name) {
        named = $1
        if ($3 == "running") named_running = $1
      }
      ref = $2
      sub(/@.*/, "", ref)        # strip digest
      sub(/:[^:\/]*$/, "", ref)  # strip tag (but not a registry :port)
      if (image_matches(ref, img) || image_matches(ref, alt)) {
        if (any == "") any = $1
        if ($3 == "running" && running == "") running = $1
      }
    }
    END {
      if (named_running != "") print named_running
      else if (running != "") print running
      else if (named != "") print named
      else if (any != "") print any
    }' <<< "$CONTAINERS"
}

OLLAMA=$(find_service "ollama" "hwdsl2/ollama-server")
DB=$(find_service "litellm-db" "pgvector/pgvector" "postgres")
LITELLM=$(find_service "litellm" "hwdsl2/litellm-server")
EMBEDDINGS=$(find_service "embeddings" "hwdsl2/embeddings-server")
WHISPER=$(find_service "whisper" "hwdsl2/whisper-server")
KOKORO=$(find_service "kokoro" "hwdsl2/kokoro-server")
MCP=$(find_service "mcp" "hwdsl2/mcp-gateway")
WHISPERLIVE=$(find_service "whisper-live" "hwdsl2/whisper-live-server")
DOCLING=$(find_service "docling" "hwdsl2/docling-server")
ANYTHINGLLM=$(find_service "anythingllm" "mintplexlabs/anythingllm")

# Track Compose projects with recognized running services.
RUNNING_PROJECTS=""
for container in "$OLLAMA" "$DB" "$LITELLM" "$EMBEDDINGS" "$WHISPER" \
  "$KOKORO" "$MCP" "$WHISPERLIVE" "$DOCLING" "$ANYTHINGLLM"; do
  project=$(awk -v n="$container" '$1 == n && $3 == "running" { print $4; exit }' <<< "$CONTAINERS")
  [ -z "$project" ] || RUNNING_PROJECTS+=" $project "
done

service_running() {
  local name="$1" state project
  [ -n "$name" ] || return 1
  read -r state project < <(awk -v n="$name" '$1 == n { print $3, $4; exit }' <<< "$CONTAINERS")
  if [ "$state" != "running" ]; then
    if [ -n "$project" ] && [[ "$RUNNING_PROJECTS" == *" $project "* ]]; then
      fail "Container $name is $state (same Compose project as running stack services)"
    else
      warn "Container $name is $state (deployment scope unknown; skipped)"
    fi
    return 1
  fi
  SERVICES_CHECKED=$((SERVICES_CHECKED + 1))
}

http_result_ok() {
  local status="$1" metrics="$2" timeout="$3" code elapsed
  read -r code elapsed <<< "$metrics"
  HTTP_DETAIL="HTTP ${code:-000}, curl $status, ${elapsed:-unknown}s elapsed, ${timeout}s limit"
  if [ "$status" -eq 28 ]; then
    HTTP_DETAIL="Timed out; $HTTP_DETAIL"
  fi
  [[ "$status" -eq 0 && "$code" =~ ^2[0-9][0-9]$ ]]
}

http_request() {
  local timeout="$1" url="$2" output="$3" result status=0
  shift 3
  if ! command -v curl >/dev/null 2>&1; then
    HTTP_BODY=""
    HTTP_DETAIL="curl was not found in PATH"
    return 1
  fi
  result=$(curl -q -sf --noproxy 'localhost,127.0.0.1,::1' \
    --connect-timeout "$STACK_CHECK_CONNECT_TIMEOUT" --max-time "$timeout" \
    -o "$output" -w '\n%{http_code} %{time_total}' "$@" "$url" 2>/dev/null) || status=$?
  HTTP_BODY="${result%$'\n'*}"
  http_result_ok "$status" "${result##*$'\n'}" "$timeout"
}

http_ok() {
  local url="$1"
  shift
  http_request "$STACK_CHECK_HEALTH_TIMEOUT" "$url" /dev/null "$@"
}

http_post_ok() {
  local timeout="$1" url="$2"
  shift 2
  http_request "$timeout" "$url" /dev/null -X POST "$@"
}

gateway_has_chat_alias() {
  # Parse the model list with LiteLLM's Python.
  if ! http_request "$STACK_CHECK_HEALTH_TIMEOUT" "http://localhost:4000/v1/models" - \
    --max-filesize 1048576 -H "Authorization: Bearer $LITELLM_KEY"; then
    return 1
  fi
  printf '%s' "$HTTP_BODY" | "$ENGINE" exec -i "$LITELLM" python3 -c '
import json
import sys

try:
    models = json.load(sys.stdin).get("data", [])
    sys.exit(0 if any(model.get("id") == sys.argv[1] for model in models) else 1)
except Exception:
    sys.exit(1)
' "$1" 2>/dev/null
}

service_key() {
  local container="$1"
  local manage_cmd="$2"
  local key
  key=$("$ENGINE" exec "$container" "$manage_cmd" --getkey 2>/dev/null | tr -d '\r\n') || key=""
  printf '%s' "$key"
}

echo ""
echo "Self-Hosted AI Stack — Health Check"
echo "==============================="
echo ""

# ── InferCrate (Ollama) ──────────────────────────────────
if service_running "$OLLAMA"; then
  info "InferCrate (Ollama, container: $OLLAMA)"

  pass "Container running"

  MODEL_COUNT=$("$ENGINE" exec "$OLLAMA" ollama_manage --listmodels | awk 'NF >= 4 && $2 ~ /^[a-f0-9]+$/ { print $1 }' | wc -l | tr -d ' ') || MODEL_COUNT=0
  if [ "$MODEL_COUNT" -gt 0 ]; then
    MODELS=$("$ENGINE" exec "$OLLAMA" ollama_manage --listmodels | awk 'NF >= 4 && $2 ~ /^[a-f0-9]+$/ { print $1 }' | paste -sd',' - | sed 's/,/, /g')
    pass "Models available ($MODEL_COUNT): $MODELS"
  else
    fail "No models pulled — run: $ENGINE exec $OLLAMA ollama_manage --pull llama3.2:3b"
  fi

  if "$ENGINE" exec "$OLLAMA" test -f /var/lib/ollama/.api_key 2>/dev/null; then
    pass "API key generated"
  else
    warn "API key file not found"
  fi
else
  info "InferCrate (Ollama): not running (skipped)"
fi

echo ""

# ── PostgreSQL (GatewayCrate / LiteLLM DB) ───────────────
if service_running "$DB"; then
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
        pass "Database uses legacy compatibility password"
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

# ── GatewayCrate (LiteLLM) ───────────────────────────────
if service_running "$LITELLM"; then
  info "GatewayCrate (LiteLLM, container: $LITELLM)"

  pass "Container running"

  if http_ok "http://localhost:4000/health/liveliness"; then
    pass "Health endpoint responds"
  else
    fail "Health endpoint not responding at http://localhost:4000/health/liveliness ($HTTP_DETAIL)"
  fi

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

  if [ -n "$OLLAMA" ] && [ "$MODEL_COUNT" -gt 0 ]; then
    LITELLM_KEY=$("$ENGINE" exec "$LITELLM" litellm_manage --showkey 2>/dev/null | sed 's/^ //' | grep '^sk-' | head -1) || LITELLM_KEY=""
    if [ -n "$LITELLM_KEY" ]; then
      FIRST_MODEL=$("$ENGINE" exec "$OLLAMA" ollama_manage --listmodels | awk 'NF >= 4 && $2 ~ /^[a-f0-9]+$/ { print $1 }' | head -1)
      ROUTING_MODEL="ollama/$FIRST_MODEL"
      if gateway_has_chat_alias "ollama-chat/$FIRST_MODEL"; then
        ROUTING_MODEL="ollama-chat/$FIRST_MODEL"
      fi
      echo -e "  ${CYAN}…${NC} Testing LLM routing (please wait)..."
      if http_post_ok "$STACK_CHECK_LLM_TIMEOUT" "http://localhost:4000/v1/chat/completions" \
        -H "Authorization: Bearer $LITELLM_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${ROUTING_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}"; then
        pass "LLM routing works ($ROUTING_MODEL)"
      else
        fail "LLM routing failed for $ROUTING_MODEL ($HTTP_DETAIL)"
      fi
    else
      warn "Could not retrieve GatewayCrate master key. Skipping routing test"
    fi
  fi
else
  info "GatewayCrate (LiteLLM): not running (skipped)"
fi

echo ""

# ── EmbedCrate (Hugging Face TEI) ────────────────────────
if service_running "$EMBEDDINGS"; then
  info "EmbedCrate (Hugging Face TEI, container: $EMBEDDINGS)"

  pass "Container running"

  EMBED_KEY=$(service_key "$EMBEDDINGS" embed_manage)
  EMBED_CURL_ARGS=(-H "Content-Type: application/json")
  if [ -n "$EMBED_KEY" ]; then
    pass "API key generated"
    EMBED_CURL_ARGS+=(-H "Authorization: Bearer $EMBED_KEY")
  else
    warn "API key not configured (existing no-auth install or explicit disable)"
  fi

  if http_post_ok "$STACK_CHECK_EMBEDDINGS_TIMEOUT" "http://localhost:8000/v1/embeddings" \
    "${EMBED_CURL_ARGS[@]}" \
    -d '{"input":"test","model":"text-embedding-ada-002"}'; then
    pass "Embedding endpoint responds"
  else
    fail "Embedding endpoint not responding at http://localhost:8000/v1/embeddings ($HTTP_DETAIL)"
  fi
else
  info "EmbedCrate (Hugging Face TEI): not running (skipped)"
fi

echo ""

# ── ScribeCrate (Whisper STT) ────────────────────────────
if service_running "$WHISPER"; then
  info "ScribeCrate (Whisper STT, container: $WHISPER)"

  pass "Container running"

  WHISPER_KEY=$(service_key "$WHISPER" whisper_manage)
  WHISPER_CURL_ARGS=()
  if [ -n "$WHISPER_KEY" ]; then
    pass "API key generated"
    WHISPER_CURL_ARGS=(-H "Authorization: Bearer $WHISPER_KEY")
  else
    warn "API key not configured (existing no-auth install or explicit disable)"
  fi

  if http_ok "http://localhost:9000/health" || http_ok "http://localhost:9000/"; then
    pass "Service responds"
  else
    warn "Could not verify health endpoint (service may still work; $HTTP_DETAIL)"
  fi

  if http_ok "http://localhost:9000/v1/models" "${WHISPER_CURL_ARGS[@]}"; then
    pass "Models endpoint responds"
  else
    fail "Models endpoint not responding at http://localhost:9000/v1/models ($HTTP_DETAIL)"
  fi
else
  info "ScribeCrate (Whisper STT): not running (skipped)"
fi

echo ""

# ── SpeakCrate (Kokoro TTS) ──────────────────────────────
if service_running "$KOKORO"; then
  info "SpeakCrate (Kokoro TTS, container: $KOKORO)"

  pass "Container running"

  KOKORO_KEY=$(service_key "$KOKORO" kokoro_manage)
  KOKORO_CURL_ARGS=(-H "Content-Type: application/json")
  if [ -n "$KOKORO_KEY" ]; then
    pass "API key generated"
    KOKORO_CURL_ARGS+=(-H "Authorization: Bearer $KOKORO_KEY")
  else
    warn "API key not configured (existing no-auth install or explicit disable)"
  fi

  if http_post_ok "$STACK_CHECK_TTS_TIMEOUT" "http://localhost:8880/v1/audio/speech" \
    "${KOKORO_CURL_ARGS[@]}" \
    -d '{"model":"tts-1","input":"ok","voice":"af_heart"}'; then
    pass "TTS endpoint responds"
  else
    fail "TTS endpoint not responding at http://localhost:8880/v1/audio/speech ($HTTP_DETAIL)"
  fi
else
  info "SpeakCrate (Kokoro TTS): not running (skipped)"
fi

echo ""

# ── UplinkCrate (MCPHub) ─────────────────────────────────
if service_running "$MCP"; then
  info "UplinkCrate (MCPHub, container: $MCP)"

  pass "Container running"

  MCP_KEY=$("$ENGINE" exec "$MCP" mcp_manage --showkey 2>/dev/null | sed 's/^ //' | grep '^mcp-' | head -1) || MCP_KEY=""
  if [ -n "$MCP_KEY" ]; then
    pass "API key generated"

    # MCP initialize handshake.
    MCP_STATUS=0
    INIT_RESP=$("$ENGINE" exec "$MCP" curl -q -sf --noproxy 'localhost,127.0.0.1,::1' \
      --connect-timeout "$STACK_CHECK_CONNECT_TIMEOUT" --max-time "$STACK_CHECK_HEALTH_TIMEOUT" "http://127.0.0.1:3000/mcp" \
      -w '\n%{http_code} %{time_total}' \
      -X POST \
      -H "Authorization: Bearer $MCP_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"stack-check","version":"1.0"}}}' 2>/dev/null) || MCP_STATUS=$?
    INIT_METRICS="${INIT_RESP##*$'\n'}"
    INIT_RESP="${INIT_RESP%$'\n'*}"
    if http_result_ok "$MCP_STATUS" "$INIT_METRICS" "$STACK_CHECK_HEALTH_TIMEOUT" \
      && { grep -q '"result"' <<< "$INIT_RESP" || grep -q '"serverInfo"' <<< "$INIT_RESP"; }; then
      pass "MCP initialize handshake succeeded"
    else
      fail "MCP initialize handshake failed ($HTTP_DETAIL)"
    fi
  else
    warn "Could not retrieve UplinkCrate API key. Skipping handshake test"
  fi
else
  info "UplinkCrate (MCPHub): not running (skipped)"
fi

echo ""

# ── ScribeCrate Live (WhisperLive) ────────────────────────
if service_running "$WHISPERLIVE"; then
  info "ScribeCrate Live (WhisperLive, container: $WHISPERLIVE)"

  pass "Container running"

  WHISPERLIVE_KEY=$(service_key "$WHISPERLIVE" whisper_live_manage)
  WHISPERLIVE_CURL_ARGS=()
  if [ -n "$WHISPERLIVE_KEY" ]; then
    pass "API key generated"
    WHISPERLIVE_CURL_ARGS=(-H "Authorization: Bearer $WHISPERLIVE_KEY")
  else
    warn "API key not configured (existing no-auth install or explicit disable)"
  fi

  if http_ok "http://localhost:8001/docs" "${WHISPERLIVE_CURL_ARGS[@]}"; then
    pass "REST API endpoint responds"
  else
    warn "Could not verify REST API endpoint (service may still be loading; $HTTP_DETAIL)"
  fi

else
  info "ScribeCrate Live (WhisperLive): not running (skipped)"
fi

echo ""

# ── ParseCrate (Docling) ─────────────────────────────────
if service_running "$DOCLING"; then
  info "ParseCrate (Docling, container: $DOCLING)"

  pass "Container running"

  DOCLING_KEY=$(service_key "$DOCLING" docling_manage)
  if [ -n "$DOCLING_KEY" ]; then
    pass "API key generated"
  else
    warn "API key not configured (existing no-auth install or explicit disable)"
  fi

  if http_ok "http://localhost:5001/health"; then
    pass "Health endpoint responds"
  else
    fail "Health endpoint not responding at http://localhost:5001/health ($HTTP_DETAIL)"
  fi

  if http_ok "http://localhost:5001/ready"; then
    pass "Service ready (models loaded)"
  else
    warn "Service not ready yet (models may still be loading; $HTTP_DETAIL)"
  fi
else
  info "ParseCrate (Docling): not running (skipped)"
fi

echo ""

# ── AnythingLLM ──────────────────────────────────────────
if service_running "$ANYTHINGLLM"; then
  info "AnythingLLM ($ANYTHINGLLM)"

  pass "Container running"

  if http_ok "http://localhost:3001/api/ping"; then
    pass "Health endpoint responds"
  else
    fail "Health endpoint not responding at http://localhost:3001/api/ping ($HTTP_DETAIL)"
  fi
else
  info "AnythingLLM — not running (skipped)"
fi

echo ""

# ── Summary ─────────────────────────────────────────────
if [ "$SERVICES_CHECKED" -eq 0 ]; then
  fail "No recognized running AI stack services were checked. Start the stack and verify '$ENGINE ps'."
fi
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
