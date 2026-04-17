# Design: Legion::Gaia NotificationGate Integration

## Problem Statement

`Legion::Gaia::NotificationGate` has three evaluators — `BehavioralEvaluator`, `PresenceEvaluator`, `ScheduleEvaluator` — plus a `DelayQueue`. The TTY has its own `Notification` component (transient banners) but no awareness of:

- User presence/availability (DoNotDisturb, Away, etc.)
- Quiet-hours schedules
- Behavioral arousal signals (suppress low-priority notifications when idle)

As a result, the TTY fires all status notifications regardless of user state — noisy when the user is heads-down.

## Proposed Solution

### 1. `TTY::NotificationGate` wrapper

A thin module in `lib/legion/tty/` that delegates to Gaia's evaluators when available, falls back to "always deliver" otherwise:

```ruby
module Legion
  module TTY
    module NotificationGate
      class << self
        def should_deliver?(priority: :normal)
          return true unless gaia_gate_available?
          Legion::Gaia::NotificationGate.instance.should_notify?(priority: priority)
        rescue StandardError
          true
        end

        def update_presence(availability:, activity: nil)
          return unless gaia_gate_available?
          Legion::Gaia::NotificationGate.instance.update_presence(
            availability: availability, activity: activity
          )
        rescue StandardError
          nil
        end

        private

        def gaia_gate_available?
          defined?(Legion::Gaia::NotificationGate) &&
            Legion::Gaia::NotificationGate.respond_to?(:instance)
        end
      end
    end
  end
end
```

### 2. Gate status bar notifications

In `lib/legion/tty/components/status_bar.rb`, `notify` method:

```ruby
def notify(message:, level: :info, ttl: 5)
  priority = level_to_priority(level)
  return unless Legion::TTY::NotificationGate.should_deliver?(priority: priority)
  # existing notification logic
end

private

def level_to_priority(level)
  { info: :ambient, success: :low, warning: :normal, error: :urgent }[level] || :normal
end
```

### 3. `/gaia status` command

Show NotificationGate evaluator state:

```
Gaia NotificationGate:
  Presence  : Available (updated 30s ago)
  Arousal   : 0.72
  Quiet now : no
  Delivery  : ambient+ allowed
```

### 4. `/gaia presence <status>` — manual override

Allow user to manually set their presence from TTY:
```
/gaia presence DoNotDisturb
```

This updates the PresenceEvaluator so only `:critical` notifications break through.

## Alternatives Considered

- **Poll system presence**: platform-specific (macOS focus modes, Teams) — follow-on issue
- **Wrap every notification in gate**: scope limited to `status_bar.notify` only for now — system messages (errors) bypass for visibility

## Constraints

- `Legion::Gaia::NotificationGate` may not be started — always guard
- `critical` and `urgent` notifications always deliver regardless of gate (errors, daemon down)
- Gate only applies to TTY-internal notifications, not LLM response rendering
