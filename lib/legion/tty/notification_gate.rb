# frozen_string_literal: true

module Legion
  module TTY
    module NotificationGate
      class << self
        def should_deliver?(priority: :normal)
          return true unless gaia_gate_available?

          Legion::Gaia::NotificationGate.instance.should_notify?(priority: priority)
        rescue StandardError => e
          Legion::Logging.debug("NotificationGate.should_deliver? failed: #{e.message}") if defined?(Legion::Logging)
          true
        end

        def update_presence(availability:, activity: nil)
          return unless gaia_gate_available?

          Legion::Gaia::NotificationGate.instance.update_presence(
            availability: availability, activity: activity
          )
        rescue StandardError => e
          Legion::Logging.debug("NotificationGate.update_presence failed: #{e.message}") if defined?(Legion::Logging)
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
