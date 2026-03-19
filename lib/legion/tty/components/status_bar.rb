# frozen_string_literal: true

require_relative '../theme'
require_relative 'notification'

module Legion
  module TTY
    module Components
      class StatusBar
        def initialize
          @state = { model: nil, tokens: 0, cost: 0.0, session: 'default', thinking: false, plan_mode: false }
          @notifications = []
        end

        def notify(message:, level: :info, ttl: 5)
          @notifications << Notification.new(message: message, level: level, ttl: ttl)
        end

        def update(**fields)
          @state.merge!(fields)
        end

        def render(width:)
          segments = build_segments
          separator = Theme.c(:muted, ' | ')
          line = segments.join(separator)
          plain_length = strip_ansi(line).length
          if plain_length < width
            line + (' ' * (width - plain_length))
          else
            truncate_to_width(line, width)
          end
        end

        SPINNER_FRAMES = %w[| / - \\].freeze

        private

        def build_segments
          [
            model_segment,
            plan_segment,
            thinking_segment,
            notification_segment,
            tokens_segment,
            cost_segment,
            session_segment,
            scroll_segment
          ].compact
        end

        def model_segment
          Theme.c(:accent, @state[:model]) if @state[:model]
        end

        def plan_segment
          return nil unless @state[:plan_mode]

          Theme.c(:warning, '[PLAN]')
        end

        def thinking_segment
          return nil unless @state[:thinking]

          @spinner_index = ((@spinner_index || 0) + 1) % SPINNER_FRAMES.size
          frame = SPINNER_FRAMES[@spinner_index]
          Theme.c(:warning, "#{frame} thinking...")
        end

        def notification_segment
          @notifications.reject!(&:expired?)
          return nil if @notifications.empty?

          @notifications.first.render
        end

        def tokens_segment
          Theme.c(:secondary, "#{format_number(@state[:tokens])} tokens") if @state[:tokens].to_i.positive?
        end

        def cost_segment
          Theme.c(:success, format('$%.3f', @state[:cost])) if @state[:cost].to_f.positive?
        end

        def session_segment
          Theme.c(:muted, @state[:session]) if @state[:session]
        end

        def scroll_segment
          scroll = @state[:scroll]
          return nil unless scroll.is_a?(Hash) && scroll[:total].to_i > scroll[:visible].to_i

          Theme.c(:muted, "#{scroll[:current]}/#{scroll[:total]}")
        end

        def format_number(num)
          num.to_s.chars.reverse.each_slice(3).map(&:join).join(',').reverse
        end

        def strip_ansi(str)
          str.gsub(/\e\[[0-9;]*m/, '')
        end

        def truncate_to_width(str, width)
          plain = strip_ansi(str)
          return str if plain.length <= width

          result = +''
          visible = 0
          idx = 0
          while idx < str.length && visible < width
            if str[idx] == "\e"
              jdx = str.index('m', idx)
              if jdx
                result << str[idx..jdx]
                idx = jdx + 1
                next
              end
            end
            result << str[idx]
            visible += 1
            idx += 1
          end
          result
        end
      end
    end
  end
end
