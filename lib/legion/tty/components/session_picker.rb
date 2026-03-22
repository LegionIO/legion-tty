# frozen_string_literal: true

module Legion
  module TTY
    module Components
      class SessionPicker
        def initialize(session_store:)
          @session_store = session_store
        end

        def select_with_prompt(output: $stdout)
          sessions = @session_store.list
          return nil if sessions.empty?

          require 'tty-prompt'
          prompt = ::TTY::Prompt.new(output: output)
          choices = sessions.map do |s|
            { name: "#{s[:name]} (#{s[:message_count]} msgs, #{s[:saved_at]})", value: s[:name] }
          end
          choices << { name: '+ New session', value: :new }
          prompt.select('Select session:', choices, per_page: 10)
        rescue ::TTY::Reader::InputInterrupt, Interrupt => e
          Legion::Logging.debug("session picker cancelled: #{e.message}") if defined?(Legion::Logging)
          nil
        end
      end
    end
  end
end
