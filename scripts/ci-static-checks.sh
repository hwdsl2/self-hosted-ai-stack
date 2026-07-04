#!/bin/bash
#
# Run static CI checks for compose and shell-script changes.
#
# This file is part of Self-Hosted AI Stack, available at:
# https://github.com/hwdsl2/self-hosted-ai-stack
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' was not found." >&2
    exit 1
  fi
}

log() {
  printf '\n==> %s\n' "$1"
}

sorted_words() {
  printf '%s\n' "$@" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

expected_services_for_variant() {
  case "$1" in
    full)
      echo "ai-stack-init anythingllm db embeddings litellm mcp ollama whisper"
      ;;
    chat-ui)
      echo "ai-stack-init anythingllm db litellm ollama"
      ;;
    chat-only)
      echo "ai-stack-init db litellm ollama"
      ;;
    rag-pipeline)
      echo "ai-stack-init db embeddings litellm ollama"
      ;;
    rag-pipeline-full)
      echo "ai-stack-init db docling embeddings litellm ollama"
      ;;
    ai-tools)
      echo "ai-stack-init db litellm mcp ollama"
      ;;
    code-assistant)
      echo "ai-stack-init db embeddings litellm mcp ollama"
      ;;
    voice-pipeline)
      echo "ai-stack-init db kokoro litellm ollama whisper"
      ;;
    voice-chat)
      echo "ai-stack-init anythingllm db kokoro litellm ollama whisper"
      ;;
    *)
      echo "Error: unknown stack variant '$1'." >&2
      exit 1
      ;;
  esac
}

compose_json() {
  local out_file="$1"
  shift
  docker compose "$@" config --quiet
  docker compose "$@" config --format json > "$out_file"
  jq -e . "$out_file" >/dev/null
}

assert_compose_shape() {
  local json_file="$1"
  local label="$2"
  local variant="$3"
  local accel="$4"
  local expected actual

  expected=$(expected_services_for_variant "$variant")
  actual=$(jq -r '.services | keys | sort | join(" ")' "$json_file")
  if [ "$actual" != "$expected" ]; then
    echo "Error: $label service set mismatch." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi

  jq -e --arg variant "$variant" --arg accel "$accel" '
    def envval($name):
      .services["ai-stack-init"].environment as $env
      | if ($env | type) == "object" then $env[$name]
        elif ($env | type) == "array" then
          (($env[] | select(startswith($name + "=")) | sub("^[^=]*="; "")) // empty)
        else empty end;
    def is_cuda_capable_image:
      type == "string"
      and test("^hwdsl2/(ollama-server|whisper-server|kokoro-server|docling-server|whisper-live-server)(:|@|$)");
    def is_cuda_image:
      type == "string" and (endswith(":cuda") or test(":cuda@"));

    (envval("AI_STACK_VARIANT") == $variant)
    and (envval("AI_STACK_ACCEL") == $accel)
    and ([.services[]?.image? | select(type == "string" and test(":latest($|@)"))] | length == 0)
    and (if $accel == "cuda" then
      all(.services | to_entries[]; ((.value.image // "") | is_cuda_capable_image | not) or ((.value.image // "") | is_cuda_image))
      and all(.services | to_entries[]; ((.value.image // "") | is_cuda_image | not) or (((.value.deploy.resources.reservations.devices // []) | length) > 0))
    else
      all(.services | to_entries[]; ((.value.image // "") | is_cuda_capable_image | not) or (((.value.image // "") | is_cuda_image) | not))
    end)
  ' "$json_file" >/dev/null || {
    echo "Error: $label failed variant/accelerator/image checks." >&2
    exit 1
  }
}

assert_proxy_shape() {
  local json_file="$1"
  local label="$2"
  local variant="$3"
  local accel="$4"
  local expected actual
  local -a expected_services

  read -r -a expected_services <<< "$(expected_services_for_variant "$variant")"
  expected=$(sorted_words caddy "${expected_services[@]}")
  actual=$(jq -r '.services | keys | sort | join(" ")' "$json_file")
  if [ "$actual" != "$expected" ]; then
    echo "Error: $label proxy service set mismatch." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi

  jq -e --arg variant "$variant" --arg accel "$accel" '
    def envval($name):
      .services["ai-stack-init"].environment as $env
      | if ($env | type) == "object" then $env[$name]
        elif ($env | type) == "array" then
          (($env[] | select(startswith($name + "=")) | sub("^[^=]*="; "")) // empty)
        else empty end;
    def has_local_port($service; $port):
      any(.services[$service].ports[]?; (.host_ip // "") == "127.0.0.1" and ((.published // "") | tostring) == $port);

    (envval("AI_STACK_VARIANT") == $variant)
    and (envval("AI_STACK_ACCEL") == $accel)
    and (envval("AI_STACK_PROXY") == "caddy")
    and has_local_port("anythingllm"; "3001")
    and has_local_port("litellm"; "4000")
  ' "$json_file" >/dev/null || {
    echo "Error: $label failed proxy checks." >&2
    exit 1
  }
}

check_shell() {
  log "Shell syntax and ShellCheck"

  local bash_scripts=(
    "$ROOT_DIR/chat-ui-bootstrap.sh"
    "$ROOT_DIR/stack-check.sh"
    "$ROOT_DIR/stacks/chat-ui/chat-ui-bootstrap.sh"
    "$ROOT_DIR/stacks/voice-chat/chat-ui-bootstrap.sh"
    "$ROOT_DIR/scripts/ci-static-checks.sh"
  )
  local sh_scripts=(
    "$ROOT_DIR/scripts/ai-stack-init.sh"
  )

  bash -n "${bash_scripts[@]}"
  sh -n "${sh_scripts[@]}"
  shellcheck "${bash_scripts[@]}"
  shellcheck -s sh "${sh_scripts[@]}"
}

check_bootstrap_parity() {
  log "Bootstrap script parity"

  local canonical="$ROOT_DIR/chat-ui-bootstrap.sh"
  local canonical_rel=${canonical#"$ROOT_DIR"/}
  local -a copies=(
    "$ROOT_DIR/stacks/chat-ui/chat-ui-bootstrap.sh"
    "$ROOT_DIR/stacks/voice-chat/chat-ui-bootstrap.sh"
  )
  local copy copy_rel

  for copy in "${copies[@]}"; do
    copy_rel=${copy#"$ROOT_DIR"/}
    echo "Comparing $copy_rel"
    if ! cmp -s "$canonical" "$copy"; then
      echo "Error: $copy_rel differs from $canonical_rel." >&2
      diff -u "$canonical" "$copy" >&2 || true
      exit 1
    fi
  done
}

check_standalone_compose() {
  log "Standalone compose files"

  local entries=(
    ".|docker-compose.yml|full|cpu"
    ".|docker-compose.cuda.yml|full|cuda"
    "stacks/ai-tools|docker-compose.yml|ai-tools|cpu"
    "stacks/ai-tools|docker-compose.cuda.yml|ai-tools|cuda"
    "stacks/chat-only|docker-compose.yml|chat-only|cpu"
    "stacks/chat-only|docker-compose.cuda.yml|chat-only|cuda"
    "stacks/chat-ui|docker-compose.yml|chat-ui|cpu"
    "stacks/chat-ui|docker-compose.cuda.yml|chat-ui|cuda"
    "stacks/code-assistant|docker-compose.yml|code-assistant|cpu"
    "stacks/code-assistant|docker-compose.cuda.yml|code-assistant|cuda"
    "stacks/rag-pipeline|docker-compose.yml|rag-pipeline|cpu"
    "stacks/rag-pipeline|docker-compose.cuda.yml|rag-pipeline|cuda"
    "stacks/rag-pipeline-full|docker-compose.yml|rag-pipeline-full|cpu"
    "stacks/rag-pipeline-full|docker-compose.cuda.yml|rag-pipeline-full|cuda"
    "stacks/voice-pipeline|docker-compose.yml|voice-pipeline|cpu"
    "stacks/voice-pipeline|docker-compose.cuda.yml|voice-pipeline|cuda"
    "stacks/voice-chat|docker-compose.yml|voice-chat|cpu"
    "stacks/voice-chat|docker-compose.cuda.yml|voice-chat|cuda"
  )

  local entry dir file variant accel label json_file
  for entry in "${entries[@]}"; do
    IFS='|' read -r dir file variant accel <<< "$entry"
    label="$dir/$file"
    json_file="$TMP_DIR/${dir//\//_}_${file//./_}.json"
    echo "Checking $label"
    (
      cd "$ROOT_DIR/$dir"
      compose_json "$json_file" -f "$file"
    )
    assert_compose_shape "$json_file" "$label" "$variant" "$accel"
  done
}

check_proxy_compose() {
  log "Proxy compose overlays"

  local entries=(
    ".|docker-compose.yml|docker-compose.proxy.yml|full|cpu"
    ".|docker-compose.cuda.yml|docker-compose.proxy.yml|full|cuda"
    "stacks/chat-ui|docker-compose.yml|../../docker-compose.proxy.yml|chat-ui|cpu"
    "stacks/chat-ui|docker-compose.cuda.yml|../../docker-compose.proxy.yml|chat-ui|cuda"
    "stacks/voice-chat|docker-compose.yml|../../docker-compose.proxy.yml|voice-chat|cpu"
    "stacks/voice-chat|docker-compose.cuda.yml|../../docker-compose.proxy.yml|voice-chat|cuda"
  )

  local entry dir base_file proxy_file variant accel label json_file
  for entry in "${entries[@]}"; do
    IFS='|' read -r dir base_file proxy_file variant accel <<< "$entry"
    label="$dir/$base_file + $proxy_file"
    json_file="$TMP_DIR/proxy_${dir//\//_}_${base_file//./_}.json"
    echo "Checking $label"
    (
      cd "$ROOT_DIR/$dir"
      DOMAIN=chat.example.test ACME_EMAIL=ci@example.test \
        compose_json "$json_file" -f "$base_file" -f "$proxy_file"
    )
    assert_proxy_shape "$json_file" "$label" "$variant" "$accel"
  done
}

check_repository_consistency() {
  log "Repository consistency scans"

  local compose_files
  mapfile -t compose_files < <(
    find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -name 'docker-compose*.yml' -type f -print | sort
  )

  if grep -RInE 'image:[[:space:]]+[^#]*:latest([[:space:]#]|$)' "${compose_files[@]}"; then
    echo "Error: compose files must not explicitly use :latest image tags." >&2
    exit 1
  fi

  local stack
  for stack in ai-tools chat-only chat-ui code-assistant rag-pipeline rag-pipeline-full voice-chat voice-pipeline; do
    test -f "$ROOT_DIR/stacks/$stack/docker-compose.yml"
    test -f "$ROOT_DIR/stacks/$stack/docker-compose.cuda.yml"
    grep -q "AI_STACK_VARIANT: $stack" "$ROOT_DIR/stacks/$stack/docker-compose.yml"
    grep -q "AI_STACK_VARIANT: $stack" "$ROOT_DIR/stacks/$stack/docker-compose.cuda.yml"
  done

  test -f "$ROOT_DIR/VERSION"
  grep -q 'AI_STACK_VARIANT: full' "$ROOT_DIR/docker-compose.yml"
  grep -q 'AI_STACK_VARIANT: full' "$ROOT_DIR/docker-compose.cuda.yml"
}

main() {
  require_cmd jq
  require_cmd shellcheck
  jq --version
  shellcheck --version

  check_shell
  check_bootstrap_parity

  require_cmd docker
  docker compose version

  check_standalone_compose
  check_proxy_compose
  check_repository_consistency

  log "All static checks passed"
}

main "$@"
