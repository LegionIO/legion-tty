# frozen_string_literal: true

require 'English'
require_relative '../theme'

module Legion
  module TTY
    module Components
      # rubocop:disable Metrics/ClassLength
      class MessageStream
        attr_reader :messages, :scroll_offset
        attr_accessor :mute_system, :silent_mode, :highlights, :filter, :truncate_limit, :wrap_width, :show_numbers,
                      :colorize, :show_timestamps

        HIGHLIGHT_COLOR = "\e[1;33m"
        HIGHLIGHT_RESET = "\e[0m"

        def initialize
          @messages = []
          @scroll_offset = 0
          @mute_system = false
          @silent_mode = false
          @highlights = []
          @wrap_width = nil
          @show_numbers = false
          @colorize = true
          @show_timestamps = true
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
          effective_width = @wrap_width || width
          all_lines = build_all_lines(effective_width)
          total = all_lines.size
          start_idx = [total - height - @scroll_offset, 0].max
          start_idx = [start_idx, total].min
          result = all_lines[start_idx, height] || []
          result = result.map { |l| strip_ansi(l) } unless @colorize
          @last_visible_count = result.size
          result
        end

        def scroll_position
          { current: @scroll_offset, total: @messages.size, visible: @last_visible_count || 0 }
        end

        private

        def build_all_lines(width)
          filtered_messages.each_with_index.flat_map do |msg, idx|
            next [] if @mute_system && msg[:role] == :system
            next [] if @silent_mode && msg[:role] == :assistant

            render_message(msg, width, @show_numbers ? idx + 1 : nil)
          end
        end

        def filtered_messages
          return @messages if @filter.nil?

          case @filter[:type]
          when :role
            @messages.select { |m| m[:role].to_s == @filter[:value].to_s }
          when :tag
            @messages.select { |m| (m[:tags] || []).include?(@filter[:value]) }
          when :pinned
            @messages.select { |m| m[:pinned] }
          else
            @messages
          end
        end

        def render_message(msg, width, number = nil)
          lines = role_lines(msg, width) + panel_lines(msg, width)
          prepend_number(lines, number)
        end

        def prepend_number(lines, number)
          return lines unless number

          lines.each_with_index.map do |line, i|
            i == 1 ? "[#{number}] #{line}" : line
          end
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
          content = apply_highlights(msg[:content].to_s)
          lines = ['', "#{user_header(msg[:timestamp])}: #{content}"]
          lines << reaction_line(msg) if msg[:reactions]&.any?
          lines.concat(annotation_lines(msg)) if msg[:annotations]&.any?
          lines
        end

        def user_header(timestamp)
          ts = @show_timestamps ? format_timestamp(timestamp) : ''
          ts.empty? ? Theme.c(:accent, 'You') : "#{Theme.c(:accent, 'You')} #{Theme.c(:muted, ts)}"
        end

        def format_timestamp(time)
          return '' unless time

          time.strftime('%H:%M')
        end

        def assistant_lines(msg, width)
          content = display_content(msg[:content])
          rendered = render_markdown(content, width)
          rendered = apply_highlights(rendered)
          lines = ['', *rendered.split("\n")]
          lines << reaction_line(msg) if msg[:reactions]&.any?
          lines.concat(annotation_lines(msg)) if msg[:annotations]&.any?
          lines
        end

        def display_content(content)
          return content unless @truncate_limit
          return content if content.to_s.length <= @truncate_limit

          "#{content[0...@truncate_limit]}... [truncated]"
        end

        def reaction_line(msg)
          reactions = msg[:reactions].map { |r| "[#{r}]" }.join(' ')
          "  #{Theme.c(:muted, reactions)}"
        end

        def annotation_lines(msg)
          msg[:annotations].map do |a|
            ts = a[:timestamp].to_s[11..15] || ''
            "  #{Theme.c(:muted, "note [#{ts}]: #{a[:text]}")}"
          end
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

        def apply_highlights(text)
          return text if @highlights.nil? || @highlights.empty?

          @highlights.reduce(text) do |result, pattern|
            result.gsub(pattern) { "#{HIGHLIGHT_COLOR}#{$LAST_MATCH_INFO}#{HIGHLIGHT_RESET}" }
          end
        rescue StandardError
          text
        end

        def apply_tool_panel_update(panel, status:, duration:, result:, error:)
          panel.instance_variable_set(:@status, status)
          panel.instance_variable_set(:@duration, duration) if duration
          panel.instance_variable_set(:@result, result) if result
          panel.instance_variable_set(:@error, error) if error
        end

        def strip_ansi(text)
          text.gsub(/\e\[[0-9;]*m/, '')
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
