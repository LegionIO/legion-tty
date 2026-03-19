# legion-tty

Rich terminal UI for the LegionIO async cognition engine.

**Version**: 0.4.18

Think Claude Code meets Codex CLI, but for LegionIO: onboarding wizard with identity detection, streaming AI chat shell with 60 slash commands, operational dashboard, extensions browser, config editor, and session persistence - all rendered with the [tty-ruby](https://ttytoolkit.org/) gem ecosystem.

## Features

- **Onboarding wizard** - First-run setup with Kerberos identity detection, GitHub profile probing, environment scanning, and LLM provider selection
- **Digital rain intro** - Matrix-style rain using discovered LEX extension names
- **AI chat shell** - Streaming LLM chat with 60 slash commands, tab completion, markdown rendering, and tool panels
- **Operational dashboard** - Service/LLM status, extension inventory, system info, panel navigation (Ctrl+D or `/dashboard`)
- **Extensions browser** - Browse installed LEX gems by category with detail view and homepage opener ('o' key)
- **Config viewer/editor** - View and edit `~/.legionio/settings/*.json` with vault:// masking and JSON validation
- **Command palette** - Fuzzy-search overlay for all commands, screens, and sessions (Ctrl+K or `/palette`)
- **Model picker** - Switch LLM providers interactively
- **Session management** - Auto-save on quit, `/save`, `/load`, `/sessions`, `/rename`, session picker (Ctrl+S)
- **Token tracking** - Per-model pricing for 9 models across 8 providers via `/cost`
- **Plan mode** - Bookmark messages without sending to LLM (`/plan`)
- **Personality styles** - Switch between default, concise, detailed, friendly, technical (`/personality`)
- **Theme selection** - Four built-in themes: purple (default), green, blue, amber (`/theme`)
- **Conversation tools** - `/compact`, `/copy`, `/diff`, `/search`, `/grep`, `/stats`, `/undo`
- **Message pinning** - Pin important messages (`/pin`), view pins (`/pins`), export bookmarks (`/bookmark`)
- **Command aliases** - Create custom shortcuts for frequently used commands (`/alias`)
- **Code snippets** - Save and load reusable text snippets (`/snippet`)
- **Debug mode** - Toggle internal state display (`/debug`)
- **Session context** - View active settings summary (`/context`)
- **Toast notifications** - Transient status bar messages for save/load/export/theme actions
- **Hotkey navigation** - Ctrl+D (dashboard), Ctrl+K (palette), Ctrl+S (sessions), Escape (back)
- **Tab completion** - Type `/` and Tab to auto-complete slash commands
- **Input history** - Up/down arrow to navigate previous inputs, `/history` to view
- **Progress panel** - Visual progress bars for long operations
- **Animated spinner** - Status bar spinner during LLM thinking
- **Daemon routing** - Routes through LegionIO daemon when available, falls back to direct
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
| `/session <name>` | Set session name |
| `/cost` | Show token usage and estimated cost |
| `/export [md\|json\|html]` | Export chat history to file |
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
| `/theme [name]` | Switch color theme (purple/green/blue/amber) |
| `/search <text>` | Search message history |
| `/grep <pattern>` | Regex search across messages |
| `/compact [N]` | Keep last N message pairs, remove older |
| `/copy` | Copy last assistant response to clipboard |
| `/diff` | Show new messages since last session load |
| `/stats` | Show conversation statistics |
| `/personality [style]` | Switch personality (default/concise/detailed/friendly/technical) |
| `/undo` | Remove last user+assistant message pair |
| `/history` | Show input history |
| `/pin [N]` | Pin a message (last assistant or by index) |
| `/pins` | Show all pinned messages |
| `/rename <name>` | Rename current session (moves saved file) |
| `/context` | Show active session state summary |
| `/alias [name] [cmd]` | Create or list command aliases |
| `/snippet <action>` | Save/load/list/delete code snippets |
| `/debug` | Toggle debug mode |
| `/uptime` | Show session elapsed time |
| `/bookmark` | Export pinned messages to file |
| `/time` | Show current date and time |
| `/autosave [N\|off]` | Toggle periodic auto-save with interval |
| `/react <emoji>` | Add emoji reaction to a message |
| `/macro <action>` | Record/stop/play/list/delete command macros |
| `/tag <label>` | Tag a message with a label |
| `/tags [label]` | Show tag statistics or filter by tag |
| `/repeat` | Re-execute the last slash command |
| `/count <pattern>` | Count messages matching a pattern |
| `/template [name]` | List or use prompt templates |
| `/fav [N]` | Favorite a message (persists to disk) |
| `/favs` | Show all favorited messages |
| `/log [N]` | View last N lines of boot log |
| `/version` | Show version and platform info |
| `/focus` | Toggle minimal UI (hide status bar) |
| `/retry` | Resend last message to LLM |
| `/merge <session>` | Merge another session into current |
| `/sort [length\|role]` | Show messages sorted by length or role |
| `/import <path>` | Import session from a JSON file |
| `/mute` | Toggle system message display |
| `/wc` | Show word count statistics |

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
    Chat                 # AI chat REPL with streaming + 60 slash commands
      SessionCommands    # save/load/sessions/delete/rename
      ExportCommands     # export/bookmark/html/json/markdown
      MessageCommands    # compact/copy/diff/search/grep/undo/pin/pins
      UiCommands         # help/clear/dashboard/hotkeys/palette/context/stats/debug/history/uptime/time
      ModelCommands      # model/system/personality switching
      CustomCommands     # alias/snippet management
    Dashboard            # Service/LLM status, panel navigation (j/k/1-5)
    Extensions           # LEX gem browser by category with homepage opener
    Config               # Settings file viewer/editor with JSON validation

  Components/
    DigitalRain          # Matrix-style falling characters
    InputBar             # Prompt line with tab completion + input history
    MessageStream        # Scrollable message history with markdown + timestamps
    StatusBar            # Model, plan, debug, notifications, thinking, tokens, cost, session, scroll
    ToolPanel            # Expandable tool use panels
    MarkdownView         # TTY::Markdown rendering
    WizardPrompt         # TTY::Prompt wrappers
    TokenTracker         # Per-model token counting and cost estimation
    CommandPalette       # Fuzzy-search command/screen/session overlay
    ModelPicker          # LLM provider/model selection
    SessionPicker        # Session list and selection
    TableView            # TTY::Table wrapper
    ProgressPanel        # TTY::ProgressBar wrapper
    Notification         # Transient notifications with TTL and levels

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
Snippets are stored in `~/.legionio/snippets/`.
Exports go to `~/.legionio/exports/`.
Boot logs go to `~/.legionio/logs/tty-boot.log`.

## Development

```bash
bundle install
bundle exec rspec       # 1143 examples, 0 failures
bundle exec rubocop     # 106 files, 0 offenses
```

## License

Apache-2.0
