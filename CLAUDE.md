# legion-tty

**Parent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## What is this?

Rich terminal UI for the LegionIO async cognition engine. Provides onboarding wizard with identity detection, AI chat shell with streaming and 115 slash commands, operational dashboard with panel navigation, extensions browser with category filter, config editor with backup, command palette, model/session pickers, theme selection, personality styles, snippets, aliases, macros, templates, favorites, debug mode, focus mode, session archiving, draft buffer, word frequency analysis, persistent preferences, message decorators, countdown timers, and session persistence using the tty-ruby gem ecosystem.

**GitHub**: https://github.com/LegionIO/legion-tty
**Gem**: `legion-tty`
**Version**: 0.4.28
**License**: Apache-2.0
**Ruby**: >= 3.4

## Architecture

```
lib/legion/tty/
  app.rb                  # Orchestrator: config, LLM (Legion::LLM only), screens, hotkeys
  screen_manager.rb       # Push/pop screen stack, overlay, render queue
  hotkeys.rb              # Key binding registry (Ctrl+D, Ctrl+K, Ctrl+S, Ctrl+L, Escape)
  session_store.rb        # JSON session persistence (~/.legionio/sessions/)
  daemon_client.rb        # HTTP client for LegionIO daemon REST API (routes tasks, gets status)
  boot_logger.rb          # Boot sequence logging
  theme.rb                # 4 themes (purple/green/blue/amber) with 17-shade palettes + semantic colors
  version.rb

  screens/
    base.rb               # Abstract: activate, deactivate, render, handle_input, teardown
    onboarding.rb         # First-run: rain -> intro -> wizard -> reveal
    chat.rb               # AI REPL: 115 slash commands, streaming, token tracking, plan/focus mode, personalities
    chat/                 # Command handler concern modules (extracted from chat.rb):
      session_commands.rb #   save/load/sessions/delete/rename/import/merge/autosave
      export_commands.rb  #   export/bookmark/html/json/markdown/yaml
      message_commands.rb #   compact/copy/diff/search/grep/undo/pin/pins/react/tag/fav/sort/count/transform/concat/split/swap
      ui_commands.rb      #   help/clear/dashboard/hotkeys/palette/context/stats/debug/history/uptime/time/tips/welcome/focus/wc/log/version/mute/calc/rand/mark/freq/color/timestamps/top/bottom/head/tail/echo/env/speak/silent/wrap/number/truncate/about/commands/ask/define/status/prefs/timer/notify
      model_commands.rb   #   model/system/personality switching/retry/chain/info/scroll/summary/prompt/reset/replace/highlight/multiline/filter/annotate/annotations
      custom_commands.rb  #   alias/snippet/template/macro/draft/revise/tee/pipe/archive/archives/ls/pwd/prefix/suffix
    dashboard.rb          # Service/LLM status, extensions, system info, panel navigation (j/k/1-5)
    extensions.rb         # LEX gem browser: category filter (f/c keys), detail view, 'o' opens homepage (lazy-loaded)
    config.rb             # Settings viewer/editor: ~/.legionio/settings/*.json, vault:// masking, JSON validation, 'b' backup (lazy-loaded)

  components/
    digital_rain.rb       # Matrix-style falling LEX names
    input_bar.rb          # Prompt with tab completion for slash commands + input history
    message_stream.rb     # Scrollable message history with markdown rendering + timestamps
    status_bar.rb         # Model | [PLAN] | [DBG] | notifications | thinking... | tokens | cost | session | scroll
    tool_panel.rb         # Expandable tool use display
    markdown_view.rb      # TTY::Markdown wrapper
    wizard_prompt.rb      # TTY::Prompt wrapper
    token_tracker.rb      # Per-model (9 models) + per-provider (8 providers) cost estimation
    command_palette.rb    # Fuzzy-search overlay for commands, screens, sessions
    model_picker.rb       # LLM provider/model selection via TTY::Prompt
    session_picker.rb     # Session list and selection via TTY::Prompt
    table_view.rb         # TTY::Table wrapper for tabular data
    progress_panel.rb     # TTY::ProgressBar wrapper for long operations
    notification.rb       # Transient notifications with TTL expiry and level-based icons

  background/
    scanner.rb            # Port probing, git repos, shell history, config detection
    github_probe.rb       # GitHub API: profile, repos, PRs, notifications, events
    kerberos_probe.rb     # klist + DNS SRV + LDAP profile resolution
    bootstrap_config.rb   # LEGIONIO_BOOTSTRAP_CONFIG fetch + split into ~/.legionio/settings/{key}.json
    llm_probe.rb          # LLM provider availability probe (checks local Ollama, cloud keys)
```

## LLM Integration

- **Legion::LLM exclusively** -- no direct RubyLLM calls anywhere
- Boot: logging -> settings -> crypt -> resolve_secrets -> LLM merge -> start (mirrors Legion::Service)
- `try_settings_llm` is the single LLM path: `Legion::LLM.chat(provider:)`
- If Legion::LLM unavailable, `@llm_chat = nil` -- chat works without LLM (commands still function)
- `/model` switches model with rescue on `StandardError` to prevent crashes
- Daemon routing: routes through LegionIO daemon when available, falls back to direct

## LegionIO Integration

- `legion tty` subcommand in LegionIO CLI (`lib/legion/cli/tty_command.rb`)
- Autoloaded: `autoload :Tty, 'legion/cli/tty_command'`
- Falls back gracefully if legion-tty gem not installed

## Key Patterns

- `::Process` and `::JSON` must be explicit (namespace collision with Legion::Process, Legion::JSON)
- Background probes use Thread + Queue pattern for async work during onboarding
- TTY::Cursor, TTY::Screen, TTY::Box, TTY::Font, TTY::Markdown are `require`d at point of use
- All file paths use `File.expand_path('~/.legionio/...')` for consistency
- Screen navigation: push/pop stack with overlay support; Escape pops or dismisses overlay
- Chat commands extracted into concern modules included via `include SessionCommands`, etc.

## Slash Commands

```
/about /ago /alias /annotate /annotations /archive /archives /ask /autosave
/bookmark /bottom
/calc /chain /clear /color /commands /compact /concat /config /context /copy /cost /count
/dashboard /debug /define /delete /diff /draft
/echo /env /export /extensions
/fav /favs /filter /focus /freq
/goto /grep
/head /help /highlight /history /hotkeys
/import /info /inject
/load /log /ls
/macro /mark /merge /model /multiline /mute
/notify /number
/palette /personality /pin /pins /pipe /plan /prefix /prefs /prompt /pwd
/quit
/rand /react /rename /repeat /replace /reset /retry /revise
/save /scroll /search /session /sessions /silent /snippet /sort /speak /split /stats /status /stopwatch /suffix /summary /swap /system
/tag /tags /tail /tee /template /theme /time /timer /timestamps /tools /top /transform /truncate
/undo /uptime
/version
/wc /welcome /wrap
```

## Hotkeys

| Key | Action |
|-----|--------|
| Ctrl+D | Toggle dashboard |
| Ctrl+K | Open command palette |
| Ctrl+S | Open session picker |
| Ctrl+L | Refresh screen |
| Escape | Go back / dismiss overlay |
| Tab | Auto-complete slash commands |

## Development

```bash
bundle install
bundle exec rspec       # 1817 examples, 0 failures
bundle exec rubocop     # 150 files, 0 offenses
```

## Pre-Push Pipeline

Same as all Legion gems -- see parent CLAUDE.md.

---

**Last Updated**: 2026-03-19
**Maintained By**: Matthew Iverson (@Esity)
