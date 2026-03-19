# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      # rubocop:disable Metrics/ClassLength
      class MessageStream
        attr_reader :messages, :scroll_offset
        attr_accessor :mute_system

        def initialize
          @messages = []
          @scroll_offset = 0
          @mute_system = false
        end

        def add_message(role:, content:)
          @messages << { role: role, content: content, tool_panels: [], timestamp: Time.now }
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
          result = all_lines[start_idx, height] || []
          @last_visible_count = result.size
          result
        end

        def scroll_position
          { current: @scroll_offset, total: @messages.size, visible: @last_visible_count || 0 }
        end

        private

        def build_all_lines(width)
          @messages.flat_map do |msg|
            next [] if @mute_system && msg[:role] == :system

            render_message(msg, width)
          end
        end

        def render_message(msg, width)
          role_lines(msg, width) + panel_lines(msg, width)
        end

        def role_lines(msg, width)
          case msg[:role]
          when :user then user_lines(msg, width)
          when :assistant then assistant_lines(msg, width)
          when :system then system_lines(msg)
          when :tool then tool_call_lines(msg, width)
          else []
          end
        end

        def user_lines(msg, _width)
          ts = format_timestamp(msg[:timestamp])
          header = "#{Theme.c(:accent, 'You')} #{Theme.c(:muted, ts)}"
          lines = ['', "#{header}: #{msg[:content]}"]
          lines << reaction_line(msg) if msg[:reactions]&.any?
          lines
        end

        def format_timestamp(time)
          return '' unless time

          time.strftime('%H:%M')
        end

        def assistant_lines(msg, width)
          rendered = render_markdown(msg[:content], width)
          lines = ['', *rendered.split("\n")]
          lines << reaction_line(msg) if msg[:reactions]&.any?
          lines
        end

        def reaction_line(msg)
          reactions = msg[:reactions].map { |r| "[#{r}]" }.join(' ')
          "  #{Theme.c(:muted, reactions)}"
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
      # rubocop:enable Metrics/ClassLength
    end
  end
end
