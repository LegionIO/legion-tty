# Implementation: Legion::Tools::Registry Integration

## Phase 1 — `/tools` command upgrade

**Files**: `lib/legion/tty/screens/chat.rb` (handle_tools method, ~line 541)

- Replace gem-scan body with `Legion::Tools::Registry.all_tools` branch
- Keep gem-scan as fallback when `!defined?(Legion::Tools::Registry)`
- Show: tool_name, mcp_tier, deferred flag, truncated description
- Add always/deferred counts to header line

## Phase 2 — `/tool` command

**Files**:
- `lib/legion/tty/screens/chat.rb` — add `when '/tool' then handle_tool(input)`
- `lib/legion/tty/screens/chat/ui_commands.rb` — add `handle_tool(input)` method
- `lib/legion/tty/daemon_client.rb` — add `run_tool(name:, args:)` method

Logic:
1. Parse name + optional JSON args from input
2. Try `Legion::Tools::Registry.find(name)` — if found, call locally
3. Else call `DaemonClient.run_tool(name:, args:)`
4. Render result via `@message_stream.add_message`

## Phase 3 — Tool schemas in inference

**Files**: `lib/legion/tty/screens/chat.rb`

- Add private `build_tool_schemas` method
- Update `perform_inference` to pass `tools: build_tool_schemas`
- Only includes `Registry.tools` (always-loaded), not deferred

## Phase 4 — `DaemonClient.run_tool`

**Files**: `lib/legion/tty/daemon_client.rb`

- Add `run_tool(name:, args: {})` method
- POST to `/api/tools/run` with `{ name:, args: }`
- Returns `{ status: :ok/:error/:unavailable, data: }` 

## Phase 5 — TriggerIndex intent routing (optional, behind flag)

**Files**: `lib/legion/tty/screens/chat.rb`

- In `perform_inference`, before building messages, check `maybe_route_to_tool(message)`
- If match found and result is non-nil, render it without LLM round-trip
- Only active when `Legion::Tools::TriggerIndex.any?`

## Spec Coverage

- `spec/legion/tty/screens/chat_spec.rb` — `/tools` output format with Registry stub
- `spec/legion/tty/screens/chat_spec.rb` — `/tool` command routes locally vs daemon
- `spec/legion/tty/daemon_client_spec.rb` — `run_tool` happy/error/unavailable paths
- `spec/legion/tty/screens/chat_spec.rb` — `build_tool_schemas` returns correct shape

## Dependencies

- `legion-tty` already `require`s `legion-logging` — no new gem deps
- `Legion::Tools::Registry` defined when LegionIO gem loaded (not required in standalone mode)
- All paths gated on `defined?(Legion::Tools::Registry)`
