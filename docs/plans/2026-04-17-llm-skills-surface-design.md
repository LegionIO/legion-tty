# Design: Legion::LLM::Skills Surface in legion-tty

## Problem Statement

`Legion::LLM::Skills` (registry, disk loader, base class, step execution) is completely invisible in the TTY interface. Users cannot:

- Browse loaded skills (`Registry.all` by namespace/trigger)
- Invoke a skill manually from chat
- See which skills are auto-injected into the current conversation context
- Load a local `.md` or `.rb` skill file at runtime

## Proposed Solution

### 1. `/skills` command — list loaded skills

```ruby
def handle_skills(input)
  return handle_skill_load(input) if input.start_with?('load ')
  return handle_skill_run(input)  if input.start_with?('run ')

  if defined?(Legion::LLM::Skills::Registry)
    all = Legion::LLM::Skills::Registry.all
    if all.empty?
      @message_stream.add_message(role: :system, content: 'No skills registered.')
      return :handled
    end
    lines = all.map do |klass|
      trigger = klass.trigger || :on_demand
      words = klass.trigger_words.any? ? " [#{klass.trigger_words.join(', ')}]" : ''
      "  #{klass.namespace}:#{klass.skill_name} (#{trigger})#{words} — #{klass.description.to_s[0, 60]}"
    end
    @message_stream.add_message(role: :system,
      content: "LLM Skills (#{all.size}):\n#{lines.join("\n")}")
  else
    @message_stream.add_message(role: :system, content: 'Legion::LLM::Skills not available.')
  end
  :handled
end
```

### 2. `/skills load <path>` — load a skill file at runtime

```ruby
def handle_skill_load(input)
  path = input.delete_prefix('load ').strip
  expanded = File.expand_path(path)
  unless File.exist?(expanded)
    @message_stream.add_message(role: :system, content: "File not found: #{expanded}")
    return :handled
  end
  Legion::LLM::Skills::DiskLoader.load_md_skill(expanded)
  @message_stream.add_message(role: :system, content: "Skill loaded from: #{expanded}")
  :handled
rescue StandardError => e
  @message_stream.add_message(role: :system, content: "Skill load failed: #{e.message}")
  :handled
end
```

### 3. `/skills run <namespace>:<name>` — invoke a skill directly

```ruby
def handle_skill_run(input)
  key = input.delete_prefix('run ').strip
  ns, name = key.split(':', 2)
  klass = Legion::LLM::Skills::Registry.find("#{ns}:#{name}")
  unless klass
    @message_stream.add_message(role: :system, content: "Skill not found: #{key}")
    return :handled
  end
  result = klass.new.run(context: { conversation_id: @session_id })
  inject = result.inject.to_s
  @message_stream.add_message(role: :system, content: inject.empty? ? 'Skill ran (no injection).' : inject)
  :handled
rescue StandardError => e
  @message_stream.add_message(role: :system, content: "Skill run failed: #{e.message}")
  :handled
end
```

### 4. Skill auto-inject context display

When building system prompt, if `Legion::LLM::Skills::Registry.by_trigger(:auto_inject)` is non-empty, append a summary of active injected skills to the context panel (`/context` output and status bar debug mode).

## Alternatives Considered

- **Full skill execution UI with step progress**: too complex for first iteration; skills can be long-running
- **Auto-inject in every inference call**: would require SkillRunResult injection into system prompt — follow-on issue after this one lands

## Constraints

- `Legion::LLM::Skills` is defined inside `legion-llm` gem — guard with `defined?`
- Skill `run` emits events via `Legion::Events` — graceful fallback if Events not started
- `DiskLoader.load_md_skill` expects a path to `.md`; `.rb` files use `require` — handle both
