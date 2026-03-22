# frozen_string_literal: true

require 'legion/json'

module Legion
  module TTY
    module Components
      class ToolCallParser
        OPEN_TAG = '<tool_call>'
        CLOSE_TAG = '</tool_call>'
        MAX_BUFFER = 4096

        def initialize(on_text:, on_tool_call:)
          @on_text = on_text
          @on_tool_call = on_tool_call
          reset
        end

        def feed(text)
          @working = @buffer + text
          @buffer = +''

          loop do
            break if @working.empty?

            if @state == :passthrough
              break unless advance_passthrough?
            else
              break unless advance_buffering?
            end
          end

          @buffer = @working
        end

        def flush
          return if @buffer.empty?

          @on_text.call(@buffer)
          @buffer = +''
          @state = :passthrough
        end

        def reset
          @buffer = +''
          @working = +''
          @state = :passthrough
        end

        private

        def advance_passthrough?
          idx = @working.index(OPEN_TAG)

          if idx
            @on_text.call(@working[0...idx]) unless idx.zero?
            @working = @working[idx..]
            @state = :buffering
            true
          elsif partial_open_match?
            false
          else
            @on_text.call(@working)
            @working = +''
            false
          end
        end

        def advance_buffering?
          idx = @working.index(CLOSE_TAG)

          if idx
            end_pos = idx + CLOSE_TAG.length
            emit_tool_call(@working[OPEN_TAG.length...idx])
            @working = @working[end_pos..]
            @state = :passthrough
            true
          elsif @working.length > MAX_BUFFER
            @on_text.call(@working)
            @working = +''
            @state = :passthrough
            false
          else
            false
          end
        end

        def emit_tool_call(json_str)
          parsed = Legion::JSON.load(json_str.strip)
          name = parsed[:name] || parsed['name']
          args = parsed[:arguments] || parsed['arguments'] || {}

          unless name
            @on_text.call("#{OPEN_TAG}#{json_str}#{CLOSE_TAG}")
            return
          end

          @on_tool_call.call(name: name, args: args)
        rescue StandardError => e
          Legion::Logging.warn("emit_tool_call failed: #{e.message}") if defined?(Legion::Logging)
          @on_text.call("#{OPEN_TAG}#{json_str}#{CLOSE_TAG}")
        end

        def partial_open_match?
          tag = OPEN_TAG
          (1...([tag.length, @working.length].min + 1)).any? do |len|
            suffix = @working[-len..]
            tag.start_with?(suffix) && suffix.length < tag.length
          end
        end
      end
    end
  end
end
