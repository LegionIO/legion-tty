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

      def handle(key)
        binding_entry = @bindings[key]
        return nil unless binding_entry

        binding_entry[:action].call
      end

      def list
        @bindings.map { |key, b| { key: key, description: b[:description] } }
      end
    end
  end
end
