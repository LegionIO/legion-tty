# Design: Legion::Tools::Registry Integration

## Problem Statement

`legion-tty`'s `/tools` command scans `Gem::Specification` for `lex-*` gems — it knows nothing about the actual **registered** tools in `Legion::Tools::Registry`. This means:

- Users see gem names/versions, not tool names, descriptions, or schemas
- The inference pipeline passes `tools: []` to `DaemonClient.inference` — the LLM never gets actual tools
- `legion.do` (natural-language tool routing via `Legion::Tools::Do`) is never invoked
- `legion.get_status` and `legion.get_config` exist but have no TTY surface
- `Legion::Tools::TriggerIndex` (semantic word→tool matching) is unused

## Proposed Solution

### 1. Rewrite `/tools` to query `Legion::Tools::Registry`

```ruby
def handle_tools
  if defined?(Legion::Tools::Registry)
    all = Legion::Tools::Registry.all_tools
    lines = all.map do |t|
      tier = t.respond_to?(:mcp_tier) && t.mcp_tier ? " [T#{t.mcp_tier}]" : ''
      deferred = t.respond_to?(:deferred?) && t.deferred? ? ' (deferred)' : ''
      "  #{t.tool_name}#{tier}#{deferred} — #{t.description.to_s[0, 80]}"
    end
    @message_stream.add_message(role: :system,
      content: "Legion Tools (#{all.size}):\n#{lines.join("\n")}")
  else
    # fallback: gem scan (existing behavior)
    ...
  end
end
```

### 2. Add `/tool <name> [json-args]` command

Invokes a registered tool directly from TTY:

```ruby
# /tool legion.get_status
# /tool legion.do {"intent": "list running tasks"}
def handle_tool(input)
  name, rest = input.strip.split(' ', 2)
  tool = Legion::Tools::Registry.find(name)
  unless tool
    # fallback: ask daemon
    result = DaemonClient.run_tool(name: name, args: parse_args(rest))
    ...
  end
  args = rest ? Legion::JSON.load(rest) : {}
  result = tool.call(**args.transform_keys(&:to_sym))
  render_tool_result(result)
end
```

### 3. Pass tools to inference

Build tool schemas from `Registry.tools` (always-loaded, non-deferred) and pass to daemon:

```ruby
def build_tool_schemas
  return [] unless defined?(Legion::Tools::Registry)
  Legion::Tools::Registry.tools.map do |t|
    {
      name:        t.tool_name,
      description: t.description,
      input_schema: t.input_schema || { type: 'object', properties: {} }
    }
  end
rescue StandardError
  []
end
```

Pass to `DaemonClient.inference(messages:, tools: build_tool_schemas, ...)`.

### 4. Add `DaemonClient.run_tool`

```ruby
def run_tool(name:, args: {})
  uri = URI("#{daemon_url}/api/tools/run")
  payload = Legion::JSON.dump({ name: name, args: args })
  response = post_json(uri, payload)
  return { status: :unavailable } unless response
  return { status: :error, body: response.body } unless SUCCESS_CODES.include?(response.code.to_i)
  { status: :ok, data: Legion::JSON.load(response.body)[:data] }
rescue StandardError => e
  handle_exception(e, level: :warn, operation: 'tty.daemon_client.run_tool')
  { status: :error, error: e.message }
end
```

### 5. `legion.do` intent routing

When a user message matches a tool trigger word (via `TriggerIndex` or prefix `/do`), route to `legion.do`:

```ruby
def maybe_route_to_tool(message)
  return nil unless defined?(Legion::Tools::TriggerIndex) && !Legion::Tools::TriggerIndex.empty?
  words = message.downcase.split(/\W+/)
  matched, _per_word = Legion::Tools::TriggerIndex.match(words)
  return nil if matched.empty?
  Legion::Tools::Do.call(intent: message)
end
```

## Alternatives Considered

- **Always pull from daemon**: adds round-trip latency for every keystroke; Registry is local and fast.
- **Replace ToolCallParser with full tool dispatcher**: scope creep — parser handles streaming; invocation is separate.

## Constraints

- `Legion::Tools::Registry` may not be defined (lite mode or no daemon running) — all paths guard with `defined?`
- Deferred tools (most extension tools) stay deferred; only `tools` (always-loaded) go into inference
- Tool schemas sent to daemon must be JSON-serializable (no Ruby objects)
