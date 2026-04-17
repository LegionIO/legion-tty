# Implementation: Legion::Gaia NotificationGate Integration

## Phase 1 — `TTY::NotificationGate` module

**Files**: `lib/legion/tty/notification_gate.rb` (new file)

Thin wrapper around `Legion::Gaia::NotificationGate` with graceful fallback.

Require it in `lib/legion/tty/app.rb` alongside other requires.

## Phase 2 — Gate `status_bar.notify`

**Files**: `lib/legion/tty/components/status_bar.rb`

- Add private `level_to_priority(level)` method
- Wrap `add_notification` / `notify` body: early return if `!NotificationGate.should_deliver?(priority:)` for non-critical levels
- `error` level always delivers regardless

## Phase 3 — `/gaia` command

**Files**:
- `lib/legion/tty/screens/chat.rb` — add `/gaia` to SLASH_COMMANDS; add dispatch
- `lib/legion/tty/screens/chat/ui_commands.rb` — add `handle_gaia(input)`, `handle_gaia_status`, `handle_gaia_presence(input)`

## Spec Coverage

- `spec/legion/tty/notification_gate_spec.rb` (new) — fallback when Gaia not defined
- `spec/legion/tty/notification_gate_spec.rb` — delegates to Gaia when available
- `spec/legion/tty/components/status_bar_spec.rb` — `notify` is gated for :info/:success

## Dependencies

- `legion-gaia` gem; all guarded with `defined?(Legion::Gaia::NotificationGate)`
- Standalone from tools/skills issues — can land independently
