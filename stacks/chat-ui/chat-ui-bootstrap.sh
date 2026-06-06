#!/bin/bash
#
# Bootstrap script for AnythingLLM in docker-ai-stack
# Reads the LiteLLM API key from the shared volume and starts AnythingLLM
#
# This file is part of Docker AI Stack, available at:
# https://github.com/hwdsl2/docker-ai-stack
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

# Read LiteLLM API key from shared volume (wait for it to be available)
if [ -d /var/lib/litellm-shared ]; then
  echo "Waiting for LiteLLM API key..."
  for i in $(seq 1 300); do
    if [ -r /var/lib/litellm-shared/.api_key ]; then
      KEY=$(cat /var/lib/litellm-shared/.api_key)
      case "$KEY" in
        sk-*)
          export GENERIC_OPEN_AI_API_KEY="$KEY"
          echo "LiteLLM API key loaded."
          break
          ;;
      esac
    fi
    sleep 2
  done
  if [ -z "$GENERIC_OPEN_AI_API_KEY" ]; then
    echo "Warning: LiteLLM API key not found or invalid after waiting. Proceeding without it."
  fi
fi

# Persist server/.env across container recreation via anythingllm-data volume
STORAGE_DIR=/app/server/storage
PERSISTENT_ENV="$STORAGE_DIR/.env"
LIVE_ENV=/app/server/.env

mkdir -p "$STORAGE_DIR" 2>/dev/null || true
if [ ! -f "$PERSISTENT_ENV" ]; then
  if [ -f "$LIVE_ENV" ] && [ ! -L "$LIVE_ENV" ]; then
    cp "$LIVE_ENV" "$PERSISTENT_ENV"
  else
    touch "$PERSISTENT_ENV"
  fi
  chmod 600 "$PERSISTENT_ENV" 2>/dev/null || true

  # Fresh-install detection: seed an admin password if no prior data exists.
  # AnythingLLM runs `prisma migrate deploy` on every boot, so absence of
  # anythingllm.db proves this volume has never been used.
  if [ ! -f "$STORAGE_DIR/anythingllm.db" ]; then
    ADMIN_PASS=$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' </dev/urandom 2>/dev/null | head -c 20)

    if [ -r /proc/sys/kernel/random/uuid ]; then
      JWT_SEC=$(cat /proc/sys/kernel/random/uuid)
    else
      HEX=$(LC_CTYPE=C tr -dc '0-9a-f' </dev/urandom 2>/dev/null | head -c 32)
      if [ "${#HEX}" -eq 32 ]; then
        JWT_SEC="${HEX:0:8}-${HEX:8:4}-4${HEX:13:3}-8${HEX:17:3}-${HEX:20:12}"
      fi
    fi

    if [ -z "$ADMIN_PASS" ] || [ -z "$JWT_SEC" ]; then
      echo "ERROR: Failed to generate admin password / JWT secret." >&2
      echo "Skipping password seeding. AnythingLLM will start without auth." >&2
      echo "To set a password manually, log in and visit Settings -> Security." >&2
    else
      cat >> "$PERSISTENT_ENV" <<EOF
AUTH_TOKEN='$ADMIN_PASS'
JWT_SECRET='$JWT_SEC'
EOF
      echo "$ADMIN_PASS" > "$STORAGE_DIR/.initial_admin_password"
      chmod 600 "$STORAGE_DIR/.initial_admin_password" 2>/dev/null || true

      printf '\n'
      printf '================================================================\n'
      printf '  AnythingLLM admin password (FIRST RUN - shown once)\n'
      printf '\n'
      printf '      %s\n' "$ADMIN_PASS"
      printf '\n'
      printf '  Retrieve later from inside the container:\n'
      printf '    docker exec anythingllm cat /app/server/storage/.initial_admin_password\n'
      printf '  Change it any time: log in -> Settings -> Security\n'
      printf '================================================================\n'
      printf '\n'
    fi
  fi
fi
ln -sf "$PERSISTENT_ENV" "$LIVE_ENV"

# Start AnythingLLM using the original entrypoint
exec /usr/local/bin/docker-entrypoint.sh
