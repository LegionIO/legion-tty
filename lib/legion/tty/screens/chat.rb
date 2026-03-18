# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../components/message_stream'
require_relative '../components/status_bar'
require_relative '../components/input_bar'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Chat < Base
        STUB_RESPONSE = "I'm Legion. LLM integration coming soon — for now I'm just a pretty face."

        SLASH_COMMANDS = %w[/help /quit /clear /model /session /cost /export /tools].freeze

        attr_reader :message_stream, :status_bar

        def initialize(app, output: $stdout, input_bar: nil)
          super(app)
          @output = output
          @message_stream = Components::MessageStream.new
          @status_bar = Components::StatusBar.new
          @running = false
          @input_bar = input_bar || build_default_input_bar
        end

        def activate
          @running = true
          cfg = safe_config
          @status_bar.update(model: cfg[:provider], session: 'default')
          @message_stream.add_message(
            role: :system,
            content: "Welcome#{", #{cfg[:name]}" if cfg[:name]}. Type /help for commands."
          )
        end

        def running?
          @running
        end

        def run
          while @running
            render_screen
            input = read_input
            break if input.nil?

            result = handle_slash_command(input)
            if result == :quit
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
        end

        def send_to_llm(_message, &)
          STUB_RESPONSE.chars.each do |char|
            @message_stream.append_streaming(char)
          end
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

        # rubocop:disable Metrics/CyclomaticComplexity
        def dispatch_slash(cmd, input)
          case cmd
          when '/quit' then :quit
          when '/help' then handle_help
          when '/clear' then handle_clear
          when '/model' then handle_model(input)
          when '/session' then handle_session(input)
          when '/cost' then handle_cost
          when '/export' then handle_export
          when '/tools' then handle_tools
          else :handled
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        def handle_help
          @message_stream.add_message(
            role: :system,
            content: 'Commands: /help /quit /clear /model <name> /session <name> /cost /export /tools'
          )
          :handled
        end

        def handle_clear
          @message_stream.messages.clear
          :handled
        end

        def handle_model(input)
          name = input.split(nil, 2)[1]
          @status_bar.update(model: name) if name
          :handled
        end

        def handle_session(input)
          name = input.split(nil, 2)[1]
          @status_bar.update(session: name) if name
          :handled
        end

        def handle_cost
          @message_stream.add_message(role: :system, content: 'Cost tracking: $0.000')
          :handled
        end

        def handle_export
          @message_stream.add_message(role: :system, content: 'Export: not yet implemented.')
          :handled
        end

        def handle_tools
          @message_stream.add_message(role: :system, content: 'Tools: none loaded.')
          :handled
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
