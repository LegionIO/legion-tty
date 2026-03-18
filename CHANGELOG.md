# Changelog

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
