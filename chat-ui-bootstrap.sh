#!/bin/bash
#
# Bootstrap script for AnythingLLM in self-hosted-ai-stack
# Reads the LiteLLM API key from the shared volume and starts AnythingLLM
#
# This file is part of Self-Hosted AI Stack, available at:
# https://github.com/hwdsl2/self-hosted-ai-stack
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

DEFAULT_OLLAMA_MODEL="ollama/llama3.2:3b"
PREFERRED_OLLAMA_CHAT_MODEL="ollama-chat/llama3.2:3b"
LITELLM_MODEL_API_WAIT_SECONDS=120
LITELLM_ALIAS_GRACE_SECONDS=15
LITELLM_MODEL_API_RETRY_SECONDS=3

litellm_model_status() {
  MODEL_TO_FIND="$1" node <<'NODE'
const http = require("http");
const https = require("https");

const model = process.env.MODEL_TO_FIND;
const base = (process.env.GENERIC_OPEN_AI_BASE_PATH || "http://litellm:4000/v1").replace(/\/+$/, "");
const apiKey = process.env.GENERIC_OPEN_AI_API_KEY || "";
let url;

try {
  url = new URL(`${base}/models`);
} catch {
  process.exit(2);
}

const client = url.protocol === "https:" ? https : http;
const headers = {};
if (apiKey) headers.Authorization = `Bearer ${apiKey}`;

const req = client.get(url, { headers, timeout: 5000 }, (res) => {
  let body = "";
  res.setEncoding("utf8");
  res.on("data", (chunk) => (body += chunk));
  res.on("end", () => {
    if (res.statusCode < 200 || res.statusCode >= 300) process.exit(2);
    try {
      const parsed = JSON.parse(body);
      const models = Array.isArray(parsed?.data) ? parsed.data : [];
      const found = models.some((entry) => entry?.id === model || entry?.model_name === model);
      process.exit(found ? 0 : 1);
    } catch {
      process.exit(2);
    }
  });
});

req.on("timeout", () => req.destroy(new Error("timeout")));
req.on("error", () => process.exit(2));
NODE
}

wait_for_litellm_model() {
  local model="$1" start_time="$SECONDS" reachable_time="" status waiting_logged=0

  while true; do
    litellm_model_status "$model"
    status=$?

    case "$status" in
      0)
        return 0
        ;;
      1)
        [ -n "$reachable_time" ] || reachable_time="$SECONDS"
        if [ $((SECONDS - reachable_time)) -ge "$LITELLM_ALIAS_GRACE_SECONDS" ]; then
          return 1
        fi
        ;;
      *)
        if [ -n "$reachable_time" ]; then
          if [ $((SECONDS - reachable_time)) -ge "$LITELLM_ALIAS_GRACE_SECONDS" ]; then
            return 1
          fi
        elif [ $((SECONDS - start_time)) -ge "$LITELLM_MODEL_API_WAIT_SECONDS" ]; then
          return 2
        elif [ "$waiting_logged" = 0 ]; then
          echo "Waiting for LiteLLM model API..."
          waiting_logged=1
        fi
        ;;
    esac

    sleep "$LITELLM_MODEL_API_RETRY_SECONDS"
  done
}

configure_model_pref() {
  local current_model_pref="${GENERIC_OPEN_AI_MODEL_PREF:-}" model_status

  if [ -z "$current_model_pref" ] || [ "$current_model_pref" = "$DEFAULT_OLLAMA_MODEL" ]; then
    wait_for_litellm_model "$PREFERRED_OLLAMA_CHAT_MODEL"
    model_status=$?

    if [ "$model_status" = 0 ]; then
      export GENERIC_OPEN_AI_MODEL_PREF="$PREFERRED_OLLAMA_CHAT_MODEL"
      echo "Using LiteLLM Ollama chat model alias: $GENERIC_OPEN_AI_MODEL_PREF"
    elif [ -z "$current_model_pref" ]; then
      export GENERIC_OPEN_AI_MODEL_PREF="$DEFAULT_OLLAMA_MODEL"
      echo "Using default LiteLLM Ollama model alias: $GENERIC_OPEN_AI_MODEL_PREF"
    elif [ "$model_status" = 2 ]; then
      echo "LiteLLM model API not available; keeping $GENERIC_OPEN_AI_MODEL_PREF"
    else
      echo "LiteLLM Ollama chat model alias not found; keeping $GENERIC_OPEN_AI_MODEL_PREF"
    fi
  else
    echo "Preserving custom AnythingLLM model preference: $GENERIC_OPEN_AI_MODEL_PREF"
  fi
}

update_anythingllm_default_chat_mode() {
  [ "${ANYTHINGLLM_DEFAULT_CHAT_MODE:-}" = "chat" ] || return 0

  node <<'NODE'
const fs = require("fs");

const file = "/app/server/models/workspace.js";
if (!fs.existsSync(file)) {
  console.warn("Warning: AnythingLLM workspace model source not found; chat mode update skipped.");
  process.exit(0);
}

let src = fs.readFileSync(file, "utf8");
let changed = false;

const validationAutomatic = 'if (!value || !Workspace.VALID_CHAT_MODES.includes(value))\n        return "automatic";';
const validationChat = 'if (!value || !Workspace.VALID_CHAT_MODES.includes(value))\n        return "chat";';
if (src.includes(validationAutomatic)) {
  src = src.replace(validationAutomatic, validationChat);
  changed = true;
} else if (!src.includes(validationChat)) {
  console.warn("Warning: AnythingLLM chatMode validation fallback update pattern not found; source may have changed.");
}

if (src.includes('chatMode: "automatic",')) {
  src = src.replace('chatMode: "automatic",', 'chatMode: "chat",');
  changed = true;
} else if (!src.includes('chatMode: "chat",')) {
  console.warn("Warning: AnythingLLM new workspace chatMode update pattern not found; source may have changed.");
}

if (changed) {
  fs.writeFileSync(file, src);
  console.log("Updated AnythingLLM default workspace chat mode to chat.");
} else {
  console.log("AnythingLLM default workspace chat mode is already set to chat.");
}
NODE
}

migrate_existing_workspaces_chat_mode() {
  [ "${ANYTHINGLLM_DEFAULT_CHAT_MODE:-}" = "chat" ] || return 0
  local migration_marker="$STORAGE_DIR/.chat_mode_default_migration_done"

  [ ! -f "$migration_marker" ] || return 0

  if [ ! -f "$STORAGE_DIR/anythingllm.db" ]; then
    : > "$migration_marker"
    chmod 600 "$migration_marker" 2>/dev/null || true
    return 0
  fi

  (
    cd /app/server || exit 1
    node <<'NODE'
const fs = require("fs");
const storageDir = (process.env.STORAGE_DIR || "/app/server/storage").replace(/\/+$/, "");
const db = `${storageDir}/anythingllm.db`;

if (!fs.existsSync(db)) process.exit(1);

(async () => {
  let PrismaClient;
  try {
    ({ PrismaClient } = require("@prisma/client"));
  } catch {
    console.log("Existing workspace chatMode migration skipped because Prisma client is not available.");
    process.exitCode = 1;
    return;
  }

  const prisma = new PrismaClient();
  try {
    const tables = await prisma.$queryRawUnsafe(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workspaces'"
    );
    if (!Array.isArray(tables) || tables.length === 0) {
      process.exitCode = 1;
      return;
    }

    const columns = await prisma.$queryRawUnsafe("PRAGMA table_info(workspaces)");
    if (!Array.isArray(columns) || !columns.some((column) => column.name === "chatMode")) {
      process.exitCode = 1;
      return;
    }

    const updated = await prisma.$executeRawUnsafe(
      "UPDATE workspaces SET chatMode = 'chat' WHERE chatMode = 'automatic'"
    );
    if (updated > 0) {
      console.log(`Updated ${updated} existing AnythingLLM workspace(s) from automatic to chat mode.`);
    }
  } catch (error) {
    console.warn(`Warning: Existing workspace chatMode migration skipped: ${error.message}`);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
})();
NODE
  ) || return 0

  : > "$migration_marker"
  chmod 600 "$migration_marker" 2>/dev/null || true
}

# Read LiteLLM API key from shared volume (wait for it to be available)
if [ -d /var/lib/litellm-shared ]; then
  echo "Waiting for LiteLLM API key..."
  for _ in $(seq 1 300); do
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

configure_model_pref

valid_admin_pass() {
  printf '%s' "$1" | grep -Eq '^[A-HJ-NPR-Za-km-z2-9]{20}$'
}

valid_jwt_secret() {
  printf '%s' "$1" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
}

generate_admin_pass() {
  PASS=$(node -e '
const crypto = require("crypto");
const alphabet = "ABCDEFGHJKLMNPRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
const length = 20;
const limit = Math.floor(256 / alphabet.length) * alphabet.length;
let out = "";
while (out.length < length) {
  for (const byte of crypto.randomBytes(32)) {
    if (byte >= limit) continue;
    out += alphabet[byte % alphabet.length];
    if (out.length === length) break;
  }
}
console.log(out);
' 2>/dev/null)
  if valid_admin_pass "$PASS"; then
    printf '%s\n' "$PASS"
    return 0
  fi

  PASS=$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' </dev/urandom 2>/dev/null | head -c 20)
  if valid_admin_pass "$PASS"; then
    printf '%s\n' "$PASS"
    return 0
  fi

  return 1
}

generate_jwt_secret() {
  JWT=$(node -e 'console.log(require("crypto").randomUUID())' 2>/dev/null)
  if valid_jwt_secret "$JWT"; then
    printf '%s\n' "$JWT"
    return 0
  fi

  if [ -r /proc/sys/kernel/random/uuid ]; then
    JWT=$(cat /proc/sys/kernel/random/uuid)
    if valid_jwt_secret "$JWT"; then
      printf '%s\n' "$JWT"
      return 0
    fi
  fi

  HEX=$(LC_CTYPE=C tr -dc '0-9a-f' </dev/urandom 2>/dev/null | head -c 32)
  if [ "${#HEX}" -eq 32 ]; then
    VARIANT_INDEX=$((0x${HEX:16:1} % 4))
    VARIANT=$(printf '%s' "89ab" | cut -c $((VARIANT_INDEX + 1)))
    JWT=$(printf '%s-%s-4%s-%s%s-%s\n' \
      "${HEX:0:8}" "${HEX:8:4}" "${HEX:13:3}" "$VARIANT" "${HEX:17:3}" "${HEX:20:12}")
    if valid_jwt_secret "$JWT"; then
      printf '%s\n' "$JWT"
      return 0
    fi
  fi

  return 1
}

urlencode_component() {
  node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$1"
}

# Persist server/.env across container recreation via anythingllm-data volume
STORAGE_DIR=/app/server/storage
PERSISTENT_ENV="$STORAGE_DIR/.env"
LIVE_ENV=/app/server/.env
POSTGRES_PASSWORD_FILE=${POSTGRES_PASSWORD_FILE:-/var/lib/ai-stack-shared/litellm_postgres_password}

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
    ADMIN_PASS=$(generate_admin_pass)
    JWT_SEC=$(generate_jwt_secret)

    if ! valid_admin_pass "$ADMIN_PASS" || ! valid_jwt_secret "$JWT_SEC"; then
      echo "ERROR: Failed to generate AnythingLLM admin password or JWT secret." >&2
      echo "Refusing to start AnythingLLM without authentication." >&2
      echo "Check that the container has access to Node.js crypto or a working entropy source." >&2
      sleep 10
      exit 1
    fi

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
    printf '  Open http://<server-ip>:3001 and use this password to log in.\n'
    printf '\n'
    printf '  Retrieve later from inside the container:\n'
    printf '    docker exec anythingllm cat /app/server/storage/.initial_admin_password\n'
    printf '  Change it any time: log in -> Settings -> Security\n'
    printf '================================================================\n'
    printf '\n'
  fi
fi
ln -sf "$PERSISTENT_ENV" "$LIVE_ENV"

if [ "$VECTOR_DB" = "pgvector" ] && [ -z "$PGVECTOR_CONNECTION_STRING" ] \
  && ! grep -Eq '^[[:space:]]*PGVECTOR_CONNECTION_STRING=' "$PERSISTENT_ENV" 2>/dev/null; then
  if [ -r "$POSTGRES_PASSWORD_FILE" ]; then
    POSTGRES_PASS=$(cat "$POSTGRES_PASSWORD_FILE")
    POSTGRES_PASS=$(printf '%s' "$POSTGRES_PASS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [ -n "$POSTGRES_PASS" ]; then
      ENCODED_POSTGRES_PASS=$(urlencode_component "$POSTGRES_PASS")
      export PGVECTOR_CONNECTION_STRING="postgresql://litellm:${ENCODED_POSTGRES_PASS}@db:5432/litellm"
      echo "Configured AnythingLLM pgvector connection from shared stack secret."
    else
      echo "Warning: Postgres password file is empty; pgvector connection string was not configured."
    fi
  else
    echo "Warning: Postgres password file not readable; pgvector connection string was not configured."
  fi
fi

update_anythingllm_default_chat_mode
migrate_existing_workspaces_chat_mode

# Start AnythingLLM using the original entrypoint
exec /usr/local/bin/docker-entrypoint.sh
