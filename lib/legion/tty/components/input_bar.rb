# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class InputBar # rubocop:disable Metrics/ClassLength
        attr_reader :completions, :buffer

        def initialize(name: 'User', reader: nil, completions: [])
          @name = name
          @completions = completions
          @buffer = +''
          @cursor_pos = 0
          @history_entries = []
          @history_index = nil
          @saved_buffer = nil
          @tab_matches = []
          @tab_index = 0
          @legacy_reader = reader
          @thinking = false
        end

        def prompt_string
          "#{Theme.c(:accent, @name)} #{Theme.c(:primary, '>')} "
        end

        def prompt_plain_length
          @name.length + 3
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        def handle_key(key)
          case key
          when :enter
            submit_line
          when :backspace
            handle_backspace
          when :tab
            handle_tab_key
          when :up
            history_prev
          when :down
            history_next
          when :right
            @cursor_pos = [@cursor_pos + 1, @buffer.length].min
            :handled
          when :left
            @cursor_pos = [@cursor_pos - 1, 0].max
            :handled
          when :home, :ctrl_a
            @cursor_pos = 0
            :handled
          when :end, :ctrl_e
            @cursor_pos = @buffer.length
            :handled
          when :ctrl_u
            @buffer = +''
            @cursor_pos = 0
            :handled
          when String
            insert_char(key)
          else
            :pass
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

        def render_line(width:)
          avail = [width - prompt_plain_length, 1].max
          display = if @buffer.length > avail
                      @buffer[(@buffer.length - avail)..]
                    else
                      @buffer
                    end
          "#{prompt_string}#{display}"
        end

        def cursor_column
          prompt_plain_length + @cursor_pos
        end

        def current_line
          @buffer.dup
        end

        def clear_buffer
          @buffer = +''
          @cursor_pos = 0
        end

        def history
          @history_entries.dup
        end

        # Backward-compatible blocking read for onboarding/tests
        def read_line
          reader = @legacy_reader || build_legacy_reader
          reader&.read_line(prompt_string)
        rescue Interrupt
          nil
        end

        def complete(partial)
          return [] if partial.nil? || partial.empty?

          @completions.select { |c| c.start_with?(partial) }.sort
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

        private

        def submit_line
          line = @buffer.dup
          @history_entries << line unless line.strip.empty? || line == @history_entries.last
          @buffer = +''
          @cursor_pos = 0
          @history_index = nil
          @saved_buffer = nil
          @tab_matches = []
          @tab_index = 0
          [:submit, line]
        end

        def handle_backspace
          return :handled if @cursor_pos.zero?

          @buffer.slice!(@cursor_pos - 1)
          @cursor_pos -= 1
          @tab_matches = []
          :handled
        end

        def handle_tab_key
          return :handled if @buffer.empty?

          matches = complete(@buffer)
          return :handled if matches.empty?

          if matches.size == 1
            @buffer = "#{matches.first} "
            @cursor_pos = @buffer.length
          else
            @tab_matches = matches unless @tab_matches == matches
            @buffer = +@tab_matches[@tab_index % @tab_matches.size].to_s
            @cursor_pos = @buffer.length
            @tab_index += 1
          end
          :handled
        end

        def history_prev
          return :handled if @history_entries.empty?

          if @history_index.nil?
            @saved_buffer = @buffer.dup
            @history_index = @history_entries.size - 1
          elsif @history_index.positive?
            @history_index -= 1
          else
            return :handled
          end
          @buffer = +@history_entries[@history_index].to_s
          @cursor_pos = @buffer.length
          :handled
        end

        def history_next
          return :handled if @history_index.nil?

          if @history_index < @history_entries.size - 1
            @history_index += 1
            @buffer = +@history_entries[@history_index].to_s
          else
            @history_index = nil
            @buffer = +(@saved_buffer || '')
            @saved_buffer = nil
          end
          @cursor_pos = @buffer.length
          :handled
        end

        def insert_char(key)
          return :pass unless key.is_a?(String) && key.length == 1 && key.ord >= 32

          @buffer.insert(@cursor_pos, key)
          @cursor_pos += 1
          @tab_matches = []
          :handled
        end

        def build_legacy_reader
          require 'tty-reader'
          ::TTY::Reader.new(history_cycle: true)
        rescue LoadError
          nil
        end
      end
    end
  end
end
