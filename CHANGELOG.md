# Changelog

All notable changes to self-hosted-ai-stack are documented here.

## 2026-06-14

### Changed

- Renamed the project from Docker AI Stack to Self-Hosted AI Stack. Existing installs cloned from `docker-ai-stack` continue to work through GitHub repository redirects, and no local directory, container, volume, or network rename is required.

## 2026-06-11

### Added

- Added Docker healthchecks for LiteLLM across the root stack and all
  lightweight stacks, improving readiness visibility without delaying
  dependent service startup.
- Added a PostgreSQL readiness check to `stack-check.sh`.

### Changed

- Added localhost reverse-proxy hints to LiteLLM port mappings in compose
  files while keeping the default direct `4000` listener unchanged.
- Hardened AnythingLLM first-run password seeding. The bootstrap script now
  uses Node.js crypto first, falls back to OS entropy sources, and refuses to
  start AnythingLLM without authentication if secret generation fails.
- Standardized the commented WhisperLive REST API host port in the
  `voice-pipeline` stack to `8001`.
- Clarified manual `docker run` startup ordering, default PostgreSQL
  credential guidance, and that `.initial_admin_password` is only the
  first-run AnythingLLM password copy.

## 2026-06-07

### Added

- **Optional Caddy HTTPS overlay.** Internet-facing deployments can now run
  `docker-compose.proxy.yml` with the root stack or the `chat-ui` /
  `voice-chat` sub-stacks to get automatic HTTPS for AnythingLLM. The overlay
  starts Caddy on ports `80`/`443`, persists certificate state in
  `caddy-data`, and binds the direct AnythingLLM and LiteLLM ports to
  `127.0.0.1` while leaving the default local/LAN quickstart unchanged.

## 2026-06-06

### Added

- **Opt-in: switch AnythingLLM to the stack's Embeddings service and
  pgvector storage.** Edit the `anythingllm` service in
  `docker-compose.yml`: comment out `EMBEDDING_ENGINE=native` and
  uncomment the new block to use BAAI/bge-small-en-v1.5 via the
  Embeddings service and/or store vectors in the shared pgvector
  Postgres. AnythingLLM auto-creates the `vector` extension and
  `anythingllm_vectors` table on first use. Default behavior is
  unchanged (bundled MiniLM + LanceDB). ⚠️ Switching the embedder or
  vector store on an existing deployment makes previously embedded
  documents incompatible. Re-embed your workspaces after the change.

### Changed

- **Pinned AnythingLLM to the stable release tag `1.13`.** The upstream
  `mintplexlabs/anythingllm:latest` image tracks the master branch and can
  change on every commit, so the compose files and `docker run` examples now
  use `mintplexlabs/anythingllm:1.13` for safer, release-based updates. Users
  already running `latest` should back up `anythingllm-data` before recreating
  the container, especially if they used unreleased AnythingLLM features.
- Raised healthcheck `interval` from 5s to 15s across all services and
  stacks to reduce steady-state probe overhead. Existing `start_period`
  settings remain unchanged to accommodate slow-starting services
  such as Ollama.

## 2026-06-05

### Added

- **Password-protected first run for AnythingLLM.** Fresh installs now
  auto-generate a 20-character admin password on first start. The password
  is printed once to `docker logs anythingllm` and saved to
  `/app/server/storage/.initial_admin_password` inside the
  `anythingllm-data` volume (mode `0600`). Change it any time from
  **Settings → Security** — changes persist across container upgrades
  thanks to the `.env` persistence fix below.

  Existing installations are **not** affected: detection is based on the
  absence of `anythingllm.db` in the data volume, so any pre-existing
  AnythingLLM install triggers a skip and the auth state is left exactly
  as it was.

  Retrieve the auto-generated password:

  ```bash
  # At any time from the data volume:
  docker exec anythingllm cat /app/server/storage/.initial_admin_password

  # Or from the live logs (only shown on first start):
  docker compose logs anythingllm | grep -A4 "FIRST RUN"
  ```

### Fixed

- AnythingLLM `server/.env` now persists across container recreation via the
  `anythingllm-data` volume. Previously, the file lived only in the container
  filesystem and was destroyed on container recreation (`docker compose down
  && up`, `pull && up` on a new image, etc.), silently dropping any password
  set via Settings → Security and any UI-configured provider keys. The
  bootstrap script now symlinks `/app/server/.env` → `/app/server/storage/.env`
  (inside the volume) on every container start.

  **Action required to benefit from this fix:**
  1. Pull the latest code: `cd self-hosted-ai-stack && git pull`
  2. Recreate the AnythingLLM container so the updated bootstrap script
     runs: `docker compose up -d --force-recreate anythingllm`

     ⚠️ This step destroys the old container, so any password currently
     set via Settings → Security will be cleared during the recreation
     and AnythingLLM will revert to its default no-password state —
     leaving the UI publicly accessible until step 3 is done. This is
     the last time that will happen.
  3. Set your password again from Settings → Security. From this point
     onward it will persist across container recreation and upgrades.

## Earlier notable changes

The changelog was introduced on 2026-06-05 after the project was already
active. This section is a best-effort summary of major user-facing and
operational changes from git history, not an exhaustive commit log.

### Added

- Initial Docker Compose stack with Ollama, LiteLLM, Embeddings, Whisper,
  Kokoro, MCP Gateway, persistent volumes, and NVIDIA CUDA variants.
- Lightweight stack presets, later expanded to include `chat-only`,
  `ai-tools`, `rag-pipeline`, `voice-pipeline`, `rag-pipeline-full`,
  `chat-ui`, `code-assistant`, and `voice-chat`.
- `stack-check.sh` health/diagnostic script for the full stack and
  lightweight stacks.
- Backup and restore documentation covering Docker volumes, generated API
  keys, service data, and migration/pre-upgrade workflows.
- Optional Docling document parsing, WhisperLive real-time STT, and the full
  RAG pipeline stack.
- AnythingLLM chat UI support, first as a lightweight `chat-ui` stack and
  later as part of the main stack.
- Bundled PostgreSQL for LiteLLM state, including health-gated startup and
  persistent `litellm-db` storage.
- Shared key volumes so LiteLLM can automatically read Ollama and MCP Gateway
  API keys without manual copy/paste setup.
- Specialized `code-assistant` and `voice-chat` stacks for MCP-enabled coding
  and speech-enabled chat workflows.
- Podman support in documentation and `stack-check.sh`, including engine
  auto-detection and Podman-specific guidance.
- pgvector-backed PostgreSQL image, enabling vector storage in the bundled
  database.

### Changed

- Bound most non-UI service ports to `127.0.0.1` by default and stopped
  exposing Ollama/MCP directly unless users explicitly uncomment those ports.
- Made heavier or more specialized services such as Kokoro, Docling, and
  WhisperLive opt-in in the main stack to keep the default footprint smaller.
- Added container healthchecks for core dependencies and used
  `depends_on: condition: service_healthy` where startup ordering matters.
- Added reverse-proxy and internet-facing deployment guidance, including
  advice to bind direct HTTP ports to localhost when using TLS termination.

### Fixed

- Improved `stack-check.sh` service detection, Podman compatibility, and
  endpoint checks across optional services.
- Iteratively expanded backup/restore docs and README guidance as new
  volumes, shared-key paths, and lightweight stacks were added.
