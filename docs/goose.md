# Use goose with Self-Hosted AI Stack

[goose](https://github.com/aaif-goose/goose) is a native AI agent for desktop
and terminal workflows. This guide connects goose on your workstation to the
authenticated LiteLLM endpoint provided by Self-Hosted AI Stack.

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

This guide reflects Self-Hosted AI Stack version `2026.08.2` and goose 1.52.0.
goose changes frequently, so compare prompts and menu names with the
[current installation](https://goose-docs.ai/docs/getting-started/installation/)
and [provider](https://goose-docs.ai/docs/getting-started/providers/)
documentation if your version differs.

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
read -r -s -p 'LiteLLM virtual key: ' AI_STACK_LITELLM_KEY
printf '\n'
export AI_STACK_LITELLM_KEY

curl -fsS "$AI_STACK_LITELLM_URL/v1/models" \
  -H "Authorization: Bearer $AI_STACK_LITELLM_KEY"
```

Use your LAN or HTTPS URL instead when applicable. A successful response should
contain the model alias permitted by the virtual key.

Clear the temporary variables after testing:

```bash
unset AI_STACK_LITELLM_KEY AI_STACK_LITELLM_URL
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

## Troubleshooting

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

## Rotate or remove access

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

## Upstream references

- [Stack Compose definition](../docker-compose.yml)
- [Stack HTTPS proxy overlay](../docker-compose.proxy.yml)
- [Stack Caddy configuration](../caddy/Caddyfile)
- [docker-litellm management commands](https://github.com/hwdsl2/docker-litellm/blob/main/manage.sh)
- [docker-mcp-gateway management commands](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/manage.sh)
- [goose 1.52.0 LiteLLM provider implementation](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/providers/litellm.rs)
- [goose installation](https://goose-docs.ai/docs/getting-started/installation/)
- [goose provider configuration](https://goose-docs.ai/docs/getting-started/providers/)
- [goose tool permissions](https://goose-docs.ai/docs/guides/managing-tools/tool-permissions/)
- [goose tool shim](https://goose-docs.ai/docs/guides/tool-shim/)
- [Ollama context length](https://docs.ollama.com/context-length)
- [Ollama tool calling](https://docs.ollama.com/capabilities/tool-calling)
