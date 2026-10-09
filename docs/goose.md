# Use goose with Self-Hosted AI Stack

[goose](https://github.com/aaif-goose/goose) is an AI agent for desktop and
terminal workflows. This guide connects it to Self-Hosted AI Stack's
authenticated LiteLLM endpoint and, when needed, MCP Gateway.

goose is not bundled with the stack. The recommended arrangement keeps your
workspace and approval interface on your workstation while the stack provides
local or external model inference:

```text
Workstation                              Self-Hosted AI Stack
+----------------------+                 +---------------------------+
| goose Desktop or CLI | -- LiteLLM --> | LiteLLM -> Ollama/model   |
| local project files  |                 |                           |
| approval prompts     | -- optional -->| MCP Gateway -> tools      |
+----------------------+                 +---------------------------+
```

The model connection works with the full stack and every lightweight stack
that includes LiteLLM. The optional MCP section requires a deployment that also
includes MCP Gateway, such as the full stack, `ai-tools`, or `code-assistant`.

This guide reflects Self-Hosted AI Stack version `2026.09.1` and goose 1.52.0.
goose changes frequently, so compare prompts and menu names with the
[current installation](https://goose-docs.ai/docs/getting-started/installation/)
and [provider](https://goose-docs.ai/docs/getting-started/providers/)
documentation if your version differs.

## Choose a path

- **Workstation goose:** Follow the numbered sections below for ordinary
  interactive work with local project files. The stack may run on another
  machine.
- **[Temporary container on AI Tools](#optional-run-goose-in-a-temporary-container):**
  Use the optional procedure near the end when you need separate agent state
  on the stack server. It begins without host-file access; later tasks can use
  explicit mounts. It has its own setup, test, troubleshooting, and removal
  steps. Do not combine its internal Docker addresses with the workstation URLs
  below.

## Before you begin

You need:

- A running Self-Hosted AI Stack deployment.
- A model configured in LiteLLM.
- Network access from the goose workstation to LiteLLM.
- goose Desktop or the goose CLI installed on the workstation.

The stack normally runs on a Linux server. goose does not have to run on that
server. Install goose on the machine that holds the project files it should
work with, which may be a Linux, macOS, or Windows workstation. If those files
live on the stack server, you can install the native goose CLI on that Linux
server and use `http://127.0.0.1:4000` as the LiteLLM host.

Use native goose first. A containerized agent is more appropriate when you
specifically need a deliberately restricted, reproducible server-side execution
environment. It adds workspace mounts, file ownership, persistent agent state,
and toolchain maintenance that are unnecessary for the normal workstation
workflow.

## 1. Verify the stack and select a model

From the Self-Hosted AI Stack directory on the server, run the health check:

```bash
./stack-check.sh
```

For a lightweight stack, run it from that stack directory:

```bash
../../stack-check.sh
```

List the model aliases exposed by LiteLLM:

```bash
docker exec litellm litellm_manage --listmodels
```

A default installation includes these aliases after the bundled model has been
pulled:

- `ollama/llama3.2:3b`
- `ollama-chat/llama3.2:3b`

Use the `ollama-chat/...` alias when testing tool calls because the stack marks
that route for chat-native behavior and streaming function calls. The 3B model
is useful for verifying the connection. Do not assume that it can complete
multi-step agent or coding work reliably.

You can instead select any stronger local or external model configured in
LiteLLM. Record its exact alias because the virtual key and goose configuration
must use the same value.

## 2. Choose how goose will reach LiteLLM

Set the host URL to the root of the LiteLLM service. Do not add `/v1` or
`/v1/chat/completions`; goose's dedicated LiteLLM provider appends
`v1/chat/completions` by default.

| Workstation location | LiteLLM host URL | Guidance |
|---|---|---|
| Same machine as the stack | `http://127.0.0.1:4000` | Appropriate for local access. |
| Trusted private LAN | `http://<server-ip>:4000` | HTTP exposes prompts and credentials to that network. Use only on a network you trust. |
| Remote or untrusted network | `https://llm.example.com` | Put LiteLLM behind HTTPS, or use the SSH tunnel below. |

### Use an SSH tunnel

An SSH tunnel avoids publishing LiteLLM to an untrusted network. Run this on
the goose workstation and keep the session open:

```bash
ssh -N -L 4000:127.0.0.1:4000 <user>@<server>
```

Then use this LiteLLM host in goose:

```text
http://127.0.0.1:4000
```

### Use HTTPS

The full stack includes a Caddy overlay. Its proxy mode binds LiteLLM's direct
port to localhost, and the included `caddy/Caddyfile` contains a commented
example for a separate LiteLLM hostname. Follow the main README's
[internet-facing deployment instructions](../README.md#internet-facing-deployments),
enable that hostname, and use its HTTPS URL as the goose LiteLLM host.

The lightweight `ai-tools` and `code-assistant` stacks do not include their own
Caddy service. Use the
[docker-litellm reverse proxy guide](https://github.com/hwdsl2/docker-litellm#using-a-reverse-proxy)
or an SSH tunnel.

Never send a LiteLLM key over public, unencrypted HTTP.

## 3. Create a restricted LiteLLM key

Do not give goose the LiteLLM administrative master key for routine use.
Create a virtual key restricted to the selected model. This example uses the
default chat-native alias and expires after 30 days:

```bash
docker exec litellm litellm_manage --createkey \
  --alias goose \
  --models ollama-chat/llama3.2:3b \
  --expires 30d
```

Replace the model after `--models` if you selected another alias. Multiple
aliases can be supplied as a comma-separated list. Save the returned key in a
password manager and treat it as a secret.

Virtual keys require the PostgreSQL database included in the complete and
lightweight stack Compose files. If key creation fails, confirm that the
`litellm-db` container is healthy before retrying:

```bash
docker compose ps
docker compose logs --tail=100 litellm litellm-db
```

## 4. Test the endpoint from the goose workstation

Test network access and authentication before configuring goose. Set the URL,
then enter the virtual key without echoing it:

```bash
export AI_STACK_LITELLM_URL='http://127.0.0.1:4000'
read -r -s -p 'LiteLLM virtual key: ' gateway_virtual_key
printf '\n'
export gateway_virtual_key

curl -fsS "$AI_STACK_LITELLM_URL/v1/models" \
  -H "Authorization: Bearer $gateway_virtual_key"
```

Use your LAN or HTTPS URL instead when applicable. A successful response should
contain the model alias permitted by the virtual key.

Clear the temporary variables after testing:

```bash
unset gateway_virtual_key AI_STACK_LITELLM_URL
```

## 5. Install goose on the workstation

Install goose on the machine identified above. The
[official installation page](https://goose-docs.ai/docs/getting-started/installation/)
provides current downloads for Linux, macOS, and Windows.

### Linux

For the CLI, run the upstream installer as your normal user:

```bash
curl -fsSL \
  https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh \
  | bash
```

For goose Desktop, use the official DEB package on Debian or Ubuntu, the RPM
package on Fedora or RHEL, or the Flatpak package linked from the installation
page.

### macOS

The official Homebrew packages are:

```bash
# Desktop
brew install --cask block-goose

# CLI
brew install block-goose-cli
```

The Linux CLI installer shown above also supports macOS.

### Windows

Use the Desktop download from the installation page. For the CLI, the same
installer runs in Git Bash or MSYS2; the official page also provides native
PowerShell instructions.

If your environment does not permit shell installers, use a release package
from the official goose GitHub releases. Confirm the installed CLI on any
platform where you plan to use it:

```bash
goose --version
```

## 6. Configure the LiteLLM provider

### goose Desktop

1. Open **Settings**, then **Models**.
2. Select **Configure providers**.
3. Choose **LiteLLM**.
4. Enter the LiteLLM host URL selected in Step 2.
5. Enter the virtual key created in Step 3.
6. Select or enter the exact LiteLLM model alias.

For the default connectivity test, the values are:

| Setting | Value |
|---|---|
| Provider | `LiteLLM` |
| Host URL | `http://127.0.0.1:4000` or your LAN/HTTPS URL |
| API key | The restricted LiteLLM virtual key |
| Model | `ollama-chat/llama3.2:3b` |

### goose CLI

Run:

```bash
goose configure
```

Select **Configure Providers**, choose **LiteLLM**, and enter the same host,
virtual key, and model alias. goose stores shared Desktop and CLI configuration
in its normal user configuration location. It stores secrets in the operating
system keyring where supported, or in a local `secrets.yaml` file if the keyring
is disabled or unavailable. Protect that fallback file with appropriate account
and filesystem permissions.

For a temporary configuration or a diagnostic session, use environment
variables instead:

```bash
export GOOSE_PROVIDER=litellm
export GOOSE_MODEL='ollama-chat/llama3.2:3b'
export GOOSE_MODE=approve
export GOOSE_MAX_TURNS=8
export LITELLM_HOST='http://127.0.0.1:4000'
export LITELLM_BASE_PATH='v1/chat/completions'
read -r -s -p 'LiteLLM virtual key: ' LITELLM_API_KEY
printf '\n'
export LITELLM_API_KEY

goose session
```

When finished, clear the credential and temporary provider settings:

```bash
unset GOOSE_PROVIDER GOOSE_MODEL GOOSE_MODE GOOSE_MAX_TURNS
unset LITELLM_HOST LITELLM_BASE_PATH LITELLM_API_KEY
```

Do not place the virtual key in a tracked project file or shell-history command.

## 7. Set permissions before using project files

Upstream goose currently defaults to Autonomous mode. Change it to **Manual
Approval** or **Smart Approval** before the first workspace task, and set the
maximum turns to a small value such as 8 for initial testing. Avoid Autonomous
mode until you have tested the exact model, tools, and task. In goose settings,
review the Developer extension and configure its tools along these lines:

- File and directory reads: **Always Allow** only after starting goose in a
  dedicated project and accepting that it still has the permissions of your
  workstation account.
- File edits and shell commands: **Ask Before**.
- Credential access, destructive commands, and unrelated system paths: **Never Allow**.

Disable extensions that the task does not need. Upstream recommends keeping
fewer than 25 tools enabled, which also reduces the tool descriptions placed in
the model context.

For CLI use, enter the intended project directory before starting a session:

```bash
cd /path/to/project
goose session
```

Native goose runs with the permissions of your workstation account. Approval
prompts reduce accidental actions, but they are not an operating-system sandbox.
The tool permission setting does not by itself restrict filesystem access to
the current project directory.
Use a dedicated checkout or disposable Git worktree for experimental write
tasks, and review changes before committing or publishing them.

## 8. Run bounded tests

Before opening a session, run `goose info` and confirm the expected version and
configuration paths. Avoid sharing the verbose `goose info -v` output without
redacting credentials and other sensitive values. After opening the session,
confirm the model in the Desktop model selector or enter `/model` in the CLI.

Test the model connection before asking goose to use tools or modify anything:

> Reply with exactly: model connection successful. Do not call tools.

Then try a read-only workspace task in a small test project:

> List the files in this project, read its README, and summarize its purpose.
> Do not edit files or run commands that change state.

Finally, if the first two tests succeed, try one reversible edit:

> Add one sentence to the test project's README describing its purpose. Show
> the proposed change and wait for approval before editing the file.

Confirm the request reached LiteLLM:

```bash
docker compose logs --since 5m litellm
```

Confirm the selected provider and model in the goose session interface and the
LiteLLM logs. Judge the result by whether goose used the intended model, chose
appropriate tools, supplied valid arguments, respected approvals, and produced
the requested state. A fluent answer alone does not prove that the agent path
worked.

## Local model and context expectations

Agent quality depends on the exact model, quantization, context allocation, and
task. Parameter count alone does not determine success.

| Model class | Appropriate starting scope |
|---|---|
| Approximately 3B | Connectivity checks, short questions, and tightly supervised single-file tasks. Do not rely on it for autonomous repository work. |
| Approximately 7B to 8B with strong tool calling | Small, bounded edits and short command sequences after testing the exact model and quantization. |
| Larger local or capable external model | More realistic choice for multi-file changes, debugging, planning, and longer agent loops. Still require approval and task limits. |

Ollama currently recommends at least 64K context for agents and coding tools,
but larger context consumes more RAM or VRAM. On constrained hardware, use the
largest allocation that fits without unwanted CPU offload, keep sessions short,
and reduce enabled tools.

To set an explicit Ollama context for this stack, create `ollama.env` beside
the Compose file:

```dotenv
OLLAMA_CONTEXT_LENGTH=64000
```

Then uncomment the existing `./ollama.env:/ollama.env:ro` mount for the
`ollama` service and recreate that service:

```bash
docker compose up -d --force-recreate ollama
```

After sending a request, inspect the allocated context and processor placement:

```bash
docker exec ollama ollama ps
```

goose 1.52 obtains advertised model context metadata from LiteLLM's
`/model/info` endpoint. Ollama controls the context allocated to the running
model. Verify the runtime value instead of assuming those two values are
identical.

If a local model emits tool calls as plain text or malformed JSON, first try a
model with stronger native tool calling. goose also has an
[experimental tool shim](https://goose-docs.ai/docs/guides/tool-shim/), but it
requires a separate interpreter model, adds latency and memory use, and does not
improve the main model's reasoning. It is not enabled in this baseline setup.

## Optional: connect goose directly to MCP Gateway

This section is unnecessary for ordinary local file editing because goose's
Developer extension already operates on the workstation workspace. Add MCP
Gateway only when goose needs a server-side tool supplied by the stack.
This direct goose connection is separate from LiteLLM's internal MCP Gateway
registration.

MCP Gateway is internal to the Docker network by default. A safe first setup
publishes it only on the server's loopback interface and, when goose runs on a
different machine, carries the connection through SSH.

In the active CPU or CUDA Compose file, uncomment the `mcp` port section and
bind it to loopback:

```yaml
ports:
  - "127.0.0.1:3000:3000/tcp"
```

Recreate MCP Gateway and verify it on the server:

```bash
docker compose up -d mcp
docker exec mcp mcp_manage --test fetch
docker exec mcp mcp_manage --list
```

If goose is on another workstation, open a second SSH tunnel there and keep it
running:

```bash
ssh -N -L 3000:127.0.0.1:3000 <user>@<server>
```

Retrieve the MCP key in a private terminal on the server:

```bash
docker exec mcp mcp_manage --showkey
```

In `goose configure`, choose **Add Extension**, then **Remote Extension
(Streamable HTTP)**. Use:

| Setting | Value |
|---|---|
| Name | `self-hosted-fetch` |
| Endpoint | `http://127.0.0.1:3000/mcp` |
| Description | `Authenticated retrieval through Self-Hosted AI Stack` |
| Custom header | `Authorization` |
| Header value | `Bearer <MCP Gateway key>` |

Replace the placeholder with the actual key. Keep the fetch extension as the
only enabled MCP capability for the first test, then ask goose to retrieve
`https://example.com` and report its title. Review the proposed URL before
approving the call.

The default gateway enables only the fetch server. Additional servers may
require credentials, filesystem mounts, or access to external services. Enable
them individually and retest permissions after each change. Do not expose the
MCP port directly to the internet.

## Workstation troubleshooting

### Connection refused or timeout

- Confirm LiteLLM is healthy with `docker compose ps` and `./stack-check.sh`.
- Test `/v1/models` from the goose workstation, not only from the server.
- Confirm that an SSH tunnel is still running.
- In proxy mode, remember that port 4000 is deliberately bound to server
  localhost unless the HTTPS hostname is enabled.

### HTTP 401 or missing API key

- Re-enter the LiteLLM virtual key in the LiteLLM provider configuration.
- Confirm that you did not configure the OpenAI provider with `LITELLM_*`
  variables or the LiteLLM provider with `OPENAI_*` variables.
- Create a new virtual key if the original key expired.

### HTTP 404

- Set the host to the service root, such as `http://127.0.0.1:4000`.
- Keep `LITELLM_BASE_PATH` at `v1/chat/completions`.
- Do not put `/v1` in both the host and base path.

### Model is unavailable

- Run `docker exec litellm litellm_manage --listmodels`.
- Confirm that `GOOSE_MODEL` exactly matches a LiteLLM alias.
- Confirm that the virtual key permits that alias.
- For an Ollama model, confirm it is present with
  `docker exec ollama ollama_manage --listmodels`.

### Tool calls appear as text or fail repeatedly

- Verify that you selected the `ollama-chat/...` alias or another model route
  tested for tool calling.
- Reduce the number of enabled extensions and tools.
- Check the actual context allocation with `docker exec ollama ollama ps`.
- Start a new short session after changing the model or context.
- Treat repeated malformed calls as a model compatibility failure, not merely
  a network problem.

### MCP extension cannot connect

- Confirm the loopback port mapping and SSH tunnel.
- Test `docker exec mcp mcp_manage --test fetch` on the server.
- Confirm the endpoint ends in `/mcp`.
- Confirm the custom header is `Authorization` with value
  `Bearer <actual-key>`.

## Rotate or remove workstation access

When the workstation should no longer use the stack:

1. Delete the goose virtual key in the LiteLLM Admin UI or with
   `litellm_manage --deletekey`.
2. Remove the LiteLLM provider credentials from goose.
3. Remove the MCP extension and rotate the MCP key if it may have been exposed.
4. Close SSH tunnels.
5. Remove the MCP host port mapping if no external client still needs it.

Deleting a client credential does not remove Ollama models, LiteLLM state, or
goose's local session history. Review each store separately when removing
sensitive data.

## Optional: run goose in a temporary container

This path adds goose to the **AI Tools** Compose project only when you launch
its `agent` profile. It is a server-side example with separate state and no
initial host-file mount. Follow the [workstation path](#before-you-begin) for
ordinary project work or when you are keeping a different stack variant. The
commands below are a source-reviewed example, not a claim that an end-to-end
container run has been performed for your image. Check the reported goose
version and CLI before following version-sensitive steps.

goose provides the agent loop while LiteLLM remains the model endpoint and MCP
Gateway remains the authenticated tool boundary. Its official image runs as a
non-root user and supports persistent configuration through a mounted volume.
Approval modes, per-tool permissions, and session limits help bound the first
task. The image digest identifies the exact build you inspected. goose is one
possible runtime, not an endorsement or the only compatible choice. The
[project](https://github.com/aaif-goose/goose) is licensed under Apache License
2.0 and maintained by the Agentic AI Foundation. Its Desktop, CLI, and API
interfaces, dedicated LiteLLM provider, and remote Streamable HTTP MCP
extensions make it a practical fit for this stack. The
[official container image](https://github.com/aaif-goose/goose/pkgs/container/goose)
and [Docker guide](https://github.com/aaif-goose/goose/blob/main/BUILDING_DOCKER.md)
are useful references when the image or CLI changes.

### Container architecture

The existing platform supplies model and controlled-tool interfaces. The goose
container adds the planning loop, session state, and approval experience.

```text
User -> temporary goose container -> LiteLLM -> Ollama or hosted model
                    |
                    +-> MCP Gateway -> enabled MCP servers
                    |
                    +-> goose home volume
```

goose, LiteLLM, and MCP Gateway share the Compose network. goose reaches
LiteLLM at `http://litellm:4000` and MCP Gateway at `http://mcp:3000/mcp`.
MCP Gateway can remain internal, and no goose port is published.

A prompt can still cross external boundaries. If LiteLLM routes to Ollama, the
model request remains on infrastructure you operate. If the selected alias
routes to a hosted provider, that provider receives the prompt and supplied
context. An MCP server can also contact an external service. Containerization
isolates files and processes, but it does not make outbound traffic local.

### Prepare the AI tools stack

This source-reviewed procedure uses the
[AI Tools variant](../stacks/ai-tools/README.md). The Code Assistant variant
has the same model and tool gateways and adds the embeddings service. If the
complete platform or another lightweight variant is already running, do not
start AI Tools beside it with the default names and
volumes. Back up and stop the current project before switching to this exact
container walkthrough. If you are keeping the current stack, use the
workstation path above instead; this guide does not verify a container overlay
for every variant. The commands below assume AI Tools is the selected variant.

If you have not cloned the repository, start in the directory where you keep
project checkouts:

```sh
git clone https://github.com/hwdsl2/self-hosted-ai-stack
```

From the directory containing the checkout, enter AI Tools. If your shell is
already there, stay in that directory. Run all remaining commands in this
container walkthrough from `stacks/ai-tools` unless a step says otherwise:

```sh
cd self-hosted-ai-stack/stacks/ai-tools
```

If AI Tools is not already running, start it and pull a model:

```sh
docker compose up -d
docker exec ollama ollama_manage --pull llama3.2:3b
```

Whether you started AI Tools now or are reusing it, verify its services:

```sh
../../stack-check.sh
```

List the LiteLLM aliases and enabled MCP servers:

```sh
docker exec litellm litellm_manage --listmodels
docker exec mcp mcp_manage --list
```

Choose a model alias that supports function calling. Small local models are
useful for confirming connectivity, but their tool selection can be less
reliable than that of larger models. Treat model quality and integration
correctness as separate questions during troubleshooting.

### Draft the optional goose service

Select an image reference from the official goose container package. For an
initial compatibility inspection, the upstream Docker guide currently uses the
mutable `latest` tag:

```sh
export GOOSE_IMAGE=ghcr.io/aaif-goose/goose:latest
```

Do not treat `latest` as a reproducible release identifier. The inspection
steps below retrieve its immutable repository digest. Use that digest for the
configuration and bounded task, and retain it with the
verification notes for your deployment.

Create `docker-compose.goose.yml` in
`self-hosted-ai-stack/stacks/ai-tools` with this content:

```yaml
services:
  goose:
    image: ${GOOSE_IMAGE:?Set GOOSE_IMAGE in the shell}
    profiles: ["agent"]
    restart: "no"
    init: true
    stdin_open: true
    tty: true
    environment:
      GOOSE_PROVIDER: litellm
      GOOSE_MODEL: ${GOOSE_MODEL:?Set GOOSE_MODEL in the shell}
      LITELLM_HOST: http://litellm:4000
      LITELLM_API_KEY: ${GOOSE_LITELLM_API_KEY:?Set GOOSE_LITELLM_API_KEY in the shell}
      GOOSE_MODE: approve
      GOOSE_DISABLE_KEYRING: "1"
    volumes:
      - goose-home:/home/goose
    depends_on:
      litellm:
        condition: service_healthy
      mcp:
        condition: service_healthy
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true

volumes:
  goose-home:
    name: ai-tools-goose-home
```

The `agent` profile prevents the service from joining ordinary startup. The
configuration also drops Linux capabilities, prevents privilege escalation,
publishes no port, and mounts only agent-owned named volumes. It does not mount
a project directory, home directory, container socket, or credential directory.

`goose-home` contains settings, extension credentials, sessions, and logs. The
official image creates `/home/goose` for its non-root user, and an initially
empty named volume receives that directory's ownership and contents. Treat the
volume as sensitive persistent state and include or exclude it from backups
deliberately.

### Create a restricted model credential

Do not give goose LiteLLM's administrative master key for routine work. Create
a virtual key restricted to the selected model alias. Replace
`your-model-alias` with an alias from `--listmodels` before running this
command:

```sh
docker exec litellm litellm_manage --createkey \
  --alias goose \
  --models your-model-alias \
  --expires 30d
```

Save the returned virtual key in your password manager. Then set the model
alias and enter the key without echoing it to the terminal:

```bash
export GOOSE_MODEL=your-model-alias
read -r -s -p "LiteLLM virtual key: " GOOSE_LITELLM_API_KEY
printf '\n'
export GOOSE_LITELLM_API_KEY
```

Replace `your-model-alias` with the same alias used to create the key. These
variables apply only to the current shell and are not written to the Compose
file. Docker can still expose a running container's environment to users with
Docker administration access, so the virtual key should remain narrow and
short-lived.

MCP Gateway uses a separate generated key. Display its connection details only
in a private terminal and avoid recording the output in screenshots or logs:

```sh
docker exec mcp mcp_manage --showkey
```

Do not store either credential in a tracked environment file.

### Check the current goose image and CLI

Pull the selected image and ask it to report its version:

```sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent pull goose

docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent run --rm goose --version
```

The goose 1.52.0 source snapshot reviewed for this guide defines `configure`,
`info`, and `session`, with `--max-turns` and `--max-tool-repetitions` on
interactive sessions. Confirm that the image exposes the same interfaces before
relying on the remaining commands:

```sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent run --rm goose session --help

docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent run --rm goose info --help
```

If either command or either session-limit flag is absent, stop here and adapt
the procedure from the documentation that matches the reported version. Do not
substitute a similar-looking flag without confirming its semantics.

Retrieve and record the image's immutable repository digest:

```sh
docker image inspect "$GOOSE_IMAGE" \
  --format '{{index .RepoDigests 0}}'
```

Before continuing, copy the complete value returned by that command and use it
as `GOOSE_IMAGE` in the current shell. It has the form shown below, but the
digest placeholder must be replaced with the exact value you retrieved:

```sh
export GOOSE_IMAGE='ghcr.io/aaif-goose/goose@sha256:replace-with-retrieved-digest'
```

Render the merged configuration with the digest-pinned reference:

```sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent config --quiet
```

If these checks succeed, the temporary containers should have exited and the
named home volume should remain available for later configuration and sessions.
These checks confirm CLI and Compose compatibility for the selected image.

### Try configuring one authenticated MCP extension

The menu labels below reflect the goose 1.52.0 source snapshot reviewed for
this guide. If the pulled version presents different choices, use its official
extension documentation to locate the equivalent settings. Run the
configuration utility inside a temporary container:

```sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent run --rm goose configure
```

Do not assume that a desktop keyring is available inside the container. The
Compose service sets `GOOSE_DISABLE_KEYRING=1`, which makes goose use file-based
secret storage. Durable settings, the custom authorization header, sessions,
and logs therefore remain within the agent's named home volume. Treat that
volume as credential-bearing data.

Confirm that the effective provider is LiteLLM and that the model is the exact
alias selected from `--listmodels`. Then select **Toggle Extensions** and
disable the Developer extension. The reviewed source and documentation also
show several platform extensions enabled by default. Review the complete
enabled list and disable analysis, application, extension-management, skills,
task, delegation, scheduling, or other capabilities that the exercise does not
require. The goal is for the configured fetch extension to be the only tool
source available to this session. If the current build does not let you reach
that state, do not continue with the example.

Use **Add Extension** to create one remote Streamable HTTP extension:

| Setting | Value |
|---|---|
| Name | `self-hosted-fetch` |
| Endpoint | `http://mcp:3000/mcp` |
| Description | `Authenticated web retrieval through MCP Gateway` |
| Custom header name | `Authorization` |
| Custom header value | `Bearer <MCP Gateway key>` |

The angle-bracketed value is a placeholder. Enter the actual key after the word
`Bearer`, without angle brackets. The extension configuration persists in the
named volume after the temporary container exits. The current CLI collects a
custom header as ordinary terminal input and persists it with the extension
configuration, so perform this step in a private terminal and do not capture
the screen or terminal transcript while entering the credential.

Do not run `goose info -v` or print the configuration after storing credentials
or custom headers. Verbose configuration output can contain sensitive values.

The default MCP Gateway configuration enables the fetch server. Verify that
assumption against the deployed gateway:

```sh
docker exec mcp mcp_manage --list
docker exec mcp mcp_manage --test fetch
```

If you customized the gateway, ensure only the servers required for this
exercise are enabled. Fetch does not directly modify its target, but
unrestricted URL retrieval can still reach internal web services or disclose
their responses. Apply outbound destination controls when the environment
requires them.

### Try a bounded read-only task

If the version, help, Compose, provider, and extension checks above all match,
try a temporary interactive agent with a small turn limit and a
repeated-tool-call limit:

```sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent run --rm goose session \
  --max-turns 8 \
  --max-tool-repetitions 2
```

Use a narrow prompt:

> Use only the self-hosted-fetch extension. Retrieve https://example.com,
> report the page title, and summarize the page's purpose in two sentences. Do
> not use shell or file tools.

The prompt describes intent, but it is not the security boundary. The absent
host mounts, disabled broad extensions, limited MCP server set, separate
credentials, approval mode, dropped capabilities, and command-line limits
provide the meaningful controls.

Check the attempted result at each boundary rather than assuming success:

1. Confirm that goose reports the configured LiteLLM alias rather than a silent
   fallback.
2. Before approving a tool call, confirm that it identifies the expected fetch
   extension and URL.
3. Confirm that no shell, host-file, delegation, scheduling,
   extension-management, or application tool is available.
4. Confirm that LiteLLM and MCP Gateway record corresponding requests without
   exposing credential values.
5. Confirm that the goose container is removed after the session exits.

Any mismatch is a failed compatibility or boundary check. Stop the session,
preserve only sanitized diagnostics, and reconcile the image's documentation
and effective configuration before retrying. Do not interpret a fluent answer
as proof that the intended model and tool path were used.

Inspect recent gateway logs:

```sh
docker compose logs --since 5m litellm mcp
```

Confirm the agent version and storage locations, without printing verbose
configuration, in another temporary container:

```sh
docker compose \
  -f docker-compose.yml \
  -f docker-compose.goose.yml \
  --profile agent run --rm goose info
```

Do not enable debug output when prompts, tool arguments, or returned documents
contain sensitive data. Debug logs can preserve more information than ordinary
session output.

### Understand what the container boundary does

The container prevents goose from seeing arbitrary host files unless you mount
them. It also gives the agent its own process, filesystem, and Linux capability
boundary. Those protections are valuable, but incomplete:

- The agent can reach services allowed by its Docker network and outbound
  network policy.
- It can modify its writable home volume.
- Docker administrators can inspect or control the container.
- A mounted directory grants the container the access specified by that mount.
- Prompt injection can still influence model-selected tool calls.
- Approval can still be mistaken or too broad.

Never mount `/var/run/docker.sock` into an agent container. Access to the Docker
socket commonly provides control over the host and the other containers, which
would defeat the isolation this design is intended to provide.

### Add filesystem access only when required

The fetch example needs no workspace. If a later task must inspect files, add
one explicit mount to the goose service instead of mounting a home directory.
Start read-only:

```yaml
    volumes:
      - goose-home:/home/goose
      - /srv/agent-work/demo:/workspace:ro
    working_dir: /workspace
```

Use a dedicated path containing only material the agent may read. If the task
must write, use a disposable worktree or staging directory, change only that
mount to read-write, and require approval before any commit, publication,
external message, or production action.

Separate read, propose, and execute permissions. The container may prepare a
change in a dedicated worktree while a human-controlled process performs the
final commit, push, deployment, or other consequential action.

### Apply tool permissions and stop conditions

Use goose tool permissions to classify each enabled tool:

- **Always Allow** only for operations that are truly safe and read-only in the
  current environment.
- **Ask Before** for writes, commands, external side effects, or operations
  whose target can vary.
- **Never Allow** for capabilities the task does not require.

Human confirmation should normally gate deletion, publication, external
messages, purchases, production changes, credential operations, privilege
changes, and irreversible or high-impact writes. Approval belongs immediately
before the consequential action, after the exact target and payload are known.

Set limits that correspond to the potential impact of the task:

- Maximum turns and repeated identical tool calls
- Maximum elapsed time and retries
- Provider cost or token budget where applicable
- Allowed directories, hosts, repositories, and database roles
- A stop on authentication failure, ambiguous targets, or repeated tool errors
- A stop when the task needs authority outside the original request

Record the task identity, image digest, selected model, enabled tools, sanitized
arguments, approvals, results, and final state. Keep enough information to
reconstruct a failure without turning logs into another store of secrets or
personal data.

### Test failure and abuse cases

A successful fetch proves only the basic connection. Before permitting writes
or production access, test:

- Web pages or documents containing prompt injection
- Tool output that falsely claims an action succeeded
- Timeouts after a partial write
- Duplicate retries and repeated identical calls
- Missing or expired credentials
- Permission denial and unavailable approval
- Attempts to reach unapproved networks, files, or environment variables
- Results that exceed size, turn, time, or cost limits
- Attempts to access host paths or the Docker socket

Release a workflow only after these tests show that authorization, approvals,
idempotency, budgets, and stop conditions behave as intended.

### Do not make the first agent an unattended service

The official image can run headless commands or a background goose server, but
that is not the starting pattern for this guide. A continuously running agent
needs its own authenticated user interface or API, concurrency policy, approval
channel, scheduler, audit trail, cancellation behavior, and recovery design.

Keep the initial service definition behind the `agent` profile and invoke it
with `docker compose run --rm`. Add unattended execution only for a narrowly
defined task after its credentials, approval behavior, failure recovery, and
stop conditions have been tested independently.

### Troubleshoot by boundary

If the container cannot start, confirm that the current shell contains
`GOOSE_IMAGE`, `GOOSE_MODEL`, and `GOOSE_LITELLM_API_KEY`, then render the
combined Compose configuration. A missing variable should stop interpolation
instead of silently starting with an empty image reference or credential.

If model calls fail, verify that LiteLLM is healthy, the virtual key is current,
and the exact alias is allowed by that key. Inside the Compose network, use
`http://litellm:4000`, not a host loopback address.

If goose cannot list or call a tool, confirm that the endpoint is
`http://mcp:3000/mcp`, the header contains the `Bearer` scheme, and the gateway
key is current. Test the fetch server with `mcp_manage` before changing the
agent configuration.

If a task can see unexpected tools, stop the session. Recheck enabled goose
extensions, per-tool permissions, the Compose mounts, inherited environment
variables, and enabled MCP servers before continuing.

### Remove the optional agent

To reverse the example:

1. Exit the goose session and confirm that its temporary container was removed.
2. Delete the LiteLLM virtual key using the Admin UI or the key-management
   commands in the [LiteLLM guide](https://github.com/hwdsl2/docker-litellm#virtual-key-management).
3. Remove `docker-compose.goose.yml` from the stack directory.
4. Review `ai-tools-goose-home` according to your backup and retention policy.
   If it may be deleted and no agent container is using it, remove it with
   `docker volume rm ai-tools-goose-home`.
5. Clear the credentials from the current shell:

```sh
unset GOOSE_IMAGE GOOSE_LITELLM_API_KEY GOOSE_MODEL
```

Removing the overlay prevents new agent containers from being created. It does
not delete the named volume or its session and configuration data. A retained
volume still holds the MCP extension credential; protect it as sensitive data.
Removing the agent volume does not affect Ollama models, LiteLLM state, or MCP
Gateway configuration. Rotate the gateway key if it may have been exposed,
accounting for other clients that use it.

## Upstream references

- [Stack Compose definition](../docker-compose.yml)
- [AI Tools Compose definition](../stacks/ai-tools/docker-compose.yml)
- [Stack HTTPS proxy overlay](../docker-compose.proxy.yml)
- [Stack Caddy configuration](../caddy/Caddyfile)
- [docker-litellm management commands](https://github.com/hwdsl2/docker-litellm/blob/main/manage.sh)
- [docker-mcp-gateway management commands](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/manage.sh)
- [goose 1.52.0 LiteLLM provider implementation](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/providers/litellm.rs)
- [goose container image](https://github.com/aaif-goose/goose/pkgs/container/goose)
- [goose Docker guide](https://github.com/aaif-goose/goose/blob/main/BUILDING_DOCKER.md)
- [goose installation](https://goose-docs.ai/docs/getting-started/installation/)
- [goose provider configuration](https://goose-docs.ai/docs/getting-started/providers/)
- [goose tool permissions](https://goose-docs.ai/docs/guides/managing-tools/tool-permissions/)
- [goose tool shim](https://goose-docs.ai/docs/guides/tool-shim/)
- [Ollama context length](https://docs.ollama.com/context-length)
- [Ollama tool calling](https://docs.ollama.com/capabilities/tool-calling)
