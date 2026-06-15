---
name: Bug report
about: Tell us about a problem you are experiencing
title: ''
labels: ''
assignees: ''

---
**Checklist**

- [ ] I read the [README](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README.md) or the relevant stack README
- [ ] I searched existing [Issues](https://github.com/hwdsl2/self-hosted-ai-stack/issues?q=is%3Aissue)
- [ ] This issue is about self-hosted-ai-stack, a stack integration, or I am not sure which service is affected

**Describe the issue**
A clear and concise description of the problem.

**Affected service(s)**
Examples: Ollama, LiteLLM, AnythingLLM, Whisper, WhisperLive, Kokoro, Embeddings, MCP Gateway, Docling, PostgreSQL/pgvector, Caddy, Docker Compose, unsure.

**Stack used**
- [ ] Full stack
- [ ] `chat-ui`
- [ ] `voice-pipeline`
- [ ] `voice-chat`
- [ ] `rag-pipeline`
- [ ] `rag-pipeline-full`
- [ ] `code-assistant`
- [ ] `ai-tools`
- [ ] `chat-only`
- [ ] Other / custom

**To Reproduce**
Steps to reproduce the behavior:

1. ...
2. ...

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment**
- Docker host OS: [e.g. Ubuntu 24.04]
- Hosting provider (if applicable): [e.g. AWS, GCP, home server]
- CPU architecture: [e.g. amd64, arm64]
- GPU/CUDA setup (if applicable):
- Compose command/files used: [e.g. `docker compose up -d`, `docker-compose.cuda.yml`]
- Any modified env files or compose files, with secrets removed:

**Checks and logs**
If available, include output from:

```bash
./stack-check.sh
docker compose logs
```

For one affected service, include:

```bash
docker compose logs <service>
```

**Reproduces outside self-hosted-ai-stack?**
If you know whether this also happens in an individual service repo, mention it here.

**Additional context**
Add any other context about the problem here.
