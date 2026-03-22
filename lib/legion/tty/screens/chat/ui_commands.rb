# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
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
            'UTILS   : /calc /rand',
            '',
            'Hotkeys: Ctrl+D=dashboard  Ctrl+K=palette  Ctrl+S=sessions  Esc=back'
          ].freeze

          CALC_SAFE_PATTERN = %r{\A[\d\s+\-*/.()%]*\z}
          CALC_MATH_PATTERN = %r{\A[\d\s+\-*/.()%]*(Math\.\w+\([\d\s+\-*/.()%,]*\)[\d\s+\-*/.()%]*)*\z}
          FREQ_STOP_WORDS = %w[
            the a an is are was were be been have has had do does did will would could should
            may might can shall to of in for on with at by from it this that i you we they
            he she my your our their and or but not no if then so as
          ].freeze
          FREQ_ROW_FMT = '  %<rank>2d. %-<word>20s %<count>5d  %<pct>5.1f%%'

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
          rescue LoadError => e
            Legion::Logging.debug("extensions screen not available: #{e.message}") if defined?(Legion::Logging)
            @message_stream.add_message(role: :system, content: 'Extensions screen not available.')
            :handled
          end

          def handle_config_screen
            require_relative '../screens/config'
            screen = Screens::Config.new(@app, output: @output)
            @app.screen_manager.push(screen)
            :handled
          rescue LoadError => e
            Legion::Logging.debug("config screen not available: #{e.message}") if defined?(Legion::Logging)
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

          def handle_truncate(input)
            arg = input.split(nil, 2)[1]&.strip
            if arg.nil?
              status = @message_stream.truncate_limit ? "#{@message_stream.truncate_limit} chars" : 'off'
              @message_stream.add_message(role: :system, content: "Truncation: #{status}")
            elsif arg == 'off'
              @message_stream.truncate_limit = nil
              @message_stream.add_message(role: :system, content: 'Truncation disabled.')
            else
              limit = arg.to_i
              if limit.positive?
                @message_stream.truncate_limit = limit
                @message_stream.add_message(role: :system, content: "Truncation set to #{limit} chars.")
              else
                @message_stream.add_message(role: :system, content: 'Usage: /truncate [N|off]')
              end
            end
            :handled
          end

          def handle_multiline
            @multiline_mode = !@multiline_mode
            if @multiline_mode
              @status_bar.update(multiline: true)
              @message_stream.add_message(role: :system,
                                          content: 'Multi-line mode ON. Submit with empty line.')
            else
              @status_bar.update(multiline: false)
              @message_stream.add_message(role: :system, content: 'Multi-line mode OFF.')
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

          def handle_goto(input)
            n_str = input.split(nil, 2)[1]
            unless n_str&.match?(/\A\d+\z/)
              @message_stream.add_message(role: :system, content: 'Usage: /goto <N>')
              return :handled
            end

            idx = n_str.to_i
            return goto_out_of_range(idx) unless goto_in_range?(idx)

            scroll_to_message(idx)
            @message_stream.add_message(role: :system, content: "Jumped to message #{idx}.")
            :handled
          end

          def goto_in_range?(idx)
            idx >= 0 && idx < @message_stream.messages.size
          end

          def goto_out_of_range(idx)
            total = @message_stream.messages.size
            @message_stream.add_message(role: :system, content: "Message #{idx} out of range (0..#{total - 1}).")
            :handled
          end

          def scroll_to_message(idx)
            total = @message_stream.messages.size
            @message_stream.scroll_down(@message_stream.scroll_offset)
            @message_stream.scroll_up([total - idx - 1, 0].max)
          end

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

          def handle_calc(input)
            expr = input.split(nil, 2)[1]&.strip
            unless expr
              @message_stream.add_message(role: :system, content: 'Usage: /calc <expression>')
              return :handled
            end

            unless safe_calc_expr?(expr)
              @message_stream.add_message(role: :system, content: "Unsafe expression blocked: #{expr}")
              return :handled
            end

            result = binding.send(:eval, expr)
            @message_stream.add_message(role: :system, content: "= #{result}")
            :handled
          rescue SyntaxError, ZeroDivisionError, Math::DomainError => e
            Legion::Logging.warn("handle_calc error: #{e.message}") if defined?(Legion::Logging)
            @message_stream.add_message(role: :system, content: "Error: #{e.message}")
            :handled
          end

          def handle_rand(input)
            arg = input.split(nil, 2)[1]&.strip
            result = parse_rand_arg(arg)
            if result == :invalid
              @message_stream.add_message(role: :system, content: 'Usage: /rand [N|min..max]')
              return :handled
            end

            @message_stream.add_message(role: :system, content: "Random: #{result}")
            :handled
          end

          def parse_rand_arg(arg)
            if arg.nil? || arg.empty?
              rand
            elsif arg.match?(/\A\d+\.\.\d+\z/)
              parts = arg.split('..').map(&:to_i)
              rand(parts[0]..parts[1])
            elsif arg.match?(/\A\d+\z/)
              rand(arg.to_i)
            else
              :invalid
            end
          end

          def handle_wrap(input)
            arg = input.split(nil, 2)[1]&.strip
            if arg.nil?
              status = @message_stream.wrap_width ? "#{@message_stream.wrap_width} columns" : 'off'
              @message_stream.add_message(role: :system, content: "Wrap: #{status}")
            elsif arg == 'off'
              @message_stream.wrap_width = nil
              @message_stream.add_message(role: :system, content: 'Word wrap disabled.')
            else
              n = arg.to_i
              if n >= 20
                @message_stream.wrap_width = n
                @message_stream.add_message(role: :system, content: "Word wrap set to #{n} columns.")
              else
                @message_stream.add_message(role: :system, content: 'Usage: /wrap [N|off]')
              end
            end
            :handled
          end

          def handle_number(input)
            arg = input.split(nil, 2)[1]&.strip
            case arg
            when 'on'
              @message_stream.show_numbers = true
              @message_stream.add_message(role: :system, content: 'Message numbering ON.')
            when 'off'
              @message_stream.show_numbers = false
              @message_stream.add_message(role: :system, content: 'Message numbering OFF.')
            else
              @message_stream.show_numbers = !@message_stream.show_numbers
              state = @message_stream.show_numbers ? 'ON' : 'OFF'
              @message_stream.add_message(role: :system, content: "Message numbering #{state}.")
            end
            :handled
          end

          def safe_calc_expr?(expr)
            CALC_SAFE_PATTERN.match?(expr) || CALC_MATH_PATTERN.match?(expr)
          end

          def handle_echo(input)
            text = input.split(nil, 2)[1]&.strip
            unless text && !text.empty?
              @message_stream.add_message(role: :system, content: 'Usage: /echo <text>')
              return :handled
            end

            @message_stream.add_message(role: :system, content: text)
            :handled
          end

          def handle_env
            width  = terminal_width
            height = terminal_height
            legion_gems = Gem::Specification.select { |s| s.name.start_with?('legion-', 'lex-') }
                                            .map { |s| "#{s.name} #{s.version}" }
                                            .sort
            lines = [
              "Ruby:     #{RUBY_VERSION} (#{RUBY_PLATFORM})",
              "Terminal: #{width}x#{height}",
              "PID:      #{::Process.pid}",
              "TTY:      legion-tty v#{Legion::TTY::VERSION}",
              "Gems (#{legion_gems.size}): #{legion_gems.join(', ')}"
            ]
            @message_stream.add_message(role: :system, content: lines.join("\n"))
            :handled
          end

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          def handle_pipe(input)
            cmd = input.split(nil, 2)[1]
            unless cmd
              @message_stream.add_message(role: :system, content: 'Usage: /pipe <shell command>')
              return :handled
            end

            last_msg = @message_stream.messages.select { |m| m[:role] == :assistant }.last
            unless last_msg
              @message_stream.add_message(role: :system, content: 'No assistant message to pipe.')
              return :handled
            end

            output = pipe_through_command(cmd, last_msg[:content].to_s)
            @message_stream.add_message(role: :system, content: "pipe | #{cmd}:\n#{output}")
            :handled
          rescue StandardError => e
            @message_stream.add_message(role: :system, content: "Pipe error: #{e.message}")
            :handled
          end

          def pipe_through_command(cmd, content)
            result = IO.popen(cmd, 'r+') do |io|
              io.write(content)
              io.close_write
              io.read
            end
            result.to_s.chomp
          rescue StandardError => e
            Legion::Logging.warn("pipe_through_command failed: #{e.message}") if defined?(Legion::Logging)
            raise "command failed: #{e.message}"
          end

          # rubocop:disable Metrics/AbcSize
          def handle_ls(input)
            path = File.expand_path(input.split(nil, 2)[1]&.strip || '.')
            entries = Dir.entries(path).sort.reject { |e| ['.', '..'].include?(e) }
            entries = entries.map { |e| File.directory?(File.join(path, e)) ? "#{e}/" : e }
            @message_stream.add_message(role: :system, content: "#{path}:\n#{entries.join("\n")}")
            :handled
          rescue Errno::ENOENT, Errno::EACCES => e
            Legion::Logging.warn("handle_ls failed: #{e.message}") if defined?(Legion::Logging)
            @message_stream.add_message(role: :system, content: "ls: #{e.message}")
            :handled
          end
          # rubocop:enable Metrics/AbcSize

          def handle_pwd
            @message_stream.add_message(role: :system, content: Dir.pwd)
            :handled
          end

          def handle_silent
            @silent_mode = !@silent_mode
            @message_stream.silent_mode = @silent_mode
            if @silent_mode
              @status_bar.update(silent: true)
              @message_stream.add_message(role: :system, content: 'Silent mode ON -- assistant responses hidden.')
            else
              @status_bar.update(silent: false)
              @message_stream.add_message(role: :system, content: 'Silent mode OFF -- assistant responses visible.')
            end
            :handled
          end

          def handle_color(input)
            arg = input.split(nil, 2)[1]&.strip
            new_state = case arg
                        when 'on'  then true
                        when 'off' then false
                        else            !@message_stream.colorize
                        end
            @message_stream.colorize = new_state
            state_label = new_state ? 'ON' : 'OFF'
            @message_stream.add_message(role: :system, content: "Color output #{state_label}.")
            :handled
          end

          def handle_timestamps(input)
            arg = input.split(nil, 2)[1]&.strip
            new_state = case arg
                        when 'on'  then true
                        when 'off' then false
                        else            !@message_stream.show_timestamps
                        end
            @message_stream.show_timestamps = new_state
            state_label = new_state ? 'ON' : 'OFF'
            @message_stream.add_message(role: :system, content: "Timestamps #{state_label}.")
            :handled
          end

          def handle_top
            @message_stream.scroll_up(@message_stream.messages.size * 5)
            :handled
          end

          def handle_bottom
            @message_stream.scroll_down(@message_stream.scroll_offset)
            :handled
          end

          def handle_about
            lines = [
              'legion-tty',
              'Description : Rich terminal UI for the LegionIO async cognition engine',
              "Version     : #{Legion::TTY::VERSION}",
              'Author      : Matthew Iverson (@Esity)',
              'License     : Apache-2.0',
              'GitHub      : https://github.com/LegionIO/legion-tty'
            ]
            @message_stream.add_message(role: :system, content: lines.join("\n"))
            :handled
          end

          def handle_commands(input)
            pattern = input.split(nil, 2)[1]&.strip&.downcase
            cmds = filter_commands(pattern)
            header = commands_header(pattern, cmds)
            rows = format_command_columns(cmds)
            @message_stream.add_message(role: :system, content: "#{header}\n#{rows.join("\n")}")
            :handled
          end

          def filter_commands(pattern)
            cmds = SLASH_COMMANDS.sort
            return cmds unless pattern && !pattern.empty?

            cmds.select { |c| c.include?(pattern) }
          end

          def commands_header(pattern, cmds)
            if pattern && !pattern.empty?
              "Commands matching '#{pattern}' (#{cmds.size}):"
            else
              "All commands (#{cmds.size}):"
            end
          end

          def format_command_columns(cmds)
            col_width = cmds.map(&:length).max.to_i + 2
            cols = [terminal_width / [col_width, 1].max, 1].max
            cmds.each_slice(cols).map { |row| row.map { |c| c.ljust(col_width) }.join.rstrip }
          end

          def handle_freq
            words = collect_freq_words
            if words.empty?
              @message_stream.add_message(role: :system, content: 'No words to analyse.')
              return :handled
            end

            top = words.tally.sort_by { |_, c| -c }.first(20)
            header = '    #  word                 count      %'
            lines = format_freq_lines(top, words.size)
            @message_stream.add_message(role: :system,
                                        content: "Word frequency (top #{top.size}):\n#{header}\n#{lines.join("\n")}")
            :handled
          end

          def collect_freq_words
            @message_stream.messages
                           .flat_map { |m| m[:content].to_s.downcase.scan(/[a-z']+/) }
                           .reject { |w| FREQ_STOP_WORDS.include?(w) || w.length < 2 }
          end

          def format_freq_lines(top, total)
            top.map.with_index(1) do |(word, count), rank|
              pct = (count.to_f / total * 100).round(1)
              format(FREQ_ROW_FMT, rank: rank, word: word, count: count, pct: pct)
            end
          end

          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          def handle_status
            autosave_val = @autosave_enabled ? "on (every #{@autosave_interval}s)" : 'off'
            filter_val   = @message_stream.filter ? @message_stream.filter[:type].to_s : 'none'
            wrap_val     = @message_stream.wrap_width ? @message_stream.wrap_width.to_s : 'off'
            truncate_val = @message_stream.truncate_limit ? @message_stream.truncate_limit.to_s : 'off'
            tee_val      = @tee_path || 'off'
            lines = [
              'Mode Status:',
              "  Plan mode  : #{@plan_mode ? 'on' : 'off'}",
              "  Focus mode : #{@focus_mode ? 'on' : 'off'}",
              "  Debug mode : #{@debug_mode ? 'on' : 'off'}",
              "  Silent mode: #{@silent_mode ? 'on' : 'off'}",
              "  Mute system: #{@muted_system ? 'on' : 'off'}",
              "  Multi-line : #{@multiline_mode ? 'on' : 'off'}",
              "  Speak mode : #{defined?(@speak_mode) && @speak_mode ? 'on' : 'off'}",
              "  Autosave   : #{autosave_val}",
              "  Color      : #{@message_stream.colorize ? 'on' : 'off'}",
              "  Timestamps : #{@message_stream.show_timestamps ? 'on' : 'off'}",
              "  Numbers    : #{@message_stream.show_numbers ? 'on' : 'off'}",
              "  Wrap       : #{wrap_val}",
              "  Truncate   : #{truncate_val}",
              "  Filter     : #{filter_val}",
              "  Tee        : #{tee_val}",
              "  Theme      : #{Theme.current_theme}",
              "  Personality: #{@personality || 'default'}"
            ]
            @message_stream.add_message(role: :system, content: lines.join("\n"))
            :handled
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          def handle_prefs(input)
            parts = input.split(nil, 3)
            key   = parts[1]
            value = parts[2]
            if key.nil?
              show_all_prefs
            elsif value.nil?
              show_one_pref(key)
            else
              set_pref(key, value)
            end
            :handled
          end

          def prefs_path
            File.expand_path('~/.legionio/prefs.json')
          end

          def load_prefs
            return {} unless File.exist?(prefs_path)

            require 'json'
            ::JSON.parse(File.read(prefs_path))
          rescue ::JSON::ParserError => e
            Legion::Logging.warn("load_prefs failed: #{e.message}") if defined?(Legion::Logging)
            {}
          end

          def save_prefs(prefs)
            require 'fileutils'
            require 'json'
            FileUtils.mkdir_p(File.dirname(prefs_path))
            File.write(prefs_path, ::JSON.pretty_generate(prefs))
          end

          def show_all_prefs
            prefs = load_prefs
            if prefs.empty?
              @message_stream.add_message(role: :system, content: 'No preferences saved.')
            else
              lines = prefs.map { |k, v| "  #{k}: #{v}" }
              @message_stream.add_message(role: :system, content: "Preferences:\n#{lines.join("\n")}")
            end
          end

          def show_one_pref(key)
            val = load_prefs[key]
            if val.nil?
              @message_stream.add_message(role: :system, content: "No preference set for '#{key}'.")
            else
              @message_stream.add_message(role: :system, content: "#{key}: #{val}")
            end
          end

          def set_pref(key, value)
            prefs = load_prefs
            prefs[key] = value
            save_prefs(prefs)
            apply_pref(key, value)
            @message_stream.add_message(role: :system, content: "Preference set: #{key} = #{value}")
          end

          def apply_pref(key, value)
            case key
            when 'theme'       then handle_theme("/theme #{value}")
            when 'personality' then handle_personality("/personality #{value}")
            when 'color'       then handle_color("/color #{value}")
            when 'timestamps'  then handle_timestamps("/timestamps #{value}")
            end
          end

          def handle_stopwatch(input)
            sub = input.split(nil, 2)[1]&.strip
            case sub
            when 'start'  then stopwatch_start
            when 'stop'   then stopwatch_stop
            when 'lap'    then stopwatch_lap
            when 'reset'  then stopwatch_reset
            else               stopwatch_status
            end
            :handled
          end

          def stopwatch_start
            @stopwatch_start = Time.now
            @message_stream.add_message(role: :system, content: 'Stopwatch started.')
          end

          def stopwatch_stop
            unless @stopwatch_start
              @message_stream.add_message(role: :system, content: 'Stopwatch is not running.')
              return
            end

            @stopwatch_elapsed += Time.now - @stopwatch_start
            @stopwatch_start = nil
            @message_stream.add_message(role: :system,
                                        content: "Stopwatch stopped. Elapsed: #{format_stopwatch(@stopwatch_elapsed)}")
          end

          def stopwatch_lap
            total = @stopwatch_elapsed
            total += Time.now - @stopwatch_start if @stopwatch_start
            @message_stream.add_message(role: :system, content: "Lap: #{format_stopwatch(total)}")
          end

          def stopwatch_reset
            @stopwatch_start = nil
            @stopwatch_elapsed = 0
            @message_stream.add_message(role: :system, content: 'Stopwatch reset.')
          end

          def stopwatch_status
            if @stopwatch_start
              total = @stopwatch_elapsed + (Time.now - @stopwatch_start)
              @message_stream.add_message(role: :system, content: "Stopwatch running: #{format_stopwatch(total)}")
            elsif @stopwatch_elapsed.positive?
              @message_stream.add_message(role: :system,
                                          content: "Stopwatch stopped at: #{format_stopwatch(@stopwatch_elapsed)}")
            else
              @message_stream.add_message(role: :system, content: 'Stopwatch: 00:00.000 (not started)')
            end
          end

          def format_stopwatch(seconds)
            total_ms = (seconds * 1000).to_i
            ms   = total_ms % 1000
            secs = (total_ms / 1000) % 60
            mins = total_ms / 60_000
            format('%<mins>02d:%<secs>02d.%<ms>03d', mins: mins, secs: secs, ms: ms)
          end

          def handle_timer(input)
            arg = input.split(nil, 2)[1]&.strip

            return timer_status if arg.nil? || arg.empty?

            return timer_cancel if arg == 'cancel'

            seconds_str, *msg_parts = arg.split
            unless seconds_str.match?(/\A\d+\z/)
              @message_stream.add_message(role: :system, content: 'Usage: /timer <seconds> [message] | cancel')
              return :handled
            end

            seconds = seconds_str.to_i
            message = msg_parts.empty? ? 'Timer expired!' : msg_parts.join(' ')
            start_timer(seconds, message)
          end

          def handle_notify(input)
            text = input.split(nil, 2)[1]&.strip
            unless text && !text.empty?
              @message_stream.add_message(role: :system, content: 'Usage: /notify <message>')
              return :handled
            end

            @status_bar.notify(message: text, level: :info, ttl: 5)
            :handled
          end

          def timer_status
            if @timer_thread&.alive?
              remaining = @timer_end - Time.now
              remaining = [remaining, 0].max.ceil
              @message_stream.add_message(role: :system, content: "Timer running: #{remaining}s remaining.")
            else
              @message_stream.add_message(role: :system, content: 'No active timer.')
            end
            :handled
          end

          def timer_cancel
            if @timer_thread&.alive?
              @timer_thread.kill
              @timer_thread = nil
              @timer_end = nil
              @message_stream.add_message(role: :system, content: 'Timer cancelled.')
            else
              @message_stream.add_message(role: :system, content: 'No active timer to cancel.')
            end
            :handled
          end

          def start_timer(seconds, message)
            if @timer_thread&.alive?
              @message_stream.add_message(role: :system,
                                          content: 'A timer is already running. Use /timer cancel first.')
              return :handled
            end

            @timer_end = Time.now + seconds
            @message_stream.add_message(role: :system, content: "Timer set for #{seconds}s: #{message}")
            @status_bar.notify(message: "Timer: #{seconds}s", level: :info, ttl: 3)
            @timer_thread = Thread.new do
              sleep(seconds)
              @message_stream.add_message(role: :system, content: "Timer: #{message}")
              @status_bar.notify(message: message, level: :info, ttl: 10)
              @timer_thread = nil
              @timer_end = nil
            end
            :handled
          end
        end
      end
    end
  end
end
