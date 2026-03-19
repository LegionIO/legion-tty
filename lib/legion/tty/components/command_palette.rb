# frozen_string_literal: true

module Legion
  module TTY
    module Components
      class CommandPalette
        COMMANDS = %w[/help /quit /clear /model /session /cost /export /tools
                      /dashboard /hotkeys /save /load /sessions /system /delete /plan
                      /palette /extensions /config].freeze

        SCREENS = %w[chat dashboard extensions config].freeze

        def initialize(session_store: nil)
          @session_store = session_store
        end

        def entries
          all = []
          COMMANDS.each { |cmd| all << { label: cmd, category: 'Commands' } }
          SCREENS.each { |s| all << { label: s, category: 'Screens' } }
          if @session_store
            @session_store.list.each do |s|
              all << { label: "/load #{s[:name]}", category: 'Sessions' }
            end
          end
          all
        end

        def search(query)
          return entries if query.nil? || query.empty?

          q = query.downcase
          entries.select { |e| e[:label].downcase.include?(q) }
        end

        def select_with_prompt(output: $stdout)
          require 'tty-prompt'
          prompt = ::TTY::Prompt.new(output: output)
          choices = entries.map { |e| { name: "#{e[:label]} (#{e[:category]})", value: e[:label] } }
          prompt.select('Command:', choices, filter: true, per_page: 15)
        rescue ::TTY::Reader::InputInterrupt, Interrupt
          nil
        end
      end
    end
  end
end
