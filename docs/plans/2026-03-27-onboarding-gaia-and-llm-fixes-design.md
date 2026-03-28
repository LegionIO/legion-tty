# Onboarding: GAIA Agentic Gems + LLM Vault Provider Detection

## Problem

Two issues in the digital rain onboarding bootstrap flow:

### 1. GAIA wake does not install agentic gems

When a user says "yes" to "Shall I wake her?", `run_gaia_awakening` starts the
LegionIO daemon but never ensures the 13 agentic gems (lex-agentic-*) or
GAIA-tier extensions (lex-tick, lex-extinction, lex-mind-growth, lex-mesh) are
installed. The extension detection catalog (`lex-detect`) maps environment
signals (apps, ports, env vars) to service-oriented gems only -- it has no
entries for any agentic gems because they are not environment-detectable.

Result: GAIA starts but has no cognitive extensions to work with.

### 2. LLM probe ignores Vault-resolved dynamic provider keys

The `LlmProbe` calls `Legion::LLM.start` which reads `settings[:providers]`.
When LLM settings are delivered via Vault (through the bootstrap config or
`resolve_secrets!`), the resolved provider hash may contain keys beyond the 6
hardcoded defaults (bedrock, anthropic, openai, gemini, azure, ollama). Examples:

- A `foundry` provider key injected by Vault
- A `xai` provider key with an api_key
- Any custom key with valid credentials

The `auto_enable_from_resolved_credentials` method in `providers.rb` handles
unknown providers via its `else` branch (checks `config[:api_key]`), so
auto-enable works. But `apply_provider_config` logs a warning and skips
configuration for unknown providers, meaning they show as enabled but
un-configured and fail the ping. The probe then reports them as errored.

Additionally, during onboarding the bootstrap config runs concurrently with the
LLM probe. If Vault-sourced settings haven't been written to
`~/.legionio/settings/llm.json` by the time the probe reads settings, the
dynamic keys won't exist yet.

## Solution

### Fix 1: Offer agentic gems when waking GAIA

In `run_gaia_awakening`, after successfully starting the daemon (or even if
the daemon was already running), check whether the agentic gems are installed
and offer to install them.

Define a constant `GAIA_GEMS` listing the full set of cognitive extensions:

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

After the daemon start succeeds (or GAIA is already awake), call a new
`offer_gaia_gems` method that:

1. Filters `GAIA_GEMS` to only those not yet installed (via
   `Gem::Specification.find_by_name`)
2. If any are missing, displays the count and asks "Install cognitive
   extensions?"
3. On "yes", installs them via `Gem.install` (same pattern as
   `Detect::Installer`)

This keeps the install optional and visible -- the user sees exactly what's
happening.

### Fix 2: Recognize Vault-resolved dynamic LLM providers

Two changes:

**a) LlmProbe: wait for bootstrap config before probing**

In `start_background_threads`, the LLM probe currently launches immediately.
Instead, have the LLM probe wait for the bootstrap config to complete first
(since bootstrap config writes `llm.json`). The simplest approach: pass the
`@bootstrap_queue` to `LlmProbe` so it can wait for bootstrap completion before
probing, OR sequence them so the LLM probe launches after bootstrap completes.

Since both run in background threads and the LLM probe has a 15s timeout in
`detect_providers`, the cleanest fix is to have `LlmProbe` accept an optional
`wait_queue` that it drains (with a short timeout) before probing.

**b) LlmProbe: recognize enabled-but-unconfigured providers**

In `collect_provider_results`, instead of only reporting providers that passed
the `RubyLLM.chat` ping, also report providers that are `enabled: true` but
couldn't be pinged -- with a `:configured` status instead of `:ok` or `:error`.
This way, Vault-injected providers show up as "configured" even if the probe
can't validate them (because `apply_provider_config` doesn't know how to
configure them in RubyLLM).

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

And in `display_provider_results`, show `:configured` providers with a different
icon (e.g. a key icon or just "configured" text) so the user knows the provider
exists but wasn't validated.

**c) select_provider_default: treat :configured as working**

`select_provider_default` filters on `status == :ok`. It should also accept
`:configured` providers as selectable defaults when no `:ok` providers exist.

## Alternatives Considered

- **Add agentic gems to lex-detect catalog**: Rejected. Agentic gems aren't
  tied to detectable environment signals. They're tied to the GAIA decision.
- **Always install agentic gems**: Rejected. They're optional and should be
  opt-in.
- **Re-read settings after bootstrap in the same probe thread**: Simpler but
  doesn't address the timing issue cleanly -- the probe might still read stale
  settings.

## Constraints

- Onboarding must remain responsive -- no long blocking waits
- The probe timeout (15s) provides a natural upper bound for bootstrap wait
- Gem installation uses `Gem.install` which requires network access
- The `GAIA_GEMS` list must be maintained as new agentic gems are added
