# Changelog

## [0.2.10] - 2026-03-19

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
