# frozen_string_literal: true

module Legion
  module TTY
    class Hotkeys
      def initialize
        @bindings = {}
      end

      def register(key, description, &block)
        @bindings[key] = { description: description, action: block }
      end

      # rubocop:disable Naming/PredicateMethod
      def handle(key)
        binding_entry = @bindings[key]
        return false unless binding_entry

        binding_entry[:action].call
        true
      end
      # rubocop:enable Naming/PredicateMethod

      def list
        @bindings.map { |key, b| { key: key, description: b[:description] } }
      end
    end
  end
end
