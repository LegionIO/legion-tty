# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
        # rubocop:disable Metrics/ModuleLength
        module SessionCommands
          private

          def handle_save(input)
            name = input.split(nil, 2)[1] || @session_store.auto_session_name
            @session_name = name
            @session_store.save(name, messages: @message_stream.messages)
            @status_bar.update(session: name)
            @status_bar.notify(message: "Saved '#{name}'", level: :success, ttl: 3)
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
            @loaded_message_count = @message_stream.messages.size
            @session_name = name
            @status_bar.update(session: name)
            @status_bar.notify(message: "Loaded '#{name}'", level: :info, ttl: 3)
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

          def handle_delete(input)
            name = input.split(nil, 2)[1]
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /delete <session-name>')
              return :handled
            end
            @session_store.delete(name)
            @message_stream.add_message(role: :system, content: "Session '#{name}' deleted.")
            :handled
          end

          def handle_rename(input)
            name = input.split(nil, 2)[1]
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /rename <new-name>')
              return :handled
            end

            old_name = @session_name
            @session_store.delete(old_name) if old_name != 'default'
            @session_name = name
            @status_bar.update(session: name)
            @session_store.save(name, messages: @message_stream.messages)
            @message_stream.add_message(role: :system, content: "Session renamed to '#{name}'.")
            :handled
          end

          def handle_import(input)
            path = input.split(nil, 2)[1]
            unless path
              @message_stream.add_message(role: :system, content: 'Usage: /import <path>')
              return :handled
            end

            load_import_file(File.expand_path(path))
          rescue ::JSON::ParserError => e
            @message_stream.add_message(role: :system, content: "Invalid JSON: #{e.message}")
            :handled
          end

          def load_import_file(path)
            unless File.exist?(path)
              @message_stream.add_message(role: :system, content: "File not found: #{path}")
              return :handled
            end

            data = ::JSON.parse(File.read(path), symbolize_names: true)
            unless data.is_a?(Hash) && data[:messages].is_a?(Array)
              @message_stream.add_message(role: :system, content: 'Invalid session file: missing messages array.')
              return :handled
            end

            apply_imported_messages(data[:messages], path)
          end

          def apply_imported_messages(messages, path)
            imported = messages.map { |m| { role: m[:role].to_sym, content: m[:content].to_s } }
            @message_stream.messages.replace(imported)
            @status_bar.notify(message: "Imported #{imported.size} messages", level: :success, ttl: 3)
            @message_stream.add_message(role: :system, content: "Imported #{imported.size} messages from #{path}.")
            :handled
          end

          def handle_autosave(input)
            arg = input.split(nil, 2)[1]
            if arg.nil?
              @autosave_enabled = !@autosave_enabled
              status = @autosave_enabled ? "ON (every #{@autosave_interval}s)" : 'OFF'
              @status_bar.notify(message: "Autosave: #{status}", level: :info, ttl: 3)
              @message_stream.add_message(role: :system, content: "Autosave #{status}.")
            elsif arg == 'off'
              @autosave_enabled = false
              @status_bar.notify(message: 'Autosave: OFF', level: :info, ttl: 3)
              @message_stream.add_message(role: :system, content: 'Autosave OFF.')
            elsif arg.match?(/\A\d+\z/)
              @autosave_interval = arg.to_i
              @autosave_enabled = true
              @status_bar.notify(message: "Autosave: ON (every #{@autosave_interval}s)", level: :info, ttl: 3)
              @message_stream.add_message(role: :system, content: "Autosave ON (every #{@autosave_interval}s).")
            else
              @message_stream.add_message(role: :system, content: 'Usage: /autosave [off|<seconds>]')
            end
            :handled
          end

          def check_autosave
            return unless @autosave_enabled
            return unless Time.now - @last_autosave >= @autosave_interval

            auto_save_session
            @last_autosave = Time.now
            @status_bar.notify(message: 'Autosaved', level: :info, ttl: 2)
          rescue StandardError
            nil
          end

          def auto_save_session
            return if @message_stream.messages.empty?

            if @session_name == 'default'
              @session_name = @session_store.auto_session_name(messages: @message_stream.messages)
            end
            @session_store.save(@session_name, messages: @message_stream.messages)
          rescue StandardError
            nil
          end

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          def handle_info
            cfg = safe_config
            elapsed = Time.now - @session_start
            hours   = (elapsed / 3600).to_i
            minutes = ((elapsed % 3600) / 60).to_i
            seconds = (elapsed % 60).to_i
            uptime_str = "#{hours}h #{minutes}m #{seconds}s"

            msgs = @message_stream.messages
            counts = %i[user assistant system tool].to_h { |r| [r, msgs.count { |m| m[:role] == r }] }
            total_chars = msgs.sum { |m| m[:content].to_s.length }
            avg_len = (total_chars.to_f / [msgs.size, 1].max).round

            model_info = if @llm_chat.respond_to?(:model)
                           @llm_chat.model.to_s
                         else
                           cfg[:provider] || 'none'
                         end

            tagged_count = msgs.count { |m| m[:tags]&.any? }
            fav_count = msgs.count { |m| m[:favorited] }

            lines = [
              "Session: #{@session_name}",
              "Started: #{@session_start.strftime('%Y-%m-%d %H:%M:%S')}",
              "Uptime: #{uptime_str}",
              '',
              "Messages: #{msgs.size} total",
              "  User: #{counts[:user]}, Assistant: #{counts[:assistant]}, System: #{counts[:system]}",
              "  Tool: #{counts[:tool]}",
              '',
              "Total characters: #{total_chars}",
              "Avg message length: #{avg_len} chars",
              '',
              "Pinned: #{@pinned_messages.size}",
              "Tagged: #{tagged_count}",
              "Favorited: #{fav_count}",
              "Aliases: #{@aliases.size}",
              "Snippets: #{@snippets.size}",
              "Macros: #{@macros.size}",
              '',
              "Autosave: #{@autosave_enabled ? "ON (every #{@autosave_interval}s)" : 'OFF'}",
              "Focus mode: #{@focus_mode ? 'on' : 'off'}",
              "Muted system: #{@muted_system ? 'on' : 'off'}",
              "Plan mode: #{@plan_mode ? 'on' : 'off'}",
              "Debug mode: #{@debug_mode ? 'on' : 'off'}",
              "LLM: #{model_info}"
            ]
            @message_stream.add_message(role: :system, content: lines.join("\n"))
            :handled
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

          def handle_merge(input)
            name = input.split(nil, 2)[1]
            unless name
              @message_stream.add_message(role: :system, content: 'Usage: /merge <session-name>')
              return :handled
            end

            data = @session_store.load(name)
            unless data
              @message_stream.add_message(role: :system, content: 'Session not found.')
              return :handled
            end

            imported = data[:messages]
            @message_stream.messages.concat(imported)
            @status_bar.update(message_count: @message_stream.messages.size)
            @message_stream.add_message(
              role: :system,
              content: "Merged #{imported.size} messages from '#{name}'."
            )
            :handled
          end
        end
        # rubocop:enable Metrics/ModuleLength
      end
    end
  end
end
