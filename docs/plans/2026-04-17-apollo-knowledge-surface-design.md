# Design: Legion::Apollo Knowledge Surface in legion-tty

## Problem Statement

`Legion::Apollo` provides a rich query/ingest/graph API for the knowledge store, but `legion-tty` has zero integration with it. Users cannot:

- Query the knowledge store from chat (`/apollo query <text>`)
- Ingest a message or selected text into the store
- See Apollo status (started?, local/global, transport) in the dashboard

## Proposed Solution

### 1. `/apollo` command family

```ruby
# /apollo query <text>       — query global/local knowledge
# /apollo ingest <text>      — ingest current message or explicit text
# /apollo status             — show Apollo started state, transport, data availability
# /apollo graph <entity_id>  — graph traversal from entity
```

```ruby
def handle_apollo(input)
  return handle_apollo_status unless input && !input.strip.empty?
  sub, rest = input.strip.split(' ', 2)
  case sub
  when 'query'  then handle_apollo_query(rest)
  when 'ingest' then handle_apollo_ingest(rest)
  when 'graph'  then handle_apollo_graph(rest)
  when 'status' then handle_apollo_status
  else
    @message_stream.add_message(role: :system,
      content: 'Usage: /apollo [query|ingest|graph|status] <text>')
  end
  :handled
end
```

```ruby
def handle_apollo_query(text)
  unless defined?(Legion::Apollo) && Legion::Apollo.started?
    @message_stream.add_message(role: :system, content: 'Apollo not started.')
    return
  end
  result = Legion::Apollo.query(text: text, limit: 5)
  if result[:success]
    entries = Array(result[:entries])
    if entries.empty?
      @message_stream.add_message(role: :system, content: 'No results found.')
    else
      lines = entries.map.with_index(1) do |e, i|
        "[#{i}] (#{format('%.2f', e[:confidence])}) #{e[:content].to_s[0, 120]}"
      end
      @message_stream.add_message(role: :system,
        content: "Apollo results (#{entries.size}):\n#{lines.join("\n")}")
    end
  else
    @message_stream.add_message(role: :system, content: "Apollo query failed: #{result[:error]}")
  end
end
```

### 2. Apollo status in Dashboard

In `lib/legion/tty/screens/dashboard.rb`, panel 3 or 5 (System Info):

```
Apollo: started=true  transport=true  data=true  mode=global
```

### 3. Auto-ingest toggle (optional, flag-gated)

When `@apollo_autoingest` is true, after each user message confirmed as `role: :user`, ingest it:
```ruby
Legion::Apollo.ingest(content: message, tags: ['tty', 'chat'], scope: :local)
```

## Alternatives Considered

- **REST API via DaemonClient**: adds latency; Apollo is a library, not an HTTP endpoint — direct call preferred
- **Full graph viz in TTY**: out of scope for this issue

## Constraints

- `Legion::Apollo` may not be started (no lex-apollo co-located) — all paths guard with `Legion::Apollo.started?`
- `ingest` fires async when only transport available — no blocking
- Graph traversal returns `{ nodes:, edges: }` — render as indented tree (depth 1-3 only in TTY)
