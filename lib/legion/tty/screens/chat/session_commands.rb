# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Chat < Base
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

          def auto_save_session
            return if @message_stream.messages.empty?

            if @session_name == 'default'
              @session_name = @session_store.auto_session_name(messages: @message_stream.messages)
            end
            @session_store.save(@session_name, messages: @message_stream.messages)
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
