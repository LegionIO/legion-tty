# legion-tty

Rich terminal UI for the LegionIO async cognition engine.

Think Claude Code meets Codex CLI, but for LegionIO: onboarding wizard with identity detection, streaming AI chat shell, operational dashboard, and session persistence - all rendered with the [tty-ruby](https://ttytoolkit.org/) gem ecosystem.

## Features

- **Onboarding wizard** - First-run setup with Kerberos identity detection, GitHub profile probing, environment scanning, and LLM provider selection
- **Digital rain intro** - Matrix-style rain using discovered LEX extension names
- **AI chat shell** - Streaming LLM chat with slash commands, tool panels, and markdown rendering
- **Operational dashboard** - Service status, extension inventory, system info, recent activity (Ctrl+D or `/dashboard`)
- **Session persistence** - Auto-save on quit, `/save`, `/load`, `/sessions` to manage history across runs
- **Token tracking** - Real-time input/output token counts and estimated cost via `/cost`
- **Hotkey navigation** - Ctrl+D (dashboard), Ctrl+L (refresh), ? (help overlay)
- **Second-run flow** - Skips onboarding, re-scans environment, drops into chat

## Installation

```bash
gem install legion-tty
```

Or via Homebrew (if legion is installed):

```bash
brew install legion
```

## Usage

### Standalone

```bash
legion-tty
```

### Via LegionIO CLI

```bash
legion tty              # launch rich TUI (default: interactive)
legion tty reset        # clear identity, re-run onboarding
legion tty sessions     # list saved chat sessions
legion tty version      # show legion-tty version
```

### Quick prompt (via legion chat)

```bash
legion chat prompt "explain async cognition"
```

## Slash Commands

| Command | Description |
|---------|-------------|
| `/help` | Show all commands |
| `/quit` | Exit (auto-saves session) |
| `/clear` | Clear message history |
| `/model <name>` | Switch LLM model at runtime |
| `/session <name>` | Rename current session |
| `/cost` | Show token usage and estimated cost |
| `/export [md\|json]` | Export chat history to file |
| `/tools` | List discovered LEX extensions |
| `/dashboard` | Toggle operational dashboard |
| `/hotkeys` | Show registered hotkey bindings |
| `/save [name]` | Save current session |
| `/load <name>` | Load a saved session |
| `/sessions` | List all saved sessions |

## Architecture

```
legion-tty
  App                    # Orchestrator: config, LLM setup, screen management
  ScreenManager          # Push/pop screen stack with overlay support
  Hotkeys                # Keybinding registry
  SessionStore           # JSON-based session persistence
  BootLogger             # Boot sequence logging

  Screens/
    Onboarding           # First-run wizard (rain -> intro -> wizard -> reveal)
    Chat                 # AI chat REPL with streaming + slash commands
    Dashboard            # Operational status panels

  Components/
    DigitalRain          # Matrix-style falling characters
    InputBar             # Prompt line with thinking indicator
    MessageStream        # Scrollable message history
    StatusBar            # Model, tokens, cost, session display
    ToolPanel            # Expandable tool use panels
    MarkdownView         # TTY::Markdown rendering
    WizardPrompt         # TTY::Prompt wrappers
    TokenTracker         # Token counting and cost estimation

  Background/
    Scanner              # Service port probing, git repo discovery, shell history
    GitHubProbe          # GitHub API profile, repos, PRs, notifications
    KerberosProbe        # klist + LDAP profile resolution
```

## Comparison

| Feature | legion-tty | Claude Code | Codex CLI |
|---------|-----------|-------------|-----------|
| Onboarding wizard | Yes (identity detection) | No (API key only) | No |
| Streaming chat | Yes | Yes | Yes |
| Tool use panels | Yes | Yes | Yes |
| Dashboard | Yes (services, extensions) | No | No |
| Session persistence | Yes | Yes (conversations) | No |
| Environment scanning | Yes (services, repos, history) | Yes (git context) | Yes (git context) |
| Extension ecosystem | Yes (LEX gems) | Yes (MCP servers) | Yes (tools) |
| Identity probing | Yes (Kerberos, GitHub, LDAP) | No | No |
| Token/cost tracking | Yes | Yes | Yes |
| Hotkey navigation | Yes | Yes | No |

## Configuration

Identity and credentials are stored in `~/.legionio/settings/`:

- `identity.json` - Name, Kerberos identity, GitHub profile, environment scan
- `credentials.json` - LLM provider and API key (chmod 600)

Sessions are stored in `~/.legionio/sessions/`.
Exports go to `~/.legionio/exports/`.
Boot logs go to `~/.legionio/logs/tty-boot.log`.

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

Apache-2.0
