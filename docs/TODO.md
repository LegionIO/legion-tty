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

## Pending

### Integration Points
- [ ] Memory file writing -- write identity data to legion memory store for richer chat context
- [ ] Wire token tracking into LLM response callbacks (track_response_tokens exists, needs real LLM)
- [ ] MCP tool use display in chat (tool_panel rendering exists, needs MCP integration)

### Homebrew
- [ ] Evaluate adding tty gems as brew formula dependencies
- [ ] Currently installed via bundler, may not need brew-level deps

### Kerberos Ticket Expiry
- [ ] Ties into `legion-rbac`, not `legion-tty`
- [ ] On ticket expiry, RBAC should handle re-auth or session downgrade
- [ ] legion-tty just reads current ticket state at boot

### Future
- [ ] Screen manager navigation hotkeys (push/pop screens beyond dashboard)
- [ ] TLS/Zscaler -- should work as-is with system cert store, monitor for issues
- [ ] Plugin system for custom slash commands
- [ ] Configurable theme selection
- [ ] Tab completion for slash commands
- [ ] Multi-model chat (switch providers mid-conversation)
- [ ] Notification integration (background alerts from lex-mesh, lex-health)
