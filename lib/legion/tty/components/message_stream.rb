# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class MessageStream
        attr_reader :messages, :scroll_offset

        def initialize
          @messages = []
          @scroll_offset = 0
        end

        def add_message(role:, content:)
          @messages << { role: role, content: content, tool_panels: [] }
        end

        def append_streaming(text)
          return if @messages.empty?

          @messages.last[:content] = @messages.last[:content] + text
        end

        def add_tool_panel(panel)
          return if @messages.empty?

          @messages.last[:tool_panels] << panel
        end

        def add_tool_call(name:, args: {}, status: :running)
          require_relative 'tool_panel'
          panel = ToolPanel.new(name: name, args: args, status: status)
          @messages << { role: :tool, content: panel, tool_panel: true }
        end

        def update_tool_call(name:, status:, duration: nil, result: nil, error: nil)
          tool_msg = @messages.reverse.find do |m|
            m[:tool_panel] && m[:content].is_a?(ToolPanel) && m[:content].instance_variable_get(:@name) == name
          end
          return unless tool_msg

          apply_tool_panel_update(tool_msg[:content], status: status, duration: duration, result: result, error: error)
        end

        def scroll_up(lines = 1)
          @scroll_offset += lines
        end

        def scroll_down(lines = 1)
          @scroll_offset = [@scroll_offset - lines, 0].max
        end

        def render(width:, height:)
          all_lines = build_all_lines(width)
          total = all_lines.size
          start_idx = [total - height - @scroll_offset, 0].max
          start_idx = [start_idx, total].min
          all_lines[start_idx, height] || []
        end

        private

        def build_all_lines(width)
          @messages.flat_map { |msg| render_message(msg, width) }
        end

        def render_message(msg, width)
          role_lines(msg, width) + panel_lines(msg, width)
        end

        def role_lines(msg, width)
          case msg[:role]
          when :user then user_lines(msg)
          when :assistant then assistant_lines(msg, width)
          when :system then system_lines(msg)
          when :tool then tool_call_lines(msg, width)
          else []
          end
        end

        def user_lines(msg)
          prefix = Theme.c(:accent, 'You')
          ['', "#{prefix}: #{msg[:content]}"]
        end

        def assistant_lines(msg, width)
          rendered = render_markdown(msg[:content], width)
          ['', *rendered.split("\n")]
        end

        def render_markdown(text, width)
          require_relative 'markdown_view'
          MarkdownView.render(text, width: width)
        rescue StandardError
          text
        end

        def system_lines(msg)
          msg[:content].split("\n").map { |l| "  #{Theme.c(:muted, l)}" }
        end

        def tool_call_lines(msg, width)
          return [] unless msg[:tool_panel] && msg[:content].respond_to?(:render)

          msg[:content].render(width: width).split("\n")
        end

        def panel_lines(msg, width)
          msg[:tool_panels].flat_map { |panel| panel.render(width: width).split("\n") }
        end

        def apply_tool_panel_update(panel, status:, duration:, result:, error:)
          panel.instance_variable_set(:@status, status)
          panel.instance_variable_set(:@duration, duration) if duration
          panel.instance_variable_set(:@result, result) if result
          panel.instance_variable_set(:@error, error) if error
        end
      end
    end
  end
end
