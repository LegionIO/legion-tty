# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        # rubocop:disable Metrics/ModuleLength
        module UiCommands
          TIPS = [
            'Press Tab after / to auto-complete commands',
            'Use /alias to create shortcuts (e.g., /alias s /save)',
            'Press Ctrl+K to open the command palette',
            'Use /grep for regex search (e.g., /grep error|warning)',
            'Pin important messages with /pin, export with /bookmark',
            'Use /compact 3 to keep only the last 3 message pairs',
            "Press 'o' in Extensions browser to open gem homepage",
            '/export html creates a styled dark-theme HTML export',
            'Use /snippet save name to save assistant responses for reuse',
            'The dashboard updates every 5 seconds; press r to refresh',
            '/context shows your full session state at a glance',
            'Use /personality technical for code-focused responses',
            '/debug shows internal state counters in the status bar',
            'Navigate dashboard panels with j/k or number keys 1-5',
            'Use /diff to see new messages since a session was loaded'
          ].freeze

          HELP_TEXT = [
            'SESSION : /save /load /sessions /delete /rename',
            'CHAT    : /clear /undo /compact /copy /search /grep /diff /stats',
            'LLM     : /model /system /personality /cost',
            'NAV     : /dashboard /extensions /config /palette /hotkeys',
            'DISPLAY : /theme /plan /debug /context /time /uptime',
            'TOOLS   : /tools /export /bookmark /pin /pins /alias /snippet /history',
            '',
            'Hotkeys: Ctrl+D=dashboard  Ctrl+K=palette  Ctrl+S=sessions  Esc=back'
          ].freeze

          private

          def handle_help
            text = HELP_TEXT.join("\n")
            if @app.respond_to?(:screen_manager) && @app.screen_manager
              @app.screen_manager.show_overlay(text)
            else
              @message_stream.add_message(role: :system, content: text)
            end
            :handled
          end

          def handle_welcome
            cfg = safe_config
            @message_stream.add_message(
              role: :system,
              content: "Welcome#{", #{cfg[:name]}" if cfg[:name]}. Type /help for commands."
            )
            :handled
          end

          def handle_tips
            tip = TIPS.sample
            @message_stream.add_message(role: :system, content: "Tip: #{tip}")
            :handled
          end

          def handle_clear
            @message_stream.messages.clear
            :handled
          end

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

          def handle_extensions_screen
            require_relative '../screens/extensions'
            screen = Screens::Extensions.new(@app, output: @output)
            @app.screen_manager.push(screen)
            :handled
          rescue LoadError
            @message_stream.add_message(role: :system, content: 'Extensions screen not available.')
            :handled
          end

          def handle_config_screen
            require_relative '../screens/config'
            screen = Screens::Config.new(@app, output: @output)
            @app.screen_manager.push(screen)
            :handled
          rescue LoadError
            @message_stream.add_message(role: :system, content: 'Config screen not available.')
            :handled
          end

          def handle_palette
            require_relative '../components/command_palette'
            palette = Components::CommandPalette.new(session_store: @session_store)
            selection = palette.select_with_prompt(output: @output)
            return :handled unless selection

            if selection.start_with?('/')
              handle_slash_command(selection)
            else
              dispatch_screen_by_name(selection)
            end
            :handled
          end

          # rubocop:disable Metrics/AbcSize
          def handle_context
            cfg = safe_config
            model_info = @llm_chat.respond_to?(:model) ? @llm_chat.model.to_s : (cfg[:provider] || 'none')
            sys_prompt = if @llm_chat.respond_to?(:instructions) && @llm_chat.instructions
                           truncate_text(@llm_chat.instructions.to_s, 80)
                         else
                           'default'
                         end
            lines = [
              'Session Context:',
              "  Model/Provider : #{model_info}",
              "  Personality    : #{@personality || 'default'}",
              "  Plan mode      : #{@plan_mode ? 'on' : 'off'}",
              "  System prompt  : #{sys_prompt}",
              "  Session        : #{@session_name}",
              "  Messages       : #{@message_stream.messages.size}",
              "  Pinned         : #{@pinned_messages.size}",
              "  Tokens         : #{@token_tracker.summary}"
            ]
            @message_stream.add_message(role: :system, content: lines.join("\n"))
            :handled
          end
          # rubocop:enable Metrics/AbcSize

          def handle_stats
            @message_stream.add_message(role: :system, content: build_stats_lines.join("\n"))
            :handled
          end

          def handle_debug
            @debug_mode = !@debug_mode
            if @debug_mode
              @status_bar.update(debug_mode: true)
              @message_stream.add_message(role: :system, content: 'Debug mode ON -- internal state shown below.')
            else
              @status_bar.update(debug_mode: false)
              @message_stream.add_message(role: :system, content: 'Debug mode OFF.')
            end
            :handled
          end

          def handle_history
            entries = @input_bar.history
            if entries.empty?
              @message_stream.add_message(role: :system, content: 'No input history.')
            else
              recent = entries.last(20)
              lines = recent.each_with_index.map { |entry, i| "  #{i + 1}. #{entry}" }
              @message_stream.add_message(role: :system,
                                          content: "Input history (last #{recent.size}):\n#{lines.join("\n")}")
            end
            :handled
          end

          def handle_uptime
            elapsed = Time.now - @session_start
            hours   = (elapsed / 3600).to_i
            minutes = ((elapsed % 3600) / 60).to_i
            seconds = (elapsed % 60).to_i
            @message_stream.add_message(role: :system, content: "Session uptime: #{hours}h #{minutes}m #{seconds}s")
            :handled
          end

          def handle_time
            now = Time.now
            tz = now.zone || 'local'
            @message_stream.add_message(
              role: :system,
              content: "Current time: #{now.strftime('%Y-%m-%d %H:%M:%S')} #{tz}"
            )
            :handled
          end

          def dispatch_screen_by_name(name)
            case name
            when 'dashboard' then handle_dashboard
            when 'extensions' then handle_extensions_screen
            when 'config' then handle_config_screen
            end
          end

          def handle_wc
            msgs = @message_stream.messages
            by_role = word_counts_by_role(msgs)
            total = by_role.values.sum
            avg = (total.to_f / [msgs.size, 1].max).round
            @message_stream.add_message(role: :system, content: build_wc_lines(by_role, total, avg).join("\n"))
            :handled
          end

          def word_counts_by_role(msgs)
            %i[user assistant system].to_h do |role|
              words = msgs.select { |m| m[:role] == role }.sum { |m| m[:content].to_s.split.size }
              [role, words]
            end
          end

          def build_wc_lines(by_role, total, avg)
            [
              'Word count:',
              "  Total: #{format_stat_number(total)}",
              "  User: #{format_stat_number(by_role[:user])}",
              "  Assistant: #{format_stat_number(by_role[:assistant])}",
              "  System: #{format_stat_number(by_role[:system])}",
              "  Avg words/message: #{avg}"
            ]
          end

          def handle_mute
            @muted_system = !@muted_system
            @message_stream.mute_system = @muted_system
            if @muted_system
              @status_bar.notify(message: 'System messages hidden', level: :info, ttl: 3)
            else
              @status_bar.notify(message: 'System messages visible', level: :info, ttl: 3)
            end
            :handled
          end

          def build_stats_lines
            msgs = @message_stream.messages
            counts = count_by_role(msgs)
            total_chars = msgs.sum { |m| m[:content].to_s.length }
            lines = stats_header_lines(msgs, counts, total_chars)
            lines << "  Tool calls: #{counts[:tool]}" if counts[:tool].positive?
            append_response_time_stat(lines, msgs)
            lines
          end

          def append_response_time_stat(lines, msgs)
            timed = msgs.select { |m| m[:response_time] }
            return unless timed.any?

            avg_rt = timed.sum { |m| m[:response_time] }.to_f / timed.size
            lines << "  Avg response time: #{avg_rt.round(2)}s (#{timed.size} responses)"
          end

          def count_by_role(msgs)
            %i[user assistant system tool].to_h { |role| [role, msgs.count { |m| m[:role] == role }] }
          end

          def stats_header_lines(msgs, counts, total_chars)
            [
              "Messages: #{msgs.size} total",
              "  User: #{counts[:user]}, Assistant: #{counts[:assistant]}, System: #{counts[:system]}",
              "Characters: #{format_stat_number(total_chars)}",
              "Session: #{@session_name}",
              "Tokens: #{@token_tracker.summary}"
            ]
          end

          def format_stat_number(num)
            num.to_s.chars.reverse.each_slice(3).map(&:join).join(',').reverse
          end

          def handle_log(input)
            n = (input.split(nil, 2)[1] || '20').to_i.clamp(1, 500)
            log_path = File.expand_path('~/.legionio/logs/tty-boot.log')
            unless File.exist?(log_path)
              @message_stream.add_message(role: :system, content: 'No boot log found.')
              return :handled
            end

            lines = File.readlines(log_path, chomp: true).last(n)
            @message_stream.add_message(
              role: :system,
              content: "Boot log (last #{lines.size} lines):\n#{lines.join("\n")}"
            )
            :handled
          end

          def handle_version
            ruby_ver = RUBY_VERSION
            platform = RUBY_PLATFORM
            @message_stream.add_message(
              role: :system,
              content: "legion-tty v#{Legion::TTY::VERSION}\nRuby: #{ruby_ver}\nPlatform: #{platform}"
            )
            :handled
          end

          def handle_focus
            @focus_mode = !@focus_mode
            if @focus_mode
              @status_bar.notify(message: 'Focus mode ON', level: :info, ttl: 2)
            else
              @status_bar.notify(message: 'Focus mode OFF', level: :info, ttl: 2)
            end
            :handled
          end

          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          def handle_scroll(input)
            arg = input.split(nil, 2)[1]
            unless arg
              pos = @message_stream.scroll_position
              @message_stream.add_message(
                role: :system,
                content: "Scroll position: offset=#{pos[:current]}, messages=#{pos[:total]}"
              )
              return :handled
            end

            case arg.strip
            when 'top'
              @message_stream.scroll_up(@message_stream.messages.size * 5)
              @message_stream.add_message(role: :system, content: 'Scrolled to top.')
            when 'bottom'
              @message_stream.scroll_down(@message_stream.scroll_offset)
              @message_stream.add_message(role: :system, content: 'Scrolled to bottom.')
            else
              idx = arg.strip.to_i
              if idx >= 0 && idx < @message_stream.messages.size
                @message_stream.scroll_down(@message_stream.scroll_offset)
                target_offset = [@message_stream.messages.size - idx - 1, 0].max
                @message_stream.scroll_up(target_offset)
                @message_stream.add_message(role: :system, content: "Scrolled to message #{idx}.")
              else
                @message_stream.add_message(
                  role: :system,
                  content: 'Invalid index. Usage: /scroll top|bottom|<N>'
                )
              end
            end
            :handled
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          def handle_highlight(input)
            arg = input.split(nil, 2)[1]
            @highlights ||= []

            unless arg
              @message_stream.add_message(role: :system, content: 'Usage: /highlight <pattern> | clear | list')
              return :handled
            end

            case arg.strip
            when 'clear' then highlight_clear
            when 'list'  then highlight_list
            else              highlight_add(arg.strip)
            end
            :handled
          end

          def highlight_clear
            @highlights = []
            @message_stream.highlights = @highlights
            @message_stream.add_message(role: :system, content: 'Highlights cleared.')
          end

          def highlight_list
            if @highlights.empty?
              @message_stream.add_message(role: :system, content: 'No active highlights.')
            else
              lines = @highlights.each_with_index.map { |p, i| "  #{i + 1}. #{p}" }
              @message_stream.add_message(role: :system,
                                          content: "Active highlights (#{@highlights.size}):\n#{lines.join("\n")}")
            end
          end

          def highlight_add(pattern)
            @highlights << pattern
            @message_stream.highlights = @highlights
            @message_stream.add_message(role: :system, content: "Highlight added: '#{pattern}'")
          end

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          def handle_summary
            msgs = @message_stream.messages
            elapsed = Time.now - @session_start
            hours   = (elapsed / 3600).to_i
            minutes = ((elapsed % 3600) / 60).to_i
            seconds = (elapsed % 60).to_i
            uptime_str = "#{hours}h #{minutes}m #{seconds}s"

            counts = %i[user assistant system].to_h { |r| [r, msgs.count { |m| m[:role] == r }] }
            most_active = counts.max_by { |_, v| v }&.first || :none

            user_msgs = msgs.select { |m| m[:role] == :user }
            top_words = user_msgs.flat_map { |m| m[:content].to_s.split.first(1) }
                                 .tally.sort_by { |_, c| -c }.first(5).map(&:first)

            longest = msgs.max_by { |m| m[:content].to_s.length }
            longest_preview = longest ? truncate_text(longest[:content].to_s, 60) : 'none'

            last_user = user_msgs.last
            recent_topic = last_user ? truncate_text(last_user[:content].to_s, 40) : 'none'

            lines = [
              'Conversation Summary',
              "  Messages: #{msgs.size}, Duration: #{uptime_str}",
              "  Most active role: #{most_active}",
              "  Top starting words: #{top_words.empty? ? 'none' : top_words.join(', ')}",
              "  Longest message: #{longest_preview}",
              "  Most recent topic: #{recent_topic}"
            ]
            @message_stream.add_message(role: :system, content: lines.join("\n"))
            :handled
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        end
        # rubocop:enable Metrics/ModuleLength
      end
    end
  end
end
