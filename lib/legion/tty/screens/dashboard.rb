# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Dashboard < Base
        PANELS = %i[services llm extensions system activity].freeze

        def initialize(app)
          super
          @last_refresh = nil
          @refresh_interval = 5
          @cached_data = {}
          @selected_panel = 0
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
          rows.concat(render_llm_panel(width))
          rows.concat(render_extensions_panel(width))
          rows.concat(render_system_panel(width))
          rows.concat(render_activity_panel(width, remaining_height(height, rows.size)))
          rows.concat(render_help_bar(width))

          pad_to_height(rows, height)
        end

        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/CyclomaticComplexity
        def handle_input(key)
          case key
          when 'r', :f5
            refresh_data
            :handled
          when 'q', :escape
            :pop_screen
          when 'j', :down
            @selected_panel = (@selected_panel + 1) % PANELS.size
            :handled
          when 'k', :up
            @selected_panel = (@selected_panel - 1) % PANELS.size
            :handled
          when '1' then navigate_to_panel(0)
          when '2' then navigate_to_panel(1)
          when '3' then navigate_to_panel(2)
          when '4' then navigate_to_panel(3)
          when '5' then navigate_to_panel(4)
          when 'e'
            extensions_shortcut
          else
            :pass
          end
        end

        # rubocop:enable Metrics/CyclomaticComplexity

        def selected_panel
          PANELS[@selected_panel]
        end

        def refresh_data
          @last_refresh = Time.now
          @cached_data = {
            services: probe_services,
            llm: llm_info,
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
          prefix = panel_prefix(:services)
          lines = [Theme.c(:accent, "#{prefix}Services")]
          services.each do |name, info|
            icon = info[:running] ? Theme.c(:success, "\u2713") : Theme.c(:error, "\u2717")
            port_str = Theme.c(:muted, ":#{info[:port]}")
            lines << "    #{icon} #{name} #{port_str}"
          end
          lines << ''
          lines
        end

        # rubocop:disable Metrics/AbcSize
        def render_llm_panel(_width)
          llm = @cached_data[:llm] || {}
          prefix = panel_prefix(:llm)
          lines = [Theme.c(:accent, "#{prefix}LLM")]
          started_icon = llm[:started] ? Theme.c(:success, "\u2713") : Theme.c(:error, "\u2717")
          daemon_icon  = llm[:daemon]  ? Theme.c(:success, "\u2713") : Theme.c(:error, "\u2717")
          lines << "    #{started_icon} Legion::LLM started"
          lines << "    #{daemon_icon} Daemon available"
          lines << "    Provider: #{Theme.c(:secondary, llm[:provider] || 'none')}"
          lines << "    Model:    #{Theme.c(:secondary, llm[:model] || 'none')}" if llm[:model]
          lines << ''
          lines
        end

        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def render_extensions_panel(_width)
          extensions = @cached_data[:extensions] || []
          count = extensions.size
          prefix = panel_prefix(:extensions)
          lines = [Theme.c(:accent, "#{prefix}Extensions (#{count})")]
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

        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def render_system_panel(_width)
          sys = @cached_data[:system] || {}
          prefix = panel_prefix(:system)
          lines = [Theme.c(:accent, "#{prefix}System")]
          lines << "    Ruby:     #{Theme.c(:secondary, sys[:ruby_version] || 'unknown')}"
          lines << "    OS:       #{Theme.c(:secondary, sys[:os] || 'unknown')}"
          lines << "    Host:     #{Theme.c(:secondary, sys[:hostname] || 'unknown')}"
          lines << "    PID:      #{Theme.c(:secondary, sys[:pid]&.to_s || 'unknown')}"
          lines << "    Memory:   #{Theme.c(:secondary, sys[:memory] || 'unknown')}"
          lines << ''
          lines
        end

        # rubocop:enable Metrics/AbcSize

        def render_activity_panel(_width, max_lines)
          activity = @cached_data[:activity] || []
          prefix = panel_prefix(:activity)
          lines = [Theme.c(:accent, "#{prefix}Recent Activity")]
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
                 "#{Theme.c(:muted, 'j/k')}=navigate  #{Theme.c(:muted, '1-5')}=jump  " \
                 "#{Theme.c(:muted, 'e')}=extensions  #{Theme.c(:muted, 'Ctrl+C')}=quit"
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

        def panel_prefix(panel_name)
          PANELS[@selected_panel] == panel_name ? '>> ' : '  '
        end

        def navigate_to_panel(index)
          @selected_panel = index
          :handled
        end

        def extensions_shortcut
          if PANELS[@selected_panel] == :extensions && @app.respond_to?(:screen_manager)
            require_relative '../screens/extensions'
            @app.screen_manager.push(Screens::Extensions.new(@app))
            :handled
          else
            :pass
          end
        rescue LoadError, StandardError => e
          Legion::Logging.debug("extensions_shortcut failed: #{e.message}") if defined?(Legion::Logging)
          :pass
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        def llm_info
          info = { provider: 'none', model: nil, started: false, daemon: false }
          if defined?(Legion::LLM)
            info[:started] = Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
            settings = Legion::LLM.respond_to?(:settings) ? Legion::LLM.settings : {}
            info[:provider] = settings[:default_provider]&.to_s || 'none'
            info[:model] = settings[:model]&.to_s
          end
          if defined?(Legion::LLM::DaemonClient)
            info[:daemon] = Legion::LLM::DaemonClient.respond_to?(:available?) &&
                            Legion::LLM::DaemonClient.available?
          end
          info
        rescue StandardError => e
          Legion::Logging.warn("llm_info failed: #{e.message}") if defined?(Legion::Logging)
          info
        end

        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

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
        rescue StandardError => e
          Legion::Logging.debug("port_open? #{port} failed: #{e.message}") if defined?(Legion::Logging)
          false
        end

        def discover_extensions
          Gem::Specification.select { |s| s.name.start_with?('lex-') }.map(&:name).sort
        rescue StandardError => e
          Legion::Logging.warn("discover_extensions failed: #{e.message}") if defined?(Legion::Logging)
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
        rescue StandardError => e
          Legion::Logging.warn("system_info failed: #{e.message}") if defined?(Legion::Logging)
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
        rescue StandardError => e
          Legion::Logging.debug("format_memory failed: #{e.message}") if defined?(Legion::Logging)
          'unknown'
        end

        def recent_activity
          log_path = File.expand_path('~/.legionio/logs/tty-boot.log')
          return [] unless File.exist?(log_path)

          File.readlines(log_path, chomp: true).last(20)
        rescue StandardError => e
          Legion::Logging.warn("recent_activity failed: #{e.message}") if defined?(Legion::Logging)
          []
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
