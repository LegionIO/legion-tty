# legion-tty

**Parent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## What is this?

Rich terminal UI for the LegionIO async cognition engine. Provides onboarding wizard with identity detection, AI chat shell with streaming and slash commands, operational dashboard, and session persistence using the tty-ruby gem ecosystem.

**GitHub**: https://github.com/LegionIO/legion-tty
**Gem**: `legion-tty`
**Version**: 0.2.9
**License**: Apache-2.0
**Ruby**: >= 3.4

## Architecture

```
lib/legion/tty/
  app.rb                  # Orchestrator: config, LLM, screens, hotkeys
  screen_manager.rb       # Push/pop screen stack, overlay, render queue
  hotkeys.rb              # Key binding registry
  session_store.rb        # JSON session persistence (~/.legionio/sessions/)
  boot_logger.rb          # Boot sequence logging
  theme.rb                # Purple palette (17 shades) + semantic colors
  version.rb

  screens/
    base.rb               # Abstract: activate, deactivate, render, handle_input, teardown
    onboarding.rb         # First-run: rain -> intro -> wizard -> reveal
    chat.rb               # AI REPL: slash commands, streaming, token tracking
    dashboard.rb          # Service status, extensions, system info panels

  components/
    digital_rain.rb       # Matrix-style falling LEX names
    input_bar.rb          # Prompt with thinking indicator
    message_stream.rb     # Scrollable message history with tool panels
    status_bar.rb         # Model | tokens | cost | session
    tool_panel.rb         # Expandable tool use display
    markdown_view.rb      # TTY::Markdown wrapper
    wizard_prompt.rb      # TTY::Prompt wrapper
    token_tracker.rb      # Per-provider token counting and cost estimation

  background/
    scanner.rb            # Port probing, git repos, shell history, config detection
    github_probe.rb       # GitHub API: profile, repos, PRs, notifications, events
    kerberos_probe.rb     # klist + DNS SRV + LDAP profile resolution
```

## LegionIO Integration

- `legion tty` subcommand in LegionIO CLI (`lib/legion/cli/tty_command.rb`)
- Autoloaded: `autoload :Tty, 'legion/cli/tty_command'`
- Falls back gracefully if legion-tty gem not installed

## Key Patterns

- `::Process` and `::JSON` must be explicit (namespace collision with Legion::Process, Legion::JSON)
- Background probes use Thread + Queue pattern for async work during onboarding
- TTY::Cursor, TTY::Screen, TTY::Box, TTY::Font, TTY::Markdown are `require`d at point of use
- All file paths use `File.expand_path('~/.legionio/...')` for consistency

## Slash Commands

`/help /quit /clear /model /session /cost /export /tools /dashboard /hotkeys /save /load /sessions`

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Pre-Push Pipeline

Same as all Legion gems -- see parent CLAUDE.md.
