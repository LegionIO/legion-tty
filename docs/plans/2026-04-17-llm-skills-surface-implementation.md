# Implementation: Legion::LLM::Skills Surface in legion-tty

## Phase 1 — `/skills` command

**Files**:
- `lib/legion/tty/screens/chat.rb`
  - Add `/skills` to `SLASH_COMMANDS` constant
  - Add `when '/skills' then handle_skills(input)` to dispatch
- `lib/legion/tty/screens/chat/ui_commands.rb`
  - Add `handle_skills(input)`, `handle_skill_load(input)`, `handle_skill_run(input)` methods

## Phase 2 — `/context` skill injection display

**Files**: `lib/legion/tty/screens/chat/ui_commands.rb`

In `handle_context`, after the existing context dump, append:
```ruby
if defined?(Legion::LLM::Skills::Registry)
  injected = Legion::LLM::Skills::Registry.by_trigger(:auto_inject)
  lines << "\nAuto-inject Skills (#{injected.size}):" if injected.any?
  injected.each { |s| lines << "  #{s.namespace}:#{s.skill_name}" }
end
```

## Phase 3 — Status bar skill indicator

**Files**: `lib/legion/tty/components/status_bar.rb`

When `@debug_mode` is true, show active skill count if `Legion::LLM::Skills::Registry` is available.

## Spec Coverage

- `spec/legion/tty/screens/chat_spec.rb` — `/skills` with empty/populated registry
- `spec/legion/tty/screens/chat_spec.rb` — `/skills load` happy path + file not found
- `spec/legion/tty/screens/chat_spec.rb` — `/skills run` found + not found

## Dependencies

- `legion-llm` gem; all guarded with `defined?(Legion::LLM::Skills::Registry)`
- No new gem deps
- Should land after tools-registry-integration (same chat dispatch pattern)
