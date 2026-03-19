# legion-tty

Rich terminal UI for the LegionIO async cognition engine.

**Version**: 0.4.1

Think Claude Code meets Codex CLI, but for LegionIO: onboarding wizard with identity detection, streaming AI chat shell, operational dashboard, extensions browser, config editor, and session persistence - all rendered with the [tty-ruby](https://ttytoolkit.org/) gem ecosystem.

## Features

- **Onboarding wizard** - First-run setup with Kerberos identity detection, GitHub profile probing, environment scanning, and LLM provider selection
- **Digital rain intro** - Matrix-style rain using discovered LEX extension names
- **AI chat shell** - Streaming LLM chat with 19 slash commands, tab completion, markdown rendering, and tool panels
- **Operational dashboard** - Service status, extension inventory, system info, recent activity (Ctrl+D or `/dashboard`)
- **Extensions browser** - Browse installed LEX gems by category (core, agentic, service, AI, other) with detail view
- **Config viewer/editor** - View and edit `~/.legionio/settings/*.json` with vault:// masking
- **Command palette** - Fuzzy-search overlay for all commands, screens, and sessions (Ctrl+K or `/palette`)
- **Model picker** - Switch LLM providers interactively
- **Session management** - Auto-save on quit, `/save`, `/load`, `/sessions`, session picker (Ctrl+S)
- **Token tracking** - Per-model pricing for 9 models across 8 providers via `/cost`
- **Plan mode** - Bookmark messages without sending to LLM (`/plan`)
- **Hotkey navigation** - Ctrl+D (dashboard), Ctrl+K (palette), Ctrl+S (sessions), Escape (back)
- **Tab completion** - Type `/` and Tab to auto-complete slash commands
- **Progress panel** - Visual progress bars for long operations (extension scanning, gem ops)
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
legion-tty --skip-rain    # skip digital rain animation
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
| `/help` | Show all commands and hotkeys |
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
| `/system <prompt>` | Set or override system prompt |
| `/delete <session>` | Delete a saved session |
| `/plan` | Toggle read-only bookmark mode |
| `/palette` | Open command palette (fuzzy search) |
| `/extensions` | Browse installed LEX extensions |
| `/config` | View and edit settings files |

## Hotkeys

| Key | Action |
|-----|--------|
| Ctrl+D | Toggle dashboard |
| Ctrl+K | Open command palette |
| Ctrl+S | Open session picker |
| Ctrl+L | Refresh screen |
| Escape | Go back / dismiss overlay |
| Tab | Auto-complete slash commands |

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
    Extensions           # LEX gem browser by category
    Config               # Settings file viewer/editor

  Components/
    DigitalRain          # Matrix-style falling characters
    InputBar             # Prompt line with tab completion + thinking indicator
    MessageStream        # Scrollable message history with markdown rendering
    StatusBar            # Model, plan mode, thinking, tokens, cost, session
    ToolPanel            # Expandable tool use panels
    MarkdownView         # TTY::Markdown rendering
    WizardPrompt         # TTY::Prompt wrappers
    TokenTracker         # Per-model token counting and cost estimation
    CommandPalette       # Fuzzy-search command/screen/session overlay
    ModelPicker          # LLM provider/model selection
    SessionPicker        # Session list and selection
    TableView            # TTY::Table wrapper
    ProgressPanel        # TTY::ProgressBar wrapper

  Background/
    Scanner              # Service port probing, git repo discovery, shell history
    GitHubProbe          # GitHub API profile, repos, PRs, notifications
    KerberosProbe        # klist + LDAP profile resolution
```

## LLM Integration

legion-tty uses **Legion::LLM exclusively** for all LLM operations. No direct RubyLLM calls. If Legion::LLM is not available or not started, the chat shell runs without LLM (commands still work, messages show "LLM not configured").

The boot sequence mirrors `Legion::Service`: logging -> settings -> crypt -> resolve_secrets -> LLM merge -> start.

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
bundle exec rspec       # 598 examples, 0 failures
bundle exec rubocop     # 68 files, 0 offenses
```

## License

Apache-2.0
