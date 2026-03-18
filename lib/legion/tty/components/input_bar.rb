# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class InputBar
        def initialize(name: 'User', reader: nil)
          @name = name
          @reader = reader
          @thinking = false
        end

        def prompt_string
          "#{Theme.c(:accent, @name)} #{Theme.c(:primary, '>')} "
        end

        def read_line
          @reader.read_line(prompt_string)
        end

        def show_thinking
          @thinking = true
        end

        def clear_thinking
          @thinking = false
        end

        def thinking?
          @thinking
        end
      end
    end
  end
end
