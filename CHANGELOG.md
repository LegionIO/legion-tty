# Changelog

## [0.4.25] - 2026-03-19

### Added
- `/ask <question>` command: quick concise Q&A mode (instructs LLM to answer in one paragraph)
- `/define <term>` command: ask LLM for a concise definition
- `/status` command: comprehensive view of all 18 toggleable modes and settings
- `/prefs [key] [value]` command: persistent user preferences in `~/.legionio/prefs.json`
- `/about` command: show legion-tty name, version, author, license, GitHub URL
- `/commands [pattern]` command: list all slash commands with optional pattern filter and count

### Changed
- Total slash commands: 103 (milestone)

## [0.4.24] - 2026-03-19

### Added
- `/mark <label>` command: insert named markers/bookmarks in conversation, list all markers
- `/freq` command: word frequency analysis with top 20 words (excludes stop words)
- `/draft <text>` command: save text to draft buffer, show/clear/send draft
- `/revise <text>` command: replace content of last user message
- `/color [on|off]` command: toggle colorized output (strip ANSI codes when off)
- `/timestamps [on|off]` command: toggle timestamp display on messages
- `/top` command: scroll to top of message history
- `/bottom` command: scroll to bottom of message history
- `/head [N]` command: peek at first N messages (default 5)
- `/tail [N]` command: peek at last N messages (default 5)

## [0.4.23] - 2026-03-19

### Added
- `/wrap [N|off]` command: set custom word wrap width for message display
- `/number [on|off]` command: toggle message numbering with `[N]` prefix
- `/echo <text>` command: add user-defined system messages (notes/markers)
- `/env` command: show environment info (Ruby version, platform, terminal, PID, Legion gems)
- `/speak [on|off]` command: toggle text-to-speech for assistant messages (macOS only, via `say`)
- `/silent` command: toggle silent mode (responses tracked but not displayed), `[SILENT]` indicator
- `/ls [path]` command: list directory contents with directory markers
- `/pwd` command: show current working directory

## [0.4.22] - 2026-03-19

### Added
- `/truncate [N|off]` command: display-only truncation of long messages (preserves originals)
- `/archive [name]` command: archive session to `~/.legionio/archives/` with timestamp and start fresh
- `/archives` command: list all archived sessions with file sizes
- `/tee <path>` command: copy new messages to file in real-time (like Unix tee)
- `/pipe <command>` command: pipe last assistant response through a shell command
- `/calc <expression>` command: safe math expression evaluator with Math functions
- `/rand [N|min..max]` command: generate random numbers (float, integer, or range)

## [0.4.21] - 2026-03-19

### Added
- `/annotate [N] <text>` command: add notes/annotations to specific messages with timestamps
- `/annotations` command: list all annotated messages with their notes
- `/filter [role|tag|pinned|clear]` command: filter displayed messages by role, tag, or pinned status
- `/multiline` command: toggle multi-line input mode (submit with empty line)
- `/export yaml` format: export chat history as YAML alongside existing md/json/html formats
- Annotation rendering in message stream (displayed after reactions)
- `[ML]` status bar indicator for multi-line input mode

## [0.4.20] - 2026-03-19

### Added
- `/prompt save|load|list|delete` command: persist and reuse custom system prompts
- `/reset` command: reset session to clean state (clears messages, modes, aliases, macros)
- `/replace old >>> new` command: find and replace text across all messages
- `/highlight` command: highlight text patterns in message rendering with ANSI color

## [0.4.19] - 2026-03-19

### Added
- `/chain` command: send a sequence of pipe-separated prompts to the LLM sequentially
- `/info` command: comprehensive session info (modes, counts, aliases, snippets, macros, provider)
- `/scroll [top|bottom|N]` command: navigate to specific scroll position in message stream
- `/summary` command: generate a local conversation summary (topics, lengths, duration)

## [0.4.18] - 2026-03-19

### Added
- `/focus` command: toggle minimal UI mode (hides status bar for distraction-free writing)
- `/retry` command: resend last user message to LLM, replacing previous assistant response
- `/merge <session>` command: import messages from another saved session into current conversation
- `/sort [length|role]` command: display messages sorted by character length or grouped by role

## [0.4.17] - 2026-03-19

### Added
- `/template` command: 8 predefined prompt templates (explain, review, summarize, refactor, test, debug, translate, compare)
- `/fav` and `/favs` commands: persistent favorites saved to `~/.legionio/favorites.json`
- `/log [N]` command: view last N lines of boot log (default 20)
- `/version` command: show legion-tty version, Ruby version, and platform

## [0.4.16] - 2026-03-19

### Added
- Extensions screen category filter: 'f' cycles through Core/AI/Service/Agentic/Other, 'c' clears
- Config screen backup: 'b' creates .bak copy, auto-backup before edits
- `/repeat` command: re-execute the last slash command
- `/count <pattern>` command: count messages matching a pattern with per-role breakdown

## [0.4.15] - 2026-03-19

### Added
- `/autosave [N|off]` command: toggle periodic auto-save with configurable interval (default 60s)
- `/react <emoji>` command: add emoji reactions to messages (displayed in render)
- `/macro record|stop|play|list|delete` command: record and replay slash command sequences
- `/tag` and `/tags` commands: tag messages with labels, filter by tag, show tag statistics

## [0.4.14] - 2026-03-19

### Added
- LLM response timing: tracks elapsed time per response, shows notification, includes avg in `/stats`
- `/wc` command: word count statistics per role (user/assistant/system) with averages
- `/import <path>` command: import session from any JSON file path with validation
- `/mute` command: toggle system message display in chat (messages still tracked, just hidden)

## [0.4.13] - 2026-03-19

### Added
- Help overlay: `/help` now renders as a categorized overlay (SESSION/CHAT/LLM/NAV/DISPLAY/TOOLS) via screen manager
- Session message count in status bar ("N msgs" segment)
- `/welcome` command: redisplay the welcome message
- `/tips` command: show random usage tips (15 tips covering commands, hotkeys, features)

## [0.4.12] - 2026-03-19

### Added
- `/grep <pattern>` command: regex search across message history (case-insensitive, with RegexpError handling)
- `/time` command: display current date, time, and timezone

### Changed
- Refactored Chat screen into 6 concern modules (chat.rb 1220 -> 466 lines):
  - `chat/session_commands.rb` — save/load/sessions/delete/rename
  - `chat/export_commands.rb` — export/bookmark/html/json/markdown
  - `chat/message_commands.rb` — compact/copy/diff/search/grep/undo/pin/pins
  - `chat/ui_commands.rb` — help/clear/dashboard/hotkeys/palette/context/stats/debug/history/uptime/time
  - `chat/model_commands.rb` — model/system/personality switching
  - `chat/custom_commands.rb` — alias/snippet management

## [0.4.11] - 2026-03-19

### Added
- Dashboard LLM status panel: shows provider, model, started/daemon status with green/red icons
- Dashboard panel navigation: j/k/arrows to move between panels, 1-5 to jump, 'e' to open extensions
- `/uptime` command: show current chat session elapsed time
- `/bookmark` command: export all pinned messages to markdown file

## [0.4.10] - 2026-03-19

### Added
- `/context` command: display active session state summary (model, personality, plan mode, system prompt, session, message count, pinned count, token usage)
- `/alias` command: create short aliases for frequently used slash commands; aliases expand and re-dispatch transparently
- `/snippet save|load|list|delete <name>` command: save last assistant message as a named snippet, insert snippets as user messages, persist to `~/.legionio/snippets/`
- `/debug` command: toggle debug mode; adds `[DEBUG]` line to render output showing msgs/scroll/plan/personality/aliases/snippets/pinned counts; StatusBar shows `[DBG]` indicator

## [0.4.9] - 2026-03-19

### Added
- StatusBar notifications: transient toast-style messages with TTL expiry (wired to save/load/export/theme)
- `/undo` command: remove last user+assistant message pair
- `/history` command: show last 20 input entries
- `/pin` and `/pins` commands: pin important messages, view pinned list
- `/rename <name>` command: rename current session (deletes old, saves new)

## [0.4.8] - 2026-03-19

### Added
- `/export html` format: dark-theme HTML export with XSS-safe content escaping
- Extension homepage opener: press 'o' in extensions browser to open gem homepage in browser
- Config JSON validation: validates data before saving to prevent corrupt config files

## [0.4.7] - 2026-03-19

### Added
- Smart session auto-naming: generates slug from first user message instead of "default"
- Message timestamps: each message records creation time, displayed in user message headers
- Scroll position indicator in status bar (shows current/total when content is scrollable)

## [0.4.6] - 2026-03-19

### Added
- `/stats` command: show conversation statistics (message counts, characters, token summary)
- `/personality <style>` command: switch between default/concise/detailed/friendly/technical personas
- Notification component: transient message display with TTL expiry and level-based icons/colors

## [0.4.5] - 2026-03-19

### Added
- `/compact [N]` command: remove older messages, keep last N pairs (default 5)
- `/copy` command: copy last assistant response to clipboard (macOS pbcopy, Linux xclip)
- `/diff` command: show new messages since last session load
- Session load tracking: `@loaded_message_count` for diff comparison

## [0.4.4] - 2026-03-19

### Added
- Animated spinner in status bar thinking indicator (cycles through frames on each render)
- `/search <text>` command: case-insensitive search across chat message history
- `/theme <name>` command: switch between purple, green, blue, amber themes at runtime
- Chat input history: up/down arrow navigation through previous inputs (via TTY::Reader history_cycle)

## [0.4.3] - 2026-03-19

### Added
- Daemon-first chat routing: chat screen routes through LegionIO daemon when available
- `send_via_daemon` and `send_via_direct` methods with automatic fallback
- `daemon_available?` guard for `Legion::LLM::DaemonClient` presence

## [0.4.2] - 2026-03-19

### Added
- Multi-provider model switching: `/model <provider>` creates new Legion::LLM.chat instance
- Model picker integration: `open_model_picker` for interactive provider/model selection
- ToolPanel wiring in MessageStream: `add_tool_call`, `update_tool_call` methods
- Tool call rendering in chat messages (`:tool` role with panel display)

### Fixed
- Flaky table_view_spec: added explicit `require 'tty-table'` to prevent test ordering failures

## [0.4.1] - 2026-03-19

### Added
- Progress panel component wrapping tty-progressbar for long operations
- Tab completion for slash commands (type `/` + Tab to cycle through matches)
- InputBar now accepts `completions:` parameter for configurable auto-complete

### Changed
- README.md updated to reflect 0.4.x features, hotkeys, architecture
- CLAUDE.md updated to reflect current version, components, LLM integration notes

## [0.4.0] - 2026-03-19

### Fixed
- /model crash: empty or invalid model name no longer crashes the shell
- Removed all RubyLLM direct usage -- all LLM access goes through Legion::LLM exclusively
- Kerberos username key mismatch in vault auth pre-fill (was :samaccountname, now :username)
- Overlay rendering: help overlay now actually displays on screen
- Thinking indicator: status bar shows "thinking..." during LLM requests
- --skip-rain CLI option now forwarded to onboarding

### Added
- Per-model token pricing (Opus/Sonnet/Haiku, GPT-4o/4o-mini, Gemini Flash/Pro)
- Markdown rendering for assistant messages via TTY::Markdown
- /system command: set or override system prompt at runtime
- /delete command: delete saved sessions
- /plan command: toggle read-only bookmark mode with [PLAN] status indicator
- /palette command: fuzzy-search command palette for all commands, screens, sessions
- /extensions command: browse installed LEX gems by category
- /config command: view and edit ~/.legionio/settings/*.json files
- Command palette component with fuzzy search
- Model picker component for switching LLM providers
- Session picker component for quick session switching
- Table view component wrapping tty-table
- Extensions browser screen (grouped by core/agentic/service/AI/other)
- Config viewer/editor screen with vault:// masking
- Hotkeys: Ctrl+K (palette), Ctrl+S (sessions), Escape (back)
- Plan mode: bookmark messages without sending to LLM

### Changed
- Token tracker now uses per-model rates with provider fallback
- Hotkey ? removed (conflicted with typing questions)
- Help text updated with all new commands and hotkey reference

### Removed
- RubyLLM direct fallback in app.rb (PROVIDER_MAP, try_credentials_llm, configure_llm_provider)

## [0.3.1] - 2026-03-19

### Fixed
- LLM boot order: follow Legion::Service init sequence (logging -> settings -> crypt -> resolve_secrets -> LLM merge -> start) instead of ad-hoc loading
- TTY shell now correctly discovers LLM providers configured in ~/.legionio/settings/llm.json

### Added
- `boot_legion_subsystems` method mirrors Service.rb initialization order
- `settings_search_path` helper matching Service default config search paths

## [0.2.9] - 2026-03-18

### Fixed
- Chat LLM not configured: setup_llm now reads from Legion::Settings llm.json first, falls back to legacy credentials.json

## [0.2.8] - 2026-03-18

### Added
- Extension detection in onboarding: background scan via lex-detect during digital rain
- "hooking into X..." typed output for each discovered service
- Offers to install missing extensions when uninstalled gems are detected
- Graceful skip when lex-detect gem is not installed
- 7 new specs for extension detection and gem availability (381 total)

## [0.2.7] - 2026-03-18

### Added
- AWS Bedrock provider option in wizard prompt
- Skip for now option in provider selection (both static and dynamic paths)

## [0.2.6] - 2026-03-18

### Fixed
- Remove local path references from Gemfile (legionio, legion-rbac, lex-kerberos)

## [0.2.5] - 2026-03-18

### Added
- Bootstrap config auto-import: detects `LEGIONIO_BOOTSTRAP_CONFIG` env var during onboarding
- Fetches config from local file or HTTP/HTTPS URL (raw JSON or base64-encoded)
- Splits top-level keys into individual settings files (`~/.legionio/settings/{key}.json`)
- Deep merges with existing config files if present
- Bootstrap summary line in reveal box showing imported sections
- 14 new specs (374 total)

## [0.2.4] - 2026-03-18

### Added
- Cache service awakening: detects running Redis/Memcached, offers to activate if missing
- GAIA daemon discovery: checks for running legionio daemon, offers to start it
- Cinematic typed prompts: "extending neural pathways", "GAIA is awake", "cognitive threads synchronized"
- Cache and GAIA status lines in reveal summary box
- 46 new specs (360 total)

## [0.2.3] - 2026-03-18

### Added
- Vault LDAP auth step in onboarding: prompts to connect to configured vault clusters
- Default username from Kerberos samaccountname or `$USER`, hidden password input
- `WizardPrompt#ask_secret` (masked) and `#ask_with_default` methods
- Vault cluster connection status in reveal summary box
- 26 new specs for vault auth and wizard prompt methods

## [0.2.2] - 2026-03-18

### Added
- Dotfile scanning: gitconfig (name, email, signing key), JFrog CLI servers, Terraform credential hosts
- `Scanner#scan_dotfiles`, `#scan_gitconfig`, `#scan_jfrog`, `#scan_terraform` methods
- Onboarding reveal box now displays discovered dotfile configuration
- Specs for all dotfile scanning and summary display methods

## [0.2.1] - 2026-03-18

### Changed
- Onboarding replaces credential prompts with LLM provider auto-detection and ping-testing
- Shows green checkmark or red X with latency for each configured provider
- Auto-selects default provider or lets user choose if multiple are available

### Added
- `Background::LlmProbe` for async provider ping-testing during onboarding
- `WizardPrompt#display_provider_results` and `#select_default_provider` methods
- Bootsnap and YJIT startup optimizations in `exe/legion-tty`

## [0.2.0] - 2026-03-18

### Added
- Token tracker with per-provider pricing (claude, openai, gemini, azure, local)
- Session persistence (save/load/list/delete) via JSON in ~/.legionio/sessions/
- Operational dashboard screen with service status, extensions, system info, recent activity
- Hotkey system with register/handle pattern and Ctrl+D dashboard toggle
- Slash commands: /cost, /export, /tools, /model, /session, /dashboard, /hotkeys, /save, /load, /sessions
- LegionIO CLI integration via `legion tty` subcommand (autoloaded)
- Background environment rescan on second-run
- LLM setup with Legion::LLM and ruby_llm fallback
- Export to markdown and JSON formats
- README with feature comparison table (vs Claude Code, Codex CLI)
- 306 specs covering all components, screens, background probes, and integration

### Changed
- Chat screen now supports full slash command dispatch
- App orchestrator wires hotkeys, dashboard toggle, help overlay, and environment rescan

## [0.1.0] - 2026-03-17

### Added
- Initial gem scaffold
- Onboarding wizard with digital rain, identity detection, API key collection
- Chat screen with streaming LLM responses and message history
- Theme system with 17-shade purple palette and semantic colors
- Screen manager with push/pop stack pattern
- Components: DigitalRain, InputBar, MessageStream, StatusBar, ToolPanel, MarkdownView, WizardPrompt
- Background probes: Scanner (services, repos, configs), GitHubProbe, KerberosProbe
- Boot logger for startup diagnostics
