# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Dashboard < Base
        def initialize(app)
          super
          @last_refresh = nil
          @refresh_interval = 5
          @cached_data = {}
        end

        def activate
          refresh_data
        end

        # rubocop:disable Metrics/AbcSize
        def render(width, height)
          refresh_data if stale?

          rows = []
          rows.concat(render_header(width))
          rows.concat(render_services_panel(width))
          rows.concat(render_extensions_panel(width))
          rows.concat(render_system_panel(width))
          rows.concat(render_activity_panel(width, remaining_height(height, rows.size)))
          rows.concat(render_help_bar(width))

          pad_to_height(rows, height)
        end

        # rubocop:enable Metrics/AbcSize

        def handle_input(key)
          case key
          when 'r', :f5
            refresh_data
            :handled
          when 'q', :escape
            :pop_screen
          else
            :pass
          end
        end

        def refresh_data
          @last_refresh = Time.now
          @cached_data = {
            services: probe_services,
            extensions: discover_extensions,
            system: system_info,
            activity: recent_activity
          }
        end

        private

        def stale?
          @last_refresh.nil? || (Time.now - @last_refresh) > @refresh_interval
        end

        def render_header(width)
          title = Theme.c(:primary, ' LEGION DASHBOARD ')
          timestamp = Theme.c(:muted, @last_refresh&.strftime('%H:%M:%S') || '--:--:--')
          line = "#{title}#{' ' * [width - 30, 0].max}#{timestamp}"
          [line, Theme.c(:muted, '-' * width)]
        end

        def render_services_panel(_width)
          services = @cached_data[:services] || {}
          lines = [Theme.c(:accent, '  Services')]
          services.each do |name, info|
            icon = info[:running] ? Theme.c(:success, "\u2713") : Theme.c(:error, "\u2717")
            port_str = Theme.c(:muted, ":#{info[:port]}")
            lines << "    #{icon} #{name} #{port_str}"
          end
          lines << ''
          lines
        end

        def render_extensions_panel(_width)
          extensions = @cached_data[:extensions] || []
          count = extensions.size
          lines = [Theme.c(:accent, "  Extensions (#{count})")]
          if extensions.empty?
            lines << Theme.c(:muted, '    No lex-* gems found')
          else
            extensions.first(8).each do |ext|
              lines << "    #{Theme.c(:secondary, ext)}"
            end
            remaining = count - 8
            lines << Theme.c(:muted, "    ... and #{remaining} more") if remaining.positive?
          end
          lines << ''
          lines
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        def render_system_panel(_width)
          sys = @cached_data[:system] || {}
          lines = [Theme.c(:accent, '  System')]
          lines << "    Ruby:     #{Theme.c(:secondary, sys[:ruby_version] || 'unknown')}"
          lines << "    OS:       #{Theme.c(:secondary, sys[:os] || 'unknown')}"
          lines << "    Host:     #{Theme.c(:secondary, sys[:hostname] || 'unknown')}"
          lines << "    PID:      #{Theme.c(:secondary, sys[:pid]&.to_s || 'unknown')}"
          lines << "    Memory:   #{Theme.c(:secondary, sys[:memory] || 'unknown')}"
          lines << ''
          lines
        end

        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        def render_activity_panel(_width, max_lines)
          activity = @cached_data[:activity] || []
          lines = [Theme.c(:accent, '  Recent Activity')]
          if activity.empty?
            lines << Theme.c(:muted, '    No recent activity')
          else
            available = [max_lines - 2, 1].max
            activity.last(available).each do |entry|
              lines << "    #{Theme.c(:muted, entry)}"
            end
          end
          lines << ''
          lines
        end

        def render_help_bar(width)
          help = "  #{Theme.c(:muted, 'r')}=refresh  #{Theme.c(:muted, 'q')}=back  " \
                 "#{Theme.c(:muted, 'Ctrl+D')}=dashboard  #{Theme.c(:muted, 'Ctrl+C')}=quit"
          [Theme.c(:muted, '-' * width), help]
        end

        def remaining_height(total, used)
          [total - used - 4, 3].max
        end

        def pad_to_height(rows, height)
          if rows.size < height
            rows + Array.new(height - rows.size, '')
          else
            rows.first(height)
          end
        end

        def probe_services
          require 'socket'
          {
            rabbitmq: { port: 5672, running: port_open?(5672) },
            redis: { port: 6379, running: port_open?(6379) },
            memcached: { port: 11_211, running: port_open?(11_211) },
            vault: { port: 8200, running: port_open?(8200) },
            postgres: { port: 5432, running: port_open?(5432) }
          }
        end

        def port_open?(port)
          ::Socket.tcp('127.0.0.1', port, connect_timeout: 0.5) { true }
        rescue StandardError
          false
        end

        def discover_extensions
          Gem::Specification.select { |s| s.name.start_with?('lex-') }.map(&:name).sort
        rescue StandardError
          []
        end

        def system_info
          {
            ruby_version: RUBY_VERSION,
            os: RUBY_PLATFORM,
            hostname: ::Socket.gethostname,
            pid: ::Process.pid,
            memory: format_memory
          }
        rescue StandardError
          {}
        end

        def format_memory
          if RUBY_PLATFORM.include?('darwin')
            rss = `ps -o rss= -p #{::Process.pid} 2>/dev/null`.strip.to_i
            "#{(rss / 1024.0).round(1)} MB"
          else
            match = `cat /proc/#{::Process.pid}/status 2>/dev/null`.match(/VmRSS:\s+(\d+)/)
            rss_kb = match ? match[1].to_i : 0
            "#{(rss_kb / 1024.0).round(1)} MB"
          end
        rescue StandardError
          'unknown'
        end

        def recent_activity
          log_path = File.expand_path('~/.legionio/logs/tty-boot.log')
          return [] unless File.exist?(log_path)

          File.readlines(log_path, chomp: true).last(20)
        rescue StandardError
          []
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
