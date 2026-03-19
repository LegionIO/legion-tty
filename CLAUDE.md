# legion-tty

**Parent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## What is this?

Rich terminal UI for the LegionIO async cognition engine. Provides onboarding wizard with identity detection, AI chat shell with streaming and 19 slash commands, operational dashboard, extensions browser, config editor, command palette, model/session pickers, and session persistence using the tty-ruby gem ecosystem.

**GitHub**: https://github.com/LegionIO/legion-tty
**Gem**: `legion-tty`
**Version**: 0.4.1
**License**: Apache-2.0
**Ruby**: >= 3.4

## Architecture

```
lib/legion/tty/
  app.rb                  # Orchestrator: config, LLM (Legion::LLM only), screens, hotkeys
  screen_manager.rb       # Push/pop screen stack, overlay, render queue
  hotkeys.rb              # Key binding registry (Ctrl+D, Ctrl+K, Ctrl+S, Ctrl+L, Escape)
  session_store.rb        # JSON session persistence (~/.legionio/sessions/)
  boot_logger.rb          # Boot sequence logging
  theme.rb                # Purple palette (17 shades) + semantic colors
  version.rb

  screens/
    base.rb               # Abstract: activate, deactivate, render, handle_input, teardown
    onboarding.rb         # First-run: rain -> intro -> wizard -> reveal
    chat.rb               # AI REPL: 19 slash commands, streaming, token tracking, plan mode
    dashboard.rb          # Service status, extensions, system info panels
    extensions.rb         # LEX gem browser: core/agentic/service/AI/other categories, detail view
    config.rb             # Settings viewer/editor: ~/.legionio/settings/*.json, vault:// masking

  components/
    digital_rain.rb       # Matrix-style falling LEX names
    input_bar.rb          # Prompt with tab completion for slash commands + thinking indicator
    message_stream.rb     # Scrollable message history with markdown rendering
    status_bar.rb         # Model | [PLAN] | thinking... | tokens | cost | session
    tool_panel.rb         # Expandable tool use display
    markdown_view.rb      # TTY::Markdown wrapper
    wizard_prompt.rb      # TTY::Prompt wrapper
    token_tracker.rb      # Per-model (9 models) + per-provider (8 providers) cost estimation
    command_palette.rb    # Fuzzy-search overlay for commands, screens, sessions
    model_picker.rb       # LLM provider/model selection via TTY::Prompt
    session_picker.rb     # Session list and selection via TTY::Prompt
    table_view.rb         # TTY::Table wrapper for tabular data
    progress_panel.rb     # TTY::ProgressBar wrapper for long operations

  background/
    scanner.rb            # Port probing, git repos, shell history, config detection
    github_probe.rb       # GitHub API: profile, repos, PRs, notifications, events
    kerberos_probe.rb     # klist + DNS SRV + LDAP profile resolution
```

## LLM Integration

- **Legion::LLM exclusively** -- no direct RubyLLM calls anywhere
- Boot: logging -> settings -> crypt -> resolve_secrets -> LLM merge -> start (mirrors Legion::Service)
- `try_settings_llm` is the single LLM path: `Legion::LLM.chat(provider:)`
- If Legion::LLM unavailable, `@llm_chat = nil` -- chat works without LLM (commands still function)
- `/model` switches model with rescue on `StandardError` to prevent crashes

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

## Slash Commands

```
/help /quit /clear /model /session /cost /export /tools /dashboard /hotkeys
/save /load /sessions /system /delete /plan /palette /extensions /config
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
bundle exec rspec       # 598 examples, 0 failures
bundle exec rubocop     # 68 files, 0 offenses
```

## Pre-Push Pipeline

Same as all Legion gems -- see parent CLAUDE.md.

---

**Last Updated**: 2026-03-19
**Maintained By**: Matthew Iverson (@Esity)
