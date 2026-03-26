# legion-tty

Rich terminal UI for the LegionIO async cognition engine.

**Version**: 0.4.35

Think Claude Code meets Codex CLI, but for LegionIO: onboarding wizard with identity detection, streaming AI chat shell with 115 slash commands, operational dashboard, extensions browser, config editor, and session persistence - all rendered with the [tty-ruby](https://ttytoolkit.org/) gem ecosystem.

## Features

- **Onboarding wizard** - First-run setup with Kerberos identity detection, GitHub profile probing, environment scanning, and LLM provider selection
- **Digital rain intro** - Matrix-style rain using discovered LEX extension names
- **AI chat shell** - Streaming LLM chat with 115 slash commands, tab completion, markdown rendering, and tool panels
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
- **Session chaining** - `/chain` sends pipe-separated prompts sequentially; `/info` shows full session state
- **Scroll navigation** - `/scroll`, `/top`, `/bottom`, `/head`, `/tail` for precise history navigation
- **Conversation editing** - `/replace`, `/reset`, `/prompt`, `/highlight` for post-hoc message editing
- **Multi-line input** - `/multiline` toggles submit-on-empty-line mode with `[ML]` status indicator
- **Message annotations** - `/annotate` and `/annotations` for inline notes on specific messages
- **Message filtering** - `/filter` by role, tag, or pinned status
- **Export YAML** - `/export yaml` alongside existing md/json/html formats
- **Session archiving** - `/archive` moves session to `~/.legionio/archives/` and starts fresh
- **Shell integration** - `/tee` mirrors messages to a file in real-time; `/pipe` pipes output through a shell command
- **Math utilities** - `/calc` for safe expression evaluation; `/rand` for random number generation
- **Shell-like commands** - `/ls`, `/pwd`, `/echo`, `/env` for quick filesystem and environment inspection
- **Display controls** - `/wrap`, `/number`, `/color`, `/timestamps`, `/truncate`, `/silent`, `/speak`
- **Draft buffer** - `/draft` and `/revise` for composing and editing messages before sending
- **Word frequency** - `/freq` shows top-20 words in conversation (excludes stop words)
- **Named markers** - `/mark` inserts named bookmarks; list all markers with `/mark`
- **Persistent preferences** - `/prefs` reads/writes `~/.legionio/prefs.json` across sessions
- **Quick Q&A** - `/ask` and `/define` for concise one-paragraph LLM answers
- **Status overview** - `/status` shows all 18 toggleable modes and settings at a glance
- **Command discovery** - `/commands [pattern]` lists all slash commands with optional pattern filter
- **About info** - `/about` shows gem name, version, author, license, and GitHub URL

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
| `/about` | Show gem name, version, author, license, and GitHub URL |
| `/alias [name] [cmd]` | Create or list command aliases |
| `/annotate [N] <text>` | Add a note to a specific message |
| `/annotations` | List all annotated messages with their notes |
| `/archive [name]` | Archive session to `~/.legionio/archives/` and start fresh |
| `/archives` | List all archived sessions with file sizes |
| `/ask <question>` | Quick concise Q&A mode (LLM answers in one paragraph) |
| `/autosave [N\|off]` | Toggle periodic auto-save with configurable interval |
| `/bookmark` | Export pinned messages to a markdown file |
| `/bottom` | Scroll to bottom of message history |
| `/calc <expression>` | Evaluate a math expression (supports Math functions) |
| `/chain <p1\|p2\|...>` | Send pipe-separated prompts to LLM sequentially |
| `/clear` | Clear message history |
| `/color [on\|off]` | Toggle colorized output (strips ANSI codes when off) |
| `/commands [pattern]` | List all slash commands with optional pattern filter |
| `/compact [N]` | Keep last N message pairs, remove older |
| `/config` | View and edit `~/.legionio/settings/*.json` files |
| `/context` | Show active session state summary |
| `/copy` | Copy last assistant response to clipboard |
| `/cost` | Show token usage and estimated cost |
| `/count <pattern>` | Count messages matching a pattern with per-role breakdown |
| `/dashboard` | Toggle operational dashboard |
| `/debug` | Toggle debug mode |
| `/define <term>` | Ask LLM for a concise definition |
| `/delete <session>` | Delete a saved session |
| `/diff` | Show new messages since last session load |
| `/draft [text\|send\|clear]` | Save text to draft buffer, show, send, or clear it |
| `/echo <text>` | Add a user-defined system message note |
| `/env` | Show environment info (Ruby version, platform, terminal, PID) |
| `/export [md\|json\|html\|yaml]` | Export chat history to file |
| `/extensions` | Browse installed LEX extensions |
| `/fav [N]` | Favorite a message (persists to `~/.legionio/favorites.json`) |
| `/favs` | Show all favorited messages |
| `/filter [role\|tag\|pinned\|clear]` | Filter displayed messages |
| `/focus` | Toggle minimal UI (hide status bar) |
| `/freq` | Word frequency analysis with top 20 words (excludes stop words) |
| `/grep <pattern>` | Regex search across messages |
| `/head [N]` | Peek at first N messages (default 5) |
| `/help` | Show all commands and hotkeys |
| `/highlight <pattern>` | Highlight text patterns in message rendering |
| `/history` | Show input history |
| `/hotkeys` | Show registered hotkey bindings |
| `/import <path>` | Import session from a JSON file |
| `/info` | Comprehensive session info (modes, counts, aliases, macros, provider) |
| `/load <name>` | Load a saved session |
| `/log [N]` | View last N lines of boot log (default 20) |
| `/ls [path]` | List directory contents |
| `/macro <action>` | Record/stop/play/list/delete command macros |
| `/mark <label>` | Insert a named marker/bookmark in conversation |
| `/merge <session>` | Merge another session into current |
| `/model <name>` | Switch LLM model at runtime |
| `/multiline` | Toggle multi-line input mode (submit with empty line) |
| `/mute` | Toggle system message display |
| `/number [on\|off]` | Toggle message numbering with `[N]` prefix |
| `/palette` | Open command palette (fuzzy search) |
| `/personality [style]` | Switch personality (default/concise/detailed/friendly/technical) |
| `/pin [N]` | Pin a message (last assistant or by index) |
| `/pins` | Show all pinned messages |
| `/pipe <command>` | Pipe last assistant response through a shell command |
| `/plan` | Toggle read-only bookmark mode |
| `/prefs [key] [value]` | Read or write persistent user preferences |
| `/prompt save\|load\|list\|delete` | Persist and reuse custom system prompts |
| `/pwd` | Show current working directory |
| `/quit` | Exit (auto-saves session) |
| `/rand [N\|min..max]` | Generate random numbers (float, integer, or range) |
| `/react <emoji>` | Add emoji reaction to a message |
| `/rename <name>` | Rename current session (moves saved file) |
| `/repeat` | Re-execute the last slash command |
| `/replace old >>> new` | Find and replace text across all messages |
| `/reset` | Reset session to clean state |
| `/retry` | Resend last user message to LLM |
| `/revise <text>` | Replace the content of the last user message |
| `/save [name]` | Save current session |
| `/scroll [top\|bottom\|N]` | Navigate to a specific scroll position |
| `/search <text>` | Search message history |
| `/session <name>` | Set session name |
| `/sessions` | List all saved sessions |
| `/silent` | Toggle silent mode (responses tracked but not displayed) |
| `/snippet <action>` | Save/load/list/delete code snippets |
| `/sort [length\|role]` | Show messages sorted by length or grouped by role |
| `/speak [on\|off]` | Toggle text-to-speech for assistant messages (macOS only) |
| `/stats` | Show conversation statistics |
| `/status` | Show all 18 toggleable modes and settings |
| `/summary` | Generate a local conversation summary |
| `/system <prompt>` | Set or override system prompt |
| `/tag <label>` | Tag a message with a label |
| `/tags [label]` | Show tag statistics or filter by tag |
| `/tail [N]` | Peek at last N messages (default 5) |
| `/tee <path>` | Copy new messages to a file in real-time |
| `/template [name]` | List or use prompt templates (8 built-in) |
| `/theme [name]` | Switch color theme (purple/green/blue/amber) |
| `/time` | Show current date and time |
| `/timestamps [on\|off]` | Toggle timestamp display on messages |
| `/tools` | List discovered LEX extensions |
| `/top` | Scroll to top of message history |
| `/truncate [N\|off]` | Display-only truncation of long messages |
| `/undo` | Remove last user+assistant message pair |
| `/uptime` | Show session elapsed time |
| `/version` | Show version and platform info |
| `/wc` | Show word count statistics per role |
| `/welcome` | Redisplay the welcome message |
| `/wrap [N\|off]` | Set custom word wrap width |
| `/ago <N>` | Show what was said N messages ago |
| `/concat` | Concatenate all assistant messages into one |
| `/goto <N>` | Jump to specific message by index |
| `/inject <role> <text>` | Inject a message with specific role |
| `/notify <message>` | Send a toast notification to status bar |
| `/prefix [text\|clear]` | Set/show/clear auto-prefix for outgoing messages |
| `/split <N> [pattern]` | Split a message by pattern into multiple messages |
| `/stopwatch [start\|stop\|lap\|reset]` | Built-in stopwatch with MM:SS.ms format |
| `/suffix [text\|clear]` | Set/show/clear auto-suffix for outgoing messages |
| `/swap <A> <B>` | Swap two messages by index |
| `/timer <seconds> [message]` | Countdown timer with notification on expiry |
| `/transform <op>` | Apply string transformation to last assistant message |

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
    Chat                 # AI chat REPL with streaming + 115 slash commands
      SessionCommands    # save/load/sessions/delete/rename/import/merge/autosave
      ExportCommands     # export/bookmark/html/json/markdown/yaml
      MessageCommands    # compact/copy/diff/search/grep/undo/pin/pins/react/tag/fav/sort/count/transform/concat/split/swap
      UiCommands         # help/clear/dashboard/hotkeys/palette/context/stats/debug/history/uptime/time/tips/welcome/focus/wc/log/version/mute + calc/rand/mark/freq/color/timestamps/top/bottom/head/tail/echo/env/speak/silent/wrap/number/truncate/about/commands/ask/define/status/prefs/timer/notify
      ModelCommands      # model/system/personality switching/retry/chain/info/scroll/summary/prompt/reset/replace/highlight/multiline/filter/annotate/annotations
      CustomCommands     # alias/snippet/template/macro/draft/revise/tee/pipe/archive/archives/ls/pwd/prefix/suffix
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
bundle exec rspec       # 1817 examples, 0 failures
bundle exec rubocop     # 150 files, 0 offenses
```

## License

Apache-2.0
