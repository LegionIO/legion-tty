# frozen_string_literal: true

require_relative '../theme'

module Legion
  module TTY
    module Components
      class Notification
        LEVELS = %i[info success warning error].freeze
        ICONS = { info: 'i', success: '+', warning: '!', error: 'x' }.freeze
        COLORS = { info: :info, success: :success, warning: :warning, error: :error }.freeze

        attr_reader :message, :level, :created_at

        def initialize(message:, level: :info, ttl: 5)
          @message = message
          @level = LEVELS.include?(level) ? level : :info
          @ttl = ttl
          @created_at = Time.now
        end

        def expired?
          Time.now - @created_at > @ttl
        end

        def render(width: 80)
          icon = Theme.c(COLORS[@level], ICONS[@level])
          text = Theme.c(COLORS[@level], @message)
          line = "#{icon} #{text}"
          plain_len = strip_ansi(line).length
          line + (' ' * [width - plain_len, 0].max)
        end

        private

        def strip_ansi(str)
          str.gsub(/\e\[[0-9;]*m/, '')
        end
      end
    end
  end
end
