# Implementation Plan: Onboarding GAIA + LLM Fixes

## Repo: LegionIO/legion-tty

All changes are in `legion-tty`. No cross-repo issues needed.

## Task 1: GAIA agentic gem installation

### Files to modify

- `lib/legion/tty/screens/onboarding.rb`

### Changes

1. Add `GAIA_GEMS` constant (after line 18):

```ruby
GAIA_GEMS = %w[
  lex-agentic-self lex-agentic-affect lex-agentic-attention
  lex-agentic-defense lex-agentic-executive lex-agentic-homeostasis
  lex-agentic-imagination lex-agentic-inference lex-agentic-integration
  lex-agentic-language lex-agentic-learning lex-agentic-memory
  lex-agentic-social
  lex-tick lex-extinction lex-mind-growth lex-mesh
  lex-synapse lex-react
  legion-gaia legion-apollo
].freeze
```

2. Add `offer_gaia_gems` private method:

```ruby
def offer_gaia_gems
  missing = GAIA_GEMS.reject do |name|
    Gem::Specification.find_by_name(name)
    true
  rescue Gem::MissingSpecError
    false
  end
  return if missing.empty?

  typed_output("#{missing.size} cognitive extension#{'s' if missing.size != 1} available.")
  @output.puts
  return unless @wizard.confirm('Install cognitive extensions?')

  missing.each { |name| Gem.install(name) }
  typed_output('Cognitive extensions installed. Neural pathways expanded.')
  @output.puts
rescue StandardError => e
  @log.log('gaia', "gem install failed: #{e.message}")
  typed_output('Some extensions could not be installed.')
  @output.puts
end
```

3. Call `offer_gaia_gems` in `run_gaia_awakening` after GAIA is confirmed
   online (both the "already awake" path and the "just started" path):
   - After line 210 (GAIA online message): `offer_gaia_gems`
   - After line 208 (already awake, threads synchronized): `offer_gaia_gems`

### Specs

- Spec that `offer_gaia_gems` does nothing when all gems installed
- Spec that `offer_gaia_gems` lists missing count and installs on confirm
- Spec that `offer_gaia_gems` skips install on decline
- Spec that `run_gaia_awakening` calls `offer_gaia_gems` after daemon start

## Task 2: LLM probe waits for bootstrap + recognizes dynamic providers

### Files to modify

- `lib/legion/tty/background/llm_probe.rb`
- `lib/legion/tty/screens/onboarding.rb`
- `lib/legion/tty/components/wizard_prompt.rb`

### Changes to `llm_probe.rb`

1. Add `wait_queue` parameter to `initialize`:

```ruby
def initialize(logger: nil, wait_queue: nil)
  @log = logger
  @wait_queue = wait_queue
end
```

2. Add `wait_for_bootstrap` call at the start of `probe_providers`:

```ruby
def probe_providers
  wait_for_bootstrap
  require 'legion/llm'
  require 'legion/settings'
  start_llm
  results = collect_provider_results
  { providers: results }
end
```

3. Add `wait_for_bootstrap` private method:

```ruby
def wait_for_bootstrap
  return unless @wait_queue

  @log&.log('llm_probe', 'waiting for bootstrap config (5s)')
  deadline = Time.now + 5
  loop do
    return unless @wait_queue.empty?
    return if Time.now >= deadline

    sleep 0.1
  end
  @log&.log('llm_probe', 'bootstrap config ready')
rescue StandardError => e
  @log&.log('llm_probe', "wait_for_bootstrap error: #{e.message}")
end
```

Note: This peeks at queue emptiness without consuming. The bootstrap probe
pushes to its own queue; we just need to know it finished. Alternative: use a
shared flag/latch instead of peeking at the queue. Simplest: pass a
`Concurrent::Event` or just a plain `@bootstrap_done` flag that bootstrap sets.

Actually, simplest approach: pass a `bootstrap_event` (a Queue or simple
thread-safe latch). The bootstrap probe pushes to `@bootstrap_queue` which the
main thread reads later. We can share that queue with LlmProbe for peeking, OR
use a simpler `Thread::Queue` as a signal:

Revised approach: In `start_background_threads`, create a
`@bootstrap_signal = Queue.new`. Have bootstrap probe push a signal when done.
Pass that signal queue to `LlmProbe`. LlmProbe drains it with 5s timeout
(consuming the signal is fine since it's a separate queue from the data queue).

4. Change `ping_provider` to return `:configured` instead of `:error` when
   the provider is enabled but ping fails:

```ruby
def ping_provider(name, config)
  model = config[:default_model]
  start_time = Time.now
  RubyLLM.chat(model: model, provider: name).ask('Respond with only: pong')
  latency = ((Time.now - start_time) * 1000).round
  { name: name, model: model, status: :ok, latency_ms: latency }
rescue StandardError => e
  latency = ((Time.now - start_time) * 1000).round
  { name: name, model: model, status: :configured, latency_ms: latency, error: e.message }
end
```

### Changes to `onboarding.rb`

1. In `start_background_threads`, create bootstrap signal and pass to LlmProbe:

```ruby
@bootstrap_signal = Queue.new
@bootstrap_probe = Background::BootstrapConfig.new(logger: @log, done_signal: @bootstrap_signal)
@bootstrap_probe.run_async(@bootstrap_queue)
@llm_probe = Background::LlmProbe.new(logger: @log, wait_queue: @bootstrap_signal)
@llm_probe.run_async(@llm_queue)
```

2. In `select_provider_default`, treat `:configured` as working when no `:ok`
   providers exist:

```ruby
def select_provider_default(providers)
  working = providers.select { |p| p[:status] == :ok }
  working = providers.select { |p| p[:status] == :configured } if working.empty?
  if working.any?
    default = @wizard.select_default_provider(working)
    sleep 0.5
    typed_output("Connected. Let's chat.")
    default
  else
    typed_output('No AI providers detected. Configure one in ~/.legionio/settings/llm.json')
    nil
  end
end
```

### Changes to `bootstrap_config.rb`

1. Add `done_signal` parameter:

```ruby
def initialize(logger: nil, done_signal: nil)
  @log = logger
  @done_signal = done_signal
end
```

2. Signal completion at end of `perform_bootstrap` (both success and skip paths):

```ruby
def perform_bootstrap
  # ... existing logic ...
ensure
  @done_signal&.push(true)
end
```

### Changes to `wizard_prompt.rb`

1. Update `display_provider_results` to handle `:configured` status:

```ruby
def display_provider_results(providers)
  providers.each do |p|
    icon = case p[:status]
           when :ok then "\u2705"
           when :configured then "\u{1F511}"
           else "\u274C"
           end
    # ... rest unchanged
  end
end
```

### Specs

- Spec that LlmProbe waits for bootstrap signal before probing
- Spec that LlmProbe proceeds after 5s timeout if no bootstrap signal
- Spec that ping_provider returns :configured (not :error) on ping failure
- Spec that select_provider_default falls back to :configured providers
- Spec that display_provider_results shows key icon for :configured
- Spec that bootstrap_config signals done_signal on completion and on skip

## Ordering

Tasks 1 and 2 are independent and can be implemented in parallel.
