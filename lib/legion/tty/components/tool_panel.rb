# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class ToolPanel
        ICONS = {
          running: "\u27F3",
          complete: "\u2713",
          failed: "\u2717"
        }.freeze

        STATUS_COLORS = {
          running: :info,
          complete: :success,
          failed: :error
        }.freeze

        # rubocop:disable Metrics/ParameterLists
        def initialize(name:, args:, status: :running, duration: nil, result: nil, error: nil)
          @name     = name
          @args     = args
          @status   = status
          @duration = duration
          @result   = result
          @error    = error
          @expanded = status == :failed
        end
        # rubocop:enable Metrics/ParameterLists

        def expanded?
          @expanded
        end

        def expand
          @expanded = true
        end

        def collapse
          @expanded = false
        end

        def toggle
          @expanded = !@expanded
        end

        def render(width: 80)
          lines = [header_line(width)]
          lines << body_line if @expanded && body_content
          lines.join("\n")
        end

        private

        def header_line(width)
          icon  = ICONS.fetch(@status, '?')
          color = STATUS_COLORS.fetch(@status, :muted)
          icon_colored = Theme.c(color, icon)
          name_colored = Theme.c(:accent, @name)
          suffix = duration_text
          line = "#{icon_colored} #{name_colored}#{suffix}"
          plain_len = strip_ansi(line).length
          line += ' ' * [width - plain_len, 0].max
          line
        end

        def duration_text
          return '' unless @duration

          Theme.c(:muted, " (#{format('%.2fs', @duration)})")
        end

        def body_content
          return @error if @error
          return @result if @result

          nil
        end

        def body_line
          content = body_content.to_s
          Theme.c(:muted, "  #{content}")
        end

        def strip_ansi(str)
          str.gsub(/\e\[[0-9;]*m/, '')
        end
      end
    end
  end
end
