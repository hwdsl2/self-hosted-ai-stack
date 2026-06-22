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

if [ -n "$CUSTOM_PASSWORD" ]; then
  write_password "$CUSTOM_PASSWORD"
  echo "Postgres password secret initialized (using LITELLM_POSTGRES_PASSWORD override)."
  exit 0
fi

if [ -s "$PASSWORD_FILE" ]; then
  chmod 0644 "$PASSWORD_FILE" 2>/dev/null || true
  echo "Postgres password secret already exists."
  exit 0
fi

if has_pg_version; then
  password="litellm"
  reason="existing Postgres data found; using legacy compatibility password"
elif has_any_db_data; then
  password="litellm"
  reason="non-empty Postgres volume found; using legacy compatibility password"
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
