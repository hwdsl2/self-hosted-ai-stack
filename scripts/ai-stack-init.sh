#!/bin/sh
#
# Initialize shared stack secrets before dependent services start.
#
# This file is part of Self-Hosted AI Stack, available at:
# https://github.com/hwdsl2/self-hosted-ai-stack
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

set -eu

DB_DIR=${AI_STACK_DB_DIR:-/var/lib/postgresql}
SHARED_DIR=${AI_STACK_SHARED_DIR:-/var/lib/ai-stack-shared}
PASSWORD_FILE="$SHARED_DIR/litellm_postgres_password"
CUSTOM_PASSWORD=${LITELLM_POSTGRES_PASSWORD:-}
VERSION_FILE=${AI_STACK_VERSION_FILE:-/etc/ai-stack/VERSION}
USAGE_STATE_DIR="$SHARED_DIR/.ai-stack-usage"
USAGE_BASE_URL=${AI_STACK_USAGE_BASE_URL:-https://github.com/hwdsl2/ai-stack-extras/releases/download/v1.0.0}

mkdir -p "$SHARED_DIR"

has_pg_version() {
  [ -s "$DB_DIR/18/docker/PG_VERSION" ] && return 0
  find "$DB_DIR" -mindepth 2 -maxdepth 4 -name PG_VERSION -type f -size +0c -print -quit 2>/dev/null | grep -q .
}

has_any_db_data() {
  find "$DB_DIR" -mindepth 1 -maxdepth 4 -print -quit 2>/dev/null | grep -q .
}

generate_password() {
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
}

write_password() {
  tmp_file=$(mktemp "$SHARED_DIR/.litellm_postgres_password.XXXXXX")
  printf '%s\n' "$1" > "$tmp_file"
  chmod 0644 "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$PASSWORD_FILE"
}

in_list() {
  needle=$1
  shift
  for item in "$@"; do
    [ "$needle" = "$item" ] && return 0
  done
  return 1
}

valid_variant() {
  in_list "$1" full chat-ui chat-only rag-pipeline rag-pipeline-full ai-tools code-assistant voice-pipeline voice-chat
}

valid_accel() {
  in_list "$1" cpu cuda
}

valid_arch() {
  in_list "$1" amd64 arm64 other
}

proxy_supported_variant() {
  in_list "$1" full chat-ui voice-chat
}

usage_arch() {
  arch=$(uname -m 2>/dev/null || printf 'unknown')
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) printf 'other' ;;
  esac
}

write_usage_state() {
  state_file=$1
  version=$2
  mkdir -p "$USAGE_STATE_DIR"
  tmp_file=$(mktemp "$USAGE_STATE_DIR/.usage.XXXXXX")
  printf '%s\n' "$version" > "$tmp_file"
  chmod 0644 "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$state_file"
}

fetch_usage_asset() {
  asset=$1
  command -v wget >/dev/null 2>&1 || return 0
  base_url=${USAGE_BASE_URL%/}
  wget -q -T 10 -O /dev/null "$base_url/$asset" >/dev/null 2>&1 || true
}

report_usage_counts() {
  [ "${AI_STACK_DISABLE_USAGE_COUNTS:-0}" != "1" ] || return 0

  current_version=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]' || true)
  [ -n "$current_version" ] || return 0

  variant=${AI_STACK_VARIANT:-}
  accel=${AI_STACK_ACCEL:-}
  arch=$(usage_arch)

  valid_variant "$variant" || return 0
  valid_accel "$accel" || return 0
  valid_arch "$arch" || return 0

  state_file="$USAGE_STATE_DIR/main-$variant-$accel-$arch.version"
  last_version=$(cat "$state_file" 2>/dev/null | tr -d '[:space:]' || true)
  action=

  if [ -z "$last_version" ]; then
    if [ "$PREEXISTING_DB_DATA" = "1" ]; then
      action=upgrade
    else
      action=deploy
    fi
  elif [ "$last_version" != "$current_version" ]; then
    action=upgrade
  fi

  if [ -n "$action" ]; then
    write_usage_state "$state_file" "$current_version"
    fetch_usage_asset "usage-v1-$action-$variant-$accel-$arch"
  fi

  if [ "${AI_STACK_PROXY:-}" = "caddy" ] && proxy_supported_variant "$variant"; then
    proxy_state_file="$USAGE_STATE_DIR/proxy-caddy-$variant-$accel-$arch.version"
    proxy_last_version=$(cat "$proxy_state_file" 2>/dev/null | tr -d '[:space:]' || true)
    if [ "$proxy_last_version" != "$current_version" ]; then
      write_usage_state "$proxy_state_file" "$current_version"
      fetch_usage_asset "usage-v1-feature-proxy-caddy-$variant-$accel-$arch"
    fi
  fi
}

init_password() {
  if [ -n "$CUSTOM_PASSWORD" ]; then
    write_password "$CUSTOM_PASSWORD"
    echo "Postgres password secret initialized (using LITELLM_POSTGRES_PASSWORD override)."
    return 0
  fi

  if [ -s "$PASSWORD_FILE" ]; then
    chmod 0644 "$PASSWORD_FILE" 2>/dev/null || true
    echo "Postgres password secret already exists."
    return 0
  fi

  if [ "$PREEXISTING_DB_DATA" = "1" ]; then
    password="litellm"
    reason="existing Postgres data found; using legacy compatibility password"
  else
    password=$(generate_password)
    if [ "${#password}" -ne 32 ]; then
      echo "Error: failed to generate Postgres password." >&2
      exit 1
    fi
    reason="fresh Postgres volume; generated random password"
  fi

  write_password "$password"
  echo "Postgres password secret initialized ($reason)."
}

PREEXISTING_DB_DATA=0
if has_pg_version || has_any_db_data; then
  PREEXISTING_DB_DATA=1
fi

init_password
report_usage_counts
