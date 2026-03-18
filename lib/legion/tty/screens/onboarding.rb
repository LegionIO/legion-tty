# frozen_string_literal: true

require_relative '../screens/base'
require_relative '../components/digital_rain'
require_relative '../components/wizard_prompt'
require_relative '../background/scanner'
require_relative '../background/github_probe'
require_relative '../theme'

module Legion
  module TTY
    module Screens
      # rubocop:disable Metrics/ClassLength
      class Onboarding < Base
        TYPED_DELAY = 0.05

        def initialize(app, wizard: nil, output: $stdout, skip_rain: false)
          super(app)
          @wizard = wizard || Components::WizardPrompt.new
          @output = output
          @skip_rain = skip_rain
          @scan_queue = Queue.new
          @github_queue = Queue.new
        end

        def activate
          start_background_threads
          run_rain unless @skip_rain
          run_intro
          config = run_wizard
          scan_data, github_data = collect_background_results
          run_reveal(name: config[:name], scan_data: scan_data, github_data: github_data)
          config
        end

        # rubocop:disable Metrics/AbcSize
        def run_rain
          require 'tty-cursor'
          require 'tty-font'
          width = terminal_width
          height = terminal_height
          rain = Components::DigitalRain.new(width: width, height: height)
          rain.run(duration_seconds: 15, fps: 18, output: @output)
          @output.print ::TTY::Cursor.clear_screen
          font = ::TTY::Font.new(:standard)
          title = font.write('LEGION')
          title.each_line do |line|
            @output.puts line.center(width)
          end
          @output.puts Theme.c(:muted, 'async cognition engine').center(width + 20)
          sleep 4
          @output.print ::TTY::Cursor.clear_screen
        end
        # rubocop:enable Metrics/AbcSize

        def run_intro
          sleep 2
          typed_output('...')
          sleep 1.2
          @output.puts
          @output.puts
          typed_output("Hello. I'm Legion.")
          @output.puts
          sleep 1.5
          typed_output("Let's get you set up.")
          @output.puts
          @output.puts
        end

        def run_wizard
          name = @wizard.ask_name
          sleep 0.8
          typed_output("  Nice to meet you, #{name}.")
          @output.puts
          sleep 1
          typed_output("Let's get you connected.")
          @output.puts
          @output.puts
          provider = @wizard.select_provider
          sleep 0.5
          api_key = @wizard.ask_api_key(provider: provider)
          { name: name, provider: provider, api_key: api_key }
        end

        def start_background_threads
          @scanner = Background::Scanner.new
          @github_probe = Background::GitHubProbe.new
          @scanner.run_async(@scan_queue)
        end

        def collect_background_results
          scan_result = drain_with_timeout(@scan_queue, timeout: 10)
          scan_data = scan_result&.dig(:data) || { services: {}, repos: [], tools: {} }

          # Now launch GitHub probe with discovered remotes
          remotes = scan_data[:repos]&.filter_map { |r| r[:remote] } || []
          @github_probe.run_async(@github_queue, remotes: remotes)
          github_result = drain_with_timeout(@github_queue, timeout: 8)
          github_data = github_result&.dig(:data)
          [scan_data, github_data]
        end

        def run_reveal(name:, scan_data:, github_data:)
          require 'tty-box'
          @output.puts
          typed_output('One moment...')
          @output.puts
          sleep 1.5
          summary = build_summary(name: name, scan_data: scan_data, github_data: github_data)
          box = ::TTY::Box.frame(summary, padding: 1, border: :thick)
          @output.puts box
          @output.puts
          @wizard.confirm('Does this look right?')
          @output.puts
          sleep 0.8
          typed_output("Let's chat.")
          @output.puts
          sleep 1
        end

        def build_summary(name:, scan_data:, github_data:)
          lines = ["Hello, #{name}!", '', "Here's what I found:"]
          lines.concat(scan_summary_lines(scan_data))
          lines.concat(github_summary_lines(github_data))
          lines.join("\n")
        end

        private

        def scan_summary_lines(scan_data)
          return [] unless scan_data.is_a?(Hash)

          services = scan_data[:services]
          return [] unless services.is_a?(Hash)

          running = services.values.select { |s| s[:running] }.map { |s| s[:name] }
          return [] if running.empty?

          ['', "Running services: #{running.join(', ')}"]
        end

        def github_summary_lines(github_data)
          return [] unless github_data.is_a?(Hash)

          username = github_data[:username]
          return [] unless username

          lines = ['', "GitHub: #{username}"]
          profile = github_data[:profile]
          lines << "  #{profile[:repos]} public repositories" if profile.is_a?(Hash) && profile[:repos]
          lines
        end

        def typed_output(text, delay: TYPED_DELAY)
          text.chars.each do |char|
            @output.print Theme.c(:primary, char)
            @output.flush if @output.respond_to?(:flush)
            sleep delay
          end
        end

        def drain_with_timeout(queue, timeout:)
          deadline = Time.now + timeout
          loop do
            return queue.pop(true) unless queue.empty?
            return nil if Time.now >= deadline

            sleep 0.1
          end
        rescue ThreadError
          nil
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
