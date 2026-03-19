# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        # rubocop:disable Metrics/ModuleLength
        module UiCommands
          private

          # rubocop:disable Metrics/MethodLength
          def handle_help
            @message_stream.add_message(
              role: :system,
              content: "Commands:\n  /help /quit /clear /model <name> /session <name> /cost\n  " \
                       "/export [md|json] /tools /dashboard /hotkeys /save /load /sessions\n  " \
                       "/system <prompt> /delete <session> /plan /palette /extensions /config\n  " \
                       "/theme [name] -- switch color theme (purple, green, blue, amber)\n  " \
                       "/search <text> -- search message history\n  " \
                       "/grep <regex> -- regex search message history\n  " \
                       "/compact [n] -- keep last n message pairs (default 5)\n  " \
                       "/copy -- copy last assistant message to clipboard\n  " \
                       "/diff -- show new messages since session was loaded\n  " \
                       "/stats -- show conversation statistics\n  " \
                       "/personality [name] -- switch assistant personality\n  " \
                       "/undo -- remove last user+assistant message pair\n  " \
                       "/history -- show recent input history\n  " \
                       "/pin [N] -- pin last assistant message (or message at index N)\n  " \
                       "/pins -- show all pinned messages\n  " \
                       "/rename <name> -- rename current session\n  " \
                       "/context -- show active session context summary\n  " \
                       "/alias [shortname /command] -- create or list command aliases\n  " \
                       "/snippet save|load|list|delete <name> -- manage reusable text snippets\n  " \
                       "/debug -- toggle debug mode (shows internal state)\n  " \
                       "/uptime -- show how long this session has been active\n  " \
                       "/time -- show current date, time, and timezone\n  " \
                       "/bookmark -- export pinned messages to a markdown file\n\n" \
                       'Hotkeys: Ctrl+D=dashboard  Ctrl+K=palette  Ctrl+S=sessions  Esc=back'
            )
            :handled
          end
          # rubocop:enable Metrics/MethodLength

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

          def build_stats_lines
            msgs = @message_stream.messages
            counts = count_by_role(msgs)
            total_chars = msgs.sum { |m| m[:content].to_s.length }
            lines = stats_header_lines(msgs, counts, total_chars)
            lines << "  Tool calls: #{counts[:tool]}" if counts[:tool].positive?
            lines
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
        end
        # rubocop:enable Metrics/ModuleLength
      end
    end
  end
end
