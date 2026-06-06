# Changelog

All notable changes to docker-ai-stack are documented here.

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
  # From the live logs (only shown on first start):
  docker compose logs anythingllm | grep -A2 "FIRST RUN"

  # Or at any time from the data volume:
  docker exec anythingllm cat /app/server/storage/.initial_admin_password
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
  1. Pull the latest code: `cd docker-ai-stack && git pull`
  2. Recreate the AnythingLLM container so the updated bootstrap script
     runs: `docker compose up -d --force-recreate anythingllm`

     ⚠️ This step destroys the old container, so any password currently
     set via Settings → Security will be cleared during the recreation
     and AnythingLLM will revert to its default no-password state —
     leaving the UI publicly accessible until step 3 is done. This is
     the last time that will happen.
  3. Set your password again from Settings → Security. From this point
     onward it will persist across container recreation and upgrades.
