# Contributing

Thanks for helping improve Docker AI Stack. This repository maintains the multi-service Docker Compose stack; changes that only affect one service image usually belong in that service's repository.

## Before You Start

- Search existing issues and pull requests.
- Keep changes focused and easy to review.
- Use this repo for stack composition, service wiring, examples, documentation, and cross-service behavior.
- Use the individual service repos for image/runtime changes to Ollama, LiteLLM, Whisper, Kokoro, Embeddings, Docling, or MCP Gateway.
- Do not include API keys, provider credentials, model files, private prompts, private documents, or logs with secrets.

## Pull Requests

- Update `README.md`, `CHANGELOG.md`, env examples, stack examples, or docs when behavior changes.
- Note which stack was tested: root stack, CUDA stack, proxy overlay, or a lightweight stack.
- For service image changes, link the matching PR or release in the service repo.

## Testing

Test the smallest relevant stack path before opening a PR, for example:

- Run `docker compose config` when editing compose files.
- Run `./stack-check.sh` when changing service wiring or health checks.
- Test the affected stack preset when changing a lightweight stack.
- Check backup/restore or upgrade notes when changing volumes, credentials, or persistence.
