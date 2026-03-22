# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class ProgressPanel
        attr_reader :title, :total, :current

        def initialize(title:, total:, output: $stdout)
          @title = title
          @total = total
          @current = 0
          @output = output
          @bar = build_bar
        end

        def advance(step = 1)
          @current = [@current + step, @total].min
          @bar&.advance(step)
        end

        def finish
          remaining = @total - @current
          @bar&.advance(remaining) if remaining.positive?
          @current = @total
        end

        def finished?
          @current >= @total
        end

        def percent
          return 0 if @total.zero?

          ((@current.to_f / @total) * 100).round(1)
        end

        def render(width: 80)
          pct = percent
          label = Theme.c(:accent, @title)
          bar = build_render_bar(width, pct)
          "#{label} [#{bar}] #{Theme.c(:secondary, "#{pct}%")}"
        end

        private

        def build_render_bar(width, pct)
          bar_width = [width - @title.length - 12, 10].max
          filled = (bar_width * pct / 100.0).round
          empty = bar_width - filled
          Theme.c(:primary, '#' * filled) + Theme.c(:muted, '-' * empty)
        end

        def build_bar
          require 'tty-progressbar'
          ::TTY::ProgressBar.new(
            "#{@title} [:bar] :percent",
            total: @total,
            output: @output,
            width: 40
          )
        rescue LoadError => e
          Legion::Logging.debug("tty-progressbar not available: #{e.message}") if defined?(Legion::Logging)
          nil
        end
      end
    end
  end
end
