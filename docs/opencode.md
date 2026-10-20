# OpenCode and 1Password

Start the OpenCode V2 TUI with `opencode`. Approve the 1Password CLI prompt
when requested. The launcher uses a private server (`--standalone`) so an
already-running background service cannot silently ignore the injected keys.
Only `opencode` and `vibe` are installed as commands; both wrap their upstream
package with 1Password.

The launcher uses `op run --no-masking` to keep stdout/stderr attached to the
terminal for TUI sizing and redraws. 1Password still injects credentials at
runtime, but does not redact secrets printed by the application. Avoid printing
credentials or sharing unreviewed logs.

By default, `op run` resolves references to the AI vault at runtime. The Nix
store contains references, not API keys. Credentials are not copied into
OpenCode's credential store. The configured providers use their standard API
endpoints: MiniMax, Mistral, Venice, Moonshot AI, OpenRouter, Z.AI and DeepSeek.
Coding-plan credentials may require a different provider/endpoint; these are
not assumed from the vault item names. The Cursor key is deliberately omitted:
it is not a supported general-purpose model-provider credential.

## Switch to a 1Password Environment

In 1Password, open **Developer > Environments**, create an **OpenCode**
environment, and add these variables with concealed values from the AI vault:

| Variable | Vault item |
| --- | --- |
| `MINIMAX_API_KEY` | Pi API - minimax |
| `MISTRAL_API_KEY` | PI API - Mistral |
| `VENICE_API_KEY` | Pi API - Venice AI |
| `MOONSHOT_API_KEY` | Pi API - kimi |
| `OPENROUTER_API_KEY` | Pi API - openrouter |
| `ZHIPU_API_KEY` | Pi API - zai |
| `DEEPSEEK_API_KEY` | Pi API - deepseek |

Mount the Environment using **Connect > Local .env file** at
`~/.config/opencode/1password.env` (or the equivalent under `$XDG_CONFIG_HOME`).
Do not create a normal file there or paste secrets into the repository.
`opencode` automatically prefers this FIFO over the vault references, and
refuses a regular plaintext file at that path. An existing FIFO whose read or
authorization fails does not fall back to a different credential source.

The Environment is managed in 1Password, not created by Nix. The launcher does
not need the newer CLI's `op run --environment` support. Environment values
copied from vault items must be updated separately when those keys rotate.
1Password must be running; locking it prevents new authorized FIFO reads but
does not revoke keys already loaded into a running OpenCode process.

## Mistral Vibe CLI

`vibe` wraps the `mistral-vibe` package from the `llm-agents` input with the
same `op run` launcher as `opencode`, including the `--no-masking` exception.
The keys differ, so it does not share the OpenCode FIFO: it prefers its own
FIFO at `~/.config/vibe/1password.env` and otherwise falls back to a store
file that references the Pro-plan key (`API - Mistral Vipe Pro` in the AI
vault) as `MISTRAL_API_KEY`. opencode keeps `PI API - Mistral`; a coding-plan
credential is not assumed to work against the general API endpoint.

For Mistral-provider setups the CLI defaults to browser-based sign-in
(`vibe --setup`), which provisions its own credentials via the system keyring;
nothing lands in `~/.vibe`. Environment variables take precedence over
`~/.vibe/.env` and `config.toml`, and `/status` shows the credential source
in use and the shadowed ones. `~/.vibe` holds `config.toml` (agents, presets,
model settings) and caches only, which is why it is persisted.

## Venice MCP

The global configuration runs `@veniceai/mcp-server@0.3.0` locally using Node.js
and `VENICE_API_KEY`. Its first start needs network access to download the
pinned npm package. This is a runtime npm install, not a Nix-locked dependency.
Check the connection in `/mcps` after starting `opencode`.
Use an inference key unless you explicitly need billing/admin operations;
generation tools can consume paid credits.

The 1Password MCP server is no longer configured or packaged. Normal
1Password CLI, GUI and SSH-agent support remain unchanged.
