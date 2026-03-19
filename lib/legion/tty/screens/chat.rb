# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../components/message_stream'
require_relative '../components/status_bar'
require_relative '../components/input_bar'
require_relative '../components/token_tracker'
require_relative '../theme'
require_relative 'chat/session_commands'
require_relative 'chat/export_commands'
require_relative 'chat/message_commands'
require_relative 'chat/ui_commands'
require_relative 'chat/model_commands'
require_relative 'chat/custom_commands'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Chat < Base
        include SessionCommands
        include ExportCommands
        include MessageCommands
        include UiCommands
        include ModelCommands
        include CustomCommands

        SLASH_COMMANDS = %w[/help /quit /clear /compact /copy /diff /model /session /cost /export /tools /dashboard
                            /hotkeys /save /load /sessions /system /delete /plan /palette /extensions /config
                            /theme /search /grep /stats /personality /undo /history /pin /pins /rename
                            /context /alias /snippet /debug /uptime /time /bookmark /welcome /tips
                            /wc /import /mute /autosave /react /macro /tag /tags /repeat /count
                            /template /fav /favs /log /version].freeze

        PERSONALITIES = {
          'default' => 'You are Legion, an async cognition engine and AI assistant. Be helpful and concise.',
          'concise' => 'You are Legion. Respond in as few words as possible. No filler.',
          'detailed' => 'You are Legion. Provide thorough, detailed explanations with examples when helpful.',
          'friendly' => 'You are Legion, a friendly AI companion. Use a warm, conversational tone.',
          'technical' => 'You are Legion, a senior engineer. Use precise technical language. Include code examples.'
        }.freeze

        attr_reader :message_stream, :status_bar

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
          @plan_mode = false
          @pinned_messages = []
          @aliases = {}
          @snippets = {}
          @macros = {}
          @debug_mode = false
          @session_start = Time.now
          @muted_system = false
          @autosave_enabled = false
          @autosave_interval = 60
          @last_autosave = Time.now
          @recording_macro = nil
          @macro_buffer = []
          @last_command = nil
        end

        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def activate
          @running = true
          cfg = safe_config
          @status_bar.update(model: cfg[:provider], session: 'default')
          setup_system_prompt
          @message_stream.add_message(
            role: :system,
            content: "Welcome#{", #{cfg[:name]}" if cfg[:name]}. Type /help for commands."
          )
          @status_bar.update(message_count: @message_stream.messages.size)
        end

        def running?
          @running
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def run
          activate
          while @running
            render_screen
            input = read_input
            break if input.nil?

            if @app.respond_to?(:screen_manager) && @app.screen_manager.overlay
              @app.screen_manager.dismiss_overlay
              next
            end

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
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def handle_slash_command(input)
          return nil unless input.start_with?('/')

          cmd = input.split.first
          unless SLASH_COMMANDS.include?(cmd)
            expanded = @aliases[cmd]
            return nil unless expanded

            return handle_slash_command("#{expanded} #{input.split(nil, 2)[1]}".strip)
          end

          result = dispatch_slash(cmd, input)
          @last_command = input if cmd != '/repeat'
          record_macro_step(input, cmd, result)
          result
        end

        def handle_user_message(input)
          @message_stream.add_message(role: :user, content: input)
          if @plan_mode
            @message_stream.add_message(role: :system, content: '(bookmarked)')
          else
            @message_stream.add_message(role: :assistant, content: '')
            send_to_llm(input)
          end
          @status_bar.update(message_count: @message_stream.messages.size)
          check_autosave
          render_screen
        end

        def send_to_llm(message)
          unless @llm_chat || daemon_available?
            @message_stream.append_streaming('LLM not configured. Use /help for commands.')
            return
          end

          if daemon_available?
            send_via_daemon(message)
          else
            send_via_direct(message)
          end
        rescue StandardError => e
          @status_bar.update(thinking: false)
          @message_stream.append_streaming("\n[Error: #{e.message}]")
        end

        def render(width, height)
          bar_line = @status_bar.render(width: width)
          divider = Theme.c(:muted, '-' * width)
          dbg = debug_segment
          extra_rows = dbg ? 1 : 0
          stream_height = [height - 2 - extra_rows, 1].max
          stream_lines = @message_stream.render(width: width, height: stream_height)
          @status_bar.update(scroll: @message_stream.scroll_position)
          lines = stream_lines + [divider, bar_line]
          lines << dbg if dbg
          lines
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

        def record_macro_step(input, cmd, result)
          return unless @recording_macro
          return if cmd == '/macro'
          return unless result == :handled

          @macro_buffer << input
        end

        def setup_system_prompt
          cfg = safe_config
          return unless @llm_chat && cfg.is_a?(Hash) && !cfg.empty?

          prompt = build_system_prompt(cfg)
          @llm_chat.with_instructions(prompt) if @llm_chat.respond_to?(:with_instructions)
        end

        def send_via_daemon(message)
          result = Legion::LLM.ask(message: message)

          case result&.dig(:status)
          when :done
            @message_stream.append_streaming(result[:response])
          when :error
            err = result.dig(:error, :message) || 'Unknown error'
            @message_stream.append_streaming("\n[Daemon error: #{err}]")
          else
            send_via_direct(message)
          end
        rescue StandardError
          send_via_direct(message)
        end

        def send_via_direct(message)
          return unless @llm_chat

          @status_bar.update(thinking: true)
          render_screen
          start_time = Time.now
          response = @llm_chat.ask(message) do |chunk|
            @status_bar.update(thinking: false)
            @message_stream.append_streaming(chunk.content) if chunk.content
            render_screen
          end
          record_response_time(Time.now - start_time)
          @status_bar.update(thinking: false)
          track_response_tokens(response)
        end

        def record_response_time(elapsed)
          @last_response_time = elapsed
          @message_stream.messages.last[:response_time] = elapsed if @message_stream.messages.last
          @status_bar.notify(message: "Response: #{elapsed.round(1)}s", level: :info, ttl: 4)
        end

        def daemon_available?
          !!(defined?(Legion::LLM::DaemonClient) && Legion::LLM::DaemonClient.available?)
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
          render_overlay if @app.respond_to?(:screen_manager) && @app.screen_manager.overlay
        end

        # rubocop:disable Metrics/AbcSize
        def render_overlay
          require 'tty-box'
          text = @app.screen_manager.overlay.to_s
          width = (terminal_width - 4).clamp(40, terminal_width)
          box = ::TTY::Box.frame(
            width: width,
            padding: 1,
            title: { top_left: ' Help ' },
            border: :round
          ) { text }
          overlay_lines = box.split("\n")
          start_row = [(terminal_height - overlay_lines.size) / 2, 0].max
          overlay_lines.each_with_index do |line, i|
            @output.print ::TTY::Cursor.move_to(2, start_row + i)
            @output.print line
          end
        rescue StandardError
          nil
        end
        # rubocop:enable Metrics/AbcSize

        def read_input
          return nil unless @input_bar.respond_to?(:read_line)

          @input_bar.read_line
        rescue Interrupt
          nil
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        def dispatch_slash(cmd, input)
          case cmd
          when '/quit' then :quit
          when '/help' then handle_help
          when '/clear' then handle_clear
          when '/compact' then handle_compact(input)
          when '/copy' then handle_copy(input)
          when '/diff' then handle_diff(input)
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
          when '/system' then handle_system(input)
          when '/delete' then handle_delete(input)
          when '/plan' then handle_plan
          when '/palette' then handle_palette
          when '/extensions' then handle_extensions_screen
          when '/config' then handle_config_screen
          when '/theme' then handle_theme(input)
          when '/search' then handle_search(input)
          when '/grep' then handle_grep(input)
          when '/stats' then handle_stats
          when '/personality' then handle_personality(input)
          when '/undo' then handle_undo
          when '/history' then handle_history
          when '/pin' then handle_pin(input)
          when '/pins' then handle_pins
          when '/rename' then handle_rename(input)
          when '/context' then handle_context
          when '/alias' then handle_alias(input)
          when '/snippet' then handle_snippet(input)
          when '/debug' then handle_debug
          when '/uptime' then handle_uptime
          when '/time' then handle_time
          when '/bookmark' then handle_bookmark
          when '/welcome' then handle_welcome
          when '/tips' then handle_tips
          when '/wc' then handle_wc
          when '/import' then handle_import(input)
          when '/mute' then handle_mute
          when '/autosave' then handle_autosave(input)
          when '/react' then handle_react(input)
          when '/macro' then handle_macro(input)
          when '/tag' then handle_tag(input)
          when '/tags' then handle_tags(input)
          when '/repeat' then handle_repeat
          when '/count' then handle_count(input)
          when '/template' then handle_template(input)
          when '/fav' then handle_fav(input)
          when '/favs' then handle_favs
          when '/log' then handle_log(input)
          when '/version' then handle_version
          else :handled
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

        def handle_repeat
          unless @last_command
            @message_stream.add_message(role: :system, content: 'No previous command to repeat.')
            return :handled
          end

          dispatch_slash(@last_command.split.first, @last_command)
        end

        def handle_cost
          @message_stream.add_message(role: :system, content: @token_tracker.summary)
          :handled
        end

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

        def handle_plan
          @plan_mode = !@plan_mode
          if @plan_mode
            @status_bar.update(plan_mode: true)
            @message_stream.add_message(role: :system,
                                        content: 'Plan mode ON -- messages are bookmarked, not sent to LLM.')
          else
            @status_bar.update(plan_mode: false)
            @message_stream.add_message(role: :system, content: 'Plan mode OFF -- messages sent to LLM.')
          end
          :handled
        end

        def handle_session(input)
          name = input.split(nil, 2)[1]
          if name
            @session_name = name
            @status_bar.update(session: name)
          end
          :handled
        end

        def handle_theme(input)
          name = input.split(nil, 2)[1]
          if name
            if Theme.switch(name)
              @status_bar.notify(message: "Theme: #{name}", level: :info, ttl: 2)
              @message_stream.add_message(role: :system, content: "Theme switched to: #{name}")
            else
              available = Theme.available_themes.join(', ')
              @message_stream.add_message(role: :system, content: "Unknown theme '#{name}'. Available: #{available}")
            end
          else
            current = Theme.current_theme
            available = Theme.available_themes.join(', ')
            @message_stream.add_message(role: :system, content: "Current theme: #{current}\nAvailable: #{available}")
          end
          :handled
        end

        def debug_segment
          return nil unless @debug_mode

          "[DEBUG] msgs:#{@message_stream.messages.size} " \
            "scroll:#{@message_stream.scroll_position&.dig(:current) || 0} " \
            "plan:#{@plan_mode} " \
            "personality:#{@personality || 'default'} " \
            "aliases:#{@aliases.size} " \
            "snippets:#{@snippets.size} " \
            "macros:#{@macros.size} " \
            "pinned:#{@pinned_messages.size} " \
            "autosave:#{@autosave_enabled}"
        end

        def build_default_input_bar
          cfg = safe_config
          name = cfg[:name] || 'User'
          Components::InputBar.new(name: name, completions: SLASH_COMMANDS)
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

        def detect_provider
          cfg = safe_config
          provider = cfg[:provider].to_s.downcase
          return provider if Components::TokenTracker::PROVIDER_PRICING.key?(provider)

          'claude'
        end

        def track_response_tokens(response)
          return unless response.respond_to?(:input_tokens)

          model_id = response.respond_to?(:model) ? response.model.to_s : nil
          @token_tracker.track(
            input_tokens: response.input_tokens.to_i,
            output_tokens: response.output_tokens.to_i,
            model: model_id
          )
          @status_bar.update(
            tokens: @token_tracker.total_input_tokens + @token_tracker.total_output_tokens,
            cost: @token_tracker.total_cost
          )
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
