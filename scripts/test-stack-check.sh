#!/bin/bash
# Offline regression tests for stack-check.sh.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
unset STACK_CHECK_LLM_TIMEOUT STACK_CHECK_EMBEDDINGS_TIMEOUT STACK_CHECK_TTS_TIMEOUT \
  STACK_CHECK_HEALTH_TIMEOUT STACK_CHECK_CONNECT_TIMEOUT

curl() {
  [ "$1" = -q ] || return 90
  local url="" budget="" connect="" bypass="" payload="" output=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --max-time) budget="$2"; shift ;;
      --connect-timeout) connect="$2"; shift ;;
      --noproxy) bypass="$2"; shift ;;
      -d) payload="$2"; shift ;;
      -o) output="$2"; shift ;;
      -H|-w|-X|--max-filesize) shift ;;
      http://*) url="$1" ;;
    esac
    shift
  done
  [ "$bypass" = 'localhost,127.0.0.1,::1' ] || return 91
  [ "$connect" = "${STACK_CHECK_CONNECT_TIMEOUT:-5}" ] || return 92
  local expected="${STACK_CHECK_HEALTH_TIMEOUT:-10}"
  case "$url" in
    */chat/completions) expected="${STACK_CHECK_LLM_TIMEOUT:-120}" ;;
    */embeddings) expected="${STACK_CHECK_EMBEDDINGS_TIMEOUT:-60}" ;;
    */audio/speech) expected="${STACK_CHECK_TTS_TIMEOUT:-60}" ;;
  esac
  [ "$budget" = "$expected" ] || return 93
  case "$url" in
    */chat/completions)
      local model='ollama-chat/llama3.2:3b'
      [ "$MOCK_CASE" != legacy ] || model='ollama/llama3.2:3b'
      [[ "$payload" == *"\"model\":\"$model\""* ]] || return 94
      case "$MOCK_CASE" in
        timeout) printf '\n200 120.000'; echo 'sk-regression-secret' >&2; return 28 ;;
        http-error) printf '\n401 0.001'; return 22 ;;
      esac
      ;;
    */v1/models)
      [ "$output" = - ] || return 95
      if [ "$MOCK_CASE" = legacy ]; then
        printf '{"data":[{"id":"ollama/llama3.2:3b"}]}'
      else
        printf '{"data":[{"id":"ollama-chat/llama3.2:3b"}]}'
      fi
      ;;
    */mcp) printf '{"jsonrpc":"2.0","id":1,"result":{"serverInfo":{}}}' ;;
  esac
  printf '\n200 0.001'
}

mock_engine() {
  case "$1" in
    ps)
      case "$MOCK_CASE" in
        engine-error) return 1 ;;
        empty) return 0 ;;
        stopped)
          printf '%s\n' 'ollama hwdsl2/ollama-server:cuda exited current' \
            'litellm hwdsl2/litellm-server running current'
          ;;
        unrelated-stopped)
          printf '%s\n' 'ollama hwdsl2/ollama-server exited old' \
            'litellm hwdsl2/litellm-server running current'
          ;;
        *)
          printf '%s\n' 'ollama docker.io/hwdsl2/ollama-server:cuda running current' \
            'litellm hwdsl2/litellm-server running current' \
            'embed-custom docker.io/hwdsl2/embeddings-server@sha256:abc running current' \
            'embeddings hwdsl2/embeddings-server exited old' \
            'old-db pgvector/pgvector:pg18-trixie exited old' \
            'db-custom docker.io/library/postgres:18 running current' \
            'kokoro hwdsl2/kokoro-server running current' \
            'mcp hwdsl2/mcp-gateway running current'
          ;;
      esac
      ;;
    exec)
      shift
      [ "$1" != -i ] || shift
      shift # container name
      case "$1" in
        ollama_manage) printf '%s\n' 'NAME ID SIZE MODIFIED' 'llama3.2:3b abc123 2.0GB now' ;;
        litellm_manage) printf '%s\n' 'sk-regression-secret' ;;
        embed_manage|kokoro_manage)
          [ "$MOCK_CASE" != legacy ] || return 1
          printf '%s\n' 'sk-regression-secret'
          ;;
        mcp_manage) printf '%s\n' 'mcp-regression-secret' ;;
        test) return 0 ;;
        pg_isready) return 0 ;;
        sh) printf '%s\n' 'litellm' ;;
        python3)
          local body=""
          IFS= read -r body || true
          [ "$body" = '{"data":[{"id":"ollama-chat/llama3.2:3b"}]}' ]
          ;;
        curl) shift; curl "$@" ;;
        *) return 99 ;;
      esac
      ;;
    *) return 99 ;;
  esac
}
export -f curl mock_engine

run_check() {
  local expected="$1" pattern="$2" status=0 output
  shift 2
  output=$(env "$@" CONTAINER_ENGINE=mock_engine bash "$ROOT_DIR/stack-check.sh" 2>&1) || status=$?
  if [ "$status" -ne "$expected" ] || [[ "$output" != *"$pattern"* ]] \
    || [[ "$output" == *'sk-regression-secret'* || "$output" == *'mcp-regression-secret'* ]]; then
    printf 'FAIL: %s (exit %s, expected %s)\n%s\n' "$MOCK_CASE" "$status" "$expected" "$output" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$MOCK_CASE"
}

export MOCK_CASE=normal
run_check 0 'All checks passed.'
MOCK_CASE=legacy
run_check 0 'LLM routing works (ollama/llama3.2:3b)'
MOCK_CASE=timeout
run_check 1 'Timed out; HTTP 200, curl 28'
MOCK_CASE=http-error
run_check 1 'HTTP 401, curl 22'
MOCK_CASE=engine-error
run_check 1 'cannot list containers'
MOCK_CASE=empty
run_check 1 'No recognized running AI stack services were checked'
MOCK_CASE=stopped
run_check 1 'Container ollama is exited (same Compose project'
MOCK_CASE=unrelated-stopped
run_check 0 'Container ollama is exited (deployment scope unknown; skipped)'
MOCK_CASE=timeout-overrides
run_check 0 'All checks passed.' STACK_CHECK_LLM_TIMEOUT=180 STACK_CHECK_EMBEDDINGS_TIMEOUT=90 \
  STACK_CHECK_TTS_TIMEOUT=75 STACK_CHECK_HEALTH_TIMEOUT=12 STACK_CHECK_CONNECT_TIMEOUT=3
MOCK_CASE=invalid-timeout
run_check 1 'STACK_CHECK_LLM_TIMEOUT must be a positive integer' STACK_CHECK_LLM_TIMEOUT=0
