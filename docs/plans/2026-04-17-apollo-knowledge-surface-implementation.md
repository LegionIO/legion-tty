# Implementation: Legion::Apollo Knowledge Surface in legion-tty

## Phase 1 — `/apollo` command

**Files**:
- `lib/legion/tty/screens/chat.rb` — add `/apollo` to SLASH_COMMANDS; add dispatch case
- `lib/legion/tty/screens/chat/ui_commands.rb` — add `handle_apollo`, `handle_apollo_query`, `handle_apollo_ingest`, `handle_apollo_graph`, `handle_apollo_status`

## Phase 2 — Apollo panel in Dashboard

**Files**: `lib/legion/tty/screens/dashboard.rb`

Add Apollo availability line to system info panel:
```ruby
if defined?(Legion::Apollo)
  transport = Legion::Apollo.transport_available? ? 'yes' : 'no'
  data = Legion::Apollo.data_available? ? 'yes' : 'no'
  started = Legion::Apollo.started? ? 'yes' : 'no'
  lines << "Apollo: started=#{started}  transport=#{transport}  data=#{data}"
end
```

## Phase 3 — Auto-ingest flag (optional)

**Files**: `lib/legion/tty/screens/chat.rb`

- Add `@apollo_autoingest = false` to `initialize`
- After message confirmed (`role: :user`), if flag set, call `Legion::Apollo.ingest(...)`
- Add `/apollo autoingest` toggle to `handle_apollo`

## Spec Coverage

- `spec/legion/tty/screens/chat_spec.rb` — `/apollo status` with/without Legion::Apollo
- `spec/legion/tty/screens/chat_spec.rb` — `/apollo query` success + empty + failure
- `spec/legion/tty/screens/chat_spec.rb` — `/apollo ingest` 

## Dependencies

- `legion-apollo` gem; all guarded with `defined?(Legion::Apollo)`
- Should land after tools-registry-integration (establishes pattern for service-aware commands)
