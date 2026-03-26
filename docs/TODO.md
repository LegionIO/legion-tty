# legion-tty TODO

## Completed

### v0.1.0
- [x] Onboarding wizard (name, provider, API key)
- [x] Digital rain + LEGION splash
- [x] Kerberos probe (klist, DNS SRV, LDAP profile with title/dept/company/location/tenure)
- [x] GitHub probe (token resolution chain, authenticated + public paths, quick probe during rain)
- [x] Background scanner integration with boot logger
- [x] Boot logger (`~/.legionio/logs/tty-boot.log`)
- [x] Identity persistence (`~/.legionio/settings/identity.json` with kerberos/github/scan data)
- [x] Credentials persistence (`~/.legionio/settings/credentials.json`, chmod 600)
- [x] LLM wiring (Legion::LLM first, RubyLLM fallback, streaming chat)
- [x] System prompt built from identity (kerberos, github, environment)
- [x] Chat screen with slash commands (/help /quit /clear /model /session)

### v0.2.0
- [x] Token tracker with per-provider pricing (claude, openai, gemini, azure, local)
- [x] Session persistence (save/load/list/delete via JSON)
- [x] Operational dashboard (service status, extensions, system info, activity)
- [x] Hotkey system (register/handle, Ctrl+D toggle dashboard, Ctrl+L refresh, ? help)
- [x] Slash commands: /cost, /export, /tools, /model switch, /dashboard, /hotkeys, /save, /load, /sessions
- [x] LegionIO CLI integration (`legion tty` subcommand, autoloaded)
- [x] Background environment rescan on second-run
- [x] Export to markdown and JSON
- [x] 306 specs (all components, screens, background probes, integration)
- [x] Rubocop clean (50 files, 0 offenses)
- [x] README with feature comparison (vs Claude Code, Codex CLI)
- [x] CLAUDE.md with architecture tree and key patterns

### v0.3.0 - v0.4.35
- [x] 115 slash commands (from 5 in v0.1.0)
- [x] Configurable theme selection (4 themes: purple/green/blue/amber with 17-shade palettes)
- [x] Tab completion for slash commands
- [x] Multi-model chat (`/model` slash command for mid-chat model switching)
- [x] Notification integration (notification component with TTL expiry and level-based icons)
- [x] Screen manager navigation hotkeys (push/pop stack with overlay support, Escape pops)
- [x] Command palette (Ctrl+K fuzzy-search overlay for commands, screens, sessions)
- [x] Model picker and session picker components
- [x] Extensions browser with category filter
- [x] Config editor with backup and vault:// masking
- [x] Progress bars, tables, spinners components
- [x] Daemon client for LegionIO REST API integration
- [x] Message decorators, countdown timers, session persistence
- [x] Draft buffer, word frequency analysis, persistent preferences
- [x] Homebrew formula: `legion-tty` in homebrew-tap (3-formula split)
- [x] 1817 specs, 150 files rubocop clean

### v0.4.36 - Rendering Engine Rebuild
- [x] Raw-mode event loop replacing synchronous readline blocking
- [x] App#run_loop with IO.select + $stdin.raw + manual escape sequence parsing
- [x] Key normalization (KEY_MAP mapping raw escape sequences to symbols)
- [x] Differential rendering (write_differential, line-by-line frame buffer comparison)
- [x] Overlay compositing (TTY::Box.frame centered, persists until Escape)
- [x] InputBar rewritten with handle_key line buffer (character-by-character, non-blocking)
- [x] Chat screen conforms to render/handle_input/handle_line contract
- [x] Streaming flag enables 50ms refresh during LLM output
- [x] Hotkeys use normalized symbol keys (:ctrl_d, :ctrl_l, :ctrl_k, :ctrl_s)
- [x] Dashboard, Extensions, Config screens driven by App event loop
- [x] with_cooked_mode for blocking TTY::Prompt calls (model picker, command palette)
- [x] 1841 specs, 156 files rubocop clean
- [x] Design: docs/plans/2026-03-26-legion-tty-rendering-engine-design.md

### v0.4.37 - Token Tracking Wiring
- [x] Fix track_response_tokens to use `model_id` from RubyLLM::Message (was checking non-existent `model`)
- [x] Initialize TokenTracker with actual model from LLM chat session at startup
- [x] Add track_daemon_tokens for daemon path (reads meta[:tokens_in]/meta[:tokens_out])
- [x] Extract update_status_bar_tokens helper
- [x] 1850 specs, 156 files rubocop clean

## Pending

### Integration Points
- [ ] Memory file writing -- write identity data to legion memory store for richer chat context
- [ ] MCP tool use display in chat (tool_panel rendering exists, needs MCP integration)

### Kerberos Ticket Expiry
- [ ] Ties into `legion-rbac`, not `legion-tty`
- [ ] On ticket expiry, RBAC should handle re-auth or session downgrade
- [ ] legion-tty just reads current ticket state at boot

### Future
- [ ] TLS/Zscaler -- should work as-is with system cert store, monitor for issues
- [ ] Plugin system for custom slash commands
