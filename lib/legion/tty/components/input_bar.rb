# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class InputBar
        attr_reader :completions

        def initialize(name: 'User', reader: nil, completions: [])
          @name = name
          @completions = completions
          @reader = reader || build_default_reader
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

        def complete(partial)
          return [] if partial.nil? || partial.empty?

          @completions.select { |c| c.start_with?(partial) }.sort
        end

        def history
          return [] unless @reader.respond_to?(:history)

          @reader.history.to_a
        end

        private

        def build_default_reader
          require 'tty-reader'
          reader = ::TTY::Reader.new(history_cycle: true)
          register_tab_completion(reader)
          reader
        rescue LoadError
          nil
        end

        def register_tab_completion(reader)
          return if @completions.empty?

          @tab_matches = []
          @tab_index = 0

          reader.on(:keypress) do |event|
            handle_tab(event) if event.value == "\t"
          end
        end

        def handle_tab(event)
          line = event.line.text.to_s
          matches = complete(line)
          return if matches.empty?

          if matches.size == 1
            event.line.replace(matches.first)
          else
            @tab_matches = matches unless @tab_matches == matches
            event.line.replace(@tab_matches[@tab_index % @tab_matches.size])
            @tab_index += 1
          end
        end
      end
    end
  end
end
