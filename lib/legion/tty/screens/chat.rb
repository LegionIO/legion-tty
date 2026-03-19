# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../components/message_stream'
require_relative '../components/status_bar'
require_relative '../components/input_bar'
require_relative '../components/token_tracker'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Chat < Base
        SLASH_COMMANDS = %w[/help /quit /clear /model /session /cost /export /tools /dashboard /hotkeys /save /load
                            /sessions].freeze

        attr_reader :message_stream, :status_bar

        def initialize(app, output: $stdout, input_bar: nil)
          super(app)
          @output = output
          @message_stream = Components::MessageStream.new
          @status_bar = Components::StatusBar.new
          @running = false
          @input_bar = input_bar || build_default_input_bar
          @llm_chat = app.respond_to?(:llm_chat) ? app.llm_chat : nil
          @token_tracker = Components::TokenTracker.new(provider: detect_provider)
          @session_store = SessionStore.new
          @session_name = 'default'
        end

        def activate
          @running = true
          cfg = safe_config
          @status_bar.update(model: cfg[:provider], session: 'default')
          setup_system_prompt
          @message_stream.add_message(
            role: :system,
            content: "Welcome#{", #{cfg[:name]}" if cfg[:name]}. Type /help for commands."
          )
        end

        def running?
          @running
        end

        def run
          activate
          while @running
            render_screen
            input = read_input
            break if input.nil?

            result = handle_slash_command(input)
            if result == :quit
              auto_save_session
              @running = false
              break
            elsif result.nil?
              handle_user_message(input) unless input.strip.empty?
            end
          end
        end

        def handle_slash_command(input)
          return nil unless input.start_with?('/')

          cmd = input.split.first
          return nil unless SLASH_COMMANDS.include?(cmd)

          dispatch_slash(cmd, input)
        end

        def handle_user_message(input)
          @message_stream.add_message(role: :user, content: input)
          @message_stream.add_message(role: :assistant, content: '')
          send_to_llm(input)
          render_screen
        end

        def send_to_llm(message)
          unless @llm_chat
            @message_stream.append_streaming(
              'LLM not configured. Use /help for commands.'
            )
            return
          end

          response = @llm_chat.ask(message) do |chunk|
            @message_stream.append_streaming(chunk.content) if chunk.content
            render_screen
          end
          track_response_tokens(response)
        rescue StandardError => e
          @message_stream.append_streaming("\n[Error: #{e.message}]")
        end

        def render(width, height)
          bar_line = @status_bar.render(width: width)
          divider = Theme.c(:muted, '-' * width)
          stream_height = [height - 2, 1].max
          stream_lines = @message_stream.render(width: width, height: stream_height)
          stream_lines + [divider, bar_line]
        end

        def handle_input(key)
          case key
          when :up
            @message_stream.scroll_up
            :handled
          when :down
            @message_stream.scroll_down
            :handled
          else
            :pass
          end
        end

        private

        def setup_system_prompt
          cfg = safe_config
          return unless @llm_chat && cfg.is_a?(Hash) && !cfg.empty?

          prompt = build_system_prompt(cfg)
          @llm_chat.with_instructions(prompt) if @llm_chat.respond_to?(:with_instructions)
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        def build_system_prompt(cfg)
          lines = ['You are Legion, an async cognition engine and AI assistant.']
          lines << "The user's name is #{cfg[:name]}." if cfg[:name]

          krb = cfg[:kerberos]
          if krb.is_a?(Hash)
            lines << "User identity: #{krb[:display_name]} (#{krb[:principal]})" if krb[:display_name]
            lines << "Title: #{krb[:title]}" if krb[:title]
            lines << "Department: #{krb[:department]}, Company: #{krb[:company]}" if krb[:department]
            lines << "Location: #{[krb[:city], krb[:state]].compact.join(', ')}" if krb[:city]
          end

          gh = cfg[:github]
          if gh.is_a?(Hash) && gh[:username]
            lines << "GitHub: #{gh[:username]}"
            profile = gh[:profile]
            if profile.is_a?(Hash) && profile[:public_repos]
              lines << "GitHub repos: #{profile[:public_repos]} public, #{profile[:private_repos]} private"
            end
            orgs = gh[:orgs]
            lines << "GitHub orgs: #{orgs.map { |o| o[:login] }.join(', ')}" if orgs.is_a?(Array) && !orgs.empty?
          end

          env = cfg[:environment]
          if env.is_a?(Hash)
            lines << "Running services: #{env[:running_services].join(', ')}" if env[:running_services]&.any?
            lines << "Repos: #{env[:repos_count]}" if env[:repos_count]
            lines << "Top languages: #{env[:top_languages].keys.join(', ')}" if env[:top_languages]&.any?
          end

          lines.join("\n")
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

        def safe_config
          return {} unless @app.respond_to?(:config)

          cfg = @app.config
          cfg.is_a?(Hash) ? cfg : {}
        end

        def render_screen
          require 'tty-cursor'
          lines = render(terminal_width, terminal_height - 1)
          @output.print ::TTY::Cursor.move_to(0, 0)
          @output.print ::TTY::Cursor.clear_screen_down
          lines.each { |line| @output.puts line }
        end

        def read_input
          return nil unless @input_bar.respond_to?(:read_line)

          @input_bar.read_line
        rescue Interrupt
          nil
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        def dispatch_slash(cmd, input)
          case cmd
          when '/quit' then :quit
          when '/help' then handle_help
          when '/clear' then handle_clear
          when '/model' then handle_model(input)
          when '/session' then handle_session(input)
          when '/cost' then handle_cost
          when '/export' then handle_export(input)
          when '/tools' then handle_tools
          when '/save' then handle_save(input)
          when '/load' then handle_load(input)
          when '/sessions' then handle_sessions
          when '/dashboard' then handle_dashboard
          when '/hotkeys' then handle_hotkeys
          else :handled
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        def handle_help
          @message_stream.add_message(
            role: :system,
            content: "Commands: /help /quit /clear /model <name> /session <name> /cost\n  " \
                     '/export [md|json] /tools /dashboard /hotkeys /save /load /sessions'
          )
          :handled
        end

        def handle_clear
          @message_stream.messages.clear
          :handled
        end

        def handle_model(input)
          name = input.split(nil, 2)[1]
          if name
            switch_model(name)
          else
            show_current_model
          end
          :handled
        end

        def switch_model(name)
          unless @llm_chat
            @message_stream.add_message(role: :system, content: 'No active LLM session.')
            return
          end

          if @llm_chat.respond_to?(:with_model)
            @llm_chat.with_model(name)
            @status_bar.update(model: name)
            @message_stream.add_message(role: :system, content: "Model switched to: #{name}")
          else
            @status_bar.update(model: name)
            @message_stream.add_message(role: :system, content: "Model set to: #{name}")
          end
        rescue StandardError => e
          @message_stream.add_message(role: :system, content: "Failed to switch model: #{e.message}")
        end

        def show_current_model
          model = @llm_chat.respond_to?(:model) ? @llm_chat.model : nil
          provider = safe_config[:provider] || 'unknown'
          info = model ? "#{model} (#{provider})" : provider
          @message_stream.add_message(role: :system, content: "Current model: #{info}")
        end

        def handle_session(input)
          name = input.split(nil, 2)[1]
          if name
            @session_name = name
            @status_bar.update(session: name)
          end
          :handled
        end

        def handle_save(input)
          name = input.split(nil, 2)[1] || @session_store.auto_session_name
          @session_name = name
          @session_store.save(name, messages: @message_stream.messages)
          @status_bar.update(session: name)
          @message_stream.add_message(role: :system, content: "Session saved as '#{name}'.")
          :handled
        end

        def handle_load(input)
          name = input.split(nil, 2)[1]
          unless name
            @message_stream.add_message(role: :system, content: 'Usage: /load <session-name>')
            return :handled
          end
          data = @session_store.load(name)
          unless data
            @message_stream.add_message(role: :system, content: "Session '#{name}' not found.")
            return :handled
          end
          @message_stream.messages.replace(data[:messages])
          @session_name = name
          @status_bar.update(session: name)
          @message_stream.add_message(role: :system,
                                      content: "Session '#{name}' loaded (#{data[:messages].size} messages).")
          :handled
        end

        def handle_sessions
          sessions = @session_store.list
          if sessions.empty?
            @message_stream.add_message(role: :system, content: 'No saved sessions.')
          else
            lines = sessions.map { |s| "  #{s[:name]} - #{s[:message_count]} messages (#{s[:saved_at]})" }
            @message_stream.add_message(role: :system, content: "Saved sessions:\n#{lines.join("\n")}")
          end
          :handled
        end

        def auto_save_session
          return if @message_stream.messages.empty?

          @session_store.save(@session_name, messages: @message_stream.messages)
        rescue StandardError
          nil
        end

        def handle_cost
          @message_stream.add_message(role: :system, content: @token_tracker.summary)
          :handled
        end

        # rubocop:disable Metrics/AbcSize
        def handle_export(input)
          require 'fileutils'
          format = input.split[1]&.downcase
          format = 'md' unless %w[json md].include?(format)
          exports_dir = File.expand_path('~/.legionio/exports')
          FileUtils.mkdir_p(exports_dir)
          timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
          path = File.join(exports_dir, "chat-#{timestamp}.#{format == 'json' ? 'json' : 'md'}")
          if format == 'json'
            export_json(path)
          else
            export_markdown(path)
          end
          @message_stream.add_message(role: :system, content: "Exported to: #{path}")
          :handled
        rescue StandardError => e
          @message_stream.add_message(role: :system, content: "Export failed: #{e.message}")
          :handled
        end

        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def handle_tools
          lex_gems = Gem::Specification.select { |s| s.name.start_with?('lex-') }
          if lex_gems.empty?
            @message_stream.add_message(role: :system, content: 'No lex-* extensions found in loaded gems.')
          else
            lines = lex_gems.map do |spec|
              loaded = $LOADED_FEATURES.any? { |f| f.include?(spec.name.tr('-', '/')) }
              status = loaded ? '[loaded]' : '[available]'
              "  #{spec.name} #{spec.version} #{status}"
            end
            @message_stream.add_message(role: :system,
                                        content: "LEX Extensions (#{lex_gems.size}):\n#{lines.join("\n")}")
          end
          :handled
        end

        # rubocop:enable Metrics/AbcSize

        def handle_dashboard
          if @app.respond_to?(:toggle_dashboard)
            @app.toggle_dashboard
          else
            @message_stream.add_message(role: :system, content: 'Dashboard not available.')
          end
          :handled
        end

        def handle_hotkeys
          if @app.respond_to?(:hotkeys)
            bindings = @app.hotkeys.list
            lines = bindings.map { |b| "#{b[:key].inspect} -> #{b[:description]}" }
            text = lines.empty? ? 'No hotkeys registered.' : lines.join("\n")
            @message_stream.add_message(role: :system, content: "Hotkeys:\n#{text}")
          else
            @message_stream.add_message(role: :system, content: 'Hotkeys not available.')
          end
          :handled
        end

        def detect_provider
          cfg = safe_config
          provider = cfg[:provider].to_s.downcase
          return provider if Components::TokenTracker::PRICING.key?(provider)

          'claude'
        end

        def track_response_tokens(response)
          return unless response.respond_to?(:input_tokens)

          @token_tracker.track(
            input_tokens: response.input_tokens.to_i,
            output_tokens: response.output_tokens.to_i
          )
          @status_bar.update(
            tokens: @token_tracker.total_input_tokens + @token_tracker.total_output_tokens,
            cost: @token_tracker.total_cost
          )
        end

        def export_markdown(path)
          lines = ["# Chat Export\n", "_Exported: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}_\n\n---\n"]
          @message_stream.messages.each do |msg|
            role_label = msg[:role].to_s.capitalize
            lines << "\n**#{role_label}**\n\n#{msg[:content]}\n"
          end
          File.write(path, lines.join)
        end

        def export_json(path)
          require 'json'
          data = {
            exported_at: Time.now.iso8601,
            token_summary: @token_tracker.summary,
            messages: @message_stream.messages.map { |m| { role: m[:role].to_s, content: m[:content] } }
          }
          File.write(path, ::JSON.pretty_generate(data))
        end

        def build_default_input_bar
          cfg = safe_config
          name = cfg[:name] || 'User'
          Components::InputBar.new(name: name)
        end

        def terminal_width
          require 'tty-screen'
          ::TTY::Screen.width
        rescue StandardError
          80
        end

        def terminal_height
          require 'tty-screen'
          ::TTY::Screen.height
        rescue StandardError
          24
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
